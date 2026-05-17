# End-to-End Orchestrated Testing

CodexAgentMonitor includes a simulated multi-agent validation flow that must pass before the project is considered complete.

## Components

- `OrchestratorAgent`: receives events, updates global `MonitorState`, writes the app-readable JSONL feed, and writes validation logs.
- `TesterAgent`: simulated Codex worker that sends lifecycle, rapid update, token usage, permission, completion, and error events.
- `CodexAgentMonitorE2ERunner`: executable runner that wires the orchestrator and tester together, validates state transitions, and emits results.

## Communication Channel

The tester sends typed `MonitorEvent` values directly to the orchestrator through `AgentEventSink`.

The orchestrator writes every received event to:

```text
~/.codex-agent-monitor/events.jsonl
```

The macOS app observes that same file, so the E2E runner creates a realistic local integration feed for the menu-bar UI.

## Simulated Events

The E2E flow emits:

- `agent_started`
- `agent_status_update`
- `agent_completed`
- `agent_error`
- `token_usage_updated`
- `permission_warning_triggered`

It covers normal lifecycle, delayed/blocked state, rapid updates, usage changes, completion cleanup, and one handled failure case.

## Validation Checks

The runner verifies:

- all events are processed;
- the JSONL event log can be replayed after every event;
- no duplicate or ghost agents are created;
- the tester agent moves from running/blocked/running to completed;
- completed agents leave the active list;
- the simulated error agent is captured safely;
- system health becomes critical after the error;
- token usage metrics reflect the final spiking usage update;
- diagnostics include the simulated failure.

## Run

```sh
./script/run_tests.sh
```

Or run only the orchestrated E2E simulation:

```sh
swift run CodexAgentMonitorE2ERunner
```

Latest expected success output:

```text
CodexAgentMonitorE2ERunner: passed
events_processed=16
checks_passed=8
final_health=critical
final_agents=2
active_agents=0
event_log=/Users/sababurduli/.codex-agent-monitor/events.jsonl
validation_log=/Users/sababurduli/CodexAgentMonitor/logs/e2e-validation.log
```

## Logs

Validation logs are written locally to:

```text
logs/e2e-validation.log
```

The file is a runtime artifact and is not committed. It is regenerated on every E2E run.
