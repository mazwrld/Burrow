import SwiftUI
import BurrowKit

/// S-005: every Mole run, newest first, and the items a selected run removed.
struct HistoryView: View {
    @Environment(AppModel.self) private var model

    private var history: HistoryModel { model.history }

    var body: some View {
        @Bindable var history = history
        Group {
            if let data = history.history {
                if data.sessions.isEmpty {
                    ContentUnavailableView("No Mole Runs Yet", systemImage: "clock.arrow.circlepath",
                                           description: Text("Runs from Burrow and from Terminal show here."))
                } else {
                    VSplitView {
                        runs(data.sessions.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }, selection: $history.selection)
                            .frame(minHeight: 160)
                        detail(data)
                            .frame(minHeight: 160)
                    }
                }
            } else if let failure = history.failure {
                FailureRow(failure: failure) { history.load() }
                    .padding(Space.margin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Reading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") { history.load() }
                    .help("Read history from Mole again (⌘R)")
                    .disabled(history.isLoading)
            }
        }
    }

    private func runs(_ sessions: [MoleHistory.Session], selection: Binding<String?>) -> some View {
        Table(sessions, selection: selection) {
            TableColumn("Command") { s in
                HStack(spacing: Space.sm) {
                    Text(s.baseCommand)
                    if s.isPreview { Badge(text: "Preview") }
                }
                .foregroundStyle(s.isPreview ? .secondary : .primary)
            }
            TableColumn("Started") { s in
                Text(s.start?.formatted(.dateTime.month(.abbreviated).day().hour().minute()) ?? s.startedAt)
            }
            TableColumn("Freed") { s in
                Text(s.size.flatMap { MoleSize($0) }.flatMap { $0.bytes > 0 ? $0.short : nil } ?? "–").monospacedDigit()
                    .foregroundStyle(s.isPreview ? .secondary : .primary)
            }
            .alignment(.trailing)
            TableColumn("Deleted") { s in count(s.actions?.removed) }.alignment(.trailing)
            TableColumn("Moved to Trash") { s in count(s.actions?.trashed) }.alignment(.trailing)
            TableColumn("Skipped") { s in count(s.actions?.skipped) }.alignment(.trailing)
            TableColumn("Failed") { s in count(s.actions?.failed) }.alignment(.trailing)
        }
    }

    private func count(_ n: Int?) -> some View {
        Text(n.map(String.init) ?? "–").monospacedDigit()
    }

    @ViewBuilder
    private func detail(_ data: MoleHistory) -> some View {
        if let session = history.selectedSession {
            let items = data.deletions(for: session)
            if items.isEmpty {
                ContentUnavailableView(session.isPreview ? "A Preview Removes Nothing" : "No Items Recorded",
                                       systemImage: "doc.text.magnifyingglass",
                                       description: Text(session.isPreview
                                           ? "This run only looked."
                                           : "Mole logged no deletions for this run in the last 200 entries."))
            } else {
                List(items) { item in
                    HStack(spacing: Space.sm) {
                        Text(item.path).lineLimit(1).truncationMode(.middle).help(item.path)
                        Spacer()
                        Text(item.sizeKb.map { ByteCountFormatter.string(fromByteCount: $0 * 1024, countStyle: .file) } ?? "–")
                            .monospacedDigit().foregroundStyle(.secondary)
                        Text(status(item)).foregroundStyle(.secondary)
                            .frame(minWidth: 112, alignment: .leading)
                    }
                }
            }
        } else {
            ContentUnavailableView("No Run Selected", systemImage: "sidebar.right",
                                   description: Text("Select a run to see what it removed."))
        }
    }

    private func status(_ d: MoleHistory.Deletion) -> String {
        switch d.status {
        case "ok": d.movedToTrash ? "Moved to Trash" : "Deleted"
        case "dry-run": "Preview"
        default: "Kept: \(d.status)"
        }
    }
}

/// A small word in a capsule, so meaning never rests on gray alone.
struct Badge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, Space.sm)
            .background(.quaternary, in: .capsule)
    }
}
