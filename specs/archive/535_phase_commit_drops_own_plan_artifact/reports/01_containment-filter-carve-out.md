# Research Report: Task #535

**Task**: 535 - Carve a task's own specs/ artifacts out of git-commit-phase.sh's containment filter, so a task's own plan file is never dropped from its own phase commit.
**Started**: 2026-11-23T03:40:44Z
**Completed**: 2026-11-23T03:55:00Z
**Effort**: Small (narrow correction + test fixtures; code defect already closed)
**Dependencies**: port_containment_strip_to_git_commit_scoped (567) — completed; dependency already satisfied, see Findings
**Sources/Inputs**: Codebase (git-commit-phase.sh, test-git-commit-phase.sh, git-staging-scope.md, orchestrator-runtime-files.md, runtime-file-patterns.sh), git log, live test-suite run
**Artifacts**: reports/01_containment-filter-carve-out.md (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The code defect this task description opens with — `is_contained()` testing `files_touched`
  only against the declared `file_scope`, with no carve-out for the committing task's own
  directory — is **already closed**. `scripts/git-commit-phase.sh` carries
  `file_scope_arr+=("${task_dir}/")` (plus `specs/TODO.md`/`specs/state.json` via the
  engine-written-state allowlist) inside its Phase-Commit Containment Self-Check, and
  `scripts/tests/test-git-commit-phase.sh` Cases 15/16 pin the admission and the paired
  genuine-excursion drop. The full 39-case (98-assertion) suite is green against the live
  source-store copy. This was landed by task `port_containment_strip_to_git_commit_scoped`
  (567, completed) — the dependency the task description's own "RE-MEASURED AND RULED" note
  names is therefore already satisfied in practice.
- One genuine code/contract divergence remains: `context/standards/git-staging-scope.md`'s
  "Staging-Layer Containment Filter" subsection still states a **false mechanism** for the
  carve-out ("never tested against this filter at all ... structurally outside its reach") that
  the landed fix contradicts for three of its four named paths. This single sentence pair is the
  one remaining correctness defect in the record.
- Two acceptance-criterion gaps remain in the test suite, both narrow and additive: (a) no
  fixture exercises a dotfile directly at the task-directory root (`.return-meta.json`,
  `.orchestrator-handoff.json`) as a `files_touched` entry — Cases 15/16 use a path one level
  down (`reports/01_probe-report.md`); (b) no case explicitly asserts that the post-commit
  completeness check **runs** (rather than being silently skipped) in the single-own-file case —
  existing cases only assert its absence-of-failure or its skip under the three *other*
  fail-open paths (missing/malformed progress file, empty `files_touched`).
- Recommended approach for the plan phase: a single small phase correcting the standard's prose,
  plus two to three new regression cases in `test-git-commit-phase.sh` extending (not replacing)
  the existing Case 15/16 pair. No change to `git-commit-phase.sh` itself, `git-commit-scoped.sh`,
  or `agents/general-implementation-agent.md` is needed.

## Context & Scope

The task description is unusually long because it accreted five rounds of evidence across a
migration from another repository, plus one in-repo re-measurement. The re-measurement
paragraph (headed "RE-MEASURED AND RULED", citing `specs/decisions/commit-layer-cluster-ordering.md`)
already supersedes most of the earlier analysis: it states the code fix (route (a)) is done and
must not be re-implemented, narrows remaining work to two items, and records a dependency on
task 567. This research verified that re-measurement against the live source store rather than
trusting it at face value, since the dispatch explicitly asks for the gap to be re-derived, not
assumed.

Scope of this research: confirm the current state of `scripts/git-commit-phase.sh` and its test
suite against every claim in the task description; identify precisely what (if anything) is
still missing against the description's acceptance criteria; and locate the exact text requiring
correction in `context/standards/git-staging-scope.md`. No code was changed during this research
phase — only read, grep, and a live test-suite invocation.

## Findings

### Codebase Patterns

**The carve-out is landed, source-store side.** In
`agent-system/extensions/core/scripts/git-commit-phase.sh` (853 lines), inside the Phase-Commit
Containment Self-Check's non-empty `file_scope_arr` guard:

- `file_scope_arr+=("${task_dir}/")` — the committing task's own resolved task directory is an
  explicit, admitted member of the array `is_contained()` iterates, mirroring Sites 1
  (`orchestrate-cycle-postflight.sh`) and 3 (`git-commit-scoped.sh`'s V10) per
  `git-staging-scope.md`'s "Three Containment sites, not one".
- `specs/TODO.md` and `specs/state.json` are admitted via the shared
  `scripts/lib/engine-written-state-paths-lib.sh` allowlist (with a hardcoded two-literal
  fallback if that library fails to source/resolve).
- `is_contained()`'s containment test (`case "$path" in "$entry"/*) return 0 ;; esac`) is plain
  bash case-pattern matching, not filesystem glob expansion — it has no "skip dotfiles" behavior,
  so a dotfile directly under an admitted directory entry (e.g. `specs/999_probe/.return-meta.json`
  against the `specs/999_probe/` entry) is already matched correctly by the existing code. This
  was verified by reading the implementation (lines ~673–697); no fixture currently exercises it
  (see Context Extension / Risks below), but the mechanism itself needs no change.
- The fourth path the task description calls out, the `--plan-path`-supplied plan path, is
  staged via a separate code path (`stage_paths+=("$plan_path")`, line 455) that bypasses
  `files_touched`/`file_scope_arr` entirely when supplied via that flag — this one genuinely is
  "appended to the staged set before the filtered loop runs" and never tested by `is_contained()`.
  It needs no fix because it is always a sub-path of the now-admitted `task_dir/`, so even if it
  *were* tested it would pass; the standard's correction (see Recommendations) should distinguish
  this one truly-untested-but-harmless path from the other three, which are now tested and pass.

**Test coverage, verified live.** Ran
`bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` against the source
store: 39 numbered cases, 98 assertions, **98 passed, 0 failed**. Of direct relevance:

- Case 15 ("an own-task-directory path lands with no drop warning and no scope-excursion issue
  record") — fixtures a `files_touched` entry at
  `specs/999_probe/reports/01_probe-report.md` (a `reports/` subpath, structurally identical to a
  plan artifact under `plans/`), asserts no drop warning and no `issues.jsonl` scope-excursion
  row. Its own comment explicitly says it was "confirmed by direct probe against the unmodified
  (pre-fix) script" to have reproduced the originating defect (file lands via the unconditional
  `stage_paths` seed regardless, but with a spurious warning/issue row) before the fix landed.
- Case 16 (paired negative) — same fixture run, asserts a genuine out-of-territory path
  (`other/outside.txt`) is still dropped, still warned, still recorded as a scope-excursion issue.
- Case 21 (VERIFY 3) — asserts `specs/TODO.md` and `specs/state.json`, when self-reported in
  `files_touched`, land with no drop warning and are never proposed into `proposed_file_scope`.
  This covers acceptance item (3)'s `TODO.md`/`state.json` half directly.
- Case 17 (a/b/c) and Case 22 — fail-open preserved across missing/empty/malformed `file_scope`,
  paired with an own-task-directory path in Case 17's fixture, confirming no regression on the
  fail-open direction.

**What the suite does not yet cover**, checked by direct grep against the 1676-line test file:

1. No fixture places a `files_touched` entry naming a dotfile directly at the task-directory
   root (`specs/{NNN}_{SLUG}/.return-meta.json` or `.orchestrator-handoff.json`) — grepping the
   test file for `orchestrator-handoff` returns zero matches, and every `.return-meta.json`
   occurrence is the fixture-setup helper file, never a `files_touched` test target. The "ADDED
   EVIDENCE" sections of the task description specifically ask for this shape because the two
   observed recurrences (task 865, task 872) were exactly dotfiles at the directory root rather
   than nested under a named subdirectory.
2. No test positively asserts that `run_completeness_check` stays `true` and the check actually
   executes in the single-own-file case. Grepping for `completeness check` / `run_completeness_check`
   across the test file shows every existing assertion is either (a) proving the check is
   *skipped* under one of the three independent fail-open paths (missing progress file, malformed
   JSON, empty derived `files_touched` — Cases 4/5/6/9), or (b) proving a *dropped* path is not
   wrongly named in a completeness-check failure (Case 24/VERIFY 5). None of the existing cases
   assert the check *ran and found everything clean* specifically for the own-task-directory
   admission path. Reading the code (`scripts/git-commit-phase.sh` lines 751–753) confirms the
   mechanism is otherwise already correct post-fix (`kept_files_touched` stays non-empty for
   Case 15's single entry, so `run_completeness_check` is never set to `false`), but this is
   presently true "by construction, unobserved" rather than pinned by an assertion — exactly the
   residual the task description's acceptance item (1) and the re-measurement's item (ii) call
   out.
3. There is also no explicit stderr diagnostic distinguishing "completeness check skipped because
   containment filtering emptied `files_touched`" from the other three skip reasons, which already
   each log their own `warn(...)` message (lines 461, 464, 482) — the containment-triggered skip
   path (line 751) is silent. A new test case can still assert the check ran by asserting the
   *absence* of all four existing skip-family warning strings together with `rc=0` and the file
   present in `git show --name-only`, following the same via-negativa pattern Cases 4/5/6/9
   already use for the inverse claim.

### Standard-Document Divergence (the one remaining code/contract gap)

`agent-system/extensions/core/context/standards/git-staging-scope.md`, "Staging-Layer
Containment Filter (a Refinement of the Fail-Safe Direction Above)" subsection, lines 363–365:

> "The four `specs/` carve-out paths (`TASK_DIR/`, `TODO.md`, `state.json`, and the plan path for
> `implement`) are never tested against this filter at all — they are appended to the staged set
> before the filtered loop runs, structurally outside its reach."

This is false for three of the four named paths, as landed: `TASK_DIR/`, `TODO.md`, and
`state.json` are now explicit members of `file_scope_arr` and ARE tested by `is_contained()` —
they simply always pass. Only the `--plan-path`-supplied plan path (when passed as a CLI flag
rather than self-reported in `files_touched`) is genuinely appended to `stage_paths` outside
`file_scope_arr`'s reach, and even that one is harmless because it is always a sub-path of the
now-admitted `task_dir/`.

The deployed mirror (`.claude/context/standards/git-staging-scope.md`) is byte-identical to the
source-store copy at this location (confirmed via `diff -q`), so there is no deploy-drift
explanation — this is the source document's own text, not a sync lag.

No other location in the repository repeats this false mechanism: a repo-wide grep for
"structurally outside its reach" and "never tested against this filter at all" across both
`agent-system/` and `.claude/` returns only this one subsection (both copies). In particular,
`agents/general-implementation-agent.md`'s "Phase-Commit Containment Self-Check" step 2 — the
specification the script was ported from — was read and confirmed to already describe the
correct behavior ("Carve out of the check entirely: this task's own task directory ... These four
are unconditionally staged by the wrapper and are never themselves task deliverables"), which is
compatible with either mechanism (carve-out-by-omission or carve-out-by-admission) and needs no
edit, consistent with the task description's own instruction.

### Dependency on Task 567

The task description's "RE-MEASURED AND RULED" paragraph states this task "now depends on
`port_containment_strip_to_git_commit_scoped` (567), by shared territory in
`test-git-commit-phase.sh`". `specs/state.json` shows task 567 with `status: "completed"`; its
plan (`specs/567_port_containment_strip_to_git_commit_scoped/plans/01_port-containment-strip.md`)
confirms it ported the deployed-tree containment strip into `git-commit-scoped.sh`'s V10
resolution block and added its own regression case (Z19) plus restored Case 26's end-to-end
assertion — git log confirms three phase commits for task 567 touching exactly the three files
this task's `file_scope` also names (`git-commit-phase.sh`, `test-git-commit-phase.sh`,
`git-staging-scope.md`), most recently `0fde006d7 task 567 phase 3: record Site-3 closure in
git-staging-scope.md`. Because 567 is already completed, the dependency is satisfied as a matter
of fact; `specs/state.json`'s `depends_on` field for task 535 is currently `null`. Whether to
formally record a (now-moot, already-satisfied) `depends_on` edge is a judgment call for the plan
phase — the practical consequence is only that any new test case numbering in this task's plan
should be added *after* reading the current (567-updated) state of `test-git-commit-phase.sh`
rather than against a stale line-number assumption, since 567 already renumbered/added cases up
through Case 39.

### `scripts/lib/runtime-file-patterns.sh` — transplanted criterion (c) confirmed moot

Spot-checked the library's exported accessor functions (`runtime_ignore_block`,
`runtime_specs_ignore_block`, `specs_tree_ignore_block`, `runtime_mt_state_path`,
`runtime_return_meta_multi_path`, `runtime_conclusion_pending_marker_path`, `runtime_recap_path`).
The landed carve-out in `git-commit-phase.sh` does not consult this library at all for the
own-task-directory admission — it is a direct, path-shaped `file_scope_arr+=("${task_dir}/")`
literal, not a class-membership lookup against a shared predicate. This confirms the task
description's own ruling that the transplanted criterion (c) — "the carve-out's class membership
derives from a single source of truth shared with `orchestrator-runtime-files.md`" — is moot
for the landed shape: there is no class-membership question to settle, because the fix never
routed through class membership in the first place.

## Recommendations

1. **Correct `git-staging-scope.md`'s mechanism sentence** (lines 363–365 quoted above). Replace
   the false "never tested ... structurally outside its reach" claim with an accurate statement:
   the task's own resolved directory, `specs/TODO.md`, and `specs/state.json` are explicit members
   of `file_scope_arr` and are tested by `is_contained()` like any other entry — they pass because
   they are admitted, not because they are skipped. Only the `--plan-path`-supplied plan path
   (when passed as a flag rather than self-reported) bypasses the test entirely, and it is
   harmless because it is always a sub-path of the now-admitted task directory. State this once,
   accurately, rather than repeating the policy a third time (the policy conclusion itself is
   already correct and needs no change).
2. **Add a dotfile-at-task-directory-root regression case** extending the Case 15/16 pair (not
   replacing them): a `files_touched` entry naming `specs/{NNN}_{SLUG}/.return-meta.json` and a
   second naming `specs/{NNN}_{SLUG}/.orchestrator-handoff.json`, each asserting the same
   properties Case 15 already asserts (lands, no drop warning, no scope-excursion issue row).
   This directly answers the "ADDED EVIDENCE" sections' concern that a dotfile at the directory
   root might be classified differently from a path in a named subdirectory — verified above to
   not be the case mechanically, but currently unpinned by any fixture.
3. **Add an explicit completeness-check-runs assertion** for the single-own-file case (either as
   a new sub-assertion on Case 15's existing fixture or as its own small case): assert `rc=0`,
   the file present in `git show --name-only`, and the absence of every one of the four existing
   skip-family warning strings (`progress file not found`, `progress file is not valid JSON`,
   `nothing to derive`, and `completeness check failed`) together — proving the check ran to
   completion rather than being silently skipped, the exact failure this task description
   identifies as the real cost of the original defect.
4. **Demonstrate-fails-first discipline, scoped correctly.** Because route (a) is already landed,
   the new cases added under items 2–3 cannot "fail against the unmodified script" in the sense
   of the current repository state (there is no unmodified state to fail against — it is already
   fixed). The equivalent discipline for this task is: temporarily comment out the
   `file_scope_arr+=("${task_dir}/")` line (and, for completeness, the engine-written-state
   allowlist splice), confirm the new cases fail against that deliberately-reverted copy, then
   restore the line and confirm green — demonstrating the new fixtures actually exercise the
   mechanism they claim to pin, not merely duplicating Case 15/16's existing coverage under a new
   path.
5. **No change needed** to `scripts/git-commit-phase.sh`'s logic itself, `git-commit-scoped.sh`,
   any V-gate, or `agents/general-implementation-agent.md`. No `file_scope`/`depends_on` edit is
   required for task 567 (already completed; dependency already satisfied in fact).

## Decisions

- Confirmed via live test-suite execution (98/98 passing) that the task description's own
  "RE-MEASURED AND RULED" ruling is accurate: the code defect is closed, route (a) is done, and
  no re-implementation should occur. Planning should proceed directly to the two remaining items
  (standard-text correction + fixture additions) rather than re-deriving or second-guessing the
  closure.
- Scoped the standard-text correction narrowly: only the two-sentence mechanism claim in the
  "Staging-Layer Containment Filter" subsection is wrong; the policy conclusion in the same
  subsection and everywhere else in the document is accurate and must not be restated or
  duplicated.
- Scoped the new fixtures to extend, not replace or renumber, the existing Case 15/16 pair and
  the current Case 1–39 sequence (now including 567's additions through Case 39), consistent with
  the task description's explicit instruction not to replace Case 7/8 (now Cases elsewhere in the
  renumbered suite covering the same genuine-excursion / fail-open guarantees).

## Risks & Mitigations

- **Risk**: a new fixture duplicates Case 15/16's coverage without adding signal (e.g., testing
  a `reports/` subpath again under a different filename). **Mitigation**: the new cases must
  specifically target a dotfile *directly at the task-directory root* (no intervening named
  subdirectory), which is mechanically distinct from Case 15/16's `reports/01_probe-report.md`
  path and is the exact shape the task description's evidence sections name.
- **Risk**: editing `git-staging-scope.md`'s mechanism sentence without updating its neighboring
  prose (the "dispatching task's own resolved task directory is always an implicit, unconditional
  in-scope member" sentence immediately preceding it, which is already correct) could leave the
  subsection internally inconsistent — one sentence saying "implicit, unconditional in-scope
  member" (correct, admission-based) immediately followed by another saying "never tested ...
  structurally outside its reach" (false, omission-based) for an overlapping set of paths.
  **Mitigation**: the correction should explicitly reconcile the two sentences — state plainly
  that admission into `file_scope_arr` IS the mechanism by which `TASK_DIR/`, `TODO.md`, and
  `state.json` are "implicit, unconditional in-scope members," rather than treating "implicit
  in-scope member" and "never tested, structurally outside its reach" as two different, coexisting
  claims about the same paths.
- **Risk (low)**: `test-git-commit-phase.sh` has grown to 39 cases / 1676 lines across multiple
  tasks (including 567's recent additions); a plan written against a stale copy could misplace
  new case numbers. **Mitigation**: the implementation phase should re-read the live file's
  current case count immediately before adding new cases, as this research did, rather than
  trusting the task description's own case numbering (which predates 567's additions and
  describes "Cases 7 and 8" using numbering current as of the original cross-repo record, not
  this repository's current sequence).

## Context Extension Recommendations

- **Topic**: dotfile-at-directory-root containment coverage.
- **Gap**: `context/standards/git-staging-scope.md` documents the own-task-directory admission
  mechanism in prose but does not call out that the admission is implemented via plain
  case-pattern string matching (not filesystem glob expansion), which is why dotfiles at any
  depth under the admitted directory are already covered without special-casing. A future reader
  auditing this mechanism for a different runtime-file class would benefit from this being
  stated explicitly, next to the existing "Own-task-directory member" code comment in
  `git-commit-phase.sh`.
- **Recommendation**: when the plan phase adds the dotfile fixtures recommended above, consider
  adding one sentence to the "Own-task-directory member" comment block in `git-commit-phase.sh`
  (around line 609) or to `git-staging-scope.md`'s corrected sentence, noting that `is_contained()`
  uses bash case-pattern matching rather than filesystem glob expansion, so dotfiles need no
  separate carve-out. This is advisory, not a new acceptance criterion.

## Appendix

### Search queries / commands used

- `jq -r '.extensions.core.source_dir' .claude-extensions.json`
- `grep -n "is_contained\|file_scope_arr\|stage_paths\|task_dir=" scripts/git-commit-phase.sh`
- `grep -n "Case 1[4-7]\|^test_case\|describe\|# Case " scripts/tests/test-git-commit-phase.sh`
- `grep -n "orchestrator-handoff" scripts/tests/test-git-commit-phase.sh scripts/git-commit-phase.sh context/standards/git-staging-scope.md`
- `grep -n "run_completeness_check" scripts/git-commit-phase.sh scripts/tests/test-git-commit-phase.sh`
- `grep -n "Staging-Layer Containment Filter\|structurally outside its reach" context/standards/git-staging-scope.md`
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` (live run: 98 passed, 0 failed)
- `git log --oneline -10 -- agent-system/extensions/core/scripts/git-commit-phase.sh agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh agent-system/extensions/core/context/standards/git-staging-scope.md`
- `diff -q .claude/scripts/git-commit-phase.sh agent-system/extensions/core/scripts/git-commit-phase.sh` (and the test/standard counterparts — confirmed no deploy drift)
- `jq -r '.active_projects[] | select(.project_number==535 or .project_number==567)' specs/state.json`

### References

- `agent-system/extensions/core/scripts/git-commit-phase.sh` — `is_contained()`, `file_scope_arr`,
  `run_completeness_check`, lines ~599–853.
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` — Cases 15, 16, 17, 21,
  22, 24 (VERIFY 3/5), 39 cases total.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — "Staging-Layer
  Containment Filter" subsection, lines 343–365; "Three Containment sites, not one," lines
  391–410.
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` and
  `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — consulted to confirm
  transplanted criterion (c) is moot for the landed, path-shaped carve-out.
- `specs/567_port_containment_strip_to_git_commit_scoped/plans/01_port-containment-strip.md` —
  the completed task that landed the Site-3 port and the Case 15/16/Z19 regression coverage.
