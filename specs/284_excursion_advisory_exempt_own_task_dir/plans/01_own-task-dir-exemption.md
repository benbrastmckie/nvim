# Implementation Plan: Task #284

- **Task**: 284 - Exempt a task's own directory from the postflight file_scope excursion advisory, so the aggregator signal it was built for is visible
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/284_excursion_advisory_exempt_own_task_dir/reports/01_excursion-advisory-own-task-dir-exemption.md
- **Artifacts**: plans/01_own-task-dir-exemption.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add the dispatching task's own resolved task directory as an implicit, unconditional member of
`file_scope` for the duration of WORK (h)'s excursion comparison in
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, so the advisory stops
firing on the artifacts the lifecycle requires every task to write and starts carrying the
aggregator-edit signal it was built for. The matching predicate itself is not changed: the fix
appends one repo-relative, trailing-slash directory entry to the `$fs` array the existing
`$p == $f or ($p | startswith($f))` comprehension already consumes. Two non-code deliverables ride
along: the enforcement-level ruling (stay advisory, with a written promotion criterion) recorded in
the script header, and the repair of the dangling cross-reference in the archived task-270
description.

### Research Integration

Key findings carried from the research report, each re-derived live at plan-authoring time:

- **Site re-grepped, not trusted.** The check lives at
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1419-1436` (header
  summary line at `:50`), not the task description's stale `1121-1132`. Verified by
  `grep -n "excursion"` at plan time. Line numbers are still not a stable anchor — Phase 1
  re-greps rather than seeking a line number.
- **`$TASK_DIR` is already the correct, archive-aware anchor.** It is produced upstream by
  `task_lookup_dir()` (`scripts/lib/task-lookup-lib.sh`), which returns
  `specs/archive/{NNN}_{name}` when the active directory is absent, and is normalized to absolute
  form inside the script (lines 337-340, `TASK_DIR="$PROJECT_ROOT/$task_dir_arg"`). No new
  active-vs-archive branching is needed anywhere in this change.
- **Both sides of the comparison are contractually repo-relative** (`return-metadata-file.md`'s
  path-form note), so `$TASK_DIR` must be stripped to repo-relative form via the `$PROJECT_ROOT`
  the script already sets at line 198.
- **Whole-directory exemption, not an artifact-subdirectory allowlist** — justified by parity with
  `git-staging-scope.md`, which already stages the entire task directory minus five named
  ephemeral paths for every commit regardless of `file_scope`.
- **The script is `set -uo pipefail`** (line 181), not `set -e`, so a jq failure inside this block
  degrades rather than aborting postflight — but Phase 1 still preserves the existing
  `2>/dev/null || fallback` guard posture on every added command.
- **The existing fixture already proves the trailing-slash directory-prefix mechanics**
  (`test-orchestrate-cycle-postflight.sh`, task `707_candidate`, `file_scope: ["specs/707_candidate/"]`),
  so this is a data-set change, not a predicate rewrite.
- **An unrelated, live predicate-unreliability source exists**: `specs/299_.../.return-meta.json`
  holds *absolute* paths in `modified_files`, violating the schema, and `validate-return-meta.sh`
  does not check that field's path form at all. This is deliberately NOT fixed here; it is the
  evidence for staying advisory and the first half of the recorded promotion criterion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided for this dispatch (no `roadmap_path` in the delegation context).

## Goals & Non-Goals

**Goals**:
- A task's own resolved task directory is an implicit `file_scope` member for WORK (h) only, so
  required artifacts never produce an excursion advisory.
- The exemption resolves from the task directory the dispatch actually used, covering a forced
  round against an archived task under `specs/archive/`.
- A genuine undeclared edit outside the task's own tree still produces exactly one advisory naming
  that file, demonstrated by a passing regression test rather than argued.
- The whole-directory ruling, the enforcement-level ruling (stay advisory), and the promotion
  criterion all live in the script header alongside the existing WORK (h) documentation.
- The dangling "recorded separately" cross-reference in the archived task-270 description is
  restated so it no longer points at an abandoned record as if it were live.

**Non-Goals**:
- Any null/type-safety change inside the WORK (h) block — that defect class belongs to the
  separate jq-null-safety audit record, which explicitly declines to bundle, and this task honours
  the boundary in the other direction.
- Promoting the advisory to a blocking gate (explicitly forbidden in this change).
- Fixing the `modified_files` absolute-path violation or adding a `validate-return-meta.sh`
  path-form check (named as a future trigger point, not done here).
- Widening the `length > 0` guard so the check also runs for an empty declared `file_scope`
  (absent-`file_scope` posture is ruled on elsewhere; widening the trigger is scope creep).
- Refactoring the inline `startswith` predicate onto `scripts/lib/file-scope-overlap.sh`.
- Any hand-edit under `.claude/**` — the source store `agent-system/extensions/core/**` is the
  edit target per `rules/source-store-deploy-boundary.md`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `${TASK_DIR#"$PROJECT_ROOT"/}` leaves the string unchanged (symlinked or divergent absolute `--task-dir`), silently adding a useless absolute entry | M | L | Compare stripped result against the original; on no change, emit a WARN to stderr and skip the implicit member entirely — never abort. Matches the block's existing "detection only, never fatal" posture |
| A trailing-slash-less entry string-prefix-collides across task directories | L | L | Append the entry with an explicit trailing `/`, matching the existing fixture's own convention |
| Over-broad exemption hides a genuine edit made beneath the task's own tree | L | L | Recorded as an accepted consequence of the whole-directory ruling, with the git-staging-parity justification written into the script header so a future reader does not re-litigate it |
| An absolute-path `modified_files` entry still produces a false advisory after this fix | M | M | Out of scope by design; recorded as the first half of the promotion criterion, which is why the channel stays advisory |
| Editing the same file a sibling task may also touch this cycle | M | L | Per the dispatch territory block: re-read the file immediately before each edit, stage only this task's own hunks by explicit path, never a directory or glob `git add` |
| Source-store edit not reflected in the deployed tree, so a later deploy-freshness gate fails | L | M | Phase 5 runs the full gate set and, only if it reports deploy staleness, runs the repo's sanctioned deploy entry point (`deploy-headless.sh`, flags confirmed from its own usage header) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 4 | -- |
| 2 | 2, 3 | 1 |
| 3 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Implicit own-task-directory `file_scope` member [COMPLETED]

**Goal**: WORK (h)'s comparison treats the dispatching task's own resolved task directory as an
unconditional in-scope prefix, without changing the matching predicate.

**Tasks**:
- [x] Re-locate the block by content, not line number: `grep -n "WORK (h)" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, then read the whole block plus its existing comment through to the `fi`. *(completed)*
- [x] Immediately after the existing `file_scope_json` read, derive the repo-relative task directory: `task_dir_rel="${TASK_DIR#"$PROJECT_ROOT"/}"`. *(completed)*
- [x] Add the defensive fallback: if `task_dir_rel` is identical to `$TASK_DIR` (prefix strip did nothing) or empty, emit one `${notice_prefix} WARNING: ...` line to stderr naming the unexpected `--task-dir` form and skip the implicit member; never `exit`, never change `verdict`. *(completed)*
- [x] Otherwise splice `"${task_dir_rel}/"` (explicit trailing slash) into the array the jq comprehension consumes, e.g. `file_scope_json=$(echo "$file_scope_json" | jq -c --arg d "${task_dir_rel}/" '. + [$d]' 2>/dev/null) || true` — keeping the existing `2>/dev/null || fallback` posture so a jq failure leaves the prior value intact. *(deviation: altered — the splice is applied to a local `effective_file_scope_json` used only by the jq comprehension, inside the existing `length > 0` guard, rather than mutating `file_scope_json` itself unconditionally right after the read; mutating it unconditionally before the guard would widen the guard's own trigger condition to fire even for tasks with no declared `file_scope`, contradicting this plan's explicit Non-Goal — see progress file for full reasoning)*
- [x] Leave the `length > 0` guard, the `any($fs[]; . as $f | ...)` re-binding comment, the advisory wording, and the "detection only — no gate, no exit-code, no verdict effect" suffix exactly as they are. *(completed)*
- [x] Add a short inline comment at the splice site stating WHY the implicit member exists (the lifecycle requires every task to write into its own directory) and that it is resolved from `$TASK_DIR`, which is already archive-aware. *(completed)*
- [x] Re-read the file immediately before the edit (sibling-task concurrency), then stage only this file by explicit path. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the change is confined to the WORK (h) block of one file and adds roughly 6-10 lines (hypothesis; the block's own current span, re-derived at plan time as lines 1419-1436, is the carried figure from the research report's site finding). Confirm at implementation time by re-grepping `WORK (h)` and checking `git diff --stat` shows exactly one file and a line delta in that range — if the diff touches any other block or file, stop and reconcile before committing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the repo-relative `$TASK_DIR` derivation, the defensive-skip fallback, the array splice, and one explanatory inline comment inside the WORK (h) block

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` exits 0 (syntax).
- `command -v shellcheck >/dev/null && shellcheck -x agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh; echo "exit=$?"` — exit status 0 is required, not merely an unchanged-looking output diff. If the binary is genuinely unavailable, record that as an explicit skip in the phase notes (never report it as a pass) and rely on Phase 5's gate set.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` still ends with zero FAILED; the pre-existing `707_candidate` excursion invariant (exit 0, `verdict=ok`, advisory logged for `completely/unrelated/excursion.sh`) still passes unchanged.

---

### Phase 2: Record both rulings in the script header [COMPLETED]

**Goal**: The whole-directory ruling and the enforcement-level ruling — including the promotion
criterion — are written where the dispatch requires them: in the script header, alongside the
existing WORK (h) documentation.

**Tasks**:
- [x] Extend the header's WORK (h) line (currently the one-line summary near line 50) with the implicit own-task-directory member, stated as behavior, not as intent. *(completed)*
- [x] Record the scope ruling: the exemption covers the WHOLE resolved task directory, not an enumerated `reports/`/`plans/`/`summaries/`/`.dispatch/`/dotfile allowlist; justification in one sentence — parity with the commit pipeline, which already stages the entire task directory regardless of declared scope, so the advisory should not be stricter than the thing it advises about. *(completed)*
- [x] Record the enforcement-level ruling explicitly: the channel STAYS advisory in this change; this is a decision, not a deferral. *(completed)*
- [x] Record the two-part promotion criterion verbatim enough to be actionable: promote to a blocking gate only once (a) this exemption has run over the current active task population for a bake-in period with zero recorded false-positive advisories — coverage re-derived live at plan time as 45 of 47 active non-abandoned tasks (~96%) already carrying a non-empty `file_scope` — AND (b) a `validate-return-meta.sh` check (or equivalent) enforces that every `modified_files` entry is repo-relative, closing the known absolute-path counter-example. Until both hold, a gate would sit on a predicate that can misfire for reasons unrelated to the aggregator signal it exists to catch. *(completed)*
- [x] Note in one sentence that the known absolute-path `modified_files` violation is deliberately out of scope here and is the named trigger point for the promotion review. *(completed)*
- [x] Use durable anchors only: no task numbers in this header text (the file is outside `specs/**`); refer to the records by their subject, not by number. *(completed: verified via check-task-references.sh, 0 occurrences)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - header WORK (h) documentation block only (comment lines; no executable change)

**Verification**:
- `git diff` for this phase shows only `#`-prefixed comment lines changed — every hunk lies inside the header comment region, no executable line touched.
- `bash -n` on the script still exits 0.
- `grep -nE "^#.*(advisory|promotion)" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` shows the stay-advisory ruling and both promotion-criterion halves present.
- `bash .claude/scripts/check-task-references.sh` reports no new findings for this file (no task numbers in a deliverable outside `specs/**`); exit status checked, not just output.

---

### Phase 3: Regression tests for the exemption and the surviving signal [COMPLETED]

**Goal**: The defect cannot silently return, and the aggregator case the advisory exists for is
demonstrated by a concrete passing test rather than asserted in prose.

**Tasks**:
- [x] Read the existing excursion-invariant fixture in `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (the `707_candidate` block) and reuse its `setup_sandbox` / `write_state` / `commit_fixture` / `run_sut` idiom verbatim; follow the suite's `pass`/`fail`/`info` helper convention and its `set -uo pipefail` Class B posture. *(completed)*
- [x] Add case (a) — the regression test for this defect: a fixture whose declared `file_scope` does NOT include its own task directory (e.g. a scope naming only some unrelated source path) and whose `modified_files` contains ONLY in-directory artifact paths. Assert ZERO `ADVISORY` excursion lines in stderr, and assert exit 0 with `verdict=ok`. *(completed: candidate #715)*
- [x] Add case (b) — the surviving aggregator signal: the same fixture plus one genuinely undeclared path outside both the declared scope and the task's own tree. Assert EXACTLY ONE advisory line and that it names that path; assert exit 0 and `verdict=ok` unchanged. *(completed: candidate #716)*
- [x] Add case (c) — archive resolution: a fixture whose task directory lives under `specs/archive/{NNN}_{name}/` with the active path absent, dispatched with that `--task-dir`. Assert the in-archive-directory artifact produces NO advisory, proving the implicit member resolved from the directory the dispatch actually used. *(completed: candidate #717)*
- [x] Leave the existing `707_candidate` case untouched; it remains the no-change invariant. *(completed: verified unchanged, still passes)*
- [x] Confirm the suite needs no registration step: `run-all.sh` auto-discovers `scripts/tests/test-*.sh`, and this file is already discovered — verify by running the runner and seeing this suite named in its output, rather than assuming it. *(completed: run-all.sh's own transcript shows `[RUN] .../test-orchestrate-cycle-postflight.sh` / `[PASS] .../test-orchestrate-cycle-postflight.sh`)*

**Timing**: 1.0 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: three new test cases are expected to suffice for the stated acceptance (zero advisories for own-directory writes; exactly one for a genuine excursion; archive-path resolution). Confirm at implementation time by running the suite and checking each new case appears as its own named PASS line, and that the total PASSED count rose by exactly the number of assertions added — if a case silently never ran (a sandbox or fixture path error), the count will not move as predicted.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add three excursion fixtures (own-directory-only, genuine excursion, archived task directory) beside the existing invariant block

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` ends with zero FAILED and each new case visible as a named PASS line.
- Negative control: temporarily revert the Phase 1 splice (in the working tree only, uncommitted), re-run the suite, and confirm case (a) FAILS — then restore. This proves the test actually exercises the fix instead of passing vacuously.
- `command -v shellcheck >/dev/null && shellcheck -x agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh; echo "exit=$?"` — exit status 0 required; an unavailable binary is recorded as a skip, never a pass.

---

### Phase 4: Restate the dangling cross-reference in the archived task record [COMPLETED]

**Goal**: The archived jq-null-safety-audit record no longer tells a reader that this advisory's
advisory-vs-blocking question "was recorded separately" when that separate record is itself
abandoned.

**Tasks**:
- [x] Locate the entry: `jq -r '(.completed_projects // [])[] | select(.project_number==270) | .description' specs/archive/state.json` and find the "RELATED, DELIBERATELY NOT MERGED" paragraph. *(completed)*
- [x] Replace the trailing `"and it was recorded separately"` clause with a restatement of the actual status: the separate record it pointed to is abandoned; the advisory-vs-blocking question was answered by the own-task-directory exemption change, which kept the channel advisory and recorded the promotion criterion in `scripts/orchestrate-cycle-postflight.sh`'s own header. Task numbers are permitted here (`specs/**` is an explicit exception), so name this task number alongside the durable anchor. *(completed)*
- [x] Leave the rest of that description byte-identical, including its boundary note that touching the same file is not a reason to bundle — that note still holds for the script itself. *(completed: verified via git diff --stat showing 1 line changed)*
- [x] Edit via `jq` with an explicit `--arg`-based string replacement written to a temp file and moved into place (never an in-place rewrite of the whole array, never a wholesale `.completed_projects = [...]` assignment), then validate with `jq empty specs/archive/state.json`. *(deviation: altered — used `python3 -I` json-load/replace/dump-to-temp-then-move instead of a jq `--arg`/`sub()` pipeline, to avoid any regex-metacharacter risk in `sub()` against free-form prose; same temp-file-and-move safety property, validated identically with `jq empty`)*
- [x] Re-read the file immediately before the edit; `specs/archive/state.json` is shared state and a sibling task may touch it this cycle. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `specs/archive/state.json` - restate the one dangling clause inside the archived entry's `description` string

**Verification**:
- `jq empty specs/archive/state.json` exits 0 (valid JSON preserved).
- `jq '(.completed_projects // []) | length' specs/archive/state.json` is unchanged from its pre-edit value (no entry added or dropped).
- `jq -r '(.completed_projects // [])[] | select(.project_number==270) | .description' specs/archive/state.json | grep -c "recorded separately"` returns 0, and the same description still contains its "Touching the same file is not a reason to bundle" sentence.
- `git diff --stat specs/archive/state.json` shows only this one file changed.

---

### Phase 5: Full gate set, deploy reconcile, and acceptance demonstration [COMPLETED WITH EXCLUSIONS]

**Goal**: The repository's complete gate set passes with the change in place, the deployed tree is
not left stale, and the acceptance criteria are demonstrated by recorded command output rather
than asserted.

**Tasks**:
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh`. Check its exit status explicitly; do not read only its summary text. *(completed: first run reported deploy staleness; see below)*
- [x] If and only if it reports deploy staleness for the edited source-store files, run the repo's sanctioned deploy entry point (`deploy-headless.sh`; confirm its path and flags from its own usage header rather than guessing) and re-run `verify-deploy.sh` to green. *(completed: `deploy-headless.sh` (default, non-destructive resync mode) ran clean, `RESULT=landed_verify_clean`; doc-lint and Gate 5 manifest-hash parity both went from FAIL to PASS for this task's two edited scripts)*
- [x] Record the acceptance demonstration in the phase notes / summary: the exact test output lines showing (i) zero advisories for a task writing only inside its own directory, and (ii) exactly one advisory naming the genuinely undeclared out-of-tree path. *(completed — see below)*
- [x] Confirm the enforcement-level ruling and its reasoning are present in the script header (`grep` the stay-advisory sentence and both promotion-criterion halves) — this is an explicit acceptance item, not an inferred one. *(completed: `grep -nE "^#.*(advisory|promotion)"` shows the stay-advisory ruling at line 64 and both promotion-criterion halves)*
- [x] Stage and commit only this task's own files by explicit path (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`, `specs/archive/state.json`, plus this task's own `specs/284_.../` artifacts), via `.claude/scripts/git-commit-scoped.sh` — never `git add -A`, never a directory or glob pathspec, never `git commit -am`. *(completed)*
- [x] If a sibling task's foreign commit or uncommitted modification is observed in these files, STOP and report it after checking `git log` to confirm the work is not this task's own. *(completed: observed and confirmed via `git log`/`git diff` — see Reasoned Exclusions below; none of it is inside this task's own three declared files, so no stop was warranted, only this evidenced record)*

**Timing**: 0.25 hours

**Depends on**: 1, 2, 3, 4

**Verification Tier**: full

**Files to modify**:
- none planned (verification, deploy reconcile, and commit only)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate reported passing, including Gate 8's shell-suite run. *(see Reasoned Exclusions — not met for 2 of 35 checks, both evidenced as outside this task's file_scope)*
- `git status --short` and `git diff --staged` reviewed before the commit; nothing outside this task's declared files is staged, and no credential/env file appears. *(completed)*
- The committed tree reproduces both acceptance demonstrations when the postflight suite is re-run from a clean checkout of the commit. *(completed: standalone suite run after the Phase 1-4 commits lands 192 passed, 0 failed)*

#### Acceptance Demonstration

`bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` output:
```
[PASS] case (a): exit 0 and verdict=ok for an own-directory-only write (file_scope does not declare the task's own directory)
[PASS] case (a): zero ADVISORY lines for a write confined to the task's own directory
[PASS] case (b): exit 0 and verdict=ok unchanged despite a genuine excursion (detection only)
[PASS] case (b): exactly one ADVISORY line emitted
[PASS] case (b): the advisory names the genuinely undeclared path (completely/unrelated/excursion.sh)
[PASS] case (b): the own-directory summary file is not named in the advisory (the exemption still applies alongside the genuine excursion)
[PASS] case (c): exit 0 and verdict=ok for an archived task directory's own-directory write
[PASS] case (c): zero ADVISORY lines -- the implicit member resolved from the ARCHIVED --task-dir actually used, not an assumed active path
Results: 192 passed, 0 failed
```
This demonstrates both ACCEPTANCE conditions concretely: (i) zero advisories for every file
inside the task's own directory (cases a, c), and (ii) exactly one advisory naming the
genuinely undeclared out-of-tree path, with the own-directory exemption still applying
alongside it (case b).

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 13 (whole-tree orphan detection): `.claude/tmp/noop-bash-shapes-<session>` flagged as an undeclared file | Session-state artifact of the `detect-noop-bash.sh` PreToolUse hook, which fires on every Bash tool call across the whole session (including this dispatch's own calls) regardless of which task is running. Its new state-file naming pattern has not yet been registered in `context/patterns/deploy-orphan-detection.md`'s exclusion classes. This is squarely the owning hook's own registration gap, not a file this task wrote, edited, or declared in its `file_scope`. | `git log --oneline -3 -- agent-system/extensions/core/hooks/detect-noop-bash.sh` shows the hook's own recent authorship as `task 345 phase 3: detect-noop-bash.sh streak accounting that survives alternation`; `ls -la .claude/tmp/` shows `noop-bash-shapes-f86dc99f-a17e-45ef-b893-15c1453e8aa8` — the literal UUID of this dispatch's own scratchpad session, confirming it was generated incidentally by the hook observing this dispatch's own Bash calls, not authored or declared by this task. |
| Gate 8 (shell test suite runner, `run-all.sh`): 4 suites reported `[SKIP] not executable (exec-bit regression?)` | `test-dispatch-metrics.sh`, `test-lint-agent-contracts-heartbeat.sh`, `test-script-inventory.sh`, `test-task-lock-liveness.sh` are committed to git as mode `100644` (non-executable), a pre-existing repository condition unrelated to this task, this session, or either concurrent sibling. | `git ls-files -s` on each file shows mode `100644`; `git log --oneline -1` on `test-dispatch-metrics.sh` shows `task 330 phase 5: test suite for dispatch-metrics.sh`, committed 2026-10-03 — days before this task's session began and attributable to an unrelated, already-closed task. |
| Gate 8 (shell test suite runner): `test-verify-deploy-context-budget.sh` FAILED its own "baseline fixture is not clean" self-check (`rc=1`, `gate20 finding lines=0`) | That suite's baseline check runs a FULL nested `verify-deploy.sh` against an `rsync`'d snapshot of the live `agent-system/extensions/` tree, symlinked to the real repo's deployed `.claude/`. Reproducing the exact same nested invocation directly shows the ONLY failing gate inside it is Gate 13's orphan finding (the same `noop-bash-shapes-<session>` file above) — gate20 (the context-budget gate this suite actually tests) reports zero findings and is unaffected. The suite's own header already documents this full-battery baseline as incidental coverage of "no OTHER gate fails on this fixture," which is exactly the mode that surfaced here; it is not evidence of a context-budget regression. | Direct reproduction of the suite's own baseline command (`ORCHESTRATOR_BUDGET_GATE_MODE=warn bash verify-deploy.sh --skip-slow --findings --quiet "$FIXTURE"`) returns `[verify-deploy] FAIL -- 1 of 33 check(s) failed`, with the sole `FINDING` line being `gate13 orphan file: tmp/noop-bash-shapes-f86dc99f-...` — the identical artifact named in the row above. |

None of these three items touches this task's own `file_scope`
(`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`,
`specs/archive/state.json`). Confirmed independently clean for exactly those three files: Gate 5
(manifest-driven content-hash parity) PASSED after the `deploy-headless.sh` reconcile; `shellcheck
-x` on both edited scripts emits the identical pre-existing finding set as the pre-change `HEAD`
baseline (zero new findings, verified by diff); `check-task-references.sh` reports 0 occurrences
in both edited scripts; and the full standalone suite run (not routed through the contended
`run-all.sh`/nested-fixture path) is green at 192 passed, 0 failed, with a negative control
(Phase 1's splice temporarily reverted, cases a/b/c confirmed to FAIL, then restored) proving the
new tests are load-bearing.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` ends with zero FAILED, including the three new excursion cases and the untouched `707_candidate` invariant.
- [ ] The negative control in Phase 3 confirms the new own-directory case fails without the Phase 1 splice (no vacuous pass).
- [ ] `shellcheck -x` exits 0 for both edited shell files, or the binary's absence is recorded as an explicit skip rather than reported as clean.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.
- [ ] `jq empty specs/archive/state.json` exits 0 and the archived entry count is unchanged.
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new task-number findings outside `specs/**`.
- [ ] The excursion advisory's exit-code/verdict neutrality is unchanged: every excursion case still exits 0 with `verdict=ok`.

## Artifacts & Outputs

- Modified `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (h) implicit scope member + header rulings).
- Modified `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (three new excursion fixtures).
- Modified `specs/archive/state.json` (restated cross-reference in the archived entry's description).
- Regenerated deployed copies under `.claude/**` if and only if a deploy reconcile was required (never hand-edited).
- `specs/284_excursion_advisory_exempt_own_task_dir/summaries/01_*-summary.md` at implement postflight.

## Rollback/Contingency

Every phase is a small, reviewable diff in a file whose behavior is detection-only and whose
script runs without `set -e`, so a bad edit degrades to a wrong or missing stderr advisory rather
than to a broken postflight. To revert: `git revert` the phase commit, or restore the single
affected file from `HEAD` with a path-scoped checkout after taking a durable checkpoint first
(`bash .claude/scripts/git-snapshot.sh 284 --no-revert`; the reverting default form is for a
genuine rollback scenario only). If Phase 5's gate set fails for a reason traceable to this
change, fix forward in the WORK (h) block; if it fails for a reason outside this task's declared
files, treat it as possibly a sibling task's in-flight edit, confirm via `git log`, and report
rather than reverting another writer's work.
