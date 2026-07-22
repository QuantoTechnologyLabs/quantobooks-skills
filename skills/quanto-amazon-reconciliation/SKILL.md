---
name: quanto-amazon-reconciliation
description: Pull Amazon (Amazon Business or amazon.com) purchase transactions for a period via the user's live browser session, match them against the client's QuickBooks records, produce a reconciliation report, and — after explicit approval — post the missing transactions into QBO. Trigger phrases — "reconcile Amazon", "pull my Amazon transactions", "match Amazon orders to QuickBooks", "Amazon Business reconciliation", "book my Amazon purchases".
---

# Amazon → QuickBooks Reconciliation

Follow the rules in `quanto-client-context` first.

Many clients buy heavily on Amazon and the charges land in the books as a wall of near-identical card transactions — or don't land at all. This skill turns that into a deterministic loop: pull the Amazon side from the user's own logged-in session, pull the QBO side through the normal tool tiers, diff them, show the user exactly what's missing or wrong, and only then write.

**This skill has a hard human gate in the middle.** Steps 1–5 are read-only. Nothing is written to QuickBooks until the user has seen the reconciliation report and explicitly approved the postings in Step 6.

## Prerequisites

Two data sources must be reachable:

1. **QuickBooks** — the QuantoBooks MCP connection, with the correct active client confirmed per `quanto-client-context`.
2. **Amazon** — one of:
   - **Browser access** (preferred): Claude for Chrome or a Chrome sandbox/browser MCP (tools like `open_url`, `list_tabs`, `extract_text`, `click`, `screenshot`, `wait_for_selector`). The user must **already be signed in** to the Amazon account in that browser.
   - **CSV fallback**: no browser tools, or the user prefers not to share a session — ask them to export the order/transaction report themselves and share the file (see *CSV fallback* below). The rest of the skill is identical from Step 3 on.

**Credential rules — non-negotiable:**
- Never ask for, type, store, or transcribe the user's Amazon password, OTP, or 2FA codes. If the session is signed out, say so and ask the **user** to sign in themselves in that browser tab, then continue.
- Only read pages needed for the scoped period: order history, order details, invoices, returns/refunds. Do not browse account settings, payment-method pages, addresses, or anything outside the reconciliation.
- Treat everything pulled as client-confidential. Don't echo full card numbers (last-4 is fine — you need it for matching).

## Playbook

### Step 1 — Scope

Confirm with the user (or infer and echo):
- **Client** — per `quanto-client-context`. Echo the active client before anything else.
- **Period** — default: the last fully closed month.
- **Amazon account type** — Amazon Business (`business.amazon.com`) or personal `amazon.com`? Business accounts have far better reporting; ask which one the client actually purchases on.
- **Payment account in QBO** — which credit card or bank account do Amazon charges hit? (`qbo_account_query` for CreditCard/Bank accounts if the user is unsure.)
- **How Amazon purchases are booked** — as `Purchase` (expense/credit-card charge, the common case) or as `Bill` + `BillPayment`? Default to `Purchase` unless the books say otherwise.
- **Default expense account(s)** — check the vendor's history first (Step 3) before asking.

### Step 2 — Pull the Amazon side (browser)

Work in the user's existing session; announce what you're opening as you go.

**Amazon Business** (`business.amazon.com`):
1. Open **Orders** (or **Business Analytics → Reports → Orders** when available — it has the cleanest data and date-range filters). Set the date range to the scoped period.
2. Prefer a structured extraction per order. If Business Analytics offers a CSV download for the period, use it — downloaded CSV beats page-scraping for accuracy. Otherwise extract from the order list + order detail pages.
3. Also open **Returns & Refunds** (or the refunds view in Business Analytics) for the same period.

**Personal amazon.com**:
1. Open **Returns & Orders**, filter to the period's year, and page through orders — but **select by charge/ship date, not order date**: the reconciliation runs on when the card was charged, and Amazon charges at shipment. Include orders placed before the period whose shipments charged inside it, and exclude in-period orders whose charges landed after the period (note them as upcoming). Open order details wherever the list view doesn't show per-shipment charged totals.
2. Check the returns page for refunds in the period.

**What to capture per order** (one row per *charge*, not per order — Amazon charges per **shipment**, so one order can produce several card charges; the order detail / invoice page shows the per-shipment breakdown):
- Order ID, order date, charge/ship date
- Charged amount (incl. tax + shipping), and tax amount if shown
- Payment method (type + last-4)
- Item summary (first line item + "…and N more"), and PO number / order note if Business
- Refunds: order ID, refund date, refunded amount

Normalize into a single table (keep it as your working dataset and include it in the report later). Sum the total charged and total refunded for the period and **echo the totals to the user** before moving on — this is the control total the reconciliation must tie to.

**Pagination discipline**: keep going until the order dates pass out of the period. If the account has hundreds of orders in the period, tell the user the count and confirm before extracting every detail page — and prefer the CSV route in that case.

### CSV fallback (no browser)

Ask the user to export and share:
- **Amazon Business**: Business Analytics → Reports → Orders (choose the period, download CSV). The `Order Status`, `Payment Amount`/`Charged amount`, `Order ID`, and shipment columns map directly onto the table above.
- **Personal**: Account → **Request Order History Report** (if available in their region), or copy/paste the orders pages.

Parse into the same normalized table and continue.

### Step 3 — Pull the QBO side

Reads follow the normal tier rules (`quanto_*` first where an equivalent exists; this workflow is mostly live-QBO because it's transaction-level and current):

1. **Find the Amazon vendor(s)**: `qbo_vendor_query` for display names containing `Amazon`, `AMZN`, `Amazon.com`, `Amazon Business`, `AMZN Mktp`. There are often several near-duplicates — note them all (and mention `quanto-vendor-cleanup` at wrap-up if you find a mess, but don't detour into fixing it now).
2. **Pull candidate transactions for the period**:
   - `qbo_purchase_query` filtered to the period (Amazon vendors and/or the payment account from Step 1).
   - `qbo_bill_query` for the same vendors/period if the client books Amazon via bills.
   - `qbo_vendorcredit_query` and credit-type purchases for refunds.
   - `qbo_report_general_ledger` scoped to the payment account (the `account`/`source_account` filter) over the period — this catches Amazon charges that were booked **without** a vendor (a common reason naive vendor-only matching misses transactions). Don't use `qbo_report_transaction_list` for this: it has no per-account filter, so on a client with several cards it pulls other accounts' activity into the matching population.
3. **Check Quanto's flags**: `quanto_general_ledger_transaction_analysis` for the period — uncategorized or miscoded rows that look like Amazon (vendor/memo match) belong in this reconciliation rather than a separate cleanup pass.
4. Record which expense account(s) historical Amazon purchases post to — that history is your default categorization for new postings.

### Step 4 — Match

Match Amazon charges to QBO transactions with these rules, in order:

1. **Order ID in memo/`PrivateNote`/`DocNumber`** — exact order-ID match wins outright (this is also what makes re-runs idempotent; see Step 6).
2. **Exact amount + date within ±3 business days** of the charge date.
3. **Amount within a few cents + date window** — flag as a probable match with an amount mismatch, don't auto-accept.
4. **Shipment roll-ups**: if no charge-level match, try matching the **order total** against a single QBO transaction (some clients book one line per order), and conversely try matching a QBO amount against the **sum of same-day charges** for one order.

Refunds match against vendor credits, credit-type purchases, or negative/credit lines on the card account, same rules.

Every Amazon charge and every QBO Amazon-side transaction ends up in exactly one bucket:

| Bucket | Meaning |
|---|---|
| **Matched** | Amazon charge ↔ QBO transaction agree |
| **Missing in QBO** | Amazon charge with no QBO record → candidate to post in Step 6 |
| **In QBO only** | QBO Amazon transaction with no Amazon charge — possible duplicate, wrong-period booking, another Amazon account, or a personal purchase on the business card |
| **Amount mismatch** | Paired but amounts differ (partial shipment, tax difference, edited transaction) |
| **Unmatched refund** | Amazon refund with no QBO credit |

Never force a match. An honest "In QBO only" row is more useful than a wrong pairing.

### Step 5 — The reconciliation report

Present, in this order:

1. **Tie-out summary**: Amazon total charged − refunds for the period; QBO total recorded; matched total; and the difference **fully explained** by the exception buckets (missing + mismatch deltas + QBO-only). If the buckets don't explain the difference, say so — don't paper over it.
2. **Bucket tables** — Missing in QBO first (these drive Step 6), then mismatches, unmatched refunds, QBO-only. Each row: date, amount, order ID, item summary, payment last-4, and your proposed action + expense account.
3. **Matched table** — collapsed/abbreviated; it's the appendix, not the headline.

For a client-facing or keepable version, render it via `quanto-report-templates`; otherwise clean markdown in-chat is fine.

### Step 6 — Verify, then write

The write gate from `quanto-client-context` applies in full: exact payloads shown, explicit approval, no standing approval from the original request.

1. **Propose postings** for *Missing in QBO*, grouped for batch approval (same protocol as `quanto-transaction-cleanup`): show the group summary + 2–3 full sample payloads, then ask.
2. **Payload shape** (the default `Purchase` route, via `qbo_purchase_create`):
   - `payment_type`: `CreditCard` (or `Cash`/`Check` per the Step 1 account type)
   - `account_id`: the payment (card/bank) account
   - `vendor_id`: the Amazon vendor (the canonical one, if duplicates exist)
   - `txn_date`: the **charge date** (not order date)
   - `line_items`: expense `AccountRef` per the client's historical categorization; description = item summary
   - `private_note`: `Amazon order <ORDER-ID> charge <YYYY-MM-DD> $<amount> — posted by quanto-amazon-reconciliation` — **always include the order ID *and* the charge date + amount**. The order ID alone is not enough: a split order produces several legitimate charges under one ID, so the idempotency key is the *charge*, not the order.
3. **Bill-based clients** (Step 1 said `Bill` + `BillPayment`): post via `qbo_bill_create` — `vendor_id`, `txn_date` = charge date, same `line_items` and `private_note` convention. If the client pays Amazon bills from a bank account by check/ACH, offer `qbo_billpayment_create` to record the payment against the created bill. If Amazon bills are settled by **credit card**, the billpayment tool doesn't support card payments — create the bills, tell the user payment application is on them in QBO, and count only the bill side as posted. Never silently fall back to the `Purchase` route for a bill-based client; that changes their AP workflow.
4. **Refunds**: `qbo_purchase_create` with `credit: true` against the card account (or `qbo_vendorcredit_create` for bill-based clients), same note convention.
5. **Idempotency**: immediately before each create, re-query for an existing transaction whose note carries the same order ID **and** matches this charge's date + amount, or (absent a note) the same amount+date on the same account. Same order ID with a *different* charge date/amount is a sibling shipment, not a duplicate — post it. Exact key match → skip and say so; never post a duplicate.
6. **Mismatches**: propose a sparse `qbo_purchase_update` (Id, SyncToken, changed field only) *only* when the Amazon side is clearly authoritative (e.g., QBO amount excludes tax). Otherwise just report them.
7. **QBO-only rows**: report, don't touch. If one looks like a duplicate, surface it and let the user decide — deletion follows the destructive-action rule (itemized, one-by-one confirmation).
8. After each batch: confirm count, total dollars, and the new `Id`s.

### Step 7 — Wrap-up and close the loop

End with: transactions posted (count + dollars), mismatches found vs fixed, refunds handled, QBO-only items left for the user, and whether the period now ties out. Flag follow-ups you noticed (vendor duplicates → `quanto-vendor-cleanup`, uncategorized backlog → `quanto-transaction-cleanup`).

Per `quanto-client-context` §7, offer to schedule a recurring run via `quanto-schedule-workflow` — **review-only**: a scheduled run pulls, matches, and delivers the report (pair with `quanto-deliver-results`), but never posts unattended. Note the caveat honestly: an unattended run only works if the browser session (or a fresh CSV) is available to it; otherwise the scheduled run covers the QBO side and queues the Amazon pull for the next interactive session.

## What NOT to do

- **No writes before the report is reviewed.** The reconciliation report is the approval surface; postings come only after it.
- **Never handle Amazon credentials.** No typing passwords or OTPs, ever. Signed out → the user signs in.
- **Never post without the order ID + charge date + amount in `private_note`.** That charge-level key is what keeps every future run duplicate-safe without swallowing sibling shipments of the same order.
- **Don't delete or void anything as part of matching.** QBO-only and duplicate rows get surfaced, not silently removed.
- **Don't create new expense or GL accounts.** Use the client's existing COA; surface gaps instead.
- **Don't guess categorization for unfamiliar purchases.** No vendor history and no obvious account → put the row in front of the user.
- **Don't scrape beyond scope.** The period's orders, invoices, and refunds — nothing else in the Amazon account.
