import Foundation

public enum MonitorEvent: Equatable, Sendable {
    case agentStarted(AgentTelemetry)
    case agentUpdated(AgentTelemetry)
    case agentStatusUpdate(AgentTelemetry)
    case agentFinished(agentId: String, status: AgentStatus, updatedAt: Date, activity: String)
    case agentCompleted(agentId: String, updatedAt: Date, activity: String)
    case agentError(agentId: String, updatedAt: Date, activity: String)
    case tokenUsageUpdated(UsageMetrics)
    case permissionWarningTriggered(PermissionScope)
}

extension MonitorEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case agent
        case agentId
        case status
        case updatedAt
        case activity
        case usage
        case permission
    }

    private enum EventType: String, Codable {
        case agentStarted = "agent_started"
        case agentUpdated = "agent_updated"
        case agentStatusUpdate = "agent_status_update"
        case agentFinished = "agent_finished"
        case agentCompleted = "agent_completed"
        case agentError = "agent_error"
        case tokenUsageUpdated = "token_usage_updated"
        case permissionWarningTriggered = "permission_warning_triggered"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(EventType.self, forKey: .type)

        switch type {
        case .agentStarted:
            self = .agentStarted(try container.decode(AgentTelemetry.self, forKey: .agent))
        case .agentUpdated:
            self = .agentUpdated(try container.decode(AgentTelemetry.self, forKey: .agent))
        case .agentStatusUpdate:
            self = .agentStatusUpdate(try container.decode(AgentTelemetry.self, forKey: .agent))
        case .agentFinished:
            self = .agentFinished(
                agentId: try container.decode(String.self, forKey: .agentId),
                status: try container.decode(AgentStatus.self, forKey: .status),
                updatedAt: try container.decode(Date.self, forKey: .updatedAt),
                activity: try container.decodeIfPresent(String.self, forKey: .activity) ?? "Finished"
            )
        case .agentCompleted:
            self = .agentCompleted(
                agentId: try container.decode(String.self, forKey: .agentId),
                updatedAt: try container.decode(Date.self, forKey: .updatedAt),
                activity: try container.decodeIfPresent(String.self, forKey: .activity) ?? "Completed"
            )
        case .agentError:
            self = .agentError(
                agentId: try container.decode(String.self, forKey: .agentId),
                updatedAt: try container.decode(Date.self, forKey: .updatedAt),
                activity: try container.decodeIfPresent(String.self, forKey: .activity) ?? "Error"
            )
        case .tokenUsageUpdated:
            self = .tokenUsageUpdated(try container.decode(UsageMetrics.self, forKey: .usage))
        case .permissionWarningTriggered:
            self = .permissionWarningTriggered(try container.decode(PermissionScope.self, forKey: .permission))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .agentStarted(let agent):
            try container.encode(EventType.agentStarted, forKey: .type)
            try container.encode(agent, forKey: .agent)
        case .agentUpdated(let agent):
            try container.encode(EventType.agentUpdated, forKey: .type)
            try container.encode(agent, forKey: .agent)
        case .agentStatusUpdate(let agent):
            try container.encode(EventType.agentStatusUpdate, forKey: .type)
            try container.encode(agent, forKey: .agent)
        case .agentFinished(let agentId, let status, let updatedAt, let activity):
            try container.encode(EventType.agentFinished, forKey: .type)
            try container.encode(agentId, forKey: .agentId)
            try container.encode(status, forKey: .status)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(activity, forKey: .activity)
        case .agentCompleted(let agentId, let updatedAt, let activity):
            try container.encode(EventType.agentCompleted, forKey: .type)
            try container.encode(agentId, forKey: .agentId)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(activity, forKey: .activity)
        case .agentError(let agentId, let updatedAt, let activity):
            try container.encode(EventType.agentError, forKey: .type)
            try container.encode(agentId, forKey: .agentId)
            try container.encode(updatedAt, forKey: .updatedAt)
            try container.encode(activity, forKey: .activity)
        case .tokenUsageUpdated(let usage):
            try container.encode(EventType.tokenUsageUpdated, forKey: .type)
            try container.encode(usage, forKey: .usage)
        case .permissionWarningTriggered(let permission):
            try container.encode(EventType.permissionWarningTriggered, forKey: .type)
            try container.encode(permission, forKey: .permission)
        }
    }
}
