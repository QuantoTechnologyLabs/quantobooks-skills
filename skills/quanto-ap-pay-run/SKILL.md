---
name: quanto-ap-pay-run
description: Build a proposed AP pay batch for the active client from aged payables, surface what's due this week, and create bill payments after confirmation. Trigger phrases — "pay run", "what bills are due", "AP pay batch", "schedule vendor payments", "what do we owe".
---

# AP Pay Run

Follow the rules in `quanto-client-context` first.

This skill is the AP side of a weekly money-out ritual: pull what's due, decide what to pay this run, and record the payments. It does NOT actually move money — QBO doesn't move money either; it records the transaction. The user runs the actual payment in their bank.

## Playbook

### Step 1 — Define the run window

Ask:
- **Pay-by date** — default to "next Friday" (or today + 7 days)
- **Available cash** — optional; if the user gives a budget, we'll prioritize within it
- **Vendor scope** — default to all; allow filtering

### Step 2 — Pull aged payables

Call `qbo_report_aged_payables_detail`. Group by vendor:
- Vendor name
- Total due
- Bills broken down by aging (current / 1-30 / 31-60 / 61-90 / 90+)
- Earliest due date in the queue

Also pull bills due within the pay-by window that aren't yet overdue — those should be in the same view. Use `qbo_bill_query` with `due_date_start` / `due_date_end` filters to top up.

### Step 3 — Prioritize

Default priority order:
1. **Already 30+ overdue** — pay first
2. **Due within the window**
3. **Critical-vendor bills** (utilities, rent, payroll-adjacent) — bump to the top if the user identifies any
4. **Discount-eligible bills** (e.g., 2/10 net 30) — bump if discount is still capturable

Show the proposed pay batch as a table:

```
Vendor         | Bill # | Amount  | Due    | Days late | Reason in batch
---------------|--------|---------|--------|-----------|----------------
Power Co       | 4421   | $312.40 | 11/15  | 18        | Overdue
Acme Supply    | INV-99 | $1,210  | 11/29  | 4         | Overdue
Office Lease   | DEC    | $4,500  | 12/01  | -         | Due this week
...
                         --------
                         $X total
```

### Step 4 — Trim to budget (if applicable)

If the user gave an available cash figure and the batch exceeds it, surface the gap and propose trimming — typically by dropping discount-not-yet-overdue items, then partial-paying the largest.

### Step 5 — Confirm payment method per vendor

Before writing, ask the user for the **paying bank account** (one for the whole batch is fine). Look up via `qbo_account_query` filtered to `account_type: Bank`. Default to whichever account the client has paid from historically.

### Step 6 — Write bill payments

For each approved row, call `qbo_billpayment_create`:

```json
{
  "vendor_id": "...",
  "pay_type": "Check",  // or "CreditCard"
  "bank_account_id": "...",
  "total_amount": 312.40,
  "line_items": [{ "Amount": 312.40, "LinkedTxn": [{ "TxnId": "<bill_id>", "TxnType": "Bill" }] }]
}
```

Write them **one at a time**, confirming each. This is a write-heavy operation; a typo here costs real money. Do not batch-create silently.

After each write, confirm the new payment's `Id` and the updated bill status.

### Step 7 — Reconcile + wrap-up

End with:
- Bills paid this run (count + total)
- Bills deferred (with reason)
- Vendors with no bills left in the queue
- Next pay-run recommendation date

### Step 8 — Offer to make it recurring (optional)

Pay runs are usually weekly. If the user runs this on a cadence for the client, offer to schedule a recurring run via `quanto-schedule-workflow`. **Be explicit that the scheduled run is review-only** — it builds the proposed pay batch and surfaces what's due so it's ready when the user sits down, but it never creates a bill payment unattended. Money out is always a human decision.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| AP aging | `qbo_report_aged_payables_detail`, `qbo_report_aged_payables` | qbo |
| Bills due | `qbo_bill_query` | qbo |
| Vendor info | `qbo_vendor_get` | qbo |
| Bank accounts | `qbo_account_query` | qbo |
| Record payment | `qbo_billpayment_create` | qbo (write) |

## Things to NEVER do

- Never batch-create payments silently. One at a time, with confirmation.
- Never pay a bill that's already been paid — always cross-check the bill's current balance before writing the payment.
- Never default the bank account silently. The user must approve which account is paying.
- Never auto-apply vendor credits without explicit user direction.
