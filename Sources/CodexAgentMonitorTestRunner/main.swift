import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorTestRunner {
    static func main() throws {
        try testAgentLifecycleEventsUpdateActiveState()
        try testHealthBecomesWarningWhenQuotaIsLow()
        try testHealthBecomesCriticalForPermissionWarning()
        try testJSONLinesDecodeEvents()
        print("CodexAgentMonitorTestRunner: 4 tests passed")
    }

    private static func testAgentLifecycleEventsUpdateActiveState() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 1_300)
        let agent = AgentTelemetry(
            id: "agent-1",
            name: "Builder",
            status: .running,
            currentTask: "Build monitor",
            startedAt: start,
            updatedAt: start,
            activity: "Starting"
        )

        var state = MonitorState()
        state.apply(.agentStarted(agent))

        try expect(state.activeAgents.count == 1, "expected one active agent")
        try expect(state.activeAgents.first?.duration(asOf: end) == 300, "expected 300 second duration")

        state.apply(.agentFinished(agentId: "agent-1", status: .completed, updatedAt: end, activity: "Done"))

        try expect(state.activeAgents.isEmpty, "expected completed agent to leave active list")
        try expect(state.agents.first?.status == .completed, "expected completed status")
    }

    private static func testHealthBecomesWarningWhenQuotaIsLow() throws {
        var state = MonitorState()
        state.apply(.tokenUsageUpdated(
            UsageMetrics(window5h: 100, window7d: 400, total: 900, remaining: 100, trend: .stable)
        ))

        try expect(state.health == .warning, "expected warning health for 10% remaining quota")
    }

    private static func testHealthBecomesCriticalForPermissionWarning() throws {
        var state = MonitorState()
        state.apply(.permissionWarningTriggered(
            PermissionScope(
                agentId: "agent-1",
                allowedOperations: ["read_files"],
                rateLimit: RateLimit(limit: 100, used: 20, window: "1h"),
                warnings: ["write scope denied"]
            )
        ))

        try expect(state.health == .critical, "expected critical health for permission warning")
        try expect(state.diagnostics == ["agent-1: write scope denied"], "expected warning diagnostic")
    }

    private static func testJSONLinesDecodeEvents() throws {
        let date = Date(timeIntervalSince1970: 1_000)
        let event = MonitorEvent.agentStarted(
            AgentTelemetry(
                id: "agent-1",
                name: "Builder",
                status: .running,
                currentTask: "Decode event",
                startedAt: date,
                updatedAt: date,
                activity: "Reading JSONL"
            )
        )

        let line = try EventCodec.encodeJSONLine(event)
        let decoded = EventCodec.decodeJSONLines("\(line)\nnot-json")

        try expect(decoded == [event], "expected JSONL decoder to skip malformed line")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() {
            throw TestFailure(message: message)
        }
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    var message: String
    var description: String { message }
}
