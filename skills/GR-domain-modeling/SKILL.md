---
name: GR-domain-modeling
description: Sharpen an Evo repo's domain language — challenge a fuzzy or overloaded term and record the resolution in CONTEXT.md. Use when a term is being defined or disputed, or when another skill needs the glossary maintained.
---

# Evo Domain Modeling

Sharpen the domain language *while* it is being decided, and write each resolution down the moment it
lands. Reading `CONTEXT.md` for vocabulary is not this skill — every workflow skill already does
that. This one runs when the model is **changing**.

## During the session

**Challenge against the glossary.** When a term is used against its recorded meaning, say so at once:
"`CONTEXT.md` defines Map relay as the whole path; you're using it for the encoding hop — which do
you mean?" A glossary nobody is held to is decoration.

**Sharpen what is fuzzy.** Overloaded words carry the bugs. Both repos already flag one: "map" has
meant the relay, the request, and the payload; "client" has meant the browser app, a socket.io peer,
and the gateway's own signaling client. When a word is doing more than one job, name the jobs and
make the user pick which one keeps the word.

**Stress-test with a scenario.** Invent the concrete case that forces the boundary: a viewer
reconnecting mid-relay, a second robot joining the same signaler, a map request arriving before SLAM
has published. Vague terms survive discussion; they do not survive a scenario.

**Cross-reference the code.** When the user states how something works, check. A contradiction is a
finding: "`config.py:47` resolves `robot_id` as a ROS param with an env override, but you're
describing it as fixed per-image — which is it?"

**Write it down inline.** The moment a term resolves, update `CONTEXT.md` — that turn, not at the
end. Batching is how a resolved distinction gets flattened back into whichever word survived. Format
in [`references/context-format.md`](references/context-format.md).

`CONTEXT.md` is a glossary and nothing else. No commands, no paths, no how-it-works — those are
`docs/agents/`. No decisions — those are `docs/adr/`. A term that needs a code sample to explain is
not yet a term.

## Which glossary a term belongs in

Two tiers, and the test is **does the term travel**:

| Tier | Holds | File |
|---|---|---|
| Stack | terms two or more repos must agree on | `~/.claude/GR-references/stack-glossary.md` |
| Repo | terms meaningful in one repo only | that repo's `CONTEXT.md` |

`Robot ID` travels — deployment, addressing, config, and tests all use it. `Relay port range` does
not; it is central to GR-ice-signaler and meaningless in GR-hal.

Decide the tier before writing, and say which you chose. A term written to both tiers is the failure
this split exists to prevent — the copies disagree eventually, and the local one wins by being
closer. Promoting a term from a repo glossary to the stack one means deleting it from the repo
glossary in the same edit.

Where a shared term is really a contract — a `robot_msgs` shape, a topic name, a QoS profile — the
glossary can name it but cannot hold it. Raise an ADR as well.

Artifacts go to `${HOME}/gitroot/.scratch/<feature>/`, as all per-feature work does — see
`~/.claude/GR-references/where-documents-go.md`.

## Clearing an UNCONFIRMED glossary

A `CONTEXT.md` seeded from documentation rather than from a conversation carries an **UNCONFIRMED**
note, and every term in it is a proposal. Both current glossaries are in this state.

Take the terms in the order the session touches them, not top to bottom — a term nobody is using is a
term nobody is ready to confirm. For each: confirm as written, replace it, or delete it as not
actually part of the domain. Drop the UNCONFIRMED note only when no proposals are left, and say what
was confirmed versus rewritten.

## Recording a decision

A resolution that is hard to reverse, surprising without context, and chosen over real alternatives
is an ADR, not a glossary entry. The gate and this stack's qualifying cases live in the repo's own
`docs/adr/README.md` — read it there rather than deciding from memory. Where a repo has no `docs/adr/`
yet, [`where-documents-go.md`](../../references/where-documents-go.md) carries the fallback gate.
Propose the ADR; do not write it silently.

## Done when

Every term resolved this session is written into every `CONTEXT.md` that holds it, and the ones left
unresolved are named as open rather than quietly dropped.
