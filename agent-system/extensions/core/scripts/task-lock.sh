#!/usr/bin/env bash
# task-lock.sh — Atomic per-task concurrency lock.
#
# Purpose: prevent two concurrent Claude Code sessions from working the SAME task
# directory at once (the 427 failure: an uncommitted in-progress task silently wiped
# by a second session). Provides acquire/heartbeat/release/check subcommands built on
# a genuinely atomic `mkdir` primitive — NOT the non-atomic `jq -n > file` pattern used
# elsewhere in this codebase for state.json writes.
#
# Canonical spec: .claude/context/patterns/task-lock.md (lockfile schema, full
# acquire/heartbeat/release/check contract, stale-threshold constant, override-and-warn
# behavior, refusal-message template). This script implements that spec; consumers
# should reference the spec doc, not restate the logic inline.
#
# Usage:
#   task-lock.sh acquire <task_number> <operation> <session_id> [command]
#   task-lock.sh acquire-retry <task_number> <operation> <session_id> [command]
#   task-lock.sh heartbeat <task_number> <session_id>
#   task-lock.sh release <task_number> <session_id>
#   task-lock.sh check <task_number>
#   task-lock.sh reap [--dry-run]
#   task-lock.sh init-marker <file_path>    (stdin = JSON content)
#   task-lock.sh scope-acquire <session_id> [stale_sec]
#   task-lock.sh scope-release <token>
#   task-lock.sh commit-acquire <session_id> [stale_sec]
#   task-lock.sh commit-release <token>
#   task-lock.sh claim-acquire <path> <task_number> <session_id> [stale_sec]
#   task-lock.sh claim-release <path> [task_number]
#   task-lock.sh session-register <session_id> <command> <task_numbers_csv> [--pid N]
#   task-lock.sh session-heartbeat <session_id>
#   task-lock.sh session-release <session_id>
#   task-lock.sh session-reap [--dry-run]
#   task-lock.sh session-list
#
# Session-Registry subcommands (session-register/session-heartbeat/session-release/session-reap/
# session-list) are a SEPARATE, ADDITIVE family from the task-number `.lock/` mechanism above:
# they record which orchestration SESSIONS (not tasks) are actually in flight, at
# specs/.sessions/{session_id}.json. session-list is this registry's reader: a read-only,
# no-mutation NDJSON enumeration (see cmd_session_list below) consumed by
# orchestrate-batch-admit.sh's session-contention pass and by this file's own cmd_acquire --
# see context/patterns/task-lock.md's Session-Registry Reader Contract section for the full
# consumer list and exclusion rules. Registry entry layout:
#
#   {
#     "session_id": "sess_1736700000_a1b2c3",
#     "pid": 261744,
#     "pid_source": "ancestor-claude",
#     "command": "/implement 944",
#     "task_numbers": [944],
#     "file_scope": ["agent-system/extensions/core/scripts/task-lock.sh"],
#     "started_at": "2026-07-04T18:07:17Z",
#     "heartbeat_at": "2026-07-04T18:12:40Z"
#   }
#
# scope-acquire/scope-release expose the specs/.scope-lock/ global mutex (defined below as
# acquire_scope_mutex/release_scope_mutex, originally introduced for cmd_acquire's cross-task
# overlap scan) as a standalone CLI primitive for callers that need to bracket a critical section
# spanning MULTIPLE process invocations (e.g. a shell script wrapping several other scripts' state
# writes) rather than a single function's lifetime. commit-acquire/commit-release expose a SIBLING
# mutex, specs/.commit-lock/, serializing the git add + git commit pair around scoped commits (see
# scripts/git-commit-scoped.sh) -- a DISTINCT directory from .scope-lock, guarded by a DISTINCT
# reentrancy flag (COMMIT_MUTEX_HELD, never SCOPE_MUTEX_HELD). Two independent critical sections
# need two independent held-flags: reusing .scope-lock for commits would either silently defeat
# serialization (a commit running inside a window where SCOPE_MUTEX_HELD is already exported would
# wrongly treat an outer holder's scope-mutex ownership as covering the unrelated commit mutex too)
# or attempt a nested acquire on a documented non-reentrant primitive. See
# .claude/context/patterns/task-lock.md for the full contract: neither mutex is reentrant
# (SCOPE_MUTEX_HELD / COMMIT_MUTEX_HELD is the sanctioned way for a callee to detect its OWN outer
# holder and skip nested acquire/release), staleness is holder-declared (the acquiring process's
# chosen stale_sec is written into the mutex directory so every waiter honors the SAME window, not
# its own default), and release is owner-token-verified (an unconditional rm -rf on release would
# be unsafe once acquire and release are separate processes -- a stale-reclaimed holder's release
# must never delete a successor's mutex).
#
# Lockfile layout (per task):
#   specs/{NNN}_{SLUG}/.lock/            <- directory, created via `mkdir` (POSIX-atomic
#                                            exclusive create: mkdir fails if the dir
#                                            already exists, with no TOCTOU race)
#   specs/{NNN}_{SLUG}/.lock/holder.json <- { session_id, task_number, operation,
#                                              acquired_at, heartbeat_at, command,
#                                              pid, pid_source }
#
# pid/pid_source (added alongside the pid-liveness reap/stale-override floor -- see cmd_reap and
# cmd_acquire's stale-override branch below) mirror the session-registry entry's own pid fields
# and are resolved the SAME way, via resolve_session_pid(). On every cmd_acquire write_holder
# call site pid is FRESHLY resolved for the acquiring process; on cmd_heartbeat's write_holder
# call site the pid already on record is PRESERVED rather than re-resolved, because a heartbeat
# may fire from a different process than the acquirer (notably from update-phase-status.sh's
# mechanized per-phase-transition refresh). A holder written before this field existed, or an
# unresolvable pid, has pid: null -- every consumer (cmd_reap, cmd_acquire's stale-override)
# treats that identically to "no liveness information available" and falls through to the prior
# timestamp-only behavior, never a hard failure.
#
# Stale threshold: TASK_LOCK_STALE_MIN env var, default 30 (minutes). This is
# DISTINCT from and much longer than git-snapshot.sh's unrelated 120-SECOND marker
# freshness window (that window gates one destructive-git exemption; this threshold
# gates whether a lock is still "fresh" for concurrency purposes).
#
# Exit codes:
#   acquire:
#     0 - lock acquired (fresh acquire, same-session re-entry, or stale override).
#         acquire creates the task directory (with reports/, plans/, summaries/) when
#         state.json names the task but no directory exists yet on disk; heartbeat,
#         release, and check remain strictly read-only and never create anything.
#     1 - refused: a DIFFERENT session holds a fresh (non-stale) lock
#     2 - usage/task-not-found error
#   acquire-retry: identical exit-code meaning to acquire (0/1/2) -- it is a bounded
#     wait-and-retry WRAPPER, never a modification of cmd_acquire's body or its exit
#     contract. This is Tier 2 of the four-tier conflict-response ladder (see
#     context/patterns/task-lock.md's "Four-Tier Conflict Response" section). Every
#     attempt is a full, fresh cmd_acquire entry -- the process-global specs/.scope-lock
#     mutex is acquired and released once PER ATTEMPT, never held across the wait window
#     -- so all three same-session re-entry exclusions (cmd_acquire's own holder_session
#     check, the held-lock scan's other_session skip, session_contention()'s self-id
#     exclusion) re-run and re-apply on every attempt. Exit 2 (error, not contention) is
#     never retried and surfaces on the first occurrence. Exit 1 is retried up to
#     TASK_LOCK_RETRY_BUDGET_MS (default 15000ms, polling every TASK_LOCK_RETRY_POLL_MS
#     default 500ms); on budget exhaustion the last attempt's ABORT text is emitted
#     verbatim, unmodified, handing off to the Tier-3 warn tier exactly as plain acquire
#     would for that same fixture.
#   heartbeat:
#     0 - heartbeat refreshed, OR no-op with a warning (lock missing / held by another
#         session — heartbeat never blocks the caller)
#     2 - usage/task-not-found error
#   release:
#     0 - always (idempotent; releasing an already-absent lock is success)
#     2 - usage/task-not-found error
#   check:
#     0 - free (no lock held)
#     1 - held, fresh
#     2 - held, stale (heartbeat older than the threshold)
#     3 - usage/task-not-found error
#   Both the held-fresh and held-stale output lines carry an APPENDED
#   `never_heartbeated=<true|false>` field (`acquired_at == heartbeat_at`) -- a distinct
#   diagnostic from staleness itself: "fresh, never heartbeated yet" (acquired a moment ago, not
#   a problem) is a different condition from "stale, never heartbeated even once" (the exact
#   defect class this exists to make legible, versus "heartbeated for a while then went quiet").
#   The line PREFIX and all three exit codes are unchanged; this is an appended field only, safe
#   for every consumer that reads the line as a prefix/substring (see the "never_heartbeated"
#   section of context/patterns/task-lock.md for the full consumer survey).
#   reap (explicit-invocation-only sweep; NEVER called from acquire/heartbeat/release/check —
#   see context/patterns/task-lock.md's Reap Contract section for the full threshold reasoning):
#     0 - always (whether or not anything qualified for reaping; reap reports, it never fails
#         on "nothing to do")
#     2 - usage error (unrecognized argument)
#   `would reap:`/`reaped:`/`SKIP:` lines also carry the same appended `never_heartbeated=`
#   field (`unknown` when holder.json is missing/unparseable, since there is no acquired_at to
#   compare) -- a dry-run sweep can distinguish "this lock's owner died" from "this lock's owner
#   never heartbeated once" at a glance.
#   init-marker (generic atomic-on-creation marker-file primitive,
#   file-granularity, independent of and unrelated to the acquire/heartbeat/
#   release/check task-number `.lock/` mechanism above):
#     0 - created (fresh; caller treats this as a fresh start)
#     1 - already exists (valid JSON found); caller resumes from the existing file
#     2 - usage/write-error, or an orphaned claim persisted after one self-heal retry
#   scope-acquire (specs/.scope-lock/ global mutex, exposed as a standalone CLI subcommand —
#   see the top-of-file usage comment):
#     0 - acquired; owner token printed on stdout
#     2 - timed out waiting for the mutex (fail closed; current holder named on stderr)
#   scope-release:
#     0 - always (best-effort; a token mismatch or absent mutex is a loud WARNING on stderr,
#         never a failure — release must never fail a caller's cleanup path)
#   commit-acquire (specs/.commit-lock/ sibling mutex serializing scoped git commits; see the
#   top-of-file usage comment and scripts/git-commit-scoped.sh, the sole intended caller):
#     0 - acquired; owner token printed on stdout
#     2 - timed out waiting for the mutex (15s acquire budget, sized for MAX_TASKS=8 concurrent
#         holders; callers are expected to fail OPEN with a loud warning on this timeout rather
#         than abort, since a fail-open commit is still path-scoped -- see git-commit-scoped.sh)
#   commit-release:
#     0 - always (best-effort; a token mismatch or absent mutex is a loud WARNING on stderr,
#         never a failure — release must never fail a caller's cleanup path)
#   session-register (specs/.sessions/{session_id}.json -- see the top-of-file usage comment for
#   the entry schema; upsert semantics -- re-registering the same session_id preserves started_at
#   and refreshes heartbeat_at):
#     0 - registered (fresh or upserted)
#     2 - usage error
#   session-heartbeat:
#     0 - heartbeat refreshed, OR no-op with a stderr warning (entry missing/unparseable —
#         session-heartbeat never blocks the caller, mirroring cmd_heartbeat's own contract)
#     2 - usage error
#   session-release:
#     0 - always (idempotent; releasing an already-absent entry is success)
#     2 - usage error
#   session-reap (explicit-invocation-only; NEVER called from session-register/-heartbeat/
#   -release -- mirrors reap's own "never implicit" contract):
#     0 - always (reports, never fails on "nothing to do")
#     2 - usage error
#
# Same-session re-entry (CRITICAL): a session re-acquiring its own lock (e.g.
# `/research 42` then `/plan 42` in one conversation) MUST NOT self-block. `acquire`
# checks holder.json's session_id BEFORE ever treating an existing lock as a refusal
# — matching session_id always succeeds and just refreshes the heartbeat.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
STATE_FILE="$PROJECT_ROOT/specs/state.json"

# --- ensure_file_scope_overlap_lib: lazy loader for lib/file-scope-overlap.sh ---
# Deferred until first actual use (inside cmd_acquire, the sole consumer of scopes_overlap() /
# session_contention()) rather than sourced unconditionally for the whole task-lock.sh CLI --
# reap/heartbeat/release/check/session-register/session-heartbeat/session-release/session-list
# never touch the overlap predicate and must keep working even if this lib copy is stale or
# missing on the deployed tree. Fails CLOSED (returns 2, never silently skips the check) only
# for the one caller that actually needs it. Deployed path: .claude/scripts/lib/file-scope-
# overlap.sh; source-store path: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh.
# A missing copy at the deployed path most likely just means this repo's .claude/ predates this
# file's addition to the core manifest and has not been regenerated since -- the historical defect
# class where a subdirectory-declared scripts/hooks entry was silently dropped even on a resync
# (the retired glob+allow-list sync engine's top-path-segment allow-list bug) is fixed: the deploy
# tree is now driven by a single manifest-driven engine that addresses every declared entry by its
# manifest path. Remedy: regenerate via the picker's `[Reload All]`/`[Regenerate]` entries or
# `bash .claude/scripts/deploy-headless.sh` so the file reaches .claude/scripts/lib/.
FILE_SCOPE_OVERLAP_LIB_LOADED="false"
ensure_file_scope_overlap_lib() {
  [ "$FILE_SCOPE_OVERLAP_LIB_LOADED" = "true" ] && return 0 || true
  if ! . "${SCRIPT_DIR}/lib/file-scope-overlap.sh" 2>/dev/null; then
    echo "ERROR: task-lock.sh: could not source ${SCRIPT_DIR}/lib/file-scope-overlap.sh." >&2
    echo "  Source-store copy: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh" >&2
    echo "  Remedy: regenerate via the picker's [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh." >&2
    echo "  Failing CLOSED: no fallback overlap check will run; task locking is blocked." >&2
    return 2
  fi
  FILE_SCOPE_OVERLAP_LIB_LOADED="true"
  return 0
}

# Stale threshold in minutes, overridable via env var. Default 30 (plan range: 30-60).
TASK_LOCK_STALE_MIN="${TASK_LOCK_STALE_MIN:-30}"

# Reap threshold in minutes, overridable via env var. Derived from TASK_LOCK_STALE_MIN
# (4x, 120 min at defaults) when unset, so the two thresholds stay proportionate if a
# caller raises the base -- this proportional movement is INTENTIONAL, not a bug. See
# context/patterns/task-lock.md's Reap Contract section for the full derivation: reap
# runs unattended and is meant to be the final word that a lock is dead, so it sits at a
# firm multiple above the override-eligible threshold, not equal to it.
TASK_LOCK_REAP_MIN="${TASK_LOCK_REAP_MIN:-$(( TASK_LOCK_STALE_MIN * 4 ))}"

# Session-registry reap threshold in minutes, overridable via env var. Default 240 (4 hours).
# Deliberately NOT derived from TASK_LOCK_REAP_MIN -- for the same reason
# ORCHESTRATOR_SESSION_REAP_MIN (reap-session-runtime-files.sh) is not: a batch orchestration
# session can legitimately run far longer than any single task's lock window (up to
# MAX_CYCLES_MT = min(task_count * 5, 25) cycles), so the safe threshold must be materially
# longer than a single task's lock threshold. Matches ORCHESTRATOR_SESSION_REAP_MIN's default
# (240) since both bound the same class of "batch session, not single task" runtime.
SESSION_REGISTRY_REAP_MIN="${SESSION_REGISTRY_REAP_MIN:-240}"

# Dead-pid floor in minutes, overridable via env var. Default 10. resolve_session_pid()'s bounded
# ancestor walk can, in principle, resolve to the wrong pid (a misresolved or since-reused pid) --
# this floor guards session-reap's dead-pid shortcut so it can NEVER fire against an entry that
# heartbeated more recently than this many minutes ago, regardless of what kill -0 reports for the
# recorded pid. This is what makes a ppid/self pid_source fallback (see resolve_session_pid below)
# an acceptable outcome rather than a safety hole: even a bogus pid can only ever shorten the wait
# down to this floor, never reap a genuinely live, recently-heartbeated session.
SESSION_REGISTRY_DEAD_PID_MIN="${SESSION_REGISTRY_DEAD_PID_MIN:-10}"

# --- resolve_task_dir: task_number [create_mode] -> specs/{NNN}_{SLUG} absolute path ---
# Prefers state.json's project_name (authoritative, archive-aware via task-lookup-lib.sh --
# active projects win, the archive is consulted only when the number is absent from them);
# falls back to a filesystem glob so the lock still works if state.json lookup fails for any
# reason.
#
# The second parameter is opt-in and OMITTED by every caller except cmd_acquire, which
# passes the literal string "create". With no second argument (or any value other than
# "create"), this function's behavior is byte-identical to its original read-only form:
# cmd_heartbeat, cmd_release, and cmd_check call it with a single argument and never
# trigger creation. When "create" IS passed, creation is reachable ONLY from a path
# resolved via state.json's project_name (recorded in state_dir below) -- never from the
# find fallback below it. The find fallback preserves its original resolution precedence
# unchanged and never creates a directory, so an unknown or typo'd task number still
# fails closed via the final `return 1`. Creation is attempted only AFTER the find
# fallback has already failed, so on project_name/on-disk slug drift the existing
# on-disk directory is still resolved rather than a second, empty one being created.
#
# Archive awareness (surfaced by this task's acceptance path, not originally scoped here): a
# forced dispatch against an archived-and-terminal task reaches task-lock.sh acquire like any
# other dispatch. Without this, `dir` below was derived as the hardcoded
# specs/${padded}_${project_name} (an active-only shape) and the directory-existence check
# failed for an archived task even though `project_name` itself resolved correctly, falling
# through to the maxdepth-1 `specs/` glob (also active-only) and ultimately `return 1` --
# "could not resolve task directory". `task_lookup_dir` resolves the SAME directory
# orchestrate-build-dispatch.sh's own skill_validate_input already wrote the dispatch file into.
resolve_task_dir() {
  local task_number="$1" create_mode="${2:-}"
  local padded project_name dir state_dir=""

  padded=$(printf "%03d" "$task_number" 2>/dev/null) || return 1

  if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    project_name=$(task_lookup_entry "$task_number" "$STATE_FILE" | jq -r '.project_name // empty' 2>/dev/null) || true
    if [ -n "$project_name" ]; then
      dir="$PROJECT_ROOT/$(task_lookup_dir "$task_number" "$project_name" "$PROJECT_ROOT")"
      if [ -d "$dir" ]; then
        echo "$dir"
        return 0
      fi
      state_dir="$dir"
    fi
  fi

  dir=$(find "$PROJECT_ROOT/specs" -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1) || true
  if [ -n "$dir" ]; then
    echo "$dir"
    return 0
  fi

  if [ "$create_mode" = "create" ] && [ -n "$state_dir" ]; then
    mkdir -p "$state_dir/reports" "$state_dir/plans" "$state_dir/summaries" 2>/dev/null || true
    if [ -d "$state_dir" ]; then
      echo "$state_dir"
      return 0
    fi
  fi

  return 1
}

# --- now_epoch: current UTC epoch seconds ---
now_epoch() {
  common_timestamp_epoch
}

# --- iso_now: current UTC ISO8601 timestamp ---
iso_now() {
  common_timestamp_iso
}

# --- write_holder: tmp-file-rename write of holder.json (atomic replace) ---
# pid/pid_source (args 8-9, both optional) mirror write_session_entry's field set -- see the
# "Why No pid on the Task Lock, Historically" absence this closes in task-lock.md. A caller on
# an ACQUIRE path (cmd_acquire's four write_holder call sites) resolves a FRESH pid via
# resolve_session_pid() before calling here. A caller on a HEARTBEAT refresh (cmd_heartbeat's
# call site) preserves the pid ALREADY recorded in holder.json instead -- the heartbeat may be
# invoked from a different process than the acquirer (notably from update-phase-status.sh after
# this file's own mechanized refresh), so re-resolving there would silently rewrite the lock's
# identity to the heartbeat caller's own pid. An empty/non-numeric pid writes JSON null,
# identical in shape to a legacy holder.json that predates this field -- every consumer treats
# both as "no liveness information available", never as a hard failure.
write_holder() {
  local lock_dir="$1" session_id="$2" task_number="$3" operation="$4" acquired_at="$5" heartbeat_at="$6" command="$7" pid="${8:-}" pid_source="${9:-}"
  local tmp_file="$lock_dir/holder.json.tmp"
  local pid_json
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    pid_json="$pid"
  else
    pid_json="null"
  fi

  # Every caller decided ITS OWN session should hold (or continue holding) this lock before
  # reaching this write -- that decision already happened in cmd_acquire/cmd_heartbeat above and
  # is not re-litigated here. But $lock_dir can be concurrently removed by another process (a
  # release, a reaper, or -- as test-four-tier-conflict.sh's Tier-2 resolving fixture deliberately
  # exercises -- a foreign holder releasing mid-retry-window) in the window between a caller's
  # existence check and this write. Recreating it here is therefore always the correct response,
  # never a decision of its own: it is a no-op if the directory still exists, and otherwise it is
  # exactly what this write needs to proceed for the session that already earned the right to
  # write. Without this, the tmp-file open below fails with "No such file or directory" and the
  # caller's whole acquire/heartbeat aborts with an ERROR that the race itself, not real
  # contention, caused.
  mkdir -p "$lock_dir" 2>/dev/null || true

  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$task_number" \
    --arg operation "$operation" \
    --arg acquired_at "$acquired_at" \
    --arg heartbeat_at "$heartbeat_at" \
    --arg command "$command" \
    --argjson pid "$pid_json" \
    --arg pid_source "$pid_source" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $acquired_at, heartbeat_at: $heartbeat_at, command: $command, pid: $pid, pid_source: $pid_source}' \
    > "$tmp_file" || true

  if [ ! -s "$tmp_file" ]; then
    echo "ERROR: failed to write holder.json (jq produced empty output)" >&2
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$lock_dir/holder.json"
}

# --- read_holder_field: read a single field from holder.json ---
# Guarded to always return 0: under set -e, every bare `VAR=$(read_holder_field ...)` call
# site (there are many, across cmd_acquire/cmd_heartbeat/cmd_release/cmd_check/cmd_reap) would
# otherwise abort the script on a missing/unreadable/corrupt holder.json -- a condition every
# caller already treats as "empty field, degrade gracefully" via `${var:-...}` or `[ -n "$var" ]`
# checks, never as fatal.
read_holder_field() {
  local lock_dir="$1" field="$2"
  jq -r --arg f "$field" '.[$f] // empty' "$lock_dir/holder.json" 2>/dev/null || echo ""
}

# --- age_minutes: minutes elapsed since an ISO8601 timestamp ---
age_minutes() {
  local ts="$1" then_epoch now
  then_epoch=$(date -u -d "$ts" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null) || true
  if [ -z "$then_epoch" ]; then
    echo "999999"
    return 0
  fi
  now=$(now_epoch)
  echo $(( (now - then_epoch) / 60 ))
}

# --- never_heartbeated_flag: acquired_at == heartbeat_at fingerprint ---
# Distinct diagnostic from staleness: a lock can be FRESH-but-never-heartbeated (acquired a
# moment ago, no heartbeat call has fired yet -- not itself a problem) or STALE-and-
# never-heartbeated (acquired long ago and its heartbeat mechanism never fired even once --
# the exact defect class this field exists to make legible, as opposed to "heartbeated for a
# while, then the holder went quiet"). Prints "true", "false", or "unknown" (either input
# timestamp empty/unparseable, e.g. the reap fallback branch with no valid holder.json at all).
never_heartbeated_flag() {
  local acquired_at="$1" heartbeat_at="$2"
  if [ -z "$acquired_at" ] || [ -z "$heartbeat_at" ]; then
    echo "unknown"
    return 0
  fi
  if [ "$acquired_at" = "$heartbeat_at" ]; then
    echo "true"
  else
    echo "false"
  fi
}

# --- get_file_scope: task_number -> compact JSON file_scope array ---
# Graceful degradation mirrors resolve_task_dir: any lookup failure (missing state
# file, no jq, unknown task, absent/null field) resolves to "[]", never a non-zero
# exit or stderr noise that could break the acquire caller.
get_file_scope() {
  local task_number="$1" result
  if [ -f "$STATE_FILE" ] && command -v jq >/dev/null 2>&1; then
    result=$(jq -c --argjson num "$task_number" \
      '(.active_projects[]? | select(.project_number == $num) | .file_scope) // empty' \
      "$STATE_FILE" 2>/dev/null) || true
    if [ -n "$result" ] && [ "$result" != "null" ]; then
      echo "$result"
      return 0
    fi
  fi
  echo "[]"
}

# --- scopes_overlap: now sourced from lib/file-scope-overlap.sh (single shared definition) ---
# Same signature (`scopes_overlap "$scope_a" "$scope_b"`) and return convention (first
# overlapping path from the foreign side, empty on no match) as before -- see
# lib/file-scope-overlap.sh for the implementation. Lazily sourced by
# ensure_file_scope_overlap_lib() (defined near the top of this file) on first use inside
# cmd_acquire; failure to source returns 2 (fail closed) from cmd_acquire only, never aborting
# unrelated subcommands (reap, session-*, heartbeat, release, check) that never call it.

# --- find_held_locks: list foreign .lock dirs under specs/, excluding one dir ---
# Skips any lock dir whose holder.json is missing or unreadable/invalid (never lets
# a corrupt foreign holder abort the caller's own acquire).
find_held_locks() {
  local exclude_dir="$1" dir
  find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 2 -type d -name ".lock" 2>/dev/null |
    while IFS= read -r dir; do
      [ "$dir" = "$exclude_dir" ] && continue || true
      [ -f "$dir/holder.json" ] || continue
      jq -e . "$dir/holder.json" >/dev/null 2>&1 || continue
      echo "$dir"
    done
}

# --- Session-Registry helpers (session-register/session-heartbeat/session-release/session-reap) ---
# See context/patterns/task-lock.md's Session-Registry CLI section for the full contract. No
# `mkdir` exclusivity gate is used here (unlike the task-number `.lock/` mechanism above): each
# session writes only its own globally-unique-id'd file (specs/.sessions/{session_id}.json), so
# write_session_entry()'s tmp-file-mv atomicity alone is sufficient to prevent a concurrent
# session-reap sweep from ever observing a half-written entry.

# --- session_registry_dir: specs/.sessions absolute path, creating it on the register path only ---
# Creation is confined to session-register, mirroring how resolve_task_dir's create_mode is
# confined to cmd_acquire -- session-heartbeat/-release/-reap all resolve this path read-only via
# the same function with create=false and have zero filesystem side effects when the directory is
# absent.
session_registry_dir() {
  local create="${1:-false}"
  local dir="$PROJECT_ROOT/specs/.sessions"
  if [ "$create" = "true" ]; then
    mkdir -p "$dir" 2>/dev/null || true
  fi
  echo "$dir"
}

# --- resolve_session_pid: bounded ancestor walk for the nearest "claude" process ---
# Prints "<pid> <pid_source>" on stdout. $$ inside this short-lived helper script is the helper's
# OWN pid, not the long-lived session process -- using it bare would make every registered entry
# look instantly dead and let session-reap's dead-pid shortcut reap live sessions. Walks up the
# process tree (at most 10 hops, stopping at pid 1) looking for a process whose command name
# contains "claude". Falls back in order: ancestor-claude -> ppid -> self. An explicit --pid N
# argument overrides the walk entirely (pid_source=explicit).
resolve_session_pid() {
  local explicit_pid=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --pid)
        explicit_pid="$2"
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  if [ -n "$explicit_pid" ]; then
    echo "$explicit_pid explicit"
    return 0
  fi

  local pid="$$" hop comm ppid
  for hop in 1 2 3 4 5 6 7 8 9 10; do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || true
    if [ -n "$comm" ] && [[ "$comm" == *claude* ]]; then
      echo "$pid ancestor-claude"
      return 0
    fi
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ') || true
    if [ -z "$ppid" ] || [ "$ppid" = "1" ]; then
      break
    fi
    pid="$ppid"
  done

  ppid=$(ps -o ppid= -p "$$" 2>/dev/null | tr -d ' ') || true
  if [ -n "$ppid" ]; then
    echo "$ppid ppid"
    return 0
  fi

  echo "$$ self"
  return 0
}

# --- write_session_entry: tmp-file-rename write of specs/.sessions/{session_id}.json ---
# Modeled byte-for-byte on write_holder's shape above: jq -n into <file>.tmp, empty-output guard,
# then mv. No mkdir exclusivity gate (see the Session-Registry helpers comment above).
write_session_entry() {
  local sessions_dir="$1" session_id="$2" pid="$3" pid_source="$4" command="$5" task_numbers_json="$6" file_scope_json="$7" started_at="$8" heartbeat_at="$9"
  local target="$sessions_dir/${session_id}.json"
  local tmp_file="${target}.tmp"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --arg pid_source "$pid_source" \
    --arg command "$command" \
    --argjson task_numbers "$task_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg started_at "$started_at" \
    --arg heartbeat_at "$heartbeat_at" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $started_at, heartbeat_at: $heartbeat_at}' \
    > "$tmp_file" || true

  if [ ! -s "$tmp_file" ]; then
    echo "ERROR: failed to write session registry entry $target (jq produced empty output)" >&2
    rm -f "$tmp_file"
    return 1
  fi

  mv "$tmp_file" "$target"
}

# --- Named-mutex primitives (generalized from this file's original specs/.scope-lock/-only
# implementation, so a second, independent mutex directory -- specs/.commit-lock/, added below
# for scoped-commit serialization -- can reuse the exact same mkdir/staleness/wait-budget logic
# without a second hand-copied implementation to drift out of sync). ---

# acquire_named_mutex <mutex_dirname> <requested_stale> <default_stale_sec> <wait_budget_ms>
#
# <mutex_dirname> is a bare directory name resolved under specs/ (e.g. ".scope-lock",
# ".commit-lock") -- each caller's wrapper below fixes its own directory, default staleness, and
# wait budget, so this function itself has no knowledge of which mutex it is serving.
#
# Staleness is holder-declared, not waiter-declared: the successful acquirer writes its own
# tolerated window into $mutex_dir/stale_sec alongside claimed_at, and every waiter (including
# waiters with a different default) reads THAT file when deciding whether to reclaim. This lets a
# long-running critical section (e.g. scope-acquire called with a generous stale_sec) declare a
# window all concurrent waiters honor, instead of a short-window waiter reclaiming the mutex out
# from under a still-live, longer-running holder.
acquire_named_mutex() {
  local mutex_dirname="$1" requested_stale="${2:-}" default_stale_sec="$3" wait_budget_ms="$4"
  local stale_sec
  if [[ "$requested_stale" =~ ^[0-9]+$ ]]; then
    stale_sec="$requested_stale"
  else
    stale_sec="$default_stale_sec"
  fi

  local mutex_dir="$PROJECT_ROOT/specs/${mutex_dirname}"
  local waited_ms=0 claimed_at now age holder_stale_sec
  while true; do
    if mkdir "$mutex_dir" 2>/dev/null; then
      now_epoch > "$mutex_dir/claimed_at" 2>/dev/null || true
      echo "$stale_sec" > "$mutex_dir/stale_sec" 2>/dev/null || true
      return 0
    fi

    claimed_at=$(cat "$mutex_dir/claimed_at" 2>/dev/null) || true
    now=$(now_epoch)
    holder_stale_sec=$(cat "$mutex_dir/stale_sec" 2>/dev/null) || true
    if ! [[ "$holder_stale_sec" =~ ^[0-9]+$ ]]; then
      holder_stale_sec="$default_stale_sec"
    fi
    if [ -n "$claimed_at" ]; then
      age=$(( now - claimed_at ))
      if [ "$age" -gt "$holder_stale_sec" ]; then
        echo "WARN: reclaiming stale specs/${mutex_dirname} mutex (age ${age}s > holder-declared ${holder_stale_sec}s)." >&2
        rm -rf "$mutex_dir" 2>/dev/null || true
        continue
      fi
    fi

    if [ "$waited_ms" -ge "$wait_budget_ms" ]; then
      return 1
    fi
    sleep 0.05
    waited_ms=$(( waited_ms + 50 ))
  done
}

release_named_mutex() {
  local mutex_dirname="$1"
  rm -rf "$PROJECT_ROOT/specs/${mutex_dirname}" 2>/dev/null || true
}

# --- specs/.scope-lock/ global mutex (cross-task file_scope overlap check) ---
# Closes the scan-then-mkdir TOCTOU race around cmd_acquire's cross-task overlap
# scan. Distinct staleness window from TASK_LOCK_STALE_MIN: a stuck mutex is a bug,
# not ordinary contention, so this window is short and acquire_scope_mutex fails
# CLOSED (non-zero) on timeout rather than ever failing open.
SCOPE_MUTEX_STALE_SEC=10
SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000

# acquire_scope_mutex [stale_sec]
#
# Thin wrapper over acquire_named_mutex, preserving this function's original signature and
# behavior byte-for-byte (same directory, same 10s default staleness, same 5000ms wait budget)
# for cmd_acquire's pre-existing no-argument call site and every other existing caller.
acquire_scope_mutex() {
  local requested_stale="${1:-}"
  acquire_named_mutex ".scope-lock" "$requested_stale" "$SCOPE_MUTEX_STALE_SEC" "$SCOPE_MUTEX_ACQUIRE_BUDGET_MS"
}

release_scope_mutex() {
  release_named_mutex ".scope-lock"
}

# --- specs/.commit-lock/ sibling mutex (serializes the git add + git commit pair around scoped
# commits; see scripts/git-commit-scoped.sh, the sole intended caller) ---
# A DISTINCT mutex directory and a DISTINCT reentrancy flag (COMMIT_MUTEX_HELD, never
# SCOPE_MUTEX_HELD) from .scope-lock above -- see the top-of-file usage comment for why reusing
# .scope-lock here would be unsafe. Larger acquire budget than .scope-lock (15s vs 5s) because it
# is sized for MAX_TASKS=8 concurrent committers rather than a single fast scan-then-mkdir
# sequence; correspondingly longer holder-declared staleness (30s vs 10s), generous against
# measured sub-second commits but short enough to reclaim a genuinely stuck holder.
COMMIT_MUTEX_STALE_SEC=30
COMMIT_MUTEX_ACQUIRE_BUDGET_MS=15000

# acquire_commit_mutex [stale_sec]
acquire_commit_mutex() {
  local requested_stale="${1:-}"
  acquire_named_mutex ".commit-lock" "$requested_stale" "$COMMIT_MUTEX_STALE_SEC" "$COMMIT_MUTEX_ACQUIRE_BUDGET_MS"
}

release_commit_mutex() {
  release_named_mutex ".commit-lock"
}

# --- acquire-retry bounded wait-and-retry constants (Tier 2 of the four-tier conflict-response
# ladder; see context/patterns/task-lock.md's "Four-Tier Conflict Response" section) ---
# Sized on the .scope-lock/.commit-lock seconds-scale mutex-acquire budgets above
# (SCOPE_MUTEX_ACQUIRE_BUDGET_MS=5000, COMMIT_MUTEX_ACQUIRE_BUDGET_MS=15000), NOT on
# TASK_LOCK_STALE_MIN (30 minutes, default) -- that constant measures how long a lock holder's
# heartbeat may go quiet before its lock is considered stale and overridable, a completely
# different quantity from how long a fresh contending acquire should wait before falling through
# to the warn tier. Deliberately unrelated; do not derive one from the other.
TASK_LOCK_RETRY_BUDGET_MS="${TASK_LOCK_RETRY_BUDGET_MS:-15000}"
TASK_LOCK_RETRY_POLL_MS="${TASK_LOCK_RETRY_POLL_MS:-500}"

# =====================================================================
# acquire <task_number> <operation> <session_id> [command]
# =====================================================================
cmd_acquire() {
  local task_number="$1" operation="$2" session_id="$3" command="${4:-}"
  local task_dir lock_dir

  # Fresh pid resolution for THIS acquiring process, computed once and reused across every
  # write_holder call site below (fresh acquire, corrupt-holder recovery, same-session
  # re-entry, stale override) -- all four are "acquire paths" in the write_holder header
  # comment's sense, distinct from cmd_heartbeat's own call site which preserves the pid
  # already on record instead of re-resolving.
  local acquire_pid acquire_pid_source
  read -r acquire_pid acquire_pid_source <<< "$(resolve_session_pid)"

  task_dir=$(resolve_task_dir "$task_number" "create") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  # --- cross-task file_scope overlap check, mutex-guarded ---
  # Wraps the scan-and-decide below AND the pre-existing own-task mkdir/holder logic in
  # the global specs/.scope-lock/ mutex, closing the scan-then-mkdir TOCTOU race. Fails
  # CLOSED (return 2) on mutex timeout — a stuck mutex is a bug, never silently bypassed.
  if ! acquire_scope_mutex; then
    echo "ERROR: timed out waiting for specs/.scope-lock mutex during task $task_number's acquire; another acquire may be stuck." >&2
    return 2
  fi
  trap 'release_scope_mutex' RETURN

  local own_scope
  own_scope=$(get_file_scope "$task_number")
  if [ -n "$own_scope" ] && [ "$own_scope" != "[]" ]; then
    if ! ensure_file_scope_overlap_lib; then
      return 2
    fi
    local held_dir other_task other_session other_scope overlap_path other_heartbeat other_age
    while IFS= read -r held_dir; do
      [ -n "$held_dir" ] || continue
      other_task=$(read_holder_field "$held_dir" "task_number")
      other_session=$(read_holder_field "$held_dir" "session_id")
      # Skip: unreadable holder, defensive self-match, or same-session bypass (report
      # Decisions — a session's own concurrent work never blocks itself).
      [ -n "$other_task" ] || continue
      [ "$other_task" = "$task_number" ] && continue || true
      [ "$other_session" = "$session_id" ] && continue || true

      other_scope=$(get_file_scope "$other_task")
      overlap_path=$(scopes_overlap "$own_scope" "$other_scope") || true
      if [ -n "$overlap_path" ]; then
        other_heartbeat=$(read_holder_field "$held_dir" "heartbeat_at")
        other_age=$(age_minutes "$other_heartbeat")
        if [ "$other_age" -le "$TASK_LOCK_STALE_MIN" ]; then
          # Fresh overlapping foreign lock: refuse. The foreign lock is only ever read
          # here, never mutated.
          echo "ABORT: Task $task_number's file_scope overlaps task $other_task's file_scope at \"$overlap_path\" and task $other_task is locked by session $other_session (heartbeat ${other_age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min)." >&2
          echo "  Wait for task $other_task's lock to go stale, or coordinate with that session before retrying." >&2
          return 1
        fi
        # Stale overlapping foreign lock: warn and proceed. Never touch the foreign lock.
        echo "WARN: task $other_task's file_scope overlaps this acquire at \"$overlap_path\", but task $other_task's lock (session $other_session, heartbeat ${other_age} min ago) is stale (> ${TASK_LOCK_STALE_MIN} min); proceeding without modifying it." >&2
      fi
    done < <(find_held_locks "$lock_dir")

    # --- session-registry contention pass (input 2, session_contention from the shared lib) ---
    # Still inside the same own_scope guard, lib-load gate, and acquire_scope_mutex critical
    # section as the held-lock pass above. Mirrors that pass's fresh-ABORT shape, collapsed to a
    # single branch: session_contention() already applies D4's three exclusions (self-session-id,
    # liveness, per-covered-task-number dependency edge) internally, so EVERY hit it returns is
    # already confirmed contending -- there is no separate "stale -> WARN and proceed" case here
    # the way the held-lock pass has one, because a dead-pid/stale-heartbeat session never
    # produces a hit at all (excluded before session_contention() ever reaches the overlap test).
    # Read-only: cmd_session_list and STATE_FILE are only ever read here, the session registry is
    # never mutated -- exactly like the held-lock pass never mutates a foreign lock.
    local sessions_json all_json sess_hit
    sessions_json=$(cmd_session_list | jq -s -c '.' 2>/dev/null) || true
    [ -z "$sessions_json" ] && sessions_json='[]' || true
    all_json=$(jq -c '.active_projects // []' "$STATE_FILE" 2>/dev/null) || true
    [ -z "$all_json" ] && all_json='[]' || true
    sess_hit=$(jq -n -c --argjson cscope "$own_scope" --argjson cnum "$task_number" \
      --arg own_sid "$session_id" --argjson all "$all_json" --argjson sessions "$sessions_json" \
      "$FILE_SCOPE_OVERLAP_JQ_DEFS"'
session_contention($cscope; $cnum; $own_sid; $all; $sessions)' 2>/dev/null) || true
    if [ -n "$sess_hit" ] && [ "$sess_hit" != "null" ]; then
      local sess_session_id sess_covered_num sess_overlap_path sess_liveness
      sess_session_id=$(jq -r '.session_id' <<<"$sess_hit" 2>/dev/null) || true
      sess_covered_num=$(jq -r '.covered_task_number' <<<"$sess_hit" 2>/dev/null) || true
      sess_overlap_path=$(jq -r '.overlapping_path' <<<"$sess_hit" 2>/dev/null) || true
      sess_liveness=$(jq -r '.liveness_reason' <<<"$sess_hit" 2>/dev/null) || true
      echo "ABORT: Task $task_number's file_scope overlaps registered session $sess_session_id's file_scope at \"$sess_overlap_path\" (session covers task #$sess_covered_num, liveness: $sess_liveness). The session registry is only ever read here, never mutated." >&2
      echo "  Wait for that session to finish or release, or coordinate with it before retrying." >&2
      return 1
    fi
    # --- end session-registry contention pass ---
  fi
  # --- end cross-task file_scope overlap check ---

  if mkdir "$lock_dir" 2>/dev/null; then
    # Fresh acquire: directory did not exist a moment ago (POSIX-atomic).
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" "$acquire_pid" "$acquire_pid_source" || return 2
    return 0
  fi

  # mkdir failed: lock directory already exists. Inspect the holder.
  if [ ! -f "$lock_dir/holder.json" ]; then
    # Directory exists but holder.json is missing/corrupt (e.g. interrupted acquire).
    # Treat as acquirable: overwrite in place (do not remove the dir, just the write).
    echo "WARN: lock directory for task $task_number exists without holder.json; treating as recoverable and overriding." >&2
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" "$acquire_pid" "$acquire_pid_source" || return 2
    return 0
  fi

  local holder_session holder_heartbeat age
  holder_session=$(read_holder_field "$lock_dir" "session_id")
  holder_heartbeat=$(read_holder_field "$lock_dir" "heartbeat_at")

  if [ "$holder_session" = "$session_id" ]; then
    # Same-session re-entry: MUST NOT self-block. Refresh heartbeat only.
    local acquired_at
    acquired_at=$(read_holder_field "$lock_dir" "acquired_at")
    write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "${acquired_at:-$(iso_now)}" "$(iso_now)" "$command" "$acquire_pid" "$acquire_pid_source" || return 2
    return 0
  fi

  age=$(age_minutes "$holder_heartbeat")

  if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
    # Fresh lock held by a DIFFERENT session: refuse.
    echo "ABORT: Task $task_number is locked by session $holder_session (heartbeat ${age} min ago; stale threshold ${TASK_LOCK_STALE_MIN} min)." >&2
    echo "  Wait for the lock to go stale, or override manually: rm -rf \"$lock_dir\"" >&2
    return 1
  fi

  # Stale-by-timestamp, but pid-liveness floor: refuse to override a lock whose recorded holder
  # pid is confirmably still alive, mirroring cmd_reap's own refusal above. A live holder pid
  # under a stale heartbeat most likely means the holder process is wedged (or its heartbeat
  # mechanism is broken) rather than gone -- an automatic override here would let a second
  # session silently steal a lock a live process still holds. A legacy holder with no pid field,
  # or an unresolvable/non-numeric pid, keeps today's override-and-warn behavior unchanged.
  local holder_pid
  holder_pid=$(read_holder_field "$lock_dir" "pid")
  if [[ "$holder_pid" =~ ^[0-9]+$ ]] && kill -0 "$holder_pid" 2>/dev/null; then
    echo "ABORT: Task $task_number's lock (session $holder_session, heartbeat ${age} min ago) is stale (> ${TASK_LOCK_STALE_MIN} min threshold), but its recorded holder pid $holder_pid is still alive; refusing to override automatically." >&2
    echo "  Investigate the live process before overriding manually: rm -rf \"$lock_dir\"" >&2
    return 1
  fi

  # Stale lock held by a different session: override-and-warn (never silent, never permanent).
  echo "WARN: Task $task_number's lock (session $holder_session, heartbeat ${age} min ago) is stale (> ${TASK_LOCK_STALE_MIN} min threshold); overriding and acquiring for $session_id." >&2
  write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$(iso_now)" "$(iso_now)" "$command" "$acquire_pid" "$acquire_pid_source" || return 2
  return 0
}

# =====================================================================
# acquire-retry <task_number> <operation> <session_id> [command]
#
# Tier 2 of the four-tier conflict-response ladder (auto-sequence, bounded retry, warn, ask; see
# context/patterns/task-lock.md). Bounded wait-and-retry wrapper AROUND cmd_acquire, never a
# modification of it: each attempt is a full, fresh cmd_acquire invocation (own mkdir/holder
# logic, own acquire_scope_mutex acquire-and-release, own cross-task overlap scan, own
# session-registry contention pass). This is the ONLY safe way to add retry here --
# cmd_acquire holds the process-global specs/.scope-lock mutex for its ENTIRE body via
# `trap 'release_scope_mutex' RETURN`, including its ABORT branches, so a retry loop placed
# INSIDE cmd_acquire would hold that mutex across the whole wait window, blocking every other
# task's acquire system-wide, and would itself be reclaimed by a competing waiter after
# SCOPE_MUTEX_STALE_SEC=10 seconds. Placing the loop out here means the mutex is acquired and
# released once per attempt, exactly as a solo `acquire` call already does.
#
# Because every attempt is a full fresh cmd_acquire entry, all three same-session re-entry
# exclusions re-run and re-apply on every attempt:
#   1. cmd_acquire's own `[ "$holder_session" = "$session_id" ]` fast-path (line ~674 above).
#   2. The held-lock overlap scan's `[ "$other_session" = "$session_id" ] && continue` skip.
#   3. session_contention()'s internal self-session-id exclusion (shared jq lib).
# A same-session re-entrant acquire therefore returns 0 on attempt 1 every time and the retry
# loop body below is never entered for that case -- there is no path where a session waits on
# its own lock.
#
# Exit codes are identical in meaning to plain `acquire`: 0 = acquired, 1 = refused (only after
# the full retry budget is exhausted), 2 = error (never retried -- see below).
#
# Exit-2 handling: exit 2 from cmd_acquire signals an ERROR (specs/.scope-lock mutex timeout,
# resolve_task_dir failure, or a write_holder failure), NOT ordinary lock contention. It is
# returned immediately on the FIRST occurrence, never retried -- retrying an error condition
# would just burn the wait budget on a problem bounded retry cannot fix.
#
# Exit-1 handling: exit 1 (ABORT -- any of the three fresh-contention variants: own-task holder,
# cross-task file_scope overlap against a held lock, cross-task overlap against a registered
# session) is treated as ordinary contention: the captured ABORT text is discarded for every
# attempt except the LAST, the loop sleeps TASK_LOCK_RETRY_POLL_MS, and re-attempts until
# TASK_LOCK_RETRY_BUDGET_MS is exhausted. On budget exhaustion the LAST attempt's captured
# stderr is emitted verbatim -- this is the Tier-2 -> Tier-3 handoff, and it is load-bearing:
# whichever of the three ABORT variants fired must reach the user with every field intact and
# unmodified, byte-identical to what a plain `acquire` call would have emitted for the same
# fixture, so the existing warn-tier consumers (command-gate-in.sh's failure path, the
# orchestrator_mode-gated Tier-4 ask flow) see exactly the message they already know how to
# render.
cmd_acquire_retry() {
  local waited_ms=0 first_retry=1
  local captured_stderr rc

  while true; do
    if captured_stderr=$(cmd_acquire "$@" 2>&1 1>/dev/null); then
      rc=0
    else
      rc=$?
    fi

    if [ "$rc" -eq 0 ]; then
      [ -n "$captured_stderr" ] && echo "$captured_stderr" >&2 || true
      return 0
    fi

    if [ "$rc" -eq 2 ]; then
      # Error, not contention: never retried, surfaced immediately.
      [ -n "$captured_stderr" ] && echo "$captured_stderr" >&2 || true
      return 2
    fi

    # rc == 1 (ABORT / ordinary contention).
    if [ "$waited_ms" -ge "$TASK_LOCK_RETRY_BUDGET_MS" ]; then
      # Budget exhausted: emit the LAST attempt's captured ABORT text verbatim (Tier-3 handoff)
      # and refuse, exactly like plain `acquire` would for this same final-attempt fixture.
      [ -n "$captured_stderr" ] && echo "$captured_stderr" >&2 || true
      return 1
    fi

    if [ "$first_retry" -eq 1 ]; then
      echo "NOTE: task ${1:-?}'s lock is held by another session; waiting up to ${TASK_LOCK_RETRY_BUDGET_MS}ms and retrying before warning." >&2
      first_retry=0
    fi

    sleep "$(awk -v ms="$TASK_LOCK_RETRY_POLL_MS" 'BEGIN { printf "%.3f", ms / 1000 }')"
    waited_ms=$(( waited_ms + TASK_LOCK_RETRY_POLL_MS ))
  done
}

# =====================================================================
# heartbeat <task_number> <session_id>
# =====================================================================
cmd_heartbeat() {
  local task_number="$1" session_id="$2"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  if [ ! -d "$lock_dir" ] || [ ! -f "$lock_dir/holder.json" ]; then
    echo "WARN: heartbeat no-op — no lock held for task $task_number." >&2
    return 0
  fi

  local holder_session
  holder_session=$(read_holder_field "$lock_dir" "session_id")

  if [ "$holder_session" != "$session_id" ]; then
    echo "WARN: heartbeat no-op — task $task_number's lock is held by a different session ($holder_session), not $session_id." >&2
    return 0
  fi

  # Preserve the pid/pid_source already on record rather than re-resolving: a heartbeat may be
  # invoked from a DIFFERENT process than the one that acquired the lock (notably from
  # update-phase-status.sh's mechanized refresh) -- re-resolving here would silently rewrite the
  # lock's recorded identity to the heartbeat caller's own pid. A legacy holder.json with no pid
  # field reads back empty, which write_holder already treats as "no liveness information",
  # identical to today's pid-less behavior.
  local operation acquired_at command holder_pid holder_pid_source
  operation=$(read_holder_field "$lock_dir" "operation")
  acquired_at=$(read_holder_field "$lock_dir" "acquired_at")
  command=$(read_holder_field "$lock_dir" "command")
  holder_pid=$(read_holder_field "$lock_dir" "pid")
  holder_pid_source=$(read_holder_field "$lock_dir" "pid_source")
  write_holder "$lock_dir" "$session_id" "$task_number" "$operation" "$acquired_at" "$(iso_now)" "$command" "$holder_pid" "$holder_pid_source" || return 2
  return 0
}

# =====================================================================
# release <task_number> <session_id>
# =====================================================================
# Owner-verified: reads the caller's session_id (the already-accepted second positional
# argument) and compares it against holder.json's session_id before removing the lock
# directory. On mismatch: WARN loudly, do NOT remove the lock directory, and return 0 --
# mirroring cmd_scope_release's token-mismatch handling (never a forced removal, release must
# never fail a caller's cleanup path). On match, or when the lock directory or holder.json is
# already absent, behavior is unchanged: idempotent rm -rf, return 0.
cmd_release() {
  local task_number="$1" session_id="${2:-}"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 2
  }
  lock_dir="$task_dir/.lock"

  if [ ! -d "$lock_dir" ]; then
    # Already absent: idempotent success, nothing to verify.
    return 0
  fi

  if [ -f "$lock_dir/holder.json" ] && [ -n "$session_id" ]; then
    local holder_session
    holder_session=$(read_holder_field "$lock_dir" "session_id")
    if [ -n "$holder_session" ] && [ "$holder_session" != "$session_id" ]; then
      echo "WARN: release for task $task_number given session=$session_id does not match current holder session=$holder_session; NOT releasing. This means a different session than the one that acquired the lock attempted to release it -- investigate rather than force-remove." >&2
      return 0
    fi
  fi

  # Match, or no holder.json/session_id to verify against: preserve prior behavior exactly
  # (unconditional and idempotent; success/partial/failed all release; an already-absent lock
  # is not an error).
  rm -rf "$lock_dir" 2>/dev/null || true
  return 0
}

# =====================================================================
# check <task_number>
# =====================================================================
cmd_check() {
  local task_number="$1"
  local task_dir lock_dir

  task_dir=$(resolve_task_dir "$task_number") || {
    echo "ERROR: could not resolve task directory for task $task_number" >&2
    return 3
  }
  lock_dir="$task_dir/.lock"

  if [ ! -d "$lock_dir" ] || [ ! -f "$lock_dir/holder.json" ]; then
    echo "free"
    return 0
  fi

  local holder_session holder_heartbeat holder_acquired age never_hb
  holder_session=$(read_holder_field "$lock_dir" "session_id")
  holder_heartbeat=$(read_holder_field "$lock_dir" "heartbeat_at")
  holder_acquired=$(read_holder_field "$lock_dir" "acquired_at")
  age=$(age_minutes "$holder_heartbeat")
  never_hb=$(never_heartbeated_flag "$holder_acquired" "$holder_heartbeat")

  if [ "$age" -le "$TASK_LOCK_STALE_MIN" ]; then
    echo "held-fresh session=$holder_session heartbeat_age_min=$age threshold_min=$TASK_LOCK_STALE_MIN never_heartbeated=$never_hb"
    return 1
  else
    echo "held-stale session=$holder_session heartbeat_age_min=$age threshold_min=$TASK_LOCK_STALE_MIN never_heartbeated=$never_hb"
    return 2
  fi
}

# =====================================================================
# reap [--dry-run]
# =====================================================================
# Explicit-invocation-only sweep of every task-number `.lock` directory under specs/
# (including specs/archive/, depth 3) whose staleness exceeds TASK_LOCK_REAP_MIN. See
# context/patterns/task-lock.md's Reap Contract section for the full threshold reasoning
# and the correction to this feature's originating premise (no holder-declared staleness
# field exists on holder.json; the reaper reads the same TASK_LOCK_STALE_MIN-derived
# constant every other caller reads).
#
# NEVER called from cmd_acquire/cmd_heartbeat/cmd_release/cmd_check -- reap is reachable
# ONLY via this explicit `reap` subcommand. Deliberately does NOT call find_held_locks()
# (its -mindepth 2 -maxdepth 2 cannot reach specs/archive/{NNN}_{slug}/.lock at depth 3);
# find_held_locks() itself is left byte-identical, since an archived task has no active
# file_scope to overlap with cmd_acquire's scan and widening it would add work and no
# signal.
cmd_reap() {
  local dry_run=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        echo "Usage: $0 reap [--dry-run]" >&2
        return 2
        ;;
    esac
  done

  local lock_dir total_count=0 reaped_count=0

  while IFS= read -r lock_dir; do
    [ -n "$lock_dir" ] || continue
    total_count=$(( total_count + 1 ))

    local task_number session_id operation age reason_suffix="" holder_pid="" never_hb="unknown"
    if [ -f "$lock_dir/holder.json" ] && jq -e . "$lock_dir/holder.json" >/dev/null 2>&1; then
      task_number=$(read_holder_field "$lock_dir" "task_number")
      session_id=$(read_holder_field "$lock_dir" "session_id")
      operation=$(read_holder_field "$lock_dir" "operation")
      local holder_heartbeat_val holder_acquired_val
      holder_heartbeat_val=$(read_holder_field "$lock_dir" "heartbeat_at")
      holder_acquired_val=$(read_holder_field "$lock_dir" "acquired_at")
      age=$(age_minutes "$holder_heartbeat_val")
      holder_pid=$(read_holder_field "$lock_dir" "pid")
      never_hb=$(never_heartbeated_flag "$holder_acquired_val" "$holder_heartbeat_val")
    else
      # Missing/unparseable holder.json (e.g. an interrupted acquire's mkdir-then-write
      # race window): fall back to the .lock directory's own mtime. Reap only if that
      # mtime age ALSO exceeds the threshold; otherwise this is reported via a SKIP:
      # line below and left in place, never silently ignored.
      task_number="unknown"
      session_id="unknown"
      operation="unknown"
      local dir_mtime
      dir_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null) || true
      if [ -n "$dir_mtime" ]; then
        age=$(( ( $(now_epoch) - dir_mtime ) / 60 ))
      else
        age=999999
      fi
      reason_suffix=" (missing/unparseable holder.json; age is the .lock directory's own mtime)"
    fi

    if [ "$age" -gt "$TASK_LOCK_REAP_MIN" ]; then
      # Pid-liveness floor, mirroring the session-registry side's dead-pid check: a lock whose
      # recorded holder pid is confirmably still alive is never reaped on timestamp age alone,
      # in EITHER --dry-run or real mode -- this is a refusal to act on a bad timestamp, not a
      # cosmetic dry-run distinction. A holder with no pid field (legacy holder.json, or the
      # missing/unparseable-holder.json fallback branch above, which never populates holder_pid)
      # or an unresolvable/non-numeric pid falls through unchanged to today's timestamp-only
      # reap behavior below.
      if [[ "$holder_pid" =~ ^[0-9]+$ ]] && kill -0 "$holder_pid" 2>/dev/null; then
        echo "SKIP: $lock_dir task=$task_number session=$session_id operation=$operation age_min=$age never_heartbeated=$never_hb (holder pid $holder_pid is alive; refusing to reap a live process's lock)"
        continue
      fi
      reaped_count=$(( reaped_count + 1 ))
      if [ "$dry_run" = true ]; then
        echo "would reap: $lock_dir task=$task_number session=$session_id operation=$operation age_min=$age never_heartbeated=$never_hb${reason_suffix}"
      else
        rm -rf "$lock_dir" 2>/dev/null || true
        echo "reaped: $lock_dir task=$task_number session=$session_id operation=$operation age_min=$age never_heartbeated=$never_hb${reason_suffix}"
      fi
    elif [ -n "$reason_suffix" ]; then
      # Corrupt/missing holder.json but not yet stale by directory mtime: report and
      # leave in place. A normal fresh lock (valid holder.json, age within threshold)
      # is silent here -- it is not reap-relevant and does not belong in the output.
      echo "SKIP: $lock_dir age_min=$age never_heartbeated=$never_hb (below ${TASK_LOCK_REAP_MIN}min reap threshold)${reason_suffix}"
    fi
  done < <(find "$PROJECT_ROOT/specs" -mindepth 2 -maxdepth 3 -type d -name ".lock" 2>/dev/null)

  if [ "$reaped_count" -eq 0 ]; then
    echo "no stale locks found (${total_count} lock(s) scanned, threshold ${TASK_LOCK_REAP_MIN}min)"
  elif [ "$dry_run" = true ]; then
    echo "would reap ${reaped_count} of ${total_count} lock(s) (threshold ${TASK_LOCK_REAP_MIN}min)"
  else
    echo "reaped ${reaped_count} of ${total_count} lock(s) (threshold ${TASK_LOCK_REAP_MIN}min)"
  fi

  return 0
}

# =====================================================================
# scope-acquire <session_id> [stale_sec]
# =====================================================================
# Standalone CLI exposure of acquire_scope_mutex for cross-process critical sections (see the
# top-of-file usage comment and .claude/context/patterns/task-lock.md for the full contract).
# Deliberately does NOT install a `trap ... RETURN` -- unlike cmd_acquire's task-scoped lock
# (which lives and dies within one function call), this mutex is meant to outlive this process:
# the caller holds the printed token across other commands and releases it explicitly (or via its
# own EXIT trap) with a separate `scope-release` invocation.
cmd_scope_acquire() {
  local session_id="$1" stale_sec="${2:-}"
  local mutex_dir="$PROJECT_ROOT/specs/.scope-lock"

  if ! acquire_scope_mutex "$stale_sec"; then
    local holder_session holder_pid
    holder_session=$(jq -r '.session_id // empty' "$mutex_dir/owner" 2>/dev/null) || true
    holder_pid=$(jq -r '.pid // empty' "$mutex_dir/owner" 2>/dev/null) || true
    echo "ERROR: timed out waiting for specs/.scope-lock mutex (session=$session_id); current holder: session=${holder_session:-unknown} pid=${holder_pid:-unknown}." >&2
    return 2
  fi

  local pid claimed_epoch token
  pid=$$
  claimed_epoch=$(now_epoch)
  token="${session_id}:${pid}:${claimed_epoch}"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --argjson claimed_epoch "$claimed_epoch" \
    --arg token "$token" \
    '{session_id: $session_id, pid: $pid, claimed_epoch: $claimed_epoch, token: $token}' \
    > "$mutex_dir/owner" 2>/dev/null || true

  echo "$token"
  return 0
}

# =====================================================================
# scope-release <token>
# =====================================================================
# Owner-token-verified release: because acquire and release are separate processes here (unlike
# acquire_scope_mutex's in-function usage), an unconditional rm -rf would be unsafe if
# this holder was stale-reclaimed and a successor already re-acquired -- this release would then
# delete the SUCCESSOR's mutex. A token mismatch is therefore a loud, non-silent WARNING (it means
# the critical section overran its declared stale_sec and a concurrent writer may have
# interleaved), never a forced removal. Release is best-effort and always exits 0 -- it must never
# fail a caller's cleanup path.
cmd_scope_release() {
  local token="$1"
  local mutex_dir="$PROJECT_ROOT/specs/.scope-lock"

  if [ ! -d "$mutex_dir" ]; then
    echo "WARN: scope-release (token=$token) found no specs/.scope-lock mutex -- already released or never held." >&2
    return 0
  fi

  local owner_token
  owner_token=$(jq -r '.token // empty' "$mutex_dir/owner" 2>/dev/null) || true

  if [ "$owner_token" != "$token" ]; then
    echo "WARN: scope-release token mismatch (given=$token current-holder=${owner_token:-unknown}); NOT releasing. This means the critical section overran its declared staleness window and a concurrent writer may have reclaimed the mutex -- investigate rather than ignore." >&2
    return 0
  fi

  release_scope_mutex
  return 0
}

# =====================================================================
# commit-acquire <session_id> [stale_sec]
# =====================================================================
# Standalone CLI exposure of acquire_commit_mutex, mirroring cmd_scope_acquire exactly (same
# owner-token format, same owner-file write, same no-trap-of-its-own contract -- the caller is
# responsible for release on every exit path, per .claude/context/patterns/task-lock.md). Serves
# a DISTINCT mutex (specs/.commit-lock/) from cmd_scope_acquire's specs/.scope-lock/.
cmd_commit_acquire() {
  local session_id="$1" stale_sec="${2:-}"
  local mutex_dir="$PROJECT_ROOT/specs/.commit-lock"

  if ! acquire_commit_mutex "$stale_sec"; then
    local holder_session holder_pid
    holder_session=$(jq -r '.session_id // empty' "$mutex_dir/owner" 2>/dev/null) || true
    holder_pid=$(jq -r '.pid // empty' "$mutex_dir/owner" 2>/dev/null) || true
    echo "ERROR: timed out waiting for specs/.commit-lock mutex (session=$session_id); current holder: session=${holder_session:-unknown} pid=${holder_pid:-unknown}." >&2
    return 2
  fi

  local pid claimed_epoch token
  pid=$$
  claimed_epoch=$(now_epoch)
  token="${session_id}:${pid}:${claimed_epoch}"

  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --argjson claimed_epoch "$claimed_epoch" \
    --arg token "$token" \
    '{session_id: $session_id, pid: $pid, claimed_epoch: $claimed_epoch, token: $token}' \
    > "$mutex_dir/owner" 2>/dev/null || true

  echo "$token"
  return 0
}

# =====================================================================
# commit-release <token>
# =====================================================================
# Owner-token-verified release, mirroring cmd_scope_release exactly. See that function's comment
# for the full rationale (a stale-reclaimed holder's release must never delete a successor's
# mutex). Always exits 0 -- release is best-effort and must never fail a caller's cleanup path.
cmd_commit_release() {
  local token="$1"
  local mutex_dir="$PROJECT_ROOT/specs/.commit-lock"

  if [ ! -d "$mutex_dir" ]; then
    echo "WARN: commit-release (token=$token) found no specs/.commit-lock mutex -- already released or never held." >&2
    return 0
  fi

  local owner_token
  owner_token=$(jq -r '.token // empty' "$mutex_dir/owner" 2>/dev/null) || true

  if [ "$owner_token" != "$token" ]; then
    echo "WARN: commit-release token mismatch (given=$token current-holder=${owner_token:-unknown}); NOT releasing. This means the critical section overran its declared staleness window and a concurrent writer may have reclaimed the mutex -- investigate rather than ignore." >&2
    return 0
  fi

  release_commit_mutex
  return 0
}

# =====================================================================
# claim-acquire <path> <task_number> <session_id> [stale_sec]
# claim-release <path> <task_number>
# =====================================================================
# First-claim lease for git-commit-scoped.sh's contended-path refusal (working-tree/build
# isolation posture decision record, Option 3(ii): "keep the shared tree but refuse to commit a
# hunk in a path the committing task does not own"). ONE mutex directory PER declared manifest
# path (specs/.contention-claims/<sanitized-path>), reusing acquire_named_mutex's exact
# mkdir/staleness pattern above rather than inventing a new primitive -- the only difference from
# commit-acquire/scope-acquire is a PER-PATH directory name instead of one fixed directory, and a
# ZERO wait budget: this call never blocks or retries. A path already held by ANOTHER live task
# must be refused to the caller immediately, so ITS OWN caller (git-commit-scoped.sh) can decide
# to defer -- never to wait it out or force it.
CONTENTION_CLAIM_STALE_SEC=1800

_contention_claim_dirname() {
  # Sanitizes a declared manifest path into a single-level directory name safe to resolve
  # directly under specs/.contention-claims/ (acquire_named_mutex does one bare `mkdir`, not
  # `mkdir -p`, so a name containing "/" would require pre-existing parents). "/" -> "_"; a
  # collision between two DIFFERENT declared paths that only differ by this substitution is
  # accepted as a rare, self-correcting false-positive claim (the lease clears within
  # CONTENTION_CLAIM_STALE_SEC as soon as its wider owner releases or times out) rather than
  # something worth a heavier collision-proof encoding for.
  printf '%s' "$1" | tr '/' '_'
}

cmd_claim_acquire() {
  local path="$1" task_number="$2" session_id="$3" stale_sec="${4:-}"
  local claim_name
  claim_name=".contention-claims/$(_contention_claim_dirname "$path")"
  local mutex_dir="$PROJECT_ROOT/specs/${claim_name}"

  # acquire_named_mutex's own `mkdir "$mutex_dir"` is NOT `mkdir -p` -- the parent
  # specs/.contention-claims/ must already exist, or every acquire attempt fails closed (looking
  # identical to "held by someone else"). Ensure it once, here, rather than at every call site.
  mkdir -p "$PROJECT_ROOT/specs/.contention-claims" 2>/dev/null || true

  if acquire_named_mutex "$claim_name" "$stale_sec" "$CONTENTION_CLAIM_STALE_SEC" 0; then
    jq -n --argjson t "$task_number" --arg s "$session_id" --arg p "$path" \
      '{task: $t, session_id: $s, path: $p}' > "$mutex_dir/holder.json" 2>/dev/null || true
    jq -n -c --arg status "claimed" --arg path "$path" '{status: $status, path: $path}'
    return 0
  fi

  # Acquire failed (directory already exists and is not stale): re-entrant when the EXISTING
  # holder's own task_number matches this caller's -- treat as success, never self-block.
  local holder_task holder_session
  holder_task=$(jq -r '.task // empty' "$mutex_dir/holder.json" 2>/dev/null) || holder_task=""
  holder_session=$(jq -r '.session_id // empty' "$mutex_dir/holder.json" 2>/dev/null) || holder_session=""

  if [ -n "$holder_task" ] && [ "$holder_task" = "$task_number" ]; then
    jq -n -c --arg status "already_self" --arg path "$path" '{status: $status, path: $path}'
    return 0
  fi

  jq -n -c --arg status "held" --arg path "$path" \
    --arg ht "$holder_task" --arg hs "$holder_session" \
    '{status: $status, path: $path,
      holder_task: (if $ht == "" then null else ($ht | tonumber) end),
      holder_session: (if $hs == "" then null else $hs end)}'
  return 1
}

# Best-effort, task-verified release (mirrors cmd_commit_release's token-verification rationale:
# never delete a claim a stale-timeout reclaim has already handed to a different task). Always
# exits 0 -- release must never fail a caller's cleanup path.
cmd_claim_release() {
  local path="$1" task_number="${2:-}"
  local claim_name
  claim_name=".contention-claims/$(_contention_claim_dirname "$path")"
  local mutex_dir="$PROJECT_ROOT/specs/${claim_name}"

  if [ ! -d "$mutex_dir" ]; then
    return 0
  fi

  local holder_task
  holder_task=$(jq -r '.task // empty' "$mutex_dir/holder.json" 2>/dev/null) || holder_task=""

  if [ -n "$task_number" ] && [ -n "$holder_task" ] && [ "$holder_task" != "$task_number" ]; then
    echo "WARN: claim-release (path=$path, task=$task_number) found holder task=$holder_task -- NOT releasing (claim was reclaimed by a different task, likely a stale-timeout race)." >&2
    return 0
  fi

  release_named_mutex "$claim_name"
  return 0
}

# =====================================================================
# init-marker <file_path>
# =====================================================================
# Generic atomic-on-creation primitive for marker/state files that were using a
# TOCTOU-prone "check-then-create" `if [ -f X ]; then resume; else jq -n ... > X; fi`
# pattern (e.g. .orchestrator-loop-guard, .orchestrator-churn-state.json). Reuses
# this script's existing exclusivity idiom — an atomic `mkdir` gate plus a
# tmp-file-`mv` payload write, mirroring `write_holder` above — but claims a
# `${file_path}.init` directory, which is entirely distinct from the task-number
# `.lock/` directory used by acquire/heartbeat/release/check. init-marker is
# file-granularity and composes independently of the task-number lock: it does
# not read, call, or modify cmd_acquire, write_holder, or `.lock/` in any way.
cmd_init_marker() {
  local file_path="$1"
  local init_dir="${file_path}.init"
  local tmp_file="${file_path}.tmp"
  local attempt recheck

  for attempt in 1 2; do
    if mkdir "$init_dir" 2>/dev/null; then
      # Won the exclusivity claim: write stdin payload via tmp-file + mv
      # (atomic replace), then release the claim directory.
      cat > "$tmp_file" || true
      if [ ! -s "$tmp_file" ]; then
        echo "ERROR: init-marker failed to write $file_path (stdin produced empty output)" >&2
        rm -f "$tmp_file"
        rmdir "$init_dir" 2>/dev/null || true
        return 2
      fi
      mv "$tmp_file" "$file_path"
      rmdir "$init_dir" 2>/dev/null || true
      return 0
    fi

    # mkdir failed: another process holds (or held) the init claim. Before
    # concluding the claim is orphaned, do a bounded recheck (poll briefly)
    # for the winner's payload to appear — this distinguishes "actively being
    # written by a live racer" (expected under concurrency) from "abandoned by
    # a crashed initializer" (the only case that should trigger self-heal).
    for recheck in 1 2 3 4 5 6 7 8 9 10; do
      if [ -f "$file_path" ] && jq empty "$file_path" >/dev/null 2>&1; then
        return 1
      fi
      [ -d "$init_dir" ] || break
      sleep 0.05
    done

    if [ -f "$file_path" ] && jq empty "$file_path" >/dev/null 2>&1; then
      return 1
    fi

    if [ "$attempt" -eq 1 ]; then
      # Still absent/corrupt after the bounded recheck: a crashed initializer
      # left an orphaned claim. Self-heal (never silent, never permanent):
      # warn, remove the stale claim, retry the mkdir once.
      echo "WARN: init-marker found a stale claim ($init_dir) with no valid $file_path after recheck; self-healing and retrying." >&2
      rmdir "$init_dir" 2>/dev/null || true
      continue
    fi
  done

  echo "ERROR: init-marker failed to create $file_path after retry" >&2
  return 2
}

# =====================================================================
# session-register <session_id> <command> <task_numbers_csv> [--pid N]
# =====================================================================
# Upsert semantics: if an entry for this session_id already exists and parses, preserve its
# started_at and refresh heartbeat_at only -- mirroring cmd_acquire's same-session re-entry safety
# property. file_scope is the deduplicated UNION across every task in task_numbers_csv, computed
# internally via get_file_scope -- callers never construct the union themselves.
cmd_session_register() {
  local session_id="$1" command="$2" task_numbers_csv="$3"
  shift 3 || true
  local explicit_pid=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --pid)
        explicit_pid="$2"
        shift 2
        ;;
      *)
        echo "Usage: $0 session-register <session_id> <command> <task_numbers_csv> [--pid N]" >&2
        return 2
        ;;
    esac
  done

  local sessions_dir
  sessions_dir=$(session_registry_dir "true")

  local task_numbers_json
  task_numbers_json=$(echo "$task_numbers_csv" | jq -R -c 'split(",") | map(select(length > 0) | tonumber)' 2>/dev/null) || true
  if [ -z "$task_numbers_json" ]; then
    echo "ERROR: session-register could not parse task_numbers_csv \"$task_numbers_csv\" as a CSV of integers" >&2
    return 2
  fi

  local scopes_tmp
  scopes_tmp=$(mktemp) || { echo "ERROR: session-register could not create a temp file" >&2; return 2; }
  echo "$task_numbers_json" | jq -c '.[]' 2>/dev/null | while IFS= read -r tn; do
    get_file_scope "$tn"
  done > "$scopes_tmp" || true
  local file_scope_json
  file_scope_json=$(jq -s -c 'add | unique' "$scopes_tmp" 2>/dev/null) || true
  rm -f "$scopes_tmp"
  [ -n "$file_scope_json" ] && [ "$file_scope_json" != "null" ] || file_scope_json="[]"

  local pid pid_source
  read -r pid pid_source <<< "$(resolve_session_pid ${explicit_pid:+--pid "$explicit_pid"})"

  local started_at="$(iso_now)" heartbeat_at="$(iso_now)"
  local existing="$sessions_dir/${session_id}.json"
  if [ -f "$existing" ] && jq -e . "$existing" >/dev/null 2>&1; then
    local prior_started
    prior_started=$(jq -r '.started_at // empty' "$existing" 2>/dev/null) || true
    [ -n "$prior_started" ] && started_at="$prior_started" || true
  fi

  write_session_entry "$sessions_dir" "$session_id" "$pid" "$pid_source" "$command" "$task_numbers_json" "$file_scope_json" "$started_at" "$heartbeat_at" || return 2
  return 0
}

# =====================================================================
# session-heartbeat <session_id>
# =====================================================================
# Refreshes heartbeat_at only. Mirrors cmd_heartbeat's contract exactly: a missing or
# unparseable entry is a stderr warning and exit 0, never a block on the caller.
cmd_session_heartbeat() {
  local session_id="$1"
  local sessions_dir target
  sessions_dir=$(session_registry_dir "false")
  target="$sessions_dir/${session_id}.json"

  if [ ! -f "$target" ] || ! jq -e . "$target" >/dev/null 2>&1; then
    echo "WARN: session-heartbeat no-op — no registry entry for session $session_id." >&2
    return 0
  fi

  local pid pid_source command task_numbers_json file_scope_json started_at
  pid=$(jq -r '.pid // empty' "$target" 2>/dev/null) || true
  pid_source=$(jq -r '.pid_source // empty' "$target" 2>/dev/null) || true
  command=$(jq -r '.command // empty' "$target" 2>/dev/null) || true
  task_numbers_json=$(jq -c '.task_numbers // []' "$target" 2>/dev/null) || true
  file_scope_json=$(jq -c '.file_scope // []' "$target" 2>/dev/null) || true
  started_at=$(jq -r '.started_at // empty' "$target" 2>/dev/null) || true
  [ -n "$pid" ] || pid=0

  write_session_entry "$sessions_dir" "$session_id" "$pid" "$pid_source" "$command" "$task_numbers_json" "$file_scope_json" "$started_at" "$(iso_now)" || return 2
  return 0
}

# =====================================================================
# session-release <session_id>
# =====================================================================
# rm -f the entry; idempotent, always exit 0, mirroring cmd_release.
cmd_session_release() {
  local session_id="$1"
  local sessions_dir
  sessions_dir=$(session_registry_dir "false")
  rm -f "$sessions_dir/${session_id}.json" 2>/dev/null || true
  return 0
}

# =====================================================================
# session_liveness <entry_file_path>
# =====================================================================
# Two-signal liveness computation, factored out of cmd_session_reap so cmd_session_list and (in
# a later phase) session_contention() consume the IDENTICAL verdict rather than a second
# transcription. Preserves cmd_session_reap's original evaluation ORDER (dead-pid tested first,
# stale-heartbeat as the eventual fallback) and both thresholds (SESSION_REGISTRY_DEAD_PID_MIN,
# SESSION_REGISTRY_REAP_MIN) byte-for-byte.
#
# Prints "<age_minutes> <liveness_reason>" on stdout (space-separated, exactly two tokens).
# liveness_reason is one of:
#   corrupt                 - entry file is missing/unparseable JSON. age falls back to the
#                              file's own mtime. Checked FIRST and short-circuits the other five
#                              -- a corrupt entry's pid/heartbeat fields cannot be trusted at all.
#   dead-pid                - pid is a parseable integer, `kill -0 $pid` FAILS (pid confirmably
#                              gone), AND age > SESSION_REGISTRY_DEAD_PID_MIN.
#   dead-pid-within-grace   - pid is a parseable integer, `kill -0 $pid` FAILS (pid confirmably
#                              gone), but age does NOT exceed SESSION_REGISTRY_DEAD_PID_MIN -- the
#                              grace floor holds the verdict at live:true, but the reason no
#                              longer claims the process is alive.
#   stale-heartbeat  - not dead-pid, and age > SESSION_REGISTRY_REAP_MIN. "pid alive" is NEVER
#                       treated as proof of liveness on its own; this band is always the
#                       fallback regardless of pid state.
#   pid-alive        - not dead-pid, not dead-pid-within-grace, not stale-heartbeat, and pid is a
#                       parseable integer for which `kill -0` succeeded.
#   undeterminable   - not dead-pid, not dead-pid-within-grace, not stale-heartbeat, and pid is
#                       empty/non-numeric (liveness cannot be confirmed either way from the pid
#                       signal alone).
session_liveness() {
  local f="$1"
  local pid age reason="" pid_dead=false

  if ! jq -e . "$f" >/dev/null 2>&1; then
    local file_mtime
    file_mtime=$(stat -c %Y "$f" 2>/dev/null || stat -f %m "$f" 2>/dev/null) || true
    if [ -n "$file_mtime" ]; then
      age=$(( ( $(now_epoch) - file_mtime ) / 60 ))
    else
      age=999999
    fi
    echo "$age corrupt"
    return 0
  fi

  pid=$(jq -r '.pid // empty' "$f" 2>/dev/null) || true
  age=$(age_minutes "$(jq -r '.heartbeat_at // empty' "$f" 2>/dev/null)")

  if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
    if ! kill -0 "$pid" 2>/dev/null; then
      pid_dead=true
      if [ "$age" -gt "$SESSION_REGISTRY_DEAD_PID_MIN" ]; then
        reason="dead-pid"
      fi
    fi
  fi

  if [ -z "$reason" ] && [ "$age" -gt "$SESSION_REGISTRY_REAP_MIN" ]; then
    reason="stale-heartbeat"
  fi

  if [ -z "$reason" ]; then
    if [ "$pid_dead" = true ]; then
      reason="dead-pid-within-grace"
    elif [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
      reason="pid-alive"
    else
      reason="undeterminable"
    fi
  fi

  echo "$age $reason"
}

# =====================================================================
# session-reap [--dry-run]
# =====================================================================
# Mirrors cmd_reap's report-then-delete shape and its "skip corrupt/unreadable entry rather than
# silently ignore" discipline. Reap fires on liveness_reason == dead-pid or stale-heartbeat, per
# session_liveness() above. A corrupt entry has no usable pid (dead-pid can never fire for it) so
# it reaps only via the SAME stale-heartbeat threshold applied to its file-mtime-derived age --
# byte-for-byte the same reap/no-reap decision and message text this command produced before the
# session_liveness() extraction. Always exits 0.
cmd_session_reap() {
  local dry_run=false
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        echo "Usage: $0 session-reap [--dry-run]" >&2
        return 2
        ;;
    esac
  done

  local sessions_dir
  sessions_dir=$(session_registry_dir "false")

  local f total_count=0 reaped_count=0
  if [ -d "$sessions_dir" ]; then
    for f in "$sessions_dir"/*.json; do
      [ -e "$f" ] || continue
      total_count=$(( total_count + 1 ))

      local session_id command task_numbers_csv age liveness live_out reason_suffix=""
      live_out=$(session_liveness "$f")
      age="${live_out%% *}"
      liveness="${live_out#* }"

      if [ "$liveness" = "corrupt" ]; then
        session_id="unknown"
        command="unknown"
        task_numbers_csv="unknown"
        reason_suffix=" (missing/unparseable entry; age is the file's own mtime)"
      else
        session_id=$(jq -r '.session_id // empty' "$f" 2>/dev/null) || true
        command=$(jq -r '.command // empty' "$f" 2>/dev/null) || true
        task_numbers_csv=$(jq -r '.task_numbers // [] | join(",")' "$f" 2>/dev/null) || true
      fi

      local reason=""
      case "$liveness" in
        dead-pid|stale-heartbeat)
          reason="$liveness"
          ;;
        corrupt)
          # No pid signal at all for a corrupt entry (dead-pid can never fire); reap only when
          # old enough by the SAME threshold this fallback path always used (mtime age vs.
          # SESSION_REGISTRY_REAP_MIN), reported as stale-heartbeat exactly as before.
          if [ "$age" -gt "$SESSION_REGISTRY_REAP_MIN" ]; then
            reason="stale-heartbeat"
          fi
          ;;
        *)
          reason=""
          ;;
      esac

      if [ -n "$reason" ]; then
        reaped_count=$(( reaped_count + 1 ))
        if [ "$dry_run" = true ]; then
          echo "would reap: specs/.sessions/$(basename "$f") session=$session_id command=$command tasks=$task_numbers_csv age_min=$age reason=$reason${reason_suffix}"
        else
          rm -f "$f" 2>/dev/null || true
          echo "reaped: specs/.sessions/$(basename "$f") session=$session_id command=$command tasks=$task_numbers_csv age_min=$age reason=$reason${reason_suffix}"
        fi
      elif [ -n "$reason_suffix" ]; then
        echo "SKIP: specs/.sessions/$(basename "$f") age_min=$age (below reap thresholds)${reason_suffix}"
      fi
    done
  fi

  if [ "$reaped_count" -eq 0 ]; then
    echo "no stale session registry entries found (${total_count} scanned, thresholds dead-pid=${SESSION_REGISTRY_DEAD_PID_MIN}min stale-heartbeat=${SESSION_REGISTRY_REAP_MIN}min)"
  elif [ "$dry_run" = true ]; then
    echo "would reap ${reaped_count} of ${total_count} session registry entries"
  else
    echo "reaped ${reaped_count} of ${total_count} session registry entries"
  fi

  return 0
}

# =====================================================================
# session-list
# =====================================================================
# Read-only enumeration of specs/.sessions/*.json -- a bounded, dedicated-directory glob, never a
# repo-wide scan. This is the session registry's first (and, per
# context/patterns/task-lock.md's Session-Registry Reader Contract, so far ONLY) reader. Emits
# one compact NDJSON line per entry: every raw entry field verbatim, plus computed `live` (bool)
# and `liveness_reason` (string) from session_liveness() above. No mutation, no --dry-run flag --
# nothing here is ever deleted.
#
# `live` is derived uniformly from liveness_reason: false for dead-pid/stale-heartbeat (confirmed
# or presumed gone), true for every other reason (pid-alive, dead-pid-within-grace, undeterminable,
# AND corrupt) -- this fails toward "still contending", never toward silently treating an
# unconfirmable session as gone. A corrupt/unparseable entry is emitted with liveness_reason:
# "corrupt", live: true, and an empty file_scope/task_numbers (nothing can be safely read from
# it) -- never silently dropped from the stream.
cmd_session_list() {
  if [ "$#" -gt 0 ]; then
    echo "Usage: $0 session-list" >&2
    return 2
  fi

  local sessions_dir
  sessions_dir=$(session_registry_dir "false")

  local f
  if [ -d "$sessions_dir" ]; then
    for f in "$sessions_dir"/*.json; do
      [ -e "$f" ] || continue

      local live_out age liveness live_flag
      live_out=$(session_liveness "$f")
      age="${live_out%% *}"
      liveness="${live_out#* }"
      case "$liveness" in
        dead-pid|stale-heartbeat) live_flag="false" ;;
        *) live_flag="true" ;;
      esac

      if [ "$liveness" = "corrupt" ]; then
        jq -n -c \
          --arg entry_file "$(basename "$f")" \
          --argjson live "$live_flag" \
          --arg liveness_reason "$liveness" \
          --argjson age_min "$age" \
          '{entry_file: $entry_file, session_id: null, pid: null, pid_source: null,
            command: null, task_numbers: [], file_scope: [], started_at: null,
            heartbeat_at: null, age_min: $age_min, live: $live, liveness_reason: $liveness_reason}'
      else
        jq -c \
          --argjson live "$live_flag" \
          --arg liveness_reason "$liveness" \
          --argjson age_min "$age" \
          '. + {age_min: $age_min, live: $live, liveness_reason: $liveness_reason}' \
          "$f" 2>/dev/null
      fi
    done
  fi

  return 0
}

# =====================================================================
# Dispatch
# =====================================================================
SUBCMD="${1:-}"
shift || true

case "$SUBCMD" in
  acquire)
    if [ "$#" -lt 3 ]; then
      echo "Usage: $0 acquire <task_number> <operation> <session_id> [command]" >&2
      exit 2
    fi
    cmd_acquire "$@"
    exit $?
    ;;
  acquire-retry)
    if [ "$#" -lt 3 ]; then
      echo "Usage: $0 acquire-retry <task_number> <operation> <session_id> [command]" >&2
      exit 2
    fi
    cmd_acquire_retry "$@"
    exit $?
    ;;
  heartbeat)
    if [ "$#" -lt 2 ]; then
      echo "Usage: $0 heartbeat <task_number> <session_id>" >&2
      exit 2
    fi
    cmd_heartbeat "$@"
    exit $?
    ;;
  release)
    if [ "$#" -lt 2 ]; then
      echo "Usage: $0 release <task_number> <session_id>" >&2
      exit 2
    fi
    cmd_release "$@"
    exit $?
    ;;
  check)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 check <task_number>" >&2
      exit 3
    fi
    cmd_check "$@"
    exit $?
    ;;
  reap)
    cmd_reap "$@"
    exit $?
    ;;
  init-marker)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 init-marker <file_path>" >&2
      exit 2
    fi
    cmd_init_marker "$@"
    exit $?
    ;;
  scope-acquire)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 scope-acquire <session_id> [stale_sec]" >&2
      exit 2
    fi
    cmd_scope_acquire "$@"
    exit $?
    ;;
  scope-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 scope-release <token>" >&2
      exit 2
    fi
    cmd_scope_release "$@"
    exit $?
    ;;
  commit-acquire)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 commit-acquire <session_id> [stale_sec]" >&2
      exit 2
    fi
    cmd_commit_acquire "$@"
    exit $?
    ;;
  commit-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 commit-release <token>" >&2
      exit 2
    fi
    cmd_commit_release "$@"
    exit $?
    ;;
  claim-acquire)
    if [ "$#" -lt 3 ]; then
      echo "Usage: $0 claim-acquire <path> <task_number> <session_id> [stale_sec]" >&2
      exit 2
    fi
    cmd_claim_acquire "$@"
    exit $?
    ;;
  claim-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 claim-release <path> [task_number]" >&2
      exit 2
    fi
    cmd_claim_release "$@"
    exit $?
    ;;
  session-register)
    if [ "$#" -lt 3 ]; then
      echo "Usage: $0 session-register <session_id> <command> <task_numbers_csv> [--pid N]" >&2
      exit 2
    fi
    cmd_session_register "$@"
    exit $?
    ;;
  session-heartbeat)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 session-heartbeat <session_id>" >&2
      exit 2
    fi
    cmd_session_heartbeat "$@"
    exit $?
    ;;
  session-release)
    if [ "$#" -lt 1 ]; then
      echo "Usage: $0 session-release <session_id>" >&2
      exit 2
    fi
    cmd_session_release "$@"
    exit $?
    ;;
  session-reap)
    cmd_session_reap "$@"
    exit $?
    ;;
  session-list)
    cmd_session_list "$@"
    exit $?
    ;;
  *)
    echo "Usage: $0 {acquire|acquire-retry|heartbeat|release|check|reap|init-marker|scope-acquire|scope-release|commit-acquire|commit-release|claim-acquire|claim-release|session-register|session-heartbeat|session-release|session-reap|session-list} ..." >&2
    exit 2
    ;;
esac
