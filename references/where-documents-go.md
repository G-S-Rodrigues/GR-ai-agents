# Where documents go

Single source of truth for paths. `GR-brainstorming`, `GR-tdd`, `GR-implement-tdd`,
`GR-domain-modeling`, and `GR-review` all point here — change a path here, not in a skill.

## The two trees

**Committed, team-facing** — standing knowledge about a repo:

```
<repo>/
├── CLAUDE.md           ← auto-loaded; carries the pointer table into docs/agents/
├── CONTEXT.md          ← glossary of terms local to THIS repo (created lazily)
└── docs/
    ├── agents/         ← standing rules: gotchas, testing, lint/pre-commit
    └── adr/            ← architecture decisions, numbered 0001-, 0002-, …
```

**Glossaries are two-tier.** Which tier a term belongs to, and why, is `GR-domain-modeling`'s call —
see its "Which glossary a term belongs in" section rather than deciding here. The two file paths are
in the Tier decision table below.

**`docs/agents/` is not scanned — it is pointed into.** The repo's `CLAUDE.md` is auto-loaded, so it
holds the table saying which file to read before which kind of work. That is the only reason any of
these files gets opened, which gives every file here two requirements:

- **A named consumer** — the skill, or the situation, that reaches for it. "Useful background" is
  not a consumer, and a file without one is dead weight.
- **A row in `CLAUDE.md`'s table**, phrased as *read this before that*. `see also X` does not make
  an agent open X; `read X before writing a test` does.

One file may be `@`-imported into `CLAUDE.md` instead — by convention `repo-gotchas.md`, the traps
any task can hit. Everything phase-specific stays behind a pointer, because an `@` import is paid in
every session whether or not that phase ever starts.

Where a repo has no `docs/agents/` yet, `~/.claude/GR-references/default-repo-rules.md` carries the
stack-wide defaults. Say that you fell back to it, and offer to bootstrap the repo's own.

**Local, per-feature** — the artifacts of one piece of work:

```
<scratch>/<feature>/
├── grill/<date>-<summary>.md
├── spec/<date>-<summary>.md
├── plans/<date>-<summary>-tdd.md             (+ <date>-<summary>-tdd-progress.md after a handoff)
├── review/<date>-<summary>.md
└── ready/<date>-ready.md
```

Each subdirectory holds a different **stage** of the work, which is why a session's output goes to
exactly one of them:

| Directory | Holds | Written by |
|---|---|---|
| `grill/` | the digest of an exploratory interrogation | `GR-brainstorming` |
| `spec/` | the settled decisions that interrogation produced | `GR-brainstorming` |
| `plans/` | the test-first implementation plan for a spec; beside a plan, its `-progress.md` when an implementing agent handed off at its context budget | `GR-tdd`; progress: `GR-implement-tdd` |
| `review/` | one review pass over the finished branch: findings, which were applied with the output that proved it, which were declined and why | `GR-review` |
| `ready/` | what the stack was verified at: per repo, the branch SHA and the `main` SHA it was rebased onto, its suite result, and the user's robot verdict | `GR-rebase` |

`review/` sits at the far end, after the implementation is committed, and `GR-pr` reads it instead
of re-deriving a cross-repo change from the diffs. A review digest is not a grill digest: grilling
interrogates an idea before it is built, reviewing interrogates code after it is.

`ready/` is the one directory with a fixed filename rather than a `<summary>`, because
`GR-squash-merge` has to find it without being told where it is: the most recent file there is the
live record. Re-running `GR-rebase` writes a new dated file beside the old one, so the history of
what was verified when stays intact.

## Resolving `<scratch>` and `<feature>`

**`<feature>` is the branch name** — e.g. `56-fe-map-visualization`. It already carries the issue
number, so filenames do **not** repeat it — branches are created from a GitHub issue, so the number
is already there. If the work is on `main`, there is no feature name to use: say so and stop rather
than inventing one.

**`<scratch>` depends on reach:**

| Reach | Location |
|---|---|
| One repo | `<repo>/.scratch/` |
| More than one repo | `${HOME}/gitroot/.scratch/` |

Decide reach once, at the start, and say which you chose in one line. When in doubt — the branch
exists in two repos, or the change touches a cross-repo contract (a `robot_msgs` shape, a topic name,
a QoS profile) — it is cross-repo. Put it in `gitroot`.

Never split one feature's artifacts across both trees.

## `<date>` and `<summary>`

`<date>` is the date the **file was written** (`YYYY-MM-DD`), not the date of the work it describes.
`<summary>` is a short kebab-case slug of the subject. Plans carry a `-tdd` suffix so a plan and the
spec it implements can share a summary without colliding.

## Both trees are gitignored

`docs/`, `.scratch/`, and `.claude/` are all in `.gitignore` in the repos set up so far
(GR-gateway, GR-ice-signaler). Nothing written to either tree reaches the team until that changes —
do not assume a teammate can see a file you wrote.

## Tier decision

Ask what outlives the feature:

- A trap that will cost time again → `docs/agents/`
- A term two or more repos must agree on → `~/.claude/GR-references/stack-glossary.md`
- A decision that is hard to reverse, surprising, and had real alternatives → the repo's own
  `docs/adr/README.md` has the full gate and what qualifies in this stack
- A term one repo keeps arguing about → that repo's `CONTEXT.md`
- Anything else about *this* piece of work → `.scratch/<feature>/`

Ask the user before committing anything from the committed tier. Both trees are gitignored today
while this way of working is still being tested, so a commit is a deliberate decision to change
that, not a routine step.

### ADR gate fallback

Read the repo's own `docs/adr/README.md` before writing an ADR — it has the full gate and this repo's
specific qualifying list. Where a repo has no `docs/adr/` yet, the fallback gate is: **hard to
reverse** (changing your mind later costs something real), **surprising without context** (a future
reader would wonder why), and **the result of a real trade-off** (genuine alternatives existed). All
three must hold. Say that you fell back to it, and offer to bootstrap the repo's own `docs/adr/README.md`.
