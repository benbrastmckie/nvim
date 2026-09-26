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
#   run-all.sh [--quiet] [--timings FILE] [--jobs N|auto]
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
# --jobs N|auto: run up to N suites concurrently (default 1 -- sequential, byte-for-byte the same
#          code path and output as before this flag existed). `auto` resolves to `nproc`, capped
#          at 4 (see the rejected-alternatives note below this header for why a fixed cap, not a
#          bare nproc). Output is ALWAYS captured per-suite and emitted whole, in discovery order,
#          never streamed concurrently -- the `[FAIL] <path>` machine-greppable contract and the
#          final summary line are unaffected by job count. A suite the Phase 4 parallelism-safety
#          audit flagged as load-sensitive (ambient-load precaution, not a resource collision --
#          see the LOAD_SENSITIVE_BASENAMES list below) always runs alone, serially, before the
#          parallel pool starts, regardless of --jobs. Scheduling within the parallel pool is
#          longest-first, using the advisory, optional suite-cost-hints.txt file (see its own
#          header) -- a missing, stale, or partial hint file only biases scheduling suboptimally,
#          never skips, duplicates, or reorders away a suite (enforced by an assertion that the
#          built schedule's length equals the discovered count). Nested-invocation guard: if
#          RUN_ALL_NESTED=1 is already set in the environment (this run was itself launched from
#          inside another run-all.sh's suite, e.g. via verify-deploy.sh's Gate 8 recursing into a
#          suite that calls verify-deploy.sh), --jobs is forced to 1 regardless of what was passed,
#          and RUN_ALL_NESTED=1 is (re-)exported for the remainder of this run so a further level
#          of nesting also stays sequential.
#
# Rejected alternatives for --jobs (recorded so a future reader does not re-propose them):
#   - A self-maintaining timing cache written on every run: rejected because it adds mutable state
#     to the tree, with gitignore and deploy-hygiene consequences that a one-shot, human-reviewed,
#     checked-in suite-cost-hints.txt does not have.
#   - File size (line count) as a cost proxy instead of measured wall time: rejected because the
#     measurements disprove it -- test-verify-deploy-context-budget.sh (261 lines) cost ~391s
#     pre-Phase-3 while test-orchestrate-cycle-plan.sh (3,839 lines) cost ~45s. Line count and
#     wall-clock cost are not correlated in this suite.
#   - A bare `nproc` for `auto` with no cap: rejected because several suites in the parallel pool
#     rsync a ~16MB fixture tree or launch headless nvim; N concurrent copies on a many-core box
#     multiplies peak disk and memory well past what those suites were sized for individually.
#
# Exit codes:
#   0  all discovered suites passed
#   1  one or more discovered suites failed
#   2  zero suites were discovered (harness failure, not a pass), or an internal scheduling
#      invariant was violated (scheduled count != discovered count)
#
# Machine-greppable output: every failing suite prints a line of the exact form
#   [FAIL] <suite path>
# so a caller can extract failures with `grep '^\[FAIL\] '` regardless of --quiet or --jobs.

set -uo pipefail

QUIET=false
TIMINGS_FILE=""
JOBS=1
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
    --jobs)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --jobs requires N or 'auto'" >&2
        exit 2
      fi
      JOBS="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,84p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# --jobs auto -> nproc, capped at 4 (see the rejected-alternatives note in the header for why a
# cap, not a bare nproc).
JOBS_CAP=4
if [ "$JOBS" = "auto" ]; then
  if command -v nproc >/dev/null 2>&1; then
    JOBS="$(nproc)"
  else
    JOBS=1
  fi
  [ "$JOBS" -gt "$JOBS_CAP" ] && JOBS="$JOBS_CAP"
elif ! printf '%s' "$JOBS" | grep -qE '^[0-9]+$' || [ "$JOBS" -lt 1 ]; then
  echo "ERROR: --jobs: invalid value '$JOBS' (must be a positive integer or 'auto')" >&2
  exit 2
fi

# Nested-invocation guard: a run-all.sh launched FROM one of this run's own suites (e.g. a suite
# that shells out to verify-deploy.sh, whose Gate 8 is run-all.sh itself) must never multiply job
# counts. If we are already nested, force sequential regardless of what --jobs requested.
if [ "${RUN_ALL_NESTED:-}" = "1" ]; then
  JOBS=1
fi
export RUN_ALL_NESTED=1

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

if [ -n "$TIMINGS_FILE" ]; then
  : > "$TIMINGS_FILE"
fi

SUITE_RUN_START_MS="$(date +%s%3N)"

if [ "$JOBS" -le 1 ]; then
  # ── Sequential path (--jobs 1, the default) ───────────────────────────────────
  # Byte-for-byte the same code path and output as before --jobs existed. Do not fold this into
  # the parallel path below -- it is kept as its own branch specifically so "at --jobs 1 the code
  # path and output must be exactly today's" is trivially true by inspection, not by argument.
  SUITE_OUT="$(mktemp)"
  trap 'rm -f "$SUITE_OUT"' EXIT

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
else
  # ── Parallel path (--jobs N > 1) ───────────────────────────────────────────────
  # Output is captured per-suite (never streamed concurrently) and emitted whole, in discovery
  # order, at the very end -- so the [FAIL]/[SKIP] machine-greppable contract and the final
  # summary line are unaffected by job count.
  OUT_DIR="$(mktemp -d)"
  trap 'rm -rf "$OUT_DIR"' EXIT

  # Phase 4 parallelism-safety audit verdicts (full 96-suite table:
  # specs/261_reduce_process_spawn_amplification_in_tests/progress/phase-4-audit-table.txt), PLUS
  # one suite found load-sensitive by Phase 6's own repeated-run flakiness gate (it postdates
  # Phase 4's audit, having been created in Phase 5). These 5 suites carry real wall-clock-budget
  # or lock-contention/memory-pressure assertions and are run alone, serially, before the parallel
  # pool starts -- an ambient-load precaution, NOT a resource-collision requirement (the audit
  # found zero suites with a fixed port/socket/lock path outside their own fixture, so no pairwise
  # conflict exists to avoid).
  #   - test-lake-build-guard.sh: real /proc/meminfo pressure checks, flock+sleep contention
  #   - test-state-write-concurrency.sh: deliberate real lock contention, sub-second sleeps
  #   - test-state-write-regen-timing.sh: real SCOPE_MUTEX_ACQUIRE_BUDGET_MS / REGEN_STUB_BUDGET_SEC
  #   - test-four-tier-conflict.sh: TASK_LOCK_RETRY_BUDGET_MS=5000 budget-bound wall-clock assertion
  #   - test-run-all-parallel.sh: its own case3/case4 measure real wall-clock elapsed time
  #     (parallel vs. forced-sequential) against a synthetic fixture. Flaked twice during Phase 6's
  #     flakiness gate under genuine ambient HOST load (other unrelated heavy processes on a
  #     shared dev machine, not sibling suites in this run-all.sh's own pool -- confirmed because
  #     serializing it here alone did NOT fix the flake). The suite's own timing assertions were
  #     separately redesigned to a load-tolerant RELATIVE ratio (parallel time <= 75% of
  #     forced-sequential time, both measured back-to-back) instead of absolute-ms thresholds --
  #     see that file's own case3/4 comment for the full account. It stays in this list anyway as
  #     a cheap defense-in-depth measure, not because serialization alone was the fix.
  LOAD_SENSITIVE_BASENAMES=(
    "test-lake-build-guard.sh"
    "test-state-write-concurrency.sh"
    "test-state-write-regen-timing.sh"
    "test-four-tier-conflict.sh"
    "test-run-all-parallel.sh"
  )
  is_load_sensitive() {
    local base
    base="$(basename "$1")"
    local n
    for n in "${LOAD_SENSITIVE_BASENAMES[@]}"; do
      [ "$base" = "$n" ] && return 0
    done
    return 1
  }

  SKIP_INDICES=()
  EXEC_INDICES=()
  for i in "${!SUITES[@]}"; do
    if [ -x "${SUITES[i]}" ]; then
      EXEC_INDICES+=("$i")
    else
      SKIP_INDICES+=("$i")
    fi
  done

  LOAD_SENSITIVE_INDICES=()
  POOL_INDICES=()
  for i in "${EXEC_INDICES[@]}"; do
    if is_load_sensitive "${SUITES[i]}"; then
      LOAD_SENSITIVE_INDICES+=("$i")
    else
      POOL_INDICES+=("$i")
    fi
  done

  # Longest-first scheduling within the parallel pool, from the advisory, optional
  # suite-cost-hints.txt (basename,wall_ms -- see that file's own header). A missing, stale, or
  # partial hint file only biases scheduling suboptimally: an unhinted suite simply keeps
  # discovery order, appended after any hinted ones -- never skipped, duplicated, or reordered
  # away from the schedule entirely (enforced by the TOTAL_ACCOUNTED assertion below).
  COST_HINTS_FILE="$SCRIPT_DIR/suite-cost-hints.txt"
  declare -A HINT_COST=()
  if [ -f "$COST_HINTS_FILE" ]; then
    while IFS=',' read -r hint_base hint_ms; do
      [ -n "$hint_base" ] || continue
      case "$hint_base" in \#*) continue ;; esac
      HINT_COST["$hint_base"]="$hint_ms"
    done < "$COST_HINTS_FILE"
  fi

  HINTED_POOL=()
  UNHINTED_POOL=()
  for i in "${POOL_INDICES[@]}"; do
    _base="$(basename "${SUITES[i]}")"
    if [ -n "${HINT_COST[$_base]:-}" ]; then
      HINTED_POOL+=("$i")
    else
      UNHINTED_POOL+=("$i")
    fi
  done

  if [ "${#HINTED_POOL[@]}" -gt 0 ]; then
    mapfile -t HINTED_POOL < <(
      for i in "${HINTED_POOL[@]}"; do
        _base="$(basename "${SUITES[i]}")"
        echo "${HINT_COST[$_base]} $i"
      done | sort -rn -k1,1 | awk '{print $2}'
    )
  fi

  SCHEDULE_POOL=("${HINTED_POOL[@]}" "${UNHINTED_POOL[@]}")

  # Safety assertion, checked BEFORE anything runs: every discovered suite must land in exactly
  # one of SKIP / LOAD_SENSITIVE / POOL.
  TOTAL_ACCOUNTED=$(( ${#SKIP_INDICES[@]} + ${#LOAD_SENSITIVE_INDICES[@]} + ${#SCHEDULE_POOL[@]} ))
  if [ "$TOTAL_ACCOUNTED" -ne "$TOTAL_DISCOVERED" ]; then
    echo "[run-all] [FAIL] internal scheduling error: accounted for $TOTAL_ACCOUNTED of $TOTAL_DISCOVERED discovered suites" >&2
    exit 2
  fi

  declare -a SUITE_RESULT=()
  declare -a SUITE_MS=()
  for i in "${SKIP_INDICES[@]}"; do
    SUITE_RESULT[i]="SKIP"
    SUITE_MS[i]=0
  done

  run_one() {
    # Usage: run_one INDEX -- writes rc.$i and ms.$i under $OUT_DIR; suite output to out.$i.
    local i="$1"
    local suite="${SUITES[i]}"
    local start end
    start="$(date +%s%3N)"
    if bash "$suite" >"$OUT_DIR/out.$i" 2>&1; then
      echo 0 > "$OUT_DIR/rc.$i"
    else
      echo 1 > "$OUT_DIR/rc.$i"
    fi
    end="$(date +%s%3N)"
    echo "$((end - start))" > "$OUT_DIR/ms.$i"
  }

  for i in "${LOAD_SENSITIVE_INDICES[@]}"; do
    say "[run-all] [RUN]  ${SUITES[i]} (load-sensitive: serialized, not in the parallel pool)"
    run_one "$i"
  done

  active=0
  for i in "${SCHEDULE_POOL[@]}"; do
    while [ "$active" -ge "$JOBS" ]; do
      wait -n
      active=$((active - 1))
    done
    run_one "$i" &
    active=$((active + 1))
  done
  wait

  for i in "${LOAD_SENSITIVE_INDICES[@]}" "${SCHEDULE_POOL[@]}"; do
    _rc="$(cat "$OUT_DIR/rc.$i" 2>/dev/null || echo 1)"
    SUITE_MS[i]="$(cat "$OUT_DIR/ms.$i" 2>/dev/null || echo 0)"
    if [ "$_rc" -eq 0 ]; then
      SUITE_RESULT[i]="PASS"
    else
      SUITE_RESULT[i]="FAIL"
    fi
  done

  # Emit whole, in discovery order -- never streamed concurrently.
  for i in "${!SUITES[@]}"; do
    suite="${SUITES[i]}"
    case "${SUITE_RESULT[i]}" in
      SKIP)
        echo "[run-all] [SKIP] not executable (exec-bit regression?): $suite" >&2
        SKIP_COUNT=$((SKIP_COUNT + 1))
        ;;
      PASS)
        say "[run-all] [RUN]  $suite"
        PASS_COUNT=$((PASS_COUNT + 1))
        say "[run-all] [PASS] $suite"
        ;;
      FAIL)
        say "[run-all] [RUN]  $suite"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo "[FAIL] $suite"
        if [ "$QUIET" = "true" ]; then
          tail -20 "$OUT_DIR/out.$i" | sed 's/^/    /'
        else
          cat "$OUT_DIR/out.$i" | sed 's/^/    /'
        fi
        ;;
    esac
    if [ -n "$TIMINGS_FILE" ]; then
      echo "${suite},${SUITE_MS[i]:-0},${SUITE_RESULT[i]}" >> "$TIMINGS_FILE"
    fi
  done
fi

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
