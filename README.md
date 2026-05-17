# CodexAgentMonitor

CodexAgentMonitor is a native macOS menu-bar observability app for Codex-style agent workflows. It shows active agents, live state, token/quota telemetry, permission scopes, rate limits, and quick diagnostics from a local event stream.

This project does not modify Codex and does not control external systems. It observes JSONL events from an integration layer and renders them in the menu bar.

## Features

- Native macOS menu-bar app using SwiftUI `MenuBarExtra`.
- Health icon states: green healthy, yellow high usage, red critical/blocked.
- Active agent list with ID, name, status, task, start time, duration, and activity.
- Usage metrics for last 5 hours, last 7 days, total usage, remaining quota, and trend.
- Permission scope and rate-limit display per agent.
- Diagnostics panel for permission and quota warnings.
- Demo telemetry when no event log exists.

## Requirements

- macOS 14 or newer.
- Swift 6.3 toolchain or compatible Xcode command line tools.

## Build And Run

```sh
swift build
swift run CodexAgentMonitor
```

When launched from Codex, the app runs from the agent PTY. The menu-bar item appears in the macOS menu bar.

## Tests

```sh
./script/run_tests.sh
```

The current Command Line Tools environment cannot import XCTest/Testing, so core checks run through `CodexAgentMonitorTestRunner`. Full validation also runs `CodexAgentMonitorE2ERunner`, which simulates an orchestrator agent and tester agent end to end.

## Event Log Contract

Default path:

```text
~/.codex-agent-monitor/events.jsonl
```

Each line is one JSON event. Dates use ISO-8601.

Supported event types:

- `agent_started`
- `agent_updated`
- `agent_status_update`
- `agent_finished`
- `agent_completed`
- `agent_error`
- `token_usage_updated`
- `permission_warning_triggered`

Example:

```json
{"type":"agent_started","agent":{"id":"local-main","name":"Primary Codex","status":"running","currentTask":"Implement feature","startedAt":"2026-05-17T12:00:00Z","updatedAt":"2026-05-17T12:00:10Z","activity":"Reading files"}}
```

See [Architecture](docs/architecture.md) for the full model boundary. See [End-to-End Testing](docs/e2e-testing.md) for the orchestrated tester-agent simulation.
