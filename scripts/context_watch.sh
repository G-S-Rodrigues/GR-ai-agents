#!/usr/bin/env bash
# Watches agent transcripts for a compaction that is not working, and prints
# one line per problem, once per transcript. Compaction itself is normal and
# silent: the plugin or the CLI does it at 20% of the window, near 196k tokens.
#
#   context_watch.sh [--interval S] [--once] [--skip-over]
#                    [--floor N] [--max-compactions N] [--stall N]
#                    [--budget N] <path>...
#
# Each <path> is a transcript (*.jsonl) or a directory of them: a session's
# subagents/ directory, or ~/.claude/projects/<project>/ for peer sessions.
# Directories are rescanned every interval, so agents dispatched after the watch
# started are picked up. Problems already present at startup are reported once,
# so a restart of the watch re-announces them; pass --skip-over to mute them.
#
# Three triggers, all in absolute tokens, so the window size does not matter:
#   ineffective  the first context after a compaction is still >= --floor
#                (default 150000), so the next compaction is close.
#   compacted    the transcript holds --max-compactions (default 5) compactions:
#                a possible loop, not progress.
#   stalled      the context reached --stall (default 240000) with no compaction
#                since it passed 220k, so compaction was skipped or failed.
#
# --budget N switches to the old rule: print once when the context first reaches
# N. Use it where the agent is still told to hand off at a fixed size.
#
# Context size is the last assistant message's
#   input_tokens + cache_read_input_tokens + cache_creation_input_tokens
# which is what the model actually saw on that turn. After a compaction the kept
# messages are replayed with all-zero usage; those records are ignored.
#
# Run under Claude Code's Monitor tool: each printed line is one notification.
# The rules this implements are in references/context-budget.md.
set -euo pipefail

budget="" interval=90 once=0 skip_over=0 floor=150000 max_compactions=5
stall=240000 paths=()
# A non-numeric threshold would make the python in analyze fail, and its failure
# is swallowed, so the watch would look like "everyone under budget".
need_int() {
  [[ $2 =~ ^[0-9]+$ ]] && return 0
  echo "usage: $1 needs a whole number, got ${2:-nothing}" >&2; exit 2
}
while [ $# -gt 0 ]; do
  case "$1" in
    --budget) budget="$2"; shift 2 ;;
    --interval) interval="$2"; shift 2 ;;
    --floor) need_int --floor "${2:-}"; floor="$2"; shift 2 ;;
    --max-compactions) need_int --max-compactions "${2:-}"; max_compactions="$2"; shift 2 ;;
    --stall) need_int --stall "${2:-}"; stall="$2"; shift 2 ;;
    --once) once=1; shift ;;
    --skip-over) skip_over=1; shift ;;
    -h|--help)
      # The leading comment block, without the shebang.
      awk 'NR > 1 { if (/^#/) print; else exit }' "$0"; exit 0 ;;
    *) paths+=("$1"); shift ;;
  esac
done
[ ${#paths[@]} -gt 0 ] || { echo "usage: $0 [--interval S] [--once] [--skip-over] [--floor N] [--max-compactions N] [--stall N] [--budget N] <path>..." >&2; exit 2; }

# The compaction point at 20% is 196k; no normal turn has been seen past 205.5k.
STALL_ARM=220000

analyze() {
  # One pass over the whole file (a single line can exceed 80 KB, so a tail is
  # not enough). Prints tab-separated events in file order, then
  # "current<TAB>N": the last non-zero usage after the last compaction.
  python3 -c '
import json, sys
path, floor, maxc, stall, arm = sys.argv[1], *map(int, sys.argv[2:6])
count = 0
current = 0
pending = None          # preTokens of a compaction awaiting its first real usage
compacted_since_below = False
out = []
with open(path, "rb") as fh:
    for line in fh:
        if b"\"usage\"" not in line and b"compact_boundary" not in line:
            continue
        try:
            r = json.loads(line)
            if not isinstance(r, dict):
                continue
            if (r.get("type") == "system"
                    and r.get("subtype") == "compact_boundary"
                    and isinstance(r.get("compactMetadata"), dict)):
                count += 1
                pending = r["compactMetadata"].get("preTokens", 0)
                compacted_since_below = True
                current = 0
                if count == maxc:
                    out.append("compacted\t%d" % count)
            elif r.get("type") == "assistant":
                u = r["message"]["usage"]
                t = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
                     + u.get("cache_creation_input_tokens", 0))
                if t == 0:
                    continue
                current = t
                if pending is not None:
                    if t >= floor:
                        out.append("ineffective\t%d\t%d" % (t, pending))
                    pending = None
                if t < arm:
                    compacted_since_below = False
                if t >= stall and not compacted_since_below:
                    out.append("stalled\t%d" % t)
        except Exception:
            continue
for o in out:
    print(o)
print("current\t%d" % current)' "$1" "$floor" "$max_compactions" "$stall" "$STALL_ARM" 2>/dev/null || true
}

transcripts() {
  local p
  for p in "${paths[@]}"; do
    if [ -d "$p" ]; then find "$p" -maxdepth 1 -name '*.jsonl' -type f
    elif [ -f "$p" ]; then echo "$p"
    fi
  done
}

describe() {
  # agent-<id>.jsonl has a sibling .meta.json with its description; a session
  # transcript is named by its session id.
  local f="$1" meta="${1%.jsonl}.meta.json" desc=""
  [ -f "$meta" ] && desc=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("description",""))' "$meta" 2>/dev/null || true)
  printf '%s%s' "$(basename "$f" .jsonl)" "${desc:+ ($desc)}"
}

# say FILE KIND MESSAGE: print once per file and kind; mute on the first scan
# when --skip-over is set.
say() {
  local key="$1|$2"
  [ -n "${reported[$key]:-}" ] && return 0
  reported[$key]=1
  if [ "$first" = 1 ] && [ "$skip_over" = 1 ]; then return 0; fi
  echo "$(describe "$1") $3"
}

declare -A reported
first=1
while true; do
  while IFS= read -r f; do
    result=$(analyze "$f")
    if [ -n "$budget" ]; then
      [ -n "${reported[$f|budget]:-}" ] && continue
      t=0
      while IFS=$'\t' read -r kind a b; do
        [ "$kind" = current ] && t="$a"
      done <<< "$result"
      if [ "$t" -ge "$budget" ]; then
        say "$f" budget "crossed ${budget}: ~${t} tokens"
      fi
    else
      while IFS=$'\t' read -r kind a b; do
        case "$kind" in
          ineffective) say "$f" ineffective "compaction ineffective: ~${a} tokens after compacting from ~${b}" ;;
          compacted) say "$f" compacted "compacted ${a} times" ;;
          stalled) say "$f" stalled "at ~${a} tokens, not compacting" ;;
        esac
      done <<< "$result"
    fi
  done < <(transcripts)
  first=0
  [ "$once" = 1 ] && exit 0
  sleep "$interval"
done
