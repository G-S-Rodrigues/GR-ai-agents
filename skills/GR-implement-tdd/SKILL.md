---
name: GR-implement-tdd
disable-model-invocation: false
description: Execute an existing implementation plan from .scratch/<feature>/plans/ test-first — red, green, verify, per step. Use when the user asks to implement, execute, or carry out a plan, or says the plan is approved and to build it.
---

# Evo Implement TDD

Execute one plan file. Evidence before claims, always.

## 1. Load and challenge the plan

Read the plan, `docs/agents/repo-gotchas.md` and `docs/agents/testing.md`, and the ADRs touching the
area — plus `CONTEXT.md` if it exists, so names match the domain language. Then review the plan
**critically before starting**:

- Does anything contradict what the code actually says now? Line numbers drift.
- Is the "one unproven assumption" still unproven? Validate it first, as the plan says.
- Any step whose instruction you cannot execute as written?

Raise concerns before writing anything. If none, say so and proceed.

Take the mode from the plan's `**Mode:**` line — do not re-decide it. In subagent mode, dispatch one
implementation subagent per step, each carrying `Do NOT change production code except as the plan's
Reuse decisions specify` and the step 2 commit instructions below, so each step is still committed by
the agent that made it, not batched up by the coordinator afterward.

If `<plan>-progress.md` exists beside the plan, a previous agent handed off: read it first and resume
from it. Every implementing agent works to a **~200k-token context budget**, handing off rather than
running past it; whoever dispatches one watches that budget.
[`references/context-budget.md`](references/context-budget.md) has how to watch it, the handoff
file's contents, and how to resume.

## 2. Per step: RED → GREEN → verify

**RED.** Write the test. Run it. **Paste the failure output.** If you did not watch it fail, you do not
know it tests the right thing.

This matters more here than in most codebases, because two things conspire to hide a test that tests
nothing:

- `test/setup/run_tests.sh` swallows failures without `RELEASE=true` (`robot ... || true`), so the
  exit code is meaningless in the default path.
- It sources `/opt/<pkg>/setup.bash` — the **installed** package, not your edits.

So a test that never ran red, run by a runner that cannot fail, against stale installed code, reports
success on nothing at all. `~/.claude/GR-references/working-in-the-devcontainer.md` has the command
that defeats both traps.

Confirm the failure is the *expected* one. A test failing for the wrong reason (import error, QoS
mismatch, wrong topic) is not RED — fix the test first.

**GREEN.** The minimal change that satisfies the test. Nothing speculative.

**Verify.** Run the test again, then the rest of the suite once, immediately before the commit gate
— not after every RED/GREEN iteration in between.

- RED and GREEN confirmation run the single test being worked on, directly (`--gtest_filter=`, Robot
  `--test <name>`, or whatever the repo's own `docs/agents/testing.md` documents) — not the full
  `run_tests.sh`. These runs are already short; read their output directly.
- The full-suite regression run happens once per step, via
  `${HOME}/gitroot/GR-ai-agents/scripts/run_tests_summary.sh` (see
  `~/.claude/GR-references/working-in-the-devcontainer.md`), which prints a condensed summary
  instead of the full log.
- If that summary shows a failure whose cause isn't immediately obvious from the condensed output,
  dispatch the `test-failure-triage` subagent with the summary (or the log path it printed) rather
  than reading the full log inline — it returns the failing test, the error text, and a likely-cause
  category in a few lines.

**Commit.** Once verify passes, commit the step before moving to the next one — one commit per step
keeps a rollback point if a later step goes wrong. Follow `GR-commit`'s scoping rules exactly:
`git branch --show-current` must not be `main` (stop and alert if it is — do not commit), stage only
the files this step touched (never `git add -A`), run pre-commit against the staged files and resolve
any failure the same way `GR-commit` does, and write a one-sentence message completing "This commit
...". Skip `GR-commit`'s approval gate for this commit only: plan execution already runs on a branch
made for this task, so a per-step commit is part of carrying out the plan the user approved, not a
change nobody signed off on. State the message and staged files after committing so the log stays
visible — don't pause for a reply. This exception lives here, not in `GR-commit`; a direct call to
`GR-commit` still asks for approval every time.

## 3. Never weaken the target

- Do not edit a test to make it pass.
- Do not change production code to make a test pass or to make a test possible — if a parameter cannot
  be overridden from the suite, work around the default, as the plan says.
- **Reuse-driven production changes are the exception**, and only as the plan's *Reuse decisions*
  section specifies. Those must leave existing tests green **without editing them**. If an existing
  test needs an edit, stop — it is a behaviour change, not a dedup.
- If a step cannot be done as planned, stop and say so. Do not improvise around a blocker.

## 4. Review gates

- **Full mode:** review at each phase boundary and at the end.
- **`quick` mode:** review at the end only.

A review pass means: re-read the diff against the plan's steps and acceptance criteria, run
`pre-commit run --all-files` per `docs/agents/lint-and-precommit.md`, and report what does not match.

## 5. Before any completion claim

1. **Identify** the command that proves the claim.
2. **Run** it fresh and complete.
3. **Read** the full output — exit code, failure count.
4. **Then** claim it, with the evidence.

A subagent's success report is not evidence. A diff is. "Should pass" is not a status.

## 6. Close out

- **Deviations** — write anything the plan got wrong back into the plan file, in a `## Deviations`
  section: what was planned, what was actually true, what was done instead.
- **New gotchas** — a trap that cost time and will cost it again goes into the repo's
  `docs/agents/`. Append to the file whose consumer already matches it. A new file needs a row in
  the repo's `CLAUDE.md` pointer table naming what to read it before — without that, nothing reaches
  it.
- **New decisions** — if implementation forced a choice that is hard to reverse, surprising without
  context, and had real alternatives, **propose** a numbered ADR in `docs/adr/`. All three must hold.
  Propose it; do not write it silently.
- Report what was implemented, the verification output, and anything left undone.
- Each step already committed itself in step 2. If anything is still uncommitted at this point (e.g.
  close-out edits made outside a step), hand off to `GR-commit` for an approval-gated commit — do not
  commit those from here.
