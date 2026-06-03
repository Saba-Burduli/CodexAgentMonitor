import Foundation

public enum CodexSessionEventMapper {
    public static func events(from line: String) -> [MonitorEvent] {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = date(from: object["timestamp"] as? String),
            let recordType = object["type"] as? String
        else {
            return []
        }
        let payload = object["payload"] as? [String: Any] ?? [:]

        switch recordType {
        case "event_msg":
            return events(fromEventMessage: payload, timestamp: timestamp)
        case "response_item":
            return events(fromResponseItem: payload, timestamp: timestamp)
        case "session_meta":
            return threadEvents(
                task: "Codex session metadata",
                activity: "Session \(string(payload["id"]) ?? "unknown") from \(string(payload["source"]) ?? "unknown source")",
                timestamp: timestamp
            )
        case "turn_context":
            return threadEvents(
                task: "Codex turn context",
                activity: "Turn \(string(payload["turn_id"]) ?? "unknown") in \(string(payload["cwd"]) ?? "unknown workspace")",
                timestamp: timestamp
            )
        case "compacted":
            return threadEvents(task: "Codex context compacted", activity: "Compacted session context", timestamp: timestamp)
        default:
            return []
        }
    }

    private static func events(fromEventMessage payload: [String: Any], timestamp: Date) -> [MonitorEvent] {
        switch payload["type"] as? String {
        case "task_started":
            let turnID = payload["turn_id"] as? String ?? "codex-thread"
            let startedAt = epochDate(payload["started_at"]) ?? timestamp
            return [.agentStarted(AgentTelemetry(
                id: turnID,
                name: "Codex Thread",
                status: .running,
                currentTask: "Codex session turn started",
                startedAt: startedAt,
                updatedAt: timestamp,
                activity: "Processing current Codex request"
            ))]
        case "token_count":
            return tokenEvents(from: payload, timestamp: timestamp)
        case "task_complete":
            let turnID = payload["turn_id"] as? String ?? "codex-thread"
            return [.agentCompleted(
                agentId: turnID,
                updatedAt: timestamp,
                activity: "Codex session turn completed"
            )]
        case "patch_apply_end":
            let callID = payload["call_id"] as? String ?? UUID().uuidString
            let success = payload["success"] as? Bool ?? false
            let activity = string(payload["stdout"]) ?? string(payload["stderr"]) ?? "Patch apply finished"
            return [.agentFinished(
                agentId: "tool-\(callID)",
                status: success ? .completed : .error,
                updatedAt: timestamp,
                activity: activity
            )]
        case "web_search_end":
            let callID = payload["call_id"] as? String ?? UUID().uuidString
            return [.agentStatusUpdate(AgentTelemetry(
                id: "web-search-\(callID)",
                name: "Web Search",
                status: .completed,
                currentTask: "Codex web search",
                startedAt: timestamp,
                updatedAt: timestamp,
                activity: string(payload["query"]) ?? actionSummary(payload["action"]) ?? "Web search completed"
            ))]
        case "user_message":
            return threadEvents(task: "User message", activity: excerpt(string(payload["message"]) ?? "User message recorded"), timestamp: timestamp)
        case "agent_message":
            return threadEvents(task: "Agent message", activity: excerpt(string(payload["message"]) ?? "Agent message recorded"), timestamp: timestamp)
        case "thread_goal_updated":
            return threadEvents(task: "Thread goal updated", activity: excerpt(string(payload["objective"]) ?? string(payload["goal"]) ?? "Thread goal updated"), timestamp: timestamp)
        case "turn_aborted":
            let turnID = payload["turn_id"] as? String ?? "codex-thread"
            return [.agentError(agentId: turnID, updatedAt: timestamp, activity: "Codex turn aborted")]
        case "context_compacted":
            return threadEvents(task: "Codex context compacted", activity: "Context compaction completed", timestamp: timestamp)
        default:
            return []
        }
    }

    private static func events(fromResponseItem payload: [String: Any], timestamp: Date) -> [MonitorEvent] {
        switch payload["type"] as? String {
        case "function_call", "custom_tool_call":
            let callID = payload["call_id"] as? String ?? UUID().uuidString
            let toolName = payload["name"] as? String ?? "tool"
            return [.agentStarted(AgentTelemetry(
                id: "tool-\(callID)",
                name: toolName,
                status: .running,
                currentTask: "Running Codex tool call",
                startedAt: timestamp,
                updatedAt: timestamp,
                activity: payload["arguments"] as? String ?? payload["input"] as? String ?? "Tool call started"
            ))]
        case "function_call_output", "custom_tool_call_output":
            let callID = payload["call_id"] as? String ?? UUID().uuidString
            return [.agentCompleted(
                agentId: "tool-\(callID)",
                updatedAt: timestamp,
                activity: "Tool call completed"
            )]
        case "web_search_call":
            let action = actionSummary(payload["action"]) ?? "Web search"
            return [.agentStatusUpdate(AgentTelemetry(
                id: "web-search-\(Int(timestamp.timeIntervalSince1970 * 1_000))",
                name: "Web Search",
                status: status(from: payload["status"] as? String),
                currentTask: "Codex web search",
                startedAt: timestamp,
                updatedAt: timestamp,
                activity: action
            ))]
        case "message":
            let role = string(payload["role"]) ?? "message"
            return threadEvents(task: "Codex \(role) message", activity: excerpt(messageText(payload["content"]) ?? "\(role) message recorded"), timestamp: timestamp)
        case "reasoning":
            return threadEvents(task: "Codex reasoning", activity: reasoningSummary(payload) ?? "Reasoning item recorded", timestamp: timestamp)
        default:
            return []
        }
    }

    private static func tokenEvents(from payload: [String: Any], timestamp: Date) -> [MonitorEvent] {
        guard let info = payload["info"] as? [String: Any] else { return [] }
        let lastUsage = info["last_token_usage"] as? [String: Any]
        let totalUsage = info["total_token_usage"] as? [String: Any]
        let rateLimits = payload["rate_limits"] as? [String: Any]
        let primary = rateLimits?["primary"] as? [String: Any]
        let usedPercent = number(primary?["used_percent"])

        let usage = UsageMetrics(
            window5h: int(lastUsage?["total_tokens"]),
            window7d: int(totalUsage?["total_tokens"]),
            total: int(totalUsage?["total_tokens"]),
            remaining: nil,
            trend: usedPercent.map { $0 >= 90 ? .spiking : .rising } ?? .stable,
            updatedAt: timestamp
        )

        var events: [MonitorEvent] = [.tokenUsageUpdated(usage)]
        if let usedPercent {
            let window = primary?["window_minutes"].map { "\(int($0))m" } ?? "unknown"
            let warning = usedPercent >= 90 ? ["Codex rate limit near exhaustion: \(Int(usedPercent))% used"] : []
            events.append(.permissionWarningTriggered(PermissionScope(
                agentId: "codex-thread",
                allowedOperations: ["codex_session", "tool_calls", "token_usage"],
                rateLimit: RateLimit(limit: 100, used: Int(usedPercent.rounded()), window: window),
                warnings: warning
            )))
        }
        return events
    }

    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        return ISO8601DateFormatter().date(from: string)
    }

    private static func epochDate(_ value: Any?) -> Date? {
        guard let seconds = number(value) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func int(_ value: Any?) -> Int {
        Int(number(value) ?? 0)
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double: value
        case let value as Int: Double(value)
        case let value as String: Double(value)
        default: nil
        }
    }

    private static func string(_ value: Any?) -> String? {
        guard let value = value as? String, !value.isEmpty else { return nil }
        return value
    }

    private static func status(from value: String?) -> AgentStatus {
        value == "completed" ? .completed : .running
    }

    private static func actionSummary(_ value: Any?) -> String? {
        guard let action = value as? [String: Any] else { return nil }
        if let queries = action["queries"] as? [String], !queries.isEmpty {
            return queries.joined(separator: ", ")
        }
        return string(action["type"])
    }

    private static func threadActivity(task: String, activity: String, timestamp: Date) -> MonitorEvent {
        .agentStatusUpdate(AgentTelemetry(
            id: "codex-thread",
            name: "Codex Thread",
            status: .running,
            currentTask: task,
            startedAt: timestamp,
            updatedAt: timestamp,
            activity: activity
        ))
    }

    private static func threadEvents(task: String, activity: String, timestamp: Date) -> [MonitorEvent] {
        [
            .sessionActivityRecorded(SessionActivity(
                timestamp: timestamp,
                category: "codex_session",
                title: task,
                detail: activity
            )),
            threadActivity(task: task, activity: activity, timestamp: timestamp)
        ]
    }

    private static func messageText(_ value: Any?) -> String? {
        if let text = string(value) {
            return text
        }
        guard let parts = value as? [[String: Any]] else { return nil }
        let text = parts.compactMap { string($0["text"]) }.joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    private static func reasoningSummary(_ payload: [String: Any]) -> String? {
        guard let summaries = payload["summary"] as? [[String: Any]] else { return nil }
        let text = summaries.compactMap { string($0["text"]) }.joined(separator: " ")
        return text.isEmpty ? nil : excerpt(text)
    }

    private static func excerpt(_ value: String, limit: Int = 240) -> String {
        if value.count <= limit {
            return value
        }
        let end = value.index(value.startIndex, offsetBy: limit)
        return "\(value[..<end])..."
    }
}
