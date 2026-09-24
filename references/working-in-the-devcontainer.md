# Working in the devcontainer

A repo's container holds its toolchain — ROS, pinned lint and test versions, and whatever else the
build needs. Claude runs on the **host**, which has none of it. The repo's own `CLAUDE.md` names its
container and how it is started.

So the split is:

- **Edit files on the host.** The repo is mounted into the container; a host edit is already visible
  inside it.
- **Run every command that touches the code inside the container** — build, test, lint, `ros2`,
  anything that needs the toolchain. A bare `colcon build`, `pre-commit run`, or `ros2 launch` on the
  host either fails or silently uses stray host tooling, which is worse.

```sh
docker exec -it <container> bash -lc 'cd "$HOME/workspace" && source setup.sh && <command>'
```

**The `cd` is load-bearing.** `bash -lc` starts in `$HOME`, which is usually not the mounted tree,
so a bare `source setup.sh` fails with "No such file or directory". Take the working directory from
the repo's `CLAUDE.md`; some repos mount at `$HOME/workspace`, others elsewhere, and some need no
`source` line at all.

The container name is `container_name:` in the repo's `.devcontainer/docker-compose.yml` — the source
of truth, over any table listing them. Start a stopped one with the wrapper, safe to do unattended:

```sh
${HOME}/gitroot/GR-ai-agents/scripts/devcontainer_up.sh <repo>
```

**Check for the image before paying for a build.** A cold `up -d --build` compiles the whole image —
minutes of wall clock and *thousands* of lines of apt and pip output, all of it read for nothing when
the build succeeds. A container that is merely stopped needs none of that:

```sh
docker image inspect <repo>:devcontainer >/dev/null 2>&1 && \
  docker compose -p <repo>-devcontainer -f .devcontainer/docker-compose.yml up -d --no-build
```

`--no-build` starts the existing image in seconds and prints about ten lines. Reach for a build only
when the image genuinely does not exist, or when a `Dockerfile`/`requirements.txt` change means you
need a new one — and then pass `--rebuild` to the wrapper, which keeps the build log on disk instead
of in your context. The wrapper does this check itself, so it is the shorter path to the same
decision:

| Situation | What the wrapper does | Console cost |
|---|---|---|
| Container already running | nothing — no compose call at all | 1 line |
| Image exists, container stopped or gone | `up -d --no-build` | ~2 lines |
| No image, or `--rebuild` | `up -d --build`, full log to disk | ~3 lines, or error markers + tail on failure |

Do **not** reach for `--quiet-build` or `--progress quiet` instead. They suppress the failing step's
own stdout too, so a broken build reports only `failed to solve` and a Dockerfile line number — the
pip conflict or compiler error that actually explains it is gone. Keeping the full log on disk is
what makes quiet output safe.

## The container is shared

Another agent, or the user in VS Code, may be working in the same container at the same time.
`docker exec` just opens an additional shell, so joining is safe — but the work inside is not
isolated:

- Two `colcon build` runs write the same `build/` and `install/` trees.
- A suite that writes a fixed output directory has its report overwritten by a second run.
- Two test runs on one `ROS_DOMAIN_ID` discover each other's nodes, and a suite can see topics from a
  run it knows nothing about.

**A failure you cannot explain may be another run, not a bug.** Check before diagnosing:

```sh
docker exec <container> ps -ef | grep -E 'colcon|robot|ros2'
```

Leave running containers running. `up -d` is additive; `stop`, `down`, and `restart` end sessions
that are not yours — ask first.

## The interference is not scoped to one repo's container

Every repo's devcontainer sets the same `ROS_DOMAIN_ID` (10, as of this writing) and runs with host
networking, so two containers with **live ROS graphs at the same time — even from different repos —
can see each other's nodes and topics.** This is a superset of the same-container warning above: it is
not enough to check that nothing else is running *in the container you're about to test in*. Before
trusting a test run's failures as real, check for live `ros2`/`robot` processes in every other running
devcontainer too:

```sh
for c in $(docker ps --format '{{.Names}}'); do echo "== $c =="; docker exec "$c" ps -ef | grep -E 'ros2|robot' | grep -v grep | grep -v defunct; done
```

Seen in practice: the same suite, run twice with identical test counts, produced different failing
cases and different symptoms depending on what else was live in another container at the time. A
rerun with every other container's ROS processes confirmed quiet resolved it to the expected
result.

## Running a repo's tests

The command is the repo's own — its `docs/agents/testing.md` and its `CLAUDE.md` name the single
test, the per-step suite, and the done gate. Never carry one repo's invocation to another.

Pipe long output through `tail` or `grep` rather than reading it inline, and dispatch
`test-failure-triage` on a failure whose cause is not immediately obvious.

**Two traps to rule out before trusting a green run**, because both report success on nothing:

- **A runner that swallows failures.** Confirm its exit code actually changes when a test fails.
  A wrapper that ends in `|| true`, or that only writes a report file, has an exit code that means
  nothing.
- **A runner that tests the installed package, not your edits.** Where a build installs into a
  separate prefix, build with `--symlink-install` first, or the run reports on stale code.

Where a repo has no suite, say so rather than substituting another command — the absence is itself
the finding.

## Running suites in parallel

One repo per container, so parallel runs never collide on `build/`, `install/`, or a fixed report
directory — those are per-container. What they collide on is the ROS graph.

Give each run its own domain and they stop seeing each other:

```sh
docker exec <container> bash -lc 'cd <workdir> && export ROS_DOMAIN_ID=<n> && source setup.sh && <the repo's suite command>'
```

`ROS_DOMAIN_ID=10` is baked into every devcontainer **image**, so it is not in
`docker-compose.yml` or `setup.sh` and grepping the repo for it finds nothing. `setup.sh` never
sets it and `cyclonedds.xml` binds `Domain Id="any"`, so an `export` in the inner command survives
the source and the RMW follows it.

Assign `20 + <index in the repo table>` — deterministic across reruns, and clear of `10`, where a
VS Code session's live graph sits.

A run on its own domain cannot see the processes the section above warns about, so isolating the
domain is the fix for that flakiness rather than a workaround for it.

Each run is a full `colcon build`, so N repos in parallel is N compiles on one host. Fan out across
repos; keep one run per container.

This is one repo's own suite. A higher tier with its own setup is a separate run, and a green run
here says nothing about it.
