---
name: quanto-ops-firm-onboarding
description: First-run setup guide for a firm adopting QuantoBooks — teaches the project-per-client operating model, inventories the firm's clients, sets firm-wide defaults (where results get delivered, default schedule cadences, headless auth), schedules the cross-client digest, and tracks setup progress in a checklist it keeps across conversations. Run once in the firm / home context (not inside a single client's project), then again whenever onboarding a new client. Trigger phrases — "set up QuantoBooks for our firm", "get our firm started", "onboard our firm", "how do we roll this out", "firm setup", "where do we start", "what's left to set up".
---

# Firm Onboarding (operational setup)

This is the **getting-started guide for a whole firm** adopting QuantoBooks. Run it once when a firm comes on board — in the firm's home / general context, **not** inside a single client's project — and return to it whenever they add a client. Its job is to teach the operating model, set the firm's defaults once, and **drive the per-client setup to completion**, keeping track of how far along the firm is between conversations.

It operates at **firm scope**. It doesn't pull any one client's books — that's what `quanto-ops-client-onboarding` does, per client, in that client's project. Anything here that does touch a specific client still follows `quanto-client-context`.

> **Prerequisite:** the plugin must be installed and the QuantoBooks data connection authenticated first — that's `quanto-ops-setup` (which runs `quanto-ops-connect`). If the connector isn't live yet, start there; this guide assumes the tools already work.

## The operating model you're teaching

Say this plainly early on, because everything else follows from it:

- **One project per client.** A firm keeps a Cowork (or Claude Code) project for each managed client and does that client's books inside it. The project *is* the client's workspace — schedules, briefings, and delivery all pin to it. (This is the same model `quanto-client-context` assumes.)
- **One firm / home context for cross-client work.** The firm-wide morning triage (`quanto-firm-digest`) and this onboarding guide live here, not in any single client project.
- **Read-and-summarize automation, human-in-the-loop on writes.** Recurring runs prepare work for review; a person approves anything that writes to the books, pays, or goes to the client (`quanto-schedule-workflow` safety posture). These runs live on the sandbox's **local scheduler** and re-arm themselves on each fire, so they survive CronCreate's 7-day cap — `quanto-schedule-workflow` owns the mechanism; managed/cloud routines are only a fallback.

## Keep a setup checklist (this is how it stays stateful)

This skill is meant to be run more than once — a firm won't set up twenty clients in one sitting. So it tracks state in a **visible checklist the firm can see**, and re-reads it at the start of every run to pick up where it left off:

- **Prefer a file:** `quanto-firm-setup.md` in the firm/home project root (Claude Code, or any host with a filesystem).
- **No filesystem?** Keep it in the host's persistent surface instead — a pinned project doc or a Slack/Notion canvas — and tell the user where it lives. Never invent state you didn't actually persist.

Format it so a human can read it at a glance:

```markdown
# QuantoBooks Firm Setup

## Firm defaults
- Delivery destinations: [e.g. Slack #client-ops for internal · Notion "Client Reports" DB]
- Default cadences: briefing weekly (before the standing call) · flag-triage weekly · close monthly
- Scheduler: local cron, self-rearming (fallback: host routine)
- Headless / scheduled-run auth: [confirmed | not yet confirmed]
- Firm digest schedule: [daily 7:00 ET | not yet]

## Clients
| Client            | Project | Discovery | Schedule          | Delivery     | Notes |
|-------------------|---------|-----------|-------------------|--------------|-------|
| Acme Corp         | done    | done      | briefing Mon 7am  | Slack #acme  |       |
| Beta Holdings LLC | —       | —         | —                 | —            | new   |
```

On every run: read the checklist first, report what's done and what's left, then continue — don't start over.

## Playbook

### Step 1 — Orient and locate the checklist

Confirm you're in the firm/home context, not a client project. If the project name matches a single client, say so and suggest running `quanto-ops-client-onboarding` there instead. Read the existing `quanto-firm-setup.md` if present; otherwise explain you'll create one and proceed.

### Step 2 — Teach the model

If this is the first run, lay out the operating model above in two or three sentences. Don't lecture — the firm wants to get going. The goal is just that they understand *why* it's a project per client before they start making them.

### Step 3 — Inventory the clients

Call `list_clients`. Write every client into the checklist's Clients table with empty setup columns — this is the firm's worklist. Note which clients are mapped to Karbon (they'll have richer context at per-client setup) if that's visible.

### Step 4 — Set firm-wide defaults (once)

These get inherited by every per-client setup, so capture them here instead of re-asking client by client:

- **Delivery destinations.** Where should results land? This is the question that makes automation worth it — a report nobody sees is wasted effort. Ask which of the firm's tools they want output in: **Slack** (which workspace / channel convention), **Notion** (which space or database), or email. If none is connected to the host yet, name the options and nudge them to connect one — hand the specifics to `quanto-deliver-results`.
- **Default cadences.** Sensible starting points per workflow (briefing weekly before the call; flag-triage weekly; close monthly). The user can override per client later.
- **Headless auth.** Scheduled runs are unattended and need the QuantoBooks connector authenticated non-interactively (an API key, not interactive sign-in). Flag this now; the first scheduled run is the real test (see `quanto-schedule-workflow`). Scheduling itself runs on the sandbox's **local cron** as a self-rearming chain (preferred over Claude-managed routines, resilient to the 7-day cron cap) — `quanto-schedule-workflow` owns it.

Record all of it in the checklist's Firm defaults block.

### Step 5 — Schedule the firm digest

Set up `quanto-firm-digest` to run at firm scope each morning (it sweeps every client read-only and routes attention) — hand off to `quanto-schedule-workflow`, pinned to the firm/home context, **not** a single client. Deliver it to the firm's internal destination from Step 4 so it's waiting in Slack/Notion at the start of the day. Mark it done in the checklist.

### Step 6 — Drive the per-client setup

For each client still unset, nudge the concrete next action: *"Open (or create) a project for **Beta Holdings**, then run `quanto-ops-client-onboarding` in it — that wires up its discovery, its schedule, and where its results go."*

Offer to go one at a time. When a client's per-client setup reports back, update that client's row. Don't try to onboard every client from the firm context — the work happens in each client's project; this skill tracks and routes.

### Step 7 — Report progress

End every run with the scoreboard: how many clients are fully set up, which are partial (and what they're missing), and what's next. Keep it short and concrete — it's a status line, not a report.

## Things to NEVER do

- Never run this inside a single client's project to set up *that* client — that's `quanto-ops-client-onboarding`. This skill is firm-level.
- Never mark a client done just because it's listed — a row is complete only when project, discovery, schedule, and delivery are all real.
- Never promise scheduled runs will work before the headless-auth model is confirmed — flag the first run as the test.
- Never fabricate checklist state — if you couldn't persist the file, say where the state actually lives (or that it doesn't).

## Relationship to other skills

- `quanto-ops-client-onboarding` — the per-client counterpart this skill routes the user into, once per client project.
- `quanto-schedule-workflow` — owns the recurring schedules this sets up (the firm digest here; per-client schedules in the client skill).
- `quanto-deliver-results` — owns the delivery destinations this captures as firm defaults.
- `quanto-firm-digest` — the one firm-scoped recurring workflow, scheduled in Step 5.
- `quanto-client-onboarding-review` — the books *diagnostic*; the per-client setup runs it as its discovery step. Different from this operational guide.
