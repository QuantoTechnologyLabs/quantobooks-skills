---
name: ar-followup
description: Walk through overdue accounts receivable for the active client, draft follow-up notes per invoice, and optionally apply received payments. Trigger phrases — "follow up on AR", "who owes us money", "overdue invoices", "AR collections", "send dunning notes".
---

# AR Follow-up

Follow the rules in `quanto-client-context` first.

This skill turns the aged-receivables report into an actionable collections session: who to email, what to say, and (optionally) recording any payments that come in during or after the session.

## Playbook

### Step 1 — Scope

Ask the user:
- **Aging threshold** — default to 30+ days overdue
- **Amount threshold** — default to $0 (everything), but for large clients suggest $250+ to focus
- **Customer scope** — all customers, or just one

### Step 2 — Pull aged receivables

Call `qbo_report_aged_receivables_detail` for the active client. (Quanto doesn't have an AR aging surface yet — note this to the user once if relevant.)

Group invoices by customer. For each customer, show:
- Customer name
- Total overdue
- Invoice count, broken down by aging bucket (1-30 / 31-60 / 61-90 / 90+)
- Oldest unpaid invoice's age in days

Sort by total overdue, descending.

### Step 3 — Pull customer context

Before drafting any note, for the top N customers (default 5), call:
- `qbo_customer_get` — pulls email, payment terms, last-contact notes
- `qbo_invoice_query` filtered to this customer's last 12 months — gives you their payment cadence

This tells you whether a customer is *chronically late* (different note) vs *uncharacteristically late* (different note again).

### Step 4 — Draft follow-up notes

For each customer, draft a follow-up email. Use these tiers:

- **1–30 days overdue, first follow-up** — friendly nudge. "Just wanted to check on Invoice #X — let us know if you need anything from our end."
- **31–60 days, chronically late** — firmer, with payment terms restated.
- **31–60 days, normally on time** — concerned check-in. "We usually hear back quicker, just want to make sure nothing's wrong."
- **61–90 days** — escalation note. Late fees if terms allow. Offer payment plan.
- **90+** — final notice / send-to-collections language. **Always confirm with the user before drafting these — the tone matters legally.**

Show each draft to the user. They edit / approve / skip. Do not actually send — there's no email tool here; the user copies into their email client.

### Step 5 — Apply payments (optional)

If during the session the user says "Acme sent in $5,000 yesterday", switch to payment-application mode:

1. Call `qbo_customer_get` to confirm the customer.
2. Call `qbo_invoice_query` filtered to that customer's unpaid invoices.
3. Propose how to apply the payment (default: oldest invoice first; ask if amount doesn't match cleanly).
4. Show the `qbo_payment_create` payload:
   ```json
   {
     "customer_id": "...",
     "total_amount": 5000.00,
     "line_items": [{ "Amount": 5000.00, "LinkedTxn": [{ "TxnId": "...", "TxnType": "Invoice" }] }]
   }
   ```
5. Get approval, write, confirm.

### Step 6 — Wrap-up

End with:
- Follow-up notes drafted (count + customer list)
- Payments applied (count + total)
- Customers flagged for escalation
- Suggested next session date

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Aging detail | `qbo_report_aged_receivables_detail` | qbo |
| Aging summary | `qbo_report_aged_receivables` | qbo |
| Customer info | `qbo_customer_get`, `qbo_customer_query` | qbo |
| Invoice history | `qbo_invoice_query` | qbo |
| Record payment | `qbo_payment_create` | qbo (write) |

## Things to NEVER do

- Never send the follow-up emails directly — there's no email integration in scope.
- Never apply a payment without showing the exact invoice it'll be linked to.
- Never assume payment amounts auto-apply cleanly. Overpayments, short-pays, and credits all need explicit handling.
