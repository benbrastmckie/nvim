# Implementation Summary: Task #236

- **Task**: 236 - Define external process wait pattern
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T23:28:00Z
- **Completed**: 2026-09-18T23:34:00Z
- **Effort**: 2 hours (estimated); actual within estimate
- **Dependencies**: None (task 172 / `bounded-build-waiter.md` is a cross-reference, not a
  dependency)
- **Artifacts**: plans/01_external-process-wait-pattern.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Created a new core context pattern file,
`agent-system/extensions/core/context/patterns/external-process-wait.md`, that states the
observed external-process-wait defect class once and defines six mandatory rules for a subagent
blocked on a long remote job (GitHub Actions first, generalized to any remote/external job with
no local writer to probe). Made it discoverable via an `index-entries.json` entry and added a
one-line pointer from `anti-stop-patterns.md`.

## What Changed

- `agent-system/extensions/core/context/patterns/external-process-wait.md` — Created (129 lines).
  Header (Created/Purpose/Audience/Related), "The Defect" (four-part incident), "Required Rules"
  (six subsections: bounded blocking wait with the 540 < 600 arithmetic explained, no no-op
  filler, no `run_in_background`/Monitor for CI waits in a subagent, legitimate-Monitor
  state-change-only emission, do independent local work first, 45-minute total-wait cap with
  handoff+`partial`), "Generalizing Beyond GitHub Actions", "Local vs. Remote Waits" (forward
  pointer to `bounded-build-waiter.md` by filename), and "Related Documentation".
- `agent-system/extensions/core/index-entries.json` — Added one on-demand entry for
  `patterns/external-process-wait.md` (`line_count: 129`, empty `load_when`, `on_demand: true`),
  inserted in path-sorted position among the `patterns/*` entries. Also corrected the pre-existing
  `patterns/anti-stop-patterns.md` entry's `line_count` from 174 to 177 — a drift this task's own
  3-line pointer addition introduced, caught by `check-extension-docs.sh`.
- `agent-system/extensions/core/context/patterns/anti-stop-patterns.md` — Added one pointer
  sentence under `## Background References` > `### Internal Documentation`, naming
  `context/patterns/external-process-wait.md` without restating its rules.

## Decisions

- Used the measured `wc -l` value (129) for the index entry's `line_count`, and fixed the
  `anti-stop-patterns.md` entry's own `line_count` in the same commit rather than leaving a
  self-introduced drift for a later gate to catch.
- Kept the index entry Tier-4 shaped (`on_demand: true`, empty `load_when.agents`), matching
  `early-metadata-pattern.md`'s convention — discovery is via keywords and the
  `anti-stop-patterns.md` pointer, not eager auto-injection.
- Cross-referenced `bounded-build-waiter.md` by filename only (it does not exist yet); the
  reciprocal pointer is explicitly deferred to whichever task authors that file.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A (documentation/context-index task)
- Tests: N/A
- Files verified: Yes — `wc -l` = 129 matches the index entry's `line_count`; `jq empty` passes
  on `index-entries.json`; `check-task-references.sh` finds 0 unexempted occurrences across the
  three touched files; `check-extension-docs.sh` shows no FAIL attributable to this task's edits
  (the one remaining core FAIL, `patterns/batch-orchestration-guardrails.md`, belongs to
  concurrently-dispatched sibling task 228's in-flight territory); `validate-context-index.sh`
  passes with 0 errors.

## Impacts

- Any future dispatched subagent (implementation or research) that hits a long external-process
  wait (GitHub Actions or another remote job) now has a canonical, discoverable rule set instead
  of reinventing ad hoc polling behavior.
- `anti-stop-patterns.md` gains a one-line pointer to the new file without duplicating content.
- No agent contracts, hooks, or `orchestrate-build-dispatch.sh` were changed — wiring the new
  pattern into those surfaces remains out of scope for this task, per its description.

## Follow-ups

- A separate, dependent task should wire `external-process-wait.md` into the relevant agent
  contracts, `orchestrate-build-dispatch.sh`, or a hook, if and when that enforcement is desired.
- Whichever task authors `bounded-build-waiter.md` (the local detached-build case) should add the
  reciprocal pointer back to `external-process-wait.md`, as this file's "Local vs. Remote Waits"
  section already anticipates.

## References

- Plan: `specs/236_define_external_process_wait_pattern/plans/01_external-process-wait-pattern.md`
- New pattern file:
  `agent-system/extensions/core/context/patterns/external-process-wait.md`
- Index entry: `agent-system/extensions/core/index-entries.json`
- Pointer: `agent-system/extensions/core/context/patterns/anti-stop-patterns.md`
