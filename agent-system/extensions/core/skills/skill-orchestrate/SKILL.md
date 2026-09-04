---
name: skill-orchestrate
description: Autonomous state machine that drives a task through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases. Invoke for /orchestrate command.
allowed-tools: Agent, Bash, Read, Edit
---

# Orchestrate Skill

Fire-and-forget autonomous loop implementing the 10-state task lifecycle state machine.
Drives research, planning, implementation, and blocker escalation without user interaction.

## Context References

Architecture documentation (load as needed):
- `.claude/docs/architecture/orchestrate-state-machine.md` - Complete state table and transition diagram
- `.claude/docs/architecture/handoff-schema.md` - Orchestrator handoff JSON schema

Infrastructure (source as needed):
- `.claude/scripts/skill-base.sh` - Shared skill lifecycle functions

---

## Execution Flow

### Stage 0: Multi-Task Mode Detection

Parse `multi_task_mode` from the delegation context. If true, branch to multi-task stages (MT-1 through MT-5) in the **Multi-Task Mode** section below. If false or absent, fall through to Stage 1 (single-task mode).

Read from delegation context:
- `multi_task_mode` (default: false)
- `session_id`
- `focus_prompt` (default: "")
- `lit_flag` (default: "false")

If `multi_task_mode` is true: skip Stages 1-8 entirely and proceed to Stage MT-1.

---

### Stage 1: Input Validation

Read from delegation context:
- `task_number` (from `task_context.task_number`)
- `session_id`, `focus_prompt`, `lit_flag`
- `continue_budget` (default: `false`) → `continue_budget_flag`. Defect B: explicit,
  operator-typed budget-continuation override for an exhausted work-cycle budget, threaded from
  the command's `--continue-budget` flag. Never inferred from `session_id`, mtime, or any
  automatic signal. See Stage 2 below for the override mechanism.
- `clean_flag` (default: `"false"`) — threaded from the command's `--clean` flag; suppresses
  Stage 3.5 Dispatch Prep's automatic memory retrieval for every dispatch this invocation makes.
- `effort_flag` (default: `""`) — threaded from the command's `--fast` flag; supplies reasoning-
  depth guidance to Stage 3.5 Dispatch Prep and to Stage 1b's agent routing below.
- `model_flag` (default: `""`) — threaded from the command's `--haiku`/`--sonnet`/`--opus`/
  `--fable` flags; selects the model family for every lifecycle dispatch this invocation makes.
  Consumed by Stage 3.5 Dispatch Prep's model-override resolution below. The not-set sentinel is
  the **empty string**, matching `parse-command-args.sh`'s `MODEL_FLAG=""` default — **not** the
  literal token `null`, despite `commands/research.md`'s prose framing.
- `hard_mode` — derived once, here, as `hard_mode="false"; [ "$effort_flag" = "hard" ] &&
  hard_mode="true"`. Consumed by Stage 3.5 Dispatch Prep's hard-mode contract injection below,
  and reserved for later conditional state-machine branches (churn/three-strikes counters, the
  burnout circuit breaker) that read this same boolean rather than re-deriving it.
- `force_phases` (default `""`) — threaded from the command's composable `--research`/`--plan`/
  `--implement` flags (A2). Single-task-only. Consumed by Stage 2b below, which splits it into
  the ordered forced-phase queue the state machine loop's Stage 3 sub-step 3c checks first, ahead
  of status-derived dispatch. Never forwarded to any admission-gate script.

**Hard-mode state-machine migration — acceptance checklist.** Each behavior below is reproduced
in this engine behind `$hard_mode`, mapped to the stage that now implements it:

| Behavior | Stage | Notes |
|----------|-------|-------|
| Conditional cycle budget (13 vs. 5) | Stage 2 head | `MAX_CYCLES` branch, before `orchestrate-loop-guard-init.sh` |
| Unified loop-guard JSON schema | Stage 2 | `hard_mode`/`burnout_signals_this_session`/`plan_version` fields, written in both modes |
| `loop-guard-staleness` detector (3-signal) | Stage 2 | `loop-guard-staleness:begin`/`:end`, hard-mode-gated only (D4) |
| Churn-state init (`.orchestrator-churn-state.json`) | Stage 2 | after `mint_dispatch_seq()`, hard-mode-gated only |
| Burnout circuit-breaker gate | Stage 3, sub-step `3b-hard` | between `3b.` and `3c.`, `3c.` left byte-identical (D2) |
| H1 single-blocking-phase-per-cycle implement dispatch | Stage 4, `#### State: planned or implementing` | whole handler forked on `$hard_mode` (D5); base `else` branch unchanged |
| H6 per-target churn counters | Stage 5b | after Stage 5's own `phases_completed` assignment (D7) |
| H5 three-strikes divergence-audit dispatch | Stage 5b | same stage as H6, on `new_target_churn >= 3` |
| Stage 5a / Stage 5b mutual exclusion | Stage 5a (gate), Stage 5b (heading) | exactly one reachable per `hard_mode` value |
| H4 adversarial-verification gate | Stage 4, `#### State: researched` and `#### State: planning` | both handlers forked on `$hard_mode`; corrected matcher, not the source engine's |

Everything in the source engine's state-machine logic (H1/H4/H5/H6/the burnout breaker, plus the
loop-guard/churn-state plumbing they depend on) is now reproduced here.

**H4 adversarial-verification gate — now ported.** See the acceptance-checklist row above. Two
scope boundaries are worth recording so a future reader is not misled the way this file's own
former residue note once misled: (a) the gate is hard-mode-gated only — base mode
(`$hard_mode = false`) is unchanged; (b) the gate is NOT present on the multi-task path (Stage
MT-3 / MT-4), mirroring the `-hard` source engine, whose own multi-task path has no H4 gate
either — this is a migration boundary carried over from the source engine, not an omission
introduced here.

**Asymmetry decision (recorded, "recorded not acted on" style)**: the H4 gate's corrected matcher
— the two `grep` patterns landed in the `researched` and `planning` handlers above — was landed
ONLY in this engine's ported copy, deliberately. The `-hard` engine's own copy of the gate
retains its original, known-false-negative patterns unchanged, because that engine is scheduled
for deletion by a separate, downstream engine-deletion task, and mirroring the fix there would
create a second site to maintain for a file about to be removed, with no correctness benefit. See
that file's own matching asymmetry note at its `researched` handler.

Resolve from `specs/state.json`:
```bash
PADDED_NUM=$(printf "%03d" "$task_number")
TASK_DATA=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)
```

If `TASK_DATA` is empty: exit with error "Task $task_number not found in state.json".

Extract: `PROJECT_NAME`, `TASK_TYPE` (default: "general"), `DESCRIPTION`, `TASK_DIR="specs/${PADDED_NUM}_${PROJECT_NAME}"`.

Then resolve the absolute anchor that every dispatched agent will be handed. `TASK_DIR` stays
relative (many consumers below depend on that); `TASK_DIR_ABS` is the anchor that goes into
delegation contexts, because a dispatched agent has no reliable way to know what the ambient
working directory will be when its Write tool runs.

```bash
# SKILL_REPO_ROOT is exported by skill-base.sh, which resolves it from BASH_SOURCE rather than
# from the ambient cwd. $(pwd) is a last-resort fallback for direct invocation.
TASK_DIR_ABS="${TASK_DIR_ABS:-${SKILL_REPO_ROOT:-$(pwd)}/${TASK_DIR}}"
HANDOFF_PATH_ABS="${TASK_DIR_ABS}/.orchestrator-handoff.json"
```

### Stage 1b: Resolve Task-Type Routing

Map task_type to the correct research, plan, and implementation agents via the single canonical
agent resolver, `command-route-agent.sh` — sourced from the shared manifest-routing-lib.sh
ladder (the same one `command-route-skill.sh` uses), against each manifest's `routing_agents`
declarations. No case table, no directory probe, no sed derivation: agent names are declared
data, not derived strings (see `context/guides/manifest-routing-schema.md`).

```bash
# 4th argument is the effort flag ("fast"/"hard"/""). Only "hard" currently changes resolution
# behavior in manifest-routing-lib.sh's routing_agents_hard block, so passing $effort_flag here
# is a no-op for "fast"/"" today — future-proofing the call sites rather than a live behavior
# change for --fast.
source .claude/scripts/command-route-agent.sh "research" "$TASK_TYPE" "general-research-agent" "$effort_flag"
RESEARCH_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "plan" "$TASK_TYPE" "planner-agent" "$effort_flag"
PLANNER_AGENT="$AGENT_NAME"
source .claude/scripts/command-route-agent.sh "implement" "$TASK_TYPE" "general-implementation-agent" "$effort_flag"
IMPLEMENT_AGENT="$AGENT_NAME"
echo "[orchestrate] Task type: $TASK_TYPE → research=$RESEARCH_AGENT, plan=$PLANNER_AGENT, implement=$IMPLEMENT_AGENT"
```

### Stage 2: Loop Guard Initialization

Create or read the loop guard file. This tracks cycle count across conversational turns.

**Ephemeral, never committed.** `.orchestrator-loop-guard` is per-cycle runtime state with no
freshness check on read (see the resume branch below: any syntactically valid guard file at this
path is trusted, with no `session_id` or mtime comparison against the current dispatch). A
git-restored copy of a stale guard would silently resume a wrong `cycle_count`/`infra_failures`
pair — exactly the hazard this file's gitignore coverage exists to prevent. The same is true, in
hard mode only, of `.orchestrator-churn-state.json` (H5/H6 per-target churn counters): a second
ephemeral, gitignored, never-committed runtime file with the identical no-freshness-check-on-read
trust model, created and read only inside `$hard_mode` branches below. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and rationale.

```bash
# Cycle budget is mode-aware: hard mode's per-phase dispatch (H1) needs roughly one cycle per
# phase, so a 7-phase plan needs ~7 cycles minimum — carried forward as the fixed
# MAX_CYCLES=13 below (the value the former standalone hard-mode engine used before it was
# merged into this file). Base mode's whole-plan-per-dispatch handler keeps its original budget.
if [ "$hard_mode" = "true" ]; then
  MAX_CYCLES=13
else
  MAX_CYCLES=5
fi
# Single shared implementation, orchestrate-loop-guard-init.sh — see that script's header for
# the full contract (MAX_INFRA_FAILURES constant, loop_guard_file/handoff_file assignment,
# mkdir -p "$TASK_DIR", and the blocker-escalation counter pair applied further below in this
# same fence). This one call now covers both effort-mode branches in this file — everything else
# in this stage (the hard-only loop-guard-staleness detector, churn-state init) stays
# mode-specific, either because it differs or because it sits inside the locked
# budget-continuation-override region below, which this script and its call site never touch.
loop_guard_init_json=$(bash .claude/scripts/orchestrate-loop-guard-init.sh "$TASK_DIR" "${HANDOFF_PATH_ABS}")
loop_guard_file=$(echo "$loop_guard_init_json" | jq -r '.loop_guard_file')
handoff_file=$(echo "$loop_guard_init_json" | jq -r '.handoff_file')
MAX_INFRA_FAILURES=$(echo "$loop_guard_init_json" | jq -r '.max_infra_failures')
# Hard-mode-only per-target churn-state file (H5/H6), plus the H4 adversarial-verification
# gate's own state variable. Assigned unconditionally so both are always in scope, but only ever
# created/read inside `$hard_mode` branches below (churn-state init, further down this stage,
# and Stage 5b's H6 detector; the gate variable in the `researched` and `planning` handlers'
# H4 gate, and its post-dispatch resets in the `not_started` and `researching` handlers).
if [ "${hard_mode:-false}" = "true" ]; then
  churn_file="${TASK_DIR}/.orchestrator-churn-state.json"
  adversarial_verified=false
fi

# Live plan-lineage reference, written into the guard's `plan_version` field in BOTH modes (D3 —
# one loop-guard JSON schema, not a per-mode fork). Computing it is a single cheap
# `ls | sort -V | tail -1` even in base mode, and the hard-only `loop-guard-staleness` detector
# (below) reads it as its Signal 2. Safe when plans/ does not exist yet (task in
# researching/planning status): the ls glob then matches nothing, `sort -V | tail -1` on empty
# input yields an empty string, and `basename ""` also yields an empty string here, so the
# explicit `:-none` fallback is required — absent plans/ is never itself evidence of staleness.
current_plan_version=$(basename "$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)" 2>/dev/null)
current_plan_version="${current_plan_version:-none}"

# --- loop-guard-staleness:begin ---
# Hard-mode-only operational-staleness detector: a genuinely-present, never-git-touched guard
# that is simply superseded or old on disk (distinct from the git-restoration hazard the
# ephemeral/gitignored classification protects against). Three OR-combined signals; any one
# tripping is sufficient. See context/standards/orchestrator-runtime-files.md's "Operational
# staleness: a second, orthogonal freshness axis" for the full policy, thresholds, and the
# anti-session_id defense. D4: this detector stays strictly `$hard_mode`-gated — whether base
# mode should gain it unconditionally is a separate, undecided question (see the Asymmetry
# decision note at the end of this stage). No task-lock.sh dependency in this region -- it only
# reads, decides, and archives (mv), so it is directly executable in a fixture harness. The
# pre-existing `budget-continuation-override` region and the resume/churn-state blocks that
# follow are left completely unmodified: once a stale guard/churn file is mv'd aside, `[ -f ]` is
# false and each falls through to its own existing fresh-init branch naturally, at
# cycle_count=0 / total_churn=0.
if [ "${hard_mode:-false}" = "true" ]; then
  loop_guard_stale=false
  if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
    stale_reason=""

    # Signal 1: schema/version drift.
    guard_max_cycles=$(jq -r '.max_cycles // empty' "$loop_guard_file")
    if [ -n "$guard_max_cycles" ] && [ "$guard_max_cycles" != "$MAX_CYCLES" ]; then
      stale_reason="${stale_reason}max_cycles drift (guard=${guard_max_cycles}, live=${MAX_CYCLES}); "
    fi

    # Signal 2: plan-lineage drift. Skipped entirely when either side is empty or "none" -- a
    # missing plan_version (old-format guard) or an absent plans/ directory is never itself
    # evidence of staleness.
    guard_plan_version=$(jq -r '.plan_version // "none"' "$loop_guard_file")
    if [ -n "$guard_plan_version" ] && [ "$guard_plan_version" != "none" ] \
       && [ -n "$current_plan_version" ] && [ "$current_plan_version" != "none" ] \
       && [ "$guard_plan_version" != "$current_plan_version" ]; then
      stale_reason="${stale_reason}plan_version drift (guard=${guard_plan_version}, live=${current_plan_version}); "
    fi

    # Signal 3: mtime-age backstop. An mtime of 0 (stat failed on both GNU and BSD forms) is
    # treated as NOT stale -- an unreadable timestamp is not evidence.
    guard_mtime=$(stat -c %Y "$loop_guard_file" 2>/dev/null || stat -f %m "$loop_guard_file" 2>/dev/null || echo 0)
    stale_days="${ORCHESTRATOR_LOOP_GUARD_STALE_DAYS:-7}"
    if [ "$guard_mtime" -gt 0 ]; then
      now_ts=$(date -u +%s)
      age_seconds=$((now_ts - guard_mtime))
      stale_threshold_seconds=$((stale_days * 86400))
      if [ "$age_seconds" -gt "$stale_threshold_seconds" ]; then
        stale_reason="${stale_reason}mtime age (${age_seconds}s since last update, threshold ${stale_threshold_seconds}s / ${stale_days} days); "
      fi
    fi

    if [ -n "$stale_reason" ]; then
      loop_guard_stale=true
      stale_ts=$(date -u +%s)
      stale_guard_dest="${TASK_DIR}/.stale-loop-guard-${stale_ts}.json"
      echo "[orchestrate] ERROR: STALE LOOP GUARD — ${stale_reason}Archived to ${stale_guard_dest} for inspection; reinitializing fresh guard at cycle 0." >&2
      if mv "$loop_guard_file" "$stale_guard_dest" 2>/dev/null; then
        :
      else
        echo "[orchestrate] WARNING: could not move stale guard aside to ${stale_guard_dest}; ${loop_guard_file} is still in place and must be removed manually before the next cycle." >&2
      fi
      # Co-archive the churn-state file under the loop guard's inherited verdict (not an
      # independently-derived detector) and the same timestamp suffix, so the two archives are
      # correlatable. Only when it exists -- never create an empty churn archive.
      if [ -f "$churn_file" ]; then
        stale_churn_dest="${TASK_DIR}/.stale-churn-state-${stale_ts}.json"
        echo "[orchestrate] Co-archiving churn state to ${stale_churn_dest} (inherits the loop guard's stale verdict)." >&2
        if mv "$churn_file" "$stale_churn_dest" 2>/dev/null; then
          :
        else
          echo "[orchestrate] WARNING: could not move stale churn state aside to ${stale_churn_dest}; ${churn_file} is still in place and must be removed manually before the next cycle." >&2
        fi
      fi
    fi
  fi
fi
# --- loop-guard-staleness:end ---

# --- budget-continuation-override:begin ---
# Defect B: cycle_count is a per-task, CUMULATIVE budget that survives re-invocation BY DESIGN --
# it is deliberately NOT reset on a new session_id, because that would let an operator silently
# bypass MAX_CYCLES by simply re-invoking /orchestrate. test-session-runtime-files.sh Case 3 is
# the regression protecting this decision; this override must never disturb it. The override
# below is the sanctioned, explicit, loudly-logged escape hatch for a genuinely exhausted budget
# -- never automatic, never session_id-gated, never inferred from mtime. Runs immediately after
# the `$hard_mode`-gated `loop-guard-staleness` region above (which only ever archives a stale
# guard aside and falls through) and before the pre-existing resume-read block below.
if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  peek_cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  if [ "$peek_cycle_count" -ge "$MAX_CYCLES" ]; then
    if [ "$continue_budget_flag" = "true" ]; then
      exhaust_ts=$(date -u +%s)
      exhausted_guard_dest="${TASK_DIR}/.exhausted-loop-guard-${exhaust_ts}.json"
      echo "[orchestrate] BUDGET EXHAUSTED (cycle_count=${peek_cycle_count}/${MAX_CYCLES}) — --continue-budget authorized a fresh budget. Archiving exhausted guard to ${exhausted_guard_dest} for auditability, reinitializing at cycle_count=0 with cross-invocation history fields (dispatch_seq_counter, detected_defects) preserved." >&2
      if cp "$loop_guard_file" "$exhausted_guard_dest" 2>/dev/null; then
        # Reinit IN PLACE from the just-archived copy: reset only cycle_count, never wipe
        # dispatch_seq_counter (must never repeat a value within this task) or detected_defects.
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$exhausted_guard_dest" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      else
        echo "[orchestrate] WARNING: could not archive exhausted guard to ${exhausted_guard_dest}; proceeding without archiving (cycle_count reset in place)." >&2
        jq --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.cycle_count = 0 | .last_updated = $updated' \
          "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
      fi
    else
      echo "[orchestrate] ERROR: work-cycle budget exhausted (cycle_count=${peek_cycle_count}/${MAX_CYCLES}). This is a budget limit, not an error condition -- the task's plan may still have incomplete phases." >&2
      echo "[orchestrate] To continue this task's work, explicitly authorize a fresh budget: /orchestrate ${task_number} --continue-budget" >&2
      exit 1
    fi
  fi
fi
# --- budget-continuation-override:end ---

if [ -f "$loop_guard_file" ] && jq empty "$loop_guard_file" 2>/dev/null; then
  # Resume: read existing guard. No session_id or mtime check — see the ephemerality note above;
  # this is precisely why a git-restorable guard would corrupt the cycle budget.
  cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
  infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
  # System-defect observation log for this run (contract: Stage MT-1's `detected_defects`
  # declaration). `// []` is the forward-compatible read for a guard file written before this
  # field existed, matching the `// 0` idiom above.
  detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
  # dispatch_seq_counter: orchestrator-minted per-dispatch identity (Defect A), read identically
  # regardless of effort mode. `// 0` forward-compatible read, matching cycle_count's own idiom —
  # a guard written before this field existed resumes at 0, never repeating a value already
  # minted this task since the counter only ever increments (see mint_dispatch_seq() below).
  dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
  # burnout_signals_this_session: hard-mode-only counter (D3 — written in BOTH modes via the
  # unified loop-guard schema below, so this read is unconditional and forward-compatible; base
  # mode simply never increments or reports it). `// 0` matches the other counters' idiom.
  burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
  # Observational-only session_id tracking (NEVER a gate — see Ephemeral note above and
  # context/standards/status-markers.md's rationale: SESSION_ID is regenerated per /orchestrate
  # invocation, while this guard is explicitly designed to survive across conversational turns.
  # The real same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not
  # session_id equality). A mismatch is logged, never branched on.
  guard_session_id=$(jq -r '.session_id // ""' "$loop_guard_file")
  if [ -n "$guard_session_id" ] && [ "$guard_session_id" != "$session_id" ]; then
    echo "[orchestrate] INFO: loop guard was last written by a different session_id ('${guard_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
  fi
  # Hard-mode-only burnout reporting, fully self-closed BEFORE the unconditional echo below so
  # the always-present resume-read `if [ -f "$loop_guard_file" ]` above this block stays the
  # ONLY still-open conditional at the point of that echo (test-loop-guard-budget-override.sh
  # extracts from the budget-continuation-override sentinel through that exact echo text and
  # appends one synthetic `fi`; a conditional wrapped around the echo itself would leave two
  # unclosed `if`s there and break the extraction's bash -n check).
  if [ "${hard_mode:-false}" = "true" ]; then
    echo "[orchestrate] Resuming (hard mode) — burnout signals so far: $burnout_signals_this_session"
  fi
  echo "[orchestrate] Resuming — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
else
  # Fresh start: create guard atomically via init-marker. A plain
  # `>` redirect has no O_EXCL semantics, so two racing writers could both take
  # this branch and stomp each other's counters; init-marker's mkdir-gate +
  # tmp-mv payload guarantees exactly one winner. On a lost race (exit 1),
  # degrade to the same resume-read the `if`-branch above performs.
  # hard_mode_json: JSON-boolean form of the existing $hard_mode string ("true"/"false" is
  # already valid JSON, so this is a direct --argjson pass-through, not a re-derivation).
  hard_mode_json="$hard_mode"
  if jq -n \
    --arg session_id "$session_id" \
    --argjson max_cycles "$MAX_CYCLES" \
    --argjson max_infra_failures "$MAX_INFRA_FAILURES" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson hard_mode_json "$hard_mode_json" \
    --arg plan_version "$current_plan_version" \
    '{
      "session_id": $session_id,
      "cycle_count": 0,
      "max_cycles": $max_cycles,
      "infra_failures": 0,
      "max_infra_failures": $max_infra_failures,
      "current_state": "reading",
      "detected_defects": [],
      "started": $started,
      "last_updated": $started,
      "dispatch_seq_counter": 0,
      "hard_mode": $hard_mode_json,
      "burnout_signals_this_session": 0,
      "plan_version": $plan_version
    }' | bash .claude/scripts/task-lock.sh init-marker "$loop_guard_file"; then
    cycle_count=0
    infra_failures=0
    detected_defects='[]'
    dispatch_seq_counter=0
    burnout_signals_this_session=0
    echo "[orchestrate] Starting fresh — MAX_CYCLES=$MAX_CYCLES, MAX_INFRA_FAILURES=$MAX_INFRA_FAILURES"
  else
    # Lost the creation race: another writer won. Resume from their guard, reading BOTH
    # counters — not just cycle_count — and the system-defect observation log alongside them.
    cycle_count=$(jq -r '.cycle_count // 0' "$loop_guard_file")
    infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file")
    detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file")
    dispatch_seq_counter=$(jq -r '.dispatch_seq_counter // 0' "$loop_guard_file")
    burnout_signals_this_session=$(jq -r '.burnout_signals_this_session // 0' "$loop_guard_file")
    if [ "$hard_mode" = "true" ]; then
      echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (burnout signals so far: $burnout_signals_this_session, infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
    else
      echo "[orchestrate] Resuming (lost init race) — cycle $cycle_count of $MAX_CYCLES (infra failures: $infra_failures of $MAX_INFRA_FAILURES)"
    fi
  fi
fi

# mint_dispatch_seq(): named-shim to the single shared implementation,
# skill_orchestrate_mint_dispatch_seq (scripts/skill-base.sh) — see that function's header for the
# full contract. Kept as a locally-named function (not called directly by name) because Stage 4/5
# call sites below still say `mint_dispatch_seq`, and this file pair is where a one-sided rename
# is a known recurring defect class. Source is defensive/idempotent: this Stage 2 fence has no
# earlier explicit source line of its own to depend on.
source .claude/scripts/skill-base.sh
mint_dispatch_seq() {
  skill_orchestrate_mint_dispatch_seq "$loop_guard_file"
}

# Hard-mode-only churn-state init/resume (H5/H6): per-target churn counters and audit-dispatch
# bookkeeping, read by Stage 5b's churn-detection/three-strikes logic. Gated identically to the
# `churn_file` assignment and the `loop-guard-staleness` region above.
if [ "${hard_mode:-false}" = "true" ]; then
  if [ -f "$churn_file" ] && jq empty "$churn_file" 2>/dev/null; then
    total_churn=$(jq -r '.total_churn // 0' "$churn_file")
    # Observational-only session_id tracking (NEVER a gate — identical rationale to the loop
    # guard's own treatment above: SESSION_ID is regenerated per /orchestrate invocation, while
    # this file is explicitly designed to survive across conversational turns. The real
    # same-task concurrency guard is task-lock.sh's acquire/heartbeat/release mutex, not
    # session_id equality).
    churn_session_id=$(jq -r '.session_id // ""' "$churn_file")
    if [ -n "$churn_session_id" ] && [ "$churn_session_id" != "$session_id" ]; then
      echo "[orchestrate] INFO: churn state was last written by a different session_id ('${churn_session_id}' vs current '${session_id}') — expected on conversational resume, not gated."
    fi
  else
    # Fresh start: create churn state atomically via init-marker; on a lost race (exit 1),
    # resume-read total_churn (matching the `if`-branch above).
    if jq -n --arg session_id "$session_id" \
      '{"session_id": $session_id, "total_churn": 0, "target_churn": {}, "adversarial_triggers": 0, "audit_dispatches": 0}' \
      | bash .claude/scripts/task-lock.sh init-marker "$churn_file"; then
      total_churn=0
    else
      total_churn=$(jq -r '.total_churn // 0' "$churn_file")
    fi
  fi
fi

# Blocker escalation counter (reset each /orchestrate invocation) — from the same shared
# orchestrate-loop-guard-init.sh call above.
blocker_escalation_count=$(echo "$loop_guard_init_json" | jq -r '.blocker_escalation_count')
MAX_BLOCKER_ESCALATIONS=$(echo "$loop_guard_init_json" | jq -r '.max_blocker_escalations')

# Drift detection constants (reset each /orchestrate invocation) — base-mode-only; hard mode has
# no Stage 5a Drift Inspection equivalent (its own Stage 5b H5 divergence-audit mechanism plays
# that role instead — see the mutual-exclusion decision record at Stage 5a/5b below), so these
# stay out of the shared script AND, now that both modes share this one file, out of scope when
# `hard_mode` is true. Only ever read/incremented from inside Stage 5a's own base-mode-gated
# call site, so leaving them unset in hard mode is safe.
if [ "${hard_mode:-false}" != "true" ]; then
  drift_inspection_count=0
  MAX_DRIFT_INSPECTIONS=1
  DRIFT_COMPLETION_THRESHOLD=0.70
  DRIFT_REVISION_THRESHOLD=0.30
fi
```

**On the `budget-continuation-override` region above (Defect B)**: this rewrites the SAME
`loop_guard_file` in place (via the archived copy), specifically so `dispatch_seq_counter` and
`detected_defects` are carried forward rather than reset to their fresh-init defaults. This
decision applies identically to both effort modes, since this single engine now handles both.

**Decision record**: `cycle_count` is a per-task, cumulative budget that survives re-invocation by
design — this is the existing, deliberate semantics (protected by
`test-session-runtime-files.sh` Case 3), not a new decision introduced by this override.

**Asymmetry decision (recorded, "recorded not acted on" style)**: the 3-signal
`loop-guard-staleness` detector now exists in this engine, behind the `$hard_mode` gate (D4) —
it is no longer absent from this file the way the note below once described. Whether base mode
(`$hard_mode = false`) should gain the detector UNCONDITIONALLY is a SEPARATE, undecided
question, left open by this migration: the detector's presence here is scoped to hard mode only,
and extending it to base mode would be a distinct, future decision requiring its own rationale —
not something this task settles by porting the hard-only region.

### Stage 2b: Forced-Phase Queue Initialization

Runs once, after Stage 2 (Loop Guard Initialization) and before Stage 3's loop opens. This is the
functional target for what this stage's originating task description called "Stage 1b/2" —
`Stage 1b` (above) is agent routing, not phase selection; this stage is where `force_phases` (A2)
actually resolves into a queue the state machine loop consumes.

**Build the ordered queue.** Split the `force_phases` string (Stage 1, default `""`) on commas
into an ordered bash array, validating each entry against the closed set `{research, plan,
implement}` and failing loudly on anything else — `force_phases` is minted only by
`parse-command-args.sh`'s own canonical-lifecycle-order accumulation (see this stage's
originating plan's Phase 1), so an invalid entry here means a corrupted delegation context, not a
user typo, and deserves a loud failure rather than a silent skip.

```bash
force_queue=()
# Initialized here, unconditionally, so no cycle can ever read force_invoked unset — Stage 3's
# 3c reassigns it explicitly on every cycle (both the terminal-check and status-derived branches
# set it to "false"; the forced-dispatch branch sets it to "true"), but this Stage 2b default is
# the belt-and-braces floor for the very first read, before Stage 3's loop has run even once.
force_invoked="false"
if [ -n "${force_phases:-}" ]; then
  IFS=',' read -ra _force_phases_split <<< "$force_phases"
  for _fp in "${_force_phases_split[@]}"; do
    case "$_fp" in
      research|plan|implement)
        force_queue+=("$_fp")
        ;;
      *)
        echo "[orchestrate] ERROR: force_phases contains an invalid entry '${_fp}' (expected one of: research, plan, implement). This should be unreachable from parse-command-args.sh's own accumulation — treating as a corrupted delegation context." >&2
        exit 1
        ;;
    esac
  done
fi
```

**Phase-to-handler map (prose, referenced by heading — never inlined).** A popped `force_queue`
entry dispatches the SAME Stage 4 handler body the status-derived path would use for the
equivalent status, by pointer:

| Forced phase | Stage 4 handler (by heading) |
|---|---|
| `research` | State: not_started or not started |
| `plan` | State: researched |
| `implement` | State: planned or implementing |

Referencing one of these handlers is a pointer, not an edit — it does not collide with the
sibling task that owns these handler bodies (see this stage's originating plan's Cross-task
composition table).

**`resolve_cycle_artifact_number()`.** Named function, defined once here, called from Stage 3's
3c on every cycle that dispatches a phase (forced or status-derived). Wraps
`skill_read_artifact_number` — itself entirely UNCHANGED by this stage — choosing `mode` and
`artifact_dir` from the phase about to run: `mode="current"`/`artifact_dir="reports/"` for a
research cycle, `mode="prev"` with the matching directory for a plan or implement cycle (planner
and implementer share the round research opened, per `skill_read_artifact_number`'s own existing
`"prev"` semantics).

```bash
resolve_cycle_artifact_number() {
  local phase="$1"  # "research" | "plan" | "implement"
  local mode artifact_dir
  case "$phase" in
    research)
      mode="current"
      artifact_dir="reports/"
      ;;
    plan)
      mode="prev"
      artifact_dir="plans/"
      ;;
    implement)
      mode="prev"
      artifact_dir="summaries/"
      ;;
  esac
  skill_read_artifact_number "$task_number" "$PADDED_NUM" "$PROJECT_NAME" "$artifact_dir" "$mode"
  # Exports ARTIFACT_NUMBER / ARTIFACT_PADDED — consumed by Stage 4's preamble sentence below,
  # which every handler's `context` object then additionally carries as
  # `artifact_number: $ARTIFACT_NUMBER`.
}
```

**Observability write (never authoritative, never gates admission).** Record the still-pending
forced phases in the loop guard, in the same jq-write style Stage 3's 3b already uses against
`loop_guard_file`:

```bash
force_phases_remaining=$(IFS=,; echo "${force_queue[*]:-}")
jq --arg remaining "$force_phases_remaining" \
  '.force_phases_remaining = $remaining' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

**Empty-queue invariant.** When `force_queue` is empty (the overwhelmingly common case — no
forcing flag was passed), this stage is a no-op: `force_invoked` is `false` on every cycle, and
every downstream path (Stage 3's 3c, Stage 4's dispatch, Stage 5's postflight tail) behaves
byte-for-byte as it did before this stage existed.

**End-to-end chain (A2, recorded once here for a future reader tracing the whole feature):**
`parse-command-args.sh` (flag detection, canonical-order accumulation) → `commands/orchestrate.md`
(6 threading sites, post-slimming: the exports comment, the flag-description bullet, the
single-task and multi-task `Skill` args strings, and their two JSON delegation blocks) → this
skill's Stage 1 `force_phases` bullet → this Stage 2b's `force_queue` →
Stage 3's 3c (`forced_phase` / `force_invoked` / `resolve_cycle_artifact_number()` →
`ARTIFACT_NUMBER`) → Stage 4's handler `context` object (carries `artifact_number:
$ARTIFACT_NUMBER`, per this file's Stage 4 preamble sentence) → Stage 5's own call to
`orchestrate-cycle-postflight.sh` (`--force-invoked "${force_invoked:-false}"`) → the
monotonic-max clamp and the artifact-round-advance block, both inside that one script (WORK (f)
and WORK (g) respectively — see `docs/architecture/orchestrate-cycle-postflight.md`).

### Stage 3: State Machine Loop

**Entry reconcile (once per invocation, never per-cycle)**: before the state machine loop opens,
run `reconcile-task-status.sh` exactly once against this task. The failure this repairs is a
*previous, separate* invocation that crashed before postflight — observable only at the start of
a fresh invocation, not on every cycle iteration (a per-cycle call here would be redundant cost
against up to `MAX_CYCLES` iterations and would fight the preflight writes `skill_preflight_update`
already makes between dispatches within this same run). Live (not `--dry-run`): no human is
reliably present to gate on in `/orchestrate`'s no-confirmation design, and the handoff-aware
promotion guard now bounds what an automatic promotion can do. Bracketed because a live no-op
prints nothing — the empty-output branch must still be visible:

```bash
recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
if [ -n "$recon_out" ]; then
  echo "$recon_out"
else
  echo "[orchestrate] Entry reconcile: no stranded status found for task $task_number"
fi
```

The loop runs until a terminal condition is reached or MAX_CYCLES is hit.

```
while [ "$cycle_count" -lt "$MAX_CYCLES" ]; do
```

At the top of each iteration:

**3a. Read current task status**

```bash
current_status=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .status' \
  specs/state.json)
echo "[orchestrate] Cycle $((cycle_count + 1))/$MAX_CYCLES — status: $current_status"
```

**3b. Update loop guard with current state**

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
   --arg sid "$session_id" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .last_session_id = $sid' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"

# Task-lock heartbeat: refresh at the same per-cycle boundary as the loop guard, so a
# multi-hour single-task /orchestrate run (whose lock was acquired once at orchestrate.md's
# CHECKPOINT 1) never goes stale under its own hand. No-op with a warning if the lock is
# somehow missing or held by another session — heartbeat never blocks this loop. See
# .claude/context/patterns/task-lock.md.
#
# This is the CYCLE-layer heartbeat, complementary to (and now backstopped by) the mechanized
# PHASE-layer refresh inside update-phase-status.sh itself: it remains necessary here because a
# research or plan cycle has no phase transitions of its own to hook, so this per-cycle site is
# the only refresh those cycles get. It is not redundant with the mechanized site during an
# implement cycle either — this fires once per whole cycle, the mechanized site fires once per
# phase transition within that cycle.
bash .claude/scripts/task-lock.sh heartbeat "$task_number" "$session_id" 2>/dev/null || true

# In-flight session registry heartbeat: same per-cycle boundary, refreshing the entry
# command-gate-in.sh registered at CHECKPOINT 1. Best-effort and non-blocking. See
# .claude/context/patterns/task-lock.md's Session-Registry CLI section.
bash .claude/scripts/task-lock.sh session-heartbeat "$session_id" 2>/dev/null || true
```

**3b-hard. Burnout circuit-breaker gate (hard mode only)**

**MANDATORY when `$hard_mode` is true — runs EVERY loop iteration**, after `current_status` is
known (3a) and the loop guard is persisted (3b), strictly before any Stage 4 dispatch decision.
Skipped entirely when `hard_mode` is false. This is not an optional guideline; it is a gate. Per
`.claude/context/contracts/orchestrator-discipline.md`, check all three self-checks before
proceeding to Stage 4:

1. **If you are about to Read a path you have already read this session without an
   intervening `Agent` dispatch having produced new information, STOP and dispatch
   `$RESEARCH_AGENT` instead** (focus_prompt = a literal restatement of the exact unresolved
   question) — do not complete the re-read.
2. **If this is the second or later consecutive orchestrator turn reasoning about task content
   with no `Agent` tool call in between, STOP reasoning immediately and take response (a) or
   (b) from the contract now** — do not produce a third such turn.
3. **If you are about to reverse a phase, target, or escalation decision without a fresh
   dispatch having just produced the new finding that justifies it, STOP and either dispatch
   `$RESEARCH_AGENT` to obtain that finding (reasoning-about-what-a-phase-should-do) or jump
   directly to Stage 6 (deciding-whether-to-keep-escalating) — never reverse on inline
   reasoning alone.**

No new artifact type is introduced. The forced dispatch reuses Stage 5b's divergence-audit
dispatch shape, triggered by a burnout signal instead of a churn-count threshold; the forced
escalation reuses Stage 6 directly.

**On any signal firing**, increment the scalar counter in the same 3b-style jq write that
already touches `loop_guard_file`:

```bash
if [ "${hard_mode:-false}" = "true" ]; then
  burnout_signals_this_session=$((burnout_signals_this_session + 1))
  jq --argjson count "$burnout_signals_this_session" \
     --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.burnout_signals_this_session = $count | .last_updated = $updated' \
    "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
  echo "[orchestrate] H-orch: burnout signal detected (session total: $burnout_signals_this_session) — forcing dispatch/escalation, not inline reasoning" >&2
fi
```

**3c. Dispatch by state.** A three-way, STRICTLY ORDERED decision, replacing the former plain
"dispatch by state" pointer. Order matters and is stated here as a requirement, not left
implicit — a forced phase NEVER overrides a terminal state, and `force_queue` (Stage 2b's
per-cycle parse of `force_phases`) takes priority over status-derived dispatch whenever it is
non-empty. One unified decision (shown as a
single flowing `if`/`elif`/`else` below, not three independently-fenced fragments, so the
control flow stays syntactically whole):

1. **Terminal check, first.** If `current_status` is `completed`, `abandoned`, or `expanded`, run
   the existing terminal-state handler UNCHANGED (see State: `completed` / States: `abandoned`,
   `expanded` in Stage 4) — a forced phase never overrides a terminal state. If `force_queue` is
   non-empty when this branch is taken, emit a loud named refusal FIRST, citing
   `rules/state-management.md`'s "Cannot transition from terminal states".
2. **Else if `force_queue` is non-empty**: pop its head into `forced_phase`, set
   `force_invoked=true` for this cycle, resolve the artifact round via
   `resolve_cycle_artifact_number "$forced_phase"` (Stage 2b), and execute the Stage 4 handler
   Stage 2b's phase-to-handler map names for `forced_phase` — by pointer, exactly as written
   there, never inlined.
3. **Else**: set `force_invoked=false`, derive `cycle_phase` from `current_status` (the same
   research/plan/implement grouping the Stage 4 handler headings already use — `not_started`/
   `not started`/`researching` → `research`; `researched`/`planning` → `plan`; `planned`/
   `implementing`/`partial` → `implement`; every other status, including `blocked` and unknown
   states, dispatches no agent and resolves no artifact number), call
   `resolve_cycle_artifact_number "$cycle_phase"` only when `cycle_phase` is non-empty, and
   dispatch by state exactly as today.

```bash
if [[ "$current_status" == "completed" || "$current_status" == "abandoned" || "$current_status" == "expanded" ]]; then
  if [ "${#force_queue[@]}" -gt 0 ]; then
    echo "[orchestrate] REFUSED: task $task_number is in terminal state [$current_status] — forced phase(s) '${force_queue[*]}' cannot run. Cannot transition from terminal states (rules/state-management.md). Running the existing terminal-state handler below unchanged; no forced dispatch occurs this cycle." >&2
  fi
  force_invoked=false
  # Fall through to the existing terminal-state handler for $current_status, unchanged
  # (see State: `completed` / States: `abandoned`, `expanded` in Stage 4).
elif [ "${#force_queue[@]}" -gt 0 ]; then
  forced_phase="${force_queue[0]}"
  force_queue=("${force_queue[@]:1}")
  force_invoked=true
  resolve_cycle_artifact_number "$forced_phase"
  # Dispatch the Stage 2b-mapped Stage 4 handler for $forced_phase, by pointer.
else
  force_invoked=false
  cycle_phase=""
  case "$current_status" in
    not_started|"not started"|researching) cycle_phase="research" ;;
    researched|planning) cycle_phase="plan" ;;
    planned|implementing|partial) cycle_phase="implement" ;;
  esac
  if [ -n "$cycle_phase" ]; then
    resolve_cycle_artifact_number "$cycle_phase"
  fi
  # Dispatch by state exactly as today (see State Handlers in Stage 4).
fi
```

**Forced-sequence-exhausted terminal condition.** After the cycle whose popped `forced_phase` left
`force_queue` empty completes its Stage 5 postflight, the loop STOPS — it does NOT fall through to
status-derived dispatch. This is checked and applied at Stage 7 (Loop Guard Update), routed
through the same `EXIT (...)` reporting idiom the existing MAX_CYCLES/MAX_INFRA_FAILURES terminal
conditions use, so the run's own summary names it.

---

### Stage 3.5: Dispatch Prep — superseded by `scripts/orchestrate-build-dispatch.sh`

No dispatch prep happens inline in this file any more. `scripts/orchestrate-build-dispatch.sh`
is the sole implementation: it performs what this stage used to describe in prose (memory
retrieval, literature briefing, the effort note, the hard-mode contract block, and model
resolution) plus every additional per-dispatch input (task description and task_type, the
artifact round, phase-specific report/plan paths, the normalized continuation pointer, the
handoff path and dispatch sequence, territory when set, and the user-decision contract
reference), and writes the result to `specs/{NNN}_{slug}/.dispatch/{seq}.md`. Every Stage 4
(single-task) and Stage MT-4 (multi-task) dispatch site below calls this script once and uses a
fixed pointer prompt — see any Stage 4 handler for the call shape. Auxiliary/diagnostic
dispatches (H4 adversarial-verification re-dispatch, Stage 5a drift inspection, Stage 5b
churn/divergence audit, Stage 6 blocker escalation) do not call this script and keep their inline
prompts, unchanged.

---

### Stage 4: State Handlers

**Every handler's `context` object below additionally carries `artifact_number: $ARTIFACT_NUMBER`**,
resolved this cycle by Stage 2b's `resolve_cycle_artifact_number()` (called from Stage 3's 3c
before the handler below runs). Stated once here and not restated per handler — no individual
handler's `context` table row is edited to add this field.

#### State: `not_started` or `not started`

```bash
skill_preflight_update "$task_number" "research" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" research "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase research. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff (Stage 5). Reset `adversarial_verified=false` (hard mode only) — a fresh research dispatch must always force the H4 gate to re-verify rather than trusting a stale `true` from a previous cycle. Increment cycle_count.

#### State: `researching`

**Converged (was: exit with warning; see below for why this is now safe)**: dispatch to
research, identically to the `not_started` handler above. `scripts/command-gate-in.sh`'s
`task-lock.sh acquire-retry` already `return 1`s and aborts the entire single-task `/orchestrate`
invocation, before Stage 1 is ever entered, whenever a FRESH foreign lock refuses after its
bounded retry budget. This handler is only reachable once this session already holds the lock —
so the former warning's claim ("another session is actively researching") is provably false in
every reachable case: either no other session holds the lock (this session's own acquire
succeeded outright), or a prior session's lock was stale and reclaimed. A task sitting in
`researching` with a dead prior session's stale lock is exactly the stranded-task case this
convergence exists to unstick; re-dispatching research is the correct, idempotent recovery
action (a fresh research pass adds a new report, it does not corrupt or lose the old one).

```bash
skill_preflight_update "$task_number" "research" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" research "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase research. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff (Stage 5). Reset `adversarial_verified=false` (hard mode only) — a fresh research dispatch must always force the H4 gate to re-verify rather than trusting a stale `true` from a previous cycle. Increment cycle_count.

#### State: `researched`

Read research artifact path from state.json:
```bash
research_artifact=$(jq -r --argjson num "$task_number" \
  '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
  specs/state.json)
```

**H4: Adversarial verification gate (hard mode only)** — ported from the superseded
standalone hard-mode engine's `researched` handler, landing corrected matcher patterns
rather than transcribing the original false-negative ones (see the companion word-boundary
portability audit for the general defect shape this instance exercises). In base mode
(`$hard_mode = false`) this gate is a no-op and `skill_preflight_update` below runs unchanged.

```bash
if [ "${hard_mode:-false}" = "true" ] && [ "$adversarial_verified" = "false" ]; then
  echo "[orchestrate] H4: Dispatching adversarial verification before planning" >&2

  if [ -n "$research_artifact" ] && [ -f "$research_artifact" ]; then
    # Check if adversarial verification section already exists in report, AND that it contains
    # a claim-verification table matched by SHAPE, not by a fixed header string (non-fatal
    # structural strengthening; both checks must pass to skip re-dispatch). Shape: a table-cell
    # containing the word "claim" immediately followed by a cell containing both "source" and
    # "counterexample" (case- and spacing-insensitive, tolerant of extra columns). Both known
    # passing formats match: the canonical `| Claim | Source/Counterexample | ... |` header and
    # the observed `| # | Claim under attack | Source / counterexample | Outcome |` header. An
    # unrelated table does not match.
    #
    # The heading check tolerates an optional numeric prefix (`## 7.`, `## 7.2.`, or the
    # unnumbered `## Adversarial Self-Verification`) — the `-hard` engine's fixed-string check
    # false-negatives on any numbered heading. The table check deliberately omits `\b`
    # word-boundary anchors: the deployed POSIX/DFA `-E` grep mis-evaluates a `\b` anchor
    # occurring downstream of an earlier `\b`-anchored subexpression separated by a `[^|]*` run,
    # producing a false negative even against the canonical header — the `|`-delimited cell
    # structure alone does the discriminating work, so the anchors are deliberately dropped for
    # grep-portability, not restored (see the companion word-boundary portability audit).
    if grep -qE '## ([0-9]+\.([0-9]+\.)?[[:space:]]*)?Adversarial Self-Verification' "$research_artifact" && \
       grep -qiE '\|[^|]*claim[^|]*\|[^|]*source[^|]*counterexample[^|]*\|' "$research_artifact"; then
      echo "[orchestrate] H4: Adversarial verification section with Claim Verification Table found in report. Proceeding to planning." >&2
      adversarial_verified=true
    else
      # Dispatch a focused verification research pass. $RESEARCH_AGENT never writes
      # .orchestrator-handoff.json, per the Stage 3.6 "Scoping Decision" in
      # general-research-agent.md (core's own hard-mode research agent counterpart is deleted; the cslib
      # and lean hard-mode research agents mirror the same scoping decision) and the Handoff Writers table
      # in docs/architecture/handoff-schema.md, so no absolute anchor (handoff_path) is passed
      # here, and orchestrator_mode is explicitly false.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false
      dispatch_seq=$(mint_dispatch_seq)

      Agent tool:
        subagent_type: $RESEARCH_AGENT
        prompt: "Adversarial verification pass for task $task_number. Read the research report at $research_artifact and verify all load-bearing claims. Focus: divergence audit — check for analysis-paralysis signatures, verify source citations, flag uncertain claims."
        delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", orchestrator_mode: false}

      # After the Agent tool returns, before Stage 5: judge the tool call's OWN outcome per
      # context/patterns/infra-failure-discrimination.md and set dispatch_was_transport_error=true
      # ONLY if the call itself returned a transport/API-layer error with no subagent-authored
      # text of any kind. Any subagent-authored output means false.
      Increment cycle_count. Loop continues — do NOT fall through to skill_preflight_update or
      the planning dispatch below this cycle.
    fi
  else
    adversarial_verified=true  # No report to verify; proceed
  fi
fi
```

**Preflight and planning dispatch** — reached when hard mode is off, or the gate above has
confirmed `adversarial_verified=true`. NEVER reached from inside the re-dispatch branch above
(which re-dispatches `$RESEARCH_AGENT` while status is still `researched`; a preflight there
would incorrectly regress status to `researching`). This is the single plan-preflight call for
this handler.

```bash
if [ "${hard_mode:-false}" != "true" ] || [ "$adversarial_verified" = "true" ]; then
```

```bash
skill_preflight_update "$task_number" "plan" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" plan "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$PLANNER_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase plan. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

#### State: `planning`

**Converged (was: exit with warning, same pattern as the former `researching` handler; see that
handler above for the full "this session provably holds the lock" justification, which applies
identically here)**: dispatch to plan, identically to the `researched` handler above.

Read research artifact path from state.json:
```bash
research_artifact=$(jq -r --argjson num "$task_number" \
  '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
  specs/state.json)
```

**H4: Adversarial verification gate (hard mode only)** — ported from the superseded
standalone hard-mode engine's `researched` handler, landing corrected matcher patterns
rather than transcribing the original false-negative ones (see the companion word-boundary
portability audit for the general defect shape this instance exercises). In base mode
(`$hard_mode = false`) this gate is a no-op and `skill_preflight_update` below runs unchanged.

```bash
if [ "${hard_mode:-false}" = "true" ] && [ "$adversarial_verified" = "false" ]; then
  echo "[orchestrate] H4: Dispatching adversarial verification before planning" >&2

  if [ -n "$research_artifact" ] && [ -f "$research_artifact" ]; then
    # Check if adversarial verification section already exists in report, AND that it contains
    # a claim-verification table matched by SHAPE, not by a fixed header string (non-fatal
    # structural strengthening; both checks must pass to skip re-dispatch). Shape: a table-cell
    # containing the word "claim" immediately followed by a cell containing both "source" and
    # "counterexample" (case- and spacing-insensitive, tolerant of extra columns). Both known
    # passing formats match: the canonical `| Claim | Source/Counterexample | ... |` header and
    # the observed `| # | Claim under attack | Source / counterexample | Outcome |` header. An
    # unrelated table does not match.
    #
    # The heading check tolerates an optional numeric prefix (`## 7.`, `## 7.2.`, or the
    # unnumbered `## Adversarial Self-Verification`) — the `-hard` engine's fixed-string check
    # false-negatives on any numbered heading. The table check deliberately omits `\b`
    # word-boundary anchors: the deployed POSIX/DFA `-E` grep mis-evaluates a `\b` anchor
    # occurring downstream of an earlier `\b`-anchored subexpression separated by a `[^|]*` run,
    # producing a false negative even against the canonical header — the `|`-delimited cell
    # structure alone does the discriminating work, so the anchors are deliberately dropped for
    # grep-portability, not restored (see the companion word-boundary portability audit).
    if grep -qE '## ([0-9]+\.([0-9]+\.)?[[:space:]]*)?Adversarial Self-Verification' "$research_artifact" && \
       grep -qiE '\|[^|]*claim[^|]*\|[^|]*source[^|]*counterexample[^|]*\|' "$research_artifact"; then
      echo "[orchestrate] H4: Adversarial verification section with Claim Verification Table found in report. Proceeding to planning." >&2
      adversarial_verified=true
    else
      # Dispatch a focused verification research pass. $RESEARCH_AGENT never writes
      # .orchestrator-handoff.json, per the Stage 3.6 "Scoping Decision" in
      # general-research-agent.md (core's own hard-mode research agent counterpart is deleted; the cslib
      # and lean hard-mode research agents mirror the same scoping decision) and the Handoff Writers table
      # in docs/architecture/handoff-schema.md, so no absolute anchor (handoff_path) is passed
      # here, and orchestrator_mode is explicitly false.
      dispatch_start_ts=$(date -u +%s)
      dispatch_was_transport_error=false
      dispatch_seq=$(mint_dispatch_seq)

      Agent tool:
        subagent_type: $RESEARCH_AGENT
        prompt: "Adversarial verification pass for task $task_number. Read the research report at $research_artifact and verify all load-bearing claims. Focus: divergence audit — check for analysis-paralysis signatures, verify source citations, flag uncertain claims."
        delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit", orchestrator_mode: false}

      # After the Agent tool returns, before Stage 5: judge the tool call's OWN outcome per
      # context/patterns/infra-failure-discrimination.md and set dispatch_was_transport_error=true
      # ONLY if the call itself returned a transport/API-layer error with no subagent-authored
      # text of any kind. Any subagent-authored output means false.
      Increment cycle_count. Loop continues — do NOT fall through to skill_preflight_update or
      the planning dispatch below this cycle.
    fi
  else
    adversarial_verified=true  # No report to verify; proceed
  fi
fi
```

**Preflight and planning dispatch** — reached when hard mode is off, or the gate above has
confirmed `adversarial_verified=true`. NEVER reached from inside the re-dispatch branch above
(which re-dispatches `$RESEARCH_AGENT` while status is still `researched`; a preflight there
would incorrectly regress status to `researching`). This is the single plan-preflight call for
this handler.

```bash
if [ "${hard_mode:-false}" != "true" ] || [ "$adversarial_verified" = "true" ]; then
```

```bash
skill_preflight_update "$task_number" "plan" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" plan "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$PLANNER_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase plan. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, research_artifacts: [research_artifact], orchestrator_mode: true, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

#### State: `planned` or `implementing`

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

**D5 — the whole handler body is forked on `$hard_mode`.** The hard branch (H1) dispatches
exactly one OPEN phase per cycle; the base (`else`) branch below is the pre-existing whole-plan
dispatch, byte-identical to before this fork.

```bash
if [ "${hard_mode:-false}" = "true" ]; then
```

##### Hard branch: Per-Phase Dispatch (H1)

```bash
# Read current handoff to determine phase progress.
if [ -f "$handoff_file" ]; then
  phases_completed=$(jq -r '.phases_completed // 0' "$handoff_file")
  phases_total=$(jq -r '.phases_total // 0' "$handoff_file")
  last_skeleton=$(jq -r '.skeleton // false' "$handoff_file")
else
  phases_completed=0
  phases_total=0
  last_skeleton=false
fi
# D7: phases_completed_before/phases_completed_after are referenced by the Stage 5b churn
# signature below but were, before this migration, set by NO stage in either engine (verified by
# grep — hard-file line 1091 is the only consumer). Capture it here, immediately after the
# handoff read above, so it is in scope before any dispatch this cycle might make; Stage 5b
# (after Stage 5's own phases_completed assignment) supplies phases_completed_after.
phases_completed_before="$phases_completed"

# Heading-scan phase selection, replacing a naive next_phase=$((phases_completed + 1)) integer
# increment (could not address N.1/N.2 sub-phase headings, sparse numbering, or
# skeleton-exhaustion). Mirrors the same Stage 3b fix the superseded standalone hard-mode
# implementer skill once carried.
next_phase=""
phase_scan_inconclusive=false
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  # Sourced from the shared anchor (scripts/lib/phase-heading-patterns.sh) rather than
  # re-derived inline. Uses the library's OPEN alternation (NOT STARTED|IN PROGRESS|PARTIAL|
  # BLOCKED) and extract_phase_number so a non-conforming heading is never silently
  # mis-selected or truncated.
  . .claude/scripts/lib/phase-heading-patterns.sh
  # --- resume-scan-conformance-gate:begin ---
  # Whole-file conformance check BEFORE the filtered scan below. PHASE_HEADING_ERE admits
  # conforming headings only, so a non-conforming heading is not merely unmatched by that grep
  # -- it is INVISIBLE to it, and the scan would silently select the next conforming OPEN
  # heading instead, dispatching out of order on top of unfinished work.
  # has_nonconforming_phase_headings is the required boolean predicate; the
  # `nonconforming_phase_headings | grep -q .` pipe form is forbidden (unsafe under pipefail).
  if has_nonconforming_phase_headings "$plan_path"; then
    warn_nonconforming "$plan_path" "orchestrate-h1-next-phase" || true
    phase_scan_inconclusive=true
  else
    next_heading=$(grep -E "${PHASE_HEADING_ERE} .*${PHASE_STATUS_OPEN_ERE}" "$plan_path" | head -1)
    if [ -n "$next_heading" ]; then
      next_phase=$(extract_phase_number "$next_heading") || next_phase=""
      if [ -z "$next_phase" ]; then
        # Defense-in-depth only, and unreachable by construction: the grep above already
        # guarantees this line matches PHASE_HEADING_ERE. Funnelled into the same sentinel so
        # there is exactly one inconclusive path, never a second silent one.
        phase_scan_inconclusive=true
      fi
    fi
  fi
  # --- resume-scan-conformance-gate:end ---
fi

if [ "$phase_scan_inconclusive" = "true" ]; then
  echo "[orchestrate] H1: non-conforming phase heading(s) in $plan_path — the filtered resume scan cannot see them, so the true next phase is UNKNOWN." >&2
  echo "[orchestrate] Refusing to dispatch, and refusing to claim skeleton-exhaustion or completion. Fix the plan's heading grammar (see plan-format.md's canonical phase-heading shape) and re-run." >&2
  EXIT (partial)

elif [ -n "$next_phase" ]; then
  # --- marker-handoff-crosscheck-predispatch:begin ---
  # Defect 6, PRE-DISPATCH and dispatch-REFUSING. Distinct from base Stage 5's own
  # `marker-handoff-crosscheck` region, which is POST-dispatch and diagnostic-and-downgrading;
  # both are retained (see this task's plan Phase 5). An interrupted dispatch can leave the
  # plan's phase markers ahead of the handoff (marker claims [COMPLETED], handoff's own
  # phases_completed has not confirmed it yet -- see context/contracts/wrap-up.md's "Ordering:
  # Handoff Write Precedes Marker Promotion"). Compare the marker-derived completed count
  # against the handoff's own phases_completed (already read above) before trusting the
  # heading scan's next_phase selection. The has_nonconforming_phase_headings ordering
  # obligation is already satisfied here by construction: this elif branch is reached only
  # after that check already ran (and passed) earlier in this same block.
  marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$plan_path" 2>/dev/null || echo 0)
  if [ "$marker_completed_count" != "$phases_completed" ]; then
    echo "[orchestrate] H1: MARKER/HANDOFF MISMATCH — plan file shows ${marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but the handoff's own phases_completed=${phases_completed}. Not dispatching the successor over unconfirmed work." >&2
    if [ "$marker_completed_count" -gt "$phases_completed" ]; then
      # Downgrade the specific disputed phase heading -- the (phases_completed + 1)-th
      # [COMPLETED]/[COMPLETED WITH EXCLUSIONS] heading by order of appearance -- to
      # [PARTIAL], matching the manual downgrade the operator performed in the observed
      # incident.
      disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$plan_path" | sed -n "$((phases_completed + 1))p")
      if [ -n "$disputed_line" ]; then
        disputed_linenum="${disputed_line%%:*}"
        disputed_text="${disputed_line#*:}"
        echo "[orchestrate] H1: downgrading disputed phase heading to [PARTIAL]: ${disputed_text}" >&2
        sed -i -E "${disputed_linenum}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "$plan_path"
      fi
    fi
    EXIT (partial)
  fi
  # --- marker-handoff-crosscheck-predispatch:end ---

  echo "[orchestrate] H1: Per-phase dispatch — phase $next_phase (heading-scan)" >&2

  # Mint this phase's dispatch identity (Defect A) before building dispatch_context, so the
  # per-phase JSON literal below can carry it inline alongside handoff_path.
  dispatch_seq=$(mint_dispatch_seq)

  # Territory (H7, Defect 5): no cross-agent FILE conflict exists within this orchestrator's OWN
  # dispatches (exactly one blocking Agent call per cycle — see "Parallel Wave Dispatch:
  # DISABLED" note below). Defect 5 is a DIFFERENT concern: a woken PREDECESSOR dispatch (see
  # context/patterns/dispatch-report-not-termination.md) resuming outside this orchestrator's
  # own control flow. The orchestrator does not parse the plan's "Files to modify" list itself
  # -- it points the agent at the plan/phase location it already has in this same context, and
  # the agent (unrestricted in what it may read) derives its own owned_files from the phase's
  # own section. Setting `territory` here (non-empty) is what causes Stage 3.5's `implement`
  # `core_contracts` to append `territory.md` — see that stage's `territory` input row.
  territory='{
    "owned_files": "derive from plan_path'\''s Phase '$next_phase' \"Files to modify\" list",
    "read_only_files": [],
    "forbidden_files": [],
    "concurrency_note": "This declaration asserts only which files THIS dispatch owns. It does NOT assert exclusive access -- a still-live predecessor may exist. If you observe foreign commits, foreign uncommitted modifications, or a running build you did not start, STOP and report it rather than proceeding or dismissing it. See context/contracts/territory.md and context/patterns/dispatch-report-not-termination.md."
  }'

  dispatch_context='{
    "task_number": '$task_number',
    "task_type": "'$TASK_TYPE'",
    "session_id": "'$session_id'",
    "orchestrator_mode": true,
    "effort_flag": "hard",
    "plan_path": "'$plan_path'",
    "roadmap_path": "specs/ROADMAP.md",
    "phase_number": '$next_phase',
    "task_dir": "'$TASK_DIR_ABS'",
    "handoff_path": "'$HANDOFF_PATH_ABS'",
    "dispatch_seq": '$dispatch_seq',
    "territory": '$territory'
  }'

  # This preflight sits inside the `[ -n "$next_phase" ]` branch ONLY — never in the elif
  # skeleton-exhaustion branch or the trailing else (all-complete) branch below, neither of
  # which dispatches an implement agent. Its remaining side effects are the workflow-active
  # marker write and the plan-level [STATUS] stamp (via update-plan-status.sh) — it writes NO
  # per-phase marker, on any path: the dispatched implementation agent owns every per-phase
  # [IN PROGRESS]/[COMPLETED] transition directly via its own explicit phase-status calls, as
  # the first action of processing whichever phase it actually works on (see
  # general-implementation-agent.md's Phase Checkpoint Protocol / Stage 4A, which every
  # implement-dispatch target — base or hard-mode, core or extension — follows the same shape
  # of). This is deliberate, not an oversight — re-deriving "the
  # first NOT STARTED phase" here with a narrower scan could advance a phase this dispatch
  # never touched, diverging from the wider `next_phase` selection above whenever the
  # dispatched phase was itself a resumed IN PROGRESS/PARTIAL/BLOCKED one.
  skill_preflight_update "$task_number" "implement" "$session_id"

  # Dispatch window for infra-failure discrimination — see
  # context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch.
  dispatch_start_ts=$(date -u +%s)
  dispatch_was_transport_error=false
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5
Dispatch Prep's sole implementation). `territory` (set above) is non-empty, so the script's
`hard_contracts_block` includes `territory.md`:

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts" --hard --territory "$territory")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" implement "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

`phase_mission_block` is genuinely per-cycle content the script does not gather (the specific
numbered plan-phase and completed/total counts change every cycle) and stays authored inline,
appended to the fixed pointer prompt below:

```bash
# D6: build_hard_mode_phase_mission() carries ONLY the non-duplicated residue of the hard
# engine's build_hard_mode_prompt_context() — the phase-only mission line, the settled-design
# preamble instruction (which has no contract file of its own), and the "PHASES COMPLETED: n
# of m" line. It deliberately does NOT restate anti-analysis, wrap-up, recovery,
# phase-closure, or pre-edit-gate — the dispatch file's hard_contracts_block (built above with
# `territory` in scope) already injects all of those as <hard-mode-contracts> entries.
build_hard_mode_phase_mission() {
  echo "
HARD MODE DISPATCH — PHASE MISSION:

1. Mission: Implement phase $next_phase only. Do not continue past this phase.
2. Settled Design Preamble: State the decided design before first tool call.

PHASES COMPLETED: $phases_completed of $phases_total
"
}
phase_mission_block=$(build_hard_mode_phase_mission)
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase implement (plan phase $next_phase). Read $dispatch_file first and execute it exactly; it names every input, output path and contract." then append `phase_mission_block` |
| `context` | `$dispatch_context` (built above, unchanged) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output means `false`. Then read handoff (Stage 5), check churn
state (Stage 5b), and increment `cycle_count`.

```bash
elif [ "$last_skeleton" = "true" ]; then
  # Skeleton-exhaustion routing: no incomplete phase heading remains AND the last handoff
  # declared skeleton=true. Derive the follow-up task list from the actually-shipped
  # wrap-up.md field `sorry_inventory[].follow_up_task` — NOT the unpopulated top-level
  # `.follow_up_tasks`.
  follow_up_tasks=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | join(", ")' "$handoff_file")
  follow_up_count=$(jq -r '[.sorry_inventory[]?.follow_up_task | select(. != null)] | unique | length' "$handoff_file")
  echo "[orchestrate] Skeleton plan exhausted — follow-up tasks pending: {${follow_up_tasks}}" >&2

  # This postflight call is routed through the pr_ready target argument (never raw-edit
  # state.json). --allow-pr-ready is required here because update-task-status.sh restricts
  # pr_ready to task_type == "pr" unless explicitly overridden; this skeleton-exhaustion
  # branch is the sanctioned task-type-agnostic exception to that guard. Because this call is
  # a postflight operation, update-task-status.sh's own postflight:pr_ready -> completed
  # mapping (see context/standards/status-markers.md's "Target Arguments vs. Resting States"
  # subsection) resolves the resting state to completed regardless of task type.
  bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id" --allow-pr-ready

  # Propagate completion_summary/roadmap_items via the single shared implementation,
  # skill_orchestrate_propagate_completion (scripts/skill-base.sh), through a locally-named
  # shim (Stage 4/5 call sites elsewhere in this file pattern already say the shim name, not
  # the shared function directly). No precomputed JSON is passed — this branch has no cached
  # recovery JSON and needs a fresh read. dispatch_start_ts is still correct here: this branch
  # is only entered on a cycle where no new dispatch occurred, so the variable still holds the
  # last real per-phase implement dispatch's timestamp, preceding that dispatch's
  # .return-meta.json write.
  source .claude/scripts/skill-base.sh
  hard_orchestrate_propagate_completion() {
    skill_orchestrate_propagate_completion "$1" "$2" "$3" "$4" "${5:-}" "[orchestrate]"
  }
  hard_orchestrate_propagate_completion "$task_number" "$TASK_TYPE" "$TASK_DIR" "${dispatch_start_ts:-9999999999}"

  rm -f "$loop_guard_file"  # loop-termination-only cleanup — see Stage 8 note.
  rm -rf "${TASK_DIR}/.dispatch/"  # loop-termination-only cleanup — see orchestrator-runtime-files.md.
  EXIT (success)

else
  # No incomplete phase heading remains and the last handoff was NOT a skeleton: all phases
  # are genuinely complete. Do not blindly dispatch phase 1 and do not loop toward MAX_CYCLES
  # here -- fall through without a new Agent dispatch; Stage 5 Part B's
  # phases_completed >= phases_total gate performs the actual status transition.
  echo "[orchestrate] No incomplete phase heading remains and last handoff was not a skeleton — deferring to Stage 5 completion gate." >&2
fi
```

**Parallel Wave Dispatch: DISABLED (scoped to the hard branch's own per-phase dispatch).** The
Per-Phase Dispatch handler above is the sole implement-dispatch path THIS BRANCH (`hard_mode ==
"true"`) uses: the orchestrator dispatches exactly one phase per cycle and blocks on its return —
no simultaneous/background `Agent` calls. Territory contracts (H7) still inform the single-phase
dispatch context above, but never fan out into parallel dispatch here. This is a statement about
what this orchestrator's own Stage 4 does — it never issues two concurrent `Agent` calls from
THIS branch — not a claim about the state of the world: a previously-dispatched agent may still
be live via a self-armed watcher/monitor or an operator resume (see
`context/patterns/dispatch-report-not-termination.md`), entirely outside this orchestrator's own
control flow.

##### Base branch: whole-plan dispatch (unchanged)

```bash
else
```

```bash
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" implement "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase implement. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

After Agent tool returns: read handoff. Increment cycle_count.

```bash
fi
```

#### State: `partial`

**Cross-reference**: the identical triage rule applied by hand below is also available as an
executable check, `scripts/orchestrate-triage-classify.sh single`. That script is the executable
form of this same rule, including its dual-form continuation-pointer resolution (nested
`continuation_context.handoff_path` OR flat `continuation_path`), and both engines now agree on
every row here except the NON-discharged sub-case of `blocked` — a narrower exception than
before this task, since the DISCHARGED sub-case now converges too (see the justification in the
"State: `blocked`" handler below).

Read `.orchestrator-handoff.json` to determine sub-state:

```bash
handoff=$(cat "$handoff_file" 2>/dev/null || echo '{}')
blockers=$(echo "$handoff" | jq -c '.blockers // []')
# Dual-form resolution + normalization: a continuation pointer may arrive as either the
# deprecated, read-only-accepted nested continuation_context.handoff_path (no writer emits this
# today -- its sole writer function has been deleted) OR the flat top-level continuation_path
# (the one canonical form live H9 hard-mode wrap-up writers actually emit). Resolve either form
# and normalize into the single shape the dispatch context below and
# context/patterns/subagent-continuation-loop.md both
# expect: { handoff_path, orchestrator_mode: true }, or null if neither form is present. This
# mirrors scripts/orchestrate-triage-classify.sh's continuation_ok predicate exactly — do not let
# this hand-applied copy drift from that script again.
continuation=$(echo "$handoff" | jq -c '
  ((.continuation_context // null) | if . != null then (.handoff_path // null) else null end) as $nested |
  (.continuation_path // null) as $flat |
  ($nested // $flat) as $resolved |
  if $resolved != null then {handoff_path: $resolved, orchestrator_mode: true} else null end
')
blocker_count=$(echo "$blockers" | jq 'length')
```

**Sub-state: continuation available** (`continuation` — the normalized object above — is non-null;
its `handoff_path` key is guaranteed non-null whenever `continuation` itself is non-null, by
construction of the `jq` resolution above):

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

```bash
# Defense-in-depth: status is typically already "implementing" here, so this is
# usually a no-op (update-task-status.sh preflight is idempotent).
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — see
# context/patterns/infra-failure-discrimination.md. Reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" implement "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase implement. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", continuation_context: continuation, lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` (`continuation_context` here is the **normalized** `continuation` object built above — `{ handoff_path, orchestrator_mode: true }` — never a raw read of the handoff's `continuation_context` or `continuation_path` field. This is the secondary-gap fix: it is what lets the successor implement dispatch actually consume a continuation the standard flat-form writer emitted. Do not "simplify" this back to a raw field read.) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

**Sub-state: blockers present** (blocker_count > 0):

Invoke blocker escalation (Stage 6). Increment cycle_count after escalation.

**Sub-state: no handoff, no blockers**:

A base-mode dispatch never writes `.orchestrator-handoff.json` (see docs/architecture/handoff-schema.md's
Handoff Writers table), so this is the normal shape a base-mode `[PARTIAL]` task takes, not a
dead end. Both engines route this sub-state to `implement` — see
`scripts/orchestrate-triage-classify.sh`'s header table. Probe the prior dispatch's outcome for
resume context before opening this cycle's dispatch window:

```bash
# Resume context for a base-mode partial: no handoff exists (base-mode dispatches never
# write one), so read the PRIOR dispatch's .return-meta.json instead. The staleness gate is
# intentionally disabled (window 0) — Stage 4 runs BEFORE this cycle's dispatch, so there is
# no current-cycle window yet, and the leftover prior-cycle state is exactly what we want
# regardless of age. This is deliberately NOT named dispatch_start_ts, which means "the
# current dispatch's window start" everywhere else in this file.
prior_meta_probe_window=0
resume_probe=$(bash .claude/scripts/orchestrate-recover-outcome.sh "$TASK_DIR" "$prior_meta_probe_window" || true)
```

`recovered=false` (exit 1) is the EXPECTED and non-fatal outcome here — the prior dispatch's own
status was `partial`/`in_progress` (that is why the task is in this state at all), and
`orchestrate-recover-outcome.sh` only reports `recovered=true` for `researched`/`planned`/
`implemented`. The probe supplies resume *context* (`.status`, `.artifact_path`,
`.phases_completed`, `.phases_total`), never a success claim, and it must NEVER gate the dispatch
— proceed to dispatch regardless of `recovered`.

```bash
skill_preflight_update "$task_number" "implement" "$session_id"
```

```bash
# Dispatch window for infra-failure discrimination — reset both signals every dispatch so a
# stale `true` can never carry over from a previous cycle.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

Read plan path:
```bash
plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
```

Build this dispatch's context file via `scripts/orchestrate-build-dispatch.sh` (Stage 3.5 Dispatch Prep's sole implementation):

```bash
build_args=(--session "$session_id" --seq "$dispatch_seq" --dispatch-start-ts "$dispatch_start_ts")
[ "${clean_flag:-false}" = "true" ] && build_args+=(--clean)
[ "${lit_flag:-false}" = "true" ] && build_args+=(--lit)
[ "${hard_mode:-false}" = "true" ] && build_args+=(--hard)
[ "${effort_flag:-}" = "fast" ] && build_args+=(--fast)
[ -n "${model_flag:-}" ] && build_args+=(--model "$model_flag")
[ -n "${focus_prompt:-}" ] && build_args+=(--focus "$focus_prompt")
dispatch_json=$(bash .claude/scripts/orchestrate-build-dispatch.sh "$task_number" implement "${build_args[@]}")
dispatch_file=$(echo "$dispatch_json" | jq -r '.dispatch_file')
dispatch_model=$(echo "$dispatch_json" | jq -r '.model')
```

Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `model` | `$dispatch_model` — pass as the Agent tool's `model` parameter when non-empty; omit the parameter entirely when empty |
| `prompt` | "You are dispatched by /orchestrate for task $task_number, phase implement. Read $dispatch_file first and execute it exactly; it names every input, output path and contract." |
| `context` | `{ task_number, task_type, session_id, orchestrator_mode: true, plan_path, roadmap_path: "specs/ROADMAP.md", lit_flag, task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq, resume_context: { status: (resume_probe.status), artifact_path: (resume_probe.artifact_path), phases_completed: (resume_probe.phases_completed), phases_total: (resume_probe.phases_total) } }` (same as the continuation branch's `context` object, minus `continuation_context`, plus `resume_context`) |

**After the Agent tool returns**, before Stage 5: judge the tool call's OWN outcome per
`context/patterns/infra-failure-discrimination.md` and set `dispatch_was_transport_error=true`
ONLY if the call itself returned a transport/API-layer error with no subagent-authored text of
any kind. Any subagent-authored output — including text in which the subagent describes an
error it hit — means `false`. Then read handoff (Stage 5), which decides whether this cycle is
charged.

No missing-plan-file guard is added here (deliberate — see Non-Goals in this task's plan): a
`partial` task with no plan file dispatches implement and likely makes no progress, exactly as
the `mt` engine already does today; `MAX_CYCLES` bounds it.

#### State: `blocked`

**Discriminating read (added by this narrowing)**: before falling through to blocker escalation,
determine whether this block has already DISCHARGED — its `dependencies[]` all reached
`status: "completed"` and its handoff carries no blockers — by invoking the executable classifier
directly, the same script Stage MT-4 already calls for the `mt` engine:

```bash
single_verdict=$(bash .claude/scripts/orchestrate-triage-classify.sh single "$task_number")
verdict_group=$(echo "$single_verdict" | jq -r '.group')
```

If `$verdict_group` is `research`, `plan`, or `implement`: the block is DISCHARGED. Dispatch
identically to the corresponding `#### State:` handler above (`not_started`/`researching` for
`research`, `researched`/`planning` for `plan`, `planned`/`implementing` for `implement`) — same
`skill_preflight_update("$task_number", <target-phase>, "$session_id")` call, same dispatch-window
reset, same Agent tool invocation shape as that handler, keyed off `$task_number`/`$session_id`
exactly as already bound in this cycle; no special-casing beyond selecting the target phase named
by `$verdict_group`.

If `$verdict_group` is anything else (`needs_human`) — a dependency still outstanding, empty
`dependencies[]`, a dependency stuck at a non-completed terminal status (`abandoned`/`expanded`),
handoff blockers present, or a discharged block with no recorded `previous_status` — fall through
to the read-blockers-and-escalate flow below, UNCHANGED:

```bash
blocker_desc=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .blockers // "Unspecified blocker"' \
  specs/state.json)
```

Invoke blocker escalation (Stage 6) with blocker_desc.

**Why this handler stays engine-unconditional for the NON-discharged case (Decision 1, narrowed
by this task, intentional divergence from `mt`)**: for a block that has NOT resolved, this
handler always escalates to a human, regardless of engine — a solo invocation has no sibling task
to make progress on, so escalation is the only meaningful action, whereas a batch invocation
(Stage MT-4) skips the still-blocked task so its siblings can proceed. This narrower row is where
the two engines still diverge; it is documented, not an oversight. For the DISCHARGED case, both
engines now converge on the SAME `previous_status`-routed dispatch — see
`scripts/orchestrate-triage-classify.sh`'s header table and justification paragraph for the full
six-branch discriminator.

#### State: `completed`

```
echo "[orchestrate] Task $task_number completed successfully."
# Clean up loop guard. This fires only at full-loop termination, never between cycles — so a
# per-cycle commit (e.g. CHECKPOINT 3) runs before this cleanup on every cycle but the last, and
# must exclude the guard itself rather than rely on this rm to keep it out of history. See
# context/standards/orchestrator-runtime-files.md.
rm -f "$loop_guard_file"
rm -rf "${TASK_DIR}/.dispatch/"  # loop-termination-only cleanup — see orchestrator-runtime-files.md.
EXIT (success)
```

#### States: `abandoned`, `expanded`

```
echo "[orchestrate] Task $task_number is in terminal state [$current_status]. No action taken."
EXIT (no-op)
```

#### Unknown state

```
echo "[orchestrate] WARNING: Unrecognized state '$current_status' for task $task_number."
EXIT (partial)
```

---

### Stage 5: Postflight (after each dispatch)

After every Agent tool invocation, run this dispatch's postflight through
`orchestrate-cycle-postflight.sh` — the single shared implementation for both engines (Stage A.4
of `specs/PATH.md`). It performs the ENTIRE post-dispatch pipeline this stage used to inline: the
stray-handoff sweep, the mtime staleness gate, the `dispatch_seq` identity gate, return-meta
recovery (`dispatch_seq`-aware), phase-count corroboration, writer-contract-aware defect
recording, `user_decision` relay, status transition with the completion-claim gate, artifact link
+ round advance, the `modified_files`-vs-`file_scope` excursion advisory, and the per-task scoped
commit. Never read the full research report, plan, or implementation summary — only named-field
`jq` reads against the handoff, exactly as the script itself is bound by. See
`docs/architecture/orchestrate-cycle-postflight.md` for the full contract this call exercises;
this stage keeps ONLY what the script does not and must not own — the loop-control decision
(`EXIT (partial)` / `cycle_count`) — per that script's own header MUST NOT list.

`dispatched_agent` resolves the agent actually dispatched THIS cycle from `cycle_phase` (set by
Stage 3's 3c, still in scope): `research` → `$RESEARCH_AGENT`, `plan` → `$PLANNER_AGENT`,
`implement` → `$IMPLEMENT_AGENT`.

```bash
case "$cycle_phase" in
  research) dispatched_agent="$RESEARCH_AGENT" ;;
  plan)     dispatched_agent="$PLANNER_AGENT" ;;
  implement) dispatched_agent="$IMPLEMENT_AGENT" ;;
  *) dispatched_agent="$IMPLEMENT_AGENT" ;;  # Stage 6 Step 5's blocker-escalation re-dispatch
esac

postflight_json=$(bash .claude/scripts/orchestrate-cycle-postflight.sh "$task_number" \
  --session "$session_id" --state-file specs/state.json --phase "$cycle_phase" \
  --task-dir "$TASK_DIR" --task-type "$TASK_TYPE" --agent "$dispatched_agent" \
  --plan-path "${plan_path:-}" --cycle-count "${cycle_count:-0}" \
  --transport-error "${dispatch_was_transport_error:-false}" \
  --force-invoked "${force_invoked:-false}" \
  --loop-guard-file "$loop_guard_file" \
  --dispatch-seq "${dispatch_seq:-}" --dispatch-start-ts "${dispatch_start_ts:-9999999999}")

dispatch_status=$(echo "$postflight_json" | jq -r '.status')
phases_completed=$(echo "$postflight_json" | jq -r '.phases_completed')
phases_total=$(echo "$postflight_json" | jq -r '.phases_total')
verdict=$(echo "$postflight_json" | jq -r '.verdict')
halt=$(echo "$postflight_json" | jq -r '.halt')
infra_exempt_cycle=$(echo "$postflight_json" | jq -r '.infra_exempt_cycle')
echo "[orchestrate] Dispatch result: $dispatch_status (verdict=$verdict)" >&2
[ "$phases_total" -gt 0 ] 2>/dev/null && echo "[orchestrate] Phase progress: $phases_completed/$phases_total" >&2

# `infra_failures` is mutated INSIDE the script (persisted straight to `$loop_guard_file`), not
# returned in `postflight_json` — re-read it here so Stage 7's own jq write below stays in sync
# with whatever this cycle actually did (increment-and-persist on a corroborated infra failure,
# unchanged otherwise). Mirrors the script's own re-read-after-write discipline internally.
infra_failures=$(jq -r '.infra_failures // 0' "$loop_guard_file" 2>/dev/null) || infra_failures="${infra_failures:-0}"

# ── Caller-side re-derivation of `handoff` / `blockers` (Stage 5b's own preconditions) ─────────
# orchestrate-cycle-postflight.sh's compact JSON output does not carry the handoff's raw prose or
# its `blockers[]` array (Context Flatness Constraint — the script itself never reads handoff
# prose beyond named-field jq extraction, and its contract is a compact status summary, not a
# pass-through). Stage 5b (H6 churn / H5 three-strikes, hard mode only, below) needs both. This
# reproduces, read-only, the SAME two gates the script already applied and already recorded
# defects for — it decides nothing new and records nothing; a handoff that the script rejected as
# stale/mismatched still resolves to an empty `$handoff` here, exactly as it resolved to a
# non-accepted outcome there.
handoff=""
blockers="[]"
if [ -f "$handoff_file" ]; then
  handoff_mtime_check=$(stat -c %Y "$handoff_file" 2>/dev/null || stat -f %m "$handoff_file" 2>/dev/null || echo 0)
  if [ "$handoff_mtime_check" -ge "${dispatch_start_ts:-9999999999}" ]; then
    handoff_seq_check=$(jq -r '.dispatch_seq // empty' "$handoff_file" 2>/dev/null)
    if [ -z "$handoff_seq_check" ] || [ "$handoff_seq_check" = "${dispatch_seq:-}" ]; then
      handoff=$(cat "$handoff_file")
      blockers=$(echo "$handoff" | jq -c '.blockers // []' 2>/dev/null) || blockers="[]"
    fi
  fi
fi

# ── user_decision relay (surfaced to the human, never invented or requested here) ──────────────
# See context/standards/user-decision-contract.md for the full contract. The script never asks
# and never writes .decisions.json (its own MUST NOT); this is the ONE place in either engine
# that surfaces a pending question to the user, batched at the end of the current cycle, never
# mid-dispatch and never by re-deriving or rephrasing the agent's own question/options/recommended
# text.
if [ "$verdict" = "ask_user" ]; then
  ud_question=$(echo "$postflight_json" | jq -r '.user_decision.question // "(no question text)"')
  ud_options=$(echo "$postflight_json" | jq -r '.user_decision.options // [] | join(" | ")')
  ud_recommended=$(echo "$postflight_json" | jq -r '.user_decision.recommended // ""')
  ud_blocking=$(echo "$postflight_json" | jq -r '.user_decision.blocking // false')
  echo "[orchestrate] USER DECISION for task $task_number: $ud_question" >&2
  echo "[orchestrate] Options: $ud_options" >&2
  echo "[orchestrate] Agent's own recommendation: $ud_recommended (blocking=$ud_blocking)" >&2
  if [ "$ud_blocking" = "true" ]; then
    echo "[orchestrate] Halting: this decision blocks further progress until you decide. The dispatched agent's own artifact already records the full context. Re-run /orchestrate $task_number once decided." >&2
    EXIT (partial)
  else
    echo "[orchestrate] Non-blocking: the dispatched agent already proceeded on its own recommendation above. Surfacing for your review; the loop continues." >&2
  fi
fi

# ── Defect 6: marker/handoff crosscheck (base-engine equivalent of the hard engine's heading-scan
# cross-check) ───────────────────────────────────────────────────────────────────────────────
# Base mode has no discrete per-phase next_phase selection to gate (it always re-dispatches the
# whole plan), so this cross-check is diagnostic-and-downgrading rather than dispatch-refusing: it
# compares the plan's own [COMPLETED]/[COMPLETED WITH EXCLUSIONS] marker count against this
# cycle's own phases_completed and, on a mismatch where the plan claims MORE than confirmed,
# downgrades the specific disputed phase heading to [PARTIAL]. Reachable only when `$handoff` was
# accepted above (the recovered path never claims a marker count the plan didn't already confirm
# via WORK (c)'s own corroboration inside the script). See
# context/contracts/wrap-up.md's "Ordering: Handoff Write Precedes Marker Promotion" for why this
# state is reachable at all.
if [ -n "$handoff" ]; then
  crosscheck_plan_path="${plan_path:-}"
  if [ -z "$crosscheck_plan_path" ]; then
    crosscheck_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1)
  fi
  if [ -n "$crosscheck_plan_path" ] && [ -f "$crosscheck_plan_path" ]; then
    . .claude/scripts/lib/phase-heading-patterns.sh
    if has_nonconforming_phase_headings "$crosscheck_plan_path"; then
      warn_nonconforming "$crosscheck_plan_path" "orchestrate-marker-handoff-crosscheck" || true
    else
      marker_completed_count=$(grep -cE "$PHASE_HEADING_DONE_ERE" "$crosscheck_plan_path" 2>/dev/null) || marker_completed_count=0
      if [ "$marker_completed_count" != "$phases_completed" ]; then
        echo "[orchestrate] MARKER/HANDOFF MISMATCH — plan file shows ${marker_completed_count} phase(s) marked [COMPLETED]/[COMPLETED WITH EXCLUSIONS], but this cycle's own phases_completed=${phases_completed}." >&2
        if [ "$marker_completed_count" -gt "$phases_completed" ]; then
          disputed_line=$(grep -nE "$PHASE_HEADING_DONE_ERE" "$crosscheck_plan_path" | sed -n "$((phases_completed + 1))p")
          if [ -n "$disputed_line" ]; then
            disputed_linenum="${disputed_line%%:*}"
            disputed_text="${disputed_line#*:}"
            echo "[orchestrate] Downgrading disputed phase heading to [PARTIAL]: ${disputed_text}" >&2
            sed -i -E "${disputed_linenum}s/\[(COMPLETED|COMPLETED WITH EXCLUSIONS)\]/[PARTIAL]/" "$crosscheck_plan_path"
          fi
        fi
      fi
    fi
  fi
fi

# Drift detection: arithmetic gate (cheap check before expensive inspection fork). Base-mode
# only (D6/Phase 6 decision record) — Stage 5b's H5 divergence audit plays this role in hard
# mode instead; see the mutual-exclusion note at Stage 5a/5b below.
if [ "${hard_mode:-false}" != "true" ] && [ "$phases_total" -gt 0 ] && [ "$dispatch_status" = "partial" ]; then
  # Use awk for floating-point comparison (bash only does integer math)
  completion_ratio=$(awk "BEGIN { printf \"%.4f\", $phases_completed / $phases_total }")
  is_below_threshold=$(awk "BEGIN { print ($completion_ratio < $DRIFT_COMPLETION_THRESHOLD) ? \"yes\" : \"no\" }")
  if [ "$is_below_threshold" = "yes" ]; then
    echo "[orchestrate] Low phase completion ($phases_completed/$phases_total). Inspecting plan for drift..."
    invoke_drift_inspection "$task_number" "$plan_path" "$session_id"
  fi
fi

# ── Halt decision ────────────────────────────────────────────────────────────────────────────
# `halt=true` only when dispatch_status was off-schema (see the script's own header) — the ONE
# case that still means "stop the whole /orchestrate invocation", mirroring the historical
# off-schema EXIT (partial) this stage used to apply inline. The script's own artifact linking
# already ran (inside its WORK (g)) before this JSON was ever returned, so any artifact this
# dispatch produced is already linked — preserving the evidence, exactly as before.
if [ "$halt" = "true" ]; then
  echo "[orchestrate] Halting: task $task_number left at its current status. Any artifact produced by this dispatch was still linked, preserving the evidence." >&2
  EXIT (partial)
fi

# Increment cycle_count — skipped ONLY for a corroborated infra failure, which is separately
# bounded by MAX_INFRA_FAILURES (Stage 7). Every iteration charges exactly one of the two
# counters; both are capped, so worst-case iterations per invocation are
# MAX_CYCLES + MAX_INFRA_FAILURES.
if [ "$infra_exempt_cycle" = "true" ]; then
  echo "[orchestrate] Cycle not charged (infra failure). cycle_count remains $cycle_count/$MAX_CYCLES." >&2
else
  cycle_count=$((cycle_count + 1))
fi
```

---

### Stage 5a: Drift Inspection

**Base mode only.** Called from Stage 5 when phase completion is below DRIFT_COMPLETION_THRESHOLD and dispatch_status is "partial".
Capped at MAX_DRIFT_INSPECTIONS=1 per /orchestrate invocation.

**Mutual exclusion with Stage 5b (decision record)**: Stage 5a and Stage 5b (below) are mutually
exclusive by construction — exactly one is reachable for any given `hard_mode` value. Hard mode's
H5 divergence-audit dispatch in Stage 5b plays the drift-inspection role that Stage 5a plays in
base mode; they are two different mechanisms answering the same underlying question ("is this
task's plan/execution drifting, and does it need outside intervention?"), not duplicates of each
other. This makes the existing Stage 2 comment (asserting hard mode "has no Stage 5a Drift
Inspection equivalent — its own H5 divergence-audit mechanism plays that role instead")
executable rather than merely asserted.

1. If `drift_inspection_count >= MAX_DRIFT_INSPECTIONS`: log warning and return (skip inspection).

2. Increment `drift_inspection_count`. Log: "[orchestrate] Drift inspection attempt N/MAX".

3. Invoke the Agent tool (fork — to inspect the plan file):

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Read the plan file at '$plan_path'. Count: (1) total checklist items matching '- [ ]' or '- [x]', (2) completed items matching '- [x]', (3) deviation annotations matching '*(deviation:'. Calculate drift_pct as: deviation_count / max(total_items, 1). Write compact JSON to '${TASK_DIR}/.drift-inspection.json' with fields: drift_pct (float), deviation_count (int), total_items (int), completed_items (int), summary (string, one sentence). Return a brief summary of findings." |
| `context` | `{ task_number, session_id, plan_path, orchestrator_mode: false }` |

4. After Agent tool returns: read `${TASK_DIR}/.drift-inspection.json`.
   - If file exists: extract `drift_pct` and `drift_summary`.
   - If file missing: log warning, set `drift_pct=0`, `drift_summary="Inspection output missing"`.

5. If `drift_pct > DRIFT_REVISION_THRESHOLD`: trigger plan revision:

   Invoke the Agent tool (reviser):

   | Field | Value |
   |-------|-------|
   | `subagent_type` | `"reviser-agent"` |
   | `prompt` | "Revise the implementation plan for task $task_number to address plan drift (drift_pct=$drift_pct). Summary: $drift_summary" |
   | `context` | `{ task_number, session_id, plan_path, revision_reason: "drift", drift_pct, orchestrator_mode: false }` |

   After Agent tool returns: read handoff to confirm revision.

6. If `drift_pct <= DRIFT_REVISION_THRESHOLD`: log "Drift check passed. Continuing."

---

### Stage 5b: Churn Detection (H6) and Three-Strikes Audit Dispatch (H5) — hard mode only

**Placed AFTER Stage 5a Drift Inspection and before Stage 6.** Placement is load-bearing twice
over: it must run after Stage 5's own `phases_completed` assignment (D7 — this stage supplies
`phases_completed_after` from that already-assigned value) and it must stay strictly outside the
Stage 5 region `test-handoff-reader-parity.sh` extracts. Gated on `hard_mode`; entirely skipped
in base mode, where Stage 5a (above) plays the equivalent role — see that stage's mutual-exclusion
decision record.

```bash
if [ "${hard_mode:-false}" = "true" ]; then
  # D7: phases_completed_before/phases_completed_after were referenced by the source engine's
  # churn signature but set by NO stage in either engine before this migration (verified by
  # grep — exactly one occurrence across the pair, the consumer itself). phases_completed_before
  # was captured in Stage 4's H1 branch, immediately after that branch's own handoff read;
  # phases_completed_after is Stage 5's own already-assigned $phases_completed, taken here.
  # Guard against a cycle where the H1 branch did not run at all (phases_completed_before never
  # set this cycle) by skipping the churn check entirely rather than computing a false delta —
  # an unset-vs-zero distinction matters here, so this is a presence check, not a `// 0` read.
  if [ -n "${phases_completed_before+x}" ] && [ "${have_outcome:-false}" = "true" ] && [ -n "${handoff:-}" ]; then
    phases_completed_after="$phases_completed"
    phases_delta=$((phases_completed_after - phases_completed_before))

    # Churn signature: no progress this cycle despite a partial dispatch with blockers.
    has_blockers=$(echo "${blockers:-[]}" | jq 'length > 0' 2>/dev/null) || has_blockers=false
    if [ "$dispatch_status" = "partial" ] && [ "$has_blockers" = "true" ] && [ "$phases_delta" -eq 0 ]; then
      blocker_target=$(echo "$handoff" | jq -r '.blockers[0].target // "unknown"')
      current_target_churn=$(jq -r --arg target "$blocker_target" \
        '.target_churn[$target] // 0' "$churn_file")
      new_target_churn=$((current_target_churn + 1))

      # Update churn counters (atomic tmp-mv jq write, matching this file's other loop-guard/
      # churn-file writes).
      jq --arg target "$blocker_target" \
         --argjson count "$new_target_churn" \
         --argjson total "$((total_churn + 1))" \
         --arg sid "$session_id" \
        '.target_churn[$target] = $count | .total_churn = $total | .last_session_id = $sid' \
        "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

      echo "[orchestrate] H6: Churn detected on '$blocker_target' (count: $new_target_churn)" >&2

      # Three-strikes: dispatch a divergence audit instead of another implement.
      if [ "$new_target_churn" -ge 3 ]; then
        echo "[orchestrate] H5: Three-strikes — dispatching divergence audit for '$blocker_target'" >&2
        verbatim_goal=$(echo "$handoff" | jq -r '.blockers[0].verbatim_goal // ""')

        # $RESEARCH_AGENT never writes .orchestrator-handoff.json, per the Stage 3.6 "Scoping
        # Decision" in general-research-agent.md (core's own hard-mode research agent
        # counterpart is deleted; the cslib and lean hard-mode research agents mirror the same
        # scoping decision) and the Handoff Writers table in
        # docs/architecture/handoff-schema.md — so no absolute anchor
        # (handoff_path) is passed here, and orchestrator_mode is explicitly false.
        Agent tool:
          subagent_type: $RESEARCH_AGENT
          prompt: "DIVERGENCE AUDIT for task $task_number. Target: '$blocker_target'. Verbatim goal: '$verbatim_goal'. This target has failed 3 times. Identify root cause of repeated failure. Write a divergence table, postmortem, and corrected target definition."
          delegation_context: {task_number, session_id, effort_flag: "hard", focus_prompt: "divergence audit $blocker_target", orchestrator_mode: false}

        # Reset the churn counter for this target after the audit dispatch.
        jq --arg target "$blocker_target" --arg sid "$session_id" \
          '.target_churn[$target] = 0 | .audit_dispatches += 1 | .last_session_id = $sid' \
          "$churn_file" > "${churn_file}.tmp" && mv "${churn_file}.tmp" "$churn_file"

        # cycle_count is NOT incremented again here: Stage 5b runs strictly after Stage 5's own
        # tail, which already charged this cycle exactly once (D7's ordering fix — the source
        # engine's Stage 4b/Stage 5 ordering left this ambiguous; positioning Stage 5b after
        # Stage 5 resolves it to "exactly one increment per cycle", never two). Loop continues —
        # the next iteration re-dispatches implement with the audit's findings available to it
        # via the plan/handoff the audit informs.
      fi
    fi
  fi
fi
```

---

### Stage 6: Blocker Escalation (5-Step Sequence)

Called when: `partial` state with non-empty blockers, or `blocked` state that has NOT discharged
(a discharged `blocked` task dispatches directly to the phase its `previous_status` names instead
of reaching this stage — see the `#### State: blocked` handler's discriminating read).
Capped at MAX_BLOCKER_ESCALATIONS=2 per /orchestrate invocation.

**If `blocker_escalation_count >= MAX_BLOCKER_ESCALATIONS`**: log error and return. Manual intervention required. Suggest: (1) `/research $task_number`, (2) `/revise $task_number`, (3) `/implement $task_number`.

Increment `blocker_escalation_count`. Log escalation attempt and blocker description.

**Step 1: DETECT** — blocker_desc is passed in by caller (from handoff or state.json).

**Step 2: RESEARCH FORK** — Invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"fork"` |
| `prompt` | "Research this specific blocker for task $task_number: $blocker_desc. Find the root cause and a concrete solution path." |
| `context` | `{ task_number, session_id, blocker: blocker_desc, orchestrator_mode: false }` |

After Agent tool returns: read the fork's own returned text for research findings.

**Step 3: READ FINDINGS** — The fork above is dispatched with `orchestrator_mode: false`, and by
the decided one-channel-per-mode contract (see `docs/architecture/handoff-schema.md`'s "Handoff
Writers" section) a dispatch with `orchestrator_mode: false` writes NO `.orchestrator-handoff.json`
at all — only the hard-mode implementation agent ever writes that file. The fork's returned text
IS the real findings channel here, not `$handoff_file`. The read below is defensive only (in case
a stale handoff from an unrelated prior hard-mode dispatch happens to sit at that path) and is
expected to fall through to the empty defaults on the common path:
```bash
findings_summary=$(jq -r '.summary // "No findings"' "$handoff_file" 2>/dev/null || echo "No findings")
findings_artifact=$(jq -r '.artifacts[0].path // ""' "$handoff_file" 2>/dev/null || echo "")
```

**Step 4: REVISE PLAN** — Read latest plan path, then invoke the Agent tool:

| Field | Value |
|-------|-------|
| `subagent_type` | `"reviser-agent"` |
| `prompt` | "Revise the implementation plan for task $task_number to address this blocker: $blocker_desc. Research findings: $findings_summary" |
| `context` | `{ task_number, session_id, research_findings: findings_summary, plan_path, orchestrator_mode: false }` |

After Agent tool returns: read handoff to confirm revision.

**Step 5: RE-DISPATCH IMPLEMENT** — Read revised plan path, then invoke the Agent tool:

```bash
# Dispatch window for infra-failure discrimination and the Stage 5 staleness/dispatch_seq gate
# — see context/patterns/infra-failure-discrimination.md. This dispatch writes
# .orchestrator-handoff.json (orchestrator_mode: true) and therefore needs its own dispatch
# window and dispatch_seq minted here, the same as every other handoff-writing dispatch site.
dispatch_start_ts=$(date -u +%s)
dispatch_was_transport_error=false
dispatch_seq=$(mint_dispatch_seq)
```

| Field | Value |
|-------|-------|
| `subagent_type` | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) |
| `prompt` | "Implement task $task_number following the revised plan" (append ". User focus: $focus_prompt" if non-empty) |
| `context` | `{ task_number, session_id, orchestrator_mode: true, plan_path: revised_plan_path, roadmap_path: "specs/ROADMAP.md", task_dir: TASK_DIR_ABS, handoff_path: HANDOFF_PATH_ABS, dispatch_seq }` |

After Agent tool returns: read handoff.

---

### Stage 7: Loop Guard Update (end of each cycle)

After each cycle (whether dispatch succeeded or failed):

```bash
jq --arg state "$current_status" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson count "$cycle_count" \
   --argjson infra "${infra_failures:-0}" \
  '.current_state = $state | .last_updated = $updated | .cycle_count = $count | .infra_failures = $infra' \
  "$loop_guard_file" > "${loop_guard_file}.tmp" && mv "${loop_guard_file}.tmp" "$loop_guard_file"
```

**Forced-sequence-exhausted (A2 — checked first, ahead of the MAX_INFRA_FAILURES/MAX_CYCLES
checks below).** If this cycle's 3c popped `force_queue` (`force_invoked` is `true`) AND
`force_queue` is now empty, the composed `--research`/`--plan`/`--implement` sequence is
exhausted. STOP here — do not fall through to status-derived dispatch on a subsequent cycle:

```
if [ "${force_invoked:-false}" = "true" ] && [ "${#force_queue[@]}" -eq 0 ]; then
  echo "[orchestrate] Forced-phase sequence complete for task $task_number (last forced phase: $forced_phase). Stopping — the composed --research/--plan/--implement sequence does not fall through to status-derived dispatch."
  EXIT (success)
fi
```

If MAX_INFRA_FAILURES reached (infra_failures >= MAX_INFRA_FAILURES):

```
echo "[orchestrate] MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached for task $task_number — repeated Agent tool transport/API failures with no subagent execution."
echo "This is a connectivity problem, not a work-budget problem: cycle_count is still $cycle_count/$MAX_CYCLES."
echo "Run /orchestrate $task_number again once connectivity is confirmed."
EXIT (partial)
```

This is the explicit bound on the exemption path. Because an infra-exempt cycle does not
increment `cycle_count`, the `while` condition alone would not advance; this check — which runs
at the end of every cycle — is what terminates the run. Worst-case iterations per invocation
are therefore `MAX_CYCLES + MAX_INFRA_FAILURES` = 8. Do NOT also increment `cycle_count` here:
the cap's purpose is to stay outside the work-cycle budget.

If MAX_CYCLES reached (cycle_count >= MAX_CYCLES). Note: with the Stage 2
budget-continuation-override in place, this branch is now normally unreachable in practice for an
already-exhausted guard — Stage 2 either exits early (flag absent) or resets cycle_count to 0
(flag present) before the main loop ever opens. It remains correct as a defense-in-depth backstop
for the rare case where MAX_CYCLES is reached DURING this same invocation's own loop:

```
echo "[orchestrate] MAX_CYCLES ($MAX_CYCLES) reached for task $task_number."
echo "Current state: $current_status. Run /orchestrate $task_number --continue-budget to authorize a fresh budget and continue."
EXIT (partial)
```

---

### Stage 8: Postflight

On clean exit (task completed or terminal state):

**Both files removed here — `.orchestrator-loop-guard` and `.drift-inspection.json` — are
ephemeral and gitignored, and this is their only cleanup site.** Cleanup fires only at full-loop
termination, never per-cycle, so any commit taken mid-loop (e.g. CHECKPOINT 3, which runs every
cycle) must independently exclude both rather than rely on this `rm` alone. See
`context/standards/orchestrator-runtime-files.md`.

```bash
# Read the run's system-defect observation log BEFORE cleanup below removes the loop guard —
# ordering is load-bearing here (the metadata merge further down consumes this value).
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
# Remove loop guard on success
rm -f "$loop_guard_file"
# Clean up drift inspection artifact if present
rm -f "${TASK_DIR}/.drift-inspection.json"
# Clean up accumulated per-dispatch context files — loop-termination-only, see
# orchestrator-runtime-files.md (the one per-task ephemeral entry that accumulates rather than
# being a singleton, so it is swept in bulk here rather than rm -f'd per dispatch).
rm -rf "${TASK_DIR}/.dispatch/"
echo "[orchestrate] Task $task_number: orchestration complete."
echo "Final status: $current_status | Cycles used: $cycle_count/$MAX_CYCLES"
```

On partial exit (MAX_CYCLES, in-flight warning, escalation cap):

```bash
# Preserve loop guard for next /orchestrate invocation
echo "[orchestrate] Task $task_number: orchestration paused."
echo "Status: $current_status | Cycles: $cycle_count/$MAX_CYCLES | Run /orchestrate $task_number --continue-budget to continue once the budget is exhausted, or /orchestrate $task_number for an ordinary cross-turn resume."
```

**Explicitly UNCHANGED by Defect B's budget-continuation override**: this cleanup site still only
fires on full-loop termination (the "On clean exit" block above), never on a partial exit --
including the Stage 2 exhaustion branch's flag-absent `exit 1`, which leaves the exhausted guard
fully in place. This is correct, not an oversight: the guard's entire job is to persist across
exactly this gap so an operator's subsequent `--continue-budget` invocation has something to read
`cycle_count` from. All four sites that touch this guard's lifecycle -- Stage 2's exhaustion
branch, this Stage 7 terminal condition, and this Stage 8 cleanup -- now visibly agree.

Write metadata file. `status` here is the `.return-meta.json` skill-status vocabulary defined
normatively in `context/formats/return-metadata-file.md` — it is NOT the state.json task-status
vocabulary (`current_status` above, where `"completed"` is correct); do not "correct" this value
back to `"completed"`.

On clean exit:

```bash
# Single shared implementation, skill_orchestrate_merge_return_meta (scripts/skill-base.sh) — see
# that function's header for the full contract, including WHY it takes a resolved
# detected_defects JSON string rather than the loop-guard path (this clean-exit call reads it
# from the EARLIER fence's `$detected_defects`, captured BEFORE the `rm -f "$loop_guard_file"`
# cleanup above — the loop guard no longer exists by the time this fence runs).
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "implemented" \
  "$cycle_count" "$current_status"
```

On partial exit:

```bash
# Same shared implementation as the clean-exit variant above. The loop guard is PRESERVED on
# partial exit, so this reads it fresh immediately before the call — ordering is not
# load-bearing here, but the read stays structurally identical to the clean-exit variant.
source .claude/scripts/skill-base.sh
meta_file="${TASK_DIR}/.return-meta.json"
detected_defects=$(jq -c '.detected_defects // []' "$loop_guard_file" 2>/dev/null || echo '[]')
skill_orchestrate_merge_return_meta "$meta_file" "$detected_defects" "partial" \
  "$cycle_count" "$current_status"
```

---

## Multi-Task Mode

Entered when `multi_task_mode=true` in the delegation context (detected in Stage 0).
All single-task stages (1-8) are skipped. The skill receives the intra-batch dependency graph
from `orchestrate.md`'s compact STAGE 0 multi-task block and manages all tasks in a single
orchestrator instance.

### Stage MT-1: Parse Multi-Task Context

Read from delegation context:
- `task_numbers` — array of task numbers to manage
- `dependency_graph` — map of task_number -> [predecessor_task_numbers]
- `waves` — **diagnostic echo, recorded not consumed**: a single row containing all validated
  tasks (`[[t1, t2, ...]]`). Nothing reads this field — eligibility is re-derived fresh every
  cycle at Stage MT-3 step 4.5 from current task statuses plus `dependency_graph`, never from a
  pre-computed wave schedule. The key is kept required only because `mt_state_file` below still
  carries it; do not reintroduce wave-based dispatch logic on account of its presence.
- `session_id`, `lit_flag`, `allow_self_modifying` (default: "false") — consumer-side opt-in
  bypass of the self-modification admission gate; never passed to `orchestrate-batch-admit.sh`
  itself (see Stage MT-3 step 4.5's `self_modifying` branch below)
- `allow_scope_collision` (default: "false") — consumer-side opt-in bypass of the CROSS-BATCH
  `file_scope_collision` admission gate only, never `in_batch` (D1); never passed to
  `orchestrate-batch-admit.sh` itself (see Stage MT-3 step 4.5's `file_scope_collision` ->
  `cross_batch` branch below)
- `clean_flag` (default: `"false"`) — threaded from the command's `--clean` flag; suppresses
  Stage 3.5 Dispatch Prep's automatic memory retrieval for every per-task dispatch this batch
  makes.
- `effort_flag` (default: `""`) — threaded from the command's `--fast` flag; supplies reasoning-
  depth guidance to Stage 3.5 Dispatch Prep for every per-task dispatch this batch makes.
- `model_flag` (default: `""`) — threaded from the command's `--haiku`/`--sonnet`/`--opus`/
  `--fable` flags; selects the model family for every per-task dispatch this batch makes.
  Resolved **once here** and passed unchanged into every Stage 3.5 call — never re-resolved per
  task, and no per-task field is added to `mt_state_file`. The not-set sentinel is the **empty
  string**, matching `parse-command-args.sh`'s `MODEL_FLAG=""` default — not the literal token
  `null`.
- `hard_mode` — derived once, here, as `hard_mode="false"; [ "$effort_flag" = "hard" ] &&
  hard_mode="true"`. Consumed by Stage 3.5 Dispatch Prep's hard-mode contract injection below,
  for every per-task dispatch this batch makes, and reserved for later conditional
  state-machine branches (churn/three-strikes counters, the burnout circuit breaker) that read
  this same boolean rather than re-deriving it.
- `force_phases` (default `""`) — read here and threaded, unmodified, into Stage MT-3's own call
  to `scripts/orchestrate-cycle-plan.sh` as `--force-phases`, which owns the actual per-task
  consumption (canonical ordering, per-task stop-after-last-named semantics, and
  `force_phases_remaining` tracking in `mt_state_file`) — closing the former multi-task
  phase-forcing gap this bullet used to describe as diagnostics-only. No notice is emitted here
  any more; `orchestrate-cycle-plan.sh`'s own dispatch rows are the record of what was forced.

**Upstream review cross-reference**: raw dependency review already happened upstream, inside
`commands/orchestrate.md`'s compact STAGE 0 multi-task block (Pre-Dispatch Review call, retained
as a one-line advisory invocation), before `dependency_graph` above was even built — that call
runs `scripts/orchestrate-predispatch-review.sh` against the FULL raw `dependencies[]` on every
candidate, warning loudly on every out-of-batch or nonexistent edge STAGE 0's own dependency-graph
build is about to narrow away. The `dependency_graph` this stage receives has therefore
already been reviewed within that review stage's own stated limits: it is advisory-loud, never
blocking, and it does not itself exclude an out-of-batch predecessor from this stage's
eligibility check below (Stage MT-3 step 3) — see
`context/patterns/batch-orchestration-guardrails.md`'s Non-Negotiable 3 and Open Design Fork for
the current status of that residual gap. No code change was needed here: this stage receives an
already-built `dependency_graph` from STAGE 0's own output rather than rebuilding any part of it
itself.

Compute: `task_count = length(task_numbers)`, `MAX_CYCLES_MT = min(task_count * 5, 25)`,
`MAX_INFRA_FAILURES = 3` (flat **per task**, not scaled by `task_count` — matching single-task
mode; see `context/patterns/infra-failure-discrimination.md`).

Initialize `mt_state_file = "specs/.orchestrator-multi-state-${session_id}.json"` with fields: `session_id`,
`task_numbers`, `waves`, `max_cycles`, `cycle_count: 0`, `failed_tasks: []`,
`completed_tasks: []`, `current_statuses: {}`, `task_dirs: {}`, `research_agents: {}`,
`implement_agents: {}`, `descriptions: {}` (map task_num -> task description, written once per
task by Stage MT-2 below; read by Stage MT-4's three dispatch loops for both the existing
`$description` prompt interpolation and the new Stage 3.5 Dispatch Prep's hard-required
`description` precondition), `infra_failures: {}` (map task_num -> count, default 0),
`dispatch_start_ts: {}` (map task_num -> unix seconds, written at dispatch time),
`dispatch_seq_counter: 0` (batch-scoped monotonic counter, Defect A — never repeats a value
across the whole batch, mirroring the single-task engine's loop-guard `dispatch_seq_counter`),
`dispatch_seq: {}` (map task_num -> the `dispatch_seq` minted for that task's most recent
dispatch, written at dispatch time alongside `dispatch_start_ts[$t]`), and
`deferred_self_modifying: []` — an APPEND-ONLY OBSERVATION LOG (persists across every cycle of
this same `mt_state_file`, never reset mid-invocation) of task numbers the self-modification gate
has deferred AT LEAST ONCE this invocation. As of the narrowed same-cycle scope, this is NO LONGER
an eligibility-exclusion set — a task appearing in this log is not thereby excluded from a later
cycle's `eligible_tasks`. The convergence mechanism is now the SAME one `file_scope_collision`
already uses: the defer is re-evaluated fresh every cycle from `${#eligible_tasks[@]}` and the
candidate's own `file_scope`, and it clears on its own once the co-dispatched sibling that caused
it leaves `eligible_tasks` by terminating or failing (a task no longer leaves `eligible_tasks`
merely by transitioning to an in-flight status (`researching`/`planning`), now that eligibility
is no longer status-gated — see Stage MT-3 step 3) — no persistent exclusion is needed for that
to happen, and the loop's existing
per-cycle re-evaluation already guarantees it. **Second, independent, per-cycle exit condition
(the one that actually bounds the self-modifying-specific case, and depends on no status
transition at all)**: the designated-candidate tie-breaker inside `orchestrate-batch-admit.sh`
(see that script's header) admits exactly one self-modifying candidate — the lowest task number —
on EVERY cycle, regardless of how many self-modifying candidates are co-dispatched. N
self-modifying candidates therefore converge to full dispatch in at most N cycles by
construction, independent of whether any sibling ever leaves `eligible_tasks` at all. See Stage
MT-3 step 3 (no longer a status-gated exclusion), step 4.5 (append-only population plus the
tie-breaker's `--phase-map`-threaded admission call), and the new consecutive-no-dispatch guard
below for the bounded case where NEITHER exit condition converges in time (e.g. a tie-breaker
defect), and Stage MT-5 (postflight reporting) for where this log is read.

**In-flight session registry** (adjacent to, not part of, `mt_state_file`): register the batch
under the bare `session_id` this stage received, with the full `task_numbers` set as the CSV.
Best-effort and non-blocking — a registration failure must never affect any admission, dispatch,
or eligibility decision:

```bash
bash .claude/scripts/task-lock.sh session-register "$session_id" "/orchestrate (multi-task)" "$(IFS=,; echo "${task_numbers[*]}")" 2>/dev/null || true
```

Single-task `/orchestrate` needs no separate registry wiring: its CHECKPOINT 1/2 already routes
through `command-gate-in.sh`/`command-gate-out.sh`, which register/release the session registry
entry for every single-task dispatch (see that pair's own wiring). This registration is
multi-task-only, mirroring why `mt_state_file` itself is initialized only in this MT branch.

`deferred_deploy_checkpoint`'s semantics are UNCHANGED by this narrowing and remain a genuine,
permanent-for-the-invocation eligibility exclusion — the two fields are not conflated by this
change; see the field definition immediately below.

Alongside it, two more INVOCATION-SCOPED fields with the same never-reset-mid-invocation
semantics, backing the inter-cycle redeploy checkpoint (Stage MT-3 step 7 below; full contract in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Inter-Cycle Redeploy Checkpoint`
subsection):

- `deferred_deploy_checkpoint: []` — task numbers excluded for the remainder of the invocation
  because a checkpoint gate (`deploy-headless.sh` or `verify-deploy.sh`) failed. A DISTINCT set
  from `deferred_self_modifying`: the two causes have different operator remedies, so they are
  never merged.
- `deployed_critical_paths: []` — critical paths already redeployed this invocation; the
  idempotence guard's backing store, so the checkpoint does not re-fire on the same path every
  cycle.
- `consecutive_no_dispatch_cycles: 0` — integer counter backing Stage MT-3 step 4.5's convergence
  guard: increments on any cycle where `eligible_tasks` was non-empty but the self-modification
  gate deferred every member of it (empty actual dispatch batch); resets to 0 on any cycle where
  at least one task dispatches. Bounds the narrow non-convergence mode a removed permanent
  exclusion set no longer prevents by construction.
- `verify_deploy_baseline_notices: []` — an APPEND-ONLY OBSERVATION LOG of every checkpoint firing
  that proceeded past a pre-existing `verify-deploy.sh` failure (the third operator-visible state;
  see the **Failure contract** branch (c) in `context/patterns/batch-orchestration-guardrails.md`'s
  `### The Inter-Cycle Redeploy Checkpoint` subsection), entries of the form
  `{"cycle": <int>, "gate": "verify-deploy.sh", "pre_findings": <int>, "post_findings": <int>, "new_findings": 0, "post_exit": <int>}`.
  It carries the same MUST NOT as `defer_ledger` immediately below: never read by any eligibility
  check, all-terminal check, circuit breaker, convergence guard, or admission branch. It is
  written for reporting only, read and rendered at Stage MT-5, which now owns the consolidated-
  output emission formerly credited to the command's now-deleted MULTI-TASK DISPATCH section. It is
  NOT a defer/exclusion set — the third state excludes nothing — and is never merged into
  `defer_ledger`, whose own contract scopes it to defer/exclusion events.

Two more fields, backing the **forward-progress invariant** (full contract in
`context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
subsection):

- `defer_ledger: []` — an APPEND-ONLY OBSERVATION LOG of every per-cycle defer/exclusion event,
  entries of the form
  `{"task": <int>, "defer_reason": <string>, "collision_scope": <string|null>, "cycle": <int>, "detail": <string>}`.
  **MUST NOT**: the ledger is never read by any eligibility check, all-terminal check, circuit
  breaker, convergence guard, or admission branch. It is written for reporting and read and
  rendered only at Stage MT-5. It is not a fifth admission gate and must
  never become one. `defer_ledger` is ADDITIVE to `deferred_self_modifying` and
  `deferred_deploy_checkpoint`, not a replacement: a self-modifying defer appends to BOTH the
  existing observation log and the ledger, and the two existing fields keep their current
  semantics, consumers, and Stage MT-5 role byte-for-byte.
- `detected_defects: []` — an APPEND-ONLY OBSERVATION LOG of every system-defect detection that
  fired during this run. This declaration is the SINGLE canonical definition of the field's
  contract, read identically by both effort-mode branches in this file — there is no longer a
  second engine file that could drift from it.

  **Entry shape**:
  `{"task": <int>, "defect_class": <string>, "attributed_source_path": <string>, "detecting_site": <string>, "cycle": <int>, "detail": <string>, "record_result": <string|null>}`.
  Unlike `defer_ledger`'s MT-only `task`, `task` here is ALWAYS populated: a task number
  (`$task_number` in single-task stages, `$task_num` in MT stages) is in scope at every detection
  site in both engines.

  **Unconditional-append rule**: the append fires whenever the caller's own detection fires, and
  is NEVER gated on `system-defect-record.sh`'s exit code, nor on a `SUPPRESSED:recursion_guard`
  or `SUPPRESSED:duplicate` value on its stdout. `record_result` records that outcome for the
  operator; it never decides whether the entry exists. Rationale: the recorder's dedup key is
  cross-run, while this log answers "what fired during THIS run" — a detection suppressed as a
  cross-run duplicate still fired here and must still be surfaced. This mirrors `defer_ledger`'s
  existing unconditional-append discipline.

  **Notice format** (modelled on the literature `AUTONOMOUS_GLOBAL` directive's `[lit:auto]`
  notice): immediately after each append, at every site, emit
  `[orchestrate] [system-defect:auto] queued for postflight summary — defect_class=<CLASS> attributed_path=<PATH> detecting_site=<SITE>`
  (`[hard-orchestrate]` prefix in the hard-mode file; MT sites additionally name the task). Its
  purpose is the same "never a silent no-op" principle that directive states: a detection that
  only lands in a file the operator never opens is indistinguishable from no detection at all.

  **Absolute constraint**: no site in this mechanism may call `AskUserQuestion`. When
  `orchestrator_mode` is true there is no human to prompt, so accumulate-then-render is the
  deterministic default — exactly as `AUTONOMOUS_GLOBAL` prescribes for the same situation. This
  mechanism surfaces detections; it creates no task and adds no interactive step.

  **MUST NOT**: the log is never read by any eligibility check, all-terminal check, circuit
  breaker, convergence guard, or admission branch. It is written for reporting and read and
  rendered only at Stage MT-5. It is not an admission gate and must never become
  one. It is likewise never consulted by `exit_status` branch selection: a batch that succeeded
  and also observed a defect is still a successful batch.

  **ADDITIVE, never merged**: `detected_defects` is ADDITIVE to `defer_ledger` and is never
  merged into it — `defer_ledger`'s `defer_reason` vocabulary is load-bearing for admission
  reporting, and a system-defect detection excludes nothing and has no `defer_reason`. It is
  likewise never merged into `verify_deploy_baseline_notices`, which is a different observation
  log for a different concern (pre-existing deploy-verify failures). Three separate logs, three
  separate operator remedies.
- `forward_progress_violated: false` — initialized false, computed and written once at Stage MT-5
  from `dispatch_start_ts`. Never read by any loop condition.
- `idle_overlap_ledger: []` — an APPEND-ONLY OBSERVATION LOG of every admitted verdict this cycle
  carrying a non-empty `idle_overlap_advisory` (NEW in v5 — see Stage MT-3 step 4.5's "Idle
  cross-batch overlap advisory" check above), entries of the form
  `{"task": <int>, "colliding_task_number": <int>, "colliding_task_status": <string>, "overlapping_path": <string>, "cycle": <int>}`.
  Follows `defer_ledger`'s exact shape and MUST NOT: never read by any eligibility check,
  all-terminal check, circuit breaker, convergence guard, or admission branch — the candidates it
  names were ADMITTED, not deferred, so this log excludes nothing. It is written for reporting
  only, read and rendered only at Stage MT-5. It is never merged into
  `defer_ledger` — that log's `defer_reason` vocabulary is load-bearing for admission reporting,
  and an advisory has no `defer_reason` at all.

**Hard-mode finding, historical, now moot**: before the standalone hard-mode engine was merged
into this file and deleted, it had no MT-stage implementation of its own — its own Stage 0 stated
explicitly that when `multi_task_mode` is true it "use[s] base multi-task stages", i.e. these SAME
Stage MT-1 through MT-5 stages. Multi-task `/orchestrate --hard` has therefore always written
`mt_state_file.dispatch_start_ts`, `defer_ledger`, and `forward_progress_violated` via this one
file, both before and after the merge, with no separate hard-mode edit ever needed. (The deleted
file's own `dispatch_start_ts` shell variable occurrences belonged to its single-task, non-MT
infra-failure-discrimination logic — a same-named but unrelated local variable, not this
`mt_state_file` field; this distinction is recorded here only because it is no longer directly
verifiable against the deleted source.) Stage MT-5's three-branch resolution (formerly credited
to the command's now-deleted MULTI-TASK DISPATCH section, before batch-output ownership moved
here) still degrades explicitly (an explicit "not evaluable" notice, never a silent skip) for any
future MT path variant that might lack the field, but no such variant exists today.

### Stage MT-2: Build Per-Task Routing Table

For each task in `task_numbers`, read `state.json` to get `task_type`, `project_name`,
`description`. Compute `task_dir = "specs/${padded}_${project_name}"`. Resolve `research_agent` and `implement_agent` using the same routing table as Stage 1b:

| task_type | research_agent | implement_agent |
|-----------|----------------|-----------------|
| `lean4` / `lean` | `lean-research-agent` | `lean-implementation-agent` |
| `neovim` | `neovim-research-agent` | `neovim-implementation-agent` |
| `nix` | `nix-research-agent` | `nix-implementation-agent` |
| *(default)* | `general-research-agent` | `general-implementation-agent` |

Check `.claude/extensions/${task_type}/manifest.json` for override routing. Populate all per-task maps into `mt_state_file`.

**Per-task description capture (must-fix, do not drop as redundant)**: within the same per-task
loop below, read `description=$(echo "$task_data" | jq -r '.description // ""')` and write it
into `mt_state_file`'s `descriptions` map, keyed by task number. Both `memory-retrieve.sh` (hard
`exit 1` on an empty description argument) and `lit-stage4a-flow.md` (`--query "$description"`)
hard-require this value — without this capture, the new Stage 3.5 Dispatch Prep silently no-ops
(no memory retrieval, no literature briefing) for every multi-task dispatch.

**Entry reconcile (once per task, never per-cycle)**: within this same per-task iteration — not
inside Stage MT-3's cycling loop — run `reconcile-task-status.sh` once for each task. This rides
the iteration Stage MT-2 already performs to build the routing table, satisfying the once-per-task
requirement on a path that has no single per-task entry point of its own. Live, bracketed the same
way as the single-task entry reconcile above (a live no-op prints nothing):

```bash
for task_number in "${task_numbers[@]}"; do
  # ... existing routing-table resolution for this task_number (task_type, project_name,
  # task_dir, research_agent, implement_agent) ...
  task_description=$(echo "$task_data" | jq -r '.description // ""')
  jq --arg t "$task_number" --arg d "$task_description" \
    '.descriptions[$t] = $d' \
    "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
  recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
  if [ -n "$recon_out" ]; then
    echo "$recon_out"
  else
    echo "[orchestrate] Entry reconcile: no stranded status found for task $task_number"
  fi
done
```

### Stage MT-3: Lifecycle-Cycling Loop

**Collapsed (was Stage MT-3 steps 1-4.5, ~35 KB of inline jq/prose)**: status refresh, session
heartbeat, the all-terminal check, eligibility, classification, admission (with the four defer
gates and their consumer-side overrides), the designated-candidate self-modification tie-breaker,
the convergence guard, the idle cross-batch overlap advisory, per-task `force_phases`
consumption, missing-task-directory creation, the read-only lock probe, budget accounting
(`MAX_CYCLES_MT`/`MAX_INFRA_FAILURES`), and the inter-cycle redeploy checkpoint are now ONE call
to `scripts/orchestrate-cycle-plan.sh`, made once per cycle. The full behavioral contract for
every one of those mechanisms is unchanged and is documented, once, in that script's own header
comment and in `docs/architecture/orchestrate-state-machine.md`'s "MT Mode" section (relocated
prose pointer) — neither is restated here.

```bash
force_phases_args=()
[ -n "${force_phases:-}" ] && force_phases_args=(--force-phases "$force_phases")
model_args=()
[ -n "${model_flag:-}" ] && model_args=(--model "$model_flag")
plan_json=$(bash .claude/scripts/orchestrate-cycle-plan.sh \
  --session "$session_id" --state-file specs/state.json \
  "${force_phases_args[@]}" "${model_args[@]}" \
  $( [ "${clean_flag:-false}" = "true" ] && echo --clean ) \
  $( [ "${lit_flag:-false}" = "true" ] && echo --lit ) \
  $( [ "${hard_mode:-false}" = "true" ] && echo --hard ) \
  $( [ "${effort_flag:-}" = "fast" ] && echo --fast ) \
  $( [ "${allow_self_modifying:-false}" = "true" ] && echo --allow-self-modifying ) \
  $( [ "${allow_scope_collision:-false}" = "true" ] && echo --allow-scope-collision ) \
  $( [ "${continue_budget:-false}" = "true" ] && echo --continue-budget ) \
  "${task_numbers[@]}")
stop_json=$(echo "$plan_json" | jq -c '.stop')
```

`continue_budget` (default `false`) — read here from delegation context (multi-task's own
threading of this field was previously unwired; single-task's Stage 2 already reads it) —
authorizes continuing past an exhausted `MAX_CYCLES_MT`/`MAX_INFRA_FAILURES` budget, honored
identically to the single-task engine's own `--continue-budget` contract.

**If `stop_json` is non-null**: log `.reason`/`.message` to the transcript and exit the
lifecycle-cycling loop — `all_terminal` is a success exit; `max_cycles`, `no_eligible_stuck`,
`max_infra_failures`, and `convergence_guard` are partial exits. Proceed to Stage MT-5. **If
`stop_json` is null**: continue to Stage MT-4's dispatch composition below, using this cycle's
`plan_json.dispatch[]` rows.

### Stage MT-4: Phase-Aware Dispatch and Per-Task Postflight

**Dispatch composition (collapsed from three separate per-phase loops to one, ≤10-line loop over
`plan_json.dispatch[]`)**: each row already carries `task`, `phase`, `agent`, `model`, and
`dispatch_file` — `scripts/orchestrate-cycle-plan.sh` already ran Stage 3.5 Dispatch Prep
(`orchestrate-build-dispatch.sh`) for every row, so the dispatch file itself names every input,
output path, and contract this dispatch carries (description, artifact round, research
artifact/plan path/continuation, memory/literature context, hard-mode contracts). The Agent
tool's own `context` argument therefore only needs the bootstrap fields a dispatched agent's
harness reads directly, before or independent of reading that file:

Prompt for every row: `"You are dispatched by /orchestrate for task $t, phase $phase. Read
$dispatch_file first and execute it exactly; it names every input, output path and contract."`
Context for every row: `{ task_number: t, orchestrator_mode: true, session_id: ctx_sid, task_dir:
task_dir_abs, handoff_path: "${task_dir_abs}/.orchestrator-handoff.json", dispatch_seq }`.

```bash
mt_state_file="specs/.orchestrator-multi-state-${session_id}.json"
echo "$plan_json" | jq -c '.dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); phase=$(jq -r .phase <<<"$row"); agent=$(jq -r .agent <<<"$row")
  model=$(jq -r '.model // empty' <<<"$row"); dispatch_file=$(jq -r .dispatch_file <<<"$row")
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")"
  dispatch_seq=$(jq -r --arg t "$t" '.dispatch_seq[$t]' "$mt_state_file")
  ctx_sid="$session_id"; [ "$phase" != "implement" ] && ctx_sid="${session_id}_${t}"
  # Invoke Agent tool: subagent_type = agent (model, if non-empty, as the Agent tool's `model`
  # parameter); prompt and context per the two field mappings named just above.
done
```

**BATCHING RULE** (unchanged): ALL Agent tool calls composed by the loop above MUST be issued in a
SINGLE orchestrator message with multiple tool-use content blocks — Claude Code processes all
calls in a single message concurrently; multiple messages force sequential execution.

Log every `plan_json.deferred[]` and `plan_json.blocked[]` row's `reason` verbatim to the
transcript — informational only, no further action required (a deferred task becomes eligible
again on a later cycle per the admission gate's own defer-not-fail semantics; a blocked task's
`failed_tasks` membership was already recorded by `orchestrate-cycle-plan.sh`).

> **COMPLETION SEQUENCING**: After ALL Agent tool calls complete (Claude Code returns control after all calls in the single message finish), run per-task postflight for every dispatched task via the single script call below. Do NOT interleave postflight calls with dispatches. Per-task postflight includes a scoped git commit (the script's own WORK (i)); these commits serialize naturally in program order because postflight is a sequential loop within this same orchestrator turn, so the `specs/.commit-lock/` mutex is needed only against a concurrently-running separate dispatch, never against this loop's own iterations.

**Per-task postflight — single shared implementation for both engines.**
`orchestrate-cycle-postflight.sh` (see `docs/architecture/orchestrate-cycle-postflight.md`) now
performs the entire per-task pipeline this section used to inline: the stray-handoff sweep, the
mtime staleness gate and `dispatch_seq` identity gate (historically present ONLY in single-task
Stage 5 — Stage MT-4 trusted any handoff sitting at the expected path; this consolidation closes
that gap by construction), `.return-meta.json` recovery, phase-count corroboration,
writer-contract-aware defect recording, `user_decision` relay, status transition with the
completion-claim gate, artifact link + the artifact-round advance (closing the historical
"multi-task never advances `next_artifact_number`" gap), the `modified_files`-vs-`file_scope`
excursion advisory, and the per-task scoped commit. Defect recording now writes directly to
`$mt_state_file` from inside the script (`skill_orchestrate_append_detected_defect`, the same
shared function single-task Stage 5 uses against the loop guard) — the local
`append_detected_defect_mt` shim this section used to define is retired; there is no second copy
of the entry shape to keep in sync any more.

**These MT sites serve `/orchestrate --hard` batches too.** Exactly as Stage MT-1 already records
for `defer_ledger`, multi-task mode has no separate hard-mode MT-stage implementation — hard-mode
batches use these same Stage MT-1 through MT-5 stages directly, so this call needs no hard-mode
mirror anywhere. This unified handling is intentional; do not "fix" it by adding one.

**Per-task transport judgment (narrated, before the postflight loop)**: for each dispatched task,
judge that task's OWN Agent tool call outcome per
`context/patterns/infra-failure-discrimination.md` and set `task_transport_error` to `true` only
if the call itself returned a transport/API-layer error with no subagent-authored text of any
kind. Judge each task independently — re-set this scalar immediately before that task's own
postflight call below, never carrying one task's verdict over to another in the same batch.

**After all Agent tool calls complete**, call the script once per dispatched task, iterating the
SAME `plan_json.dispatch[]` rows the dispatch-composition loop above already iterated — each row
already carries `task`/`phase`/`agent`/`force` (the `force` field is the Phase 7 addition
`docs/architecture/orchestrate-cycle-postflight.md` documents), so no separate
`research_tasks`/`plan_tasks`/`implement_tasks` bookkeeping is needed here:

```bash
echo "$plan_json" | jq -c '.dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); phase=$(jq -r .phase <<<"$row"); agent=$(jq -r .agent <<<"$row")
  force=$(jq -r .force <<<"$row")
  task_dir_rel=$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")
  task_type=$(jq -r --argjson n "$t" \
    '.active_projects[] | select(.project_number == $n) | .task_type // "general"' specs/state.json)
  plan_path_for_task=$(ls -1 "${task_dir_rel}/plans/"*.md 2>/dev/null | sort -V | tail -1)

  postflight_json=$(bash .claude/scripts/orchestrate-cycle-postflight.sh "$t" \
    --session "$session_id" --state-file specs/state.json --phase "$phase" \
    --task-dir "$task_dir_rel" --task-type "$task_type" --agent "$agent" \
    --plan-path "$plan_path_for_task" --cycle-count "${cycle_count:-0}" \
    --transport-error "${task_transport_error:-false}" \
    --force-invoked "$force")

  dispatch_status=$(echo "$postflight_json" | jq -r '.status')
  verdict=$(echo "$postflight_json" | jq -r '.verdict')
  halt=$(echo "$postflight_json" | jq -r '.halt')
  infra_exempt_cycle=$(echo "$postflight_json" | jq -r '.infra_exempt_cycle')
  echo "[orchestrate] Task #${t}: dispatch result: $dispatch_status (verdict=$verdict)" >&2

  # ── user_decision relay ─────────────────────────────────────────────────────────────────────
  # Non-blocking for the WAVE regardless of the payload's own `blocking` value — mirrors
  # off-schema's own "loud per-task, never kills sibling tasks" precedent below: a single task's
  # pending question never stops the other tasks in this batch from proceeding. See
  # context/standards/user-decision-contract.md for the full contract.
  if [ "$verdict" = "ask_user" ]; then
    ud_question=$(echo "$postflight_json" | jq -r '.user_decision.question // "(no question text)"')
    ud_options=$(echo "$postflight_json" | jq -r '.user_decision.options // [] | join(" | ")')
    ud_recommended=$(echo "$postflight_json" | jq -r '.user_decision.recommended // ""')
    ud_blocking=$(echo "$postflight_json" | jq -r '.user_decision.blocking // false')
    echo "[orchestrate] Task #${t}: USER DECISION: $ud_question" >&2
    echo "[orchestrate] Task #${t}: Options: $ud_options | Agent's own recommendation: $ud_recommended (blocking=$ud_blocking)" >&2
  fi

  # ── Off-schema (halt=true): the multi-task analogue of Stage 5's halt ───────────────────────
  # Loud and per-task; deliberately does NOT kill sibling tasks in the wave. The script's own
  # WORK (j) already charged this task to `failed_tasks` (multi-task-scoped) before this JSON was
  # ever returned — this is a log line only, never a second write.
  if [ "$halt" = "true" ]; then
    echo "[orchestrate] Task #${t}: OFF-SCHEMA dispatch_status — charged to failed_tasks inside the script's own multi-task-scoped postflight. Sibling tasks in this wave are unaffected." >&2
  fi

  # ── Supplemental failed_tasks / MAX_INFRA_FAILURES cap (caller-owned; NOT the script's job) ──
  # Two cases the script's WORK (j) does not itself resolve, because both are loop-control
  # decisions this per-cycle script does not own (see its own header MUST NOT list) rather than
  # outcome bookkeeping:
  #   1. A genuinely missing/declined outcome (verdict=failed, halt=false, not infra-exempt — the
  #      handoff was absent AND return-meta recovery also declined AND no corroborating transport
  #      error exists) must still be charged to failed_tasks, preserving historical MT behavior.
  #      Re-adding a task the script already charged (an in-vocabulary failed/blocked
  #      dispatch_status) is a harmless no-op — `unique` makes this idempotent.
  #   2. An infra-exempt cycle (verdict=defer, infra_exempt_cycle=true) does NOT charge
  #      cycle_count, but IS independently bounded per task: once THIS task's own
  #      `infra_failures[$t]` (incremented and persisted by the script itself) reaches
  #      `MAX_INFRA_FAILURES`, give up on it for this batch — matching single-task Stage 7's own
  #      MAX_INFRA_FAILURES bound, scoped per-task instead of invocation-wide.
  if [ "$verdict" = "defer" ] && [ "$infra_exempt_cycle" = "true" ]; then
    task_infra=$(jq -r --arg t "$t" '.infra_failures[$t] // 0' "$mt_state_file" 2>/dev/null) || task_infra=0
    if [ "$task_infra" -ge "$MAX_INFRA_FAILURES" ]; then
      echo "[orchestrate] Task #${t}: MAX_INFRA_FAILURES ($MAX_INFRA_FAILURES) reached — repeated transport/API failures. Marking failed_tasks." >&2
      jq --argjson tn "$t" '.failed_tasks = ((.failed_tasks // []) + [$tn] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    else
      echo "[orchestrate] Task #${t}: INFRA FAILURE ${task_infra}/${MAX_INFRA_FAILURES} — NOT marked failed; stays eligible for the next cycle." >&2
    fi
  elif [ "$verdict" = "failed" ] && [ "$halt" != "true" ]; then
    jq --argjson tn "$t" '.failed_tasks = ((.failed_tasks // []) + [$tn] | unique)' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
  fi
done
```

**Bound**: the shared `MAX_CYCLES_MT` still increments once per wave cycle regardless of any
task's outcome, so the outer loop is unchanged and already bounded. Independently, a task can be
infra-deferred at most `MAX_INFRA_FAILURES` times (the supplemental check above) before it lands
in `failed_tasks` anyway — so no task can keep the wave alive indefinitely.

**Serialization note** (unchanged from before this cutover): these per-task commits (inside the
script's own WORK (i)) serialize naturally in program order, because per-task postflight is a
sequential loop within the orchestrator's own turn — no two iterations of this loop ever run
concurrently with each other. The `specs/.commit-lock/` mutex `git-commit-scoped.sh` acquires
internally remains required only for cross-process safety against a concurrently-running
SEPARATE `/orchestrate` or `/implement` dispatch sharing the same index, not against this loop's
own iterations.

**Task-lock release**: unconditional, per task, inside the script's own WORK (j) — using the
bare `$session_id` the acquire call used, matching the Task-lock acquire invariant. No separate
caller-side release call remains here.

### Stage MT-5: Multi-Task Postflight

After the lifecycle-cycling loop exits (all terminal, no eligible tasks, or MAX_CYCLES_MT reached):

1. Read from `mt_state_file`: `completed_tasks`, `failed_tasks`, `deferred_self_modifying`,
   `deferred_deploy_checkpoint`, `dispatch_start_ts`, `defer_ledger`, `idle_overlap_ledger`,
   `verify_deploy_baseline_notices`, `detected_defects`, `current_statuses`, `cycles_used`,
   counts. `validated_count = length(task_numbers)` — `task_numbers` already IS the validated set
   (STAGE 0's compact multi-task block filters out not-found and terminal candidates before
   invoking this skill), so no separate recomputation is needed; used by the template's
   `### ZERO DISPATCH` section below. `current_statuses`
   (refreshed every cycle by Stage MT-3 step 1) is what step 3 below consults to determine, per
   task in `deferred_self_modifying`, whether it reached a terminal state by loop exit.
2. **Compute the forward-progress invariant** (full contract in
   `context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
   subsection — referenced here, not restated): set `forward_progress_violated = true` when
   `task_numbers` is non-empty AND `dispatch_start_ts` is an empty object at loop exit; otherwise
   `false`. Write it back to `mt_state_file` so step 4 below can read it when rendering the
   consolidated output. This
   is cause-agnostic by construction — it is true regardless of which `defer_reason` produced the
   zero-dispatch outcome (`self_modifying`, `file_scope_collision`, or `deploy_checkpoint`).
3. Determine `exit_status` — this is the `.return-meta-multi.json` skill-status vocabulary
   (normatively defined in `context/formats/return-metadata-file.md`), distinct from the
   `tasks_completed` array below (which records state.json task status, where `"completed"` is
   correct):
   - `forward_progress_violated == true` → `"partial"` (preserve `mt_state_file` for
     diagnostics), taking precedence over the `"implemented"` branch below. **Why this precedence
     is needed**: the existing conditions key on `failed_count`, non-terminal
     `deferred_self_modifying` residue, and `deferred_deploy_checkpoint` emptiness, so a batch
     that dispatched nothing because every candidate hit `file_scope_collision` would otherwise
     satisfy the `"implemented"` branch with an empty `completed_tasks` array — a batch that did
     nothing reporting success. **This is a status-legibility correction, not an admission or
     behavior change**: no verdict, no task status, no `state.json` write, and no loop condition
     is affected by this branch — only the skill-status string reported for an outcome that
     already dispatched nothing.
   - `failed_count == 0` AND every task in `deferred_self_modifying` reached a terminal state
     (`completed`, `abandoned`, or `expanded`) by loop exit AND `deferred_deploy_checkpoint` is
     empty → `"implemented"` (remove `mt_state_file`). A task that appears in
     `deferred_self_modifying` — meaning the gate deferred it at least once cycle during this
     invocation — but went on to dispatch and complete before the loop exited is a SUCCESS, not a
     partial: the observation log records history, not an outstanding obligation.
   - `failed_count > 0` OR any task in `deferred_self_modifying` is STILL non-terminal at loop
     exit OR `deferred_deploy_checkpoint` is non-empty → `"partial"` (preserve `mt_state_file` for
     diagnostics). The gate here is deliberately narrower than "the log is merely non-empty" — it
     is "the log names a task with unfinished work remaining" — because the log itself no longer
     implies an outstanding exclusion the way it did before the narrowing. A non-empty
     `deferred_deploy_checkpoint` alone (zero `failed_tasks`, and no non-terminal
     `deferred_self_modifying` residue) still yields `"partial"`, never `"implemented"` — that set
     retains its original, unchanged permanent-exclusion semantics: at least one task remains
     undispatched pending a manual deploy/verify fix. This is distinct from a failure: the task is
     not in `failed_tasks` and was never status-mutated, so `"partial"` here means "incomplete by
     design", not "broken".

   **Confirmed invariant, restated not re-derived**: a zero-dispatch outcome mutates no
   `specs/state.json` status and adds nothing to `failed_tasks` — see
   `context/patterns/batch-orchestration-guardrails.md`'s `### The Forward-Progress Invariant`
   subsection for the full reasoning; this stage only reuses it by name.

   **`verify_deploy_baseline_notices` is NEVER consulted by this branch selection.** A batch that
   ran to completion past a pre-existing `verify-deploy.sh` failure (the third operator-visible
   state) is `"implemented"`, exactly as if the checkpoint had never fired at all — this is a
   deliberate decision, stated here so a later pass does not "fix" it into a `"partial"`. Only
   `deferred_deploy_checkpoint` (a genuine, non-empty exclusion set) affects this resolution;
   `verify_deploy_baseline_notices` is a pure observation log with no bearing on `exit_status`.

   **`detected_defects` is likewise NEVER consulted by this branch selection.** A batch that
   completed its work successfully and also observed one or more system-defect detections is
   `"implemented"`. A detection names a defect in the agent system itself, not unfinished work in
   the batch: it excludes no task and mutates no task status, so it cannot make an otherwise
   successful batch partial. This too is a deliberate decision, stated here so a later pass does
   not "fix" it into a `"partial"`.
4. Report `deferred_self_modifying` tasks in the consolidated summary as **deferred at least one
   cycle by the self-modification gate** — an OBSERVATION, not an outstanding-work category. For
   each task in the log, report its FINAL status at loop exit alongside the note: a task that
   reached a terminal state is reported as completed (with the observation as a footnote); a task
   still non-terminal at loop exit is reported as **still pending — deferred, not yet redispatched
   this invocation** and remains eligible for a future `/orchestrate` run (solo or batched) or an
   `--allow-self-modifying` override. Never add a self-modifying-deferred task to `failed_tasks`,
   and never mutate its `specs/state.json` status because of the deferral itself.

   Report `deferred_deploy_checkpoint` tasks as a **distinct** category —
   **deferred-by-redeploy-checkpoint** — separate from both the self-modification-gate
   observation above and `failed_tasks`, because the operator remedy differs: resolve the
   deploy/verify failure, redeploy manually, then re-run `/orchestrate` on the remaining task
   numbers. Never add these tasks to `failed_tasks`, and never mutate their `specs/state.json`
   status.

   Whenever `verify_deploy_baseline_notices` is non-empty, it MUST be reported as its own
   **distinct** category — never folded into the `deferred_deploy_checkpoint` reporting above, and
   never omitted merely because the batch otherwise succeeded (see
   `context/patterns/orchestrate-batch-results-template.md`'s own
   `### Pre-Existing Deploy-Verify Failures (Not Deferred)` section for
   the actual rendering). This is the third
   operator-visible state and must be announced just as loudly as an outright failure, on a
   `"partial"` batch or an `"implemented"` one alike.

   Whenever `detected_defects` is non-empty, it MUST likewise be reported as its own **distinct**
   category — never folded into any defer category, never merged with
   `verify_deploy_baseline_notices`, and never omitted merely because the batch otherwise
   succeeded (see `context/patterns/orchestrate-batch-results-template.md`'s own
   `### System Defects Detected` section for the
   actual rendering). Its operator remedy is different again
   from every category above: the fix belongs in the named source-store path under
   `agent-system/extensions/**`, not in any task's own work.

   **Additive requirement**: when `forward_progress_violated` is true, the consolidated summary
   MUST additionally lead with the zero-dispatch banner and enumerate every `defer_ledger` entry
   with its `defer_reason` (see `context/patterns/orchestrate-batch-results-template.md`'s own
   `### ZERO DISPATCH` section for the actual rendering). This is additive to, and does not replace, the
   `deferred_self_modifying` and `deferred_deploy_checkpoint` reporting instructions above.

   **Re-run sequence derivation**: the `### ZERO DISPATCH` section's own "Re-run sequence
   (dependency order; printed, not executed)" already specifies the rendering — order the
   deferred/excluded task numbers predecessor-first using `dependency_graph`, ascending within a
   tier, one `/orchestrate {N}` line per task; printed for the operator to run, never executed
   automatically. This replaces the deleted command's former reuse of a pre-computed `waves`
   array — this stage derives the order directly from `dependency_graph` instead.

   Whenever `idle_overlap_ledger` is non-empty, it MUST likewise be reported as its own
   **distinct** category — never folded into any Deferred section (its entries are ADMITS, not
   exclusions), never omitted merely because the batch otherwise succeeded (see
   `context/patterns/orchestrate-batch-results-template.md`'s own `### Admitted (idle overlap
   advisory)` section, for the actual rendering). It has no
   bearing on `exit_status` — an admitted-with-advisory task is a normal admit and is never
   consulted by branch selection above, exactly like `detected_defects` and
   `verify_deploy_baseline_notices`.

   **Emit the consolidated output now**: READ `context/patterns/orchestrate-batch-results-template.md`
   and emit the batch results using that template exactly; its per-section rendering conditions
   are contract, not commentary. This is the one instruction whose absence would silently drop
   all multi-task batch output, now that the command's former MULTI-TASK DISPATCH invocation of
   this same template has been deleted — this stage is now the template's sole caller.

   **Residue check**: after emitting the consolidated output, run the non-blocking residue check
   documented in `docs/architecture/orchestrate-state-machine.md`'s `### Commit Granularity`
   section (`git status --porcelain -- specs/`) — WARN-ONLY, never commits. This stage is the site
   that runs it; the command no longer does.
5. Write `specs/.return-meta-multi-${session_id}.json`:
```bash
jq -n \
  --arg status "$exit_status" \
  --arg session_id "$session_id" \
  --argjson tasks_completed "$completed_tasks" \
  --argjson tasks_failed "$failed_tasks" \
  --argjson tasks_deferred_self_modifying "$deferred_self_modifying" \
  --argjson tasks_deferred_deploy_checkpoint "$deferred_deploy_checkpoint" \
  --argjson forward_progress_violated "$forward_progress_violated" \
  --argjson defer_ledger "$defer_ledger" \
  --argjson idle_overlap_ledger "$idle_overlap_ledger" \
  --argjson detected_defects "$detected_defects" \
  --argjson verify_deploy_baseline_notices "$verify_deploy_baseline_notices" \
  --argjson cycles_used "$cycles_used" \
  '{
    "status": $status,
    "session_id": $session_id,
    "metadata": {
      "tasks_completed": $tasks_completed,
      "tasks_failed": $tasks_failed,
      "tasks_deferred_self_modifying": $tasks_deferred_self_modifying,
      "tasks_deferred_deploy_checkpoint": $tasks_deferred_deploy_checkpoint,
      "forward_progress_violated": $forward_progress_violated,
      "defer_ledger": $defer_ledger,
      "idle_overlap_ledger": $idle_overlap_ledger,
      "detected_defects": $detected_defects,
      "verify_deploy_baseline_notices": $verify_deploy_baseline_notices,
      "cycles_used": $cycles_used,
      "multi_task_mode": true
    }
  }' > "specs/.return-meta-multi-${session_id}.json"
```
The top-level `status` field keeps its existing closed vocabulary (`"implemented"` / `"partial"`
/ `"failed"`) and gains no new value; `forward_progress_violated`, `detected_defects`, and
`idle_overlap_ledger` are carried only inside `metadata`, never as `status` values themselves.

6. **In-flight session registry release**: alongside the `mt_state_file` remove/preserve handling
   above (step 3), release the batch's session registry entry — unconditionally, regardless of
   which `exit_status` branch was taken, so the registry is cleaned up at the same postflight
   boundary as the batch's other session-scoped runtime state. Best-effort and non-blocking; must
   not alter `exit_status`, `forward_progress_violated`, or any other computation above:
   ```bash
   bash .claude/scripts/task-lock.sh session-release "$session_id" 2>/dev/null || true
   ```
7. **Per-task `.dispatch/` cleanup (the MT-5 equivalent of the single-task loop-termination `rm
   -rf "${TASK_DIR}/.dispatch/"` sites)**: for every task in `completed_tasks` ONLY — never for a
   task in `failed_tasks` or still non-terminal at loop exit, mirroring the single-task asymmetry
   that `.dispatch/` persists across a `[PARTIAL]`/timeout exit and is swept only at genuine
   full completion — resolve that task's `project_name` from `specs/state.json` and remove its
   accumulated per-dispatch context directory. Best-effort and non-blocking:
   ```bash
   for tn in $(echo "$completed_tasks" | jq -r '.[]'); do
     pn=$(jq -r --argjson n "$tn" '.active_projects[] | select(.project_number == $n) | .project_name // empty' specs/state.json)
     [ -n "$pn" ] && rm -rf "specs/$(printf '%03d' "$tn")_${pn}/.dispatch/"
   done
   ```

---

## MUST NOT (Context Flatness Constraint)

This skill MUST NOT:

1. **Read research reports** (`reports/*.md`) during the state machine loop
2. **Read plan files** (`plans/*.md`) during the state machine loop
3. **Read implementation summaries** (`summaries/*.md`) during the state machine loop
4. **Read continuation handoff files** (`handoffs/*.md`) — pass the path, not the content

The two files read per dispatch are `.orchestrator-handoff.json` (≤400 tokens) and, on the
missing/stale-handoff path only, `.return-meta.json` (bounded to a handful of scalar fields, no
report prose). This ensures context grows by only ~450 tokens per cycle regardless of artifact
complexity.

**Since Phase 7 of the task that built it, `orchestrate-cycle-postflight.sh` — not this skill's
own inline prose — performs every read this constraint governs**: the handoff read (guarded by
the mtime staleness gate and the `dispatch_seq` identity gate), the `.return-meta.json` recovery
fallback, and the two narrowly-scoped `grep -c` phase-marker recovery reads (count-only, heading
lines only, never matched-line content). The script's own header enforces the identical four
bounds this section names, by construction — it is the ONE place either engine touches these
files, so there is no second copy of this narrative to keep in sync. The one exception is Defect
6's marker/handoff crosscheck (Stage 5, base mode only) and Stage 5b's churn/blockers read (hard
mode only), both of which re-derive their own tiny, read-only, gate-respecting view of the
already-fetched handoff — never a new read of report/plan/summary prose.

**Full narrative relocated**: the detailed branch-by-branch account of the two recovery
exceptions (return-meta fallback, phase-marker grep — including the three reachable branches,
their token ceilings, and the diagnostic-vs-authoritative distinction between them) now lives in
`docs/architecture/orchestrate-cycle-postflight.md`, alongside the script's own contract. Read
that file, not this section, for the full mechanics; this section states only the constraint
itself and where it is enforced.

---

## MUST NOT (Postflight Boundary)

This section is distinct from, and additive to, the Context Flatness Constraint above: that
section bounds what this skill reads between dispatches; this section bounds what this skill
does. After each stage dispatch (research/plan/implement) returns, this skill MUST NOT:

1. **Edit source files** - All research, planning, and implementation work is done by the
   dispatched skill/agent, never by the orchestrator's own state-machine loop
2. **Run build/test commands** - Verification is done by the dispatched skill/agent
3. **Use MCP/WebSearch/domain tools** - Domain tools are for the dispatched skill/agent's use only
4. **Analyze or grep source** - Analysis is dispatched-skill work
5. **Write reports/plans/summaries** - Artifact creation is dispatched-skill work

The per-dispatch postflight phase is LIMITED TO:
- Reading the dispatch's `.orchestrator-handoff.json` (or the bounded return-meta/phase-marker
  recovery exceptions documented above)
- Driving the state-machine transition to the next stage
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research dispatch | `$RESEARCH_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Plan dispatch | `$PLANNER_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Implement dispatch | `$IMPLEMENT_AGENT` (resolved by task type in Stage 1b) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes .drift-inspection.json |
| Plan revision (drift) | `"reviser-agent"` | Triggered when drift_pct > DRIFT_REVISION_THRESHOLD |

Default agents: `general-research-agent`, `planner-agent`, `general-implementation-agent`. Extension agents resolved in Stage 1b via `command-route-agent.sh`.
