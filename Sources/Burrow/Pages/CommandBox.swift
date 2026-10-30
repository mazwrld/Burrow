import AppKit
import SwiftUI
import BurrowKit

/// A command in monospace that people can select.
struct CommandText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.body.monospaced())
            .textSelection(.enabled)
            .padding(.horizontal, Space.sm)
            .padding(.vertical, Space.xs)
            .background(.quaternary, in: .rect(cornerRadius: 4))
    }
}

/// "Copy Command", then "Copied" for two seconds.
struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button(copied ? "Copied" : "Copy Command") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
        .help("Copy the exact command")
    }
}

/// A step Burrow cannot do: the command, Copy Command, and Open in Terminal.
struct CommandBox: View {
    @Environment(AppModel.self) private var model
    let command: TerminalCommand

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.sm) {
                CommandText(text: command.display)
                CopyButton(text: command.display)
                Button("Open in Terminal") { model.openInTerminal(command) }
                    .help("Run this command in a new Terminal window")
            }
            if model.terminalFailure == command {
                Text("Burrow can't open Terminal. Copy the command and paste it into Terminal.")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// A failed Mole command, inline, with what to do next.
struct FailureRow: View {
    let failure: MoleFailure
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label {
                Text("Unable to run `\(failure.command)`. \(failure.message)")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
            HStack(spacing: Space.sm) {
                CopyButton(text: failure.command)
                Button("Try Again", action: retry)
            }
        }
    }
}
