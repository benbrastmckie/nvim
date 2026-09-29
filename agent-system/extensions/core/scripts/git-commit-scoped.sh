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
#       git add/commit), or `git add` failed for one or more staged paths
#   3 - contended-path refusal (V5, --task only): a positive pathspec entry is listed as
#       contended in the cycle manifest AND currently claimed by ANOTHER live task. Refused
#       before any git add; nothing staged. Never emitted when --task is omitted.
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
        # existing WARN message, unchanged behavior.
        echo "WARN: git-commit-scoped.sh dropping unmatched pathspec '${p}' (no such file/directory on disk and not tracked by git); this path will NOT be part of the commit." >&2
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

# --- git add (guarded; a failure here aborts before any commit is attempted) ---
# Uses add_pathspecs (the case-2-excluded set from the V2 gate above), never the full pathspecs
# array used for the commit below. Skipped entirely when add_pathspecs carries no positive
# entries — a deletion-only commit, where every positive pathspec landed in the already-staged-
# deletion case above and there is nothing left to add; invoking `git add` with an empty or
# exclude-only list is unnecessary and, for the exclude-only shape, exactly the V3 hazard this
# script guards against elsewhere.
if has_positive_pathspec "${add_pathspecs[@]}"; then
  if ! git add "${add_pathspecs[@]}"; then
    echo "WARNING: git add failed for one or more staged paths (non-blocking); no commit was attempted." >&2
    exit 2
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

if [ "$commit_exit" -ne 0 ]; then
  echo "NOTE: Nothing to commit or git commit failed (non-blocking)" >&2
fi

exit "$commit_exit"
