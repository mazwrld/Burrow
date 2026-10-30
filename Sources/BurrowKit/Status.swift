import Foundation

/// The parts of `mo status --json` that the Health page shows.
/// Every field is optional, so a Mole that drops one still decodes.
public struct StatusSnapshot: Decodable, Equatable, Sendable {
    public var collectedAt: String?
    public var host: String?
    public var healthScore: Int?
    public var healthScoreMsg: String?
    public var cpu: CPU?
    public var memory: Memory?
    public var disks: [Disk]?
    public var batteries: [Battery]?
    public var topProcesses: [Process]?
    public var trashSize: Int64?

    public struct CPU: Decodable, Equatable, Sendable {
        public var usage: Double?
        public var load1: Double?
        public var coreCount: Int?
    }

    public struct Memory: Decodable, Equatable, Sendable {
        public var used: Int64?
        public var total: Int64?
        public var usedPercent: Double?
        public var pressure: String?
        public var swapUsed: Int64?
    }

    public struct Disk: Decodable, Equatable, Sendable {
        public var mount: String
        public var used: Int64?
        public var total: Int64?
        public var usedPercent: Double?
        public var external: Bool?
        public var free: Int64? { total.flatMap { t in used.map { t - $0 } } }
    }

    public struct Battery: Decodable, Equatable, Sendable {
        public var percent: Double?
        public var status: String?
        public var health: String?
        public var cycleCount: Int?
    }

    public struct Process: Decodable, Equatable, Sendable, Identifiable {
        public var pid: Int
        public var name: String
        public var cpu: Double?
        public var memoryBytes: Int64?
        public var id: Int { pid }
    }

    /// The startup disk: the one mounted at `/`, else the first internal one.
    public var startupDisk: Disk? {
        disks?.first { $0.mount == "/" } ?? disks?.first { $0.external != true }
    }

    public static func decode(_ data: Data) throws -> StatusSnapshot {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(StatusSnapshot.self, from: data)
    }
}
