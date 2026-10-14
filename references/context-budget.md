# Context budget: hand off when compaction stops working

Every agent — a session working alone, a coordinator, and every subagent or peer session a
coordinator dispatches — keeps working through compactions. It hands off only when compaction has
stopped working, and a watch outside the agent is what notices. A deliberate handoff keeps what
long work depends on: which hypothesis was already ruled out, which command actually worked.

## Compaction is Jev pruning, not a summary

Compaction is the `fast-jev-compaction` plugin, our fork, installed by `scripts/install.sh`.
TypeSafe's Jev scores every old tool call and result; a stale call is dropped with its result, a
stale result is cut to its first 300 characters, and everything kept stays verbatim. User and
assistant text is never removed. The first message and the last 2 are always kept.

- **It fires at 20% of the window**, in every session and every subagent. On a 1M window that is
  about 196k for the CLI's own trigger and 200,000 tokens for the plugin's; real fires landed at
  193–223k, because a step can add a large chunk before the check runs.
- **The built-in summary never runs.** With `onFallback: "skip"`, a Jev failure or too small a
  reduction compacts nothing, and the context keeps growing until the watch reports it stalled.
- **Text survives; tool output may not.** Write a finding, a ruling or the command that worked into
  a message as you go. One left only in a tool result can be pruned.
- **A pruned result is re-run, not recalled.** A truncated read or log means re-read it.

Settings live in `~/.claude/settings.json`, as the lines `scripts/install.sh` prints from
`plugins/fast-jev-compaction.settings.json`: `pluginConfigs` with `compactAtPercent: 20`,
`onFallback: "skip"` and `preserveRecentMessages: 2`, and in `env`
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=20`, `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` and `TYPESAFE_API_KEY`.
The override is what makes subagents compact: an Agent-tool subagent compacts only through the CLI's
native auto-compaction, whose default on a 1M window is about 967k, and the plugin prunes whatever
that triggers. The override is process-wide, so the main session gets the same 20%. Every
compaction sends the conversation (not tool results) to `api.typesafe.ai`.

## When compaction has stopped working

**Context size** is the last assistant message's `usage`:
`input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.

Compaction itself needs no action. Any one of three triggers means it has stopped working, and the
agent hands off:

| Trigger | Condition | What it means |
|---|---|---|
| ineffective | the first context after a compaction is still >= 150k | the next compaction is close, with too little room left to finish a step |
| count | the 5th compaction | a possible loop, not progress |
| stalled | >= 240k with no compaction since the context passed 220k | Jev is failing or skipping |

The thresholds are absolute tokens, so a model's window does not change them.

## Who watches

| The agent is... | Watched by | Transcript |
|---|---|---|
| an Agent-tool subagent | the coordinator that dispatched it | `~/.claude/projects/<project>/<coordinator-session>/subagents/agent-<id>.jsonl` |
| a peer session (its own desktop or terminal session, reached with `SendMessage`) | the coordinator driving it | `~/.claude/projects/<project>/<session-id>.jsonl` |
| a coordinator | itself, in the same watch as its subagents | `~/.claude/projects/<project>/<coordinator-session>.jsonl` |
| a long-lived session with no coordinator | itself, in its own background `Monitor` | `~/.claude/projects/<project>/<session-id>.jsonl` |

An agent a coordinator dispatched runs no watch: it acts on the coordinator's message.
`<project>` is the working directory with every `/` replaced by `-`. A session's own id is
`$CLAUDE_CODE_SESSION_ID` (a subagent inherits its coordinator's), so its own transcript is
`~/.claude/projects/<project>/$CLAUDE_CODE_SESSION_ID.jsonl`, and a coordinator's
`<coordinator-session>` is that id. Where the variable is unset, the newest transcript stands in
(`ls -t ~/.claude/projects/<project>/*.jsonl | head -1`); it can be another session's when several
share a project. A peer's session id is in `~/.claude/sessions/*.json`, next to the `name` it shows
in the sidebar.

The watch is `scripts/context_watch.sh` from the GR-ai-agents checkout, found through the installed
references link, run in a background `Monitor`. A coordinator watches its subagents, its peers and
its own transcript:

```sh
"$(dirname "$(readlink -f ~/.claude/GR-references)")"/scripts/context_watch.sh --skip-over \
  ~/.claude/projects/<project>/$CLAUDE_CODE_SESSION_ID/subagents \
  ~/.claude/projects/<project>/$CLAUDE_CODE_SESSION_ID.jsonl \
  ~/.claude/projects/<project>/<peer-session-id>.jsonl
```

A long-lived session with no coordinator watches its own transcript:

```sh
"$(dirname "$(readlink -f ~/.claude/GR-references)")"/scripts/context_watch.sh \
  ~/.claude/projects/<project>/$CLAUDE_CODE_SESSION_ID.jsonl
```

It prints one line per trigger per transcript, once, so a quiet watch means compaction is working
everywhere. Directories are rescanned, so subagents dispatched later are picked up. `--skip-over`
mutes problems already present at startup, i.e. ones already handled before a restart. `--once`
checks one time and exits, for a one-off check rather than a watch. `--floor`, `--max-compactions`
and `--stall` move the three thresholds. `--budget N` brings back the old rule, one line when the
context first reaches N, for an agent still told to hand off at a fixed size.

On a line about another agent: message it that compaction is no longer effective for it, quoting
the line. When it replies `handoff written`, dispatch a fresh agent pointed at the progress file,
with the same rules and rulings the first one had. On a line about your own transcript: a
coordinator stops (**Coordinating a run**); a session with no coordinator does the handoff below,
push-notifies the owner and ends, and the owner opens a fresh session that resumes from the
progress file.

## Every dispatch carries the budget

The clause tells the agent the reply the coordinator waits for, and the dispatch prompt is the
only place a subagent is guaranteed to see it. Every dispatch prompt includes:

> Context budget per `~/.claude/GR-references/context-budget.md`. Pipe long output through
> `tail`/`grep`. When the coordinator tells you compaction is no longer effective, finish the step
> to a clean point, write the progress file that reference describes, and reply exactly
> `handoff written`.

## Coordinating a run

A coordinator that drives a multi-part run lasts longer than any agent in it, so it spends its
context differently: it holds the shape of the run and nothing else. Four rules do that work.

- **Read no source file and no test log.** Every detail stays in the subagent that produced it. A
  coordinator that opens a failing test to see for itself has become a worker, and it compacts
  away the run to make room for the file.
- **Cap every report at ~30 lines**, in the dispatch prompt. An uncapped subagent returns what it
  found interesting, which is the whole file.
- **Write to the ledger before the next dispatch** — every ruling, commit SHA, worker name and open
  topic, never only in the reply. A subagent's report is a tool result, and Jev may prune it at the
  next compaction; a ruling is the expensive kind to lose.
- **On your own trigger, stop.** Write the ledger, push-notify the owner, and end the session. A
  coordinator cannot start its own successor, so the ledger is what the next one resumes from —
  which is the whole reason it is complete rather than tidy.

## Keeping the budget

Every command whose output is not needed in full goes through `tail`, `grep`, or `-q`. A full log
read inline costs more than the step it came from. That is what `tail`, `grep` and the
`test-failure-triage` subagent are for. Fan-out reads go to `Explore` or `GR-researcher`, which
return conclusions rather than file dumps.

## The handoff

1. Finish the current step to a clean point: tests green and committed. If the step is far from
   done, commit nothing half-made. Leave it uncommitted and describe it.
2. Write the progress file, under ~150 lines. For plan work it sits beside the plan as
   `<plan>-progress.md` (path in `where-documents-go.md`); otherwise it goes in the feature's
   `<scratch>/<feature>/` directory. It holds:
   - steps completed, each with its commit SHA;
   - the current step: what is done, what is left, every uncommitted file and its state;
   - findings, measurements and deviations so far, with why;
   - rulings received from the coordinator or the user that are still in force;
   - open problems and **dead ends already tried**, so the next agent does not repeat them;
   - the exact commands that worked (container, source line, single-test invocation).
3. Stop and reply `handoff written`. Do not start the next step.

## Resuming

A fresh agent reads the progress file **before** anything else in the task and trusts it. It does
not redo what the file lists as done, and it keeps the file current as it goes, so the next handoff
is an edit rather than a rewrite.
