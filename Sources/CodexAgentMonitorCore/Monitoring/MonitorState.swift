import Foundation

public struct MonitorState: Equatable, Sendable {
    public var agents: [AgentTelemetry]
    public var usage: UsageMetrics
    public var permissions: [PermissionScope]
    public var diagnostics: [String]
    public var lastEventAt: Date?

    public init(
        agents: [AgentTelemetry] = [],
        usage: UsageMetrics = UsageMetrics(),
        permissions: [PermissionScope] = [],
        diagnostics: [String] = [],
        lastEventAt: Date? = nil
    ) {
        self.agents = agents
        self.usage = usage
        self.permissions = permissions
        self.diagnostics = diagnostics
        self.lastEventAt = lastEventAt
    }

    public var activeAgents: [AgentTelemetry] {
        agents.filter { $0.status.isActive }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status { return lhs.startedAt < rhs.startedAt }
                return statusRank(lhs.status) < statusRank(rhs.status)
            }
    }

    public var health: SystemHealth {
        if agents.contains(where: { $0.status == .blocked || $0.status == .error }) {
            return .critical
        }

        if permissions.contains(where: { !$0.warnings.isEmpty || $0.rateLimit.usageRatio >= 0.95 }) {
            return .critical
        }

        if usage.remainingRatio.map({ $0 <= 0.05 }) == true {
            return .critical
        }

        if usage.remainingRatio.map({ $0 <= 0.20 }) == true || usage.trend == .spiking {
            return .warning
        }

        if permissions.contains(where: { $0.rateLimit.usageRatio >= 0.80 }) {
            return .warning
        }

        return .healthy
    }

    public mutating func apply(_ event: MonitorEvent) {
        switch event {
        case .agentStarted(let agent), .agentUpdated(let agent):
            upsert(agent)
            lastEventAt = agent.updatedAt
        case .agentFinished(let agentId, let status, let updatedAt, let activity):
            if let index = agents.firstIndex(where: { $0.id == agentId }) {
                agents[index].status = status
                agents[index].updatedAt = updatedAt
                agents[index].activity = activity
            } else {
                agents.append(
                    AgentTelemetry(
                        id: agentId,
                        name: agentId,
                        status: status,
                        currentTask: "Unknown finished task",
                        startedAt: updatedAt,
                        updatedAt: updatedAt,
                        activity: activity
                    )
                )
            }
            lastEventAt = updatedAt
        case .tokenUsageUpdated(let metrics):
            usage = metrics
            lastEventAt = metrics.updatedAt
        case .permissionWarningTriggered(let scope):
            upsert(scope)
            diagnostics.append(contentsOf: scope.warnings.map { "\(scope.agentId): \($0)" })
            lastEventAt = Date()
        }
    }

    public mutating func apply(_ events: [MonitorEvent]) {
        for event in events {
            apply(event)
        }
    }

    private mutating func upsert(_ agent: AgentTelemetry) {
        if let index = agents.firstIndex(where: { $0.id == agent.id }) {
            agents[index] = agent
        } else {
            agents.append(agent)
        }
    }

    private mutating func upsert(_ scope: PermissionScope) {
        if let index = permissions.firstIndex(where: { $0.agentId == scope.agentId }) {
            permissions[index] = scope
        } else {
            permissions.append(scope)
        }
    }
}

private func statusRank(_ status: AgentStatus) -> Int {
    switch status {
    case .blocked: 0
    case .error: 1
    case .running: 2
    case .idle: 3
    case .completed: 4
    }
}
