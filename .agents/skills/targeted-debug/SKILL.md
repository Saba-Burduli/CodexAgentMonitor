---
name: targeted-debug
description: Low-cost debugging workflow for bugs, errors, failing tests, stack traces, and regressions.
---

# Targeted Debug

Use this skill for bugs, errors, failing tests, stack traces, or regressions.

Workflow:
- Start from the exact error, failing assertion, stack trace, or reproduction step.
- Inspect only files directly named by the error or required by the failing path.
- Form one hypothesis at a time.
- Make the smallest fix that addresses the confirmed cause.
- Avoid architecture rewrites and unrelated cleanup.
- Run only the relevant test, command, or reproduction step.
- If validation is expensive or unavailable, state what was skipped and why.
- Report the root cause, files changed, targeted validation, and remaining risk.
