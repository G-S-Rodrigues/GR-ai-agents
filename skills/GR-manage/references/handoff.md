# Handoff: pass the run to a fresh coordinator without losing work in flight

Reached by `/GR-manage handoff`, or by your own context-budget trigger (**Coordinating a run** in
`context-budget.md`). Either way the subagents already running are worth hours, and they live in
**this** session's process: closing it kills them. So this session does not end. It writes a handoff,
stops coordinating, and stays open as a **relay** — it files each late result where the successor reads
it — while the successor coordinates from the files alone.

The relay and the successor each own their half: the relay only appends `RESULT` lines and writes the
result files the handoff names; the successor owns everything else in the ledger and the report.

## Steps

1. **Freeze.** The dispatch already made is the last one from this session. Done when nothing new has
   been sent since the handoff began.

2. **Give every agent in flight a landing file.** For each running subagent, record its id, what it
   is doing, and the file its result lands in. Use the file its prompt already names; one whose prompt
   names none gets a `SendMessage` naming one (a report under `run/reports/`, the plan or the
   progress file). An agent with no write tool (`GR-researcher`, `Explore`) cannot land it: the relay
   writes it (step R1 below). Owner-call timers: the call's expiry and recommendation go in the ledger,
   so the successor settles it. Done when every agent and timer this session started is in the table
   of step 4, and none is missing.

3. **Write the ledger.** Every result received but not yet recorded, then one line:
   `<date> HANDOFF (<owner asked | context trigger>): successor reads run/handoff-<date>-coordinator.md`.

4. **Write `<scratch>/<feature>/run/handoff-<date>-coordinator.md`**, under ~120 lines, in this shape:

   ```markdown
   # Handoff: continue <feature> as coordinator (<date>)
   <one paragraph: run /GR-manage on it, re-ask nothing in the ledger, start your own watch and safety net>

   ## Read first (do not re-derive)
   <ledger, report, the plans in play, the findings files the next steps rest on>

   ## Where it stands
   | Part | Branch / worktree, head | State |       <every part, merged ones with PR and merge SHA>
   main = <sha>. Nightly last read: <run id, result, sha>.

   ## Agents still running from the old session
   They belong to session <id>; the successor cannot message them.
   | Agent (type, id) | Doing | File it writes | If it never appears |
   <one row per step-2 entry. The fallback names the check (worktree idle, no new section) and the
   re-dispatch. For an agent with no write tool, it gives the extraction command:>
   jq -r 'select(.type=="assistant")|.message.content[]?|select(.type=="text")|.text' \
     ~/.claude/projects/<project>/<session-id>/subagents/agent-<id>.jsonl | tail -c 20000

   ## Next, in order
   <numbered, each naming its stage, the skill or agent, and what binds it (rulings by ledger id)>

   ## Waiting on the owner
   <each open call: what it decides, recommendation, expiry or "parks">

   ## Rules that bit this run
   <traps hit and how they were handled, one line each>
   ```

   Done when a session that has read only this file and the ledger could make the next dispatch
   without asking anything.

5. **Stop coordinating.** `CronDelete` the safety net and `TaskStop` the context watch, so this session
   never resumes as coordinator. Update the report's **Now** to name the successor and the relay.

6. **Hand the owner the command**, in its own `bash`-tagged block, and the list of agents the relay is
   still waiting on:

   ```
   /GR-manage Read <scratch>/<feature>/run/handoff-<date>-coordinator.md and continue from it.
   ```

   Tell them to keep this session open until the relay reports its last agent landed.

## The relay

Every late report or task notification that reaches this session afterwards gets exactly this:

- **R1.** If the agent did not write its own landing file, write its report there, verbatim in
  substance and headed with who wrote it and why.
- **R2.** Append one ledger line: `<date> RESULT: <agent> -> <file>. <one sentence of what it found>`.
- **R3.** Mark its row in the handoff file `DONE: <file>`.
- **R4.** Reply to the owner in two or three lines: what landed, where, and what the successor does
  with it.

Nothing else: no dispatch, no analysis, no ruling. A relayed report that asks for a decision is the
successor's to make. A repeated or `is waiting on its own background work` notification from an agent
already filed gets one line and nothing more. When the last row is `DONE`, tell the owner this session
can be closed.
