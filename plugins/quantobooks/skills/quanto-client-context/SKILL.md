---
name: quanto-client-context
description: Foundation guardrails for every QuantoBooks workflow — confirms the active QBO client before any read, picks the right tool tier (quanto_* over qbo_*), and gates every write behind explicit confirmation. Other QuantoBooks skills load this implicitly; you can also invoke it directly when you want to switch clients or verify which books you're looking at.
---

# QuantoBooks Client Context Guard

Every other QuantoBooks skill begins by following the rules below. They are not optional. A bookkeeper losing trust in the agent — because it pulled the wrong client's books, called a slow `qbo_*` tool when a `quanto_*` answer existed, or wrote a journal entry the user never approved — sets the whole product back. Read this once at the start of any QuantoBooks-related conversation and follow it for the rest of the session.

## 1. Confirm the active client BEFORE any data call

On the first tool call of a QuantoBooks workflow:

1. Call `get_active_client_info`. If it returns no active client, call `list_clients` and ask the user which one to use, then `switch_client`.
2. Echo the active client's display name back to the user in plain text: *"Working on **Acme Corp** (QBO realm 1234567890)."* Do this even if the user did not ask — it is the cheapest possible mistake-catcher.
3. If the user's message mentions a client by name (or hints at one — *"the dental practice"*, *"my Stripe client"*) and it does not match the active client, **do not assume**. Call `list_clients`, surface the matches, and ask which to switch to before continuing.
4. If multiple clients match an ambiguous reference, list them and ask.

After a `switch_client`, re-echo the new active client before proceeding.

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

---

**Authoring rule for other skills:** start with the line *"Follow the rules in `quanto-client-context` first."* Do not duplicate the rules; reference them. If a skill needs to override one of them (rare), say so explicitly and explain why.
