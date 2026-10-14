#!/usr/bin/env bash
# derived-artifact-probe-lib.sh - Single home of the repo-declared, build-free derived-artifact
# staleness probe mechanism both implement-postflight engines (orchestrate-cycle-postflight.sh,
# the multi-task engine, and command-gate-out.sh, the single-task engine) call before their own
# status write. Modelled structurally on scripts/lib/deploy-freshness-lib.sh: a header stating
# the contract, the fail-open posture, and the list of consumers; sourced, never executed; sets
# no shell options a caller inherits; exports nothing a caller must guess at.
#
# Declaration point (see context/standards/repo-level-declarations.md for the full writeup): a
# consumer repo's own <repo_root>/.claude-extensions.json may carry a hand-authored, sibling
# top-level key, `derived_artifact_probes`, an array of entries:
#
#   {
#     "component": "<name, for logging only -- never interpreted>",
#     "check_command": "<a single build-free shell command string>",
#     "derived_output_dirs": ["<repo-root-relative directory or file path>", ...]
#   }
#
# Three exported functions:
#
#   (a) derived_probe_entries <repo_root> - prints a compact JSON array of every VALIDATED
#       entry (component, check_command, derived_output_dirs all present and correctly typed).
#       A malformed entry (missing/empty check_command, non-array or non-string-member
#       derived_output_dirs) is DROPPED with one named WARNING line on stderr per dropped entry
#       -- never aborts the whole read.
#
#   (b) derived_probe_output_prefixes <repo_root> - prints a compact JSON array of every
#       declared derived_output_dirs member across all VALIDATED entries, each normalized to a
#       trailing-slash, repo-root-relative prefix -- the exact shape a `startswith` containment
#       comparison already consumes (see orchestrate-cycle-postflight.sh's WORK (h)).
#
#   (c) derived_probe_run_all <repo_root> <notice_prefix> - runs every VALIDATED entry's
#       check_command once, under a bounded `timeout`, cwd <repo_root>. Returns 0 only when
#       every probe exits 0; returns 1 when any probe exits non-zero OR times out. Emits one
#       named line per FAILING probe on stderr, prefixed with <notice_prefix>, naming the
#       component, the command, and the observed exit code (124 for a timeout).
#
# Fail-open posture (absolute, no exceptions): a missing .claude-extensions.json, a missing
# `jq`, an absent `derived_artifact_probes` key, or an empty `[]` array all yield `[]` / `[]` /
# rc 0 from every function above, with NO probe executed and NO stderr noise beyond the single
# explanatory line reserved for a genuinely malformed per-entry shape. This is the same
# "unknown/absent must never read as a block" contract deploy-freshness-lib.sh already commits
# to, applied here to a BLOCKING caller instead of an advisory one -- the blocking behaviour
# lives entirely in what a declared, validated check_command's own exit status says, never in
# the absence-detection path itself.
#
# Bounded execution (Decision 4 of the implementation plan this library was built against): a
# declared check_command is run with no elevated privilege or environment beyond what the
# implementation agent dispatching this postflight already has, and under a single named
# timeout bound (see DERIVED_PROBE_TIMEOUT_SECONDS below). A probe that exceeds the bound is a
# LOUD, NAMED PROBE FAILURE attributed to the repo's own declaration (the repo declared a
# command that is not, in fact, build-free) -- never a silent pass and never an unbounded block.
# See context/patterns/external-process-wait.md for the general bounded-wait discipline this
# bound follows in spirit (a build-free check is expected to resolve in well under a second in
# the overwhelming common case; the bound is generous headroom against an occasional slow disk
# or cold cache, not a tuning knob for a genuinely slow command).
#
# Consumers (both MUST source this file, never re-implement any part of its algorithm):
#   - scripts/orchestrate-cycle-postflight.sh (multi-task engine)
#   - scripts/command-gate-out.sh (single-task engine)

# Single named bound, Decision 4: a declared check_command is build-free by the repo's own
# declaration, so this is headroom against incidental slowness, not a budget for a genuinely
# slow command. A probe that exceeds this is a failure, not a retry candidate.
DERIVED_PROBE_TIMEOUT_SECONDS=30

# ─── _derived_probe_load_entries_json <repo_root> ───────────────────────────────────────────────
# Internal helper, not part of the exported contract. Prints the raw (unvalidated)
# `derived_artifact_probes` array from <repo_root>/.claude-extensions.json on success; prints
# "[]" and returns 0 for every absence/cannot-parse case (missing file, missing jq, invalid
# JSON, absent key, non-array value) -- this helper NEVER signals failure to its callers; every
# caller below treats its output as the array to iterate, full stop.
_derived_probe_load_entries_json() {
  local repo_root="$1"
  local state_file="${repo_root}/.claude-extensions.json"

  if [ ! -f "$state_file" ] || ! command -v jq >/dev/null 2>&1; then
    echo "[]"
    return 0
  fi

  local json
  json="$(cat "$state_file" 2>/dev/null)"
  if [ -z "$json" ] || ! echo "$json" | jq -e . >/dev/null 2>&1; then
    echo "[]"
    return 0
  fi

  local raw
  raw="$(echo "$json" | jq -c '.derived_artifact_probes // [] | if (type == "array") then . else [] end' 2>/dev/null)"
  if [ -z "$raw" ]; then
    echo "[]"
    return 0
  fi
  echo "$raw"
  return 0
}

# derived_probe_entries <repo_root>
# Prints a compact JSON array of every validated {component, check_command,
# derived_output_dirs} entry. Drops a malformed entry with a named WARNING on stderr. Always
# returns 0.
derived_probe_entries() {
  local repo_root="${1:?derived_probe_entries: repo_root required}"

  local raw_json
  raw_json="$(_derived_probe_load_entries_json "$repo_root")"

  local count
  count="$(echo "$raw_json" | jq 'length' 2>/dev/null)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  if [ "$count" -eq 0 ]; then
    echo "[]"
    return 0
  fi

  local validated="[]"
  local i entry component check_command dirs_json dirs_ok entry_ok
  for ((i = 0; i < count; i++)); do
    entry="$(echo "$raw_json" | jq -c ".[$i]" 2>/dev/null)"
    [ -z "$entry" ] && entry="null"

    entry_ok=true
    component="$(echo "$entry" | jq -r '.component // ""' 2>/dev/null)"
    check_command="$(echo "$entry" | jq -r '.check_command // ""' 2>/dev/null)"
    dirs_json="$(echo "$entry" | jq -c '.derived_output_dirs // null' 2>/dev/null)"

    [ -z "$check_command" ] && entry_ok=false

    dirs_ok=false
    if [ "$entry_ok" = "true" ]; then
      if echo "$dirs_json" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
        dirs_ok=true
      fi
    fi
    [ "$dirs_ok" != "true" ] && entry_ok=false

    if [ "$entry_ok" = "true" ]; then
      validated="$(echo "$validated" | jq -c --arg c "$component" --arg cc "$check_command" --argjson d "$dirs_json" \
        '. + [{component: $c, check_command: $cc, derived_output_dirs: $d}]' 2>/dev/null)"
      [ -z "$validated" ] && validated="[]"
    else
      echo "WARNING: derived-artifact-probe-lib.sh: dropping malformed derived_artifact_probes entry at index ${i} (component='${component:-<empty>}') -- check_command and derived_output_dirs (array of strings) are both required." >&2
    fi
  done

  echo "$validated"
  return 0
}

# derived_probe_output_prefixes <repo_root>
# Prints a compact JSON array of every declared derived_output_dirs member across all validated
# entries, each normalized to a trailing-slash, repo-root-relative prefix. Always returns 0.
derived_probe_output_prefixes() {
  local repo_root="${1:?derived_probe_output_prefixes: repo_root required}"

  local entries_json
  entries_json="$(derived_probe_entries "$repo_root")"

  local prefixes
  prefixes="$(echo "$entries_json" | jq -c \
    '[.[].derived_output_dirs[]? | if (endswith("/")) then . else . + "/" end] | unique' 2>/dev/null)"
  if [ -z "$prefixes" ]; then
    echo "[]"
    return 0
  fi
  echo "$prefixes"
  return 0
}

# derived_probe_run_all <repo_root> <notice_prefix>
# Runs every validated entry's check_command once under a DERIVED_PROBE_TIMEOUT_SECONDS bound,
# cwd <repo_root>. Returns 0 only when every probe exits 0; returns 1 when any probe fails or
# times out, after emitting one named failure line per failing probe on stderr. Returns 0
# immediately, with no probe executed, when there are no validated entries.
derived_probe_run_all() {
  local repo_root="${1:?derived_probe_run_all: repo_root required}"
  local notice_prefix="${2:-}"

  local entries_json
  entries_json="$(derived_probe_entries "$repo_root")"

  local count
  count="$(echo "$entries_json" | jq 'length' 2>/dev/null)"
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  if [ "$count" -eq 0 ]; then
    return 0
  fi

  local overall_rc=0
  local i component check_command probe_rc
  for ((i = 0; i < count; i++)); do
    component="$(echo "$entries_json" | jq -r ".[$i].component" 2>/dev/null)"
    check_command="$(echo "$entries_json" | jq -r ".[$i].check_command" 2>/dev/null)"

    probe_rc=0
    ( cd "$repo_root" && timeout "${DERIVED_PROBE_TIMEOUT_SECONDS}" bash -c "$check_command" ) \
      >/dev/null 2>&1 || probe_rc=$?

    if [ "$probe_rc" -ne 0 ]; then
      overall_rc=1
      echo "${notice_prefix} DERIVED-STALENESS: component '${component:-<unnamed>}' check_command '${check_command}' exited ${probe_rc}$([ "$probe_rc" -eq 124 ] && echo " (timed out after ${DERIVED_PROBE_TIMEOUT_SECONDS}s)")." >&2
    fi
  done

  return "$overall_rc"
}
