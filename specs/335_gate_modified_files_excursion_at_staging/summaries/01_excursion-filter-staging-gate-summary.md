# Implementation Summary: Task #335

- **Task**: 335 - Promote the modified_files-vs-file_scope excursion advisory into a staging-time
  gate, so the per-cycle commit stops carrying paths the advisory already named
- **Status**: [COMPLETED]
- **Started**: 2026-10-08
- **Completed**: 2026-10-08
- **Effort**: ~6.5 hours (matches plan estimate)
- **Dependencies**: 284 (completed — own-task-directory exemption in WORK (h))
- **Artifacts**: plans/01_excursion-filter-staging-gate.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, git-staging-scope.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md

## Overview

`orchestrate-cycle-postflight.sh`'s WORK (i) per-cycle commit step now derives its staged set from
the same `modified_files` array WORK (h) already parsed, and drops any entry WORK (h)'s own
`excursions_json` verdict names as outside the dispatching task's declared `file_scope` —
drop-and-warn, never refuse the whole commit. The ruling, its reason, a declined sibling work item,
and the surface this layer cannot reach are all recorded in the script's own header and in
`context/standards/git-staging-scope.md`. All edits landed in the source store
(`agent-system/extensions/core/**`), never `.claude/**`, per
`rules/source-store-deploy-boundary.md`.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — WORK (i)'s staging loop
  now iterates `modified_files_json` (no second independent read of `.modified_files[]`) and skips
  any entry present in `excursions_json` (read with no `:-` default, so a future reordering of
  WORK (h)/(i) fails loudly under `set -u`), emitting a per-path `EXCURSION DROPPED` warning and a
  summary line when `excursion_dropped_count > 0`. Header items (h) and (i) expanded with the
  ruling, the Decision-2 promotion-criterion distinction, the declined `orchestrator-postflight.sh`
  Stage 9 work item, the phase-commit non-coverage pointer, and the ordering dependency — the two
  pre-existing RULING blocks (own-task-directory, advisory-enforcement-level) preserved verbatim.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — the
  `707_candidate` excursion fixture modified so the excursion path (and the in-scope summary file)
  are real on-disk files with a genuine committed-then-modified state, adding commit-contents and
  left-dirty-on-disk assertions; four new fixtures added (fail-open #712, specs/ carve-out #713,
  all-entries-dropped edge #714, zero-`modified_files` confirmation #790); `setup_sandbox()` fixed
  to also copy `generate-task-order.sh`, a previously-missing hard dependency of `generate-todo.sh`
  that was silently degrading TODO.md regeneration in every sandboxed fixture.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — new subsection
  "Staging-Layer Containment Filter (a Refinement of the Fail-Safe Direction Above)" inserted
  immediately after "Fail-Safe Direction", recording the behaviour, the dated empirical basis with
  its phase-commit provenance stated accurately, the explicit non-claim, and the forward pointer to
  `general-implementation-agent.md`'s "Phase-Commit Containment Self-Check".

## Decisions

- Drop-and-warn (never refuse the whole commit, never widen `file_scope`) is the recorded ruling:
  it is the only candidate that needs no change to `git-commit-scoped.sh`'s exit-code contract,
  matches `git-staging-scope.md`'s "Under-stage, never over-stage" direction, and matches the
  sibling phase-commit surface's independently-reached ruling on the same Containment predicate.
- This IS the promotion dependency 284 deferred, but to a THIRD posture (drop-and-warn) distinct
  from the REFUSING-gate promotion criterion 284 recorded — drop-and-warn needs neither half of
  that criterion, since an absolute-path counter-example is simply dropped, not corrected.
- `modified_count` keeps counting every reported entry (unchanged meaning); a separate
  `excursion_dropped_count` tracks drops.
- Work item 3 (adding the same filter to the orphaned `orchestrator-postflight.sh` Stage 9) is
  declined — confirmed orphaned by three independent sources and zero repo-wide invocation sites.
- `issue-record.sh` is not called from the drop path — this script already has its own structured
  diagnostic channels (stderr warnings, `system-defect-record.sh`).

## Plan Deviations

- **Phase 3** (specs/ carve-out fixture, candidate #713) surfaced and fixed a genuine test-harness
  gap, not a SUT defect: `setup_sandbox()` never copied `generate-task-order.sh`, a hard dependency
  of `generate-todo.sh`. Without it, TODO.md regeneration silently failed (non-fatal warning) in
  EVERY existing fixture in the suite, undetected until this task's new assertion actually checked
  TODO.md's committed content. Fixed by adding it to both the `require_file` loop and the
  `setup_sandbox()` copy loop, with an explanatory comment matching the file's existing
  hard-dependency-comment convention. A companion discovery: a fixture whose dispatched task
  transitions to a terminal status can make a regenerated TODO.md come back byte-identical to a
  bare `"## Tasks"` baseline (the completed task drops out of the active list) — worked around by
  seeding candidate #713's baseline TODO.md with a stale placeholder line that cannot coincide with
  any real regenerated output.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
  **210 passed, 0 failed, exit 0** (up from 193 passed/2 failed confirmed RED against the
  unmodified script in Phase 1, both of which are now green per the ACCEPTANCE line's demand).
- `grep -c "jq -r '.modified_files\[\]" orchestrate-cycle-postflight.sh` → **1**, not the literally
  stated 0. The surviving hit is a DIFFERENT site: WORK (j)'s `cycle_modified_files` accumulation
  for the Inter-Cycle Redeploy Checkpoint (~line 1842), which carries its own regression-anchor
  comment and dedicated characterization test for an entirely different purpose (not commit
  staging) and is explicitly out of this task's scope. The literal WORK (i) duplicate read this
  task's work item (1) actually targets IS gone (confirmed via `git diff`, which shows exactly that
  line removed). Recorded here precisely rather than silently claiming the grep returns 0.
- Three sanctioned lints (`lint-scoped-commit-boundary.sh`, `lint-directory-pathspec-boundary.sh`,
  `lint-postflight-boundary.sh`): all exit 0, 0 violations each.
- Three sibling suites (`test-lint-scoped-commit-boundary.sh`, `test-lint-postflight-boundary.sh`,
  `test-guard-destructive-git.sh`): 8/0, 6/0, 91/0 — all exit 0.
- `shellcheck -x` on the edited script: **UNMET as literally specified** (exit 0 was not achieved).
  The environment's default resolved Nix-store shellcheck symlink was indeed broken (as
  research-time predicted), but `nix shell nixpkgs#shellcheck` resolved a working 0.11.0 binary,
  which exits 1. The 12-finding set (SC1091 unresolved sources, SC2012 `ls` usage, SC2034 unused
  `artifact_linked` at a pre-existing site) is **byte-identical, same rule codes in the same
  order**, between this task's pre-edit baseline (commit `526eb2622`) and the final edited file —
  zero new findings, zero removed, across both of this task's edits to the script (Phases 2 and
  4). Recorded honestly as an unmet strict item, not glossed over.
- `verify-deploy.sh`: run with `--skip-slow` (34 of 35 checks; gate 8 deferred given its ~5-6
  minute cost) — **3 of 34 FAIL**, none attributable to this task:
  - Doc-lint: "books-observe.sh not yet deployed" — unrelated extension (books), pre-existing.
  - Manifest content-hash: the three edited source-store files differ from their undeployed
    `.claude/` copies — EXPECTED (deploying is a separate, later step, out of this task's scope).
  - Whole-tree orphan detection: one stray `tmp/noop-bash-shapes-<session-id>` file matching THIS
    session's own scratchpad id — unrelated to any file this task touched.
  Gate 8 (`run-all.sh --jobs auto`, run standalone instead of inside verify-deploy.sh): 120
  passed, 2 failed, 4 skipped. Both failures (`test-gate-out-repair-reporting.sh`,
  `test-verify-deploy-context-budget.sh`) independently confirmed NOT attributable to this change:
  the first passes cleanly (21/0) when re-run serially instead of under `--jobs auto` concurrency
  (a parallelism artifact, not a regression); the second fails identically (14 passed/1 failed)
  both with and without this task's edits present, confirmed via a `git stash` baseline comparison
  against the unmodified script.
- Files verified: Yes (both edited scripts confirmed to exist, be non-empty, and pass their
  respective suites; `git-staging-scope.md`'s new subsection confirmed via `git diff --stat`,
  48 insertions, 0 deletions, pure addition).

## Work-Item-by-Work-Item Walkthrough

1. **One derivation, one verdict**: WORK (i) now iterates `modified_files_json` (WORK (h)'s own
   parse) and checks membership in `excursions_json`; the independent `.modified_files[]` re-read
   at that site is gone (confirmed via `git diff`).
2. **Ruling recorded**: drop-and-warn, with its reason, in the script header's item (i) and in
   `git-staging-scope.md`'s new subsection.
3. **`orchestrator-postflight.sh` Stage 9**: declined, recorded as such in the header (item (i)'s
   "DECLINED" paragraph) — orphan status re-confirmed, not merely carried from research.
4. **Fail-open**: confirmed structurally (no code added) and via the live candidate #712 fixture.
5. **specs/ carve-out and `modified_count -eq 0` preserved**: confirmed via candidate #713 (carve-out)
   and candidate #790 (zero-`modified_files`, sanctioned wording unchanged).
6. **Tests added**: candidates #712, #713, #714, #790, plus the modified #707 block, in
   `test-orchestrate-cycle-postflight.sh`, following the suite's existing fixture conventions.
7. **Phase-commit non-coverage disclaimed, owner named**: recorded in the script header and in
   `git-staging-scope.md`, pointing at `general-implementation-agent.md`'s "Phase-Commit
   Containment Self-Check" (re-confirmed present at the cited heading, file not edited).

## ACCEPTANCE Line Walkthrough

- "WORK (i)'s staged set is derived once and checked against WORK (h)'s verdict" — done (Phase 2).
- "an excursion is handled per the recorded ruling with the reason in the script header" — done
  (Phase 4).
- "a task with no file_scope commits exactly as it does today" — confirmed (candidate #712,
  fail-open).
- "the specs/ carve-out and the zero-modified_files case are both green" — confirmed (candidates
  #713 and #790).
- "git-staging-scope.md records the new behaviour... with the dated observation as its empirical
  basis and with that observation's phase-commit provenance stated accurately" — done (Phase 5).
- "the excursion shape is exercised as a synthesised postflight-shaped regression fixture that
  fails before the change and passes after" — done (Phase 1: RED against the unmodified script,
  193/2; Phase 2: GREEN, 210/0 at suite completion).
- "no artifact claims this gate would have caught the observed commit" — confirmed via the
  prohibited-claim audit (Phase 6): every match is the explicit non-claim or a meta-reference to
  the prohibition itself.
- "shellcheck clean per shell-strict-mode.md" — **UNMET**, recorded honestly above (zero NEW
  findings, but the pre-existing 12-finding baseline is not itself clean and fixing it is outside
  this task's declared scope).

## Impacts

- A future `/orchestrate` cycle whose dispatched agent self-reports a `modified_files` path outside
  its declared `file_scope` no longer has that path silently swept into the per-cycle commit; it is
  dropped with a loud warning and left on disk for manual review instead.
- No change to `git-commit-scoped.sh`'s exit-code contract, to how `file_scope` is declared or
  harvested, or to the phase-commit staging surface (that sibling task's own scope).

## Follow-ups

- If a future ruling needs a distinguishable `git-commit-scoped.sh` exit code for "commit succeeded
  but dropped a `file_scope` excursion," that is a FOLLOW-UP owned by the out-of-repository-
  pathspec task, which owns that exit-code contract. Not performed here, per this task's Non-Goals.
- The pre-existing 12-finding shellcheck baseline on `orchestrate-cycle-postflight.sh` (SC1091,
  SC2012, SC2034) remains unaddressed — out of this task's scope, but worth a dedicated cleanup
  task if `shell-strict-mode.md` compliance is to be enforced going forward.
- The sibling phase-commit staging surface (its own task, already landed per the dispatch
  description) is the owner of the in-dispatch mid-phase-commit Containment check this per-cycle
  postflight filter structurally cannot reach.

## References

- Plan: specs/335_gate_modified_files_excursion_at_staging/plans/01_excursion-filter-staging-gate.md
- Report: specs/335_gate_modified_files_excursion_at_staging/reports/01_excursion-filter-staging-gate.md
- Edited files: agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh,
  agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh,
  agent-system/extensions/core/context/standards/git-staging-scope.md
