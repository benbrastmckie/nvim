# Report Artifact Standard

**Scope:** Research, analysis, verification, and review reports produced by the research dispatch, /review, /analyze, and related agents.

## Metadata (required)
- **Task**: `{id} - {title}`
- **Started**: `{ISO8601}` when work begins
- **Completed**: `{ISO8601}` when work completes
- **Effort**: `{estimate}`
- **Dependencies**: `{list or None}`
- **Sources/Inputs**: bullet list of inputs consulted
- **Artifacts**: list of produced artifacts (paths)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

**Note**: Status metadata belongs in TODO.md and state.json only, not in reports. Include **Started**/**Completed** timestamps in metadata; do not use emojis.

## Structure
1. **Project Context (optional)** – dependency relationships if applicable (see below).
2. **Executive Summary** – 4-6 bullets.
3. **Context & Scope** – what is being evaluated, constraints.
4. **Findings** – ordered or bulleted list with evidence; include status markers for subsections if phases are tracked.
5. **Decisions** – explicit decisions made.
6. **Recommendations** – prioritized list with owners/next steps.
7. **Risks & Mitigations** – optional but recommended.
8. **Context Extension Recommendations (optional)** – identified gaps in project context documentation.
9. **Appendix** – references, data, links.

## Required Section Headings (verbatim)

The five headings below are verbatim and non-paraphrasable:

- `## Executive Summary`
- `## Context & Scope`
- `## Findings`
- `## Decisions`
- `## Recommendations`

They are read live out of `validate-artifact.sh`'s own `REPORT_SECTIONS` array, and that
script's own check loop matches each with an any-depth heading-prefix regex, `^##+ {section}`.
This match is exact-text, not fuzzy: a heading that merely discusses the same topic under
different wording does not satisfy the check. A nested heading (for example a third-level
`### Recommendations` inside `## Findings`) does satisfy the check — the regex has no ceiling on
heading depth — but a renamed or reworded heading never does.

Two near-misses have been observed to fail in a real produced report:
`## Recommended Next Steps` and `## Context Extension Recommendations` do **not** satisfy
`## Recommendations` — only a heading whose text, after the `##+ ` prefix, is exactly
`Recommendations` does. Keep `## Context Extension Recommendations` in a report where it applies
(it is a distinct, useful section), but never as a substitute for the required
`## Recommendations` heading.

**Pre-return self-check**: before finalizing a report, grep the written file once per required
heading above (`grep -qE "^##+ {section}" <path>`) and add any missing heading before proceeding
to the metadata-file stage. Treat a missing heading as something to fix immediately, not a
passive warning to leave for a later gate — the production failure this contract exists to
prevent was exactly a non-blocking validator warning left unactioned.

This section is the single place this contract is stated. An agent whose report-writing stage
needs this contract should point at this section by name rather than copy its text — copying
the same contract into several agent files is the mechanism that let one copy drift out of date
while another was updated.

## Project Context (optional)

Include when dependency relationships are essential to the research topic. Omit for standalone topics. Fields: **Upstream Dependencies**, **Downstream Dependents**, **Alternative Paths**, **Potential Extensions** -- each a brief list of relevant modules/components.

## Writing Guidance
- Be objective, cite sources/paths.
- Keep headings at most level 3 inside the report.
- Prefer bullet lists over prose for findings/recommendations.
- Group Sources/Inputs by category when >5 items.
- Appendix must not duplicate Findings or Recommendations content.
- Omit code blocks that restate file contents cited by path.
- Ensure lazy directory creation: create `reports/` only when writing the first report file.
- Re-derive or mark every carried figure at authoring time — see `## Carried-Figure Discipline`.

## Carried-Figure Discipline

**Definition**: a figure or mechanical claim the report did not produce by its own measurement
in this authoring session — one copied or closely paraphrased from another record (a prior
report, a prior plan version, another task's artifact, the task description, a session
transcript) — is a *carried figure*. Every carried figure must be either re-derived at authoring
time or marked `CARRIED-UNVERIFIED` with its source named. The purpose of this obligation:
presenting a carried figure as freshly measured is the defect; carrying one openly is not.

**In scope (the trigger)** — a claim of any of these six shapes, copied or closely paraphrased
from another record, is a carried figure:
1. A numeric count or measurement.
2. The output of a command, or a characterization of what a command's output shows.
3. A file/line citation presented as locating specific content.
4. A pass/fail, exit-status, or gate-outcome claim.
5. An "N of M" ratio.
6. A qualitative claim about mechanical, system, or environmental state — reachability,
   capacity, availability, or a hard "always"/"never"/"cannot"/"is required".

**Out of scope**: a purely interpretive or evaluative claim carried from another record — a
priority ranking, a design preference, a quality assessment — is not a carried figure: it is not
falsifiable by re-measurement against the live corpus, so re-derive-or-mark has nothing to act
on. A figure the author measured in this session is not carried, however many times the report
restates it. The line this paragraph draws is "falsifiable by re-measurement against the live
corpus", not "a recommendation" categorically — see the next paragraph for the one recommendation
shape that IS in scope, as the artifact's own new claim rather than something carried from
elsewhere.

**A recommendation whose adoption asserts a measurable property of the live corpus is in
scope.** The trigger: a recommendation proposes changing a mechanical rule applied over a
corpus, and the recommendation's soundness as recommended depends on how the current corpus
responds to that changed rule. Discharge the obligation either by running the proposed rule
against the corpus at authoring time and reporting the result inline, or, when deferring that
check, by marking the recommendation with a distinct literal fixed-case token naming both the
corpus swept and the rule not checked against:

    {recommendation} [CORPUS-UNVERIFIED: {corpus swept} / {rule not yet checked against it}]

`CORPUS-UNVERIFIED` is deliberately NOT `CARRIED-UNVERIFIED`: that token's definition is keyed to
a claim copied or closely paraphrased from another record, and here the claim is the artifact's
own new recommendation, not something carried. `CORPUS-UNVERIFIED` carries the same
required-named-argument rule and the same greppability terms
(`grep -rn 'CORPUS-UNVERIFIED' specs/`): an unnamed mark is greppable but not actionable, exactly
as for `CARRIED-UNVERIFIED`.

**Canonical positive instance**: a recommendation to tighten a marker parser to a depth counter.
Plan-time re-measurement showed five source-store test suites end their marker parse at nonzero
depth, so the recommended rule is not behaviour-preserving over the current corpus — the
recommendation's adoption asserts exactly the measurable property that re-measurement refuted.

**Canonical negative instance**: a pure design preference (for example, preferring a depth
counter purely for readability, with no claim about corpus behaviour) asserts nothing the corpus
could contradict, and stays out of scope under the paragraph above.

Neither this paragraph nor any other turns the convention into a prohibition on carrying or
recommending; the purpose stated in the Definition above still governs: presenting a carried or
corpus-dependent claim as verified when it is not is the defect, not the carrying or the
recommending itself.

**The mark**, shown as an indented literal form:

    {figure or claim} [CARRIED-UNVERIFIED: {source path or record identifier}]

The token `CARRIED-UNVERIFIED` is literal and fixed-case so it is greppable
(`grep -rn 'CARRIED-UNVERIFIED' specs/`). Naming the source is REQUIRED, not optional: an unnamed
mark is greppable but not actionable — a later reviewer cannot re-derive what it cannot locate.
Prefer the most specific identifier available (path, plus section heading or line range).

**What re-derivation means per trigger class**: re-run the command and read its actual output
rather than only its exit status (a command whose output was never spot-checked against what it
was supposed to detect is the most common failure shape); re-count rather than trusting a stated
tally, including a tally a document asserts about its own contents; re-open a cited file and
confirm the cited content is at the cited place; re-measure a gate rather than inheriting a prior
record's *prediction* about it as a settled constraint.

**Internal consistency**: a document must not assert something it contradicts elsewhere in
itself — most sharply, a test or assertion requiring the ABSENCE of a string the same document
mandates elsewhere as literal output. General mechanical detection of this class is not feasible
(contradiction is a semantic relation between arbitrary spans, not an enumerable pattern) and is
therefore a reviewer obligation. Reviewer prompt:

> Read the document's mandated literal text blocks and its test/assertion directives side by
> side. Does any assertion require the ABSENCE of a string a mandated literal requires to be
> PRESENT? Does any risk or prediction stated as a constraint contradict a measured result stated
> elsewhere in the same document? Flag each pair, quoting both halves verbatim.

**Enforcement level**: a well-formedness check exists in `scripts/validate-artifact.sh`: every
mark of the literal token names a non-empty source designator before its closing bracket. It is
advisory-only (`log_warn`, never `log_error`), gated to `report` and `plan` artifacts only
(`summary-format.md` carries no carried-figure obligation), and carries its own
promotion-criterion comment stating what would have to be true before it is promoted to
blocking — promotion to blocking is explicitly NOT part of this change. The check is a
well-formedness test on a fixed literal token's syntax, never semantic contradiction detection;
two closely related questions were considered and are each ruled out of scope, as reasoned
exclusions rather than open items:

- **Does the named source resolve?** Ruled NO. The mark's own specification above permits "a
  source path or record identifier", and prose-only designators (a session description, a
  dispatch's own instructions) already exist in the live corpus — there is no single resolvable
  form to check against. Attempting to extract a path-shaped candidate from an arbitrary prose
  designator and test its existence would reproduce, in miniature, the heuristic semantic
  extraction that sank the rejected general contradiction detector (see "Internal consistency"
  above); a mark that merely fails to resolve is not evidence the figure itself is wrong.
- **Is a mark owed where a figure was carried without one?** Ruled NO. Establishing that a given
  claim *was* carried from another record — as opposed to independently derived in this
  session — requires comparing the claim's prose against an unbounded set of candidate prior
  records, with no fixed literal anchor to match against. The six trigger-class shapes above
  describe how to recognize a carried figure once a human or reviewer already suspects one; they
  give a mechanical check nothing to grep for before that judgment is made.

A deliberately malformed illustrative example written in prose to demonstrate the mark's syntax
(for instance, in a document that discusses this convention itself) will still draw the
well-formedness advisory; this is accepted for an advisory-level check and is not treated as a
false positive worth suppressing.

**Placement record**: this section is the authoritative statement for both report and plan
artifacts; `context/formats/plan-format.md` points here rather than restating, so the two cannot
drift. Two other placements were considered and rejected: a new standalone contract document
(rejected — raises the net document count and adds a third place for the rule to drift), and
stating the full rule in both format documents (rejected — duplicated normative text drifts).

## Amending a Prior Verdict: Ground Overturned vs. Outcome Overturned

When a report re-tests a verdict recorded in an earlier artifact (a NO-GO, a GO, a pass/fail
gate result, a recommendation), distinguish two different kinds of amendment before writing the
`## Decisions` section:

- **Outcome overturned**: re-testing shows the prior verdict's conclusion was wrong. The new
  report states the new conclusion plainly; no special framing is needed beyond ordinary
  decision-recording.
- **Ground overturned, outcome preserved**: re-testing shows the prior verdict's *conclusion*
  still holds, but the *reason it gave* does not — the stated obstruction, divergence count, or
  inference that originally justified the verdict turns out to be wrong, incomplete, or
  differently characterized, while the verdict itself (NO-GO, blocked, do-not-adopt, or
  whatever it was) remains correct under a different and now-correct reason.

These are not the same event, and conflating them misleads a later reader. A reader who sees
only "the verdict still holds" with no comment on the reason may reasonably infer the original
reasoning was re-confirmed; a reader who sees the reasoning silently swapped without comment may
mistake a ground correction for a reopened question. Neither inference is safe to leave
implicit.

**When ground is overturned but the outcome is preserved, say so explicitly and name both
halves**: state the preserved outcome, name the specific component of the original reasoning
that was wrong, and give the corrected reasoning that now supports the same outcome. Do this in
`## Decisions`, as its own bullet, not folded silently into `## Findings` where a skimming
reader could miss that the ground changed at all. A verdict amended this way is a complete,
freestanding outcome in its own right — it is not a partial or deferred result requiring further
work to "finish" the amendment, unless further open questions independently remain.

**Do not describe this as reopening, lifting, or walking back the original verdict.** Those
words describe outcome-overturning amendments; using them for a ground-only correction invites
exactly the misreading this section exists to prevent.

## Example Skeleton
```
# Research Report: {title}
- **Task**: {id} - {title}
- **Started**: 2025-12-22T10:00:00Z
- **Completed**: 2025-12-22T13:00:00Z
- **Effort**: 3 hours
- **Dependencies**: None
- **Sources/Inputs**: ...
- **Artifacts**: ...
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context (optional)
- **Upstream Dependencies**: `utils/helpers.lua`, `config/base.lua`
- **Downstream Dependents**: Plugin configurations, LSP setup
- **Alternative Paths**: None identified
- **Potential Extensions**: Additional filetype support, new keymaps

## Executive Summary
- ...

## Context & Scope
...

## Findings
- ...

## Decisions
- ...

## Recommendations
- ...

## Risks & Mitigations
- ...

## Context Extension Recommendations
- **Topic**: {topic not covered by existing context}
- **Gap**: {description of missing documentation}
- **Recommendation**: {suggested context file to create or update}

## Appendix
- References: ...
```

## Context Extension Recommendations Section

Include when research reveals undocumented topics, outdated context, or recurring patterns worth capturing. Omit for meta tasks or when no gaps are found. Each entry uses the format: `- **Topic**: ... / **Gap**: ... / **Recommendation**: ...`. Context gap task creation is currently disabled; document gaps for manual review only.
