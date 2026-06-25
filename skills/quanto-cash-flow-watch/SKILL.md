---
name: quanto-cash-flow-watch
description: Weekly cash-position and runway watch for the active QuantoBooks client — current cash across accounts, net burn/build over the window, expected AR coming in vs AP going out, and a simple runway estimate. Read-only, no writes. The canonical "schedule it weekly" workflow. Trigger phrases — "how's cash looking", "cash flow check", "what's our runway", "cash position", "are we going to make payroll", "watch the cash for [client]", "weekly cash update".
---

# Cash Flow Watch

Follow the rules in `quanto-client-context` first — a cash number against the wrong client's books is dangerous, not just wrong.

Cash is the single number a small-business owner asks about most, and it moves every day. This skill produces a tight, **read-only** weekly cash picture: where cash stands now, which way it's moving, what's expected in and out over the near term, and roughly how long the runway is. It does **not** forecast with false precision — it's a directional watch the user (or a scheduled run) can glance at before a Monday call or a payables decision.

## Strictly read-only

No `_create` / `_update` / `_delete`, ever. This skill observes cash; it never moves it. If it surfaces a crunch, name it and point the user at `quanto-ap-pay-run` (to decide what to pay) or `quanto-ar-followup` (to pull cash in) — this skill doesn't act.

## Playbook

### Step 1 — Confirm scope

After confirming the active client, establish:
- **Window** — default to the last 7 days vs the prior 7 (a weekly watch). Monthly cadence works too; match it to how often this runs.
- **Forward horizon** — default 30 days for "what's coming due / expected in."
- **Accounts** — all bank + cash accounts by default. Ask only if the client has odd account structure (e.g. a restricted reserve they don't count).

State it: *"Cash watch for **Acme Corp** — position now, the last week's movement, and what's due in the next 30 days."*

### Step 2 — Current cash position

Pull cash on hand: `quanto_balance_sheet_report` (cash + bank lines), falling back to `qbo_report_balance_sheet` for live figures if the user needs today's number and Quanto's copy may be stale (say so). Sum all operating bank accounts; list each account's balance so the user sees concentration (e.g. most cash sitting in one account).

### Step 3 — Movement over the window

Use `qbo_report_cash_flow` over the window to characterize **net burn or build** — did cash go up or down, and driven by what (operating vs investing vs financing). Translate to plain English: *"Cash fell $38k this week — $22k of that was the equipment purchase, the rest is normal operating spend."* Distinguish a one-off (a tax payment, an asset buy) from a recurring trend, because the runway math depends on it.

### Step 4 — What's coming in and going out

The near-term forward picture:
- **Expected in** — `qbo_report_aged_receivables`: receivables likely to land inside the horizon (be conservative; flag any large overdue balance as *uncertain* rather than expected).
- **Going out** — `qbo_report_aged_payables`: bills due inside the horizon. Note any single large payable that dominates.
- Call out recurring obligations the reports won't time precisely (payroll, rent, loan payments) if you can see them in the data — but don't invent amounts you can't source.

### Step 5 — Runway estimate (directional, honest)

If the client has a consistent net burn, give a simple runway: current cash ÷ average weekly/monthly burn = weeks/months of runway. State the assumption out loud and keep it directional: *"At roughly $30k/month net burn, current cash covers ~5 months — before counting the $60k receivable that's 45 days out."* For a cash-positive client, say so plainly and skip the runway math. **Never present runway as a precise forecast** — it's a rule-of-thumb watch, and a confident-but-wrong runway number erodes trust fast.

### Step 6 — Synthesize

```markdown
# [Client Name] — Cash Watch · [window]

## Position
- Total cash: $X across N accounts (largest: [account] $Y)
- vs last week: [+/-]$Z

## What moved it
- [1–3 plain-English drivers, one-offs vs recurring separated]

## Next [horizon] days
- Expected in: ~$X (AR; [note any uncertain large balances])
- Going out: ~$Y (AP + known recurring)
- Net near-term: [+/-]$Z

## Runway
- [Directional runway, with the burn assumption stated — or "cash-positive, no runway concern"]

## Watch
- [Anything trending wrong: cash concentration, a big payable with no matching receivable, a dipping balance]
```

Lead with the bottom line. If cash is tight, that's the first sentence, not a buried bullet.

### Step 7 — Offer to loop it

A cash watch is the textbook weekly automation. After the first run, offer to schedule it via `quanto-schedule-workflow`, pinned to this client, timed before the user's weekly cash decision (often a Monday). It runs review-only by nature — it only reads and summarizes — so there's nothing unsafe to automate. Offer once; if they decline, drop it.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| Cash on hand | `quanto_balance_sheet_report` | quanto |
| Cash movement | `qbo_report_cash_flow` | qbo |
| Expected in | `qbo_report_aged_receivables` | qbo |
| Going out | `qbo_report_aged_payables` | qbo |
| Period rollup | `quanto_financial_period` | quanto |
| Live position fallback | `qbo_report_balance_sheet` | qbo |
| Make it recurring | hand off to `quanto-schedule-workflow` | — |

## Things to NEVER do

- Never write anything — no payments, no transfers, no journal entries. This skill only reads.
- Never present a runway estimate as a precise forecast — state the burn assumption and keep it directional.
- Never count a large overdue receivable as "expected in" without flagging the uncertainty.
- Never watch the wrong client's cash — confirm the active client first, every time.

## Relationship to other skills

- `quanto-ap-pay-run` and `quanto-ar-followup` are where you *act* on what the watch surfaces — slow the outflow or speed the inflow. This skill only observes.
- `quanto-management-report` includes a cash line but is monthly and client-facing; this is the frequent, internal, forward-looking watch.
- `quanto-schedule-workflow` owns the weekly recurrence.
