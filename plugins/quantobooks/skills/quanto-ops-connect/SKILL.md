---
name: quanto-ops-connect
description: Connect and authenticate the QuantoBooks (QuickBooks) data connection so the quanto-* skills can read the books — covers the QuantoBooks account, adding the connector (one-click OAuth or API key), confirming the active client, and verifying that scheduled / headless runs can authenticate without a human. USE THIS when the quanto-* skills can't reach QuickBooks, someone says "connect QuantoBooks", "authenticate the connector", "the quanto skills can't see my books", "no active client", "set up the API key", or "scheduled run can't reach the books". Trigger phrases — "connect my books", "authenticate QuantoBooks", "QuantoBooks says not authenticated", "set up the QuantoBooks connector", "why can't Claude see my QuickBooks".
---

# Connect QuantoBooks (data + auth)

This is the QuantoBooks **access gate**: the quanto-* skills do nothing useful until Claude can reach your QuickBooks data through the QuantoBooks connector. It's the equivalent of "getting access," but for QuantoBooks that means a **QuantoBooks account + an authenticated data connection**, not a code repo.

Prerequisite: the QuantoBooks plugin is installed (`quanto-ops-setup`). You guide and verify; the person performs the sign-in/clicks. Never assume it worked — verify with a live call.

## Step 1 — Account + a connected QuickBooks company

- Confirm they have a **QuantoBooks account** (created from the QuantoBooks dashboard) and that their firm has at least **one QuickBooks Online company connected** to it. The connector reads whatever QBO companies the firm has linked.
- No account / no company connected → that happens in the QuantoBooks dashboard first; the connector has nothing to read until then.

## Step 2 — Pick the auth model

QuantoBooks supports two; pick by environment:

- **One-click OAuth (recommended, no key).** On Claude Code the plugin bundles the connector, so the first time a quanto-* tool runs you'll get a sign-in prompt; if not, run `/mcp` and authenticate **quantobooks**. The browser flow signs you in with your QuantoBooks account and scopes the grant to your firm. It's read-only by default; the write tools are unlocked by approving the write scope on the consent screen.
- **API key.** From the QuantoBooks dashboard, presented as a bearer credential on the connector. This is the path for **headless / scheduled runs** and for clients without the bundled connector (Step 5). Treat it like a password.

## Step 3 — Connect, by environment

- **Claude Code (terminal):** the bundled connector points at the hosted server. Run `/mcp` → authenticate **quantobooks** (OAuth), or set the API key in the connector's config/env. Confirm it shows connected.
- **Cowork:** Customize → connectors → add the **QuantoBooks** connector and sign in with the QuantoBooks account. On first use of a quanto-* skill you may be prompted to authenticate.
- **Claude Desktop:** add the QuantoBooks server to the MCP config with the hosted URL + your API key (the dashboard / INSTALL guide has the exact config).

## Step 4 — Verify the connection + active client

Ask for a live read: *"What's my active QuantoBooks client?"* The model should call `get_active_client_info` and name a company.
- **No active client / not authenticated** → the connection isn't live; recheck Steps 2–3.
- **Multiple companies** → use `list_clients`, then `switch_client` to set the right one. (The day-to-day discipline of confirming the active client lives in `quanto-client-context`.)

## Step 5 — Verify HEADLESS / scheduled-run auth (don't skip)

This is the step that makes the scheduling skills reliable. A **scheduled, unattended run can't do interactive OAuth** — no human is there to click. It needs a **non-interactive credential**: an API key configured on the connector, not a one-time browser sign-in.

- If they'll use `quanto-schedule-workflow` (recurring runs), confirm the connector has an **API key** configured so background runs authenticate on their own.
- If you can't verify it from the environment, say so plainly: *"Your first scheduled run is the real test — if it errors on auth, the connector needs an API key rather than interactive sign-in."* Never promise headless runs will work if you couldn't confirm the credential.

## Things to NEVER do

- Never paste an API key into a shared chat, a public field, or anything logged — treat it like a password.
- Never call the connection "done" without a live `get_active_client_info` succeeding — an added-but-unauthenticated connector looks connected and still fails every skill.
- Never promise scheduled / headless runs will authenticate on interactive OAuth alone — they need an API key (Step 5).
- Never switch a client's books without confirming the `client_id` (`quanto-client-context`).

## Relationship to other skills

- `quanto-ops-setup` — installs the plugin; this is its Step 2.
- `quanto-schedule-workflow` — recurring runs depend on the headless auth verified here (Step 5).
- `quanto-client-context` — the active-client discipline every workflow skill follows once you're connected.
