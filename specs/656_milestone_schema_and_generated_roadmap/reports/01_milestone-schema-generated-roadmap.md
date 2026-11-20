# Research Report: Task #656

**Task**: 656 - Milestone schema in state.json and a wholly generated ROADMAP.md
**Started**: 2026-11-20T09:18:19Z
**Completed**: 2026-11-20T10:05:00Z
**Effort**: Large implementation (schema + validator + renderer rewrite + migration + lint retarget + 7 test suites + ~12 documentation/caller files)
**Dependencies**: 654 (completed). Downstream: 657 (milestone automation and review gates) builds on this schema; 655 follows 657.
**Sources/Inputs**: - Source store `agent-system/extensions/core/**` (schema, validator, renderer, migration precedent, lint, agent/skill/command files, tests); live `specs/state.json` + `specs/ROADMAP.md` of this repository and of `/home/benjamin/Projects/Sapience/sf1-engine`; `sf1-engine/integration/design.md` section 7; a throwaway prototype render (scratchpad). No web research was needed.
**Artifacts**: - specs/656_milestone_schema_and_generated_roadmap/reports/01_milestone-schema-generated-roadmap.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The prose problem is measured, not anecdotal: `## Next` is 70% of this repository's ROADMAP.md (91,878 of 131,554 bytes) and 67% of sf1-engine's (27,750 of 41,618). Its bulk is `rationale` (62,587 B here, 18,875 B there) plus `roadmap_notes` preamble/postamble (24,421 B here). The `description` field's 100-character bound holds in both corpora (0 of 37 batches over); every unbounded field became a screen of prose.
- A prototype of the proposed three-part layout, rendered read-only from sf1-engine's live state plus a draft M0-M4 overlay, is **127 lines / 5,163 bytes against the live file's 188 lines / 41,618 bytes** (12%), and shows every milestone's status, progress and review state in a five-row table at the top. It also exposed three design defects that the plan must handle (below).
- The 49 existing "milestone" lines (50 occurrences, 22 files) all mean the events-log `category` enum value or the generic word "checkpoint". None is a roadmap concept. Reconcile by naming the new key `roadmap_milestones` (the existing `roadmap_` prefix family), never a bare `milestones` key and never a new `category`.
- Recommended schema: three new top-level keys - `primary_goals`, `roadmap_milestones[]` (ordered; each with `id`, `title`, `aim`, `gate`, `progress`, `review`, `batches[]`), `roadmap_context` (`overview`, `rules`, `conventions`) - with the existing `roadmapBatchEntry` reused unchanged as the nested batch shape. Flat `roadmap_batches` and `roadmap_notes` are retired by the migration.
- Progress counts must be **derived** by the renderer; only what cannot be derived (milestone `status`, closure date, review state) is stored. This requires inverting one existing rule: validate-state Check 13 and the renderer treat a terminal batch member as cruft; under milestones it is progress.
- Review state must be a **stored** field, never fetched by the renderer (`gh` in the render path would break the byte-identical-second-regenerate property that `skill-roadmap` Stage 3 asserts). 657 owns the writer; this task owns only the shape.
- Advisory-lint disposition: **retarget** at the state entries; call site stays `scripts/orchestrate-conclusion-roadmap.sh` (`LINT_SCRIPT`, invoked after the regenerate commit). Evidence: 316 of its 326 live findings here are finding (a), which has no other owner.
- A blocker for the acceptance repo that the description does not name: sf1-engine's `specs/` is gitignored (`.gitignore:30:/specs/`), so `specs/ROADMAP.md` never reaches a collaborator there. The "collaboration dashboard" needs a ruling on output location; recorded as a non-blocking user decision with a recommended default.

## Context & Scope

Researched: what exists today for roadmap generation, what the new schema must hold, how the generated file should be laid out, what to prune, what the migration and its accounting gate must cover, the lint's disposition, and which tests and files outside the declared `file_scope` the change reaches. Constraints honoured: source store is the edit target (deployed `.claude/` is stale for `core` per the dispatch's freshness note - all code reading was done in `agent-system/extensions/core/`); the judgment/rendering split is preserved; no deliverable may carry task numbers or draft-history language.

Not researched: branch topology and the push/review automation (657's Element 1 and Element 2), and the content of a real M0-M4 batch assignment for sf1-engine, which is roadmap-agent judgment at acceptance time. The prototype's overlay is illustrative only.

## Findings

### What exists today (codebase)

**Renderer** (`scripts/roadmap-integration.sh`, 790 lines). Two layouts, both partly hand-authored:
- *classic*: eight literal headers. `## Next` (`render_next()`) and `## Open work` (`render_open_work()`) render from state; the other six are read back out of the existing file by `load_existing_sections()`/`extract_section()` and re-emitted verbatim by `assemble_roadmap()`.
- *stage*: every section retained byte-for-byte except the run-order section.
- Layout classification lives in `scripts/lib/roadmap-preflight-lib.sh` (`detect_layout`: classic/stage/unknown; `roadmap_preflight_classify` adds absent; `roadmap_preflight_scaffold` writes the classic eight-header skeleton). The Destructive-Overwrite Refusal is documented as a permanent property.
- It shells out to `generate-task-order.sh --print` and parses the `**Dependency Waves**:` table (used only by the coverage appendix). This is the only coupling to `generate-task-order.sh`; that script contains zero roadmap references, and `test-generate-task-order.sh` contains zero (`grep -c` = 0 for both `roadmap_batches` and `ROADMAP`). It pins the wave-table format and `active_goal` Goal-line resolution (25 `active_goal` references).

**Schema** (`context/schemas/state-schema.json`): top-level `additionalProperties: false`; roadmap-related keys are top-level `roadmap_batches` (array of `definitions.roadmapBatchEntry`: `task_ids` required/minItems 1, `description` required/maxLength 100, `rationale` optional unbounded, `flags` optional) and `roadmap_notes` (`next_preamble`, `next_postamble`, `open_work_trailer`, all arrays of unbounded strings); per-task `roadmap_annotation`, `roadmap_ext_blocked`, `roadmap_items`. `active_goal` (free prose, read by `generate-task-order.sh`'s `resolve_goal_text()`, written by `/review`) already exists and overlaps the requested `primary_goals`.

**Validator** (`scripts/validate-state.sh`): `KNOWN_TOP_LEVEL_FIELDS` / `KNOWN_ENTRY_FIELDS` are hand-mirrored from the schema, and `test-validate-state.sh`'s drift test (around line 1694) asserts both sets are equal to the schema's property keys in both directions - this is the mechanical form of "schema and validator move as one". Check 13 (WARN-only, `--strict`-promotable) covers `roadmap_batches`: non-empty `task_ids`, every member an existing **non-terminal** `project_number`, no id in two batches, description present and <= 100 chars. Checks 3/4 WARN on unknown top-level/entry fields.

**Readers of the flat batch array** - non-test, non-deprecated scripts, found with `grep -rIl 'roadmap_batches\|roadmap_notes' --include=*.sh` and cross-checked with the differently-shaped `grep -rIl 'task_ids' --include=*.sh` (both return the same four files):
1. `scripts/roadmap-integration.sh` (lines 459, 460, 536, 593, 719, 747)
2. `scripts/validate-state.sh` (Check 13, line 1233)
3. `scripts/orchestrate-suggest-next-batch.sh` (`read_roadmap_batches()`, line 404 - Mode A's primary candidate source for `--next-batch`)
4. `scripts/migrate-roadmap-next-to-state.sh` (lines 93, 423 - the only script that assigns the keys)

Plus `agents/roadmap-agent.md` (instruction text, line 56). The lint reads no state batch field today - it parses the rendered file.

**Judgment/rendering split**: `roadmap-agent` (opus; Read/Write/Edit/Bash) writes entries only through `state-write.sh` and edges only through `update-task-status.sh ... edge_only --depends-on-add`, then calls `--regenerate`; it must never write the file. `skill-roadmap` gates on preflight classify, dispatches the agent, verifies (Check 13 + a dry-run idempotence check that greps `no content change`), and commits exactly `specs/state.json` and `specs/ROADMAP.md`.

**Four live `--regenerate` callers** (`context/patterns/roadmap-update.md`, "Live Callers"): `scripts/orchestrate-conclusion-roadmap.sh`, `roadmap-agent`, `commands/todo.md` Stage 6.6, `commands/review.md` Section 6.8. The last three carry an `AskUserQuestion` approval arm for `absent`/`unknown` and call `roadmap_preflight_scaffold`.

### The "milestone" vocabulary

`grep -rIi milestone agent-system/extensions/core` = 49 lines (the description's figure, re-derived), 50 occurrences by `grep -o`, 22 files. Classified by reading every line:
- **Events-log category** (closed enum `deviation|blocker|milestone|success` in `context/schemas/events-schema.json`, written by `events-append.sh`, `skill-base.sh`, `command-gate-out.sh`, `push-grant-lib.sh`, the two `events-log-*` hooks, pinned by `test-gate-out-repair-reporting.sh`): the large majority.
- **Generic prose** ("commit at every green milestone", "update partial_progress on significant milestones"): `wrap-up.md`, `hard-mode-routing.md`, `convergence.md`, `early-metadata-pattern.md`, `code-patterns.md`, `general-research-agent.md`.
- **A keyword** in `task-type-detect.sh` (`founder:project|...,milestone`).

No existing occurrence names a roadmap unit, so there is nothing to merge with, only a collision to avoid. A bare top-level `milestones` key, or any event emitted with a new category, would create the parallel vocabulary the description forbids.

### Corpus measurements

| Measure | this repository | sf1-engine |
|---|---|---|
| ROADMAP.md size | 1,104 lines / 131,554 B | 188 lines / 41,618 B |
| `## Next` | 91,878 B | 27,750 B |
| `## Open work` | 13,061 B | 9,571 B |
| `## Gate state` | 6,891 B | 34 B ("Not yet measured.") |
| `## Checks ...` | 2,610 B | 789 B |
| `## Settled decisions` | 4,969 B | 1,269 B |
| `## Standing rules` | 1,715 B | 1,534 B |
| `## Unfiled observations` | 9,565 B | 73 B (placeholder) |
| `## Goal` | 509 B | 409 B |
| batches | 30 | 7 |
| `description` over 100 chars / max | 0 / 99 | 0 / 98 |
| `rationale` min / median / max | 540 / 1,437 / 10,800 | 1,834 / 2,577 / 4,567 |
| `roadmap_notes` paragraphs (pre/post/trailer) | 5 / 12 / 0 | 6 / 5 / 8 |
| batch members total / absent from `active_projects` / terminal | 127 / 0 / 6 | 10 / 0 / 0 |
| batches over 8 members | 0 | 0 |
| `roadmap_annotation` count / max length | 11 / 124 | 18 / 119 |
| open tasks / open and in no batch | 122 / 1 | 17 / 7 |
| coverage appendix present in file | no | no |

Reading: the one bounded field stayed bounded; every unbounded one grew to paragraphs. Bounds, not exhortation, are what kept `description` readable.

### Prototype render (sf1-engine, read-only)

Method: the consumer's `specs/state.json` was read unchanged; a separate overlay file held only the proposed new keys, with milestone titles and gate text taken from `integration/design.md` sections 7.1-7.5 and the seven existing batches assigned by index (M1: four, M2: one, M3: two). Files: `/tmp/claude-1000/-home-benjamin--config-nvim/94ae85c2-0054-4d16-8e1a-a056d6d03f03/scratchpad/sf1-milestone-overlay.json`, `.../scratchpad/proto-render.jq`, `.../scratchpad/sf1-ROADMAP-proto.md` (scratch, not durable).

Result: 127 lines / 5,163 bytes. Top of the output:

```
| Milestone | Status | Tasks done | Review |
|---|---|---|---|
| M0: Ground truth and decisions | closed 2026-11-17 | 0/0 | merged |
| M1: The task workflow on OpenCode | active | 0/6 | in_review (PR #34) |
| M2: The extension system | planned | 0/1 | none |
| M3: The extensions in use | planned | 0/3 | none |
| M4: Fit with SF-1 memory | planned | 0/0 | none |
```

and one batch block:

```
**Batch 1** -- Trust the instruments: the D2 limit, the translator trust checks, then the comparison instrument
/orchestrate 36, 38, 40
36 IN FLIGHT  d2_hotpath_one_sided_median_gate
38 blocked:36  translator_trust_checks_census_determinism_perms
40 blocked:38  comparison_instrument_paired_record
```

Does it serve a reviewer? Mostly yes: order, gate text, what is in flight, what is blocked on what, and review state are all visible in the first screen, which the live file does not offer anywhere. Three defects surfaced, each with a design consequence:

1. **Progress reads 0/6 for M1 although work has landed.** Task 34 (completed, "before the M1 gate") is in no batch, because today's rules strip terminal members (the renderer omits them, Check 13 WARNs on them, and roadmap-agent is told to retire such batches). A milestone's done-count is only meaningful if batches keep their completed members while the milestone is open.
2. **A closed milestone with no batches renders "0/0 batches, 0/0 tasks"** - noise. A closed milestone should collapse to one line (title, closure date, review state).
3. **M4 shows 0/0 while its real work is held task 13**, which sits in the unscheduled list. Held tasks must be admissible as batch members so a planned milestone shows its content; that is a roadmap-agent instruction, not a renderer rule.

Also observed: 15 of 18 sf1 tasks have no `title`, so the slug `project_name` is displayed (existing behaviour, `.title // .project_name`); the per-task block inside each batch makes a separate `## Open work` section redundant for every batched task.

### The advisory lint against the live corpus

Deployed copy run read-only in both repositories:
- this repository: `layout=classic authored_run_lines=29 findings=326` - 316 finding (a) (file_scope overlap with an out-of-batch task), 9 finding (f) (unresolved path citation), 1 finding (d) (terminal member).
- sf1-engine: `authored_run_lines=7 findings=0`.

Two facts follow. First, the lint already consumes *generated* text: the Run lines it parses are `render_next()` output, so it validates state at one remove, through a regex over a rendering. The same run of `validate-state.sh` reports 6 Check 13 terminal-member warnings where the lint reports 1 finding (d), because the file on disk lags state - the indirection is measurably lossy. Second, finding (a) is 97% of the output and is the only check anywhere for an under-inclusive batch at authoring time; finding (d) is already owned by Check 13; finding (f) exists almost entirely because of long prose, which the new schema removes.

### Output location under an ignored specs tree

`git check-ignore -v specs/ROADMAP.md` in sf1-engine reports `.gitignore:30:/specs/` - the managed `specs-tree-ignore` block that `init-specs.sh` writes by default (the 658-662 strand, all completed). `git ls-files specs` is empty there. Task 656's own `roadmap_annotation` in this repository's state reads: "specs/ becomes ignored by default above -- rule where the generated review surface then lives". In such a repository `skill-roadmap` Stage 4's commit of `specs/ROADMAP.md` is a skip (exit 8/9), and no collaborator ever sees the file. `roadmap-integration.sh` already accepts `--roadmap PATH`; `scripts/lib/specs-ignore-lib.sh` (`specs_tree_is_gitignored`, `path_is_gitignored`) already answers the posture question. sf1-engine also already has a hand-authored `integration/roadmap.md`, so a tracked output path there must not collide with it.

### Files the change reaches beyond the declared file_scope

`file_scope` is descriptive, but the plan should name these so no phase is surprised [COVERAGE-UNVERIFIED: `grep -rIl 'ROADMAP\.md'` over the core extension (51 files) read selectively by header-vocabulary grep (`Gate state|## Next|Standing rules|Settled decisions|Open work`) / the 51 files were not each read in full, so a consumer that depends on the old layout without naming a header literally may be missed]:

- `scripts/lib/roadmap-preflight-lib.sh` - `CLASSIC_HEADERS`, `detect_layout`, the classic-skeleton scaffolder; needs a `generated` verdict and a scaffold that no longer writes "authored by hand" stubs.
- `scripts/tests/test-lint-roadmap-batch-proposals.sh` and `scripts/tests/test-orchestrate-conclusion-roadmap.sh` - both build classic-layout fixtures; neither is among the five named tests.
- `commands/todo.md` Stage 6.6 and `commands/review.md` Section 6.8 - classify/approve/scaffold/regenerate callers whose prose describes six hand-filled sections; `commands/review.md` line 242 also states the file "is hand-curated prose".
- `context/formats/roadmap-format.md` (Section Order, Authored vs. Generated, Per-Section Ruling - which currently rules `## Gate state` "cannot be generated at all"), `context/formats/roadmap-entry-template.md`, `context/patterns/roadmap-update.md` (including its paragraph leaving the lint's disposition undecided), `context/reference/state-management-schema.md`, `context/contracts/conclusion-stage.md` (Step 5).
- `agents/planner-agent.md` lines 149-152: the `--roadmap` flag mandates a last plan phase "Update ROADMAP.md - mark completed items with `- [x]`", a hand-edit of a file that will be wholly generated.
- `scripts/lib/engine-written-state-paths-lib.sh` line 26 describes `specs/ROADMAP.md` as "user-maintained and read-only for agents; no agent ever writes it" - already inaccurate, fully false after this task.
- `scripts/lib/suite-selection-lib.sh` lines 21/24 and `scripts/tests/run-all.sh` lines 126/127 cite "specs/ROADMAP.md's Settled decision 15" and "Settled decision 13" as an anchor. If that section stops being rendered, the anchor dangles.
- `manifest.json` (script and test lists), `scripts/tests/suite-classification.data`, `index-entries.json` line counts - required for any new script, lib or suite.

## Decisions

Design decisions this research makes, each with its ground; the planner may overturn any with a stated reason.

1. **Key naming: `primary_goals`, `roadmap_milestones`, `roadmap_context`.** `primary_goals` is the name the task description gives. `roadmap_milestones` rather than `milestones` keeps the unqualified word for the events category. `roadmap_context` holds overview/rules/conventions as one object so three more arrays do not sit beside the milestones at top level ("sited so they do not crowd the milestones").
2. **Batches nest; the entry shape is reused.** `roadmap_milestones[].batches[]` items are `$ref: #/definitions/roadmapBatchEntry` unchanged. `description` (<= 100) already is "a statement of what that batch aims to achieve" and holds its bound in 37 of 37 live entries; renaming it would churn four scripts and three test suites for no reader benefit.
3. **`active_goal` is kept, not replaced.** It has a live reader (`resolve_goal_text()`), a live writer (`/review`), and 25 pinning references in `test-generate-task-order.sh`. The renderer uses `primary_goals` and falls back to `[active_goal]` when `primary_goals` is absent; the migration seeds `primary_goals` from the `## Goal` section. Consequence for the five named tests: `test-generate-task-order.sh` should need no edit unless the plan changes `generate-task-order.sh` itself, and this research found no reason to.
4. **Progress: store the decision, derive the counts.** Stored `progress` = `{status: planned|active|closed, closed?: YYYY-MM-DD, note?: bounded}`. Batch and task done-counts are computed at render time from member statuses. A stored count would need a validator equality check to stay honest and would be wrong between a task completing and the next writer running.
5. **Completed members stay in their batch while the milestone is open.** Renderer: a member that is terminal in `active_projects`, or present in `specs/archive/state.json`'s `completed_projects`, counts as done and is left off the `/orchestrate` line; a batch with no open member renders as done. Check 13's terminal-member sub-condition is scoped to *abandoned/expanded* members and to *closed* milestones; a member resolvable in neither file remains a WARN.
6. **Review state is stored, never fetched.** `review` = `{state: none|prepared|in_review|changes_requested|approved|merged, ref?, request?, updated?}`. `ref` and `request` are free strings (branch name; PR/MR identifier or URL) so the shape does not prejudge 657's branch-topology ruling. This task ships the field, its validation and its rendering; it ships no writer beyond roadmap-agent's ordinary `state-write.sh` path.
7. **`rationale` stays in the schema and is no longer rendered.** It is the agent's own continuity note between passes. Bounding it was tested against the corpus and rejected: at a 600-character bound, 28 of 30 entries here and 7 of 7 in sf1-engine would be in violation on day one.
8. **`roadmap_notes` is retired.** Its three arrays are unrendered under the new layout and have no other reader; an unrendered, unbounded prose field with no reader is the failure mode this task exists to remove. The migration moves the text to a retained-prose file and deletes the key.
9. **Lint disposition: retarget** (detail under Recommendations).
10. **A generated sentinel replaces header-vocabulary classification.** The file's first line is a fixed HTML comment. `detect_layout` gains `generated`. `--regenerate` overwrites only `generated` (or writes onto `absent` when `roadmap_milestones` is non-empty); on `classic`/`stage`/`unknown` it refuses and names the migration script. The Destructive-Overwrite Refusal stays a permanent property; only its predicate changes from "eight headers present" to "sentinel present".
11. **Output location (surfaced as a non-blocking user decision).** Default stays `specs/ROADMAP.md`. Add an optional `roadmap_context.output_path` (repository-relative) that the renderer honours when `--roadmap` is not given, so a repository whose `specs/` tree is ignored can publish the dashboard at a tracked path (for example `docs/ROADMAP.md`) without the engine guessing one. The renderer exercises no judgment here: it reads a stored path. The alternative - leave the file in `specs/` everywhere - keeps the dashboard private to one working copy in every repository `init-specs.sh` now sets up by default, which contradicts its stated purpose. The reason this is put to the user rather than simply decided: a tracked roadmap publishes local task numbers and batch descriptions to collaborators, and sf1-engine already tracks a hand-authored `integration/roadmap.md`; whether to publish, and where, is the repository owner's call. Proceeding on the recommended default costs one optional schema field if the user disagrees.

## Recommendations

### 1. Schema additions (schema and validator in one commit)

```json
"primary_goals":      { "type": "array", "items": { "type": "string", "maxLength": 500 } },
"roadmap_milestones": { "type": "array", "items": { "$ref": "#/definitions/roadmapMilestoneEntry" } },
"roadmap_context":    { "type": "object", "additionalProperties": false, "properties": {
    "overview":    { "type": "array", "items": { "type": "string", "maxLength": 300 } },
    "rules":       { "type": "array", "items": { "type": "string", "maxLength": 300 } },
    "conventions": { "type": "array", "items": { "type": "string", "maxLength": 300 } } } }

"roadmapMilestoneEntry": { "type": "object", "additionalProperties": false,
  "required": ["id", "title", "aim", "progress", "batches"],
  "properties": {
    "id":    { "type": "string", "pattern": "^[A-Za-z0-9][A-Za-z0-9._-]{0,15}$" },
    "title": { "type": "string", "maxLength": 80 },
    "aim":   { "type": "string", "maxLength": 300 },
    "gate":  { "type": "string", "maxLength": 400 },
    "progress": { "type": "object", "additionalProperties": false, "required": ["status"],
      "properties": { "status": { "enum": ["planned", "active", "closed"] },
                      "closed": { "type": "string" }, "note": { "type": "string", "maxLength": 140 } } },
    "review": { "type": "object", "additionalProperties": false, "required": ["state"],
      "properties": { "state": { "enum": ["none", "prepared", "in_review", "changes_requested", "approved", "merged"] },
                      "ref": { "type": "string" }, "request": { "type": "string" }, "updated": { "type": "string" } } },
    "batches": { "type": "array", "items": { "$ref": "#/definitions/roadmapBatchEntry" } } } }
```

Array position is milestone order (same rule as batches today - no priority field). Remove `roadmap_batches` and `roadmap_notes` from the schema and from `KNOWN_TOP_LEVEL_FIELDS`; add the three new keys to both. Add `maxLength: 140` to `roadmap_annotation` (corpus: max 124 here, 119 in sf1-engine; 0 of 29 annotations violate).

The bounds were run against the existing text each field would absorb:

| Field (bound) | Corpus | Result |
|---|---|---|
| `gate` (400) | the five `**Gate M0-M4:**` paragraphs of sf1-engine `integration/design.md` 7.1-7.5 | 135, 393, 169, 156, 176 characters including the label - 0 of 5 over |
| `primary_goals` item (500) | `## Goal` paragraphs: two here (max 254), one in sf1-engine (about 400) | 0 of 3 over. A 200 bound was tried first and fails 2 of 3, which is why the bound is 500 |
| `rules` item (300) | sf1-engine's ten numbered standing rules | 61-248 characters - 0 of 10 over |
| `conventions` item (300) | this repository's 20 numbered settled decisions | **7 of 20 over** (max 657) |
| `roadmap_annotation` (140) | 29 annotations across both stores | 0 over (max 124) |

The `conventions` result is the one that bites: seven of this repository's settled decisions do not fit, and by the migration rule in Recommendation 6 they go whole to the retained-prose file with a WARN each. That is the intended pressure (a ruling that needs 650 characters belongs in a `specs/decisions/` record with a one-line pointer here), but it means this repository's migration is not finished until those seven are rewritten by hand or by a `/roadmap` pass. This repository's `## Checks` (2,610 B) and `## Standing rules` (1,715 B) sections are hard-wrapped multi-line items and were measured only as whole sections [CORPUS-UNVERIFIED: this repository's `## Checks before and after every call` and `## Standing rules` list items / per-item length against the 300-character bound, which needs the migration's own item splitter to measure].

### 2. Validator: extend Check 13 in place (keep its number and WARN-only posture)

Iterate `roadmap_milestones[].batches[]` and report with a `roadmap_milestones[i].batches[j]` path prefix. Sub-conditions: (a) existing ones for `task_ids`/`description`, with terminal-member handling changed per Decision 5; (b) no task id in two batches across all milestones; (c) milestone `id` unique, `title`/`aim` non-empty and within bounds; (d) `progress.status == "closed"` iff `progress.closed` present (no ordering constraint between milestone statuses: sf1-engine's M4 may run beside M2 and M3 by design); (e) a named WARN when flat `roadmap_batches`/`roadmap_notes` is present, pointing at the migration script by name (rather than the generic Check 3 "unknown field" text, which points at `migrate-state-legacy-fields.sh`). `test-validate-state.sh`: rewrite the six Check 13 fixtures (lines 507-652) to the nested shape, extend the field-drift fixture, and let the existing schema/validator drift test prove the pair moved together.

### 3. One accessor for "the ordered flat batch list"

Add a small sourced lib (suggested `scripts/lib/roadmap-entries-lib.sh`) exporting one jq definition: batches of non-closed milestones in milestone-then-batch order, falling back to `.roadmap_batches // []` when `roadmap_milestones` is absent. Consumers: `orchestrate-suggest-next-batch.sh`'s `read_roadmap_batches()`, Check 13, the retargeted lint, the renderer. The fallback matters: `--next-batch` is a dispatch-selection surface, and a store that has not been migrated must keep suggesting from its authored batches rather than silently dropping to the mechanical fallback. `test-orchestrate-suggest-next-batch.sh` (19 `roadmap_batches` references): keep one flat-shape fixture as the fallback case, convert the rest, add a closed-milestone-is-skipped case.

### 4. Renderer: whole-file render, three parts, in this order

```
<!-- generated by roadmap-integration.sh from specs/state.json; do not edit -->
# Roadmap
- {primary_goals...}
| Milestone | Status | Tasks done | Review |      <- links to each milestone section
See also: [Rules, conventions and repo context](#...)

## {id}: {title}                                  <- one per milestone, array order
{aim}
- **Progress**: {status} -- {b_done}/{b} batches, {t_done}/{t} tasks done
- **Review**: {state} on `{ref}`, {request} ({updated})
- **Gate**: {gate}
**Batch N** -- {description}
/orchestrate {open members} {flags}
{id} {status token}  {title}   <- {roadmap_annotation}

## Rules, conventions and repo context            <- last
```

Rules: a closed milestone collapses to its heading plus one line; `status_token()` and `token_rank()` are reused unchanged; the unscheduled-open-tasks list (open tasks in no batch) goes at the end of the last section. Delete `load_existing_sections`, `extract_section`, `extract_preamble`, `assemble_roadmap`, the whole stage round-trip (`split_sections`, `assemble_stage_roadmap`, `mode_regenerate_stage`), `render_next`'s preamble/rationale/postamble arms and `open_work_trailer_from_notes`. Keep `--print`, `--regenerate`, `--dry-run`, the deprecated `--prune` alias, the six-field stderr marker (redefine `runs=` as open-milestone batch count, `retained=` as 0) and the `OUTCOME:` line - `orchestrate-conclusion-roadmap.sh` greps `^OUTCOME:` and `skill-roadmap` greps `no content change`. Anchor ids must come from the stored `id`, not the title, so a retitle does not break the intro links.

`test-roadmap-generation.sh` (1,289 lines): Case group 1 (token derivation) survives with new expected framing; groups 2 (retention), 4 (layout refusal), the two stage-layout groups, and the scaffold group are rewritten against the sentinel model; group 6 (render from batches) becomes the milestone-nesting group. Its live-tree isolation guard should be kept - this repository's own Gate state records that suite false-failing when the live file was being rewritten.

### 5. Pruning ledger (the named deliverable)

| Emitted today | Reader found | Disposition |
|---|---|---|
| Italic preamble ("Forward-only ... Last measured") | none; the date is hand-kept and stale | **Drop**; replaced by the one-line sentinel |
| `## Goal` | humans; `generate-task-order.sh` reads the state field, not the section | **Keep**, as the intro's `primary_goals` bullets |
| `## Gate state` | none mechanical; 6,891 B of dated measurements here, a 17-character placeholder in sf1-engine | **Drop the section.** A measurement belongs to the run that produced it. The milestone `gate` field carries the *criterion*, which is what a reviewer needs |
| `## Next` preamble / postamble (`roadmap_notes`) | none | **Drop** rendering and the field |
| `## Next` fence of `/orchestrate` lines | humans; `--next-batch` reads the state entries | **Keep**, regrouped under milestones, one block per batch |
| `## Next` "Why this order:" (`rationale`) | roadmap-agent's next pass, from state | **Drop from the file**; keep the state field |
| Coverage appendix | absent from both live files | **Drop**; superseded by the unscheduled list, which also removes the renderer's only dependency on parsing `generate-task-order.sh --print` |
| `## Open work` topic blocks | humans; duplicates `specs/TODO.md` | **Drop as a section**; each batch lists its members with the same status tokens; only tasks in no batch keep a list |
| `## Open work` trailer | none | **Drop** |
| `## Checks before and after every call` | humans (occasionally) | **Keep as bounded `conventions` items** in the last section |
| `## Settled decisions` | two code comments cite decisions 13 and 15 by number | **Keep as bounded `conventions` items**, each ideally one line pointing at a `specs/decisions/` record; re-anchor the two code comments to a durable file before the numbered list goes away |
| `## Standing rules` | humans | **Keep as bounded `rules` items** in the last section |
| `## Unfiled observations` | none; by its own title nothing in it is worth a task | **Drop** |

### 6. Migration (new script; `migrate-roadmap-next-to-state.sh` is the structural precedent)

Suggested name `scripts/migrate-roadmap-to-milestones.sh`, same flag set (`--dry-run`, `--force`, `--roadmap`, `--state`, `--session-id`), writes through `state-write.sh`, refuses when `roadmap_milestones` is already non-empty without `--force`.

- **Mechanical only.** It wraps every existing flat batch, in order and unchanged, into one milestone (`id: "M1"`, `title: "Current work"`, `progress.status: "active"`, `review.state: "none"`, `aim` a fixed neutral sentence). Dividing work into real milestones is roadmap-agent judgment performed afterwards by `/roadmap "<instruction>"`; a migration that invented milestone boundaries would collapse the split the description says to preserve.
- **State moves**: `roadmap_batches` -> the single milestone's `batches`; `## Goal` paragraphs -> `primary_goals` (split on blank lines); `## Standing rules` list items -> `roadmap_context.rules`; `## Checks` and `## Settled decisions` list items -> `roadmap_context.conventions`. An item over its bound is not truncated: it goes to the retained-prose file whole and a one-line WARN names it.
- **Retained-prose file**: everything not given a state field (`## Gate state`, `## Unfiled observations`, the preamble, all three `roadmap_notes` arrays, over-bound items) is written verbatim, under its original header, to one file such as `specs/archive/roadmap-retained-prose-{DATE}.md`. Nothing is deleted from the world; it is removed from the rendered surface.
- **Losslessness gate (hard, before any write)**: every non-blank line of the existing ROADMAP.md outside generated regions, and every string in `roadmap_notes`, must be found, trimmed, in exactly one destination - a state field or the retained-prose file. Batch accounting is structural: batch count, per-batch `task_ids`, `description`, `rationale`, `flags` are byte-equal before and after (`jq -S` comparison of the flat array against the flattened nested one). Any unaccounted line is named and the script exits non-zero.
- **Stage layout**: the same rule covers it - every section that is not the run-order section goes to the retained-prose file. Which consumer repositories still carry a stage-layout file was not measured.
- The old script and `test-migrate-roadmap-next-to-state.sh` should stay runnable for stores that never ran the first migration (a hand-authored `## Next` with empty `roadmap_batches`): chain it - new script detects that condition and names the old one as the prerequisite. The named test then needs only its classic-fixture expectations checked against whatever `roadmap-preflight-lib.sh` changes; add a new suite for the new script (manifest + `suite-classification.data` rows).

### 7. Lint disposition: retarget, call site unchanged

Record: **`scripts/lint/lint-roadmap-batch-proposals.sh` is retargeted at `specs/state.json`'s `roadmap_milestones[].batches[]` entries. Its call site remains `scripts/orchestrate-conclusion-roadmap.sh` (the `LINT_SCRIPT` variable; the `bash "$LINT_SCRIPT"` invocation inside the regenerate arm, after the scoped commit), documented in `context/contracts/conclusion-stage.md` Step 5.**

- Remove the parse layer: `RUN_LINE_RE`, the `## Next` / section scan, the fence walker, the `detect_layout` sniff and the `--roadmap` flag. Read batches through the accessor in Recommendation 3.
- Keep finding (a) (out-of-batch file_scope overlap) and finding (c) (more than `MAX_TASKS` members). Drop finding (d): Check 13 owns it. Narrow finding (f) from the whole file to the bounded string fields of the roadmap entries.
- Keep the advisory contract (exit 0 with findings; no proposer behaviour). Location labels change from `[Run line N]` to `[milestone ID batch N]`.
- The conclusion script's arm condition changes from `classic|stage` to `generated`; since the lint no longer needs the file, it can also run on the degrade arm.
- Why not retire: finding (a) has 316 live instances here and no other authoring-time owner. Why not leave as is: its `## Next` anchor will not exist, so it would print one "unknown layout" line per `/orchestrate` run forever - the outcome the description rules out.
- Worth a separate decision by the lint's owner, not made here: 316 one-line findings in every conclusion block is itself unread output; a per-batch count with `--verbose` for detail would fit this task's pruning aim.

### 8. Agent, skill and caller text

`roadmap-agent.md`: add milestone decisions (which milestones exist, order, `aim`, `gate`, which batches sit under which, `progress.status` transitions and closure) to "Deciding Batches"; state that completed members are left in place while a milestone is open; state that `rationale` is a working note and is not rendered; state that `review` is written only on a human's or 657's instruction, never inferred; remove the `roadmap_notes` paragraph. Its Write Contract is unchanged. `skill-roadmap/SKILL.md`: Stage 1's verdict set becomes `generated` (proceed) / `absent` (proceed when milestones exist) / `classic|stage|unknown` (offer the migration, with its dry-run accounting shown, behind the existing single `AskUserQuestion`). The remaining callers and documents listed under "Files the change reaches" need matching edits.

### 9. Phasing suggestion for the planner

(1) schema + validator + drift test; (2) accessor lib + `--next-batch` + its test; (3) preflight lib sentinel + renderer + generation test; (4) migration + its test; (5) lint retarget + its test + conclusion script and its test; (6) agent/skill/command/format documentation; (7) redeploy, migrate this repository, run `/roadmap`, then the sf1-engine acceptance render. Phases 1-2 are independently green; 3-5 share `roadmap-preflight-lib.sh` and are best declared one atomic batch or strictly ordered.

## Risks & Mitigations

- **Unmigrated consumer stores.** After redeploy, a store with flat batches meets a renderer that refuses its classic file. Mitigation: the refusal names the migration command; `--next-batch` keeps working through the accessor fallback; the conclusion step's existing loud-degrade arm (event + issue record) already handles "cannot regenerate here".
- **Vault renumbering.** No script rewrites batch `task_ids` when task numbers are renumbered (among non-test scripts only the migration assigns the batch keys; `orchestrate-suggest-next-batch.sh` line 377 already documents stale members "left behind by vault renumbering"). Keeping completed members longer, per Decision 5, widens that existing exposure: a reused number could make a done member look open. Mitigation: have roadmap-agent drop done members when it closes a milestone, so only open milestones carry them, and record the residual in `state-management-schema.md`. A mechanical fix belongs to the vault operation, not to this task.
- **Review state going stale.** A stored `review.state` is only as fresh as its last writer. Mitigation: render `updated` beside it, so staleness is visible; 657 owns freshness.
- **Scope.** Roughly a dozen files outside the declared `file_scope` are reached. Mitigation: name them in the plan's territory up front; `scripts/lib/roadmap-preflight-lib.sh` and the two extra test suites are not optional.
- **Deployed tree is stale for `core`.** Every script here sources `deploy-root-guard.sh` and is not runnable from the source store; redeploy (`timeout 540 bash .claude/scripts/deploy-headless.sh`) before any test phase, and again before the acceptance render.
- **The acceptance judgment is subjective.** "Serves a reviewer" has no mechanical test. Mitigation: the prototype in this report gives a concrete before/after (41,618 B -> about 5 KB; five-row status table first) to judge the real render against.

## Context Extension Recommendations

none (meta task).

## Appendix

**Search patterns used** (all rooted at `agent-system/extensions/core/`):
- `grep -rIic milestone .` (per-file line counts, summed to 49); cross-check `grep -rIio milestone . | wc -l` = 50 occurrences, `grep -rIli` = 22 files.
- `grep -rIl 'roadmap_batches\|roadmap_notes' .` (20 files); `--include=*.sh` minus tests/deprecated (4 files); cross-check `grep -rIl 'task_ids' --include=*.sh` (same 4 files).
- `grep -rIn 'lint-roadmap-batch-proposals' .` (call sites: one executable caller, `scripts/orchestrate-conclusion-roadmap.sh`).
- `grep -rIl 'ROADMAP\.md' .` (51 files).
- Corpus figures: `awk` per-`## `-section byte counts over both ROADMAP.md files; `jq` length statistics over both `specs/state.json` files (commands reproducible from the table's row labels).

**Live runs**: deployed `lint-roadmap-batch-proposals.sh` in both repositories (read-only, exit 0); deployed `validate-state.sh specs/state.json` here (6 Check 13 lines).

**Key files read**: `scripts/roadmap-integration.sh` (whole), `scripts/lib/roadmap-preflight-lib.sh`, `scripts/validate-state.sh` (header, Checks 3/4/13), `context/schemas/state-schema.json` (roadmap portions), `scripts/orchestrate-conclusion-roadmap.sh`, `scripts/lint/lint-roadmap-batch-proposals.sh` (header + parse layer outline), `scripts/migrate-roadmap-next-to-state.sh` (header), `agents/roadmap-agent.md` (whole), `skills/skill-roadmap/SKILL.md` (Stages 1, 3, 4), `context/formats/roadmap-format.md` (Authored vs. Generated, Per-Section Ruling), `context/formats/roadmap-entry-template.md`, `context/patterns/roadmap-update.md` (Live Callers), `sf1-engine/integration/design.md` section 7, both live ROADMAP.md files.

**Issue log**: one entry recorded this dispatch (a scratch prototype fixture tripped the state-write backstop hook's text scan; the prototype was restructured to read state read-only and keep new keys in a separate overlay, so no state-shaped file was written).
