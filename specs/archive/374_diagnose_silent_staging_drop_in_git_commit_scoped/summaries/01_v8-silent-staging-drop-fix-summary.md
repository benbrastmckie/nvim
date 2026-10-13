# Implementation Summary: Task #374

- **Task**: 374 - Diagnose and fix the silent staging drop in git-commit-scoped.sh
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T06:55:00Z
- **Completed**: 2026-10-09T11:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_silent-staging-drop-loud-failure.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`git-commit-scoped.sh` could silently drop a named, correctly-staged positive pathspec from the
resulting commit while exiting `0` and printing nothing — a defect this task confirms by direct,
deterministic reproduction (a planted `pre-commit` hook that mutates the commit's own temporary
partial index, exploiting the fact that `git commit -- <pathspec>` re-reads the working tree
fresh at commit time rather than committing whatever `git add` last staged). This task adds a
pre-commit intent snapshot (content hash, or an "absent" sentinel for a staged deletion) taken
before `git add`, and a new post-commit integrity gate (**V8**) that compares the snapshot
against `HEAD` after the commit attempt, exiting a new dedicated code `5` whenever a commit was
created but a named path did not land as intended.

**Correction, made during review**: the real incident that originally motivated this task
(commit `fc9f786e`) was INITIALLY believed to be exactly this shape. Re-checking the actual
tool-call transcript that produced that commit (after a team-lead challenge) shows the dropped
path (`zigzag.typ`) was never named in that commit's own pathspec argument list at all, even
though it had genuinely been regenerated on disk and recorded as touched in the caller's own
progress file moments earlier. The real incident was therefore a CALLER-SIDE omission from the
pathspec list before the script was ever invoked — a class V8 cannot catch by construction, since
it only verifies paths it was actually given. This does not weaken the gate itself: V8 is
confirmed, by this task's own direct reproduction, to catch a different, real mechanism (a named,
correctly-staged path whose committed content still diverges from what was staged). It does mean
two specific causal claims written into the deliverables during Phase 4 were wrong and have been
corrected by a follow-up commit — see Plan Deviations below and the plan's own Phase 4 Reasoned
Exclusions block for the full evidence trail.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — added the V8 pre-commit intent
  snapshot (before `git add`) and the V8 post-commit integrity gate (after the commit attempt),
  a new exit code `5`, the full V8 header entry alongside V2-V7, and the git-semantics note on
  `git commit -- <pathspec>`'s working-tree-reread behavior. The `specs/.commit-lock` mutex
  branch's fail-open WARNING now states the shared-overlapping-path worst case as UNDETERMINED
  (not confirmed safe, but also not asserted as a reproduced drop) — a correction from this
  task's own initial, unsupported "falsified... reproduced" claim; see the Overview correction
  above.
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added the X1
  deterministic red/green fixture, 7 false-positive dimension cases (X2-X8) pinning every shape
  where absence is the correct post-state, and two non-default inversion probes confirming the
  new assertions are genuine guards rather than tautologies. Suite grew from 13 pre-existing
  cases to 47 total assertions, all passing.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — mirrored the exit-code
  table's new row `5` and the V8 gate label, and recorded two flagged follow-ups (no caller
  branches on exit `5` either; the `.commit-lock` fail-closed option, held out of this task's
  scope).
- `.claude/` (deployed tree, gitignored build artifact) — regenerated via `deploy-headless.sh`;
  confirmed byte-identical to the source-store copies.

## Decisions

- Adopted the research's mechanism-agnostic fix (a post-commit integrity gate) rather than a
  narrow patch against one concurrency precondition, since the gate is correct regardless of
  which underlying mechanism produces a future drop.
- The deterministic pre-commit-hook injection (confirmed 100% reproducible by direct probe)
  replaced the research's probabilistic two-writer harness as the default fixture; the latter was
  deliberately not ported into the suite, since the deterministic case makes it unnecessary.
- V8's comparison logic runs before the existing V6 gate's own `exit 4` (not strictly "after" it
  as the plan's literal wording suggested), so V8's own diagnostic is never suppressed when both
  gates could in principle apply to the same invocation; the actual exit-code decision is still
  made last, after both gates have run.
- The intent snapshot enumerates via git's own pathspec resolver (the union of `git ls-files`,
  `git diff --name-only HEAD`, and `git ls-files --others --exclude-standard`), run BEFORE
  `git add` — timing confirmed load-bearing by direct probe (the same enumeration run after
  `git add` loses the vacated half of a rename).

## Plan Deviations

- **Task 1.3** (two-writer fallback harness) skipped: the primary deterministic injection
  reproduced the incident on the first attempt, so the conditional fallback never applied.
- **Task 2** (V8 gate placement) altered: V8's comparison is placed before the V6 gate's own
  `exit 4` textually, not strictly after it, so its diagnostic is never suppressed.
- **Task 4** (fail-open comment correction) altered: the falsified claim lives inside a runtime
  stderr WARNING string literal, not a separate `#`-comment; edited that string's text only (no
  control-flow change).
- **Phase 4 causal claims** EXCLUDED and corrected by a follow-up commit, after a team-lead
  challenge: (1) the V8 header's claim that the gate's exit-5 shape was "matching the real
  incident's fc9f786e" was removed — the actual tool-call transcript for that commit shows the
  dropped path was never named in its pathspec list, a caller-side omission V8 cannot catch; (2)
  the fail-open WARNING's "(reproduced)" concurrency claim was removed — this task never
  independently reproduced the two-writer mechanism (the research's own probabilistic harness was
  explicitly not ported into this suite), so attributing "(reproduced)" to it was unsupported.
  Both corrected to accurate, mechanism-agnostic or explicitly-UNDETERMINED framing. See the
  plan's own Phase 4 Reasoned Exclusions block for the full evidence trail.
- **Phase 5 closure** altered: closed `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`.
  The full, unflagged `verify-deploy.sh` run shows 34/35 checks green; the one failure (Gate 8) is
  fully attributed, with evidence, to 4 suites outside this task's scope and unrelated to
  `git-commit-scoped.sh` (none reference it; this task's own suite passes 47/47 within the same
  run). See the plan's own `#### Reasoned Exclusions` block under Phase 5 for the full record.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-git-commit-scoped.sh` 47/47 (13 pre-existing T-cases, X1 fixture + 1
  inversion probe, X2-X8 false-positive cases + 1 inversion probe, U1-U6, V1-V7, W1-W4), run
  directly, via `run-all.sh --only`, and from the deployed tree.
- Files verified: Yes — deployed and source-store copies of all three modified files confirmed
  byte-identical; `shellcheck`/`bash -n` clean (zero new findings beyond the pre-existing 3
  info-level notices already present on the unmodified baseline).
- End-to-end smoke check (deployed tree, scratch repo): a correct commit exits `0`; the
  injected-drop fixture exits `5` with the marked V8 `ERROR:`.
- Exit-code contract hand-checked directly: `0`, `1`, `2`, `4`, `5` confirmed by direct scratch-
  repo invocation; `3` already covered by the existing V1-V7 suite cases.

## Impacts

- Every dispatch in the agent system commits through this script; the fix applies system-wide
  once deployed into a repository. A future silent-partial-commit of this shape will now exit `5`
  with a named, marked diagnostic instead of exiting `0` silently.
- All 8 registered consumer repositories (`~/.dotfiles`, `~/Philosophy/Papers/PossibleWorlds`,
  `~/Projects/BimodalLogic`, `~/Projects/cslib`, `~/Projects/Logos/Hardware`,
  `~/Projects/Logos/Theory`, `~/Projects/ModelChecker`, `~/Projects/PersonalWebsite`) are stale
  with respect to this change and were not deployed into (manual regeneration by design).

## Follow-ups

- Making the `specs/.commit-lock` mutex fail *closed* on an acquire timeout (rather than
  proceeding unserialized) — flagged by the research and recorded in `git-staging-scope.md`'s
  residual notes, deliberately out of this task's scope (a larger behavior change than "make the
  failure loud").
- Rewiring call sites to branch on the new exit code `5` — every current call site already
  swallows any nonzero exit via `cmd || echo "..."`; the same residual already exists for exit
  `4` and is recorded in `git-staging-scope.md`.
- A latent test-fragility was found and fixed during this task (6 assertions grepping for a bare
  "V8" substring, broken by this task's own corrected WARNING text now also mentioning V8) — no
  further action needed, but worth noting as a caught-before-ship class of risk for future
  diagnostic-text changes in this script.
- Redeploying into the 8 stale consumer repositories remains manual by design; not actioned here.
- The real incident's actual root cause (a caller-side omission from a manually-constructed
  `stage_paths` array, upstream of this script) is NOT addressed by this task and is outside
  V8's reach by construction — V8 only verifies paths it is actually given. Whether some other
  mechanism (e.g. deriving `stage_paths` from `files_touched` in a progress file automatically,
  rather than hand-listing it) would be worth pursuing to reduce THIS class of risk is a separate
  question this task did not scope or investigate.
- Whether the `specs/.commit-lock` mutex's shared-overlapping-path worst case is actually safe or
  actually drops a path under genuine concurrency remains UNDETERMINED (an earlier research
  harness reported a minority-trial drop, 3/20 and 1/10, not independently reproduced here). A
  future task wanting to settle this should reproduce it directly rather than citing that figure
  as already-confirmed.

## References

- Plan: `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/plans/01_silent-staging-drop-loud-failure.md`
- Research: `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/reports/01_silent-staging-drop-diagnosis.md`
- Progress files and phase-end handoffs: `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/progress/`, `specs/374_diagnose_silent_staging_drop_in_git_commit_scoped/handoffs/`
