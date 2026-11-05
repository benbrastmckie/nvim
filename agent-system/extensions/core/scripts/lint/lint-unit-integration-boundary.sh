#!/usr/bin/env bash
# lint-unit-integration-boundary.sh - Enforce the unit/integration classification declared in
# scripts/tests/suite-classification.data: a suite classified "unit" there must not spawn
# deploy-headless.sh, verify-deploy.sh, or (nested) tests/run-all.sh -- those three are full-
# system integration operations wearing a unit-test's clothing, and this corpus's own measured
# finding (58% of the hinted test-suite runtime pool sits in exactly these suites, see
# context/standards/shell-script-testing.md) is what this lint exists to keep from drifting back
# unnoticed.
#
# THE DATA FILE IS THE SOURCE OF TRUTH, NOT A CACHE OF THIS LINT'S OWN JUDGMENT
# ------------------------------------------------------------------------------
# scripts/tests/suite-classification.data declares each discovered suite's class by hand (one row
# per suite, "basename<TAB>class<TAB>reason" -- see that file's own header for the full grammar).
# This lint does NOT re-derive a suite's class from its content; it only checks two things against
# the declared class:
#   (a) BOUNDARY VIOLATION: a suite declared "unit" whose content references one of the three
#       heavyweight tool basenames -- the declared class disagrees with what the suite actually
#       does, so either the suite needs decoupling from the heavyweight tool or its own
#       classification needs to change to "integration" (with a stated reason).
#   (b) COVERAGE GAP: a suite discovered under the tests directory with NO row in the data file at
#       all. Per that file's own "adding a suite must be a data edit, not a documentation edit"
#       principle, an unclassified suite is itself a violation -- silently defaulting an
#       unclassified suite to either class would let the classification drift out of sync with
#       the corpus exactly the way an unenforced convention always does (this corpus's own
#       recurring finding; see the dispatch's "sixteen additive tasks against three reductive
#       ones" ratio).
# A STALE ROW (a classification entry naming a basename no longer discovered under the tests
# directory) is reported as an INFO note, never a violation -- the file not finding a line to
# delete is not a safety problem the way an unclassified live suite is, and treating it as a hard
# failure would make an unrelated suite's removal fail this lint.
#
# DETECTION MODEL FOR (a): a single literal basename match (`grep -qF`) for each of
# "deploy-headless.sh", "verify-deploy.sh", and "run-all.sh" against the suite's own file content
# -- the same conservative, cheap, over-counting-never-under-counting textual-reference method
# script-inventory.sh's own inbound_callers field already documents and suite-classification.data
# itself was derived with. A suite whose own content mentions one of these names only in a comment
# or a fixture string literal (never a real invocation) still trips this lint; reclassify it to
# "integration" with a stated reason rather than treating that as a false positive to suppress --
# matching this corpus's established "no suppression allowlist without hand-inspection" posture
# (see lint-test-harness-adoption.sh's own narrowly-reasoned ALLOWLIST for the one precedent, and
# note it required direct inspection before any entry was added).
#
# Usage: lint-unit-integration-boundary.sh [--verbose] [--tests-dir DIR] [--data FILE] [--help]
#   --tests-dir DIR   Directory to scan for discovered test-*.sh suites. Default: this script's
#                     own sibling ../tests/ directory. SCOPE NOTE: in the DEPLOYED tree that
#                     sibling directory is the flat merge of every extension's own
#                     scripts/tests/*.sh (deploy-headless.sh's per-extension merge) -- the actual
#                     set tests/run-all.sh (gate 8) discovers and runs in production -- while in
#                     the SOURCE STORE the equivalent path sees only this extension's (core's) own
#                     suites. suite-classification.data's own header documents the same scope
#                     distinction for its row coverage.
#   --data FILE       Classification data file. Default: <tests-dir>/suite-classification.data.
#   Both overrides exist for this lint's own fixture test, which plants a synthetic tests
#   directory and data file in a scratch workdir rather than mutating the real corpus.
#
# Exit codes:
#   0 - no violations found (stale-row INFO notes, if any, do not affect this)
#   1 - one or more violations found (boundary violation or unclassified live suite)
#   2 - environment/usage error (tests dir or data file not found, unknown argument)

set -uo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

VERBOSE=false
TESTS_DIR=""
DATA_FILE=""

usage() {
  sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --tests-dir)
      TESTS_DIR="${2:-}"
      if [[ -z "$TESTS_DIR" ]]; then
        echo "ERROR: --tests-dir requires a DIR argument" >&2
        exit 2
      fi
      shift 2
      ;;
    --data)
      DATA_FILE="${2:-}"
      if [[ -z "$DATA_FILE" ]]; then
        echo "ERROR: --data requires a FILE argument" >&2
        exit 2
      fi
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$TESTS_DIR" ]]; then
  TESTS_DIR="$(cd "$SCRIPT_DIR/../tests" 2>/dev/null && pwd || true)"
fi
if [[ -z "$TESTS_DIR" ]] || [[ ! -d "$TESTS_DIR" ]]; then
  echo "ERROR: tests directory not found: ${TESTS_DIR:-<unresolved>}" >&2
  exit 2
fi

if [[ -z "$DATA_FILE" ]]; then
  DATA_FILE="$TESTS_DIR/suite-classification.data"
fi
if [[ ! -f "$DATA_FILE" ]]; then
  echo "ERROR: classification data file not found: $DATA_FILE" >&2
  exit 2
fi

log_info() { $VERBOSE && echo "[INFO] $1" || true; }

VIOLATIONS=0
SUITES_CHECKED=0

# ── Load the data file into two associative arrays, keyed by basename ──────────────────────────
declare -A CLASS_OF=()
declare -A REASON_OF=()
while IFS=$'\t' read -r basename class reason; do
  [[ -z "$basename" ]] && continue
  [[ "$basename" == \#* ]] && continue
  CLASS_OF["$basename"]="$class"
  REASON_OF["$basename"]="${reason:-}"
done < "$DATA_FILE"

if [[ "${#CLASS_OF[@]}" -eq 0 ]]; then
  echo "ERROR: classification data file has zero parsed rows: $DATA_FILE" >&2
  exit 2
fi

# ── Discover suites, exactly as run-all.sh discovers them: test-*.sh files directly under
# TESTS_DIR (not recursive -- run-all.sh's own discovery is flat, matching this corpus's
# convention of one tests/ directory per extension, never a nested tests/tests/). ──────────────
declare -a DISCOVERED=()
while IFS= read -r -d '' f; do
  DISCOVERED+=("$(basename "$f")")
done < <(find "$TESTS_DIR" -maxdepth 1 -type f -name 'test-*.sh' -print0 2>/dev/null | sort -z)

if [[ "${#DISCOVERED[@]}" -eq 0 ]]; then
  echo "ERROR: zero test-*.sh suites discovered under $TESTS_DIR" >&2
  exit 2
fi

declare -A DISCOVERED_SET=()
for d in "${DISCOVERED[@]}"; do
  DISCOVERED_SET["$d"]=1
done

HEAVY_TOOLS=("deploy-headless.sh" "verify-deploy.sh" "run-all.sh")

for suite in "${DISCOVERED[@]}"; do
  SUITES_CHECKED=$((SUITES_CHECKED + 1))
  suite_path="$TESTS_DIR/$suite"

  if [[ -z "${CLASS_OF[$suite]:-}" ]]; then
    echo -e "${RED}[VIOLATION]${NC} $suite_path"
    echo "  Discovered under $TESTS_DIR with no row in $DATA_FILE. Adding a suite must be a data"
    echo "  edit: add 'basename<TAB>unit|integration<TAB>reason' to the classification file."
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi

  class="${CLASS_OF[$suite]}"
  reason="${REASON_OF[$suite]:-}"

  if [[ "$class" != "unit" && "$class" != "integration" ]]; then
    echo -e "${RED}[VIOLATION]${NC} $suite_path"
    echo "  Classification row for '$suite' has an unrecognized class '$class' (expected 'unit' or"
    echo "  'integration')."
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi

  if [[ "$class" == "integration" && ( -z "$reason" || "$reason" == "-" ) ]]; then
    echo -e "${RED}[VIOLATION]${NC} $suite_path"
    echo "  Classified 'integration' with no reason recorded (reason field is '-'); an"
    echo "  integration-class row must name which heavyweight tool(s) it invokes."
    VIOLATIONS=$((VIOLATIONS + 1))
    continue
  fi

  if [[ "$class" == "unit" ]]; then
    found=()
    for tool in "${HEAVY_TOOLS[@]}"; do
      if grep -qF "$tool" "$suite_path" 2>/dev/null; then
        found+=("$tool")
      fi
    done
    if [[ "${#found[@]}" -gt 0 ]]; then
      joined="$(IFS=,; echo "${found[*]}")"
      echo -e "${RED}[VIOLATION]${NC} $suite_path"
      echo "  Classified 'unit' in $DATA_FILE but its content references: $joined. A unit-class"
      echo "  suite must not spawn deploy-headless.sh, verify-deploy.sh, or run-all.sh. Either"
      echo "  remove the dependency on the heavyweight tool, or reclassify this row to"
      echo "  'integration' with a stated reason."
      VIOLATIONS=$((VIOLATIONS + 1))
      continue
    fi
  fi

  log_info "OK: $suite ($class)"
done

# ── Stale-row disclosure (INFO only, never a violation) ─────────────────────────────────────────
STALE=0
for basename in "${!CLASS_OF[@]}"; do
  if [[ -z "${DISCOVERED_SET[$basename]:-}" ]]; then
    STALE=$((STALE + 1))
    log_info "stale classification row (no longer discovered): $basename"
  fi
done
if [[ "$STALE" -gt 0 ]]; then
  echo -e "${YELLOW}[INFO]${NC} $STALE stale classification row(s) name a suite no longer discovered under $TESTS_DIR (re-run with --verbose for names)"
fi

echo ""
if [[ "$VIOLATIONS" -eq 0 ]]; then
  echo -e "${GREEN}[PASS]${NC} lint-unit-integration-boundary: 0 violation(s) across $SUITES_CHECKED discovered suite(s)"
  exit 0
else
  echo -e "${RED}[FAIL]${NC} lint-unit-integration-boundary: $VIOLATIONS violation(s) across $SUITES_CHECKED discovered suite(s)"
  exit 1
fi
