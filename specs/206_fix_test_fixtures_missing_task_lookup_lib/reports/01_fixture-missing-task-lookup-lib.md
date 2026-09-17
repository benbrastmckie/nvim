# Research Report: Task #206

**Task**: 206 - fix_test_fixtures_missing_task_lookup_lib
**Started**: 2026-09-17T23:26:47Z
**Completed**: 2026-09-17
**Effort**: small (2 confirmed root causes, both fully diagnosed and fix-verified experimentally)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (agent-system/extensions/core/scripts/), direct execution of the two red suites, transient experimental patches (not committed) to confirm each fix before recommending it
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both suites named in the (addendum-narrowed) scope were reproduced exactly as described and
  root-caused with certainty; suite (3) (`test-gate-out-repair-reporting.sh`) is confirmed GREEN
  (19 passed, 0 failed) and stays out of scope, matching the addendum.
- Suite (1) `test-postflight-deploy-gate.sh`: 7/19 FAIL. Root cause confirmed: `REQUIRED_LIBS` at
  line 85 omits `task-lookup-lib.sh`, which `task-lock.sh:197` sources **unconditionally** (no
  `[ -f ... ]` guard). Fix verified experimentally: adding `task-lookup-lib.sh` to
  `REQUIRED_LIBS` alone (no other transitive libs needed — `task-lookup-lib.sh` itself sources
  nothing) takes the suite from 12/19 to 19/19 passed.
- Suite (2) `test-lint-json-channel-discipline.sh`: 2/11 FAIL. The current real-corpus run
  actually reports **two** `[VIOLATION]` lines against `orchestrate-triage-classify.sh` (lines
  225 and 527), not the one the addendum's evidence highlighted — but they share one root cause.
  Line 225 (`printf '%s' "$archived_projects_json" > "$archived_projects_tmpfile"`) is a false
  positive: the write **is** redirected (to a file), but `check_emit_perline()`'s exclusion list
  only strips `>&2`/`>&3`/`$(...)` lines, not a generic `> "$file"` redirect. Because that false
  match pushes the file's "candidate unredirected writes" count to 2, the per-line contract's
  "exactly one surviving match is the legitimate final emit" short-circuit never fires, so the
  **genuinely legitimate** line 527 (`printf '%s\n' "$verdicts"`, the script's real JSON-on-
  stdout output) gets flagged too. **Recommendation: fix the predicate** (not allowlist) —
  verified experimentally that adding one exclusion clause,
  `grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]'`, to the pipeline in `check_emit_perline()` (scripts/
  lint/lint-json-channel-discipline.sh) makes the real corpus clean (0 violations, up from 179
  files / 2 violations) while leaving both existing fixture cases (the genuine-2-violations case
  and the genuine-1-legitimate-emit negative control) unchanged, and correctly clears a
  synthetic case combining a `> "$var"` write plus one legitimate final emit.
- Audit (item d): of 22 candidate suites that reference `task-lock.sh`/`skill-base.sh`/
  `update-task-status.sh`, one other genuine (but currently dormant/non-manifesting) gap was
  found: `test-handoff-dispatch-identity.sh` copies `task-lock.sh` + `skill-base.sh` +
  `update-task-status.sh` via an explicit lib list that also omits `task-lookup-lib.sh`. It stays
  green today only because every case in that suite runs with `--dry-run`, which skips the one
  code path (`orchestrate-cycle-postflight.sh`'s `bash task-lock.sh release ...` subprocess call)
  that would actually execute the unguarded `source`. A second, lower-risk instance
  (`test-git-commit-scoped.sh`, `REQUIRED_SCRIPTS=(... task-lock.sh lib/common.sh)`) copies
  `task-lock.sh` but never invokes it at all — it exists only so `deploy-root-guard.sh`'s
  directory-shape check sees a real file. Both should get `task-lookup-lib.sh` added defensively
  per the dispatch's item (d) instruction, even though neither is currently red. Full suite list
  audited is in Findings below.

## Context & Scope

Dispatch `.dispatch/3.md` narrows the original three-suite defect to two, per a 2026-09-17
addendum: suite (3) `test-gate-out-repair-reporting.sh` is now confirmed green on master (this
research reconfirmed 19 passed / 0 failed) and item (c) is withdrawn. Remaining work items:
(a) fix suite (1)'s fixture, (b) decide and fix suite (2)'s lint predicate/allowlist/code, and
(d) audit every fixture under `core/scripts/tests/` that copies `task-lock.sh`, `skill-base.sh`,
or `update-task-status.sh` via an explicit lib list, for the same missing-lib gap.

All investigation ran directly against the source store
(`agent-system/extensions/core/scripts/...`), never `.claude/**` (per the source-store/deploy
boundary rule). No files in the source store were modified by this research — all confirming
edits were made to throwaway copies (`/tmp/...` or a dotfile inside `scripts/tests/`/`scripts/
lint/` that was deleted immediately after each experiment) and none are present in the working
tree now.

## Findings

### Suite (1): test-postflight-deploy-gate.sh

- `scripts/tests/test-postflight-deploy-gate.sh:85`:
  `REQUIRED_LIBS=(common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh)`
- `scripts/task-lock.sh:197`: `source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"` — unconditional,
  no existence guard, unlike `skill-base.sh`'s own sourcing of the same lib (see below).
- `task-lookup-lib.sh` itself sources nothing further (checked: no `^source`/`^\. ` lines), so no
  transitive additions are needed beyond the one file.
- Experimentally confirmed: adding `task-lookup-lib.sh` to `REQUIRED_LIBS` (and nowhere else —
  the fixture's `build_fixture_repo()` already copies every name in `REQUIRED_LIBS` into
  `$root/.claude/scripts/lib/`) takes the suite from **12 passed / 7 failed** to **19 passed / 0
  failed**. Every one of the 7 originally-failing cases (2, 3, 4, 5's exit-code assertion, 5's
  pass-through-status assertion, 7) turns green; no new failures appear.
- The dispatch's guidance to keep the fixture's explicit list (rather than switching to a
  wholesale `lib/*.sh` copy) is directly actionable: this is a pure one-line addition.

### Suite (2): test-lint-json-channel-discipline.sh / lint-json-channel-discipline.sh

- `scripts/lint/lint-json-channel-discipline.sh`'s `check_emit_perline()` (used for
  `orchestrate-batch-admit.sh` and `orchestrate-triage-classify.sh`, the two files in
  `EMIT_PERLINE_FILES`) collects every `echo|printf|cat <<` line, then excludes `>&2`, `>&3`,
  `$(...)`-captured, and comment lines. If exactly one candidate survives, that is treated as the
  legitimate final JSON-on-stdout emit and the file passes clean; two or more is treated as the
  regression signal (every survivor gets printed as a `[VIOLATION]`).
- `orchestrate-triage-classify.sh:225`:
  `printf '%s' "$archived_projects_json" > "$archived_projects_tmpfile"` — this **is** redirected
  (to a `mktemp`-created file held in a variable), so it should never have been a stdout-write
  candidate at all, but none of the four exclusions catch a generic `>` file redirect.
- `orchestrate-triage-classify.sh:527`: `printf '%s\n' "$verdicts"` — this is the file's one true
  contractual JSON-on-stdout emit (confirmed by reading the surrounding code: it is the very last
  statement, immediately preceded by the error-handling block for `jq` evaluation failure).
- Net effect on a real-corpus run today: 2 candidates survive (225 false positive + 527
  legitimate), so the "exactly one" shortcut never fires and **both** are printed as
  `[VIOLATION]`s. This is why the live lint currently shows 2 violations even though the
  addendum's evidence (dated 2026-09-17, same day) describes "the one VIOLATION at ...:225" —
  the addendum's phrasing tracks the single *root cause*, which is accurate: fixing 225 alone
  drops the candidate count back to 1, which auto-clears 527's flag too via the existing
  "exactly one" branch. No separate fix for line 527 is needed or wanted.
- **Decision recommended: fix the predicate**, not allowlist-and-move-on and not change the
  code. Rationale: (1) the write at line 225 is correct as written (it must land in a file for
  `--slurpfile` to read later, per the surrounding comment about `--argjson`'s ~960KB argv
  ceiling) — there is nothing to change in `orchestrate-triage-classify.sh`; (2) an allowlist
  entry keyed to this one file/line is narrower than the actual defect class (any future
  per-line-emit script that also writes a temp file via `> "$var"` would hit the identical false
  positive) — the predicate fix is the general fix and the allowlist is not; (3) verified fix is
  a single, minimal, well-scoped addition to the existing exclusion pipeline.
- **Verified fix**: append one more `grep -v` stage to `check_emit_perline()`'s existing
  `grep -v '>&2' | grep -v '>&3' | grep -v '\$(' | grep -v '^\s*[0-9]*:\s*#'` pipeline:
  `| grep -vE '>[[:space:]]*"?\$\{?[A-Za-z_]'` — excludes a line whose (non-`&`) `>` redirect
  target starts with a `$` (i.e. a variable-named path, quoted or not, braced or not). This is
  deliberately scoped to *variable-named* redirect targets (matching the dispatch's own framing
  of the false positive), not every possible `>` redirect, to stay conservative and not
  accidentally suppress a literal-path redirect that might indicate something else.
- Experimentally confirmed against three cases with a throwaway patched copy of the lint script
  (`REPO_ROOT` exported explicitly since a `/tmp`-resident copy can't `git rev-parse` its way to
  the real repo root):
  1. Real corpus (`lint-json-channel-discipline.sh` with no explicit paths): 179 files checked,
     **0 violations** (down from 2).
  2. Existing fixture "EMIT case 2" (two genuine unredirected writes, no file redirect involved):
     still correctly flags **2** violations — the predicate change does not weaken real-defect
     detection.
  3. Existing fixture "EMIT negative control" (exactly one legitimate emit): still passes clean.
  4. New synthetic case combining a `> "$var"`-redirected write plus one legitimate final emit
     (i.e. exactly reproducing the real corpus's current shape) on a file named
     `orchestrate-triage-classify.sh`: now passes clean (0 violations), confirming the fix
     resolves the actual defect, not just the specific existing fixtures.
- Per the dispatch's item (b) instruction, the implementation should add a **new** fixture case
  to `test-lint-json-channel-discipline.sh` covering the `> "$var"` redirect shape (case 4 above
  is a ready template), alongside the existing two EMIT-PER-LINE cases, and should re-confirm the
  existing "two genuine violations" and "one legitimate emit" cases are unaffected (which this
  research already did once, informally, against a throwaway copy — implementation should make
  this the suite's own permanent, checked-in regression coverage).

### Audit (item d): fixtures copying task-lock.sh / skill-base.sh / update-task-status.sh

22 suites under `agent-system/extensions/core/scripts/tests/` reference at least one of the three
scripts by name. They fall into four buckets:

**1. Wholesale `lib/*.sh` copy — safe by construction, no gap possible**: `test-force-phases.sh`,
`test-gate-out-repair-reporting.sh`, `test-roadmap-items-producer.sh`,
`test-skill-base-lifecycle.sh`, `test-update-task-status.sh`.

**2. Explicit lib list that already includes `task-lookup-lib.sh`** (multi-line lists that a
naive single-line grep can miss — confirmed by grepping the literal string in each file):
`test-orchestrate-churn.sh`, `test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`,
`test-orchestrate-cycle-postflight.sh`, `test-phase-heartbeat.sh`,
`test-loop-guard-budget-override.sh`. No gap.

**3. No isolated fixture copy at all** — `skill-base.sh` (or its lib collaborator) is sourced
directly from its real location (source-store-first/deploy-tree-fallback), so its own internal
sourcing of `task-lookup-lib.sh` resolves normally; nothing is copied into a partial lib tree:
`test-corroborate-phase-counts.sh`, `test-mint-dispatch-seq.sh`,
`test-orchestrate-build-aux-dispatch.sh`, `test-orchestrate-build-dispatch.sh`,
`test-postflight-marker-schema.sh`. No gap.

**4. Static/structural analysis only (`bash -n`, grep on source text), never executes the
copied/referenced script**: `test-lint-lifecycle-status-var.sh`, `test-lint-task-lookup-adoption.sh`
(fixtures are synthetic stand-ins, never the real `skill-base.sh`), `test-reconcile-handoff-status.sh`
(bare comment reference, no copy), `test-resume-scan-nonconformance.sh` (Site D is `bash -n` +
grep against the real file path, never sourced/executed). No gap.

**5. Genuine gaps found** (explicit lib list, missing `task-lookup-lib.sh`, AND the fixture does
copy one of the three trigger scripts):

- `test-postflight-deploy-gate.sh` — already covered above as the primary suite-1 target.
- `test-handoff-dispatch-identity.sh` (lines 59-67 and 82-90): copies `task-lock.sh`,
  `skill-base.sh`, AND `update-task-status.sh`, with an explicit lib list (`common.sh
  file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh
  phase-heading-patterns.sh status-vocabulary.sh`) that omits `task-lookup-lib.sh`. Currently
  green (8 passed, 0 failed — reconfirmed by running it) **only** because every one of its four
  cases invokes the fixture's `orchestrate-cycle-postflight.sh` with `--dry-run` (line 114), and
  the only place that script would actually execute `task-lock.sh` as a subprocess —
  `bash "${SCRIPT_DIR}/task-lock.sh" release "$task_number" "$session_id"` at
  `orchestrate-cycle-postflight.sh:1040` — sits inside the `else`-guarded dry-run branch and is
  never reached. `skill-base.sh` is separately sourced by the fixture's
  `orchestrate-cycle-postflight.sh` (`. .claude/scripts/skill-base.sh`), but `skill-base.sh`'s
  own sourcing of `task-lookup-lib.sh` (`scripts/skill-base.sh:55-58`) is **soft-guarded**
  (`if [ -f ... ]; then source ...; else WARNING ...; fi`), unlike `task-lock.sh`'s unconditional
  `source` — so a missing lib there degrades gracefully instead of hard-failing. This is a real,
  fixable gap that should be closed defensively (add `task-lookup-lib.sh` to both explicit lib
  loops) even though no case currently exercises the failing path; it is exactly the kind of
  latent breakage the coordination note about `isolate_shell_suites_from_host_state` landing on
  top of this work would want closed now rather than discovered later.
- `test-git-commit-scoped.sh` (line 41, `REQUIRED_SCRIPTS=(git-commit-scoped.sh
  deploy-root-guard.sh task-lock.sh lib/common.sh)`): copies `task-lock.sh` and `chmod +x`'s it,
  but `task-lock.sh` is never actually invoked anywhere in this suite (grepped for any
  `task-lock.sh` invocation beyond the copy loop — none found); it exists purely so
  `deploy-root-guard.sh`'s directory-shape check and the "runtime dependency present on disk"
  framing the suite's own header describes are satisfied. Lower-priority than the previous
  finding (fully dormant, no code path anywhere in the suite would ever source it), but the same
  one-line defensive fix (`lib/common.sh` -> `lib/common.sh lib/task-lookup-lib.sh` in
  `REQUIRED_SCRIPTS`, plus the matching `chmod +x` skip-guard already keys off `lib/common.sh`
  specifically so a new lib entry needs the same non-executable treatment) closes it.

## Decisions

- Suite (2)'s false positive: **fix the lint predicate** (generalize the `check_emit_perline()`
  exclusion to recognize a `> "$var"`-shaped file redirect), not an allowlist entry and not a
  code change to `orchestrate-triage-classify.sh`. See rationale and verified patch above.
- Suite (1) and both audit gaps: add `task-lookup-lib.sh` to each fixture's existing explicit lib
  list/array — keep the explicit-list style throughout (per dispatch guidance for suite 1; the
  audit gaps are architecturally identical, so the same style choice applies to them for
  consistency, not just because the dispatch said so for suite 1 specifically).
- `test-git-commit-scoped.sh`'s gap is real but dormant (task-lock.sh copied, never executed);
  fix it anyway for defensive correctness rather than leaving a structurally-incomplete fixture
  on record, but this is lower urgency than `test-handoff-dispatch-identity.sh`'s gap (which sits
  one `--dry-run` flag away from actually mattering).

## Risks & Mitigations

- **file_scope mismatch**: `specs/state.json`'s `file_scope` for task 206 currently lists only
  `test-lint-json-channel-discipline.sh`, `test-postflight-deploy-gate.sh`, and
  `lint-json-channel-discipline.sh` — it does not list `test-handoff-dispatch-identity.sh` or
  `test-git-commit-scoped.sh`, which this research's audit (explicitly requested by dispatch item
  (d)) found also need the one-line fix. `file_scope` is descriptive/anticipated rather than
  filesystem-validated (per `.claude/rules/state-management.md`), so this is not a hard blocker,
  but the plan should either extend `file_scope` to include these two files or explicitly note
  the deviation, since item (d) explicitly instructs fixing any gaps found during the audit.
- **Shellcheck**: not run during this research pass (acceptance criterion, not a research
  deliverable); every shell file the implementation actually touches (the two fixtures needing
  one-line lib additions, plus `lint-json-channel-discipline.sh`, plus the two audit-gap
  fixtures) will need a clean `shellcheck` pass per
  `context/standards/shell-strict-mode.md` before the task can close.
- **Deployed-copy re-verification**: acceptance requires both suites pass from the source store
  AND from the deployed `.claude/` copy after redeploy. This research verified source-store
  behavior only (per the source-store-is-the-edit-target rule, `.claude/**` was never touched);
  the redeploy + re-run step is implementation/verification work, not something to front-run
  here.

## Context Extension Recommendations

None. The relevant conventions (source-store-first resolution in test suites, the deploy-tree-
first/source-store-fallback pattern, the EMIT_STRUCTURAL vs EMIT_PERLINE distinction in the
lint) are already documented inline in the scripts' own headers and comments in enough detail
that no new `.claude/context/` file is warranted for this task's scope.

## Appendix

### Commands run

- `bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` (baseline: 12
  passed, 7 failed; with the one-line `REQUIRED_LIBS` fix in a throwaway copy: 19 passed, 0
  failed)
- `bash agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh`
  (baseline: 9 passed, 2 failed)
- `bash agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` (baseline: 178
  files, 2 violations; with the one-line predicate fix in a throwaway copy, run with
  `REPO_ROOT` exported explicitly: 179 files, 0 violations)
- `bash agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` (8 passed,
  0 failed — confirms the audit gap there is currently dormant, not red)
- `bash agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` (19 passed,
  0 failed — reconfirms the addendum's withdrawal of former item (c))
- `grep`-based structural audit across all 22 suites under `agent-system/extensions/core/scripts/
  tests/` referencing `task-lock.sh`/`skill-base.sh`/`update-task-status.sh`, classifying each
  into the four buckets in Findings above.

### Notes on experimental method

All confirming edits were made to throwaway files, never the tracked source-store copies:
- Suite (1) fix: a full copy of `test-postflight-deploy-gate.sh` placed at
  `scripts/tests/.test-postflight-deploy-gate-experiment.sh` (dotfile, so it does not match the
  suite's own `test-*.sh` discovery glob or pollute `run-all.sh`), `sed`-patched, run, then
  deleted.
- Suite (2) fix: a full copy of `lint-json-channel-discipline.sh` placed at
  `scripts/lint/.lint-experiment.sh`, patched via a small Python `str.replace` (to avoid sed
  quoting issues with the regex's embedded `$`/`{`/`}` characters), run with `REPO_ROOT`
  exported explicitly (a `/tmp`-resident copy can't resolve its own repo root via `git
  rev-parse`), then deleted. Fixture-shape synthetic files for the three targeted cases were
  built under `/tmp/lint-fixture-test/` and removed afterward.
- No file under `agent-system/extensions/core/` or `.claude/` was left modified by this research;
  `git status` reflects no changes attributable to this dispatch.
