---
name: quanto-firm-digest
description: Cross-client morning triage for the whole firm — sweeps every QuantoBooks client and ranks where attention is needed today (new CRITICAL/HIGH flags, cash crunches, overdue AR, looming Karbon deadlines), so a firm_user opens one digest instead of checking each client by hand. Read-only, no writes. The one intentionally firm-scoped skill — it iterates across clients rather than pinning one. Trigger phrases — "what needs my attention today", "firm morning digest", "across all my clients", "which clients need me", "daily triage", "firm-wide rundown", "who's on fire".
---

# Firm Digest (cross-client triage)

Follow the rules in `quanto-client-context` first — **with one deliberate override, stated below.**

Every other QuantoBooks skill works one client in one project. This one is the exception: it answers *"across my whole book of business, where do I need to look today?"* It sweeps every client, pulls a few cheap signals from each, and ranks them so the firm_user starts the day with a prioritized list instead of opening twenty projects. It is **strictly read-only**.

## The one override: this skill is firm-scoped, not single-client

`quanto-client-context` rule #1 says confirm one active client before any data call. **This skill intentionally overrides that** — its entire job is to iterate across clients. It still honors everything else in the guard:

- It calls `list_clients`, then visits each client with `switch_client`, pulling **only read-only** signals.
- It **echoes which client each signal belongs to** — the digest is useless (and dangerous) if a flag is attributed to the wrong client, so every line names its client explicitly.
- It performs **no writes anywhere**, on any client — there is nothing in this skill but reads.
- Because it deliberately ranges across clients, it is best run **outside** a specific client project (a firm-level / "home" context), not inside one client's project where it would contradict the project-per-client model. If it's run inside a single client's project, say so and confirm the user really wants the firm-wide sweep, not just that client.

This override exists because a daily triage is genuinely firm-level work. It does not loosen the write rules — read-only is what makes ranging across clients safe.

## Strictly read-only

No `_create` / `_update` / `_delete`, on any client. The digest points the user *to* the client and skill that will do the work — it never does the work itself.

## Playbook

### Step 1 — Enumerate clients

Call `list_clients`. Confirm the scope with the user if the firm is large — *"You have 23 clients; sweep all of them, or a subset (e.g. just monthly-close clients)?"* Default to all. Note the count so the user knows the digest is complete.

### Step 2 — Sweep each client (cheap signals only)

For each client, `switch_client` and pull a **small, fixed set of fast read-only signals** — keep it light; this runs across the whole book:

- **Open issues** — `quanto_action_checklist`: count of unresolved CRITICAL / HIGH flags, and whether any are *new* since the last digest.
- **Cash health** — `quanto_balance_sheet_report` cash line (and `qbo_report_aged_receivables` only if a client looks tight): is cash low or falling hard?
- **AR pressure** — large newly-overdue receivables.
- **Deadlines** — if mapped to Karbon, `karbon_work_item_query` for work items due soon or overdue.
- **Recent meetings** — if the firm's Notion is connected, `notion_page_query` with `kind: "meeting_note"` and `modified_since` set to the last day or two: a fresh meeting note usually means fresh commitments, so surface it ("met with [client] yesterday — check the note for follow-ups"). Skip silently when the client has no Notion pages.

Keep per-client work minimal and uniform — this is triage, not a per-client review. If a client errors (not authenticated, no data), note it and move on; one bad client never aborts the sweep.

**One firm-level signal before (or after) the sweep:** `quanto_firm_document_query` with `source: "notion"`, `category: "notion_meeting_note"` — firm-wide meeting notes (internal all-hands, pipeline reviews) modified since the last digest. It needs no active client, so it's a single extra call, and anything client-specific said in a firm meeting belongs in that client's digest line.

### Step 3 — Score and rank

Assign each client a simple priority from its signals — anything with a new CRITICAL flag, a cash crunch, or an overdue deadline rises to the top; quiet clients sink. Don't over-engineer the score; the goal is a sensible ordering, not a model. Surface the **top items**, not all signals for all clients.

### Step 4 — Synthesize the digest

```markdown
# Firm Digest — [date] · swept N clients

## Needs you today
- **[Client A]** — new CRITICAL flag (negative AR balance) · cash down 22% this week → open in [client A]'s project, run quanto-flag-triage
- **[Client B]** — $48k receivable now 60 days overdue → quanto-ar-followup
- **[Client C]** — year-end work item due in 2 days (Karbon) → quanto-month-end-close

## Worth a look
- [Client D] — 2 HIGH flags, no change since yesterday
- [Client E] — cash trending down, not urgent yet

## Quiet
- 14 clients with nothing new. [Optionally list, or just the count.]

## Couldn't reach
- [Client F] — connector not authenticated for this sweep
```

Each line **names its client** and **points to the next action** (which project / which skill). Lead with what's genuinely urgent; don't let 14 quiet clients bury the one that's on fire.

### Step 5 — Hand off, don't act

The digest ends at "here's where to go." When the user picks a client to act on, that's a switch into that client's project and the relevant single-client skill (`quanto-flag-triage`, `quanto-ap-pay-run`, etc.). This skill never crosses from *triage* into *doing*.

### Step 6 — Offer to loop it

A morning digest is meant to run daily before the workday. After the first run, offer to schedule it via `quanto-schedule-workflow` — with one caveat specific to this skill: it pins a **firm-level run**, not a single `client_id`, so set it up in the firm/home context rather than a client project, and it stays review-only (it only ever reads). Offer once.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Enumerate clients | `list_clients` | — |
| Visit each client | `switch_client` | — |
| Open issues per client | `quanto_action_checklist` | quanto |
| Cash health | `quanto_balance_sheet_report` | quanto |
| AR pressure | `qbo_report_aged_receivables` | qbo |
| Deadlines (if mapped) | `karbon_work_item_query` | karbon |
| Fresh client meeting notes (if Notion connected) | `notion_page_query` (`kind: "meeting_note"`, `modified_since`) | notion |
| Fresh firm-wide meeting notes (no active client needed) | `quanto_firm_document_query` (`source: "notion"`, `category: "notion_meeting_note"`) | quanto |
| Make it recurring | hand off to `quanto-schedule-workflow` | — |

## Things to NEVER do

- Never write anything, on any client — this skill is pure read-only triage.
- Never attribute a signal to the wrong client — every line names its client; if you're unsure which client a number came from, drop it rather than guess.
- Never let one unreachable or erroring client abort the whole sweep — note it under "couldn't reach" and continue.
- Never turn the digest into per-client deep reviews — it's a light, uniform sweep; depth happens in the single-client skills it points to.
- Never run heavy per-client analysis tools across the whole book — keep the per-client signal set small and fast.

## Relationship to other skills

- This is the **only** firm-scoped skill; every other skill is single-client and project-pinned. It deliberately overrides `quanto-client-context` rule #1 (single active client) and nothing else.
- It is a **router**: it points at the single-client skills (`quanto-flag-triage`, `quanto-ar-followup`, `quanto-ap-pay-run`, `quanto-cash-flow-watch`, `quanto-month-end-close`) where the actual work happens.
- `quanto-client-briefing` is the per-client deep version of "what's going on" — the digest tells you *which* client to brief; the briefing tells you *everything* about that one.
- `quanto-schedule-workflow` owns the recurrence (pinned firm-level here, not to a `client_id`).
