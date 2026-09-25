# Research Report: Task #258

**Task**: 258 - Stop recording a declined return-meta recovery as HANDOFF_STALE_OR_ABSENT against skill-orchestrate
**Started**: 2026-09-25T20:50:00Z
**Completed**: 2026-09-25T20:50:00Z
**Effort**: small-to-medium (one branch, one shared-library reuse, test extension)
**Dependencies**: task 257 (agent-contract inline-status task) — CONFIRMED COMPLETE (status `completed` in `specs/state.json`); the artifact this task's cheaper path needs (`scripts/lib/return-meta-status-vocabulary.sh`) already exists on disk.
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, `orchestrate-recover-outcome.sh`, `system-defect-record.sh`, `validate-return-meta.sh`, `lib/return-meta-status-vocabulary.sh`, `lint/lint-agent-contracts.sh`, `tests/test-orchestrate-cycle-postflight.sh`), `context/patterns/system-defect-discrimination.md`, `specs/state.json`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dependency has landed.** Task 257 is `completed`, and it already extracted the 8-value `.return-meta.json` status vocabulary into `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh` (`RETURN_META_STATUS_VALUES`, `RETURN_META_SUCCESS_STATUSES`, `is_return_meta_status`, `is_return_meta_success_status`, `RETURN_META_FORBIDDEN_STATUS`/`_MESSAGE`). `orchestrate-recover-outcome.sh` and `validate-return-meta.sh` both already source it. **The "cheaper path" the dispatch asks to evaluate first is now the obviously-cheapest path**: reuse this library's `RETURN_META_FORBIDDEN_STATUS_MESSAGE` / `is_return_meta_status` directly in the WORK (d) branch rather than hand-rolling a message.
- **The dispatch's "no agent-name → agent-file resolver exists" prerequisite is stale — correct this in the plan.** `scripts/system-defect-record.sh` (unchanged by 257) **already** accepts `--dispatched-agent NAME` as an alternative to `--attributed-path PATH` (lines ~11, 122, 139, 156, 229-238) and resolves it via `"$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md"` (a nullglob match), refusing (exit 3, "Signal B attribution unresolvable") if nothing matches. This is exactly the deployed/source-store-agnostic resolver the dispatch says must be built. The only genuinely new glue needed is: (a) pass `--dispatched-agent "$agent_name"` to `system-defect-record.sh` instead of `--attributed-path "$attributed_path"` for the corrected record, and (b) compute the same resolved path locally (3-4 lines, same glob idiom) to pass to `skill_orchestrate_append_detected_defect`'s positional `attributed_path` argument, since that helper only takes a plain string and has no resolver of its own. No new standalone resolver script or function is required.
- **`.reason` (not `.evidence_reason`) is the correct field** — confirmed by reading `orchestrate-recover-outcome.sh`'s header (`reason` documented as one of `NONE|META_MISSING|META_STALE|META_UNPARSEABLE|META_DISPATCH_SEQ_MISMATCH|STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|USAGE`) and its `emit()` calls. `evidence_reason` is confirmed hardcoded to `"NONE"` on every `recovered=false` emit call in the script. The dispatch's correction is accurate and the current WORK (d) branch reads neither field today — it reads only `out_recovered_reported_status` (`.status`), computed a few lines *after* the branch's defect-record call, so it is not even in scope at the point the record is written.
- **Line numbers have drifted** from the dispatch's citations (`:591-612`) because task 259 (also completed) touched this same script afterward. The branch now starts at line 595 (`# ─── WORK (d): ... ───`) and the absent-handoff `if [ ! -f "$handoff_file" ]` / record block runs roughly 610-634. `handoff_expected="true"` is now at line 180, `attributed_path=` at line 328 — both cited correctly by line number in the dispatch, but the WORK (d) range itself needs re-verification at implementation time, not blind reuse of `:591-612`.
- **The closed 14-value enum in `system-defect-record.sh` has NOT gained `PHASE_ACCOUNTING_MISMATCH`** despite task 259 (which contemplated it) also being `completed` — confirmed by grepping the current `case "$defect_class" in ... esac` (lines 162-171): still exactly the 14 values listed in the dispatch. No collision exists right now; a new class (if chosen) is free to add as a 15th.
- **`context/patterns/system-defect-discrimination.md`'s own definition of `HANDOFF_STALE_OR_ABSENT`** ("a handoff whose mtime predates the dispatch window (**or is otherwise absent when expected**), as detected by the stale-handoff gate") is genuinely about the *handoff* being missing/stale, not about a *return-meta status* being out-of-vocabulary. This is textual support, beyond the dispatch's own argument, for treating `reason=STATUS_NOT_SUCCESS` as a materially different defect shape than `reason=META_MISSING`/`STATUS_IN_PROGRESS` (which really are "nothing/incomplete was produced," closer to the documented class).

## Context & Scope

Task 258 fixes a diagnostics-attribution defect (not a causal one): when a dispatch writes no `.orchestrator-handoff.json` AND `orchestrate-recover-outcome.sh` declines to recover a successful outcome from `.return-meta.json`, `orchestrate-cycle-postflight.sh`'s WORK (d) branch unconditionally records `HANDOFF_STALE_OR_ABSENT` against `skill-orchestrate/SKILL.md`, even when the real fault is agent-side (an out-of-vocabulary `.return-meta.json` status, e.g. `"completed"`). Research here verifies every load-bearing factual claim in the dispatch against current source and flags what has changed or was previously miscited.

## Findings

### Codebase Patterns

**The WORK (d) branch, current shape** (`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:595-634`):

```
else
  # WORK (d): dispatch-derived handoff-expectation recording for an ABSENT handoff
  meta_file="${TASK_DIR}/.return-meta.json"
  meta_mtime=$(stat -c %Y "$meta_file" 2>/dev/null || stat -f %m "$meta_file" 2>/dev/null || echo 0)
  meta_touched= [true|false based on meta_mtime >= dispatch_start_ts]

  if [ ! -f "$handoff_file" ]; then
    if [ "$handoff_expected" = "true" ]; then
      echo "ERROR: Skill did not write orchestrator handoff (agent '${agent_name}', ...)" >&2
      [record HANDOFF_STALE_OR_ABSENT, attributed_path, message referencing meta_touched/transport_error]
    else
      echo "handoff not expected for this dispatch ...; no defect recorded." >&2
    fi
  fi
  # (out_recovered_reported_status / dispatch_status read here, AFTER the record call above)
  ...
```

This is reached only when `recovered != "true"` from `orchestrate-recover-outcome.sh` — i.e. only after recovery has already declined — confirming the dispatch's "NUANCE THAT MUST BE PRESERVED" claim: a genuinely successful research/plan/implement dispatch takes the `recovered = true` branch above this one and is logged correctly via the `RECOVERY:` line, never reaching WORK (d) at all.

`$recover_json` (captured just above this whole `if/else`, at the top of the enclosing block) already carries `.reason` — it is simply never read here. The fix is additive: read `.reason` (and reuse the `status` this block later computes as `out_recovered_reported_status`, or hoist that read earlier) to discriminate the three sub-cases the dispatch names.

**`orchestrate-recover-outcome.sh`'s `reason` vocabulary** (verified against the script's own header table and every `emit ... "<REASON>"` call site):

| `reason` | Meaning | Where in WORK (d)'s current test suite |
|---|---|---|
| `META_MISSING` | no `.return-meta.json` at all | Fixtures (A) and (C) — must keep recording `HANDOFF_STALE_OR_ABSENT`, unchanged |
| `META_STALE` | file present but mtime predates the dispatch window | not exercised by WORK (d) fixtures today (file exists but is old — a different shape than "absent") |
| `META_UNPARSEABLE` | file present, fresh, invalid JSON | not exercised |
| `META_DISPATCH_SEQ_MISMATCH` | file present, dispatch_seq field mismatches | exercised only via the direct `orchestrate-recover-outcome.sh` probe at test-file line ~259, not via a WORK (d) postflight fixture |
| `STATUS_IN_PROGRESS` | file present, fresh, `.status == "in_progress"` | not exercised by a WORK (d) fixture today — this is the dispatch's sub-case (ii) |
| `STATUS_NOT_SUCCESS` | file present, fresh, `.status` is any other out-of-vocabulary or non-success value (e.g. `"completed"`, `"failed"` outside the accepted 3-value success subset, or a genuinely bogus string) | not exercised by a WORK (d) fixture today — this is the dispatch's sub-case (iii), the actual incident |
| `USAGE` | argument-count/usage error calling the script itself | not exercised (infrastructure error, not a dispatch outcome) |

Only `META_MISSING` (and implicitly `META_STALE`/`META_UNPARSEABLE`, which behave identically in that they still leave `handoff_file` absent while `.return-meta.json` reports nothing usable) genuinely correspond to "the agent produced nothing usable" in the same sense as an absent handoff. `STATUS_IN_PROGRESS` and `STATUS_NOT_SUCCESS` both mean the agent *did* write something — the failure is that what it wrote doesn't parse as an accepted terminal outcome. This is the textual basis for a three-way (or at minimum two-way: META_MISSING/META_STALE/META_UNPARSEABLE vs. STATUS_IN_PROGRESS/STATUS_NOT_SUCCESS) split in the fixed branch.

**The vocabulary library is already built and already the single source of truth** (`agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh`, sourced by both `orchestrate-recover-outcome.sh` and `validate-return-meta.sh`):

```bash
RETURN_META_STATUS_VALUES=(in_progress researched planned implemented needs_research partial failed blocked)
RETURN_META_FORBIDDEN_STATUS="completed"
RETURN_META_FORBIDDEN_STATUS_MESSAGE="status value is 'completed', which is explicitly forbidden (triggers Claude stop behavior) -- use \"implemented\" instead"
RETURN_META_SUCCESS_STATUSES=(researched planned implemented)
is_return_meta_status() { ... }        # membership in the 8-value enum
is_return_meta_success_status() { ... } # membership in the 3-value success subset
```

`orchestrate-cycle-postflight.sh` does **not** currently source this library (confirmed: no `return-meta-status-vocabulary.sh` reference anywhere in the file). Since the WORK (d) fix needs to word a message like *"agent reported status=completed, which is not in the accepted researched\|planned\|implemented vocabulary,"* the cheapest correct approach is:
- source `lib/return-meta-status-vocabulary.sh` in `orchestrate-cycle-postflight.sh` (mirroring how `orchestrate-recover-outcome.sh` already does it — same deployed/source-store dual-path sourcing idiom used throughout this codebase), then
- when `reason == STATUS_IN_PROGRESS` or `STATUS_NOT_SUCCESS`, build the message from `$dispatch_status` (the file's own `.status`) plus `RETURN_META_FORBIDDEN_STATUS_MESSAGE` when `$dispatch_status == "$RETURN_META_FORBIDDEN_STATUS"`, else a generic "not in the accepted vocabulary" wording referencing `RETURN_META_SUCCESS_STATUSES`.

This avoids hand-rolling a second copy of the forbidden-value sentence, and keeps the message correct even for non-"completed" out-of-vocabulary values (e.g. a typo'd status string).

**The agent-name → file resolver already exists in `system-defect-record.sh`** (verified at lines ~11-30, 122, 139, 156-157, 209-238):

```bash
resolved_path=""
if [ -n "$attributed_path_arg" ]; then
  resolved_path="$(transform_deploy_to_source "$attributed_path_arg")"
elif [ -n "$dispatched_agent_arg" ]; then
  shopt -s nullglob
  agent_matches=("$PROJECT_ROOT"/agent-system/extensions/*/agents/"${dispatched_agent_arg}.md")
  shopt -u nullglob
  if [ "${#agent_matches[@]}" -gt 0 ] && [ -f "${agent_matches[0]}" ]; then
    resolved_path="${agent_matches[0]#"$PROJECT_ROOT"/}"
  fi
fi
case "$resolved_path" in
  agent-system/extensions/*) ;;
  *) echo "REFUSING: Signal B attribution unresolvable ..." >&2; exit 3 ;;
esac
```

This resolves an `agent_name` (e.g. `general-research-agent`) directly to its source-store path (`agent-system/extensions/core/agents/general-research-agent.md`) via a glob over every extension's `agents/` directory — precisely the "handle both trees" requirement the dispatch describes, minus the deployed-tree half, which is irrelevant here because `--attributed-path`'s `transform_deploy_to_source()` is the deployed-path handler and `--dispatched-agent` is *already* source-store-only by construction (it globs `agent-system/extensions/*/agents/`, never `.claude/agents/`). Verified against a real file: `agent-system/extensions/core/agents/general-research-agent.md` opens with `name: general-research-agent`, and the glob pattern `*/agents/general-research-agent.md` matches it directly (filename == frontmatter `name:` value, confirmed across the ~20 sampled agent files in `agents/*.md` and extension `agents/*.md`).

Two call sites in the fixed branch need this resolution, but only one can call `system-defect-record.sh` directly:
1. `system-defect-record.sh --dispatched-agent "$agent_name" ...` — the recorder resolves internally; no local computation needed for this call.
2. `skill_orchestrate_append_detected_defect "$defect_store" "$notice_prefix" "<CLASS>" "$resolved_path_local" ...` (`scripts/skill-base.sh:1467`) — this helper's 4th positional argument (`attributed_path`) is written verbatim into the loop-guard's `.detected_defects[].attributed_source_path` field and into the `[system-defect:auto]` stderr notice; it does **not** call `system-defect-record.sh` and has no resolver of its own. To keep the local record's `attributed_source_path` consistent with what `events.jsonl` actually received, the fix needs 3-4 lines mirroring the exact same glob:
   ```bash
   shopt -s nullglob
   agent_path_matches=("${PROJECT_ROOT}"/agent-system/extensions/*/agents/"${agent_name}.md")
   shopt -u nullglob
   agent_attributed_path="${agent_path_matches[0]:+${agent_path_matches[0]#"${PROJECT_ROOT}"/}}"
   agent_attributed_path="${agent_attributed_path:-$attributed_path}"  # fall back to the shared constant if unresolvable
   ```
   `PROJECT_ROOT` is already computed once near the top of the script (line 148: `PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"`), so no new root-resolution logic is needed.

This is meaningfully cheaper than the dispatch's "NO AGENT-NAME → AGENT-FILE RESOLVER EXISTS" framing suggests — no new script, function, or lookup table needs to be built; only ~4 lines of glue duplicating an existing 4-line glob, because the one existing resolver lives inside a script whose return value isn't otherwise exposed to its caller.

**`attributed_path` reuse across sites** (verified all five call sites in `orchestrate-cycle-postflight.sh`): the shared constant `attributed_path="agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"` (line 328) is passed to `system-defect-record.sh --attributed-path` and to `skill_orchestrate_append_detected_defect` at:
- stray-handoff sweep (`HANDOFF_MISLOCATED`, ~line 370)
- stale-handoff gate (`HANDOFF_STALE_OR_ABSENT`, ~line 401)
- dispatch_seq-mismatch gate (`HANDOFF_STALE_OR_ABSENT`, ~line 427-430)
- recovered-path `ARTIFACTS_SHAPE_MISMATCH` (~line 528-531/583-586 — two near-duplicate sites, single-task and one other branch)
- WORK (d) absent-handoff (`HANDOFF_STALE_OR_ABSENT`, ~line 621-624) — **the one this task fixes**
- Tier C `OFF_SCHEMA_STATUS` (~line 899-902) — a sixth site, not named in the dispatch, also reusing the shared constant; it fires on the `have_outcome=true` / handoff-present path, structurally separate from WORK (d) (different branch, different precondition), so it is out of scope for this task but worth naming as a sibling misattribution instance for the plan's "argued boundary" paragraph.

The dispatch's framing ("this task fixes ONE of at least three sites") is accurate; research finds a fourth/fifth (`OFF_SCHEMA_STATUS` and the second `ARTIFACTS_SHAPE_MISMATCH` near-duplicate) not enumerated in the dispatch, reinforcing that the boundary needs to be stated explicitly rather than assumed narrow.

### External Resources

Not applicable — this is a pure in-repo shell/JSON diagnostics fix with no external API or library surface.

### Recommendations

1. **Reuse `HANDOFF_STALE_OR_ABSENT` for `META_MISSING`/`META_STALE`/`META_UNPARSEABLE`, unchanged** (fixture (A)/(C) safety net, per the dispatch's explicit "DO NOT BREAK IT"). These reasons genuinely mean "nothing usable was produced" — the current message and attribution are defensible for them.
2. **Introduce discrimination on `reason` for `STATUS_IN_PROGRESS` and `STATUS_NOT_SUCCESS`.** At minimum, correct the *message* and *attribution* (via `--dispatched-agent "$agent_name"` / the local glob) for these two, since the current message ("Skill did not write orchestrator handoff") is actively false when a `.return-meta.json` file exists and was read.
3. **Defect-class choice is a genuine, weighable decision, not predetermined** — evaluate against `context/patterns/system-defect-discrimination.md`'s own definition of `HANDOFF_STALE_OR_ABSENT` (handoff-shaped, not status-shaped) before choosing:
   - Reuse `HANDOFF_STALE_OR_ABSENT` with corrected message+attribution for all reasons (simplest, no enum/pattern-doc edit, but leaves the class name itself still slightly mismatched to the `STATUS_NOT_SUCCESS` sub-case).
   - Add a new class (e.g. `RECOVERY_DECLINED` or `STATUS_VOCABULARY_VIOLATION`) for `STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS` only, keeping `HANDOFF_STALE_OR_ABSENT` for `META_MISSING`/`META_STALE`/`META_UNPARSEABLE`. Requires editing `system-defect-record.sh`'s closed 14-value `case` (lines 162-171) and adding a row + registry entry to `context/patterns/system-defect-discrimination.md`. Confirmed the enum has room (no collision with 259's contemplated `PHASE_ACCOUNTING_MISMATCH`, which was never added).
   Either choice satisfies "name the real fault"; the new-class option is more work (two extra files beyond current `file_scope`) for a cleaner taxonomy, and 258's own dispatch explicitly leaves this open ("Weigh the addition against enum growth for its own sake").
4. **Prefer `--dispatched-agent "$agent_name"` over building a bespoke path lookup** for the `system-defect-record.sh` call; add the 3-4 line local glob (shown above) only for the `skill_orchestrate_append_detected_defect` call's positional argument, since that helper cannot resolve on its own.
5. **Source `lib/return-meta-status-vocabulary.sh`** in `orchestrate-cycle-postflight.sh` and build the corrected message from `RETURN_META_FORBIDDEN_STATUS_MESSAGE` (when applicable) / `RETURN_META_SUCCESS_STATUSES` rather than a new literal string.
6. **Test additions**: extend `scripts/tests/test-orchestrate-cycle-postflight.sh` with at minimum one new fixture reproducing `reason=STATUS_NOT_SUCCESS` — a `.return-meta.json` with a fresh mtime and `"status":"completed"` (or another out-of-vocabulary value), no `.orchestrator-handoff.json`, dispatched with `--agent general-research-agent` — asserting: (a) the corrected message text (agent/status-worded, not "Skill did not write orchestrator handoff"), (b) `attributed_source_path` resolves to the agent's own file (`agent-system/extensions/core/agents/general-research-agent.md`) rather than `skill-orchestrate/SKILL.md`, (c) `verdict=failed` is preserved (this is still a genuine work-cycle failure, not silenced), (d) fixtures (A) and (C) (`META_MISSING`) continue to assert `HANDOFF_STALE_OR_ABSENT` attributed to `skill-orchestrate/SKILL.md` unchanged. A `STATUS_IN_PROGRESS` fixture is a reasonable secondary addition but not explicitly required by the dispatch's VERIFICATION section (which names only (a) STATUS_NOT_SUCCESS, (b) META_MISSING, (c) genuinely-stale-handoff).
7. **Do not flip `--handoff-expected`** for research dispatches as the fix mechanism — confirmed by direct inspection that doing so silences the branch entirely (the `else` arm at line 632 prints "handoff not expected ...; no defect recorded" and records nothing), which would lose the genuine `META_MISSING`/`STATUS_NOT_SUCCESS` signal the dispatch explicitly wants preserved, not deleted.

## Decisions

- **Confirmed**: read `.reason` from `recover_json`, not `.evidence_reason` (dispatch's correction verified correct against script source).
- **Confirmed**: task 257's dependency is satisfied; `lib/return-meta-status-vocabulary.sh` exists and is reusable today.
- **Correction to the dispatch's own prerequisite framing**: an agent-name → file resolver already exists in `system-defect-record.sh` via `--dispatched-agent`; the plan should scope the "build a resolver" work down to a small glue read of the resolved path for the local loop-guard append, not a new resolver.
- **Left open for the plan** (per the dispatch's own instruction not to pre-decide): whether to add a new defect class or reuse `HANDOFF_STALE_OR_ABSENT` with corrected attribution/message.

## Risks & Mitigations

- **Risk**: editing the closed 14-value enum in `system-defect-record.sh` collides with the sibling phase-accounting task if both land in the same window. **Mitigation**: confirmed via `specs/state.json` that task 259 is already `completed` and did *not* add `PHASE_ACCOUNTING_MISMATCH` to the enum — no live collision exists at research time; the orchestrator's designated-self-modifying-candidate admission control (cited by the dispatch) prevents co-dispatch regardless.
- **Risk**: line-number drift. The dispatch's `:591-612`/`:180`/`:328` citations are partly stale (the branch now spans roughly 595-634) because task 259 touched this file after the dispatch was authored. **Mitigation**: re-locate by anchor text (`# ─── WORK (d):`, `ERROR: Skill did not write orchestrator handoff`) at implementation time rather than trusting line numbers.
- **Risk**: a fix that changes the message/attribution for `STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS` but keeps the same defect class could still confuse a reader who filters `events.jsonl` by `defect_class=HANDOFF_STALE_OR_ABSENT` expecting only handoff-shaped incidents. **Mitigation**: this is exactly the tradeoff recommendation 3 above surfaces for the plan to decide explicitly, with cost/benefit named.

## Context Extension Recommendations

- **Topic**: agent-name → source-store path resolution.
- **Gap**: `system-defect-record.sh`'s `--dispatched-agent` resolver is not documented anywhere outside its own script header/comments (not in `context/patterns/system-defect-discrimination.md`'s Signal B section, not in a dedicated pattern doc), which is very likely why the dispatch's author believed no resolver existed.
- **Recommendation**: consider a one-line pointer from `system-defect-discrimination.md`'s "Signal B — attribution" section to `system-defect-record.sh`'s `--dispatched-agent` mechanism, so a future task researching attribution does not re-derive this from scratch. Not required for this task's own fix, but cheap and directly motivated by the near-miss this research turned up.

## Appendix

- Files read in full or in relevant part: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (headers, WORK (a)/(d), Tier C, attributed_path sites), `orchestrate-recover-outcome.sh` (full header + emit logic), `system-defect-record.sh` (full), `validate-return-meta.sh` (status-check section), `lib/return-meta-status-vocabulary.sh` (full), `lint/lint-agent-contracts.sh` (`is_dispatchable_agent`/`enumerate_dispatchable_agents`), `tests/test-orchestrate-cycle-postflight.sh` (fixtures A/B/C/D region), `context/patterns/system-defect-discrimination.md` (Signal A table, detection-point registry).
- Commands used: `grep -n`, `sed -n`, `jq` queries against `specs/state.json` for tasks 257/258/259, `python3 -c` JSON scan of `specs/events.jsonl` for `HANDOFF_STALE_OR_ABSENT` rows (confirmed the dispatch's "10 records / Verification consumer repo" claim refers to a different repository's event store, not this one — this repo's own 10 `HANDOFF_STALE_OR_ABSENT` rows are all stale-mtime/dispatch_seq-mismatch shapes, none at the `cycle-postflight-absent-expected-writer` site, consistent with this being the first occurrence of that sub-case as the dispatch states for the *other* repo).
