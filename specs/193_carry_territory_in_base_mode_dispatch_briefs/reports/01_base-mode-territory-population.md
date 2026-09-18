# Research Report: Task #193

- **Task**: 193 - Carry concurrent-sibling territory in base-mode dispatch briefs
- **Started**: 2026-09-18T17:20:00Z
- **Completed**: 2026-09-18T17:55:00Z
- **Effort**: ~1.5 hours (research)
- **Dependencies**: 197 (archived/completed), 213 (completed) — both already landed; nothing
  blocks starting the plan phase.
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (H1 territory block, batch
    admission wiring, live per-task dispatch loop)
  - `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (`--territory` flag,
    `## Territory` section, hard-mode-gated `core_contracts` block)
  - `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (cross-batch/in-batch
    `file_scope` overlap predicate, `admit`/`defer` verdict schema)
  - `agent-system/extensions/core/context/contracts/territory.md` (H7 territory contract)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` and
    `test-orchestrate-cycle-plan.sh` (existing fixture/harness conventions)
  - `specs/state.json` (task 165, 199, 162 descriptions — coordination targets)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's framing is confirmed exactly against current code, only the line numbers moved:
  `--territory` and the `## Territory` brief section already work in base mode today — the
  section-emission gate is `[ -n "$territory" ]` only, **not** gated on `--hard`
  (`orchestrate-build-dispatch.sh` ~line 437-445). What is entirely hard-mode-gated is (a) the
  **population** of `$territory` in `orchestrate-cycle-plan.sh` (only `h1_territory[$t]`, set
  inside `if [ "$hard_mode" = "true" ]`, ~line 1689-1758) and (b) the **contract pull-in**: the
  whole `core_contracts`/`hard_contracts_block` machinery that appends `territory.md` when
  `-n "$territory"` (line 281) lives entirely inside `if [ "$hard_mode" = "true" ]` (line ~275).
  Two independent gates, both need a base-mode path; the brief-rendering half needs no change at
  all.
- The natural, lowest-risk fix for the contract pull-in is a **second, ungated block**: inside
  `orchestrate-build-dispatch.sh`'s existing `if [ -n "$territory" ]; then ... fi` (the block that
  already unconditionally emits `## Territory`), add a line pointing at
  `context/contracts/territory.md` whenever `$hard_mode != true` (the hard-mode path already
  covers it via `core_contracts`). This keeps the "pulled in as it already is for hard mode"
  acceptance criterion true without duplicating the `<hard-mode-contracts>` tag semantics, which
  are hard-mode-specific vocabulary.
- The natural site to populate a base-mode territory payload is `orchestrate-cycle-plan.sh`'s
  live per-task dispatch loop (`for t in "${probed_dispatch_post_h1[@]}"`, ~line 1802 onward),
  immediately alongside the existing `if [ -n "${h1_next_phase[$t]:-}" ]; then build_args+=(...
  --territory "${h1_territory[$t]}") fi` block (~line 1881-1883). `probed_dispatch_post_h1` is
  **exactly** the set of concurrently-dispatched sibling tasks for this cycle — it already exists,
  already excludes deferred/blocked/locked tasks, and is computed once, shared by both dry-run and
  live paths' upstream logic. No new sibling-discovery mechanism is needed; the gap is purely
  "nothing currently turns this array into a per-task territory payload outside hard mode."
- `orchestrate-batch-admit.sh`'s jq already computes, for every candidate, a `$comparison_set`
  restricted to non-terminal, non-dependency-linked tasks, and an in-batch/cross-batch overlap
  test (`scopes_overlap_first`) — but it reports collisions only (as `defer` reasons or the
  `idle_overlap_advisory` on an `admit` row for idle cross-batch tasks). It never reports a
  **non-colliding** sibling's existence/scope on an `admit` row. Task 193's territory payload is
  a different, additive fact (informational context for a dispatched agent) from batch-admit's
  admission verdict — building it directly from `probed_dispatch_post_h1` plus a `jq` lookup of
  each sibling's `file_scope` in `orchestrate-cycle-plan.sh` avoids touching `orchestrate-batch-admit.sh`'s
  admission-decision jq at all, which is the safer boundary: it keeps "who gets admitted" and
  "what a dispatched agent is told" as separate concerns, matching the H7 contract's own framing
  (territory declares ownership; it does not gate execution).
- **Coordination confirmed**: task 165 ("Decide and implement the admission posture for an absent
  file_scope in orchestrate-batch-admit.sh", status `not_started`) is the "already-filed work on
  absent-file_scope admission posture" the dispatch tells this task to defer to — it owns whether
  an absent `file_scope` becomes a *defer* reason. This task must NOT re-decide that; it only
  needs to decide how the **territory payload** represents an absent (or too-coarse) sibling scope
  so it is not silently invisible to the *agent reading the brief*, independent of whatever
  admission posture task 165 eventually settles. Task 199 ("working-tree and build isolation
  posture for concurrent same-repo dispatches") explicitly defers to this task for "what a dispatch
  is TOLD" and separately notes informing agents is "demonstrably insufficient on its own" for its
  own commit-bleed failure mode (mode 1b) — i.e., task 193's remedy is real but partial, and task
  199's own acceptance criteria are not this task's burden.

## Context & Scope

Task 193 (dependencies 197, 213 — both already landed) asks for two things: (1) populate a
base-mode territory payload in the dispatch brief naming concurrent siblings and their declared
`file_scope`, reusing the already-wired-for-hard-mode `--territory`/`territory.md` mechanism
rather than inventing a new channel; (2) ensure an undeclared or too-coarse sibling scope is
represented explicitly in that payload rather than silently contributing nothing (coordinating
with, not duplicating, task 165's admission-posture ruling). This report verifies the current
code against the dispatch's claims, locates the exact insertion points for both scripts, and
resolves the payload-shape and scope-boundary questions the dispatch leaves open.

## Findings

### 1. The brief-rendering mechanism already works in base mode; only two upstream gates block it

`orchestrate-build-dispatch.sh`:
- Accepts `--territory "<json>"` unconditionally (arg parser, line ~128 — no hard-mode check).
- Emits `## Territory` + the fenced JSON block whenever `[ -n "$territory" ]` (line ~437-445) —
  this condition does **not** check `$hard_mode`. A base-mode call that passed `--territory`
  today would already render the section correctly.
- The **only** hard-mode-gated piece touching territory is the `core_contracts` array inside
  `if [ "$hard_mode" = "true" ]; then ... case "$phase" in ... implement) ... [ -n "$territory" ]
  && core_contracts+=(territory.md) ...` (lines ~273-310), which builds the
  `<hard-mode-contracts>` block. In base mode this whole region is skipped, so `territory.md` is
  never named as a contract to read even when `$territory` is non-empty — this is the "pulls in
  ... as a core contract when it is set [but only for hard mode]" gap named in the dispatch.

`orchestrate-cycle-plan.sh`:
- `h1_territory[$t]` is the only writer of a territory JSON value anywhere in the file (confirmed:
  `grep -n territory` shows exactly one assignment, inside the `[ "$hard_mode" = "true" ]`-gated
  H1 loop, ~line 1752). The live per-task loop's only consumer is
  `[ -n "${h1_next_phase[$t]:-}" ] && build_args+=(--phase-number ... --territory
  "${h1_territory[$t]}")` (~line 1881-1883) — `h1_next_phase[$t]` is itself only ever set inside
  the hard-mode H1 loop, so this branch is structurally unreachable in base mode. Confirms the
  dispatch's claim exactly: "absent from every base-mode call."

### 2. `probed_dispatch_post_h1` is the sibling set the territory payload needs — no new plumbing required

`probed_dispatch_post_h1` (built ~line 1768-1781) is the final list of task numbers that will
actually be dispatched **this cycle**, across all phase groups (research/plan/implement mixed),
after H1 refusals are filtered out. It is computed once, upstream of the mode fork
(`--dry-run` vs. live), and the live per-task loop already iterates it
(`for t in "${probed_dispatch_post_h1[@]}"`, ~line 1802). This is precisely "the concurrently-
dispatched sibling task numbers" the dispatch asks for — no separate sibling-discovery query is
needed; the existing loop variable already enumerates them, and each task's own
`project_names[$t]`/`task_dirs[$t]` are already resolved in-loop.

Each sibling's declared `file_scope` is not currently held in any per-task associative array in
this script (only `orchestrate-batch-admit.sh`'s internal jq reads `.active_projects[].file_scope`
directly from `$STATE_FILE`). The lowest-risk way to obtain it for the territory payload is a
single `jq` query against `$STATE_FILE` per relevant task (or one batched query keyed by the
`probed_dispatch_post_h1` array, mirroring the style of `compose_focus()`'s existing per-task jq
lookup at ~line 1600), rather than re-deriving it from `orchestrate-batch-admit.sh`'s already-
returned ndjson (which only carries `file_scope`-derived facts for tasks that collided, not a
verbatim scope list for every admitted candidate).

### 3. `orchestrate-batch-admit.sh`'s existing collision detection is a different fact, not a substitute

Reviewed the full jq body (`sed -n '500,700p'`): for candidate `c`, `$comparison_set` is every
non-terminal, non-dependency-linked task in `state.json` (not scoped to this cycle's batch); the
in-batch/cross-batch distinction (`$scope_kind`) is used only to decide **which direction** of an
already-detected collision gets deferred (asymmetric tie-break: only the higher-numbered task in
a colliding same-batch pair sees the hit and is deferred; the lower-numbered one is admitted with
no signal at all about the collision or the sibling). Two **non-colliding** batch siblings
currently produce zero shared information on either one's `admit` row. This confirms: batch-admit
answers "should this task be admitted", territory answers "what should a dispatched agent be
told" — even for pairs that were correctly admitted together, the second question has never been
answered before this task. Building the territory payload independently in
`orchestrate-cycle-plan.sh` (Finding 2) rather than widening `orchestrate-batch-admit.sh`'s
verdict schema keeps these concerns separated, consistent with `orchestrate-batch-admit.sh`'s own
header framing as strictly an admission predicate.

### 4. H7's `territory.md` contract is a template, not a rigid schema — reusable content, adapt the framing

`territory.md`'s `owned_files`/`read_only_files`/`forbidden_files`/`concurrency_note` shape
(File Territory section) is written for **within-task** parallel phase ownership (H7's stated
scope: "multiple agents dispatched simultaneously to work on different phases of the same plan").
The dispatch is explicit that base-mode's cross-task concurrency is "a different fact" and warns
against assuming the hard-mode payload shape transfers unchanged. The parts of `territory.md` that
generalize cleanly to cross-task concurrency without rewriting: the **Handoff Merge Rule**
(applies verbatim — `.orchestrator-handoff.json` is per-task, not shared across siblings in base
mode, so this section is largely inert for the new payload) and, more relevantly, the closing
"Explicit removal note" (never let a dispatch conclude it is the only agent active) and the
`concurrency_note` idiom already used by `h1_territory` ("This declaration asserts only which
files THIS dispatch owns... If you observe foreign commits... STOP and report it"). The base-mode
payload should reuse that STOP-and-report framing but change the subject from "a possibly-live
predecessor on the same task" to "concurrently-dispatched sibling tasks in this batch" — a
plan-phase decision to word precisely, not something this report should freeze verbatim, but the
existing `concurrency_note` string is the right model to adapt rather than inventing new prose.

### 5. Minimum payload contents and the undeclared/coarse-scope representation

Per the dispatch's own "at minimum" framing and the RECURRED addendum's granularity point, a
base-mode territory payload per dispatched task should carry, for every OTHER task in
`probed_dispatch_post_h1` this cycle:
- `task_number`
- `file_scope`: the sibling's declared array verbatim (including a single-entry directory-root
  declaration exactly as coarse as it is — Finding 3's point that batch-admit's own gate already
  cannot see a too-coarse declaration means the territory payload is the one place left that CAN
  surface it to a human-equivalent reader, i.e. the dispatched agent, even where the machine gate
  missed it)
- An explicit sentinel for the absent-scope case rather than a silently-omitted key or an empty
  array that could be misread as "touches nothing" — e.g. `file_scope: null` with a
  `"scope_declared": false` flag, or a literal string sentinel. This directly answers the
  dispatch's item (2): a `file_scope: null` sibling must appear in the payload with an explicit
  marker, never be dropped from the list the way it is currently dropped from the collision gate's
  comparison entirely (Finding 3 confirms `orchestrate-batch-admit.sh` already treats `file_scope
  // [] | length == 0` as an unconditional early-admit with no collision check — the same
  invisibility the dispatch describes). This is a representational decision only (how the payload
  renders an absent/coarse scope); it does not touch or pre-empt task 165's separate ADMISSION
  question of whether that absence should ever cause a defer.
- Whether to include the sequencing/non-idempotence rationale the dispatch mentions ("consider
  also") is a plan-phase judgment call: nothing in the codebase currently computes or stores a
  machine-derivable "task A's edits are non-idempotent over task B's" fact, so this would have to
  be either omitted, or synthesized generically (e.g. "any commit you make to a file also named in
  a sibling's scope requires re-reading it immediately before your own commit" — a general
  procedural instruction, not a per-pair fact).

### 6. Phase-group scope of the payload (research/plan/implement mixed)

`probed_dispatch_post_h1` mixes phase groups in the same cycle (a batch can dispatch one task's
research alongside another's implement). The two recorded incidents were both implement-vs-
implement collisions (arbitrary repo file writes); research/plan agents write only under
`specs/{task}/reports|plans/` plus their own `.return-meta.json`/`.orchestrator-handoff.json`
(never arbitrary repo paths per the task-type routing table), so a research or plan sibling is
structurally very unlikely to collide with anything outside its own task directory. Two credible
options for the plan phase to weigh explicitly (not resolved here): (a) emit the territory section
for every dispatched phase group uniformly, since it costs nothing and keeps one code path; or (b)
restrict population to `implement`-group siblings only, since those are the only realistic
collision surface and a smaller payload is easier to read under time pressure. Given `--territory`
already flows through `orchestrate-build-dispatch.sh`'s existing phase-agnostic `## Territory`
section (Finding 1), option (a) is the lower-risk default; (b) is a legitimate scope-narrowing
the plan could choose instead, provided it states the corresponding tradeoff.

### 7. Header-contract and shellcheck acceptance criteria map onto known existing conventions

Both scripts already document new behavior in structured top-of-file comment blocks (see
`orchestrate-cycle-plan.sh`'s existing "mt_state_file field list" and per-flag comment blocks,
e.g. the `--phase-number` and `--compare` blocks in `orchestrate-build-dispatch.sh`'s header).
The acceptance criterion "documented in the header contracts of both" maps directly onto adding a
comparable dated/flag-scoped comment block to each file, following the exact style already used
for `--phase-number`/`--territory`(H1) in `orchestrate-build-dispatch.sh`'s header and the H1
block's own inline comments in `orchestrate-cycle-plan.sh` — no new documentation convention needs
to be invented. `shellcheck` is already run against both scripts in CI/dev workflow per
`context/standards/shell-strict-mode.md`; both files already carry `set -euo pipefail`
(Class A strict mode), so a base-mode territory addition following the same quoting/array
conventions used by the adjacent `h1_territory`/`build_args` code should stay clean by
construction.

### 8. Existing test harness gives a ready-made fixture shape for the acceptance criterion's fixture requirement

`tests/test-orchestrate-cycle-plan.sh` already uses a JSON-fixture-per-group convention
(`{"project_number": N, ..., "file_scope": [...]}` entries assembled into a fixture
`state.json`, then `run_sut` + `assert_contains`/`assert_not_contains` against the produced
dispatch JSON / `.dispatch/N.md` file). Group 9 (H1: `--territory`/`--phase-number`, ~line 789-826)
is the closest existing precedent, asserting `dispatch_argv` contains `--territory` for a
hard-mode candidate. The acceptance criterion's fixture — "two concurrent implement dispatches,
one with a declared narrow scope and one with none" — maps directly onto a new group following
this exact pattern: two `project_number` entries, `status: "planned"` or `"implementing"` (so both
resolve to the `implement` group), one `file_scope: ["some/narrow/path"]` and one `file_scope: []`
(or the key omitted entirely, to also exercise the "field literally absent" case the dispatch
distinguishes from "empty array"), asserting the base-mode (no `--hard`) dispatch's `## Territory`
section now names the sibling task number(s) and reflects the undeclared-scope sentinel for the
second. `test-orchestrate-build-dispatch.sh`'s Group 5/6 (territory-absent vs. territory-present
parity, ~line 281-320) is the analogous precedent for asserting `territory.md` is now referenced
even when `$hard_mode != true`.

## Decisions

None made unilaterally here beyond representational framing (Finding 5's sentinel choice is a
recommendation, not a binding decision — left for the plan phase per this task's own "decide, do
not pre-commit" posture on adjacent open questions). No file was edited; this is a research-only
dispatch.

## Recommendations

1. **`orchestrate-build-dispatch.sh`**: inside the existing `if [ -n "$territory" ]; then ... fi`
   block (the one that already unconditionally renders `## Territory`), add a base-mode contract
   pointer — e.g. `[ "$hard_mode" != "true" ] && echo "See context/contracts/territory.md for the
   full territory contract."` — so `territory.md` is referenced whenever `$territory` is set,
   regardless of hard mode, without touching the `<hard-mode-contracts>`/`core_contracts`
   machinery that remains hard-mode's own vocabulary.
2. **`orchestrate-cycle-plan.sh`**: in the live per-task dispatch loop, alongside the existing
   `h1_next_phase`-gated `--territory` append, add a new, independent base-mode branch that (when
   `$hard_mode != true`, or unconditionally as a superset — plan phase to decide) builds a
   territory JSON literal from `probed_dispatch_post_h1` minus `$t` itself, with each sibling's
   `project_number` and `file_scope` (jq-queried from `$STATE_FILE`, absent/empty represented per
   Finding 5's sentinel), and appends `--territory "<json>"` to `build_args` when the sibling list
   is non-empty (empty-value-skips-flag, matching every other flag in that block).
3. Do not modify `orchestrate-batch-admit.sh`'s admission jq (Finding 3) — the territory payload
   is built independently in `orchestrate-cycle-plan.sh` from data it already has in scope
   (`probed_dispatch_post_h1` plus a `file_scope` lookup), keeping admission-decision logic and
   dispatch-brief-content logic as separate concerns.
4. Word the base-mode `concurrency_note` (or equivalent) by adapting the existing H1
   `concurrency_note` string (Finding 4) rather than authoring new prose from scratch, changing
   only the subject from "a possibly-live predecessor" to "concurrently-dispatched sibling tasks
   in this cycle's batch."
5. State explicitly in the plan (Finding 6) whether the payload is emitted for every dispatched
   phase group or restricted to `implement`-group siblings; recommend the phase-agnostic default
   given it costs nothing extra given `--territory`'s already phase-agnostic rendering.
6. Add new test groups to both existing test files following the Group 9 / Group 5-6 precedents
   (Finding 8) rather than a new standalone test file, to satisfy the acceptance criterion's
   fixture requirement.
7. Document the change in both scripts' header comment blocks following the existing per-flag
   comment-block convention (Finding 7); no new documentation format is needed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Base-mode territory payload accidentally reuses/collides with the `--territory` flag's hard-mode-only semantics (e.g. a base-mode dispatch now also triggers `<hard-mode-contracts>` rendering) | Base-mode dispatch briefs balloon with unrelated hard-mode contract text | Low if Recommendation 1 is implemented as a genuinely separate branch keyed on `$hard_mode`, not a reuse of `core_contracts` | Keep the base-mode contract pointer textually and structurally distinct from `hard_contracts_block`/`<hard-mode-contracts>`, as scoped in Finding 1 |
| Building the sibling list from `probed_dispatch_post_h1` after H1 filtering silently drops a sibling that is dispatched via a different code path this cycle (e.g. `aux_dispatch[]`, referenced in the header's Phase 5 note) | Territory payload incomplete for auxiliary dispatch flows | Low-Medium — not fully investigated in this pass | Plan phase should grep `aux_dispatch`/`aux_pending` call sites and confirm whether they route through the same live per-task loop or a separate one before finalizing the sibling-set source |
| Territory payload for an absent-scope sibling reads as an accusation/false-positive report risk (echoing the dispatch's own observed harm: a dispatch reported a sibling for a breach that hadn't happened) | Agents over-react to informational territory data, generating spurious STOP-and-report noise | Low-Medium | Model the STOP-and-report language on existing `territory.md` wording precisely (Finding 4), which already frames it as "if you observe foreign work," not "sibling X will conflict with you" |
| Fixture additions to the large, already-2000+-line `test-orchestrate-cycle-plan.sh` increase test runtime/complexity further | Slower CI, harder-to-navigate test file | Low | Follow the existing Group-N append convention (Finding 8) exactly; do not restructure the file |

## Context Extension Recommendations

- **Topic**: base-mode cross-task territory payload shape.
- **Gap**: `context/contracts/territory.md` documents only the within-task H7 shape; once this
  task lands, the contract file should gain a second section (or a companion doc) describing the
  cross-task base-mode payload shape, its sentinel convention for absent/coarse scope, and its
  relationship to task 165's admission posture — otherwise a future reader of `territory.md` will
  see only the phase-ownership template and miss the newer cross-task use.
- **Recommendation**: the plan/implementation phase should update `territory.md` itself (not a
  new file) with a "Cross-Task Territory (Base Mode)" section mirroring the existing "File
  Territory" section's structure, since this is directly in this task's own file_scope
  (`agent-system/extensions/core/context/contracts/territory.md` is already declared).

## Appendix

- Grep confirming the sole `h1_territory` writer and its hard-mode gate:
  `grep -n "territory\|h1_territory" orchestrate-cycle-plan.sh`.
- Grep confirming `--territory`'s ungated brief-rendering vs. hard-mode-gated contract pull-in:
  `grep -n "territory\|Territory" orchestrate-build-dispatch.sh`.
- Batch-admission jq body reviewed in full: `orchestrate-batch-admit.sh` lines ~500-700.
- Coordination targets confirmed via `specs/state.json`: task 165 ("Decide and implement the
  admission posture for an absent file_scope in orchestrate-batch-admit.sh", not_started), task
  199 ("Decide and implement the working-tree and build isolation posture for concurrent
  same-repo dispatches", not_started, explicitly defers "what a dispatch is TOLD" to this task),
  task 162 ("Formalize Files to modify... and backfill existing tasks", researched — relevant only
  insofar as it affects how reliably `file_scope` is populated at all, not this task's payload
  format).
- Existing test-fixture precedent reviewed: `tests/test-orchestrate-cycle-plan.sh` Group 9
  (~lines 714-868), `tests/test-orchestrate-build-dispatch.sh` Groups 5-6 (~lines 281-360).
