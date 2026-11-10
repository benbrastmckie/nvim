#!/usr/bin/env bash
# command-route-agent.sh — Resolve task_type to AGENT_NAME via extension manifest lookup
#
# Sources the shared manifest-routing-lib.sh ladder against routing_agents -- the sole surviving
# routing block since routing_agents_hard was retired (every "--hard dispatches a separate
# domain-specific agent" behavior now runs through hard_contracts' contract-injection mechanism
# instead -- see context/guides/manifest-routing-schema.md). This is the resolver
# skill-orchestrate calls (both effort modes, one engine today), replacing its prior independent
# case tables, directory probes, sed derivations, and — before the standalone hard-mode engine
# was merged in and deleted — that engine's own no-break last-match-wins manifest loop.
#
# USAGE:
#   source .claude/scripts/command-route-agent.sh "$op" "$TASK_TYPE" "$default_agent" "${effort_flag:-}"
#   echo "$AGENT_NAME"  # resolved agent name (no .md suffix)
#
# PARAMETERS:
#   $1 = op             : "research" | "plan" | "implement"
#   $2 = task_type      : TASK_TYPE resolved by the caller (may be simple or compound, e.g.
#                         "founder:deck")
#   $3 = default_agent  : fallback agent name if no manifest declares a routing_agents entry —
#                         e.g., "general-research-agent", "planner-agent",
#                         "general-implementation-agent".
#   $4 = effort_flag    : (optional) "hard" | "fast" | "" | unset. Resolution is now IDENTICAL
#                         for every value of this parameter -- it survives only as a
#                         routing_trace argument (so a trace log can still show which effort mode
#                         a dispatch ran under), never as a second lookup rung. Hard-mode's own
#                         behavioral difference (domain-specific contract injection) is resolved
#                         separately, by hard_contracts via orchestrate-build-dispatch.sh's
#                         Stage 3.5, not by this script.
#
# EXPORTS:
#   AGENT_NAME          : resolved agent name (from extension declaration or default)
#
# EDGE CASES:
#   - No extensions declare a routing_agents entry for this (op, task_type): AGENT_NAME =
#     $default_agent, via="default".
#
# NOTE: This script uses source semantics. It must be sourced (not executed) to export
#       AGENT_NAME to the calling shell environment. It must NEVER call exit — a faulty
#       resolution at worst leaves AGENT_NAME at the caller-supplied default, which is the safe
#       default.

SCRIPT_DIR_ROUTE_AGENT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib/manifest-routing-lib.sh
source "${SCRIPT_DIR_ROUTE_AGENT}/lib/manifest-routing-lib.sh"

_route_op="$1"
_route_task_type="$2"
_route_default_agent="$3"
_route_effort_flag="${4:-}"

routing_lookup "routing_agents" "$_route_op" "$_route_task_type"
if [ -n "$_ROUTE_LAST_VALUE" ]; then
  AGENT_NAME="$_ROUTE_LAST_VALUE"
  _route_via="$_ROUTE_LAST_VIA"
else
  AGENT_NAME="$_route_default_agent"
  _route_via="default"
fi

routing_trace "$_route_op" "$_route_task_type" "$_route_effort_flag" "$AGENT_NAME" "$_route_via" "route-agent"

unset _route_op _route_task_type _route_default_agent _route_effort_flag _route_via SCRIPT_DIR_ROUTE_AGENT

export AGENT_NAME
