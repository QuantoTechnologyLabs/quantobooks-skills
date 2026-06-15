---
name: client-onboarding-review
description: Pre-engagement diagnostic for a newly added QuantoBooks client — surfaces COA hygiene issues, opening balance sanity, vendor list quality, and produces a "what needs attention before we start" report. Trigger phrases — "review the new client", "onboarding review for [client]", "what's the state of [client]'s books", "is this client ready for us".
---

# Client Onboarding Review

Follow the rules in `quanto-client-context` first.

This skill runs when a firm takes on a new client and wants to know what they're walking into before quoting work. The output is read-only — no writes. The goal is a clear, prioritized "what needs to be cleaned up" list the firm can use to scope the engagement.

## Playbook

### Step 1 — Pull the onboarding rollup

Call `quanto_client_onboarding`. This returns Quanto's executive summary: client metadata, scorecard, suggested pricing tier, and the high-level findings from the initial review pass.

Lead the response with this summary — it's already structured for exactly this conversation.

### Step 2 — Chart of accounts hygiene

Call `quanto_chart_of_accounts_report`. Surface:
- **Total active accounts** (anything over ~150 is a yellow flag for SMB; over ~300 is concerning)
- **Duplicate-looking accounts** (e.g., "Office Supplies" and "Office Supplies Expense")
- **Inactive accounts with balances** (shouldn't exist)
- **Accounts with no activity in 12+ months** (cleanup candidates)
- **Missing standard accounts** (e.g., no Accumulated Depreciation, no Owner Distributions for a sole prop)

For HIGH/CRITICAL flagged accounts, drill in with `quanto_chart_of_accounts_account_analysis`.

### Step 3 — Opening balance sanity

Call `quanto_balance_sheet_report` for the most recent period. Cross-check:
- Does it balance?
- Are bank balances reasonable (not negative unless overdrawn)?
- Is AR / AP populated (or suspiciously zero)?
- Is there an Opening Balance Equity balance? **Anything non-zero here is a red flag** — it means the prior bookkeeper or migration left a plug.
- Does Retained Earnings make sense for the company's age?

### Step 4 — Vendor list quality

Call `quanto_vendor_report`. Look for:
- **Duplicates** (Quanto pattern analysis surfaces these)
- **Missing TINs / W9s** on 1099-eligible vendors
- **Inconsistent naming** ("Amazon" vs "AMAZON.COM" vs "Amazon Web Services")
- **One-time vendors** that should probably be merged into a generic "Misc"

Drill in via `quanto_vendor_pattern_analysis` on flagged rows.

### Step 5 — Recent transaction volume + categorization quality

Call `quanto_general_ledger_transaction_analysis` for the last 3 months. Report:
- Transactions per month (rough volume estimate for pricing)
- % uncategorized / Ask My Accountant
- Largest single transaction
- Most active expense accounts

### Step 6 — Period coverage

Call `quanto_financial_period` to see which periods Quanto has reviewed. Flag any:
- Gaps in coverage (months with no review)
- Open / partially-reviewed periods
- Periods marked closed but with unresolved flags

### Step 7 — Documents

Call `quanto_document_query` to see what supporting documents exist (receipts, statements, contracts). Note:
- Total document count
- Coverage gaps (e.g., bank statements only for 6 of 12 months)

### Step 8 — Karbon context (if the client is mapped)

If the firm runs this client in Karbon, the practice-management context is gold for an onboarding review — it tells you what the firm already knows about a client the books alone can't.

- Call `karbon_client_profile_get` (or `_query`) for the client. Surface the entity type, fiscal year end, tax basis / GST settings, line of business, and any free-text notes on the client record. A fiscal year end that doesn't match how the books are kept, or an entity type that contradicts the COA structure, is exactly the kind of thing to flag before quoting work.
- Call `karbon_work_item_query` to see engagement work the firm has logged for this client — prior or in-flight projects hint at scope and history.
- Call `karbon_note_query` for any relationship notes that flag known issues ("client always behind on receipts", "owner does their own payroll").

This step is **best-effort**: if the client isn't mapped to Karbon or the calls return nothing, skip it silently — don't present absence as a finding. Fold anything useful you do find into the report in Step 9.

### Step 9 — Synthesize

Produce a single structured report:

```
# [Client Name] Onboarding Review

**Quanto scorecard:** [overall score]
**Suggested pricing tier:** [from onboarding rollup]

## Critical issues (block engagement until addressed)
- ...

## High-priority cleanup (factor into scope)
- ...

## Medium-priority observations
- ...

## Strengths
- ...

## Recommended next steps
1. [most important]
2. ...
```

End with a one-paragraph plain-English summary the firm can paste into an internal Slack or proposal.

## No writes

This skill is **strictly read-only**. Surface issues; don't fix them. The firm hasn't signed an engagement yet — modifying the books before the contract is signed is a liability problem.

If the user wants to start cleanup, recommend they switch to `transaction-cleanup` or `flag-triage` once the engagement is signed.
