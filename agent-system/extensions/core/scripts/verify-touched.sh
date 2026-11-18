#!/usr/bin/env bash
# verify-touched.sh - The single entry point "narrow" means: turns a touched-path set into a
# correct, parallel, timed, narrowed run-all.sh pass, with a verdict that can never be mistaken
# for a full-battery pass. Wraps (and adds no competing implementation of) three libraries this
# record built: scripts/lib/suite-resolver-lib.sh (the declarable resolver interface, default
# backend `suite_selection_select` unchanged), scripts/lib/unmapped-fallback-lib.sh (the
# classified NO-SUITE-BY-CLASS / OWED-NOT-PAID fallback replacing the old `__FULL_SWEEP__`
# collapse on any unmapped path), and scripts/lib/verification-scope-lib.sh (the repo-declared
# tree-root / project-suite-root / resolver-backend topology).
#
# Usage:
#   verify-touched.sh [OPTIONS] [PATH...]
#
#   --base REF             Base ref for the committed half of touched-path derivation (see
#                           "TOUCHED-PATH DERIVATION" below). Default: this repository's own
#                           determined default branch (origin/HEAD, then init.defaultBranch),
#                           falling back to HEAD (degrading to working-tree-only derivation) when
#                           neither resolves.
#   --tree-root DIR[,DIR...] / --root-set DIR[,DIR...]
#                           One or more tree roots (repo-root-relative or absolute) to run the
#                           resolved battery against -- the "a consumer repository may run a
#                           copied tree under several deploy roots" case. Both flags are the
#                           SAME parameter (a root SET is just a comma-separated root list);
#                           --root-set is accepted only so the plan's own "tree root and root
#                           set" wording has a literal flag to point at, not a second mechanism.
#                           Default: this repository's own declared `verification_scope.tree_roots`
#                           (or the single root `.` when undeclared).
#   --task-dir DIR          Task directory an OWED classification's durable record is written
#                           under (<DIR>/records/full-sweep-owed.jsonl). Optional: when absent,
#                           an OWED path is still reported but no record is written (a named
#                           warning says so) -- an ad hoc, non-task-scoped invocation is not
#                           blocked over having nowhere durable to write.
#   --session SID           Forwarded into an owed record's own `session_id` field. Optional.
#   --dispatch-seq N        Forwarded into an owed record's own `dispatch_seq` field. Optional.
#   --timings FILE          Where the main resolved run-all.sh pass's --timings output lands.
#                           Default: a fresh `mktemp` path, ALWAYS printed regardless of whether
#                           --timings was given. Diagnostic only -- see "TIMINGS" below.
#   --jobs N|auto           Forwarded to every run-all.sh invocation this script makes. Default:
#                           auto.
#   --full-sweep            Opt-in STRICT MODE: skip resolution and classification entirely and
#                           run the complete, unnarrowed battery at every declared root instead --
#                           today's pre-this-record behaviour, for a caller that genuinely wants
#                           it. Still prints its own distinct, explicit verdict string.
#   -h, --help              Show this help and exit 0.
#
#   PATH...                 Explicit touched paths, overriding the default derivation entirely.
#
# TOUCHED-PATH DERIVATION (default, no PATH arguments given)
# ------------------------------------------------------------
# The union of two sets, sorted and de-duplicated:
#   1. "Working tree": every uncommitted change against HEAD (`git diff --name-only HEAD`, which
#      covers staged AND unstaged together) plus every untracked-but-not-ignored file
#      (`git ls-files --others --exclude-standard`).
#   2. "Staged diff against a named base": every path that differs between
#      `git merge-base <base> HEAD` and HEAD -- i.e. everything this branch has committed since
#      diverging from <base>, independent of what is or is not currently dirty.
# This is deliberately the union, not either alone: a fully-clean branch with committed-but-not-
# yet-merged work must still be covered (set 2), and uncommitted work-in-progress must still be
# covered (set 1) even before it is committed.
#
# PREFLIGHT (modeled on verify-deploy.sh's gate0: runs BEFORE any resolution, sits structurally
# outside the selection it validates, and so can never itself be deselected by that selection)
# ------------------------------------------------------------------------------------------------
# Refuses (named FINDING, exit 2, no suite runs) when, under `--full-sweep`'s absence:
#   - scripts/tests/suite-selection-map.data or suite-selection-noclass.data contains a
#     malformed row (not exactly 3 TAB-separated fields);
#   - any suite/lint basename either data file names does not exist on disk at either of the two
#     canonical suite locations (tests/test-*.sh or flat test-*.sh) relative to this script's own
#     tree;
#   - the declared OWED fallback set (`suite_selection_by_cost_class "$UNMAPPED_FALLBACK_COST_CLASS"`)
#     is empty -- an owed path with nothing to run against it now would be silently worse than
#     today's full-sweep collapse;
#   - a declared resolver backend (`verification_scope.resolver.command`) fails
#     `suite_resolver_conformance_check`.
#
# DUAL-MODE, PER-ROOT run-all.sh RESOLUTION
# -------------------------------------------
# Suite NAMES are resolved exactly ONCE, against THIS script's own co-located tree (multiple
# declared tree_roots are, by the "copied tree under several deploy roots" scenario this
# mechanism serves, identical copies of the same suite corpus -- resolving once and reusing the
# same --only list at every root is correct, not a shortcut). Running WHERE each resolved list
# actually executes is dual-mode and per-root: for each declared root, try
# "<root>/.claude/scripts/tests/run-all.sh" (the deployed mirror) first, then
# "<root>/agent-system/extensions/core/scripts/tests/run-all.sh" (the source-store copy) second;
# a root resolving neither is skipped with a named, loud Note (never silently treated as a pass).
#
# TIMINGS
# -------
# Every scoped run-all.sh invocation's --timings output is diagnostic-only. It is NOT an input to
# scripts/tests/suite-cost-hints.txt, whose regeneration authority stays exclusively with
# `measure-gate-costs.sh --regen-hints` -- that script's own idle-guard and multi-run averaging
# cannot be satisfied by a scoped, single-sample, ambient-load run, so wiring this output in
# would silently corrupt the hints file's own measurement discipline. Do not "helpfully" change
# this.
#
# VERDICT STRINGS (deliberately distinct from both of the two pre-existing pass strings: plain
# run-all.sh's "all discovered suites passed", and verify-deploy.sh's --gate8-touched narrowed
# "... (narrowed by --gate8-touched -- NOT a full-battery pass)") -- see the final verdict block
# near the end of this file for the exact text; a subset pass is never rendered as a full pass,
# in output or in any record.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for _vt_lib in verification-scope-lib.sh suite-selection-lib.sh suite-resolver-lib.sh unmapped-fallback-lib.sh; do
  if [ -f "${SCRIPT_DIR}/lib/${_vt_lib}" ]; then
    # shellcheck disable=SC1090
    . "${SCRIPT_DIR}/lib/${_vt_lib}"
  else
    echo "ERROR: verify-touched.sh: required library not found: ${SCRIPT_DIR}/lib/${_vt_lib}" >&2
    exit 2
  fi
done
unset _vt_lib

usage() {
  sed -n '2,46p' "$0" | sed 's/^# \{0,1\}//'
}

BASE_REF=""
TREE_ROOTS_ARG=""
TASK_DIR=""
SESSION_ID=""
DISPATCH_SEQ=""
TIMINGS_FILE=""
JOBS="auto"
FULL_SWEEP=false
EXPLICIT_PATHS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      [ $# -ge 2 ] || { echo "ERROR: --base requires REF" >&2; exit 2; }
      BASE_REF="$2"; shift 2 ;;
    --tree-root|--root-set)
      [ $# -ge 2 ] || { echo "ERROR: $1 requires DIR[,DIR...]" >&2; exit 2; }
      TREE_ROOTS_ARG="$2"; shift 2 ;;
    --task-dir)
      [ $# -ge 2 ] || { echo "ERROR: --task-dir requires DIR" >&2; exit 2; }
      TASK_DIR="$2"; shift 2 ;;
    --session)
      [ $# -ge 2 ] || { echo "ERROR: --session requires SID" >&2; exit 2; }
      SESSION_ID="$2"; shift 2 ;;
    --dispatch-seq)
      [ $# -ge 2 ] || { echo "ERROR: --dispatch-seq requires N" >&2; exit 2; }
      DISPATCH_SEQ="$2"; shift 2 ;;
    --timings)
      [ $# -ge 2 ] || { echo "ERROR: --timings requires FILE" >&2; exit 2; }
      TIMINGS_FILE="$2"; shift 2 ;;
    --jobs)
      [ $# -ge 2 ] || { echo "ERROR: --jobs requires N or 'auto'" >&2; exit 2; }
      JOBS="$2"; shift 2 ;;
    --full-sweep) FULL_SWEEP=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do EXPLICIT_PATHS+=("$1"); shift; done ;;
    -*)
      echo "ERROR: verify-touched.sh: unknown flag: $1" >&2
      exit 2
      ;;
    *) EXPLICIT_PATHS+=("$1"); shift ;;
  esac
done

[ -z "$TIMINGS_FILE" ] && TIMINGS_FILE="$(mktemp -t verify-touched-timings.XXXXXX)"
echo "verify-touched.sh: timings file (diagnostic-only; NOT an input to suite-cost-hints.txt): ${TIMINGS_FILE}"

# ─── tree_roots resolution ──────────────────────────────────────────────────────────────────────
INVOCATION_ROOT="$(pwd)"
declare -a TREE_ROOTS=()
if [ -n "$TREE_ROOTS_ARG" ]; then
  IFS=',' read -r -a TREE_ROOTS <<< "$TREE_ROOTS_ARG"
else
  while IFS= read -r _vt_r; do
    [ -n "$_vt_r" ] && TREE_ROOTS+=("$_vt_r")
  done < <(verification_scope_tree_roots "$INVOCATION_ROOT")
  unset _vt_r
fi
[ "${#TREE_ROOTS[@]}" -eq 0 ] && TREE_ROOTS=(".")

# project_suite_roots are additional roots this invocation also covers (see header "DUAL-MODE,
# PER-ROOT run-all.sh RESOLUTION" and repo-level-declarations.md's verification_scope schema).
declare -a PROJECT_SUITE_ROOTS=()
while IFS= read -r _vt_r; do
  [ -n "$_vt_r" ] && PROJECT_SUITE_ROOTS+=("$_vt_r")
done < <(verification_scope_project_suite_roots "$INVOCATION_ROOT")
unset _vt_r
declare -a ALL_ROOTS=("${TREE_ROOTS[@]}" "${PROJECT_SUITE_ROOTS[@]}")

# _vt_resolve_run_all_sh <root> -- stdout: the resolved run-all.sh path for <root> under the
# dual-mode, deployed-mirror-first / source-store-second pattern; empty (rc 1) if neither exists.
_vt_resolve_run_all_sh() {
  local _vt_root="$1"
  local -a _vt_candidates=(
    "${_vt_root}/.claude/scripts/tests/run-all.sh"
    "${_vt_root}/agent-system/extensions/core/scripts/tests/run-all.sh"
  )
  local _vt_c
  for _vt_c in "${_vt_candidates[@]}"; do
    if [ -f "$_vt_c" ]; then
      printf '%s\n' "$_vt_c"
      return 0
    fi
  done
  return 1
}

# --full-sweep: skip resolution/classification entirely.
if [ "$FULL_SWEEP" = "true" ]; then
  overall_rc=0
  for root in "${ALL_ROOTS[@]}"; do
    ra="$(_vt_resolve_run_all_sh "$root")" || {
      echo "Note: verify-touched.sh --full-sweep: neither a deployed .claude/ mirror nor an agent-system source-store tree resolves under root '${root}'; skipping this root." >&2
      continue
    }
    echo "verify-touched.sh --full-sweep: running the complete, unnarrowed battery at root '${root}' (${ra})"
    _vt_fs_tag="root"
    [ "$root" = "." ] || _vt_fs_tag="$(basename "$root" | tr -c 'A-Za-z0-9_-' '_')"
    bash "$ra" --jobs "$JOBS" --timings "${TIMINGS_FILE}.${_vt_fs_tag}.full-sweep" || overall_rc=1
  done
  echo "verify-touched.sh: --full-sweep requested -- ran the complete, unnarrowed battery at every resolved root (this IS a full-battery pass, not a touched-path narrowing)."
  exit "$overall_rc"
fi

# ─── Touched-path derivation ────────────────────────────────────────────────────────────────────
declare -a TOUCHED=()
if [ "${#EXPLICIT_PATHS[@]}" -gt 0 ]; then
  TOUCHED=("${EXPLICIT_PATHS[@]}")
else
  if [ -z "$BASE_REF" ]; then
    BASE_REF="$(git -C "$INVOCATION_ROOT" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)"
    BASE_REF="${BASE_REF#origin/}"
    if [ -z "$BASE_REF" ]; then
      BASE_REF="$(git -C "$INVOCATION_ROOT" config --get init.defaultBranch 2>/dev/null)"
    fi
    [ -z "$BASE_REF" ] && BASE_REF="HEAD"
  fi

  declare -A _vt_seen=()
  _vt_merge_base="$(git -C "$INVOCATION_ROOT" merge-base "$BASE_REF" HEAD 2>/dev/null)"
  if [ -n "$_vt_merge_base" ]; then
    while IFS= read -r _vt_p; do
      [ -n "$_vt_p" ] || continue
      [ -z "${_vt_seen[$_vt_p]:-}" ] && { TOUCHED+=("$_vt_p"); _vt_seen[$_vt_p]=1; }
    done < <(git -C "$INVOCATION_ROOT" diff --name-only "$_vt_merge_base" HEAD 2>/dev/null)
  fi
  while IFS= read -r _vt_p; do
    [ -n "$_vt_p" ] || continue
    [ -z "${_vt_seen[$_vt_p]:-}" ] && { TOUCHED+=("$_vt_p"); _vt_seen[$_vt_p]=1; }
  done < <(git -C "$INVOCATION_ROOT" diff --name-only HEAD 2>/dev/null)
  while IFS= read -r _vt_p; do
    [ -n "$_vt_p" ] || continue
    [ -z "${_vt_seen[$_vt_p]:-}" ] && { TOUCHED+=("$_vt_p"); _vt_seen[$_vt_p]=1; }
  done < <(git -C "$INVOCATION_ROOT" ls-files --others --exclude-standard 2>/dev/null)
  unset _vt_seen _vt_merge_base _vt_p
fi

if [ "${#TOUCHED[@]}" -eq 0 ]; then
  echo "verify-touched.sh: no touched paths detected (derivation against --base '${BASE_REF:-HEAD}' and the working tree both empty) -- nothing to verify."
  exit 0
fi

echo "verify-touched.sh: ${#TOUCHED[@]} touched path(s):"
printf '    %s\n' "${TOUCHED[@]}"

# ─── Preflight (strictly before resolution; see header) ────────────────────────────────────────
# Read through the SAME env-var overrides suite-resolver-lib.sh / unmapped-fallback-lib.sh
# themselves honour (SUITE_RESOLVER_MAP_DATA / UNMAPPED_FALLBACK_NOCLASS_DATA), so the preflight
# always validates the exact files resolution will actually consult -- never a second, divergent
# path computation.
MAP_DATA="${SUITE_RESOLVER_MAP_DATA:-${SCRIPT_DIR}/tests/suite-selection-map.data}"
NOCLASS_DATA="${UNMAPPED_FALLBACK_NOCLASS_DATA:-${SCRIPT_DIR}/tests/suite-selection-noclass.data}"

_vt_suite_exists() {
  local _vt_s="$1"
  [ -f "${SCRIPT_DIR}/tests/${_vt_s}" ] || [ -f "${SCRIPT_DIR}/${_vt_s}" ]
}

_vt_preflight_fail() {
  echo "FINDING preflight verify-touched.sh could not run: $1" >&2
  exit 2
}

_vt_preflight_check_data_file() {
  local _vt_file="$1"
  local _vt_col="$2"
  [ -f "$_vt_file" ] || return 0
  local _vt_lineno=0 _vt_glob _vt_names _vt_reason
  while IFS=$'\t' read -r _vt_glob _vt_names _vt_reason; do
    _vt_lineno=$((_vt_lineno + 1))
    case "$_vt_glob" in ""|"#"*) continue ;; esac
    if [ -z "${_vt_names:-}" ] || [ -z "${_vt_reason:-}" ]; then
      _vt_preflight_fail "${_vt_file} line ${_vt_lineno}: malformed row (expected 3 TAB-separated fields: path_glob, ${_vt_col}, reason)"
    fi
    local -a _vt_name_arr=()
    IFS=',' read -r -a _vt_name_arr <<< "$_vt_names"
    local _vt_n
    for _vt_n in "${_vt_name_arr[@]}"; do
      [ -n "$_vt_n" ] || continue
      if ! _vt_suite_exists "$_vt_n"; then
        _vt_preflight_fail "${_vt_file} line ${_vt_lineno}: names '${_vt_n}', which does not exist at ${SCRIPT_DIR}/tests/${_vt_n} or ${SCRIPT_DIR}/${_vt_n}"
      fi
    done
  done < "$_vt_file"
  return 0
}

_vt_preflight_check_data_file "$MAP_DATA" "suites"
_vt_preflight_check_data_file "$NOCLASS_DATA" "lints"

_vt_fallback_set="$(suite_selection_by_cost_class "$(unmapped_fallback_cost_class)" 2>/dev/null)"
if [ -z "$_vt_fallback_set" ]; then
  _vt_preflight_fail "the declared OWED fallback set (suite_selection_by_cost_class '$(unmapped_fallback_cost_class)') is empty -- an owed path would have nothing to run against it now"
fi
unset _vt_fallback_set

_vt_declared_backend="$(verification_scope_resolver_command "$INVOCATION_ROOT" 2>/dev/null)"
if [ -n "$_vt_declared_backend" ]; then
  if ! suite_resolver_conformance_check "$_vt_declared_backend" "$INVOCATION_ROOT"; then
    _vt_preflight_fail "declared resolver backend '${_vt_declared_backend}' failed suite_resolver_conformance_check (see the REFUSED line above for the specific violation)"
  fi
fi
unset _vt_declared_backend

echo "verify-touched.sh: preflight passed (map/class data parse, every named suite exists, the OWED fallback set is non-empty, any declared backend conforms)."

# ─── Resolve + classify ─────────────────────────────────────────────────────────────────────────
declare -a RESOLVE_OUT=()
mapfile -t RESOLVE_OUT < <(suite_resolver_resolve "$INVOCATION_ROOT" "${TOUCHED[@]}")

declare -a RESOLVED_SUITES=()
declare -a UNRESOLVED_PATHS=()
declare -A _vt_suite_seen=()
for _vt_line in "${RESOLVE_OUT[@]:-}"; do
  case "$_vt_line" in
    "SELECT "*)
      _vt_tok="${_vt_line#SELECT }"
      if [ -z "${_vt_suite_seen[$_vt_tok]:-}" ]; then
        RESOLVED_SUITES+=("$_vt_tok")
        _vt_suite_seen[$_vt_tok]=1
      fi
      ;;
    "UNRESOLVED "*)
      UNRESOLVED_PATHS+=("${_vt_line#UNRESOLVED }")
      ;;
  esac
done
unset _vt_line _vt_tok _vt_suite_seen

declare -a NOCLASS_SUITES=()
declare -a OWED_PATHS=()
declare -a NOCLASS_LINES=()
if [ "${#UNRESOLVED_PATHS[@]}" -gt 0 ]; then
  declare -a CLASSIFY_OUT=()
  mapfile -t CLASSIFY_OUT < <(unmapped_fallback_classify "${TASK_DIR:-/dev/null/no-task-dir}" "$SESSION_ID" "$DISPATCH_SEQ" "${UNRESOLVED_PATHS[@]}")
  declare -A _vt_noclass_seen=()
  for _vt_line in "${CLASSIFY_OUT[@]:-}"; do
    IFS=$'\t' read -r _vt_tag _vt_path _vt_rest <<< "$_vt_line"
    case "$_vt_tag" in
      NO-SUITE-BY-CLASS)
        NOCLASS_LINES+=("$_vt_line")
        IFS=',' read -r -a _vt_lint_arr <<< "$_vt_rest"
        for _vt_lint in "${_vt_lint_arr[@]:-}"; do
          [ -n "$_vt_lint" ] || continue
          if [ -z "${_vt_noclass_seen[$_vt_lint]:-}" ]; then
            NOCLASS_SUITES+=("$_vt_lint")
            _vt_noclass_seen[$_vt_lint]=1
          fi
        done
        ;;
      OWED)
        OWED_PATHS+=("$_vt_path")
        ;;
    esac
  done
  unset _vt_line _vt_tag _vt_path _vt_rest _vt_lint_arr _vt_lint _vt_noclass_seen
fi

if [ -z "${TASK_DIR:-}" ] && [ "${#OWED_PATHS[@]}" -gt 0 ]; then
  echo "WARNING: verify-touched.sh: ${#OWED_PATHS[@]} owed path(s) with no --task-dir given -- reported below but NOT durably recorded. Pass --task-dir to write records/full-sweep-owed.jsonl." >&2
fi

# ─── Union MAIN_SUITES = resolved SELECT suites + NO-SUITE-BY-CLASS lints (a plain --only union;
# never combined with --cost-class, which intersects rather than unions with --only) ────────────
declare -a MAIN_SUITES=("${RESOLVED_SUITES[@]}" "${NOCLASS_SUITES[@]}")

echo ""
echo "verify-touched.sh: resolution summary"
if [ "${#RESOLVED_SUITES[@]}" -gt 0 ]; then
  echo "  SELECT (resolved via default/explicit-map/declared backend):"
  printf '      %s\n' "${RESOLVED_SUITES[@]}"
else
  echo "  SELECT: (none)"
fi
if [ "${#NOCLASS_LINES[@]}" -gt 0 ]; then
  echo "  NO-SUITE-BY-CLASS:"
  printf '      %s\n' "${NOCLASS_LINES[@]}"
fi
if [ "${#OWED_PATHS[@]}" -gt 0 ]; then
  echo "  OWED (fallback set: --cost-class $(unmapped_fallback_cost_class)):"
  printf '      %s\n' "${OWED_PATHS[@]}"
  if [ -n "${TASK_DIR:-}" ]; then
    echo "  owed record: ${TASK_DIR}/records/full-sweep-owed.jsonl"
  fi
fi

# ─── Run: per declared root, dual-mode resolve run-all.sh and invoke ───────────────────────────
overall_rc=0
any_root_ran=false
for root in "${ALL_ROOTS[@]}"; do
  ra="$(_vt_resolve_run_all_sh "$root")" || {
    echo "Note: verify-touched.sh: neither a deployed .claude/ mirror nor an agent-system source-store tree resolves under root '${root}'; skipping this root." >&2
    continue
  }
  any_root_ran=true
  if [ "$root" = "." ]; then
    root_tag="root"
  else
    root_tag="$(printf '%s' "$root" | tr -c 'A-Za-z0-9_-' '_')"
    [ -z "$root_tag" ] && root_tag="root"
  fi

  if [ "${#MAIN_SUITES[@]}" -gt 0 ]; then
    only_arg="$(IFS=,; echo "${MAIN_SUITES[*]}")"
    echo "verify-touched.sh: root '${root}' (${ra}) -- running ${#MAIN_SUITES[@]} selected suite(s): --only ${only_arg}"
    bash "$ra" --only "$only_arg" --jobs "$JOBS" --timings "${TIMINGS_FILE}.${root_tag}.main" || overall_rc=1
  fi

  if [ "${#OWED_PATHS[@]}" -gt 0 ]; then
    echo "verify-touched.sh: root '${root}' (${ra}) -- running the OWED fallback set: --cost-class $(unmapped_fallback_cost_class)"
    bash "$ra" --cost-class "$(unmapped_fallback_cost_class)" --jobs "$JOBS" --timings "${TIMINGS_FILE}.${root_tag}.owed-fallback" || overall_rc=1
  fi
done

if [ "$any_root_ran" = "false" ]; then
  echo "FINDING verify-touched.sh could not run: no declared root resolved either a deployed .claude/ mirror or an agent-system source-store tree." >&2
  exit 2
fi

# ─── Verdict (see header "VERDICT STRINGS") ─────────────────────────────────────────────────────
if [ "$overall_rc" -eq 0 ]; then
  echo "verify-touched.sh: touched-path run complete -- ${#MAIN_SUITES[@]} suite(s) selected, ${#OWED_PATHS[@]} owed, ${#NOCLASS_LINES[@]} no-suite-by-class, across ${#TOUCHED[@]} touched path(s) -- touched-path narrowed via verify-touched.sh, NOT a full-battery pass."
else
  echo "verify-touched.sh: touched-path run reported a failure -- see the run-all.sh output above (touched-path narrowed via verify-touched.sh, NOT a full-battery pass)."
fi

exit "$overall_rc"
