# Context budget: 200k tokens per agent

Every agent — a session working alone, a coordinator, and every subagent or peer session a
coordinator dispatches — works to a **200k-token context ceiling**. Past it, answers get worse
before auto-compaction ever triggers. Auto-compaction also drops the details long work depends on:
which hypothesis was already ruled out, which command actually worked. A deliberate handoff keeps
them.

No setting enforces this. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` is a percentage of the model's window,
and whether it reaches Agent-tool subagents is undocumented. The budget is a process, and this file
is that process.

## The numbers

- **Context size** is the last assistant message's `usage`:
  `input_tokens + cache_read_input_tokens + cache_creation_input_tokens`.
- **170k: ask for the handoff.** The agent still has to finish its step to a clean point. Two plan
  runs asked at 200k overshot to 231k and 250k doing exactly that.
- **200k: the ceiling.** An agent past it hands off at once, even mid-step (see the handoff below
  for what to do with half-made work).
- A coordinator may ask earlier, at a clean step boundary, when most of the work is still ahead. It
  says why in the message.

## Who watches

| The agent is... | Watched by | Transcript |
|---|---|---|
| an Agent-tool subagent | the coordinator that dispatched it — a subagent cannot be compacted from outside | `~/.claude/projects/<project>/<coordinator-session>/subagents/agent-<id>.jsonl` |
| a peer session (its own desktop or terminal session, reached with `SendMessage`) | the coordinator driving it | `~/.claude/projects/<project>/<session-id>.jsonl` |
| a session with no coordinator | itself | its own transcript, or the status line |

`<project>` is the working directory with every `/` replaced by `-`. A peer's session id is in
`~/.claude/sessions/*.json`, next to the `name` it shows in the sidebar.

A coordinator watches with a background `Monitor` running `scripts/context_watch.sh` from the
GR-ai-agents checkout, found through the installed references link. It prints one line per
transcript when that transcript first crosses the threshold, so a quiet watch means everyone is
under budget:

```sh
"$(dirname "$(readlink -f ~/.claude/GR-references)")"/scripts/context_watch.sh --skip-over \
  ~/.claude/projects/<project>/<coordinator-session>/subagents \
  ~/.claude/projects/<project>/<peer-session-id>.jsonl
```

Directories are rescanned, so subagents dispatched later are picked up. `--skip-over` mutes agents
that were already over at startup, i.e. ones already handled before a restart. `--budget 200000`
watches the ceiling instead. `--once` checks one time and exits.

On a line from the watch: message that agent to hand off. When it replies `handoff written`,
dispatch a fresh agent pointed at the progress file, with the same rules and rulings the first one
had. The coordinator watches its own context too, and hands off the same way.

## Every dispatch carries the budget

A dispatched agent has not read this file unless its prompt points here. Every dispatch prompt
includes:

> Context budget: ~200k tokens, per `~/.claude/GR-references/context-budget.md`. Pipe long output
> through `tail`/`grep`. When you pass 170k, or when the coordinator asks, finish the step to a
> clean point, write the progress file that reference describes, and reply exactly
> `handoff written`.

## Keeping the budget

Every command whose output is not needed in full goes through `tail`, `grep`, or `-q`. A full log
read inline costs more than the step it came from. That is what `tail`, `run_tests_summary.sh`
(where the repo runs `run_tests.sh`) and the `test-failure-triage` subagent are for. Fan-out reads
go to `Explore` or `GR-researcher`, which return conclusions rather than file dumps.

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
