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
# A dropped path is additionally proposed back into the task's own declared `file_scope`: it is
# deposited into this task's `.return-meta.json` `proposed_file_scope` array (skip-if-absent,
# never create) so the next implement-postflight merge widens the declaration to match reality.
# This deposit is strictly additive to, and never a substitute for, the warn() and
# issue-record.sh calls immediately above it -- the warning and the issue row still fire on
# every drop, unconditionally. The deposit fails open exactly as this check itself does: every
# failure mode warns non-fatally and never touches the commit's exit code. See
# context/formats/return-metadata-file.md's `proposed_file_scope` field specification for the
# full producer/consumer contract on the implement path.
#
# DEPLOYED-TREE REFUSAL
# ----------------------
# A deployed-tree path (`.claude`, `.claude/`, or anything prefixed `.claude/`) is never a
# legitimate `file_scope` member: `.claude/` is a gitignored, disposable deploy artifact
# regenerated from the source store (rules/source-store-deploy-boundary.md), so a declared claim
# on it is silently wiped by the next regeneration regardless of what `file_scope` says. This is
# enforced at the two points such a path can reach this script, both a pure structural prefix
# test on the string -- never a filesystem/existence check:
#   1. `propose_file_scope_addition()` refuses to deposit such a path at all, so a drop caused BY
#      the refusal below can never re-seed `state.json`'s `file_scope` through the implement
#      postflight's `--file-scope-add` union-merge. The warn()/issue-record.sh calls at the drop
#      call site fire unconditionally regardless of this refusal -- it changes only what, if
#      anything, gets deposited.
#   2. The Containment Self-Check's own `file_scope_arr`, once populated from `state.json` and
#      BEFORE the own-task-directory and engine-written-state splices immediately below it, has
#      every deployed-tree entry stripped, each with its own `warn()`. This is the predicate's
#      input -- `file_scope_arr` is NEVER widened by `proposed_file_scope` (see the
#      "Within-dispatch proposed_file_scope lookup" comment at the strip's call site for why a
#      true union was rejected), so a deployed-tree path can reach `file_scope_arr` only through
#      `state.json`'s own declared `file_scope`, exactly where this strip removes it.
#      Non-emptiness is re-tested immediately after the strip: if nothing survives, the existing
#      fail-open path (skip the whole check) fires exactly as it does for a missing/empty
#      `file_scope` today -- this is
#      why neither splice is relocated out of the non-empty guard.
# Refusing a deployed-tree path never changes the drop-and-warn guard's behavior for a genuine
# out-of-territory SOURCE path, and never touches the fail-open posture for an absent, empty,
# unreadable, or malformed `file_scope` -- both stay exactly as documented above.
#
# WITHIN-DISPATCH proposed_file_scope LOOKUP (PART B)
# -----------------------------------------------------
# A path dropped by this check gets `warn()`ed, `issue-record.sh`-ed, and deposited into
# `proposed_file_scope` EVERY time it recurs in a later phase's own commit within the same
# dispatch -- this is deliberately UNCHANGED, not suppressed. A design that instead admitted a
# `proposed_file_scope` entry into `file_scope_arr`/`is_contained()` (making this script stop
# dropping it) was built and then rejected: git-commit-scoped.sh carries its OWN, separate V10
# containment guard (Site 3 of the three documented sites) that re-reads the UNWIDENED
# `file_scope` straight from `specs/state.json` with no override once `--task` is passed
# (always is, here), so admitting the path here would not make it actually land -- it would
# instead make THIS script falsely report success (or trip its own post-commit completeness
# check) for a path that Site 3 silently vetoes regardless, which is strictly worse than today's
# honest, visible, repeatable drop. The only safe, in-scope improvement implemented: the warn()
# text is annotated (via `already_proposed()`, a read-only exact-string lookup against this
# task's own `proposed_file_scope`) to say a recurring drop is already known and should be
# landed with a scoped follow-up commit, rather than silently reading as a brand-new incident
# each time. See this task's own implementation summary for the Site-3 residual this leaves for
# a future task, and the regression this averts (test-git-commit-phase.sh's own idempotence
# fixture, which depends on `issue-record.sh`'s append-only log growing on every repeat drop to
# keep producing a committable diff at all -- an admit-on-union design starves that diff and
# either falsely succeeds or hard-fails depending on exactly how it is built).
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
# SECOND-REPOSITORY COMMIT (design option (b): the sanctioned route for a SOURCE_STORE path)
# ----------------------------------------------------------------------------------------------
# Runs immediately AFTER this script's own `git-commit-scoped.sh` invocation returns, once per
# `source_store_commits` entry the Repository Classification step above recorded. Invokes
# `commit-source-store-path.sh <source_toplevel> <rel_path> <message> <session_id>`, captures its
# exit code and output, and FAILS OPEN UNCONDITIONALLY: the result never propagates into this
# script's own exit code (0-6, documented below), never retries, and never widens into a second
# attempt with a different pathspec. Three outcomes, each reported and each recorded
# (`issue-record.sh`, win or loss alike) -- the Phase 3 drop warning's own repository-naming
# notice is made unconditional and outcome-aware by these three branches:
#   exit 0  -- committed. Named with the resulting revision (`kind: win`, severity `none`).
#   exit 1  -- nothing to commit there (the path may already be landed). Named, not recorded as
#              an issue (a benign, unremarkable outcome).
#   other   -- the second-repository commit did NOT happen. Named with the reason
#              `commit-source-store-path.sh` itself already printed, plus the exact manual
#              recovery command, and recorded (`kind: issue`, severity `minor`) for visibility.
# `commit-source-store-path.sh`'s own exit-code vocabulary (0/1/2-9) is DISTINCT from, and never
# collides with, this script's own (0-6) -- the two are never compared or forwarded to each
# other, only inspected by this wiring's own three-way case split above.
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
#
# REPOSITORY CLASSIFICATION (ported from a different-repository-containment remedy)
# -------------------------------------------------------------------------------------
# A `files_touched` path can be a path this repository cannot hold AT ALL -- either it belongs
# to a DIFFERENT repository entirely (a genuine out-of-repository path, no extension's source
# store claims it), or it belongs to an EXTENSION'S SOURCE STORE, resolved via
# `.claude-extensions.json`'s per-extension `source_dir`, whose enclosing git toplevel differs
# from this repository's own root. Before this classification existed, both shapes reached the
# ordinary Containment Self-Check below and were reported with the SAME "not contained in this
# task's declared file_scope" wording a genuinely in-repository undeclared path gets -- the two
# causes were indistinguishable from the warning text alone.
#
# This classification runs BEFORE the Containment Self-Check below -- the same placement rule
# git-commit-scoped.sh's own V9 out-of-repository guard already documents for itself: an
# out-of-repository (or source-store) path must never be able to reach the scope test, because
# the scope test can only ever answer "declared or not", never "which repository". It sources
# `scripts/lib/source-store-path-lib.sh` with the same guarded, fail-soft `source … 2>/dev/null`
# posture the engine-written-state library below already uses -- an unavailable library skips
# this classification entirely and leaves the Containment Self-Check exactly as it was before
# this classification existed (today's behavior, byte for byte).
#
# Each classified entry is removed from `files_touched` -- and therefore from `stage_paths`, the
# post-commit completeness check, and the Containment Self-Check's own scope test, all of which
# consume `files_touched` downstream of this classification -- and reported with wording
# TEXTUALLY DISTINCT from the Containment Self-Check's own "not contained in this task's declared
# file_scope" message:
#   SOURCE_STORE: names the resolved extension, the source repository's toplevel, and the path's
#     location inside it. Recorded under `issue-record.sh --class "source store excursion"` (a
#     class distinct from the Containment Self-Check's own "scope excursion"), with its own
#     `--what-happened` wording so the two causes are separable in the issue log. A fail-open
#     attempt to commit this path in its OWN repository runs immediately after this script's own
#     commit returns, via `commit-source-store-path.sh` -- see the "SECOND-REPOSITORY COMMIT"
#     subsection below for the wiring's own exit-handling contract.
#   OUT_OF_REPO (no extension claims it): names the resolved parent directory and states plainly
#     that the path lies outside this repository. Recorded under the SAME "source store
#     excursion" class (both shapes share "this repository cannot hold it at all", distinct from
#     an ordinary declared-scope miss).
# Neither verdict's path is ever deposited into `proposed_file_scope`: re-seeding
# `specs/state.json`'s `file_scope` with a path this repository can never hold would guarantee an
# identical drop on every future phase. `propose_file_scope_addition()` itself additionally
# refuses such a path defensively (mirroring its existing deployed-tree refusal), in case a
# future call site ever reaches it for one.
#
# An `IN_REPO` verdict changes nothing: the path proceeds into the existing Containment
# Self-Check exactly as before this classification existed, including its existing "scope
# excursion" message, class, `--what-happened` string, and deposit for a genuinely undeclared
# in-repository path (acceptance-criterion-3 pin). In THIS repository, where the source store
# sits inside this repository's own root, every `agent-system/**` path classifies `IN_REPO`, so
# this classification is provably inert here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# Repository classification library (see "REPOSITORY CLASSIFICATION" header subsection above).
# Sourced early, fail-soft, so it is available to both propose_file_scope_addition()'s defensive
# refusal and the classification block further down -- an unavailable library leaves every
# consumer of source_store_classify/source_store_unexpanded_variable behaving exactly as it did
# before this library existed (both consumers guard with `declare -F` before calling either
# function).
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/source-store-path-lib.sh" 2>/dev/null || true

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

# propose_file_scope_addition <path> -- deposits a containment-dropped path into the task's own
# .return-meta.json `proposed_file_scope` array at drop time, additively and idempotently, under
# flock. This is the implement-path producer side of the proposed_file_scope channel documented
# in context/formats/return-metadata-file.md -- additive to, and never a substitute for, the
# warn()/issue-record.sh calls at the call site below. Skip-if-absent, never create: a task
# directory with no .return-meta.json yet is left untouched, because the file's own required
# fields (status, a correctly shaped artifacts) cannot be synthesized by a commit wrapper -- see
# the Decisions section this helper implements. Every failure path warns non-fatally and returns
# 0; this function never returns non-zero and never writes to stdout, and nothing it does can
# change the calling commit's exit code.
propose_file_scope_addition() {
  local path="$1"
  local meta_file="${task_dir}/.return-meta.json"
  local lock_file="${task_dir}/.return-meta.lock"

  # Deployed-tree deposit refusal (see "Deployed-tree refusal" subsection below): a path dropped
  # by the Containment Self-Check specifically BECAUSE it is a deployed-tree path must never be
  # re-deposited here -- the whole point of the drop. Without this refusal, the deposit channel
  # would re-seed specs/state.json's file_scope through the implement postflight's
  # --file-scope-add union-merge, resurrecting the exact entry the drop just correctly removed.
  # The warn()/issue-record.sh calls at the drop call site are untouched and still fire
  # unconditionally on every drop -- this refusal only changes what, if anything, gets deposited.
  case "$path" in
    .claude|.claude/|.claude/*)
      warn "refusing to deposit '${path}' into proposed_file_scope: a deployed-tree (.claude/**) path is never a legitimate file_scope member (see rules/source-store-deploy-boundary.md)"
      return 0
      ;;
  esac

  # Repository-classification refusal (defense in depth): a path this repository cannot hold at
  # all -- a different repository entirely, or a different extension's source store -- is never
  # a legitimate file_scope member here either, for the identical reason the deployed-tree
  # refusal above exists: re-seeding specs/state.json's file_scope with it would guarantee an
  # identical drop on every future phase. The classification block below never calls this
  # function for such a path in the first place (see its own header subsection), so this is a
  # defensive refusal for any future call site, not the primary enforcement point.
  if declare -F source_store_classify >/dev/null 2>&1; then
    _fsa_classify_out="$(source_store_classify "$PROJECT_ROOT" "$path" 2>/dev/null || echo "IN_REPO")"
    case "${_fsa_classify_out%%$'\t'*}" in
      SOURCE_STORE|OUT_OF_REPO)
        warn "refusing to deposit '${path}' into proposed_file_scope: this path is not contained in this repository (classified ${_fsa_classify_out%%$'\t'*}) -- it can never become a legitimate file_scope member here"
        return 0
        ;;
    esac
  fi

  if [ ! -f "$meta_file" ]; then
    warn "skipping proposed_file_scope deposit for '${path}': ${meta_file} not found (skip-if-absent, never create)"
    return 0
  fi
  if ! jq empty "$meta_file" >/dev/null 2>&1; then
    warn "skipping proposed_file_scope deposit for '${path}': ${meta_file} is not valid JSON"
    return 0
  fi

  (
    flock -x 200
    local tmp_file
    if ! tmp_file="$(mktemp "${meta_file}.XXXXXX" 2>/dev/null)"; then
      warn "skipping proposed_file_scope deposit for '${path}': mktemp failed"
      exit 0
    fi
    if jq --arg p "$path" \
        '.proposed_file_scope = (
           (((.proposed_file_scope // []) | if (type == "array") then . else [] end)) as $existing
           | if ($existing | index($p)) then $existing else ($existing + [$p]) end
         )' \
        "$meta_file" > "$tmp_file" 2>/dev/null \
      && mv "$tmp_file" "$meta_file" 2>/dev/null; then
      exit 0
    fi
    warn "skipping proposed_file_scope deposit for '${path}': jq update or atomic move failed"
    rm -f "$tmp_file" 2>/dev/null || true
    exit 0
  ) 200> "$lock_file" || warn "skipping proposed_file_scope deposit for '${path}': flock failed"

  return 0
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

# --- Repository Classification (see "REPOSITORY CLASSIFICATION" header subsection). Runs BEFORE
# the Containment Self-Check below so a source-store or out-of-repository path can never reach
# the scope test. Fail-soft on an unavailable library (declare -F guard): every files_touched
# entry is left untouched and the Containment Self-Check below runs exactly as it did before
# this classification existed. ---
# source_store_commits: one tab-joined record per SOURCE_STORE-classified path --
# "<extension><TAB><source_toplevel><TAB><rel_path><TAB><original_path>" -- consumed by Phase 4's
# wiring (added in a later change) to attempt a fail-open commit in that path's own repository.
# Declared unconditionally (even when empty) so a caller added later can rely on it existing.
source_store_commits=()
if [ "${#files_touched[@]}" -gt 0 ] && declare -F source_store_classify >/dev/null 2>&1; then
  _rc_kept=()
  for f in "${files_touched[@]}"; do
    _rc_out="$(source_store_classify "$PROJECT_ROOT" "$f" 2>/dev/null || echo "IN_REPO")"
    _rc_verdict="${_rc_out%%$'\t'*}"
    case "$_rc_verdict" in
      SOURCE_STORE)
        IFS=$'\t' read -r _ _rc_ext _rc_toplevel _rc_rel <<< "$_rc_out"
        warn "dropping '${f}' from this repository's commit — classified as belonging to extension '${_rc_ext}'s source store at ${_rc_toplevel} (path inside that repository: ${_rc_rel:-$f}); it must be committed there, not here"
        bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind issue \
          --class "source store excursion" --severity minor \
          --what-happened "git-commit-phase.sh dropped '${f}' from a phase commit pathspec: classified as belonging to extension '${_rc_ext}'s source store at ${_rc_toplevel}, not this repository." \
          --phase implement \
          >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
        source_store_commits+=("${_rc_ext}"$'\t'"${_rc_toplevel}"$'\t'"${_rc_rel}"$'\t'"${f}")
        ;;
      OUT_OF_REPO)
        IFS=$'\t' read -r _ _rc_parent <<< "$_rc_out"
        warn "dropping '${f}' from this repository's commit — this path lies outside this repository (resolves under ${_rc_parent}); no extension's source store claims it, so there is no repository this script can commit it in"
        bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind issue \
          --class "source store excursion" --severity minor \
          --what-happened "git-commit-phase.sh dropped '${f}' from a phase commit pathspec: path resolves outside this repository (${_rc_parent}); not a declared-scope issue." \
          --phase implement \
          >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
        ;;
      *)
        _rc_kept+=("$f")
        ;;
    esac
  done
  files_touched=("${_rc_kept[@]}")
  if [ "${#files_touched[@]}" -eq 0 ]; then
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

    # Within-dispatch proposed_file_scope lookup (read-only; NOT unioned into file_scope_arr):
    # closes PART B's within-dispatch window -- a path containment-dropped by an earlier phase's
    # own commit in THIS SAME dispatch must not be treated as a FRESH drop incident by a later
    # phase's commit -- without changing what actually gets staged. Reads THIS task's own
    # currently-deposited `proposed_file_scope` array from its own `.return-meta.json`, resolved
    # exactly as `propose_file_scope_addition()` resolves it (`${task_dir}/.return-meta.json`),
    # with the same skip-if-absent, skip-if-malformed posture -- never a cross-task read.
    #
    # Deliberately NOT unioned into `file_scope_arr`/`is_contained()`: doing so would make THIS
    # script admit the path into `kept_files_touched`/`stage_paths`, which are then handed to
    # git-commit-scoped.sh -- but that script carries its OWN, separate V10 containment guard
    # (context/standards/git-staging-scope.md's "Three Containment sites, not one", Site 3),
    # which re-reads the UNWIDENED `file_scope` straight from `specs/state.json` and has no
    # override channel once `--task` is passed (always is, here). A path admitted here but still
    # vetoed by Site 3 would make this script report a false success while the path silently
    # never lands -- worse than today's honest, visible drop. `proposed_file_scope_lookup` is
    # therefore consulted ONLY to suppress a repeat `warn()`/`issue-record.sh` call for a drop
    # already recorded earlier in this dispatch; the admit/reject decision below is unchanged,
    # `propose_file_scope_addition()` is still called (harmless: it is itself idempotent), and
    # the path is still excluded from staging exactly as before Phase 3. See this task's own
    # implementation summary for the full citation of why a true within-dispatch union was
    # rejected, and for the recorded Site-3 residual this leaves for a future task to close.
    proposed_file_scope_lookup=()
    _fsa_meta_file="${task_dir}/.return-meta.json"
    if [ -f "$_fsa_meta_file" ] && jq empty "$_fsa_meta_file" >/dev/null 2>&1; then
      while IFS= read -r _fsa_proposed; do
        # Exclude a deployed-tree entry from the lookup even if one somehow reached
        # proposed_file_scope (hand-edited, or a future bug in propose_file_scope_addition()'s
        # own refusal): the lookup's only purpose is to annotate a warning as "already known,
        # land it with a follow-up commit", and a deployed-tree path must never be annotated
        # that way -- it is never legitimate to land, follow-up or otherwise.
        case "$_fsa_proposed" in
          .claude|.claude/|.claude/*) continue ;;
        esac
        [ -n "$_fsa_proposed" ] && proposed_file_scope_lookup+=("$_fsa_proposed")
      done < <(jq -r 'if (.proposed_file_scope? // [] | type) == "array" then (.proposed_file_scope // [])[] else empty end' "$_fsa_meta_file" 2>/dev/null || true)
    fi

    # Deployed-tree strip (see "Deployed-tree refusal" subsection below): drop every entry
    # equal to `.claude`/`.claude/` or prefixed `.claude/` from the task's own declared
    # file_scope BEFORE the own-task-directory and engine-written-state splices below -- a
    # deployed-tree path is never a legitimate file_scope member (Hard Constraint:
    # rules/source-store-deploy-boundary.md), and residue from an older, un-refused declaration
    # must not re-admit a deployed-tree path into this Containment check. A pure structural
    # prefix test on the string, never a filesystem/existence check. Non-emptiness is re-tested
    # by the very next guard below: if nothing survives the strip, the existing fail-open path
    # (skip the whole Containment check) fires exactly as it does for a missing/empty
    # file_scope today -- this ordering (strip, then test) is why the splices are never
    # relocated out of the non-empty guard.
    _fsa_stripped=()
    for _fsa_entry in "${file_scope_arr[@]}"; do
      case "$_fsa_entry" in
        .claude|.claude/|.claude/*)
          warn "stripped deployed-tree file_scope entry '${_fsa_entry}': never a legitimate file_scope member (see rules/source-store-deploy-boundary.md); declare a whole-deployed-tree claim with the \`__WHOLE_TREE__\` sentinel instead"
          ;;
        *)
          _fsa_stripped+=("$_fsa_entry")
          ;;
      esac
    done
    file_scope_arr=("${_fsa_stripped[@]}")

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

      # already_proposed <path> -- true if <path> is already a member of this dispatch's own
      # within-dispatch proposed_file_scope_lookup (an exact-string test: deposited entries are
      # always literal files_touched strings, never a directory/glob form). Used only to
      # suppress a repeat warn()/issue-record.sh call below for a drop already recorded earlier
      # in this same dispatch -- see the "Within-dispatch proposed_file_scope lookup" comment
      # above for why this never changes the admit/reject decision itself.
      already_proposed() {
        local path="$1" entry
        for entry in "${proposed_file_scope_lookup[@]}"; do
          [ "$path" = "$entry" ] && return 0
        done
        return 1
      }

      kept_files_touched=()
      for f in "${files_touched[@]}"; do
        if is_contained "$f"; then
          kept_files_touched+=("$f")
        else
          # already_proposed() never changes this drop's outcome or suppresses the warn()/
          # issue-record.sh/propose_file_scope_addition() calls below -- all three still fire
          # unconditionally, exactly as before this phase, so every pre-existing fixture's
          # assumption that a repeated drop keeps producing a fresh, git-visible issues.jsonl
          # row stays intact. It ONLY annotates the warning text with a pointer to the
          # already-known-and-recorded status, so a within-dispatch repeat of a drop already
          # seen earlier reads as "still open, go land it" rather than appearing identical to a
          # brand-new incident -- the one piece of this phase's "within-dispatch window" goal
          # achievable without admitting the path into `kept_files_touched`/staging (see the
          # "Within-dispatch proposed_file_scope lookup" comment above for why admitting it
          # there was rejected).
          if already_proposed "$f"; then
            warn "dropping out-of-scope path '${f}' from phase commit — not in task ${task_number}'s declared file_scope (already recorded in proposed_file_scope earlier in this dispatch -- land it with a scoped follow-up commit rather than a widened pathspec)"
          else
            warn "dropping out-of-scope path '${f}' from phase commit — not in task ${task_number}'s declared file_scope"
          fi
          bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind issue \
            --class "scope excursion" --severity minor \
            --what-happened "git-commit-phase.sh dropped '${f}' from a phase commit pathspec: not contained in this task's declared file_scope." \
            --phase implement \
            >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
          propose_file_scope_addition "$f"
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

# --- Second-repository commit for every SOURCE_STORE-classified path (see "REPOSITORY
# CLASSIFICATION" header subsection). Invoked once per source_store_commits entry, AFTER this
# script's own commit above has already returned, so a second-repository failure can never
# affect this repository's own commit or exit code. FAIL-OPEN UNCONDITIONALLY: the result is
# captured, never propagated -- this script's own exit-code vocabulary (0-6) is unchanged by
# this block, matching commit-source-store-path.sh's own documented "no caller may treat a
# non-zero result as fatal" contract. The Phase 3 drop warning above is made outcome-aware here:
# it now also states whether the second-repository commit succeeded (naming the resulting
# revision) or did not (naming why and the exact manual command, already printed by
# commit-source-store-path.sh itself on stderr). Each outcome is additionally recorded via a
# non-fatal issue-record.sh call, win or loss alike. ---
if [ "${#source_store_commits[@]}" -gt 0 ] && [ -x "${SCRIPT_DIR}/commit-source-store-path.sh" ]; then
  for _ssc_record in "${source_store_commits[@]}"; do
    IFS=$'\t' read -r _ssc_ext _ssc_toplevel _ssc_rel _ssc_orig <<< "$_ssc_record"
    set +e
    _ssc_out="$(bash "${SCRIPT_DIR}/commit-source-store-path.sh" "$_ssc_toplevel" "$_ssc_rel" "$message" "$session_id" 2>&1)"
    _ssc_rc=$?
    set -e
    case "$_ssc_rc" in
      0)
        _ssc_sha="$(echo "$_ssc_out" | tail -1)"
        warn "second-repository commit SUCCEEDED for '${_ssc_orig}' (extension '${_ssc_ext}') in ${_ssc_toplevel} at revision ${_ssc_sha}"
        bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind win \
          --class "source store excursion" --severity none \
          --what-happened "commit-source-store-path.sh committed '${_ssc_orig}' in extension '${_ssc_ext}'s source store (${_ssc_toplevel}) at revision ${_ssc_sha}." \
          --phase implement \
          >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
        ;;
      1)
        warn "second-repository commit for '${_ssc_orig}' (extension '${_ssc_ext}') found nothing to commit in ${_ssc_toplevel} -- it may already be landed there"
        ;;
      *)
        warn "second-repository commit FAILED for '${_ssc_orig}' (extension '${_ssc_ext}') in ${_ssc_toplevel} (exit ${_ssc_rc}) -- it was NOT committed there. Run it by hand: bash '${SCRIPT_DIR}/commit-source-store-path.sh' '${_ssc_toplevel}' '${_ssc_rel}' '<message>' '${session_id}'. Detail: ${_ssc_out}"
        bash "${SCRIPT_DIR}/issue-record.sh" --task "$task_number" --kind issue \
          --class "source store excursion" --severity minor \
          --what-happened "commit-source-store-path.sh did NOT commit '${_ssc_orig}' in extension '${_ssc_ext}'s source store (${_ssc_toplevel}): exit ${_ssc_rc}. Manual follow-up required." \
          --phase implement \
          >/dev/null 2>&1 || warn "issue-record.sh call failed (non-fatal)"
        ;;
    esac
  done
fi

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
