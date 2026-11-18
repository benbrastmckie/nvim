# Research Report: Task #547

- **Task**: 547 - Close the orchestrate aux blocker-research carrier defect and the implement-readmission gap
- **Started**: 2026-11-16T18:50:00Z
- **Completed**: 2026-11-16T19:04:00Z
- **Effort**: ~2 hours (research pass; source-store reading plus two targeted script traces)
- **Dependencies**: None (research phase)
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (AUX CHAIN block, lines ~1380-1596; triage-group assignment loop, ~1788-1867; `out_blocked_rows`/`emit_and_exit`)
  - `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (k)/(m) aux-signal recording, lines ~1837-1940)
  - `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` (fixed-agent prompts, lines 203-235)
  - `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (header table, blocked-discharge jq, lines 1-170, 440-526)
  - `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` (`blocker_escalation_count` reset-per-invocation note)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (Group 10 aux cases A/B/F, lines 979-1163)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` (blocker-research/plan-revision prompt assertions, lines 98-230)
  - `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` (header comment and audited-fields list: `next_action_hint` retirement)
  - `agent-system/extensions/core/context/patterns/plan-revision-notification.md`
  - `agent-system/extensions/core/agents/reviser-agent.md`, `agents/general-implementation-agent.md`
  - `agent-system/extensions/core/context/schemas/orchestrator-handoff-schema.json`, `docs/architecture/handoff-schema.md`
  - `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (lines 30-40, 760-775)
  - `.claude-extensions.json` (source_dir resolution)
- **Artifacts**: this report
- **Standards**: report-format.md, return-metadata-file.md, source-store-deploy-boundary.md

## Executive Summary

- Both defects are confirmed exactly as the dispatch describes, by direct reading of the live
  source store (resolved to `agent-system/extensions/core`, confirmed via `.claude-extensions.json`).
- Item 1: `orchestrate-cycle-plan.sh`'s blocker-research case clears `aux_pending[t]` at line
  1466 (hop 2, emission time), unconditionally, before anything confirms the forked agent wrote
  `.blocker-research.json`. The carrier-success branch (lines 1407-1415) never sets
  `aux_clear_pending[t]`, so a confirmed carrier was *already* going to leave `aux_pending[t]`
  stale under a confirm-then-clear design unless that branch is also updated. The absence is
  silent today in every channel the dispatch names.
- Item 2: `orchestrate-triage-classify.sh`'s blocked-discharge arm (lines 467-526) routes a
  discharged `blocked` candidate by `previous_status` alone and never reads `aux_pending`,
  `.plan-revised.json`, or `next_action_hint`. `next_action_hint` is confirmed structurally dead:
  it has **zero** live writers (no agent file populates it) and its only readers are
  `validate-handoff.sh` and a retired test-suite audit — `test-handoff-reader-parity.sh`'s own
  header states it was retired because "neither field has a live reader in either file any more."
  This is stronger than the dispatch's own framing ("consumed by NO routing code"); it has no
  live *writer* either.
- **One correction to the dispatch's own premise, stated per the carried-figure/ground-overturned
  discipline**: option (ii)'s claim that the chain-state obligation "is recorded in the
  multi-task state file, which the planner already reads" is true of
  `orchestrate-cycle-plan.sh` as a whole but not of the specific component that makes the
  blocked-discharge decision. `orchestrate-triage-classify.sh` reads only `specs/state.json` and
  a candidate's own `.orchestrator-handoff.json` (its own header: "This script reads ONLY
  specs/state.json... and that candidate's own .orchestrator-handoff.json") — it never touches
  `aux_pending`, which lives in the per-invocation multi-task state file
  (`specs/.orchestration/.orchestrator-multi-state-{session_id}.json`, loaded into `mt_json` in
  `orchestrate-cycle-plan.sh` itself). The outcome recommended below (key on chain state, no
  schema change) is preserved; the reasoning is corrected to place the gate in
  `orchestrate-cycle-plan.sh`'s own triage-group post-processing rather than inside
  `orchestrate-triage-classify.sh`.
- Recommended remedies: Item 1 — shape (a), confirm-then-clear, by moving the `aux_pending[t]`
  clear from hop 2 (emission) to hop 4 (confirmation) or the escalation cap, with the existing
  `blocker_escalation_count[t]` increment point left unchanged. Item 2 — shape (ii) as corrected
  above: a post-triage override in `orchestrate-cycle-plan.sh` that downgrades an `implement`
  verdict to `needs_human` whenever `aux_pending[t].kind == "blocker-research"` is still set,
  applied identically regardless of which engine (live classifier or degraded fallback) produced
  the base verdict, and applied *before* the existing forced-phase override so an explicit
  forcing flag still bypasses it (with an added stderr warning).

## Context & Scope

This research phase was asked to settle, not merely restate, three open decisions the dispatch
poses: which of three remedy shapes closes Item 1's carrier-confirmation gap; which of three
hooks closes Item 2's implement-readmission gap; and whether the documented insistence asymmetry
between the `blocker-research` and `plan-revision` aux prompts is deliberate. All three required
reading the live `.sh` sources rather than trusting the dispatch's own prose account, per the
dispatch's own instruction ("RE-DERIVE IT RATHER THAN TRUSTING THIS ACCOUNT"). The sibling record
`plan_self_consistency_and_artifact_existence` (cited for cross-reference only, no dependency
edge) could not be located in this repository's current `specs/state.json`, `specs/TODO.md`,
`specs/archive/`, or `specs/vault/` under its slug or under project number 827 — it is referenced
only secondhand (inside this task's own migrated description and inside an unrelated backlog
audit's `.ndjson` evidence file). This is noted as a caveat for the implementation phase, not
treated as blocking: the dispatch itself declares no dependency edge on it, and its half of the
problem (plan-authoring guidance, not script behavior) is explicitly out of this record's scope
either way.

## Findings

### The four-hop chain, confirmed hop by hop

1. **Hop 1** (`orchestrate-cycle-postflight.sh`, WORK (k), lines ~1905-1940): on `verdict ==
   "blocked"` or a base-mode `partial` outcome carrying `blockers[]`, writes
   `aux_pending[t] = {kind: "blocker-research", blocker_desc}` to the multi-task state file.
   Unconditional on `hard_mode` for this signal (base mode has its own analogous drift-inspection
   write just above, gated the other way).
2. **Hop 2** (`orchestrate-cycle-plan.sh`, lines 1457-1466): reads `aux_pending[t]`, checks
   `blocker_escalation_count[t] >= MAX_BLOCKER_ESCALATIONS` (2), and if under the cap sets
   `aux_emit_kind[t]="blocker-research"` and **unconditionally** `aux_clear_pending[t]="true"` —
   this line runs regardless of whether the subsequent live-dispatch loop (lines 1510-1577)
   actually succeeds in building and launching the fork. The clear is applied in the consumption
   loop at lines 1581-1588, which runs after dispatch-file construction but does not itself
   gate on construction outcome either (a build failure at line 1554 only `continue`s the loop,
   leaving `aux_clear_pending[t]` already `"true"` from step 2).
3. **Hop 3** (`orchestrate-build-aux-dispatch.sh`, line 215): the `blocker-research` prompt reads
   verbatim: *"Research this specific blocker for task N: ... Write compact JSON to
   '.../.blocker-research.json' with fields: summary, root_cause, solution_path."* No
   insistence language, no contract pointer. By contrast the `plan-revision` prompt (line 230)
   ends: *"Do this every time, unconditionally, even if you cannot tell whether an implement
   dispatch for this task is live this cycle. See context/patterns/plan-revision-notification.md
   for the full contract."* The asymmetry is real and confirmed line-for-line. The dispatch asks
   whether it is deliberate — nothing in the file's own comments, in
   `plan-revision-notification.md`, or in `test-orchestrate-build-aux-dispatch.sh`'s existing
   assertions suggests a deliberate reason for withholding equivalent insistence from the
   `blocker-research` prompt. The `plan-revision` sentinel's insistence exists specifically
   because that write races a concurrently-live implement dispatch reading the same plan file
   (per `plan-revision-notification.md`'s "hazard" section); the `blocker-research` carrier has
   no analogous same-cycle reader to race against, so the two prompts' insistence need not be
   *identical*, but the blocker-research prompt still has zero insistence of any kind today,
   which this research treats as an oversight rather than a reasoned omission.
4. **Hop 4** (`orchestrate-cycle-plan.sh`, lines 1407-1415): tests
   `[ -f "$aux_blocker_file" ] && jq empty "$aux_blocker_file"`; on success, emits a
   `plan-revision` row and sets `aux_consume_blocker_file[t]="true"` (which removes the carrier
   file at lines 1585-1588) — but this branch **never sets `aux_clear_pending[t]`**. Confirmed by
   direct reading: lines 1407-1415 contain no `aux_clear_pending` assignment at all. This matters
   independent of which remedy is chosen for Item 1: today it is harmless only because hop 2
   already cleared `aux_pending[t]` the cycle before (the two were never intended to race each
   other under the current, broken design). Any confirm-then-clear remedy that stops hop 2 from
   clearing immediately **must** add the clear to this branch, or a successfully-confirmed
   carrier would leave a stale `aux_pending[t]="blocker-research"` entry sitting in state forever
   (a new, self-inflicted defect symmetric to the one being fixed).

### Item 1 — the escalation counter's actual re-use semantics

`scripts/orchestrate-loop-guard-init.sh` documents `blocker_escalation_count` as reset to 0 "each
/orchestrate invocation" (line 45) — it is scoped to one run, not to one logical blocker. The
counter increments only inside the live-dispatch branch, after a build+dispatch actually succeeds
(lines 1572-1574), never on a round that failed to produce a carrier (there is no such detection
point today — this is exactly the gap Item 1 exists to close). This means: under the
confirm-then-clear remedy below, the increment's existing location is already correct for the
new semantics — it counts "how many blocker-research forks this invocation has actually
launched," which is the right thing to cap regardless of whether earlier launches ever produced a
carrier. Only the **clear** point needs to move, not the **increment** point.

### Item 2 — the discharge path, and where the fix must NOT be made

`orchestrate-triage-classify.sh`'s blocked-discharge arm (lines 467-526) discharges when (1)
`dependencies[]` is non-empty, (2) every dependency's own `status` is exactly `"completed"`, and
(3) the candidate's own `.orchestrator-handoff.json` `blockers[]` is empty or absent — then routes
by `previous_status` alone (`researched`→plan, `planned`/`implementing`→implement, etc.). This is
confirmed against the live script text, matching the dispatch's account exactly. The script's own
header (lines 121-167) frames this discharge check as **by design** — it exists precisely so a
task blocked purely on an external dependency is not left stuck in `needs_human` once that
dependency resolves. The defect is not that discharge exists; it is that discharge checks only
dependency-resolution and handoff-`blockers[]` emptiness, never whether a blocker-research/
plan-revision chain triggered by an *internal* implementation blocker (unrelated to
`dependencies[]`) ever actually resolved.

The degraded fallback table inside `orchestrate-cycle-plan.sh` (lines 1811-1819) maps `blocked`
unconditionally to `needs_human` with no discharge logic at all — confirmed. This divergence from
the live classifier is **already-documented design**, not an oversight needing to be converged:
the live classifier's own header (lines 154-167) gives an explicit discriminator for when a
divergence between the two tables is a defect (a bare assertion by one shared table) versus a
design (independent implementation by both sides) — and the `blocked`-discharge row is the
narrowed, design case the header itself distinguishes from the `partial`-with-neither row that
*was* converged. Because the fallback is strictly more conservative (it never discharges at all),
nothing in Item 2's remedy requires touching the fallback table, and the existing Group 13 parity
fixture (which asserts `not_started`/`researching` parity only, never `blocked`) needs no new
assertion to keep passing.

**`next_action_hint` is confirmed dead on both the write and read side.** `grep -rl
"next_action_hint"` across the source store returns exactly five files:
`validate-handoff.sh`, `test-handoff-reader-parity.sh`, `docs/architecture/handoff-schema.md`,
`context/patterns/system-defect-discrimination.md`, and the JSON schema itself. No agent file
(`general-implementation-agent.md`, `reviser-agent.md`, `lean-implementation-agent.md`) writes
it. `test-handoff-reader-parity.sh`'s own header states plainly that the field was retired from
that suite because "neither field has a live reader in either file any more" — confirming it by
the test suite's own prior audit, not only by this research's fresh grep. This closes the
question of whether a cheap substring match on free-text `next_action_hint` prose could serve as
a stopgap: there is no live-written prose to match against today, so option (i) would start from
zero adoption on both ends, not merely add a router.

### The multi-task state file is not what `orchestrate-triage-classify.sh` reads

This is the one correction to the dispatch's own stated premise (see Executive Summary for the
ground-overturned/outcome-preserved framing). `orchestrate-triage-classify.sh`'s own header
states its allowed reads explicitly: `specs/state.json`, the archive's state file, and — for
`partial`/`blocked` candidates only — that candidate's own `.orchestrator-handoff.json`. It never
opens the per-invocation multi-task state file (`specs/.orchestration/.orchestrator-multi-
state-{session_id}.json`) where `aux_pending` lives; that file is loaded into `mt_json` only
inside `orchestrate-cycle-plan.sh` itself, at the `mt_get`/`mt_set`/`mt_save` definitions (around
line 676), well before the triage-classify call (line 1791) and well before the triage-group
assignment loop finishes (line 1829). This means `mt_json`/`aux_pending[t]` *is* in scope,
readably, at exactly the point right after `triage_group[$t]` is fully populated from either
engine (line 1829) and right before the forced-phase/`effective_group` loop begins (line 1842) —
but it is in scope to `orchestrate-cycle-plan.sh`, not to the classifier script.

## Decisions

1. **Item 1 remedy: shape (a), confirm-then-clear**, with the clear point moved from hop 2
   (unconditional emission-time clear at line 1466) to hop 4 (the carrier-success branch at
   lines 1407-1415, which must gain `aux_clear_pending[t]="true"` alongside its existing
   `aux_consume_blocker_file[t]="true"`) **and** to the existing escalation-cap branch (lines
   1459-1463, which already sets the clear — this path is unchanged). Reason: this is the
   minimal-diff shape that makes `aux_pending[t]` an honest "is there still an open obligation"
   signal across cycles, which Item 2's remedy (below) depends on reading. Shape (b)
   (synthesize a minimal carrier from the fork's own return text) was rejected because `fork`
   dispatches run with `orchestrator_mode: false` and return prose, not a structured payload the
   orchestrator script can read without an intermediate parse step of unknown reliability — it
   would trade one unverified channel for another. Shape (c) (fail loud, no retry) was rejected
   as the sole mechanism because it discards the chain's existing, working retry behavior
   (`MAX_BLOCKER_ESCALATIONS` already exists specifically to allow more than one attempt) for no
   benefit; shape (c)'s audibility bar is adopted as a *requirement layered onto* shape (a) at
   the cap (see Decision 2), not as the chosen top-level shape.
2. **The escalation counter's increment point is unchanged.** It already increments once per
   actually-launched fork (line 1572-1574), which is the correct semantic for "how many attempts
   has this invocation spent on this obligation" once the clear point moves per Decision 1. No
   new counter is introduced.
3. **At the cap** (`blocker_escalation_count[t] >= MAX_BLOCKER_ESCALATIONS`, line 1459), in
   addition to the existing stderr line (line 1460), the remedy must add: (a) an
   `issue-record.sh` call (`--class "orchestration defect"` or an equivalently named class,
   non-fatal) naming the task and the absent carrier path, and (b) an `out_blocked_rows` entry
   (the mechanism every other audible-stop condition in this file already uses — e.g. lines 1688,
   1692, 1717, 1745) so the absence is visible in the cycle's own JSON output, not only in
   stderr. This directly satisfies the dispatch's audibility bar ("no stderr notice, no
   issue-log entry, no blocked[] row, no state field" today) at the one point where the chain
   gives up.
4. **Item 2 hook: shape (ii) as corrected** — key the predicate on chain state
   (`aux_pending[t].kind == "blocker-research"`), but place the check in
   `orchestrate-cycle-plan.sh`'s own triage-group post-processing (immediately after line 1829,
   before the forced-phase loop at line 1842), not inside `orchestrate-triage-classify.sh`. This
   corrects the ground stated in the dispatch's option (ii) (see Findings, "the multi-task state
   file is not what orchestrate-triage-classify.sh reads") while preserving the outcome the
   dispatch recommends weighing: no handoff-schema change, dependent on Item 1's remedy landing
   first (an un-cleared `aux_pending[t]` is exactly the obligation signal this check reads), and
   cheaper than shape (i). Shape (i) (constrained `next_action_hint` vocabulary) was rejected: it
   has zero live writers today (Findings), so adopting it costs not only the schema/validator/doc
   update the dispatch already names but the *first-ever* adoption by every writer, for a signal
   that duplicates information `aux_pending` already carries once Item 1 lands. Shape (iii) (key
   on `.plan-revised.json`'s `revised_at` directly, compared against "the dispatch that blocked
   it") was rejected as the sole mechanism because it requires persisting a NEW reference
   timestamp (the blocking dispatch's own `dispatch_start_ts`) somewhere the planner can read it
   later — a new field, not reuse of an existing one — for no case Decision 4's chosen hook does
   not already cover: `plan-revision-notification.md`'s own design states the sentinel's
   freshness rule is intra-cycle and reader-mediated by the *implement agent itself*, not
   intended for cross-cycle planner consumption; repurposing it that way is a second, different
   use of the same file this research did not find already load-bearing elsewhere.
5. **Placement is NOT inside `orchestrate-triage-classify.sh`.** Keeping the override outside the
   classifier means the live/fallback parity concern (acceptance criterion 4) is structurally
   satisfied without touching either table: the override applies identically to whichever
   engine's `triage_group[$t]` value it receives, so no new divergence between the two tables is
   introduced, and the existing Group 13 parity fixture needs no change.
6. **Forcing-flag interaction**: because the override (Decision 4) is applied before the
   forced-phase/`effective_group` loop (line 1842), and that loop already ignores `triage_group`
   entirely whenever `force_phases_remaining[t]` is non-empty, an explicit `/orchestrate
   --implement` (or the admit-once-for-a-held-task path) continues to admit one dispatch exactly
   as today, with no code change needed to preserve that behavior. The remedy adds one thing: a
   stderr warning, emitted at the point `forced_phase` is assigned (around line 1851), when the
   task being force-admitted also carries an outstanding `aux_pending[t].kind ==
   "blocker-research"` obligation — stating explicitly that the override is bypassing an owed
   revision, satisfying the dispatch's "it must be stated and tested rather than left to the
   reader" requirement.
7. **The `blocker-research`/`plan-revision` prompt insistence asymmetry is not deliberate** and
   should be corrected alongside Item 1: add a parallel (not necessarily identical) insistence
   clause to the `blocker-research` prompt in `orchestrate-build-aux-dispatch.sh` (line 215),
   naming the carrier path and stating the write is required regardless of what the fork's own
   return text says, mirroring the `plan-revision` prompt's existing clause in spirit.

## Recommendations

- Implement Decision 1 by: removing the unconditional `aux_clear_pending[t]="true"` at line 1466
  (the `blocker-research)` case arm) and adding `aux_clear_pending[t]="true"` to the carrier-
  success branch (lines 1407-1415, alongside `aux_consume_blocker_file[t]="true"`). Verify by
  extending `tests/test-orchestrate-cycle-plan.sh`'s existing Group 10 (Cases A/B/F, lines
  979-1163) with a new case: seed `aux_pending[t]=blocker-research`, run once with no
  `.blocker-research.json` present, assert `aux_pending[t]` is **still present** afterward
  (currently it would be absent — this is the failing-first assertion), then run a second cycle
  and assert a fresh `blocker-research` row is emitted again (re-emission), and a third time at
  the cap to assert the new `out_blocked_rows`/issue-log behavior from Decision 3.
- Implement Decision 4 by inserting the post-triage override loop between the existing lines 1829
  and 1831 (see Findings for the exact seam), reading `mt_get --arg t "$t"
  '.aux_pending[$t].kind // ""'` and downgrading `triage_group[$t]` to `needs_human` with a named
  reason when the result is `"blocker-research"`. Extend `tests/test-orchestrate-cycle-plan.sh`
  with a failing-first case: a `blocked` task, `previous_status=implementing`, dependencies all
  `completed`, handoff `blockers[]` empty (today's exact discharge-eligible shape), plus a seeded
  `aux_pending[t]=blocker-research` — assert the dispatch is `needs_human`, not `implement`
  (fails against the unmodified script, which would discharge to implement). Add a second case
  with `--force-phases implement` (or the single-task `--implement` equivalent exercised through
  this engine) on the same fixture, asserting the implement dispatch still fires AND the new
  stderr warning from Decision 6 is present.
- Extend `tests/test-orchestrate-build-aux-dispatch.sh` (which already asserts the
  `plan-revision` prompt's unconditional sentinel clause at lines 208-215/223-230) with a mirror
  assertion for the `blocker-research` prompt's new insistence clause (Decision 7), following the
  same `grep`-the-dispatch-file pattern the existing assertions already use (line 180-183).
- Update `docs/architecture/orchestrate-state-machine.md`'s `blocked, discharged` row (line 36)
  and its aux-dispatch section (lines 760-775) to state, in writing, both the carrier-confirmation
  behavior (an unresolved blocker-research escalation is retried up to the cap, then surfaced
  loud) and the implement-readmission guard (a discharge to `implement` is withheld while that
  escalation is outstanding), satisfying acceptance criterion 6 directly — this document already
  describes the *current* (defective) discharge behavior accurately, so the edit is additive
  narrowing of an existing row, not a rewrite.
- State the forcing-flag override behavior in whichever document carries Item 2's narrative (the
  state-machine doc and/or a context pattern file, implementer's choice) as: *"an explicit forcing
  flag admits one dispatch regardless of an outstanding blocker-research escalation; the
  admission is logged as an override, not silently granted."*
- Treat the unreachable sibling record (`plan_self_consistency_and_artifact_existence`, Context &
  Scope above) as a planning-phase note rather than a research blocker: if the plan-authoring
  phase can locate it under a renumbered task id, read it before authoring the `## Lean Challenge
  Statements`-adjacent prose (not applicable here, since this task is script-only) or any prose
  about which artifact names the "sanctioned carrier" — otherwise proceed on this record's own
  findings alone, since no dependency edge was declared.

## Risks & Mitigations

- **Risk**: moving the `aux_pending[t]` clear to hop 4 could leave a permanently-stuck entry if a
  task's chain is abandoned mid-flight (e.g., the task is manually re-pointed to a different
  blocker without ever confirming or exhausting the old one). **Mitigation**: the existing
  escalation cap already bounds this to `MAX_BLOCKER_ESCALATIONS` (2) attempts per invocation
  before Decision 3's loud-stop clears it; across separate invocations the counter resets (per
  `orchestrate-loop-guard-init.sh`), so a stuck entry is retried, not permanently wedged, on the
  next `/orchestrate` run, and surfaces in `blocked[]` well before that.
- **Risk**: the post-triage override (Decision 4) could mask a *legitimately* resolved blocker
  whose `aux_pending[t]` entry was never cleared due to an unrelated bug in Decision 1's own
  implementation, creating a new stuck-forever-at-`needs_human` failure mode. **Mitigation**:
  this is exactly why Decision 1 must land first and be tested to confirm the carrier-success
  branch's new clear is reached in the ordinary (working) case before Decision 4 is exercised;
  the failing-first tests recommended above test both directions (stuck-when-unconfirmed and
  cleared-when-confirmed) rather than only the defect case.
- **Risk**: adding a stderr warning at the forced-phase admission site (Decision 6) without a
  corresponding assertion could regress silently. **Mitigation**: explicitly called out as a
  required test in Recommendations above, not left as an unverified prose claim.

## Context Extension Recommendations

- **Topic**: `orchestrate-state-machine.md`'s `blocked, discharged` row.
  **Gap**: the row currently documents only the dependency/handoff-blockers discharge condition,
  with no mention of the blocker-research/plan-revision chain obligation this task adds as a
  further discharge precondition.
  **Recommendation**: narrow the existing row's prose in place (see Recommendations above) rather
  than adding a new document — this is the single place a future reader would look first.

## Appendix

- Search queries used (exact): `grep -n "aux_pending" scripts/orchestrate-cycle-postflight.sh`;
  `grep -n "aux_pending\|aux_clear_pending\|blocker_escalation_count\|MAX_BLOCKER_ESCALATIONS\|aux_consume_blocker_file\|aux_blocker_file" scripts/orchestrate-cycle-plan.sh`;
  `grep -n "blocked\|previous_status\|discharge\|blocker_count\|continuation_ok\|age_min\|next_action_hint" scripts/orchestrate-triage-classify.sh`;
  `grep -n "previous_status\|needs_human\|\"blocked\"" scripts/orchestrate-cycle-plan.sh`;
  `grep -rln "next_action_hint" agent-system/extensions/core`;
  `grep -n "blocker-research\|plan-revision" scripts/tests/test-orchestrate-build-aux-dispatch.sh`;
  `grep -n "MAX_BLOCKER_ESCALATIONS\|blocker_escalation_count\|blocker-research" scripts/tests/test-orchestrate-cycle-plan.sh`;
  `grep -n "blocker_escalation_count" scripts/*.sh`.
- `.claude-extensions.json`'s `.extensions.core.source_dir` resolved to
  `/home/benjamin/.config/nvim/agent-system/extensions/core` at the time of this research,
  matching the dispatch's own stated reading.
- The sibling-record lookup attempts (for the record, not a completeness claim about the whole
  task space): `jq` queries against `specs/state.json`'s `.active_projects[]` and
  `.completed_projects[]` for `project_name == "plan_self_consistency_and_artifact_existence"` and
  `project_number == 827`; directory globs under `specs/`, `specs/archive/`, and `specs/vault/`
  for the slug. All returned empty.
