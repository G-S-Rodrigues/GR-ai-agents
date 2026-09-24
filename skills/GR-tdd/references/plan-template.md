# Plan template

Reference example: `.scratch/56-fe-map-visualization/plans/2026-07-31-map-robot-tests.md`. Sections marked **required** are
never omitted — if one does not apply, say so in a line rather than dropping it.

```markdown
# Plan: <short title>

**Date:** YYYY-MM-DD
**Spec:** [<name>.md](../spec/<name>.md)        # omit entirely if there is no spec
**Mode:** inline | subagent — <the reason, one clause>
**Executor:** claude | copilot | unspecified

## Context                                       # required

What exists now, with `file:line` anchors, and what this plan changes. Cite the repo's
`docs/agents/*` findings that constrain the work. Note that line numbers drift.

A table of what is untested / missing today is often the clearest opening:

| Part | Repo |
|---|---|
| ... | ... |

Out of scope: <things a reader might expect here, and are not>.

## The one unproven assumption                   # required

The single thing this plan depends on that has not been verified, and the step that validates it
first. If there genuinely is none, write "None — every step is grounded in code read for this plan."

## Reuse decisions                               # required

One line per new function: what already exists, the option taken (reuse / extend / extract /
duplicate), and the count that justified it. See `reuse-and-dedup.md`.

## Test tiers                                    # required

Per behaviour: tier, file, test ID. Plus an explicit line on what stays unverified and why.
See `test-tiers.md`.

## Step 0 — <prerequisite>                       # only if one exists

E.g. committing pending work the tests will target, or bumping a limit the tests need.

## Step N — <repo>: <what>

Prose describing the change, anchored: `src/gateway/gateway/gateway_node.py:570-599`.

Include real code only where the exact form matters — a new signature, a tricky QoS setting, a
constant with a rationale comment. Do not transcribe whole files.

For a test-first step, write it as RED then GREEN:

- **RED** — the test to write, its ID, and the failure expected before any implementation exists.
- **GREEN** — the minimal change that satisfies it.

Test cases as a table when there are several:

| ID | Behaviour |
|---|---|
| PKG-1200 | publish a pose → the controller emits the expected command |

Notes: constraints discovered while planning — what cannot be done and how the step works around it.

## Verification                                  # required

Runnable commands, in devcontainer form. Claude runs on the host; the host has no toolchain.

```sh
test -f /.dockerenv && echo "in container" || echo "NOT in container"
```

Each command below is the repo's own, from `docs/agents/testing.md` and
`docs/agents/lint-and-precommit.md`, and its `CLAUDE.md` names the container and working directory.
The shape is shown; the command is never carried over from another repo.

```sh
# the suite / done gate
docker exec <container> bash -lc 'cd <workdir> && <the repo's done gate>'
```

```sh
# the lint gate
docker exec -it <container> bash -lc 'cd <workdir> && source setup.sh && pre-commit run --all-files'
```

State the expected end state concretely: "6 new gateway cases, 2 new signaler cases, no regressions."

## Risks                                         # required

Concrete failure modes. Existing tests that will fail until updated — state them as expected, not as
regressions.
```

## Rules

- `**Date:**` directly under the title. `**Spec:**` directly under it when one exists.
- The mode decision is recorded so `GR-implement-tdd` does not re-decide it.
- Anchor with `file:line`, not prose location.
- Copilot executor only: expand every step into ordered actions with exact commands and expected
  output, and reference `docs/agents/*` by path.
- Never plan a production-code change whose purpose is to make a test possible. Reuse-driven changes
  (see `reuse-and-dedup.md`) are the one sanctioned category, and they must leave existing tests green
  unedited.
