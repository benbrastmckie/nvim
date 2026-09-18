# Implementation Summary: Task #193

- **Task**: 193 - Carry concurrent-sibling territory in base-mode dispatch briefs
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T17:33:09Z
- **Completed**: 2026-09-18T18:55:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None (197 and 213 already landed; 165 is a coordination target, not a blocker)
- **Artifacts**: plans/01_base-mode-territory-briefs.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Multi-task `/orchestrate` in base mode used to dispatch concurrent sibling tasks onto one shared
working tree with no way for any dispatch to know the others existed — the mechanism
(`--territory`, the `## Territory` dispatch-file section, the `territory.md` contract pointer)
existed but was wired for hard mode only. This implementation adds a `concurrent_siblings`
payload built in EVERY mode by `orchestrate-cycle-plan.sh` from every other task scheduled the
same cycle, each classified by an explicit `file`/`coarse`/`undeclared` file-scope granularity,
merges it into the existing hard-mode H1 territory literal rather than replacing it, pulls in the
`territory.md` contract for base-mode dispatches, and documents the full contract. A fixture
reproduces the observed batch shape (narrow, undeclared, coarse, and empty-array file scopes
mixed in one cycle) and proves the payload now carries what concurrent agents previously lacked.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — Added
  `build_sibling_territory()` and `_sibling_territory_classify_entry()` helpers, a header contract
  block, and live-loop wiring that populates `--territory` for every dispatch a multi-task cycle
  builds (base and hard mode alike) from `probed_dispatch_post_h1` minus the dispatching task
  itself, reading each sibling's `file_scope` via the existing `lookup_project` helper. Merges into
  the hard-mode H1 owned-files literal under a `concurrent_siblings` key when both are present.
  Replaced the stale "absent from every base-mode call" comment. `aux_dispatch[]` rows are
  deliberately excluded, documented with the reason (no `--territory` plumbing in
  `orchestrate-build-aux-dispatch.sh`; aux kinds are short research/revision calls, not
  file-editing implement dispatches).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — Added a
  `context/contracts/territory.md` pointer line inside the existing `## Territory` block for every
  case except `hard_mode=true AND phase=implement` (the one case where `core_contracts` already
  pulls the contract in via `<hard-mode-contracts>`), plus a header contract block documenting the
  new base-mode behavior.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — New Group 13
  (Cases A-D): base-mode `--territory` renders the pointer and no `<hard-mode-contracts>`;
  hard-mode research also gets the pointer (its own `core_contracts` never lists `territory.md`);
  hard-mode implement does NOT duplicate the pointer; no `--territory` stays byte-identical to the
  prior behavior. Also inverted this suite's SUT resolution to source-store-first (discovered the
  suite was validating the stale deployed `.claude/scripts/` copy against this exact edit —
  documented precedent: `test-force-phases.sh`'s own candidate-resolution inversion).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — New Group 25
  (Cases A-E): a 4-task base-mode fixture mixing narrow-file, undeclared (key-omitted),
  coarse-directory, and explicit-empty-array `file_scope` declarations in one cycle; each task's
  own `--territory` payload correctly names its siblings with the right granularity/undeclared
  classification; a single-task-cycle regression guard (no `--territory` at all); and a hard-mode
  H1 merge case (owned_files literal plus `concurrent_siblings` coexist).
- `agent-system/extensions/core/context/contracts/territory.md` — New `## Cross-Task Territory
  (Base Mode)` section (payload shape with example, granularity/undeclared vocabulary, agent
  obligations, relationship to H7/absent-scope-admission/working-tree-isolation), and an updated
  opening paragraph naming both consumers (hard-mode H1 and the multi-task cycle planner in every
  mode).
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Fixed a stale claim
  found by the Phase 4 grep: Stage 3.6's Observation Duty said base mode never sends a `territory`
  delegation-context parameter, which this task makes false for a multi-task cycle with a
  concurrent sibling.

## Decisions

- Emit the sibling payload in every mode, including hard mode, merged into the existing H1
  territory literal rather than replacing it, so hard mode also gains this cross-task fact.
- Emit for every phase group (research/plan/implement); a single-task cycle (no siblings)
  therefore produces a byte-identical dispatch file, which is the regression guard.
- Granularity is explicit and never silently dropped: `file` / `directory` / `glob` per entry,
  rolling up to `file` / `coarse` / `undeclared` per sibling, with an explicit sentinel for an
  absent, `null`, or empty-array `file_scope`.
- No admission-posture decision made here — an absent or coarse `file_scope`'s effect on
  admission remains owned entirely by `orchestrate-batch-admit.sh`'s separate work; this payload
  only represents the absence/coarseness.
- Sequencing rationale is one fixed, generic procedural instruction (re-read before editing, stage
  only your own hunks, never run a reverting `git-snapshot.sh`, treat foreign-scope build failures
  as possibly a sibling's, STOP-and-report after a `git log` self-check) rather than a fabricated
  per-pair claim, since nothing in the codebase computes non-idempotence between two specific
  tasks.
- `aux_dispatch[]` rows are deliberately excluded from `concurrent_siblings` (documented, not a
  silent gap): their builder has no `--territory` plumbing and their short research/revision
  nature does not carry the file-collision risk this payload guards against.

## Plan Deviations

- **Phase 1, "Optionally surface a `territory_siblings` count on `--dry-run` rows"**: skipped —
  the plan itself marked this optional/not-required; `--dry-run` never builds dispatch files, so
  adding the count would require duplicating the sibling-list computation for no consumer benefit.
- **Phase 3, Case F** (an aux-dispatched sibling appears with its `aux:` phase label): skipped —
  the plan's own condition ("only if aux rows were included in Phase 1") is false, since Phase 1
  deliberately excluded aux rows for the documented reason above.

## Verification

- Build: N/A (shell scripts + markdown)
- Tests: Passed — `test-orchestrate-cycle-plan.sh` 221/221, `test-orchestrate-build-dispatch.sh`
  92/92
- shellcheck: Clean at `-S warning` on all four touched shell files, relative to the pre-existing
  baseline (`orchestrate-cycle-plan.sh` carries the same two pre-existing SC2154 notices it had
  before this task)
- `check-task-references.sh agent-system/extensions/core`: PASS, 0 unexempted occurrences
- Files verified: Yes

## Impacts

- A concurrent multi-task `/orchestrate` batch (the default, common case for `/orchestrate
  A,B,C`) now informs every dispatched agent of its scheduled siblings and their declared file
  territory, in every mode — directly addressing the two recorded incidents (2026-09-08 and the
  2026-09-17 RECURRED four-task batch) where sibling collisions went undetected because no
  dispatch knew a concurrent sibling existed.
- Hard-mode H1 dispatches now also carry cross-task sibling awareness alongside their existing
  within-task owned-files territory, closing a gap that existed even in hard mode.
- No change to admission behavior, dispatch concurrency, or working-tree isolation — this is
  purely an informational payload addition.

## Follow-ups

- The absent/coarse-`file_scope` admission-posture decision remains open, owned by the separate
  `orchestrate-batch-admit.sh` work this task explicitly deferred to.
- Working-tree or build isolation between concurrent dispatches remains a distinct, unimplemented
  remedy noted in `territory.md`'s new section.
- Whether mid-flight mailbox delivery to a running dispatch is fixable was explicitly out of
  scope per the task description's "CONSIDER, DO NOT PRE-COMMIT" note; not investigated here.

## References

- Plan: `specs/193_carry_territory_in_base_mode_dispatch_briefs/plans/01_base-mode-territory-briefs.md`
- Research: `specs/193_carry_territory_in_base_mode_dispatch_briefs/reports/01_base-mode-territory-population.md`
- Contract: `agent-system/extensions/core/context/contracts/territory.md`
