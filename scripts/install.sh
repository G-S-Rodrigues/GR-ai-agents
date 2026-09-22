#!/usr/bin/env bash
#
# Install the Evo agent skills into your local harness by symlink, so a `git pull`
# in this repo updates every installed skill with no reinstall.
#
#   ./scripts/install.sh                 install skills + agents + references
#   ./scripts/install.sh --dry-run       show what would change, touch nothing
#   ./scripts/install.sh --with-drafts   also install skills/in-progress/*
#   ./scripts/install.sh --claude-only   skip the ~/.codex targets
#
# Existing real files/directories at a target path are moved into a timestamped
# backup directory, never deleted. Existing symlinks are replaced.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="${HOME}/.GR-ai-agents-backup/$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
WITH_DRAFTS=0
CLAUDE_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)     DRY_RUN=1 ;;
    --with-drafts) WITH_DRAFTS=1 ;;
    --claude-only) CLAUDE_ONLY=1 ;;
    -h|--help)     sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
[ -t 1 ] || { c_ok=""; c_warn=""; c_dim=""; c_off=""; }

say()  { printf '%s\n' "$*"; }
run()  { if [ "$DRY_RUN" = 1 ]; then printf '%s  would: %s%s\n' "$c_dim" "$*" "$c_off"; else "$@"; fi; }

backed_up=0

# link <source> <target>
link() {
  local src="$1" dst="$2" name="${2##*/}" relative_src
  relative_src="$(realpath --relative-to="$(dirname "$dst")" "$src")"

  if [ -L "$dst" ]; then
    # Compare the immediate target, not the resolved one: a link that chains through
    # another install target resolves to the right file but breaks the moment that
    # intermediate link is removed. Every target must point straight at the repo.
    local cur; cur="$(readlink "$dst" || true)"
    if [ "$cur" = "$relative_src" ]; then
      printf '  %s✓%s %-24s already linked\n' "$c_ok" "$c_off" "$name"; return
    fi
    run rm -f "$dst"
    printf '  %s↻%s %-24s relinked %s(was %s)%s\n' "$c_ok" "$c_off" "$name" "$c_dim" "${cur:-broken}" "$c_off"
  elif [ -e "$dst" ]; then
    run mkdir -p "$BACKUP/$(dirname "${dst#"$HOME"/}")"
    run mv "$dst" "$BACKUP/${dst#"$HOME"/}"
    backed_up=1
    printf '  %s⇄%s %-24s backed up, then linked\n' "$c_warn" "$c_off" "$name"
  else
    printf '  %s+%s %-24s linked\n' "$c_ok" "$c_off" "$name"
  fi

  run mkdir -p "$(dirname "$dst")"
  run ln -s "$relative_src" "$dst"
}

[ "$DRY_RUN" = 1 ] && say "${c_dim}dry run — nothing will be written${c_off}"
say "repo: $REPO"

# --- targets ------------------------------------------------------------------
SKILL_DIRS=("$HOME/.claude/skills")
AGENT_DIRS=("$HOME/.claude/agents")
REF_DIRS=("$HOME/.claude/GR-references")
if [ "$CLAUDE_ONLY" = 0 ]; then
  SKILL_DIRS+=("$HOME/.codex/skills")
  REF_DIRS+=("$HOME/.codex/GR-references")
fi

# --- skills -------------------------------------------------------------------
say ""
say "skills →  ${SKILL_DIRS[*]}"
for skill in "$REPO"/skills/*/; do
  name="$(basename "$skill")"
  [ "$name" = "in-progress" ] && continue
  [ -f "$skill/SKILL.md" ] || { printf '  %s!%s %-24s no SKILL.md, skipped\n' "$c_warn" "$c_off" "$name"; continue; }
  for d in "${SKILL_DIRS[@]}"; do link "${skill%/}" "$d/$name"; done
done

if [ "$WITH_DRAFTS" = 1 ]; then
  say ""
  say "drafts (skills/in-progress) →"
  for skill in "$REPO"/skills/in-progress/*/; do
    [ -d "$skill" ] || continue
    name="$(basename "$skill")"
    [ -f "$skill/SKILL.md" ] || continue
    for d in "${SKILL_DIRS[@]}"; do link "${skill%/}" "$d/$name"; done
  done
fi

# --- agents (Claude subagents only) -------------------------------------------
say ""
say "agents →  ${AGENT_DIRS[*]}"
for agent in "$REPO"/agents/*.md; do
  [ -e "$agent" ] || continue
  name="$(basename "$agent")"
  [ "$name" = "README.md" ] && continue
  for d in "${AGENT_DIRS[@]}"; do link "$agent" "$d/$name"; done
done

# --- shared references --------------------------------------------------------
say ""
say "references →  ${REF_DIRS[*]}"
for d in "${REF_DIRS[@]}"; do link "$REPO/references" "$d"; done

# --- done ---------------------------------------------------------------------
say ""
if [ "$DRY_RUN" = 1 ]; then
  say "${c_dim}dry run complete — re-run without --dry-run to apply${c_off}"
else
  say "${c_ok}done.${c_off} Skills update on 'git pull' — no reinstall needed."
  [ "$backed_up" = 1 ] && say "${c_warn}Replaced files were moved to: $BACKUP${c_off}"
fi
say ""
say "Hooks are NOT installed by this script — they need settings.json entries."
say "See hooks/README.md and add them yourself."
