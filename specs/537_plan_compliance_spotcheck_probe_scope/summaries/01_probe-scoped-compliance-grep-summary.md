# Implementation Summary: Task #537

- **Task**: 537 - lean-implementation-agent's plan-compliance spot-check does not search
  plan-pinned evidence-probe locations outside `lean-src-roots.sh`'s roots
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T18:06:12Z
- **Completed**: 2026-11-22T18:24:03Z
- **Effort**: ~1.3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_probe-scoped-compliance-grep.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`lean-plan-compliance-check.sh`'s per-name declaration/field lookup (`find_decl_files`,
`find_field_files`) now searches the resolved Lean source roots unioned with paths the plan
under check itself declares — its own harvested `Files to modify` `.lean` entries and the
Challenge snapshot manifest's `project_root`+`challenge_path` join — under must-exist polarity
only, entirely fail-soft, with no caller-side change. The `replacement_targets` integrity sweep
inherits the widening automatically through its existing `find_decl_files` reuse.
`find_module_files` and refutation polarity stay roots-only by design (Decisions D1/D6). All
three plan phases completed; the deployed tree carries the change and diffs clean against the
source store.

## What Changed

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` — added a 4-rung
  harvester-resolution ladder (an explicitly-set `LEAN_PLAN_COMPLIANCE_HARVESTER` override is
  terminal; otherwise sibling-directory, repo-relative-deployed, then source-store
  sibling-extension rungs), a fail-soft `extra_paths` derivation (harvester Files-to-modify
  harvest plus an optional Challenge manifest join, gated on `jq`), a polarity-conditioned
  `search_roots` assignment (Decision D6), the three per-name grep call-site swaps
  (`find_decl_files` x2, `find_field_files`'s bare-name branch), reworded must-exist-polarity
  output scope phrases (Decision D8), and a sixth header-inventory entry.
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` — added a
  probe fixture outside `$ROOT` and six new regression cases (renumbered C23-C28 at implement
  time; see Plan Deviations), plus a header-comment update.
- `.claude/scripts/lean-plan-compliance-check.sh` and
  `.claude/scripts/tests/test-lean-plan-compliance-check.sh` — regenerated deploy artifacts via
  `deploy-headless.sh`, byte-identical to their source-store counterparts; not hand-edited.

## Decisions

- An explicitly-set `LEAN_PLAN_COMPLIANCE_HARVESTER` override is terminal (used if readable,
  else treated as unresolved outright), never falling through to the remaining three rungs —
  this is a clarification of the plan's own D7 intent, made during implementation because a
  uniform 4-way existence-checked cascade would silently defeat the plan's own fail-soft test
  case (the source-store sibling rung always resolves when running from the source store).
- Only the must-exist-polarity `[OK]`/`[MISSING]` decl/field output lines were reworded for
  Decision D8; the module `[OK]` line and all refutation-polarity lines keep their original
  phrasing unchanged, since `find_module_files` and refutation polarity were never widened.
- The absent/unparseable-Challenge-manifest case emits no stderr note (silent), consistent with
  Decision D4's "never an error" framing for a routine, expected condition; the no-`jq`/
  unresolvable-harvester/failed-harvest cases each emit exactly one note.

## Plan Deviations

- **Phase 2 case numbering** altered: the plan's plan-time numbering (C20-C25) collided with
  sibling task #504's already-landed C21/C22, so the six new cases were appended as C23-C28
  instead, per the plan's own Scope Hypothesis instruction to renumber upward rather than reuse
  a number.
- **Phase 1 suite-baseline figure** altered: the plan-time baseline of "19 passed, 0 failed" had
  drifted to 22 passed/0 failed by implement time (sibling task #504 landed C21/C22 after the
  plan was written); verified the live baseline unchanged (22/22, then 28/28 after Phase 2's
  additions) rather than checking against the stale plan-time count.
- **Phase 1 harvester-resolution-ladder mechanism** altered (not its intent): implemented as an
  explicitly-set-override-is-terminal design rather than a uniform 4-rung existence-checked
  cascade, to make the plan's own Verification bullet 3 (nonexistent-override -> fail-soft)
  actually testable. See Decisions above.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — `test-lean-plan-compliance-check.sh` reports 28 passed, 0 failed, both from
  the source-store location and from the redeployed `.claude/scripts/tests/` location
- Files verified: Yes — both deployed copies diff clean against their source-store counterparts;
  `verify-touched.sh` over both touched paths exits 0
- Regression-bind check: reverting the three `search_roots` call-site swaps in a scratch copy
  made exactly C23, C24, C25, C28 fail while C26, C27 still passed, confirming the new cases
  bind to the widening rather than passing for an unrelated reason

## Impacts

- A plan following this repository's evidence-probe convention (Goals pinned in
  `specs/evidence/**/*.lean`, outside `lean-src-roots.sh`'s resolved roots) no longer produces a
  false `COMPLIANCE_CHECK: failed` at the lean-implementation-agent's Final Verification Stage
  step 5, removing the hand-override this task's originating incident required.
- The `replacement_targets` integrity sweep now also catches a stale delegation living in such a
  probe-scoped file, closing the identical blind spot it previously inherited.

## Follow-ups

- The comparator-gate Preflight 4 sub-step (`lean-implementation-agent.md` step 6's inline
  `grep -rl ... "${lean_roots[@]}"` deriving `solution_module`) carries the structurally
  identical scope limitation and remains unfixed, deliberately out of scope per this plan's own
  Non-Goals. Recorded as a follow-up candidate in `issues.jsonl` (class: tooling bug or gap,
  severity minor).

## References

- Plan: `specs/537_plan_compliance_spotcheck_probe_scope/plans/01_probe-scoped-compliance-grep.md`
- Report: `specs/537_plan_compliance_spotcheck_probe_scope/reports/01_plan-compliance-probe-scope.md`
- Progress: `specs/537_plan_compliance_spotcheck_probe_scope/progress/phase-{1,2,3}-progress.json`
- Handoffs: `specs/537_plan_compliance_spotcheck_probe_scope/handoffs/phase-{1,2,3}-handoff-*.md`
- Originating observation: `iss_1791842368633_NJQxnS` (resolvable only in the source repository
  per this task's migration provenance)
