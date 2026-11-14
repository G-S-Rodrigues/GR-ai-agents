#!/usr/bin/env bash
# List the worktrees of the current repo that are safe to remove, and remove them with --remove.
#
# A worktree is removable when it is clean and its branch has landed. Clean: `git status` shows no
# modified or untracked file (ignored build output does not count). Landed: GitHub reports a merged
# PR from the branch whose head is the branch tip or contains it. Nothing else counts: a branch
# with no commits of its own sits on origin/main exactly like a fast-forwarded one, so a worktree
# made for a part that has not committed yet would look landed. A branch name reused after its PR
# merged keeps. A branch landed without a PR is kept and listed; remove it by hand.
# The main checkout and detached worktrees are never touched.
#
# Usage, from inside the repo:
#   worktree_gc.sh               # dry run: one "remove" or "keep" line per worktree
#   worktree_gc.sh --remove      # also remove each removable worktree and its local branch
#
# A removal can fail on files a container wrote as root; the line says so and names the path.
# Delete those through a container (the repo's gotchas say how), then run `git worktree prune`.
set -uo pipefail

remove=0
for a in "$@"; do
  case "$a" in
    --remove) remove=1 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 64 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not in a git repo" >&2; exit 64; }
main_wt=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
git -C "$main_wt" fetch -q origin 2>/dev/null || echo "warning: fetch failed; judging against the local origin/main" >&2
git -C "$main_wt" rev-parse -q --verify origin/main >/dev/null || {
  echo "no origin/main in $main_wt: nothing to judge a branch as landed against; nothing removed" >&2; exit 65; }
command -v gh >/dev/null || { echo "gh not found: a branch counts as landed only by its merged PR; nothing removed" >&2; exit 65; }

landed() {  # landed BRANCH -> prints the reason and returns 0 when a merged PR carried the tip
  local b="$1" tip oid
  tip=$(git -C "$main_wt" rev-parse "refs/heads/$b") || return 1
  for oid in $(gh pr list --head "$b" --state merged --json headRefOid --jq '.[].headRefOid' 2>/dev/null); do
    if [ "$oid" = "$tip" ] || git -C "$main_wt" merge-base --is-ancestor "$tip" "$oid" 2>/dev/null; then
      echo "PR merged on GitHub at this tip"; return 0
    fi
  done
  return 1
}

path="" branch="" n_remove=0 n_keep=0
verdict() {
  local p="$1" b="$2" why
  [ -z "$p" ] || [ "$p" = "$main_wt" ] && return
  if [ -z "$b" ]; then echo "keep   $p (detached)"; n_keep=$((n_keep + 1)); return; fi
  if [ ! -d "$p" ]; then echo "keep   $p $b (directory missing; git worktree prune clears it)"; n_keep=$((n_keep + 1)); return; fi
  if [ -n "$(git -C "$p" status --porcelain 2>/dev/null | head -1)" ]; then
    echo "keep   $p $b (uncommitted or untracked changes)"; n_keep=$((n_keep + 1)); return
  fi
  if ! why=$(landed "$b"); then
    echo "keep   $p $b (no merged PR at this tip; $(git -C "$main_wt" rev-list --count "origin/main..refs/heads/$b") commits not on origin/main)"
    n_keep=$((n_keep + 1)); return
  fi
  echo "remove $p $b ($why)"; n_remove=$((n_remove + 1))
  if [ "$remove" = 1 ]; then
    local err
    if err=$(git -C "$main_wt" worktree remove --force "$p" 2>&1); then
      git -C "$main_wt" branch -D "$b" >/dev/null 2>&1
    else
      echo "  could not remove: $(head -1 <<<"$err")"
    fi
  fi
}

while IFS= read -r line; do
  case "$line" in
    "worktree "*) verdict "$path" "$branch"; path=${line#worktree }; branch="" ;;
    "branch refs/heads/"*) branch=${line#branch refs/heads/} ;;
  esac
done < <(git -C "$main_wt" worktree list --porcelain)
verdict "$path" "$branch"

[ "$remove" = 1 ] && git -C "$main_wt" worktree prune
echo "$n_remove removable, $n_keep kept$([ "$remove" = 1 ] || echo ' (dry run; --remove to remove)')"
