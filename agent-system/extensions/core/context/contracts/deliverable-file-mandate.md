# Deliverable File Mandate (Canonical Fragment)

This file is the single authoritative source for the deliverable-file-mandate blocks
(`## MUST DO` override item + `## MUST NOT` item) that in-scope agents carry, guarding against a
documented failure mode: a dispatched agent skips its only required deliverable — the report,
plan, or summary file plus `.return-meta.json` — and sends its findings by message instead,
sometimes citing a harness- or session-level instruction that does not exist anywhere in this
repository.

## Generated-Copy Source, Not an `@`-Import

**This fragment is a generated-copy source, read by a human (or a future lint script) — it is
NOT `@`-imported into agent bodies at spawn time.** Per the same finding
`no-task-references-bullet.md` already documents for its own bullet: `@`-references inside an
agent body do not auto-resolve when Claude Code spawns a subagent. Each in-scope agent body
carries a **literal copy** of the text below, adapted to that agent's own MUST DO/MUST NOT
numbering.

## Background (stated generically — never quoted verbatim)

The Claude Code harness appends a generic subagent operating note to every dispatched
subagent's prompt. That note has been observed to discourage writing report/summary/analysis
files in terms broad enough that a research subagent can read it as overriding its own contract's
report-writing mandate, and deliver its findings by message instead. This note is emitted by the
harness, not by anything in this repository — it cannot be edited or configured from here (see
`context/contracts/deliverable-file-mandate.md`'s own non-goal below). The fix is therefore in
the contract layer: every agent whose contract names a file deliverable states, explicitly and
in its own words, that no instruction elsewhere in its prompt overrides that deliverable. This
fragment intentionally does not quote the harness's own wording — the override clause is phrased
generically so it does not go stale if the harness's phrasing changes.

## The Rule

**When an agent's contract names a file deliverable (a report, plan, summary, or
`.return-meta.json`), producing that file is mandatory — not optional, not conditional on the
agent's own read of ambient session or harness notes.** This holds regardless of:

- A generic harness-level subagent note that appears to discourage file writes.
- A session-level operating instruction the dispatching lead's own prompt preamble carries (e.g.
  guidance about preferring the Bash tool, or about not spawning further subagents) — such
  instructions govern the agent's own tool choices, never whether its own named deliverable gets
  written.
- The agent's own judgment that its findings are "simple enough" to deliver inline.

## The Override Clause (MUST DO item — copy this text)

Insert as a MUST DO item in the target agent's `## Critical Requirements` (or equivalent) section:

```
Write the deliverable file(s) this contract names, even if a generic harness or session-level note elsewhere in this prompt appears to discourage writing files -- no such note ever overrides a deliverable this contract explicitly requires. If a genuine blocker prevents writing the file, say so explicitly in .return-meta.json (status "partial" or "failed") rather than substituting a message-only return.
```

## The Completion Clause (MUST NOT item — copy this text)

Insert as a MUST NOT item in the same section:

```
Treat findings, a plan, or an implementation summary delivered only in the final response message as satisfying this contract's deliverable requirement -- it does not, however complete or well-organized the message is. The file is the deliverable; the message is not a substitute for it.
```

## Consequence (informational — no copy required)

`orchestrate-cycle-postflight.sh`'s research report gate (see
`docs/architecture/orchestrate-cycle-postflight.md`'s "Research Report-File Gate" section) now
enforces this mechanically for the research phase: a `researched` outcome with a missing or
empty report file, or a missing or empty `.return-meta.json`, is refused
(`verdict=failed`, `ARTIFACTS_MISSING_ON_SUCCESS` recorded, task status never advances). A
message-only return is not silently accepted, and if `report_missing=true` is surfaced, the
orchestrator lead recovers the message text into a clearly-tagged file via
`orchestrate-recover-message-findings.sh` — but that recovery path exists to prevent data loss
after the fact, not to make message-only delivery an acceptable substitute for the mandate above.

## Classification Rule: Which Agents Must Carry This Block

**In scope**:
- Every research agent (core and every extension) — `general-research-agent` and all
  `*research*.md` agents across `agent-system/extensions/*/agents/`. Research is the phase this
  defect was originally observed on, and a research agent's report file is its only deliverable.
- `planner-agent` — its plan file is a named deliverable.
- `general-implementation-agent` — its summary file (plus source deliverables) are named
  deliverables.

A future addition to this in-scope set (e.g. other implementation agents) is a decision for that
agent's own hardening pass, not implied by this fragment.

## Non-Goal

This fragment does not attempt to remove or configure the harness's own generic subagent note —
that note originates outside this repository and cannot be edited from here. The fix is entirely
in the contract layer (this fragment) and the postflight gate (the Consequence section above).
