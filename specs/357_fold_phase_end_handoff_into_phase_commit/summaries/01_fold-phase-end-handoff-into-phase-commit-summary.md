# Implementation Summary: Task #357

- **Task**: 357 - Fold phase-end handoff into phase commit
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T08:50:00Z
- **Completed**: 2026-10-07T09:29:21Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fold-phase-end-handoff-into-phase-commit.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Re-confirmed, at implementation time, the research finding that no consumer anywhere in the
source store depends on the per-phase `handoffs/phase-{P}-handoff-*.md` file landing in a commit
separate from its phase's work commit. Delivered the FOLD outcome: a single-commit-per-phase
ruling recorded in `git-staging-scope.md`, a sequencing fix at the real production site
(`general-implementation-agent.md`), and cross-references from `git-workflow.md` and
`phase-closure.md`. This very implementation dispatch dogfooded the fix: each of its four phases
landed as exactly one commit, with its own phase-end handoff folded inside it.

## What Changed

- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a ruling block
  under `### implement`: exactly one commit per phase, the safety argument (no freshness
  consumer; filename-embedded timestamp survives folding), the crash-ordering rationale, the
  no-scope-widening confirmation, and a pointer to `phase-closure.md`.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — bound the phase-end
  handoff write to the phase's closing commit at three sites: Stage 4D-iii (standalone bolded
  "MUST NOT be committed separately" sentence), Phase Checkpoint Protocol step 4 (explicit
  ordering), and step 5 (one-line statement that the pathspec is the only commit this phase
  produces); added `MUST NOT` entry #14.
- `agent-system/extensions/core/rules/git-workflow.md` — qualified the `Create Commits After`
  phase-completion bullet to "exactly one commit per phase" and added a `Do Not Commit` bullet
  forbidding a trailing provenance-only commit, both as compact pointers to `git-staging-scope.md`
  (compacted mid-implementation after an initial drafting regressed the orchestrator eager-context
  budget gate — see Plan Deviations).
- `agent-system/extensions/core/context/contracts/phase-closure.md` — extended the
  promotion-on-commit bullet to name the progress file and phase-end handoff alongside the
  marker as same-commit content.
- `agent-system/extensions/core/index-entries.json` — surgical 2-line fix (not committed by this
  task; see below) updating the `line_count` fields for `contracts/phase-closure.md` (192→196)
  and `standards/git-staging-scope.md` (533→564), the two entries made stale by this task's own
  content growth (see Plan Deviations).

## Decisions

- **The load-bearing question is answered: no.** Three decisive greps were re-run against the
  current source store: (a) `handoffs/` has no row in `orchestrator-runtime-files.md`'s Class
  Table; (b) `grep -rln 'phase-.*-handoff' agent-system/ --include=*.sh` matches only three test
  files (`test-validate-handoff.sh`, `test-orchestrate-triage-classify.sh`,
  `test-handoff-reader-parity.sh`), none a production consumer; (c) every `mtime`/`dispatch_seq`
  hit in `orchestrate-cycle-postflight.sh` concerns `$handoff_file`, defined at that script's
  line 404 as `${TASK_DIR}/.orchestrator-handoff.json` — the singular JSON handoff, never the
  per-phase markdown one. None contradicted the research finding; the FOLD outcome was confirmed,
  not the load-bearing-separation outcome.
- **The crash-between-commits argument is addressed in writing, in a deliverable** (not only in
  the research report): `git-staging-scope.md`'s new block states that a crash before the single
  folded commit loses only re-doable wrap-up bookkeeping, never substantive work, because the
  mandatory per-objective green-substep commits already protect that work throughout the phase.
- **The `(tracking update)` shape is classified as a related-but-distinct defect, not folded in
  by assumption.** It shares the general family (late-sequenced provenance trailing an
  already-fired work commit) but has a different and unverified production site (plan-checklist
  and progress-file content, not a handoff file; the preceding work commit in the one measured
  instance does not even follow the `task {N} phase {P}: {phase_name}` subject convention). It is
  not ruled legitimate — no contract sanctions a trailing tracking-only commit either — and the
  new `git-staging-scope.md` block covers its *content class* on the general principle, but its
  production site is out of scope here and warrants a separate audit.
- **Folding does not widen staging scope.** `handoffs/` already lies inside the task-directory
  pathspec the `implement` scope already stages, and `git-staging-scope.md`'s own exclusion-set
  rationale already names `handoffs/` as durable content the design deliberately does not drop.

## Plan Deviations

- **Scope Hypothesis (Phase 4)**: a fifth source-store path, `index-entries.json` (JSON, not
  `.sh`), was touched in addition to the four planned `.md` files. Cause: Gate 3 (doc-lint
  Rule R) failed on `line_count` staleness for the two files this task's own edits grew
  (`phase-closure.md` 192→196, `git-staging-scope.md` 533→564). Remedy was a surgical 2-line JSON
  patch to exactly those two entries, verified via `git diff` to touch no sibling-owned entry.
  Ruled mechanical bookkeeping required by the planned edits' own growth, not scope creep — the
  "zero `.sh` files" half of the hypothesis still holds exactly, and net document count is still
  flat (no file added). `index-entries.json` is not in this task's declared `file_scope`,
  however, so the Phase-Commit Containment Self-Check drops it from this task's automated phase
  commits by design; it was recorded as a non-fatal "scope excursion" issue
  (`issue-record.sh`) and is left in the working tree as a verified, minimal, uncommitted
  correction rather than force-staged into a commit outside this task's declared scope.
- **Phase 3 (`git-workflow.md`)**: the originally-drafted cross-reference bullets (570 B added)
  regressed Gate 20 (orchestrator eager-context budget: `git-workflow.md` is eager-loaded via a
  broad `.claude/**/*` frontmatter glob), pushing the live measurement from 65,927 B to 66,159 B,
  209 B over the fixed 65,950 B baseline. Per the established precedent already recorded in
  `orchestrator-context-budget.json`'s own history (trim to compact pointer form rather than move
  a deliberately-fixed baseline), both bullets were rewritten more tersely — same ruling, same
  pointer to `git-staging-scope.md`, `git-workflow.md`'s net growth reduced from +531 B to
  +264 B. Live measurement after the trim: 65,892 B, 58 B under baseline. No baseline value was
  moved.
- No other deviation (all four phases' remaining checklist items followed the plan as written).

## Verification

- Build: N/A (no build system for this change class)
- Tests: `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet --jobs auto` — 113
  passed, 5 failed (4 pre-existing/EXPECTED per that runner's own allowlist, none referencing any
  of this task's five changed files; the 1 NEW failure,
  `test-verify-deploy-context-budget.sh`, runs a full-battery `verify-deploy.sh` against a
  real-copied fixture that shares the live `.claude/` symlink and reproduces the same
  deploy-staleness gate findings documented below — not a regression this task introduced), 2
  skipped.
- `bash .claude/scripts/verify-deploy.sh --only-gate 20`: **PASS** — eager-load total 65,892 B
  within the 65,950 B baseline (after the Phase 3 trim).
- `bash .claude/scripts/verify-deploy.sh --only-gate 5`: **FAIL** — 12 "Content differs from
  source" findings. 4 are this task's own four `.md` files; the other 8 belong to
  concurrently-dispatched sibling tasks (core/email/nix/nvim files held by siblings in this same
  `/orchestrate` cycle). This is cross-task deploy-sync lag — `.claude/` is gitignored and
  regenerated wholesale by a separate `deploy-headless.sh` step, explicitly exempted from the
  "never hand-author `.claude/**`" rule (`source-store-deploy-boundary-narrative.md`'s
  Exceptions list) — never a per-phase obligation of a single implementation dispatch. Not a
  correctness regression; left for the next deploy-and-verify cycle.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3` (doc-lint): the `index-entries.json`
  line-count findings for this task's two files are repaired (see Plan Deviations); the one
  remaining core FAIL (`deployed rule content drift: rules/git-workflow.md`) is the same
  deploy-staleness class as Gate 5, not a new defect.
- `bash .claude/scripts/check-task-references.sh` — PASS (0 occurrences) on all four changed
  `.md` files.
- Files verified: Yes — all five changed source-store files confirmed present, correctly
  modified, and committed; both ruled-out declared-scope files
  (`skill-orchestrate/SKILL.md`, `orchestrate-cycle-postflight.sh`) confirmed untouched by
  `git show --stat` on each of this task's three phase commits; no extension implementation
  agent touched; net document count flat (no file added under `agent-system/**`).

## Impacts

- Every future `/implement`-phase dispatch that reaches the Phase Checkpoint Protocol now
  produces exactly one commit per phase instead of two — halving the per-phase commit count for
  any plan that previously wrote a phase-end handoff (most multi-phase plans).
- The ruling and its evidence live in `git-staging-scope.md`, which every implementation agent
  (core and extension) already lists in its own Context References, so the contract reaches
  every implementation agent without editing each one individually.
- The `(tracking update)` commit-doubling shape remains open as a separate, unverified-production-
  site defect — recorded as a follow-up, not fixed here.

## Follow-ups

- **Extension-agent prose alignment** (recommendation, not an edit this task performed): the
  eleven extension implementation agents that independently restate the Phase Checkpoint
  Protocol in their own words (books, cslib, cslib pr-review, email, latex, nix, nvim, python,
  rust, typst, web, z3 — confirmed present in the books agent only; the remaining ten are
  unverified, consistent with the plan's own stated uncertainty) should receive the same
  sequencing correction directly, since a reader of `git-staging-scope.md`'s pointer alone may
  not reach their own duplicated prose. Deferred because those files are concurrently held by
  sibling task territory this cycle.
- **The `(tracking update)` shape** (recommendation): a separate audit should identify its actual
  production site (plan-checklist/progress-file content trailing an already-fired work commit,
  observed subject-suffixed `(tracking update)`, with at least one preceding work commit not
  following the `task {N} phase {P}: {phase_name}` convention) before ruling on remedy. Not
  folded in here; the new contract block covers its *content class* on the general
  one-commit-per-phase principle but does not assert its site is the same as the handoff's.
- **Consumer-repo consequence** (recommendation, informational): the fold changes future
  behavior only. No consumer repository was touched, and none should be — existing history in
  any consumer repository, including the Logos/Verification repo's measured eight-commit
  evidence, stays exactly as it is.
- **Uncommitted `index-entries.json` correction** (action needed, small): a verified 2-line
  `line_count` fix for `contracts/phase-closure.md` and `standards/git-staging-scope.md` remains
  uncommitted in the working tree (see Plan Deviations) because `index-entries.json` is outside
  this task's declared `file_scope` and the Phase-Commit Containment Self-Check accordingly
  drops it from this task's own commits. A future dispatch touching `index-entries.json`, or a
  manual `git add agent-system/extensions/core/index-entries.json && git commit`, should land
  it — the fix itself needs no further changes, only a commit.
- **Deploy-sync lag** (recommendation, informational): `.claude/` has not been regenerated via
  `deploy-headless.sh` since this and two sibling tasks' concurrent source-store edits landed.
  The next full `verify-deploy.sh` run after a deploy will clear the 12 Gate 5 / 1 Gate 3
  "content differs from source" findings documented above. No action needed from this task;
  recorded so the next reader does not mistake it for a regression.

## References

- Plan: `specs/357_fold_phase_end_handoff_into_phase_commit/plans/01_fold-phase-end-handoff-into-phase-commit.md`
- Research: `specs/357_fold_phase_end_handoff_into_phase_commit/reports/01_fold_phase_end_handoff_into_phase_commit.md`
- Dispatch: `specs/357_fold_phase_end_handoff_into_phase_commit/.dispatch/8.md`
