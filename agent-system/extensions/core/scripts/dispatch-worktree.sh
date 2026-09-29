#!/usr/bin/env bash
# dispatch-worktree.sh - Per-dispatch git-worktree lifecycle: provision, locate, release, prune.
#
# WHY THIS EXISTS: the working-tree and build isolation posture decision record
# (context/patterns/batch-orchestration-guardrails.md, "Working-Tree and Build Isolation
# Posture" section) selects per-dispatch git-worktree isolation for lean4/cslib `implement`
# dispatches, to remove three observed concurrent-dispatch failure modes at once: a sibling's
# working-tree revert (mode 1a), cross-task commit bleed into a shared file (mode 1b), and build
# contention over one shared `.lake` (mode 2). This script is the full worktree lifecycle:
# creation/teardown (`provision`/`path`/`release`/`prune`, added in Phase 4) and merge-back
# (`land`, added in Phase 5).
#
# WHAT THIS DOES:
#   provision <task_number> --session <sid> --seq <n>
#       Preflights free disk space and the concurrent-worktree cap, creates
#       `<PROJECT_ROOT>/.orchestrate-worktrees/<task_number>-<seq>` on branch
#       `orchestrate/task-<task_number>-<seq>` from HEAD, hardlink-clones `.claude/` (and `.lake/`
#       when the main tree has one) into it, asserts PROJECT_ROOT resolves INSIDE the new
#       worktree (never back to the main tree), and records the provision under
#       `specs/.worktree-registry/<task_number>-<seq>.json`. Idempotent: re-provisioning the
#       same `<task_number>-<seq>` while its record and worktree both still exist reuses them
#       rather than erroring or double-creating. Emits a JSON verdict on stdout; every diagnostic
#       goes to stderr.
#   path <task_number>
#       Resolves the most recently provisioned worktree path for a task from its registry
#       record. Prints the bare path (no JSON wrapper) on stdout; prints nothing and exits
#       non-zero when no record exists.
#   release <task_number> [--force]
#       Strips the worktree's hardlink-cloned `.claude/`/`.lake/` scratch (untracked-by-
#       construction, safe to discard), then `git worktree remove` (only `--force` when asked)
#       and deletes the registry record. Deliberately leaves the branch intact for later
#       inspection -- this script never deletes a branch.
#   prune --session <sid>
#       Reaps registry records (and their worktrees) whose recorded session differs from `<sid>`
#       AND whose `created_at` is older than `DISPATCH_WORKTREE_STALE_SEC`. A record naming the
#       CALLING session itself is never reaped regardless of age -- the caller is, by definition,
#       live. This reuses the age-based staleness pattern already established by
#       `specs/.commit-lock/`/`task-lock.sh` rather than inventing a new liveness primitive (a
#       genuine pid-liveness check would need the full session registry, which is a separate,
#       heavier mechanism this script does not depend on).
#   land <task_number> --session <sid>
#       Runs from the MAIN TREE (refuses outright if PROJECT_ROOT resolves under
#       `.orchestrate-worktrees/`, i.e. if invoked via a worktree's own hardlinked copy of this
#       script). Merges the dispatch branch (resolved from the registry record, same as
#       `path`/`release`) into the main tree's current HEAD via `git merge --no-ff`, after two
#       refusals that run BEFORE any `git add`/merge is attempted: (1) any path under `specs/**`
#       in the branch's diff against its merge-base -- a worktree's own `specs/` is a tracked,
#       HEAD-stale snapshot (see below), and merging it would overwrite live main-tree state; (2)
#       any branch-touched path the main tree currently has uncommitted modifications to -- surfaced
#       rather than silently merged over. A genuine merge conflict aborts the merge
#       (`git merge --abort`), leaves the branch AND worktree intact for human resolution, and is
#       never auto-resolved (no `-X ours`/`-X theirs`, ever). Already-merged-or-never-diverged is a
#       no-op. Emits exactly one JSON verdict on stdout -- `{"verdict": "landed" |
#       "nothing_to_land" | "refused_specs_paths" | "conflict" | "refused_dirty_overlap" |
#       "unavailable", ...}` -- with every diagnostic (including the wrapped `git merge`'s own
#       stdout/stderr) redirected to stderr, per the JSON-channel discipline
#       `lint-json-channel-discipline.sh` enforces repo-wide.
#
# WHY A HARDLINK CLONE, NEVER A SYMLINK, FOR `.claude/`: see the decision record's "A Corrected
# Rationale for Hardlink-Over-Symlink" subsection. In short: a symlinked `.claude/` is not a
# separate directory -- every write under it (locks, results, logs, any future ephemeral runtime
# path) lands physically in the MAIN tree's `.claude/`, reintroducing exactly the shared-mutable-
# resource hazard isolation exists to remove. A hardlink clone (`cp -al`) gives the worktree its
# own directory entries (independently rebindable via the same atomic-rename mechanism Phase 1
# confirmed Lake itself uses) while sharing disk blocks for anything unchanged.
#
# `specs/` IS TRACKED, SO IT IS NEVER TOUCHED HERE: a fresh worktree carries a HEAD-stale copy of
# `specs/state.json`/`specs/TODO.md`/every task directory. This script does not read or write
# anything under a worktree's own `specs/`; task artifacts (`.return-meta.json`, handoffs,
# reports/plans/summaries) are written by the dispatched agent to the MAIN tree's absolute paths,
# which the dispatch file names explicitly. Landing a branch that touched `specs/**` is refused
# outright by `land` -- this script's own registry writes (`specs/.worktree-registry/*.json`)
# are gitignored runtime state in the MAIN tree, not inside any worktree, and carry no such
# hazard.
#
# RUNTIME PATHS THIS SCRIPT OWNS (register any change here in
# context/standards/orchestrator-runtime-files.md and .gitignore, not just here):
#   <PROJECT_ROOT>/.orchestrate-worktrees/<task_number>-<seq>/   the worktree checkout itself
#   <PROJECT_ROOT>/specs/.worktree-registry/<task_number>-<seq>.json   the provisioning record
#
# Exit codes:
#   0  - success
#   2  - usage error
#   3  - `path`/`release` found no matching registry record
#   80 - `provision` refused: free-space preflight failed (below the configured floor, or the
#        available-space probe itself failed)
#   81 - `provision` refused: the concurrent-worktree cap is already reached
#   82 - `provision` refused: PROJECT_ROOT did not resolve inside the new worktree; the worktree
#        was torn down before returning
#   83 - `provision` refused: the main tree has no `.claude/` to clone (deploy first)
#   84 - `provision`/`release` failed: the underlying `git worktree add`/`remove` call failed
#   90 - `land` refused: the branch's diff against its merge-base touches a `specs/**` path
#   91 - `land` refused: the main tree has uncommitted modifications overlapping a branch-touched
#        path
#   92 - `land` aborted: a genuine merge conflict (branch and worktree left intact, no in-progress
#        merge)
#   93 - `land` refused: invoked with PROJECT_ROOT resolving inside a worktree, or found no usable
#        registry record/branch (`verdict: "unavailable"`)
#
# Test seams (env vars, all optional):
#   DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB - free-space floor in GiB. Default 5 (Phase 1 Findings).
#   DISPATCH_WORKTREE_MAX_CONCURRENT       - concurrent-worktree cap. Default 3 (Phase 1 Findings).
#   DISPATCH_WORKTREE_STALE_SEC            - `prune` age threshold in seconds. Default 3600.
#   DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE  - when set, `provision`'s free-space check uses this
#                                             byte count directly instead of probing `df`, so a
#                                             test can exercise the refusal path deterministically
#                                             without actually exhausting disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1

# --- Test seams (see header) ---
DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB="${DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB:-5}"
DISPATCH_WORKTREE_MAX_CONCURRENT="${DISPATCH_WORKTREE_MAX_CONCURRENT:-3}"
DISPATCH_WORKTREE_STALE_SEC="${DISPATCH_WORKTREE_STALE_SEC:-3600}"
DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE="${DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE:-}"

WORKTREES_ROOT="$PROJECT_ROOT/.orchestrate-worktrees"
RECORD_DIR="$PROJECT_ROOT/specs/.worktree-registry"

EXIT_USAGE=2
EXIT_NOT_FOUND=3
EXIT_FREE_SPACE=80
EXIT_WORKTREE_CAP=81
EXIT_ROOT_ASSERT=82
EXIT_CLAUDE_MISSING=83
EXIT_GIT_WORKTREE_ADD=84
EXIT_LAND_SPECS=90
EXIT_LAND_DIRTY_OVERLAP=91
EXIT_LAND_CONFLICT=92
EXIT_LAND_UNAVAILABLE=93

print_help() {
  cat <<'EOF'
dispatch-worktree.sh - per-dispatch git-worktree lifecycle (provision, path, release, prune, land).

Usage:
  dispatch-worktree.sh provision <task_number> --session <sid> --seq <n>
  dispatch-worktree.sh path <task_number>
  dispatch-worktree.sh release <task_number> [--force]
  dispatch-worktree.sh prune --session <sid>
  dispatch-worktree.sh land <task_number> --session <sid>
  dispatch-worktree.sh --help

provision: preflights free disk space (floor: DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB GiB,
  default 5) and the concurrent-worktree cap (DISPATCH_WORKTREE_MAX_CONCURRENT, default 3),
  creates a worktree on branch orchestrate/task-<task_number>-<seq>, hardlink-clones .claude/
  (and .lake/ if present) into it, asserts PROJECT_ROOT resolves inside the new worktree, and
  records the provision. Idempotent for an already-provisioned <task_number>-<seq>. Emits a JSON
  verdict on stdout.

path: prints the bare worktree path for the most recently provisioned record matching
  <task_number>, or nothing (exit 3) if no record exists.

release: removes the worktree (only --force when asked) and its registry record. Never deletes
  the branch.

prune: reaps every registry record (and its worktree) whose session differs from --session's
  <sid> and whose age exceeds DISPATCH_WORKTREE_STALE_SEC (default 3600s). A record naming <sid>
  itself is never reaped. Emits a JSON summary on stdout.

land: run from the main tree. Merges <task_number>'s dispatch branch (resolved from its
  registry record) into the current HEAD via `git merge --no-ff`, after refusing any specs/**
  touch or any main-tree dirty overlap. A genuine conflict aborts the merge and leaves the
  branch and worktree intact. Emits exactly one JSON verdict on stdout: {"verdict": "landed" |
  "nothing_to_land" | "refused_specs_paths" | "conflict" | "refused_dirty_overlap" |
  "unavailable", ...}. Never auto-resolves a conflict.

Exit codes: 0 success; 2 usage error; 3 not found (path/release); 80 free-space refusal;
  81 worktree-cap refusal; 82 PROJECT_ROOT-resolution-assert failure (provision torn down);
  83 main tree has no .claude/ to clone; 84 git worktree add/remove failure; 90 land refused
  (specs/** touched); 91 land refused (dirty overlap); 92 land aborted (conflict); 93 land
  unavailable (no record/branch, or invoked from inside a worktree).
EOF
}

usage() {
  print_help >&2
  exit "$EXIT_USAGE"
}

# --- free_bytes_available <dir> -- echoes bytes free at <dir>'s filesystem, or the test-seam
# override when DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE is set. Empty stdout on probe failure. ---
free_bytes_available() {
  local dir="$1"
  if [ -n "$DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE" ]; then
    echo "$DISPATCH_WORKTREE_FREE_BYTES_OVERRIDE"
    return 0
  fi
  df --output=avail -B1 "$dir" 2>/dev/null | tail -n1 | tr -d ' '
}

# --- count_active_worktrees -- number of registry records currently on disk. ---
count_active_worktrees() {
  find "$RECORD_DIR" -maxdepth 1 -type f -name '*.json' 2>/dev/null | wc -l | tr -d ' '
}

# --- latest_record_for_task <task_number> -- echoes the path of the most recently modified
# registry record matching <task_number>-*.json, or empty if none exists. ---
latest_record_for_task() {
  local task_number="$1"
  find "$RECORD_DIR" -maxdepth 1 -type f -name "${task_number}-*.json" -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -n1 | cut -d' ' -f2-
}

cmd_provision() {
  local task_number="" session_id="" seq=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session)
        [ "$#" -ge 2 ] || usage
        session_id="$2"
        shift 2
        ;;
      --seq)
        [ "$#" -ge 2 ] || usage
        seq="$2"
        shift 2
        ;;
      -*)
        usage
        ;;
      *)
        if [ -z "$task_number" ]; then
          task_number="$1"
          shift
        else
          usage
        fi
        ;;
    esac
  done

  [[ "$task_number" =~ ^[0-9]+$ ]] || usage
  [ -n "$session_id" ] || usage
  [[ "$seq" =~ ^[0-9]+$ ]] || usage

  mkdir -p "$WORKTREES_ROOT" "$RECORD_DIR"

  local key="${task_number}-${seq}"
  local worktree_path="$WORKTREES_ROOT/$key"
  local record_path="$RECORD_DIR/$key.json"
  local branch="orchestrate/task-${task_number}-${seq}"

  # Idempotent re-provision: an existing record whose worktree git still recognizes is reused
  # verbatim rather than re-created or refused.
  if [ -f "$record_path" ] && git -C "$PROJECT_ROOT" worktree list --porcelain 2>/dev/null | grep -qxF "worktree $worktree_path"; then
    jq -n --arg status "reused" --argjson task "$task_number" --arg session "$session_id" \
      --argjson seq "$seq" --arg branch "$branch" --arg path "$worktree_path" \
      '{status: $status, task_number: $task, session_id: $session, seq: $seq, branch: $branch, path: $path}'
    return 0
  fi

  local active
  active="$(count_active_worktrees)"
  if [ "$active" -ge "$DISPATCH_WORKTREE_MAX_CONCURRENT" ]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- worktree cap reached ($active/$DISPATCH_WORKTREE_MAX_CONCURRENT active). Defer this dispatch rather than proceeding." >&2
    exit "$EXIT_WORKTREE_CAP"
  fi

  local floor_bytes avail_bytes
  floor_bytes=$(( DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB * 1024 * 1024 * 1024 ))
  avail_bytes="$(free_bytes_available "$PROJECT_ROOT")"
  if ! [[ "$avail_bytes" =~ ^[0-9]+$ ]]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- could not determine free disk space at $PROJECT_ROOT; refusing rather than proceeding blind." >&2
    exit "$EXIT_FREE_SPACE"
  fi
  if [ "$avail_bytes" -lt "$floor_bytes" ]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- only ${avail_bytes} bytes free at $PROJECT_ROOT, below the ${DISPATCH_WORKTREE_FREE_SPACE_FLOOR_GIB} GiB floor." >&2
    exit "$EXIT_FREE_SPACE"
  fi

  if [ ! -d "$PROJECT_ROOT/.claude" ]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- $PROJECT_ROOT/.claude is absent; deploy first (bash .claude/scripts/deploy-headless.sh)." >&2
    exit "$EXIT_CLAUDE_MISSING"
  fi

  if [ -e "$worktree_path" ]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- $worktree_path already exists but is not a recognized live worktree; remove it manually or choose a different --seq." >&2
    exit "$EXIT_GIT_WORKTREE_ADD"
  fi

  if ! git -C "$PROJECT_ROOT" worktree add -b "$branch" "$worktree_path" HEAD 1>&2; then
    echo "ERROR: dispatch-worktree.sh provision failed -- git worktree add failed for $worktree_path." >&2
    exit "$EXIT_GIT_WORKTREE_ADD"
  fi

  # Hardlink clone, never a symlink -- see the header's "WHY A HARDLINK CLONE" note.
  cp -al "$PROJECT_ROOT/.claude" "$worktree_path/.claude"

  # .lake/ is populated the same way, only when the main tree actually has one.
  if [ -d "$PROJECT_ROOT/.lake" ]; then
    cp -al "$PROJECT_ROOT/.lake" "$worktree_path/.lake"
  fi

  local resolved_root canonical_worktree
  resolved_root="$(common_repo_root "$worktree_path/.claude/scripts" 2)"
  canonical_worktree="$(cd "$worktree_path" && pwd)"
  if [ "$resolved_root" != "$canonical_worktree" ]; then
    echo "ERROR: dispatch-worktree.sh provision refused -- PROJECT_ROOT resolved to '$resolved_root', not the worktree '$canonical_worktree'. Tearing down." >&2
    git -C "$PROJECT_ROOT" worktree remove --force "$worktree_path" 1>&2 || true
    exit "$EXIT_ROOT_ASSERT"
  fi

  local created_at
  created_at="$(common_timestamp_iso)"
  local tmp_record
  tmp_record="$(mktemp "${RECORD_DIR}/.tmp.XXXXXX")"
  jq -n \
    --argjson task "$task_number" \
    --arg session "$session_id" \
    --argjson seq "$seq" \
    --arg branch "$branch" \
    --arg path "$worktree_path" \
    --arg created_at "$created_at" \
    '{task_number: $task, session_id: $session, seq: $seq, branch: $branch, path: $path, created_at: $created_at}' \
    > "$tmp_record"
  mv "$tmp_record" "$record_path"

  jq -n --arg status "provisioned" --argjson task "$task_number" --arg session "$session_id" \
    --argjson seq "$seq" --arg branch "$branch" --arg path "$worktree_path" \
    '{status: $status, task_number: $task, session_id: $session, seq: $seq, branch: $branch, path: $path}'
}

cmd_path() {
  local task_number="${1:-}"
  [[ "$task_number" =~ ^[0-9]+$ ]] || usage

  local match
  match="$(latest_record_for_task "$task_number")"
  if [ -z "$match" ]; then
    exit "$EXIT_NOT_FOUND"
  fi
  jq -r '.path' "$match"
}

cmd_release() {
  local task_number="" force=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --force)
        force=1
        shift
        ;;
      -*)
        usage
        ;;
      *)
        if [ -z "$task_number" ]; then
          task_number="$1"
          shift
        else
          usage
        fi
        ;;
    esac
  done
  [[ "$task_number" =~ ^[0-9]+$ ]] || usage

  local match
  match="$(latest_record_for_task "$task_number")"
  if [ -z "$match" ]; then
    echo "ERROR: dispatch-worktree.sh release found no provisioning record for task $task_number." >&2
    exit "$EXIT_NOT_FOUND"
  fi

  local worktree_path
  worktree_path="$(jq -r '.path' "$match")"

  # Strip the hardlink-cloned .claude/ and .lake/ scratch BEFORE asking git to remove the
  # worktree. Both are untracked-by-construction in every worktree (never committed anywhere,
  # never symlinked -- see the header), so their mere presence would make a plain `git worktree
  # remove` (no --force) refuse EVERY release as "dirty", defeating the whole point of a
  # no-force default. Removing them first leaves only genuine uncommitted SOURCE edits (a real
  # signal worth refusing on) to trigger git's own clean-check.
  if [ -n "$worktree_path" ] && [ -d "$worktree_path" ]; then
    rm -rf "${worktree_path:?}/.claude" "${worktree_path:?}/.lake" 2>/dev/null || true
  fi

  local remove_args=(worktree remove)
  [ "$force" -eq 1 ] && remove_args+=(--force)
  remove_args+=("$worktree_path")

  if ! git -C "$PROJECT_ROOT" "${remove_args[@]}" 1>&2; then
    echo "ERROR: dispatch-worktree.sh release failed to remove worktree $worktree_path (dirty? pass --force if intentional)." >&2
    exit "$EXIT_GIT_WORKTREE_ADD"
  fi

  rm -f "$match"
  jq -n --arg status "released" --arg path "$worktree_path" '{status: $status, path: $path}'
}

cmd_prune() {
  local session_id=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session)
        [ "$#" -ge 2 ] || usage
        session_id="$2"
        shift 2
        ;;
      *)
        usage
        ;;
    esac
  done
  [ -n "$session_id" ] || usage

  mkdir -p "$RECORD_DIR"

  local now
  now="$(common_timestamp_epoch)"

  local pruned=() kept=()
  local record
  while IFS= read -r -d '' record; do
    [ -n "$record" ] || continue
    local rec_session rec_created_at rec_path rec_epoch age
    rec_session="$(jq -r '.session_id // empty' "$record" 2>/dev/null)" || rec_session=""
    rec_created_at="$(jq -r '.created_at // empty' "$record" 2>/dev/null)" || rec_created_at=""
    rec_path="$(jq -r '.path // empty' "$record" 2>/dev/null)" || rec_path=""

    if [ "$rec_session" = "$session_id" ]; then
      kept+=("$record")
      continue
    fi

    rec_epoch=""
    if [ -n "$rec_created_at" ]; then
      rec_epoch="$(date -u -d "$rec_created_at" +%s 2>/dev/null)" || rec_epoch=""
    fi
    if [ -z "$rec_epoch" ]; then
      # Unparseable/absent timestamp: never guess-reap, just keep.
      kept+=("$record")
      continue
    fi

    age=$(( now - rec_epoch ))
    if [ "$age" -gt "$DISPATCH_WORKTREE_STALE_SEC" ]; then
      if [ -n "$rec_path" ]; then
        git -C "$PROJECT_ROOT" worktree remove --force "$rec_path" 1>&2 2>&1 || true
      fi
      rm -f "$record"
      pruned+=("$rec_path")
    else
      kept+=("$record")
    fi
  done < <(find "$RECORD_DIR" -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null)

  local pruned_json
  pruned_json="$(printf '%s\n' "${pruned[@]:-}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"

  jq -n --argjson pruned "$pruned_json" --argjson kept_count "${#kept[@]}" \
    '{pruned: $pruned, kept_count: $kept_count}'
}

cmd_land() {
  local task_number="" session_id=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --session)
        [ "$#" -ge 2 ] || usage
        session_id="$2"
        shift 2
        ;;
      -*)
        usage
        ;;
      *)
        if [ -z "$task_number" ]; then
          task_number="$1"
          shift
        else
          usage
        fi
        ;;
    esac
  done
  [[ "$task_number" =~ ^[0-9]+$ ]] || usage
  [ -n "$session_id" ] || usage

  # land must run from the MAIN tree. If this invocation is the WORKTREE's own hardlinked copy
  # of this script, PROJECT_ROOT resolved (correctly, for provision's own purposes) to the
  # worktree root -- landing "into" that would merge into the isolated checkout, not the main
  # tree, so refuse outright rather than silently doing the wrong thing.
  case "$PROJECT_ROOT" in
    */.orchestrate-worktrees/*)
      echo "ERROR: dispatch-worktree.sh land refused -- PROJECT_ROOT ('$PROJECT_ROOT') resolves inside a worktree, not the main tree. Invoke the main tree's own .claude/scripts/dispatch-worktree.sh instead." >&2
      jq -n --arg verdict "unavailable" --arg reason "invoked from inside a worktree" '{verdict: $verdict, reason: $reason}'
      exit "$EXIT_LAND_UNAVAILABLE"
      ;;
  esac

  local match
  match="$(latest_record_for_task "$task_number")"
  if [ -z "$match" ]; then
    echo "ERROR: dispatch-worktree.sh land found no provisioning record for task $task_number." >&2
    jq -n --arg verdict "unavailable" --arg reason "no registry record" '{verdict: $verdict, reason: $reason}'
    exit "$EXIT_LAND_UNAVAILABLE"
  fi

  local branch
  branch="$(jq -r '.branch' "$match")"

  if ! git -C "$PROJECT_ROOT" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null 2>&1; then
    echo "ERROR: dispatch-worktree.sh land found no branch '$branch' for task $task_number." >&2
    jq -n --arg verdict "unavailable" --arg reason "branch does not exist" '{verdict: $verdict, reason: $reason}'
    exit "$EXIT_LAND_UNAVAILABLE"
  fi

  # Already fully landed (or the branch never diverged from HEAD at all): nothing to do.
  if git -C "$PROJECT_ROOT" merge-base --is-ancestor "$branch" HEAD 2>/dev/null; then
    jq -n --arg verdict "nothing_to_land" --arg branch "$branch" '{verdict: $verdict, branch: $branch}'
    return 0
  fi

  local merge_base
  merge_base="$(git -C "$PROJECT_ROOT" merge-base HEAD "$branch" 2>/dev/null)" || merge_base=""
  if [ -z "$merge_base" ]; then
    echo "ERROR: dispatch-worktree.sh land could not compute a merge-base between HEAD and '$branch'." >&2
    jq -n --arg verdict "unavailable" --arg reason "no merge-base" '{verdict: $verdict, reason: $reason}'
    exit "$EXIT_LAND_UNAVAILABLE"
  fi

  local touched_paths
  touched_paths="$(git -C "$PROJECT_ROOT" diff --name-only "$merge_base" "$branch" 2>/dev/null)"

  local touched_arr=()
  local p
  while IFS= read -r p; do
    [ -n "$p" ] && touched_arr+=("$p")
  done <<< "$touched_paths"

  if [ "${#touched_arr[@]}" -eq 0 ]; then
    jq -n --arg verdict "nothing_to_land" --arg branch "$branch" '{verdict: $verdict, branch: $branch}'
    return 0
  fi

  # Refusal 1 (before any git add/merge): a specs/** path in the branch's own diff would
  # overwrite live main-tree state with a HEAD-stale worktree snapshot -- see the header's
  # "`specs/` IS TRACKED" note.
  local specs_paths=()
  for p in "${touched_arr[@]}"; do
    case "$p" in
      specs/*)
        specs_paths+=("$p")
        ;;
    esac
  done

  if [ "${#specs_paths[@]}" -gt 0 ]; then
    echo "ERROR: dispatch-worktree.sh land refused -- branch '$branch' touches specs/** path(s), which would overwrite live main-tree state with a HEAD-stale worktree snapshot:" >&2
    printf '  %s\n' "${specs_paths[@]}" >&2
    local specs_json
    specs_json="$(printf '%s\n' "${specs_paths[@]}" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
    jq -n --arg verdict "refused_specs_paths" --arg branch "$branch" --argjson paths "$specs_json" \
      '{verdict: $verdict, branch: $branch, paths: $paths}'
    exit "$EXIT_LAND_SPECS"
  fi

  # Refusal 2 (before any git add/merge): the main tree already has uncommitted modifications
  # overlapping a path the branch touched -- surface it rather than merging over in-flight work.
  local dirty_overlap
  dirty_overlap="$(git -C "$PROJECT_ROOT" status --porcelain -- "${touched_arr[@]}" 2>/dev/null)"
  if [ -n "$dirty_overlap" ]; then
    echo "ERROR: dispatch-worktree.sh land refused -- the main tree has uncommitted modifications overlapping branch '$branch':" >&2
    echo "$dirty_overlap" >&2
    local overlap_json
    overlap_json="$(printf '%s\n' "$dirty_overlap" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
    jq -n --arg verdict "refused_dirty_overlap" --arg branch "$branch" --argjson overlap "$overlap_json" \
      '{verdict: $verdict, branch: $branch, overlap: $overlap}'
    exit "$EXIT_LAND_DIRTY_OVERLAP"
  fi

  local merge_msg="dispatch-worktree.sh land: task ${task_number} (${branch})"
  if git -C "$PROJECT_ROOT" merge --no-ff "$branch" -m "$merge_msg" >&2; then
    jq -n --arg verdict "landed" --arg branch "$branch" '{verdict: $verdict, branch: $branch}'
    return 0
  fi

  # Conflict: read the conflicted paths BEFORE aborting, then abort -- never auto-resolve, never
  # -X ours/theirs. Both the branch and the worktree are left intact for human resolution.
  local conflicted_paths conflicted_json
  conflicted_paths="$(git -C "$PROJECT_ROOT" diff --name-only --diff-filter=U 2>/dev/null)"
  git -C "$PROJECT_ROOT" merge --abort >&2 || true
  echo "ERROR: dispatch-worktree.sh land aborted -- merge conflict against branch '$branch'; branch and worktree left intact for resolution:" >&2
  echo "$conflicted_paths" >&2
  conflicted_json="$(printf '%s\n' "$conflicted_paths" | jq -R -s -c 'split("\n") | map(select(length > 0))')"
  jq -n --arg verdict "conflict" --arg branch "$branch" --argjson paths "$conflicted_json" \
    '{verdict: $verdict, branch: $branch, paths: $paths}'
  exit "$EXIT_LAND_CONFLICT"
}

# --- main dispatch ---
[ "$#" -ge 1 ] || usage

case "$1" in
  --help | -h)
    print_help
    exit 0
    ;;
  provision)
    shift
    cmd_provision "$@"
    ;;
  path)
    shift
    cmd_path "$@"
    ;;
  release)
    shift
    cmd_release "$@"
    ;;
  prune)
    shift
    cmd_prune "$@"
    ;;
  land)
    shift
    cmd_land "$@"
    ;;
  *)
    usage
    ;;
esac
