# Default repo rules

Stack-wide conventions that hold across the Evo repos. A repo's own `docs/agents/*` always wins where
the two disagree. Use this file to cover a repo that has none, and offer to bootstrap `docs/agents/`
for it afterwards.

## Where the toolchain is

Read `working-in-the-devcontainer.md` before running any command in a repo — it carries the
`docker exec` form, how to find and start the container, what a shared container means for
concurrent runs, and the two traps in `run_tests.sh`. The commands below all run inside it.

## Python ROS2 (GR-gateway, GR-alert-sender)

- Node source under `src/<pkg>/<pkg>/`. Pure logic goes in its own module so it is unit-testable;
  wiring stays in the node.
- `colcon build` so Python edits take effect without a full rebuild.
- Lint: `ruff check --fix`, `ruff format`, `pyrefly check`, all with
  `--config=code-analysis/config/python/...`.
- `install/_local_setup_util_*.py` are colcon-generated. Never hand-edit; lint findings there are noise.

## C++ ROS2 (GR-hal, GR-slam, GR-aom, GR-general)

- Style is **Google, with `IndentWidth: 4`** (`GR-configs/code-analysis/config/cpp/.clang-format`,
  `BasedOnStyle: Google`, `ColumnLimit: 80`).
- Naming enforced by clang-tidy `readability-identifier-naming`: `CamelCase` classes/structs/enums,
  `UPPER_CASE` enum constants, `lower_case` functions and methods.
- Two clang-tidy configs: `.clang-tidy` (full, `google-*` plus `misc-const-correctness`) and
  `.clang-tidy-light` (fast — `readability-*`, `modernize-*`). Pre-commit uses one of them; check the
  repo's `.pre-commit-config.yaml`.
- clang-tidy needs a compilation database: `-p=build`, so `colcon build` before linting.
- Public headers live in `include/<pkg>/...` and are installed — changing one is an interface change.

## JS / React (GR-ice-signaler)

- In the devcontainer: `cd src/signaler && ./build.sh`,
  `cd src/simple-teleop && ./build.sh && npm run dev -- --host`.
- Pure logic goes in `.mjs` feature modules under `src/features/<area>/`; tests are
  `node --test test/*.test.mjs`. JSX wiring is verified live.
- biome for lint. Note that some large files are deliberately excluded in
  `.pre-commit-config.yaml` — do not remove an exclusion to "fix" it.

## Cross-cutting

- **RMW**: `rmw_cyclonedds_cpp`, configured by a repo-local `cyclonedds.xml` via `CYCLONEDDS_URI` set
  in `setup.sh`. Check this and `ROS_DOMAIN_ID` before assuming an application bug in cross-node
  comms.
- **Custom messages** live in `GR-ros2-messages` (`robot_msgs`) and are installed image-wide at
  `/opt/ros_custom_msgs`. Changing one means rebuilding every dependent image.
- **`robot_id`** addresses robots; WebRTC ports derive from it (`8000 + robot_id` WHEP TCP,
  `9000 + robot_id` video UDP) and need per-robot router forwarding. Never inline a robot-specific
  literal.
- **Lint config is not in the repo** — `code-analysis/config/` is populated from `GR-configs` at
  container build time by `post-create.sh`, and `.devcontainer/docker-compose.yml` mounts
  `../../GR-configs/code-analysis/config/`. `GR-configs` must be checked out as a sibling.
