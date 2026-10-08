# Implementation Summary: Task #358

- **Task**: 358 - Require rederivation of carried figures in artifacts
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T08:50:18Z
- **Completed**: 2026-10-07T10:45:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_carried-figure-authoring-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed a forward-looking authoring contract requiring that a figure or mechanical claim carried
into a new report or plan from another record be re-derived at authoring time, or else marked
`CARRIED-UNVERIFIED` with its source named. The contract is stated in full, once, in
`report-format.md`'s new `## Carried-Figure Discipline` section; `plan-format.md` points at it
from its existing `### Counts-are-hypotheses obligation` subsection rather than duplicating the
normative text. A narrowly scoped mechanical detector for the internal-consistency sub-class was
measured rather than assumed buildable, and the measurement said no: the gate failed on all
three pre-stated criteria (RECALL, PRECISION, BOUNDEDNESS), so Phase 5 closed as
`[COMPLETED WITH EXCLUSIONS]` with a full `#### Reasoned Exclusions` record rather than forcing a
brittle check into existence.

## What Changed

- `agent-system/extensions/core/context/formats/report-format.md` — added one new
  `## Carried-Figure Discipline` section (between `## Writing Guidance` and
  `## Example Skeleton`) carrying the full contract: the definition, the six-class trigger, the
  out-of-scope exclusion for interpretive claims, the literal `CARRIED-UNVERIFIED` mark form
  with required source naming, per-trigger-class re-derivation guidance, the internal-consistency
  reasoned-infeasibility finding plus reviewer prompt, the enforcement-level statement, and the
  placement record naming both rejected alternatives (a new standalone document; duplicating the
  rule in both format files). Added one cross-reference bullet to the existing
  `## Writing Guidance` list. Zero lines removed.
- `agent-system/extensions/core/context/formats/plan-format.md` — appended one paragraph inside
  `### Counts-are-hypotheses obligation` (before the existing harvest-source note) ruling that a
  carried figure is a different object from the plan's own forward-looking Scope Hypothesis,
  pointing at `report-format.md`'s contract, naming the `**Scope Hypothesis**:` discharge path
  and its two naming conditions, and stating the at-least-as-strict ruling (a plan is held at
  least as strictly as a report because its figures drive execution). Zero lines removed.
- No script was added or modified. Phase 4's throwaway probe lived only in the session
  scratchpad and was never committed.
- `specs/358_require_rederivation_of_carried_figures_in_artifacts/plans/01_carried-figure-authoring-contract.md`
  — all six phases checked off with completion annotations; Phase 5 heading rewritten to
  `[COMPLETED WITH EXCLUSIONS]` with its `#### Reasoned Exclusions` record.

## Decisions

- Item 1 (placement): asymmetric — `report-format.md` states the contract fully because a
  report's entire purpose is producing freshly-derived facts, where the measured failures
  cluster; `plan-format.md` points rather than restates, so the two documents cannot drift apart.
- Item 2 (trigger): six classes in scope — numeric count/measurement, command output or its
  characterization, file/line citation, pass/fail/exit-status/gate-outcome claim, "N of M" ratio,
  and a qualitative claim about mechanical/system/environmental state (reachability, capacity,
  availability, a hard always/never/cannot/required). Purely interpretive or evaluative claims
  (recommendations, priority rankings, design preferences, quality assessments) are explicitly
  out of scope because they are not falsifiable by re-measurement.
- Item 3 (the mark): the literal fixed-case token `CARRIED-UNVERIFIED`, inline, in the form
  `{figure or claim} [CARRIED-UNVERIFIED: {source path or record identifier}]`; naming the
  source is REQUIRED, not optional.
- Item 4 (internal-consistency feasibility): MEASURED INFEASIBLE for the narrow mechanical
  check. See Measured Evidence below for the full RECALL/PRECISION/BOUNDEDNESS numbers. The
  honest-infeasibility-plus-reviewer-prompt answer (already written into `report-format.md` by
  Phase 2) is the complete, sanctioned answer for this scope item; no detector shipped.

## Measured Evidence

All four sub-classes named in the task description were re-derived (not merely re-cited) in
Phase 1, against the Logos/Verification consumer repository and this repository's own format
documents:

1. **False-positive grep sub-class**: `grep -rln '^module' components/framed_channel/lean`
   matched 9 files; `find components/framed_channel/lean -name '*.lean' | wc -l` = 42 files;
   every one of the 9 matched lines is wrapped doc-comment prose, confirmed by direct inspection
   of each line's content (none is a real Lean `module` declaration); an exact-line test
   (`grep -rlx 'module' ...`) matched 0 files. No divergence from the carried figures.
2. **Prediction-carried-as-fact sub-class**: the Logos/Verification repo's
   `specs/229_handle_certify_exit3_as_indeterminate/issues.jsonl` entry `iss_1791359765610_QC89xy`
   quotes the measured outcome directly: "the plain run PASSed end to end (exit 0)". No
   divergence.
3. **Internally-impossible-assertion sub-class**: in that repo's
   `specs/229_handle_certify_exit3_as_indeterminate/plans/01_certify-exit3-indeterminate.md`
   (623 lines total), line 238 carries the mandated literal "no book was certified and none was
   refused"; lines 353-359 carry the fixture task's own deviation note explaining why the word
   "refused" cannot be banned because of that same literal. The task description's pointer to
   "lines 238 and 357" is confirmed accurate. No divergence.
4. **Self-reported-tally sub-class**: that repo's
   `specs/206_regenerate_stale_component_certificates/summaries/01_regenerate-framed-channel-recheck-summary.md`
   confirms the plan assumed a pre-edit baseline of "3 binding, 6 partially, 1 none yet" against
   a measured actual of "5 binding, 4 partially, 1 none yet" — matching the carried figure
   exactly. The page (`docs/records/architecture-decisions.md`) has since been corrected; a
   direct count of its current 10 `Validated by` markers measures 6 binding / 3 partially / 1
   none yet, consistent with the page's own stated tally and the summary's recorded post-edit
   value. Divergence noted and attributed as instructed (page has changed since the carried
   figure was authored).

Both amendment-site anchors were re-measured rather than trusted: `report-format.md` is 88 lines
(pre-change) with `## Writing Guidance` at line 32 and `## Example Skeleton` at line 41;
`plan-format.md` is 599 lines (pre-change) with `### Counts-are-hypotheses obligation` at line
299 — both exact matches to the carried figures, and both files confirmed unmodified by any
sibling at measurement time. Pre-change format-document count: 16 (confirmed, matching the
carried hypothesis).

**Phase 4 decision-gate measurement** (the hardest scope item): a throwaway probe implementing
the plan's exact specified ERE
(`(assert|require|check|verif)[^.]{0,60}(absence|absent|no occurrence|does not (appear|contain)|not present)`)
was run, unmodified, against the one known positive and against this repository's own corpus:

- RECALL: **FAIL**. The known positive's actual trigger line ("assert it does **not** contain
  REFUSE or the word \"refused\"") is split by markdown bold emphasis (`**not**`), which breaks
  the literal `does not (appear|contain)` substring match. The probe instead flagged an
  unrelated, non-contradictory incidental duplicate — the backtick literal `` `[REFUSE]` ``
  appearing on two different lines of the same file, which is the same tag mentioned twice
  consistently, not a contradiction.
- PRECISION: **FAIL**. Corpus = 2711 files under `specs/**/plans/*.md` and
  `specs/**/reports/*.md`. Flagged (HITS>0) = 92 files. A 12-file hand-inspected sample of the
  flagged set found 0 genuine contradictions — every sampled hit was the same short literal (a
  filename, a command name, a common word) simply quoted more than once in ordinary technical
  prose.
- BOUNDEDNESS: **FAIL**. 92 flagged files vastly exceeds the pre-stated 5-file threshold ("an
  advisory nobody can triage is noise, not a check").

All three criteria failed; the gate decision is **FAIL**. Full numbers recorded in
`progress/phase-4-progress.json`'s `measured_values` block.

## Plan Deviations

- **Phase 5** altered: the gate-PASSED task list (add the narrow check to
  `validate-artifact.sh`, update the Enforcement-level paragraph) was not executed. Reason:
  Phase 4's measured gate outcome was FAIL on all three criteria, and the plan's own pre-written
  contingency clause directs closing Phase 5 as `[COMPLETED WITH EXCLUSIONS]` with a
  `#### Reasoned Exclusions` record instead — which is what happened. This was the plan's own
  pre-stated contingency, not an improvised deviation.
- No other deviations. Every other phase's task list was executed as planned.

## Verification

- Build: N/A (markdown-only change; no script shipped)
- Tests: N/A (no script shipped; Phase 4's probe was a throwaway measurement tool, deliberately
  not committed)
- Files verified: Yes — `validate-artifact.sh` PASS (0 warnings) on both this plan and the
  research report; `check-task-references.sh` PASS (0 occurrences) on both amended format
  documents; zero removed lines confirmed by `git diff | grep -c '^-[^-]'` = 0 on both files; net
  format-document count confirmed unchanged at 16.

## Acceptance Criteria Walk-Through

- **Four sub-classes re-confirmed or corrected**: done in Phase 1 — see Measured Evidence above;
  zero divergences, one page-staleness note correctly attributed.
- **Contract stated per the placement ruling, rejected option recorded**: done — `report-format.md`'s
  `## Carried-Figure Discipline` section's own `**Placement record**` paragraph names both
  rejected alternatives (new standalone document; duplicating the rule in both files) and why.
- **Trigger precise enough to apply to a concrete sentence**: demonstrated on two sentences from
  this task's own plan. IN-SCOPE: "`grep -rln '^module' components/framed_channel/lean` matched
  9 files... and the directory holds 42 `.lean` files" is trigger classes (1) numeric count and
  (2) command-output characterization — correctly marked `CARRIED-UNVERIFIED` with source named.
  OUT-OF-SCOPE: the Risk-table entry "`CARRIED-UNVERIFIED` becomes a blanket escape hatch, used
  in place of ever re-deriving" is a predictive design/behavior judgment, not falsifiable by
  re-measurement — excluded by the interpretive/evaluative-claim carve-out.
- **Mark specified and greppable**: `grep -rn 'CARRIED-UNVERIFIED' specs/358_require_rederivation_of_carried_figures_in_artifacts/`
  locates every mark in this task's own artifacts; all three live marks (in the plan) name a
  source record.
- **Internal-consistency item answered**: Phase 4 measured the narrow detector infeasible on all
  three criteria; Phase 5 closed with a full `#### Reasoned Exclusions` record citing the
  measured numbers; `report-format.md`'s reasoned-infeasibility finding plus reviewer prompt
  (landed in Phase 2) stands as the complete answer, unchanged.
- **Net document count unchanged; nothing weakened**: both confirmed by direct measurement in
  Phase 6 (16 files; 0 removed lines across both amended documents).

## Impacts

- Future `/research` and `/plan` dispatches now have an explicit, checkable obligation (and a
  greppable escape hatch) for figures carried from a prior record, closing the gap the task
  description's four measured consumer-repo failures all trace back to.
- The repo-local half (a mechanical-derivation gate inside the Logos/Verification consumer repo's
  own decision records) remains explicitly out of this task's scope, per its own description —
  not implemented here.
- `verify-deploy.sh --findings` now reports two new, expected, self-caused findings (an
  `index-entries.json` line_count mismatch and a deploy-content-drift entry for both amended
  format documents) that resolve automatically on the orchestrator's next inter-cycle redeploy;
  no action was taken on them in this dispatch, per the plan's own non-goal against running
  `deploy-headless.sh` mid-cycle.

## Follow-ups

- None required by this task. A future task could reconsider the narrow internal-consistency
  detector if the markdown-bold-interruption and quoted-literal-duplication false-positive modes
  measured in Phase 4 were addressed by a different detection strategy — but that is explicitly
  not required here, and the reviewer-prompt answer already in `report-format.md` is a complete
  answer on its own.
- A later task may build the still-not-built validation that every `CARRIED-UNVERIFIED` mark
  names a source (named as a future item in `report-format.md`'s own Enforcement-level
  paragraph, unchanged by this task since no detector shipped).

## References

- Plan: `specs/358_require_rederivation_of_carried_figures_in_artifacts/plans/01_carried-figure-authoring-contract.md`
- Research report: `specs/358_require_rederivation_of_carried_figures_in_artifacts/reports/01_carried-figure-authoring-contract.md`
- Progress files: `specs/358_require_rederivation_of_carried_figures_in_artifacts/progress/phase-{1..6}-progress.json`
- Amended format documents:
  `agent-system/extensions/core/context/formats/report-format.md`,
  `agent-system/extensions/core/context/formats/plan-format.md`
