#!/usr/bin/env bash
# measure-gate-costs.sh - Mechanical, idle-guarded, averaged per-gate cost measurement harness
# for verify-deploy.sh's registered gates, and the regeneration path for
# tests/suite-cost-hints.txt.
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
# not merely "a bit slow", so this is a hard refusal (exit 2) BEFORE any measurement starts.
#
# MID-RUN CONTAMINATION IS THE LOAD-BEARING SIGNAL, NOT THE TWO END GUARDS: a pre-run and a
# post-run check alone cannot see contention that begins and subsides ENTIRELY INSIDE the
# measurement window -- this was observed directly (a run begun at load 1.46 was contaminated
# mid-flight by an unrelated sibling build and produced gate1 10ms -> 1,235ms and gate3
# 125.7s -> 299.0s, with its two runs disagreeing 404s against 193s, and the CSV it wrote was
# mechanically indistinguishable from a clean sample until this hardening). The fix is per-RUN
# capture: mgc_load_1min is called once immediately after every individual gate run (not only
# once before and once after the whole pass), and --regen-hints captures once after every
# individual run-all.sh invocation. Each capture is compared against the threshold and folded
# into that row's own "valid" column and the artifact's file-level "# ALL_VALID=" header line --
# see mgc_measure_gate, mgc_write_with_overwrite_guard, and the CSV/hints header comments
# themselves for the mechanics. A caller that only reads the two end-of-run stderr warnings
# (the ORIGINAL, now-insufficient-alone signal) will miss a contamination window the per-row
# validity marking catches; read the artifact's own ALL_VALID header, not stderr, to decide
# whether to trust a sample.
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
# reads it). Columns: gate_id,run1_ms,run1_load,run2_ms,run2_load,...,avg_ms,cost_class,valid.
# Row count follows --runs: a '--runs 3' invocation emits three run{N}_ms/run{N}_load pairs. The
# row's own header line (one emitted per run, so a reader can tell how many run-column pairs to
# expect without parsing the data) makes the shape self-describing. The header additionally
# carries a "# ALL_VALID=true|false" line -- see the MID-RUN CONTAMINATION note above.
#
# OVERWRITE PROTECTION: this script never lets a contaminated (ALL_VALID=false) run silently
# replace a PREVIOUSLY ALL_VALID=true artifact. On that specific collision the new, contaminated
# content is written instead to a sibling "<file>.contaminated-<UTC timestamp>" path, the
# original artifact is left untouched, a loud ERROR is printed, and the script exits 2. Any
# other combination (no prior artifact, a prior artifact that was already not-all-valid, or a
# new run that IS all-valid) overwrites normally. Applies identically to gate-cost-model.csv and
# to suite-cost-hints.txt under --regen-hints. See mgc_write_with_overwrite_guard.
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
#   --skip-gate-measure    With --regen-hints, skip the registered-gate measurement pass entirely
#                          (useful when only the suite-level hints need refreshing).
#
# Exit codes:
#   0  measurement(s) completed and written (the artifact MAY still carry ALL_VALID=false if
#      contamination was detected but there was no previously-clean artifact to protect --
#      check the artifact's own header, not just this exit code, before trusting a sample)
#   1  (reserved; this harness has no notion of a measurement "failing" -- a gate's own nonzero
#      exit during measurement is still a valid, recorded timing, not a harness failure)
#   2  usage error, the pre-run load guard refused (observed load printed either way), OR a
#      contaminated run was refused from overwriting a previously ALL_VALID=true artifact (see
#      OVERWRITE PROTECTION above -- the contaminated data was still written, to a sibling
#      ".contaminated-<timestamp>" path named in the stderr ERROR line)

set -uo pipefail

_MGC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${_MGC_SCRIPT_DIR}/lib/common.sh"

# Degrade-safe guarded source of the gate registry library -- same idiom verify-deploy.sh itself
# uses: a missing library degrades to a stub (empty gate_registry_ids/gate_registry_load) rather
# than aborting this script, and the default GATE_LIST below falls back to the last-known literal
# (seq 1 23) with a warning when the registry cannot be read, instead of silently measuring zero
# gates.
_MGC_GREG_LIB="${_MGC_SCRIPT_DIR}/lib/gate-registry-lib.sh"
if [ -f "$_MGC_GREG_LIB" ]; then
  # shellcheck source=lib/gate-registry-lib.sh
  . "$_MGC_GREG_LIB"
fi
declare -F gate_registry_ids >/dev/null 2>&1 || gate_registry_ids() { :; }
declare -F gate_registry_load >/dev/null 2>&1 || gate_registry_load() { :; }
gate_registry_load "${_MGC_SCRIPT_DIR}/gate-registry.data" 2>/dev/null || true

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
  # Test-only override hook 1: MEASURE_GATE_COSTS_LOADAVG_SEQUENCE, when set, is a comma-separated
  # list of values consumed ONE PER CALL (tracked via a counter file at
  # MEASURE_GATE_COSTS_LOADAVG_SEQFILE, default a fixed tmp path -- callers that need isolation
  # set SEQFILE explicitly) and the last value repeats once the list is exhausted. This exists
  # solely so test-measure-gate-costs.sh can simulate a load that RISES partway through a
  # multi-run measurement (this script now calls mgc_load_1min once per individual run, not only
  # once before and once after the whole measurement, so a static override cannot exercise a
  # mid-run rise at all). Never set in production use.
  if [ -n "${MEASURE_GATE_COSTS_LOADAVG_SEQUENCE:-}" ]; then
    local _seqfile="${MEASURE_GATE_COSTS_LOADAVG_SEQFILE:-${TMPDIR:-/tmp}/mgc-loadavg-seq-idx}"
    local _idx=0 _val _n
    [ -f "$_seqfile" ] && _idx="$(cat "$_seqfile" 2>/dev/null || echo 0)"
    IFS=',' read -r -a _MGC_SEQ_VALS <<< "$MEASURE_GATE_COSTS_LOADAVG_SEQUENCE"
    _n=${#_MGC_SEQ_VALS[@]}
    if [ "$_idx" -lt "$_n" ]; then
      _val="${_MGC_SEQ_VALS[$_idx]}"
    else
      _val="${_MGC_SEQ_VALS[$((_n - 1))]}"
    fi
    echo "$((_idx + 1))" > "$_seqfile"
    echo "$_val"
    return 0
  fi
  # Test-only override hook 2: MEASURE_GATE_COSTS_LOADAVG_OVERRIDE, when set, is returned verbatim
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

# mgc_load_exceeds <load_value> -- "1" if load_value > LOAD_THRESHOLD, "0" otherwise (including
# when load_value is empty/unreadable -- an unreadable sample cannot itself be evidence of
# contention, matching mgc_load_guard's own "proceed, but UNVERIFIED" posture for an empty read).
mgc_load_exceeds() {
  local _load="$1"
  [ -z "$_load" ] && { echo 0; return; }
  awk -v l="$_load" -v t="$LOAD_THRESHOLD" 'BEGIN { print (l > t) ? 1 : 0 }'
}

# mgc_measure_gate <gate_id> -- runs verify-deploy.sh --only-gate <gate_id> RUNS times against
# TARGET, returns (via global MGC_RUN_MS array) each run's wall time in ms and (via global
# MGC_RUN_LOAD array) the 1-minute load average captured IMMEDIATELY AFTER that specific run --
# not only once before and once after the whole gate loop -- so contention that begins and
# subsides entirely inside one gate's own measurement window is no longer invisible. Sets
# MGC_GATE_VALID to "1" iff every captured run-load stayed at or below LOAD_THRESHOLD, else "0".
# The gate's own PASS/FAIL/SKIP outcome is irrelevant to this measurement -- a failing gate still
# costs the same wall time to determine that it failed, and this harness measures cost, not
# correctness (that is verify-deploy.sh's own job, and this task's Phase 1/2 already cover it).
mgc_measure_gate() {
  local _gate="$1" _i _start _end _load
  MGC_RUN_MS=()
  MGC_RUN_LOAD=()
  MGC_GATE_VALID=1
  for _i in $(seq 1 "$RUNS"); do
    _start="$(mgc_now_ms)"
    bash "$VERIFY_DEPLOY" --only-gate "$_gate" --quiet "$TARGET" >/dev/null 2>&1 || true
    _end="$(mgc_now_ms)"
    _load="$(mgc_load_1min)"
    MGC_RUN_MS+=("$((_end - _start))")
    MGC_RUN_LOAD+=("$_load")
    if [ "$(mgc_load_exceeds "$_load")" = "1" ]; then
      MGC_GATE_VALID=0
    fi
  done
}

mgc_mean() {
  local _sum=0 _n=0 _v
  for _v in "$@"; do _sum=$((_sum + _v)); _n=$((_n + 1)); done
  [ "$_n" -eq 0 ] && { echo 0; return 0; }
  echo "$((_sum / _n))"
}

# mgc_header_all_valid <file> -- echoes the existing artifact's own "# ALL_VALID=" header value
# ("true"/"false"), or empty if the file does not exist or carries no such line (e.g. an artifact
# written before this validity marking existed). Read, never written, by the overwrite guard
# below -- this is how a NEW contaminated run discovers whether it is about to clobber a
# previously-trustworthy sample.
mgc_header_all_valid() {
  local _file="$1"
  [ -f "$_file" ] || { echo ""; return 0; }
  # Anchored at BOTH ends (^...$): the header's explanatory prose deliberately mentions the
  # literal substring "ALL_VALID=true"/"ALL_VALID=false" inline (so a human reading the file
  # understands the field without cross-referencing this script), and an unanchored match would
  # pick up that prose line instead of the actual data line. The real data line is written as
  # exactly "# ALL_VALID=true" or "# ALL_VALID=false" with nothing else on it.
  grep -m1 -E '^# ALL_VALID=(true|false)$' "$_file" 2>/dev/null | sed 's/^# ALL_VALID=//'
}

# mgc_write_with_overwrite_guard <target_file> <tmp_file> <new_all_valid:true|false> -- the single
# choke point through which BOTH the gate-cost CSV and the regenerated hints file are written, so
# "a contaminated run must never silently replace a good sample" holds identically for both
# artifacts rather than being reimplemented per-caller. If TARGET already carries
# "# ALL_VALID=true" and the incoming run is NOT all-valid, the write is REFUSED: the new
# (contaminated) content is instead moved to a sibling "<target>.contaminated-<UTC timestamp>"
# file for inspection, TARGET is left untouched, a loud ERROR is printed, and this returns 3.
# Otherwise TMP_FILE is moved into place at TARGET (atomic rename, same directory) and this
# returns 0. Prints the path actually written to on stdout in both cases.
mgc_write_with_overwrite_guard() {
  local _target="$1" _tmp="$2" _new_valid="$3" _old_valid _side
  _old_valid="$(mgc_header_all_valid "$_target")"
  if [ "$_old_valid" = "true" ] && [ "$_new_valid" != "true" ]; then
    _side="${_target}.contaminated-$(date -u +%Y%m%dT%H%M%SZ)"
    mv -f "$_tmp" "$_side"
    echo "ERROR: measure-gate-costs.sh: REFUSING to overwrite previously-clean $_target with a contaminated measurement (load rose during this run). Contaminated data written instead to $_side for inspection; $_target is UNCHANGED. Re-run once the host is idle before trusting a new sample." >&2
    echo "$_side"
    return 3
  fi
  mv -f "$_tmp" "$_target"
  echo "$_target"
  return 0
}

MGC_EXIT_CODE=0

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
    _mgc_registry_ids="$(gate_registry_ids)"
    if [ -n "$_mgc_registry_ids" ]; then
      for _g in $_mgc_registry_ids; do GATE_LIST+=("$_g"); done
    else
      echo "WARNING: measure-gate-costs.sh: gate registry unavailable, falling back to the last-known literal gate set (1-23); this list will not reflect any gate registered after it was written" >&2
      for _g in $(seq 1 23); do GATE_LIST+=("$_g"); done
    fi
    unset _mgc_registry_ids
  fi

  MGC_ALL_VALID_GATES=1
  MGC_ROWS=()
  for _gate in "${GATE_LIST[@]}"; do
    mgc_measure_gate "$_gate"
    avg="$(mgc_mean "${MGC_RUN_MS[@]}")"
    class="$(mgc_cost_class "$avg")"
    row="gate${_gate}"
    for _i in "${!MGC_RUN_MS[@]}"; do
      row="${row},${MGC_RUN_MS[$_i]},${MGC_RUN_LOAD[$_i]}"
    done
    row="${row},${avg},${class},${MGC_GATE_VALID}"
    MGC_ROWS+=("$row")
    [ "$MGC_GATE_VALID" = "0" ] && MGC_ALL_VALID_GATES=0
    echo "INFO: measure-gate-costs.sh: gate${_gate} avg=${avg}ms class=${class} valid=${MGC_GATE_VALID} (runs: ${MGC_RUN_MS[*]}; loads: ${MGC_RUN_LOAD[*]})" >&2
  done

  mgc_load_guard "post-gate-measurement"
  MGC_POST_GUARD_RC=$?
  if [ "$MGC_POST_GUARD_RC" -ne 0 ]; then
    echo "WARNING: measure-gate-costs.sh: load rose above threshold DURING measurement -- this run's data is marked ALL_VALID=false. Re-run once idle before trusting it for cost-class decisions." >&2
  fi

  MGC_ALL_VALID=true
  [ "$MGC_ALL_VALID_GATES" = "0" ] && MGC_ALL_VALID=false
  [ "$MGC_POST_GUARD_RC" -ne 0 ] && MGC_ALL_VALID=false

  MGC_TMP="$(mktemp "${OUT_FILE}.tmp.XXXXXX")"
  {
    printf '# gate-cost-model.csv - MECHANICALLY GENERATED by measure-gate-costs.sh. Do not hand-edit.\n'
    printf '# Regenerate: bash agent-system/extensions/core/scripts/measure-gate-costs.sh\n'
    printf '# Cost classes: free <= 2000ms, moderate <= 30000ms, slow > 30000ms (see this script'"'"'s header).\n'
    printf '# VALIDITY: the per-row "valid" column is 1 iff every per-RUN load sample captured WHILE\n'
    printf '# that specific gate was being measured stayed at or below load_threshold -- not merely at\n'
    printf '# the start and end of the whole measurement pass. ALL_VALID below is the AND of every row'"'"'s\n'
    printf '# valid column and the final post-measurement guard. A false ALL_VALID does not stop this\n'
    printf '# file from being written (a reader needs to see exactly which gates were affected), but\n'
    printf '# this script itself refuses to let a contaminated run silently overwrite an existing\n'
    printf '# ALL_VALID=true artifact -- see mgc_write_with_overwrite_guard. Never trust a non-true\n'
    printf '# ALL_VALID for a cost-class decision; regenerate once the host is idle instead.\n'
    printf '# ALL_VALID=%s\n' "$MGC_ALL_VALID"
    printf '# Generated: %s UTC, target=%s, runs=%s, load_threshold=%s, 1min_load_at_start=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$TARGET" "$RUNS" "$LOAD_THRESHOLD" "$(mgc_load_1min)"
    hdr="gate_id"
    for _i in $(seq 1 "$RUNS"); do hdr="${hdr},run${_i}_ms,run${_i}_load"; done
    hdr="${hdr},avg_ms,cost_class,valid"
    printf '%s\n' "$hdr"
    for row in "${MGC_ROWS[@]}"; do printf '%s\n' "$row"; done
  } > "$MGC_TMP"

  MGC_WRITTEN_PATH="$(mgc_write_with_overwrite_guard "$OUT_FILE" "$MGC_TMP" "$MGC_ALL_VALID")"
  MGC_GUARD_RC=$?
  [ "$MGC_GUARD_RC" -eq 3 ] && MGC_EXIT_CODE=2
  echo "INFO: measure-gate-costs.sh: wrote $(wc -l < "$MGC_WRITTEN_PATH") line(s) to $MGC_WRITTEN_PATH (ALL_VALID=$MGC_ALL_VALID)" >&2
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
  MGC_HINTS_RUN_LOADS=()
  MGC_ALL_VALID_HINTS=1

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
    # Per-run-all.sh-invocation load capture -- this script does not instrument run-all.sh's own
    # per-suite internals, so the per-invocation granularity (one of these per --runs iteration,
    # not only once before and once after the whole --regen-hints pass) is the finest-grained
    # contamination signal available without touching a different script.
    _hload="$(mgc_load_1min)"
    MGC_HINTS_RUN_LOADS+=("$_hload")
    [ "$(mgc_load_exceeds "$_hload")" = "1" ] && MGC_ALL_VALID_HINTS=0
  done

  mgc_load_guard "post-hints-regeneration"
  MGC_HINTS_POST_RC=$?
  if [ "$MGC_HINTS_POST_RC" -ne 0 ]; then
    echo "WARNING: measure-gate-costs.sh: load rose above threshold DURING hints regeneration -- this run's hints are marked ALL_VALID=false. Re-run once idle before trusting $HINTS_FILE." >&2
  fi

  MGC_ALL_VALID_H=true
  [ "$MGC_ALL_VALID_HINTS" = "0" ] && MGC_ALL_VALID_H=false
  [ "$MGC_HINTS_POST_RC" -ne 0 ] && MGC_ALL_VALID_H=false

  MGC_HTMP="$(mktemp "${HINTS_FILE}.tmp.XXXXXX")"
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
    printf '# VALIDITY: ALL_VALID is false if ANY of the %s per-invocation load captures below\n' "$RUNS"
    printf '# (one taken immediately after each --runs iteration'"'"'s full run-all.sh pass, plus the\n'
    printf '# final post-regeneration guard) exceeded load_threshold. As with gate-cost-model.csv, this\n'
    printf '# script refuses to let an ALL_VALID=false regeneration silently overwrite an existing\n'
    printf '# ALL_VALID=true hints file -- see mgc_write_with_overwrite_guard. Never trust a non-true\n'
    printf '# ALL_VALID for scheduling decisions; regenerate once idle instead.\n'
    printf '# ALL_VALID=%s\n' "$MGC_ALL_VALID_H"
    printf '# run_loads=%s, load_threshold=%s\n' "$(IFS=,; echo "${MGC_HINTS_RUN_LOADS[*]}")" "$LOAD_THRESHOLD"
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
  } > "$MGC_HTMP"

  MGC_HWRITTEN_PATH="$(mgc_write_with_overwrite_guard "$HINTS_FILE" "$MGC_HTMP" "$MGC_ALL_VALID_H")"
  MGC_HGUARD_RC=$?
  [ "$MGC_HGUARD_RC" -eq 3 ] && MGC_EXIT_CODE=2
  echo "INFO: measure-gate-costs.sh: regenerated $MGC_HWRITTEN_PATH with ${#MGC_SUITE_ORDER[@]} suite(s) (ALL_VALID=$MGC_ALL_VALID_H)" >&2
fi

exit "$MGC_EXIT_CODE"
