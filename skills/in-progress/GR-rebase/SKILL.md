---
name: GR-rebase
disable-model-invocation: false
description: Rebase every repo an issue touches onto current main, run their suites in parallel, verify the whole stack on the robot, and write the ready record — the gate a feature passes before its PRs open.
---

# Rebase Skill

Run this when the work is reviewed and you are ready to publish it. It brings every repo onto
current `main`, proves each one green, and hands the whole stack over for one verification on the
robot.

**What you verified on the robot is what lands on `main`.** That is the whole point of the skill,
and it is not free: review takes days, `main` moves underneath, and a fixup changes the branch you
already drove. So this run ends by writing a **ready record** — the branch SHA and the `main` SHA
each repo was verified at. `GR-squash-merge` reads that record and refuses to merge once it has
gone stale.

```
repo A ─┐
repo B ─┼─▶ rebased ─▶ suites in parallel ─▶ ONE robot verification ─▶ ready record
repo C ─┘
```

## Gate discipline

Every phase ends with a **report and a stop**. Resume only on an explicit go-ahead for the *next*
phase. A green check is evidence, not consent — one reply authorises one phase. When a command fails
or returns something the user did not predict, stop and report instead of choosing a recovery.

## Phase 0 — Scope

Build the repo/branch table per `~/.claude/GR-references/scope-a-solved-issue.md`.

Assign each repo a `ROS_DOMAIN_ID` of `20 + <its row index>`, so the parallel suites in Phase 2
cannot discover each other.

**Stop.** Report the table with each repo's branch, container name, and assigned domain. Ask whether
it is complete — a repo missing here is a repo that never gets verified.

## Phase 1 — Rebase

For each repo in the table:

```sh
git fetch origin && git rebase origin/main
git push --force-with-lease   # or `git push -u origin <branch>` where the branch has no upstream
```

A conflict ends that repo's pass: report the conflicted paths, leave the rebase in progress, and
hand it back. Resolving another author's conflicts is their call.

Force-pushing here is cheap precisely because it happens *before* the PR — no reviewer's work is
invalidated by it.

**Done when** every repo reports its new HEAD SHA and the `origin/main` SHA it now sits on. Report
both columns and stop.

## Phase 2 — Suites, in parallel

Dispatch one `GR-test-runner` subagent per repo, all in one batch, each carrying its repo name,
container name, and assigned domain from Phase 0.

They run concurrently because each holds its own container and its own domain — the parallel-run
rules are in `~/.claude/GR-references/working-in-the-devcontainer.md`, and the runner reads them.

**Done when** every repo has returned `PASS`, `FAIL`, or `NO SUITE` with its pasted output. Report
the results table verbatim from what the runners returned.

A red suite ends the run. Report it and ask — the robot verification is meaningless while any repo
is failing, and running it anyway wastes the expensive phase.

## Phase 3 — Robot verification

Runs **once**, only when every repo is green. This phase is the user's.

Open with a briefing they can shape their own test list from:

- **Per repo, what changed** — the behaviour, not the file list, from the diff against `main`.
- **The path it changes** — where a value enters, what transforms it, where it surfaces.
- **How to run it** — the launch or run commands for the touched packages, the URL if it is teleop.
- **What the issue asked for** — the acceptance criteria, verbatim.
- **What is worth looking at** — proposed checks, offered as a starting list.

Where `<scratch>/<feature>/prospect/` holds a report for this issue, its runtime-acceptance section
is the better starting list; use it and say so.

Invite the user to correct, cut, or add to that list, and **stop and wait**.

The verdict comes only from the user typing it. A clean build, a green suite, and a plausible diff
are not it, and elapsed time never converts silence into approval.

## Phase 4 — Write the ready record

```markdown
# Ready record — <issue title>
**Date:** <YYYY-MM-DD>
**Issue:** https://github.com/EvoWorkforce/GR-documentation/issues/<n>

| Repo | Branch | Branch SHA | Rebased onto main SHA | Suite |
|---|---|---|---|---|
| GR-gateway | 62-colour-waypoints | a1b2c3d | 9f8e7d6 | pass |

## Robot verification
**Checks run:** <the list the user settled on>
**Verdict:** <the user's own words, verbatim>
```

Write it to `<scratch>/<feature>/ready/<YYYY-MM-DD>-ready.md`. Re-running this skill writes a new
dated file beside the old one; the most recent file in `ready/` is the live record, and that is the
one `GR-squash-merge` reads.

**Done when** every repo in the Phase 0 table has both SHAs recorded and the verdict quotes the user
rather than paraphrasing them.

Report the record's path. `GR-pr` starts from it.
