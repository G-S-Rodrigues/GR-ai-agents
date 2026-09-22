# Spec template

Derived from `.scratch/56-fe-map-visualization/spec/2026-07-31-map-ui-interaction.md`, which is the
reference example. Sections are mandatory unless marked optional. Keep prose tight — every paragraph
should carry a fact, a constraint, or a decision.

```markdown
# Spec: <short title>

**Date:** YYYY-MM-DD

## Context

What exists today, with `file:line` anchors. What is wrong with it, as observable symptoms rather
than opinions ("points render sub-pixel at fit distance", not "the map looks bad"). Name the commit
range or branch the current state came from, and note that line numbers will drift.

## Goals

One paragraph. What someone can do after this that they cannot do now.

## Non-goals

Deliberately excluded, **each with its reason**, so they are not re-litigated mid-implementation.
This section is what makes the spec hold up. Include things that are genuinely worth doing but are
out of scope, and say why — bigger piece, unverified dependency, would churn existing tests, needs
measurement first.

## Scope

Numbered items. Each item:

### N. <name>

**Now:** current behaviour, with `file:line`.
**Change:** what it becomes. Concrete enough to implement, not so concrete it dictates style.

Rationale only where the choice is non-obvious — especially where a simpler-looking option was
rejected. Name the pure function(s) the change introduces, with signature:

```js
formatMapStatus({ pointCount, receivedAt }) -> string | null
```

Files: `path/one.mjs`, `path/two.jsx`, `test/one.test.mjs`.

## Layout (optional, UI changes)

An ASCII sketch of the resulting arrangement, plus the rule that decides where future additions go.

## Testing

Per that repo's `docs/agents/testing.md`. Split by tier — see
`~/.claude/skills/GR-tdd/references/test-tiers.md`:

- **Unit** — the pure functions, named, with the exact runner command.
- **Integration (`.robot`)** — what wiring is covered.
- **Live/manual** — a numbered list of steps a human performs, and why these cannot be automated.
- **Lint** — the command, plus any file-specific exclusions that must not be removed.

## Risks

Concrete failure modes, not generic caution. Shared state that might be affected, files already too
large, existing tests that will fail until updated (state them as expected, not regressions).

## Acceptance criteria

Numbered, each independently checkable, phrased as an observable outcome. The last one is the test
and lint commands passing.
```

## Rules

- Non-goals carry reasons. A bare list is not useful.
- Every scope item ends with a `Files:` line.
- Prefer `file:line` over prose descriptions of location.
- Say what the spec does **not** verify.
- No implementation steps — those belong in the plan (`GR-tdd`).
