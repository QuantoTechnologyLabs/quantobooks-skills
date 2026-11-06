---
name: quanto-month-end-close
description: Run a month-end close for the active QuantoBooks client. Pulls the financial period, walks the action checklist, runs balance sheet / P&L / trial balance review in order, and ends with a "ready to close?" summary. Trigger phrases the user is likely to say — "close November", "run month-end for [client]", "is [period] ready to close", "do the close".
---

# Month-End Close

Follow the rules in `quanto-client-context` first.

This skill orchestrates the full month-end close for one period. It is the highest-leverage workflow in QuantoBooks — most firms structure their month around it. Done well it replaces a 2–4 hour ritual; done poorly it loses the client's trust permanently. Bias toward thoroughness over speed.

## Inputs you need before starting

1. **Active client** — confirmed per the foundation guard.
2. **Period** — month + year. If the user did not specify, default to the **most recent closed month** (e.g., if today is 2026-06-02, default to May 2026). State your default and offer to switch.
3. **Accounting method** — Accrual unless the user says cash. Mention it in the summary.

## Playbook

### Step 1 — Period status

Call `quanto_financial_period` with the target period. This returns Quanto's Month-End Review row for the period: status, scorecard, open flags, last reviewer touch, and its `review_phase` — `unprepared` → `in_preparation` → `prepared` → `reviewed` ("Books closed").

- If the period is already closed in Quanto (`review_phase` is `reviewed`), ask the user whether they want to **re-review** or **close a different period**. Do not silently proceed.
- If the period has no Quanto row yet, say so — the data may be too fresh. Offer to pull live QBO reports as a fallback.

### Step 2 — Action checklist sweep

Call `quanto_action_checklist` filtered to the target period. Group items by `risk_level` and present them in this order:
1. `CRITICAL` (block the close — do not proceed past Step 4 until these are resolved or explicitly snoozed)
2. `HIGH`
3. `MEDIUM`
4. `LOW`

For each item show: title, account/transaction reference, the reviewer note. Ask the user how they want to handle the criticals before continuing. For each one, the user's options are:
- **Fix** — invoke the `quanto-flag-triage` skill on that item (it knows how to draft the fix, write it back and sign the lines off).
- **Snooze** — `quanto_flag_snooze` with the item's `action_checklist_id`, a `preset` (`this_month` unless the user says longer) and the user's `reason`.
- **Accept** — sign the item's lines off with `quanto_action_checklist_item_mark` (`prepared`, then `reviewed`), or, when the item doesn't apply, `quanto_action_checklist_item_status_update` with `status: "dismissed"` and the user's reason.

`quanto_action_checklist_reviewed` and `quanto_flag_snoozes` only read the marks and snoozes; they never write. Reviewed marks and snoozes need a firm admin or staff user.

### Step 3 — Balance sheet review

Call `quanto_balance_sheet_report` for the target period. For each account flagged `HIGH` or `CRITICAL`, drill in with `quanto_balance_sheet_account_analysis`. Present:
- Ending balance + prior-period comparison
- Movement summary
- Anomalies surfaced by Quanto

Ask the user whether each flagged account needs an adjusting JE. If yes, invoke `quanto-journal-entry-assist`.

### Step 4 — P&L review

Call `quanto_profit_and_loss_report`. Same treatment as the BS — drill into flagged accounts via `quanto_profit_and_loss_account_analysis`. Pay special attention to:
- Revenue accounts with missing items
- Expense accounts with single large transactions (often miscategorized)
- Accounts with zero activity that historically had movement

### Step 5 — Trial balance sanity check

Call `quanto_trial_balance_report`. Confirm:
- Debits = Credits (it always should — but flag immediately if not)
- No accounts with unusual signs (negative AR, positive AP balances, etc.)

### Step 5b — Engagement context (if the client is mapped to Karbon)

A clean trial balance isn't the whole picture if the firm's own engagement work for the period is unfinished. If the client is mapped to Karbon, call `karbon_work_item_query` and surface any open or due work items relevant to this close (e.g. a "November bookkeeping" work item still In Progress). This is context for the readiness call, not a blocker you resolve here — Karbon work items are managed in Karbon, not written from Quanto. Mention open items in the Step 6 summary so the user closes with eyes open. Skip silently if the client isn't mapped or nothing's open.

### Step 6 — Close readiness summary

Produce a written summary with:
- **Client + period + accounting method**
- **Open critical/high flags** (with counts)
- **Adjusting JEs drafted/posted this session** (list each)
- **Recommendation**: "ready to close" / "not ready, see [N] open criticals" / "ready with caveats"
- **Next step suggestion** for the user (e.g., "close the period in Quanto", "send to reviewer", "draft client report")

### Step 7 — Close the period (only on the user's explicit yes)

Closing is the user's decision. Never move the period unless they said to in this conversation; a scheduled run never closes. When they do, move it one phase at a time with `quanto_financial_period_phase_update` (`period` + the next `phase`): `in_preparation` once work has started, `prepared` when every line of every item is prepared, then `reviewed` to close the books. The tool applies the same rules as the web checklist, by the firm's review workflow settings — items dismissed (or completed, AR/AP aging aside) need no line sign-offs, snoozed lines and excluded flags don't count — and closing needs a firm admin or staff user. If it refuses, report what is still outstanding; never work around a refusal (no blanket dismissals to get past the gate). Reopening a closed period is the same tool, one phase back.

If the user wants a visual snapshot of the period — flags by risk, scorecard, status — invoke `quanto-report-templates` and fill the **financial period dashboard** template with the period data you already pulled. Renders inline in Cowork; a saved `.html` file in Claude Code.

A close runs every month-end. If this client closes on a predictable cadence (e.g. "run the close on the 3rd business day"), offer to schedule a recurring review-only run via `quanto-schedule-workflow` — it prepares the close and surfaces what needs the user's decision; it never marks the period closed or posts a JE unattended.

## Tool cheat sheet

| Step | Tool | Tier |
|------|------|------|
| Period status | `quanto_financial_period` | quanto |
| Action items | `quanto_action_checklist`, `quanto_flag_snoozes`, `quanto_action_checklist_reviewed` | quanto |
| Sign-offs | `quanto_action_checklist_item_mark` / `_unmark`, `quanto_action_checklist_item_status_update` | quanto (write) |
| Snoozes | `quanto_flag_snooze` / `quanto_flag_unsnooze` | quanto (write) |
| Close the period | `quanto_financial_period_phase_update` | quanto (write) |
| BS review | `quanto_balance_sheet_report`, `quanto_balance_sheet_account_analysis` | quanto |
| P&L review | `quanto_profit_and_loss_report`, `quanto_profit_and_loss_account_analysis` | quanto |
| TB check | `quanto_trial_balance_report`, `quanto_trial_balance_account_analysis` | quanto |
| Engagement context | `karbon_work_item_query` | karbon |
| Adjusting JEs | invoke `quanto-journal-entry-assist` skill | qbo (write) |
| Flag fixes | invoke `quanto-flag-triage` skill | qbo (write) |

You should rarely hit live QBO directly during a close — Quanto's data is exactly what was built for this. If you do (e.g., user asks "what was the largest expense"), prefer `quanto_general_ledger_transaction_analysis` over `qbo_report_general_ledger`.

## What "good" looks like

A close session ends with: the user knows every critical flag's disposition, every sign-off and snooze was one they approved, every adjusting JE that was written has a clear narration, the user has a one-paragraph summary they can paste into a client email, and they were never surprised by a write.
