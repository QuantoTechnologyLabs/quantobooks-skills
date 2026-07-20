#!/bin/sh
# SessionStart: if this project is pinned to a QuantoBooks client
# (.claude/quanto-client.json), inject the pin into the session context so
# Claude switches to the right client before touching any books.
#
# POSIX sh + sed only — hook scripts run on whatever the user's machine has,
# so no jq/node dependency.

PIN_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/quanto-client.json"
[ -f "$PIN_FILE" ] || exit 0

PIN=$(tr -d '\\' < "$PIN_FILE")
CLIENT_ID=$(printf '%s' "$PIN" | sed -n 's/.*"clientId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
COMPANY=$(printf '%s' "$PIN" | sed -n 's/.*"companyName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
[ -n "$CLIENT_ID" ] || exit 0

# The company name lands inside a JSON string below — strip anything that
# could break it.
SAFE_COMPANY=$(printf '%s' "$COMPANY" | tr -d '"\\' | tr -d '\n')

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"QuantoBooks project pin: this project is pinned to client %s (client_id %s). Before any QuantoBooks data tool (qbo_*, quanto_*, karbon_*), call switch_client with client_id %s and confirm it succeeds — the QuantoBooks pin guard blocks data tools until the pinned client is the verified active client. To work on a different client, use that client'"'"'s own project, or update .claude/quanto-client.json."}}\n' \
  "$SAFE_COMPANY" "$CLIENT_ID" "$CLIENT_ID"
exit 0
