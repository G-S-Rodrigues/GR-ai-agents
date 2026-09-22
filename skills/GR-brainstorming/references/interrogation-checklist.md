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

- Topic and service names: new, renamed, or reused? A rename is a fleet-wide breaking change.
- **QoS**: reliable vs best-effort on both ends. A best-effort publisher never matches a reliable
  subscriber and the failure is silent — it looks like "no data", not an error.
- Message/service/action definitions live in `GR-ros2-messages` and are installed image-wide at
  `/opt/ros_custom_msgs`. Changing one means rebuilding every dependent repo's image.
- Node parameters: is the new knob a parameter, an env var, or a literal? Parameters that tests
  cannot override force the test to work around the default.

## Fleet and addressing [ask]

- Is anything derived from `robot_id`? WebRTC port ranges are (`8000 + robot_id` WHEP TCP,
  `9000 + robot_id` video UDP) and must be router-forwarded per robot.
- `ROS_DOMAIN_ID` and `cyclonedds.xml` — does this change cross-node visibility?
- Does behaviour differ per robot model (G1 vs GO2W)? `GR-hal` adapters and `GR-slam` launch files
  are per-model; a change in one is not automatically right for the other.

## Runtime and lifecycle [ask]

- What happens on reconnect or restart? A signaler container restart currently drops live WebRTC
  sessions and the controller's stored robot `peer_id` goes stale.
- What happens when the thing being called is absent — service unavailable, no map yet, robot
  disconnected? Silent no-op or visible failure?
- Rate limits and back-pressure: is anything throttled, and does the new path bypass it?
- Payload size: is there a frame or buffer ceiling in the way (engine.io `maxHttpBufferSize`)?

## Operator safety [call]

- Can a new control steal keyboard focus while the operator is driving? WASD is bound for locomotion —
  a focusable slider or button can swallow movement keys.
- Can stale data be mistaken for fresh? A map, pose, or detection that persists after its source
  stopped is worse than an empty panel.
- Can the operator act on stale data — download it, send it, act on a stale position?

## Build and test reachability [call]

- Does verification need the devcontainer? Claude runs on the host; the host has none of the toolchain.
- Does the test runner test the **installed** package rather than local edits? (`run_tests.sh` sources
  `/opt/<pkg>/setup.bash` in the ROS2 repos.)
- Which tier can actually reach this — pure unit, in-repo `.robot`, `GR-tests` cross-repo, or only
  manual? What will stay unverified, and is that acceptable?
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
