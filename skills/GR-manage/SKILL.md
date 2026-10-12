---
name: GR-manage
disable-model-invocation: true
argument-hint: <path to a spec with a numbered part list>
description: Drive a spec's numbered parts from plan to merged PR without owner input, dispatching one subagent per stage and keeping the run's state in a ledger on disk. Started by the owner with a spec path.
---

# Manage a run

You carry a spec's parts from plan to merged PR. You dispatch every stage and implement none of it.

The run's state lives in `<scratch>/<feature>/run/ledger.md`, **not in this context**. Write it
before each dispatch. A session that holds the run only in memory loses every ruling at its next
compaction, and loses the whole run when it ends — which is the failure this design exists to
prevent.

Read `~/.claude/GR-references/context-budget.md` first: its **Coordinating a run** section is the
four rules you work by, and its **Every dispatch carries the budget** clause goes into every prompt
you send. Quote it; do not restate it.

Prompts for each stage are in [`references/dispatch-prompts.md`](references/dispatch-prompts.md).
The ledger's format is in [`references/ledger.md`](references/ledger.md).

## Phase 0 — adopt the run

Read the spec's part list. Resolve `<feature>` and read or create
`<scratch>/<feature>/run/ledger.md`.

**Resuming is this same phase.** If the ledger exists, continue from it and re-ask nothing — not
the spec path, not which part is next, not a ruling already recorded. A fresh session taking over
from the ledger alone is the normal case, not a recovery mode.

## Phase 1 — the part loop

Per part, in order, one dispatch each:

| Stage | Skill / agent | Model |
|---|---|---|
| plan | `GR-tdd` | Opus |
| review the plan | `GR-review`, `target: plan` | Opus |
| implement | `GR-plan-worker` | Sonnet |
| review the branch | `GR-review`, `target: branch` | Opus |
| ready gate ║ open and land | `GR-test-runner` ║ `GR-pr` | Sonnet |

The plan-review pass replaces the owner's approval of a plan. That is why it is a separate Opus
agent rather than a self-check inside `GR-tdd`: a plan reviewed by its author is approved by nobody.

**Ready gate ║ open and land** is two dispatches in the same turn, once Phase 3's guard passes.
`GR-test-runner` runs the gate the repo's `CLAUDE.md` names as the rule for done and reports the
scope line, exit, branch SHA and `main` SHA; you write the `ready/` row and the ledger row from that
report. `GR-pr` opens the PR at once and merges only on that row (its ready-evidence rule). A missing
row means no merge, so write it.

**A part is planned once every part it depends on has merged**, so it is planned against the code
that actually landed rather than the code that was proposed. An independent part may start while a
PR waits.

**One heavy lane:** one colcon build or ready run at a time. A second in-flight part works in a
worktree (the repo's gotchas name the worktree traps) and queues for the lane. Fix subagents queue
for the lane too, since their `--fast` is a colcon build: a Copilot fix, or a fix after a red ready
gate, waits while a ready run holds it.

## Phase 2 — the nightly boundary

`GR-pr` waits on CI and the Copilot review, off-host, while the heavy lane works another part or
idles. Before dispatching any part's next stage, read the last scheduled run and write the ledger's
`Nightly` line:

```sh
gh run list --repo <owner>/<repo> --event schedule --limit 1 --json databaseId,conclusion,headSha,createdAt,url
```

**A red nightly is a blocking escalation.** Map the failing test IDs to implementations with the
lookup the repo's `testing.md` documents; where it documents none, halt every part. Halt the
in-flight parts whose branch `ready scope:` line names a failing implementation, and any in-flight
part with no such line. Not-yet-started parts queue behind a fix part, which you queue at the head,
and push-notify the owner.

## Phase 3 — the pre-PR guard

Before any PR opens, check `git diff main...HEAD` for:

- `tests/golden/baseline.json`
- `scripts/compare_metrics.py`
- removed asserts
- added skip or `xfail` markers

**Any hit halts the queue.** This check is mechanical and takes no judgement — do not reason about
whether a particular change was justified. A justified one is still recorded as a ruling in the
ledger and named in the PR body before it proceeds; that is the only route past this gate.

The worker is told not to do these things and this catches them anyway. Both layers are deliberate:
the instruction states the intent, the diff is what observes it.

## Rulings

When a stage escalates:

- **Blocking** — the part cannot proceed correctly without a decision. Halt the queue, write the
  question to the ledger, and send the owner a push notification.
- **Otherwise** — write it to `<scratch>/<feature>/open_topics/<date>-<slug>.md` and quote it in the
  PR body, so it reaches the owner at review time instead of stopping the run.

Record every ruling you give in the ledger, with its date and the part it binds, **before** the next
dispatch.

Watch the escalation count. Too few is the failure mode, and it is indistinguishable from a run
going well.

## Wake-up

While waiting you may schedule your own resume (`/loop` dynamic mode). If you end instead, a fresh
session resumes from the ledger — that is the degenerate case of this design working, not a
recovery.

**Local only.** A scheduled cloud agent has no `gr-roboracer-dev` container and cannot run the gate,
so it cannot take a stage of this run. Do not schedule one.

## Done when

- every part in the ledger is `merged`, or carries a written reason it is not;
- every ruling you gave appears in the ledger;
- the ledger's part table names a PR and a merge SHA for each merged part.

A part reported merged with no merge SHA in the ledger is not done — it is unrecorded.
