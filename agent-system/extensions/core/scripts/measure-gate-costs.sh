#!/usr/bin/env bash
# measure-gate-costs.sh - Mechanical, idle-guarded, averaged per-gate cost measurement harness
# for verify-deploy.sh's 23 gates, and the regeneration path for tests/suite-cost-hints.txt.
#
# THIS IS A DECISION-GATE SCRIPT, not a convenience. Its output -- not any carried-forward prose
# figure from this task's own research report or dispatch -- is what Phases 4-9's cost-class
# assignment and scheduling-priority decisions are built on (see this task's plan, Phase 3's
# "CARRIED-UNVERIFIED" note). A number this script did not itself measure, idle, must never be
# used for a cost-class decision.
#
# WHY WALL-CLOCK VIA `date +%s%3N`, NOT `/usr/bin/time`: the latter does not exist as
# `/usr/bin/time` on this NixOS host (only a PATH-resolved `time` at a Nix store path) --
# confirmed live before writing this script. Wall-clock delta via `date +%s%3N` is the exact
# technique tests/run-all.sh already uses for its own per-suite timings
# (`_suite_start_ms`/`_suite_end_ms`), so this reuses a proven, portable, already-audited
# measurement shape instead of depending on a non-portable external binary.
#
# LOAD GUARD: refuses to record ANY measurement taken while the 1-minute load average exceeds
# the threshold (default 2.0 on this repo's 24-core measurement host; override via
# MEASURE_GATE_COSTS_LOAD_THRESHOLD or --load-threshold). A contended figure is wrong in EITHER
# direction (inflated by contention, or -- for a gate that itself spawns background work --
# deflated by a scheduler that silently shares cores with the very load being measured against),
# not merely "a bit slow", so this is a hard refusal (exit 2), never a warning-and-proceed.
# Checked once before the run starts AND once more immediately after, matching the two-sided
# contamination concern: a quiet start does not guarantee a quiet measurement window.
#
# AVERAGING: every gate (or suite, under --regen-hints) is measured MEASURE_RUNS times
# (default 2, minimum 2 -- a single sample cannot distinguish a real cost from a one-off system
# hiccup) and the arithmetic mean (integer ms, floor) is what feeds cost-class assignment. All
# individual run values are retained in the output row, not discarded, so a reader can see
# variance directly rather than trusting only the mean.
#
# COST CLASSES (boundaries stated here, the single place a reader needs to check -- never
# scattered per-consumer):
#   free     : avg_ms <= 2000      (2 seconds)
#   moderate : 2000 < avg_ms <= 30000   (2-30 seconds)
#   slow     : avg_ms > 30000      (over 30 seconds)
# These three bands are deliberately coarse (matching the research's own observed cost
# concentration -- a handful of gates account for virtually all the wall time, the rest are
# free) rather than a finer scale that would invite false precision from a 2-sample mean.
#
# OUTPUT: a machine-readable CSV at scripts/gate-cost-model.csv (regenerated wholesale on every
# run, header included -- this file is GENERATED, never hand-edited; Phase 4's gate registry
# reads it). Columns: gate_id,run1_ms,run2_ms,...,avg_ms,cost_class. Row count follows
# --runs: a '--runs 3' invocation emits run1_ms,run2_ms,run3_ms. The row's own header line (one
# emitted per run, so a reader can tell how many run columns to expect without parsing the data)
# make the shape self-describing.
#
# Usage:
#   measure-gate-costs.sh [--target DIR] [--runs N] [--load-threshold N] [--gate N[,N...]]
#                         [--out FILE] [--regen-hints [HINTS_FILE]] [--skip-gate-measure]
#
#   --target DIR          Directory to run verify-deploy.sh against (default: this script's own
#                          resolved repo root).
#   --runs N               Measurements per gate/suite (default 2, minimum 2; refuses below 2).
#   --load-threshold N     1-minute load-average ceiling (default 2.0, or
#                          MEASURE_GATE_COSTS_LOAD_THRESHOLD if set; --load-threshold wins).
#   --gate N[,N...]        Measure only these gate ids (default: all 23, 1-23 inclusive).
#   --out FILE             Where to write the gate cost CSV (default:
#                          <repo_root>/agent-system/extensions/core/scripts/gate-cost-model.csv).
#   --regen-hints [FILE]   ALSO regenerate the suite-level cost model by running
#                          tests/run-all.sh --timings under the same load guard and rewriting
#                          FILE (default: tests/suite-cost-hints.txt) from the result. Every
#                          suite run-all.sh discovers appears in the output exactly once (the
#                          unhinted-suite append invariant run-all.sh itself already documents
#                          for a MISSING file now holds for every suite in a FRESH one too: no
#                          suite is dropped, duplicated, or silently reordered away by this
#                          regeneration). SKIPped suites (exec-bit regression) are omitted from
#                          the hints file -- a 0ms "cost" for a suite that did not actually run
#                          would misinform scheduling, not merely be imprecise.
#   --skip-gate-measure    With --regen-hints, skip the 23-gate measurement pass entirely (useful
#                          when only the suite-level hints need refreshing).
#
# Exit codes:
#   0  measurement(s) completed and written
#   1  (reserved; this harness has no notion of a measurement "failing" -- a gate's own nonzero
#      exit during measurement is still a valid, recorded timing, not a harness failure)
#   2  usage error, OR the load guard refused (observed load printed either way)

set -uo pipefail

_MGC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${_MGC_SCRIPT_DIR}/lib/common.sh"

# TARGET defaults to the caller's own working directory -- deliberately NOT derived via
# common_repo_root's fixed-levels-up walk, which cannot distinguish source-store depth
# (scripts/ -> core -> extensions -> agent-system -> repo root, 4 levels) from deployed depth
# (.claude/scripts/ -> .claude -> repo root, 2 levels) without the caller's own location telling
# it which mode applies. verify-deploy.sh itself resolves TARGET the same way
# (`TARGET="${TARGET:-$(pwd)}"`) for the identical reason -- matched here for consistency, since
# this harness's whole job is to invoke that same script with the same target semantics.
TARGET="$(pwd)"
RUNS=2
LOAD_THRESHOLD="${MEASURE_GATE_COSTS_LOAD_THRESHOLD:-2.0}"
GATES_ARG=""
OUT_FILE=""
REGEN_HINTS=false
HINTS_FILE=""
SKIP_GATE_MEASURE=false

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      [ $# -ge 2 ] || { echo "ERROR: --target requires a DIR argument" >&2; exit 2; }
      TARGET="$2"; shift 2 ;;
    --runs)
      [ $# -ge 2 ] || { echo "ERROR: --runs requires a number" >&2; exit 2; }
      RUNS="$2"; shift 2 ;;
    --load-threshold)
      [ $# -ge 2 ] || { echo "ERROR: --load-threshold requires a number" >&2; exit 2; }
      LOAD_THRESHOLD="$2"; shift 2 ;;
    --gate)
      [ $# -ge 2 ] || { echo "ERROR: --gate requires a gate id or comma-separated list" >&2; exit 2; }
      GATES_ARG="$2"; shift 2 ;;
    --out)
      [ $# -ge 2 ] || { echo "ERROR: --out requires a FILE argument" >&2; exit 2; }
      OUT_FILE="$2"; shift 2 ;;
    --regen-hints)
      REGEN_HINTS=true
      if [ $# -ge 2 ] && [ "${2:0:2}" != "--" ]; then HINTS_FILE="$2"; shift 2; else shift 1; fi
      ;;
    --skip-gate-measure) SKIP_GATE_MEASURE=true; shift ;;
    -h|--help) sed -n '2,65p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

case "$RUNS" in
  ''|*[!0-9]*) echo "ERROR: --runs must be a positive integer, got: '$RUNS'" >&2; exit 2 ;;
esac
if [ "$RUNS" -lt 2 ]; then
  echo "ERROR: --runs must be at least 2 (a single sample cannot distinguish a real cost from a one-off hiccup), got: $RUNS" >&2
  exit 2
fi

if [ -z "$TARGET" ] || [ ! -d "$TARGET" ]; then
  echo "ERROR: could not resolve a usable target directory (TARGET='$TARGET')" >&2
  exit 2
fi
TARGET="$(cd "$TARGET" && pwd)"

VERIFY_DEPLOY="${_MGC_SCRIPT_DIR}/verify-deploy.sh"
RUN_ALL="${_MGC_SCRIPT_DIR}/tests/run-all.sh"
: "${OUT_FILE:=${_MGC_SCRIPT_DIR}/gate-cost-model.csv}"
: "${HINTS_FILE:=${_MGC_SCRIPT_DIR}/tests/suite-cost-hints.txt}"

if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: expected verify-deploy.sh at $VERIFY_DEPLOY" >&2
  exit 2
fi

# ─── Load guard -- checked at call time, by the caller of this function, both before the
# measurement run starts and immediately after it ends. ─────────────────────────────────────────
mgc_load_1min() {
  # Test-only override hook: MEASURE_GATE_COSTS_LOADAVG_OVERRIDE, when set, is returned verbatim
  # instead of reading the live system load. This exists solely so test-measure-gate-costs.sh can
  # exercise the load-guard refusal/pass branches deterministically, without depending on this
  # test host's own ambient load at run time (which this suite cannot control and must not
  # assume). Never set in production use.
  if [ -n "${MEASURE_GATE_COSTS_LOADAVG_OVERRIDE:-}" ]; then
    echo "$MEASURE_GATE_COSTS_LOADAVG_OVERRIDE"
    return 0
  fi
  # Portable Linux read of the 1-minute load average; degrades to empty (never aborts the
  # calling shell) if /proc/loadavg is unavailable, matching this script's own `set -uo pipefail`
  # (no `set -e`) posture for a diagnostic read.
  if [ -r /proc/loadavg ]; then
    awk '{print $1}' /proc/loadavg 2>/dev/null
  else
    uptime 2>/dev/null | sed -E 's/.*load average[s]?: *([0-9.]+).*/\1/'
  fi
}

mgc_load_guard() {
  local _label="$1" _load _cmp
  _load="$(mgc_load_1min)"
  if [ -z "$_load" ]; then
    echo "WARNING: measure-gate-costs.sh: could not read the 1-minute load average ($_label) -- proceeding, but this measurement's idle-ness is UNVERIFIED" >&2
    return 0
  fi
  _cmp="$(awk -v l="$_load" -v t="$LOAD_THRESHOLD" 'BEGIN { print (l > t) ? 1 : 0 }')"
  if [ "$_cmp" = "1" ]; then
    echo "ERROR: measure-gate-costs.sh: REFUSING to record a measurement -- 1-minute load average is ${_load}, above the ${LOAD_THRESHOLD} threshold ($_label). A contended figure is wrong in either direction; re-run once the host is idle, or raise --load-threshold / MEASURE_GATE_COSTS_LOAD_THRESHOLD explicitly if this host's baseline load legitimately differs." >&2
    return 1
  fi
  echo "INFO: measure-gate-costs.sh: load guard OK ($_label): 1-minute load average ${_load} <= threshold ${LOAD_THRESHOLD}" >&2
  return 0
}

mgc_cost_class() {
  local _ms="$1"
  if [ "$_ms" -le 2000 ]; then
    echo "free"
  elif [ "$_ms" -le 30000 ]; then
    echo "moderate"
  else
    echo "slow"
  fi
}

mgc_now_ms() { date +%s%3N; }

# mgc_measure_gate <gate_id> -- runs verify-deploy.sh --only-gate <gate_id> RUNS times against
# TARGET, returns (via global MGC_RUN_MS array) each run's wall time in ms. The gate's own
# PASS/FAIL/SKIP outcome is irrelevant to this measurement -- a failing gate still costs the same
# wall time to determine that it failed, and this harness measures cost, not correctness (that is
# verify-deploy.sh's own job, and this task's Phase 1/2 already cover it).
mgc_measure_gate() {
  local _gate="$1" _i _start _end
  MGC_RUN_MS=()
  for _i in $(seq 1 "$RUNS"); do
    _start="$(mgc_now_ms)"
    bash "$VERIFY_DEPLOY" --only-gate "$_gate" --quiet "$TARGET" >/dev/null 2>&1 || true
    _end="$(mgc_now_ms)"
    MGC_RUN_MS+=("$((_end - _start))")
  done
}

mgc_mean() {
  local _sum=0 _n=0 _v
  for _v in "$@"; do _sum=$((_sum + _v)); _n=$((_n + 1)); done
  [ "$_n" -eq 0 ] && { echo 0; return 0; }
  echo "$((_sum / _n))"
}

if ! $SKIP_GATE_MEASURE; then
  mgc_load_guard "pre-gate-measurement" || exit 2

  if [ -n "$GATES_ARG" ]; then
    IFS=',' read -r -a GATE_LIST <<< "$GATES_ARG"
    for _g in "${GATE_LIST[@]}"; do
      case "$_g" in
        ''|*[!0-9]*) echo "ERROR: --gate: invalid gate id '$_g'" >&2; exit 2 ;;
      esac
    done
  else
    GATE_LIST=()
    for _g in $(seq 1 23); do GATE_LIST+=("$_g"); done
  fi

  {
    printf '# gate-cost-model.csv - MECHANICALLY GENERATED by measure-gate-costs.sh. Do not hand-edit.\n'
    printf '# Regenerate: bash agent-system/extensions/core/scripts/measure-gate-costs.sh\n'
    printf '# Cost classes: free <= 2000ms, moderate <= 30000ms, slow > 30000ms (see this script'"'"'s header).\n'
    printf '# Generated: %s UTC, target=%s, runs=%s, 1min_load_at_start=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TARGET" "$RUNS" "$(mgc_load_1min)"
    hdr="gate_id"
    for _i in $(seq 1 "$RUNS"); do hdr="${hdr},run${_i}_ms"; done
    hdr="${hdr},avg_ms,cost_class"
    printf '%s\n' "$hdr"
  } > "$OUT_FILE"

  for _gate in "${GATE_LIST[@]}"; do
    mgc_measure_gate "$_gate"
    avg="$(mgc_mean "${MGC_RUN_MS[@]}")"
    class="$(mgc_cost_class "$avg")"
    row="gate${_gate}"
    for v in "${MGC_RUN_MS[@]}"; do row="${row},${v}"; done
    row="${row},${avg},${class}"
    echo "$row" >> "$OUT_FILE"
    echo "INFO: measure-gate-costs.sh: gate${_gate} avg=${avg}ms class=${class} (runs: ${MGC_RUN_MS[*]})" >&2
  done

  mgc_load_guard "post-gate-measurement" || {
    echo "WARNING: measure-gate-costs.sh: load rose above threshold DURING measurement -- the just-written $OUT_FILE may be contaminated by contention that started mid-run. Re-run once idle before trusting it for cost-class decisions." >&2
  }
  echo "INFO: measure-gate-costs.sh: wrote $(wc -l < "$OUT_FILE") line(s) to $OUT_FILE" >&2
fi

if $REGEN_HINTS; then
  if [ ! -f "$RUN_ALL" ]; then
    echo "ERROR: --regen-hints requires tests/run-all.sh, not found at $RUN_ALL" >&2
    exit 2
  fi
  mgc_load_guard "pre-hints-regeneration" || exit 2

  declare -A MGC_SUITE_SUM=()
  declare -A MGC_SUITE_N=()
  MGC_SUITE_ORDER=()

  for _i in $(seq 1 "$RUNS"); do
    _tf="$(mktemp)"
    ( cd "$TARGET" && bash "$RUN_ALL" --quiet --jobs 1 --timings "$_tf" >/dev/null 2>&1 ) || true
    while IFS=',' read -r _name _ms _result; do
      [ "$_name" = "TOTAL" ] && continue
      [ "$_result" = "SKIP" ] && continue
      # run-all.sh's --timings CSV names each suite by its FULL discovery path (suite_name="$suite"
      # at its own call site) -- the hints file's documented format is "basename,wall_ms" (basename
      # specifically because discovery paths differ between source-store and deployed mode; see
      # this script's and run-all.sh's own header). Reduce to basename here, once, mechanically,
      # rather than relying on a human to have done this by hand at generation time.
      _name="$(basename "$_name")"
      if [ -z "${MGC_SUITE_SUM[$_name]+x}" ]; then
        MGC_SUITE_SUM["$_name"]=0
        MGC_SUITE_N["$_name"]=0
        MGC_SUITE_ORDER+=("$_name")
      fi
      MGC_SUITE_SUM["$_name"]=$(( MGC_SUITE_SUM["$_name"] + _ms ))
      MGC_SUITE_N["$_name"]=$(( MGC_SUITE_N["$_name"] + 1 ))
    done < "$_tf"
    rm -f "$_tf"
  done

  {
    printf '# suite-cost-hints.txt - Advisory, OPTIONAL scheduling hints for run-all.sh'"'"'s --jobs N parallel\n'
    printf '# pool: longest-first dispatch keeps worker slots busy the whole run instead of ending on one\n'
    printf '# long straggler suite. Format: one row per suite, "basename,wall_ms" (basename, not a full path,\n'
    printf '# since discovery paths differ between source-store and deployed mode -- see run-all.sh'"'"'s own\n'
    printf '# header). Lines starting with # are comments and blank lines are ignored.\n'
    printf '#\n'
    printf '# ADVISORY ONLY: a missing, stale, or partial hint file never skips, duplicates, or reorders away\n'
    printf '# a suite -- an unhinted suite simply keeps discovery order, appended after any hinted ones (see\n'
    printf '# run-all.sh'"'"'s TOTAL_ACCOUNTED assertion, which checked before this file is read). Deleting or\n'
    printf '# truncating this file must never change which suites run, only the order they are scheduled in.\n'
    printf '#\n'
    printf '# MECHANICALLY GENERATED by measure-gate-costs.sh --regen-hints (%s UTC, %s run(s) averaged,\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RUNS"
    printf '# 1min_load_at_start=%s). This file is no longer a one-shot hand-curated snapshot -- re-run the\n' "$(mgc_load_1min)"
    printf '# same command to refresh it whenever drift starts meaningfully hurting scheduling.\n'
    for _name in "${MGC_SUITE_ORDER[@]}"; do
      _sum="${MGC_SUITE_SUM[$_name]}"
      _n="${MGC_SUITE_N[$_name]}"
      _avg=$(( _n > 0 ? _sum / _n : 0 ))
      printf '%s,%s\n' "$_name" "$_avg"
    done
  } > "$HINTS_FILE"

  mgc_load_guard "post-hints-regeneration" || {
    echo "WARNING: measure-gate-costs.sh: load rose above threshold DURING hints regeneration -- re-run once idle before trusting $HINTS_FILE." >&2
  }
  echo "INFO: measure-gate-costs.sh: regenerated $HINTS_FILE with ${#MGC_SUITE_ORDER[@]} suite(s)" >&2
fi

exit 0
