# Dispatch prompts

One template per stage. Read them from here rather than writing them from memory each time — a
prompt written from memory is where the budget clause and the report cap go missing, and neither
failure is visible until the run is already expensive.

Every template carries two things: **the budget clause** (verbatim from
`~/.claude/GR-references/context-budget.md`) and **a report cap**. Both are below in `<budget>`;
substitute it literally.

```
<budget> =
Context budget: ~200k tokens, per `~/.claude/GR-references/context-budget.md`. Pipe long output
through `tail`/`grep`. When you pass 170k, or when the coordinator asks, finish the step to a
clean point, write the progress file that reference describes, and reply exactly
`handoff written`.

Report in at most ~30 lines. I hold no source files and no logs, so what you leave out is lost.
```

## plan — `GR-tdd` (Opus)

```
Run GR-tdd on part <n> of <spec path>: "<part title>".

The ledger is at <ledger path> — read it first; the rulings in it bind this plan.
Parts <...> have already merged; plan against what is on main now, not against the spec's
description of it.

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

## rebase and gate — `GR-rebase` (Sonnet)

```
Run GR-rebase on <branch> in <repo>.

<Before a PR: rebase onto origin/main and run the full gate.>
<After a predecessor merged: restack with --onto; <predecessor>'s old tip was <sha>.>

Decide the gate by the skill's mechanical rule, not by the size of the diff. The last recorded
gate for this branch was <gate> at branch <sha> against main <sha>.

Write the record to <scratch>/<feature>/ready/ and report which gate ran and why.

<budget>
```

## open and land — `GR-pr` (Sonnet)

```
Run GR-pr on <branch> in <repo>. You are invoked by GR-manage: the PR-text approval gate is mine
and is already satisfied — do not stop for it.

Issue: #<n>. Use `Refs #<n>`, or `Closes #<n>` if this is the last part.
Review digest: <path>. Open topics to quote in the body: <paths, or none>.

Report the PR number as soon as it is open, then continue to landing.

<budget>
```

## fix review comments — `GR-plan-worker` (Sonnet)

```
Apply the review comments on PR #<n> in <repo> that <reviewer> raised, on branch <branch>.

Ledger: <ledger path>. The comments to act on are: <list>.
Where a comment is wrong or out of scope, say so and leave the code alone — a review comment is
not automatically a ruling.

Your definition's escalation triggers and guardrails apply here exactly as they do to plan work.

<budget>
```
