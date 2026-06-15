---
name: vendor-cleanup
description: Find and fix vendor-list problems for the active client — duplicates, missing TIN/W9, inconsistent naming, classification gaps. Trigger phrases — "clean up vendors", "vendor list audit", "find duplicate vendors", "vendor hygiene", "fix vendor names".
---

# Vendor Cleanup

Follow the rules in `quanto-client-context` first.

Messy vendor lists cause downstream pain: 1099 prep breaks, AP aging misreports, and spending analytics fragment. This skill runs the audit and fixes the issues that are safe to fix.

## Playbook

### Step 1 — Pull the vendor analysis

Call `quanto_vendor_report`. This gives you Quanto's already-analyzed view: flagged duplicates, missing-W9 vendors, naming inconsistencies, classification gaps.

If Quanto's analysis hasn't run on this client yet, fall back to `qbo_vendor_query` and `quanto_vendor_pattern_analysis` to derive what you can.

### Step 2 — Group issues by category

Walk the issues in this order — most-impactful first:

#### Duplicates

`quanto_vendor_pattern_analysis` flags likely duplicates by name similarity + payment-pattern overlap. For each duplicate cluster:

1. Show the cluster: 2–4 vendor records, their balance, transaction count, last activity date.
2. Propose a **survivor** (the one with most activity / cleanest name / valid TIN).
3. **Do NOT auto-merge.** QBO vendor merge happens in the UI. What you CAN do:
   - Update the survivor with any missing fields the duplicates had (email, address, TIN)
   - Move open AP balances by creating offsetting vendor credit / bill JEs (rare — confirm carefully)
   - Mark non-survivor vendors as inactive via `qbo_vendor_update` (`Active: false`)

For deactivation: explicit confirmation per vendor, never batch.

#### Missing TIN / W9

For 1099-eligible vendors (anyone paid > $600 in the tax year for services), QBO flags `Vendor1099 = true`. Cross-reference with vendors where `TaxIdentifier` is empty.

For each:
1. Show the vendor + YTD payment total
2. Note the gap: *"Acme Consulting — $4,200 YTD, no TIN on file"*
3. Suggest follow-up: ask the user to request a W9 (script it if helpful)
4. If the user provides the TIN, propose `qbo_vendor_update` with the new `TaxIdentifier` — confirm and write

#### Inconsistent naming

Quanto pattern analysis flags name variants. For each:
1. Show all variants + which one looks canonical (matches official business name, has the most history)
2. Propose updating non-canonical vendors to redirect users to the canonical one (rename to `<old name> [merged]` + deactivate)
3. Confirm per vendor

#### Classification gaps

Surface vendors missing:
- `Vendor1099` flag where the payment pattern suggests services
- Address (needed for 1099 mailing)
- Email (needed for AP automation)
- Default expense account (useful for QBO auto-categorization)

For each, propose the update; confirm; write.

### Step 3 — Vendor-by-vendor walk for high-volume vendors

For any vendor with >50 transactions YTD, do a quick sanity check via `quanto_vendor_pattern_analysis`:
- Are all transactions categorized consistently?
- Are there unusual amount spikes?
- Is the vendor's role clear (one expense category vs. scattered)?

Surface, don't fix automatically — most of these need recategorization via `transaction-cleanup`, not vendor-record changes.

### Step 4 — Wrap-up

End with:
- Vendors updated (count + breakdown)
- Vendors deactivated (count, listed)
- Open follow-ups (W9 requests, etc.)
- Duplicate clusters left for the user to merge in the QBO UI

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Vendor analysis | `quanto_vendor_report`, `quanto_vendor_pattern_analysis` | quanto |
| Vendor lookup | `qbo_vendor_query`, `qbo_vendor_get` | qbo |
| Vendor edit | `qbo_vendor_update` | qbo (write) |
| YTD payments | `qbo_report_vendor_expenses` | qbo |

## Things to NEVER do

- Never call `qbo_vendor_*_delete` — QBO doesn't really support it, and you'd corrupt history. Always deactivate (`Active: false`).
- Never merge vendors automatically. Surface the cluster, let the user merge in QBO UI.
- Never change a vendor's `DisplayName` silently — it cascades to every transaction view.
- Never update `TaxIdentifier` without explicit user provision of the value.
