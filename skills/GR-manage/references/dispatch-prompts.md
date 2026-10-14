# Dispatch prompts

One template per stage. Read them from here rather than writing them from memory each time — a
prompt written from memory is where the budget clause and the report cap go missing, and neither
failure is visible until the run is already expensive.

Every template carries two things: **the budget clause** (verbatim from
`~/.claude/GR-references/context-budget.md`) and **a report cap**. Both are below in `<budget>`;
substitute it literally.

```
<budget> =
Context budget per `~/.claude/GR-references/context-budget.md`. Pipe long output through
`tail`/`grep`. When the coordinator tells you compaction is no longer effective, finish the step
to a clean point, write the progress file that reference describes, and reply exactly
`handoff written`.

Report in at most ~30 lines. I hold no source files and no logs, so what you leave out is lost.
```

## plan — `GR-tdd` (Opus)

```
Run GR-tdd on part <n> of <spec path>: "<part title>".

The ledger is at <ledger path> — read it first; the rulings in it bind this plan.
Parts <...> this one depends on have merged; plan against what is on main now, not against
the spec's description of it.

Write the plan to <scratch>/<feature>/plans/. Do not implement anything.

<budget>
```

## review the plan — `GR-review` target `plan` (Opus)

```
Run GR-review with target: plan on <plan path>, against part <n> of <spec path>.

You are the approval this plan gets. The owner will not read it before it is implemented, so
check what an owner would: every step test-first and naming the failure it expects before the fix,
no decision settled here that the spec left open, and the plan's Files: set matching the part's.

Ledger: <ledger path>. Write your digest to <scratch>/<feature>/review/.

<budget>
```

## implement — `GR-plan-worker` (Sonnet)

```
Implement part <n> of <plan path>: "<part title>".

Read the ledger at <ledger path> first — it holds the rulings in force.
Branch: <branch>, already created from main.

Your definition holds the escalation triggers and the guardrails. They bind: escalate rather than
decide, and report rather than work around a blocker.

<budget>
```

## review the branch — `GR-review` target `branch` (Opus)

```
Run GR-review with target: branch on <branch> in <repo>.

Ledger: <ledger path>. Write your digest to <scratch>/<feature>/review/ — GR-pr reads it.

<budget>
```

## ready gate — `GR-test-runner` (Sonnet)

```
Run the ready gate on <branch> in <repo>, in the background. The ready gate is the command the
repo's CLAUDE.md names as the rule for done; run exactly that command, with no change to which
tests it selects.

Report: the scope line the gate printed (or "none"), the command, its exit, the full count of
failures, the branch SHA and the main SHA. Pipe the log through tail/grep; I record the row in
<scratch>/<feature>/ready/ myself.

<budget>
```

## open and land — `GR-pr` (Sonnet)

```
Run GR-pr on <branch> in <repo>. You are invoked by GR-manage: the PR-text approval gate is mine
and is already satisfied — do not stop for it.

Issue: #<n>. Use `Refs #<n>`, or `Closes #<n>` if this is the last part.
Review digest: <path>. Open topics to quote in the body: <paths, or none>.

The ready gate started beside you, and its record will be at <scratch>/<feature>/ready/. Open the PR
now; merge per your ready-evidence rule. Report the PR number as soon as it is open, then continue
to landing.

<budget>
```

## resume landing — `GR-pr` (Sonnet)

Use after a red ready gate's fix was committed and the whole gate re-run.

```
Resume landing PR #<n> on <branch> in <repo>. You are invoked by GR-manage; the PR exists, so skip
opening it and go to Phase 2's wait.

A new ready row for this branch will be at <scratch>/<feature>/ready/. Wait for it as you wait for
CI, then merge per your ready-evidence rule.

<budget>
```

## fix review comments — `GR-plan-worker` (Sonnet)

```
Apply the review comments on PR #<n> in <repo> that <reviewer> raised, on branch <branch>.

Ledger: <ledger path>. The comments to act on are: <list>
(or: the ready gate failed at <sha>; the failing output is <...>. Fix it test-first; the
coordinator re-runs the whole gate afterwards, so these commits need no `fixed in` reply).
Queue for the heavy lane: your `--fast` runs the repo's build, so start it only when no ready
run holds the lane.
Where a comment is wrong or out of scope, say so and leave the code alone — a review comment is
not automatically a ruling.

Your definition's escalation triggers and guardrails apply here exactly as they do to plan work.

<budget>
```
