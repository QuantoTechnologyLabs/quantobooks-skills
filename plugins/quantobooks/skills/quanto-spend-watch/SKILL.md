---
name: quanto-spend-watch
description: Recurring spend and vendor-cost monitor for the active QuantoBooks client — surfaces new vendors, unusually large or duplicate payments, creeping recurring charges (subscriptions), and out-of-pattern spend between closes, before it becomes a month-end surprise. Read-only, no writes. Trigger phrases — "watch our spending", "any unusual expenses", "where's the money going", "spend check", "new vendors this month", "are we paying for duplicate subscriptions", "cost creep".
---

# Spend Watch

Follow the rules in `quanto-client-context` first.

`quanto-flag-triage` walks the issues Quanto's review layer has *already flagged*. This skill is the **proactive** counterpart — it watches raw spend between closes and surfaces what an owner would want to catch *early*: a vendor that appeared out of nowhere, a payment far larger than this vendor's norm, the same bill apparently paid twice, or a subscription that's quietly crept up. It is **strictly read-only** — it reports; it never recategorizes or pays anything.

## Strictly read-only

No `_create` / `_update` / `_delete`. If the watch finds a duplicate to void or a charge to recategorize, name it and hand off to `quanto-transaction-cleanup` or `quanto-flag-triage`. This skill is the smoke detector, not the fix.

## Playbook

### Step 1 — Confirm scope

After confirming the active client, establish:
- **Window** — default last 30 days (or one interval back if run on a cadence).
- **Materiality floor** — a dollar threshold below which spend isn't worth surfacing; suggest one scaled to the client (e.g. $250 for a small client, $2.5k for a larger one) and confirm.

### Step 2 — Top spend & vendor concentration

Pull `quanto_vendor_report` (or `qbo_report_vendor_expenses`) for the window. Rank vendors by spend. Show the top movers and note concentration — *"68% of spend went to 3 vendors."* This frames everything else.

### Step 3 — New and unusual vendors

- **New vendors** — vendors with their first activity inside the window (no prior history). A new vendor taking material spend is the #1 thing to surface.
- **Out-of-pattern spend** — use `quanto_vendor_pattern_analysis` to flag vendors whose window spend deviates sharply from their established pattern (a vendor that normally bills $500/mo suddenly at $9k).

### Step 4 — Duplicate and suspicious payments

Use `quanto_general_ledger_transaction_analysis` (and `qbo_bill_query` / `qbo_purchase_query` to confirm) to look for:
- **Likely duplicates** — same vendor, same/near amount, close dates.
- **Round-number anomalies** and payments materially above the vendor's norm.
- **Recurring-charge creep** — subscriptions/retainers whose amount has stepped up over recent periods.

Confirm before asserting — a "duplicate" is a *candidate* until the user looks; present it as "worth checking," not "you double-paid."

### Step 5 — Synthesize

```markdown
# [Client Name] — Spend Watch · [window]

## Spend snapshot
- Total spend: $X (vs prior window [+/-]Y%)
- Top vendors: [vendor $ / vendor $ / vendor $], concentration [note]

## New vendors this window
- [Vendor — $X — first activity. Worth confirming it's expected.]

## Out of pattern
- [Vendor normally ~$A, this window $B — [Nx] its norm]

## Worth checking
- [Possible duplicate: Vendor, $X, 6/11 and 6/13 — confirm not double-paid]
- [Subscription creep: SaaS vendor up from $X to $Y over 3 months]

## Nothing-to-see
- [If a section is clean, say so — an honest "no new vendors, no duplicates this window" is a useful result]
```

Lead with anything that smells like real money leaking (duplicate, runaway charge), not the routine top-vendor list.

### Step 6 — Offer to loop it

Cost control is an ongoing watch, not a one-off. After the first run, offer to schedule it via `quanto-schedule-workflow`, pinned to this client, review-only. Offer once.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Vendor spend ranking | `quanto_vendor_report`, `qbo_report_vendor_expenses` | quanto / qbo |
| Out-of-pattern detection | `quanto_vendor_pattern_analysis` | quanto |
| Transaction-level anomalies | `quanto_general_ledger_transaction_analysis` | quanto |
| Confirm a specific charge | `qbo_bill_query`, `qbo_purchase_query`, `qbo_billpayment_query` | qbo |
| Make it recurring | hand off to `quanto-schedule-workflow` | — |

## Things to NEVER do

- Never write — no recategorizing, no voiding, no payments. Surface and hand off.
- Never assert a duplicate or fraud as fact — present candidates as "worth checking," with the evidence.
- Never bury a material new vendor or a runaway charge under the routine top-vendor list.
- Never watch the wrong client's spend — confirm the active client first.

## Relationship to other skills

- `quanto-vendor-cleanup` fixes vendor-list *hygiene* (dupes, missing TINs, naming); this watches vendor *spend*.
- `quanto-transaction-cleanup` and `quanto-flag-triage` are where flagged items get resolved.
- `quanto-schedule-workflow` owns the recurrence.
