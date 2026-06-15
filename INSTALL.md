# Installing QuantoBooks Skills

End users have four install paths. Pick whichever matches the user's setup.

## Path 1 — One-line shell installer (recommended; no Node required)

```bash
curl -fsSL https://get.quantobooks.com/skills | bash
```

What it does:
1. Detects which Claude clients are installed (Claude Code, Claude Desktop).
2. Downloads the latest skills bundle from GitHub.
3. Copies every skill into the right skills directory for each detected client.
4. Drops a version marker so future updates can detect what's installed.

No Node, no npm, no sudo. macOS + Linux only — Windows users should use Path 2.

Optional flags (pass after `--`):

```bash
curl -fsSL https://get.quantobooks.com/skills | bash -s -- --dry-run
curl -fsSL https://get.quantobooks.com/skills | bash -s -- --target claude-desktop
```

Pin a specific version:

```bash
curl -fsSL https://get.quantobooks.com/skills | INSTALL_VERSION=0.1.0 bash
```

Want to inspect before running (recommended for any pipe-to-bash):

```bash
curl -fsSL https://get.quantobooks.com/skills | less
```

The script itself lives at [`install.sh`](./install.sh) in this directory and at the root of the public mirror repo.

## Path 2 — Node CLI (Windows, or anywhere npx works)

```bash
npx @quantobooks/skills install
```

What it does (same outcome as Path 1):
1. Detects which Claude clients are installed.
2. Copies every skill from the package into the right skills directory.
3. Prints a summary.

Re-run any time to update.

Optional flags:
- `--target claude-code-user` / `--target claude-desktop` — restrict client
- `--skills quanto-month-end-close,flag-triage` — install a subset
- `--dry-run` — preview without writing
- `--upgrade` — explicit re-install (default behavior; flag kept for clarity)

## Path 3 — Web app one-click install (for users who don't want a CLI)

In the QuantoBooks dashboard, **Settings → AI Assistant → Skills** offers:

- A "Copy install command" button that puts `npx @quantobooks/skills install` on the clipboard
- A "Download bundle" button for users on locked-down machines — gives a zip with the skill folders and a per-OS README explaining where to drop them

Same files as Path 1, just delivered without a terminal.

## Path 4 — Manual install (for power users + air-gapped environments)

```bash
git clone https://github.com/quantotechnologylabs/quantobooks-skills.git
cd quantobooks-skills

# Claude Code (user-level, applies across all projects)
cp -r skills/* ~/.claude/skills/

# Claude Code (project-level, applies in this repo only)
cp -r skills/* ./.claude/skills/

# Claude Desktop (macOS)
cp -r skills/* "~/Library/Application Support/Claude/skills/"
```

Or symlink instead of copy if you want to follow the git repo:

```bash
ln -s "$(pwd)/skills" ~/.claude/skills/quantobooks
```

## Source of truth

This directory (`apps/mcp-server/skills/` in `glaceon-monorepo`) is the canonical source. A GitHub Action mirrors every change to the public [`quantotechnologylabs/quantobooks-skills`](https://github.com/quantotechnologylabs/quantobooks-skills) repo on push to `production`. The npm package `@quantobooks/skills` publishes from the same mirror.

## Verifying installation

After install, in Claude Code or Claude Desktop, run:

```
/skills list
```

You should see the QuantoBooks skills listed. To test, try:

> "Run a month-end close for my active client"

Claude should load the `quanto-month-end-close` skill and start by calling `get_active_client_info`.

## Updating

```bash
npx @quantobooks/skills install --upgrade
```

This re-downloads the latest version and overwrites. The CLI prints a diff of changes since the last install so users see what's new.

## Uninstall

```bash
npx @quantobooks/skills uninstall
```

Removes every skill the installer placed. Leaves anything the user added manually.

## What lives where

| Client | Skills directory |
|--------|------------------|
| Claude Code (user) | `~/.claude/skills/` |
| Claude Code (project) | `<repo>/.claude/skills/` |
| Claude Desktop (macOS) | `~/Library/Application Support/Claude/skills/` |
| Claude Desktop (Windows) | `%APPDATA%/Claude/skills/` |
| Claude Desktop (Linux) | `~/.config/Claude/skills/` |
| Claude.ai web | Uploaded as Project Knowledge (the CLI generates a zip for this) |

## Telemetry (none by default)

The installer doesn't phone home. We add nothing to the user's machine other than the skill files themselves. If we ever ship optional usage telemetry, it'll be opt-in with a `--enable-telemetry` flag.
