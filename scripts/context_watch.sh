#!/usr/bin/env bash
# Prints one line per agent transcript the first time its context crosses a
# threshold: by default 170k, the point to ask an agent to hand off so it can
# finish its step under the 200k ceiling.
#
#   context_watch.sh [--budget N] [--interval S] [--once] <path>...
#
# Each <path> is a transcript (*.jsonl) or a directory of them — a session's
# subagents/ directory, or ~/.claude/projects/<project>/ for peer sessions.
# Directories are rescanned every interval, so agents dispatched after the watch
# started are picked up. Transcripts already over budget at startup are reported
# once, so a restart of the watch re-announces them; pass --skip-over to mute them.
#
# Context size is the last assistant message's
#   input_tokens + cache_read_input_tokens + cache_creation_input_tokens
# which is what the model actually saw on that turn.
#
# Run under Claude Code's Monitor tool: each printed line is one notification.
# The rules this implements are in references/context-budget.md.
set -euo pipefail

budget=170000 interval=90 once=0 skip_over=0 paths=()
while [ $# -gt 0 ]; do
  case "$1" in
    --budget) budget="$2"; shift 2 ;;
    --interval) interval="$2"; shift 2 ;;
    --once) once=1; shift ;;
    --skip-over) skip_over=1; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) paths+=("$1"); shift ;;
  esac
done
[ ${#paths[@]} -gt 0 ] || { echo "usage: $0 [--budget N] [--interval S] [--once] <path>..." >&2; exit 2; }

context_of() {
  # The tail is enough: only the last message with usage matters.
  tail -c 60000 "$1" | python3 -c '
import json, sys
tot = 0
for line in sys.stdin:
    try:
        u = json.loads(line)["message"]["usage"]
    except Exception:
        continue
    tot = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
           + u.get("cache_creation_input_tokens", 0))
print(tot)' 2>/dev/null || echo 0
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

declare -A reported
first=1
while true; do
  while IFS= read -r f; do
    [ -n "${reported[$f]:-}" ] && continue
    t=$(context_of "$f")
    if [ "$t" -ge "$budget" ]; then
      reported[$f]=1
      if [ "$first" = 1 ] && [ "$skip_over" = 1 ]; then continue; fi
      echo "$(describe "$f") crossed ${budget}: ~${t} tokens"
    fi
  done < <(transcripts)
  first=0
  [ "$once" = 1 ] && exit 0
  sleep "$interval"
done
