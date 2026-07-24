---
name: quanto-client-context
description: Foundation guardrails for every QuantoBooks workflow — confirms the active QBO client before any read, picks the right tool tier (quanto_* over qbo_*), and gates every write behind explicit confirmation. Other QuantoBooks skills load this implicitly; you can also invoke it directly when you want to switch clients or verify which books you're looking at.
---

# QuantoBooks Client Context Guard

Every other QuantoBooks skill begins by following the rules below. They are not optional. A bookkeeper losing trust in the agent — because it pulled the wrong client's books, called a slow `qbo_*` tool when a `quanto_*` answer existed, or wrote a journal entry the user never approved — sets the whole product back. Read this once at the start of any QuantoBooks-related conversation and follow it for the rest of the session.

## 1. Confirm the active client BEFORE any data call

**The intended setup is one project per managed client** — a firm keeps a Cowork/Claude Code project per client and works that client's books inside it. Use that: the project you're in is a strong signal for *which* client, but never a silent substitute for confirming it.

**Pinned projects short-circuit this.** If `.claude/quanto-client.json` exists
in the project folder, this project is pinned to that client: `switch_client`
to it immediately, echo it, and proceed — the plugin's session-guard hooks
block data tools until you do, and block switching to any other client. If the
user asks for a *different* client while pinned, don't fight the guard: point
them to that client's own project, or walk them through repinning via
`quanto-project-pin`. In unpinned projects, resolve the client in this order:

1. **Did the user name a client?** If the message names one (or hints at one — *"the dental practice"*, *"my Stripe client"*), that wins. Call `list_clients`, find the match, `switch_client` if it isn't already active. If the hint is ambiguous or matches several, list the candidates and ask.
2. **No client named → infer from the project, then confirm.** Call `list_clients` and compare the **current project / workspace name** against the client names. If one client clearly matches the project name (exact or obvious — "Acme Corp" project ↔ "Acme Corp" client), propose it and switch: *"This looks like the **Acme Corp** project — working on Acme Corp's books. Say the word if that's wrong."* This is a confirm-and-proceed, not a silent assumption — you've told the user which books you're about to touch and given them a one-word veto.
3. **No clear project match → check the active client.** Call `get_active_client_info`. If there's an active client, echo it and proceed (the user can redirect). If there's no active client and the project name didn't resolve one, **ask explicitly** — list the clients and have the user pick. Never guess when there's no confident signal.
4. **Always echo.** Whatever path you took, state the active client in plain text before any data call: *"Working on **Acme Corp** (QBO realm 1234567890)."* It's the cheapest mistake-catcher there is.

Matching rules: an exact or near-exact project↔client name match is enough to propose-and-confirm. A weak/partial match (one shared word, a guess) is NOT — fall through to asking. When two clients could both match, always ask. The cost of touching the wrong client's books is far higher than one clarifying question.

After any `switch_client`, re-echo the new active client before proceeding.

Two server behaviors back this up (MCP server 0.2+): sessions for multi-client
firms start with **no active client** — data tools error until you
`switch_client` — and every tool response ends with an `[active_client: …]`
line. Read that line; if it ever names a client other than the one you intend,
stop and re-resolve before acting on the result.

## 2. Pick the right tool tier

For **reads**, always try `quanto_*` first. They are:
- Cached and analyzed (faster + cheaper than live QBO).
- Pre-flagged with risk levels (`LOW | MEDIUM | HIGH | CRITICAL`) and reviewer context that raw QBO data does not have.
- The same data your reviewers already work from in the QuantoBooks dashboard.

Fall back to `qbo_*` only when:
- The user needs **real-time** data (e.g., "what did we invoice today" — Quanto data may be hours stale).
- The entity or report has **no `quanto_*` equivalent** (e.g., `qbo_employee_*`, `qbo_transfer_*`, AR/AP aging detail reports).
- You need to **write** — every `_create`/`_update`/`_delete` is QBO-only.

When you fall back, say so out loud: *"Quanto doesn't have an aged-receivables view, so pulling this live from QBO."* The user should always know which surface answered.

**Searching the knowledge base: search first, then drill in.** To find anything in documents or notes — "what does our SOP say about X", "find the loan amortization schedule", "what did we note about this client" — **always start with `quanto_knowledge_base_search`**, not by guessing file names. One semantic call spans uploaded documents, Google Drive files, firm-wide SOPs, Karbon records, and Notion pages — including auto-detected meeting notes (`doc_type: notion_meeting_note`, the answer to "what did we discuss with this client") — across both client and firm scope, and returns the matching snippets. Each hit carries the `document_id` (and `chunk_index`) of the chunk that matched, so when the user wants the full document you drill in with `quanto_document_get` / `quanto_firm_document_get` / `karbon_*_get` / `notion_page_get`. The `quanto_document_query` / `quanto_firm_document_query` tools only match file names and metadata (never the contents) — they're for browsing, not finding. And if a document looks empty or stuck (status not `completed`, no extracted text), don't conclude the content is missing — search returns the readable copy that's been ingested from another source. (The `quanto-document-lookup` skill covers this in depth.)

## 3. Gate every write

A write is any `qbo_*_create`, `qbo_*_update`, `qbo_*_delete`, or `qbo_company_info_update`. Before calling any of them:

1. Show the user the exact payload you are about to send (the JSON body of the tool call, or a plain-English summary if the payload is long — but lean toward showing the JSON).
2. Wait for an explicit affirmative ("yes", "go ahead", "do it"). Do **not** treat the original instruction as standing approval.
3. For batch operations (e.g., updating 30 transactions), present a summary and a sample of 2–3 representative items, then ask for batch approval.
4. After the call, confirm what was written and the new `Id` / `SyncToken`.

If the server is in `READ_ONLY` mode the write tools will not be registered. If a user asks for a write that isn't available, say so plainly — don't substitute a read.

## 4. Surface flags as you go

When a `quanto_*` tool returns rows with `risk_level` of `HIGH` or `CRITICAL`, do not bury them. Lead the response with them. The user is paying for Quanto's review layer specifically to know what to look at first.

## 5. Karbon client context — check it when the client is mapped

Some firms run their client/workflow management in Karbon. When a client's books are connected to a Karbon record, Quanto ingests that practice-management context into the same knowledge base the review tools read from, exposed through a separate tool tier:

| Tool | What it returns |
|------|-----------------|
| `karbon_client_profile_query` / `_get` | The client's Karbon profile — entity type, fiscal year end, tax basis, line of business, registration numbers, and free-text notes on the client record. The richest single source of "who is this client". |
| `karbon_work_item_query` / `_get` | Engagement work items — what the firm is doing for this client (monthly close, year-end, etc.), with status, assignee, and due dates. |
| `karbon_note_query` / `_get` | Relationship notes accountants have written about the client. |
| `karbon_note_comment_query` / `_get` | Threaded discussion on those notes. |

How to use this tier:
- It is **context, never authority**. Karbon data informs your read of a situation; it never overrides what's in the books or licenses a write. There are no Karbon write tools.
- It is **optional and often sparse**. Not every client is mapped to Karbon, and a mapped client may have thin data (Notes in particular arrive over time, not all at once). Treat every `karbon_*` call as "check if there's useful context here" — if it returns nothing, move on silently. Never report missing context as an error, and never invent context that isn't there.
- `karbon_client_profile` and `karbon_work_item` are populated at connect time, so they're the reliable day-one sources. `karbon_note` / `karbon_note_comment` accumulate as the firm works in Karbon.
- Scope is the same active client as everything else — these tools only return data for the client whose `firm_clients` row is mapped to a Karbon record.

## 6. Stop and ask when uncertain

If the user's request would produce a destructive or irreversible action (deleting a transaction, voiding an invoice, changing the company tax setting), pause and confirm even if a literal reading of the instruction allows it. "Delete that bill" gets one extra confirmation step. Never delete more than one transaction in a single batch without itemizing them.

## 7. Close the loop — offer to schedule and to deliver

When a workflow produces a **deliverable the user would want to keep, repeat, or act on** — a report, a drafted list, a close summary — end the run by offering the two things that turn a one-off into an orchestrated routine:

1. **Schedule it** — *"want this every Monday before your call?"* → hand off to `quanto-schedule-workflow`.
2. **Deliver it** — *"where should this land — your Slack, a Notion page?"* → hand off to `quanto-deliver-results`.

A recurring run is only worth setting up if its result actually reaches the user, so these two belong together. Don't do this on trivial lookups (a single balance, one document fetch) — it's for real deliverables. Offer once per run; if a schedule or destination is already set, just confirm it rather than re-asking.

---

**Authoring rule for other skills:** start with the line *"Follow the rules in `quanto-client-context` first."* Do not duplicate the rules; reference them. If a skill needs to override one of them (rare), say so explicitly and explain why.
