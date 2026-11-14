#!/usr/bin/env bash
# List the worktrees of the current repo that are safe to remove, and remove them with --remove.
#
# A worktree is removable when it is clean and its branch has landed. Clean: `git status` shows no
# modified or untracked file (ignored build output does not count). Landed, any one of:
#   - the branch tip is an ancestor of origin/main (merge commit or fast-forward);
#   - every commit ahead of origin/main is patch-equivalent to one on it (`git cherry`, which
#     catches a rebase merge and a one-commit squash);
#   - GitHub reports a merged PR from the branch (a multi-commit squash; skipped with --no-gh).
# The main checkout and detached worktrees are never touched.
#
# Usage, from inside the repo:
#   worktree_gc.sh               # dry run: one "remove" or "keep" line per worktree
#   worktree_gc.sh --remove      # also remove each removable worktree and its local branch
#   worktree_gc.sh --no-gh       # do not ask GitHub
#
# A removal can fail on files a container wrote as root; the line says so and names the path.
# Delete those through a container (the repo's gotchas say how), then run `git worktree prune`.
set -uo pipefail

remove=0 use_gh=1
for a in "$@"; do
  case "$a" in
    --remove) remove=1 ;;
    --no-gh) use_gh=0 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $a" >&2; exit 64 ;;
  esac
done

git rev-parse --git-dir >/dev/null 2>&1 || { echo "not in a git repo" >&2; exit 64; }
main_wt=$(git worktree list --porcelain | sed -n '1s/^worktree //p')
git -C "$main_wt" fetch -q origin 2>/dev/null || echo "warning: fetch failed; judging against the local origin/main" >&2
[ "$use_gh" = 1 ] && ! command -v gh >/dev/null && use_gh=0

landed() {  # landed BRANCH -> prints the reason and returns 0 when the branch has landed
  local b="$1"
  if git -C "$main_wt" merge-base --is-ancestor "refs/heads/$b" origin/main 2>/dev/null; then
    echo "on origin/main"; return 0
  fi
  if ! git -C "$main_wt" cherry origin/main "refs/heads/$b" 2>/dev/null | grep -q '^+'; then
    echo "every commit's patch is on origin/main"; return 0
  fi
  if [ "$use_gh" = 1 ] && [ -n "$(gh pr list --head "$b" --state merged --json number --jq '.[].number' 2>/dev/null)" ]; then
    echo "PR merged on GitHub"; return 0
  fi
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
    echo "keep   $p $b ($(git -C "$main_wt" rev-list --count "origin/main..refs/heads/$b") commits not on origin/main)"
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
