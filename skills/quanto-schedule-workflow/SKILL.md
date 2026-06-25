---
name: quanto-schedule-workflow
description: Set up, change, or cancel a recurring run of a QuantoBooks workflow for a specific client — e.g. "run AR follow-up for Acme every Monday at 8am", "review Client B's books each Wednesday", "make Acme's close weekly instead of monthly", "move the pay-run reminder to Fridays", "stop scheduling the AR for Beta". Pins the client, schedules an unattended review-only run via the host's scheduler at whatever cadence the user wants, and can edit or remove an existing one. Trigger phrases — "schedule this", "run this every [day]", "make it weekly/monthly", "change the cadence", "reschedule [workflow] for [client]", "pause/stop/cancel the [workflow] schedule", "automate the [AR/close/triage] for [client]".
---

# Schedule a QuantoBooks Workflow

Follow the rules in `quanto-client-context` first — a schedule is only as good as the client it's pinned to.

This skill turns a one-off workflow into a recurring routine for one client. It fits the project-per-client journey: a firm running Client A's AR every Monday before a Monday-afternoon meeting, and Client B's every Wednesday. Other QuantoBooks skills offer to invoke this at the end of a run ("want me to do this every week?").

## The two things that make scheduling safe

Read these before creating anything. They are not optional.

### 1. A scheduled run is UNATTENDED → review-only

When the routine fires, **no human is in the chat to approve a write.** So a scheduled QuantoBooks run must never perform a `qbo_*_create` / `_update` / `_delete`, apply a payment, post a JE, or send anything. It **prepares and summarizes** so the user has the work waiting for them when they sit down — it does not execute it.

Every schedule you create must bake this in: the scheduled prompt explicitly says *"review-only: do not perform any write operations; draft and summarize for my approval."* If the user asks for a schedule that auto-posts or auto-pays, decline and explain — that's a human-in-the-loop action by design (see `quanto-client-context`).

### 2. A scheduled run needs MCP auth that survives without you

The routine runs headless. It can only reach the QuantoBooks MCP if that connection is authenticated **non-interactively** — i.e. an API key configured in the client, not a one-time interactive sign-in. Before creating the schedule:
- Tell the user the routine needs the QuantoBooks connector authenticated in scheduled/background runs.
- If you can't verify that from the environment, say so plainly: *"The first run will confirm whether scheduled runs can reach your books — if it reports an auth error, your QuantoBooks connector needs an API key in its config rather than interactive sign-in."*
- Never promise it will work if you can't confirm the auth model. Set the schedule, but flag the first run as the real test.

## Playbook

### Step 1 — Confirm what to schedule

Collect, and read back before creating:
1. **Workflow** — which skill (e.g. `quanto-ar-followup`, `quanto-month-end-close`, `quanto-flag-triage`).
2. **Client** — the exact active client. You **must** capture its `client_id` (and realm), not just a display name — call `get_active_client_info` / `list_clients` to pin it. The scheduled run will `switch_client` to this id first.
3. **Cadence — the user's choice, always.** Ask for the interval, day(s), time, and timezone. The user can pick anything the host scheduler supports: weekly, every two weeks, monthly, twice a month, specific weekdays, "the 3rd business day," etc. Suggest a sensible default for the workflow (AR/pay-run/cleanup → weekly; close/BS/management report → monthly) but make clear it's just a starting point — *"Weekly on Mondays at 8am, or did you want a different day/frequency?"* Whatever they say wins. Don't hard-code the default; confirm the actual cadence back before creating.
4. **What 'done' looks like** — what the user wants waiting for them: a drafted AR follow-up list, a flagged-items summary, a close-readiness report.

### Step 2 — State the safety posture

Tell the user, in one line, what the scheduled run will and won't do: *"Every Monday 8am I'll pull Acme's overdue AR and draft the follow-ups for your review — I won't send anything or apply any payments unattended."* Get a yes.

### Step 3 — Compose the scheduled prompt

Build a self-contained instruction the routine will run. It must stand alone (the routine has none of this conversation's context):

```
Run the QuantoBooks {{WORKFLOW}} workflow for client {{CLIENT_NAME}} (client_id {{CLIENT_ID}}).
1. switch_client to {{CLIENT_ID}} and confirm the active client is {{CLIENT_NAME}} before anything else.
   If the client can't be activated or the QuantoBooks connector isn't authenticated, stop and report that — do not proceed against the wrong books.
2. Run the workflow in REVIEW-ONLY mode: prepare, draft, and summarize. Do NOT perform any
   create/update/delete, do not apply payments, do not send messages.
3. End with a short summary I can act on when I'm back: what you found, what you drafted, what needs my decision.
```

Fill `{{WORKFLOW}}`, `{{CLIENT_NAME}}`, `{{CLIENT_ID}}`. Keep it tight.

### Step 4 — Create the schedule

Use the **host's scheduling capability** — whatever the current client exposes:
- In **Cowork**, create a scheduled task with the prompt + cadence.
- In **Claude Code**, use the scheduling/routine mechanism (`/schedule`) to create a cron routine with the prompt.

If the host has **no** scheduler available, don't fake it — tell the user, and offer the fallback: you'll remind them (or they re-run it) at the chosen time. Don't claim a recurring job exists if you didn't create one.

### Step 5 — Confirm + hand off

Report back:
- **What was created** — workflow, client, cadence, next run time (with timezone).
- **Where to manage it** — how to edit or cancel (the host's schedule/routine list).
- **The first-run caveat** — *"I'll know the scheduled run can reach Acme's books after the first fire; if it errors on auth, we'll need an API key on the connector."*

### Step 6 — Per-client, not global

One schedule pins one client. For a firm running several clients on different days, set up one routine per client — ideally each inside that client's project — so Client A's Monday routine and Client B's Wednesday routine stay independent. If the user lists several at once, create them one at a time, confirming the client each time.

## Changing, pausing, or cancelling an existing schedule

Cadence isn't locked in — a user who set up a monthly close can switch it to weekly, move the day/time, pause it, or remove it entirely. When they ask ("make Acme's AR weekly", "move the close to the 1st", "pause Beta's pay-run schedule", "stop scheduling X"):

1. **Find it.** List the host's existing scheduled tasks/routines and identify the one for this workflow + client. If several could match, show them and ask which. If you can't find a matching schedule, say so — don't create a new one unless the user wants that.
2. **Apply the change** using the host's update capability:
   - **Change cadence / day / time** → update the existing routine's schedule (or, if the host can't edit in place, delete it and recreate with the same pinned-client prompt at the new cadence — tell the user that's what you did).
   - **Pause** → disable the routine if the host supports it; otherwise delete it and offer to recreate when they're ready.
   - **Cancel/stop** → delete the routine.
3. **Don't touch the safety posture.** Editing cadence never changes review-only — the run stays prepare-and-summarize regardless of frequency.
4. **Confirm the new state** — *"Acme's AR follow-up now runs **weekly on Mondays 8am** instead of monthly; next run is [date]."* Or, for cancel — *"Removed Beta's pay-run schedule; nothing will run automatically now."*

One change at a time, per client. Don't bulk-reschedule multiple clients in one step without confirming each.

## Things to NEVER do

- Never schedule a workflow that writes/sends unattended. Review-only, always.
- Never pin a schedule by client *name* alone — always the `client_id`, or the routine may hit the wrong books if names are similar or the default client changes.
- Never claim a recurring job was created if the host has no scheduler — offer a reminder instead.
- Never promise the scheduled run will authenticate if you couldn't confirm the connector's headless auth — flag the first run as the test.
- Never bundle multiple clients into one schedule.

## Relationship to other skills

The cadence-appropriate workflows end by offering to schedule themselves — that hands off to this skill. Today those are `quanto-ar-followup`, `quanto-flag-triage`, `quanto-ap-pay-run`, `quanto-transaction-cleanup` (weekly/ongoing), and `quanto-month-end-close`, `quanto-balance-sheet-review`, `quanto-management-report` (monthly). `quanto-client-briefing` (timed to a standing client call, whatever its cadence) leans on this skill the hardest — being strictly read-only, it re-offers the schedule on every manual run until one is pinned, since a pre-call brief is only useful if it reliably runs before the call. The read-only monitors — `quanto-cash-flow-watch` (weekly), `quanto-spend-watch` and `quanto-missing-docs-chase` (per close / weekly) — are built to be scheduled and offer it too. `quanto-firm-digest` is the one exception to per-client pinning: it schedules a **firm-level** run (across all clients), not a single `client_id`, set up in the firm/home context rather than a client project. The one-off skills (onboarding review, catch-up bookkeeping, JE assist, document lookup) don't — they're not recurring. This skill only sets up the recurrence; the actual work is whatever workflow it points at, running review-only.
