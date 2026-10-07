#!/usr/bin/env bash
# git-commit-scoped.sh — the single sanctioned implementation of the scoped-commit contract.
#
# Every commit site in the dispatch pipeline previously staged narrowly (targeted `git add`) but
# then committed with a BARE `git commit`, which commits the ENTIRE shared index rather than just
# the paths staged — so a concurrently-dispatched agent's staged-but-uncommitted work got swept
# into whichever agent committed next. This script closes that defect for every caller, and
# additionally serializes the git add + git commit pair through the specs/.commit-lock/ mutex (see
# scripts/task-lock.sh's commit-acquire/commit-release verbs and
# context/patterns/task-lock.md's Scope-Mutex CLI section) so path-scoping alone does not simply
# convert misattribution into an `index.lock` commit-failure race under true concurrency.
#
# Usage:
#   git-commit-scoped.sh --message <msg> --session <session_id> \
#       [--honest-index-rows <task_number>] [--task <task_number>] -- <pathspec>...
#
# --task <task_number>: opt-in (empty-value-skips-flag, like --honest-index-rows). When given,
# consults the cycle-scoped contended-path manifest (orchestrate-cycle-plan.sh's
# build_contended_manifest, specs/.contention-manifest/*.json) for each POSITIVE pathspec entry.
# A path NOT listed in any manifest proceeds exactly as before -- this is the common case and is
# byte-identical to a caller that omits --task entirely. A listed path is claimed via
# task-lock.sh's claim-acquire/claim-release (a first-claim lease per declared manifest path,
# specs/.contention-claims/<path>) BEFORE any git add is attempted: unclaimed -> claim, stage,
# commit, release; claimed by this same task -> proceed (re-entrant); claimed by another live
# task -> REFUSE before any git add, with nothing staged, naming the path, the holding task, and
# the release condition (the holder's own commit or its claim's staleness timeout) -- direct the
# caller to defer that path and re-sequence, never to widen the pathspec or force it. FAILS OPEN
# unconditionally: --task absent, a missing/unreadable/malformed manifest, or any error inside
# this check proceeds with today's behavior (plus a stderr notice for the error case) -- a
# concurrency guard must never be the reason an agent cannot commit at all. See the working-tree/
# build isolation posture decision record's Option 3(ii) for the full rationale.
#
# <msg> is the commit body WITHOUT the trailing "Session: ..." line — this script appends
# "\n\nSession: <session_id>\n" itself, so every call site gets an identical session-line
# convention without repeating it.
#
# <pathspec>... is one or more git pathspecs, exactly as would be passed to `git add`/`git commit
# --`. At least one POSITIVE (non-`:(exclude)...`) entry is required — see the V3 safety gate
# below. When any positive entry looks like a task directory (`specs/{NNN}_{slug}/`), the
# canonical ephemeral-runtime-file CANDIDATE set from context/standards/git-staging-scope.md is
# considered for that directory, so callers no longer need to spell out (or risk forgetting)
# `ephemeral_excludes` by hand. Each candidate is injected as an explicit `:(exclude)...` pathspec
# entry only when `git check-ignore` reports it is NOT already covered by `.gitignore` — see the
# injection loop below for why an unconditional injection is unsafe.
#
# --honest-index-rows <task_number>: when given, runs the same staged-vs-HEAD
# `specs/state.json` comparison `orchestrator-postflight.sh`'s Stage 9b previously ran inline,
# appending "Also carries current index rows for tasks: N, M" to the commit message when the
# staged state.json also carries OTHER tasks' current rows. Entirely failure-tolerant: any error
# (missing HEAD ref on a first commit, unparseable JSON, no staged state.json) omits the addendum
# and falls through to the plain message — this must never break a commit.
#
# Exit codes:
#   0 - commit created
#   1 - "nothing to commit" (identical to a bare `git commit`'s own exit code — V4) or the git
#       commit itself failed after the bounded index.lock retry; non-blocking, matches every call
#       site's existing `|| echo "Note: Nothing to commit..."` fallback
#   2 - usage error, the V3 degenerate-pathspec refusal (exclude-only list; refused before any
#       git add/commit), or git add left one or more staged paths genuinely unstaged (verified
#       against the index, not inferred from git add's exit code — see V7)
#   3 - contended-path refusal (V5, --task only): a positive pathspec entry is listed as
#       contended in the cycle manifest AND currently claimed by ANOTHER live task. Refused
#       before any git add; nothing staged. Never emitted when --task is omitted.
#   4 - the V6 refusal below: one or more positive pathspecs were dropped as genuinely unmatched
#       (V2 case 3) AND the commit attempt produced no commit (exit code 1, "nothing to
#       commit"). Non-blocking under every current caller's `cmd || echo "WARN: ...(non-
#       blocking)"` idiom (bash's `A || B` yields B's exit status regardless of A's own code),
#       so this is observability, not an enforcement change — see V6 below.
#
# Safety gates (empirically discovered; see specs/908_.../reports/02_commit-site-inventory.md):
#   V2 - an unmatched path in the commit pathspec aborts the WHOLE commit in bare git. This
#        script instead classifies each positive pathspec into THREE outcomes: (1) matched --
#        present on disk or already tracked, added and committed as before; (2) an
#        already-staged deletion -- absent from both the working tree and the index but present
#        in HEAD (a `git rm`, or the delete half of a `git mv`), which is committed via
#        `git commit --` but deliberately withheld from `git add` (a single all-or-nothing call
#        that would otherwise exit 128 and abort staging for every other path in the same
#        pathspec set); or (3) genuinely unmatched -- neither on disk, tracked, nor in HEAD --
#        DROPPED with a loud warning exactly as before, never passed through to git add/git
#        commit. A staged deletion whose path is NOT named in the caller's pathspec list at all
#        (out-of-scope) is left out of the commit silently, uniformly with every other
#        out-of-scope change type -- see context/standards/git-staging-scope.md's
#        "under-stage, never over-stage" fail-safe direction; no refuse logic is added for this
#        case.
#   V3 - an exclude-only pathspec list commits EVERYTHING except the excluded paths — wider than
#        a bare commit, not narrower. This script refuses outright (no git add, no commit) if the
#        pathspec list contains zero positive entries, both before and after V2 filtering (since
#        filtering itself can produce a degenerate list).
#   V5 - explicit-path staging alone does not protect against CONCURRENT same-file dispatch: two
#        tasks can each stage only their own paths, correctly and narrowly, and still bleed into
#        each other's commit when both touch the SAME file in the SAME shared working tree (see
#        the working-tree/build isolation posture decision record's mode-1b finding). --task
#        opts a caller into the fix: a per-path first-claim lease consulted against the
#        cycle-scoped contention manifest before any git add is attempted.
#   V6 - a PARTIAL pathspec drop (some, not all, positive entries hit V2 case 3) is indistinguishable
#        from the ordinary, benign "nothing changed" no-op once the survivors themselves carry no
#        diff: both shapes land on `git commit`'s own exit 1 ("nothing to commit"), and the one
#        difference -- a WARN line on stderr -- is not inspected by any current caller. (V3 above
#        already refuses the OTHER half of this gap, where EVERY positive pathspec drops; V6
#        covers what V3 does not.) This script refuses to report that ambiguous outcome as plain
#        "nothing to commit": when at least one pathspec was dropped as genuinely unmatched AND
#        the commit attempt produced no commit, it exits `4` with a loud ERROR naming every
#        dropped path, instead of falling through to the generic NOTE. The predicate deliberately
#        does NOT try to distinguish "nothing to commit" from "git commit genuinely failed" by
#        parsing commit output -- both sub-cases are already nonzero and already swallowed
#        identically by every current caller, so splitting them buys nothing and adds a
#        dependency on git's own wording. See context/standards/git-staging-scope.md for the
#        recorded caller-escalation residual: no caller branches on this exit code today.
#   V7 - `git add`'s own exit code is unreliable in BOTH directions for a positive pathspec naming
#        a path that is TRACKED but whose path matches a `.gitignore` rule via a parent-directory
#        pattern: git prints "The following paths are ignored by one of your .gitignore files"
#        and exits 1 while CORRECTLY STAGING the file — a false negative, not a failure. `git
#        check-ignore -q` cannot detect this case either: it is index-aware and reports "not
#        ignored" for exactly these tracked paths, directly contradicting `git add`. This script
#        therefore trusts neither signal; it captures `git add`'s output and exit code without
#        branching on them, then verifies ACTUAL INDEX STATE per positive pathspec: present in
#        `git ls-files` and no residual `git diff` against the working tree. A path that fails
#        either check is genuinely unstaged (e.g. the sibling out-of-repo-pathspec hard failure,
#        which stages nothing and must keep refusing) and aborts the commit exactly as before; a
#        path that passes both checks is accepted even if `git add` exited nonzero, with a stderr
#        NOTE naming the tolerated case so it is never silent.
#        SECOND ACCEPTED SHAPE -- the fully-staged deletion: the index-presence half of that
#        verification is NOT universal, because a positive pathspec whose every tracked file
#        `git add` just staged as DELETED is correctly absent from `git ls-files` afterwards. The
#        source half of a directory move has exactly this shape (an archival pass that `mv`s a
#        task directory and names both the old and the new path in one call), and the index it
#        produces is already exactly right -- `git status` shows the rename staged -- so refusing
#        it rejected a correct commit. Such a pathspec is therefore accepted, under a predicate
#        narrow enough that no genuine failure slips through: absent from the working tree, HEAD
#        resolvable, and `git diff --cached HEAD -- <path>` exiting EXACTLY 1 (a staged change
#        exists). Exit 0 (nothing staged there -- a genuine drop) and any code above 1 (git
#        errors, notably the 128 of an out-of-repo pathspec) both keep refusing. This acceptance
#        can only ever convert a false refusal into a commit: it is unreachable whenever the
#        index still holds an entry for the pathspec, which is the only state in which a real
#        add failure leaves a path behind. Residual blind spot, deliberate and
#        unchanged from pre-existing behavior: a single newly-created, ignore-matched file swept
#        up IMPLICITLY inside a directory pathspec that also covers other already-tracked files is
#        not independently verified by this per-positive-pathspec loop (the directory entry itself
#        is what is checked) — the same "an ignored path swept up implicitly is silently skipped"
#        behavior already documented in context/standards/git-staging-scope.md, not a gap
#        introduced here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

usage() {
  echo "Usage: $0 --message <msg> --session <session_id> [--honest-index-rows <task_number>] -- <pathspec>..." >&2
  exit 2
}

message=""
session_id=""
honest_task_number=""
contention_task_number=""
pathspecs=()

while [ "$#" -gt 0 ]; do
  case "$1" in
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
    --honest-index-rows)
      [ "$#" -ge 2 ] || usage
      honest_task_number="$2"
      shift 2
      ;;
    --task)
      [ "$#" -ge 2 ] || usage
      contention_task_number="$2"
      shift 2
      ;;
    --)
      shift
      pathspecs=("$@")
      break
      ;;
    *)
      usage
      ;;
  esac
done

[ -n "$message" ] || usage
[ -n "$session_id" ] || usage
[ "${#pathspecs[@]}" -gt 0 ] || usage

cd "$PROJECT_ROOT" || exit 2

# --- has_positive_pathspec: true if the given array has at least one non-exclude entry ---
has_positive_pathspec() {
  local p
  for p in "$@"; do
    case "$p" in
      :\(exclude\)*) ;;
      *) return 0 ;;
    esac
  done
  return 1
}

# --- V3 safety gate (pre-filter): refuse a degenerate, exclude-only caller-supplied list ---
if ! has_positive_pathspec "${pathspecs[@]}"; then
  echo "ERROR: git-commit-scoped.sh refuses to commit — the pathspec list contains zero positive (non-exclude) entries. An exclude-only pathspec list commits EVERYTHING except the excluded paths, which is WIDER than a bare commit, not narrower (Verified Finding V3). No git add or git commit was attempted." >&2
  exit 2
fi

# --- Inject the canonical ephemeral-runtime-file exclusion set for any task-directory entry ---
# Mirrors context/standards/git-staging-scope.md's ephemeral_excludes CANDIDATE array exactly
# (same four names, same order); injection is conditional, not unconditional. Applied here
# (rather than left to each caller) so every call site is protected uniformly, closing the
# staleness gap where the exclusion set had drifted out of sync at nine of eleven commit sites.
#
# Why conditional: naming an already-gitignored path in an explicit `:(exclude)...` pathspec
# entry makes `git add` treat it as an EXPLICITLY-NAMED ignored path and refuse the WHOLE add
# ("The following paths are ignored by one of your .gitignore files") whenever that path
# currently exists on disk — e.g. a held task lock's `.lock/` directory. An ignored path swept up
# IMPLICITLY by a bare directory pathspec (no exclude entry naming it) is, by contrast, silently
# skipped by `git add` with no error. So for a candidate `.gitignore` already covers, the exclude
# entry was pure downside — it added an abort hazard while contributing nothing `.gitignore`
# wasn't already doing. Each candidate is therefore injected only when `git check-ignore -q`
# reports it is NOT already covered (non-zero exit); a repo that has not applied the ephemeral
# `.gitignore` block still gets the injected entries verbatim, same as before this change.
#
# Fall-through direction is deliberately safe: ONLY exit code 0 (definitively ignored) skips
# injection. Exit 1 (not ignored) and exit 128 (error, e.g. malformed pathspec) both fall through
# to injecting the entry, matching pre-conditional behavior. Do NOT "simplify" this into
# `if ! git check-ignore ...; then continue` — that would invert the safe direction and skip
# injection on error instead of on confirmed coverage.
expanded_pathspecs=()
for p in "${pathspecs[@]}"; do
  expanded_pathspecs+=("$p")
  case "$p" in
    specs/[0-9][0-9][0-9]_*/)
      task_dir="${p%/}"
      candidate_excludes=(
        "${task_dir}/.orchestrator-loop-guard"
        "${task_dir}/.orchestrator-churn-state.json"
        "${task_dir}/.drift-inspection.json"
        "${task_dir}/.lock/"
        "${task_dir}/.dispatch/"
      )
      for eph in "${candidate_excludes[@]}"; do
        if git check-ignore -q -- "$eph"; then
          : # already covered by .gitignore -- injecting would only add an abort hazard, skip
        else
          expanded_pathspecs+=(":(exclude)${eph}")
        fi
      done
      ;;
  esac
done
pathspecs=("${expanded_pathspecs[@]}")

# --- V5 contended-path refusal (--task opt-in only; see the header's V5 note) ---
# Runs BEFORE V2/V3 and before any git add — a refusal here must leave nothing staged. Iterates
# the caller's own POSITIVE pathspec entries (exactly as given; exclude entries are never
# checked, same scope as every gate above) against every manifest file under
# specs/.contention-manifest/*.json. Unconditionally fail-open: --task omitted, the manifest
# directory absent or empty, or any error while reading a manifest file falls through to today's
# behavior (no claim, no refusal) — this check must never be the reason a commit cannot happen.
contended_claims_acquired=()

release_contended_claims() {
  local p
  for p in "${contended_claims_acquired[@]:-}"; do
    [ -n "$p" ] || continue
    bash "$SCRIPT_DIR/task-lock.sh" claim-release "$p" "$contention_task_number" >&2 || true
  done
}

if [ -n "$contention_task_number" ]; then
  contention_manifest_dir="$PROJECT_ROOT/specs/.contention-manifest"
  if [ -d "$contention_manifest_dir" ]; then
    for p in "${pathspecs[@]}"; do
      case "$p" in
        :\(exclude\)*) continue ;;
      esac

      contended_here="false"
      manifest_file=""
      for manifest_file in "$contention_manifest_dir"/*.json; do
        [ -e "$manifest_file" ] || continue
        jq_rc=0
        jq -e --arg p "$p" '.contended // [] | any(.path == $p)' "$manifest_file" >/dev/null 2>/dev/null || jq_rc=$?
        if [ "$jq_rc" -eq 0 ]; then
          contended_here="true"
          break
        elif [ "$jq_rc" -gt 1 ]; then
          echo "WARN: git-commit-scoped.sh could not parse contention manifest '$manifest_file' (malformed/unreadable) — skipping it for this check (fail-open)." >&2
        fi
      done

      [ "$contended_here" = "true" ] || continue

      claim_out=""
      claim_rc=0
      claim_out=$(bash "$SCRIPT_DIR/task-lock.sh" claim-acquire "$p" "$contention_task_number" "$session_id") || claim_rc=$?
      if [ "$claim_rc" -eq 0 ]; then
        claim_status=$(echo "$claim_out" | jq -r '.status // ""' 2>/dev/null) || claim_status=""
        if [ "$claim_status" = "claimed" ]; then
          contended_claims_acquired+=("$p")
        fi
        # "already_self" (re-entrant): proceed without adding to the release list — this
        # invocation did not freshly acquire it, so it must not release someone else's hold.
      else
        holder_task=$(echo "$claim_out" | jq -r '.holder_task // "unknown"' 2>/dev/null) || holder_task="unknown"
        echo "ERROR: git-commit-scoped.sh refuses to commit — path '$p' is contended this cycle and currently claimed by task #${holder_task} (Verified Finding V5, mode-1b: explicit-path staging alone does not protect against concurrent same-file dispatch). Nothing was staged. Defer this path and re-sequence after task #${holder_task}'s own commit lands (or the claim's staleness timeout elapses) — never widen the pathspec or force it." >&2
        release_contended_claims
        exit 3
      fi
    done
  fi
fi

# --- V2 safety gate: classify each positive pathspec into one of THREE outcomes, not two ---
# Exclude pathspecs pass through unvalidated into BOTH arrays below (git itself never resolves
# them against the working tree the way it does a positive entry, and validating them would
# require reimplementing git's own pathspec-exclusion matching).
#
# filtered_pathspecs is the set handed to `git commit --` (must include every already-staged
# deletion, or the deletion silently never reaches the commit). add_pathspecs is the set handed
# to `git add` (must EXCLUDE an already-staged deletion — see case 2 below). The two sets are
# identical except for case 2, which is exactly why they must be two separate arrays rather than
# one shared `pathspecs` array as before.
filtered_pathspecs=()
add_pathspecs=()
# dropped_pathspecs (V6): every pathspec dropped by case 3 below -- never case 1 or case 2 --
# so the V6 gate after the commit attempt can tell a genuine drop apart from a routine no-op.
dropped_pathspecs=()
for p in "${pathspecs[@]}"; do
  case "$p" in
    :\(exclude\)*)
      filtered_pathspecs+=("$p")
      add_pathspecs+=("$p")
      ;;
    *)
      if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
        # Case 1 — matched: present on disk, or already tracked. Unchanged behavior: goes to
        # both the add set and the commit set.
        filtered_pathspecs+=("$p")
        add_pathspecs+=("$p")
      elif git rev-parse --verify -q HEAD >/dev/null 2>&1 && git cat-file -e "HEAD:$p" 2>/dev/null; then
        # Case 2 — already-staged deletion: absent from BOTH the working tree and the index (so
        # case 1 above did not match), but present in HEAD, meaning a `git rm` or the delete half
        # of a `git mv` already removed it from the index. It is fully reflected in the index
        # already, so it belongs in the commit's pathspec set (filtered_pathspecs) but must be
        # kept OUT of add_pathspecs: `git add` on a path absent from both disk and index exits
        # 128, and because `git add "${add_pathspecs[@]}"` below is a single all-or-nothing
        # invocation, that one bad entry would abort staging for every other path in the same
        # call — silently converting today's "deletion dropped" bug into a louder "whole commit
        # aborted" bug for any mixed add+delete path set. Do NOT "fix" this by adding the path to
        # add_pathspecs; that reintroduces the exact failure this branch exists to avoid.
        filtered_pathspecs+=("$p")
      else
        # Case 3 — genuinely unmatched: neither on disk, nor tracked, nor in HEAD. Drop with the
        # existing WARN message, unchanged behavior. Also recorded in dropped_pathspecs (V6) --
        # this is the ONLY branch that appends to it; case 1 and case 2 above must never touch it.
        echo "WARN: git-commit-scoped.sh dropping unmatched pathspec '${p}' (no such file/directory on disk and not tracked by git); this path will NOT be part of the commit." >&2
        dropped_pathspecs+=("$p")
      fi
      ;;
  esac
done

# --- V3 safety gate (post-filter): filtering itself can produce a degenerate list ---
# Evaluated against filtered_pathspecs (the commit set), not add_pathspecs: a deletion-only
# commit legitimately has zero entries in add_pathspecs (nothing to add) while still having one
# positive entry in filtered_pathspecs (the deletion itself), and that is a valid, non-degenerate
# commit, not a V3 refusal case.
if ! has_positive_pathspec "${filtered_pathspecs[@]}"; then
  echo "ERROR: git-commit-scoped.sh refuses to commit — after dropping unmatched paths, zero positive pathspec entries remain (would degenerate into an exclude-only commit, Verified Finding V3). No git add or git commit was attempted." >&2
  exit 2
fi

pathspecs=("${filtered_pathspecs[@]}")

# --- specs/.commit-lock/ mutex: fail-open with a loud warning, mirroring update-task-status.sh's
# acquire_state_mutex pattern for specs/.scope-lock exactly (a distinct mutex, distinct
# reentrancy flag — see task-lock.sh's top-of-file comment for why the two must never share a
# flag). Released via an EXIT trap so no code path below can leak the mutex. ---
COMMIT_MUTEX_TOKEN=""
COMMIT_MUTEX_OWNED_HERE="false"

release_commit_mutex_guarded() {
  if [ "$COMMIT_MUTEX_OWNED_HERE" = "true" ]; then
    bash "$SCRIPT_DIR/task-lock.sh" commit-release "$COMMIT_MUTEX_TOKEN" >&2 || true
    COMMIT_MUTEX_OWNED_HERE="false"
    unset COMMIT_MUTEX_HELD
  fi
  # V5 contended-path claims (see the block above this section): release on EVERY exit path
  # (success, git-commit failure, or an early refusal that already released inline) — a single
  # trap-driven cleanup point, same shape as the commit mutex directly above. Idempotent: a path
  # already released by the inline exit-3 refusal call finds no claim directory and is a no-op.
  release_contended_claims
}
trap release_commit_mutex_guarded EXIT

if [ -n "${COMMIT_MUTEX_HELD:-}" ]; then
  echo "Note: an outer holder already owns the specs/.commit-lock mutex (COMMIT_MUTEX_HELD=1 inherited); running as guest, no nested acquire." >&2
else
  commit_token=""
  if commit_token=$(bash "$SCRIPT_DIR/task-lock.sh" commit-acquire "$session_id"); then
    COMMIT_MUTEX_TOKEN="$commit_token"
    COMMIT_MUTEX_OWNED_HERE="true"
    export COMMIT_MUTEX_HELD=1
  else
    echo "WARNING: failed to acquire specs/.commit-lock mutex (session=${session_id}); proceeding unserialized (non-blocking, fail-open). Worst case is the safe index.lock race, not commit misattribution, since this commit is still path-scoped." >&2
  fi
fi

# --- git add (guarded; a genuine failure here aborts before any commit is attempted) ---
# Uses add_pathspecs (the case-2-excluded set from the V2 gate above), never the full pathspecs
# array used for the commit below. Skipped entirely when add_pathspecs carries no positive
# entries — a deletion-only commit, where every positive pathspec landed in the already-staged-
# deletion case above and there is nothing left to add; invoking `git add` with an empty or
# exclude-only list is unnecessary and, for the exclude-only shape, exactly the V3 hazard this
# script guards against elsewhere.
#
# V7: `git add`'s exit code is trusted in NEITHER direction (see the header's V7 note). The add's
# output and exit code are captured without branching on them, then every positive pathspec is
# verified against actual index state. Only a genuinely-failed path aborts the commit.
if has_positive_pathspec "${add_pathspecs[@]}"; then
  add_positive_pathspecs=()
  add_exclude_pathspecs=()
  for p in "${add_pathspecs[@]}"; do
    case "$p" in
      :\(exclude\)*) add_exclude_pathspecs+=("$p") ;;
      *) add_positive_pathspecs+=("$p") ;;
    esac
  done

  # `-e`-exempt capture idiom (mirrors the git commit capture further below): a nonzero exit here
  # is a routine, documented possibility (the V7 advisory false negative), not necessarily an
  # error, so it must not abort the script before the per-path verification below can run.
  if add_output=$(git add "${add_pathspecs[@]}" 2>&1); then
    add_exit=0
  else
    add_exit=$?
  fi

  genuinely_failed_adds=()
  staged_deletion_adds=()
  for p in "${add_positive_pathspecs[@]}"; do
    if ! git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
      # Absence from the index is the CORRECT post-add state for a pathspec whose every tracked
      # file `git add` just staged as deleted -- the source half of a directory move (the common
      # shape: an archival pass that `mv`s a task directory and names both old and new paths in
      # one call). Treating that as a failure refuses a commit whose index is already exactly
      # right, which is why this branch exists: verify the fully-staged-deletion shape before
      # falling through to the refusal.
      #
      # The exit code of `git diff --cached HEAD` is read EXACTLY, never as a boolean: 1 means
      # "a staged change exists for this pathspec" (for a path absent from both index and disk
      # that can only be the deletion), 0 means "nothing staged here" (never tracked -- a
      # genuine drop), and anything above 1 (notably 128) is a git error such as an out-of-repo
      # pathspec. Only 1 is accepted, so the out-of-repo hard failure keeps refusing exactly as
      # before; a `! git diff ...` boolean test would wrongly accept the 128 case.
      staged_deletion_rc=0
      git diff --cached --quiet HEAD -- "$p" >/dev/null 2>&1 || staged_deletion_rc=$?
      if [ ! -e "$p" ] \
         && [ "$staged_deletion_rc" -eq 1 ] \
         && git rev-parse --verify -q HEAD >/dev/null 2>&1; then
        staged_deletion_adds+=("$p")
        continue
      fi
      genuinely_failed_adds+=("${p} (not present in the index at all)")
      continue
    fi
    diff_check_args=("$p")
    if [ "${#add_exclude_pathspecs[@]}" -gt 0 ]; then
      diff_check_args+=("${add_exclude_pathspecs[@]}")
    fi
    if ! git diff --quiet -- "${diff_check_args[@]}"; then
      genuinely_failed_adds+=("${p} (working tree still differs from the index — not fully staged)")
    fi
  done

  if [ "${#genuinely_failed_adds[@]}" -gt 0 ]; then
    echo "$add_output" >&2
    echo "ERROR: git-commit-scoped.sh refuses to commit — git add left one or more staged paths genuinely unstaged, verified against actual index state rather than inferred from git add's exit code (Verified Finding V7). Failing path(s): ${genuinely_failed_adds[*]}" >&2
    exit 2
  fi

  if [ "${#staged_deletion_adds[@]}" -gt 0 ]; then
    echo "NOTE: git-commit-scoped.sh accepted ${#staged_deletion_adds[@]} positive pathspec(s) as fully-staged deletions — absent from the index because git add staged every tracked file under them as deleted, which is the correct post-add state for the source half of a directory move, not an unstaged path (Verified Finding V7). Path(s): ${staged_deletion_adds[*]}" >&2
  fi

  if [ "$add_exit" -ne 0 ]; then
    echo "$add_output" >&2
    echo "NOTE: git-commit-scoped.sh tolerated git add's nonzero exit code (${add_exit}) because every positive pathspec verified present and fully staged against the index (Verified Finding V7). Known case: the gitignore advisory for a tracked path whose path matches a .gitignore rule — git prints \"ignored by one of your .gitignore files\" and exits 1 while correctly staging the file." >&2
  fi
fi

# --- Optional honest-index-rows addendum (moved verbatim from
# orchestrator-postflight.sh's former Stage 9b inline scan) ---
final_message="$message"
if [ -n "$honest_task_number" ]; then
  also_carries=$(python3 -c "
import json, subprocess, sys

def load_ref(ref):
    try:
        out = subprocess.run(['git', 'show', ref], capture_output=True, text=True, check=True).stdout
        return json.loads(out)
    except Exception:
        return None

head = load_ref('HEAD:specs/state.json')
staged = load_ref(':specs/state.json')
if head is None or staged is None:
    sys.exit(0)

head_map = {p.get('project_number'): p for p in head.get('active_projects', []) if 'project_number' in p}
staged_map = {p.get('project_number'): p for p in staged.get('active_projects', []) if 'project_number' in p}

changed = sorted(
    num for num, entry in staged_map.items()
    if num != ${honest_task_number} and head_map.get(num) != entry
)
print(', '.join(str(n) for n in changed))
" 2>/dev/null) || also_carries=""

  if [ -n "$also_carries" ]; then
    final_message="${message}

Also carries current index rows for tasks: ${also_carries}"
  fi
fi

full_message="${final_message}

Session: ${session_id}
"

# --- git commit, with one bounded retry (short randomized backoff) specifically for an
# index.lock failure — the residual race that remains when the mutex fails open above. ---
# `if VAR=$(cmd); then ... else status=$?; fi` rather than a bare `VAR=$(cmd)` followed by
# `status=$?`: git commit's exit code 1 ("nothing to commit") is a DOCUMENTED, routine outcome
# (see this script's own header), not an error -- under `set -e` a bare failing assignment would
# abort the script on this line, before commit_exit could ever be captured, the index.lock retry
# could run, or this script's own documented exit-code contract could be honored. Wrapping the
# assignment in the `if` test is `-e`-exempt and preserves the captured status exactly, mirroring
# the same fix applied to state-write.sh and task-lock.sh's cmd_acquire_retry.
if commit_output=$(git commit -m "$full_message" -- "${pathspecs[@]}" 2>&1); then
  commit_exit=0
else
  commit_exit=$?
fi

if [ "$commit_exit" -ne 0 ] && echo "$commit_output" | grep -qi 'index\.lock'; then
  echo "$commit_output" >&2
  echo "NOTE: git commit hit index.lock contention; retrying once after a short backoff." >&2
  sleep "0.$(( (RANDOM % 5) + 1 ))"
  if commit_output=$(git commit -m "$full_message" -- "${pathspecs[@]}" 2>&1); then
    commit_exit=0
  else
    commit_exit=$?
  fi
fi

echo "$commit_output"

# --- V6 safety gate: refuse to report an ambiguous "nothing to commit" when a pathspec was
# genuinely dropped. Fires ONLY when a drop occurred AND the commit attempt produced no commit --
# an all-resolve caller (dropped_pathspecs empty) always falls through to the unchanged NOTE/exit
# below, which is the dispatch's HARD CONSTRAINT. The array expansion is guarded behind the
# ${#dropped_pathspecs[@]} test so `set -u` never sees an unguarded empty-array expansion. ---
if [ "$commit_exit" -ne 0 ] && [ "${#dropped_pathspecs[@]}" -gt 0 ]; then
  echo "ERROR: git-commit-scoped.sh refuses to report success as plain \"nothing to commit\" -- one or more pathspecs were dropped as unmatched AND the commit attempt produced no commit (Verified Finding V6). Dropped path(s): ${dropped_pathspecs[*]}" >&2
  exit 4
fi

if [ "$commit_exit" -ne 0 ]; then
  echo "NOTE: Nothing to commit or git commit failed (non-blocking)" >&2
fi

exit "$commit_exit"
