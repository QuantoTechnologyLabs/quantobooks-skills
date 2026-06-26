---
name: quanto-ops-client-onboarding
description: Operational setup for one QuantoBooks client's project — anchors the project to the client, runs the discovery diagnostic, gives the user a quick tour of the day-to-day tools, pins the client's standing schedule, and wires up where results get delivered. The per-client counterpart to quanto-ops-firm-onboarding; run once inside each client's own project. Distinct from quanto-client-onboarding-review, which is the books diagnostic this runs as one step. Trigger phrases — "set up this client's project", "wire up [client]", "get [client] going", "finish setting up [client]", "automate [client]", "onboard [client]'s project".
---

# Client Onboarding (operational project setup)

Follow the rules in `quanto-client-context` first — this skill wires automation to a specific client, so pinning the right client is the whole game.

This is the **per-client setup** that `quanto-ops-firm-onboarding` routes you into. Run it once inside a client's own project. It turns an empty project into a working client workspace: the books are diagnosed, the user knows the toolkit, the standing schedule is pinned, and results have somewhere to land.

It is **not** a books audit — that's `quanto-client-onboarding-review`, which this skill *runs* as its discovery step (Step 2). The split: this skill sets up the *workflow*; that one assesses the *books*.

## What "done" looks like

By the end, this client has: (1) the project confirmed as its workspace, (2) a discovery summary of the state of its books, (3) at least one standing recurring run pinned, and (4) a delivery destination for results. Those four are the columns this writes back to the firm checklist.

## Playbook

### Step 1 — Anchor the project to the client

Per `quanto-client-context`, confirm the active client and tie it to this project. If the project name matches a client, propose-and-confirm and `switch_client`; otherwise ask. Echo it: *"This is the **Acme Corp** project — setting Acme up as its workspace."*

If a `quanto-firm-setup.md` checklist exists (from the firm onboarding), read this client's row so you inherit the firm defaults (delivery, cadences) and don't re-ask what's already decided.

### Step 2 — Run discovery

Hand off to `quanto-client-onboarding-review` and run it for this client. That's the read-only diagnostic — COA hygiene, opening balances, vendor quality, period coverage, Karbon context. Surface its prioritized findings. This both *tells the user what they're working with* and *seeds* the day-to-day workflows they'll lean on (e.g. lots of uncategorized GL → `quanto-transaction-cleanup`; messy vendor list → `quanto-vendor-cleanup`).

### Step 3 — Quick tour of the toolkit

Briefly orient the user to the skills they'll use for this client day to day — don't run them, just name the two or three that matter most given what discovery found, plus the staples:

- **Daily / weekly:** `quanto-flag-triage` (work the action items), `quanto-client-briefing` (prep before the standing call).
- **Monthly:** `quanto-month-end-close`, `quanto-management-report`.
- **Whatever discovery flagged** as this client's first cleanup job.

One line each. The point is the user leaves knowing what to reach for — not a manual.

### Step 4 — Pin the standing schedule

This is the setup that makes the project run itself. Identify the recurring workflows that fit *this* client and pin them via `quanto-schedule-workflow`, inheriting the firm default cadences unless the user overrides:

- **The standing call → `quanto-client-briefing`.** If the client has a recurring meeting, capture its day/time and schedule the briefing to land just before it. This is the highest-value loop — push for it.
- **Weekly hygiene → `quanto-flag-triage`** (and a monitor or two — `quanto-cash-flow-watch`, `quanto-spend-watch` — if the client warrants it).
- **Monthly → `quanto-month-end-close`** or `quanto-management-report`.

Everything stays review-only and unattended-safe per `quanto-schedule-workflow`. Don't over-schedule — one or two real loops beat five the user ignores.

### Step 5 — Wire up delivery

Decide where this client's outputs land when those schedules fire — because an unattended run is only useful if the result reaches someone. Inherit the firm default destination, or set a client-specific one (e.g. a dedicated Slack channel per client). Hand the specifics to `quanto-deliver-results`, and bake the destination into the schedules from Step 4 so each run delivers itself.

### Step 6 — Record and report

Update this client's row in the firm checklist — project done, discovery done, schedule (what/when), delivery (where). Report back: what's set up, what runs when, where it lands, and the one thing the user should do first (usually: work the discovery findings via the flagged cleanup skill).

## Things to NEVER do

- Never wire automation to the wrong client — confirm the active client first, every time (`quanto-client-context`).
- Never write to the books during setup — discovery and the tour are read-only; actual changes happen later when the user runs a write skill with approval.
- Never pin a schedule that writes or sends to the client unattended — review-only, internal delivery only (`quanto-schedule-workflow`).
- Never schedule more than the user will actually use — a couple of meaningful loops, not a wall of routines.

## Relationship to other skills

- `quanto-ops-firm-onboarding` — the firm-level parent that routes here and holds the shared checklist + defaults.
- `quanto-client-onboarding-review` — the books diagnostic, run as Step 2 (discovery). The operational/diagnostic split is why both exist.
- `quanto-schedule-workflow` — pins the standing schedule in Step 4.
- `quanto-deliver-results` — wires delivery in Step 5.
- The day-to-day workflows (`quanto-flag-triage`, `quanto-client-briefing`, `quanto-month-end-close`, …) — what the project runs once it's set up.
