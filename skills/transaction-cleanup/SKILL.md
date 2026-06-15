---
name: transaction-cleanup
description: Find uncategorized or miscategorized transactions in the active client's general ledger and recategorize them in batches. Trigger phrases — "fix uncategorized transactions", "clean up the GL", "recategorize [vendor/category]", "what's in Ask My Accountant", "catch-up coding".
---

# Transaction Cleanup

Follow the rules in `quanto-client-context` first.

This is the workhorse for catch-up bookkeeping and ongoing hygiene. A clean GL is the foundation everything else sits on; uncategorized transactions cascade into wrong P&Ls, wrong reports, and wrong client decisions.

## Playbook

### Step 1 — Scope the work

Ask the user (or infer):
- **Period** — single month, quarter, or YTD?
- **Filter** — uncategorized only, miscoded only, or both?
- **Account focus** — a specific account (e.g., "Ask My Accountant", "Uncategorized Expense") or all?

If unclear, default to: **all uncategorized transactions in the last fully closed period**.

### Step 2 — Pull candidates

Use `quanto_general_ledger_transaction_analysis` with filters:
- `transaction_date_start` / `transaction_date_end` — the scoped period
- `flags` — include `uncategorized`, `miscoded`, `ask_my_accountant` (whichever Quanto uses)
- `risk_level` — start with HIGH/CRITICAL

Quanto has already flagged these and often has a suggested account. Use that as your starting proposal — don't re-derive from scratch.

If Quanto returns nothing useful, fall back to `qbo_report_general_ledger` filtered to the suspect accounts, then `qbo_purchase_query` / `qbo_journalentry_query` for the underlying transactions.

### Step 3 — Group by likely category

Don't present transactions one at a time when there's clear repetition. Group by:
- **Vendor + amount pattern** (e.g., 6 transactions to "Slack" — all clearly Software & Subscriptions)
- **Memo keyword** (e.g., everything with "Uber" in the memo)
- **Account pattern Quanto detected**

For each group, propose a single recategorization to apply across all transactions in the group.

### Step 4 — Confirm and write

For each group:
1. Show the user the group: vendor, count, total dollars, and the proposed target account.
2. Show 2–3 representative transactions in full.
3. Ask for batch approval.
4. On approval, loop through each transaction and call the right update:
   - `qbo_purchase_update` — for expense transactions (cash purchases, debit card)
   - `qbo_bill_update` — for vendor bills
   - `qbo_journalentry_update` — for JEs (rare, usually adjusting)
   - `qbo_deposit_update` — for deposits posted to the wrong income account

Use the **sparse update** pattern: pass `Id`, `SyncToken`, and only the `AccountRef` on the affected line. Don't replay the whole record.

After each batch, confirm: *"Recategorized 6 Slack transactions to Software & Subscriptions ($487.32 total)."*

### Step 5 — One-offs

After the groups are done, walk through any remaining ungrouped transactions one at a time. Same protocol — propose, confirm, write.

### Step 6 — Wrap-up

End with:
- Total transactions touched
- Total dollars recategorized
- Accounts that changed (e.g., "Ask My Accountant down from $4,212.18 to $0.00")
- Anything you skipped and why

## Account-selection tips

When proposing a target account, prefer accounts that:
1. Already exist in the COA (`quanto_chart_of_accounts_report` for the list — don't create new accounts during cleanup unless the user asks).
2. Match the vendor's historical pattern (if Slack has been "Software & Subscriptions" for 11 months, the 12th one is too).
3. Match the firm's own COA conventions (check Quanto's chart of accounts flags for naming hints).

When in doubt, ask. Better to stop and clarify than to silently make 50 transactions wrong in a new way.

## What NOT to do

- Don't create new GL accounts during cleanup. Surface the gap, defer the creation.
- Don't change account types — only `AccountRef`.
- Don't touch the `Description` or `Memo` field on a transaction unless the user explicitly asks.
- Don't delete transactions to "recategorize" — always update.
