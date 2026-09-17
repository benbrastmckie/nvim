# Research Report: Task #213

**Task**: 213 - Thread focus prompt into cycle plan (absorbed former tasks 214 and 216)
**Started**: 2026-09-17T16:30:00Z
**Completed**: 2026-09-17T17:10:00Z
**Effort**: Large — three coupled defects in one source-store engine, one 1860-line script
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `orchestrate-build-dispatch.sh`, `orchestrate-loop-guard-init.sh`, `parse-command-args.sh`
- Docs: `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `merge-sources/claudemd.md`,
  `docs/architecture/orchestrate-state-machine.md`, `context/standards/orchestrator-runtime-files.md`
- Tests: `scripts/tests/test-orchestrate-cycle-plan.sh`, `scripts/tests/test-force-phases.sh`,
  `scripts/test-session-runtime-files.sh`, `scripts/tests/test-loop-guard-budget-override.sh`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect A (focus threading)**: confirmed root cause exactly as described in the dispatch.
  `orchestrate-cycle-plan.sh` has no `--focus` flag at all in its parser (lines 269–319), and
  `skills/skill-orchestrate/SKILL.md`'s Move 1 call (lines 63–75) forwards every other flag but
  never `focus_prompt` — which SKILL.md's own "Setup" list (lines 28–33) doesn't even name as a
  delegation-context input it draws from, despite `commands/orchestrate.md` already passing
  `focus_prompt={focus_prompt}` into the Skill call (line 213) and delegation-context JSON (line
  223). `orchestrate-build-dispatch.sh` already fully supports `--focus` (parses it, renders
  "User focus:", feeds `--clean`-gated memory retrieval) — **no change needed there**, confirmed
  by direct read.
- **Defect B (fall-through after forced queue exhausted)**: confirmed root cause exactly.
  `orchestrate-cycle-plan.sh` section (f) (lines 1340–1363) computes `effective_group[$t]` from
  `force_phases_remaining[$t]`'s first element when non-empty, but **falls straight through to
  `triage_group[$t]` (ordinary status-derived classification) the moment that queue is empty** —
  with no distinction between "this task was never forced this session" and "this task's forced
  queue in *this same session* was fully consumed." The existing test suite currently *codifies
  the fall-through as correct behavior* (`test-orchestrate-cycle-plan.sh` lines 348–391, named
  "stop-after-last-named" but asserting the opposite) — fixing this defect necessarily breaks
  that specific existing assertion, which is itself the acceptance criterion's expected effect.
  The doc contradiction is real and lives in at least three files, including **two places within
  the same file** (`merge-sources/claudemd.md` lines 112 vs. 116) and `commands/orchestrate.md`
  (per-flag rows say "STOPS", Stage 0 prose says "falls through").
- **Defect C (cross-invocation cumulative budget + artifact-based admission)**: confirmed.
  `cycle_counts[t]` is seeded every invocation from the durable
  `${TASK_DIR}/.orchestrator-loop-guard` file's `cycle_count` field via
  `orchestrate-loop-guard-init.sh --seed` (cycle-plan.sh lines 891–900) and flushed back via
  `--flush` (lines 1834–1836) — genuinely cumulative *across* `/orchestrate` invocations, exactly
  as `context/standards/orchestrator-runtime-files.md`'s "Defect B" section (lines 215–253)
  documents it as *intentional design*, and exactly as `test-orchestrate-cycle-plan.sh` Group 8
  (lines 497–611) and `test-session-runtime-files.sh` Case 3 assert. This is the behavior the
  task's INTENT section says must change: cycle budget resets every run; only
  `dispatch_seq_counter`, `pending_dispatch`, and `detected_defects` persist. `--continue-budget`
  touches four scripts and two test files end to end (grep-confirmed, list below) and one dormant
  `MAX_INFRA_FAILURES` bypass. The artifact-based admission rule (plan → reviser vs. planner;
  implement → blocked without a plan) has **no implementation today**: `resolve_agent()`'s `plan`
  case is hardcoded to `"planner-agent"` unconditionally (line 1520), and the implement dispatch's
  `plan_path` resolution in `orchestrate-build-dispatch.sh` (line 188) silently sends an **empty**
  `plan_path` when none exists rather than blocking.
- All three defects share one file (`orchestrate-cycle-plan.sh`) and two coupled data structures
  (`force_phases_remaining[]`, `cycle_counts[]`/durable guard `cycle_count`) — the planner should
  treat this as one coordinated change to that script, not three independent patches, since a
  naive sequential fix risks each edit clobbering the others' context (see "Cross-Cutting
  Interactions" below).

## Context & Scope

Task 213's dispatch (`.dispatch/4.md`) absorbed two related defect reports verbatim (former
tasks 214 and 216) into one description, all targeting the same orchestrator engine:

1. **Focus-prompt threading** (this task's own original scope): a user-supplied
   `/orchestrate N --research "<questions>"` focus string never reaches the dispatched agent's
   `.dispatch/{seq}.md` file.
2. **Stop-after-forced-phase** (absorbed from 214): once a phase-forcing flag's queue is
   exhausted within a session, the engine must stop dispatching that task for the rest of that
   session — not silently resume ordinary status-derived dispatch.
3. **Per-run cycle budget + artifact-based admission** (absorbed from 216, itself amending 214's
   scope to be session-bound): the work-cycle budget must reset every `/orchestrate` invocation
   (not persist across them), `--continue-budget` is removed entirely, and forced
   plan/implement admission must be decided by artifact presence (does a plan exist?) rather than
   task status.

All three concern `agent-system/extensions/core/` (the source store); `.claude/**` is the
disposable deploy target per `.claude/rules/source-store-deploy-boundary.md` and was not touched
during this research.

## Findings

### Defect A — Focus-prompt threading

**Confirmed absent**: `orchestrate-cycle-plan.sh`'s flag parser (lines 269–319) recognizes
`--session`, `--state-file`, `--invocation-count`, `--force-phases`, `--clean`, `--lit`,
`--compare`, `--hard`, `--fast`, `--model`, `--allow-self-modifying`, `--allow-scope-collision`,
`--continue-budget`, `--dry-run`, `--no-plan-cache` — no `--focus`.

**Confirmed research_questions path already works and must stay byte-identical**: lines
1761–1777 read the task's own `research_questions` field from `state.json`, join with `"; "`, and
pass `--focus` to `orchestrate-build-dispatch.sh` only for a `research`-phase build (`if [ "$g" =
"research" ]`), only when non-empty. This is the ONLY existing `--focus` producer in the whole
pipeline today.

**Confirmed downstream consumer already complete** (`orchestrate-build-dispatch.sh`):
- Line 127: `--focus` parsed into `focus_prompt`.
- Lines 352–355: renders `"User focus: ${focus_prompt}"` into the dispatch file's `## Description`
  section, gated on non-empty.
- Line 215: `memory_arg3="$focus_prompt"` threads focus into `memory-retrieve.sh`'s 3rd argument
  for research-phase dispatches only, gated on `--clean` not being set.
- The dispatch WORK item's claim "no change is needed there" is verified correct.

**Confirmed SKILL.md never forwards a user-typed `focus_prompt`**:
- `SKILL.md`'s "Setup" section (lines 28–33) enumerates the delegation-context vars it draws
  from — `task_numbers`, `dependency_graph`, `session_id`, `lit_flag`, `compare_flag`,
  `allow_self_modifying`, `allow_scope_collision`, `clean_flag`, `effort_flag`, `model_flag`,
  `hard_mode`, `force_phases`, `continue_budget` — **`focus_prompt` is not in this list at all**,
  even though `commands/orchestrate.md` already passes it (line 213: `focus_prompt={focus_prompt}`
  in the Skill invocation; line 223 in the delegation-context JSON block).
- Move 1's `orchestrate-cycle-plan.sh` call (lines 63–75) builds `build_args`-equivalent CLI flags
  for every one of those vars except `focus_prompt` — there is no `$( [ -n "${focus_prompt:-}" ]
  && echo --focus "$focus_prompt" )` line at all.

**Fix shape implied by dispatch WORK (a)–(d)** (for the planner, not decided here):
- (a) Add `--focus` to `orchestrate-cycle-plan.sh`'s own parser, propagate it through to the
  plan-cache key (`plan_cache` is keyed only on `dispatch_seq_counter` today — verify whether a
  composition that differs only in `--focus` could otherwise incorrectly replay a cached plan
  built without it; see lines 502–528 and 607–619 for the cache read/write sites).
- (b) In section (l) (lines 1761–1777), combine a CLI-supplied focus with `research_questions`
  when both exist ("neither may silently replace the other" — dispatch's own words), and decide
  whether plan/implement dispatches should carry it too (today only research does, and
  `orchestrate-build-dispatch.sh`'s own `--focus` flag is phase-agnostic — it renders
  unconditionally in `## Description` regardless of `$phase`, so the consumer side already
  supports non-research use if the caller chooses to pass it).
- (c) SKILL.md Move 1: append `$( [ -n "${focus_prompt:-}" ] && echo --focus "$focus_prompt" )` to
  the existing flag list, matching the empty-value-skips-flag convention every other flag there
  already uses, with quoting safe for embedded spaces/quotes (the existing list already relies on
  bash's `$( ... )` word-splitting per flag, so a `--focus "$focus_prompt"` addition following the
  same idiom is consistent, but the VALUE itself needs to survive a value containing double quotes
  — worth an explicit test case, since this is exactly the kind of text a free-form focus prompt
  is likely to contain).
- (d) `--dry-run` currently prints a plan JSON with `dispatch_file`/`model` forced to `null.` and a
  human table with four sections (Dispatch/Aux Dispatch/Deferred/Blocked/Stop) — none show any
  per-row context beyond phase/agent/reason. Showing "focus text was received" needs either a new
  field on the dispatch row in the plan JSON (a live-mode-parity concern, since `--dry-run` and
  live share one JSON shape per the script's own header mandate — "never two independently
  maintained renderings") or a distinct top-level echo. The simplest option consistent with the
  existing contract is a new optional field on each dispatch row (e.g. `focus`), always present
  (possibly `null`) so dry-run and live stay byte-identical in shape.

### Defect B — Fall-through after forced-phase queue exhausted

**Confirmed root cause, line-exact**: section (f) (`orchestrate-cycle-plan.sh` lines 1340–1363):

```bash
declare -A effective_group=()
declare -A forced_this_cycle=()
for t in "${eligible_tasks[@]}"; do
  remaining=$(echo "$mt_json" | jq -c --arg t "$t" '.force_phases_remaining[$t] // []')
  remaining_len=$(echo "$remaining" | jq 'length')
  if [ "$remaining_len" -gt 0 ]; then
    forced_phase=$(echo "$remaining" | jq -r '.[0]')
    effective_group[$t]="$forced_phase"
    forced_this_cycle[$t]="true"
  else
    effective_group[$t]="${triage_group[$t]:-skip}"
    forced_this_cycle[$t]="false"
  fi
done
```

`.force_phases_remaining[$t] // []` cannot distinguish "task `t` was never forced this session"
(key absent) from "task `t` was forced and its queue is now empty" (key present, value `[]`,
written at line 1724 by the pop: `.force_phases_remaining[$t] =
(.force_phases_remaining[$t][1:])`). Both read back as `[]` via jq's `//`, since jq's `//`
triggers on `null`/`false`, not on an empty array. Both cases currently produce identical
behavior: fall through to `triage_group[$t]` — ordinary status-derived classification. This is
precisely the observed live incident (a RESEARCHED task with a fully consumed
`--force-phases research` queue got auto-advanced to `[PLANNING]` on a later, unforced re-check
call within the *same* session).

**`mt_state_file` is already session-scoped** (line 448:
`mt_state_file="$(dirname "$STATE_FILE")/.orchestrator-multi-state-${session_id}.json"`), so
`force_phases_remaining` already does NOT leak across a *new* `/orchestrate` invocation (a fresh
`session_id` reads a fresh, empty `mt_json`). This means the fix's "must persist forced-round
state" requirement (dispatch WORK 214(a)) is naturally scoped correctly already by session — the
gap is purely the missing "was this task ever forced this session" marker, not a need to widen
persistence beyond the session. This matches the later AMENDMENT text verbatim ("Scope the
'forced round' state... to ONE run's multi-state file... A NEW /orchestrate run... must start
clean").

**`task_has_forced_phase()`** (lines 1126–1143) already has almost the right shape for a
DIFFERENT purpose — it exempts a *terminal* task from the all-terminal/eligibility exclusion when
either `canonical_force_phases_json` (this invocation's CLI flag) is non-empty OR
`force_phases_remaining[$t]` is non-empty. It returns **false** once the queue is empty, which is
*correct* for a terminal task (the worked example in
`docs/architecture/orchestrate-state-machine.md` lines 738–770 confirms: a terminal task's forced
round completing correctly re-triggers `all_terminal` on the next cycle, because
`is_terminal_status` is independently true). **The gap is entirely in the NON-terminal case**:
a non-terminal task (e.g. `researched`) whose forced queue just emptied is *not* caught by any
exclusion check — it sails past the all-terminal check (never terminal) and the eligibility loop
(no budget/dependency issue), straight into section (f)'s fall-through.

**Documentation contradiction, confirmed at three sites, two within one file**:
- `merge-sources/claudemd.md` line 112 (the `/orchestrate` command-table row): "...then
  **stopping after the last named phase rather than falling through to status-derived dispatch**;
  an invocation with NO forcing flag on a fully terminal set still stops immediately..."
- `merge-sources/claudemd.md` line 116 (two paragraphs later, "Multi-task syntax" prose, same
  file): "...each task tracks its own remaining-forced-phases position independently via
  `scripts/orchestrate-cycle-plan.sh`'s `force_phases_remaining`, **falling through to ordinary
  status-derived classification once its own forced sequence is exhausted**."
- `commands/orchestrate.md`: the per-flag Options-table rows (lines 51–53, `--research`/`--plan`/
  `--implement`) all say "STOPS after the last named phase"; the Stage 0 Constraints prose (lines
  25–28) and the `force_phases` bullet under "Each parsed flag becomes a delegation-context key"
  (lines 91–95) both say "...falls through to ordinary status-derived classification for that
  task."
- `docs/architecture/orchestrate-state-machine.md` does not itself contain the contradiction — its
  only worked example (lines 738–770) is the terminal-task case, which the code already handles
  correctly; it simply never documents the non-terminal case at all (a documentation gap, not a
  contradiction, but still needs a new worked example once the fix lands).

**Existing test currently *asserts* the fall-through as correct** (this is the test the dispatch's
ACCEPTANCE clause means when it says "The test fails against the current script" — after the fix
lands, this specific existing assertion must be inverted, not merely supplemented):
`scripts/tests/test-orchestrate-cycle-plan.sh` lines 348–391, "Group 4/5 (continued): per-candidate
forced-phase stop-after-last-named fall-through (LIVE)":

```
# cycle 1: forces "research" despite status "implementing" — force=true, correct, unaffected by fix
# cycle 2 (same session, queue now empty): asserts
#   .dispatch[].phase == "implement"  (status-derived — i.e. the CURRENT, to-be-fixed behavior)
#   .dispatch[].force == "false"
# labeled "stop-after-last-named: cycle 2 falls through to status-derived classification ...
#   once the forced queue is exhausted" — the test's own name says "stop" but its assertion
#   proves the OPPOSITE (fall-through), which is the defect.
```

After the fix, cycle 2 on the same fixture must instead produce **no dispatch row for task 501**
(excluded — e.g. surfaced as `deferred`/`blocked`/absent-from-all-three, per whatever exclusion
shape the planner chooses) with status still `implementing` unchanged, `cycle_count` unchanged,
and no new `.dispatch/` file — matching task 214's ACCEPTANCE clause almost verbatim
(`scripts/tests/test-force-phases.sh`, a distinct, not-yet-created suite per the dispatch, is the
file named for the *new* regression coverage; this existing Group 4/5 assertion in
`test-orchestrate-cycle-plan.sh` is the one that must be edited in place, not left as a
duplicate/contradictory pass).

`scripts/tests/test-force-phases.sh` does not currently exist in the source store (grep found
zero matches for that filename); the dispatch's ACCEPTANCE clause for the absorbed 214 material
names it as the target for the new regression suite, so it is a **new file** the plan should
create, distinct from editing the existing Group 4/5 block above.

### Defect C — Per-run cycle budget reset, `--continue-budget` removal, artifact-based admission

**Cumulative-across-invocations confirmed as current, intentional design** — three converging
proofs:

1. **Code**: `orchestrate-cycle-plan.sh` section (a2) (lines 881–900) seeds
   `.cycle_counts[$t] //= $v` from `orchestrate-loop-guard-init.sh --seed "$_task_dir_abs"`, which
   reads `.cycle_count` from the durable, gitignored `${TASK_DIR}/.orchestrator-loop-guard` file
   (`orchestrate-loop-guard-init.sh` lines 88–106) — this file survives across `/orchestrate`
   invocations by construction (it is task-directory-scoped, not session-scoped). The live charge
   site (lines 1830–1841) flushes the incremented value back via `--flush`, and the file is
   *never* reset to 0 except through the `--continue-budget` override path (lines 1236–1262).
2. **Doc**: `context/standards/orchestrator-runtime-files.md` lines 215–253 ("`cycle_count`
   semantics and the budget-continuation override (Defect B)") states explicitly: "`cycle_count`
   ... is **per-task and cumulative across invocations, by design**... deliberately NOT reset
   when a new `session_id` appears... gating the budget on it would let an operator bypass
   `MAX_CYCLES` simply by re-invoking the command." This section must be replaced per the
   dispatch's WORK (a) ("Replace the Defect B section... with the per-run contract and why") —
   note this is the OPPOSITE design philosophy from what the task now requires, so the
   replacement is a genuine reversal, not an extension.
3. **Test**: `test-orchestrate-cycle-plan.sh` Group 8 (lines 497–611) explicitly asserts
   cross-session cumulative resume ("Invocation 2, session B: a FRESH session_id... must still
   resume from the durable file's cycle_count=1... this is the cross-invocation cumulative
   guarantee Decision 1 exists to preserve", lines 522–533) and mode-aware budget enforcement via
   a *pre-seeded durable guard file* read directly by `--dry-run` (lines 544–562) — both need
   inverting/rewriting once cycle_counts starts fresh each run.
   `scripts/test-session-runtime-files.sh` Case 3 (lines 191–211, referenced by name in the
   Defect-B doc paragraph) asserts the per-task cycle_counts seed block contains no
   `session_id`-keyed hard-fail gate — a resume-tolerance property that stays true either way, but
   whose surrounding rationale ("no session-keyed gate... unconditional tolerance by
   construction") will need re-examination once the seed source for budgeting is removed; the
   dispatch's own text says "Invert" this case, which likely means asserting the opposite framing
   (that `cycle_counts` is *not* seeded from the durable file's `cycle_count` for budgeting at
   all) rather than literally negating today's specific greps.

**`--continue-budget` touches exactly these 7 files** (grep-confirmed,
`grep -rln "continue-budget\|continue_budget\|CONTINUE_BUDGET"`):
`commands/orchestrate.md`, `context/standards/orchestrator-runtime-files.md`,
`scripts/orchestrate-cycle-plan.sh`, `scripts/parse-command-args.sh`,
`scripts/tests/test-loop-guard-budget-override.sh`, `scripts/tests/test-orchestrate-cycle-plan.sh`,
`skills/skill-orchestrate/SKILL.md`. Concretely, in `orchestrate-cycle-plan.sh`:
- Flag declaration/parse: lines 282, 301.
- MAX_INFRA_FAILURES bypass (line 1223): `if [ "${infra_failure_counts[$t]:-0}" -ge
  "$MAX_INFRA_FAILURES" ] && [ "$continue_budget" != "true" ]` — the dispatch explicitly calls
  out removing this override too ("including... the MAX_INFRA_FAILURES override"). This gate is
  currently **dormant**: its own comment (lines 1218–1222) states `infra_failures` is "incremented
  only by the (not-yet-built) postflight composer's corroborated-transport-failure detection, so
  this is a dormant no-op today" — so removing the bypass has no live behavioral effect today,
  lowering the risk of this particular sub-change.
- Budget-exhaustion reset path (lines 1236–1262): archives the guard file to
  `.exhausted-loop-guard-<ts>.json`, resets `cycle_count` to 0 in place via
  `orchestrate-loop-guard-init.sh --flush ... 0`, and clears `pending_dispatch` via
  `--clear-pending`. This whole branch is removed per WORK (a); with per-run reset, there is no
  "exhausted" state left to recover from within a session (budget resets to 0 every run
  automatically).
- `orchestrate-loop-guard-init.sh` itself (`--seed`/`--flush` forms, lines 38–57) is generic
  (reads/writes whatever `cycle_count` value it's given) and likely needs **no signature change**
  — the fix is at the *call site* in `orchestrate-cycle-plan.sh` (section (a2) and the charge
  site), which should stop reading/writing `.cycle_count` for budgeting purposes. Confirm during
  planning whether `cycle_count` remains in the guard file's JSON schema at all (as inert
  historical data) or is dropped from the schema — the dispatch's WORK (a) says "the saved
  `cycle_count` is no longer read or written for budgeting," which is consistent with either
  choice as long as budgeting itself no longer consults it.

**Artifact-based admission — confirmed gaps, no existing implementation**:
- **Plan**: `resolve_agent()` (lines 1516–1527) hardcodes `plan) echo "planner-agent"; return
  ;;` unconditionally — there is no branch anywhere in `orchestrate-cycle-plan.sh` that checks
  `plans/*.md` existence before choosing planner vs. reviser for a *primary* (non-aux) plan
  dispatch. The AUX path already has this exact logic for a *different* trigger
  (`plan-revision` aux rows, driven by `.blocker-research.json`/`.drift-inspection.json` chain
  files or `aux_pending[t]`, lines 925–1002) and already resolves to `"reviser-agent"` via
  `aux_fixed_agent()` (line 1021) — the dispatch's WORK (b) is asking for a NEW, separate trigger
  (a forced `--plan` on a task that already has a plan) to reach the same `reviser-agent`
  destination, but through the PRIMARY `dispatch[]` array, not the `aux_dispatch[]` array
  (`/revise N` stays the standalone command per the dispatch's own text: "There is no separate
  `--revise` flag").
- **Implement**: `orchestrate-build-dispatch.sh` line 188: `plan_path=$(ls -1
  "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1) || plan_path=""` — on no match, `ls`
  exits non-zero, the `||` catches it, and `plan_path` is set to the empty string; the script
  proceeds to write a dispatch file with an empty `## Plan` / `- plan_path:` line rather than
  refusing. Confirmed no existing check anywhere in `orchestrate-cycle-plan.sh`'s eligibility (c),
  admission (d), or bucketing logic that would catch a forced-implement-with-no-plan case before
  it reaches `orchestrate-build-dispatch.sh`. The dispatch's WORK (b) requires this to become a
  `blocked[]` row with reason "no plan artifact; run --plan first" and no dispatch at all —
  meaning the check must move earlier, into `orchestrate-cycle-plan.sh` itself (likely alongside
  the bucketing step at lines 1447–1470, which already produces `needs_human`/`skip` exclusions
  and `blocked_rows`/`deferred_rows` in the same shape this new check would need).
- **Research artifact (plan dispatch's own input)**: `orchestrate-build-dispatch.sh` lines
  181–185 resolve `research_artifact` as `.[0]` of the task's `report`-type artifacts —
  `state-management.md`'s "Artifacts Are Append-Only (With Same-Type Supersession)" section
  already guarantees every artifact writer removes prior same-type entries before appending, so
  `.[0]` is already the newest report by construction. The dispatch text agrees ("No known
  defect... only pins it with a test") — this is a **test-only** addition (WORK (c)), not a code
  change; the report found no counter-evidence during this research.

## Cross-Cutting Interactions (read before sequencing the plan's phases)

1. **`force_phases_remaining` popping (Defect B fix) and `effective_group` resolution feed
   directly into `resolve_agent()`'s plan/implement branch (Defect C's artifact-based admission)**
   — both fixes touch the SAME per-candidate loop (lines 1340–1470 and the live dispatch loop at
   1682–1854). A sequenced, single coordinated edit to this region is strongly preferable to two
   independent patches landing at different times; a naive independent Defect-B-then-Defect-C
   ordering risks the Defect-B exclusion logic and the Defect-C blocked-row logic fighting over
   which one "wins" for the same candidate in the same cycle (e.g. a forced-implement candidate
   whose queue just emptied AND has no plan — must resolve to exactly one deterministic outcome,
   not two competing exclusion paths racing for the same `out_blocked_rows` slot).
2. **The per-run cycle-budget reset (Defect C) changes what "the session's own forced-round
   state" even means for Defect B's fix**: since `cycle_counts` will no longer read the durable
   guard file, and `force_phases_remaining` is already purely session-scoped (via
   `mt_state_file`), the planner should confirm the NEW "forced round completed, exclude for rest
   of session" marker (Defect B's own new field) does NOT reuse or get confused with the
   `cycle_counts`/budget machinery — they are answering different questions (has this task's
   NAMED phase list been fully dispatched vs. has this task hit its per-run work-cycle ceiling)
   and Decision 1's own header comments already treat them as orthogonal maps
   (`force_phases_remaining` vs. `cycle_counts`/`max_cycles_per_task`).
3. **`--focus` (Defect A) and the plan-cache** (`plan_cache`, lines 502–528, 607–619): the cache
   key today is `dispatch_seq_counter` alone. If a `--focus` value can differ between two
   `--dry-run` calls with nothing else changed but the same `dispatch_seq_counter` (a plausible
   operator action: re-running `--dry-run` with different focus text before ever going live),
   confirm whether the dry-run path even touches `plan_cache` at all — re-reading lines 516 and
   614, the whole plan-cache replay/write mechanism is unconditionally skipped under `--dry-run`
   (`[ "$dry_run" != "true" ]` guards both the read and the write), so this interaction is a
   **non-issue for `--dry-run`**. For a LIVE run, `--focus` is a per-dispatch CLI argument fixed
   for the whole invocation (not something that changes cycle-to-cycle within one session), so a
   plan-cache replay within that same invocation would replay the SAME focus value it was built
   with — also a non-issue. Recorded here so the planner does not need to re-derive this.
4. **Doc updates for all three defects converge on the same four files**: `commands/orchestrate.md`,
   `merge-sources/claudemd.md`, `skills/skill-orchestrate/SKILL.md`, and
   `docs/architecture/orchestrate-state-machine.md` all need edits from more than one of the three
   defects (e.g. `commands/orchestrate.md`'s Options table loses the `--continue-budget` row
   *and* gains updated STOP-contract language *and* possibly a `--focus`-received note under
   `--dry-run`). A single pass across these four files covering all three defects together will
   avoid repeated re-reads/re-edits of the same file across separate phases.

## Decisions

- No code or doc changes were made during this research phase (research-only, per the dispatch's
  MUST NOT boundaries and this agent's own postflight-boundary constraints).
- Confirmed via direct reading (not inference) that `orchestrate-build-dispatch.sh` needs **no
  change** for Defect A, and that the research-artifact resolution for Defect C's item (c) needs
  **no code change**, only a new test — both narrow the plan's actual code-change surface
  relative to the dispatch's WORK lists, which name these as open questions.

## Risks & Mitigations

- **Test churn risk**: fixing Defect B will legitimately break the existing "stop-after-last-named"
  assertions in `test-orchestrate-cycle-plan.sh` Group 4/5 (lines 348–391), and fixing Defect C
  will legitimately break Group 8's cross-session cumulative assertions (lines 497–611) and
  `test-loop-guard-budget-override.sh` (the whole `--continue-budget` suite, described in its own
  header as testing "the explicit, operator-typed `--continue-budget` override"). These are not
  regressions to avoid — they are the expected, load-bearing effect of the fix — but the plan
  should call them out explicitly per-phase so the implementer does not mistake a red pre-existing
  test for an unrelated break introduced by their own change and try to "preserve" the old
  assertion.
- **Ambiguous "excluded from dispatch" rendering**: the dispatch's WORK 214(a) says a
  fully-forced, now-exhausted task must be "excluded from dispatch (terminal for this session,
  with a clear stop or skip reason)" without specifying which of the plan JSON's four existing
  buckets (`dispatch`/`deferred`/`blocked`/absent-with-a-`stop`) that means. `deferred[]` implies
  "will become eligible later" (misleading — it never will, this session); `blocked[]` implies "a
  problem to fix" (also misleading — nothing is wrong); a `stop` (only usable for a whole-batch
  halt, not a single task in a multi-task batch) is too broad. The planner should pick one
  explicitly rather than defaulting to whichever bucket is easiest to wire — recommend either a
  NEW reason string within `blocked[]` (closest existing fit, cheapest to implement, and
  `blocked[]` rows already tolerate "no defect, just a rule" reasons like MAX_CYCLES) or a genuine
  new top-level `excluded[]` array if `blocked[]`'s semantics are judged too misleading (verify
  against every existing consumer of `plan_json.blocked` — `orchestrate-cycle-postflight.sh` and
  SKILL.md Move 2/3/4 — before choosing, since a new top-level array is a wider schema change that
  ripples through more call sites).
- **`--continue-budget` removal touches a locked-region-adjacent file**: `orchestrate-loop-guard-init.sh`'s
  own header (lines 1–25) references a `budget-continuation-override:begin` sentinel and a
  `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md` file describing a region "locked,
  never touched" — that region belonged to the now-deleted single-task engine per
  `commands/orchestrate.md`'s own text ("The former single-task engine... is deleted"). This
  appears to be pre-existing stale documentation unrelated to this task's own scope (the locked
  region it describes no longer exists in the current engine), not something this task's own
  `--continue-budget` removal needs to preserve — flagging it so the planner does not spend effort
  trying to honor a lock that no longer has a real referent, while also not assuming it is
  necessarily safe to delete without a quick independent check of
  `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md`'s current status.
- **`orchestrator-runtime-files.md`'s "pending_dispatch" section cross-references the removed
  `--continue-budget` reset** (lines 264–267: "`--continue-budget`'s reset explicitly clears it
  too"). This sentence needs updating alongside the Defect-B section replacement, not just the
  Defect-B section itself — a partial doc edit that only touches the named "Defect B" heading
  would leave this dangling cross-reference behind.

## Context Extension Recommendations

- None beyond the doc-consistency fixes named in the WORK items above — this is a well-documented
  subsystem (`orchestrate-state-machine.md` is thorough and mostly accurate; the gaps found are
  specific, single contradictory sentences, not missing topic coverage).

## Appendix

### Files read in full or near-full during this research
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (1859 lines, entire file)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (446 lines, entire file)
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` (200 lines, entire file)
- `agent-system/extensions/core/scripts/parse-command-args.sh` (195 lines, entire file)
- `agent-system/extensions/core/commands/orchestrate.md` (281 lines, entire file)
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (264 lines, entire file)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (relevant sections:
  ~95–120, ~620–800 of 901 lines)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (relevant
  sections: ~195–290 of 405 lines)
- `agent-system/extensions/core/merge-sources/claudemd.md` (targeted greps around the
  `/orchestrate` row and Multi-task syntax paragraph)
- `agent-system/extensions/core/scripts/test-session-runtime-files.sh` (Case 3, lines ~179–228)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` (targeted: Group
  headers via grep, then Groups 2, 4/5, 8 read in full — lines 154–194, 348–391, 497–611)
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` (header/intent,
  lines 1–40)

### Files named by the dispatch but not yet existing (new-file targets for the plan)
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` — does not exist yet; the
  dispatch's ACCEPTANCE clause for the absorbed 214 material names it as the new regression
  suite's home.

### Search queries used
- `grep -n "research_questions\|^# (l)\|^# (f)\|--focus\|continue_budget\|MAX_INFRA_FAILURES\|force_phases_remaining\|plans/\*.md\|reviser-agent\|planner-agent\|cycle_counts\[" scripts/orchestrate-cycle-plan.sh`
- `grep -rln "continue-budget\|continue_budget\|CONTINUE_BUDGET" --include="*.sh" --include="*.md" .`
- `grep -n "^# Group\|Group 8\|continue-budget\|continue_budget\|focus" scripts/tests/test-orchestrate-cycle-plan.sh`
- `grep -n "stop-after-last-named\|fall.through\|falls through" scripts/tests/test-orchestrate-cycle-plan.sh`
- `grep -n "orchestrate\b" -A3 merge-sources/claudemd.md`
- `find . -iname "orchestrate.md" -o -iname "orchestrate-cycle-plan.sh" ...` (initial file
  inventory)
