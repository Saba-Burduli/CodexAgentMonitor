import Foundation

public protocol AgentStatusProvider: Sendable {
    func agentStatuses() throws -> [CodexAgentStatus]
}

public protocol TokenStatusProvider: Sendable {
    func tokenStatus(for sessionId: String?) throws -> TokenStatus?
}

public protocol GitStatusProvider: Sendable {
    func recentGitActivity(limit: Int) throws -> [GitCommitStatus]
}

public protocol PermissionStatusProvider: Sendable {
    func permissionStatus() throws -> PermissionStatus
}

public protocol SkillStatusProvider: Sendable {
    func skillStatus() throws -> SkillStatus
}

public protocol SessionStatusProvider: Sendable {
    func sessions() throws -> [CodexSessionStatus]
}
