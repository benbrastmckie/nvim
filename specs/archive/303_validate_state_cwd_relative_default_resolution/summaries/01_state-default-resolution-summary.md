# Implementation Summary: Task #303

- **Task**: 303 - Make `validate-state.sh`'s omitted-argument state-file default resolve against
  the repository being validated rather than the current working directory, and survey sibling
  scripts for the same latent pattern
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T12:00:00Z
- **Completed**: 2026-10-08T14:10:00Z
- **Effort**: ~2.25 hours
- **Dependencies**: 271, 279 (footprint-collision serializations only; no work dependency)
- **Artifacts**: plans/01_state-default-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  shell-strict-mode.md, git-staging-scope.md

## Overview

`validate-state.sh`'s omitted-argument `STATE_FILE` default resolved against the invoking
shell's CWD, so a dispatched agent with its CWD in one repository but loading the script from
another repository's deploy would silently validate the wrong repository and report a false
positive against it. This implementation re-anchors only that default to the git toplevel of the
script's own location (depth-independent upward `.git` discovery, never `common_repo_root()`'s
caller-supplied hop count), refuses loudly when no work tree is found there, canonicalizes
`STATE_FILE` to an absolute path on the success path before the `Validating state file:` banner,
and adds two non-vacuous regression cases to the script's own suite. The explicit-positional-
argument path (including every argument-relative sibling lookup) is proven unchanged.

## What Changed

- `agent-system/extensions/core/scripts/validate-state.sh` — replaced the 3-line CWD-relative
  omitted-argument default with script-anchored git-toplevel resolution (marked with the
  grep-gate token `default-resolution: script-anchored`), a loud exit-2 refusal when
  `SCRIPT_DIR` is not inside a git work tree, an informational divergence note between the CWD's
  own toplevel and the script-anchored one, success-path absolute-path canonicalization
  immediately after the existing `-f` existence check (before the banner), and revised
  header/`--help` contract text distinguishing the two resolution grains (argument-relative body,
  script-anchored default).
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — added an `XREPO_VALIDATOR`
  source-store-first, grep-gated validator resolution block, Case A (cross-repo omitted-argument
  invocation, non-vacuous via a deliberately malformed foreign fixture), and Case B sub-cases
  B1-B5 (explicit-argument argument-relativity regression: sibling-archive dependency resolution
  with a present/absent flip, sibling-TODO.md warning naming, and absolute banner path), all run
  from a foreign CWD.
- Regenerated (gitignored) `.claude/**` deploy tree via `deploy-headless.sh`.

## Decisions

- Chosen fix mechanism: git-toplevel-of-`SCRIPT_DIR` upward discovery, implemented inline without
  modifying `scripts/lib/common.sh`'s `common_repo_root()` — its caller-supplied hop count cannot
  be correct for both of this script's live locations (`.claude/scripts/` vs.
  `agent-system/extensions/core/scripts/`) simultaneously.
- Canonicalization sited once, immediately after the existing `-f` existence check (success path
  only), reusing the file's own `cd "$(dirname ...)" && pwd` idiom rather than introducing a
  second normalization style.
- Case A's non-vacuity device is the script's own existing `VALIDATION FAILED (invalid JSON)`
  exit-1 signature (via a deliberately malformed foreign fixture), not a sentinel string embedded
  in jq's parse-error text — jq's installed version does not echo the offending token back in
  that message.
- Non-vacuity demonstration against the pre-fix script used a temporary `git worktree` (removed
  immediately after recording evidence) rather than copying the extracted script to an arbitrary
  scratch path, because the extracted file's own `source "${SCRIPT_DIR}/lib/common.sh"` line
  requires its original directory structure.

## Plan Deviations

- **Task 2.3** (Case B fixture path) altered: built at `$WORKDIR/argrel/state.json` (no
  intervening `specs/` subdirectory) instead of the plan's literal
  `$WORKDIR/argrel/specs/state.json`, exactly mirroring the archived-parent (D6b) fixture's own
  construction that the same checklist item separately instructs this item to mirror.
  Functionally identical argument-relative-sibling-lookup property, one directory level
  shallower.
- **Task 3.5** (full `verify-deploy.sh` gate-set green) altered, closed via
  `[COMPLETED WITH EXCLUSIONS]`: gate 10 (`validate-state.sh --deep`, this task's actually-
  governing acceptance gate) is confirmed `[PASS]`; three unrelated gates (3, 5, 8) failed for
  reasons confirmed via `git log`/`git status` to be concurrent sibling task 367's in-flight/
  landing work (declared in this dispatch's own Territory block) or pre-existing drift in an
  unrelated extension, not this task's change. See the plan's Phase 3
  `#### Reasoned Exclusions` table for the full per-gate reason and evidence.

## Verification

- Build: N/A (shell scripts)
- Tests:
  - `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh`: 51 passed, 0 failed
    (was 45 passed, 0 failed before this task — 6 new cases, strictly higher, confirmed executed
    not skipped)
  - `bash .claude/scripts/tests/test-validate-state.sh` (deployed copy): 51 passed, 0 failed
  - `bash agent-system/extensions/core/scripts/tests/test-init-specs.sh`: 23 passed, 0 failed
    (unaffected sibling suite)
  - `bash -n` and `shellcheck` on both changed files: no new findings relative to a pre-change
    run (identical single pre-existing info-level finding each, confirmed by diffing the two
    runs' outputs)
  - Suite re-run twice in a row: idempotent, identical 51/0 result, no residue outside its own
    `WORKDIR` (`git status --short` unchanged by the run)
- Deploy: `deploy-headless.sh` → `RESULT=landed_verify_clean`; `diff -q` deploy-parity confirmed
  no difference for both changed files
- Files verified: Yes

## Acceptance Ledger

| # | Criterion | Discharged by |
|---|-----------|----------------|
| 1 | Omitted-argument invocation from a foreign CWD never silently validates the other repo | Manual probe: `cd /home/benjamin && bash <abs-path>/agent-system/extensions/core/scripts/validate-state.sh` — banner names THIS repository's `specs/state.json` absolutely, never `/home/benjamin`'s. XREPO Case A (automated, non-vacuous): output never contains `$OTHER_CWD`, never carries the malformed-JSON failure signature, names an absolute script-anchored path. |
| 2 | `Validating state file:` banner prints an absolute resolved path | Explicit-argument: `Validating state file: /home/benjamin/.config/nvim/specs/state.json`. Defaulted: same absolute-path shape confirmed in the cross-repo probe above. XREPO Case B5 (automated). |
| 3 | Explicit-positional `STATE_FILE` behaves exactly as today (argument-relative sibling `TODO.md`, sibling `archive/state.json`, `--fix` writer search) | XREPO Cases B1-B4 (automated, run from a foreign CWD): sibling-archive dependency resolves when present and goes dangling when removed (the flip); missing/present sibling `TODO.md` warning appears/disappears correctly, naming the fixture's own path. Pre-existing `--fix` fixtures (45 original cases) still pass unchanged. |
| 4 | `test-validate-state.sh` gains a non-vacuous cross-repo omitted-argument case | XREPO Case A added; non-vacuity demonstrated by running its invocation against the pre-fix script (via a temporary `git worktree` at the commit before Phase 1's commit) — pre-fix run produced `VALIDATION FAILED (invalid JSON)` reading `$OTHER_CWD`'s malformed fixture; post-fix run does not. |
| 5 | `test-validate-state.sh` passes in full; `verify-deploy.sh` gate 10 still passes | 51/0 (source-store and deployed copies). Gate 10 explicitly `[PASS]` in the full `verify-deploy.sh` run and via direct invocation (exit 0, 0 `[FAIL]` lines). |
| 6 | Sibling survey recorded with a per-site verdict | `reports/01_state-default-resolution.md`'s `## Sibling Survey (Part b — report only, no remediation here)` section (confirmed present, not duplicated here). |

## Sibling Survey Reference

See `specs/303_validate_state_cwd_relative_default_resolution/reports/01_state-default-resolution.md`'s
`## Sibling Survey (Part b — report only, no remediation here)` section for the full per-site
table. No sibling was remediated in this task.

## Follow-Up Recommendations (not filed as tasks)

- A follow-up task for `scripts/command-gate-in.sh` and `scripts/command-gate-out.sh` — the
  survey classes both as the same defect family (unguarded ambient-CWD dependency on
  `specs/state.json`, with `command-gate-out.sh` additionally writing downstream). Likely fix:
  the same `git -C "$SCRIPT_DIR" rev-parse --show-toplevel` upward-discovery technique used here.
- A lower-priority, diagnostic-only improvement to `git-snapshot.sh`'s success-path logging
  (echo the resolved repo/CWD on success, not only in failure messages, mirroring its existing
  `(cwd: $(pwd))` failure-message instinct). `git-snapshot.sh`'s CWD-relative resolution itself is
  by design and should not change.
- Optional: a marker-based mode for `scripts/lib/common.sh`'s `common_repo_root()` (depth-
  independent, alongside its existing caller-supplied-hop-count mode) so future callers runnable
  from two layouts of different depths are not forced to re-derive the inline idiom this task
  used. Also optional: a `context/patterns/` write-up of the three path-resolution idioms now in
  live use (CWD-relative-by-design, `common_repo_root()`'s hop-count, and upward marker
  discovery) and when each applies.
- `scripts/init-specs.sh` was confirmed CWD-relative by design and excluded from remediation.

## Impacts

- A dispatched agent invoking `validate-state.sh` with no positional argument from a foreign
  repository's CWD can no longer silently validate that foreign repository's state — the
  Observed Damage scenario this task was filed against (a false `TODO.md is OUT OF SYNC` finding
  attributed to the wrong repository) cannot recur via the omitted-argument path.
- No behavior change for any production caller that passes an explicit positional `STATE_FILE`
  (verified: `commands/task.md`, `verify-deploy.sh` gate 10, `test-init-specs.sh`, and this
  script's own suite all pass an explicit path and are unaffected).

## Follow-ups

- None owned by this task beyond the three recommendations recorded above (not filed as tasks
  per the dispatch's explicit instruction).

## References

- Report: `specs/303_validate_state_cwd_relative_default_resolution/reports/01_state-default-resolution.md`
- Plan: `specs/303_validate_state_cwd_relative_default_resolution/plans/01_state-default-resolution.md`
  (Phase 3's `#### Reasoned Exclusions` table has the full gate-3/5/8 exclusion evidence)
