#!/usr/bin/env bash
# Case runner for hooks/branch_guard.py: GUARD-01... Each case feeds the hook
# the PreToolUse JSON for one Bash command and checks the exit code: 0 lets the
# command run, 2 blocks it. Exit 1 if any case fails.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
hook="$here/../../../hooks/branch_guard.py"
failed=0

# case ID WANT COMMAND: run the hook on COMMAND, expect exit WANT.
case_() {
  local id="$1" want="$2" cmd="$3" got
  python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]}}))' "$cmd" \
    | timeout 10 python3 "$hook" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$want" ]; then echo "PASS $id"; else echo "FAIL $id: want $want got $got: $cmd"; failed=1; fi
}

# New branches must start with an issue number.
case_ GUARD-01 0 'git checkout -b 44-autodrive-sim-3 origin/main'
case_ GUARD-02 2 'git checkout -b hl-land origin/main'
case_ GUARD-03 0 'git switch -c 102-agents-knowledge'
case_ GUARD-04 2 'git switch -c d2-data-layout'
case_ GUARD-05 2 'git switch --create gates-vs-benchmarks'
case_ GUARD-06 0 'git branch 3-issue-anchored-scratch origin/main'
case_ GUARD-07 2 'git branch benchmark-command'
case_ GUARD-08 2 'git -C ~/gitroot/GR-roboracer checkout -B f-t0-fix'
case_ GUARD-09 2 'cd repo && git fetch && git checkout -b n1-flakes'
# Branch housekeeping is not creation.
case_ GUARD-10 0 'git branch -D hl-land'
case_ GUARD-11 0 'git branch --merged origin/main'
case_ GUARD-12 0 'git branch -m old new'
case_ GUARD-13 0 'git checkout main'
case_ GUARD-14 0 'git switch hl-land'
# Worktrees: the directory is named after the branch.
case_ GUARD-15 0 'git worktree add -b 44-autodrive-sim-3 .scratch/44-autodrive-sim-3 origin/main'
case_ GUARD-16 2 'git worktree add -b 44-autodrive-sim-7-3b .scratch/autodrive-p7-3b origin/main'
case_ GUARD-17 2 'git worktree add -b p8-wt .scratch/p8-wt origin/main'
case_ GUARD-18 0 'git worktree add .scratch/47-lidar-slam-2'
case_ GUARD-19 2 'git worktree add .scratch/slam-m3'
case_ GUARD-20 0 'git worktree add .scratch/47-lidar-slam-2 47-lidar-slam-2'
case_ GUARD-21 2 'git worktree add .scratch/slam-m3 47-lidar-slam-2'
case_ GUARD-22 0 'git worktree add --detach .scratch/diag origin/main'
case_ GUARD-23 0 'git worktree remove .scratch/p8-wt'
# Not git, or git named only in text.
case_ GUARD-24 0 'ls -la'
case_ GUARD-25 0 'echo "git checkout -b hl-land"'
case_ GUARD-26 0 'git log --oneline -3'
# Unparseable input lets the command run rather than wedging the session.
case_ GUARD-27 0 'echo "unterminated'

exit "$failed"
