# Repository Guidelines

Default: use `$cost-control`.

## Context Rules

- Load context minimally and intentionally.
- Search before reading large files; read the smallest useful range.
- Do not scan the whole repository unless necessary.
- Avoid generated folders, dependency folders, caches, logs, build output, `.build/`, `dist/`, and secrets.
- Do not use subagents, install dependencies, make network calls, or run broad tests without approval.
- Explain important decisions, not obvious steps.
- Report only files changed, commands run, validation, skipped expensive actions, and remaining risks.

## Semantic Repo Map Workflow

Before editing, build a lightweight repo map and rank files. The goal is the smallest correct edit surface.

1. Extract task signals from the request, errors, diffs, or tests:
   symbols, filenames, paths, modules, commands, event names, UI labels, error text, domain terms, tests, fixtures.
2. Search cheaply before opening files:
   `git status --short`, `rg "<signal>"`, `rg --files`, `git grep "<signal>"`.
3. Rank candidate files before deep reading:
   direct path/symbol matches first, then nearby tests, then owning model/view/runner files, then docs.
4. Open only the top candidates first with narrow ranges:
   `sed -n 'start,endp' file`, `rg -n "<signal>" file`.
5. Expand only when evidence requires it:
   follow imports/callers/tests one hop at a time; avoid broad repo scans.
6. Edit minimally:
   keep changes scoped to the ranked files; do not refactor unrelated code.
7. Validate with the narrowest relevant command:
   prefer `swift run CodexAgentMonitorTestRunner` for core logic, `swift run CodexAgentMonitorE2ERunner` for event flows, `./script/run_tests.sh` for broader verification, and `./script/run_ui_smoke.sh` only for UI/runtime changes.

## Project Shape

CodexAgentMonitor is a SwiftPM macOS menu-bar app.

- `Sources/CodexAgentMonitor/`: SwiftUI/AppKit menu-bar UI and local polling service.
- `Sources/CodexAgentMonitorCore/`: domain models, event decoding, reducer, and health rules.
- `Sources/CodexAgentMonitorTestRunner/`: focused core verification runner.
- `Sources/CodexAgentMonitorE2ERunner/`: orchestrated E2E simulation runner.
- `docs/`: architecture and integration notes.
- `script/`: local build and verification helpers.

Keep business rules in `CodexAgentMonitorCore`. Keep macOS UI and filesystem polling in `CodexAgentMonitor`.

## Commands

- `swift build`: build all targets.
- `swift run CodexAgentMonitorTestRunner`: run core verification tests.
- `./script/run_tests.sh`: run build, core verification, and E2E simulation.
- `./script/run_ui_smoke.sh`: launch UI smoke flow and capture screenshot.
- `swift run CodexAgentMonitor`: launch the menu-bar app.

Prefer the narrowest useful command for validation.

## Boundaries

- This app is observability-only.
- Do not add direct agent control, process killing, external command execution, or Codex internals coupling without an explicit integration layer and user approval.
- Prefer small, typed models and deterministic tests.
- Update docs only when event contracts, setup, architecture, or UX behavior materially change.
- Preserve existing project style unless clearly broken.
