#!/usr/bin/env bash
#
# Install the shared statusline into your local harness by symlink, so a `git pull`
# in this repo updates the running statusline with no reinstall, and wire it into
# settings.json.
#
#   ./scripts/statusline_install.sh              install + wire into ~/.claude/settings.json
#   ./scripts/statusline_install.sh --dry-run    show what would change, touch nothing
#
# Requires: bash, jq. The statusline script itself additionally wants git and curl
# on PATH at run time (see statusline/statusline.sh).

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/statusline/statusline.sh"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
LINK="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
BACKUP="${HOME}/.GR-ai-agents-backup/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)         echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq is required but not on PATH" >&2; exit 1; }

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
[ -t 1 ] || { c_ok=""; c_warn=""; c_dim=""; c_off=""; }

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" = 1 ]; then printf '%s  would: %s%s\n' "$c_dim" "$*" "$c_off"; else "$@"; fi; }

[ "$DRY_RUN" = 1 ] && say "${c_dim}dry run — nothing will be written${c_off}"
say "repo: $REPO"

# --- symlink the script --------------------------------------------------------
say ""
say "statusline script → $LINK"
if [ -L "$LINK" ]; then
  cur="$(readlink "$LINK" || true)"
  if [ "$cur" = "$SRC" ]; then
    say "  ${c_ok}✓${c_off} already linked"
  else
    run rm -f "$LINK"
    run ln -s "$SRC" "$LINK"
    say "  ${c_ok}↻${c_off} relinked ${c_dim}(was $cur)${c_off}"
  fi
elif [ -e "$LINK" ]; then
  run mkdir -p "$BACKUP"
  run mv "$LINK" "$BACKUP/statusline.sh"
  run ln -s "$SRC" "$LINK"
  say "  ${c_warn}⇄${c_off} backed up existing file, then linked"
else
  run mkdir -p "$CLAUDE_DIR"
  run ln -s "$SRC" "$LINK"
  say "  ${c_ok}+${c_off} linked"
fi

# --- wire into settings.json ---------------------------------------------------
# settings.json is shared, user-owned config (permissions, env vars, model config
# alongside statusLine) — merge only the one key we own, never overwrite the file.
say ""
say "settings.json statusLine → $LINK"

if [ ! -f "$SETTINGS" ]; then
  run mkdir -p "$CLAUDE_DIR"
  run bash -c "printf '{}' > '$SETTINGS'"
  say "  ${c_dim}created empty $SETTINGS${c_off}"
fi

if [ "$DRY_RUN" = 1 ]; then
  say "  ${c_dim}would: set .statusLine = {type: command, command: \"$LINK\", padding: 0}${c_off}"
else
  jq -e . "$SETTINGS" >/dev/null 2>&1 || { echo "  $SETTINGS is not valid JSON — fix it by hand first" >&2; exit 1; }

  cur_cmd=$(jq -r '.statusLine.command // empty' "$SETTINGS")
  if [ "$cur_cmd" = "$LINK" ]; then
    say "  ${c_ok}✓${c_off} already wired"
  else
    run mkdir -p "$BACKUP"
    run cp "$SETTINGS" "$BACKUP/settings.json"
    tmp="$(mktemp)"
    jq --arg cmd "$LINK" \
      '.statusLine = {"type": "command", "command": $cmd, "padding": 0}' \
      "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
    if [ -n "$cur_cmd" ]; then
      say "  ${c_ok}↻${c_off} replaced previous statusLine command ${c_dim}(was $cur_cmd, backed up)${c_off}"
    else
      say "  ${c_ok}+${c_off} wired"
    fi
  fi
fi

# --- done ------------------------------------------------------------------------
say ""
if [ "$DRY_RUN" = 1 ]; then
  say "${c_dim}dry run complete — re-run without --dry-run to apply${c_off}"
else
  say "${c_ok}done.${c_off} Restart Claude Code (or open a new session) to see the statusline."
  if [ -d "$BACKUP" ]; then
    say "${c_warn}Replaced files were backed up to: $BACKUP${c_off}"
  fi
fi
