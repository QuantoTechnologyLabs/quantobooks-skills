---
name: quanto-project-pin
description: Pin a Cowork / Claude Code project to one QuantoBooks client so workflows can never run against the wrong client's books — creates the per-project pin file the plugin's session-guard hooks enforce, and verifies the guard is live. USE THIS when setting up a new client project, when the user says "pin this project to [client]", "lock this project to a client", "make sure I'm always on the right client here", "set up the client pin", or when quanto-ops-client-onboarding reaches its anchor step. Also covers changing or removing a pin.
---

# Project → Client Pin

Follow the rules in `quanto-client-context` first.

QuantoBooks users work across many clients, usually one Cowork/Claude Code
project per client. The classic mistake: switching projects while the MCP
connection's active client still points at the previous client, then running a
workflow against the wrong books. The pin makes that structurally impossible:

- A **pin file** (`.claude/quanto-client.json` in the project folder) declares
  which client this project belongs to.
- The **plugin's hooks** (shipped with the quantobooks plugin, v0.12.0+)
  enforce it: at session start Claude is told the pin; every QuantoBooks data
  tool is **blocked** until `switch_client` to the pinned client has succeeded
  this session; and `switch_client` to any *other* client is blocked outright.
  Read-only tools are auto-allowed (no permission prompts) once verified.

The pin is a hard guard, not a suggestion — but it lives in a plain file the
user can edit or delete at any time. It protects against accidents, not intent.

## Prerequisites

- The quantobooks plugin **v0.12.0 or newer** installed (hooks ship with it) —
  `quanto-ops-setup` / `quanto-ops-update` if not.
- A working QuantoBooks connection (`quanto-ops-connect`).
- An environment with a project folder and hooks: **Cowork** or **Claude
  Code**. Plain claude.ai chat has neither — there, rely on the server-side
  guards (sessions start with no active client; every response echoes the
  active client) and consider a **pinned connector** (below).

## Playbook

### Step 1 — Resolve the client

Per `quanto-client-context`: if the user named a client, match it via
`list_clients`; otherwise infer from the project name and confirm. Never pin on
a guess — the pin will enforce whatever you write, so writing the wrong client
is worse than no pin. Echo the choice: *"Pinning this project to **Acme Corp**
(client_id `…`)."*

### Step 2 — Write the pin file

Create `.claude/quanto-client.json` in the project root (create the `.claude/`
directory if needed) with exactly:

```json
{
  "clientId": "<client_id from list_clients>",
  "companyName": "<company name>"
}
```

Both fields matter: `clientId` is what the guard compares; `companyName` is for
humans reading the file and the session-start banner.

### Step 3 — Activate and verify

The SessionStart part of the guard only announces the pin in *new* sessions,
but the blocking guard is live immediately. Verify it:

1. Call `switch_client` with the pinned client_id — must succeed.
2. Call `get_active_client_info` — must echo the pinned client.
3. Tell the user: from now on, in this project, data tools are blocked until
   the pinned client is active, and switching to any other client is blocked.
   New sessions get the pin announced up front.

If the guard doesn't engage (step 1 of a *fresh* session doesn't mention the
pin, or a deliberate `switch_client` to another client is NOT blocked), the
plugin hooks aren't running — check the plugin version (`quanto-ops-update`)
and that the session runs inside this project folder.

### Step 4 — Optional: fully lock the connection (pinned connector)

The pin file guards Claude's behavior in this project. For a lock that holds on
**every** surface (including plain claude.ai chat), the QuantoBooks MCP server
also supports **connection-level pinning**: add `?client_id=<client_id>` to the
connector URL (e.g. `https://mcp.quantobooks.com/?client_id=…`), or send an
`x-quanto-client-id` header on API-key connections. A pinned connection starts
on that client and rejects `switch_client` to any other — server-side, no hooks
involved. Offer this when the firm sets up one connector per client project.

## Changing or removing a pin

- **Change:** update `clientId` + `companyName` in `.claude/quanto-client.json`
  (re-run Steps 1–3). Confirm with the user first — repinning a project is a
  deliberate act, not a workaround for "the guard blocked me".
- **Remove:** delete the file. The project falls back to the standard
  `quanto-client-context` confirm-before-use rules.
- If the user hits a block and asks why: explain the pin, show the file, and
  ask whether they meant to work on the other client (→ its own project) or to
  repin this one.

## Things to NEVER do

- Never write the pin file without the user confirming the client — the guard
  enforces whatever is written.
- Never edit or delete the pin file just because a tool call was denied —
  surface the denial to the user and let them decide.
- Never present the pin as a security boundary — it prevents accidents;
  anyone with the project folder can change it.

## Relationship to other skills

- `quanto-client-context` — the soft confirm-first rules; the pin hard-enforces
  them in pinned projects.
- `quanto-ops-client-onboarding` — runs this as its anchor step when setting up
  a client's project.
- `quanto-ops-setup` / `quanto-ops-update` — get the plugin (and its hooks)
  installed and current.
