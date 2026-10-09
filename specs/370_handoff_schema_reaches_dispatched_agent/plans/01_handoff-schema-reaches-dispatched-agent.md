# Implementation Plan: Task #370

- **Task**: 370 - Make the `.orchestrator-handoff.json` schema reach the dispatched agent before it writes the handoff
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None declared (file-level overlap with Task 359 recorded in Risks; see "Ordering edge against Task 359" below)
- **Research Inputs**: specs/370_handoff_schema_reaches_dispatched_agent/reports/01_handoff_schema_reaches_dispatched_agent.md
- **Artifacts**: plans/01_handoff-schema-reaches-dispatched-agent.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Route (b) from the task description is selected: repair the one agent contract whose
handoff-writing section does not state the `artifacts` requirement, correct the stale claim in
the architecture doc that already named this gap, and add a section-scoped lint check so the
regression class is caught mechanically instead of by a production incident. The fix is
verifiable on a real lint run — not by asserting new prose exists — which is what the task's
acceptance bar requires. No new document is created, and `orchestrate-build-dispatch.sh` is not
touched.

### Research Integration

The research report's route selection and its rejection of routes (a), (c), and (d) are adopted
as written, and its two concrete repair targets were re-confirmed by direct inspection:

- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` Stage 5 (lines
  ~291-394): its JSON example omits `artifacts` entirely and still writes
  `"continuation_context": null`. The string `artifacts` appears in this file exactly once, at
  line 642, inside the separate Stage 8 `.return-meta.json` section — never inside the Stage 5
  handoff section.
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (lines ~343-366) is
  the already-fixed reference: inline `"artifacts": [{"path": ..., "type": "summary", "summary":
  ...}]`, a dedicated "`artifacts` linking rationale" paragraph, an explicit
  `continuation_path` population rule, and a "Never write the nested `continuation_context`
  object" instruction.
- `lint-agent-contracts.sh` Check F is whole-file (`has_artifacts_object_shape` at lines
  ~379-400 greps the entire file), so it passes on the broken file today. Confirmed.

**One material divergence from the research, established by measurement during planning.** The
report's recommendation 3 proposes reusing `has_artifacts_object_shape`'s detection logic inside
the bounded handoff section. A prototype scan of all 45 writer sections shows that predicate
would FAIL 44 of 45 files, because `has_artifacts_object_shape` greps for the quoted JSON key
`"artifacts"` and the dominant writer pattern states the requirement in **prose** instead
(`` `artifacts[]` entries MUST use that schema's `{type, path, summary}` object shape, never a
bare path string ``). Only `cslib-implementation-hard-agent.md` carries a literal JSON
`artifacts` block inside its handoff section. The check therefore accepts **either** accepted
form — prose shape-triple or quoted-JSON object keys — which yields the clean, decisive baseline
below.

**Measured baseline for the new check (re-confirm, do not re-derive).** Scanning each writer's
bounded handoff-writing section for any `artifacts` mention plus the `{type, path, summary}`
shape triple: **44 of 45 writers PASS; `lean-implementation-hard-agent.md` is the sole
outlier** (0 mentions), exactly matching the measured incident. This is what makes the check
worth adding: it fails precisely the known-broken file today and nothing else, and reaches
45/45 after Phase 1.

The research also understated the writer population: there are ~45 handoff writers across all
extensions, not seven, and three of them (`books-implementation-hard-agent.md`,
`cslib-implementation-hard-agent.md`, `lean-implementation-hard-agent.md`) introduce the write
under a `Stage N: Wrap-Up` heading rather than the `` ### `.orchestrator-handoff.json`
(orchestrator-mode dispatches) `` heading the other 42 use. Both heading forms must be
recognized, and the `` — research agents never write one `` heading form must be excluded.
`books-implementation-hard-agent.md` does state the requirement, in a third phrasing
(`` `artifacts[]` entries use `{type, path, summary}` objects, never bare path strings ``), so
the detection predicate must not be an exact-sentence match on the dominant phrasing.

### The `partial`-status conditional (the task's "ALSO DECIDE")

No new rule is invented. The conditional is already decided and consistently encoded in three
places that agree, and the research verified all three:
`context/schemas/orchestrator-handoff-schema.json`, `scripts/validate-handoff.sh` (Check 2c's
`case "$status" in researched|planned|implemented)` branch), and `context/contracts/wrap-up.md`
lines 67-69. The settled rule: **`artifacts` is always a required array; non-empty is required
only when `status` is `researched`/`planned`/`implemented`; `[]` is legal and expected for
`partial`/`blocked`/`failed`.**

This task's job is to make that rule *readable by the agent before it writes*, which means
stating it inline in the contract being repaired (Phase 1) and re-confirming the three-way
agreement as evidence (Phase 1, Task 3) — not adding a fourth statement of it somewhere new.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Make `lean-implementation-hard-agent.md`'s Stage 5 state the `artifacts` requirement, its
  object shape, and the `partial`-status conditional, before the agent writes the handoff.
- Correct the now-stale "two known, named, unlanded gaps" claim in the architecture doc's
  Handoff Writers table.
- Add a section-scoped lint check that catches this regression class mechanically, and
  demonstrate it on a real lint run (baseline FAIL on the broken file, PASS after the fix).
- Record this task's `file_scope`, which was deliberately left absent at creation time.

**Non-Goals**:
- Editing `orchestrate-build-dispatch.sh` or the dispatch file's `## Handoff` section (route (a),
  rejected: it would inject handoff-write instructions into every research dispatch, which never
  writes the file).
- Creating any new prose document, shared template file, or second source of truth (routes (c)
  and (d), rejected; also the task's explicit failure condition).
- Restating or re-deciding the `partial`-status conditional as a new rule.
- Widening the shared 44-file boilerplate to also carry the non-empty conditional. The
  conditional is reachable today via `wrap-up.md`, which every writer already points at; a
  44-file mechanical edit is a separate, larger change with its own blast radius and is not
  required by this task's acceptance bar.
- Widening `stall_suspected`'s trigger (recorded prior ruling; no new evidence here bears on it).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Ordering edge against Task 359: both tasks edit `lint-agent-contracts.sh`; 359's `file_scope` also claims `test-lint-agent-contracts.sh` | M | M | No hard dependency declared — see the dedicated subsection below for the reasoning. Phase 3 puts its tests in a **new** file (`test-lint-agent-contracts-handoff-section.sh`, mirroring the existing `test-lint-agent-contracts-heartbeat.sh` precedent), removing the test-file overlap entirely; the remaining shared file is edited as a pure append (one new function + one line in `main()`), re-read immediately before editing per the territory contract |
| A heading-anchored check is brittle if a future writer phrases its handoff section differently | M | M | Anchor on two alternative literal heading forms already in use, and FAIL loudly (never silently skip) when a listed writer has no recognizable handoff section at all — so a drifted heading surfaces as a failure rather than a silent pass |
| An exact-sentence detection pattern would miss the two minority phrasings already in the tree | H | H (measured) | Detect the shape triple `{type, path, summary}` OR quoted JSON `"type"`/`"path"`/`"summary"` keys within the bounded section, never an exact-sentence match. Verified against all three live phrasings during planning |
| Research-agent sections are structurally similar and would false-FAIL | M | M | Exclude any section whose heading carries `never write one`; verified to cleanly separate all writers from all non-writers in the planning prototype |
| Concurrent sibling dispatches (299, 319) are live on this same working tree this cycle | M | M | 299's `file_scope` includes `orchestrate-build-dispatch.sh` and `planner-agent.md`, neither of which this task edits; 319's two files are disjoint. Re-read every file immediately before editing, stage only this task's own hunks with an explicit file list, never `git-snapshot.sh` in reverting mode |
| `.claude/**` edited instead of the source store, silently wiped on next deploy | H | L | Every edit target below is under `agent-system/extensions/**`; Phase 4 redeploys via `deploy-headless.sh` and verifies the deployed tree reflects the source |

### Ordering edge against Task 359

The task description instructs: add an ordering edge against 359 **only if** research picks route
(b). Research did pick route (b), so the condition is met and the overlap is real — 359's
`file_scope` in `specs/state.json` names both `lint-agent-contracts.sh` and
`test-lint-agent-contracts.sh`.

A hard `--depends-on-add` edge is nonetheless **not** declared, for a stated reason rather than
by omission: 359 is `not_started` with no declared dependencies of its own and no scheduled
dispatch, so a blocking edge would stall this task's *entire* scope — including Phases 1 and 2,
which fix a measured, recurring production defect and touch none of 359's files — behind
unrelated work. The research report's own mitigation anticipates exactly this and recommends
sequencing the lint work as a later phase rather than blocking the whole task.

What is done instead, mechanically rather than by assertion: the test-file overlap is removed
outright (new test file), the one remaining shared file is touched by pure append, and the
overlap is declared in `file_scope` so the batch admission gate's overlap detection can see this
record — closing the "known blindness" the task description names. **This is a deliberate
deviation from the description's literal instruction and is flagged as such for the operator;**
if a blocking edge is preferred, declare it with
`update-task-status.sh ... --depends-on-add='[359]'` and Phases 1-2 can still land first.

### File scope (set at plan time, as the description requires)

Proposed via `proposed_file_scope` in `.return-meta.json`, which the plan postflight forwards to
`update-task-status.sh --file-scope-add`:

- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`

**Interpretation note on the `core/**` line in the description.** The description's "SOURCE STORE
IS THE EDIT TARGET: agent-system/extensions/core/**" is read as the research report reads it:
generic meta-task boilerplate naming the source store, whose binding constraint is *source store,
never a deployed `.claude/**` tree*. The same description separately anticipates "the agent
definitions" as a route-(b) touch point without scoping them to core, and the measured defect
lives in `extensions/lean/`. Editing under `agent-system/extensions/lean/` satisfies the binding
constraint. Flagged rather than assumed silently.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Repair the lean hard agent's handoff contract [NOT STARTED]

**Goal**: `lean-implementation-hard-agent.md`'s Stage 5 states the `artifacts` requirement, its
object shape, and the `partial`-status conditional, so the dispatched agent reads the requirement
before it writes the handoff. This is the measured defect.

**Tasks**:
- [ ] Re-read `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` lines
      ~343-366 (the already-fixed reference) and
      `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` lines ~291-394
      immediately before editing
- [ ] Add `"artifacts": [{"path": "...", "type": "summary", "summary": "..."}]` to the Stage 5
      JSON example, mirroring cslib's placement
- [ ] Add an "`artifacts` linking rationale" paragraph adapted from cslib's: `artifacts` is what
      the orchestrator's artifact-linking step consumes; it is an array of objects with `path`,
      `type`, `summary` keys, never bare path strings; an absent or empty array on an
      `implemented` handoff silently prevents linking
- [ ] State the `partial`-status conditional explicitly in that paragraph: `artifacts` is always a
      required array; non-empty required when `status` is `researched`/`planned`/`implemented`;
      `[]` legal for `partial`/`blocked`/`failed` — citing `context/contracts/wrap-up.md` as the
      canonical source rather than restating it as a new rule
- [ ] Remove `"continuation_context": null` from the JSON example and add cslib's
      `continuation_path` population rule plus its "Never write the nested `continuation_context`
      object" instruction
- [ ] Re-confirm (read only, no edit) the three-way agreement on the conditional across
      `context/schemas/orchestrator-handoff-schema.json`, `scripts/validate-handoff.sh`, and
      `context/contracts/wrap-up.md` lines 67-69; record the confirmation in the phase notes
- [ ] Confirm no task-number reference was introduced (the file lands under `agent-system/**`)

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts-heartbeat.sh` plus `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` covers it — a single agent-definition markdown file with no executable surface and no cross-file contract consumer.

**Scope Hypothesis**: this file is asserted to be the **sole** writer of 45 whose handoff section omits the requirement (measured during planning). Confirm by re-running the section-scoped scan before editing — if a second outlier now exists, fix it in this same phase and record the count change rather than silently planning around one file.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` - Stage 5 JSON example
  gains `artifacts`, loses `continuation_context: null`; gains the linking-rationale and
  conditional paragraphs and the `continuation_path` population rule

**Verification**:
- The bounded Stage 5 section contains a non-zero count of `artifacts` mentions and the
  `{type, path, summary}` shape triple
- `grep -c 'continuation_context' ` on the file shows only the deprecation instruction, no
  `"continuation_context": null` JSON line
- The section-scoped scan now reports 45/45 writers stating the requirement
- `run-all.sh --only test-lint-agent-contracts-heartbeat.sh` green; `verify-deploy.sh
  --only-gate 3,4` green

---

### Phase 2: Correct the stale Handoff Writers claim [NOT STARTED]

**Goal**: the architecture doc's Writers table no longer asserts gaps that are closed, so the next
reader is not sent after a defect that no longer exists.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/docs/architecture/handoff-schema.md` around line 491
      (the Writers table's Notes cell) immediately before editing
- [ ] Remove the cslib half of the "Two known, named, unlanded gaps" sentence: both of its claims
      are stale (cslib now carries the `artifacts`-shape spec and the `continuation_path`
      population rule, and no longer writes `continuation_context`)
- [ ] Remove the lean half, closed by Phase 1
- [ ] Rewrite the cell to state the current design only — no "formerly", "no longer", or
      supersession framing (`rules/no-record-versioning-in-deliverables.md`); keep the pointer to
      `context/contracts/wrap-up.md`'s canonical schema
- [ ] Confirm the surrounding "out of this document's declared scope" caveat still reads correctly
      once the gap sentence is gone

**Timing**: 0.4 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and task-reference lint) is the honest covering check — `suite_selection_select` returns `__FULL_SWEEP__` for this path, so no suite covers it, and the edit is confined to one markdown table cell with zero executable surface.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Writers table Notes cell:
  the stale two-gap sentence removed, current state stated

**Verification**:
- Diff read-through confirms every changed hunk lies inside the one table cell
- The file no longer asserts that cslib "lacks the `artifacts`-shape spec" or that lean "omits
  `artifacts` entirely"
- No record-versioning language introduced in the rewritten cell
- `verify-deploy.sh --only-gate 3,4` green

---

### Phase 3: Add the section-scoped handoff-artifacts lint check [NOT STARTED]

**Goal**: this regression class is caught mechanically. A new Check J bounds its scan to each
writer's handoff-writing section, so it can distinguish a correct `.return-meta.json` section
from a correct `.orchestrator-handoff.json` section — which whole-file Check F structurally
cannot.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` immediately
      before editing (Task 359 claims this file in its `file_scope`; a sibling may have landed)
- [ ] Add `check_j_handoff_section_artifacts()` as a pure append near the existing checks, and
      register it with one added line in `main()` after `check_i_heartbeat_mechanization_adoption`
      (next free letter is J; existing checks are A, B, C, F, E, G, H, I)
- [ ] Implement section bounding: locate the first heading matching either
      `` `.orchestrator-handoff.json` (orchestrator-mode `` or `Wrap-Up`, excluding any heading
      containing `never write one`; end the section at the next heading of same-or-higher level
- [ ] Implement the detection predicate: within the bounded section, require an `artifacts`
      mention AND the shape evidence — the prose triple `{type, path, summary}` OR quoted JSON
      `"type"`/`"path"`/`"summary"` keys. Do not reuse `has_artifacts_object_shape` unmodified:
      it requires the quoted `"artifacts"` key and would fail 44 of 45 writers
- [ ] FAIL loudly when a file that mentions `.orchestrator-handoff.json` and is not a
      `never write one` non-writer has no recognizable handoff section at all
- [ ] Add a brief comment block explaining why Check J exists alongside Check F (whole-file vs.
      section-scoped), and why the predicate accepts two statement forms
- [ ] Write `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`,
      structured on the existing `test-lint-agent-contracts-heartbeat.sh`: fixtures for a
      prose-form writer (PASS), a JSON-form writer (PASS), a writer whose section omits
      `artifacts` (FAIL), a writer with a correct `.return-meta.json` section but a broken
      handoff section (FAIL — the exact Check F blind spot), a `never write one` research agent
      (skipped, not failed), and a writer with an unrecognizable heading (FAIL loudly)
- [ ] Run the full lint and confirm Check J reports 45/45 PASS with Phase 1 landed

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts-handoff-section.sh,test-run-all-selection.sh,test-askuserquestion-rehome.sh,test-verify-deploy-context-budget.sh` is the covering set `suite_selection_select` resolves for this file, and the change is an append-only new function with no edit to any existing check's behavior.

**Scope Hypothesis**: the new check is asserted to pass 45/45 writers after Phase 1 and to require no per-agent exclusion list beyond the `never write one` heading rule. Confirm by running the full lint before declaring the phase green — if any writer needs a recorded exclusion, add it with a read-and-verified justification comment in the style of Check F's `EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS` block, never inferred from absence alone.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` - new
  `check_j_handoff_section_artifacts()` plus one registration line in `main()`
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh` - new
  test file covering the six fixture cases above

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` exits 0 with Check J
  reporting PASS for every writer and no new failures in Checks A-I
- Reverting Phase 1's edit in a scratch copy makes Check J FAIL on
  `lean-implementation-hard-agent.md` specifically — the demonstration the task's acceptance bar
  asks for (a real lint run, not an assertion that prose exists)
- The new test file passes standalone and is discovered by `run-all.sh` without manual
  registration
- `run-all.sh --only <the six suites above>` green

---

### Phase 4: Redeploy, declare scope, and run the full gate [NOT STARTED]

**Goal**: the source-store edits reach the deployed tree, the task's `file_scope` is recorded, and
the complete gate set is observed green.

**Tasks**:
- [ ] Re-read `git status --short` and confirm only this task's files are modified; investigate
      and report any foreign modification rather than proceeding
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's
      documented invocation) to regenerate the deployed `.claude/**` tree
- [ ] Verify the deployed `.claude/agents/lean-implementation-hard-agent.md` and
      `.claude/scripts/lint/lint-agent-contracts.sh` reflect the source-store edits
- [ ] Run `bash .claude/scripts/verify-deploy.sh` (complete gate set, no `--only-gate`, no
      `--skip-slow`)
- [ ] Confirm `file_scope` was recorded on this task (proposed at plan time via
      `proposed_file_scope`); if the postflight forward did not apply, record it explicitly
- [ ] Capture the acceptance evidence in the summary: the composed lint run showing Check J
      green, and the scratch-revert run showing it FAIL on the previously broken file
- [ ] Record the `partial`-status conditional's final resting place (lean Stage 5 inline, plus the
      three-way agreement confirmed in Phase 1) as the explicit answer to the task's
      "ALSO DECIDE" item

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: full

**Files to modify**:
- None directly; this phase regenerates the deployed tree and runs gates

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 across the complete gate set, with no
  `--only-gate` narrowing and no `--skip-slow`
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` green
- Deployed tree confirmed to carry both source-store edits
- Acceptance evidence captured: a real lint run demonstrating the mechanism, with the
  `partial`-status conditional stated explicitly in the repaired contract

---

## Testing & Validation

- [ ] Check J passes for all 45 handoff writers and skips (does not fail) every
      `never write one` research agent
- [ ] Check J fails on `lean-implementation-hard-agent.md` when Phase 1's edit is reverted in a
      scratch copy — the regression it exists to catch
- [ ] Check J fails on a fixture with a correct `.return-meta.json` section and a broken handoff
      section (the Check F blind spot)
- [ ] Checks A-I show no new failures
- [ ] `verify-deploy.sh` green across the complete gate set
- [ ] `run-all.sh` green, including the new test file
- [ ] No task-number references in any file landing under `agent-system/**`
- [ ] No record-versioning language in the rewritten doc cell

## Artifacts & Outputs

- Repaired `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` Stage 5
- Corrected Writers-table cell in `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- New `check_j_handoff_section_artifacts()` in
  `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh`
- New `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-handoff-section.sh`
- Regenerated deployed `.claude/**` tree
- Implementation summary recording the lint-run acceptance evidence and the `partial`-conditional
  verdict

## Rollback/Contingency

All four edits are small, additive, and independently revertible. If Check J proves too brittle
across the three live phrasings, revert Phase 3 alone (`git revert` the lint commit) and keep
Phases 1-2: the measured defect is fixed by Phase 1, and the task's acceptance bar is still met
by the recorded verdict plus the repaired contract. Before any intentional rollback that would
discard uncommitted work, run `bash .claude/scripts/git-snapshot.sh 370` first; for an ordinary
defensive checkpoint mid-phase use `bash .claude/scripts/git-snapshot.sh 370 --no-revert`.
Because sibling dispatches are live on this tree, stage only this task's own files with an
explicit file list and never use a directory or glob pathspec.
