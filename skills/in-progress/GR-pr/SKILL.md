---
name: GR-pr
disable-model-invocation: false
description: Open the pull requests for a solved issue, one per repo it touches, and land them — draft a body saying what the repo adds and the technical specifics, create each PR once its text is approved, then wait for CI and the Copilot review, fix what the review got right, and rebase-merge on green.
---

# PR Skill

One issue, one PR per repo. The PR body is the deliverable: it is what a reviewer reads instead of
the diff, and on a cross-repo issue it is how a reviewer in one repo learns what the others did.

`GR-rebase` verifies what this skill publishes. Phase 2 lands it: this skill owns a PR from its text
to its merge.

## Gate discipline

Each repo's PR is created only after the user approves that repo's text. A go-ahead for one repo
authorises one PR. When a command fails or returns something unexpected, stop and report instead of
choosing a recovery.

## Phase 0 — Scope

Establish which repos need a PR:

```sh
gh api graphql -f query='{repository(owner:"EvoWorkforce",name:"GR-documentation"){issue(number:<n>){
  title linkedBranches(first:20){nodes{ref{name repository{nameWithOwner}}}}}}}'
```

Branches created locally never appear there, so also check `git -C <repo> branch --list "<n>-*"`
across `${HOME}/gitroot` and reconcile. For each candidate, confirm from real output:

- `git log --oneline origin/main..HEAD` is non-empty — a branch with nothing ahead needs no PR.
- `gh pr list --repo EvoWorkforce/<repo> --head <branch> --json number,state` is empty — otherwise
  report the existing PR and leave it alone.

**Stop.** Report the repo/branch table, which already have PRs, and the order you will work them.

## Phase 1 — One repo at a time

For each repo, in order:

### Confirm the ready record

`GR-rebase` rebased this branch, ran its suite, and verified the stack on the robot. Read the most
recent file in `<scratch>/<feature>/ready/` and confirm this repo's recorded branch SHA still matches
`git rev-parse HEAD`.

A mismatch means the branch moved since anyone drove it — report it and ask. Where no record exists,
say so and offer `/GR-rebase`, which is where the suites now run.

### Read the change, not the commits

Draft from the diff. Commit messages compress, and "what this adds" is a behavioural claim the
messages usually do not carry:

```sh
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
```

`GR-rebase` pushed the branch; where `git status -sb` shows no upstream, push it with
`git push -u origin <branch>`.

### Draft the text

The body is read by a person, so read `~/.claude/GR-references/writing-for-people.md` before writing
it and apply the directives there to both sections below.

**Title**: the issue number, then the branch's words with hyphens as spaces — GitHub's own default.
Where that runs past roughly 60 characters, summarise the words while keeping the number:
`62-mark-different-waypoint-types-in-the-map-in-different-colours` becomes `62 colour waypoint
markers by type`. `GR-squash-merge` reuses this title verbatim as the squash subject, so the shortening
happens once, here, and the issue number still reaches `main`'s history.

**Body**, two sections:

```markdown
Issue: https://github.com/EvoWorkforce/GR-documentation/issues/<n>

## What this adds

- <a behaviour, in terms of what the system now does — one bullet per user-visible change>

## Technical changes

- <symbol, topic, message, or parameter level detail — what a reviewer needs to read the diff>
- <what is deliberately unchanged, where another repo consumes it>
```

Four rules make the difference between these and the empty bodies already in these repos:

- **"What this adds" is behaviour.** A reviewer uses it to decide whether the change is *right*.
  Naming files there wastes the section.
- **"Technical changes" names things, not paths.** `/evo/slam/request_map`, `TelemetryStore`,
  `map_pointcloud_min_interval_s` — see `GR-gateway#11` for the shape.
- **State what did not change, when another repo consumes it.** `GR-aom#7`'s "No topic/interface
  changes — `/waypoints_marker` keeps the same publisher and message shape consumed by GR-gateway"
  is what tells a reviewer elsewhere they are unaffected.
- **Each PR stands alone.** The issue link is the only cross-repo reference; a reviewer follows it
  when they need the wider picture.

**Link the issue by full URL, never a closing keyword.** Closing keywords do not work across
repositories, so `Closes #<n>` in `GR-aom` would do nothing for an issue in `GR-documentation` — or
close that repo's own issue of the same number. The issue is closed by hand once every repo lands.

### Iterate, then create

Present the title and body exactly as they will be submitted, and wait. Edits from the user replace
the draft; re-present the whole text and wait again. There is no limit on rounds — the text is the
point of this skill.

On approval:

```sh
gh pr create --repo EvoWorkforce/<repo> --base main --head <branch> --title "<approved title>" --body "<approved body>"
```

No draft, no reviewers, no labels — these repos use none of them.

No attribution footer either: never append "🤖 Generated with Claude Code" or any similar line to
the body. The body submitted is exactly the text the user approved.

**Stop.** Report the PR URL and ask to move to the next repo.

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
6. **Restack.** A branch stacked on the merged one (a plan started before this PR landed) is
   rebased onto `origin/main` and pushed with `--force-with-lease`, then its own suite runs before
   its PR opens.

## Done

Every repo in scope has a merged PR, or a stated reason it does not: its text is still in
iteration, a check is red, or a valid review comment is unfixed. Report each PR's URL, merge commit,
and its Copilot comments with their verdicts.
