---
name: skill-orchestrate
description: Autonomous state machine that drives a task through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases. Invoke for /orchestrate command.
allowed-tools: Agent, Bash, Read, Edit, AskUserQuestion
---

# Orchestrate Skill

Fire-and-forget autonomous loop implementing the task lifecycle state machine — one engine drives
every invocation; a single task number is a batch of size one through the SAME four-move loop, no
separate single-task code path. Full state table, transition diagram, design rationale:
`docs/architecture/orchestrate-state-machine.md`.

## Context References

- `.claude/scripts/orchestrate-cycle-plan.sh` — Move 1: per-cycle status refresh, eligibility,
  admission, routing, and dispatch-file composition
- `.claude/scripts/orchestrate-build-dispatch.sh` — Move 1's dispatch-file writer (called
  internally by `orchestrate-cycle-plan.sh` for every row)
- `.claude/scripts/orchestrate-cycle-postflight.sh` — Move 3: the shared per-task postflight body
- `.claude/scripts/orchestrate-recover-message-findings.sh` — Move 3's `report_missing=true`
  branch: saves a research dispatch's message-borne findings as a clearly-tagged recovered
  artifact (D4)

---

## The Four-Move Loop

**Setup (once per invocation, before the loop begins)** — from delegation context:
`task_numbers`, `dependency_graph`, `session_id`, `lit_flag` (Move 1's `--lit` passthrough runs
`context/patterns/lit-stage4a-flow.md`'s resolver directives inside `orchestrate-build-dispatch.sh`
for every per-task dispatch), `compare_flag`, `gate_flag` (advisory-only intermediate
verification tier; forwarded unchanged and never acted on by this skill),
`allow_self_modifying`, `allow_scope_collision`, `clean_flag`, `effort_flag`, `model_flag`,
`hard_mode` (`"true"` iff `effort_flag = "hard"`), `force_phases`,
`focus_prompt` (free-form `$2+` text after the task number(s) on the `/orchestrate` command line
— see `commands/orchestrate.md`; passed to Move 1 below, applied to every task in the batch).
Register the batch's in-flight session (best-effort, non-blocking):

```bash
bash .claude/scripts/task-lock.sh session-register "$session_id" "/orchestrate" \
  "$(IFS=,; echo "${task_numbers[*]}")" 2>/dev/null || true
```

For each task in `task_numbers`, run the entry reconcile ONCE (never per-cycle — a later cycle's
call for a still-eligible task is fresh, not a repeat):

```bash
for task_number in "${task_numbers[@]}"; do
  recon_out=$(bash .claude/scripts/reconcile-task-status.sh "$task_number" "$session_id" 2>&1 || true)
  [ -n "$recon_out" ] && echo "$recon_out"
done
```

### Move 1: Plan the cycle

One call. Status refresh, all-terminal check, eligibility, classification, admission (the four
defer gates and their overrides), the self-modification tie-breaker, the convergence guard, the
idle cross-batch overlap advisory, `force_phases` consumption (STOP-not-fall-through once a
task's own forced round completes for this run), artifact-keyed forced-plan/forced-implement
admission, task-directory creation, the lock probe, the PER-RUN work-cycle budget (resets every
invocation; no `--continue-budget` override), the inter-cycle redeploy checkpoint, and
dispatch-file composition (via `orchestrate-build-dispatch.sh`, incl. a `## Prior Decisions`
section from `.decisions.json` and, when `focus_prompt` is non-empty, a `User focus:` block
composed with `research_questions`) all happen inside this one script call — full contract in
its own header comment and in `orchestrate-state-machine.md`.

`focus_prompt` is free-form text (may contain spaces/quotes), so it is NOT threaded through the
`$( [ -n ... ] && echo --flag "$v" )` idiom below — that re-splits on whitespace via the
surrounding unquoted command substitution, safe only for single-token values. Build it as an
explicit array above the call, splicing with `${arr[@]+"${arr[@]}"}` (safe under `set -u` when
empty):

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
  $( [ "${gate_flag:-false}" = "true" ] && echo --gate ) \
  $( [ "${hard_mode:-false}" = "true" ] && echo --hard ) \
  $( [ "${effort_flag:-}" = "fast" ] && echo --fast ) \
  $( [ "${allow_self_modifying:-false}" = "true" ] && echo --allow-self-modifying ) \
  $( [ "${allow_scope_collision:-false}" = "true" ] && echo --allow-scope-collision ) \
  "${focus_args[@]+"${focus_args[@]}"}" \
  "${task_numbers[@]}")
stop_json=$(echo "$plan_json" | jq -c '.stop')
mt_state_file="specs/.orchestration/.orchestrator-multi-state-${session_id}.json"
mkdir -p "$(dirname "$mt_state_file")"
```

If `stop_json` is non-null: log `.reason`/`.message`, skip to Move 4 (`all_terminal` is a success
exit; `max_cycles`/`no_eligible_stuck`/`max_infra_failures`/`convergence_guard` are partial
exits). Otherwise continue with this cycle's `plan_json.dispatch[]`/`plan_json.aux_dispatch[]`.
A task whose forced round has completed for this run (every phase its own
`--research`/`--plan`/`--implement` flag named has already been dispatched) appears in
`plan_json.blocked[]` with a `"forced round complete"` reason instead — this task's own
terminal-for-this-run verdict (not a batch-wide `stop`), treated like any other `blocked[]` row:
log and move on, never re-attempted this run even if a later cycle repeats the forcing flag.

**A prepared row that will never be issued** (this cycle's own dispatch[] row, once Move 1 just
built it, is abandoned before Move 2 ever calls it — e.g. the operator asks to stop after seeing
the plan, or this process is about to be killed): `scripts/orchestrate-unwind-dispatch.sh
<task_number> --session SID [--dry-run] [--commit]` is the sanctioned hand-recovery path, never
called automatically from this loop — see `docs/architecture/orchestrate-state-machine.md`'s
"Unwinding an Unconsumed Dispatch" subsection for what it reverses, the refusal gate, the
by-hand-only rationale, and what to run afterwards. If the unwind was run because the underlying work was already complete
(a `summaries/*.md` exists), follow it with `reconcile-task-status.sh <task_number> <session_id>`
— NOT a direct re-run of `orchestrate-cycle-postflight.sh` or `/orchestrate`, which opens a fresh
dispatch window the existing handoff predates and trips the (working-as-designed) handoff-
identity staleness gate.

**MUST NOT**: never re-invoke `orchestrate-cycle-plan.sh` LIVE just to inspect state — a live
call mutates (task lock, `dispatch_seq`, preflight status, a real dispatch file). `--dry-run`
(mutates nothing; see `commands/orchestrate.md`'s dry-run short-circuit) or reading
`mt_state_file` directly are the only sanctioned ways to check status mid-run. This loop stops
only on the plan's own stop verdict or a per-task `forced_round_complete` blocked row.

**Hard-mode burnout gate (`--hard` only, every cycle, before Move 2)**: on any of the three
self-check signals (re-reading a path with no new dispatch, a second consecutive no-dispatch
turn, reversing a decision without a fresh finding), call `bash
.claude/scripts/orchestrate-churn.sh --burnout-signal "$task_dir_abs"` for the task the signal
fired on. Full self-check text: `context/contracts/orchestrator-discipline.md`.

### Move 2: Dispatch

Issue every Agent call named by `dispatch[]` AND `aux_dispatch[]` in **one message** (multiple
messages force sequential execution). Each row already carries every field
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

**MUST NOT**: an `aux_dispatch[]` row never reaches Move 3 or contributes to `failed_tasks` —
its only effect is a written file or a revised plan a later cycle picks up. `agent` is FIXED by
`kind` (`fork`/`fork`/`reviser-agent`/the resolved research agent), never task-type-routed — see
`orchestrate-cycle-plan.sh`'s header (Decision 2).

Log every `plan_json.deferred[]`/`plan_json.blocked[]` row's `reason` verbatim — informational;
deferred tasks become eligible again later.

**MUST NOT**: no field of a `dispatch[]` or `aux_dispatch[]` row is ever forwarded as an
Agent-tool argument unless this section names it as one — today that is `agent`
(-> `subagent_type`) and `model` only; the `Context: {...}` fields above are prompt text handed
to the dispatched agent, never Agent-tool arguments themselves.

### Move 3: Postflight

**After ALL Agent calls from Move 2 complete** (never interleaved with dispatch), run this once
per `dispatch[]` row — the one shared implementation for every task/phase/effort mode:

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
  persisted_status=$(echo "$postflight_json" | jq -r '.persisted_status // "unknown"')
  verdict=$(echo "$postflight_json" | jq -r '.verdict')
  halt=$(echo "$postflight_json" | jq -r '.halt')
  infra_exempt_cycle=$(echo "$postflight_json" | jq -r '.infra_exempt_cycle')
  report_missing=$(echo "$postflight_json" | jq -r '.report_missing // false')
  stall_suspected=$(echo "$postflight_json" | jq -r '.stall_suspected // false')
  echo "[orchestrate] Task #${t}: dispatch result: $dispatch_status (verdict=$verdict, persisted=$persisted_status)" >&2

  # dispatch_seq_for_row is read unconditionally (not only inside the D4 branch below): the
  # stall-reprompt accumulation further down needs it too, to key pending_stall_reprompt[] /
  # stall_reprompted[] on {task, dispatch_seq} exactly like D4 keys its own capture file on it.
  dispatch_seq_for_row=$(jq -r --arg t "$t" '.dispatch_seq[$t] // empty' "$mt_state_file")

  # D4 message-findings recovery (research phase only; full rationale in "MUST NOT (Postflight
  # Boundary)" below): report_missing=true means no usable report file/outcome was recovered, so
  # the lead writes this row's own Agent-tool return text VERBATIM to
  # "${task_dir_rel}/.dispatch/${dispatch_seq}.agent-message.md", then runs:
  if [ "$report_missing" = "true" ]; then
    recover_json=$(bash .claude/scripts/orchestrate-recover-message-findings.sh \
      --task-dir "$task_dir_rel" --dispatch-seq "$dispatch_seq_for_row" \
      --message-file "${task_dir_rel}/.dispatch/${dispatch_seq_for_row}.agent-message.md" \
      --agent "$agent" --session "$session_id")
    echo "[orchestrate] Task #${t}: message-findings recovery: $recover_json" >&2
  fi
  # Never changes verdict/dispatch_status/failed_tasks — best-effort save only, per D4.

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
    # stall_suspected guard: a suspected stall does NOT accept the failed verdict on its FIRST
    # occurrence for this dispatch_seq — the committed work is intact and only the wrap-up is
    # missing (see "Abandoned Wrap-Up" in orchestrate-state-machine.md). Accumulate instead and
    # let Move 4's batched relay re-prompt once before this verdict is ever charged to
    # failed_tasks. A SECOND no-outcome return on the SAME dispatch_seq (stall_reprompted[]
    # already carries this {task, dispatch_seq} pair) takes this ordinary failed_tasks path —
    # exactly one re-prompt is ever owed per dispatch.
    already_stall_reprompted=$(jq -r --argjson tn "$t" --argjson ds "${dispatch_seq_for_row:-null}" \
      '([.stall_reprompted // [] | .[] | select(.task == $tn and .dispatch_seq == $ds)] | length) > 0' \
      "$mt_state_file" 2>/dev/null) || already_stall_reprompted=false
    if [ "$stall_suspected" = "true" ] && [ "$already_stall_reprompted" != "true" ]; then
      echo "[orchestrate] Task #${t}: STALL SUSPECTED — queued for a one-time foreground re-prompt (dispatch_seq=${dispatch_seq_for_row}, phase=${phase}); NOT charged to failed_tasks yet." >&2
      jq --argjson tn "$t" --argjson ds "${dispatch_seq_for_row:-null}" --arg ph "$phase" \
        --arg ag "$agent" --argjson c "${cycle_count:-0}" \
        '.pending_stall_reprompt = ((.pending_stall_reprompt // []) + [{"task": $tn, "dispatch_seq": $ds, "phase": $ph, "agent": $ag, "cycle": $c}])
         | .stall_ledger = ((.stall_ledger // []) + [{"task": $tn, "dispatch_seq": $ds, "phase": $ph, "cycle": $c}])' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    else
      jq --argjson tn "$t" '.failed_tasks = ((.failed_tasks // []) + [$tn] | unique)' \
        "$mt_state_file" > "${mt_state_file}.tmp" && mv "${mt_state_file}.tmp" "$mt_state_file"
    fi
  fi
done
```

No Agent call is issued anywhere in this loop, including the stall-reprompt accumulation just
added: Move 2's "never interleaved with dispatch" rule and the Postflight Boundary's enumeration
both forbid it here. That is why the actual re-prompt is sited at Move 4's branch move below,
not inside this per-task postflight loop.

**`.status` vs. `.persisted_status`**: `.status` above is the dispatched agent's own
self-report (diagnostic only — never used for loop-control); `.persisted_status` is
`state.json`'s actual post-postflight status. They legitimately diverge by design (e.g. an
empty-blocker `partial`). Full contract: `docs/architecture/orchestrate-state-machine.md`'s
"Context Flatness Guarantee" section.

`MAX_CYCLES_MT` increments once per wave regardless of outcome; a task can be infra-deferred at
most `MAX_INFRA_FAILURES` times before landing in `failed_tasks`. Per-task commits (inside the
script's own postflight) serialize in program order; `specs/.commit-lock/` guards only against a
concurrent, separate dispatch.

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
call per task. Per answer, call `bash .claude/scripts/orchestrate-record-decision.sh` (see its usage for
flags); never hand-author this file. Clear `pending_ask_user` for that task. A non-blocking decision proceeds on the agent's own recommendation instead of asking, and
is surfaced in the consolidated output. Unrelated to `detected_defects` (accumulate-and-render
only, never prompted).

**Batched stall re-prompt relay (same siting as the `AskUserQuestion` relay directly above —
after every task's Move 3 has run this cycle, never mid-cycle, never once per task inside Move
3's own loop)**: if `mt_state_file`'s `pending_stall_reprompt[]` is non-empty, for each entry
issue exactly one Agent call, batched together with every other entry's call (and with the
`AskUserQuestion` calls above, in one message):

```bash
echo "$(jq -c '.pending_stall_reprompt // []' "$mt_state_file")" | jq -c '.[]' | while IFS= read -r entry; do
  t=$(jq -r .task <<<"$entry"); ds=$(jq -r .dispatch_seq <<<"$entry")
  phase=$(jq -r .phase <<<"$entry"); agent=$(jq -r .agent <<<"$entry")
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")"
  # Agent tool: subagent_type: agent (the SAME agent this dispatch_seq already used — no new
  # dispatch file is composed; Move 1 does not run for this task this cycle). Prompt: "You are
  # being re-prompted by /orchestrate for task $t, phase $phase, dispatch_seq $ds. Your previous
  # turn committed work but ended without writing your closing artifacts. (a) Re-run the
  # verification you were waiting on in the FOREGROUND, with a bounded timeout, redirecting
  # output to a file and grepping that file — never await a harness notification. (b) Attribute
  # any failure to your own edits or to pre-existing breakage, with git log/git status overlap
  # evidence. (c) Close every phase with an explicit verdict ([COMPLETED], or [COMPLETED WITH
  # EXCLUSIONS] with a full Reasoned Exclusions record) — leave none open. (d) Write all three
  # closing artifacts (summary, .return-meta.json, .orchestrator-handoff.json) and commit them."
  # Context: { task_number: t, orchestrator_mode: true, session_id: session_id,
  # task_dir: task_dir_abs, handoff_path: "${task_dir_abs}/.orchestrator-handoff.json",
  # dispatch_seq: ds }
done
```

After each relay Agent call returns, run `orchestrate-cycle-postflight.sh` once for that task
with the same invocation shape Move 3 uses, and apply the ordinary verdict handling to its result
— including the `failed_tasks` append, which is now reachable because this dispatch_seq's
re-prompt has been spent. Then move the entry from `pending_stall_reprompt[]` to
`stall_reprompted[]`, keyed on `{task, dispatch_seq}` (the same key Move 3's guard reads), so
exactly one re-prompt is ever owed per dispatch — a second no-outcome return on the same
`dispatch_seq` takes the ordinary `failed_tasks` path on its next Move 3 pass rather than
re-queuing here. This relay, like the `AskUserQuestion` relay it sits beside, never runs
mid-cycle and never runs once per task inside Move 3's loop.

Then: emit the consolidated output (read `context/patterns/orchestrate-batch-results-template.md`
and render exactly), run the residue check (`git status --porcelain -- specs/` — warn only,
never commits), release the session registry (`task-lock.sh session-release "$session_id"`),
remove `.dispatch/` for every task in
`completed_tasks` only, and write `specs/.orchestration/.return-meta-multi-${session_id}.json`
(creating `specs/.orchestration/` first via `mkdir -p` if it does not already exist) with `status`,
`session_id`, and `metadata` (`tasks_completed`, `tasks_failed`, the two deferred arrays,
`forward_progress_violated`, `defer_ledger`, `idle_overlap_ledger`, `detected_defects`,
`verify_deploy_baseline_notices`, `cycles_used`) — `jq -n` shape documented in
`context/formats/return-metadata-file.md`.

---

## MUST NOT (Context Flatness Constraint)

Never read `reports/*.md`, `plans/*.md`, `summaries/*.md`, or `handoffs/*.md` during the loop —
`orchestrate-cycle-postflight.sh` performs every sanctioned read on this skill's behalf (the
handoff, gated by mtime/`dispatch_seq`; the bounded recovery fallbacks). Full accounting and the
measured 871 B/cycle/task growth figure: `docs/architecture/orchestrate-cycle-postflight.md` and
`orchestrate-state-machine.md`'s `## Context Flatness Guarantee`.

## MUST NOT (Postflight Boundary)

Full contract (the five prohibited operations, the D4 verbatim-recovery exception, and why
`orchestrate-cycle-postflight.sh` is this boundary's sole implementation): see
`docs/architecture/handoff-schema.md`'s "Postflight Boundary" section and
`context/standards/postflight-tool-restrictions.md`. After a dispatch returns (Move 3), this
skill only reads the handoff, drives the state transition, and cleans up temp/marker files.

Also: never hardcode a phase order (dispatch whatever phase `orchestrate-cycle-plan.sh` names);
the `detected_defects` constraint above (Move 4) applies here too.

## Skill-to-Agent Mapping

| Operation | `subagent_type` | Notes |
|-----------|----------------|-------|
| Research / Plan / Implement dispatch | `$RESEARCH_AGENT` / `$PLANNER_AGENT` / `$IMPLEMENT_AGENT` (all resolved by task type inside `orchestrate-cycle-plan.sh`, via `command-route-agent.sh`) | Fresh context; `orchestrator_mode: true` |
| Blocker research | `"fork"` | Inherits parent cache; fast blocker research |
| Plan revision (blocker) | `"reviser-agent"` | Fresh context; `orchestrator_mode: false` |
| Drift inspection | `"fork"` | Inherits parent cache; reads plan file, writes `.drift-inspection.json` |
| Plan revision (drift) | `"reviser-agent"` | Triggered when `drift_pct > DRIFT_REVISION_THRESHOLD` |

Default agents: `general-research-agent`, `planner-agent`, `general-implementation-agent`.
