# Implementation Summary: Task #277

- **Task**: 277 - Make an unresolvable pathspec a hard error in git-commit-scoped.sh instead of a silent WARN-and-drop
- **Status**: [COMPLETED]
- **Started**: 2026-10-02T00:00:00Z
- **Completed**: 2026-10-02T00:00:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_pathspec-drop-hard-error.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, git-staging-scope.md

## Overview

Closed the residual false-success path in `git-commit-scoped.sh`: a partial pathspec drop whose
surviving pathspecs contribute no diff was previously indistinguishable, at the exit-code level,
from the ordinary benign "nothing changed" no-op. Added a dropped-pathspec ledger to the existing
V2 three-way classification loop and a new V6 refusal gate (exit code `4`, loud `ERROR:` naming
every dropped path) that fires only when a drop occurred AND no commit was produced. All edits
landed in the source store (`agent-system/extensions/core/**`), never `.claude/**`.

## What Changed

- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — added a `dropped_pathspecs=()`
  ledger populated only in the V2 loop's case-3 (genuinely-unmatched) branch; added the V6
  refusal gate after the commit attempt (exit `4` + `ERROR:` naming every dropped path, fired
  only when `commit_exit != 0 AND dropped_pathspecs` is non-empty, guarded against unbound
  empty-array expansion); documented exit code `4` and the V6 gate in both header tables
  (Exit codes, Safety gates).
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added three cases in
  research order: **T11** (case A, all pathspecs dropped — pins the pre-existing V3 refusal,
  unaffected by this change), **T12** (case B, the new V6 posture — a partial drop whose
  survivors carry no diff now exits `4` with a named `ERROR:` instead of the generic `NOTE:`),
  **T13** (case C — the HARD CONSTRAINT's partial-drop half: a legitimate dropped artifact path
  plus a survivor with a real diff still commits exactly as before, exit `0`).
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — added a new
  "Exit-Code Contract and Safety Gates" subsection under "Commit-Level Path Scoping and
  Cross-Process Serialization": the exit-code table (`0`-`4`), the V2/V3/V5/V6 gate
  descriptions, and the recorded caller-escalation residual note.

## Decisions

- Adopted corrected option (c) from the research: refuse when `dropped_count > 0 AND the commit
  attempt produced no commit` — smallest, most auditable refusal surface, zero caller-contract
  changes. Option (a) (parent-directory-exists heuristic) was rejected because it would not have
  caught the historical incident (`specs/{NNN}_{slug}/`-shaped paths have an existing parent
  `specs/` in any scaffolded repo). Option (b) (opt-in optional-pathspec marker) was rejected as
  requiring an audit of ~50 call sites for an identical payoff.
- Deliberately did NOT change any caller. The declared `file_scope` for this task was the script
  and its test file; every current caller wraps the invocation as `cmd || echo "WARN:
  ...(non-blocking)"`, so a caller-side `$?` branch is a separate change with its own blast
  radius. This residual is recorded explicitly in the plan and in `git-staging-scope.md` rather
  than left as an undiscovered gap.
- The V6 predicate does not parse `commit_output` to distinguish "nothing to commit" from "git
  commit genuinely failed" — both sub-cases are already nonzero and already swallowed
  identically by every current caller, so splitting them adds an output-parsing dependency on
  git's own wording for no benefit.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — `test-git-commit-scoped.sh` 26/26 passed (T1-T13, V1-V8); `bash -n` clean;
  `test-lint-scoped-commit-boundary.sh` 8/8 passed (no code path in this change alters the
  `-- <pathspec>` invocation shape the lint checks for)
- Files verified: Yes — manual scratch-repo (`mktemp -d`) repro confirmed exit `4` + named
  `ERROR:` for the partial-drop/no-diff gap case, and exit `1` + unchanged `NOTE:` for the
  zero-drop/no-diff case (the HARD CONSTRAINT's all-resolve half)

## Impacts

- Every caller of `git-commit-scoped.sh` whose pathspecs all resolve sees byte-identical
  behavior (the HARD CONSTRAINT). A caller hitting the new V6 gap case now gets a loud, named
  `ERROR:` and a distinct exit code `4` on stderr in place of the previously indistinguishable
  generic `NOTE:` — strictly additive observability, not a behavior change for any existing
  caller's control flow (every current caller's `|| echo` idiom still collapses any nonzero
  exit to success).
- `git-staging-scope.md` now documents the full exit-code contract and gate labels, so a reader
  consulting the standards doc no longer needs to open the script header to learn them.

## Follow-ups

- A future task may escalate on exit `4` at the live script call sites
  (`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`) by branching on `$?`
  instead of `||`. Deliberately excluded from this task's scope; recorded in the plan's Scope
  Decision section and in `git-staging-scope.md`'s residual note.

## References

- specs/277_git_commit_scoped_worktree_targeting/reports/01_pathspec-drop-hard-error.md
- specs/277_git_commit_scoped_worktree_targeting/plans/01_pathspec-drop-hard-error.md
- agent-system/extensions/core/scripts/git-commit-scoped.sh
- agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh
- agent-system/extensions/core/context/standards/git-staging-scope.md
