import Foundation
import Testing
@testable import BurrowKit

private func fixture(_ name: String) throws -> String {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "Fixtures/\(name)")
    return try String(contentsOf: url, encoding: .utf8)
}

// S-001
@Test func readsVersionFromFirstLine() throws {
    let v = try #require(MoleVersion(versionOutput: "Mole version 1.64.0\nmacOS: 27.2\n"))
    #expect(v.description == "1.64.0")
    #expect(v.isSupported)
    #expect(MoleVersion(versionOutput: "Mole version 1.61.3")?.isSupported == false)
    #expect(MoleVersion(versionOutput: "zsh: command not found: mo") == nil)
}

@Test func locatorOrder() {
    let list = MoleLocator.candidates(customPath: "~/bin/mo", home: "/Users/x")
    #expect(list.first == ("~/bin/mo" as NSString).expandingTildeInPath)
    #expect(Array(list.dropFirst()) == ["/opt/homebrew/bin/mo", "/usr/local/bin/mo", "/Users/x/.local/bin/mo"])
    #expect(MoleLocator.candidates(customPath: "  ", home: "/h").first == "/opt/homebrew/bin/mo")
}

// S-002
@Test func decodesStatus() throws {
    let s = try StatusSnapshot.decode(Data(try fixture("status.json").utf8))
    #expect(s.healthScore != nil)
    #expect(s.startupDisk?.mount == "/")
    #expect((s.topProcesses?.count ?? 0) >= 5)
    #expect(s.batteries?.isEmpty == false)
    let desktop = try StatusSnapshot.decode(Data(try fixture("status-desktop.json").utf8))
    #expect(desktop.batteries?.isEmpty == true)
}

// S-003
@Test func parsesCleanList() throws {
    let groups = CleanListParser.parse(try fixture("clean-list.txt"))
    #expect(groups.first?.name == "User essentials")
    #expect(groups.map(\.name).contains("Developer tools"))
    let geo = groups[0].items.first { $0.path.hasSuffix("/GeoServices") }
    #expect(geo?.size == MoleSize(bytes: 63_100_000))
    #expect(!groups.flatMap(\.items).contains { $0.path.hasPrefix("#") })
}

@Test func parsesListLineWithSpacesAndHash() {
    let groups = CleanListParser.parse("=== A ===\n/Users/me/Caches/My # App  # 1.5MB\n/Users/me/x\n")
    #expect(groups[0].items[0].path == "/Users/me/Caches/My # App")
    #expect(groups[0].items[0].size?.bytes == 1_500_000)
    #expect(groups[0].items[1].size == nil)
}

@Test func readsTotalsAndAdviceFromDryRun() throws {
    let preview = CleanPreview(listFile: try fixture("clean-list.txt"), output: try fixture("clean-dry-run.txt"), home: "/Users/test")
    #expect(preview.totals == CleanTotals(size: MoleSize(bytes: 4_140_000_000), items: 359, categories: 6))
    #expect(preview.advice.contains { $0.section == "Project artifacts" && $0.detail.contains("mo purge") })
    #expect(preview.advice.contains { $0.title == "Simulator data" })
    #expect(preview.emptiesTrash)
    #expect(preview.adminSkipped)
}

@Test func stripsANSI() {
    #expect(MoleText.stripANSI("\u{1B}[0;32m4.14GB\u{1B}[0m\r") == "4.14GB")
    #expect(MoleText.stripANSI("\u{1B}[0;38;5;244m~/x\u{1B}[0m") == "~/x")
}

@Test("Sizes", arguments: [
    ("4.14GB", Int64(4_140_000_000), false), ("4.88GB+", 4_880_000_000, true),
    ("63.1MB", 63_100_000, false), ("4KB", 4_000, false), ("0B", 0, false),
])
func parsesSizes(_ text: String, bytes: Int64, lower: Bool) {
    #expect(MoleSize(text) == MoleSize(bytes: bytes, isLowerBound: lower))
}

@Test func lowerBoundReadsAtLeast() {
    #expect(MoleSize("4.88GB+")?.display.hasPrefix("at least ") == true)
    #expect(MoleSize("lots") == nil)
}

// S-004
@Test func readsRunSummary() throws {
    let s = CleanRunSummary(output: try fixture("clean-run.txt"))
    #expect(s.freed == MoleSize(bytes: 4_020_000_000))
    #expect(s.itemsCleaned == 310)
    #expect(s.freeSpace == "134.76GB (+4.02GB)")
    #expect(s.adminSkipped)
    #expect(!s.alreadyClean)
    #expect(s.problem == nil)
    let clean = CleanRunSummary(output: "System was already clean; no additional space freed.\nFree space: 130GB")
    #expect(clean.alreadyClean && clean.freed == nil)
    let cancelled = CleanRunSummary(output: "⚠ Cancelled: a cleanup step was interrupted (exit 130). Remaining cleanup was skipped.")
    #expect(cancelled.problem?.hasPrefix("Cancelled:") == true)
}

// S-005
@Test func decodesHistory() throws {
    let h = try MoleHistory.decode(Data(try fixture("history.json").utf8))
    #expect(!h.sessions.isEmpty)
    #expect(Set(h.sessions.map(\.id)).count == h.sessions.count, "ids must be unique, even with empty run ids")
    let preview = try #require(h.sessions.first { $0.command == "clean-dry-run" })
    #expect(preview.isPreview && preview.baseCommand == "clean")
    let analyze = try #require(h.sessions.first { $0.command == "analyze" && ($0.actions?.trashed ?? 0) > 0 })
    let items = h.deletions(for: analyze)
    #expect(!items.isEmpty)
    #expect(items.allSatisfy { $0.movedToTrash })
}

// S-006
@Test func terminalCommandsAreQuoted() {
    #expect(TerminalCommand.clean.display == "mo clean")
    #expect(TerminalCommand.cleanWhitelist.display == "mo clean --whitelist")
    #expect(TerminalCommand.uninstall(name: "google chrome").display == "mo uninstall 'google chrome'")
    #expect(TerminalCommand.uninstall(name: "a'b; rm -rf ~").display == #"mo uninstall 'a'\''b; rm -rf ~'"#)
    #expect(TerminalCommand.clean.script(moPath: "/opt/homebrew/bin/mo") == "#!/bin/zsh\n/opt/homebrew/bin/mo clean\n")
}

@Test func processStreamsLinesAndStops() async throws {
    let lines = LockedLines()
    let p = MoleProcess(executable: "/bin/sh", arguments: ["-c", "printf '\\033[0;32mone\\033[0m\\ntwo'"])
    let r = try await p.run { lines.add($0) }
    #expect(r.status == 0)
    #expect(lines.all == ["one", "two"])

    let slow = MoleProcess(executable: "/bin/sleep", arguments: ["30"])
    Task { try? await Task.sleep(for: .milliseconds(200)); slow.stop() }
    let stopped = try await slow.run()
    #expect(stopped.wasStopped)
}

private final class LockedLines: @unchecked Sendable {
    private let lock = NSLock()
    private var lines: [String] = []
    func add(_ l: String) { lock.withLock { lines.append(l) } }
    var all: [String] { lock.withLock { lines } }
}

@Test func streamsFixtureSections() async throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "Fixtures/clean-dry-run.txt")
    let lines = LockedLines()
    _ = try await MoleProcess(executable: "/bin/cat", arguments: [url.path]).run { lines.add($0) }
    #expect(lines.all.contains { $0.contains("➤ Large files") })
    #expect(lines.all.compactMap { CleanOutput.section(of: Substring($0)) }.contains("Large files"))
}
