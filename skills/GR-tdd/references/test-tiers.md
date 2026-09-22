# Test tiers

Decide per behaviour which tier covers it. State what stays unverified and why — a plan that silently
leaves wiring untested is the failure this file prevents.

| Tier | Covers | Runner |
|---|---|---|
| 1 — unit | Pure logic, no ROS2/socket/DOM | `pytest` (in-repo `test/`), `node --test test/*.test.mjs` |
| 2 — integration | ROS2 and socketio **wiring** inside one repo | in-repo `test/*.robot` via `./test/setup/run_tests.sh` |
| 3 — system | Behaviour spanning repos | `GR-tests` via `system_testing/setup/spin_components.sh` |
| — manual | Anything the tiers cannot reach | a numbered human procedure, **with the reason** |

## Tier 1 — pure logic

Only genuinely side-effect-free code. The established pattern is to extract logic out of wiring first,
then test the extracted module: `features/map_pcl/mapPointCloud.mjs`, `pcdDownload.mjs`,
`pointcloud_codec.py`, `rate_limit.py`. Do not mock ROS2 or socket.io to force a unit test — that is
what tier 2 is for.

## Tier 2 — in-repo `.robot`

The only tier that reaches ROS2 and socketio wiring. Every ROS2 repo has `test/*.robot` plus
`test/setup/run_tests.sh`; shared Robot libraries are installed in the image at
`/opt/robot_tests/common_libraries/` (source: `GR-tests/system_testing/common_libraries/`).

Techniques that are not obvious and have already cost time:

- **Match QoS or the test silently sees nothing.** Register the publisher with `reliability=reliable`
  when the node subscribes with `qos_reliable`. A best-effort publisher never matches, and the failure
  looks like absent data, not an error.
- **Mock service servers** for services the node calls, following the existing mock pattern in the
  repo's `.robot` suite.
- **Repo-local helper libraries** go in `test/helper_libraries/` and reach an existing library
  instance via `BuiltIn().get_library_instance("SocketIOLibrary")` — the same lookup
  `RosLib._resolve_callback` uses. Prefer this over editing `GR-tests`.
- **Keep large payloads out of Robot variables.** Some keywords log every buffered message on each
  poll; generate *and* assert inside a Python helper so a multi-MB payload never crosses a keyword
  boundary. Assert on length or a decoded count, never on the raw string.
- **No event-count keyword?** Give each stimulus a distinct value (e.g. a different point count) and
  assert on what "last event" still holds. That is how "no second event was emitted" is proven.
- **Parameters read from config cannot be overridden from the suite.** `Run Components` passes only
  env vars while nodes read parameters from their config yaml — so write the test against the default
  (sleep past a 1.0s interval rather than shortening it). Never change production defaults to suit a
  test.

## Tier 3 — cross-repo

`GR-tests` starts the whole stack. Run `spin_components.sh start` outside any devcontainer first,
then the suite inside the GR-tests container. A per-repo green run says nothing about fleet
integration.

Editing `GR-tests/system_testing/common_libraries/*.py` affects **every** repo's tier-2 suite, and
takes effect only after the devcontainer image is rebuilt — those files are consumed from
`/opt/robot_tests/`, not from the working tree.

## Two traps that make green runs meaningless

Every ROS2 repo's `test/setup/run_tests.sh` swallows failures and tests the installed package rather
than your edits. Read `~/.claude/GR-references/working-in-the-devcontainer.md` before planning a
suite that has to actually prove something — it has both traps and the command that defeats them.

## Recording the decision

```markdown
## Test tiers

| Behaviour | Tier | Where |
|---|---|---|
| PCD encode/decode round-trip | 1 | `test/pointcloud_codec_test.py` |
| map topic → socketio emit | 2 | `test/gateway.robot` GATEWAY-1200 |
| robot → all controllers relay | 2 | `test/ice_signaler.robot` Ice_signaler-1040 |
| operator sees map after reconnect | manual | needs a real WebRTC session; no harness reaches it |

Not tested: gateway-side downsampling — no downsampling path exists yet (item deferred in the spec).
```

Use the repo's existing test-ID numbering; do not invent a new scheme.
