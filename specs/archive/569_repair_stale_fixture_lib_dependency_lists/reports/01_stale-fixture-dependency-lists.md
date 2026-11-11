# Research Report: Task #569

**Task**: 569 - Repair stale fixture lib dependency lists
**Started**: 2026-11-10T00:00:00Z
**Completed**: 2026-11-10T00:00:00Z
**Effort**: small (3 one-line array edits + 1 copy-loop edit; no logic changes)
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/, agent-system/extensions/core/scripts/tests/), git history (`git log`/`git show`), live reproduction in an isolated scratch fixture
**Artifacts**: - specs/569_repair_stale_fixture_lib_dependency_lists/reports/01_stale-fixture-dependency-lists.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Root cause confirmed and reproduced mechanically: `state-write.sh` unconditionally sources
  `lib/project-number-inuse.sh` since commit `918c9a031`. Three fixture suites still copy a
  curated dependency list into a throwaway `.claude/scripts/lib/` that omits this library, so
  every fixture call to the copied `state-write.sh` aborts (bash `source`: "No such file or
  directory", exit 1), which the fixtures' `update-task-status.sh` caller then surfaces as its
  own generic exit 2 ("state.json update failed") — masking the real cause exactly as the
  dispatch description states.
- **Scope correction (time-sensitive finding)**: of the four suites named in the dispatch
  description, only **three** currently need the fix. `test-orchestrate-unwind-dispatch.sh`
  already carries `project-number-inuse.sh` in its `REQUIRED_LIB_SCRIPTS` array and now runs
  **21 passed, 0 failed** — it was fixed today by an unrelated, already-committed commit
  (`db0e0c054`, "orchestrate conclusion: channel (a) direct fixes", 2026-11-10 07:54:36, same
  day as this dispatch but landed before it). The description's "10 passed, 11 failed" /
  "confirmed pre-existing" figures for that suite predate `db0e0c054` and are now stale; its
  note that those 11 failures are pre-existing and unrelated to this defect class remains
  correct in spirit (that suite's remaining defect, if any, is zero today), but no fix action
  is needed there. **Recommendation**: the planner should drop this suite from the fix's
  task-dir scope entirely rather than re-verify it as part of the remedy.
- The three suites that do need the one-line fix, each independently reproduced at the counts
  the dispatch description reports:
  - `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — 17 passed, 12
    failed. Fix: add `project-number-inuse.sh` to its `REQUIRED_LIBS` array (line 65).
  - `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` — 10
    passed, 7 failed. Fix: same array, same name, line 88.
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` — 35
    passed, 2 failed. Fix: different pattern — add a `require_file "$CORE_DIR/lib/project-number-inuse.sh"`
    check (near line 45) AND add the library to the `setup_sandbox()` copy loop (near line 66),
    since this suite does not use a named array at all.
- In every one of these three, `REQUIRED_LIBS`/the explicit copy list IS the full fix: the
  array drives both the pre-flight existence check and the fixture-build copy loop, so a
  one-line addition in each repairs both check and copy together.
- On the secondary design question ("should these lists be derived from source rather than
  hand-maintained"): a source-line scan of every script copied into a curated-list fixture,
  cross-checked against each suite's own declared array, found **no drift beyond the three
  known cases** anywhere else in the corpus of suites using this pattern. This is a `##
  Recommendations` finding backed by the actual re-derivation this report's own discipline
  requires — see Recommendations below for the full method and result, which also bears on
  Risks & Mitigations.

## Context & Scope

Scope is narrowly the stale-dependency-list defect in test fixtures that copy `state-write.sh`
(or its collaborator `task-lock.sh`) into an isolated temp root using a hand-maintained
lib/script allow-list, specifically the drift introduced when `state-write.sh` gained an
unconditional `source "${SCRIPT_DIR}/lib/project-number-inuse.sh"` at line 214 (commit
`918c9a031`, 2026-11-03). Out of scope per the dispatch description, confirmed correct: the
audit-evidence gate inside `state-write.sh` (commit `b5b730454`, same day) — that gate only
fires on new `active_projects` entries, and every affected fixture pre-seeds `active_projects`
and only transitions `status`, so it is never reached.

Both the deployed copy (`.claude/scripts/`) and the source-store copy
(`agent-system/extensions/core/scripts/`) carry the identical bug per
`source-store-deploy-boundary.md`; all investigation and the eventual fix belong in the source
store (`agent-system/extensions/core/scripts/`), never in the gitignored deploy tree.

## Findings

### Codebase Patterns

**The defect, reproduced independently.** A minimal, non-destructive reproduction (a throwaway
fixture under this session's scratchpad, never touching any tracked file) confirms the exact
failure signature:

```
.claude/scripts/state-write.sh: line 214: <fixture>/.claude/scripts/lib/project-number-inuse.sh: No such file or directory
```

`state-write.sh` exits 1 on this (bash's own `set -euo pipefail` reacting to the failed
`source` builtin). `update-task-status.sh`'s own header documents `exit 2 - state.json update
failed` as its generic wrapper code for any failed `state-write.sh` invocation (grep
`update-task-status.sh:26` plus the call sites at lines ~1066-1103), which is exactly what the
three affected suites observe: every `[FAIL]` line in their output reports `got 2`.

**Why only these three, structurally.** The codebase uses two patterns for populating a
fixture's `.claude/scripts/lib/`:

1. **Whole-directory glob copy** — `cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/"`
   or `cp "$LIB_DIR"/*.sh "$scratch/.claude/scripts/lib/"`. Structurally immune to this defect
   class: a new `source` line in a copied script is automatically satisfied. Confirmed present
   in `test-update-task-status.sh` and `test-orchestrate-suggest-next-batch.sh` — neither needed
   any change when `project-number-inuse.sh` was introduced, and neither is in the affected list.
2. **Curated allow-list** (`REQUIRED_LIBS=(...)` / `REQUIRED_LIB_SCRIPTS=(...)` /
   `REQUIRED_SCRIPTS=(...)`, or a sequence of bare `require_file` calls) — the array is both the
   pre-flight "does this exist" check and the literal copy-loop driver. Anything that copies
   `state-write.sh` this way must also carry `project-number-inuse.sh` in the same array/list,
   by hand, forever. This is the vulnerable pattern, and it is exactly where the three live
   failures sit.

**Commit `918c9a031`'s own fix was already partial, by its own account.** Its commit message
says verbatim: "Extends the lib allow-list in the five suites that copy state-write.sh into a
throwaway temp root" — and the diff shows exactly five: `test-state-write-concurrency.sh`,
`test-state-write-large-payload.sh`, `test-state-write-regen-timing.sh`,
`test-state-write-spill-names.sh`, and `test-orchestrate-cycle-plan.sh` (Group 21). All five
verified still fixed (re-grepped; all five list `project-number-inuse.sh` in their copy set).
That commit's own audit of "the suites that copy state-write.sh" evidently did not enumerate
`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`, or
`test-orchestrate-predispatch-review.sh` — this is the actual mechanism of the defect
("hand-maintained list, incomplete audit at the time of the upstream change"), not a second,
independent cause.

**`test-orchestrate-unwind-dispatch.sh` was already repaired, separately and this same day.**
Its `REQUIRED_LIB_SCRIPTS` array already contains `project-number-inuse.sh`
(`git log -p --follow` on the file shows exactly one commit ever touching that line:
`db0e0c054`, "orchestrate conclusion: channel (a) direct fixes", committed 2026-11-10
07:54:36 -0800 — before this dispatch's own `dispatch_start_ts`). Re-running the suite today
gives **21 passed, 0 failed**, not the dispatch description's "10 passed, 11 failed." The
description's own caveat ("Confirmed pre-existing: ... fails identically at commit
`3b7f13344`") is consistent with this: those 11 (now-historical) failures were never this
defect's doing in the first place, and the unrelated commit that happened to also add the
missing array entry has since fully resolved the suite. No action is needed on this file for
task 569.

**The exact one-line/two-line fixes, verified by direct inspection of each file:**

- `test-postflight-deploy-gate.sh:65` —
  `REQUIRED_LIBS=(common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh task-lookup-lib.sh)`
  — append `project-number-inuse.sh`. The existence check (`for req in "${REQUIRED_LIBS[@]}"`,
  line 66) and the fixture copy loop (`for f in "${REQUIRED_LIBS[@]}"`, line 93, inside
  `build_fixture_repo()`) both iterate this same array, so one edit repairs both.
- `test-redeploy-checkpoint-promotion.sh:88` — identical array, identical fix, identical
  single-array double-duty (check at line 89, copy loop at line 121 inside
  `build_fixture_repo()`).
- `test-orchestrate-predispatch-review.sh` — this suite uses no named array; it lists
  individual `require_file "$CORE_DIR/..."` calls (lines 38-49) and a hard-coded `for f in
  orchestrate-predispatch-review.sh deploy-root-guard.sh state-write.sh task-lock.sh; do cp
  ...` loop inside `setup_sandbox()` (lines 61-67). The fix needs **two** edits here, not one:
  add a `require_file "$CORE_DIR/lib/project-number-inuse.sh"` line (mirroring the existing
  `file-scope-overlap.sh`/`task-lock.sh` precedent comments at lines 43-49, which already
  explain why each addition became necessary — the same explanatory convention should be kept)
  and add `cp "$CORE_DIR/lib/project-number-inuse.sh" "$WORKDIR/.claude/scripts/lib/project-number-inuse.sh"`
  inside `setup_sandbox()`.

**`task-lock.sh`'s own transitive lib dependencies are already correctly covered everywhere.**
`task-lock.sh` itself sources `lib/task-lookup-lib.sh` and `lib/file-scope-overlap.sh`; all
three affected suites (and the already-fixed fourth) already carry both in their
arrays/require-lists — this is not a second gap riding along with the `project-number-inuse.sh`
one.

### External Resources

Not applicable — this is a pure in-repo shell-fixture defect with no external library or API
surface.

## Recommendations

1. **Primary fix** (matches dispatch description's own stated primary fix): add
   `project-number-inuse.sh` to the three locations above. No other code or behavior changes
   are needed; each suite's existing `set -uo pipefail` / exit-2-on-missing-file-at-startup
   contract already does the right thing once the array is complete — these suites fail LOUD
   today specifically because the *array* is short, not because the fail-loud mechanism itself
   is broken.
2. **Scope the plan to three suites, not four.** Do not include
   `test-orchestrate-unwind-dispatch.sh` in the implementation plan's file list; it is already
   green. (A plan author who re-runs the full suite before planning will see this directly —
   flagging it here saves that redundant discovery and avoids a wasted "fix" commit touching an
   already-correct line.)
3. **On "should these lists be derived from the subject script's own source lines rather than
   hand-maintained" — re-derivation performed, not deferred.** This recommendation proposes
   changing a mechanical rule (how a fixture's dependency list is produced) applied across a
   corpus (every suite using the curated-array pattern), and its own soundness turns on how that
   corpus actually responds — the exact trigger for this report's carried-figure-discipline
   obligation. The check was run: for every script copied by a curated-list suite
   (`state-write.sh`, `update-task-status.sh`, `task-lock.sh`, `deploy-root-guard.sh`,
   `generate-todo.sh`, `generate-task-order.sh`, `update-plan-status.sh`,
   `update-phase-status.sh`, `validate-state.sh`, `orchestrate-predispatch-review.sh`,
   `reconcile-task-status.sh`, `lib/redeploy-checkpoint-lib.sh`), each script's own
   `source "${SCRIPT_DIR}/lib/X.sh"` lines were extracted and cross-checked against the
   declared array of every suite that copies it. **Result: zero additional drift beyond the
   three known suites.** Given that result, a full runtime change (actually deriving the copy
   list from source lines at fixture-build time, replacing the arrays outright) is higher risk
   than benefit right now — it would touch 8+ working suites to fix a defect that, empirically,
   is not currently recurring elsewhere. The lower-risk, right-sized version is a **lint-time
   drift detector**, not a runtime behavior change: a small standalone check (e.g.
   `lint-test-fixture-dependency-drift.sh`, following the existing `lint-*.sh` convention in
   this scripts directory) that, for each suite file using the `REQUIRED_LIBS`/
   `REQUIRED_LIB_SCRIPTS`/`REQUIRED_SCRIPTS`/`require_file` pattern, greps the *real* subject
   script(s) it copies for their own `source "${SCRIPT_DIR}/lib/...sh"` lines and asserts each
   named library appears in the suite's own declared list — catching the next `918c9a031`-style
   upstream change before it silently breaks a fixture again, without changing any suite's
   actual copy behavior. This is a candidate follow-up task, not part of this repair's minimal
   fix.
4. **Keep the fix minimal and surgical.** Given finding 3's clean result, the plan for task 569
   itself should stay to the one-/two-line array edits in the three suites — no broader
   refactor of the dependency-declaration pattern is warranted as part of this repair.

## Decisions

- Scope is the three suites confirmed still failing on this exact defect today
  (`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`,
  `test-orchestrate-predispatch-review.sh`), not the four named in the dispatch description.
  `test-orchestrate-unwind-dispatch.sh` is excluded because it is independently, already fixed
  (commit `db0e0c054`) and currently passes 21/21.
- The audit-evidence gate (`b5b730454`) is confirmed, by direct reading of `state-write.sh`'s
  gate condition and every affected fixture's pre-seeded `active_projects` + status-only
  transition shape, to be unreachable in these fixtures and is excluded from the fix.
- The "derive from source" design question is answered as: not now, as a runtime change (no
  drift found to justify the risk); yes, as a candidate lint-time drift detector follow-up task
  (not implemented here).

## Risks & Mitigations

- **Risk**: a future upstream change to `state-write.sh` (or any other script copied by a
  curated-list fixture) adds another `source` line and this defect class recurs. **Mitigation**:
  Recommendation 3's lint-time drift detector as a follow-up task; until then, any future PR
  touching `state-write.sh`'s `source` lines should grep
  `agent-system/extensions/core/scripts/tests/*.sh` for `state-write.sh` copy sites and update
  their arrays in the same commit (the discipline commit `918c9a031` itself intended but did not
  fully execute).
- **Risk**: re-verifying `test-orchestrate-unwind-dispatch.sh` as part of this task's
  implementation wastes a cycle re-discovering it is already green, or worse, an implementer
  "fixes" an already-correct line defensively. **Mitigation**: this report states the finding
  plainly above; the plan should simply omit the file.
- **Risk** (territory): task 589 (concurrent sibling, phase=plan) has file_scope naming five
  *different* test files in this same `tests/` directory (`test-deploy-baseline-lib.sh`,
  `test-gate-cache-lib.sh`, `test-gate-registry-resolution.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-build-aux-dispatch.sh`) — no overlap with the three files this task's fix
  touches, confirmed by direct comparison. Task 500 (concurrent sibling, phase=research)
  file_scopes `update-task-status.sh` and its own test suite — also no overlap with this task's
  three files. No territory collision identified; the implementer should still re-read each
  target file immediately before editing per the standing concurrency note.

## Context Extension Recommendations

- none

## Appendix

### Search queries / commands used

- `find . -name "state-write.sh"`, `find . -name "test-postflight-deploy-gate.sh" -o ...` (locate subjects)
- `grep -n "REQUIRED_LIBS\|project-number-inuse\|state-write.sh" <each of the four named suites>`
- `git log -1 --format=... 918c9a031 / 3b7f13344 / b5b730454` (verify referenced commits exist and their intent)
- `git show --stat 918c9a031` / `git show 918c9a031 -- 'tests/*'` (what that commit actually fixed)
- `git log -p --follow -- test-orchestrate-unwind-dispatch.sh | grep project-number-inuse` (when/whether this suite's array was ever updated)
- `git show -s --format="%H %ci %s" db0e0c054` (date the unwind-dispatch suite was actually fixed, and by what)
- Non-destructive scratch reproduction: built a minimal `.claude/scripts/{state-write.sh,task-lock.sh,deploy-root-guard.sh,lib/common.sh}` fixture under this session's scratchpad (never under the repo) and invoked the copied `state-write.sh` directly to capture the exact `source`-failure message and real exit code (1).
- Ran all four named suites directly (`bash test-postflight-deploy-gate.sh`, etc.) to independently reproduce the reported pass/fail counts.
- `grep -rln "REQUIRED_LIBS\|REQUIRED_LIB_SCRIPTS\|REQUIRED_SCRIPTS\|REQUIRED_CORE_SCRIPTS" tests/*.sh` and a source-line extraction pass over every script copied by those suites, to discharge the enumeration/carried-figure obligation for the "derive from source" recommendation.

### References

- `agent-system/extensions/core/scripts/state-write.sh:214` (the new unconditional `source`)
- `agent-system/extensions/core/scripts/update-task-status.sh:26` (exit 2 contract)
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh:57-96`
- `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh:80-124`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh:36-67`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh:38-43` (already fixed)
- `agent-system/extensions/core/scripts/test-state-write-{concurrency,regen-timing,spill-names,large-payload}.sh` (fixed by `918c9a031`)
- Commits: `918c9a031`, `b5b730454`, `3b7f13344`, `db0e0c054`
