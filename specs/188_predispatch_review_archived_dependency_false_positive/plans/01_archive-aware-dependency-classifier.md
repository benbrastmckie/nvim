# Implementation Plan: Task #188

- **Task**: 188 - Fix orchestrate-predispatch-review.sh Class A false positive: archived completed dependencies reported as nonexistent
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/188_predispatch_review_archived_dependency_false_positive/reports/01_archived-dependency-false-positive.md
- **Artifacts**: plans/01_archive-aware-dependency-classifier.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-predispatch-review.sh`'s Class A dependency-edge classifier binds `$all` to
`active_projects[]` only (line 213), so any dependency `/todo` has archived resolves to null and
buckets as `"nonexistent"` — the loudest verdict the classifier has — despite being satisfied.
The fix adopts the pattern `orchestrate-triage-classify.sh` already proves in this same codebase:
source `lib/task-lookup-lib.sh`, stage the flattened archive array through a tempfile read back
via `--slurpfile` (never `--argjson`, whose argv ceiling was already observed to break at a
~960KB archive), merge active + archived into `$all`, and add a fifth bucket
`archived_satisfied` so the word `nonexistent` is reserved for edges resolvable nowhere. Report
rendering splits Class A into a loud primary list plus a clearly-labeled informational archived
list — demotion, never suppression, per this script's own never-silent design philosophy. New
test fixtures close the gap that let this bug ship: the existing suite has no dependency array
and no archive fixture at all.

### Research Integration

The research report's seven recommendations are adopted essentially intact, with phase
boundaries drawn around them:

- Recommendations 1-4 (source the lib, tempfile + `--slurpfile`, merged `$all`,
  `$archived_nums` + 4-way bucket branch) become Phase 1.
- Recommendation 5 (report-mode presentation, informational demotion rather than suppression)
  becomes Phase 2.
- Recommendation 6 (test fixtures, landing in the same round as the fix, not deferred) becomes
  Phase 3.
- Recommendation 7 (deploy check; `lib/task-lookup-lib.sh` already ships in the core manifest at
  line 116, so no new deploy wiring is needed) becomes Phase 5.

Two research decisions are carried into the plan as settled and are NOT re-opened by any phase:
no new verdict is added for "completed but not yet archived" (`out_of_batch_terminal` already
covers it correctly and non-loudly), and neither `orchestrate-batch-admit.sh` nor
`orchestrate-triage-classify.sh` is touched — the former's active-only comparison set is
intentionally correct (an archived task poses zero live file_scope collision risk) and it never
emits a `nonexistent`-flavored verdict at all; the latter already merges active + archived via
the same library.

One deliverable the research did not name was found during planning and is added as Phase 4:
`context/patterns/batch-orchestration-guardrails.md` (lines ~916-920) documents the classifier
as producing "one of four buckets" and names all four. Landing a fifth bucket without updating
that Non-Negotiable's narrative leaves the guardrail doc describing behavior the script no
longer has. The SUT's own header comment (lines 11-12) carries the same four-bucket list and is
corrected alongside it in Phase 2.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap_path provided in the dispatch context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Class A resolves dependency targets against active + archived tasks, not active alone.
- A dependency satisfied by an archived task reports at informational volume under a distinct
  bucket name; the word `nonexistent` never appears for it.
- A dependency resolvable in neither `active_projects[]` nor the archive still reports loudly as
  `nonexistent`.
- Class A's dependency logic gains its first test coverage, pinning both outcomes.
- Source-store edit only (`agent-system/extensions/core/**`), with the deployed `.claude/` copy
  reproducing both outcomes after a regeneration.

**Non-Goals**:
- No change to `orchestrate-batch-admit.sh` or `orchestrate-triage-classify.sh` (research
  confirmed neither needs it).
- No new verdict for "completed but not yet archived" — `out_of_batch_terminal` already covers it.
- No filesystem scan of `specs/archive/` directories; `/todo` writes `archive/state.json` and
  performs the `specs/archive/{NNN}_{slug}` directory move in the same run, so the state-file
  lookup is a faithful proxy and preserves the script's stated Context Flatness Constraint.
- No change to `orchestrate-batch-admit.sh`'s silent-admit behavior for a candidate absent from
  `active_projects[]` (noted by research as a separate, unreported behavior, explicitly out of
  scope).
- No resolution of the guardrail doc's "Open Design Fork" (whether an out-of-batch predecessor
  should be excluded from live dispatch). This stage stays warn-only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `--argjson` argv ceiling on a long-lived archive (~960KB observed to give exit 126, "Argument list too long") | H | M | Use the tempfile + `--slurpfile` pattern from the start, transcribed from `orchestrate-triage-classify.sh` lines 222-225 — never `--argjson` for the archive array |
| Widening the Class A/B `$all` binding leaks into an unrelated consumer of the same name | M | L | Confirmed at plan time that the Class C/D/E jq program (lines 361-431) binds its own separate `$all`; Phase 1 re-verifies by enumerating every `$all` reference before landing |
| New `trap ... EXIT` for the tempfile clobbers existing cleanup | M | L | The script currently has NO `trap` at all (`admit_stderr_file` is removed inline at line 349), so a single new EXIT trap is additive; Phase 1 verifies `grep -n 'trap '` still shows exactly one |
| Regression in Class A goes unnoticed — no existing fixture touches dependencies or the archive | H | M | Phase 3 lands fixtures in the same round as the fix, not as a follow-up; Phase 5 gates on the full suite passing |
| Deployed `.claude/` copy drifts from the source store, so the fix appears not to work | M | M | Phase 5 runs `deploy-headless.sh` (default non-destructive resync) and re-runs the acceptance checks against the deployed copy |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Archive-aware Class A/B resolution [COMPLETED]

**Goal**: Class A/B resolve candidate and dependency entries against active + archived tasks,
and Class A gains a distinct `archived_satisfied` bucket, leaving `nonexistent` for edges
resolvable nowhere.

**Tasks**:
- [x] Enumerate every `$all` reference in `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`
      (`grep -n '\$all' `) and confirm the Class A/B binding at line 213 is used only inside the
      Class A/B blocks (lines 216-239), and that the Class C/D/E program (lines 361-431) binds
      its own separate `$all`. Do not proceed to the edit if this does not hold. *(completed:
      confirmed both hypotheses hold before editing)*
- [x] Add `source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"` (with the `# shellcheck disable=SC1091`
      line above it) immediately after the existing `source "${SCRIPT_DIR}/lib/common.sh"` at
      line 128 and before `PROJECT_ROOT=...`, matching `orchestrate-triage-classify.sh`'s
      ordering at its lines 200-205. *(completed)*
- [x] Before the Class A/B jq invocation (current line 207), stage the archive array:
      `archived_projects_json="$(task_lookup_archived_projects_json "$STATE_FILE")"`, write it to
      a `mktemp` file, and register `trap 'rm -f "$archived_projects_tmpfile"' EXIT`. Carry a
      comment naming the `--argjson`/ARG_MAX rationale and pointing at
      `orchestrate-triage-classify.sh` as the precedent, rather than restating it from scratch.
      *(completed)*
- [x] Add `--slurpfile archived_raw "$archived_projects_tmpfile"` to the Class A/B jq invocation
      and change the `$all` binding to
      `(($state_arr[0].active_projects // []) + $archived_raw[0]) as $all`, preserving the
      active-first ordering so `first` keeps `task_lookup_entry`'s active-wins contract.
      *(completed)*
- [x] Bind `($archived_raw[0] | map(.project_number)) as $archived_nums` and extend the Class A
      bucket decision (lines 223-225) to four branches: `$dep_entry == null` → `"nonexistent"`;
      `($archived_nums | index($d)) != null` → `"archived_satisfied"`; terminal status →
      `"out_of_batch_terminal"` (unchanged); else `"out_of_batch_live"` (unchanged). *(completed)*
- [x] Run `bash -n` on the edited script and confirm `grep -n 'trap '` reports exactly one trap.
      *(completed: bash -n exits 0, exactly one trap; also verified live via a synthetic
      deployed-shaped sandbox — an archived dependency reports `archived_satisfied` and a
      genuinely absent one still reports `nonexistent`, exit 0)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase assumes the Class A/B `$all` binding at line 213 has no
references outside lines 216-239, and that the script currently registers no `trap`. Both are
hypotheses from a plan-time read, not facts: the first task above confirms the binding scope by
enumeration and the last confirms the trap count, before and after the edit respectively. If
either fails, stop and re-scope rather than editing around it.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - source the lookup
  library, stage the archive array via tempfile, merge it into the Class A/B `$all`, add the
  `archived_satisfied` bucket.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` exits 0.
- `grep -n 'argjson archived\|argjson.*archived_raw'` returns nothing (the archive array is
  never passed via `--argjson`).
- Running the script against this repository's live `specs/state.json` with a candidate whose
  dependency is archived emits `archived_satisfied` for that edge and does not abort.

---

### Phase 2: Class A report rendering and header correction [COMPLETED]

**Goal**: The report reserves loud wording for genuine `nonexistent` edges and lists
`archived_satisfied` edges separately at informational volume, without suppressing them.

**Tasks**:
- [x] Split the Class A section (lines 442-456) into two derived lists using this script's own
      established two-part convention (the "Deferred: ..." / "Admitted: ..." shape already used
      by Classes C and D): a primary list of non-`archived_satisfied` findings, and a separate
      line-labeled informational list, e.g. `Archived (satisfied): #C depends on #D`. *(completed:
      rendered as "Primary (live/terminal/nonexistent):" / "Archived (satisfied):" inside the
      single Class A section, mirroring Class C/D exactly)*
- [x] Keep both lists unconditional — an `archived_satisfied` finding is demoted in wording and
      placement, never dropped. Full suppression is explicitly rejected by the research and by
      this script's never-silent design philosophy (see its Class E comment on the "0 findings
      vs. 0 matched" conflation). *(completed)*
- [x] Update the Class A negative line (line 452) so it no longer promises the absence of
      archived-satisfied targets as part of the "0 findings" claim; keep the negative accurate
      for the primary list and give the informational list its own accurate negative. *(completed)*
- [x] Update the SUT header comment (lines 11-12) from the four-bucket list to the five-bucket
      list, keeping the guardrail-doc cross-reference intact. *(completed)*
- [x] Confirm `grep -n nonexistent` in the script shows the word only on the true-nonexistent
      bucket branch, the header comment's enumeration, and the primary-list negative — never on
      an archived-satisfied path. *(completed: verified live in a synthetic sandbox — the
      archived-satisfied line renders "archived (satisfied)", never "nonexistent")*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - Class A report
  rendering split, negative-line wording, header bucket enumeration.

**Verification**:
- `bash -n` exits 0.
- A manual run against live `specs/state.json` prints the archived edges under the
  informational label and prints no `nonexistent` text for them.
- Both Class A negatives still print when their respective lists are empty (no section is ever
  silently omitted).

---

### Phase 3: Class A dependency test fixtures [COMPLETED]

**Goal**: The suite pins both acceptance outcomes — archived dependency reports as satisfied,
genuinely absent dependency still reports loudly.

**Tasks**:
- [x] Add `lib/task-lookup-lib.sh` to `setup_sandbox`'s copy list (and to the `require_file`
      preflight beside `lib/common.sh`), so the sandboxed SUT can source it. *(completed)*
- [x] Add a helper mirroring `write_state` that writes `$WORKDIR/specs/archive/state.json` (the
      path `task_lookup_archived_projects_json` derives as
      `${state_file%state.json}archive/state.json`), with a `completed_projects` array.
      *(completed: `write_archive_state`)*
- [x] Add a scenario: candidate #N carries `dependencies: [M]`, where #M exists only in the
      synthetic archive state file. Assert the output contains the `archived_satisfied` label
      for that edge and does NOT contain `nonexistent`. *(completed: Scenario 5; also verified
      the fixture is non-vacuous by temporarily reverting the Phase 1 bucket branch, confirming
      it FAILs, then restoring)*
- [x] Add a scenario: candidate #N carries `dependencies: [M]`, where #M is in neither
      `active_projects[]` nor the archive. Assert `nonexistent` still fires for that edge.
      *(completed: Scenario 6)*
- [x] Add a scenario with no `specs/archive/state.json` present at all, asserting the SUT still
      exits 0 and renders Class A (the library's documented `"[]"`-on-absent-archive contract).
      *(completed: Scenario 7)*
- [x] Run the suite and confirm every pre-existing scenario still passes. *(completed: 21 passed,
      0 failed -- 14 pre-existing + 7 new, strictly greater than the 14 pre-change count)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` - sandbox
  copy list, archive-state fixture helper, three new scenarios.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` exits
  0 with zero FAIL lines and a PASS count strictly greater than the pre-change count.
- Temporarily reverting the Phase 1 bucket branch makes the archived-dependency scenario FAIL
  (the fixture genuinely exercises the fix rather than passing vacuously); restore afterward.

---

### Phase 4: Guardrail documentation sync [COMPLETED]

**Goal**: The Non-Negotiable narrative describes the classifier's actual bucket set.

**Tasks**:
- [x] Update `context/patterns/batch-orchestration-guardrails.md` Non-Negotiable 3 (lines
      ~911-924): "one of four buckets" becomes five, adding `archived_satisfied` to the
      enumeration, and the "warning loudly ... for all three non-`intra_batch` subcases" clause
      is corrected to reflect that the archived-satisfied subcase reports informationally rather
      than loudly — a satisfied edge is not a hazard. *(completed)*
- [x] Preserve the paragraph's existing scope statements unchanged: this is still a REVIEW stage
      that never excludes on its own account, and the Open Design Fork is still open. *(completed)*
- [x] Reference the script and the bucket names as durable anchors; introduce no task-number
      citation (this file is outside `specs/**`). *(completed: `grep -n "task [0-9]"` on the
      changed file returns nothing)*

**Timing**: 0.25 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` -
  Non-Negotiable 3 bucket enumeration and volume wording.

**Verification**:
- Diff read-through confirms every changed hunk is prose inside Non-Negotiable 3.
- `grep -rn "one of four buckets" agent-system/` returns nothing.
- `grep -n "task [0-9]" ` on the changed file introduces no new match.

---

### Phase 5: Deploy regeneration and live acceptance [COMPLETED]

**Goal**: The deployed `.claude/` copy reproduces both acceptance outcomes.

**Tasks**:
- [x] Run `bash .claude/scripts/deploy-headless.sh` (default, no flag — the non-destructive
      resync mode; do NOT pass `--wipe`). *(completed: deploy landed. RESULT=landed_verify_red
      (exit 3) rather than the expected exit 0 -- see deviation note below)*
- [x] Confirm the deployed copy carries the fix:
      `diff agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh .claude/scripts/orchestrate-predispatch-review.sh`
      reports no differences. *(completed: diff is empty)*
- [x] Acceptance check 1: run
      `bash .claude/scripts/orchestrate-predispatch-review.sh <candidates>` over a candidate set
      whose dependencies point at archived tasks, and confirm zero `nonexistent` findings and
      `archived_satisfied` classification for those edges. *(completed: ran against all 53 live
      `active_projects[]` candidates -- 24 real archived-satisfied edges found (incl. this task's
      own #188 depends on #197), 0 nonexistent findings)*
- [x] Acceptance check 2: against a synthetic state file (or a candidate carrying a synthetic
      dependency number present in neither `active_projects[]` nor `specs/archive/state.json`),
      confirm `nonexistent` still fires loudly. *(completed: synthetic sandbox on the deployed
      copy -- #999 depends on #999999 renders "nonexistent")*
- [x] Re-run the test suite from the deployed tree
      (`bash .claude/scripts/tests/test-orchestrate-predispatch-review.sh`) and confirm it
      passes there too. *(completed: 21 passed, 0 failed)*

**Deviation (deploy-headless.sh exit code)**: `deploy-headless.sh` returned exit 3
(`RESULT=landed_verify_red`), not the expected exit 0. The deploy itself landed cleanly (the
`diff` check above is empty) and both acceptance checks plus the deployed test suite pass. The
non-zero exit comes from `verify-deploy.sh`'s check 20 (`measure-eager-context.sh --check` +
per-file ceilings), which reports `[FAIL] eager-load total (65198 B) exceeds recorded baseline
(64450 B)` and `[WARN] commands/orchestrate.md exceeds its configured ceiling`. Neither is
caused by this task: `measure-eager-context.sh --check`'s own eager-file enumeration does not
include `context/patterns/batch-orchestration-guardrails.md` (the only content file this task
touches outside `scripts/`), and `git status --short` confirms this task never touched
`CLAUDE.md`, any `merge-sources/**` file, or any `rules/**` file -- the three channels that sum
to the reported 65198 B. This is pre-existing/concurrent drift in the orchestrator context
budget, out of this task's scope and plan, observed rather than fixed here per the
observation-duty contract.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Scope Hypothesis**: the research measured 20 archived-resolving dependency edges and 0
genuinely absent edges in this repository (and 37/0 in BimodalLogic). Those counts are a
hypothesis about state at research time, not a fixed acceptance number — `specs/state.json` and
`specs/archive/state.json` both change between rounds. Confirm the live count at implementation
time by re-deriving it from the two state files, and assert the invariant (every flagged edge
resolves to the archive; `nonexistent` count is zero) rather than the specific number.

**Files to modify**:
- None (deploy regeneration writes `.claude/**`, which is a gitignored disposable artifact and
  is not a hand-authored edit target).

**Verification**:
- `deploy-headless.sh` exits 0.
- The `diff` above is empty.
- Both acceptance checks produce the stated outcomes from the deployed copy.
- The deployed test suite exits 0.

---

## Testing & Validation

- [x] `bash -n` clean on the edited script.
- [x] `test-orchestrate-predispatch-review.sh` passes in full from the source store, with new
      scenarios covering archived-resolving, genuinely-absent, and archive-file-absent cases.
      *(21 passed, 0 failed)*
- [x] A live run reports zero `nonexistent` findings where every out-of-batch edge resolves to
      the archive. *(confirmed against all 53 live active_projects[] candidates: 24
      archived-satisfied edges, 0 nonexistent findings)*
- [x] A synthetic unresolvable dependency still reports `nonexistent` loudly. *(confirmed on both
      the source-store and deployed copies)*
- [x] The archive array is never passed through `--argjson` (ARG_MAX regression guard).
      *(`grep -n 'argjson.*archived' ` returns nothing)*
- [x] Both acceptance outcomes reproduce from the deployed `.claude/` copy after regeneration.
      *(confirmed; see Phase 5's deviation note for the one caveat -- deploy-headless.sh's own
      exit code is 3 due to unrelated, pre-existing eager-context-budget drift, not this task's
      change)*

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
- Modified: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- Regenerated (not committed, gitignored): `.claude/scripts/orchestrate-predispatch-review.sh`
- Summary: `specs/188_predispatch_review_archived_dependency_false_positive/summaries/01_*-summary.md`

## Rollback/Contingency

Every phase touches at most one file and commits per green sub-step, so reverting is a
per-commit `git revert` of the offending commit — no snapshot-and-reset is warranted for a
change of this footprint. If Phase 1's `$all`-scope enumeration shows the binding is referenced
outside the Class A/B blocks, stop before editing and re-plan rather than widening the binding.
If the deployed copy in Phase 5 disagrees with the source store after a resync, the fault is in
deploy wiring rather than this change: leave the source-store edit in place, report the deploy
discrepancy, and do not hand-author into `.claude/**`
(`rules/source-store-deploy-boundary.md`).
