# The ledger

One file per run: `<scratch>/<feature>/run/ledger.md`.

**The rule that decides every question about it: a fresh session must be able to take over from this
file with nothing else.** Not the spec, not a transcript, not the session that wrote it. That is
what makes a resident coordinator optional rather than load-bearing — and it is why the ledger is
kept *complete* rather than tidy. A detail you leave out because it seemed obvious in context is
gone, because the context is what gets lost.

It lives outside every repo working tree, so a `git clean -xdf` inside a repo cannot reach it.

## Format

```markdown
# Run: <feature>

Spec: <path>
Started: <date>
Last written: <date> by <session or agent name>

## Parts

| # | Title | Branch | State | PR | Merge SHA |
|---|---|---|---|---|---|
| 1 | <title> | <branch> | merged | #<n> | <sha> |
| 2 | <title> | <branch> | in progress | — | — |
| 3 | <title> | <branch> | not started | — | — |

Nightly: <run id>, main <sha>, <pass | fail>, <date> — last scheduled run read before a dispatch

## Current

One block per in-flight part (an independent part may start while a PR waits).

Part: <n>
Stage: <plan | review-plan | implement | review-branch | ready+pr>
Worker: <agent name / id, so its transcript can be found; two at `ready+pr`: the runner and GR-pr>
Started: <timestamp>
Branch head: <sha, or "no commits yet">
Done so far: <the commits on this branch, one line each, and what is left>
Last reported: <the worker's last report in a line or two — including any measurement that
prompted an escalation, and whether it predates or postdates a fix attempt>

## Rulings

- **<date>, part <n>** — <the question that was raised>
  **Ruling:** <what was decided> — <why, in one line>
- **<date time>, part <n>** — <the question that was raised>
  **Provisional call** (no reply in 5 min): <the recommendation taken> — <why> — report call #<k>

## Gate results

| Part | Branch SHA | main SHA | Gate | Scope | Result |
|---|---|---|---|---|---|
| 1 | <sha> | <sha> | `<the ready gate command>` | <scope line> | fail — <test ID> |
| 1 | <sha> | <sha> | `<ready gate command>` | <scope line> | pass — whole gate re-run after fix |

## Open topics

- [<date>-<slug>](../open_topics/<date>-<slug>.md) — <one line>, quoted in PR #<n>
```

## What each part earns its place for

- **The part table** is the run. `State` is one of `not started`, `in progress`, `parked`,
  `merged`. `parked` always has a call below it saying what on.
- **Current** is what a resuming session needs to know it is mid-stage rather than between stages.
  The worker name matters: a handoff or a context-budget line is traced through it. **`Branch head`,
  `Done so far` and `Last reported` are what stop the next session having to go and read the branch
  to find out where the last one got to** — the moment it has to do that, this file has stopped being
  sufficient and the rule above is broken. A measurement that caused an escalation goes in
  `Last reported` with its date, because "the estimator came in at 0.012" is useless if nobody can
  tell whether that was before or after someone tried to fix it.
  At `ready+pr` the stage text names the record write: the coordinator writes the `ready/` row and
  the gate-results row from the runner's report, before `GR-pr` can merge.
- **Rulings** are the expensive thing to lose. A provisional call is marked as one until the owner
  confirms or overturns it, so the next session knows it may still change. A ruling given in a reply and not written here is
  gone at the next compaction, and the next worker will make the opposite call in good faith. Each
  one names the part it binds — a ruling about part 2 does not silently govern part 5.
- **Gate results** carry both SHAs, because a gate result is only valid against the `main` it ran
  on. Without them `GR-pr` cannot tell whether a later commit is covered.
- **Open topics** are the non-blocking escalations, linked so the PR body and the ledger do not
  drift into two versions of the same question.

## Writing it

Update it **before** the next dispatch, never after. The moment it is stale, the run's recorded
state and its real state disagree, and nothing detects that — the ledger looks just as confident
either way.

Copy a file into `run/` before the ledger cites it, as
`~/.claude/GR-references/where-documents-go.md`'s **Cited files live in `run/`** says.

# The report

One file per run, beside the ledger: `<scratch>/<feature>/run/report.md`. The ledger is for the next
session; the report is for the owner coming back. Plain words throughout: a part by what it does, a
test by what it checks, never a bare ledger code.

```markdown
# Report: <feature>

Last written: <date time>

## What was done

| When | Part | What it does now | State | PR / merge SHA |
|---|---|---|---|---|
| <date time> | <n> <title> | <one or two plain sentences: the capability, with its number> | merged | #<n> <sha> |
| <date time> | <n> <title> | <what is built so far> | parked — waits on call <k> | — |
| <date time> | — | moved on to <next feature>: its report is <path> | — | — |

## Calls taken without you

| # | When | Question | Taken | Why | To undo |
|---|---|---|---|---|---|
| <k> | <date time> | <the question, standalone> | <the recommendation> | <one line> | <what overturning costs: a revert of <sha>, a re-plan of part <n>> |

## Waiting on you

| # | Since | Question | Blocks | Recommendation |
|---|---|---|---|---|
| <k> | <date time> | <the question, standalone> | part <n> | <option and why> |
```

**To undo** is what lets the owner judge a call quickly: a call cheap to reverse can wait, one that
later parts build on cannot. A row leaves **Waiting on you** when the owner answers; a provisional
call stays in **Calls taken without you** with the owner's verdict added once they give it.
