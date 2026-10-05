# Implementation Plan: Task #339

- **Task**: 339 - Record the tabular-presentation convention in the typst extension context
- **Status**: [IMPLEMENTING]
- **Effort**: 0.75 hours
- **Dependencies**: None (prose prerequisite: the upstream Verification-repo ruling, confirmed present at research time)
- **Research Inputs**: specs/339_typst_tabular_presentation_convention/reports/01_tabular-presentation-convention.md
- **Artifacts**: plans/01_tabular-presentation-convention.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The three substantive work items this task names were already written and committed by the
research dispatch (`7af9640c9`, "task 339: record tabular-presentation convention in typst
extension context", 64 insertions across exactly the two target context files). This plan
therefore does not re-author that material: it audits the landed additions against the dispatch's
own acceptance criteria, then closes the one mechanical gap the research dispatch left behind —
the typst extension's `index-entries.json` still declares the pre-edit line counts for both files
it changed. Two phases, both small, the second gated on the first.

### Research Integration

Key findings carried forward from the research report:

- The upstream ruling exists and is fully worked out in
  `~/Projects/Logos/Verification/typst/manual/template.typ` (`obligation-list`/`data-table`/
  `data-list` plus a "Convention ruling" comment); the convention was transcribed from it, not
  invented. That repo is read-only input and nothing in it was or will be touched.
- Work item (1) landed as a new `## Pagination and Element Choice` section in
  `patterns/tables-and-figures.md` (figure non-breakability; the
  `#show figure.where(kind: table): set block(breakable: true)` mechanism and the top-level
  placement requirement; header-repeat and caption-position as explicitly settled decisions).
- Work item (2) landed as a new `### Tabular / Key-Value Data` Per-Element Semantics entry in
  `standards/semantic-element-usage.md`, following that file's existing three-subsection entry
  format and stating that the shape choice is orthogonal to the Universal Placement Rule.
- Work item (3) was ruled on explicitly rather than skipped: a `### Mechanical Check: Not Added`
  subsection records the decision not to extend `typst-element-lint.sh`, with the reason (the
  choice test is a rendering-dependent judgment, not a structural grep; no recurring real-corpus
  defect of this class observed yet). `typst-element-lint.sh` itself is correctly untouched.

Gap the research report did not cover, found during planning:
`.claude/scripts/generate-context-line-counts.sh --check` reports exactly two mismatches for the
typst extension — `tables-and-figures.md` declared 170 / actual 214, and
`semantic-element-usage.md` declared 281 / actual 301. Both are direct consequences of this
task's own edits, so repairing them belongs to this task.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Confirm, with evidence, that all three dispatch work items and all five acceptance criteria are
  satisfied by the landed material.
- Bring the typst `index-entries.json` `line_count` values for the two edited files back into
  agreement with the files themselves.

**Non-Goals**:
- Re-authoring, expanding, or restructuring the two landed additions. They are deliberately short
  and must not grow into a general formatting framework.
- Adding the mechanical lint check. The recorded ruling is "not added"; that ruling stands.
- Redeploying the `.claude/` tree. The source edits make the deployed typst copy stale, but a
  redeploy is an operator-run system action and writing under `.claude/**` is explicitly out of
  scope here. Recorded as a follow-up instead.
- Any file in `~/Projects/Logos/Verification`, the thmbox/theorem guidance, the fletcher diagram
  patterns, or `standards/chapter-quality.md` / `chapter-quality-check.sh`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `generate-context-line-counts.sh --write` rewrites `line_count` for every extension, not just typst — including the books extension a concurrent sibling task owns | M | H | Do not use `--write`. Edit only the two typst entries surgically, then use `--check` (grepped to typst) as the verifier. |
| The audit finds a landed addition does not actually meet a work item, re-opening authoring work this plan assumes is done | M | L | Phase 1 is a real audit, not a rubber stamp: if it finds a genuine shortfall, record it and extend Phase 2 to fix that file rather than closing the gate. |
| Staging picks up a concurrent sibling's edits under `agent-system/extensions/books/**` | M | M | Stage only the one explicitly named file path; never a directory or glob pathspec. Re-read the file immediately before editing. |
| The two additions are read later as a general framework and expanded | L | M | Both files' new material is scoped to one ruling and cross-references the other rather than duplicating it; nothing in this plan adds surface area. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Audit the Landed Additions Against the Acceptance Criteria [COMPLETED]

**Goal**: Establish, with concrete evidence rather than assumption, that the three work items and
the five acceptance criteria are satisfied by what is already committed — and surface any shortfall
before the gate closes.

**Tasks**:
- [x] Read `agent-system/extensions/typst/context/project/typst/patterns/tables-and-figures.md`'s
      `## Pagination and Element Choice` section and confirm it states all three required points:
      a figure-wrapped grid does not break across pages; the mechanism for making one breakable;
      and header-repeat plus caption-position as decisions to settle rather than inherit.
      *(completed: all three points confirmed present)*
- [x] Read `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`'s
      `### Tabular / Key-Value Data` entry and confirm it (a) states the description-list-vs-grid
      choice rule, (b) uses the same three-subsection shape as the Definition / `rule-list`
      entries, and (c) is consistent with the Universal Placement Rule rather than carving an
      exception out of it. *(completed: all three sub-checks confirmed)*
- [x] Confirm the `### Mechanical Check: Not Added` subsection records a ruling *with a reason*,
      and that `agent-system/extensions/typst/scripts/typst-element-lint.sh` is unmodified by this
      task (`git log --oneline -- <script>` shows no commit from this task).
      *(completed: ruling with reason present; script untouched by commit 7af9640c9)*
- [x] Confirm the task's commit touched only the two context files:
      `git show --stat 7af9640c9` — no `.claude/**` path, no path outside
      `agent-system/extensions/typst/context/project/typst/`.
      *(completed: 2 files changed, 64 insertions(+), both under the expected path)*
- [x] Confirm nothing in `~/Projects/Logos/Verification` was modified by this task
      (`git -C ~/Projects/Logos/Verification status --short`, read-only check only — do not
      stage, commit, or alter anything there). *(completed: pre-existing unrelated dirty state
      only; nothing touched by this task, which performed read-only checks there)*
- [x] Confirm the additions document one ruling and did not become a framework: the combined
      diff is ~64 inserted lines across two files; flag it if that has grown materially.
      *(completed: exactly 64 lines, confirmed, no growth)*
- [x] Record any shortfall found as an issue via `issue-record.sh` and carry it into Phase 2's
      task list rather than closing the gate over it. *(completed: no shortfall found, nothing
      to record)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the audit finds no shortfall — that all three work items
are already fully satisfied by commit `7af9640c9`. That is a hypothesis from planning-time reads,
not a fact. The implementer confirms it by actually performing each check above; a failed check
means Phase 2 gains authoring work, not that the check was wrong.

**Files to modify**:
- None. This phase is read-only verification.

**Verification**:
- Each of the six checks above produces an explicit pass/fail note, not a blanket "looks fine".
- No file is modified during this phase (`git status --short` unchanged from its starting state
  apart from this task's own `specs/**` artifacts).

---

### Phase 2: Repair the Stale typst index-entries.json Line Counts [COMPLETED]

**Goal**: Make the typst extension's context index agree with the two files this task changed, so
the context-budget tooling reports accurate sizes, and commit the repair.

**Tasks**:
- [x] Re-read `agent-system/extensions/typst/index-entries.json` immediately before editing (a
      concurrent sibling task is live on this same working tree). *(completed)*
- [x] Recompute both actual counts with `wc -l` rather than trusting this plan's numbers, then
      update exactly two values: the `line_count` on the entry whose `path` is
      `project/typst/patterns/tables-and-figures.md`, and the one on
      `project/typst/standards/semantic-element-usage.md`. *(completed: 170->214, 281->301,
      matching planning-time measurement exactly)*
- [x] Leave every other field and every other entry in that file byte-identical; do not run
      `generate-context-line-counts.sh --write` (it rewrites all extensions, including one a
      sibling task owns) and do not round-trip the file through `jq`. *(completed: surgical Edit
      tool replacement only; git diff shows exactly 2 changed lines)*
- [x] Apply any shortfall fix carried over from Phase 1, if one was found. *(completed: no
      shortfall was found, nothing to apply)*
- [x] Run the acceptance gates: `generate-context-line-counts.sh --check` (typst must report
      `0 mismatch`), `check-task-references.sh` (must PASS), and the extension doc check for
      typst. *(completed: typst 0 mismatch; check-task-references.sh PASS; check-extension-docs.sh
      typst PASS)*
- [x] Stage only `agent-system/extensions/typst/index-entries.json` (plus any Phase 1 carry-over
      file) by explicit path — never `git add -A`, never a directory or glob pathspec — review
      `git diff --staged`, and commit via `git-commit-scoped.sh`. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts exactly two `line_count` values need changing, and that
no other typst index entry is stale. Confirm with
`bash .claude/scripts/generate-context-line-counts.sh --check 2>&1 | grep typst` before editing —
if it reports more than those two typst mismatches, the extra ones are not this task's doing and
should be reported, not silently absorbed.

**Files to modify**:
- `agent-system/extensions/typst/index-entries.json` - two `line_count` values corrected to the
  freshly measured actuals (planning-time measurement: 170 -> 214 and 281 -> 301).

**Verification**:
- `bash .claude/scripts/generate-context-line-counts.sh --check 2>&1 | grep typst` reports
  `0 mismatch, 0 null, 0 missing source` for typst.
- `git diff` on `index-entries.json` shows exactly two changed lines, both `line_count`.
- `bash .claude/scripts/check-task-references.sh` reports PASS.
- The extension doc check passes for typst.
- `git show --stat HEAD` on the new commit lists only the intended path(s) — no `.claude/**`, no
  `agent-system/extensions/books/**`.

---

## Testing & Validation

- [ ] Both target context files carry the new material, each in its own existing format and voice.
- [ ] An explicit recorded ruling on the `typst-element-lint.sh` question exists, with a reason.
- [ ] No file under any deployed `.claude/` tree was edited by this task.
- [ ] No file in `~/Projects/Logos/Verification` was edited by this task.
- [ ] The additions document one ruling; no general formatting framework was built.
- [ ] `generate-context-line-counts.sh --check` reports no typst mismatch.
- [ ] `check-task-references.sh` passes (no task-number references outside `specs/**`).

## Artifacts & Outputs

- `agent-system/extensions/typst/context/project/typst/patterns/tables-and-figures.md` (already
  modified, audited by this plan)
- `agent-system/extensions/typst/context/project/typst/standards/semantic-element-usage.md`
  (already modified, audited by this plan)
- `agent-system/extensions/typst/index-entries.json` (two `line_count` values repaired)
- `specs/339_typst_tabular_presentation_convention/summaries/01_*-summary.md` (implementation
  summary)

## Follow-ups (not in scope here)

- The deployed `.claude/` typst context copy is now behind the source store. The sanctioned remedy
  is an operator-run `bash .claude/scripts/deploy-headless.sh`; hand-patching under `.claude/**`
  is explicitly not a substitute and is out of scope for this task.

## Rollback/Contingency

Phase 1 is read-only and needs no rollback. Phase 2 changes two values in one JSON file: revert it
with `git revert` of that phase's commit, or `git checkout HEAD -- agent-system/extensions/typst/index-entries.json`
before it is committed (tree must be clean for that path, or take a
`bash .claude/scripts/git-snapshot.sh 339 --no-revert` checkpoint first). The already-landed
context additions are a separate, earlier commit and are not touched by any rollback of this plan.
