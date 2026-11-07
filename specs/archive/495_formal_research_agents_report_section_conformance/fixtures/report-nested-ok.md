# Research Report: Fixture Nested OK

**Task**: 0 - Fixture: nested Recommendations shape (formal's current, pre-remedy shape)
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:05:00Z
**Effort**: 5 minutes
**Dependencies**: None
**Sources/Inputs**: - Fixture, hand-authored
**Artifacts**: - this fixture
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- This fixture carries `### Recommendations` nested under `## Findings`.
- Because the validator's heading match is any-depth-prefix (`^##+ Recommendations`), this
  shape still satisfies the required-section check.

## Context & Scope
This fixture establishes a control: the validator's own matching rule treats a nested
`### Recommendations` as satisfying the required `## Recommendations` section.

## Findings

### Domain Findings
- Sample finding content.

### Cross-Domain Synthesis
- Sample synthesis content.

### Recommendations
- Sample recommendation content, nested three levels deep.

## Decisions
- None; this is a fixture, not a real report.

## Risks & Mitigations
- None.

## Context Extension Recommendations
- **Topic**: None -- present to confirm it is not required for the match.
- **Gap**: None.
- **Recommendation**: None.

## Appendix
- None.
