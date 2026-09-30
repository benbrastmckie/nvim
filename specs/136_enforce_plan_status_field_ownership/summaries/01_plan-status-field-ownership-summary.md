# Implementation Summary: Task #136

- **Task**: 136 - Implementation-agent contract corrections: plan-level Status ownership, no
  fan-out, marker/commit sync, validator catch
- **Status**: [COMPLETED]
- **Started**: 2026-09-29T00:00:00Z
- **Completed**: 2026-09-30T00:00:00Z
- **Effort**: ~10 hours
- **Dependencies**: 139 (completed), 91 (completed, archived), 13 (completed, archived)
- **Artifacts**: plans/01_plan-status-field-ownership.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Three defect threads shared one root cause -- agent contract text drifting from what
`validate-artifact.sh` enforces -- and all three are now closed on both ends: the contract text
that produced the drift, and the validator/lint layer that should catch it. All 8 plan phases are
complete: a canonical, lint-enforced plan-level-Status ownership boundary across 14 implementation
agents; a shared Status-line grammar library wired into the validator with a new error-level
check; a fixed report-heading skeleton in `general-research-agent.md`; a fan-out prohibition and
bidirectional marker/commit-synchrony contract in `phase-closure.md`; and a full redeploy with
green re-verification from the deployed tree.

## What Changed

- `agent-system/extensions/core/context/contracts/plan-status-ownership.md` -- new canonical
  fragment: the MUST-NOT bullet text, the classification rule, the in-scope enumeration (14
  files), and the clarifying-sentence text for the "Phase status lives ONLY in the heading"
  anchor.
- `agent-system/extensions/core/scripts/lib/plan-status-line.sh` -- new shared classifier
  library (`plan_status_classify`, `plan_status_error_message`), mirroring
  `update-plan-status.sh`'s M1/M2/M3 grammar exactly.
- `agent-system/extensions/core/scripts/validate-artifact.sh` -- sources the new library in the
  `plan` branch; adds an error-level Status-line grammar check; extends the exit-code header
  comment; records the `--fix` non-participation decision inline.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` -- new Check G
  (`check_g_plan_status_ownership_bullet`), wired into `main()`, `--help`, and the header
  check-list comment.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` -- 4 new Check G
  fixture cases (missing bullet, verbatim-bullet pass, near-miss-paraphrase fail,
  fragment-missing fail).
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` -- new suite: Status
  grammar (5 shapes), `--fix` non-participation, report-heading conformance (3 cases), depth
  tolerance, and a cross-script conformance guard against `update-plan-status.sh`.
- `agent-system/extensions/core/context/contracts/phase-closure.md` -- new `## No fan-out to
  phase sub-agents` section (with terminal-status corollary) and new `## Marker/commit
  synchrony is bidirectional` section; corrected a stale claim about `skill-orchestrate/SKILL.md`
  carrying a discoverability reference (grep found none).
- `agent-system/extensions/core/agents/general-implementation-agent.md` -- 3 new MUST-NOT
  bullets (no fan-out, no promotion-without-evidence, plan-status ownership); 2 clarifying
  sentences; 1 `phase-closure.md` reference-description update.
- 13 other implementation agents (`cslib` x2, `founder`, `latex`, `lean` x2, `nix`, `nvim`,
  `python`, `rust`, `typst`, `web`, `z3`) -- ownership bullet, clarifying sentence (anchor-adjacent
  or own-instruction-adjacent), and reference-description update, each in its own commit.
- `agent-system/extensions/core/agents/general-research-agent.md` -- promoted `### Recommendations`
  to top-level `## Recommendations`; added the verbatim/non-paraphrasable five-heading statement
  naming both observed near-misses.
- `agent-system/extensions/core/index-entries.json` -- new entry for
  `contracts/plan-status-ownership.md` (found missing by doc-lint during Phase 8's full gate run;
  fixed in place).
- `agent-system/extensions/core/manifest.json` -- registered `lib/plan-status-line.sh` and
  `tests/test-validate-artifact.sh` in `provides.scripts`.
- `specs/TODO.md` -- regenerated (date-stamp only) to resolve a state/TODO sync warning surfaced
  during Phase 8's gate run.

## Decisions

1. **`--fix` non-participation (consistent with decision D-A, not reopening it)**. The new
   Status-line grammar check does NOT participate in `--fix`. Three independent grounds, recorded
   inline in `validate-artifact.sh`'s header comment: (a) the existing `--fix` machinery only ever
   inserts a placeholder for an *absent* metadata field -- it has never rewritten an
   author-supplied value, so a grammar repair would be a new mutation class; (b) M3 offers no
   derivable intent and M1 no anchor, so two of three malformed shapes are unrepairable by any
   general rule anyway; (c) auto-repair would erase the only signal that an agent hand-wrote the
   line, defeating this task's own producer-side purpose. Verified: `--fix` on an M2 fixture
   leaves the Status line byte-identical and the error is still reported. Consistent with decision
   D-A (`--fix` remains in-place-mutating on the gate-out path in general) -- declined here on
   these three specific grounds, not because in-place repair is categorically forbidden.
2. **Fan-out resolution: prohibited, with a read-only carve-out, plus a terminal-status
   corollary.** `phase-closure.md`'s new `## No fan-out to phase sub-agents` section states flatly
   that a dispatched implementation agent MUST NOT delegate plan-phase execution to sub-agents --
   the dispatched agent alone owns its `.return-meta.json`/`.orchestrator-handoff.json`, and a
   parent returning while children still run was the observed failure (twice in one dispatch
   batch, each leaving `status: "in_progress"`). Read-only search/exploration fan-out is exempt
   (cannot leave work uncommitted). The terminal-status corollary states the dispatched agent
   writes its own terminal status before returning, retiring the per-dispatch prompt-text
   workaround by moving the same wording into the contract every in-scope agent already loads.
3. **Bidirectional marker/commit synchrony.** `phase-closure.md`'s new `## Marker/commit synchrony
   is bidirectional` section states both directions as requirements: promotion-on-commit (a
   phase's marker promotion is committed together with its final work, never deferred) and
   no-promotion-without-evidence (a marker is promoted only after this dispatch's own verification
   has actually run and been observed green -- an inherited marker on a resumed dispatch is
   re-verified, never trusted on sight). Both directions are independently necessary: the
   over-claim incident (five of seven phases `[COMPLETED]` against an unmodified `file_scope`) was
   caught only by an orchestrator cross-check against the working tree, and tightening
   promotion-on-commit alone would not have caught it.

## Grep Evidence: Ownership-Boundary Rollout (14/14 files)

Every in-scope implementation agent carries the ownership bullet, verified by
`grep -qF` against the fragment's exact bullet text, not by assumption:

| File | Carries bullet |
|------|-----------------|
| `core/agents/general-implementation-agent.md` | PASS |
| `cslib/agents/cslib-implementation-agent.md` | PASS |
| `cslib/agents/cslib-implementation-hard-agent.md` | PASS |
| `founder/agents/founder-implement-agent.md` | PASS |
| `latex/agents/latex-implementation-agent.md` | PASS |
| `lean/agents/lean-implementation-agent.md` | PASS |
| `lean/agents/lean-implementation-hard-agent.md` | PASS |
| `nix/agents/nix-implementation-agent.md` | PASS |
| `nvim/agents/neovim-implementation-agent.md` | PASS |
| `python/agents/python-implementation-agent.md` | PASS |
| `rust/agents/rust-implementation-agent.md` | PASS |
| `typst/agents/typst-implementation-agent.md` | PASS |
| `web/agents/web-implementation-agent.md` | PASS |
| `z3/agents/z3-implementation-agent.md` | PASS |

**Scope deviation from the plan's own hypothesis**: the plan hypothesized 13 files, explicitly
excluding `founder/agents/founder-implement-agent.md`. Re-running the predicate sweep at
implementation time (a file is in scope iff its contract instructs editing a
`### Phase N: ... [MARKER]` heading) found this exclusion was wrong: `founder-implement-agent.md`
genuinely edits phase-heading markers via the Edit tool (e.g. `old_string: "### Phase 1: {Phase
Name} [IN PROGRESS]"` / `new_string: "...[COMPLETED]"`), identically to the other 13 confirmed
agents. Per the plan's own instruction ("if the sweep yields a different set, the sweep wins"),
the file was added as the 14th in-scope agent. `epidemiology/agents/epi-implement-agent.md`,
`cslib/agents/pr-review-implementation-agent.md`, and `email/agents/email-implementation-agent.md`
were re-confirmed correctly OUT of scope (zero phase-heading marker edit instructions in any of
the three).

Enforcement of this 14-file set is now mechanical: `lint-agent-contracts.sh` Check G iterates
`OWNERSHIP_IN_SCOPE_RELATIVE_PATHS` (identical to the fragment's recorded list) and fails naming
any file missing the bullet -- verified by temporarily removing the bullet from
`general-implementation-agent.md` (lint exits 1, names the file) and restoring it (lint returns to
0 failures).

## Machine-Check Table: Core Skeleton Enumeration (Phase 6)

Every core agent's embedded skeleton, extracted to a temp file and checked against
`validate-artifact.sh`'s own `^##+ {section}` regex for each of `REPORT_SECTIONS`,
`SUMMARY_SECTIONS`, and `PLAN_SECTIONS` -- not by eye:

| Agent | Skeleton type | Result |
|-------|---------------|--------|
| `general-implementation-agent.md` | Summary | 6/6 `SUMMARY_SECTIONS`, all top-level |
| `general-research-agent.md` | Report | 5/5 `REPORT_SECTIONS`, all top-level (fixed this task; previously 4/5, `Recommendations` buried as `### Recommendations` under `## Findings`) |
| `planner-agent.md` | Plan | 7/7 `PLAN_SECTIONS`, all top-level |
| `code-reviewer-agent.md` | (skeleton present) | Matches none of the three required arrays fully -- authors no validated artifact type |
| `spawn-agent.md` | (skeleton present) | Matches none of the three required arrays fully -- authors no validated artifact type |
| `meta-builder-agent.md` | -- | No embedded skeleton |
| `reviser-agent.md` | -- | No embedded skeleton |

All results match the plan's Scope Hypothesis exactly; no further gaps found among the seven core
agents.

## Report-Heading Fix Verification (Phase 6)

The historically observed failure was reproduced in a fixture and shown fixed:
- A report carrying `## Recommended Next Steps (for the plan phase)` and `## Context Extension
  Recommendations` but no `## Recommendations` -> `[ERROR] Missing required section: ##
  Recommendations` (reproduces the real incident).
- The same fixture with a top-level `## Recommendations` added -> `[PASS]`.
- `## Context Extension Recommendations` **alone** (the dispatch's explicit requirement) -> still
  FAILs, proving the check was not relaxed into a false pass.
- Depth tolerance preserved: a report whose only conforming heading is `### Recommendations`
  (nested) still PASSes, locking in the `^##+` any-depth semantics.

## Plan Deviations

- **Task 1.2** altered: `founder/agents/founder-implement-agent.md` added to the in-scope set
  (14 files, not the plan's hypothesized 13) -- see Grep Evidence section above for the full
  reasoning.
- **Task 2** (Scope Hypothesis) altered: rolled out to 14 files, not 13.
- **Task 3.4(b)** altered: fixture (b) (verbatim bullet, no FAIL) uses
  `cslib/agents/cslib-implementation-agent.md` rather than reusing fixture (a)'s
  `general-implementation-agent.md`, since that path is already committed as Check C's own
  "missing bullet" negative fixture; fixture (c) (near-miss paraphrase) uses
  `lean/agents/lean-implementation-agent.md`.
- **Task 4.1** altered: re-swept the plan conformance count at implementation time -- 199 plans
  (not the planning-time 193), still 0 non-conforming.
- **Task 7.4** altered: "12 extension agents" in the plan text corrected to 13 (14 total in-scope
  files minus the 1 core agent), consistent with the Phase 1 deviation.
- **Task 7.5** altered: `phase-closure.md`'s "Loaded via explicit reference in BOTH modes" section
  claimed `skill-orchestrate/SKILL.md` carries a discoverability reference to it; a repo-wide
  `grep -rl "phase-closure.md"` found zero occurrences in that file. Corrected in place rather
  than repeated.
- **Task 8 (unplanned, discovered during the full gate run)**: `check-extension-docs.sh` Rule S
  failed because the new `plan-status-ownership.md` context file had no entry in
  `agent-system/extensions/core/index-entries.json`. Added an entry mirroring
  `no-task-references-bullet.md`'s shape (fixed in place; doc-lint now passes clean).
- **Task 8 (unplanned)**: `validate-state.sh --deep` reported "TODO.md is OUT OF SYNC with
  specs/state.json" (a date-stamp drift from concurrent same-cycle task activity, not from this
  task's own edits). Regenerated via `generate-todo.sh` (fixed in place; validation now passes
  with only its four pre-existing advisory warnings).

## Verification

- Build: N/A (shell scripts and markdown contracts, no compiled artifact)
- Tests:
  - `test-validate-artifact.sh` (new suite): 18/18 PASS.
  - `test-lint-agent-contracts.sh` (4 new Check G cases added): 26/26 PASS.
  - Mutation checks: reverting the Status-grammar check in `validate-artifact.sh` makes the suite
    go RED (13/18); perturbing `plan-status-line.sh`'s M3 branch makes it go RED (16/18, including
    the cross-script conformance guard); both restored to green afterward.
  - Removing the ownership bullet from `general-implementation-agent.md` makes
    `lint-agent-contracts.sh` exit 1 naming that file; restoring it returns to 0 failures.
  - `verify-deploy.sh`'s gate 6 (agent contracts lint) passes from the deployed tree.
  - `run-all.sh` (full 105-suite source-store run): 97 passed, 8 failed at last full run; all 8
    failures are in suites this task never touches (typst element-lint under task 255's
    concurrent territory, and other pre-existing suites) -- both of this task's own suites verified
    independently green as listed above.
  - `check-extension-docs.sh --quiet`: PASS (after the index-entries.json fix).
  - `validate-state.sh --deep`: PASS with warnings (after the TODO.md regen; the four remaining
    warnings are pre-existing `file_scope` coarseness advisories unrelated to this task).
  - Deployed-tree re-verification: Check G passes via `.claude/scripts/lint/lint-agent-contracts.sh`
    (187 passed, 0 failed); the new fixtures pass via `.claude/scripts/tests/test-validate-artifact.sh`
    (18/18); `.claude/scripts/lib/plan-status-line.sh` exists and is sourced without the exit-5
    environment error.
  - This plan file itself: `validate-artifact.sh <this plan> plan` -> `[PASS]`, and its own
    `- **Status**:` line classifies `OK`.
- Files verified: Yes (all new/modified files confirmed present and correct via direct read/grep)

## Impacts

- An implementation agent that hand-edits the plan-level `- **Status**:` metadata field (the
  producer-side root cause of the original incident) now violates an explicit, lint-enforced MUST
  NOT bullet across all 14 agents capable of making that mistake.
- A plan file carrying a malformed Status line (missing brackets, no bracket pair, text between
  the prefix and the bracket) is now caught by `validate-artifact.sh` as an ERROR, not silently
  passed -- closing the validator-side gap that let the original incident's malformed line
  validate `[PASS]`.
- A produced research report that drifts from the required `## Recommendations` heading (the
  near-miss trap) is now guarded against by both a fixed skeleton (top-level, not buried) and an
  explicit non-paraphrasable statement in the authoring agent's own contract.
- Fan-out to phase sub-agents is now a contract-level prohibition (with a stated terminal-status
  corollary) rather than a per-dispatch prompt-text workaround, and phase-marker promotion now
  carries an explicit bidirectional synchrony requirement against committed reality.

## Follow-ups

- **Deferred**: refactor `update-plan-status.sh`'s three inline classification branches onto
  `scripts/lib/plan-status-line.sh` so there is exactly one implementation of the M1/M2/M3 grammar
  rather than two kept in sync by a conformance test. Deliberately excluded from this task's scope
  boundary (that script belongs to a different task's `file_scope`); currently guarded against
  drift by this task's own cross-script conformance guard in `test-validate-artifact.sh`.
- **Not in this task's scope, observed during Phase 8's full gate run** (pre-existing, unrelated):
  three `context/contracts/*.md` content-hash mismatches from an earlier lean4-parity-copy task,
  one `postflight-boundary-lint` finding against `skill-lean-research/SKILL.md`, an orchestrator
  eager-load context-budget overage, and 8 `run-all.sh` suite failures outside this task's own two
  suites (predominantly a concurrently-active sibling task's typst-extension territory). None of
  these were introduced by this task and none are in its `file_scope`.

## References

- `specs/136_enforce_plan_status_field_ownership/plans/01_plan-status-field-ownership.md`
- `specs/136_enforce_plan_status_field_ownership/reports/01_plan-status-field-ownership.md`
- `agent-system/extensions/core/context/contracts/plan-status-ownership.md`
- `agent-system/extensions/core/context/contracts/phase-closure.md`
- `agent-system/extensions/core/scripts/lib/plan-status-line.sh`
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh`
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh`
