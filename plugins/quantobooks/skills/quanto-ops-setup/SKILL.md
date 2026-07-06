---
name: quanto-ops-setup
description: First-time setup for QuantoBooks in Claude — installs the QuantoBooks skills plugin, connects the QuantoBooks (QuickBooks) data connection, verifies it works, turns on auto-updates, and hands off to firm/client onboarding. USE THIS when someone is getting started, says "set me up on QuantoBooks", "install QuantoBooks", "I'm new to QuantoBooks", "get QuantoBooks working in Claude", "the quanto skills aren't showing up", or downloaded the QuantoBooks setup skill on its own. Works as a standalone bootstrap — it does not assume the rest of the plugin is installed yet. Trigger phrases — "set me up on QuantoBooks", "install the QuantoBooks plugin", "get started with QuantoBooks", "connect QuantoBooks", "why aren't my quanto skills working".
---

# QuantoBooks Setup (getting started)

The single entry point for getting QuantoBooks working in Claude: install the plugin, connect the data, verify, learn how to stay updated — then hand off to the operating-model onboarding.

**This skill is the bootstrap.** It is the one skill a brand-new user can download on its own (from the QuantoBooks dashboard's Learn Center) before anything else exists. So — unlike every other QuantoBooks skill — it does **not** begin with "Follow `quanto-client-context` first": that skill isn't installed yet. Getting the rest installed is this skill's whole job.

Tone: friendly and concrete. Most users are in **Cowork**, are not developers, and just want their books connected. You (the agent) guide and verify; the person performs the clicks/commands. Never assume terminal access — confirm the environment first.

## Start every run by establishing context

1. **Which Claude?** Cowork (the desktop app / claude.ai), Claude Code (terminal), or Claude Desktop chat. This changes almost every step — Desktop can't use plugin marketplaces, so steer those users to Cowork or Claude Code.
2. **Brand-new to Cowork?** Have them run **`/setup-cowork`** first (Anthropic's built-in starter), then come back here for the QuantoBooks specifics.
3. **Resuming?** Ask what's already done and re-verify rather than redo.

## The checklist

Render this and keep it updated (✅ done · ⬜ todo · ⏭️ skipped/N-A):

```
QuantoBooks setup — [name], [environment]
⬜ 1. Install the QuantoBooks plugin
⬜ 2. Connect the QuantoBooks data + authenticate
⬜ 3. Verify: a quanto-* skill loads AND an active client resolves
⬜ 4. Turn on auto-update
⬜ 5. Know how to update later
⬜ 6. Hand off to firm / client onboarding
```

### Step 1 — Install the QuantoBooks plugin

QuantoBooks ships as a **public** plugin marketplace (`quantotechnologylabs/quantobooks-skills`) — no GitHub access or account needed just to install.

- **Cowork (most users):** Customize (toolbox) → **Personal plugins** → **+** → **Create plugin → Add marketplace** → paste `quantotechnologylabs/quantobooks-skills` → install **quantobooks** → toggle it **enabled**.
- **Claude Code (terminal):**
  ```
  /plugin marketplace add quantotechnologylabs/quantobooks-skills
  /plugin install quantobooks@quantobooks
  ```
  then `/reload-plugins` (or restart). On Claude Code the plugin also **bundles the data connection** — you authenticate it in Step 2.
- **Claude Desktop:** no marketplace support — use Cowork or Claude Code, or upload skills via the in-app Skills uploader from the dashboard bundle.

Installing brings in the whole bundle, including `quanto-ops-connect` and `quanto-ops-update`, which the next steps use.

### Step 2 — Connect the data → `quanto-ops-connect`

The skills are inert until the QuantoBooks data connection (the connector to your QuickBooks) is authenticated. Now that the plugin is installed, hand off to **`quanto-ops-connect`** for the full flow (account → connector → one-click OAuth or API key → confirm the active client → headless-auth check).

Short version if you want it inline: in Claude Code run `/mcp` and authenticate **quantobooks** (one-click sign-in); in Cowork add the QuantoBooks connector and sign in with your QuantoBooks account. Then confirm an active client resolves.

### Step 3 — Verify

Ask for something that needs the connection: *"What's my active QuantoBooks client?"* — a quanto-* skill should run `get_active_client_info` and name a company. If it can't, the connection isn't authenticated → back to `quanto-ops-connect`. Both "a skill engaged" and "an active client resolved" must be true to tick this.

### Step 4 — Turn on auto-update

So new skills and fixes arrive without manual work: enable auto-update for the `quantobooks` marketplace where the client exposes it (Cowork Marketplaces tab / Claude Code `/plugin` marketplaces). Even with it on, Cowork caches the catalog — that's Step 5.

### Step 5 — Know how to update later → `quanto-ops-update`

Set the expectation now: updating in Cowork can need a catalog refresh (and sometimes a remove/re-add of the marketplace). Point them at **`quanto-ops-update`** — they'll want it each release.

### Step 6 — Hand off to onboarding

Setup is "tools working." The operating model is next:
- **Firm-level** (run once, in the firm/home context): **`quanto-ops-firm-onboarding`** — the project-per-client model, firm defaults, the cross-client digest.
- **Per client** (in each client's project): **`quanto-ops-client-onboarding`** — discovery, schedule, delivery.

## Finish

When 1–5 are ✅, QuantoBooks is installed, connected, verified, and updatable. Summarize what's done, what was skipped and why, and the one next thing — usually: run `quanto-ops-firm-onboarding` to set up the firm.

## Things to NEVER do

- Never assume the environment — confirm Cowork / Claude Code / Desktop first; the steps differ.
- Never tell a Desktop user to drop skill files into the app folder — it's ignored; use Cowork or Claude Code.
- Never call setup "done" until an active client actually resolves (Step 3) — an installed-but-unconnected plugin looks set up while every skill quietly fails.
- Never paste an API key into a shared or public field (see `quanto-ops-connect`).

## Relationship to other skills

- `quanto-ops-connect` — the data connection + auth (Step 2); the access gate for everything else.
- `quanto-ops-update` — keeping the plugin current (Step 5).
- `quanto-ops-firm-onboarding` / `quanto-ops-client-onboarding` — the operating-model setup this hands off to (Step 6).
- `quanto-client-context` — the foundation guard every *workflow* skill follows, available once installed. This setup skill is the one exception that runs before it exists.
