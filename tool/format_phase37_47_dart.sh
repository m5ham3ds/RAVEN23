#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible alias; Phase48 extends the maintained formatter targets.
exec bash "$(dirname "$0")/format_phase37_48_dart.sh" "$@"
