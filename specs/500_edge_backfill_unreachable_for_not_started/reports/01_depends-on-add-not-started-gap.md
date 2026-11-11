# Research Report: Task #500

**Task**: 500 - edge_backfill_unreachable_for_not_started
**Started**: 2026-11-11T07:21:14Z
**Completed**: 2026-11-11T07:25:54Z
**Effort**: small (single-file fix, confined footprint)
**Dependencies**: 328, 430, 446, 448 (state.json-declared; all four now `completed`/archived -- see Findings)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/update-task-status.sh` (full read, both halves)
- Codebase: `agent-system/extensions/core/scripts/lib/status-vocabulary.sh`
- Codebase: `agent-system/extensions/core/scripts/validate-state.sh` (Check D3 / Kahn cycle detector, `--deep` and positional-state-file support)
- Codebase: `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` (the sole live automated caller of `--depends-on-add`, `resolve_noop_token()` / `propose_edge_for_pair()`)
- Codebase: `agent-system/extensions/core/scripts/tests/test-update-task-status.sh` (Case 17, the flag's own test coverage)
- Codebase: `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh`
- Codebase: `specs/state.json`, `specs/archive/state.json` (live status of tasks 421, 438, 497, 328, 430, 446, 448)
- Docs: `context/patterns/multi-task-operations.md` §13, `context/patterns/batch-orchestration-guardrails.md`, `docs/architecture/batch-admit-schema.md`, `docs/guides/user-guide.md`, `merge-sources/claudemd.md`
**Artifacts**:
- `specs/500_edge_backfill_unreachable_for_not_started/reports/01_depends-on-add-not-started-gap.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is confirmed exactly as described: `map_status()` has twelve `operation:target_status` arms, none resolves to `not_started`, and the status-no-op restriction therefore makes `--depends-on-add` unconditionally unreachable for any `not_started` task. Verified by direct read of the live source (lines 461-503) and by re-deriving the arm count independently (12, matching the dispatch's figure).
- `orchestrate-suggest-next-batch.sh` already knows about this exact gap today: its `resolve_noop_token()` helper has no `not_started` case and `propose_edge_for_pair()` falls back to a "propose-only, add by hand" notice whenever the higher-numbered task in a collision pair is `not_started`. This is independent corroboration from a second file and gives a ready-made, minimal integration point for the fix.
- Recommendation: **Option (a)** -- add one new no-op-only `operation:target_status` arm that resolves `STATE_STATUS` to `"not_started"`, refused outright unless `--depends-on-add` accompanies it. This is confined to `update-task-status.sh` (map_status, the target_status enum/usage text, and one new edge-only guard) plus a one-line addition to `orchestrate-suggest-next-batch.sh`'s `resolve_noop_token()`. Option (b) (a standalone operation with no `operation`/`target_status` positionals) would instead require restructuring every `target_status`-gated block in the same file (phase-check, the postflight completion-deploy gate, `update_plan_file()`) and would force a parallel rewrite of `resolve_noop_token()`/`propose_edge_for_pair()` for every status, not just `not_started` -- a far larger diff for the same outcome, and precisely the "second vehicle" the script's own header already declined to invent. See Decisions.
- A significant fact discovered during research, with real consequences for the acceptance criteria: of the two "live, currently-unaddable" edges the dispatch names, only one (438 -> 500) is still realizable once the fix lands. The other (421 -> the telemetry-sub-mode relocation task) targets task 497 (`promote_telemetry_submodes_to_core`), which has since **completed and been archived out of `active_projects`** -- so even after the fix, that literal edge-add call would fail `--depends-on-add`'s existing missing-predecessor refusal (which checks `active_projects` only), and more importantly the ordering risk the edge existed to prevent no longer exists, because the relocation already happened. See Findings and Risks.
- All four of task 500's own declared `dependencies[]` (328, 430, 446, 448) have likewise completed and archived since this task was created; 500 is fully unblocked today regardless of the fix.
- No change to `status-vocabulary.sh`, `state-schema.json`, or the cycle-detection algorithm is needed: `"not_started"` is already a member of the closed 13-value enum (rank 0), and the mandatory write-time cycle refusal already reuses `validate-state.sh --deep`'s existing Kahn-algorithm detector unconditionally for any `--depends-on-add` call, independent of which status arm supplied the no-op replay.

## Context & Scope

Scope is exactly the dispatch's: determine why `--depends-on-add` cannot fire on a `not_started` task, rule on one of three candidate remediation shapes ((a) new no-op-only status arm, (b) standalone operation, (c) move edge-add to a different surface), and verify every guarantee the dispatch requires survive unchanged. This phase is research only -- no code was changed. The two "end-to-end" edges named in the dispatch (421 and 438) were investigated for current feasibility but not added; that is implement-phase work, contingent on the fix landing first.

Out of scope, per the dispatch's own Non-Goals: the per-edge semantic/serialization rationale discriminator (task 438's own open question), the `dependencies[]` flat-array schema, an auto-invoked drain check, and any change to `state-management.md`'s transition model beyond what the chosen shape strictly requires.

## Findings

### The defect, re-verified against the live tree

`map_status()` (`update-task-status.sh` lines 461-503) has exactly twelve `operation:target_status` case arms (counted directly, matching the dispatch's figure):

| Arm | Resolves to |
|---|---|
| `preflight:research` | `researching` |
| `preflight:plan` | `planning` |
| `preflight:implement` | `implementing` |
| `postflight:research` | `researched` |
| `postflight:plan` | `planned` |
| `postflight:implement` | `completed` |
| `preflight:pr_ready` | `pr_ready` |
| `postflight:pr_ready` | `completed` |
| `preflight:hold` | `hold` |
| `postflight:partial` | `partial` |
| `postflight:blocked` | `blocked` |
| `postflight:needs_research` | `researching` |

Ten distinct resolved values (`completed` and `researching` each appear twice); none is `not_started`, `abandoned`, or `expanded`. There is no `operation:target_status` combination in the catch-all-protected case statement that could produce `not_started` -- confirming the dispatch's claim that the precondition is structurally unsatisfiable for a `not_started` task, not merely untested.

The status-no-op restriction itself (lines 641-649) is unconditional and independent of which arm supplied the no-op: `if [[ "$DEPENDS_ON_ADD_LEN" -gt 0 && "$state_is_noop" != "true" ]]; then exit 1; fi`, where `state_is_noop` is `current_state_status == STATE_STATUS`. Since no arm ever sets `STATE_STATUS="not_started"`, this condition can never be satisfied when `current_state_status == "not_started"`, regardless of which `operation`/`target_status` pair is tried. The quoted error text in the dispatch (`"Error: --depends-on-add requires operation:target_status to resolve to task 421's CURRENT status..."`) matches the live source verbatim (line 647), confirming the reproduction is current, not stale.

### Independent corroboration from a second file

`orchestrate-suggest-next-batch.sh` already anticipates this exact gap. Its `resolve_noop_token()` helper (lines 487-509) maps each resolvable status to its no-op `operation target_status` token (`researching -> "preflight research"`, `researched -> "postflight research"`, etc.) and has **no case for `not_started`** -- it falls through to `return 1`. The caller, `propose_edge_for_pair()` (lines 511-566), explicitly handles this failure with a named, non-silent fallback: when the higher-numbered task in a file-scope-collision pair is `not_started`, it prints `NOTE: task ${higher}'s current status '${higher_status}' has no resolving operation:target_status no-op token... the --depends-on-add call cannot be issued until it leaves that status. Add the edge by hand...` and returns 1 (propose-only, never silently drops the pair). This script's own header comments (lines 517-521) name this as "the genuine not_started gap" in almost the same words as this task's dispatch -- independent confirmation that the gap is real, already known to at least one other part of the codebase, and already has a designated (if currently dead) integration point: adding one case to `resolve_noop_token()` is all that script would need once the underlying script supports a `not_started` no-op token.

No other script, doc, or test in the tree invokes `--depends-on-add` with an explicit CLI shape; every other reference (`context/patterns/multi-task-operations.md`, `batch-orchestration-guardrails.md`, `docs/architecture/batch-admit-schema.md`, `docs/guides/user-guide.md`, `merge-sources/claudemd.md`) is prose naming the flag, not a literal invocation template. Call-site impact for either remediation shape is therefore concentrated in exactly two scripts (`update-task-status.sh` and `orchestrate-suggest-next-batch.sh`) and their two test files.

### Guarantee-preservation evidence (all five confirmed intact and reusable as-is)

- **Write-time cycle refusal** (lines 651-689): reuses `validate-state.sh --deep` against a scratch copy of `state.json` with the candidate edge applied, grepping only the `Dependency cycle detected among project_number(s):` line (confirmed present verbatim in `validate-state.sh` at the point its own Check D3 / Kahn-algorithm sweep logs it, line ~1369). This machinery is entirely orthogonal to which status arm produced the no-op replay -- it fires unconditionally whenever `DEPENDS_ON_ADD_LEN > 0`, before the no-op-restriction check or the write. Fail-closed guard (`[[ ! -x "$DEPENDS_VALIDATE_STATE_SCRIPT" ]]` -> refuse) is also unconditional. Neither candidate shape (a) nor (b) touches this block.
- **Value validation** (array-of-numbers, lines 403-407), **self-edge refusal** (lines 408-413), **missing-predecessor refusal** (lines 446-458, scoped to `active_projects[].project_number` only -- see the archived-predecessor finding below), and **union-merge idempotence** (`unique` in both the no-op write path, line 1112, and the real-write path, line 1171) are all independent of the status-no-op gate and need no change under either shape.
- **Drain confirmation stays the caller's responsibility**: confirmed by the absence of any `orchestrate-cycle-plan.sh` invocation inside `update-task-status.sh`; the dispatch's prohibition on adding one is easy to keep since nothing in either candidate shape touches this.
- `validate-state.sh` already accepts a positional scratch-state-file argument (confirmed in its arg-parsing loop) and a `--deep` flag independent of `--archive` mode, so the reuse requirement has no hidden precondition that either shape would disturb.

### Acceptance-criterion feasibility check: the two "currently unaddable" edges

This research re-verified the live status of every task named in the dispatch's edge-backfill examples and in task 500's own `dependencies[]`:

| Task | project_name | Current status |
|---|---|---|
| 421 | `retarget_distill_meta_as_evidence_consumer` | `not_started` (still in `active_projects`) |
| 438 | `dependency_edge_rationale_semantic_check` | `not_started` (still in `active_projects`) |
| 500 | `edge_backfill_unreachable_for_not_started` (this task) | `researching` (still in `active_projects`) |
| 497 | `promote_telemetry_submodes_to_core` | **`completed`, archived out of `active_projects`** |
| 328 | `systematic_script_and_test_corpus_efficiency` | **`completed`, archived** (dispatch described it as currently `implementing`/"a live writer" -- no longer true) |
| 430 | `feed_undeclared_implement_paths_into_file_scope` | **`completed`, archived** |
| 446 | `close_the_plan_to_file_scope_reconciliation_gap` | **`completed`, archived** |
| 448 | `contain_deliberate_break_source_mutations` | **`completed`, archived** |

Two consequences follow directly from this, both material to acceptance criterion 5:

1. **The 438 -> 500 edge remains the correct end-to-end proof.** Task 438 is `not_started` and task 500 is a live `active_projects` entry, so once the fix lands, adding `438` depends on `[500]` exercises exactly the gap this task closes, on a genuinely live pair. This part of acceptance criterion 5 is fully achievable as written.
2. **The 421 -> (telemetry relocation task) edge is now moot, and literally unaddable even after the fix.** The relocation task the dispatch describes ("the task that relocates the three vault-independent distill telemetry sub-modes into core") is task 497, which has already completed and is no longer in `active_projects`. `--depends-on-add`'s missing-predecessor refusal checks `active_projects[].project_number` only (line 452), so a call naming `497` as a predecessor would be refused with "`--depends-on-add references nonexistent task number(s): 497`" regardless of whether the `not_started` gap is fixed -- the predecessor has to exist in the live roster, and an archived/completed task does not. More fundamentally, the ordering concern the edge existed to enforce ("RELOCATE FIRST") is already satisfied in fact: the relocation finished before this research ran, so there is no remaining risk of 421 landing in the wrong tree. Adding this edge would therefore be both infeasible by the existing refusal and pointless by the dispatch's own stated rationale. The correct disposition for acceptance criterion 5's first half is to report it as **moot** (ruling already enforced by completed fact, not by a written edge) rather than to attempt the literal edge-add.
3. **Task 500's own declared `dependencies[]` (328, 430, 446, 448) are all satisfied** -- every one of them has completed and archived since task 500 was created. This does not block anything; it simply means 500 is unblocked today independent of the fix, and the plan/implement phases need not wait on any of these four.

## Decisions

- **Decision: pursue remediation shape (a)** -- add one new no-op-only `operation:target_status` arm to `map_status()` that resolves `STATE_STATUS` to `"not_started"`, paired with an explicit guard refusing that arm whenever `--depends-on-add` is absent (so it can never be misused as a settable lifecycle target). Reasons:
  - **Call-site count.** Shape (a)'s footprint is four files, each with a small, additive diff: `update-task-status.sh` (one `map_status()` arm, one addition to the `target_status` validation/usage text, one new "edge-only" refusal guard), its test file (new Case-17-style assertions), `orchestrate-suggest-next-batch.sh` (one new line in `resolve_noop_token()`, removing the need for its existing fallback branch to fire for `not_started` specifically -- the branch itself stays, now simply unreached for this one status), and its test file (one new assertion that a `not_started` collision pair now writes the edge instead of falling back to propose-only). Shape (b) touches the same four files but far more invasively: `update-task-status.sh`'s phase-check block, the postflight completion-deploy gate, and `update_plan_file()` are all gated on `target_status == "implement"` / `!= "implement"`; a standalone `--depends-on-add` operation with no `target_status` positional would need every one of those blocks to either special-case or bypass the new operation, and `resolve_noop_token()`/`propose_edge_for_pair()` in `orchestrate-suggest-next-batch.sh` would need restructuring for **every** status it currently handles (not just `not_started`), since the whole op/target-token construction those functions do becomes unnecessary once the write no longer needs a resolved pair. That is a strictly larger and riskier diff for an equivalent outcome.
  - **One-sentence describability**, the second axis the dispatch asked to weigh on, arguably favors (b) ("the edge-add is its own operation, independent of phase and status" reads more cleanly than (a)'s "ride the no-op token for every status, including a new one for not_started"). But the dispatch weighs the two axes together, not independently, and the call-site-count asymmetry is large enough (a handful of additive lines vs. a cross-cutting rewrite of every `target_status`-gated block in the same file) that it dominates the marginally cleaner one-liner (b) would buy.
  - Shape (a)'s own cost, named in the dispatch, is the risk of the new token "being misused as a settable [lifecycle] target." This is fully mitigated by making the new arm's only legal use be as an `--depends-on-add` vehicle: refuse the call outright (exit 1, named error) whenever that arm is selected without `--depends-on-add` present. This mirrors the codebase's own existing precedent for a flag-only-legal-combination (`--hold-reason` restricted to `preflight:hold`, `--research-questions` restricted to `postflight:needs_research`).
  - Shape (b) is explicitly, by the dispatch's own framing, "precisely the second vehicle the header declined to invent" -- choosing it means overturning a stated design decision, which the dispatch says must be done explicitly and with reasons if chosen. The call-site evidence above does not support overturning it: the existing "ride the no-op replay" vehicle extends to `not_started` with a small, local addition, so there is no forcing reason to invent the second vehicle.
  - Shape (c) (move edge-add for `not_started` tasks to a different surface) is rejected for the reason the dispatch itself names: it splits one primitive across two entry points, which this codebase's consolidation bias (visible in the write-time-cycle-refusal reuse requirement and the single-sourced-library pattern used throughout this same file) argues against, with no offsetting benefit over (a).
  - **Naming the new arm.** The literal token should not read as a settable status (the risk shape (a) itself names). `"not_started"` as a literal `target_status` string risks exactly that misreading, since every other `target_status` literal names a phase a caller can genuinely request. A deliberately non-phase-shaped name -- `backfill` was checked and is unused anywhere in the tree (`grep` for `"backfill"`/`=backfill`/`target_status.*backfill` across `scripts/`, `context/`, `docs/` returned no hits) -- better satisfies "unmistakably no-op-only." This is offered as a concrete starting point for the plan phase, not a binding final decision; the plan phase should confirm the exact literal and operation pairing (`preflight:backfill` is the natural choice, since `hold`/`unhold` already establish `preflight` as the operation value for human-initiated, non-dispatch-outcome actions on a task's resting state).
  - **Decision: acceptance criterion 5's first edge (421 -> telemetry relocation task) should be reported as moot, not attempted**, per the Findings above: task 497 has completed and archived, so (i) the ordering risk the edge existed to prevent is already resolved by fact, and (ii) the literal edge-add call would be refused by the existing, unrelated missing-predecessor check regardless of whether this task's fix lands. The plan/implement phases should record this disposition explicitly (with the evidence above) rather than silently dropping the item or attempting a call known in advance to fail.

## Recommendations

1. **Implement shape (a)** in `update-task-status.sh`: add a `preflight:backfill` (or planning-confirmed equivalent) arm to `map_status()` resolving `STATE_STATUS="not_started"`/`TODO_STATUS="NOT STARTED"`; add `backfill` to the `target_status` validation list (line ~313) and the usage/help text (line ~302-304); add a guard immediately adjacent to the existing `--depends-on-add` status-no-op-restriction check (line ~646) that refuses `operation:target_status == "preflight:backfill"` whenever `DEPENDS_ON_ADD_LEN == 0`, with a named error distinguishing it from the pre-existing no-op-restriction message.
2. **Extend `orchestrate-suggest-next-batch.sh`'s `resolve_noop_token()`** with the matching `not_started) echo "preflight backfill" ;;` case so `propose_edge_for_pair()` writes the edge directly for a `not_started` higher task instead of falling back to its existing "add by hand" notice. No other change to that function's control flow is required -- the existing write/re-probe/fallback structure already handles every status uniformly once a token resolves.
3. **Extend `test-update-task-status.sh`'s Case 17 block** with: (i) a positive case -- `--depends-on-add` against a `not_started` fixture task via the new arm succeeds, leaves status `not_started`, and merges the edge; (ii) a negative case -- the new arm invoked without `--depends-on-add` is refused; (iii) re-run of the existing cycle-refusal/self-edge/missing-predecessor/malformed-value cases with a `not_started` target to confirm every existing guarantee from the dispatch's acceptance list holds on this new path too, not only on the previously-reachable statuses.
4. **Extend `test-orchestrate-suggest-next-batch.sh`** with one case exercising a `not_started` file-scope-collision pair under `--write-edges`, asserting the edge is written and the pair re-probes to admit, rather than falling back to the existing propose-only NOTE.
5. **At implement time, execute acceptance criterion 5's remaining feasible half only**: add `438` depends-on `[500]` once the fix lands (both tasks are live and not_started/researching respectively), and record the resulting `dependencies[]` array. Do not attempt the `421 -> 497` edge-add; instead record in the plan/summary that it is moot, with the evidence in this report's Findings (497 completed and archived; the ordering risk it would have mitigated no longer exists).
6. **Re-verify every quoted error string and the twelve-arm count against the tree as it stands at implement time** (dispatch's own acceptance item 7) -- this report re-verified them as of 2026-11-11; a future implement dispatch should not assume they are still unchanged without its own grep, in case an intervening task touched the same file.

## Risks & Mitigations

- **Risk**: the new no-op-only arm is later invoked without `--depends-on-add` by a caller who mistakes it for a genuine "reset to not_started" lifecycle action. **Mitigation**: the edge-only refusal guard recommended above (item 1) makes this a hard, immediate validation error rather than a silent no-op or a real transition; choosing a non-phase-shaped literal (`backfill`, not `not_started`) further reduces the chance of this misreading at the call site.
- **Risk**: a future caller passes `--depends-on-add` together with the new arm AND the task is not actually `not_started` (e.g. it is `researching`). **Mitigation**: no new logic is needed here -- the pre-existing status-no-op-restriction check (line 646-649) already catches this generically, since `STATE_STATUS` would be `"not_started"` while `current_state_status` is something else, making `state_is_noop` false and triggering the existing, unmodified refusal with its existing message.
- **Risk**: attempting the `421 -> 497` edge-add at implement time despite the mootness finding above, wasting a dispatch cycle on a call known in advance to fail. **Mitigation**: this report documents the evidence (497 archived, existence check scoped to `active_projects` only) precisely so the plan phase can pre-empt this and mark the item resolved-by-fact rather than attempted.
- **Risk**: `state.json`/`specs/archive/state.json` could themselves be re-synced (e.g. a vault operation) between this research dispatch and the implement dispatch, changing task numbers. **Mitigation**: acceptance item 7 already requires re-verification at implement time; this report's task-number references (421, 438, 497, 500, 328, 430, 446, 448) should be re-confirmed against `specs/state.json` rather than trusted blind if a vault operation intervened.

## Context Extension Recommendations

- **Topic**: the `--depends-on-add` flag's "status-no-op restriction" and its interaction with `not_started`.
- **Gap**: `context/patterns/multi-task-operations.md` §13 and `context/patterns/batch-orchestration-guardrails.md` both describe `--depends-on-add` as the default move for backfilling a serializing edge, but neither mentions that the flag was, prior to this task, unreachable for the single most common pre-lifecycle status. `orchestrate-suggest-next-batch.sh`'s own header comments are currently the only place this gap is named in prose, and only as an inline code comment, not in a discoverable context doc.
- **Recommendation**: once the fix lands, add one sentence to `context/patterns/multi-task-operations.md`'s §13 (or a new short subsection) noting that `--depends-on-add` now has a dedicated no-op-only token for `not_started` tasks, naming the literal chosen at plan/implement time, so a future reader does not have to re-derive this from the script's own header comment.

## Appendix

- Search/verification commands used (all against the live working tree, 2026-11-11):
  - `jq -r '.extensions.core.source_dir' .claude-extensions.json` -- confirmed source-store resolution target.
  - `grep -n "requires operation:target_status to resolve to task" scripts/update-task-status.sh` -- confirmed the quoted error string is current.
  - `grep -rln 'depends-on-add' .` across `agent-system/extensions/core/` -- enumerated every file referencing the flag (10 files: 2 scripts, 2 test files, 6 docs; only the 2 scripts and 2 test files show an executable invocation shape).
  - `jq` queries against `specs/state.json` and `specs/archive/state.json` for project numbers 421, 438, 497, 500, 328, 430, 446, 448.
  - Direct reads of `update-task-status.sh` (both halves, full `map_status()`, the `--depends-on-add` validation/cycle-refusal/write blocks), `status-vocabulary.sh` (full file), `orchestrate-suggest-next-batch.sh` (`resolve_noop_token()`/`propose_edge_for_pair()` and their test coverage), and `validate-state.sh` (cycle-detector / `--deep` / arg-parsing sections).
- Related artifacts: none yet created for this task (this is the first research report).
