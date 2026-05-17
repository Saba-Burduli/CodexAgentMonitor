import Foundation

public enum DemoTelemetry {
    public static func state(now: Date = Date()) -> MonitorState {
        let agents = [
            AgentTelemetry(
                id: "local-main",
                name: "Primary Codex",
                status: .running,
                currentTask: "Implementing observability layer",
                startedAt: now.addingTimeInterval(-42 * 60),
                updatedAt: now.addingTimeInterval(-8),
                activity: "Editing SwiftUI menu-bar views"
            ),
            AgentTelemetry(
                id: "tester",
                name: "Tester",
                status: .idle,
                currentTask: "Waiting for verification work",
                startedAt: now.addingTimeInterval(-18 * 60),
                updatedAt: now.addingTimeInterval(-2 * 60),
                activity: "No active check assigned"
            )
        ]

        let usage = UsageMetrics(
            window5h: 124_800,
            window7d: 832_500,
            total: 1_420_000,
            remaining: 580_000,
            trend: .rising,
            updatedAt: now.addingTimeInterval(-20)
        )

        let permissions = [
            PermissionScope(
                agentId: "local-main",
                allowedOperations: ["read_files", "write_project_files", "run_local_tests"],
                rateLimit: RateLimit(limit: 120, used: 64, window: "1h")
            ),
            PermissionScope(
                agentId: "tester",
                allowedOperations: ["read_files", "run_local_tests"],
                rateLimit: RateLimit(limit: 60, used: 8, window: "1h")
            )
        ]

        return MonitorState(
            agents: agents,
            usage: usage,
            permissions: permissions,
            diagnostics: ["Demo mode: no event log found"],
            lastEventAt: now
        )
    }
}
