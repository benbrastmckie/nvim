# Implementation Summary: Task #500

- **Task**: 500 - edge_backfill_unreachable_for_not_started
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T09:54:00Z
- **Completed**: 2026-11-11T10:50:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: 328, 430, 446, 448 (all completed/archived prior to this dispatch)
- **Artifacts**: plans/01_edge-only-admission-token.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`update-task-status.sh --depends-on-add` was structurally unreachable for a `not_started` task
because its status-no-op restriction requires an `operation:target_status` pair that resolves to
the task's own current status, and `map_status()`'s twelve arms never emitted `not_started`. This
implementation closed the gap via shape (a): a new no-op-only `preflight:edge_only` pair, refused
outright without `--depends-on-add`, that resolves `STATE_STATUS="not_started"`. Every existing
guarantee (no transition alongside an edge add, mandatory write-time cycle refusal, value/
self-edge/missing-predecessor refusals, union-merge idempotence, caller-owned drain confirmation)
is preserved unchanged and covered by new test cases. The suggester
(`orchestrate-suggest-next-batch.sh`) now resolves this token automatically instead of falling
back to propose-only for a `not_started` collision. The fix is deployed and proven end-to-end:
task 438 now depends on 500, added via the new `edge_only` pair, with task 438's status left at
`not_started`.

## What Changed

- `agent-system/extensions/core/scripts/update-task-status.sh` — new `preflight:edge_only` arm in
  `map_status()`; `edge_only` added to the `target_status` validation list, both usage lines, and
  the existing preflight-only guard (alongside `hold`/`unhold`); new edge-only refusal guard
  (`DEPENDS_ON_ADD_LEN == 0` with `target_status=edge_only` is a hard error); a `not_started`-only
  hint sentence appended to the pre-existing status-no-op refusal (D4 — every other status's
  message stays byte-identical); header-comment documentation of the new pair.
- `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` — fourth fixture entry
  (`not_started`, project_number 4), with entry 1's initial `dependencies` changed from `[]` to
  `[4]` to give the new cycle-refusal sub-case a real reverse edge; new Case 18 cluster (18a-18g,
  7 sub-cases) covering every acceptance guarantee on the new path; pre-existing Case 17 block
  re-run unchanged, confirming no regression.
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — new `not_started`
  case in `resolve_noop_token()` resolving to `preflight edge_only`; both `resolve_noop_token()`'s
  and `propose_edge_for_pair()`'s header comments corrected (no longer describe the `not_started`
  gap as current/genuine).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — new Case
  (b-not-started): both colliding fixture tasks at `not_started`; asserts the edge is written
  under `--write-edges`, both re-probe to `admit`, `dependencies[]` carries the edge, and neither
  status moves off `not_started`.
- `agent-system/extensions/core/context/patterns/multi-task-operations.md` — one new paragraph
  immediately after the "Direction cannot be inferred from task numbering" paragraph, naming the
  `preflight <n> edge_only <session_id> --depends-on-add=[...]` call shape for a `not_started`
  task and pointing to the flag's own header for the full guarantee set.
- `agent-system/extensions/core/index-entries.json` — `line_count` corrected for the
  `patterns/multi-task-operations.md` entry (684 → 691), scoped narrowly to that one entry.
- `specs/state.json` — task 438 gained the `500` dependency edge (`dependencies[]` now
  `[312,313,401,446,458,500]`); task 438's status unchanged at `not_started`.
- `specs/TODO.md` — regenerated as a side effect of the state write.
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`; all four touched scripts
  confirmed byte-identical between source store and deployed tree.

## Decisions

- Shape (a) (a new no-op-only `operation:target_status` pair) was adopted over shape (b)
  (a standalone operation) and shape (c) (a second entry point), per the plan's D1: shape (b)
  would require special-casing eleven live `target_status`-gated blocks in the same script and
  rewriting `resolve_noop_token()`/`propose_edge_for_pair()` for every status, not just one; shape
  (c) splits one primitive across two entry points.
- Token literal `edge_only` (D2), confirmed collision-free (the only textual hit in the whole
  tree is an unrelated test-fixture session name, `sess_edge_only`).
- The existing status-no-op refusal message is preserved byte-for-byte for every previously
  reachable status; the new hint sentence fires only when `current_state_status == "not_started"`
  (D4) — confirmed by Case 18g, which asserts the hint sentence is absent for a non-`not_started`
  task.
- No universal, dynamically-resolving edge-only token was built (D3, rejected) — the gap exists at
  exactly one status, so a fixed-`not_started` arm is the minimal fix.

## Plan Deviations

- **Phase 1** (premise re-validation): the plan's Premise Re-Validation table cited "the
  real-write site line ~1171" as a second `dependencies[]` union-merge site; re-measurement found
  line 1171 is actually a `FILE_SCOPE_ADD` merge in the real-write path, not a `dependencies[]`
  merge — `--depends-on-add`'s merge is reachable only via the no-op-replay site (line 1112),
  since the status-no-op restriction makes a real-transition + `--depends-on-add` call a hard
  validation error before any write function is reached. A citation imprecision in the plan's
  background table, not a script defect; recorded in `progress/phase-1-premise.json`.
- **Phase 2** (test fixture cycle construction): Case 18a/18f initially used predecessor task 2
  for the valid-acyclic `--depends-on-add` edge; this closed a real cycle (4→2→1→4, since entry 1
  already depends on entry 4 and entry 2 depends on entry 1), correctly triggering the
  cycle-refusal code rather than a test bug. Switched to predecessor 3 (no dependents, depends on
  nothing), which is genuinely acyclic.
- **Phase 3** (editing mechanics): a comment-block replacement momentarily duplicated
  `propose_edge_for_pair()`'s header comment during editing; caught by a `grep -n 'genuine'`
  check and consolidated back to one block before proceeding.
- **Phase 4** (unplanned doc-addition side effect): the plan's task list said to leave
  `index-entries.json` untouched unless the topical summary changed. The one-paragraph addition
  to `multi-task-operations.md` (684→691 lines) tripped the file's own `line_count` drift check
  (Rule R) at verification time. Corrected the one affected entry via the sanctioned remedy
  script, scoped narrowly; a second, unrelated pre-existing drift the same script run also wanted
  to "fix" (`formats/issue-log.md`, 275→280, predates this dispatch) was deliberately reverted
  out of the diff before committing, since it is out of this task's scope.
- **Phase 5** (verification-tier discharge): per the dispatch file's `## Batch Gate Deferral`
  section, the full `verify-deploy.sh` (no `--skip-slow`) and full `run-all.sh` sweep were
  deferred to the once-per-batch stage rather than independently run in this dispatch. Discharged
  instead against the scoped narrowing invocation
  (`run-all.sh --only test-update-task-status.sh,test-orchestrate-suggest-next-batch.sh`, from
  the deployed tree: 2 passed, 0 failed) plus `validate-state.sh --deep` run directly both pre-
  and post-edge (20 passed, 7 warnings, 0 failed each time) — see the plan's Phase 5 `#### Reasoned
  Exclusions` table for the full record, including a second, independent exclusion
  (`deploy-headless.sh`'s internal fast-gate check surfaced a pre-existing, documented,
  unrelated gate-24 finding in the memory extension's docs).

## Verification

- Build: N/A (shell scripts; `bash -n` clean on all four modified scripts)
- Shellcheck: `lint-shellcheck.sh` exits 0 on all four modified scripts, zero findings
- Tests:
  - `test-update-task-status.sh`: 82 passed, 0 failed (full suite, including the pre-existing
    Case 17 block re-run unchanged, and the new Case 18 cluster 18a-18g)
  - `test-orchestrate-suggest-next-batch.sh` (`CORE_TEST_SUBJECT_MODE=source-store`): 14 passed,
    0 failed (including the new Case (b-not-started))
  - Both suites re-run from the deployed tree post-redeploy (no `CORE_TEST_SUBJECT_MODE`
    override): 2 passed, 0 failed (`run-all.sh --only`), confirming the deployed copy carries the
    fix
  - `agent-system/extensions/core/scripts/tests/run-all.sh --only` (the 20-suite list named in
    Phase 2's Tier Justification, covering `scripts/update-task-status.sh`): 17 passed, 3 failed
    — all 3 pre-existing and documented in `known-failures.txt`
    (`test-orchestrate-cycle-postflight.sh`, `test-postflight-deploy-gate.sh`,
    `test-redeploy-checkpoint-promotion.sh`, all `real-defect|needs-owner`, unrelated to
    source-store/extensions-root resolution or this fix), 0 NEW
- `validate-state.sh --deep`: 20 passed, 7 warnings, 0 failed — both pre-edge and post-edge
- Files verified: Yes (all four scripts confirmed byte-identical between source store and
  deployed tree post-redeploy)

## Acceptance Checklist (dispatch description's 7 items)

1. **`--depends-on-add` succeeds against a `not_started` task in a fixture, adding the edge and
   leaving the task's status still `not_started`.** Confirmed by Case 18a:
   `preflight 4 edge_only ... --depends-on-add='[3]'` → `dependencies[4]` becomes `[3]`, status
   stays `not_started`. Confirmed live by the real end-to-end call below.
2. **The same call still refuses, with its existing error text, any attempt to combine an edge
   add with a real status transition.** Confirmed by Case 17g (pre-existing, re-run unchanged)
   and Case 18g (edge_only against a non-`not_started` task): both exit nonzero with the
   byte-identical `"...CURRENT status (a no-op replay)..."` message; Case 18g additionally
   asserts the new hint sentence is absent for this status.
3. **The write-time cycle refusal still fires on a candidate edge that would create a cycle,
   including on a `not_started` target, and still fails closed when `validate-state.sh` cannot be
   run.** Confirmed by Case 18d (real path and `--dry-run`, both refused, state unchanged,
   `"Dependency cycle detected..."` named) and by the pre-existing fail-closed guard, unchanged by
   this fix (the new arm reuses the identical cycle-check code path).
4. **Malformed value, self-edge, and missing-predecessor refusals all still exit 1 with their
   existing messages; a repeated call is still idempotent.** Confirmed by Case 18e (all three
   refusals, state unchanged) and Case 18f (repeated identical call is a byte-for-byte no-op).
5. **End-to-end, on the two real edges this gap blocked**: the 438→500 edge was added live —
   `preflight 438 edge_only <session_id> --depends-on-add='[500]'`, dry-run previewed
   `[312,313,401,446,458] → [312,313,401,446,458,500]`, the real call succeeded, and 438's
   resulting `dependencies[]` is **`[312,313,401,446,458,500]`**, status unchanged at
   `not_started`. The 421→497 edge was **not attempted**: 497 (`promote_telemetry_submodes_to_core`)
   has completed and archived out of `active_projects` (confirmed in `specs/archive/state.json`),
   so `--depends-on-add`'s missing-predecessor refusal (scoped to `active_projects`) would refuse
   the call regardless of this fix, and the RELOCATE-FIRST ordering the edge existed to enforce is
   already satisfied in fact. 421's `dependencies[]` is confirmed unchanged at **`[312,402]`**.
6. **`validate-state.sh` passes over the resulting `state.json` with zero failures.** Confirmed:
   20 passed, 7 warnings (all pre-existing, unrelated to this task — `audit_override`/
   `audit_verdict` unknown-field warnings and coarse `file_scope` warnings on unrelated tasks), 0
   failed, both before and after the 438→500 edge write.
7. **Re-verify every quoted error string, header sentence, and `map_status()` arm cited in this
   description against the tree as it then stands.** Done in Phase 1 (`progress/phase-1-premise.json`):
   exactly 12 `map_status()` arms confirmed, none resolving to `not_started`; the status-no-op
   refusal message, the write-time-cycle fail-closed message, and the 9-value `target_status`
   validation list all confirmed byte-identical to the dispatch's quotes; `edge_only` confirmed
   collision-free; one citation imprecision found and corrected (see Plan Deviations, Phase 1).

## Impacts

- A `not_started` task — the status most edges are backfilled onto — can now receive a
  `--depends-on-add` edge through the sanctioned script, closing a real backlog-ordering
  regression (task 438 can now declare its dependency on this task).
- `orchestrate-suggest-next-batch.sh` no longer falls back to propose-only for a `not_started`
  file_scope collision; it writes the edge and re-probes automatically, matching its behavior for
  every other status.
- No existing guarantee, call shape, or error message changed for any previously-reachable
  status.

## Follow-ups

- None required by this task. Task 438 (`dependency_edge_rationale_semantic_check`) may now gain
  its own edge onto this task through the same newly-reachable mechanism, per the dispatch's
  ordering note — that edge is a separate task's own action, not part of this implementation's
  acceptance list.

## References

- `specs/500_edge_backfill_unreachable_for_not_started/reports/01_depends-on-add-not-started-gap.md`
- `specs/500_edge_backfill_unreachable_for_not_started/plans/01_edge-only-admission-token.md`
- `specs/500_edge_backfill_unreachable_for_not_started/progress/phase-1-premise.json`
  through `phase-5-progress.json`
