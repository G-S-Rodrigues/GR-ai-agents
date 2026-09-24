# Default repo rules

Fallback conventions for a repo with no `docs/agents/` of its own. **A repo's own `docs/agents/*`
and `CLAUDE.md` always win**; use this only to cover the gap, and offer to bootstrap that repo's own
afterwards.

## Holds everywhere

- **Claude runs on the host; the toolchain does not.** Read `working-in-the-devcontainer.md` before
  running any command — it carries the `docker exec` form, how to find and start the container, and
  what a shared container means for concurrent runs. A bare `colcon build` is broken.
- **The done gate is the repo's own.** Its `CLAUDE.md` names it, often as "the rule". Run that
  command, not the subset of tests you touched.
- **C++ is Google style with `IndentWidth: 4` and `ColumnLimit: 80`**, naming enforced by clang-tidy
  `readability-identifier-naming`. clang-tidy needs a compilation database, so build before linting
  (`-p=build`).
- **Python is `ruff`**, 80 columns.
- **RMW is `rmw_cyclonedds_cpp`.** Check `CYCLONEDDS_URI` and `ROS_DOMAIN_ID` before assuming an
  application bug in cross-node comms — and note that a QoS mismatch presents as absent data rather
  than as an error.

## Where the toolchain is

Read `working-in-the-devcontainer.md` before running any command — it carries the `docker exec`
form, how to find and start the container, and what a shared container means for concurrent runs.

## Lint

- A repo's `.pre-commit-config.yaml` lists what is live; its `docs/agents/lint-and-precommit.md`,
  where one exists, says which hooks are real and which are inert boilerplate.
- Some paths are deliberately excluded from a linter and linted another way. Do not remove an
  exclusion to "fix" a gap — find what lints it instead.
- Generated files (`install/`, build output) are not hand-edited, and lint findings in them are noise.

## What always wins

The repo's own `CLAUDE.md`, `docs/agents/*` and ADRs. This file exists only to stop a session
inventing conventions where a repo has recorded none — offer to bootstrap that repo's `docs/agents/`
rather than growing this file.
