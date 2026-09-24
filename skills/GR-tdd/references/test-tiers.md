# Test tiers

Decide per behaviour which tier covers it. State what stays unverified and why — a plan that silently
leaves wiring untested is the failure this file prevents.

| Tier | Covers | Runner |
|---|---|---|
| 1 — unit | Pure logic, no ROS graph, no I/O | the repo's unit runner (`pytest`, `gtest`, `node --test`) |
| 2 — integration | **Wiring** — a live ROS graph inside one repo | the repo's integration tier |
| 3+ — system | Behaviour only a full run exhibits | the repo's system / acceptance tier |
| — manual | Anything the tiers cannot reach | a numbered human procedure, **with the reason** |

The repo's own `docs/agents/testing.md` names what each tier actually is and the command that runs
it. The table above is the shape, not the commands.

## Tier 1 — pure logic

Only genuinely side-effect-free code. The established pattern is to extract logic out of wiring
first, then test the extracted module — which is why the packages here are thin shells over a
ROS-free core. Do not mock the ROS graph to force a unit test; that is what tier 2 is for.

## Tier 2 — wiring

The first tier that reaches a live ROS graph: nodes actually running, actually talking. Shared test
keywords live wherever the repo's `docs/agents/testing.md` says — reuse them rather than growing a
second set.

Techniques that are not obvious and have already cost time:

- **Match QoS or the test silently sees nothing.** Register the publisher with `reliability=reliable`
  when the node subscribes with `qos_reliable`. A best-effort publisher never matches, and the failure
  looks like absent data, not an error.
- **Mock service servers** for services the node calls, following the existing mock pattern in the
  repo's `.robot` suite.
- **Repo-local helper libraries** go where the repo's `docs/agents/testing.md` puts them, and reach
  an existing library instance via `BuiltIn().get_library_instance(...)` rather than constructing a
  second one.
- **Keep large payloads out of Robot variables.** Some keywords log every buffered message on each
  poll; generate *and* assert inside a Python helper so a multi-MB payload never crosses a keyword
  boundary. Assert on length or a decoded count, never on the raw string.
- **No event-count keyword?** Give each stimulus a distinct value (e.g. a different point count) and
  assert on what "last event" still holds. That is how "no second event was emitted" is proven.
- **A parameter the suite cannot override** is worked around, not redefined. Where nodes read
  parameters from a config file the harness does not set, write the test against the default — sleep
  past a 1.0 s interval rather than shortening it. Never change a production default to suit a test.

## Tier 3+ — system

A full run: the whole graph up, driving a real scenario. A green unit and wiring tier says nothing
about what the system does over a lap.

Shared test keywords affect **every** suite that imports them, and where they are installed into an
image they take effect only after a rebuild — they are consumed from the image, not from the working
tree.

## Two traps that make green runs meaningless

A runner whose exit code does not change when a test fails, and a runner that tests the installed
package rather than your edits. Read
`~/.claude/GR-references/working-in-the-devcontainer.md` before planning a suite that has to actually
prove something — it has both and how to rule them out.

## Recording the decision

```markdown
## Test tiers

| Behaviour | Tier | Where |
|---|---|---|
| Frenet conversion round-trip | 1 | `test/test_frenet.py` |
| pose topic → controller command | 2 | `test/<pkg>.robot` PKG-1200 |
| a full lap completes within budget | 3 | `tests/system/test_<behaviour>.py` |
| the RViz overlay reads correctly | manual | no harness renders it; a numbered procedure instead |

Not tested: <behaviour> — <the reason, e.g. no such path exists yet; item deferred in the spec>.
```

Use the repo's existing test-ID numbering; do not invent a new scheme.
