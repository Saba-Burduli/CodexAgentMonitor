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
- `swift run CodexAgentMonitor`: launch the menu-bar app from the agent PTY.

## Engineering Notes

This app is an observability layer only. It reads agent, token, and permission events from a local integration boundary and displays state. Do not add direct agent control, process killing, external command execution, or Codex internals coupling without an explicit integration layer and user approval.

Prefer small, typed models and deterministic tests. Update docs when event contracts or UX behavior change.
