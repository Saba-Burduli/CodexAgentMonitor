# Project Status

Last updated: 2026-06-03

## Current State

CodexAgentMonitor has an initial working SwiftPM macOS menu-bar app, a typed observability core, JSONL event ingestion, demo telemetry fallback, documentation, and an executable verification runner.

The GitHub repository is published at:

```text
https://github.com/Saba-Burduli/CodexAgentMonitor
```

## Shipped

- Native SwiftUI `MenuBarExtra` app for macOS.
- Health status icon model: healthy, warning, critical.
- Active agent list with ID, name, status, task, start time, duration, and activity.
- Recent session activity history in the menu UI for mirrored Codex thread/session records.
- Token/quota usage display for 5-hour and 7-day windows, total, remaining, and trend.
- Permission scope display with allowed operations, rate limits, and warnings.
- Diagnostics panel for warning and critical conditions.
- Settings panel for event log path and health-rule explanation.
- JSONL event contract at `~/.codex-agent-monitor/events.jsonl`.
- Demo telemetry when no event log is available.
- Core reducer and event codec in `CodexAgentMonitorCore`.
- Executable verification runner via `CodexAgentMonitorTestRunner`.
- Orchestrated E2E simulation via `CodexAgentMonitorE2ERunner` with simulated Orchestrator, Tester, Constraint Audit, and Session Mirror Validation agents.
- Menu-bar UI smoke runner via `script/run_ui_smoke.sh`.
- UI smoke checks for expected tester-agent events, final error transition, app process visibility, and screenshot artifact creation.
- Local HTTP ingest daemon via `CodexAgentMonitorIngestDaemon` for appending posted events to the JSONL feed.
- Request-level HTTP ingest validation for method, path, content length, and event JSON decoding.
- Configurable sample event writer arguments for ID, name, status, task, and activity.
- Additional accessibility identifiers for usage, diagnostics, permission rows, and menu sections.
- Material-backed menu health header with native visual emphasis.
- UI smoke assertions that require the menu accessibility identifiers used by automation.
- Local ad-hoc signed `.app` bundle build via `script/build_app.sh`.
- Settings now opens as a de-duplicated, focusable, closable tab beside Overview.
- UI smoke checks include the tab container and dynamic tab identifier expression.
- Codex session JSONL mapper for task lifecycle, token usage, rate limits, tool calls, custom tools, patch results, web search, messages, reasoning markers, goal updates, turn context, session metadata, aborts, and compaction records.
- Codex session mirror CLI via `CodexAgentMonitorSessionMirror`, including `--session` and `--event-log` options.
- Codex session mirror follow mode via `--follow`, with bounded `--max-polls` support for deterministic smoke tests.
- Shared core `EventLogReader`, so app UI polling and verification tests replay the same event-log state path.
- Shared core `SessionActivity` state and `session_activity_recorded` events with bounded recent-history retention.
- Mirrored-session replay test proving mapped Codex session events reduce into active agents, usage metrics, and permission/rate-limit state.
- Session mirror smoke script validating one-shot import and live appended-line follow behavior.
- Context docs: `AGENTS.md`, `SYSTEM.md`, `PROJECT_STATUS.md`, `README.md`, and `docs/`.

## Verification

Latest local verification command:

```sh
./script/run_tests.sh
```

Latest known result:

```text
CodexAgentMonitorTestRunner: 11 tests passed
CodexAgentMonitorE2ERunner: passed
CodexAgentMonitor session mirror smoke passed
events_processed=30
checks_passed=16
final_health=critical
final_agents=7
active_agents=0
```

Runtime smoke completed earlier with `swift run CodexAgentMonitor`; the app process started successfully and was stopped cleanly.

## Known Constraints

- The app is observe-only and does not control Codex agents.
- Real Codex token/quota data requires an explicit external integration layer to emit events.
- Real Codex session import is a local CLI adapter. Live mirroring requires running `CodexAgentMonitorSessionMirror --follow` beside the app.
- The local Command Line Tools environment cannot import XCTest or Testing, so tests are implemented through an executable runner.
- The app currently polls a JSONL file rather than using a persistent daemon or socket stream.
- E2E validation logs are runtime artifacts at `logs/e2e-validation.log` and are regenerated locally.

## Next Priorities

1. Add a future opt-in enforcement protocol only if explicitly requested.
