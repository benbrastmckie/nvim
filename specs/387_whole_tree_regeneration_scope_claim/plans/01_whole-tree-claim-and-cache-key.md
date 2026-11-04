# Implementation Plan: Task #387

- **Task**: 387 - Whole-tree regeneration scope claim (Part A) + plan-cache force-phases bypass (Part B)
- **Status**: [NOT STARTED]
- **Effort**: 7.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/387_whole_tree_regeneration_scope_claim/reports/01_whole_tree_regeneration_scope_claim.md
- **Artifacts**: plans/01_whole-tree-claim-and-cache-key.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two defects in the orchestrator's co-dispatch and cycle-composition machinery, found in one
investigation and kept batched (research confirmed no shared lines). **Part A** gives a plan phase
that regenerates the whole deployed tree a way to declare that claim honestly, as a reserved
`file_scope` sentinel harvested through the existing `Files to modify` pipeline, and adds a new,
last-ranked admission dimension in `orchestrate-batch-admit.sh` that serializes two
sentinel-carrying tasks even when their real declared paths are strictly disjoint. **Part B**
stops the in-session plan cache from becoming permanently replayable: the write guard is tightened
to require a real `dispatch[]` row, and the canonicalized `--force-phases` value is folded into the
cache key as defense in depth.

Every edit lands in the source store at `/home/benjamin/.config/nvim/agent-system/extensions/core`
(resolved from `.claude-extensions.json`'s `source_dir`), never under the deployed `.claude/` tree,
and the final phase redeploys.

### Research Integration

The research report's mechanical findings are adopted wholesale and were re-verified during
planning: `deploy-headless.sh` regenerates from current filesystem state (so it reads uncommitted
sibling edits regardless of `file_scope`); `plan-file-scope-harvest.sh` already unions every
phase's `Files to modify` list into `file_scope` at plan-postflight time and is path-shape-agnostic;
`deploy-headless.sh`'s `specs/.deploy-lock/` mutex already exists and is explicitly fail-open; and
Part B's mechanical lead is confirmed in code (`orchestrate-cycle-plan.sh` lines ~1478-1481 mint and
advance `dispatch_seq_counter` on the aux path, the write guard at ~754-755 accepts an aux-only
composition, and `orchestrate-cycle-postflight.sh` ~2130-2137 is the sole `del(.plan_cache)` site
that an aux dispatch structurally never reaches).

**One load-bearing research recommendation is rejected, on verified grounds.** The report
recommended declaring a real wide path (`agent-system/`) in a redeploy phase's `Files to modify`
and reusing the existing `file_scope_collision` branch with zero gate code, claiming it
"automatically inherits that branch's EXISTING `--phase-map` exemption with no new code." Three
checks during planning disqualify that shape:

1. **No phase exemption exists on the collision scan.** `orchestrate-batch-admit.sh` reads
   `$phase_group` in exactly two places — the `self_modifying` branch (~line 789) and the
   `absent_file_scope` branch (~line 845). The collision branch (the `else` arm after
   `$sm_flag == true`, ~line 870 onward) never reads it. A sentinel declared this way would defer
   a task's **research and plan** dispatches too, which never redeploy — precisely the false
   positive the two existing phase-aware branches were built to avoid.
2. **`agent-system/` is the archetype of an existing lint finding.** `validate-state.sh` Check 8
   flags a trailing-slash whole-directory-root `file_scope` entry that overlaps at least
   `FILE_SCOPE_COARSE_MIN_OVERLAP` other non-terminal tasks as a declaration-quality defect.
   Adopting it as a convention would mass-produce the finding that check exists to surface.
3. **A real wide path silently loosens the Containment consumer.** `path_covered_by_scope()` in
   `lib/file-scope-overlap.sh` (consumed by `git-snapshot.sh`) would treat every path under
   `agent-system/` as in-scope for a sentinel-carrying task, maximally weakening the
   snapshot/commit scope guardrail — a cost the report does not weigh.

A slashless reserved token is inert in both predicates (`scopes_overlap_first`: no exact match and
no `X/` prefix relation against any real path; `path_covered_by_scope`: nothing is ever under
`__WHOLE_TREE__/`), so it adds detection without loosening containment.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` in the dispatch context; no roadmap phases.

## Goals & Non-Goals

**Goals**:

- Part A: two tasks with strictly disjoint real `file_scope`, whose plans both contain a
  whole-tree regeneration phase, are never co-dispatched into the same wave.
- Part A: the verdict carries a named, machine-readable `defer_reason` distinguishable from
  `file_scope_collision`, with its own payload fields.
- Part A: a research or plan dispatch for a sentinel-carrying task is exempt from the new defer
  (it never redeploys), with the claim still visible on the verdict.
- Part A: the four existing admit/defer branches (`self_modifying`, `file_scope_collision`,
  `session_active`, `absent_file_scope`) and the `idle_overlap_advisory` keep their current
  semantics and output fields, and the fail-open posture is preserved.
- Part B: an invocation carrying a `--force-phases` value different from the cached composition's
  does not replay that cache, and an aux-only composition never creates a cache entry with no
  clearing counterpart.
- Part B: the cache still suppresses the redundant re-composition it was built for, the stdout
  contract (single-line JSON, both modes) is unchanged, and the write/clear pairing is stated in
  the script's own header.

**Non-Goals**:

- **Closing the stale-deploy READ hazard** (a gate run failing doc-lint on files outside the
  candidate's own scope, because the deployed tree lags a sibling's already-committed source
  edits). Serializing dispatch removes the wasted wave, not this hazard. It is already covered by
  the inter-cycle redeploy checkpoint plus the postflight completion-deploy gate — the archived
  evidence shows the checkpoint did catch and correct it, at a one-cycle cost. This must be stated
  explicitly in the shipped documentation, not silently assumed solved.
- **Promoting `deploy-headless.sh`'s fail-open `specs/.deploy-lock/` mutex to blocking.** It stays
  exactly as it is, as the last-resort backstop for a plan written before this convention exists.
  Promoting it is a separable decision whose cost/benefit should be measured after the
  admission-time fix lands.
- Content-sniffing a plan artifact from inside the admission gate. `orchestrate-batch-admit.sh`
  stays a pure `state.json`-only predicate with no repo-wide filesystem walk.
- Any change to `plan-file-scope-harvest.sh`'s parsing code (it is already path-shape-agnostic;
  Phase 5 only confirms this with a test case).
- Splitting the task. Research confirmed Parts A and B touch disjoint line ranges of one shared
  file and no shared lines elsewhere.

## Design Decisions

**Part A — the chosen mechanism** (the dispatch's Option 2, reserved-sentinel flavor):

- **Sentinel**: `__WHOLE_TREE__`, a reserved slashless token, matching this codebase's existing
  reserved-token convention (`__FULL_SWEEP__` in `context/formats/plan-format.md`, `__MISSING__` in
  `scripts/validate-handoff.sh`).
- **Declaration path**: a plan phase whose steps invoke whole-tree regeneration lists
  `` `__WHOLE_TREE__` `` as an entry in that phase's `**Files to modify**:` block, alongside its
  real files. `plan-file-scope-harvest.sh` unions it into `active_projects[].file_scope` at
  plan-postflight time with **zero change to that script**.
- **Consumption**: a new, fifth admission dimension in `orchestrate-batch-admit.sh`, evaluated
  **last** — after `self_modifying`, `file_scope_collision`, and `session_active`, and only on a
  candidate those three would otherwise ADMIT. Nothing is reordered; no existing branch is edited.
- **Verdict**: `defer_reason: "whole_tree_claim"`, with `colliding_task_number`,
  `colliding_task_status`, `collision_scope` (`in_batch`/`cross_batch`), and `claim_sentinel`. A
  `whole_tree_claim: true` field appears on every verdict for a sentinel-carrying candidate, even
  when it admits — the "hazard stays visible when not deferred" convention `self_modifying` already
  uses.
- **Deferral direction**: mirrors `file_scope_collision`'s already-narrowed v5 rule rather than
  inventing a new one. `in_batch`: defer only against a LOWER-numbered peer that is ITSELF admitted
  this cycle. `cross_batch`: defer only while the other task carries execution evidence (status in
  `researching`/`planning`/`implementing`); an idle cross-batch sentinel peer admits with an
  advisory.
- **Phase exemption**: a candidate mapped via `--phase-map` to `research` or `plan` is exempt
  unconditionally, same rationale and same shape as the two existing phase-aware branches.
- **Fail-open**: unknown task, terminal status, and absent `file_scope` all return from earlier
  branches and never reach the new dimension; a candidate with no sentinel in its declared
  `file_scope` is unaffected. No plan artifact is read, so a missing plan cannot error.
- **Schema version**: `$schema` bumps `orchestrate-batch-admit-v6` -> `-v7` (a new `defer_reason`
  enum member plus new fields), following the in-file precedent that recorded
  `absent_file_scope` as "NEW in v6".
- **Migration story** (the dispatch's stated cost of Option 2): the sentinel is **inert on the
  pre-fix gate** — a slashless token overlaps no real path under `scopes_overlap_first` and covers
  nothing under `path_covered_by_scope`. A plan may therefore adopt the convention before the gate
  ships, with no behavior change, and a plan written before the convention existed simply declares
  nothing and falls back to the existing fail-open deploy mutex. No backfill migration is required.
  This plan's own final phase declares the sentinel, which exercises the producer side live.

**Part B — the chosen fix** (primary plus defense in depth):

- Primary: tighten the cache-write guard at `orchestrate-cycle-plan.sh` ~754-755 from
  `{ [ "${#out_dispatch_rows[@]}" -gt 0 ] || [ "${#out_aux_dispatch_rows[@]}" -gt 0 ]; }` to
  `[ "${#out_dispatch_rows[@]}" -gt 0 ]`. This closes the whole defect class (any invocation
  difference, not only `--force-phases`) at the root, since an aux-only composition caches at a
  counter value nothing but a future real dispatch can ever advance past.
- Defense in depth: fold the already-computed `canonical_force_phases_json` into the cache key at
  both the write site (~757) and the replay check (~639-650); a replay fires only when BOTH the
  counter and the forced-phases value match. This satisfies ACCEPTANCE (a) literally even if some
  future change reintroduces an aux-only write path.
- The inline comment at ~740-753 **already claims** "write plan_cache ONLY when this composition
  actually built >=1 dispatch row" while the code also accepts an aux row — a live comment/code
  divergence. The fix makes the code match the comment that was already there.
- Decision (D3) recorded at ~749-753 ("the cache key stays `dispatch_seq_counter` ALONE, with no
  `--focus` component") is **amended, not contradicted silently**: `--focus` stays out of the key
  for the reason D3 gives (it is fixed for the whole invocation), while `--force-phases` goes in
  because it is the human's documented override lever and must be able to break a replay. The
  amendment is written into the comment.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `$schema` v6 -> v7 bump ripples into more consumers than anticipated (literal-string pins in scripts and tests) | H | M | Phase 4 enumerates every `orchestrate-batch-admit-v6` literal by grep across the source store BEFORE editing, and treats the count as a hypothesis to confirm (see its Scope Hypothesis), not a fact |
| Planner discipline is the sole producer-side enforcement: a plan that omits the sentinel leaves the gap open for that one plan | M | M | Same trust model `file_scope` already relies on everywhere (prospective, never filesystem-validated); the existing fail-open deploy mutex stays as backstop, and `backfill-file-scope.sh` is the remedial tool for a stale `file_scope` |
| A reserved token in `file_scope` surfaces somewhere path-shaped and reads oddly (e.g. `orchestrate-build-dispatch.sh`'s territory `owned_files` block) | L | M | Phase 6 documents the token in `file-footprint-overlap.md` so a reader of any consumer can resolve it; Phase 4 verifies it trips neither `validate-state.sh` Check 8 (no trailing slash) nor Check 11 (no glob metacharacter) |
| Adding a fifth dimension regresses one of the four existing branches | H | L | The new dimension is appended last and evaluated only on an otherwise-ADMIT candidate, so no existing branch's code path is edited; Phase 2's red-baseline fixtures pin all four existing reasons before Phase 4 touches anything |
| Part B's tightened guard removes caching for every aux-only cycle | L | H | Accepted and recorded: a true no-charge cycle already never caches, so this narrows an already-narrow optimization rather than creating a new cost category. ACCEPTANCE (b) requires the benefit only for the real-dispatch case |
| Design requires editing files beyond the dispatch's enumerated SCOPE list | M | H | Named explicitly: `context/formats/plan-format.md`, `agents/planner-agent.md`, `docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`, and the three test suites are all required by the chosen design. The dispatch's list is anticipated, not binding; the expansion is recorded here rather than discovered silently at implementation time |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3, 4 | 1 (for 3), 2 (for 4) |
| 3 | 5, 6 | 4 |
| 4 | 7 | 3, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Part B red-baseline regression tests [NOT STARTED]

**Goal**: Pin the three Part B acceptance behaviors as failing tests against the unmodified
`orchestrate-cycle-plan.sh`, so the fix in Phase 3 is demonstrated rather than asserted.

**Tasks**:

- [ ] Read `scripts/tests/test-orchestrate-cycle-plan.sh`'s existing harness conventions (temp
      multi-task state file, `mt_json` seeding, fd-3 capture) and reuse them; do not build a second
      harness.
- [ ] Add case: an aux-only composition (>=1 `aux_dispatch` row, zero `dispatch` rows) must leave
      `plan_cache` absent in the written state file. Expect RED today.
- [ ] Add case: an invocation whose `--force-phases` value differs from the one a cache entry was
      built with must NOT replay (must fall through to real composition). Expect RED today.
- [ ] Add case: a composition with >=1 real `dispatch` row still writes `plan_cache`, and a
      same-counter same-`--force-phases` re-invocation still replays it verbatim — the no-charge
      benefit is preserved. Expect GREEN today and after the fix (a non-regression pin).
- [ ] Add case: stdout is a single-line JSON object in both live and `--dry-run` mode, byte-shape
      unchanged by any of the above.
- [ ] Run `bash scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh` and record the
      red-baseline output in this phase's completion notes.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Four new cases in one existing suite file. Confirm at implementation time
that the existing harness exposes a per-case `--force-phases` argument path and a readable
post-invocation state file; if it does not, the harness extension is part of this phase, not a
reason to restructure.

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`
covers the one test file this phase edits, which has no non-test consumer.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - four new cases
  covering aux-only non-caching, force-phases replay rejection, cache-benefit preservation, and
  stdout shape

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`
  runs and reports the two new cases as FAIL (the expected red baseline) and the two
  non-regression pins as PASS.
- The suite's pre-existing cases are all still PASS.

---

### Phase 2: Part A red-baseline fixtures and existing-branch pins [NOT STARTED]

**Goal**: Add the ACCEPTANCE (a) fixture (two disjoint-scope sentinel-carrying tasks must not
co-admit) as a failing test, and pin every existing defer branch's current output so Phase 4's
non-regression claim is mechanical.

**Tasks**:

- [ ] Read `scripts/tests/test-orchestrate-batch-admit.sh`'s isolated-temp-root harness (it copies
      `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`, `lib/file-scope-overlap.sh`,
      `lib/common.sh`, `lib/task-lookup-lib.sh`, `task-lock.sh` into `$TMPROOT/.claude/scripts/`)
      and reuse it verbatim.
- [ ] Add case `WHOLE-TREE-CODISPATCH`: two in-batch tasks with strictly disjoint real
      `file_scope`, each additionally declaring `__WHOLE_TREE__`, with `--invocation-count 2`. The
      higher-numbered candidate must defer with `defer_reason: "whole_tree_claim"`. Expect RED
      today (today it admits).
- [ ] Add case `WHOLE-TREE-PHASE-EXEMPT`: the same pair with the higher-numbered candidate mapped
      via `--phase-map N:plan`. It must ADMIT, carrying `whole_tree_claim: true`. Expect RED today
      (the field does not exist).
- [ ] Add case `WHOLE-TREE-NO-SENTINEL`: the same disjoint pair with neither declaring the
      sentinel must both ADMIT — the new dimension must not fire on ordinary tasks.
- [ ] Add case `WHOLE-TREE-INERT-PATH`: a candidate declaring `__WHOLE_TREE__` against a peer
      declaring only real paths must NOT produce a `file_scope_collision` on the sentinel (the
      token must be inert against real paths under `scopes_overlap_first`).
- [ ] Add non-regression pins asserting the unchanged verdict shape for each of
      `self_modifying`, `file_scope_collision`, `session_active`, `absent_file_scope`, and the
      `idle_overlap_advisory` — reuse the suite's existing cases where they already pin these and
      add only what is missing.
- [ ] Run `bash scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh` and record the
      red-baseline output in this phase's completion notes.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Four new cases plus up to five non-regression pins in one existing suite
file. Confirm at implementation time which of the five existing branches the suite already pins
(its header names `IN-BATCH-ABSENCE`, `CROSS-BATCH-ABSENCE`, `SOLO-SELF-MOD-CROSS-SESSION`,
`PHASE-EXEMPT-ABSENCE`, and a `$schema`-literal pin) and add only the genuinely missing pins
rather than duplicating coverage.

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh`
covers the one test file this phase edits, which has no non-test consumer.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - four new
  whole-tree-claim cases plus the missing existing-branch non-regression pins

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh`
  reports `WHOLE-TREE-CODISPATCH` and `WHOLE-TREE-PHASE-EXEMPT` as FAIL (expected red baseline) and
  `WHOLE-TREE-NO-SENTINEL`, `WHOLE-TREE-INERT-PATH`, and every non-regression pin as PASS.
- The suite's pre-existing cases are all still PASS.

---

### Phase 3: Part B plan-cache write-guard and force-phases cache key [NOT STARTED]

**Goal**: Turn Phase 1's red cases green: an aux-only composition never writes `plan_cache`, and a
differing `--force-phases` value cannot replay a cached composition.

**Tasks**:

- [ ] Tighten the write guard at `scripts/orchestrate-cycle-plan.sh` ~754-755 to
      `[ "${#out_dispatch_rows[@]}" -gt 0 ]`, dropping the `out_aux_dispatch_rows` disjunct.
- [ ] Extend the cache object written at ~757 to carry the canonicalized forced-phases value
      alongside `dispatch_seq_counter` (`canonical_force_phases_json` is already computed at
      ~543-554; do not recompute it).
- [ ] Extend the replay check at ~639-650 to require BOTH the counter AND the forced-phases value
      to match before replaying; a missing forced-phases key in a pre-existing cache entry must be
      treated as a non-match (fall through and recompose), never as an error.
- [ ] Update the header comment block at ~71-76 to state the corrected write condition, name the
      single `plan_cache`-clearing site (`orchestrate-cycle-postflight.sh`), and state the
      write/clear pairing invariant explicitly so a future reader can check it without re-deriving
      it — this is ACCEPTANCE (d).
- [ ] Update the inline comment at ~740-753: state that an aux-only composition is deliberately
      never cached because an aux dispatch structurally never reaches the one clearing site, and
      amend decision (D3) to record that `--force-phases` IS in the key while `--focus` remains
      deliberately out of it, with the reason for the asymmetry.
- [ ] Confirm the replay-path stderr message still names the reason accurately after the key change.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`
covers this script, and the edit changes no interface the script exposes — the stdout JSON contract
is explicitly unchanged and pinned by Phase 1's stdout-shape case.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - write guard (~754-755), cache
  object (~757), replay check (~639-650), header comment (~71-76), inline write-site comment
  (~740-753)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`
  is fully green, including Phase 1's two previously-red cases.
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` passes.
- The header comment states the write condition and the clearing site; verify by reading it back.

---

### Phase 4: Part A whole-tree-claim admission dimension and schema v7 [NOT STARTED]

**Goal**: Turn Phase 2's red cases green by adding the fifth admission dimension, without editing
any existing branch's code path.

**Tasks**:

- [ ] Enumerate every `orchestrate-batch-admit-v6` literal across the source store
      (`grep -rn 'orchestrate-batch-admit-v6' agent-system/extensions/core/`) and record the list
      before editing anything — this is the Scope Hypothesis below, to confirm, not assume.
- [ ] Define the reserved sentinel once, as a named constant in
      `scripts/lib/file-scope-overlap.sh`, alongside the existing predicates — so the gate, the
      documentation, and any future consumer share one spelling rather than transcribing the
      literal. Add no new matching rule; the token's inertness against real paths is a property of
      the existing `scopes_overlap_first` definition, not new code.
- [ ] Add the new dimension in `scripts/orchestrate-batch-admit.sh`, evaluated LAST and only on a
      candidate the three existing post-absence branches would otherwise ADMIT. Emit
      `defer_reason: "whole_tree_claim"` with `colliding_task_number`, `colliding_task_status`,
      `collision_scope`, `claim_sentinel`, and a `reason` string in the established
      ordering-constraint-not-exclusion phrasing.
- [ ] Add `whole_tree_claim: true` to every verdict for a sentinel-carrying candidate, including the
      admit shapes and the phase-exempt shape (hazard stays visible when not deferred).
- [ ] Apply the `--phase-map` `research`/`plan` exemption in the new branch, with the same
      unconditional posture and the same rationale the `self_modifying` and `absent_file_scope`
      branches use.
- [ ] Reuse the deferral-direction rule verbatim from the collision scan: `in_batch` defers only
      against a lower-numbered peer ITSELF admitted this cycle (reading the fold accumulator);
      `cross_batch` defers only on execution evidence, otherwise admits with an advisory.
- [ ] Bump `$schema` to `orchestrate-batch-admit-v7` at every literal site enumerated in step 1,
      including the test suite's `$schema`-literal pin.
- [ ] Update the script's own header field list and `defer_reason` enum documentation to describe
      the new reason, its payload fields, and that it has no override flag (matching
      `file_scope_collision`, `session_active`, and `absent_file_scope`, not `self_modifying`).
- [ ] Confirm the sentinel trips neither `validate-state.sh` Check 8 (it carries no trailing slash)
      nor Check 11 (it contains no glob metacharacter) by running
      `bash agent-system/extensions/core/scripts/validate-state.sh` against a state file seeded
      with a sentinel-carrying task.

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The `$schema` v6 -> v7 bump is hypothesized to touch a small, enumerable set
of literal sites (the gate script, its test suite's pin, and `docs/architecture/batch-admit-schema.md`).
Confirm by the grep in step 1 before editing; if the grep returns consumers outside this plan's
declared files, stop and record the finding rather than silently widening the edit.

**Tier Justification**: The verdict `$schema` literal and the `defer_reason` enum are consumed
across multiple files, so verification must cover this script plus its enumerated direct
dependents: `bash scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh,test-orchestrate-cycle-plan.sh`
plus `bash -n` on each edited script and a `validate-state.sh` run on a sentinel-seeded fixture.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - new last-ranked whole-tree
  claim dimension, `whole_tree_claim` verdict field, `$schema` v7 bump, header field/enum docs
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` - the reserved sentinel constant
  and a comment stating why a slashless token is inert in both the Overlap and Containment
  predicates
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - `$schema` literal
  pin updated v6 -> v7

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh,test-orchestrate-cycle-plan.sh`
  is fully green, including Phase 2's two previously-red cases and every existing-branch pin.
- `bash -n` passes on both edited scripts.
- `bash agent-system/extensions/core/scripts/validate-state.sh` against a sentinel-seeded fixture
  state file reports no Check 8 and no Check 11 finding for the sentinel entry.
- A fail-open spot check: invoking the gate with an unknown task number, a terminal-status task,
  and a task with absent `file_scope` each still ADMITs and never errors.

---

### Phase 5: Producer-side convention — plan format and planner contract [NOT STARTED]

**Goal**: Make the sentinel actually get declared. Without this phase, no plan ever emits it and the
gate dimension is dead code.

**Tasks**:

- [ ] Extend `context/formats/plan-format.md`'s `Files to modify` field definition with the
      whole-tree-claim rule: a phase whose steps invoke whole-tree regeneration (the deploy script,
      or the picker's reload/regenerate entries) MUST additionally declare the reserved sentinel as
      an entry in that phase's `Files to modify` block. State that the token is deliberately
      slashless so it is inert in both the Overlap and Containment predicates, and that it is
      harvested by the existing pipeline with no parser change.
- [ ] Add the same obligation to `agents/planner-agent.md`'s phase-construction stage, in the same
      register as its existing per-phase field obligations, so a generated plan carries the
      declaration by contract rather than by luck.
- [ ] Add a case to `scripts/tests/test-plan-file-scope-harvest.sh` confirming a backticked
      slashless reserved token in a `Files to modify` block harvests verbatim into the output array
      (the script is path-shape-agnostic; this pins that it stays so).
- [ ] Verify no task-number reference lands in any file under `agent-system/**`: describe the
      hazard by mechanism (a plan phase that regenerates the whole deployed tree), never by citing
      the archived task numbers that evidenced it.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-plan-file-scope-harvest.sh`
covers the one executable change, and the two markdown edits are covered by
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
(doc-lint and task-reference lint, with the explicit source-store TARGET the no-argument form would
silently skip).

**Files to modify**:

- `agent-system/extensions/core/context/formats/plan-format.md` - whole-tree-claim declaration rule
  inside the `Files to modify` field definition
- `agent-system/extensions/core/agents/planner-agent.md` - the matching per-phase authoring
  obligation
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` - case pinning that a
  slashless reserved token harvests verbatim

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-plan-file-scope-harvest.sh`
  is green including the new case.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
  passes.
- Reading `plan-format.md` and `planner-agent.md` back confirms the obligation is stated in both,
  with one spelling of the sentinel.

---

### Phase 6: Mechanism and non-goal documentation [NOT STARTED]

**Goal**: Record the new dimension, its reuse-vs-new-reason rationale, and the explicit non-goal, so
a future reader can check the invariant without re-deriving it.

**Tasks**:

- [ ] Add the v7 entry to `docs/architecture/batch-admit-schema.md`'s Version History and document
      the `whole_tree_claim` `defer_reason`, its payload fields, its last-ranked precedence, and its
      absence of an override flag.
- [ ] Add a subsection to `context/patterns/batch-orchestration-guardrails.md`, sibling to its
      existing self-modification hazard section: the whole-tree-claim convention, why it is a
      distinct hazard class from a declared-path collision, and the explicit non-goal — this does
      not close the stale-deploy READ hazard, which the inter-cycle redeploy checkpoint and the
      postflight completion-deploy gate already cover.
- [ ] Add a short note to `context/patterns/file-footprint-overlap.md` recording the reserved
      sentinel: why a slashless token is inert in the Overlap predicate and invisible to the
      Containment predicate, and that this inertness is what makes the convention adoptable before
      the gate that reads it ships.
- [ ] Update `docs/architecture/orchestrate-state-machine.md` where it enumerates the admission
      dimensions, so the count and the reason list stay accurate.
- [ ] Verify no task-number reference lands in any of these files; cite durable anchors (script
      names, section headings, the predicate names) instead.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Four documentation files are hypothesized to be the complete set that
enumerates admission dimensions or `defer_reason` values. Confirm with
`grep -rln 'absent_file_scope\|file_scope_collision' agent-system/extensions/core/context agent-system/extensions/core/docs`
before closing the phase; a fifth file naming the enum is in scope for this phase, not a reason to
defer.

**Tier Justification**: These are pure-guidance markdown edits with no executable surface, so the
covering check is the source-store gate subset
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
(doc-lint and task-reference lint) with the explicit TARGET; no test suite maps to these paths.

**Files to modify**:

- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - v7 Version History entry
  and the `whole_tree_claim` field documentation
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - the
  whole-tree-claim hazard subsection and its explicit non-goal
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - the reserved-sentinel
  inertness note
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - admission-dimension
  enumeration kept accurate

**Verification**:

- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4 /home/benjamin/.config/nvim/agent-system/extensions/core`
  passes.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the repo-wide equivalent)
  reports no new finding under `agent-system/**`.
- Each of the four files, read back, states the new reason or the non-goal it is responsible for.

---

### Phase 7: Redeploy and full gate [NOT STARTED]

**Goal**: Regenerate the deployed tree from the source store and prove the whole change set green
under the complete gate set.

**Tasks**:

- [ ] Confirm the working tree carries no uncommitted sibling-task edits before regenerating — the
      very hazard this task exists to prevent. If any are present, stop and record it rather than
      deploying over them.
- [ ] Run the whole-tree regeneration from the source store.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` with no gate narrowing.
- [ ] Run the full shell suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh` with no
      `--only` narrowing.
- [ ] Confirm the deployed copies of every edited file match the source store.

**Timing**: 0.75 hours

**Depends on**: 3, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration and therefore declares the reserved
  sentinel itself, per the convention Phase 5 establishes; the declaration is inert on the pre-fix
  gate and live once Phase 4 has shipped
- `agent-system/extensions/core/scripts/deploy-headless.sh` - read and invoked, not edited (listed
  so the phase's real footprint is honest)

**Verification**:

- `bash .claude/scripts/verify-deploy.sh` passes with every gate run, no narrowing.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` passes with no `--only` narrowing.
- The deployed `.claude/` copy of every file this plan edited is byte-identical to the source store
  (enumerate the set from the phase commits rather than from a count asserted here).
- `bash agent-system/extensions/core/scripts/validate-state.sh` passes.

---

## Testing & Validation

- [ ] ACCEPTANCE A(a): two tasks with disjoint real `file_scope`, both declaring the sentinel, are
      not co-dispatched into the same wave — demonstrated by the `WHOLE-TREE-CODISPATCH` fixture.
- [ ] ACCEPTANCE A(b): the verdict carries `defer_reason: "whole_tree_claim"`, a named
      machine-readable reason distinguishable from `file_scope_collision`, with its own payload
      fields.
- [ ] ACCEPTANCE A(c): `self_modifying`, `file_scope_collision`, `session_active`,
      `absent_file_scope`, and `idle_overlap_advisory` all keep their current semantics and output
      fields — pinned by the Phase 2 non-regression cases, which pass both before and after Phase 4.
- [ ] ACCEPTANCE A(d): an unknown task, a terminal-status task, and a task with missing or absent
      `file_scope` or no plan artifact each still ADMIT and never error.
- [ ] ACCEPTANCE B(a): an invocation whose `--force-phases` differs from the cached composition's
      does not replay.
- [ ] ACCEPTANCE B(b): a real-dispatch composition still caches and still replays on an unconsumed
      re-invocation — the no-charge benefit survives.
- [ ] ACCEPTANCE B(c): stdout is single-line JSON in both live and `--dry-run` mode, shape unchanged.
- [ ] ACCEPTANCE B(d): the write/clear pairing is stated in `orchestrate-cycle-plan.sh`'s own header.
- [ ] Full gate set and full shell suite green after redeploy (Phase 7).

## Artifacts & Outputs

- Updated `orchestrate-batch-admit.sh` with a fifth, last-ranked admission dimension and a v7
  verdict schema.
- Updated `orchestrate-cycle-plan.sh` with a tightened cache-write guard and a forced-phases cache
  key component.
- A reserved sentinel constant in `lib/file-scope-overlap.sh`.
- Producer-side convention in `plan-format.md` and `planner-agent.md`.
- Three extended test suites with red-baseline-then-green evidence.
- Four updated documentation surfaces, including the explicit non-goal record.
- A regenerated deployed tree.

## Rollback/Contingency

Every phase is a separate scoped commit, so any phase reverts independently with
`git revert <sha>` followed by a redeploy. Part A and Part B are in disjoint files and line ranges
(research confirmed no shared lines), so either part reverts without disturbing the other.

If the `$schema` v6 -> v7 enumeration in Phase 4 step 1 reveals consumers outside this plan's
declared files, stop at that step and record the finding: the dimension can ship without the bump
only if no strict consumer rejects an unknown `defer_reason`, which is itself a finding to verify
rather than assume.

If Phase 7's pre-deploy check finds uncommitted sibling edits, do not deploy. Record it and leave
the phase `[PARTIAL]` — that self-block is the correct behavior and is itself evidence for the
hazard this task addresses.
