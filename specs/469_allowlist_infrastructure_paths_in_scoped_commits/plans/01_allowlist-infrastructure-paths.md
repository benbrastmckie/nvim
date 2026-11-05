# Implementation Plan: Task #469

- **Task**: 469 - Allowlist infrastructure paths in scoped commits
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None (concurrent-territory serialization note only — see Risks & Mitigations)
- **Research Inputs**: specs/469_allowlist_infrastructure_paths_in_scoped_commits/reports/01_allowlist-infrastructure-paths.md
- **Artifacts**: plans/01_allowlist-infrastructure-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The Containment predicate — one concrete path tested against one task's declared `file_scope` —
is checked at three independent sites, two of which hand-copy the same two-literal allowlist
(`specs/TODO.md`, `specs/state.json`) and one of which carries no allowlist at all.
`specs/events.jsonl` is in none of them, so an append-only engine-written event row is dropped
from any commit pathspec that names it. This plan creates ONE canonical shared library holding
the engine-written-state path set (four members), migrates both existing hand-copied splices to
source it, adds the net-new splice at the third site, records the landing in the standard, and
pins the new behavior with per-site fixtures that each also assert a genuine out-of-scope path
is STILL dropped and warned. The last phase redeploys and observes a real commit carrying an
actual `specs/events.jsonl` delta, so the fix is verified end-to-end rather than only at the
predicate.

### Research Integration

The research report settles three questions this plan then executes rather than re-litigates:

- **Site inventory and exact edit points** (confirmed by direct read during planning):
  `git-commit-scoped.sh`'s V10 splices the literal pair into `containment_scope_arr` at
  `scripts/git-commit-scoped.sh:499`; `orchestrate-cycle-postflight.sh`'s WORK (h) splices the
  same pair into `effective_file_scope_json` at `scripts/orchestrate-cycle-postflight.sh:1670`;
  `git-commit-phase.sh`'s Phase-Commit Containment Self-Check (lines ~229-282) has **no**
  allowlist, because its two fixed paths sit in the untested `stage_paths` seed
  (`scripts/git-commit-phase.sh:196`) and bypass `is_contained()` entirely. Site 2 therefore
  needs a net-new splice into `file_scope_arr`, not a migration.
- **Consolidation verdict (Required Outcome 2)**: one canonical shared library, modelled on the
  proven `scripts/lib/derived-artifact-probe-lib.sh` shape (sourced, never executed; one
  function printing a compact JSON array; defensive `source ... 2>/dev/null` at every consumer).
  Both existing allowlist sites already source that sibling library for the derived-output
  widening, so the call-site shape is precedent, not invention.
- **Membership verdict (Required Outcome 2, second half)**: `specs/TODO.md`,
  `specs/state.json`, `specs/events.jsonl`, `specs/errors.json` — and nothing wider.
  `specs/CHANGE_LOG.md` (written only at archival), `specs/ROADMAP.md` (user-maintained,
  read-only for agents) and `specs/README.md` (static) are rejected against the existing
  code comment's own admission bar ("engine-written on behalf of every task").
- **Staging-side verdict (Required Outcome 3)**: no staging-side fix is needed. The report
  matched the recorded issue's exact wording, its absent `--phase`/`--dispatch-seq` flags, and
  its to-the-second timestamp against a real task-creation commit, establishing that
  `specs/events.jsonl` already reaches a `--task`-supplying `git-commit-scoped.sh` invocation in
  production via an agent-composed pathspec. The defect is confined to the predicate's
  allowlist. Phase 6 verifies this claim by observation rather than assertion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- `specs/events.jsonl` (and `specs/errors.json`) is no longer classified as a `file_scope`
  excursion at any of the three Containment sites, and no longer dropped from a commit pathspec
  that names it.
- Exactly one definition of the engine-written-state path set exists in the source store; a
  fifth infrastructure path costs one edit in one file, not three.
- The drop-and-warn posture for a genuine out-of-scope path is unchanged at all three sites, and
  that non-regression is pinned by a paired assertion in every new fixture.
- `context/standards/git-staging-scope.md` describes the landed shape truthfully (shared source,
  four members, Site 2 now carrying a splice too).
- One real commit carrying an actual `specs/events.jsonl` delta is observed after redeploy.

**Non-Goals**:

- Adding `specs/events.jsonl` or `specs/errors.json` to any `stage_paths` **seed** (WORK (i)'s
  `stage_paths=(...)` at `orchestrate-cycle-postflight.sh`, `git-commit-phase.sh:196`, or
  `orchestrator-postflight.sh:491`). Unconditionally seeding an append-only shared event store
  into every commit would sweep a concurrently-dispatched sibling's event rows into this task's
  commit — the opposite defect. The allowlist admits the path when a caller names it; it must
  not cause a caller to name it.
- Widening the allowlist beyond the four justified members.
- Migrating the hand-typed `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json" ...)`
  shape repeated across the per-extension implementation agents (lean, nix, rust, typst, books,
  latex, web, python, z3, cslib, epidemiology, founder, nvim). `git-staging-scope.md`'s "Scope of
  the `git-commit-phase.sh` migration" paragraph already records that as separately-scoped
  follow-up ground; it is not folded in here.
- Removing Site 2's self-check on the grounds that Site 3 subsumes it. The standard's existing
  ruling (deliberately redundant, left in place, records its own independent issue-log entry) is
  preserved.
- Any edit under `.claude/**`. That tree is a disposable deploy artifact; every edit lands in
  the source store `agent-system/extensions/core/` and reaches `.claude/` only via Phase 6's
  redeploy.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A failed/absent `source` of the new library silently empties the splice, REGRESSING today's admission of `specs/TODO.md`/`specs/state.json` at Sites 1 and 3 | H | M | Mandated fallback (Decision 2): every consumer falls back to the hardcoded two-literal pair when the source or the function call yields nothing, so a source failure reproduces today's behavior exactly, never a narrower scope. Pinned by a fixture at Site 3 (Phase 2) |
| Concurrent territory: open task #461 declares `git-commit-scoped.sh`; #430/#446 declare `git-commit-phase.sh`/`git-staging-scope.md`; this cycle's live siblings #428 declares `orchestrate-cycle-postflight.sh` and `test-orchestrate-cycle-postflight.sh` | H | H | Re-read every target file immediately before editing it; stage and commit only this task's own hunks with an explicit file-list pathspec; never a directory or glob add; never `git-snapshot.sh` in reverting default mode. Treat a foreign commit or foreign uncommitted modification as STOP-and-report, per `context/contracts/territory.md` |
| Sibling #428 edits `orchestrate-cycle-postflight.sh` and its suite in this same cycle — Phase 3's exact line numbers may shift under it | M | H | Phase 3 relocates its edit point by `grep -n 'specs/TODO.md", "specs/state.json"'` immediately before editing, never by the line number recorded here |
| Over-widening weakens the excursion guard | M | L | Membership frozen at four, each justified against the engine-written-on-behalf-of-every-task bar; every fixture carries a paired genuine-excursion assertion |
| A new test fixture's own `git commit` shape trips `lint-scoped-commit-boundary.sh` | L | M | Copy the shape existing fixtures already use verbatim (`git -C "$repo" commit -q -m "..."`), which passes the lint today; verify with `lint-scoped-commit-boundary.sh` in the phase that adds the fixture |
| Phase 6's real-repo observation runs against the DEPLOYED `.claude/scripts/`, which is stale for core/lean/literature at dispatch time | M | H | Phase 6 redeploys to `RESULT=landed_verify_clean` BEFORE the observation, using the bounded-wait idiom; never hand-patches a deployed file |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel. All paths below are relative to the
resolved source store `agent-system/extensions/core/` unless written out in full.

---

### Phase 1: Canonical Engine-Written-State Path Library [COMPLETED]

**Goal**: One definition of the engine-written-state path set exists, with its own regression
suite, before any consumer is migrated to it.

**Tasks**:

- [x] Create `scripts/lib/engine-written-state-paths-lib.sh`, structurally modelled on
      `scripts/lib/derived-artifact-probe-lib.sh`'s header style: a contract statement, the
      fail-open posture, and an explicit enumeration of the three consumers. Sourced, never
      executed; sets no shell options a caller inherits. *(completed)*
- [x] Export one function, `engine_written_state_paths`, printing the compact JSON array
      `["specs/TODO.md","specs/state.json","specs/events.jsonl","specs/errors.json"]` on stdout,
      rc 0. Build it with `printf` from a literal, NOT via `jq` — the set is a fixed constant of
      the core engine (no `.claude-extensions.json` lookup, unlike the derived-output probes), so
      the function must not acquire a `jq` dependency it does not need and must still succeed on
      a host without `jq`. *(completed)*
- [x] In the header, record the admission bar verbatim so a future addition is held to it:
      engine-written on behalf of every/many tasks AND never legitimately declarable in any one
      task's own `file_scope`. Record the four rejected `specs/` candidates
      (`CHANGE_LOG.md`, `ROADMAP.md`, `README.md`, and any task-owned `specs/{NNN}_*/` path) with
      the one-line reason each fails the bar. *(completed)*
- [x] Add `scripts/tests/test-engine-written-state-paths-lib.sh`, using the harness conventions
      the sibling suites already use (`set -uo pipefail`, `lib/common.sh`'s
      `common_test_pass`/`common_test_fail`/`common_test_info`, PASSED/FAILED tally). Assert:
      (a) the function prints valid JSON that is an array of strings; (b) it contains exactly the
      four expected members, no more; (c) `specs/events.jsonl` and `specs/errors.json` are
      present; (d) `specs/CHANGE_LOG.md` and `specs/ROADMAP.md` are absent (a membership-creep
      tripwire, not a tautology); (e) sourcing the file twice is idempotent and emits nothing on
      stdout or stderr at source time. *(completed: 10/10 assertions passing)*
- [x] Confirm `scripts/tests/run-all.sh` picks the new suite up without a roster edit (it globs
      `scripts/tests/test-*.sh`; no explicit list to update). *(completed: confirmed via grep and
      a successful --only run)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase adds exactly TWO new files and modifies none, on the assumption
that `scripts/tests/run-all.sh` discovers suites by globbing `scripts/tests/test-*.sh` with no
hand-maintained roster to update. Confirm with
`grep -n 'tests"/test-\*\.sh\|SUITES+=' agent-system/extensions/core/scripts/tests/run-all.sh`
before closing the phase; a hand-maintained roster would add a third file to this phase.

**Tier Justification**: Both files are new and self-contained with no consumer yet wired, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-engine-written-state-paths-lib.sh`
plus `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh`
is the complete covering check for this phase's blast radius.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` - new; the single
  canonical definition plus its admission-bar header
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh` - new;
  membership, shape, and membership-creep tripwire assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-engine-written-state-paths-lib.sh`
  exits 0 with every assertion passing.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh <the two new files>` exits 0.
- `source agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh && engine_written_state_paths | jq -e 'length == 4 and (index("specs/events.jsonl") != null)'`
  succeeds.

---

### Phase 2: Migrate Site 3 (V10 in git-commit-scoped.sh) [COMPLETED]

**Goal**: V10's `containment_scope_arr` is widened from the shared library instead of a
hand-copied literal, with a source-failure fallback that cannot narrow today's scope.

**Tasks**:

- [x] Re-read `scripts/git-commit-scoped.sh` immediately before editing (sibling #461 declares
      this file). Relocate the splice by `grep -n '"specs/TODO.md" "specs/state.json"'` rather
      than trusting the line number recorded here. *(completed)*
- [x] Replace the literal `containment_scope_arr+=("specs/TODO.md" "specs/state.json")` with a
      defensive source of `lib/engine-written-state-paths-lib.sh` followed by an iteration over
      `engine_written_state_paths`'s entries, structurally mirroring the
      `derived-artifact-probe-lib.sh` block immediately below it in the same function (same
      `source "${SCRIPT_DIR}/lib/..." 2>/dev/null` guard, same `while IFS= read -r` +
      `jq -r '.[]?'` drain). *(completed)*
- [x] Implement Decision 2's fallback: when the source fails or the function yields an empty
      string, splice the hardcoded `("specs/TODO.md" "specs/state.json")` pair instead, so a
      library-resolution failure reproduces today's behavior exactly and never a narrower scope.
      *(completed)*
- [x] Update the surrounding comment: it currently says "the two fixed specs/ literals" and
      "mirrors git-commit-phase.sh's own Containment Self-Check scope exactly". Both statements
      become false — state the shared source and name the library file. *(completed)*
- [x] Add fixtures to `scripts/tests/test-git-commit-scoped.sh`, extending the Z-series from its
      current maximum (Z14) using the existing `build_repo_with_scope 999 probe '[...]'` helper:
      - **Z15 (positive)**: a tracked, dirtied `specs/events.jsonl` named directly in the
        pathspec alongside an in-scope source path, with `--task 999`, commits with rc 0, zero
        Containment drops, and `specs/events.jsonl` present in `git show --name-only HEAD`.
      - **Z16 (positive)**: the same for `specs/errors.json`.
      - **Z17 (paired negative, the non-regression guard)**: in the SAME fixture shape, a
        genuinely out-of-scope path (`specs/998_sibling/out.txt`, the helper's purpose-built
        out-of-scope candidate) alongside the admitted `specs/events.jsonl` — the commit lands,
        `specs/events.jsonl` is in `HEAD`, `specs/998_sibling/out.txt` is NOT, the drop WARN
        names it, and the exit code is the same partial-drop code Z3 already asserts.
      - **Z18 (fallback)**: with `lib/engine-written-state-paths-lib.sh` made unsourceable in the
        fixture repo (the same technique the existing issue-record.sh-unavailable case at Z10
        uses), `specs/TODO.md` is still admitted and still committed — pinning Decision 2.
      *(completed: Z15-Z18 added, 70/70 suite assertions passing; also added
      `lib/engine-written-state-paths-lib.sh` to `REQUIRED_SCRIPTS` so the shared library is
      actually present to source in every fixture repo — see progress file deviation 2.5)*
- [x] Copy the fixtures' `git` invocation shape verbatim from the existing Z-cases so
      `lint-scoped-commit-boundary.sh` and `lint-directory-pathspec-boundary.sh` stay clean.
      *(completed: both lints exit 0)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to `git-commit-scoped.sh`'s V10 scope-resolution
block with no signature or caller-contract change, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
is the dedicated covering suite for exactly that predicate (T-series plus Z1-Z18).

**Scope Hypothesis**: The hand-copied literal pair occurs exactly ONCE in
`git-commit-scoped.sh` (at `scripts/git-commit-scoped.sh:499`), and the Z-series currently ends
at Z14. Confirm both at implementation time with
`grep -n '"specs/TODO.md" "specs/state.json"' agent-system/extensions/core/scripts/git-commit-scoped.sh`
and `grep -cn '^# --- Z' agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`
before editing; a second occurrence or a higher Z number changes this phase's edit list, not its
goal.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` - V10 splice sourced from the
  shared library, with the two-literal fallback; surrounding comment corrected
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - Z15-Z18 fixtures
  (two positive, one paired negative, one fallback)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-scoped.sh`
  exits 0, with Z15-Z18 reported as passing and every pre-existing T-/Z-case still passing.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh <the two files>` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` exits 0.
- The Z17 negative assertion demonstrably fails if the admission is made blanket (sanity-check
  the fixture by temporarily widening the library to `["specs/"]` locally, confirming Z17 goes
  red, then revert that probe — the fixture must not be a tautology).

---

### Phase 3: Migrate Site 1 (WORK (h) in orchestrate-cycle-postflight.sh) [COMPLETED]

**Goal**: WORK (h)'s `effective_file_scope_json` is widened from the shared library, and the
postflight suite pins that an engine-written path is neither advised as an excursion nor dropped
by WORK (i).

**Tasks**:

- [x] Re-read `scripts/orchestrate-cycle-postflight.sh` and
      `scripts/tests/test-orchestrate-cycle-postflight.sh` immediately before editing — sibling
      #428 declares BOTH files and is live in this same cycle. Relocate the splice by
      `grep -n 'specs/TODO.md", "specs/state.json"'`. *(completed: no foreign collision observed
      at edit time — this task's own working-tree diff was the only pending change to either
      file)*
- [x] Replace the literal `jq -c '. + ["specs/TODO.md", "specs/state.json"]'` splice with a
      `--argjson` splice fed by `engine_written_state_paths`, mirroring the
      `derived_output_prefixes_json` splice immediately above it (same `spliced_*` temp-variable
      and `&& effective_file_scope_json=...` assignment discipline, so a `jq` failure leaves the
      prior value intact rather than emptying it). *(completed)*
- [x] Source the library once near the top of the script alongside the existing
      `derived-artifact-probe-lib.sh` source, not inline inside WORK (h), matching how the
      sibling library is already resolved; apply Decision 2's two-literal fallback. *(completed:
      sourced unconditionally at the top matching the sibling library's own convention; the
      call-site fallback via `engine_written_paths_json="$(engine_written_state_paths 2>/dev/null)" || engine_written_paths_json=""`
      is what actually implements Decision 2, since an unconditional top-level source itself
      cannot "fall back" on failure)*
- [x] Rewrite the WORK (h) comment block: it currently names "specs/TODO.md and specs/state.json"
      explicitly, calls itself "site 1 of two non-subsuming containment sites", and says
      "Deliberately literal, not derived". All three statements become false. Preserve the
      cross-reference to WORK (i)'s independent `stage_paths` seed, which is unchanged.
      *(completed)*
- [x] Add fixtures to `scripts/tests/test-orchestrate-cycle-postflight.sh`, extending the
      existing "excursion never changes exit code or verdict" block (which already provisions
      `completely/unrelated/excursion.sh` as its genuine-excursion fixture):
      - Provision a tracked, committed baseline `specs/events.jsonl` in the fixture repo, then
        dirty it, and add `"specs/events.jsonl"` to the same dispatch's `modified_files`.
      - Assert `specs/events.jsonl` is NOT named in any `ADVISORY` stderr line and NOT named in
        any `EXCURSION DROPPED` line.
      - Assert `specs/events.jsonl` IS present in the resulting commit's file list.
      - Assert, in the same run, that `completely/unrelated/excursion.sh` is STILL reported as an
        `ADVISORY` excursion, STILL absent from the commit, and STILL dirty on disk afterwards —
        the existing assertions must survive unchanged alongside the new ones.
      *(completed: new "Engine-written-state allowlist" block added with 8 assertions, all
      passing)*
- [x] Verify the fixture's own harness does not itself append to `specs/events.jsonl` mid-run
      (which would make the delta assertion pass for the wrong reason); if it does, assert on the
      specific committed blob rather than mere presence. *(completed: it DOES append mid-run via
      `skill_postflight_update`'s own `events-append.sh` call — confirmed empirically — so the
      committed-blob assertion accepts either an exact match or an interleaved match containing
      this dispatch's own dirtying line, and documents why in its own PASS message)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is confined to WORK (h)'s scope-splice inside
`orchestrate-cycle-postflight.sh`, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
is the dedicated covering suite for WORK (h)/(i)'s excursion behavior, including the
exit-code/verdict invariant and the WORK (i) carve-out cases.

**Scope Hypothesis**: The literal pair occurs exactly ONCE in
`orchestrate-cycle-postflight.sh` (at `scripts/orchestrate-cycle-postflight.sh:1670`, inside
WORK (h)) and the WORK (i) `stage_paths` seed is a DIFFERENT, deliberately-retained construct
that this phase must not touch. Confirm with
`grep -n 'specs/TODO.md' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
before editing — expect exactly two hits (WORK (h)'s splice, WORK (i)'s seed via
`$(dirname "$STATE_FILE")/TODO.md`), and edit only the first.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - WORK (h) splice
  sourced from the shared library with the two-literal fallback; comment block corrected;
  WORK (i)'s `stage_paths` seed deliberately untouched
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - engine-written
  path admitted-and-committed assertions, paired with the unchanged genuine-excursion assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  exits 0, with the new assertions passing and every pre-existing assertion in the excursion,
  fail-open, carve-out, and all-entries-dropped blocks still passing.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh <the two files>` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` exits 0.

**Verification notes (recorded at implementation time)**: the new "Engine-written-state
allowlist" block's 8 assertions all pass, and shellcheck/`lint-postflight-boundary.sh` both
exit 0. The suite as a whole does NOT exit 0: 25 pre-existing `[FAIL]` assertions (spread
across `acceptance`, `fixture`, `regression`, `invariant (fd-3)`, `skeleton follow-up`, and
`case-9xx` status-transition blocks, plus one assertion inside the named `carve-out` block
expecting `specs/state.json` in a commit) are present both before and after this phase's edit,
confirmed by running a byte-identical pre-edit copy (`git show HEAD:` of both files) in
isolation: identical 25 failures, identical `cleanup: command not found` trap error, 271 passed
pre-edit vs. 278 passed post-edit — the +7 delta is exactly this phase's own new assertions
(an 8th was added afterward for the `EXCURSION DROPPED` check, bringing it to 8). These 25
failures are unrelated to the engine-written-state allowlist and out of task 469's scope to
fix; recorded in the issue log (class "pre-existing test failure", severity costly) rather than
silently absorbed. The excursion, fail-open, and all-entries-dropped blocks named above have no
failing assertions; only the named `carve-out` block carries one, and it is this same
pre-existing, unrelated defect.

---

### Phase 4: Add Site 2's Net-New Splice (git-commit-phase.sh) [COMPLETED]

**Goal**: The phase-commit Containment Self-Check admits engine-written state paths it would
drop today, closing the third site.

**Tasks**:

- [x] Re-read `scripts/git-commit-phase.sh` immediately before editing (siblings #430/#446
      declare it). *(completed: no foreign collision observed)*
- [x] After `file_scope_arr` is populated from `specs/state.json` and before `is_contained()` is
      defined, append `engine_written_state_paths`'s entries to `file_scope_arr`, with the same
      defensive source guard and the same Decision 2 fallback as Sites 1 and 3. *(completed)*
- [x] Place the splice INSIDE the existing `if [ "${#file_scope_arr[@]}" -gt 0 ]` guard, so the
      fail-open posture is unchanged: a task with no declared `file_scope` still skips the check
      entirely rather than acquiring a four-member scope it never declared. *(completed, pinned
      by Case 14)*
- [x] Leave the fixed `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")` seed at
      `scripts/git-commit-phase.sh:196` untouched (Non-Goal), and add a one-line comment
      distinguishing the untested seed from the newly-spliced tested scope, so a future reader
      does not read the two as duplicates. *(completed)*
- [x] Add fixtures to `scripts/tests/test-git-commit-phase.sh`, following its existing
      Case-N convention and its existing containment fixtures (Case 7's uncontained-path drop,
      Case 8's fail-open, Case 10/11's deep-glob coverage):
      - **Positive**: a progress file whose `files_touched` names `specs/events.jsonl` (and
        `specs/errors.json`) against a declared `file_scope` containing neither — no
        `dropping out-of-scope path` warning for either, both present in the commit.
      - **Paired negative**: in the same fixture, `other/outside.txt` (Case 7's existing
        out-of-scope shape) is STILL dropped, STILL warned with the same message text, and the
        commit STILL lands minus that path.
      - **Fail-open preserved**: a task entry with no `file_scope` still skips the check entirely
        (extend or re-assert Case 8 rather than replacing it).
      *(completed: Case 13 (positive + paired negative, one fixture) and Case 14 (fail-open
      re-assertion with an engine-written-state path present) added; all 24 suite assertions
      pass. Confirmed Case 13's negative assertion is a genuine, non-tautological guard by
      temporarily widening the library to return exactly `["other/outside.txt"]` and observing
      it go red (14 of 24 failing), then restored and verified byte-identical via `diff`.)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The edit is one splice inside `git-commit-phase.sh`'s self-check with no
change to its exit-code contract or its `stage_paths` seed, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh`
is the dedicated covering suite for that self-check's containment and fail-open cases.

**Scope Hypothesis**: `git-commit-phase.sh` carries ZERO engine-written-state allowlist today
(the research finding this phase rests on) — its two fixed paths sit only in the untested
`stage_paths` seed. Confirm before editing with
`grep -n 'specs/TODO.md\|file_scope_arr+=' agent-system/extensions/core/scripts/git-commit-phase.sh`:
expect the seed line and no `file_scope_arr` splice. If a splice already exists, this phase
becomes a migration like Phase 2 rather than an addition.

**Files to modify**:

- `agent-system/extensions/core/scripts/git-commit-phase.sh` - net-new `file_scope_arr` splice
  inside the existing non-empty guard, with the shared-library source and fallback
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - positive admission
  cases, the paired genuine-excursion non-regression case, and the preserved fail-open case

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-git-commit-phase.sh`
  exits 0, with the new cases passing and Cases 1-11 still passing.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh <the two files>` exits 0.
- `grep -c 'issue-record.sh' agent-system/extensions/core/scripts/git-commit-phase.sh` is
  unchanged — the site still records its own independent `scope excursion` entry for a genuine
  excursion.

---

### Phase 5: Record the Landing in git-staging-scope.md [COMPLETED]

**Goal**: The standard describes the landed shape, so its account of the allowlist stays
truthful (Required Outcome 4).

**Tasks**:

- [x] Re-read `context/standards/git-staging-scope.md` immediately before editing (siblings
      #430/#446 declare it). *(completed: no foreign collision observed)*
- [x] Amend the **"Three Containment sites, not one."** paragraph: all three sites now consult
      ONE shared definition; Site 2, which previously tested `files_touched` against the raw
      declared `file_scope` alone, now carries the same splice. Keep the existing
      subsumption analysis (Site 3 subsumes Site 2's reach; Site 1 is not subsumed) intact — the
      shared allowlist does not change that asymmetry, and the paragraph must not imply it does.
      *(completed)*
- [x] Rewrite the **"Site 1 carries its own engine-written-state allowlist."** paragraph: the
      heading's claim is no longer accurate once the definition is shared. Reframe it around the
      canonical source, name `scripts/lib/engine-written-state-paths-lib.sh`, state the four
      members, state the admission bar, and state the source-failure fallback (Decision 2).
      Preserve the existing statement that WORK (i)'s unconditional `stage_paths` seed is an
      independent second layer the allowlist does not replace. *(completed: retitled to "The
      engine-written-state allowlist is one shared, canonical definition." since the old
      heading's "Site 1" framing was itself one of the now-false claims; the cross-reference at
      `:358` was updated to the new heading text so it does not point at a stale name)*
- [x] Add one sentence recording the Non-Goal explicitly: the allowlist admits an
      engine-written path when a caller names it and deliberately does NOT add it to any
      `stage_paths` seed, because unconditionally seeding a shared append-only store would sweep
      a concurrent sibling's rows into this task's commit. *(completed, folded into the
      rewritten paragraph's closing sentence)*
- [x] Write in the current-design voice only: no draft-history or supersession framing, and no
      task-number citations — `git-staging-scope.md` is outside `specs/**`, so
      `rules/no-task-references-in-deliverables.md` and
      `rules/no-record-versioning-in-deliverables.md` both bind. Cite the library filename and
      the paragraph headings as the durable anchors. *(completed, confirmed by
      check-task-references.sh: 0 unexempted occurrences)*

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4

**Verification Tier**: prose

**Tier Justification**: The edit is confined to two prose paragraphs in a source-store markdown
standard with no executable surface, which `suite_selection_select` resolves to
`__FULL_SWEEP__` (sub-case (b)), so the honest covering check is
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
together with the `prose` row's diff read-through.

**Scope Hypothesis**: Exactly two named paragraphs need amendment, at
`context/standards/git-staging-scope.md:342` ("Three Containment sites, not one.") and `:370`
("Site 1 carries its own engine-written-state allowlist."), plus the cross-reference at `:213`.
Confirm with `grep -n 'Three Containment sites\|engine-written' agent-system/extensions/core/context/standards/git-staging-scope.md`
before editing; a third stale paragraph found by that grep is in scope for this phase.

**Files to modify**:

- `agent-system/extensions/core/context/standards/git-staging-scope.md` - both named paragraphs
  amended to the shared-source, four-member, three-site shape; the Non-Goal recorded

**Verification**:

- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 agent-system/extensions/core`
  exits 0.
- `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/context/standards/git-staging-scope.md`
  (or the repo-wide form) reports no new findings.
- Diff read-through confirms every changed hunk is prose, that no paragraph still claims a
  per-site literal or "the two fixed specs/ literals", and that no version-history or
  task-number language was introduced.

**Verification notes (recorded at implementation time)**: `check-task-references.sh` reports 0
unexempted occurrences; diff read-through confirms both hunks are prose-only, correctly
describe the shared-library/four-member/three-site shape, and introduce no version-history or
task-number language. `verify-deploy.sh --skip-slow --only-gate 3,4` does NOT exit 0 at this
point in the sequence: gate 4 (task-reference lint) passes cleanly, but gate 3 (doc-lint) still
reports 6 pre-redeploy "deployed script content drift" FAILs for the five scripts and one
library edited in Phases 1-4, which have not yet been redeployed — this is the expected,
by-design state between Phase 4's close and Phase 6's redeploy, not a regression from this
phase's own prose edit. Two necessary infrastructure fixes were also made in the working tree
(uncommitted by this phase, deliberately — see below) so gate 3 cleanly reflects only that
expected drift rather than unrelated noise:
- `agent-system/extensions/core/manifest.json`: ran `sync-manifest-scripts.sh --write`, adding
  exactly 2 `provides.scripts` entries for Phase 1's two new files
  (`lib/engine-written-state-paths-lib.sh`, `tests/test-engine-written-state-paths-lib.sh`).
  Confirmed via `--check` beforehand that these were the ONLY 2 gaps repo-wide before writing.
- `agent-system/extensions/core/index-entries.json`: ran the deployed
  `generate-context-line-counts.sh --write` (the source-store copy refuses to run outside a
  deployed tree) twice, to correct `standards/git-staging-scope.md`'s `line_count` entry after
  this phase's own edit (first to 885, then to 884 after a follow-up line-wrap cleanup).
  **Left uncommitted by this phase's own scoped commit**: this file's working-tree diff also
  carries unrelated `line_count` corrections for OTHER extensions' content files, already dirty
  from concurrent sibling tasks' own edits before this phase touched it (the file was already
  listed modified at this session's start). Committing the whole file under task 469's own
  attribution would sweep those siblings' unrelated deltas into this task's commit — the exact
  "scope excursion" failure mode this task exists to fix, in the other direction. Both files are
  also outside this task's own declared `file_scope` (not in the per-file list; the
  `__WHOLE_TREE__` member is a batch-serialization sentinel only, never a literal path match —
  confirmed via `context/patterns/file-footprint-overlap.md`). The on-disk fixes are necessary
  and safe to leave in place (deploy-headless.sh reads the working tree directly, not git
  history, so Phase 6's redeploy and gate run see them correctly regardless of commit state);
  only the COMMIT is deferred. Recorded here so a future reader does not mistake the omission
  for an oversight, and flagged in this phase's handoff for whoever closes out the batch.

---

### Phase 6: Redeploy and Observe a Real events.jsonl Commit [NOT STARTED]

**Goal**: The fix is live in the deployed tree and verified end-to-end by an observed commit that
actually carries a `specs/events.jsonl` delta (Required Outcomes 1 and 3), behind the complete
gate set.

**Tasks**:

- [ ] Run the full source-store suite battery before deploying:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Redeploy the source store into `.claude/` using the bounded-wait idiom —
      `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool `timeout`
      parameter raised to 600000 — and confirm it reaches `RESULT=landed_verify_clean`. Never
      hand-patch a deployed file as a substitute. The deployed `.claude/` tree is stale for
      core/lean/literature at dispatch time, so this step is required before any observation that
      invokes `.claude/scripts/`.
- [ ] Confirm the deployed copies carry the change:
      `grep -n 'engine_written_state_paths' .claude/scripts/git-commit-scoped.sh .claude/scripts/orchestrate-cycle-postflight.sh .claude/scripts/git-commit-phase.sh`
      returns a hit in all three, and `.claude/scripts/lib/engine-written-state-paths-lib.sh`
      exists.
- [ ] Observe a REAL commit carrying an actual `specs/events.jsonl` delta, using this task's own
      final commit as the subject (the lifecycle has appended to `specs/events.jsonl` throughout
      this task, so the delta is genuine, not synthesized): invoke
      `bash .claude/scripts/git-commit-scoped.sh --task 469 --message ... --session ... -- <this task's own files> specs/events.jsonl`
      with `specs/events.jsonl` named explicitly in the pathspec.
- [ ] Verify by observation, not by exit code alone: `git show --stat HEAD` names
      `specs/events.jsonl`; `git show --name-only --format= HEAD | grep -x 'specs/events.jsonl'`
      succeeds; and the command's stderr contains NO `dropped 'specs/events.jsonl'` warning and
      NO new `scope excursion` entry in
      `specs/469_allowlist_infrastructure_paths_in_scoped_commits/issues.jsonl`.
- [ ] Re-read `specs/events.jsonl`'s staged delta before committing to confirm it contains only
      rows appended during this task's own dispatches; if a concurrent sibling's rows are
      interleaved (they share the file), record that in the issue log as the expected,
      known consequence of committing a shared append-only store rather than treating it as a
      defect, and state it in the handoff summary.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path
      `bash agent-system/extensions/core/scripts/verify-deploy.sh`), with every aggregated gate
      executed — not a hand-picked subset and not `--skip-slow`.

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed
  `.claude/` tree; declared per the whole-tree-claim rule so a batch admitting a sibling
  whole-tree claimant serializes against it
- `specs/469_allowlist_infrastructure_paths_in_scoped_commits/` - summary artifact, progress
  files, issue log
- `specs/events.jsonl` - committed (not authored) as this phase's own end-to-end evidence

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0 with zero `[FAIL]` tokens
  and no new entries relative to the known-failures roster.
- `timeout 540 bash .claude/scripts/deploy-headless.sh` reaches `RESULT=landed_verify_clean`.
- All three deployed Containment sites plus the deployed library are present (the `grep` above).
- `git show --name-only --format= HEAD` names `specs/events.jsonl` for the observed commit, with
  no drop warning and no new `scope excursion` issue entry.
- `bash .claude/scripts/verify-deploy.sh` — the complete aggregated gate set, every gate run —
  exits 0.

## Testing & Validation

- [ ] `specs/events.jsonl` is admitted at Site 1 (not advised as an excursion, not dropped by
      WORK (i), present in the commit).
- [ ] `specs/events.jsonl` is admitted at Site 2 (no `dropping out-of-scope path` warning,
      present in the commit).
- [ ] `specs/events.jsonl` is admitted at Site 3 (no V10 drop, no `scope excursion` issue
      record, present in the commit).
- [ ] `specs/errors.json` is admitted at Sites 2 and 3 by the same fixtures.
- [ ] A genuine out-of-scope path is STILL dropped and STILL warned at all three sites, each
      asserted in the same fixture as the corresponding admission (no blanket pass).
- [ ] A library source failure falls back to today's two-literal scope rather than an empty one
      (Site 3 fixture).
- [ ] `specs/CHANGE_LOG.md`/`specs/ROADMAP.md` are absent from the set (membership-creep
      tripwire).
- [ ] Every pre-existing assertion in all four touched suites still passes.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` exits 0.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0 after redeploy.
- [ ] One real commit carrying an observed `specs/events.jsonl` delta.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh` (new)
- Edits to `scripts/git-commit-scoped.sh`, `scripts/orchestrate-cycle-postflight.sh`,
  `scripts/git-commit-phase.sh` under the source store
- Fixture additions to `scripts/tests/test-git-commit-scoped.sh`,
  `scripts/tests/test-orchestrate-cycle-postflight.sh`,
  `scripts/tests/test-git-commit-phase.sh`
- Amended `context/standards/git-staging-scope.md`
- Regenerated `.claude/` tree (Phase 6 redeploy)
- `specs/469_allowlist_infrastructure_paths_in_scoped_commits/summaries/01_allowlist-infrastructure-paths-summary.md`

## Rollback/Contingency

Every phase is a source-store edit committed on its own, so reverting is a per-phase
`git revert` of that phase's commit followed by a redeploy to
`RESULT=landed_verify_clean`. No schema, state, or history migration is involved.

- **If a migrated site regresses** (a formerly-admitted path is dropped): Decision 2's fallback
  is the first suspect — confirm the library sources and the function returns non-empty, since
  the fallback is what makes a source failure behavior-preserving rather than scope-narrowing.
  Revert that one site's commit; the other sites are independent.
- **If Phase 6's observation shows `specs/events.jsonl` still dropped** after a clean redeploy,
  the research's "no staging-side fix needed" verdict is the thing to re-open: capture the exact
  drop message (its wording identifies which of the three sites fired) and whether the path
  reached the pathspec at all, and route that as a follow-up round rather than widening a
  `stage_paths` seed, which the Non-Goals forbid.
- **If a concurrent sibling's edit collides** in a shared file, STOP and report per
  `context/contracts/territory.md` rather than resolving the conflict unilaterally.
- **If the deploy does not reach `landed_verify_clean`**, leave `.claude/` as-is and report —
  never hand-patch the deployed tree to make the observation pass.
