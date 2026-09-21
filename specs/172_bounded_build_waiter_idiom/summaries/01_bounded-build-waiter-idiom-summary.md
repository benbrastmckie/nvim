# Implementation Summary: Task #172

- **Task**: 172 - Define a canonical bounded-wait idiom for detached builds
- **Status**: [COMPLETED]
- **Started**: 2026-09-21T00:00:00Z
- **Completed**: 2026-09-21T23:14:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_bounded-build-waiter-idiom.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Wrote the previously-missing canonical anchor `bounded-build-waiter.md`, which states the
unbounded-waiter defect class once (a sentinel poll with no writer-liveness backing it, a
turn-ending stop in place of a bounded wait, and a process-name self-match) and defines a safe,
generic waiter for any detached local command. Wired it in from three carriers: the Lean
`long-builds.md` operations doc, core's `index-entries.json`, and the always-present
dispatch-file Wait Discipline block that every `/orchestrate` dispatch receives, so
general-implementation-agent (and every other dispatched agent, not only Lean ones) reaches it.

## What Changed

- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — new file (120
  lines). Header block (Created/Purpose/Audience/Related), "The Defect" (naming all three
  incidents by repository and symptom, never by task number), "Two Symptoms, One Missing
  Affordance", four numbered "Required Rules" (hard timeout; PID-captured writer liveness, never
  name-matching; dead writer ends the wait immediately; one waiter per log with
  attach-or-fail-loudly), "The Canonical Idiom", "Conforming Examples" (`lake-build-guard.sh`'s
  own `kill -0` idiom, a generic gate-script), "Local vs. Remote Waits" (reciprocal of
  `external-process-wait.md`'s section), and "Related Documentation".
- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` — added a new
  `## Blocking on a detached build` section between "Passive progress checks" and "Completion
  discipline" pointing at the new anchor (single-statement-plus-pointer convention, no restated
  model), plus one added sentence in "The liveness caveat" distinguishing liveness observation
  from a genuine blocking wait.
- `agent-system/extensions/core/index-entries.json` — new `patterns/bounded-build-waiter.md`
  entry, copied from the `external-process-wait.md` entry shape (domain `core`, subdomain
  `patterns`, accurate `line_count: 120`, the seven specified keywords, topics
  `workflow`/`orchestration`, empty `load_when` arrays, `on_demand: true`).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the unconditional
  `## Wait Discipline` echo block now also points at `context/patterns/bounded-build-waiter.md`
  for a detached local command, alongside the existing `external-process-wait.md` pointer for
  remote waits; the header comment above the block now names both anchors.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — Group 14
  gained matching `assert_contains` assertions for the new pointer across all six
  base/hard x research/plan/implement combinations, plus a single-occurrence guard mirroring the
  existing `external-process-wait.md` guard.

## Decisions

- Followed the plan's decision to include the `orchestrate-build-dispatch.sh` Wait Discipline
  edit (Phase 3) rather than deferring it, since the third evidence round in the task description
  explicitly required the pointer to reach general-implementation-agent and the script is neither
  an agent file nor one of the three files the description forbids touching.
- Used the deploy-tree-relative citation form (`context/patterns/bounded-build-waiter.md`) for
  the cross-extension pointer in `long-builds.md`, matching the convention already used
  throughout the source store for citations from one extension's context files into core's (e.g.
  `context/patterns/dispatch-report-not-termination.md`), rather than a source-store filesystem
  relative path — the latter is used only for links between files inside the same extension's own
  merge-source tree, where source-store and deployed layout coincide.
- Left the new `bounded-build-waiter.md`'s own `Related:` header and "Related Documentation"
  cross-reference to `long-builds.md` as a genuine source-store-relative path
  (`../../../lean/context/project/lean4/operations/long-builds.md`), since Phase 1's own
  verification criterion required every relative cross-reference in that specific file to resolve
  under `agent-system/extensions/` as a literal filesystem path.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A
- Tests: Passed — `test-orchestrate-build-dispatch.sh` 113/113; `test-index-entries-schema.sh`
  9/9; `jq empty` on `index-entries.json` succeeds; `validate-context-index.sh` on the deployed
  index reports 222 entries, 0 errors, 0 warnings; `bash -n orchestrate-build-dispatch.sh`
  succeeds.
- Files verified: Yes — all five touched files exist and are non-empty; every
  `bounded-build-waiter.md` inbound pointer (`external-process-wait.md` x3,
  `long-builds.md`, `index-entries.json`, the dispatch script) resolves to the file.

## Impacts

- Any future dispatched agent (general, meta, Lean, or otherwise) that reads the always-present
  Wait Discipline block in its dispatch file now has a sanctioned, bounded idiom for blocking on a
  detached local command, closing the affordance gap that previously produced both unbounded
  sentinel-poll loops and turn-ending stops.
- The Lean `long-builds.md` operations doc now distinguishes passive liveness observation from a
  genuine blocking wait, with the blocking case pointing at the shared anchor instead of leaving
  it undocumented.
- `external-process-wait.md`'s "Local vs. Remote Waits" section, which already named this file as
  a forward reference, now resolves to a real, non-dead-ending sibling.

## Follow-ups

- Guard-side, reaper-side, and agent-contract dependent tasks (explicitly out of scope here) still
  need to: (1) add the explicit MUST NOT against ending a turn on an unresolved background wait to
  agent contracts, (2) add postflight detection of a stop lacking a handoff or
  `.return-meta.json`, and (3) mechanically enforce one-waiter-per-log (lock files or guard
  changes) — this task states the policy only.
- `check-extension-docs.sh`, run in source-store mode as an optional Phase 4 check, reports
  expected script-content drift between the source store and this repo's currently-deployed
  `.claude/` copy for `orchestrate-build-dispatch.sh` and its test — this is inherent to editing
  the source store without redeploying (out of scope per this task's Non-Goals) and is not a
  content defect in the changes themselves.

## References

- `specs/172_bounded_build_waiter_idiom/plans/01_bounded-build-waiter-idiom.md`
- `specs/172_bounded_build_waiter_idiom/reports/01_bounded-build-waiter-idiom.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- `agent-system/extensions/core/context/patterns/external-process-wait.md`
