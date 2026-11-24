# Implementation Summary: Task #700

- **Task**: 700 - Bind a push grant to the pushed ref
- **Status**: [COMPLETED]
- **Started**: 2026-11-24T18:04:00Z
- **Completed**: 2026-11-24T19:10:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: None
- **Artifacts**: plans/01_bind-grant-to-pushed-ref.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A `push_branch` grant now binds, at mint time, to the commit of the ref it names (resolved via
`refs/heads/<ref>`), and is matched at consume time against that same ref's current commit,
instead of bare `HEAD`. A grant for the checked-out branch is unaffected, since that branch's
`refs/heads/<name>` is exactly what `HEAD` resolves to. All four plan phases completed: the two
production binding-site edits, nine new/amended suite cases across two suites proving the three
acceptance behaviours, one clarifying doc sentence, and a clean redeploy.

## What Changed

- `agent-system/extensions/core/hooks/please-grant.sh` — the `HEAD_SHA` mint-time assignment now
  branches on `ACTION_CLASS`: `push_branch` resolves `refs/heads/${REF}` (refusing to mint via
  the existing `exit_ok` path if unresolvable); every other class keeps `git rev-parse HEAD`.
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — the same two-branch resolution
  inside `pg_grant_find_match()`'s consume-time `head_sha` assignment, gated on the already-in-scope
  `action_class`/`ref` locals; the existing `[ -n "$head_sha" ]` fail-closed guard now covers both
  branches. The grant-file-format header comment documents the split.
- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` — `mint_grant_in` mirrors
  the production resolution (and mints nothing at all when the ref is unresolvable, matching
  `please-grant.sh`'s own fail-closed refusal). Added `make_plumbing_branch`/
  `advance_plumbing_branch` helpers (`commit-tree` + `update-ref`, never a checkout) and three
  new consume-side cases (survival across an unrelated HEAD commit, refusal once the granted ref
  moves, fail-closed refusal for an unresolvable `REF=HEAD`), plus annotations on two existing
  cases ("wrong branch", "HEAD moved since mint") clarifying how they now exercise the new code.
- `agent-system/extensions/core/scripts/tests/test-please-grant.sh` — four mint-side cases: an
  existing non-checked-out branch (`master`, deliberately advanced past by `feature-x` so the
  commits provably differ) binds correctly; a nonexistent branch mints nothing; the checked-out
  branch still binds to `HEAD`; and a bonus production-level case for the pathological
  `/please push HEAD to origin` typed line (the Risks table's detached-HEAD sentinel), which the
  pre-fix code dangerously minted and the fix correctly refuses.
- `agent-system/extensions/core/context/standards/git-safety.md` — one clarifying sentence added
  to the existing grant-binding paragraph stating the `push_branch`/`HEAD` split.
  `context/standards/push-consent-relay.md` left untouched per plan Decision D4 (its own
  sentence stays accurate as written).
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`; confirmed byte-identical to the
  source store for every file this task touched.

## Decisions

- Kept the on-disk field name `HEAD_SHA` unchanged (plan Decision D2) — only which commit it
  holds changes, documented via comments and the one doc sentence rather than a field rename.
- One resolution form only, no fallback: `git rev-parse --verify --quiet "refs/heads/${REF}"`
  (plan Decision D3). An unresolvable `REF` refuses to mint and refuses to match — fail-closed at
  both sites.
- Verified each new suite case empirically against a scratch copy of the pre-fix production
  files (never touching the live working tree) rather than reasoning abstractly about
  before/after behavior. Finding: the "survival" case and all four mint-side cases genuinely
  discriminate old-vs-new (fail before the fix, pass after); the "refused once the ref moves"
  consume-side case and the guard-side "fail-closed REF=HEAD" case are satisfied by the pre-fix
  code too — vacuously, because the pre-fix code refuses every non-checked-out-ref grant
  unconditionally (the "too strict" bug this record exists to fix). Both remain required,
  valid forward-looking regression pins; they are just not old-vs-new discriminators, and are
  described that way rather than overstated.

## Plan Deviations

- Added a fourth mint-side suite case beyond the plan's three (the pathological
  `/please push HEAD to origin` production-level case), additive only — no planned case removed
  or weakened. Recorded in the Phase 2 progress file's `deviations` array.
- Phase 4 required one fix-forward commit not anticipated by the plan text in detail: the first
  redeploy attempt failed gate 22 (shellcheck lint, SC1083) on an unquoted `HEAD^{tree}` in
  Phase 2's `make_plumbing_branch` test helper. Fixed forward in a dedicated scoped commit,
  re-verified (50/50 in the affected suite, shellcheck clean), then redeployed successfully.
  This is exactly the fix-forward path Phase 4's own plan text anticipates for a gate failure.

## Verification

- Build: N/A (bash scripts and markdown only).
- Tests: `test-guard-git-push.sh` 50/50 (47 pre-existing + 3 new), `test-please-grant.sh` 32/32
  (28 pre-existing + 4 new), both run directly against the source store. Post-redeploy,
  `verify-touched.sh` over all five touched paths: 98/98 passed (7 selected suites + a 1-path
  OWED-NOT-PAID full free-cost-class battery for the prose-only `git-safety.md` path, a known
  trigger for an unmapped doc path). `deploy-headless.sh` reports a clean verify: 41 checks, 0
  failures.
- Files verified: Yes — byte-identical diff confirmed between the deployed and source-store
  copies of every file this task touched.

## Impacts

- A typed `/please push <remote> <branch>` grant for a branch other than the checked-out one
  (e.g. a plumbing-built ref such as the `/slice` command's own `update-ref`-only construction)
  now survives unrelated commits made elsewhere in the repository during the grant's expiry
  window, and is correctly refused if the named ref itself is rebuilt before the push — closing
  both the "too strict" and "too loose" problems the ruling identified. A grant for the
  checked-out branch is unaffected.
- No change to who may mint a grant, the grammar, `PG_EXPIRY_WINDOW`, the one-live-grant rule, or
  the default-branch force bar. No change to `hooks/guard-git-push.sh` or
  `scripts/git-push-granted.sh` (confirmed call-site spectators, no code edit needed).

## Follow-ups

- None owed by this task. The `/merge`-minting-branch removal from `please-grant.sh` is a
  separate, already-ordered-after successor that edits the same file; this task's edit is
  confined to the single `HEAD_SHA` assignment block so that later removal lands as a clean
  deletion with no conflict.
- The complete `verify-deploy.sh` gate set is deferred to this multi-task batch's orchestration
  close per the dispatch's Batch Gate Deferral directive, rather than independently re-run here;
  this task's own scoped `verify-touched.sh` check (98/98) and the `deploy-headless.sh` clean
  verify (41/41) are the evidence attributable to this task specifically.

## References

- Plan: `specs/700_bind_push_grant_to_pushed_ref/plans/01_bind-grant-to-pushed-ref.md`
- Report: `specs/700_bind_push_grant_to_pushed_ref/reports/01_bind-grant-to-pushed-ref.md`
- Ruling: `specs/decisions/slice-command-one-path-to-review.md`
- Progress files: `specs/700_bind_push_grant_to_pushed_ref/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/700_bind_push_grant_to_pushed_ref/handoffs/phase-{1,2,3,4}-handoff-*.md`
