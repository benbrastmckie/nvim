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
#                  [--arg NAME VALUE]... [--argjson NAME VALUE]... [--allocate-into NAME]
#                  [--audit-verdict FILE] [--audit-override REASON]
#                  [--regen-todo] [--dry-run]
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
#   --allocate-into NAME  Optional. Allocates the next task/project number under the SAME mutex
#                   that guards the write: binds `$NAME` to a MEMBERSHIP-based derived number, not
#                   to the live target's `next_project_number` -- the smallest number absent from
#                   the in-use set (unioning `active_projects` with the sibling
#                   `archive/state.json`'s `archived_projects`/`abandoned_projects`/
#                   `completed_projects`) that is strictly greater than the maximum ACTIVE
#                   `project_number`, identical to the definition `scripts/validate-state.sh`'s
#                   Check 12 consumes; both sites source the single shared
#                   `lib/project-number-inuse.sh` rather than each computing their own copy, so
#                   the two can never drift out of sync the way two independently written
#                   expressions could. `next_project_number` itself is a regenerable CACHE, not
#                   the allocation authority: it is still validated fail-closed before the derived
#                   number is bound (absent, non-numeric, or itself already in use each refuse via
#                   jq `error()`, surfacing as exit 3 with no write -- naming the number and the
#                   array it is in use in for the in-use case), and it is REWRITTEN, after the
#                   transform and still inside the mutex, to the freshly-derived next free number
#                   computed against the staged result. Before that regeneration, a recording
#                   assertion refuses (exit 3, no write) a filter that consumed `$NAME` without
#                   recording it anywhere the staged result's own in-use set can see -- the direct
#                   successor to a monotonic counter-advance assertion's purpose, now expressed as
#                   membership rather than as an arithmetic advance, since the counter it used to
#                   compare against is no longer the authority. Applies the identical recording
#                   assertion on the `--dry-run` preview path (which has no cache to regenerate,
#                   since it performs no atomic replace). NAME must be a valid jq identifier, must
#                   not use the reserved `__alloc_` prefix, and must not collide with any NAME
#                   already bound via `--arg`/`--argjson`/`--argjson-file` (checked regardless of
#                   flag order). REFUSED (exit 1) together with `--init` (null input has no
#                   counter to read). `specs/vault/**` is deliberately excluded from the bound --
#                   see the allocation prefix's own comment, below, for the recycling rationale.
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
#   --audit-verdict FILE  Optional. A JSON document (array, or NDJSON -- both parsed via
#                   `jq -s`) of backlog-reconciliation verdict objects as emitted by
#                   `scripts/audit-task-proposals.sh` (see context/patterns/
#                   backlog-reconciliation.md for the full vocabulary this references). THE
#                   AUDIT-EVIDENCE GATE (below) fires only when this write's transform introduces
#                   a genuinely NEW `active_projects` `project_number` -- every status update,
#                   artifact link, `file_scope` edit, and non-`active_projects` write (archive,
#                   vault, `--init`) is byte-for-byte unaffected, gate or no gate. When the gate
#                   fires, it requires, for EVERY newly-appearing entry, that this FILE contain at
#                   least one verdict object whose `.proposal.id` equals that entry's
#                   `project_name` -- the caller's own contract: the audit MUST be run with
#                   `id` set to the slug/`project_name` the write is about to use, since the real
#                   `project_number` is rarely known before an `--allocate-into` write actually
#                   allocates it. On a match, the matching verdict object is recorded verbatim
#                   into the new entry's own `audit_verdict` field -- durable, auditable evidence
#                   after the fact, not merely a check made in flight and then discarded. No match
#                   for any new entry refuses the WHOLE write with exit 5 (every new entry, not
#                   just the uncovered one(s), naming each uncovered entry on stderr) rather than
#                   partially applying a batch.
#   --audit-override REASON  Optional. An explicit, human-authored override that satisfies the
#                   audit-evidence gate without a matching `--audit-verdict` entry, for every new
#                   entry this write introduces. REASON is recorded verbatim into each new
#                   entry's own `audit_override` field (and that entry carries no `audit_verdict`
#                   field in that case) -- this is a deliberate, recorded escape hatch (see this
#                   plan's Rollback/Contingency section), never a silent bypass: the reason is
#                   permanently visible on the entry itself. `--audit-verdict` and
#                   `--audit-override` may both be given; override wins for any entry the verdict
#                   file does not cover, verdict wins (and is recorded) for any entry it does.
#
# Exit codes:
#   0 - success (write applied, or --dry-run preview)
#   1 - usage error (missing filter, missing --session-id, malformed --arg/--argjson, or one of
#       the two `--state-file`/`--init` usage refusals below). The target state file is untouched.
#   2 - mutex acquire failed: FAIL CLOSED. An ABORT-prefixed message on stderr names the current
#       holder. The target state file is untouched.
#   3 - jq transform failed, OR (with --allocate-into) the existing counter refused as itself
#       absent/non-numeric/in-use, OR (with --allocate-into) the staged result failed the
#       recording assertion, OR (with --allocate-into) cache regeneration itself failed. The
#       target state file is left untouched in every case.
#   4 - jq empty validation failed on the transformed output (invalid JSON). The target state file
#       is left untouched.
#   5 - AUDIT-EVIDENCE GATE refusal: this write introduces one or more new `active_projects`
#       entries with no covering `--audit-verdict` entry and no `--audit-override`. The target
#       state file is left untouched; stderr names every uncovered `project_number`/
#       `project_name` and the remedy (re-run the audit with a matching `id`, pass
#       `--audit-verdict`, or pass `--audit-override REASON`).
#
# `--allocate-into NAME` worked example: allocate one number in a single mutex-scoped write (the
# caller's own filter is responsible for RECORDING the allocated value somewhere the in-use set
# can see -- here, by adding it to `active_projects` -- the recording assertion refuses the write
# otherwise; the caller does NOT need to touch `next_project_number` itself, since it is a
# regenerable cache this script rewrites after the transform):
#   state-write.sh \
#     '.active_projects += [{project_number: $new_num, project_name: $ARGS.named.name, status: "not_started"}]' \
#     --allocate-into new_num --arg name "my-new-task" --session-id "$SESSION_ID"
#
# `--audit-verdict` worked example (same call, now carrying audit evidence -- note the verdict
# file's proposal.id must equal "my-new-task", the project_name the filter above writes):
#   bash audit-task-proposals.sh --title "..." --description "..." > /tmp/verdict.json
#   # (caller sets .proposal.id = "my-new-task" itself, e.g. by passing --title such that the
#   #  slug it derives matches, or by post-processing the verdict JSON before passing it here)
#   state-write.sh \
#     '.active_projects += [{project_number: $new_num, project_name: $ARGS.named.name, status: "not_started"}]' \
#     --allocate-into new_num --arg name "my-new-task" --audit-verdict /tmp/verdict.json \
#     --session-id "$SESSION_ID"
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
# PNUM_INUSE_JQ_DEFS: the shared "a project_number is in use" / next-free-number definitions the
# --allocate-into allocation prefix below splices into its own jq program -- see that library's
# own header for the full contract (it is safe to `source` plainly under this script's
# `set -euo pipefail` without an `if ! ...; then` guard).
source "${SCRIPT_DIR}/lib/project-number-inuse.sh"
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

# --allocate-into NAME (D: allocation under the mutex -- see the dedicated section below, after
# argument parsing, for the full contract). ALL_BOUND_NAMES tracks every NAME bound via
# --arg/--argjson/--argjson-file (not only spilled ones) regardless of parse order, so a NAME
# collision with --allocate-into is caught whichever flag comes first on the command line.
ALLOCATE_INTO_NAME=""
ALLOCATE_INTO_SET=false
ALL_BOUND_NAMES=()

# --audit-verdict FILE / --audit-override REASON (audit-evidence gate -- see the usage header
# above and the dedicated section below, after the transform, for the full contract).
AUDIT_VERDICT_FILE=""
AUDIT_OVERRIDE_REASON=""
# AUDIT_VERDICT_NORMALIZED_FILE: private mktemp path holding the normalized (array-shaped)
# verdict JSON -- always bound into jq via --slurpfile (never --argjson) at every one of the
# three audit-evidence-gate call sites below, so an arbitrarily large --audit-verdict FILE is
# always read from disk rather than passed as a process argument. A large payload previously hit
# the argv-length limit when the normalized JSON was round-tripped through a bash variable and
# re-passed via `--argjson verdicts "$AUDIT_VERDICT_JSON"`. Populated even when --audit-verdict is
# not given (holding the literal `[]`), so every call site can use the identical `--slurpfile
# verdicts ... | $verdicts[0]` binding unconditionally -- no separate small-payload code path.

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
  echo "Usage: $0 <jq-filter> --session-id SID [--state-file PATH] [--init] [--arg NAME VALUE]... [--argjson NAME VALUE]... [--argjson-file NAME PATH]... [--allocate-into NAME] [--audit-verdict FILE] [--audit-override REASON] [--regen-todo] [--dry-run]" >&2
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
    --allocate-into)
      if [ "$#" -lt 2 ]; then
        echo "Error: --allocate-into requires a NAME argument" >&2
        usage
        exit 1
      fi
      ALLOCATE_INTO_NAME="$2"
      ALLOCATE_INTO_SET=true
      shift 2
      ;;
    --arg)
      if [ "$#" -lt 3 ]; then
        echo "Error: --arg requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      JQ_ARGS+=(--arg "$2" "$3")
      ALL_BOUND_NAMES+=("$2")
      shift 3
      ;;
    --argjson)
      if [ "$#" -lt 3 ]; then
        echo "Error: --argjson requires NAME and VALUE" >&2
        usage
        exit 1
      fi
      ALL_BOUND_NAMES+=("$2")
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
      ALL_BOUND_NAMES+=("$2")
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
    --audit-verdict)
      if [ "$#" -lt 2 ]; then
        echo "Error: --audit-verdict requires a FILE argument" >&2
        usage
        exit 1
      fi
      AUDIT_VERDICT_FILE="$2"
      shift 2
      ;;
    --audit-override)
      if [ "$#" -lt 2 ]; then
        echo "Error: --audit-override requires a REASON argument" >&2
        usage
        exit 1
      fi
      AUDIT_OVERRIDE_REASON="$2"
      shift 2
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

# --- --allocate-into NAME: usage validation ---
# NAME must be a valid jq identifier, must not use the reserved __alloc_ namespace (internal to
# this script's own allocation prefix, see the EFFECTIVE_FILTER extension below), and must not
# collide with any NAME already bound via --arg/--argjson/--argjson-file (ALL_BOUND_NAMES,
# populated regardless of parse order above) -- following the check_spill_name_unique precedent.
# --allocate-into + --init is refused: --init runs against null input (`jq -n`), where
# next_project_number could only ever be null.
if [ "$ALLOCATE_INTO_SET" = true ]; then
  if ! [[ "$ALLOCATE_INTO_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Error: --allocate-into NAME '$ALLOCATE_INTO_NAME' is not a valid jq identifier (must match ^[A-Za-z_][A-Za-z0-9_]*\$)" >&2
    usage
    exit 1
  fi
  case "$ALLOCATE_INTO_NAME" in
    __alloc_*)
      echo "Error: --allocate-into NAME '$ALLOCATE_INTO_NAME' uses the reserved __alloc_ namespace (internal to this script's own allocation binding); choose a different NAME." >&2
      usage
      exit 1
      ;;
  esac
  if [ "${#ALL_BOUND_NAMES[@]}" -gt 0 ]; then
    for _alloc_bn in "${ALL_BOUND_NAMES[@]}"; do
      if [ "$_alloc_bn" = "$ALLOCATE_INTO_NAME" ]; then
        echo "Error: --allocate-into NAME '$ALLOCATE_INTO_NAME' collides with a NAME already bound via --arg/--argjson/--argjson-file" >&2
        usage
        exit 1
      fi
    done
  fi
  if [ "$INIT_MODE" = true ]; then
    echo "Error: --allocate-into cannot be combined with --init (an --init target runs against null input via 'jq -n', where next_project_number could only ever be null)." >&2
    usage
    exit 1
  fi
  # Bind the sibling archive for the allocation prefix below. jq resolves --slurpfile when it
  # runs, which is inside the mutex (the transform/dry-run jq calls below run after acquire_mutex
  # in the non-dry-run path; dry-run never writes, so this read is advisory there) -- state-write.sh
  # is the single mutex-guarded writer for the archive as well as the live file, so this read is
  # serialized by the same lock. specs/vault/** is deliberately NOT part of this bound: a vault
  # operation (commands/todo.md Step 5.7) recycles the vacated number space by renumbering active
  # tasks down and resetting the counter, and counting vaulted numbers would make every post-vault
  # state permanently unable to allocate. Sibling expression that must stay in sync:
  # scripts/validate-state.sh's Check 12 computes this identical combined max.
  ALLOC_ARCHIVE_FILE="$(dirname "$STATE_FILE")/archive/state.json"
  if [ -f "$ALLOC_ARCHIVE_FILE" ]; then
    JQ_ARGS+=(--slurpfile __alloc_archive_raw "$ALLOC_ARCHIVE_FILE")
  else
    JQ_ARGS+=(--argjson __alloc_archive_raw '[]')
  fi
  JQ_ARGS+=(--arg __alloc_state_file "$STATE_FILE")
  JQ_ARGS+=(--arg __alloc_script "$0")
fi

# --- Audit-evidence gate: usage validation for --audit-verdict (read and parse eagerly, before
# the mutex, so a bad FILE fails fast exactly like every other usage error above) ---
# AUDIT_VERDICT_NORMALIZED_FILE is always created -- holding the literal `[]` when --audit-verdict
# is not given -- so every downstream call site can bind it via --slurpfile unconditionally. This
# keeps the normalized verdict JSON on disk end to end: it is never round-tripped through a bash
# variable and re-passed as a jq --argjson process argument, which is what previously hit the
# argv-length limit on a large (observed: 145KB/159KB) --audit-verdict FILE.
AUDIT_VERDICT_NORMALIZED_FILE=$(mktemp "$TMP_DIR/state-write-audit-verdict.XXXXXX") || {
  echo "Error: failed to create private audit-verdict normalization file under $TMP_DIR" >&2
  exit 1
}
SPILL_FILES+=("$AUDIT_VERDICT_NORMALIZED_FILE")
if [ -n "$AUDIT_VERDICT_FILE" ]; then
  if [ ! -r "$AUDIT_VERDICT_FILE" ]; then
    echo "Error: --audit-verdict FILE '$AUDIT_VERDICT_FILE' does not exist or is not readable" >&2
    usage
    exit 1
  fi
  # jq -s tolerates BOTH a single JSON array and NDJSON (one object per line, as
  # audit-task-proposals.sh emits) -- -s slurps every top-level value on stdin into one array
  # regardless of which shape the file uses, then flattens one level so a file that is ALREADY
  # an array of verdict objects (rather than NDJSON of them) is not double-wrapped. Output goes
  # straight to AUDIT_VERDICT_NORMALIZED_FILE on disk (never into a bash variable); only stderr is
  # captured for the failure message, matching this script's existing
  # `err=$(cmd 2>&1 > file) || status=$?` idiom used elsewhere (e.g. the dry-run branch below).
  audit_verdict_status=0
  audit_verdict_err=$(jq -c -s '[.[] | if type == "array" then .[] else . end]' "$AUDIT_VERDICT_FILE" 2>&1 > "$AUDIT_VERDICT_NORMALIZED_FILE") || audit_verdict_status=$?
  if [ "$audit_verdict_status" -ne 0 ]; then
    echo "Error: --audit-verdict FILE '$AUDIT_VERDICT_FILE' is not valid JSON/NDJSON: $audit_verdict_err" >&2
    usage
    exit 1
  fi
else
  printf '[]' > "$AUDIT_VERDICT_NORMALIZED_FILE"
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

# --- EFFECTIVE_FILTER: --allocate-into allocation prefix (appended after any spill prefix,
# immediately before the caller's filter) ---
# Membership-based, not max-based: the bound is the identical "in use" definition
# scripts/validate-state.sh's Check 12 consumes (that script's comment names this prefix as the
# sibling expression that must stay in sync, and vice versa), both sourced from the single shared
# lib/project-number-inuse.sh rather than each writing its own copy of the bound.
#
# next_project_number is NOT the allocation authority here -- it is a regenerable cache (see the
# cache-regeneration step after the caller's transform, below). The number actually issued into
# $NAME is always `pnum_next_free`: the smallest number absent from the in-use set and strictly
# greater than the maximum ACTIVE project_number -- never the smallest unused number counting from
# 1, which would recycle small numbers that predate every active task and appear throughout
# committed history.
#
# The existing counter is still validated fail-closed before the derived number is bound: absent
# or non-numeric raises `error(...)` exactly as before; a counter that is ITSELF already in use
# (pnum_location(...) != null) also raises `error(...)`, naming the number and the array it is in
# use in -- a sign the cache was left stale by something other than this script's own
# regeneration step, caught here rather than silently allocating over it. A jq `error()` makes the
# transform fail, which the existing transform_status handling below already turns into an abort
# with no write -- fail-closed by construction, no new exit-code plumbing needed for either
# refusal.
if [ "$ALLOCATE_INTO_SET" = true ]; then
  alloc_prefix="${PNUM_INUSE_JQ_DEFS}"
  alloc_prefix="${alloc_prefix}(\$__alloc_archive_raw[0] // {}) as \$__alloc_archive_doc | "
  alloc_prefix="${alloc_prefix}(if has(\"next_project_number\") then .next_project_number else error(\"--allocate-into: next_project_number is absent in \" + \$__alloc_state_file) end) as \$__alloc_ctr_raw | "
  alloc_prefix="${alloc_prefix}(if (\$__alloc_ctr_raw | type) == \"number\" then \$__alloc_ctr_raw else error(\"--allocate-into: next_project_number is not a number in \" + \$__alloc_state_file) end) as \$__alloc_ctr | "
  alloc_prefix="${alloc_prefix}(pnum_location(\$__alloc_ctr; \$__alloc_archive_doc)) as \$__alloc_ctr_loc | "
  alloc_prefix="${alloc_prefix}(pnum_next_free(\$__alloc_archive_doc)) as \$__alloc_next_free | "
  alloc_prefix="${alloc_prefix}(if \$__alloc_ctr_loc != null then error(\"--allocate-into: next_project_number (\" + (\$__alloc_ctr|tostring) + \") is already in use in \" + \$__alloc_ctr_loc + \" in \" + \$__alloc_state_file + \" -- refusing to allocate a number from a counter that already names an in-use value. Repair: \" + \$__alloc_script + \" '.next_project_number = \" + (\$__alloc_next_free|tostring) + \"' --session-id SID \" + \$__alloc_state_file) else \$__alloc_next_free end) as \$${ALLOCATE_INTO_NAME} | "
  EFFECTIVE_FILTER="${alloc_prefix}${EFFECTIVE_FILTER}"
fi

# --- --allocate-into: shared bash-level helpers for the post-transform recording assertion and
# cache regeneration (Design Decision: the counter is a regenerable cache, not the allocation
# authority -- see the allocation prefix's own comment above). Both splice $PNUM_INUSE_JQ_DEFS
# directly rather than re-deriving the in-use definitions, so a staged file's recorded/regenerated
# values can never drift from what the allocation prefix itself just computed. Defined here
# (before the --dry-run branch) so both the dry-run preview path and the main write path below
# can call them. Neither takes any action on failure -- each only reports; the caller decides
# whether to refuse. ---

# alloc_issued_number FILE -- echoes pnum_next_free computed against FILE's (pre-transform)
# active_projects plus the same sibling archive the allocation prefix reads. Deterministic given
# the same FILE/archive pair, so calling this against $STATE_FILE immediately before the
# transform below yields the exact same integer EFFECTIVE_FILTER's own allocation prefix just
# bound to $NAME inside that same transform -- there is no race, since both reads happen with no
# intervening write (the mutex excludes any other writer on the main path; dry-run never writes
# at all).
alloc_issued_number() {
  local file="$1"
  jq -r "${JQ_ARGS[@]}" \
    "${PNUM_INUSE_JQ_DEFS}(\$__alloc_archive_raw[0] // {}) as \$__alloc_archive_doc | pnum_next_free(\$__alloc_archive_doc)" \
    "$file" 2>/dev/null
}

# alloc_is_recorded FILE N -- true iff N (the number issued into $NAME) is present in FILE's own
# in-use set (unioning FILE's active_projects with the SAME sibling archive the allocation prefix
# read). This is the direct successor to the old monotonic-advance assertion's purpose: a filter
# that consumes $NAME without recording it anywhere the in-use set can see is refused, so the next
# allocation can never re-derive and re-issue the same number.
alloc_is_recorded() {
  local file="$1" n="$2"
  jq -e --argjson __alloc_n "$n" "${JQ_ARGS[@]}" \
    "${PNUM_INUSE_JQ_DEFS}(\$__alloc_archive_raw[0] // {}) as \$__alloc_archive_doc | (pnum_location(\$__alloc_n; \$__alloc_archive_doc)) != null" \
    "$file" >/dev/null 2>&1
}

# alloc_regenerate_cache FILE -- rewrites FILE's own next_project_number in place to
# pnum_next_free computed against FILE's post-transform active_projects plus the same sibling
# archive. Edits FILE via a private mktemp-then-mv so FILE is never observed half-written. Returns
# 1 (FILE left untouched) on any jq failure, surfaced by the caller exactly like the existing
# transform_status handling.
alloc_regenerate_cache() {
  local file="$1" tmp
  tmp=$(mktemp "${file}.regen.XXXXXX") || return 1
  if ! jq "${JQ_ARGS[@]}" \
    "${PNUM_INUSE_JQ_DEFS}(\$__alloc_archive_raw[0] // {}) as \$__alloc_archive_doc | .next_project_number = (pnum_next_free(\$__alloc_archive_doc))" \
    "$file" > "$tmp" 2>/dev/null; then
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$file"
}

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
  # DRYRUN_NEEDS_OUTPUT: either assertion below (--allocate-into's recording assertion, or the
  # audit-evidence gate) needs to inspect the STAGED result, not just a syntax/apply check -- so
  # whenever either could apply, capture to a private temp file instead of /dev/null. Registered
  # in SPILL_FILES so the existing cleanup() trap removes it on every exit path, including a
  # refusal exit below. No cache regeneration and no audit-evidence recording here -- dry-run has
  # no atomic replace to apply either against.
  DRYRUN_AUDIT_APPLIES=false
  if [ "$IS_DEFAULT_TARGET" = true ] && [ "$INIT_MODE" = false ]; then
    DRYRUN_AUDIT_APPLIES=true
  fi
  if [ "$ALLOCATE_INTO_SET" = true ] || [ "$DRYRUN_AUDIT_APPLIES" = true ]; then
    # alloc_issued_number's own jq call references the --allocate-into-only JQ_ARGS bindings
    # (__alloc_archive_raw et al, added only when ALLOCATE_INTO_SET=true above) -- call it ONLY
    # in that case. The audit-evidence gate below needs no allocated-number preview at all; it
    # diffs active_projects project_number SETS directly from DRYRUN_OUT.
    if [ "$ALLOCATE_INTO_SET" = true ]; then
      ALLOC_ISSUED_NUMBER=$(alloc_issued_number "$STATE_FILE")
    fi
    DRYRUN_OUT=$(mktemp "$TMP_DIR/state-write-dryrun.XXXXXX") || {
      echo "Error: failed to create private dry-run output file under $TMP_DIR" >&2
      exit 1
    }
    SPILL_FILES+=("$DRYRUN_OUT")
    if [ "$INIT_MODE" = true ]; then
      dryrun_err=$(jq -n "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" 2>&1 > "$DRYRUN_OUT") || dryrun_status=$?
    else
      dryrun_err=$(jq "${JQ_ARGS[@]}" "$EFFECTIVE_FILTER" "$STATE_FILE" 2>&1 > "$DRYRUN_OUT") || dryrun_status=$?
    fi
    if [ "$dryrun_status" -eq 0 ] && [ "$ALLOCATE_INTO_SET" = true ]; then
      # The recording assertion (Design Decision: counter is a regenerable cache, not the
      # allocation authority -- see the allocation prefix's own comment above) applies on the
      # dry-run preview path too, so a dry run reports the same refusal a real write would.
      if ! [[ "$ALLOC_ISSUED_NUMBER" =~ ^[0-9]+$ ]] || ! alloc_is_recorded "$DRYRUN_OUT" "$ALLOC_ISSUED_NUMBER"; then
        echo "Error: [dry-run] --allocate-into: the filter consumed \$$ALLOCATE_INTO_NAME ($ALLOC_ISSUED_NUMBER) without recording it anywhere the in-use set can see; $STATE_FILE was NOT modified." >&2
        exit 3
      fi
    fi
    if [ "$dryrun_status" -eq 0 ] && [ "$DRYRUN_AUDIT_APPLIES" = true ] && [ -z "$AUDIT_OVERRIDE_REASON" ]; then
      # Audit-evidence gate, dry-run polarity: identical pre/post diff and coverage check as the
      # real-write path below, applying the SAME assertion a real write would -- but against a
      # pre-transform read taken outside the mutex (dry-run never acquires it) and a staged
      # result that is never applied. An --audit-override given here short-circuits identically
      # to the real-write path (every new entry is covered unconditionally), so this block is
      # skipped entirely in that case -- matching the "override wins" contract in the usage
      # header.
      AUDIT_PRE_NUMBERS_DRY="$(jq -c '[.active_projects[]?.project_number] | map(select(type == "number"))' "$STATE_FILE")"
      AUDIT_POST_NUMBERS_DRY="$(jq -c '[.active_projects[]?.project_number] | map(select(type == "number"))' "$DRYRUN_OUT")"
      AUDIT_NEW_NUMBERS_DRY="$(jq -c -n --argjson pre "$AUDIT_PRE_NUMBERS_DRY" --argjson post "$AUDIT_POST_NUMBERS_DRY" '$post - $pre')"
      AUDIT_NEW_COUNT_DRY="$(printf '%s' "$AUDIT_NEW_NUMBERS_DRY" | jq 'length')"
      if [ "$AUDIT_NEW_COUNT_DRY" -gt 0 ]; then
        AUDIT_UNCOVERED_DRY="$(jq -c -n \
          --argjson newnums "$AUDIT_NEW_NUMBERS_DRY" \
          --slurpfile stagearr "$DRYRUN_OUT" \
          --slurpfile verdicts "$AUDIT_VERDICT_NORMALIZED_FILE" \
          '
          ($stagearr[0]) as $staged |
          ([$verdicts[0][] | .proposal.id] | map(select(. != null))) as $covered_ids |
          [ $newnums[] as $n |
            (($staged.active_projects[] | select(.project_number == $n) | .project_name) // null) as $pname |
            select(($pname == null) or (($covered_ids | index($pname)) == null)) |
            {project_number: $n, project_name: $pname}
          ]
          ')"
        AUDIT_UNCOVERED_COUNT_DRY="$(printf '%s' "$AUDIT_UNCOVERED_DRY" | jq 'length')"
        if [ "$AUDIT_UNCOVERED_COUNT_DRY" -gt 0 ]; then
          echo "Error: [dry-run] audit-evidence gate (exit 5): this write would introduce $AUDIT_NEW_COUNT_DRY new active_projects entry(ies); $AUDIT_UNCOVERED_COUNT_DRY of them carry no covering --audit-verdict entry and no --audit-override." >&2
          echo "  Uncovered: $AUDIT_UNCOVERED_DRY" >&2
          exit 5
        fi
      fi
    fi
  elif [ "$INIT_MODE" = true ]; then
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

# --- --allocate-into: capture the pre-transform issued number INSIDE the mutex, for the
# recording assertion and cache regeneration below. This is the one read that makes allocation
# genuinely mutex-scoped: it happens after acquire_mutex above and before the transform/mv below,
# so no other writer can interleave between this read and the eventual atomic replace. ---
if [ "$ALLOCATE_INTO_SET" = true ]; then
  ALLOC_ISSUED_NUMBER=$(alloc_issued_number "$STATE_FILE")
fi

# --- Audit-evidence gate: capture the PRE-transform active_projects number set INSIDE the
# mutex, for the post-transform diff below. Scoped identically to --regen-todo's own
# IS_DEFAULT_TARGET/INIT_MODE gating: this is a live-task-creation concern only -- an archive or
# vault write (always a non-default --state-file) and an --init fresh-create are both completely
# unaffected, exactly as the usage header promises. ---
AUDIT_PRE_NUMBERS='[]'
if [ "$IS_DEFAULT_TARGET" = true ] && [ "$INIT_MODE" = false ]; then
  AUDIT_PRE_NUMBERS="$(jq -c '[.active_projects[]?.project_number] | map(select(type == "number"))' "$STATE_FILE")"
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

# --- --allocate-into: recording assertion plus cache regeneration (still inside the mutex, still
# before the atomic replace, so either failure leaves $STATE_FILE completely untouched) ---
# Design Decision: the counter is a regenerable cache, not the allocation authority. The
# recording assertion is the direct successor to the old monotonic-advance assertion's purpose:
# closes the Step 4c omission this allocator exists to prevent -- a caller that consumes
# $ALLOCATE_INTO_NAME but never records it anywhere the in-use set can see must never be allowed
# to land that write, or the next allocation would re-derive and re-issue the same number. Once
# recording is confirmed, the cache regeneration step rewrites the staged file's own
# next_project_number to the freshly-derived next free number (computed against the staged
# file's now-updated active_projects), so every plain `jq -r '.next_project_number'` reader keeps
# reading a number that is itself free -- never an in-use number, and never requiring a hand
# repair of the counter first.
if [ "$ALLOCATE_INTO_SET" = true ]; then
  if ! [[ "$ALLOC_ISSUED_NUMBER" =~ ^[0-9]+$ ]] || ! alloc_is_recorded "$STAGE_FILE" "$ALLOC_ISSUED_NUMBER"; then
    echo "Error: --allocate-into: the filter consumed \$$ALLOCATE_INTO_NAME ($ALLOC_ISSUED_NUMBER) without recording it anywhere the in-use set can see; $STATE_FILE was NOT modified." >&2
    exit 3
  fi
  if ! alloc_regenerate_cache "$STAGE_FILE"; then
    echo "Error: --allocate-into: failed to regenerate next_project_number in the staged result; $STATE_FILE was NOT modified." >&2
    exit 3
  fi
fi

# --- Audit-evidence gate: post-transform diff, coverage check, and durable recording (still
# inside the mutex, still before the atomic replace, so a refusal here leaves $STATE_FILE
# completely untouched -- identical posture to the --allocate-into block above). See the usage
# header's "--audit-verdict FILE" / "--audit-override REASON" entries for the full contract this
# implements; this is deliberately the SAME technique the --allocate-into recording assertion
# above already uses (diff a pre/post-transform set, refuse on an uncovered gap), applied to a
# different set (active_projects project_numbers, not a single allocated counter value). ---
if [ "$IS_DEFAULT_TARGET" = true ] && [ "$INIT_MODE" = false ]; then
  AUDIT_POST_NUMBERS="$(jq -c '[.active_projects[]?.project_number] | map(select(type == "number"))' "$STAGE_FILE")"
  AUDIT_NEW_NUMBERS="$(jq -c -n --argjson pre "$AUDIT_PRE_NUMBERS" --argjson post "$AUDIT_POST_NUMBERS" '$post - $pre')"
  AUDIT_NEW_COUNT="$(printf '%s' "$AUDIT_NEW_NUMBERS" | jq 'length')"
  if [ "$AUDIT_NEW_COUNT" -gt 0 ]; then
    if [ -n "$AUDIT_OVERRIDE_REASON" ]; then
      # Override satisfies every new entry unconditionally -- but only the entries the verdict
      # file does NOT already cover get the override reason recorded; an entry the verdict file
      # DOES cover still gets its real verdict recorded (see the "both may be given" contract in
      # the usage header), never silently replaced by the override.
      AUDIT_UNCOVERED='[]'
    else
      AUDIT_UNCOVERED="$(jq -c -n \
        --argjson newnums "$AUDIT_NEW_NUMBERS" \
        --slurpfile stagearr "$STAGE_FILE" \
        --slurpfile verdicts "$AUDIT_VERDICT_NORMALIZED_FILE" \
        '
        ($stagearr[0]) as $staged |
        ([$verdicts[0][] | .proposal.id] | map(select(. != null))) as $covered_ids |
        [ $newnums[] as $n |
          (($staged.active_projects[] | select(.project_number == $n) | .project_name) // null) as $pname |
          select(($pname == null) or (($covered_ids | index($pname)) == null)) |
          {project_number: $n, project_name: $pname}
        ]
        ')"
    fi
    AUDIT_UNCOVERED_COUNT="$(printf '%s' "$AUDIT_UNCOVERED" | jq 'length')"
    if [ "$AUDIT_UNCOVERED_COUNT" -gt 0 ]; then
      echo "Error: audit-evidence gate (exit 5): this write introduces $AUDIT_NEW_COUNT new active_projects entry(ies); $AUDIT_UNCOVERED_COUNT of them carry no covering --audit-verdict entry and no --audit-override. $STATE_FILE was NOT modified." >&2
      echo "  Uncovered: $AUDIT_UNCOVERED" >&2
      echo "  Remedy: re-run scripts/audit-task-proposals.sh with --title/--description matching each entry, set the verdict's" >&2
      echo "  proposal.id to that entry's project_name, and pass the result via --audit-verdict FILE -- or pass" >&2
      echo "  --audit-override REASON to record an explicit human override instead." >&2
      exit 5
    fi

    # Coverage confirmed (or --audit-override given) -- record durable evidence onto each new
    # entry. A verdict-matched entry gets .audit_verdict (the matching object verbatim); an
    # entry the verdict file does not cover (whether because --audit-verdict was omitted
    # entirely, or because --audit-override is what actually covers it) gets .audit_override
    # instead. Applied via a private mktemp-then-mv, matching alloc_regenerate_cache's own
    # never-half-written discipline.
    AUDIT_RECORD_TMP="$(mktemp "${STAGE_FILE}.audit.XXXXXX")" || {
      echo "Error: audit-evidence gate: failed to create a private recording temp file; $STATE_FILE was NOT modified." >&2
      exit 3
    }
    if ! jq \
      --argjson newnums "$AUDIT_NEW_NUMBERS" \
      --slurpfile verdicts "$AUDIT_VERDICT_NORMALIZED_FILE" \
      --arg override "$AUDIT_OVERRIDE_REASON" \
      '
      ([$verdicts[0][] | select(.proposal.id != null)] | map({key: .proposal.id, value: .}) | from_entries) as $by_id |
      .active_projects |= map(
        .project_number as $pn |
        if ($newnums | index($pn)) != null then
          ( (.project_name // "") as $pname | $by_id[$pname] ) as $v |
          if $v != null then (. + {audit_verdict: $v})
          else (. + {audit_override: $override})
          end
        else . end
      )
      ' "$STAGE_FILE" > "$AUDIT_RECORD_TMP" 2>/dev/null; then
      rm -f "$AUDIT_RECORD_TMP"
      echo "Error: audit-evidence gate: failed to record audit evidence into the staged result; $STATE_FILE was NOT modified." >&2
      exit 3
    fi
    mv "$AUDIT_RECORD_TMP" "$STAGE_FILE"
  fi
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
