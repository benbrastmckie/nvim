# Implementation Summary: Task #221

- **Task**: 221 - Correct the lean implementation-agent contracts: build-verdict method, waiter teardown, no-revert snapshot
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T00:45:00Z
- **Completed**: 2026-09-22T01:07:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 172, 173, 194 (all completed)
- **Artifacts**: plans/01_build-verdict-evidence-contracts.md (this round)
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the verification-evidence vacuum a live incident exposed: an agent used a process count
(a self-matching `pgrep -f`) as evidence of a finished build's outcome. Added a single canonical
"Reading the build's verdict" evidence hierarchy to the lean extension's long-build operations
doc, closed the PID-source gap in "Passive progress checks" with an explicit `pgrep -f`
self-match prohibition, pointed every `build_passed` determination site in both lean
implementation agents at that hierarchy, wired the teardown rule's supersession case and fix-site
list, and added an identical `--no-revert` bullet to both lean agents for `orchestrator_mode`
dispatches. All six plan phases completed; source-store edits verified via mechanical grep
audits, the guard's 47-case regression suite, and a redeploy.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/operations/long-builds.md` — added
  `## Reading the build's verdict` (three-tier hierarchy, strongest last: guard exit code/`result`,
  success-line + zero `error:` count, `.olean`-newer-than-source), the un-piped-capture
  prohibition, a PID-source lead-in and `pgrep -f` self-match prohibition (with bracket-trick
  escape hatch) in "Passive progress checks", and a sharpened liveness caveat pointing forward to
  the new section.
- `agent-system/extensions/lean/rules/lean4.md` — added the un-piped capture form
  (`> <log> 2>&1; GUARD_EXIT=$?`) under "Build Commands", pointing at the new anchor rather than
  restating it.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — Final Verification step 4
  now determines `build_passed` from the terminal full-project bar (Tier 1 + Tier 2 + Tier 3 for
  touched modules) by pointer, notes the unpiped harness exit code, and points at the
  waiter/teardown obligations; added a `--no-revert`-under-`orchestrator_mode` bullet next to the
  `.orchestrator-handoff.json` section.
- `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md` — Stage 4 step D now
  determines the phase-end verdict from the scoped bar (Tier 1 + Tier 3); Stage 6 step 4 now uses
  the terminal full-project bar; both cite the waiter/teardown pointer; added the identical
  `--no-revert` bullet next to the Stage 5 wrap-up/handoff section.
- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` — extended
  "Tear Down Watchers/Monitors Before Reporting" to cover the supersession/cancellation case, and
  added both lean agents' build-verdict sites to "Where This Is Referenced" (now 5 entries).
- `specs/221_lean_build_verdict_evidence_contracts/plans/01_build-verdict-evidence-contracts.md` —
  all six phases marked `[COMPLETED]`; checklist items annotated.

## Decisions

- Followed the plan's verdict-bar-per-site-type decision exactly: terminal full-project sites
  (plain agent step 4, hard agent Stage 6 step 4) require all three tiers; the hard agent's Stage
  4 scoped phase-end check requires only Tier 1 + Tier 3 (Tier 2 optional).
- Trimmed an initial draft of the lean4.md pointer that restated the prohibition's rationale
  ("that reads the pipe's exit code, not the guard's") — the duplication-check risk mitigation in
  the plan caught this before it landed; the final text points at the anchor for both the
  hierarchy and the prohibition.
- Added the waiter/teardown pointer at both hard-agent sites (step D and Stage 6 step 4)
  separately rather than once in a shared spot, since the plan allowed either and separate pointers
  keep each site self-contained.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (documentation/contract task; no Lean build involved)
- Tests: Passed — `test-lake-build-guard.sh` 47/47 (including case 21, the `--help` self-match
  assertion; no guard file was touched by this task)
- Files verified: Yes

### Phase 6 acceptance-check detail

- Duplication check: clean after the lean4.md trim above — the tier list and the pipe-prohibition
  rationale appear only in `long-builds.md`.
- `pgrep` audit (`grep -rn pgrep agent-system/extensions/lean/`): the only hit outside
  `long-builds.md`'s own (correct) prohibition text is a pre-existing, untouched line in
  `operations/multi-instance-optimization.md` (`htop -p $(pgrep -d, -f 'lean|lake')`), out of this
  task's file_scope and not a build-verdict recommendation.
- Verdict-site audit: all three `build_passed`/step-D determination sites now name their method
  and bar; the remaining `build_passed` mentions (JSON output examples, the hard agent's Stage 8
  metadata-field list) are output-shape only, confirmed unchanged.
- Anchor integrity: `## Reading the build's verdict` and `## Tear Down Watchers/Monitors Before
  Reporting` both exist verbatim at their cited headings; `bounded-build-waiter.md` exists.
- Deliverable rule: `check-task-references.sh` (run from the deployed `.claude/scripts/` copy,
  repo-wide) reports `PASS: 0 unexempted task-reference occurrences across 4 tree(s)`.
- Redeploy: `deploy-headless.sh` landed the tree. `verify-deploy.sh`'s fast-gate run reported one
  FAIL — a hand-rolled bare `git commit -m` string inside a pre-existing, untouched test fixture
  (`agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh:152`, a quoted example
  string `git commit -m "true"` used to test the noop-bash-detection hook's classifier). This is
  unrelated to and outside this task's five-file `file_scope`; it was not introduced by this
  task's edits and is left for a future dispatch to address under the scoped-commit-boundary lint.
- Deploy-tree diff — **finding, not a plain pass**: the lean extension is **not currently loaded**
  in this repository's `.claude-extensions.json` (only `nix`, `nvim`, `email`, `literature`,
  `core`, and `memory` are loaded here). Consequently none of the four lean-scoped edited files
  (`long-builds.md`, `lean4.md`, `lean-implementation-agent.md`,
  `lean-implementation-hard-agent.md`) has a deployed `.claude/` counterpart to diff against at
  all — a more basic condition than the plan's anticipated "merged or templated" risk. Only the
  fifth, core-scoped file has a live counterpart
  (`.claude/context/patterns/dispatch-report-not-termination.md`); `diff` against it is byte-empty.
  The source-store edits themselves were verified directly (the grep audits above, plus manual
  read-back of every edited section) since no deploy round-trip was available for them in this
  repo. A repo where the lean extension IS loaded (e.g. a Lean project) will pick up all five
  edits on its own next `deploy-headless.sh` run, since these are ordinary source-store changes.

## Impacts

- Both lean implementation agents (plain and hard) now have an unambiguous, single-sourced method
  for determining a build's pass/fail verdict, closing the exact vacuum that let a self-matching
  `pgrep -f` process count stand in for build evidence in the observed incident.
- The teardown rule's supersession clause and lean fix-site list close the specific gap the
  absorbed former-task-175 text identified: the governing rule already existed but named no fix
  site that a build-waiter-arming lean agent would ever consult.
- Both lean agents now carry the same `orchestrator_mode` → `--no-revert` discipline already
  present in `general-implementation-agent.md`, closing the calling-convention gap the absorbed
  former-task-198 text identified (default-mode `git-snapshot.sh` reverting a concurrent sibling's
  in-flight edits).

## Follow-ups

- Recorded for the git-snapshot script-level remedy (per the absorbed former-task-198 text): its
  currently-recorded design direction keys the proposed refusal on "tracked paths OUTSIDE the
  task's declared `file_scope`". That predicate does not cleanly cover the concurrent-sibling case
  this task's absorbed text observed, where a sibling's edits fall INSIDE an overlapping declared
  scope. A live-concurrent-dispatch predicate is a distinct condition from an out-of-file_scope
  predicate; this task's contract bullet is a convention-level interim mitigation only, not a
  substitute for that structural remedy.
- Scope ceiling (per the same absorbed text): this task's `--no-revert` bullet addresses only the
  working-tree-revert failure mode of concurrent dispatch. It does not address, and should not be
  read as evidence against, the other two observed failure modes: cross-task commit bleed via
  whole-path staging on a shared file, and `.lake` build contention. Those remain open, tracked
  elsewhere (the isolation-posture task named in the dispatch).
- The pre-existing `test-detect-noop-bash.sh` scoped-commit-boundary lint violation (noted above
  under Phase 6) is outside this task's file_scope and was left untouched; a future dispatch
  should route that test fixture's string through the lint's existing quote-stripping exemption
  mechanism or otherwise satisfy the lint.
- When this task's five source-store edits reach a repository where the lean extension is loaded,
  confirm the deploy-tree diff there (this repo could not exercise that path).

## References

- specs/221_lean_build_verdict_evidence_contracts/plans/01_build-verdict-evidence-contracts.md
- specs/221_lean_build_verdict_evidence_contracts/reports/01_build_verdict_evidence_contracts.md
- agent-system/extensions/lean/context/project/lean4/operations/long-builds.md
- agent-system/extensions/lean/rules/lean4.md
- agent-system/extensions/lean/agents/lean-implementation-agent.md
- agent-system/extensions/lean/agents/lean-implementation-hard-agent.md
- agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md
