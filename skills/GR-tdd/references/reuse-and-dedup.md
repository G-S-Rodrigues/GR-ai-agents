# Reuse before adding

A near-duplicate function is a worse outcome than a measured change to an existing one. Duplication is
the default failure mode of an agent told not to touch working code: it looks safe, ships fast, and
then two copies drift apart until a bug is fixed in one of them.

So: **prefer adjusting production code over duplicating it — but measure first, and record the
decision.**

## Before writing any new function

Search for something that already does it, or nearly:

```sh
grep -rn "<likely name>" src/ test/          # by name
grep -rn "<distinctive expression or constant>" src/   # by behaviour
```

Look where shared logic already lives in this repo: the ROS-free core each package is a shell over,
the common package the others depend on, the shared test keywords. The repo's layout section in
`CLAUDE.md` names them.

Then take the **highest** option that works:

| # | Option | When |
|---|---|---|
| 1 | **Reuse as-is** | It already does what you need. Always preferred. |
| 2 | **Extend in place, back-compatible** | Add a parameter with a default, widen a type, generalise the body — every existing call site behaves identically with no edits. Usually cheap; preferred over duplication. |
| 3 | **Extract and migrate** | Pull the shared core into a helper, point both callers at it, update all call sites. Requires enumerating them. |
| 4 | **Duplicate deliberately** | Last resort. The plan must name which hard stop below applies. |

## The cost probe

Run this before choosing option 2 or 3. Every item is countable, and the counts go in the plan.

- **Call sites** — `grep -rn` the symbol. State the number and list them. If you cannot enumerate them,
  option 3 is off the table.
- **Repo boundary** — do any call sites live in another repo? Cross-repo means a ROS2 topic/service/
  message contract, a separate build, a separate deploy, and separate CI.
- **Test cover** — do tests exercise the function today? If none, a refactor is blind: either add a
  characterisation test first (RED against existing behaviour) or drop to option 4.
- **Public interface** — is it a field in a message or service, a ROS parameter name, a topic name,
  or an installed C++ header under `include/`? Changing those is an interface change, not a
  refactor.
- **Behaviour preserved?** If any existing call site's behaviour changes, this is no longer a dedup —
  split it into its own step with its own test.

## Hard stops → duplicate, and say why

- The reuse would cross a repo boundary.
- It would change a message, service or action definition, or a topic or service name.
- It would replace an existing algorithm rather than add beside it, where the repo's ADRs say
  implementations are added and never replaced.
- The existing function has no test and characterising it is larger than the task itself.
- Call sites cannot be enumerated.

## Green light → extend or extract

All of:

- single repo, and
- call sites enumerated in the plan, and
- existing tests cover them, or a characterisation test is added first, and
- every existing call site's behaviour is unchanged.

## Record it in the plan

A short **Reuse decisions** section, one line per new function — what already exists, the option
taken, and the count that justified it:

```markdown
## Reuse decisions

- `formatMapStatus` — nothing comparable; new pure function in `features/map_pcl/mapPointCloud.mjs`.
- point-count abbreviation — `mapViewUtils.mjs:abbreviateCount` already does it (3 call sites, all in
  `features/map_pcl/`, covered by `mapViewUtils.test.mjs`) → **reuse as-is**.
- `track_bounds()` — needs a curvature-only variant → **extend in place** with an optional argument
  defaulting to current behaviour (2 call sites, both covered) → existing tests must stay green
  unedited.
- Centreline arc-length — another repo has it, but that is a cross-repo hard stop → **duplicate** it
  in the test helper, and say why.
```

## The line against the TDD rule

Two rules coexist and must not be confused:

- **Do not change production code to make a test pass, or to make a test possible.** Absolute. That is
  bending the design to satisfy the harness.
- **Do change production code to avoid duplicating it.** Required, under the gate above. That is the
  design improving.

The tell: a refactor under this gate leaves the existing tests green **without editing them**. If
existing tests need edits, it is a behaviour change, not a dedup — plan it as one.
