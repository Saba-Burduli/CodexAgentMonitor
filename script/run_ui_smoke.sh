#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
APP_LOG="$LOG_DIR/ui-smoke-app.log"
SCREENSHOT="$LOG_DIR/ui-smoke-screen.png"
PID_FILE="$LOG_DIR/ui-smoke.pid"
EVENT_LOG="$HOME/.codex-agent-monitor/events.jsonl"

mkdir -p "$LOG_DIR"

swift run --package-path "$ROOT_DIR" CodexAgentMonitorE2ERunner > "$LOG_DIR/ui-smoke-e2e.log"

grep -q '"type":"agent_error"' "$EVENT_LOG"
grep -q '"type":"token_usage_updated"' "$EVENT_LOG"

pkill -x CodexAgentMonitor 2>/dev/null || true
swift run --package-path "$ROOT_DIR" CodexAgentMonitor > "$APP_LOG" 2>&1 &
echo $! > "$PID_FILE"

sleep 3

APP_PID="$(pgrep -x CodexAgentMonitor | head -1 || true)"
if [[ -z "$APP_PID" ]]; then
  cat "$APP_LOG"
  exit 1
fi

PROCESS_COUNT="$(osascript -e 'tell application "System Events" to count processes whose name is "CodexAgentMonitor"')"
if [[ "$PROCESS_COUNT" -lt 1 ]]; then
  echo "CodexAgentMonitor was not visible to System Events"
  exit 1
fi

screencapture -x "$SCREENSHOT" 2>/dev/null || true

kill "$APP_PID" 2>/dev/null || true
wait "$(cat "$PID_FILE")" 2>/dev/null || true

echo "CodexAgentMonitor UI smoke passed"
echo "app_pid=$APP_PID"
echo "process_count=$PROCESS_COUNT"
echo "event_log=$EVENT_LOG"
echo "app_log=$APP_LOG"
echo "screenshot=$SCREENSHOT"
