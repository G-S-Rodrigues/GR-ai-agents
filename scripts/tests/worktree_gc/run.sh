#!/usr/bin/env bash
# Case runner for scripts/worktree_gc.sh: GC-01... Builds a throwaway origin and clone with one
# worktree per situation, runs the sweep against a stub gh, and checks each worktree's verdict line and,
# under --remove, that only the removable ones are gone. Exit 1 if any case fails.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
gc="$here/../../worktree_gc.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
failed=0
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null 2>&1; }

g init --bare "$tmp/origin.git"
g clone "$tmp/origin.git" "$tmp/repo"
r="$tmp/repo"
printf 'build/\n' >"$r/.gitignore"; echo a >"$r/a"; g -C "$r" add -A; g -C "$r" commit -m base; g -C "$r" push origin main

# A stub gh answers `pr list --head <b>` with
# the head SHAs listed in $tmp/gh/<b>.
mkdir -p "$tmp/bin" "$tmp/gh"
cat >"$tmp/bin/gh" <<EOF
#!/usr/bin/env bash
while [ \$# -gt 0 ]; do [ "\$1" = --head ] && { cat "$tmp/gh/\$2" 2>/dev/null; exit 0; }; shift; done
EOF
chmod +x "$tmp/bin/gh"
merged() { git -C "$r" rev-parse "$1" >>"$tmp/gh/$1"; }  # record a merged PR at the tip

wt() { g -C "$r" worktree add -b "$1" "$r/.scratch/$1" origin/main; }
commit() { echo "$2" >"$r/.scratch/$1/$3"; g -C "$r/.scratch/$1" add -A; g -C "$r/.scratch/$1" commit -m "$2"; }

wt 1-merged;     commit 1-merged one f1; merged 1-merged       # PR merged, fast-forwarded into main
wt 2-squashed;   commit 2-squashed two f2; merged 2-squashed   # PR squash-merged
wt 3-unmerged;   commit 3-unmerged three f3                   # never landed
wt 4-dirty;      commit 4-dirty four f4; merged 4-dirty; echo x >"$r/.scratch/4-dirty/f4"   # landed, edited since
wt 5-untracked;  echo x >"$r/.scratch/5-untracked/new"        # nothing ahead, untracked file
wt 6-built;      commit 6-built six f6; merged 6-built; mkdir -p "$r/.scratch/6-built/build"; echo o >"$r/.scratch/6-built/build/o"  # landed, ignored output only
wt 7-empty                                                     # fresh part, nothing committed yet
wt 10-nopr;      commit 10-nopr ten f10                       # landed by hand, no PR

g -C "$r" merge --ff-only 1-merged
g -C "$r" cherry-pick 2-squashed
g -C "$r" cherry-pick 4-dirty
g -C "$r" cherry-pick 6-built
g -C "$r" merge --ff-only 10-nopr 2>/dev/null || g -C "$r" cherry-pick 10-nopr
g -C "$r" push origin main
g -C "$r" fetch origin

out=$(cd "$r" && PATH="$tmp/bin:$PATH" bash "$gc" 2>&1)

# expect ID BRANCH VERDICT: the sweep printed VERDICT for BRANCH.
expect() {
  if grep -qE "^$3 +\S*/$2 " <<<"$out"; then echo "PASS $1"; else echo "FAIL $1: want '$3' for $2"; failed=1; fi
}
expect GC-01 1-merged    remove
expect GC-02 2-squashed  remove
expect GC-03 3-unmerged  keep
expect GC-04 4-dirty     keep
expect GC-05 5-untracked keep
expect GC-06 6-built     remove
expect GC-07 7-empty     keep
expect GC-15 10-nopr     keep
if grep -q 'main' <<<"$(grep -E '^(remove|keep)' <<<"$out" | grep -E " $r " )"; then
  echo "FAIL GC-08: the main checkout was listed"; failed=1
else echo "PASS GC-08"; fi

# Dry run by default: nothing removed yet.
if [ -d "$r/.scratch/1-merged" ]; then echo "PASS GC-09"; else echo "FAIL GC-09: dry run removed a worktree"; failed=1; fi

(cd "$r" && PATH="$tmp/bin:$PATH" bash "$gc" --remove >/dev/null 2>&1)
for b in 1-merged 2-squashed 6-built; do
  if [ -d "$r/.scratch/$b" ] || git -C "$r" rev-parse -q --verify "refs/heads/$b" >/dev/null; then
    echo "FAIL GC-10: $b still present"; failed=1
  fi
done
for b in 3-unmerged 4-dirty 5-untracked 7-empty 10-nopr; do
  if [ ! -d "$r/.scratch/$b" ]; then echo "FAIL GC-11: $b was removed"; failed=1; fi
done
[ "$failed" = 0 ] && echo "PASS GC-10" && echo "PASS GC-11"

wt 8-reused;    commit 8-reused eight f8; merged 8-reused
commit 8-reused eight-more f8b                                 # committed after its PR merged
wt 9-ghmerged;  commit 9-ghmerged nine f9; commit 9-ghmerged nine-b f9b
merged 9-ghmerged                                              # squash-merged at this tip
out=$(cd "$r" && PATH="$tmp/bin:$PATH" bash "$gc" 2>&1)
expect GC-12 8-reused   keep
expect GC-13 9-ghmerged remove

# With no origin/main to judge against, nothing is removed and the sweep says why.
git -c init.defaultBranch=master init -q --bare "$tmp/o2.git"
git clone -q "$tmp/o2.git" "$tmp/r2" 2>/dev/null
echo a >"$tmp/r2/a"; g -C "$tmp/r2" add -A; g -C "$tmp/r2" commit -m base; g -C "$tmp/r2" push origin HEAD:master
g -C "$tmp/r2" fetch origin
g -C "$tmp/r2" worktree add -b 1-work "$tmp/r2/.scratch/1-work" origin/master
echo w >"$tmp/r2/.scratch/1-work/w"; g -C "$tmp/r2/.scratch/1-work" add -A; g -C "$tmp/r2/.scratch/1-work" commit -m work
out2=$(cd "$tmp/r2" && PATH="$tmp/bin:$PATH" bash "$gc" --remove 2>&1); rc=$?
if [ "$rc" != 0 ] && [ -d "$tmp/r2/.scratch/1-work" ] && grep -q 'origin/main' <<<"$out2"; then echo "PASS GC-14"
else echo "FAIL GC-14: rc=$rc, worktree $( [ -d "$tmp/r2/.scratch/1-work" ] && echo kept || echo removed): $out2"; failed=1; fi

[ "$failed" = 0 ] || printf -- '--- sweep output ---\n%s\n' "$out"
exit "$failed"
