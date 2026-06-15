---
name: journal-entry-assist
description: Conversational journal entry builder for the active QuantoBooks client. User describes the entry in plain English, skill validates accounts exist, drafts the JE in QBO format, and writes it after confirmation. Trigger phrases — "make a JE", "accrue [X]", "post a journal entry", "adjusting entry for [X]", "reclass [X] to [Y]".
---

# Journal Entry Assist

Follow the rules in `quanto-client-context` first.

JEs are the most error-prone write a bookkeeper makes. Wrong sign, wrong account, missed offsetting line — and the BS goes sideways. This skill exists to slow the process down enough to get it right, without slowing it so much that the user stops using it.

## Playbook

### Step 1 — Parse the user's intent

Common JE shapes the user might describe:
- **Accrual** — "accrue $5k of December rent" → debit Rent Expense, credit Accrued Liabilities
- **Reclass** — "move $1,200 from Office Supplies to Computer Equipment" → debit Computer Equipment, credit Office Supplies
- **Depreciation** — "post November depreciation: $2,400" → debit Depreciation Expense, credit Accumulated Depreciation
- **Prepaid amortization** — "amortize $500 of prepaid insurance for the month" → debit Insurance Expense, credit Prepaid Insurance
- **Owner contribution / distribution** — explicit equity movements
- **Reversing entry** — undo a prior period's accrual

Ask clarifying questions for anything genuinely ambiguous. Don't guess the offsetting account; ask.

### Step 2 — Validate accounts

For each account the JE will touch, call `quanto_chart_of_accounts_report` (or `qbo_account_query` if Quanto's analysis isn't current). Confirm:
- The account exists
- It's active
- It's the right type (debiting an Income account vs. Expense account has very different P&L effects)

If an account doesn't exist, ask the user whether to:
1. Use the closest match (show options)
2. Pause and create the account separately (don't create it inline)
3. Use a generic catch-all and let the user fix later

### Step 3 — Draft the JE

Build the QBO JournalEntry payload:

```json
{
  "txn_date": "2025-12-31",
  "doc_number": "ADJ-2025-12-001",
  "private_note": "Accrue December rent — landlord invoice not yet received",
  "line_items": [
    {
      "Amount": 5000.00,
      "DetailType": "JournalEntryLineDetail",
      "Description": "December rent accrual",
      "JournalEntryLineDetail": {
        "PostingType": "Debit",
        "AccountRef": { "value": "<rent_expense_id>", "name": "Rent Expense" }
      }
    },
    {
      "Amount": 5000.00,
      "DetailType": "JournalEntryLineDetail",
      "Description": "December rent accrual",
      "JournalEntryLineDetail": {
        "PostingType": "Credit",
        "AccountRef": { "value": "<accrued_liab_id>", "name": "Accrued Liabilities" }
      }
    }
  ]
}
```

Mandatory fields:
- **`txn_date`** — when the entry posts. For period-end accruals, use the last day of the period.
- **`doc_number`** — a memo number. Suggest `ADJ-YYYY-MM-NNN` pattern; ask for override.
- **`private_note`** — the *why*. Future-you (or the next reviewer) needs this. Push back if the user gives a thin one.
- **Each line's `Description`** — short purpose tag.

### Step 4 — Pre-flight checks

Before showing the JE for confirmation, verify:
- **Debits = Credits** — sum them. If not equal, do not present; fix or ask.
- **At least 2 lines** — a one-line JE is impossible.
- **No account used as both debit and credit on the same line** — usually a copy-paste mistake.
- **Sign + account type makes sense** — e.g., debiting Retained Earnings without an explanation should make you ask "is this really intentional?"

### Step 5 — Present + confirm

Show the user:
1. The plain-English summary: *"This will debit Rent Expense $5,000 and credit Accrued Liabilities $5,000, dated Dec 31, 2025."*
2. The full JSON payload
3. The expected P&L / BS effect: *"Increases December expenses by $5,000; increases accrued liabilities on the BS by $5,000."*

Wait for explicit approval. The phrase "looks right" is approval; "yes" is approval; "post it" is approval. "okay let me think" is NOT.

### Step 6 — Write

Call `qbo_journalentry_create` with the payload. Confirm the new entry's `Id` and `TxnDate` back to the user.

### Step 7 — If it's a reversing accrual, offer the reversal

For period-end accruals, ask: *"Want me to set up the reversing entry dated [first of next month]?"* If yes, build it now — same payload with sides flipped + appropriate doc number + note that points back.

## Things to NEVER do

- Never post a JE where debits ≠ credits. The tool may technically accept it; you should refuse.
- Never post a JE with no `private_note`. Even one sentence is fine; empty is not.
- Never create accounts inline as part of a JE. Pause, create separately, come back.
- Never post a JE to a closed period without explicit user override + a note explaining why.
- Never post identical-amount round-number JEs in bulk without checking — that's a classic "plug" pattern that hides real problems.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Account validation | `quanto_chart_of_accounts_report`, `qbo_account_query` | quanto / qbo |
| Look up similar JEs | `qbo_journalentry_query`, `quanto_general_ledger_transaction_analysis` | quanto preferred |
| Post the JE | `qbo_journalentry_create` | qbo (write) |
| Update a posted JE | `qbo_journalentry_update` | qbo (write) — extra confirmation |
