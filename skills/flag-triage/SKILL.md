---
name: flag-triage
description: Walk through QuantoBooks action items (flags) for the active client one by one, propose a resolution for each (fix, snooze, or accept), and write back to QuickBooks after confirmation. The bread-and-butter daily skill. Trigger phrases — "what needs my attention", "go through the flags", "triage the action items", "fix the issues Quanto found".
---

# Flag Triage

Follow the rules in `quanto-client-context` first.

This is the highest-frequency QuantoBooks skill. A bookkeeper sits down, says "what's on the list today", and expects to walk out 20 minutes later with a clean checklist. Optimize for that loop.

## Playbook

### Step 1 — Pull the checklist

Call `quanto_action_checklist` for the active client.

Filter / sort:
- Default to **unresolved** items (drop anything already in `quanto_action_checklist_reviewed`).
- Drop anything in `quanto_flag_snoozes` (unless the snooze has expired — surface those at the bottom).
- Sort by `risk_level`: CRITICAL → HIGH → MEDIUM → LOW.
- Break ties by `period` (newest first), then by dollar impact.

If the checklist is empty, say so plainly and stop. Don't invent work.

### Step 2 — Present one at a time

For each item, show the user:
1. **Title** and **risk_level**
2. **Account / transaction reference** (link or ID)
3. **Reviewer note** from Quanto
4. **Suggested disposition** — your read of whether this is a fix, snooze, or accept candidate

Always present in batches of 1–3 items, not the whole list at once. The user is going to decide on each one; a wall of 40 flags is unreadable.

### Step 3 — Drill in when needed

Before proposing a fix, pull the underlying analysis row:

| Flag source | Drill-in tool |
|-------------|--------------|
| Chart of accounts | `quanto_chart_of_accounts_account_analysis` |
| Trial balance | `quanto_trial_balance_account_analysis` |
| Balance sheet | `quanto_balance_sheet_account_analysis` |
| P&L | `quanto_profit_and_loss_account_analysis` |
| General ledger | `quanto_general_ledger_transaction_analysis` |
| Vendor | `quanto_vendor_pattern_analysis` |

Filter by the specific `account_id` / `vendor_id` from the flag. This gives you the row-level detail Quanto's reviewer saw.

**Karbon context check (when the client is mapped).** Before proposing fix-vs-snooze-vs-accept on a flag that looks like a judgment call, do a quick `karbon_note_query` / `karbon_client_profile_query` for the client. Accountants often record the "why" in Karbon: *"owner reimburses personal fuel through the business — leave it"*, *"we reclass this to owner draws every quarter"*. A note like that can flip your suggested disposition from "fix" to "accept" or justify a snooze. Keep it lightweight — one lookup, and only when the flag's correct disposition is genuinely ambiguous. If the client isn't mapped or there's no relevant note, proceed on the books alone; never block triage waiting on Karbon.

### Step 4 — Propose a disposition

Three options. Show your proposed action; let the user pick.

**Fix.** Most common. Draft the QBO write:
- *Recategorization:* `qbo_purchase_update`, `qbo_bill_update`, etc. — change `AccountRef` to the right account.
- *Adjusting JE:* invoke `journal-entry-assist`.
- *Voiding / deleting a bad transaction:* `qbo_<entity>_delete`. **Extra confirmation required** (see foundation guard).
- *Vendor / customer fix:* `qbo_vendor_update`, `qbo_customer_update`.

Show the JSON payload. Get explicit approval. Call the tool. Confirm the write back.

**Snooze.** Use when the flag is valid but blocked or low-priority. Call `quanto_flag_snoozes` with:
- The flag identifier
- A snooze duration (default 30 days; ask if longer)
- A reason (required — Quanto's review team reads these)

**Accept.** Use when the flag was a false positive or the underlying state is correct as-is. Call `quanto_action_checklist_reviewed` with the user's note.

### Step 5 — Move on

After each disposition, immediately present the next 1–3 items. Don't ask "shall I continue" — the user already opted in by starting the triage. Stop only when:
- The user explicitly pauses ("hold on", "let me check")
- You hit a CRITICAL flag that needs a multi-step write (in which case finish that one cleanly before the next batch)
- The list is empty

### Step 6 — Wrap-up

When the queue is empty:
- Count: *"Disposed of 12 flags — 8 fixed, 3 snoozed, 1 accepted."*
- Surface anything you left for later: *"2 criticals deferred at your request: [...]"*
- Offer a one-line next-step: *"Want to run `month-end-close` now, or stop here?"*

## Things that should NEVER happen

- Disposing of a flag without user confirmation. Even an "accept" is a write to Quanto's review state.
- Batch-deleting transactions without itemizing each one.
- Calling `qbo_*_delete` when an update would do.
- Marking a critical flag as reviewed because "it looked fine" — only the user can make that call.
