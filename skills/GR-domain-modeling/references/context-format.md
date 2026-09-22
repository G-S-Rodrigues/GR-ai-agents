# CONTEXT.md format

Adapted from Matt Pocock's `CONTEXT-FORMAT.md`. Applies to both tiers — a repo's `CONTEXT.md` and the
workspace-wide `stack-glossary.md` use the same format.

## Structure

```md
# {Repo or context name}

{One or two sentences: what this context is and why it exists.}

This file is a **glossary and nothing else**. No commands, no file paths, no how-it-works — those
live in `docs/agents/`. Decisions live in `docs/adr/`.

## Language

**Robot ID**:
The fleet's identifier for a single robot. Resolved through config — a ROS2 parameter with a
`ROBOT_ID` env override — never a literal in source.
_Avoid_: robot number, unit id, serial

**Session**:
One live WebRTC connection between a viewer and a robot, from negotiation to teardown. Sessions do
not survive a signaler restart.
_Avoid_: call, stream, connection

## Flagged ambiguities

- **"map" alone is overloaded** — it has meant the relay, the request, and the payload. Use **Map
  relay**, **Map request**, or *map point cloud*; never bare "map" for a mechanism.
```

## Rules

- **Be opinionated.** Where several words compete for one concept, pick one and list the rest under
  `_Avoid_`. A glossary that records the disagreement instead of settling it has done nothing.
- **Define what it is, not what it does.** One or two sentences. A definition that needs a code
  sample is a `docs/agents/` entry wearing a glossary's clothes.
- **Only terms specific to this domain.** Robot ID, Map relay, Viewer, Session — yes. Timeout, retry,
  callback, QoS profile — no, those are ROS2 and general programming vocabulary, however often the
  project says them.
- **Local terms only.** A term two or more repos must agree on goes in
  `~/.claude/GR-references/stack-glossary.md` instead, and appears in exactly one of the two files —
  never both.
- **Flagged ambiguities are load-bearing.** A word that caused a real misunderstanding is worth a
  line even before it has a settled definition — that is the record of what to sharpen next.
- **Group under subheadings** only once natural clusters appear. A flat list is fine, and usually
  right.

## UNCONFIRMED

A glossary seeded from documentation rather than from a conversation ends with:

```md
- **UNCONFIRMED** — this file was seeded from `docs/agents/` and `CLAUDE.md`, not from a session.
  Every term above is a proposal.
```

The note goes when the last proposal is confirmed or replaced, not before — and never as a tidy-up
pass over terms nobody has used yet.
