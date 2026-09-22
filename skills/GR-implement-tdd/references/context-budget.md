# Context budget and handoff

An implementing agent's context budget is **~200k tokens**. Past that, answers get worse before
auto-compaction ever triggers, and auto-compaction drops the details a plan run depends on (which
hypothesis was already ruled out, which command actually worked). A deliberate handoff keeps them.

## Who watches

A running agent cannot compact itself on demand, and a subagent cannot be compacted from outside.
So the **coordinator** — the session that dispatched the implementing agent — owns the budget:

- Read each subagent's current context size from the `usage` of the last assistant message in its
  transcript (`input_tokens + cache_read_input_tokens + cache_creation_input_tokens`). A background
  `Monitor` that prints once per agent when it crosses the budget does this without polling by hand.
- When an agent crosses the budget, message it to hand off. When it replies `handoff written`,
  dispatch a fresh agent pointed at the progress file and the plan, with the same rules the first one
  had.

An agent running this skill with no coordinator watches itself the same way: when it notices it is
near the budget, it hands off unprompted.

## Keeping the budget

Every command whose output is not needed in full goes through `tail`, `grep`, or `-q`. A full log
read inline costs more than the step it came from — that is what `run_tests_summary.sh` and the
`test-failure-triage` subagent are for.

## The handoff

1. Finish the current step to a clean point — tests green and committed. If the step is far from
   done, commit nothing half-made; leave it uncommitted and describe it.
2. Write the progress file beside the plan (path in `where-documents-go.md`), under ~150 lines:
   - steps completed, each with its commit SHA;
   - the current step — what is done, what is left, every uncommitted file and its state;
   - findings, measurements and deviations so far, with why;
   - open problems and **dead ends already tried**, so the next agent does not repeat them;
   - the exact commands that worked (container, source line, single-test invocation).
3. Stop and reply `handoff written`. Do not start the next step.

## Resuming

A fresh agent reads the progress file **before** the plan's steps and trusts it: it does not redo
what it lists as done, and it keeps it current as it goes, so the next handoff is an edit rather
than a rewrite.
