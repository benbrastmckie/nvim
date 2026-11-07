# Research Report: Task #409

**Task**: 409 - Advise on dirty file scope at admission
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: medium (3 script surfaces + 2 regression suites + doc convergence)
**Dependencies**: ordered after the artifact-round record in the same batch (shared-file edge on
orchestrate-cycle-plan.sh / orchestrate-build-dispatch.sh); see the dispatch's Territory Edges.
**Sources/Inputs**: codebase read of agent-system/extensions/core/scripts/{orchestrate-batch-admit.sh,
orchestrate-cycle-plan.sh, orchestrate-predispatch-review.sh, git-snapshot.sh,
lib/file-scope-overlap.sh, test-conflict-predicate.sh, test-four-tier-conflict.sh,
tests/test-orchestrate-predispatch-review.sh}, docs/architecture/batch-admit-schema.md,
context/patterns/{batch-orchestration-guardrails.md, orchestrate-batch-results-template.md}
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The three named surfaces already share one converged, additive-advisory pattern (
  `idle_overlap_advisory`, `absent_scope_advisory`, `cross_session_hazard`): computed once,
  carried verbatim through a bash ledger, rendered as its own lettered Class in the pre-dispatch
  review. The new dirty-worktree advisory fits this pattern with no structural surprises.
- The containment check needs **no new jq logic**: `scopes_overlap_first()`, already spliced
  into `orchestrate-batch-admit.sh` from `lib/file-scope-overlap.sh`, correctly answers "does any
  dirty path fall inside this candidate's own file_scope" when the dirty-path list is passed as
  its `other_scope` argument (exact match or directory-prefix-ancestor in either direction).
- `git-snapshot.sh` needs **no code change**. It is cited in the dispatch only as the design
  precedent for `git diff --name-only HEAD` already covering staged+unstaged changes in one call
  (lines ~403-407); there is no extractable shared function there to call into, so the natural
  move is one new, directly-qualified `git -C "$PROJECT_ROOT" diff --name-only HEAD` call inside
  `orchestrate-batch-admit.sh` itself, not a refactor of `git-snapshot.sh`.
- The next unused rendering letter in `orchestrate-predispatch-review.sh` is **Class J** (A
  through I are taken).
- Both named regression suites (`test-conflict-predicate.sh`, `test-four-tier-conflict.sh`) run
  the real `orchestrate-batch-admit.sh` inside an isolated `TMPROOT` that is **never actually a
  git repository** today (no `git init` in either suite). Exercising the real dirty-worktree path
  requires extending both fixture builders with `git init` + a baseline commit + an uncommitted
  edit — a new fixture capability, not just new assertions. This is the one real gap found.
- Recommended field name: `dirty_scope_advisory` (adjective_noun_advisory, matching the existing
  two names). Not established anywhere in the codebase today — confirm at planning time.

## Context & Scope

Researched how to add a fourth additive, non-blocking advisory to the admission-verdict schema
`orchestrate-batch-admit.sh` already produces, surfacing when a dispatch candidate's own declared
`file_scope` intersects the CURRENT dirty working tree (uncommitted tracked changes) at admission
time — so an operator can commit a foreign hunk separately before an implement dispatch's
whole-file staging sweeps it into that task's own commit (the originating incident: a one-line
uncommitted edit outside the task's own region got staged and committed as part of a `Phase 1`
commit, named in that commit's body, because `git add -p` is unavailable in this environment).

Scope of this research: locate the exact code shape of the three sibling advisories across their
three surfaces, determine the correct containment predicate and its placement, confirm whether
`git-snapshot.sh` needs changing, and assess what the two named regression suites would need to
add real presence/absence coverage. This is a research dispatch; no code was written or planned
in a phased sequence — that is the next (`/plan`) dispatch's job.

## Findings

### Codebase Patterns

**The converged three-advisory shape** (`orchestrate-batch-admit.sh`):

- `idle_overlap_advisory` — present on any post-collision-scan verdict (admit, `session_active`
  defer, or `file_scope_collision` defer) when the collision scan found a suppressed cross-batch
  overlap against a provably idle task. Computed inside the collision-scan branch only
  (`orchestrate-batch-admit.sh:959-980`); structurally absent on the three early-exit admit
  branches and both self-modifying branches, "none of which reach the collision scan"
  (`orchestrate-batch-admit.sh:195-205` header comment).
- `absent_scope_advisory` — present on EVERY verdict the absent-file_scope early-exit branch
  produces (admit or the `absent_file_scope` defer itself), carried "regardless of decision...
  purely informational" (`orchestrate-batch-admit.sh:204-212`, computed `:825-848`).
- `cross_session_hazard` — present ONLY on a self-modifying ADMIT verdict
  (`orchestrate-batch-admit.sh:860-879`), deliberately never on the self-modifying DEFER branch
  ("adding this field there would wrongly suggest the defer is caused by the session overlap").
  This is the one sibling advisory that is NOT universally merged — a useful negative precedent
  (see Recommendations).
- `whole_tree_claim` — present on EVERY verdict for a candidate whose own `file_scope` carries the
  reserved sentinel (`orchestrate-batch-admit.sh:881`), computed from `$c_scope` alone (no
  cross-task comparison) at the same point `$c_scope` is bound, and merged into both the
  self-modifying branches (`:910`, `:928`) AND the ordinary branch's admit/defer shapes further
  down. **This is the structural precedent the new advisory should follow**, not
  `cross_session_hazard`'s self-modifying-only scoping, because the new check — like
  `whole_tree_claim` — depends only on the candidate's own `file_scope`, never on a cross-task
  comparison, so it applies uniformly regardless of self-modifying status.

**The containment predicate already exists and needs no new jq def.**
`lib/file-scope-overlap.sh` exports `FILE_SCOPE_OVERLAP_JQ_DEFS` (spliced verbatim into
`orchestrate-batch-admit.sh`'s one `jq -n` program) containing `scopes_overlap_first(own_scope;
other_scope)`: for every pair across the two arrays, a hit on exact match OR either side being a
directory-prefix ancestor of the other, returning the first overlapping path from the "foreign"
side. Calling `scopes_overlap_first($c_scope; $dirty_paths)` — where `$dirty_paths` is the
invocation-wide list of concrete dirty tracked paths, passed in as the "foreign" scope — answers
exactly "is any dirty path contained in this candidate's own declared scope" with zero new jq
code, because a concrete file path trivially satisfies the same exact-match/directory-prefix
test a `path_covered_by_scope()` containment check would apply. The one accepted blind spot this
inherits: a **glob-shaped** `file_scope` entry (e.g. `lua/*.lua`) is invisible to
`scopes_overlap_first` by design (`is_glob_entry`/Class G already exists in
`orchestrate-predispatch-review.sh` to warn about this same blind spot elsewhere) — not a new gap
introduced by this feature, and not something this task needs to close.

The separate bash-only `path_covered_by_scope()` (also in `lib/file-scope-overlap.sh`,
`:190-233`) additionally matches globs, but its own header comment states it has "exactly one
string-comparison consumer" (`git-snapshot.sh`'s per-dirty-path loop) and is pure bash by design
because its only caller doesn't need jq's array handling. Reusing it from
`orchestrate-batch-admit.sh` (a pure-jq, single-slurp architecture) would require either shelling
out per candidate (breaking the "one jq program, one state.json read" architecture the script's
own header commits to — `orchestrate-batch-admit.sh:715-723`) or transcribing a third copy of the
same algorithm. `scopes_overlap_first` is the better fit on every axis that matters here.

**`git-snapshot.sh` needs no code change.** Its dirty-tracked-paths computation
(`git-snapshot.sh:403-407`) is a single, undecorated `git diff --name-only HEAD 2>/dev/null` with
a comment explaining it already captures staged AND unstaged changes (staging copies to the
index; the working-tree file the diff reads stays modified either way) — directly resolving the
dispatch's "and/or `git diff --cached --name-only`" phrasing: **one call suffices, no second
`--cached` pass is needed.** This is inline script logic, not an extracted function — there is
nothing to "call into" from `orchestrate-batch-admit.sh`. The correct move is one new, directly
root-qualified `git -C "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null` call inside
`orchestrate-batch-admit.sh` (which already resolves `$PROJECT_ROOT` via `common_repo_root` at
`:565`), computed once per invocation (like `sessions_json`/`critical_expanded_json` already are,
`:700-709`) and passed into the jq program via a new `--argjson dirty_paths "$dirty_paths_json"`.
`git-snapshot.sh` remains unmodified and is cited correctly only as the DESIGN precedent, not an
edit target — resolving the dispatch's "possibly" qualifier on this surface in the negative.

**`orchestrate-batch-admit.sh` placement.** `($entry.file_scope) as $c_scope` is bound at
`:852`, immediately before `$sm_hit`/`$sm_flag` and before the branch that splits into
self-modifying vs. ordinary admission logic. `$whole_tree_claim_frag` is computed right after
this point (`:881-886`) for exactly this reason: it needs only `$c_scope`, so computing it once
there lets it be merged into every downstream verdict shape regardless of which branch is taken.
The new advisory fragment should be computed at this same point, using `$c_scope` and the new
`$dirty_paths` (bound once at the top of the jq program alongside `$own_sid`/`$sess_list`), then
merged (`+ $dirty_scope_frag`) into every verdict object the fold can produce — both
self-modifying admit shapes (`:901-909`, `:919-927`), and every shape in the ordinary branch
(`:973` admit, `:980-991` session_active defer, `:1003` whole-tree-claim admit, `:1009-1019`
whole-tree-claim defer, and the `file_scope_collision` defer further below). It should be
structurally absent, like `idle_overlap_advisory`/`whole_tree_claim`, on the three early-exit
branches (unknown task / terminal status / absent `file_scope`) where `$c_scope` either doesn't
exist or is empty by construction.

**Field shape — one notable divergence from the sibling advisories' convention.** The dispatch's
own DESIRED BEHAVIOUR language says "emit an ADVISORY **naming the intersecting paths**" (plural).
`idle_overlap_advisory`/`cross_session_hazard` both carry a single `overlapping_path` (first
match only), matching their one-colliding-task-at-a-time shape. The new advisory is checking the
candidate's OWN scope against a set of dirty paths with no natural "one worst offender" — an
operator deciding what to commit separately needs the full list. Recommend a `dirty_paths` array
(every intersecting path, not first-match-only) inside the new object, departing deliberately from
the single-`overlapping_path` convention for this one field, with a `reason` string following the
existing machine-templated-sentence convention (naming the remedy: commit the listed path(s)
separately before this task's own commit sweeps them in).

**`orchestrate-cycle-plan.sh` ledger convention.** `idle_overlap_ledger`/`absent_scope_ledger`/
`cross_session_hazard_ledger` are each: (a) declared in the mt_state_file field-list header
comment (`:53-56`), (b) self-initialized via `//= []` (`:617-619`), and (c) captured inside the
per-row `while IFS= read -r row` loop (`:1907-1925`) via `jq -c 'if (.X != null) then .X else null
end'` then an `mt_set --argjson entry ... '.X_ledger += [$entry]'` call — "capture the advisory
regardless of the decision" is the loop's own stated convention (`:1913-1916`). A fourth
`dirty_scope_ledger` slots in identically.

**`orchestrate-predispatch-review.sh` rendering convention.** Classes used so far: A, B, C,
C-admitted, D, D-admitted, E, F, G, H, H-admitted, I — **J is the next free letter**. Class I
(cross_session_hazard) is the closest structural analog: a field that never changes `decision`,
so it gets ONE rendering block with no "-admitted"/deferred split (`:600-611` extraction,
`:849-868` rendering), unlike C/D/H which split into deferred+admitted pairs because their
underlying signal CAN also cause a defer. The new advisory should follow Class I's single-block
shape. Unlike Class E/I, it needs no `$session_id_explicit` gate (it depends on no session
registry input at all) — closer to Class C/D's unconditional availability. Each existing class's
"0 findings" line is written to avoid conflating "never tested" with "tested, no hit" — Class J's
zero-count line should read along the lines of "0 findings (no candidate's file_scope intersects
the currently dirty working tree)."

### External Resources

Not applicable — this is a pure codebase-pattern-convergence task; no external library or API is
involved.

### Regression Coverage — the one real gap

`test-conflict-predicate.sh` and `test-four-tier-conflict.sh` both construct an isolated
`$TMPROOT` by copying the real scripts byte-for-byte and writing a fixture `specs/state.json` (and
`specs/.sessions/` entries), satisfying `deploy-root-guard.sh`'s directory-shape check. **Neither
suite ever runs `git init` inside `$TMPROOT`.** `common_repo_root()` (sourced from `lib/common.sh`)
is pure path arithmetic — it walks up a fixed number of directory levels from the script's own
location and does not call `git rev-parse` — so `orchestrate-batch-admit.sh`'s existing
`PROJECT_ROOT` resolution works today inside a non-git `$TMPROOT` without erroring. A new `git -C
"$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null` call against that same non-git `$TMPROOT` would
simply fail silently (git exits non-zero outside a repository) and degrade to an empty
`dirty_paths` list — safe (no advisory ever spuriously fires in the existing cases 2.5/2.6/12),
but it also means **neither suite can exercise a true positive today** without a fixture change.

To add the parallel presence/absence cases the dispatch asks for, both suites' `$TMPROOT`
builders need: `git init` inside `$TMPROOT` (or inside whatever subpath becomes the git top-level
relative to the copied `.claude/scripts/`), an initial commit establishing a baseline tracked
file at a path the test's candidate declares in its `file_scope`, and then — for the presence
case only — a real, uncommitted edit to that same file before invoking
`orchestrate-batch-admit.sh`. The absence case needs no edit (clean tree) or an edit to a path
outside the candidate's `file_scope`. This is a one-time fixture-builder extension reusable by
both suites' new cases, not a per-case cost.

`tests/test-orchestrate-predispatch-review.sh` needs no such fixture change: it feeds synthetic
NDJSON verdict rows directly to the composer script (see its existing Scenario 2 fixture at
`:148-154`, a literal `{"decision":"admit", ..., "idle_overlap_advisory": {...}}` row) — a new
Scenario fixture carrying a literal `dirty_scope_advisory` object is sufficient to assert Class J
renders it as a non-"0 findings" row.

## Decisions

- Reuse `scopes_overlap_first()` from `lib/file-scope-overlap.sh`'s already-spliced
  `FILE_SCOPE_OVERLAP_JQ_DEFS` for the containment check — no new jq def is needed.
- `git-snapshot.sh` is NOT an edit target; it is cited only as the design precedent for the
  dirty-tracked-paths command, which should be duplicated (one line, `git -C "$PROJECT_ROOT" diff
  --name-only HEAD 2>/dev/null`) directly inside `orchestrate-batch-admit.sh` rather than shared
  via a new library function.
- A second `--cached` pass is not needed — `git diff --name-only HEAD` already reports both
  staged and unstaged changes relative to `HEAD`.
- Follow `whole_tree_claim`'s universal-merge placement (computed once from `$c_scope` alone,
  merged into every verdict branch), not `cross_session_hazard`'s self-modifying-only scoping.
- Carry the FULL list of intersecting paths (`dirty_paths: [...]`) in the new advisory object,
  departing from the sibling advisories' single-`overlapping_path` convention, because the
  dispatch's own desired behaviour asks for "the intersecting paths" (plural) and there is no
  natural single "colliding task" to pick a first match against.
- Render the new advisory as Class J in `orchestrate-predispatch-review.sh` (next free letter),
  in Class I's single-block (non-deferred/admitted-split) style, with no session-registry gate.
- Both named test suites need a new `git init` + baseline-commit + uncommitted-edit fixture
  capability in their `$TMPROOT` builders before the presence/absence cases the dispatch asks for
  can be added meaningfully.

## Recommendations

1. **Field name**: `dirty_scope_advisory`, confirmed at plan time (no prior art in the codebase
   to converge on; this is new coinage following the existing `adjective_noun_advisory` shape).
2. **Bash layer** (`orchestrate-batch-admit.sh`): add one `dirty_paths_json=$(git -C
   "$PROJECT_ROOT" diff --name-only HEAD 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length
   > 0))')` (default `[]` on any failure, mirroring `sessions_json`'s degrade-safe pattern at
   `:700-709`), passed to the `jq -n` call as `--argjson dirty_paths "$dirty_paths_json"`.
3. **jq layer**: bind `$dirty_paths as $dirty` alongside the other invocation-level bindings
   (near `$own_sid`/`$sess_list`, `:748-751`); compute `$dirty_scope_frag` immediately after
   `($entry.file_scope) as $c_scope` is bound (`:852`), using
   `([$dirty[] | select(scopes_overlap_first($c_scope; [.]) != null)])` (or an equivalent
   single-pass array-intersection form) to collect every intersecting path, not just the first;
   merge `+ $dirty_scope_frag` into every verdict shape in both the self-modifying and ordinary
   branches, exactly where `+ $whole_tree_claim_frag` already appears.
4. **`orchestrate-cycle-plan.sh`**: add `dirty_scope_ledger` to the mt_state_file field list
   comment (`:53-56`) and its `//= []` initializer (`:617-619`); add a capture block mirroring
   `absent_adv`/`cross_sess_hazard` (`:1913-1926`) inside the existing per-row loop.
5. **`orchestrate-predispatch-review.sh`**: add a Class J extraction (`select($v.dirty_scope_advisory
   != null)`, no `decision`/`self_modifying` filter) alongside Class I's block (`:600-611`), and a
   `-- Class J: ... --` rendering section mirroring Class I's single-block style (`:849-868`),
   including its own accurate "0 findings" line.
6. **Regression coverage**: extend `test-conflict-predicate.sh` and `test-four-tier-conflict.sh`'s
   `$TMPROOT` builders with `git init` + baseline commit + (for the presence case) an uncommitted
   edit to an in-scope tracked file; add one presence case and one absence case to each, mirroring
   cases 2.5/2.6 and case 12's existing structure. Add a new Scenario fixture to
   `tests/test-orchestrate-predispatch-review.sh` carrying a literal `dirty_scope_advisory` object
   and assert the Class J rendering.
7. **Documentation convergence (not in the dispatch's SURFACES list — flag for plan
   confirmation)**: `docs/architecture/batch-admit-schema.md`'s Field Definitions table and
   Version History (a new row + worked example, matching the existing three), and
   `context/patterns/batch-orchestration-guardrails.md`'s Blocking-vs-Advisory classification
   table (a new row), and `context/patterns/orchestrate-batch-results-template.md` (a new
   "Admitted (dirty scope advisory)" rendering-style section). These three docs track every
   existing advisory precisely; leaving the new one undocumented there would be an inconsistency
   with this codebase's own established convergence discipline, but they were not named in the
   dispatch's SURFACES list, so confirm scope at plan time rather than assuming inclusion.
8. **Explicitly out of scope** (per the dispatch's own DESIRED BEHAVIOUR wording, which names only
   `git diff --name-only HEAD`/`--cached`): untracked (new, not-yet-`git add`-ed) files. The
   observed incident was an edit to an already-tracked file; `git-snapshot.sh`'s separate
   WARN-only untracked-path handling (`DIRTY_UNTRACKED`, `:434+`) is a different, already-solved
   concern this task should not fold in.

## Risks & Mitigations

- **Risk**: computing `git diff --name-only HEAD` adds one more subprocess to every
  `orchestrate-batch-admit.sh` invocation (one per admission cycle, not per candidate — cost is
  O(1), not O(candidates)). **Mitigation**: negligible; the script already shells out for
  `sessions_json` (`task-lock.sh session-list`) and `critical_expanded_json` per invocation.
- **Risk**: a non-git `$PROJECT_ROOT` (the test-suite `$TMPROOT`s today) makes `git diff` fail.
  **Mitigation**: `2>/dev/null` plus a default-`[]` fallback, identical to the existing
  `sessions_json`/`critical_expanded_json` degrade-safe pattern; the advisory simply never fires
  in that degraded case rather than erroring the script — correct, since "no advisory" is the
  conservative/safe default for an informational-only field.
- **Risk**: scope creep into untracked-file detection or `--cached`-specific handling, both
  already solved elsewhere (`git-snapshot.sh`) for a different purpose (reverting, not advising).
  **Mitigation**: explicitly scoped out above (Recommendation 8); re-use `git-snapshot.sh` as a
  read-only precedent, never modify it.
- **Risk**: the two regression suites' fixture extension (git init + baseline commit) could leak
  stray `.git` state if `TMPROOT` cleanup is interrupted. **Mitigation**: both suites already use
  `mktemp -d` + a `trap cleanup EXIT` removing the whole `$TMPROOT` tree (`rm -rf`), which covers
  a nested `.git` directory identically to any other file under it — no new cleanup logic needed.

## Context Extension Recommendations

- **Topic**: a single catalog of "additive, decision-never-changing advisory fields on an
  admission verdict" (naming convention, placement convention, rendering-letter allocation).
- **Gap**: this knowledge is currently scattered across three scripts' own header comments plus
  `docs/architecture/batch-admit-schema.md`'s Field Definitions table and
  `context/patterns/batch-orchestration-guardrails.md`'s classification table — correct and
  cross-referenced, but there is no single page a future "add one more advisory" task can read
  first to get the full placement/naming/rendering-letter checklist in one place (this report
  reconstructs that checklist from four separate reads).
- **Recommendation**: after this task lands, consider a short
  `context/patterns/admission-advisory-checklist.md` (or an addendum to
  `batch-orchestration-guardrails.md`) distilling the five-surface checklist this research
  reconstructed (bash-layer input, jq-layer computation+placement, ledger capture, rendering
  class+letter, regression-fixture shape) so the next advisory field is a lookup, not a four-file
  archaeology exercise.

## Appendix

- Search queries / greps used: `idle_overlap_advisory` occurrences across `scripts/`;
  `git diff\|git status` in `orchestrate-batch-admit.sh`; `path_covered_by_scope` cross-references;
  `idle_overlap_ledger\|absent_scope_ledger\|cross_session_hazard_ledger` in
  `orchestrate-cycle-plan.sh`; `class: "` enumeration in `orchestrate-predispatch-review.sh`;
  `git init\|git -C\|mktemp -d` in both named test suites; `dirty_scope\|uncommitted.*advisory` to
  confirm no prior naming exists.
- Key files read in full or in relevant part: `orchestrate-batch-admit.sh` (header field-list
  comment, the `$c_scope`/self-modifying/ordinary branch fold, the jq invocation site),
  `orchestrate-cycle-plan.sh` (mt_state_file field list, ledger initializers, per-row ledger
  capture loop), `orchestrate-predispatch-review.sh` (Class extraction block, Class C/D/H/I
  rendering sections), `git-snapshot.sh` (dirty-tracked-paths computation and its own
  cross-reference to the canonical containment predicate), `lib/file-scope-overlap.sh`
  (`scopes_overlap_first`, `path_covered_by_scope`, `self_mod_match`, `session_contention`),
  `test-conflict-predicate.sh` and `test-four-tier-conflict.sh` (TMPROOT fixture construction),
  `tests/test-orchestrate-predispatch-review.sh` (synthetic-NDJSON fixture convention),
  `docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`,
  `context/patterns/orchestrate-batch-results-template.md`.
