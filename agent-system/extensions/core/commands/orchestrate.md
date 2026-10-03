---
description: Execute a task autonomously through its full lifecycle (research -> plan -> implement -> complete) without user confirmation between phases
allowed-tools: Skill, Agent, Bash(jq:*), Bash(git:*), Read, AskUserQuestion
argument-hint: TASK_NUMBERS [PROMPT] [--haiku|--sonnet|--opus|--fable] [--research] [--plan] [--implement]
model: opus
---

# /orchestrate Command

Drive a task through its complete lifecycle autonomously without pausing for user confirmation.
Implements fire-and-forget state machine: research -> plan -> implement -> complete.

## Arguments

- `$1` - Task number(s) (required). Supports single task, comma-separated lists, and ranges.
  - Single: `42`
  - Comma-separated: `42, 43, 45`
  - Range: `42-45`
  - Mixed: `42, 44-46, 50`
- `$2+` - Optional prompt/focus text (e.g., `focus on the LSP config`). Applies to all tasks in multi-task mode.

## Constraints

- The loop uses dependency-aware wave dispatch, uniformly for a batch of one task or many.
  Batching related open tasks into one invocation is the default way to work this system, not a
  throughput-only optimization — see `context/patterns/batch-orchestration-guardrails.md`'s
  "Batching Is the Default" section for which tasks to batch together.
- `--research`/`--plan`/`--implement` (phase-forcing flags): honored uniformly across every
  task_number in multi-task mode too, via `scripts/orchestrate-cycle-plan.sh`'s `--force-phases`.
  Each task stops (never falls through to ordinary status-derived classification) once its own
  forced sequence is exhausted for the rest of this run; re-invoke `/orchestrate` to continue.
  Admission is artifact-keyed, not status-keyed (`--plan` always admitted; `--implement` only
  when a plan artifact exists). See `docs/architecture/orchestrate-state-machine.md`'s "Forced
  Phases on a Terminal or Archived Task" and "Dependency Gating Model" sections for the full
  contract.
- No confirmation gates between lifecycle phases.
- Terminates on success, `MAX_CYCLES` exceeded, `MAX_INFRA_FAILURES` exceeded (repeated Agent-tool
  transport/API failures — distinct from work-budget exhaustion), or an unrecoverable blocker.
- A failed task never blocks siblings in its own wave, but DOES block dependents in later waves.

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--lit` | Literature mode: pass lit_flag=true to skill for paper/spec-based tasks | false |
| `--compare` | Advisory-only, lean-implementation-scoped: pass compare_flag=true so the implement-phase dispatch runs the Comparator gate against the snapshot Challenge and the implemented Solution. Never blocks completion or downgrades status. Composable with `--hard` and the model flags; meaningless for research/plan dispatches, so it never reaches them | false |
| `--gate` | Advisory-only intermediate verification tier: pass gate_flag=true so the implement-phase dispatch runs the cheap regex layer lint plus the `Books.Meta` import-closure check between `lake build` and the ten-minute fail-closed full gate. ADVISORY ONLY — it never blocks a dispatch, never fails one, and never downgrades status; it adds a tier rather than relaxing an existing one. Composable with `--hard`, `--lit`, `--compare` and the model flags; meaningless for research/plan dispatches, so it never reaches them | false |
| `--dry-run` | Report-only: run the full admission analysis and print the verdict report; dispatch nothing and mutate nothing. The report also shows any `$2+` focus text this invocation received (a `focus=` column per row), so it can be checked before a live run | false |
| `--allow-self-modifying` | Opt-in, this-invocation-only bypass of the self-modification admission gate; deliberate human intent, never a general-purpose weakening | false |
| `--allow-scope-collision` | Opt-in, this-invocation-only bypass of the CROSS-BATCH `file_scope_collision` gate only (never `in_batch`); deliberate human intent | false |
| `--clean` | Skip automatic memory retrieval | false |
| `--fast` | Low-effort mode: lighter reasoning, AND skips the default research-first phase for a `not_started` task (planner can still route back via `needs_research`); `--research` still forces research even under `--fast`. See `docs/architecture/orchestrate-state-machine.md`'s "The `needs_research` Fork" | false |
| `--hard` | High-effort mode: injects hard-mode contracts (churn/three-strikes/burnout counters); ~3-5x cost; composable with `--lit`, `--compare`, `--gate`, model flags, and the phase-forcing flags | false |
| `--haiku` | Use Haiku model (fastest, lowest cost). Applies to research/plan/implement dispatches only — diagnostic dispatches retain their frontmatter model | false |
| `--sonnet` | Use Sonnet model (balanced cost/quality) | false |
| `--opus` | Use Opus model (highest quality, same as agent default) | false |
| `--fable` | Use Fable model (claude-fable-5) | false |
| `--research` | Force a research round, including on a TERMINAL/archived task; composable with `--plan`/`--implement` in canonical order; never regresses status. See `docs/architecture/orchestrate-state-machine.md`'s "Forced Phases on a Terminal or Archived Task" for the full per-flag contract (admission rules, status preservation, archived-task directory resolution) | false |
| `--plan` | Force a plan round on the same terms as `--research` above. Always admitted: dispatches `reviser-agent` when a plan already exists, `planner-agent` otherwise. See the same doc section | false |
| `--implement` | Force an implement round on the same terms as `--research` above. Admitted only when a plan artifact exists, else blocked with "no plan artifact; run --plan first". See the same doc section | false |

## Anti-Bypass Constraint

**PROHIBITION**: All lifecycle phases (research, plan, implement) MUST be executed by delegating
to `skill-orchestrate` via the Skill tool. Never run research/plan/implement directly from this
command.

## Execution

### STAGE 0: PARSE AND DISPATCH

```bash
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# Exports: TASK_NUMBERS (space-separated), FOCUS_PROMPT, REMAINING_ARGS, DRY_RUN_FLAG,
#          ALLOW_SELF_MODIFYING_FLAG, ALLOW_SCOPE_COLLISION_FLAG,
#          CLEAN_FLAG, EFFORT_FLAG, MODEL_FLAG, FORCE_PHASES_FLAG
focus_prompt="${FOCUS_PROMPT:-}"
```

Belt-and-braces `specs/` bootstrap (idempotent; see `context/standards/orchestrator-runtime-files.md`'s
"Consumer Repo Setup"). `/orchestrate` requires a pre-existing task number and cannot realistically
be a first-touch site, but the call is cheap and never destructive:
```bash
bash .claude/scripts/init-specs.sh
```

Each parsed flag becomes a delegation-context key, threaded unchanged into the single Skill
invocation below — there is only one dispatch path now, used identically whether `TASK_NUMBERS`
names one task or many (see `docs/architecture/orchestrate-state-machine.md`, "The Orchestration
Loop (Batch-of-One and Multi-Task)"). All are **consumer-side-only** — never forwarded to
`orchestrate-batch-admit.sh`:

- `allow_self_modifying` (default `false`) — opt-in bypass of the self-modification gate, this
  invocation only.
- `allow_scope_collision` (default `false`) — opt-in bypass of the CROSS-BATCH
  `file_scope_collision` gate only (never `in_batch`).
- `clean_flag` (default `false`) — suppresses Move 1's automatic memory retrieval
  (`orchestrate-build-dispatch.sh`'s Stage 3.5 Dispatch Prep).
- `effort_flag` (default `""`) / `model_flag` (default `""`, not `null`) — reasoning-depth
  guidance and model-family selection for every lifecycle dispatch.
- `force_phases` (default `""`) — the composable `--research`/`--plan`/`--implement` surface (A2).
  Honored per-task by `orchestrate-cycle-plan.sh`, which seeds each eligible task's own
  `force_phases_remaining` queue from this value and pops one forced phase per cycle until
  exhausted -- at which point the task STOPS for the rest of this run (excluded via a
  `blocked[]` row naming the reason), never falling through to ordinary status-derived
  classification (see that script's header, Section (f)). Admission itself is artifact-keyed,
  not status-keyed: `plan` is always admitted (reviser-agent vs. planner-agent depending on
  whether a plan already exists); `implement` is admitted only when a plan artifact exists.
- `focus_prompt` (default `""`) — the user's own `$2+` text (Arguments section above), applied to
  every task in a multi-task batch. `orchestrate-cycle-plan.sh` composes it with a task's own
  `research_questions` field (neither silently replaces the other) and threads the result into
  every dispatched phase's dispatch file — research, plan AND implement — as a labelled
  `User focus:` block; see that script's `--focus` flag and its header comment for the exact
  composition rule.

**Dry-run short-circuit** (before the dispatch block below runs): `SESSION_ID` is not yet minted
at this point (there is no separate gate-in step any more — see below). This is not a problem:
`orchestrate-cycle-plan.sh` does not require a minted session for its `--dry-run` report — pass
`--session "$SESSION_ID"` when one exists, otherwise omit it (an empty `--session ""` argument
and a fully omitted `--session` are equivalent to the script; both leave it to synthesize an
internal, never-persisted identity under `--dry-run`).

```bash
if [ "${DRY_RUN_FLAG:-false}" = "true" ]; then
  focus_args=(); [ -n "${focus_prompt:-}" ] && focus_args=(--focus "$focus_prompt")
  bash .claude/scripts/orchestrate-cycle-plan.sh --dry-run --session "${SESSION_ID:-}" \
    --state-file specs/state.json ${focus_args[@]+"${focus_args[@]}"} $TASK_NUMBERS
  # STOP HERE.
fi
```

The report's `-- Dispatch --` table now shows the focus text this invocation received (a
`focus=` suffix on each dispatched row whenever `--focus` composed to a non-empty value) — check
it here before committing to a live run.

Note: `--force-phases`/`force_phases` is deliberately still NOT forwarded to this dry-run call
(a known, pre-existing, separate gap — not fixed by this addition). This means a dry-run report
against a forced round does not itself reflect the forcing flag; only `focus_prompt` is
threaded through here.

`orchestrate-cycle-plan.sh --dry-run` runs the IDENTICAL read-only decision pass the live
cycle uses (the same call to `scripts/orchestrate-batch-admit.sh` and
`scripts/orchestrate-triage-classify.sh`), so the printed verdicts match what a live run would
actually dispatch — one rendering of every admission verdict, not a second, independently
maintained one. It prints the plan JSON on stdout and a compact human table on stderr; neither
schema is restated here — see that script's own header comment.

**Dry-run prohibition block**: in dry-run mode this command MUST NOT continue to the dispatch
block below, MUST NOT invoke the Skill or Agent tools, MUST NOT acquire a task lock, and MUST NOT
commit anything — mirroring the Anti-Bypass Constraint above, the STOP HERE is absolute, not
advisory.

**Dispatch** (every invocation, whether `TASK_NUMBERS` names one task or many — there is no
`len(TASK_NUMBERS)` branch here any more; the single-task engine that this command used to fall
through to for a solo task number is deleted, and the block below is the only dispatch path):

```bash
validated_tasks=(); skipped_tasks=()
for task_num in "${TASK_NUMBERS[@]}"; do
  task_data=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num)' specs/state.json)
  if [ -z "$task_data" ]; then
    skipped_tasks+=("$task_num: not found")
    continue
  fi
  status=$(echo "$task_data" | jq -r '.status')
  case "$status" in
    completed|abandoned|expanded)
      skipped_tasks+=("$task_num: terminal status [$status]")
      continue
      ;;
    hold)
      # A THIRD category distinct from terminal above: non-terminal (so this task can still be
      # admitted), yet non-dispatchable by DEFAULT (so ordinary status-derived routing must not
      # reach it). An explicit forcing flag, already parsed into $FORCE_PHASES_FLAG above STAGE 0's
      # top, IS the human lifting the hold for exactly this one dispatch -- admit the task and let
      # orchestrate-cycle-plan.sh's own task_has_forced_phase()/effective_group machinery
      # (unchanged by this feature) take over downstream; it already overrides a status-derived
      # "hold" verdict with zero further change here. Without a forcing flag, skip with a reason
      # distinct from the terminal one above so an operator can tell a pause from a true terminal
      # skip at a glance.
      if [ -n "${FORCE_PHASES_FLAG:-}" ]; then
        validated_tasks+=("$task_num")
        continue
      fi
      hold_reason=$(echo "$task_data" | jq -r '.hold_reason // "no reason recorded"')
      skipped_tasks+=("$task_num: held [$hold_reason]")
      continue
      ;;
  esac
  validated_tasks+=("$task_num")
done
```

Report skipped tasks as warnings. If no validated tasks remain, ABORT with error.

**Pre-Dispatch Review** (advisory-loud, never blocking — the only visibility surface for
out-of-batch/nonexistent `dependencies[]` edges before they are narrowed away below; `--dry-run`
remains the abort-before-dispatch surface for a human who wants the full picture):

```bash
bash .claude/scripts/orchestrate-predispatch-review.sh "${validated_tasks[@]}"
```

Build the intra-batch dependency graph (dependencies on tasks also in `validated_tasks` — the
raw, unfiltered edges were already reviewed above):

```bash
declare -A predecessors
for task_num in "${validated_tasks[@]}"; do
  deps=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .dependencies // [] | .[]' \
    specs/state.json)
  intra_deps=()
  for dep in $deps; do
    [[ " ${validated_tasks[*]} " == *" $dep "* ]] && intra_deps+=("$dep")
  done
  predecessors[$task_num]="${intra_deps[*]}"
done

dep_graph_json=$(jq -n '{}')
for task_num in "${validated_tasks[@]}"; do
  deps_array=$(jq -n --argjson deps "$(printf '%s\n' "${predecessors[$task_num]}" | jq -R . | jq -s .)" '$deps')
  dep_graph_json=$(echo "$dep_graph_json" | jq --arg key "$task_num" --argjson deps "$deps_array" \
    '. + {($key): $deps}')
done
```

**MAX_TASKS Guard** (contract: `orchestrate-state-machine.md`'s `### Batch Size Cap`):

```bash
task_count=${#validated_tasks[@]}
MAX_TASKS=8
if [ "$task_count" -gt "$MAX_TASKS" ]; then
  echo "[orchestrate] WARNING: $task_count tasks exceeds MAX_TASKS=$MAX_TASKS."
  echo "Batching is not yet supported. Running with first $MAX_TASKS tasks only."
  validated_tasks=("${validated_tasks[@]:0:$MAX_TASKS}")
fi
```

`waves` is a **diagnostic echo, not a schedule the engine consumes** — eligibility is re-derived
fresh every cycle from `dependency_graph` inside `orchestrate-cycle-plan.sh`. Passed as one row of
all validated tasks:

```bash
waves_json=$(jq -n --argjson t "$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')" '[$t]')
task_numbers_json=$(printf '%s\n' "${validated_tasks[@]}" | jq -R 'tonumber' | jq -s '.')

source .claude/scripts/lib/common.sh
batch_session_id="$(common_session_id)"
```

Invoke a single `skill-orchestrate` instance with all task context — it manages wave-by-wave
dispatch, per-task postflight, session-registry annotation, and writes results to
`specs/.orchestration/.orchestrator-multi-state-${batch_session_id}.json`:

```
Tool: Skill
Parameters:
  skill: "skill-orchestrate"
  args: "task_numbers={task_numbers_json} waves={waves_json} dependency_graph={dep_graph_json} session_id={batch_session_id} focus_prompt={focus_prompt} lit_flag={LIT_FLAG} allow_self_modifying={ALLOW_SELF_MODIFYING_FLAG} allow_scope_collision={ALLOW_SCOPE_COLLISION_FLAG} clean_flag={CLEAN_FLAG} effort_flag={EFFORT_FLAG} model_flag={MODEL_FLAG} force_phases={FORCE_PHASES_FLAG}"
```

The delegation context passed to the skill must include:
```json
{
  "session_id": "{batch_session_id}",
  "task_numbers": [42, 43, 44],
  "waves": [[42, 43, 44]],
  "dependency_graph": {"42": [], "43": [42], "44": [42]},
  "focus_prompt": "{focus_prompt}",
  "lit_flag": "{LIT_FLAG}",
  "allow_self_modifying": "{ALLOW_SELF_MODIFYING_FLAG}",
  "allow_scope_collision": "{ALLOW_SCOPE_COLLISION_FLAG}",
  "clean_flag": "{CLEAN_FLAG}",
  "effort_flag": "{EFFORT_FLAG}",
  "model_flag": "{MODEL_FLAG}",
  "force_phases": "{FORCE_PHASES_FLAG}"
}
```

The skill emits the consolidated batch output itself (Move 4) — see
`orchestrate-batch-results-template.md`.

**After the Skill invocation returns, STOP.** Every commit (one per task per phase transition) is
issued inside `skill-orchestrate`'s own Move 3 per-task postflight
(`orchestrate-cycle-postflight.sh`) — this command has no separate gate-in/delegate/gate-out/commit
checkpoint sequence of its own any more. The former single-task engine's own CHECKPOINT 1 (GATE
IN) / STAGE 2 (DELEGATE) / CHECKPOINT 2 (GATE OUT) / CHECKPOINT 3 (COMMIT) sequence, reachable only
when a lone task number fell through the pre-rewrite `len(TASK_NUMBERS) == 1` branch, is deleted
along with the single-task `SKILL.md` engine it delegated to — see
`docs/architecture/orchestrate-state-machine.md` for the current design.

## Output

**Completion**: `Orchestration complete for Task #{N}` | Final status: `[COMPLETED]` | Cycles: M/5

**Partial**: `Orchestration paused for Task #{N}` | Status: `[{STATUS}]` | Cycles: M/5 | `Next: /orchestrate {N}`

**Blocked**: `Task #{N} requires manual intervention` | Blocker description | Suggested actions

**System Defects Detected**: rendered only when `metadata.detected_defects` in the task's
`.return-meta.json` is non-empty — on a **Completion** outcome as readily as a **Partial** one,
since a detection is an observation about the agent system, never a verdict on the task
(`/orchestrate --hard` writes the same key from its own postflight metadata merge). Same table shape
as the batch section, for visual consistency:

| Task | Defect Class | Attributed Source Path | Detecting Site | Detail |
|------|--------------|-------------------------|------------------|--------|
| #{N} | HANDOFF_STALE_OR_ABSENT | agent-system/extensions/core/skills/skill-orchestrate/SKILL.md | skill-orchestrate/SKILL.md:cycle-postflight-stale-handoff | handoff mtime predates this dispatch window |
| #{N} | HANDOFF_STALE_OR_ABSENT | agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh | skill-orchestrate/SKILL.md:cycle-postflight-dispatch-seq-mismatch-newer | handoff dispatch_seq is newer than this cycle's minted value |

The two rows above are different directions of the SAME mismatch check, not two different
checks: the first is a handoff genuinely older than this dispatch's own minted identity (a
still-live predecessor's late write), attributed to `skill-orchestrate/SKILL.md` because that
skill only reads the already-minted value back out. The second is a handoff NEWER than what
this cycle minted — composed with a seq this cycle's own mint never produced — attributed
instead to `orchestrate-cycle-plan.sh`, the sole minting site, because this direction is a
composition/minting-side authoring fault, not a stale predecessor artifact.

Operator remedy: fix the named source-store path under `agent-system/extensions/**`; the durable
record is already in `specs/events.jsonl`. No task status was mutated because of these rows.

**`--dry-run`**: the printed admission report only — no status transition, no cycle consumed, no commit. The invocation ends after the report; nothing else in this Output section applies to a `--dry-run` run.

## Error Handling

- **Validation failure**: task not found or terminal — reported as a skipped-task warning; if no
  validated tasks remain, ABORT with error.
- **Dispatch failure**: `orchestrate-cycle-plan.sh`/the Skill invocation keeps the task's current
  status and logs the error; the durable per-task loop guard is preserved for resume.
- **Postflight failure**: `orchestrate-cycle-postflight.sh` warns and continues with whatever
  artifacts are available, rather than blocking the batch.
- **MAX_CYCLES Reached**: report status, provide `/orchestrate {N}` resume instruction
- **MAX_INFRA_FAILURES Reached**: report a connectivity problem distinct from work-budget
  exhaustion (`cycle_count` unaffected), provide `/orchestrate {N}` resume once connectivity is
  confirmed
