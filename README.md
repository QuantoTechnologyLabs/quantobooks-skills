# QuantoBooks Skills

Portable Claude skills that ship alongside the QuantoBooks MCP server. Each skill is a self-contained playbook that teaches an AI agent how to run a specific accounting workflow against the `qbo_*` and `quanto_*` MCP tools.

## Why skills (and not just tools)

The MCP server exposes ~150 granular tools. That's the right shape for capability — wrong shape for accountants. A staff bookkeeper asking "review the November close" does not want to choose between `quanto_balance_sheet_report` and `qbo_report_balance_sheet`; they want the right one called in the right order, with the right defaults, and a write-safety rail in front of every `_create`/`_update`/`_delete`.

Skills encode that. Each one:

1. Asserts the active client (so the agent never touches the wrong books).
2. Picks the right tool tier (`quanto_*` first for cached/analyzed reads; `qbo_*` for live data or writes).
3. Walks a deterministic playbook so two agents running the same skill against the same client produce the same result.
4. Requires explicit confirmation before any write, with the payload shown back to the user.

## Catalog

### Foundation
- **`quanto-client-context`** — the cross-cutting client-confirmation + tool-selection guard. Every other skill references it.

### Tier 1 — daily / monthly workhorses
- **`quanto-month-end-close`** — full close orchestration: financial period → action checklist → BS / P&L / TB review → unresolved-flags summary.
- **`quanto-flag-triage`** — walks the `quanto_action_checklist` in priority order, proposes resolutions, writes back with confirmation.
- **`quanto-balance-sheet-review`** — account-by-account roll-forward with adjusting-JE suggestions.
- **`quanto-transaction-cleanup`** — uncategorized / miscoded GL transactions; bulk recategorization with confirmation.
- **`quanto-client-onboarding-review`** — pre-engagement diagnostic for a new client: COA hygiene, opening balances, vendor list.

### Tier 2 — high-value, well-scoped
- **`quanto-ar-followup`** — aged receivables → follow-up notes → optional payment application.
- **`quanto-ap-pay-run`** — aged payables → proposed pay batch → bill payment creation.
- **`quanto-vendor-cleanup`** — duplicate vendors, missing TIN/W9, inconsistent naming.
- **`quanto-management-report`** — monthly client-facing narrative: P&L, BS, ratios, deltas, 3–5 talking points. No writes.

### Tier 3 — specialized
- **`quanto-year-end-1099-prep`** — vendor 1099 audit: payment totals, missing TINs, classification.
- **`quanto-catch-up-bookkeeping`** — multi-period close loop with cumulative "what's still broken" list.
- **`quanto-journal-entry-assist`** — conversational JE builder; validates accounts, drafts entry, writes with confirmation.
- **`quanto-document-lookup`** — thin wrapper around `quanto_document_query` / `quanto_document_get`.

### Intentionally not shipped (v1)
- **Bank reconciliation** — the MCP surface doesn't have a first-class bank-feed entity; the workflow would feel half-built.
- **Payroll** — no payroll MCP coverage.
- **Sales tax** — possible via `qbo_taxcode_*` but jurisdiction-specific; too narrow to package generically.

## Skill format

Each skill is a directory containing `SKILL.md` with YAML frontmatter:

```markdown
---
name: skill-name
description: One sentence that triggers the skill. Mention the user-facing intent ("review the month-end close", "fix uncategorized transactions").
---

# Body — the playbook the agent follows.
```

The `description` field is what Claude uses to decide whether to load the skill. Write it as the trigger sentence a user would say.

## Distribution (see `INSTALL.md`)

Four install paths:
1. **Shell one-liner** — `curl -fsSL https://get.quantobooks.com/skills | bash`. No Node required; macOS + Linux. Source: `install.sh` in this directory.
2. **Node CLI** — `npx @quantobooks/skills install`. Works anywhere with Node 18+; includes Windows.
3. **Web app "Install Skills" button** — generates the same files into a downloadable bundle for users who don't want to run a terminal command.
4. **Manual** — clone the public repo and symlink. For power users.

The source of truth lives here in the monorepo. CI mirrors `apps/mcp-server/skills/` (including `install.sh`) to the public `quantotechnologylabs/quantobooks-skills` repo on every push to `production`, and publishes the `@quantobooks/skills` npm package from the same source.
