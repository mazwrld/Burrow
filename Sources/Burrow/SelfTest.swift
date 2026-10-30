import AppKit
import BurrowKit

/// Self-test for agents: runs the app's real flows on fixture output,
/// prints PASS or FAIL per check, and quits with exit code 0 or 1.
///   APP_FIXTURES=Tests/Fixtures ~/Applications/Burrow.app/Contents/MacOS/Burrow --selftest
/// (tools/selftest.sh does this.) Fixture mode never runs `mo`.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    /// Read by AppDelegate.applicationWillTerminate.
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: AppModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        guard model.mole.isFixture else {
            print("SELFTEST refused: set APP_FIXTURES to the fixtures folder")
            finish(code: 1)
            return
        }
        Task {
            // S-001
            check("finds Mole and reads its version", model.lookup == .ready(path: "/fixtures/mo", version: MoleVersion(major: 1, minor: 64, patch: 0)))

            // S-007
            for page in Page.allCases {
                model.page = page
                check("Command-\(page.shortcut.character) shows \(page.title)", model.page == page)
            }

            // S-002
            model.page = .health
            model.health.load()
            await until { model.health.snapshot != nil || model.health.failure != nil }
            check("Health reads a snapshot", model.health.snapshot?.healthScore != nil)
            check("Health shows the startup disk", model.health.snapshot?.startupDisk?.mount == "/")

            // S-003
            let clean = model.clean
            check("Clean is disabled before a preview", !clean.canClean)
            clean.runPreview()
            check("Clean is disabled while previewing", !clean.canClean && clean.isBusy)
            await until { !clean.isBusy }
            check("preview finishes", clean.phase == .previewed)
            check("preview has groups", (clean.preview?.groups.count ?? 0) > 3)
            check("preview total is 4.14 GB", clean.preview?.totals?.size.short == MoleSize(bytes: 4_140_000_000).short)
            check("preview notes the Trash", clean.preview?.emptiesTrash == true)
            check("preview reads the section names", clean.log.contains { $0.contains("➤ Large files") }, "\(clean.log.count) lines: \(clean.log.suffix(12))")

            // S-004
            check("Clean is enabled after a preview", clean.canClean)
            clean.isConfirming = true
            clean.runClean()
            check("confirming starts the clean", clean.phase == .cleaning)
            await until { clean.phase == .done }
            check("done shows the freed size", clean.summary?.freed == MoleSize(bytes: 4_020_000_000))
            check("done shows admin cleanup skipped", clean.summary?.adminSkipped == true)
            check("Clean needs a new preview after a run", !clean.canClean)

            // S-005
            await until { model.history.history != nil && !model.history.isLoading }
            check("History lists runs", (model.history.history?.sessions.count ?? 0) > 0, "\(String(describing: model.history.failure)) loading=\(model.history.isLoading)")
            check("History marks previews", model.history.history?.sessions.contains { $0.isPreview } == true)

            // S-006
            model.openInTerminal(.uninstall(name: "google chrome"))
            check("Open in Terminal quotes names", model.lastTerminalCommand?.display == "mo uninstall 'google chrome'")

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    /// Waits up to 10 seconds for a condition.
    private static func until(_ condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    private static func check(_ name: String, _ ok: Bool, _ detail: String = "") {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)\(detail.isEmpty ? "" : ": \(detail)")")
    }

    /// Quits through NSApp.terminate, never exit(), and closes sheets first:
    /// an open sheet refuses terminate, and the run would wait forever.
    static func finish(code: Int32) {
        exitCode = code
        for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
        NSApp.terminate(nil)
    }
}
