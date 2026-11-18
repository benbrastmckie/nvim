#!/usr/bin/env bash
# suite-resolver-lib.sh - Declarable resolver interface: turns a touched-path set plus a tree
# root into a selection-token set plus a per-path unresolved list, composing the DEFAULT backend
# (scripts/lib/suite-selection-lib.sh's `suite_selection_select`, unchanged) with an explicit
# map pre-pass (scripts/tests/suite-selection-map.data) and, when a repository declares one via
# `.claude-extensions.json`'s `verification_scope.resolver`, an invocable DECLARED backend.
#
# Sourced (never executed) -- same discipline as suite-selection-lib.sh: no shell options set,
# no `exit` ever called, internal names prefixed `_srl_`.
#
# ─── WHY THIS WRAPS suite_selection_select RATHER THAN CALLING IT MULTI-PATH ──────────────────
# `suite_selection_select PATH [PATH...]` escalates the WHOLE multi-path call to the
# `__FULL_SWEEP__` sentinel the moment ONE path is unmappable (see that library's own header).
# This wrapper calls it ONE PATH AT A TIME instead, so one new/unmapped file in a touched set
# never drowns out the real suites the OTHER touched paths resolve to -- the exact collapse the
# originating record exists to prevent. No edit to suite-selection-lib.sh itself is needed or
# made; this is purely a different call pattern over its existing, unchanged public functions.
#
# ─── PUBLISHED OUTPUT SHAPE (every function below that resolves a path set emits exactly this) ─
# stdout, nothing else:
#   SELECT <suite-basename>      -- one line per resolved suite token, de-duplicated
#   UNRESOLVED <path>            -- one line per touched path no resolution covers
# Exit codes:
#   0  resolved (possibly to the empty SELECT set -- every path legitimately UNRESOLVED)
#   2  usage/shape error (bad arguments to THIS library's own functions)
#   3  the invoked backend cannot resolve AT ALL (reserved for a DECLARED backend's own self
#      report; `suite_resolver_resolve` below, built on the default backend, never returns this --
#      the default backend always "resolves" in the sense of emitting a disposition, mapped or
#      UNRESOLVED, for every path given)
#
# ─── THE DECLARED-BACKEND CONTRACT (published narrative copy lives in
# context/standards/shell-script-testing.md's resolver-backend-contract subsection; this header
# states the mechanical shape the invocation and conformance check below actually implement) ───
# A declared backend is a single shell command (`verification_scope.resolver.command`), invoked
# as:  <command> <tree_root>   with every touched path written one-per-line on STDIN.
# Its stdout MUST be exactly the published shape above and nothing else (no banner, no progress
# line -- diagnostics go to stderr). Its exit code MUST be one of 0 / 2 / 3 above. A backend
# violating either constraint is NON-CONFORMING and `suite_resolver_conformance_check` refuses it
# before any of its output is ever trusted by `suite_resolver_resolve`.
#
# ─── COMPOSITION (`verification_scope.resolver.compose`, default "union") ─────────────────────
#   union    (default) -- the final SELECT set is the default-backend-plus-map resolution UNION
#            the declared backend's own resolution; a path is UNRESOLVED only when BOTH leave it
#            unresolved.
#   replace  -- the declared backend's resolution is used ALONE; the default backend and the
#            explicit map are not consulted at all for a repository declaring "replace".
#
# ─── EXPLICIT MAP PRE-PASS (scripts/tests/suite-selection-map.data) ────────────────────────────
# For a path the default backend leaves unresolved, consult the checked-in TAB-separated map
# (path_glob  suites  reason; see that file's own header for the full grammar). First matching
# row (bash glob match, `*` crosses `/`) wins; its `suites` column (comma-separated) is emitted
# as SELECT lines. A path matching no row stays unresolved at this stage and falls through to
# the declared backend (if any) and then to the Phase 3 classified fallback.
#
# Consumers:
#   - scripts/verify-touched.sh (the entry point)
#   - scripts/lib/unmapped-fallback-lib.sh (classifies whatever this library leaves UNRESOLVED)

_SRL_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_SRL_DEFAULT_MAP_DATA="${_SRL_SELF_DIR}/../tests/suite-selection-map.data"

# shellcheck source=suite-selection-lib.sh
if [ -f "${_SRL_SELF_DIR}/suite-selection-lib.sh" ]; then
  . "${_SRL_SELF_DIR}/suite-selection-lib.sh"
fi
# shellcheck source=verification-scope-lib.sh
if [ -f "${_SRL_SELF_DIR}/verification-scope-lib.sh" ]; then
  . "${_SRL_SELF_DIR}/verification-scope-lib.sh"
fi

# _srl_map_lookup <map_file> <path> -- stdout: comma-separated suites from the FIRST matching
# row of <map_file>, or nothing (empty, rc 0) when no row matches or the file does not exist.
# Internal; not part of the public API.
_srl_map_lookup() {
  local _srl_map_file="$1"
  local _srl_path="$2"
  local _srl_line _srl_glob _srl_suites

  [ -f "${_srl_map_file}" ] || { return 0; }

  while IFS=$'\t' read -r _srl_glob _srl_suites _srl_reason; do
    case "${_srl_glob}" in
      ""|"#"*) continue ;;
    esac
    [ -n "${_srl_glob}" ] || continue
    # shellcheck disable=SC2053
    if [[ "${_srl_path}" == ${_srl_glob} ]]; then
      printf '%s\n' "${_srl_suites}"
      unset _srl_map_file _srl_path _srl_line _srl_glob _srl_suites _srl_reason
      return 0
    fi
  done < "${_srl_map_file}"

  unset _srl_map_file _srl_path _srl_line _srl_glob _srl_suites _srl_reason
  return 0
}

# _srl_default_resolve_one <path> -- stdout: "SELECT <suite>" lines for <path> if the default
# (basename) backend maps it, or nothing when unmapped by both basename resolution AND the
# explicit map. Internal.
_srl_default_resolve_one() {
  local _srl_path="$1"
  local _srl_unmapped _srl_suite _srl_map_hit

  if command -v suite_selection_unmapped >/dev/null 2>&1; then
    _srl_unmapped="$(suite_selection_unmapped "${_srl_path}" 2>/dev/null)"
  else
    _srl_unmapped="${_srl_path}"
  fi

  if [ -z "${_srl_unmapped}" ]; then
    suite_selection_select "${_srl_path}" 2>/dev/null | while IFS= read -r _srl_suite; do
      [ -n "${_srl_suite}" ] && printf 'SELECT\t%s\n' "${_srl_suite}"
    done
    unset _srl_path _srl_unmapped _srl_suite _srl_map_hit
    return 0
  fi

  _srl_map_hit="$(_srl_map_lookup "${SUITE_RESOLVER_MAP_DATA:-${_SRL_DEFAULT_MAP_DATA}}" "${_srl_path}")"
  if [ -n "${_srl_map_hit}" ]; then
    IFS=',' read -r -a _srl_map_suites <<< "${_srl_map_hit}"
    for _srl_suite in "${_srl_map_suites[@]}"; do
      [ -n "${_srl_suite}" ] && printf 'SELECT\t%s\n' "${_srl_suite}"
    done
    unset _srl_map_suites
  fi

  unset _srl_path _srl_unmapped _srl_suite _srl_map_hit
  return 0
}

# _srl_invoke_declared_backend <command> <tree_root> <path> [<path>...] -- stdout: the backend's
# RAW stdout verbatim; return value: the backend's own exit code. Internal; callers that trust
# the output must have already run `suite_resolver_conformance_check` against this same command.
_srl_invoke_declared_backend() {
  local _srl_cmd="$1"
  local _srl_tree_root="$2"
  shift 2
  local -a _srl_paths=("$@")
  local _srl_rc

  printf '%s\n' "${_srl_paths[@]}" | bash -c "${_srl_cmd}" -- "${_srl_tree_root}"
  _srl_rc=$?
  unset _srl_cmd _srl_tree_root _srl_paths
  return "${_srl_rc}"
}

# suite_resolver_conformance_check <command> <tree_root> -- runs <command> against a fixed,
# deliberately small probe input (two synthetic paths that resolve to nothing meaningful; the
# conformance check tests SHAPE, never correctness of a real resolution) and verifies: every
# stdout line matches "^SELECT " or "^UNRESOLVED ", nothing else is printed, and the exit code is
# one of 0/2/3. Prints one named reason to stderr and returns 1 on any violation; returns 0 when
# conforming.
suite_resolver_conformance_check() {
  local _src_cmd="${1:?suite_resolver_conformance_check: command required}"
  local _src_tree_root="${2:?suite_resolver_conformance_check: tree_root required}"
  local -a _src_probe_paths=(
    "__suite_resolver_conformance_probe__/does-not-exist-a.sh"
    "__suite_resolver_conformance_probe__/does-not-exist-b.sh"
  )
  local _src_out _src_rc _src_line

  _src_out="$(_srl_invoke_declared_backend "${_src_cmd}" "${_src_tree_root}" "${_src_probe_paths[@]}" 2>/dev/null)"
  _src_rc=$?

  case "${_src_rc}" in
    0|2|3) : ;;
    *)
      echo "suite_resolver_conformance_check: REFUSED -- declared backend '${_src_cmd}' exited ${_src_rc}, which is not one of the documented 0/2/3 exit codes." >&2
      unset _src_cmd _src_tree_root _src_probe_paths _src_out _src_rc _src_line
      return 1
      ;;
  esac

  if [ -n "${_src_out}" ]; then
    while IFS= read -r _src_line; do
      [ -z "${_src_line}" ] && continue
      case "${_src_line}" in
        SELECT\ *|UNRESOLVED\ *) : ;;
        *)
          echo "suite_resolver_conformance_check: REFUSED -- declared backend '${_src_cmd}' emitted a malformed line not matching 'SELECT <token>' or 'UNRESOLVED <path>': '${_src_line}'" >&2
          unset _src_cmd _src_tree_root _src_probe_paths _src_out _src_rc _src_line
          return 1
          ;;
      esac
    done <<< "${_src_out}"
  fi

  unset _src_cmd _src_tree_root _src_probe_paths _src_out _src_rc _src_line
  return 0
}

# suite_resolver_resolve <tree_root> PATH [PATH...] -- see PUBLIC API header above. Composes the
# default backend (basename resolution + explicit map) with a declared backend per
# verification_scope's resolver.compose, reading the declaration from <tree_root>'s own
# .claude-extensions.json via verification-scope-lib.sh. Always returns 0 except on a genuine
# usage error (no tree_root / no paths), which returns 2.
suite_resolver_resolve() {
  local _sr_tree_root="${1:?suite_resolver_resolve: tree_root required}"
  shift
  if [ "$#" -eq 0 ]; then
    echo "suite_resolver_resolve: at least one PATH is required" >&2
    return 2
  fi
  local -a _sr_paths=("$@")
  local _sr_p _sr_t _sr_declared_cmd _sr_compose
  local -A _sr_default_resolved=()
  local -A _sr_declared_resolved=()
  local -a _sr_select_tokens=()
  local -A _sr_select_seen=()

  _sr_declared_cmd=""
  _sr_compose="union"
  if command -v verification_scope_resolver_command >/dev/null 2>&1; then
    _sr_declared_cmd="$(verification_scope_resolver_command "${_sr_tree_root}" 2>/dev/null)"
  fi
  if command -v verification_scope_resolver_compose >/dev/null 2>&1; then
    _sr_compose="$(verification_scope_resolver_compose "${_sr_tree_root}" 2>/dev/null)"
  fi
  [ -z "${_sr_compose}" ] && _sr_compose="union"

  # Default-backend + explicit-map resolution, per path, skipped entirely under "replace" with a
  # declared backend present.
  if [ -z "${_sr_declared_cmd}" ] || [ "${_sr_compose}" = "union" ]; then
    local _sr_tag _sr_val
    for _sr_p in "${_sr_paths[@]}"; do
      while IFS=$'\t' read -r _sr_tag _sr_val; do
        [ "${_sr_tag}" = "SELECT" ] || continue
        [ -z "${_sr_val}" ] && continue
        if [ -z "${_sr_select_seen[${_sr_val}]:-}" ]; then
          _sr_select_tokens+=("${_sr_val}")
          _sr_select_seen["${_sr_val}"]=1
        fi
        _sr_default_resolved["${_sr_p}"]=1
      done < <(_srl_default_resolve_one "${_sr_p}")
    done
  fi

  # Declared-backend resolution, when one is declared.
  if [ -n "${_sr_declared_cmd}" ]; then
    local _sr_backend_out _sr_backend_rc _sr_tag _sr_val
    _sr_backend_out="$(_srl_invoke_declared_backend "${_sr_declared_cmd}" "${_sr_tree_root}" "${_sr_paths[@]}" 2>/dev/null)"
    _sr_backend_rc=$?
    if [ "${_sr_backend_rc}" -eq 0 ] && [ -n "${_sr_backend_out}" ]; then
      while IFS=$'\t' read -r _sr_tag _sr_val; do
        [ -z "${_sr_tag}" ] && continue
        case "${_sr_tag}" in
          SELECT)
            [ -z "${_sr_val}" ] && continue
            if [ -z "${_sr_select_seen[${_sr_val}]:-}" ]; then
              _sr_select_tokens+=("${_sr_val}")
              _sr_select_seen["${_sr_val}"]=1
            fi
            ;;
          UNRESOLVED)
            : # declared backend's own UNRESOLVED disposition contributes nothing positive;
              # absence from _sr_declared_resolved is the signal consumed below.
            ;;
        esac
      done <<< "$(printf '%s\n' "${_sr_backend_out}" | sed -E 's/^(SELECT|UNRESOLVED) /\1\t/')"
      # A path is declared-resolved iff it does NOT appear on an UNRESOLVED line from the
      # backend (the backend is given the full path list, so silence on a path -- not emitting
      # it as UNRESOLVED -- means the backend considers it covered by whatever it selected).
      for _sr_p in "${_sr_paths[@]}"; do
        if ! printf '%s\n' "${_sr_backend_out}" | grep -qF "UNRESOLVED ${_sr_p}"; then
          _sr_declared_resolved["${_sr_p}"]=1
        fi
      done
    fi
  fi

  for _sr_t in "${_sr_select_tokens[@]}"; do
    printf 'SELECT %s\n' "${_sr_t}"
  done

  for _sr_p in "${_sr_paths[@]}"; do
    if [ "${_sr_compose}" = "replace" ] && [ -n "${_sr_declared_cmd}" ]; then
      [ -z "${_sr_declared_resolved[${_sr_p}]:-}" ] && printf 'UNRESOLVED %s\n' "${_sr_p}"
    else
      if [ -z "${_sr_default_resolved[${_sr_p}]:-}" ] && [ -z "${_sr_declared_resolved[${_sr_p}]:-}" ]; then
        printf 'UNRESOLVED %s\n' "${_sr_p}"
      fi
    fi
  done

  unset _sr_tree_root _sr_paths _sr_p _sr_line _sr_mode _sr_declared_cmd _sr_compose
  unset _sr_default_resolved _sr_declared_resolved _sr_select_tokens _sr_select_seen _sr_t
  return 0
}
