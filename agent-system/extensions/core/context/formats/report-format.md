# Report Artifact Standard

**Scope:** Research, analysis, verification, and review reports produced by /research, /review, /analyze, and related agents.

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

**Out of scope**: a purely interpretive or evaluative claim carried from another record (a
recommendation, a priority ranking, a design preference, a quality assessment) is not a carried
figure — it is not falsifiable by re-measurement, so re-derive-or-mark has nothing to act on. A
figure the author measured in this session is not carried, however many times the report
restates it.

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

**Enforcement level**: this is an authoring-side obligation today. Validation that every
`CARRIED-UNVERIFIED` names a source is a named future item, not built here.

**Placement record**: this section is the authoritative statement for both report and plan
artifacts; `context/formats/plan-format.md` points here rather than restating, so the two cannot
drift. Two other placements were considered and rejected: a new standalone contract document
(rejected — raises the net document count and adds a third place for the rule to drift), and
stating the full rule in both format documents (rejected — duplicated normative text drifts).

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
