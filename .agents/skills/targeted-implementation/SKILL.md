---
name: targeted-implementation
description: Low-cost workflow for adding small features with narrow inspection and small diffs.
---

# Targeted Implementation

Use this skill for adding small features or narrowly scoped behavior.

Workflow:
- Clarify the smallest implementation path from the request.
- Inspect only the relevant modules, adjacent patterns, and direct callers when needed.
- Keep the diff small and localized.
- Avoid broad refactors, architecture rewrites, and speculative abstractions.
- Preserve existing style, naming, validation, and error-handling patterns.
- Add or update only directly relevant docs or tests.
- Run targeted validation for the changed behavior.
- Report files changed, validation, skipped expensive actions, and assumptions.
