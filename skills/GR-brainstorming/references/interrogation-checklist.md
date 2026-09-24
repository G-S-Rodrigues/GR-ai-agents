# Interrogation checklist

Dimensions to walk during Phase 1. Not a questionnaire to read out — cover the ones with live risk
and say which you skipped.

Each heading is tagged with how it usually resolves:

- **[ask]** — normally earns a blocking question. Contract shapes, and anything only the user knows.
- **[call]** — normally decided with a stated recommendation and shown in the round's batch. Escalate
  a specific item to a question only when it meets the triage test in `SKILL.md`.

The tag is the default, not the rule: a `[call]` dimension becomes an `[ask]` the moment the answer
is hard to reverse or the evidence is balanced, and an `[ask]` dimension is called when the codebase
already settles it.

## Blast radius [ask]

- Which repos does this touch? A change in one repo that shifts a topic, service, message, or port
  is a change in every repo that talks to it.
- Who else subscribes to / calls the thing being changed? Grep before assuming nobody.
- Does this cross the CPU/GPU split (`GR-perception` builds and deploys separately)?

## ROS2 contract [ask]

- Topic and service names: new, renamed, or reused? A rename is a breaking change for every
  consumer, and nothing flags it.
- **QoS**: reliable vs best-effort on both ends. A best-effort publisher never matches a reliable
  subscriber and the failure is silent — it looks like "no data", not an error.
- Message, service and action definitions are a contract. Changing one means rebuilding everything
  that depends on it, and a consumer that still compiles can read a field nothing sets any more.
- Node parameters: is the new knob a parameter, an env var, or a literal? Parameters that tests
  cannot override force the test to work around the default.

## Configuration and addressing [ask]

- Is anything derived from a configured identifier or a vehicle parameter? A value that disagrees
  with the thing it describes is invisible — the run completes and reports a plausible number.
- `ROS_DOMAIN_ID` and the RMW configuration — does this change cross-node visibility?
- Does behaviour differ per platform or per track? A change right for one is not automatically right
  for the other.

## Runtime and lifecycle [ask]

- What happens on restart? State held only in a process is gone, and a stale identifier held by
  something else outlives it.
- What happens when the thing being called is absent — service unavailable, no map yet, a pose
  source not yet publishing? Silent no-op or visible failure? A late-starting participant is a
  classic source of a latched fault at t=0.
- Rate limits and back-pressure: is anything throttled, and does the new path bypass it?
- Timing: does anything here read the clock, and does it use simulated time when the rest does?

## Safety [call]

- Can stale data be mistaken for fresh? A map, pose, or detection that persists after its source
  stopped is worse than no data at all.
- Does a failure surface, or does it degrade quietly into a plausible number?
- Is there a path where a safety stop latches with no fault anywhere in the logs?

## Build and test reachability [call]

- Does verification need the devcontainer? Claude runs on the host; the host has none of the toolchain.
- Does the test runner test the **installed** package rather than local edits, and does its exit
  code actually reflect a failure?
- Which tier can actually reach this — pure unit, integration, `.robot`, or only manual? What will
  stay unverified, and is that acceptable?
- Is there an existing test that this change will break? That is expected, not a regression — but it
  must be named up front.

## Duplication [call]

- Does something already do this, or nearly? Read before a new helper is assumed — this one is
  answered by the codebase, not by the user.
  See `~/.claude/skills/GR-tdd/references/reuse-and-dedup.md`.

## Deployment and rollback [call]

- Does this need a per-robot deploy (`deployment/deploy.sh`), an image rebuild, or just a restart?
- How is it rolled back on a robot in the field?
- Does it change anything provisioned once by `GR-robot-setup`?

## The implicit decisions [ask]

This dimension is never resolved by calling it, and it is the one to spend a question on when the
budget is tight. Always ask at least one of these — they are where "the whole picture" actually hides:

- What does choosing this shape *decide* that hasn't been discussed?
- What becomes hard to change later?
- What is being assumed constant that is actually somebody else's decision?
- If this is phase 1 of several, what does it commit the later phases to?
