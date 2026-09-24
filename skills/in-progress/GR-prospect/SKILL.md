---
name: GR-prospect
disable-model-invocation: true
description: Scope a new GitHub issue before designing it — determine which repos it touches, trace the contract end to end, find the open PRs already doing part of it, and write the findings to disk. Facts only; the design decisions are parked for GR-brainstorming.
---

# Prospect

**Out of the loop, deliberately.** Its job is scoping across repos, and `GR-brainstorming` now ends
by creating the issue and splitting the spec into parts, which covers that for single-repo GR work.
This stays installable for a genuinely cross-repo issue.

Turn one issue into a grounded scope report.

**Read-only until Phase 3.** No production edits, no branches, until the user approves.

## Phase 0 — Frame

1. Read the issue: `gh issue view <n> --repo <owner>/<issue-repo> --json number,title,body,labels,comments`.
2. Resolve `<feature>` as the branch name GitHub itself would generate: the issue number, then the
   **whole** title lowercased and hyphenated, nothing dropped. Issue 62, *Mark different waypoint types
   in the map in different colours*, gives `62-mark-different-waypoint-types-in-the-map-in-different-colours`.
   The branch does not exist yet, so the issue supplies the name it will later carry.
3. `<scratch>` is always `${HOME}/gitroot/.scratch/`. Reach is this skill's *output*, so it cannot pick
   the per-repo tree; a prospect that turns out to be single-repo can be moved afterwards.
4. Name **candidate repos** cheaply — grep `${HOME}/gitroot` for the issue's domain nouns (a topic
   name, a message type, a symbol) rather than reading every repo. Say which repos you ruled out.
5. List the **questions this run will answer**: the standing set below, plus every question the user
   typed, each becoming its own named finding.

**Stop.** Report the feature slug, the report path, the candidate repos, and the question list. Ask to
proceed — a wrong scope caught here costs one round trip instead of the whole run.

## The standing questions

Answer these for every issue, alongside whatever the user added:

- **Repo impact** — per candidate repo: production change, test-only change, or none.
- **Contract trace** — follow the value the issue is about along its real path, and name where it
  stops. "Does topic X carry field Y" is answered by walking publisher → relay → consumer, not by
  grepping for Y.
- **Feasibility at each boundary** — where the change is cheap and where it forces a contract change,
  with the cost of each.
- **In-flight collisions** — see below.
- **Extensibility** — what the issue's shape implies about the next case of the same kind.

## Phase 1 — Research

Dispatch `GR-researcher` per candidate repo, in parallel, one question set each. Every claim in the
report carries a `file:line` anchor or a PR number; a claim that cannot be anchored belongs under
unproven assumptions.

**Sweep GitHub before trusting the checkouts.** Work already in flight is invisible to a code reader
and is the finding most likely to save a rewrite:

```sh
gh pr list --repo <owner>/<repo> --state all --limit 20 --json number,title,state,updatedAt,headRefName
gh api graphql -f query='{repository(owner:"<owner>",name:"<issue-repo>"){issue(number:<n>){
  linkedBranches(first:20){nodes{ref{name repository{nameWithOwner}}}}}}}'
```

An open PR that already implements part of the issue changes the answer to *what do I need to build* —
report it as a dependency, not as prior art.

## Phase 2 — Report

Write `<scratch>/<feature>/prospect/<date>-<summary>.md`, in this order — a reader coming back a week
later reads the top three sections and stops:

```markdown
# Prospect: <topic>
**Date:** YYYY-MM-DD
**Issue:** [<owner>/<issue-repo>#<n>](url)

## Summary
(the shortest sound path, and the minimum repo scope, in under ten lines)

## Repo impact
| Repo | Production | Tests | Why |

## Open decisions
(numbered, each stating what it commits to — this is what GR-brainstorming grills)

## Findings
(one section per question, with file:line anchors)

## In flight
(open PRs and linked branches that overlap, and what each already does)

## Unproven
(what could not be settled by reading, and what would settle it)
```

**Cost is a finding; the choice is a decision.** "Colouring in the frontend needs the type added to
three payloads — AOM already owns the colour" is a fact and belongs in Findings. "So keep AOM as the
authority" is a recommendation: it goes in **Open decisions**, phrased as the question, and waits for
the grill. This is the same parking rule `GR-brainstorming` runs on, applied one stage earlier.

**Stop.** Report the path and the summary.

## Phase 3 — Linked branches

Propose one branch per repo needing a production change, each named `<feature>` — the same name in
every repo, so the issue number and title identify the work wherever it lands. Wait for approval.

Create them through GitHub so they appear in the issue's Development panel — a locally created branch
pushed afterwards is **not** linked, and nothing links it retroactively:

```sh
gh issue view <n> --repo <owner>/<issue-repo> --json id --jq .id
gh api graphql -f query='{repository(owner:"<owner>",name:"<repo>"){id defaultBranchRef{target{oid}}}}'
gh api graphql -f query='mutation($i:ID!,$r:ID!,$o:GitObjectID!,$n:String!){createLinkedBranch(input:{issueId:$i,repositoryId:$r,oid:$o,name:$n}){linkedBranch{ref{name}}}}' \
  -f i=<issueId> -f r=<repoId> -f o=<mainHeadOid> -f n=<branch>
```

Then check out each locally: `git -C <repo> fetch origin && git -C <repo> checkout <branch>`.

Where a branch of that name already exists, report it and leave it alone — it may hold work.

**The run ends here.** The report is the input to `GR-brainstorming`; this skill writes no spec and no
plan.
