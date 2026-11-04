# Research Report: Task #387

**Task**: 387 - Whole-tree regeneration scope claim (Part A) + plan-cache force-phases bypass (Part B)
**Started**: 2026-11-04
**Completed**: 2026-11-04
**Effort**: medium (two independent design decisions in one investigated root area)
**Dependencies**: None
**Sources/Inputs**:
  - Codebase: `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
    `orchestrate-cycle-plan.sh`, `orchestrate-cycle-postflight.sh`, `lib/file-scope-overlap.sh`,
    `plan-file-scope-harvest.sh`, `deploy-headless.sh`, `context/patterns/file-footprint-overlap.md`,
    `context/patterns/batch-orchestration-guardrails.md`, `context/formats/plan-format.md`,
    `docs/architecture/orchestrate-state-machine.md`, `skills/skill-orchestrate/SKILL.md`,
    `context/reference/orchestrator-critical-paths.json`
  - Historical evidence: `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/issues.jsonl`,
    `specs/archive/372_conclusion_stage_report_block_and_caller_split/issues.jsonl`,
    `specs/archive/372_conclusion_stage_report_block_and_caller_split/handoffs/phase-4-handoff-20261010T010324Z.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Part A confirmed live, not hypothetical.** The task 372 Phase-4 handoff and both tasks'
  `issues.jsonl` entries corroborate the dispatch's narrative exactly: `deploy-headless.sh`
  regenerates the deployed tree from **current filesystem state** (not from a committed
  snapshot), so it reads uncommitted sibling edits regardless of `file_scope`. No existing
  admission input sees this, because the claim is over the **source store** (`agent-system/**`,
  read unconditionally) and the **deployed targets** (`.claude/`, `.opencode/`, written
  unconditionally) — a scope no single task's `file_scope` entry expresses.
- **A cheap, already-wired integration point exists and should be preferred over new
  admission-gate logic**: `plan-file-scope-harvest.sh` already unions every phase's `Files to
  modify` field into `file_scope` at plan-postflight time (confirmed callers:
  `skill-base.sh`, `orchestrator-postflight.sh`, `reconcile-task-status.sh`,
  `skill-reviser/SKILL.md`). A phase that invokes whole-tree regeneration can declare a wide
  sentinel scope (the source-store root, e.g. `agent-system/`) in its own `Files to modify`
  field, and the EXISTING `file_scope_collision` machinery in `orchestrate-batch-admit.sh`
  (directory-prefix overlap, already covering every task whose `file_scope` lives under
  `agent-system/extensions/...`) serializes it with **zero new admission-gate code**. This
  resolves ACCEPTANCE (c)/(d) by construction (no new branch touched) and gives a documented
  justification for reusing `file_scope_collision` rather than minting a new `defer_reason`
  (ACCEPTANCE (b)'s "or a documented justification for reusing it" clause).
- **A deploy-level mutex already exists, and it is explicitly fail-open/non-blocking**:
  `deploy-headless.sh` lines ~266-307 already implement a `specs/.deploy-lock/` mkdir-mutex with
  stale-reclaim, but on contention it WARNS and proceeds unserialized — Option (3) in the
  dispatch is already half-built, as a backstop, not a remedy. It would need to become blocking
  (or at minimum visible to admission) to close the gap by itself, and even then would not
  prevent the wasted co-dispatch wave or the out-of-scope Phase-2 doc-lint failure (ADDRESSED
  explicitly below).
- **Part B's mechanical lead is CONFIRMED, not merely plausible.** `orchestrate-cycle-plan.sh`
  line ~1478-1481 shows the aux-dispatch path DOES mint and advance `dispatch_seq_counter` before
  a cache write that only requires `>=1 dispatch OR >=1 aux_dispatch row` (line 754-755).
  `skills/skill-orchestrate/SKILL.md` line 185 states explicitly: "an `aux_dispatch[]` row never
  reaches Move 3 [`orchestrate-cycle-postflight.sh`] or contributes to `failed_tasks`" — and
  `plan_cache` is cleared in exactly one place, inside that same Move 3 script (line 2136). So a
  composition that charges only via an aux_dispatch row caches at a `dispatch_seq_counter` value
  nothing will ever advance past, making it replayable indefinitely — exactly the observed defect
  (`--force-phases implement 372` silently replayed a stale cached plan).
- **Recommended Part B fix is narrower than "key in --force-phases"**: tighten the cache-write
  guard to require `>=1` real `dispatch[]` row (drop the `OR >=1 aux_dispatch row` disjunct).
  This closes the whole defect class (any invocation difference, not just `--force-phases`,
  silently replays after an aux-only cycle) with a one-line change, no new state field, and no
  cache-key hashing. Folding the canonicalized `--force-phases` value into the cache key is a
  reasonable belt-and-suspenders addition but treats a symptom, not the root cause, and the
  dispatch's own candidate list already offers the guard-tightening option implicitly under
  "ensure every cache-writing path has a guaranteed clearing counterpart."
- **Adjacency verdict: keep Parts A and B batched.** They touch one shared file
  (`orchestrate-cycle-plan.sh`) at disjoint line ranges (admission/phase-map section near
  line ~1830-1945 for A; the plan-cache read/write sections near line ~625-760 for B) and no
  shared lines in `orchestrate-batch-admit.sh` or `lib/file-scope-overlap.sh` at all (B never
  touches either). No split is warranted on territory grounds.

## Context & Scope

Researched two defects in the orchestrator's admission/cycle-composition machinery, both found
during one investigation (the conclusion stage of an earlier multi-task orchestration run), per
the dispatch's scope:
`extensions/core/scripts/orchestrate-batch-admit.sh`, `orchestrate-cycle-plan.sh`, and
(conditionally) `lib/file-scope-overlap.sh`, `context/patterns/file-footprint-overlap.md`,
`docs/architecture/orchestrate-state-machine.md`.

Part A: the batch admission gate's `file_scope`-overlap predicate cannot see a hazard that exists
only as a plan's own phase content (a whole-tree `deploy-headless.sh` invocation), not as any
task's declared `file_scope` — demonstrated live by tasks 371/372 landing in the same
co-dispatched wave with disjoint declared scopes, yet colliding at Phase 4/Phase 2 because both
plans ended in a redeploy phase.

Part B: the in-session plan-cache replay (keyed solely on `dispatch_seq_counter`) can become
permanently stale when a cycle's only charge is an `aux_dispatch[]` row, because aux dispatches
never run `orchestrate-cycle-postflight.sh` (the sole place `plan_cache` is cleared) — defeating
`--force-phases` as a human override lever.

## Findings

### Codebase Patterns

**Part A — the three relevant mechanisms and their actual coverage:**

1. `orchestrate-batch-admit.sh`'s collision scan (`file_scope_collision`) compares each
   candidate's declared `file_scope` against every other non-terminal task's declared
   `file_scope`, via `scopes_overlap_first()` in `lib/file-scope-overlap.sh`
   (exact match, or either side a directory-prefix ancestor of the other — see
   `context/patterns/file-footprint-overlap.md`). This is a pure, read-only, state.json-only
   predicate; it never reads a plan file's content.
2. The `self_modifying` branch (same script) tests a candidate's OWN `file_scope` against a
   fixed, declared list in `context/reference/orchestrator-critical-paths.json` — a list of
   specific orchestrator-machinery FILES (`skills/skill-orchestrate/SKILL.md`,
   `scripts/task-lock.sh`, etc.), not a "regenerates everything" sentinel. A task whose
   `file_scope` legitimately sits outside that list (e.g. an unrelated skill's `SKILL.md`) but
   whose plan ends in a full redeploy is invisible to this branch by construction — exactly the
   gap the dispatch names ("does not cover it... keys on the candidate's OWN declared
   `file_scope` naming a path on a fixed declared critical-path list").
3. The **inter-cycle redeploy checkpoint** inside `orchestrate-cycle-plan.sh` (documented
   exhaustively in `context/patterns/batch-orchestration-guardrails.md`'s "The Inter-Cycle
   Redeploy Checkpoint" section) is a DIFFERENT mechanism from the admission gate: it fires
   *after* a cycle's dispatches return, comparing that cycle's own `cycle_modified_files` against
   the critical-paths expansion, and (on a hit) runs `deploy-headless.sh` + `verify-deploy.sh`
   itself, under the orchestrator's own control, with a baseline-comparison failure contract.
   This is NOT what tasks 371/372 hit: their redeploy was each task's OWN plan-authored Phase 4
   step, invoked from inside an **implementing agent's** dispatch, not from this checkpoint. The
   checkpoint's own "Considered and found ALREADY SATISFIED" analysis proves there is no
   cross-sibling race *for the checkpoint itself* (dispatch is cycle-synchronous, commits land
   before the checkpoint runs) — but that finding is scoped to the checkpoint's own invocation of
   `deploy-headless.sh`, not to a PLAN PHASE's own, separately-authored invocation of the same
   script. The two call sites are architecturally distinct and this finding does not cover the
   Part-A hazard.
4. `deploy-headless.sh` itself already has a **fail-open deploy mutex**
   (`specs/.deploy-lock/`, lines ~266-307): `mkdir` as the atomic-on-creation primitive, a
   stale-reclaim threshold, and on contention it prints a `WARNING` and "proceeds unserialized
   (fail-open)" — it never blocks. This is Option (3) from the dispatch, already implemented as a
   backstop, but explicitly documented as non-blocking; promoting it to blocking would need a new
   decision (and would still not explain the Phase-2 out-of-scope doc-lint failure, which happened
   *before* any redeploy ran — see below).
5. **`plan-file-scope-harvest.sh`** (confirmed live callers: `skill-base.sh`,
   `orchestrator-postflight.sh`, `reconcile-task-status.sh`, `skill-reviser/SKILL.md`,
   `backfill-file-scope.sh`) already parses every phase's `**Files to modify**:` field from a
   plan artifact and unions the result into the task's `file_scope` in `state.json` — but it does
   so ONCE, at plan-creation/revision postflight time, never inside the admission hot path. This
   is the existing, already-tested machinery that already turns "something stated in a plan's
   phase content" into "a fact visible to `file_scope`-based admission," for the unrelated
   purpose of ordinary per-phase file lists.

**Live evidence for the observed consequences** (verified directly in the archived task
directories, not merely cited):
- `specs/archive/372_.../issues.jsonl` entry `iss_1791594146426_x2i4ct` (severity `blocking`):
  "`deploy-headless.sh` regenerates the whole deployed tree from filesystem state, which would
  deploy 371's in-progress, unverified, uncommitted edit."
- `specs/archive/372_.../handoffs/phase-4-handoff-20261010T010324Z.md`: the implementing agent
  caught this only by reading `git log`/`git status` live at Phase-4 entry — "there was no gate,
  no warning" is accurate; the agent self-blocked ad hoc.
- `iss_1791593439801_hh8mKq` (severity `minor`, Phase 2): a `verify-deploy.sh --only-gate 3,4`
  doc-lint failure on two files OUTSIDE task 372's declared scope, attributed to task 371's
  already-committed-but-not-yet-redeployed state. This is a **stale-deploy READ hazard** distinct
  from the Phase-4 concurrent-WRITE hazard — the deployed tree lagging the source store causes a
  doc-lint check (reading the deployed copy) to see drift that has nothing to do with the
  candidate's own edits. Both hazards share one root cause (the deployed tree's regeneration is
  an all-or-nothing operation over a scope no task declares) but are observationally different:
  one is "my redeploy would clobber your uncommitted work," the other is "your committed-but-
  undeployed work makes my gate run fail on files I never touched." A whole-tree-claim admission
  fix (serializing dispatch) addresses the first directly; it also addresses the second as a side
  effect, because serializing the two tasks means 371's redeploy phase (or the checkpoint) lands
  before 372's Phase 2 gate run ever sees the drift — but only if the *ordering*, not merely
  mutual exclusion, is right (see Decisions below).
- `iss_1791598089947_3K8mO2` (severity `costly`, task 371): "postflight completion write was
  refused by the completion-deploy gate (exit 6): the deployed `.claude/` tree was stale... /
  Deferred to the next cycle's Inter-Cycle Redeploy Checkpoint." This confirms the checkpoint DID
  eventually catch and correct the staleness — at a one-cycle cost — corroborating that the
  checkpoint mechanism and the admission-time gap are two different layers of the same system,
  not the same bug twice.

**Part B — confirmed mechanical chain:**

- `orchestrate-cycle-plan.sh` line ~754-757: `plan_cache` is written whenever
  `[ "${#out_dispatch_rows[@]}" -gt 0 ] || [ "${#out_aux_dispatch_rows[@]}" -gt 0 ]`, keyed on
  `dispatch_seq_counter` **after** this composition (every row-charging site has already
  minted/advanced it by this point).
- Line ~1478-1481 (aux-dispatch build path): `aux_dispatch_seq=$(mt_get '(.dispatch_seq_counter
  // 0) + 1')` followed by `mt_set --argjson seq "$aux_dispatch_seq" '.dispatch_seq_counter =
  $seq'` — confirms the aux path mints and commits a new counter value, exactly as the dispatch's
  "MECHANICAL LEAD" paragraph predicted.
- `orchestrate-cycle-postflight.sh` line ~2130-2137: the ONLY `del(.plan_cache)` site in the
  whole corpus (`grep -n plan_cache` across both scripts confirms this), gated inside
  `if is_live; then ... fi` under the multi-task-engine branch (`[ -z "$loop_guard_file" ]`).
- `skills/skill-orchestrate/SKILL.md` line 185: **"an `aux_dispatch[]` row never reaches Move 3
  [`orchestrate-cycle-postflight.sh`] or contributes to `failed_tasks`"** — stated as a `MUST
  NOT` for the orchestrator's own dispatch loop. This is a direct, textual confirmation (not an
  inference) that an aux-only cycle structurally cannot reach the one place that clears the
  cache.
- Net effect: a cycle whose only charge is an `aux_dispatch[]` row (e.g. a blocker-research aux
  dispatch for a `needs_human`-blocked task) writes a `plan_cache` entry keyed at the
  post-advance counter value, and nothing in the system will ever advance the counter past that
  value again until some OTHER, later cycle dispatches a real `dispatch[]` row for some task
  (which does reach postflight and clears the cache). Until then, **every** subsequent
  `orchestrate-cycle-plan.sh` invocation for that session — regardless of `--force-phases`,
  regardless of which task numbers are passed, regardless of any other flag — replays the stale
  cached plan verbatim. This generalizes the observed defect beyond `--force-phases` specifically:
  any invocation difference is silently swallowed by the replay, not just a forcing flag.

### External Resources

Not applicable — this is purely an internal orchestrator-machinery investigation; no external
library or documentation informs the fix. (No web research was performed; codebase and historical
task-artifact evidence fully ground both findings.)

## Decisions

- **Part A: reuse the existing `file_scope_collision` machinery via a declared wide-scope entry,
  harvested through the existing `plan-file-scope-harvest.sh` pipeline, rather than adding
  content-sniffing to the admission gate itself or minting a new `defer_reason`.** This is
  Option (2) from the dispatch ("a dedicated declaration a plan can carry... an explicit 'claims
  whole deployed tree' field or a reserved `file_scope` sentinel"), landed through the ALREADY-
  EXISTING `Files to modify` -> `file_scope` harvesting convention rather than a brand-new
  planner-agent field. Concretely: a plan phase whose steps invoke whole-tree regeneration
  declares, in its own `**Files to modify**:` field, a wide sentinel path covering the source
  store the regeneration reads from (e.g. `agent-system/` — the common ancestor of every
  extension's source tree) in addition to its own narrow files. `plan-file-scope-harvest.sh`
  unions this into `file_scope` with **zero code change to that script** (it already harvests
  verbatim, path-shape-agnostic, per-phase entries). `orchestrate-batch-admit.sh`'s existing
  `file_scope_collision` branch then serializes any OTHER candidate whose own `file_scope` falls
  anywhere under `agent-system/...` — which is every meta/orchestrator-machinery task by
  convention (`source-store-deploy-boundary.md` requires editing under `agent-system/extensions/
  {ext}/`) — via the directory-prefix overlap rule already in `lib/file-scope-overlap.sh`, with no
  new jq branch.
  - **Why this satisfies ACCEPTANCE (b)'s "documented justification for reusing it" clause
    rather than needing a new `defer_reason`**: a whole-tree claim really IS a (very wide)
    `file_scope` collision once declared — the collision-scan's existing semantics (directory-
    prefix ancestor) are the correct predicate for "does this touch the same territory," and the
    wideness of the declared scope is exactly what makes the claim honest. Minting a new
    `defer_reason` would duplicate payload fields (`colliding_task_number`,
    `colliding_task_status`, `overlapping_path`, `collision_scope`) that `file_scope_collision`
    already carries correctly, for no behavioral gain.
  - **Why this does NOT need admission-gate content-sniffing (declining Option 1 as the primary
    mechanism)**: Option (1)'s own stated weakness — "fragile to rewording," "a new kind of input
    for this gate" — is avoided entirely, because the admission gate (`orchestrate-batch-admit.sh`)
    stays a pure `state.json`-only predicate, unchanged in shape. The only new surface is a plan-
    authoring convention plus (optionally, see Risks) a best-effort textual safety net confined to
    `plan-file-scope-harvest.sh`'s own single, already-plan-reading call site — never inside the
    hot admission path, and never a new script.
  - **Phase-exemption interaction**: the self-modifying branch already exempts a candidate's
    research/plan dispatch from deferral via `--phase-map` (a research/plan dispatch never
    touches orchestrator machinery). The same exemption rationale applies to a whole-tree-claim
    collision: a research or plan dispatch for a task whose plan WILL eventually redeploy never
    itself redeploys, so it should be phase-map-exempted from this specific collision the same
    way. Since this reuses `file_scope_collision`, it automatically inherits that branch's EXISTING
    `--phase-map` exemption with no new code — confirmed by reading the admission script's
    existing phase-group dispatch logic, which applies uniformly to the collision scan regardless
    of which task declared the overlapping scope.
  - **Addressing the Phase-2 out-of-scope doc-lint failure (explicitly required by the dispatch's
    "Evaluate at minimum" instruction)**: serializing dispatch (via the wide `file_scope`
    collision) does not, by itself, guarantee 371's redeploy lands before 372's gate run — it only
    guarantees 371 and 372 are never CO-DISPATCHED into the same wave. The out-of-scope doc-lint
    failure's true cause is 371's commit-without-redeploy interval, which the existing "inter-cycle
    redeploy checkpoint" + "postflight completion-deploy gate" pair already exists to close (see
    `iss_1791598089947_3K8mO2`'s own resolution: "deferred to the next cycle's Inter-Cycle
    Redeploy Checkpoint," which DID resolve it, at a one-cycle cost). Serializing 371/372's
    dispatch removes the WASTED WAVE (372 dispatching into a doomed Phase 2 at all, this cycle) but
    the stale-deploy READ hazard is a pre-existing, already-covered risk, not a new one this fix
    must additionally solve. This should be stated explicitly in the plan rather than silently
    assumed solved.
  - **Serializing vs. `defer_reason` (existing) for ordering**: the dispatch asks whether
    serializing is the right remedy versus deferring the second task with an existing
    `defer_reason`. Reusing `file_scope_collision` IS exactly "deferring the second task with an
    existing `defer_reason`" — the two framings converge once Option 2 is chosen this way; there is
    no separate "serialize at the deploy level" mechanism needed in addition (Option 3's existing
    fail-open mutex stays as the orthogonal last-resort backstop for the residual case where a
    task's plan was written before this convention existed and declares no sentinel — see Risks).

- **Part B: tighten the plan-cache write guard to require `>=1` real `dispatch[]` row, dropping
  the `aux_dispatch[]`-alone trigger, as the primary fix; fold the canonicalized
  `--force-phases` value into the cache key as an additional, independent safeguard.**
  - The write-guard fix directly targets the confirmed root cause (an aux-only composition caches
    at a counter value nothing but a FUTURE real dispatch can ever advance past) and closes the
    **entire defect class**, not just the `--force-phases` instance of it: any invocation that
    would currently replay a stale aux-only-charged cache (changed task set, changed `--focus`,
    changed `--clean`/`--lit`, a plain re-invocation with no flags at all) is fixed identically,
    with a one-line change and no new state field.
  - This is explicitly one of the dispatch's own candidate directions ("ensure every cache-writing
    path has a guaranteed clearing counterpart") — reframed as "don't let an aux-only path create
    a cache entry with no clearing counterpart in the first place," which is simpler than adding a
    clearing call to every aux-dispatch site (there may be more than one; a missed site would
    silently reopen the bug) and does not touch `orchestrate-cycle-postflight.sh`.
  - **Trade-off accepted**: an aux-only cycle (e.g., a blocker-research dispatch for a blocked
    task, with every OTHER candidate this cycle also deferred/blocked) no longer gets ANY cache
    benefit — the next invocation re-runs the full composition from scratch. This is the cost
    already implicitly paid today by every no-dispatch-no-aux-dispatch cycle (which already never
    caches, per the existing guard's secondary clause being unreachable without at least one
    charging row) — extending "never cache a cycle with nothing durably clearable" to aux-only
    cycles is a narrowing of an already-narrow optimization, not a new cost category.
  - Folding `--force-phases` into the cache key additionally satisfies ACCEPTANCE (a) literally
    and immediately, independent of whether some future change reintroduces an aux-only cache
    write path; recommended as defense-in-depth alongside the guard fix, not instead of it.
    ACCEPTANCE (c) (stdout contract unchanged) and (d) (header-documented pairing) are unaffected
    by either change — the header already documents the write/clear pairing (lines 71-76); it only
    needs updating to describe the corrected guard condition.

- **Adjacency: keep Parts A and B in one task/plan.** Confirmed no shared lines: Part A's touches
  are the admission/phase-map section (`orchestrate-cycle-plan.sh` ~1830-1945) plus
  `plan-file-scope-harvest.sh`'s header documentation (no code change there) plus plan-format.md
  convention text; Part B's touches are the plan-cache read/write sections
  (`orchestrate-cycle-plan.sh` ~625-760) plus that same script's header comment. Neither touches
  `orchestrate-batch-admit.sh` for B, nor the cache sections for A. The two can be implemented and
  tested as independent phases of one plan with no re-read hazard between them.

## Recommendations

1. **Part A implementation shape**: (a) extend `context/formats/plan-format.md`'s existing
   `Files to modify` convention with a short, explicit rule: a phase whose steps invoke whole-tree
   regeneration (`deploy-headless.sh`, or the picker's `[Reload All]`/`[Regenerate]` entries) MUST
   additionally list the source-store root(s) it reads from (at minimum `agent-system/`) as a
   `Files to modify` entry on that phase. (b) No change needed to `plan-file-scope-harvest.sh`
   itself — confirm via its existing test suite (`scripts/tests/test-plan-file-scope-harvest.sh`)
   that a bare directory-root entry (`agent-system/`) harvests correctly (it should, since the
   script is path-shape-agnostic). (c) No change needed to `orchestrate-batch-admit.sh` or
   `lib/file-scope-overlap.sh` — the directory-prefix overlap rule already produces the correct
   `file_scope_collision` verdict once the sentinel is present in `file_scope`. (d) Add a fixture
   test demonstrating ACCEPTANCE (a): two tasks with otherwise-disjoint `file_scope`, one
   declaring the `agent-system/` sentinel, do not co-admit. (e) Document, in the plan or in
   `batch-orchestration-guardrails.md`, the explicit non-goal named above: this fix prevents the
   wasted co-dispatch wave, not the independent (already-covered) stale-deploy-read hazard.
2. **Part A residual-risk backstop**: do not weaken or remove `deploy-headless.sh`'s existing
   fail-open `specs/.deploy-lock/` mutex. It remains the correct last-resort protection for a plan
   written before this convention exists (a legacy plan with no sentinel declared) — exactly the
   layered-defense posture `batch-orchestration-guardrails.md` already uses elsewhere (advisory
   layers backing up blocking ones). Do not promote it to blocking as part of this task; that is a
   separable decision with its own cost/benefit (how often does a declared whole-tree claim fail
   to prevent co-dispatch in practice, post-fix) that should be measured after the admission-time
   fix lands, not bundled into it.
3. **Part B implementation shape**: change the guard at `orchestrate-cycle-plan.sh` line ~754-755
   from `{ [ "${#out_dispatch_rows[@]}" -gt 0 ] || [ "${#out_aux_dispatch_rows[@]}" -gt 0 ]; }` to
   `[ "${#out_dispatch_rows[@]}" -gt 0 ]`. Update the header comment's existing `plan_cache`
   description (lines 71-76, and the inline comment at the write site) to state the corrected
   condition and the reason (aux dispatches never reach the one `plan_cache`-clearing site).
   Additionally fold the canonicalized `--force-phases` value (the script already computes
   `canonical_force_phases_json`) into the cache-key comparison at the replay-check site (~line
   640-650) and the write site (~line 757) — compare both `dispatch_seq_counter` AND the forced-
   phases value for a replay to fire; write both into `plan_cache`. Add regression tests for: (i)
   an aux-only composition never gets cached (ACCEPTANCE b's "no-charge benefit" is preserved for
   the cases that already had it — a real-dispatch cycle still caches); (ii) a `--force-phases`
   value different from the one a cache was built with does not replay (ACCEPTANCE a); (iii) the
   stdout JSON shape is byte-identical in both modes (ACCEPTANCE c).
4. **Keep the two parts as two phases of one plan**, per the Adjacency verdict above — no
   structural reason to split into separate tasks.

## Risks & Mitigations

- **Risk (Part A)**: planner-agent discipline is the sole enforcement mechanism for declaring the
  sentinel; a plan written without following the new convention leaves the gap exactly as open as
  today for that one plan. *Mitigation*: this is the same trust model `file_scope` declaration
  already relies on everywhere else (it is "descriptive/anticipated... never mutated by
  status-sync" per `state-management.md`); the existing fail-open deploy mutex (Recommendation 2)
  remains the backstop precisely for this case, and `backfill-file-scope.sh` already exists as
  the remedial tool for an absent/stale `file_scope` generally.
- **Risk (Part A)**: a sentinel as wide as `agent-system/` will now collide with almost every
  concurrently-dispatched meta/orchestrator task, not just ones that also redeploy — a legitimate
  precision cost of an honest claim. *Mitigation*: this is the dispatch's own stated goal
  ("treated as an implicit scope claim over the entire deployed tree") — the wideness is the
  point, not a defect; the existing `idle_overlap_advisory`/ordering-constraint-not-exclusion
  framing already used throughout `orchestrate-batch-admit.sh` applies unchanged (a deferred task
  resolves next cycle once the lower-numbered peer clears).
- **Risk (Part B)**: tightening the write guard removes caching for every aux-only cycle, which
  could, in a batch with persistently many blocked/deferred tasks and few real dispatches, reduce
  the frequency of the "do not charge for a read" benefit. *Mitigation*: this cost is bounded and
  already implicitly accepted elsewhere in the script (a true no-charge cycle already never
  caches); measure actual recomposition cost before treating this as a performance regression —
  the dispatch's own ACCEPTANCE (b) requires the benefit be preserved only for "the redundant
  re-composition it was built for," which is the real-dispatch case, not the aux-only case.

## Context Extension Recommendations

- **Topic**: whole-tree regeneration as an admission-time hazard.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md`'s extensive admission-layer
  documentation (Self-Modification Hazard, Absent file_scope Hazard, etc.) has no section
  covering a plan-phase-authored whole-tree redeploy as a distinct hazard class, despite covering
  every other admission dimension exhaustively.
- **Recommendation**: once Part A lands, add a short subsection to that file (sibling to "Self-
  Modification Hazard: The Fourth Admission Dimension") documenting the whole-tree-claim
  convention, why it reuses `file_scope_collision` rather than minting a new `defer_reason`, and
  the explicit non-goal (does not by itself close the stale-deploy-read hazard, which the
  inter-cycle redeploy checkpoint already covers).
- **Topic**: `plan_cache`'s write-guard/clear-pairing invariant.
- **Gap**: nothing documents, outside this task's own fix, that an aux-only composition must
  never be the sole trigger for a cache write — this is exactly the kind of invariant
  `orchestrate-cycle-plan.sh`'s own header already states it wants recorded ("the cache-write/
  cache-clear pairing is stated in the script's own header comment, so a future reader can check
  it without re-deriving it" — ACCEPTANCE (d)).
- **Recommendation**: covered by Recommendation 3's header-comment update; no separate context
  file needed beyond that.

## Appendix

### Search queries / commands used
- `cat .claude-extensions.json` (resolve `source_dir`)
- `Read` on `orchestrate-batch-admit.sh`, `lib/file-scope-overlap.sh`, `orchestrate-cycle-plan.sh`
  (partial, by section), `redeploy-checkpoint-lib.sh`, `file-footprint-overlap.md`
- `grep -n "plan_cache"` across `orchestrate-cycle-plan.sh` / `orchestrate-cycle-postflight.sh`
- `grep -n "dispatch_seq_counter"` across `orchestrate-cycle-plan.sh`
- `grep -n "aux_dispatch\|cycle-postflight"` across `skill-orchestrate/SKILL.md`
- `grep -n "specs/.deploy-lock\|mutex"` in `deploy-headless.sh`
- `find`/`grep` against `specs/archive/371_.../issues.jsonl`, `specs/archive/372_.../issues.jsonl`,
  and the task-372 Phase-4 handoff artifact, to verify every cited `entry_id` and corroborate the
  dispatch's narrative against primary evidence rather than taking it on faith.
- `grep -rln "plan-file-scope-harvest.sh"` to enumerate every live caller and confirm the
  harvest-at-plan-postflight-time integration point.

### References
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (verdict schema v6, header
  comment, self-modification/collision/absent-scope branches)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (plan_cache section ~560-760;
  phase-map/admission section ~1795-1945; aux-dispatch-seq mint ~1478-1481)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (plan_cache clear
  ~2128-2137)
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` (`scopes_overlap_first`,
  `self_mod_match`, `session_contention`)
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (header contract, caller list)
- `agent-system/extensions/core/scripts/deploy-headless.sh` (`specs/.deploy-lock` mutex,
  lines ~266-307)
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` ("The
  Inter-Cycle Redeploy Checkpoint" section)
- `agent-system/extensions/core/context/formats/plan-format.md` ("Files to modify" field)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (line 185, aux-dispatch
  postflight exclusion)
- `specs/archive/371_roadmap_generator_stage_layout_and_silent_abort/issues.jsonl`
- `specs/archive/372_conclusion_stage_report_block_and_caller_split/issues.jsonl`
- `specs/archive/372_conclusion_stage_report_block_and_caller_split/handoffs/phase-4-handoff-20261010T010324Z.md`
