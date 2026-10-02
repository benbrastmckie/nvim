# Implementation Summary: Task #315

- **Task**: 315 - Stop `orchestrate-cycle-postflight.sh` reporting an outcome it did not persist, and make its `HANDOFF_STALE_OR_ABSENT` attribution depend on the DIRECTION of a dispatch_seq mismatch
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T14:37:00Z
- **Completed**: 2026-10-02T15:03:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_postflight-attribution-and-status.md
- **Standards**: plan-format.md, status-markers.md, artifact-formats.md, source-store-deploy-boundary.md, shell-strict-mode.md, git-workflow.md

## Overview

Both independent honesty defects from the originating incident are fixed. Deliverable 1 makes
the `dispatch_seq`-mismatch arm in `orchestrate-cycle-postflight.sh` direction-aware: a handoff
newer than the cycle's minted seq is now attributed to `orchestrate-cycle-plan.sh` (the sole
minting site — a composition/minting-side authoring fault) instead of
`skill-orchestrate/SKILL.md`, while the older direction (a still-live predecessor's late write)
keeps its existing attribution byte-for-byte. The three-way documented inconsistency across the
script, `commands/orchestrate.md`, and `orchestrate-state-machine.md` is reconciled, plus a
fourth adjacent inconsistency found in `system-defect-discrimination.md`. Deliverable 2 adds an
additive `persisted_status` field to the emitted postflight JSON — `state.json`'s actual current
status, read fresh at emit time — so a consumer can distinguish "what the agent reported" from
"what this script actually persisted," without disturbing `.status`'s existing semantics or the
`user_decision` relay that depends on it.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — direction-aware
  `dispatch_seq`-mismatch attribution (branch-local `seq_direction`/`mismatch_attributed_path`/
  `mismatch_site`/`mismatch_detail`, guarded against non-numeric input); enriched ERROR and
  dry-run notices naming the direction; new unconditional `persisted_status` read before the
  emit fork, added to both `jq -n` emit blocks; output-schema docstring and RECOVERY_DECLINED
  comment updated to document the `status`/`persisted_status` distinction.
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` — new case 5
  (newer-than-minted direction) with an attribution assertion proven non-vacuous against the
  pre-fix script; case 2 gained a non-regression attribution assertion; `run_case` extended with
  an optional `EXPECT_ATTRIBUTION` parameter; header/negative-control notes updated.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — Acceptance
  (4b) extended with older-direction attribution assertions; new Acceptance (4c) for the
  newer-direction live `detected_defects` row (proven non-vacuous against the pre-fix script);
  Acceptance (5) gained the `persisted_status`-diverges-from-`status` assertion; Acceptance (4a)
  gained an else-block `persisted_status` presence assertion; the existing `--dry-run` invariant
  block gained a `persisted_status`-unchanged assertion; new Acceptance (5b) for the `"unknown"`
  fallback on an absent task row.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 3 destructures
  `persisted_status`; diagnostic echo shows both status fields; new contract-text paragraph
  states which field means what.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — mirrored Move 3
  snippet updated identically; the "not a bug" exoneration at the unwind-replay scenario narrowed
  to the direction it actually covers (older), with the newer direction's different attribution
  named explicitly.
- `agent-system/extensions/core/commands/orchestrate.md` — corrected the existing example row's
  Attributed Source Path/Detecting Site to match the mtime arm's actual code; added a second
  example row for the newer direction; added an explanatory paragraph distinguishing the two
  rows as directions of the same check.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — added a
  clarifying paragraph distinguishing the registry's "Location" column (where the check lives)
  from `attributed_path` (who is blamed), naming the new direction split.

## Decisions

- D1 (newer direction attributes to `orchestrate-cycle-plan.sh`), D2 (no `defect_class`
  vocabulary churn), D3 (additive `persisted_status` field, not a `.status` swap), and D4 (the
  `persisted_status` read is a separate, unconditional read — not a refactor of the existing
  multi-task-only `fresh_status` read) were all adopted from the research report as planned, with
  no deviation.
- The research's proposed test-assertion mechanism (reading `.detected_defects[-1]` inside
  `test-handoff-dispatch-identity.sh`) was corrected during planning: every case in that suite
  runs `--dry-run`, under which the SUT's defect-recording calls never execute, so no row ever
  exists there to assert against. Coverage was split as planned: the dry-run suite asserts the
  enriched stderr notice (Phase 2), and the live suite's Acceptance (4b)/(4c) assert the actual
  recorded row (Phase 3). Both non-vacuity proofs (case 5 and Acceptance 4c) were independently
  verified by running the new assertions against the pre-fix script via scratch copies, confirming
  they fail pre-fix and pass post-fix.

## Plan Deviations

- None (implementation followed plan). The only adjustments were line-number re-reads
  before each edit (plan-documented line numbers shifted after Phase 1's insertion), which the
  plan itself anticipated and which were handled per its own "re-read immediately before editing"
  instructions.

## Verification

- Build: N/A (shell scripts and markdown only)
- Tests:
  - `test-handoff-dispatch-identity.sh`: 13 passed, 0 failed (5 cases, up from 4)
  - `test-orchestrate-cycle-postflight.sh`: 142 passed, 0 failed (up from 138)
  - `test-orchestrate-recover-message-findings.sh`: 23 passed, 0 failed (unchanged consumer,
    confirmed to need no edit)
- shellcheck: clean on all three edited shell files (zero new findings; all remaining notices
  pre-exist this task's edits — confirmed by diffing shellcheck output against the unedited
  baseline)
- Files verified: Yes

### Per-Criterion Acceptance Mapping

1. **Direction-aware attribution, distinguished in notice/row/dry-run line** —
   `orchestrate-cycle-postflight.sh:478-500` (`seq_direction` computation, branch-local
   `mismatch_attributed_path`/`mismatch_site`/`mismatch_detail`, direction-named ERROR and
   dry-run notices).
2. **New non-vacuous case covering the newer direction** —
   `test-handoff-dispatch-identity.sh:256-261` (case 5); non-vacuity proven via a scratch copy
   pointed at the pre-fix script (2 of its 4 new assertions failed pre-fix, including the
   attribution assertion).
3. **Four existing cases keep current behaviour, case 2 especially** — full suite run:
   13 passed, 0 failed, including case 2's original accept/reject + stderr-grep assertions
   unchanged, now with an added (and passing) attribution assertion.
4. **`.status` never implies an unperformed transition** —
   `orchestrate-cycle-postflight.sh:1430-1442` (unconditional `persisted_status` read) plus both
   `jq -n` emit blocks at the final-output site; manual `--dry-run` invocation confirmed valid
   JSON with both fields present and able to diverge.
5. **SKILL.md Move 3 updated in the same change, contract text states meaning** —
   `skill-orchestrate/SKILL.md:192,197,237-245`.
6. **`user_decision` relay at the agent-reported status still works, verified not assumed** —
   `test-orchestrate-cycle-postflight.sh` Acceptance (5)'s pre-existing `.status == "partial"`
   assertion, confirmed textually unchanged via `git diff` context-line inspection, still passing
   in the full suite run.
7. **Docs agree with code; "not a bug" narrowed to the direction it covers** —
   `commands/orchestrate.md:309-317` (corrected row + new row + explanatory paragraph);
   `orchestrate-state-machine.md` unwind-replay scenario (narrowing clause appended, preceding
   narrative untouched); `system-defect-discrimination.md` (fourth inconsistency, clarifying
   paragraph added — not owned by any other live task's fenced region).
8. **Full suite green, shellcheck clean** — all three named suites green in one run on one tree
   (13/142/23, all 0 failed); shellcheck clean on all three edited shell files.

All eight acceptance criteria are fully demonstrated; none required exclusion.

## Impacts

- Any future operator reading a `HANDOFF_STALE_OR_ABSENT` defect row or notice can now tell from
  the attribution alone whether the fault is a stale predecessor artifact (SKILL.md's read-only
  role) or a minting-side composition bug (`orchestrate-cycle-plan.sh`).
- Any consumer of the postflight JSON (currently `skill-orchestrate/SKILL.md` Move 3 and its
  mirrored doc copy) can now read `persisted_status` when it needs the ground truth rather than
  the agent's self-report, without any change to existing `.status`-based logic.

## Follow-ups

- The research's Context Extension Recommendation (a reusable "attribute by direction of a
  monotonic mismatch" pattern writeup in `system-defect-discrimination.md`) remains a separate,
  optional task — only the one-line registry note from Phase 7 landed here, as scoped.
- No other `postflight_json` consumer was found beyond the two updated and the one confirmed
  unaffected (`test-orchestrate-recover-message-findings.sh`).

## References

- `specs/315_postflight_reports_only_what_it_persists/plans/01_postflight-attribution-and-status.md`
- `specs/315_postflight_reports_only_what_it_persists/reports/01_postflight-attribution-and-status.md`
- `.dispatch/14.md` (this implementation dispatch's originating context)
