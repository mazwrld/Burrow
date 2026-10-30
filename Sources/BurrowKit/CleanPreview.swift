import Foundation

/// One `=== Group ===` section of `~/.config/mole/clean-list.txt`.
public struct CleanGroup: Identifiable, Equatable, Sendable {
    public var name: String
    public var items: [CleanItem]
    public var id: String { name }
    public var total: Int64 { items.reduce(0) { $0 + ($1.size?.bytes ?? 0) } }

    public init(name: String, items: [CleanItem]) {
        self.name = name; self.items = items
    }
}

/// One path in a group, with the size Mole measured.
public struct CleanItem: Identifiable, Equatable, Sendable {
    public var path: String
    public var size: MoleSize?
    public var id: String { path }

    public init(path: String, size: MoleSize?) {
        self.path = path; self.size = size
    }
}

/// A row Mole reports but `mo clean` does not remove (Large files, Project artifacts).
public struct AdviceItem: Identifiable, Equatable, Sendable {
    public var section: String
    public var title: String
    public var detail: String
    public var id: String { section + "|" + title }
}

/// The totals line: `Potential space: 4.14GB | Items: 359 | Categories: 6`.
public struct CleanTotals: Equatable, Sendable {
    public var size: MoleSize
    public var items: Int
    public var categories: Int
}

/// What a preview found: groups from the list file, totals and advice from the output.
public struct CleanPreview: Equatable, Sendable {
    public var groups: [CleanGroup]
    public var totals: CleanTotals?
    public var advice: [AdviceItem]
    /// True when the user's Trash is in the list: `mo clean` empties it.
    public var emptiesTrash: Bool
    /// True when Mole said system caches need an administrator password.
    public var adminSkipped: Bool

    public var isEmpty: Bool { groups.allSatisfy(\.items.isEmpty) && (totals?.size.bytes ?? 0) == 0 }

    public init(listFile: String, output: String, home: String) {
        groups = CleanListParser.parse(listFile)
        let clean = MoleText.stripANSI(output)
        totals = CleanOutput.totals(clean)
        advice = CleanOutput.advice(clean)
        adminSkipped = CleanOutput.adminSkipped(clean)
        let trash = home + "/.Trash"
        emptiesTrash = groups.contains { $0.items.contains { $0.path == trash || $0.path.hasPrefix(trash + "/") } }
    }
}

public enum CleanListParser {
    /// Parses the list file. Header comments are skipped; `/path  # 63.1MB` is an item.
    public static func parse(_ text: String) -> [CleanGroup] {
        var groups: [CleanGroup] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = String(raw)
            if line.hasPrefix("=== "), line.hasSuffix(" ===") {
                let name = String(line.dropFirst(4).dropLast(4)).trimmingCharacters(in: .whitespaces)
                groups.append(CleanGroup(name: name, items: []))
                continue
            }
            guard line.hasPrefix("/"), !groups.isEmpty else { continue }
            var path = line
            var size: MoleSize?
            if let mark = line.range(of: "  # ", options: .backwards) {
                path = String(line[..<mark.lowerBound])
                size = MoleSize(String(line[mark.upperBound...]))
            }
            groups[groups.count - 1].items.append(CleanItem(path: path, size: size))
        }
        return groups.filter { !$0.items.isEmpty }
    }
}

/// Reads Mole's human output (colors already removed).
public enum CleanOutput {
    /// Sections whose rows are only reported, never cleaned by `mo clean`.
    public static let adviceSections: Set<String> = ["Large files", "Project artifacts"]

    public static func totals(_ text: String) -> CleanTotals? {
        for line in text.split(whereSeparator: \.isNewline) {
            guard let range = line.range(of: "Potential space: ") else { continue }
            let fields = line[range.upperBound...].components(separatedBy: " | ")
            guard let size = MoleSize(fields[0]) else { continue }
            func number(_ label: String) -> Int {
                fields.first { $0.hasPrefix(label) }.flatMap { Int($0.dropFirst(label.count)) } ?? 0
            }
            return CleanTotals(size: size, items: number("Items: "), categories: number("Categories: "))
        }
        return nil
    }

    /// The `➤ Section` name of a line, if it is a section title.
    public static func section(of line: Substring) -> String? {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("➤ ") else { return nil }
        return String(t.dropFirst(2))
    }

    public static func advice(_ text: String) -> [AdviceItem] {
        var current: String?
        var out: [AdviceItem] = []
        for line in text.split(whereSeparator: \.isNewline) {
            if let name = section(of: line) { current = name; continue }
            guard let s = current, adviceSections.contains(s) else { continue }
            let t = line.trimmingCharacters(in: .whitespaces)
            guard t.hasPrefix("⊙ ") else { continue }
            let parts = t.dropFirst(2).components(separatedBy: " · ")
            out.append(AdviceItem(section: s, title: parts[0], detail: parts.dropFirst().joined(separator: " · ")))
        }
        return out
    }

    public static func adminSkipped(_ text: String) -> Bool {
        text.contains("System caches need sudo") || text.contains("System-level cleanup skipped, requires sudo")
    }
}

/// The end of a real `mo clean` run.
public struct CleanRunSummary: Equatable, Sendable {
    /// From `Tracked cleanup: 4.02GB | Items cleaned: 310`; nil when nothing was freed.
    public var freed: MoleSize?
    public var itemsCleaned: Int
    /// `Free space: 134.9GB (+4.0GB)` without the label.
    public var freeSpace: String?
    public var alreadyClean: Bool
    public var adminSkipped: Bool
    /// A `Cancelled: …` or `A required cleanup step failed …` line.
    public var problem: String?

    public init(output: String) {
        let text = MoleText.stripANSI(output)
        freed = nil; itemsCleaned = 0; freeSpace = nil; problem = nil
        alreadyClean = text.contains("no additional space freed")
        adminSkipped = CleanOutput.adminSkipped(text)
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if let r = line.range(of: "Tracked cleanup: ") {
                let fields = line[r.upperBound...].components(separatedBy: " | ")
                freed = MoleSize(fields[0])
                itemsCleaned = fields.first { $0.hasPrefix("Items cleaned: ") }.flatMap { Int($0.dropFirst(15)) } ?? 0
            } else if line.hasPrefix("Free space: ") {
                freeSpace = String(line.dropFirst(12))
            } else if let r = line.range(of: "Cancelled: ") ?? line.range(of: "A required cleanup step failed") {
                problem = String(line[r.lowerBound...])
            }
        }
    }
}
