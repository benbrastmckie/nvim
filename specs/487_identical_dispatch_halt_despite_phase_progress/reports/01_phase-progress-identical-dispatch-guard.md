# Research Report: Task #487

**Task**: 487 - Stop the identical-dispatch convergence guard halting a task on cycle 2 even when
cycle 1 closed a real plan phase
**Started**: 2026-11-10T13:00:14Z
**Completed**: 2026-11-10T13:40:00Z
**Effort**: medium
**Dependencies**: None (open territory edge with Task 451, still [NOT STARTED] at research time —
see Findings)
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh,
orchestrate-build-dispatch.sh, orchestrate-cycle-postflight.sh, skill-base.sh,
lib/phase-heading-patterns.sh, lib/continuation-pointer-lib.sh, orchestrate-churn.sh,
tests/test-orchestrate-cycle-plan.sh), specs/TODO.md, specs/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The root cause stated in the task description is confirmed by direct code reading: for a
  non-hard-mode (base-mode) `implement` dispatch, `orchestrate-build-dispatch.sh` renders no
  phase-progress content at all. The only phase-progress interpolation (`PHASES COMPLETED: <n> of
  <m>` inside the `## Phase Mission` section) is gated on `[ -n "$phase_number" ]`, and
  `--phase-number` is set by `orchestrate-cycle-plan.sh` at exactly one site, documented in that
  site's own comment as "only ever set for a hard-mode implement candidate." A base-mode
  multi-phase implement dispatch therefore composes byte-identical bodies across consecutive
  cycles regardless of how many phases close in between, and `cycle_plan_dispatch_hash()`'s strip
  pattern (which removes only `dispatch_seq`, `dispatch_start_ts`, and the Issue Log's
  `--dispatch-seq` placeholder) has no other line to catch the real change.
- The codebase already contains a fully-worked structural precedent for fixing this the way the
  task's option (b) describes: the **deploy_pending streak-freeze** block immediately above the
  halt in `orchestrate-cycle-plan.sh` (same file, same function scope) freezes — never
  suppresses — the streak counter when an independent signal (a `.return-meta.json` flag) explains
  a repeated hash without charging it as churn. A phase-progress freeze is the same shape, reading
  a different independent signal.
- The codebase also already contains the exact mechanism needed to compute that independent
  signal for an ordinary (non-hard-mode) implement dispatch: `lib/phase-heading-patterns.sh` is
  sourced **unconditionally** in `orchestrate-cycle-plan.sh` (not hard-mode-gated), and
  `skill-base.sh`'s `skill_corroborate_phase_counts()` demonstrates the exact two-line
  `grep -cE "$PHASE_HEADING_ERE"` / `grep -cE "$PHASE_HEADING_DONE_ERE"` idiom against the plan
  file's own headings — the same ground-truth source the hard-mode H1 branch already trusts for
  its own next-phase selection, independent of whatever the agent self-reports in its handoff.
- **Recommended approach**: implement option (b) (an independent-signal streak freeze, modeled
  directly on the deploy_pending precedent and using the plan-file heading count as the signal) as
  the required correctness fix, because it never touches the carefully-reasoned hash normalizer or
  its strip pattern at all — the exact surface whose drift already caused one silent regression
  (Group 27 Case F). Layer option (a) on top as a transparency enhancement (surface
  `PHASES COMPLETED: N of M` to the dispatched agent for every implement dispatch, not only
  hard-mode phase-scoped ones) via a new, always-on section distinct from the hard-mode-only
  `## Phase Mission`, deliberately left unstripped by the hash (a fourth DECIDED-AND-RECORDED
  entry alongside Batch Gate Deferral and Outstanding Gate Finding). Neither mechanism weakens the
  guard's genuine-non-convergence case: when no plan file corroborates (or no phase closed), both
  degrade to exactly today's behavior.
- The `cycle_plan_dispatch_hash()` header comment's assertion that "a real behavioral change to
  the dispatch... changes some OTHER line and therefore still changes the digest" needs the
  correction the task description already calls for: it does not hold for an ordinary multi-phase
  implement dispatch today, and the fix must state that exception explicitly in the same place the
  two existing DECIDED AND RECORDED rulings already live.
- Territory edges named in the task description are effectively clear: five of the six named tasks
  (`hoist_batch_gate_deferral_directive`, `warn_plan_size_exceeds_cycle_budget`,
  `validate_settled_route_before_dispatch`, `advise_on_dirty_file_scope_at_admission`,
  `validate_carried_unverified_names_a_source`) are already `[COMPLETED]`. One,
  `snapshot_lean_challenge_at_plan_time` (task 451), is still `[NOT STARTED]` and also touches
  `orchestrate-cycle-plan.sh`; the description's own "re-check at admission" instruction still
  applies to it.

## Context & Scope

This research investigated why `/orchestrate`'s identical-dispatch convergence guard
(`orchestrate-cycle-plan.sh`'s "Fix 2") halts a multi-phase `implement` task on the second
consecutive cycle even when the first cycle closed a genuine plan phase and committed the work —
a false positive that caps every `/orchestrate` invocation over a multi-phase plan at one phase of
progress. The task description supplies a verified root-cause analysis and three non-exclusive
candidate directions (emit phase progress into the hashed content; consult an independent progress
signal before halting; or both). The scope here is to re-derive and confirm that root cause against
the live source store, evaluate the three candidate directions against the stated hard constraints,
identify the concrete mechanisms and precedents already in the codebase that a plan phase would
reuse, and recommend a direction with reasoning recorded — not to implement it.

Out of scope: writing the fix, writing the regression tests themselves (though the test shape is
recommended in detail), and touching the deploy or any file outside read-only investigation.

## Findings

### Codebase Patterns

**Confirmed root cause (re-derived against current line numbers).**
- `orchestrate-build-dispatch.sh`'s only phase-progress render is inside the `[ "$phase" =
  "implement" ]` branch, gated on `if [ -n "$phase_number" ]` (around line 747), emitting
  `## Phase Mission` with `PHASES COMPLETED: ${phases_completed_for_mission} of
  ${phases_total_for_mission}` (around line 760). `phases_completed_for_mission`/
  `phases_total_for_mission` are themselves computed only inside that same `if [ -n "$phase_number"
  ]` guard (around lines 338-346), read from the handoff's own self-reported
  `phases_completed`/`phases_total` fields — not from the plan file.
- `--phase-number` is appended to `build_args` at exactly one call site in
  `orchestrate-cycle-plan.sh` (around line 2746): `[ -n "${h1_next_phase[$t]:-}" ] && build_args+=
  (--phase-number "${h1_next_phase[$t]}")`. `h1_next_phase[$t]` is populated only inside the H1 loop
  (around lines 2343-2409), whose very first line is `[ "$hard_mode" != "true" ] && continue`. A
  base-mode implement dispatch therefore never sets `--phase-number`, never renders `## Phase
  Mission`, and carries zero phase-progress content of any kind.
- `cycle_plan_dispatch_hash()` (around line 2222) strips exactly three lines before hashing:
  `- dispatch_seq: N`, `- dispatch_start_ts: N`, and the Issue Log's
  `--what-happened "..." [--phase P] [--dispatch-seq N] \` boilerplate. Every other line of a
  base-mode implement dispatch for the same task/phase/plan/description/territory is reproduced
  byte-for-byte across cycles — there is nothing left for the strip pattern to need to catch,
  because nothing in the body varies with phase progress in the first place. The header comment's
  claim that a real behavioral change always "changes some OTHER line" is true for every dimension
  it actually enumerates (phase_number, territory, focus) but silently assumes phase_number is
  always available when phase progress happens — which it is not in base mode.

**The Fix 2 halt block itself** (around lines 2850-2917) computes `_idh_hash` via
`cycle_plan_dispatch_hash()`, compares it against `mt_get '.last_dispatch_hash[$t]'` and
`.last_dispatch_phase[$t]`, and increments a per-task `identical_dispatch_streak[$t]` on a match
(or resets to 1 on a genuine difference). At `_idh_streak -ge 2` it halts: removes the
just-written dispatch file, restores pre-dispatch `state.json` fields via `state-write.sh`,
releases the task lock, and records the task in `identical_dispatch_halted[]` — explicitly without
charging any budget, seq, or pending-dispatch side effect. This back-out logic is independent of
*why* the streak reached 2 and does not need to change for either candidate direction.

**Existing precedent for an independent-signal freeze (option (b)'s model).** Immediately above
the increment, a `deploy_pending` freeze already exists for a structurally identical problem: a
task refused by the postflight completion-deploy gate (exit 6) necessarily re-derives a
byte-identical dispatch next cycle — not evidence of genuine non-convergence. The comment block
(lines ~2833-2849) states the chosen semantics explicitly: "Freeze, never suppress... the streak
counter is left at its current persisted value — not incremented, and not reset to 1 either, so a
pre-existing genuine streak survives the interruption intact." The live code (lines 2869-2883)
reads this task's own fresh `.return-meta.json` `deploy_pending` flag (never the batch-wide
`deploy_pending_any`), and when true AND the hash matches, reads the streak without incrementing it
rather than taking the increment branch. A phase-progress freeze is the same shape: same
conditional structure, same "read fresh, freeze without incrementing, still persist the new hash/
phase for next cycle's comparison" pattern — only the independent-signal source changes.

**Existing mechanism for the independent signal itself.** `orchestrate-cycle-plan.sh` sources
`lib/phase-heading-patterns.sh` **unconditionally** (around line 2341), with an explicit comment
noting this was deliberately widened beyond the H1 (hard-mode) loop because "sourcing only defines
functions/variables -- no side effect -- so widening this to unconditional is safe." The library
exports `PHASE_HEADING_ERE` and `PHASE_HEADING_DONE_ERE` plus `has_nonconforming_phase_headings`/
`warn_nonconforming` guards. `skill-base.sh`'s `skill_corroborate_phase_counts()` (around line
1558) already demonstrates the exact pattern needed: `grep -cE "$PHASE_HEADING_ERE" "$plan_path"`
for the total, `grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path"` for the completed count (`DONE`
meaning `[COMPLETED]` or `[COMPLETED WITH EXCLUSIONS]`), gated on
`has_nonconforming_phase_headings` returning false first (never trust a filtered count over a file
with an unparseable heading). The hard-mode H1 loop (lines 2343-2409) already resolves `plan_path`
for every implement candidate via `ls -1 ".../plans/"*.md | sort -V | tail -1` and uses the same
counting idiom for its own marker/handoff crosscheck (`h1_marker_completed_count`, line 2387) — but
only inside its own `[ "$hard_mode" != "true" ] && continue`-gated loop. Nothing in that resolution
or counting logic is itself hard-mode-specific; it is gated purely by the surrounding loop's own
guard, which a base-mode-reaching computation would simply not inherit.

**The agent's self-reported `phases_completed` is a weaker, not stronger, signal than the plan
file's own headings.** `orchestrate-build-dispatch.sh` (lines 338-346) and the H1 loop both read
`phases_completed` from `.orchestrator-handoff.json` — a self-report that can be stale, absent (a
`partial` dispatch that never wrote the field), or (per the H1 marker/handoff crosscheck's own
existence) can actively disagree with the plan file's own markers. `skill_corroborate_phase_counts`
exists specifically because postflight does not trust the handoff's self-report unconditionally;
it corroborates against the plan file before ever overwriting counts. The same preference applies
here: the independent signal a guard-freeze mechanism should read is the plan file's own
`[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]` heading count (ground truth, already committed to the
repository by the time the next cycle composes its dispatch), not the handoff's self-report.

**`orchestrate-churn.sh` is not directly reusable here.** It persists `phases_completed_last` per
task and computes a delta, which looks superficially like the needed mechanism — but it is called
only from `orchestrate-cycle-postflight.sh`'s hard-mode branch (`if [ "$hard_mode" = "true" ] &&
...`), gated the same way H1 is. Base-mode tasks get an unrelated "drift-inspection" signal instead
(`orchestrate-cycle-postflight.sh` lines ~1795-1809), which does not persist a comparable prior
value usable at the NEXT cycle's compose-time Fix-2 block. A new, parallel persisted field in the
SAME `mt_state` JSON file the Fix 2 block already reads/writes (`last_dispatch_hash`,
`last_dispatch_phase` — initialized via `//= {}` around lines 632-634) is the natural site for a
new `last_dispatch_phases_completed[$t]` field, not a repurposing of `orchestrate-churn.sh`'s
hard-mode-only churn file.

**Regression-test precedent and template.** `scripts/tests/test-orchestrate-cycle-plan.sh`'s
"Group 27" (identical-dispatch content hashing, lines ~3935-4198) and "Group 28" (the halt itself,
lines ~4199-4345) own this guard's existing coverage, exactly as the task description names. Group
27 Case F (lines ~4098-4139) is the regression fixture for the exact failure mode this record's
root cause describes: a THIRD per-cycle-varying line (the Issue Log's `[--dispatch-seq N]`
placeholder) was added to the composed dispatch body without extending the strip pattern, silently
making the halt permanently inert; Case F pins that two files differing only in that line still
hash equal. "Group 29" (lines ~4346 onward) is the closer, more directly reusable template: it
reproduces and pins the resolution of the deploy_pending-vs-identical-dispatch composition defect —
structurally the SAME class of problem this record addresses (an independent signal should prevent
a false-positive halt), using a `g29_write_task_fixture` helper that writes a task directory with a
plan file (`[COMPLETED]` phase heading), a `.orchestrator-handoff.json` with `phases_completed`/
`phases_total`, and a `.return-meta.json` with a `deploy_pending` flag, then runs `run_sut` across
multiple cycles and asserts on `state.json`, the blocked[]/dispatch[] rows, and the persisted
mt_state streak value. A phase-progress freeze fixture would clone this shape almost directly:
seed a 2-phase plan (Phase 1 `[COMPLETED]`, Phase 2 `[IN PROGRESS]`), run cycle 1 (dispatches
normally, seeds `last_dispatch_hash`/new `last_dispatch_phases_completed`), mutate the plan file
in place to flip Phase 2 to `[COMPLETED]` (simulating the agent's committed work, exactly as the
originating evidence describes), run cycle 2, and assert the task is NOT in `blocked[]`/was not
halted. A companion fixture skips the mutation step and asserts cycle 2 DOES halt, exactly
mirroring Group 28's existing assertions (zero dispatch rows, one blocked[] row naming the guard,
the named stderr notice, and every back-out assertion: state.json restore, dispatch file removal,
lock release, unchanged `dispatch_seq_counter`, unchanged `cycle_counts`). The next available group
number in this file is 37 (Group 36 is currently the last).

**Status of the named territory edges** (checked in `specs/TODO.md` at research time):
`hoist_batch_gate_deferral_directive` (449), `warn_plan_size_exceeds_cycle_budget` (420),
`validate_settled_route_before_dispatch` (450), `advise_on_dirty_file_scope_at_admission` (409),
and `validate_carried_unverified_names_a_source` (360) are all `[COMPLETED]`. The dependency edge
the description declares against `hoist_batch_gate_deferral_directive` (over `## Batch Gate
Deferral`'s positioning and the hash normalizer's DECIDED-AND-RECORDED ruling about that section)
is therefore already resolved — that section's final position and the normalizer's ruling about
it are settled, live code, not a moving target. `snapshot_lean_challenge_at_plan_time` (451) is
still `[NOT STARTED]` and (per its own title) also concerns plan-time phase-snapshot behavior in
the same file; the description's instruction to "re-check at admission" for this one specifically
still applies and should be re-verified immediately before any implementation dispatch for this
record, not assumed clear from this research pass.

### External Resources

Not applicable — this is a self-contained orchestration-engine bug confined to this repository's
own `agent-system/extensions/core/scripts/` source store. No external library, API, or published
best-practice source bears on the fix; the relevant precedents are entirely internal (the
deploy_pending freeze and the phase-heading corroboration library).

## Recommendations

1. **Primary fix — option (b), modeled on the deploy_pending freeze.** In
   `orchestrate-cycle-plan.sh`'s Fix 2 block, before the existing hash-match branch, resolve
   `plan_path` for the task (the same `ls -1 ".../plans/"*.md | sort -V | tail -1` idiom the H1
   loop already uses, generalized outside the `hard_mode` guard) and, when it resolves to a file
   with no non-conforming headings and at least one conforming phase heading, compute
   `cur_phases_completed` via `grep -cE "$PHASE_HEADING_DONE_ERE"` against it. Compare against a
   new persisted `last_dispatch_phases_completed[$t]` field in the same `mt_state` JSON object
   `last_dispatch_hash`/`last_dispatch_phase` already live in (same `//= {}` initialization
   pattern). When the hash matches AND `cur_phases_completed` is strictly greater than the
   persisted prior value, freeze the streak exactly as the deploy_pending branch does (read it
   without incrementing) rather than charging churn; still persist the new `cur_phases_completed`
   value for the next comparison, same as the hash/phase fields are unconditionally persisted
   today. When there is no prior persisted value yet (first measurement for this task), do not
   freeze — just seed it, mirroring the hash/phase fields' own first-cycle behavior. This is the
   REQUIRED correctness fix: it satisfies every HARD CONSTRAINT without touching
   `cycle_plan_dispatch_hash()` or its strip pattern at all, the exact surface whose drift already
   caused a silent regression once (Group 27 Case F). Gate the whole computation on `[ "$g" =
   "implement" ]` (research/plan phases have no plan-phase concept).
2. **Secondary enhancement — option (a), layered on top, not substituted for (1).** Generalize
   `orchestrate-build-dispatch.sh`'s `phases_completed_for_mission`/`phases_total_for_mission`
   computation (currently gated on `phase_number`, i.e. hard-mode-only) to also compute a
   plan-file-corroborated count for every implement dispatch, and render it in a **new**,
   always-on-for-implement section — not the hard-mode-specific `## Phase Mission` (whose
   "HARD MODE DISPATCH" wording and "implement phase N only" instruction must stay exactly as
   they are for hard mode) — e.g. `## Phase Progress`, emitted whenever the plan file corroborates
   a nonzero phase count, independent of `hard_mode`/`phase_number`. Deliberately leave this new
   section OUT of `cycle_plan_dispatch_hash()`'s strip pattern (it must change the digest whenever
   genuine progress happens), and add it as a fourth DECIDED-AND-RECORDED entry in that function's
   header comment, in the same style as the existing Batch Gate Deferral and Outstanding Gate
   Finding entries. This gives the dispatched agent visibility into phase progress for base-mode
   multi-phase plans too (today only a hard-mode phase-scoped dispatch sees this), and — as a
   side effect in the common case — naturally diverges the hash whenever a phase closes, without
   being load-bearing for correctness (mechanism (1) above already guarantees correctness even
   when this section is absent, e.g. a plan with no conforming phase headings at all).
3. **Correct the header comment's over-general assertion**, as the task description itself
   requires. Immediately after the sentence "a real behavioral change to the dispatch (a different
   phase_number, a different territory payload, a different focus string) changes some OTHER line
   and therefore still changes the digest," add an explicit exception naming the case this record
   addresses: an ordinary (non-hard-mode) multi-phase implement dispatch closing a phase changes no
   line of the dispatch body by itself, and point to (2)'s new unstripped section (when
   implemented) and/or (1)'s independent-signal freeze as the two mechanisms that keep the guard
   correct despite that exception. Per `rules/no-task-references-in-deliverables.md`, this
   correction (landing under `agent-system/**`) must describe the exception by durable technical
   shape only — never by citing this task's own number.
4. **Do not implement option (a) alone.** Relying only on hash divergence from the new section
   would leave the guard's correctness dependent on every future implement-dispatch content
   addition correctly avoiding the strip list — exactly the STANDING OBLIGATION the comment already
   warns about, and exactly the failure mode Group 27 Case F exists to catch. Mechanism (1) is the
   one that must not regress; (2) is additive value, not a substitute safety net.
5. **Test placement**: site the two new fixtures (phase-closed -> not halted; phase-not-closed ->
   still halted) as a new Group 37 in
   `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`, cloning Group 29's
   `g29_write_task_fixture`/`g29_seed_state_and_mt` helper shapes (adapted for a plan-heading
   mutation between cycles rather than a `deploy_pending` flag) rather than Group 27/28's simpler
   per-file hash-only fixtures, since this guard's new behavior is only observable end-to-end
   through `run_sut` across two real cycles with a plan-file mutation in between. Additionally
   re-run the full existing Group 27 (especially Case F and Case G, the two DECIDED-AND-RECORDED
   unstripped-section pins) and Group 28 suites unmodified as a regression check that the new
   mechanism changes no existing assertion.

## Decisions

- The independent progress signal should be the **plan file's own phase headings**
  (`PHASE_HEADING_DONE_ERE` count via `lib/phase-heading-patterns.sh`), not the handoff's
  self-reported `phases_completed` — the plan file is ground truth already trusted elsewhere
  (H1's own marker/handoff crosscheck exists specifically because the handoff's self-report can
  disagree with it) and is available even when a dispatch returned `partial` without the field.
- The fix should be implemented as a **persisted independent-signal freeze** (option (b)) as the
  load-bearing correctness mechanism, with a **separate, non-load-bearing** content/visibility
  enhancement (option (a)) layered on top — not option (a) alone. This research explicitly
  recommends against relying on hash divergence as the sole correctness mechanism, for the
  STANDING OBLIGATION risk reason stated in Recommendation 4.
- The territory edge against `snapshot_lean_challenge_at_plan_time` (451) is not resolved by this
  research and must be re-checked at admission time, per the description's own instruction — this
  report does not supersede that instruction.

## Risks & Mitigations

- **Risk**: a plan file with non-conforming phase headings could make the independent signal
  unreliable (silently under/over-counting). **Mitigation**: gate the new computation on
  `has_nonconforming_phase_headings` returning false first, exactly as every existing consumer of
  this library does (H1's own resume scan, `skill_corroborate_phase_counts`); on a hit, treat the
  signal as unavailable (behave exactly as today, relying on hash-identity alone) rather than
  guessing.
- **Risk**: adding a new unstripped, always-on section to the dispatch body (Recommendation 2)
  could inadvertently change dispatch content in a way some other downstream consumer depends on
  (e.g. a snapshot/golden-file test outside the two named groups). **Mitigation**: grep the test
  suite for any fixture asserting an exact byte-for-byte dispatch-file render before adding the
  section, and treat mechanism (1) as sufficient on its own if such a dependency is found — (2) is
  explicitly optional, not required to close this record.
- **Risk**: freezing the streak on ANY phase advance could mask a task that advances one phase
  then genuinely stalls on every subsequent phase for many cycles, if the freeze is implemented as
  "forgive forever" rather than "forgive this one repeat." **Mitigation**: mirror the
  deploy_pending freeze's exact semantics — freeze (hold the current streak value) only for the
  cycle where the hash matches AND the signal shows new progress since the LAST persisted value,
  then re-arm fully: the next cycle's comparison uses the just-updated
  `last_dispatch_phases_completed[$t]`, so a second consecutive non-advancing repeat after a
  one-phase advance still accumulates streak normally and can still halt. This is exactly how the
  existing deploy_pending freeze already avoids "forgive forever" (per its own header comment: "a
  pre-existing genuine streak survives the interruption intact").
- **Risk**: the plan-file read in the Fix-2 block happens after `orchestrate-build-dispatch.sh` has
  already composed and written this cycle's dispatch file — if plan-file state could somehow
  change between those two steps within the same cycle, the signal and the composed content could
  disagree. **Mitigation**: both steps run sequentially within the same per-task loop iteration
  with no intervening agent dispatch, so no such race exists in practice; this is the same
  sequencing the existing `_idc_identity_seq` consistency assertion (immediately above the Fix 2
  block) already relies on being race-free.

## Context Extension Recommendations

- **Topic**: independent-signal guard-freeze pattern.
- **Gap**: there is no context file documenting the "freeze, never suppress, re-arm every cycle"
  pattern as a named, reusable idiom — it currently exists only as inline comments on the
  deploy_pending freeze block in `orchestrate-cycle-plan.sh`, and this research found it only by
  reading that block directly. A second occurrence (this record's phase-progress freeze) would
  make it a two-instance pattern worth naming.
- **Recommendation**: once this record's fix lands, consider extracting a short pattern note (e.g.
  under `context/patterns/`) naming the "freeze-not-suppress" idiom generically, citing both
  occurrences by their durable section headings rather than by task number, so a third future
  guard-interaction case does not have to re-derive the idiom from scratch by reading comments.

## Appendix

- Search queries / investigation steps used: direct reads of
  `orchestrate-build-dispatch.sh` (Identity/Phase Mission/Issue Log composition, lines ~280-937),
  `orchestrate-cycle-plan.sh` (`cycle_plan_dispatch_hash`, the H1 loop, the Fix 2 streak/halt
  block, lines ~2174-2920), `orchestrate-cycle-postflight.sh` (phases_completed/phases_total
  derivation and churn/drift signal wiring, lines ~738-1914), `skill-base.sh`
  (`skill_corroborate_phase_counts`, lines ~1503-1632), `lib/phase-heading-patterns.sh` (full
  file), `lib/continuation-pointer-lib.sh` (full file), `orchestrate-churn.sh` (grep for
  `phases_completed_last`), and `tests/test-orchestrate-cycle-plan.sh` Groups 27-29 and the
  Group-numbering tail (Group 36 is currently last).
- `specs/TODO.md` entries checked for territory-edge status: tasks 360, 420, 444, 446, 449, 450
  (all `[COMPLETED]`), 409 (`advise_on_dirty_file_scope_at_admission`, `[COMPLETED]`, found via
  `specs/state.json`'s `completed_projects`), and 451 (`snapshot_lean_challenge_at_plan_time`,
  `[NOT STARTED]`).
- No web search or external documentation was used; this is a self-contained internal
  orchestration-engine investigation.
