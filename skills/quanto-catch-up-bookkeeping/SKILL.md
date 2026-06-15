---
name: quanto-catch-up-bookkeeping
description: Multi-period close loop for clients whose books are months behind. Walks through each open period in order, runs an abbreviated close on each, and accumulates a cumulative "what's still broken" list. Trigger phrases — "catch up [client]'s books", "we're 6 months behind", "clean up [date range]", "back-bookkeeping for [client]".
---

# Catch-Up Bookkeeping

Follow the rules in `quanto-client-context` first.

This is the workflow for clients who haven't been touched in months. Resist the urge to fix everything in parallel — periods must close sequentially because each one's ending balance is the next one's opening balance. Get period N right before starting period N+1.

## Playbook

### Step 1 — Scope the catch-up

Ask:
- **Start period** — earliest month that needs work
- **End period** — usually "most recently completed month"
- **Known issues** — anything the user already knows is broken (e.g., "August had a major bank account change")

Confirm the scope with the user before starting — catch-up is a large block of work and they should know what they're committing to.

### Step 2 — Pull the period landscape

For each month in scope, call `quanto_financial_period`. Build a table:

```
Period   | Status      | Open flags | Last reviewed | Notes
---------|-------------|-----------|---------------|------
2025-06  | unreviewed  |  -        | -             | -
2025-07  | unreviewed  |  -        | -             | -
2025-08  | in-progress |  12       | 2025-09-15    | bank change
2025-09  | unreviewed  |  -        | -             | -
...
```

If Quanto has no period rows for the older months, that's normal — generate the picture from `quanto_general_ledger_report` filtered to each period.

### Step 3 — Define stopping conditions

Catch-up sessions are long. Set explicit checkpoints:
- After every period closed, surface progress + a "continue or pause" prompt
- After any CRITICAL flag that needs cross-period investigation, pause for the user
- After 3 consecutive periods with > 20 flags each, pause — there may be a systemic issue worth surfacing before continuing

### Step 4 — For each period, run the abbreviated close

In strict chronological order, for each period:

1. **Transaction cleanup** — invoke `quanto-transaction-cleanup` scoped to this period. Get uncategorized down to zero (or near it).
2. **Flag triage** — invoke `quanto-flag-triage` scoped to this period. Resolve CRITICAL/HIGH.
3. **Quick BS sanity** — `quanto_balance_sheet_report` for this period. Does it balance? Does the ending balance look plausible vs. last period?
4. **Period summary** — note count of transactions cleaned, flags resolved, JEs written.

Then **move to the next period**. Do not rebalance the whole BS until you reach the last period.

### Step 5 — Cumulative issue tracker

Maintain a running list of issues that span periods:
- An account that's been miscategorized for 8 months (one fix needs to propagate)
- A vendor that was a duplicate created mid-year
- A bank account that changed mid-year and needs careful opening-balance treatment

When you spot a multi-period issue, **don't fix in place**. Note it in the tracker and ask the user how to handle:
- Fix retroactively (re-open closed periods)
- Fix going forward (correct the most recent period and accept the historical noise)
- Adjusting JE in the most recent period that nets the historical effect

### Step 6 — Final period rollup

After the last in-scope period:
1. `quanto_balance_sheet_report` for the final period — does it balance?
2. `quanto_profit_and_loss_report` YTD — sanity check totals
3. `quanto_trial_balance_report` — final check

If anything doesn't reconcile, **stop and surface** — don't paper over it.

### Step 7 — Final summary

Produce:
- Periods closed (count + range)
- Transactions touched (cumulative count + dollar volume)
- JEs written (count, listed)
- Multi-period issues resolved
- Multi-period issues deferred (with reason)
- Recommended next-step (start regular monthly close, or there's more cleanup needed)

## When to escalate to the user

- **Bank balance doesn't tie to a statement** — surface and stop until the user confirms which side is right
- **Opening Balance Equity has any movement** — usually means a balance plug; needs human judgment
- **More than 50 flags in a single period** — there's probably a systemic issue the user should look at before automating fixes

## Tool cheat sheet

Use the same tools the per-period skills use. Catch-up is an orchestrator over `quanto-transaction-cleanup`, `quanto-flag-triage`, and `quanto-balance-sheet-review`. Don't re-implement their playbooks — invoke them.

## Things to NEVER do

- Never close periods out of order.
- Never apply a "fix" that requires modifying a closed period without explicit user approval — closed periods are signed off.
- Never bulk-resolve flags without per-period confirmation. The volume in catch-up makes this tempting; resist.
- Never claim "caught up" if BS doesn't balance or TB doesn't tie at the final period.
