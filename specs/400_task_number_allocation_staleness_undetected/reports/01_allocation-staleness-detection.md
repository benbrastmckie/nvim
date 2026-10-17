# Research Report: Task #400

**Task**: 400 - Task-number allocation staleness undetected
**Started**: 2026-10-17
**Completed**: 2026-10-17
**Effort**: medium
**Dependencies**: 379 (already implemented/landed in this repository — confirmed below)
**Sources/Inputs**: Codebase (scripts/validate-state.sh, scripts/state-write.sh, scripts/tests/test-validate-state.sh, commands/task.md, commands/review.md, skills/skill-spawn/SKILL.md, skills/skill-fix-it/SKILL.md, skills/skill-project-overview/SKILL.md, agents/meta-builder-agent.md, context/contracts/conclusion-stage.md, context/schemas/state-schema.json, context/patterns/task-lock.md)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The seven hand-rolled allocation sites share one structural flaw: each reads
  `next_project_number` with a bare `jq -r` call *outside* `state-write.sh`'s mutex, then
  passes that value in as `--argjson`/`$num` to a *separate* `state-write.sh` invocation. The
  write is mutex-guarded; the read that produced the number being written is not. That gap is
  exactly what produced both recorded incidents (task 390's class, and the 2026-10-13
  BimodalLogic incident this task's dispatch documents).
- `state-write.sh` already runs the caller's jq filter *against the live file, after acquiring
  the mutex* (`jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE"`). Six of the seven call
  sites can close their own race with **zero new mechanism**, by rebinding the allocated
  number from `.next_project_number as $num` *inside* the filter instead of from a pre-read
  bash variable — the value is then read from the file jq is handed, under the mutex, not from
  a stale external read. This is a per-caller fix, in file-scope-conditional territory (see
  Scope note below), not this record's required file-scope.
- That per-caller fix does not, by itself, satisfy requirement 1 ("must not be able to
  silently produce a duplicate") as an invariant independent of every caller getting it right
  forever. The dispatch's own diagnosis (point 4) is that allocation is unserialized *by
  construction* — nothing stops an eighth future caller from reintroducing the same
  pre-read-then-pass bug. The structurally strongest fix is a dedicated allocation primitive
  inside `state-write.sh` itself (a new flag, e.g. `--allocate-into NAME`, that binds `$NAME`
  from the live file's own `.next_project_number` *inside* the same mutex-protected
  transform the caller's filter already runs in) so the number is never computed anywhere
  outside the critical section, for any caller, present or future.
- Requirement 2 (staleness detectable *before* use) and requirement 3 (archive-aware) point at
  a different artifact: `scripts/validate-state.sh`. It has an established, mature
  base-mode/`--deep`/`--archive` architecture (confirmed by reading it directly) and already
  has the exact archive-sibling-reading idiom this new check needs, reused verbatim from
  `--deep`'s Check D3 (`archive_file="$state_dir/archive/state.json"`, unioning
  `archived_projects`/`completed_projects`/`abandoned_projects`). No check anywhere compares
  `next_project_number` against `max(project_number)` today — confirmed by reading every
  `project_number`-touching line in the script. Check D1 (the only uniqueness check) is
  `--deep`-only, so even an *existing* duplicate is invisible in a base-mode run.
- Task 379 — the declared footprint/substantive dependency — is **already implemented** in
  this repository: `--archive` mode (Checks A1–A6) is live in `scripts/validate-state.sh` today,
  confirmed by reading the file directly. The dependency edge is satisfied; no conflict, no
  waiting required.
- Recommendation: two layers, each closing a distinct failure mode neither alone covers — a new
  base-mode, archive-aware `validate-state.sh` check (detection, requirements 2–4) plus a
  mutex-scoped allocation primitive in `state-write.sh` (prevention, requirement 1). See
  Recommendations for the division of labor and why collapsing to one layer leaves a gap.

## Context & Scope

This is a research-only dispatch for task 400 (`agent-system/extensions/core/**` is the edit
target at plan/implement time — the source store, never the deployed `.claude/**` tree — but no
edits are made during research). The task's own description and the prior incident write-up
(reproduced in the dispatch, not repeated here) establish the problem; this report's job was to
verify the diagnosed mechanism against the actual scripts, confirm the detection gap, confirm
the dependency-379 relationship, and survey the open fix-direction candidates on their merits.

Scope boundaries carried from the dispatch and re-verified here:
- Declared file scope: `scripts/validate-state.sh`, `scripts/tests/test-validate-state.sh`,
  `scripts/state-write.sh` (all under `agent-system/extensions/core/`).
- Conditional scope (narrow or add at plan time, only if the chosen remedy rewrites per-caller
  allocation sites instead of centralizing): `commands/task.md`, `commands/review.md`,
  `skills/skill-spawn/SKILL.md`, `skills/skill-fix-it/SKILL.md`,
  `skills/skill-project-overview/SKILL.md`, `agents/meta-builder-agent.md`,
  `context/contracts/conclusion-stage.md`. Confirmed live territory conflicts the dispatch
  flags: `conclusion-stage.md` and `agents/meta-builder-agent.md` are claimed by task 391
  (itself serialized behind 369/372/373 for that file); `commands/review.md` is claimed by task
  313. Adding either to this record's scope requires a dependency edge, not a bare exclusion.
- Out of scope: repairing the already-recovered incident data; vault-operation renumbering in
  `skill-todo/`; Step 4c's unpopulated `new_task_dir_paths` array (filed separately as task 402,
  which depends on this record).

## Findings

### Codebase Patterns

**The confirmed race mechanism, read directly from the six still-separate read-then-write call
sites** (grep of `next_project_number`/`next_num` across `agent-system/extensions/core`,
excluding `specs/`):

| Site | Read | Write |
|---|---|---|
| `commands/task.md:64,182` | `next_num=$(jq -r '.next_project_number' specs/state.json)` | `state-write.sh '.next_project_number = {NEW_NUMBER} \| .active_projects = [{"project_number": {N}, ...}] + ...'` |
| `commands/review.md:462,524` | `next_num=$(jq -r '.next_project_number' specs/state.json)` | `--arg num "$next_num" ... '.next_project_number = (($num \| tonumber) + 1)'` |
| `skills/skill-fix-it/SKILL.md:270,303-304` | `next_num=$(jq -r '.next_project_number' specs/state.json)` | hand-incremented bash variable folded into a later state-write.sh call |
| `skills/skill-project-overview/SKILL.md:288,414` | `next_num=$(jq -r '.next_project_number' specs/state.json)` | `--argjson num "$next_num" ... '... \| .next_project_number = ($num + 1)'` |
| `skills/skill-spawn/SKILL.md:270,400-404` | `next_num=$(jq -r '.next_project_number' specs/state.json)` | `--argjson next "$((next_num + task_count))" '.next_project_number = $next'` |
| `agents/meta-builder-agent.md:250,911` | `base_num = next_project_number from state.json` (prose) | "Increment next_project_number" (prose) |
| `context/contracts/conclusion-stage.md` Step 4c | **no read at all** | **no `.next_project_number` clause at all** — `$new_task_num` is referenced but never bound (this is the dropped-increment omission filed as task 402, not this record's target) |

Every one of the first six reads `next_project_number` via a **separate `jq -r` process**,
before `state-write.sh` is ever invoked. `state-write.sh` (confirmed by reading it in full)
acquires the `specs/.scope-lock` mutex only inside itself (`acquire_mutex()`, called after
argument parsing and the `--dry-run` branch, immediately before staging), and applies the
caller's jq filter to the **live file at that moment**
(`jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE"`). The external `jq -r` read that
produced the bash variable passed in via `--arg`/`--argjson` happened *before* that mutex was
ever requested — so two concurrent callers can both read the same stale number, and the mutex
only serializes the order their writes land, not the values each one computed. This is exactly
the mechanism task 390's acceptance criteria record ("read next_project_number as 387, written
as 387 and 388, collided with 387/388/389 created by a concurrent writer... that write also
clobbering the other writer's own correct counter bump").

**`state-write.sh` has zero concept of `next_project_number`** (confirmed: `grep -n
next_project_number scripts/state-write.sh` returns nothing). It is a generic
jq-filter-under-mutex executor; it has no opinion about what any particular caller's filter
does. This means the fix-by-rebinding-inside-the-filter path (see Recommendations) requires no
change to `state-write.sh` at all for the six already-structured-as-"filter transforms the live
file" callers — only a change to what expression each filter uses for the allocated number
(`.next_project_number as $num | ...` instead of consuming an externally-bound `$num`/`--argjson
num`). Only a *new, dedicated* primitive (the second recommended layer) requires touching
`state-write.sh` itself.

**The detection gap, confirmed directly against `scripts/validate-state.sh` (1482 lines)**:

- Base-mode Check 2 (`scripts/validate-state.sh:769-770ish`, the "required top-level fields"
  loop) tests only that `next_project_number` is *present* as a key — no value check.
- Check 6 tests `active_projects[].project_number` is a number — a per-entry type check, not a
  counter-vs-max comparison.
- Check D1 (`project_number uniqueness`, line ~1136) is the *only* duplicate check in the whole
  script, and it is gated entirely inside the `if [[ "$DEEP" == "true" ]]` block — a base-mode
  run (the mode every interactive call site in `commands/task.md` actually uses today, per its
  own Step 6.5 comment: "base mode — no `--deep`, so no git-history round trip on this
  interactive path") never runs it.
- No check anywhere — base, `--deep`, or `--archive` — compares `next_project_number` against
  `max(project_number)` over any population. Confirmed by reading every line matching
  `project_number` in the file (grep, ~80 matches): all of them either type-check, dedupe within
  one array, or build the dependency/parentage graph. None computes a max-vs-counter bound.

**The archive-aware reader idiom already exists and is reusable verbatim.** Check D3
(dependency-graph integrity, `--deep`-only) already builds a "known project numbers" set as
`active_projects[].project_number` **union** the sibling archive file's terminal arrays:

```bash
archive_file="$state_dir/archive/state.json"
jq -r '[(.archived_projects // [])[], (.abandoned_projects // [])[], (.completed_projects // [])[] | .project_number] | .[]' \
  "$archive_file" 2>/dev/null >> "$known_pnums_file" || true
```

This is the same union the dispatch's requirement 3 demands (`archived_projects` max 267 vs.
`completed_projects` max 392 in this repo's own archive — reading only one undercounts). A new
counter-staleness check can reuse this exact pattern rather than inventing a second archive
reader — which is itself the duplication task 379 already existed to settle for the `--archive`
mode's own checks (confirmed: `--archive` mode's Check A1–A6 are a parallel check set that
*replaces* Checks 2–11 for validating `specs/archive/state.json` itself as the *primary* file;
it is a different concern from this task's need to read the archive as a *secondary* reference
while validating the *live* file — the same distinction Check D3 already draws).

**Task 379 dependency status — already resolved, not pending.** Reading
`specs/379_validate_state_cannot_validate_archive_state/.return-meta.json` and the file itself
confirms `--archive` mode (Checks A1–A6, the `state-write.sh`/`validate-state.sh` header
documentation lines 40–53 and 183–207) is **already live** in
`agent-system/extensions/core/scripts/validate-state.sh` in this repository — status
`implemented`, both declared files (`validate-state.sh`, `test-validate-state.sh`) already
carry 379's changes. The footprint dependency (same two files) and the substantive one (archive
shape literacy) are both satisfied today; this task's plan does not need to wait on anything
further from 379.

**Where a new base-mode check would fit the script's existing structure.** The script already
has a clean seam for exactly this kind of check: Checks 1–11 run unconditionally in base mode
(always executed, before the `if [[ "$DEEP" == "true" ]]` block at line ~1133); `--deep` is
strictly additive (D1–D6). A new check numbered after 11 (or inserted as, say, "Check 12") that
(a) computes `max(active_projects[].project_number)`, (b) unions in the sibling archive file's
`archived_projects`/`completed_projects`/`abandoned_projects` maxima via the Check-D3 idiom
above, and (c) FAILs when `next_project_number <= that combined max` would run in base mode —
satisfying requirement 2 ("detectable before it is used") for every caller that runs
`validate-state.sh` at all, not only `--deep` callers. It needs no git-history round trip (unlike
D4/D5), so it carries none of the "skip with a warning when not in a git work tree" caveats
those checks have — it is a pure filesystem read, same cost class as Check D1.

### External Resources

Not applicable — no external library or framework dependency is involved; this is pure
in-repo bash/jq tooling.

## Decisions

- **Task 379 is confirmed already landed** in this repository (status `implemented`,
  `--archive` mode present in the live `validate-state.sh`). The dependency edge stays declared
  (it documents a real relationship and matches the footprint rule), but it imposes no actual
  wait at plan time.
- **The archive-aware "known project numbers" reader must reuse Check D3's existing idiom**
  (`$state_dir/archive/state.json`, union of `archived_projects`/`abandoned_projects`/
  `completed_projects`), not a new hand-rolled archive reader — this is the same duplication
  task 379 already exists to prevent (noted explicitly in the dispatch).
- **The new staleness check belongs in base mode, not `--deep`-only.** Requirement 2 explicitly
  requires pre-use detectability; gating it behind `--deep` (as Check D1 currently is for plain
  duplicates) would reproduce exactly the gap this task exists to close — a base-mode run (the
  mode `commands/task.md`'s own interactive path uses today) would still miss it.
- **A per-caller "rebind inside the filter" fix and a centralized allocation primitive are not
  redundant with each other** — see Recommendations for why both are being recommended rather
  than picking one.

## Recommendations

Recommend **two layers**, each closing a distinct failure mode the other does not:

**Layer 1 — archive-aware base-mode detection in `validate-state.sh` (closes requirements 2, 3,
4).** Add a new base-mode check comparing `next_project_number` against
`max(active_projects[].project_number, archive's archived_projects/completed_projects/
abandoned_projects[].project_number)`, FAIL-level (this is exactly the shape of invariant that
belongs at FAIL from day one — unlike Checks 3/4/8/9/10's advisory-first rollout, there is no
"live measurement found N violations" reason to start this one as WARN; a stale counter is
unconditionally wrong, not a stylistic nit). Reuse Check D3's archive-sibling-reading lines
verbatim rather than re-deriving them. Cover it in
`scripts/tests/test-validate-state.sh` per requirement 4, with at minimum: (a) a fixture where
the live file's counter is correct, asserting PASS; (b) a fixture matching the 2026-10-13
incident shape (counter equal to an in-use active number), asserting FAIL; (c) a fixture
matching requirement 3's own cited numbers (archive's true max in `completed_projects`,
*not* in `abandoned_projects`/`archived_projects`), asserting the check reads the right array —
this directly tests the exact bug "two readers independently made twice" per the dispatch.

**Layer 2 — a mutex-scoped allocation primitive in `state-write.sh` (closes requirement 1 as a
structural invariant, not a per-caller discipline).** The six existing hand-rolled call sites
could each close their own race today by changing their jq filter to derive the allocated
number from `.next_project_number as $num` *inside* the filter `state-write.sh` already runs
under the mutex, instead of from an externally pre-read bash variable passed in via
`--arg`/`--argjson`. That is a real, low-risk improvement and plan time should decide whether to
land it at each site. But it does not, by itself, make "an allocation must not be able to
silently produce a duplicate" an invariant of the *system* — it is an invariant of "every
caller remembered to write their filter this way," which is the identical class of failure that
produced the dropped-increment in Step 4c (a caller that forgot a step nothing enforced). The
dispatch's own causal diagnosis (point 4) names this directly: allocation is unserialized by
construction because `state-write.sh`, the one mutex-guarded writer, "has no concept of
`next_project_number` at all." The stronger fix is to give it one: a new opt-in flag (e.g.
`--allocate-into NAME`, naming is a plan-time decision) that, when passed, prefixes the caller's
`EFFECTIVE_FILTER` with a binding equivalent to `.next_project_number as $NAME` evaluated against
the live file at transform time (inside the existing mutex-protected `jq ... "$STATE_FILE"`
call), so the allocated number is *never* computed anywhere outside the critical section, for any
caller present or future — closing the race by construction rather than by every caller's
discipline. This does not require `state-write.sh` to itself derive the number from `max(...)`
over the archive (that would duplicate Layer 1's archive-reading logic inside the hot write
path); it only needs to read the *live counter value* from the file it is already about to
transform, which is sufficient to eliminate the specific race both recorded incidents exhibit
(stale pre-read vs. a concurrent writer's advance).

**Why not fold to one layer**: Layer 1 alone detects staleness but does not prevent a race
between two *correctly-behaving* concurrent callers reading the same (even momentarily correct)
counter in the same instant — detection-after-the-fact was exactly the posture requirement 2
explicitly rules out. Layer 2 alone prevents the race for any caller using the new primitive,
but provides no backstop against a hand-edited `state.json`, a caller that never migrates to the
new primitive, or a counter that goes stale for a reason unrelated to the race (e.g. a manual
edit, or a future writer class not yet imagined) — and it provides nothing for the archive-aware
bound requirement 3 demands, which is squarely a read-time property of the *validator*, not the
*writer*. The two layers are complementary, not overlapping: Layer 1 is the backstop that fires
regardless of how a staleness arose; Layer 2 is the fix for the one specific, already-twice-
recorded cause (an unserialized read-then-write race).

**Scope implication for plan time**: adopting Layer 2 as described does **not** require
touching any of the seven per-caller files listed as "conditional scope" in the dispatch — the
new `state-write.sh` flag is opt-in, and migrating existing callers to use it is optional
follow-up (explicitly flagged in the dispatch as task 402's problem for Step 4c specifically,
and otherwise not mandated by this record). If plan time instead chooses to rewrite the
per-caller filters directly (the "rebind inside the filter" variant, requiring no new
`state-write.sh` flag at all), that *does* trigger the conditional-scope file list, and the
already-identified conflicts with tasks 391 and 313 apply as the dispatch describes.

## Risks & Mitigations

- **Risk**: a new base-mode FAIL-level check could break an existing caller that currently
  treats a nonzero `validate-state.sh` base-mode exit as non-fatal advisory (e.g.
  `commands/task.md`'s Step 6.5, which already greps only `file_scope` lines and explicitly
  states "a nonzero exit code ... MUST NOT stop Steps 7 and 8"). **Mitigation**: that call site
  already tolerates a nonzero exit by design; a new FAIL does not change its behavior. Other
  callers (`scripts/verify-deploy.sh` gate 10, `scripts/tests/test-init-specs.sh`) should be
  checked at plan time for whether they treat base-mode exit 0 as a hard gate — if so, this is a
  deliberate, desired tightening (the whole point of requirement 2), not a regression to avoid.
- **Risk**: adding `--allocate-into` to `state-write.sh` without migrating any caller to use it
  yields a layer that exists but prevents nothing yet. **Mitigation**: scope this task's
  Layer 2 deliverable as "the primitive exists and is tested," with caller migration explicitly
  deferred — the dispatch's own "NOT IN SCOPE" section and task 402's dependency edge already
  establish that at least one caller (Step 4c) is a separate record's job to migrate.
- **Risk**: the new validator check could false-positive against a legitimately-reserved gap
  (e.g. a vault operation mid-flight). **Mitigation**: `commands/todo.md`'s vault-operation
  section (next_project_number > 1000 trigger) resets the counter and renumbers in one state
  write; confirm at plan time that no intermediate, committed state during that operation
  transiently has a lower-than-max counter. Not confirmed in this research pass — flag as a
  plan-time verification item, not a blocking finding.

## Context Extension Recommendations

- **Topic**: allocation-under-mutex convention for `next_project_number`.
- **Gap**: `context/patterns/task-lock.md`'s "State-Write Convention" section documents the
  single-mutex-across-targets rationale in detail but says nothing about `next_project_number`
  allocation specifically (confirmed: zero matches for `next_project_number`/`allocat` in that
  file). Once this task's plan lands a chosen mechanism, that file (or a new sibling pattern
  doc) should record the convention so an eighth future caller does not reinvent the
  read-then-write race.
- **Recommendation**: extend `context/patterns/task-lock.md` with a short "Allocating
  next_project_number" subsection once the plan settles the mechanism, rather than leaving the
  convention implicit in each call site's own prose comments.

## Appendix

- Search queries/commands used: `grep -n next_project_number -r agent-system/extensions/core`;
  targeted reads of `scripts/state-write.sh` (full file), `scripts/validate-state.sh` (header
  block + Check D1/D3/D6 bodies + archive-mode header), `scripts/tests/test-validate-state.sh`
  (header), `context/schemas/state-schema.json` (next_project_number field), `.return-meta.json`
  for tasks 379/390/402, `context/patterns/task-lock.md`.
- Key files read in full or substantially: `agent-system/extensions/core/scripts/state-write.sh`
  (498 lines, read in full); `agent-system/extensions/core/scripts/validate-state.sh` (header and
  structural comments, lines 1–260, plus Check D1/D3/D6 bodies).
