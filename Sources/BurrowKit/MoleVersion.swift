import Foundation

/// The installed Mole's version, read from the first line of `mo --version`.
public struct MoleVersion: Comparable, CustomStringConvertible, Sendable {
    public var major: Int, minor: Int, patch: Int

    /// The oldest Mole whose JSON and dry-run output Burrow reads.
    public static let minimum = MoleVersion(major: 1, minor: 62, patch: 0)

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major; self.minor = minor; self.patch = patch
    }

    /// Reads `Mole version 1.64.0` (the first line of `mo --version`).
    public init?(versionOutput: String) {
        let first = MoleText.stripANSI(versionOutput).split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        guard first.hasPrefix("Mole version "),
              let token = first.dropFirst("Mole version ".count).split(separator: " ").first else { return nil }
        let parts = token.split(separator: ".").map { Int($0) }
        guard parts.count >= 2, let major = parts[0], let minor = parts[1] else { return nil }
        self.init(major: major, minor: minor, patch: parts.count > 2 ? (parts[2] ?? 0) : 0)
    }

    public var isSupported: Bool { self >= Self.minimum }
    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (a: MoleVersion, b: MoleVersion) -> Bool {
        (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
    }
}

/// Where Burrow looks for `mo`, in order.
public enum MoleLocator {
    public static func candidates(customPath: String?, home: String) -> [String] {
        var list: [String] = []
        if let custom = customPath?.trimmingCharacters(in: .whitespaces), !custom.isEmpty {
            list.append((custom as NSString).expandingTildeInPath)
        }
        list += ["/opt/homebrew/bin/mo", "/usr/local/bin/mo", home + "/.local/bin/mo"]
        return list
    }
}
