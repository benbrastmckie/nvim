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

## Multi-Task Mode

There is one engine now: every invocation, including a single-task-number one, runs through this
loop as a batch (`task_numbers` of length one for a solo invocation). The skill receives the
intra-batch dependency graph from `orchestrate.md`'s compact STAGE 0 multi-task block and manages
all tasks in a single orchestrator instance.

### Stage MT-1: Parse Multi-Task Context

Read from delegation context:
- `task_numbers` — array of task numbers to manage
- `dependency_graph` — map of task_number -> [predecessor_task_numbers]
- `waves` — **diagnostic echo, recorded not consumed**: a single row containing all validated
  tasks (`[[t1, t2, ...]]`). Nothing reads this field — eligibility is re-derived fresh every
  cycle at Stage MT-3 step 4.5 from current task statuses plus `dependency_graph`, never from a
  pre-computed wave schedule. The key is kept required only because `mt_state_file` below still
  carries it; do not reintroduce wave-based dispatch logic on account of its presence.
- `session_id`, `lit_flag`, `compare_flag` (default: "false") — forwarded, unmodified, to
  `orchestrate-cycle-plan.sh`'s own `--compare` flag below, which scopes it to implement-phase
  candidates internally; never threaded into research- or plan-phase dispatches
- `allow_self_modifying` (default: "false") — consumer-side opt-in
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
`description`. Compute `task_dir = "specs/${padded}_${project_name}"`. Resolve `research_agent` and `implement_agent` via `command-route-agent.sh` (the same routing table below):

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
  $( [ "${compare_flag:-false}" = "true" ] && echo --compare ) \
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
`stop_json` is null**: continue to MT-3-hard below, then to Stage MT-4's dispatch composition,
using this cycle's `plan_json.dispatch[]` rows.

**MT-3-hard. Burnout circuit-breaker gate (hard mode only)**

**MANDATORY when `$hard_mode` is true — runs EVERY cycle**, after `plan_json` is known and
`stop_json` has been confirmed null, strictly before Stage MT-4's dispatch composition. Skipped
entirely when `hard_mode` is false. The batch engine has no per-invocation state-machine copy of
its own for this self-check — it is the SAME behavioral gate single-task Stage 3b-hard states,
reused verbatim rather than duplicated, per
`.claude/context/contracts/orchestrator-discipline.md`. Check all three self-checks, for whichever
task in this cycle's `plan_json.dispatch[]` you are currently reasoning about, before proceeding:

1. **If you are about to Read a path you have already read this session without an
   intervening `Agent` dispatch having produced new information, STOP and dispatch
   `$RESEARCH_AGENT` instead** (focus_prompt = a literal restatement of the exact unresolved
   question) — do not complete the re-read.
2. **If this is the second or later consecutive orchestrator turn reasoning about task content
   with no `Agent` tool call in between, STOP reasoning immediately and take response (a) or
   (b) from the contract now** — do not produce a third such turn.
3. **If you are about to reverse a phase, target, or escalation decision without a fresh
   dispatch having just produced the new finding that justifies it, STOP and either dispatch
   `$RESEARCH_AGENT` to obtain that finding or let the NEXT cycle's `aux_pending`/`aux_dispatch[]`
   machinery (Decision 2) carry the escalation instead — never reverse on inline reasoning alone.**

**On any signal firing**, call `orchestrate-churn.sh --burnout-signal "$task_dir_abs"` for the
task the signal fired on (resolved the same way the dispatch-composition loop above resolves
`task_dir_abs`) — replacing single-task 3b-hard's own inline `loop_guard_file` jq write with a
single script call, since the durable counter's home
(`${TASK_DIR}/.orchestrator-loop-guard`'s `burnout_signals_this_session` field) and its exact log
line (`"[orchestrate] H-orch: burnout signal detected ..."`) are already owned by that script (see
its own `--burnout-signal` mode, built by the earlier phase of this same task):

```bash
if [ "${hard_mode:-false}" = "true" ]; then
  # <signal fired — see the three self-checks above>
  bash .claude/scripts/orchestrate-churn.sh --burnout-signal "$task_dir_abs" >/dev/null
fi
```

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

**Aux dispatch composition (Decision 2 — the task that ported single-task's Stage 5a/5b/6
auxiliary flows into the batch engine)**: a SECOND, adjacent loop, over `plan_json.aux_dispatch[]`
rather than `plan_json.dispatch[]`. Each row already carries `task`, `kind`, `agent`, `model`, and
`dispatch_file` — `orchestrate-cycle-plan.sh` already called `orchestrate-build-aux-dispatch.sh`
for every row, so the dispatch file itself names the prompt and every input this dispatch carries.
`agent` here is FIXED by `kind` (`fork`, `fork`, `reviser-agent`, or the task's own already-resolved
research agent — see that script's own header), never task-type-routed.

Prompt for every row: `"You are dispatched by /orchestrate for task $t (auxiliary: $kind). Read
$dispatch_file first and execute it exactly; it names every input, output path and contract."`
Context for every row: `{ task_number: t, orchestrator_mode: false, session_id: session_id,
task_dir: task_dir_abs }` — deliberately NO `handoff_path` key at all (not even null): an aux
dispatch runs with `orchestrator_mode: false` and, per the decided one-channel-per-mode contract
(`docs/architecture/handoff-schema.md`'s "Handoff Writers" table), writes NO
`.orchestrator-handoff.json` — the same reasoning single-task Stage 6 Step 3 already documents for
its own research fork.

```bash
echo "$plan_json" | jq -c '.aux_dispatch[]' | while IFS= read -r row; do
  t=$(jq -r .task <<<"$row"); kind=$(jq -r .kind <<<"$row"); agent=$(jq -r .agent <<<"$row")
  model=$(jq -r '.model // empty' <<<"$row"); dispatch_file=$(jq -r .dispatch_file <<<"$row")
  task_dir_abs="${SKILL_REPO_ROOT:-$(pwd)}/$(jq -r --arg t "$t" '.task_dirs[$t]' "$mt_state_file")"
  # Invoke Agent tool: subagent_type = agent (model, if non-empty, as the Agent tool's `model`
  # parameter); prompt and context per the two field mappings named just above.
done
```

**MUST NOT**: an `aux_dispatch[]` row NEVER reaches `orchestrate-cycle-postflight.sh` and NEVER
contributes to `failed_tasks` — true by construction (the postflight loop below iterates
`plan_json.dispatch[]` only, never `plan_json.aux_dispatch[]`), stated here explicitly so it is
never "fixed" by adding a postflight call for aux rows. An aux dispatch's only effect is a written
file (`.blocker-research.json`, `.drift-inspection.json`) or a revised plan, which the NEXT
cycle's `orchestrate-cycle-plan.sh` AUX DECISION section and ordinary status-derived dispatch pick
up on their own.

**BATCHING RULE** (unchanged, now covering BOTH loops above): ALL Agent tool calls composed by
either loop MUST be issued in a SINGLE orchestrator message with multiple tool-use content blocks
— Claude Code processes all calls in a single message concurrently; multiple messages force
sequential execution.

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
    --force-invoked "$force" \
    $( [ "${hard_mode:-false}" = "true" ] && echo --hard ))

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
