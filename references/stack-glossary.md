# Stack glossary

Terms that **travel between repos**. A term belongs here when two or more repos must mean the same
thing by it; a term used in exactly one repo belongs in that repo's own `CONTEXT.md`, not here.

This file is a **glossary and nothing else**. No commands, no file paths, no how-it-works — those
live in each repo's `docs/agents/`. Decisions live in that repo's `docs/adr/`.

Installed to `~/.claude/GR-references/stack-glossary.md`, so it reads the same from the host and
from inside a container.

## Language

*Empty.* Every term in play today is local to one repo and lives in that repo's `CONTEXT.md`. The
first term that two repos must agree on gets the first entry here, in the format below.

```markdown
**Term**:
What it means, in one or two sentences. Where it is resolved from, if that is the confusing part.
_Avoid_: the spellings people reach for instead
```

## Flagged ambiguities

*Empty.* A word doing two jobs across repos is recorded here once `GR-domain-modeling` has resolved
it — what each job is, and which name each job takes from now on.

## Adding a term here

The test is **does it travel** — not whether it sounds important. A term central to one repo and
meaningless in another stays local. A term that appears in deployment, addressing, config, and tests
across several repos belongs here.

Moving a term up from a repo glossary is a promotion: delete it there in the same edit, or the copy
you left behind becomes the one people read.
