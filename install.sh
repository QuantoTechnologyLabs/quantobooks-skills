#!/usr/bin/env bash
#
# QuantoBooks Skills — one-command installer.
#
# Usage (recommended):
#   curl -fsSL https://get.quantobooks.com/skills | bash
#
# Or with options:
#   curl -fsSL https://get.quantobooks.com/skills | bash -s -- --dry-run
#   curl -fsSL https://get.quantobooks.com/skills | bash -s -- --target claude-desktop
#
# This script installs the bundle for **Claude Code** (the CLI) by copying
# skills into ~/.claude/skills/ (user) and ./.claude/skills/ (project):
#   1. Downloads the latest QuantoBooks skills bundle from GitHub
#   2. Copies skills into Claude Code's skills directories
#   3. Drops a quantobooks-version.json marker so updates can be detected later
#
# Claude Code / Cowork users can ALSO install the whole bundle as a plugin:
#   /plugin marketplace add quantotechnologylabs/quantobooks-skills
#   /plugin install quantobooks@quantobooks
#
# Claude DESKTOP does not load skills from a filesystem folder and does not
# support custom plugin marketplaces yet, so this script cannot install there.
# For Desktop, download the zip from the QuantoBooks dashboard and add skills
# via the in-app Skills uploader. (This script will tell you if it detects
# Desktop.)
#
# No Node, no npm, no sudo. macOS and Linux only — Windows users should run
# `npx @quantobooks/skills install` from PowerShell instead.
#
# To pin a specific version, set INSTALL_VERSION:
#   curl -fsSL https://get.quantobooks.com/skills | INSTALL_VERSION=0.1.0 bash
#
# To inspect the script before piping (recommended):
#   curl -fsSL https://get.quantobooks.com/skills | less

set -euo pipefail

# -------- Config --------
REPO="${INSTALL_REPO:-quantotechnologylabs/quantobooks-skills}"
VERSION="${INSTALL_VERSION:-latest}"
DRY_RUN=0
ONLY_TARGET=""

# -------- Pretty output (TTY only) --------
# Use ANSI-C ($'...') quoting so the variables hold real ESC bytes, not the
# literal 4-char string "\033[2m". That lets us print them with %s everywhere
# (a previous version embedded these in a %s argument, which printed the raw
# escape codes on screen).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_CYAN=$'\033[36m'
  C_OFF=$'\033[0m'
else
  C_DIM=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_OFF=""
fi

say()  { printf "%s\n" "$*"; }
step() { printf "%s→%s %s\n" "$C_CYAN" "$C_OFF" "$*"; }
ok()   { printf "%s✓%s %s\n" "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf "%s!%s %s\n" "$C_YELLOW" "$C_OFF" "$*" >&2; }
err()  { printf "%s✗%s %s\n" "$C_RED" "$C_OFF" "$*" >&2; }

# -------- Args --------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --target) ONLY_TARGET="${2:-}"; shift 2 ;;
    --target=*) ONLY_TARGET="${1#--target=}"; shift ;;
    -h|--help)
      cat <<EOF
QuantoBooks Skills installer (Claude Code)

Options:
  --target <id>   Install only to a specific location. One of:
                  claude-code-user, claude-code-project
  --dry-run       Show what would happen; write nothing
  -h, --help      Show this help

Note: Claude Desktop is not a supported target — it doesn't load skills from
a folder. For Desktop, use the in-app Skills uploader or the plugin install:
  /plugin marketplace add quantotechnologylabs/quantobooks-skills
  /plugin install quantobooks@quantobooks

Env vars:
  INSTALL_VERSION   Pin to a specific bundle version (e.g. 0.1.0). Default: latest
  INSTALL_REPO      Override mirror repo. Default: quantotechnologylabs/quantobooks-skills
  NO_COLOR          Suppress colored output
EOF
      exit 0
      ;;
    *) err "Unknown argument: $1"; exit 2 ;;
  esac
done

# -------- Sanity: required tools --------
need() { command -v "$1" >/dev/null 2>&1 || { err "Required tool not found: $1"; exit 1; }; }

if command -v curl >/dev/null 2>&1; then DL="curl -fsSL"
elif command -v wget >/dev/null 2>&1; then DL="wget -qO-"
else err "Need curl or wget. Install one and re-run."; exit 1
fi
need tar
need mkdir
need cp

# -------- Detect OS + per-OS Claude Desktop path --------
OS="$(uname -s)"
case "$OS" in
  Darwin) CLAUDE_DESKTOP_ROOT="$HOME/Library/Application Support/Claude" ;;
  Linux)  CLAUDE_DESKTOP_ROOT="${XDG_CONFIG_HOME:-$HOME/.config}/Claude" ;;
  *) err "Unsupported OS: $OS. Use npx @quantobooks/skills install instead."; exit 1 ;;
esac

# -------- Resolve version → tarball URL --------
if [ "$VERSION" = "latest" ]; then
  step "Resolving latest release of $REPO..."
  # GitHub releases API works unauthenticated for public repos (60 req/hr/IP).
  # If the repo has no releases yet, fall back to main branch.
  if RESOLVED="$($DL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
      | grep -E '"tag_name"' | head -n1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"; then
    if [ -n "$RESOLVED" ]; then
      VERSION="$RESOLVED"
      TARBALL_URL="https://github.com/$REPO/archive/refs/tags/$VERSION.tar.gz"
    else
      warn "No tagged releases found — falling back to main branch."
      VERSION="main"
      TARBALL_URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
    fi
  else
    warn "Could not reach GitHub API — falling back to main branch."
    VERSION="main"
    TARBALL_URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
  fi
else
  # User-pinned version. Strip any leading "v" they passed.
  VERSION="${VERSION#v}"
  TARBALL_URL="https://github.com/$REPO/archive/refs/tags/v$VERSION.tar.gz"
fi

say "${C_BOLD}QuantoBooks Skills${C_OFF}  ${C_DIM}($VERSION)${C_OFF}"
say ""

# Claude Desktop is detected only to warn the user — it can't be a file target.
if [ -d "$CLAUDE_DESKTOP_ROOT" ]; then DESKTOP_DETECTED=1; else DESKTOP_DETECTED=0; fi

# A user passing --target claude-desktop has the wrong mental model; explain
# and exit cleanly rather than writing files Desktop will ignore.
if [ "$ONLY_TARGET" = "claude-desktop" ]; then
  warn "Claude Desktop can't be installed to from the filesystem."
  say ""
  say "Claude Desktop doesn't load skills from a folder, and doesn't support"
  say "custom plugin marketplaces yet. To use these skills in Claude Desktop:"
  say "  • Download the bundle zip from the QuantoBooks dashboard and add each"
  say "    skill via Settings → Capabilities → Skills, or"
  say "  • Use Claude Code / Cowork instead (this installer, or the plugin:"
  say "    /plugin marketplace add quantotechnologylabs/quantobooks-skills)."
  exit 0
fi

# -------- Detect targets (Claude Code only) --------
# Each target is "id|label|path|detected"
TARGETS=()

CLAUDE_USER_ROOT="$HOME/.claude"
USER_SKILLS="$CLAUDE_USER_ROOT/skills"
[ -d "$CLAUDE_USER_ROOT" ] && DET=1 || DET=0
TARGETS+=("claude-code-user|Claude Code (user)|$USER_SKILLS|$DET")

PROJECT_SKILLS="$(pwd)/.claude/skills"
# Skip the project target when it resolves to the same dir as the user target
# (e.g. when run from $HOME), so we don't "install" twice to one place.
if [ "$PROJECT_SKILLS" != "$USER_SKILLS" ]; then
  [ -d "$(pwd)/.claude" ] && DET=1 || DET=0
  TARGETS+=("claude-code-project|Claude Code (project)|$PROJECT_SKILLS|$DET")
fi

# Pick which targets get the install.
SELECTED=()
if [ -n "$ONLY_TARGET" ]; then
  for entry in "${TARGETS[@]}"; do
    id="${entry%%|*}"
    [ "$id" = "$ONLY_TARGET" ] && SELECTED+=("$entry")
  done
  if [ ${#SELECTED[@]} -eq 0 ]; then
    err "No target matched --target $ONLY_TARGET (valid: claude-code-user, claude-code-project)"
    exit 2
  fi
else
  for entry in "${TARGETS[@]}"; do
    det="${entry##*|}"
    [ "$det" = "1" ] && SELECTED+=("$entry")
  done
  # If nothing detected, default to Claude Code (user) — we'll create the dir.
  if [ ${#SELECTED[@]} -eq 0 ]; then
    SELECTED+=("claude-code-user|Claude Code (user)|$USER_SKILLS|0")
  fi
fi

# -------- Download + extract --------
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t qbskills)"
trap 'rm -rf "$TMP"' EXIT

step "Downloading bundle from $TARBALL_URL"
if [ "$DRY_RUN" -eq 1 ]; then
  say "  ${C_DIM}(dry-run: skipping download)${C_OFF}"
else
  $DL "$TARBALL_URL" > "$TMP/bundle.tar.gz" || {
    err "Download failed. Check your network or pin INSTALL_VERSION to a known release."
    exit 1
  }
  tar -xzf "$TMP/bundle.tar.gz" -C "$TMP"
  # GitHub tarballs extract to a single top-level dir named <repo>-<ref>.
  EXTRACTED="$(find "$TMP" -mindepth 1 -maxdepth 1 -type d | head -n1)"
  if [ -z "$EXTRACTED" ] || [ ! -d "$EXTRACTED" ]; then
    err "Tarball extraction produced no directory."
    exit 1
  fi
  # The mirror layout puts skills at top level (no /skills/ subdir, since
  # the mirror workflow copies our skills folder to the root of the mirror).
  # Probe for both shapes so this script also works against the source repo
  # for testing.
  if [ -d "$EXTRACTED/skills" ]; then
    SKILLS_SRC="$EXTRACTED/skills"
  else
    SKILLS_SRC="$EXTRACTED"
  fi
  if [ ! -f "$SKILLS_SRC/version.json" ]; then
    err "Downloaded bundle is missing version.json — refusing to install."
    exit 1
  fi
fi
say ""

# -------- Install --------
TOTAL_INSTALLED=0
for entry in "${SELECTED[@]}"; do
  IFS='|' read -r id label path _det <<EOF
$entry
EOF
  step "${label}  ${C_DIM}(${path})${C_OFF}"

  if [ "$DRY_RUN" -eq 1 ]; then
    say "  ${C_GREEN}+${C_OFF} would install 14 skill(s) ${C_DIM}(dry-run)${C_OFF}"
    continue
  fi

  mkdir -p "$path"

  installed_here=0
  for skill_dir in "$SKILLS_SRC"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    [ -f "$skill_dir/SKILL.md" ] || continue

    rm -rf "$path/$skill_name"
    cp -R "$skill_dir" "$path/$skill_name"
    say "  ${C_GREEN}+${C_OFF} $skill_name"
    installed_here=$((installed_here + 1))
    TOTAL_INSTALLED=$((TOTAL_INSTALLED + 1))
  done

  # Drop the version marker (used by `quantobooks-skills list` later).
  if [ -f "$SKILLS_SRC/version.json" ]; then
    cp "$SKILLS_SRC/version.json" "$path/quantobooks-version.json"
  fi

  if [ "$installed_here" -eq 0 ]; then
    warn "No skill directories found in the bundle for $label."
  fi
  say ""
done

ok "Done. Installed $TOTAL_INSTALLED skill(s) across ${#SELECTED[@]} location(s)."
say ""
say "${C_DIM}Try it: open Claude Code and say \"run a month-end close for my active client\".${C_OFF}"
say ""
say "${C_DIM}Tip: in Claude Code / Cowork you can install + auto-update the whole${C_OFF}"
say "${C_DIM}bundle as one plugin instead:${C_OFF}"
say "${C_DIM}  /plugin marketplace add quantotechnologylabs/quantobooks-skills${C_OFF}"
say "${C_DIM}  /plugin install quantobooks@quantobooks${C_OFF}"

if [ "$DESKTOP_DETECTED" = "1" ]; then
  say ""
  warn "Claude Desktop detected — note these skills will NOT appear there."
  say "${C_DIM}Desktop doesn't load filesystem skills. Use the in-app Skills uploader${C_OFF}"
  say "${C_DIM}(download the zip from the QuantoBooks dashboard), or use Claude Code.${C_OFF}"
fi
