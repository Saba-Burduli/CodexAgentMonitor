# System Context

CodexAgentMonitor is a native macOS menu-bar observability layer for Codex-style agent workflows.

## Product Boundary

This project observes and displays agent telemetry. It must not modify Codex, control agents, kill processes, trigger external systems, or assume private OpenAI infrastructure access.

Real integrations should feed local events into the app through an explicit boundary, currently the default JSONL event log at:

```text
~/.codex-agent-monitor/events.jsonl
```

If an integration cannot provide real token, quota, permission, or lifecycle data, keep the UI honest by showing unavailable/demo state instead of inventing values.

## Primary Surfaces

- macOS menu-bar item with health status icon.
- Dropdown panel with active agents, token usage, permission/rate-limit details, diagnostics, and settings access.
- Settings panel for event source path and health-rule explanation.

## Core Domain

The core model tracks:

- agents with ID, name, status, task, start time, update time, duration, and current activity;
- usage metrics for 5-hour and 7-day windows, total usage, remaining quota, and trend;
- permission scopes with allowed operations, rate limits, and warnings;
- system health derived from blocked agents, quota pressure, permission warnings, and rate-limit usage.

## Engineering Rules

Keep observable business logic in `Sources/CodexAgentMonitorCore/` and keep macOS-specific UI/filesystem behavior in `Sources/CodexAgentMonitor/`.

Preserve the observe-only boundary unless the user explicitly asks for a future control/enforcement extension. If enforcement is added later, it must be opt-in, documented, and isolated behind a clear integration protocol.

Run `./script/run_tests.sh` after meaningful changes. This includes the orchestrated E2E simulation and must pass before completion. The local Command Line Tools environment cannot import XCTest/Testing, so verification currently uses `CodexAgentMonitorTestRunner`.
