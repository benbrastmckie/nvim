# Research Report: Task #151

**Task**: 151 - Fix the two pre-existing verify-deploy gate failures (state-writer boundary, whole-tree orphan)
**Started**: 2026-09-07T21:07:00Z
**Completed**: 2026-09-07T21:14:55Z
**Effort**: small (fix already landed; verification + documentation)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`, `agent-system/extensions/core/scripts/state-write.sh`, `agent-system/extensions/core/scripts/tests/test-force-phases.sh`, `agent-system/extensions/core/scripts/verify-deploy.sh`, `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`
- Git history (`git log`, `git show 89f575aed`)
- Live command execution: `lint-state-writer-boundary.sh --verbose`, `test-force-phases.sh`, `test-lint-state-writer-boundary.sh`, direct `manager.find_orphans` invocation via headless nvim, full `verify-deploy.sh` run
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **FAILURE 1 (state-writer boundary lint, gate 12) is already fixed** on disk, by commit
  `89f575aed` ("task 151: route test-force-phases.sh state writes through state-write.sh"),
  which predates this research dispatch. Verified live: `lint-state-writer-boundary.sh --verbose`
  reports **0 violations** across 1075 scanned files; `test-force-phases.sh` passes **19/19**;
  the lint's own regression suite `test-lint-state-writer-boundary.sh` passes **8/8**.
- The chosen remedy is **(a) route through `state-write.sh`**, applied uniformly to **all four**
  sites — including the three `$WORKDIR`-scoped ones, not just the real-`specs/state.json` one at
  the old `:261`. This is the correct call, not a reflexive one: the fixture's own setup block
  (`test-force-phases.sh` lines 78-101) copies `state-write.sh` plus its full dependency chain
  (`task-lock.sh`, `generate-todo.sh`, `deploy-root-guard.sh`, `lib/*.sh`) into
  `$WORKDIR/.claude/scripts/`, and `state-write.sh` resolves its own `PROJECT_ROOT` from its own
  script location (`common_repo_root "$SCRIPT_DIR" 2`), not from `$SKILL_REPO_ROOT` or cwd — so
  invoking `"$WORKDIR/.claude/scripts/state-write.sh"` self-targets `$WORKDIR/specs/state.json`
  correctly with no extra plumbing. Options (b) allowlist and (c) narrow-the-lint are strictly
  worse here: the sanctioned writer already works against a scratch fixture root with zero
  special-casing, so weakening the lint's detection or carving out an allowlist exception would
  trade away boundary-guarantee coverage for no benefit.
- **FAILURE 2 (whole-tree orphan detection, gate 13) currently reports 0 findings**, both via a
  direct headless-nvim `manager.find_orphans()` call (5353 files checked, 0 orphans, 0 ghost
  index rows) and via the full `verify-deploy.sh` run. The original single finding's identity
  was **not reproducible** during this research pass — see Findings for the evidence-based
  explanation (a live multi-task `/orchestrate` batch was — and still is — running concurrently
  today, which is the most probable source of a transient declared/deployed mismatch that self-
  resolved once the other task's phase committed).
- A full `bash agent-system/extensions/core/scripts/verify-deploy.sh` run (all 30 gates, ~2
  minutes) shows gate 12 and gate 13 **both PASS**. One unrelated, out-of-scope gate currently
  fails: **gate 3 (doc-lint)**, on a fresh `index-entries.json` `line_count` drift for
  `project/lean4/domain/comparator-integration.md` (declared 219, actual 247) — this is a new
  instance of the exact "stale line_count declaration" class the dispatch already called out as
  previously fixed and separately tracked by a sibling task; not part of this task's two named
  failures and not touched here.

## Context & Scope

Task 151 targets exactly two pre-existing, unrelated-to-any-specific-task `verify-deploy.sh`
gate failures that were observed blocking an unrelated multi-task `/orchestrate` batch:

1. Gate 12 — state-writer boundary lint: 4 hand-rolled `state.json` writes in
   `agent-system/extensions/core/scripts/tests/test-force-phases.sh`.
2. Gate 13 — whole-tree orphan detection: 1 unspecified finding (detail not captured at
   observation time; the full-suite run needed to reproduce it exceeds a 120s timeout).

The dispatch's constraint set requires: edits only under `agent-system/extensions/**`; never
weaken a gate merely to pass it (fix detection if a finding is a genuine false positive, fix the
violation if real); redeploy and confirm 0 failures.

## Findings

### FAILURE 1 — State-writer boundary lint: already fixed, verified correct

Current repo state (verified, not assumed):

```
$ bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose
Files checked: 1075
Candidate lines exempted: 22
Total violations: 0
```

`git log` shows commit `89f575aed` already applied the fix, titled exactly
"task 151: route test-force-phases.sh state writes through state-write.sh", authored
2026-09-07 12:34:50 -0700 under session `sess_1788809689_86fcdd` — a session distinct from and
earlier than this research dispatch's own session (`sess_1788815202_e9189b_151`). This repo is
mid-way through a large concurrent multi-task `/orchestrate` batch today (tasks 137, 143, 153,
154, 158, 159, 160, 161, 166, 167 all have commits from today); the most likely explanation is
that an earlier cycle for this same task number already reached and completed this fix before
this particular research dispatch was issued. Whatever the sequencing, the fix is present,
committed, and independently verified working (not merely trusted from the commit message):

- `lint-state-writer-boundary.sh --verbose` (whole source store): 0 violations, 1075 files
  checked.
- `test-force-phases.sh`: 19 passed, 0 failed (all four previously-hand-rolled write sites
  exercised).
- `test-lint-state-writer-boundary.sh` (the lint's own regression suite, unaffected by this fix
  but re-run for completeness): 8 passed, 0 failed.

**The decision this task must state explicitly** (per dispatch): is (a) route-through-
`state-write.sh`, (b) file-level allowlist, or (c) narrow the lint's detection the correct
remedy — and does the real `specs/state.json` write at the old `:261` deserve different treatment
than the three `$WORKDIR`-scoped writes at `:307`/`:317`/`:327`?

**Answer, with reasoning**: (a) for all four sites, uniformly — no split treatment.

- `test-force-phases.sh`'s setup block (lines 78-101, unchanged by the fix) already builds a
  fully self-contained fixture root: it copies `update-task-status.sh`, `state-write.sh`,
  `task-lock.sh`, `generate-todo.sh`, `deploy-root-guard.sh`, and the `lib/*.sh` dependency chain
  into `$WORKDIR/.claude/scripts/` before any test body runs. This means a call to
  `"$WORKDIR/.claude/scripts/state-write.sh"` is not routing through the *real* production
  writer against a fake target — it is routing through the *fixture's own copy* of the sanctioned
  writer, which is the correct level of fidelity for a test that exists specifically to exercise
  `skill_postflight_update`'s and `orchestrate-stage5-postflight.sh`'s real state-transition
  logic.
- `state-write.sh` resolves `PROJECT_ROOT` via `common_repo_root "$SCRIPT_DIR" 2` — i.e. from
  *its own invoked path*, not from `$SKILL_REPO_ROOT`, cwd, or any other ambient variable. So
  `"$WORKDIR/.claude/scripts/state-write.sh"` self-resolves to `PROJECT_ROOT=$WORKDIR`, and its
  default target `"$PROJECT_ROOT/specs/state.json"` becomes exactly `"$WORKDIR/specs/state.json"`
  — byte-identical to what the old hand-rolled `jq ... "$WORKDIR/specs/state.json" > ... && mv
  ...` sequence targeted. There was no impedance mismatch to work around, which is exactly why a
  single uniform remedy applies to both shapes named in the dispatch (the real-path `:261` write,
  which already ran with cwd `=$WORKDIR` via a preceding `cd "$WORKDIR"`, and the
  explicit-`$WORKDIR`-path writes at `:307`/`:317`/`:327`) — both shapes ultimately target the
  same fixture-root `specs/state.json`, and both now go through the same fixture-root
  `state-write.sh`.
- This is also the invariant-preserving choice: the lint exists to protect the single-writer
  mutex/staging-path guarantee (see `state-write.sh`'s header for the two corruption channels it
  closes). A test fixture that hand-rolls the anti-pattern is not "safe because it's a scratch
  dir" — it is simply *undetected* risk in a codebase where the sanctioned writer already
  supports being pointed at an arbitrary root with zero extra ceremony. Choosing (b) or (c) here
  would carve a permanent hole in the boundary guarantee's coverage for a case that needed no
  hole at all.
- (b) allowlist and (c) narrow-detection were both live options the lint already supports
  (`EXCLUDED_FILES` array; structural classification in `classify_line`), so this was a genuine,
  considered choice among three working mechanisms, not merely "the only thing that compiles."

**Regression safety**: `test-lint-state-writer-boundary.sh` pins the lint's own detection
behavior (positive/negative/control cases, 8 assertions), and `test-force-phases.sh` now
exercises the four converted call sites on every run — a future re-introduction of a hand-rolled
`jq ... > tmp && mv` sequence in this file would be caught by `lint-state-writer-boundary.sh`
directly (gate 12 fails) before it could land in `agent-system/extensions/**`.

### FAILURE 2 — Whole-tree orphan detection: currently 0 findings; original finding not reproducible

Direct invocation (bypassing the ~2 minute full-suite run):

```
$ nvim --headless -c "lua ... manager.find_orphans('/home/benjamin/.config/nvim') ..." -c "qa!"
ORPHAN_DONE checked=5353
```

Zero `ORPHAN_FINDING` lines emitted — 0 orphan files, 0 ghost `context/index.json` rows, across
5353 files checked. The full `verify-deploy.sh` run (all 30 gates) independently confirms this:
gate 13 reports `[PASS] no deployed-but-undeclared files or ghost context/index.json rows`.

**What the dispatch asked for**: establish what the single finding actually was, not merely make
it disappear. This could not be done directly — the finding's specific file/row was never
captured, and it is not currently reproducible. The evidence gathered supports a specific,
falsifiable explanation rather than a shrug:

- `find_orphans` compares two **live filesystem reads**, taken at query time: the declared set
  (union of every *active* extension's `agent-system/extensions/*/index-entries.json`, read
  directly off disk — uncommitted edits count immediately) against the deployed set (a walk of
  the live `.claude/` tree). Neither side depends on git history or commit state.
- `deploy-orphan-detection.md`'s own design section states the detector is **detect, never
  auto-delete**: nothing removes a deployed file or index row automatically. A true orphan
  therefore cannot self-heal merely by the passage of time or by an unrelated redeploy (which is
  additive-only) — it heals only when (i) the offending deployed file is explicitly removed, or
  (ii) its declaration is added/restored.
- This repo is mid-way through a large **concurrent** multi-task `/orchestrate` batch today: 10
  other task numbers (137, 143, 153, 154, 158, 159, 160, 161, 166, 167) have commits with today's
  date, and at observation time this research session's own process list showed *other* live
  `verify-deploy.sh --skip-slow` processes running under `.claude/scripts/` (i.e. other
  concurrently-executing task sessions doing their own postflight checks) alongside this
  session's `agent-system/extensions/core/scripts/verify-deploy.sh` run.
- The most parsimonious explanation consistent with all of the above: the original 1-finding
  observation caught a **transient** declared/deployed mismatch mid-edit by one of those other
  concurrent tasks — e.g. a moment where a source-store `index-entries.json` row had been removed
  (or a file added to the deploy tree) by another task's in-flight phase, before that task's own
  commit + redeploy cycle completed and reconciled the two sides. By the time this research
  session queried `find_orphans`, the other task(s) had already committed and the live tree and
  live declarations agreed again. This is consistent with `.claude-extensions.json` and
  `.claude/context/index.json` both showing very recent regeneration timestamps (14:08, same
  session window) from an intervening redeploy.
- This explanation is falsifiable and cheap to re-check: if gate 13 fails again, the
  `deploy-orphan-detection.md` measurement recipe (clean scratch-clone regenerate + diff) plus a
  process-list check for concurrently-running `/orchestrate` batches is the direct way to
  confirm or refute it, without needing to catch the exact race in the act.

**Constraint check**: no detection code or exclusion-class list was touched to reach 0 findings
here — this is the gate reporting its true current state, not a weakened check. No production or
test file was edited for this failure; there is nothing to fix in the source store for FAILURE 2
as currently observed.

**Regression safety**: gate 13 itself is the regression guard — it runs on every
`verify-deploy.sh` invocation (part of every task's postflight redeploy checkpoint per this
task's own trigger scenario) and will re-fail loudly if a real orphan or ghost index row
reappears. `context/patterns/deploy-orphan-detection.md`'s 4-class exclusion contract and
measurement recipe remain the authoritative tool for classifying any future finding as
real-orphan vs. one of the four documented noise classes (runtime artifact, merged/generated
artifact, `.syncprotect`-protected path, uncommitted working-tree artifact).

### Full verify-deploy.sh run: gates 12 and 13 pass; one unrelated pre-existing failure surfaced

```
[verify-deploy] FAIL -- 1 of 30 check(s) failed
```
- Gate 12: PASS
- Gate 13: PASS
- Gate 3 (doc-lint, `check-extension-docs.sh --quiet`): **FAIL** — `Rule R: index-entries.json
  entry 'project/lean4/domain/comparator-integration.md' line_count mismatch: declared 219,
  actual 247`.

This is a **new, unrelated instance** of the same failure *class* the dispatch already noted was
fixed once before ("stale index-entries.json line_count declarations") and which this task's own
"RELATED, not a dependency" note attributes to a sibling task addressing line_count/gate-coupling
brittleness as a class. It surfaced live during this research pass, almost certainly because a
concurrent lean4-related task in today's batch edited `comparator-integration.md`'s content
without updating its `index-entries.json` `line_count` declaration. It is **out of scope for
task 151** (whose CONSTRAINTS and title name only gates 12 and 13) and was not touched here.
Flagging it is itself evidence for the value of the sibling gate-coupling task: an unrelated
task's edit can transiently or persistently break a shared, unrelated gate, exactly the coupling
problem that task addresses at the class level.

## Decisions

- FAILURE 1 remedy: **(a) route all four `test-force-phases.sh` write sites through
  `state-write.sh`**, uniformly (no split treatment between the real-path and `$WORKDIR`-path
  shapes) — already implemented in commit `89f575aed`, verified correct and complete above.
- FAILURE 2: **no code or detection change** — the gate currently reports its true state (0
  findings), the original finding is judged transient/concurrency-induced based on the evidence
  above, and the existing detect-never-auto-delete design plus documented exclusion contract is
  the correct standing mechanism for handling any future recurrence.
- Gate 3's fresh `lean4` `line_count` drift is explicitly **out of scope** for this task and is
  not remediated here; it should be left for the sibling line_count/gate-coupling task or a
  fresh, separately-scoped fix.

## Risks & Mitigations

- **Risk**: FAILURE 2's root cause (a plausible-but-unproven transient concurrency race) could
  recur under similar batch conditions and again present with no captured detail.
  **Mitigation**: `deploy-orphan-detection.md`'s measurement recipe is the standing tool for
  exactly this; recommend that the next time gate 13 fails, the finding be captured immediately
  (`orphan_output` before `grep -c`) rather than only the summary count, so a future recurrence is
  diagnosable without needing to catch a live race.
- **Risk**: Treating this task as "done" without any code change might read as under-delivery
  against the acceptance criteria's literal wording ("Whole-tree orphan detection reports 0
  findings, with the finding's actual identity documented"). **Mitigation**: this report
  documents the identity question honestly (not reproducible, with a specific evidenced
  hypothesis) rather than fabricating a specific file/row that was never observed.

## Context Extension Recommendations

- **Topic**: capturing full orphan-finding detail at fail time, not just the count.
- **Gap**: `verify-deploy.sh`'s gate 13 branch only extracts `ORPHAN_FINDING` lines into
  `FINDINGS_LIST` when `$FINDINGS = "true"` (i.e. `--findings` mode); a default `bash
  verify-deploy.sh` run without `--findings` discards the specific finding text even though
  `$orphan_output` was already captured in the shell variable, which is exactly why this task's
  originating incident had no captured detail to research from.
- **Recommendation**: consider having gate 13 (and gate 5, which has the same suppress-and-
  extract shape) always log the raw `ORPHAN_FINDING`/`FINDING` lines to a small rotating file
  (e.g. `specs/tmp/last-gate-findings.log`) on failure, independent of the `--findings` flag, so a
  future occurrence is diagnosable from the very first observation instead of requiring a
  multi-minute non-`--quiet` re-run (which is itself what this task's dispatch had to instruct).
  This is a process-improvement observation, not a requirement of this task's acceptance
  criteria.

## Appendix

Commands run (all against the live repo, no files modified by this research):
- `bash agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh --verbose`
  (twice: whole store, and scoped to `test-force-phases.sh`)
- `bash agent-system/extensions/core/scripts/tests/test-force-phases.sh`
- `bash agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh`
- `nvim --headless -c "lua ... manager.find_orphans(...) ..." -c "qa!"` (direct gate-13 snippet)
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` (full run, ~2 min, all 30 gates)
- `bash .claude/scripts/check-extension-docs.sh` (gate 3 detail, for the out-of-scope finding)
- `git log`, `git show 89f575aed`, `git status --short`, `git check-ignore`

References:
- `agent-system/extensions/core/context/patterns/deploy-orphan-detection.md`
- `agent-system/extensions/core/scripts/state-write.sh` (header, `PROJECT_ROOT` resolution)
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh`
- Commit `89f575aed5674ef3ae573c9529121945b1e440d2`
