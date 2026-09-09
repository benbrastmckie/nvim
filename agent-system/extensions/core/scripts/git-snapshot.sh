#!/usr/bin/env bash
# git-snapshot.sh
# Sanctioned snapshot helper for agent git-safety: preserve uncommitted work.
#
# Purpose: write a recoverable, durable snapshot of uncommitted working-tree changes
# BEFORE any destructive git operation (git reset --hard, git checkout -- <path>,
# git restore <path>, git clean -fd, git stash drop/clear, forced checkout/switch),
# and refresh a short-lived freshness marker that guard-destructive-git.sh (the
# PreToolUse Bash hook) checks to decide whether to allow the destructive command.
#
# --- Marker contract (read by .claude/hooks/guard-destructive-git.sh) ---
#   Filename: .git-snapshot-marker
#   Location: task-scoped, written under the resolved task directory
#             (specs/{NNN}_{SLUG}/.git-snapshot-marker)
#   Format:   line-oriented KEY=VALUE, always contains at minimum:
#               TIMESTAMP=<epoch seconds when the snapshot was taken>
#               HEAD_SHA=<git rev-parse HEAD at snapshot time>
#               PATCH_PATH=<path to the durable .patch file, or NONE>
#             plus (best-effort, mode-dependent):
#               STASH_REF=<stash@{N} ref, or NONE>
#               BRANCH_NAME=<wip-snapshot-{ts} branch name, or NONE>
#               UNTRACKED_BACKUP=<untracked-backup-{ts} dir, or NONE>
#   Freshness window: 120 seconds. The hook treats a marker older than this window
#             as stale and will NOT honor it (a stale marker does not authorize a
#             later, unrelated destructive command).
#   Consumption: single-shot / delete-on-use. The guard hook deletes the marker file
#             the first time it is consumed to authorize a destructive command, so a
#             fresh snapshot only ever unblocks the ONE destructive command it was
#             taken for.
#   Ignored:  the marker filename is gitignored (**/.git-snapshot-marker); the
#             durable working-progress-*.patch file is NOT gitignored and remains
#             tracked under the task directory for manual recovery if needed.
#
# --- Usage ---
#   git-snapshot.sh [--branch | --no-revert] [--allow-out-of-scope] [TASK]
#     TASK          Task number (an integer), a specs/{NNN}_{SLUG} directory path, or
#                   omitted to infer the task from specs/state.json (see TASK inference).
#     --branch      Instead of the default stash-based snapshot, create a WIP commit
#                   on a scratch branch (wip-snapshot-{ts}) capturing the dirty tree,
#                   then return to the original branch.
#     --no-revert   Take the snapshot WITHOUT mutating the working tree (see modes).
#     --allow-out-of-scope
#                   Override the out-of-scope refusal guard below. Independent of the
#                   three modes; combinable with either.
#     --help, -h    Print the usage summary and exit 0.
#   --branch and --no-revert are mutually exclusive with each other; passing both is an
#   error. --allow-out-of-scope is a separate boolean and does not count toward that
#   mutual-exclusion check.
#
# --- WARNING: default and --branch modes REVERT the working tree ---
#   Despite the name, this script is NOT read-only in its default or --branch modes.
#   Both leave the working tree CLEAN at HEAD: uncommitted edits are removed from the
#   working directory (still recoverable, but no longer present).
#     default mode  runs `git stash push -u`, which reverts modified tracked files and
#                   removes untracked ones.
#     --branch mode commits the dirty tree onto a scratch branch and then checks out the
#                   original branch, which reverts the tree exactly as much as the stash
#                   path does. --branch changes only the RECOVERY HANDLE (a branch instead
#                   of a stash entry) -- it does NOT avoid the revert.
#   Use --no-revert when you want a durable backup and intend to KEEP WORKING. Use the
#   default (or --branch) when the snapshot is a precursor to an already-decided
#   destructive git command, where a clean tree is the intended handoff.
#
# --- Out-of-scope refusal guard (default and --branch modes only) ---
#   Before reverting anything, these two modes classify every dirty TRACKED path
#   against the resolved task's declared file_scope in specs/state.json (via the
#   canonical path_covered_by_scope() predicate in lib/file-scope-overlap.sh -- see
#   context/patterns/file-footprint-overlap.md's "Containment vs. Overlap" section).
#   If any dirty tracked path falls outside that scope, the script REFUSES -- naming
#   every offending path -- rather than sweeping unrelated work away, and mutates
#   NOTHING (no patch, no stash, no marker, no branch). This is fail-closed: it also
#   refuses when the task has no declared (or empty) file_scope, when
#   specs/state.json is missing, or when `jq` is unavailable -- in each case the
#   script cannot tell task work apart from unrelated work, which is the exact
#   condition that caused this guard to be written. Pass --allow-out-of-scope for the
#   deliberate whole-tree case (the guard's refusal message names this flag). Dirty
#   UNTRACKED paths outside scope are WARNED about on stderr, never refusal-triggering
#   (see D3 in the implementation for why). --no-revert is NEVER guarded: it reverts
#   nothing, so it has nothing to destroy.
#
#   Default mode: writes specs/{NNN}_{SLUG}/working-progress-{ts}.patch (git diff HEAD)
#   AND runs `git stash push -u -m git-snapshot-{task}-{ts}` (untracked-inclusive, without
#   drop) as a belt-and-suspenders in-repo copy. Both the patch and the marker are written
#   before the script exits successfully. THE WORKING TREE IS REVERTED.
#
#   --no-revert mode: writes the same working-progress-{ts}.patch, records a real stash
#   entry via `git stash create git-snapshot-{task}-{ts}` + `git stash store` (which build
#   and store a stash commit object without ever touching the working tree), and copies
#   untracked files to specs/{NNN}_{SLUG}/untracked-backup-{ts}/ because a diff cannot
#   represent them. The working tree is left exactly as it was found. The freshness marker
#   is still written: the resulting snapshot is genuinely recoverable, but note that
#   because the tree stays dirty, a destructive command run afterwards discards the LIVE
#   edits and recovery must come from the patch / stash / untracked backup.
#
#   Stash identity: every stash entry this script creates (default and --no-revert alike)
#   is named git-snapshot-{task}-{ts}, where {task} is the owning task number (or
#   "unknown" if TASK_DIR's basename carries no leading digit run) -- so `git stash list`
#   lets an operator see which task produced each entry when judging which are safe to
#   drop. `STASH_REF` is parsed from `git stash list`'s ref column (`stash@{N}`), never
#   from this message, so the longer message does not affect that parsing.
#
#   TASK inference: with no TASK argument, the script reads specs/state.json and uses the
#   single task whose status is "implementing". Inference FAILS whenever that is not
#   exactly one task -- zero matches, two or more concurrent "implementing" tasks, no jq,
#   or no specs/state.json. Several tasks being in flight at once is normal here, so
#   passing TASK explicitly is the reliable form.
#
#   On a clean working tree, this script is a no-op: it prints a message and exits 0
#   without writing a marker (there is nothing to protect).
#
#   On any failure, this script exits non-zero with a clear message so the caller
#   (an agent about to run a destructive git command) does NOT proceed believing a
#   snapshot exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# This single relative path resolves to agent-system/extensions/core/scripts/lib/ in
# source-store mode and to .claude/scripts/lib/ in deployed mode, with no branching.
# Sourced via `if ! . file; then` (never a bare top-level `source`) because
# FILE_SCOPE_OVERLAP_JQ_DEFS is assigned with `read -r -d ''`, which always returns
# exit status 1 at EOF even on a fully successful read -- a bare `source` under this
# script's `set -e` would abort right there, before any function in the file is even
# defined. task-lock.sh's ensure_file_scope_overlap_lib() hits this identical gotcha
# and uses the same `if !` guard for the same reason.
# shellcheck source=lib/file-scope-overlap.sh
if ! . "$SCRIPT_DIR/lib/file-scope-overlap.sh" 2>/dev/null; then
  echo "git-snapshot.sh: could not source $SCRIPT_DIR/lib/file-scope-overlap.sh." >&2
  echo "  Source-store copy: agent-system/extensions/core/scripts/lib/file-scope-overlap.sh" >&2
  echo "  Remedy: regenerate via the picker's [Reload All]/[Regenerate] entries, or bash .claude/scripts/deploy-headless.sh." >&2
  exit 1
fi

MODE="default"
TASK_ARG=""
MODE_FLAG_COUNT=0
ALLOW_OUT_OF_SCOPE=0

print_usage() {
  cat << 'USAGE'
Usage: git-snapshot.sh [--branch | --no-revert] [--allow-out-of-scope] [TASK]

  TASK                 Task number (an integer), a specs/{NNN}_{SLUG} directory path, or
                        omitted to infer the single "implementing" task from
                        specs/state.json.
  --branch             Snapshot by committing the dirty tree to a scratch branch
                        (wip-snapshot-{ts}), then returning to the original branch.
  --no-revert          Snapshot WITHOUT mutating the working tree.
  --allow-out-of-scope Override the out-of-scope refusal guard below (default and
                        --branch modes only; --no-revert is never guarded).
  --help, -h           Print this usage and exit 0.

WARNING: the default and --branch modes BOTH revert the working tree.
  Default mode runs `git stash push -u`; --branch mode commits to a scratch branch and
  then checks out the original branch. Either way the tree ends up clean at HEAD and the
  uncommitted edits are no longer present in the working directory (they remain
  recoverable via the reported patch / stash / branch). --branch changes only the
  recovery handle -- it does NOT avoid the revert.
  Use --no-revert to take a durable backup and keep working.

OUT-OF-SCOPE REFUSAL GUARD: before reverting anything, default and --branch modes
  classify every dirty TRACKED path against the resolved task's declared file_scope in
  specs/state.json. If any dirty tracked path falls outside that scope, the script
  REFUSES (naming every offending path) rather than sweeping unrelated work away --
  and mutates nothing (no patch, no stash, no marker, no branch). This also fires,
  fail-closed, when the task has no declared file_scope, when specs/state.json is
  missing, or when 'jq' is unavailable, since the script then cannot tell task work
  apart from unrelated work. Pass --allow-out-of-scope for the deliberate whole-tree
  case. Dirty UNTRACKED out-of-scope paths are WARNED about (not refused) in reverting
  modes, since default mode's `-u` will delete them too but refusing on every untracked
  scratch/build artifact would make the guard fire on nearly every real tree.

--branch and --no-revert are mutually exclusive with each other; --allow-out-of-scope is
an independent flag and may be combined with either (or neither).
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --branch)
      MODE="branch"
      MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1))
      ;;
    --no-revert)
      MODE="no-revert"
      MODE_FLAG_COUNT=$((MODE_FLAG_COUNT + 1))
      ;;
    --allow-out-of-scope)
      ALLOW_OUT_OF_SCOPE=1
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    -*)
      echo "git-snapshot.sh: unrecognized option '$arg'" >&2
      print_usage >&2
      exit 1
      ;;
    *)
      TASK_ARG="$arg"
      ;;
  esac
done

if [ "$MODE_FLAG_COUNT" -gt 1 ]; then
  echo "git-snapshot.sh: --branch and --no-revert are mutually exclusive" >&2
  print_usage >&2
  exit 1
fi

# resolve_task_dir: turn a task number / path / empty arg into a specs/{NNN}_{SLUG} dir.
# On failure it echoes a specific reason to stderr and returns 1. The reason is written to
# stderr rather than assigned to a variable on purpose: this function is invoked as
# TASK_DIR=$(resolve_task_dir ...), i.e. in a subshell, so any variable it set would be
# discarded -- stderr passes through the command substitution unchanged.
resolve_task_dir() {
  local arg="$1"

  if [ -n "$arg" ]; then
    if [ -d "$arg" ]; then
      echo "$arg"
      return 0
    fi
    if [[ "$arg" =~ ^[0-9]+$ ]]; then
      local padded dir
      padded=$(printf "%03d" "$arg")
      dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1) || true
      if [ -n "$dir" ]; then
        echo "$dir"
        return 0
      fi
      echo "git-snapshot.sh: could not resolve a task directory." >&2
      echo "  reason: '$arg' looks like a task number, but no specs/${padded}_* directory exists (cwd: $(pwd))" >&2
      return 1
    fi
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: '$arg' is neither an existing directory nor an integer task number (cwd: $(pwd))" >&2
    return 1
  fi

  # No TASK argument: infer the single task currently in status "implementing".
  if ! command -v jq >/dev/null 2>&1; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and 'jq' is not installed, so specs/state.json could not be read" >&2
    return 1
  fi
  if [ ! -f specs/state.json ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and specs/state.json does not exist (cwd: $(pwd)); inference requires it" >&2
    return 1
  fi

  local nums count
  nums=$(jq -r '.active_projects[] | select(.status=="implementing") | .project_number' specs/state.json 2>/dev/null) || true
  count=$(printf '%s\n' "$nums" | grep -c '^[0-9]\+$' || true)

  if [ "$count" = "0" ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: no TASK argument was given and no task in specs/state.json has status \"implementing\", so there is nothing to infer" >&2
    return 1
  fi
  if [ "$count" = "1" ]; then
    local padded dir
    padded=$(printf "%03d" "$nums")
    dir=$(find specs -maxdepth 1 -type d -name "${padded}_*" 2>/dev/null | head -1) || true
    if [ -n "$dir" ]; then
      echo "$dir"
      return 0
    fi
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: inferred task $nums from specs/state.json, but no specs/${padded}_* directory exists" >&2
    return 1
  fi

  echo "git-snapshot.sh: could not resolve a task directory." >&2
  echo "  reason: no TASK argument was given and $count tasks are concurrently \"implementing\" ($(printf '%s' "$nums" | tr '\n' ' ' | sed 's/ *$//')), so inference is ambiguous" >&2
  return 1
}

TASK_DIR=$(resolve_task_dir "$TASK_ARG")
if [ -z "$TASK_DIR" ] || [ ! -d "$TASK_DIR" ]; then
  if [ -n "$TASK_DIR" ]; then
    echo "git-snapshot.sh: could not resolve a task directory." >&2
    echo "  reason: resolved to '$TASK_DIR', which is not a directory" >&2
  fi
  echo "  fix:    pass the task explicitly, in either form:" >&2
  echo "            bash .claude/scripts/git-snapshot.sh <task-number>" >&2
  echo "            bash .claude/scripts/git-snapshot.sh specs/<NNN>_<slug>" >&2
  echo "  note:   the no-argument form only resolves when EXACTLY ONE task in" >&2
  echo "          specs/state.json has status \"implementing\". Several tasks being in" >&2
  echo "          flight at once is normal here, so the explicit form is the reliable one." >&2
  echo "  modes:  the default and --branch modes REVERT the working tree; --no-revert does" >&2
  echo "          not. Run 'bash .claude/scripts/git-snapshot.sh --help' for details." >&2
  exit 1
fi

# Clean-tree check: nothing to snapshot.
if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
  echo "git-snapshot.sh: nothing to snapshot (working tree is clean)"
  exit 0
fi

# Task number, derived once from the resolved TASK_DIR's leading digits, for BOTH the guard
# below (default/--branch modes only) AND the stash-identity message every mode writes
# (default, --branch, and --no-revert all embed it -- see the stash/branch section below).
# Empty when TASK_DIR's basename has no leading digit run (e.g. a non-numbered directory
# passed explicitly); the guard's own D4 fallback below handles that case for reverting
# modes, and the stash-message use falls back to "unknown" (see below).
TASK_NUM=$(basename "$TASK_DIR" | grep -oE '^[0-9]+' || true)

# ─── Out-of-scope refusal guard (D1-D5) ────────────────────────────────────────────────
# Runs BEFORE any mutation (patch/stash/branch). Classifies every dirty TRACKED path
# against the resolved task's declared file_scope in specs/state.json, using the
# canonical path_covered_by_scope() predicate (see
# context/patterns/file-footprint-overlap.md's "Containment vs. Overlap" section).
# Skipped entirely for --no-revert (D2: it reverts nothing, so it has nothing to
# destroy) and when --allow-out-of-scope was passed (the deliberate whole-tree
# override).
if [ "$MODE" != "no-revert" ] && [ "$ALLOW_OUT_OF_SCOPE" -ne 1 ]; then
  FAIL_CLOSED_REASON=""
  FILE_SCOPE_JSON="[]"

  # D4: fail-closed no-file_scope fallback. Any of these three conditions means the
  # script CANNOT distinguish task work from unrelated work -- precisely the state that
  # produced the incident this guard exists to close -- so a reverting mode refuses
  # rather than silently proceeding as before.
  if [ -z "$TASK_NUM" ]; then
    FAIL_CLOSED_REASON="could not derive a task number from '$TASK_DIR' to look up its file_scope"
  elif ! command -v jq >/dev/null 2>&1; then
    FAIL_CLOSED_REASON="'jq' is not installed, so file_scope could not be read"
  elif [ ! -f specs/state.json ]; then
    FAIL_CLOSED_REASON="specs/state.json does not exist (cwd: $(pwd)); file_scope could not be read"
  else
    FILE_SCOPE_JSON=$(jq -c --argjson n "$TASK_NUM" \
      '[.active_projects[]? | select(.project_number == $n) | (.file_scope // [])[]]' \
      specs/state.json 2>/dev/null) || FILE_SCOPE_JSON=""
    if [ -z "$FILE_SCOPE_JSON" ] || [ "$FILE_SCOPE_JSON" = "[]" ]; then
      FAIL_CLOSED_REASON="task $TASK_NUM has no declared file_scope in specs/state.json"
    fi
  fi

  if [ -n "$FAIL_CLOSED_REASON" ]; then
    echo "git-snapshot.sh: refusing to run in ${MODE} mode (which reverts the working tree)." >&2
    echo "  reason: $FAIL_CLOSED_REASON" >&2
    echo "  Nothing has been mutated -- no patch, no stash, no marker, no branch." >&2
    echo "  fix:    pass --allow-out-of-scope to proceed anyway (reverts the WHOLE dirty" >&2
    echo "          tree), or --no-revert for a durable, non-reverting snapshot instead." >&2
    exit 1
  fi

  mapfile -t SCOPE_ENTRIES < <(printf '%s' "$FILE_SCOPE_JSON" | jq -r '.[]')

  # Dirty TRACKED paths. `git diff --name-only HEAD` (no --cached) already reports every
  # path that differs from HEAD in the working tree, which covers staged AND unstaged
  # changes alike (staging copies to the index; the working-tree file the diff reads
  # remains modified either way), so a second --cached pass is not needed.
  mapfile -t DIRTY_TRACKED < <(git diff --name-only HEAD 2>/dev/null)

  OUT_OF_SCOPE_PATHS=()
  for p in "${DIRTY_TRACKED[@]}"; do
    [ -z "$p" ] && continue
    if ! path_covered_by_scope "$p" "${SCOPE_ENTRIES[@]}"; then
      OUT_OF_SCOPE_PATHS+=("$p")
    fi
  done

  if [ "${#OUT_OF_SCOPE_PATHS[@]}" -gt 0 ]; then
    echo "git-snapshot.sh: refusing to run in ${MODE} mode -- it would revert dirty tracked" >&2
    echo "  path(s) outside task ${TASK_NUM}'s declared file_scope:" >&2
    for p in "${OUT_OF_SCOPE_PATHS[@]}"; do
      echo "    $p" >&2
    done
    echo "  Nothing has been mutated -- no patch, no stash, no marker, no branch." >&2
    echo "  fix:    pass --allow-out-of-scope to proceed anyway (reverts the WHOLE dirty" >&2
    echo "          tree), or --no-revert for a durable, non-reverting snapshot instead." >&2
    exit 1
  fi

  # D3: out-of-scope UNTRACKED paths are WARN-only, never refusal-triggering. Default
  # mode's `-u` will delete them too, but refusing on every untracked scratch/build
  # artifact would make the guard fire on nearly every real tree. Enumerated only after
  # the tracked-path refusal above has already been cleared.
  mapfile -t DIRTY_UNTRACKED < <(git ls-files --others --exclude-standard 2>/dev/null)
  OUT_OF_SCOPE_UNTRACKED=()
  for p in "${DIRTY_UNTRACKED[@]}"; do
    [ -z "$p" ] && continue
    if ! path_covered_by_scope "$p" "${SCOPE_ENTRIES[@]}"; then
      OUT_OF_SCOPE_UNTRACKED+=("$p")
    fi
  done
  if [ "${#OUT_OF_SCOPE_UNTRACKED[@]}" -gt 0 ]; then
    echo "git-snapshot.sh: WARNING (non-blocking) -- ${MODE} mode will DELETE the following" >&2
    echo "  untracked path(s) outside task ${TASK_NUM}'s declared file_scope:" >&2
    for p in "${OUT_OF_SCOPE_UNTRACKED[@]}"; do
      echo "    $p" >&2
    done
  fi
fi

TS=$(date +%s)
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
PATCH_PATH="${TASK_DIR}/working-progress-${TS}.patch"
MARKER_PATH="${TASK_DIR}/.git-snapshot-marker"

# Capture the diff to a scratch location OUTSIDE the repo first. Writing it directly
# under $TASK_DIR before stashing would make it an untracked file that `git stash
# push -u` immediately sweeps away (and can delete $TASK_DIR itself if it had no
# other tracked contents). It is moved into place after the stash/branch step below.
PATCH_TMP=$(mktemp)
if ! git diff HEAD > "$PATCH_TMP" 2>/dev/null; then
  echo "git-snapshot.sh: failed to compute diff for $PATCH_PATH" >&2
  rm -f "$PATCH_TMP"
  exit 1
fi

STASH_REF="NONE"
BRANCH_NAME="NONE"
UNTRACKED_BACKUP="NONE"

# Pre-op warning. On stderr so the existing stdout report stays byte-compatible for the
# docs that describe it (checkpoint-before-overflow.md and the agent handoff steps).
if [ "$MODE" = "no-revert" ]; then
  echo "git-snapshot.sh: --no-revert mode -- the working tree will NOT be modified." >&2
else
  echo "git-snapshot.sh: WARNING -- ${MODE} mode REVERTS the working tree." >&2
  echo "  Your uncommitted changes are about to be removed from the working directory." >&2
  echo "  They stay recoverable via the patch / stash / branch reported on completion, but" >&2
  echo "  they will no longer be present as live edits. --branch does NOT avoid this; it" >&2
  echo "  only changes the recovery handle. If you intend to keep working, abort and re-run" >&2
  echo "  with --no-revert." >&2
fi

if [ "$MODE" = "branch" ]; then
  ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  BRANCH_NAME="wip-snapshot-${TS}"

  if ! git checkout -b "$BRANCH_NAME" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create scratch branch $BRANCH_NAME" >&2
    exit 1
  fi
  if ! git add -A >/dev/null 2>&1 || ! git commit -m "wip snapshot ${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to create WIP commit on $BRANCH_NAME" >&2
    git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1 || true
    exit 1
  fi
  if ! git checkout "$ORIGINAL_BRANCH" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to return to original branch $ORIGINAL_BRANCH after WIP commit on $BRANCH_NAME" >&2
    exit 1
  fi
elif [ "$MODE" = "no-revert" ]; then
  # Non-destructive mode. `git stash create` builds a stash COMMIT OBJECT and prints its
  # sha without touching the working tree or refs/stash; `git stash store` then records
  # that object so it appears in `git stash list` like any other entry. Neither step
  # reverts anything. `git stash create` prints nothing when there are no tracked-file
  # changes (e.g. an untracked-only dirty tree), which is handled below.
  STASH_SHA=$(git stash create "git-snapshot-${TASK_NUM:-unknown}-${TS}" 2>/dev/null)
  if [ -n "$STASH_SHA" ]; then
    if ! git stash store -m "git-snapshot-${TASK_NUM:-unknown}-${TS}" "$STASH_SHA" >/dev/null 2>&1; then
      echo "git-snapshot.sh: failed to store stash object $STASH_SHA (no-revert mode)" >&2
      rm -f "$PATCH_TMP"
      exit 1
    fi
    STASH_REF=$(git stash list | head -1 | cut -d: -f1)
  fi

  # `git stash create` cannot capture untracked files and the patch cannot represent them,
  # so copy them instead. --exclude-standard matches `git stash -u`'s own ignored-file
  # semantics, so coverage is at parity with default mode. Enumeration happens BEFORE the
  # backup directory is created, so a backup never contains itself. Untracked filenames
  # containing a newline are not supported (none exist in practice).
  UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>/dev/null)
  if [ -n "$UNTRACKED_LIST" ]; then
    UNTRACKED_BACKUP="${TASK_DIR}/untracked-backup-${TS}"
    while IFS= read -r f; do
      [ -z "$f" ] && continue || true
      dest="${UNTRACKED_BACKUP}/${f}"
      if ! mkdir -p "$(dirname "$dest")" >/dev/null 2>&1 || ! cp -p "$f" "$dest" >/dev/null 2>&1; then
        echo "git-snapshot.sh: failed to back up untracked file '$f' to $dest (no-revert mode)" >&2
        rm -f "$PATCH_TMP"
        exit 1
      fi
    done <<< "$UNTRACKED_LIST"
  fi
else
  # Default mode: belt-and-suspenders in-repo stash copy (patch above is the primary
  # durable record; -u also captures untracked files the patch cannot represent).
  # NOTE: this REVERTS the working tree -- see the warning block above.
  if ! git stash push -u -m "git-snapshot-${TASK_NUM:-unknown}-${TS}" >/dev/null 2>&1; then
    echo "git-snapshot.sh: failed to stash changes (diff was computed but not yet written to $PATCH_PATH)" >&2
    rm -f "$PATCH_TMP"
    exit 1
  fi
  STASH_REF=$(git stash list | head -1 | cut -d: -f1)
fi

# Recreate $TASK_DIR in case the stash/branch step removed it (e.g. it contained only
# untracked content that `git stash push -u` swept away), then move the patch into place.
mkdir -p "$TASK_DIR"
if ! mv "$PATCH_TMP" "$PATCH_PATH"; then
  echo "git-snapshot.sh: failed to write patch to $PATCH_PATH (snapshot itself succeeded: stash=$STASH_REF branch=$BRANCH_NAME)" >&2
  rm -f "$PATCH_TMP"
  exit 1
fi

cat > "$MARKER_PATH" << EOF
TIMESTAMP=${TS}
HEAD_SHA=${HEAD_SHA}
PATCH_PATH=${PATCH_PATH}
STASH_REF=${STASH_REF}
BRANCH_NAME=${BRANCH_NAME}
UNTRACKED_BACKUP=${UNTRACKED_BACKUP}
EOF

echo "git-snapshot.sh: snapshot complete"
echo "  patch:  ${PATCH_PATH}"
echo "  stash:  ${STASH_REF}"
echo "  branch: ${BRANCH_NAME}"
[ "$UNTRACKED_BACKUP" = "NONE" ] || echo "  untracked-backup: ${UNTRACKED_BACKUP}"
echo "  marker: ${MARKER_PATH}"

# Post-op notice, on stderr for the same stdout-compatibility reason as the pre-op warning.
if [ "$MODE" = "no-revert" ]; then
  echo "git-snapshot.sh: the working tree was left UNCHANGED -- your edits are still present." >&2
  echo "  Because the tree is still dirty, a destructive git command run after this will" >&2
  echo "  discard those live edits; recover them from the patch / stash / untracked backup." >&2
else
  echo "git-snapshot.sh: THE WORKING TREE WAS JUST RESET TO HEAD." >&2
  echo "  Your uncommitted changes are no longer in the working directory. Recover with:" >&2
  echo "    patch  -> git apply ${PATCH_PATH}" >&2
  [ "$STASH_REF" = "NONE" ] || echo "    stash  -> git stash pop ${STASH_REF}" >&2
  [ "$BRANCH_NAME" = "NONE" ] || echo "    branch -> git checkout ${BRANCH_NAME}" >&2
fi
exit 0
