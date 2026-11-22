# Implementation Plan: Task #607

- **Task**: 607 - Resolve the gate 20 orchestrator context-budget overage and the per-gate timeout sensitivity under concurrent load
- **Status**: [COMPLETED]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/607_gate_20_context_budget_and_timeout_sensitivity/reports/01_gate20-budget-and-timeout-sensitivity.md
- **Artifacts**: plans/01_gate20-headroom-and-timeout-raise.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two independent, config-only remedies in the source store (`agent-system/extensions/core/**`),
followed by a redeploy and a full gate sweep. First, gate 20's three budget figures get a
deliberate, dated headroom move while the gate is green — breaking the ~10-round reactive
0-200 B-margin pattern the config's own derivation history records. Second, the three gates
empirically corroborated as killed by their 60s bound under concurrent dispatch load (3, 4, 10)
get a static raise to 180s, with the deviation from the registry's idle-derived sizing rule
recorded in the registry's own `timeout_s` field documentation. No load-adaptive mechanism is
built here; that remains task 610's charter.

### Premise Re-Validation (Carried-Figure Discipline)

The dispatch flagged two description lines as carried-figure triggers. Both were re-checked
against the prior report AND against live state during this planning pass:

| Carried claim | Live check (this dispatch) | Verdict |
|---|---|---|
| "commands/orchestrate.md plus skills/skill-orchestrate/SKILL.md measure 71712B against a 70400B baseline" | `measure-eager-context.sh --check` → `TOTAL: 70400 B`; baseline 70400 B | **STALE and additionally mis-described.** 71712 B is a pre-fix figure already closed before this dispatch. Separately, the description conflates two distinct sub-checks: the 70400 B baseline is the *whole eager-load set* (parent chain + predicted CLAUDE.md + eager rules), not the sum of those two files. Those two files have their own independent per-file ceilings. |
| Per-file figures (not in the trigger lines but load-bearing) | `wc -c`: `commands/orchestrate.md` 21496 B (ceiling 21500, margin **4 B**); `skills/skill-orchestrate/SKILL.md` 25692 B (ceiling 26000, margin 308 B) | Confirmed; gate 20 passes on all three sub-checks right now. |
| "gates 8 and 10 of the same sweep were killed by their own 60s per-gate timeout" | `gate-registry.data` live rows: gate 8 `timeout_s=1500 serialized=true`; gate 10 `timeout_s=60`; gates 3 and 4 also `timeout_s=60` | **Half incorrect.** Gate 8's bound is 1500s and it runs serialized — it is not in this incident class. Gate 10 is confirmed (3 corroborations, re-passing standalone in 61-66s). Gates 3 and 4 share the same 60s bound and the same corroborated incident class. |
| "gate 10's underlying check (validate-state.sh --deep) then passed in 61s when re-run in isolation" | Corroborated verbatim in `specs/562_*/issues.jsonl` and `specs/634_*/issues.jsonl` | Confirmed. |
| "SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/**" | Both targets have deployed mirrors (`.claude/context/config/orchestrator-context-budget.json`, `.claude/scripts/gate-registry.data`) | Confirmed; a redeploy is mandatory (Phase 3). |

**Net effect on scope**: the gate-20 remedy becomes purely preventive (nothing is red), and the
timeout remedy retargets from gates 8+10 onto gates 3, 4, and 10.

### Research Integration

- Both of the report's branch decisions are adopted: **re-baseline, not trim** for gate 20
  (the config's own recent entries already report "no further redistributable bloat found
  nearby", so a fourth compaction search is low-yield), and a **static raise, not a
  load-adaptive mechanism** for the timeouts.
- The report's gate-8 exclusion is adopted verbatim and extended: this plan additionally *adds*
  gates 3 and 4, which the report flagged as corroborated by task 610's own record and left as
  a conditional ("if a conservative bump is judged low-risk"). Planning judgment: they are in
  the same incident class, share the same 60s bound, and a split remedy would leave two of the
  three evidenced gates unfixed. Decided here rather than deferred.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no `roadmap_flag` was set; ROADMAP.md was
not consulted and is not modified by this plan.

## Goals & Non-Goals

**Goals**:
- Give gate 20's three budget figures real, durable headroom (hundreds of bytes, not 4 B),
  recorded in the config's own existing dated-derivation narrative style.
- Raise gates 3, 4, and 10's `timeout_s` from 60 to 180 so a loaded run stops reporting
  contention as a TIMEOUT finding, with the derivation recorded in `gate-registry.data`'s own
  field documentation.
- Leave a durable cross-reference where task 610's eventual load-adaptive design will find it.
- Redeploy and re-verify, leaving source store and deployed tree content-hash equal.

**Non-Goals**:
- Any compaction/trim pass on `commands/orchestrate.md` or `skills/skill-orchestrate/SKILL.md`.
  Explicitly rejected: three prior rounds already recorded the well as dry.
- Any load-adaptive, loadavg-scaled, or dispatch-count-scaled timeout mechanism. Task 610's
  charter; building a partial version here risks being superseded or contradicted.
- Gate 8: neither its 1500s bound nor its red shell suites. The latter is separately owned and
  the dispatch explicitly scopes it out.
- Regenerating `scripts/gate-cost-model.csv`. See Risks for why this is deliberately excluded.
- Removing the `test-gate-cache-equivalence.sh` row from `known-failures.txt`. Its citation is
  corrected; proving it resolvable would cost a ~543s suite run and is left open.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-baselining gate 20 while green reads as "weakening verification" | M | M | Nothing about *what* is checked changes: sub-check A stays unconditional-fail, sub-check B stays fail-above-baseline, sub-check C stays `fail()` under `ORCHESTRATOR_BUDGET_GATE_MODE=hard`. Only three numbers move, following the config's own documented rounding convention, with a dated justification entry — the same shape as every prior move. |
| Raising gate 10's bound masks a future real `validate-state.sh --deep` regression | M | L | 180s is still a hard, killable bound, not removal. It is 3x the current 60s and ~2.7x the worst observed standalone figure (66s) — a genuine regression would have to nearly triple runtime to hide. The dated registry note makes any future move auditable. |
| `gate-cost-model.csv` carries only a `gate8` row, so the registry's documented "derive from the idle cost model's clean avg_ms" rule cannot be mechanically applied to gates 3/4/10 | M | H (already true) | Derive from the corroborated incident evidence instead and say so in the registry note. Regenerating the model is excluded: `measure-gate-costs.sh` re-runs each gate twice and gate 8 alone measured 662s per run — a multi-hour cost this task does not need to pay to raise three static values. |
| `gate-registry.data` is inside concurrent sibling task 584's declared `file_scope` (research phase) | H | L | 584 is at `research`, which writes a report, not source-store scripts. Still: re-read `gate-registry.data` immediately before editing it (Phase 2 step 1), stage only this task's own hunks, and if a foreign uncommitted modification to that file is observed, STOP and report per the territory contract rather than proceeding. |
| Source store edited but not redeployed leaves gate 5 (content-hash equality) red | H | M | Phase 3 redeploys before the full sweep. Phases 1 and 2 use *narrowed* verification precisely because a full sweep is expected to show gate 5 red until the redeploy lands. |
| Task 607/610 overlap re-litigated from scratch by a future implementer | M | M | Phase 2 writes the cross-reference into `gate-registry.data`'s own `timeout_s` field documentation — the file a load-adaptive-timeout designer necessarily reads — rather than editing task 610's own record in-flight. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files and
have no ordering constraint between them.

---

### Phase 1: Gate 20 deliberate headroom re-baseline [COMPLETED]

**Goal**: Move all three gate-20 budget figures to values carrying real slack, with a dated
justification entry in the config's own narrative style, while the gate is green.

**Tasks**:
- [x] Re-measure immediately before editing, to confirm the figures have not moved under
      concurrent sibling activity: `cd <repo-root> && REPO_ROOT=$(pwd) bash
      agent-system/extensions/core/scripts/measure-eager-context.sh --check` (expect
      `TOTAL: 70400 B`) and `wc -c agent-system/extensions/core/commands/orchestrate.md
      agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (expect 21496 / 25692).
      If any figure differs, recompute the targets below from the live measurement using the
      same rules, and record the live figure in the derivation entry — never carry the figures
      above forward unchecked. *(deviation: altered — live total was 70472 B against an
      ALREADY-MOVED baseline of 70500 (task 644 phase 5, same-day /recap-row move), not 70400 B;
      per-file figures 21496/25692 matched exactly)*
- [x] Set `eager_load.baseline_bytes`: 70400 -> **71500**. Rule: the config's own 2026-10-18
      entry names ~1,488 B of headroom as "enough to absorb an ordinary eager addition without
      immediately re-firing the gate"; 71500 leaves 1,100 B against the live 70400 B total,
      the same order of magnitude, versus the 0-200 B margins every reactive move since has
      left. *(deviation: altered — set to 71600, recomputed from live 70472 B + 1,100 B
      headroom rounded to the next 100 B, per the pre-edit re-measurement above)*
- [x] Set `files["commands/orchestrate.md"].ceiling_bytes`: 21500 -> **22000**. Rule: the
      file's own documented convention is "measured, rounded up to the next 500 B"; this is
      that convention plus one deliberate 500 B headroom step (21496 -> 21500 would be the
      reactive value; 22000 is the preventive one). Refresh `measured_bytes`/`measured_at` to
      the live figure and today's date. *(completed)*
- [x] Set `files["skills/skill-orchestrate/SKILL.md"].ceiling_bytes`: 26000 -> **26500**. Same
      rule and same one-step headroom addition. Refresh `measured_bytes`/`measured_at`.
      *(completed)*
- [x] Append one dated entry to EACH of the three `derivation` / `note` narrative strings,
      matching the surrounding voice and explicitly framed as **preventive headroom, not a
      response to an overage** — stating that the gate was green at the time of the move, that
      no trim was attempted because the three most recent entries already record "no further
      redistributable bloat found nearby", and naming the one-step-beyond-the-rounding-
      convention derivation used. Do not restate the other two entries' content in each note;
      each note covers only its own figure. *(completed)*
- [x] Confirm the file still parses: `jq -e . agent-system/extensions/core/context/config/orchestrator-context-budget.json >/dev/null`. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: (omitted — default `per-substep`)

**Scope Hypothesis**: This phase asserts exactly three numeric figures move and that no file
other than `orchestrator-context-budget.json` is touched. Confirm at implementation time by
`git diff --stat` showing a single changed file, and by the pre-edit re-measurement step above
agreeing with 70400 / 21496 / 25692 before any target is computed.

**Tier Justification**: `verify-deploy.sh --only-gate 20` exercises all three sub-checks that
read this file, and `run-all.sh --only test-verify-deploy-context-budget.sh` is the one suite
whose fixtures assert against this config — together they cover every consumer of the edit, so
a full sweep buys nothing here.

**Files to modify**:
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - three
  numeric figures, two `measured_bytes`/`measured_at` refreshes, three appended dated
  derivation entries.

**Verification**:
- `jq -e .` parses the file.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20 .` reports all
  four PASS lines, now with the widened bounds.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-verify-deploy-context-budget.sh`
  shows no NEW failing case beyond the single row already declared in
  `scripts/tests/known-failures.txt` (the baseline-fixture-clean assertion, blocked on an
  unrelated gate-24 finding). A changed failure *count* or a different failing case name is a
  regression and must be investigated before committing.

---

### Phase 2: Raise the contention-prone gates' static timeout bound [COMPLETED]

**Goal**: Raise `timeout_s` from 60 to 180 for gates 3, 4, and 10; record the derivation and
its deliberate deviation from the idle-cost-model rule; leave the task-610 cross-reference and
correct one stale citation.

**Tasks**:
- [x] **Re-read `agent-system/extensions/core/scripts/gate-registry.data` immediately before
      editing.** It is inside concurrent sibling task 584's declared `file_scope`. If a foreign
      uncommitted modification or a foreign commit touching it is present (check `git log` to
      confirm the work is not this task's own), STOP and report rather than proceeding.
      *(completed — `git status --porcelain` and `git log -3` on the file showed no foreign
      uncommitted change and no recent foreign commit)*
- [x] Confirm the row set before editing: exactly gates 3, 4, and 10 declare `timeout_s=60`
      (gate 8 declares 1500 and `serialized=true`; gate 17 declares 40; gate 22 declares 170;
      every other row declares 30). Verify with
      `grep -v '^#' agent-system/extensions/core/scripts/gate-registry.data | awk -F'\t' '$6==60 {print $1, $2}'`.
      If the set differs from {3, 4, 10}, reconcile against the live rows before editing — do
      not edit a row this plan did not name. *(completed — confirmed exactly {3, 4, 10})*
- [x] Edit gate 3's row (`Doc-lint (check-extension-docs.sh)`): `timeout_s` 60 -> **180**.
      Preserve the row's TAB separation exactly; the format is 9 TAB-separated fields.
      *(completed)*
- [x] Edit gate 4's row (`Task-reference lint (check-task-references.sh)`): 60 -> **180**.
      *(completed)*
- [x] Edit gate 10's row (`specs/state.json schema validation (validate-state.sh --deep)`):
      60 -> **180**. *(completed)*
- [x] Append a dated note to the `timeout_s` field documentation in the file's own header
      comment block recording: (a) that these three values deviate deliberately from the
      documented "roughly 3x headroom over the measured average, floor 30s" derivation because
      `gate-cost-model.csv` currently carries only a `gate8` row and cannot supply a clean
      `avg_ms` for gates 3/4/10; (b) that 180 is instead derived from gate 10's own
      independently corroborated worst standalone figure (66s, re-passing cleanly in 61-66s
      across three separate 2026-11-16 incidents) at the same ~3x headroom factor; (c) that the
      bound remains hard and killable, so a genuine runtime regression still surfaces; and
      (d) a one-line cross-reference stating that a general load-adaptive or
      concurrency-scaled timeout mechanism was deliberately NOT built here and that these three
      static values are the floor any such future design should start from. *(completed)*
- [x] Correct the stale citation in `agent-system/extensions/core/scripts/tests/known-failures.txt`
      (the `test-gate-cache-equivalence.sh|load-sensitive` row, confirmed present at line 33 of
      the live file during planning). It currently reads "gate10's declared timeout_s (30,
      gate-registry.data)" — a figure stale by two moves. Restate it as the current declared
      value and note that this raise may make the row's own `needs-owner` question
      ("whether gate10's specific 30s budget should be recalibrated") resolvable, without
      removing the row. **If the row is not found at implementation time** (a sibling may have
      rewritten the file), search `known-failures.txt` for `test-gate-cache-equivalence.sh`;
      if no such row exists at all, skip this task, record the absence via `issue-record.sh`,
      and proceed — this task is a correctness touch-up, not a precondition for the rest of the
      phase. *(completed — row found at line 33, citation corrected to 180 with the 60->180
      provenance, needs-owner note updated to reflect the raise without removing the row)*
- [x] Confirm the registry still lints: `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh`.
      *(completed — 7 passed, 0 failed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: (omitted — default `per-substep`)

**Scope Hypothesis**: This phase asserts the `timeout_s=60` row set is exactly {3, 4, 10} and
that the file's 9-TAB-separated-field shape is preserved across three row edits. Confirm with
the `awk -F'\t' '$6==60'` probe above before editing, and with
`awk -F'\t' 'NF!=9 && $0 !~ /^#/ && NF>0 {print NR}'` returning nothing after editing.

**Tier Justification**: `lint/lint-gate-registry.sh` validates the row shape and `timeout_s`
well-formedness, and the mechanically-selected suite set for this phase's touched paths
(`suite-selection-lib.sh`'s own selection: `test-gate-registry-resolution.sh`,
`test-gate-cache-lib.sh`, `test-gate-cache-equivalence.sh`, `test-deploy-baseline-lib.sh`,
`test-gate8-expected-new-distinction.sh`, `test-orchestrate-cycle-plan.sh`,
`test-run-all-failure-reporting.sh`, `test-run-all-selection.sh`,
`test-verify-deploy-gate-selection.sh`, `test-verify-deploy-gate-selection-crash-net.sh`)
covers every suite whose fixtures read `gate-registry.data` or `known-failures.txt` — including
`test-gate-cache-lib.sh`'s case 10, which asserts a registry-row `timeout_s` edit changes the
gate's implementation digest, the one behavioral consequence of this edit beyond the bound
itself.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-registry.data` - three `timeout_s` values
  60 -> 180, plus a dated note appended to the `timeout_s` field documentation.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - one stale `timeout_s`
  citation corrected in the `test-gate-cache-equivalence.sh` row.

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` exits 0.
- `grep -v '^#' .../gate-registry.data | awk -F'\t' '$6==180 {print $1}'` prints exactly
  `3`, `4`, `10`.
- No non-comment row has a field count other than 9.
- The mechanically-selected suite set for this phase's touched paths runs green:
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --fail-on-new --only
  test-gate-registry-resolution.sh,test-gate-cache-lib.sh,test-gate-cache-equivalence.sh,test-deploy-baseline-lib.sh,test-gate8-expected-new-distinction.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh,test-verify-deploy-gate-selection.sh,test-verify-deploy-gate-selection-crash-net.sh`
  exits 0. `--fail-on-new` is used deliberately: `test-gate-cache-equivalence.sh` already
  carries a declared `load-sensitive` row in `known-failures.txt`, so an EXPECTED failure there
  must not be read as this phase's regression. Any suite classified NEW is a regression and
  blocks the commit. This selection is ~10-15 minutes of wall time, dominated by
  `test-gate-cache-equivalence.sh` (~543s hinted) — budget for it rather than narrowing the
  list.

---

### Phase 3: Redeploy and full-gate verification [COMPLETED]

**Goal**: Regenerate the deployed tree from the edited source store and confirm the whole gate
battery is green, with the two edited files' deployed mirrors content-hash equal to their
sources.

**Tasks**:
- [x] Confirm Phases 1 and 2 are both committed before deploying — a deploy mid-edit publishes
      a half-applied state. *(completed — `git log --oneline -3` showed both phase commits
      landed, with no uncommitted change to either of this task's edited files)*
- [x] Run the redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the
      invocation the repo's own deploy path documents, if it differs at implementation time).
      *(completed)*
- [x] Confirm the two deployed mirrors now match their sources:
      `diff agent-system/extensions/core/context/config/orchestrator-context-budget.json .claude/context/config/orchestrator-context-budget.json`
      and
      `diff agent-system/extensions/core/scripts/gate-registry.data .claude/scripts/gate-registry.data`,
      both silent. *(completed — both silent, plus a third confirming diff on
      known-failures.txt, also silent)*
- [x] Run the full gate sweep and confirm gate 5 (content-hash equality) is green — it is
      expected RED between the Phase 1/2 edits and this redeploy, and its return to green is
      the specific signal this phase exists to produce. *(deviation: altered — per this
      dispatch's Batch Gate Deferral directive, the full unflagged sweep was NOT independently
      re-run; discharged instead via `verify-deploy.sh --only-gate 5,10,20 --skip-unchanged`.
      Gate 5 still FAILs, but its 4 findings are exclusively on files OUTSIDE this task's
      file_scope -- context/standards/orchestrator-runtime-files.md,
      scripts/lib/runtime-file-patterns.sh, scripts/orchestrate-build-aux-dispatch.sh,
      scripts/tests/test-runtime-file-tracking.sh -- committed by concurrent sibling tasks at
      2026-11-18T14:33-14:39, landing in the window around this task's own deploy. This task's
      own three edited files are separately diff-confirmed content-hash equal above. The
      full-sweep gate-5 return to green is deferred to the batch's own close sweep, which will
      pick up the now-settled sibling commits; see issues.jsonl for the full attribution.)*
- [x] Confirm the raised bounds behave as intended: gate 10 completes without a TIMEOUT finding
      in the sweep. If the host is idle at verification time the raise will not be *exercised*;
      record that honestly rather than claiming the contention case was proven. *(completed —
      gate 10 PASSed cleanly and quickly in this scoped run; the host was not under the kind of
      concurrent load that previously triggered the 60s timeout, so the raise's contention-case
      benefit is not directly exercised/proven here, only its non-interference with the idle
      case)*
- [x] Record issues and wins for this phase via `issue-record.sh` as they arise. *(completed —
      three issues recorded across this dispatch: two verification nuances in Phases 1-2, one
      scope-excursion attribution in this phase)*

**Timing**: 1 hour

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: (omitted — default `per-substep`)

**Scope Hypothesis**: This phase asserts that `deploy-headless.sh` regenerates the whole
deployed `.claude/**` tree and that the only *intended* content changes in it are the two
mirrored files. Confirm with `git status --short` after the deploy; `.claude/**` is gitignored,
so the check is the two `diff` invocations above plus gate 5's own verdict, not a git diff.

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree.

**Verification**:
- The complete gate set runs: `bash agent-system/extensions/core/scripts/verify-deploy.sh .`
  with no `--only-gate` narrowing, reporting no NEW findings relative to the pre-change
  baseline. Pre-existing, separately-owned red gates (notably gate 8's shell suites, explicitly
  out of this task's scope) are compared against, not fixed — a finding present before this
  task's first edit is not this task's regression, and the comparison must be stated
  explicitly rather than assumed.
- Gate 5 (content-hash equality) PASSES.
- Gate 20 PASSES with the three widened bounds visible in its output.
- Gate 10 completes without a TIMEOUT finding.
- Both `diff` invocations above are silent.

---

## Testing & Validation

- [ ] `jq -e .` parses `orchestrator-context-budget.json` after the edit.
- [ ] `verify-deploy.sh --only-gate 20` reports four PASS lines with the new bounds.
- [ ] `run-all.sh --only test-verify-deploy-context-budget.sh` shows no new failing case.
- [ ] `lint/lint-gate-registry.sh` exits 0.
- [ ] `run-all.sh --only test-gate-registry-resolution.sh` passes cases 5, 12, 14.
- [ ] Exactly gates 3, 4, 10 declare `timeout_s=180`; gate 8 still declares 1500.
- [ ] Post-deploy: both source/deployed `diff`s silent; gate 5 green; full sweep shows no new
      findings versus the pre-change baseline.

## Artifacts & Outputs

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` (3 figures
  moved, 3 dated derivation entries appended)
- `agent-system/extensions/core/scripts/gate-registry.data` (3 `timeout_s` values raised, one
  dated field-documentation note appended carrying the task-610 cross-reference)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` (one stale citation
  corrected)
- Regenerated deployed `.claude/**` tree
- `specs/607_gate_20_context_budget_and_timeout_sensitivity/summaries/01_*-summary.md`

## Rollback/Contingency

All three edits are small, self-contained, and reversible by restoring the prior numeric values
and removing the appended narrative entries; each phase's work is committed separately, so a
single `git revert` of either phase's commit restores that figure set without touching the
other. A redeploy after any revert restores the deployed mirrors. No schema, no executable
logic, and no gate severity changes, so there is no partially-applied state that leaves the
battery in an inconsistent configuration — the worst case is a deployed tree out of sync with
the source store, which gate 5 detects and a redeploy fixes.

If the Phase 3 full sweep surfaces a finding that cannot be attributed to a pre-existing,
separately-owned red gate, revert both phases' commits, redeploy, and re-run the sweep to
confirm the finding disappears before re-attempting — do not debug forward with the deployed
tree in an unknown state.
