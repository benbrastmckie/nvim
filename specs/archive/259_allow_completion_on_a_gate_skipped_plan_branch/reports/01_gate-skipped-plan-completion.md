# Research Report: Task #259

**Task**: 259 - Allow completion when a plan branch deliberately skips phases, and stop the
identical-redispatch loop
**Started**: 2026-09-25T18:21:00Z
**Completed**: 2026-09-25T19:10:00Z
**Effort**: Medium (verification-heavy, two independent script-level fixes plus two doc updates)
**Dependencies**: None (independent of the sibling return-meta-vocabulary and
recovery-decline-attribution meta tasks — see Relationship to Sibling Tasks below)
**Sources/Inputs**: Codebase read of `agent-system/extensions/core/` (source store)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's reframed premise is confirmed end-to-end by direct code inspection:
  `[COMPLETED WITH EXCLUSIONS]` already exists, is already wired into every phase-closed
  denominator/numerator (`PHASE_STATUS_DONE_ALT='COMPLETED|COMPLETED WITH EXCLUSIONS'` in
  `scripts/lib/phase-heading-patterns.sh:104-107`), and is already argued as the *sole* marker for
  whole-phase exclusion in `context/standards/status-markers.md`. No new marker, no new handoff
  field, and no plan-format lint change is needed to represent Task 188's gate-skipped Phases 3-5.
- **Gap 1 (documentation) is real and precisely as scoped**: nothing in `plan-format.md`,
  `status-markers.md`, or `planner-agent.md` mentions "decision gate" or "gate-skipped" at all
  (confirmed by grep — zero hits). The mapping from a branched/contingency plan shape to
  `[COMPLETED WITH EXCLUSIONS]` is undocumented.
- **Gap 2 (the gate defect) is real, but its fix site is narrower than one line, and lands in a
  different file than the dispatch's own File Scope Note names.** `skill_gate_completion_claim`
  (`scripts/skill-base.sh:1224`) is a pure decision function with no plan-reading capability by
  design; it never needs editing. The actual defect is in its sole live caller,
  `scripts/orchestrate-cycle-postflight.sh:478-486`, whose corroboration-trigger precondition is
  hardcoded to `phases_total -eq 0` (Case 3 only) and never fires for Case 1 (`phases_total > 0`,
  incomplete). **This file is not in the task's declared `file_scope`.** See Findings for the
  precise widening needed and a false-positive-defect-record pitfall a naive widening would
  introduce.
- `orchestrate-stage5-gates.sh` and `orchestrate-stage5-postflight.sh` — which also call
  `skill_gate_completion_claim` — are **confirmed dead code** (zero call sites, per
  `docs/architecture/orchestrate-cycle-postflight.md:237`, itself confirmed by grep across the
  whole tree). They must not be edited; touching them would have no runtime effect and would
  violate the "no test may be weakened" spirit by adding untested, unreachable branches.
- The `[phase-check]` `--phase-check=refuse` mode (dispatch's caution item) is **confirmed never
  in force** on the `/orchestrate` completing-transition path: both live call sites
  (`orchestrate-cycle-postflight.sh:791` and the now-dead `orchestrate-stage5-postflight.sh:161`)
  hardcode `"warn"`, with an explicit comment explaining this is deliberate ("a valuable SECOND
  OPINION... not a veto"). A Gap 2 fix at the `skill_gate_completion_claim` layer cannot be undone
  by a second refusal downstream on this path. `--phase-check=refuse` is real but lives only on
  `command-gate-out.sh` (single-command `/implement`) and `reconcile-task-status.sh` — different
  code paths, out of scope here, not at risk of interference.
- **Fix 2 (convergence guard) is confirmed exactly as described**: the guard at
  `scripts/orchestrate-cycle-plan.sh:1715` only increments `consecutive_no_dispatch_cycles` when
  `probed_dispatch` is empty; a refused-after-dispatch cycle resets the counter to 0 every time.
  A per-task hash-based identical-dispatch counter is a natural, low-risk extension of the
  existing multi-task state shape, which already keys several fields
  (`max_cycles_per_task[t]`, `cycle_counts[t]`) by task number, and `sha256sum`-based hashing with
  a `CANNOTVERIFY`-style degrade path already has precedent in `scripts/lib/deploy-ledger-lib.sh`.
- `docs/architecture/handoff-schema.md` must be edited **regardless of whether a new field is ever
  added** (contra the dispatch's "keep only if a schema addition survives" framing): its own
  `plan_markers_verified` subsection currently documents, as settled fact, "Case 1 ... always
  REFUSES. `plan_markers_verified` is not consulted" (lines 364-365) — text that becomes false the
  moment Gap 2 is fixed, independent of any schema addition.
- The fourteen-value `system-defect-record.sh` enum genuinely has no fitting class; the
  self-modifying-candidate serialization against the sibling recovery-decline-attribution task is
  correctly reasoned and needs no `dependencies[]` edge.

## Context & Scope

This is a `meta` task researching a real production deadlock observed via `/orchestrate 184,188`
in a consumer repository (ModelChecker): a task whose implementation dispatch fully succeeded, but
whose handoff's self-reported `phases_completed=4`/`phases_total=7` (the plan's Phase 2 decision
gate failed, so contingency Phases 3-5 were correctly left unexecuted) triggered the
completion-claim gate's fail-closed Case 1, producing two wasted ~40-minute redispatch cycles
before being halted by hand. The dispatch document is a corrected second draft — the earlier
draft's premise (no marker exists for "deliberately not executed") is explicitly flagged false and
retracted in the dispatch text itself. This report's job is to verify the corrected premise and
the two proposed fixes against the actual source, and to surface anything the dispatch got wrong
or under-specified before planning begins.

All verification was done by reading `agent-system/extensions/core/` (the source store; per
`.claude/rules/source-store-deploy-boundary.md` this is the correct read/edit target, never the
deployed `.claude/` tree) — never by trusting the dispatch's line-number citations at face value.
Every citation below was independently re-derived from the current file contents.

## Findings

### Codebase Patterns

**`[COMPLETED WITH EXCLUSIONS]` is fully wired, confirmed by direct inspection:**
- `context/standards/status-markers.md:186-238` — defines the marker, its five-condition admission
  test, the `#### Reasoned Exclusions` cross-reference, explicitly states whole-phase exclusion is
  "a valid, intended case, not a degenerate one," and rejects a fourth marker (`[DESCOPED]`) by
  name using the same argument that would apply to `[SKIPPED]`/`[NOT APPLICABLE]`.
- `scripts/lib/phase-heading-patterns.sh:90-107` — `PHASE_STATUS_ENUM` includes it as the fourth
  of six values; `PHASE_STATUS_DONE_ALT='COMPLETED|COMPLETED WITH EXCLUSIONS'` is the single
  authoritative "closed" definition consumed by every accounting/recovery site, with a comment
  stating this exact orchestration-deadlock class is the reason it exists.
- `context/formats/plan-format.md:353-380` — `## Reasoned Exclusions (format)` gives the required
  per-phase `#### Reasoned Exclusions` table (`Item`/`Reason`/`Evidence`), explicitly positioned as
  a field-for-field generalization of the `sorry_inventory` schema, with `follow_up_task`
  deliberately absent (decided-and-closed, not deferred-and-tracked).
- `scripts/tests/test-corroborate-phase-counts.sh` Fixture D already exercises "mixed `[COMPLETED]`
  and `[COMPLETED WITH EXCLUSIONS]`, all closed → corroborated" for
  `skill_corroborate_phase_counts` in isolation, and Fixture A already exercises feeding a
  corroborated output into `skill_gate_completion_claim` and getting an ALLOW. **The underlying
  mechanism for Fix 1's no-schema-change path is proven correct today, in isolation** — it is
  simply never invoked from the Case 1 shape.

**Gap 1 confirmed, precisely**: `grep -n -i "decision gate\|contingency\|gate-skipped\|gate skip"`
across `plan-format.md`, `status-markers.md`, `anti-analysis.md`, and `planner-agent.md` returns
zero hits inside any of those files' bodies (the only two "contingency" hits are the unrelated
`## Rollback/Contingency` plan section). Nothing tells a planner that a decision-gate/contingency
branch shape is the trigger condition for `[COMPLETED WITH EXCLUSIONS]`.

**Gap 2 confirmed, but the fix site is narrower and differently located than the dispatch's File
Scope Note states.** Tracing the call graph precisely:

1. `skill_gate_completion_claim` (`scripts/skill-base.sh:1224-1284`) takes
   `phases_completed`/`phases_total`/`plan_markers_verified` as **already-computed arguments** —
   its own header comment states explicitly: "This function never reads a plan file, report, or
   summary... this gate fires only when a handoff IS present and fresh." This is a deliberate
   architectural boundary (a "pure decision function," called unconditionally even under
   `--dry-run` per the caller's own comment), not an oversight. It does not need to change, and
   changing it to read a plan directly would violate this documented contract.
2. The corroboration trigger lives entirely in the caller. In the one live call site,
   `scripts/orchestrate-cycle-postflight.sh:478-486`:
   ```bash
   if [ "$dispatch_status" = "implemented" ] && [ "$phases_total" -eq 0 ]; then
     ...
     cpc_line=$(skill_corroborate_phase_counts "$task_number" "$corroboration_plan_path" \
       "$notice_prefix" "$handoff_file")
     ...
   fi
   ```
   The precondition is `phases_total -eq 0` **alone** — deliberately matching
   `skill_gate_completion_claim`'s Case 3 precondition exactly (documented as D3 in
   `skill_corroborate_phase_counts`'s own header). A handoff reporting `4/7` never enters this
   block at all, so `skill_corroborate_phase_counts` — proven correct in isolation above — is
   simply never asked the question.
3. **`orchestrate-stage5-gates.sh` and `orchestrate-stage5-postflight.sh` are dead code.**
   `docs/architecture/orchestrate-cycle-postflight.md:237` states outright: "`orchestrate-stage5-
   gates.sh` and `orchestrate-stage5-postflight.sh` have zero call sites after the Phase 7
   cutover." Confirmed independently: `grep -rln` for both filenames across the whole
   `agent-system/` and `.claude/` trees finds only self-references, test files that exercise them
   directly (not via any live caller), and this doc's own note — no `SKILL.md`, no manifest hook,
   no other script invokes either file. **Do not edit these two files** — they have no runtime
   path to the observed deadlock, and any change to them is unverifiable by the normal
   `/orchestrate` flow.

**Consequence for file_scope**: the task's declared `file_scope` (from `specs/state.json`)
currently lists `scripts/skill-base.sh` and `scripts/orchestrate-cycle-plan.sh` as the executable
targets, but the actual Gap 2 edit site — the corroboration-trigger precondition — is in
`scripts/orchestrate-cycle-postflight.sh`, which is **absent from `file_scope`**. `skill-base.sh`
still needs a **non-functional** edit: `skill_corroborate_phase_counts`'s own header carries a "D3
(deliberate divergence)" comment block stating "This function's sole consumer is
`skill_gate_completion_claim`'s Case 3... each caller gates on it BEFORE invoking this function"
— that invariant description becomes stale once a second (Case-1-adjacent) precondition is added
in the caller, and should be corrected alongside the caller-side change so the comment does not
mislead a future reader. The concrete recommendation below flags this as a `proposed_file_scope`
addition for the plan phase.

**A widening pitfall worth flagging before planning.** The existing overwrite pattern at the
Case-3 call site is unconditional:
```bash
cpc_line=$(skill_corroborate_phase_counts ...)
IFS=' ' read -r cpc_a cpc_b cpc_c <<< "$cpc_line"
phases_completed="${cpc_a#phases_completed=}"
phases_total="${cpc_b#phases_total=}"
plan_markers_verified="${cpc_c#plan_markers_verified=}"
```
This is safe today because it only runs when `phases_total` was already `0` (overwriting `0` with
`0` on a non-corroborating result is a no-op). If a naive fix reuses this exact pattern but widens
the *trigger* to also cover Case 1 (`phases_total > 0`, incomplete), a **genuinely incomplete**
plan (the false-shortfall case, verification arm 3) would have its real, non-zero
`phases_completed`/`phases_total` **zeroed out** by `skill_corroborate_phase_counts`'s own
non-corroborating return shape (it explicitly returns `phases_completed=0 phases_total=0` on every
non-corroborating branch, not "leave the input alone"). The gate would still end up refusing (Case
1 becomes Case 3, which also refuses when `plan_markers_verified` stays `absent`) — arm 3's
*outcome* survives — but the refusal would now silently masquerade as Case 3 rather than Case 1,
which flips the caller-side defect-recording guard: `orchestrate-cycle-postflight.sh:803-812`
explicitly treats Case 1 as "an ordinary refuse and is NOT a defect" and gates its
`META_MISSING_AFTER_NARRATION` recording on `phases_total -eq 0`. Zeroing out a genuinely-nonzero
`phases_total` on a merely-non-corroborating plan would make every ordinary Case-1 refusal record
a **false-positive system defect**. The plan phase should design this as: corroborate whenever
`dispatch_status = "implemented"` (regardless of `phases_total`), but **only overwrite
`phases_completed`/`phases_total`/`plan_markers_verified` when `skill_corroborate_phase_counts`
itself reports `plan_markers_verified=true`** — otherwise leave the handoff's original counts (and
therefore the original Case 1 attribution) untouched. This is a small, surgical change (an `if`
around the three assignment lines, or an early-return-preserving variant), not a redesign, but it
is exactly the kind of detail a plan needs to get right and the dispatch does not spell out.

**`[phase-check]` mode confirmed non-interfering, precisely.** Traced both live callers of
`skill_gate_completion_claim` for the `implemented` outcome:
- `orchestrate-cycle-postflight.sh:791`: `skill_postflight_update ... "warn" ...` — hardcoded.
- `orchestrate-stage5-postflight.sh:161` (dead code, listed only for completeness): also
  hardcoded `"warn"`, with a comment: "`warn`, deliberately NOT `refuse`: the script-side backstop
  reads the plan file's own phase headings — structurally different evidence — so it is a valuable
  SECOND OPINION here, not a veto over a decision this state machine made deliberately and
  loggedly."
`--phase-check=refuse` is real (`update-task-status.sh:485-489`, exit code 4) but is only ever
passed by `command-gate-out.sh:133` (the single-command `/implement` gate-out, not `/orchestrate`)
and `reconcile-task-status.sh:591,641` (the reconciliation replay path). Neither is in the call
chain from `skill_gate_completion_claim`'s ALLOW. **A Gap 2 fix at the gate layer is safe from a
downstream refuse on the `/orchestrate` path** — this closes the dispatch's own open caution item
definitively. Separately, `update-task-status.sh`'s `count_plan_phases()` (lines 423-443) already
sources the same shared `PHASE_HEADING_DONE_ERE` library and already treats
`[COMPLETED WITH EXCLUSIONS]` as closed — this is an independently-correct, already-existing
second implementation of the same "COMPLETED WITH EXCLUSIONS counts as closed" rule, confirming
the dispatch's "ALREADY CORRECT — do not duplicate or silence" framing of the `[phase-check]`
warning.

**Fix 2 (convergence guard) confirmed exactly as described.** `scripts/orchestrate-cycle-
plan.sh:1714-1725`:
```bash
if [ "${#probed_dispatch[@]}" -eq 0 ] && [ "${#eligible_tasks[@]}" -gt 0 ]; then
  new_counter=$(( $(mt_get '.consecutive_no_dispatch_cycles') + 1 ))
  ...
  if [ "$new_counter" -ge 3 ]; then ... emit_and_exit ...
else
  mt_set '.consecutive_no_dispatch_cycles = 0'
  ...
```
A cycle that dispatches (populates `probed_dispatch`) and is then refused at postflight always
resets the counter to `0` on the very next cycle's pass through this block, regardless of how many
times in a row the same dispatch content is refused. The only outer bound is `MAX_CYCLES`/
`max_cycles_per_task[t]` (5 base, 13 hard mode, per `orchestrate-cycle-plan.sh:481-482`) — matching
the dispatch's "two wasted cycles before hand-halt" observation as within-budget but wasteful.

The multi-task state already stores several fields keyed by task number
(`max_cycles_per_task[t]`, `cycle_counts[t]` — `orchestrate-cycle-plan.sh:491,581`), so a parallel
`last_dispatch_hash[t]` / `identical_dispatch_streak[t]` pair is a structurally consistent
addition, not a new pattern. `scripts/lib/deploy-ledger-lib.sh:119,131,141` already establishes
the codebase's precedent for `sha256sum`-based content hashing with an explicit degrade path
(`command -v sha256sum >/dev/null 2>&1 || return 2`, surfaced as a named `CANNOTVERIFY` state
rather than a silent skip) — the plan phase should reuse that same degrade-gracefully idiom for
Fix 2's hash rather than inventing a new one. The dispatch file's own `## Identity` block (see
this task's own `.dispatch/2.md`) confirms `dispatch_seq` and `dispatch_start_ts` are each emitted
as a single, greppable `- dispatch_seq: N` / `- dispatch_start_ts: N` line, so "hash modulo those
two lines" is a simple `grep -v` (or two `sed` deletes) before hashing — no structural parsing
needed.

### External Resources

None consulted — this is a pure internal-mechanism task; no external documentation applies.

### Recommendations

1. **Gap 1 (docs)**: Add a subsection to `context/formats/plan-format.md` (near the existing
   `## Reasoned Exclusions (format)` section) and cross-reference it from
   `context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection, explicitly
   naming the decision-gate/contingency-branch plan shape as a canonical trigger for
   `[COMPLETED WITH EXCLUSIONS]` on the skipped phases, with a worked example modeled on the
   observed Task 188 shape (gate phase COMPLETED, contingency-taken phases
   `[COMPLETED WITH EXCLUSIONS]` with a `Reasoned Exclusions` table citing the gate's own failing
   measurement as Evidence). Per the dispatch's explicit scope caution, do **not** edit any
   agent body (`planner-agent.md` etc.) in this task — that is the sibling agent-contract task's
   territory; sequence after it if agent-body wording is later judged necessary.
2. **Gap 2 (gate)**: Widen the corroboration trigger in
   `scripts/orchestrate-cycle-postflight.sh`'s handoff-present branch from
   `[ "$phases_total" -eq 0 ]` to also cover the Case 1 shape, call
   `skill_corroborate_phase_counts` in both cases, but **only overwrite the three output
   variables when the corroboration reports `plan_markers_verified=true`** — otherwise leave the
   handoff's original `phases_completed`/`phases_total`/`plan_markers_verified` untouched so a
   genuinely-incomplete plan still refuses as an ordinary (non-defect) Case 1, exactly as today.
   Update `skill_corroborate_phase_counts`'s D3 header comment in `scripts/skill-base.sh` (no
   functional change to that function) to describe the new two-precondition trigger instead of
   claiming Case 3 is the sole consumer precondition. Do not touch
   `orchestrate-stage5-gates.sh`/`orchestrate-stage5-postflight.sh` — confirmed dead code.
3. **Schema doc**: Regardless of whether any new field is added, correct
   `docs/architecture/handoff-schema.md`'s `plan_markers_verified` subsection (currently states,
   as fact, "Case 1... `plan_markers_verified` is not consulted") to describe the corrected
   behavior. Recommend this land as part of Gap 2's phase, not deferred.
4. **Fix 2 (convergence guard)**: Add per-task `last_dispatch_hash[t]` /
   `identical_dispatch_streak[t]` fields to the multi-task state (mirroring
   `max_cycles_per_task[t]`), hash each dispatch file's content with `dispatch_seq`/
   `dispatch_start_ts` lines stripped (reuse `deploy-ledger-lib.sh`'s `sha256sum`-with-
   `CANNOTVERIFY`-fallback idiom), and stop after N=2 consecutive identical dispatches for the
   same task/phase, independent of and in addition to the existing empty-`probed_dispatch`
   guard. Size as its own phase, committable green first, per the dispatch's own suggestion — it
   has no dependency on Gap 1/Gap 2's outcome.
5. **File scope correction for the plan phase**: add `scripts/orchestrate-cycle-postflight.sh`
   and `scripts/tests/test-orchestrate-cycle-postflight.sh` to file_scope (the actual Gap 2 edit
   site and its test suite); `scripts/tests/test-corroborate-phase-counts.sh` should also be
   listed as a test target even though it is not in the task's originally-declared file_scope,
   since Gap 2's fix changes the calling contract that file's fixtures document. This report's
   `.return-meta.json` proposes these three paths via `proposed_file_scope` for the plan phase to
   pick up.
6. **Adjacent items**: confirmed correct as scoped — (a) no `[DESCOPED]`-class marker work needed,
   drop it; (b) no `dependencies[]` edge needed between this task and the sibling
   recovery-decline-attribution task — `orchestrate-batch-admit.sh`'s designated-self-modifying-
   candidate rule already serializes them via `context/reference/orchestrator-critical-paths.json`
   (confirmed: this task's declared paths `scripts/skill-base.sh` and
   `scripts/orchestrate-cycle-plan.sh` are both listed critical paths, alongside the sibling's
   `scripts/orchestrate-cycle-postflight.sh` and `scripts/system-defect-record.sh` — **note**:
   this task's Gap 2 fix now also touches `orchestrate-cycle-postflight.sh`, which is *also* a
   critical path the sibling declares; this does not break the self-modifying-serialization
   argument, since both tasks already independently qualify as self-modifying candidates and only
   the lowest-numbered one is ever admitted per cycle regardless of how many critical paths each
   declares — but the plan phase should be aware the file-level overlap with the sibling's
   declared scope is now closer than the dispatch's own adjacency analysis assumed).

## Decisions

- Confirmed and adopted: no new phase-heading marker; no new handoff field (unless proven
  insufficient, which this research does not find to be the case); `[COMPLETED WITH EXCLUSIONS]`
  plus its existing `#### Reasoned Exclusions` record is sufficient end to end.
- Confirmed and adopted: `--phase-check=refuse` is not in force on the `/orchestrate` path; no
  second-refusal risk to design around.
- New finding, to carry into planning: the Gap 2 edit site is `scripts/orchestrate-cycle-
  postflight.sh`, not `scripts/skill-base.sh` (which needs only a comment update); file_scope
  needs updating accordingly.
- New finding, to carry into planning: `orchestrate-stage5-gates.sh`/`orchestrate-stage5-
  postflight.sh` are dead code and must be excluded from any edit.
- New finding, to carry into planning: a naive corroboration-trigger widening risks zeroing
  genuinely-nonzero phase counts on a non-corroborating plan, producing false-positive
  `META_MISSING_AFTER_NARRATION` defect records on ordinary Case 1 refusals; the fix must gate the
  three-variable overwrite on `plan_markers_verified=true`, not merely on entering the widened
  `if`.

## Risks & Mitigations

- **Risk**: planner reuses the dispatch's File Scope Note verbatim and edits
  `skill_gate_completion_claim` itself, breaching its documented "never reads a plan file" pure-
  function contract and duplicating corroboration logic that already exists and is already tested
  in isolation. **Mitigation**: this report's Recommendation 2/5 and the `proposed_file_scope`
  entries redirect the edit to the correct caller-side file.
- **Risk**: the overwrite-pitfall above ships unnoticed, producing false-positive defect records
  on ordinary Case 1 refusals in a future incident that looks superficially similar but is a
  genuine shortfall. **Mitigation**: called out explicitly in Findings and Decisions; verification
  arm (4) in the dispatch (under-reporting `phases_total` against an incomplete plan) already
  exercises the adjacent case and should be extended to also assert the *case label* (via the
  `[test]`-prefixed stderr line), not just the ALLOW/REFUSE boolean, so a regression here is
  caught by the case-2/1/3 log-line assertion pattern `test-skill-base-lifecycle.sh` already uses.
- **Risk**: Fix 2's hash-based dedup could false-positive on a legitimately-retried dispatch whose
  content differs only in something the exclusion pattern misses (e.g. a timestamp embedded
  elsewhere in the dispatch body, not just the two Identity-block lines). **Mitigation**: the
  dispatch body is generated deterministically by `orchestrate-build-dispatch.sh` from the task's
  own state; grep the generator for any other per-cycle-varying interpolation before finalizing
  the exclusion list, rather than assuming only the two Identity lines vary (this report did not
  exhaustively verify that no other line varies cycle-to-cycle; flag as a plan-phase check).

## Context Extension Recommendations

- **Topic**: Decision-gate / contingency-branch plan shape → `[COMPLETED WITH EXCLUSIONS]` mapping.
- **Gap**: `plan-format.md` and `status-markers.md` document the marker's admission test in the
  abstract but never connect it to the specific, common planner shape (a gated phase followed by
  conditional phases) that actually produces it in practice.
- **Recommendation**: the Gap 1 documentation work proposed above should live in
  `context/formats/plan-format.md` (new subsection near `## Reasoned Exclusions (format)`) with a
  one-line cross-reference from `status-markers.md`, per Recommendation 1 above.

## Appendix

### Search queries / commands used
- `grep -n -i "decision gate\|contingency\|gate-skipped\|gate skip"` across plan-format.md,
  status-markers.md, anti-analysis.md, planner-agent.md
- `grep -n "skill_gate_completion_claim"` / `"skill_corroborate_phase_counts"` across
  `scripts/*.sh`
- `grep -rln "orchestrate-stage5-postflight.sh\|orchestrate-stage5-gates.sh"` across
  `agent-system/` and `.claude/`
- Direct reads: `scripts/skill-base.sh` (~1180-1420), `scripts/orchestrate-cycle-postflight.sh`
  (~420-835), `scripts/orchestrate-stage5-postflight.sh`, `scripts/orchestrate-stage5-gates.sh`,
  `scripts/update-task-status.sh` (~395-510), `scripts/command-gate-out.sh` (~110-145),
  `scripts/reconcile-task-status.sh` (~575-650), `scripts/orchestrate-cycle-plan.sh` (~1690-1740,
  ~480-585), `scripts/system-defect-record.sh` (~155-175), `scripts/lib/phase-heading-
  patterns.sh` (~90-115), `context/standards/status-markers.md` (~150-240), `context/formats/
  plan-format.md` (~140-425), `docs/architecture/handoff-schema.md` (grep), `docs/architecture/
  orchestrate-cycle-postflight.md` (~200-240), `context/reference/orchestrator-critical-
  paths.json` (grep), `scripts/tests/test-corroborate-phase-counts.sh` (grep + read),
  `scripts/tests/test-skill-base-lifecycle.sh` (grep), `scripts/lib/deploy-ledger-lib.sh` (grep)
- Task metadata: `specs/state.json` (task 259 entry, for declared `file_scope` comparison)

### References
- `agent-system/extensions/core/scripts/skill-base.sh:1224` (`skill_gate_completion_claim`),
  `:1335` (`skill_corroborate_phase_counts`)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:478-486,765-812`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1714-1725,479-583`
- `agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh:90-107`
- `agent-system/extensions/core/context/standards/status-markers.md:186-238`
- `agent-system/extensions/core/context/formats/plan-format.md:353-420`
- `agent-system/extensions/core/scripts/update-task-status.sh:423-494`
- `agent-system/extensions/core/scripts/command-gate-out.sh:110-145`
- `agent-system/extensions/core/scripts/reconcile-task-status.sh:575-650`
- `agent-system/extensions/core/scripts/system-defect-record.sh:155-175`
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md:213-240`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md:294-382`
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh:119-141`
- `agent-system/extensions/core/scripts/tests/test-corroborate-phase-counts.sh`
