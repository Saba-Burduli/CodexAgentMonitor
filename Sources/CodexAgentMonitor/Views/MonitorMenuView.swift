import CodexAgentMonitorCore
import SwiftUI

struct MonitorMenuView: View {
    @ObservedObject var model: MonitorViewModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeaderView(health: model.state.health, isDemoMode: model.isDemoMode)

            SectionHeader(title: "Active Agents", value: "\(model.state.activeAgents.count)")
            if model.state.activeAgents.isEmpty {
                EmptyStateView(text: "No active agents reported")
            } else {
                VStack(spacing: 10) {
                    ForEach(model.state.activeAgents) { agent in
                        AgentRow(agent: agent, now: Date())
                    }
                }
            }

            SectionHeader(title: "Token Usage", value: model.state.usage.trend.rawValue.capitalized)
            UsageSummaryView(metrics: model.state.usage)

            SectionHeader(title: "Diagnostics", value: model.state.health.label)
            DiagnosticsView(state: model.state)

            Divider()

            HStack {
                Button("Refresh") { model.refresh() }
                Button("Settings") { openSettings() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .accessibilityIdentifier("monitor.menu.root")
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
        }
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
            }
        }
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
