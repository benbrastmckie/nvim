# Implementation Summary: Task #155

- **Task**: 155 - Thread an advisory `--compare` flag through the lean implementation path
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T00:54:19Z
- **Completed**: 2026-09-08T01:19:05Z
- **Effort**: ~1.5 hours
- **Dependencies**: `lean-comparator-run.sh` (exists, tested, untouched), `lean-challenge-snapshot.sh` (exists, tested, untouched)
- **Artifacts**: plans/01_compare-flag-lean-threading.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Threaded an opt-in, advisory-only `--compare` flag end to end: from `parse-command-args.sh`,
through `/orchestrate`'s dispatch machinery (both the single-task `skill-orchestrate/SKILL.md`
implement sites and the multi-task `orchestrate-cycle-plan.sh` engine), into both Lean
implementation skills' delegation contexts, into both Lean implementation agents' Final
Verification Stage as a gated Comparator step, out into a documented `comparator` block in
`.return-meta.json`, and back up into both skills' postflight surfacing. The gate runs
leanprover/comparator (a kernel-backed judge) against the snapshot Challenge and the implemented
Solution, scoped to the plan's named theorems, but per the operator's binding decision it can
never fail a build: a non-`verified` verdict is recorded and surfaced loudly, never used to set
`verification_passed: false`, downgrade `status` to `partial`, or block completion.

## What Changed

- `agent-system/extensions/core/scripts/parse-command-args.sh` — added `COMPARE_FLAG` (header
  doc, default, `--compare` match block, `FOCUS_PROMPT` strip, export), modeled on `LIT_FLAG`.
- `agent-system/extensions/core/commands/orchestrate.md` — `--compare` options-table row;
  `--hard` composability note updated to name it.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — `compare_flag` default,
  `--compare` case, usage-line mentions, and `build_args` forwarding scoped to implement-phase
  candidates only (`[ "$compare_flag" = "true" ] && [ "$g" = "implement" ] && build_args+=(--compare)`).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `compare_flag` default,
  `--compare` case, usage-line mentions, and conditional emission of a single
  `- compare_flag: true` line into the dispatch file's `## Identity` section (emitted only when
  true, so a no-flag dispatch file is byte-identical to before this task).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — `compare_flag` added to the
  Stage 0/Stage 1 documented input list and to Stage MT-1's; forwarded at the three confirmed
  implement-phase dispatch sites (`build_args` line + `context` table row); also forwarded at the
  multi-task engine's own call into `orchestrate-cycle-plan.sh` (Stage MT-3), a site the plan's
  literal grep pattern did not catch but which is required for `--compare` to have any effect in
  multi-task mode.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — new
  `### comparator (optional)` section: full field table, both verdict vocabularies (`runner`'s 9
  values, `preflight`'s 4 new values), and the binding advisory-contract Notes.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — new gated step 6 in the
  Final Verification Stage: gate-first, four ordered preflight checks
  (`challenge_missing`/`challenge_drift`/`solution_module_unresolved`/`solution_module_ambiguous`),
  the `lean-comparator-run.sh --json` invocation, `comparator` block recording, and the inline
  advisory MUST NOTs.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — the structurally
  identical step 6, in the file's own terser voice.
- `agent-system/extensions/lean/skills/skill-lean-implementation/SKILL.md` — `compare_flag` in
  the delegation context (Stage 3); a "subagent will" bullet; new `### Stage 6c: Comparator
  Verdict Surface (Read from Metadata)` immediately after Stage 6b; a conditional Stage 9 summary
  bullet; two new `MUST NOT` entries.
- `agent-system/extensions/lean/skills/skill-lean-implementation-hard/SKILL.md` — the same
  additions: `compare_flag` beside `"effort_flag": "hard"` (composes, does not replace); a
  `Stage 6c` placed immediately after the pre-existing Stage 6b (not literally between the
  pre-existing 6a/6b, to avoid renumbering Stages 7-10 — documented inline); a conditional
  Stage 10 summary bullet; two new `MUST NOT` entries.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new Group 9
  (byte-identity without `--compare`; exactly one added line with it).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 12
  (`--compare` reaches an implement-phase candidate's build_args, not a plan-phase candidate's;
  `--compare --hard` reach the same dispatch together).

## Decisions

- Followed the plan's Q1-Q4 resolutions verbatim (implement-phase-only scoping,
  `solution_module` derivation reusing the Stage-5 compliance grep, the `verdict_source`
  discriminator, per-skill Stage 6c placement).
- Re-read `lean-implementation-agent.md` and `lean-implementation-hard-agent.md` fresh at edit
  time per the plan's file-collision warning; no concurrent edits were present at time of read
  (`git status --short` on both files was clean; last touching commit was an unrelated summary-
  skeleton addition).
- Additionally threaded `compare_flag` through `skill-orchestrate/SKILL.md`'s Stage MT-3 call
  into `orchestrate-cycle-plan.sh` — not named by the plan's literal
  `grep -n 'build_args+=(--lit)'` Scope Hypothesis (that call uses a `$(... echo --lit)` shape,
  not `build_args+=(--lit)`), but required: it is the multi-task engine's only call site into the
  script that now accepts `--compare`, and omitting it would leave that capability unreachable
  from `/orchestrate` in multi-task mode.
- Placed the hard skill's new `Stage 6c` immediately after the pre-existing `Stage 6b: Sorry
  Inventory Propagation` rather than literally between the pre-existing `Stage 6a`/`Stage 6b`, to
  avoid renumbering `Stage 7`-`Stage 10`. No external file references these stage numbers by
  name (confirmed by search), so this was a safe, lower-churn substitution for the same
  structural slot the base skill's own `Stage 6c` occupies.

## Plan Deviations

- None (implementation followed plan). The one addition beyond the plan's literal grep-derived
  scope (the multi-task engine's `Stage MT-3` call site) and the one placement adjustment (hard
  skill's `Stage 6c` position) are recorded above as decisions, not deviations from the plan's
  substance — both are required consequences of, not departures from, the plan's own stated goal
  ("`--compare` reaches an implement-phase dispatch") and structural-parity requirement.

## Verification

- Build: N/A (no Lean build touched; this is pure wiring across markdown/bash/context files)
- Tests: Passed — `test-orchestrate-build-dispatch.sh` 58/58, `test-orchestrate-cycle-plan.sh`
  89/89 (85 pre-existing + 4 new), `test-lean-comparator-run.sh` 22/22 (1 skip, unchanged from
  before this task)
- Files verified: Yes — every modified `.sh` file passes `bash -n`; every fenced bash block added
  to the four agent/skill markdown files passes `bash -n` when extracted; the deploy/validation
  gate (`bash .claude/scripts/deploy-headless.sh`) reports `RESULT=landed_verify_clean`

## Comparator Advisory Findings (this task's own dispatch)

None — this task's own implementation work involved no Lean proof changes, so `--compare` was
never invoked against this task's own output. This section exists per the plan's requirement to
name any non-`verified` verdict prominently; it is empty here because there was nothing to
report for this dispatch's own artifacts. See "ACCEPTANCE Evidence" below for the verdicts the
new gate *itself* was proven to produce, live, against test fixtures.

## ACCEPTANCE Evidence

All five ACCEPTANCE bullets plus the two named preflight verdicts were demonstrated **live**
(not merely by inspection), by extracting the exact bash logic added to
`lean-implementation-agent.md` (and, for the postflight half of A3, to
`skill-lean-implementation/SKILL.md`'s Stage 6c) and executing it against controlled fixtures —
a fixture git repo standing in for a Lean project, a synthetic `challenge/manifest.json`, and
(for A2/A3) a stubbed `landrun`/`lean4export`/`lake`/`comparator` toolchain built with the exact
same stub technique `test-lean-comparator-run.sh` already uses for its own verdict-classification
cases:

| Criterion | Verdict observed | Source |
|-----------|-------------------|--------|
| A1 (no-flag parity) | dispatch file diff = exactly 1 added line (`- compare_flag: true`) | live diff against `orchestrate-build-dispatch.sh`; codified as Group 9 |
| A2 (honest implementation) | `verdict=verified source=runner solution_module=Theories.Solution` | live, extracted agent step, stubbed toolchain |
| A3 (weakened statement, still completes) | `verdict=statement_mismatch source=runner`; Stage 6c printed the loud advisory block AND left `status=implemented` unchanged | live, extracted agent step + extracted Stage 6c |
| A4 (composition) | both `--compare` and `--hard` present in the same implement `build_args` | live, Group 12's second case |
| A5 (missing binaries) | `verdict=comparator_unavailable source=runner` (message names `lean4export`) | live, REAL `lean-comparator-run.sh` against the REAL host environment (`lean4export` genuinely absent) |
| `challenge_missing` | `verdict=challenge_missing source=preflight` | live, extracted agent step, no manifest present |
| `challenge_drift` | `verdict=challenge_drift source=preflight`, `reason_detail` names both mismatched hashes | live, extracted agent step, deliberately wrong `content_sha256` |
| `solution_module_unresolved` (not separately named in ACCEPTANCE, exercised anyway) | `verdict=solution_module_unresolved source=preflight` | live, extracted agent step, no matching theorem declaration |
| `solution_module_ambiguous` (not separately named in ACCEPTANCE, exercised anyway) | `verdict=solution_module_ambiguous source=preflight`, both candidate files named | live, extracted agent step, two files declaring the same theorem name |

No acceptance bullet required fallback to pure by-inspection tracing; the Rollback/Contingency
section's fixture-level fallback plan was not needed.

## Impacts

- Every existing lean4 `/orchestrate` dispatch (no `--compare`) is provably unaffected: no new
  metadata block, no Comparator invocation, no runtime cost, byte-identical dispatch files.
- A caller that opts in with `--compare` gets a kernel-backed statement/axiom/kernel-replay check
  layered on top of the existing grep-based Final Verification Stage checks, without that check
  ever being able to block completion.
- The `comparator` block is now a documented part of the metadata schema, so any future
  automation (dashboards, `/distill`, promotion-criteria tracking) has a stable field contract to
  read from rather than an undeclared ad hoc field.

## Follow-ups

- **Promote to a hard gate** — a separate, later, evidence-based decision. Concrete promotion
  criteria (see below) should be tracked before that decision is revisited.
- A2/A3's live demonstration used a STUBBED `comparator`/`landrun`/`lean4export` toolchain
  (following `test-lean-comparator-run.sh`'s own established technique) because the real
  `lean4export` binary is still absent on this host; `test-lean-comparator-run.sh`'s own Case E1
  remains `SKIP`ped for the same reason. Re-running both once the real toolchain is provisioned
  (tracked by a sibling `~/.dotfiles/` task outside this repository, per that test's own skip
  message) would convert this task's own live evidence from "real script, stubbed dependencies"
  to "fully real, no stubs at any layer."
- The multi-task engine's Stage MT-3 forwarding addition (see Decisions) was not named by the
  plan's literal grep-derived Scope Hypothesis; a future reader auditing this task against the
  plan alone should know to look for it there rather than conclude it was missed.

## Promotion Criteria

Concrete, evidence-based conditions for promoting this gate from advisory to blocking — recorded
now so that later decision has evidence to stand on rather than being taken on vibes, per the
dispatch's own instruction:

1. **Volume and diversity**: at least **20 consecutive `verified` runs** across **at least 5
   distinct target projects** (not 20 runs of the same project/theorem set) with `--compare`
   active, with **zero** `comparator_unavailable` verdicts and **zero** `preflight`-sourced
   verdicts (`challenge_missing`, `challenge_drift`, `solution_module_unresolved`,
   `solution_module_ambiguous`) in that run set. A `preflight` verdict in the qualifying set means
   the harness itself is not yet reliable enough to gate on; it must first stabilize to near-zero
   friction under advisory use before being trusted to block.
2. **Toolchain provisioning stability**: `landrun`, `lean4export`, and `comparator` (and
   `nanoda_bin`/`external_kernels` if those are ever used) must be provisioned and version-pinned
   in the environment(s) where implementation dispatches actually run — not merely present on one
   developer machine — for the same qualifying period as (1). `lean4export`'s version-coupling
   caveat (C3: it must match the TARGET project's Lean version, not Comparator's own) should have
   at least one recorded cross-check confirming this was respected across the qualifying runs.
3. **Runtime budget evidence**: a measured **p95 wall-clock `runtime_seconds`** across the
   qualifying run set, compared against an agreed budget (the constraint that motivated
   `--timeout`'s existing 1800s default in `lean-comparator-run.sh`). If p95 runtime materially
   exceeds what a typical implementation dispatch's overall timeout can absorb, promotion should
   wait for either a faster path or a documented timeout-budget increase policy.
4. **At least one true-positive demonstration in the qualifying period**: at least one advisory
   run in the qualifying window (or immediately prior to it) that caught a genuine statement
   weakening, axiom violation, or kernel rejection that the EXISTING grep-based checks (plan
   compliance spot-check, `axiom_count`, vacuous-definition grep) did NOT catch — evidence that
   the gate is adding real signal beyond what already exists, not just duplicating it.
5. **No `definition_hole_needs_human` friction**: since `--definitions` is deliberately never
   passed by this gate (Non-Goal), `definition_hole_needs_human` should not appear in the
   qualifying run set at all; if it does, that indicates an invocation-shape bug worth fixing
   before promotion, not a Comparator finding to route around.

Only once conditions (1)-(5) are jointly satisfied should promoting the gate from advisory
(`MUST NOT` set `verification_passed`/`status`/block completion) to blocking be considered, and
that promotion itself should be a separate, explicit, human-approved task — never an automatic
consequence of accumulating this evidence.

## References

- Plan: `specs/155_thread_compare_flag_through_lean_implementation/plans/01_compare-flag-lean-threading.md`
- Research: `specs/155_thread_compare_flag_through_lean_implementation/reports/01_compare-flag-lean-threading.md`
- Schema: `agent-system/extensions/core/context/formats/return-metadata-file.md`'s
  `### comparator (optional)` section
- Design record referenced throughout: `agent-system/extensions/lean/context/project/lean4/domain/comparator-integration.md`
