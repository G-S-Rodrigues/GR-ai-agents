---
name: GR-implement-tdd
disable-model-invocation: false
description: Execute an existing implementation plan from ~/gitroot/.scratch/<feature>/plans/ test-first — red, green, verify, per step. Use when the user asks to implement, execute, or carry out a plan, or says the plan is approved and to build it.
---

# Evo Implement TDD

Execute one plan file. Evidence before claims, always.

## Invoked by `GR-manage`

When a coordinator dispatched this, **the approval gates below are the manager's and are already
satisfied** — do not stop for them. Escalate instead of asking: report what needs deciding and wait,
rather than choosing.

Invoked by the owner, every gate is unchanged. One skill, two callers — never a second copy.

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
from it. Before dispatching an implementing agent, and whenever your context passes 170k, read
`~/.claude/GR-references/context-budget.md`: the dispatcher watches each agent's budget and puts the
budget clause in its prompt, and that file has the thresholds, the handoff file and how to resume.

## 2. Per step: RED → GREEN → verify

The repo's own `docs/agents/testing.md` names the commands this section runs: a single test, the
per-step suite, and the **done gate** — the one command that defines done, often restated as "the
rule" in the repo's `CLAUDE.md`, run once before §5's claim. Run them in the container and working
directory the repo's `CLAUDE.md` names. Where the repo has no `testing.md`, fall back to
`~/.claude/GR-references/working-in-the-devcontainer.md`.

**RED.** Write the test. Run it. **Paste the failure output.** If you did not watch it fail, you do not
know it tests the right thing.

A runner that cannot fail, or that runs an installed copy instead of your edits, reports success on
nothing at all. Before trusting the first run, confirm its exit code reflects failures and that it
runs the working tree. The Evo ROS2 repos' `test/setup/run_tests.sh` has both traps;
`working-in-the-devcontainer.md` has the command that defeats them.

Confirm the failure is the *expected* one. A test failing for the wrong reason (import error, QoS
mismatch, wrong topic) is not RED — fix the test first.

**GREEN.** The minimal change that satisfies the test. Nothing speculative.

**Verify.** Run the test again, then the rest of the suite once, immediately before the commit gate
— not after every RED/GREEN iteration in between.

- RED and GREEN confirmation run the single test being worked on, directly, with the single-test
  invocation `testing.md` documents (`pytest -k`, `--gtest_filter=`, `launch_test <file>`, Robot
  `--test <name>`) — not the suite. These runs are short; read their output directly.
- The regression run happens once per step, with the command `testing.md` names for per-commit
  verification (the pre-commit gate, where one exists). Keep its log out of context: pipe it through
  `tail`, or use `${HOME}/gitroot/GR-ai-agents/scripts/run_tests_summary.sh` where the repo runs
  `run_tests.sh`.
- If that output shows a failure whose cause isn't immediately obvious, dispatch the
  `test-failure-triage` subagent with the summary (or the log path) rather than reading the full log
  inline — it returns the failing test, the error text, and a likely-cause category in a few lines.

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

A review pass means: re-read the diff against the plan's steps and acceptance criteria, run the
repo's lint gate over all files, and report what does not match. `docs/agents/lint-and-precommit.md`
names the gate; where that file is absent, run `pre-commit run --all-files` in the container if the
repo has a `.pre-commit-config.yaml`.

## 5. Before any completion claim

1. **Identify** the command that proves the claim. For "done", that is the done gate (§2).
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
