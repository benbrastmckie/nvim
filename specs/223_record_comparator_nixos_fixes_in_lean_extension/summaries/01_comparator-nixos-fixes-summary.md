# Implementation Summary: Task #223

- **Task**: 223 - Record comparator nixos fixes in lean extension
- **Status**: [COMPLETED]
- **Started**: 2026-09-29
- **Completed**: 2026-09-30
- **Effort**: ~9 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_comparator-nixos-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Transcribed the four proven Comparator-on-NixOS fixes (landrun shim with TMPDIR/git-library/
ELF-interpreter grants, pinned-toolchain PATH ordering with elan-wrapper unwrapping, an outer
landrun hardening layer, and a git-remote pre-flight probe) from the `framed_channel` reference
implementation into the lean extension's source store, so a Comparator run works on this NixOS
host. Documented four further findings (the `lean4export` panic on a Challenge-absent
`permitted_axioms` entry, the `lake update --keep-toolchain` pitfall, the batched-Lean4Lean
earlyoom caveat, and the outer-landrun design rationale) in the design record and operator
guide. Added a new `dependency-tracing.md` pattern file (absorbed scope) reproducing four
reusable Lean 4 dependency-tracing probe shapes and the `#print axioms` caveat. Closed the round
with the lean extension's first-ever deploy to `.claude/`.

## What Changed

- `agent-system/extensions/lean/scripts/lean-comparator-landrun-shim.sh` — new file: the
  landrun shim Comparator's own internal sandbox is pointed at via `COMPARATOR_LANDRUN`, adding
  TMPDIR-inside-`.lake`, git shared-library `--rox`, and ELF-interpreter `--rox` grants.
- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` — `resolve_toolchain()` (Fix 1:
  pinned-toolchain PATH ordering via `lean --print-prefix`, elan-wrapper unwrap into a private
  `LAKE_DIR`), `git_remote_preflight()` (pre-flight probe over `.lake/packages/*/`), and
  `run_sandboxed()`'s outer landrun hardening layer (confines the whole run, not just
  Comparator's own internal build) with an explicit `--env` passthrough list.
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` — six new regression
  cases (P1-P5 plus a dedicated mutation check) covering PATH ordering, elan-wrapper unwrapping,
  shim wiring, the shim's own grants, and the pre-flight probe; two new test helpers
  (`make_lean_stub`, `write_landrun_stub`/`write_wrapped_lake_stub`) needed to keep the 22
  pre-existing cases green against the newly-real toolchain resolution and landrun wrapping.
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` —
  diagnosed root cause for the `lake: Permission denied` failure (superseding the old
  "Comparator's own internal concern" framing), the landrun-shim mechanism, the `lean4export`
  panic, the `lake update --keep-toolchain` pitfall, the batched-Lean4Lean earlyoom caveat, and
  the outer-landrun/pre-flight design decisions.
- `agent-system/extensions/lean/context/project/lean4/tools/comparator-guide.md` — operator
  pointer for hand-constructing `permitted_axioms`.
- `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md` — new
  file (211 lines): the `#print axioms` caveat plus four reusable probe-shape templates.
- `agent-system/extensions/lean/manifest.json`, `index-entries.json`, `EXTENSION.md` — wiring
  for the new shim script and pattern file, plus a missing pre-existing index entry for
  `operations/long-builds.md` (see Deviations).
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/fake-landrun.sh` — added a
  missing trailing newline (pre-existing, see Deviations).
- Loaded the `lean` extension into `.claude-extensions.json` (never previously active on this
  host) so this task's own files could reach the `.claude/` deploy tree.

## Decisions

- Re-read every reference file live at implementation time rather than trusting the research
  report's quoted excerpts — confirmed stale paths and three mechanisms (ELF-interpreter grant,
  in-shim PATH prepend, `RECHECK_EXTRA_RWX` hook) the report never mentioned; only the first two
  were in this task's own Phase 1 scope.
- Reused `$LANDRUN_PATH` directly for the outer landrun layer (no separate override var); its
  "non-fatal absence" branch is defensive belt-and-suspenders since binary resolution already
  requires it earlier in the script.
- `git_remote_preflight()` runs as its own main-flow step, not folded into `clean_room_setup()`
  or `run_sandboxed()`.

## Plan Deviations

- **Task 1.8** (shellcheck): shellcheck is not installed on this host; substituted `bash -n`
  clean plus manual review.
- **Task 2.8 / 3.6** (re-run existing suite): required two new test helpers not in the plan's
  own file list — `make_lean_stub()` (stub `lean --print-prefix`, needed once real toolchain
  resolution existed) and `write_landrun_stub()` (exec-forwarding landrun stub, needed once the
  outer landrun layer wrapped the whole invocation rather than only Comparator's own internal,
  never-reached-by-stub use).
- **Phase 3 verification** ("pre-flight failure path is reachable"): deferred to Phase 4's own
  dedicated regression case (Case P5) rather than built as an ad hoc Phase 3 smoke test.
- **Task 7.1** (repo-wide shell-test runner): deferred, matching `verify-deploy.sh`'s own
  default `--skip-slow` convention; every lean-specific test file was run individually instead
  (28/0/1, 14/0/0, 17/0, 7/0, 10/0 across the five suites).
- **Task 7.2 / Phase 7 heading**: closed as `[COMPLETED WITH EXCLUSIONS]`. Loading the `lean`
  extension for the first time on this host surfaced two trivial pre-existing gaps (fixed
  directly: a missing `index-entries.json` entry for `operations/long-builds.md`, a missing
  trailing newline on `fake-landrun.sh`) and three non-trivial pre-existing gaps, documented as
  a Reasoned Exclusions record on the Phase 7 heading in the plan:
  1. Manifest-driven verification flags 3 "core: content differs from source" findings for
     `context/contracts/{adversarial-verification,anti-analysis,reference-grounding}.md` — NOT
     a defect: these are legitimate lean-extension overrides of the core contracts
     (`manifest.json`'s `provides.context` includes `contracts`), and `verify-deploy.sh`'s
     manifest check is simply not override-aware. Fixing it is a `core`-scoped change outside
     this task's file_scope.
  2. Postflight boundary lint flags `skill-lean-research/SKILL.md` for a missing
     `## MUST NOT (Postflight Boundary)` section — a pre-existing lean-extension gap unrelated
     to Comparator/dependency-tracing, predating this task by many commits.
  3. The orchestrator context budget lock flags the eager-load total (67980 B) exceeding the
     recorded baseline (65950 B) — the direct, expected consequence of loading a
     previously-unloaded extension for the first time; the baseline file is `core`-owned and
     its own check text gates re-deriving it on human review.

## Verification

- Build: N/A (bash scripts + markdown; no compiled build step)
- Tests: `test-lean-comparator-run.sh` 28 passed / 0 failed / 1 skip (Case E1, explicitly
  deferred for want of real `comparator`/`lean4export` binaries), identical from both the
  source store and the deployed copy. Four sibling lean test suites also pass (14/0/0, 17/0,
  7/0, 10/0), plus the sibling-regression check for `test-lean-sorry-census.sh`.
- Files verified: Yes — both new deployed paths
  (`.claude/scripts/lean-comparator-landrun-shim.sh`,
  `.claude/context/project/lean4/patterns/dependency-tracing.md`) confirmed present and correct
  post-deploy.
- `bash .claude/scripts/check-task-references.sh` reports 0 unexempted task-reference
  occurrences across all touched files outside `specs/**`.
- `verify-deploy.sh`: 30 of 33 checks pass; 3 pre-existing, out-of-scope findings documented
  above (Reasoned Exclusions).

## Impacts

- A Comparator run is no longer blocked by the previously-undiagnosed `lake: Permission denied`
  failure on this NixOS host; the four fixes are load-bearing for any future real end-to-end
  Comparator demonstration once `lean4export`/`nanoda_bin` are provisioned (tracked separately).
- The lean extension is now active in `.claude-extensions.json` and deployed to `.claude/` for
  the first time on this host, surfacing (and partly fixing) latent extension-hygiene gaps that
  had never been exercised before.
- The new `dependency-tracing.md` pattern gives a future dependency-trace task four ready-to-adapt
  probe templates instead of starting from zero.

## Follow-ups

- Provisioning `lean4export`/`nanoda_bin` remains tracked by the sibling `~/.dotfiles/` effort;
  a real end-to-end Comparator run stays out of reach until that lands.
- The three Reasoned-Exclusions findings from Phase 7 (override-aware manifest verification,
  `skill-lean-research/SKILL.md`'s missing postflight-boundary section, the eager-load budget
  baseline) are pre-existing, `core`-scoped or cross-cutting concerns outside this task's file
  scope; a future lean-extension-hygiene or `core` maintenance task should pick them up.

## References

- Plan: `specs/223_record_comparator_nixos_fixes_in_lean_extension/plans/01_comparator-nixos-fixes.md`
- Report: `specs/223_record_comparator_nixos_fixes_in_lean_extension/reports/01_comparator-nixos-fixes.md`
- Progress files: `specs/223_record_comparator_nixos_fixes_in_lean_extension/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/223_record_comparator_nixos_fixes_in_lean_extension/handoffs/`
- Live reference (re-read at implementation time): `~/Projects/Logos/Verification/framed_channel/scripts/recheck-comparator.sh`, `~/Projects/Logos/Verification/framed_channel/recheck/landrun-shim.sh`
- Absorbed-scope probes: `~/Projects/BimodalLogic/specs/archive/549_trace_decide_dependency_on_vacuous_run_theorems/probes/`
