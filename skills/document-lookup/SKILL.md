---
name: document-lookup
description: Find and read supporting documents (receipts, statements, invoices, contracts) attached to the active QuantoBooks client. Trigger phrases — "find the receipt for [X]", "what document supports [Y]", "look up the statement for [Z]", "where's the bill from [vendor]".
---

# Document Lookup

Follow the rules in `quanto-client-context` first.

A thin but high-value wrapper around Quanto's document tools. Users want to find a document fast and read its extracted contents; this skill keeps them from having to learn the underlying tool surface.

Uploaded documents (`quanto_document_*`) are the primary surface. But if the client is mapped to Karbon, the same knowledge base also holds Karbon practice-management context — the client profile, work items, and relationship notes — reachable through the `karbon_*_query` / `karbon_*_get` tools. When the user's question is less "find me this receipt" and more "what do we know about this client / what was discussed / what's the engagement status", those Karbon sources are where the answer lives (see Step 2b).

## Playbook

### Step 1 — Parse the search criteria

The user usually gives one or more of:
- **Vendor / counterparty name** ("the Amazon receipt", "Verizon bill")
- **Date or date range** ("November statement", "receipt from last Tuesday")
- **Amount** ("the $1,212 charge")
- **Document type** ("bank statement", "invoice", "W9")
- **Account** ("anything supporting the AWS line")

Combine into a filter set for `quanto_document_query`.

### Step 2 — Query

Call `quanto_document_query` with the assembled filters. If the query returns:

- **One match** — go to step 3.
- **2–5 matches** — list them with key metadata (filename, date, type, summary) and ask the user which to open.
- **6+ matches** — narrow further: ask for an additional criterion (date range, exact amount).
- **Zero matches** — broaden: drop the most-restrictive filter, retry. If still zero, say so and ask the user to check the original source.

### Step 2b — Karbon context (when the question isn't about an uploaded file)

If the user is asking about the client rather than a specific document — "what do we know about this client", "what's the status of their year-end", "did anyone note why they switched banks", "what's their fiscal year end" — `quanto_document_query` won't have it. Reach into the Karbon-sourced knowledge base instead:

| User is asking about… | Tool |
|---|---|
| Client background / entity type / fiscal year / line of business | `karbon_client_profile_query` → `karbon_client_profile_get` |
| Engagement status / what work is open or done | `karbon_work_item_query` → `karbon_work_item_get` |
| Notes the team wrote about the client | `karbon_note_query` → `karbon_note_get` |
| Discussion threads on those notes | `karbon_note_comment_query` → `karbon_note_comment_get` |

These work exactly like the document tools (`_query` for metadata + a key, `_get` for full markdown). Only the active client's mapped Karbon data is returned. If the client isn't mapped or the query is empty, say there's no Karbon context for that and fall back to what the documents/books show — don't treat empty as an error.

### Step 3 — Fetch + present

Call `quanto_document_get` with the chosen document ID. Pull both the summary and the extracted markdown.

Present:
1. **Filename + metadata** (date, type, source)
2. **One-line summary** (from Quanto's extraction)
3. **Key extracted fields** — vendor, total, line items, dates
4. **Relevant excerpt** — quote the section that answers the user's question (not the whole document; the whole document is often pages long)

If the user explicitly asks for the full content, return all of it. Default to relevant-only.

### Step 4 — Surface related transactions if useful

If the document is clearly tied to a known QBO transaction (vendor + amount + date all match), look it up via `qbo_bill_query` / `qbo_purchase_query` and surface the link. *"This receipt matches Bill #4421 from Power Co on 11/15 — already in the books."*

If it doesn't match anything, note that — it might mean the document was forwarded but the transaction hasn't been entered.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Find documents | `quanto_document_query` | quanto |
| Read one document | `quanto_document_get` | quanto |
| Find Karbon client context | `karbon_client_profile_query`, `karbon_work_item_query`, `karbon_note_query`, `karbon_note_comment_query` | karbon |
| Read one Karbon item | `karbon_client_profile_get`, `karbon_work_item_get`, `karbon_note_get`, `karbon_note_comment_get` | karbon |
| Match to a transaction | `qbo_bill_query`, `qbo_purchase_query` | qbo |

## Strictly read-only

This skill doesn't touch documents or create new ones. Document upload happens through the QuantoBooks web app and document-processing workflow.

## Tips

- Document text is OCR'd extraction. Numbers can be slightly off (e.g., $1,212.00 read as $1,212.OO). If a search by exact amount fails, try a range.
- Bank statements are usually long. Quote the relevant section; don't dump pages.
- Receipts often have a different vendor name on them than the QBO vendor record (e.g., "AMZN MKTP" on receipt vs "Amazon" in QBO). Search both ways if needed.
