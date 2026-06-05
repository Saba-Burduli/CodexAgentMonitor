import CodexAgentMonitorCore
import Foundation
import SwiftUI

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published private(set) var state: MonitorState
    @Published var eventLogPath: String
    @Published var isDemoMode = true
    @Published var tabs = MonitorTabState()
    @Published private(set) var gitActivity: [GitCommitStatus] = []
    @Published private(set) var gitActivityUnavailableReason: String?

    nonisolated(unsafe) private var timer: Timer?
    private let repositoryURL: URL

    init(
        eventLogPath: String = MonitorViewModel.defaultEventLogPath,
        repositoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    ) {
        self.eventLogPath = eventLogPath
        self.repositoryURL = repositoryURL
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
        refreshGitActivity()
    }

    private func refreshGitActivity() {
        do {
            gitActivity = try LocalGitStatusProvider(repositoryURL: repositoryURL).recentGitActivity(limit: 3)
            gitActivityUnavailableReason = gitActivity.isEmpty ? "No local commits found" : nil
        } catch {
            gitActivity = []
            gitActivityUnavailableReason = "Git activity unavailable"
        }
    }

    func revealEventDirectory() {
        let url = URL(fileURLWithPath: (eventLogPath as NSString).expandingTildeInPath).deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openSettingsTab() {
        tabs.open(.settings)
    }

    func selectTab(_ kind: MonitorTabKind) {
        tabs.select(kind)
    }

    func closeTab(_ kind: MonitorTabKind) {
        tabs.close(kind)
    }

    static let defaultEventLogPath = "~/.codex-agent-monitor/events.jsonl"
}
