# Implementation Summary: Task #153

- **Task**: 153 - lean_comparator_clean_room_runner
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T15:55:00Z
- **Completed**: 2026-09-07T19:10:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None in-repo. End-to-end acceptance additionally requires `landrun`,
  `lean4export` and the `comparator` binary provisioned by a sibling `~/.dotfiles/` task.
- **Artifacts**: plans/01_lean-comparator-clean-room-runner.md, reports/01_lean-comparator-clean-room-runner.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-script-testing.md, source-store-deploy-boundary.md

## Overview

Built `agent-system/extensions/lean/scripts/lean-comparator-run.sh`, a clean-room wrapper CLI
around the upstream `leanprover/comparator` judge, plus its regression suite
(`tests/test-lean-comparator-run.sh`), vendored/authored fixtures
(`tests/fixtures/comparator/`), and a design record
(`context/project/lean4/domain/comparator-integration.md`). All 8 plan phases completed. The
gate is ADVISORY ONLY per the binding operator decision: this task does not wire Comparator into
any completion gate.

## What Changed

- `agent-system/extensions/lean/scripts/lean-comparator-run.sh` — new, 683 lines. CLI parsing
  (`--project-root`, `--challenge-module`, `--solution-module`, `--theorems`,
  `--permitted-axioms`, `--definitions`, `--commit`, `--timeout`, `--keep-workdir`,
  `--enable-nanoda`, `--external-kernels`, `--json`); binary resolution for
  `COMPARATOR_BIN`/`COMPARATOR_LANDRUN`/`COMPARATOR_LEAN4EXPORT`/`COMPARATOR_NANODA` with loud
  `comparator_unavailable` degradation; clean-room `git worktree add` + `lake exe cache get` +
  lakefile/config.json synthesis; the README's mandated `systemd-run` sandbox wrapper nested
  around `lake-build-guard.sh` (`--no-share` always passed, never `--memory-bound`) with
  `--timeout`; and `classify_verdict()` recovering a 9-value closed verdict vocabulary
  (8 named + 1 internal `unclassified_failure` escape hatch) from Comparator's unstructured
  stdout/stderr via priority-ordered substring matching.
- `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh` — new, regression
  suite: 22 passing assertions plus 1 explicit skip-with-report, covering usage errors, all four
  resolvable-binary-missing cases, guard routing (argv assertion + degradation branches),
  timeout, all 9 verdict values, an anti-vacuous discrimination check, a live mutation check
  (mutated tool + full suite re-run confirmed to fail), and a sibling-suite regression check.
- `agent-system/extensions/lean/scripts/tests/fixtures/comparator/` — new: `fake-landrun.sh`,
  `simple_match/`, `def_hole_axiom_issue/` vendored from upstream commit `2312244ac716564a`
  (Apache-2.0, attributed); `statement_weakened/` authored for this task (no upstream fixture
  isolates a pure same-kind statement weakening); `README.md` recording provenance.
- `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md` — new
  design record: clean-room trust chain and alternatives, sandbox nesting order, the
  `--no-share` correctness requirement, the full verdict-string table with upstream source
  citations, the C3 version-coupling caveat, the binding advisory-only gate decision, and a
  mid-implementation binary-provisioning-status addendum.
- `agent-system/extensions/lean/manifest.json` — `provides.scripts` gained 16 new entries (2
  scripts + 14 individual fixture-tree files — the `scripts` deploy category has no
  directory-glob support, confirmed against the literature extension's identical precedent).
- `agent-system/extensions/lean/index-entries.json` — one new entry for the design record.

## Decisions

- Lakefile synthesis is parameterised by the actual `--challenge-module`/`--solution-module`
  names rather than upstream's literal "Challenge"/"Solution" strings, since this runner accepts
  arbitrary module names unlike upstream's own `runtests.lean` harness.
- Added a 9th, internal-only verdict `unclassified_failure` (exit 72) for `classify_verdict()`'s
  fail-closed fallthrough — necessary so a genuinely unrecognised Comparator failure is never
  misreported as `verified` or `comparator_unavailable`. Documented in both the plan (Goals-table
  amendment) and the design record.
- `RUN_STDOUT_LOG` (not `RUN_STDERR_LOG`) is where all of Comparator's own stdout+stderr text
  lands, because the README's mandated `--pty` wrapper merges the wrapped command's streams
  before `systemd-run` forwards them to its own stdout; `classify_verdict()` searches only that
  file.
- Manifest wiring requires per-file fixture entries (no directory-glob support in the `scripts`
  deploy category).

## Plan Deviations

- None (implementation followed plan). One amendment was recorded transparently within the plan
  itself (Phase 5's 9th verdict value, `unclassified_failure`) rather than treated as a deviation
  from a fixed spec, since the dispatch's acceptance criteria explicitly required a fail-closed
  fallthrough that the original 8-value vocabulary had no slot for.

## Verification

- Build: N/A (shell scripts).
- Tests: `test-lean-comparator-run.sh` — 22 passed, 0 failed, 1 skipped-with-report. Sibling
  `test-lean-sorry-census.sh` still exits 0. `bash -n` clean on all three shell files
  (`lean-comparator-run.sh`, `test-lean-comparator-run.sh`, `fake-landrun.sh`). A live mutation
  check (breaking the `axiom_violation` string match, then re-running the FULL suite against the
  mutated tool) confirmed the suite correctly fails (exit 1, Case V5 the specific failure).
- Files verified: Yes — `manifest.json` parses and every listed script/fixture path confirmed to
  exist on disk; `check-task-references.sh` reports 0 occurrences under
  `agent-system/extensions/lean/`; `git status --short .claude/` empty throughout.

## Impacts

- `lean-comparator-run.sh` is now deployable (pending a `.claude/` sync/reload) and available as
  a standalone, opt-in CLI. It is NOT wired into `lean-implementation-agent`'s Final Verification
  Stage or any other gate — that wiring, and the harder question of who authors a trusted
  `Challenge.lean` (constraint C1), are explicitly out of this task's scope and left to sibling
  tasks.
- The design record closes a previously-zero-coverage context gap for the lean extension:
  `context/project/lean4/domain/comparator-integration.md` is now the canonical reference for
  the clean-room trust chain, the verdict vocabulary, and the C3 version-coupling caveat, so a
  future hard-gate-promotion task (or anyone debugging a Comparator verdict) does not need to
  re-clone and re-read the upstream repository from scratch.

## Follow-ups

- **Sibling `~/.dotfiles/` provisioning task**: `lean4export` and `nanoda_bin` remain absent on
  this host. `comparator` and `landrun` were discovered present partway through this
  implementation (a change since the dispatch's own same-day snapshot), suggesting the sibling
  task has partially landed.
- **New finding for that sibling task (or a dedicated follow-up)**: invoking the real
  `comparator` binary directly (diagnostic only, no provisioning/patching attempted per this
  task's Non-Goal) against the vendored `simple_match` fixture failed with `error: command
  failed: 'lake' / Permission denied (os error 13)` — Comparator's own internal `landrun`
  invocation around its internal `lake` build appears to deny an operation `lake` needs
  (Landlock requires explicit `--ro`/`--rw`/`--rox`/`--rwx` grants). This is a SEPARATE blocker
  from `lean4export`'s absence; provisioning `lean4export` alone will not resolve it. Recorded in
  the design record's new "Binary Provisioning Status" section.
- Once both blockers clear, re-run `test-lean-comparator-run.sh`: its Case E1 will automatically
  convert from a skip-with-report into a real end-to-end pass/fail demonstration against
  `simple_match`/`statement_weakened`/`def_hole_axiom_issue` (the check is written to detect
  binary availability live, not hardcoded to skip).
- Promotion of Comparator to a hard completion gate (replacing or augmenting
  `lean-implementation-agent`'s current text-heuristic Final Verification Stage) is a separate,
  later, not-yet-made decision per the binding advisory-only gate strength decision — this task
  does not attempt it.
- Constraint C1 (who authors a trusted `Challenge.lean`, and what plan-format field would carry
  an intended statement rather than a bare identifier) remains unsolved and out of scope, as the
  plan's Non-Goals state explicitly.

## References

- Plan: `specs/153_lean_comparator_clean_room_runner/plans/01_lean-comparator-clean-room-runner.md`
- Research report: `specs/153_lean_comparator_clean_room_runner/reports/01_lean-comparator-clean-room-runner.md`
- Design record: `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`
- Runner script: `agent-system/extensions/lean/scripts/lean-comparator-run.sh`
- Regression suite: `agent-system/extensions/lean/scripts/tests/test-lean-comparator-run.sh`
- Fixtures: `agent-system/extensions/lean/scripts/tests/fixtures/comparator/`
