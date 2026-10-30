import SwiftUI

/// Shown instead of the sidebar until Burrow finds a Mole it can read.
struct SetupView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: Space.xl) {
            Image(systemName: "terminal")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            VStack(spacing: Space.sm) {
                Text(title).font(.title2.bold())
                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            CommandText(text: command)
            HStack(spacing: Space.md) {
                CopyButton(text: command)
                Button("Check Again") { Task { await model.locate() } }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Space.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .gridArea("setup")
    }

    private var isTooOld: Bool { if case .tooOld = model.lookup { true } else { false } }

    private var title: String {
        if case .tooOld = model.lookup { "Update Mole to 1.62.0 or later" } else { "Burrow Needs Mole" }
    }

    private var message: String {
        if case .tooOld(let version) = model.lookup {
            return "This Mac has Mole \(version). Burrow reads output that newer versions print. Update it with Homebrew, then check again."
        }
        return "Burrow shows and runs the Mole command line tool. Install it with Homebrew, then check again."
    }

    private var command: String { isTooOld ? "brew upgrade mole" : "brew install mole" }
}
