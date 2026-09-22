---
name: GR-tdd
disable-model-invocation: true
description: Turn an idea, spec, or grill digest into a test-first implementation plan written to .scratch/<feature>/plans/. Use when the user asks for a plan, an implementation plan, a TDD plan, or asks how to implement something; also when a spec is ready to be planned. Produces the plan only — GR-implement-tdd executes it.
---

# Evo TDD — plan creation

Produce one implementation plan file. Do not implement anything.

## 1. Read the input

| Input | What to do |
|---|---|
| A spec path (`<scratch>/<feature>/spec/*.md`) | Treat its decisions as settled. Do **not** re-litigate scope, non-goals, or design. Link it with a `**Spec:**` line. |
| A grill digest (`<scratch>/<feature>/grill/*.md`) | Use its resolved branches and open flags. Flags still open become plan risks. |
| A bare idea | Plan it directly. If the idea is ambiguous in a way that changes the plan's shape, ask — do not invent scope. If it needs design exploration, say so and suggest `GR-brainstorming` first. |

## 2. Ground yourself

Name the repos in scope, then read and cite in the plan:

- `docs/agents/repo-gotchas.md` — the traps any change here can hit
- `docs/agents/testing.md` — the harness this plan's steps will actually run in; step 6 depends on it
- `CONTEXT.md`, if it exists — use its vocabulary in step and test names
- the code the plan touches — anchor every step with `file:line`

ADRs in the area are settled: a step that contradicts one must say so and justify reopening it, not
quietly route around it.

Name the grounding files that were **absent**, not only the ones you read. A repo with no
`docs/agents/` looks exactly like a repo with no traps in it, and it is not — say so, fall back to
`~/.claude/GR-references/default-repo-rules.md`, and offer to bootstrap the repo's own.

## 3. Decide the depth, and announce it

- **Full** (default): the whole process below.
- **`quick`**: adapt to the task — steps and verification only, no test-ID table, no subagents. For
  work whose shape is already obvious (lint cleanup, a one-file change, a rename).

Say which you chose and why in one line. If a `quick` request has cross-repo reach or an unfamiliar
harness, say that full mode is warranted and let the user decide.

## 4. Decide inline vs subagent — never both

Count these:

1. more than one repo is touched
2. the plan needs facts from an area not read in this session
3. the test harness involved has not been used in this session
4. third-party, generated, or `node_modules` code must be read

**≥2 true → subagent mode.** Otherwise inline. `quick` mode is always inline.

Announce the choice with the reason and record it in the plan. In subagent mode:

- `GR-researcher` for facts, patterns, constraints, and unproven assumptions.
- `GR-inventory` for mechanical lists — existing tests, harness, test-ID numbering, current coverage.
- Dispatch in parallel when the questions are independent. Never dispatch a subagent to *write* the
  plan; you write it from their findings.

## 5. Decide the executor

- **claude** (default): plan at normal altitude — steps, anchors, and verification commands. Trust the
  implementer to know the toolchain.
- **copilot**: the plan must stand alone. Exact commands with expected output, no reliance on these
  skills or any Claude-only tool, and `docs/agents/` referenced by path rather than assumed read.
- **unspecified**: do not tailor. Note in one line that a cheaper model could execute it.

## 6. Decide the test tiers

Read `references/test-tiers.md`. State per behaviour which tier covers it, **and what stays
unverified and why**. A plan that silently leaves wiring untested is the failure this section prevents.

The `.robot` tier is not optional filler — for ROS2 and socketio wiring it is the only tier that
reaches the code at all.

## 7. Apply the reuse gate

Read `references/reuse-and-dedup.md` before introducing any new function. Near-duplicate functions
are a worse outcome than a measured change to an existing one. Every plan carries a
**Reuse decisions** section.

## 8. Write the plan

Use `references/plan-template.md`. Read `~/.claude/GR-references/where-documents-go.md` — it is the
single source of truth for the path — and write to:

```
<scratch>/<feature>/plans/<date>-<summary>-tdd.md
```

`<feature>` is the branch name (e.g. `56-fe-map-visualization`), so the filename does **not** repeat
the issue number. `<scratch>` is `<repo>/.scratch/` for single-repo work and
`${HOME}/gitroot/.scratch/` when the plan touches more than one repo. `<date>` is today. The `-tdd`
suffix keeps the plan distinct from a spec sharing the summary.

State the resolved path in one line before writing.

## Standing rules

- **Verification runs in the devcontainer, not on the host.** Claude runs on the host and the host has
  no toolchain. Every verification command is written as:
  ```sh
  docker exec -it <container> bash -lc 'cd "$HOME/workspace" && source setup.sh && <command>'
  ```
  Include this line in the plan so the implementer can confirm where it is running:
  ```sh
  test -f /.dockerenv && echo "in container" || echo "NOT in container"
  ```
- **Production code is never changed to make a test pass or to make a test possible.** If a parameter
  cannot be overridden from the suite, the test works around the default — say so in the plan. This is
  distinct from the reuse gate in step 7, which *does* change production code to avoid duplication.
- **Name the one unproven assumption** and put validating it first. If a plan has none, say so
  explicitly rather than omitting the section.
- Every step is anchored with `file:line`, and the plan notes that line numbers drift.
- Do not implement, commit, or run the build. Hand off to `GR-implement-tdd`.
