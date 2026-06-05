import CodexAgentMonitorCore
import SwiftUI

struct MonitorMenuView: View {
    @ObservedObject var model: MonitorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView(health: model.state.health, isDemoMode: model.isDemoMode)
            MonitorTabBar(model: model)

            switch model.tabs.selected {
            case .overview:
                OverviewTabView(model: model)
            case .settings:
                SettingsView(model: model)
                    .frame(minHeight: 280)
            }

            Divider()

            HStack {
                Button("Refresh") { model.refresh() }
                Button("Settings") { model.openSettingsTab() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .accessibilityIdentifier("monitor.menu.root")
    }
}

private struct MonitorTabBar: View {
    @ObservedObject var model: MonitorViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(model.tabs.tabs) { tab in
                MonitorTabItem(
                    tab: tab,
                    isSelected: model.tabs.selected == tab.kind,
                    select: { model.selectTab(tab.kind) },
                    close: { model.closeTab(tab.kind) }
                )
            }
            Spacer()
        }
        .accessibilityIdentifier("monitor.tabs")
    }
}

private struct MonitorTabItem: View {
    var tab: MonitorTab
    var isSelected: Bool
    var select: () -> Void
    var close: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(tab.title, action: select)
                .buttonStyle(.plain)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)

            if tab.isClosable {
                Button("x", action: close)
                    .buttonStyle(.plain)
                    .font(.caption2.weight(.bold))
                    .accessibilityLabel("Close \(tab.title)")
            }
        }
        .background(isSelected ? Color.secondary.opacity(0.16) : Color.clear, in: Capsule())
        .accessibilityIdentifier("monitor.tab.\(tab.kind.rawValue)")
    }
}

private struct OverviewTabView: View {
    @ObservedObject var model: MonitorViewModel

    var body: some View {
        let adapter = MonitorStateCodexDashboardAdapter(state: model.state)
        let agents = (try? adapter.agentStatuses()) ?? []
        let sessions = (try? adapter.sessions()) ?? []
        let selectedSessionId = effectiveSessionId(selected: model.selectedSessionId, sessions: sessions)
        let visibleAgents = selectedSessionId.map { id in agents.filter { $0.sessionId == id } } ?? agents
        let tokenStatus = (try? adapter.tokenStatus(for: selectedSessionId)) ?? nil
        let permissionStatus = (try? adapter.permissionStatus()) ?? PermissionStatus()

        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Active Session", value: selectedSessionId ?? "Unavailable")
            SessionPicker(sessions: sessions, selectedSessionId: selectedSessionId) { model.selectSession($0) }

            SectionHeader(title: "Codex Agents", value: "\(visibleAgents.count)")
            if visibleAgents.isEmpty {
                EmptyStateView(text: "No active Codex agents observed")
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleAgents) { agent in
                        CodexAgentRow(agent: agent)
                    }
                }
            }

            SectionHeader(title: "Sessions", value: "\(sessions.count)")
            CodexSessionList(sessions: sessions)

            SectionHeader(title: "Context", value: tokenStatus?.contextUsedPercent.map { "\(Int($0))%" } ?? "Unavailable")
            CodexContextView(tokenStatus: tokenStatus)

            SectionHeader(title: "Latest Git Activity", value: model.gitActivity.isEmpty ? "Unavailable" : "\(model.gitActivity.count)")
            GitActivityList(commits: model.gitActivity, unavailableReason: model.gitActivityUnavailableReason)

            SectionHeader(title: "Permissions", value: "\(permissionStatus.pendingApprovals) pending")
            PermissionStatusView(status: permissionStatus)

            SectionHeader(title: "Skills", value: model.skillStatus.isAvailable ? "\(model.skillStatus.enabled.count) enabled" : "Unavailable")
            SkillStatusView(status: model.skillStatus) { name, enabled in
                model.setSkill(name, enabled: enabled)
            }

            SectionHeader(title: "Recent Codex Activity", value: "\(model.state.sessionActivities.count)")
            SessionActivityList(activities: Array(model.state.sessionActivities.suffix(4).reversed()))
        }
        .accessibilityIdentifier("monitor.tab.overview.content")
    }
}

private struct SessionPicker: View {
    var sessions: [CodexSessionStatus]
    var selectedSessionId: String?
    var select: (String) -> Void

    var body: some View {
        if sessions.isEmpty {
            EmptyStateView(text: "No Codex sessions available for switching")
        } else {
            Menu(selectedSessionTitle) {
                ForEach(sessions) { session in
                    Button(session.name ?? session.id) {
                        select(session.id)
                    }
                }
            }
            .accessibilityIdentifier("monitor.sessionPicker")
        }
    }

    private var selectedSessionTitle: String {
        sessions.first(where: { $0.id == selectedSessionId })?.name
            ?? selectedSessionId
            ?? sessions.first?.name
            ?? sessions.first?.id
            ?? "Select Session"
    }
}

private struct CodexAgentRow: View {
    var agent: CodexAgentStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agent: \(agent.displayName)")
                        .font(.subheadline.weight(.semibold))
                    Text("Session: \(agent.sessionName ?? agent.sessionId)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: agent.status)
            }

            CodexDetailRow(label: "Action", value: agent.currentAction)
            CodexDetailRow(label: "Model", value: agent.model ?? "Unavailable")
            CodexDetailRow(label: "Reasoning", value: agent.reasoningMode?.rawValue.capitalized ?? "Unavailable")
            CodexDetailRow(label: "Updated", value: relativeTime(from: agent.updatedAt))

            if !agent.files.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(agent.files.prefix(4)) { file in
                        HStack {
                            Text(file.path)
                                .font(.caption2.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Text(file.activity.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("monitor.codexAgent.\(agent.id)")
    }
}

private struct CodexSessionList: View {
    var sessions: [CodexSessionStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if sessions.isEmpty {
                EmptyStateView(text: "No Codex sessions observed")
            } else {
                ForEach(sessions.prefix(3)) { session in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.name ?? session.id)
                                .font(.caption.weight(.semibold))
                            Text("\(session.agents.count) agent\(session.agents.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(relativeTime(from: session.updatedAt))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("monitor.codexSession.\(session.id)")
                }
            }
        }
        .accessibilityIdentifier("monitor.codexSessions.summary")
    }
}

private struct CodexContextView: View {
    var tokenStatus: TokenStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    MetricCell(label: "Task Tokens", value: tokenStatus?.currentTaskTokens?.formatted() ?? "Unavailable")
                    MetricCell(label: "Context Used", value: contextValue)
                }
                GridRow {
                    MetricCell(label: "5h Limit", value: percentValue(tokenStatus?.fiveHourUsedPercent))
                    MetricCell(label: "Weekly Limit", value: percentValue(tokenStatus?.weeklyUsedPercent))
                }
                GridRow {
                    MetricCell(label: "5h Reset", value: resetValue(tokenStatus?.fiveHourResetAt))
                    MetricCell(label: "Weekly Reset", value: resetValue(tokenStatus?.weeklyResetAt))
                }
            }

            if let usedPercent = tokenStatus?.contextUsedPercent {
                ProgressView(value: max(0, min(1, usedPercent / 100)))
                    .tint(usedPercent >= 90 ? .red : usedPercent >= 75 ? .yellow : .green)
                    .accessibilityIdentifier("monitor.codexContext.progress")
            } else {
                EmptyStateView(text: "Context window size is unavailable from current Codex telemetry")
            }
        }
        .accessibilityIdentifier("monitor.codexContext.summary")
    }

    private var contextValue: String {
        guard let used = tokenStatus?.contextWindowUsed else { return "Unavailable" }
        guard let limit = tokenStatus?.contextWindowLimit else { return "\(used.formatted()) / Unavailable" }
        return "\(used.formatted()) / \(limit.formatted())"
    }

    private func percentValue(_ value: Double?) -> String {
        guard let value else { return "Unavailable" }
        return "\(Int(value.rounded()))%"
    }

    private func resetValue(_ date: Date?) -> String {
        guard let date else { return "Unavailable" }
        return relativeTimeUntil(date)
    }
}

private struct CodexDetailRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(value)
                .font(.caption)
                .lineLimit(2)
            Spacer()
        }
    }
}

private struct GitActivityList: View {
    var commits: [GitCommitStatus]
    var unavailableReason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if commits.isEmpty {
                EmptyStateView(text: unavailableReason ?? "Git activity unavailable")
            } else {
                ForEach(commits) { commit in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(commit.shortHash)
                                .font(.caption.monospaced().weight(.semibold))
                            Text(commit.branch)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(commit.localCommitAt.map { relativeTime(from: $0) } ?? "Local time unavailable")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(commit.message)
                            .font(.caption)
                            .lineLimit(1)
                        Text("Push status: \(commit.pushStatus.rawValue.capitalized)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("monitor.gitActivity.\(commit.shortHash)")
                }
            }
        }
        .accessibilityIdentifier("monitor.gitActivity.summary")
    }
}

private struct PermissionStatusView: View {
    var status: PermissionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    MetricCell(label: "Commands", value: status.commandExecution.rawValue.capitalized)
                    MetricCell(label: "File Writes", value: status.fileWrites.rawValue.capitalized)
                }
                GridRow {
                    MetricCell(label: "Git Push", value: status.gitPush.rawValue.capitalized)
                    MetricCell(label: "Approvals", value: "\(status.pendingApprovals)")
                }
            }

            if status.pendingActions.isEmpty {
                EmptyStateView(text: "No pending permission warnings")
            } else {
                ForEach(status.pendingActions.prefix(3), id: \.self) { action in
                    Label(action, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("monitor.permissions.summary")
    }
}

private struct SkillStatusView: View {
    var status: SkillStatus
    var setSkill: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !status.isAvailable {
                EmptyStateView(text: "Skill Status: Unavailable")
            } else {
                SkillNamesRow(title: "Enabled", names: status.enabled, actionTitle: "Disable") { name in
                    setSkill(name, false)
                }
                SkillNamesRow(title: "Disabled", names: status.disabled, actionTitle: "Enable") { name in
                    setSkill(name, true)
                }
            }
        }
        .accessibilityIdentifier("monitor.skills.summary")
    }
}

private struct SkillNamesRow: View {
    var title: String
    var names: [String]
    var actionTitle: String
    var action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if names.isEmpty {
                Text("None")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(names.prefix(4)), id: \.self) { name in
                    HStack {
                        Text(name)
                            .font(.caption.monospaced())
                            .lineLimit(1)
                        Spacer()
                        Button(actionTitle) {
                            action(name)
                        }
                        .font(.caption2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SessionActivityList: View {
    var activities: [SessionActivity]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if activities.isEmpty {
                EmptyStateView(text: "No session activity mirrored")
            } else {
                ForEach(activities) { activity in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(activity.title)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(activity.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(activity.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("monitor.sessionActivity.\(activity.id)")
                }
            }
        }
        .accessibilityIdentifier("monitor.sessionActivity.summary")
    }
}

private struct HeaderView: View {
    var health: SystemHealth
    var isDemoMode: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color.opacity(0.35), radius: 4)
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Agent Monitor")
                    .font(.headline)
                    .accessibilityIdentifier("monitor.header.title")
                Text(isDemoMode ? "Demo telemetry, waiting for event log" : "Live event log connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(health.label)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("monitor.header.health")
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.18), in: Capsule())
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    private var color: Color {
        switch health {
        case .healthy: .green
        case .warning: .yellow
        case .critical: .red
        }
    }
}

private struct SectionHeader: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

private struct AgentRow: View {
    var agent: AgentTelemetry
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(agent.name)
                        .font(.subheadline.weight(.semibold))
                    Text(agent.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: agent.status)
            }
            Text(agent.currentTask)
                .font(.caption)
            Text(agent.activity)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack {
                Text("Started \(agent.startedAt.formatted(date: .omitted, time: .shortened))")
                Spacer()
                Text(formatDuration(agent.duration(asOf: now)))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier("monitor.agent.\(agent.id)")
    }
}

private struct StatusBadge: View {
    var status: AgentStatus

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }

    private var color: Color {
        switch status {
        case .idle: .secondary
        case .running: .green
        case .blocked: .orange
        case .completed: .blue
        case .error: .red
        }
    }
}

private struct UsageSummaryView: View {
    var metrics: UsageMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    MetricCell(label: "Last 5h", value: metrics.window5h.formatted())
                    MetricCell(label: "Last 7d", value: metrics.window7d.formatted())
                }
                GridRow {
                    MetricCell(label: "Total", value: metrics.total.formatted())
                    MetricCell(label: "Remaining", value: metrics.remaining?.formatted() ?? "Unavailable")
                }
            }
            if let ratio = metrics.remainingRatio {
                ProgressView(value: max(0, min(1, 1 - ratio)))
                    .tint(ratio <= 0.05 ? .red : ratio <= 0.20 ? .yellow : .green)
                    .accessibilityIdentifier("monitor.usage.progress")
            }
        }
        .accessibilityIdentifier("monitor.usage.summary")
    }
}

private struct MetricCell: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
    }
}

private struct DiagnosticsView: View {
    var state: MonitorState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PolicySummaryView(state: state)

            if state.diagnostics.isEmpty {
                EmptyStateView(text: "No diagnostics warnings")
            } else {
                ForEach(state.diagnostics.prefix(4), id: \.self) { item in
                    Label(item, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            ForEach(state.permissions) { scope in
                VStack(alignment: .leading, spacing: 3) {
                    Text(scope.agentId)
                        .font(.caption.weight(.semibold))
                    Text(scope.allowedOperations.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Rate: \(scope.rateLimit.used)/\(scope.rateLimit.limit) per \(scope.rateLimit.window)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(scope.rateLimit.usageRatio >= 0.80 ? .orange : .secondary)
                }
                .accessibilityIdentifier("monitor.permission.\(scope.agentId)")
            }
        }
        .accessibilityIdentifier("monitor.diagnostics.summary")
    }
}

private struct PolicySummaryView: View {
    var state: MonitorState

    private var violationCount: Int {
        state.permissions.reduce(0) { count, scope in
            count + scope.warnings.filter { $0.contains("Observe-only policy forbids operation") }.count
        }
    }

    var body: some View {
        Label(
            violationCount == 0 ? "Observe-only boundary intact" : "Observe-only violations: \(violationCount)",
            systemImage: violationCount == 0 ? "eye" : "exclamationmark.octagon"
        )
        .font(.caption)
        .foregroundStyle(violationCount == 0 ? Color.secondary : Color.red)
        .accessibilityIdentifier("monitor.policy.summary")
    }
}

private struct EmptyStateView: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }
}

private func formatDuration(_ interval: TimeInterval) -> String {
    let total = Int(interval)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60

    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }

    if minutes > 0 {
        return "\(minutes)m \(seconds)s"
    }

    return "\(seconds)s"
}

private func relativeTime(from date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 { return "\(seconds)s ago" }

    let minutes = seconds / 60
    if minutes < 60 { return "\(minutes)m ago" }

    let hours = minutes / 60
    if hours < 24 { return "\(hours)h ago" }

    return date.formatted(date: .abbreviated, time: .shortened)
}

private func relativeTimeUntil(_ date: Date, now: Date = Date()) -> String {
    let seconds = Int(date.timeIntervalSince(now))
    if seconds <= 0 { return "Now" }

    let minutes = seconds / 60
    if minutes < 60 { return "\(max(1, minutes))m" }

    let hours = minutes / 60
    if hours < 24 { return "\(hours)h \(minutes % 60)m" }

    let days = hours / 24
    return "\(days)d \(hours % 24)h"
}

private func effectiveSessionId(selected: String?, sessions: [CodexSessionStatus]) -> String? {
    if let selected, sessions.contains(where: { $0.id == selected }) {
        return selected
    }
    return sessions.first?.id
}
