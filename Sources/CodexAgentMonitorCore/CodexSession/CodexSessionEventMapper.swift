import Foundation

public enum CodexSessionEventMapper {
    public static func events(from line: String) -> [MonitorEvent] {
        guard
            let data = line.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let timestamp = date(from: object["timestamp"] as? String),
            let recordType = object["type"] as? String,
            let payload = object["payload"] as? [String: Any]
        else {
            return []
        }

        switch recordType {
        case "event_msg":
            return events(fromEventMessage: payload, timestamp: timestamp)
        case "response_item":
            return events(fromResponseItem: payload, timestamp: timestamp)
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
}
