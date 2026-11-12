# Implementation Plan: Task #603

- **Task**: 603 - Make specs/ROADMAP.md a wholly generated artifact backed by state.json roadmap
  entries, and add a `/roadmap [instruction]` command/skill/agent that maintains them
- **Status**: [IMPLEMENTING]
- **Effort**: 13 hours
- **Dependencies**: None declared on this record. Task 602 carries a declared edge running
  *behind* 603 (its `--prune`-wiring question is answered differently once this lands).
- **Research Inputs**: specs/603_roadmap_command_generated_from_state/reports/01_roadmap-generated-artifact-research.md
- **Artifacts**: plans/01_roadmap-generated-from-state.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/context/reference/artifact-management.md
  - .claude/context/workflows/tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`specs/ROADMAP.md` is already partly generated, but the judgment that makes it useful — which
tasks form a batch, in what order, and why — exists only as prose inside the file its own
generator rewrites. This plan inverts that: a new top-level `roadmap_batches` array plus a
`roadmap_notes` object in `specs/state.json` become the only home for that judgment, the
generator renders `## Next` and `## Open work` wholly from state with no retention parsing in the
path, and a new `/roadmap [instruction]` command (skill + judgment-bearing agent) maintains the
entries. The agent decides; the script renders; nothing in the rendering path makes a judgment
call. Done means: a second consecutive render is byte-identical, the live file's authored
judgment is in state.json rather than discarded, both `/roadmap` forms are demonstrated against
this repository, and the Destructive-Overwrite Refusal still refuses an unclassifiable file.

**The narrower reading of "wholly generated", stated explicitly** (research Decision 1, confirmed
at plan time): `## Next` and `## Open work` become fully derived from `state.json`. The other six
`classic` sections stay authored directly in the markdown, each with a per-section ruling recorded
in Phase 2. `## Gate state` in particular cannot be generated at all — every bullet in the live
section cites a freshly-run suite count, a probe result, or a lock-contention observation, none of
which any script can derive from state. "Wholly generated" is therefore read as *every section an
agent's judgment can touch is generated, and the rendering path makes no judgments* — not as
*every byte of the file is derived*. This narrows the literal GOAL text and is adopted
deliberately, not silently.

### Research Integration

- Entry schema: new top-level `roadmap_batches`, array position **is** the batch priority — no
  new priority field, no reuse of the per-task `priority` enum (research Decisions 2 and 3).
- Two authored text fields per batch, not one: a bounded `description` (the anti-fluff field) and
  an unbounded `rationale` (the lossless home for today's "Why this order:" prose).
- Writes go through `state-write.sh` for entries and through
  `update-task-status.sh preflight <N> edge_only <session> --depends-on-add=[M]` for edges; no
  second writer of either kind (research Decision 6). `state-write.sh`'s audit-evidence gate
  fires only when a write introduces a new `active_projects` entry, which `/roadmap` never does,
  so no `--audit-verdict`/`--audit-override` plumbing is needed.
- Layout duality: keep `detect_layout` and the refusal gate as they are (both vocabularies still
  accepted); collapse only the rendering strategy (research Decision 5).
- `specs/ROADMAP.md` stays git-tracked and committed — the `specs/TODO.md`
  generated-and-committed precedent settles it.
- The advisory batch-proposal lint (`lint-roadmap-batch-proposals.sh`, from the record titled
  "Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md phase blocks",
  `[COMPLETED]`) is reported as **superseded in its parse layer, not merely narrowed**, and left
  untouched (research Decision 4; Phase 2 records the finding, the task summary reports it).

### Plan-time additions beyond the research report

Four things were measured at plan time that the research pass did not establish, and they
materially simplify or redirect the work:

1. **The `## Next` section's authored content is much larger than "Run lines plus a dozen
   bullets."** Its authored body before the coverage appendix is **193 lines, 178 non-blank**, of
   which 9 are `/orchestrate` lines and 2 are fence markers — leaving **167 non-blank authored
   prose lines**, spread across pre-fence analysis paragraphs, 14 top-level `Why this order:`
   bullets, and several free-standing paragraph blocks interleaved after them. A batch
   `rationale` field alone cannot hold all of it, so the schema gains a `roadmap_notes` object
   with three verbatim slots (`next_preamble`, `next_postamble`, `open_work_trailer`).
2. **`## Next`'s authored half is not read by a parser at all today.** `parse_retention()` (the
   actual retention parser) governs only `## Open work` task lines; `## Next` is retained by
   whole-section verbatim passthrough (`RM_NEXT` -> `strip_coverage_appendix`). `roadmap-format.md`'s
   `next:run:{i}:rationale` / `next:why-this-order` keys are conceptual labels for that
   passthrough, not parse targets. Retiring "the retention parser" therefore means retiring the
   **Open work** override machinery; eliminating the **Next** passthrough is a separate, parallel
   deletion. The plan does both, which is what the "no retention parser in the path" acceptance
   criterion actually requires.
3. **The Open work overrides carry no genuine authored content, and the retention mechanism is
   actively harmful.** Diffing the live `## Open work` against a fresh `--print` render: **13 of
   137 task lines differ; 12 are stale truncations of a title the retention parser froze, and the
   13th (task 540) is an older title snapshot**. There are **0 `<- ` annotations and 0
   `EXT-BLOCKED` tokens** in the live file. So the per-task `description` override is retired
   outright (the title is the sole source), which also repairs those 13 lines, and the migration
   of Open work overrides is a no-op by measurement rather than by assumption.
4. **A hard 100-character bound on the whole rendered Run line is unsatisfiable; the bound belongs
   on `description` alone.** `/orchestrate 603, 602, 515, 600, 597, 490, 601, 531` already
   consumes 51 characters, and the live trailing comments run to ~134 characters. The bound is
   therefore **`description` <= 100 characters**, reusing `## Open work`'s 100-character
   discipline as the dispatch directs, with the full original prose preserved in the unbounded
   `rationale`. Every live description must be condensed during migration — that is the
   anti-fluff rule doing its job, and nothing is lost because the original text lands in
   `rationale`.

### Premise re-validation (Carried-Figure Discipline)

Every trigger line the dispatch flagged, checked against live state at plan time:

| Carried claim | Result |
|---|---|
| Source store is the edit target (`agent-system/extensions/core/**`), redeploy via `deploy-headless.sh` | **CONFIRMED.** `.claude-extensions.json` present; every named file exists under `agent-system/extensions/core/`; `deploy-headless.sh` resolves only in the deployed tree. |
| "133 open records / 4 waves / 82 of 133" vs "142 records and 6 waves (83/30/18/9/1/1)" | **BOTH figures fail to reproduce.** Live: **142 `active_projects` entries, 137 non-terminal**; `generate-task-order.sh --print` gives **6 waves at 83 / 33 / 13 / 5 / 2 / 1**, with 83 having no open predecessor. The live `ROADMAP.md` figure (83/33/13/5/2/1 over 137) is the accurate one; the dispatch's parenthetical distribution is not. |
| "`priority` populated on 14 of 142 records: 1 critical, 3 high, 10 medium, 133 null" | **RE-DERIVED, different.** Live: **15 of 142 populated — 1 critical, 4 high, 10 medium — and 127 null.** The carried figure was also internally inconsistent (14 + 133 = 147 != 142). |
| "`--prune` reports `pruned=0 retained=141`" | **PARTIALLY reproduces.** `pruned=0` confirmed. `retained` is **0** in `--prune` mode (that field is only populated by `--regenerate`, which reports `retained=137`). `141` does not reproduce in either mode. |
| "The Destructive-Overwrite Refusal is a documented PERMANENT property" | **CONFIRMED verbatim** in `roadmap-integration.sh`'s header and in `roadmap-format.md`'s own subsection heading. |
| "`## Gate state` is measured by running checks, not by reading state, so it probably cannot be generated at all" | **CONFIRMED** by reading the live section; adopted as a ruling in Phase 2. |
| "[the batch lint] must never author, suggest or rank a batch" | **CONFIRMED.** That record is `[COMPLETED]`; the lint is wired into **no gate** (zero references in `verify-deploy.sh`, `gate-registry.data`, or `tests/run-all.sh`), so this task breaks nothing mechanically; its own script header already names this objective as the trigger for rescoping its parse layer. |
| "per-batch descriptions are ONE line ... never a paragraph" | Not a measurement — carried forward as this task's own requirement, implemented as the 100-character `description` bound plus the worked example pair in Phase 2. |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so no roadmap consultation
stage ran and no roadmap phases are added. For orientation only: the live `specs/ROADMAP.md`
`## Next` Run 1 rationale names this record's objective — "stop maintaining this file by hand" —
as the thing the rest of that batch is arranged around, and names the migration of that section's
rationale bullets as this record's inherited obligation. This plan discharges that obligation in
Phase 7.

## Goals & Non-Goals

**Goals**:
- A `roadmap_batches` entry schema in `specs/state.json`: ordered batches, each with member task
  ids, one bounded description, an unbounded rationale, and an optional CLI flag segment;
  specified in `state-management-schema.md` and validated by `validate-state.sh`.
- A `roadmap_notes` object holding the non-batch authored prose of `## Next` and the `## Open
  work` trailer, so nothing authored has to live inside the file the generator overwrites.
- A concise template under `context/` specifying both the entry shape and the rendered shape,
  with a hard length bound and one compliant plus one non-compliant worked description.
- `## Next` and `## Open work` rendered wholly from state; `parse_retention()` and the `## Next`
  verbatim passthrough both deleted; a second consecutive render byte-identical.
- `/roadmap [instruction]` — command, skill, and judgment-bearing agent — registered in
  `manifest.json` with a test companion, writing entries through `state-write.sh` and edges
  through the existing `edge_only` arm.
- The live file's authored judgment migrated into state entries, with losslessness demonstrated
  mechanically rather than by eyeballing.
- A recorded per-section ruling for every authored-verbatim and measured-by-hand section.

**Non-Goals**:
- Generating `## Gate state`, `## Goal`, `## Checks before and after every call`, `## Settled
  decisions`, `## Standing rules`, or `## Unfiled observations`. Each gets a ruling; none gets a
  renderer.
- Retiring the per-task `priority` enum, or removing the dead `roadmap_items` field (see Reasoned
  Exclusions).
- Editing the advisory batch-proposal lint or its owning record.
- Any second edge-writing path, or a `/roadmap`-specific state writer.
- Wiring `--prune` into the orchestration conclusion stage (that belongs to task 602, which reads
  differently after this lands).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **`validate-state.sh` is also task 531's sole declared file_scope entry** — a real, in-batch file collision this plan creates that the live roadmap's Run 1 rationale explicitly claims does not exist ("None of the four collides with another run-1 member") | H | H | Reported in this plan and in the handoff so the operator declares an edge (`update-task-status.sh preflight 531 edge_only <session> --depends-on-add=[603]`, or the reverse) **before either reaches implement**. Phase 1 additionally re-reads the file immediately before editing and stages only its own hunks. Not a planner-side write. |
| Concurrent writers mutate `specs/state.json` during Phase 7's migration | H | M | Every write goes through `state-write.sh` (fail-closed mutex, private staging path). The migration is idempotent and re-runnable; it refuses when `roadmap_batches` is already non-empty unless `--force`. |
| The 100-character `description` bound forces rewriting all 9 live descriptions, and a condensation silently loses meaning | M | H | The original trailing comment is preserved verbatim as the first paragraph of that batch's `rationale`; the migration asserts this and fails if any original comment text is unaccounted for. |
| Losslessness is checked by eyeballing and a paragraph is dropped or merged | H | M | Phase 7's migration performs a mechanical line-level accounting: every non-blank line of the pre-migration `## Next` body (**167 prose lines + 9 Run lines + 2 fence lines = 178**) must be accounted for in a `roadmap_notes` slot, a batch `rationale`, or a reconstructed Run line, and the script **exits non-zero naming each unaccounted line** rather than reporting success. |
| The `stage` layout is live in a consumer repo this work cannot see, and the new rendering breaks it silently | M | M | `detect_layout` and the refusal gate are untouched; both vocabularies stay accepted. The state-backed `## Next` rendering becomes the only generation strategy under both layouts, with the stage layout's run-order section located by the existing `body_has_orchestrate_fence` predicate. Phase 3 keeps the existing stage round-trip test cases green as its own criterion. |
| Retiring the per-task description override changes 13 live `## Open work` lines on first regenerate | L | H | Expected and desirable — 12 are stale truncations and 1 an outdated title snapshot. Phase 7 records the 13-line diff as an intended repair in the task summary, not as a regression. |
| `roadmap_batches` / `roadmap_notes` land in `state-schema.json` and `validate-state.sh` out of sync | M | M | The existing schema-to-validator drift test in `tests/test-validate-state.sh` catches this class; Phase 1 runs it as its own criterion rather than assuming a pass. |
| A new top-level key breaks a consumer that assumes the current key set | M | L | Both keys are optional with documented absent-means-empty semantics; `additionalProperties: false` is satisfied by adding them to `properties`; no existing reader enumerates top-level keys except Check 3's own allow-list. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 5 | 2 |
| 4 | 4, 6 | 3 (phase 4), 5 (phase 6) |
| 5 | 7 | 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 5 and 6 both edit
`manifest.json`, which is why 6 depends on 5 rather than joining it in wave 3.

---

### Phase 1: Schema and Validator for `roadmap_batches` and `roadmap_notes` [COMPLETED]

**Goal**: `specs/state.json` gains two optional top-level keys with a modelled, validated,
documented shape, and the schema reference stops omitting fields it already models.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/validate-state.sh` immediately before editing
      (task 531 declares this same file; see Risks).
- [x] Add `roadmap_batches` to `state-schema.json`'s top-level `properties`: an array of objects,
      each with `task_ids` (array of integers, required, non-empty), `description` (string,
      required, `maxLength: 100`), `rationale` (string, optional, unbounded), `flags` (string,
      optional). Document in the field description that **array position is the batch's
      priority** and that no separate priority field exists.
- [x] Add `roadmap_notes` to `state-schema.json`'s top-level `properties`: an object with
      `next_preamble`, `next_postamble`, and `open_work_trailer`, each an optional array of
      strings (one entry per rendered paragraph), `additionalProperties: false`.
- [x] Add `roadmap_annotation` (string, optional) and `roadmap_ext_blocked` (boolean, optional) to
      `definitions.projectEntry.properties` — the schema-backed successors to the `<- ` annotation
      and `EXT-BLOCKED` token, which have had no schema home at all. Do **not** add a description
      override field: the title is the sole source (see Overview addition 3).
- [x] Add all four names to `validate-state.sh`'s `KNOWN_TOP_LEVEL_FIELDS` / `KNOWN_ENTRY_FIELDS`
      arrays in the same commit as the schema change, per the drift-test convention Check 3 and
      Check 4 document.
- [x] Add **Check 13** to `validate-state.sh` (next free number; Check 12 is the current highest):
      for every `roadmap_batches` entry, assert (a) `task_ids` is non-empty and every member is an
      existing, non-terminal `project_number`; (b) no task id appears in more than one batch;
      (c) `description` is present, non-empty, and <= 100 characters. Land it at the same
      **WARN-only, `--strict`-enforcing** level as Checks 8-11, with a PROMOTION CRITERION comment
      in the same shape those checks already carry.
- [x] Extend `tests/test-validate-state.sh` with fixtures for each Check 13 sub-condition (clean
      pass, terminal member, duplicated member, over-long description, absent key as a clean
      pass), plus the schema-to-validator drift case for the four new names.
- [x] Update `context/reference/state-management-schema.md`: add `roadmap_batches` and
      `roadmap_notes` rows to the Top-Level Fields table, `roadmap_annotation` /
      `roadmap_ext_blocked` rows to the Project Entry Fields table, and — the directly adjacent
      gap the research pass found — a **`priority`** row, which that table omits today although
      the schema models it and the validator references it.
- [x] Record the two field rulings in that same file: `priority` is kept as-is and is **never**
      read for batch ordering; `roadmap_items` (array, documented-optional, **0 live entries, no
      writer, no reader**) is explicitly **not** the batch carrier and is named a dead field whose
      retirement belongs to `migrate-state-legacy-fields.sh`'s purview, not this task.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: `suite_selection_select` over this phase's four `Files to modify` paths
returns exactly these eight suites, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-assess-repo-health.sh,test-deploy-baseline-lib.sh,test-init-specs.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-suggest-next-batch.sh,test-status-vocabulary.sh,test-update-task-status.sh,test-validate-state.sh`.

**Scope Hypothesis**: "Check 12 is the current highest check number, so the new one is Check 13",
"`roadmap_items` has 0 live entries", and "`priority` is populated on 15 of 142 entries (1
critical, 4 high, 10 medium, 127 null)" are all plan-time measurements over the live
`specs/state.json` and `validate-state.sh`; re-derive each with `grep -nE 'Check [0-9]+'` and a
`jq` count at implementation time before relying on it, since both files are under concurrent
edit by a sibling record.

**Files to modify**:
- `agent-system/extensions/core/context/schemas/state-schema.json` - add two top-level properties and two projectEntry properties
- `agent-system/extensions/core/scripts/validate-state.sh` - extend both known-field arrays; add Check 13
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - Check 13 fixtures and the drift case
- `agent-system/extensions/core/context/reference/state-management-schema.md` - field documentation and the two field rulings

**Verification**:
- The eight suites named in the Tier Justification pass, `test-validate-state.sh` among them.
- `bash .claude/scripts/validate-state.sh` exits 0 against the live `specs/state.json` with both
  new keys still absent (absent-means-empty is a clean pass, not a warning).
- `bash .claude/scripts/lint/lint-shellcheck.sh` is clean for the edited script, per
  `context/standards/shell-strict-mode.md`.

---

### Phase 2: The Generation Contract and the Concise Entry Template [COMPLETED]

**Goal**: the rendered shape, the entry shape, the anti-fluff bound, and the per-section ruling
for all six authored sections are all written down before any renderer changes.

**Tasks**:
- [x] Create `context/formats/roadmap-entry-template.md`: the concise template the dispatch asks
      for. It specifies **both** the entry shape (a `roadmap_batches` object, field by field) and
      the rendered shape (`/orchestrate {ids} {flags}   # {description}` plus the `Why this
      order:` bullet rendered from `rationale`), states the **hard bound — `description` <= 100
      characters** — and gives the anti-fluff rule: one line stating what the batch accomplishes
      and why those members belong together, never a paragraph, never a restatement of each
      member's own title.
- [x] In that file, write the two worked examples the dispatch requires, with character counts
      shown so the bound is checkable rather than aspirational:
      - **Compliant** (76 chars): `Make the roadmap generated and close the two costs that measurement surfaced`
      - **Non-compliant** (112 chars): `Fixes the roadmap generator, the next-batch suggester, the backgrounding ceiling, and the memory-retrieval retry` — over the bound *and* a per-member title restatement, which is why it fails on two counts rather than one.
- [x] State in the template that the 100-character bound is deliberately on `description` alone,
      not on the whole rendered line, and why (a long `task_list` already consumes ~51 characters
      of a Run line, so a whole-line bound would be unsatisfiable).
- [x] Rewrite `roadmap-format.md`'s **Authored vs. Generated** table: `## Next` becomes
      `generated` (sourced from `roadmap_batches` + `roadmap_notes.next_preamble` /
      `.next_postamble`); `## Open work` becomes `generated` (sourced from `active_projects` +
      `roadmap_annotation` / `roadmap_ext_blocked` + `roadmap_notes.open_work_trailer`); the
      retention-key column is replaced by a state-field column.
- [x] Rewrite `roadmap-format.md`'s **Next Grammar** section as a rendering contract rather than a
      parsing one, and its **Open work Grammar** `{description}` bullet to name `title` as the sole
      source (the authored override is retired). Keep the `EXT-BLOCKED` precedence row but change
      its Source cell from "authored override ... no schema support" to the new
      `roadmap_ext_blocked` field.
- [x] Record the **per-section ruling** the dispatch requires, as its own subsection: `## Goal`
      (authored-verbatim — a standing mission statement, no structured shape an agent would
      revise); `## Gate state` (**cannot be generated at all** — measured by running suites, not
      derived from any field); `## Checks before and after every call` (authored-verbatim — a
      fixed procedural checklist); `## Settled decisions (do not re-litigate)` (authored-verbatim
      — owner rulings, no per-task shape); `## Standing rules` (authored-verbatim — same shape);
      `## Unfiled observations` (authored-verbatim — a scratch list, deliberately unstructured).
- [x] Leave the **Destructive-Overwrite Refusal** subsection unchanged, and add one sentence
      recording why a fully generated file makes it *more* important: the blast radius of a bad
      render is now the whole document.
- [x] Update `context/patterns/roadmap-update.md`'s per-mode contract: `--regenerate`'s "retaining
      every authored value" promise is replaced by "renders `## Next` and `## Open work` wholly
      from state"; `--prune` is documented as a **deprecated alias** that prints a named note and
      performs `--regenerate` (a file rendered from live state cannot accumulate terminal cruft —
      measured: `--prune` reports `pruned=0` on this repository), with its caller contract
      unbroken.
- [x] Record the batch-proposal lint's disposition in `roadmap-update.md`'s own cross-reference:
      its parse layer's subject matter (hand-authored `## Next` Run lines) ceases to exist, so it
      is **superseded, not narrowed**; the lint is wired into no gate, so nothing breaks
      mechanically; the rescoping-or-retirement decision is left to its owner and **that record is
      not edited by this task**.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` over this phase's three `Files to modify` paths
returns `__FULL_SWEEP__` (every path is a `context/` markdown file with no mapped suite), so the
covering check is
`bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
alongside the `prose` row's diff read-through confirming every changed hunk is prose.

**Scope Hypothesis**: the claim that the six non-batch sections are the complete authored set, and
that `--prune` reports `pruned=0`, is carried from the research report
(`reports/01_roadmap-generated-artifact-research.md`, Decision 1) and re-derived at plan time
(`grep -n '^## ' specs/ROADMAP.md` gives exactly eight headers; `--prune --dry-run` against a copy
reports `pruned=0`); re-run both before writing the ruling subsection in case a section was added.

**Files to modify**:
- `agent-system/extensions/core/context/formats/roadmap-entry-template.md` - NEW: the concise entry/rendered-shape template with the hard bound and worked example pair
- `agent-system/extensions/core/context/formats/roadmap-format.md` - rewrite the authored/generated table and both grammars; add the per-section ruling
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - per-mode contract update; `--prune` deprecation; lint disposition cross-reference

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0 (gates 3 and 4 both run rather than SKIP, since this repository root holds both a
  deployed `.claude/` tree and the `agent-system/extensions` source store).
- Diff read-through confirms every changed hunk is prose; the new template states a numeric bound
  and carries exactly one compliant and one non-compliant example, each with its character count.
- A ruling exists for each of the six sections named above — six rulings, none deferred.

---

### Phase 3: Render `## Next` Wholly from `roadmap_batches` and `roadmap_notes` [COMPLETED]

**Goal**: `## Next` is built from state instead of being passed through verbatim, under both
layouts, with the refusal gate and the coverage appendix unchanged.

**Tasks**:
- [x] Add `render_next()` to `roadmap-integration.sh`: emit `roadmap_notes.next_preamble`
      paragraphs, then a fence containing one `/orchestrate {ids} {flags}   # {description}` line
      per `roadmap_batches` entry **in array order**, then `Why this order:` and one bullet per
      entry carrying a non-empty `rationale` (a multi-paragraph rationale renders as one bullet
      with continuation lines indented two spaces), then `roadmap_notes.next_postamble`
      paragraphs.
- [x] Rewrite `mode_regenerate_classic()` to call `render_next()` instead of
      `strip_coverage_appendix <<<"$RM_NEXT"`, keeping `render_coverage_appendix()`'s input
      contract intact by computing `covered_ids_json` from `roadmap_batches[].task_ids` directly
      rather than by grepping the rendered block.
- [x] Rewrite `mode_regenerate_stage()` to replace the run-order section's body with
      `render_next()`'s output plus the fresh coverage appendix, locating that section with the
      existing `body_has_orchestrate_fence` predicate and leaving every other section
      byte-for-byte. Keep the existing stage round-trip test cases green.
- [x] Leave `detect_layout()`, `refuse_unrecognised_layout()`, `write_or_diff()`, and the stderr
      marker's six count fields untouched. `runs=` now counts `roadmap_batches` entries; state
      that in the header comment rather than changing the field set.
- [x] Make a batch naming a now-terminal task render with that id dropped and the whole line
      omitted once every member is terminal — the behaviour `--prune` used to provide, now a
      property of rendering from live state rather than a separate pass.
- [x] Extend `tests/test-roadmap-generation.sh`: a fixture state with two batches renders both Run
      lines in array order with their descriptions; an entry with no `rationale` emits no bullet;
      a batch whose members are all terminal is omitted; `next_preamble`/`next_postamble` render
      in the right positions; a second consecutive `--regenerate` is byte-identical; the
      unrecognised-layout refusal still refuses (exit non-zero, no write).

**Timing**: 2 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two `Files to modify` paths
returns exactly three suites, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh,test-sweep-invalidated-claims.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - add `render_next()`; rewrite both regenerate arms to read state instead of the existing file's `## Next` body
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - state-backed `## Next` cases, idempotence, refusal-still-refuses

**Verification**:
- The three suites named in the Tier Justification pass. `test-roadmap-generation.sh` resolves its
  subject in `source-store` mode and builds its own scratch deploy tree, so the edited source-store
  script is the thing under test without a redeploy.
- `bash .claude/scripts/lint/lint-shellcheck.sh` is clean for the edited script.
- A fixture `--regenerate` run twice in a row produces a byte-identical file (`cmp -s`).

---

### Phase 4: Delete the Retention Parser and Deprecate `--prune` [COMPLETED]

**Goal**: the net deletion — no code path in the generator reads authored content out of the file
it is about to overwrite.

**Tasks**:
- [x] Delete `parse_retention()` and the `RETAIN_DESC` / `RETAIN_ANNOT` / `RETAIN_EXT` globals.
- [x] Rewrite `render_open_work()`'s per-line branch: the description is always the
      `title`-derived render (truncated so `{num} {tok}  {desc}` stays at or under 100
      characters); the `<- ` suffix comes from `roadmap_annotation`; the `EXT-BLOCKED` token comes
      from `roadmap_ext_blocked` and keeps its position 5 precedence, ahead of the dependency
      filter.
- [x] Replace `extract_open_work_trailer()` with a read of `roadmap_notes.open_work_trailer`, and
      delete the function.
- [x] Make `--prune` a deprecated alias: print one named stderr note ("--prune is deprecated: a
      file rendered from live state accumulates no terminal cruft; running --regenerate instead")
      and dispatch to `mode_regenerate`. Delete `count_terminal_task_lines()`,
      `count_pruned_next_ids()`, `prune_open_work_body()`, `prune_next_body()`,
      `mode_prune_classic()`, and `mode_prune_stage()`. Keep the flag accepted and the stderr
      marker's `pruned=` field present (always `0`) so every existing caller — the conclusion
      stage's documented invocation included — keeps working unchanged.
- [x] Update the script's own header-comment usage block and the `--help` output it `sed`s out of
      itself, so `--help` does not drift from the new behaviour.
- [x] Extend `tests/test-roadmap-generation.sh`: an `## Open work` line whose live file holds a
      stale truncated description re-renders from the current `title` (the drift repair); a task
      with `roadmap_annotation` renders the `<- ` suffix; a task with `roadmap_ext_blocked: true`
      renders `EXT-BLOCKED` and takes precedence over its dependency-derived token; `--prune`
      emits the deprecation note, exits 0, and produces the same file `--regenerate` would.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's two `Files to modify` paths
returns exactly three suites, so the covering check is
`bash .claude/scripts/tests/run-all.sh --only test-roadmap-generation.sh,test-skill-base-lifecycle.sh,test-sweep-invalidated-claims.sh`.

**Scope Hypothesis**: the function list above (`parse_retention`, `extract_open_work_trailer`, and
the six prune-mode functions) is enumerated from the live
`agent-system/extensions/core/scripts/roadmap-integration.sh` at plan time; confirm with
`grep -nE '^[a-z_]+\(\)' agent-system/extensions/core/scripts/roadmap-integration.sh` before
deleting, since Phase 3 edits the same file and may have moved or renamed a call site.

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - delete the retention parser, the trailer extractor, and the prune mode; state-source the Open work overrides
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` - drift-repair, annotation, ext-blocked, and `--prune`-alias cases

**Verification**:
- The three suites named in the Tier Justification pass.
- `grep -n 'parse_retention\|RETAIN_DESC\|RETAIN_ANNOT\|RETAIN_EXT\|extract_open_work_trailer\|mode_prune_' agent-system/extensions/core/scripts/roadmap-integration.sh`
  returns no hits outside comments — the exit status of the grep is checked, not only its output.
- `bash .claude/scripts/lint/lint-shellcheck.sh` is clean for the edited script.

---

### Phase 5: The `/roadmap` Command, Skill, and Agent, Registered [COMPLETED]

**Goal**: `/roadmap [instruction]` exists end to end — the agent decides, the script renders — and
is registered everywhere the extension's conventions require.

**Tasks**:
- [x] Create `commands/roadmap.md` with the frontmatter shape `commands/spawn.md` uses
      (`description:`, `allowed-tools:`, `argument-hint:`): `argument-hint: [instruction]`,
      documenting that no argument performs a full maintenance pass and a quoted instruction
      scopes the pass to that focus.
- [x] Create `skills/skill-roadmap/SKILL.md` as a thin wrapper that dispatches `roadmap-agent`
      and then performs the writes the agent decided on, modelled on `skill-reviser`'s
      delegate-then-postflight shape.
- [x] Create `agents/roadmap-agent.md` — a judgment-bearing agent, deliberately not collapsed to
      direct execution. Its decisions: which batches exist and in what order, each batch's one
      bounded description, each batch's rationale, and which dependency edges are missing. Its
      frontmatter carries `name:`, `description:`, `model: opus` (deep-reasoning tier), `tools:`,
      and **no** `allowed-tools:`/`mcp-servers:` key, per
      `docs/reference/standards/agent-frontmatter-standard.md` and the checks
      `lint/lint-agent-contracts.sh` already applies to every agent file.
- [x] Give the agent file the two contract fragments that lint requires of a dispatchable agent:
      the no-task-references MUST-NOT bullet (text read from
      `context/contracts/no-task-references-bullet.md`, not invented) and an object-shaped
      `artifacts` template with `type`/`path`/`summary` keys.
- [x] Write the agent's write contract explicitly, as a MUST NOT list: entries go through
      `bash .claude/scripts/state-write.sh '<jq-filter>' --session-id "$SID"`; **edges go through
      `bash .claude/scripts/update-task-status.sh preflight <N> edge_only "$SID"
      --depends-on-add=[M]` and through nothing else**. Record the measured constraint on that
      arm: `edge_only` resolves `STATE_STATUS` to the literal `not_started`, so it is correct
      **only** for a task currently at `not_started`; for any other status the agent must replay
      that task's own current status (the script's own refusal message names the right call), and
      it must never invent a third path.
- [x] Write the agent's anti-fluff contract by reference to
      `context/formats/roadmap-entry-template.md` (the bound and the worked example pair live
      there, not in two places).
- [x] State that the agent never writes `specs/ROADMAP.md` itself — it writes entries and then
      invokes `bash .claude/scripts/roadmap-integration.sh --regenerate`, so nothing in the
      rendering path makes a judgment call.
- [x] Register all three in `manifest.json`'s `provides.commands` (`roadmap.md`),
      `provides.agents` (`roadmap-agent.md`), and `provides.skills` (`skill-roadmap`).
- [x] Add the `/roadmap` rows to `merge-sources/claudemd.md`'s Command Reference table and the
      `skill-roadmap | roadmap-agent` row to its Skill-to-Agent Mapping table — the source store
      for the deployed `.claude/CLAUDE.md`, never the deployed file.
- [x] Add an `index-entries.json` entry for `formats/roadmap-entry-template.md` (created in Phase
      2) and refresh `formats/roadmap-format.md`'s and `patterns/roadmap-update.md`'s `line_count`
      and `summary` fields, which Phase 2's rewrite stales. Re-read this file immediately before
      editing — a sibling record declares it.
- [x] Create `tests/test-roadmap-command-registration.sh`, the test companion the acceptance
      criteria require: assert the three files exist, that each is listed in the matching
      `manifest.json` `provides` array, that the agent frontmatter carries a valid `model:` and no
      forbidden key, that the index entry for the new template resolves, and that both
      `claudemd.md` tables carry a `/roadmap` row.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: full

**Tier Justification**: `manifest.json` is this extension's deploy-registration surface —
`suite_selection_select` maps it alone to 31 suites spanning deploy propagation, gate selection,
double-loading, and index-schema checks, and the group as a whole returns `__FULL_SWEEP__` because
the three new guidance files map to no suite at all — so no cheaper subset covers a registration
change that every consumer's deploy reads.

**Scope Hypothesis**: "`manifest.json` maps to 31 suites" and "the three new files map to no
suite" are plan-time `suite_selection_select` outputs; re-run the selector over this phase's final
`Files to modify` list at implementation time rather than trusting the count, since the suite
corpus turns over.

**Files to modify**:
- `agent-system/extensions/core/commands/roadmap.md` - NEW: the `/roadmap [instruction]` command definition
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md` - NEW: thin wrapper dispatching `roadmap-agent`, then performing the decided writes
- `agent-system/extensions/core/agents/roadmap-agent.md` - NEW: the judgment-bearing agent, with its write contract and anti-fluff reference
- `agent-system/extensions/core/manifest.json` - register the command, skill, and agent
- `agent-system/extensions/core/merge-sources/claudemd.md` - command-reference and skill-to-agent-mapping rows
- `agent-system/extensions/core/index-entries.json` - entry for the new template; refresh two stale `line_count`/`summary` pairs
- `agent-system/extensions/core/scripts/tests/test-roadmap-command-registration.sh` - NEW: the structural test companion

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set) exits 0.
- `bash .claude/scripts/lint/lint-agent-contracts.sh` passes for the new agent file, with its exit
  status checked rather than its output diffed.
- `bash .claude/scripts/tests/run-all.sh --only test-roadmap-command-registration.sh` passes.
- `bash .claude/scripts/lint/lint-shellcheck.sh` is clean for the new test script.

---

### Phase 6: The One-Time Migration Script [COMPLETED]

**Goal**: a script that reads the current `specs/ROADMAP.md` once, seeds the state entries from
it, and **proves** the read was lossless rather than reporting success.

**Tasks**:
- [x] Create `scripts/migrate-roadmap-next-to-state.sh`: parse the existing `## Next` body (before
      the coverage appendix) into one `roadmap_batches` entry per `/orchestrate` line — `task_ids`
      from the id list, `flags` from the authored flag segment, `description` from the trailing
      `   # ` comment **condensed to <= 100 characters**, and `rationale` seeded with the original
      trailing comment verbatim followed by the matching `Why this order:` bullet.
- [x] Assign each `Why this order:` bullet to a batch when it names that batch (by position or by
      first-named task id) and to `roadmap_notes.next_postamble` otherwise; assign the pre-fence
      paragraphs to `roadmap_notes.next_preamble` and the interleaved free-standing paragraph
      blocks after the bullet list to `next_postamble`, in file order.
- [x] Implement the **losslessness accounting** as a hard gate, not a report: every non-blank line
      of the pre-migration `## Next` body must be accounted for in exactly one of a
      `roadmap_notes` slot, a batch `rationale`, a reconstructed `/orchestrate` line, or the two
      fence markers. **Exit non-zero and name every unaccounted line** on any shortfall. The
      deliberate exception is the condensed `description`, whose original text is required to
      appear verbatim inside its own batch's `rationale` — assert that too.
- [x] Also seed `roadmap_notes.open_work_trailer` from any free-standing prose after the last
      `## Open work` fence (measured as **empty** in the live file, so the expected result is an
      empty array — the code path still exists and is tested).
- [x] Write exclusively through `bash .claude/scripts/state-write.sh` with an explicit
      `--session-id`, never a hand-rolled `jq ... > tmp && mv`, following the discipline
      `validate-state.sh --fix` and `migrate-state-legacy-fields.sh` already use. Refuse (exit 2)
      when `roadmap_batches` is already non-empty unless `--force`, and support `--dry-run`
      printing the proposed entries plus the accounting result while writing nothing.
- [x] Source `lib/common.sh` and the deploy-root guard the same way its sibling scripts do, and
      register the script in `manifest.json`'s `provides.scripts` in the same commit it is
      created (`test-manifest-scripts-sync.sh` enforces both directions).
- [x] Create `tests/test-migrate-roadmap-next-to-state.sh`: a fixture `## Next` with two batches,
      one preamble paragraph, two bullets (one batch-attributable, one not) and one postamble
      paragraph migrates to the expected entries; an over-long description fails the bound unless
      condensed; a deliberately dropped line makes the accounting gate exit non-zero naming that
      line; `--dry-run` writes nothing; a second run without `--force` refuses.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` over this phase's `Files to modify` paths returns
the `__FULL_SWEEP__` sentinel (a brand-new script and a brand-new suite are in no mapping yet), so
no existing suite covers them and none is claimed; the covering check is the `local` row's own
single-module lint, `bash .claude/scripts/lint/lint-shellcheck.sh`, run together with this phase's
own newly authored suite named in the Verification criteria below.

**Scope Hypothesis**: "the live `## Open work` has no trailer" and "the live `## Next` authored
body is 193 lines / 178 non-blank / 9 Run lines / 2 fence lines" are plan-time measurements over
`specs/ROADMAP.md`; re-measure immediately before Phase 7 runs the migration, because that file is
hand-edited between orchestration runs and the figures move.

**Files to modify**:
- `agent-system/extensions/core/scripts/migrate-roadmap-next-to-state.sh` - NEW: the one-time `## Next` -> state.json migration with a hard losslessness gate
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-next-to-state.sh` - NEW: fixture, accounting-gate, dry-run, and refuse-on-rerun cases
- `agent-system/extensions/core/manifest.json` - register the new script in `provides.scripts`

**Verification**:
- `bash .claude/scripts/tests/run-all.sh --only test-migrate-roadmap-next-to-state.sh,test-manifest-scripts-sync.sh`
  passes.
- `bash .claude/scripts/lint/lint-shellcheck.sh` is clean for both new scripts.
- `bash .claude/scripts/lint/lint-state-writer-boundary.sh` passes — the new script writes only
  through `state-write.sh`.

---

### Phase 7: Redeploy, Migrate Live State, and Demonstrate `/roadmap` [NOT STARTED]

**Goal**: the whole thing works on this repository — the live file's judgment is in state, the
file renders from it idempotently, and both `/roadmap` forms are demonstrated.

**Tasks**:
- [ ] Regenerate the deployed tree: `bash .claude/scripts/deploy-headless.sh`, so the new
      command/skill/agent and the edited scripts land in `.claude/`.
- [ ] Confirm the deploy landed the new surfaces (the three trio files and both new scripts
      present under the deployed tree, and `/roadmap` visible in the deployed `CLAUDE.md` tables).
- [ ] Take a durable, non-reverting checkpoint before the first live state write:
      `bash .claude/scripts/git-snapshot.sh 603 --no-revert`.
- [ ] Re-measure the live `## Next` body (line counts, Run-line count, bullet count) and record
      the figures, then run
      `bash .claude/scripts/migrate-roadmap-next-to-state.sh --dry-run` and read the proposed
      entries and the accounting result before writing anything.
- [ ] Run the migration for real, then show the accounting gate's own output as the losslessness
      evidence: every non-blank authored line accounted for, and each condensed description's
      original text present verbatim in its batch's `rationale`.
- [ ] Run `bash .claude/scripts/roadmap-integration.sh --regenerate --dry-run`, read the diff
      (it will include the 13 `## Open work` lines the retired description override was freezing —
      an intended repair, not a regression), then run `--regenerate` for real.
- [ ] Prove idempotence: run `--regenerate` a second time and confirm `cmp -s` byte-identity
      against the first render, and that the `OUTCOME:` line reports "left ... unchanged".
- [ ] Prove the refusal still holds: point `--regenerate --roadmap` at a scratch copy whose
      headers match neither vocabulary and confirm a non-zero exit, the named reason on stderr,
      and **no write**.
- [ ] Demonstrate `/roadmap` with no argument (a full maintenance pass) and
      `/roadmap "<instruction>"` (the same pass scoped to a stated focus) against this
      repository's live roadmap, and record both outcomes.
- [ ] Confirm `bash .claude/scripts/validate-state.sh` passes Check 13 against the now-populated
      `roadmap_batches`, and that `specs/ROADMAP.md` remains git-tracked and is committed with the
      state change.
- [ ] Record, in the task summary, the batch-proposal lint's disposition (superseded in its parse
      layer, wired into no gate, left untouched, decision left to its owner) and the
      `--prune`-dissolves finding that the dependent next-batch-suggestion record needs.

**Timing**: 2 hours

**Depends on**: 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `specs/state.json` - populated `roadmap_batches` and `roadmap_notes` entries migrated from the live file
- `specs/ROADMAP.md` - the first wholly generated render
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set this repository aggregates —
  exits 0. No `--skip-slow` and no `--only-gate` narrowing: this is the final phase's own full
  gate run, and a narrowed pass is not evidence the doc-sync pins hold.
- `bash .claude/scripts/tests/run-all.sh` (the unfiltered battery) passes, or every failure is
  already classified in `tests/known-failures.txt` with its row re-read rather than assumed.
- A second consecutive `--regenerate` is byte-identical (`cmp -s`, exit status checked).
- The migration's accounting gate exited 0 on the live file, with its per-line accounting shown.
- The unclassifiable-layout refusal exits non-zero with no write against a scratch fixture.
- Both `/roadmap` invocation forms ran against the live roadmap and their effects are recorded.
- `bash .claude/scripts/validate-state.sh` exits 0 with `roadmap_batches` populated.

---

## Testing & Validation

- [ ] `test-validate-state.sh` covers each Check 13 sub-condition plus the schema-to-validator
      drift case for all four new field names.
- [ ] `test-roadmap-generation.sh` covers state-backed `## Next` rendering under both layouts,
      the state-sourced Open work annotation and `EXT-BLOCKED` carriers, the `--prune` deprecation
      alias, byte-identical idempotence, and the unchanged unrecognised-layout refusal.
- [ ] `test-migrate-roadmap-next-to-state.sh` covers the losslessness accounting gate in both
      directions (clean pass, and non-zero exit naming a deliberately dropped line).
- [ ] `test-roadmap-command-registration.sh` covers the trio's existence, manifest registration,
      agent frontmatter validity, index entry, and both `claudemd.md` table rows.
- [ ] `lint-agent-contracts.sh`, `lint-shellcheck.sh`, and `lint-state-writer-boundary.sh` pass
      for every new or edited file, with exit statuses checked.
- [ ] The complete `verify-deploy.sh` gate set passes at the end of the final phase.

## Artifacts & Outputs

- `specs/603_roadmap_command_generated_from_state/plans/01_roadmap-generated-from-state.md` (this
  plan)
- Four new source-store files: `context/formats/roadmap-entry-template.md`,
  `commands/roadmap.md`, `skills/skill-roadmap/SKILL.md`, `agents/roadmap-agent.md`
- Three new scripts/suites: `scripts/migrate-roadmap-next-to-state.sh`,
  `scripts/tests/test-migrate-roadmap-next-to-state.sh`,
  `scripts/tests/test-roadmap-command-registration.sh`
- Edited: `state-schema.json`, `validate-state.sh`, `test-validate-state.sh`,
  `state-management-schema.md`, `roadmap-format.md`, `roadmap-update.md`,
  `roadmap-integration.sh`, `test-roadmap-generation.sh`, `manifest.json`, `claudemd.md`,
  `index-entries.json`
- Live state: `specs/state.json` with populated `roadmap_batches` / `roadmap_notes`;
  `specs/ROADMAP.md` as a wholly generated, committed artifact
- A regenerated `.claude/` deploy tree (a disposable artifact, not a deliverable)

## Reasoned Exclusions

- **Retiring the `roadmap_items` project-entry field.** It has 0 live entries, no writer, and no
  reader, so it is a genuinely dead third axis. It is *ruled on* in Phase 1 (explicitly not the
  batch carrier, explicitly named dead) but not removed: field retirement in this codebase goes
  through `migrate-state-legacy-fields.sh`'s no-information-loss migration path, which is a
  separate mechanism with its own consumer-repo rollout obligation. Pulling it in would widen this
  task across a second migration surface for no benefit to the acceptance criteria.
- **Retiring or rescoping the advisory batch-proposal lint.** The dispatch explicitly forbids
  silently editing that record; this task reports the disposition and leaves the decision to its
  owner. The lint is wired into no gate, so nothing breaks in the interim.
- **Generating `## Gate state`.** Ruled impossible in Phase 2 rather than attempted: every bullet
  cites a freshly-run suite count, probe result, or lock observation that no field holds.
- **Wiring `--prune` (now an alias) into the orchestration conclusion stage.** That belongs to the
  dependent next-batch-suggestion record, whose own question this task answers.
- **A `stage`-layout live validation.** No `stage`-layout roadmap exists anywhere in this tree to
  test against, so the stage arm is covered by fixture tests only; the plan preserves both
  vocabularies rather than collapsing detection on an untestable assumption.

## Rollback/Contingency

The only irreversible-looking step is Phase 7's live write to `specs/state.json` and
`specs/ROADMAP.md`. Both are git-tracked, and the phase takes a durable checkpoint first
(`bash .claude/scripts/git-snapshot.sh 603 --no-revert`), which preserves the pre-migration tree
without reverting the working tree. If the migration's accounting gate fails, it exits non-zero
**before** writing, so no partial state is produced; if a later step goes wrong, recover the
pre-migration `specs/ROADMAP.md` and `specs/state.json` from that checkpoint rather than from a
reverting snapshot. For a genuine rollback that must discard uncommitted work, follow
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag — never a bare reverting `git-snapshot.sh` as a precaution. Phases 1-6
are all additive or test-covered source-store edits, revertible by ordinary commit-level revert; a
`.claude/` tree left mid-deploy is repaired by re-running `deploy-headless.sh`, since the deployed
tree is a disposable artifact regenerated from the source store.
