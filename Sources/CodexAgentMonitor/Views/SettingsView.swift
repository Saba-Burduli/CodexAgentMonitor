import CodexAgentMonitorCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: MonitorViewModel

    var body: some View {
        Form {
            Section("Event Source") {
                TextField("Event log path", text: $model.eventLogPath)
                    .textFieldStyle(.roundedBorder)
                Text(ObserveOnlyPolicy.summary)
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

            Section("Observe-Only Policy") {
                Text("Forbidden operations")
                    .font(.caption.weight(.semibold))
                Text(ObserveOnlyPolicy.forbiddenOperations.sorted().joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Allowed monitor operations")
                    .font(.caption.weight(.semibold))
                Text(ObserveOnlyPolicy.allowedOperations.sorted().joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
    }
}
