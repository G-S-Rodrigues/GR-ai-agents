---
name: GR-review
disable-model-invocation: true
description: Review a solved issue's branch across every Evo repo it touches before its PRs open — blast radius across repos first, then per-repo correctness.
---

# Evo Review

Two axes, kept apart:

- **Blast radius** — what this branch does to code that did not change. Whole-branch, inline.
- **Correctness** — whether the changed code is right on its own terms. Per repo, in subagents.

Blast radius is never sharded by repo: the drift this stack produces lives *between* repos, so an
agent holding one repo cannot see it. Correctness is sharded — a bug is local, and one repo's diff
is enough to judge it.

`GR-rebase` runs the suites; this skill finds what should change before they do.

## Gate discipline

Phases 0–3 report and stop. Phase 5 applies the findings the user picked — a fix landing across nine
repos unasked is harder to undo than to propose.

## Phase 0 — Scope

Build the repo/branch table per `~/.claude/GR-references/scope-a-solved-issue.md`.

**Stop.** Report it with each repo's `git diff --stat main...HEAD` and the review order —
interface-defining repos first, so their **contract** is settled before its consumers are judged.

## Phase 1 — Ground

Read, and cite by path:

- the feature's spec and plan in `<scratch>/<feature>/{spec,plans}/` — the diff can only be wrong
  relative to an intent
- each repo's `docs/agents/repo-gotchas.md` and `CONTEXT.md`
- `~/.claude/GR-references/where-documents-go.md` when `<scratch>` is ambiguous

Name the grounding files that were **absent**, not only the ones read: a repo with no `docs/agents/`
looks identical to a repo with no traps. Fall back to
`~/.claude/GR-references/default-repo-rules.md` and say so.

## Phase 2 — Blast radius

List the **contract** this branch moves: every environment variable, topic, ROS parameter, interface
type, enum-like string literal, frame id, and persisted path it adds, renames, or removes. Read it
out of the diffs.

Grep each item across all of `${HOME}/gitroot`, **including repos not on the branch** — a consumer
that did not change is where a break hides, and `main` will not flag it.

Then walk the drift classes. Each reads *what it is* → *how to check it*:

- **Undeclared launch parameter** — a launch file passes a parameter the node never declares. ROS2
  keeps it as an unused override, so the setting silently does nothing. → grep the parameter name in
  that node's own sources; a hit only in the launch file is a dead parameter.
- **Half-moved remap** — a remap moves one side of a topic while the other still names the old one.
  → grep both topic strings stack-wide, publisher side and subscriber side.
- **Interface change without consumers** — a `robot_msgs` field or service added, renamed, or
  removed. Everything building against `/opt/ros_custom_msgs` is a consumer. → grep the type name
  stack-wide; a consumer that still compiles can still read a field nothing sets any more.
- **Broken env chain** — a variable must survive `deploy.sh` → `robot.env` → compose `env_file` →
  `start.sh` → `os.environ` in the launch file. One missing link leaves the default in force on the
  robot while tests pass, because tests set it explicitly. → walk all five links per variable.
- **Stale node inventory** — a new node must appear in whatever enumerates nodes (`SYSTEM_NODES`,
  lifecycle inventory and config, `_evo_robot.env`) or it goes unmonitored while reporting healthy.
  → compare the nodes actually launched against every such list, in every deploy script.
- **Disagreeing literal** — one selector value spelled two ways in two repos; no compiler catches
  it. → grep every occurrence, including comments and test docstrings, which drift last and mislead
  the next reader.
- **Unprovisioned path** — a node writes persisted state to a directory deploy must create and
  compose must mount. → check creation, mount, and write permission for the container's runtime user.
- **Frame drift** — frame ids in the URDF versus the code and RViz configs that look them up.
- **Cross-repo `main` dependency** — this repo's branch needs another repo's unmerged change.
  → record it as merge-order input for `GR-squash-merge` rather than as a defect.

**Done when** every contract item has been grepped stack-wide with the command shown, and every
drift class has a finding or an explicit "checked, clean".

## Phase 3 — Correctness

Dispatch one `general-purpose` subagent per repo, in parallel, each carrying the repo path, its
`git diff main...HEAD` command, the phase 1 grounding files, and this brief:

> Review this diff for defects. Report a finding only with a **repro** — the inputs or state that
> produce the wrong behaviour, and what the robot does as a result. Confirm the path is reachable by
> reading the surrounding code before reporting; a finding that dissolves on a second read costs the
> reviewer more than it saves. Anchor each to `file:line`, and name the command or test that would
> prove it. Skip what pre-commit enforces. Under 400 words.

**Done when** every repo in the table has returned findings or an explicit "clean".

## Phase 4 — Report

Two headings, `## Blast radius` and `## Correctness`, findings unmerged and unranked across axes — a
single ranking hides whichever axis scored lower.

Per finding: `file:line`, what breaks, and the symptom on the robot.

Sort each axis into **blockers** — the field test is wasted without the fix — and **cleanup**, which
merges can wait on.

**Stop.** Ask which findings to apply.

## Phase 5 — Act

Apply each finding the user picked, then run the command that finding named and paste the output —
the same evidence rule `GR-implement-tdd` runs on.

Commit per repo under `GR-commit`'s rules, approval gate included.

Write the digest to `<scratch>/<feature>/review/<date>-<summary>.md`: each finding, applied with its
output or declined with the user's reason. `GR-pr` quotes it instead of re-deriving nine repos.

**Done when** every finding is applied-and-verified or declined-with-a-reason, and the digest lists
both.
