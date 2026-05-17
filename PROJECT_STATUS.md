# Project Status

Last updated: 2026-05-17

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
- Token/quota usage display for 5-hour and 7-day windows, total, remaining, and trend.
- Permission scope display with allowed operations, rate limits, and warnings.
- Diagnostics panel for warning and critical conditions.
- Settings panel for event log path and health-rule explanation.
- JSONL event contract at `~/.codex-agent-monitor/events.jsonl`.
- Demo telemetry when no event log is available.
- Core reducer and event codec in `CodexAgentMonitorCore`.
- Executable verification runner via `CodexAgentMonitorTestRunner`.
- Orchestrated E2E simulation via `CodexAgentMonitorE2ERunner` with simulated Orchestrator Agent and Tester Agent.
- Menu-bar UI smoke runner via `script/run_ui_smoke.sh`.
- Context docs: `AGENTS.md`, `SYSTEM.md`, `PROJECT_STATUS.md`, `README.md`, and `docs/`.

## Verification

Latest local verification command:

```sh
./script/run_tests.sh
```

Latest known result:

```text
CodexAgentMonitorTestRunner: 5 tests passed
CodexAgentMonitorE2ERunner: passed
events_processed=16
checks_passed=8
final_health=critical
final_agents=2
active_agents=0
```

Runtime smoke completed earlier with `swift run CodexAgentMonitor`; the app process started successfully and was stopped cleanly.

## Known Constraints

- The app is observe-only and does not control Codex agents.
- Real Codex token/quota data requires an explicit external integration layer to emit events.
- The local Command Line Tools environment cannot import XCTest or Testing, so tests are implemented through an executable runner.
- The app currently polls a JSONL file rather than using a persistent daemon or socket stream.
- E2E validation logs are runtime artifacts at `logs/e2e-validation.log` and are regenerated locally.

## Next Priorities

1. Expand UI smoke automation with accessibility identifiers and targeted menu-bar assertions.
2. Add an optional local daemon or helper that can ingest events over HTTP or Unix socket and append to the JSONL log.
3. Add a sample event writer CLI for integration testing.
4. Add richer menu-bar visual polish and accessibility identifiers for UI smoke automation.
5. Package a signed `.app` bundle for easier launch outside `swift run`.
6. Add a future opt-in enforcement protocol only if explicitly requested.
