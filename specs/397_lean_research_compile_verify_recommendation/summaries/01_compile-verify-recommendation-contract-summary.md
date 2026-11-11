# Implementation Summary: Task #397

- **Task**: 397 - lean research compile-verify recommendation contract
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T00:00:00Z
- **Completed**: 2026-11-11T00:20:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_compile-verify-recommendation-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added an always-on "Compile-Verify-Before-Recommend" contract clause to the lean research
agent's constraint section, and the matching `[VERIFIED: ...]` / `[No compiled gate applicable]`
evidence tag to both copies of the research-report skeleton, so a recommendation naming a
concrete artifact whose acceptance an existing compiled gate decides must carry a measured
PASS/FAIL result before it is written up. The edit is prose-only (no tool-grant change, no new
script, no hook), landed in the lean extension's source store, and was followed by an
`index-entries.json` `line_count` correction and a redeploy.

## What Changed

- `agent-system/extensions/lean/agents/lean-research-agent.md` — new
  `### Compile-Verify-Before-Recommend` subsection (trigger, worked examples, REQUIRED/FORBIDDEN
  lists, FAIL obligation, rejected-trigger record) placed between Zero-Debt Policy Compliance and
  Literature Extraction Protocol; the Stage 1 `### Recommendations` report skeleton gained the
  three-tag convention plus a following note; two new `## Critical Requirements` entries (MUST
  DO 12, MUST NOT 16 — the pre-existing MUST NOT item for `.orchestrator-handoff.json` was
  renumbered 16 -> 17 to avoid a duplicate number).
- `agent-system/extensions/lean/context/project/lean4/agents/lean-research-flow.md` — a
  cross-reference paragraph before Stage 5 pointing at the new clause, and the Stage 5
  `## Recommendations` skeleton gained the same three-tag convention plus a note. File grew
  186 -> 196 lines.
- `agent-system/extensions/lean/index-entries.json` — corrected the
  `project/lean4/agents/lean-research-flow.md` entry's `line_count` from 186 to 196 (the only
  line changed in the file).
- Regenerated `.claude/` deploy tree via `deploy-headless.sh` (disposable, not committed).

## Decisions

- Trigger **(a)** adopted unchanged from the research report: both conjuncts (concrete artifact
  named + existing compiled gate decides acceptance) must hold. Triggers (b) ("any bounded
  mechanical check") and (c) ("only the primary recommendation") were rejected, with reasons
  recorded directly in the contract text itself (not only in the report), mirroring how the
  Zero-Debt section states its FORBIDDEN list in place.
- Placement is always-on in `lean-research-agent.md`, not hard-mode-only: no `-hard`-suffixed
  agent file exists in this extension (confirmed by directory listing before any edit), so a
  hard-mode-only placement would not have caught the cited failure, which occurred in a standard
  dispatch.
- `agents/lean-research-hard-agent.md` was dropped from the plan's file scope after the premise
  re-validation found it does not exist; no such file was created.

## Plan Deviations

- **Task 4.4** (Phase 4, "Run the complete gate set: `verify-deploy.sh`") altered: per the
  dispatch file's Batch Gate Deferral directive, Phase 4 was discharged against a scoped tier
  instead of an independent full-gate run — `verify-deploy.sh --skip-slow --only-gate 3,4` PASS,
  the five `index-entries.json`-covering suites PASS, and `generate-context-line-counts.sh
  --check`'s `lean:` census reporting 0 mismatch. The full unscoped gate set runs once for the
  whole batch at the end of the invocation; it is deferred, never forgiven.

## Verification

- Build: N/A (prose/JSON-only change)
- Tests: Passed — gates 3/4 pass on every markdown phase; the five `index-entries.json`-covering
  suites pass after Phase 3; `generate-context-line-counts.sh --check`'s `lean:` line reports
  `45 entries, 45 exact, 0 mismatch, 0 null, 0 missing source`; both deployed copies carry the
  clause (4 and 2 grep occurrences respectively) after redeploy.
- Files verified: Yes

## Impacts

- Future lean research reports must tag every recommendation with one of
  `[VERIFIED: PASS -- ...]`, `[VERIFIED: FAIL -- ...; revised to: ...]`, or
  `[No compiled gate applicable]`, closing the gap that let an uncheckable "land this artifact"
  recommendation reach plan time before its compiled gate was run.
- The two report skeletons (`lean-research-agent.md` Stage 1, `lean-research-flow.md` Stage 5)
  now share the identical tag convention, with the flow file cross-referencing the agent file's
  authoritative clause rather than duplicating it — closing the drift the research report
  measured between the two.

## Follow-ups

- None. (The report's deferred Context Extension Recommendation — a `hard-mode.md` pointer
  paragraph — is explicitly out of scope for this task.)

## References

- `specs/397_lean_research_compile_verify_recommendation/reports/01_compile-verify-recommendation-contract.md`
- `specs/397_lean_research_compile_verify_recommendation/plans/01_compile-verify-recommendation-contract.md`
- `specs/397_lean_research_compile_verify_recommendation/.dispatch/8.md`
