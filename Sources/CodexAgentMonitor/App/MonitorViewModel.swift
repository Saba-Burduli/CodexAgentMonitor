import CodexAgentMonitorCore
import Foundation
import SwiftUI

@MainActor
final class MonitorViewModel: ObservableObject {
    @Published private(set) var state: MonitorState
    @Published var eventLogPath: String
    @Published var isDemoMode = true
    @Published var tabs = MonitorTabState()
    @Published var selectedSessionId: String?
    @Published private(set) var gitActivity: [GitCommitStatus] = []
    @Published private(set) var gitActivityUnavailableReason: String?
    @Published private(set) var skillStatus = SkillStatus()

    nonisolated(unsafe) private var timer: Timer?
    private let repositoryURL: URL

    init(
        eventLogPath: String = MonitorViewModel.defaultEventLogPath,
        repositoryURL: URL = MonitorViewModel.defaultRepositoryURL()
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
        let monitorState = EventLogReader(url: url).readState()
        let codexState = CodexCLIStateReader().readLatestState()

        if let codexState {
            state = merge(primary: codexState, overlay: monitorState)
            isDemoMode = false
        } else if let monitorState {
            state = monitorState
            isDemoMode = false
        } else {
            state = DemoTelemetry.state()
            isDemoMode = true
        }
        refreshGitActivity()
        refreshSkillStatus()
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

    private func refreshSkillStatus() {
        let skillsURL = repositoryURL.appendingPathComponent(".agents/skills")
        skillStatus = (try? LocalSkillStatusProvider(skillsRootURL: skillsURL).skillStatus()) ?? SkillStatus()
    }

    private func merge(primary: MonitorState, overlay: MonitorState?) -> MonitorState {
        guard let overlay else { return primary }
        return MonitorState(
            agents: primary.agents + overlay.agents,
            usage: primary.usage.total > 0 ? primary.usage : overlay.usage,
            permissions: primary.permissions + overlay.permissions,
            diagnostics: primary.diagnostics + overlay.diagnostics,
            sessionActivities: Array((primary.sessionActivities + overlay.sessionActivities).suffix(200)),
            lastEventAt: [primary.lastEventAt, overlay.lastEventAt].compactMap(\.self).max()
        )
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

    func selectSession(_ id: String) {
        selectedSessionId = id.isEmpty ? nil : id
    }

    func setSkill(_ name: String, enabled: Bool) {
        let skillsURL = repositoryURL.appendingPathComponent(".agents/skills")
        try? LocalSkillStatusProvider(skillsRootURL: skillsURL).setSkill(name, enabled: enabled)
        refreshSkillStatus()
    }

    static let defaultEventLogPath = "~/.codex-agent-monitor/events.jsonl"

    private static func defaultRepositoryURL() -> URL {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app", bundleURL.deletingLastPathComponent().lastPathComponent == "dist" {
            return bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }
}
