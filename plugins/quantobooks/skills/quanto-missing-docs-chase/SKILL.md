---
name: quanto-missing-docs-chase
description: Recurring documentation-completeness audit for the active QuantoBooks client — finds transactions lacking supporting docs (receipts, bills, statements) or adequate detail, cross-references the knowledge base, and drafts a client-ready request list ("please send X for the $Y charge on Z"). Read-only, no writes. Trigger phrases — "what docs are we missing", "chase the client for receipts", "open items list", "PBC list", "what backup do we still need", "missing receipts", "audit trail gaps".
---

# Missing-Docs Chase

Follow the rules in `quanto-client-context` first.

Every firm runs the same monthly drudgery: find the transactions with no receipt, no bill, or a memo too vague to support, and chase the client for the backup. This skill automates the *find-and-draft* half — it builds the **open-items / PBC ("provided by client") request list** so the user just reviews and sends. It is **strictly read-only** — it never edits a transaction or fabricates the missing support; it identifies the gap and drafts the ask.

## Strictly read-only

No `_create` / `_update` / `_delete`. Finding a miscoded or unsupported transaction does not license fixing it here — name it, draft the request, and (if it needs a books change) hand off to `quanto-transaction-cleanup`.

## Playbook

### Step 1 — Confirm scope

After confirming the active client, establish:
- **Window** — default to the period being closed, or the last 30 days.
- **Materiality floor** — don't chase a $4 coffee; suggest a threshold (e.g. $75–$250 depending on client size) and confirm. Expense categories with audit/tax sensitivity (meals, travel, large equipment, contractor payments) may warrant a lower floor — note that.

### Step 2 — Pull the transactions in scope

Use `quanto_general_ledger_report` / `quanto_general_ledger_transaction_analysis` for the window to get the transaction population, plus `qbo_bill_query` / `qbo_purchase_query` for AP-side detail. Focus on outflows and journal entries where support is normally expected.

### Step 3 — Determine what's already supported

For each candidate transaction, check whether backup already exists before chasing it — nothing erodes trust like asking a client for a receipt they already sent. **Search first** with `quanto_knowledge_base_search` (it spans uploaded docs, Google Drive, Karbon, and Notion in one call), then confirm with `quanto_document_query`. Treat a transaction as a gap only when no matching document turns up. Remember a document that looks empty/stuck may still be ingested elsewhere — trust the search result.

### Step 4 — Classify the gaps

For each unsupported transaction, classify why it's on the list — the request reads better when it's specific:
- **No document at all** — needs a receipt/invoice/statement.
- **Has a doc but detail is thin** — vague memo, missing business purpose (esp. meals/travel), no payee.
- **Needs categorization context** — an ambiguous charge where the client needs to say what it was for, not just send paper.

### Step 5 — Fold in practice-management context (Karbon, if mapped)

If the client is mapped to Karbon, check `karbon_work_item_*` for an open "PBC" / document-request work item or prior requests, so you don't duplicate an ask already in flight. Context only — never a write. Skip silently if unmapped.

### Step 6 — Draft the request list

Produce a **client-ready** list, grouped so it's easy to action, each line specific enough that the client knows exactly what you mean:

```markdown
# [Client Name] — Open Items / Document Requests · [period]

Hi [client] — to finish your [period] books, we still need the following.
Where possible, just reply with the file or a one-line note.

## Receipts / invoices needed
- **$1,240 — 6/12 — "AMEX 4471"** — please send the receipt or invoice.
- **$3,500 — 6/03 — check to "J. Rivera"** — invoice + what it was for (contractor? reimbursement?).

## Need a bit more detail
- **$820 — 6/18 — "Travel"** — business purpose + who traveled, for the meals/travel substantiation.

## Quick categorization questions
- **$415 — 6/22 — "Apple"** — equipment or software? Affects how we book it.
```

Then give the **user** a short internal summary: count of items, total dollars unsupported, anything tax/audit-sensitive to prioritize.

### Step 7 — Hand off

Output the request list verbatim, ready to paste into an email or the client portal. There's no send tool here — the user reviews and sends. If any item is actually a *books* problem (clearly miscoded, not a missing doc), note it for `quanto-transaction-cleanup` rather than putting it on the client.

### Step 8 — Offer to loop it

The missing-docs chase recurs every close. After the first run, offer to schedule it via `quanto-schedule-workflow`, pinned to this client, review-only — it drafts the request list each period for the user to review and send. Offer once.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Transaction population | `quanto_general_ledger_report`, `quanto_general_ledger_transaction_analysis` | quanto |
| AP-side detail | `qbo_bill_query`, `qbo_purchase_query` | qbo |
| Find existing support | `quanto_knowledge_base_search` → `quanto_document_query` / `quanto_document_get` | quanto |
| Prior requests in flight | `karbon_work_item_query`, `karbon_work_item_get` | karbon |
| Make it recurring | hand off to `quanto-schedule-workflow` | — |

## Things to NEVER do

- Never write — no recategorizing, no attaching, no edits. Identify and draft only.
- Never ask the client for a document they already provided — search the knowledge base first.
- Never chase below the agreed materiality floor — a request list 80 items long gets ignored.
- Never fabricate a business purpose or guess what a charge was — that's the question you're *asking*, not answering.
- Never chase against the wrong client's books — confirm the active client first.

## Relationship to other skills

- `quanto-transaction-cleanup` fixes the books once the docs/answers come back; this skill gathers what's needed.
- `quanto-month-end-close` consumes a clean, fully-supported ledger — run this before close to clear the open items.
- `quanto-document-lookup` is the on-demand "find this one doc"; this is the systematic "what's missing across the period."
- `quanto-schedule-workflow` owns the recurrence.
