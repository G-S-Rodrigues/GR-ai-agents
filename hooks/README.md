# Hooks

Empty for now — this directory is the agreed home for hook scripts so the first one doesn't have to
invent a location.

## Why the installer doesn't install them

Skills and subagents are files in a directory: symlink one in and it works. A hook is different — it
only fires if it's registered in `settings.json`, which is a **shared, user-owned file** that also
holds permissions, env vars, and model config. Merging into it automatically means an install script
editing a file the user is also editing, with no safe merge strategy and real blast radius if it
gets it wrong.

So: this repo ships the script and the exact snippet; you paste the snippet.

## Adding a hook

1. Put the script here, executable: `hooks/<name>.sh`.
2. Document it below with the settings snippet that arms it — matcher, event, and what it blocks or
   emits.
3. Say whether it belongs in user settings (`~/.claude/settings.json`, all projects) or project
   settings (`<repo>/.claude/settings.json`, one repo). Prefer project scope for anything
   stack-specific.

Snippet shape:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "~/gitroot/GR-ai-agents/hooks/<name>.sh" }]
      }
    ]
  }
}
```

Point the command at the repo path, not at a copy — same reason skills are symlinked, so a
`git pull` updates the behaviour.

## Candidates worth building

Not yet written; listed so the first person to want one doesn't start from scratch.

- **Block host-run toolchain commands.** A `PreToolUse` guard on `Bash` that refuses a bare
  `colcon build`, `pre-commit run`, or `ros2 ...` when the command isn't wrapped in `docker exec`.
  This is the single most repeated correction in the stack, and a hook enforces it where a skill
  instruction only asks.
- **Block commits on `main`.** `GR-commit` already checks the branch and stops; a hook makes it
  unbypassable regardless of which skill (or none) is driving.
- **Guard destructive git.** `git reset --hard`, `git clean -fd`, `git checkout .` — a repo-wide
  discard silently wipes `docs/` and `.scratch/` precisely *because* they're gitignored, with no
  warning and nothing in the reflog to recover from.
