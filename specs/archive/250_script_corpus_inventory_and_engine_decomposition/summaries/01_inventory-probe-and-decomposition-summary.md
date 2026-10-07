# Implementation Summary: Task #250

- **Task**: 250 - Script-corpus inventory probe, then decompose orchestrate-cycle-plan.sh
- **Status**: [COMPLETED]
- **Started**: 2026-10-03T06:10:52Z
- **Completed**: 2026-10-03T09:50:00Z
- **Effort**: ~3.5 hours (plan estimated 11 hours)
- **Dependencies**: 199, 245, 249, 259, 265, 266 (all completed, re-verified in research)
- **Artifacts**: plans/01_inventory-probe-and-decomposition.md, reports/01_script-corpus-inventory-probe-and-decomposition.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Built a standing, mechanical inventory probe (`scripts/script-inventory.sh`) over the non-test
shell-script corpus under `agent-system/extensions/**`, registered it, and acted on its
evidence-based ranking by decomposing `orchestrate-cycle-plan.sh` — the corpus's largest script —
into three `scripts/lib/` extractions. All six plan phases completed. `orchestrate-cycle-plan.sh`
shrank from 3,026 to 2,597 lines (14.2%); the full test suite, a byte-identical `--dry-run` diff
against a pre-refactor baseline, and the complete acceptance sweep all pass.

## What Changed

- `agent-system/extensions/core/scripts/script-inventory.sh` — new standing probe. Per non-test
  script: line/byte counts, a textual (grep-based, deliberately over-counting) inbound-caller
  census across skills/agents/commands/manifests/hooks/docs/scripts, filename-convention
  test-coverage pairing, `provides.scripts`/`provides.hooks` manifest-registration (reusing
  `check-extension-docs.sh` Rule Q by invocation for `scripts/`, a small supplementary
  `provides.hooks` check for `hooks/`), bounded cross-script duplicate-block detection (fixed
  10-line normalized windows via one `python3` pass, reported at 3+ occurrences or 2+ files), and
  a documented composite-score ranked ordering (`score = lines + 500*zero_caller + duplicate_blocks`,
  weighted so line count stays the dominant signal). `--check` mode prints the per-script table
  and exits non-zero on a zero-caller or manifest-unregistered finding.
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` — new suite, 19 cases,
  covering every metric including the no-side-effects contract.
- `agent-system/extensions/core/manifest.json` — registered `script-inventory.sh`,
  `tests/test-script-inventory.sh`, and the three new libs below in `provides.scripts`.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — added the probe's
  entry alongside `assess-repo-health.sh`.
- `specs/250_script_corpus_inventory_and_engine_decomposition/probe-baseline.json` — captured
  probe output over the real source store; reproducibility formally confirmed (two runs, empty
  diff modulo the documented `generated_at` timestamp field).
- `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh` — new lib (330 lines):
  `_sibling_territory_classify_entry`, `build_sibling_territory`, `_paths_contend`,
  `build_contended_manifest`, and the `CONTENDED_MANIFEST_DIR` assignment, moved verbatim out of
  `orchestrate_cycle_plan_main()`.
- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` — new lib (103 lines):
  `is_terminal_status`, `in_json_array`, `task_has_forced_phase`, `task_is_build_heavy_implement`,
  and the `BUILD_HEAVY_TASK_TYPES` array, moved verbatim out of four disjoint call sites.
- `agent-system/extensions/core/scripts/lib/redeploy-checkpoint-lib.sh` — new lib (158 lines):
  the "Post-deploy reconcile pass" leaf sub-region only (the plan's own declared fallback — see
  Plan Deviations). `run_post_deploy_reconcile_pass()`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — reduced 3,026 → 2,597 lines
  (429 fewer, 14.2%); three new early `source` blocks for the libs above; each extracted region
  replaced with a short pointer comment.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — fixture setup
  extended to copy the three new libs into its isolated `.claude/scripts/lib/` workdir; Case G's
  `_paths_contend()` unit-extraction re-pointed from `orchestrate-cycle-plan.sh` to
  `lib/territory-contention-lib.sh`, its new home.
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` — fixture setup extended
  (source-store-first inversion) to resolve and copy all three new libs.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` — fixture
  setup's `REQUIRED_LIB_SCRIPTS` array extended with all three new libs.
- `specs/250_script_corpus_inventory_and_engine_decomposition/dry-run-baseline/` — the
  pre-refactor `--dry-run` JSON+human-table baseline (tasks 22, 29, 170), diffed byte-identical
  after every one of Phases 4-6.

## Decisions

- **Verbatim relocation instead of parameter-conversion, for all three extractions.** The plan
  instructed converting every closed-over local into an explicit parameter (serializing
  `effective_group` as JSON, etc.). Before doing that, I verified experimentally (three minimal
  bash fixtures) that bash scopes `local` DYNAMICALLY by call stack, not lexically by textual
  nesting: a function `source`d from a separate file still sees — and can modify — a caller's
  `local` variables when invoked from within that caller's own execution. Grepping each candidate
  region confirmed none of the five variables the plan named as "closed-over locals"
  (`effective_group`, `session_id`, `new_cycle_count`, `CONTENDED_MANIFEST_DIR`, `PROJECT_ROOT`)
  were actually both function-local AND inaccessible by this mechanism — only `effective_group`
  is a true function-local, and dynamic scoping reaches it transparently. A verbatim,
  byte-for-byte move is therefore both simpler and strictly safer than a parameter-conversion
  rewrite (which itself risks a silent behavior change), and makes every byte-identical
  `--dry-run` diff a structural guarantee rather than something to verify painstakingly.
  Phase 6's 479-line candidate region went further: a direct grep found **zero** `local`/`declare`
  statements in it at all, confirming the same property at the largest scale attempted.
- **Phase 6 took the plan's own declared fallback, for a reason the plan did not anticipate.** A
  first attempt moved the WHOLE 479-line inter-cycle-redeploy-checkpoint region — including its
  inline `deploy-headless.sh` call — into the lib. It passed every other gate but failed
  `test-lint-deploy-caller-wrap.sh`, which hard-codes exactly two genuine, specially-wrapped
  `deploy-headless.sh` callers in the whole corpus. Per this task's own "never weaken a test"
  rule, I reverted that attempt rather than patch the lint, and instead extracted only the
  106-line "Post-deploy reconcile pass" leaf (confirmed to contain no `deploy-headless.sh`
  reference), leaving the hazardous call inline, still protected by `orchestrate-cycle-plan.sh`'s
  existing self-overwrite wrap. See Plan Deviations and Follow-ups for the consequence.
- **Duplicate-block score weight lowered from the initial x20 to x1.** At x20, a 1,635-line
  script with 172 duplicate-window hits outranked the corpus's actual largest script
  (orchestrate-cycle-plan.sh, 3,026 lines) — violating the plan's own Phase 2 verification
  criterion. Reduced to a low-weight modifier so line count stays the dominant signal; re-verified
  `orchestrate-cycle-plan.sh` ranks #1 both before and after the Phase 4-6 extractions.
- **`manifest_registered` is category-aware (`scripts/` → Rule Q reuse; `hooks/` → a small
  supplementary `provides.hooks` membership check)**, since Rule Q's own jurisdiction stops at
  `scripts/` and would otherwise misreport every hook file as unregistered.

## Plan Deviations

- **Task 272's status re-check** (Phase 4, item 1): confirmed `not_started`, no deviation.
- **Phase 4 "Convert every closed-over local into an explicit parameter"**: altered — verbatim
  move instead, per the dynamic-scoping finding above. Documented in
  `lib/territory-contention-lib.sh`'s own header and the plan's Phase 4 task annotations.
- **Phase 5, same instruction**: altered — same reason, documented in
  `lib/task-classification-lib.sh`'s header.
- **Phase 6, "Create `scripts/lib/redeploy-checkpoint-lib.sh` holding the checkpoint and reconcile
  logic... with explicit parameters"**: altered, AND the plan's own **Declared Fallback** item was
  invoked — not for the reason it anticipated (an unsafe/large closed-over-local set; there was
  none), but because moving the full region broke `test-lint-deploy-caller-wrap.sh`'s two-caller
  invariant for `deploy-headless.sh`. Only the "Post-deploy reconcile pass" leaf (106 of the 479
  candidate lines) was extracted; the "(k, part 2) Inter-cycle redeploy checkpoint" half
  (~373 lines, including the `deploy-headless.sh` call) remains inline in
  `orchestrate-cycle-plan.sh`. Consequence: the final reduction is 14.2% (3,026 → 2,597), not the
  plan's ~29% target. See Follow-ups for what a future task would need to do to close that gap.

## Verification

- Build: N/A (bash scripts; `bash -n` clean on every new/modified file)
- Tests:
  - `tests/test-script-inventory.sh`: 19/19 passed
  - `tests/test-orchestrate-cycle-plan.sh`: 344/344 passed (including Group 31 contended-path
    manifest, Groups 1/2/8, Groups 4/5/6)
  - `tests/test-force-phases.sh`: 36/36 passed
  - `tests/test-orchestrate-unwind-dispatch.sh`: 21/21 passed
  - `tests/test-lint-deploy-caller-wrap.sh`: 7/7 passed (after the Phase 6 fallback correction)
  - `tests/run-all.sh --jobs auto` (final, post-Phase-6): 104 passed, 4 failed (3 EXPECTED per
    the suite's own known-failures manifest; 1 NEW but **foreign and out of this task's scope** —
    `tests/test-typst-element-lint.sh`, caused by a pre-existing uncommitted modification to
    `agent-system/extensions/typst/scripts/typst-element-lint.sh` present in the working tree
    before this dispatch began, confirmed via `git diff --stat` and `git log`), 1 skipped, 109
    total. Re-run identically after each of Phases 4, 5, and 6.
  - `tests/test-lake-build-guard.sh` was observed failing inside ONE full `run-all.sh --jobs auto`
    pass (Phase 5's run) then passed 48/48 cleanly in isolation immediately after — the exact
    known ambient-concurrency flake this backlog's shell-test-isolation task already documents,
    not a regression from this task.
- `--dry-run` byte-identical: confirmed after Phases 4, 5, and 6, each time diffed against the
  single pre-refactor baseline (tasks 22/29/170) — empty diff every time.
- `md5sum specs/state.json`: unchanged across every `--dry-run` invocation throughout.
- `check-extension-docs.sh`: PASS overall every run; 4 content-drift FAIL items persist from
  Phase 4 onward (the edited `orchestrate-cycle-plan.sh` and 3 test files not yet redeployed —
  expected, self-resolving at the orchestrator's next redeploy checkpoint, never attempted by this
  agent per `context/patterns/regeneration-is-manual-only.md`'s sanctioned-caller-only rule) plus
  ADVISORY (never-deployed) entries for the 3 new libs and 2 new Phase 1-3 files. No new Rule
  E/Q drift at any point.
- `verify-deploy.sh --skip-slow` (final): 2 of 33 checks failed — gate 3 (doc-lint) and gate 5
  (manifest-driven verification), both propagating the SAME not-yet-deployed-source-store-edits
  condition above, not a second independent defect. The two issues the dispatch recorded as
  pre-existing on 2026-10-02 (migrate-state-legacy-fields.sh doc-lint gap, sandbox orphan tmp
  file) are both CONFIRMED ABSENT from every run in this task.
- Files verified: yes (all new/modified files confirmed to exist and be non-empty; `jq empty` on
  `manifest.json` at every edit).

## Impacts

- The corpus now has a standing, re-runnable, evidence-based inventory probe
  (`script-inventory.sh --check` is safe to run on demand) instead of relying on ad hoc reading.
- `orchestrate-cycle-plan.sh` is 14.2% smaller and gained three new, independently-testable
  `scripts/lib/` modules, following the established extraction pattern.
- `test-lint-deploy-caller-wrap.sh`'s two-genuine-caller invariant for `deploy-headless.sh` was
  exercised for the first time by a real refactor attempt and held — confirming the lint "has
  teeth" against exactly the class of extraction mistake it exists to catch.

## Follow-ups

- **The deferred ~373-line "(k, part 2)" redeploy-checkpoint half** (including the
  `deploy-headless.sh` call) remains inline in `orchestrate-cycle-plan.sh`. A future task could
  extract it too, but would first need to resolve the `test-lint-deploy-caller-wrap.sh` constraint
  — either by teaching that lint to recognize a third, early-sourced-library safety shape (the
  "fully sourced long before the hazardous call executes" guarantee this task's lib headers
  document), or by wrapping the WHOLE lib file itself in one function invoked as that file's own
  last statement, matching `orchestrate-cycle-plan.sh`'s and `command-gate-out.sh`'s existing
  shape exactly.
- **`main()`'s remaining ~1,500-line straight-line stage body** (the ~25 banner-delimited sections
  outside the three extractions and the deferred checkpoint half) is still the bulk of what is
  left in `orchestrate-cycle-plan.sh`, and warrants its own task if further decomposition is
  wanted — not attempted here per the plan's Non-Goals.
- **The probe's `inbound_callers` field is a textual over-count by design**: on the real corpus it
  currently reports 0 zero-caller scripts (every registered script's own `manifest.json` entry
  counts as a "caller" of its basename). This made Phase 3's disposition step vacuous (nothing to
  disposition) rather than exercising the "most zero-caller hits are legitimate" judgment call the
  dispatch anticipated — worth knowing if a future reader expects that field to find dead code.
- **DEFECT A / gate-8 coverage gap** (pre-existing, flagged inline in the moved
  redeploy-checkpoint code's own comments, not introduced by this task): deferring `run-all.sh`
  from the inline `deploy-headless.sh --skip-verify` call means roughly 40 deploy-tree-first test
  suites are no longer exercised against a freshly-redeployed tree by this checkpoint. Already
  flagged for human review by a prior task; repeated here only because this task's extraction
  touched the surrounding code.

## References

- Plan: `specs/250_script_corpus_inventory_and_engine_decomposition/plans/01_inventory-probe-and-decomposition.md`
- Research: `specs/250_script_corpus_inventory_and_engine_decomposition/reports/01_script-corpus-inventory-probe-and-decomposition.md`
- Progress files: `specs/250_script_corpus_inventory_and_engine_decomposition/progress/phase-{1..6}-progress.json`
- Probe baseline: `specs/250_script_corpus_inventory_and_engine_decomposition/probe-baseline.json`
- Dry-run baseline: `specs/250_script_corpus_inventory_and_engine_decomposition/dry-run-baseline/`
