#!/usr/bin/env bash
# command-route-agent.sh — Resolve task_type to AGENT_NAME via extension manifest lookup
#
# Sources the shared manifest-routing-lib.sh ladder against routing_agents/routing_agents_hard --
# the sole surviving routing block pair since the routing-ladder collapse retired the parallel
# skill-level routing/routing_hard blocks and their resolver. This is the resolver
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
#                         "general-implementation-agent". skill-orchestrate's one call site
#                         passes the SAME base agent name regardless of effort_flag; there is no
#                         separate "-hard" caller default in practice today (core's own
#                         "-hard"-suffixed agents are deleted). An extension whose
#                         routing_agents_hard block declares its own domain-specific "-hard"
#                         agent (e.g. cslib, lean) is still reached via Steps 1-2 below, not via
#                         this default.
#   $4 = effort_flag    : (optional) "hard" | "fast" | "" | unset
#                         When "hard", resolution runs against routing_agents_hard first, then
#                         falls back to routing_agents, then to $default_agent.
#
# EXPORTS:
#   AGENT_NAME          : resolved agent name (from extension declaration or default)
#
# EDGE CASES:
#   - No extensions declare a routing_agents entry for this (op, task_type): AGENT_NAME =
#     $default_agent.
#   - Hard mode resolves against a three-rung ladder: routing_agents_hard (hit) -> routing_agents
#     (hit, via="hard-miss-standard-fallback") -> $default_agent (via="default"). A hard-mode
#     miss on routing_agents_hard falls back to the extension's own declared standard agent
#     rather than discarding it, so --hard is never LESS specific than standard mode for
#     extensions that declare routing_agents without a routing_agents_hard block. The
#     caller-supplied default is reached only on a genuine total miss of both blocks. In practice
#     this default is always a base agent name (see $3 above); it is never itself a
#     "-hard"-suffixed name today.
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

# Standard-block lookup, computed unconditionally up front so a hard-mode miss on
# routing_agents_hard has an already-resolved standard value to fall back to instead of the
# caller's generic hard default.
routing_lookup "routing_agents" "$_route_op" "$_route_task_type"
_route_std_value="$_ROUTE_LAST_VALUE"
_route_std_via="$_ROUTE_LAST_VIA"

if [ "$_route_effort_flag" = "hard" ]; then
  routing_lookup "routing_agents_hard" "$_route_op" "$_route_task_type"
  if [ -n "$_ROUTE_LAST_VALUE" ]; then
    AGENT_NAME="$_ROUTE_LAST_VALUE"
    _route_via="$_ROUTE_LAST_VIA"
  elif [ -n "$_route_std_value" ]; then
    AGENT_NAME="$_route_std_value"
    _route_via="hard-miss-standard-fallback"
  else
    AGENT_NAME="$_route_default_agent"
    _route_via="default"
  fi
else
  if [ -n "$_route_std_value" ]; then
    AGENT_NAME="$_route_std_value"
    _route_via="$_route_std_via"
  else
    AGENT_NAME="$_route_default_agent"
    _route_via="default"
  fi
fi

routing_trace "$_route_op" "$_route_task_type" "$_route_effort_flag" "$AGENT_NAME" "$_route_via" "route-agent"

unset _route_op _route_task_type _route_default_agent _route_effort_flag _route_std_value _route_std_via _route_via SCRIPT_DIR_ROUTE_AGENT

export AGENT_NAME
