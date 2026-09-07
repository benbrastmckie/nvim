# Implementation Summary: Task #154

- **Task**: 154 - Make lean plans carry exact theorem statements and emit an immutable trusted Challenge snapshot
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T17:00:00Z
- **Completed**: 2026-09-07T17:50:00Z
- **Effort**: ~4 hours (plan estimated 12.75)
- **Dependencies**: None
- **Artifacts**: plans/01_lean-challenge-statement-snapshot.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Established the trusted Challenge that constraint C1 (no Challenge exists today) named as missing:
a recorded, exact theorem *statement* fixed before the implementation agent runs, plus
`lean-challenge-snapshot.sh`, a script that turns a plan's declared statements into an immutable,
git-committed Challenge module `lean-comparator-run.sh` accepts. All 8 plan phases completed. The
decided route is R1 (plan-declared statements via a new `## Lean Challenge Statements` plan
section), with R2 (git-baseline extraction) as a loudly-degraded legacy fallback. Immutability is
achieved by committing the Challenge into the target project's own git history and pinning
callers to the resulting SHA, backed by a process-level status gate that refuses regeneration once
a task has moved past `planned`. The independent value the task's description called out — closing
the system's largest verification hole, where a same-named weaker restatement passes the existing
name-only compliance grep silently — is delivered via a Comparator-independent `--check`
statement-drift mode, demonstrated on a real Lean project (`~/Projects/cslib`) in both directions.

## What Changed

- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — new design
  record: R1-vs-R2 decision with comparison table, storage/immutability mechanism (git-SHA
  pinning + independent `content_sha256`), manifest schema, exit-code vocabulary (aligned with
  `lean-comparator-run.sh`'s own codes), advisory-only gate-strength restatement, and a
  "Demonstrated Behaviour" section recording the real Phase 8 evidence.
- `agent-system/extensions/core/context/formats/plan-format.md` — new, additive
  `## Lean Challenge Statements` section (gated on `task_type: lean`/`lean4`, mirroring the
  existing `## Planned Strategic Sorries` conditional-section precedent) plus its `## Structure`
  list entry; non-lean plans are provably untouched (validated before/after on two existing
  non-lean plans with identical outcomes).
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` — new script (788 lines).
  CLI: `<task_number> <project_root> [--commit REF] [--challenge-module NAME] [--force]
  [--dry-run] [--json]`, plus `--check`. Implements R1 extraction (fenced-block concatenation
  with forced `sorry` bodies), R2 legacy fallback (git-baseline declaration extraction with
  import-lifting, hard-fails on ambiguity/missing), identifier cross-validation (`**Goals**:` vs
  the declared set), commit + manifest + status-gate immutability mechanism
  (`git commit --allow-empty` so a byte-identical regeneration still gets a fresh SHA), and the
  `--check` statement-drift mode (whitespace/comment-normalized signature comparison, excluding
  the pinned Challenge file itself from the current-tree search).
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — new regression
  suite, 13 cases (R1-R4, M1-M3, C1-C5, AV1), all passing; carries the anti-vacuous-test guard
  (naive exit-code-nonzero classifier cannot distinguish drift-65 from config-error-71, this
  suite's own value-level assertions can).
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/*` — 6 new fixtures (an R1 plan,
  a legacy plan, a mismatched-identifier plan, and honest/weakened/cosmetic Solution variants).
- `agent-system/extensions/lean/rules/plan-compliance.md` — new `## Statement Fidelity`
  subsection: a `## Lean Challenge Statements` section's declared signatures are part of the
  compliance contract, not only identifiers; a new Forbidden Patterns bullet naming statement
  weakening; cross-referenced to the rule's existing escalate-rather-than-substitute (`[BLOCKED]`)
  behavior and to `--check` as the advisory mechanical check.
- `agent-system/extensions/lean/manifest.json`, `agent-system/extensions/lean/index-entries.json`,
  `agent-system/extensions/core/index-entries.json` — registration and line-count sync for the new
  files (`provides.scripts` entries; index entries for the design record and the widened
  `plan-format.md`).

## Decisions

- **R1 primary, R2 demoted to a logged fallback** — R2 structurally cannot serve a greenfield
  theorem (the case the task exists to close); R1 costs an additive plan section but has exact
  planner-intent fidelity. Full comparison table recorded in `challenge-snapshot.md`.
- **Immutability = git content-addressing, not filesystem permissions** — reuses the same
  `--commit REF` trust primitive `lean-comparator-run.sh` already assumes, at two independent
  layers: a process-level status gate (refuse past `planned`) and a mechanism-level SHA pin plus
  independent `content_sha256` witness.
- **`git commit --allow-empty`** for the Challenge write — a `--force` re-run whose content is
  byte-identical to what is already committed must still yield a fresh commit SHA representing a
  distinct regeneration event, rather than failing with "nothing to commit" (found and fixed
  during Phase 4 testing).
- **`--check`'s current-tree search excludes the manifest's own `challenge_path`** — otherwise a
  still-present, un-deleted `Challenge.lean` in the working tree would trivially self-match
  instead of comparing against the real implementation.
- **Script invocation convention**: `lean-challenge-snapshot.sh` must be invoked with CWD set to
  (or containing) the target project's own `specs/` tree — a lean/lean4 task's plan and its
  target `.lean` sources are assumed to share one git repository, which is what makes R2's
  "plan's approval commit" lookup meaningful.
- **`--check` normalization is whitespace/comment collapsing only** — a cosmetically renamed
  bound variable is not alpha-normalized and would report as drift; documented explicitly as a
  stated limitation rather than attempting full alpha-equivalence checking, per the phase's own
  "anything it cannot decide is reported as drift" allowance.
- **Phase 8 used R1, not R2, against the real project** — cslib's real theorems are heavily
  namespaced (`Proposition.map_injective`-style dotted names) which the extractor's identifier
  regex does not capture as one token; rather than widen scope to fix R2's dotted-name gap, two
  plain, undotted real theorems (`embedFormula_neg`, `embedFormula_and`) were selected and R1 was
  used, keeping the demonstration real without expanding scope. This dotted-name gap in R2 is
  noted as a known, unaddressed limitation (R2 is the degraded fallback, scoped to declaration
  shapes this codebase's own style guide already produces, per the plan's own risk mitigation).

## Plan Deviations

- None (implementation followed plan). Test-suite case count (13) exceeds the plan's 11-case
  hypothesis, which the plan explicitly permits ("adding cases is fine, dropping one requires a
  stated reason"); no case was dropped.

## Verification

- Build: N/A (bash/markdown/JSON, no compiled build step)
- Tests: Passed — `test-lean-challenge-snapshot.sh` 13/13; sibling suites
  `test-lean-comparator-run.sh` (22 passed, 1 named SKIP for missing `lean4export`/`comparator`
  end-to-end) and `test-lean-sorry-census.sh` (14/14) both still pass with no regression.
- Files verified: Yes — every path in `lean/manifest.json`'s `provides.scripts` confirmed to
  exist on disk; `check-deploy-freshness.sh` and `check-task-references.sh --quiet` both clean;
  `check-extension-docs.sh` shows zero NEW findings (the one remaining FAIL,
  `comparator-integration.md`'s stale line-count entry, pre-dates this task and was never touched
  by it).
- Real-project acceptance demonstration (Phase 8, against a `git clone --no-hardlinks` scratch
  copy of `~/Projects/cslib`, deleted afterward): Challenge module/`theorem_names` match the
  vendored Comparator fixture shape; commit SHA and `content_sha256` both independently
  retrievable and verified; a real weakened theorem statement was flagged (`--check` exit 65,
  naming only that theorem) and an honest restoration was not (exit 0); the status-gate refusal
  (exit 73) and `--force` incident warning were both captured, with the original commit's content
  and hash confirmed intact after the bypass. The end-to-end sandboxed `comparator`/`lean4export`
  run itself is an explicit, named SKIP (`lean4export` absent on this host; `landrun` and
  `comparator` are present, contrary to the shared background's 2026-09-07 measurement).
  `~/Projects/cslib` and `~/Projects/BimodalLogic` both confirmed byte-identical
  (`git status --porcelain` and `git log -1`) before and after the demonstration.

## Impacts

- `lean-implementation-agent`'s Final Verification Stage compliance check (name-existence grep
  only) now has an available, opt-in, Comparator-independent statement-fidelity check
  (`--check`) it can be wired to consume in a future task — not wired in by this task, per its
  explicit Non-Goals.
- `plan-format.md`'s new `## Lean Challenge Statements` section is available to any future
  lean/lean4 plan; non-lean plans are unaffected (validated).
- `plan-compliance.md` now has a textual basis (Statement Fidelity) for treating a same-named
  weaker restatement as a forbidden pattern, closing a gap the rule's own decomposition-only
  framing previously left open.
- The manifest schema (`{schema_version, task_number, plan_path, project_root, challenge_module,
  challenge_path, theorem_names, route, commit, content_sha256, created_at}`) is now the fixed
  interface a downstream Comparator compare-step task can consume for its
  `--commit`/`--challenge-module`/`--theorems` arguments.

## Follow-ups

- R2's declaration-name regex does not capture dotted/namespaced Lean identifiers
  (`Namespace.member`) as a single token — a real limitation surfaced during Phase 8 fixture
  selection, not fixed here since R2 is the degraded fallback and Phase 8 substituted a
  plain-named real example instead. A future task widening R2's realistic-project coverage should
  address this.
- Wiring `--check` (or the underlying Comparator compare step, once `lean4export` is provisioned)
  into `lean-implementation-agent`'s Final Verification Stage is explicitly out of this task's
  scope (ADVISORY FIRST gate-strength decision) and is the natural next step for a downstream
  task.
- The pre-existing, unrelated `comparator-integration.md` index-entries.json line-count drift
  (declared 219, actual 247) was noted but not fixed — outside this task's `file_scope`.

## References

- Plan: `specs/154_lean_challenge_statement_snapshot/plans/01_lean-challenge-statement-snapshot.md`
- Research report: `specs/154_lean_challenge_statement_snapshot/reports/01_lean-challenge-statement-snapshot.md`
- Design record: `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
- Progress files: `specs/154_lean_challenge_statement_snapshot/progress/phase-{1..8}-progress.json`
- Handoffs: `specs/154_lean_challenge_statement_snapshot/handoffs/phase-1-handoff-*.md`,
  `specs/154_lean_challenge_statement_snapshot/handoffs/phase-7-handoff-*.md`
