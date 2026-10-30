import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Screenshot mode for agents.
///   APP_FIXTURES=Tests/Fixtures APP_SNAPSHOT=/tmp/shots ~/Applications/Burrow.app/Contents/MacOS/Burrow
/// writes <shot>-light.png and <shot>-dark.png for every page and state in
/// docs/STORIES.md, plus settings-<tab>-<mode>.png, then quits.
/// Each PNG gets a <shot>-<mode>-layout.json with the grid probes (tools/check-layout.swift).
/// APP_SNAPSHOT_PAGES=01-health,settings limits the shots. Fixture mode never runs `mo`.
enum Snapshot {
    static func runIfRequested(model: AppModel, openSettings: OpenSettingsAction) {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["APP_SNAPSHOT"], !dir.isEmpty else { return }
        // Snapshots never run the real Mole: a clean state would clean this Mac.
        guard model.mole.isFixture else {
            print("SNAPSHOT refused: set APP_FIXTURES to the fixtures folder")
            NSApp.terminate(nil)
            return
        }
        let only = env["APP_SNAPSHOT_PAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        func wanted(_ name: String) -> Bool { only?.contains(name) ?? true }
        Task {
            // A sleeping display gives screencapture nothing. Declaring user
            // activity wakes it; the assertion keeps it on until the run quits.
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            var awake: IOPMAssertionID = 0
            IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                        IOPMAssertionLevel(kIOPMAssertionLevelOn), "Snapshots" as CFString, &awake)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? await Task.sleep(for: .seconds(1.5))
            let clean = model.clean
            @MainActor func shot(_ name: String, mode: String, window: NSWindow? = nil) async {
                guard wanted(name) else { return }
                try? await Task.sleep(for: .seconds(0.8))
                capture(to: "\(dir)/\(name)-\(mode).png", window: window)
            }
            @MainActor func wait(_ done: () -> Bool) async {
                for _ in 0..<200 where !done() { try? await Task.sleep(for: .milliseconds(50)) }
            }
            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                let ready = model.lookup
                model.lookup = .missing
                await shot("00-setup", mode: mode)
                model.lookup = ready
                model.page = .health
                await wait { model.health.snapshot != nil }
                await shot("01-health", mode: mode)

                model.page = .clean
                clean.phase = .idle
                await shot("clean-empty", mode: mode)
                clean.phase = .previewing
                clean.section = "Browsers"
                await shot("03-clean-scanning", mode: mode)
                clean.phase = .idle
                clean.runPreview()
                await wait { clean.phase == .previewed }
                await shot("02-clean-preview", mode: mode)
                clean.isConfirming = true
                try? await Task.sleep(for: .seconds(2))
                let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
                await shot("04-clean-confirm", mode: mode, window: main?.attachedSheet ?? main)
                clean.isConfirming = false
                try? await Task.sleep(for: .seconds(0.5))
                let previewed = clean.preview
                clean.phase = .cleaning
                clean.section = "Developer tools"
                clean.log = Array(((try? String(contentsOf: model.mole.fixtures!.appending(path: "clean-run.txt"), encoding: .utf8)) ?? "")
                    .split(separator: "\n", omittingEmptySubsequences: false).prefix(16).map(String.init))
                await shot("05-clean-running", mode: mode)
                clean.phase = .previewed
                clean.preview = previewed
                clean.runClean()
                await wait { clean.phase == .done }
                await shot("06-clean-done", mode: mode)

                model.page = .history
                await wait { model.history.history != nil }
                model.history.selection = model.history.history?.sessions
                    .first { !(model.history.history?.deletions(for: $0).isEmpty ?? true) }?.id
                await shot("07-history", mode: mode)
                model.page = .space
                await shot("08-space", mode: mode)
                model.page = .apps
                await shot("10-apps", mode: mode)
            }
            if wanted("settings") {
                let main = NSApp.windows.first { $0.canBecomeMain && !$0.isSheet }
                openSettings()
                try? await Task.sleep(for: .seconds(1))
                for mode in ["light", "dark"] {
                    NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                    for tab in SettingsTab.allCases {
                        model.settingsTab = tab
                        try? await Task.sleep(for: .seconds(0.8))
                        let settings = NSApp.windows.first { $0.isVisible && $0 !== main && !$0.isSheet }
                        capture(to: "\(dir)/settings-\(tab.rawValue)-\(mode).png", window: settings)
                    }
                }
            }
            print("SNAPSHOT done \(dir)")
            // An open sheet refuses terminate, and the run would wait forever.
            for window in NSApp.windows { if let sheet = window.attachedSheet { window.endSheet(sheet) } }
            NSApp.terminate(nil)
        }
    }

    /// Captures the real window with screencapture, so glass, sidebars, and
    /// materials look exactly as on screen. That needs Screen Recording
    /// permission for the app that started this one (your terminal, or Claude).
    /// Without it, falls back to drawing the view hierarchy, which leaves
    /// sidebars and glass blank.
    private static func capture(to path: String, window: NSWindow? = nil) {
        // Another app can hide this one while snapshots run (computer use hides
        // apps it does not control). Hidden windows cannot be captured.
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        guard let window = window ?? NSApp.windows.first(where: { $0.canBecomeMain && !$0.isSheet }) else {
            print("SNAPSHOT no window")
            return
        }
        // Active, like a window someone is using: real accent colors and focus rings.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        let size = window.contentView?.bounds.size ?? .zero
        GridProbes.shared.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)
        try? FileManager.default.removeItem(atPath: path)
        // The first capture of a run sometimes misses the window. Try three times.
        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback: no Screen Recording permission, sidebars and glass are blank)")
        }
    }
}
