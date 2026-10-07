# Implementation Plan: Carried-Figure Authoring Contract for Reports and Plans

- **Task**: 358 - Require rederivation of carried figures in artifacts
- **Status**: [IMPLEMENTING]
- **Effort**: 4.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/358_require_rederivation_of_carried_figures_in_artifacts/reports/01_carried-figure-authoring-contract.md
- **Artifacts**: plans/01_carried-figure-authoring-contract.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Land a forward-looking authoring contract requiring that a figure or mechanical claim copied
into a new report or plan from another record be re-derived at authoring time, or else marked
`CARRIED-UNVERIFIED` with its source named. The contract is stated in full, once, in
`report-format.md`; `plan-format.md` points at it from its existing
`### Counts-are-hypotheses obligation` subsection and rules on the plan-side strictness without
duplicating the normative text. Net format-document count is unchanged. A narrowly scoped
mechanical detector for the hardest sub-class (an assertion contradicting a literal the same
document mandates elsewhere) is put behind a measured decision gate rather than assumed
buildable: an honest, evidenced infeasibility finding plus the reviewer prompt is the sanctioned
alternative outcome, and the contingency branch is pre-written here.

### Research Integration

The research report settled all four scope items and surveyed the two amendment sites. Carried
into this plan from that report and used to shape it:

- Item 1 ruling: asymmetric placement — `report-format.md` states the contract fully,
  `plan-format.md` points. Rationale: a report's entire purpose is producing freshly-derived
  facts, and the measured failures cluster on report-shaped records.
- Item 2 ruling: the five dispatch-listed shapes plus a sixth, a qualitative claim about
  mechanical/system/environmental state — because the costliest measured sub-class (a prediction
  that a component gate was unreachable, later measured as exit 0) contains no number at all.
  Purely interpretive prose is explicitly excluded.
- Item 3 ruling: the literal fixed-case token `CARRIED-UNVERIFIED`, inline, source naming
  REQUIRED. Style borrowed from the existing bolded `VERIFIED`/`UNVERIFIED` family in
  `context/contracts/adversarial-verification.md`, without that file's hard-mode gating, since
  none of the measured failures were hard-mode-specific.
- Item 4 ruling: general contradiction detection infeasible; the narrow shape judged feasible.
  This plan does not inherit "feasible" as settled — Phase 4 measures it.
- Survey finding: neither format document currently carries any vocabulary for a figure's
  provenance. That is the gap being closed.

Figures carried from the report into this plan, not re-derived at plan-authoring time, are
marked below in the exact convention this plan asks the format documents to mandate — this plan
dogfoods its own contract:

- `grep -rln '^module' components/framed_channel/lean` matched 9 files, all wrapped doc-comment
  prose, and the directory holds 42 `.lean` files
  [CARRIED-UNVERIFIED: specs/358_require_rederivation_of_carried_figures_in_artifacts/reports/01_carried-figure-authoring-contract.md, Findings, sub-class (1)].
- The page-level tally mismatch was 3 binding / 6 partially / 1 none-yet (assumed) versus
  5 / 4 / 1 (measured), over ten markers
  [CARRIED-UNVERIFIED: specs/358_require_rederivation_of_carried_figures_in_artifacts/reports/01_carried-figure-authoring-contract.md, Findings, sub-class (4)].
- `report-format.md` is 88 lines with `## Writing Guidance` at line 32; `plan-format.md` is 599
  lines with `### Counts-are-hypotheses obligation` at line 299
  [CARRIED-UNVERIFIED: planner's own read of the two files during this planning dispatch, not
  re-read at implementation time — concurrent sibling tasks share this working tree].

Phase 1 discharges every mark above by re-deriving it; no mark above is expected to survive into
any deliverable.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this dispatch (no `roadmap_path` in the delegation context).

## Goals & Non-Goals

**Goals**:
- State a precise, checkable carried-figure trigger and a greppable mark for the
  unverified-and-carried escape hatch, in the two existing format documents.
- Rule explicitly on the plan-vs-report asymmetry and record the rejected placement options
  inside the surviving text, so the decision is not re-litigated later.
- Answer the internal-consistency feasibility question with a measurement, not an assertion, and
  land whichever of the two sanctioned answers the measurement supports.
- Leave the net format-document count unchanged and every existing requirement in both documents
  intact.

**Non-Goals**:
- No new format or contract document. Both amendments land inside the two existing files.
- No general-purpose fact-checker, claim-extraction pipeline, or general contradiction detector.
- No retroactive audit or amendment of existing reports and plans in any repository.
- No weakening or relaxation of any existing requirement in either format document.
- No gate, script, or file added under any consumer repository; the repo-local half is a
  separately filed task in that repository.
- No redeploy of `.claude/` from this dispatch (the orchestrator's inter-cycle redeploy
  checkpoint owns that, and a mid-cycle redeploy would publish concurrent siblings' in-flight
  source edits).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `CARRIED-UNVERIFIED` becomes a blanket escape hatch, used in place of ever re-deriving | M | M | Accepted by design per the task's own framing: the mark makes carried-and-unverified status visible and greppable rather than forbidding the carry. The section text states the obligation's purpose (never present a carried figure as freshly measured) so the hatch reads as a disclosure, not a waiver |
| The new section is read as requiring re-derivation of every number in a report, including fresh measurements | M | M | The trigger text scopes itself explicitly to figures copied from another record, and states that a figure the author measured in this session is not carried however often it is restated |
| A brittle narrow detector gets forced into existence to avoid answering "infeasible" | H | M | Phase 4 is a measured decision gate with pre-stated pass criteria including a recall test against the one known positive; the contingency branch (no detector, evidenced infeasibility finding) is pre-written and is a complete answer |
| A concurrent sibling task edits one of the two format documents between planning and implementation | M | L | Territory measurement found no non-terminal task declaring either file; Phase 1 re-reads both files immediately before editing and re-confirms the anchor line numbers rather than trusting this plan's carried ones |
| `verify-deploy.sh` findings in Phase 6 are caused by a sibling's in-flight source edits, not by this task | L | M | Phase 6 attributes every finding to a path and acts only on findings naming this task's own files; it does not run `deploy-headless.sh` |
| A task-number reference leaks into the amendment text | M | L | Phase 6 runs `check-task-references.sh`; the amendment text cites files, commands, and concepts only |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 3, 4, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-derive the Carried Evidence and Confirm the Amendment Anchors [COMPLETED]

**Goal**: Discharge every `CARRIED-UNVERIFIED` mark this plan carries, by re-deriving it, before
writing contract text that depends on it. Report any divergence rather than absorbing it.

**Tasks**:
- [x] Re-run, read-only, in `~/Projects/Logos/Verification`:
      `grep -rln '^module' components/framed_channel/lean | wc -l`,
      `grep -rn '^module' components/framed_channel/lean | head -20`, and
      `find components/framed_channel/lean -name '*.lean' | wc -l`. Record the three actual
      outputs verbatim. Confirm (or correct) that every matched line is wrapped doc-comment
      prose rather than a Lean `module` declaration, and that an exact-line test
      (`grep -rlx 'module' components/framed_channel/lean` or equivalent) matches none of them.
      *(completed: 9 files matched, all 9 confirmed wrapped doc-comment prose by direct
      inspection; 42 total .lean files; exact-line test matched 0 — no divergence)*
- [x] Re-confirm the prediction-carried-as-fact instance by direct citation: locate the
      `kind: win` / `class: environment-measurement-reversal` entry in that repo's
      `specs/229_handle_certify_exit3_as_indeterminate/issues.jsonl` and quote the measured
      outcome (gate passed, exit 0) from the entry itself, not from this plan or the report.
      *(completed: entry iss_1791359765610_QC89xy quotes "the plain run PASSed end to end
      (exit 0)" — no divergence)*
- [x] Re-confirm the internally-impossible-assertion instance by reading both halves in that
      repo's `specs/229_handle_certify_exit3_as_indeterminate/plans/01_certify-exit3-indeterminate.md`:
      the mandated message literal, and the fixture task item asserting absence of the word it
      contains. Record both line numbers as measured now (the task description's own pointer to
      lines 238 and 357 is itself a carried figure -- confirm or correct it).
      *(completed: line 238 carries the mandated literal "no book was certified and none was
      refused"; lines 353-359 carry the fixture's deviation note on the same contradiction —
      pointer confirmed accurate, file is 623 lines total — no divergence)*
- [x] Re-count the self-reported-tally instance: read the ten `Validated by` markers at the page
      the summary in that repo's `specs/206_regenerate_stale_component_certificates/` cites, and
      record the measured distribution. If the page has since changed, say so and cite the
      summary's own recorded measurement instead, labelled as such.
      *(completed: summary confirms plan-assumed 3/6/1 vs measured pre-edit 5/4/1 — matches
      carried figure exactly; page has since been corrected to 6 binding/3 partially/1 none-yet,
      confirmed by direct count of all 10 current markers and the page's own stated tally — no
      divergence, page-change noted per instructions)*
- [x] Re-read both amendment sites in THIS repository at their current state and record measured
      line numbers: `grep -n '^## \|^### ' agent-system/extensions/core/context/formats/report-format.md`
      and `grep -n '### Counts-are-hypotheses obligation' agent-system/extensions/core/context/formats/plan-format.md`.
      Confirm no sibling has modified either file (`git log --oneline -3 -- <both paths>` and
      `git status --short -- <both paths>`).
      *(completed: report-format.md 88 lines, `## Writing Guidance` at line 32, `## Example
      Skeleton` at line 41; plan-format.md 599 lines, `### Counts-are-hypotheses obligation` at
      line 299 — exact match to carried figures; `git status --short` clean on both files; net
      format-document count = 16, confirming Phase 6's carried hypothesis)*
- [x] Record every divergence found (and every confirmation) in the phase's progress notes, and
      file an `issue-record.sh` entry for any divergence with
      `--class research-defect --severity minor` (non-fatal if recording fails).
      *(completed: zero divergences found across all four sub-classes and both anchor
      measurements; recorded in progress/phase-1-progress.json; a `kind: win` issue-record.sh
      entry filed instead of a divergence entry)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this plan asserts, carried from the research report, that the grep matches
9 files in a directory of 42 `.lean` files, and that the tally mismatch is 3/6/1 versus 5/4/1
over ten markers. Both are hypotheses. Confirm by the commands in this phase's task list and
replace every carried number in the eventual summary with the measured one; a divergence is a
finding to report, not an error to hide.

**Files to modify**:
- none planned (read-only re-derivation; findings are recorded in progress notes and
  `issues.jsonl`)

**Verification**:
- Each of the four sub-classes has a recorded command (or exact citation) and its verbatim
  output or quoted text, produced during this phase and not copied from the report.
- The measured heading/anchor line numbers for both format documents are recorded, and both
  files are confirmed unmodified by any sibling.
- Divergences, if any, are stated explicitly alongside the carried value they replace.

---

### Phase 2: State the Carried-Figure Discipline in report-format.md [COMPLETED]

**Goal**: Add one new section to `report-format.md` carrying the full, authoritative contract:
the trigger, the mark, the re-derivation obligation, the internal-consistency reviewer prompt,
and the record of the rejected placement options.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/formats/report-format.md` in full
      immediately before editing (sibling concurrency). *(completed)*
- [x] Insert a new `## Carried-Figure Discipline` section immediately after `## Writing Guidance`
      and immediately before `## Example Skeleton`, so the rule is read before the skeleton a
      reader is about to copy. Content, substantively as follows (wording may be tightened, but
      every numbered element below must survive):
      - **Definition**: a figure or mechanical claim the report did not produce by its own
        measurement in this authoring session -- one copied or closely paraphrased from another
        record (a prior report, a prior plan version, another task's artifact, the task
        description, a session transcript) -- is a *carried figure*. Every carried figure must be
        either re-derived at authoring time or marked `CARRIED-UNVERIFIED` with its source named.
        State the purpose: presenting a carried figure as freshly measured is the defect;
        carrying one openly is not.
      - **In scope (the trigger)**, as a numbered list: (1) a numeric count or measurement;
        (2) the output of a command, or a characterization of what a command's output shows;
        (3) a file/line citation presented as locating specific content; (4) a pass/fail,
        exit-status, or gate-outcome claim; (5) an "N of M" ratio; (6) a qualitative claim about
        mechanical, system, or environmental state -- reachability, capacity, availability, or a
        hard "always" / "never" / "cannot" / "is required".
      - **Out of scope**: a purely interpretive or evaluative claim carried from another record
        (a recommendation, a priority ranking, a design preference, a quality assessment) is not
        a carried figure -- it is not falsifiable by re-measurement, so re-derive-or-mark has
        nothing to act on. A figure the author measured in this session is not carried, however
        many times the report restates it.
      - **The mark**, shown as an indented literal form:
        `{figure or claim} [CARRIED-UNVERIFIED: {source path or record identifier}]`.
        State that the token is literal and fixed-case so it is greppable, give the grep
        (`grep -rn 'CARRIED-UNVERIFIED' specs/`), and state that naming the source is REQUIRED,
        not optional, because an unnamed mark is greppable but not actionable -- a later reviewer
        cannot re-derive what it cannot locate. Prefer the most specific identifier available
        (path, plus section heading or line range).
      - **What re-derivation means per trigger class**: re-run the command and read its actual
        output rather than only its exit status (a command whose output was never spot-checked
        against what it was supposed to detect is the most common failure shape); re-count rather
        than trusting a stated tally, including a tally a document asserts about its own
        contents; re-open a cited file and confirm the cited content is at the cited place;
        re-measure a gate rather than inheriting a prior record's *prediction* about it as a
        settled constraint.
      - **Internal consistency**: a document must not assert something it contradicts elsewhere
        in itself -- most sharply, a test or assertion requiring the ABSENCE of a string the same
        document mandates elsewhere as literal output. State that general mechanical detection of
        this class is not feasible (contradiction is a semantic relation between arbitrary spans,
        not an enumerable pattern) and is therefore a reviewer obligation, then give the reviewer
        prompt as a block quote: read the document's mandated literal text blocks and its
        test/assertion directives side by side; does any assertion require the ABSENCE of a
        string a mandated literal requires to be PRESENT; does any risk or prediction stated as a
        constraint contradict a measured result stated elsewhere in the same document; flag each
        pair, quoting both halves verbatim.
      - **Enforcement level**: this is an authoring-side obligation today. Validation that every
        `CARRIED-UNVERIFIED` names a source is a named future item, not built here. (If Phase 4's
        gate passes and Phase 5 lands a check, Phase 5 updates this paragraph to match what
        actually shipped -- Phase 2 must not pre-announce a check that may not exist.)
      - **Placement record**: this section is the authoritative statement for both report and
        plan artifacts; `context/formats/plan-format.md` points here rather than restating, so
        the two cannot drift. Record the two rejected options and why: a new standalone contract
        document (rejected -- raises the net document count and adds a third place for the rule
        to drift) and stating the full rule in both format documents (rejected -- duplicated
        normative text drifts).
- [x] Add exactly one bullet to the existing `## Writing Guidance` list pointing at the new
      section (e.g. re-derive or mark every carried figure, see `## Carried-Figure Discipline`).
      Add; do not reword or remove any existing bullet. *(completed: one bullet added at line 40,
      no existing bullet reworded or removed)*
- [x] Confirm additive-only:
      `git diff -- agent-system/extensions/core/context/formats/report-format.md | grep -c '^-[^-]'`
      must print `0`. *(completed: measured 0)*
- [x] Commit this phase's single file with a scoped commit. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/report-format.md` - new `## Carried-Figure Discipline` section after `## Writing Guidance`; one added cross-reference bullet inside `## Writing Guidance`

**Verification**:
- `grep -n '## Carried-Figure Discipline' agent-system/extensions/core/context/formats/report-format.md`
  returns exactly one hit, positioned after the `## Writing Guidance` line and before the
  `## Example Skeleton` line (confirm by comparing the three line numbers).
- All six trigger classes, the out-of-scope paragraph, the literal mark form, the required-source
  rule, the reviewer prompt, and both rejected placement options are present (check each by
  grep or by reading the section back).
- `git diff` on the file shows zero removed lines (the grep above prints `0`).
- `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/context/formats/report-format.md`
  (or the repo-wide invocation, scoped to this path) reports no task-number reference.

---

### Phase 3: Point plan-format.md at the Contract from Counts-are-hypotheses [NOT STARTED]

**Goal**: Extend `plan-format.md`'s existing `### Counts-are-hypotheses obligation` subsection
with a short pointing paragraph that rules on plan-side strictness and names the
`Scope Hypothesis` discharge path, without restating the contract.

**Tasks**:
- [ ] Re-read the `### Counts-are-hypotheses obligation` subsection immediately before editing,
      and re-confirm its measured line number from Phase 1.
- [ ] Append one paragraph to that subsection (before the `**`Scope Hypothesis`:` is deliberately
      not a harvest source...**` paragraph, so the existing harvest note stays adjacent to the
      field it qualifies) stating:
      - A count, citation, command output, or mechanical claim *carried into this plan from
        another record* (a research report, a prior plan version, another task's artifact, the
        task description) is a different object from the plan's own forward-looking estimate
        governed above, and is subject to the Carried-Figure Discipline in
        `context/formats/report-format.md`: re-derive at authoring time, or mark
        `CARRIED-UNVERIFIED` with the source named.
      - The two obligations are complementary, not alternatives: `**Scope Hypothesis**:` governs
        a claim this plan makes about future implementation-time state; carried-figure discipline
        governs a claim this plan repeats from an already-written record.
      - A plan MAY discharge the re-derivation half through its own `**Scope Hypothesis**:` line
        when re-deriving at plan-authoring time is genuinely not cheap, provided that line names
        both the carried figure and the record it came from; a Scope Hypothesis naming neither
        does not discharge it.
      - The strictness ruling, stated explicitly: a plan is held at least as strictly as a
        report, because a plan's figures drive execution -- a stale carried figure in a plan
        becomes a wrong action, not only a wrong belief.
- [ ] Confirm additive-only:
      `git diff -- agent-system/extensions/core/context/formats/plan-format.md | grep -c '^-[^-]'`
      must print `0`.
- [ ] Commit this phase's single file with a scoped commit.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - one appended paragraph inside `### Counts-are-hypotheses obligation`

**Verification**:
- The added paragraph sits inside `### Counts-are-hypotheses obligation` and before the
  `### Enforcement level` heading (confirm by line numbers from `grep -n '^### '`).
- The paragraph names `report-format.md`, the token `CARRIED-UNVERIFIED`, the
  `**Scope Hypothesis**:` discharge path with its two naming conditions, and the
  at-least-as-strict ruling.
- The contract's normative text is pointed at, not duplicated: the paragraph does not restate
  the six trigger classes.
- `git diff` on the file shows zero removed lines (the grep above prints `0`).

---

### Phase 4: DECISION GATE -- Measure Narrow Impossible-Assertion Detector Feasibility [NOT STARTED]

**Goal**: Decide, by measurement rather than assertion, whether the narrowly scoped mechanical
check for the impossible-assertion sub-class is worth shipping. This gate decides whether Phase 5
runs or is closed as a reasoned exclusion.

**Tasks**:
- [ ] Write a throwaway probe script in the scratchpad directory (NOT in the repository) that,
      for a single markdown file: (a) finds absence-assertion directives -- lines matching an ERE
      in the family `(assert|require|check|verif)[^.]{0,60}(absence|absent|no occurrence|does not (appear|contain)|not present)`
      that also contain a quoted literal; (b) extracts each such literal; (c) reports a hit when
      that literal also appears inside a *different* quoted literal elsewhere in the same file.
- [ ] RECALL TEST (the one known positive): run the probe against
      `~/Projects/Logos/Verification/specs/229_handle_certify_exit3_as_indeterminate/plans/01_certify-exit3-indeterminate.md`
      and record whether the measured contradiction from Phase 1 is detected.
- [ ] PRECISION TEST: run the probe over every existing `specs/**/plans/*.md` and
      `specs/**/reports/*.md` in this repository. Record the flagged-file count and inspect each
      flagged file by hand, classifying it as a genuine instance or a false positive. Record the
      counts.
- [ ] Apply the gate criteria, all three of which must hold to PASS:
      1. RECALL: the probe detects the known positive.
      2. PRECISION: at least half of the flagged files in this repository are genuine instances.
      3. BOUNDEDNESS: the flagged-file count is small enough that a reviewer can act on every
         flag (treat more than 5 flagged files across the corpus as a FAIL -- an advisory nobody
         can triage is noise, not a check).
- [ ] Record the gate outcome, the three measured values, and the decision in the phase's
      progress notes, explicitly and quotably, so Phase 5 or its exclusion record can cite them.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: this phase assumes the flagged-file count over the existing corpus will be
small (single digits) and that the known positive is detectable by the narrow pattern. Both are
hypotheses, and either failing is a legitimate FAIL outcome, not a reason to loosen the pattern
until it passes. Confirm by the two measured runs in this phase's task list, and report the
actual numbers.

**Files to modify**:
- none planned in the repository (the probe lives in the scratchpad directory and is not
  committed)

**Verification**:
- The recall result against the known positive is recorded (detected / not detected).
- The flagged-file count and the genuine-versus-false-positive classification of every flagged
  file are recorded.
- The gate outcome (PASS or FAIL) is stated with all three criteria evaluated against measured
  numbers, not estimates.

---

### Phase 5: CONDITIONAL -- Land the Narrow Advisory Check in validate-artifact.sh [NOT STARTED]

**Goal**: Only if Phase 4's gate PASSED: add the measured-feasible narrow check to
`validate-artifact.sh` as an advisory-only warning, and align `report-format.md`'s enforcement
paragraph with what shipped.

**Contingency (gate FAILED)**: do not edit any script. Close this phase as
`[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record whose `Evidence` column
cites Phase 4's own measured recall/precision/boundedness numbers, and confirm that
`report-format.md`'s internal-consistency subsection already carries the reasoned infeasibility
finding and the reviewer prompt (it does, from Phase 2) -- that pair is a complete answer to the
internal-consistency scope item, and no further work is owed.

**Tasks** (gate-PASSED branch only):
- [ ] Re-read `agent-system/extensions/core/scripts/validate-artifact.sh` immediately before
      editing; confirm no sibling task has modified it
      (`git log --oneline -3 -- <path>`, `git status --short -- <path>`).
- [ ] Add the check in the plan/report branch as a `log_warn`-only advisory, modelled on the
      existing advisory-first Verification Tier check: same warning style, same non-promotion
      note (document the promotion criterion and state that promotion is NOT part of this
      change).
- [ ] Add a header comment stating the check's deliberately narrow scope: it detects exactly the
      assert-absence-of-a-literal-that-is-mandated-elsewhere shape and makes no claim to general
      contradiction detection.
- [ ] Test by direct invocation of the source-store copy (its sibling libraries are present in
      `agent-system/extensions/core/scripts/lib/`): run it against the known positive (expect the
      advisory), against this plan file and the research report (expect no new advisory), and
      against two previously clean existing plans (expect byte-identical output apart from the
      new check's absence). Confirm exit codes are unchanged in default mode -- an advisory must
      not turn a passing artifact into a failing one.
- [ ] Update `report-format.md`'s `**Enforcement level**` paragraph from Phase 2 to describe the
      check that actually shipped, replacing the named-future-item wording.
- [ ] Commit the script and the format-document touch-up as one scoped commit.

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - new advisory-only check in the plan/report branch (CONDITIONAL on Phase 4 PASS)
- `agent-system/extensions/core/context/formats/report-format.md` - enforcement paragraph aligned with the shipped check (CONDITIONAL on Phase 4 PASS)

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-artifact.sh` passes.
- The known positive produces the advisory; this plan, the research report, and two existing
  clean plans produce no new advisory and the same exit codes as before the change.
- Default-mode exit codes are unchanged for every artifact tested (advisory does not fail).
- If the contingency branch was taken: the phase heading reads
  `[COMPLETED WITH EXCLUSIONS]`, the `#### Reasoned Exclusions` record cites Phase 4's measured
  numbers, and no script was modified (`git status --short` shows no change under
  `agent-system/extensions/core/scripts/`).

---

### Phase 6: Acceptance Sweep [NOT STARTED]

**Goal**: Confirm every acceptance criterion mechanically, confirm nothing was weakened or added
as a document, and attribute any deploy-freshness finding before acting on it.

**Tasks**:
- [ ] Net document count unchanged:
      `ls agent-system/extensions/core/context/formats/*.md | wc -l` equals the pre-change count
      recorded in Phase 1 (the hypothesis is 16 -- confirm, do not assume).
- [ ] No weakening: `git diff -- agent-system/extensions/core/context/formats/report-format.md agent-system/extensions/core/context/formats/plan-format.md | grep '^-[^-]'`
      produces no output. If it produces any, reconcile each removed line explicitly before
      proceeding.
- [ ] No task-number references in deliverables:
      `bash .claude/scripts/check-task-references.sh` over the changed paths under
      `agent-system/**` reports clean.
- [ ] Artifact validation still passes for this plan and the research report:
      `bash .claude/scripts/validate-artifact.sh <plan path> plan` and
      `... <report path> report` (exit 0, warnings tolerated).
- [ ] Acceptance walk-through, written out one criterion at a time with its evidence: the four
      sub-classes re-confirmed or corrected (Phase 1); the contract stated per the placement
      ruling with the rejected option recorded (Phase 2); the trigger precise enough to apply to
      a concrete sentence -- demonstrate by applying it to two sentences, one in scope and one
      out, and stating the verdict; the mark specified and greppable -- demonstrate with
      `grep -rn 'CARRIED-UNVERIFIED'` over this task's own artifacts; the internal-consistency
      item answered (Phase 4/5 outcome, either branch).
- [ ] Run `bash .claude/scripts/verify-deploy.sh --findings` and attribute each finding to a
      path. Act only on findings naming this task's own files. Do NOT run `deploy-headless.sh`:
      redeploy is the orchestrator's inter-cycle checkpoint, and a mid-cycle redeploy would
      publish concurrent siblings' in-flight source edits.
- [ ] Final scoped commit for any remaining uncommitted hunk of this task's own files.

**Timing**: 0.5 hours

**Depends on**: 2, 3, 4, 5

**Verification Tier**: full

**Scope Hypothesis**: the pre-change format-document count is asserted here as 16 and the
amendment set as two files (three if Phase 5's gate passed). Both are hypotheses; confirm with
the `ls | wc -l` command above and with `git status --short`, and report any divergence.

**Files to modify**:
- none planned (verification sweep only; the final commit stages already-written files)

**Verification**:
- `bash .claude/scripts/verify-deploy.sh --findings` run, with every finding attributed; no
  unattributed or own-file failure left standing.
- Net format-document count equals the Phase 1 pre-change count.
- The removed-lines grep over both format documents produces no output.
- `check-task-references.sh` clean over the changed `agent-system/**` paths.
- Every acceptance criterion is walked through in the summary with its own evidence line.

## Testing & Validation

- [ ] All four measured sub-classes re-confirmed or corrected in Phase 1 with a stated command or
      exact citation, and every divergence reported rather than absorbed.
- [ ] `report-format.md` carries the full contract: six-class trigger, out-of-scope paragraph,
      literal mark form with required source, per-class re-derivation guidance, internal-
      consistency finding plus reviewer prompt, enforcement level, placement record with the
      rejected options.
- [ ] `plan-format.md` points rather than duplicates, and states the plan-side strictness ruling
      and the `Scope Hypothesis` discharge conditions.
- [ ] Trigger applicability demonstrated on one in-scope and one out-of-scope sentence, with the
      verdicts stated.
- [ ] `grep -rn 'CARRIED-UNVERIFIED'` locates every mark; each located mark names a source.
- [ ] Internal-consistency scope item answered by either branch, with measured numbers cited.
- [ ] Zero removed lines in both format documents; net format-document count unchanged.
- [ ] `check-task-references.sh` clean; `validate-artifact.sh` passes on this task's artifacts;
      `verify-deploy.sh --findings` findings attributed.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/report-format.md` - amended with
  `## Carried-Figure Discipline` and one Writing Guidance cross-reference bullet.
- `agent-system/extensions/core/context/formats/plan-format.md` - amended with one pointing
  paragraph inside `### Counts-are-hypotheses obligation`.
- `agent-system/extensions/core/scripts/validate-artifact.sh` - CONDITIONAL on Phase 4's gate:
  one advisory-only narrow check.
- `specs/358_require_rederivation_of_carried_figures_in_artifacts/summaries/01_carried-figure-authoring-contract-summary.md`
  - execution summary carrying the re-derived evidence, the gate measurement, and the acceptance
  walk-through.
- Scoped commits, one per phase that edits a file.

## Rollback/Contingency

Every change is additive text inside two existing markdown documents, plus one conditional,
advisory-only script addition. Revert granularity is the per-phase scoped commit: `git revert`
the phase commit, or `git checkout HEAD~1 -- <path>` for a single file, leaves both format
documents at their pre-change content with no cross-file dependency to unwind. The conditional
script check is advisory (`log_warn`) and cannot change any artifact's exit status, so leaving it
in place while reverting the documents is also safe. Phase 4's probe is never committed, so there
is nothing to roll back from the gate measurement itself. If a concurrent sibling is found to
have modified either format document mid-flight, stop, report it per the territory contract, and
do not reconcile by overwriting.
