#!/bin/sh
# PostToolUse recorder for switch_client / get_active_client_info /
# authenticate. Extracts the clientId the server reported as active and writes
# it to the per-session state file the PreToolUse guard reads — so data tools
# unlock only after the server itself confirmed the pinned client is active.
#
# The tool response arrives as escaped JSON inside the hook payload; stripping
# backslashes makes the clientId field directly extractable with sed.

INPUT=$(cat)
CLEAN=$(printf '%s' "$INPUT" | tr -d '\\')

SESSION=$(printf '%s' "$CLEAN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -n "$SESSION" ] || exit 0

CLIENT=$(printf '%s' "$CLEAN" | sed -n 's/.*"clientId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -n "$CLIENT" ] || exit 0

printf '%s' "$CLIENT" > "${TMPDIR:-/tmp}/quanto-pin-verified-${SESSION}"
exit 0
