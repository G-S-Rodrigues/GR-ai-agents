---
name: GR-squash-merge
disable-model-invocation: false
description: Land an issue's approved PRs across every repo it touches — check the ready record still holds against a main that has moved, then squash-merge each in contract order.
---

# Squash Merge Skill

**Out of the loop, deliberately.** `GR-manage` lands parts with `GR-pr`'s rebase-merge instead,
because squash-merging erases the one-commit-per-step history a plan produced — the history that
makes a later bisect or revert land on the step that caused it. This stays installable for landing a
multi-repo issue by hand.

`GR-rebase` verified this stack on the robot and pinned what it verified. Between then and now,
`main` moved and review changed the branches. This skill decides whether that pinned verdict is
still **live** — and stops when it has gone **stale**, rather than landing something nobody drove.

## Gate discipline

Every phase ends with a **report and a stop**. Resume only on an explicit go-ahead for the *next*
phase. When a command fails or returns something the user did not predict, stop and report instead
of choosing a recovery.

## Phase 0 — Scope and order

Build the repo/branch table from the issue's linked branches, then for each:

```sh
gh pr view <pr> --repo G-S-Rodrigues/<repo> --json number,title,state,reviewDecision,mergeStateStatus,statusCheckRollup,headRefName
```

Propose a **merge order** and say what it rests on. These are separate repos with separate `main`s,
so order is not about rebasing — it is about never leaving a `main` that depends on something
unmerged. A repo whose contract others consume (the interface-defining repo first, then its producers, then its consumers,
then the frontend) lands first.

Report `statusCheckRollup` as it comes back; where a PR reports no checks, say that rather than
reading absence as a pass.

**Stop.** Report the table and the proposed order, and ask whether both are right.

## Phase 1 — Is the record still live?

Read the most recent file in `<scratch>/<feature>/ready/`. Where none exists, the stack was never
verified on the robot — say so and hand back to `/GR-rebase`.

Three checks per repo, each with one stale answer:

1. **Did the branch move?** `git rev-parse HEAD` against the recorded branch SHA. A review fixup,
   an amend, a rebase — any difference means the artifact on the robot is not the artifact about to
   land. **Stale, with no exceptions**, because nothing here can tell a cosmetic commit from a
   behavioural one.
2. **Did `main` move?** `git rev-parse origin/main` against the recorded main SHA. Equal, and this
   repo is live. Different, and it goes to the drift check below.
3. **Does GitHub see a conflict?** `mergeStateStatus: DIRTY` is a textual conflict, which needs a
   rebase whatever the other two say.

### The drift check

`main` moving is not by itself a problem — the question is whether it moved *under this branch's
contract*. Take the contract item list from `<scratch>/<feature>/review/`'s digest, which `GR-review`
already derived, and grep each item against what `main` gained:

```sh
git diff <recorded-main-sha>..origin/main -U0 | grep -nE '<item>|<item>|<item>'
```

Run each item against **every in-scope repo's** main movement, not only the repo the item came from.
The drift this stack produces lives between repos: a message field that changed on the
interface repo's `main` breaks a consumer's branch that no conflict marker will ever flag.

Two verdicts:

- **Unrelated drift** — no item hit. Rebase, push, and this repo is live.
- **Touches the contract** — quote the hits. The repo is **stale**.

### Where it lands

A stale repo ends the run. Report which repos are stale and why, and hand back to `/GR-rebase` —
the record is rebuilt by re-verifying on the robot, not by asserting the drift was harmless.

**Done when** every repo has a live-or-stale verdict with the SHAs and any drift hits shown, and
every repo is live.

**Stop.** Report the verdicts and ask to merge.

## Phase 2 — Merge

Merge in the Phase 0 order, one repo at a time, each with its own approved message.

- **Subject**: the PR title verbatim plus the PR number — `46 robot parameters topic (#9)`. The
  title was settled when the PR opened; reusing it keeps the issue number reaching `main` matched to
  the one under review.
- **Body**: what changed and why, compact enough to read at a glance in `git log` — a few short
  lines, one per behaviour change, in terms a teammate scanning history will understand.

Present subject and body exactly as they will be committed, and wait. Edits from the user replace
the draft; re-present and wait again.

```sh
gh pr merge <pr> --repo <owner>/<repo> --squash --subject "<approved subject>" --body "<approved body>"
```

After each merge, report the merge commit and stop before the next repo. From that point `main`
carries a contract the unmerged repos depend on, and the user should see each step of that before
the next is taken.

**The run ends when every PR is merged.** Branch deletion, local `main` sync, and closing the issue
stay with the user.
