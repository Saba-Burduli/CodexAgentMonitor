---
name: cost-control
description: Default low-cost workflow for minimizing token usage, context size, and expensive actions.
---

# Cost-Control

Default workflow for this repository.

Rules:
- Start from the exact request; avoid exploratory expansion.
- Load only directly relevant files and the smallest useful ranges.
- Search before reading large files.
- Do not scan the whole repository.
- Do not use subagents, network calls, or package installs without approval.
- Avoid broad tests, full builds, generated folders, dependencies, caches, logs, build output, `.build/`, `dist/`, and secrets.
- Prefer small patches over rewrites.
- Run only targeted validation that proves the change.
- Explain important decisions, not obvious steps.
- Report files changed, commands run, validation, skipped expensive actions, and remaining risks.
