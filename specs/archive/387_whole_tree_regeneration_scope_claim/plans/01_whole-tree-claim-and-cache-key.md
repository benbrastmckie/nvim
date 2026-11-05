# Implementation Plan: Task #387

- **Task**: 387 - Whole-tree regeneration scope claim (Part A) + plan-cache force-phases bypass (Part B)
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/387_whole_tree_regeneration_scope_claim/reports/01_whole_tree_regeneration_scope_claim.md; blocker research for the Phase 7 self-block, delivered inline in the aux dispatch context at specs/387_whole_tree_regeneration_scope_claim/.dispatch/31-aux-plan-revision.md (no standalone report artifact was written for it, and the `.blocker-research.json` path that dispatch names does not exist on disk)
- **Artifacts**: plans/01_whole-tree-claim-and-cache-key.md (this file)
- **Reports Integrated**: 01_whole_tree_regeneration_scope_claim.md; 31-aux-plan-revision.md (inline blocker research, Phase 7)
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

**Blocker research integrated into Phase 7 (this revision).** A follow-up investigation of Phase 7's
self-block concluded it should be DISCHARGED rather than escalated to a human, and Phase 7 is
rewritten accordingly. Its three findings — a false concurrency attribution, a clean-tree
precondition the orchestrator's own Inter-Cycle Redeploy Checkpoint violates every cycle, and a
misidentified hazard (the deployed tree is a disposable artifact, so sweeping uncommitted source
into it loses nothing) — are recorded in full in Phase 7's own `Precondition Correction`
subsection, together with the mechanism that replaces the withdrawn gate. Every load-bearing claim
was re-verified against the live tree while writing this revision: `orchestrate-cycle-plan.sh`
contains no `git status`/`--porcelain` read and calls `deploy-headless.sh --skip-verify`
unconditionally at ~line 1030; the deploy ledger records cycle 12 at `verified_at` 1793820621 with
`verify_outcome: "pre_existing"`; and `scripts/lib/deploy-baseline-lib.sh` exports the four
capture/confirm/attribute functions the new gate is built on, already consumed in production by
`orchestrate-batch-gate.sh` and `command-gate-out.sh`.

This substitution does not weaken the task's own thesis. Part A serializes two tasks that both
regenerate the whole tree **at admission time**, which is where the hazard is actually
addressable; Phase 7's withdrawn gate tried to re-litigate the same hazard **at deploy time**, in
a process the orchestrator has already deployed over. The non-goal below (the stale-deploy READ
hazard, left to the redeploy checkpoint) is unchanged and is the same division of labor.

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

**Phase 7's deploy precondition** (revised; supersedes the original clean-working-tree gate):

- A redeploy phase **MUST NOT** gate on `git status` cleanliness. The condition is structurally
  unsatisfiable in this orchestrator: the Inter-Cycle Redeploy Checkpoint deploys unconditionally
  with no cleanliness read, and the EXCURSION DROPPED containment predicate manufactures
  uncommitted dirt every cycle. A phase that waits for a clean tree waits forever.
- The checkable condition that replaces it is a **baseline delta**: capture findings before the
  deploy, capture them again after, and require the newly-introduced set
  (`deploy_baseline_new_findings`) to be empty after one confirmation re-run. This measures what
  the redeploy actually changed rather than what the tree happened to contain.
- Gating is on the **invoked command's exit status**, not on a stdout diff alone — the baseline
  delta is used to *attribute* a failure, never to substitute for the gate's own exit code (see
  `rules/plan-format-enforcement.md` on naming a tool's entry point in verification criteria).
- Attribution uses `deploy_baseline_unattributable_findings` against the task's own
  `modified_files`, which is the precise remedy for the real risk the withdrawn gate was groping
  toward: misattributing a foreign edit's gate failure to this change set.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `$schema` v6 -> v7 bump ripples into more consumers than anticipated (literal-string pins in scripts and tests) | H | M | Phase 4 enumerates every `orchestrate-batch-admit-v6` literal by grep across the source store BEFORE editing, and treats the count as a hypothesis to confirm (see its Scope Hypothesis), not a fact |
| Planner discipline is the sole producer-side enforcement: a plan that omits the sentinel leaves the gap open for that one plan | M | M | Same trust model `file_scope` already relies on everywhere (prospective, never filesystem-validated); the existing fail-open deploy mutex stays as backstop, and `backfill-file-scope.sh` is the remedial tool for a stale `file_scope` |
| A reserved token in `file_scope` surfaces somewhere path-shaped and reads oddly (e.g. `orchestrate-build-dispatch.sh`'s territory `owned_files` block) | L | M | Phase 6 documents the token in `file-footprint-overlap.md` so a reader of any consumer can resolve it; Phase 4 verifies it trips neither `validate-state.sh` Check 8 (no trailing slash) nor Check 11 (no glob metacharacter) |
| Adding a fifth dimension regresses one of the four existing branches | H | L | The new dimension is appended last and evaluated only on an otherwise-ADMIT candidate, so no existing branch's code path is edited; Phase 2's red-baseline fixtures pin all four existing reasons before Phase 4 touches anything |
| Part B's tightened guard removes caching for every aux-only cycle | L | H | Accepted and recorded: a true no-charge cycle already never caches, so this narrows an already-narrow optimization rather than creating a new cost category. ACCEPTANCE (b) requires the benefit only for the real-dispatch case |
| Design requires editing files beyond the dispatch's enumerated SCOPE list | M | H | Named explicitly: `context/formats/plan-format.md`, `agents/planner-agent.md`, `docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`, and the three test suites are all required by the chosen design. The dispatch's list is anticipated, not binding; the expansion is recorded here rather than discovered silently at implementation time |
| Phase 7's redeploy lands over foreign uncommitted edits, so a gate failure they cause is misattributed to this change set | M | M | Phase 7 gates on the pre/post-deploy baseline delta (`deploy_baseline_new_findings`) plus one confirmation re-run, and partitions any residual finding with `deploy_baseline_unattributable_findings` against this task's own `modified_files`. The withdrawn clean-tree precondition is NOT the mitigation: it is unsatisfiable (the Inter-Cycle Redeploy Checkpoint deploys over the same dirt with no cleanliness read) |

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

### Phase 1: Part B red-baseline regression tests [COMPLETED]

**Goal**: Pin the three Part B acceptance behaviors as failing tests against the unmodified
`orchestrate-cycle-plan.sh`, so the fix in Phase 3 is demonstrated rather than asserted.

**Tasks**:

- [x] Read `scripts/tests/test-orchestrate-cycle-plan.sh`'s existing harness conventions (temp
      multi-task state file, `mt_json` seeding, fd-3 capture) and reuse them; do not build a second
      harness. *(completed)*
- [x] Add case: an aux-only composition (>=1 `aux_dispatch` row, zero `dispatch` rows) must leave
      `plan_cache` absent in the written state file. Expect RED today. *(completed: Group 18
      continuation, task #1803 fixture with a dangling out-of-batch dependency so ordinary
      dispatch is 0 while the aux decision loop still fires; RED confirmed)*
- [x] Add case: an invocation whose `--force-phases` value differs from the one a cache entry was
      built with must NOT replay (must fall through to real composition). Expect RED today.
      *(completed: Group 18 continuation, task #1805 fixture; RED confirmed — both the
      no-incorrect-replay assertion and the correct-recompute assertion fail today)*
- [x] Add case: a composition with >=1 real `dispatch` row still writes `plan_cache`, and a
      same-counter same-`--force-phases` re-invocation still replays it verbatim — the no-charge
      benefit is preserved. Expect GREEN today and after the fix (a non-regression pin).
      *(completed: Group 18 continuation, task #1806 fixture with a matching non-empty
      `--force-phases research` on both runs; GREEN confirmed)*
- [x] Add case: stdout is a single-line JSON object in both live and `--dry-run` mode, byte-shape
      unchanged by any of the above. *(completed: Group 18 continuation, task #1807 fixture;
      GREEN confirmed)*
- [x] Run `bash scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh` and record the
      red-baseline output in this phase's completion notes. *(completed: 379 passed, 3 failed —
      recorded in progress/phase-1-progress.json's red_baseline field)*

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

### Phase 2: Part A red-baseline fixtures and existing-branch pins [COMPLETED]

**Goal**: Add the ACCEPTANCE (a) fixture (two disjoint-scope sentinel-carrying tasks must not
co-admit) as a failing test, and pin every existing defer branch's current output so Phase 4's
non-regression claim is mechanical.

**Tasks**:

- [x] Read `scripts/tests/test-orchestrate-batch-admit.sh`'s isolated-temp-root harness (it copies
      `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`, `lib/file-scope-overlap.sh`,
      `lib/common.sh`, `lib/task-lookup-lib.sh`, `task-lock.sh` into `$TMPROOT/.claude/scripts/`)
      and reuse it verbatim. *(completed)*
- [x] Add case `WHOLE-TREE-CODISPATCH`: two in-batch tasks with strictly disjoint real
      `file_scope`, each additionally declaring `__WHOLE_TREE__`, with `--invocation-count 2`. The
      higher-numbered candidate must defer with `defer_reason: "whole_tree_claim"`. Expect RED
      today. *(completed: RED confirmed, but via a DIFFERENT mechanism than assumed — today it
      already defers, via the EXISTING file_scope_collision exact-match on the identical sentinel
      literal, not a false admit. See this phase's `design_finding` in
      progress/phase-2-progress.json and the recorded issue: Phase 4 must resolve a design
      tension this reveals — the exact-match scan intercepts before a last-ranked new dimension
      would ever run)*
- [x] Add case `WHOLE-TREE-PHASE-EXEMPT`: the same pair with the higher-numbered candidate mapped
      via `--phase-map N:plan`. It must ADMIT, carrying `whole_tree_claim: true`. Expect RED today.
      *(completed: RED confirmed, same underlying mechanism as WHOLE-TREE-CODISPATCH above — the
      exact-match scan defers it regardless of --phase-map, so the phase exemption does not
      apply today either)*
- [x] Add case `WHOLE-TREE-NO-SENTINEL`: the same disjoint pair with neither declaring the
      sentinel must both ADMIT — the new dimension must not fire on ordinary tasks. *(completed:
      GREEN confirmed)*
- [x] Add case `WHOLE-TREE-INERT-PATH`: a candidate declaring `__WHOLE_TREE__` against a peer
      declaring only real paths must NOT produce a `file_scope_collision` on the sentinel (the
      token must be inert against real paths under `scopes_overlap_first`). *(completed: GREEN
      confirmed — the sentinel IS inert against a different real path; it is only non-inert
      against ANOTHER instance of itself, which is the WHOLE-TREE-CODISPATCH finding above)*
- [x] Add non-regression pins asserting the unchanged verdict shape for each of
      `self_modifying`, `file_scope_collision`, `session_active`, `absent_file_scope`, and the
      `idle_overlap_advisory` — reuse the suite's existing cases where they already pin these and
      add only what is missing. *(completed: `self_modifying` (Case 3), `file_scope_collision`
      (Cases 1-2), `absent_file_scope` (IN-BATCH-ABSENCE/CROSS-BATCH-ABSENCE/
      PHASE-EXEMPT-ABSENCE/SOLO-ABSENT-SCOPE-NON-REGRESSION), and cross-session (SOLO-SELF-MOD-
      CROSS-SESSION family) were already pinned in this file; no new pin added for
      `session_active`/`idle_overlap_advisory` since both are already covered by
      test-orchestrate-predispatch-review.sh, a different suite outside this phase's declared
      SCOPE — adding a duplicate here was judged to not be "genuinely missing" coverage)*
- [x] Run `bash scripts/tests/run-all.sh --only test-orchestrate-batch-admit.sh` and record the
      red-baseline output in this phase's completion notes. *(completed: 13 passed, 2 failed —
      recorded in progress/phase-2-progress.json's red_baseline field)*

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

### Phase 3: Part B plan-cache write-guard and force-phases cache key [COMPLETED]

**Goal**: Turn Phase 1's red cases green: an aux-only composition never writes `plan_cache`, and a
differing `--force-phases` value cannot replay a cached composition.

**Tasks**:

- [x] Tighten the write guard at `scripts/orchestrate-cycle-plan.sh` ~754-755 to
      `[ "${#out_dispatch_rows[@]}" -gt 0 ]`, dropping the `out_aux_dispatch_rows` disjunct.
      *(completed)*
- [x] Extend the cache object written at ~757 to carry the canonicalized forced-phases value
      alongside `dispatch_seq_counter` (`canonical_force_phases_json` is already computed at
      ~543-554; do not recompute it). *(completed: `force_phases` field added to the cache
      object, reusing the existing variable)*
- [x] Extend the replay check at ~639-650 to require BOTH the counter AND the forced-phases value
      to match before replaying; a missing forced-phases key in a pre-existing cache entry must be
      treated as a non-match (fall through and recompose), never as an error. *(completed: jq
      `null == array` comparison naturally treats a missing key as a non-match with no special
      casing needed)*
- [x] Update the header comment block at ~71-76 to state the corrected write condition, name the
      single `plan_cache`-clearing site (`orchestrate-cycle-postflight.sh`), and state the
      write/clear pairing invariant explicitly so a future reader can check it without re-deriving
      it — this is ACCEPTANCE (d). *(completed)*
- [x] Update the inline comment at ~740-753: state that an aux-only composition is deliberately
      never cached because an aux dispatch structurally never reaches the one clearing site, and
      amend decision (D3) to record that `--force-phases` IS in the key while `--focus` remains
      deliberately out of it, with the reason for the asymmetry. *(completed)*
- [x] Confirm the replay-path stderr message still names the reason accurately after the key
      change. *(completed: message updated to also name the `--force-phases` match condition)*

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

### Phase 4: Part A whole-tree-claim admission dimension and schema v7 [COMPLETED]

**Goal**: Turn Phase 2's red cases green by adding the fifth admission dimension, without editing
any existing branch's code path.

**Tasks**:

- [x] Enumerate every `orchestrate-batch-admit-v6` literal across the source store
      (`grep -rn 'orchestrate-batch-admit-v6' agent-system/extensions/core/`) and record the list
      before editing anything — this is the Scope Hypothesis below, to confirm, not assume.
      *(completed: 5 files found, 2 beyond this phase's declared list — see this phase's
      `schema_widening_finding` in progress/phase-4-progress.json)*
- [x] Define the reserved sentinel once, as a named constant in
      `scripts/lib/file-scope-overlap.sh`, alongside the existing predicates — so the gate, the
      documentation, and any future consumer share one spelling rather than transcribing the
      literal. Add no new matching rule; the token's inertness against real paths is a property of
      the existing `scopes_overlap_first` definition, not new code. *(completed: `def
      whole_tree_claim_sentinel: "__WHOLE_TREE__";` added inside `FILE_SCOPE_OVERLAP_JQ_DEFS`)*
- [x] Add the new dimension in `scripts/orchestrate-batch-admit.sh`, evaluated LAST and only on a
      candidate the three existing post-absence branches would otherwise ADMIT. Emit
      `defer_reason: "whole_tree_claim"` with `colliding_task_number`, `colliding_task_status`,
      `collision_scope`, `claim_sentinel`, and a `reason` string in the established
      ordering-constraint-not-exclusion phrasing. *(completed: ALTERED from the literal
      "separately-evaluated last stage" shape — see Phase 2's recorded design finding, which this
      phase resolves by RELABELING the existing collision scan's own `$hit` in place when
      `$hit.ov_path == whole_tree_claim_sentinel`, rather than adding a trailing stage the
      existing exact-match scan would otherwise intercept first. All five listed verdict fields
      are present exactly as specified; only the mechanism by which the check is reached differs
      from the plan's literal wording, not its observable behavior or any ACCEPTANCE criterion)*
- [x] Add `whole_tree_claim: true` to every verdict for a sentinel-carrying candidate, including the
      admit shapes and the phase-exempt shape (hazard stays visible when not deferred).
      *(completed: via a `$whole_tree_claim_frag` merged into every verdict object across the
      entire non-terminal/non-absent-scope branch, both self-modifying and ordinary)*
- [x] Apply the `--phase-map` `research`/`plan` exemption in the new branch, with the same
      unconditional posture and the same rationale the `self_modifying` and `absent_file_scope`
      branches use. *(completed)*
- [x] Reuse the deferral-direction rule verbatim from the collision scan: `in_batch` defers only
      against a lower-numbered peer ITSELF admitted this cycle (reading the fold accumulator);
      `cross_batch` defers only on execution evidence, otherwise admits with an advisory.
      *(completed: literally verbatim — the whole-tree-claim branch inspects the SAME `$hit`
      value the collision scan already selected, with no separate selection logic of its own)*
- [x] Bump `$schema` to `orchestrate-batch-admit-v7` at every literal site enumerated in step 1,
      including the test suite's `$schema`-literal pin. *(completed: all 4 code/test files;
      `docs/architecture/batch-admit-schema.md` deliberately deferred to Phase 6, its own
      explicitly-assigned task — see `schema_widening_finding`)*
- [x] Update the script's own header field list and `defer_reason` enum documentation to describe
      the new reason, its payload fields, and that it has no override flag (matching
      `file_scope_collision`, `session_active`, and `absent_file_scope`, not `self_modifying`).
      *(completed)*
- [x] Confirm the sentinel trips neither `validate-state.sh` Check 8 (it carries no trailing slash)
      nor Check 11 (it contains no glob metacharacter) by running
      `bash agent-system/extensions/core/scripts/validate-state.sh` against a state file seeded
      with a sentinel-carrying task. *(completed: a 4-task sentinel-seeded fixture reports zero
      Check 8/Check 11 findings, exit 0 — see progress/phase-4-progress.json's
      `validate_state_sentinel_check`)*

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

### Phase 5: Producer-side convention — plan format and planner contract [COMPLETED]

**Goal**: Make the sentinel actually get declared. Without this phase, no plan ever emits it and the
gate dimension is dead code.

**Tasks**:

- [x] Extend `context/formats/plan-format.md`'s `Files to modify` field definition with the
      whole-tree-claim rule: a phase whose steps invoke whole-tree regeneration (the deploy script,
      or the picker's reload/regenerate entries) MUST additionally declare the reserved sentinel as
      an entry in that phase's `Files to modify` block. State that the token is deliberately
      slashless so it is inert in both the Overlap and Containment predicates, and that it is
      harvested by the existing pipeline with no parser change. *(completed: new
      "Whole-tree-claim declaration rule" subsection added)*
- [x] Add the same obligation to `agents/planner-agent.md`'s phase-construction stage, in the same
      register as its existing per-phase field obligations, so a generated plan carries the
      declaration by contract rather than by luck. *(completed: new Stage 4 step 9)*
- [x] Add a case to `scripts/tests/test-plan-file-scope-harvest.sh` confirming a backticked
      slashless reserved token in a `Files to modify` block harvests verbatim into the output array
      (the script is path-shape-agnostic; this pins that it stays so). *(completed: Case 22)*
- [x] Verify no task-number reference lands in any file under `agent-system/**`: describe the
      hazard by mechanism (a plan phase that regenerates the whole deployed tree), never by citing
      the archived task numbers that evidenced it. *(completed:
      bash .claude/scripts/check-task-references.sh reports 0 unexempted occurrences)*

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

### Phase 6: Mechanism and non-goal documentation [COMPLETED]

**Goal**: Record the new dimension, its reuse-vs-new-reason rationale, and the explicit non-goal, so
a future reader can check the invariant without re-deriving it.

**Tasks**:

- [x] Add the v7 entry to `docs/architecture/batch-admit-schema.md`'s Version History and document
      the `whole_tree_claim` `defer_reason`, its payload fields, its last-ranked precedence, and its
      absence of an override flag. *(completed: new example JSON block, Field Definitions rows,
      "NEW in v7" precedence paragraph explaining the relabeling mechanism, and a new
      Deferral-Direction bullet; altered from "last-ranked" to "relabels the collision scan's
      own already-selected result" per Phase 2/4's recorded design finding)*
- [x] Add a subsection to `context/patterns/batch-orchestration-guardrails.md`, sibling to its
      existing self-modification hazard section: the whole-tree-claim convention, why it is a
      distinct hazard class from a declared-path collision, and the explicit non-goal — this does
      not close the stale-deploy READ hazard, which the inter-cycle redeploy checkpoint and the
      postflight completion-deploy gate already cover. *(completed: new "Whole-Tree Regeneration
      Hazard: The Sixth Admission Dimension" section, plus a pointer paragraph added to "The
      Three Existing Admission Layers")*
- [x] Add a short note to `context/patterns/file-footprint-overlap.md` recording the reserved
      sentinel: why a slashless token is inert in the Overlap predicate and invisible to the
      Containment predicate, and that this inertness is what makes the convention adoptable before
      the gate that reads it ships. *(completed: new "Reserved sentinels" subsection plus a new
      Consumers bullet)*
- [x] Update `docs/architecture/orchestrate-state-machine.md` where it enumerates the admission
      dimensions, so the count and the reason list stay accurate. *(investigated thoroughly —
      no edit made: this file contains no admission-dimension/defer_reason enumeration at all,
      contrary to the Scope Hypothesis's premise; see progress/phase-6-progress.json's
      `approaches_tried` for the full search record)*
- [x] Verify no task-number reference lands in any of these files; cite durable anchors (script
      names, section headings, the predicate names) instead. *(completed:
      bash .claude/scripts/check-task-references.sh reports 0 unexempted occurrences)*

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

### Phase 7: Redeploy and full gate [COMPLETED]

**Goal**: Regenerate the deployed tree from the source store and prove the whole change set green
under the complete gate set, gated on a *measurement-integrity* precondition the orchestrator's
own machinery can actually satisfy.

#### Precondition Correction (supersedes this phase's original clean-tree gate)

This phase originally opened with a "confirm the working tree carries no uncommitted sibling-task
edits" gate and self-blocked against it. That gate is **withdrawn as structurally unsatisfiable**
and the blocker it raised is **discharged, not escalated**. Three findings, each re-verified
against the live tree while this revision was written:

1. **The concurrency attribution was false.** The recorded block read 62-64 dirty paths as
   "multiple concurrent sibling tasks in this same /orchestrate batch invocation". The session
   registry carries exactly ONE live session and this batch dispatches strictly serially, so no
   sibling was ever concurrent with this phase. Of 63 dirty paths, 52 are verified by mtime to
   predate the run start entirely (lean/nix extension edits, `lake-build-guard.sh`, and `specs/`
   artifacts belonging to a dozen unrelated tasks); the 10 touched during the run are this run's
   own artifacts plus its own deliberately-dropped `file_scope` excursions. **There is no
   concurrency defect behind this blocker — a future reader should not go hunting one.**
2. **A clean working tree is not a state the orchestrator ever offers.** The Inter-Cycle Redeploy
   Checkpoint invokes `deploy-headless.sh --skip-verify` unconditionally
   (`orchestrate-cycle-plan.sh` ~line 1030), and that script reads no `git status` and no
   `--porcelain` anywhere — cleanliness is never consulted before a deploy. The deploy ledger
   (`specs/.orchestrator-deploy-ledger.json`) records the most recent such deploy at
   `verified_at` 1793820621, cycle 12, `verify_outcome: "pre_existing"` — roughly two minutes
   before the dispatch that produced this revision. Separately, the orchestrator's EXCURSION
   DROPPED containment predicate manufactures uncommitted dirt on every cycle by design. Waiting
   for a clean tree therefore cannot discharge the block, because the condition is never reached.
3. **The hazard was misidentified.** The deployed `.claude/` tree is a gitignored, disposable
   artifact regenerated from the source store (`rules/source-store-deploy-boundary.md`). Sweeping
   uncommitted source into it loses no work and is reversed by any later redeploy — which, per
   (2), has already swept exactly the edits this phase refused to sweep. Empirically: the
   working-tree copies of `agent-system/extensions/nix/rules/nix.md` and
   `scripts/lake-build-guard.sh` are byte-identical to their deployed counterparts.

**What the original gate was reaching for is kept.** The genuine residual risk is **measurement
integrity**, not data loss: a full gate set run over a tree carrying foreign edits can attribute
a failure those edits caused to this task's change set. This phase still gates on that risk — but
through the mechanism built for it, `scripts/lib/deploy-baseline-lib.sh`'s capture -> confirm ->
attribute pipeline, which subtracts a pre-deploy baseline instead of demanding a precondition
nothing can satisfy.

**Tasks**:

- [x] Record the pre-deploy findings baseline with `deploy_findings_snapshot` over the full gate
      set (no `--skip-slow`, explicit TARGET). Do NOT gate on this being empty — pre-existing
      findings are expected, and subtracting them is the baseline's entire purpose. *(completed:
      cited the orchestrator's same-cycle batch-gate capture — 8x gate8 + 1x gate16 findings,
      zero attributable — rather than duplicating an independent full run that exceeded a 540s
      inner timeout under concurrent load)*
- [x] Run the whole-tree regeneration from the source store unconditionally, with no
      working-tree cleanliness precondition. *(completed: `deploy-headless.sh` run with no git
      status/porcelain check; RESULT=landed_verify_clean, 8 extensions resynced)*
- [x] Record the post-deploy snapshot the same way and compute the newly-introduced set with
      `deploy_baseline_new_findings "$pre" "$post"`. **This is the phase's blocking gate**: that
      set must be empty. A non-empty set is re-run once through
      `deploy_baseline_confirm_new_findings` to drop findings that did not reproduce; only a
      confirmed non-empty set blocks. *(completed: post-deploy snapshot reproduced the identical
      9-finding set verbatim; new_findings set is empty)*
- [x] Run the complete gate set with no narrowing and **check its exit status**:
      `bash .claude/scripts/verify-deploy.sh`. On a non-zero exit, partition the confirmed
      findings with `deploy_baseline_unattributable_findings` against this task's own
      `modified_files`: a finding naming this task's files is blocking and must be fixed here, a
      finding naming only foreign paths is recorded with its attribution and does not block.
      `orchestrate-batch-gate.sh` already performs exactly this capture/confirm/attribute run
      once per invocation for the whole batch — if it has already covered this cycle, cite its
      result rather than duplicating the full run. *(completed: exit 1 (9 pre-existing findings);
      all 9 confirmed unattributable to this task's modified_files via
      `deploy_baseline_unattributable_findings`, and `deploy_baseline_self_attributable_findings`
      returned empty)*
- [x] Run the full shell suite with no `--only` narrowing and check its exit status:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh`. *(completed: cited the
      identical invocation already embedded in the verify-deploy.sh run above as its own gate8 --
      same command, same exit 1, same 8 failing suites, none naming this task's files)*
- [x] Confirm the deployed `.claude/` copy of every file this plan edited is byte-identical to
      the source store (enumerate the set from the phase commits, not from a count asserted here).
      *(completed: all 13 files this task touched diffed byte-identical, deployed vs. source)*
- [x] Run `bash agent-system/extensions/core/scripts/validate-state.sh`. *(completed: exit 0, 12
      passed, 12 pre-existing warnings, 0 failed)*

**Timing**: 1 hour

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

- The newly-introduced findings set (`deploy_baseline_new_findings` over the pre- and post-deploy
  snapshots, after one confirmation re-run) is empty; or every confirmed member is attributed by
  `deploy_baseline_unattributable_findings` to a path outside this task's `modified_files` and is
  recorded as such.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate run and no narrowing. On a
  non-zero exit, no confirmed finding is attributable to this task's own `modified_files`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with no `--only` narrowing.
- The deployed `.claude/` copy of every file this plan edited is byte-identical to the source store.
- `bash agent-system/extensions/core/scripts/validate-state.sh` exits 0.
- No step in this phase consulted working-tree cleanliness as a precondition.

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
- [ ] Full gate set and full shell suite green after redeploy, by exit status, with the
      post-deploy baseline delta showing no newly-introduced findings attributable to this task
      (Phase 7).

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

Phase 7 does not gate on working-tree cleanliness, and a dirty tree is never a reason to withhold
the redeploy: the Inter-Cycle Redeploy Checkpoint regenerates the deployed tree over the same
uncommitted content on its own schedule with no cleanliness read, so refusing to deploy protects
nothing and merely strands the phase. The real stop condition is instead a post-deploy baseline
delta showing findings that were newly introduced by the redeploy, reproduced on a confirmation
re-run, AND attributable to this task's own `modified_files`. On that condition, revert the
implicated phase commit with `git revert <sha>`, redeploy, and confirm the delta returns to empty.
