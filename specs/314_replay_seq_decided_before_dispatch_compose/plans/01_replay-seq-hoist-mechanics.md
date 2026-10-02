# Implementation Plan: Task #314

- **Task**: 314 - Make the unconsumed-dispatch replay decide its dispatch_seq BEFORE the seq is minted and before the dispatch file is composed
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None (deliberately; non-concurrency constraints only -- see Risks)
- **Research Inputs**: specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md
- **Artifacts**: plans/01_replay-seq-hoist-mechanics.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The unconsumed-dispatch replay branch in `orchestrate-cycle-plan.sh` currently rewrites
`mt_json.dispatch_seq[$t]` roughly 140 lines after `orchestrate-build-dispatch.sh` already
composed the dispatch file with a freshly minted seq, so the file and the state disagree and
every downstream seq check (handoff, `.return-meta.json`) fails against a correct dispatch --
silently losing the status transition. This plan hoists the replay decision above the mint so
exactly one seq is ever in play, adds a post-compose consistency assertion as a loud backstop,
and extends Group 19 of `test-orchestrate-cycle-plan.sh` -- which today inspects only state
files and never the composed dispatch file, which is precisely why the defect shipped green.
Definition of done: all eight ACCEPTANCE items in the dispatch hold, with the new coverage
demonstrated RED against unfixed source before the fix lands.

### Research Integration

The report confirms every line anchor in the dispatch against current source (mint at
`:2541-2544`, `build_args` at `:2579`, `dispatch_file=` read-back at `:2649`,
`orchestrate-build-dispatch.sh:385`/`:400`, hash-strip at `:1997-2001`) and establishes three
mechanics findings this plan builds on directly:

1. **The hoist is unobstructed.** `$g` is set at `:2507` (first line of the dispatch-building
   loop body); `pending_dispatch_seed[$t]` is populated at `:1237` and `forced_this_cycle[$t]`
   at `:1697-1710`, both in earlier loops. The forced-phase pop at `:2546-2548` *reads*
   `forced_this_cycle[$t]` but never mutates it, so it neither depends on nor interacts with the
   replay decision. Insertion point: immediately after the lock-acquire block closes (`:2537`),
   before section (i).
2. **DELIVERABLE 1b resolves by construction, not by patching.** Under a correct hoist the
   replay path never calls `mt_get '(.dispatch_seq_counter // 0) + 1'` at all, so there is no
   minted-but-discarded global value to leak and nothing to flush. `--flush-seq` is confirmed to
   be called only on the non-replay branch, both today and after the fix.
3. **The counter leak lives in the EPHEMERAL counter, not the durable file.** The report
   corrects a premise in the dispatch's DELIVERABLE 3: the flagged Group 19 assertion at
   `:2587` reads the *durable* `.orchestrator-loop-guard` `dispatch_seq_counter`, and that value
   is genuinely unchanged by a replay both before and after the fix. The real leak is
   `mt_json.dispatch_seq_counter` (bumped by today's unconditional mint, never reverted by the
   replay branch) -- a value no Group 19 assertion reads. This changes the shape of the argued
   correction required by ACCEPTANCE #7: see Phase 5 and the Decisions note below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are included.

## Decisions Settled At Plan Time

These two points were flagged by the research report as requiring a plan-time ruling rather than
mid-implementation discovery. Both are now settled; implementation must not re-open them.

**D1 -- "ALL FOUR agree" scope (report Recommendation 4 / Risk 1): option (b)-minimal.** Group 19
will demonstrate all four legs literally, within this task's own file scope, without editing any
postflight-owned file:

- *Leg 1 (dispatch file Identity)* and *Leg 2 (`mt_json.dispatch_seq[$t]`)*: direct assertions.
- *Leg 3 (`.return-meta.json`)*: fabricate a `.return-meta.json` whose `dispatch_seq` is read
  **from the composed dispatch file's Identity block** (exactly what a real agent does -- the
  observed incident had the agent resolve in favour of the file), then invoke the REAL,
  unmodified `orchestrate-recover-outcome.sh <task_dir> <window_start_ts> <expected_seq>` with
  `<expected_seq>` taken from `mt_json.dispatch_seq[$t]`, and assert the emitted record carries
  `recovered=true` and reason not `META_DISPATCH_SEQ_MISMATCH`. That script is read-only here and
  is in no sibling task's `file_scope`.
- *Leg 4 (handoff)*: postflight's handoff check is a plain equality between the handoff's
  `dispatch_seq` and `mt_json.dispatch_seq[$t]`. Replicate that equality inline over a fabricated
  handoff whose seq is likewise read from the composed dispatch file. Do not edit, source, or
  invoke `orchestrate-cycle-postflight.sh`.

Option (a) (two legs plus a prose cross-reference) is rejected: ACCEPTANCE #1 and #6 ask for a
demonstration, and option (b)-minimal delivers one at no territory cost.

**D2 -- ACCEPTANCE #2 and #3 are demonstrated via Leg 3, not via `state.json`.** Group 19 stubs
`update-task-status.sh` to a bare `exit 0`, so a literal `state.json` transition cannot be
observed in this suite, and making it observable would mean rebuilding postflight's whole
transition path inside a plan-side fixture. Leg 3's `recovered=true` IS the mechanical
precondition that failed in the incident: postflight attempts no transition at all when
`have_outcome=false` (`orchestrate-cycle-postflight.sh:671-679`), and `have_outcome` is gated
solely on recovery succeeding. ACCEPTANCE #3 (no redundant re-plan) follows from #2 with no
independent mechanism. Record this reasoning in the test comment and in the report; do not widen
scope into postflight to chase a more literal reading.

## Goals & Non-Goals

**Goals**:
- Exactly one `dispatch_seq` value exists per replayed row, across the composed dispatch file's
  `## Identity` block, `mt_json.dispatch_seq[$t]`, the handoff seq check and the
  `.return-meta.json` seq check (ACCEPTANCE #1, #2, #3).
- `dispatch_seq_counter` left consistent after a replay by construction: no double-mint, no
  durable/in-memory divergence, no later run able to re-mint a value already used as a dispatch
  filename (ACCEPTANCE #4).
- A composed dispatch file whose Identity seq disagrees with state produces a DEFERRED row with
  an explicit reason, never a dispatch (ACCEPTANCE #5).
- Extended Group 19 coverage that FAILS against current source and PASSES after the fix,
  constructed so it cannot pass vacuously (ACCEPTANCE #6).
- The revised Group 19 assertion carries recorded reasoning for why the prior framing encoded
  the defect (ACCEPTANCE #7).
- Full suite green and shellcheck clean (ACCEPTANCE #8).

**Non-Goals**:
- Any edit to `orchestrate-cycle-postflight.sh`, its tests, `skill-orchestrate/SKILL.md`,
  `orchestrate-state-machine.md`, or `commands/orchestrate.md` -- a concurrent sibling owns all
  five this cycle (see Territory in the dispatch).
- Re-litigating the fix shape. DELIVERABLE 1 option (a) is settled; the reuse-the-recorded-file
  alternative is rejected on verified per-cycle-varying-input grounds (`--territory`, `--focus`,
  `--phase-number`, `--dispatch-start-ts`, `--model`).
- Touching Group 18 (in-session `plan_cache` replay) or Group 24 (`prior_*` pre-image fields) --
  both confirmed unaffected and already correct.
- Any change to `cycle_plan_dispatch_hash` or the identical-dispatch hash guard.
- Writing a new test suite. Group 19 is extended in place.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New Group 19 assertions pass vacuously -- the new stub echoes back whatever seq it is handed, so the Identity check could be green regardless of the hoist | H | M | Phase 1 is a dedicated RED-first phase: run the extended suite against UNFIXED source and record the observed failure text (file says the minted seq, state says the replayed one) before Phase 2 begins. ACCEPTANCE #6 is not satisfiable without this evidence. |
| Sibling task edits `orchestrate-cycle-plan.sh` concurrently (six live tasks declare it in `file_scope`) | H | L | The dispatch states this task must not be batched with 311, 299, 272, 265, 250 or 165; none of them appear in this cycle's Territory block. Per the concurrency note: re-read each file immediately before editing, stage only this task's own hunks, never a directory or glob `git add`, never reverting `git-snapshot.sh`. |
| Line anchors drift if task 250's decomposition of this script lands first | M | L | All anchors re-verified against current source during research and again at the start of Phase 2 by grepping for the code text (not by line number). Whichever of the two lands second carries the other's change along; they must not run concurrently. |
| Hoisting the decision above `skill_preflight_update` changes behaviour on a non-replay path | M | L | The decision block is pure computation over three already-populated inputs with no side effects; the only mutating statement (`mt_set .dispatch_seq[$t]`) folds into the existing section (i) `mt_set`, and the charging side effects that need `$dispatch_file` stay at their current position. Verify by diff review that the hoisted block contains no `mt_set`, no `orchestrate-loop-guard-init.sh` call, and no logging. |
| `set -uo pipefail` / shellcheck regression from new variables | L | M | Follow the file's existing conventions mechanically: `"${array[$t]:-default}"` for every array read, `--arg`/`--argjson` for all jq interop. Run shellcheck in Phase 4. |
| Weakening a currently-green test, which task 265 forbids | H | L | Phase 5 KEEPS the existing durable-counter assertion (still true post-fix) and ADDS the ephemeral-counter assertion that actually demonstrates the fix, with the necessary-but-insufficient reasoning recorded in the test comment and the report. Nothing is relaxed or deleted. |

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

Phases within the same wave can execute in parallel. This plan is fully sequential: Phases 2 and
3 edit adjacent regions of the same file, and Phase 1 must be observed RED before Phase 2 changes
the behaviour it probes.

---

### Phase 1: RED-first -- extend Group 19 case 1 to inspect the composed dispatch file [COMPLETED]

**Goal**: Make the four-legged seq agreement observable in Group 19 case 1, and demonstrate the
extended coverage FAILS against current, unfixed source -- the evidence ACCEPTANCE #6 requires.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` around
      Group 19 (`:2528` onward) immediately before editing, per the cycle's concurrency note. *(completed)*
- [x] Replace Group 19's two-line `orchestrate-build-dispatch.sh` stub (`:2538-2541`) with one
      that (a) parses its own `--seq N` argument out of argv the way the real script receives it
      from `build_args`, (b) writes a real file at a real path under
      `$WORKDIR/specs/1901_g19_pending/.dispatch/${seq}.md` containing a `## Identity` section
      with a `- dispatch_seq: ${seq}` line byte-compatible with `orchestrate-build-dispatch.sh:400`,
      and (c) emits `{dispatch_file: <that real path>, model: ""}`. Keep the stub minimal -- it
      must not reimplement any other part of the real script. *(completed)*
- [x] Add Leg 1 assertion: the composed dispatch file's `- dispatch_seq:` Identity line equals
      the replayed seq (3 in the case-1 fixture). *(completed)*
- [x] Add Leg 2 assertion already present in spirit at `:2583` -- keep it, and assert Leg 1 and
      Leg 2 are equal to each other explicitly, so neither can drift silently. *(completed)*
- [x] Add Leg 3: fabricate `$WORKDIR/specs/1901_g19_pending/.return-meta.json` with
      `dispatch_seq` read FROM the composed dispatch file's Identity line (not from the state
      file -- that is what makes the assertion non-vacuous), then run the real
      `orchestrate-recover-outcome.sh <task_dir> <window_start_ts> "$(jq -r --arg t 1901 '.dispatch_seq[$t]' "$g19_mt_state_1")"`
      and assert `recovered=true` and reason not `META_DISPATCH_SEQ_MISMATCH`. *(completed)*
- [x] Add Leg 4: fabricate a handoff JSON whose `dispatch_seq` is likewise read from the composed
      file, and assert equality against `mt_json.dispatch_seq[1901]` -- the same predicate
      `orchestrate-cycle-postflight.sh` applies when it decides whether to consume a handoff. *(completed)*
- [x] Add the ephemeral-counter assertion: `jq -r '.dispatch_seq_counter' "$g19_mt_state_1"`
      equals 3 (NOT 4) after a replay. *(completed)*
- [x] Copy `orchestrate-recover-outcome.sh` into the fixture's synthetic `.claude/scripts/` tree
      if the suite's existing collaborator-copy loop does not already cover it, and add it to the
      `require_file` list so a missing collaborator is an environment error (exit 2), never a
      silent skip. *(completed: also copied the transitive return-meta-status-vocabulary.sh lib dependency)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` and
      capture the failing output verbatim into the task's scratch notes. Confirm the failures are
      genuine FAILs (assertion mismatch), not exit-2 environment errors or skipped cases. *(completed: exit 1, 330 passed, 5 failed; see progress/phase1-red-evidence.log)*
- [x] Commit the red test with its captured failure evidence referenced in the commit body. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes Group 19 case 1 spans roughly `:2563-2606` and that its
`$g19_mt_state_1` variable is already in scope at the point the new assertions are added (the
report confirms it is, assigned at `:2592`). It also assumes the suite's collaborator-copy loop
does not yet include `orchestrate-recover-outcome.sh`. Confirm all three by reading the file
before editing; if `orchestrate-recover-outcome.sh` is already copied, drop that sub-step rather
than duplicating the copy.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new stub that
  writes a real Identity block; four-leg seq agreement assertions; ephemeral-counter assertion;
  collaborator copy/require for `orchestrate-recover-outcome.sh`

**Verification**:
- The extended suite runs to completion and reports at least two new FAILs attributable to the
  seq disagreement (Identity-vs-state, and the ephemeral counter at 4).
- Exit code is 1 (assertion failure), not 2 (environment error).
- No pre-existing Group 19 assertion changed its verdict as a side effect of the stub change.

---

### Phase 2: Hoist the replay decision above the mint; make the mint branch-conditional [COMPLETED]

**Goal**: Decide the replayed seq before it is minted, so `orchestrate-build-dispatch.sh`
composes the dispatch file with the one and only seq for the row (DELIVERABLE 1), and leave the
counter consistent by construction (DELIVERABLE 1b).

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` `:2500-2560` and
      `:2755-2800` immediately before editing. Locate the anchors by grepping for the code text,
      not by line number. *(completed)*
- [x] Move the decision computation -- `_pd_forced_this_cycle`, `_pd_replay`, `_pd_phase`,
      `_pd_forced`, `_pd_dispatch_file`, and the `_pd_replay=true` predicate -- from its current
      position to immediately after the lock-acquire block closes and before the section (i)
      comment. Move it verbatim; do not restructure the predicate. *(deviation: altered -- an
      extra guard condition was added: `_pd_replay` is now also gated on
      `mt_json.last_dispatch_hash[$t]` being empty, i.e. this session has not already dispatched
      this task this run. Discovered via the plan's own RED-first/full-suite methodology: hoisting
      verbatim regressed Group 28 (identical-dispatch halt) by letting a same-session repeat of
      identical content be misclassified as a cross-process replay, which then recomposed ON TOP
      OF the prior cycle's own dispatch file at the same seq-derived path, which Fix 2's halt then
      deleted. Pre-hoist this never collided because Fix 2 always ran first (against a freshly
      minted seq) and could `continue` before the old, later-positioned replay check was ever
      reached -- an accidental ordering shield the hoist removes. The added condition restores the
      intended in-session/cross-invocation boundary the header comments already draw, using data
      Fix 2 already maintains (no new field). See the code comment at the decision block and the
      report's "Argued correction, as implemented" note for the full reasoning. Full suite:
      335 passed, 0 failed after this correction; 1 failed (Group 28) without it.)*
- [x] Also hoist the `_pd_seq` read (`jq -r '.seq'`) into that block, guarded by
      `_pd_replay=true`, so the seq is available to the mint branch. *(completed)*
- [x] Rewrite section (i) as a two-way branch:
      - replay: `task_dispatch_seq="$_pd_seq"`; `task_dispatch_start_ts=$(date -u +%s)`; one
        `mt_set` writing `.dispatch_start_ts[$t]` and `.dispatch_seq[$t]` ONLY -- explicitly never
        `.dispatch_seq_counter`, and never calling `mt_get '(.dispatch_seq_counter // 0) + 1'`.
      - non-replay: today's three-field mint, byte-for-byte unchanged. *(completed)*
- [x] Update the section (i) comment to state the invariant plainly: on a replay no global seq is
      consumed, so the durable `.orchestrator-loop-guard` counter and the in-memory
      `mt_json.dispatch_seq_counter` agree by construction and `--flush-seq` is correctly skipped.
      Note the global-vs-per-task split (`mt_json.dispatch_seq_counter` is one global scalar;
      `.orchestrator-loop-guard`'s is per-task) that the report flagged as undocumented.
      *(completed)*
- [x] At the original location, delete the now-duplicated decision computation and the
      `mt_set .dispatch_seq[$t]` / `task_dispatch_seq="$_pd_seq"` rewrite. Keep the branch itself:
      it still owns `task_new_cycle_count`, the REPLAY log line, `--flush-seq`, the `prior_*`
      pre-image capture and `--record-pending`, all of which need `$dispatch_file`. It now simply
      branches on the already-computed `_pd_replay`. *(completed)*
- [x] Amend the comment block above that branch so it no longer implies the decision is made
      there, and so it records that the decision was hoisted specifically because the dispatch
      file is composed between the two points. *(completed)*
- [x] Verify by diff review that the hoisted block performs no mutation, no logging, and no
      `orchestrate-loop-guard-init.sh` call. *(completed: the block reads mt_json/pending_dispatch_seed
      and $g only; the one `mt_get` call is a pure read)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the decision block is relocatable verbatim because all three of its
inputs (`pending_dispatch_seed[$t]`, `forced_this_cycle[$t]`, `$g`) are populated before the
dispatch-building loop starts, and that the forced-phase pop does not interact with it. Confirm
at implementation time by grepping for every assignment to those three names and checking none
lies between the lock acquire and the current decision site.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - decision block hoisted above
  section (i); section (i) mint becomes a two-way branch; original branch stripped to its
  `$dispatch_file`-dependent side effects; two comment blocks amended

**Verification**:
- `bash -n` parses clean.
- Group 19 case 1's Leg 1/Leg 2 and ephemeral-counter assertions from Phase 1 now pass.
- Group 19 cases 2 and 3 (phase mismatch, missing dispatch file) still pass unchanged -- the
  non-replay path must be byte-for-byte equivalent in behaviour.
- `grep -c 'dispatch_seq_counter = \$seq'` shows the counter write survives only on the
  non-replay branch.

---

### Phase 3: Post-compose Identity-vs-state consistency assertion [COMPLETED]

**Goal**: Make the whole defect class non-silent independently of whether the hoist is perfect --
a composed dispatch file disagreeing with state defers the row loudly instead of dispatching
(DELIVERABLE 2, ACCEPTANCE #5).

**Tasks**:
- [x] Insert the assertion immediately after `dispatch_model_json` is assigned (just past the
      `dispatch_file=` / `dispatch_model=` read-back) and BEFORE the Fix 2 identical-dispatch hash
      block begins. *(completed)*
- [x] Parse the Identity value directly off the file:
      `grep -m1 '^- dispatch_seq: ' "$dispatch_file"` piped through `sed 's/^- dispatch_seq: //'`
      (or equivalent). Never route this through `cycle_plan_dispatch_hash` -- its strip regex
      deliberately removes the `dispatch_seq`/`dispatch_start_ts` lines before hashing, which
      would make the check vacuous by construction. *(completed: guarded with `|| _idc_identity_seq=""`
      since under `set -e`/`pipefail` a no-match grep would otherwise abort the whole script --
      discovered via the full-suite RED run, see deviation note below)*
- [x] Compare against the in-memory `$task_dispatch_seq`. On disagreement, push an
      `out_deferred_rows` entry with an explicit reason naming both values, then `continue` --
      matching the existing idiom used three lines above for the `build_exit -ne 0` case.
      *(completed)*
- [x] Handle a missing or unparseable Identity line as a disagreement (defer loudly), not as a
      pass. An unreadable file is exactly the situation this backstop exists for. *(completed)*
- [x] Add a comment recording that this check must not disturb the identical-dispatch hash and
      why it cannot be implemented on top of the hash helper. *(completed)*
- [x] Confirm the deferred-row reason string is distinct enough to be greppable in a test.
      *(completed: "disagrees with this cycle's decided dispatch_seq" is unique in the file;
      verified via a manual perturbation run -- see Verification below)*

**Deviation (discovered via full-suite RED/GREEN runs, not anticipated by the plan's Files-to-
modify list, which named only `orchestrate-cycle-plan.sh`)**: adding a production check that
reads the COMPOSED dispatch file's own content exposed that MOST of this suite's pre-existing
`orchestrate-build-dispatch.sh` stubs (8 of the 9 definitions, everywhere except Group 19's own
Phase 1 stub) return a notional `/fake/<n>-<phase>.md` path that is never actually written to
disk -- harmless for every feature before this one (nothing previously read the file's content
back except `cycle_plan_dispatch_hash`, which degrades gracefully on a missing file), but fatal
to DELIVERABLE 2's "missing Identity line is a loud disagreement, never a pass" contract. Fixing
this required (a) upgrading all 8 stubs, in
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`, to parse `--seq` and
write a real, writable file (`$WORKDIR/fake-dispatch/<n>-<phase>.md`) with a byte-compatible
`## Identity` / `- dispatch_seq:` line -- the same convention Group 19's own Phase 1 stub already
established -- and (b) updating the 5 pre-existing assertions in Groups 15/16/18 that checked the
old literal `/fake/<n>-plan.md` string. This in turn surfaced two further, genuinely separate
discoveries, each argued and fixed in place rather than weakening any assertion:
1. Group 18 (in-session plan_cache) dispatches the SAME candidate/phase twice across genuinely
   separate charges (run 1, and run 3 after cache invalidation) with nothing else to vary, so a
   now-realistic stub made the two compositions hash byte-identical and trip Fix 2's UNRELATED
   identical-dispatch streak guard -- a false collision between two mechanisms the plan's own
   Non-Goals keep independent. Fixed by embedding a per-call nonce (PID + nanosecond timestamp)
   in a line Fix 2's hash normalizer does not strip, matching how real territory/focus/timestamps
   vary call to call in production.
2. The G8 budget group's own "dispatch_seq_counter must durably increase across two separate
   runs on the same task" case dispatched the SAME task twice via two different sessions with
   run 1's dispatch file never consumed in between -- which, correctly, is now recognized as an
   UNCONSUMED DISPATCH REPLAY (this task's own fix) and legitimately reuses the seq rather than
   minting a new one. That is not the kind of repeat this invariant forbids (reusing a seq for a
   genuinely NEW, separately-charged dispatch); it is the single pending dispatch being
   recomposed in place. Fixed by removing run 1's recorded dispatch file before run 2 (the same
   proof-of-non-consumption idiom Group 19 case 3 and Group 24 already use), simulating a
   predecessor's postflight having actually consumed it -- the realistic scenario this invariant
   protects.
Full suite: 335 passed, 0 failed after all three fixes; 2 failed (budget seq-no-repeat, Group 18
cycle_counts) immediately after the stub upgrade alone, 53 failed (mass `<missing>` Identity
disagreements) before the stub upgrade.

**Timing**: 45 minutes

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the insertion point sits between the `dispatch_file=` read-back and
the Fix 2 hash block with no intervening statement that must run first. Confirm by reading the
~15 lines between the two anchors before inserting.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - post-compose Identity
  consistency assertion with a deferring, explicit-reason failure path

**Verification**:
- `bash -n` parses clean.
- Temporarily perturb the Phase 1 stub to emit a deliberately wrong Identity seq and confirm the
  row is DEFERRED with the explicit reason and no dispatch row is emitted; revert the
  perturbation afterwards. Record the observed deferred-row text.
- The identical-dispatch hash guard's behaviour is unchanged (Group 18 and the hash-related
  groups still pass).

---

### Phase 4: Green the extended suite, the full suite, and shellcheck [COMPLETED]

**Goal**: Demonstrate the full ACCEPTANCE set holds -- the extended Group 19 passes, nothing else
regressed, and both touched files are strict-mode and shellcheck clean (ACCEPTANCE #6, #8).

**Tasks**:
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` in
      full and confirm zero FAILs and exit 0. *(completed: exit 0, 335 passed, 0 failed)*
- [x] Diff the pass count against the Phase 1 red run to confirm the previously-failing
      assertions are the ones that flipped, and that no assertion disappeared. *(completed:
      Phase 1 RED = 330 passed + 5 failed = 335 total; final GREEN = 335 passed + 0 failed = 335
      total -- exact match, nothing disappeared)*
- [x] Run `shellcheck` on both touched files and resolve every new finding per
      `context/standards/shell-strict-mode.md`. Pre-existing findings unrelated to this diff are
      out of scope -- note them rather than fixing them. *(completed: zero new findings on
      either file. orchestrate-cycle-plan.sh carries only 2 pre-existing SC2154 warnings at
      lines 1673/1792 (unrelated, confirmed present before this task's first commit via
      `git show 231f022f5:...`); test-orchestrate-cycle-plan.sh carries 2 pre-existing
      SC2319/SC2034 warnings at lines 3935/3937 in Group 28, also confirmed pre-existing)*
- [x] Run any sibling orchestrate test suites that exercise `orchestrate-cycle-plan.sh`
      (`test-handoff-reader-parity.sh` and any `test-orchestrate-*` suite that loads it) to catch
      cross-suite regressions. *(completed: test-handoff-reader-parity.sh,
      test-orchestrate-unwind-dispatch.sh, test-force-phases.sh,
      test-orchestrate-context-growth.sh, test-routing-resolution.sh, and
      test-mint-dispatch-seq.sh all pass -- 0 failed in every one)*
- [x] Record the before/after pass counts in the task's scratch notes for the summary.
      *(completed: Phase 1 RED 330/5 -> Phase 2 fix 334/1 -> Phase 2 correction 335/0 ->
      Phase 3 stub realism gap 282/53 -> Phase 3 fixes 309/26 -> 333/2 -> final 335/0, recorded
      in progress/phase-{1,2,3,4}-progress.json)*

**Timing**: 45 minutes

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts the only suites exercising this SUT are
`test-orchestrate-cycle-plan.sh` plus the `test-orchestrate-*` family. Confirm by
`grep -rl 'orchestrate-cycle-plan' agent-system/extensions/core/scripts/tests/` before running.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - shellcheck/strict-mode fixes
  only, if any
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - shellcheck/strict-mode
  fixes only, if any

**Verification**:
- Full suite exit 0, zero FAILs.
- `shellcheck` reports no new findings on either file.
- Sibling orchestrate suites unchanged in verdict.

---

### Phase 5: Record the argued correction [COMPLETED]

**Goal**: Satisfy ACCEPTANCE #7 -- a reviewer can see why the prior Group 19 framing encoded the
defect without reconstructing this analysis.

**Tasks**:
- [x] Revise the comment accompanying Group 19 case 1's existing durable-counter assertion to
      record the necessary-but-insufficient argument: the assertion is TRUE both before and after
      the fix (because `--flush-seq` really is skipped on a replay in both versions), so on its
      own it gave false assurance that the replay path was handled correctly; the actual leak
      lived in the ephemeral in-memory `mt_json.dispatch_seq_counter`, which this assertion never
      read, and which feeds both the composed dispatch file's seq-derived filename and the next
      invocation's re-seed. KEEP the assertion; the new ephemeral-counter assertion added in
      Phase 1 closes the sufficiency gap. *(completed)*
- [x] Add a comment above the new four-leg assertions stating why Group 19 inspects the composed
      dispatch file at all: every prior assertion in the group read only state files, which is
      exactly why a file-vs-state disagreement shipped green. *(completed: this comment was
      already authored at Phase 1 time, immediately above the Leg 1/2 assertions; verified
      present and correct rather than re-added)*
- [x] Add the D2 reasoning (Legs 3/4 stand in for the `state.json` transition because
      `update-task-status.sh` is stubbed here, and recovery succeeding is the precondition the
      transition is gated on) as a comment next to Leg 3. *(completed: likewise already present
      from Phase 1, in the same comment block and again immediately above the Leg 3 code;
      verified present and correct)*
- [x] Cite durable anchors only in these comments -- filenames, function names, section headings.
      No task-number references: this file is outside `specs/**` and
      `rules/no-task-references-in-deliverables.md` applies, as the suite's own header NOTE
      already observes. *(completed: verified via `bash .claude/scripts/check-task-references.sh
      agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` -> 0 occurrences)*
- [x] Append a short "Argued correction, as implemented" note to
      `specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md`
      recording the final wording and the D1/D2 rulings, so the report and the test comment agree.
      Task-number references are permitted there. *(completed)*

**Timing**: 30 minutes

**Depends on**: 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: None asserted -- this phase changes comments and one report section only,
with no count or file-list claim beyond the two files named below.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - revised and new
  explanatory comments only
- `specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md` -
  appended "Argued correction, as implemented" note

**Verification**:
- Diff read-through confirms every changed hunk in the test file lies inside a comment region.
- Full suite still exit 0 (comment-only change, but re-run as a cheap guard).
- `bash .claude/scripts/check-task-references.sh` (or the repo-wide lint equivalent) reports no
  new task-number occurrences outside `specs/**`.

---

### Phase 6: Deploy the fixed source into the live `.claude/` tree [NOT STARTED]

**Goal**: Make the fix live. The source store is authoritative, but the running orchestrator
executes `.claude/scripts/orchestrate-cycle-plan.sh`, which still carries the defect until a
deploy runs.

**Tasks**:
- [ ] Confirm the working tree is committed and clean for this task's own files before deploying.
- [ ] Run `bash .claude/scripts/deploy-headless.sh` (non-destructive force-resync; NOT `--wipe`).
- [ ] Confirm the deployed `.claude/scripts/orchestrate-cycle-plan.sh` and
      `.claude/scripts/tests/test-orchestrate-cycle-plan.sh` now contain the hoisted decision and
      the post-compose assertion, by grepping for the new code text in both trees.
- [ ] Run the deployed copy of the suite once
      (`bash .claude/scripts/tests/test-orchestrate-cycle-plan.sh`) and confirm exit 0 -- the
      deployed tree anchors its own `CORE_DIR`, so this is a genuinely independent run.
- [ ] Confirm no unrelated `.claude/**` churn was committed: `.claude/` is gitignored and
      regenerated, so the deploy should produce no staged changes for this task.

**Timing**: 30 minutes

**Depends on**: 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserts `deploy-headless.sh` in its default non-destructive mode suffices
and that `.claude/` is gitignored in this repo (so the deploy contributes nothing to the commit).
Confirm the latter with `git check-ignore .claude` before deploying; if `.claude/` is tracked
here, STOP and report rather than committing a regenerated tree.

**Files to modify**:
- `.claude/scripts/orchestrate-cycle-plan.sh` - regenerated by the deploy, never hand-authored
- `.claude/scripts/tests/test-orchestrate-cycle-plan.sh` - regenerated by the deploy, never
  hand-authored

**Verification**:
- Both deployed files contain the new code text.
- Deployed suite exits 0.
- `git status --short` shows no `.claude/**` entries staged for this task.

## Testing & Validation

- [ ] ACCEPTANCE #1: Group 19 case 1 asserts all four legs equal -- composed dispatch file
      Identity seq, `mt_json.dispatch_seq[1901]`, the handoff seq predicate, and
      `orchestrate-recover-outcome.sh`'s `.return-meta.json` seq check.
- [ ] ACCEPTANCE #2: Leg 3 reports `recovered=true` with reason not `META_DISPATCH_SEQ_MISMATCH`
      on the replayed path -- the precondition postflight's transition is gated on (see D2).
- [ ] ACCEPTANCE #3: follows from #2; no independent assertion (see D2).
- [ ] ACCEPTANCE #4: the ephemeral `mt_json.dispatch_seq_counter` stays at the replayed value
      (3, not 4), and the durable guard-file counter stays at 3 -- both asserted, with the
      global-vs-per-task distinction documented in the section (i) comment.
- [ ] ACCEPTANCE #5: a deliberately perturbed stub emitting a wrong Identity seq produces a
      DEFERRED row with an explicit reason and no dispatch row (Phase 3 verification, observed
      and recorded).
- [ ] ACCEPTANCE #6: Phase 1's red run captured verbatim; Phase 4's green run captured; the
      specific assertions that flipped are named.
- [ ] ACCEPTANCE #7: revised comment plus report note, both recording the
      necessary-but-insufficient argument.
- [ ] ACCEPTANCE #8: `bash scripts/tests/test-orchestrate-cycle-plan.sh` exits 0 in full;
      shellcheck clean on both touched files per `context/standards/shell-strict-mode.md`.
- [ ] Regression: Group 18 and Group 24 verdicts unchanged.
- [ ] Regression: Group 19 cases 2 and 3 verdicts unchanged.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - hoisted replay decision,
  branch-conditional mint, post-compose Identity consistency assertion
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - Group 19 case 1
  extended with a real-Identity-block stub, four-leg seq agreement assertions, an
  ephemeral-counter assertion, and the argued-correction comments
- `specs/314_replay_seq_decided_before_dispatch_compose/reports/01_replay-seq-hoist-mechanics.md` -
  appended "Argued correction, as implemented" note
- Regenerated `.claude/scripts/orchestrate-cycle-plan.sh` and
  `.claude/scripts/tests/test-orchestrate-cycle-plan.sh` (deploy artifacts, gitignored)
- `specs/314_replay_seq_decided_before_dispatch_compose/summaries/01_*-summary.md` at
  implementation completion

## Rollback/Contingency

Both source-store files are committed per green sub-step, so the contingency is a targeted
`git revert` of this task's own commits -- no working-tree-discarding operation is needed and
none should be used.

If a rollback that would discard uncommitted work becomes genuinely necessary mid-phase, take a
durable checkpoint first with `bash .claude/scripts/git-snapshot.sh --no-revert 314` (which does
not revert the working tree) and only then follow `context/contracts/recovery.md`'s rollback rung
for the reverting invocation shape, including its out-of-scope override flag. Never emit a bare
reverting `git-snapshot.sh` as a routine start-of-phase precaution.

Phase-specific contingencies:
- If Phase 2's hoist turns out to break an ordering invariant not visible in the section (i)
  comments, Phase 3's post-compose assertion alone already converts the defect from silent to
  loud (ACCEPTANCE #5), so the fix can land in two independently-valuable halves rather than
  being reverted wholesale.
- If Phase 6's deploy reveals `.claude/` is tracked rather than gitignored in this repo, STOP and
  report rather than committing a regenerated tree; the source-store change stands on its own.
