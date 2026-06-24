---
name: quanto-document-lookup
description: Find and read anything in the client's knowledge base — receipts, statements, invoices, contracts, firm SOPs, and Karbon notes. Trigger phrases — "find the receipt for [X]", "what document supports [Y]", "look up the statement for [Z]", "where's the bill from [vendor]", "what do we know about [client]".
---

# Document Lookup

Follow the rules in `quanto-client-context` first.

A thin but high-value wrapper around Quanto's knowledge base. Users want to find something fast and read it; this skill keeps them from having to learn the underlying tool surface.

**The flow is always the same: search first, then drill in.**

1. **Search** by meaning with `quanto_knowledge_base_search`. One call covers everything ingested for the client — uploaded documents, Google Drive files, firm-wide SOPs, and Karbon notes/work items/profiles — across both client and firm scope. This is the front door for essentially every request, *including* "what do we know about this client" questions. Don't start by guessing file names.
2. **Drill in** using the metadata on each hit. Every result carries the `document_id` (and `chunk_index`) of the chunk that matched, so when the user wants more than the snippet you fetch the full document it came from with `quanto_document_get` / `quanto_firm_document_get` / `karbon_*_get`.

`quanto_document_query` is the *secondary* tool — for browsing by name/category or confirming what's ingested — not the place to start.

## Playbook

### Step 1 — Search the knowledge base

Turn the request into a natural-language `query` and call `quanto_knowledge_base_search`. Fold whatever the user gave you into the query text:

- **Vendor / counterparty** ("the Amazon receipt", "Verizon bill")
- **Date or period** ("November statement", "Q3 2024")
- **Amount** ("the $1,212 charge")
- **Document type** ("bank statement", "invoice", "W-9", "amortization schedule")
- **Topic / question** ("why did they switch banks", "what's their fiscal year end", "engagement status")

Scope defaults to the active client, and firm-wide SOPs are always included. Only widen to `scope: all_clients` when the user is explicitly asking across clients.

### Step 2 — Read the hits

Each result is the chunk that matched, with:

- **`content`** — the snippet itself. Often this already answers the question; lead with the best one or two.
- **`doc_type`** — `sop` (client document), `firm_sop` (firm-wide standard), or `karbon_*` (practice-management).
- **`source`** — `upload` or `google_drive`.
- **`document_id`** (sop / firm_sop) or **`external_id`** (karbon) — the handle for Step 3.
- **`chunk_index`** and **`score`** — where in the document the snippet came from, and how strong the match is.

Present the snippet(s) with the source document name. If the snippet fully answers the question, you're done — no need to fetch the whole file.

### Step 3 — Drill into the full document when needed

When the user wants more than the snippet (the full statement, every line item, surrounding context), fetch the document the chunk came from using the metadata from Step 2:

| Hit `doc_type` | Fetch full content with |
|---|---|
| `sop` | `quanto_document_get(document_id)` |
| `firm_sop` | `quanto_firm_document_get(document_id)` |
| `karbon_note` / `karbon_work_item` / `karbon_note_comment` / `karbon_client_profile` | the matching `karbon_*_get` with the payload `external_id` |

Pass `include_chunks` if you want the ordered chunks; `chunk_index` tells you which part the match came from. Then present:

1. **Filename + metadata** (date, type, source)
2. **One-line summary** (from Quanto's extraction)
3. **Key extracted fields** — vendor, total, line items, dates
4. **Relevant excerpt** — quote the section that answers the question, not the whole document (statements run pages)

Default to the relevant excerpt; return everything only if the user asks.

### Step 4 — Surface related transactions if useful

If the document is clearly tied to a known QBO transaction (vendor + amount + date all match), look it up via `qbo_bill_query` / `qbo_purchase_query` and surface the link. *"This receipt matches Bill #4421 from Power Co on 11/15 — already in the books."*

If it doesn't match anything, note that — it might mean the document was forwarded but the transaction hasn't been entered.

## Browsing by name, or when search comes up empty

`quanto_document_query` (client) and `quanto_firm_document_query` (firm) are for *enumerating*, not searching content — use them when the user names a specific file or wants a list ("show me all the bank statements", "what W-9s do we have"). They filter on `file_name`, `category`, `status`, `source`, and `has_text`.

If `quanto_knowledge_base_search` returns nothing useful:

1. Try a broader or differently-worded query — the document is often titled differently from how the user described it.
2. Browse with `quanto_document_query` (filter `has_text=true` to list only readable copies), and check firm scope with `quanto_firm_document_query`.
3. Only after those come up empty, tell the user it isn't ingested and point them at the original source.

A row with `status=uploading` / `processing` and null `md_text` is a failed or in-flight upload, **not** missing content — the readable copy (often a Google Drive ingest of the same file) is what search returns. Trust search over a stuck metadata row.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| 1 · Search the knowledge base by content (all sources, both scopes) | `quanto_knowledge_base_search` | quanto |
| 2 · Drill into a hit — full client document | `quanto_document_get` (by `document_id`) | quanto |
| 2 · Drill into a hit — full firm-wide document | `quanto_firm_document_get` (by `document_id`) | quanto |
| 2 · Drill into a hit — full Karbon item | `karbon_*_get` (by `external_id`) | karbon |
| Browse / list by name or category | `quanto_document_query`, `quanto_firm_document_query` | quanto |
| Browse Karbon directly | `karbon_client_profile_query`, `karbon_work_item_query`, `karbon_note_query`, `karbon_note_comment_query` | karbon |
| Match to a transaction | `qbo_bill_query`, `qbo_purchase_query` | qbo |

## Strictly read-only

This skill doesn't touch documents or create new ones. Document upload happens through the QuantoBooks web app and document-processing workflow.

## Tips

- Lead with search. "Find me X", "what does Y say", even "what do we know about this client" are all `quanto_knowledge_base_search` queries — don't guess file names first.
- Document text is OCR'd extraction. Numbers can be slightly off (e.g., $1,212.00 read as $1,212.OO). If an exact figure doesn't match, search the surrounding context instead.
- Bank statements are usually long. Quote the relevant section; don't dump pages.
- Receipts often carry a different vendor name than the QBO record ("AMZN MKTP" vs "Amazon"). Search by what's likely *in* the document.
- The same document can exist several times — a manual upload plus one or more Google Drive copies. Search returns the readable, ingested copy; a row stuck at `status=uploading` with null `md_text` is just a failed upload, not missing content.
