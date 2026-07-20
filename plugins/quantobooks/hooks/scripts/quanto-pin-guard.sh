#!/bin/sh
# PreToolUse guard for QuantoBooks MCP tools. Two jobs:
#
#  1. Pin enforcement — when the project carries a client pin
#     (.claude/quanto-client.json), client-scoped data tools are DENIED until a
#     switch_client to the pinned client has been verified this session (the
#     PostToolUse recorder writes the verification), and switch_client to any
#     OTHER client is denied outright. The deny reason tells Claude exactly
#     which switch_client call to make, so it self-corrects in one step.
#
#  2. Read auto-allow — read-only QuantoBooks tools (everything except
#     *_create/*_update/*_delete, authenticate, switch_client) are ALLOWED
#     without a permission prompt. Writes keep the normal permission flow.
#
# Matches tools by their base name (after the mcp__<server>__ prefix) because
# the server segment varies by surface (quantobooks, Quantobooks, connector
# UUIDs in Cowork). POSIX sh + sed only — no jq/node dependency. Field
# extraction is greedy-regex over the single-line hook payload; good enough for
# the UUID-ish ids involved.

INPUT=$(cat)
CLEAN=$(printf '%s' "$INPUT" | tr -d '\\')
TOOL=$(printf '%s' "$CLEAN" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

case "$TOOL" in
  mcp__*__*) ;;
  *) exit 0 ;;
esac
BASE=${TOOL##*__}

# Only QuantoBooks-family tools concern this guard; other MCP servers pass through.
case "$BASE" in
  qbo_*|quanto_*|karbon_*|notion_*|switch_client|list_clients|get_active_client_info|get_auth_status|authenticate) ;;
  *) exit 0 ;;
esac

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}
deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

IS_READ=1
case "$BASE" in
  *_create*|*_update*|*_delete*|authenticate|switch_client) IS_READ=0 ;;
esac

PIN_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/quanto-client.json"
PIN_ID=""
if [ -f "$PIN_FILE" ]; then
  PIN_ID=$(tr -d '\\' < "$PIN_FILE" | sed -n 's/.*"clientId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
fi

if [ -z "$PIN_ID" ]; then
  # No pin: nothing to enforce, but reads still skip the permission prompt.
  [ "$IS_READ" = "1" ] && allow "QuantoBooks read-only tool"
  exit 0
fi

SESSION=$(printf '%s' "$CLEAN" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
STATE_FILE="${TMPDIR:-/tmp}/quanto-pin-verified-${SESSION:-unknown}"

case "$BASE" in
  authenticate|get_auth_status|list_clients|get_active_client_info)
    allow "QuantoBooks session/context tool"
    ;;
  switch_client)
    TARGET=$(printf '%s' "$CLEAN" | sed -n 's/.*"client_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    if [ "$TARGET" = "$PIN_ID" ]; then
      allow "switch_client to this project's pinned client"
    fi
    deny "This project is pinned to QuantoBooks client_id ${PIN_ID} (.claude/quanto-client.json). switch_client to a different client is blocked here — work on that client from its own project, or update the pin file first."
    ;;
  quanto_firm_document_*)
    allow "Firm-scoped read (needs no active client)"
    ;;
  *)
    VERIFIED=$(cat "$STATE_FILE" 2>/dev/null || true)
    if [ "$VERIFIED" = "$PIN_ID" ]; then
      [ "$IS_READ" = "1" ] && allow "Pinned client verified; read-only tool"
      exit 0
    fi
    deny "This project is pinned to QuantoBooks client_id ${PIN_ID}, but that client has not been verified as active this session. Call switch_client with client_id ${PIN_ID} first, then retry — this prevents running against another client's books."
    ;;
esac
