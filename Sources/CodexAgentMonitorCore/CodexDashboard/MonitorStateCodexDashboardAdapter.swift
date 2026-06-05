import Foundation

public struct MonitorStateCodexDashboardAdapter: AgentStatusProvider, SessionStatusProvider, TokenStatusProvider, PermissionStatusProvider {
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
                    sessionName: agent.sessionName ?? sessionName,
                    status: agent.status,
                    currentAction: agent.activity.isEmpty ? agent.currentTask : agent.activity,
                    model: agent.model,
                    reasoningMode: agent.reasoningMode,
                    files: fileActivities(for: agent),
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
            contextWindowUsed: state.usage.contextWindowUsed,
            contextWindowLimit: state.usage.contextWindowLimit,
            fiveHourUsedPercent: state.usage.fiveHourUsedPercent ?? percentUsed(consumed: state.usage.total, remaining: state.usage.remaining),
            weeklyUsedPercent: state.usage.weeklyUsedPercent,
            fiveHourResetAt: state.usage.fiveHourResetAt,
            weeklyResetAt: state.usage.weeklyResetAt
        )
    }

    public func permissionStatus() throws -> PermissionStatus {
        guard !state.permissions.isEmpty else {
            return PermissionStatus()
        }

        let operations = Set(state.permissions.flatMap(\.allowedOperations))
        return PermissionStatus(
            commandExecution: operations.contains("run_local_validation") ? .allowed : .unavailable,
            fileWrites: operations.contains("write_monitor_event_log") ? .allowed : .unavailable,
            gitPush: operations.contains("git_push") ? .allowed : .unavailable,
            pendingApprovals: 0,
            pendingActions: state.permissions.flatMap(\.warnings)
        )
    }

    private var sessionName: String? {
        state.sessionActivities
            .last(where: { $0.title == "Codex session metadata" })?
            .detail
    }

    private func sessionId(for agent: AgentTelemetry) -> String {
        if let sessionId = agent.sessionId {
            return sessionId
        }
        if agent.name == "Codex Thread" {
            return agent.id
        }
        if agent.id.hasPrefix("tool-") || agent.id.hasPrefix("web-search-") {
            return "codex-thread"
        }
        return "local-monitor"
    }

    private func fileActivities(for agent: AgentTelemetry) -> [CodexFileActivity] {
        let text = "\(agent.currentTask) \(agent.activity)"
        let kind = fileActivityKind(from: text)
        let paths = extractFilePaths(from: text)
        return paths.prefix(4).map { path in
            CodexFileActivity(path: path, activity: kind, updatedAt: agent.updatedAt)
        }
    }

    private func fileActivityKind(from text: String) -> FileActivityKind {
        let normalized = text.lowercased()
        if normalized.contains("push") { return .pushing }
        if normalized.contains("commit") { return .committing }
        if normalized.contains("stage") || normalized.contains("git add") { return .staging }
        if normalized.contains("edit") || normalized.contains("patch") || normalized.contains("write") { return .editing }
        return .reading
    }

    private func extractFilePaths(from text: String) -> [String] {
        let tokens = text
            .split { character in
                character.isWhitespace || "\"'`,:;()[]{}<>".contains(character)
            }
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "./")) }

        var seen = Set<String>()
        return tokens.compactMap { token in
            guard isLikelyFilePath(token), seen.insert(token).inserted else { return nil }
            return token
        }
    }

    private func isLikelyFilePath(_ token: String) -> Bool {
        let knownExtensions = [
            ".swift", ".md", ".json", ".toml", ".yml", ".yaml",
            ".sh", ".txt", ".plist", ".xcodeproj", ".xcworkspace"
        ]
        return knownExtensions.contains { token.hasSuffix($0) }
    }

    private func percentUsed(consumed: Int, remaining: Int?) -> Double? {
        guard let remaining else { return nil }
        let total = consumed + remaining
        guard total > 0 else { return nil }
        return Double(consumed) / Double(total) * 100
    }
}
