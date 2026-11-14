#!/usr/bin/env bash
set -euo pipefail
# Backward-compatible alias; Phase49 adds XMLTV/EPG targets.
exec bash tool/format_phase37_49_dart.sh "$@"
