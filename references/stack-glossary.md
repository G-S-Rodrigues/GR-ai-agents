# Stack glossary

Terms that **travel between repos**. A term belongs here when two or more repos must mean the same
thing by it; a term used in exactly one repo belongs in that repo's own `CONTEXT.md`, not here.

This file is a **glossary and nothing else**. No commands, no file paths, no how-it-works — those
live in each repo's `docs/agents/`. Decisions live in that repo's `docs/adr/`.

Installed to `~/.claude/GR-references/stack-glossary.md`, so it reads the same from the host and
from inside a devcontainer.

## Language

**Robot ID**:
The fleet's identifier for a single robot. Resolved through config — a ROS2 parameter with a
`ROBOT_ID` env override — never a literal in source.
_Avoid_: robot number, unit id, serial

**Fleet**:
Every robot addressed by the system, as a set. Used when a statement is true across all robots rather
than the one in front of you.
_Avoid_: swarm, cluster

**Teleop path**:
The full chain from browser to ROS2 graph: teleop client → signaler → gateway → ROS2 graph. Used when
a statement concerns more than one hop.
_Avoid_: teleop pipeline, comms path, the stack

**Map relay**:
The path carrying the SLAM map point cloud from the ROS2 graph, through encoding in the gateway, out
over the WebRTC data channel, to the teleop client's 3D view. Names the whole path, not any one hop.
_Avoid_: map streaming, map pcl, pointcloud pipeline, map point cloud streaming

**Map request**:
A request originating at the teleop client asking for the map to be (re)sent. Distinct from the
**Map relay**, which is the path a map travels once requested.
_Avoid_: map trigger, request_map, fetch map

**Reference** _(settled 2026-08-18)_:
A located coordinate reference that poses and waypoints are expressed in — an origin plus an
identity, not merely a set of axis directions. The genus; the species in the fleet are the **ENU
reference** and the **SLAM map reference**. A pose or waypoint is always expressed *against* one
reference, and coordinates from two references are never comparable. Distinct from **Active
reference**, which names a selection rather than a coordinate system.
_Avoid_: frame (bare), coordinate system, datum (that is one reference's origin, not the reference),
localization mode, map

**ENU reference** _(settled 2026-08-18)_:
The **Reference** anchored at a surveyed geodetic origin, with east-north-up axes, that
`gnss_pose_transform_node` expresses GNSS positions in. The origin is captured deliberately and
persisted, so the reference survives restarts and remains comparable across sessions. Not to be
confused with `gnss_enu`, which is a labels-only axis convention for a velocity vector and claims no
origin — the two are different kinds of thing that share three letters.
_Avoid_: enu (bare), gnss_enu, ENU frame, GPS frame, world

**SLAM map reference** _(settled 2026-08-18)_:
The **Reference** defined by a specific built SLAM map. Its identity is the map that produced it:
rebuilding the map yields a *different* SLAM map reference even when the file path and the frame name
are unchanged, which is what makes previously recorded waypoints incomparable. Naming it as a
reference rather than as "the map" is what allows that invalidation to be stated at all.
_Avoid_: map frame, the map, slam frame

**Reference ID** _(settled 2026-08-18)_:
The identity of one **Reference** instance, durable enough to compare across sessions and machines.
Two sets of coordinates may be interpreted together only when their reference IDs match. It is what a
stored route carries so that loading it can be refused when it disagrees with the **Active
reference**.
_Avoid_: map name, datum name, frame id, reference name

**Active reference** _(settled 2026-08-18)_:
The one **Reference** that navigation currently uses — the selection that decides which pose the
planner consumes and which reference new waypoints are recorded against. Exactly one is active at a
time. It is explicitly set and persisted, never inferred from which route is loaded. It says nothing
about which localization sources are running: several may run at once, and the inactive ones keep
producing poses that nothing navigates on.
_Avoid_: localization mode, navigation mode, mode (bare), pose source, active localization

## Flagged ambiguities

- **"map" alone is overloaded** — it has meant the relay, the request, and the point-cloud payload
  itself in different plan files (`map-pointcloud-streaming`, `map-pcl-consolidation`,
  `map-request-trigger`). Use **Map relay**, **Map request**, or *map point cloud* for the payload;
  never bare "map" for a mechanism. Since 2026-08-18 it also names a **Reference** (the **SLAM map
  reference**) and, separately, the `map` TF frame — which are not the same thing, because rebuilding
  the map changes the reference while leaving the frame name identical.

- **"mode" is doing four jobs** — `SystemOperationMode` (autonomous vs. teleop), `LocomotionMode`
  (gait), `/evo/slam/mode` (`MAPPING`/`LOCALIZATION`/`MAP_LOST`/…), and, until 2026-08-18, the
  informal name for which localization source navigation uses. The fourth is now **Active
  reference** and "mode" must not be used for it. Always qualify the other three; never write bare
  "mode" for a mechanism.

- **"reference" alone is ambiguous in GR-gnss** — the repo uses it for the ENU *origin point* (a
  `GeodeticPoint` captured by `record_enu_reference`) and the stack glossary now uses it for the
  *coordinate reference* that origin defines. The origin is one field of the reference, not the
  reference. Say **ENU reference** for the coordinate system and *reference origin* (or *datum*) for
  the point.

## Adding a term here

The test is **does it travel** — not whether it sounds important. `Relay port range` is central to
GR-ice-signaler and meaningless in GR-hal, so it stays local. `Robot ID` appears in deployment,
addressing, config, and tests across the whole stack, so it lives here.

Moving a term up from a repo glossary is a promotion: delete it there in the same edit, or the copy
you left behind becomes the one people read.

- **UNCONFIRMED** — applies to the terms seeded from repo documentation rather than from a session:
  **Robot ID**, **Fleet**, **Teleop path**, **Map relay**, **Map request**. Each is still a proposal;
  `GR-domain-modeling` confirms or replaces them. Terms marked _(settled &lt;date&gt;)_ were resolved in
  a session and are not proposals.
