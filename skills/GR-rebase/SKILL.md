---
name: GR-rebase
disable-model-invocation: false
description: Bring one branch onto current main and prove it green there — before its PR opens, or again after a predecessor merged — choosing the gate by a mechanical rule and recording which ran, at which branch and main SHA.
---

# Rebase and gate

A gate result is only true against the `main` it ran on. `main` moves, so this skill exists to move
the branch onto it and re-establish the result — and to **record what was proved against what**, so
the next caller can tell whether it still holds.

Two callers, one operation:

| When | What runs |
|---|---|
| **before a PR opens** | rebase onto `origin/main`, run the full gate, record |
| **after a predecessor merged** | restack with `--onto`, re-verify by the rule below, record |

## Restacking uses `--onto`, always

```sh
git fetch origin
git rebase --onto main <old-predecessor-tip> <branch>
```

`<old-predecessor-tip>` is the predecessor's tip **as it was before it merged** — the ledger or the
previous ready record has it.

This is not a preference. A rebase-merge rewrites the predecessor's commits as it lands them, so a
plain `git rebase main` sees the branch's base as unmerged work and replays the predecessor's
commits onto copies of themselves. The result builds, passes, and carries every commit twice.

## Which gate runs

Mechanical. Read it off the facts, do not weigh them:

```
--full  once per branch, before its PR opens.
        No exception: it is the repo's stated done gate.

--ci    permitted on a restack when ALL of these hold:
          - the rebase applied with no conflicts;
          - the files main changed since the recorded SHA are disjoint from the branch's files;
          - none of those changed files are package.xml, CMakeLists.txt,
            docker/, config/, or tests/golden/.

--full  otherwise.
```

**The rule this is not:** the size of one's own diff never decides the gate. A one-line change to a
parameter default can move every metric in the suite, and a large diff confined to one package may
touch nothing else. What decides it is what `main` moved underneath, not what the branch did.

The disjointness test compares two file lists:

```sh
git diff --name-only <recorded-main-sha>..main      # what main changed
git diff --name-only main...HEAD                    # what the branch changes
```

## Running the gate

The gate command and the container it runs in are named in **the repo's own `CLAUDE.md`** — read it
rather than assuming. Claude runs on the host and the toolchain does not, so emit the containerised
form:

```sh
docker exec <container> bash -lc 'cd <workdir> && ./scripts/check.sh --full'
```

A bare gate command run on the host is broken, not merely unconventional.

## Stop and report when

- **the rebase conflicts** — report the conflicted paths, leave the rebase in progress, and hand it
  back. Resolving a conflict is a decision, and this skill does not make those.
- **the gate is red** — report the failing output. A red gate ends the run; it is not something to
  re-run until it passes.

Force-pushing after a rebase is cheap *before* a PR opens and expensive after, because it
invalidates a review in progress. Use `--force-with-lease`, and where the branch has no upstream,
`git push -u origin <branch>`.

## The record

Write `<scratch>/<feature>/ready/<YYYY-MM-DD>-ready.md` — a fixed filename, so a caller finds it
without being told where it is. Re-running writes a new dated file beside the old one, keeping the
history of what was verified when.

```markdown
# Ready record — <branch>
**Date:** <YYYY-MM-DD>

| Branch | Branch SHA | Rebased onto main SHA | Gate | Result |
|---|---|---|---|---|
| <branch> | <sha> | <sha> | `--full` | pass |

**Why this gate:** <"first gate before the PR", or the three conditions and how each was met>
```

**Done when** both SHAs are recorded, the gate that ran is named, and the reason it was the right
one is written down rather than implied. A record that says `--ci` without saying why is a record
nobody can re-check.
