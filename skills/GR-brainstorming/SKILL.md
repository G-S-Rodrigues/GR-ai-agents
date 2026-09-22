---
name: GR-brainstorming
disable-model-invocation: true
description: Interrogate an idea before designing it — challenge assumptions, expose what hasn't been considered, then present genuinely different options and a recommendation. Use when the user has an idea, plan, or approach and wants it questioned, stress-tested, grilled, pressure-tested, challenged, explored, or brainstormed, or wants to choose between approaches. Also use before writing a spec.
---

# Evo Brainstorming

Interrogate first, recommend second. The job is to surface what the user has not thought about — not
to agree, and not to reach a recommendation quickly.

Cover every dimension; spend the user's turns only on the decisions that need them. What is hard to
reverse or turns on a fact only they hold gets **asked**; everything else gets **called** — decided
out loud with its consequence, for them to veto.

Announce the depth chosen (see **Depth**) in one line before the first question.

## Phase 0 — Ground

Name the repos in scope, then read `docs/agents/repo-gotchas.md` in each and the code the idea
touches, so questions land on what is actually there. Read `CONTEXT.md` if it exists and use its
vocabulary in every question; respect the ADRs in the area — where the idea contradicts one, that
contradiction is itself a question to put to the user.

Never ask anything this reading answers. For facts from an area you have not read, dispatch
`GR-researcher` instead of asking the user.

## Phase 1 — Grill

The main phase. Its purpose is extraction, not agreement — and every dimension gets covered whether
or not it costs a question.

### Triage before asking

An item earns a **blocking question** when at least one holds:

- it is hard to reverse once built — a topic, message, service, parameter, or deployment contract;
- it turns on a fact or priority only the user holds — field experience, a teammate, a schedule, how
  a robot actually behaves;
- the options differ materially in cost or scope and nothing in the codebase favours either;
- the answer would contradict `CONTEXT.md` or an ADR.

Everything else you **call**: state the decision, why, and what it rules out in one line, and keep
going in the same turn.

Target **≤6 blocking questions** at full depth. Ask a seventh when it genuinely meets the test above,
and say in one line why it was worth the round trip. The budget exists to cut ceremony, not coverage:
a dimension you skip is still named as skipped, and a dimension you resolved by calling it is still
shown.

### Rounds, not turns

One message per round: the calls made for that group of dimensions, then that round's blocking
questions.

- **Calls are batched, and silence is agreement.** The user vetoes by naming a line; unnamed lines are
  recorded as agreed. Continue without waiting for an acknowledgement.
- **Each blocking question carries your recommended answer** — your best inference, so the user can
  confirm, correct, or redirect. Faster for them, and it exposes where your model is wrong.
- **Resolve dependencies in order.** A round only touches items independent of an unanswered blocking
  question. Settle the upstream decision first, and walk each branch to its end before starting the
  next.
- **Checkpoint once per round**, before the next round's questions. The file on disk is the source of
  truth, not this conversation.
- When a later answer invalidates an earlier call, say so and correct it in the digest.

### While grilling

- **Do not agree by default.** For every answer, state what it commits them to and what it rules out.
  If an answer contradicts an earlier one, say so.
- Calls and recommended answers are allowed at the **question** level (scope, facts, priorities,
  trade-offs). Neither is allowed at the **design** level — which approach to take belongs to Phase 2.
- **The parking rule.** If a design or recommendation starts forming, append it to the digest's
  `## Parked hypotheses (not yet offered)` section. Do not say it. Phase 2 starts from that list.
- **A disputed term is its own question.** When a word turns out to be doing two jobs, or to
  contradict `CONTEXT.md`, use `GR-domain-modeling` and settle it there — the glossary gets written
  that turn, not at graduation. **Exception: defer the file write when the term names something that
  does not exist yet.** A term whose referent is a topic, file, or flag the grill has only just
  decided to create would be documented as fact while the code still contradicts it — write it at
  graduation instead, and say in one line that you are deferring and why, so the skip is visible
  rather than silent. Settling the term is still Phase 1's job; only the write moves.
- **Unanswerable → flag it and move on.** Record the open item with its owner: a teammate, a robot to
  test on, a doc, or "needs code reading" → `GR-researcher`. Do not stall on a gap.
- Walk the dimensions in `references/interrogation-checklist.md`, which marks which ones are usually
  called and which usually earn a question. Skip ones that plainly do not apply; say which you
  skipped.
- Before exiting, ask the completeness backstop: "anything we haven't touched that should be in here?"

## The gate

Phase 2 does not open until every branch is either **resolved** — called or answered — or
**owner-flagged**. State the gate out loud with both counts before proceeding, so under-asking is as
visible as under-grilling:

```
Gate: 9 called, 5 asked, 2 flagged (QoS behaviour → test on G1; peer limit → ask <teammate>).
Opening options.
```

If you find yourself wanting to recommend before the gate, that is the parking rule's job.

## Phase 2 — Options

Start from the parked hypotheses.

- 2–3 **genuinely different** options — not three flavours of the same design. Include a smaller
  change, reuse of existing behaviour, or doing nothing when credible.
- For each: what it costs, what it risks, what it forecloses.
- Recommend the simplest option that satisfies the goal, and say what evidence would change the
  recommendation. If one option is clearly better, say so — do not manufacture balance.

## Phase 3 — Spec

Only when the user asks for one. Write it with `references/spec-template.md` to
`<scratch>/<feature>/spec/<date>-<summary>.md` — see **Where artifacts go**. Then stop — do not plan or
implement. `GR-tdd` owns the plan.

## Depth

- **Default: full.** Phases 0–2, ≤6 blocking questions, digest file on disk.
- **`quick`** (also "quickly", "fast", "just give me a second opinion"): bound Phase 1 to ~2
  shape-changing questions and call the rest in one batch, keep the adversarial stance, skip the
  digest, go to options.

Announce which you chose and why in one line, so under-grilling is visible and the user can escalate.
Scale to the task — a lint fix does not get six questions. Bias toward covering more dimensions, and
toward resolving them by calling rather than asking.

## Where artifacts go

Read `~/.claude/GR-references/where-documents-go.md` — it is the single source of truth for the grill,
spec, and plan paths. Resolve `<scratch>` and `<feature>` **once**, in Phase 0, and state the choice
in one line before the first question.

## Digest file

Full mode only: `<scratch>/<feature>/grill/<date>-<summary>.md`. Create it with the header
before the first question and say the path in one line.

```markdown
# Grill: <topic>
**Date:** YYYY-MM-DD

## Summary / key decisions
(running synthesis — the TL;DR of everything settled so far)

## Called without asking
(decided with a stated recommendation and not vetoed — one line each)
- <topic>: <decision> — <why>; rules out <consequence>

## Q&A log
### Q1 — <topic>
- Asked: <question>
- Answer: <facts and decisions, their words verbatim where the wording matters>
- Commits to / rules out: <consequence>

## Parked hypotheses (not yet offered)
- <forming recommendation, held until the gate>

## Open flags
- <item> -> <owner>
```

Keep `Summary / key decisions` current, and correct earlier entries when a later answer changes them.

## Graduation

At the end, **propose** — never apply silently — promoting what is reusable out of scratch and into
the committed tree:

- a trap that will cost time again → the file in that repo's `docs/agents/` whose consumer matches
  it; a new file also needs a row in that repo's `CLAUDE.md` pointer table, or nothing will read it
- a **decision** that is hard to reverse, surprising without context, and the result of a real
  trade-off → a new numbered ADR in that repo's `docs/adr/`. All three must hold; miss one and skip
  it. The grill's `## Summary / key decisions` is the raw material — a decision that survived the
  gate is often exactly this.
- a term still unsettled → `GR-domain-modeling`; the ones resolved mid-session are already written
- a standing preference → a memory
- a gap in one of these skills → an edit to it

This is how `docs/agents/` and `docs/adr/` grow as a side effect of work already being done.

## Rules

- Question constructively; never disagree merely to look critical.
- Evidence from the codebase beats speculation.
- Do not re-ask what has been answered.
- Do not write a spec, plan, commit, or code unless asked — say when you have enough for one and let the user call it.
