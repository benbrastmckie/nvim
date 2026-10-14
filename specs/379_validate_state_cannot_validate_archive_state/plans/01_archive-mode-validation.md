# Implementation Plan: Task #379

- **Task**: 379 - Make specs/archive/state.json validatable by validate-state.sh
- **Status**: [IMPLEMENTING]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/379_validate_state_cannot_validate_archive_state/reports/01_archive-state-validation-gate.md
- **Artifacts**: plans/01_archive-mode-validation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`validate-state.sh` has no code path for `specs/archive/state.json`'s shape: Check 2 correctly
FAILs on the two missing required top-level fields, but Checks 5/6/7 **falsely PASS** because
their `jq` pipelines over `.active_projects[]` error out, emit zero lines, and leave their
bad-entry counters at the initialized zero — which the script reads as "verified clean" rather
than "could not check." This plan closes both halves of the defect: it stops base mode from
silently false-PASSing an `active_projects`-less file, and it adds an explicit `--archive` mode
with its own parallel, deliberately looser check set over `archived_projects` /
`completed_projects`. Definition of done: the `/task --abandon` archive-insert shape validates
cleanly under `--archive`, this repository's own live archive file produces no new FAIL, and
`tests/test-validate-state.sh` covers both the archive shape and the base-mode false-PASS
regression.

### Research Integration

Key findings carried into the phases below:

- **The false PASS is the real defect** (report, Executive Summary + Decisions): a fix that only
  addresses Check 2's two correct FAILs while leaving Checks 5/6/7 free to silently false-PASS
  does not satisfy the dispatch's requirement 2. Phase 2 exists solely for this.
- **Explicit flag over auto-detection** (report, Recommendation 1): shape-based auto-detection
  would let a genuinely corrupted *live* `specs/state.json` that lost its `active_projects` key
  be silently re-routed into the looser archive checks. An explicit flag matches this script's
  own `--deep`/`--fix`/`--strict` idiom and has no backward-compatibility cost — no caller passes
  an archive path today.
- **Advisory-first is mandatory, not stylistic** (report, Findings: measured counts): the live
  archive carries 24 `project_number` values present in *both* arrays and an `orphan_archived`
  status outside the closed 13-value enum. A FAIL-level duplicate or status check regresses
  against this repository's own data on day one.
- **Three distinct archive-insert shapes exist** (report, Findings): `/task --abandon` writes into
  `completed_projects` with `status: "abandoned"` and an `abandoned` timestamp key;
  `skill-todo` writes two other shapes (`archived_projects` + `archived_at`, and
  `completed_projects` + `archived_at`). The literal `--abandon` shape must be its own fixture.
- **`abandoned_projects` is dead vocabulary** (report, Findings): no writer repo-wide; present,
  absent, or empty must all be non-findings.
- **Per-array field sets differ** (report, Findings): `archived_projects[]` and
  `completed_projects[]` have different real field sets; they must not be merged into one
  allowlist.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation
performed.

## Goals & Non-Goals

**Goals**:

- Base mode never again reports PASS for a check it could not actually run against an
  `active_projects`-less file; it says, by name, that it could not validate and points at
  `--archive`.
- An explicit `--archive` mode validates `specs/archive/state.json`'s real shape
  (`archived_projects` / `completed_projects`), including the literal `/task --abandon` insert.
- Every new archive-scoped check that could collide with this repository's existing historical
  data is WARN-level with a stated PROMOTION CRITERION, in this script's established
  advisory-first idiom.
- `tests/test-validate-state.sh` covers the archive shape, the `--abandon` shape, a genuine
  archive defect, the cross-array duplicate WARN, and the base-mode false-PASS regression guard.

**Non-Goals**:

- Wiring a new caller (e.g. `/task --abandon` or `skill-todo` invoking
  `validate-state.sh --archive` against the write it just made). Outside the declared
  `file_scope`; the dispatch requires the gate be *capable*, not that writers invoke it.
- Refreshing `context/schemas/state-schema.json`'s stale header comment (it names
  `researching_2` / `plan_metadata`, neither of which is in the live archive). Outside
  `file_scope`; flagged by research for a follow-up.
- Editing `context/patterns/task-abandon-mode.md` — read-only here, and concurrently claimed by
  a sibling task's `file_scope` this cycle.
- Retrofitting the archive into `state-schema.json`'s `active_projects`-shaped schema or into
  Checks 3/4's `KNOWN_*_FIELDS` allowlists. The schema's own header already records this as a
  deliberate scope boundary.
- Promoting any archive-scoped WARN to FAIL in this task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new archive check FAILs against this repo's live archive (24 cross-array duplicates, `orphan_archived` status) | H | H | Every collision-prone check is WARN-level with a PROMOTION CRITERION comment; Phase 3 measures the live file *before* fixing each check's enforcement level (see its Scope Hypothesis) |
| Phase 2's base-mode guard changes output for existing callers (`verify-deploy.sh` gate 10, `test-init-specs.sh`) | M | L | Guard fires only when `.active_projects` is absent or not an array — a condition no live `specs/state.json` meets; Phase 2's verification runs both dependent suites |
| Archive-mode checks accidentally fall through to the existing `.active_projects[]` jq pipelines, recreating the false PASS | H | M | Archive mode routes around Checks 2-11 entirely (Phase 1) rather than relaxing them; Phase 5's fixture (d) pins the behavior |
| `--archive` combined with `--fix` or `--deep` does something silently meaningless | M | M | Phase 1 fixes an explicit posture per combination: `--fix` refuses loudly (exit 2), `--deep` emits a named notice and continues, `--strict` works normally |
| A sibling task edits `validate-state.sh` or the test suite concurrently (381/382/388 declare no `file_scope`) | M | L | Re-read both files immediately before each edit; stage only this task's own hunks with an explicit file list; never run `git-snapshot.sh` in its reverting default mode |
| Deployed `.claude/` tree is stale for `core` (per this dispatch's deploy-freshness context), so gate 10 and gate 8's deployed-tree coverage would test an old copy | M | H | Phase 6 redeploys with the bounded-wait idiom before running the full gate set |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: every phase
edits one of the two files in `file_scope`, so parallel waves would mean concurrent edits to the
same file.

---

### Phase 1: `--archive` flag, mode routing, and flag-combination posture [COMPLETED]

**Goal**: `--archive` exists, is documented, routes around every `active_projects`-keyed check
instead of relaxing it, and has an explicit stated behavior for each combination with `--deep`,
`--fix`, and `--strict`. At the end of this phase `--archive` runs Check 1 (JSON parsability,
shared) plus Check A1 (top-level archive shape) and exits through the existing shared summary.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/validate-state.sh` immediately before editing
      (sibling-concurrency precaution). *(completed)*
- [x] Add `ARCHIVE_MODE=false` alongside the existing `DEEP` / `FIX_MODE` / `STRICT_MODE`
      initializations, and an `--archive)` case to the existing `while [[ $# -gt 0 ]]` arg loop. *(completed)*
- [x] Extend the leading `#`-comment header: add `[--archive]` to the usage synopsis line, and a
      dedicated `--archive:` paragraph in the same shape as the existing `--deep` / `--fix` /
      `--strict` paragraphs, stating (a) opt-in only, never implicit; (b) *why* an explicit flag
      rather than shape auto-detection (a corrupted live `specs/state.json` that lost
      `active_projects` must keep FAILing Check 2, never be silently re-routed into the looser
      archive checks); (c) that it replaces Checks 2-11 with the archive check set rather than
      relaxing them. `--help` picks this up automatically via the existing `awk` dynamic-range
      extractor — no separate help text to update. *(completed)*
- [x] Fix the flag-combination posture explicitly, each with an inline comment stating the
      reason: `--archive --fix` refuses loudly (`exit 2`, since `--fix` repairs only active-mode
      Check 9 `file_scope` duplicates, which have no archive analogue); `--archive --deep` emits
      a named notice that no `--deep` checks exist in archive mode and continues (deep is purely
      additive, so a loud notice is honest and a refusal would be gratuitous);
      `--archive --strict` works unchanged (promotes archive WARNs to exit-blocking). *(completed)*
- [x] Make the `Mode:` banner line report archive mode (e.g. `Mode: --archive`). *(completed)*
- [x] Route the control flow: with `ARCHIVE_MODE=true`, Check 1 runs as today, then the archive
      check set runs, then Checks 2-11 and the `--deep` block are **skipped entirely** (never
      run with relaxed arguments) — this is what structurally prevents the
      "jq error -> zero lines -> false PASS" pattern from recurring in archive mode. *(completed)*
- [x] Add **Check A1** (identifier string `Check A1`, so the test suite can grep for it):
      at least one of `archived_projects` / `completed_projects` must be present, and each key
      that *is* present must be an array — FAIL otherwise. `abandoned_projects` absent, present,
      or empty is a non-finding in all three cases (confirmed dead vocabulary); add an inline
      comment saying so, so a future reader does not "helpfully" require it. No
      `next_project_number` requirement. *(completed)*
- [x] Leave the `PASSED`/`WARNINGS`/`FAILED` counters, `log_*` helpers, Summary block, and
      `--strict` exit arithmetic completely untouched — archive mode reuses them as-is. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Tier Justification**: The edit is confined to `validate-state.sh` with no externally visible
signature change (a new opt-in flag only), and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is the
suite `suite_selection_select` resolves for that path.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - add `ARCHIVE_MODE`, the `--archive`
  arg case, header/usage documentation, flag-combination posture, mode banner, check-routing
  branch, and Check A1

**Verification**:

- `bash agent-system/extensions/core/scripts/validate-state.sh --help` prints the new `--archive`
  paragraph (proves the dynamic-range extractor picked it up).
- `bash agent-system/extensions/core/scripts/validate-state.sh --archive specs/archive/state.json`
  runs, reports Check 1 PASS and Check A1 PASS, and emits **none** of the three
  `[PASS] All active_projects[]...` lines and none of the `jq: error ... Cannot iterate over null`
  lines observed in the research reproduction.
- `bash agent-system/extensions/core/scripts/validate-state.sh --archive --fix specs/archive/state.json`
  exits 2 with a named refusal.
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` (no `--archive`)
  is byte-identical to its pre-edit output — capture the pre-edit output first and diff.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is
  green.

---

### Phase 2: Close the base-mode false PASS [COMPLETED]

**Goal**: In base mode (no `--archive`), a file whose `.active_projects` is absent or not an
array makes Checks 4-11 report, by name, that they **could not be run** — never PASS — with a
remediation pointer to `--archive`. This is the half of the defect that exists independently of
whether anyone ever passes `--archive`.

**Tasks**:

- [x] Re-read `validate-state.sh` immediately before editing. *(completed)*
- [x] Add a single base-mode guard, evaluated once after Check 2: compute whether
      `.active_projects` is present *and* of type `array`. *(completed)*
- [x] When the guard trips, emit one `log_fail` naming the condition and the consequence
      explicitly — that Checks 4-11 were not run, that this is an inability to validate rather
      than a clean result, and that `--archive` is the right invocation if the target is
      `specs/archive/state.json` — then skip Checks 4-11 and the `--deep` block rather than
      letting their `jq` pipelines error into a false PASS. Check 2's own two existing FAILs are
      unchanged (they are already correct). *(completed)*
- [x] Add an inline comment recording *why* the guard is FAIL-level and not WARN: an inability to
      validate the live state file is a hard defect, and the only file that legitimately has this
      shape is the archive, which now has its own explicit mode. *(completed)*
- [x] Confirm the guard cannot trip for any legitimate live `specs/state.json` (the schema
      requires `active_projects`; every writer maintains it) — so no existing caller's behavior
      changes. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that exactly three base-mode checks (5, 6, 7) currently
false-PASS, and that Checks 4 and 8-11 either already degrade safely or need the same guard.
Confirm at implementation time by running the pre-edit validator against
`specs/archive/state.json` and classifying **every** emitted line as correct-FAIL,
correct-WARN, or false-PASS before deciding which checks the guard must cover — do not assume the
report's three-check count is exhaustive.

*(confirmed: Checks 4 and 8-11 ALSO false-PASS, silently via their own `2>/dev/null` -- the
guard covers Checks 4-11, matching the Phase 2 Goal text's own framing.)*

**Tier Justification**: Base-mode output is consumed by enumerated one-hop dependents, so
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh,test-init-specs.sh`
covers the changed module plus both suites that assert on base-mode behavior.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - add the base-mode
  unvalidatable-shape guard and its skip routing for Checks 4-11 and `--deep`

**Verification**:

- `bash agent-system/extensions/core/scripts/validate-state.sh specs/archive/state.json` (no
  `--archive`) emits the named "could not validate" FAIL and **zero** of the three
  `[PASS] All active_projects[]...` lines; exit code is still 1.
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` and
  `--deep specs/state.json` are byte-identical to pre-edit output (diff against a captured
  baseline).
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh,test-init-specs.sh`
  is green.

---

### Phase 3: Archive per-entry and advisory checks (A2-A6) [COMPLETED]

**Goal**: `--archive` mode carries a complete, parallel check set over the archive's real shape,
with each check's enforcement level chosen from a measurement of the live file rather than an
assumption.

**Tasks**:

- [x] Re-read `validate-state.sh` immediately before editing. *(completed)*
- [x] **Measure first** (before fixing any enforcement level): over the live
      `specs/archive/state.json`, count entries in each array with a non-numeric
      `project_number`, a missing/empty `project_name`, and a missing/empty `task_type`. Record
      the counts in the implementation summary. Any check whose live count is zero may be
      FAIL-level; any check with a nonzero live count must be WARN-level with a PROMOTION
      CRITERION. *(completed)*
- [x] Add **Check A2** — `project_number` is a number, per array, with the array name in the
      message. Enforcement level per the measurement above. *(completed)*
- [x] Add **Check A3** — `project_name` and `task_type` present and non-empty, per array.
      Enforcement level per the measurement above. *(completed)*
- [x] Add **Check A4** — status membership against a **widened, archive-scoped vocabulary**: the
      closed 13-value enum from `lib/status-vocabulary.sh` (sourced, never re-listed) plus the
      observed terminal/legacy archive values (`orphan_archived` at minimum — re-derive the full
      observed set from the live file rather than trusting this list). Any value outside even the
      widened set is **WARN**, not FAIL, so the live file does not regress while a genuinely new
      value still surfaces. Carry a PROMOTION CRITERION comment. *(completed)*
- [x] Add **Check A5** — unknown per-entry fields, with **two separate allowlists**, one per
      array (`archived_projects[]` and `completed_projects[]` have materially different real
      field sets; merging them would hide drift in both). WARN-only, with a PROMOTION CRITERION
      comment, and an inline note that the archive's field set has already drifted once and will
      drift again. *(completed)*
- [x] Add **Check A6** — cross-array duplicate `project_number` (the same number appearing in
      both `archived_projects` and `completed_projects`). **WARN-only, never FAIL**, with an
      inline comment recording the measured live count so a future reader can see the promotion
      bar is a real number and not an arbitrary one. Also report within-array duplicates. *(completed)*
- [x] Add an unknown-top-level-key check for archive mode (WARN-only), recognizing
      `archived_projects` / `completed_projects` / `abandoned_projects` and nothing else. *(completed)*
- [x] Give every A-check its own `log_pass` "nothing found" line on the clean path, matching the
      existing checks' idiom — so a check that found nothing is visibly distinguishable from a
      check that did not run. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts a six-check set (A2-A6 plus the top-level key check) and
asserts specific per-array field sets and a widened status vocabulary. Confirm all three at
implementation time by re-deriving the top-level keys, the per-array field sets, and the observed
status values directly from the live `specs/archive/state.json` with `jq` — the report's measured
values (48 / 328 entries, the two field lists, `orphan_archived`) are a dated measurement, not a
fact, and the file may have changed.

*(confirmed: 48 archived_projects / 328 completed_projects entries, the two field unions, and
`orphan_archived` as the sole off-enum status all re-measured identical to the research report's
values; 24 cross-array duplicates and 24 missing-task_type entries in completed_projects, both
confirmed to be the SAME 24 project_numbers.)*

**Tier Justification**: The edit stays inside `validate-state.sh` with no change to any
externally visible signature, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is the
suite that covers that path.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - add Checks A2-A6 and the
  archive-scoped unknown-top-level-key check

**Verification**:

- `bash agent-system/extensions/core/scripts/validate-state.sh --archive specs/archive/state.json`
  produces **zero FAIL** against this repository's own live archive, and the expected WARNs
  (cross-array duplicates, `orphan_archived`-class statuses, any unknown fields) each named.
- `bash agent-system/extensions/core/scripts/validate-state.sh --archive --strict specs/archive/state.json`
  exits 1 and reports the WARN promotion (proves `--strict` composes).
- `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` still
  byte-identical to the captured baseline.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is
  green.

---

### Phase 4: Extend the test suite for the archive shape [COMPLETED]

**Goal**: `tests/test-validate-state.sh` proves the gate now validates the archive — including the
literal `/task --abandon` write — and pins the base-mode behavior against a regression to the
false PASS.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-validate-state.sh` immediately
      before editing. *(completed)*
- [x] Add an `ARCHIVE_VALIDATOR` resolution block following the file's existing
      source-store-first precedent (`D5_VALIDATOR`, `FS_VALIDATOR`): candidates in
      source-store-then-deployed order, each trusted only after `grep -q "Check A1"` succeeds, so
      a stale deployed copy cannot produce a false green. Skip the archive cases with an `info`
      line when no candidate qualifies, matching the existing blocks' behavior. *(completed)* *(deviation: altered — greps "Check A6" (the last archive check added) instead of "Check A1", since "Check A1" alone would also substring-match the archive-mode top-level-key check's own "Check A1b" label, making it a less specific anchor)*
- [x] Fixture (a) — positive archive shape: `archived_projects` + `completed_projects`, each with
      a few well-formed entries; asserts exit 0 under `--archive`. *(completed)*
- [x] Fixture (b) — the literal `/task --abandon` write shape: a `completed_projects` entry with
      `status: "abandoned"` and an `abandoned` timestamp key, **no** `archived_at`; asserts exit 0
      under `--archive`. Add a comment naming this as the write this task exists for. *(completed)*
- [x] Fixture (c) — archive defect: a non-numeric `project_number` (plus a status outside even
      the widened archive vocabulary); asserts nonzero exit and a **named** error line under
      `--archive`. If the Phase 3 measurement forced A2/A3 to WARN level, assert the nonzero exit
      under `--archive --strict` instead, and add a comment recording why. *(completed)*
- [x] Fixture (d) — base-mode regression guard: an archive-shaped file validated **without**
      `--archive` asserts (i) Check 2's two required-field FAILs are still reported, (ii) the
      Phase 2 "could not validate" FAIL is reported, and (iii) **none** of the three
      `All active_projects[]...` PASS lines appear. This is the assertion that catches a
      regression to the false-PASS pattern. *(completed)*
- [x] Fixture (e) — cross-array duplicate `project_number`: asserts exit **0** with a named WARN
      under `--archive` (confirming A6 does not regress against live data), and exit 1 under
      `--archive --strict`. *(completed)*
- [x] Fixture (f) — `abandoned_projects` tolerance: three variants (absent, present-and-empty,
      present-with-entries) each exit 0 under `--archive`, pinning the dead-vocabulary decision. *(completed)*
- [x] Fixture (g) — flag-combination posture: `--archive --fix` exits 2 with a named refusal;
      `--archive --deep` exits 0 with the named "no --deep checks in archive mode" notice. *(completed)*
- [x] Reuse the file's existing `pass()` / `fail()` / `info()` helpers, `PASSED`/`FAILED`
      counters, and `WORKDIR` fixture-directory convention; add no new harness machinery. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Seven fixture groups (a)-(g) are asserted here. Confirm at implementation
time that each one actually fails against the pre-Phase-1 validator — temporarily point
`ARCHIVE_VALIDATOR` at a `git stash`-free copy of the original script, or assert the expectation
by hand once — so no fixture is vacuously green.

**Tier Justification**: The edit is confined to the test suite itself, and running that suite
(`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh`) is
both the change and its own complete covering check.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - add the
  `ARCHIVE_VALIDATOR` resolution block and fixtures (a)-(g)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with every new
  case reported `[PASS]` and none reported as skipped-by-`info`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is
  green.
- The suite's pre-existing cases all still pass (compare the `[PASS]` count against a pre-edit
  baseline run).

---

### Phase 5: Validate against every real archive-insert shape [NOT STARTED]

**Goal**: Prove the three *real* archive-insert shapes that writers actually produce — not only
the synthetic fixtures — validate under `--archive`, which is the dispatch's requirement 1.

**Tasks**:

- [ ] Re-derive the three live insert shapes read-only from their writers:
      `context/patterns/task-abandon-mode.md` (the `--abandon` insert: `completed_projects`,
      `status: "abandoned"`, `abandoned` timestamp) and `skills/skill-todo/SKILL.md` (the two
      `skill-todo` inserts: `archived_projects` + `archived_at`, and `completed_projects` +
      `archived_at`). **Read only** — `task-abandon-mode.md` is a concurrent sibling's declared
      `file_scope` this cycle and must not be edited.
- [ ] For each of the three shapes, build a scratch fixture under the session scratchpad (not the
      versioned tree) that reproduces the insert against a minimal archive file, and confirm
      `--archive` reports exit 0 with no FAIL.
- [ ] Where a shape produces an unexpected WARN, decide and record explicitly whether the
      allowlist/vocabulary is wrong (fix it in `validate-state.sh`) or the WARN is correct and
      informative (leave it, note why in the summary). Do not silence a WARN by widening an
      allowlist without stating the reason inline.
- [ ] If any shape needed a `validate-state.sh` correction, mirror it as an additional fixture in
      `tests/test-validate-state.sh` so the real shape is pinned, not just the scratch check.
- [ ] Re-run `--archive` against the live `specs/archive/state.json` and confirm still zero FAIL.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts there are exactly three live archive-insert shapes.
Confirm at implementation time with
`grep -rn 'archived_projects\|completed_projects' agent-system/extensions --include=*.md --include=*.sh`
over the writer set, in case a fourth insert site exists that the research pass did not reach.

**Tier Justification**: Any correction landing here stays inside the same two `file_scope` files,
and `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is
the suite covering both.

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - corrections only, if a real insert
  shape exposes a wrong allowlist or vocabulary entry
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - an additional fixture per
  real shape that needed a correction

**Verification**:

- Each of the three real insert shapes exits 0 under `--archive` with no FAIL.
- `--archive specs/archive/state.json` still reports zero FAIL.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-validate-state.sh` is
  green.

---

### Phase 6: Redeploy and full gate set [NOT STARTED]

**Goal**: The deployed tree carries the change and the complete repository gate set passes.

**Tasks**:

- [ ] Confirm the working tree holds only this task's own changes to its two `file_scope` files
      (`git status --short`); if a foreign commit or foreign uncommitted modification is present,
      STOP and report it after checking `git log` to confirm the work is not this task's own.
- [ ] Redeploy so gate 10 and gate 8's deployed-tree coverage exercise the new code rather than
      the stale copy this dispatch's deploy-freshness context reports:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash tool `timeout`
      parameter raised to 600000 (not its 120000 default) per
      `context/patterns/external-process-wait.md` Rule 1. Do **not** hand-patch any file under
      `.claude/**` as a substitute.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. No `--skip-slow`, no
      `--only-gate` narrowing — this is the final phase and the full gate set is the tier.
- [ ] Confirm gate 10 (`validate-state.sh --deep specs/state.json`) passes and gate 8's shell
      suite battery passes, including `test-validate-state.sh` and `test-init-specs.sh`.
- [ ] Fix forward on any failure (never discard uncommitted changes to reach a passing gate, per
      `rules/error-handling.md`'s write-gating constraint).

**Timing**: 0.5 hours

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `agent-system/extensions/core/scripts/validate-state.sh` - fix-forward corrections only, if a
  gate fails
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - fix-forward corrections
  only, if a gate fails

**Verification**:

- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes and the deploy-freshness
  divergence for `core` is resolved.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set this script aggregates — passes
  with no FAIL-level finding. Nothing is deferred past this tier.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0, with
      every archive fixture (a)-(g) reported `[PASS]` and none skipped.
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh --archive specs/archive/state.json`
      exits 0 with zero FAIL against this repository's own live archive.
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh specs/archive/state.json` (base
      mode) reports the named "could not validate" FAIL and **none** of the three
      `All active_projects[]...` false PASSes.
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh specs/state.json` and
      `--deep specs/state.json` are byte-identical to their pre-change output.
- [ ] `bash agent-system/extensions/core/scripts/validate-state.sh --help` prints the `--archive`
      documentation.
- [ ] Each of the three real archive-insert shapes (`/task --abandon`, `skill-todo`'s two) exits 0
      under `--archive`.
- [ ] `bash .claude/scripts/verify-deploy.sh` passes in full after redeploy.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-state.sh` — `--archive` mode (Checks A1-A6 plus
  the archive-scoped unknown-top-level-key check), the base-mode unvalidatable-shape guard, and
  the extended header/usage documentation.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — `ARCHIVE_VALIDATOR`
  resolution block and fixtures (a)-(g), plus any real-shape fixtures added in Phase 5.
- `specs/379_validate_state_cannot_validate_archive_state/summaries/01_*-summary.md` —
  implementation summary, recording the Phase 3 live measurements and every enforcement-level
  decision they drove.
- Redeployed `.claude/` tree (a regenerated deploy artifact, not a hand-authored edit).

## Rollback/Contingency

Both files in `file_scope` are additive-only changes to a single script and its test suite, so
rollback is per-phase and cheap: each phase commits its own verified-green sub-steps, so reverting
one phase's commits leaves the earlier phases intact and green.

- **Phase 1-5 regression**: `git revert` the offending phase's commits. The `--archive` flag is
  opt-in and no caller passes it, so reverting archive-mode work cannot break any existing
  invocation.
- **Phase 2 regression (the only phase that changes existing base-mode output)**: this is the one
  change an existing caller could notice. If `verify-deploy.sh` gate 10 or `test-init-specs.sh`
  turns red because of it, revert Phase 2's commits alone and re-open the false-PASS question
  separately — the archive-mode work in Phases 1 and 3-5 stands independently and still satisfies
  the dispatch's requirement 1.
- **If a rollback must discard uncommitted work**: take a durable checkpoint first with
  `bash .claude/scripts/git-snapshot.sh --no-revert`, then follow
  `context/contracts/recovery.md`'s rollback rung for the reverting invocation shape (including
  its out-of-scope override flag). Never the bare reverting default form as a precaution.
- **Deploy contingency**: the deployed `.claude/` tree is a disposable artifact — a bad deploy is
  recovered by re-running `deploy-headless.sh`, never by hand-patching under `.claude/**`.
