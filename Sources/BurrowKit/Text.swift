import Foundation

/// Text helpers for Mole's terminal output.
public enum MoleText {
    /// Removes ANSI color and cursor codes (`ESC [ ... letter`) and carriage
    /// returns, so a line reads the same as it does in Terminal.
    public static func stripANSI(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        var iterator = text.unicodeScalars.makeIterator()
        while let scalar = iterator.next() {
            if scalar == "\u{1B}" {
                // CSI: ESC [ params final-letter. Other escapes: drop ESC and the next scalar.
                guard let next = iterator.next() else { break }
                if next == "[" {
                    while let c = iterator.next() {
                        if (0x40...0x7E).contains(c.value) { break }
                    }
                }
                continue
            }
            if scalar == "\r" { continue }
            out.unicodeScalars.append(scalar)
        }
        return out
    }
}

/// Sizes as Mole prints them: decimal units, like `4.14GB`, `63.1MB`, `4KB`, `0B`.
/// A trailing `+` means the size is a lower bound.
public struct MoleSize: Equatable, Comparable, Sendable {
    public var bytes: Int64
    public var isLowerBound: Bool

    public init(bytes: Int64, isLowerBound: Bool = false) {
        self.bytes = bytes
        self.isLowerBound = isLowerBound
    }

    /// Parses `4.14GB`, `4.88GB+`, `63.1MB`, `968.3MB`, `4KB`, `0B`, `1.2TB`.
    public init?(_ text: String) {
        var s = text.trimmingCharacters(in: .whitespaces)
        isLowerBound = s.hasSuffix("+")
        if isLowerBound { s.removeLast() }
        let units: [(String, Double)] = [("TB", 1e12), ("GB", 1e9), ("MB", 1e6), ("KB", 1e3), ("B", 1)]
        guard let (suffix, scale) = units.first(where: { s.uppercased().hasSuffix($0.0) }),
              let number = Double(s.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)),
              number >= 0 else { return nil }
        bytes = Int64((number * scale).rounded())
    }

    /// "4.14 GB", or "at least 4.88 GB" for a lower bound.
    public var display: String {
        let text = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        return isLowerBound ? "at least \(text)" : text
    }

    /// "4.14 GB" without the lower-bound words, for buttons and titles.
    public var short: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

    public static func < (a: MoleSize, b: MoleSize) -> Bool { a.bytes < b.bytes }
}
