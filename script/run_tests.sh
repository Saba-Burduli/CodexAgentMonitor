#!/usr/bin/env bash
set -euo pipefail

swift build
swift run CodexAgentMonitorTestRunner
swift run CodexAgentMonitorE2ERunner
./script/run_session_mirror_smoke.sh
