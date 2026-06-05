import Foundation

public struct MonitorStateCodexDashboardAdapter: AgentStatusProvider, SessionStatusProvider, TokenStatusProvider {
    public var state: MonitorState

    public init(state: MonitorState) {
        self.state = state
    }

    public func agentStatuses() throws -> [CodexAgentStatus] {
        state.agents
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { agent in
                CodexAgentStatus(
                    id: agent.id,
                    displayName: agent.name,
                    sessionId: sessionId(for: agent),
                    sessionName: sessionName,
                    status: agent.status,
                    currentAction: agent.activity.isEmpty ? agent.currentTask : agent.activity,
                    model: nil,
                    reasoningMode: nil,
                    files: [],
                    tokenStatus: try? tokenStatus(for: sessionId(for: agent)),
                    updatedAt: agent.updatedAt
                )
            }
    }

    public func sessions() throws -> [CodexSessionStatus] {
        let agents = try agentStatuses()
        let grouped = Dictionary(grouping: agents, by: \.sessionId)
        return grouped.map { sessionId, agents in
            CodexSessionStatus(
                id: sessionId,
                name: agents.compactMap(\.sessionName).first,
                agents: agents,
                updatedAt: agents.map(\.updatedAt).max() ?? Date(timeIntervalSince1970: 0)
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func tokenStatus(for sessionId: String?) throws -> TokenStatus? {
        guard state.usage.total > 0 || state.usage.window5h > 0 || state.usage.window7d > 0 else {
            return nil
        }

        return TokenStatus(
            currentTaskTokens: state.usage.window5h == 0 ? nil : state.usage.window5h,
            contextWindowUsed: state.usage.total == 0 ? nil : state.usage.total,
            contextWindowLimit: nil,
            fiveHourUsedPercent: percentUsed(consumed: state.usage.total, remaining: state.usage.remaining),
            weeklyUsedPercent: nil,
            fiveHourResetAt: nil,
            weeklyResetAt: nil
        )
    }

    private var sessionName: String? {
        state.sessionActivities
            .last(where: { $0.title == "Codex session metadata" })?
            .detail
    }

    private func sessionId(for agent: AgentTelemetry) -> String {
        if agent.name == "Codex Thread" {
            return agent.id
        }
        if agent.id.hasPrefix("tool-") || agent.id.hasPrefix("web-search-") {
            return "codex-thread"
        }
        return "local-monitor"
    }

    private func percentUsed(consumed: Int, remaining: Int?) -> Double? {
        guard let remaining else { return nil }
        let total = consumed + remaining
        guard total > 0 else { return nil }
        return Double(consumed) / Double(total) * 100
    }
}
