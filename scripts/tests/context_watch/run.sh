#!/usr/bin/env bash
# Fixture runner for scripts/context_watch.sh: WATCH-01..20. Each case runs the
# watch (--once unless it drives the live loop), and its stdout is diffed
# against expected/<ID>.out. Exit 1 if any case fails.
#
# Provenance: every compact_boundary line in fixtures/ is a real record,
# verbatim except WATCH-07, whose preTokens is edited to 236000: agent-a52fb2ec0e09c39c0 (the 2026-10-14 route-(b) live test reader,
# sessionId c5fb1ffb) lines 46/102/165/231/310; session 2045aabb line 742; session
# cb807bc9 line 842. Assistant lines are real lines 43 and 58 of the reader with
# the content cut to one short text block and the usage edited to the scenario's
# value. Line 58 is the zero-usage replay that follows every boundary.
# fixtures/<ID>.jsonl is named for the case so the watch prints <ID> as the agent.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
watch="$here/../../context_watch.sh"
fx="$here/fixtures"
tmp=$(mktemp -d)
bgpid=""
# shellcheck disable=SC2317  # invoked by the EXIT trap
cleanup() {
  [ -n "$bgpid" ] && kill "$bgpid" 2>/dev/null
  rm -rf "$tmp"
}
trap cleanup EXIT
failed=0

# w ARGS: run the watch. A non-zero exit (a hang killed by timeout is 124) is
# appended as "rc=N", so a case that expects empty output cannot pass on it.
w() {
  local out rc
  out=$(timeout 10 bash "$watch" "$@" 2>&1); rc=$?
  [ -z "$out" ] || printf '%s\n' "$out"
  [ "$rc" -eq 0 ] || printf 'rc=%s\n' "$rc"
}

# check ID ACTUAL: compare with expected/ID.out and print PASS or FAIL.
check() {
  local id="$1" actual="$2"
  if [ "$actual" = "$(cat "$here/expected/$id.out")" ]; then
    echo "PASS $id"
  else
    echo "FAIL $id"
    echo "--- expected"; cat "$here/expected/$id.out"
    echo "--- actual"; printf '%s\n' "$actual"
    failed=1
  fi
}

check WATCH-01 "$(w --once "$fx/WATCH-01.jsonl")"
check WATCH-02 "$(w --once "$fx/WATCH-02.jsonl")"
check WATCH-03 "$(w --once "$fx/WATCH-03.jsonl")"
check WATCH-04 "$(w --once "$fx/WATCH-04.jsonl")"
check WATCH-05 "$(w --once "$fx/WATCH-05.jsonl")"
check WATCH-06 "$(w --once "$fx/WATCH-06.jsonl")"
check WATCH-07 "$(w --once "$fx/WATCH-07.jsonl")"
check WATCH-08 "$(w --once "$fx/WATCH-08.jsonl")"
check WATCH-09 "$(w --once --skip-over "$fx/WATCH-04.jsonl" "$fx/WATCH-06.jsonl")"
check WATCH-10 "$(w --once --budget 170000 "$fx/WATCH-10.jsonl")"

# WATCH-11: an 80,000-byte line after the last usage, longer than the old tail.
mkdir "$tmp/11"
cp "$fx/WATCH-11.jsonl" "$tmp/11/WATCH-11.jsonl"
python3 -c 'import json; print(json.dumps({"type":"attachment","x":"a"*80000}))' \
  >> "$tmp/11/WATCH-11.jsonl"
check WATCH-11 "$(w --once --budget 170000 "$tmp/11/WATCH-11.jsonl")"

check WATCH-12 "$(w --once --budget 170000 "$fx/WATCH-12.jsonl")"
check WATCH-13 "$(w --once "$fx/WATCH-13.jsonl")"
check WATCH-14 "$(w --once "$fx/WATCH-14.jsonl")"

# WATCH-15: the description comes from the sibling .meta.json.
mkdir "$tmp/15"
cp "$fx/WATCH-02.jsonl" "$tmp/15/agent-a52fb2ec0e09c39c0.jsonl"
cp "$fx/agent-a52fb2ec0e09c39c0.meta.json" "$tmp/15/"
check WATCH-15 "$(w --once "$tmp/15/agent-a52fb2ec0e09c39c0.jsonl")"

check WATCH-16 "$( { w --once --floor 100000 "$fx/WATCH-01.jsonl"
  w --once --max-compactions 4 "$fx/WATCH-03.jsonl"
  w --once --stall 250000 "$fx/WATCH-06.jsonl"; } )"
check WATCH-17 "$(w --once "$fx/WATCH-17.jsonl")"

# WATCH-18: the live loop. A file that ends in zero-usage replays, then gets its
# first real usage appended; then a new file appears.
mkdir "$tmp/18"
cp "$fx/WATCH-05.jsonl" "$tmp/18/a.jsonl"
bash "$watch" --interval 1 "$tmp/18" > "$tmp/18.out" 2>&1 &
bgpid=$!
sleep 2
python3 - "$fx/WATCH-02.jsonl" "$tmp/18/a.jsonl" <<'PY'
import sys
last = open(sys.argv[1]).read().splitlines()[-1]
open(sys.argv[2], "a").write(last + "\n")
PY
sleep 2   # a poll must see the append before b exists, so the order is fixed
cp "$fx/WATCH-06.jsonl" "$tmp/18/b.jsonl"
sleep 3
kill "$bgpid" 2>/dev/null; wait "$bgpid" 2>/dev/null; bgpid=""
check WATCH-18 "$(cat "$tmp/18.out")"

# WATCH-19: no paths, and --help.
out19=""
timeout 10 bash "$watch" >/dev/null 2>&1; out19="noargs exit $?"
help=$(timeout 10 bash "$watch" --help 2>&1); rc=$?
out19="$out19"$'\n'"help exit $rc"
for flag in --floor --max-compactions --stall --budget; do
  if printf '%s\n' "$help" | grep -q -- "$flag"; then
    out19="$out19"$'\n'"help mentions $flag"
  fi
done
check WATCH-19 "$out19"

# WATCH-20: a non-numeric threshold is a usage error, not a silent watch.
out20=""
for flag in --floor --stall --max-compactions; do
  msg=$(timeout 10 bash "$watch" --once "$flag" 240k "$fx/WATCH-01.jsonl" 2>&1 >/dev/null); rc=$?
  out20="$out20${out20:+$'\n'}$flag exit $rc: ${msg%%$'\n'*}"
done
check WATCH-20 "$out20"

exit "$failed"
