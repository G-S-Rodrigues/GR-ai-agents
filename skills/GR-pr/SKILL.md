---
name: GR-pr
disable-model-invocation: false
description: Open the pull request for a finished branch and land it — draft a body saying what the repo adds and the technical specifics, create it once its text is approved, then wait for CI and merge on green.
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

**Resume landing PR #N.** When dispatched with that wording, the PR exists on purpose (a red ready
gate was fixed and re-run): skip the checks below, including the PR-exists check, and Phase 1, and go
to Phase 2's wait.

The issue number is the branch's leading number (`4-estimators` → `#4`), and the issue lives in the
repo whose `origin` the branch pushes to. Read it:

```sh
gh issue view <n> --repo <owner>/<repo> --json title,body,state
```

`<owner>/<repo>` comes from `git remote get-url origin`. Confirm from real output:

- `git log --oneline origin/main..HEAD` is non-empty — a branch with nothing ahead needs no PR.
- `gh pr list --repo <owner>/<repo> --head <branch> --json number,state` is empty — otherwise report
  the existing PR and leave it alone.
- the repo's `CLAUDE.md` names a merge method — otherwise stop and report before opening.

**Stop.** Report the branch, whether a PR already exists for it, and what you will do.

## Phase 1 — Open it

### Ready evidence

The PR opens as the ready gate starts: at once when `GR-manage` dispatched this, on text approval
under the owner. This skill never runs the gate. The ready gate is the command the repo's
`CLAUDE.md` names as the rule for done, and its result is a row in `<scratch>/<feature>/ready/`
(format in `~/.claude/GR-references/where-documents-go.md`). Phase 2 step 5 reads that row.

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
- **The PR stands alone.** A reader has the body and the diff, not this session or its scratch tree:
  quote a measurement in the body, and keep its source file in `<scratch>/<feature>/run/`.

**Closing the issue.** One issue covers a feature's parts, so use `Refs #<n>` on every part's PR and
`Closes #<n>` only on the last — the issue lives in this repo, where both work. A sub-issue's branch
closes its sub-issue. The PR that closes the **owning issue** carries a `## Harvest` section: the
verdict for every `open_topics/` and `findings/` file, per `where-documents-go.md` **Closing out a
feature**, or "nothing to harvest" when both are empty. Under `GR-manage` the coordinator owes
it: without it, stop before opening and report. Under the owner, run it yourself **before the ready
gate starts**, since a commit after the ready SHA voids the evidence: dispatch a `GR-general` with
`GR-manage`'s `references/dispatch-prompts.md` **harvest** template, commit what it wrote through
`GR-commit`, and only then does the gate run.

### Iterate, then create

Present the title and body exactly as they will be submitted, and wait. Edits from the user replace
the draft; re-present the whole text and wait again. There is no limit on rounds — the text is the
point of this skill.

On approval:

```sh
gh pr create --repo <owner>/<repo> --base main --head <branch> --title "<approved title>" --body "<approved body>"
```

No draft, no reviewers, no labels — these repos use none of them.

No attribution footer either: never append "🤖 Generated with Claude Code" or any similar line to
the body. The body submitted is exactly the text the user approved.

Go to Phase 2.

## Phase 2 — Land

The owner's standing authorization: once a PR's text is approved, **land it without asking again**.
The gate is evidence, not a reply — every blocking check green and the ready evidence holding for
HEAD. A check whose name contains `(non-blocking)` is never waited on and never stops a merge;
every other check is blocking.

1. **Wait on events, not by polling.** Run one background `Monitor` per PR that prints when its
   blocking checks finish. Plain `gh pr checks` prints name, status and duration as tab-separated
   columns (gh 2.45 has no `--json` there); status `pending` is unfinished, `pass` and `skipping`
   are green, anything else is red:
   ```sh
   gh pr checks <pr> --repo <owner>/<repo> | grep -vF '(non-blocking)' | cut -f1,2
   ```
   A PR that reports no blocking checks has not passed any; report that rather than reading absence
   as green. The monitor also polls the
   `ready/` record for a row for this branch at HEAD, or at an ancestor step 5 covers. Wait up to
   30 minutes for it, as for CI. A `fail` row means stop and report "ready gate failed", with no
   merge; no row at the timeout is reported the same way.
2. **Triage every review comment** a person left — none is awaited (`gh api
   repos/<owner>/<repo>/pulls/<pr>/comments`). Each is **valid** — the code is wrong or the claim
   it makes is — or **declined**, with the reason: it contradicts an ADR or a gotcha, misreads the
   diff, or is style the repo's lint already rules on.
   Read the code the comment points at before deciding; the comment is a claim, not evidence.
3. **Fix the valid ones in a subagent** with `model: sonnet`, carrying the comment text, the file
   and line, and the rule that a behaviour fix goes test-first under `GR-implement-tdd` §2 (RED,
   GREEN, one scoped commit, `--fast` only; CI re-runs on the push). When another agent is working
   in the main tree, the fix works in a worktree of the PR branch. The subagent commits; this skill
   pushes, and re-reads the diff before it does — a subagent's report is not evidence.
4. **Reply on each comment**: `fixed in <sha>` or `declined: <reason>`. The trail is what a later
   reader of the PR has instead of this session.
5. **Merge when the ready evidence holds for HEAD**, re-watching checks after any fix push. All of these hold:
   - the latest `ready/` row for this branch is `pass`, and its branch SHA is HEAD or an ancestor of
     HEAD;
   - every commit in `git rev-list --first-parent <ready-sha>..HEAD` is one of two kinds: a
     non-merge commit whose SHA appears in your own `fixed in <sha>` replies (`gh api
     repos/<owner>/<repo>/pulls/<pr>/comments`) and that ran its test RED/GREEN plus `--fast`; or a
     merge commit made by step 6 that applied with no conflict;
   - every blocking check is green on HEAD, and every comment is triaged.

   Any other commit in the range is no evidence: report it and let the ready gate re-run. A failed
   ready row means fix, then re-run the whole gate. Merge with the method the repo's `CLAUDE.md`
   names as the merge method:
   ```sh
   gh pr merge <pr> --repo <owner>/<repo> <method flag>
   ```
   Where `CLAUDE.md` names none, stop and report. A red blocking check, a merge conflict, or a
   valid comment still unfixed stops the run and gets reported instead.

   If `gh pr merge` or `gh pr edit` fails with GraphQL's "Projects (classic) deprecation" error,
   do the same through REST (`-F` reads `@<file>` as its contents; `-f` would send the literal):
   ```sh
   gh api -X PUT repos/<owner>/<repo>/pulls/<pr>/merge -f merge_method=<merge|squash|rebase>
   gh api -X PATCH repos/<owner>/<repo>/pulls/<pr> -F body=@<file>
   ```
6. **Bring `main` in** when the PR conflicts, or when a hand-stacked branch's dependency has merged:
   ```sh
   git fetch origin && git merge origin/main
   ```
   then push. On a conflict, run `git merge --abort` so the checkout stays clean, report the
   conflicting files and escalate; once resolved, the ready gate re-runs. A conflict-free merge runs
   no gate, because CI's merge ref covers integration.

7. **Clear the worktree** once merged. When the branch has a worktree, remove it and the local
   branch from the main checkout:
   ```sh
   git worktree remove <repo>/.scratch/<branch> && git branch -D <branch>
   ```
   A removal that fails on root-owned build output is reported with its path, not forced. When the
   merge closed the owning issue (`gh issue view <n> --json state`) and no coordinator dispatched
   you, delete `<scratch>/<feature>/` — the harvest already moved what outlives it. Under a
   coordinator the folder holds its ledger, so the coordinator deletes it last.

## Done

The branch has a merged PR, or a stated reason it does not: its text is still in iteration, a check
is red, there is no ready evidence for HEAD, the ready gate failed, no merge method is named, or a
valid review comment is unfixed. Report the PR's URL, its merge commit, any review
comments with their verdicts, and whether the worktree and scratch folder were removed.
