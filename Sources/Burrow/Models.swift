import Foundation
import Observation
import SwiftUI
import BurrowKit

/// The sidebar pages. Snapshot mode walks through every case.
enum Page: String, CaseIterable, Identifiable {
    case health, space, clean, apps, history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .health: "Health"
        case .space: "Space"
        case .clean: "Clean"
        case .apps: "Apps"
        case .history: "History"
        }
    }

    var symbol: String {
        switch self {
        case .health: "heart.text.square"
        case .space: "chart.pie"
        case .clean: "sparkles"
        case .apps: "square.grid.2x2"
        case .history: "clock.arrow.circlepath"
        }
    }

    /// Command-1 to Command-5.
    var shortcut: KeyEquivalent {
        KeyEquivalent(Character(String((Page.allCases.firstIndex(of: self) ?? 0) + 1)))
    }

    /// Space and Apps arrive in M2.
    var isComingSoon: Bool { self == .space || self == .apps }
}

/// App-wide state that menus, toolbars, and views share.
@Observable
final class AppModel {
    let mole: Mole
    var lookup: MoleLookup = .checking
    var page: Page = Page(rawValue: UserDefaults.standard.string(forKey: "page") ?? "") ?? .health {
        didSet { if !mole.isFixture { UserDefaults.standard.set(page.rawValue, forKey: "page") } }
    }
    let health: HealthModel
    let clean: CleanModel
    let history: HistoryModel
    /// The last command handed to Terminal (the self-test reads it in fixture mode).
    var lastTerminalCommand: TerminalCommand?
    var terminalFailure: TerminalCommand?

    /// Settings reopens on the last tab. Fixture runs leave it alone.
    var settingsTab: SettingsTab = SettingsTab(rawValue: UserDefaults.standard.string(forKey: "settings.tab") ?? "") ?? .general {
        didSet { if !mole.isFixture { UserDefaults.standard.set(settingsTab.rawValue, forKey: "settings.tab") } }
    }

    init(mole: Mole) {
        self.mole = mole
        let runner = Runner(mole: mole)
        health = HealthModel(runner: runner)
        clean = CleanModel(runner: runner)
        history = HistoryModel(runner: runner)
        runner.app = self
    }

    var isReady: Bool { if case .ready = lookup { true } else { false } }

    var moPath: String? { if case .ready(let path, _) = lookup { path } else { nil } }

    /// Looks for `mo`, then loads the page on screen.
    func locate() async {
        lookup = .checking
        let custom = UserDefaults.standard.string(forKey: "moPath")
        lookup = await mole.locate(customPath: mole.isFixture ? nil : custom)
        if isReady { refresh() }
    }

    /// Reads the current page from Mole again (Command-R).
    func refresh() {
        switch page {
        case .health: health.load()
        case .history: history.load()
        case .clean, .space, .apps: break
        }
    }

    func openInTerminal(_ command: TerminalCommand) {
        lastTerminalCommand = command
        terminalFailure = nil
        do { try mole.openInTerminal(command, moPath: moPath ?? "mo") } catch { terminalFailure = command }
    }
}

/// Runs Mole commands for the page models and streams their lines on the main actor.
final class Runner {
    let mole: Mole
    weak var app: AppModel?

    init(mole: Mole) { self.mole = mole }

    func process(_ command: Mole.Command) -> MoleProcess {
        mole.process(command, moPath: app?.moPath ?? "/usr/bin/false")
    }

    /// Runs to the end, delivering each output line in order on the main actor.
    /// A `timeout` stops the command after that many seconds.
    func run(_ process: MoleProcess, timeout: Duration? = nil,
             onLine: @escaping (String) -> Void = { _ in }) async throws -> MoleProcess.Result {
        let (lines, continuation) = AsyncStream<String>.makeStream()
        let consumer = Task { for await line in lines { onLine(line) } }
        let watchdog = timeout.map { limit in
            Task.detached { try await Task.sleep(for: limit); process.stop() }
        }
        defer { watchdog?.cancel() }
        let result = try await process.run { continuation.yield($0) }
        continuation.finish()
        await consumer.value
        return result
    }
}

@Observable
final class HealthModel {
    private let runner: Runner
    var snapshot: StatusSnapshot?
    var updated: Date?
    var isLoading = false
    var failure: MoleFailure?

    init(runner: Runner) { self.runner = runner }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            let command = Mole.Command.status
            do {
                let result = try await runner.run(runner.process(command), timeout: .seconds(10))
                if result.wasStopped {
                    failure = MoleFailure(command: command.display, message: "Mole took longer than 10 seconds.")
                    return
                }
                guard result.status == 0 else {
                    failure = MoleFailure(command: command.display, message: "It exited with code \(result.status).")
                    return
                }
                snapshot = try StatusSnapshot.decode(Data(result.output.utf8))
                updated = .now
                failure = nil
            } catch {
                failure = MoleFailure(command: command.display, message: "Mole's answer could not be read.")
            }
        }
    }
}

@Observable
final class HistoryModel {
    private let runner: Runner
    var history: MoleHistory?
    var selection: String?
    var isLoading = false
    var failure: MoleFailure?

    init(runner: Runner) { self.runner = runner }

    var selectedSession: MoleHistory.Session? {
        history?.sessions.first { $0.id == selection }
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            let command = Mole.Command.history
            do {
                let result = try await runner.run(runner.process(command), timeout: .seconds(20))
                guard result.status == 0, !result.wasStopped else {
                    failure = MoleFailure(command: command.display, message: result.wasStopped
                        ? "Mole took longer than 20 seconds." : "It exited with code \(result.status).")
                    return
                }
                history = try MoleHistory.decode(Data(result.output.utf8))
                failure = nil
            } catch {
                failure = MoleFailure(command: command.display, message: "Mole's answer could not be read.")
            }
        }
    }
}

@Observable
final class CleanModel {
    enum Phase: Equatable {
        case idle
        case previewing
        case previewed
        case cleaning
        case done
    }

    private let runner: Runner
    var phase: Phase = .idle
    /// The `➤ Section` Mole is on, while previewing or cleaning.
    var section = ""
    var preview: CleanPreview?
    var log: [String] = []
    var summary: CleanRunSummary?
    var wasStopped = false
    var failure: MoleFailure?
    var isConfirming = false
    private var running: MoleProcess?

    init(runner: Runner) { self.runner = runner }

    var isBusy: Bool { phase == .previewing || phase == .cleaning }

    /// Clean needs a finished preview from this session that found something.
    var canClean: Bool {
        phase == .previewed && preview.map { !$0.isEmpty } == true
    }

    func runPreview() {
        guard !isBusy else { return }
        phase = .previewing
        section = ""
        preview = nil
        summary = nil
        failure = nil
        wasStopped = false
        log = []
        let started = Date.now
        let command = Mole.Command.cleanPreview
        let process = runner.process(command)
        running = process
        Task {
            defer { running = nil }
            do {
                let result = try await runner.run(process) { line in self.take(line) }
                if result.wasStopped { phase = .idle; return }
                guard result.status == 0 else {
                    failure = MoleFailure(command: command.display, message: "It exited with code \(result.status).")
                    phase = .idle
                    return
                }
                preview = CleanPreview(listFile: readList(since: started), output: result.output, home: runner.mole.home)
                phase = .previewed
            } catch {
                failure = MoleFailure(command: command.display, message: "Mole could not be started.")
                phase = .idle
            }
        }
    }

    /// The list file, if this preview wrote it. An older file is another run's.
    private func readList(since start: Date) -> String {
        let url = runner.mole.cleanListURL
        if !runner.mole.isFixture {
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            guard let modified, modified >= start.addingTimeInterval(-2) else { return "" }
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    /// Runs `mo clean`, only after the confirmation dialog.
    func runClean() {
        guard canClean else { return }
        isConfirming = false
        phase = .cleaning
        section = ""
        log = []
        wasStopped = false
        failure = nil
        let command = Mole.Command.clean
        let process = runner.process(command)
        running = process
        Task {
            defer { running = nil }
            do {
                let result = try await runner.run(process) { line in self.take(line) }
                summary = CleanRunSummary(output: result.output)
                wasStopped = result.wasStopped
                if result.status != 0, !result.wasStopped {
                    failure = MoleFailure(command: command.display, message: "It exited with code \(result.status).")
                }
            } catch {
                failure = MoleFailure(command: command.display, message: "Mole could not be started.")
            }
            preview = nil
            phase = .done
            runner.app?.history.load()
        }
    }

    func stop() { running?.stop() }

    private func take(_ line: String) {
        log.append(line)
        if let name = CleanOutput.section(of: Substring(line)) { section = name }
    }
}
