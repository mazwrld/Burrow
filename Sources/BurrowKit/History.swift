import Foundation

/// `mo history --json --limit N`.
public struct MoleHistory: Decodable, Equatable, Sendable {
    public var sessions: [Session]
    public var deletions: [Deletion]

    public struct Session: Decodable, Equatable, Sendable, Identifiable {
        public var command: String
        public var runId: String
        public var startedAt: String
        public var endedAt: String?
        public var items: Int?
        public var size: String?
        public var actions: Actions?
        /// Older Mole versions log an empty run id, so fall back to command and start time.
        public var id: String { runId.isEmpty ? "\(command)@\(startedAt)" : runId }

        /// `clean-dry-run`, `optimize-dry-run`: a preview that changed nothing.
        public var isPreview: Bool { command.hasSuffix("-dry-run") }
        /// `clean` for `clean-dry-run`.
        public var baseCommand: String { isPreview ? String(command.dropLast(8)) : command }
        public var start: Date? { MoleHistory.localDate(startedAt) }
        public var end: Date? { endedAt.flatMap(MoleHistory.localDate) }
    }

    public struct Actions: Decodable, Equatable, Sendable {
        public var removed: Int
        public var trashed: Int
        public var skipped: Int
        public var failed: Int
    }

    public struct Deletion: Decodable, Equatable, Sendable, Identifiable {
        public var timestamp: String
        public var mode: String
        public var status: String
        public var sizeKb: Int64?
        public var path: String
        public var id: String { timestamp + path }
        public var date: Date? { MoleHistory.isoDate(timestamp) }
        public var movedToTrash: Bool { mode == "trash" }
    }

    /// The deletions logged while a run was going, matched by time
    /// (Mole's deletion records carry no run id). One second of slack each side.
    public func deletions(for session: Session) -> [Deletion] {
        guard let start = session.start else { return [] }
        let end = session.end ?? start
        let window = start.addingTimeInterval(-1)...end.addingTimeInterval(1)
        return deletions.filter { d in d.date.map { window.contains($0) } ?? false }
    }

    public static func decode(_ data: Data) throws -> MoleHistory {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(MoleHistory.self, from: data)
    }

    /// `2026-10-30 09:08:09` in the Mac's time zone.
    static func localDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: text)
    }

    /// `2026-10-27T08:44:02-0500`.
    static func isoDate(_ text: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        return f.date(from: text)
    }
}
