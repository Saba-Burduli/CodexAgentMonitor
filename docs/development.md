# Development

## Commands

```sh
swift build
./script/run_tests.sh
./script/run_ui_smoke.sh
swift run CodexAgentMonitorTestRunner
swift run CodexAgentMonitorE2ERunner
swift run CodexAgentMonitor
```

## Local Event Testing

Create a sample event log:

```sh
mkdir -p ~/.codex-agent-monitor
cat > ~/.codex-agent-monitor/events.jsonl <<'JSONL'
{"type":"agent_started","agent":{"id":"local-main","name":"Primary Codex","status":"running","currentTask":"Testing event ingestion","startedAt":"2026-05-17T12:00:00Z","updatedAt":"2026-05-17T12:00:10Z","activity":"Reading JSONL"}}
{"type":"token_usage_updated","usage":{"window5h":120000,"window7d":800000,"total":1400000,"remaining":600000,"trend":"rising","updatedAt":"2026-05-17T12:00:10Z"}}
JSONL
```

Launch the app:

```sh
swift run CodexAgentMonitor
```

Delete or empty the log to return to demo telemetry.
