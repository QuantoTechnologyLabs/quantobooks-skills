---
name: quanto-year-end-1099-prep
description: Audit the active client's vendor list against the year's 1099-eligible payments — surfaces missing TINs, classification gaps, and payment totals so the firm can file 1099-NECs. Trigger phrases — "1099 prep", "vendor 1099 audit", "who needs a 1099", "year-end vendor cleanup", "ready for 1099s".
---

# Year-End 1099 Prep

Follow the rules in `quanto-client-context` first.

This skill runs once a year, in January, and is high-stakes — missed 1099s mean IRS penalties for the client. Bias toward completeness over speed. Surface everything that looks marginal; let the user decide.

## Playbook

### Step 1 — Confirm the tax year

Default to the most recent completed calendar year. Confirm with the user — sometimes firms run this for prior years too.

### Step 2 — Pull all vendor expenses for the year

Call `qbo_report_vendor_expenses` with `start_date: <year>-01-01`, `end_date: <year>-12-31`.

This gives you the master list — every vendor paid in the year, with totals.

### Step 3 — Filter to 1099 candidates

A vendor is a 1099-NEC candidate when:
1. **Paid ≥ $600 in the year** for non-employee compensation (services)
2. Paid by check, cash, or ACH (NOT credit card — credit card payments are reported by the card processor on 1099-K, not by the payer)
3. Not a corporation (unless legal services — those are always reportable)

Apply filters:
- Drop anyone under $600
- Drop credit-card-only payments (use `qbo_purchase_query` with `payment_type: CreditCard` to identify and exclude — leave only check/cash/ACH portion)
- Drop vendors marked as corporations (TIN starts with EIN pattern + entity type set; the firm may need to make the call here)

Output the surviving list with YTD totals.

### Step 4 — Cross-check each survivor's vendor record

For each remaining vendor, call `qbo_vendor_get`. Verify:
- `Vendor1099 = true` — if not, propose updating it (write)
- `TaxIdentifier` — present and well-formed (9 digits with or without dashes)
- `BillAddr` — present and complete (street, city, state, zip)
- Legal name vs. DBA — make sure the right one is in `CompanyName` for 1099 reporting

Group vendors into:
- ✅ **Ready** — all fields present, classification correct
- ⚠️ **Missing TIN** — need to request a W9
- ⚠️ **Missing address**
- ⚠️ **Classification mismatch** — `Vendor1099 = false` but pattern looks 1099-eligible
- ❓ **Marginal** — close to $600, or mixed CC/check, needs human judgment

### Step 5 — Fix what's safely fixable

For each "classification mismatch" with the user's approval, update `Vendor1099` via `qbo_vendor_update`. Show payload, confirm, write.

For "missing TIN" — draft a W9 request email per vendor that the user can send. Don't update `TaxIdentifier` until the user provides the value.

For "missing address" — if the user provides it, write. Otherwise note for follow-up.

### Step 6 — Special cases

Surface and ask, never auto-handle:
- **Attorneys / law firms** — always 1099-reportable regardless of corporation status. Confirm each.
- **Medical providers** — 1099-MISC, not NEC. Different form.
- **Rent payments to landlords** — 1099-MISC. Different form.
- **Partnerships** — always reportable.
- **Foreign vendors** — different form (1042-S), out of scope. Note and skip.

### Step 7 — Export the working file

Produce a structured output the user can hand off:

```
# [Client Name] — Tax Year [YYYY] 1099-NEC Prep

## Ready to file ([N] vendors)
| Vendor | TIN | Address | YTD Paid |
|--------|-----|---------|----------|
| ...    | ... | ...     | $...     |

## Action required ([N] vendors)
- Acme Consulting — missing TIN, $4,200 paid (W9 request drafted)
- ...

## Marginal — needs decision ([N] vendors)
- Stripe Inc — $580 paid (just under threshold)
- ...

## Special handling
- ABC Law Firm — attorney, always reportable: confirmed
- ...

## Excluded
- Credit-card-only vendors: [N]
- Corporations: [N]
- Under-threshold: [N]
```

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Vendor expense totals | `qbo_report_vendor_expenses` | qbo |
| Vendor records | `qbo_vendor_get`, `qbo_vendor_query` | qbo |
| Payment method audit | `qbo_purchase_query`, `qbo_billpayment_query` | qbo |
| Vendor updates | `qbo_vendor_update` | qbo (write) |

## Things to NEVER do

- Never call this "filed" — this skill prepares the data; actual e-filing happens elsewhere (Track1099, Yearli, IRS FIRE).
- Never auto-add a missing TIN. The vendor must provide it via W9.
- Never decide a vendor is a corporation without verifying — guessing wrong creates a missed 1099 penalty.
- Never include credit card payments in the reportable amount.
