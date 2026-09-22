---
name: GR-commit
disable-model-invocation: false
description: Create a scoped, single-sentence commit in an Evo repo — stage only the files belonging to the implementation being committed, and write a commit message that completes "This commit ...", approved by the user before committing.
---

# Evo Commit Skill

Use this skill when the user asks to commit changes in an Evo repo.

## Procedure

1. Check the current branch with `git branch --show-current`. Work always happens on a branch created for a specific GitHub Projects task, never directly on `main`. If the current branch is `main`, stop and alert the user instead of committing — don't create a branch on their behalf or commit anyway, since you don't know which task this work belongs to.
2. Run `git status` / `git diff` and identify which changed or untracked files actually belong to the implementation being committed. If the working tree has unrelated changes sitting around (other in-progress work, stray edits, unrelated generated files), leave them out — don't sweep them in just because they're modified.
3. Stage only those files by name (`git add <file> ...`). Avoid `git add -A` / `git add .` since that stages everything indiscriminately.
4. If the repo has a `.pre-commit-config.yaml`, read `docs/agents/lint-and-precommit.md` first — it is the authority on which hooks are actually live in this repo and which are inert boilerplate. Then run pre-commit against just the staged files before writing the commit message; verification should track the same scope as the commit, not the whole repo. These repos' tooling lives in a devcontainer, not on the host (see the repo's own CLAUDE.md for the container name), so run it there:
   ```
   docker exec <container_name> bash -lc 'cd "$HOME/workspace" && source setup.sh && pre-commit run --files <staged files>'
   ```

   If `docker exec` fails because the container isn't running (check `docker ps -a`), start it first — safe to do without asking, and safe even if you're already attached to it in VS Code:
   ```
   ${HOME}/gitroot/GR-ai-agents/scripts/devcontainer_up.sh <repo>
   ```
   Then retry the `docker exec`. Use the wrapper rather than a bare `up -d`: it skips the build when the image already exists, and keeps a cold build's log on disk instead of streaming thousands of lines of apt/pip output into the transcript.
   - Some hooks auto-fix in place (whitespace/EOF, `ruff check --fix`, `ruff format`, `clang-format`, `biome --write`). If one modifies a file, re-stage it.
   - Others only report a problem without fixing it (`pyrefly`, `shellcheck`, `clang-tidy --warnings-as-errors`, `check-yaml`, `check-added-large-files`). For each failing hook, dispatch the `lint-fixer` subagent with the container, working directory, hook id, its failure output, and the `docs/agents/lint-and-precommit.md` path — it applies a bounded, mechanical fix and re-verifies with that hook itself. Re-stage any file it changed. It escalates back to you rather than guessing when the fix isn't mechanical (a suppression, a behavior change, a genuinely large/ambiguous edit) — handle those yourself or stop and ask, same as any other judgment call.
   - Don't commit while pre-commit is still failing.
5. Write the commit message as one sentence that completes "This commit ...". Don't type the words "This commit" into the message — start directly with the completing verb phrase (present tense, third person singular, e.g. "adds", "fixes", "removes"), so it reads naturally when mentally prefixed with "This commit ", and keep it specific rather than generic. The message is that one sentence and nothing else: never add a `Co-Authored-By:` trailer, a "Generated with Claude Code" line, or any other attribution.
6. Show the user the proposed message together with the list of staged files, and ask them to approve it before committing. Wait for their explicit answer — silence, or a reply about something else, is not approval. If they ask for changes, revise and show it again; repeat until they approve. Approval covers this one message only, so ask again for every subsequent commit, including the amended-and-recommitted case.
7. Commit, using exactly the message the user approved. If the repo has a `.pre-commit-config.yaml`, it's installed as an actual git hook, so a bare host-side `git commit` re-triggers pre-commit on the host and fails even after step 4 passed in the container — run the commit inside the container instead:
   ```
   docker exec <container_name> bash -lc 'cd "$HOME/workspace" && git commit -m "<message>"'
   ```
   Repos with no `.pre-commit-config.yaml` have no such hook; commit on the host as normal.
8. If step 4 required any fix, say so explicitly afterward and summarize exactly what was fixed and in which file(s) — don't let it pass silently.

## Examples

- Good: `adds retry logic to the telemetry adapter's reconnect loop`
- Good: `fixes the null pointer in map response handling when no waypoints are queued`
- Good: `removes the unused legacy pointcloud downsampling path`
- Bad: `This commit adds retry logic` (literal prefix, don't type it)
- Bad: `update files` (too generic)
- Bad: `49 fe support for perception visualization` (old ticket/area format, no longer used)
