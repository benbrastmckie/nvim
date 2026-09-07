#!/usr/bin/env bash
# orchestrate-build-aux-dispatch.sh — Per-aux-dispatch context file builder for the batch
# /orchestrate engine (originating plan's Decision 2, item 4 AUXILIARY DISPATCHES).
#
# Purpose: single-task Stage 5a (Drift Inspection), Stage 5b's H5 three-strikes divergence-audit
# dispatch, and Stage 6 (Blocker Escalation)'s research-fork/plan-revision steps each used to
# author their own inline Agent-tool prompt. This script is their batch-engine replacement for
# FOUR fixed-agent, non-task-type-routed dispatch kinds: writes
# `specs/{NNN}_{slug}/.dispatch/{seq}-aux-{kind}.md` carrying the kind's prompt content and the
# same "read your dispatch file first" pointer convention orchestrate-build-dispatch.sh uses, and
# prints `{dispatch_file, agent, model}` so the caller (orchestrate-cycle-plan.sh) can build an
# `aux_dispatch[]` row without knowing any prompt text itself.
#
# Deliberately NEVER calls orchestrate-build-dispatch.sh, memory-retrieve.sh,
# literature-lit-flag-resolve.sh/literature-briefing-invoke.sh, or command-route-agent.sh — an aux
# dispatch's agent is fixed by KIND, chosen by the emitting logic below, never task-type-resolved
# (Decision 2's own MUST NOT). `model` is read from the resolved agent's OWN frontmatter `model:`
# field (searched across every `agent-system/extensions/*/agents/<agent>.md`), never from
# `--model`/effort routing — empty (not the literal string "null") when the agent file is absent
# (e.g. "fork", a harness built-in with no agent file in this repo) or declares no `model:` line.
#
# Fixed agent per kind (never task-type-routed):
#   drift-inspection  -> fork
#   blocker-research  -> fork
#   plan-revision     -> reviser-agent
#   divergence-audit  -> the task's OWN research agent, passed in verbatim via --research-agent
#                        (the caller's own already-resolved mt_json.research_agents[t], or its
#                        "general-research-agent" default — never re-resolved here)
#
# Usage:
#   orchestrate-build-aux-dispatch.sh <task_number> <kind> --session SID --seq N
#     [--dispatch-start-ts TS]
#     # drift-inspection:
#     --plan-path PATH
#     # blocker-research:
#     --blocker-desc "..."
#     # plan-revision (exactly one reason):
#     --revision-reason blocker --blocker-desc "..." --findings-summary "..." --plan-path PATH
#     --revision-reason drift --drift-pct N --drift-summary "..." --plan-path PATH
#     # divergence-audit:
#     --target "..." --verbatim-goal "..." --research-agent NAME
#
# Output: a single line of compact JSON on stdout:
#   {"dispatch_file": "<absolute path>", "agent": "<fixed agent name>", "model": "<model|>"}
# `model` is empty (never the string "null") when the resolved agent declares none.
#
# Exit codes:
#   0 - dispatch file written successfully; JSON printed on stdout
#   1 - task not found in state.json, or task is in a terminal state (propagated from
#       skill_validate_input)
#   2 - usage error (missing/invalid arguments, unrecognized kind)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: orchestrate-build-aux-dispatch.sh <task_number> <kind> --session SID --seq N
         [--dispatch-start-ts TS] [--plan-path PATH] [--blocker-desc "..."]
         [--revision-reason blocker|drift] [--findings-summary "..."]
         [--drift-pct N] [--drift-summary "..."] [--target "..."] [--verbatim-goal "..."]
         [--research-agent NAME]

<kind> is one of: drift-inspection | blocker-research | plan-revision | divergence-audit
USAGE
}

if [ "$#" -lt 2 ]; then
  usage >&2
  exit 2
fi

task_number="$1"; shift
kind="$1"; shift

case "$kind" in
  drift-inspection|blocker-research|plan-revision|divergence-audit) ;;
  *)
    echo "ERROR: orchestrate-build-aux-dispatch.sh: kind must be drift-inspection|blocker-research|plan-revision|divergence-audit, got '$kind'" >&2
    usage >&2
    exit 2
    ;;
esac

session_id=""
dispatch_seq=""
dispatch_start_ts=""
plan_path=""
blocker_desc=""
revision_reason=""
findings_summary=""
drift_pct=""
drift_summary=""
target=""
verbatim_goal=""
research_agent=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --seq) dispatch_seq="${2:-}"; shift 2 ;;
    --dispatch-start-ts) dispatch_start_ts="${2:-}"; shift 2 ;;
    --plan-path) plan_path="${2:-}"; shift 2 ;;
    --blocker-desc) blocker_desc="${2:-}"; shift 2 ;;
    --revision-reason) revision_reason="${2:-}"; shift 2 ;;
    --findings-summary) findings_summary="${2:-}"; shift 2 ;;
    --drift-pct) drift_pct="${2:-}"; shift 2 ;;
    --drift-summary) drift_summary="${2:-}"; shift 2 ;;
    --target) target="${2:-}"; shift 2 ;;
    --verbatim-goal) verbatim_goal="${2:-}"; shift 2 ;;
    --research-agent) research_agent="${2:-}"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: orchestrate-build-aux-dispatch.sh: unrecognized argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$session_id" ] || [ -z "$dispatch_seq" ]; then
  echo "ERROR: orchestrate-build-aux-dispatch.sh: --session and --seq are required" >&2
  usage >&2
  exit 2
fi

if ! [[ "$task_number" =~ ^[0-9]+$ ]]; then
  echo "ERROR: orchestrate-build-aux-dispatch.sh: task_number must be numeric, got '$task_number'" >&2
  exit 2
fi

if [ "$kind" = "plan-revision" ]; then
  case "$revision_reason" in
    blocker|drift) ;;
    *)
      echo "ERROR: orchestrate-build-aux-dispatch.sh: kind=plan-revision requires --revision-reason blocker|drift, got '$revision_reason'" >&2
      exit 2
      ;;
  esac
fi

# ─── Task identity: skill-base.sh's skill_validate_input is the single source, mirroring
# orchestrate-build-dispatch.sh's own precedent exactly ────────────────────────────────────────
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/skill-base.sh"
cd "$SKILL_REPO_ROOT"

skill_validate_input "$task_number"
description="$DESCRIPTION"

# ─── Fixed agent per kind (never task-type-routed — Decision 2's own MUST NOT) ──────────────────
case "$kind" in
  drift-inspection|blocker-research) agent="fork" ;;
  plan-revision) agent="reviser-agent" ;;
  divergence-audit) agent="${research_agent:-general-research-agent}" ;;
esac

# ─── Model resolution: the resolved agent's OWN frontmatter `model:` line, never --model/effort
# routing. "fork" is a harness built-in with no agent file anywhere in this repo, so it correctly
# falls through to empty (never the literal string "null"). ────────────────────────────────────
model=""
agent_file=""
for candidate in "$EXT_ROOT"/*/agents/"${agent}.md"; do
  if [ -f "$candidate" ]; then
    agent_file="$candidate"
    break
  fi
done
if [ -n "$agent_file" ]; then
  model=$(grep -m1 -E '^model:[[:space:]]*' "$agent_file" 2>/dev/null | sed -E 's/^model:[[:space:]]*//; s/[[:space:]]+$//') || model=""
fi

# ─── Build the kind-specific prompt, ported verbatim from single-task Stage 5a/5b/6's own prose
# (see skill-orchestrate/SKILL.md), with ONE deliberate departure per Decision 2: blocker-research
# instructs the fork to WRITE ${TASK_DIR}/.blocker-research.json rather than relying on the fork's
# own returned text (single-task Stage 6 Step 3's channel), since the thin lead here never reads
# prose — it only reads a JSON file back, mirroring Stage 5a's own .drift-inspection.json
# convention. ─────────────────────────────────────────────────────────────────────────────────
prompt=""
case "$kind" in
  drift-inspection)
    prompt="Read the plan file at '${plan_path}'. Count: (1) total checklist items matching '- [ ]' or '- [x]', (2) completed items matching '- [x]', (3) deviation annotations matching '*(deviation:'. Calculate drift_pct as: deviation_count / max(total_items, 1). Write compact JSON to '${TASK_DIR_ABS}/.drift-inspection.json' with fields: drift_pct (float), deviation_count (int), total_items (int), completed_items (int), summary (string, one sentence). Return a brief summary of findings."
    ;;
  blocker-research)
    prompt="Research this specific blocker for task ${task_number}: ${blocker_desc}. Find the root cause and a concrete solution path. Write compact JSON to '${TASK_DIR_ABS}/.blocker-research.json' with fields: summary (string), root_cause (string), solution_path (string)."
    ;;
  plan-revision)
    if [ "$revision_reason" = "blocker" ]; then
      prompt="Revise the implementation plan for task ${task_number} to address this blocker: ${blocker_desc}. Research findings: ${findings_summary}"
    else
      prompt="Revise the implementation plan for task ${task_number} to address plan drift (drift_pct=${drift_pct}). Summary: ${drift_summary}"
    fi
    ;;
  divergence-audit)
    prompt="DIVERGENCE AUDIT for task ${task_number}. Target: '${target}'. Verbatim goal: '${verbatim_goal}'. This target has failed 3 times. Identify root cause of repeated failure. Write a divergence table, postmortem, and corrected target definition."
    ;;
esac

# ─── Write specs/{NNN}_{slug}/.dispatch/{seq}-aux-{kind}.md ────────────────────────────────────
dispatch_dir="${TASK_DIR_ABS}/.dispatch"
mkdir -p "$dispatch_dir"
dispatch_file="${dispatch_dir}/${dispatch_seq}-aux-${kind}.md"

{
  echo "# Aux Dispatch Context: Task ${task_number}, kind=${kind}"
  echo ""
  echo "Generated by scripts/orchestrate-build-aux-dispatch.sh — never hand-edit. Read this file"
  echo "in full before doing anything else; it names every input, output path, and contract this"
  echo "one dispatch carries."
  echo ""
  echo "This is an AUXILIARY dispatch: it is never postflighted by"
  echo "orchestrate-cycle-postflight.sh and never contributes to failed_tasks. It runs with"
  echo "orchestrator_mode: false — write no \`.orchestrator-handoff.json\`; return findings as your"
  echo "own text, or as the specific JSON file this dispatch names below, per its own kind."
  echo ""
  echo "## Identity"
  echo ""
  echo "- task_number: ${task_number}"
  echo "- kind: ${kind}"
  echo "- agent: ${agent}"
  echo "- session_id: ${session_id}"
  echo "- dispatch_seq: ${dispatch_seq}"
  if [ -n "$dispatch_start_ts" ]; then
    echo "- dispatch_start_ts: ${dispatch_start_ts}"
  fi
  echo ""
  echo "## Description"
  echo ""
  echo "${description}"
  echo ""
  echo "## Prompt"
  echo ""
  echo "${prompt}"
  echo ""
  echo "## Task Directory"
  echo ""
  echo "- task_dir: ${TASK_DIR_ABS}"
  if [ -n "$plan_path" ]; then
    echo "- plan_path: ${plan_path}"
  fi
  echo ""
} > "$dispatch_file"

jq -n -c --arg dispatch_file "$dispatch_file" --arg agent "$agent" --arg model "$model" \
  '{dispatch_file: $dispatch_file, agent: $agent, model: $model}'
