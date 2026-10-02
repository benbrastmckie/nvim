# Research Report: Task #315

**Task**: 315 - Stop `orchestrate-cycle-postflight.sh` reporting an outcome it did not persist, and make its `HANDOFF_STALE_OR_ABSENT` attribution depend on the DIRECTION of a dispatch_seq mismatch
**Started**: 2026-10-02
**Completed**: 2026-10-02
**Effort**: medium (2 independent defects, same file, no shared mechanism)
**Dependencies**: None declared (deliberately — see Batching Guidance in dispatch; non-concurrency only, not a dependency edge)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (source store — all line numbers below are against this file, not the deployed `.claude/` copy)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/commands/orchestrate.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (adjacent, not in dispatch's named 3-way list)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_orchestrate_append_detected_defect`, `skill_orchestrate_mint_dispatch_seq`)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (confirmed sole minting site for both engines)
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md (all edits target `agent-system/extensions/core/**`, never `.claude/**`)

## Executive Summary

- **Deliverable 1** (direction-aware attribution): the dispatch_seq-mismatch arm at
  `orchestrate-cycle-postflight.sh:456-474` has no direction check at all — it fires identically
  whether the handoff's `dispatch_seq` is older or newer than the cycle's minted value, and
  always attributes to `skills/skill-orchestrate/SKILL.md` (the hardcoded `attributed_path` at
  `:366`). Adding a numeric direction check at `:456` is a small, surgical change: when
  `handoff_dispatch_seq > expected_dispatch_seq`, attribute to
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (the confirmed, sole minting
  site for both engines — see Findings) with a distinguishing message and detecting-site suffix;
  otherwise keep today's behavior unchanged.
- **The 3-way documented inconsistency is real and independently reproducible**: the code
  (`:366`/`:462`/`:469`), the operator-facing table (`commands/orchestrate.md:309`), and the
  architecture doc's exoneration (`orchestrate-state-machine.md:318-322`) all disagree with each
  other on the attributed path and/or the scope of the exoneration. All three are fixable without
  touching any other task's file_scope.
- **Deliverable 2** (status honesty): `dispatch_status` (the JSON's `.status` field) is set from
  the agent's *self-reported* value in the RECOVERY_DECLINED branch (`:678`), with a comment
  candidly noting "this does NOT make the outcome recovered" — but the emitted JSON carries no
  flag saying so. A direct swap to the persisted value would break an *already-tested* contract:
  `test-orchestrate-cycle-postflight.sh`'s Acceptance (5) asserts `.status == "partial"` (the
  agent's self-report) in a case where `state.json` never transitions out of `"implementing"` —
  i.e. even a *successfully recovered* outcome can legitimately diverge from the persisted
  status (a `partial` outcome with zero blockers writes nothing by design). **Recommendation:
  add a new sibling field, do not repurpose `.status`.** This preserves the existing,
  already-verified Acceptance (5) behavior and gives callers (Move 3) a way to tell "the agent's
  own words" from "what state.json actually now says."
- Both fixes are confined to `orchestrate-cycle-postflight.sh` plus doc/SKILL.md updates; neither
  touches `orchestrate-cycle-plan.sh`'s own code (only a string literal *naming* that file), so
  this task and the concurrent sibling task 314 (which owns the minting bug itself) remain
  file-scope disjoint as the dispatch asserts.

## Context & Scope

This is a research-phase dispatch for task 315, `task_type: meta`. The task folds two
independent, same-file honesty defects discovered from one live incident
(`sess_1790944701_f94b90`) into a single task, explicitly NOT dependency-linked to 8 other live
tasks that also touch `orchestrate-cycle-postflight.sh` (non-concurrency constraint only — see
dispatch's Batching Guidance). Scope is:

1. Make the `HANDOFF_STALE_OR_ABSENT` dispatch_seq-mismatch arm direction-aware, reconcile the
   resulting 3-way documentation inconsistency, and close the test gap for the newer-than-minted
   direction.
2. Stop the emitted JSON's `.status` field from implying a state.json transition the script did
   not perform; decide between "return the persisted status" and "add a discriminating flag",
   and thread the choice through `skill-orchestrate/SKILL.md` Move 3 and its contract text,
   without degrading the existing `user_decision` relay behavior.

This report is research only — no code or doc changes were made. All recommendations below are
scoped for a subsequent `/plan`.

## Findings

### Deliverable 1 — Direction-aware attribution

**Current code shape** (`orchestrate-cycle-postflight.sh`):

- `:366` — `attributed_path="agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"`,
  a single hardcoded value used by every defect-recording call site below it in the file.
- `:425-450` (WORK (a), mtime arm) — stale-mtime gate. No `dispatch_seq` involved at all; purely
  `handoff_mtime < dispatch_start_ts`. Records `HANDOFF_STALE_OR_ABSENT` at detecting site
  `skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff`, attributed to `$attributed_path`.
  **This arm has no "direction" concept and the dispatch does not ask to change it.**
- `:452-478` (WORK (a), dispatch_seq arm) — only reached when the handoff is present and NOT
  already stale by mtime. Three sub-branches:
  - `:454-455` — `handoff_dispatch_seq` absent → WARN, degrade to mtime-only (unchanged by this
    task).
  - `:456-474` — **the mismatch arm**: `[ "$handoff_dispatch_seq" != "$expected_dispatch_seq" ]`.
    No numeric comparison — `!=` fires identically for 4≠5 (older, the suite's existing Case 2)
    and 6≠5 (newer, the incident's actual shape). Records `HANDOFF_STALE_OR_ABSENT` at detecting
    site `skill-orchestrate/SKILL.md:cycle-postflight-dispatch-seq-mismatch`, attributed to the
    same hardcoded `$attributed_path` regardless of direction.
  - `:475-476` — exact match → informational "confirmed" log line, no defect.

**Confirmed: the minting site is `orchestrate-cycle-plan.sh` for both engines.**
`skill_orchestrate_mint_dispatch_seq` is defined in `scripts/skill-base.sh:1466` but is not
called from any `.sh` file — `orchestrate-cycle-plan.sh` mints `dispatch_seq` directly via
`mt_json.dispatch_seq_counter` arithmetic (`orchestrate-cycle-plan.sh:1376-1378` for the aux path,
and the main per-task path building on the same `dispatch_seq_counter`/`dispatch_seq` multi-state
fields it seeds at `:1199-1234`). `skill-orchestrate/SKILL.md:138` reads the already-minted value
back out of `mt_state_file.dispatch_seq[$t]` — it does not mint. So "the minting script" the
dispatch refers to is unambiguously `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
for both single-task and multi-task dispatch composition today.

**Why direction matters (semantic distinction, not just cosmetic):**
- **Older** (`handoff_dispatch_seq < expected_dispatch_seq`): the handoff file was written by a
  predecessor dispatch whose own seq has since been superseded by a newer mint. The gate is
  refusing a genuinely stale artifact — correct, and the existing comment/exoneration language is
  accurate for this direction.
- **Newer** (`handoff_dispatch_seq > expected_dispatch_seq`): the handoff carries a seq value this
  cycle's own mint (`expected_dispatch_seq`) never produced. The *only* way a handoff can be newer
  than what was just freshly minted is that whoever composed/dispatched this cycle handed the
  agent a dispatch file carrying a seq from a different (typically later, in-progress-elsewhere or
  retroactively-rewritten) minting event than the one this postflight call was told to expect —
  i.e. a composition/minting-side authoring fault, not a leftover artifact from a defunct
  predecessor. Attributing this to `skill-orchestrate/SKILL.md` (which only *reads* the minted
  value, per the confirmation above) blames the wrong file; the fault is in whatever produced the
  mismatched `--dispatch-seq`/`--expected_dispatch_seq` pairing, i.e. `orchestrate-cycle-plan.sh`.

**The three-way inconsistency, confirmed line-by-line:**

| # | Location | Attributed path | Detecting site | Scope of claim |
|---|----------|-----------------|-----------------|-----------------|
| 1 | `orchestrate-cycle-postflight.sh:366` (code, both arms) | `.../skills/skill-orchestrate/SKILL.md` | `skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff` or `...-dispatch-seq-mismatch` | Applies to both arms uniformly, no direction split |
| 2 | `commands/orchestrate.md:309` (operator-facing example row) | `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` | `orchestrate-cycle-postflight.sh:stale-handoff-gate` | Names neither real detecting-site string; attributed path contradicts (1) |
| 3 | `orchestrate-state-machine.md:318-322` | (prose) `skills/skill-orchestrate/SKILL.md` — matches (1) | — | Declares the misattribution "not a bug" **wholesale**, with no direction qualifier |

Row 2's detail text ("handoff mtime predates this dispatch window") is a verbatim match for the
**mtime arm's** message (`:438`/`:444`), so row 2 is specifically about the mtime arm, not the
dispatch_seq arm — but its attributed path (`orchestrate-cycle-postflight.sh` itself) does not
match what the mtime arm's own code actually records (`skills/skill-orchestrate/SKILL.md`, same
hardcoded `$attributed_path` the dispatch_seq arm uses). This is a straightforward doc bug: the
doc's example row needs its attributed-path and detecting-site columns corrected to match the
real mtime-arm values.

Row 3's narrative (`orchestrate-state-machine.md:287-322`) is specifically about the
unwind-then-reopen-a-fresh-window scenario — a fresh dispatch window opened over a handoff that
is **valid and complete but older** than the new window. That is squarely the "older" direction.
The paragraph's closing sentence ("None of this is a bug in the staleness gate; it is the gate
correctly refusing...") is accurate for that scenario but is phrased as a general statement about
"the staleness gate," with no textual signal that it does not extend to the newer direction this
task is fixing. It needs a narrowing clause, not a rewrite: the scenario it describes is unchanged
and still "not a bug"; a handoff-newer-than-minted is a *different* scenario this doc does not
currently discuss at all, and should name explicitly once Deliverable 1 ships (pointing at
`orchestrate-cycle-plan.sh` attribution).

**A fourth, adjacent location noticed but NOT in the dispatch's named 3-way list**:
`context/patterns/system-defect-discrimination.md:263` has a registry row "Stale-handoff gate |
`scripts/orchestrate-cycle-postflight.sh` (mtime staleness gate...) | ... | `HANDOFF_STALE_OR_ABSENT`"
whose "Location" column names the postflight script itself (matching doc row 2's error, not the
code's real attributed_path). This column's semantics ("where the check lives in code") differ
from `attributed_path` ("who to blame"), so it is arguably not making the same claim as the other
three — but it reads confusingly similarly. **Recommendation**: mention it in the plan as an
optional, low-risk follow-up edit (same file family, same kind of fix) but do not treat it as
required by this task's acceptance criteria, since the dispatch's file_scope/acceptance language
names only `commands/orchestrate.md` and `orchestrate-state-machine.md` for the doc side.

**Test gap, confirmed independently**: `test-handoff-dispatch-identity.sh` has exactly 4 cases
(`case1-match`, `case2-mismatch-inside-window` — handoff seq 4 vs minted 5, older —,
`case3-old-mtime`, `case4-absent`). None constructs a handoff seq *greater* than the minted value.
The suite's `run_case` helper currently asserts only on `.status`/`.verdict` and a stderr grep —
it never inspects `detected_defects`' `attributed_source_path`, so even today's 4 cases carry no
attribution assertion at all. A 5th case can reuse the existing harness almost verbatim.

### Deliverable 2 — Status honesty

**Status lifecycle, traced end to end:**

1. `:492` — `dispatch_status=""` initialized.
2. `:505` — set from a trusted, present, non-stale handoff's own `.status` (the ordinary,
   healthy path — this IS the persisted-transition path, since WORK (f)'s case ladder below acts
   on this same value and performs the real `skill_postflight_update` write).
3. `:591` — set from `recover_json` inside the **successful recovery** branch ("no handoff
   written for this dispatch — expected outcome for this phase's writer... recovering the
   dispatch outcome from it"). `have_outcome=true` here too, so WORK (f) still acts on this value
   and (for `researched`/`planned`/`implemented`) performs a real transition. **But**: for a
   `partial` outcome with an empty `blockers[]` (see the `partial)` case arm, `:947-952` in the
   ladder), WORK (f) explicitly performs **no transition at all** — "Dispatch status '$dispatch_status'
   — recognized exception outcome. No state.json transition performed." So even on this
   successful-recovery path, `.status` can legitimately differ from what is in `state.json`
   immediately after this call (e.g. `partial` reported, `implementing` still persisted) — **by
   design**, not as a bug. This is directly confirmed by `test-orchestrate-cycle-postflight.sh`'s
   Acceptance (5) fixture (`706_candidate`): `state.json.status` stays `"implementing"`
   throughout, `.return-meta.json.status` is `"partial"`, and the test asserts
   `jqf '.status' == "partial"` (see `:390-395` of that suite) — i.e. **the suite already locks
   in "echo the agent's self-report here," not "echo the persisted value."**
4. `:678` — set from `out_recovered_reported_status` inside the **RECOVERY_DECLINED** branch
   (`have_outcome` stays `false`). The comment at `:672-677` is explicit: "Diagnostic only — this
   does NOT make the outcome recovered... lets the final output JSON's own `status` field echo
   what the agent actually reported... most useful for WORK (e)'s user_decision relay." **This is
   the exact branch the originating incident hit**: a plan dispatch declined recovery
   (`META_DISPATCH_SEQ_MISMATCH`), `have_outcome` stayed `false`, WORK (f)'s case ladder (gated on
   `if [ "$have_outcome" = "true" ]` at `:829`) never ran at all, so **no transition was even
   attempted** — yet the emitted JSON's `.status` is `"planned"` (the agent's self-report) while
   `state.json` genuinely still reads `"planning"`.

5. The final emit (`:1404`/`:1422`, two `jq -n` blocks for the `user_decision_json != "null"` and
   `else` cases) both do `--arg status "$dispatch_status"` with **no accompanying field**
   distinguishing provenance. The documented output schema at `:94-96` (`{task, phase, status,
   phases_completed, phases_total, verdict, user_decision?, halt, infra_exempt_cycle, aux_signal,
   report_missing, note}`) likewise has no such field today.

**Where "the persisted status" actually lives, and why it is not already threaded through:**
`:1317-1322` computes `fresh_status` — a fresh, authoritative read of `state.json`'s current
`.status` for this task — but only inside `if [ -z "$loop_guard_file" ]` (multi-task engine
only) **and** inside `if is_live` (never under `--dry-run`). It is used solely for the
multi-state `current_statuses[$t]`/`completed_tasks`/`failed_tasks` bookkeeping at
`:1317-1335`, never surfaced in the final emitted JSON, and never computed at all for the
single-task engine or for a `--dry-run` call. Any fix that wants to expose "the actual persisted
status" to callers must generalize this read (or an equivalent one) to run unconditionally — both
engines, dry-run included (under dry-run it simply reports today's unchanged persisted value,
which is correct: no write happened).

**Why a straight swap (`.status` := persisted value) would be the wrong fix, evidenced, not
assumed:**
- It would change Acceptance (5)'s asserted behavior: `test-orchestrate-cycle-postflight.sh:390-395`
  currently requires `.status == "partial"` (the agent's self-report) specifically in a case where
  the persisted value is `"implementing"` — a straight swap flips this assertion's expected value
  and, per the comment at `:672-677`, actively degrades the stated purpose of that field for the
  `user_decision` relay (WORK (e), `:1091` in the dispatch's citation — confirmed at the `if
  [ "$user_decision_json" != "null" ]` block, which logs "Status is left exactly as the agent
  reported it (${dispatch_status:-<empty>})" and is designed to read as the agent's own words to
  the user asking the `ask_user` question, not an internal bookkeeping value).
- The dispatch's own acceptance criterion 6 asks that this specific behavior be "verified rather
  than assumed" — it already is, by the existing Acceptance (5) test, as long as the fix does not
  touch the `.status` field's meaning. This is strong, pre-existing evidence in favor of the
  "add an explicit flag" branch of the dispatch's either/or framing.

**Recommendation: add an explicit discriminating flag, leave `.status` semantics untouched.**
Concretely:
- Generalize the `fresh_status` read (`:1317-1322`) to run unconditionally — both engines,
  live or dry-run — immediately before the final emit, reading `state.json`'s current `.status`
  for `$task_number` fresh (this is a read, not a mutation, so it is safe under `--dry-run` and
  for the single-task engine, which currently never computes it).
- Add a new JSON field to both final-emit `jq -n` blocks (`:1404`/`:1422`), e.g.
  `--arg persisted_status "$fresh_status"` → `persisted_status: $persisted_status`, and update the
  output-schema docstring at `:94-96` to document it alongside `status`:
  - `status`: the dispatch's own self-reported outcome (verbatim from the handoff or a recovered
    `.return-meta.json`), unchanged in meaning from today. Used for diagnostics and the
    `user_decision` relay; may differ from `persisted_status`.
  - `persisted_status`: `state.json`'s current status for this task, read fresh at the moment of
    this emit (reflects any transition WORK (f) just performed, or the task's pre-existing status
    if none was performed/attempted).
- This is additive and backward-compatible: every existing consumer reading `.status` keeps its
  current behavior (including Acceptance (5), which only ever reads `.status`); no existing test
  needs its expected value changed, only the new field's presence needs assertion.

**Move 3 interaction, confirmed load-bearing as the dispatch states**: `skill-orchestrate/SKILL.md:191-192`
does `dispatch_status=$(... .status ...)` and `verdict=$(... .verdict ...)`. Tracing every use of
the resulting `$dispatch_status` shell variable within Move 3 (`:170-231`) and Move 4
(`:260-327`): it is used **exactly once**, at `:196`, for the diagnostic echo `"[orchestrate] Task
#${t}: dispatch result: $dispatch_status (verdict=$verdict)"`. All actual loop-control branching in
Move 3 (`ask_user` accumulation, `halt` handling, `defer`+`infra_exempt_cycle`, `failed`) keys off
`$verdict`/`$halt`/`$infra_exempt_cycle` — never `$dispatch_status` directly. The batch-results
template (`context/patterns/orchestrate-batch-results-template.md:83`, "Deferred (self-modifying)"
section) separately documents that a task's rendered "Final Status" in operator-facing output is
read fresh from state.json at loop exit, independent of any per-cycle `dispatch_status` value —
confirming `dispatch_status`'s only live role today is the Move-3 diagnostic line. This means the
blast radius of adding `persisted_status` is small: Move 3's one echo line is the only required
update (recommend echoing both: `"... dispatch result: $dispatch_status (verdict=$verdict,
persisted=$persisted_status)"`), plus updating the `postflight_json=$(...)` destructuring at
`:191-195` to also capture the new field for that line. No other Move 3/4 logic needs to change.

**Contract-text update required** (acceptance criterion 5): `SKILL.md`'s prose around `:170-196`
should state plainly that `.status` is the agent's self-report (diagnostic/relay use only) and
`.status`-is-not-state.json is the documented, intentional behavior, with `.persisted_status`
naming the actual transition outcome. This is a documentation-only change colocated with the code
change, not a second code path.

## Recommendations

1. **Deliverable 1 code change** (`orchestrate-cycle-postflight.sh:456`): before the existing
   `elif [ -n "$expected_dispatch_seq" ] && [ "$handoff_dispatch_seq" != "$expected_dispatch_seq" ]`
   branch, add a numeric-safe direction check (guard non-numeric values the same way
   `partial_blocker_count` is guarded elsewhere in this file, e.g. a `case ... in ''|*[!0-9]*)`
   fallback to today's behavior) distinguishing:
   - `handoff_dispatch_seq -gt expected_dispatch_seq` (**newer**): new message text naming the
     direction explicitly (e.g. "handoff dispatch_seq=$handoff_dispatch_seq is NEWER than this
     cycle's minted dispatch_seq=$expected_dispatch_seq — this dispatch was composed/handed a seq
     this cycle's own mint never produced (an authoring fault in composition, not a stale
     predecessor artifact)"), a distinct detecting-site suffix (e.g.
     `:cycle-postflight-dispatch-seq-mismatch-newer`), and
     `attributed_path="agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"` for this
     one record call only (do not change the file-level `$attributed_path` default — shadow it
     locally for this branch).
   - otherwise (**older**, the existing/default case): unchanged behavior, byte-for-byte, so
     `case2-mismatch-inside-window` keeps passing with no edits.
   Recommend keeping `defect_class=HANDOFF_STALE_OR_ABSENT` for both directions (no vocabulary
   churn in `system-defect-record.sh`'s enum or any triage consumer) — the two detecting-site
   strings plus the two distinct `attributed_source_path` values are sufficient to satisfy
   acceptance criterion 1's "distinguished in both the notice text and the recorded
   `detected_defects` row."
2. **Deliverable 1 test addition** (`test-handoff-dispatch-identity.sh`): add
   `run_case "case5-newer-than-minted" 805 6 5 0 "false" 'DISPATCH_SEQ MISMATCH'` (handoff seq 6,
   minted 5, mtime inside window — mirrors Case 2's shape exactly, only the seq direction
   flipped), then extend the shared `run_case`/assertion helper with an attribution check: after
   `run_sut`, read `${WORKDIR}/specs/805_candidate/.orchestrator-loop-guard`'s
   `.detected_defects[-1].attributed_source_path` and assert it equals
   `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` for case 5, and (to prove the
   assertion is not vacuous and does not regress case 2) equals
   `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` for case 2. This genuinely
   fails against the pre-fix script (today both cases record the SKILL.md path), satisfying
   acceptance criterion 2 non-vacuously.
3. **Doc reconciliation** (acceptance criterion 7):
   - `commands/orchestrate.md:309` — correct the example row's "Attributed Source Path" and
     "Detecting Site" columns to the mtime arm's real values
     (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` /
     `skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff`), since the row's own "Detail"
     text already matches that arm's message verbatim.
   - `orchestrate-state-machine.md:318-322` — add a narrowing clause immediately after "it is the
     gate correctly refusing to trust a handoff that predates the window a fresh dispatch just
     opened," stating this exoneration covers only the handoff-older-than-minted direction, and
     pointing to the new newer-direction attribution (`orchestrate-cycle-plan.sh`) as the distinct,
     genuinely-attributable case this task adds. Do not alter the preceding scenario narrative —
     it is accurate for the direction it describes.
   - (Optional, low-risk, outside named scope) `context/patterns/system-defect-discrimination.md:263`'s
     registry row could gain a one-line note distinguishing "Location" (where the check lives)
     from "attributed_path" (who to blame) to avoid the same visual confusion — flag for the plan
     to include or defer.
4. **Deliverable 2 code change**: generalize the `fresh_status` read (currently
   `:1317-1322`, multi-task+is_live only) to run unconditionally right before the final emit;
   add `persisted_status` to both `jq -n` emit blocks (`:1404`/`:1422`) and to the output-schema
   docstring (`:94-96`); leave `dispatch_status`/`.status` semantics and every existing call site
   untouched.
5. **SKILL.md update** (acceptance criteria 5-6): update `skill-orchestrate/SKILL.md:191-195`'s
   destructuring to also capture `persisted_status`, update the `:196` echo line to show both, and
   add one or two sentences near `:170-196` stating the two fields' distinct meanings. Re-run (or
   extend) `test-orchestrate-cycle-postflight.sh`'s existing Acceptance (5) fixture unmodified to
   confirm `.status` is still `"partial"` post-fix (it already asserts this — the plan phase
   should treat an unmodified green Acceptance (5) as the acceptance-criterion-6 proof, plus add a
   new assertion that `.persisted_status == "implementing"` in that same fixture to make the
   discrimination itself testable, not merely non-regressed).
6. **Territory note for the plan phase**: this task's two fixes are entirely contained within
   `orchestrate-cycle-postflight.sh`, its own test file, and the two named docs. The
   `orchestrate-cycle-plan.sh` reference introduced by Deliverable 1 is a string literal inside a
   defect-record call, not an edit to that file — task 314 (concurrently researching the minting
   bug in `orchestrate-cycle-plan.sh` itself) remains file-scope disjoint, consistent with the
   dispatch's framing.

## Decisions

- **D1 (attribution direction)**: a dispatch_seq mismatch where the handoff is *newer* than the
  cycle's minted value is attributed to `orchestrate-cycle-plan.sh` (the confirmed, sole minting
  site for both engines); the *older* direction keeps today's `skill-orchestrate/SKILL.md`
  attribution unchanged. Reasoning: only the minting/composition step can hand a dispatch a seq
  value this cycle's own expected-value never produced; `skill-orchestrate/SKILL.md` only reads
  the already-minted value back out of multi-state, per `SKILL.md:138`.
- **D2 (defect vocabulary)**: keep `defect_class=HANDOFF_STALE_OR_ABSENT` for both directions;
  discriminate via `attributed_source_path` and `detecting_site` only. Reasoning: avoids touching
  `system-defect-record.sh`'s class enum or any downstream triage consumer keyed on defect class,
  and the dispatch's acceptance criteria only require the attribution and notice text to differ,
  not the class.
- **D3 (status field shape)**: add a new sibling field (`persisted_status`), do not repurpose or
  swap `.status`. Reasoning: `test-orchestrate-cycle-postflight.sh`'s existing Acceptance (5) is
  already evidence that `.status` is relied upon, and tested, to carry the agent's self-report
  even when it diverges from the persisted value by design (an empty-blocker `partial` outcome
  writes nothing); swapping would regress a passing, deliberate test and degrade the
  `user_decision` relay's documented purpose.
- **D4 (generalizing the persisted-status read)**: the existing `fresh_status` computation
  (`:1317-1322`) is multi-task+`is_live`-only and cannot be reused verbatim; it must be
  recomputed unconditionally (both engines, dry-run included) immediately before the final emit
  to populate `persisted_status` reliably in every call shape this script supports.

## Risks & Mitigations

- **Risk**: a numeric comparison on `handoff_dispatch_seq`/`expected_dispatch_seq` could receive
  a non-numeric or empty value in some unanticipated call shape, causing the new `-gt`/`-lt` test
  to error under `set -u`/strict mode. **Mitigation**: guard with the same
  `case ... in ''|*[!0-9]*)` idiom already used elsewhere in this file (e.g.
  `partial_blocker_count` at `:946`) before the numeric comparison, falling back to the existing
  (older-direction) behavior on any non-numeric input — never erroring, never silently
  misattributing.
- **Risk**: adding `persisted_status` to the emitted JSON without updating every consumer could
  leave the field silently ignored where it would actually be useful (e.g. a future triage script
  that wants to know the true state.json value rather than parsing `state.json` itself a second
  time). **Mitigation**: this report scopes the Move-3 update as required by acceptance criterion
  5; a broader audit of all `postflight_json` consumers is out of scope for this task (the
  dispatch names only Move 3) but should be a one-line note in the plan's "Follow-ups" if any
  other consumer is found during implementation.
- **Risk**: the doc narrowing in `orchestrate-state-machine.md:318-322` could be mis-edited to
  accidentally weaken the still-valid "not a bug" claim for the older direction. **Mitigation**:
  the recommended edit is additive (append a narrowing clause after the existing sentence), not a
  rewrite of the existing scenario narrative.
- **Risk**: 8 other live tasks (285, 279, 284, 273, 263, 304, 184, 185) touch this same file.
  **Mitigation**: already addressed by the dispatch's non-concurrency batching guidance (do not
  batch 315 in the same `/orchestrate` wave as any of those 8); task 263 is the one semantic
  overlap (owns the `user_decision` relay) and should be re-checked against the chosen
  `persisted_status` shape if 263 lands first, per the dispatch's own note.

## Context Extension Recommendations

- **Topic**: direction-aware defect attribution pattern (older vs. newer than an expected
  monotonic counter).
- **Gap**: `context/patterns/system-defect-discrimination.md` currently documents
  `HANDOFF_STALE_OR_ABSENT` as a single undifferentiated class/attribution pair (line ~88, ~263);
  after this task ships, it will have two attribution outcomes keyed on comparison direction, with
  no existing pattern doc describing "attribute by direction of a monotonic mismatch" as a reusable
  shape.
- **Recommendation**: once implemented, add a short subsection to
  `system-defect-discrimination.md` documenting the `HANDOFF_STALE_OR_ABSENT` direction split
  (mirroring how it already documents the `RECOVERY_DECLINED` vs. `HANDOFF_STALE_OR_ABSENT` split
  at lines ~97/266), so a future direction-sensitive attribution elsewhere in the orchestrator can
  point at this as precedent rather than re-deriving the reasoning.

## Appendix

- Line numbers cited throughout are against
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (source store) as read
  during this research session; the deployed copy at `.claude/scripts/orchestrate-cycle-postflight.sh`
  is a regenerated artifact and must never be hand-edited (per
  `.claude/rules/source-store-deploy-boundary.md`).
- Searches performed: `grep -n "dispatch_status"`, `grep -n "have_outcome"`, `grep -n
  "fresh_status"`, `grep -n "HANDOFF_STALE_OR_ABSENT"` across `scripts/*.sh`, `docs/`, `context/`;
  `grep -rn "skill_orchestrate_mint_dispatch_seq"` / `"dispatch_seq"` across `scripts/*.sh` to
  confirm the sole minting site; full reads of
  `test-handoff-dispatch-identity.sh` and the relevant ~450-line window of
  `test-orchestrate-cycle-postflight.sh` (Acceptance 4b/5 regions); full reads of the cited
  windows of `commands/orchestrate.md`, `orchestrate-state-machine.md`, and
  `skill-orchestrate/SKILL.md` (Move 3/4).
- No web search was used — this is a pure codebase-internal consistency/design task with no
  external dependency.
