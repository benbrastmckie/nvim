# Implementation Summary: Task #489

- **Task**: 489 - Derive gate-count expectations from the live gate registry
- **Status**: [COMPLETED]
- **Started**: 2026-11-06T21:50:00Z
- **Completed**: 2026-11-07T01:15:00Z
- **Effort**: ~6.75 hours (matches plan estimate)
- **Dependencies**: Serialized behind records 328, 435, 448, 418, 414 (shared declared paths)
- **Artifacts**: plans/01_registry-derived-gate-count-expectations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Converted every gate-count expectation in `test-gate-registry-resolution.sh` and
`test-verify-deploy-gate-selection.sh` (plus two further sites found during planning,
`test-verify-deploy-gate-selection-crash-net.sh` and `measure-gate-costs.sh`) from hardcoded
integers to values derived at test time from the live gate registry. Added a reusable
`gate_registry_max_id` accessor and a `gate_store_fixture_build` fixture-store builder, two
cross-source drift guards (G1, G2), and a permanent throwaway-gate fixture proof in both target
suites demonstrating that registering a new gate requires zero suite edits — the task's
acceptance bar.

## What Changed

- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — added `gate_registry_max_id`
  (prints the largest loaded id, empty/rc=0 when nothing is loaded); stale "23-gate" header prose
  made count-free.
- `agent-system/extensions/core/scripts/lib/gate-store-fixture-lib.sh` — new file: builds a
  throwaway, path-mirrored copy of the gate source store with one extra synthetic gate id, for
  use by the fixture-gate proof cases.
- `agent-system/extensions/core/manifest.json` — registered the new library file.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `--only-gate`'s bound is now
  single-sourced on `gate_registry_max_id` (was an inline max loop); degrade-safe stub added; the
  `23` missing-library fallback and both error-message strings preserved byte-identical.
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` — default `GATE_LIST` now derives
  from `gate_registry_ids` with a degrade-safe fallback to the literal `1-23` (with a stderr
  warning) when the registry library is unavailable; explicit `--gate` path untouched; stale
  prose counts made count-free.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh` —
  the crash-net id set now derives from `gate_registry_ids` instead of `seq 1 23` (this one
  previously under-covered silently, never going red).
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` — stale "23-gate"
  header prose made count-free.
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` — case1,
  case14, case32, case33 converted to derive from an independently-awk-read
  `REGISTRY_IDS_EXPECTED`/`REGISTRY_MAX`; added Guard G1 (cross-checks `verify-deploy.sh`'s own
  reported bound); added case1-NC (negative control, non-vacuity proof); added cases 35-39
  (throwaway-gate fixture proof, reusing an `ids_match_check` function shared with case1).
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — case (c)'s
  out-of-range probe and case (d)'s enumeration converted to derive from `REGISTRY_MAX`/
  `REGISTRY_IDS`; case (d) is now Guard G2, a two-directional set-equality check via a reusable
  `noflag_header_set_check` function; added case (s) (throwaway-gate fixture proof, reusing the
  same function).
- A regenerated deployed `.claude/` tree (via `deploy-headless.sh`).

## Decisions

- Every converted assertion derives its expectation from a source INDEPENDENT of the function
  under test (an awk re-read of the raw data file), never from `gate_registry_ids` itself, to
  avoid a silently-vacuous self-comparison.
- The throwaway-gate fixture proof reuses the exact same comparison functions
  (`ids_match_check`, `noflag_header_set_check`) for both the real-registry case and the
  fixture-store case, so the two cannot silently diverge into two copies of the same check.
- `gate_store_fixture_build` inserts the throwaway gate function into both the copied library
  AND the copied `verify-deploy.sh` (a second, inert, byte-identical copy), because
  `lint-gate-registry.sh`'s Check A greps `verify-deploy.sh`'s text only.
- Both suites' fixture cases pass the real `$REPO_ROOT` as `verify-deploy.sh`'s TARGET argument
  (not the fixture store's own root), since `verify-deploy.sh` requires TARGET to already hold a
  deployed `.claude/` tree before it reaches gate dispatch at all; the fixture builder
  deliberately does not create one.

## Plan Deviations

- Phase 3 included three further sites of the identical defect class beyond the two suites the
  dispatch description named as "the sole remaining place" (the crash-net suite, the cost-model
  script, and three stale prose counts) — within the plan's own stated scope, not a deviation
  from it.
- The fixture-gate proof's extra id is derived (`$((REGISTRY_MAX + 1))`, landing on 28) rather
  than the plan's prose-assumed literal 27, because the real registry's live max moved from 26
  to 27 partway through this dispatch (a sibling task registered a real gate 27 concurrently).
- Phase 7 closed `[COMPLETED WITH EXCLUSIONS]`: the deploy itself landed successfully (all 9
  `file_scope` files confirmed byte-identical deployed-vs-source), but the post-deploy
  full-battery check and the independent full-battery run were both discharged with documented,
  evidence-backed exclusions — see the plan's Phase 7 Reasoned Exclusions table for the full
  record (a Batch Gate Deferral directive, and two confirmed-unrelated findings: a pre-existing
  load-sensitive gate10 timeout, and two memory-extension doc violations naming a dead `/ide`
  command).

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: `test-gate-registry-resolution.sh` 44/44 passed; `test-verify-deploy-gate-selection.sh`
  24/24 passed; `test-verify-deploy-gate-selection-crash-net.sh` 1/1 passed;
  `test-measure-gate-costs.sh` 12/12 passed; `test-gate-cache-lib.sh` 28/28 passed. Final
  28-suite resolver-selected covering run for `verify-deploy.sh`: 25/28 passed, 3 failures all
  confirmed pre-existing/unrelated (2 EXPECTED per `run-all.sh`'s own baseline, 1 naming suites
  outside this task's scope). Non-vacuity demonstrated for every converted mechanism via
  scratch edit-then-revert or isolated-function probes, each confirmed by an empty `git diff`
  after reverting.
- Files verified: Yes (all 9 `file_scope` files confirmed byte-identical deployed-vs-source
  after `deploy-headless.sh`)

## Impacts

- Registering a future gate now requires zero edits to either target suite, the crash-net suite,
  or the cost-model script — mechanically proven, not merely asserted, via the fixture-gate
  cases that will keep running on every future suite invocation.
- `gate_registry_max_id` and `gate_store_fixture_build` are now reusable primitives for any
  future gate-registry-related tooling or test work.
- Directly fixed a real, observed regression: sibling task 418's registration of a real gate 27
  made `test-verify-deploy-gate-selection.sh`'s case (c) go red during this very dispatch; this
  task's Phase 5 conversion is what resolved it, confirmed in the final covering run.

## Follow-ups

- The two Reasoned-Exclusion findings from Phase 7 (gate10's load-sensitive timeout threshold;
  the memory extension's dead `/ide` command references) are pre-existing and unrelated to this
  task — left for separate follow-up work, not addressed here.
- `scripts/gate-registry.data`'s own stale "23-gate"/"25-gate" prose comments (lines ~29, ~74)
  were explicitly out of scope (a declared Non-Goal: that file is not modified by this task) and
  remain stale.

## References

- Plan: `specs/489_derive_gate_count_expectations_from_registry/plans/01_registry-derived-gate-count-expectations.md`
- Progress files: `specs/489_derive_gate_count_expectations_from_registry/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/489_derive_gate_count_expectations_from_registry/handoffs/`
- Issue log: `specs/489_derive_gate_count_expectations_from_registry/issues.jsonl`
