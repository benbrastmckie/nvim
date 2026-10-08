# Phase 3/4/6 Handoff: Migration-script phases closed by operator directive

## Immediate Next Action
Proceed to Phase 5 (deploy-propagation harness assertions) and Phase 7 (markdown templates),
both of which remain fully in scope and are unaffected by this exclusion.

## Current State
Mid-implementation, the operator sent an explicit scope-change instruction: do not write the
migration script for already-deployed repos, because the operator is separately
reloading/redeploying the agent system to every consumer repo, which reaches already-deployed
repos directly and supersedes the "install-once root-files cannot reach already-deployed repos"
premise (D3) that made the migration script mandatory in the original plan.

Actions taken:
- A draft `agent-system/extensions/core/scripts/migrate-hook-registration-paths.sh` had already
  been written and smoke-tested (bash -n, --help, dry-run + real-run + idempotency against a
  scratch fixture, including the jq-based dedup logic) before the directive arrived. It was never
  committed (confirmed via `git status --porcelain`) and has been deleted per the operator's
  instruction not to leave dead code behind.
- No `test-migrate-hook-registration-paths.sh` had been started.
- No `progress/phase-3-progress.json` had been created yet, so no progress-file cleanup was
  needed.
- Plan file updated: Phase 3, Phase 4, and Phase 6 headings closed `[COMPLETED WITH EXCLUSIONS]`,
  each with a `#### Reasoned Exclusions` table citing the operator instruction as evidence. Every
  task checkbox in those three phases annotated `*(deviation: skipped — ... see Reasoned
  Exclusions)*`. Goals, Non-Goals, Testing & Validation, Artifacts & Outputs, and
  Rollback/Contingency sections updated to strike the migration-dependent claims and record the
  disposition of acceptance criteria 1, 2, 5, and the existing-repo half of criterion 6.
- Issue logged via `issue-record.sh` (class `scope-change`, severity `minor`).

## Key Decisions Made
- Phase 6 was excluded even though the operator's message named only "the migration script (and
  the migration-specific test for the no-duplicate criterion)" explicitly (Phase 3 and part of
  Phase 4) — Phase 6's entire task list invokes the now-deleted script, so it is a direct, total
  dependent and was excluded on the same grounds, named explicitly here so it does not read as an
  oversight.
- Phase 5's duplicate-registration assertion was NOT excluded: it tests fresh-install-time
  cross-file divergence (root-files vs. merge-sources) via `deep_merge`, which is independent of
  the dropped migration script (it is "the fresh-install half of criterion 6" per the plan's own
  phrasing, not the migration-specific half).

## Deviations from Plan
- Phase 3 (entire): migration script never written — operator scope change.
- Phase 4 (entire): migration test never written — depends entirely on Phase 3.
- Phase 6 (entire): real-deploy migration and demonstration never run — depends entirely on
  Phase 3/4.
- See each phase's `#### Reasoned Exclusions` table in the plan for the full record.

## What NOT to Try
- Do not resurrect `migrate-hook-registration-paths.sh` or its test absent a new, explicit
  instruction reopening this scope — the operator's redeploy action is the current, sanctioned
  path to already-deployed repos.

## Critical Context
Acceptance criteria 1, 2, and 5 (demonstrated against a real pre-existing deploy) are NOT
satisfied by this task. Criterion 4 (fresh deploy has zero CWD-relative paths) is unaffected and
remains absolute, to be asserted in Phase 5.

## References
- Plan: specs/364_cwd_relative_hook_registration_paths/plans/02_cwd-relative-hook-registration-paths.md
- Phases: 3, 4, 6 of 7 (all closed [COMPLETED WITH EXCLUSIONS])
