import CodexAgentMonitorCore
import Foundation

@main
struct CodexAgentMonitorTestRunner {
    static func main() throws {
        try testAgentLifecycleEventsUpdateActiveState()
        try testHealthBecomesWarningWhenQuotaIsLow()
        try testHealthBecomesCriticalForPermissionWarning()
        try testJSONLinesDecodeEvents()
        try testStructuredLifecycleAliases()
        try testHTTPIngestRequestValidation()
        try testSessionActivityEventsReplayIntoState()
        try testObserveOnlyPolicySanitizesForbiddenOperations()
        try testCodexDashboardTokenDerivedValues()
        try testMonitorStateCodexDashboardAdapter()
        try testLocalGitStatusProviderParsesLogLine()
        try testLocalSkillStatusProviderReadsRepoSkills()
        try testSettingsTabDeduplicatesAndFocuses()
        try testCodexSessionMapperMirrorsUsageAndToolEvents()
        try testCodexSessionMapperMirrorsMessagesAndContext()
        try testCodexCLIStateReaderReadsLatestRollout()
        try testEventLogReaderReplaysMirroredSessionEvents()
        print("CodexAgentMonitorTestRunner: 17 tests passed")
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

    private static func testStructuredLifecycleAliases() throws {
        let start = Date(timeIntervalSince1970: 2_000)
        var state = MonitorState()
        state.apply(.agentStarted(AgentTelemetry(
            id: "tester",
            name: "Tester",
            status: .running,
            currentTask: "Start",
            startedAt: start,
            updatedAt: start,
            activity: "Started"
        )))
        state.apply(.agentStatusUpdate(AgentTelemetry(
            id: "tester",
            name: "Tester",
            status: .blocked,
            currentTask: "Blocked edge case",
            startedAt: start,
            updatedAt: start.addingTimeInterval(1),
            activity: "Waiting"
        )))
        state.apply(.agentCompleted(
            agentId: "tester",
            updatedAt: start.addingTimeInterval(2),
            activity: "Completed safely"
        ))

        try expect(state.agents.count == 1, "expected alias events to update one agent")
        try expect(state.agents.first?.status == .completed, "expected agent_completed alias to complete agent")
        try expect(state.activeAgents.isEmpty, "expected completed alias to remove active agent")
    }

    private static func testHTTPIngestRequestValidation() throws {
        let body = """
        {"type":"agent_status_update","agent":{"id":"ingest-test","name":"Ingest Test","status":"running","currentTask":"Validate request","startedAt":"2026-06-02T19:00:00Z","updatedAt":"2026-06-02T19:00:00Z","activity":"Request accepted"}}
        """
        let request = "POST /events HTTP/1.1\r\nContent-Length: \(Data(body.utf8).count)\r\n\r\n\(body)"
        let event = try HTTPIngestRequest.decodeEvent(from: request)

        if case .agentStatusUpdate(let agent) = event {
            try expect(agent.id == "ingest-test", "expected decoded ingest agent")
        } else {
            throw TestFailure(message: "expected agent_status_update event")
        }

        let badPath = "POST /wrong HTTP/1.1\r\n\r\n\(body)"
        do {
            _ = try HTTPIngestRequest.decodeEvent(from: badPath)
            throw TestFailure(message: "expected bad path rejection")
        } catch HTTPIngestRequestError.unsupportedPath {
        }
    }

    private static func testSessionActivityEventsReplayIntoState() throws {
        let activity = SessionActivity(
            timestamp: Date(timeIntervalSince1970: 3_000),
            category: "message",
            title: "Agent message",
            detail: "Reading project files"
        )
        let line = try EventCodec.encodeJSONLine(.sessionActivityRecorded(activity))
        let events = EventCodec.decodeJSONLines(line)

        var state = MonitorState()
        state.apply(events)

        try expect(state.sessionActivities == [activity], "expected session activity to replay into state")
        try expect(state.lastEventAt == activity.timestamp, "expected session activity timestamp to update last event")
    }

    private static func testObserveOnlyPolicySanitizesForbiddenOperations() throws {
        var state = MonitorState()
        state.apply(.permissionWarningTriggered(PermissionScope(
            agentId: "policy-test",
            allowedOperations: ["read_codex_session_jsonl", "modify_codex", "control_agents"],
            rateLimit: RateLimit(limit: 100, used: 5, window: "1h")
        )))

        let scope = state.permissions.first(where: { $0.agentId == "policy-test" })
        try expect(scope?.allowedOperations == ["read_codex_session_jsonl"], "expected forbidden operations to be removed")
        try expect(scope?.warnings.count == 2, "expected forbidden operation warnings")
        try expect(state.diagnostics.contains("policy-test: Observe-only policy forbids operation: modify_codex"), "expected modify Codex diagnostic")
        try expect(state.diagnostics.contains("policy-test: Observe-only policy forbids operation: control_agents"), "expected control agents diagnostic")
        try expect(state.health == .critical, "expected policy violation to make health critical")
    }

    private static func testCodexDashboardTokenDerivedValues() throws {
        let status = TokenStatus(
            currentTaskTokens: 12_000,
            contextWindowUsed: 61_000,
            contextWindowLimit: 200_000,
            fiveHourUsedPercent: 18,
            weeklyUsedPercent: 42
        )

        try expect(status.contextUsedPercent == 30.5, "expected context percentage")
        try expect(status.contextRemaining == 139_000, "expected context remaining")

        let agent = CodexAgentStatus(
            id: "agent-main",
            displayName: "Main Agent",
            sessionId: "session-1",
            sessionName: "Streaming Platform",
            status: .running,
            currentAction: "Implementing Token Provider",
            model: "GPT-5.5",
            reasoningMode: .high,
            files: [CodexFileActivity(path: "TokenProvider.swift", activity: .editing, updatedAt: Date(timeIntervalSince1970: 1))],
            tokenStatus: status,
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        try expect(agent.files.first?.activity == .editing, "expected file activity")
        try expect(agent.reasoningMode == .high, "expected reasoning mode")
    }

    private static func testMonitorStateCodexDashboardAdapter() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        var state = MonitorState()
        state.apply(.agentStarted(AgentTelemetry(
            id: "turn-1",
            name: "Codex Thread",
            status: .running,
            currentTask: "Codex session turn started",
            startedAt: now,
            updatedAt: now,
            activity: "Editing Sources/CodexAgentMonitorCore/TokenProvider.swift"
        )))
        state.apply(.tokenUsageUpdated(UsageMetrics(
            window5h: 1_200,
            window7d: 9_000,
            total: 12_000,
            remaining: 188_000,
            contextWindowUsed: 61_000,
            contextWindowLimit: 200_000,
            fiveHourUsedPercent: 18,
            weeklyUsedPercent: 42,
            fiveHourResetAt: Date(timeIntervalSince1970: 4_300),
            weeklyResetAt: Date(timeIntervalSince1970: 5_000),
            trend: .rising,
            updatedAt: now
        )))
        state.apply(.permissionWarningTriggered(PermissionScope(
            agentId: "codex-thread",
            allowedOperations: ["read_codex_session_jsonl", "write_monitor_event_log", "run_local_validation"],
            rateLimit: RateLimit(limit: 100, used: 20, window: "5h"),
            warnings: []
        )))

        let adapter = MonitorStateCodexDashboardAdapter(state: state)
        let agents = try adapter.agentStatuses()
        let sessions = try adapter.sessions()
        let permissions = try adapter.permissionStatus()

        try expect(agents.first?.sessionId == "turn-1", "expected Codex thread session id")
        try expect(agents.first?.currentAction == "Editing Sources/CodexAgentMonitorCore/TokenProvider.swift", "expected current action")
        try expect(agents.first?.files.first?.path == "Sources/CodexAgentMonitorCore/TokenProvider.swift", "expected file activity path")
        try expect(agents.first?.files.first?.activity == .editing, "expected editing file activity")
        try expect(agents.first?.tokenStatus?.currentTaskTokens == 1_200, "expected token status")
        try expect(agents.first?.tokenStatus?.contextWindowLimit == 200_000, "expected context limit")
        try expect(agents.first?.tokenStatus?.weeklyUsedPercent == 42, "expected weekly percent")
        try expect(agents.first?.tokenStatus?.fiveHourResetAt == Date(timeIntervalSince1970: 4_300), "expected reset date")
        try expect(sessions.first?.id == "turn-1", "expected session status")
        try expect(permissions.commandExecution == .allowed, "expected command permission")
        try expect(permissions.fileWrites == .allowed, "expected file write permission")
        try expect(permissions.gitPush == .unavailable, "expected unavailable git push permission")
    }

    private static func testLocalGitStatusProviderParsesLogLine() throws {
        let commit = LocalGitStatusProvider.parseLogLine(
            "a13f92c\u{1f}add token provider\u{1f}2026-06-05T12:30:00Z",
            branch: "main",
            pushStatus: .pushed
        )

        try expect(commit?.shortHash == "a13f92c", "expected short hash")
        try expect(commit?.message == "add token provider", "expected message")
        try expect(commit?.branch == "main", "expected branch")
        try expect(commit?.pushStatus == .pushed, "expected pushed status")
        try expect(commit?.localCommitAt != nil, "expected commit date")
        try expect(LocalGitStatusProvider.parsePushStatus(aheadBehindLine: "1\t0\n") == .unpushed, "expected unpushed status")
        try expect(LocalGitStatusProvider.parsePushStatus(aheadBehindLine: "0\t2\n") == .pushed, "expected pushed status")
    }

    private static func testLocalSkillStatusProviderReadsRepoSkills() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-agent-monitor-skills-\(UUID().uuidString)")
        let enabled = root.appendingPathComponent("cost-control")
        let disabled = root.appendingPathComponent("legacy-monitor")
        try FileManager.default.createDirectory(at: enabled, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: disabled, withIntermediateDirectories: true)
        try "---\nname: cost-control\ndescription: Test\n---\n".write(to: enabled.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "---\nname: legacy-monitor\ndescription: Test\n---\n".write(to: disabled.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "".write(to: disabled.appendingPathComponent(".disabled"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: root) }

        let provider = LocalSkillStatusProvider(skillsRootURL: root)
        let status = try provider.skillStatus()
        try expect(status.isAvailable, "expected skill status to be available")
        try expect(status.enabled == ["cost-control"], "expected enabled skill")
        try expect(status.disabled == ["legacy-monitor"], "expected disabled skill")

        try provider.setSkill("cost-control", enabled: false)
        let disabledStatus = try provider.skillStatus()
        try expect(disabledStatus.disabled.contains("cost-control"), "expected disabled marker")
        try provider.setSkill("cost-control", enabled: true)
        let enabledStatus = try provider.skillStatus()
        try expect(enabledStatus.enabled.contains("cost-control"), "expected enabled marker removal")
    }

    private static func testSettingsTabDeduplicatesAndFocuses() throws {
        var tabs = MonitorTabState()

        tabs.open(.settings)
        try expect(tabs.tabs.map(\.kind) == [.overview, .settings], "expected settings tab to be added once")
        try expect(tabs.selected == .settings, "expected settings tab to be selected")

        tabs.select(.overview)
        tabs.open(.settings)
        try expect(tabs.tabs.map(\.kind) == [.overview, .settings], "expected existing settings tab to be reused")
        try expect(tabs.selected == .settings, "expected existing settings tab to be focused")

        tabs.close(.settings)
        try expect(tabs.tabs.map(\.kind) == [.overview], "expected settings tab to close")
        try expect(tabs.selected == .overview, "expected overview to be selected after closing settings")
    }

    private static func testCodexSessionMapperMirrorsUsageAndToolEvents() throws {
        let tokenLine = """
        {"timestamp":"2026-05-24T22:44:26.308Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":24152842},"last_token_usage":{"total_tokens":182089},"context_window_used":61000,"context_window_limit":200000},"rate_limits":{"primary":{"used_percent":100.0,"window_minutes":10080,"resets_at":1780626599},"secondary":{"used_percent":42.0,"resets_at":1781213399}}}}
        """
        let usageEvents = CodexSessionEventMapper.events(from: tokenLine)
        try expect(usageEvents.count == 2, "expected usage and rate-limit events")

        var state = MonitorState()
        state.apply(usageEvents)
        try expect(state.usage.window5h == 182089, "expected last token usage to mirror into 5h window")
        try expect(state.usage.total == 24152842, "expected total token usage to mirror")
        try expect(state.usage.contextWindowUsed == 61_000, "expected context usage to mirror")
        try expect(state.usage.contextWindowLimit == 200_000, "expected context limit to mirror")
        try expect(state.usage.weeklyUsedPercent == 42, "expected weekly percent to mirror")
        try expect(state.usage.fiveHourResetAt == Date(timeIntervalSince1970: 1_780_626_599), "expected primary reset to mirror")
        try expect(state.permissions.first?.rateLimit.used == 100, "expected rate limit percent to mirror")
        try expect(state.health == .critical, "expected exhausted Codex rate limit to be critical")

        let toolLine = """
        {"timestamp":"2026-05-24T22:44:26.205Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"git status\\"}","call_id":"call_123"}}
        """
        state.apply(CodexSessionEventMapper.events(from: toolLine))
        try expect(state.activeAgents.contains(where: { $0.id == "tool-call_123" }), "expected tool call to mirror as active tool agent")

        let customToolLine = """
        {"timestamp":"2026-05-24T22:45:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","input":"*** Begin Patch","call_id":"call_custom"}}
        """
        let customToolOutputLine = """
        {"timestamp":"2026-05-24T22:45:01.000Z","type":"response_item","payload":{"type":"custom_tool_call_output","call_id":"call_custom","output":"Success"}}
        """
        state.apply(CodexSessionEventMapper.events(from: customToolLine))
        try expect(state.activeAgents.contains(where: { $0.id == "tool-call_custom" }), "expected custom tool call to mirror as active tool agent")
        state.apply(CodexSessionEventMapper.events(from: customToolOutputLine))
        try expect(state.agents.first(where: { $0.id == "tool-call_custom" })?.status == .completed, "expected custom tool output to complete tool agent")

        let failedPatchLine = """
        {"timestamp":"2026-05-24T22:45:02.000Z","type":"event_msg","payload":{"type":"patch_apply_end","call_id":"call_patch","success":false,"stderr":"Patch failed"}}
        """
        state.apply(CodexSessionEventMapper.events(from: failedPatchLine))
        try expect(state.agents.first(where: { $0.id == "tool-call_patch" })?.status == .error, "expected failed patch to mirror as tool error")
        try expect(state.diagnostics.contains("tool-call_patch: Patch failed"), "expected failed patch to add diagnostic")

        let webSearchLine = """
        {"timestamp":"2026-05-24T22:45:03.000Z","type":"response_item","payload":{"type":"web_search_call","status":"completed","action":{"type":"search","queries":["codex monitor"]}}}
        """
        let webSearchEndLine = """
        {"timestamp":"2026-05-24T22:45:04.000Z","type":"event_msg","payload":{"type":"web_search_end","call_id":"ws_123","query":"codex monitor","action":{"type":"search"}}}
        """
        state.apply(CodexSessionEventMapper.events(from: webSearchLine))
        try expect(state.agents.contains(where: { $0.name == "Web Search" && $0.activity == "codex monitor" }), "expected web search call to mirror as agent state")
        state.apply(CodexSessionEventMapper.events(from: webSearchEndLine))
        try expect(state.agents.first(where: { $0.id == "web-search-ws_123" })?.status == .completed, "expected web search end to mirror as completed")
    }

    private static func testEventLogReaderReplaysMirroredSessionEvents() throws {
        let lines = [
            """
            {"timestamp":"2026-05-24T22:45:05.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-reader","started_at":1780008305}}
            """,
            """
            {"timestamp":"2026-05-24T22:45:06.000Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\\"cmd\\":\\"git status\\"}","call_id":"call_reader"}}
            """,
            """
            {"timestamp":"2026-05-24T22:45:07.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":2000},"last_token_usage":{"total_tokens":200}},"rate_limits":{"primary":{"used_percent":85.0,"window_minutes":300}}}}
            """
        ]
        let events = lines.flatMap { CodexSessionEventMapper.events(from: $0) }
        let text = try events.map { try EventCodec.encodeJSONLine($0) }.joined(separator: "\n")
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-agent-monitor-reader-\(UUID().uuidString).jsonl")
        try "\(text)\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        guard let state = EventLogReader(url: url).readState() else {
            throw TestFailure(message: "expected reader to replay mirrored session events")
        }
        try expect(state.activeAgents.contains(where: { $0.id == "turn-reader" }), "expected Codex turn to replay into active UI state")
        try expect(state.activeAgents.contains(where: { $0.id == "tool-call_reader" }), "expected tool call to replay into active UI state")
        try expect(state.usage.total == 2000, "expected token usage to replay into UI state")
        try expect(state.permissions.first?.rateLimit.used == 85, "expected rate limit to replay into UI state")
    }

    private static func testCodexSessionMapperMirrorsMessagesAndContext() throws {
        var state = MonitorState()
        let lines = [
            """
            {"timestamp":"2026-06-03T10:01:00.000Z","type":"session_meta","payload":{"id":"session-1","source":"cli"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:01.000Z","type":"turn_context","payload":{"turn_id":"turn-1","cwd":"/tmp/project"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:02.000Z","type":"event_msg","payload":{"type":"user_message","message":"Build the monitor"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:03.000Z","type":"event_msg","payload":{"type":"agent_message","message":"Reading project files"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:04.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Implemented the mapper"}]}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:05.000Z","type":"response_item","payload":{"type":"reasoning","summary":[],"content":null,"encrypted_content":"redacted"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:06.000Z","type":"event_msg","payload":{"type":"thread_goal_updated","objective":"Verify session mirroring"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:07.000Z","type":"event_msg","payload":{"type":"context_compacted"}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:08.000Z","type":"compacted","payload":{}}
            """,
            """
            {"timestamp":"2026-06-03T10:01:09.000Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1"}}
            """
        ]

        state.apply(lines.flatMap { CodexSessionEventMapper.events(from: $0) })

        try expect(state.agents.contains(where: { $0.id == "codex-thread" && $0.currentTask == "Codex context compacted" }), "expected compaction record to mirror as thread activity")
        try expect(state.sessionActivities.count == 9, "expected message and context records to persist in session activity history")
        try expect(state.sessionActivities.contains(where: { $0.title == "User message" && $0.detail == "Build the monitor" }), "expected user message to persist in activity history")
        try expect(state.sessionActivities.contains(where: { $0.title == "Codex reasoning" }), "expected reasoning marker to persist in activity history")
        try expect(state.agents.first(where: { $0.id == "turn-1" })?.status == .error, "expected aborted turn to mirror as error")
        try expect(state.diagnostics.contains("turn-1: Codex turn aborted"), "expected aborted turn diagnostic")
    }

    private static func testCodexCLIStateReaderReadsLatestRollout() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("codex-agent-monitor-cli-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions/2026/06/05")
        let history = root.appendingPathComponent("history.jsonl")
        let sessionID = "019e9557-e183-7f80-9a37-6e49beb7f547"
        let rollout = sessions.appendingPathComponent("rollout-2026-06-05T05-13-45-\(sessionID).jsonl")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let rolloutLines = [
            #"{"timestamp":"2026-06-05T01:14:35.730Z","type":"session_meta","payload":{"id":"019e9557-e183-7f80-9a37-6e49beb7f547","source":"cli"}}"#,
            #"{"timestamp":"2026-06-05T01:14:36.445Z","type":"turn_context","payload":{"turn_id":"turn-1","session_id":"019e9557-e183-7f80-9a37-6e49beb7f547","cwd":"/tmp/project","model":"gpt-5.5","collaboration_mode":{"settings":{"reasoning_effort":"medium"}}}}"#,
            #"{"timestamp":"2026-06-05T01:14:53.585Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":79486},"last_token_usage":{"total_tokens":28542},"model_context_window":258400},"rate_limits":{"primary":{"used_percent":29.0,"window_minutes":300,"resets_at":1780626599},"secondary":{"used_percent":5.0,"window_minutes":10080,"resets_at":1781213399}}}}"#
        ].joined(separator: "\n")
        try "\(rolloutLines)\n".write(to: rollout, atomically: true, encoding: .utf8)
        try #"{"session_id":"019e9557-e183-7f80-9a37-6e49beb7f547","ts":1780658148,"text":"Fix Missing Real Codex Data"}"#.write(to: history, atomically: true, encoding: .utf8)

        guard let state = CodexCLIStateReader(
            sessionsRootURL: root.appendingPathComponent("sessions"),
            historyURL: history
        ).readLatestState() else {
            throw TestFailure(message: "expected Codex CLI state")
        }

        let agent = state.agents.first { $0.id == sessionID }
        try expect(agent?.sessionName == "Fix Missing Real Codex Data", "expected history session name")
        try expect(agent?.model == "gpt-5.5", "expected model metadata")
        try expect(agent?.reasoningMode == .medium, "expected reasoning metadata")
        try expect(state.usage.contextWindowLimit == 258_400, "expected model context window")
        try expect(state.usage.contextWindowUsed == 28_542, "expected last usage as context used")
        try expect(state.usage.fiveHourUsedPercent == 29, "expected primary limit percent")
        try expect(state.usage.weeklyUsedPercent == 5, "expected weekly limit percent")
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
