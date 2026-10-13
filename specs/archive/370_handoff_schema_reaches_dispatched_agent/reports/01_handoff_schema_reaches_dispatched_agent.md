# Research Report: Task #370

**Task**: 370 - Make the `.orchestrator-handoff.json` schema reach the dispatched agent before it writes the handoff
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: medium
**Dependencies**: None (new ordering edge against Task 359 recommended below)
**Sources/Inputs**: Codebase read-through of the handoff write/validate/dispatch chain (no web search needed — this is a closed, internal mechanism)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The measured incident's proximate cause is **not** an absent schema pointer in the dispatch
  file — it is a **stale worked JSON example inside `lean-implementation-hard-agent.md` itself**
  (`agent-system/extensions/lean/agents/lean-implementation-hard-agent.md:311-341`) that omits
  `artifacts` entirely and still carries a redundant `"continuation_context": null`. This is
  already a named, documented, unlanded gap in `docs/architecture/handoff-schema.md:491` — the
  doc just hadn't been acted on.
- **Every other implementation agent** writing `.orchestrator-handoff.json` under
  `orchestrator_mode: true` (general, neovim, nix, email, lean non-hard, plus `planner-agent`)
  already carries an identical, correct, inline boilerplate paragraph stating the
  `{type, path, summary}` artifacts shape and the required-fields list, reachable in the agent's
  own contract before it writes anything. The pattern already works; it just isn't applied
  uniformly across the `*-hard` family.
- `cslib-implementation-hard-agent.md` had the **same** two gaps the doc names, but has
  **already been fixed** (its Stage 5 example now includes `"artifacts": [{"path": ..., "type":
  ..., "summary": ...}]` and a rationale paragraph, and no longer writes
  `continuation_context: null`) — the doc's claim about cslib is now stale. This fixed version is
  the proof-of-pattern for repairing lean's.
- `lint-agent-contracts.sh`'s existing Check F (return-meta artifacts-template presence) is a
  **whole-file** scan and structurally cannot catch this exact regression: `lean-implementation-
  hard-agent.md` already carries a correctly-shaped `artifacts` block in its separate
  `.return-meta.json` section (Stage 8, `lean/agents/lean-implementation-hard-agent.md:641-652`),
  so Check F passes on this file today even though its `.orchestrator-handoff.json` section
  (Stage 5) is the one that is broken. A new, section-scoped check is needed, not an extension of
  Check F.
- The `partial`-status `artifacts` conditional is **already fully decided and encoded** in three
  places that agree: `context/schemas/orchestrator-handoff-schema.json`, `validate-handoff.sh`,
  and `context/contracts/wrap-up.md:67-69` ("may be `[]` only when `status` is
  `partial`/`blocked`/`failed`; non-empty required when `status` is `implemented`"). No new rule
  is needed — only applying it where it is currently missing (lean's Stage 5).
- **Recommended route: (b)** — fix the concrete broken contract (and the stale doc claim), and
  add a section-scoped lint check so this class of regression is caught mechanically rather than
  by a production incident. Routes (a), (c), (d) are evaluated and rejected below, each on a
  demonstrated reason, not a guess.

## Context & Scope

Scope: determine why the schema `validate-handoff.sh` enforces against
`.orchestrator-handoff.json` failed to reach a dispatched agent (the measured
`lean-implementation-hard-agent` incident in a different repo on 2026-10-08, re-confirmed against
this repo's copy of the same agent-system source), and recommend which of four named routes (or a
reasoned rejection of all four) closes that gap durably. Per the dispatch's constraint, the
recommendation must be verifiable by inspecting a composed artifact (an agent file diff, a lint
run) — not by asserting new prose exists.

This is a `meta` task; research consisted entirely of codebase exploration (no web search): the
handoff schema, its validator, every writer agent's own wrap-up contract, the dispatch-file
generator, the lint tooling, and the already-completed fix in a sibling `*-hard` agent
(`cslib-implementation-hard-agent.md`) that this task's gap mirrors.

## Findings

### Codebase Patterns

**The handoff contract chain, as it exists today:**

1. `context/schemas/orchestrator-handoff-schema.json` — the draft-07 JSON Schema, single machine-
   checkable source of truth. Already correctly encodes: `artifacts` required, non-empty only for
   `researched`/`planned`/`implemented` (its own description field states this explicitly).
2. `scripts/validate-handoff.sh` — implements that exact conditional correctly (Check 2c: `case
   "$status" in researched|planned|implemented) ... -gt 0 ... *) legal empty`). Runs at write
   time (`hooks/validate-handoff-location.sh`, rejecting with `exit 2`) and once more at
   postflight (`orchestrate-cycle-postflight.sh`, non-gating, durably recorded).
3. `context/contracts/wrap-up.md` ("H9 prose contract") — the canonical worked example
   (`wrap-up.md:46-67`) includes `artifacts` correctly and states the conditional in prose
   immediately below it. This is the contract every `*-hard` agent is supposed to implement.
4. `docs/architecture/handoff-schema.md` — exhaustive prose companion, including a dedicated
   "Handoff Writers — the settled decision, in one place" section (`:469`) and a Writers table
   (`:491`) that **already names this exact gap**, with the caveat "both extensions are out of
   this document's declared scope" — i.e. documented but deliberately left unfixed pending a task
   like this one.
5. `scripts/orchestrate-build-dispatch.sh:522-526` — the dispatch file's `## Handoff` section.
   Confirmed by direct inspection of this very dispatch's own composed file
   (`specs/370_handoff_schema_reaches_dispatched_agent/.dispatch/1.md:100-104`): it supplies only
   `handoff_path` and `task_dir`, unconditionally, to every dispatch kind (research included,
   even though research never writes the file). It carries no schema content and no pointer to
   the schema.

**Where the pattern is correct vs. where it drifted — verified by direct comparison:**

- `general-implementation-agent.md:815-824`, `planner-agent.md:524-532`, and the identical
  boilerplate in `neovim-implementation-agent.md`, `nix-implementation-agent.md`,
  `email-implementation-agent.md`, and `lean-implementation-agent.md` (non-hard) **all** carry the
  same paragraph, verbatim or near-verbatim: "Use the shape defined by
  `context/schemas/orchestrator-handoff-schema.json` ... `artifacts[]` entries MUST use that
  schema's `{type, path, summary}` object shape, never a bare path string," followed by "`summary`
  and `blockers` are BOTH required top-level fields." None of these six agent files give a full
  literal JSON example for `.orchestrator-handoff.json` — they state the shape in prose and point
  at the schema. This pattern is demonstrably reachable and demonstrably worked: none of these six
  agents is implicated in any measured incident.
- `lean-implementation-hard-agent.md:291-341` (Stage 5, "Step 1: Write the orchestrator handoff")
  departs from that shared boilerplate. Instead of the prose-plus-pointer pattern, it gives a full
  hand-maintained JSON example (lines 311-341) that omits `artifacts` entirely and still writes
  `"continuation_context": null` (a deprecated, no-longer-canonical field per
  `docs/architecture/handoff-schema.md`'s "One Write Form" section). This file contains the string
  `artifacts` exactly once (line 642, inside its separate Stage 8 `.return-meta.json` section) —
  never once inside its Stage 5 `.orchestrator-handoff.json` section.
- `cslib-implementation-hard-agent.md` had the identical pattern-deviation and the identical two
  gaps the doc names (`:317-360`). It has since been **fixed**: its Stage 2 example
  (`cslib-implementation-hard-agent.md:338-353`) now reads
  `"artifacts": [{"path": "...", "type": "summary", "summary": "..."}]` inline in the JSON block,
  immediately followed by a dedicated "`artifacts` linking rationale" paragraph
  (`:363-366`) explaining why an absent/empty array silently breaks linking, and the file no
  longer writes `continuation_context` in any form (`:359`: "Never write the nested
  `continuation_context` object"). **`docs/architecture/handoff-schema.md:491`'s claim that
  cslib "lacks the `artifacts`-shape spec" is therefore stale** — only the lean half of that
  sentence is still true. This fixed file is the working template to copy from.

**Why `lint-agent-contracts.sh`'s existing Check F cannot catch this:**

Check F (`scripts/lint/lint-agent-contracts.sh:352-447`, helper `has_artifacts_object_shape` at
`:379`) scans an agent's **entire file** for any occurrence of `"artifacts"` followed within ~6
lines by `type`/`path`/`summary` keys, and PASSes if found anywhere. Because
`lean-implementation-hard-agent.md` has a correct `artifacts` block in its Stage 8
`.return-meta.json` section, Check F already PASSes on this exact file today — it has no way to
distinguish "the `.return-meta.json` section is correct" from "the `.orchestrator-handoff.json`
section is correct," because it does not scope its scan to either section. A regression exactly
like the measured incident would pass Check F silently, as it evidently has.

**Backlog overlap, re-verified against `specs/TODO.md:1229` (Task 359, `[NOT STARTED]`):** 359 is
scoped exactly to two curated-array coverage gaps in `lint-agent-contracts.sh` Check C/G (books
agents, bounded-wait scope for 23 research agents), editing `lint-agent-contracts.sh` and its test
file, and its own description explicitly argues against folding a third, unrelated check into it.
A new Check (as recommended below) touches the same two files 359 is about to edit. This is a
genuine, not merely nominal, territory overlap.

### External Resources

None consulted — this is a closed, internal-mechanism question with no external prior art to
draw on; all four candidate routes are fully specified by files already in this repository.

## Decisions

- **The `artifacts`/`partial` conditional is already correctly decided and does not need a new
  rule.** `context/schemas/orchestrator-handoff-schema.json`, `validate-handoff.sh`, and
  `wrap-up.md:67-69` already agree: `artifacts` must be present as an array always; non-empty is
  required only when `status` is `researched`/`planned`/`implemented`; `[]` is legal for
  `partial`/`blocked`/`failed`. The task's "ALSO DECIDE" instruction is satisfied by confirming
  this existing, consistent rule — not by inventing a new one.
- **Route (b) is selected.** Reasoning for rejecting the other three, each on a concrete,
  demonstrated basis rather than a guess:
  - **(a) — add the schema to `orchestrate-build-dispatch.sh`'s `## Handoff` section** is
    rejected as the primary fix: six of the seven writer agents already state the exact required
    shape correctly, inline, in their own contracts, with zero incidents — proving an agent does
    not need the dispatch file to restate the schema when its own contract is correct. Adding it
    to the dispatch file's `## Handoff` section would also inject handoff-write instructions into
    every research dispatch (this very dispatch included), which never writes the file at all —
    pure noise for the one phase that is schematically exempt. It does not fix the actual broken
    file, only works around it a second time (exactly the "per-run prompt injection" workaround
    the task names as evidence of the defect, not a fix).
  - **(c) — `docs/architecture/handoff-schema.md` plus a dispatch-file pointer** is rejected:
    `handoff-schema.md` already exists, is exhaustive, and is already linked from every writer's
    wrap-up section, including `lean-implementation-hard-agent.md`'s own ("see
    `docs/architecture/handoff-schema.md`'s `### status (required)` field definition"). The
    incident happened anyway, because the agent's own inline worked example (what an agent
    pattern-matches against, not a doc it is merely linked to) contradicted the doc it links to.
    A dispatch-file pointer to a doc the writer already points to itself does not change what the
    writer actually copies from.
  - **(d) — a validator-adjacent shared template the agent is pointed at** is rejected as a
    second, parallel source of truth: `wrap-up.md`'s own worked example (`:46-67`) already *is*
    exactly this template, correctly shaped, and is the canonical H9 contract
    `lean-implementation-hard-agent.md` is already supposed to implement. Introducing a second
    template file does not fix an agent that already has one correct template to copy and
    nonetheless drifted from it; the fix is bringing the drifted file back into conformance with
    the template that already exists, not adding another one.
  - **(b) — fix the implementation agents' own contracts, lint-checkable** is supported directly
    by the evidence: the defect is concretely located inside one file
    (`lean-implementation-hard-agent.md`'s Stage 5 example), a working fixed reference for the
    identical defect already exists in a sibling file (`cslib-implementation-hard-agent.md`), and
    the reason it recurred/wasn't caught (Check F's whole-file scope) is itself a concrete,
    named, fixable gap in the lint tooling.
- **Ordering edge recommended**: declare Task 370 `--depends-on-add` Task 359 at plan time (both
  edit `lint-agent-contracts.sh` and its test file; 359 is `[NOT STARTED]` and explicitly scoped
  away from adding a third check, so sequencing 370's lint-file edit after 359's lands avoids a
  concurrent hand-edit collision on the same two files, per the Batching/territory guidance this
  dispatch's own Territory section points at).
- **File scope for the plan** (informational — the plan sets this formally, per the dispatch's
  "FILE SCOPE IS DELIBERATELY ABSENT" instruction): the research found the concrete edit targets
  to be `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` (content fix),
  `agent-system/extensions/core/docs/architecture/handoff-schema.md` (remove the now-stale cslib
  half of the `:491` table-cell claim, and update/close the lean half once fixed), and
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` plus its test file (new,
  section-scoped check). Whether `lean/**` is in scope alongside `core/**` (the dispatch
  description's "SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/**" line appears
  to be generic boilerplate carried into every meta-task description, since the same description
  separately anticipates "the agent definitions" — unscoped to core — as a route-(b) touch point)
  is a plan-time call, not resolved here.

## Recommendations

1. **Fix `lean-implementation-hard-agent.md`'s Stage 5 wrap-up example** (lines ~311-341) to match
   `cslib-implementation-hard-agent.md`'s already-fixed version: add
   `"artifacts": [{"path": "...", "type": "summary", "summary": "..."}]` to the JSON example, add
   a short "`artifacts` linking rationale" paragraph (copy cslib's), and remove the now-redundant
   `"continuation_context": null` line (the flat `continuation_path` field two lines above it is
   the only canonical form).
2. **Update the stale claim in `docs/architecture/handoff-schema.md:491`**: the cslib half of the
   "Two known, named, unlanded gaps" sentence is no longer true and should be removed/corrected;
   the lean half should be updated to reflect the fix once item 1 lands (or removed entirely if
   this task closes it in the same cycle).
3. **Add a new, section-scoped lint check** to `lint-agent-contracts.sh` (distinct from Check F,
   which is whole-file and therefore structurally blind to this regression): for every agent in
   the Handoff Writers table (every `*-implementation-agent`/`*-implement-agent` plus
   `planner-agent`), locate its `.orchestrator-handoff.json`-writing section (anchor on the
   literal heading/string used consistently across all current writers, e.g. `` `.orchestrator-
   handoff.json` (orchestrator-mode dispatches) `` or the Stage/Step heading that introduces the
   write, bounded to the next same-or-higher-level heading) and verify an object-shaped
   `artifacts` occurrence (reusing `has_artifacts_object_shape`'s detection logic) appears within
   that bounded section specifically — not merely anywhere in the file. FAIL if the section exists
   but no correctly-shaped `artifacts` mention is found inside it.
4. **Sequence after Task 359** via a declared dependency, per the Decisions section above, since
   both touch `lint-agent-contracts.sh` and its test file.
5. **Do not touch `orchestrate-build-dispatch.sh`, `handoff-schema.md`'s doc content beyond the
   one stale-claim correction, or introduce any new shared template file** — per the Decisions
   section, routes (a)/(c)/(d) are each rejected on a demonstrated basis, and adding any of them
   now would be exactly the "new prose document that no dispatch actually reads" failure mode the
   dispatch explicitly warns against, on top of a fix that is already fully specified and already
   proven to work (cslib) without them.

## Risks & Mitigations

- **Risk**: a new lint check that anchors on a literal heading string is brittle if a future agent
  file phrases its handoff-writing section differently. **Mitigation**: anchor on the literal
  string `.orchestrator-handoff.json` combined with a nearby `orchestrator_mode` or `handoff_path`
  mention (all seven current writers use near-identical phrasing, giving a reliable, shared
  anchor), and fail loudly (not silently skip) when no such section is found at all in a listed
  writer, so a drifted heading is caught rather than silently passed.
- **Risk**: fixing only `lean-implementation-hard-agent.md` leaves the *mechanism* (a `*-hard`
  agent choosing to hand-write a full JSON example instead of the shared prose-plus-pointer
  boilerplate) free to reintroduce the same class of drift in a future `*-hard` agent not yet
  written. **Mitigation**: this is exactly what recommendation 3's lint check durably covers going
  forward — it is written once, against the Handoff Writers table, and applies to any future
  writer added to that table without per-agent registration beyond adding the row (mirroring how
  Check F already requires no extra registration step beyond the dispatchable-agent detector).
- **Risk**: declaring a dependency on Task 359 could stall Task 370 if 359 itself stalls (359
  depends on Tasks 350 and 356). **Mitigation**: this is a minor, bounded risk — 370's own fix to
  `lean-implementation-hard-agent.md` (recommendation 1) and the doc correction (recommendation 2)
  do not touch `lint-agent-contracts.sh` at all and could land independently; only the lint-check
  addition (recommendation 3) needs the ordering edge, so the plan could sequence 1-2 as an
  earlier phase and 3-4 as a later phase gated on 359, rather than blocking the whole task.

## Context Extension Recommendations

None. The relevant context (`wrap-up.md`, `handoff-schema.md`, the schema JSON file) is already
thorough, already indexed (`wrap-up.md` is indexed under the "handoff" topic in
`.claude/context/index.json`), and already correctly cross-referenced from every writer agent.
The gap found here is a single file's drift from an existing, correct, well-documented contract —
not a documentation coverage gap.

## Appendix

- Searches/reads performed: `scripts/validate-handoff.sh`,
  `context/schemas/orchestrator-handoff-schema.json`, `docs/architecture/handoff-schema.md` (full
  1094 lines, headings enumerated), `context/contracts/wrap-up.md` (schema section),
  `scripts/orchestrate-build-dispatch.sh` (`## Handoff` section generation),
  `scripts/lint/lint-agent-contracts.sh` (Check F and its helper), and the `.orchestrator-
  handoff.json`-writing sections of `general-implementation-agent.md`, `planner-agent.md`,
  `neovim-implementation-agent.md`, `nix-implementation-agent.md`, `email-implementation-agent.md`,
  `lean-implementation-agent.md`, `lean-implementation-hard-agent.md`, and
  `cslib-implementation-hard-agent.md`.
- `specs/TODO.md:1229` (Task 359, backlog-overlap re-verification).
- `.claude-extensions.json` (confirmed loaded extensions: core, email, lean, literature, memory,
  nix, nvim; `cslib` exists in the shared source store at `agent-system/extensions/cslib/` even
  though not loaded into this repo's deployed tree, since this repo is the source store for the
  whole agent-system).
