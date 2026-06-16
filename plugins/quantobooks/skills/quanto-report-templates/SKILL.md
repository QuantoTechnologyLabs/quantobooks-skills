---
name: quanto-report-templates
description: Branded QuantoBooks HTML templates for displaying accounting reports as polished, on-brand dashboards. Use when a QuantoBooks workflow has pulled report data (management report, financial period analysis, AR aging, balance sheet review) and the user wants to SEE it — a visual summary, a client-ready dashboard, an HTML preview, or something to screenshot/export. Trigger phrases — "show me a dashboard", "make it visual", "client-ready report", "render this as HTML", "turn this into a one-pager".
---

# QuantoBooks Report Templates

Client context is established by the calling workflow — follow `quanto-client-context` for client confirmation and tool-tier rules; this skill only handles presentation.

This skill turns QuantoBooks report data into **branded HTML dashboards**. It's a presentation layer other skills reach for when the user wants to *look at* numbers rather than read them in prose. In Cowork the result renders as an inline HTML preview; in Claude Code you write the file and the user opens it.

## When to use it

Reach for a template when:
- A user finishing a workflow says "make that a dashboard / one-pager / something I can send the client."
- `quanto-management-report` has produced a monthly narrative and the user wants the visual version.
- `quanto-financial-period` / a close produced flags + scorecards worth showing at a glance.
- Any time the answer is "here are the numbers" and a chart/card layout communicates better than a table.

Don't force it — if the user just wants the figures inline, give them inline. Templates are opt-in.

## The templates

All live in `templates/` next to this file. Each is a single self-contained HTML file (inline CSS, no external dependencies, no network fetch) so it renders anywhere, including Cowork's preview and a saved `.html` file.

| Template | File | For |
|----------|------|-----|
| Management report | `templates/management-report.html` | Monthly client-facing summary: KPI cards, P&L summary, MoM/YoY deltas, talking points |
| Financial period dashboard | `templates/financial-period-dashboard.html` | Close / FPA snapshot: scorecard, flags grouped by risk level, period status |

(Add more over time — AR aging, balance-sheet roll-forward, vendor summary — following the same shape and theme.)

## How to render

1. **Pick the template** that matches the data you have.
2. **Read the template file** to see its placeholders. Placeholders are written as `{{UPPER_SNAKE}}` and there's a `<!-- SAMPLE DATA -->` comment block showing the expected shape and any repeatable rows.
3. **Fill it in** with the active client's real data (from the `quanto_*` tools the calling workflow already pulled — don't re-fetch if you have it). Replace every `{{PLACEHOLDER}}`. For repeatable sections (flag rows, line items), duplicate the marked row block once per item.
4. **Set the client name + period** in the header, and stamp "as of" with the period end, not today's date.
5. **Render:**
   - **Cowork:** write the filled HTML to the session outputs directory and present it as an HTML preview so it renders in-chat. Offer to save/export.
   - **Claude Code:** write the filled HTML to a file in the working directory (e.g. `./<client>-<period>-management-report.html`) and tell the user the path to open.
6. **Never invent numbers to fill a placeholder.** If you don't have a value, omit that card/row or label it "—", and say what's missing. A dashboard that looks authoritative but contains a guessed figure is worse than a table.

## Theme rules (keep it on-brand)

The templates already carry the QuantoBooks theme — **do not restyle them**:
- Primary blue `#2563eb`, ink `#111827`, muted `#6b7280`, hairlines `#e5e7eb`.
- Risk colors: CRITICAL `#dc2626`, HIGH `#ea580c`, MEDIUM `#d97706`, LOW `#16a34a` / neutral.
- System font stack, generous whitespace, a "QuantoBooks" wordmark top-left.
- Numbers right-aligned and tabular; deltas colored (green up / red down) with ▲ ▼.

If the user asks for their own firm's logo/colors instead, that's fine — swap the wordmark + `--brand` variable at the top of the file, but keep the layout.

## Honesty + scope

- These are **display only** — rendering a dashboard is never a substitute for the write-confirmation rules in the underlying workflow. Don't let "make it pretty" skip a JE confirmation.
- Read-only: this skill never calls a `qbo_*` write tool.
- The HTML is for the user to review/share. It is not filed or sent anywhere by this skill.
