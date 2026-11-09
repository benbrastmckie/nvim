# Implementation Plan: Task #446

- **Task**: 446 - Close the plan-to-file-scope reconciliation gap
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: 430 (semantic + file overlap, must land first -- `[COMPLETED]`), 443, 407, 385, 328 (serialization only)
- **Research Inputs**: specs/446_close_the_plan_to_file_scope_reconciliation_gap/reports/01_plan_to_file_scope_reconciliation_gap.md
- **Artifacts**: plans/01_close-plan-file-scope-gap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The plan-to-`file_scope` reconciliation mechanism already exists, is additive, and is wired into
the `/orchestrate` plan cycle; research confirmed it was never the defect. Per the research
report's verdict table, the five observed divergences resolve to three distinct causes: a plan
**authoring** miss against a grammar the harvester implements exactly as documented (hypothesis
(a), #417's four backtick-quoted-but-not-entry paths), genuinely incomplete plan lists discovered
mid-implementation (hypothesis (d), all three #413 citations plus #417's four glob-only
destinations -- task 430's territory, not re-litigated here), and a since-fixed containment
predicate bug plus a **still-live loophole** (#424's `.claude/` entry, which today's normalized
`is_contained()` reads as covering every deployed-tree path -- the exact inverse of this record's
Hard Constraint).

PART A therefore does not widen the harvester's grammar (explicitly rejected, with a recorded
counter-example) -- it adds a narrow structural `.claude/**` **refusal** at every point a
deployed-tree path can enter `file_scope`, plus advisory authoring-time detection of the #417
shape at plan acceptance, where it is cheap to fix. PART B extends task 430's completed
`proposed_file_scope` channel rather than inventing a second one: the deposit is already durable,
but `git-commit-phase.sh` consults only `specs/state.json`'s committed `file_scope`, so a drop in
one phase does not inform the next phase's own commit within the same dispatch. Unioning this
task's own deposited array into the Containment check closes that within-dispatch window, and a
mechanical follow-up-commit trigger replaces "read the WARNING text" as the loop-closing step.

### Research Integration

Key findings carried directly into phase boundaries:

- **No harvester grammar change.** `plan-file-scope-harvest.sh`'s "one path per `` - `path` ``
  line; a continuation line belongs to the preceding entry" behavior mirrors
  `context/formats/plan-format.md`'s field definition verbatim. Widening it to scan every
  backtick token in a block was considered and rejected: #417's own Phase 2 block contains
  backtick-quoted tokens that are not paths at all (a quoted markdown heading, and a bare
  basename missing its directory prefix) sitting in ordinary prose inside the same block, so a
  token scan trades silent-drop for silent-garbage -- strictly worse, because a garbage entry can
  falsely legitimize an unrelated future edit under the Containment predicate.
- **A measured, present-day loophole.** A bare `.claude/` `file_scope` entry today judges every
  `.claude/**` path as CONTAINED. Re-measured at plan time against the live `specs/state.json`:
  no live task carries the catastrophic bare `.claude/` entry, but two live tasks (483, 512) each
  carry narrow `.claude/**` file paths, so the residue is real though currently non-widening.
- **Three leak paths, not one.** The research report names two (the harvester, and a hand-edited
  `state.json` reaching the containment site). A third was found at plan time and is folded into
  Phase 3: `propose_file_scope_addition()` itself can deposit a `.claude/**` path into
  `.return-meta.json`'s `proposed_file_scope`, which the implement postflight then merges into
  `state.json` via `--file-scope-add` -- re-seeding the loophole from a correct drop.
- **The dual-copy constraint is satisfied without touching either copy.** The harvest *call site*
  is duplicated (`scripts/skill-base.sh` ~lines 1061-1082, live; `scripts/orchestrator-postflight.sh`
  ~lines 330-350, no live caller). This plan changes the *harvester* and not the call site, so
  both copies inherit the new behavior with no edit to either -- recorded here so the constraint's
  satisfaction is auditable rather than assumed.
- **The end-to-end harness already exists.** `scripts/tests/test-skill-base-lifecycle.sh`'s
  Group 4a already drives the plan postflight against a fixture plan and asserts the merged
  `file_scope` equals the plan's list (not merely exit 0), so VERIFY item 3 extends an existing
  group rather than building a new harness.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:

- Rule, once and in one place, that a deployed-tree path is never a legitimate `file_scope`
  member, and enforce that ruling at all three points such a path can enter: the harvester, the
  mid-dispatch deposit, and the containment site's assembled scope array.
- Detect the #417 authoring shape (a comma-joined second path, or a wrapped continuation line
  that itself looks like an entry) at plan-acceptance time, advisory-only, before the harvest runs.
- Close PART B's within-dispatch window by unioning this task's own `proposed_file_scope` into
  `git-commit-phase.sh`'s Containment check, so a drop in one phase cannot recur in the next.
- Replace "read the commit's WARNING output" with a mechanical follow-up-commit trigger keyed on
  a newly-appeared `proposed_file_scope` entry.
- Keep `plan-file-scope-harvest.sh`'s header and `plan-format.md`'s field definition in verbatim
  agreement, as both already claim.

**Non-Goals**:

- Widening the harvester's entry grammar (rejected -- see Research Integration).
- Re-deciding auto-merge versus operator confirmation for `proposed_file_scope`. Task 430 settled
  that; this record extends the same channel and matches its ruling.
- Re-litigating hypothesis (d) divergences (#413's three citations, #417's four glob-only
  destinations). Those are task 430's territory by this dispatch's own instruction.
- Narrowing any other task's already-recorded `file_scope` in `specs/state.json`. The additive,
  never-remove semantics of `--file-scope-add` are preserved; existing residue is neutralized at
  the containment site instead of by mutating another task's declaration.
- Making any containment check fatal, or removing fail-open on a missing/empty/unreadable/
  malformed `file_scope`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `.claude/**` refusal is read as "the harvester now validates paths", conflicting with its documented never-filesystem-validates posture (a path the plan will CREATE must still be harvested) | H | M | Scope the refusal to a pure structural prefix test on the string (`.claude`, `.claude/`, `.claude/*`) -- categorically not an existence check. State this explicitly in the header comment the same edit touches, so the distinction travels with the code. |
| Stripping `.claude/**` entries empties `file_scope_arr`, silently turning the Containment check on | H | L | Re-test non-emptiness immediately after the strip and fall back to the existing fail-open path (skip the whole check) when nothing survives -- the same posture the current non-empty guard already implements. Pinned by a dedicated fixture. |
| Unioning `proposed_file_scope` is implemented as "any deposit is authoritative", weakening the check for a genuine excursion | H | L | Read only THIS task's own `.return-meta.json`, resolved exactly as `propose_file_scope_addition()` already resolves it; never a cross-task read. Pinned by a fixture asserting a genuine out-of-territory path is still dropped, still warned, and still issue-recorded. |
| The union re-admits a `.claude/**` path a correct earlier drop deposited, defeating the Hard Constraint | H | M | Order matters: the strip runs AFTER the union, over the single assembled array, so a deposited deployed-tree path cannot survive it. Phase 3 additionally refuses the deposit at source, making this defense-in-depth rather than the sole barrier. |
| Two live tasks (483, 512) carry `.claude/**` file_scope entries; the containment-site strip will begin dropping their deployed-tree edits | M | H | This is the Hard Constraint's intended outcome, not a regression: editing under `.claude/**` is already prohibited by `rules/source-store-deploy-boundary.md`, so dropping such a path is correct behaviour. Drop-and-warn is non-fatal and the dropped file is left on disk for review. |
| The advisory authoring check false-positives on legitimate prose, adding noise to every plan validation | M | M | Land it at `log_warn` only (never `log_error`), matching the Verification Tier and `Files to modify` presence checks' existing advisory-first posture in the same per-phase loop, and anchor each pattern to line-start. A miss is a missed warning, never a suppressed stricter finding. |
| `plan-format.md` is also in task 385's territory (serialization edge) | M | M | Re-read the file immediately before each edit per the concurrency note; stage only this task's own hunks; never a directory or glob `git add`. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 2, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Rule and enforce the deployed-tree refusal in the harvester, with its documentation mirror [COMPLETED]

**Goal**: Land the single ruling this record turns on -- a deployed-tree path is never a
legitimate `file_scope` member -- at the harvester, and keep the harvester header and
`plan-format.md`'s field definition in the verbatim agreement both already claim.

**Tasks**:

- [x] Re-derive the current line numbers for `extract_paths()`, the `HARVESTED=` assignment, and
      the final `jq -n` emission in `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh`
      (the research report's numbers were taken at research time and move). *(completed)*
- [x] Add a refusal stage operating on the harvested string set, placed so it filters BOTH the
      `extract_paths()` output and anything the generated-surface stage appends: drop any entry
      equal to `.claude` or `.claude/`, or matching the prefix `.claude/`, emitting one loud
      `>&2` warning per refused entry naming the entry and the governing rule
      (`rules/source-store-deploy-boundary.md`). Never silently. *(completed: strip applied to the
      single merged array, after the generated-surface append, via a `^\.claude(/.*)?$` regex)*
- [x] Confirm the refusal cannot change the exit-code contract: a plan whose every entry is
      refused still exits 0 with `[]`, and a refusal is never signalled through the exit code.
      *(completed: pinned by new Case 25)*
- [x] Extend the script's header comment: a new subsection stating the refusal, that it is a
      structural prefix test on the string and explicitly NOT a filesystem/existence check (the
      never-validates posture for every other path is unchanged), and that the sanctioned way to
      declare a whole-deployed-tree claim is the reserved `` `__WHOLE_TREE__` `` sentinel.
      *(completed)*
- [x] In `agent-system/extensions/core/context/formats/plan-format.md`'s `Files to modify` field
      definition (around line 108), add the matching sentence pair: each real path takes its own
      `` - `path` `` line (with the comma-join and wrapped-continuation shapes named as the
      anti-pattern), and never name a `.claude/**` path directly -- use the `` `__WHOLE_TREE__` ``
      sentinel, cross-referenced to the existing "Whole-tree-claim declaration rule" subsection.
      *(completed)*
- [x] Re-read both files immediately before editing (concurrency: `plan-format.md` is also in
      task 385's declared territory) and diff the header subsection against the `plan-format.md`
      sentences to confirm the mirror claim still holds after the edit. *(completed)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` with
      three cases appended after the existing Case 22: the #417 rendering (one entry line whose
      following indented line itself begins with a backtick, plus a separate entry line joining
      two backtick paths with a comma) asserting the CURRENT, unchanged first-path-only output as
      a regression pin of the documented semantics; a `.claude/**` entry refused out of the
      output with a stderr warning while a sibling real path survives; and a bare `.claude/`
      entry refused the same way. *(completed: Cases 23-25, 39/39 total passing)*
- [x] Re-run the harvester against
      `specs/archive/417_resolve_gate20_eager_load_budget_overage/plans/01_gate20-eager-load-headroom.md`
      and confirm the output is byte-identical to the pre-change output (that plan authors zero
      `.claude/**` paths, so the refusal must be a no-op for it). *(completed: confirmed identical
      against git show HEAD's pre-change copy)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-backfill-file-scope.sh,test-lean-challenge-snapshot.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh,test-skill-base-lifecycle.sh,test-validate-artifact.sh` is the exact set `suite_selection_select` returns for this phase's three touched paths, and the harvester has no caller outside those suites' reach.

**Scope Hypothesis**: three new fixture cases (Cases 23-25) and exactly two edited non-test files. Confirm at implementation time by counting the appended `=== Case` labels and by `git status --short` naming only `scripts/plan-file-scope-harvest.sh`, `context/formats/plan-format.md`, and `scripts/tests/test-plan-file-scope-harvest.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` - add the deployed-tree refusal stage and its header subsection
- `agent-system/extensions/core/context/formats/plan-format.md` - add the one-path-per-line anti-pattern sentence and the never-name-a-deployed-path sentence with the sentinel cross-reference
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` - append the #417 grammar pin and the two refusal cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` exits 0 with every pre-existing case still passing and the three new cases passing.
- The archived #417 plan's harvested output is unchanged from the pre-change run (captured before the edit, diffed after).
- A plan fixture whose only entry is `.claude/foo.sh` exits 0, emits `[]`, and writes a warning to stderr -- exit code and empty-array contract intact.
- The header subsection and the `plan-format.md` sentences state the same rule in the same terms.

---

### Phase 2: Advisory authoring-shape detection at plan acceptance [COMPLETED]

**Goal**: Surface the #417 authoring shape and the directly-named deployed-tree path at plan
acceptance time, where the author can still fix them, rather than at implement time via a drop.

**Tasks**:

- [x] Re-derive the current line numbers for the per-phase loop in
      `agent-system/extensions/core/scripts/validate-artifact.sh` (the `Files to modify`
      header-presence test sits around line 376; the deferred two-tier emission around line 553).
      *(completed)*
- [x] Inside the existing per-phase loop, add a `Files to modify` block scan emitting `log_warn`
      (never `log_error`) for each of three shapes: (i) an entry line whose immediately following
      line, leading whitespace stripped, itself begins with a backtick -- the #417 wrapped-
      continuation shape; (ii) an entry line carrying a second `` `...` `` pair after a comma --
      the #417 comma-join shape; (iii) an entry naming a path equal to `.claude`/`.claude/` or
      prefixed `.claude/` instead of the `` `__WHOLE_TREE__` `` sentinel. *(completed)*
- [x] Anchor each pattern to line-start with the same optional-leading-list-marker tolerance the
      header-presence test already uses, so a task bullet that merely mentions the field name in
      backticks is never misread as a field line (the precedent the Tier Justification check's
      own anchoring comment already records). *(completed: block captured via the same
      header/field-label-bounded awk shape the Tier Justification capture already uses)*
- [x] Confirm the new warnings route through the existing `warnings` counter and the existing
      `total_issues=$((errors + warnings))` `--strict` branch -- no new strictness logic, no new
      exit path. *(completed: verified by grep diff for log_error/exit -- only the two awk-internal
      capture exits, zero new script-level additions)*
- [x] Add an "Enforcement level" subsection for this check to
      `agent-system/extensions/core/context/formats/plan-format.md`, placed alongside the existing
      `Enforcement level (Files to modify)` subsection (around line 631) and following its shape:
      advisory-by-default, with the promotion criterion stated. *(completed)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` with fixtures:
      a plan exhibiting each of the three shapes warns and still exits 0 in default mode; the same
      plan exits non-zero under `--strict`; a correctly-authored plan (one path per line, sentinel
      used for a deploy phase) emits none of the three warnings. *(completed: FTM-shape(g)/(h),
      59/59 total passing)*
- [x] Re-read `plan-format.md` immediately before editing (Phase 1 also touched it; task 385
      shares territory) and stage only this phase's own hunks. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-gate-out-derived-staleness.sh,test-gate-out-repair-reporting.sh,test-lean-challenge-snapshot.sh,test-orchestrate-cycle-postflight.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh,test-validate-artifact.sh` is the exact set `suite_selection_select` returns for this phase's three touched paths; the check is advisory-only and adds no new exit path for any other consumer to observe.

**Scope Hypothesis**: three advisory sub-checks in one new block inside the existing per-phase loop, no new exit path. Confirm by grepping the diff for `log_error` (expect zero additions) and for new `exit` statements (expect zero).

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-artifact.sh` - add the three advisory authoring-shape warnings inside the existing per-phase loop
- `agent-system/extensions/core/context/formats/plan-format.md` - add the paired Enforcement level subsection for the new check
- `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` - fixtures for each shape, the strict-mode promotion, and the clean-plan negative case

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` exits 0 with the new fixtures passing.
- A plan carrying all three shapes validates to `[PASS] ... (3+ warning(s))` and exit 0 in default mode, and non-zero under `--strict`.
- A correctly-authored plan emits none of the three new warnings (no-noise negative case).
- `git diff` shows no `log_error` addition and no new exit path.

---

### Phase 3: Refuse a deployed-tree path at the deposit site and at the containment site [COMPLETED]

**Goal**: Close the two remaining leak paths by which a deployed-tree entry reaches or is honored
by `file_scope` -- the mid-dispatch deposit, and a `file_scope_arr` assembled from an already-
polluted `state.json` -- without weakening the drop-and-warn guard or the fail-open posture.

**Tasks**:

- [x] Re-derive the current line numbers for `propose_file_scope_addition()` (around line 212),
      the `file_scope_arr` assembly (around line 300), and `is_contained()` (around line 346) in
      `agent-system/extensions/core/scripts/git-commit-phase.sh`. *(completed)*
- [x] In `propose_file_scope_addition()`, refuse to deposit a path equal to `.claude`/`.claude/`
      or prefixed `.claude/`: return early with a `warn` naming the path and the governing rule.
      This keeps the deposit channel from re-seeding `state.json` through implement postflight's
      `--file-scope-add`. The `warn()` and `issue-record.sh` calls at the drop call site are
      untouched and still fire unconditionally on every drop. *(completed)*
- [x] Immediately after `file_scope_arr` is populated from the `state.json` JSON and before the
      own-task-directory and engine-written-state splices, strip every entry equal to
      `.claude`/`.claude/` or prefixed `.claude/`, emitting one `warn` per stripped entry.
      *(completed)*
- [x] Re-test non-emptiness after the strip: if nothing survives, fall through to the existing
      fail-open path (skip the whole Containment check) rather than running it against an empty
      array. Do not relocate either splice; both must stay inside the non-empty guard where they
      are today. *(completed: the strip reassigns file_scope_arr in place, and the pre-existing
      `if [ "${#file_scope_arr[@]}" -gt 0 ]` guard immediately below re-tests the stripped result;
      neither splice moved)*
- [x] Extend the header comment's Phase-Commit Containment Self-Check section to state the strip,
      its placement relative to the two splices, and the fail-open consequence when nothing
      survives. *(completed: new "DEPLOYED-TREE REFUSAL" header subsection)*
- [x] Extend `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` with fixtures
      appended after Case 24: a `.claude/**` `files_touched` path under a `file_scope` seeded with
      a bare `.claude/` entry is STILL dropped, warned, and issue-recorded (the loophole closed);
      a `file_scope` consisting solely of `.claude/` strips to empty and fails open exactly as a
      missing `file_scope` does; a `.claude/**` drop does NOT appear in `.return-meta.json`'s
      `proposed_file_scope` (deposit refused) while a non-deployed excursion in the same run still
      IS deposited; a genuine out-of-territory source path is still dropped with its warning AND
      its `issue-record.sh --class "scope excursion"` call; the fixed-scope carve-out paths are
      still staged unconditionally; and fail-open on absent/empty/malformed `file_scope` is
      unchanged. *(completed: Case 25 covers the loophole-closure/deposit-refusal/sibling-excursion
      properties; Case 26 pins this script's OWN fail-open at the strip-to-empty shape. Cases 1-24
      re-run unchanged, 56/56 total. Deviation: Case 26 narrows to Site 2's own behavior only --
      see Deviations below and this phase's progress-file verification_notes for the Site-3
      residual this uncovered)*
- [x] Re-read `git-commit-phase.sh` and `test-git-commit-phase.sh` immediately before editing
      (tasks 430 and 443 share this territory) and stage only this phase's own hunks.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-skill-base-lifecycle.sh,test-task-reference-patterns-lib.sh,test-update-task-status.sh` is the exact set `suite_selection_select` returns for this phase's two touched paths, and `test-git-commit-phase.sh` drives the real script in a scratch git repo rather than mocking the predicate.

**Scope Hypothesis**: two refusal sites in one script and roughly six new fixture cases. Confirm by grepping the diff for the refusal predicate (expect exactly two occurrences, one per site) and by counting the appended `=== Case` labels.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - refuse a deployed-tree deposit in `propose_file_scope_addition()`; strip deployed-tree entries from `file_scope_arr` before the splices with a post-strip non-emptiness re-test; extend the header
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - append the loophole-closure, strip-to-empty fail-open, deposit-refusal, surviving-guard, carve-out, and fail-open fixtures

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` exits 0 with every pre-existing case (1-24) still passing.
- A `file_scope` containing a bare `.claude/` entry no longer admits any `.claude/**` path: the path is dropped, warned, and issue-recorded.
- A `file_scope` of only `.claude/` behaves byte-for-byte like a missing `file_scope` (fail open, nothing dropped, nothing deposited).
- A genuine out-of-territory source path's drop warning, issue row, and `proposed_file_scope` deposit are all unchanged from the pre-change behavior.

---

### Phase 4: Honor this task's own mid-dispatch deposits at the next phase's commit [COMPLETED]

**Goal**: Close PART B's within-dispatch window -- a path dropped in one phase must not be dropped
again by the next phase's own commit in the same dispatch -- without touching `state.json` early
and without introducing a second state writer.

**Tasks**:

- [x] Re-derive the `file_scope_arr` assembly line numbers after Phase 3's edit. *(completed)*
- [x] Read this task's own `.return-meta.json` `proposed_file_scope` array, resolving the path
      exactly as `propose_file_scope_addition()` already resolves it (`${task_dir}/.return-meta.json`),
      with the same skip-if-absent, skip-if-malformed posture; never a cross-task read.
      *(completed: `proposed_file_scope_lookup`)*
- [x] Union those entries into `file_scope_arr` at the point Phase 3's strip runs, ordered so the
      strip executes AFTER the union over the single assembled array -- a deposited deployed-tree
      path must not survive into the Containment check. *(deviation: altered -- NOT unioned into
      `file_scope_arr`/`is_contained()`. A literal admitting union was built and rejected:
      `git-commit-scoped.sh` carries its own, separate, un-patched Site-3 V10 containment guard
      that re-reads the unwidened `file_scope` from `state.json` with no override once `--task`
      is passed, so admitting a path at Site 2 either silently fails to land it (Site 3 vetoes it
      anyway) or regresses the pre-existing Case 20 idempotence fixture via a hard completeness
      failure. Implemented instead: a read-only lookup that only ANNOTATES a recurring drop's
      warning text, with the drop/warn/issue-record/deposit cadence otherwise completely
      unchanged from Phase 3. See the Phase 4 progress file's `approaches_tried` for both
      rejected designs and the full reasoning, and git-commit-phase.sh's own "WITHIN-DISPATCH
      proposed_file_scope LOOKUP (PART B)" header subsection.)*
- [x] Confirm no `state.json` write is introduced: the union is read-only and in-memory, and
      `state.json` continues to be widened once, at the terminal postflight, through
      `update-task-status.sh --file-scope-add`'s existing mutex-guarded path. *(completed: the
      lookup introduces no state.json write of any kind, read-only in both designs considered)*
- [x] Confirm fail-open is unchanged: an absent, unreadable, or malformed `.return-meta.json`
      contributes nothing and never alters the commit's exit code; a task with no declared
      `file_scope` at all still skips the whole check (the union must sit inside the existing
      non-empty guard, never widen a task into a check it never entered). *(completed: the lookup
      sits inside the SAME outer non-empty guard as the deployed-tree strip, so it is structurally
      unreachable whenever file_scope is absent/empty/malformed)*
- [x] Extend the header comment's Containment Self-Check section to state the union, its
      task-scoped read, its ordering relative to the strip, and that `state.json` is still
      written only at postflight. *(completed: new "WITHIN-DISPATCH proposed_file_scope LOOKUP
      (PART B)" header subsection documents the lookup, both rejected designs, and the Site-3
      residual)*
- [x] Add fixtures to `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`: a
      path deposited into `proposed_file_scope` by a simulated earlier phase is NOT dropped on a
      subsequent phase's commit in the same repo fixture; a genuine out-of-territory path absent
      from the deposit is still dropped, warned, and issue-recorded; a deposited `.claude/**`
      entry (planted directly in `.return-meta.json`, bypassing Phase 3's deposit refusal) is
      still stripped and still does not admit a deployed-tree path; a malformed
      `.return-meta.json` contributes nothing and does not fail the commit; and a task with no
      declared `file_scope` plus a non-empty deposit still fails open. *(completed with the
      annotation-not-admission scope, matching the deviation above: Case 27a/27b pin the
      annotated-vs-plain warning text, the unchanged issue-record.sh cadence, idempotent deposit
      count, and rc=0; Case 28 pins a planted `.claude/**` proposed_file_scope entry drawing no
      already-known annotation. Malformed/absent `.return-meta.json` and no-declared-scope
      fail-open were already pinned by Phase 3's Cases 22/23 and remain unchanged -- re-run
      green, not re-duplicated.)*
- [x] Re-read both files immediately before editing and stage only this phase's own hunks.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-git-commit-phase.sh,test-git-commit-scoped.sh,test-skill-base-lifecycle.sh,test-task-reference-patterns-lib.sh,test-update-task-status.sh` is the exact set `suite_selection_select` returns for this phase's two touched paths, and `test-skill-base-lifecycle.sh` within it covers the implement-postflight consumer of the same field.

**Scope Hypothesis**: one union site in one script and roughly five new fixture cases, with no new `state.json` writer. Confirm by grepping the diff for `state-write.sh`, `update-task-status.sh`, and any `specs/state.json` write (expect zero additions) and by counting the appended `=== Case` labels.

**Files to modify**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` - union this task's own `proposed_file_scope` into `file_scope_arr` ahead of the strip; extend the header
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - append the within-dispatch honoring, surviving-guard, planted-deployed-entry, malformed-metadata, and no-declared-scope fail-open fixtures

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` exits 0 with every pre-existing case still passing.
- A path dropped in a simulated Phase 2 commit is staged by the simulated Phase 3 commit without a second drop warning.
- A genuine out-of-territory path, a planted deployed-tree deposit, a malformed `.return-meta.json`, and an absent `file_scope` each behave exactly as before.
- `git diff` introduces no `state.json` write and no second state writer.

---

### Phase 5: Make the drop non-advisory in the implementer's own protocol [COMPLETED]

**Goal**: Replace "verify the phase-closing commit's WARNING output names every expected file"
with a mechanical trigger an implementing agent cannot miss, and bring the durable containment
documentation into line with Phases 3 and 4.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md` around the
      Phase-Commit Containment Self-Check (around line 402) and the Phase Checkpoint Protocol's
      rc-code case statement (around line 946). *(completed)*
- [x] At the Phase Checkpoint Protocol's commit step, add a step following the `case "$rc"` block:
      after `git-commit-phase.sh` returns, compare this task's `.return-meta.json`
      `proposed_file_scope` array against its value before the call; a newly-appeared entry means
      a path was dropped from the commit just made, and the agent immediately issues a scoped
      follow-up commit of that specific path -- never a widened pathspec, never a directory or
      glob `git add`. Phrase the trigger as a comparison of two observed values, not as a
      reminder to read stdout. *(completed)*
- [x] State in the same place that the trigger is mechanical and additive: the warning and the
      issue row still fire, and the follow-up commit is what closes the loop the warning only
      reports. *(completed)*
- [x] Mirror the same trigger at the per-objective green-substep site (around line 447), since
      both sites invoke the same wrapper and both can drop. *(completed)*
- [x] Update the Self-Check's step-3/step-4 prose to record Phase 3's strip and Phase 4's union:
      the predicate's input is this task's declared `file_scope` unioned with its own
      currently-deposited `proposed_file_scope`, with every deployed-tree entry stripped first.
      *(deviation: altered -- documents what Phase 4 actually shipped (a read-only, exact-string
      `proposed_file_scope_lookup` used only to annotate a repeat drop's warning, never unioned
      into the predicate) rather than the union this bullet describes; see Phase 4's own recorded
      deviation and `approaches_tried` for why the union was rejected)*
- [x] Update `agent-system/extensions/core/context/standards/git-staging-scope.md`'s
      "Three Containment sites, not one" section (around line 342) and its site-2 paragraph
      (around line 350) with the same two facts, so the durable standard and the agent prose do
      not diverge. *(completed: new "A third asymmetry, deliberately left open" paragraph pair,
      consistent with the deviation above and with Phase 3's own recorded Site-3 residual)*
- [x] Re-read both files immediately before editing (task 430 owns both;
      `general-implementation-agent.md` especially) and stage only this phase's own hunks.
      *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `bash scripts/tests/run-all.sh --only test-lint-agent-contracts.sh,test-lint-agent-contracts-heartbeat.sh,test-orchestrate-cycle-postflight.sh,test-todo-move-pair-staging.sh` is the exact set `suite_selection_select` returns for this phase's two touched paths, and the agent-contract lint is what mechanically checks this file's structural obligations.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add the follow-up-commit trigger at both commit sites and update the Self-Check's predicate-input prose
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - record the strip and the union at the site-2 paragraph and in the three-sites section

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-lint-agent-contracts.sh` and
  `bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` both exit 0.
- Both commit sites in the agent file carry the trigger, stated as a before/after comparison of
  `proposed_file_scope` rather than as an instruction to read stdout.
- The Self-Check prose, the `git-staging-scope.md` site-2 paragraph, and
  `git-commit-phase.sh`'s header all describe the same predicate input in the same terms.
- No task-number reference and no record-versioning language is introduced in either file
  (`bash agent-system/extensions/core/scripts/check-task-references.sh`).

---

### Phase 6: End-to-end reconciliation proof, redeploy, and full gate [COMPLETED]

**Goal**: Prove the merged `file_scope` equals the plan's authoritative list with the refusal
active -- not merely that the harvest exits 0 -- then redeploy the source store and run the
complete gate set.

**Tasks**:

- [x] Extend `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`'s Group 4a
      (the live plan-postflight harvest group, around line 535) with a fixture plan whose
      `Files to modify` blocks carry a mix of real source paths, one `.claude/**` path, and one
      `` `__WHOLE_TREE__` `` sentinel entry; assert the resulting `active_projects[].file_scope`
      equals exactly the real paths plus the sentinel, with the deployed-tree path absent.
      *(completed)*
- [x] Assert in the same group that the harvest's refusal warning reached stderr and that the
      postflight exited 0 -- a refusal is never an error. *(deviation: altered -- skill-base.sh's
      plan-branch call site redirects the harvester's stderr to /dev/null by design (unedited by
      this task), so the refusal warning is asserted directly against the harvester for this same
      fixture plan instead of through skill_postflight_update; the exit-0 half is asserted through
      the live call site as planned. See Phase 6 progress file's `deviations`.)*
- [x] Confirm the existing Group 4a positive case and the no-`plans/`-directory degenerate case
      (`file_scope` stays null, never a bogus `[]`) both still pass unchanged. *(completed:
      72/72 total passing)*
- [x] Redeploy the source store: `timeout 540 bash .claude/scripts/deploy-headless.sh` (Bash tool
      `timeout` parameter raised to 600000 per `context/patterns/external-process-wait.md` Rule 1),
      then confirm the deployed copies of all six edited files match their source-store
      counterparts (ten files: the six non-test files plus the four test suites). *(completed:
      all ten files byte-identical after redeploy; verify-deploy reported 3 pre-existing,
      unrelated failures -- see Phase 6 progress file's `verification_notes`)*
- [x] Run the complete gate set unnarrowed: `bash .claude/scripts/tests/run-all.sh`, the
      repo-wide task-reference and record-version lints, and `bash .claude/scripts/validate-state.sh`.
      *(deviation: altered -- per this dispatch's Batch Gate Deferral directive, `run-all.sh` ran
      SCOPED to `suite_selection_select`'s output for this phase's touched path (10 suites, 9/10
      pass; the one failure is a pre-existing, unrelated defect) rather than unnarrowed, with the
      complete unnarrowed run deferred to the batch-level stage. The repo-wide task-reference lint
      and `validate-state.sh` DID run unnarrowed and are clean for this task; the repo-wide
      record-version lint also ran unnarrowed and found 3 pre-existing BLOCKING hits, all in
      unrelated Himalaya plugin docs never touched by this task.)*
- [x] Re-run `bash .claude/scripts/validate-artifact.sh` against this plan file itself and confirm
      the Phase 2 advisory checks emit no warning against it (the plan must satisfy the authoring
      discipline it introduces). *(completed: zero Phase-2-authoring-shape warnings; 3 unrelated
      pre-existing Tier-Justification-measurement warnings remain)*
- [x] Re-measure the live `specs/state.json` for `.claude/**` `file_scope` residue and record the
      count in the summary, noting that the containment-site strip neutralizes it without mutating
      any other task's declaration. *(completed: 4 entries across 2 tasks (483, 512), unchanged
      from the plan's own research-time measurement)*

**Timing**: 1.5 hours

**Depends on**: 2, 5

**Verification Tier**: full

**Scope Hypothesis**: one new fixture group extension plus a whole-tree redeploy; ten source-store files edited across the whole task (six non-test files plus four test suites), matching this plan's own harvested `file_scope` minus the `` `__WHOLE_TREE__` `` sentinel. Confirm by comparing `bash .claude/scripts/plan-file-scope-harvest.sh` on this plan file against `git diff --stat` across the task's phase commits.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - extend Group 4a with the mixed-entry end-to-end reconciliation fixture
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0, with the new Group 4a case asserting the merged `file_scope` equals the plan's real paths plus the sentinel and excludes the deployed-tree path.
- `bash .claude/scripts/tests/run-all.sh` exits 0 across the whole suite.
- `bash .claude/scripts/check-task-references.sh` and the record-version lint both exit 0 for every file landing under `agent-system/**`.
- `bash .claude/scripts/validate-state.sh` exits 0 (including Check 8's coarse-declaration lint).
- `bash .claude/scripts/validate-artifact.sh` on this plan file emits none of the Phase 2 advisory warnings.
- Each of the ten edited source-store files matches its deployed counterpart after the redeploy.

---

## Testing & Validation

- [ ] `test-plan-file-scope-harvest.sh`: the #417 grammar pin asserts unchanged first-path-only
      extraction; the deployed-tree refusal drops the entry with a stderr warning while keeping
      exit 0 and the `[]` contract; the `` `__WHOLE_TREE__` `` sentinel still passes through
      verbatim.
- [ ] `test-validate-artifact.sh`: each of the three advisory shapes warns in default mode with
      exit 0, promotes under `--strict`, and a correctly-authored plan emits none of them.
- [ ] `test-git-commit-phase.sh`: a genuine out-of-territory path is still dropped with its
      warning and its `issue-record.sh --class "scope excursion"` call; the fixed-scope carve-outs
      are still staged unconditionally; fail-open on absent/empty/malformed `file_scope` is
      unchanged; a deployed-tree path is still dropped even under a `.claude/`-seeded
      `file_scope`; a deployed-tree drop is not deposited; and a prior phase's deposit prevents a
      repeat drop at the next phase's commit.
- [ ] `test-skill-base-lifecycle.sh`: the plan postflight merges a mixed-entry fixture plan into a
      `file_scope` equal to the real paths plus the sentinel, with the deployed-tree path absent
      and the postflight exiting 0.
- [ ] `run-all.sh` (unnarrowed), the task-reference and record-version lints, and
      `validate-state.sh` all exit 0 after the redeploy.

## Artifacts & Outputs

- Updated `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` with the deployed-tree
  refusal and its header subsection.
- Updated `agent-system/extensions/core/scripts/git-commit-phase.sh` with the deposit-site refusal,
  the containment-site strip, and the within-dispatch `proposed_file_scope` union.
- Updated `agent-system/extensions/core/scripts/validate-artifact.sh` with three advisory
  authoring-shape checks.
- Updated `agent-system/extensions/core/context/formats/plan-format.md` (field definition,
  anti-pattern, sentinel cross-reference, new Enforcement level subsection),
  `agent-system/extensions/core/context/standards/git-staging-scope.md`, and
  `agent-system/extensions/core/agents/general-implementation-agent.md`.
- Extended fixtures in `test-plan-file-scope-harvest.sh`, `test-validate-artifact.sh`,
  `test-git-commit-phase.sh`, and `test-skill-base-lifecycle.sh`.
- A redeployed `.claude/` tree, and an execution summary recording the per-citation verdicts
  carried from research and the remaining live `.claude/**` `file_scope` residue count.

## Rollback/Contingency

Every phase is a scoped, independently revertible commit over source-store files only; the
deployed tree is regenerated and never hand-patched. To revert a single phase, `git revert` its
commit and redeploy. Before any phase whose edit is riskier than planned, take a non-reverting
checkpoint with `bash .claude/scripts/git-snapshot.sh 446 --no-revert` (never the default,
reverting form -- a sibling task is live on this same working tree this cycle).

Per-phase contingencies: if Phase 3's containment-site strip proves to interact badly with the
existing splices, revert Phase 3 alone -- Phase 1's harvester refusal stands on its own and
already prevents new residue. If Phase 4's union is found to admit anything a genuine excursion
should not, revert Phase 4 alone; Phase 3's refusals and the unmodified drop-and-warn guard remain
intact, and PART B degrades to task 430's already-shipped terminal-postflight merge. If Phase 2's
advisory checks prove too noisy against the live plan corpus, the warnings can be narrowed or the
check removed without touching any other phase, since nothing consumes their output
programmatically.
