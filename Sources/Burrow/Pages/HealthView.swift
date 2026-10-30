import SwiftUI
import BurrowKit

/// S-002: disk, memory, CPU, battery, and the top processes from `mo status --json`.
struct HealthView: View {
    @Environment(AppModel.self) private var model

    private var health: HealthModel { model.health }

    var body: some View {
        Group {
            if let snapshot = health.snapshot {
                content(snapshot)
            } else if let failure = health.failure {
                FailureRow(failure: failure) { health.load() }
                    .padding(Space.margin)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Reading health…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Health")
        .navigationSubtitle(subtitle)
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") { health.load() }
                    .help("Read health from Mole again (⌘R)")
                    .disabled(health.isLoading)
            }
        }
    }

    private var subtitle: String {
        guard let updated = health.updated else { return "" }
        return "Updated " + updated.formatted(.relative(presentation: .named))
    }

    private func content(_ s: StatusSnapshot) -> some View {
        Form {
            if let failure = health.failure {
                Section { FailureRow(failure: failure) { health.load() } }
            }
            Section {
                LabeledContent {
                    Text(s.healthScoreMsg ?? "")
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Text(s.healthScore.map(String.init) ?? "–")
                            .font(.system(size: 32, weight: .semibold).monospacedDigit())
                        Text("Health score").foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            Section {
                if let disk = s.startupDisk {
                    MeterRow(title: "Disk", fraction: (disk.usedPercent ?? 0) / 100,
                             value: disk.free.map { "\(bytes($0)) free of \(bytes(disk.total ?? 0))" } ?? "Unknown")
                }
                if let memory = s.memory {
                    MeterRow(title: "Memory", fraction: (memory.usedPercent ?? 0) / 100,
                             value: memoryText(memory))
                }
                if let cpu = s.cpu {
                    MeterRow(title: "CPU", fraction: (cpu.usage ?? 0) / 100,
                             value: "\(percent(cpu.usage)) used" + (cpu.coreCount.map { " · \($0) cores" } ?? ""))
                }
                if let battery = s.batteries?.first {
                    MeterRow(title: "Battery", fraction: (battery.percent ?? 0) / 100,
                             value: batteryText(battery))
                }
            }
            if let processes = s.topProcesses, !processes.isEmpty {
                Section("Top Processes") {
                    ForEach(processes.prefix(5)) { p in
                        LabeledContent {
                            Text("\(percent(p.cpu)) CPU · \(bytes(p.memoryBytes ?? 0))")
                                .monospacedDigit()
                        } label: {
                            Text(p.name).lineLimit(1).truncationMode(.middle).help(p.name)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func memoryText(_ m: StatusSnapshot.Memory) -> String {
        var text = "\(bytes(m.used ?? 0)) of \(bytes(m.total ?? 0))"
        if let pressure = m.pressure, !pressure.isEmpty { text += " · pressure \(pressure)" }
        return text
    }

    private func batteryText(_ b: StatusSnapshot.Battery) -> String {
        var parts = [percent(b.percent)]
        if let status = b.status, !status.isEmpty { parts.append(status) }
        if let health = b.health, !health.isEmpty { parts.append("health \(health.lowercased())") }
        return parts.joined(separator: " · ")
    }

    private func bytes(_ n: Int64) -> String { ByteCountFormatter.string(fromByteCount: n, countStyle: .file) }
    private func percent(_ v: Double?) -> String { v.map { "\(Int($0.rounded()))%" } ?? "–" }
}

/// A labeled bar with its value in words, so color is never the only signal.
struct MeterRow: View {
    let title: String
    let fraction: Double
    let value: String

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: Space.md) {
                Text(value).monospacedDigit().foregroundStyle(.secondary)
                ProgressView(value: min(max(fraction, 0), 1))
                    .frame(width: 120)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}
