# Shipping plan — getting QuantoBooks skills to end users

This document covers how we get the skills in `apps/mcp-server/skills/` into the hands of accountants using Claude. It's the strategy doc behind `INSTALL.md`.

## The shape of the problem

End users:
- Are accountants and bookkeepers, **not engineers**. Many have never run an npm command.
- Use a mix of clients: **Claude Desktop** (most common), **Claude Code** (the technical ones), **Claude.ai web** (firms that don't want desktop installs), and **Cursor** (rare but growing).
- Don't want to think about "where do skills live". They want a button that says "install" and another that says "update".
- Distrust anything that touches their books without confirmation — and rightly so.

What we need:
1. A **single canonical source** so we're not maintaining four copies.
2. A **per-client install path** because the skills directory differs per client.
3. **Frictionless updates** — when we ship a new skill or fix one, users get it without manual work.
4. A **verifiable provenance chain** — users should be able to confirm the skills they installed came from us, not from a typosquat.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  apps/mcp-server/skills/   (monorepo, source of truth) │
└─────────────────────────────────────────────────────┘
                    │
                    │  CI on push to `production`
                    ▼
┌─────────────────────────────────────────────────────┐
│  github.com/quantotechnologylabs/quantobooks-skills │
│  (public read-only mirror)                          │
└─────────────────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   npm registry  Web app    git clone
   (@quantobooks /skills    (power users)
    /skills)    download
```

## The three install paths (recap)

### 1. `npx @quantobooks/skills install`

Primary path. Lowest friction for anyone with Node installed.

The CLI:
- Detects installed clients (`~/.claude`, `~/Library/Application Support/Claude/`, `~/.config/Claude/`)
- Copies skills into each detected location
- Prints what was installed and where
- Has `--upgrade`, `--dry-run`, `--target <client>`, `--skills <subset>`

A small package — under 100 lines of JS for the core logic. We control the npm package so users get our signed release, not a knockoff.

### 2. Web app one-click

For users who don't have Node (or won't run terminal commands). In the QuantoBooks dashboard:

- **"Copy install command"** button — for users who CAN run a terminal but don't want to figure out which one
- **"Download skill bundle"** button — generates a zip server-side with per-OS install instructions

Both paths produce identical results to the CLI. The web app shows a "skills last updated" date and a changelog so users can tell when there's something new.

### 3. Manual git clone

For power users, locked-down corporate environments, or anyone who wants to track changes. Documented in `INSTALL.md`.

## Update strategy

Skills evolve. We add new ones, fix bugs in existing ones, tune trigger descriptions. Users need a way to pull updates without re-discovering the install command.

Two approaches in parallel:

**Active update** — `npx @quantobooks/skills install --upgrade`. User-driven. Shows a diff.

**Passive prompt** — the MCP server returns a `_meta.skill_version` field on the `get_active_client_info` response (or a dedicated `get_skill_advice` tool). If the version the user's MCP server reports is newer than what they have installed, Claude can mention it in conversation: *"Heads up — there's a newer version of the QuantoBooks skills (v1.3.0, you have v1.1.0). Run `npx @quantobooks/skills install --upgrade` to update."* This requires:

- A `version` file in the skills bundle
- A small `version_check` endpoint or MCP tool the agent can call
- Skill copy that instructs the agent to mention updates exactly once per session

Lean toward passive prompt — users don't check for updates on their own.

## Versioning

Skills are versioned together as a bundle, not individually. SemVer applies:
- **patch** — clarification, typo, trigger phrase tuning
- **minor** — new skill added, new step in an existing skill
- **major** — breaking change to a skill's expected outputs (rare; only if we change a workflow's contract with downstream consumers)

A single `version.json` at the bundle root, mirrored to the npm package version.

## What to build first

Order of operations:

1. **Land the skills in the monorepo** ← done in this commit
2. **Set up the public mirror repo + CI mirror job** — small GitHub Action, ~30 lines
3. **Ship the `@quantobooks/skills` npm package + CLI** — small Node project, hosted in `apps/skills-cli` or `tools/skills-cli`
4. **Add the web app "Install Skills" page** — settings UI with copy command + download zip
5. **Add the version-check MCP tool + passive update prompt copy** — small task-runner / mcp-server change

Steps 1–3 are necessary for any users to install. Steps 4–5 are about reducing friction for the non-engineer majority.

## Quality bar before public release

Before announcing skills to users:
- Every skill has been dogfooded by a real firm on a real client for one full close cycle
- Every skill's trigger description has been A/B tested against likely user phrasings (the foundation guard depends on Claude actually loading the skill when needed)
- The CLI works on macOS, Windows, Linux (sample install on each before publishing)
- The web app's install page has a "verify install" step that runs a no-op skill to confirm Claude can see them

## Open questions

- **Should skills auto-update on every Claude Code launch?** A `~/.claude/skills/.quantobooks-version` file + a check-on-start hook could do this. Probably yes for Claude Code users; probably no for Claude Desktop (no hook surface).
- **How do we handle per-firm customization?** Some firms will want to tweak the close playbook (e.g., they always start with cash, not accrual). Two options: (a) a `~/.claude/skills/quantobooks.overrides.md` that Claude loads after the bundled skill, (b) a web-app UI for editing skills and downloading the customized bundle. (b) is the right answer but (a) ships faster.
- **Do we ship skills via the MCP server itself?** Recent MCP spec drafts include skill discovery; if it lands we could stop shipping a separate bundle and have the MCP server advertise its own skills. Worth tracking but don't build for it yet — spec isn't stable.

## Out of scope for v1

- Multi-language skills (English only)
- Skill marketplaces / third-party skills
- Per-skill telemetry / usage analytics (we don't need it yet, and any telemetry needs to be opt-in)
- Auto-rollback if a new skill version misbehaves (manual `--upgrade --version 1.2.0` is fine for now)
