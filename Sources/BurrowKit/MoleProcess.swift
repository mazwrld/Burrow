import Foundation

/// Runs one Mole command, streams its output lines, and can stop it.
/// Output from stdout and stderr is merged, colors removed.
public final class MoleProcess: @unchecked Sendable {
    public let executable: String
    public let arguments: [String]
    private let process = Process()
    private let lock = NSLock()
    private var stopped = false

    public init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    /// The exit code and every output line. `onLine` runs on a background queue.
    public struct Result: Sendable {
        public var status: Int32
        public var output: String
        public var wasStopped: Bool
    }

    public func run(onLine: @escaping @Sendable (String) -> Void = { _ in }) async throws -> Result {
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        // No terminal: Mole takes its non-interactive paths and never prompts.
        process.standardInput = FileHandle.nullDevice
        var env = ProcessInfo.processInfo.environment
        env["NO_COLOR"] = "1"
        // A GUI app's PATH lacks Homebrew; Mole's helpers live there.
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        let collector = LineCollector(onLine: onLine)
        try process.run()
        // Process closes the parent's copy of the write end itself. Closing it
        // again here could close a reused descriptor of another running command.
        let reader = pipe.fileHandleForReading
        let process = process
        // Read to the end of the output first, then wait for the exit code:
        // reading in the termination handler raced the last lines away.
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                while true {
                    let data = reader.availableData
                    if data.isEmpty { break }
                    collector.append(data)
                }
                collector.flush()
                process.waitUntilExit()
                continuation.resume(returning: Result(status: process.terminationStatus,
                                                      output: collector.text,
                                                      wasStopped: isStopped))
            }
        }
    }

    private var isStopped: Bool { lock.withLock { stopped } }

    /// Sends SIGINT, like Control-C in Terminal, so Mole stops cleanly.
    public func stop() {
        lock.withLock { stopped = true }
        if process.isRunning { process.interrupt() }
    }
}

private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var all = ""
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) { self.onLine = onLine }

    var text: String { lock.withLock { all } }

    func append(_ data: Data) {
        let lines: [String] = lock.withLock {
            buffer.append(data)
            var out: [String] = []
            while let nl = buffer.firstIndex(of: 0x0A) {
                let line = MoleText.stripANSI(String(decoding: buffer[buffer.startIndex..<nl], as: UTF8.self))
                buffer.removeSubrange(buffer.startIndex...nl)
                all += line + "\n"
                out.append(line)
            }
            return out
        }
        lines.forEach(onLine)
    }

    func flush() {
        let line: String? = lock.withLock {
            guard !buffer.isEmpty else { return nil }
            let l = MoleText.stripANSI(String(decoding: buffer, as: UTF8.self))
            buffer.removeAll()
            all += l + "\n"
            return l
        }
        if let line { onLine(line) }
    }
}
