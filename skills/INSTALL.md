# Installing QuantoBooks Skills

Pick the path that matches your client. **Claude Code / Cowork** has a true
one-command bundle install (the plugin marketplace). **Claude Desktop** does
not — see the note at the bottom.

## Path 1 — Plugin marketplace (recommended for Claude Code / Cowork)

All skills install as one plugin, namespaced `quantobooks:quanto-*`, and
update in place. There are two ways to add it depending on your client.

### Claude Code (CLI) — slash commands

```
/plugin marketplace add quantotechnologylabs/quantobooks-skills
/plugin install quantobooks@quantobooks
```

Update later with `/plugin update quantobooks@quantobooks`. Restart Claude
Code so it picks up the new skills.

### Cowork (Claude desktop app) — UI, not slash commands

Cowork doesn't take `/plugin` commands — you add the marketplace through the
**Customize** panel:

1. Open **Customize** (the toolbox icon).
2. Under **Personal plugins**, click the **+**.
3. Choose **Create plugin → Add marketplace**.
4. Paste the marketplace repo: `quantotechnologylabs/quantobooks-skills`
   (or the full URL `https://github.com/quantotechnologylabs/quantobooks-skills`).
5. Once the marketplace is added, install the **quantobooks** plugin from it.

The plugin then appears under **Personal plugins → Quantobooks**, and all 14
skills are available in your Cowork sessions. To update, re-open the plugin
from the same menu and pull the latest.

This is the cleanest path on either client: one unit, updatable, no loose files.

## Path 2 — One-line shell installer (Claude Code, no Node required)

Copies skills into `~/.claude/skills/` (and the project `.claude/skills/` if
you run it from a repo). Good if you don't want the plugin system.

```bash
curl -fsSL https://www.quantobooks.com/api/skills/install.sh | bash
```

No Node, no npm, no sudo. macOS + Linux only — Windows users use Path 3.

Optional flags (pass after `--`):

```bash
curl -fsSL https://www.quantobooks.com/api/skills/install.sh | bash -s -- --dry-run
curl -fsSL https://www.quantobooks.com/api/skills/install.sh | bash -s -- --target claude-code-project
```

Pin a specific version:

```bash
curl -fsSL https://www.quantobooks.com/api/skills/install.sh | INSTALL_VERSION=0.4.0 bash
```

Inspect before running (recommended for any pipe-to-bash):

```bash
curl -fsSL https://www.quantobooks.com/api/skills/install.sh | less
```

The script lives at [`install.sh`](./install.sh) here and at the root of the
public mirror repo.

## Path 3 — Node CLI (Windows, or anywhere npx works; Claude Code)

```bash
npx @quantobooks/skills install
```

Same outcome as Path 2 (copies into `~/.claude/skills/`). Flags:
- `--target claude-code-user` / `--target claude-code-project` — restrict location
- `--skills quanto-month-end-close,quanto-flag-triage` — install a subset
- `--dry-run` — preview without writing

## Path 4 — Manual (power users / air-gapped; Claude Code)

```bash
git clone https://github.com/quantotechnologylabs/quantobooks-skills.git
cd quantobooks-skills

# Claude Code (user-level, all projects)
cp -r skills/quanto-* ~/.claude/skills/

# Claude Code (project-level, this repo only)
cp -r skills/quanto-* ./.claude/skills/
```

## Claude Desktop

**Claude Desktop can't install this bundle from the filesystem, and doesn't
support custom plugin marketplaces yet.** Dropping files into
`~/Library/Application Support/Claude/skills/` does nothing — the app ignores
it. Your options today:

1. **Download the zip** from the QuantoBooks dashboard (Settings → AI
   Assistant → Skills → Download bundle) and add each skill via Claude
   Desktop's in-app Skills uploader (Settings → Capabilities → Skills). This
   is one-at-a-time — a Claude product constraint, not ours.
2. **Use Claude Code / Cowork instead** (Path 1), where the whole bundle
   installs in one command.

We'll switch Desktop to a one-command install the moment Anthropic exposes
custom marketplaces there.

## Verifying installation

In Claude Code, after a restart, try:

> "Run a month-end close for my active client"

Claude should load `quanto-month-end-close` and start by confirming the active
client (`get_active_client_info`). If it doesn't, the skills aren't loaded —
re-run the installer / re-add the plugin and restart.

## Updating

- **Plugin marketplace:** `/plugin update quantobooks@quantobooks`
- **Shell / npx:** re-run the installer (it overwrites in place).

## Uninstall

- **Plugin marketplace:** `/plugin uninstall quantobooks@quantobooks`
- **Shell / npx:** `npx @quantobooks/skills uninstall` (removes only what the
  CLI placed; leaves skills you added manually).

## Source of truth

`apps/mcp-server/skills/` in `glaceon-monorepo` is canonical. A GitHub Action
mirrors every change to the public
[`quantotechnologylabs/quantobooks-skills`](https://github.com/quantotechnologylabs/quantobooks-skills)
repo (skills + `install.sh` + the plugin-marketplace manifests) on push to
`production`. The npm package `@quantobooks/skills` publishes from the same
source.

## What lives where (Claude Code)

| Location | Skills directory |
|----------|------------------|
| Plugin install | `~/.claude/plugins/` (managed by `/plugin`) |
| Claude Code (user) | `~/.claude/skills/` |
| Claude Code (project) | `<repo>/.claude/skills/` |
