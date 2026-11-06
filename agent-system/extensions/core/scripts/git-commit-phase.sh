#!/usr/bin/env bash
# git-commit-phase.sh - Mechanized phase-commit wrapper: derives the stage list from a phase's
# own progress-file `files_touched` arrays instead of asking agent prose to hand-type it, commits
# unpiped through git-commit-scoped.sh, and verifies after the commit that every derived path is
# actually clean against HEAD.
#
# THE INCIDENT THIS CLOSES
# -------------------------
# A phase commit's `stage_paths` array was hand-typed by an agent rather than derived. Of ten
# regenerated Typst fragments, nine were named and one (zigzag.typ) was not. git-commit-scoped.sh
# committed exactly what it was given and exited 0 -- it behaved correctly throughout; the
# omission was entirely upstream, in how the caller built its own array. A stale copy of the
# missing file sat at HEAD until a manual follow-up commit caught it later.
#
# The data needed to catch the omission was already present in three places the caller itself had
# produced before the commit ran: the file was regenerated on disk, it was recorded in the
# caller's own progress-file `files_touched` array, and it was showing as modified in a `git
# status` check run immediately beforehand. Only the stage-list construction step lost it. This
# script removes that construction step from agent prose entirely -- the list is derived by this
# script from the progress file every caller already maintains, not retyped by hand at commit
# time.
#
# PRECEDENT FOR MECHANIZING OVER INSTRUCTING
# -------------------------------------------
# A prose heartbeat instruction once documented a few lines below an agent's own
# `update-phase-status.sh` call fired 0 times across 8 real phase transitions in one measured
# run. Moving the identical step INSIDE update-phase-status.sh itself -- the one script every
# caller must already invoke to move a phase heading -- made it fire 16/16 in the same class of
# run. This script applies the same move: a derivation and a completeness check that used to be
# prose instructions (hand-type the list; remember to check it afterwards) are instead mechanized
# inside the one script every phase-commit call site must already invoke.
#
# ARGUMENT INTERFACE
# -------------------
# Usage:
#   git-commit-phase.sh --task N --project SLUG --phase P --message MSG --session SID \
#       [--objective ID] [--plan-path PATH]
#
#   --task N        Task number (unpadded). Required. Forwarded to git-commit-scoped.sh's own
#                   --task flag (V5 contended-path lease) and used to resolve the task directory
#                   and the state.json entry for the Containment Self-Check below.
#   --project SLUG  The task's project-name slug, exactly as it appears in
#                   specs/{NNN}_{SLUG}/. Required.
#   --phase P       Phase number (unpadded). Required. Selects
#                   specs/{NNN}_{SLUG}/progress/phase-{P}-progress.json as the derivation source.
#   --message MSG   Commit message body, forwarded verbatim to git-commit-scoped.sh. Required.
#   --session SID   Session id, forwarded verbatim to git-commit-scoped.sh. Required.
#   --objective ID  Optional. Narrows derivation to one objective's own `files_touched` array --
#                   the per-objective green-substep call site's shape. When absent, derivation
#                   unions every objective's `files_touched` array in the phase -- the per-phase
#                   closing-commit call site's shape.
#   --plan-path PATH
#                   Optional. The plan file path, staged alongside the task directory exactly as
#                   the `implement` scope in context/standards/git-staging-scope.md already
#                   specifies.
#
# DERIVATION
# ----------
# The fixed scope is always staged first, unconditionally: `specs/{NNN}_{SLUG}/`,
# `specs/TODO.md`, `specs/state.json`, and --plan-path if given. These four stay structurally
# outside the Containment Self-Check below, exactly as context/standards/git-staging-scope.md's
# Phase-Commit Containment Self-Check prose already specifies.
#
# The `files_touched` set is then derived from the progress file with jq, deduplicated, and
# appended. Each surviving path is also the exact set the post-commit completeness check verifies
# against HEAD below -- derivation and verification share one source of truth.
#
# PHASE-COMMIT CONTAINMENT SELF-CHECK (ported from agent prose)
# ---------------------------------------------------------------
# This is a mechanical port of the Phase-Commit Containment Self-Check documented in
# agents/general-implementation-agent.md, preserved here verbatim rather than reinvented: read
# the task's declared `file_scope` from specs/state.json; carve out the four fixed paths above
# (never tested); for every remaining derived `files_touched` path, apply the Containment
# predicate (exact match to a file_scope entry, or either path a directory/glob ancestor of the
# other); drop an uncontained entry from the commit with a loud warning and a non-fatal
# `issue-record.sh --class "scope excursion"` call; and fail OPEN (proceed as if the check were
# absent) on any missing, empty, unreadable, or malformed `file_scope`, or any internal error.
# Never refuse the whole commit over this -- drop-and-warn only, the same "under-stage, never
# over-stage" fail-safe direction git-staging-scope.md already settles.
#
# POST-COMMIT COMPLETENESS CHECK
# -------------------------------
# After git-commit-scoped.sh returns, every surviving (derived, not containment-dropped)
# `files_touched` path is checked with `git status --porcelain -- <path>`. Any non-empty result
# means that path is not clean against HEAD after the commit -- the exact silent-drop shape this
# script exists to catch, whatever the underlying mechanism (an unmatched pathspec, a dropped
# `git add`, or anything else that leaves a named path un-landed while the script itself exits
# without complaint). Every dirty path is named on stderr; nothing here attempts to guess why a
# path is dirty or to retry the commit.
#
# FAIL-OPEN PATH
# --------------
# A missing progress file, a progress file that is not valid JSON, or a derived `files_touched`
# set that is empty (nothing to check) each produce a loud stderr warning, fall back to
# committing the fixed scope alone, and skip the completeness check entirely -- there is nothing
# to verify a derivation that never ran. The commit itself is never blocked by a missing or
# malformed optional input; see context/standards/git-staging-scope.md's settled fail-safe
# direction.
#
# EXIT-CODE MAPPING
# ------------------
#   0-5  Passed through verbatim from git-commit-scoped.sh's own exit-code contract (see that
#        script's header) whenever the completeness check did not fail -- including the
#        fail-open path, which always exits with the inner code.
#   6    The completeness check failed: one or more derived `files_touched` paths are not clean
#        against HEAD after the commit. This is reserved and never collides with
#        git-commit-scoped.sh's own 0-5 vocabulary. Note explicitly: "nothing to commit" (inner
#        code 1) together with one or more dirty `files_touched` paths IS the silent-drop shape
#        this script exists to catch, and correctly yields 6 rather than 1 -- a caller that reads
#        an inner "nothing to commit" as benign would otherwise miss exactly the incident this
#        script closes.
#   2    Usage/argument error, before any commit is attempted.
#
# Recovery from exit 6 is a follow-up commit of the named paths, never a widened pathspec --
# matching the Containment Self-Check's own existing recovery guidance.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

usage() {
  echo "Usage: $0 --task N --project SLUG --phase P --message MSG --session SID [--objective ID] [--plan-path PATH]" >&2
  exit 2
}

task_number=""
project_name=""
phase_number=""
message=""
session_id=""
objective_id=""
plan_path=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --task)
      [ "$#" -ge 2 ] || usage
      task_number="$2"
      shift 2
      ;;
    --project)
      [ "$#" -ge 2 ] || usage
      project_name="$2"
      shift 2
      ;;
    --phase)
      [ "$#" -ge 2 ] || usage
      phase_number="$2"
      shift 2
      ;;
    --message)
      [ "$#" -ge 2 ] || usage
      message="$2"
      shift 2
      ;;
    --session)
      [ "$#" -ge 2 ] || usage
      session_id="$2"
      shift 2
      ;;
    --objective)
      [ "$#" -ge 2 ] || usage
      objective_id="$2"
      shift 2
      ;;
    --plan-path)
      [ "$#" -ge 2 ] || usage
      plan_path="$2"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$task_number" ] || usage
[ -n "$project_name" ] || usage
[ -n "$phase_number" ] || usage
[ -n "$message" ] || usage
[ -n "$session_id" ] || usage

cd "$PROJECT_ROOT" || exit 2

warn() {
  echo "WARNING: git-commit-phase.sh: $1" >&2
}

padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
progress_file="${task_dir}/progress/phase-${phase_number}-progress.json"

# --- Fixed scope: always staged, never tested by the Containment Self-Check below. This is a
# DIFFERENT construct from that check's own file_scope_arr engine-written-state splice further
# down -- this seed is unconditional and untested (these paths are staged regardless of any
# task's declared file_scope), while the splice below only widens what the Self-Check itself
# ADMITS when testing files_touched; the two are not duplicates of each other. ---
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
[ -n "$plan_path" ] && stage_paths+=("$plan_path")

# --- Derivation: fail-open on a missing/malformed progress file or an empty derived set. ---
run_completeness_check=true
files_touched=()

if [ ! -f "$progress_file" ]; then
  warn "progress file not found: ${progress_file} -- falling back to the fixed task-directory scope; completeness check skipped"
  run_completeness_check=false
elif ! jq empty "$progress_file" >/dev/null 2>&1; then
  warn "progress file is not valid JSON: ${progress_file} -- falling back to the fixed task-directory scope; completeness check skipped"
  run_completeness_check=false
else
  if [ -n "$objective_id" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] && files_touched+=("$f")
    done < <(jq -r --arg oid "$objective_id" \
      '.objectives[] | select((.id|tostring) == $oid) | .files_touched[]? // empty' \
      "$progress_file" 2>/dev/null | sort -u)
  else
    while IFS= read -r f; do
      [ -n "$f" ] && files_touched+=("$f")
    done < <(jq -r '[.objectives[].files_touched[]?] | unique[]' "$progress_file" 2>/dev/null)
  fi

  if [ "${#files_touched[@]}" -eq 0 ]; then
    warn "no files_touched entries found in ${progress_file}$( [ -n "$objective_id" ] && echo " for objective ${objective_id}" ) -- nothing to derive; completeness check skipped"
    run_completeness_check=false
  fi
fi

# --- Phase-Commit Containment Self-Check (ported from agent prose; see header). ---
# Fails open (leaves files_touched untouched) on any missing/empty/unreadable/malformed
# file_scope, or any internal error below -- never block a commit over a guard defect.
if [ "${#files_touched[@]}" -gt 0 ]; then
  file_scope_json="$(jq -r --argjson n "$task_number" \
    '.active_projects[]? | select(.project_number == $n) | .file_scope // empty' \
    specs/state.json 2>/dev/null || true)"

  if [ -n "$file_scope_json" ] && [ "$file_scope_json" != "null" ] && [ "$file_scope_json" != "[]" ]; then
    file_scope_arr=()
    while IFS= read -r s; do
      [ -n "$s" ] && file_scope_arr+=("$s")
    done < <(printf '%s' "$file_scope_json" | jq -r '.[]?' 2>/dev/null || true)

    if [ "${#file_scope_arr[@]}" -gt 0 ]; then
      # Own-task-directory member: the committing task's own resolved artifact directory is an
      # implicit, unconditional in-scope member of this Self-Check, mirroring the per-site
      # splices Sites 1 (orchestrate-cycle-postflight.sh) and 3 (git-commit-scoped.sh's V10) each
      # already carry -- see git-staging-scope.md's "Three Containment sites, not one". This is
      # deliberately NOT a member of the shared scripts/lib/engine-written-state-paths-lib.sh
      # allowlist spliced in immediately below: that library's own header rejects any task-owned
      # specs/{NNN}_*/ path, because a per-task directory is authored by one task's own dispatch
      # rather than engine-written on behalf of every/many tasks, failing the library's admission
      # bar. Placed INSIDE this non-empty guard -- exactly where the engine-written-state splice
      # sits -- so the fail-open posture above is unchanged: a task with no declared file_scope
      # still skips this whole check, never acquiring a scope member it never declared.
      file_scope_arr+=("${task_dir}/")

      # Engine-written-state allowlist (the third of three Containment sites -- see
      # git-staging-scope.md's "Three Containment sites, not one"): widen file_scope_arr from
      # the shared source scripts/lib/engine-written-state-paths-lib.sh, the same library Sites
      # 1 (orchestrate-cycle-postflight.sh) and 3 (git-commit-scoped.sh) already consult, rather
      # than hand-copying the literal list a third time. Placed INSIDE this non-empty guard so
      # the fail-open posture above is unchanged: a task with no declared file_scope still skips
      # this whole check, never acquiring a four-member scope it never declared. Decision 2's
      # fallback: a source/resolution failure splices the hardcoded two-literal pair instead, so
      # a library failure reproduces today's (zero-allowlist) behavior's nearest safe neighbor
      # rather than silently widening or narrowing in an unreviewed way.
      engine_written_paths_json=""
      # shellcheck disable=SC1091
      if source "${SCRIPT_DIR}/lib/engine-written-state-paths-lib.sh" 2>/dev/null; then
        engine_written_paths_json="$(engine_written_state_paths 2>/dev/null)" || engine_written_paths_json=""
      fi
      if [ -n "$engine_written_paths_json" ] \
         && echo "$engine_written_paths_json" | jq -e 'type == "array" and (all(.[]; type == "string"))' >/dev/null 2>&1; then
        while IFS= read -r ewp; do
          [ -n "$ewp" ] && file_scope_arr+=("$ewp")
        done < <(echo "$engine_written_paths_json" | jq -r '.[]?' 2>/dev/null)
      else
        file_scope_arr+=("specs/TODO.md" "specs/state.json")
      fi

      # is_contained <path> -- exact match, directory/glob ancestor in either direction, or a
      # literal trailing-/** entry's deep-glob prefix (the base directory itself, its direct
      # children, and every deeper descendant -- nothing outside it).
      is_contained() {
        local path="$1" entry entry_base
        for entry in "${file_scope_arr[@]}"; do
          # Normalize a trailing-slash directory entry ("dir/", or "dir//") down to "dir"
          # before composing any glob below. Left un-normalized, "$entry/*" on an entry that
          # already ends in "/" composes a doubled "//*" suffix, which never matches a real
          # single-slash child path in bash case-pattern matching -- every file under that
          # scope entry is then wrongly judged out-of-scope and dropped. A literal "/**"
          # suffix is untouched here (it never ends in a bare "/"), and the lone "/" entry is
          # left alone rather than reduced to an empty string.
          while [ "${entry%/}" != "$entry" ] && [ -n "${entry%/}" ]; do
            entry="${entry%/}"
          done
          [ "$path" = "$entry" ] && return 0
          # Entry ends in a literal "/**": the quoted case pattern below can never match it, so
          # strip the literal suffix and test prefix containment against the stripped base.
          entry_base="${entry%/\*\*}"
          if [ "$entry_base" != "$entry" ]; then
            case "$path" in
              "$entry_base"|"$entry_base"/*) return 0 ;;
            esac
          fi
          case "$path" in
            "$entry"/*) return 0 ;;
          esac
          case "$entry" in
            "$path"/*) return 0 ;;
          esac
        done
        return 1
      }

      kept_files_touched=()
      for f in "${files_touched[@]}"; do
        if is_contained "$f"; then
          kept_files_touched+=("$f")
        else
          warn "dropping out-of-scope path '${f}' from phase commit — not in task ${task_number}'s declared file_scope"
          bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind issue \
            --class "scope excursion" --severity minor \
            --what-happened "git-commit-phase.sh dropped '${f}' from a phase commit pathspec: not contained in this task's declared file_scope." \
            --phase implement \
            >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
        fi
      done
      files_touched=("${kept_files_touched[@]}")
      if [ "${#files_touched[@]}" -eq 0 ]; then
        run_completeness_check=false
      fi
    fi
  fi
fi

stage_paths+=("${files_touched[@]}")

# --- Invoke git-commit-scoped.sh unpiped; capture its real exit code directly. ---
set +e
bash "${SCRIPT_DIR}/git-commit-scoped.sh" \
  --message "$message" \
  --session "$session_id" \
  --task "$task_number" \
  -- "${stage_paths[@]}"
commit_exit=$?
set -e

# --- Post-commit completeness check ---
if $run_completeness_check; then
  dirty_paths=()
  for f in "${files_touched[@]}"; do
    status_out="$(git status --porcelain -- "$f" 2>/dev/null || true)"
    [ -n "$status_out" ] && dirty_paths+=("$f")
  done

  if [ "${#dirty_paths[@]}" -gt 0 ]; then
    echo "ERROR: phase commit completeness check failed — the following files_touched path(s) are not clean against HEAD after the commit:" >&2
    for f in "${dirty_paths[@]}"; do
      echo "  ${f}" >&2
    done
    exit 6
  fi
fi

exit "$commit_exit"
