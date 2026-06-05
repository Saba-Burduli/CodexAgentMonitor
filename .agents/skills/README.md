# Repo-Local Codex Skills

These skills keep CodexAgentMonitor work targeted, local-first, and low-cost.

Available skills:

- `$cost-control`: Default mode for minimizing token usage, context size, network use, installs, broad tests, and broad file reads.
- `$targeted-debug`: Use for bugs, errors, failing tests, stack traces, or regressions. Starts from the exact error and validates the smallest fix.
- `$targeted-implementation`: Use for small features. Keeps inspection narrow, avoids rewrites, and limits the diff.
- `$targeted-review`: Use for diffs or PRs. Reviews changed files with `git diff --stat` and focused `git diff`.
- `$local-js-automation`: Use for local JavaScript/Node automation or replacing node_repl-style MCP execution with explicit local commands.

Invocation examples:

```text
$cost-control
$targeted-debug
$targeted-implementation
$targeted-review
$local-js-automation run a local Node check for this repo
```

Notes:

- Load only the skill needed for the task.
- Keep validation targeted; prefer `swift run CodexAgentMonitorTestRunner` for core logic and avoid full scripts unless needed.
- Do not use network calls, package installs, subagents, or broad tests without approval.
