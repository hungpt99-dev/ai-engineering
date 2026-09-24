#!/usr/bin/env bash
# Alias for setup/check.sh (kept for docs compatibility)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$ROOT/setup/check.sh" "$@"
