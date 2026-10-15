#!/usr/bin/env bash
# gate-registry-lib.sh - Parses scripts/gate-registry.data and executes one gate by id.
#
# THIS IS A THIN INTERPRETER, DELIBERATELY. The declarative registry removes the 23-gate
# copy-pasted `if gate_selected N; then ... fi` BOILERPLATE from verify-deploy.sh's top level
# (adding a migrated gate becomes a data-file row plus one `gateN_run` function, not a 40-line
# inline block), but it does NOT attempt to generically re-derive each gate's own selection,
# source-store guard, or output shape -- those 8 migrated gates are heterogeneous enough (see
# gate-registry.data's own header, and this task's plan Phase 4 Scope Hypothesis) that a generic
# fold would either special-case several gates in code (defeating the point) or silently change
# a SKIP message's exact text (breaking the byte-identical output this migration is required to
# preserve). So `gate_registry_execute` does exactly one thing: look up the function name
# registered for a gate id, and call it. Each `gateN_run` function remains fully self-contained
# -- it still performs its own `gate_selected` check, its own source-store guard (where
# applicable), and its own pass/fail/FINDINGS_LIST population, identically to the pre-registry
# inline code it was extracted from verbatim.
#
# CONTRACT (mirrors scripts/lib/manifest-routing-lib.sh's own contract verbatim):
#   - Never calls `exit` -- a faulty resolution at worst leaves a gate id unresolved (silently a
#     no-op for that id), never aborts the caller.
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Every internal variable is prefixed `_greg_` and is explicitly unset before each function
#     returns, so sourcing this file never leaks state into the calling shell's environment.
#   - A miss is signalled by empty output / a silent no-op, never a non-zero exit status.
#
# Exports FOUR functions (load once, query many times -- this library is sourced, never
# re-executed per gate):
#
#   gate_registry_load [DATA_FILE]
#     Parses DATA_FILE (default: the sibling scripts/gate-registry.data) into the global
#     associative arrays below, keyed by gate id. Idempotent -- calling it twice simply
#     re-parses, which is harmless since the data file is static for the lifetime of one
#     verify-deploy.sh invocation. Must be called before any other function in this file; the
#     other three degrade to empty/no-op if the registry was never loaded, rather than erroring.
#
#   gate_registry_ids
#     Echoes every loaded gate id, space-separated, in ascending numeric order. This is what
#     verify-deploy.sh's own gate-execution loop iterates over
#     (`for _gate_id in $(gate_registry_ids); do "gate${_gate_id}_run"; done`).
#
#   gate_registry_execute <id>
#     Looks up the `invoke` field for <id> and calls that function directly (no subshell --
#     a subshell would strand the function's mutations to FINDINGS_LIST/PASS/FAIL/CURRENT_GATE,
#     which are globals in the calling verify-deploy.sh process). A gate id with no registered
#     function is a silent no-op (never an error): a lint-gate-registry.sh finding, not a runtime
#     abort, is the correct place to catch that. NOT currently used by verify-deploy.sh's own
#     loop (which calls `"gate${id}_run"` directly via the id itself, since the function-naming
#     convention IS the lookup for the migrated tranche) -- provided for a future consumer (e.g.
#     a selection surface that needs the registry's declared `invoke` name explicitly rather than
#     assuming the `gate${id}_run` convention, or an out-of-order/filtered execution path).
#
#   gate_registry_field <id> <field>
#     Echoes one field's value for <id> (one of: name, invoke, dependencies,
#     requires_source_store, timeout_s, cost_class, serialized), or empty on a miss. The single
#     read path lint-gate-registry.sh and test-gate-registry-resolution.sh use to validate the
#     data without each re-implementing the TSV parse.

declare -gA _GREG_NAME=()
declare -gA _GREG_INVOKE=()
declare -gA _GREG_DEPS=()
declare -gA _GREG_SOURCE_STORE=()
declare -gA _GREG_TIMEOUT=()
declare -gA _GREG_COST_CLASS=()
declare -gA _GREG_SERIALIZED=()
_GREG_IDS=()
_GREG_LOADED=false

gate_registry_load() {
  local _greg_file="${1:-}"
  local _greg_self_dir _greg_line
  local _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser

  if [ -z "$_greg_file" ]; then
    _greg_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    _greg_file="${_greg_self_dir}/gate-registry.data"
  fi

  _GREG_NAME=(); _GREG_INVOKE=(); _GREG_DEPS=(); _GREG_SOURCE_STORE=()
  _GREG_TIMEOUT=(); _GREG_COST_CLASS=(); _GREG_SERIALIZED=(); _GREG_IDS=()
  _GREG_LOADED=false

  if [ ! -f "$_greg_file" ]; then
    unset _greg_file _greg_self_dir _greg_line _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser
    return 0
  fi

  while IFS=$'\t' read -r _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser; do
    # Skip comments (lines starting with #) and blank lines -- same loud-skip-free advisory
    # convention as suite-cost-hints.txt.
    case "$_greg_id" in
      ''|'#'*) continue ;;
    esac
    case "$_greg_id" in
      ''|*[!0-9]*) continue ;;  # malformed id -- not a valid row, skip rather than abort
    esac
    _GREG_NAME["$_greg_id"]="$_greg_name"
    _GREG_INVOKE["$_greg_id"]="$_greg_invoke"
    # "-" is the data file's placeholder for "no dependencies" -- a TRULY empty field between
    # two tabs is unreliable under `IFS=$'\t' read`, because bash classifies tab as an
    # IFS-whitespace character even when it is IFS's sole member, so consecutive-delimiter
    # (empty-field) sequences silently collapse and shift every later column by one. Normalize
    # the placeholder back to empty here, once, so every consumer of this array sees "" for "no
    # dependencies" regardless of the file's own on-disk placeholder convention.
    [ "$_greg_deps" = "-" ] && _greg_deps=""
    _GREG_DEPS["$_greg_id"]="$_greg_deps"
    _GREG_SOURCE_STORE["$_greg_id"]="$_greg_rss"
    _GREG_TIMEOUT["$_greg_id"]="$_greg_timeout"
    _GREG_COST_CLASS["$_greg_id"]="$_greg_class"
    _GREG_SERIALIZED["$_greg_id"]="$_greg_ser"
    _GREG_IDS+=("$_greg_id")
  done < "$_greg_file"

  # Sort ids numerically, ascending -- deterministic iteration order regardless of the data
  # file's own row order (today they are already ascending, but this must not be assumed).
  if [ "${#_GREG_IDS[@]}" -gt 0 ]; then
    mapfile -t _GREG_IDS < <(printf '%s\n' "${_GREG_IDS[@]}" | sort -n)
  fi

  _GREG_LOADED=true
  unset _greg_file _greg_self_dir _greg_line _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser
  return 0
}

gate_registry_ids() {
  if [ "${#_GREG_IDS[@]}" -eq 0 ]; then
    return 0
  fi
  printf '%s\n' "${_GREG_IDS[@]}" | tr '\n' ' ' | sed 's/ $//'
  echo ""
  return 0
}

gate_registry_execute() {
  local _greg_id="$1" _greg_fn
  _greg_fn="${_GREG_INVOKE[$_greg_id]:-}"
  if [ -n "$_greg_fn" ] && declare -F "$_greg_fn" >/dev/null 2>&1; then
    "$_greg_fn"
  fi
  unset _greg_id _greg_fn
  return 0
}

gate_registry_field() {
  local _greg_id="$1" _greg_field="$2" _greg_result=""
  case "$_greg_field" in
    name) _greg_result="${_GREG_NAME[$_greg_id]:-}" ;;
    invoke) _greg_result="${_GREG_INVOKE[$_greg_id]:-}" ;;
    dependencies) _greg_result="${_GREG_DEPS[$_greg_id]:-}" ;;
    requires_source_store) _greg_result="${_GREG_SOURCE_STORE[$_greg_id]:-}" ;;
    timeout_s) _greg_result="${_GREG_TIMEOUT[$_greg_id]:-}" ;;
    cost_class) _greg_result="${_GREG_COST_CLASS[$_greg_id]:-}" ;;
    serialized) _greg_result="${_GREG_SERIALIZED[$_greg_id]:-}" ;;
  esac
  echo "$_greg_result"
  unset _greg_id _greg_field _greg_result
  return 0
}
