# Research Report: Task #271

**Task**: 271 - finish_parent_task_edge
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: 3-5 hours (schema + docs + two validator checks + two renderer decisions + a renumber-survival ruling)
**Dependencies**: None (the footprint-serialization edge on task 269, over `scripts/validate-state.sh`, is explicitly droppable per the dispatch's standing convention if 269 stalls)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/`), `specs/TODO.md`/`specs/state.json` (this repo only)
**Artifacts**: - `specs/271_finish_parent_task_edge/reports/01_parent-task-edge-contract.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's producer/consumer inventory is substantially correct but over-counts
  producers: only **two** call sites actually write the persisted `active_projects[].parent_task`
  field (`skills/skill-spawn/SKILL.md:380` and `context/patterns/task-review-mode.md:270` — the
  latter supersedes the dispatch's `commands/task.md:833` citation, which does not exist in the
  current 282-line `commands/task.md`). The other three cited sites (`commands/spawn.md:117`,
  `agents/spawn-agent.md:176,195`, `context/orchestration/delegation.md:657,673`) are prose or
  staging-JSON/ephemeral-return-metadata references to a same-named but structurally distinct
  concept, not writers of the schema field.
- All four named consumers verified at **zero occurrences**: `context/schemas/state-schema.json`,
  `scripts/validate-state.sh`, `scripts/generate-todo.sh`, `context/reference/state-management-schema.md`.
  `scripts/generate-task-order.sh`'s 10 "parent" hits are confirmed to be entirely union-find
  (`cc_parent`/`cc_find`/`cc_union`, an unrelated connected-components helper) plus two
  **dependency**-display strings ("indented = depends on parent") — none reads `parent_task`.
- The renumber-survival question (work item 4) resolves cleanly: `scripts/deprecated/vault-operation.sh`
  is **confirmed dead** by its own `scripts/deprecated/README.md` entry (zero live callers,
  explicit reactivation hazard: unmutexed `state.json` writes). The **live** renumbering path is
  `commands/todo.md` Step 5.7.7 ("Renumber tasks > 1000"), whose 5-item checklist updates
  `project_number`, artifact paths, **`dependencies` arrays**, directory renames, and TODO.md
  entries — with no step for `parent_task`. This is the real target if renumber survival is to be
  fixed; the deprecated script must not be reactivated.
- The renderer quirk ("parenttask") is mechanistically confirmed: `generate-task-order.sh`'s
  `build_graph()` jq pipeline applies `gsub("_"; "")` to `.title // .description // .project_name`
  as a blanket markdown-emphasis-stripping step, deleting (not escaping) every underscore in the
  source string before truncation. Any title/description/slug containing the literal substring
  `parent_task` loses both underscores. This is a general bug (any underscore pair is affected),
  not something unique to this field, and is independently fixable from work item 3's rendering
  decision.
- `validate-state.sh` already has a fully established, textually consistent advisory-first /
  `--strict` / PROMOTION CRITERION idiom (Check D3's dependency-graph integrity checks are the
  structural template); the dispatch's `plan-format.md:259-266` citation is stale — the live
  anchor is plan-format.md's `### Enforcement level` subsection (now ~line 328), which
  `validate-state.sh`'s own header comments already cite by name.
- Recommended approach: declare `parent_task` as an optional scalar integer sibling of
  `dependencies` in `state-schema.json` and `state-management-schema.md` (mirroring the existing
  `dependencies`/`file_scope` field-section template); add scalar-specific (not Kahn's-algorithm)
  orphan/self-reference/cycle checks to `validate-state.sh` Check D3's neighborhood, advisory-first
  with a written promotion criterion; render parentage as a per-task TODO.md line rather than in
  the Task Order tree's indentation (which is pre-committed to dependency semantics); and rule
  renumber survival by fixing `commands/todo.md` Step 5.7.7's prose, not the dead script.

## Context & Scope

Researched the full state of the `parent_task` state.json field across the source store
(`agent-system/extensions/core/`, the edit target per `rules/source-store-deploy-boundary.md` —
**no edits were made in this research phase**): every producer and consumer location the dispatch
named, the dependency-validation and cycle-detection pattern already established for the sibling
`dependencies[]` edge, the advisory-first/`--strict` enforcement idiom, the renumbering code path
(live vs. deprecated), and the renderer defect. The BimodalLogic consumer-repo population evidence
cited in the dispatch (six active `parent_task: 165` entries) was taken as given, read-only,
per the dispatch's own instruction — it is a separate repository and not re-verified or edited
here.

## Findings

### Codebase Patterns

**Producers (verified)**:
- `skills/skill-spawn/SKILL.md:380` — writes `"parent_task": $parent` via `state-write.sh` when
  spawn creates new tasks from a blocked parent. `$parent` is `$task_number`, a bare integer.
- `context/patterns/task-review-mode.md:270` — writes `"parent_task": '{parent_N}'` via
  `state-write.sh` when `/task --review` creates follow-up tasks from incomplete plan phases.
  This is the real site behind the dispatch's `commands/task.md:833` citation (that line does not
  exist in the present 282-line `commands/task.md`; the Review Mode machinery is implemented in
  `task-review-mode.md` and invoked from `task.md`'s Review Mode section).
- Both sites write a bare, non-null integer; no current writer ever sets `parent_task: null` or an
  array.

**Not producers, despite dispatch phrasing** (same string, different concept):
- `commands/spawn.md:117` — prose summary of what `skill-spawn` does ("Update state.json with new
  tasks (including parent_task and dependencies)"); not itself a write site.
- `agents/spawn-agent.md:176,195` — `parent_task_number` in the agent's **proposed-task staging
  JSON** (the `new_tasks`/`parent_task_number` object spawn-agent returns to the skill, before
  `skill-spawn` renames it to `parent_task` at the actual `state-write.sh` call). Same concept,
  different field name, pre-persistence.
- `context/orchestration/delegation.md:657,673` — `"parent_task": "{N}"` inside an **ephemeral
  subagent-return `metadata` object** for an unrelated "divide task" operation. This is
  operational return metadata (like `session_id`, `subtasks`), never written to
  `active_projects[].parent_task`. Treating this as a fourth producer would be a scope error.

**Consumers (verified zero, as the dispatch claimed)**:
- `context/schemas/state-schema.json` — `definitions.projectEntry.properties` has no
  `parent_task` key; `dependencies` sits at the same level (`~line 320`) as `"type": "array",
  "items": {"type": "integer"}` — the sibling slot `parent_task` should occupy as a scalar.
- `scripts/validate-state.sh` — 0 hits. Check D3 (`~lines 812-899`) implements the exact
  precedent pattern to follow for `dependencies`: self-reference check, dangling-reference check
  (against a `known_pnums_file` built from `active_projects` ∪ archive's terminal arrays), and a
  Kahn's-algorithm cycle sweep over the dependency adjacency built from one `jq` TSV pass. Because
  `parent_task` is a **single scalar**, not an array, the analogous checks are simpler: orphan =
  value absent from the same `known_pnums_file` technique; self-reference =
  `parent_task == project_number`; cycle = walk the single-parent chain with a seen-set (a forest
  of single-parent pointers only cycles if walking up from X ever revisits X — no general Kahn
  sweep is needed, though one would also work).
- `scripts/generate-todo.sh` — 0 hits; `parent_task` is currently invisible in TODO.md.
- `context/reference/state-management-schema.md` — 0 hits. The file's `### Dependencies Field`
  (line 296) and `### File Scope Field` (line 315) sections are the exact template to mirror: a
  one-row field table, a "Validation" bullet list, and (for `file_scope`) a contrast note against
  a related concept. A new `### Parent Task Field` section should state explicitly that
  `parent_task` is **not** a dependency edge (per work item 1) while still getting its own
  orphan/cycle checks (unlike `file_scope`, which is documented as having *no* graph checks at
  all — don't copy that line verbatim).
- `scripts/generate-task-order.sh` — the dispatch's "not a consumer despite appearances" call is
  confirmed exactly: all 10 "parent" hits are `cc_parent`/`cc_find`/`cc_union` (union-find
  connected-components helper, `~lines 459-479`) or the two display strings "(indented = depends
  on parent)" at `generate_grouped_section()` (`~line 505`) and `generate_dependency_tree()`
  (`~line 880`). Both display strings mean the **dependency**-graph parent (via indentation
  depth), a different relation from `parent_task`. Any new parentage rendering must not reuse
  "parent" unqualified in that context.

**Renumbering (work item 4) — resolved**:
- `scripts/deprecated/vault-operation.sh` is quarantined. Its own
  `scripts/deprecated/README.md` entry states it has "zero live callers," was superseded by
  `commands/todo.md` Steps 5.7-5.8 (now the **authoritative** implementation), and carries an
  explicit "Reactivation hazard" note: its `state.json` writes never went through the mutex-safe
  `state-write.sh --state-file` path, it used a fixed temp-path vulnerable to concurrent-write
  collision, and it lacks the renumbering logic the prose path now performs. **Reactivating it is
  the wrong move regardless of this task's ruling.**
- The live renumbering path is `commands/todo.md` **Step 5.7.7** ("Renumber tasks > 1000"), a
  5-item checklist: (1) subtract 1000 from `project_number`, (2) update artifact paths, (3)
  **update dependencies arrays**, (4) rename task directories, (5) update TODO.md entries. There
  is no step 6 for `parent_task`. If renumber survival is to be fixed, the edit target is this
  prose checklist (add a step mirroring (3) but rewriting the scalar `parent_task` value instead
  of an array), not the dead script.

**Renderer quirk (work item 3's "fold in") — root cause confirmed**:
- `scripts/generate-task-order.sh`'s `build_graph()` (`~lines 184-230`) computes the display
  string for each task's title/description/slug via a jq pipeline that, among other
  markup-stripping steps, applies `gsub("_"; "")` — **deleting**, not escaping, every underscore —
  before word-boundary truncation (`wb_truncate(65)`). This is a blanket
  markdown-emphasis-escape step (alongside stripping backtick/asterisk/open-bracket), not
  something written with `parent_task` specifically in mind. Any title/description/project_name
  containing a literal underscore pair — including this very task's own slug,
  `271_finish_parent_task_edge` — loses both underscores in the rendered tree, producing
  "parenttask" wherever that substring occurs. Confirmed no fenced code blocks (` ``` `) wrap this
  script's output, so an escape-rather-than-delete fix (`gsub("_"; "\\_")`) would render correctly
  in a markdown viewer without reintroducing the italics hazard the original `gsub` was guarding
  against. This bug class is independent of whatever work item 3 decides about *where* parentage
  is rendered — it affects any underscored title, not just parent_task-labeled text.

**Advisory-first enforcement idiom (work item 2's contract) — already fully established**:
- `validate-state.sh` has `STRICT_MODE` (default `false`), a `--strict` CLI flag, and
  `log_pass`/`log_fail`/`log_warn` counters (`PASSED`/`FAILED`/`WARNINGS`); under `--strict`,
  `WARNINGS` joins `FAILED` in the exit-blocking total (confirmed at `~lines 1006-1019`). Multiple
  existing checks (Check 3's unknown-top-level-field, Check 10, others) already carry a
  `# PROMOTION CRITERION (advisory-first, per plan-format.md's "Enforcement level" subsection ...)`
  comment stating the measurable bar that would later promote a WARN to FAIL. The dispatch's
  `plan-format.md:259-266` citation is **stale** — that range is now the `## Verification Tiers`
  prose; the actual precedent is the `### Enforcement level` subsection, now at `~line 328`,
  which is exactly what `validate-state.sh`'s own comments already cite by name. New
  orphan/cyclic-parentage checks should follow this identical idiom (WARN by default, `--strict`
  promotes, a PROMOTION CRITERION comment written in the same commit).

### External Resources

Not applicable — this is an internal agent-system schema/validator/renderer task with no external
library or API surface; all research was codebase-internal.

## Recommendations

1. **Schema** (`context/schemas/state-schema.json`): add `parent_task` as a sibling property of
   `dependencies` in `definitions.projectEntry.properties` (~line 320), `"type": "integer"`,
   optional (absent by default, never written as `null` — mirror the `topic`/`priority`
   delete-not-null convention already used by `state-write.sh` callers:
   `if .topic == null then del(.topic) else . end`). Description text should state explicitly that
   it is a lineage pointer, not a dependency edge, and must never affect dispatch eligibility or
   the Kahn-algorithm dependency waves (per work item 1's instruction).
2. **Documentation** (`context/reference/state-management-schema.md`): add a `### Parent Task
   Field` section mirroring `### Dependencies Field`/`### File Scope Field` in shape (field table +
   Validation bullets), explicitly contrasting with `dependencies` (lineage vs. ordering) and
   stating that it *does* get its own orphan/cycle checks (unlike `file_scope`'s "no checks at
   all").
3. **Validator** (`scripts/validate-state.sh`): add scalar-specific orphan/self-reference/cycle
   checks adjacent to Check D3, reusing its `known_pnums_file` technique for the orphan check and
   a simple seen-set chain-walk for the cycle check (not a full Kahn sweep — unnecessary for a
   single-parent-pointer forest). WARN by default; `--strict` promotes; write a PROMOTION
   CRITERION comment in the same commit per the already-established idiom.
4. **Rendering** (work item 3): render parentage as a per-task TODO.md line (e.g.
   `- **Parent**: Task #{N}`, consistent with how `dependencies` already renders per
   `state-management-schema.md`'s Format Conversion table) rather than inside the Task Order
   tree's indentation, which is already committed to meaning "depends on" via both
   `generate_grouped_section()` and `generate_dependency_tree()`'s identical header strings.
   Independently fix `build_graph()`'s `gsub("_"; "")` to escape (`\\_`) rather than delete, since
   this is a general display bug, not scoped to parentage.
5. **Renumbering** (work item 4): rule that `scripts/deprecated/vault-operation.sh` stays
   quarantined (do not reactivate — its own README documents an unmutexed-write hazard). If
   renumber survival for `parent_task` is in scope, add a step to `commands/todo.md`'s live Step
   5.7.7 checklist (sibling to its existing "update dependencies arrays" step) that rewrites the
   scalar `parent_task` value the same way; if out of scope for this task, record in writing that
   parentage stability currently rests on task numbers never being rewritten (satisfies the
   dispatch's "answered either way in writing" acceptance bar).
6. Follow the sibling BimodalLogic-owning task's per-field widen/migrate/retire policy for how
   `parent_task` is declared, per the dispatch's RELATED note — that task could not be located in
   this repo's `TODO.md`/`state.json` (expected: the dispatch states it lives in the consumer
   repo, not here), so the plan phase should treat the dispatch's own policy description
   (no non-null value deleted without recording where the information went) as the operative
   constraint rather than re-deriving it from a task file.

## Decisions

- Treated `context/patterns/task-review-mode.md:270` as the second real producer in place of the
  dispatch's `commands/task.md:833` (which does not exist in the current file) — a correction, not
  a contradiction, of the dispatch's intent (`/task --review` follow-up creation).
- Excluded `commands/spawn.md:117`, `agents/spawn-agent.md:176,195`, and
  `context/orchestration/delegation.md:657,673` from the producer count: verified each is prose,
  pre-persistence staging JSON, or unrelated ephemeral return metadata, not a `state.json` write
  site.
- Ruled `scripts/deprecated/vault-operation.sh` out of scope for any renumber-survival fix;
  identified `commands/todo.md` Step 5.7.7 as the correct live edit target if that work item is
  pursued.
- Corrected the dispatch's `plan-format.md:259-266` citation to the file's actual `### Enforcement
  level` subsection (now ~line 328) as the operative advisory-first precedent.
- Confirmed the "parenttask" renderer defect's exact mechanism (`gsub("_"; "")` in
  `build_graph()`) and scoped it as independently fixable from the parentage-rendering-location
  decision.

## Risks & Mitigations

- **Risk**: copying Check D3's dependency-array logic verbatim for `parent_task` (a scalar) would
  introduce an array/scalar type-confusion bug. **Mitigation**: write scalar-specific
  orphan/self-reference/cycle logic (seen-set chain walk), not a blind port of the Kahn sweep.
- **Risk**: fixing `gsub("_"; "")` has blast radius beyond `parent_task` — any existing golden/
  snapshot assertions in `scripts/tests/test-generate-task-order.sh` may assert on the current
  (buggy) stripped-underscore output. **Mitigation**: check that test file's fixtures before
  changing the gsub and update any golden outputs that encode the old behavior.
- **Risk**: editing `commands/todo.md`'s already-long, carefully ordered Step 5.7 sequence for
  renumber survival could disturb its existing dependencies-array handling. **Mitigation**: add a
  new, clearly delimited sub-step rather than interleaving logic into the existing dependencies
  step.
- **Risk**: declaring `parent_task` as bare `"type": "integer"` without stating the
  delete-not-null convention could let a future writer set `null` instead of omitting the key,
  which `additionalProperties: false`-style validation may not catch. **Mitigation**: state the
  convention explicitly in both the schema description and the reference-doc section.
- **Risk** (consumer-repo population, out of edit scope but relevant to check design): the
  BimodalLogic repo's `parent_task: 165` entries include children in `not_started` and `blocked`
  status with a still-active parent — any orphan/cycle check must not misfire on ordinary,
  mid-lifecycle parentage. **Mitigation**: design the orphan check against "parent not found in
  known project numbers" only (matching the `dependencies` dangling-reference precedent), never
  against parent/child status combinations.

## Context Extension Recommendations

- **Topic**: parent/child task lineage vs. dependency-ordering semantics as a named, documented
  distinction. **Gap**: `state-management-schema.md` has no "relation taxonomy" section
  distinguishing lineage edges from dependency edges before this task. **Recommendation**: the
  planned `### Parent Task Field` section (Recommendation 2 above) fills this gap directly; no
  separate context file is needed.
- **Topic**: the `gsub(X; "")`-as-markup-escape bug class (delete vs. escape) in
  `generate-task-order.sh`. **Gap**: no existing standard calls out "stripping markup characters
  via deletion can corrupt other legitimate uses of the same character" as a lint-worthy pattern.
  **Recommendation**: optional follow-up note in `context/standards/shell-script-testing.md` or
  similar; not blocking for this task.

## Appendix

Search queries / commands used (all read-only, against `agent-system/extensions/core/`):
- `grep -rn "parent_task" --include="*.md" --include="*.sh" --include="*.json" .`
- `grep -n "parent_task" context/schemas/state-schema.json scripts/validate-state.sh scripts/generate-todo.sh context/reference/state-management-schema.md`
- `sed -n` ranges over `skills/skill-spawn/SKILL.md`, `commands/task.md`, `commands/spawn.md`,
  `agents/spawn-agent.md`, `context/orchestration/delegation.md`, `context/patterns/task-review-mode.md`
- `sed -n` ranges over `scripts/validate-state.sh` (Check D3, `--strict` block, `log_pass`/`log_fail`/`log_warn`)
- `sed -n` ranges over `scripts/generate-task-order.sh` (union-find block, `build_graph()`/`gsub`, display-string headers)
- `cat scripts/deprecated/README.md`; `grep -n "vault-operation" scripts/lib/common.sh scripts/lint/lint-state-writer-boundary.sh context/patterns/task-lock.md`
- `sed -n '661,710p' commands/todo.md` (Step 5.7.7/5.7.8)
- `grep -n "Enforcement level" context/formats/plan-format.md`
- `jq -r '.extensions.core.source_dir' .claude-extensions.json`

References: `agent-system/extensions/core/skills/skill-spawn/SKILL.md`,
`agent-system/extensions/core/context/patterns/task-review-mode.md`,
`agent-system/extensions/core/context/schemas/state-schema.json`,
`agent-system/extensions/core/scripts/validate-state.sh`,
`agent-system/extensions/core/scripts/generate-task-order.sh`,
`agent-system/extensions/core/scripts/generate-todo.sh`,
`agent-system/extensions/core/context/reference/state-management-schema.md`,
`agent-system/extensions/core/commands/todo.md`,
`agent-system/extensions/core/scripts/deprecated/vault-operation.sh`,
`agent-system/extensions/core/scripts/deprecated/README.md`,
`agent-system/extensions/core/context/formats/plan-format.md`.
