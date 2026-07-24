---
name: quanto-client-briefing
description: Generate an internal pre-call briefing for the active QuantoBooks client — what's changed in their business since you last spoke, pulled across QBO financials, Quanto flags, Karbon work items / notes, and recent documents, distilled into talking points and open questions for the firm_user to walk into the meeting with. Read-only, no writes. The natural recurring workflow — after the first run it offers to loop ahead of every standing client call. Trigger phrases — "prep me for the call with [client]", "what's new with [client]", "client briefing", "pre-call brief", "catch me up on [client] before our meeting", "what should I raise with [client]", "what's changed since we last spoke".
---

# Client Briefing (pre-call discovery)

Follow the rules in `quanto-client-context` first — a briefing pinned to the wrong client is worse than no briefing.

This skill is the read-only mirror of `quanto-management-report`, but **internal-facing**. Management report is what the firm *sends the client*; this is what the firm_user *reads before talking to the client*. Its job is to fan across every integration Quanto can see — QBO movement, Quanto's review flags, Karbon practice-management context, Notion pages & meeting notes, and recent documents — and synthesize a single page: **what changed since the last conversation, what to raise, and what to ask.**

It fits the project-per-client setup directly: one client, one project, a standing call, and this skill run just before it. Because a recurring client call is the canonical looping workflow, this skill leans into the recurrence harder than any other — see Step 8.

## Strictly read-only

No `_create`, `_update`, or `_delete` calls in this skill, ever — not on QBO, not anywhere. A briefing observes; it never edits the books. If it surfaces something that needs fixing, name it as a talking point and point the user at `quanto-flag-triage`, `quanto-month-end-close`, or the relevant write skill. This read-only nature is also what makes it safe to schedule unattended (Step 8).

## Playbook

### Step 1 — Confirm scope

After confirming the active client (per `quanto-client-context`), establish the **window** — the single most important input, because a briefing is about *change*, not state:

- **"Since" anchor** — default to **since the last call**. If you don't know when that was, ask, or fall back to the last 30 days. If the user ran this skill before on a cadence, default to one interval back (a weekly loop briefs the last week).
- **Meeting context (optional)** — who's on the call and what it's for ("monthly check-in", "the client is worried about cash", "first call since year-end"). If the user offers it, let it steer emphasis. Don't interrogate — one line is plenty, and skip if they just want the standard brief.

State the window back before pulling anything: *"Briefing you on **Acme Corp** for your call — covering everything since your last check-in on May 28."*

### Step 2 — Financial movement (QBO / Quanto)

Pull what changed in the numbers over the window. Prefer `quanto_*` cached/analyzed reads; fall back to `qbo_*` for live or aging data (say so when you do).

- **P&L over the window vs the prior comparable window** — `quanto_profit_and_loss_report` (or `qbo_report_profit_and_loss`). Revenue, gross margin, net income, and any expense line that moved materially.
- **Cash trajectory** — the beat clients ask about most, so always include it. `quanto_balance_sheet_report` for cash position now vs window start, and `qbo_report_cash_flow` for *what moved it* — was the change operating, or a one-off like an asset purchase or tax payment? If there's a consistent burn, give a directional runway ("at ~$30k/mo net burn, ~5 months of cash"), stated as a rule of thumb, never a precise forecast. For a deeper weekly cash view, that's the `quanto-cash-flow-watch` skill — here, one honest cash-direction beat is enough.
- **AR / AP pressure** — `qbo_report_aged_receivables` and `qbo_report_aged_payables` (Quanto has no aging surface). New large overdue receivables or payables coming due are prime talking points, and they're also what's *behind* the cash trajectory above.

You are not writing a full management report here — extract only the **deltas and outliers a client would notice or ask about.** "Revenue up 18% on the new contract", "cash down $40k from the equipment purchase", "one customer now 60 days overdue at $22k." Skip anything flat.

### Step 3 — Open issues (Quanto flags)

Call `quanto_action_checklist` for the window. Surface **unresolved CRITICAL / HIGH flags** — these are the things the firm's own review layer thinks need attention, and the user should not be caught flat-footed on them in front of the client. Note anything new since the last briefing separately from long-standing items. Lead with these per the `quanto-client-context` flag rule.

### Step 4 — Practice-management context (Karbon, if mapped)

Karbon is where the *relationship and engagement* context lives — exactly what you want walking into a call. If the client is mapped (skip silently if not — many aren't, and notes arrive over time):

- **`karbon_work_item_query` / `_get`** — open and recently-changed engagement work items. What is the firm currently doing for this client, what's due, what's blocked? "Year-end work item due in 9 days" is a talking point.
- **`karbon_note_query` / `_get`** — recent relationship notes. Anything an accountant recorded about the client since the last call — a promised deliverable, a concern raised, a change in the client's business.
- **`karbon_note_comment_query` / `_get`** — threaded follow-up on those notes, where the live back-and-forth often is.
- **`karbon_client_profile_get`** — calibration only: entity type, fiscal year end, line of business, so you frame everything in the client's terms.

This tier is **context, never authority** (per `quanto-client-context`) — it colors the brief, it doesn't override the books, and there are no Karbon writes.

### Step 5 — What's new in the knowledge base

Run `quanto_knowledge_base_search` to catch anything that landed since the last call that the steps above wouldn't surface — a new statement, contract, or document the client sent, or a firm SOP that bears on this engagement. Search first (it spans uploaded docs, Google Drive, firm SOPs, Karbon, and Notion in one call), then drill into anything relevant with `quanto_document_get` / `quanto_firm_document_get` / `karbon_*_get` / `notion_page_get` using the `document_id` on each hit. Note genuinely new or changed items; don't re-list documents that were already there last time.

**Prior meeting notes are the single best "since we last spoke" source.** When the firm keeps meeting notes in Notion, pull the most recent ones for this client — `notion_page_query` with `kind: "meeting_note"` (or `quanto_knowledge_base_search` with `doc_types: ["notion_meeting_note"]` and a `dateFrom` filter) — and mine them for commitments made last time ("we said we'd fix X by Y"): those become the top of the *what to raise* list.

### Step 6 — Synthesize the briefing

This is the deliverable — a scannable one-pager the user reads in the two minutes before the call, **not** a data dump of everything you pulled. Structure:

```markdown
# [Client Name] — Pre-Call Briefing
*Covering [window start] → today · prepared for your [meeting context] call*

## Bottom line
[2–3 sentences. Is the business trending up / down / steady? What's the single
most important thing to know walking in?]

## What changed since last time
- [Financial movement that matters, in plain English with the number]
- [New or escalating issue]
- [Engagement / relationship development from Karbon]

## Raise on the call
- [Things YOU should bring up — a flag to explain, a cash trend to discuss,
  a deliverable the firm owes them]

## Be ready for (questions they might ask)
- [What the client is likely to ask given the numbers — "why is cash down",
  "did the new invoice go out" — with the answer ready]

## Open items / follow-ups
- [Outstanding work items, promised deliverables, anything left hanging from
  last time]
```

Rules for the synthesis:
- **Change over state.** If it didn't move, it doesn't belong here. The user already knows the steady-state; they need the delta.
- **Every claim traces to a number or a source you actually pulled.** Never invent a trend to fill a section. An empty section ("Nothing new in the knowledge base this period") is a perfectly good — and honest — answer.
- **Lead with what matters most**, not with whichever integration you queried first. A CRITICAL flag outranks a tidy P&L.
- **Plain English, concrete numbers.** "Cash down $41k from the truck purchase" beats "liquidity decreased."

### Step 7 — Hand off

Output the markdown verbatim, ready to read or paste. If the user wants something more polished to glance at on a phone before the call, you may offer the `quanto-report-templates` visual treatment — but the default deliverable is the markdown brief. Don't re-fetch data you already have.

### Step 8 — Offer to loop it (and keep offering until it's pinned)

**This is the step that matters most for this skill.** A pre-call briefing is the textbook recurring workflow — it's worthless the week you forget to run it, and it maps one-to-one onto a standing client meeting. So unlike the other skills, which offer scheduling once and move on, this skill **re-offers the loop every time it's run manually, until the user has actually scheduled it (or told you to stop asking).**

- **On the first run for a client:** end by offering to make it recurring via `quanto-schedule-workflow`, pinned to this client, timed to land just before the standing call — *"Want me to run this automatically every Monday at 7am so it's waiting for you before your 9am check-in? It'll stay review-only — it only ever reads and summarizes."* Suggest a cadence drawn from the meeting context if you have it.
- **On any later manual run, if no schedule exists yet:** ask again, briefly — *"Still running this by hand each week — want me to put it on a schedule so you don't have to remember?"* One line, not a nag, but always present.
- **Once a schedule exists:** stop offering. If the user changes their call cadence, hand off to `quanto-schedule-workflow` to adjust it.
- **If the user declines or says stop asking:** respect it for the rest of the session and don't re-prompt.

Because the run is strictly read-only, there is nothing unsafe to automate — the scheduled run just has the brief waiting when the user sits down. Honor the `quanto-schedule-workflow` safety posture regardless: scheduled runs are unattended and review-only, and the connector must be authenticated non-interactively for them to reach the books.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| P&L movement | `quanto_profit_and_loss_report` | quanto |
| Balance sheet / cash position | `quanto_balance_sheet_report` | quanto |
| Cash movement (what moved it) | `qbo_report_cash_flow` | qbo |
| Period rollup | `quanto_financial_period` | quanto |
| AR / AP pressure | `qbo_report_aged_receivables`, `qbo_report_aged_payables` | qbo |
| Open issues | `quanto_action_checklist` | quanto |
| Engagement / work items | `karbon_work_item_query`, `karbon_work_item_get` | karbon |
| Relationship notes | `karbon_note_query`, `karbon_note_get`, `karbon_note_comment_query` | karbon |
| Client profile (calibration) | `karbon_client_profile_get` | karbon |
| What's new in docs/notes | `quanto_knowledge_base_search` → `quanto_document_get` / `karbon_*_get` | quanto / karbon |
| Make it recurring | hand off to `quanto-schedule-workflow` | — |

## Things to NEVER do

- Never write anything — no `_create` / `_update` / `_delete`, on any surface. This skill only reads.
- Never present state as change — if a number didn't move over the window, it isn't a briefing item.
- Never invent a trend, a flag, or a Karbon note to fill a section. Missing context is reported as missing, not fabricated.
- Never let the schedule offer become a nag — once per run at most, and stop entirely once a schedule exists or the user declines.
- Never brief the wrong client — confirm the active client first, every time (per `quanto-client-context`).

## Relationship to other skills

- `quanto-management-report` is the **client-facing** counterpart — same financial backbone, but polished narrative *sent to* the client. If the user wants to send something rather than prep, hand off there.
- `quanto-flag-triage`, `quanto-month-end-close`, and the write skills are where issues this brief surfaces actually get *resolved* — this skill names them, it doesn't fix them.
- `quanto-schedule-workflow` owns the recurrence this skill pushes toward in Step 8.
