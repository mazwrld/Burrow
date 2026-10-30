import AppKit
import BurrowKit

/// How Burrow reaches Mole. Live mode runs the installed `mo`. Fixture mode
/// (APP_FIXTURES) reads captured output with /bin/cat and never runs `mo`, so
/// snapshots and the self-test cannot clean anything.
struct Mole: Sendable {
    /// Set in fixture mode: the folder with status.json, clean-list.txt, and the rest.
    let fixtures: URL?

    static func fromEnvironment() -> Mole {
        let dir = ProcessInfo.processInfo.environment["APP_FIXTURES"] ?? ""
        return Mole(fixtures: dir.isEmpty ? nil : URL(fileURLWithPath: dir, isDirectory: true))
    }

    var isFixture: Bool { fixtures != nil }

    /// The commands Burrow runs itself. Only `clean` removes anything.
    enum Command {
        case version, status, history, cleanPreview, clean

        var arguments: [String] {
            switch self {
            case .version: ["--version"]
            case .status: ["status", "--json"]
            case .history: ["history", "--json", "--limit", "200"]
            case .cleanPreview: ["clean", "--dry-run"]
            case .clean: ["clean"]
            }
        }

        var fixture: String {
            switch self {
            case .version: "version.txt"
            case .status: "status.json"
            case .history: "history.json"
            case .cleanPreview: "clean-dry-run.txt"
            case .clean: "clean-run.txt"
            }
        }

        /// `mo status --json`, for error messages and Copy Command.
        var display: String { (["mo"] + arguments).joined(separator: " ") }
    }

    /// Finds `mo`: the Settings path first, then the usual install places.
    func locate(customPath: String?) async -> MoleLookup {
        if let fixtures {
            let text = (try? String(contentsOf: fixtures.appending(path: "version.txt"), encoding: .utf8)) ?? ""
            guard let version = MoleVersion(versionOutput: text) else { return .missing }
            return version.isSupported ? .ready(path: "/fixtures/mo", version: version) : .tooOld(version)
        }
        for path in MoleLocator.candidates(customPath: customPath, home: NSHomeDirectory())
        where FileManager.default.isExecutableFile(atPath: path) {
            let result = try? await MoleProcess(executable: path, arguments: ["--version"]).run()
            guard let result, result.status == 0, let version = MoleVersion(versionOutput: result.output) else { continue }
            return version.isSupported ? .ready(path: path, version: version) : .tooOld(version)
        }
        return .missing
    }

    func process(_ command: Command, moPath: String) -> MoleProcess {
        if let fixtures {
            return MoleProcess(executable: "/bin/cat", arguments: [fixtures.appending(path: command.fixture).path])
        }
        return MoleProcess(executable: moPath, arguments: command.arguments)
    }

    /// Where `mo clean --dry-run` writes every path it found.
    var cleanListURL: URL {
        fixtures?.appending(path: "clean-list.txt")
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: ".config/mole/clean-list.txt")
    }

    /// The home folder the list paths start with (the fixtures were captured on /Users/test).
    var home: String { isFixture ? "/Users/test" : NSHomeDirectory() }

    /// Opens a new Terminal window that runs the command. A `.command` file
    /// needs no Automation permission. Fixture mode only records the request.
    func openInTerminal(_ command: TerminalCommand, moPath: String) throws {
        guard !isFixture else { return }
        let url = FileManager.default.temporaryDirectory.appending(path: "Burrow-\(UUID().uuidString).command")
        try command.script(moPath: moPath).write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
        guard let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            throw CocoaError(.fileNoSuchFile)
        }
        NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}

enum MoleLookup: Equatable {
    case checking
    case missing
    case tooOld(MoleVersion)
    case ready(path: String, version: MoleVersion)
}

/// A failed Mole command, shown inline with its exit code and Copy Command.
struct MoleFailure: Equatable {
    var command: String
    var message: String
}
