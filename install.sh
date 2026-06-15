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
# This script:
#   1. Detects which Claude clients are installed on this machine
#   2. Downloads the latest QuantoBooks skills bundle from GitHub
#   3. Copies skills into each detected client's skills directory
#   4. Drops a quantobooks-version.json marker so updates can be detected later
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
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_DIM="\033[2m"; C_BOLD="\033[1m"
  C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_RED="\033[31m"; C_CYAN="\033[36m"
  C_OFF="\033[0m"
else
  C_DIM=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_OFF=""
fi

say()  { printf "%b\n" "$*"; }
step() { printf "%b→%b %s\n" "$C_CYAN" "$C_OFF" "$*"; }
ok()   { printf "%b✓%b %s\n" "$C_GREEN" "$C_OFF" "$*"; }
warn() { printf "%b!%b %s\n" "$C_YELLOW" "$C_OFF" "$*" >&2; }
err()  { printf "%b✗%b %s\n" "$C_RED" "$C_OFF" "$*" >&2; }

# -------- Args --------
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --target) ONLY_TARGET="${2:-}"; shift 2 ;;
    --target=*) ONLY_TARGET="${1#--target=}"; shift ;;
    -h|--help)
      cat <<EOF
QuantoBooks Skills installer

Options:
  --target <id>   Install only to a specific client. One of:
                  claude-code-user, claude-code-project, claude-desktop
  --dry-run       Show what would happen; write nothing
  -h, --help      Show this help

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

# -------- Detect targets --------
# Each target is "id|label|path|detected"
TARGETS=()

CLAUDE_USER_ROOT="$HOME/.claude"
[ -d "$CLAUDE_USER_ROOT" ] && DET=1 || DET=0
TARGETS+=("claude-code-user|Claude Code (user)|$CLAUDE_USER_ROOT/skills|$DET")

[ -d "$(pwd)/.claude" ] && DET=1 || DET=0
TARGETS+=("claude-code-project|Claude Code (project)|$(pwd)/.claude/skills|$DET")

[ -d "$CLAUDE_DESKTOP_ROOT" ] && DET=1 || DET=0
TARGETS+=("claude-desktop|Claude Desktop|$CLAUDE_DESKTOP_ROOT/skills|$DET")

# Pick which targets get the install.
SELECTED=()
if [ -n "$ONLY_TARGET" ]; then
  for entry in "${TARGETS[@]}"; do
    id="${entry%%|*}"
    [ "$id" = "$ONLY_TARGET" ] && SELECTED+=("$entry")
  done
  if [ ${#SELECTED[@]} -eq 0 ]; then
    err "No target matched --target $ONLY_TARGET"
    exit 2
  fi
else
  for entry in "${TARGETS[@]}"; do
    det="${entry##*|}"
    [ "$det" = "1" ] && SELECTED+=("$entry")
  done
  # If nothing detected, default to Claude Code (user) — we'll create the dir.
  if [ ${#SELECTED[@]} -eq 0 ]; then
    warn "No Claude clients detected — installing to Claude Code (user) anyway."
    SELECTED+=("claude-code-user|Claude Code (user)|$CLAUDE_USER_ROOT/skills|0")
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
say "${C_DIM}Try it: open Claude and say \"run a month-end close for my active client\".${C_OFF}"
