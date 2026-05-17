#!/usr/bin/env bash
set -euo pipefail

swift build
swift run CodexAgentMonitorTestRunner
swift run CodexAgentMonitorE2ERunner
