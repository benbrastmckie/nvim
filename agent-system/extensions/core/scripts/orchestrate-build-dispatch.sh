#!/usr/bin/env bash
# orchestrate-build-dispatch.sh — Per-dispatch context file builder for /orchestrate.
#
# Purpose: every dispatch site in skill-orchestrate/SKILL.md (single-task Stage 4 and the
# multi-task MT-4 loops) used to author its own Agent-tool prompt inline: the task description,
# the memory-context block, the literature briefing, the hard-mode contract block, the effort
# note, the plan/report path, and the handoff anchor were all string-interpolated by the lead
# itself. This script is the single canonical replacement: it performs Stage 3.5 (Dispatch Prep)
# in full, gathers every additional per-dispatch input the inline recipes used to interpolate,
# writes `specs/{NNN}_{slug}/.dispatch/{seq}.md`, and prints a one-line JSON return so the calling
# dispatch site's own prompt can shrink to a fixed one-sentence pointer: "Read {dispatch_file}
# first and execute it exactly."
#
# This is a TRANSPORT change only -- it must never change what a dispatched agent receives
# semantically. A generated dispatch file must carry every input the inline recipe it replaces
# would have interpolated.
#
# Precedent / style: follows the doc-header, usage, and exit-code conventions of
# orchestrate-triage-classify.sh and orchestrate-recover-outcome.sh.
#
# Usage:
#   orchestrate-build-dispatch.sh <task_number> <phase> --session SID --seq N
#     [--clean] [--lit] [--compare] [--gate] [--hard] [--fast] [--model M] [--focus "..."]
#     [--territory "..."] [--phase-number N] [--dispatch-start-ts TS] [--allow-terminal]
#
# --allow-terminal: forwarded verbatim as skill_validate_input's 2nd positional argument, so a
# forced /orchestrate dispatch (--research/--plan/--implement on an already-terminal task) can
# reach this script's task-identity resolution instead of hitting skill_validate_input's
# terminal-state exit 1. Absent by default -- only orchestrate-cycle-plan.sh's forced path ever
# passes it (when forced_this_cycle[$t] is true). An ordinary (unforced) dispatch never sees this
# flag and behaves exactly as before.
#
# --compare: advisory-only, lean-implementation-scoped mode hint (see COMPARE_FLAG in
# parse-command-args.sh). Emits a single `- compare_flag: true` line into the written dispatch
# file's `## Identity` section — emitted ONLY when the flag is true, so a no-flag dispatch file
# is byte-identical to one built before this flag existed.
#
# --gate: advisory-only intermediate verification-tier mode hint (see GATE_FLAG in
# parse-command-args.sh). Emits a single `- gate_flag: true` line into the written dispatch
# file's `## Identity` section — emitted ONLY when the flag is true, so a no-flag dispatch file
# is byte-identical to one built before this flag existed, exactly as for --compare above.
# ADVISORY ONLY: the flag never blocks a dispatch, never fails one, and never downgrades status.
# This script is deliberately phase-agnostic about it — it records whatever it is told. Scoping
# `--gate` to implement dispatches is orchestrate-cycle-plan.sh's forwarding guard's job.
#
# Prior Decisions: when `specs/{NNN}_{slug}/.decisions.json` exists and is non-empty (schema in
# docs/architecture/handoff-schema.md's "## Decisions File Schema (.decisions.json)" section),
# emits a "## Prior Decisions" section listing each entry's question/answer/cycle/timestamp, so a
# dispatched agent sees what the lead's batched AskUserQuestion relay already settled. Absent or
# empty file emits nothing — a dispatch built for a task with no .decisions.json stays
# byte-identical to one built before this feature existed.
#
# --phase-number N (implement phase only, hard mode's per-phase dispatch -- Decision Structure H1
# in the task that ported single-task features into the batch engine): records the SINGLE plan
# phase this dispatch is scoped to. Adds a "## Phase Mission" section to the dispatch file naming
# the phase and this task's own phases_completed/phases_total (read from the handoff file, the
# same named-field read the caller's own heading-scan already performs). Optional and absent from
# every base-mode call.
#
# Wait Discipline (external-process-wait + bounded-build-waiter pointers): this script
# unconditionally appends a "## Wait Discipline" pointer to every dispatch file it writes, in
# every phase (research, plan, implement) and mode (base and --hard) -- so a dispatched agent
# receives both the external-process wait discipline (bounded polling; never an unbounded watch,
# no-op filler calls, or a Monitor/background wait that wakes on every unchanged poll) AND the
# local-detached-command bounded-waiter discipline (hard timeout, `kill -0` on a captured PID,
# never `ps | grep`/`pgrep -f`, one waiter per log) independent of which agent contract or
# `hard_contracts` routing it happens to load. This block and "## User-Decision Contract" are
# the two deliberate, permanent exceptions to the byte-identical-when-inactive invariant every
# other section in this file follows -- neither is gated behind an `if`, and neither should be.
#
# --territory "<json>" (the task that carries concurrent-sibling territory into base-mode
# dispatch briefs): NO LONGER hard-mode-only. `orchestrate-cycle-plan.sh`'s per-cycle planner now
# populates this flag for EVERY dispatch a multi-task cycle builds, in EVERY mode, whenever the
# cycle schedules more than one task this same cycle -- carrying a `concurrent_siblings` payload
# (each sibling's task number, phase, declared `file_scope`, an explicit `file`/`coarse`/
# `undeclared` granularity classification, and a generic re-read-before-editing/stage-your-own-
# hunks/no-reverting-snapshot procedural note) alongside, or merged into, whatever hard-mode H1/H7
# owned-files literal that same task may also carry. This script itself only ever renders whatever
# JSON it is given, unchanged, under "## Territory" below -- it never computes or validates the
# payload's shape. The one behavior this script DOES own: the `context/contracts/territory.md`
# pointer is emitted directly inside the "## Territory" block for every case except
# hard_mode=true+phase=implement (the one case where hard_contracts_block's own core_contracts
# list already pulls that same contract in via `<hard-mode-contracts>`), so a base-mode dispatch --
# which never renders `<hard-mode-contracts>` at all -- still gets pointed at the contract that
# governs the JSON it just received. See `## Territory` below and
# `context/contracts/territory.md`'s "Cross-Task Territory (Base Mode)" section.
#
# where <phase> is one of: research | plan | implement
#
# Caller-owned, never generated here (per this task's Non-Goals -- see the plan this script
# implements): `--seq N` (minted by the caller's own dispatch_seq counter, e.g.
# skill_orchestrate_mint_dispatch_seq) and `--dispatch-start-ts` (the caller's own `date -u +%s`
# capture immediately before the Agent tool call). This script only RECORDS both values into the
# dispatch file; it never mints or stamps either one itself.
#
# Output: a single line of compact JSON on stdout:
#   {"dispatch_file": "<absolute path>", "model": "<haiku|sonnet|opus|fable|>"}
# `model` is empty (never the string "null") when --model was not passed.
#
# Exit codes:
#   0 - dispatch file written successfully; JSON printed on stdout
#   1 - task not found in state.json or the archive, or task is in a terminal state and
#       --allow-terminal was not passed (propagated from skill_validate_input, which itself
#       exits 1 in both cases)
#   2 - usage error (missing/invalid arguments)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: orchestrate-build-dispatch.sh <task_number> <phase> --session SID --seq N
         [--clean] [--lit] [--compare] [--gate] [--hard] [--fast] [--model M] [--focus "..."]
         [--territory "..."] [--phase-number N] [--dispatch-start-ts TS] [--allow-terminal]

<phase> is one of: research | plan | implement
USAGE
}

if [ "$#" -lt 2 ]; then
  usage >&2
  exit 2
fi

task_number="$1"; shift
phase="$1"; shift

case "$phase" in
  research|plan|implement) ;;
  *)
    echo "ERROR: orchestrate-build-dispatch.sh: phase must be research|plan|implement, got '$phase'" >&2
    usage >&2
    exit 2
    ;;
esac

session_id=""
dispatch_seq=""
clean_flag="false"
lit_flag="false"
compare_flag="false"
gate_flag="false"
hard_mode="false"
effort_flag=""
model_flag=""
focus_prompt=""
territory=""
dispatch_start_ts=""
phase_number=""
allow_terminal="false"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --seq) dispatch_seq="${2:-}"; shift 2 ;;
    --phase-number) phase_number="${2:-}"; shift 2 ;;
    --clean) clean_flag="true"; shift ;;
    --lit) lit_flag="true"; shift ;;
    --compare) compare_flag="true"; shift ;;
    --gate) gate_flag="true"; shift ;;
    --hard) hard_mode="true"; effort_flag="hard"; shift ;;
    --fast) effort_flag="fast"; shift ;;
    --model) model_flag="${2:-}"; shift 2 ;;
    --focus) focus_prompt="${2:-}"; shift 2 ;;
    --territory) territory="${2:-}"; shift 2 ;;
    --dispatch-start-ts) dispatch_start_ts="${2:-}"; shift 2 ;;
    --allow-terminal) allow_terminal="true"; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: orchestrate-build-dispatch.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$dispatch_seq" ]; then
  echo "ERROR: orchestrate-build-dispatch.sh: --session and --seq are required" >&2
  usage >&2
  exit 2
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "ERROR: orchestrate-build-dispatch.sh: task_number must be numeric, got '$task_number'" >&2
  exit 2
fi

# ─── Task identity: skill-base.sh's skill_validate_input is the single source (no separate
# DESCRIPTION/description case-alias reconciliation needed -- this script IS the source) ───────
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/skill-base.sh"
cd "$SKILL_REPO_ROOT"

skill_validate_input "$task_number" "$allow_terminal"
description="$DESCRIPTION"
task_type="$TASK_TYPE"

handoff_path_abs="${TASK_DIR_ABS}/.orchestrator-handoff.json"

if [ -z "$description" ]; then
  echo "[orchestrate-build-dispatch] WARNING: empty description at dispatch prep (phase=$phase) — memory retrieval and literature briefing will be skipped" >&2
fi

# ─── Artifact round resolution (mirrors SKILL.md's resolve_cycle_artifact_number()) ────────────
case "$phase" in
  research) artifact_mode="current"; artifact_dir="reports/" ;;
  plan)     artifact_mode="prev";    artifact_dir="plans/" ;;
  implement) artifact_mode="prev";   artifact_dir="summaries/" ;;
esac
skill_read_artifact_number "$task_number" "$PADDED_NUM" "$PROJECT_NAME" "$artifact_dir" "$artifact_mode"
# ARTIFACT_NUMBER / ARTIFACT_PADDED now exported by skill_read_artifact_number.

# ─── Phase-specific inputs ──────────────────────────────────────────────────────────────────────
research_artifact=""
existing_plan_path=""
plan_path=""
continuation="null"

if [ "$phase" = "plan" ]; then
  research_artifact=$(jq -r --argjson num "$task_number" \
    '[.active_projects[] | select(.project_number == $num) | .artifacts // [] | .[] | select(.type == "report")] | .[0].path // ""' \
    specs/state.json)
  # Phase 5 (artifact-based admission): a forced --plan round on a task that already has a plan
  # dispatches reviser-agent, which reads `existing_plan_path` (see agents/reviser-agent.md's
  # Stage 1/2) to enter Plan Revision mode rather than Description Update mode. Same
  # `ls | sort -V | tail -1` newest-artifact idiom the implement branch below already uses.
  # Absent plan -> stays "" -> neither line is rendered below -> the ordinary planner-agent path
  # (no prior plan) is byte-for-byte unchanged.
  existing_plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1) || existing_plan_path=""
fi

if [ "$phase" = "implement" ]; then
  plan_path=$(ls -1 "${TASK_DIR}/plans/"*.md 2>/dev/null | sort -V | tail -1) || plan_path=""
  # Shared helper (scripts/lib/continuation-pointer-lib.sh) — the SAME resolution
  # orchestrate-triage-classify.sh's continuation_ok predicate now also calls, collapsing the two
  # previously hand-copied implementations into one.
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/continuation-pointer-lib.sh"
  continuation=$(resolve_continuation_pointer "$handoff_path_abs")

  # phases_completed/phases_total for --phase-number's "## Phase Mission" section below (hard
  # mode's per-phase dispatch only) — the same named-field handoff read single-task Stage 4's H1
  # branch performs before any dispatch. Absent handoff (first cycle) defaults to 0/0, matching
  # that branch's own defaults exactly.
  if [ -n "$phase_number" ]; then
    if [ -f "$handoff_path_abs" ]; then
      phases_completed_for_mission=$(jq -r '.phases_completed // 0' "$handoff_path_abs" 2>/dev/null) || phases_completed_for_mission=0
      phases_total_for_mission=$(jq -r '.phases_total // 0' "$handoff_path_abs" 2>/dev/null) || phases_total_for_mission=0
    else
      phases_completed_for_mission=0
      phases_total_for_mission=0
    fi
  fi
fi

# ─── Stage 3.5 output 1: memory_context (Auto retrieval), skipped when --clean ─────────────────
memory_context=""
if [ "$clean_flag" != "true" ]; then
  memory_arg3=""
  [ "$phase" = "research" ] && memory_arg3="$focus_prompt"
  memory_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/memory-retrieve.sh" "$description" "$task_type" "$memory_arg3" 2>/dev/null) || memory_context=""
fi

# ─── Stage 3.5 output 2: lit_context (headless — orchestrator_mode is always true here, so the
# two interactive directives (PROMPT_NEEDED's interactive branch, and any AskUserQuestion) are
# unreachable by construction; PROMPT_NEEDED itself is handled defensively below even though
# literature-lit-flag-resolve.sh never emits it when --orchestrator-mode true is passed) ────────
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_rationale_file=$(mktemp)
  directive=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/literature-lit-flag-resolve.sh" \
    --lit-flag "true" \
    --orchestrator-mode "true" \
    --query "$description" 2>"$lit_rationale_file") || directive="GLOBAL_MISSING"
  lit_rationale="$(cat "$lit_rationale_file" 2>/dev/null || true)"
  rm -f "$lit_rationale_file"

  case "$directive" in
    LIT_DISABLED)
      lit_context=""
      ;;
    GLOBAL_MISSING)
      echo "[orchestrate-build-dispatch] No literature available this run: no per-repo sub-index and no global Literature index found. ($lit_rationale)" >&2
      lit_context=""
      ;;
    SUBINDEX_PRESENT)
      lit_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/literature-briefing-invoke.sh" --query "$description") || lit_context=""
      ;;
    AUTONOMOUS_GLOBAL|PROMPT_NEEDED)
      lit_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/literature-briefing-invoke.sh" --global "$description") || lit_context=""
      echo "[orchestrate-build-dispatch] [lit:auto] No per-repo sub-index found; autonomous context (orchestrator_mode=true) — running a global-corpus search instead of prompting. ($lit_rationale)" >&2
      ;;
    SPARSE_PROMPT_NEEDED)
      lit_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/literature-briefing-invoke.sh" --query "$description") || lit_context=""
      echo "[orchestrate-build-dispatch] [lit:auto] Per-repo sub-index is sparse or has a topic-scoped coverage delta; autonomous context (orchestrator_mode=true) — proceeding with the existing sub-index rather than prompting. ($lit_rationale)" >&2
      ;;
    *)
      echo "[orchestrate-build-dispatch] WARNING: unrecognized literature directive '$directive'; treating as GLOBAL_MISSING" >&2
      lit_context=""
      ;;
  esac
fi

# ─── Stage 3.5 output 3: effort_note ────────────────────────────────────────────────────────────
effort_note=""
if [ -n "$effort_flag" ]; then
  effort_note="Reasoning-depth guidance: this dispatch runs in --${effort_flag} mode."
fi

# ─── Stage 3.5 output 4: hard_contracts_block (gated on --hard) ────────────────────────────────
hard_contracts_block=""
if [ "$hard_mode" = "true" ]; then
  case "$phase" in
    research) core_contracts=(anti-analysis.md reference-grounding.md adversarial-verification.md) ;;
    plan)     core_contracts=(reference-grounding.md wrap-up.md anti-analysis.md) ;;
    implement)
      core_contracts=(anti-analysis.md wrap-up.md)
      [ -n "$territory" ] && core_contracts+=(territory.md)
      core_contracts+=(recovery.md phase-closure.md pre-edit-gate.md)
      ;;
  esac

  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/lib/manifest-routing-lib.sh"
  routing_lookup_flat "hard_contracts" "$task_type"
  if [ -n "$_ROUTE_LAST_VALUE" ]; then
    while IFS= read -r entry; do
      case "$entry" in
        replace:*)
          core_basename="${entry#replace:}"; core_basename="${core_basename%%:*}"
          override_path="${entry#replace:*:}"
          for i in "${!core_contracts[@]}"; do
            [ "${core_contracts[$i]}" = "$core_basename" ] && core_contracts[i]="$override_path"
          done
          ;;
        *)
          core_contracts+=("$entry")
          ;;
      esac
    done < <(echo "$_ROUTE_LAST_VALUE" | jq -r '.[]')
  fi

  hard_contracts_block="<hard-mode-contracts>"$'\n'
  for c in "${core_contracts[@]}"; do
    hard_contracts_block+="- context/contracts/${c}"$'\n'
  done
  hard_contracts_block+="</hard-mode-contracts>"
fi

# ─── Stage 3.5 output 5: deploy_freshness_context — surfaces the SAME per-extension, path-scoped
# staleness signal skill-base.sh's skill_preflight_update already emits to stderr at dispatch
# preflight (see that function's own comment block), but placed where the SPAWNED agent actually
# reads it: inside the dispatch file itself. Reuses skill_deploy_freshness_stale_names (defined
# by skill-base.sh, already sourced above at this script's own top) rather than re-deriving the
# deploy-freshness-lib.sh call a second time. Degrades to an empty string on every failure mode
# (library not resolvable, no .claude-extensions.json, missing jq/git, or a genuinely clean
# tree) exactly like that function's own contract, so a build with nothing stale produces a
# dispatch file byte-identical to one built before this feature existed — no block is emitted
# for an empty list, matching the memory_context/lit_context/hard_contracts_block precedent
# immediately above.
deploy_freshness_context=""
_stale_ext_names="$(skill_deploy_freshness_stale_names 2>/dev/null || true)"
if [ -n "$_stale_ext_names" ]; then
  _stale_ext_names_line="$(echo "$_stale_ext_names" | tr '\n' ' ' | sed 's/ *$//')"
  deploy_freshness_context="<deploy-freshness-context>"$'\n'
  deploy_freshness_context+="This repo's deployed .claude/ tree is STALE relative to the source store (agent-system/extensions/) for the following extension(s): ${_stale_ext_names_line}."$'\n'
  deploy_freshness_context+="Documented commands and instructions sourced from those extensions' deployed files may be out of date. Verify against the source store before relying on a command or instruction from a stale extension's deployed copy."$'\n'
  deploy_freshness_context+="A fresh-looking file elsewhere in this SAME deployed tree does NOT mean the tree is current — staleness here is per-extension, not whole-tree; a different extension can be stale even when the one you happened to check is not."$'\n'
  deploy_freshness_context+="Remedy: redeploy via 'bash .claude/scripts/deploy-headless.sh'. Do NOT hand-patch any file under .claude/** as a substitute — that would mask this divergence instead of fixing it."$'\n'
  deploy_freshness_context+="</deploy-freshness-context>"
fi

# ─── Stage 3.5 output 6: lean_readiness_context — the lean extension's language-server
# readiness probe (lean-mcp-preflight-check.sh --dispatch-block), called UNCONDITIONALLY here
# rather than gated on task_type. This is deliberate: a per-extension manifest hooks.preflight
# registration is resolved by task_type, so it structurally cannot reach a Lean project whose
# task_type is declared by a DIFFERENT extension (e.g. "formal") — the exact gap that let a
# dispatch proceed against an unreachable language server with no warning. The probe gates
# itself on its own lakefile detection (not on task_type), so calling it here reaches every
# Lean project regardless of which extension's task_type the task carries. Absent-safe (a
# deploy predating the lean extension, or a non-Lean repo, both produce empty output) and
# failure-degrades-to-empty exactly like memory_context/lit_context/deploy_freshness_context
# above, so a non-Lean dispatch build stays byte-identical to one built before this feature
# existed — no block is emitted for empty output.
#
# Measured added wall-clock cost of a dispatch build in THIS (non-Lean) repo, 5-run means,
# `date +%s%N` deltas around the whole script invocation: ~65ms before this call existed,
# ~65ms after (no measurable delta — the `[ -x ... ]` guard below short-circuits before any
# process is spawned when the probe script is absent, which is this repo's own case since it
# carries no lakefile).
lean_readiness_context=""
if [ -x "${SKILL_REPO_ROOT}/.claude/scripts/lean-mcp-preflight-check.sh" ]; then
  lean_readiness_context=$(bash "${SKILL_REPO_ROOT}/.claude/scripts/lean-mcp-preflight-check.sh" --dispatch-block 2>/dev/null) || lean_readiness_context=""
fi

# ─── model resolution: pass-through, empty (never "null") when unset ───────────────────────────
model="$model_flag"

# ─── Prior decisions read path: specs/{NNN}_{slug}/.decisions.json (schema in
# docs/architecture/handoff-schema.md's "## Decisions File Schema (.decisions.json)" section) ───
# Byte-identical-when-absent: prior_decisions_block stays empty (and no section is emitted) when
# the file is absent or empty, matching the --compare flag's own no-flag-no-change precedent.
prior_decisions_block=""
decisions_file="${TASK_DIR_ABS}/.decisions.json"
if [ -f "$decisions_file" ]; then
  decisions_content=$(cat "$decisions_file" 2>/dev/null) || decisions_content="[]"
  decisions_count=$(echo "$decisions_content" | jq 'length' 2>/dev/null) || decisions_count=0
  if [ "$decisions_count" -gt 0 ]; then
    prior_decisions_block=$(echo "$decisions_content" | jq -r \
      '.[] | "- Question: \(.question)\n  Answer: \(.answer)\n  Answered in cycle \(.cycle) at \(.timestamp)"')
  fi
fi

# ─── Write specs/{NNN}_{slug}/.dispatch/{seq}.md ────────────────────────────────────────────────
dispatch_dir="${TASK_DIR_ABS}/.dispatch"
mkdir -p "$dispatch_dir"
dispatch_file="${dispatch_dir}/${dispatch_seq}.md"

{
  echo "# Dispatch Context: Task ${task_number}, phase=${phase}"
  echo ""
  echo "Generated by scripts/orchestrate-build-dispatch.sh — never hand-edit. Read this file in"
  echo "full before doing anything else; it names every input, output path, and contract this"
  echo "one dispatch carries."
  echo ""
  echo "## Identity"
  echo ""
  echo "- task_number: ${task_number}"
  echo "- phase: ${phase}"
  echo "- task_type: ${task_type}"
  echo "- session_id: ${session_id}"
  echo "- dispatch_seq: ${dispatch_seq}"
  if [ -n "$dispatch_start_ts" ]; then
    echo "- dispatch_start_ts: ${dispatch_start_ts}"
  fi
  if [ "$compare_flag" = "true" ]; then
    echo "- compare_flag: true"
  fi
  if [ "$gate_flag" = "true" ]; then
    echo "- gate_flag: true"
  fi
  echo ""
  echo "## Description"
  echo ""
  echo "${description}"
  if [ -n "$focus_prompt" ]; then
    echo ""
    echo "User focus: ${focus_prompt}"
  fi
  echo ""
  echo "## Artifact Round"
  echo ""
  echo "- artifact_number: ${ARTIFACT_NUMBER}"
  echo "- artifact_padded: ${ARTIFACT_PADDED}"
  echo "- output_dir: ${TASK_DIR}/${artifact_dir}"
  echo ""
  if [ "$phase" = "plan" ]; then
    echo "## Research Artifact"
    echo ""
    echo "- research_artifact: ${research_artifact}"
    echo ""
    if [ -n "$existing_plan_path" ]; then
      echo "## Prior Plan"
      echo ""
      echo "- existing_plan_path: ${existing_plan_path}"
      echo "- revision_reason: forced --plan round"
      echo ""
    fi
  fi
  if [ "$phase" = "implement" ]; then
    echo "## Plan"
    echo ""
    echo "- plan_path: ${plan_path}"
    echo ""
    echo "## Continuation"
    echo ""
    echo '```json'
    echo "${continuation}"
    echo '```'
    echo ""
    if [ -n "$phase_number" ]; then
      # Hard mode's per-phase dispatch (H1) — ported from single-task Stage 4's
      # build_hard_mode_phase_mission(). Deliberately does NOT restate anti-analysis, wrap-up,
      # recovery, phase-closure, or pre-edit-gate -- hard_contracts_block (below) already injects
      # all of those as <hard-mode-contracts> entries; this section carries only the genuinely
      # per-cycle residue (which phase, and the running phase count).
      echo "## Phase Mission"
      echo ""
      echo "HARD MODE DISPATCH — PHASE MISSION:"
      echo ""
      echo "1. Mission: Implement phase ${phase_number} only. Do not continue past this phase."
      echo "2. Settled Design Preamble: State the decided design before first tool call."
      echo ""
      echo "PHASES COMPLETED: ${phases_completed_for_mission} of ${phases_total_for_mission}"
      echo ""
    fi
  fi
  echo "## Handoff"
  echo ""
  echo "- handoff_path: ${handoff_path_abs}"
  echo "- task_dir: ${TASK_DIR_ABS}"
  echo ""
  if [ -n "$territory" ]; then
    echo "## Territory"
    echo ""
    echo '```json'
    echo "${territory}"
    echo '```'
    echo ""
    # Base-mode / non-implement-hard-mode contract pointer (the task that carries
    # concurrent-sibling territory into base-mode dispatch briefs): the ONLY case where the
    # territory contract is already pulled in elsewhere is hard_mode=true AND phase=implement --
    # the sole combination where hard_contracts_block's core_contracts list below conditionally
    # appends territory.md (see the `[ -n "$territory" ] && core_contracts+=(territory.md)` line
    # in the implement branch below). Every other case that reaches this block (base mode in any
    # phase, or hard mode's research/plan phases) never sees <hard-mode-contracts> at all, so
    # without this pointer a base-mode agent would receive the "## Territory" JSON with no
    # instruction to read the contract governing it. This is a separate branch, never a reuse of
    # core_contracts/<hard-mode-contracts> -- base mode must not be routed through hard mode's
    # contract machinery just to receive this one pointer line.
    if ! { [ "$hard_mode" = "true" ] && [ "$phase" = "implement" ]; }; then
      echo "Read context/contracts/territory.md (Cross-Task Territory section) before editing any file."
      echo ""
    fi
  fi
  if [ -n "$memory_context" ]; then
    echo "$memory_context"
    echo ""
  fi
  if [ -n "$lit_context" ]; then
    echo "$lit_context"
    echo ""
  fi
  if [ -n "$effort_note" ]; then
    echo "$effort_note"
    echo ""
  fi
  if [ -n "$hard_contracts_block" ]; then
    echo "$hard_contracts_block"
    echo ""
  fi
  if [ -n "$deploy_freshness_context" ]; then
    echo "$deploy_freshness_context"
    echo ""
  fi
  if [ -n "$lean_readiness_context" ]; then
    echo "$lean_readiness_context"
    echo ""
  fi
  if [ -n "$prior_decisions_block" ]; then
    echo "## Prior Decisions"
    echo ""
    echo "Answers relayed from a prior cycle's batched \`AskUserQuestion\` call (see"
    echo "\`specs/${PADDED_NUM}_${PROJECT_NAME}/.decisions.json\`). Treat these as settled — do not"
    echo "re-ask a question already answered here."
    echo ""
    echo "$prior_decisions_block"
    echo ""
  fi
  echo "## Wait Discipline"
  echo ""
  echo "Read context/patterns/external-process-wait.md before waiting on any long-running external"
  echo "or remote process (e.g. a CI run) — bounded polling only; never an unbounded watch, no-op"
  echo "filler calls, or a Monitor/background wait that wakes you on every unchanged poll."
  echo ""
  echo "For a detached local command instead (a build, gate, or test run you backgrounded), read"
  echo "context/patterns/bounded-build-waiter.md: a hard timeout, writer liveness via \`kill -0\`"
  echo "on the captured PID, never \`ps | grep\` or \`pgrep -f\`, and one waiter per log."
  echo ""
  echo "## User-Decision Contract"
  echo ""
  echo "See \`context/standards/user-decision-contract.md\` for the full contract — when to set"
  echo "\`user_decision\` on \`.return-meta.json\`, the blocking/non-blocking distinction, and how"
  echo "postflight relays it. Set it only when a choice genuinely requires the user's judgment"
  echo "(a preference the artifacts cannot infer, an external cost or risk the user must accept,"
  echo "or an ambiguity research cannot resolve) — never as a routine field."
} > "$dispatch_file"

jq -n -c --arg dispatch_file "$dispatch_file" --arg model "$model" \
  '{dispatch_file: $dispatch_file, model: $model}'
