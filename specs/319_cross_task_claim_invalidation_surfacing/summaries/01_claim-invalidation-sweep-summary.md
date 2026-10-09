# Implementation Summary: Task #319

- **Task**: 319 - Surface cross-task claim invalidation when a research dispatch refutes a filed premise
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T06:04:36Z
- **Completed**: 2026-10-09T07:40:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 285 (satisfied)
- **Artifacts**: plans/01_claim-invalidation-sweep.md, summaries/01_claim-invalidation-sweep-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Delivered the three pieces the plan specified: a structured, producer-owned `claim_invalidations`
trigger field on `.return-meta.json`; the conditional research-agent instruction that populates
it; and `sweep-invalidated-claims.sh`, a read-only, JSON-on-stdout, exit-0-always matcher that
takes declaration names and returns every non-terminal sibling task whose own title/description
names one, plus a regression fixture replaying the motivating incident end-to-end. All edits land
under `agent-system/extensions/core/`, never `.claude/**`. The postflight call site that would
invoke the matcher remains deliberately unwired (Decision 5), with the owed follow-up recorded
below.

## What Changed

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added the
  `### claim_invalidations (optional)` field section (four keys: `declaration_names`, `kind`,
  `claim`, `evidence_path`), stated its false-negative posture and dormancy note, and extended
  the `Multiple Sequential Writers` producer-owned enumeration. 835 -> 869 lines.
- `agent-system/extensions/core/agents/general-research-agent.md` — added a conditional Stage 7
  paragraph instructing emission of `claim_invalidations` only when a dispatch machine-checked a
  refutation or closed a question by supersession, plus a matching `MUST DO` entry.
- `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh` — new file: the matcher.
  Two combinable input modes (`--name`, `--from-return-meta`), one `jq` invocation implementing
  word-boundary Oniguruma-lookaround matching (Decision 1) and membership-test terminal/self
  exclusion with no `!=` anywhere (Decision 2), output `{task_number, title, matched_name}`
  (Decision 4), ships deliberately uncalled with its header naming both owed integration calls
  (Decision 5).
- `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh` — new file: 18
  assertions covering the incident replay (all five analogs named), four negative controls
  (unrelated, word-boundary substring, terminal, self), the non-mutation checksum guard, output
  determinism, the full robustness contract, the `--from-return-meta` union case, a combined
  input-mode case, and `--help`.
- `agent-system/extensions/core/manifest.json` — three `provides.scripts` entries added by
  `sync-manifest-scripts.sh --write` (the two this task's files need, plus one pre-existing gap
  from an unrelated already-landed task, fixed incidentally as mechanical housekeeping).
- `agent-system/extensions/core/index-entries.json` — `line_count` for
  `formats/return-metadata-file.md` refreshed by `generate-context-line-counts.sh --write`.

## Decisions

Carried from the plan (not re-litigated here): word-boundary matching via explicit Oniguruma
lookarounds inside one `jq` pass (Decision 1); terminal/self exclusion via membership tests,
never `!=` (Decision 2); the field needs an explicit agent instruction, not format-doc
documentation alone (Decision 3); output carries `title` alongside `{task_number,
matched_name}` (Decision 4); the matcher ships deliberately uncalled, with its header naming
both owed integration calls (Decision 5).

One implementation-level refinement: the self-exclusion predicate is written as
`select(([.project_number | tostring] | inside($self_set)) | not)` rather than a direct `==`
against `.project_number`, because `project_number` is a JSON number and the CLI-supplied
`--self` value is a string — a bare `==` would never match. This stays inside Decision 2's
no-`!=` membership-test spirit; it is a type-correctness detail of implementing that decision,
not a change to it.

## Plan Deviations

- **Task 5.1** altered: `sync-manifest-scripts.sh --check` found three missing
  `provides.scripts` entries, not the two the Scope Hypothesis predicted. The third
  (`scripts/tests/test-lint-agent-contracts-handoff-section.sh`) is a pre-existing gap from an
  unrelated, already-landed task, outside this task's `file_scope`. `--write` is mechanical and
  additive-only (derives from disk, never removes a declared-but-absent entry), so all three
  were written in one pass. Recorded via `issue-record.sh` at the time.

## Verification

- Build: N/A (no compiled artifact)
- Tests: Passed — `test-sweep-invalidated-claims.sh` (18/18 assertions), `run-all.sh` full suite
  (all discovered suites, including the new one)
- Files verified: Yes
- `bash .claude/scripts/verify-deploy.sh` (full, all 21 gates, no `--skip-slow`): **PASS — 35
  check(s), 0 failure(s)**
- `bash .claude/scripts/check-deploy-freshness.sh`: exit 0, deployed tree current
- Hand-verified acceptance criterion directly: replaying the `NoFiniteWidthModel` incident shape
  against five synthetic non-terminal analogs plus four controls (unrelated, substring,
  terminal, self) produces an advisory list naming exactly the five expected analogs, with the
  fixture state file byte-identical afterwards (`sha256sum` before/after match) and no task
  description, `file_scope`, or status ever mutated.

## Impacts

- A future research dispatch that machine-checks a refutation or closes a question by
  supersession now has a structured, producer-owned field to record it in, and a tested,
  read-only matcher that can surface the blast radius for human triage once wired.
- No existing behavior changes: the matcher is new and uncalled, the field is optional and
  absent by default, and the research-agent instruction only fires on the narrow
  machine-checked-refutation-or-explicit-supersession trigger bar.

## Follow-ups

- **Owed, not performed here (Decision 5)**: a follow-up task against
  `scripts/orchestrate-cycle-postflight.sh`, at the research-postflight call site, adding BOTH
  calls as one task (never two, to halve the serializing edges against that already
  eight-tasks-contended file): (1) `sweep-invalidated-claims.sh --from-return-meta <path> --self
  <task_number>`, keyed on a non-empty top-level `claim_invalidations` array; (2)
  `memory-harvest.sh <task_number>`, keyed on a non-empty top-level `memory_candidates` array
  (the positive direction from this task's amendment scope). This follow-up task also owes the
  decision on the durable sink the sweep's advisory output lands in — deliberately left open
  here, not settled.
- The one pre-existing, unrelated `validate-context-budgets.sh` ten-agent failure against stale
  `EXCEPTIONS` caps remains unrepaired — it is not one of `verify-deploy.sh`'s 21 gates and is
  out of this task's scope (Non-Goals).

## References

- `specs/319_cross_task_claim_invalidation_surfacing/reports/01_claim-invalidation-surfacing.md`
- `specs/319_cross_task_claim_invalidation_surfacing/plans/01_claim-invalidation-sweep.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/agents/general-research-agent.md`
- `agent-system/extensions/core/scripts/sweep-invalidated-claims.sh`
- `agent-system/extensions/core/scripts/tests/test-sweep-invalidated-claims.sh`
