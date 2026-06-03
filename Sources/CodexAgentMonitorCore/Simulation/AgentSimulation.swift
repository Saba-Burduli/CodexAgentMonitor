import Foundation

public protocol AgentEventSink {
    mutating func receive(_ event: MonitorEvent) throws
}

public struct ValidationReport: Equatable, Sendable {
    public var eventsProcessed: Int
    public var checksPassed: Int
    public var logURL: URL
    public var eventLogURL: URL
    public var finalState: MonitorState

    public init(eventsProcessed: Int, checksPassed: Int, logURL: URL, eventLogURL: URL, finalState: MonitorState) {
        self.eventsProcessed = eventsProcessed
        self.checksPassed = checksPassed
        self.logURL = logURL
        self.eventLogURL = eventLogURL
        self.finalState = finalState
    }
}

public struct OrchestratorAgent: AgentEventSink {
    public private(set) var state = MonitorState()
    public private(set) var eventsProcessed = 0

    private let eventLogURL: URL
    private let validationLogURL: URL
    private let fileManager: FileManager

    public init(
        eventLogURL: URL,
        validationLogURL: URL,
        fileManager: FileManager = .default
    ) throws {
        self.eventLogURL = eventLogURL
        self.validationLogURL = validationLogURL
        self.fileManager = fileManager
        try fileManager.createDirectory(at: eventLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: validationLogURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "".write(to: eventLogURL, atomically: true, encoding: .utf8)
        try "CodexAgentMonitor E2E Validation Log\n".write(to: validationLogURL, atomically: true, encoding: .utf8)
    }

    public mutating func receive(_ event: MonitorEvent) throws {
        state.apply(event)
        eventsProcessed += 1

        let line = try EventCodec.encodeJSONLine(event) + "\n"
        try append(line, to: eventLogURL)
        try append(snapshotLine(for: event), to: validationLogURL)
        try verifyReadableEventLog()
    }

    public func makeReport(checksPassed: Int) -> ValidationReport {
        ValidationReport(
            eventsProcessed: eventsProcessed,
            checksPassed: checksPassed,
            logURL: validationLogURL,
            eventLogURL: eventLogURL,
            finalState: state
        )
    }

    private func verifyReadableEventLog() throws {
        let text = try String(contentsOf: eventLogURL, encoding: .utf8)
        let decoded = EventCodec.decodeJSONLines(text)
        guard decoded.count == eventsProcessed else {
            throw SimulationFailure("event log replay mismatch: decoded \(decoded.count), expected \(eventsProcessed)")
        }
    }

    private func snapshotLine(for event: MonitorEvent) -> String {
        let activeIDs = state.activeAgents.map(\.id).joined(separator: ",")
        return "event=\(eventLogName(event)) processed=\(eventsProcessed) health=\(state.health.rawValue) active=[\(activeIDs)] totalAgents=\(state.agents.count) usage5h=\(state.usage.window5h) remaining=\(state.usage.remaining.map(String.init) ?? "unavailable")\n"
    }

    private func append(_ text: String, to url: URL) throws {
        if let handle = try? FileHandle(forWritingTo: url) {
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(text.utf8))
            try handle.close()
        } else {
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

public struct TesterAgent {
    public var id: String
    public var errorAgentId: String
    public var now: Date
    public var eventDelay: TimeInterval

    public init(
        id: String = "tester-agent",
        errorAgentId: String = "tester-agent-error-case",
        now: Date = Date(),
        eventDelay: TimeInterval = 0
    ) {
        self.id = id
        self.errorAgentId = errorAgentId
        self.now = now
        self.eventDelay = eventDelay
    }

    public func run<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try sendLifecycleEvents(through: &sink)
        try sendRapidUpdates(through: &sink)
        try sendUsageAndPermissionEvents(through: &sink)
        try sendErrorScenario(through: &sink)
    }

    private func sendLifecycleEvents<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try send(.agentStarted(agent(status: .running, task: "Spawn tester workload", offset: 0, activity: "Tester agent spawned")), through: &sink)
        try send(.agentStatusUpdate(agent(status: .running, task: "Prepare fixtures", offset: 1, activity: "Creating synthetic Codex task events")), through: &sink)
        try send(.agentStatusUpdate(agent(status: .blocked, task: "Wait for simulated dependency", offset: 2, activity: "Delay edge case: waiting safely")), through: &sink)
        try send(.agentStatusUpdate(agent(status: .running, task: "Resume after delay", offset: 3, activity: "Delay cleared, continuing")), through: &sink)
    }

    private func sendRapidUpdates<Sink: AgentEventSink>(through sink: inout Sink) throws {
        for index in 0..<6 {
            try send(.agentStatusUpdate(agent(
                status: .running,
                task: "Rapid update batch",
                offset: 4 + TimeInterval(index),
                activity: "Rapid progress update \(index + 1)/6"
            )), through: &sink)
        }
        try send(.agentCompleted(agentId: id, updatedAt: now.addingTimeInterval(11), activity: "Tester workload completed"), through: &sink)
    }

    private func sendUsageAndPermissionEvents<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try send(.tokenUsageUpdated(UsageMetrics(
            window5h: 40_000,
            window7d: 180_000,
            total: 220_000,
            remaining: 780_000,
            trend: .rising,
            updatedAt: now.addingTimeInterval(12)
        )), through: &sink)
        try send(.tokenUsageUpdated(UsageMetrics(
            window5h: 98_000,
            window7d: 251_000,
            total: 291_000,
            remaining: 709_000,
            trend: .spiking,
            updatedAt: now.addingTimeInterval(13)
        )), through: &sink)
        try send(.permissionWarningTriggered(PermissionScope(
            agentId: id,
            allowedOperations: ["read_files", "write_event_log", "run_validation"],
            rateLimit: RateLimit(limit: 100, used: 82, window: "1h"),
            warnings: []
        )), through: &sink)
    }

    private func sendErrorScenario<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try send(.agentStarted(AgentTelemetry(
            id: errorAgentId,
            name: "Tester Failure Case",
            status: .running,
            currentTask: "Simulate failing Codex task",
            startedAt: now.addingTimeInterval(14),
            updatedAt: now.addingTimeInterval(14),
            activity: "Failure scenario started"
        )), through: &sink)
        try send(.agentError(
            agentId: errorAgentId,
            updatedAt: now.addingTimeInterval(15),
            activity: "Simulated tool failure handled safely"
        ), through: &sink)
    }

    private func send<Sink: AgentEventSink>(_ event: MonitorEvent, through sink: inout Sink) throws {
        try sink.receive(event)
        if eventDelay > 0 {
            Thread.sleep(forTimeInterval: eventDelay)
        }
    }

    private func agent(status: AgentStatus, task: String, offset: TimeInterval, activity: String) -> AgentTelemetry {
        AgentTelemetry(
            id: id,
            name: "Tester Agent",
            status: status,
            currentTask: task,
            startedAt: now,
            updatedAt: now.addingTimeInterval(offset),
            activity: activity
        )
    }
}

public struct ConstraintAuditAgent {
    public var id: String
    public var now: Date

    public init(id: String = "constraint-audit-agent", now: Date = Date()) {
        self.id = id
        self.now = now
    }

    public func run<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try sink.receive(.agentStarted(AgentTelemetry(
            id: id,
            name: "Constraint Audit Agent",
            status: .running,
            currentTask: "Audit observe-only boundaries",
            startedAt: now,
            updatedAt: now,
            activity: "Checking monitor permissions and product constraints"
        )))
        try sink.receive(.permissionWarningTriggered(PermissionScope(
            agentId: id,
            allowedOperations: ["read_codex_session_jsonl", "write_monitor_event_log", "run_local_validation"],
            rateLimit: RateLimit(limit: 60, used: 12, window: "1h"),
            warnings: []
        )))
        try sink.receive(.sessionActivityRecorded(SessionActivity(
            timestamp: now.addingTimeInterval(1),
            category: "constraint_audit",
            title: "Observe-only boundary verified",
            detail: "Audit permits session reads, monitor event-log writes, and local validation only. It does not permit modifying Codex, controlling agents, killing processes, or invoking external systems."
        )))
        try sink.receive(.agentCompleted(
            agentId: id,
            updatedAt: now.addingTimeInterval(2),
            activity: "Observe-only constraint audit completed"
        ))
    }
}

public struct SessionMirrorValidationAgent {
    public var id: String
    public var now: Date

    public init(id: String = "session-mirror-validation-agent", now: Date = Date()) {
        self.id = id
        self.now = now
    }

    public func run<Sink: AgentEventSink>(through sink: inout Sink) throws {
        try sink.receive(.agentStarted(AgentTelemetry(
            id: id,
            name: "Session Mirror Validation Agent",
            status: .running,
            currentTask: "Validate Codex session mirroring",
            startedAt: now,
            updatedAt: now,
            activity: "Mapping synthetic Codex session JSONL through the real mapper"
        )))

        for line in codexSessionLines {
            for event in CodexSessionEventMapper.events(from: line) {
                try sink.receive(event)
            }
        }

        try sink.receive(.agentCompleted(
            agentId: id,
            updatedAt: now.addingTimeInterval(3),
            activity: "Session mirror validation completed"
        ))
    }

    private var codexSessionLines: [String] {
        [
            """
            {"timestamp":"2026-06-03T10:02:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"mirror-turn","started_at":1780480920}}
            """,
            """
            {"timestamp":"2026-06-03T10:02:01.000Z","type":"event_msg","payload":{"type":"user_message","message":"Validate mirrored session activity"}}
            """,
            """
            {"timestamp":"2026-06-03T10:02:02.000Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"swift test\\"}","call_id":"call_mirror"}}
            """,
            """
            {"timestamp":"2026-06-03T10:02:03.000Z","type":"response_item","payload":{"type":"function_call_output","call_id":"call_mirror","output":"passed"}}
            """,
            """
            {"timestamp":"2026-06-03T10:02:04.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":5000},"last_token_usage":{"total_tokens":500}},"rate_limits":{"primary":{"used_percent":70.0,"window_minutes":300}}}}
            """,
            """
            {"timestamp":"2026-06-03T10:02:05.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"mirror-turn"}}
            """
        ]
    }
}

public enum AgentSimulation {
    public static func run(
        eventLogURL: URL,
        validationLogURL: URL,
        now: Date = Date(),
        eventDelay: TimeInterval = 0
    ) throws -> ValidationReport {
        var orchestrator = try OrchestratorAgent(eventLogURL: eventLogURL, validationLogURL: validationLogURL)
        let tester = TesterAgent(now: now, eventDelay: eventDelay)
        try tester.run(through: &orchestrator)
        let constraintAudit = ConstraintAuditAgent(now: now.addingTimeInterval(16))
        try constraintAudit.run(through: &orchestrator)
        let sessionMirrorValidation = SessionMirrorValidationAgent(now: now.addingTimeInterval(19))
        try sessionMirrorValidation.run(through: &orchestrator)

        var checksPassed = 0
        try check(orchestrator.eventsProcessed == 30, "expected 30 processed events") { checksPassed += 1 }
        try check(orchestrator.state.agents.map(\.id).uniqueCount == orchestrator.state.agents.count, "expected no duplicate agents") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == tester.id })?.status == .completed, "expected tester agent completion") { checksPassed += 1 }
        try check(!orchestrator.state.activeAgents.contains(where: { $0.id == tester.id }), "expected completed tester cleanup from active list") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == tester.errorAgentId })?.status == .error, "expected error scenario to be captured") { checksPassed += 1 }
        try check(orchestrator.state.health == .critical, "expected critical health after simulated error") { checksPassed += 1 }
        try check(orchestrator.state.permissions.contains(where: { $0.agentId == tester.id && $0.rateLimit.used == 82 }), "expected tester permission metrics") { checksPassed += 1 }
        try check(orchestrator.state.diagnostics.contains(where: { $0.contains("Simulated tool failure") }), "expected error diagnostic") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == constraintAudit.id })?.status == .completed, "expected constraint audit completion") { checksPassed += 1 }
        try check(orchestrator.state.sessionActivities.contains(where: { $0.category == "constraint_audit" }), "expected constraint audit activity") { checksPassed += 1 }
        try check(!hasForbiddenOperations(in: orchestrator.state.permissions, agentId: constraintAudit.id), "expected observe-only permissions") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == sessionMirrorValidation.id })?.status == .completed, "expected session mirror validation completion") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == "mirror-turn" })?.status == .completed, "expected mirrored Codex turn completion") { checksPassed += 1 }
        try check(orchestrator.state.agents.first(where: { $0.id == "tool-call_mirror" })?.status == .completed, "expected mirrored tool completion") { checksPassed += 1 }
        try check(orchestrator.state.sessionActivities.contains(where: { $0.detail == "Validate mirrored session activity" }), "expected mirrored session activity history") { checksPassed += 1 }
        try check(orchestrator.state.usage.total == 5_000 && orchestrator.state.usage.window5h == 500, "expected mirrored Codex token metrics") { checksPassed += 1 }

        try appendSummary(to: validationLogURL, checksPassed: checksPassed, state: orchestrator.state)
        return orchestrator.makeReport(checksPassed: checksPassed)
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String, onPass: () -> Void) throws {
        guard condition() else { throw SimulationFailure(message) }
        onPass()
    }

    private static func appendSummary(to url: URL, checksPassed: Int, state: MonitorState) throws {
        let summary = "summary=passed checks=\(checksPassed) finalHealth=\(state.health.rawValue) finalAgents=\(state.agents.count) activeAgents=\(state.activeAgents.count)\n"
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(summary.utf8))
        try handle.close()
    }

    private static func hasForbiddenOperations(in permissions: [PermissionScope], agentId: String) -> Bool {
        let forbidden = Set(["modify_codex", "control_agents", "kill_processes", "execute_external_systems"])
        let allowed = permissions.first(where: { $0.agentId == agentId })?.allowedOperations ?? []
        return !forbidden.isDisjoint(with: allowed)
    }
}

public struct SimulationFailure: Error, CustomStringConvertible, Sendable {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}

private func eventLogName(_ event: MonitorEvent) -> String {
    switch event {
    case .agentStarted: "agent_started"
    case .agentUpdated: "agent_updated"
    case .agentStatusUpdate: "agent_status_update"
    case .agentFinished: "agent_finished"
    case .agentCompleted: "agent_completed"
    case .agentError: "agent_error"
    case .tokenUsageUpdated: "token_usage_updated"
    case .permissionWarningTriggered: "permission_warning_triggered"
    case .sessionActivityRecorded: "session_activity_recorded"
    }
}

private extension Array where Element: Hashable {
    var uniqueCount: Int { Set(self).count }
}
