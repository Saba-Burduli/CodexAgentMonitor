---
name: targeted-review
description: Low-cost review workflow for changed files, diffs, and pull requests.
---

# Targeted Review

Use this skill for reviewing diffs or PRs.

Workflow:
- Review only changed files unless the diff requires a direct dependency check.
- Start with `git diff --stat`, then inspect focused `git diff` output.
- Prioritize correctness, security, regressions, data loss, edge cases, and missing tests.
- Avoid style-only comments unless requested or the issue harms maintainability.
- Do not run broad tests unless requested.
- If running validation, use only commands tied to the changed files.
- Report findings first with file and line references, then note validation gaps.
