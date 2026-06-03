import Foundation

public enum ObserveOnlyPolicy {
    public static let allowedOperations: Set<String> = [
        "codex_session",
        "read_codex_session_jsonl",
        "read_files",
        "run_local_tests",
        "run_local_validation",
        "run_validation",
        "token_usage",
        "tool_calls",
        "write_event_log",
        "write_monitor_event_log"
    ]

    public static let forbiddenOperations: Set<String> = [
        "assume_private_openai_infrastructure",
        "control_agents",
        "execute_external_systems",
        "kill_processes",
        "modify_codex",
        "modify_codex_internals",
        "start_agents",
        "stop_agents"
    ]

    public static var summary: String {
        "Observe-only: reads Codex/session telemetry and writes monitor events; does not modify Codex, control agents, kill processes, execute external systems, or assume private OpenAI infrastructure."
    }

    public static func violations(in operations: [String]) -> [String] {
        let normalizedForbidden = Set(forbiddenOperations.map(normalize))
        return operations.filter { normalizedForbidden.contains(normalize($0)) }
    }

    public static func sanitized(_ scope: PermissionScope) -> PermissionScope {
        let violations = violations(in: scope.allowedOperations)
        guard !violations.isEmpty else { return scope }

        var warnings = scope.warnings
        for operation in violations {
            warnings.append("Observe-only policy forbids operation: \(operation)")
        }

        let allowedOperations = scope.allowedOperations.filter { !violations.contains($0) }
        return PermissionScope(
            agentId: scope.agentId,
            allowedOperations: allowedOperations,
            rateLimit: scope.rateLimit,
            warnings: warnings
        )
    }

    private static func normalize(_ operation: String) -> String {
        operation.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}
