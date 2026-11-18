#!/usr/bin/env bash
set -euo pipefail
# Backward-compatible entrypoint; the maintained list now includes Phase 42.
exec bash "$(dirname "$0")/format_phase37_42_dart.sh" "$@"
