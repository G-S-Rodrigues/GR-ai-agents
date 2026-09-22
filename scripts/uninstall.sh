#!/usr/bin/env bash
#
# Remove symlinks that point into this repo. Only removes links whose target is
# inside the repo — anything else (your own skills, other marketplaces) is left alone.
#
#   ./scripts/uninstall.sh            remove links
#   ./scripts/uninstall.sh --dry-run  show what would be removed

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

if [ "$removed" = 0 ]; then
  echo "Nothing installed from this repo."
elif [ "$DRY_RUN" = 1 ]; then
  echo "$removed link(s) would be removed."
else
  echo "Removed $removed link(s). Backups, if any, are under ~/.GR-ai-agents-backup/."
fi
