#!/usr/bin/env bash
# commit-source-store-path.sh - Commit exactly ONE file_scope path, classified SOURCE_STORE by
# scripts/lib/source-store-path-lib.sh, in ITS OWN repository (a repository different from the
# one dispatching the phase commit that called this script). This is the sanctioned,
# single-pathspec mechanism design option (b) of the originating containment remedy adopts: a
# source-store edit is committed in its own repository as part of phase closure, rather than left
# entirely to the dispatched agent's own vigilance.
#
# Usage:
#   commit-source-store-path.sh <target_root> <relative_path> <message> <session_id>
#
#   <target_root>    Absolute path to the SECOND repository's root (the resolved source
#                    repository toplevel a SOURCE_STORE classification names).
#   <relative_path>  The one path to commit, relative to <target_root>. Staged with ONE explicit
#                    pathspec and nothing else -- never a directory, never a glob, never `-A`,
#                    never `.`, never `-am`. This script does not run any generator and does not
#                    stage any file it was not handed; a whole-file or directory add would sweep
#                    in a concurrent writer's uncommitted rows in that second repository.
#   <message>        Commit message body.
#   <session_id>     Session id, recorded as a `Session: <id>` trailer, mirroring this
#                     repository's own commit-message convention.
#
# REFUSALS (checked in order, before touching the index; each names the reason and the exact
# manual command to run by hand)
# -----------------------------------------------------------------------------------------------
#   3  <target_root> canonicalizes to THIS script's own repository root -- not an
#      out-of-repository case at all (a SOURCE_STORE classification against a repository that
#      owns its own source store is the inertness case; it must never reach this script in the
#      first place, but this refusal exists defensively).
#   4  <target_root> is not a git working tree.
#   5  HEAD is detached in <target_root>.
#   6  A merge, rebase, cherry-pick, or bisect is in progress in <target_root>.
#   7  <target_root>'s git directory carries an existing `index.lock`.
#   8  <target_root>/<relative_path> does not exist.
#   1  The diff for <relative_path> is empty (nothing to commit) -- a benign no-op, NOT an
#      error; mirrors git-commit-scoped.sh's own "nothing to commit" = exit 1 convention.
#
# EXIT-CODE VOCABULARY (own, dedicated; never collides with git-commit-phase.sh's or
# git-commit-scoped.sh's own vocabularies, because this script is never the direct return value
# of either -- its caller captures and discards this script's own exit code unconditionally; see
# "FAIL-OPEN CONTRACT" below)
# -----------------------------------------------------------------------------------------------
#   0  Committed. The resulting commit SHA is printed on stdout, alone on its own line.
#   1  Nothing to commit for this one path (benign no-op).
#   2  Usage error (wrong argument count).
#   3  <target_root> equals this script's own repository root.
#   4  <target_root> is not a git working tree.
#   5  Detached HEAD in <target_root>.
#   6  An in-progress merge/rebase/cherry-pick/bisect in <target_root>.
#   7  An existing `index.lock` in <target_root>.
#   8  <relative_path> does not exist under <target_root>.
#   9  `git add` or `git commit` genuinely failed (the one case not pre-empted by a refusal
#      above).
#
# FAIL-OPEN CONTRACT
# -------------------
# NO CALLER IS PERMITTED TO TREAT A NON-ZERO RESULT FROM THIS SCRIPT AS FATAL. Every call site
# must capture this script's exit code, report it (the outcome-aware notice this feeds), and
# proceed exactly as if this script had never been called otherwise. This script never touches
# the caller's own commit, the caller's own exit code, or the caller's own repository's state in
# any way -- its entire blast radius is the one `<target_root>` repository and the one named
# path.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
THIS_REPO_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"

usage() {
  echo "Usage: $0 <target_root> <relative_path> <message> <session_id>" >&2
  exit 2
}

[ "$#" -eq 4 ] || usage

target_root_arg="$1"
relative_path="$2"
message="$3"
session_id="$4"

[ -n "$target_root_arg" ] || usage
[ -n "$relative_path" ] || usage
[ -n "$message" ] || usage
[ -n "$session_id" ] || usage

err() {
  echo "ERROR: commit-source-store-path.sh: $1" >&2
}

manual_hint() {
  echo "  Manual recovery: git -C '${target_root_arg}' add -- '${relative_path}' && git -C '${target_root_arg}' commit -m '<message>'" >&2
}

# --- Refusal 3: target_root equals this script's own repository root. ---
target_root_canon="$(realpath -m -- "$target_root_arg" 2>/dev/null)"
this_repo_canon="$(realpath -m -- "$THIS_REPO_ROOT" 2>/dev/null)"
if [ -n "$target_root_canon" ] && [ -n "$this_repo_canon" ] && [ "$target_root_canon" = "$this_repo_canon" ]; then
  err "target_root '${target_root_arg}' equals this script's own repository root (${this_repo_canon}) -- not an out-of-repository case at all; nothing to do here."
  manual_hint
  exit 3
fi

# --- Refusal 4: not a git working tree. ---
target_toplevel="$(git -C "$target_root_arg" rev-parse --show-toplevel 2>/dev/null)" || target_toplevel=""
if [ -z "$target_toplevel" ]; then
  err "target_root '${target_root_arg}' is not a git working tree."
  manual_hint
  exit 4
fi

# --- Refusal 5: detached HEAD. ---
if ! git -C "$target_root_arg" symbolic-ref -q HEAD >/dev/null 2>&1; then
  err "HEAD is detached in '${target_root_arg}' -- refusing to commit there."
  manual_hint
  exit 5
fi

# --- Refusal 6: an in-progress merge/rebase/cherry-pick/bisect. ---
target_git_dir="$(git -C "$target_root_arg" rev-parse --git-dir 2>/dev/null)" || target_git_dir=""
if [ -n "$target_git_dir" ]; then
  case "$target_git_dir" in
    /*) : ;;
    *) target_git_dir="${target_root_arg%/}/${target_git_dir}" ;;
  esac
  for marker in MERGE_HEAD CHERRY_PICK_HEAD BISECT_LOG rebase-merge rebase-apply; do
    if [ -e "${target_git_dir}/${marker}" ]; then
      err "an in-progress merge/rebase/cherry-pick/bisect was detected in '${target_root_arg}' (${marker}) -- refusing to commit there."
      manual_hint
      exit 6
    fi
  done
fi

# --- Refusal 7: an existing index.lock. ---
if [ -n "$target_git_dir" ] && [ -e "${target_git_dir}/index.lock" ]; then
  err "an existing index.lock was found in '${target_root_arg}' -- refusing to commit there (contention)."
  manual_hint
  exit 7
fi

# --- Refusal 8: the target file does not exist. ---
if [ ! -e "${target_root_arg%/}/${relative_path}" ]; then
  err "'${relative_path}' does not exist under '${target_root_arg}'."
  manual_hint
  exit 8
fi

# --- Refusal 1 (benign): an empty diff for this one path. ---
status_out="$(git -C "$target_root_arg" status --porcelain -- "$relative_path" 2>/dev/null)"
if [ -z "$status_out" ]; then
  echo "NOTE: commit-source-store-path.sh: '${relative_path}' is already clean in '${target_root_arg}' -- nothing to commit." >&2
  exit 1
fi

# --- Stage with ONE explicit pathspec and nothing else. ---
if ! add_output="$(git -C "$target_root_arg" add -- "$relative_path" 2>&1)"; then
  echo "$add_output" >&2
  err "'git add -- ${relative_path}' failed in '${target_root_arg}'."
  manual_hint
  exit 9
fi

full_message="$(printf '%s\n\nSession: %s\n' "$message" "$session_id")"
if ! commit_output="$(git -C "$target_root_arg" commit -m "$full_message" -- "$relative_path" 2>&1)"; then
  echo "$commit_output" >&2
  err "'git commit' failed in '${target_root_arg}'."
  manual_hint
  exit 9
fi

resulting_sha="$(git -C "$target_root_arg" rev-parse HEAD 2>/dev/null)"
echo "$resulting_sha"
exit 0
