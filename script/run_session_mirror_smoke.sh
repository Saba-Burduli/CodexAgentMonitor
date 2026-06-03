#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION_FILE="$(mktemp -t codex-agent-monitor-session).jsonl"
EVENT_LOG="$(mktemp -t codex-agent-monitor-events).jsonl"
FOLLOW_LOG="$(mktemp -t codex-agent-monitor-follow).log"

cleanup() {
  rm -f "$SESSION_FILE" "$EVENT_LOG" "$FOLLOW_LOG"
}
trap cleanup EXIT

cat > "$SESSION_FILE" <<'JSONL'
{"timestamp":"2026-06-03T10:00:00.000Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-smoke","started_at":1780480800}}
JSONL

swift run --package-path "$ROOT_DIR" CodexAgentMonitorSessionMirror -- --session "$SESSION_FILE" --event-log "$EVENT_LOG" > "$FOLLOW_LOG"
grep -q 'events_written=1' "$FOLLOW_LOG"
grep -q '"id":"turn-smoke"' "$EVENT_LOG"
grep -q '"type":"agent_started"' "$EVENT_LOG"

: > "$EVENT_LOG"
swift run --package-path "$ROOT_DIR" CodexAgentMonitorSessionMirror -- --session "$SESSION_FILE" --event-log "$EVENT_LOG" --follow --poll-interval 0.2 --max-polls 4 > "$FOLLOW_LOG" &
MIRROR_PID=$!

sleep 0.35
cat >> "$SESSION_FILE" <<'JSONL'
{"timestamp":"2026-06-03T10:00:01.000Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-smoke"}}
JSONL

wait "$MIRROR_PID"

grep -q 'total_events_written=2' "$FOLLOW_LOG"
grep -q '"type":"agent_started"' "$EVENT_LOG"
grep -q '"type":"agent_completed"' "$EVENT_LOG"
grep -q '"agentId":"turn-smoke"' "$EVENT_LOG"

echo "CodexAgentMonitor session mirror smoke passed"
