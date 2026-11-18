#!/usr/bin/env bash
# report-suite-coverage.sh - Coverage convergence report: lists every tracked (or untracked-but-
# not-ignored) file under the given scope that resolves to NO suite (default basename resolution,
# scripts/lib/suite-resolver-lib.sh's declared-backend composition included), NO explicit map row
# (scripts/tests/suite-selection-map.data), and NO class row
# (scripts/tests/suite-selection-noclass.data) -- i.e. a file that would be classified OWED, NOT
# PAID if it were touched today. The purpose is convergence: a maintainer reads this roster and
# adds a map or class row for whichever entries deserve one, shrinking the roster over time.
#
# THIS IS NEVER A BLOCKING GATE (decision recorded, rejected alternative stated plainly): the map
# is expected to converge GRADUALLY as new files land and existing ones are resolved by hand. A
# nonzero count printed here is informational, not a failure, by default -- registering this as a
# blocking verify-deploy.sh gate was rejected because it would refuse every commit until
# convergence completed, a throughput reduction with no corresponding gain in what eventually
# runs (the owed-not-paid fallback already guarantees every unconverged touched path still runs
# SOMETHING now and is tracked as owed until the batch gate discharges it -- this report is a
# CONVERGENCE AID on top of that guarantee, not a substitute for it). `--strict` exists for a
# caller that explicitly wants a nonzero exit on a nonzero count (e.g. a CI job tracking
# convergence progress over time), never as this script's own default posture.
#
# Usage:
#   report-suite-coverage.sh [--path-scope PATH] [--strict] [-h|--help]
#
#   --path-scope PATH   Scope the enumeration to this repo-root-relative path (passed straight
#                        through to git_corpus_enum). Default: "." (the whole tree).
#   --strict             Exit 1 when the unconverged roster is nonzero. Default: always exit 0.
#
# Enumeration reuses scripts/lib/git-corpus-enum-lib.sh's `git_corpus_enum` (the tracked +
# untracked-but-not-ignored union) rather than a new walk -- see that library's own header for why
# a bare `git ls-files` alone is a false-clean risk for an uncommitted new file.
#
# NO-CLASS LOOKUP: this script re-implements the identical glob-match lookup
# scripts/lib/unmapped-fallback-lib.sh's internal `_umf_noclass_lookup` already performs, rather
# than calling that library's public `unmapped_fallback_classify` -- deliberately: that function
# ALSO writes a durable owed record for every OWED path it classifies (the correct behaviour for
# a real touched-path run), and calling it here would spuriously populate
# records/full-sweep-owed.jsonl for this report's entire whole-tree unconverged backlog on every
# run. This report is read-only by design; the small duplicated lookup keeps it that way without
# widening the library's public contract or this phase's own file scope.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for _rsc_lib in git-corpus-enum-lib.sh suite-selection-lib.sh suite-resolver-lib.sh verification-scope-lib.sh; do
  if [ -f "${SCRIPT_DIR}/lib/${_rsc_lib}" ]; then
    # shellcheck disable=SC1090
    . "${SCRIPT_DIR}/lib/${_rsc_lib}"
  else
    echo "ERROR: report-suite-coverage.sh: required library not found: ${SCRIPT_DIR}/lib/${_rsc_lib}" >&2
    exit 2
  fi
done
unset _rsc_lib

usage() {
  sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'
}

PATH_SCOPE="."
STRICT=false

while [ $# -gt 0 ]; do
  case "$1" in
    --path-scope)
      [ $# -ge 2 ] || { echo "ERROR: --path-scope requires PATH" >&2; exit 2; }
      PATH_SCOPE="$2"; shift 2 ;;
    --strict) STRICT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "ERROR: report-suite-coverage.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="${REPO_ROOT:-}"
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"
fi
if [ -z "$REPO_ROOT" ]; then
  REPO_ROOT="$(cd "${SCRIPT_DIR}/../../../.." 2>/dev/null && pwd)"
fi
if [ -z "$REPO_ROOT" ] || [ ! -d "$REPO_ROOT" ]; then
  echo "ERROR: report-suite-coverage.sh: could not resolve a repository root" >&2
  exit 2
fi

NOCLASS_DATA="${UNMAPPED_FALLBACK_NOCLASS_DATA:-${SCRIPT_DIR}/tests/suite-selection-noclass.data}"

# _rsc_noclass_lookup <path> -- 0 (true) iff <path> matches a row in NOCLASS_DATA; prints nothing,
# read-only. See header "NO-CLASS LOOKUP" for why this is a local re-implementation rather than a
# call into unmapped-fallback-lib.sh's public, record-writing function.
_rsc_noclass_lookup() {
  local _rsc_path="$1"
  local _rsc_glob _rsc_rest

  [ -f "$NOCLASS_DATA" ] || return 1

  while IFS=$'\t' read -r _rsc_glob _rsc_rest; do
    case "${_rsc_glob}" in
      ""|"#"*) continue ;;
    esac
    # shellcheck disable=SC2053
    if [[ "${_rsc_path}" == ${_rsc_glob} ]]; then
      return 0
    fi
  done < "$NOCLASS_DATA"

  return 1
}

declare -a ALL_FILES=()
while IFS= read -r _rsc_f; do
  [ -n "$_rsc_f" ] && ALL_FILES+=("$_rsc_f")
done < <(git_corpus_enum "$REPO_ROOT" "$PATH_SCOPE")
unset _rsc_f

if [ "${#ALL_FILES[@]}" -eq 0 ]; then
  echo "report-suite-coverage.sh: no files enumerated under scope '${PATH_SCOPE}' -- nothing to report."
  exit 0
fi

declare -a UNRESOLVED=()
mapfile -t _RSC_RESOLVE_OUT < <(suite_resolver_resolve "$REPO_ROOT" "${ALL_FILES[@]}")
for _rsc_line in "${_RSC_RESOLVE_OUT[@]:-}"; do
  case "$_rsc_line" in
    "UNRESOLVED "*) UNRESOLVED+=("${_rsc_line#UNRESOLVED }") ;;
  esac
done
unset _rsc_line _RSC_RESOLVE_OUT

declare -a UNCONVERGED=()
for _rsc_path in "${UNRESOLVED[@]:-}"; do
  [ -n "$_rsc_path" ] || continue
  if ! _rsc_noclass_lookup "$_rsc_path"; then
    UNCONVERGED+=("$_rsc_path")
  fi
done
unset _rsc_path

echo "report-suite-coverage.sh: scope '${PATH_SCOPE}', ${#ALL_FILES[@]} file(s) enumerated, ${#UNRESOLVED[@]} unresolved by suite/map, ${#UNCONVERGED[@]} with no suite, no map row, and no class row:"
if [ "${#UNCONVERGED[@]}" -gt 0 ]; then
  printf '    %s\n' "${UNCONVERGED[@]}"
fi
echo "report-suite-coverage.sh: unconverged count: ${#UNCONVERGED[@]}"

if [ "$STRICT" = "true" ] && [ "${#UNCONVERGED[@]}" -gt 0 ]; then
  exit 1
fi
exit 0
