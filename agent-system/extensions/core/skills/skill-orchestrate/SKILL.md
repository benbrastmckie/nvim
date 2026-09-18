---
name: skill-orchestrate
description: Autonomous state machine that drives a task through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases. Invoke for /orchestrate command.
allowed-tools: Agent, Bash, Read, Edit, AskUserQuestion
---

# Orchestrate Skill

Fire-and-forget autonomous loop implementing the task lifecycle state machine. One engine drives
every invocation — a single task number is a batch of size one through the SAME four-move loop a
many-task batch uses; there is no separate single-task code path. Full state table, transition
diagram, and design rationale: `docs/architecture/orchestrate-state-machine.md`.

## Context References

- `.claude/scripts/orchestrate-cycle-plan.sh` — Move 1: per-cycle status refresh, eligibility,
  admission, routing, and dispatch-file composition
- `.claude/scripts/orchestrate-build-dispatch.sh` — Move 1's dispatch-file writer (called
  internally by `orchestrate-cycle-plan.sh` for every row)
- `.claude/scripts/orchestrate-cycle-postflight.sh` — Move 3: the shared per-task postflight body
- `.claude/docs/architecture/orchestrate-state-machine.md` — state table, loop diagram,
  `mt_state_file` field reference, exit-status resolution, and `handoff-schema.md` cross-reference

---

## The Four-Move Loop

**Setup (once per invocation, before the loop begins)** — from delegation context:
`task_numbers`, `dependency_graph`, `session_id`, `lit_flag` (Move 1's `--lit` passthrough runs
`context/patterns/lit-stage4a-flow.md`'s resolver directives inside `orchestrate-build-dispatch.sh`
for every per-task dispatch), `compare_flag`,
`allow_self_modifying`, `allow_scope_collision`, `clean_flag`, `effort_flag`, `model_flag`,
`hard_mode` (`"true"` iff `effort_flag = "hard"`), `force_phases`,
`focus_prompt` (the user's own free-form `$2+` text typed after the task number(s) on the
`/orchestrate` command line — see `commands/orchestrate.md`; passed through to Move 1 below,
applied to every task in the batch). Register the batch's in-flight session (best-effort,
non-blocking):

```bash
bash .claude/scripts/task-lock.sh session-register "$session_id" "/orchestrate" \
  "$(IFS=,; echo "${task_numbers[*]}")" 2>/dev/null || true
```

For each task in `task_numbers`, run the entry reconcile ONCE (never per-cycle — this loop below
runs it again next cycle only for a task that is still eligible then, which is a fresh call, not
a repeat):

```bash
for task_number in "${task_numbers[@]}"; do
  recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
  [ -n "$recon_out" ] && echo "$recon_out"
done
```

### Move 1: Plan the cycle

One call. Status refresh, all-terminal check, eligibility, classification, admission (the four
defer gates and their overrides), the self-modification tie-breaker, the convergence guard, the
idle cross-batch overlap advisory, `force_phases` consumption (STOP, never fall-through, once a
task's own forced round completes for this run), artifact-keyed forced-plan/forced-implement
admission, task-directory creation, the lock probe, the PER-RUN work-cycle budget (resets every
invocation; no `--continue-budget` override), the inter-cycle redeploy checkpoint, and
dispatch-file composition (via `orchestrate-build-dispatch.sh`, including any `## Prior
Decisions` section from a task's `.decisions.json` and, when `focus_prompt` is non-empty, a
`User focus:` block composed with the task's own `research_questions`) all happen inside this
one script call — full contract in its own header comment and in `orchestrate-state-machine.md`.

`focus_prompt` is free-form user text (may contain spaces and embedded double quotes), so it is
NOT threaded through the `$( [ -n ... ] && echo --flag "$v" )` idiom the other flags below use —
that idiom re-splits on whitespace via the surrounding unquoted command substitution, which is
safe only for single-token flag values. Build it as an explicit array immediately above the call
instead, and splice it in with the `${arr[@]+"${arr[@]}"}` form (safe under `set -u` when the
array is empty):

```bash
focus_args=()
[ -n "${focus_prompt:-}" ] && focus_args=(--focus "$focus_prompt")
plan_json=$(bash .claude/scripts/orchestrate-cycle-plan.sh \
  --session "$session_id" --state-file specs/state.json \
  $( [ -n "${force_phases:-}" ] && echo --force-phases "$force_phases" ) \
  $( [ -n "${model_flag:-}" ] && echo --model "$model_flag" ) \
  $( [ "${clean_flag:-false}" = "true" ] && echo --clean ) \
  $( [ "${lit_flag:-false}" = "true" ] && echo --lit ) \
  $( [ "${compare_flag:-false}" = "true" ] && echo --compare ) \
  $( [ "${hard_mode:-false}" = "true" ] && echo --hard ) \
  $( [ "${effort_flag:-}" = "fast" ] && echo --fast ) \
  $( [ "${allow_self_modifying:-false}" = "true" ] && echo --allow-self-modifying ) \
  $( [ "${allow_scope_collision:-false}" = "true" ] && echo --allow-scope-collision ) \
  "${focus_args[@]+"${focus_args[@]}"}" \
  "${task_numbers[@]}")
stop_json=$(echo "$plan_json" | jq -c '.stop')
mt_state_file="specs/.orchestrator-multi-state-${session_id}.json"
```

If `stop_json` is non-null: log `.reason`/`.message`, skip to Move 4 (`all_terminal` is a success
exit; `max_cycles`/`no_eligible_stuck`/`max_infra_failures`/`convergence_guard` are partial
exits). Otherwise continue with this cycle's `plan_json.dispatch[]`/`plan_json.aux_dispatch[]`.
A task whose forced round has completed for this run (every phase its own
`--research`/`--plan`/`--implement` flag named has already been dispatched) appears in
`plan_json.blocked[]` with a `"forced round complete"` reason instead — this is that task's own
terminal-for-this-run verdict, not a batch-wide `stop`; the loop must treat it exactly like any
other `blocked[]` row (log and move on) and never re-attempt dispatching it this run, whether or
not a later cycle's caller repeats the forcing flag.

**A prepared row that will never be issued** (this cycle's own dispatch[] row, once Move 1 just
built it, is abandoned before Move 2 ever calls it — e.g. the operator asks to stop after seeing
the plan, or this process is about to be killed): `scripts/orchestrate-unwind-dispatch.sh
<task_number> --session SID [--dry-run] [--commit]` is the sanctioned way to reverse that one
task's Move 1 mutations (preflight status write, lock, dispatch file, durable loop-guard
bookkeeping) by hand. It is never called automatically from this loop — see
`docs/architecture/orchestrate-state-machine.md`'s "Unwinding an Unconsumed Dispatch" subsection
for the refusal gate and the by-hand-only rationale.

**MUST NOT**: never re-invoke `orchestrate-cycle-plan.sh` LIVE purely to inspect state (a "check
where things stand" call outside the normal per-cycle Move 1 loop). A live call mutates: it can
take a task lock, mint a dispatch_seq, write a preflight status, and build a real dispatch file —
none of which a mere inspection should ever risk. `--dry-run` (which mutates nothing; see
`commands/orchestrate.md`'s dry-run short-circuit) or reading `mt_state_file` directly are the
only sanctioned ways to check status mid-run. This loop stops on the plan's own stop verdict (or
a per-task `forced_round_complete` blocked row) — it does not get a second, unsanctioned way to
decide the run is done.

**Hard-mode burnout gate (`--hard` only, every cycle, before Move 2)**: the same three
self-checks single-task mode used to run (re-reading a path with no new dispatch since, a second
consecutive no-dispatch reasoning turn, reversing a decision without a fresh finding) — on any
signal, call `bash .claude/scripts/orchestrate-churn.sh --burnout-signal "$task_dir_abs"` for the
task the signal fired on. See `context/contracts/orchestrator-discipline.md` for the full
self-check text.

### Move 2: Dispatch

Issue every Agent call named by `dispatch[]` AND `aux_dispatch[]` in **one message** (concurrent
execution — multiple messages force sequential execution). Each row already carries every field
`orchestrate-build-dispatch.sh` (or its aux counterpart) resolved; the prompt is a fixed pointer.

```bash
echo "$plan_json" | jq -c '.dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); phase=$(jq -r .phase <<<"$row"); agent=$(jq -r .agent <<<"$row")
  model=$(jq -r '.model // empty' <<<"$row"); dispatch_file=$(jq -r .dispatch_file <<<"$row")
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")"
  dispatch_seq=$(jq -r --arg t "$t" '.dispatch_seq[$t]' "$mt_state_file")
  ctx_sid="$session_id"; [ "$phase" != "implement" ] && ctx_sid="${session_id}_${t}"
  # Agent tool: subagent_type: agent (model param if non-empty). Prompt: "You are dispatched by
  # /orchestrate for task $t, phase $phase. Read $dispatch_file first and execute it exactly; it
  # names every input, output path and contract." Context: { task_number: t,
  # orchestrator_mode: true, session_id: ctx_sid, task_dir: task_dir_abs,
  # handoff_path: "${task_dir_abs}/.orchestrator-handoff.json", dispatch_seq }
done
echo "$plan_json" | jq -c '.aux_dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); kind=$(jq -r .kind <<<"$row"); agent=$(jq -r .agent <<<"$row")
  dispatch_file=$(jq -r .dispatch_file <<<"$row")
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")"
  # Agent tool: subagent_type: agent. Prompt: "You are dispatched by /orchestrate for task $t
  # (auxiliary: $kind). Read $dispatch_file first and execute it exactly." Context: { task_number:
  # t, orchestrator_mode: false, session_id: session_id, task_dir: task_dir_abs } — NO
  # handoff_path key at all: an aux dispatch never writes .orchestrator-handoff.json.
done
```

**MUST NOT**: an `aux_dispatch[]` row never reaches Move 3 and never contributes to
`failed_tasks` — its only effect is a written file or a revised plan a later cycle picks up.
`agent` for an aux row is FIXED by `kind` (`fork`/`fork`/`reviser-agent`/the task's own resolved
research agent), never task-type-routed — see `orchestrate-cycle-plan.sh`'s header (Decision 2).

Log every `plan_json.deferred[]`/`plan_json.blocked[]` row's `reason` verbatim — informational
only; a deferred task becomes eligible again on a later cycle.

### Move 3: Postflight

**After ALL Agent calls from Move 2 complete** (never interleaved with dispatch), run this once
per `dispatch[]` row — the single shared implementation for every task, every phase, every effort
mode:

```bash
echo "$plan_json" | jq -c '.dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); phase=$(jq -r .phase <<<"$row"); agent=$(jq -r .agent <<<"$row")
  force=$(jq -r .force <<<"$row")
  task_dir_rel=$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")
  task_type=$(jq -r --argjson n "$t" \
    '.active_projects[] | select(.project_number == $n) | .task_type // "general"' specs/state.json)
  plan_path_for_task=$(ls -1 "${task_dir_rel}/plans/"*.md 2>/dev/null | sort -V | tail -1)
  # task_transport_error: true only when THIS task's own Agent call returned a transport/API
  # error with no subagent-authored text at all (context/patterns/infra-failure-discrimination.md)
  postflight_json=$(bash .claude/scripts/orchestrate-cycle-postflight.sh "$t" \
    --session "$session_id" --state-file specs/state.json --phase "$phase" \
    --task-dir "$task_dir_rel" --task-type "$task_type" --agent "$agent" \
    --plan-path "$plan_path_for_task" --cycle-count "${cycle_count:-0}" \
    --transport-error "${task_transport_error:-false}" --force-invoked "$force" \
    $( [ "${hard_mode:-false}" = "true" ] && echo --hard ))
  dispatch_status=$(echo "$postflight_json" | jq -r '.status')
  verdict=$(echo "$postflight_json" | jq -r '.verdict')
  halt=$(echo "$postflight_json" | jq -r '.halt')
  infra_exempt_cycle=$(echo "$postflight_json" | jq -r '.infra_exempt_cycle')
  echo "[orchestrate] Task #${t}: dispatch result: $dispatch_status (verdict=$verdict)" >&2

  # ask_user verdicts accumulate for Move 4's batched relay — never asked here, never per-task.
  if [ "$verdict" = "ask_user" ]; then
    jq --argjson tn "$t" --argjson q "$(echo "$postflight_json" | jq -c '.user_decision')" \
      '.pending_ask_user = ((.pending_ask_user // []) + [{"task": $tn, "decision": $q}])' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
  fi
  if [ "$halt" = "true" ]; then
    echo "[orchestrate] Task #${t}: OFF-SCHEMA — charged to failed_tasks inside the script's own postflight. Sibling tasks unaffected." >&2
  fi

  # Two cases the script does not itself resolve (loop-control, not outcome bookkeeping):
  if [ "$verdict" = "defer" ] && [ "$infra_exempt_cycle" = "true" ]; then
    task_infra=$(jq -r --arg t "$t" '.infra_failures[$t] // 0' "$mt_state_file" 2>/dev/null) || task_infra=0
    if [ "$task_infra" -ge "${MAX_INFRA_FAILURES:-3}" ]; then
      jq --argjson tn "$t" '.failed_tasks = ((.failed_tasks // []) + [$tn] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    fi
  elif [ "$verdict" = "failed" ] && [ "$halt" != "true" ]; then
    jq --argjson tn "$t" '.failed_tasks = ((.failed_tasks // []) + [$tn] | unique)' \
      "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
  fi
done
```

`MAX_CYCLES_MT` increments once per wave regardless of any task's outcome; a task can be
infra-deferred at most `MAX_INFRA_FAILURES` times before landing in `failed_tasks`. Per-task
commits (inside the script's own postflight) serialize naturally in program order; the
`specs/.commit-lock/` mutex guards only against a concurrent, separate dispatch.

### Move 4: Branch

**Loop condition**: if `stop_json` was null and at least one task remains non-terminal, go back
to Move 1 for the next cycle. Otherwise (or once `stop_json` fired) resolve this invocation's
final state — the full branch reasoning (forward-progress invariant, `exit_status` precedence
table, each deferred/observation category's rendering) is documented once in
`orchestrate-state-machine.md`'s "Consolidated Output and Exit-Status Resolution" section; this
step only executes it:

```bash
forward_progress_violated=$(jq -r 'if (.task_numbers // [] | length) > 0 and (.dispatch_start_ts // {} | length) == 0 then true else false end' "$mt_state_file")
exit_status="implemented"
[ "$forward_progress_violated" = "true" ] && exit_status="partial"
failed_count=$(jq -r '.failed_tasks // [] | length' "$mt_state_file")
[ "$failed_count" -gt 0 ] && exit_status="partial"
# ... plus the deferred_self_modifying/deferred_deploy_checkpoint non-terminal-residue checks —
# see orchestrate-state-machine.md for the exact three-branch precedence.
```

**Batched `AskUserQuestion` relay (after every task's Move 3 has run this cycle)**: if
`mt_state_file`'s `pending_ask_user[]` is non-empty, call `AskUserQuestion` once per entry
(question/options/recommended from `.decision`), batched together — never mid-cycle, never one
call per task. For each answer, append `{question, answer, cycle, timestamp}` to that task's
`specs/{padded}_{project}/.decisions.json` (schema:
`orchestrate-state-machine.md`'s "See Also" -> `handoff-schema.md`'s "Decisions File Schema"
section) and clear `pending_ask_user` for that task. A non-blocking decision proceeds on the
agent's own recommendation instead of asking, and is surfaced in the consolidated output. This
mechanism is UNRELATED to `detected_defects` (accumulate-and-render only, never prompted).

Then: emit the consolidated output (read `context/patterns/orchestrate-batch-results-template.md`
and render exactly), run the non-blocking residue check (`git status --porcelain -- specs/` —
warn only, never commits), release the session registry
(`task-lock.sh session-release "$session_id"`), remove `.dispatch/` for every task in
`completed_tasks` only, and write `specs/.return-meta-multi-${session_id}.json` with `status`,
`session_id`, and `metadata` (`tasks_completed`, `tasks_failed`, the two deferred arrays,
`forward_progress_violated`, `defer_ledger`, `idle_overlap_ledger`, `detected_defects`,
`verify_deploy_baseline_notices`, `cycles_used`) — the exact `jq -n` shape is unchanged from
before this rewrite and is documented in `context/formats/return-metadata-file.md`.

---

## MUST NOT (Context Flatness Constraint)

Full accounting: `docs/architecture/orchestrate-cycle-postflight.md`. Never read `reports/*.md`,
`plans/*.md`, `summaries/*.md`, or `handoffs/*.md` content during the loop —
`orchestrate-cycle-postflight.sh` performs every sanctioned read (the handoff, gated by mtime and
`dispatch_seq`; the bounded `.return-meta.json`/phase-marker recovery fallbacks). Context grows by
a measured 871 B (~218 tokens) per cycle per task, regardless of artifact complexity — see
`docs/architecture/orchestrate-state-machine.md`'s `## Context Flatness Guarantee` for the
re-runnable measurement (`scripts/tests/test-orchestrate-context-growth.sh`).

## MUST NOT (Postflight Boundary)

Full accounting: `docs/architecture/handoff-schema.md`'s "Postflight Boundary" section. This
section is additive to the Context Flatness Constraint above. After a dispatch returns (Move 3),
this skill MUST NOT: edit source files, run build/test commands, use MCP/WebSearch/domain tools,
analyze or grep source, or write reports/plans/summaries — that is dispatched-agent work. This
skill only reads the handoff, drives the state transition, and cleans up temp/marker files.
Reference: `context/standards/postflight-tool-restrictions.md`.

Also: never hardcode a phase order (the loop dispatches whatever phase `orchestrate-cycle-plan.sh`
names); never let `detected_defects` call `AskUserQuestion` (accumulate-then-render only, per
`orchestrate-state-machine.md`'s `mt_state_file` field reference); never let an `aux_dispatch[]`
row reach Move 3.

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research dispatch | `$RESEARCH_AGENT` (resolved by task type inside `orchestrate-cycle-plan.sh`, via `command-route-agent.sh`) | Fresh context; `orchestrator_mode: true` |
| Plan dispatch | `$PLANNER_AGENT` (same resolution) | Fresh context; `orchestrator_mode: true` |
| Implement dispatch | `$IMPLEMENT_AGENT` (same resolution) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes `.drift-inspection.json` |
| Plan revision (drift) | `"reviser-agent"` | Triggered when `drift_pct > DRIFT_REVISION_THRESHOLD` |

Default agents: `general-research-agent`, `planner-agent`, `general-implementation-agent`.
Extension agents resolved by `command-route-agent.sh`.
