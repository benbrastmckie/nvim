#!/usr/bin/env bash
# state-write.sh - The single mutex-guarded writer for specs/state.json and its archive/vault
# counterparts.
#
# Every specs/state.json read-modify-write in this codebase is meant to go through this one
# helper instead of hand-rolling its own `jq ... > tmp && mv tmp state.json` sequence. Before
# this script existed, nine scripts plus two inline command-file write blocks each rolled their
# own sequence, only two of which acquired the specs/.scope-lock mutex at all -- and both of
# those failed OPEN on acquire timeout, so serialization silently stopped applying under exactly
# the contention it exists for. A second, independent corruption channel ran alongside: several
# scripts staged through fixed, shared temp paths with unconditional `rm -f` EXIT traps, so one
# process's normal exit could delete another's in-flight staging file regardless of any mutex
# work. This script closes both channels: fail-closed mutex acquisition, a private per-process
# `mktemp` staging path, and a single acquire -> stage -> transform -> validate -> mv -> release
# sequence that every writer shares.
#
# `--state-file` extends this same sequence to archive and vault targets (the default target,
# `specs/state.json`, is unchanged for every pre-existing caller). `--init` extends it further to
# fresh-create targets that have no existing file to transform. See the "`--state-file` and
# `--init`" section below for both contracts in full, including why the mutex stays a single,
# unparameterized global across every target rather than becoming per-file.
#
# Usage:
#   state-write.sh <jq-filter> --session-id SID [--state-file PATH] [--init]
#                  [--arg NAME VALUE]... [--argjson NAME VALUE]... [--regen-todo] [--dry-run]
#
# Arguments:
#   <jq-filter>     Required. An arbitrary jq filter applied against the target state file. Must
#                   be the first positional argument.
#   --session-id    Required. The caller's session_id, used to attribute mutex ownership.
#   --state-file    Optional. Path to the target state file, default
#                   "$PROJECT_ROOT/specs/state.json" (every pre-existing caller keeps working
#                   unchanged since none passes this flag). A relative value is resolved against
#                   the caller's own working directory, exactly as passing that same relative
#                   path directly to `jq`/`mv` would be -- this script never `cd`s elsewhere
#                   first. Used for `specs/archive/state.json` and vault-root `state.json`
#                   targets.
#   --init          Optional, boolean. Constructs a fresh target from null input
#                   (`jq -n "$JQ_FILTER"`) instead of transforming an existing file, for
#                   fresh-create sites (e.g. an archive reinit) that have nothing to read yet.
#                   REQUIRES an explicit `--state-file` naming a non-default target -- refused
#                   (exit 1) against the default live path, since a filter typo there must never
#                   be able to destroy live task state. Overwrites an existing target, but never
#                   silently: emits a named stderr note first. See "`--state-file` and `--init`"
#                   below.
#   --arg NAME VAL      Optional, repeatable. Forwarded to jq as `--arg NAME VAL`.
#   --argjson NAME VAL  Optional, repeatable. Forwarded to jq as `--argjson NAME VAL`.
#   --regen-todo    Optional. When passed, `generate-todo.sh` runs AFTER the mutex is released (in
#                   owned-here mode) so regeneration's wall time is never charged against the
#                   specs/.scope-lock critical section; in guest mode (SCOPE_MUTEX_HELD=1
#                   inherited) it still runs inside the outer caller's own bracket, unchanged. This
#                   means TODO.md itself is last-writer-wins under concurrent --regen-todo calls --
#                   an accepted trade-off, since it is a generated view and its own write is already
#                   atomic (tempfile + mv). A regen failure is a loud warning, not a hard failure --
#                   the state.json write already succeeded, matching update-task-status.sh's
#                   existing posture. REFUSED (exit 1) when combined with a non-default
#                   `--state-file`, or with `--init` -- see "`--state-file` and `--init`" below.
#   --dry-run       Optional. Serializes nothing because it writes nothing: no mutex acquire, no
#                   staging, no transform. Matches update-task-status.sh's existing dry-run
#                   posture. The filter and bindings are still validated for syntax, against
#                   the target's `--init`/existing-file transform shape.
#
# Exit codes:
#   0 - success (write applied, or --dry-run preview)
#   1 - usage error (missing filter, missing --session-id, malformed --arg/--argjson, or one of
#       the two `--state-file`/`--init` usage refusals below). The target state file is untouched.
#   2 - mutex acquire failed: FAIL CLOSED. An ABORT-prefixed message on stderr names the current
#       holder. The target state file is untouched.
#   3 - jq transform failed. The target state file is left untouched.
#   4 - jq empty validation failed on the transformed output (invalid JSON). The target state file
#       is left untouched.
#
# `--state-file` and `--init`
# ---------------------------
# Single mutex, not per-file (binding decision, not an oversight): `state-write.sh` continues to
# call `task-lock.sh scope-acquire`/`scope-release` with no file-derived lock name -- only the
# internal STATE_FILE variable is parameterized. A per-file mutex scheme is a real ABBA-deadlock
# surface: `commands/task.md`'s recover flow does an archive removal immediately followed by a
# live-state insert in the same logical operation, and its abandon flow does the mirror image
# (live-state extract, archive add, live-state remove). Two concurrent sessions doing opposite
# operations under per-file locks could acquire in opposite order and deadlock. A single lock name
# for every `--state-file` target makes this impossible by construction -- each acquire/release
# pair is sequential and never nested, regardless of which file it targets. The cost (archive/vault
# writers serializing against live-state writers) is negligible: these are rare, human/agent-paced
# operations that already serialize in practice. See context/patterns/task-lock.md's State-Write
# Convention section for the fuller rationale and the recover/abandon interleaved-block example.
#
# `--init` mode: skips the "target must already exist" precondition and runs `jq -n
# "${JQ_ARGS[@]}" "$JQ_FILTER"` (null input) instead of transforming an existing file --
# `--arg`/`--argjson` passthrough is unchanged. It overwrites an existing target, but never
# silently: a named stderr note ("Note: --init is replacing an existing <path>") is emitted first
# so an accidental clobber is visible in the transcript. `--init` REFUSES to run (exit 1) against
# the default live path -- either with no `--state-file` at all, or with a `--state-file` that
# normalizes (via `realpath -m`, since an `--init` target may not exist yet) to the same path as
# the default -- as a cheap, loud guard against a filter typo destroying live task state. `--init`
# is for archive and vault targets only.
#
# `--regen-todo` refusal: `generate-todo.sh` regenerates `specs/TODO.md` from
# `specs/state.json` unconditionally. Running it after an archive or vault write would render a
# view of a file that was not the one just written, so `--regen-todo` together with a
# `--state-file` that does not `realpath -m`-normalize to the default path is a hard usage error
# (exit 1), naming both paths. `--init` combined with `--regen-todo` is likewise a hard usage
# error -- unreachable given the default-path refusal above, but asserted explicitly so the
# combination can never become reachable through a later edit alone.
#
# Mutex posture: fail-closed, not fail-open. Honors SCOPE_MUTEX_HELD=1 as guest mode exactly as
# update-task-status.sh's acquire_state_mutex does today -- when an outer holder (e.g.
# orchestrator-postflight.sh) already owns the specs/.scope-lock mutex, this script skips its own
# acquire/release entirely and runs as a guest inside the outer critical section, so nested calls
# from within an outer bracket never self-deadlock. When no outer holder exists and acquisition
# times out, this is a hard failure (ABORT, exit 2) -- the accepted trade-off replacing the old
# fail-open-on-timeout posture. See context/patterns/task-lock.md for the full mutex contract.
#
# Staging: a private `mktemp` file under specs/tmp/ (directory created if absent), never a fixed
# shared path, and never per-target -- every `--state-file` value stages through the same
# project-local `specs/tmp/` directory, kept private and un-parameterized. The EXIT trap is
# scoped to THIS process's own mktemp path plus mutex release, so one process's exit can never
# delete another's in-flight staging file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"
TMP_DIR="$PROJECT_ROOT/specs/tmp"
# Created early (not only at staging time below) so spill files written during argument parsing
# -- which can happen before the --dry-run branch, before any mutex is acquired -- always have
# somewhere to land.
mkdir -p "$TMP_DIR"

# Defense-in-depth staleness widening: an explicit stale_sec passed to `scope-acquire`, mirroring
# orchestrator-postflight.sh's own widened-bracket posture, so a future slow operation added
# inside this now-regeneration-free critical section has margin before a live holder's mutex is
# reclaimed as stale. This widens ONLY the staleness reclaim WINDOW -- it has no effect on
# SCOPE_MUTEX_ACQUIRE_BUDGET_MS (task-lock.sh's separate, non-overridable waiter-timeout
# constant), so it is not a fix for waiter-timeout ABORTs on its own.
STATE_WRITE_SCOPE_STALE_SEC=30

# --- Argument parsing ---
JQ_FILTER=""
SESSION_ID=""
REGEN_TODO=false
DRY_RUN=false
INIT_MODE=false
STATE_FILE_EXPLICIT=false
JQ_ARGS=()

# --- Oversized --argjson transparent spill (D1/D2: report Shape 2, threshold below MAX_ARG_STRLEN) ---
# Any --argjson value at or under SPILL_THRESHOLD bytes is forwarded to jq exactly as before, byte
# for byte. A value over the threshold is written to a private mktemp file and bound via
# `jq --slurpfile` instead, with the caller's own $NAME reference resolved unchanged by an
# EFFECTIVE_FILTER prefix built below -- no existing or future --argjson call site has to change.
SPILL_THRESHOLD=100000
SPILL_FILES=()          # mktemp paths this process created; removed by cleanup() below. A
                         # caller-supplied --argjson-file PATH must NEVER enter this array -- see
                         # SPILL_SEQ below for why that matters.
SPILL_PRIVATE_NAMES=()  # jq --slurpfile binding names, e.g. __spill_0
SPILL_PUBLIC_NAMES=()   # the caller's original NAME for each spilled binding, e.g. NAME
SPILL_SOURCES=()        # human-readable origin of each spilled binding (parallel to
                         # SPILL_PUBLIC_NAMES/SPILL_PRIVATE_NAMES), used only for the
                         # duplicate-NAME error message below
# Explicit shared counter for private-name allocation, advanced by BOTH spill branches on every
# spill regardless of kind. Deliberately NOT derived from ${#SPILL_FILES[@]} (the historical bug:
# the --argjson-file branch never mktemps anything, so it never appended to SPILL_FILES, and its
# private_name="__spill_${#SPILL_FILES[@]}" computation therefore stayed on __spill_0 forever --
# every --argjson-file binding collided, and jq's duplicate---slurpfile first-wins semantics
# silently substituted the first spilled value for every later one). SPILL_SEQ is a separate
# scalar so the two concerns -- "how many private names have been allocated" vs. "which mktemp
# paths this process owns and must rm" -- can never be conflated again.
SPILL_SEQ=0

# check_spill_name_unique NAME SOURCE_DESC
# Hard-fails (exit 1) if NAME was already spilled earlier in THIS invocation, naming the NAME and
# both conflicting sources -- called by BOTH spill branches, before allocation, so a duplicate
# spilled public NAME can never reach EFFECTIVE_FILTER's `as $NAME` prefix chain as a silent
# last-write-wins. `set -u`-safe against an empty SPILL_PUBLIC_NAMES (checks length before
# expanding the array), matching this script's existing SPILL_FILES-length-check idiom.
check_spill_name_unique() {
  local candidate="$1" source_desc="$2" idx
  if [ "${#SPILL_PUBLIC_NAMES[@]}" -gt 0 ]; then
    for idx in "${!SPILL_PUBLIC_NAMES[@]}"; do
      if [ "${SPILL_PUBLIC_NAMES[$idx]}" = "$candidate" ]; then
        echo "Error: duplicate spilled binding NAME '$candidate' -- already spilled from ${SPILL_SOURCES[$idx]}, and now again from $source_desc. A NAME may be spilled (via an oversized --argjson value or --argjson-file) at most once per invocation." >&2
        exit 1
      fi
    done
  fi
}

usage() {
  echo "Usage: $0 <jq-filter> --session-id SID [--state-file PATH] [--init] [--arg NAME VALUE]... [--argjson NAME VALUE]... [--argjson-file NAME PATH]... [--regen-todo] [--dry-run]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --session-id)
      SESSION_ID="${2:-}"
      shift 2
      ;;
    --state-file)
      if [ "$#" -lt 2 ]; then
        echo "Error: --state-file requires a PATH argument" >&2
        usage
        exit 1
      fi
      STATE_FILE="$2"
      STATE_FILE_EXPLICIT=true
      shift 2
      ;;
    --init)
      INIT_MODE=true
      shift
      ;;
    --arg)
      if [ "$#" -lt 3 ]; then
        echo "Error: --arg requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      JQ_ARGS+=(--arg "$2" "$3")
      shift 3
      ;;
    --argjson)
      if [ "$#" -lt 3 ]; then
        echo "Error: --argjson requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      if [ "${#3}" -gt "$SPILL_THRESHOLD" ]; then
        check_spill_name_unique "$2" "an oversized --argjson value"
        spill_file=$(mktemp "$TMP_DIR/state-write-spill.XXXXXX") || {
          echo "Error: failed to create private spill file under $TMP_DIR" >&2
          exit 1
        }
        printf '%s' "$3" > "$spill_file"
        private_name="__spill_${SPILL_SEQ}"
        SPILL_SEQ=$((SPILL_SEQ + 1))
        JQ_ARGS+=(--slurpfile "$private_name" "$spill_file")
        SPILL_FILES+=("$spill_file")
        SPILL_PRIVATE_NAMES+=("$private_name")
        SPILL_PUBLIC_NAMES+=("$2")
        SPILL_SOURCES+=("an oversized --argjson value")
      else
        JQ_ARGS+=(--argjson "$2" "$3")
      fi
      shift 3
      ;;
    --argjson-file)
      if [ "$#" -lt 3 ]; then
        echo "Error: --argjson-file requires NAME and PATH" >&2
        usage
        exit 1
      fi
      if [ ! -r "$3" ]; then
        echo "Error: --argjson-file PATH '$3' does not exist or is not readable" >&2
        usage
        exit 1
      fi
      check_spill_name_unique "$2" "--argjson-file path '$3'"
      # NOTE: the caller-supplied PATH ("$3") is intentionally NEVER appended to SPILL_FILES --
      # this branch mktemps nothing, the caller owns the file, and cleanup()'s
      # `rm -f "${SPILL_FILES[@]}"` must never delete a caller's own file.
      private_name="__spill_${SPILL_SEQ}"
      SPILL_SEQ=$((SPILL_SEQ + 1))
      JQ_ARGS+=(--slurpfile "$private_name" "$3")
      SPILL_PRIVATE_NAMES+=("$private_name")
      SPILL_PUBLIC_NAMES+=("$2")
      SPILL_SOURCES+=("--argjson-file path '$3'")
      shift 3
      ;;
    --regen-todo)
      REGEN_TODO=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -*)
      echo "Error: unknown flag '$1'" >&2
      usage
      exit 1
      ;;
    *)
      if [ -n "$JQ_FILTER" ]; then
        echo "Error: unexpected extra positional argument '$1' (jq filter already given)" >&2
        usage
        exit 1
      fi
      JQ_FILTER="$1"
      shift
      ;;
  esac
done

if [ -z "$JQ_FILTER" ]; then
  echo "Error: missing required jq filter argument" >&2
  usage
  exit 1
fi

if [ -z "$SESSION_ID" ]; then
  echo "Error: missing required --session-id" >&2
  usage
  exit 1
fi

# --- EFFECTIVE_FILTER: prefix the caller's filter with an `as` binding for every spilled
# --argjson/--argjson-file, so the caller's own $NAME reference resolves exactly as a plain
# --argjson would have. `--slurpfile` always binds an array of the file's JSON values, hence the
# `[0]` dereference here. Unaffected (byte-identical to JQ_FILTER) when nothing was spilled. ---
EFFECTIVE_FILTER="$JQ_FILTER"
if [ "${#SPILL_PRIVATE_NAMES[@]}" -gt 0 ]; then
  spill_prefix=""
  for spill_idx in "${!SPILL_PRIVATE_NAMES[@]}"; do
    spill_prefix="${spill_prefix}(\$${SPILL_PRIVATE_NAMES[$spill_idx]}[0]) as \$${SPILL_PUBLIC_NAMES[$spill_idx]} | "
  done
  EFFECTIVE_FILTER="${spill_prefix}${JQ_FILTER}"
fi

# --- Mutex/cleanup scaffolding: declared and trapped here, before the --dry-run branch below, so
# a --dry-run exit still cleans up any spill files written during argument parsing above. Only the
# declarations, function bodies, and trap installation move this early -- the actual acquire_mutex
# call and staging mktemp stay gated behind the --dry-run check further down, unchanged. ---
MUTEX_TOKEN=""
MUTEX_OWNED_HERE=false
STAGE_FILE=""

acquire_mutex() {
  if [ -n "${SCOPE_MUTEX_HELD:-}" ]; then
    echo "Note: an outer holder already owns the specs/.scope-lock mutex (SCOPE_MUTEX_HELD=1 inherited); running as guest, no nested acquire." >&2
    return 0
  fi
  local token
  if ! token=$("$SCRIPT_DIR/task-lock.sh" scope-acquire "$SESSION_ID" "$STATE_WRITE_SCOPE_STALE_SEC"); then
    echo "ABORT: timed out waiting for specs/.scope-lock mutex (session=$SESSION_ID); $STATE_FILE was NOT modified." >&2
    return 1
  fi
  MUTEX_TOKEN="$token"
  MUTEX_OWNED_HERE=true
  export SCOPE_MUTEX_HELD=1
  return 0
}

release_mutex() {
  if [ "$MUTEX_OWNED_HERE" = true ]; then
    "$SCRIPT_DIR/task-lock.sh" scope-release "$MUTEX_TOKEN" >&2 || true
    MUTEX_OWNED_HERE=false
    unset SCOPE_MUTEX_HELD
  fi
}

# EXIT trap scoped to THIS process's own staging file, spill files, and mutex release. Idempotent:
# safe to fire even if release_mutex/staging cleanup already ran on an earlier explicit path. A
# --dry-run exit reaches this trap too (installed above the --dry-run branch), so spill files
# created during argument parsing are never leaked even though dry-run never acquires the mutex or
# stages a write.
cleanup() {
  [ -n "$STAGE_FILE" ] && rm -f "$STAGE_FILE" 2>/dev/null || true
  if [ "${#SPILL_FILES[@]}" -gt 0 ]; then
    rm -f "${SPILL_FILES[@]}" 2>/dev/null || true
  fi
  release_mutex
}
trap cleanup EXIT

# --- D3/D4: normalized-path comparison and the two hard usage refusals ---
# `realpath -m` does not require the path to exist -- required here since an `--init` target may
# not exist yet. Both sides are normalized before comparison so `./specs/state.json`,
# `specs/state.json`, and an absolute "$PROJECT_ROOT/specs/state.json" all compare equal to the
# default; a raw string compare would let `./specs/state.json` slip past these refusals.
DEFAULT_STATE_FILE_NORMALIZED="$(realpath -m "$PROJECT_ROOT/specs/state.json")"
STATE_FILE_NORMALIZED="$(realpath -m "$STATE_FILE")"
IS_DEFAULT_TARGET=false
if [ "$STATE_FILE_NORMALIZED" = "$DEFAULT_STATE_FILE_NORMALIZED" ]; then
  IS_DEFAULT_TARGET=true
fi

if [ "$INIT_MODE" = true ] && [ "$IS_DEFAULT_TARGET" = true ]; then
  if [ "$STATE_FILE_EXPLICIT" = true ]; then
    echo "Error: --init refuses to target the default live state file ($STATE_FILE_NORMALIZED); --init is for archive/vault targets only. Pass an explicit --state-file naming a non-default target." >&2
  else
    echo "Error: --init requires an explicit --state-file naming a non-default target; refusing to run against the default live state file ($DEFAULT_STATE_FILE_NORMALIZED)." >&2
  fi
  usage
  exit 1
fi

if [ "$REGEN_TODO" = true ] && [ "$INIT_MODE" = true ]; then
  echo "Error: --regen-todo cannot be combined with --init (an --init target is never the default live state file that --regen-todo reads from)." >&2
  usage
  exit 1
fi

if [ "$REGEN_TODO" = true ] && [ "$IS_DEFAULT_TARGET" = false ]; then
  echo "Error: --regen-todo cannot be combined with a non-default --state-file ($STATE_FILE_NORMALIZED != $DEFAULT_STATE_FILE_NORMALIZED); generate-todo.sh always regenerates specs/TODO.md from the default live state.json, which would not reflect this write. Refusing rather than regenerating from the wrong source." >&2
  usage
  exit 1
fi

# --- Existence precondition (skipped for --init) / overwrite note ---
if [ "$INIT_MODE" = true ]; then
  if [ -f "$STATE_FILE" ]; then
    echo "Note: --init is replacing an existing $STATE_FILE" >&2
  fi
else
  if [ ! -f "$STATE_FILE" ]; then
    echo "Error: state file not found at $STATE_FILE" >&2
    exit 1
  fi
fi

# --- Dry run: validate filter syntax only, write nothing, acquire nothing ---
if [ "$DRY_RUN" = true ]; then
  # `if VAR=$(cmd); then ... else dryrun_status=$?; fi` rather than a bare `VAR=$(cmd)` followed
  # by `dryrun_status=$?`: under `set -e`, a bare failing assignment would abort the script on
  # this line, before the status could ever be captured or the custom error message printed.
  # Wrapping the assignment itself in the `if` test is `-e`-exempt and preserves both the
  # captured non-zero status and this script's documented exit-code contract.
  dryrun_status=0
  if [ "$INIT_MODE" = true ]; then
    dryrun_err=$(jq -n "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" 2>&1 > /dev/null) || dryrun_status=$?
  else
    dryrun_err=$(jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE" 2>&1 > /dev/null) || dryrun_status=$?
  fi
  if [ "$dryrun_status" -ne 0 ]; then
    echo "Error: [dry-run] jq filter failed syntax/apply check:" >&2
    [ -n "$dryrun_err" ] && echo "$dryrun_err" >&2
    exit 3
  fi
  echo "[dry-run] filter applies cleanly; no write performed, no mutex acquired."
  exit 0
fi

# --- Mutex acquire (fail-closed; guest mode honored) ---
# Declarations, function bodies, and trap installation for acquire_mutex/release_mutex/cleanup
# live earlier (before the --dry-run branch above) so a --dry-run exit still cleans up spill
# files. Only the actual acquire call stays gated here, after --dry-run has already returned.
if ! acquire_mutex; then
  exit 2
fi

# --- Staging: private mktemp under specs/tmp/, never a fixed shared path, never per-target ---
mkdir -p "$TMP_DIR"
STAGE_FILE=$(mktemp "$TMP_DIR/state-write.XXXXXX") || {
  echo "Error: failed to create private staging file under $TMP_DIR" >&2
  exit 3
}

# --- Apply the caller's jq filter with forwarded bindings ---
# Same `|| transform_status=$?` guard as the dry-run branch above: a bare `VAR=$(cmd)` followed
# by a separate `transform_status=$?` line is `-e`-hostile (the assignment's own failure would
# abort the script before the status line or the custom error message ever ran).
transform_status=0
if [ "$INIT_MODE" = true ]; then
  transform_err=$(jq -n "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" 2>&1 > "$STAGE_FILE") || transform_status=$?
else
  transform_err=$(jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE" 2>&1 > "$STAGE_FILE") || transform_status=$?
fi
if [ "$transform_status" -ne 0 ]; then
  echo "Error: jq transform failed; $STATE_FILE left untouched." >&2
  [ -n "$transform_err" ] && echo "$transform_err" >&2
  exit 3
fi

# --- Validate before mv ---
if ! jq empty "$STAGE_FILE" 2>/dev/null; then
  echo "Error: jq produced invalid JSON; $STATE_FILE left untouched." >&2
  exit 4
fi

# --- Atomic replace ---
mv "$STAGE_FILE" "$STATE_FILE"
STAGE_FILE=""

# Release the mutex BEFORE regeneration, not after. generate-todo.sh's wall time can exceed both
# SCOPE_MUTEX_ACQUIRE_BUDGET_MS (the waiter timeout) and half of SCOPE_MUTEX_STALE_SEC (the
# staleness reclaim window) against a large state.json, which risks a live holder's mutex being
# reclaimed as stale out from under it. The state.json write is already durable at this point
# (the `mv` above already landed), so releasing early only changes when TODO.md regeneration is
# allowed to run, not the correctness of the state.json write itself. release_mutex() is a no-op
# in guest mode (MUTEX_OWNED_HERE stays false there), so this call has no effect when running
# nested under an outer holder's bracket -- see acquire_mutex()'s guest-mode branch above.
release_mutex

# --- Optional TODO.md regen (outside the critical section in owned-here mode; still inside the
# outer caller's bracket in guest mode, since release_mutex() above was a no-op there) ---
# Reachable only against the default target -- the D4 refusal above exits before this point for
# any non-default --state-file.
if [ "$REGEN_TODO" = true ]; then
  "$SCRIPT_DIR/generate-todo.sh" || {
    echo "Warning: generate-todo.sh failed (state.json was updated successfully)" >&2
  }
fi

exit 0
