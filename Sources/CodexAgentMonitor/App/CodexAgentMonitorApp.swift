import SwiftUI

@main
struct CodexAgentMonitorApp: App {
    @StateObject private var model = MonitorViewModel()

    var body: some Scene {
        MenuBarExtra {
            MonitorMenuView(model: model)
                .frame(width: 420)
        } label: {
            Label("Codex", systemImage: iconName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
                .frame(width: 420)
        }
    }

    private var iconName: String {
        switch model.state.health {
        case .healthy: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }
}
