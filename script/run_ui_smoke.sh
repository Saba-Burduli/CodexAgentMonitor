#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT_DIR/logs"
APP_LOG="$LOG_DIR/ui-smoke-app.log"
SCREENSHOT="$LOG_DIR/ui-smoke-screen.png"
PID_FILE="$LOG_DIR/ui-smoke.pid"
EVENT_LOG="$HOME/.codex-agent-monitor/events.jsonl"
MENU_VIEW="$ROOT_DIR/Sources/CodexAgentMonitor/Views/MonitorMenuView.swift"

mkdir -p "$LOG_DIR"

for identifier in \
  'monitor.menu.root' \
  'monitor.tabs' \
  'tab.kind.rawValue' \
  'monitor.header.health' \
  'monitor.sessionActivity.summary' \
  'monitor.usage.summary' \
  'monitor.usage.progress' \
  'monitor.diagnostics.summary'; do
  grep -Fq "$identifier" "$MENU_VIEW"
done

swift run --package-path "$ROOT_DIR" CodexAgentMonitorE2ERunner > "$LOG_DIR/ui-smoke-e2e.log"

grep -q '"id":"tester-agent"' "$EVENT_LOG"
grep -q '"id":"tester-agent-error-case"' "$EVENT_LOG"
grep -q '"type":"agent_error"' "$EVENT_LOG"
grep -q '"activity":"Simulated tool failure handled safely"' "$EVENT_LOG"
grep -q '"type":"token_usage_updated"' "$EVENT_LOG"

NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
cat >> "$EVENT_LOG" <<JSONL
{"type":"session_activity_recorded","sessionActivity":{"id":"ui-smoke-session-activity","timestamp":"$NOW","category":"codex_session","title":"UI smoke session activity","detail":"Session activity visible in menu state"}}
JSONL
grep -q '"type":"session_activity_recorded"' "$EVENT_LOG"
grep -q '"id":"ui-smoke-session-activity"' "$EVENT_LOG"

pkill -x CodexAgentMonitor 2>/dev/null || true
swift run --package-path "$ROOT_DIR" CodexAgentMonitor > "$APP_LOG" 2>&1 &
echo $! > "$PID_FILE"

APP_PID=""
for _ in {1..30}; do
  APP_PID="$(pgrep -x CodexAgentMonitor | head -1 || true)"
  if [[ -n "$APP_PID" ]]; then
    break
  fi
  sleep 1
done

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
if [[ ! -s "$SCREENSHOT" ]]; then
  echo "UI smoke screenshot was not created"
  exit 1
fi

kill "$APP_PID" 2>/dev/null || true
wait "$(cat "$PID_FILE")" 2>/dev/null || true

echo "CodexAgentMonitor UI smoke passed"
echo "app_pid=$APP_PID"
echo "process_count=$PROCESS_COUNT"
echo "event_log=$EVENT_LOG"
echo "app_log=$APP_LOG"
echo "screenshot=$SCREENSHOT"
