---
name: GR-writing
disable-model-invocation: true
description: Write or rewrite a document a person will read, following the shared prose directives.
argument-hint: "a file path, pasted text, or nothing to take the last thing produced"
---

# Evo Writing

Produce prose a teammate reads without noticing it was generated. Read
`~/.claude/GR-references/writing-for-people.md` first and follow it; this skill is the procedure
around it, not a second copy of the rules.

## 1. Take the input

| Given | What it is |
|---|---|
| A path that exists | Rewrite pass over that file. |
| A path that does not exist yet, or a description of a document to produce | New document, drafted to the directives from the start. |
| Pasted text | Rewrite pass; return the result in the reply rather than writing a file. |
| Nothing | The last document produced in this session. Name it and confirm before touching it. |

## 2. State the reader and the job

One line, before writing: who reads this, and what they do after reading it. A README is read by a
teammate deciding whether to install the thing. A PR body is read by a reviewer deciding whether the
change is right. This line decides what can be cut, so it comes before any cutting.

## 3. Cut

For an existing document, list what goes and why before editing: restatement, filler, paragraphs
carrying only transition, sections the reader already knows. For a new one, this is the outline
decision, meaning which sections earn their place at all.

Facts, numbers, paths, links, commands, and code survive verbatim. Where the source text is unclear
about a fact, ask rather than writing a plausible version of it.

## 4. Write

Apply the sentence-level targets in the directives. Structure is in scope for a rewrite: reorder
sections, merge them, split a wall of prose into a table where the content is a table.

## 5. Verify

Run the signature grep from the directives against the result:

```sh
grep -nEi '—|not just .{1,40} but|isn.t (just )?.{1,30}, it.s|delve|seamless|leverage|crucial|robust|dive in|landscape|tapestry|testament to' <file>
```

Then read for the ones no command catches: rule-of-three padding, bolded stubs on every bullet,
negation-then-correction, rhetorical openers, a closer that only sounds like an ending, bullets all
padded to the same length.

## Done when

- The grep returns nothing, or every remaining hit is a deliberate keep, named and justified.
- The judgement-level signatures have been checked and the result stated.
- What was cut is reported, with a reason per item, so the author can restore anything load-bearing.
