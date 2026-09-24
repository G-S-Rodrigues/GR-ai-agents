# GR-ai-agents

Skills, subagents, hooks, and scripts for `GR-roboracer` and the GR projects after it: the shared
discipline the team's coding agents run on.

## Purpose

This repo defines how we work with AI agents on this stack. It gives them a workflow to follow and
the constraints that make them behave like a teammate who already knows the robots.

Out of the box an agent knows generic software engineering, not ours. It will run `colcon build` on
the host where nothing is installed, write a test that never ran red against a runner that cannot
fail, or reach for a Python unit test where the behaviour only shows up through Robot Framework. The
skills here teach it three things:

- **Test-driven development the way this stack actually tests.** Which behaviour belongs in a unit
  test and which is only reachable from the `.robot` tier, and that a test is worth nothing until you
  have watched it fail — against a runner whose exit code actually reflects failures, which is not
  something to assume.
- **Development inside the devcontainer.** The toolchain lives in a container and the host has none
  of it, so every build, lint, and test command goes through `docker exec`, with a wrapper that
  starts the container without dumping a whole image build into the conversation.
- **A workflow with handoffs.** Grill, plan, review, implement, review, rebase, PR. Each stage
  writes its artifact to disk, instead of one long session that silently does all of it — and a
  coordinator can drive the whole loop from those artifacts rather than from its own memory.

The main point is to state the stack constraints that are expensive to rediscover, once, in a place
every agent reads. Nobody has to re-explain them at the start of every session, and no agent burns a
dozen tool calls working out something we already know the answer to.

## Install

```bash
git clone git@github.com:G-S-Rodrigues/GR-ai-agents.git ~/gitroot/GR-ai-agents
cd ~/gitroot/GR-ai-agents && ./scripts/install.sh
```

Skills and references are **symlinked** into `~/.claude/` and `~/.codex/`, so `git pull` updates
them. Re-run `install.sh` only after adding, renaming, or removing a skill. Flags: `--dry-run`,
`--with-drafts` (also installs `skills/in-progress/*`), `--claude-only`. Anything real already at a
target path is moved to `~/.GR-ai-agents-backup/<timestamp>/`, never deleted.
`./scripts/uninstall.sh` removes only symlinks pointing into this repo.

On Windows, use `scripts\install.ps1` / `scripts\uninstall.ps1` (same flags, PascalCase:
`-DryRun`, `-WithDrafts`, `-ClaudeOnly`). Directories link as symlinks (or a junction if the
process can't create symlinks); agent files link as symlinks (or a hardlink as fallback). A
hardlinked agent file breaks if something replaces it via rename instead of editing in place
(`sed -i`, some editor atomic-saves) — re-run `install.ps1` if an agent stops updating on
`git pull`. For real symlinks every time, enable Developer Mode (Settings > Privacy & security >
For developers) and run from a normal terminal, or run `install.ps1` once as Administrator.

The statusline installs separately, since it edits `settings.json`: `./scripts/statusline_install.sh`.

## The loop

You discuss goals in chat and run `/GR-brainstorming` once. It produces an issue and a spec split
into numbered parts. From there `GR-manage` carries each part round the ring — plan, review, build,
review, rebase, land — and stops only for a decision that genuinely blocks.

```
   you: goals in chat ──▶ GR-brainstorming ──▶ issue + spec in numbered parts
                                                      │
                    ┌─────────────────────────────────▼────────────────────┐
                    │              GR-tdd  ──▶  GR-review (plan)           │
                    │                 ▲                   │                │
                    │                 │                   ▼                │
   GR-manage ◀─────▶│           GR-rebase           GR-implement-tdd       │
   (Opus, thin,     │          (restack, gate)            │                │
    ledger on disk) │                 ▲                   ▼                │
                    │               GR-pr  ◀──────  GR-review (branch)     │
                    │        land: CI ║ Copilot ║ nightly ──▶ rebase-merge │
                    └──────────────────────────────────────────────────────┘

   escalation ──▶ blocking?  halt + notify the owner
                  otherwise  open_topics/ + the PR body

  GR-domain-modeling: any stage, whenever a term turns out to be doing two jobs
  GR-researcher / GR-inventory / GR-test-runner / GR-plan-worker / lint-fixer /
    test-failure-triage: subagents the skills dispatch
```

`GR-manage` sits outside the ring because it produces no artifact of its own except the ledger. That
is the rule for anything added later: a stage goes **inside** the ring only if it writes to
`~/gitroot/.scratch/<feature>/`. Anything that only decides belongs to the coordinator.

The ledger is what makes the resident session optional. Every ruling, SHA and open topic is written
to disk before the next dispatch, so a fresh session resumes a run it did not start — and a
compaction costs nothing that mattered.

Artifacts land in `~/gitroot/.scratch/<feature>/{grill,spec,plans,review,ready,run,open_topics}/`,
where `<feature>` is the branch name. One location, outside every repo working tree, so a
`git clean -xdf` inside a repo cannot reach a run's plans or its ledger. Standing knowledge goes instead to `<repo>/docs/{agents,adr}/` and
`CONTEXT.md`. Full rules in [`references/where-documents-go.md`](references/where-documents-go.md).

## Skills

Installed by default (`skills/`). You invoke these by typing `/<name>`, except `GR-domain-modeling`
and `GR-commit`, which the agent can also reach on its own.

| Skill | What it does | Use it when |
|---|---|---|
| [`GR-brainstorming`](skills/GR-brainstorming/) | Grills an idea across every dimension, but spends your turns only on what is hard to reverse or only you know — the rest it decides out loud for you to veto. Parks every design thought until the branches are resolved, checkpoints a digest per round, then offers genuinely different options. | You have an idea and want it stress-tested, before any spec or plan exists. |
| [`GR-tdd`](skills/GR-tdd/) | Turns an idea, spec, or grill digest into a test-first plan: test tiers, a reuse gate against existing code, the one unproven assumption named. Writes the plan file and stops. | A direction is settled and you want the implementation planned. It never implements. |
| [`GR-implement-tdd`](skills/GR-implement-tdd/) | Executes one plan file step by step: RED with the real failure output pasted, GREEN, verify, commit that step. | A plan is approved and you want it built. Point it at the plan path. |
| [`GR-commit`](skills/GR-commit/) | Stages only the files belonging to this change, runs pre-commit on that same scope in the devcontainer, and proposes a one-sentence message completing "This commit ..." for your approval. | Committing anything. It refuses to commit on `main`. |
| [`GR-domain-modeling`](skills/GR-domain-modeling/) | Challenges a fuzzy or overloaded term against a concrete scenario and writes the resolution into `CONTEXT.md` that same turn. | A word is doing two jobs, such as "map" or "client". Other skills reach for it automatically. |
| [`GR-pr`](skills/GR-pr/) | Drafts the PR body and opens it once its text is approved, then lands it: waits for CI and the Copilot review, fixes the valid comments test-first, replies on each, and rebase-merges on green. | The done gate passed on the branch and it is ready to publish. |
| [`GR-review`](skills/GR-review/) | Interrogates one artifact before it goes on: `target: plan` checks a plan is test-first and settles nothing the spec left open — the approval a plan gets under a coordinator — and `target: branch` runs blast radius across the repo's packages, then correctness. | A plan is written, or a branch is finished and its PR is not open yet. |
| [`GR-rebase`](skills/GR-rebase/) | Brings a branch onto current `main` — with `--onto` when restacking on a rebase-merged predecessor — chooses `--full` or `--ci` by a mechanical rule, and records which ran at which branch and `main` SHA. | Review is clean, or a predecessor just merged underneath you. |
| [`GR-manage`](skills/GR-manage/) | Drives a spec's parts from plan to merged PR: one subagent per stage, every ruling and SHA written to a ledger on disk before the next dispatch, and a mechanical pre-PR diff check that halts on a baseline, a tolerance or a removed assert. | You have a spec in numbered parts and want it built without a reply per stage. |

### Drafts (`skills/in-progress/`, install with `--with-drafts`)

| Skill | What it does | Use it when |
|---|---|---|
| [`GR-prospect`](skills/in-progress/GR-prospect/) | Scopes a GitHub issue across repos before design. **Out of the loop:** it scopes across repos, which the issue and part list from `GR-brainstorming` now cover. | A cross-repo issue, by hand. |
| [`GR-squash-merge`](skills/in-progress/GR-squash-merge/) | Checks the ready record is still live, then squash-merges each repo in contract order. **Out of the loop:** squash-merging erases the per-step history that rebase-merge exists to keep. | Landing a multi-repo issue by hand. |
| [`GR-writing`](skills/in-progress/GR-writing/) | Writes a new document, or rewrites an existing file or pasted text, following the shared prose directives: cut first, then reword, then check for the signatures that read as machine-written. | A README, PR body, ADR, or reply needs to read like a person wrote it. |
| [`matt-writing-great-skills`](skills/in-progress/matt-writing-great-skills/) | Reference on skill design: invocation cost, the information hierarchy, completion criteria. | Writing or pruning a skill. Pairs with [`references/writing-skills.md`](references/writing-skills.md). |
| [`matt-handoff`](skills/in-progress/matt-handoff/) | Compacts the current conversation into a handoff doc for a fresh session, referencing artifacts by path instead of duplicating them. | A session is getting long and the work needs to continue elsewhere. |

## Subagents

The skills dispatch these, and you can also call them by name. Each is read-only or narrowly bounded,
so its raw output never lands in the main conversation.

| Agent | What it does |
|---|---|
| [`GR-researcher`](agents/GR-researcher.md) | Grounded codebase facts with `file:line` anchors, patterns to imitate, and unproven assumptions. Proposes no designs. |
| [`GR-inventory`](agents/GR-inventory.md) | Mechanical test inventory: files, runner, test-ID numbering in use, current coverage. Lists only. |
| [`lint-fixer`](agents/lint-fixer.md) | Fixes one failing report-only pre-commit hook (pyrefly, clang-tidy, shellcheck) in bounded attempts, re-verifying with that hook. Escalates instead of guessing. |
| [`GR-test-runner`](agents/GR-test-runner.md) | Runs one repo's suite in its devcontainer on an assigned `ROS_DOMAIN_ID` and reports pass/fail with the real output tail. Lets a multi-repo run fan out in parallel. |
| [`GR-plan-worker`](agents/GR-plan-worker.md) | Implements one part of a plan by running `GR-implement-tdd` on it, escalating rather than deciding on an ADR, a ROS contract, a baseline, a tolerance or a deviation. Also applies review-comment fixes. |
| [`test-failure-triage`](agents/test-failure-triage.md) | Pulls the failing test name, error text, and likely cause out of a test log. |

## References, scripts, hooks

Shared material installed to `~/.claude/GR-references/`:
[`where-documents-go`](references/where-documents-go.md), the single source of truth for paths;
[`default-repo-rules`](references/default-repo-rules.md), the fallback conventions for a repo with no
`docs/agents/` yet; [`working-in-the-devcontainer`](references/working-in-the-devcontainer.md);
[`stack-glossary`](references/stack-glossary.md); [`writing-skills`](references/writing-skills.md),
for authoring a skill; [`writing-for-people`](references/writing-for-people.md), for prose a teammate
reads.
[`context-budget`](references/context-budget.md) is the 200k-token rule every agent works to, and
`scripts/context_watch.sh` is the watch a coordinator runs to enforce it. A reference no session is
told to read is never read, so add this line to your `~/.claude/CLAUDE.md`:

```markdown
- Every session and every subagent works to a 200k-token context budget. Before dispatching a subagent or driving another session, and when your own context passes 170k, read `~/.claude/GR-references/context-budget.md`.
```

Scripts: `devcontainer_up.sh <repo>` starts a container without streaming its build log.

[`hooks/`](hooks/) is the agreed home for hook scripts and is empty so far. A hook ships with the
`settings.json` snippet that arms it, which you paste yourself, since the installer never touches
that file. [`statusline/`](statusline/statusline.sh) is vendored from
[daniel3303/ClaudeCodeStatusLine](https://github.com/daniel3303/ClaudeCodeStatusLine) with local
changes, and renders `CWD 🌿 Branch → Model → Tokens → Effort → Session → 5h → 7d → +/-`.

## Contributing

[CLAUDE.md](CLAUDE.md) is the working agreement. Short version: drafts start in
`skills/in-progress/`; promoting one means moving it to `skills/` and adding a row above and in
CLAUDE.md's inventory; extend an existing skill rather than adding a near-duplicate. Both installers
glob, so a new skill or agent needs no installer edit — but re-run `install.sh` so the symlink
exists.
