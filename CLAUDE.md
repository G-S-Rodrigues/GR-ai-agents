# CLAUDE.md — working in GR-ai-agents

This repo holds the skills, not the robot code. They are for **`GR-roboracer` and the GR projects
after it**. Editing a skill changes how every teammate's agent behaves after their next `git pull`, so the bar is different from
ordinary code: a change is cheap to make and expensive to get wrong.

## Layout

```
skills/<name>/SKILL.md          ← installed by default
skills/<name>/references/*.md   ← progressive disclosure, loaded on demand
skills/in-progress/<name>/      ← drafts; NOT installed unless --with-drafts
agents/<name>.md                ← Claude subagents
hooks/                          ← hook scripts + the settings.json snippets that arm them
references/*.md                 ← shared material, installed to ~/.claude/GR-references/
scripts/{install,uninstall}.sh
```

**Two tiers, not five buckets.** Promoted (`skills/`) or draft (`skills/in-progress/`). The split
exists so a teammate can push a half-finished skill without changing anyone's installed set. Add
more buckets only when the flat list stops being readable.

Every skill installed by the script is a **symlink into this repo**. A teammate editing
`~/.claude/skills/GR-tdd/SKILL.md` is editing this repo's working tree — they'll see it in
`git status`. That's intended: it makes local hacks visible instead of silent.

## Adding or changing a skill

1. Start in `skills/in-progress/`. Install it with `--with-drafts` and use it on real work.
2. Promote by moving to `skills/` and adding a row to the `README.md` table.
3. `./scripts/install.sh` again after adding, renaming, or removing a skill — new entries need a new
   symlink. (Editing an existing skill needs nothing; the link already points at it.) Both
   installers glob `skills/*/` and `agents/*.md`, so there is no list to edit — but **promoting** a
   skill out of `skills/in-progress/` leaves a `--with-drafts` symlink dangling until
   `uninstall.sh` and `install.sh` are re-run.

## Writing skills that stay predictable

The goal of a skill is **predictability** — the agent taking the same process every run.

- **Invocation.** Model-invoked skills keep a `description` in every context window, forever. Pay
  that only when the agent must reach the skill on its own, or another skill must reach it. If only
  a human ever types its name, set `disable-model-invocation: true` and pay nothing.
- **Single source of truth.** One meaning, one place. Paths live in
  [`references/where-documents-go.md`](references/where-documents-go.md) — skills point at it rather than
  restating it. When you catch the same instruction in two skills, that's the signal to extract it.
- **Prompt the positive.** "Do not X" makes X more available, not less. State the target behaviour
  instead; keep a prohibition only as a hard guardrail you can't phrase positively, and pair it with
  what to do instead.
- **Cut no-ops.** A line the model already obeys by default costs tokens and says nothing. Test each
  sentence: does it change behaviour versus the default? If not, delete the sentence — don't trim it.
- **Completion criteria must be checkable.** "Produce a change list" invites stopping early; "every
  modified behaviour accounted for, with the command that proves it" does not.
- **Disclose reference.** Material only some runs need goes in `references/` behind a pointer, not
  inline in `SKILL.md`.

When the thing being written is prose a teammate reads rather than a skill — this repo's `README.md`,
a PR body, an ADR — the register is different, and
[`references/writing-for-people.md`](references/writing-for-people.md) is the authority on it. The
`GR-writing` skill runs it as a pass over an existing file.

Fuller treatment — the two context budgets, the six cutting tests, and the pre-commit checklist for
a skill edit — in [`references/writing-skills.md`](references/writing-skills.md). Read it before
adding a skill or editing one that has grown.

## Stack facts these skills assume

Changing any of these means changing skills, so they're recorded here rather than rediscovered:

- **Claude runs on the host; the toolchain does not.** Every build/test/lint command is
  `docker exec -it <container> bash -lc "source setup.sh && <command>"`. A skill that emits a bare
  `colcon build` is broken.
- **`${HOME}/gitroot` is not a git repo** — it's independent repos side by side. "The repo" always
  means one of them.
- **Two artifact trees.** Committed standing knowledge in `<repo>/docs/{agents,adr}` plus
  `CONTEXT.md`; per-feature work in
  `~/gitroot/.scratch/<feature>/{grill,spec,plans,review,ready,run,open_topics}/`. One location, and
  it sits outside every repo working tree so a `git clean -xdf` cannot reach it. Full rules in
  `references/where-documents-go.md`.
- **A run is driven from disk, not from a session.** `GR-manage` keeps the ledger and dispatches one
  subagent per stage; a fresh session resumes from the ledger alone. Anything a coordinator knows
  only in context is lost at its next compaction.
- **Agent docs have named consumers.** A skill names the file it needs — `repo-gotchas.md`,
  `testing.md`, `lint-and-precommit.md` — and the repo's `CLAUDE.md` carries the table pointing at
  them. A skill that says "read `docs/agents/`" is asking for a directory scan that will not happen.
- **Not every repo is migrated yet.** Where `docs/agents/` is missing, the fallback is
  `references/default-repo-rules.md` — check, don't assume. Which repos are done is a fact the
  filesystem already answers, so it isn't recorded here.

## Inventory

Installed skills: `GR-brainstorming`, `GR-tdd`, `GR-implement-tdd`, `GR-review`, `GR-rebase`,
`GR-pr`, `GR-commit`, `GR-domain-modeling`, `GR-manage`. Drafts: `GR-prospect` and `GR-squash-merge`
(both out of the loop, each saying why at the top of its `SKILL.md`), `GR-writing`, `matt-handoff`,
`matt-writing-great-skills`.

Agents: `GR-researcher`, `GR-inventory`, `GR-test-runner`, `GR-plan-worker`, `lint-fixer`,
`test-failure-triage`.

## Don't

- Don't commit anything robot-specific here — a fact about one repo belongs in that repo's
  `docs/agents/`, not in a skill. Skills describe *process*; repos describe *themselves*.
- Don't add a skill that near-duplicates an existing one. Extend the existing one, or extract the
  shared part into a reference both point at.
