---
name: GR-manage
disable-model-invocation: true
argument-hint: <path to a spec with a numbered part list> | handoff
description: Drive a spec's numbered parts from plan to merged PR without waiting on the owner, dispatching one subagent per stage, timing every owner call out to its recommendation, and keeping the run's state in a ledger on disk. Started by the owner with a spec path; `handoff` passes the run to a fresh session while this one relays its agents' results.
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

The owner is often away. A run that waits on a reply wastes every hour they are gone, so this run
never waits: every call to the owner is **timed** (Owner calls), and a part that truly cannot move
is **parked** while everything else keeps going.

Prompts for each stage are in [`references/dispatch-prompts.md`](references/dispatch-prompts.md).
The ledger's and the report's formats are in [`references/ledger.md`](references/ledger.md).

**`/GR-manage handoff`** — or your own context-budget trigger — runs
[`references/handoff.md`](references/handoff.md) and nothing else in this file: it writes the handoff,
gives the owner the command that starts the successor, and keeps this session open as a relay so the
subagents already running finish instead of dying with it.

## Phase 0 — adopt the run

Read the spec's part list. Resolve `<feature>` and read or create
`<scratch>/<feature>/run/ledger.md`.

Start the watch before the first dispatch: a background `Monitor` running the coordinator command in
`context-budget.md` **Who watches**, over this session's `subagents/` directory and its own transcript. A
line about a subagent: tell it compaction is no longer effective. A line about your own transcript is the
stop in **Coordinating a run**. The successor after a stop is a fresh session, which starts its own watch
since the last one ended with its session. A resumed session under the same id would have its own
past trigger muted by `--skip-over`.

Arm the safety net: a recurring `CronCreate` each hour, at an off-minute, with the prompt
`/GR-manage <spec path> — resume from the ledger`. It fires only while this session sits idle, so it
is what restarts the run after a usage-limit reset or a turn that ended with nothing in flight. It
lives only as long as this session; a successor arms its own.

**Resuming is this same phase.** If the ledger exists, continue from it and re-ask nothing — not
the spec path, not which part is next, not a ruling already recorded. A fresh session taking over
from the ledger alone is the normal case, not a recovery mode. A session started on a handoff file reads it before the ledger, waits on
each landing file its agents table names, and re-dispatches an agent only when that row's fallback
condition holds.

## Phase 1 — the part loop

Per part, in order, one dispatch per stage (the ready gate and `GR-pr` go together):

| Stage | Skill / agent | Model |
|---|---|---|
| plan | `GR-tdd` | Opus |
| review the plan | `GR-review`, `target: plan` | Opus |
| implement | `GR-plan-worker` | Sonnet |
| review the branch | `GR-review`, `target: branch` | Opus |
| ready gate ║ open and land | `GR-test-runner` ║ `GR-pr` | Sonnet |

`GR-tdd` and `GR-review` are dispatched as `subagent_type: GR-general`, and `GR-pr` as
`subagent_type: GR-lander`, each with the model shown.

The plan-review pass replaces the owner's approval of a plan. That is why it is a separate Opus
agent rather than a self-check inside `GR-tdd`: a plan reviewed by its author is approved by nobody.

**Ready gate ║ open and land** is two dispatches in the same turn, once Phase 3's guard passes.
`GR-test-runner` runs the gate the repo's `CLAUDE.md` names as the rule for done and reports the
scope line, exit, branch SHA and `main` SHA; you write the `ready/` row and the ledger row from that
report. `GR-pr` opens the PR at once and merges only on that row (its ready-evidence rule). A
missing row means no merge, so write it.

**A part is planned once every part it depends on has merged**, so it is planned against the code
that actually landed rather than the code that was proposed. An independent part may start while a
PR waits.

**A part the spec did not list** — a fix part, a split, the rework of an overturned call — gets a
sub-issue of the owning issue before its branch exists, and its branch and ledger row carry the
sub-issue's number (`where-documents-go.md` **Issues, branches and worktrees**).

**The last part carries the harvest.** Before its ready gate, dispatch a `GR-general` to run
`where-documents-go.md` **Closing out a feature** on the last part's branch; its verdict table goes
to `run/<date>-harvest.md` for `GR-pr` to quote. The harvest writes the docs and does not commit
them: they are committed-tier, so their commit message goes to the owner through `GR-commit` — the
run's one owner stop before the last ready gate.

**One heavy lane:** one build or ready run at a time. A second in-flight part works in a worktree at
`<repo>/.scratch/<branch>` (the repo's gotchas name the worktree traps) and queues for the lane. Fix subagents queue for the
lane too, since their `--fast` runs the repo's build: a review-comment fix, or a fix after a red
ready gate, waits while a ready run holds it.

## Phase 2 — the nightly boundary

`GR-pr` waits on CI, off-host, while the heavy lane works another part or
idles. Before dispatching any part's next stage, read the last scheduled run and write the ledger's
`Nightly` line:

```sh
gh run list --repo <owner>/<repo> --event schedule --limit 1 --json databaseId,conclusion,headSha,createdAt,url
```

What a red nightly does to the queue is the repo's `CLAUDE.md`'s rule; follow it as written there.

## Phase 3 — the pre-PR guard

Before any PR opens, check `git diff main...HEAD` for:

- `tests/golden/baseline.json`
- `scripts/compare_metrics.py`
- removed asserts
- added skip or `xfail` markers

**Any hit parks that part.** This check is mechanical and takes no judgement — do not reason about
whether a particular change was justified. The hit goes to the owner as a call whose timed default
is to stay parked, so only the owner's own answer passes it; that answer is recorded as a ruling in
the ledger and named in the PR body before the part proceeds.

The worker is told not to do these things and this catches them anyway. Both layers are deliberate:
the instruction states the intent, the diff is what observes it.

## Owner calls

Every decision that is the owner's is asked, and **timed**: it waits five minutes for a reply, then
the run takes the recommendation and goes on. The owner reviews every call taken that way when they
return and overturns what they disagree with — by then with the run's results in hand, which is
more than they had when it was asked.

When a stage escalates, or a decision is the owner's:

1. **Do the legwork before asking.** A bare question comes back as "find the root cause first",
   "what are the pros and cons", "what would a senior robotics engineer do". Do that work now,
   dispatching it if it needs code read or something measured, and say what the competition and the
   real car do. The recommendation may stand unreviewed for hours, so make it one you would ship.
2. **Ask in a message** — the `AskUserQuestion` dialog holds the session until it is answered,
   which is the very block this section removes. Write it for someone arriving cold: what was being
   done, what happened with its numbers, the options, the recommendation and why, and "no reply by
   <time> → I take <recommendation>". Name each test or ID by what it checks. Push-notify the
   one-line question.
3. **Start the timer:** a background `Bash` (`run_in_background`) running `sleep 300`, its
   description naming the call. Keep dispatching while it runs.
4. **Settle it.** A reply before the timer is a ruling. A timer that fires unanswered makes the
   recommendation a **provisional call**: record it in the ledger's Rulings and the report's calls
   table, then carry on. An overturned provisional call becomes a ruling, and the work it changes
   becomes a fix part at the head of the queue.

A timed default **parks the part** instead of proceeding when the call needs the owner's hands (a
physical action, another machine, a credential) or comes from the pre-PR guard.

Standing recommendation: a ready gate red only on a test that also goes red on `main` at a similar
rate — shown by an A/B run of that test on both — is merged and tracked, the flake written up as an
open topic.

A question the part can proceed without goes to `<scratch>/<feature>/open_topics/<date>-<slug>.md`
and is quoted in the PR body, so it reaches the owner at review time.

Record every ruling and provisional call in the ledger, with its date and the part it binds,
**before** the next dispatch.

Watch the escalation count. Too few is the failure mode, and it is indistinguishable from a run
going well.

## When a part parks

Dispatch, in the same turn, everything that does not depend on the parked part, in this order:

1. other parts whose dependencies have merged;
2. plans and plan reviews for later parts (a plan built on a provisional call says so);
3. the legwork for parked calls;
4. open topics and docs the run owes.

When nothing in this spec can move, **move on** to the next item in the owner's queue — the order
the repo's `CLAUDE.md` or the session's memory gives. Adopt it as its own run (Phase 0, its own
ledger and report), and write the move as the last row of this run's report. If that item has no
spec in numbered parts, dispatch a draft of one to `<scratch>/<feature>/spec/` for the owner and
stop there. With no queue named, push-notify and stop. One run is worked at a time, and the heavy
lane spans both.

## The report

`<scratch>/<feature>/run/report.md` is how the owner catches up without interrupting the run: what
is in flight now, what waits on them, what was implemented and the calls taken without them, in
plain words (format in [`references/ledger.md`](references/ledger.md)). Rewrite its **Now** at every
dispatch and every return; update the rest whenever a part changes state or a call settles, and name
it in every push notification. It is complete when the owner, reading it alone in a minute, could
tell what is running, what changed, what was decided for them, and what to answer.

## Never end a turn idle

A turn ends only while something in flight will wake you: a background subagent, a `Monitor` or a
call's timer. The safety net catches a turn that broke this rule; it is never the reason to end one.
Waiting for the owner is never the reason either: if nothing is in flight, there is undispatched work
under **When a part parks**. On a stop (done, or out of work after moving on), delete the safety net
with `CronDelete`, update the report and push-notify. The context-budget stop is the handoff instead
(`references/handoff.md`), because agents still in flight would die with an ended session.

**Local only.** A scheduled cloud agent has no `gr-roboracer-dev` container and cannot run the gate,
so it cannot take a stage of this run. Do not schedule one.

## Done when

- every part in the ledger is `merged`, or carries a written reason it is not;
- every ruling and provisional call appears in the ledger, and every provisional call in the
  report's calls table;
- the ledger's part table names a PR and a merge SHA for each merged part;
- the last part's PR quotes the harvest verdicts, and the owning issue is closed.

A part reported merged with no merge SHA in the ledger is not done — it is unrecorded.

When all of these hold, report to the owner, then post `run/report.md`'s calls table as a comment
on the owning issue (`gh issue comment <n> --repo <owner>/<repo> --body-file <file>`) — provisional
calls the owner has not vetoed yet must outlive the folder — and only then delete
`<scratch>/<feature>/`: the last PR's harvest moved the rest.
