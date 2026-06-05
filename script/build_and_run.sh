#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="CodexAgentMonitor"
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
LOG_DIR="$ROOT_DIR/logs"
CONFIGURATION="debug"
MODE="${1:-}"

mkdir -p "$LOG_DIR"

pkill -x "$APP_NAME" 2>/dev/null || true
"$ROOT_DIR/script/build_app.sh" "$CONFIGURATION"
/usr/bin/open -n "$APP_DIR"
sleep 2

if pgrep -x "$APP_NAME" >/dev/null; then
  echo "launched=$APP_DIR"
else
  echo "launch_failed=$APP_DIR" >&2
  exit 1
fi

case "$MODE" in
  --logs)
    /usr/bin/log stream --style compact --predicate "process == '$APP_NAME'" --info
    ;;
  --verify|"")
    ;;
  *)
    echo "unknown_mode=$MODE" >&2
    exit 2
    ;;
esac
