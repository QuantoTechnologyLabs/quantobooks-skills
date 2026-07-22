---
name: quanto-schedule-workflow
description: Set up, change, or cancel a recurring run of a QuantoBooks workflow for a specific client — e.g. "run AR follow-up for Acme every Monday at 8am", "review Client B's books each Wednesday", "make Acme's close weekly instead of monthly", "move the pay-run reminder to Fridays", "stop scheduling the AR for Beta". Pins the client, schedules an unattended review-only run on the sandbox's self-rearming local cron at whatever cadence the user wants, and can edit or remove an existing one. Trigger phrases — "schedule this", "run this every [day]", "make it weekly/monthly", "change the cadence", "reschedule [workflow] for [client]", "pause/stop/cancel the [workflow] schedule", "automate the [AR/close/triage] for [client]".
---

# Schedule a QuantoBooks Workflow

Follow the rules in `quanto-client-context` first — a schedule is only as good as the client it's pinned to.

This skill turns a one-off workflow into a recurring routine for one client. It fits the project-per-client journey: a firm running Client A's AR every Monday before a Monday-afternoon meeting, and Client B's every Wednesday. Other QuantoBooks skills offer to invoke this at the end of a run ("want me to do this every week?").

## Where scheduling runs — local cron first

QuantoBooks is built to run in an **always-on cloud sandbox** (Docker + tmux) where the Claude session stays alive around the clock. In that environment, **prefer the local in-session scheduler (`CronCreate`) over a Claude-managed / cloud routine.** Local cron keeps the whole loop — fire → run → deliver → re-arm — inside the one place the QuantoBooks connector is already authenticated, with no dependency on an external routine runner, and it fires whenever the session is idle.

**One hard constraint shapes everything below:** `CronCreate` jobs **auto-expire 7 days after creation** — a recurring job fires once at the 7-day boundary and is then deleted. So a plain recurring local cron can't sustain a weekly cadence, and can't fire a monthly one at all (it dies before the first run). The fix, used by every schedule this skill creates: **a self-rearming chain of one-shot jobs.** Each fire re-arms the next one, and no single job is ever scheduled more than ~6 days out, so the chain never hits the 7-day death and runs indefinitely. Create jobs with `durable: true` so they survive a sandbox restart.

Managed / host routines (Cowork scheduled tasks, Claude Code `/schedule`) are the **fallback** — for ephemeral sessions, or when the user explicitly wants a cloud-managed routine. They have no 7-day cap, so a normal recurring schedule is fine there. Details in Step 4.

## The two things that make scheduling safe

Read these before creating anything. They are not optional.

### 1. A scheduled run is UNATTENDED → review-only

When the routine fires, **no human is in the chat to approve a write.** So a scheduled QuantoBooks run must never perform a `qbo_*_create` / `_update` / `_delete`, apply a payment, post a JE, or send anything **to the client**. It **prepares and summarizes** so the user has the work waiting for them when they sit down — it does not execute it. It *may* deliver its read-only summary to an **internal firm destination** (the firm's own Slack or Notion) — that's what makes a scheduled run worth setting up — by handing off to `quanto-deliver-results`, which holds the internal-vs-client-facing line.

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
3. **Cadence — the user's choice, always.** Ask for the interval, day(s), time, and timezone. The user can pick any cadence — weekly, every two weeks, monthly, twice a month, specific weekdays, "the 3rd business day," etc. (the self-rearming chain handles arbitrary cadences, including ones longer than the 7-day cron cap). Suggest a sensible default for the workflow (AR/pay-run/cleanup → weekly; close/BS/management report → monthly) but make clear it's just a starting point — *"Weekly on Mondays at 8am, or did you want a different day/frequency?"* Whatever they say wins. Don't hard-code the default; confirm the actual cadence back before creating.
4. **What 'done' looks like** — what the user wants waiting for them: a drafted AR follow-up list, a flagged-items summary, a close-readiness report.
5. **Delivery destination** — where the result lands when it fires (an internal Slack channel, a Notion page). A scheduled run no one sees is wasted, so capture this now and bake it in. Inherit the firm/client default from onboarding if one is set; hand the specifics to `quanto-deliver-results`.

### Step 2 — State the safety posture

Tell the user, in one line, what the scheduled run will and won't do: *"Every Monday 8am I'll pull Acme's overdue AR and draft the follow-ups for your review — I won't send anything or apply any payments unattended."* Get a yes.

### Step 3 — Compose the scheduled prompt

Build a self-contained instruction the run will execute. It must stand alone (the run has none of this conversation's context) **and re-arm its own successor** — that's what beats the 7-day cron cap:

```
# quanto-schedule: {{WORKFLOW}} · client {{CLIENT_ID}} · cadence {{CADENCE}}
You are an unattended, scheduled QuantoBooks run in an always-on sandbox. No human is watching.
The next real {{CADENCE}} run is due at {{NEXT_TARGET}} ({{TZ}}).

1. Run-or-hop: if the current time is at/after {{NEXT_TARGET}} (within ~1h), this is a REAL run — continue.
   If {{NEXT_TARGET}} is still in the future, this fire is only a keep-alive hop to beat CronCreate's
   7-day expiry — skip to step 5 and just re-arm; do NOT run the workflow.
2. switch_client to {{CLIENT_ID}} and confirm the active client is {{CLIENT_NAME}}. If it can't be
   activated or the QuantoBooks connector isn't authenticated, report that and skip to step 5 (still
   re-arm) — never run against the wrong books.
3. Run the QuantoBooks {{WORKFLOW}} workflow in REVIEW-ONLY mode: prepare, draft, summarize. Do NOT
   create/update/delete, apply payments, post JEs, or send anything to the client. End with a short
   summary I can act on: what you found, what you drafted, what needs my decision.
4. Deliver that summary to {{DESTINATION}} (internal firm destination only — never the client) per
   quanto-deliver-results. If unreachable, keep it in the run output and note it wasn't delivered.
5. RE-ARM THE NEXT RUN — do this on EVERY fire, whether it ran (step 3) or just hopped (step 1):
   - If step 3 ran, advance {{NEXT_TARGET}} to the next {{CADENCE}} occurrence; otherwise keep it.
   - FIRE_AT = min(updated {{NEXT_TARGET}}, now + 6 days)   ← never schedule past the 7-day cap.
   - CronCreate a ONE-SHOT (recurring:false, durable:true) at FIRE_AT carrying THIS WHOLE PROMPT with
     {{NEXT_TARGET}} updated. Arm exactly one successor; if CronList shows duplicates for this marker
     line, CronDelete the extras.
```

Fill `{{WORKFLOW}}`, `{{CLIENT_NAME}}`, `{{CLIENT_ID}}`, `{{CADENCE}}`, `{{NEXT_TARGET}}`, `{{TZ}}`, `{{DESTINATION}}`. The `# quanto-schedule:` marker line is how you find this job again in `CronList`. Keep it tight — but keep step 5 verbatim; the chain dies without it.

### Step 4 — Create the schedule (local cron, self-rearming)

**Default — local in-session cron (`CronCreate`).** Per "Where scheduling runs," this is the preferred path in the always-on sandbox. Create only the FIRST hop; the prompt re-arms the rest:
- Compute `NEXT_TARGET` (the first real run time, in the user's timezone) and `FIRE_AT = min(NEXT_TARGET, now + 6 days)`.
- `CronCreate({ cron: "<FIRE_AT as a 5-field cron>", recurring: false, durable: true, prompt: "<the Step-3 self-perpetuating prompt>" })`.
- `recurring: false` — it's a one-shot; the *chain*, not a standing job, is the recurrence. `durable: true` persists it to `.claude/scheduled_tasks.json` so it survives a sandbox restart.
- Do **not** create a recurring `CronCreate` for a weekly-or-longer cadence — it expires in 7 days (and never fires at all for monthly). The self-rearming chain is the only correct shape.

**Fallback — managed / host scheduler.** Only when there's no persistent local session (e.g. an ephemeral Cowork desktop) or the user explicitly asks for a cloud-managed routine: use the host's scheduler — a Cowork scheduled task, or a Claude Code `/schedule` routine. These have no 7-day cap, so a normal recurring schedule works; tell the user you used the managed scheduler rather than local cron. If neither a local session nor a host scheduler is available, don't fake it — offer to remind them (or have them re-run) at the chosen time, and don't claim a recurring job exists.

### Step 5 — Confirm + hand off

Report back:
- **What was created** — workflow, client, cadence, next run time (with timezone), and that it **re-arms itself each fire** (local cron) so it keeps running past the 7-day cron cap.
- **Where to manage it** — `CronList` shows the pending job (find it by the `# quanto-schedule: …` marker); `CronDelete <id>` cancels it. For the managed-scheduler fallback, point at the host's schedule/routine list instead.
- **The first-run caveat** — *"I'll know the scheduled run can reach Acme's books after the first fire; if it errors on auth, we'll need an API key on the connector."*

### Step 6 — Per-client, not global

One schedule pins one client. For a firm running several clients on different days, set up one routine per client — ideally each inside that client's project — so Client A's Monday routine and Client B's Wednesday routine stay independent. If the user lists several at once, create them one at a time, confirming the client each time.

## Changing, pausing, or cancelling an existing schedule

Cadence isn't locked in — a user who set up a monthly close can switch it to weekly, move the day/time, pause it, or remove it entirely. When they ask ("make Acme's AR weekly", "move the close to the 1st", "pause Beta's pay-run schedule", "stop scheduling X"):

1. **Find it.** Run `CronList` and identify the job by its `# quanto-schedule: {{WORKFLOW}} · client {{CLIENT_ID}}` marker (for the managed fallback, list the host's scheduled tasks/routines instead). If several could match, show them and ask which. If you can't find one, say so — don't create a new one unless the user wants that.
2. **Apply the change:**
   - **Change cadence / day / time** → `CronDelete` the current job and create a fresh first hop (Step 4) with the new `{{CADENCE}}` / `{{NEXT_TARGET}}` and the same pinned-client prompt. A local chain can't be edited in place — you replace it; tell the user that's what you did.
   - **Pause** → `CronDelete` the job and offer to recreate when they're ready (a one-shot chain has nothing to "disable" — removing the pending hop stops it).
   - **Cancel/stop** → `CronDelete` the job. Because the chain only persists by re-arming, deleting the pending hop ends it permanently.
3. **Don't touch the safety posture.** Editing cadence never changes review-only — the run stays prepare-and-summarize regardless of frequency.
4. **Confirm the new state** — *"Acme's AR follow-up now runs **weekly on Mondays 8am** instead of monthly; next run is [date]."* Or, for cancel — *"Removed Beta's pay-run schedule; nothing will run automatically now."*

One change at a time, per client. Don't bulk-reschedule multiple clients in one step without confirming each.

## Things to NEVER do

- Never schedule a workflow that writes/sends unattended. Review-only, always.
- Never use a plain **recurring** `CronCreate` for a weekly-or-longer cadence — it auto-expires after 7 days (and a monthly one never fires at all). Always use the self-rearming one-shot chain.
- Never let a scheduled run finish without re-arming the next hop — the chain dies the moment one fire skips step 5.
- Never pin a schedule by client *name* alone — always the `client_id`, or the run may hit the wrong books if names are similar or the default client changes.
- Never claim a recurring job was created if you couldn't create one (no local session and no host scheduler) — offer a reminder instead.
- Never promise the scheduled run will authenticate if you couldn't confirm the connector's headless auth — flag the first run as the test.
- Never bundle multiple clients into one schedule.

## Relationship to other skills

The cadence-appropriate workflows end by offering to schedule themselves — that hands off to this skill. Today those are `quanto-ar-followup`, `quanto-flag-triage`, `quanto-ap-pay-run`, `quanto-transaction-cleanup` (weekly/ongoing), and `quanto-month-end-close`, `quanto-balance-sheet-review`, `quanto-management-report`, `quanto-amazon-reconciliation` (monthly; its scheduled run is report-only and needs a reachable Amazon session or fresh CSV for the Amazon side — otherwise it covers the QBO side and queues the pull for the next interactive session). `quanto-client-briefing` (timed to a standing client call, whatever its cadence) leans on this skill the hardest — being strictly read-only, it re-offers the schedule on every manual run until one is pinned, since a pre-call brief is only useful if it reliably runs before the call. The read-only monitors — `quanto-cash-flow-watch` (weekly), `quanto-spend-watch` and `quanto-missing-docs-chase` (per close / weekly) — are built to be scheduled and offer it too. `quanto-firm-digest` is the one exception to per-client pinning: it schedules a **firm-level** run (across all clients), not a single `client_id`, set up in the firm/home context rather than a client project. The one-off skills (onboarding review, catch-up bookkeeping, JE assist, document lookup) don't — they're not recurring. This skill only sets up the recurrence; the actual work is whatever workflow it points at, running review-only. Where that run's output lands is owned by `quanto-deliver-results` — a schedule pins a destination, and the run hands off there to deliver its summary to the firm internally.
