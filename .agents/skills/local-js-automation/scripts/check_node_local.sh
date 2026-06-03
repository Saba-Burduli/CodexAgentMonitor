#!/usr/bin/env bash
set -euo pipefail

# Verifies whether local Node.js is available without using MCP, network calls, or credentials.
if ! command -v node >/dev/null 2>&1; then
  echo "node_available=false"
  exit 0
fi

echo "node_available=true"
node --version
