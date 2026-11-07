# Implementation Summary: Task #493

- **Task**: 493 - Plan format Tier Justification fixes
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T01:49:00Z
- **Completed**: 2026-11-07T03:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_tier-justification-fixes.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Two defects in the `**Tier Justification**:` block of
`agent-system/extensions/core/context/formats/plan-format.md` were repaired in the source store
and redeployed. Defect 1 (a suite-subset entry point that cannot resolve in a deploy-target
repository) was fixed by naming both the deploy and source-store forms and delegating the choice
to the existing "Batch-aware deferral" resolve-whichever-exists rule by reference. Defect 2 (a
Tier Justification asserting a selector result instead of measuring it) was closed with a new
measurement obligation in the standard plus a mechanical, advisory-first enforcement check added
to `scripts/validate-artifact.sh`, backed by a fixture pair in
`scripts/tests/test-validate-artifact.sh` and a corpus-wide residue sweep.

## What Changed

- `agent-system/extensions/core/context/formats/plan-format.md` — rewrote the suite-subset
  narrowing bullet (line ~339) to name the deploy form first and the source-store form second,
  referencing the "Batch-aware deferral" rule rather than restating it; added the measurement
  obligation sentence to the Tier Justification bullet and the sentinel-measurability sentence to
  the `__FULL_SWEEP__` paragraph (the three existing (a)/(b)/(c) sub-cases left untouched); added
  a new `### Enforcement level (Tier Justification measurement)` subsection after the existing
  `### Enforcement level (Files to modify)` subsection, recording the mechanical-lint ruling, its
  reasoning, scope, and promotion criterion with the measured corpus residue (5 of 11 non-terminal
  plan-linked tasks newly warn).
- `agent-system/extensions/core/scripts/validate-artifact.sh` — sourced
  `scripts/lib/suite-selection-lib.sh` (same lazy, `${BASH_SOURCE[0]}`-relative, exit-5-on-missing
  idiom as the two existing libraries); added a Tier Justification measurement check inside the
  existing per-phase `plan` loop that re-derives `suite_selection_select`'s output for each
  non-final phase's touched paths (harvested via `plan-file-scope-harvest.sh` on a single-phase
  fragment) and compares it against that phase's own claim in both directions (fabrication /
  under-verification), including the `__FULL_SWEEP__` sentinel as a measurable claim; skips the
  final phase.
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` — added
  `make_tj_fixture()` and seven new assertions: a positive fixture (measured claim, no finding), a
  negative/fabrication fixture (exactly one warning), a sentinel-direction pair (fabricated
  sentinel claim warns; genuinely-unmapped-path sentinel claim passes), and two skip-case variants
  (`__WHOLE_TREE__`-only and prose-sentinel-only `Files to modify` blocks).
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`; all three edited files confirmed
  byte-identical between source store and deployed copies.

## Decisions

- Claim extraction scans the captured `**Tier Justification**:` block for any `test-*.sh` token
  anywhere in the text (not only the literal `--only SUITE,...` command form), since the corpus
  uses both surface forms interchangeably for the same underlying claim.
- The block-capture pattern is anchored to line-start (optional leading list marker), not a bare
  substring match, to avoid false-matching a task-checklist bullet that merely mentions the field
  name in backticks — discovered live against this task's own Phase 2 task list.
- A mechanical lint was chosen over a prose-only requirement for defect 2: the originating defect
  was an author asserting the selector's output without running it, which a prose-only rule
  cannot prevent, while `suite_selection_select` costs roughly what a `grep` costs (no build, no
  test execution), so the mechanical check does not meaningfully raise the standard's cost.
- The new check's scope is bounded to `suite_selection_select`-grounded claims; it does not extend
  to the `--only-gate N[,M,...]` gate-subset mechanism, which neither filed defect implicates.

## Plan Deviations

- Phase 2: the new enforcement subsection's promotion-criterion residue was left as an explicit
  `PENDING-CORPUS-SWEEP` placeholder rather than a guessed figure, since the check did not yet
  exist; Phase 4 filled in the measured count once it did.
- Phase 3: discovered live, while testing against this task's own plan file (the first live
  positive fixture), that running the check from the SOURCE STORE copy of `validate-artifact.sh`
  produces false positives, because `suite_selection_select`'s scripts-root resolution is
  `BASH_SOURCE`-relative and the core extension's own source-store `tests/` lacks suites that live
  in other extensions. Verified instead against a temporary copy in `.claude/scripts/` (gitignored,
  disposable, and the actual production execution context).
- Phase 3: the negative-fixture verification bullet anticipated "exactly one mismatch warning" for
  a one-suite-name substitution; the measured, correct behavior is two (one per direction), since
  both the missing original suite and the fabricated replacement are independently detected. Not a
  defect — `--strict` exit is still non-zero as specified.
- Phase 3: Phase 4's own Tier Justification/Verification text (as originally planned) deferred one
  touched file's coverage to Phase 2 by cross-reference rather than stating it; the new check
  correctly flagged this as under-verification against this task's own first-live-positive-fixture
  requirement, so it was corrected to name the full measured union.
- Phase 4: two live-discovered fixture-construction hazards were corrected during fixture
  authoring — a fixed literal "unmapped path" placeholder self-matched via the grep-based
  reference stratum once written into the test file's own source (fixed by PID-suffixing it), and
  a real-suite path whose own basename looked like a `test-*.sh` file caused the claim-extraction
  token scan to misread the path-argument mention as part of the claim (fixed by using a
  non-test-shaped real-suite path instead).
- Phase 5: the plan's verification bullet "`bash .claude/scripts/verify-deploy.sh` passes after
  redeploy" is satisfied with a recorded exception: this dispatch carried a `## Batch Gate
  Deferral` directive (multi-task `/orchestrate` batch), so the SCOPED check attributed to this
  dispatch (`--only-gate 3,4` plus the measured suite subset) passed cleanly, while
  `deploy-headless.sh`'s own unavoidable built-in post-deploy call separately exited 3 on two
  confirmed pre-existing, unrelated findings (a gate10 wrapper-timeout flake that passes
  standalone, and the dead-command-recommendation lint's 2 pre-existing `/ide` findings in the
  memory extension).

## Verification

- Build: N/A (meta task)
- Tests: Passed — `scripts/tests/test-validate-artifact.sh` (50 passed, 0 failed) from both the
  source store and the deployed tree; the measured covering-suite subset for every phase passed;
  `shellcheck` reports no new findings on either edited script.
- Files verified: Yes — all three edited files confirmed byte-identical between source store and
  deployed tree.

## Impacts

- A plan author following the suite-subset bullet in a deploy-target repository is now handed a
  resolvable entry point instead of a dead path.
- A Tier Justification naming a suite subset or the `__FULL_SWEEP__` sentinel is now mechanically
  checked against the selector's actual output (advisory by default, enforced under `--strict`),
  closing the gap that let defect 2's false claim go unnoticed.
- The corpus-wide residue (5 of 11 non-terminal plan-linked tasks) establishes the baseline a
  future task will use to decide promotion to an error-level check.

## Follow-ups

- A future task should re-sweep the active-plan corpus and promote the Tier Justification
  measurement warning to an error once the residue reaches zero, per the promotion criterion
  recorded in `plan-format.md`'s new enforcement-level subsection.
- `agent-system/extensions/core/index-entries.json`'s line-count regeneration (a routine
  `deploy-headless.sh` byproduct touching entries beyond this task's own three files, shared with
  concurrent sibling tasks' in-flight edits) was correctly dropped from this task's phase commits
  by the commit wrapper's containment check and remains uncommitted in the working tree for
  whichever task's scope actually covers it.

## References

- `specs/493_plan_format_tier_justification_fixes/reports/01_tier-justification-fixes.md`
- `specs/493_plan_format_tier_justification_fixes/plans/01_tier-justification-fixes.md`
- `agent-system/extensions/core/context/formats/plan-format.md`
- `agent-system/extensions/core/scripts/validate-artifact.sh`
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
