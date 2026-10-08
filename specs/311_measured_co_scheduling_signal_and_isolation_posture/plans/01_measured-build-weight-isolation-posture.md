# Implementation Plan: Task #311

- **Task**: 311 - Measured co-scheduling signal and isolation posture (two folded parts)
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/311_measured_co_scheduling_signal_and_isolation_posture/reports/01_co-scheduling-signal-isolation-posture.md`
- **Artifacts**: plans/01_measured-build-weight-isolation-posture.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Part 1 replaces the build-heavy co-scheduling admission rule's static `task_type` family
membership test with a measured signal read from each candidate task's own
`specs/{NNN}_{SLUG}/metrics.jsonl`, so a genuinely light build (a Mathlib-free `lean4` package
measured at 6 s wall / 17 jobs from an empty `.lake/`) stops being categorically refused
co-scheduling alongside a full Mathlib build. Part 2 appends two later-observed hazard classes
and the CoW/reflink/overlayfs/clone-nothing evaluation to
`batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section, with an
exact-filename cross-reference to the reaffirmation decision record, so any future re-opening of
the worktree question starts from a complete evidence base. Every edit lands under
`agent-system/extensions/core/`, never `.claude/**`, per `source-store-deploy-boundary.md`.
Definition of done: the measured predicate admits a measured-light candidate for co-scheduling,
conservatively defers every unmeasured one (today's behavior, byte-for-byte), carries test
coverage for both directions, and the posture record is complete.

### Research Integration

Findings from `reports/01_co-scheduling-signal-isolation-posture.md` carried into this plan:

- **The signal already exists and needs no new instrumentation.** `dispatch-metrics.sh` already
  writes `wall_clock_seconds` for every `phase: "implement"` dispatch to
  `specs/{NNN}_{SLUG}/metrics.jsonl`, append-only, never gitignored, keyed by exactly the task
  directory the call site already resolves.
- **The call site already resolves the task directory 23 lines above the check.**
  `orchestrate-cycle-plan.sh`'s bucketing loop assigns `_p5_task_dir_abs` via
  `task_lookup_dir "$t" "${project_names[$t]}" "$PROJECT_ROOT"` for the
  forced-implement-needs-a-plan gate, immediately above the build-heavy check. Reading
  `${task_dir}/metrics.jsonl` reuses a proven-correct idiom in this exact function.
- **Job count is a closed door; do not re-open it.** `lake-build-guard.sh` records the explicit
  decision that job count "is a property of `lake`'s own output text, not of anything this guard
  records, and parsing it would couple the guard to a format it deliberately passes through
  untouched," and separately that "Lake 5.0.0 exposes no `-j`/`--jobs` flag."
- **The failure mode is confirmed, not hypothetical**, from the archived live evidence: a
  Mathlib-free `lean4` package built in 6 s / 17 jobs from an empty `.lake/` and was refused
  co-scheduling purely because its `task_type` string is `"lean4"`.
- **Historical duration is real, used admission practice** (a Launchpad buildd proposal refusing
  long builds from an already-maintained duration estimate; a patent maintaining a per-job running
  average between builds), but **a cache that changes between runs makes historical duration an
  inaccurate predictor** (a Ninja-project discussion, `ccache` as its example) — directly
  analogous to Lake's oelean cache and `.lake/` state. This caveat is why this plan uses `max`
  rather than `mean` and requires a minimum sample count before issuing a *light* verdict
  (Decision 3 below).
- **Part 2's content is already fully written** in the archived task-301 research report ("Live
  Evidence") and `specs/decisions/worktree-isolation-removal-reaffirmation.md` ("The Gate
  Question, Answered"), and the target section's existing retained-history subsections already
  have exactly the shape the append needs. Part 2 is transcription, not new analysis.
- **`territory.md` needs no edit.** Its "Working-tree and build isolation" subsection states the
  rule in principle without naming `BUILD_HEAVY_TASK_TYPES` or the family-list mechanism, so it
  remains accurate prose under any backing signal. The dispatch description's note that
  territory.md "also carries build-heavy references" is accurate as a reason this is one task,
  not as a required edit.

**Two corrections to the research report, found by direct verification at plan-authoring time:**

1. **Test coverage DOES exist.** The report concluded "No test coverage exists for the current
   predicate or array" from a symbol-name grep over `scripts/tests/`. Group 32 of
   `test-orchestrate-cycle-plan.sh` ("Mode 2 build-heavy co-scheduling admission") already covers
   the rule end-to-end in four cases — two build-heavy candidates defer one; build-heavy plus
   ordinary both dispatch; two build-heavy in different phases both dispatch; dry-run and live
   render byte-for-byte identical deferred reasons. The grep missed it because the suite drives
   the behavior through `state.json` fixtures rather than naming the predicate. Phase 4 therefore
   **extends** Group 32 rather than authoring coverage from scratch, and asserts the existing
   four cases keep passing unchanged.
2. **`lake-build-guard.sh` does record a genuine per-build duration — and it is still unusable
   here.** `write_inflight_record`/`finalize_record` write `start_epoch` and `end_epoch` to
   `RESULT_PATH`, a real build duration and a strictly better weight signal than dispatch
   wall-clock. It is eliminated with evidence rather than left unexamined: `init_guard_paths` sets
   `RESULT_PATH="$root/.lake/build-guard.result"` — single-slot (overwritten every build, no
   history), inside the built project's gitignored `.lake/`, and for `lean4` tasks inside a
   *sibling repository* unreachable from this repo's admission path. This closes the one
   better-looking alternative so a future reader need not re-litigate it (Decision 2 below).

### Prior Plan Reference

No prior plan. This is artifact round 01 for this task.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and `roadmap_flag` is not
set; no ROADMAP.md consultation or roadmap phases apply.

## Goals & Non-Goals

**Goals**:

- Replace `task_type` family membership as the *verdict* for build-heavy co-scheduling with a
  measured signal derived from the candidate task's own recorded implement-dispatch durations.
- Design the no-measurement-history fallback **explicitly**, with a stated rationale, rather than
  leaving it an implicit default (the dispatch description's own explicit requirement).
- Make the admission decision's basis observable in the `deferred[]` reason string, so an operator
  can tell a measured defer from a conservative-fallback defer without re-running anything.
- Extend existing Group 32 test coverage to both directions of the new signal, including the
  regression-safety property that unmeasured candidates behave exactly as today.
- Complete the isolation posture record: two later-observed hazard classes, the
  CoW/reflink/overlayfs/clone-nothing evaluation, and an exact-filename cross-reference to the
  reaffirmation decision record.

**Non-Goals**:

- Do **not** restore per-dispatch `git worktree` isolation. That verdict was re-opened, re-argued
  and CONFIRMED; see `specs/decisions/worktree-isolation-removal-reaffirmation.md`.
- Do **not** attempt a Lake/Mathlib shared-cache feasibility spike. Named in the evidence base as
  a possible future spike, explicitly out of scope here.
- Do **not** pursue a job-count signal (Decision 2).
- Do **not** adopt the `file_scope`-based Mathlib-manifest probe (Decision 2).
- Do **not** build a PATH-shim wrapper for unguarded build-tool callers. Already weighed and
  deferred in the guardrails doc's own Mode 2 subsection.
- Do **not** edit `.claude/**` by hand, and do **not** edit `context/contracts/territory.md`.

## Decisions

These four decisions are the plan's load-bearing design choices. Each exists because the research
report deliberately left it to the plan phase, or because plan-time verification closed an option
the report left open.

**Decision 1 — the family list is retained, demoted from *verdict* to *candidacy pre-filter*.**
`wall_clock_seconds` measures whole-*dispatch* duration, not build duration: this task's own
research dispatch recorded 547 s with zero builds. A measured signal that consulted wall-clock
*alone*, with no family gate, would therefore classify a slow `markdown` or `meta` dispatch as
build-heavy — a task with no `.lake/` to contend over at all — which is strictly worse than
today's behavior, not better. The family list survives as the answer to "could this task contend
over a shared build directory at all?", and the measured signal answers "does it, in fact,
heavily?". The array is renamed `BUILD_HEAVY_CANDIDATE_TASK_TYPES` so its name states the demoted
role and cannot be misread as the verdict.

**Decision 2 — wall-clock dispatch duration is the signal, and it measures a *contention window*,
not build CPU.** This is the design's principal limitation, stated plainly rather than papered
over. The quantity the admission rule actually needs is the probability that two candidates' build
activity overlaps in time, and dispatch duration is a direct measure of each candidate's exposure
window: two 6-second dispatches barely overlap, two 40-minute dispatches almost certainly do. It
remains a *proxy* for build weight, not a measurement of it. The three better-looking
alternatives are each declined with evidence, so none needs re-litigating:

| Alternative | Why declined |
|-------------|--------------|
| Lake job count | No capture path exists anywhere; `lake-build-guard.sh` already declined parsing it to avoid coupling to Lake's output format, and Lake 5.0.0 exposes no `-j`/`--jobs` flag |
| `lake-build-guard.sh`'s `build-guard.result` `start_epoch`/`end_epoch` | A genuine build duration, but single-slot (overwritten per build, no history), under the built project's gitignored `.lake/`, and for `lean4` tasks inside a sibling repository unreachable from this repo's admission path |
| `file_scope` → Mathlib-manifest probe | `file_scope` is documented as descriptive and not filesystem-validated; no `lean4`/`cslib` task directory exists in this repository to test the resolution against; the research report flags it unverified |

**Decision 3 — the aggregator is `max` over prior implement dispatches, not the mean, and a
*light* verdict additionally requires a minimum sample count.** The research report suggested
averaging to soften a single data point; this plan deliberately departs from that, because
contention risk is one-sided. A task that has ever built heavily can build heavily again — a
toolchain bump or a dependency change invalidates a populated `.lake/` at any time — whereas a
task that has only ever built lightly may simply not have hit its heavy path yet. Averaging lets
one 6-second dispatch dilute a 40-minute one and flip a genuinely heavy task to light, which is
the wrong direction for a fail-safe gate. `max` never dilutes a heavy reading. The Ninja-project
cache caveat cuts specifically against treating a *low* reading as proof of lightness, which `max`
alone does not address, so a *light* verdict additionally requires at least
`BUILD_HEAVY_MIN_SAMPLES` (default 2) usable implement-phase measurements.

**Decision 4 — the no-history fallback is conservative default-to-heavy.** Required explicitly by
the dispatch description; chosen over the alternatives for four stated reasons:

1. It preserves today's behavior **byte-for-byte** for every unmeasured candidate, so this change
   is strictly a *relaxation applied only where evidence exists* — it introduces no new
   co-scheduling exposure anywhere.
2. It is the direction the guardrails doc's own "Defer-Not-Fail: The Standing Default" section
   already mandates.
3. It keeps the existing Group 32 assertions valid unchanged: those fixtures create no task
   directories, hence no `metrics.jsonl`, hence the fallback fires and today's verdicts hold. That
   is an asserted regression-safety property in Phase 4, not a hope.
4. The one alternative with real upside — the `file_scope` Mathlib probe — is declined on evidence
   under Decision 2.

The fallback covers five distinct no-usable-measurement conditions, all collapsing to *heavy*: no
task directory resolved; no `metrics.jsonl`; no `phase: "implement"` entries; every implement entry
missing `wall_clock_seconds` (the format's omission-not-zeroing rule, which this read MUST respect
— an absent key is never read as `0`); and fewer than `BUILD_HEAVY_MIN_SAMPLES` usable entries.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wall-clock dispatch duration misreads a long-thinking, light-building dispatch as heavy | L | H | Accepted and named (Decision 2). A false *heavy* is today's behavior — safe, merely unhelpful. Only a false *light* is a new hazard, and `max` + min-sample-count guard that direction |
| A false *light* admits two genuinely heavy builds into one cycle | H | L | Three stacked guards: family pre-filter, `max` aggregator (never diluted by a light reading), and `BUILD_HEAVY_MIN_SAMPLES` before any light verdict. Threshold and sample floor are both env-overridable for fast tightening without a code change |
| A malformed line in `metrics.jsonl` aborts the read and crashes the bucketing loop under `set -euo pipefail` | H | L | Read with `jq -R` + `fromjson? // empty`, which skips unparseable lines rather than failing; the whole read is additionally guarded so any failure path yields the conservative *heavy* verdict, never an error |
| Float `wall_clock_seconds` values (the format's worked example shows `4123.7`) break a bash integer comparison | M | M | The count and max are computed inside one `jq` invocation and compared with `awk`, never with `[ ]`/`(( ))` integer tests |
| Editing an orchestrator-critical path (`orchestrate-cycle-plan.sh`) regresses batch dispatch | H | L | Phases 1 and 3 are each independently green against today's behavior before the signal can ever return *light*; Phase 4 asserts the existing four Group 32 cases still pass; Phase 6 runs the complete gate set |
| Part 2's append silently makes the "The Three Failure Modes" heading a falsehood by adding two more | M | M | The two new classes go in their own clearly-labeled sibling subsection with a forward-pointer from the three-modes preamble, preserving that taxonomy's retained-history integrity rather than editing history |
| Self-modification admission defers this task's implementation | L | H | Expected, per the dispatch's own SELF-MODIFICATION note and `orchestrator-critical-paths.json`'s listing of `scripts/orchestrate-cycle-plan.sh`. The orchestrator defers and re-invokes `/orchestrate`; `--allow-self-modifying` is NOT to be passed |
| Source-store edits do not take effect because `.claude/` is stale | M | M | Phase 6 runs `deploy-headless.sh` before the full gate set; no phase hand-edits `.claude/**` |
| A concurrent sibling dispatch (task 280, plan phase) edits a shared file | M | L | Declared file scopes are disjoint (280 touches `record-version-*`, `no-record-versioning-*`, `index-entries.json`, `manifest.json`, `merge-sources/claudemd.md`; this task touches none of them). Per-file re-read immediately before each edit, scoped per-file staging, never `git-snapshot.sh` in reverting mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 3 (for 4); 2, 3 (for 5) |
| 4 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Measured-signal predicate in task-classification-lib.sh [NOT STARTED]

**Goal**: Turn `task_is_build_heavy_implement()` into a measured-signal predicate inside its own
lib file, additively — the existing two-argument call site keeps compiling and keeps producing
today's verdict, so this phase is green on its own.

**Tasks**:

- [ ] Re-read `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` immediately
      before editing (concurrent-sibling discipline).
- [ ] Rename `BUILD_HEAVY_TASK_TYPES` to `BUILD_HEAVY_CANDIDATE_TASK_TYPES` at its declaration and
      in its reader, and rewrite the array's banner comment to state the demoted role per
      Decision 1 (candidacy pre-filter, not verdict) while keeping the "a future extension adds
      its task_type to this ONE array" guidance and the hoisting history.
- [ ] Add two env-overridable constants beside the array, with their grounding in the comment:
      `BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS="${BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS:-900}"`
      (900 s sits above the 547 s zero-build dispatch duration observed on this very task, with
      margin, and well below the tens of minutes a full Mathlib build drives a dispatch to) and
      `BUILD_HEAVY_MIN_SAMPLES="${BUILD_HEAVY_MIN_SAMPLES:-2}"` (Decision 3).
- [ ] Add `build_heavy_measure_signal <task_dir_abs>`: emits `heavy|<basis prose>` or
      `light|<basis prose>` on stdout, always exits 0. Reads count and max in ONE `jq` call,
      malformed-line-tolerant and float-safe:
      `jq -R -s 'split("\n") | map(fromjson? // empty) | map(select(.phase == "implement") | select(has("wall_clock_seconds")) | .wall_clock_seconds) | "\(length) \(max // 0)"'`.
      `has("wall_clock_seconds")` is load-bearing: the metrics format omits the key when
      unavailable and it MUST NOT be read as `0`. Compare with `awk`, never a bash integer test.
- [ ] Rewrite `task_is_build_heavy_implement <phase> <ttype> [task_dir_abs]` as the three-rung
      ladder: (1) `[ "$phase" = "implement" ]` or return 1; (2) `$ttype` in
      `BUILD_HEAVY_CANDIDATE_TASK_TYPES` or return 1; (3) delegate to
      `build_heavy_measure_signal`, returning 0 for `heavy` and 1 for `light`. An empty or omitted
      third argument yields *heavy* without consulting anything — the backward-compatible,
      conservative path (Decision 4).
- [ ] Set a global `BUILD_HEAVY_SIGNAL_BASIS` to the basis prose on every rung-3 evaluation, so
      Phase 3's call site can name the decision's basis in its `deferred[]` reason. Use a global
      (not a return channel) following `lake-build-guard.sh`'s `_RECORD_FINALIZED` precedent.
- [ ] Extend the file header to record the measured-signal design, Decision 2's declined-alternative
      table in brief, and the omission-not-zeroing constraint.
- [ ] Confirm the lib still sources cleanly and sets no shell options: `bash -n` plus a sourcing
      smoke check.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: `BUILD_HEAVY_TASK_TYPES` is hypothesized to have exactly 3 occurrences in
the source store (declaration and reader in `task-classification-lib.sh`, one comment reference in
`orchestrate-cycle-plan.sh:1984` which Phase 3 updates), re-derived at plan-authoring time via
`grep -rn BUILD_HEAVY_TASK_TYPES agent-system/`. Confirm at implementation time by re-running that
grep and checking the post-rename count of the old name is 0.

**Tier Justification**: The edit is confined to one lib file with an additive optional third
parameter that leaves the existing two-argument call site's verdict unchanged, and is covered by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh,test-force-phases.sh,test-orchestrate-unwind-dispatch.sh`
— the exact suite set `suite_selection_select` resolves for this path.

**Files to modify**:

- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` - rename the array to
  `BUILD_HEAVY_CANDIDATE_TASK_TYPES`, add the two threshold constants, add
  `build_heavy_measure_signal()`, rewrite `task_is_build_heavy_implement()` as a three-rung
  ladder, extend the header

**Verification**:

- `bash -n agent-system/extensions/core/scripts/lib/task-classification-lib.sh` passes.
- Sourcing the lib in a subshell leaves `set -e`/`set -u`/`pipefail` unchanged and leaks no
  `_`-prefixed internals.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh,test-force-phases.sh,test-orchestrate-unwind-dispatch.sh`
  is green — confirming the still-two-argument call site produces today's verdicts.
- `grep -rn BUILD_HEAVY_TASK_TYPES agent-system/` returns only the one
  `orchestrate-cycle-plan.sh` comment line Phase 3 owns.

---

### Phase 2: Isolation posture record — hazard classes and CoW evaluation [NOT STARTED]

**Goal**: Append Part 2's two later-observed hazard classes and the
CoW/reflink/overlayfs/clone-nothing evaluation to `batch-orchestration-guardrails.md`'s
"Working-Tree and Build Isolation Posture" section, with an exact-filename cross-reference to the
reaffirmation record.

**Tasks**:

- [ ] Re-read the two evidence documents for the exact facts to transcribe:
      `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
      ("Live Evidence") and `specs/decisions/worktree-isolation-removal-reaffirmation.md` ("The
      Gate Question, Answered").
- [ ] Re-read the target section of
      `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      immediately before editing.
- [ ] Add a new `### Two Later-Observed Hazard Classes` subsection immediately after "The Three
      Failure Modes", plus a one-line forward pointer in that section's own preamble. Do NOT
      renumber or extend the three-mode taxonomy in place: the section states explicitly that the
      taxonomy is "retained as history and reference", and adding a fourth and fifth item inside
      it would edit history and make its own heading false.
- [ ] Transcribe hazard class A — **repo-scanning pollution from in-tree worktree provisioning**:
      `.orchestrate-worktrees/` surfacing in `git status` with no matching `.gitignore` rule, plus
      the named generator classes (`certificate-export.sh`'s fixture suite, `status-counts.sh`,
      `typst-component-index.sh`) that do not consult `.gitignore` at all regardless of its
      content — so a `.gitignore` rule would not have closed this.
- [ ] Transcribe hazard class B — **mode 2's guard-bypass-via-bare-invocation recurrence**: a
      plan-sanctioned `certify.sh` (406 lines, zero occurrences of `lake-build-guard`) issuing bare
      `lake build --wfail` / `lake env` / `lake shake` calls gated only by `command -v lake`. Frame
      it as the *recurrence* of the already-named opt-in-participation residual, i.e. evidence that
      residual is live and observed, not hypothetical.
- [ ] Add a new `### CoW / Reflink / Overlayfs / Clone-Nothing Evaluation` subsection adjacent to
      "A Corrected Rationale for Hardlink-Over-Symlink", covering all three candidates: CoW/reflink
      unavailable (`ext4` has no `FICLONE`/reflink support, confirmed via `findmnt -no FSTYPE /` on
      both this host and the sibling repo) — the blocker; overlayfs structurally correct and
      available on `ext4` without migration, but requiring a new privileged/user-namespace
      mount-management subsystem and not addressing the repo-scanning hazard at all;
      clone-nothing/content-addressed cache the most promising and externally practiced
      (`lake exe cache get`'s own tar-keyed oelean store) but unverified for this system's
      non-Mathlib Lean targets and explicitly needing its own feasibility spike — the spike this
      task's description names as a non-goal.
- [ ] Add `specs/decisions/worktree-isolation-removal-reaffirmation.md` by **exact filename** to
      the section's "Related Documents" list. Today only `worktree-isolation-removal-verdict.md`
      (the superseded original) is named there; the reaffirmation record is referenced only
      generically in prose, so a reader cannot navigate to it directly.
- [ ] Verify every path and filename written in this phase resolves on disk.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: Every changed hunk is markdown prose in a context file with no executable
surface, covered by `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint) together with
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-gate-out-self-attribution.sh`
— the suite set `suite_selection_select` resolves for this path, which is a real set here, not the
`__FULL_SWEEP__` sentinel.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - add
  `### Two Later-Observed Hazard Classes` after "The Three Failure Modes" plus a preamble forward
  pointer; add `### CoW / Reflink / Overlayfs / Clone-Nothing Evaluation` near "A Corrected
  Rationale for Hardlink-Over-Symlink"; add the reaffirmation record's exact filename to "Related
  Documents"

**Verification**:

- Diff read-through confirms every changed hunk is prose inside the named section, with no edit
  crossing into another section.
- Every file path newly written in the section resolves on disk (`ls`/`test -f` over each).
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` is green.
- The "The Three Failure Modes" heading and its three bullets are textually unchanged, confirming
  the retained-history taxonomy was not edited.

---

### Phase 3: Wire the measured signal into the admission call site [NOT STARTED]

**Goal**: Pass the resolved task directory into the predicate at
`orchestrate-cycle-plan.sh`'s bucketing loop, surface the decision basis in the `deferred[]`
reason, and update the script's own header narrative and inline comment.

**Tasks**:

- [ ] Re-read the bucketing-loop region of
      `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` immediately before editing.
- [ ] Hoist the `task_lookup_dir`-based task-directory resolution so one resolved value serves both
      the existing forced-implement-needs-a-plan gate and the new build-heavy check, rather than
      calling `task_lookup_dir` twice in the same loop iteration. Keep the existing gate's behavior
      and its `_p5_` naming intact; resolution must stay unconditional relative to the build-heavy
      check (that gate runs only for forced implements, the build-heavy check for all of them).
- [ ] Pass the resolved absolute task directory as the predicate's third argument:
      `task_is_build_heavy_implement "$g" "${task_types[$t]:-}" "$_task_dir_abs"`.
- [ ] Extend the `deferred[]` reason string with a parenthetical signal basis from
      `BUILD_HEAVY_SIGNAL_BASIS`, e.g. `... this cycle's one build-heavy implement dispatch
      (signal: measured max 1820s over 3 implement dispatches >= 900s threshold); deferring to a
      later cycle`. **Keep the existing leading substring `build-heavy implement co-scheduling`
      verbatim and keep the string free of the token `file_scope`** — Group 32 case (i) asserts
      both, and both must keep passing. Append only; never restructure the existing prefix.
- [ ] Update the inline comment block above the check (which today says the rule "Calls the single
      reader of `BUILD_HEAVY_TASK_TYPES`") to the new array name and the measured-signal ladder,
      and state that the dry-run/live parity property is unchanged because this remains one shared
      bucketing loop with one row builder.
- [ ] Update the script header's Mode 2 decision narrative to describe the measured signal and the
      conservative fallback, replacing the family-list framing.
- [ ] Confirm `bash -n` passes and that the dry-run path still emits a well-formed plan.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The predicate's direct-dependent set is hypothesized to be exactly one file
(`orchestrate-cycle-plan.sh`), re-derived at plan-authoring time via
`grep -rn task_is_build_heavy_implement agent-system/`, which returned one call site plus the lib's
own definition. Confirm at implementation time by re-running that grep before editing, and treat
any second consumer as a scope change requiring its own task list entry.

**Tier Justification**: The change alters the predicate's call arity across the
lib/consumer boundary, so verification must cover the changed lib plus its enumerated direct
dependent — discharged by
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only <the set suite_selection_select resolves for task-classification-lib.sh and orchestrate-cycle-plan.sh together>`
(24 suites as of this plan; re-derive rather than hardcoding, since the set grows with the corpus).

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - hoist the task-directory
  resolution, pass it as the predicate's third argument, append the signal basis to the
  `deferred[]` reason, update the inline comment block and the header's Mode 2 narrative

**Verification**:

- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` passes.
- `grep -rn BUILD_HEAVY_TASK_TYPES agent-system/` returns nothing (the old name is fully retired).
- The existing Group 32 cases (i)-(iv) pass unchanged:
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`.
- The full resolved suite set for both touched paths is green under `run-all.sh --only`.
- A manual `--dry-run` invocation against a two-`lean4` fixture still emits 1 dispatch + 1 deferred,
  with the deferred reason carrying both the original prefix and the new parenthetical basis.

---

### Phase 4: Extend Group 32 with measured-signal coverage [NOT STARTED]

**Goal**: Cover both directions of the new signal, each guard independently, and assert the
regression-safety property that unmeasured candidates behave exactly as before.

**Tasks**:

- [ ] Re-read Group 32 of
      `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` and its
      `write_state`/`reset_lock_dirs`/`run_sut`/`jqf` helpers, to match the suite's existing fixture
      idiom rather than inventing a second one.
- [ ] Add a small helper that writes a synthetic `metrics.jsonl` into a fixture task directory under
      `$WORKDIR/specs/`, matching the real schema's field names and the directory name
      `task_lookup_dir` resolves for the fixture's `project_number`/`project_name`.
- [ ] Case (v) — **the headline fix**: two `lean4` implement candidates, each with 2 implement-phase
      entries well under threshold. Assert BOTH dispatch, 0 deferred. This is the task-129-shaped
      case the static family list categorically refused.
- [ ] Case (vi) — **min-samples guard**: one `lean4` candidate with exactly 1 light measurement.
      Assert it is still treated as heavy (so pairing it with a second build-heavy candidate still
      defers one).
- [ ] Case (vii) — **max-not-mean proof**: one `lean4` candidate with 2 entries, one far below and
      one far above threshold, chosen so the *mean* falls below threshold while the *max* does not.
      Assert heavy. This case fails if the aggregator is ever changed to a mean.
- [ ] Case (viii) — **omission-not-zeroing**: `metrics.jsonl` present with implement entries that
      lack `wall_clock_seconds` entirely. Assert heavy (the absent key must never be read as `0`,
      which would otherwise read as maximally light).
- [ ] Case (ix) — **candidacy pre-filter proof**: a `general` implement candidate with a very large
      measured wall clock. Assert it is not build-heavy, so two such candidates co-schedule freely.
- [ ] Case (x) — **malformed-line tolerance**: `metrics.jsonl` containing a non-JSON line alongside
      valid implement entries. Assert the SUT exits 0 and renders a verdict rather than failing.
- [ ] Case (xi) — **basis observability**: a measured-heavy defer's reason string contains the
      signal basis, and still contains `build-heavy implement co-scheduling` and still contains no
      `file_scope` token.
- [ ] Case (xii) — **regression safety**: explicitly re-assert that a fixture with NO task
      directory (hence no `metrics.jsonl`) produces today's exact verdict, naming the conservative
      fallback as the reason in the pass message.
- [ ] Follow the suite's own naming convention in every pass/fail message: "candidate #N" /
      "project #N", never "task N", per `no-task-references-in-deliverables.md`.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts it adds 8 new cases (v)-(xii) to Group 32, extending the
existing 4 cases (i)-(iv) to 12 — the existing count re-derived at plan-authoring time by reading
the Group 32 block directly. Confirm at implementation time by counting `pass`/`fail` call sites
within the Group 32 block before and after, and treat a different pre-existing count as a signal
that the group changed under a concurrent edit.

**Tier Justification**: The edit is confined to one test file with no production surface, and is
covered by running that suite itself:
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - add a synthetic
  `metrics.jsonl` fixture helper and Group 32 cases (v)-(xii)

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-plan.sh`
  is green, with every new case reporting PASS and the pre-existing cases (i)-(iv) unchanged.
- Each new case is confirmed to fail for the right reason when its own guard is temporarily
  inverted (spot-check at least cases (v) and (vii), the two whose direction is new behavior rather
  than preserved behavior).
- `bash .claude/scripts/check-task-references.sh --quiet` reports no new occurrences from this file.

---

### Phase 5: Restate the Mode 2 principle and correct two stale claims [NOT STARTED]

**Goal**: Bring `batch-orchestration-guardrails.md`'s Mode 2 principle statement in line with the
now-implemented measured signal, and correct two claims in the same document that plan-time
verification found stale.

**Tasks**:

- [ ] Re-read the "Mode 2: An Admission Rule, Not a Layer" subsection and the "Related Documents"
      list of `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      immediately before editing (Phase 2 edited this same file in an earlier wave).
- [ ] Restate the Mode 2 principle as "never co-schedule two *measured-build-heavy* implement
      tasks in one cycle", with the measured signal, the conservative no-history fallback, and the
      family list's demoted candidacy-pre-filter role named as principles. Keep the document's
      standing posture of stating principles only and pointing at
      `orchestrate-cycle-plan.sh`'s own header for the mechanism — do not restate the implementation
      here.
- [ ] Correct stale claim 1: "Related Documents" currently says the mode-2 admission predicate is
      "a stated intent for that mechanism's eventual home rather than a claim that the predicate is
      implemented there today". It **is** implemented today, in `orchestrate-cycle-plan.sh`'s
      bucketing loop, with Group 32 test coverage. Replace the hedge with the fact.
- [ ] Correct stale claim 2: the same list describes
      `context/reference/orchestrator-critical-paths.json` as having "13 entries". The live count is
      16. Update the figure and keep the accompanying `scope_roots` and dual-consumer description
      intact.
- [ ] Re-read the diff to confirm no hunk strays outside these three edits.

**Timing**: 0.75 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The critical-path entry count is asserted as 16, re-derived at
plan-authoring time via
`jq '.critical_paths | length' agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
(returned 16, against the document's stated 13). Re-run that exact command at implementation time
before writing the figure, since a concurrent task may add an entry.

**Tier Justification**: Every changed hunk is markdown prose in a context file with no executable
surface, covered by `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint) plus the diff read-through the `prose` tier prescribes.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - restate the
  Mode 2 principle for the measured signal; replace the "stated intent, not implemented" hedge with
  the implemented fact; correct the critical-path entry count

**Verification**:

- Diff read-through confirms exactly three edit regions, all prose.
- `jq '.critical_paths | length' agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
  matches the figure written into the document.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` is green.
- `grep -n "stated intent for that mechanism's eventual home" <file>` returns nothing.

---

### Phase 6: Redeploy and full gate set [NOT STARTED]

**Goal**: Propagate the source-store changes into the deployed `.claude/` tree and confirm the
complete gate battery is green across both parts.

**Tasks**:

- [ ] Confirm the working tree carries only this task's own changes plus any known concurrent
      sibling's, via `git status --short`; investigate any foreign modification before proceeding
      rather than dismissing it.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate `.claude/`
      from the source store. No file under `.claude/**` is hand-edited at any point in this plan.
- [ ] Confirm the deployed mirror now matches the source store for all four touched files, and that
      the retired `BUILD_HEAVY_TASK_TYPES` name appears nowhere in either tree:
      `grep -rn BUILD_HEAVY_TASK_TYPES agent-system/ .claude/` returns nothing.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` with no `--only-gate`, no
      `--skip-slow`, and no `--only` suite narrowing — all 21 gates including Gate 8's full shell
      suite battery. A narrowed or `--skip-slow` pass is explicitly NOT acceptable evidence for
      this phase.
- [ ] Run the full test corpus: `bash agent-system/extensions/core/scripts/tests/run-all.sh` with
      no `--only`.
- [ ] Record the task's completion state and confirm every phase heading in this plan carries a
      terminal marker.

**Timing**: 0.75 hours

**Depends on**: 4, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `.claude/` (regenerated wholesale by `deploy-headless.sh`, never hand-edited)

**Verification**:

- `bash agent-system/extensions/core/scripts/deploy-headless.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` — the complete 21-gate battery, no `--only-gate`, no
  `--skip-slow` — is green.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (full corpus, no `--only`) is green.
- `grep -rn BUILD_HEAVY_TASK_TYPES agent-system/ .claude/` returns nothing.
- `diff` confirms each of the four touched source-store files matches its deployed counterpart.

---

## Testing & Validation

- [ ] Group 32 cases (i)-(iv) pass **unchanged**, confirming the conservative no-history fallback
      reproduces today's behavior byte-for-byte for every unmeasured candidate.
- [ ] Two measured-light `lean4` implement candidates co-schedule in one cycle (case (v)) — the
      capability the static family list categorically refused.
- [ ] A single light measurement does NOT yield a light verdict (case (vi), min-samples guard).
- [ ] A light-plus-heavy pair whose mean is below threshold still yields heavy (case (vii),
      proving `max`, not mean).
- [ ] An implement entry missing `wall_clock_seconds` is never read as `0` (case (viii)).
- [ ] A non-family `task_type` with a large measured duration is never build-heavy (case (ix)).
- [ ] A malformed `metrics.jsonl` line does not abort the bucketing loop (case (x)).
- [ ] The `deferred[]` reason names the signal basis while preserving the existing
      `build-heavy implement co-scheduling` prefix and omitting any `file_scope` token (case (xi)).
- [ ] Dry-run and live paths render byte-for-byte identical deferred reasons (existing case (iv),
      still passing).
- [ ] Every file path newly written into `batch-orchestration-guardrails.md` resolves on disk.
- [ ] The complete `verify-deploy.sh` battery and the full `run-all.sh` corpus are green (Phase 6).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` — measured-signal
  predicate, `build_heavy_measure_signal()`, two env-overridable constants, renamed candidacy array
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — task-directory-aware call
  site, basis-carrying `deferred[]` reason, updated Mode 2 header narrative
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — Group 32 cases
  (v)-(xii) plus a synthetic `metrics.jsonl` fixture helper
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — two
  later-observed hazard classes, the CoW/reflink/overlayfs/clone-nothing evaluation, the
  reaffirmation record's exact-filename cross-reference, the restated Mode 2 principle, two
  corrected stale claims
- `.claude/**` — regenerated by `deploy-headless.sh` in Phase 6, never hand-edited
- `specs/311_measured_co_scheduling_signal_and_isolation_posture/summaries/01_*-summary.md` —
  implementation summary

## Rollback/Contingency

Each phase commits independently at its own green sub-steps, so reverting is per-phase rather than
all-or-nothing, and the phase ordering makes partial landing safe by construction: Phases 1 and 3
are each green against today's verdicts before the signal can ever return *light*, and Phase 2's
append is pure retained-history documentation with no behavioral coupling to Part 1.

- **Part 1 misbehaves after landing**: set `BUILD_HEAVY_MIN_SAMPLES` to a very large value in the
  environment. Every candidate then falls to the conservative fallback and the rule reverts to
  today's family-list behavior with no code change and no revert — this is the primary contingency
  and the reason both constants are env-overridable.
- **A phase must be reverted**: `git revert` that phase's own commits. No phase depends on a later
  phase's edits, and `.claude/**` is regenerated from the source store by re-running
  `deploy-headless.sh`, so the deploy tree never needs its own revert.
- **A rollback that would discard uncommitted work**: do NOT emit a bare reverting
  `git-snapshot.sh`. Follow `context/contracts/recovery.md`'s rollback rung for the exact
  invocation shape, including its out-of-scope override flag; for an ordinary defensive checkpoint
  before risky work, use `git-snapshot.sh --no-revert`, which is durable without reverting the
  working tree.
- **Concurrency**: a sibling task is scheduled this same cycle on this shared working tree. Never
  stage a directory or glob pathspec, re-read each file immediately before editing it, and if a
  foreign commit or foreign uncommitted modification appears, STOP and report it after checking
  `git log` to confirm the work is not this task's own.
