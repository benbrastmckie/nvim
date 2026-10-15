#!/usr/bin/env bash
# gate-registry-lib.sh - Parses scripts/gate-registry.data and executes one gate by id.
#
# THIS IS A THIN INTERPRETER, DELIBERATELY. The declarative registry removes the 23-gate
# copy-pasted `if gate_selected N; then ... fi` BOILERPLATE from verify-deploy.sh's top level
# (adding a migrated gate becomes a data-file row plus one `gateN_run` function, not a 40-line
# inline block), but it does NOT attempt to generically re-derive each gate's own selection,
# source-store guard, or output shape -- those 8 migrated gates are heterogeneous enough (see
# gate-registry.data's own header, and this task's plan Phase 4 Scope Hypothesis) that a generic
# fold would either special-case several gates in code (defeating the point) or silently change
# a SKIP message's exact text (breaking the byte-identical output this migration is required to
# preserve). So `gate_registry_execute` does exactly one thing: look up the function name
# registered for a gate id, and call it. Each `gateN_run` function remains fully self-contained
# -- it still performs its own `gate_selected` check, its own source-store guard (where
# applicable), and its own pass/fail/FINDINGS_LIST population, identically to the pre-registry
# inline code it was extracted from verbatim.
#
# CONTRACT (mirrors scripts/lib/manifest-routing-lib.sh's own contract verbatim):
#   - Never calls `exit` -- a faulty resolution at worst leaves a gate id unresolved (silently a
#     no-op for that id), never aborts the caller.
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Every internal variable is prefixed `_greg_` and is explicitly unset before each function
#     returns, so sourcing this file never leaks state into the calling shell's environment.
#   - A miss is signalled by empty output / a silent no-op, never a non-zero exit status.
#
# Exports SIX functions (load once, query many times -- this library is sourced, never
# re-executed per gate):
#
#   gate_registry_load [DATA_FILE]
#     Parses DATA_FILE (default: the sibling scripts/gate-registry.data) into the global
#     associative arrays below, keyed by gate id. Idempotent -- calling it twice simply
#     re-parses, which is harmless since the data file is static for the lifetime of one
#     verify-deploy.sh invocation. Must be called before any other function in this file; the
#     other three degrade to empty/no-op if the registry was never loaded, rather than erroring.
#
#   gate_registry_ids
#     Echoes every loaded gate id, space-separated, in ascending numeric order. This is what
#     verify-deploy.sh's own gate-execution loop iterates over
#     (`for _gate_id in $(gate_registry_ids); do "gate${_gate_id}_run"; done`).
#
#   gate_registry_execute <id>
#     Looks up the `invoke` field for <id> and calls that function directly (no subshell --
#     a subshell would strand the function's mutations to FINDINGS_LIST/PASS/FAIL/CURRENT_GATE,
#     which are globals in the calling verify-deploy.sh process). A gate id with no registered
#     function is a silent no-op (never an error): a lint-gate-registry.sh finding, not a runtime
#     abort, is the correct place to catch that. NOT currently used by verify-deploy.sh's own
#     loop (which calls `"gate${id}_run"` directly via the id itself, since the function-naming
#     convention IS the lookup for the migrated tranche) -- provided for a future consumer (e.g.
#     a selection surface that needs the registry's declared `invoke` name explicitly rather than
#     assuming the `gate${id}_run` convention, or an out-of-order/filtered execution path).
#
#   gate_registry_field <id> <field>
#     Echoes one field's value for <id> (one of: name, invoke, dependencies,
#     requires_source_store, timeout_s, cost_class, serialized), or empty on a miss. The single
#     read path lint-gate-registry.sh and test-gate-registry-resolution.sh use to validate the
#     data without each re-implementing the TSV parse.
#
#   gate_registry_exec_bounded <fn> <timeout_s> <outfile> <errfile> <statefile> [VAR...]
#     Runs bash function <fn> (taking no arguments -- every gateN_run is self-contained) under a
#     bounded timeout, the enforcement mechanism Phase 6 (Uniform Bounded Timeouts Per Gate and
#     Per Suite) requires. <timeout_s> empty or "0" means "no declared bound": <fn> is called
#     DIRECTLY, in the current shell, with no capture and no subshell at all -- byte-identical to
#     every call site's pre-Phase-6 behavior, and the correct degrade-safe default for any future
#     gate the registry carries with no timeout_s populated.
#
#     With a positive <timeout_s>, <fn> MUST run in a forked subshell to be killably bounded --
#     not safe to parallel-schedule only, but the one architectural requirement a function-level
#     timeout imposes no matter how many gates run concurrently (0 today). A subshell strands any
#     mutation <fn> makes to the CALLER's globals (see gate_registry_execute's own header for why
#     it avoids a subshell for exactly this reason) -- a real cost here, paid deliberately, since
#     interruptibility requires a real OS-level child process to send a signal to, which a same-
#     process function call can never be. The VAR... arguments are the caller's own global
#     variable NAMES (e.g. `CHECKS FAILURES FINDINGS_LIST CURRENT_GATE`) this call should
#     reconcile across that subshell boundary: on a clean (non-timeout) finish, the subshell
#     dumps those variables' final values via `declare -p` to <statefile>, and the CALLER is
#     responsible for `source`-ing <statefile> afterward to restore continuity -- this function
#     does not do so itself, since sourcing an arbitrary file name back into globals the caller
#     alone knows how to interpret is the caller's business, not this thin interpreter's. Passing
#     no VAR names is valid (an empty <statefile>, nothing to source) for a caller with no global
#     state to carry across a gate boundary. <outfile>/<errfile> receive <fn>'s stdout/stderr
#     verbatim (same separation, same byte content, buffered rather than live-streamed) when a
#     subshell was used; with no bound declared, output goes straight to the caller's own
#     inherited stdout/stderr, and both files are left untouched (do not assume they were
#     created -- check before reading).
#
#     Returns 124 (the same sentinel GNU `timeout` uses) when <fn> did not finish within
#     <timeout_s> -- the one return value this function's caller must specifically branch on, to
#     emit its OWN attributable "named the gate, named the bound" failure (this library does not
#     know the caller's FAIL-reporting convention, so it does not attempt to produce one itself).
#     On a timeout, the entire process GROUP <fn> was running in is sent SIGTERM then, after a
#     grace period, SIGKILL -- not merely the immediate child -- so a gate that itself shells out
#     (Gate 8 -> tests/run-all.sh -> further suite processes; Gate 13's headless nvim) cannot
#     leave an orphaned grandchild running past the bound. This requires <fn>'s own backgrounded
#     job to carry its OWN process group, established via `set -m` (bash job-control monitor
#     mode) inside the wrapping subshell rather than via the external `setsid` binary -- `set -m`
#     is a bash builtin with no extra binary dependency, matching this codebase's existing
#     portability bar (see run-all.sh's own "Portable command" precedent for the standard this
#     file holds itself to) -- `setsid` is util-linux-only and not guaranteed present on every
#     platform this script might run on.
#
#     On a clean finish (no timeout), returns <fn>'s own exit status, unchanged from direct-call
#     behavior.
#
#   gate_registry_exec_concurrent_batch <jobs> <outdir> [VAR...]
#     Runs EVERY loaded gate id concurrently, a direct port of tests/run-all.sh's own
#     proven worker-slot-pool shape (see that script's header for the rejected alternatives --
#     a fixed cap rather than bare `nproc`, no self-maintaining timing cache -- both honored
#     here rather than re-proposed), extended with two things run-all.sh's own suite-level pool
#     does not need: WAVE-BARRIER dependency honouring (a dependent gate must never start before
#     every one of its declared prerequisites has finished -- run-all.sh's suites have no
#     producer/consumer relationship among them, so it never needed this) and the SAME
#     capture-then-reconcile protocol gate_registry_exec_bounded already established (see that
#     function's own header for why a killable bound requires a real subshell, which strands
#     caller-scope mutations unless explicitly dumped via `declare -p` and restored by the
#     caller).
#
#     <jobs> is the worker-slot cap (must already be resolved to a positive integer by the
#     caller -- this function does not interpret "auto" and does not apply the nested-invocation
#     forcing-to-1 guard itself; see verify-deploy.sh's own call site for both, mirroring
#     RUN_ALL_NESTED's forcing happening in run-all.sh itself, not inside a sourced lib). <outdir>
#     is a directory the caller owns (create and remove it); for every id, this function writes
#     outdir/out.$id, outdir/err.$id, outdir/state.$id (identical four-artifact shape
#     gate_registry_exec_bounded itself produces for one id, reused verbatim) and
#     outdir/rc.$id (the REAL, uncollapsed exit status -- 124 for "this id's own bound fired,"
#     matching gate_registry_exec_bounded's own sentinel -- so the caller can apply the exact
#     same timeout-vs-ordinary-failure branch it already uses for the sequential path). The
#     VAR... names are the caller's own globals (e.g. CHECKS FAILURES FINDINGS_LIST CURRENT_GATE)
#     threaded straight through to every per-id gate_registry_exec_bounded call; this function
#     itself never reads or reconciles them -- same separation of concerns as
#     gate_registry_exec_bounded's own caller-reconciles contract: the CALLER sources each
#     id's state.$id (in whatever order it wants -- this library has no opinion on emission
#     order) after this function returns.
#
#     SCHEDULING, in order:
#       1. Partition loaded ids into SERIALIZED (registry `serialized=true`, gate8 only today)
#          and POOL (everything else). Mirrors run-all.sh's LOAD_SENSITIVE_BASENAMES precedent
#          exactly: an ambient-load precaution (gate8 itself spawns up to run-all.sh's own
#          JOBS_CAP additional nested processes), not a resource-collision requirement -- a live
#          audit of every one of the 23 real migrated gates' function bodies for a fixed-path
#          write, lock, or socket outside its own mktemp-scoped fixture found none (see
#          context/standards/shell-script-testing.md's gate-level parallelism-safety audit
#          record, the Phase 7 extension of run-all.sh's own documented audit).
#       2. Resolve a WAVE number per pool id from the registry's own `dependencies` field:
#          wave(id) = 1 + max(wave(dep) for dep in dependencies(id)), or 0 if id has no
#          dependencies (every one of the real registry's 23 gates today -- this machinery is
#          exercised live only by a synthetic test registry until a future gate declares a real
#          dependency). A dependency id absent from this run (filtered out, or simply unknown)
#          is treated as already-satisfied, contributing nothing to the max. A cycle (detected
#          via a visiting-set) falls back that id to wave 0 rather than looping or aborting --
#          never let a malformed dependency graph hang the battery.
#       3. Run wave 0's serialized ids first, one at a time, in ascending id order -- strictly
#          before wave 0's own pool starts.
#       4. For each wave in ascending order, run that wave's pool ids concurrently, bounded by
#          <jobs>, LONGEST-FIRST by the registry's own `cost_class` field (Phase 3's cost model,
#          already folded into this data file: slow, then moderate, then free), ties broken by
#          ascending id for determinism. `wait` once a wave's pool is fully dispatched (a hard
#          barrier) before starting the next wave -- the one mechanism that actually PROVES "a
#          dependent gate never starts before its prerequisite completes" rather than merely
#          scheduling hopefully.
#
#     An empty/zero declared timeout_s (none of the real registry's 23 gates has one -- see
#     test-gate-registry-resolution.sh's case14 pin) falls back to a generous 600s bound ONLY in
#     this concurrent path, never in the sequential gate_registry_exec_bounded call site that
#     caller still uses at jobs<=1: under concurrency every gate id MUST run in its own forked,
#     capturable subshell for the capture-then-reconcile protocol to work at all (the alternative
#     -- a same-process direct call -- would run inside THIS function's own backgrounded pool
#     job, stranding its mutations exactly the way a same-process call always does, since nothing
#     downstream would ever read a statefile that was never written). The sequential path's
#     documented byte-identical-when-empty behavior is unaffected; this fallback exists only on
#     the branch nothing in the real registry exercises today.

declare -gA _GREG_NAME=()
declare -gA _GREG_INVOKE=()
declare -gA _GREG_DEPS=()
declare -gA _GREG_SOURCE_STORE=()
declare -gA _GREG_TIMEOUT=()
declare -gA _GREG_COST_CLASS=()
declare -gA _GREG_SERIALIZED=()
_GREG_IDS=()
_GREG_LOADED=false

gate_registry_load() {
  local _greg_file="${1:-}"
  local _greg_self_dir _greg_line
  local _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser

  if [ -z "$_greg_file" ]; then
    _greg_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    _greg_file="${_greg_self_dir}/gate-registry.data"
  fi

  _GREG_NAME=(); _GREG_INVOKE=(); _GREG_DEPS=(); _GREG_SOURCE_STORE=()
  _GREG_TIMEOUT=(); _GREG_COST_CLASS=(); _GREG_SERIALIZED=(); _GREG_IDS=()
  _GREG_LOADED=false

  if [ ! -f "$_greg_file" ]; then
    unset _greg_file _greg_self_dir _greg_line _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser
    return 0
  fi

  while IFS=$'\t' read -r _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser; do
    # Skip comments (lines starting with #) and blank lines -- same loud-skip-free advisory
    # convention as suite-cost-hints.txt.
    case "$_greg_id" in
      ''|'#'*) continue ;;
    esac
    case "$_greg_id" in
      ''|*[!0-9]*) continue ;;  # malformed id -- not a valid row, skip rather than abort
    esac
    _GREG_NAME["$_greg_id"]="$_greg_name"
    _GREG_INVOKE["$_greg_id"]="$_greg_invoke"
    # "-" is the data file's placeholder for "no dependencies" -- a TRULY empty field between
    # two tabs is unreliable under `IFS=$'\t' read`, because bash classifies tab as an
    # IFS-whitespace character even when it is IFS's sole member, so consecutive-delimiter
    # (empty-field) sequences silently collapse and shift every later column by one. Normalize
    # the placeholder back to empty here, once, so every consumer of this array sees "" for "no
    # dependencies" regardless of the file's own on-disk placeholder convention.
    [ "$_greg_deps" = "-" ] && _greg_deps=""
    _GREG_DEPS["$_greg_id"]="$_greg_deps"
    _GREG_SOURCE_STORE["$_greg_id"]="$_greg_rss"
    _GREG_TIMEOUT["$_greg_id"]="$_greg_timeout"
    _GREG_COST_CLASS["$_greg_id"]="$_greg_class"
    _GREG_SERIALIZED["$_greg_id"]="$_greg_ser"
    _GREG_IDS+=("$_greg_id")
  done < "$_greg_file"

  # Sort ids numerically, ascending -- deterministic iteration order regardless of the data
  # file's own row order (today they are already ascending, but this must not be assumed).
  if [ "${#_GREG_IDS[@]}" -gt 0 ]; then
    mapfile -t _GREG_IDS < <(printf '%s\n' "${_GREG_IDS[@]}" | sort -n)
  fi

  _GREG_LOADED=true
  unset _greg_file _greg_self_dir _greg_line _greg_id _greg_name _greg_invoke _greg_deps _greg_rss _greg_timeout _greg_class _greg_ser
  return 0
}

gate_registry_ids() {
  if [ "${#_GREG_IDS[@]}" -eq 0 ]; then
    return 0
  fi
  printf '%s\n' "${_GREG_IDS[@]}" | tr '\n' ' ' | sed 's/ $//'
  echo ""
  return 0
}

gate_registry_execute() {
  local _greg_id="$1" _greg_fn
  _greg_fn="${_GREG_INVOKE[$_greg_id]:-}"
  if [ -n "$_greg_fn" ] && declare -F "$_greg_fn" >/dev/null 2>&1; then
    "$_greg_fn"
  fi
  unset _greg_id _greg_fn
  return 0
}

gate_registry_field() {
  local _greg_id="$1" _greg_field="$2" _greg_result=""
  case "$_greg_field" in
    name) _greg_result="${_GREG_NAME[$_greg_id]:-}" ;;
    invoke) _greg_result="${_GREG_INVOKE[$_greg_id]:-}" ;;
    dependencies) _greg_result="${_GREG_DEPS[$_greg_id]:-}" ;;
    requires_source_store) _greg_result="${_GREG_SOURCE_STORE[$_greg_id]:-}" ;;
    timeout_s) _greg_result="${_GREG_TIMEOUT[$_greg_id]:-}" ;;
    cost_class) _greg_result="${_GREG_COST_CLASS[$_greg_id]:-}" ;;
    serialized) _greg_result="${_GREG_SERIALIZED[$_greg_id]:-}" ;;
  esac
  echo "$_greg_result"
  unset _greg_id _greg_field _greg_result
  return 0
}

# gate_registry_exec_bounded -- see this file's header for the full contract (degrade-safe
# no-bound path, subshell/state-dump reconciliation protocol, process-group kill, 124 sentinel).
gate_registry_exec_bounded() {
  local _greg_fn="$1" _greg_timeout="$2" _greg_outfile="$3" _greg_errfile="$4" _greg_statefile="$5"
  shift 5
  local -a _greg_vars=("$@")
  local _greg_pid _greg_rc _greg_pgidfile _greg_group
  local _greg_elapsed_tenths=0 _greg_timeout_tenths

  if [ -z "$_greg_timeout" ] || [ "$_greg_timeout" = "0" ]; then
    # No declared bound -- direct call, same process, no capture. Byte-identical to every
    # pre-Phase-6 call site.
    "$_greg_fn"
    _greg_rc=$?
    unset _greg_fn _greg_timeout _greg_outfile _greg_errfile _greg_statefile _greg_vars
    return "$_greg_rc"
  fi

  _greg_pgidfile="$(mktemp)"

  (
    set -m
    # The function call AND its state dump must run inside the SAME backgrounded job (one `{
    # ...; } &` group = one fork) -- if `declare -p` instead followed a separate `"$_greg_fn" &
    # ... wait`, the dump would run in THIS subshell while <fn>'s own mutations happened in the
    # further-nested child that `&` forks for <fn> itself, and would see none of them. Grouping
    # them with `{ }` keeps <fn>'s mutations and the dump that reads them in one process.
    {
      "$_greg_fn"
      _greg_body_rc=$?
      if [ "${#_greg_vars[@]}" -gt 0 ]; then
        declare -p "${_greg_vars[@]}" > "$_greg_statefile" 2>/dev/null
      fi
      exit "$_greg_body_rc"
    } &
    echo "$!" > "$_greg_pgidfile"
    wait "$!"
  ) >"$_greg_outfile" 2>"$_greg_errfile" &
  _greg_pid=$!

  _greg_timeout_tenths=$(( _greg_timeout * 10 ))
  while [ "$_greg_elapsed_tenths" -lt "$_greg_timeout_tenths" ]; do
    if ! kill -0 "$_greg_pid" 2>/dev/null; then
      break
    fi
    sleep 0.1
    _greg_elapsed_tenths=$(( _greg_elapsed_tenths + 1 ))
  done

  if kill -0 "$_greg_pid" 2>/dev/null; then
    # Still alive at the bound -- kill the WHOLE process group `set -m` gave <fn>'s backgrounded
    # job (negative pgid), not merely the wrapping subshell, so a grandchild (Gate 8's run-all.sh
    # suite processes; Gate 13's headless nvim) cannot survive as an orphan.
    _greg_group="$(cat "$_greg_pgidfile" 2>/dev/null)"
    [ -n "$_greg_group" ] && kill -TERM "-$_greg_group" 2>/dev/null
    kill -TERM "$_greg_pid" 2>/dev/null
    sleep 0.3
    [ -n "$_greg_group" ] && kill -KILL "-$_greg_group" 2>/dev/null
    kill -KILL "$_greg_pid" 2>/dev/null
    wait "$_greg_pid" 2>/dev/null
    rm -f "$_greg_pgidfile"
    unset _greg_fn _greg_timeout _greg_outfile _greg_errfile _greg_statefile _greg_vars _greg_pid _greg_group _greg_elapsed_tenths _greg_timeout_tenths
    return 124
  fi

  wait "$_greg_pid"
  _greg_rc=$?
  rm -f "$_greg_pgidfile"
  unset _greg_fn _greg_timeout _greg_outfile _greg_errfile _greg_statefile _greg_vars _greg_pid _greg_group _greg_elapsed_tenths _greg_timeout_tenths
  return "$_greg_rc"
}

# gate_registry_exec_concurrent_batch -- see this file's header for the full contract (wave-
# barrier dependency honouring, serialized-class isolation, longest-first cost-class scheduling,
# the four-artifact-per-id output shape, the concurrency-only timeout fallback).
# ── Reconciliation helpers for gate_registry_exec_concurrent_batch ──────────────────────────
#
# WHY THIS EXISTS (read before touching either function below): a naive "just source each id's
# state.$id file in sequence" reconciliation -- which is exactly what the SEQUENTIAL gate loop
# gets away with, because it is sequential -- is WRONG for concurrently-forked ids. Every
# subshell gate_registry_exec_bounded forks for a concurrently-scheduled id inherits the SAME
# snapshot of the caller's named vars (whatever CHECKS/FAILURES/FINDINGS_LIST/CURRENT_GATE
# equalled the instant that id's job was backgrounded), mutates its OWN private copy, and dumps
# that copy's FINAL value -- not a delta, not aware of any sibling id's own dump. A bare
# `source state.$id` for id A followed by `source state.$id` for id B does not ACCUMULATE A's
# contribution into B's -- it REPLACES A's dump with B's, because both dumps are independently
# "snapshot + own delta", not "running total". Sourcing them in sequence silently drops every
# id's contribution except the last one sourced. (Caught live during this phase's own
# implementation via a smoke test: CHECKS collapsed from an expected 6 to 1, FINDINGS_LIST from
# 6 entries to 1, across 6 synthetic concurrent gates that should have summed/unioned.)
#
# THE FIX: capture a snapshot of each named var's baseline (scalar value, or array length)
# immediately before forking a batch of jobs that will share it, then for each job's dump,
# compute ONLY that job's own DELTA against the shared snapshot and APPLY the delta to the real
# var (sum for a numeric scalar, append-new-tail-elements for an array, last-write-wins for a
# non-numeric scalar such as CURRENT_GATE, where "which gate narrated last" is cosmetic and
# unread downstream either way). Applying deltas incrementally, one job at a time, composes
# correctly across any number of ids sharing one snapshot. This is why the batch function below
# snapshots once per dispatched group (each serialized id gets its own one-job snapshot; each
# wave's pool shares one snapshot for the whole wave) and reconciles immediately after that
# group's jobs finish, before moving on -- not once at the very end, which would equally be
# correct arithmetically but was not done because the NEXT wave's baseline is obviously supposed
# to reflect every prior wave's completed work (even though no gate function reads these vars
# today, that is the only sane model if one ever does).

# _greg_snapshot_vars <VAR...>: populates the global _GREG_SNAP_SCALAR/_GREG_SNAP_LEN maps from
# the REAL named vars' CURRENT values -- the shared baseline every job in the next dispatched
# group will fork from. Call fresh immediately before dispatching that group.
declare -gA _GREG_SNAP_SCALAR=()
declare -gA _GREG_SNAP_LEN=()
_greg_snapshot_vars() {
  # Reassert -A explicitly on every reset (never a bare `NAME=()`): gate_registry_exec_concurrent_
  # batch's own cleanup `unset`s both maps after each call (so a caller never sees stale baseline
  # data from a PRIOR invocation), and `unset` on a `declare -gA` variable removes its type along
  # with its value -- a later bare `NAME=()` would silently recreate it as an ORDINARY INDEXED
  # array instead of associative. That is not cosmetic: a subsequent `MAP["$key"]=val` on an
  # indexed array evaluates the string key ARITHMETICALLY, and once the real var the key names
  # (e.g. "FINDINGS") already holds element text containing a hyphen (e.g. "finding-1"), bash's
  # arithmetic evaluator parses that as a subtraction expression and chokes on the unset bare
  # identifier before the hyphen -- this exact chain was caught live, across a second real call to
  # gate_registry_exec_concurrent_batch within one process, before this reassertion was added.
  declare -gA _GREG_SNAP_SCALAR=()
  declare -gA _GREG_SNAP_LEN=()
  local _gs_v _gs_decl
  for _gs_v in "$@"; do
    _gs_decl="$(declare -p "$_gs_v" 2>/dev/null)"
    case "$_gs_decl" in
      "declare -a"*|"declare -A"*)
        local -n _gs_ref="$_gs_v"
        _GREG_SNAP_LEN["$_gs_v"]="${#_gs_ref[@]}"
        ;;
      *)
        _GREG_SNAP_SCALAR["$_gs_v"]="${!_gs_v:-0}"
        ;;
    esac
  done
}

# _greg_apply_delta <STATEFILE> <VAR...>: applies ONE id's dumped state to the REAL named vars,
# using the most recent _greg_snapshot_vars call as the shared baseline. Renames every target
# var with a disposable prefix (via sed on a throwaway copy of the dump, never the original
# file) before sourcing, specifically so a bare `source` never clobbers the real var directly --
# only this function's own arithmetic/append logic, below, is allowed to touch it.
_greg_apply_delta() {
  local _ga_state="$1"
  shift
  [ -s "$_ga_state" ] || return 0
  local _ga_prefix="_GREG_REMOTE_"
  local _ga_tmp _ga_v _ga_sedexpr=""
  for _ga_v in "$@"; do
    _ga_sedexpr="${_ga_sedexpr}s/^declare \([-a-zA-Z]*\) ${_ga_v}=/declare \1 ${_ga_prefix}${_ga_v}=/; "
  done
  _ga_tmp="$(mktemp)"
  sed "$_ga_sedexpr" "$_ga_state" > "$_ga_tmp"
  # shellcheck disable=SC1090
  source "$_ga_tmp"
  rm -f "$_ga_tmp"

  for _ga_v in "$@"; do
    local _ga_remote="${_ga_prefix}${_ga_v}"
    [ -n "${!_ga_remote+x}" ] || continue
    local _ga_decl
    _ga_decl="$(declare -p "$_ga_remote" 2>/dev/null)"
    case "$_ga_decl" in
      "declare -a"*|"declare -A"*)
        local -n _ga_real_arr="$_ga_v"
        local -n _ga_remote_arr="$_ga_remote"
        local _ga_base_len="${_GREG_SNAP_LEN[$_ga_v]:-0}"
        local _ga_i
        for ((_ga_i = _ga_base_len; _ga_i < ${#_ga_remote_arr[@]}; _ga_i++)); do
          _ga_real_arr+=("${_ga_remote_arr[_ga_i]}")
        done
        ;;
      *)
        local _ga_remote_val="${!_ga_remote}"
        local -n _ga_real_scalar="$_ga_v"
        case "$_ga_remote_val" in
          ''|*[!0-9]*)
            # Non-numeric scalar (e.g. CURRENT_GATE): last-writer-wins -- cosmetic only, nothing
            # downstream reads this across a concurrent batch's own internal ordering.
            _ga_real_scalar="$_ga_remote_val"
            ;;
          *)
            local _ga_base_val="${_GREG_SNAP_SCALAR[$_ga_v]:-0}"
            _ga_real_scalar=$(( _ga_real_scalar + (_ga_remote_val - _ga_base_val) ))
            ;;
        esac
        ;;
    esac
    unset "$_ga_remote"
  done
}

gate_registry_exec_concurrent_batch() {
  local _greg_jobs="$1" _greg_outdir="$2"
  shift 2
  local -a _greg_vars=("$@")

  if [ "${#_GREG_IDS[@]}" -eq 0 ]; then
    unset _greg_jobs _greg_outdir _greg_vars
    return 0
  fi

  # ── Partition: serialized vs. pool ──────────────────────────────────────────
  local -a _greg_serial_ids=() _greg_pool_ids=()
  local _greg_id _greg_rc
  for _greg_id in "${_GREG_IDS[@]}"; do
    if [ "${_GREG_SERIALIZED[$_greg_id]:-false}" = "true" ]; then
      _greg_serial_ids+=("$_greg_id")
    else
      _greg_pool_ids+=("$_greg_id")
    fi
  done

  # ── Wave assignment over the pool ids, memoized via two function-local-to-this-call global
  # scratch arrays (unset at the end of this function -- never leaked to the caller's shell). ──
  declare -gA _GREG_WAVE=()
  declare -gA _GREG_VISITING=()
  _greg_resolve_wave() {
    local id="$1"
    if [ -n "${_GREG_WAVE[$id]:-}" ]; then
      echo "${_GREG_WAVE[$id]}"
      return 0
    fi
    if [ "${_GREG_VISITING[$id]:-}" = "1" ]; then
      # Cycle detected -- fall back to wave 0 rather than recursing forever.
      _GREG_WAVE[$id]=0
      echo 0
      return 0
    fi
    _GREG_VISITING[$id]=1
    local _deps="${_GREG_DEPS[$id]:-}" _max=-1 _d _dw
    if [ -n "$_deps" ]; then
      local -a _dep_arr
      IFS=',' read -r -a _dep_arr <<< "$_deps"
      for _d in "${_dep_arr[@]}"; do
        [ -n "$_d" ] || continue
        # A dependency id absent from this run's loaded registry (filtered out, or simply
        # unknown) is treated as already-satisfied -- it contributes nothing to the max, it
        # never blocks scheduling.
        [ -z "${_GREG_INVOKE[$_d]:-}" ] && continue
        _dw="$(_greg_resolve_wave "$_d")"
        [ "$_dw" -gt "$_max" ] && _max="$_dw"
      done
    fi
    unset '_GREG_VISITING[$id]'
    _GREG_WAVE[$id]=$((_max + 1))
    echo "${_GREG_WAVE[$id]}"
  }
  for _greg_id in "${_greg_pool_ids[@]}"; do
    _greg_resolve_wave "$_greg_id" >/dev/null
  done

  local _greg_max_wave=0
  for _greg_id in "${_greg_pool_ids[@]}"; do
    [ "${_GREG_WAVE[$_greg_id]}" -gt "$_greg_max_wave" ] && _greg_max_wave="${_GREG_WAVE[$_greg_id]}"
  done

  # cost-class rank for longest-first tie-break within a wave: slow first, then moderate, then
  # free; an unrecognized/missing class ranks alongside moderate (a reasonable, documented
  # middle default -- never first, never last, for a gate whose cost_class is somehow absent).
  local -A _greg_cost_rank=([slow]=0 [moderate]=1 [free]=2)

  _greg_pool_job() {
    local id="$1"
    local fn timeout_s
    fn="${_GREG_INVOKE[$id]:-}"
    timeout_s="${_GREG_TIMEOUT[$id]:-}"
    # See this function's header comment, final paragraph: under concurrency every id MUST run
    # in its own bounded, capturable subshell, regardless of its own declared timeout_s -- an
    # empty one (dead code against the real registry; see test-gate-registry-resolution.sh
    # case14) falls back to a generous 600s bound HERE ONLY, never on the sequential path.
    [ -z "$timeout_s" ] && timeout_s=600
    gate_registry_exec_bounded "$fn" "$timeout_s" \
      "$_greg_outdir/out.$id" "$_greg_outdir/err.$id" "$_greg_outdir/state.$id" \
      "${_greg_vars[@]}"
    echo "$?" > "$_greg_outdir/rc.$id"
  }

  local _greg_wave_num
  for ((_greg_wave_num = 0; _greg_wave_num <= _greg_max_wave; _greg_wave_num++)); do
    local -a _greg_wave_ids=()
    for _greg_id in "${_greg_pool_ids[@]}"; do
      [ "${_GREG_WAVE[$_greg_id]}" -eq "$_greg_wave_num" ] && _greg_wave_ids+=("$_greg_id")
    done

    # Serialized ids run alone, ascending id order, strictly before wave 0's own pool starts --
    # mirrors run-all.sh's LOAD_SENSITIVE_BASENAMES precedent (always first, regardless of the
    # parallel pool's own schedule). Each one is its own one-job "batch": snapshot immediately
    # before it runs, reconcile its delta immediately after -- so the NEXT serialized id (or the
    # wave-0 pool right after) forks from an already-up-to-date baseline, never a stale one.
    if [ "$_greg_wave_num" -eq 0 ]; then
      for _greg_id in "${_greg_serial_ids[@]}"; do
        _greg_snapshot_vars "${_greg_vars[@]}"
        _greg_pool_job "$_greg_id"
        _greg_rc="$(cat "$_greg_outdir/rc.$_greg_id" 2>/dev/null || echo 1)"
        [ "$_greg_rc" != "124" ] && _greg_apply_delta "$_greg_outdir/state.$_greg_id" "${_greg_vars[@]}"
      done
    fi

    [ "${#_greg_wave_ids[@]}" -eq 0 ] && continue

    # Longest-first within this wave: sort by cost-class rank, then ascending id.
    mapfile -t _greg_wave_ids < <(
      for _greg_id in "${_greg_wave_ids[@]}"; do
        printf '%s %s\n' "${_greg_cost_rank[${_GREG_COST_CLASS[$_greg_id]:-moderate}]:-1}" "$_greg_id"
      done | sort -n -k1,1 -k2,2n | awk '{print $2}'
    )
    # Drain the process-substitution pipeline's own background reader before the worker-cap
    # dispatch loop's `wait -n` calls begin. CAUGHT LIVE as an intermittent (~1-in-10) cap
    # violation during this phase's own implementation: `mapfile ... < <(...)` backgrounds a
    # process to feed the substitution, and bash's job table can still be holding that process
    # unwaited at this point. The dispatch loop below is about to call `wait -n` expecting EVERY
    # such call to correspond to one of ITS OWN `_greg_pool_job &` jobs finishing; if the very
    # first `wait -n` instead reaps this leftover reader, `_greg_active` gets decremented with
    # NO pool job having actually finished, letting the loop launch one EXTRA job past the
    # declared cap -- reproduced directly: 6 synthetic jobs at cap 2 occasionally ran 3
    # concurrently, confirmed via non-racing flock-guarded counters (a naive, non-atomic
    # read-modify-write counter could only ever UNDER-count a real violation here, never
    # fabricate one, so it masked this for several initial runs). A bare `wait` with no cap
    # loop forming yet is correct and cheap here: it only has this one pipeline's reader left to
    # reap, never any pool job (none has been launched yet).
    wait

    # One shared snapshot for the WHOLE wave: every job dispatched below forks from this exact
    # baseline, regardless of completion order, so each one's delta is computed against the
    # same reference point (see the reconciliation-helpers comment above for why this must be a
    # single shared snapshot per concurrently-dispatched group, not a per-job one).
    _greg_snapshot_vars "${_greg_vars[@]}"

    local _greg_active=0
    for _greg_id in "${_greg_wave_ids[@]}"; do
      while [ "$_greg_active" -ge "$_greg_jobs" ]; do
        wait -n
        _greg_active=$((_greg_active - 1))
      done
      _greg_pool_job "$_greg_id" &
      _greg_active=$((_greg_active + 1))
    done
    # Hard barrier: do not start the next wave until every job in THIS wave has returned -- the
    # one mechanism that actually proves a dependent id never starts before its prerequisite.
    wait

    # Reconcile this wave's deltas, ascending id order (deterministic; CHECKS/FAILURES sums and
    # FINDINGS_LIST's eventual set are order-independent regardless, but CURRENT_GATE's cosmetic
    # last-write-wins is at least reproducible rather than racing on completion order).
    for _greg_id in "${_greg_wave_ids[@]}"; do
      _greg_rc="$(cat "$_greg_outdir/rc.$_greg_id" 2>/dev/null || echo 1)"
      [ "$_greg_rc" != "124" ] && _greg_apply_delta "$_greg_outdir/state.$_greg_id" "${_greg_vars[@]}"
    done
  done

  unset -f _greg_pool_job _greg_resolve_wave
  unset _GREG_WAVE _GREG_VISITING _GREG_SNAP_SCALAR _GREG_SNAP_LEN
  unset _greg_cost_rank _greg_serial_ids _greg_pool_ids _greg_id _greg_max_wave _greg_wave_num
  unset _greg_wave_ids _greg_active _greg_jobs _greg_outdir _greg_vars _greg_rc
  return 0
}

# gate_registry_shared_corpus_build <root>
#   Phase 9 ("Shared Corpus Enumeration"): produces ONE master tracked-path list per
#   verify-deploy.sh invocation -- `git ls-files` over <root>'s `agent-system/extensions`
#   subtree, written NUL-delimited to a fresh `mktemp` file -- and echoes that file's path on
#   stdout. This is a pure corpus PRODUCER, deliberately generic: it does not know or care which
#   gates will filter it, or by what pattern (today's affected lints use differing filters --
#   `*.sh`, `*.md`, `*.sh`+`*.md`, specific JSON basenames, a scripts/-minus-tests/-minus-
#   deprecated/ subtree -- see each affected lint's own shared-corpus branch, not this function,
#   for that). The matching CONSUMER half is lib/common.sh's common_shared_corpus_files /
#   common_shared_corpus_available, which every affected lint already sources; this function and
#   that pair agree on exactly two contracts: the output file is NUL-delimited, and each line is
#   a path RELATIVE to <root> (git ls-files' own natural output, never rewritten to absolute
#   here) -- the consumer side re-prefixes with its own root before use (see
#   GATE_SHARED_CORPUS_ROOT below).
#
#   Returns an EMPTY corpus (a zero-byte file, never an error) when <root>/agent-system/
#   extensions does not exist -- <root> is a deploy consumer, not the source store, exactly the
#   case every affected lint's own [SKIP] guard already handles independently; an empty corpus
#   file still satisfies common_shared_corpus_available's readability check, so a consumer sees
#   "corpus available, zero matches" rather than falling back to its own enumeration -- harmless
#   either way since a deploy-consumer TARGET's lints already [SKIP] before ever reaching their
#   own FILES-collection code.
#
#   The caller (verify-deploy.sh) is responsible for exporting the returned path as
#   GATE_SHARED_CORPUS_FILE, exporting <root> itself as GATE_SHARED_CORPUS_ROOT (the prefix every
#   consumer re-applies to each relative line), and removing the temp file on exit -- this
#   function does not export anything itself and does not register a cleanup trap, the same
#   "thin interpreter, no caller-env mutation beyond stdout" discipline as every other function
#   in this file.
gate_registry_shared_corpus_build() {
  local _greg_root="${1:-}"
  local _greg_outfile
  _greg_outfile="$(mktemp)" || { unset _greg_root; return 1; }
  if [ -n "$_greg_root" ] && [ -d "$_greg_root/agent-system/extensions" ]; then
    (cd "$_greg_root" && git ls-files -z -- 'agent-system/extensions') > "$_greg_outfile" 2>/dev/null
  fi
  printf '%s\n' "$_greg_outfile"
  unset _greg_root _greg_outfile
  return 0
}
