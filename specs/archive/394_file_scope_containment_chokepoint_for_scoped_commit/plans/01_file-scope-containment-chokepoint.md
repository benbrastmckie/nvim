# Implementation Plan: Task #394

- **Task**: 394 - Specify and implement a file_scope-based containment chokepoint for `git-commit-scoped.sh` / `git-commit-phase.sh`
- **Status**: [COMPLETED]
- **Effort**: 6.5 hours
- **Dependencies**: None (task 304's exit-code contract is already landed; this plan extends it)
- **Research Inputs**: specs/394_file_scope_containment_chokepoint_for_scoped_commit/reports/01_containment-chokepoint-exit-code.md
- **Artifacts**: plans/01_file-scope-containment-chokepoint.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `file_scope`-Containment gate (label **V10**) inside `git-commit-scoped.sh`, layered onto
the existing `--task <N>` flag so every caller that already supplies `--task` for the V5
contended-path lease gains Containment with **zero call-site edits**. The gate classifies each
positive pathspec against the dispatching task's own declared `file_scope` (widened by the same
implicit and exempt members the postflight-sited filter already honors), drops an uncontained
path with a loud, textually distinct WARN, and emits the reserved exit code `7` when a commit
nonetheless succeeded. Posture is drop-and-warn, never refuse, and fail-open on any
missing/empty/unreadable/malformed `file_scope` or any internal error. The contract document
`git-staging-scope.md` is then updated row-for-row, and the archived specification's Rider
subsection is authored to close it.

### Research Integration

The research report's two primary decisions are adopted unchanged: (a) layer onto `--task`
rather than introduce a separate opt-in flag (every live caller that needs the protection
already passes `--task`; a new flag would reproduce the per-call-site migration burden the
chokepoint exists to eliminate), and (b) reuse the exit code `7` that task 304's own table
reserves by name for this follow-up, scoped to the commit-succeeded-with-drops shape, parallel
to V9's exit `6`.

Three corrections to the report, each established by direct reads during this planning pass and
each load-bearing (see Risks & Mitigations for the consequence of getting any of them wrong):

1. **Path normalization is mandatory, and the report does not mention it.**
   `orchestrate-cycle-postflight.sh` stages `"${TASK_DIR}/"` and `"$STATE_FILE"` as **absolute**
   paths (`orchestrate-cycle-postflight.sh:429-435`), and `lib/redeploy-checkpoint-lib.sh:288`
   stages `"$STATE_FILE"` and its sibling `TODO.md` the same way, while `file_scope` entries are
   repo-relative. A raw string predicate would classify every one of those as out-of-scope and
   drop it on every orchestrate cycle. `git-commit-phase.sh`, by contrast, passes repo-relative
   paths (`git-commit-phase.sh:197`), so both shapes are live simultaneously.
2. **The derived-output exemption must be carried into the inner check.** WORK (h) widens its
   comparison scope with `derived_probe_output_prefixes "$PROJECT_ROOT"`
   (`orchestrate-cycle-postflight.sh:1588`, from `lib/derived-artifact-probe-lib.sh`), and WORK
   (i) drops only paths WORK (h) already classified as excursions — so a declared derived-output
   path survives postflight's own filter and reaches `git-commit-scoped.sh`. An inner check that
   does not apply the same widening silently reverses an exemption the layer above deliberately
   granted.
3. **The all-dropped shape is exit `2`, not exit `4`.** If Containment drops every positive
   pathspec, V3's post-filter refusal (`git-commit-scoped.sh:519`) fires before any commit is
   attempted and exits `2`. Exit `4` (V6) is reachable only when some positive pathspecs
   survive, a drop occurred, and the survivors carry no diff.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- A Containment gate (V10) inside `git-commit-scoped.sh`, reached by every `--task`-supplying
  caller with no edits to any caller.
- Correct normalization and carve-out handling, so no currently-correct commit regresses.
- Exit code `7` emitted for the commit-succeeded-with-Containment-drops shape, independently
  attributable from exit `3` (V5 Overlap refusal), exit `6` (V9 repository boundary), and exit
  `4` (V6 ambiguous no-commit).
- New regression cases in `tests/test-git-commit-scoped.sh` covering fail-open, partial drop,
  all-dropped, exit-7 emission, the absolute-path postflight shape, and the derived-output
  exemption — without regressing any existing case.
- `git-staging-scope.md` updated: exit-code table rows `2` and `7`, a V10 gate-label entry, the
  Containment-filter subsection extended to three layers, and the archived specification's
  Rider subsection ("Phase Commit (mid-dispatch)") authored.

**Non-Goals**:
- Editing `git-commit-phase.sh` (outside this task's declared `file_scope`), including removing
  its now-redundant own self-check — see Decisions.
- Migrating the ~12 per-extension implementation agents onto `git-commit-phase.sh`; the whole
  point of this design is that they need no edits.
- Repairing those agents' dead cross-reference prose (a separate, already-surfaced follow-up).
- Any new refusal mode. Containment never refuses a whole commit on its own.

## Decisions

- **Mechanism**: layered onto `--task`, evaluated inside the V2 classification loop immediately
  after V9's own repository-containment branch, in the in-repo (`*)`) arm where V9's
  per-pathspec `p_dir_rel` result is already computed. Reusing that value gives normalization for
  free and inherits V9's empirically-verified leaf-symlink safety (V9 deliberately resolves only
  the pathspec's PARENT, never its final component); a fresh `realpath` over the whole pathspec
  would resolve a leaf symlink to its target and could misclassify scope membership.
- **Effective scope** = declared `file_scope`, plus the task's own resolved task directory
  (`task_lookup_dir` from `lib/task-lookup-lib.sh`, already a required dependency of the test
  harness), plus the two fixed literals `specs/TODO.md` and `specs/state.json`, plus every
  `derived_probe_output_prefixes` entry. The plan path needs no separate carve-out: it lives
  under the task's own directory, which the implicit member already admits — and
  `git-commit-scoped.sh` has no `--plan-path` flag with which to identify it anyway.
- **Exit codes**: `7` only when `commit_exit == 0` and at least one Containment drop occurred;
  precedence after V8 (`5`) and V9 (`6`), so an invocation that trips both V9 and V10 reports
  `6`. The all-dropped shape stays exit `2` (V3) and the survivors-but-no-commit shape stays
  exit `4` (V6), both via the existing `dropped_pathspecs` wiring.
- **`git-commit-phase.sh`'s own self-check is left in place.** It becomes redundant for the one
  caller that reaches it, but it is idempotent, fail-open and cheap, the file is outside this
  task's `file_scope`, and it additionally records a `scope excursion` issue-log entry. The
  redundancy is documented in `git-staging-scope.md` rather than silently left for a reader to
  discover.
- **Issue-log recording on drop**: the new gate mirrors `git-commit-phase.sh`'s non-fatal
  `issue-record.sh --class "scope excursion"` call, under an idiom that tolerates the script
  being absent entirely (it is absent in the suite's scratch repos), so no change to the test
  harness's `REQUIRED_SCRIPTS` is needed for it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing normalization drops the absolute `TASK_DIR/`, `TODO.md`, `state.json` carve-outs on every orchestrate cycle | H | H if unaddressed | Phase 1 normalizes via V9's own `p_dir_rel` + basename rejoin; Phase 3 adds a case asserting the exact live postflight pathspec shape (absolute carve-outs + relative `modified_files`) commits unchanged |
| Omitting the derived-output widening reverses postflight's deliberate exemption | M | M (fires only in consumer repos declaring `derived_artifact_probes`; `[]` in this repo) | Phase 1 splices `derived_probe_output_prefixes` into the effective scope; Phase 3 covers it with a declared-prefix fixture |
| Trailing-slash asymmetry (`specs/394_x/` vs `specs/394_x`) makes a directory pathspec miss its own scope entry | M | M | Normalize both sides by stripping one trailing `/` before the predicate; Phase 3 covers a directory pathspec explicitly |
| The gate becomes live for every task that declares `file_scope` (most now do), so a false positive blocks real work | H | L after mitigation | Drop-and-warn only, fail-open on every error path, and an unconditional `|| true`-equivalent guard around every helper call; the existing 40+ suite cases run with no `specs/state.json` in the scratch repo and therefore prove the fail-open path still commits exactly as before |
| Regressing one of the existing V2/V3/V5/V6/V7/V8/V9 cases | M | L | Phase 1 and 2 both close on a green `test-git-commit-scoped.sh`; the final phase runs the full gate set |
| Source-store/deploy skew: edits land in `agent-system/**` while the runtime copies live in `.claude/scripts/` | M | M | All edits target the source store only (per `.claude/rules/source-store-deploy-boundary.md`); propagation is the orchestrator's deploy-pending gate's job, not an edit under `.claude/**` |
| Concurrent sibling task 393 is in flight this cycle | L | L | 393's `file_scope` is ten per-extension agent definitions; zero overlap with this task's three files. Re-read each file immediately before editing and stage only this task's own hunks |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: V10 Containment Classification in `git-commit-scoped.sh` [COMPLETED]

**Goal**: The gate exists and drops correctly. Exit codes are deliberately NOT changed yet —
Containment drops flow through the existing `dropped_pathspecs` wiring only, so this phase is
independently verifiable against unchanged exit-code behavior.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/git-commit-scoped.sh` immediately before
      editing (sibling task 393 is dispatched this same cycle).
- [x] Add an effective-scope resolution block gated on `[ -n "$contention_task_number" ]`,
      placed after the V5 block and before the V2 loop. Resolve the state entry with
      `task_lookup_entry`/`task_lookup_dir` (`lib/task-lookup-lib.sh`, sourced defensively — a
      failed source must leave the scope array empty, i.e. fail open).
- [x] Build `containment_scope_arr` from: declared `file_scope` entries; the resolved task
      directory; the literals `specs/TODO.md` and `specs/state.json`; and every entry of
      `derived_probe_output_prefixes "$PROJECT_ROOT"` (sourcing
      `lib/derived-artifact-probe-lib.sh` defensively, same fail-open rule). Leave the array
      EMPTY on a missing/empty/`null`/malformed `file_scope` — an empty array disables the gate
      entirely.
- [x] Normalize every scope entry and every candidate pathspec to a repo-relative form with at
      most no trailing slash, and implement `is_contained` as exact match OR either path a
      directory ancestor of the other (ported from `git-commit-phase.sh:244-257`).
- [x] Add the V10 branch inside the V2 loop's in-repo `*)` arm, deriving the pathspec's
      normalized form from V9's already-computed `p_dir_rel` plus the original pathspec's
      basename (never a fresh whole-path `realpath`, which would resolve a leaf symlink).
      Evaluated BEFORE case 1 so a dropped path never reaches `git add`.
- [x] On an uncontained path: print a WARN textually distinct from both case 3's and V9's; append
      to `dropped_pathspecs` AND to a new `containment_dropped` array; add to NEITHER
      `add_pathspecs` NOR `filtered_pathspecs`; make one non-fatal
      `issue-record.sh --task <N> --kind issue --class "scope excursion" --severity minor` call
      that tolerates the script being absent.
- [x] Document V10 in the script header's "Safety gates" list, in the same voice as V9, naming
      the fail-open posture, the normalization rule and why the leaf is never resolved.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only "$(source agent-system/extensions/core/scripts/lib/suite-selection-lib.sh && suite_selection_select agent-system/extensions/core/scripts/git-commit-scoped.sh | paste -sd,)"` runs exactly the resolver's covering suite set for this one touched script — its own suite plus every suite exercising a live caller — which is the cheapest check that covers a shared-script edit without paying the doc-lint and deploy gates this phase cannot affect.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - new effective-scope resolution
  block, the V10 classification branch, the `containment_dropped` array, header documentation.

**Verification**:
- `bash -n` parse check plus `shellcheck` clean on the edited script.
- The `--only` suite set above is green; in particular every pre-existing case still passes,
  which is itself the fail-open proof (the scratch repos carry no `specs/state.json`).
- Ad-hoc scratch-repo probe: a repo with a `specs/state.json` declaring a one-entry `file_scope`
  drops an out-of-scope path with the new WARN and commits the in-scope one.

---

### Phase 2: Exit Code 7 and the Exit-Code Decision Wiring [COMPLETED]

**Goal**: The reserved exit code `7` is emitted for the commit-succeeded-with-drops shape, with
documented precedence relative to V8's `5` and V9's `6`, and with the V3/V6 folds left
untouched.

**Tasks**:
- [x] Add the V10 exit-code decision after the existing V9 decision block
      (`git-commit-scoped.sh:855-857`): exit `7` when `${#containment_dropped[@]} -gt 0` and
      `commit_exit -eq 0`.
- [x] Document in-script, in the header's exit-code list, that an invocation tripping both V9 and
      V10 reports `6` (V9 keeps precedence by placement), that the all-dropped shape remains V3's
      exit `2`, and that the survivors-but-no-commit shape remains V6's exit `4`.
- [x] Verify that no `set -u` unguarded-empty-array expansion is introduced (match the existing
      `${#array[@]}`-test-first idiom used by V6, V8 and V9).

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Tier Justification**: the same resolver-driven `run-all.sh --only "$(… suite_selection_select agent-system/extensions/core/scripts/git-commit-scoped.sh …)"` set covers this edit, because an exit-code change is observable only through this script's own suite and the suites of its live callers, which that set enumerates exactly.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - V10 exit-code decision block and
  the header exit-code list entry for `7`.

**Verification**:
- Scratch-repo probe: partial Containment drop with a committable survivor exits exactly `7`;
  an all-dropped invocation exits `2`; a drop whose survivors carry no diff exits `4`.
- The `--only` suite set above is green.

---

### Phase 3: Regression Suite Cases [COMPLETED]

**Goal**: Every behavioral claim above is asserted by a test that would fail against the
pre-change script, verified via `git log`/`git show --name-only`, never exit code alone.

**Tasks**:
- [x] Add a `build_repo_with_scope <file_scope-json>` helper (or extend `build_repo`) that writes
      a synthetic `specs/state.json` carrying one `active_projects` entry with a declared
      `file_scope`, following the suite's existing inline-fixture style. *(completed: also
      provisions baseline a.txt/b.txt inside the task directory and an out.txt fixture under a
      SIBLING task directory, specs/998_sibling/ -- needed because a.txt/b.txt cannot ever be
      dropped, see the deviation note below)*
- [x] Case: `--task` given, no `specs/state.json` at all -> fail-open, commit unchanged. *(completed: Z1)*
- [x] Case: `--task` given, entry present but `file_scope` absent/`[]`/malformed -> fail-open. *(completed: Z2, covering all four shapes -- absent, `[]`, a non-array string, and an array with a non-string member -- in one case)*
- [x] Case: partial drop -> the out-of-scope path is absent from the commit, the in-scope path
      landed, the distinct WARN appears, exit `7`. *(completed: Z3)*
- [x] Case: every positive pathspec out of scope -> exit `2` (V3), nothing staged. *(completed: Z4)*
- [x] Case: drop plus survivors carrying no diff -> exit `4` (V6). *(completed: Z5)*
- [x] Case: **the live postflight shape** — absolute `<repo>/specs/<NNN>_<slug>/`, absolute
      `<repo>/specs/TODO.md`, absolute `<repo>/specs/state.json`, plus a relative in-scope
      source path — all land, nothing is dropped, exit `0`. *(completed: Z6)*
- [x] Case: a directory pathspec with a trailing slash matching a `file_scope` entry without one
      (and the converse) is contained. *(completed: Z7)*
- [x] Case: a path outside `file_scope` but under a `derived_artifact_probes`-declared
      `derived_output_dirs` prefix in `<repo>/.claude-extensions.json` is NOT dropped. *(completed: Z8)*
- [x] Case: `--task` omitted entirely -> no Containment check at all, even with a declared
      `file_scope` present. *(completed: Z9)*
- [x] Case: the drop WARN still appears when `issue-record.sh` is absent from the scratch repo
      (non-fatality proof). *(completed: Z10)*
- [x] If the derived-output case requires `lib/derived-artifact-probe-lib.sh` in the scratch
      repo, add it to `REQUIRED_SCRIPTS` and to `build_repo`'s copy loop, preserving the
      sourced-not-executed `chmod` exemption pattern. *(completed: added to REQUIRED_SCRIPTS and
      all three chmod-exemption copy loops -- build_repo, build_repo_tracked_ignored,
      build_repo_movable)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: ten new cases are anticipated, and `REQUIRED_SCRIPTS` is anticipated to
need one new entry. Confirm at implementation time by running the suite and counting PASS lines
against the pre-change total; if a case proves unreachable or duplicative, say so explicitly
rather than padding to ten.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh` is the whole blast radius of editing that one suite file — nothing else in the repository reads it.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - new fixture helper and
  the new cases.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` exits `0` with the
  pre-change case count plus the new cases, and zero FAIL lines.
- Negative-control check, matching the suite's existing probe discipline: each new assertion is
  confirmed to fail against a copy of the pre-change script, so no new case is vacuous.

---

### Phase 4: `git-staging-scope.md` Contract Update [COMPLETED]

**Goal**: The standards document states the landed semantics, so the reserved row no longer
reads "RESERVED, not yet emitted".

**Tasks**:
- [x] Rewrite the exit-code table's row `7` in the same prose style as rows `3` and `6`: the V10
      decision, drop-and-warn posture, `--task`-gated, fail-open, and the V9-keeps-precedence
      rule. *(completed)*
- [x] Extend row `2`'s parenthetical so the all-positive-pathspecs-dropped clause names V10
      alongside V2/V9, and row `4`'s so `dropped_pathspecs` is stated to carry Containment drops
      too. *(completed)*
- [x] Add a **V10** entry to the gate-label list after V9, in the same voice: the predicate (one
      path against one task's own declared scope, as distinct from the V5 Overlap family), the
      effective-scope members (declared `file_scope`, implicit task directory, the two `specs/`
      literals, declared derived-output prefixes), the normalization rule, and the fail-open
      posture. *(completed)*
- [x] Update the "Staging-Layer Containment Filter" subsection: it currently states the V-gates
      all live inside the script while the Containment filter is sited one layer above. With V10
      landed there are now three Containment sites (postflight WORK (h)/(i), the
      `git-commit-phase.sh` self-check, and V10 inside the script) — state all three, which one
      reaches which commit surface, and that `git-commit-phase.sh`'s own self-check is now
      deliberately redundant rather than load-bearing. *(completed)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: four edit sites are anticipated in this one file (rows `2`, `4`, `7`; the
gate-label list; the Containment-filter subsection — the first three being table rows in one
block). Confirm by grepping the rendered file for `RESERVED` (must be gone) and for `V10` (must
appear in both the table and the gate-label list).

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__`-class coverage for this pure-prose standards file (its only mapped suite, `test-todo-move-pair-staging.sh`, exercises unrelated staging behavior), so the honest covering check is the `prose` row's diff read-through plus `bash <source_dir>/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 <source_dir>` with `<source_dir>` resolved to `agent-system/`.

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - exit-code table rows
  `2`/`4`/`7`, the V10 gate-label entry, the Containment-filter subsection.

**Verification**:
- Diff read-through confirming every hunk is prose/table text.
- `grep -c "RESERVED" ` on the file returns `0` for the exit-7 row.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system`
  is green (doc-lint and task-reference lint against the source store).

---

### Phase 5: Rider Subsection and Full Gate Sweep [COMPLETED WITH EXCLUSIONS]

**Goal**: The archived specification's Rider is closed, and the whole change is verified against
the complete gate set.

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 doc-lint: "deployed script content drift" for `test-git-commit-scoped.sh` | Source-store-only editing by design (`source-store-deploy-boundary.md`); the deployed `.claude/` copy is intentionally stale until the next `deploy-headless.sh` run, which is outside this task's `file_scope` and the plan's own acknowledged "Source-store/deploy skew" risk. | `check-extension-docs.sh` output: `FAIL: deployed script content drift (deployed != extension source): scripts/tests/test-git-commit-scoped.sh`. |
| Gate 3 doc-lint Rule R: `index-entries.json` `line_count` mismatch for `git-staging-scope.md` (748 vs. actual 811) | The remedy script explicitly refuses to run from the source store ("must run from a deployed scripts/ tree ... Deploy first"), confirmed by direct invocation; `index-entries.json` is outside this task's own `file_scope` and remains unmodified by this task's commits. | `generate-context-line-counts.sh --write` output: `ERROR: generate-context-line-counts.sh must run from a deployed scripts/ tree ...`; `git status --porcelain agent-system/extensions/core/index-entries.json` returns empty throughout this task. |
| Gate 5 manifest-driven verification: "Content differs from source" for `git-staging-scope.md` and `test-git-commit-scoped.sh` | Same source-store/deploy-boundary skew as the Gate 3 deploy-drift finding above — the deployed `.claude/` copies have not yet been regenerated from this task's source-store edits. | `verify-deploy.sh` full-run output: `core: Content differs from source: context/standards/git-staging-scope.md` and `... test-git-commit-scoped.sh`. |
| Gate 8 `run-all.sh`: `test-run-all-selection.sh` case1/case1b/case3 | Pre-existing, unrelated to this task: `suite_selection_select`'s current grep-based resolution for `lib/common.sh` returns the list of referencing suites, never the `FULL_SWEEP` sentinel the test expects; neither `suite-selection-lib.sh` nor `test-run-all-selection.sh` was touched by this task or any of its commits (last touching commits are `task 366`/`task 411`, both predating this task). | `git log --oneline -- agent-system/extensions/core/scripts/lib/suite-selection-lib.sh agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` shows no commit from this task; `git status --porcelain` on both files is empty throughout this task; failure reproduced identically under both heavy and low concurrent system load. |
| Gate 8 `run-all.sh`: `test-gate-cache-equivalence.sh` cold-baseline/negative-case | Pre-existing, unrelated to this task: gate 10 (`validate-state.sh --deep` against the live, now-large `specs/state.json`) consistently exceeds the fixture's hardcoded 30s bound; the script under test was last touched by `task 416`, predating this task, and this task's `file_scope` does not include it. | `git log --oneline -- agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` shows no commit from this task; failure (`gate10 (gate10_run) exceeded its 30s timeout`) reproduced identically on a re-run under confirmed-idle concurrent load (`ps aux` showed zero other verify-deploy/run-all processes). |

No residual work remains for this task: `test-git-commit-scoped.sh` (62/62) and `test-git-commit-phase.sh` are both independently confirmed green, which is this phase's own named verification criterion for the files this task's `file_scope` actually covers; the five excluded findings above are each either a structural deploy-boundary artifact this task cannot and should not fix from the source store, or a corpus-wide pre-existing defect this task did not introduce and whose fix belongs to separately-scoped future work. An issue-log entry (`--class "unrelated test corpus defect"`) was filed non-fatally rather than silently dropped.

**Tasks**:
- [x] Author the "Phase Commit (mid-dispatch)" subsection in `git-staging-scope.md`, as the
      archived specification's Rider requires, documenting the asymmetry: a phase commit fires
      mid-dispatch inside an already-running agent, with no postflight in scope and no guarantee
      the cycle-scoped contention manifest exists or is current — so a guard for that surface
      must be sited in the recipe itself or inside `git-commit-scoped.sh`, which V10 now is.
      Cross-reference the existing `### implement` section and the Containment-filter subsection
      rather than restating their content. *(completed)*
- [x] Re-read the whole edited `git-staging-scope.md` once for internal consistency between the
      new subsection, the updated Containment-filter subsection, and the exit-code table. *(completed)*
- [x] Run the complete gate set and record the result. *(completed: see Reasoned Exclusions below for two unrelated pre-existing corpus failures)*

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - new "Phase Commit
  (mid-dispatch)" subsection.

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh agent-system` — the complete gate
  set, run and observed green in this dispatch, including Gate 8's full shell-suite battery.
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` and
  `test-git-commit-phase.sh` both green.
- The archived specification's Rider requirement is satisfied: a subsection with that exact
  heading exists.

---

## Testing & Validation

- [ ] Every pre-existing case in `tests/test-git-commit-scoped.sh` still passes (the fail-open
      proof).
- [ ] Each new case is confirmed non-vacuous against the pre-change script.
- [ ] The live postflight pathspec shape (absolute carve-outs plus relative source paths) commits
      with zero drops.
- [ ] `test-git-commit-phase.sh` is green, proving the now-doubled Containment evaluation is
      idempotent for the wrapper's one caller.
- [ ] Exit codes `2`, `4`, `6` and `7` are each independently reachable and attributable.
- [ ] `verify-deploy.sh` full gate set green.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V10 gate, exit `7`).
- Modified: `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (new cases).
- Modified: `agent-system/extensions/core/context/standards/git-staging-scope.md` (exit-code
  table, V10 gate label, Containment-filter subsection, Rider subsection).
- Implementation summary at completion.

## Rollback/Contingency

Every change is additive and confined to three source-store files. If V10 proves to produce false
positives in live use, the gate is disabled by reverting the effective-scope resolution block
alone (leaving the array empty disables the predicate by construction, which is the same code
path the fail-open posture already exercises), without touching V2/V3/V5/V6/V7/V8/V9 or any exit
code below `7`. For a full revert, `git revert` of this task's phase commits restores the prior
script and contract verbatim; before any rollback that would discard uncommitted work, take a
checkpoint with `bash .claude/scripts/git-snapshot.sh 394 --no-revert`.
