# Research Report: Task #358

**Task**: 358 - Require rederivation of carried figures in artifacts
**Started**: 2026-10-07T08:30:00Z
**Completed**: 2026-10-07T09:10:00Z
**Effort**: ~1.5 hours
**Dependencies**: None
**Sources/Inputs**:
- `agent-system/extensions/core/context/formats/report-format.md` (full read)
- `agent-system/extensions/core/context/formats/plan-format.md` (full read)
- `agent-system/extensions/core/context/standards/status-markers.md` (partial read, marker vocabulary)
- `agent-system/extensions/core/context/contracts/adversarial-verification.md` (full read, existing VERIFIED/UNVERIFIED precedent)
- Direct measurement against `~/Projects/Logos/Verification` (the consumer repo named in the dispatch's measured evidence): tasks 184, 206, 229 artifacts and `issues.jsonl` entries
**Artifacts**:
- This report: `specs/358_require_rederivation_of_carried_figures_in_artifacts/reports/01_carried-figure-authoring-contract.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- All four measured-evidence sub-classes in the dispatch were independently re-confirmed against the Logos/Verification consumer repo by direct command/citation, not trusted from the dispatch's own prose (see Findings). No divergence from the dispatch's characterization was found, though exact numbers in sub-class (4) differ slightly from the dispatch's rounded description and are reported precisely below.
- **Item 1 ruling**: the obligation differs in strictness by artifact kind and is stated asymmetrically: `report-format.md` carries the full, authoritative definition (reports are the point of first failure — a report's entire purpose is producing freshly-derived facts, and three of the four measured failures trace to a report or a report-shaped decision record); `plan-format.md` carries a short, pointing extension onto its own already-existing "Counts-are-hypotheses obligation" / `Scope Hypothesis` machinery, cross-referencing the report-format.md definition rather than restating it.
- **Item 2 ruling**: the carried-figure trigger covers the five dispatch-listed shapes (count/measurement, command output, file/line citation, pass/fail or exit-status claim, N-of-M ratio) plus one additional class not explicitly numeric: a **qualitative claim about mechanical, system, or environmental state** (reachability, capacity, a hard "always"/"never"/"cannot") carried verbatim from a prior record — because sub-class (2), the most costly of the four measured failures, is exactly this shape and has no number in it at all. Purely interpretive/judgment prose (a recommendation, a priority opinion) is explicitly out of scope.
- **Item 3 ruling**: the mark is the literal uppercase token `CARRIED-UNVERIFIED`, used inline immediately adjacent to the carried figure, in the form `{figure/claim} [CARRIED-UNVERIFIED: {source path}]`. The source record MUST be named — ruled required, not optional, because every re-confirmation performed in this report's own Findings section depended on knowing exactly where a figure originated.
- **Item 4 ruling**: general mechanical contradiction detection (an assertion that contradicts text the same document mandates elsewhere) is **not mechanically feasible** — true natural-language contradiction detection is unbounded. A narrowly-scoped mechanical check IS feasible for the exact repro shape measured in sub-class (3) (an assert-absence-of-literal-string test whose literal also appears inside a mandated quoted string elsewhere in the same file) and is specified below as a recommended future lint, not built in this research-phase dispatch. A reviewer prompt is also specified for the general case.
- Recommended approach: amend both format documents per the Decisions/Recommendations sections below; no new document is created; net document count is unchanged.

## Context & Scope

This is a research dispatch (phase=research) for the agent-authoring half of a defect class
observed in a batch of five `/orchestrate` dispatches against a different, consumer repository
(Logos/Verification): every one of the five found a written record (a report, a plan, or a
decision record) contradicted by direct measurement. The dispatch asks this phase to (a)
re-confirm the four measured sub-classes rather than trust them, and (b) settle four scope
items that together define a forward-looking authoring contract requiring a carried figure to be
re-derived at authoring time or explicitly marked as unverified-and-carried.

**Explicitly out of scope** (restated from the dispatch, not re-litigated here): no new format
document; no general-purpose fact-checker or claim-extraction pipeline; no retroactive audit of
existing reports/plans in any repo; no weakening of any existing requirement in either format
document; no repo-local mechanical-derivation gate against the consumer repo's own records (that
is a separately filed Verification-repo task). This dispatch is research only — the actual edits
to `report-format.md`/`plan-format.md` are implementation-phase work; this report settles the
four scope items and specifies the concrete text to land, but does not edit the format documents
itself.

## Findings

### Re-confirmation of the four measured sub-classes

All four were re-confirmed by direct command or citation against `~/Projects/Logos/Verification`
(outside this repo's own tree; the dispatch scope limit does not apply to read-only
re-confirmation of evidence from another repo, only to writing a gate against it).

**Sub-class (1) — false-positive grep presented as evidence.** Task 184's research report
(`specs/184_build_gate_run_recorder_and_tagging_cost_probe/reports/01_gate-run-recorder-and-tagging-cost-probe.md`,
around lines 177-191) cites `grep -rln '^module' components/framed_channel/lean` as confirming
that `framed_channel` files carry `module` headers. Re-running that exact command against the
live consumer-repo tree:
```
grep -rln '^module' components/framed_channel/lean   # 9 files matched
grep -rn  '^module' components/framed_channel/lean   # inspect the actual matched lines
```
Every one of the 9 matched lines is wrapped prose inside a doc comment (e.g. `Stuff.lean:11:
module is and what the gate checks.`, `Ladder.lean:13: modules three things.`), not a Lean
`module` keyword declaration. `find components/framed_channel/lean -name '*.lean' | wc -l` counts
42 files in that directory, confirming the dispatch's "0 of 42" framing is the correct
characterization of actual module declarations there (not 9, the grep's raw match count) —
**confirmed, no divergence**. The repo's own `issues.jsonl` for task 184 independently records
this exact finding (`class: research-defect`, "an exact-line test (grep -qx module) measured 0 of
42 there and 46 of 46 in components/distsys"), corroborating the re-measurement above.

**Sub-class (2) — a prediction carried forward as a settled fact.** Task 229's `issues.jsonl`
carries a `kind: win`, `class: environment-measurement-reversal` entry: "Risk R6 predicted
`bash components/distsys/check.sh` (plain) was unreachable on this host for a measured
aeneas/charon toolchain-pin drift. By Phase 6, hours later, that drift no longer reproduced: the
plain run PASSed end to end (exit 0), writing a certificate whose identity matched Phase 5's own
manual regeneration exactly." **Confirmed, no divergence.** This is the dispatch's clearest
illustration that a carried figure need not be numeric — it is a qualitative reachability claim.

**Sub-class (3) — an internally impossible assertion.** Task 229's plan
(`specs/229_handle_certify_exit3_as_indeterminate/plans/01_certify-exit3-indeterminate.md`) does
contain, in its own task-list body, both halves of the contradiction: a mandated message text
("no book was certified and none was refused") and, in the fixture-assertion task item for the
INDETERMINATE leg, an instruction to assert absence of "the word 'refused'". The plan's own text
already carries the self-correction as a recorded Deviation note at the point of the second half:
"the 'or the word refused' half of this assertion is checked instead as absence of the
certifier's own `[REFUSE]` tag. The literal substring 'refused' cannot be banned: Phase 2's own
mandated consequence sentence...contains it verbatim." **Confirmed, no divergence** — the
contradiction is real and is visible entirely within one document, exactly as the dispatch
states, and the consumer repo's own implementer already caught and worked around it.

**Sub-class (4) — a self-reported tally contradicting its own content.** Task 206's summary
(`specs/206_regenerate_stale_component_certificates/summaries/01_regenerate-framed-channel-recheck-summary.md`)
records: the plan assumed Decision 10's page-level `Validated by` tally baseline was `3 binding,
6 partially, 1 none yet`; "direct grep of the page's ten `Validated by` lines measured the actual
pre-edit state as `5 binding, 4 partially, 1 none yet`." The implementing agent corrected the
bullet to the true post-edit count (`6 binding, 3 partially, 1 none yet`) rather than propagating
the plan's stale figure. **Confirmed, with one precision correction against the dispatch's own
rounded description**: the dispatch says "a direct count... measured a different one" without
giving numbers; the actual pre-edit mismatch was 3/6/1 (plan's assumption) vs. 5/4/1 (measured) —
both distributions summing to 10, consistent with "its own ten markers," but the dispatch's prose
does not itself carry these numbers, so there is nothing to diverge from, only to add precision
to. Reported here rather than silently absorbed, per the dispatch's own instruction to treat its
measured evidence as re-confirmable leads.

### Existing marker/field conventions surveyed (Item 3 input)

- `plan-format.md` already has a "Counts-are-hypotheses obligation" (`## Verification Tiers` →
  `### Counts-are-hypotheses obligation`): any count, file list, or scope estimate **asserted in
  a plan** is a hypothesis requiring implementation-time confirmation, carried via a required
  `**Scope Hypothesis**:` per-phase field. This is the plan's own forward-looking estimate about
  future (implementation-time) state — a different concept from a figure **copied from another
  already-written record** (the carried-figure case this task addresses), but it establishes the
  precedent that "a count is a hypothesis, not a fact" is already native vocabulary in this
  document, and that a `**Field**:` bold-label line is the established way to carry such an
  obligation.
- `plan-format.md` also has `#### Reasoned Exclusions` (`Item | Reason | Evidence` table) and
  `## Planned Strategic Sorries` (`sorry_inventory`-mirroring table) — both precedent for a
  structured table carrying a justification/evidence column next to a claim.
- `context/contracts/adversarial-verification.md` (hard-mode-only, H4) already uses a bolded
  **VERIFIED**/**UNVERIFIED** vocabulary and an `UNRESOLVED CONTRADICTION:` block-opener
  convention. This is the closest existing precedent for an uppercase, greppable, bolded status
  tag — but it is gated to hard-mode research agents only and is not part of the base
  `report-format.md`/`plan-format.md` documents this task must amend. The new mark should borrow
  this family's style (uppercase, bold, grep-friendly) without depending on hard-mode gating,
  since none of the four measured failures were hard-mode-specific.
- Neither format document currently has any vocabulary for a figure's **provenance** (where a
  number/claim was copied from). This is the actual gap.

## Decisions

- **Item 1 (where the contract lives)**: strengthen `report-format.md` with the full, authoritative
  definition (new section, placed after "Writing Guidance" and before "Context Extension
  Recommendations Section"); strengthen `plan-format.md` with a short cross-referencing extension
  to its existing "Counts-are-hypotheses obligation" subsection, pointing at `report-format.md`'s
  definition rather than duplicating it. Rationale: a report's entire purpose is producing
  freshly-derived facts, so a carried-and-unmarked figure in a report defeats the document's
  reason for existing — the full statement belongs there. A plan already has partial machinery
  (`Scope Hypothesis`) for its own estimates; the new text only needs to make explicit that a
  figure **copied from another record** (a prior report, a prior plan version, another task's
  artifact) is subject to the identical re-derive-or-mark rule, with `Scope Hypothesis`'s
  existing implementation-time confirmation serving as one valid discharge path when
  re-derivation at plan-authoring time is genuinely not cheap.
- **Item 2 (trigger definition)**: a "carried figure or mechanical claim" is any of the following,
  when copied or closely paraphrased from a prior record (another artifact, a prior session, a
  different task) into a new report or plan, rather than freshly produced by the authoring
  agent's own measurement in this authoring session:
  1. A numeric count or measurement.
  2. The output, or a claimed characterization of the output, of a command.
  3. A file/line citation presented as locating specific content.
  4. A pass/fail or exit-status claim.
  5. An "N of M" ratio.
  6. A qualitative claim about mechanical, system, or environmental state (e.g. "X is
     unreachable on this host," "Y always/never happens," "Z is required") — added beyond the
     dispatch's five enumerated shapes because sub-class (2), the costliest of the four measured
     failures, is exactly this non-numeric shape.
  A purely interpretive or judgment claim (a recommendation, a priority ranking, a stylistic
  preference) carried from a prior record is explicitly **not** in scope — such claims are not
  falsifiable by re-measurement, so "re-derive or mark" does not apply to them.
- **Item 3 (the mark)**: the literal token `CARRIED-UNVERIFIED` (fixed spelling, fixed case),
  used inline immediately next to the figure/claim: `{figure/claim} [CARRIED-UNVERIFIED:
  {source path}]`. The source record MUST be named inside the bracket — not optional. Rationale:
  every re-confirmation in this report's own Findings section above depended on being told
  exactly which record a figure came from; an unnamed-source mark would be greppable but not
  actionable by a future reviewer or re-deriving agent.
- **Item 4 (internal-consistency feasibility)**: general contradiction detection across a
  document is ruled **not mechanically feasible** — contradiction is a semantic relation between
  arbitrary natural-language spans, not a pattern a lint tool can enumerate. A narrowly-scoped
  check IS feasible for the specific repro shape measured in sub-class (3): a line matching an
  assert-absence-of-literal-string test directive whose target literal also appears, verbatim and
  quoted, inside a different "mandated text" block elsewhere in the same file. This is specified
  as a recommended future lint (not built in this research dispatch — building it is
  implementation-phase scope) in Recommendations below, alongside a reviewer prompt for the
  general case.
- Net document count is unchanged: both amendments land inside the two existing format documents;
  no third document is created.

## Recommendations

1. **`report-format.md`** — add a new top-level section, e.g. `## Carried-Figure Discipline`,
   stating: any figure or mechanical claim in scope per Item 2 above that is copied from a prior
   record must be re-derived (re-run the command, re-count, re-check the citation) at authoring
   time, OR marked `CARRIED-UNVERIFIED` inline with its named source per Item 3. Cross-reference
   this new section from the "Writing Guidance" bullet list ("Be objective, cite sources/paths")
   so a reader following that bullet lands on the fuller rule.
2. **`plan-format.md`** — extend the existing `### Counts-are-hypotheses obligation` subsection
   (under `## Verification Tiers`) with one short paragraph: a count, claim, or citation **carried
   from another record** (not originating as this plan's own estimate) is subject to
   `report-format.md`'s Carried-Figure Discipline (re-derive or mark `CARRIED-UNVERIFIED` with
   named source); a plan MAY discharge the re-derivation obligation via its own `Scope
   Hypothesis`/implementation-time-confirmation mechanism when re-deriving at plan-authoring time
   is not cheap, provided the hypothesis explicitly names the carried figure and its source.
3. **Future lint (not built this dispatch)**: a narrow mechanical check for sub-class (3)'s
   shape — scan a single plan/report file for an assert-absence-of-literal-string test directive;
   for each, check whether the same literal string appears verbatim inside a different quoted
   "mandated text" block elsewhere in the file; if so, emit an advisory (not a hard failure, to
   avoid false positives) naming both locations for human review. This is a recommended follow-up
   task, not a deliverable of this research phase.
4. **Reviewer prompt for the general contradiction case** (Item 4, general-case answer): "Read
   this document's mandated literal text blocks (quoted messages, exact strings the plan requires
   to appear verbatim in output) and this document's test/assertion directives side by side. Does
   any assertion require the ABSENCE of a string that a mandated literal block requires to be
   PRESENT? Does any risk/prediction stated as a constraint contradict a measured result stated
   elsewhere in the same document? Flag each pair found, quoting both halves verbatim."

## Risks & Mitigations

- **Risk**: a forward-looking-only contract (no retroactive audit, per the dispatch's explicit
  non-goal) means the four already-measured failures in the consumer repo remain uncorrected by
  this task. **Mitigation**: none needed from this task — a separate Verification-repo task is
  explicitly scoped to own the repo-local mechanical-derivation gate; this task's job is the
  agent-authoring contract only, and the dispatch is explicit that retroactive audit is out of
  scope.
- **Risk**: `CARRIED-UNVERIFIED` could be used as a blanket escape hatch to avoid ever
  re-deriving anything. **Mitigation**: the dispatch itself names this as a deliberate, accepted
  tradeoff ("the marked-as-carried escape hatch is deliberate... must not make it impossible to
  reference a figure one cannot cheaply reproduce, only impossible to present such a figure as
  freshly measured"); the mark makes the carried-and-unverified status visible and greppable
  rather than preventing the carry outright.
- **Risk**: the new `## Carried-Figure Discipline` section in `report-format.md` could be read as
  requiring re-derivation of every single number in a report, including ones genuinely produced
  fresh in this session. **Mitigation**: the trigger (Item 2) is explicitly scoped to figures
  *copied from a prior record*, not to fresh measurements; the recommended section text should
  state this scoping explicitly to avoid over-application.

## Context Extension Recommendations
- **Topic**: Carried-figure discipline enforcement tooling.
- **Gap**: no existing script greps for `CARRIED-UNVERIFIED` or validates that every such mark
  names a source; `validate-artifact.sh` has no check for this new vocabulary yet.
- **Recommendation**: a follow-up implementation task should add an advisory-first check to
  `scripts/validate-artifact.sh` (mirroring the Verification Tier's advisory-first rollout
  pattern) that greps for `CARRIED-UNVERIFIED` and flags any occurrence missing a bracketed
  source path.

## Appendix
- Search queries/commands used:
  - `grep -rln '^module' components/framed_channel/lean` and the unfiltered `grep -rn` variant
    (Logos/Verification consumer repo) — sub-class (1) re-confirmation.
  - `find components/framed_channel/lean -name '*.lean' | wc -l` — file-count re-confirmation.
  - `cat specs/229_.../issues.jsonl | python3 -c '...'` filtering `class ==
    "environment-measurement-reversal"` — sub-class (2) re-confirmation.
  - `sed -n` reads of `specs/229_.../plans/01_certify-exit3-indeterminate.md` around the cited
    lines — sub-class (3) re-confirmation.
  - `sed -n` read of `specs/206_.../summaries/01_regenerate-framed-channel-recheck-summary.md` —
    sub-class (4) re-confirmation.
- References: `agent-system/extensions/core/context/formats/report-format.md`,
  `agent-system/extensions/core/context/formats/plan-format.md`,
  `agent-system/extensions/core/context/contracts/adversarial-verification.md`,
  `agent-system/extensions/core/context/standards/status-markers.md`.
