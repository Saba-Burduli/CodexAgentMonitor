# CodexAgentMonitor

CodexAgentMonitor is a native macOS menu-bar observability app for Codex-style agent workflows. It shows active agents, live state, token/quota telemetry, permission scopes, rate limits, and quick diagnostics from a local event stream.

This project does not modify Codex and does not control external systems. It observes JSONL events from an integration layer and renders them in the menu bar.

## Features

- Native macOS menu-bar app using SwiftUI `MenuBarExtra`.
- Health icon states: green healthy, yellow high usage, red critical/blocked.
- Active agent list with ID, name, status, task, start time, duration, and activity.
- Recent Codex session activity history for mirrored messages, context, goals, reasoning markers, and compaction records.
- Usage metrics for last 5 hours, last 7 days, total usage, remaining quota, and trend.
- Permission scope and rate-limit display per agent.
- Diagnostics panel for permission and quota warnings.
- Demo telemetry when no event log exists.
- Settings opens as a tab beside Overview and focuses the existing Settings tab if already open.
- Codex session JSONL mirror for importing local `~/.codex/sessions` telemetry into the app event log.

## Requirements

- macOS 14 or newer.
- Swift 6.3 toolchain or compatible Xcode command line tools.

## Build And Run

```sh
swift build
swift run CodexAgentMonitor
```

When launched from Codex, the app runs from the agent PTY. The menu-bar item appears in the macOS menu bar.

Build a local ad-hoc signed app bundle:

```sh
./script/build_app.sh release
open dist/CodexAgentMonitor.app
```

## Tests

```sh
./script/run_tests.sh
./script/run_ui_smoke.sh
```

The current Command Line Tools environment cannot import XCTest/Testing, so core checks run through `CodexAgentMonitorTestRunner`. Full validation also runs `CodexAgentMonitorE2ERunner`, which simulates an orchestrator agent and tester agent end to end. Use `swift run CodexAgentMonitorE2ERunner -- --live` to slow the feed down for menu-bar inspection.

## Local Event Writer

Append a sample integration event to the observed JSONL feed:

```sh
swift run CodexAgentMonitorEventWriter
```

Custom sample event:

```sh
swift run CodexAgentMonitorEventWriter -- --id writer-cli-test --name "Writer CLI Test" --status blocked --task "Validate CLI args" --activity "Custom event emitted"
```

## Local HTTP Ingest Daemon

Run a local observe-only HTTP helper that appends posted `MonitorEvent` JSON to the event log:

```sh
swift run CodexAgentMonitorIngestDaemon -- --port 8765
```

For one-shot validation:

```sh
swift run CodexAgentMonitorIngestDaemon -- --once --port 8765
```

## Codex Session Mirror

Import a real Codex session JSONL file into the app-readable event log:

```sh
swift run CodexAgentMonitorSessionMirror -- --session ~/.codex/sessions/YYYY/MM/DD/rollout-file.jsonl
```

If `--session` is omitted, the mirror imports the most recently modified `.jsonl` file under `~/.codex/sessions`.

For isolated validation without touching the live app feed:

```sh
swift run CodexAgentMonitorSessionMirror -- --session ~/.codex/sessions/YYYY/MM/DD/rollout-file.jsonl --event-log /tmp/codex-agent-monitor-events.jsonl
```

Follow a session file and mirror new records into the live app feed:

```sh
swift run CodexAgentMonitorSessionMirror -- --session ~/.codex/sessions/YYYY/MM/DD/rollout-file.jsonl --follow
```

For deterministic validation, bounded follow mode is available:

```sh
swift run CodexAgentMonitorSessionMirror -- --session /tmp/session.jsonl --event-log /tmp/events.jsonl --follow --poll-interval 0.2 --max-polls 4
```

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
- `session_activity_recorded`

Example:

```json
{"type":"agent_started","agent":{"id":"local-main","name":"Primary Codex","status":"running","currentTask":"Implement feature","startedAt":"2026-05-17T12:00:00Z","updatedAt":"2026-05-17T12:00:10Z","activity":"Reading files"}}
```

See [Architecture](docs/architecture.md) for the full model boundary. See [End-to-End Testing](docs/e2e-testing.md) for the orchestrated tester-agent simulation.
