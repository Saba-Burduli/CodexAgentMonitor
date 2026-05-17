# Architecture

CodexAgentMonitor is intentionally split into a UI shell and a testable observability core.

## Targets

- `CodexAgentMonitor`: SwiftUI macOS executable. Owns `MenuBarExtra`, settings, polling, and local filesystem access.
- `CodexAgentMonitorCore`: models, event decoding, state reducer, demo telemetry, and health rules.
- `CodexAgentMonitorTestRunner`: executable core checks for lifecycle, usage, permission, and event-codec behavior.
- `CodexAgentMonitorE2ERunner`: orchestrated simulation with an Orchestrator Agent and Tester Agent.

## Observability Boundary

The app reads append-only JSONL events from `~/.codex-agent-monitor/events.jsonl` by default. This is the integration layer between Codex/proxy tooling and the menu-bar UI.

The app must not:

- modify Codex internals;
- start, stop, or kill agents;
- execute external systems as part of observation;
- assume access to private OpenAI infrastructure.

Future integrations should write events into the JSONL file or expose an equivalent local API that can be adapted into `MonitorEvent` values.

## Event Flow

1. Integration layer emits one JSON event per line.
2. `EventLogReader` reads the file on a short polling interval.
3. `EventCodec` decodes valid lines and skips malformed lines.
4. `MonitorState.apply(_:)` reduces events into current agents, usage, permissions, diagnostics, and health.
5. SwiftUI renders the latest state in the menu bar.

## Orchestrated Self-Test

`CodexAgentMonitorE2ERunner` runs a simulated Tester Agent through an Orchestrator Agent. The tester emits structured lifecycle, rapid update, completion, error, usage, and permission events. The orchestrator applies every event to `MonitorState`, writes `~/.codex-agent-monitor/events.jsonl`, verifies replayability after each event, and logs state snapshots to `logs/e2e-validation.log`.

## Health Rules

- `healthy`: no blocked/error agents, no permission warnings, quota/rate limits are healthy.
- `warning`: remaining quota is at or below 20%, usage trend is spiking, or rate usage is at or above 80%.
- `critical`: blocked/error agents, explicit permission warnings, rate usage at or above 95%, or remaining quota at or below 5%.

## Event Schema

Agent fields:

```json
{
  "id": "local-main",
  "name": "Primary Codex",
  "status": "running",
  "currentTask": "Implement feature",
  "startedAt": "2026-05-17T12:00:00Z",
  "updatedAt": "2026-05-17T12:00:10Z",
  "activity": "Reading files"
}
```

Usage fields:

```json
{
  "window5h": 120000,
  "window7d": 800000,
  "total": 1400000,
  "remaining": 600000,
  "trend": "rising",
  "updatedAt": "2026-05-17T12:00:10Z"
}
```

Permission fields:

```json
{
  "agentId": "local-main",
  "allowedOperations": ["read_files", "write_project_files", "run_local_tests"],
  "rateLimit": { "limit": 120, "used": 64, "window": "1h" },
  "warnings": []
}
```
