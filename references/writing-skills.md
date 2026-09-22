# Writing skills for this suite

How to write, review, and prune a skill in `GR-ai-agents`. For prose a teammate reads, see
[`writing-for-people.md`](writing-for-people.md) instead. Read this before adding a skill or
editing one that has grown.

The vocabulary and the cutting tests below are adapted from Matt Pocock's `writing-great-skills`
(<https://github.com/mattpocock/skills>), rewritten for this stack. The full comparison of what was
adopted and what was deliberately rejected lives outside this repo, in
`${HOME}/gitroot/.scratch/GR-skill-suite/`.

## The root virtue is predictability

A skill is good when the agent takes the **same process** every run — not when it produces the same
output. Every rule below serves that. When two rules conflict, ask which one makes the next run more
like the last one.

## Two budgets, priced very differently

This is the single most useful thing to internalise, because it is counter-intuitive:

| | Loaded when | Cost |
|---|---|---|
| `name` + `description` | **Every turn of every session, forever** | Paid whether or not the skill ever fires |
| SKILL.md body | Only when the skill triggers | Paid per use |
| `references/*.md` | Only when the body points at it and the agent follows | Paid rarely |

So a 40-line body is a smaller problem than a 70-word description. **Prune the description hardest.**
A body that is long because the procedure genuinely has eight steps is fine; a description carrying
five phrasings of the same trigger is not.

The exception worth knowing: a skill that triggers on nearly every task has a body that is
*effectively* always resident too. Those bodies deserve the same scrutiny as a description.

**Compare against the free tier before writing anything.** `CLAUDE.md` is auto-loaded in every
session at no marginal cost, and a repo's own `docs/` sits one read away. A skill whose content
could live in either of those is strictly dominated: it pays a permanent description to deliver
what an already-open file delivers for nothing.

### Writing the description

- Lead with the verb and the leading word. "Ground work in an Evo repo…", not "This skill helps
  you…".
- List **genuinely distinct** trigger branches. "before asking a question, writing a spec or plan,
  executing a plan, reviewing a diff, or debugging" is one branch — *any work here* — wearing five
  costumes. Pick the shortest phrasing that covers them.
- Do not restate identity the body already carries. The description exists to answer *should I open
  this?*, nothing more.
- Say when another skill should reach for it, if that is the point of the skill. That sentence is
  what makes a primitive reachable.

## Invocation: pick one deliberately

- **Model-invoked** (no flag): the agent can find it alone, and **other skills can invoke it**. Costs
  context load forever — worth it only for a shared *procedure* other skills genuinely run.
- **User-invoked** (`disable-model-invocation: true`): costs zero context; only a human typing its
  name reaches it. Correct for the workflow entry points — `GR-brainstorming`, `GR-tdd`,
  `GR-implement-tdd`, `GR-commit`.

The trap that has already bitten this suite once: **a user-invoked skill is invisible to other
skills.** Flagging a primitive breaks every call site silently — the callers keep saying "use X" and
nothing happens. If any skill names it, it must stay model-invoked.

## Primitive and wrapper

One behaviour, one file, many entry points. A primitive holds the shared procedure and is
model-invoked; wrappers are user-invoked and add their own phase around it.

**Extract a procedure; duplicate a sentence.** This is the gate, and it is stricter than it sounds.
A multi-turn procedure — an interrogation loop, a red/green cycle — earns a primitive. A habit that
fits in one sentence does not: the permanent description plus the invocation hop cost more than a
second copy of the line. Upstream, `tdd` and `diagnosing-bugs` each carry their own copy of the
"read `CONTEXT.md`, respect the ADRs" sentence rather than share one. That duplication is the
cheaper trade, and it was chosen deliberately.

Extracting is also only a win **if the callers get shorter**. A primitive that adds 30 lines while
every caller still restates the procedure is a net loss — two copies that will disagree, and double
the context when both load. Delete from the callers in the same edit that creates the primitive, or
don't extract yet.

`GR-ground` failed both tests and was removed. It is worth knowing why, because the shape recurs:
it wrapped a one-sentence habit, its opening step duplicated a fact `gitroot/CLAUDE.md` already
auto-loads, and its closing step ("read the code") was a no-op the agent does by default.

## The cutting tests

Run these over any skill that feels long. Delete whole sentences, not words — a trimmed no-op is
still a no-op.

1. **No-op test.** Does this line change behaviour versus the agent's default? "Be thorough",
   "read carefully", "use good judgement" are already the default. Cut.
2. **Duplication test.** Does this fact live anywhere else — another skill, a `CLAUDE.md`, a
   reference? Then it belongs in exactly one of them and the other should point. Two copies is a
   drift bug with a delay fuse.
3. **Volatility test.** Will this line be false in a month? Enumerated state goes stale — "only
   GR-gateway and GR-ice-signaler are migrated" is a fact the filesystem already knows. State the
   *rule* ("read `docs/agents/testing.md`; where it is missing, fall back to the stack defaults")
   and let the check answer it.
4. **Audience test.** Is this addressed to the agent running the skill, or to the human maintaining
   it? Architecture notes, rationale for the split, history — those belong in `CLAUDE.md` or a
   reference, not in the body the agent loads.
5. **Sediment test.** Was this added for a failure that no longer happens? Old content settles and
   quietly stops being relevant.
6. **Branch test.** Does *every* run need this, or only some? Material only some runs need goes into
   `references/` behind a pointer. The pointer's wording, not the file, decides whether the agent
   actually reaches it — "read X when Y" beats "see also X".

## Steering

- **Prompt the positive.** Naming a behaviour to forbid it makes it more available, not less. State
  the target behaviour. Keep a prohibition only where it is a hard guardrail with no positive
  phrasing, and pair it with what to do instead.
- **Completion criteria must be checkable.** A step ends when a stated condition holds, not when the
  agent feels done. "Produce a change list" invites stopping early; "every modified behaviour
  accounted for, with the command that proves it" does not. Visible later steps pull the agent
  toward finishing the current one early — a concrete criterion is the counterweight.
- **Explain why, once.** A reason lets the agent generalise to the case you did not write down. One
  clause attached to the rule; not a paragraph per step.

## Before you commit a skill edit

- Description: count the words. Falling is good.
- Every fact in the body: exists in exactly one place.
- Every prohibition: rephrased positively, or justified as a guardrail.
- Every step: ends in a condition someone could check.
- If a primitive was extracted: its callers shrank in the same edit.
