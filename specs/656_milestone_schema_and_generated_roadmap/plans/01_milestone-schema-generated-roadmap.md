# Implementation Plan: Task #656

- **Task**: 656 - Milestone schema in state.json and a wholly generated ROADMAP.md
- **Status**: [IMPLEMENTING]
- **Effort**: 16 hours
- **Dependencies**: 654 (completed). Downstream: 657 builds on this schema; 655 follows 657.
- **Research Inputs**: specs/656_milestone_schema_and_generated_roadmap/reports/01_milestone-schema-generated-roadmap.md
- **Artifacts**: plans/01_milestone-schema-generated-roadmap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/ROADMAP.md` today renders two of its eight sections from `specs/state.json`; the other six are
hand-authored and round-tripped verbatim, and the unbounded prose fields (`rationale`,
`roadmap_notes`) make up roughly 70% of the file. This plan adds a milestone layer to the state
schema (`primary_goals`, ordered `roadmap_milestones[]` with nested batches, `roadmap_context`),
rewrites `roadmap-integration.sh` to render the whole file from state in a fixed three-part order,
migrates flat stores with a hard losslessness gate, retargets the advisory batch lint at the state
entries, and updates every caller and document that describes the old layout. Done when the file
renders entirely from state, each milestone section shows progress and review state, the pruning
ledger and the lint disposition are recorded in the source store, the migration's accounting gate
passes on this repository, the five named suites pass, and the sf1-engine acceptance render has
been produced and judged.

All edits land in the source store `agent-system/extensions/core/**` (resolved from
`.claude-extensions.json`'s `extensions.core.source_dir`, confirmed at planning time), never under
`.claude/**`. No file under `agent-system/**` may carry a task number or draft-history language.

### Research Integration

The research report's nine recommendations are adopted with two overrides (see Decisions 1 and 8).
Key findings carried into the phases:

- Key names `primary_goals`, `roadmap_milestones`, `roadmap_context`; the nested batch reuses
  `definitions.roadmapBatchEntry` unchanged.
- Progress counts are derived at render time; only `progress.status`, the closure date and the
  review state are stored. Completed members stay in their batch while a milestone is open.
- Review state is a stored field, never fetched in the render path (a network call would break the
  byte-identical second regenerate that `skill-roadmap` Stage 3 asserts).
- `rationale` stays in state and is not rendered; `roadmap_notes` is retired by the migration.
- A generated sentinel on line 1 replaces header-vocabulary layout classification.
- Lint disposition: retarget at state; call site stays `scripts/orchestrate-conclusion-roadmap.sh`.

Premise re-validation (the four description lines the dispatch flagged), checked at planning time:

- Source store is the edit target: confirmed, `source_dir` resolves to
  `/home/benjamin/.config/nvim/agent-system/extensions/core`.
- Only `## Next` and `## Open work` render from state: confirmed against the report's reading of
  `roadmap-integration.sh` and against the live file, which carries all eight classic headers.
- The judgment/rendering split: confirmed unchanged from the report; no phase below gives the
  renderer a decision or the agent a file write.
- The five named test files exist at the stated paths (717 to 2,097 lines each).

Carried figures: re-derived at planning time - 49 "milestone" lines in 22 files; four non-test
scripts read the flat batch keys; one executable caller of the lint; this store holds 30 flat
batches and `roadmap_notes` arrays of 5 / 12 / 0 paragraphs; `roadmap_milestones` and
`primary_goals` are absent. CARRIED-UNVERIFIED from the report (not re-measured here): the byte
sizes of both ROADMAP.md files, the 127-line prototype render, 316 of 326 lint findings being
finding (a), 7 of 20 settled decisions exceeding a 300-character bound, and the six Check 13
terminal-member warnings.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set. This task's own
state annotation ("rule where the generated review surface then lives") is answered by Decision 6.

## Goals & Non-Goals

**Goals**:
- Schema and validator gain the milestone layer in one commit, with bounded prose fields.
- `roadmap-integration.sh --regenerate` renders the whole file from state: intro with primary goals
  and a milestone status table, one dashboard section per milestone in array order, then rules,
  conventions and repo context last.
- A one-time migration from the flat shape with a hard losslessness accounting gate.
- One recorded disposition for `scripts/lint/lint-roadmap-batch-proposals.sh` (retarget), with its
  call site named.
- A recorded per-section pruning ledger in `context/formats/roadmap-format.md`.
- The five named suites, plus the two unnamed suites the change reaches, updated and passing.
- This repository migrated and regenerated; sf1-engine acceptance render produced and judged.

**Non-Goals**:
- Any writer for `review` beyond roadmap-agent's ordinary `state-write.sh` path; push and review
  automation belong to task 657.
- Dividing this repository's work into real milestones. The migration wraps existing batches in
  one neutral milestone; the division is roadmap-agent judgment on a later `/roadmap` run.
- Changing `generate-task-order.sh` or replacing `active_goal`.
- A mechanical fix for batch `task_ids` across vault renumbering.
- Writing to the live sf1-engine store (see Decision 9).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Unmigrated consumer stores meet a renderer that refuses their classic file | M | H | The refusal names the migration command; `--next-batch` keeps working through the accessor's flat-shape fallback; the conclusion step's existing loud-degrade arm covers "cannot regenerate here" |
| Renderer flip leaves a pinned suite red between phases | H | M | Phase 4 adds the milestone render path beside the existing one; the old paths are deleted only in Phase 6, together with every suite and caller that pins them |
| Source-store scripts refuse to run outside a deployed tree (report's claim about `deploy-root-guard.sh`, CARRIED-UNVERIFIED) | M | M | Each phase names the source-store `verify-touched.sh` form; if it refuses, redeploy with `timeout 540 bash .claude/scripts/deploy-headless.sh` and use the `.claude/scripts/` form, recording the switch in the issue log |
| Seven of this store's settled decisions exceed the `conventions` bound | L | H | The migration never truncates: over-bound items go whole to the retained-prose file with a WARN each; the migration is still lossless and the render is still complete |
| Stored `review.state` goes stale | L | M | `updated` is rendered beside it; freshness is 657's concern |
| Keeping completed members widens the existing vault-renumbering exposure | L | L | roadmap-agent is instructed to drop done members when closing a milestone; the residual is recorded in `context/reference/state-management-schema.md` |
| Concurrent sessions are writing `specs/state.json` during the Phase 9 migration | M | M | The migration writes only through `state-write.sh`; run its `--dry-run` accounting first and re-run it immediately before the real write |
| The acceptance judgment is subjective | L | H | Judge against the report's concrete before/after: a status table in the first screen and a file a fraction of the live one |

## Decisions

1. **The flat keys stay in the schema as the unmigrated-store shape.** The report recommends
   removing `roadmap_batches` and `roadmap_notes` from the schema in the first phase. They are kept
   instead, because the accessor's fallback (Phase 2) is a live reader of the flat shape, and
   because this repository's own store would otherwise carry an unknown top-level field from
   Phase 1 until Phase 9. Check 13 emits a named WARN pointing at the migration script whenever a
   flat key is present. The migration deletes both keys from a store.
2. **Key naming**: `primary_goals`, `roadmap_milestones`, `roadmap_context`. The unqualified word
   "milestone" keeps its one existing meaning, the events-log `category` value; no event category
   is added.
3. **Derived counts, stored decisions.** `progress` stores `status`, `closed`, `note`; batch and
   task done-counts are computed by the renderer.
4. **Check 13 keeps its number and WARN-only posture.** Its terminal-member sub-condition narrows
   to abandoned or expanded members and to members of closed milestones.
5. **`active_goal` is kept.** The renderer falls back to it when `primary_goals` is absent.
6. **Output location: optional `roadmap_context.output_path`.** The report surfaced this as a
   non-blocking user decision and recommended this default; the plan proceeds on it. The renderer
   honours the stored repository-relative path when `--roadmap` is not given; the default stays
   `specs/ROADMAP.md`. If the user rules the other way, the cost is removing one optional field
   and its accessor.
7. **Lint disposition: retarget, call site unchanged** (Phase 3 implements, Phase 8 records).
8. **Additive render before the flip.** The report suggests treating renderer, migration and lint
   as one atomic batch. They are ordered instead: lint retarget first (it stops needing the file),
   then an additive milestone render path, then the migration, then deletion of the old paths.
   Every phase boundary is green and no phase needs `atomic-batch` across more than one suite.
9. **sf1-engine acceptance runs on a copy.** The implementer reads sf1-engine's state and
   `integration/design.md` section 7, builds a migrated copy under this task's `records/`
   directory, and renders from it. Writing another repository's live store is outside this task's
   territory and is put to the user as a non-blocking decision in the return metadata.
10. **Numbered settled-decision anchors move to an in-extension file.** The comments citing
    "Settled decision 13" and "15" are re-anchored to
    `context/standards/shell-script-testing.md`, which deploys with the extension, rather than to a
    numbered list that the generated file will not carry.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 1, 4 |
| 5 | 6 | 3, 4, 5 |
| 6 | 7, 8 | 6 |
| 7 | 9 | 7, 8 |

Phases within the same wave can execute in parallel.

### Phase 1: Schema and Validator Milestone Layer [COMPLETED]

**Goal**: The schema defines the milestone layer and `validate-state.sh` checks it, moved together
in one commit.

**Tasks**:
- [x] In `state-schema.json` add top-level `primary_goals` (array of strings, `maxLength` 500),
  `roadmap_milestones` (array of `#/definitions/roadmapMilestoneEntry`) and `roadmap_context`
  (object, `additionalProperties: false`: `overview`, `rules`, `conventions` as arrays of strings
  with `maxLength` 300, plus optional string `output_path`). *(completed)*
- [x] Add `definitions.roadmapMilestoneEntry` per the report's Recommendation 1: required `id`
  (pattern `^[A-Za-z0-9][A-Za-z0-9._-]{0,15}$`), `title` (80), `aim` (300), `progress`, `batches`;
  optional `gate` (400) and `review`. `progress` = `{status: planned|active|closed, closed?,
  note? (140)}`; `review` = `{state: none|prepared|in_review|changes_requested|approved|merged,
  ref?, request?, updated?}`; `batches` items `$ref` the existing `roadmapBatchEntry` unchanged. *(completed)*
- [x] Add `maxLength: 140` to the per-task `roadmap_annotation`. *(completed)*
- [x] Keep `roadmap_batches` and `roadmap_notes` defined; reword their descriptions to say they are
  the shape of a store that has not run the milestone migration (state the current design only). *(completed)*
- [x] In `validate-state.sh` add the three keys to `KNOWN_TOP_LEVEL_FIELDS` and extend Check 13 in
  place: iterate `roadmap_milestones[].batches[]` with a `roadmap_milestones[i].batches[j]` path
  prefix; no task id in two batches across all milestones; milestone `id` unique; `title` and `aim`
  non-empty and within bounds; `progress.status == "closed"` if and only if `progress.closed` is
  present; a member that is abandoned or expanded, or any terminal member of a closed milestone,
  WARNs; a member resolvable in neither `active_projects` nor `specs/archive/state.json` WARNs; a
  completed member of an open milestone does not; a named WARN when a flat key is present, naming
  `scripts/migrate-roadmap-to-milestones.sh`. Keep the existing flat-array checks for a store that
  still carries the flat shape. *(completed)*
- [x] In `test-validate-state.sh` keep the existing flat-shape Check 13 fixtures, add nested-shape
  fixtures for each new sub-condition (one firing and one clean case each), extend the field-drift
  fixture, and confirm the existing schema/validator drift test passes in both directions. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: The report places the existing Check 13 fixtures at lines 507-652 of
`test-validate-state.sh` and the drift test near line 1694 (CARRIED-UNVERIFIED from the report);
confirm by `grep -n 'Check 13\|KNOWN_TOP_LEVEL_FIELDS'` before editing. The bounds are hypotheses
against live text: before committing, run `jq` length checks for `roadmap_annotation` over this
store and confirm zero entries exceed 140.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's three paths covers the schema's dependents, the selector returning test-assess-repo-health.sh, test-deploy-baseline-lib.sh, test-init-specs.sh, test-migrate-roadmap-next-to-state.sh, test-orchestrate-suggest-next-batch.sh, test-roadmap-command-registration.sh, test-status-vocabulary.sh, test-update-task-status.sh and test-validate-state.sh.

**Files to modify**:
- `agent-system/extensions/core/context/schemas/state-schema.json` - three top-level keys, one definition, one bound
- `agent-system/extensions/core/scripts/validate-state.sh` - known-field set and Check 13
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - nested fixtures and drift fixture

**Verification**:
- `jq empty` on the schema exits 0.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the three paths above exits 0
  and its verdict names the nine suites.
- Running the validator on this repository's live store reports the named flat-key WARN and no new
  error.

---

### Phase 2: Roadmap Entries Accessor and Next-Batch Reader [COMPLETED]

**Goal**: One sourced accessor answers "the ordered batch list" and "the output path" for every
consumer, and `--next-batch` reads through it.

**Tasks**:
- [x] Create `scripts/lib/roadmap-entries-lib.sh` (sourced, sets no shell options, never exits):
  a function emitting batches of non-closed milestones in milestone-then-batch order, each tagged
  with its milestone `id` and batch ordinal, falling back to `.roadmap_batches // []` when
  `roadmap_milestones` is absent; a function emitting the resolved output path
  (`roadmap_context.output_path`, else `specs/ROADMAP.md`). *(completed)*
- [x] Create `scripts/tests/test-roadmap-entries-lib.sh`: nested order, closed milestone skipped,
  flat fallback, both shapes present (nested wins), empty store, output-path default and override. *(completed)*
- [x] Change `orchestrate-suggest-next-batch.sh`'s `read_roadmap_batches()` to read through the
  accessor; behaviour on a flat store is unchanged. *(completed)*
- [x] In `test-orchestrate-suggest-next-batch.sh` keep one flat-shape fixture as the fallback case,
  convert the rest to the nested shape, and add a closed-milestone-is-skipped case. *(completed)*
- [x] Register the new lib and suite in `manifest.json` and `suite-classification.data` (class
  `unit`). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: The report counts 19 `roadmap_batches` references in
`test-orchestrate-suggest-next-batch.sh` (CARRIED-UNVERIFIED); confirm with `grep -c` and convert
every fixture except the one kept as the fallback case. Whether a sourced lib needs its own
`manifest.json` row is a hypothesis; confirm against how `scripts/lib/roadmap-preflight-lib.sh` is
registered and follow that.

**Tier Justification**: `manifest.json` is the extension's global registration surface, read by the deploy, install and inventory machinery across the battery, so no enumerated-dependent set covers an edit to it.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/roadmap-entries-lib.sh` - new accessor
- `agent-system/extensions/core/scripts/tests/test-roadmap-entries-lib.sh` - new suite
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` - reader goes through the accessor
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` - nested fixtures, fallback case
- `agent-system/extensions/core/manifest.json` - lib and suite rows
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - suite row

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the six paths above exits 0;
  under `/orchestrate` the complete gate set is deferred to the orchestration close.
- The new suite and `test-orchestrate-suggest-next-batch.sh` both appear green in that run.

---

### Phase 3: Retarget the Advisory Batch Lint at State [COMPLETED]

**Goal**: The lint reads `roadmap_milestones[].batches[]` through the accessor and no longer parses
the rendered file.

**Tasks**:
- [x] In `lint-roadmap-batch-proposals.sh` remove the parse layer (`RUN_LINE_RE`, the `## Next`
  section scan, the fence walker, the `detect_layout` sniff, the `--roadmap` flag) and read batches
  through `roadmap-entries-lib.sh`. *(completed)*
- [x] Keep finding (a) (file_scope overlap with an out-of-batch task) and finding (c) (more than
  `MAX_TASKS` members). Remove finding (d); Check 13 owns terminal members. Narrow finding (f)
  from the whole file to the bounded string fields of the roadmap entries. *(completed)*
- [x] Location labels become `[milestone ID batch N]`. Keep the advisory contract: exit 0 with
  findings, no proposer behaviour. Rewrite the header comment to describe the state input. *(completed)*
- [x] In `orchestrate-conclusion-roadmap.sh` drop the `--roadmap` argument from the `LINT_SCRIPT`
  invocation and also run the lint on the degrade arm, since it no longer needs the file. Do not
  change the arm's verdict condition here; Phase 6 owns that. *(completed)*
- [x] Rewrite `test-lint-roadmap-batch-proposals.sh` fixtures to state entries, covering each kept
  finding, a clean store, the flat fallback, and absence of the removed finding (d). *(completed)*
- [x] Update `test-orchestrate-conclusion-roadmap.sh` only where it pins the lint's invocation or
  label text. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: The lint's only executable caller is `orchestrate-conclusion-roadmap.sh`
(re-derived at planning time with `grep -rIn 'lint-roadmap-batch-proposals' --include=*.sh`);
re-run that grep before removing `--roadmap` and stop if a second caller has appeared.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's four paths covers the lint and its one caller, the selector returning test-lint-roadmap-batch-proposals.sh, test-orchestrate-conclusion-roadmap.sh and test-orchestrate-recap.sh.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` - state input, findings (a), (c), narrowed (f)
- `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` - state fixtures
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` - lint invocation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - lint expectations

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the four paths above exits 0
  and its verdict names the three suites.
- `grep -c 'RUN_LINE_RE\|detect_layout' agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh`
  prints 0.

---

### Phase 4: Generated Sentinel and Milestone Render Path [COMPLETED]

**Goal**: A store that carries `roadmap_milestones` renders the whole file in the three-part
layout, while a classic or stage store keeps its current behaviour until Phase 6.

**Tasks**:
- [x] In `roadmap-preflight-lib.sh` define the sentinel constant (a fixed HTML comment naming the
  generator and "do not edit") and add a `generated` verdict to `detect_layout`, tested first, when
  the file's first line is the sentinel. Existing verdicts are unchanged. *(completed)*
- [x] In `roadmap-integration.sh` add the whole-file render, selected when `roadmap_milestones` is
  present, in this order: sentinel; `# Roadmap`; `primary_goals` bullets (falling back to
  `active_goal`); a status table (Milestone, Status, Tasks done, Review) whose first column links
  to each milestone section; a link to the last section; one section per milestone in array order;
  the rules, conventions and repo-context section last. *(completed)*
- [x] Milestone section: heading `## {id}: {title}` with an explicit anchor derived from the stored
  `id`; `aim`; a Progress line (`status`, derived batch and task done-counts, `note`); a Review
  line (`state`, `ref`, `request`, `updated`); a Gate line; then per batch a description line, an
  `/orchestrate` line listing open members only, and one line per member reusing `status_token()`
  and `token_rank()` unchanged with the member's `roadmap_annotation`. *(completed)*
- [x] A member that is terminal in `active_projects` or present in the archive's completed list
  counts as done and is left off the `/orchestrate` line; a batch with no open member renders as
  done with no `/orchestrate` line; a closed milestone collapses to its heading plus one line. *(completed)*
- [x] Last section: `overview`, `rules`, `conventions`, then the list of open tasks in no batch. *(completed)*
- [x] Do not render `rationale`. Do not call `generate-task-order.sh --print` on this path. *(completed)*
- [x] Resolve the output path through the accessor when `--roadmap` is not given. `--regenerate`
  on this path writes when the target classifies `generated` or `absent`; any other verdict is
  left to the existing code. *(completed)*
- [x] Keep `--print`, `--dry-run`, the six-field stderr marker (`runs=` = open-milestone batch
  count, `retained=` = 0), the `OUTCOME:` line and the `no content change` wording. *(completed)*
- [x] Add a milestone group to `test-roadmap-generation.sh`: section order, anchors from `id`,
  derived counts with a completed member, a done batch, a collapsed closed milestone, the
  unscheduled list, `output_path` honoured, byte-identical second regenerate, the `generated`
  verdict. Keep the suite's live-tree isolation guard. *(completed)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The estimate is that this path adds without touching `render_next()`,
`render_open_work()` or `assemble_roadmap()`, so every existing case in
`test-roadmap-generation.sh` stays green unedited. Confirm by running the suite before adding the
new group; if an existing case fails, the path selection is leaking into the classic branch and
must be fixed rather than the case edited.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's three paths covers the renderer and its sourcers, the selector returning test-migrate-roadmap-next-to-state.sh, test-orchestrate-conclusion-roadmap.sh, test-roadmap-generation.sh, test-skill-base-lifecycle.sh and test-sweep-invalidated-claims.sh.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` - sentinel constant, `generated` verdict
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - whole-file milestone render path
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - milestone group

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the three paths above exits 0
  and its verdict names the five suites.
- A `--print` against a fixture with three milestones (one closed) shows the status table before
  the first milestone section and the rules section last.

---

### Phase 5: Migration to the Milestone Shape with a Losslessness Gate [NOT STARTED]

**Goal**: A one-time, mechanical migration from the flat shape that proves, before any write, that
nothing was lost.

**Tasks**:
- [ ] Create `scripts/migrate-roadmap-to-milestones.sh` with the precedent script's flag set
  (`--dry-run`, `--force`, `--roadmap`, `--state`, `--session-id`) plus `--retained PATH`
  (default a dated file under `specs/archive/`). It writes state only through `state-write.sh` and
  refuses when `roadmap_milestones` is already non-empty unless `--force`.
- [ ] State moves: every flat batch, in order and unchanged, into one milestone (`id` `M1`,
  `title` `Current work`, `progress.status` `active`, `review.state` `none`, a fixed neutral
  `aim`); `## Goal` paragraphs to `primary_goals`; `## Standing rules` items to
  `roadmap_context.rules`; `## Checks` and `## Settled decisions` items to
  `roadmap_context.conventions`. It invents no milestone boundary.
- [ ] An item over its bound is never truncated: it goes whole to the retained-prose file and one
  WARN names it.
- [ ] Retained-prose file: everything with no state field (`## Gate state`,
  `## Unfiled observations`, the preamble, all three `roadmap_notes` arrays, over-bound items,
  and for a stage-layout file every section but the run-order one) verbatim under its original
  header.
- [ ] Losslessness gate, hard and before any write: every non-blank line of the existing file
  outside generated regions, and every `roadmap_notes` string, is found trimmed in exactly one
  destination; batch accounting is structural (`jq -S` equality of the flat array against the
  flattened nested one for count, `task_ids`, `description`, `rationale`, `flags`). Any
  unaccounted line is named and the script exits non-zero with nothing written.
- [ ] After a passing gate: write state, delete `roadmap_batches` and `roadmap_notes`, write the
  retained-prose file, then write the generated file through the Phase 4 render path.
- [ ] A hand-authored `## Next` with empty `roadmap_batches` is detected and the script stops,
  naming `migrate-roadmap-next-to-state.sh` as the prerequisite.
- [ ] Create `scripts/tests/test-migrate-roadmap-to-milestones.sh`: classic happy path, over-bound
  item retained, gate failure on an injected unaccounted line (nothing written), idempotent
  refusal, `--force`, `--dry-run` writes nothing, stage layout, prerequisite detection.
- [ ] Register script and suite in `manifest.json` and `suite-classification.data`.
- [ ] Run `test-migrate-roadmap-next-to-state.sh` unmodified; edit it only if it fails, and then
  only its expectations, never its coverage.

**Timing**: 2 hours

**Depends on**: 1, 4

**Verification Tier**: full

**Scope Hypothesis**: The list-item splitter for `## Checks` and `## Standing rules` is untested
against this repository's hard-wrapped multi-line items (the report marks per-item lengths there
CORPUS-UNVERIFIED). Confirm with a `--dry-run` against a copy of this repository's file inside the
suite's scratch directory and record how many items land in state and how many are retained.

**Tier Justification**: `manifest.json` is the extension's global registration surface, read by the deploy, install and inventory machinery across the battery, so no enumerated-dependent set covers an edit to it.

**Files to modify**:
- `agent-system/extensions/core/scripts/migrate-roadmap-to-milestones.sh` - new migration
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-to-milestones.sh` - new suite
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-next-to-state.sh` - expectations only, and only if it fails
- `agent-system/extensions/core/manifest.json` - script and suite rows
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - suite row

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the five paths above exits 0;
  under `/orchestrate` the complete gate set is deferred to the orchestration close.
- The gate-failure case shows a non-zero exit and an unchanged state fixture (`cmp` against the
  pre-run copy).

---

### Phase 6: Remove the Hand-Authored Render Paths [NOT STARTED]

**Goal**: No hand-authored section survives a regenerate: the classic and stage round-trips are
deleted and every non-generated file is refused with the migration named.

**Tasks**:
- [ ] In `roadmap-integration.sh` delete `load_existing_sections`, `extract_section`,
  `extract_preamble`, `assemble_roadmap`, `split_sections`, `assemble_stage_roadmap`,
  `mode_regenerate_stage`, `render_next`'s preamble, rationale and postamble arms,
  `open_work_trailer_from_notes`, the coverage appendix and the `generate-task-order.sh --print`
  call. Keep the deprecated `--prune` alias.
- [ ] `--regenerate` overwrites only a `generated` file, or writes onto `absent` when
  `roadmap_milestones` is non-empty. On `classic`, `stage` or `unknown` it refuses and names
  `migrate-roadmap-to-milestones.sh`. The Destructive-Overwrite Refusal stays; its predicate is
  the sentinel.
- [ ] In `roadmap-preflight-lib.sh` make `roadmap_preflight_scaffold` write a sentinel-only
  generated file and remove the "authored by hand" stub text. Keep `CLASSIC_HEADERS` only as far
  as classifying an unmigrated file needs it.
- [ ] In `orchestrate-conclusion-roadmap.sh` change both `classic|stage` arms to `generated`,
  commit the accessor-resolved output path, and reword the degrade summary to name the migration.
- [ ] Rewrite `test-roadmap-generation.sh`: token derivation keeps its cases with new framing; the
  retention, layout-refusal, both stage-layout and scaffold groups are rewritten against the
  sentinel model; the batch-render group folds into the Phase 4 milestone group.
- [ ] Rewrite `test-orchestrate-conclusion-roadmap.sh` fixtures from the classic stale file to a
  generated stale file plus one refused-classic degrade case.
- [ ] Run `test-generate-task-order.sh` and `test-migrate-roadmap-next-to-state.sh`; neither
  should need an edit. If the second fails because the scaffold changed, adjust its expectations.

**Timing**: 2 hours

**Depends on**: 3, 4, 5

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: The six files below are the complete set pinning the classic and stage
paths among scripts and suites. Confirm before deleting with
`grep -rIl 'roadmap-preflight-lib\|detect_layout\|roadmap_preflight_' agent-system/extensions/core --include=*.sh`
(planning-time result: the lint, the conclusion script, the renderer, the lib and two suites), and
cross-check with a differently shaped search, `grep -rIl 'Gate state\|Unfiled observations' --include=*.sh`,
so the confirmation does not reuse the first search's own pattern.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's six paths covers the renderer, the lib and the conclusion caller, the selector returning test-migrate-roadmap-next-to-state.sh, test-orchestrate-conclusion-roadmap.sh, test-orchestrate-recap.sh, test-roadmap-generation.sh, test-skill-base-lifecycle.sh and test-sweep-invalidated-claims.sh.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - delete round-trip paths, sentinel refusal
- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` - generated scaffold
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` - `generated` arm, resolved commit path
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - rewritten groups
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - generated fixtures
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-next-to-state.sh` - expectations only, and only if it fails

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the six paths above exits 0
  and its verdict names the six suites.
- `grep -c 'extract_section\|assemble_stage_roadmap\|load_existing_sections' agent-system/extensions/core/scripts/roadmap-integration.sh`
  prints 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-generate-task-order.sh`
  exits 0 with that suite unedited.

---

### Phase 7: Agent, Skill and Command Text [NOT STARTED]

**Goal**: The judgment side and the four regenerate callers describe the milestone model and the
generated-only file, with the judgment/rendering split intact.

**Tasks**:
- [ ] `agents/roadmap-agent.md`: add milestone decisions to "Deciding Batches" (which milestones
  exist, order, `aim`, `gate`, which batches sit under which, `progress.status` transitions and
  closure); completed members stay while a milestone is open and are dropped when it closes; held
  tasks are admissible batch members; `rationale` is a working note and is not rendered; `review`
  is written only on explicit instruction, never inferred; remove the `roadmap_notes` paragraph;
  state the field bounds. The Write Contract is unchanged: entries through `state-write.sh`, edges
  through `update-task-status.sh`, never the file.
- [ ] `skills/skill-roadmap/SKILL.md`: Stage 1 verdicts become `generated` (proceed), `absent`
  (proceed when milestones exist), `classic|stage|unknown` (offer the migration with its dry-run
  accounting behind the existing single `AskUserQuestion`); Stage 4 commits the accessor-resolved
  output path.
- [ ] `commands/roadmap.md`: describe the three-part generated file.
- [ ] `commands/todo.md` Stage 6.6 and `commands/review.md` Section 6.8: replace the
  six-hand-filled-sections prose and the "hand-curated prose" statement with the generated model
  and the migration offer.
- [ ] `agents/planner-agent.md` roadmap-flag stage: the closing roadmap phase regenerates through
  `roadmap-integration.sh --regenerate` after state changes; remove the instruction to mark items
  with `- [x]` in the file.
- [ ] Sweep the six files for task numbers and draft-history phrasing before committing.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The report locates the planner's roadmap-flag text at lines 149-152 and the
"hand-curated prose" statement at `commands/review.md` line 242 (CARRIED-UNVERIFIED line numbers);
locate each by `grep -n 'hand-curated\|\[x\]\|Update ROADMAP' ` rather than by line.

**Tier Justification**: Agent, skill and command definition files are grep-pinned by doc-sync and wiring suites across the battery and reach the deployed context budget, a cross-cutting surface no enumerated-dependent set covers.

**Files to modify**:
- `agent-system/extensions/core/agents/roadmap-agent.md` - milestone decisions, bounds, no `roadmap_notes`
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` - verdict set, migration offer, commit path
- `agent-system/extensions/core/commands/roadmap.md` - generated layout
- `agent-system/extensions/core/commands/todo.md` - Stage 6.6 prose
- `agent-system/extensions/core/commands/review.md` - Section 6.8 prose
- `agent-system/extensions/core/agents/planner-agent.md` - roadmap-flag closing phase

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the six paths above exits 0;
  under `/orchestrate` the complete gate set is deferred to the orchestration close.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 (doc lint and task-reference lint).
- `grep -c 'roadmap_notes' agent-system/extensions/core/agents/roadmap-agent.md` prints 0.

---

### Phase 8: Format, Contract and Reference Documents; Recorded Dispositions [NOT STARTED]

**Goal**: The pruning ledger and the lint disposition are recorded in the source store, and no
document or code comment describes a layout that can no longer exist.

**Tasks**:
- [ ] `context/formats/roadmap-format.md`: rewrite Section Order, Authored vs. Generated and the
  Per-Section Ruling as the current design (everything generated; three parts in order). Record
  the pruning ledger here as a table: each section a classic file carries, who reads it, and its
  disposition (kept as a bounded field, or not rendered), per the report's Recommendation 5.
  State rejected alternatives on their merits, with no attribution to an earlier draft.
- [ ] `context/patterns/roadmap-update.md`: record the lint's single disposition (reads
  `roadmap_milestones[].batches[]`; call site `scripts/orchestrate-conclusion-roadmap.sh`, the
  `LINT_SCRIPT` invocation) in place of the undecided paragraph; update "Live Callers" and the
  refusal predicate.
- [ ] `context/contracts/conclusion-stage.md` Step 5: `generated` arm, lint on both arms, resolved
  output path.
- [ ] `context/formats/roadmap-entry-template.md`: milestone entry template with bounds.
- [ ] `context/reference/state-management-schema.md`: the three keys, the nested batch shape, the
  flat keys as the unmigrated-store shape, and the vault-renumbering residual for completed
  members.
- [ ] `context/standards/postflight-tool-restrictions.md` and
  `context/patterns/file-footprint-overlap.md`: correct their references to the preflight
  verdicts and to the lint's input.
- [ ] Re-anchor the numbered settled-decision citations in `scripts/lib/suite-selection-lib.sh`,
  `scripts/tests/run-all.sh` and `context/formats/plan-format.md` to the section of
  `context/standards/shell-script-testing.md` that states the `--skip-slow` coverage trade-off;
  confirm that file also states that `known-failures.txt` is advisory and never changes which
  suites run, and add one sentence there if it does not.
- [ ] `scripts/lib/engine-written-state-paths-lib.sh`: correct the comment describing the roadmap
  file as user-maintained.
- [ ] `index-entries.json`: every edited `context/**` file moves its `line_count`. The drift check
  is not commit-blocking here, so reconcile by hand in this phase where cheap and otherwise leave
  it to the Phase 9 redeploy, which auto-repairs it.
- [ ] Sweep every edited file for task numbers and draft-history phrasing.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: full

**Scope Hypothesis**: The file list below comes from the report's selective read of 51 files
naming the roadmap file (marked COVERAGE-UNVERIFIED there) plus this plan's own grep for the
preflight verdict names. Confirm completeness with a search shaped differently from both:
`grep -rIln 'Gate state\|Standing rules\|Settled decision\|hand-authored\|hand-curated' agent-system/extensions/core --include=*.md`,
and add any hit that describes the old layout to this phase's edits, recording the addition.

**Tier Justification**: The set spans indexed context documents, the plan-format standard and two battery-wide script headers (`run-all.sh`, `suite-selection-lib.sh`) that most suites reference, a cross-cutting surface no enumerated-dependent set covers.

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-format.md` - generated design, pruning ledger
- `agent-system/extensions/core/context/formats/roadmap-entry-template.md` - milestone template
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - lint disposition, callers
- `agent-system/extensions/core/context/reference/state-management-schema.md` - keys and residual
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - Step 5
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` - verdict names
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - lint input
- `agent-system/extensions/core/context/formats/plan-format.md` - re-anchored citation
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - anchor target, one sentence if missing
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` - comment
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` - re-anchored comment
- `agent-system/extensions/core/scripts/tests/run-all.sh` - re-anchored comment
- `agent-system/extensions/core/index-entries.json` - `line_count` for edited context files

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-touched.sh` with the thirteen paths above
  exits 0; under `/orchestrate` the complete gate set is deferred to the orchestration close.
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0.
- `grep -rIn 'Settled decision 1[35]' agent-system/extensions/core --include=*.sh --include=*.md`
  prints nothing.
- `roadmap-format.md` contains the ledger table and `roadmap-update.md` names both the lint's
  input and its call site.

---

### Phase 9: Redeploy, Migrate This Repository, and Acceptance Render [NOT STARTED]

**Goal**: The deployed tree carries the change, this repository's roadmap renders entirely from
state, and the sf1-engine acceptance render exists with a recorded judgment.

**Tasks**:
- [ ] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool timeout
  raised to 600000 ms. Confirm `index-entries.json` is reconciled afterwards.
- [ ] Run `bash .claude/scripts/migrate-roadmap-to-milestones.sh --dry-run --retained specs/archive/roadmap-retained-prose.md`
  and read the accounting: batch count before and after, items placed in state, items retained,
  every WARN. If the retained-prose target already exists, stop and choose a new name rather than
  overwrite.
- [ ] Re-run the dry run immediately before the real run, then run it for real with the same
  `--retained` path and this session id. The losslessness gate must pass; a failure is a blocker,
  not something to force.
- [ ] Confirm `specs/ROADMAP.md` begins with the sentinel, a second `--regenerate --dry-run`
  reports no content change, and `bash .claude/scripts/validate-state.sh specs/state.json` shows
  no flat-key WARN.
- [ ] Acceptance render on a copy (Decision 9): under this task's `records/` directory build a
  migrated copy of sf1-engine's store named `sf1-acceptance-store.json`, with milestones M0 to M4
  whose titles and gate text come from `integration/design.md` section 7, M0 closed, and that
  store's existing batches assigned beneath them. Render it with `--state` and `--roadmap`
  pointing into `records/`. Read sf1-engine only; write nothing there.
- [ ] Record the judgment in `records/sf1-acceptance-judgment.md`: size against the live file,
  whether status, progress and review state for every milestone are visible in the first screen,
  whether any milestone reads empty while holding real work, and what a reviewer still cannot
  see. A negative judgment is a valid result and is reported as such.
- [ ] Run the five named suites plus the two reached ones from the deployed tree and record the
  result per suite.

**Timing**: 2 hours

**Depends on**: 7, 8

**Verification Tier**: full

**Scope Hypothesis**: The report expects 7 of this repository's 20 settled decisions to exceed
the `conventions` bound and go to the retained-prose file (CARRIED-UNVERIFIED), and expects the
store to hold 30 flat batches (re-derived at planning time; other sessions may have changed it).
Confirm both from the dry run's own accounting and record the actual figures. The assignment of
sf1-engine's seven batches to M1 to M3 follows the report's illustrative overlay and is a
judgment the implementer may revise with a stated reason.

**Files to modify**:
- `__WHOLE_TREE__`
- `specs/state.json` - migrated to the milestone shape through `state-write.sh`
- `specs/ROADMAP.md` - generated
- `specs/archive/roadmap-retained-prose.md` - verbatim retained prose
- `agent-system/extensions/core/index-entries.json` - reconciled by the redeploy
- `specs/656_milestone_schema_and_generated_roadmap/records/sf1-acceptance-store.json` - migrated copy
- `specs/656_milestone_schema_and_generated_roadmap/records/sf1-acceptance-ROADMAP.md` - acceptance render
- `specs/656_milestone_schema_and_generated_roadmap/records/sf1-acceptance-judgment.md` - recorded judgment

**Verification**:
- Scoped touched-path check: `bash .claude/scripts/verify-touched.sh` exits 0. Under
  `/orchestrate` the complete gate set is deferred to the orchestration close and this phase
  records that deferral; a standalone run instead runs `bash .claude/scripts/verify-deploy.sh`
  and requires exit 0.
- `bash .claude/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-validate-state.sh,test-generate-task-order.sh,test-orchestrate-suggest-next-batch.sh,test-migrate-roadmap-next-to-state.sh,test-lint-roadmap-batch-proposals.sh,test-orchestrate-conclusion-roadmap.sh`
  exits 0 (the acceptance criterion's named suites, checked by exit status).
- `head -1 specs/ROADMAP.md` is the sentinel; `jq 'has("roadmap_batches") or has("roadmap_notes")' specs/state.json`
  prints `false`; `jq '.roadmap_milestones | length' specs/state.json` is at least 1.
- Both acceptance files exist and are non-empty.

## Testing & Validation

- [ ] The five named suites pass: `test-roadmap-generation.sh`, `test-validate-state.sh`,
  `test-generate-task-order.sh`, `test-orchestrate-suggest-next-batch.sh`,
  `test-migrate-roadmap-next-to-state.sh`.
- [ ] The two reached suites pass: `test-lint-roadmap-batch-proposals.sh`,
  `test-orchestrate-conclusion-roadmap.sh`.
- [ ] The two new suites pass: `test-roadmap-entries-lib.sh`,
  `test-migrate-roadmap-to-milestones.sh`.
- [ ] The schema/validator drift test passes in both directions.
- [ ] The migration's losslessness gate passes on this repository's real store.
- [ ] A second regenerate is byte-identical.
- [ ] Doc lint and task-reference lint pass over the source store.
- [ ] The complete gate set passes at the orchestration close.

## Artifacts & Outputs

- Source-store changes under `agent-system/extensions/core/` as listed per phase, including two
  new scripts and two new suites.
- `specs/ROADMAP.md` generated; `specs/state.json` in the milestone shape;
  `specs/archive/roadmap-retained-prose.md`.
- `specs/656_milestone_schema_and_generated_roadmap/records/` holding the sf1-engine acceptance
  store copy, render and judgment.
- `specs/656_milestone_schema_and_generated_roadmap/summaries/01_milestone-schema-generated-roadmap-summary.md`.

## Rollback/Contingency

Phases 1 to 8 are source-store commits, one per phase; revert the phase commits in reverse order
with `git revert` and redeploy. Phase 4 is additive and can stay in place if Phase 6 is reverted.

Phase 9's migration is the only step that changes this repository's store. Its inputs are
recoverable: the prior `specs/ROADMAP.md` and `specs/state.json` are in git history, and every
line the render drops is in the retained-prose file. To undo it, restore those two files from the
commit before the migration through the sanctioned rollback recipe in
`context/contracts/recovery.md`'s rollback rung (snapshot first, with its out-of-scope override
only if the tree holds other sessions' work), then redeploy the reverted source store. If the
losslessness gate fails in Phase 9, write nothing, leave the store flat, mark the phase
`[BLOCKED]` with the unaccounted lines named, and return; the accessor fallback keeps
`--next-batch` working on the flat store in the meantime.
