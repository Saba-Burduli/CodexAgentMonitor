# Repo-Local Codex Skills

This directory contains repo-local skills created to replace useful MCP-driven workflows with local-first Codex Skills.

## MCP Inspection Summary

Global config inspected but not modified because the user explicitly requested that `~/.codex/config.toml` must not be changed.

| Config path | MCP server | Current action | Replacement skill |
| --- | --- | --- | --- |
| `~/.codex/config.toml` | `mcp_servers.node_repl` | Recommended: add `enabled = false` manually under `[mcp_servers.node_repl]` | `$local-js-automation` |
| `.codex/config.toml` | none; file not present | No repo-local MCP config to disable | none |

No repo-local MCP server blocks were found, so no `.codex/config.toml` changes were made.

## Skills Created

### `$local-js-automation`

Use for local JavaScript/Node automation, quick JSON/data transforms, Node file validation, or replacing node_repl-style MCP execution with local commands.

Explicit invocation:

```text
$local-js-automation run a local Node check for this repo
```

Skill path:

```text
.agents/skills/local-js-automation/SKILL.md
```

Helper script:

```sh
.agents/skills/local-js-automation/scripts/check_node_local.sh
```

## Recommended Global MCP Edit

Because global config modification was explicitly forbidden, apply this manually if you want Codex MCP disabled globally:

```toml
[mcp_servers.node_repl]
enabled = false
```

Preserve existing fields such as `command`, `args`, `env`, `startup_timeout_sec`, and `tool_timeout_sec`.

## Capabilities Not Fully Replaced

- Persistent in-process Node REPL state from MCP is not replicated. The replacement is safer local one-shot commands or explicit scripts.
- Any browser automation behavior layered on top of a REPL must be re-created as explicit local scripts or project tests.
- Global MCP status still needs manual verification because `~/.codex/config.toml` was not modified.

## Suggested Verification

```sh
codex mcp list
```

Or inside Codex:

```text
/mcp
```
