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
# A THIRD, SIBLING function -- routing_resolve_observers() -- lives alongside the two
# first-match-wins ladders above (routing_lookup / routing_lookup_flat) but is a different shape
# on purpose: it resolves the manifest `observers` block, which is a fan-out (notify-every-match)
# seam, not a precedence ladder. It returns every matching entry across every loaded extension
# (core included -- there is no precedence to establish when every match fires) as one
# TAB-separated line per match on stdout, via plain command substitution, and never via the
# _ROUTE_LAST_VALUE/_ROUTE_LAST_VIA globals the two ladders above use. Do not fold it into
# routing_lookup, and do not widen routing_lookup's single-value return contract to serve it.
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
#   while IFS=$'\t' read -r manifest ext name script matched_on timeout_s; do
#     ...
#   done < <(routing_resolve_observers "$topic" "$task_type")  # resolve-ALL observer matches
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

# routing_resolve_observers -- resolve-ALL-matches ladder for the `observers` manifest block,
# $1=topic $2=task_type. Unlike routing_lookup/routing_lookup_flat (first-match-wins, single
# value via globals), this is a fan-out resolver: every matching observer declaration, across
# every loaded extension (core included -- there is no precedence to establish when every match
# fires), is emitted as one TAB-separated line on stdout:
#   manifest_path<TAB>extension_name<TAB>observer_name<TAB>script<TAB>matched_on<TAB>timeout_seconds
# where matched_on is one of topic|task_type|both. Empty stdout on a total miss. Always
# `return 0` -- a caller iterating this function's stdout must never see a non-zero status as a
# signal; emptiness alone means "no match". Deliberately does NOT use the _ROUTE_LAST_VALUE /
# _ROUTE_LAST_VIA globals: this is a resolve-all function, not a third single-value ladder, so it
# must be safe to call under command substitution (`while read -r line; do ... done < <(routing_resolve_observers ...)`)
# and must never be mistaken for a sibling of routing_lookup.
#
# Matching is prefix-aware on BOTH keys, reusing the existing idiom verbatim: a declared `books`
# matches a task value of `books:certify` (compound task_type/topic values with a `:` sub-route,
# e.g. `present:grant`, are an established convention here). An exact match also counts.
# matched_on is "both" only when BOTH declared keys on an entry actually matched the task's own
# values -- not merely when both keys are declared.
#
# Structural validation (missing `script`, an entry declaring neither `topic` nor `task_type`, an
# unrecognized key) is NOT this resolver's job -- see check-extension-docs.sh's Rule X. This
# function silently SKIPS such an entry rather than failing; it must never be the thing that
# halts a caller.
#
# Enumerates `"${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json` in glob order (D7:
# deterministic multi-match ordering), with observer keys sorted within a manifest for
# determinism when more than one declaration in the same manifest matches.
routing_resolve_observers() {
  local _route_topic="$1"
  local _route_task_type="$2"
  local _route_manifest _route_ext_name _route_has_obs _route_obs_keys _route_obs_key
  local _route_obs_topic _route_obs_tt _route_obs_script _route_obs_timeout
  local _route_topic_base _route_tt_base _route_matched

  for _route_manifest in "${ROUTE_MANIFEST_ROOT:-.claude}"/extensions/*/manifest.json; do
    [ -f "$_route_manifest" ] || continue
    _route_has_obs=$(jq -r 'has("observers")' "$_route_manifest" 2>/dev/null)
    [ "$_route_has_obs" = "true" ] || continue
    _route_ext_name=$(jq -r '.name // empty' "$_route_manifest" 2>/dev/null)
    _route_obs_keys=$(jq -r '.observers | keys_unsorted | sort | .[]' "$_route_manifest" 2>/dev/null)

    while IFS= read -r _route_obs_key; do
      [ -n "$_route_obs_key" ] || continue

      _route_obs_script=$(jq -r --arg k "$_route_obs_key" '.observers[$k].script // empty' "$_route_manifest" 2>/dev/null)
      _route_obs_topic=$(jq -r --arg k "$_route_obs_key" '.observers[$k].topic // empty' "$_route_manifest" 2>/dev/null)
      _route_obs_tt=$(jq -r --arg k "$_route_obs_key" '.observers[$k].task_type // empty' "$_route_manifest" 2>/dev/null)
      _route_obs_timeout=$(jq -r --arg k "$_route_obs_key" '.observers[$k].timeout_seconds // empty' "$_route_manifest" 2>/dev/null)

      # Skip without failing: structural validation is Rule X's job, not this resolver's.
      [ -n "$_route_obs_script" ] || continue
      if [ -z "$_route_obs_topic" ] && [ -z "$_route_obs_tt" ]; then
        continue
      fi

      _route_matched=""

      if [ -n "$_route_obs_topic" ] && [ -n "$_route_topic" ]; then
        if [ "$_route_obs_topic" = "$_route_topic" ]; then
          _route_matched="topic"
        elif printf '%s' "$_route_topic" | grep -q ":"; then
          _route_topic_base=$(printf '%s' "$_route_topic" | cut -d: -f1)
          [ "$_route_obs_topic" = "$_route_topic_base" ] && _route_matched="topic"
        fi
      fi

      if [ -n "$_route_obs_tt" ] && [ -n "$_route_task_type" ]; then
        if [ "$_route_obs_tt" = "$_route_task_type" ]; then
          if [ "$_route_matched" = "topic" ]; then _route_matched="both"; else _route_matched="task_type"; fi
        elif printf '%s' "$_route_task_type" | grep -q ":"; then
          _route_tt_base=$(printf '%s' "$_route_task_type" | cut -d: -f1)
          if [ "$_route_obs_tt" = "$_route_tt_base" ]; then
            if [ "$_route_matched" = "topic" ]; then _route_matched="both"; else _route_matched="task_type"; fi
          fi
        fi
      fi

      [ -n "$_route_matched" ] || continue

      if ! printf '%s' "$_route_obs_timeout" | grep -qE '^[1-9][0-9]*$'; then
        _route_obs_timeout=30
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$_route_manifest" "$_route_ext_name" "$_route_obs_key" "$_route_obs_script" "$_route_matched" "$_route_obs_timeout"
    done <<EOF_KEYS
$_route_obs_keys
EOF_KEYS
  done

  unset _route_topic _route_task_type _route_manifest _route_ext_name _route_has_obs _route_obs_keys _route_obs_key
  unset _route_obs_topic _route_obs_tt _route_obs_script _route_obs_timeout _route_topic_base _route_tt_base _route_matched
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
