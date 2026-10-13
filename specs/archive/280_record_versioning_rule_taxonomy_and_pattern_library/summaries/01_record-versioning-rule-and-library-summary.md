# Implementation Summary: Task #280

- **Task**: 280 - Record-versioning rule, taxonomy, and pattern library
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T23:00:00Z
- **Completed**: 2026-10-09T02:10:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None (foundational; two later tasks consume this task's library)
- **Artifacts**: plans/01_record-versioning-rule-and-library.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the policy and the mechanical source of truth for a new repository-wide rule: deliverables
outside `specs/**` must state the current design only and must never narrate their own draft
history (page-level version labels, supersession framing, `(v1 Decision N)` attributions,
migration claims). Delivered the rule, its full exemption taxonomy (including a shape-based
discriminator that separates the record-version axis from three durable, legitimate version
axes), the shared pattern/exemption library, an executable test suite, and all wiring. The two
enforcement consumers (a repo-wide lint and a write-time hook) are deliberately out of scope and
land in later tasks.

## What Changed

- `agent-system/extensions/core/scripts/lib/record-version-patterns.sh` — new shared library:
  BLOCKING/ADVISORY detection patterns, `is_exempt_path`, `strip_durable_axis_lines` (the
  shape-based durable-axis discriminator), `strip_exempt_regions` (the `version-ok` marker
  convention), Class C (sourced-only, shellcheck clean).
- `agent-system/extensions/core/scripts/tests/test-record-version-patterns.sh` — new executable
  test suite, 30 assertions (8 BLOCKING positives, 9 real-corpus BLOCKING negatives, 5 ADVISORY
  positives, path/marker/durable-axis helper coverage).
- `agent-system/extensions/core/rules/no-record-versioning-in-deliverables.md` — new eager rule,
  structurally parallel to its sibling `no-task-references-in-deliverables.md`.
- `agent-system/extensions/core/context/standards/record-version-exemptions.md` — new taxonomy
  standard: rationale, exemption taxonomy, forbidden-category/tier table, marker convention,
  forward-looking enforcement narrative, and the structural-shape design principle.
- `agent-system/extensions/core/manifest.json` — wired the new rule into `provides.rules` and
  both new scripts into `provides.scripts`; verified `provides.context`'s `"standards"` entry
  already covers the new taxonomy file (no edit needed there).
- `agent-system/extensions/core/index-entries.json` — two new discovery entries
  (`standards/record-version-exemptions.md`, `reference/artifact-numbering-and-versioning.md`).
- `agent-system/extensions/core/merge-sources/claudemd.md` — one new Rules References bullet,
  plus a compaction of the Hard Mode and Syncprotect sections (budget reconciliation).
- `agent-system/extensions/core/rules/git-workflow.md`, `rules/artifact-formats.md` — compacted
  narrative, with full detail relocated verbatim to non-eager homes.
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md`,
  `context/guides/hard-mode-routing.md`, `context/guides/loader-reference.md`,
  `context/reference/artifact-numbering-and-versioning.md` (new) — relocation destinations for
  the eager-budget reconciliation.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — one new dated
  reconciliation note; `baseline_bytes` left unmoved.

## Decisions

- Discriminated the record-version axis from three durable axes (toolchain/software pins,
  file-format/schema versions, CI cache-key epochs) by structural shape rather than a string
  whitelist — live calibration against the Verification repository's current (post-reorg)
  `docs/`, `README.md`, `books/`, `books/schema/`, `records/`, and
  `records/architecture-decisions/` trees found and fixed two real discriminator misses (schema
  documents self-declaring their own format version in a backtick-quoted title) before freezing
  the pattern set.
- Tiered the bare-past-tense vocabulary (`no longer`, `previously`, `formerly`, `used to`,
  `withdrawn`) as ADVISORY with an escalation rule (promote to BLOCKING only when the same line
  also carries a non-durable-axis `v[0-9]` token), since it produced 53 hits in accepted,
  non-versioning prose during calibration.
- Shipped the disposition-table heuristic as ADVISORY and explicitly undercalibrated — zero real
  positive instances exist in the live corpus.
- Closed the eager-context budget overage (3,229 B over an already-zero-headroom baseline) by
  relocating narrative to existing or new non-eager homes rather than moving `baseline_bytes`,
  landing 9 B under the unmoved baseline.

## Plan Deviations

- **Phase 6** (full gate set): altered. Gates 3, 4, 5, 10, and 20 — every gate this task's own
  work touches — are green. Gates 8 and 13 remain red for reasons independently confirmed
  unrelated to this task (a pre-existing `detect-noop-bash.sh` hook runtime-file orphan-detection
  gap predating this dispatch); see the plan's Phase 6 Reasoned Exclusions table for the full
  evidence trail. Closed `[COMPLETED WITH EXCLUSIONS]`.

## Verification

- Build: N/A (markdown/shell deliverables)
- Tests: Passed — `test-record-version-patterns.sh` (30/30), `run-all.sh` (123/124 suites,
  1 failing suite traced to an unrelated pre-existing issue, see Plan Deviations)
- Files verified: Yes — all four new deliverables confirmed deployed byte-identical to source

## Impacts

- Provides the single mechanical source of truth (`record-version-patterns.sh`) that the two
  planned enforcement consumers (a repo-wide lint and a write-time guard hook) will source rather
  than redefine, mirroring the existing `task-reference-patterns.sh` precedent.
- The rule and taxonomy are live and discoverable immediately; no deliverable outside `specs/**`
  should now narrate its own draft history, though enforcement is not yet mechanically gated
  until the two consumer tasks land.

## Follow-ups

- Two later tasks build the repo-wide lint (`scripts/check-record-versioning.sh`) and the
  write-time hook (`hooks/validate-no-record-versioning.sh`), both sourcing this task's library.
- The disposition-table ADVISORY heuristic remains uncalibrated against a real positive instance;
  revisit if one is found.
- The pre-existing `detect-noop-bash.sh` orphan-detection gap (gates 8/13's excluded failures) is
  a separate, systemic issue outside this task's scope and is not tracked further here.

## References

- Plan: specs/280_record_versioning_rule_taxonomy_and_pattern_library/plans/01_record-versioning-rule-and-library.md
- Research: specs/280_record_versioning_rule_taxonomy_and_pattern_library/reports/01_rule-taxonomy-and-pattern-library-design.md
- Sibling precedent: `rules/no-task-references-in-deliverables.md`,
  `context/standards/task-reference-exemptions.md`, `scripts/lib/task-reference-patterns.sh`
