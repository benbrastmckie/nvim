# Implementation Summary: Task #658

- **Task**: 658 - Add a shared gitignored-specs predicate and a distinct, non-failure commit-path
  outcome for an all-ignored pathspec
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T00:38:42Z
- **Completed**: 2026-11-20T05:30:00Z
- **Effort**: ~5 hours
- **Dependencies**: None (task 618 shares file territory in `git-commit-scoped.sh`; declared
  not-blocking by the user's ruling, never co-admitted into one batch)
- **Artifacts**: plans/01_ignored-specs-predicate-commit-path.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added one shared predicate library (`scripts/lib/specs-ignore-lib.sh`) answering whether a
repository's `specs` tree, or one path inside it, is gitignored, and a new `V13` classification
gate in `git-commit-scoped.sh` that consults it per positive pathspec before the existing
all-or-nothing `git add` call can see an untracked, gitignored path. Two new additive,
non-failure exit codes (`8` all-ignored, `9` partial-ignore-with-landed-commit) replace the
previous indistinguishable-from-a-real-failure exit `2` for this shape. Both consumer call sites
(`orchestrate-cycle-postflight.sh`, `git-commit-phase.sh`) and the standards document
(`context/standards/git-staging-scope.md`) were updated to match, and the whole change was
redeployed and verified against a tracked-specs baseline and two new ignored-specs fixtures.

## What Changed

- `agent-system/extensions/core/scripts/lib/specs-ignore-lib.sh` — new: two rc-based predicates,
  `specs_tree_is_gitignored` (repository-level) and `path_is_gitignored` (per-pathspec), both
  fail-open to "not ignored", modelled on `lib/engine-written-state-paths-lib.sh`'s header style.
- `agent-system/extensions/core/scripts/tests/test-specs-ignore-lib.sh` — new: 12 cases covering
  both polarities, the partial-ignore case, the index-awareness property for a
  tracked-but-ignore-matching path, and the fail-open direction.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — the `ignored_dropped` ledger, a
  guarded source of the new library, the `V13` gate in the V2 classification loop (after
  V9/V10/V11, before case 1), the exit-`8` gate (before V3's post-filter refusal) and exit-`9`
  gate (after V10's exit `7`), and header documentation for both the exit-code list and the
  gate-label list.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — amended test case U5
  (rc `2` -> `8`, `ERROR:.*genuinely unstaged` -> a `NOTE:` match, invariant assertions preserved
  verbatim); added `build_repo_specs_ignored` and `build_repo_specs_partially_ignored` fixture
  builders plus seven new controls (`AA1`-`AA7` — renamed from the plan's own "Y1-Y6" wording to
  avoid colliding with this suite's pre-existing `Y1`-`Y6`/`Z1`-`Z18` case series), including a
  control-of-the-controls probe that neutralises `V13` and confirms the new exit codes disappear.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — a dedicated `8|9)`
  `NOTE`-level arm in the WORK (i) `case "$commit_rc"` statement (never `ERROR:`, never an
  `issue-record.sh` call); the demotion-gate comment extended to name `8`/`9` as two further
  deliberate no-demotion exclusions (the arm's own code is unchanged).
- `agent-system/extensions/core/scripts/git-commit-phase.sh` — header note for the `8`/`9`
  passthrough, plus a recorded (not fixed) caveat that this script's own locally-reserved `6`
  collides with the inner codes `6`/`7` from `git-commit-scoped.sh`.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — exit `8`/`9` table
  rows, a `V13` gate-label entry, the corrected gate-label enumeration, a scoped amendment to
  "Positive-Pathspec Ignore-Advisory Hazard" (with mutual cross-references to/from `V13`), a
  measured account of the real plain-`mv`-into-ignored-destination call-site pattern, and a new
  "Per-Operation Contract: Tracked vs. Gitignored `specs`" subsection.
- `agent-system/extensions/core/scripts/tests/suite-classification.data`,
  `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/index-entries.json`
  — registration and derived-surface reconciliation for the new library/test pair and the moved
  `git-staging-scope.md` line count.
- Redeployed `.claude/**`: every one of the seven edited/created files verified byte-identical
  between the source store and the deployed tree.

## Decisions

- `V13` drops feed a dedicated `ignored_dropped` ledger only, never `dropped_pathspecs` — a
  `V13` drop's cause is definitively known and definitively benign, unlike the ambiguous-cause
  shapes `dropped_pathspecs` exists to flag for V6's exit `4`.
- The exit-`8` gate is placed immediately before the V3 post-filter gate; exit-`9` immediately
  after V10's exit `7`, giving the precedence chain `6` (V9) > `7` (V10) > `9` (V13).
- `V13` is unconditional (not `--task`-gated, unlike V10) and evaluated after V9/V10/V11, before
  case 1's existence test.
- The predicate's two functions are rc-based booleans with no stdout, fail-open to "not ignored"
  on any indeterminate input — mirroring the fall-through direction the script's own existing
  `check-ignore` call for ephemeral-exclude injection already documents.
- The library is consulted from one call site (`V13`) rather than inlined per the task's own
  "one mechanism consulted from one place" criterion, departing from the research report's
  inline recommendation.

## Plan Deviations

- **Phase 3's controls** renamed from the plan's own "Y1-Y6" wording to `AA1`-`AA7`: this test
  suite already carries pre-existing `Y1`-`Y6` (V11 cached-untracking) and `Z1`-`Z18` (V10
  containment) case series from earlier work, and reusing those letters would have collided with
  and shadowed the existing cases.
- **Phase 3's `build_repo_specs_partially_ignored` builder** initially omitted `mkdir -p
  "$repo/specs"`, causing a silent write failure and a polluted captured path variable on first
  run; fixed in the same phase.
- **Phase 6's task order** (line-count reconciliation vs. redeploy) was executed redeploy-first,
  since `generate-context-line-counts.sh` refuses to run from the source-store `scripts/`
  directory; the net outcome (reconciled `line_count`, clean `check-extension-docs.sh`) matches
  what the plan itself anticipated either way.
- **Test-suite harness additions not itemized in the plan's task list**: `lib/specs-ignore-lib.sh`
  was added to `test-git-commit-scoped.sh`'s `REQUIRED_SCRIPTS` array and its five `chmod +x`
  exclusion guards, required for the scratch-repo fixtures to actually source the new library.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on every edited script, no new `shellcheck` findings
  versus each file's own pre-dispatch baseline)
- Tests: Passed — `test-specs-ignore-lib.sh` 12/12; `test-git-commit-scoped.sh` 83/83 (including
  the amended U5, the unchanged X5/U1-U4/U6, and the new AA1-AA7); `test-git-commit-phase.sh`
  84/84; `test-orchestrate-cycle-postflight.sh` 321/321 — all four re-confirmed against the
  deployed tree after redeploy.
- Files verified: Yes — all 7 edited/created files byte-identical between source store and
  deployed tree; `check-extension-docs.sh` reports "core PASS" / "all extensions OK".
- DONE WHEN criteria: the predicate exists in one place with its own tests (Phase 1); the
  script's exit-code contract and header distinguish the new outcome beside the existing V-codes
  (Phase 2); `git-staging-scope.md` states the per-operation contract for both postures (Phase
  5); a tracked-specs repository's commit behaviour is demonstrably unchanged (Control AA1, and
  every pre-existing baseline case requiring no amendment beyond U5's).

## Impacts

- A consumer repository whose `specs` tree is wholly or partly gitignored now receives an
  honest, non-failure exit code (`8`/`9`) instead of a staging-failure-shaped exit `2`, and its
  trackable sibling paths commit normally instead of being withheld by the prior all-or-nothing
  refusal.
- `orchestrate-cycle-postflight.sh` no longer demotes a task to `partial`, nor emits a loud
  `ERROR:`, solely because its target repository ignores `specs/`.
- A tracked-`specs` repository (this repository's own root, and every consumer repository that
  has not gitignored `specs/`) is unaffected: `V13` never fires for a tracked path, by
  construction (index-awareness), and every pre-existing baseline test case required no
  amendment beyond U5's rc/message-class change.

## Follow-ups

- Task 618 (`working_tree_residue_disposition_policy`) should re-measure its own starting
  evidence against `git-commit-scoped.sh` now that `V13` has landed, per the dispatch's own
  not-blocking ruling; the two tasks must never be co-admitted into one batch.
- The pre-existing exit-`7` framing gap in `orchestrate-cycle-postflight.sh`'s `*)` catch-all, and
  the pre-existing `6`/`7`-versus-local-`6` collision in `git-commit-phase.sh`'s exit-code
  vocabulary, remain unfixed (both pre-existing, explicit non-goals, now also re-recorded in the
  header/standards-doc prose this task touched).
- One pre-existing, unrelated finding (`scripts/tests/run-all.sh`'s own Gate 27
  subject-resolution-declaration gap) surfaced during this task's `verify-deploy.sh` and
  `verify-touched.sh` runs; confirmed via `git log`/`git status` to predate this dispatch and
  left unfixed as out of this task's declared scope.

## References

- Plan: `specs/658_ignored_specs_predicate_and_commit_path/plans/01_ignored-specs-predicate-commit-path.md`
- Research report: `specs/658_ignored_specs_predicate_and_commit_path/reports/01_ignored-specs-predicate-research.md`
- Progress files: `specs/658_ignored_specs_predicate_and_commit_path/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/658_ignored_specs_predicate_and_commit_path/handoffs/phase-{1..6}-handoff-*.md`
