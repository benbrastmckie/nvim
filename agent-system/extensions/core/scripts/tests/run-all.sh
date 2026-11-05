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
#   run-all.sh [--quiet] [--timings FILE] [--jobs N|auto] [--only SUITE[,SUITE,...]]
#              [--class CLASS[,CLASS,...]] [--tag TAG[,TAG,...]]
#              [--cost-class CLASS[,CLASS,...]] [--fail-on-new]
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
# --jobs N|auto: run up to N suites concurrently. DEFAULT IS `auto` (Phase 10, "Flip run-all.sh's
#          Default to Parallel"): a bare invocation with no --jobs argument now resolves exactly
#          as `--jobs auto` always has, so a direct `run-all.sh` call is no longer accidentally
#          3-8x slower than the identical work done via verify-deploy.sh's Gate 8 (which has
#          always passed `--jobs auto` explicitly). Pass `--jobs 1` for the explicit opt-out,
#          which routes to the EXACT SAME sequential code path this script has always had --
#          byte-for-byte unchanged, not a new "sequential-flavored parallel" path. `auto`
#          resolves to `nproc`, capped at 4 (see the rejected-alternatives note below this header
#          for why a fixed cap, not a bare nproc, AND why raising that cap would buy nothing even
#          though it looks like the obvious next lever). Output is ALWAYS captured per-suite and
#          emitted whole, in discovery order,
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
#     rsync a ~23MB fixture tree (measured: `du -sh --exclude=literature-pyenv
#     agent-system/extensions/`; the unexcluded tree is ~263MB) or launch headless nvim; N
#     concurrent copies on a many-core box multiplies peak disk and memory well past what those
#     suites were sized for individually. Re-measured at the chosen cap (jobs=4, real battery,
#     idle-start host): peak concurrent fixture count 22, peak `free -m` used 21,952MB against a
#     30GiB host -- consistent with, not a refutation of, this rejection.
#   - Raising JOBS_CAP above 4: re-derived on current evidence (suite-cost-hints.txt's own
#     153-row, 1,402.17s aggregate, superseding the 147-row/1,016.6s figure this header once
#     cited -- see shell-script-testing.md's per-gate before/after table). The pool's longest
#     single suite is now `test-gate-cache-equivalence.sh` (543s isolated; added by the cost-
#     model re-aim task's own equivalence-proof phase), not `test-verify-deploy-gate-selection-
#     crash-net.sh` (~149s, demoted to second-longest). Aggregate/N crosses below the 543s
#     straggler once N>=3 (1,402.17/3=467.4s < 543s), so the pool is straggler-bound at every
#     candidate cap (4, 8, 12) alike -- raising the cap cannot reduce wall clock below the
#     straggler's own cost, it can only add concurrent CPU pressure. Measured directly, not only
#     projected: a real `--jobs 4` battery on an idle-start host (1-min load 0.28 before, 0.62
#     within seconds after) ran 650s and pushed `test-gate-cache-equivalence.sh` itself over its
#     own 600s per-suite timeout (TIMEOUT, killed) under the pool's own self-generated
#     contention, plus five further suites with transient contention-shaped failures (a timing-
#     budget suite and several state-leakage symptoms), none attributable to any source edit
#     (none had landed when this run was taken) and none present in `known-failures.txt`. Raising
#     the cap would increase per-core contention at the exact suite already closest to its own
#     timeout, not relieve it -- this is now a measured reason to hold the cap, not only a
#     mathematical one. An explicit `--jobs 12` already bypasses this cap entirely today (the cap
#     applies only inside the `auto` branch below).
#
# --only SUITE[,SUITE,...]: STRICTLY OPT-IN suite-level selection. Every comma-separated token is
#          validated as an exact basename against the discovered suite set BEFORE any suite runs
#          -- any unknown token refuses the whole run with exit 2, naming the offending token
#          (mirrors verify-deploy.sh's --only-gate: "a partially-valid list must refuse loudly,
#          not silently run a subset"). Filtering happens at exactly one site, immediately after
#          the self-exclusion block and before TOTAL_DISCOVERED is computed, so every downstream
#          mechanism (the sequential/parallel branch split, LOAD_SENSITIVE_BASENAMES scheduling,
#          TOTAL_ACCOUNTED, --timings, known-failures.txt classification) inherits the narrowing
#          for free with zero duplicated logic. Absent this flag, no filtering runs at all and
#          output is byte-identical to a pre-`--only` run. A selected-subset pass is NOT evidence
#          that doc-sync pins hold -- the same accepted trade-off already recorded for
#          --skip-slow in specs/ROADMAP.md's Settled decision 15 -- and selection is a strictly
#          separate axis from known-failures.txt (Settled decision 13: that manifest is advisory
#          and never changes which suites run). To resolve WHICH suites a set of touched
#          source files maps to, see scripts/lib/suite-selection-lib.sh (a separate, independently
#          sourced piece that composes with this flag rather than being called from inside it --
#          a caller resolves suite names there first, then passes the resolved list here).
#          Rejected alternative: a `--filter PATTERN` flag (human-typed glob/regex matching
#          against discovered basenames) was declined-for-now -- no concrete interactive caller
#          was identified, and suite-selection-lib.sh always emits an exact resolved basename
#          list, never a pattern, so there is nothing today that would consume a pattern syntax.
#
# --class CLASS[,CLASS,...] / --tag TAG[,TAG,...] / --cost-class CLASS[,CLASS,...]: three further
#          OPT-IN selection axes, layered ON TOP of --only (composed by intersection: when --only
#          and one or more of these are both given, the result is suites satisfying --only AND
#          every supplied axis -- never a replacement for --only). Each axis selects the UNION of
#          suites matching ANY of its own comma-separated values, reading declarative data this
#          corpus already has (scripts/lib/suite-selection-lib.sh's "Declarative class / tag /
#          cost-class selection" section owns the full derivation rule and is sourced from here
#          for it, never duplicated):
#            --class        tests/suite-classification.data's own unit/integration column.
#            --tag          mechanically derived, never hand-authored: every invoked-tool token
#                           an integration-class suite's own `reason` column already names, plus
#                           the fixed tag "lint" for every test-lint-*.sh suite.
#            --cost-class   tests/suite-cost-hints.txt's advisory wall_ms column, bucketed free /
#                           moderate / slow at suite-selection-lib.sh's fixed thresholds, plus
#                           "unknown" for a suite the (optional) hints file does not cover.
#          Every token across all three flags is validated against its own axis's closed known-
#          value vocabulary BEFORE any suite runs -- an unknown token refuses the whole run with
#          exit 2, naming the offending token and its axis, mirroring --only's own "refuse
#          loudly, never silently run a subset" discipline. Absent all three flags, no filtering
#          from this block runs at all and output is byte-identical to a pre-Phase-14 run; --jobs,
#          --timings and --fail-on-new behave identically under this narrowing, exactly as they
#          already do under --only, because filtering happens before TOTAL_DISCOVERED is computed
#          and every downstream mechanism inherits it for free, same as --only's own site.
#
# --fail-on-new: opt-in. When a committed tests/known-failures.txt manifest is present (see its
#          own header -- advisory, optional, basename-keyed, format
#          `basename|category|reason|owner`), each failing suite is classified as EXPECTED
#          (basename matches a manifest row) or NEW (does not). With --fail-on-new, the exit code
#          is 1 only if at least one failure is NEW; an all-EXPECTED failure set exits 0. Without
#          this flag, the DEFAULT exit-code semantics are unchanged: exit 1 if any suite failed,
#          EXPECTED or not. A missing or truncated known-failures.txt degrades to today's
#          behavior exactly -- every failure is then classified NEW, so --fail-on-new becomes
#          equivalent to the default (exit 1 on any failure).
#
# Exit codes:
#   0  all discovered suites passed (or, under --fail-on-new, no failure was classified NEW)
#   1  one or more discovered suites failed (or, under --fail-on-new, at least one was NEW)
#   2  zero suites were discovered (harness failure, not a pass), or an internal scheduling
#      invariant was violated (scheduled count != discovered count)
#
# Machine-greppable output: every failing suite prints a line of the exact form
#   [FAIL] <suite path>
# so a caller can extract failures with `grep '^\[FAIL\] '` regardless of --quiet or --jobs.
#
# End-of-run failure roster: immediately before the final tally line, if one or more suites
# failed, a consolidated roster block is printed:
#   [run-all] Failing suites (N):
#       <suite path>
#       <suite path>
# printed unconditionally -- NOT suppressed by --quiet, matching the inline [FAIL] line's own
# posture -- so a caller that only captures the tail of the output (or a human skimming a long
# run) can recover every failing suite's identity without set-differencing [RUN]/[PASS] markers.
# CRITICAL CONSTRAINT: this roster block must never contain the literal token `[FAIL]` anywhere.
# verify-deploy.sh's Gate 8 folds every `grep -F '[FAIL]'` hit into a FINDING gate8 row; a roster
# carrying that token would silently double-count every failure. The header and entry lines above
# are deliberately token-free for this reason -- do not "helpfully" prefix roster entries with
# `[FAIL]` in a future edit.
#
# Known-failing baseline: if tests/known-failures.txt (basename-keyed, advisory, optional -- see
# its own header) is present, each roster entry is annotated `(EXPECTED)` or `(NEW)` and the final
# tally line grows a trailing `(E expected, X NEW)` clause, e.g.
#   [run-all] 97 passed, 8 failed (8 expected, 0 NEW), 0 skipped, 105 total
# The leading `N passed, M failed` prefix is byte-identical to the pre-manifest tally either way,
# so any existing consumer parsing only the head of that line is unaffected. A missing or
# truncated known-failures.txt degrades to exactly today's tally line and roster (no annotation,
# no trailing clause) -- see --fail-on-new above for the manifest's file format and semantics.
#
# specs/.gate-lock bracket (repo-scoped coordination of concurrent gate-set runs): a full,
# UNFILTERED battery (no --only) run from a NON-nested, NON-guest invocation holds the repo-scoped
# specs/.gate-lock mutex (task-lock.sh's gate-acquire/gate-release) for its whole duration, so two
# concurrent sessions' full batteries in one checkout serialize instead of contending for the same
# cores. Skipped (no mutex touched, a named `Note:` line printed instead) in exactly four cases:
# --only narrowed this run; RUN_ALL_NESTED was already "1" at entry (this invocation was itself
# launched from inside another run-all.sh's suite, e.g. verify-deploy.sh's Gate 8); an outer
# holder already exported GATE_MUTEX_HELD=1 (this run is a guest); or the deployed task-lock.sh
# (always the DEPLOYED copy -- the source-store copy cannot be invoked, see
# rules/source-store-deploy-boundary.md) is not present. On an acquire failure for any other
# reason, this script fails OPEN: a single named `WARNING:` line (mirroring git-commit-scoped.sh's
# specs/.commit-lock posture) and the battery proceeds unserialized -- coordination failing is
# never a reason to skip or alter verification. See
# context/patterns/batch-orchestration-guardrails.md for the full contract.

set -uo pipefail

# RUN_ALL_SUITE_TIMEOUT_S (Phase 6, "Uniform Bounded Timeouts Per Gate and Per Suite"): a uniform
# per-suite wall-clock bound, applied identically in the sequential and parallel (`run_one()`)
# paths below via the external `timeout` command -- each suite is already its own subprocess
# (`bash "$suite"`), so, unlike verify-deploy.sh's in-process gate functions, no fork/state-
# capture reconciliation is needed here: `timeout` is simply inserted in front of the existing
# invocation. Default 600s (10 minutes), sized with real headroom over the slowest suite this
# repository has ever measured at the time this bound was set
# (test-verify-deploy-context-budget.sh, ~228.6s per suite-cost-hints.txt's own hinted maximum --
# roughly 2.6x that figure), not a bare guess. A suite that exceeds the bound is reported as a
# named, attributable [FAIL] (the suite's own name, plus a TIMEOUT line naming the bound) rather
# than hanging the whole run indefinitely or producing an unattributed generic failure.
# Overridable for a test that deliberately needs a short bound (see test-stalled-fixture.sh and
# its regression case in test-run-all-selection.sh).
RUN_ALL_SUITE_TIMEOUT_S="${RUN_ALL_SUITE_TIMEOUT_S:-600}"

QUIET=false
TIMINGS_FILE=""
# Phase 10 ("Flip run-all.sh's Default to Parallel"): default is now "auto", not "1" -- see this
# file's own --jobs header documentation above for the full rationale. The string "auto" flows
# through the exact same resolution branch below (`if [ "$JOBS" = "auto" ]; then ...`) that an
# explicit `--jobs auto` has always used, so there is no new code path here, only a new default
# value feeding the pre-existing one.
JOBS=auto
FAIL_ON_NEW=false
ONLY_SUITES=""
CLASS_FILTER=""
TAG_FILTER=""
COST_CLASS_FILTER=""
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
    --only)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --only requires SUITE[,SUITE,...] (a non-empty basename list)" >&2
        exit 2
      fi
      ONLY_SUITES="$2"
      shift 2
      ;;
    --class)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --class requires CLASS[,CLASS,...] (a non-empty value list)" >&2
        exit 2
      fi
      CLASS_FILTER="$2"
      shift 2
      ;;
    --tag)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --tag requires TAG[,TAG,...] (a non-empty value list)" >&2
        exit 2
      fi
      TAG_FILTER="$2"
      shift 2
      ;;
    --cost-class)
      if [ $# -lt 2 ] || [ -z "$2" ]; then
        echo "ERROR: --cost-class requires CLASS[,CLASS,...] (a non-empty value list)" >&2
        exit 2
      fi
      COST_CLASS_FILTER="$2"
      shift 2
      ;;
    --fail-on-new) FAIL_ON_NEW=true; shift ;;
    -h|--help)
      sed -n '2,163p' "$0" | sed 's/^# \{0,1\}//'
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

if ! printf '%s' "$RUN_ALL_SUITE_TIMEOUT_S" | grep -qE '^[0-9]+$' || [ "$RUN_ALL_SUITE_TIMEOUT_S" -lt 1 ]; then
  echo "ERROR: RUN_ALL_SUITE_TIMEOUT_S: invalid value '$RUN_ALL_SUITE_TIMEOUT_S' (must be a positive integer)" >&2
  exit 2
fi

# Nested-invocation guard: a run-all.sh launched FROM one of this run's own suites (e.g. a suite
# that shells out to verify-deploy.sh, whose Gate 8 is run-all.sh itself) must never multiply job
# counts. If we are already nested, force sequential regardless of what --jobs requested.
#
# Captured BEFORE the unconditional export below (which would otherwise make every subsequent
# read of RUN_ALL_NESTED report "1" even for a top-level invocation) -- the specs/.gate-lock
# bracket further down needs to know whether THIS invocation was nested AT ENTRY, not whether
# RUN_ALL_NESTED is set now.
RUN_ALL_WAS_NESTED_AT_ENTRY="${RUN_ALL_NESTED:-}"
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

# Deployed task-lock.sh resolution for the specs/.gate-lock mutex bracket below (see this file's
# own header for the full contract). Mirrors MODE exactly: the SOURCE-STORE copy of task-lock.sh
# cannot be invoked directly -- it sources deploy-root-guard.sh, which exits 1 for any scripts/
# directory not under .claude/ or .opencode/ -- so both this script's bracket and
# verify-deploy.sh's gate8_run() always invoke the DEPLOYED copy. That resolution is also what
# makes task-lock.sh's own PROJECT_ROOT (its SCRIPT_DIR/../..) land on the one repository whose
# specs/ tree holds the mutex -- repo scoping is satisfied by that resolution, not by new code
# here.
if [ "$MODE" = "deployed" ]; then
  GATE_TASK_LOCK_SH="$DEPLOY_SCRIPTS_ROOT/task-lock.sh"
else
  GATE_REPO_ROOT="$(cd "$EXTENSIONS_ROOT/../.." 2>/dev/null && pwd || true)"
  GATE_TASK_LOCK_SH="${GATE_REPO_ROOT:+$GATE_REPO_ROOT/.claude/scripts/task-lock.sh}"
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

# --only SUITE[,SUITE,...]: the single filtering site (see header). Validate every comma-
# separated token against the discovered basename set BEFORE narrowing anything -- an unknown
# token refuses the whole run (exit 2, naming the token), mirroring verify-deploy.sh's
# --only-gate discipline ("a partially-valid list must refuse loudly, not silently run a
# subset"). Absent --only (ONLY_SUITES empty), SUITES is left untouched here and every line
# below is byte-identical to a pre-"--only" run.
if [ -n "$ONLY_SUITES" ]; then
  IFS=',' read -r -a ONLY_TOKENS <<< "$ONLY_SUITES"
  declare -A DISCOVERED_BASENAMES=()
  for s in "${SUITES[@]}"; do
    DISCOVERED_BASENAMES["$(basename "$s")"]=1
  done
  for only_tok in "${ONLY_TOKENS[@]}"; do
    if [ -z "$only_tok" ] || [ -z "${DISCOVERED_BASENAMES[$only_tok]:-}" ]; then
      echo "ERROR: --only: unknown suite basename '$only_tok' (not among ${#SUITES[@]} discovered suites)" >&2
      exit 2
    fi
  done
  ONLY_FILTERED_SUITES=()
  for s in "${SUITES[@]}"; do
    base="$(basename "$s")"
    for only_tok in "${ONLY_TOKENS[@]}"; do
      if [ "$base" = "$only_tok" ]; then
        ONLY_FILTERED_SUITES+=("$s")
        break
      fi
    done
  done
  SUITES=("${ONLY_FILTERED_SUITES[@]}")
  unset ONLY_TOKENS DISCOVERED_BASENAMES only_tok ONLY_FILTERED_SUITES base s
fi

# --class / --tag / --cost-class: three further opt-in axes, composed with --only (and with each
# other) by intersection -- see this file's own header for the full contract. Absent all three,
# this whole block is a no-op and SUITES/output stay byte-identical to a pre-Phase-14 run. Sourced
# here, not duplicated: scripts/lib/suite-selection-lib.sh owns the declarative derivation for
# every axis (the touched-path mapping functions this library already had are untouched).
if [ -n "$CLASS_FILTER" ] || [ -n "$TAG_FILTER" ] || [ -n "$COST_CLASS_FILTER" ]; then
  SUITE_SELECTION_LIB="$SCRIPT_DIR/../lib/suite-selection-lib.sh"
  if [ ! -f "$SUITE_SELECTION_LIB" ]; then
    echo "ERROR: --class/--tag/--cost-class require $SUITE_SELECTION_LIB (not found)" >&2
    exit 2
  fi
  # shellcheck source=/dev/null
  source "$SUITE_SELECTION_LIB"

  _validate_filter_tokens() {
    # Usage: _validate_filter_tokens AXIS_NAME TOKEN_CSV KNOWN_VALUES_NEWLINE_LIST
    # Exits 2, naming both the axis and the offending token, on a value absent from the known
    # vocabulary -- mirrors --only's own "a partially-valid list must refuse loudly" discipline.
    local axis="$1" csv="$2" known="$3"
    local -a toks=()
    local tok
    IFS=',' read -r -a toks <<< "$csv"
    for tok in "${toks[@]}"; do
      if [ -z "$tok" ] || ! printf '%s\n' "$known" | grep -qxF "$tok"; then
        echo "ERROR: --$axis: unknown value '$tok' (known: $(printf '%s' "$known" | tr '\n' ',' | sed 's/,$//'))" >&2
        exit 2
      fi
    done
  }

  if [ -n "$CLASS_FILTER" ]; then
    _validate_filter_tokens class "$CLASS_FILTER" "$(suite_selection_known_classes)"
  fi
  if [ -n "$TAG_FILTER" ]; then
    _validate_filter_tokens tag "$TAG_FILTER" "$(suite_selection_known_tags)"
  fi
  if [ -n "$COST_CLASS_FILTER" ]; then
    _validate_filter_tokens cost-class "$COST_CLASS_FILTER" "$(suite_selection_known_cost_classes)"
  fi

  if [ -n "$CLASS_FILTER" ]; then
    declare -A _MATCH_CLASS=()
    while IFS= read -r _m; do [ -n "$_m" ] && _MATCH_CLASS["$_m"]=1; done < <(suite_selection_by_class "$CLASS_FILTER")
  fi
  if [ -n "$TAG_FILTER" ]; then
    declare -A _MATCH_TAG=()
    while IFS= read -r _m; do [ -n "$_m" ] && _MATCH_TAG["$_m"]=1; done < <(suite_selection_by_tag "$TAG_FILTER")
  fi
  if [ -n "$COST_CLASS_FILTER" ]; then
    declare -A _MATCH_COST=()
    while IFS= read -r _m; do [ -n "$_m" ] && _MATCH_COST["$_m"]=1; done < <(suite_selection_by_cost_class "$COST_CLASS_FILTER")
  fi

  CLASS_TAG_COST_FILTERED_SUITES=()
  for s in "${SUITES[@]}"; do
    base="$(basename "$s")"
    keep=true
    [ -n "$CLASS_FILTER" ] && [ -z "${_MATCH_CLASS[$base]:-}" ] && keep=false
    [ -n "$TAG_FILTER" ] && [ -z "${_MATCH_TAG[$base]:-}" ] && keep=false
    [ -n "$COST_CLASS_FILTER" ] && [ -z "${_MATCH_COST[$base]:-}" ] && keep=false
    [ "$keep" = "true" ] && CLASS_TAG_COST_FILTERED_SUITES+=("$s")
  done
  SUITES=("${CLASS_TAG_COST_FILTERED_SUITES[@]}")
  unset -f _validate_filter_tokens
  unset _MATCH_CLASS _MATCH_TAG _MATCH_COST CLASS_TAG_COST_FILTERED_SUITES base s keep _m SUITE_SELECTION_LIB
fi

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
FAILED_SUITE_NAMES=()

# Known-failing baseline manifest: advisory, optional, basename-keyed -- see
# tests/known-failures.txt's own header for the full format contract and
# suite-cost-hints.txt's precedent for the same shape. A missing file leaves
# KNOWN_FAILURE_CATEGORY empty, so every failure classifies as NEW below -- today's behavior,
# exactly, when no manifest exists.
KNOWN_FAILURES_FILE="$SCRIPT_DIR/known-failures.txt"
MANIFEST_PRESENT=false
declare -A KNOWN_FAILURE_CATEGORY=()
if [ -f "$KNOWN_FAILURES_FILE" ]; then
  MANIFEST_PRESENT=true
  while IFS='|' read -r kf_base kf_category _kf_reason _kf_owner; do
    [ -n "$kf_base" ] || continue
    case "$kf_base" in \#*) continue ;; esac
    KNOWN_FAILURE_CATEGORY["$kf_base"]="$kf_category"
  done < "$KNOWN_FAILURES_FILE"
fi

if [ -n "$TIMINGS_FILE" ]; then
  : > "$TIMINGS_FILE"
fi

# ── specs/.gate-lock mutex bracket (see this file's own header for the full contract) ──────────
# ONE composed EXIT handler, installed ONCE here, before either execution branch below -- NOT two
# branch-local `trap ... EXIT` installations (the prior shape), which would silently clobber
# whichever cleanup (gate-lock release, or SUITE_OUT/OUT_DIR removal) was installed first. Both
# branches below now only ASSIGN SUITE_OUT/OUT_DIR; neither re-installs its own trap.
GATE_MUTEX_OWNED_HERE=false
GATE_MUTEX_TOKEN=""

run_all_exit_cleanup() {
  if [ "$GATE_MUTEX_OWNED_HERE" = "true" ]; then
    "$GATE_TASK_LOCK_SH" gate-release "$GATE_MUTEX_TOKEN" >&2 || true
    GATE_MUTEX_OWNED_HERE=false
    unset GATE_MUTEX_HELD
  fi
  [ -n "${SUITE_OUT:-}" ] && rm -f "$SUITE_OUT" 2>/dev/null || true
  [ -n "${OUT_DIR:-}" ] && rm -rf "$OUT_DIR" 2>/dev/null || true
  if [ -n "${RUN_ALL_SHARED_FIXTURE:-}" ] && [ -d "$RUN_ALL_SHARED_FIXTURE" ]; then
    # Reverse the read-only lending chmod first -- `rm -rf` needs write+execute on every
    # directory to unlink its entries, which the read-only chmod below deliberately removed.
    chmod -R u+w "$RUN_ALL_SHARED_FIXTURE" 2>/dev/null || true
    rm -rf "$RUN_ALL_SHARED_FIXTURE" 2>/dev/null || true
  fi
}
trap run_all_exit_cleanup EXIT

# Stable session string for this run's gate-acquire token when no richer session id is available
# -- the mutex is opaque to this string's shape; it is only ever echoed back in a holder-identity
# WARN/Note line.
GATE_SESSION_STR="run-all-$$"

if [ -n "$ONLY_SUITES" ]; then
  echo "Note: --only narrowed this run to ${TOTAL_DISCOVERED} suite(s); specs/.gate-lock is not touched for a narrowed run (suite narrowing already discharges a sub-full verification tier; it must not wait out a sibling's full battery)." >&2
elif [ "$RUN_ALL_WAS_NESTED_AT_ENTRY" = "1" ]; then
  echo "Note: this run-all.sh invocation is nested (RUN_ALL_NESTED was already 1 at entry); specs/.gate-lock is not touched -- the outer invocation is responsible for holding it." >&2
elif [ -n "${GATE_MUTEX_HELD:-}" ]; then
  echo "Note: an outer holder already owns the specs/.gate-lock mutex (GATE_MUTEX_HELD=1 inherited); running as guest, no nested acquire." >&2
elif [ -z "$GATE_TASK_LOCK_SH" ] || [ ! -f "$GATE_TASK_LOCK_SH" ]; then
  echo "Note: deployed task-lock.sh not found at '${GATE_TASK_LOCK_SH:-<unresolved>}'; specs/.gate-lock coordination is skipped for this run (fail-open: coordination is optional, verification is not)." >&2
else
  gate_token=""
  if gate_token=$(bash "$GATE_TASK_LOCK_SH" gate-acquire "$GATE_SESSION_STR"); then
    GATE_MUTEX_TOKEN="$gate_token"
    GATE_MUTEX_OWNED_HERE=true
    export GATE_MUTEX_HELD=1
  else
    echo "WARNING: failed to acquire specs/.gate-lock mutex (session=${GATE_SESSION_STR}); proceeding unserialized (non-blocking, fail-open). Worst case: contention with a sibling session's full gate-set battery persists for this run; verification itself is neither skipped nor altered by this mutex -- its own PASS/FAIL/SKIP verdicts and summary line are unaffected. Mirrors git-commit-scoped.sh's specs/.commit-lock fail-open posture and its explicit refusal to cite an unreproduced result as settled." >&2
  fi
fi

# ── Shared deployed-tree fixture: built ONCE here, before
# any suite runs, and lent READ-ONLY (chmod -R a-w) to every suite named in
# SHARED_FIXTURE_CONSUMERS below -- never reconstructed per suite. A suite that must mutate it
# calls common_test_fixture_overlay() (lib/common.sh) for a private writable copy instead.
#
# Scoped deliberately narrow, not "every integration-class suite": a suite that tests
# deploy-headless.sh's or verify-deploy.sh's OWN behavior across distinct flags/scenarios (a
# fresh-vs-resync propagation check, a flag-matrix wiring check, a gate-cache equivalence proof)
# is NOT a consumer here -- its variance across invocations IS the thing under test, so a single
# shared tree cannot stand in for it; migrating those would change what they verify, not just how
# cheaply. See context/standards/shell-script-testing.md's shared-fixture contract for the full
# discriminator and the evidenced reason the realistic consumer set is far smaller than a bare
# textual-reference count over suite-classification.data's "integration" rows would suggest.
SHARED_FIXTURE_CONSUMERS=(
  test-deploy-orphans.sh
)
RUN_ALL_SHARED_FIXTURE=""
NEEDS_SHARED_FIXTURE=false
for _sfc_suite in "${SUITES[@]}"; do
  _sfc_base="$(basename "$_sfc_suite")"
  for _sfc_consumer in "${SHARED_FIXTURE_CONSUMERS[@]}"; do
    if [ "$_sfc_base" = "$_sfc_consumer" ]; then
      NEEDS_SHARED_FIXTURE=true
      break 2
    fi
  done
done
unset _sfc_suite _sfc_base _sfc_consumer

if [ "$NEEDS_SHARED_FIXTURE" = "true" ]; then
  if [ "$MODE" = "deployed" ]; then
    _SFC_DEPLOY_SCRIPT="$DEPLOY_SCRIPTS_ROOT/deploy-headless.sh"
  else
    _SFC_DEPLOY_SCRIPT="$EXTENSIONS_ROOT/core/scripts/deploy-headless.sh"
  fi
  if [ -f "$_SFC_DEPLOY_SCRIPT" ]; then
    _SFC_BUILD="$(mktemp -d)/deployed"
    mkdir -p "$_SFC_BUILD"
    _SFC_OK=false
    if (cd "$_SFC_BUILD" && git init -q) >/dev/null 2>&1 && \
       git -C "$_SFC_BUILD" -c user.email="test@test.local" -c user.name="run-all-shared-fixture" \
         commit -q --allow-empty -m "scratch init" >/dev/null 2>&1; then
      # --skip-verify: this fixture only needs the DEPLOYED CONTENT, never deploy-headless.sh's
      # own inline verify-deploy.sh pass (which would fail gate 14's runtime-file-tracking check
      # against a bare scratch repo that never seeded a consumer .gitignore -- a concern specific
      # to deploy-headless.sh's own self-check, orthogonal to what any consumer suite verifies).
      # Exit 4 (RESULT=landed_verify_skipped) is --skip-verify's own documented SUCCESS code,
      # never a failure; exit 0 is also accepted defensively. Mirrors
      # test-gate-cache-equivalence.sh's identical exit-4-is-success precedent.
      bash "$_SFC_DEPLOY_SCRIPT" --skip-verify "$_SFC_BUILD" >/dev/null 2>&1
      _SFC_DEPLOY_RC=$?
      if [ "$_SFC_DEPLOY_RC" -eq 0 ] || [ "$_SFC_DEPLOY_RC" -eq 4 ]; then
        _SFC_OK=true
      fi
      unset _SFC_DEPLOY_RC
    fi
    if [ "$_SFC_OK" = "true" ]; then
      chmod -R a-w "$_SFC_BUILD" 2>/dev/null || true
      RUN_ALL_SHARED_FIXTURE="$_SFC_BUILD"
      export RUN_ALL_SHARED_FIXTURE
      say "[run-all] Built shared deployed-tree fixture once at $RUN_ALL_SHARED_FIXTURE (read-only, lent to ${#SHARED_FIXTURE_CONSUMERS[@]} consumer suite(s))."
    else
      echo "WARNING: run-all.sh: shared deployed-tree fixture build failed; consuming suite(s) fall back to their own per-suite build." >&2
      chmod -R u+w "$_SFC_BUILD" 2>/dev/null || true
      rm -rf "$_SFC_BUILD" 2>/dev/null || true
    fi
    unset _SFC_OK
  fi
  unset _SFC_DEPLOY_SCRIPT _SFC_BUILD
fi

SUITE_RUN_START_MS="$(date +%s%3N)"

if [ "$JOBS" -le 1 ]; then
  # ── Sequential path (--jobs 1, the default) ───────────────────────────────────
  # Byte-for-byte the same code path and output as before --jobs existed. Do not fold this into
  # the parallel path below -- it is kept as its own branch specifically so "at --jobs 1 the code
  # path and output must be exactly today's" is trivially true by inspection, not by argument.
  # (SUITE_OUT is assigned, not trapped here -- the single composed trap above handles cleanup.)
  SUITE_OUT="$(mktemp)"

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
    # -k 5: if the suite ignores SIGTERM (the bound's primary signal), `timeout` escalates to
    # SIGKILL 5s later -- a suite must not be able to survive past the bound merely by trapping
    # or ignoring TERM. rc=124 is `timeout`'s own sentinel for "the bound fired"; distinguished
    # below from an ordinary suite failure so the [FAIL] line stays byte-identical to today's
    # and the timeout detail is additional, named, attributable information, not a replacement.
    if ( timeout -k 5 "$RUN_ALL_SUITE_TIMEOUT_S" bash "$suite" >"$SUITE_OUT" 2>&1 ); then
      _suite_result="PASS"
      PASS_COUNT=$((PASS_COUNT + 1))
      say "[run-all] [PASS] $suite_name"
    else
      _suite_rc=$?
      _suite_result="FAIL"
      FAIL_COUNT=$((FAIL_COUNT + 1))
      FAILED_SUITE_NAMES+=("$suite_name")
      echo "[FAIL] $suite_name"
      if [ "$_suite_rc" -eq 124 ] || [ "$_suite_rc" -eq 137 ]; then
        # 124: `timeout`'s own "it timed out" sentinel (the suite honored SIGTERM promptly).
        # 137: 128+SIGKILL -- the suite ignored/blocked SIGTERM, so `-k 5`'s escalation to
        # SIGKILL is what actually ended it. Both are "the bound fired," per `timeout --help`'s
        # own documented exit-status contract; a suite could in principle exit 137 on its own
        # for an unrelated reason, but that ambiguity is `timeout`'s own documented contract,
        # not a gap this wrapper introduces.
        echo "    TIMEOUT: $suite_name exceeded the ${RUN_ALL_SUITE_TIMEOUT_S}s per-suite bound and was killed"
      fi
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
  # (OUT_DIR is assigned, not trapped here -- the single composed trap installed before the
  # gate-lock bracket above handles cleanup.)
  OUT_DIR="$(mktemp -d)"

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
  #   - test-lint-shellcheck-parallel.sh: its default-path dispatch-shape case spins up several
  #     concurrent processes (a cheap stub shellcheck, not the real binary, over a 9-file
  #     fixture); the real-corpus relative-ratio comparison is opt-in behind
  #     RUN_REAL_CORPUS_TIMING=1, which run-all.sh never sets. Kept load-sensitive as a
  #     defense-in-depth measure: the dispatch-shape case's peak-concurrency assertion still
  #     depends on observable process-scheduling timing, the same contention/flakiness profile
  #     test-run-all-parallel.sh above was registered for.
  #   - test-gate-lock.sh: performs real specs/.gate-lock mutex contention and launches genuinely
  #     concurrent child `run-all.sh` processes against its own isolated fixture root (the
  #     serialization/non-vacuousness/stale-reclaim cases), the same real-contention-plus-
  #     concurrent-process-launch property that put test-state-write-concurrency.sh on this list.
  LOAD_SENSITIVE_BASENAMES=(
    "test-lake-build-guard.sh"
    "test-state-write-concurrency.sh"
    "test-state-write-regen-timing.sh"
    "test-four-tier-conflict.sh"
    "test-run-all-parallel.sh"
    "test-lint-shellcheck-parallel.sh"
    "test-gate-lock.sh"
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

  # Advisory hint-coverage report: a missing hint row never changes which suites run, skips any,
  # or fails this run (see this file's own ADVISORY ONLY header comment) -- it only biases
  # longest-first scheduling suboptimally. The point here is visibility, not enforcement: a newly
  # added suite that lands with no cost hint should be named in the output, not silently absorbed
  # into "appended after any hinted ones". Covers every suite that actually executes (the
  # scheduled pool plus the load-sensitive serial class); a non-executable (SKIP) suite needs no
  # hint at all.
  UNHINTED_NAMES=()
  for i in "${UNHINTED_POOL[@]}"; do
    UNHINTED_NAMES+=("$(basename "${SUITES[i]}")")
  done
  for i in "${LOAD_SENSITIVE_INDICES[@]}"; do
    _base="$(basename "${SUITES[i]}")"
    [ -n "${HINT_COST[$_base]:-}" ] || UNHINTED_NAMES+=("$_base")
  done
  if [ "${#UNHINTED_NAMES[@]}" -gt 0 ]; then
    say "[run-all] [INFO] ${#UNHINTED_NAMES[@]} suite(s) have no cost hint in $(basename "$COST_HINTS_FILE") (advisory only, does not affect which suites run): ${UNHINTED_NAMES[*]}"
  fi

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
  declare -a SUITE_RC=()
  for i in "${SKIP_INDICES[@]}"; do
    SUITE_RESULT[i]="SKIP"
    SUITE_MS[i]=0
  done

  run_one() {
    # Usage: run_one INDEX -- writes rc.$i and ms.$i under $OUT_DIR; suite output to out.$i.
    # rc.$i carries the REAL exit status (not collapsed to 0/1) specifically so the emission
    # loop below can distinguish `timeout`'s 124 sentinel from an ordinary suite failure and
    # attribute a bound-exceeded [FAIL] by name, matching the sequential path's -k 5 escalation.
    local i="$1"
    local suite="${SUITES[i]}"
    local start end
    start="$(date +%s%3N)"
    timeout -k 5 "$RUN_ALL_SUITE_TIMEOUT_S" bash "$suite" >"$OUT_DIR/out.$i" 2>&1
    echo "$?" > "$OUT_DIR/rc.$i"
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
    SUITE_RC[i]="$_rc"
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
        FAILED_SUITE_NAMES+=("$suite")
        echo "[FAIL] $suite"
        if [ "${SUITE_RC[i]:-0}" -eq 124 ] || [ "${SUITE_RC[i]:-0}" -eq 137 ]; then
          # See the sequential path's identical check for why both 124 and 137 are recognized.
          echo "    TIMEOUT: $suite exceeded the ${RUN_ALL_SUITE_TIMEOUT_S}s per-suite bound and was killed"
        fi
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

# Classify each failure as EXPECTED (basename matches a known-failures.txt row) or NEW
# (does not). With no manifest present, KNOWN_FAILURE_CATEGORY is empty, so every failure
# classifies NEW -- this is the "missing file degrades to today's behavior" contract; NEW_COUNT
# then always equals FAIL_COUNT, keeping --fail-on-new equivalent to the default in that case.
EXPECTED_COUNT=0
NEW_COUNT=0
declare -a FAILED_SUITE_STATUS=()
for _failed_name in "${FAILED_SUITE_NAMES[@]}"; do
  _failed_base="$(basename "$_failed_name")"
  if [ -n "${KNOWN_FAILURE_CATEGORY[$_failed_base]:-}" ]; then
    FAILED_SUITE_STATUS+=("EXPECTED")
    EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
  else
    FAILED_SUITE_STATUS+=("NEW")
    NEW_COUNT=$((NEW_COUNT + 1))
  fi
done

# End-of-run failure roster: printed unconditionally (not --quiet-suppressed, matching the
# inline [FAIL] line's own posture) immediately before the final tally, so failing suite
# identities are recoverable without set-differencing [RUN]/[PASS] markers. Deliberately carries
# zero occurrences of the literal token `[FAIL]` -- see the header comment's CRITICAL CONSTRAINT.
# Each entry is annotated (EXPECTED)/(NEW) only when a known-failures.txt manifest is present.
if [ "${#FAILED_SUITE_NAMES[@]}" -gt 0 ]; then
  echo "[run-all] Failing suites (${#FAILED_SUITE_NAMES[@]}):"
  for _idx in "${!FAILED_SUITE_NAMES[@]}"; do
    if [ "$MANIFEST_PRESENT" = "true" ]; then
      echo "    ${FAILED_SUITE_NAMES[_idx]} (${FAILED_SUITE_STATUS[_idx]})"
    else
      echo "    ${FAILED_SUITE_NAMES[_idx]}"
    fi
  done
fi

# The leading "N passed, M failed" prefix is byte-identical whether or not the manifest clause is
# appended, so any existing consumer parsing only the head of the line is unaffected.
if [ "$MANIFEST_PRESENT" = "true" ]; then
  echo "[run-all] $PASS_COUNT passed, $FAIL_COUNT failed ($EXPECTED_COUNT expected, $NEW_COUNT NEW), $SKIP_COUNT skipped, $TOTAL_DISCOVERED total"
else
  echo "[run-all] $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped, $TOTAL_DISCOVERED total"
fi

if [ -n "$TIMINGS_FILE" ]; then
  echo "TOTAL,$((SUITE_RUN_END_MS - SUITE_RUN_START_MS)),${PASS_COUNT}/${FAIL_COUNT}/${SKIP_COUNT}/${TOTAL_DISCOVERED}" >> "$TIMINGS_FILE"
fi

# --fail-on-new: exit nonzero only when at least one failure is NEW. Default (no flag) exit-code
# semantics are unchanged: exit 1 if any suite failed, EXPECTED or not.
if [ "$FAIL_ON_NEW" = "true" ]; then
  if [ "$NEW_COUNT" -gt 0 ]; then
    exit 1
  fi
  exit 0
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi

exit 0
