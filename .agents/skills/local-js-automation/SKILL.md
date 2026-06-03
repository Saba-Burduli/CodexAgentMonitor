---
name: local-js-automation
description: Use when a task would benefit from local JavaScript or Node.js automation, small data transforms, browser-test helper scripting, or replacing node_repl-style MCP execution with safe local shell commands.
---

# Local JS Automation

## Purpose

Replace node_repl MCP-style JavaScript execution with local, inspectable, filesystem-based workflows. Use this skill to run small Node.js snippets, validate JavaScript files, transform local data, or create deterministic helper scripts without relying on MCP servers.

## When To Use

Use this skill when:

- A task asks for JavaScript execution, Node.js snippets, quick JSON/data transforms, or browser-test helper logic.
- Prior behavior would have used a `node_repl` MCP server.
- The work can be done locally with files, shell commands, and repository inspection.

Do not use this skill when:

- The task requires remote services, credentials, or unknown network calls.
- The repository has no JavaScript/Node requirement and a simpler shell/Swift/Python command is more appropriate.

## Step-By-Step Workflow

1. Inspect the repository before running code:
   - `pwd`
   - `git status --short`
   - `find . -maxdepth 3 -type f \( -name package.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name package-lock.json \)`
   - `rg -n "node|npm|pnpm|yarn|playwright|vite|next|jest|vitest" .` when relevant.
2. Prefer existing project scripts when a `package.json` exists:
   - `cat package.json`
   - `npm test`, `pnpm test`, or `yarn test` only if defined.
   - `npm run build`, `pnpm build`, or `yarn build` only if defined.
3. For quick local snippets, use temporary files or `node -e` with quoted, reviewable code.
4. For repeated logic, add a small script under the repository or skill `scripts/` directory and make it executable.
5. Capture only necessary output in the final response: what ran, what changed, and any failures.

## Commands Codex May Run Locally

Safe default commands:

```sh
git status --short
git diff --stat
rg -n "pattern" .
find . -maxdepth 3 -type f
node --version
node --check path/to/file.js
node -e 'console.log(JSON.stringify({ok:true}))'
```

Project-specific commands, only when the matching files/scripts exist:

```sh
npm test
npm run build
pnpm test
pnpm build
yarn test
yarn build
```

For this SwiftPM repository, prefer existing native checks unless the task specifically needs JavaScript:

```sh
swift build
./script/run_tests.sh
./script/run_ui_smoke.sh
```

## Safety Constraints

- Do not use MCP tools for JavaScript execution.
- Do not install packages unless the user explicitly asks.
- Do not make network calls unless the user explicitly approves.
- Do not print environment variables or secret values.
- Do not run destructive commands such as `rm -rf`, `git reset --hard`, or force pushes.
- Do not execute untrusted generated code without inspecting it first.
- Prefer local files and deterministic scripts over hidden REPL state.

## Expected Final Response Format

Return a concise report with:

- Commands run.
- Files changed, if any.
- Test/build results.
- Any limitations or follow-up needed.
