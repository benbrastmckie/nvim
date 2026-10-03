#!/usr/bin/env bash
# manifest-routing-lib.sh - Single source of truth for the manifest routing ladder.
#
# Sourced (never executed) by command-route-agent.sh, and by lint-routing-wiring.sh /
# test-routing-resolution.sh for validation. Implements the one five-step first-match-wins
# precedence ladder every routing consumer now shares:
#   1. non-core extension manifest, exact task_type match
#   2. non-core extension manifest, compound-base task_type match (task_type contains ":")
#   3. core extension manifest, exact task_type match
#   4. core extension manifest, compound-base task_type match
#   5. no match -> empty output (never an error)
#
# "Non-core" here means "not the manifest whose .name == 'core'" -- see routing_core_manifest()
# below. This is a narrower exclusion than routing_exempt:true (which also covers `literature`
# and `slidev`): those two extensions never declare `.routing_agents`/`.routing_agents_hard`
# entries of their own, so treating them as ordinary non-core participants in Steps 1-2 produces
# identical resolution to the prior per-consumer implementations, while giving core-identification
# a single unambiguous meaning independent of the exemption field's separately-scoped semantics.
#
# CONTRACT (verified by this library's own sourcing callers at Phase 1 of the routing
# consolidation task):
#   - Never calls `exit` -- a faulty resolution at worst leaves the caller's SKILL_NAME/AGENT_NAME
#     at its own safe default; this library only ever returns 0.
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this file
#     must never change the calling shell's error-handling behavior.
#   - Every internal variable is prefixed `_route_` and is explicitly unset before each function
#     returns (on top of already being `local`), so sourcing this file never leaks state into the
#     calling shell's environment.
#   - A miss is signalled by empty stdout, never by a non-zero exit status -- every function below
#     always returns 0, on both hit and miss.
#
# Manifest source: `${ROUTE_MANIFEST_ROOT:-.claude}/extensions/*/manifest.json`. Every live
# routing consumer (command-route-agent.sh, the orchestrate skills) runs with the default unset,
# resolving against `.claude/extensions/*/manifest.json` -- the DEPLOYED
# tree, matching every existing consumer this library replaces, not the
# agent-system/extensions/** source store. Callers run post-deploy, from a working directory at
# the repo root.
#
# Validation-only callers (lint-routing-wiring.sh, test-routing-resolution.sh) instead set
# `ROUTE_MANIFEST_ROOT=agent-system` before sourcing, so the exact same ladder validates the
# SOURCE STORE pre-deploy -- both roots share the identical `<root>/extensions/*/manifest.json`
# shape, so no other code path changes. This is the one configuration knob this library exposes;
# it changes WHERE manifests are read from, never the ladder's precedence logic.
#
# Usage:
#   source .claude/scripts/lib/manifest-routing-lib.sh
#   manifest=$(routing_core_manifest)
#   routing_lookup "routing_agents" "research" "general"
#   value="$_ROUTE_LAST_VALUE"                   # resolved value, or empty on a miss
#   via="$_ROUTE_LAST_VIA"                        # noncore-exact|noncore-compound|core-exact|core-compound|miss
#   routing_trace "research" "epi" "" "$value" "$via"
#   routing_lookup_flat "hard_contracts" "general"
#
# routing_lookup is called DIRECTLY (never via `$(routing_lookup ...)` command substitution) --
# command substitution forks a subshell, and a subshell's variable assignments never propagate
# back to the caller, which would silently strand both of routing_lookup's outputs. Read its
# result from $_ROUTE_LAST_VALUE / $_ROUTE_LAST_VIA immediately after the call, the same way
# AGENT_NAME is read as a plain (non-subshelled) variable today. `routing_core_manifest` has no
# second output to strand, so it remains an ordinary echo-and-capture function.

# routing_core_manifest -- echoes the path to the manifest whose .name == "core", or empty.
# Replaces the old routing_exempt:true-based identification (Defect 4): routing_exempt is not
# unique to core (literature and slidev also set it), but .name is guaranteed unique.
routing_core_manifest() {
  local _route_manifest _route_name
  for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
    [ -f "$_route_manifest" ] || continue
    _route_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
    if [ "$_route_name" = "core" ]; then
      echo "$_route_manifest"
      unset _route_manifest _route_name
      return 0
    fi
  done
  unset _route_manifest _route_name
  return 0
}

# routing_lookup -- the shared five-step ladder against $1=block ("routing_agents" or
# "routing_agents_hard"), $2=op, $3=task_type.
#
# Outputs (both intentional external-facing globals, deliberately NOT unset before return, unlike
# the _route_-prefixed internals below): $_ROUTE_LAST_VALUE (the resolved value, or empty on a
# total miss) and $_ROUTE_LAST_VIA (one of noncore-exact|noncore-compound|core-exact|
# core-compound|miss). Must be called directly, never as `$(routing_lookup ...)` -- see the
# Usage note above for why.
routing_lookup() {
  local _route_block="$1"
  local _route_op="$2"
  local _route_task_type="$3"
  local _route_manifest _route_value _route_name _route_base _route_core_manifest

  _ROUTE_LAST_VALUE=""
  _ROUTE_LAST_VIA="miss"

  # Step 1 -- non-core, exact match
  for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
    [ -f "$_route_manifest" ] || continue
    _route_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
    [ "$_route_name" = "core" ] && continue
    _route_value=$(jq -r --arg b "$_route_block" --arg op "$_route_op" --arg tt "$_route_task_type" \
      '(.[$b] // {})[$op][$tt] // empty' "$_route_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="noncore-exact"
      unset _route_block _route_op _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  done

  # Step 2 -- non-core, compound-base match
  if printf '%s' "$_route_task_type" | grep -q ":"; then
    _route_base=$(printf '%s' "$_route_task_type" | cut -d: -f1)
    for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
      [ -f "$_route_manifest" ] || continue
      _route_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
      [ "$_route_name" = "core" ] && continue
      _route_value=$(jq -r --arg b "$_route_block" --arg op "$_route_op" --arg tt "$_route_base" \
        '(.[$b] // {})[$op][$tt] // empty' "$_route_manifest" 2>/dev/null)
      if [ -n "$_route_value" ]; then
        _ROUTE_LAST_VALUE="$_route_value"
        _ROUTE_LAST_VIA="noncore-compound"
        unset _route_block _route_op _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
        return 0
      fi
    done
  fi

  # Step 3 -- core, exact match
  _route_core_manifest=$(routing_core_manifest)
  if [ -n "$_route_core_manifest" ]; then
    _route_value=$(jq -r --arg b "$_route_block" --arg op "$_route_op" --arg tt "$_route_task_type" \
      '(.[$b] // {})[$op][$tt] // empty' "$_route_core_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="core-exact"
      unset _route_block _route_op _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  fi

  # Step 4 -- core, compound-base match
  if [ -n "$_route_core_manifest" ] && printf '%s' "$_route_task_type" | grep -q ":"; then
    _route_base=$(printf '%s' "$_route_task_type" | cut -d: -f1)
    _route_value=$(jq -r --arg b "$_route_block" --arg op "$_route_op" --arg tt "$_route_base" \
      '(.[$b] // {})[$op][$tt] // empty' "$_route_core_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="core-compound"
      unset _route_block _route_op _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  fi

  # Step 5 -- total miss ($_ROUTE_LAST_VALUE stays "", $_ROUTE_LAST_VIA stays "miss")
  unset _route_block _route_op _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
  return 0
}

# routing_lookup_flat -- a SIBLING ladder for one-level manifest blocks shaped
# `{task_type: [...]}`, e.g. the `hard_contracts` block: `$1`=block, `$2`=task_type. This is
# deliberately NOT a wrapper over routing_lookup() with a fabricated `$op` key: routing_lookup's
# four-argument jq path (`.[$b][$op][$tt]`) assumes a TWO-level block (`{op: {task_type: value}}`)
# and a fake `$op` would silently coerce a one-level block into that two-level shape, corrupting
# resolution the moment a manifest actually declares one. Keep this function's jq path
# one-level (`.[$b][$tt]`) and do not "simplify" it into a call to routing_lookup().
#
# Same 4-step first-match-wins precedence as routing_lookup(): non-core exact -> non-core
# compound-base -> core exact -> core compound-base -> miss (empty output, return 0). Uses
# `jq -c`, not `-r`, because the resolved value here is a JSON array, not a scalar.
#
# Outputs: $_ROUTE_LAST_VALUE (the resolved JSON array as a compact string, or empty on a total
# miss) and $_ROUTE_LAST_VIA (one of noncore-exact|noncore-compound|core-exact|core-compound|
# miss) -- same two globals routing_lookup() sets, on the same terms. Must be called directly,
# never as `$(routing_lookup_flat ...)` -- see the Usage note above for why.
routing_lookup_flat() {
  local _route_block="$1"
  local _route_task_type="$2"
  local _route_manifest _route_value _route_name _route_base _route_core_manifest

  _ROUTE_LAST_VALUE=""
  _ROUTE_LAST_VIA="miss"

  # Step 1 -- non-core, exact match
  for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
    [ -f "$_route_manifest" ] || continue
    _route_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
    [ "$_route_name" = "core" ] && continue
    _route_value=$(jq -c --arg b "$_route_block" --arg tt "$_route_task_type" \
      '(.[$b] // {})[$tt] // empty' "$_route_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="noncore-exact"
      unset _route_block _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  done

  # Step 2 -- non-core, compound-base match
  if printf '%s' "$_route_task_type" | grep -q ":"; then
    _route_base=$(printf '%s' "$_route_task_type" | cut -d: -f1)
    for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
      [ -f "$_route_manifest" ] || continue
      _route_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
      [ "$_route_name" = "core" ] && continue
      _route_value=$(jq -c --arg b "$_route_block" --arg tt "$_route_base" \
        '(.[$b] // {})[$tt] // empty' "$_route_manifest" 2>/dev/null)
      if [ -n "$_route_value" ]; then
        _ROUTE_LAST_VALUE="$_route_value"
        _ROUTE_LAST_VIA="noncore-compound"
        unset _route_block _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
        return 0
      fi
    done
  fi

  # Step 3 -- core, exact match
  _route_core_manifest=$(routing_core_manifest)
  if [ -n "$_route_core_manifest" ]; then
    _route_value=$(jq -c --arg b "$_route_block" --arg tt "$_route_task_type" \
      '(.[$b] // {})[$tt] // empty' "$_route_core_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="core-exact"
      unset _route_block _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  fi

  # Step 4 -- core, compound-base match
  if [ -n "$_route_core_manifest" ] && printf '%s' "$_route_task_type" | grep -q ":"; then
    _route_base=$(printf '%s' "$_route_task_type" | cut -d: -f1)
    _route_value=$(jq -c --arg b "$_route_block" --arg tt "$_route_base" \
      '(.[$b] // {})[$tt] // empty' "$_route_core_manifest" 2>/dev/null)
    if [ -n "$_route_value" ]; then
      _ROUTE_LAST_VALUE="$_route_value"
      _ROUTE_LAST_VIA="core-compound"
      unset _route_block _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
      return 0
    fi
  fi

  # Step 5 -- total miss ($_ROUTE_LAST_VALUE stays "", $_ROUTE_LAST_VIA stays "miss")
  unset _route_block _route_task_type _route_manifest _route_value _route_name _route_base _route_core_manifest
  return 0
}

# routing_trace -- emits one `[LABEL] op=.. task_type=.. effort=.. resolved=.. via=..` line to
# stderr. Never writes to stdout (would corrupt a caller capturing routing_lookup's own output).
# $6 (optional) overrides the bracketed label, default "route"; command-route-agent.sh passes
# "route-agent" for its own, otherwise-identical trace shape.
routing_trace() {
  local _route_op="$1" _route_task_type="$2" _route_effort="$3" _route_resolved="$4" _route_via="${5:-}" _route_label="${6:-route}"
  echo "[${_route_label}] op=${_route_op} task_type=${_route_task_type} effort=${_route_effort} resolved=${_route_resolved} via=${_route_via}" >&2
  unset _route_op _route_task_type _route_effort _route_resolved _route_via _route_label
  return 0
}
