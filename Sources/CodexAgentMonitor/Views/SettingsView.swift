import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MonitorViewModel

    var body: some View {
        Form {
            Section("Event Source") {
                TextField("Event log path", text: $model.eventLogPath)
                    .textFieldStyle(.roundedBorder)
                Text("The app observes JSONL events only. It does not control Codex agents or execute external systems.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Folder") { model.revealEventDirectory() }
                    Button("Refresh Now") { model.refresh() }
                }
            }

            Section("Health Rules") {
                Text("Green: no blocked agents and quota is healthy.")
                Text("Yellow: token usage is spiking or remaining quota is at or below 20%.")
                Text("Red: blocked/error agents, permission warnings, rate limits at 95%, or quota at or below 5%.")
            }
            .font(.caption)
        }
        .padding(20)
    }
}
