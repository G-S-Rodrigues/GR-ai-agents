---
name: GR-review
disable-model-invocation: false
argument-hint: "target: plan | branch"
description: Interrogate an artifact before it goes on — a plan before it is implemented (target plan), or a finished branch before its PR opens (target branch) — in one repo, blast radius first, then correctness.
---

# Review

One repo. Two targets, and the caller names which:

- **`target: plan`** — a plan, before anything is built from it.
- **`target: branch`** — a finished branch, before its PR opens.

The caller is the owner, or `GR-manage` when a run dispatched this. Where a phase below stops and
asks, it is asking whichever of the two invoked it.

---

# `target: plan`

**This pass is the approval the plan gets.** Under `GR-manage` the owner does not read a plan before
it is implemented, which is exactly why this runs as a separate agent rather than as a self-check
inside `GR-tdd`: a plan reviewed by its author is approved by nobody.

Read the plan, and the spec part it implements.

Check, and report each as a finding or an explicit "checked, clean":

- **Every step is test-first** — the test comes before the change that satisfies it.
- **Every step names the failure it expects** before the fix. A step that says "add a test" without
  saying what the failure looks like cannot tell a real RED from an import error.
- **Nothing is settled here that the spec left open.** A plan that quietly resolves an open question
  has made a decision nobody reviewed — that is the expensive class, because it reads as thoroughness.
- **The plan's `Files:` set matches the part's**, in both directions. A file in the plan and not the
  part is scope creep; a file in the part and not the plan is a step that is missing.
- **Each step is executable as written** against the tree as it is now. Line numbers drift; a step
  anchored to one that moved is a step the implementer will improvise around.
- **The unproven assumption is named and validated first**, if the plan has one.

**Stop** and report. A plan that fails any check goes back to `GR-tdd` rather than forward to an
implementer.

---

# `target: branch`

Two axes, kept apart:

- **Blast radius** — what this branch does to code that did not change.
- **Correctness** — whether the changed code is right on its own terms.

Blast radius is never sharded: the drift lives *between* packages, so an agent holding one package
cannot see it. Correctness can be — a bug is local.

`GR-rebase` runs the suites; this skill finds what should change before they do.

## Gate discipline

Phases 0–3 report and stop. Phase 5 applies only the findings the caller picked — a fix landing
unasked is harder to undo than to propose.

## Phase 0 — Scope

Report `git diff --stat main...HEAD` and the review order: interface-defining packages first, so a
**contract** is settled before its consumers are judged.

## Phase 1 — Ground

Read, and cite by path:

- the feature's spec and plan in `<scratch>/<feature>/{spec,plans}/` — a diff can only be wrong
  relative to an intent;
- the repo's `docs/agents/repo-gotchas.md` and `CONTEXT.md`;
- the ADRs the changed area names in the repo's `CLAUDE.md` table.

Name the grounding files that were **absent**, not only those read: a repo with no `docs/agents/`
looks identical to a repo with no traps. Fall back to
`~/.claude/GR-references/default-repo-rules.md` and say so.

## Phase 2 — Blast radius

List the **contract** this branch moves: every topic, service, ROS parameter, message or interface
type, enum-like string literal, frame id, environment variable, and persisted path it adds, renames,
or removes. Read it out of the diff.

Grep each item across the whole repo, **including packages the branch did not touch** — a consumer
that did not change is where a break hides, and a green build will not flag it.

Then walk the drift classes. Each reads *what it is* → *how to check it*:

- **Undeclared launch parameter** — a launch file passes a parameter the node never declares. ROS 2
  keeps it as an unused override, so the setting silently does nothing. → grep the parameter name in
  that node's own sources; a hit only in the launch file is a dead parameter.
- **Half-moved remap** — a remap moves one side of a topic while the other still names the old one.
  → grep both topic strings, publisher side and subscriber side.
- **QoS mismatch** — a reliable subscriber never hears a best-effort publisher, and nothing says so.
  → compare both ends' profiles wherever the branch adds or moves an endpoint.
- **Interface change without consumers** — a message field or service added, renamed, or removed.
  → grep the type name repo-wide; a consumer that still compiles can still read a field nothing sets.
- **Stale inventory** — a new node must appear in whatever enumerates nodes (a launch file, a
  reference-stack file, a config list) or it runs unmonitored while reporting healthy. → compare the
  nodes actually launched against every such list.
- **Disagreeing literal** — one selector value spelled two ways in two packages; no compiler catches
  it. → grep every occurrence, including comments and test docstrings, which drift last and mislead
  the next reader.
- **Unprovisioned path** — a node writes persisted state to a directory the image or compose file
  must create. → check creation, mount, and write permission for the container's runtime user.
- **Frame drift** — frame ids in the URDF versus the code and visualization configs that look them up.

**Done when** every contract item has been grepped repo-wide with the command shown, and every drift
class has a finding or an explicit "checked, clean".

## Phase 3 — Correctness

Dispatch `general-purpose` subagents over the diff — one per package where the diff is large enough
to shard, otherwise one — each carrying the repo path, its `git diff main...HEAD` command, the
phase 1 grounding files, and this brief:

> Review this diff for defects. Report a finding only with a **repro** — the inputs or state that
> produce the wrong behaviour, and what the vehicle does as a result. Confirm the path is reachable
> by reading the surrounding code before reporting; a finding that dissolves on a second read costs
> the reviewer more than it saves. Anchor each to `file:line`, and name the command or test that
> would prove it. Skip what pre-commit enforces. Under 400 words.

**Done when** every shard has returned findings or an explicit "clean".

## Phase 4 — Report

Two headings, `## Blast radius` and `## Correctness`, findings unmerged and unranked across axes — a
single ranking hides whichever axis scored lower.

Per finding: `file:line`, what breaks, and the symptom when it runs.

Sort each axis into **blockers** — the run is wasted without the fix — and **cleanup**, which a merge
can wait on.

**Stop.** Ask the caller which findings to apply.

## Phase 5 — Act

Apply each finding the caller picked, then run the command that finding named and paste the output —
the same evidence rule `GR-implement-tdd` runs on.

Commit under `GR-commit`'s rules.

Write the digest to `<scratch>/<feature>/review/<date>-<summary>.md`: each finding, applied with its
output or declined with the reason. `GR-pr` quotes it instead of re-deriving the branch.

**Done when** every finding is applied-and-verified or declined-with-a-reason, and the digest lists
both.
