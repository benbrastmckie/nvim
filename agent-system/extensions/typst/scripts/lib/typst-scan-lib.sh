#!/usr/bin/env bash
# typst-scan-lib.sh - Shared ANSI colors, CLI option parsing, and .typ-file collection for the
# typst extension's two quality-gate scripts (chapter-quality-check.sh, typst-element-lint.sh).
#
# Those two scripts are a mutual duplicate-block pair: 44 duplicate 10-line sliding-window hits
# each against the other (scripts/script-inventory.sh). The shared surface is the colored-output
# palette, the `PATH... [--verbose] [--help]` option-parsing loop, and the recursive `*.typ`
# directory-expansion loop that follows it -- every byte of each script up to its own first
# lint-specific function. This library extracts exactly that shared surface so it has one
# definition, sourced from both call sites, rather than two near-identical copies.
#
# Sourced only, never executed directly.
#
# Usage (both call sites, identical):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/typst-scan-lib.sh"
#
#   usage() { ... }   # each script defines its own help text BEFORE calling the functions below
#
#   typst_scan_parse_args "$@"   # populates VERBOSE and PATHS[]; calls the caller's usage() and
#                                 # exits 0 on --help/-h, or exits 2 on an unknown option or an
#                                 # empty PATHS[] result (same text/exit codes as the original
#                                 # inline loop in both scripts)
#   typst_scan_collect_files     # expands PATHS[] (files and/or directories) into TYP_FILES[];
#                                 # exits 2 on a nonexistent path or an empty TYP_FILES[] result
#
# Colors -- unchanged from both scripts' own pre-extraction literals. Each is used only by the
# sourcing script (both already reference $RED/$GREEN/$YELLOW/$BLUE/$NC throughout their own
# per-finding echo calls), never within this library itself, so shellcheck's single-file analysis
# cannot see the use and flags each as unused.
# shellcheck disable=SC2034 # consumed by the script that sources this library, not by this file
RED='\033[0;31m'
# shellcheck disable=SC2034 # consumed by the script that sources this library, not by this file
GREEN='\033[0;32m'
# shellcheck disable=SC2034 # consumed by the script that sources this library, not by this file
YELLOW='\033[1;33m'
# shellcheck disable=SC2034 # consumed by the script that sources this library, not by this file
BLUE='\033[0;34m'
# shellcheck disable=SC2034 # consumed by the script that sources this library, not by this file
NC='\033[0m'

# typst_scan_parse_args ARGS... -- parses argv for --verbose/-v, --help/-h, --, -*, and
# positional PATHs. Sets global VERBOSE (true/false) and global array PATHS. Requires the
# caller to have already defined its own usage() function (each script's help text differs).
typst_scan_parse_args() {
  # shellcheck disable=SC2034 # consumed by the sourcing script's own $VERBOSE checks, not here
  VERBOSE=false
  PATHS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v)
        VERBOSE=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          PATHS+=("$1")
          shift
        done
        ;;
      -*)
        echo "Error: unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
      *)
        PATHS+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#PATHS[@]} -eq 0 ]]; then
    echo "Error: no PATH given" >&2
    usage >&2
    exit 2
  fi
}

# typst_scan_collect_files -- expands global array PATHS (files and/or directories) into global
# array TYP_FILES (sorted *.typ files, directories walked recursively). Exits 2 if a given path
# does not exist, or if the resulting TYP_FILES set is empty.
typst_scan_collect_files() {
  TYP_FILES=()
  local p f
  for p in "${PATHS[@]}"; do
    if [[ -f "$p" ]]; then
      TYP_FILES+=("$p")
    elif [[ -d "$p" ]]; then
      while IFS= read -r -d '' f; do
        TYP_FILES+=("$f")
      done < <(find "$p" -type f -name '*.typ' -print0 | sort -z)
    else
      echo "Error: path does not exist: $p" >&2
      exit 2
    fi
  done

  if [[ ${#TYP_FILES[@]} -eq 0 ]]; then
    echo "Error: no .typ files found under the given path(s)" >&2
    exit 2
  fi
}
