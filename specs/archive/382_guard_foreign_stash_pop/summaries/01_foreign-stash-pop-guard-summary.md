# Implementation Summary: Task #382

- **Task**: 382 - Refuse `git stash pop`/`apply` of a stash entry the session did not create
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T19:30:00Z
- **Completed**: 2026-10-15T00:10:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_foreign-stash-pop-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`guard-destructive-git.sh`'s `git stash pop`/`apply` detector previously permitted every pop or
apply unconditionally (Item 8), reasoning that a conflicting pop fails safely rather than
discarding silently. That reasoning does not cover a pop with **nothing of the caller's own on
the stack**: it still succeeds and silently drops whatever foreign entry sits at the named
position, as observed in a 2026-10-09 consumer-repo incident (`git stash push -- <path>` saved
nothing, then `git stash pop` dropped an unrelated user WIP entry). This task adds a
session-scoped stash-provenance ledger and a new tree-state-blind predicate in
`guard-destructive-git.sh` that refuses a foreign `pop`/`apply` with `exit 2`, while a
pop/apply of an entry the calling session actually created keeps working unchanged, as does
`git-snapshot.sh`'s sanctioned snapshot/rollback flow.

## What Changed

- `agent-system/extensions/core/scripts/lib/stash-provenance-lib.sh` — new: per-session
  provenance ledger (pre-call snapshot, diff-and-record, fail-closed ownership query), never
  text-matching `git stash push` so `git-snapshot.sh`'s subprocess-invisible internal stash
  creation is correctly attributed.
- `agent-system/extensions/core/hooks/record-stash-provenance.sh` — new: PostToolUse `Bash`
  hook, the write half of the ledger.
- `agent-system/extensions/core/scripts/tests/test-record-stash-provenance.sh` — new: 9-case
  unit suite for the library and hook.
- `agent-system/extensions/core/merge-sources/settings-hooks.json` — registered the new hook on
  the existing PostToolUse `Bash` matcher.
- `agent-system/extensions/core/manifest.json` — declared the new lib, hook, and test files.
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` — added `stash_pop_foreign` to
  `PG_ACTION_CLASSES`.
- `agent-system/extensions/core/hooks/please-grant.sh` — new mint arm for `git stash
  pop`/`apply`, plus accepted-forms text.
- `agent-system/extensions/core/commands/please.md` — documented the new accepted forms.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` — pre-call stash-provenance
  snapshot (before the empty-command exit); new tree-state-blind hazard-class-3 predicate
  (before the clean-tree exit) refusing an unowned `pop`/`apply` with an inline
  `stash_pop_foreign` grant check and `exit 2` guidance; header narrative updated to a
  three-hazard-class description.
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` — `run_hook_in`
  gained an optional `session_id` parameter; the two now-incorrect unconditional-allow
  assertions were replaced with foreign-entry fixtures expecting `exit 2`; six new acceptance
  fixture groups added (owned pop, four foreign-incident variants with a
  refusal-prevents-the-drop post-check each, default/`--no-revert` snapshot-rollback,
  fail-closed regression, grant escape hatch) plus two empty-stash-list regression-guard cases.
- `agent-system/extensions/core/rules/git-workflow.md` — "Not blocked" list now states the
  conditional form (session-created vs. foreign), plus a new enforcement note for the class.
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — new
  "Wrong-identity hazard" paragraph (the sibling-conflict Item 8 argument kept intact, not
  replaced); residual-risk paragraph updated to note the provenance mechanism's scope.
- `agent-system/extensions/core/context/standards/git-safety.md` — class enumeration extended
  with `stash_pop_foreign` and its two structural differences from the rest of the family.
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` — added a runtime-artifact exemption for
  `tmp/stash-pre-*`/`tmp/stash-owned-*`, mirroring the existing `tmp/noop-bash-count-*` pattern
  (discovered necessary during Phase 6's gate run, since the new hooks create these files on
  every session's first qualifying Bash call).
- `agent-system/extensions/core/scripts/tests/test-deploy-orphans.sh` — new Assertion H covering
  the exemption above.
- Deployed tree under `.claude/**` — regenerated via `deploy-headless.sh`; never hand-patched.

## Decisions

- Ownership is established by **diffing the stash-sha set across a whole Bash call**, never by
  matching `git stash push` command text, so `git-snapshot.sh`'s internal stash primitives are
  correctly attributed without special-casing.
- Session scope is **literal**: keyed to Claude Code's native `session_id`, not an agent-system
  `sess_*` identity. A stash from an earlier dispatch reads as foreign to a later one; the
  recovery path is the `/please stash pop` grant, not widened automatic ownership.
- The new predicate is **tree-state-blind** and runs before the clean-tree exemption (the most
  dangerous case is a pop on a clean tree, where nothing conflicts and the drop proceeds
  silently), with **no snapshot-marker exemption** (a snapshot of the caller's own tree does
  nothing to make someone else's stash entry recoverable).
- `stash-provenance-lib.sh` is dependency-free (never sources `common.sh`) and fail-closed on
  any missing/invalid state — diverging deliberately from `detect-noop-bash.sh`'s fail-open
  posture, since this library backs a refusal decision rather than an advisory nudge.

## Plan Deviations

- **Task 3.6** (Scope Hypothesis confirmation grep): two new `assert_allowed_dirty` cases
  (empty-stash-list regression guard for pop/apply) were added beyond the plan's literal grep
  check, which expected zero remaining matches of that shape. This is additive test coverage
  for a real over-blocking risk the plan's grep did not anticipate, not a missed rewrite — see
  `progress/phase-3-progress.json`'s `deviations` array.
- **Task 6.3** (run the complete gate set): the complete, unfiltered `verify-deploy.sh` run is
  unreachable from this dispatch — gate 8 absent `--skip-slow` runs the full `tests/run-all.sh`
  battery, which includes the literature extension's `test-zotero-generate-export.sh`, a
  pre-existing indefinite hang already named by the dispatching orchestration message and filed
  as its own task. Ran the fast-gate set (21 of 23 passing; the 2 exclusions are both
  pre-existing and unrelated to this task) plus narrow `run-all.sh --only` selections covering
  every collaborator suite this task touches, all passing. See Phase 6's `#### Reasoned
  Exclusions` table in the plan for the full table and evidence.

## Verification

- Build: N/A (shell scripts, markdown, Lua)
- Tests: `test-record-stash-provenance.sh` (9/9), `test-guard-destructive-git.sh` (107/107,
  including all six new acceptance fixture groups), `test-please-grant.sh` (43/43),
  `test-deploy-orphans.sh` (all pass including new Assertion H), `test-git-snapshot.sh`,
  `test-manifest-scripts-sync.sh`, `test-lint-hook-registration-paths.sh`,
  `test-deploy-propagation.sh`, `test-guard-git-push.sh` — all collaborator suites pass except
  one pre-existing, unrelated `test-guard-git-push.sh` timing-expiry case (confirmed pre-existing
  via a detached worktree at the Phase 1 commit, before any of this task's edits).
- Shellcheck: clean (0 findings) on every new/edited script, and on the full repository after
  Phase 6's fixes (the deploy-headless fast-gate run showed shellcheck transiently FAIL once,
  then PASS on a clean re-run — not reproduced, not attributable to this task's files).
- Files verified: Yes — deployed tree confirmed to carry the new hook, lib, and PostToolUse
  registration; a live end-to-end probe against the deployed hook (throwaway fixture, not this
  working tree) refuses a foreign `git stash pop` with exit 2.

### ACCEPTANCE sentences, walked explicitly

1. **Pop/apply of a session-created entry passes.** `test-guard-destructive-git.sh`'s "ACCEPTANCE
   1" case: a real `git stash push -- tracked.txt`, recorded via the real pre/post hooks under
   one `session_id`, then `git stash pop` under the same id — exit 0. Confirmed.
2. **Pop/apply of a foreign entry is refused with exit 2, including the exact "push saved
   nothing, then pop" incident shape, bare/ref-naming/sha-naming forms.** Four variants (bare
   pop, apply, `pop stash@{0}`, pop by raw sha), each reproducing the incident shape exactly
   (pre-existing entry created outside session machinery, then a same-session push that saves
   nothing) — all exit 2, and each was confirmed genuinely RED (exit 0) against the pre-Phase-3
   hook via `git show` of the Phase 2 commit. Confirmed, including a post-check that the
   foreign entry survives in `git stash list` after every refusal.
3. **`git-snapshot.sh` rollback flow unaffected, default and `--no-revert` modes.** Both modes
   driven as real subprocesses under a tracked session; the script's own reported `stash@{N}`
   ref pops with exit 0 in both. Confirmed.

## Impacts

- Any agent (or human) whose `git stash push` saves nothing and who then pops/applies without
  realizing the stack was never theirs is now refused rather than silently dropping someone
  else's work, with clear inspection/recovery/grant guidance.
- `git-snapshot.sh`'s sanctioned snapshot/rollback flow, in both modes, continues to work
  without any special-casing.
- Every future session's first qualifying Bash call now writes a small per-session
  stash-provenance state file under `.claude/tmp/`; this is accounted for in the orphan-detection
  exemption list (`verify.lua`) so it will never surface as a false deploy-orphan finding.

## Follow-ups

- The pre-existing `test-guard-git-push.sh` "invalidation: expired grant (700s old) blocked"
  failure (unrelated to this task) remains open; recorded via `issue-record.sh` but not filed as
  a separate task by this dispatch.
- `git-safety.md`'s destructive-class enumeration already omitted `stash_revert` before this
  task touched it; left as pre-existing drift, out of this task's scope.
- The complete, unfiltered gate set remains blocked on the literature extension's
  `test-zotero-generate-export.sh` hang, already filed as its own task per the dispatching
  message.

## References

- `specs/382_guard_foreign_stash_pop/plans/01_foreign-stash-pop-guard.md`
- `specs/382_guard_foreign_stash_pop/progress/phase-{1..6}-progress.json`
- `specs/382_guard_foreign_stash_pop/handoffs/phase-{1..5}-handoff-*.md`
