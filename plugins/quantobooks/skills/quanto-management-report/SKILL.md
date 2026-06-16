---
name: quanto-management-report
description: Generate a monthly client-facing management report for the active QuantoBooks client — P&L, BS, key ratios, MoM/YoY deltas, and 3–5 plain-English talking points. Read-only, no writes. Trigger phrases — "monthly report", "management report for [period]", "client narrative", "draft the client summary", "MoM report".
---

# Management Report

Follow the rules in `quanto-client-context` first.

This skill produces the narrative the firm sends to the client at month-end. It is **strictly read-only** — no writes anywhere. The output is markdown the user can paste into their reporting tool, an email, or a PDF.

## Playbook

### Step 1 — Confirm scope

Ask (or default):
- **Report period** — default to the most recent closed month
- **Comparison periods** — default to: prior month + same month prior year
- **Accounting method** — Accrual unless the user says cash
- **Audience** — "executive" (short, high-level) vs "operational" (more detail). Default executive.

### Step 2 — Pull P&L for the three periods

Call `quanto_profit_and_loss_report` three times: target period, prior month, prior-year same month. Use the same accounting method across all three.

Extract for each:
- Revenue
- COGS
- Gross profit + gross margin %
- Total operating expenses
- Net income + net margin %

Compute deltas — MoM and YoY — for each line.

### Step 3 — Pull BS snapshot

Call `quanto_balance_sheet_report` for the period-end and prior period-end.

Extract:
- Total assets, total liabilities, total equity
- Cash position (sum of all bank accounts)
- AR balance
- AP balance
- Working capital (current assets − current liabilities)

### Step 4 — Compute the ratios that matter

Standard SMB KPIs:
- **Gross margin %** — gross profit / revenue
- **Net margin %** — net income / revenue
- **Operating expense ratio** — opex / revenue
- **Quick ratio** — (cash + AR) / current liabilities
- **DSO** — (AR / revenue) × days in period — *days sales outstanding*
- **DPO** — (AP / COGS) × days in period — *days payable outstanding*
- **Burn rate** (for any client with consistent monthly losses) — avg monthly cash decrease

Don't show all of these — show the 3–5 most relevant to this client's business model. If unsure, ask.

### Step 5 — Pull flag context

Call `quanto_action_checklist` for the period. Note any unresolved CRITICAL/HIGH flags. These should be acknowledged in the report (transparency > polish), even if briefly.

### Step 5b — Ground the narrative in client context (if mapped to Karbon)

A management report reads better when it speaks the client's language. If the client is mapped to Karbon, call `karbon_client_profile_get` (or `_query`) and use the profile to calibrate — line of business and entity type tell you which KPIs matter (a SaaS LLC and a construction partnership care about very different ratios) and let you frame drivers in industry terms rather than generic accounting ones. This is calibration only: it informs tone and KPI selection, never the numbers, which come exclusively from the financial reports above. Skip silently if the client isn't mapped.

### Step 6 — Draft the narrative

Produce a markdown report with this structure:

```markdown
# [Client Name] — [Month Year] Management Report

## Executive summary
[2–3 sentences. Was this a good / bad / neutral month? Why?]

## Headlines
- Revenue: $X ([+/-]Y% MoM, [+/-]Z% YoY)
- Net income: $X ([+/-]Y% MoM)
- Cash position: $X ([+/-]$Y vs prior month)
- [1–2 client-specific KPIs]

## What drove the numbers
[3–5 bullets. Plain English. "Revenue grew because X. Opex jumped because Y. Cash dipped because Z."]

## Balance sheet snapshot
[Brief — cash, AR, AP, key liabilities. Flag anything unusual.]

## What to watch next month
[2–3 forward-looking items. Anything that's trending wrong but isn't a problem yet.]

## Notes from your bookkeeping team
[Any unresolved flags worth surfacing, in client-friendly language.]
```

### Step 7 — Tone calibration

Match the firm's voice. Default rules:
- Plain English. Avoid accounting jargon when a normal word will do.
- Concrete numbers > vague trends. "Revenue down $4,212 from October" > "Revenue softened."
- Honest about losses. Glossing over a bad month damages trust faster than a bad month does.
- No advice unless the user asks for it. This is a report, not a consultation.

### Step 8 — Hand off

Output the markdown verbatim, ready to paste. Don't try to render it or "format" it further — let the user's downstream tool handle that.

### Step 9 — Offer the visual version (optional)

If the user wants something more polished to send the client — "make it a dashboard / one-pager / something I can screenshot" — invoke `quanto-report-templates` and fill the **management report** template with the figures you just computed. In Cowork it renders as an inline HTML preview; in Claude Code you write the `.html` file and give them the path. Don't re-fetch data you already have, and never fill a card with a number you didn't actually compute.

### Step 10 — Offer to make it recurring (optional)

A management report goes out every month. If the user produces this on a cadence for the client, offer to schedule a recurring run via `quanto-schedule-workflow` — it drafts the report for the user's review each period (read-only by nature, so there's nothing unsafe to automate here). One schedule per client.

## Tool cheat sheet

| Purpose | Tool | Tier |
|---------|------|------|
| P&L | `quanto_profit_and_loss_report` | quanto |
| BS | `quanto_balance_sheet_report` | quanto |
| Flags context | `quanto_action_checklist` | quanto |
| Period rollup | `quanto_financial_period` | quanto |
| Client profile (narrative calibration) | `karbon_client_profile_query`, `karbon_client_profile_get` | karbon |
| Live fallback | `qbo_report_profit_and_loss`, `qbo_report_balance_sheet` | qbo |

## Strictly read-only

No `_create`, `_update`, or `_delete` calls in this skill, ever. If the report surfaces something that needs fixing, recommend the user switch to `quanto-flag-triage` or `quanto-month-end-close` for that. The report itself is a snapshot of what's in the books, not a chance to edit them.
