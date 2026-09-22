---
name: GR-pr
disable-model-invocation: false
description: Open the pull request for a finished branch and land it — draft a body saying what the repo adds and the technical specifics, create it once its text is approved, then wait for CI and the Copilot review, fix what the review got right, and rebase-merge on green.
---

# PR Skill

One branch, one PR. The PR body is the deliverable: it is what a reviewer reads instead of the
diff.

This skill owns a PR from its text to its merge: Phases 0–1 open it, Phase 2 lands it.

## Invoked by `GR-manage`

When a coordinator dispatched this, **the approval gates below are the manager's and are already
satisfied** — do not stop for them. Escalate instead of asking: report what needs deciding and wait,
rather than choosing.

Invoked by the owner, every gate is unchanged. One skill, two callers — never a second copy.

## Gate discipline

The PR is created only after its text is approved. When a command fails or returns something
unexpected, stop and report instead of choosing a recovery.

## Phase 0 — Scope

The issue number is the branch's leading number (`4-estimators` → `#4`), and the issue lives in the
repo whose `origin` the branch pushes to. Read it:

```sh
gh issue view <n> --repo <owner>/<repo> --json title,body,state
```

`<owner>/<repo>` comes from `git remote get-url origin`. Confirm from real output:

- `git log --oneline origin/main..HEAD` is non-empty — a branch with nothing ahead needs no PR.
- `gh pr list --repo <owner>/<repo> --head <branch> --json number,state` is empty — otherwise report
  the existing PR and leave it alone.

**Stop.** Report the branch, whether a PR already exists for it, and what you will do.

## Phase 1 — Open it

### Confirm the done gate on this HEAD

The PR opens on evidence that the repo's **done gate** (named in its `docs/agents/testing.md`, or
"the rule" in its `CLAUDE.md`) passed on the exact commit being published. Compare `git rev-parse
HEAD` with the SHA that gate last passed on in this session or in the plan's progress file. A
mismatch, or no record, means run the gate now and read its full output before going on. A red gate
stops the run: report it.

### Read the change, not the commits

Draft from the diff. Commit messages compress, and "what this adds" is a behavioural claim the
messages usually do not carry:

```sh
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
```

Also read the plan's `## Deviations` section, where one exists — it is what the PR must disclose.
Where `git status -sb` shows no upstream, push the branch with `git push -u origin <branch>`.

### Draft the text

The body is read by a person, so read `~/.claude/GR-references/writing-for-people.md` before writing
it and apply the directives there to every section below.

**Title**: the issue's title, summarised to roughly 60 characters where it runs longer. The issue
number is carried by the body's closing line, not the title.

**Body**:

```markdown
<one sentence: what this PR makes true, and which plan/spec items it delivers>

## What changes

- <a behaviour, in terms of what the system now does — one bullet per change, with the test IDs
  that prove it>

## Technical changes

- <symbol, topic, message, or parameter level detail — what a reviewer needs to read the diff>
- <what is deliberately unchanged, where something else consumes it>

## Golden change            <- only when a golden or reviewed baseline was regenerated

<what moved, by how much, and why — the reviewed diff the repo's gotchas require>

## Deviations and open issues   <- only when the plan recorded deviations or left items open

Closes #<n>
```

Four rules make the difference between a useful body and an empty one:

- **"What changes" is behaviour.** A reviewer uses it to decide whether the change is *right*.
  Naming files there wastes the section.
- **"Technical changes" names things, not paths** — topics, classes, parameters.
- **State what did not change, when something else consumes it.** It is what tells a reviewer they
  are unaffected.
- **The PR stands alone.** A reader has the body and the diff, not this session.

**Closing the issue.** One issue covers a feature's parts, so use `Refs #<n>` on every part's PR and
`Closes #<n>` only on the last — the issue lives in this repo, where both work.

### Iterate, then create

Present the title and body exactly as they will be submitted, and wait. Edits from the user replace
the draft; re-present the whole text and wait again. There is no limit on rounds — the text is the
point of this skill.

On approval:

```sh
gh pr create --repo <owner>/<repo> --base main --head <branch> --title "<approved title>" --body "<approved body>"
```

No draft, no reviewers, no labels — these repos use none of them. The Copilot review arrives on its
own.

No attribution footer either: never append "🤖 Generated with Claude Code" or any similar line to
the body. The body submitted is exactly the text the user approved.

Go to Phase 2.

## Phase 2 — Land

The owner's standing authorization: once a PR's text is approved, **land it without asking again**.
The gate is evidence, not a reply — every check green and the Copilot review triaged.

1. **Wait on events, not by polling.** Run one background `Monitor` per PR that prints when its
   checks finish and when `copilot-pull-request-reviewer[bot]` submits a review
   (`gh pr checks <pr> --json name,bucket`, `gh api repos/<owner>/<repo>/pulls/<pr>/reviews`).
   Copilot usually reviews within ~5 minutes of creation. After 15 minutes with no review, land
   without it and say so in the report. A PR that reports no checks has not passed any; report
   that rather than reading absence as green.
2. **Triage every Copilot comment** (`gh api repos/<owner>/<repo>/pulls/<pr>/comments`). Each is
   **valid** — the code is wrong or the claim it makes is — or **declined**, with the reason: it
   contradicts an ADR or a gotcha, misreads the diff, or is style the repo's lint already rules on.
   Read the code the comment points at before deciding; the comment is a claim, not evidence.
3. **Fix the valid ones in a subagent** with `model: sonnet`, carrying the comment text, the file
   and line, and the rule that a behaviour fix goes test-first under `GR-implement-tdd` §2 (RED,
   GREEN, one scoped commit). When another agent is working in the main tree, the fix works in a
   worktree of the PR branch. The subagent commits; this skill pushes, and re-reads the diff before
   it does — a subagent's report is not evidence.
4. **Reply on each comment**: `fixed in <sha>` or `declined: <reason>`. The trail is what a later
   reader of the PR has instead of this session.
5. **Merge when every check is green on the pushed head**, re-watching checks after any fix push
   (Copilot does not re-review on push, so its review is not awaited again):
   ```sh
   gh pr merge <pr> --repo <owner>/<repo> --rebase
   ```
   Rebase-merge keeps the one-commit-per-step history a plan produced. A red check, a merge
   conflict, or a valid comment still unfixed stops the run and gets reported instead.
6. **Restack** any branch that was stacked on the merged one by running `GR-rebase` on it — it
   owns the `--onto` form a rebase-merged predecessor needs, and the rule deciding which gate
   re-runs. Do not rebase inline here; one copy of that knowledge, in one place.

## Done

The branch has a merged PR, or a stated reason it does not: its text is still in iteration, a check
is red, or a valid review comment is unfixed. Report the PR's URL, its merge commit, and its Copilot
comments with their verdicts.
