#!/usr/bin/env bash
#
# Remove symlinks that point into this repo. Only removes links whose target is
# inside the repo — anything else (your own skills, other marketplaces) is left alone.
#
#   ./scripts/uninstall.sh            remove links
#   ./scripts/uninstall.sh --dry-run  show what would be removed
#   CLAUDE_BIN=<path> ./scripts/uninstall.sh   use this claude CLI for the plugin step
#
# Also uninstalls the fast-jev-compaction plugin and its marketplace through the
# claude CLI, which deletes the plugin's saved options. The plugins/ checkout stays.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

c_ok=$'\033[32m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
[ -t 1 ] || { c_ok=""; c_dim=""; c_off=""; }

removed=0
for dir in "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.claude/agents" \
           "$HOME/.claude" "$HOME/.codex"; do
  [ -d "$dir" ] || continue
  for entry in "$dir"/*; do
    [ -L "$entry" ] || continue
    target="$(readlink -f "$entry" || true)"
    case "$target" in
      "$REPO"|"$REPO"/*)
        if [ "$DRY_RUN" = 1 ]; then
          printf '%s  would remove: %s%s\n' "$c_dim" "$entry" "$c_off"
        else
          rm -f "$entry"; printf '  %s−%s %s\n' "$c_ok" "$c_off" "$entry"
        fi
        removed=$((removed + 1))
        ;;
    esac
  done
done

# --- fast-jev-compaction plugin -----------------------------------------------
# Resolve the claude CLI: $CLAUDE_BIN, else `claude` on PATH. Never claude.exe: under
# WSL that manages the Windows profile, not this one.
claude_cli() {
  if [ -n "${CLAUDE_BIN:-}" ]; then
    [ -x "$CLAUDE_BIN" ] && printf '%s\n' "$CLAUDE_BIN"
  else
    command -v claude || true
  fi
}

PLUGIN_ID="fast-jev-compaction@gr-fast-jev-compaction"
MARKETPLACE="gr-fast-jev-compaction"
CLI="$(claude_cli || true)"
if [ -z "$CLI" ]; then
  echo "claude CLI not found (CLAUDE_BIN=${CLAUDE_BIN:-unset}) -- plugin left installed; set CLAUDE_BIN=<path to claude>"
elif [ "$DRY_RUN" = 1 ]; then
  printf '%s  would: %s plugin uninstall %s (if installed)%s\n' "$c_dim" "$CLI" "$PLUGIN_ID" "$c_off"
  printf '%s  would: %s plugin marketplace remove %s (if present; drops the plugin'"'"'s saved options)%s\n' \
    "$c_dim" "$CLI" "$MARKETPLACE" "$c_off"
else
  # Capture each list first: removing something absent exits 1, and a failing `list`
  # must not be swallowed inside an `if` pipeline.
  plugins="$("$CLI" plugin list --json)"
  if printf '%s\n' "$plugins" | grep -qF "\"$PLUGIN_ID\""; then
    "$CLI" plugin uninstall "$PLUGIN_ID"
  fi
  mkts="$("$CLI" plugin marketplace list --json)"
  if printf '%s\n' "$mkts" | grep -qF "\"$MARKETPLACE\""; then
    echo "removing marketplace $MARKETPLACE (this deletes the plugin's saved options)"
    "$CLI" plugin marketplace remove "$MARKETPLACE"
  fi
fi

if [ "$removed" = 0 ]; then
  echo "Nothing installed from this repo."
elif [ "$DRY_RUN" = 1 ]; then
  echo "$removed link(s) would be removed."
else
  echo "Removed $removed link(s). Backups, if any, are under ~/.GR-ai-agents-backup/."
fi
