# Implementation Plan: Task #378

- **Task**: 378 - Resolve the reviser-agent handoff contract contradiction between skill-orchestrate and orchestrate-cycle-plan.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/378_reviser_agent_handoff_contract_contradiction/reports/01_reviser-agent-handoff-contract.md
- **Artifacts**: plans/01_reviser-agent-handoff-writer.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Research confirmed the root-cause hypothesis and selected direction (a): `reviser-agent` is
reachable by two call paths with opposite handoff expectations, and its own contract file
documents neither. This plan closes the gap by giving `agents/reviser-agent.md` the same
`orchestrator_mode`-gated handoff-writing section every sibling writer already carries, then
aligns the three declared statements (schema doc, skill mapping table, and one stale script
comment about the same table) so no reader has to re-derive the writer set from the engine. Every
edit lands in the source store (`agent-system/extensions/core/**`), never in the deployed
`.claude/` mirror. No script behavior changes: `orchestrate-cycle-plan.sh`'s artifact-based
admission rule and `orchestrate-cycle-postflight.sh`'s dispatch-derived expectation predicate are
both left exactly as they are.

### Research Integration

Key findings carried into this plan:

- Call Path 1 (`aux_dispatch[]`, "Plan revision (blocker/drift)") hardcodes
  `orchestrator_mode: false` at both row-builders in `scripts/orchestrate-cycle-plan.sh` and
  supplies no `handoff_path` key at all; it also never reaches postflight. This path is correctly
  documented and must stay handoff-less.
- Call Path 2 (`dispatch[]`, `plan` phase) resolves to `reviser-agent` whenever
  `resolve_agent()`'s artifact-based admission rule finds an existing `plans/*.md`, and
  `skill-orchestrate/SKILL.md`'s Move 2 `dispatch[]` template is agent-agnostic: every row gets
  `orchestrator_mode: true` and a `handoff_path`. Confirmed independently against
  `scripts/orchestrate-build-dispatch.sh`, which emits the `## Handoff` section with
  `handoff_path` unconditionally for every dispatch kind — including this dispatch's own file.
- `agents/reviser-agent.md` contains zero occurrences of `.orchestrator-handoff.json`,
  `orchestrator_mode`, or `handoff_path`. Its only cross-dispatch sentinel is
  `{task_dir}/.plan-revised.json` (Stage 5c), a different file for a different consumer.
- `docs/architecture/handoff-schema.md`'s "Handoff Writers" table names only `planner-agent`
  beside the implementation agents, and its own "Registering a new writer" note states the fix is
  a table-row addition with no script-side registration step.
- The artifact-based plan admission is deliberate and test-pinned (Group 23 Cases C and E in
  `scripts/tests/test-orchestrate-cycle-plan.sh`), which is why direction (b) was rejected: it
  would require reintroducing exactly the per-agent-name allowlist that
  `orchestrate-cycle-postflight.sh`'s own D1 design comment records as deleted for drifting
  behind the agent roster.

Facts established by this planning pass, beyond the research report:

- `scripts/lint/lint-agent-contracts.sh` Check J is **content-gated**, not list-gated: it scans
  any agent file that mentions `.orchestrator-handoff.json` and requires a heading matching
  `` `.orchestrator-handoff.json` `` or `Wrap-Up`, bounding the section and asserting the
  `{type, path, summary}` artifacts requirement inside it. Adding the section therefore brings
  `reviser-agent.md` into Check J automatically, with no lint edit — and makes the new section's
  heading shape load-bearing.
- `scripts/tests/test-lint-agent-contracts-handoff-section.sh` is fixture-driven against an
  isolated scratch tree, so it cannot break from a real agent-file edit.
- `context/schemas/orchestrator-handoff-schema.json` requires
  `status, summary, artifacts, phases_completed, phases_total, blockers`; its `status` enum is
  `researched|planned|implemented|partial|failed|blocked` (no `description_updated`), and
  `scripts/validate-handoff.sh` Check 2c requires a **non-empty** `artifacts` array when status is
  `planned`. This settles the description-update edge case in Phase 1 below.
- `scripts/reconcile-task-status.sh:66` asserts that the Handoff Writers table places
  `planner-agent` in the "Never writes a handoff, by design" row. That is false today — the table
  places it in the Active row — so a fourth statement about the same table already disagrees with
  it. The comment's *conclusion* (no handoff writer emits `needs_research`) is unaffected and
  stays true after this change.
- `scripts/lib/suite-selection-lib.sh` maps `agents/reviser-agent.md` to three suites
  (`test-orchestrate-build-dispatch.sh`, `test-orchestrate-build-aux-dispatch.sh`,
  `test-orchestrate-cycle-plan.sh`), maps `docs/architecture/handoff-schema.md` to
  `__FULL_SWEEP__` (no covering suite — the expected result for a pure doc), and maps
  `skills/skill-orchestrate/SKILL.md` to seventeen-plus suites. This asymmetry drives the per-phase
  tiering below and is why the SKILL.md edit is deferred to the final, `full`-gated phase rather
  than carrying a twenty-suite narrowing list.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so no roadmap consultation was performed
and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Give `agents/reviser-agent.md` a conditional, `orchestrator_mode`-gated
  `.orchestrator-handoff.json` writing contract, so a `dispatch[]` plan-phase dispatch that
  resolves to it writes the handoff the dispatch asked for, and an `aux_dispatch[]` revision
  still writes none.
- Make the handoff contract self-consistent across all four places that state it:
  `agents/reviser-agent.md`, `docs/architecture/handoff-schema.md`'s Handoff Writers table,
  `skills/skill-orchestrate/SKILL.md`'s Skill-to-Agent Mapping table, and
  `scripts/reconcile-task-status.sh`'s comment about that table.
- Pin, in the agent contract itself, the two outcome mappings the schema and validator force but
  the reviser's existing Stage 6 vocabulary does not cover: how `description_updated` maps into
  the handoff status enum, and why `phases_completed` is not unconditionally `0` for a reviser.
- Leave `orchestrate-cycle-plan.sh` and `orchestrate-cycle-postflight.sh` byte-unchanged.

**Non-Goals**:
- Direction (b): reclassifying a forced-plan reviser row as handoff-exempt, by any mechanism
  (`--handoff-expected false` plumbing, an agent-name branch in postflight, or a Move 3 change).
  Rejected with recorded rationale; this plan does not revisit it.
- Any change to `resolve_agent()`'s artifact-based plan admission rule or to the Group 23 Case C/E
  assertions that pin it.
- Any edit under `.claude/**`. The deployed tree is a disposable deploy artifact; regeneration is
  manual-only (`context/patterns/regeneration-is-manual-only.md`), so the expected post-edit
  source/deploy drift on the touched files is not a gate failure to work around and is not this
  task's to resolve.
- Adding a new lint check that would FAIL if `reviser-agent.md` ever loses its handoff section
  again. Check J cannot catch that (a file with no mention of the file is skipped, not failed), so
  the hole is real — but closing it means a new curated in-scope list plus its own fixture suite,
  which is a separate, larger change than the contradiction this task was filed for. Recorded in
  Risks below and recommended as a follow-on rather than smuggled in here.
- Backfilling a handoff for the BimodalLogic dispatch that surfaced the defect; recovery from
  `.return-meta.json` already succeeded there and nothing was lost.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new section is written unconditionally, regressing Call Path 1 into writing a handoff on an `aux_dispatch[]` revision | H | M | Phase 1 mirrors `planner-agent.md`'s gate verbatim, including its "A delegation context that does NOT carry `orchestrator_mode: true` carries no handoff obligation" sentence, and adds a MUST NOT bullet naming the aux path explicitly; Phase 1 verification greps the landed section for both the positive gate and the negative sentence |
| The section heading drifts from the two forms Check J recognizes, so the lint silently cannot bound it (it FAILs loudly on heading drift, but only for a file that mentions the filename) | M | M | Phase 1 fixes the heading as `` ### `.orchestrator-handoff.json` (orchestrator-mode dispatches) `` — byte-identical in shape to `planner-agent.md`'s — and runs `lint-agent-contracts.sh` in-phase so Check J's bounded PASS line is observed, not assumed |
| A reviser handoff claims `status: planned` with an empty `artifacts` array in description-update mode, failing `validate-handoff.sh` Check 2c at write time | M | L | Phase 1 pins the mapping: a dispatch-path reviser that cannot produce a plan artifact writes `partial` with `[]` and a blocker naming the missing plan file, never `planned` |
| `phases_completed: 0` copied blindly from `planner-agent.md` under-reports preserved `[COMPLETED]` phases, mis-feeding the completion-claim gate that reads phase accounting | M | M | Phase 1 states the reviser-specific rule explicitly (count the `[COMPLETED]` phase headings in the plan it just wrote) instead of reusing planner's unconditional `0` |
| Nothing will detect a future deletion of the new section, since Check J skips a file that never mentions the handoff filename | M | M | Accepted and recorded, not silently absorbed: declared a Non-Goal above with its cost stated, and the Phase 3 summary records it as the recommended follow-on so a future reader finds the hole already named |
| The Handoff Writers table is cited as authoritative from several other places in the same file and from `reconcile-task-status.sh`, so a row edit can leave a second statement stale | M | M | Phase 2 re-greps `planner-agent` and `Handoff Writers` across the whole file after editing and reconciles every hit; Phase 3 fixes the one out-of-file citation (`reconcile-task-status.sh:66`) that is already stale today |
| A sibling dispatch edits one of the four touched files mid-cycle | M | L | Each phase stages only its own named files via the scoped-commit path and reviews `git status --short` before committing; a foreign modification is reported, not worked around |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. The serial chain is deliberate: the agent
contract must exist before the schema doc declares it a writer, and the skill table's clarifying
note should describe a contract that is already landed.

### Phase 1: Give reviser-agent the orchestrator_mode-gated handoff contract [COMPLETED]

**Goal**: `agents/reviser-agent.md` carries a handoff-writing section that is correct on both call
paths, passes Check J's bounded scan, and pins the two reviser-specific outcome mappings
(`description_updated` -> `partial`, `phases_completed` = preserved completed phases).

**Tasks**:
- [x] Re-read `agents/planner-agent.md`'s `` ### `.orchestrator-handoff.json` (orchestrator-mode
      dispatches) `` section in full (locate it by heading, not by line number — the research
      report's `:501-531` citation may have drifted) and confirm
      `grep -c 'orchestrator-handoff' agents/reviser-agent.md` is still `0` before editing.
      *(completed)*
- [x] Insert a new section into `agents/reviser-agent.md` between Stage 6 (Write Metadata File)
      and Stage 7 (Return Brief Text Summary), headed exactly
      `` ### `.orchestrator-handoff.json` (orchestrator-mode dispatches) `` so Check J's heading
      predicate bounds it. *(completed)*
- [x] In that section, mirror `planner-agent.md` for: the `orchestrator_mode: true` precondition;
      writing before returning on success, `partial`, and `blocked` alike; the absolute
      `handoff_path` rule with the `{task_dir}/.orchestrator-handoff.json` fallback and the
      never-a-bare-filename prohibition; the verbatim "A delegation context that does NOT carry
      `orchestrator_mode: true` carries no handoff obligation; do not write the file in that case"
      sentence; the `dispatch_seq` echo-verbatim rule; the pointer to
      `context/schemas/orchestrator-handoff-schema.json` and
      `docs/architecture/handoff-schema.md`; the `{type, path, summary}` artifacts-object shape
      with the bare-string prohibition; and the both-required `summary` (2-4 sentences) and
      `blockers` (`[]` is normal) fields with the `hooks/validate-handoff-location.sh` write-time
      gate note.
- [x] Add the reviser-specific content planner's section cannot supply, as explicit prose:
      (a) name the aux path — `aux_dispatch[]` "Plan revision (blocker/drift)" rows carry
      `orchestrator_mode: false` and no `handoff_path`, so no handoff is written there, and that
      is the expected case, not a miss; (b) `status` is `planned` on a completed plan revision,
      `partial`/`blocked` on an incomplete or blocked one, and `partial` with `artifacts: []` plus
      a blocker naming the absent plan file if the dispatch fell back to Description Update mode
      (never `planned` with an empty array, which `validate-handoff.sh` Check 2c rejects, and
      never the non-enum value `description_updated` that Stage 6's `.return-meta.json` vocabulary
      uses); (c) `phases_total` is the revised plan's phase count and `phases_completed` is the
      number of phases the revision preserved as `[COMPLETED]` — not planner's unconditional `0`,
      because a reviser routinely writes a plan containing already-finished work. *(completed)*
- [x] Add to "Critical Requirements" MUST DO: write `.orchestrator-handoff.json` when the
      delegation context carries `orchestrator_mode: true`, on every outcome including `partial`
      and `blocked`. *(completed)*
- [x] Add to "Critical Requirements" MUST NOT: write `.orchestrator-handoff.json` when the
      delegation context does not carry `orchestrator_mode: true` (the `aux_dispatch[]` plan-
      revision path), and never substitute `.plan-revised.json` or `.return-meta.json` for it.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
newly routes this file through Check J (whose bounded section scan is the exact check that covers
a handoff-writing section's content), together with
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-cycle-plan.sh`,
the three suites `suite-selection-lib.sh` resolves this path to.

**Scope Hypothesis**: This phase asserts that exactly one file changes
(`agents/reviser-agent.md`), that its pre-edit handoff-mention count is `0`, and that one inserted
section plus two Critical-Requirements bullets suffice. Confirm at implementation time with
`grep -c 'orchestrator-handoff' agents/reviser-agent.md` before the edit (expect `0`) and
`git status --short` after it (expect exactly this one path modified).

**Files to modify**:
- `agent-system/extensions/core/agents/reviser-agent.md` - new
  `` ### `.orchestrator-handoff.json` (orchestrator-mode dispatches) `` section between Stage 6
  and Stage 7; one new MUST DO bullet; one new MUST NOT bullet.

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0, and its
  output carries a Check J PASS line naming `core/agents/reviser-agent.md` (its absence means the
  heading did not match either recognized form and the section was never bounded).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-cycle-plan.sh`
  exits 0.
- `grep -n 'does NOT carry' agent-system/extensions/core/agents/reviser-agent.md` returns the
  negative-gate sentence, and the new section contains both `orchestrator_mode: true` and
  `handoff_path` — i.e. the gate is conditional in both directions, not unconditional.
- The section states `phases_completed` as the preserved-`[COMPLETED]` count (not `0`) and maps
  Description Update mode to `partial`, verifiable by reading the landed hunk.

---

### Phase 2: Register reviser-agent in the Handoff Writers contract text [COMPLETED]

**Goal**: `docs/architecture/handoff-schema.md` — the file that declares itself the single place
the writer set is settled — names `reviser-agent` as a writer under the same `orchestrator_mode`
gate, with no remaining statement in that file that implies otherwise.

**Tasks**:
- [x] Re-grep `grep -n 'planner-agent\|Handoff Writers' docs/architecture/handoff-schema.md` to
      re-locate every statement of the writer set (the research report found hits at the opening
      `**Written by**:` framing, the Handoff Writers prose, and the table row; re-derive rather
      than trusting those line numbers). *(completed)*
- [x] Extend the Handoff Writers table's active-writer row so it names `reviser-agent` alongside
      `planner-agent`, and add a Notes clarification that the `plan` phase's resolved agent is
      chosen by `orchestrate-cycle-plan.sh`'s artifact-based admission rule (existing
      `plans/*.md` -> `reviser-agent`, otherwise `planner-agent`) and that both land in the same
      `dispatch[]` array under `orchestrator_mode: true`, while `reviser-agent`'s separate
      `aux_dispatch[]` path carries `orchestrator_mode: false` and writes nothing. *(completed)*
- [x] Update the "plus `planner-agent`" phrasings in the surrounding prose (the `**Written by**:`
      header framing and the Handoff Writers narrative) so they no longer read as an exhaustive
      non-implementation writer list that excludes `reviser-agent`. *(completed)*
- [x] Leave "Registering a new writer" as-is: this phase is exactly the table-row-only change it
      prescribes, and no script-side registration step is being added. *(completed)*
- [x] Re-grep the file for any remaining statement that enumerates writers by name and would now
      be stale (including the `continuation_path` discussion the research report flagged); fix or
      explicitly leave each with a reason recorded in the commit body. *(completed: the
      `continuation_path` row at line 122 and the "exactly one writer" scope note at line
      ~833-835 are pre-existing, unrelated staleness -- the latter already contradicted this
      file's own corrected "every plan and implement agent" framing before this change, and
      fixing it is out of this task's scope; recorded here rather than silently left)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: Every changed hunk is markdown prose or table text in a file
`suite-selection-lib.sh` resolves to `__FULL_SWEEP__` (no covering suite, the expected result for
a pure doc), so the covering check is the source-store gate subset
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
plus a diff read-through.

**Scope Hypothesis**: This phase asserts that all edits are confined to
`docs/architecture/handoff-schema.md` and that the writer set is stated in a small, enumerable set
of places within it. Confirm by re-running
`grep -n 'planner-agent\|Handoff Writers' docs/architecture/handoff-schema.md` after the edit and
reading every hit, rather than assuming the pre-edit hit list was complete.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Handoff Writers table row
  and Notes cell; the `**Written by**:` header framing; the Handoff Writers narrative's
  "plus `planner-agent`" phrasings.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
  exits 0 (explicit source-store TARGET, never the bare no-argument form, which would run both
  gates' SKIP branch). *(deviation: altered -- this exact invocation exits 2, "no deploy tree at
  agent-system/extensions/core/.claude": `verify-deploy.sh`'s TARGET positional must be a repo
  root, since gates 3/4 classify source-store-vs-deploy-consumer by checking
  `TARGET/agent-system/extensions` and `TARGET/.claude`, not by TARGET itself being that
  subdirectory. Ran `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow
  --only-gate 3,4` with TARGET defaulted to the repo root instead -- PASS, 3 checks, 0 failures
  (doc-lint, STRICT_CORE_DEPLOY, task-reference lint). See progress file `approaches_tried` and
  `deviations`.)*
- `grep -n 'reviser-agent' docs/architecture/handoff-schema.md` shows it inside the Handoff
  Writers table's active row, not only in prose. *(verified)*
- Diff read-through confirms no hunk leaves markdown/table text, and no surviving sentence in the
  file states a writer set that excludes `reviser-agent`. *(verified)*

---

### Phase 3: Align the skill mapping table and the stale table citation, then close [COMPLETED]

**Goal**: The skill table a reader consults first no longer reads as contradicting the engine, the
one out-of-file citation of the Handoff Writers table that is already false is corrected, and the
whole change is verified against the complete gate set and closed with a summary.

**Tasks**:
- [x] In `skills/skill-orchestrate/SKILL.md`'s Skill-to-Agent Mapping table, add a clarifying note
      (beneath the table, or in the Plan row's notes cell) stating that a `dispatch[]` Plan row's
      resolved agent is `planner-agent` OR `reviser-agent` depending on
      `orchestrate-cycle-plan.sh`'s artifact-based admission rule, that either resolved agent
      receives `orchestrator_mode: true` and a `handoff_path` from Move 2's generic row template,
      and that this is a different path from the "Plan revision (blocker)" / "(drift)"
      `aux_dispatch[]` rows below it, which carry `orchestrator_mode: false`. Do not alter the
      existing aux rows — each is already accurate for the path it describes. *(completed: added
      as a short parenthetical inside the existing "Research / Plan / Implement dispatch" row's
      Notes cell, not a separate paragraph, to minimize the Gate 20 byte-ceiling impact -- see
      Plan Deviations)*
- [x] Correct `scripts/reconcile-task-status.sh`'s comment claim that the Handoff Writers table
      places `planner-agent` in the "Never writes a handoff, by design" row: it is in the active
      row, and `reviser-agent` now joins it. Preserve the comment's conclusion — neither writer
      emits `needs_research` into a handoff, so the `needs_research` path through this function
      stays unreachable — and keep the edit comment-only, with no change to any executable line.
      *(completed)*
- [x] Re-read all four touched files' diffs end to end as one change set, confirming the four
      statements (agent contract, schema doc, skill table, script comment) now agree and that no
      executable line was altered in either script-adjacent file. *(completed)*
- [x] Record this phase's own issue-log entries via `issue-record.sh` (including an explicit
      nothing-to-record attestation if that is the honest outcome). *(completed: two entries
      recorded -- the Gate 20 scope-excursion fix to orchestrator-context-budget.json, and the
      two scoped-suite failures attributed to concurrent sibling task 381)*
- [x] Write the completion summary artifact under `summaries/`, naming the follow-on recommendation
      from Non-Goals (no lint check detects a future deletion of the new handoff section, because
      Check J skips a file that never mentions the filename) so it is discoverable without
      re-deriving it. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that exactly two files change
(`skills/skill-orchestrate/SKILL.md` and `scripts/reconcile-task-status.sh`), that the SKILL.md
change is additive (a note, with the existing aux rows untouched), and that the
`reconcile-task-status.sh` change touches only comment lines. Confirm with `git status --short`
(expect exactly those two paths modified in this phase) and by checking that
`git diff -- agent-system/extensions/core/scripts/reconcile-task-status.sh` contains only
comment-prefixed lines.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - clarifying note on the
  Skill-to-Agent Mapping table's Plan dispatch row.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` - correct the stale Handoff
  Writers table citation in the header comment block (comment-only).

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core` exits
  0 — the complete gate set, including Gate 8's full shell-suite battery, run in this dispatch and
  observed green rather than trusted on sight. *(deviation: altered -- this dispatch's own
  dispatch file carries a Batch Gate Deferral directive for this multi-task batch invocation.
  Discharged instead via the `suite-selection-lib.sh`-derived union of 28 suites covering this
  phase's two touched files (`run-all.sh --only ...`), plus `lint-agent-contracts.sh`,
  `lint-contract-compliance.sh`, `lint-shellcheck.sh`, and `verify-deploy.sh --only-gate 20`
  directly (required by this dispatch's own top-level Gate 20 instruction, since this phase added
  text to SKILL.md). Result: 25/28 scoped suites passed; 1 pre-existing EXPECTED failure
  (`test-verify-deploy-context-budget.sh`, a fixture-cleanliness issue unrelated to this phase's
  gate20 ceiling numbers) and 2 failures attributed to concurrent sibling task 381's in-flight
  work on `orchestrate-cycle-postflight.sh` and its own test file -- see progress file and issue
  log. The complete gate set runs once at the batch level per the deferral directive.)*
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` and
  `bash agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` both exit 0.
  *(verified: both PASS)*
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0, confirming the
  comment-only script edit introduced no shell finding. *(verified: PASS, 0 findings)*
- Any `.claude/` source/deploy staleness reported by the gate run for the four touched files is
  recorded as expected (regeneration is manual-only) and is not treated as a failure to repair
  inside this task. *(verified: `check-extension-docs.sh` reports exactly this expected drift for
  `scripts/reconcile-task-status.sh`'s deployed copy; not treated as a failure)*

---

## Testing & Validation

- [x] `agents/reviser-agent.md` appears in `lint-agent-contracts.sh`'s Check J output with a PASS
      line (proving the section's heading was recognized and its artifacts requirement found).
      *(verified)*
- [x] The new section is conditional in both directions: it requires a handoff under
      `orchestrator_mode: true` and explicitly forbids one otherwise. *(verified)*
- [x] The status/artifacts/phase-accounting rules in the new section are consistent with
      `context/schemas/orchestrator-handoff-schema.json` and with `validate-handoff.sh`'s Check 2c
      (no `planned` with an empty `artifacts` array; no off-enum `description_updated`).
      *(verified)*
- [x] `docs/architecture/handoff-schema.md`, `skills/skill-orchestrate/SKILL.md`,
      `agents/reviser-agent.md`, and `scripts/reconcile-task-status.sh` make mutually consistent
      claims about whether a `reviser-agent` plan dispatch writes a handoff. *(verified)*
- [x] `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core`
      exits 0 at the end of Phase 3. *(deviation: altered -- discharged via the batch-deferred
      scoped tier instead, per this dispatch's Batch Gate Deferral directive; see Phase 3's own
      Verification notes above)*
- [x] `scripts/orchestrate-cycle-plan.sh` and `scripts/orchestrate-cycle-postflight.sh` are
      byte-unchanged (`git diff --stat` empty for both). *(verified: both empty)*

## Artifacts & Outputs

- `agent-system/extensions/core/agents/reviser-agent.md` (modified) - new handoff-writing section
  plus two Critical-Requirements bullets.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (modified) - `reviser-agent`
  registered in the Handoff Writers table.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (modified) - clarifying note on
  the Plan dispatch row's resolved-agent ambiguity.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (modified) - corrected,
  comment-only citation of the Handoff Writers table.
- `specs/378_reviser_agent_handoff_contract_contradiction/summaries/01_reviser-agent-handoff-writer-summary.md`
  (new) - completion summary carrying the follow-on recommendation.
- Three scoped commits, one per phase, following `task {N}: ...` conventions.

## Rollback/Contingency

Every change is an additive edit to four text files with no executable-line change and no schema
or script behavior change, so rollback is a per-file revert of the phase's own commit
(`git revert <sha>` for the phase, or `git checkout <pre-phase-sha> -- <path>` for a single file
once the tree is clean). Reverting restores the pre-existing state exactly: `reviser-agent` goes
back to writing no handoff on either path, and postflight resumes recovering that dispatch's
outcome from `.return-meta.json` — the same non-lossy recovery the originating incident already
exercised in the BimodalLogic repo. There is no migration, no state to unwind, and no deployed
artifact to repair, because `.claude/**` is regenerated from the source store rather than edited.
If Phase 1's section proves unable to satisfy Check J's heading predicate after two attempts, stop
and report rather than widening the lint: a heading the lint cannot bound is a signal the section
shape is wrong, not that the check is.
