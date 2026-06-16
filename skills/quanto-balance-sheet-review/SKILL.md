---
name: quanto-balance-sheet-review
description: Account-by-account balance sheet roll-forward for the active QuantoBooks client. Pulls the period's BS, drills into each flagged account, and proposes adjusting journal entries when needed. Trigger phrases — "review the balance sheet", "BS review for [period]", "what's wrong with the balance sheet", "reconcile balance sheet accounts".
---

# Balance Sheet Review

Follow the rules in `quanto-client-context` first.

The balance sheet is where bookkeeping errors accumulate. A clean P&L with a sloppy BS is one of the most common things bookkeepers ship — and the most common reason clients lose trust later. This skill catches that.

## Playbook

### Step 1 — Pick the period

Default to the most recent closed month. Ask if the user wants a different period. Use the same period boundary across every step (don't compare November-ending against December-MTD).

### Step 2 — Pull the BS report

Call `quanto_balance_sheet_report` with the period. Show the user:
- High-level snapshot (Total Assets / Total Liabilities / Equity)
- Count of accounts flagged at each risk level
- Period-over-period delta on Total Assets

If the BS doesn't balance (Assets ≠ Liabilities + Equity) — that is an immediate CRITICAL. Stop and investigate before any account-level work. It almost always means an unbalanced JE was posted directly.

### Step 3 — Walk flagged accounts in priority order

Sort accounts by `risk_level` (CRITICAL → HIGH → MEDIUM), then by absolute balance. Walk them in batches of 3–5.

For each flagged account:

1. Call `quanto_balance_sheet_account_analysis` with the `account_id`. Surface:
   - **Ending balance** and **prior-period balance**
   - **Period activity** (net movement)
   - **Quanto's anomaly notes** — what did the reviewer flag

2. Categorize what you're seeing:
   - **Stale balance** — account hasn't moved in 6+ months but should have (e.g., prepaid that never amortized)
   - **Wrong sign** — AR negative, AP positive, accumulated depreciation positive, etc.
   - **Suspense balance** — clearing / undeposited funds that should be zero
   - **Missing accrual** — recurring expense not yet accrued
   - **Reclass needed** — balance posted to wrong account

3. Propose the fix. Most are adjusting JEs — invoke `quanto-journal-entry-assist`. For account-level changes (rename, archive), invoke `qbo_account_update` with confirmation.

### Step 4 — Cross-check categories

A few BS sections need extra scrutiny regardless of flags:

- **Bank accounts** — does the balance match the last reconciled statement? If not, surface — but note that bank reconciliation itself is out of scope for this skill (no MCP bank-feed tool).
- **AR** — pull `qbo_report_aged_receivables` and confirm the aging total matches the BS AR balance.
- **AP** — same with `qbo_report_aged_payables`.
- **Undeposited Funds** — should be near zero at month-end. Anything > $0 is a stuck deposit.
- **Owner equity / draws** — flag any unusual movements; these are often pre-tax red flags.

### Step 5 — Summary

End with:
- Adjusting JEs written this session (each one summarized)
- Open issues you couldn't resolve (and why)
- A one-line readiness statement: *"BS clean for close" / "BS has 2 open items: [...]"*

### Step 6 — Offer to make it recurring (optional)

The BS review is a monthly close ritual. If the user runs it on a cadence for the client, offer to schedule a recurring review-only run via `quanto-schedule-workflow` — it walks the flagged accounts and drafts adjusting JEs for the user's approval, but never posts a JE unattended.

## Tool cheat sheet

| Purpose | Tool |
|---------|------|
| BS snapshot | `quanto_balance_sheet_report` |
| Per-account drill-in | `quanto_balance_sheet_account_analysis` |
| AR aging cross-check | `qbo_report_aged_receivables` |
| AP aging cross-check | `qbo_report_aged_payables` |
| GL for unusual activity | `quanto_general_ledger_report`, `quanto_general_ledger_transaction_analysis` |
| Adjusting JE | invoke `quanto-journal-entry-assist` |

## What's out of scope

- **Bank reconciliation** — no MCP bank-feed surface. Note discrepancies, don't try to reconcile.
- **Fixed-asset depreciation schedules** — surface the depreciation account's behavior, but the schedule itself lives in client docs, not QBO.
