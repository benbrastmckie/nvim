# Research Report: Task #188

**Task**: 188 - Fix orchestrate-predispatch-review.sh Class A false positive: archived completed dependencies reported as nonexistent
**Started**: 2026-09-09
**Completed**: 2026-09-09
**Effort**: small (single-file jq change plus new test fixtures)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (EDIT TARGET), `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`, `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`, `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`, `agent-system/extensions/core/skills/skill-todo/SKILL.md`, `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
- Local empirical cross-check of `specs/state.json` vs `specs/archive/state.json` in this repository
**Artifacts**:
- specs/188_predispatch_review_archived_dependency_false_positive/reports/01_archived-dependency-false-positive.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed**: Class A of `orchestrate-predispatch-review.sh` resolves every raw
  `dependencies[]` target against `specs/state.json`'s `active_projects[]` array only (the `$all`
  binding at line 213). Once `/todo` archives a completed dependency, it is moved out of
  `active_projects[]` into `specs/archive/state.json` (+ its directory moves to
  `specs/archive/{NNN}_{slug}/`), so the dependency lookup returns null and the edge is bucketed
  as `"nonexistent"` — the loudest verdict this classifier has — even though it is fully satisfied.
- **Empirically reproduced in this repository**, not just BimodalLogic: cross-checking
  `specs/state.json`'s `active_projects[].dependencies[]` against `specs/archive/state.json`
  found **20 dependency edges** currently flagged `nonexistent` that all resolve to archived
  tasks, and **0 genuinely nonexistent** edges. Same ~100%-false-positive pattern the dispatch
  measured elsewhere. Sample pairs (dependent → dependency): 136→146, 136→91, 170→151, 127→125,
  170→169, 129→128, 155→153, 44→87, 76→146, 88→148 (10 more not listed).
- **A ready-made fix mechanism already exists and is already proven in this exact codebase**:
  `scripts/lib/task-lookup-lib.sh` is the established single source of truth for archive-aware
  task lookup (`task_lookup_archived_projects_json`, `task_lookup_entry`,
  `task_lookup_is_active`, `task_lookup_dir`). `orchestrate-triage-classify.sh` already sources
  it and already merges active + archived into its own `$all` binding (lines 203, 222–225,
  292, 395) — including resolving per-dependency status from that merged array for its own
  "blocked, dependency outstanding" check (line 465). The fix for `orchestrate-predispatch-review.sh`
  is to adopt the identical, already-battle-tested pattern, not to invent a new one.
- **The "completed but not yet archived" case the dispatch asks about is already handled
  correctly and needs no new verdict**: a dependency still in `active_projects[]` with a
  terminal status already buckets as `"out_of_batch_terminal"`, which is distinct from
  `"nonexistent"` today. Only the archived case is missing a bucket.
- **Neither `orchestrate-batch-admit.sh` nor `orchestrate-triage-classify.sh` need the same
  correction.** `orchestrate-triage-classify.sh` already merges active+archived (see above — this
  was fixed by an earlier task, per that file's own header narrative). `orchestrate-batch-admit.sh`'s
  active-projects-only comparison set is *intentionally* correct: an archived (terminal)
  dependency task poses zero live file_scope collision risk, so its absence from the collision
  comparison set is the correct behavior, not a bug — and `grep -n "nonexistent"` across both
  scripts returns nothing; that wording, and the underlying defect, is unique to this script's
  Class A.

## Context & Scope

Task 188 (`task_type: meta`) asks for a fix to `orchestrate-predispatch-review.sh`'s Class A
dependency-edge classifier so that a dependency satisfied by an archived (completed) task is no
longer reported at the same loud "nonexistent" volume as a genuinely absent dependency, while
confirming the archive directory-naming assumption and checking two sibling scripts
(`orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`) for the same defect. This is a
research-only dispatch; no code was changed. `agent-system/extensions/core/` is this repository's
source store — `.claude/scripts/orchestrate-predispatch-review.sh` is a gitignored, disposable
deploy artifact regenerated from it (`.claude/rules/source-store-deploy-boundary.md`), so the fix
belongs in `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`.

## Findings

### Codebase Patterns

- **`orchestrate-predispatch-review.sh`** (`agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`):
  Class A/B share one jq program (lines 207–248). `$all` is bound at line 213 as
  `($state_arr[0].active_projects // []) as $all` — active-only. The per-dependency
  classification block (lines 216–228) resolves each `$d` via
  `([$all[] | select(.project_number == $d)] | first) as $dep_entry`, then buckets: null →
  `"nonexistent"`; found with a terminal status → `"out_of_batch_terminal"`; found otherwise →
  `"out_of_batch_live"`. Class B (lines 229–239) resolves the *candidate's own* entry the same
  active-only way, so an archived candidate being force-redispatched (see below) would also
  silently produce zero Class A/B findings for that candidate today, not an error.

- **`scripts/lib/task-lookup-lib.sh`** already solves exactly this problem and is documented as
  the single source of truth for archive-aware lookup:
  - `task_lookup_archived_projects_json <state_file>` reads
    `${state_file%state.json}archive/state.json`, flattens `completed_projects` +
    `archived_projects` into one array, and normalizes `.status` (completed/abandoned/expanded
    preserved verbatim; any other archive-only status maps to `"completed"`). Emits `"[]"` when
    the archive file is absent.
  - `task_lookup_entry`, `task_lookup_is_active`, `task_lookup_dir` round out the API (active
    wins; archive is a fallback).
  - The file's own header names its consumer-discovery mechanism:
    `grep -rl 'task-lookup-lib.sh' agent-system/extensions` — the intended way to find every
    current consumer, rather than a hardcoded list.

- **`orchestrate-triage-classify.sh`** is the precedent consumer and proves the pattern works at
  scale: it sources the lib at line 203 (immediately after `lib/common.sh`, before
  `PROJECT_ROOT`/`deploy-root-guard.sh`), computes the archived-projects JSON and writes it to a
  `mktemp` file (lines 222–225) rather than passing it via `--argjson` — the file's own comment
  documents an **observed ~960KB archive/state.json triggering "Argument list too long" (exit
  126)** when embedded directly into jq's argv, hence reading it back via `--slurpfile` from disk
  instead, which has no such ceiling. It then merges
  `(($state_arr[0].active_projects // []) + $archived_raw[0]) as $all` (lines 292, 395), and
  explicitly resolves per-dependency status from that **merged** `$all` for its own
  "blocked, dependency outstanding" discharge logic (line 465), with an inline comment noting the
  status must come from `$all`, not `$candidates`, to avoid reproducing an "infinite-skip defect"
  a prior fix already addressed.

- **`skill-todo/SKILL.md`** ("Move project directories to specs/archive/", roughly lines
  439–535) confirms the archive/state.json write and the directory move happen in the *same*
  `/todo` run: step 439 adds the entry to `specs/archive/state.json`'s `completed_projects` (or
  `archived_projects` for abandoned tasks); step 493 moves the directory via
  `target_dir="specs/archive/$(basename "$source_dir")"`, i.e. the zero-padded `{NNN}_{slug}`
  name is carried over verbatim. This is the concrete basis for treating
  `task_lookup_archived_projects_json` (state-file-based) as a faithful, already-in-sync proxy
  for "resolvable under `specs/archive/`" — no new filesystem-scanning code path is needed, which
  also respects this script's own stated Context Flatness Constraint ("reads ONLY
  `specs/state.json` directly, plus ... one subprocess call to `orchestrate-batch-admit.sh`").

- **Empirical reproduction in this repository** (Python cross-check of `specs/state.json`
  against `specs/archive/state.json`): of every `active_projects[].dependencies[]` edge pointing
  outside `active_projects[]`, **20 resolve to `specs/archive/state.json` entries and 0 are
  genuinely absent from both**. Every one of those 20 is currently mis-reported as `"nonexistent"`
  by the live script. This independently corroborates the dispatch's BimodalLogic measurement
  (37 flagged, 37 archived, 0 genuinely absent) in a second repository using the same source
  store.

- **`orchestrate-batch-admit.sh`**: `grep -n "nonexistent"` returns no hits — it never emits a
  `"nonexistent"`-flavored verdict at all. Its own active-projects-only `$all` (line 511) is used
  for two things: (a) looking up the *candidate's* own entry — `$entry == null` (i.e. the
  candidate itself isn't in `active_projects[]`) silently **admits** it with
  `self_modifying: false` (lines 547–549); this is a different, unreported behavior, not a
  `"nonexistent"` finding, and out of this task's stated scope; (b) building the
  file_scope-collision `$comparison_set` (lines 601–607) by iterating `$all[]` — an archived
  (terminal) dependency task can never appear in `$all` regardless of the dependency-edge
  exclusion clause, but since a terminal/archived task poses **zero live file_scope collision
  risk**, its absence from the comparison set is the *correct*, intended behavior. This is not a
  defect the task needs to fix.

- **`orchestrate-triage-classify.sh`** requires no correction — see above: it already merges
  active+archived everywhere relevant. Its own header narrative describes this as "Phase 5 of the
  task that fixed this classifier's archive-blindness" and "Phase 1" for the library's
  extraction, i.e. an earlier task already closed this gap for this script specifically.

- **Test coverage gap**: `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
  (241 lines) stubs only `orchestrate-batch-admit.sh` and exercises Classes B/C/D/E rendering
  behavior; it has **no fixture that populates a `dependencies` array or an
  `specs/archive/state.json` file at all**, so Class A's dependency-edge logic — including this
  bug — is currently untested. `setup_sandbox` (lines 54–61) copies only
  `orchestrate-predispatch-review.sh`, `deploy-root-guard.sh`, `state-write.sh`, and
  `lib/common.sh` into the sandbox.

### External Resources

Not applicable — this is a self-contained shell/jq defect fix with no external library or API
surface; no web research was needed or performed.

### Recommendations

1. Source the lib: add `source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"` immediately after the
   existing `source "${SCRIPT_DIR}/lib/common.sh"` (current line 128), before `PROJECT_ROOT=...`
   — matching `orchestrate-triage-classify.sh`'s exact ordering (its lines 200–205).
2. Stage the archived-projects JSON via a `mktemp` file before the Class A/B jq invocation
   (before current line 207), mirroring `orchestrate-triage-classify.sh` lines 222–225 verbatim —
   the same `--argjson` ARG_MAX risk documented there applies here on any repo with a long-lived
   archive.
3. Change the Class A/B jq program's `$all` binding (current line 213) to
   `(($state_arr[0].active_projects // []) + $archived_raw[0]) as $all`, adding a new
   `--slurpfile archived_raw <tmpfile>` argument. This incidentally also fixes Class A/B's
   candidate-entry lookup for the case where the candidate itself is an archived/terminal task
   being force-redispatched — `CLAUDE.md` documents that `/orchestrate`'s forced-phase flags can
   dispatch into an already-archived task "without ever changing its status or writing to the
   archive," which the current active-only `$entry` lookup would otherwise silently miss
   entirely (zero Class A/B output for that candidate, not an error).
4. Additionally bind an archived-only project-number set, e.g.
   `($archived_raw[0] | map(.project_number)) as $archived_nums`, and extend Class A's
   per-dependency bucket decision (current lines 223–225) to a 4-way branch:
   `$dep_entry == null` → `"nonexistent"`; else `$d` present in `$archived_nums` → a new bucket
   (suggest `"archived_satisfied"`, following the existing `out_of_batch_terminal` /
   `out_of_batch_live` naming style); else keep the existing terminal/live split unchanged. This
   leaves `out_of_batch_terminal` exactly as-is for the "completed but not yet archived" case —
   already correctly distinguished from `"nonexistent"` today, so no new verdict is needed there.
5. Report-mode output (Class A section, current lines 442–456): the word `"nonexistent"` should
   only ever appear for the true-nonexistent bucket (satisfied structurally by recommendation 4's
   distinct bucket name). As a presentation choice for planning/implementation to settle, consider
   reusing this script's own established two-part convention already applied to Classes C and D
   ("Deferred: ..." / "Admitted: ...") to split Class A into a primary loud list plus a separate,
   clearly-labeled informational "Archived (satisfied)" list, rather than inventing a new
   presentation pattern. The file's stated design philosophy throughout (e.g. Class E's comment
   on avoiding a "0 findings vs. 0 matched conflation") favors explicit, never-silent reporting
   over suppression — full suppression of `archived_satisfied` findings is **not** recommended;
   informational demotion via wording/section placement is.
6. Extend `test-orchestrate-predispatch-review.sh`: add `lib/task-lookup-lib.sh` to
   `setup_sandbox`'s copy list, and add fixtures that (a) write a dependency pointing at a task
   present only in a synthetic `$WORKDIR/specs/archive/state.json`, asserting the new bucket
   label appears and the word `"nonexistent"` does not; and (b) write a dependency pointing at a
   task present in neither file, asserting `"nonexistent"` still fires.
7. Deploy check: `scripts/lib/task-lookup-lib.sh` is already present at both the source store
   (`agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`) and this repository's live
   deployed copy (`.claude/scripts/lib/task-lookup-lib.sh`), so no new deploy-manifest wiring is
   needed for the library itself — only `orchestrate-predispatch-review.sh`'s own regeneration
   (already an existing deploy target) needs to carry the fix forward, satisfying the
   acceptance criterion that a redeployed consuming repo reproduces both outcomes.

## Decisions

- No new "completed but not yet archived" verdict is needed — `out_of_batch_terminal` already
  covers it correctly and non-loudly.
- `orchestrate-batch-admit.sh` needs no correction: its active-only comparison set is
  intentionally correct for terminal/archived dependencies (zero live collision risk), and it
  never emits a `"nonexistent"`-flavored verdict.
- `orchestrate-triage-classify.sh` needs no correction: it already merges active+archived via
  `task-lookup-lib.sh` (an earlier task's fix) for its own dependency-discharge check.
- The fix should reuse `scripts/lib/task-lookup-lib.sh` rather than introduce a second,
  filesystem-directory-scanning resolution path — `/todo` keeps `specs/archive/state.json` and
  the `specs/archive/{NNN}_{slug}` directory move in lockstep (same run), so the state-file-based
  lookup is a faithful proxy and preserves this script's own stated Context Flatness Constraint.

## Risks & Mitigations

- **Risk**: the `--argjson` size ceiling that forced `orchestrate-triage-classify.sh` onto a
  `--slurpfile`-via-tempfile pattern applies identically here on a repo with a long-lived
  archive. **Mitigation**: adopt the same tempfile pattern from the start (recommendation 2)
  rather than `--argjson`.
- **Risk**: widening the Class A/B `$all` binding to include archived entries could have
  unintended effects if that same binding is reused elsewhere in the script. **Mitigation**:
  confirmed the Class C/D/E jq program lower in the file (lines 361–431) has its own, separate
  `$all` binding sourced from the `orchestrate-batch-admit.sh` subprocess output plus
  `$state_arr` — unaffected by this change. Verify at implementation time that no other reference
  to the Class A/B `$all` binding exists beyond the Class A/B blocks (lines 216–239) before
  landing the merge.
- **Risk**: no existing test exercises Class A/dependency logic, so a regression here could go
  unnoticed. **Mitigation**: recommendation 6 (new fixtures) should land in the same phase as the
  fix, not deferred to a follow-up.

## Context Extension Recommendations

None — `task-lookup-lib.sh` already documents its own self-verifying consumer-discovery
mechanism (`grep -rl 'task-lookup-lib.sh' agent-system/extensions`); no new context file is
needed for this task.

## Appendix

- Search queries / commands used: `find` for `orchestrate-predispatch-review.sh` /
  `orchestrate-batch-admit.sh` / `orchestrate-triage-classify.sh`; `grep -n` over each script for
  `active_projects`, `dependencies`, `task_lookup`, `nonexistent`, `archive`; full `Read` of
  `orchestrate-predispatch-review.sh` and `task-lookup-lib.sh`; targeted `Read`/`grep` of
  `orchestrate-batch-admit.sh`, `orchestrate-triage-classify.sh`, `skill-todo/SKILL.md`, and
  `test-orchestrate-predispatch-review.sh`; a local Python cross-check of `specs/state.json`
  against `specs/archive/state.json` to empirically reproduce the false-positive count in this
  repository.
- References: `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`,
  `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh`,
  `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`,
  `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
  `agent-system/extensions/core/skills/skill-todo/SKILL.md`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`.
