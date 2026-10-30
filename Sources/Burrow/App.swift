import AppKit
import SwiftUI

// Burrow
//   Burrow                          the app; runs the real `mo`
//   APP_FIXTURES=<dir> Burrow       read Mole output from fixture files instead (Tests/Fixtures); never runs `mo`
//   APP_SNAPSHOT=<dir> Burrow       with APP_FIXTURES: save a PNG of every page and state in light and dark, then quit
//   Burrow --selftest               with APP_FIXTURES: run the self-test and quit with 0 or 1 (tools/selftest.sh)
//   APP_ACCENT=<id> Burrow          run with another accent from Theme.all (UI/Theme.swift)
//   APP_GRID=1 Burrow               draw the grid and the layout probes over the window

@main
struct BurrowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel(mole: Mole.fromEnvironment())

    var body: some Scene {
        Window("Burrow", id: "main") {
            ContentView()
                .environment(model)
                .themed()
                .overlay { if GridOverlay.enabled { GridOverlay() } }
                .frame(minWidth: 760, minHeight: 480)
        }
        .defaultSize(width: 1100, height: 720)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Clean") {
                Button("Preview") { model.page = .clean; model.clean.runPreview() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                    .disabled(!model.isReady || model.clean.isBusy)
            }
            CommandGroup(after: .toolbar) {
                Button("Refresh") { model.refresh() }
                    .keyboardShortcut("r")
                    .disabled(!model.isReady)
                Divider()
                ForEach(Page.allCases) { page in
                    Button(page.title) { model.page = page }
                        .keyboardShortcut(page.shortcut)
                }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
                .themed()
        }
        .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Started from a terminal, the process is not a foreground app yet.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// The self-test's result becomes the exit code, after a normal quit.
    func applicationWillTerminate(_ notification: Notification) {
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
