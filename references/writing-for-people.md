# Writing for people

How to write prose a teammate reads. For how to author a skill in this suite, see
[`writing-skills.md`](writing-skills.md) instead.

**Scope.** These directives apply to the one document being written or rewritten right now, when the
reader is a person: a README, a PR body, an ADR, an issue comment, a reply in chat. Grill digests,
specs, plans, and review reports are read by the next agent and keep their default density: tables,
`file:line` anchors, clipped fragments. Do not carry these directives into them.

## Cut before rewording

Polishing a paragraph that should be deleted is wasted work, so cutting comes first.

- **Delete what the reader already knows.** A sentence explaining that tests should pass, or that a
  config file holds config, is filler wearing the costume of context.
- **Delete restatement.** A closing paragraph that summarises the section above it earns nothing. A
  bullet that repeats the sentence introducing the list earns nothing.
- **One claim per sentence.** Where a sentence carries a claim plus its caveat plus an aside, split
  it. Short sentences are what makes text skimmable, not short paragraphs.
- **Every paragraph carries a fact, a constraint, or a decision.** A paragraph that carries only
  transition is a paragraph to remove, not to shorten.
- **Cut hedging that changes nothing.** "It's worth noting that", "generally speaking", "in many
  cases" where no case is being excluded.

## Sentence-level targets

- **Plainest available word.** `use`, not `utilise`. `so`, not `thereby`. `about`, not `regarding`.
- **Concrete nouns and named things.** `the gateway drops the session`, not `session continuity is
  impacted`.
- **Active voice with the actor named.** `the installer moves the file`, not `the file is moved`.
- **Vary sentence length.** A run of sentences of the same length reads mechanically no matter how
  plain the words are. Put a short one after a long one.
- **Caveats get their own sentence.** Stack them into subordinate clauses and the main claim
  disappears.
- **Repeat the term instead of finding a synonym.** Calling the same thing a skill, then a module,
  then a component makes the reader work out whether three things are meant.
- **Punctuate with full stops, commas, colons, and parentheses.** A colon introduces, a full stop
  separates, and most joins that feel like they need something stronger are two sentences.

## Signatures to check for

Each of these reads as machine-written. The first group is literal text, so check it with a command
rather than by eye:

```sh
grep -nEi '—|not just .{1,40} but|isn.t (just )?.{1,30}, it.s|delve|seamless|leverage|crucial|robust|dive in|landscape|tapestry|testament to' <file>
```

The rest need a read:

- **Rule of three.** Three parallel items where the third is padding, or a three-clause sentence
  built for cadence rather than content.
- **Bolded stub on every bullet.** Fine when the stubs are genuine labels the reader scans, as in
  this list. A tell when every bullet in the document opens that way regardless.
- **Negation-then-correction.** "This is not a linter, it's a discipline." Say what it is.
- **Rhetorical question openers.** "So what does this actually mean?"
- **Symmetrical closers.** A final paragraph whose only job is to sound like an ending.
- **Uniform bullet length.** Every bullet at the same size means some were padded to reach it.

## Rewriting text that already exists

- Cutting and reordering are in scope. A pass that only swaps words preserves the structure that
  made the text bad.
- Facts, numbers, file paths, links, commands, and code stay verbatim. Where the meaning is unclear,
  ask rather than smoothing it into something plausible.
- Report what was cut and why, so the author can put back anything that was load-bearing.
