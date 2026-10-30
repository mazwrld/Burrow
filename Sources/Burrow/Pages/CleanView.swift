import AppKit
import SwiftUI
import BurrowKit

/// S-003 and S-004: preview `mo clean`, confirm, run it, and show what it freed.
struct CleanView: View {
    @Environment(AppModel.self) private var model

    private var clean: CleanModel { model.clean }

    var body: some View {
        @Bindable var clean = clean
        content
            .navigationTitle("Clean")
            .toolbar {
                ToolbarItemGroup {
                    if clean.isBusy {
                        Button("Stop", systemImage: "stop.fill") { clean.stop() }
                            .help("Stop Mole now")
                    } else {
                        Button("Preview", systemImage: "eye") { clean.runPreview() }
                            .help("See what Mole can clean. Nothing is removed (⇧⌘P)")
                    }
                    Button(cleanTitle) { clean.isConfirming = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!clean.canClean)
                        .help(clean.canClean ? "Delete the previewed items for good" : "Preview first to see what will be cleaned")
                }
            }
            .confirmationDialog(confirmTitle, isPresented: $clean.isConfirming, titleVisibility: .visible) {
                Button("Clean", role: .destructive) { clean.runClean() }
                Button("Cancel", role: .cancel) {}
                    .keyboardShortcut(.defaultAction)
            } message: {
                Text(confirmMessage)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch clean.phase {
        case .idle:
            if let failure = clean.failure {
                FailureRow(failure: failure) { clean.runPreview() }
                    .padding(Space.margin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Clean", systemImage: "sparkles")
                } description: {
                    Text("Preview shows what Mole can clean. Nothing is removed.")
                } actions: {
                    Button("Preview") { clean.runPreview() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        case .previewing:
            Working(title: "Previewing…", section: clean.section)
        case .previewed:
            if let preview = clean.preview { PreviewList(preview: preview) }
        case .cleaning:
            VStack(alignment: .leading, spacing: 0) {
                Working(title: "Cleaning…", section: clean.section)
                    .frame(height: 120)
                Divider()
                LogView(lines: clean.log)
            }
        case .done:
            DoneView()
        }
    }

    private var size: String { clean.preview?.totals?.size.short ?? "" }
    private var cleanTitle: String { clean.canClean && !size.isEmpty ? "Clean \(size)" : "Clean" }
    private var confirmTitle: String { size.isEmpty ? "Clean?" : "Clean \(size)?" }

    private var confirmMessage: String {
        var text = "Files are deleted for good. They do not go to the Trash."
        if clean.preview?.emptiesTrash == true { text += " Cleaning also empties the Trash." }
        return text
    }
}

/// A spinner with the section Mole is on.
private struct Working: View {
    let title: String
    let section: String

    var body: some View {
        VStack(spacing: Space.sm) {
            ProgressView()
            Text(title).font(.headline)
            Text(section.isEmpty ? " " : section)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The groups Mole would clean, biggest first, plus what this run leaves alone.
private struct PreviewList: View {
    @Environment(AppModel.self) private var model
    let preview: CleanPreview

    private var groups: [CleanGroup] { preview.groups.sorted { $0.total > $1.total } }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(headline).font(.title2.bold()).monospacedDigit()
                    if preview.emptiesTrash {
                        Label("Cleaning also empties the Trash.", systemImage: "trash")
                            .foregroundStyle(.secondary)
                    }
                    if preview.adminSkipped {
                        Label("Admin cleanup is not in this preview. It needs your password, so it runs in Terminal.",
                              systemImage: "lock")
                            .foregroundStyle(.secondary)
                        CommandBox(command: .clean)
                    }
                }
                .padding(.vertical, Space.xs)
            }
            if groups.isEmpty {
                Text("Nothing to clean right now").foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                DisclosureGroup {
                    ForEach(group.items.sorted { ($0.size?.bytes ?? 0) > ($1.size?.bytes ?? 0) }) { item in
                        ItemRow(item: item, home: model.mole.home)
                    }
                } label: {
                    HStack {
                        Text(group.name)
                        Spacer()
                        Text("\(group.items.count) items").foregroundStyle(.secondary)
                        Text(MoleSize(bytes: group.total).short)
                            .monospacedDigit()
                            .frame(minWidth: 72, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            if !preview.advice.isEmpty {
                Section("Not cleaned by this run") {
                    ForEach(preview.advice) { advice in
                        LabeledContent {
                            Text(advice.detail).lineLimit(1).truncationMode(.middle).help(advice.detail)
                        } label: {
                            Text(advice.title)
                        }
                    }
                    if preview.advice.contains(where: { $0.section == "Project artifacts" }) {
                        Text("Run `mo purge` to remove build folders.").foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var headline: String {
        guard let totals = preview.totals else { return "Nothing to clean right now" }
        return "\(totals.size.display) in \(totals.items) items"
    }
}

private struct ItemRow: View {
    let item: CleanItem
    let home: String

    private var shown: String {
        item.path.hasPrefix(home + "/") ? "~" + item.path.dropFirst(home.count) : item.path
    }

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(shown)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(item.path)
            Spacer()
            Text(item.size?.short ?? "Unknown")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Button("Reveal in Finder", systemImage: "magnifyingglass") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Show this item in Finder")
        }
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
            }
        }
    }
}

/// The streamed output of a run, newest line in view.
private struct LogView: View {
    let lines: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .id(index)
                    }
                }
                .padding(Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onChange(of: lines.count) { proxy.scrollTo(lines.count - 1, anchor: .bottom) }
        }
    }
}

/// After `mo clean`: what it freed, what it skipped, and the way to History.
private struct DoneView: View {
    @Environment(AppModel.self) private var model
    @State private var showLog = false

    private var clean: CleanModel { model.clean }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text(headline).font(.title2.bold()).monospacedDigit()
                    if let free = clean.summary?.freeSpace {
                        Text("Free space: \(free)").foregroundStyle(.secondary).monospacedDigit()
                    }
                    if let problem = clean.summary?.problem {
                        Label(problem, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Space.xs)
                .accessibilityElement(children: .combine)
                Button("See in History") { model.page = .history }
            }
            if let failure = clean.failure {
                Section { FailureRow(failure: failure) { clean.runPreview() } }
            }
            if clean.summary?.adminSkipped == true {
                Section("Admin cleanup skipped") {
                    Text("It needs your password. Run it in Terminal, where Mole asks for it.")
                        .foregroundStyle(.secondary)
                    CommandBox(command: .clean)
                }
            }
            Section {
                DisclosureGroup("Mole's output", isExpanded: $showLog) {
                    Text(clean.log.joined(separator: "\n"))
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var headline: String {
        if clean.wasStopped { return "Stopped. Some items were already deleted." }
        if let freed = clean.summary?.freed { return "Freed \(freed.display)" }
        if clean.summary?.alreadyClean == true { return "Nothing to clean right now" }
        return "Clean finished"
    }
}
