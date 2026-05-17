# Repository Guidelines

## Project Structure

CodexAgentMonitor is a SwiftPM macOS menu-bar app.

- `Sources/CodexAgentMonitor/`: SwiftUI/AppKit menu-bar UI and local polling service.
- `Sources/CodexAgentMonitorCore/`: observable domain models, event decoding, reducer, health rules.
- `Sources/CodexAgentMonitorTestRunner/`: executable verification runner for event ingestion and quota/health behavior.
- `Sources/CodexAgentMonitorE2ERunner/`: orchestrated self-test runner with simulated orchestrator and tester agents.
- `docs/`: architecture and integration notes.
- `script/`: local build and verification helpers.

Keep business rules in `CodexAgentMonitorCore`. Keep macOS UI and filesystem polling in `CodexAgentMonitor`.

## Commands

- `swift build`: build all targets.
- `swift run CodexAgentMonitorTestRunner`: run core verification tests without XCTest.
- `./script/run_tests.sh`: run build, core verification, and orchestrated E2E simulation.
- `./script/run_ui_smoke.sh`: generate E2E telemetry, launch the menu-bar app, verify the macOS process, and capture a runtime screenshot artifact.
- `swift run CodexAgentMonitor`: launch the menu-bar app from the agent PTY.

## Engineering Notes

This app is an observability layer only. It reads agent, token, and permission events from a local integration boundary and displays state. Do not add direct agent control, process killing, external command execution, or Codex internals coupling without an explicit integration layer and user approval.

Prefer small, typed models and deterministic tests. Update docs when event contracts or UX behavior change.

## TODO-Driven Git Workflow

Development must proceed as a stream of small, traceable changes.

Loop for every implementation task:

1. Find the next explicit TODO or the next item in `PROJECT_STATUS.md`.
2. Implement only that TODO or one tightly scoped subtask of it.
3. Validate locally with the narrowest useful command.
4. Commit immediately with a clear technical message.
5. Push immediately before starting the next task.

Commit rules:

- Keep each commit focused on one idea, fix, or feature increment.
- Avoid mixing unrelated files or multiple TODOs in one commit.
- Do not accumulate unpushed commits.
- If push fails, fix the push before continuing development.
- Use clear messages such as `add agent event dispatcher`, `fix tester agent state sync`, or `implement orchestrator event handler`.
- Do not use vague messages such as `update code` or `fix stuff`.

Safety rules:

- Do not perform broad refactors unless the current TODO explicitly requires it.
- Do not batch completed work for later commits.
- Preserve the observe-only product boundary unless a future TODO explicitly introduces an opt-in integration layer.
