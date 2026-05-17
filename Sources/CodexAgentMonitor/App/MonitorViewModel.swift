import CodexAgentMonitorCore
import Foundation
import SwiftUI

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published private(set) var state: MonitorState
    @Published var eventLogPath: String
    @Published var isDemoMode = true

    nonisolated(unsafe) private var timer: Timer?

    init(eventLogPath: String = MonitorViewModel.defaultEventLogPath) {
        self.eventLogPath = eventLogPath
        self.state = DemoTelemetry.state()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func refresh() {
        let url = URL(fileURLWithPath: (eventLogPath as NSString).expandingTildeInPath)
        if let loaded = EventLogReader(url: url).readState() {
            state = loaded
            isDemoMode = false
        } else {
            state = DemoTelemetry.state()
            isDemoMode = true
        }
    }

    func revealEventDirectory() {
        let url = URL(fileURLWithPath: (eventLogPath as NSString).expandingTildeInPath).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static let defaultEventLogPath = "~/.codex-agent-monitor/events.jsonl"
}
