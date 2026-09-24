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

## Current

Part: <n>
Stage: <plan | review-plan | implement | review-branch | rebase | pr>
Worker: <agent name / id, so its transcript can be found>
Started: <timestamp>
Branch head: <sha, or "no commits yet">
Done so far: <the commits on this branch, one line each, and what is left>
Last reported: <the worker's last report in a line or two — including any measurement that
prompted an escalation, and whether it predates or postdates a fix attempt>

## Rulings

- **<date>, part <n>** — <the question that was raised>
  **Ruling:** <what was decided> — <why, in one line>

## Gate results

| Part | Branch SHA | main SHA | Gate | Result |
|---|---|---|---|---|
| 1 | <sha> | <sha> | `--full` | pass |
| 2 | <sha> | <sha> | `--ci` | pass — restack, files disjoint |

## Open topics

- [<date>-<slug>](../open_topics/<date>-<slug>.md) — <one line>, quoted in PR #<n>
```

## What each part earns its place for

- **The part table** is the run. `State` is one of `not started`, `in progress`, `blocked`,
  `merged`. `blocked` always has a ruling below it saying what on.
- **Current** is what a resuming session needs to know it is mid-stage rather than between stages.
  The worker name matters: a handoff or a context-budget line is traced through it. **`Branch head`,
  `Done so far` and `Last reported` are what stop the next session having to go and read the branch
  to find out where the last one got to** — the moment it has to do that, this file has stopped being
  sufficient and the rule above is broken. A measurement that caused an escalation goes in
  `Last reported` with its date, because "the estimator came in at 0.012" is useless if nobody can
  tell whether that was before or after someone tried to fix it.
- **Rulings** are the expensive thing to lose. A ruling given in a reply and not written here is
  gone at the next compaction, and the next worker will make the opposite call in good faith. Each
  one names the part it binds — a ruling about part 2 does not silently govern part 5.
- **Gate results** carry both SHAs, because a gate result is only valid against the `main` it ran
  on. Without them a restack cannot tell whether it still holds.
- **Open topics** are the non-blocking escalations, linked so the PR body and the ledger do not
  drift into two versions of the same question.

## Writing it

Update it **before** the next dispatch, never after. The moment it is stale, the run's recorded
state and its real state disagree, and nothing detects that — the ledger looks just as confident
either way.
