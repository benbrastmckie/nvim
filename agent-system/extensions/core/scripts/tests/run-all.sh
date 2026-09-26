#!/usr/bin/env bash
# run-all.sh - Discover and run every shell test suite across both documented test locations
# (scripts/tests/test-*.sh and flat scripts/test-*.sh), in every extension, and exit nonzero if
# any suite fails.
#
# This is the regression net every later shell-hygiene phase (strict-mode migration, boilerplate
# extraction) depends on, and the suite discovery engine behind verify-deploy.sh's Gate 8.
#
# Two independent directory shapes, auto-detected from this script's own location:
#   - Source-store mode: this file lives at
#     agent-system/extensions/<ext>/scripts/tests/run-all.sh. Suites live per-extension at
#     agent-system/extensions/*/scripts/tests/test-*.sh (narrow suites) and
#     agent-system/extensions/*/scripts/test-*.sh (broad/flat suites), per
#     context/standards/shell-script-testing.md's location rule. Every extension directory
#     directly under agent-system/extensions/ is scanned, not just core.
#   - Deployed mode: this file lives at .claude/scripts/tests/run-all.sh, where the deploy
#     merges every extension's scripts into one flat .claude/scripts/ tree. Suites live at
#     .claude/scripts/tests/test-*.sh and .claude/scripts/test-*.sh.
#
# Uses set -uo pipefail (NOT set -euo pipefail) deliberately: this is a counter-idiom harness
# (PASSED/FAILED style, one level up -- see suite-level PASS/FAIL counters below) that must keep
# running after an individual suite fails so it can report a complete summary. A runner that
# aborts at the first failing suite cannot fulfil its own job.
#
# Loud-skip discipline: a suite file that is not executable is reported as a named [SKIP] warning,
# never silently dropped -- an exec-bit regression must degrade to a visible warning, not a false
# green. Suites are invoked via `bash "$suite"` (not `"$suite"` directly) specifically so a lost
# exec bit does not turn "SKIPPED" into "PASSED (0 suites actually ran)".
#
# Zero discovered suites is treated as a harness failure (loud, nonzero exit), never as a silent
# pass -- per shell-script-testing.md's loud-skip discipline extended to the discovery step itself.
#
# Usage:
#   run-all.sh [--quiet] [--timings FILE]
#
# --quiet: suppress per-suite [RUN]/[PASS] narration; still prints [FAIL] lines and the final
#          summary line, so a caller (e.g. Gate 8 in verify-deploy.sh) can capture failures
#          without the full per-suite transcript.
#
# --timings FILE: additionally write one CSV row per discovered suite (suite_path,wall_ms,result)
#          plus a final aggregate row (TOTAL,wall_ms,PASS_COUNT/FAIL_COUNT/SKIP_COUNT/TOTAL) to
#          FILE. Strictly additive: absent this flag, stdout/stderr output and exit codes are
#          byte-identical to today's. Result is one of PASS, FAIL, or SKIP.
#
# Exit codes:
#   0  all discovered suites passed
#   1  one or more discovered suites failed
#   2  zero suites were discovered (harness failure, not a pass)
#
# Machine-greppable output: every failing suite prints a line of the exact form
#   [FAIL] <suite path>
# so a caller can extract failures with `grep '^\[FAIL\] '` regardless of --quiet.

set -uo pipefail

QUIET=false
TIMINGS_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=true; shift ;;
    --timings)
      if [ $# -lt 2 ]; then
        echo "ERROR: --timings requires a FILE argument" >&2
        exit 2
      fi
      TIMINGS_FILE="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

say() { [ "$QUIET" = "true" ] || echo "$@"; }

# ── Detect source-store vs. deployed layout ──────────────────────────────────
# Source-store mode: three levels up from scripts/tests/ is agent-system/extensions/, containing
# per-extension directories each with their own manifest.json (core/manifest.json in particular).
CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"

SUITES=()

if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
  MODE="source-store"
  EXTENSIONS_ROOT="$CANDIDATE_EXT_ROOT"
  say "[run-all] Mode: source-store (extensions root: $EXTENSIONS_ROOT)"

  for ext_dir in "$EXTENSIONS_ROOT"/*/; do
    ext_scripts="${ext_dir}scripts"
    [ -d "$ext_scripts" ] || continue

    # Narrow suites: scripts/tests/test-*.sh
    if [ -d "$ext_scripts/tests" ]; then
      for f in "$ext_scripts/tests"/test-*.sh; do
        [ -e "$f" ] || continue
        SUITES+=("$f")
      done
    fi

    # Broad/flat suites: scripts/test-*.sh (excluding the tests/ subdirectory, which is scanned
    # above, and excluding this runner itself even though "run-all.sh" never matches "test-*.sh").
    for f in "$ext_scripts"/test-*.sh; do
      [ -e "$f" ] || continue
      SUITES+=("$f")
    done
  done
else
  MODE="deployed"
  DEPLOY_SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  say "[run-all] Mode: deployed (scripts root: $DEPLOY_SCRIPTS_ROOT)"

  if [ -d "$DEPLOY_SCRIPTS_ROOT/tests" ]; then
    for f in "$DEPLOY_SCRIPTS_ROOT/tests"/test-*.sh; do
      [ -e "$f" ] || continue
      SUITES+=("$f")
    done
  fi

  for f in "$DEPLOY_SCRIPTS_ROOT"/test-*.sh; do
    [ -e "$f" ] || continue
    SUITES+=("$f")
  done
fi

# Exclude this script itself, defensively (it never matches test-*.sh, but guards against a
# future rename).
FILTERED_SUITES=()
SELF_PATH="$(cd "$SCRIPT_DIR" && pwd)/$(basename "${BASH_SOURCE[0]}")"
for s in "${SUITES[@]}"; do
  s_abs="$(cd "$(dirname "$s")" && pwd)/$(basename "$s")"
  [ "$s_abs" = "$SELF_PATH" ] && continue
  FILTERED_SUITES+=("$s")
done
SUITES=("${FILTERED_SUITES[@]}")

TOTAL_DISCOVERED="${#SUITES[@]}"

if [ "$TOTAL_DISCOVERED" -eq 0 ]; then
  echo "[run-all] [FAIL] zero test suites discovered -- this is a harness failure, not a pass." >&2
  echo "[run-all] Checked mode: $MODE" >&2
  exit 2
fi

say "[run-all] Discovered $TOTAL_DISCOVERED suite(s)."
say ""

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

SUITE_OUT="$(mktemp)"
trap 'rm -f "$SUITE_OUT"' EXIT

if [ -n "$TIMINGS_FILE" ]; then
  : > "$TIMINGS_FILE"
fi

SUITE_RUN_START_MS="$(date +%s%3N)"

for suite in "${SUITES[@]}"; do
  suite_name="$suite"
  if [ ! -x "$suite" ]; then
    echo "[run-all] [SKIP] not executable (exec-bit regression?): $suite_name" >&2
    SKIP_COUNT=$((SKIP_COUNT + 1))
    if [ -n "$TIMINGS_FILE" ]; then
      echo "${suite_name},0,SKIP" >> "$TIMINGS_FILE"
    fi
    continue
  fi

  say "[run-all] [RUN]  $suite_name"
  _suite_start_ms="$(date +%s%3N)"
  if ( bash "$suite" >"$SUITE_OUT" 2>&1 ); then
    _suite_result="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
    say "[run-all] [PASS] $suite_name"
  else
    _suite_result="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] $suite_name"
    if [ "$QUIET" = "true" ]; then
      tail -20 "$SUITE_OUT" | sed 's/^/    /'
    else
      cat "$SUITE_OUT" | sed 's/^/    /'
    fi
  fi
  _suite_end_ms="$(date +%s%3N)"
  if [ -n "$TIMINGS_FILE" ]; then
    echo "${suite_name},$((_suite_end_ms - _suite_start_ms)),${_suite_result}" >> "$TIMINGS_FILE"
  fi
  : > "$SUITE_OUT"
done

SUITE_RUN_END_MS="$(date +%s%3N)"

say ""
echo "[run-all] $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped, $TOTAL_DISCOVERED total"

if [ -n "$TIMINGS_FILE" ]; then
  echo "TOTAL,$((SUITE_RUN_END_MS - SUITE_RUN_START_MS)),${PASS_COUNT}/${FAIL_COUNT}/${SKIP_COUNT}/${TOTAL_DISCOVERED}" >> "$TIMINGS_FILE"
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
