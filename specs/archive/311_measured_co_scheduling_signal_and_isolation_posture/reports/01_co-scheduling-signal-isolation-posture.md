# Research Report: Task #311

**Task**: 311 - Measured co-scheduling signal and isolation posture (two folded parts)
**Started**: 2026-10-08T00:00:00Z
**Completed**: 2026-10-08T00:00:00Z
**Effort**: ~1 research dispatch (grounded entirely in existing codebase evidence; no implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase (`orchestrate-cycle-plan.sh`, `task-classification-lib.sh`,
`dispatch-metrics.sh`/`dispatch-metrics.md`, `lake-build-guard.sh`, `territory.md`,
`batch-orchestration-guardrails.md`, `orchestrator-critical-paths.json`), task 301's archived
research report and the isolation-removal reaffirmation decision record (the evidence base this
task was built from), one WebSearch pass on duration-based CI admission heuristics.
**Artifacts**:
- This report: `specs/311_measured_co_scheduling_signal_and_isolation_posture/reports/01_co-scheduling-signal-isolation-posture.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md,
no-task-references-in-deliverables.md (this file is under `specs/`, exempt)

## Executive Summary

- **Part 1 (measured build weight) is well-grounded and has an unexpectedly cheap primary
  signal already built: `specs/{NNN}_{SLUG}/metrics.jsonl`.** `dispatch-metrics.sh` already
  records `wall_clock_seconds` for every `phase: "implement"` dispatch, keyed to the task's own
  directory, which `orchestrate-cycle-plan.sh`'s bucketing loop already resolves via
  `task_lookup_dir()` at the exact call site immediately above the build-heavy check (line 1964
  resolves `_p5_task_dir_abs`; the build-heavy check is at line 1987). Consulting this task's own
  prior implement-dispatch duration there is a small, local change reusing an existing idiom —
  not new instrumentation.
- **Job count is NOT available anywhere in this codebase, and parsing it from Lake's own output
  was already explicitly declined once, for a documented reason.** `lake-build-guard.sh`'s own
  header states "No job count: … it is a property of `lake`'s own output text, not of anything
  this guard records, and parsing it would couple the guard to a format it deliberately passes
  through untouched." A measured-signal design that leans on wall-clock duration (already
  captured) rather than job count (never captured, previously declined) avoids re-opening that
  declined path.
- **The static family list's failure mode is confirmed, not hypothetical**: task 301's live
  evidence measured a Mathlib-free `lean4` package (task 129) building in 6 s / 17 jobs from an
  empty `.lake/`, categorically refused co-scheduling purely because its `task_type` string is
  `"lean4"`. `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` at
  `task-classification-lib.sh:101` (the current source-store location; line 1819 cited in the
  dispatch description is this repo's older line number for the same array before it was
  extracted into this lib file) has no measurement or probe anywhere in its one reader,
  `task_is_build_heavy_implement()`.
- **No existing mechanism supplies a signal for a task's *first* implement dispatch** (the
  explicit fallback case the dispatch calls out), since `metrics.jsonl` is written only after a
  dispatch completes. External research corroborates both halves of this: historical build
  duration is a real, used admission-heuristic input elsewhere (a Launchpad buildd proposal to
  refuse long builds using an already-estimated duration; a patent describing a running average
  duration maintained between builds), but a Ninja-project discussion separately warns that
  historical duration is an inaccurate predictor when a cache (e.g. `ccache`) changes between
  runs — directly analogous to Lake's own oelean cache and `.lake/` state, and a concrete reason
  the no-history fallback cannot simply assume "first run was light therefore future runs are
  light."
- **Part 2 (isolation posture record) is a pure documentation append**: the two hazard classes
  (repo-scanning pollution; mode 2's guard-bypass-via-bare-invocation recurrence, evidenced by
  `certify.sh` bypassing `lake-build-guard.sh` via a bare `lake` call) and the
  CoW/reflink/overlayfs/clone-nothing evaluation are already fully written, point-by-point, in
  task 301's research report and the reaffirmation decision record — both already exist, are both
  already cross-referenced correctly, and this task's own description already names the exact
  cross-reference path (`specs/decisions/worktree-isolation-removal-reaffirmation.md`). Appending
  them to `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section
  is transcription into the retained-history subsections that section already carries, not new
  analysis.
- **Both parts land under `agent-system/extensions/core/`, never `.claude/**`**, per
  `source-store-deploy-boundary.md`: this repository's `.claude/` tree is a deploy artifact of the
  `core` extension (confirmed via `.claude-extensions.json`'s `extensions.core.source_dir` =
  `agent-system/extensions/core`), and the identical files exist at both paths today
  (`.claude/scripts/orchestrate-cycle-plan.sh` and
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` are byte-identical in this
  snapshot) — the source-store copy is the one to edit.
- **This task is genuinely self-modifying**, confirmed directly against
  `orchestrator-critical-paths.json`'s `critical_paths[]`: `scripts/orchestrate-cycle-plan.sh` is
  listed verbatim. The admission gate should defer it on this cycle, per the dispatch's own
  SELF-MODIFICATION note — this is expected, not a defect to route around.
- **No implementation was performed and no file under `agent-system/extensions/core/scripts/`
  was modified** — this dispatch is research-only, per the phase contract.

## Context & Scope

Task 311 folds two parts into one document edit, both scoped to
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (plus, for Part
1, the implementing script/lib and possibly `territory.md`'s generic cross-reference):

- **Part 1 — measured build weight**: replace `BUILD_HEAVY_TASK_TYPES`'s static `task_type`
  family membership test with a measured-or-probed signal, and explicitly design what happens
  for a task with no measurement history yet.
- **Part 2 — isolation posture record**: append the two new hazard classes and the
  CoW/reflink/overlayfs/clone-nothing evaluation to the existing "Working-Tree and Build Isolation
  Posture" section, cross-referencing the reaffirmation decision record, per that research
  report's own Context Extension Recommendation (which named this exact gap and exact
  recommendation, not performed at the time because it was outside that task's charter).

**Non-goals, honored**: no per-dispatch `git worktree` isolation design is proposed or restored
(CONFIRMED removed, per the reaffirmation record); no Lake/Mathlib shared-cache feasibility spike
was run (named in the evidence base as a possible future spike, explicitly out of scope here).

**What this report does not do**: it does not write the actual code change for Part 1 (that is
plan/implement work) and does not re-litigate the CONFIRM verdict Part 2 records — it verifies
the evidence is accurate, current, and complete enough to transcribe, and surfaces the concrete
hook points and constraints a plan should account for.

## Findings

### Codebase Patterns — Part 1 (Measured Build Weight)

- **Current mechanism, exact location.** `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` is declared
  at `agent-system/extensions/core/scripts/lib/task-classification-lib.sh:101`, inside a dedicated
  extraction (the file's own header explains this was hoisted out of
  `orchestrate-cycle-plan.sh` to guarantee the array and its reader function are defined before
  any call site, closing a prior exit-127-under-`set -euo pipefail` hazard). Its sole reader,
  `task_is_build_heavy_implement(phase, ttype)`, does a linear membership test:
  `[ "$phase" = "implement" ] && ttype is in the family`. No other file reads this array
  (`grep -rn BUILD_HEAVY_TASK_TYPES` returns exactly these two lines plus their mirrored `.claude/`
  deploy copy).
- **Exact call site and what is already in scope there.** `orchestrate-cycle-plan.sh`'s bucketing
  loop calls `task_is_build_heavy_implement "$g" "${task_types[$t]:-}"` at line 1987, inside the
  same `for t in "${eligible_tasks[@]}"` loop that, 23 lines earlier (line 1964), already resolves
  `_p5_task_dir_abs="${PROJECT_ROOT}/$(task_lookup_dir "$t" "${project_names[$t]}"
  "$PROJECT_ROOT")"` for an unrelated check (the forced-implement-needs-a-plan-artifact gate).
  `task_lookup_dir` is called this same way at six other sites in this one script. Resolving
  `${task_dir}/metrics.jsonl` for the build-heavy check is therefore a small, local addition that
  reuses an idiom already proven correct in this exact function, not new resolution machinery.
- **The primary measured signal already exists and needs no new instrumentation.**
  `scripts/dispatch-metrics.sh` (documented in `context/formats/dispatch-metrics.md`) already
  writes one JSON line per dispatch to `specs/{NNN}_{SLUG}/metrics.jsonl`, including
  `phase` (`"implement"` is one of the closed enum values), `outcome`, and — critically —
  `wall_clock_seconds`, computed from `.dispatch/{seq}.md`'s own `dispatch_start_ts` to the
  postflight return, omitted (never zeroed) only when `dispatch_start_ts` is absent or the
  fail-closed sentinel. This file is never gitignored and is append-only, one line per dispatch,
  already keyed by exactly the task directory `task_lookup_dir` resolves. A task with two or more
  prior `implement`-phase dispatches (e.g. a multi-phase plan spanning several cycles) already has
  a durable, measured wall-clock figure sitting in its own task directory, writable to read at
  admission time with a plain `jq` filter — no new capture path needed for this half of the
  signal.
- **Job count is a dead end, confirmed by an existing, deliberate design decision — do not
  re-open it.** `lake-build-guard.sh` (around its result-sharing/replay logic) states explicitly:
  "No job count: see the plan's Decision 3 — it is a property of `lake`'s own output text, not of
  anything this guard records, and parsing it would couple the guard to a format it deliberately
  passes through untouched." Separately, `lake-build-guard.sh`'s own header records that "Lake
  5.0.0 exposes no `-j`/`--jobs` flag." Any design that wants a job-count signal would be
  reversing an explicit, reasoned, already-shipped decision to avoid exactly this coupling — a
  materially larger and riskier change than consulting wall-clock duration, which is already
  captured without touching Lake's output format at all.
- **`file_scope` could, in principle, support a *second*, static, zero-execution probe, but this
  is unverified and the field is documented as unreliable for this purpose.**
  `rules/state-management.md` states `file_scope` is "optional/descriptive (not
  filesystem-validated)" — set at creation time, never mutated, and not guaranteed to reflect the
  actual target package path. A design that tries to resolve a lean4/cslib task's target
  `lakefile.toml`/`lake-manifest.json` from `file_scope` (to grep for a Mathlib dependency as a
  zero-execution heavy/light proxy — Mathlib-dependent vs. Mathlib-free is exactly the line task
  129's counter-example sits on) is plausible but was not tested in this pass: no lean4/cslib
  task directory or lakefile exists in this repository to test against (lean4 tasks run in sibling
  repositories, e.g. the Verification repo task 301's live evidence was captured from), and
  `file_scope` has no filesystem-validation guarantee. This is recorded as an unverified candidate,
  not a recommended mechanism.
- **No test coverage exists for the current predicate or array.** `grep -rln
  task_is_build_heavy_implement\|BUILD_HEAVY_TASK_TYPES` against
  `agent-system/extensions/core/scripts/tests/` returns nothing. A plan changing this predicate's
  behavior has no existing acceptance test to extend; one would need to be written alongside the
  behavior change, not merely as a follow-up.
- **`territory.md` carries only a generic, non-array-specific cross-reference and needs no edit
  for Part 1.** `context/contracts/territory.md`'s "Working-tree and build isolation" subsection
  describes the rule in principle ("build contention is closed instead by the build-heavy
  co-scheduling admission rule in `orchestrate-cycle-plan.sh` … never dispatch two build-heavy
  implement tasks in the same cycle") without naming `BUILD_HEAVY_TASK_TYPES` or the family-list
  mechanism. Changing the signal's implementation does not require touching this file; it remains
  accurate prose regardless of which admission mechanism backs it. The dispatch description's
  note that "territory.md also carries build-heavy references" is accurate as a reason this task
  is one task (both files discuss the topic) but does not imply a required territory.md edit.
- **This task is self-modifying, confirmed directly, not inferred.**
  `context/reference/orchestrator-critical-paths.json`'s `critical_paths[]` lists
  `scripts/orchestrate-cycle-plan.sh` verbatim (one of 16 entries). Any plan that edits this file
  trips the self-modification admission check in `orchestrate-batch-admit.sh`. The dispatch's own
  SELF-MODIFICATION note anticipates exactly this; no new finding is needed to confirm it, only
  independent verification that the critical-path declaration is real (it is).

### External Resources — Part 1

One WebSearch pass ("CI build scheduler historical duration based admission heuristic avoid
co-scheduling heavy builds") surfaced:

- **Historical duration as an admission-heuristic input is real, used practice, not a novel
  proposal.** A Launchpad (Ubuntu PPA build farm) bug thread proposes that the builddmaster
  refuse to schedule builds expected to take more than a threshold when most builds are short,
  using an already-maintained build-duration estimate — the identical shape as this task's
  "recorded prior wall-clock duration" signal, applied to the identical problem (a few heavy
  builds monopolizing a shared farm). A separately-surfaced patent on job scheduling within
  program builds describes maintaining "a running average duration" per job between builds as the
  scheduling input.
- **The cache-invalidates-history caveat is the one directly relevant limitation.** A Ninja
  project discussion warns that historic build time is an inaccurate predictor when a cache (its
  example: `ccache`) changes between runs — a cache hit can make a past duration wildly
  unrepresentative of the next run. Lake's own oelean cache (`lake exe cache get`) and a project's
  own `.lake/` state are a direct analogue: a task's *first* implement dispatch building from an
  empty `.lake/` (task 129's own counter-example — 6 s, 17 jobs) and a *later* re-dispatch of the
  same task against a now-populated `.lake/` are not the same workload, even though both would be
  recorded against the same task's `metrics.jsonl`. A fallback/probe design should treat a single
  historical data point as a soft, not load-bearing, signal, and should not assume monotonic
  stability across a task's own dispatches.
- No other source in this pass addressed Lean/Lake specifically, or this repository's own
  task_type-family mechanism; the search was scoped to general CI admission-heuristic practice
  rather than Lean-specific tooling, consistent with Part 1's non-goal of a Lake/Mathlib
  cache-feasibility spike.

### Codebase Patterns — Part 2 (Isolation Posture Record)

- **The two named hazard classes and the CoW/reflink/overlayfs/clone-nothing evaluation are
  already fully written**, with exact evidence, in two documents both already cross-referenced by
  this task's own description:
  - `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
    (the research report; archived but intact and readable) — "Live Evidence" section documents
    the `certify.sh` bare-`lake`-invocation bypass (406-line file, zero occurrences of
    `lake-build-guard`, bare `lake build --wfail`/`lake env`/`lake shake` gated only by
    `command -v lake`) and the repo-scanning-pollution hazard (`.orchestrate-worktrees/` surfacing
    in `git status` with no matching `.gitignore` rule, plus named generator classes —
    `certificate-export.sh`'s fixture suite, `status-counts.sh`, `typst-component-index.sh` — that
    do not consult `.gitignore` at all regardless of its content). Its own "Context Extension
    Recommendations" section names this exact gap in `batch-orchestration-guardrails.md` and this
    exact fix, not performed there because it was outside that task's charter.
  - `specs/decisions/worktree-isolation-removal-reaffirmation.md` — "The Gate Question, Answered"
    section evaluates all three candidates (CoW/reflink: unavailable, `ext4` has no
    `FICLONE`/reflink support, confirmed via `findmnt -no FSTYPE /` on both this host and the
    sibling repo; overlayfs: structurally correct and available on `ext4` without migration, but
    requires a new privileged/user-namespace mount-management subsystem and does not address the
    repo-scanning hazard; clone-nothing/content-addressed-cache: the most promising, real,
    externally-practiced pattern (`lake exe cache get`'s own tar-keyed oelean store), but unverified
    for this system's non-Mathlib Lean targets and explicitly flagged as needing its own
    feasibility spike — the exact spike this task's description names as a non-goal here).
  - Both documents are currently reachable and unmodified since task 301's research; re-reading
    them in full for this task confirms no new divergence or staleness against the live `ext4`
    filesystem fact or the `certify.sh` bypass fact.
- **The target section's structure already anticipates this append.**
  `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section (lines
  1574–1844 in the current source-store copy) already states, in its own opening paragraph, that
  the three-failure-mode taxonomy is "retained as history and reference, not as a live selection
  rationale" — the same posture the two new hazard classes and the CoW evaluation should be
  recorded under. The section's existing subsections ("The Three Failure Modes," "Scoring Table,"
  "Measurements That Informed the Verdict," "Deliberate Divergences") are each exactly this shape:
  a retained-history record with its own heading. A new subsection (or an addition to "The Three
  Failure Modes" naming the repo-scanning and bare-invocation-recurrence hazards as a fourth and
  fifth item, plus a new "CoW/Reflink/Overlayfs/Clone-Nothing Evaluation" subsection near "A
  Corrected Rationale for Hardlink-Over-Symlink") fits the section's existing shape without
  restructuring it.
- **The "Related Documents" list at the end of the section already names the reaffirmation
  decision record's general existence** ("the isolation-removal decision record under
  `specs/decisions/`" is referenced generically twice in the section body) but does not yet carry
  an explicit filename-level cross-reference to
  `worktree-isolation-removal-reaffirmation.md` specifically (only
  `worktree-isolation-removal-verdict.md`, the original record, is named in the removal-script
  bullet). The append should add the reaffirmation record's exact filename to "Related Documents,"
  not only reference it inline in prose, so a future reader can navigate directly.

## Decisions

1. **Part 1's primary measured signal should be wall-clock duration read from
   `metrics.jsonl`, not job count.** Job count has no existing capture path and was already
   explicitly declined as a design direction in `lake-build-guard.sh` to avoid coupling to Lake's
   output format; wall-clock duration is already captured by `dispatch-metrics.sh` with zero new
   instrumentation. This is a finding to carry into the plan, not a code change made here.
2. **Part 1's no-history fallback must be designed explicitly, not left as an implicit
   default-to-heavy or default-to-light choice**, per the dispatch's own requirement. This report
   does not choose between the fallback options it surfaces (see Recommendations) — that choice
   belongs to the plan phase, informed by this report's evidence (notably the Ninja-discussion
   cache-invalidates-history caveat, which argues against ever treating a single data point as
   fully load-bearing).
3. **No implementation performed; no file under `agent-system/extensions/core/scripts/` or
   `agent-system/extensions/core/context/` was modified in this dispatch.** All edits described
   above are findings and recommendations for the plan/implement phases.
4. **Both parts are confirmed to belong under `agent-system/extensions/core/`**, never
   `.claude/**`, consistent with `source-store-deploy-boundary.md` and this task's own
   description.

## Risks & Mitigations

- **Risk: a plan treats a single prior `wall_clock_seconds` reading as fully predictive of the
  next build.** Mitigation: this report surfaces the Ninja-discussion cache-invalidation caveat
  explicitly — a plan should treat a lone historical data point as a soft signal (e.g., averaged
  over however many prior implement dispatches exist, or bounded by a conservative multiplier)
  rather than a hard threshold compared against one number.
- **Risk: the no-history fallback silently reproduces today's over-broad refusal (every lean4/cslib
  task treated as heavy) or silently reproduces today's under-protective gap (every unmeasured
  task treated as light, including a first-time heavy Mathlib-dependent task).** Mitigation: this
  report names both poles explicitly (conservative-default-to-heavy vs. a static,
  zero-execution Mathlib-dependency probe via `file_scope`) as unresolved design choices for the
  plan to pick between, rather than silently picking one here.
- **Risk: a plan assumes `file_scope`-based lakefile resolution is reliable enough to probe.**
  Mitigation: this report states plainly that this candidate is unverified (no lean4/cslib task
  directory exists in this repository to test against) and that `file_scope` is documented as
  non-filesystem-validated — a plan adopting this probe should verify it against a real lean4/cslib
  task directory in a repository that has one, not assume it from this report alone.
- **Risk: Part 2's append duplicates or contradicts the already-written evidence instead of
  transcribing it.** Mitigation: this report quotes the exact source locations and facts
  (file names, line counts, grep results) from both source documents, so the plan/implement phase
  can transcribe directly rather than re-deriving or paraphrasing lossily.
- **Risk: self-modification admission defers this task's implementation indefinitely if not
  re-invoked.** Mitigation: this is expected behavior per the dispatch's own SELF-MODIFICATION
  note and `orchestrator-critical-paths.json`'s listing of `orchestrate-cycle-plan.sh`; the
  orchestrator is expected to defer and re-invoke `/orchestrate`, not to be routed around with
  `--allow-self-modifying`.

## Context Extension Recommendations

- **Topic**: `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture"
  section (Part 2's own target).
  **Gap**: already named by task 301's own Context Extension Recommendation — the section
  retains the original three-failure-mode taxonomy as history but does not yet carry the
  repo-scanning-pollution hazard, the mode-2 guard-bypass-via-bare-invocation recurrence, or the
  CoW/reflink/overlayfs/clone-nothing evaluation.
  **Recommendation**: this is Part 2 of this very task — act on it directly in the
  implement phase, using this report's "Codebase Patterns — Part 2" findings as the exact source
  material and line/fact references, rather than re-reading the two evidence documents from
  scratch.
- **Topic**: `scripts/tests/` coverage for `task_is_build_heavy_implement()` /
  `BUILD_HEAVY_TASK_TYPES`.
  **Gap**: no test file references either symbol today; a behavior change here has no existing
  acceptance test to extend.
  **Recommendation**: the implement phase for Part 1 should add a test (mirroring whatever test
  harness pattern `scripts/tests/` already uses for other `orchestrate-cycle-plan.sh` lib
  extractions) covering at minimum: the no-history fallback behavior, and a measured-heavy vs.
  measured-light case using a synthetic `metrics.jsonl`.

## Recommendations

1. **Use `metrics.jsonl`'s `wall_clock_seconds` for `phase: "implement"` entries, filtered to the
   candidate task's own task directory (already resolvable via the existing `task_lookup_dir`
   call pattern in `orchestrate-cycle-plan.sh`), as the primary measured signal.** This requires
   no new capture instrumentation — only a read at admission time.
2. **Do not pursue a job-count signal.** It requires new Lake-output parsing that an existing,
   documented design decision in `lake-build-guard.sh` already declined, for a stated,
   still-valid reason (format coupling).
3. **Explicitly choose and document a no-history fallback in the plan**, between at least two
   evidenced candidates this report surfaces: (a) conservative default-to-heavy (preserves
   today's safety margin for a task's first implement dispatch, at the cost of still refusing
   task 129-shaped cases on their first run); (b) a cheap, zero-execution static probe —
   resolving the task's target Lean package manifest via `file_scope` and checking for a Mathlib
   dependency — explicitly flagged here as unverified and needing testing against a real
   lean4/cslib task directory before adoption, not a drop-in. A hybrid (probe when `file_scope`
   resolves to a real manifest; conservative default otherwise) is also a reasonable shape for
   the plan to consider.
4. **Treat a single historical `wall_clock_seconds` reading as a soft signal**, per the
   cache-invalidates-history caveat surfaced in External Resources — e.g. average across however
   many prior `implement`-phase entries exist for the task, or otherwise avoid hinging the
   decision on exactly one number.
5. **For Part 2, transcribe the already-written evidence directly** from
   `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
   ("Live Evidence" section) and
   `specs/decisions/worktree-isolation-removal-reaffirmation.md` ("The Gate Question, Answered"
   section) into new subsections of `batch-orchestration-guardrails.md`'s "Working-Tree and Build
   Isolation Posture" section, and add the reaffirmation record's exact filename to that section's
   "Related Documents" list (currently only the original verdict record is named there).
6. **Add a minimal test for the changed predicate** before or alongside the behavior change,
   since none exists today.

## Appendix

### Search Queries Used

- "CI build scheduler historical duration based admission heuristic avoid co-scheduling heavy
  builds"

### Codebase Commands Used (Representative)

- `grep -rn BUILD_HEAVY_TASK_TYPES agent-system/ .claude/` — confirmed the array's two locations
  (source store and deploy mirror) and its one reader.
- `grep -n "task_lookup_dir\|task_lookup_entry" orchestrate-cycle-plan.sh` — confirmed the
  existing task-directory-resolution idiom and its six call sites, including immediately above
  the build-heavy check.
- `grep -n "job\b" lake-build-guard.sh` — confirmed the explicit "no job count" design decision
  and the "Lake 5.0.0 exposes no `-j`/`--jobs` flag" fact.
- `jq -r '.critical_paths[].path' orchestrator-critical-paths.json` — confirmed
  `scripts/orchestrate-cycle-plan.sh` is a listed critical path, grounding the SELF-MODIFICATION
  note.
- `jq -r '.extensions.core.source_dir' .claude-extensions.json` — confirmed
  `agent-system/extensions/core` as the correct edit target per the source-store/deploy boundary.
- Direct reads of both Part-2 evidence documents in full
  (`specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`,
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`) and of
  `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section in
  full.

### Prior Tasks / Artifacts Audited

`specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`,
`specs/decisions/worktree-isolation-removal-reaffirmation.md`,
`specs/decisions/worktree-isolation-removal-verdict.md` (cited, not re-read in full — already
superseded-but-cited by the reaffirmation record), task 287 (`no_coschedule_build_heavy_implement`,
completed — the task that originally implemented the static family list this task revises).
