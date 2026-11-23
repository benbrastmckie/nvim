#!/usr/bin/env bash
# task-landing-verify.sh - The landing verification for one task: decide whether the task's work
# is on the integration branch and nothing of it was left behind, and record one landing proof
# in the batch record that lists the task.
#
# Phase commits stay on the integration branch as they are made; nothing is picked, squashed or
# rewritten there. "Landing" is this verification plus the recorded proof. It reads refs and the
# working tree, changes no ref, and writes exactly one thing on a pass: one element appended to
# the batch record's `landing_proofs` array (context/standards/orchestrator-runtime-files.md,
# "The batch record"). A refusal writes nothing.
#
# USAGE
# -----
#   task-landing-verify.sh <task_number> --session SID
#       [--check] [--modified-files-from FILE] [--print-body]
#
#   --session SID   The invocation's session identity: recorded in the proof and used as the
#                   identity for the specs/.commit-lock mutex. Required.
#   --check         Read-only: evaluate the predicate, write no proof, take no mutex.
#   --modified-files-from FILE
#                   A return-metadata JSON file. Its `modified_files` array widens V5 and its
#                   `source_store_commits` array, when present, is copied into the proof. A
#                   missing or unparseable file contributes nothing.
#   --print-body    Print, on standard output, the commit-body block built from the task's
#                   recorded proof (phases, attributed commits oldest first, the end commit,
#                   second-repository commits) and exit 0. Prints nothing when the task has no
#                   proof. Evaluates nothing and writes nothing.
#
# Every diagnostic (the pass line, a refusal, an inconclusive notice) goes to standard error;
# standard output carries only the --print-body block.
#
# THE PREDICATE
# -------------
#   V1  branch       HEAD is a symbolic ref to the integration branch. The branch is resolved
#                    from the newest batch record listing the task, else the declared
#                    `integration_branch`, else the branch HEAD names. A detached HEAD, or a
#                    branch other than the resolved one, refuses.
#   V2  attribution  The task's commits are the non-merge commits on that branch whose subject
#                    starts `task {N}:` or `task {N} phase `, committed at or after the task's
#                    `created` timestamp (specs/state.json, else specs/archive/state.json). The
#                    time bound is what keeps a reused task number's earlier commits out. A task
#                    entry with no `created` is bounded by the oldest `admitted_at` among the
#                    batch records listing it. An empty set refuses.
#   V3  path set     The union of the paths those commits touched, less the state territory
#                    (BATCH_ADMISSION_STATE_TERRITORY in lib/batch-admission-lib.sh).
#   V4  blob equality  For every path of the set, the blob at the branch tip equals the blob at
#                    the task's end commit. A mismatch refuses and names the commits that
#                    touched the path after the end commit.
#   V5  nothing left behind  No path of the set, and no reported modified path inside the
#                    repository and outside the state territory, differs between the working
#                    tree and the tip (untracked reported files included). Reported paths can
#                    only add a refusal; they never establish that work landed.
#
# The END COMMIT is the task's last attributed commit that touches at least one path outside
# the state territory. A commit carrying state files only (the completion commit) never becomes
# the end commit, so a re-run after it sees the same end commit. A task whose commits touch
# only the state territory has an empty path set; its end commit is its last attributed commit,
# V4 holds vacuously, and V5 reads the reported paths alone.
#
# IDEMPOTENCE: a recorded proof for the task whose `end_commit` equals the current end commit
# (or, for an empty path set, any recorded proof with an empty path set) makes the run a passing
# no-op that appends nothing. V4 and V5 are not re-evaluated then: a later task that edits the
# same file would otherwise fail a task that landed correctly.
#
# INCONCLUSIVE cases print one named line and exit 0: the project root is not a git work tree,
# `git` or `jq` is missing, the task is in neither state file, or the task carries neither a
# `created` timestamp nor a batch record to bound attribution by (an unbounded match would
# attribute an earlier holder of the number). NO BATCH RECORD lists the task: the predicate runs
# all the same and decides the exit status; one notice says no proof was recorded.
#
# The verify-and-record mode runs under the existing specs/.commit-lock mutex (task-lock.sh
# commit-acquire): a guest when COMMIT_MUTEX_HELD is set, and fail-open with a named warning
# when the mutex cannot be acquired. No new lock.
#
# EXIT CODES
# ----------
#   0   pass (including the idempotent no-op and every inconclusive case), or --print-body
#   2   usage error
#   10  V1 refused: HEAD is not on the integration branch
#   11  V2 refused: no commit on the integration branch is attributable to the task
#   12  V4 refused: a path of the task changed after the task's end commit
#   13  V5 refused: work in the working tree that no commit carries

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck source=deploy-root-guard.sh disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"

ME="task-landing-verify"

usage() {
  echo "Usage: $0 <task_number> --session SID [--check] [--modified-files-from FILE] [--print-body]" >&2
  exit 2
}

task_number=""
session_id=""
check_only="false"
print_body="false"
meta_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --session) [ $# -ge 2 ] || usage; session_id="$2"; shift 2 ;;
    --check) check_only="true"; shift ;;
    --print-body) print_body="true"; shift ;;
    --modified-files-from) [ $# -ge 2 ] || usage; meta_file="$2"; shift 2 ;;
    -*) usage ;;
    *) [ -z "$task_number" ] || usage; task_number="$1"; shift ;;
  esac
done
case "$task_number" in ''|*[!0-9]*) usage ;; esac
[ -n "$session_id" ] || usage

inconclusive() {
  echo "LANDING-INCONCLUSIVE task ${task_number}: $1; the landing verification did not run." >&2
  exit 0
}

for tool in git jq; do
  command -v "$tool" >/dev/null 2>&1 || inconclusive "${tool} is not available"
done
[ "$(git -C "$PROJECT_ROOT" rev-parse --is-inside-work-tree 2>/dev/null || true)" = "true" ] \
  || inconclusive "the project root is not a git work tree"
cd "$PROJECT_ROOT" || inconclusive "the project root cannot be entered"

# shellcheck source=lib/task-lookup-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
# shellcheck source=lib/runtime-file-patterns.sh disable=SC1091
[ -f "${SCRIPT_DIR}/lib/runtime-file-patterns.sh" ] && source "${SCRIPT_DIR}/lib/runtime-file-patterns.sh"
# shellcheck source=lib/batch-admission-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/batch-admission-lib.sh"
# shellcheck source=lib/phase-heading-patterns.sh disable=SC1091
source "${SCRIPT_DIR}/lib/phase-heading-patterns.sh"

SPECS_DIR="${PROJECT_ROOT}/specs"
STATE_FILE="${SPECS_DIR}/state.json"

g() { git -c core.quotePath=false --literal-pathspecs "$@"; }

# in_territory <path> -- 0 when <path> is a state-territory member or lies under one.
in_territory() {
  local p="$1" member
  for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
    case "$p" in "$member"|"$member"/*) return 0 ;; esac
  done
  return 1
}

# proof_for_task -- stdout: the newest recorded proof for the task across every batch record
# that lists it (compact JSON), or nothing.
proof_for_task() {
  local rec
  while IFS= read -r rec; do
    [ -n "$rec" ] && [ -f "$rec" ] || continue
    jq -c --argjson n "$task_number" \
      '[(.landing_proofs // [])[] | select(.task_number == $n)] | last // empty' \
      "$rec" 2>/dev/null || true
  done < <(batch_admission_record_for_task "$SPECS_DIR" "$task_number" all) | head -n 1
}

# --- --print-body: read the recorded proof, evaluate nothing ---------------------------------
if [ "$print_body" = "true" ]; then
  proof="$(proof_for_task)"
  [ -n "$proof" ] || exit 0
  printf '%s' "$proof" | jq -r '
    "Landing verified on \(.integration_branch // "the integration branch") at \(.tip_at_verification // "")",
    "",
    "Phases:",
    (if ((.phases // []) | length) == 0 then "- none recorded"
     else (.phases[] | "- Phase \(.phase): \(.name)") end),
    "",
    "Commits:",
    ((.commits // [])[] | "- \(.)"),
    "",
    "End commit: \(.end_commit // "")",
    (if ((.source_store_commits // []) | length) == 0 then empty
     else "", "Source-store commits (second repository, recorded, not verified here):",
          (.source_store_commits[] | "- \(.repository // "unknown") \(.commit // "")") end)'
  exit 0
fi

# --- The task and its attribution bound ------------------------------------------------------
entry=""
[ -f "$STATE_FILE" ] && entry="$(task_lookup_entry "$task_number" "$STATE_FILE" 2>/dev/null || true)"
[ -n "$entry" ] || inconclusive "the task is in neither specs/state.json nor specs/archive/state.json"
created="$(printf '%s' "$entry" | jq -r '.created // empty' 2>/dev/null || true)"
created_epoch=""
[ -n "$created" ] && created_epoch="$(date -u -d "$created" +%s 2>/dev/null || true)"
if [ -z "$created_epoch" ]; then
  # No created timestamp: bound by the oldest admission among the records listing the task.
  created="$(
    while IFS= read -r rec; do
      [ -n "$rec" ] && [ -f "$rec" ] && jq -r '.admitted_at // empty' "$rec" 2>/dev/null
    done < <(batch_admission_record_for_task "$SPECS_DIR" "$task_number" all) | LC_ALL=C sort | head -n 1
  )"
  [ -n "$created" ] && created_epoch="$(date -u -d "$created" +%s 2>/dev/null || true)"
fi
[ -n "$created_epoch" ] || inconclusive "the task carries no readable created timestamp and no batch record lists it, so attribution has no time bound"
project_name="$(printf '%s' "$entry" | jq -r '.project_name // empty' 2>/dev/null || true)"

# --- Serialize under the existing commit mutex (verify-and-record mode only) -----------------
commit_token=""
commit_mutex_owned="false"
# shellcheck disable=SC2329  # invoked through the EXIT trap
release_mutex() {
  if [ "$commit_mutex_owned" = "true" ]; then
    bash "$SCRIPT_DIR/task-lock.sh" commit-release "$commit_token" >&2 || true
    commit_mutex_owned="false"
  fi
}
trap release_mutex EXIT
if [ "$check_only" != "true" ] && [ -z "${COMMIT_MUTEX_HELD:-}" ]; then
  if commit_token="$(bash "$SCRIPT_DIR/task-lock.sh" commit-acquire "$session_id" 2>/dev/null)"; then
    commit_mutex_owned="true"
  else
    echo "WARNING: [${ME}] failed to acquire specs/.commit-lock mutex (session=${session_id}); proceeding unserialized (non-blocking, fail-open)." >&2
  fi
fi

refuse() { # <exit_code> <check> <message>
  echo "LANDING-REFUSED task ${task_number} [$2]: $3" >&2
  exit "$1"
}

# --- V1: branch ------------------------------------------------------------------------------
record="$(batch_admission_record_for_task "$SPECS_DIR" "$task_number")"
integration_branch=""
[ -n "$record" ] && integration_branch="$(jq -r '.integration_branch // empty' "$record" 2>/dev/null || true)"
[ -n "$integration_branch" ] || integration_branch="$(batch_admission_integration_branch "$PROJECT_ROOT")"
current_branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"
[ -n "$integration_branch" ] || integration_branch="$current_branch"
if [ -z "$current_branch" ]; then
  named=""
  [ -n "$integration_branch" ] && named=" (the integration branch is '${integration_branch}')"
  refuse 10 "V1 branch" "HEAD is detached, so commits made here are on no branch${named}. Remedy: switch the primary tree to the integration branch and bring the task's commits onto it, then re-run."
fi
if [ "$current_branch" != "$integration_branch" ]; then
  refuse 10 "V1 branch" "HEAD is on '${current_branch}', not the integration branch '${integration_branch}'. Remedy: switch the primary tree to '${integration_branch}' and bring the task's commits onto it, then re-run."
fi
tip="$(git rev-parse -q --verify "refs/heads/${integration_branch}^{commit}" 2>/dev/null || true)"
[ -n "$tip" ] || refuse 10 "V1 branch" "the integration branch '${integration_branch}' has no commit. Remedy: commit the task's work on it, then re-run."

# --- V2: attribution -------------------------------------------------------------------------
# --grep matches any line of the message, so the subject is re-tested here.
subject_re="^task ${task_number}(:| phase )"
own=()
while read -r sha ct subject; do
  [ -n "$sha" ] || continue
  [[ "$subject" =~ $subject_re ]] || continue
  [ "$ct" -ge "$created_epoch" ] 2>/dev/null && own+=("$sha")
done < <(git log --no-merges --reverse --format='%H %ct %s' -E \
           --grep="$subject_re" "$tip" 2>/dev/null)
if [ "${#own[@]}" -eq 0 ]; then
  refuse 11 "V2 attribution" "no non-merge commit on '${integration_branch}' made at or after ${created} has a subject starting 'task ${task_number}:' or 'task ${task_number} phase '. Remedy: commit the task's work on '${integration_branch}' under the task's subject convention, then re-run."
fi

# --- V3: path set, and the end commit --------------------------------------------------------
declare -A path_seen=()
paths=()
end_commit=""
for sha in "${own[@]}"; do
  touched_outside="false"
  while IFS= read -r -d '' p; do
    [ -n "$p" ] || continue
    in_territory "$p" && continue
    touched_outside="true"
    if [ -z "${path_seen[$p]:-}" ]; then
      path_seen[$p]=1
      paths+=("$p")
    fi
  done < <(git diff-tree --root --no-commit-id --name-only -r -z "$sha" 2>/dev/null)
  [ "$touched_outside" = "true" ] && end_commit="$sha"
done
[ -n "$end_commit" ] || end_commit="${own[-1]}"
if [ "${#paths[@]}" -gt 0 ]; then
  mapfile -t paths < <(printf '%s\n' "${paths[@]}" | LC_ALL=C sort)
fi

pass() { # <suffix>
  echo "LANDING-VERIFIED task ${task_number}: commits=${#own[@]} end=${end_commit:0:12} paths=${#paths[@]} branch=${integration_branch}; $1" >&2
  exit 0
}

# --- Idempotence -----------------------------------------------------------------------------
existing="$(proof_for_task)"
if [ -n "$existing" ]; then
  existing_end="$(printf '%s' "$existing" | jq -r '.end_commit // empty' 2>/dev/null || true)"
  existing_paths="$(printf '%s' "$existing" | jq -r '(.paths // []) | length' 2>/dev/null || echo 1)"
  if [ "$existing_end" = "$end_commit" ] \
     || { [ "${#paths[@]}" -eq 0 ] && [ "$existing_paths" = "0" ]; }; then
    pass "a landing proof is already recorded for this end commit (no-op)."
  fi
fi

# --- V4: blob equality between the tip and the end commit ------------------------------------
if [ "${#paths[@]}" -gt 0 ]; then
  mismatched=()
  while IFS= read -r -d '' p; do
    [ -n "$p" ] && mismatched+=("$p")
  done < <(g diff --no-renames --name-only -z "$end_commit" "$tip" -- "${paths[@]}" 2>/dev/null)
  if [ "${#mismatched[@]}" -gt 0 ]; then
    detail=""
    for p in "${mismatched[@]}"; do
      offenders="$(g log --format='%h %s' "${end_commit}..${tip}" -- "$p" 2>/dev/null | paste -sd';' - | sed 's/;/; /g')"
      detail="${detail:+${detail} | }${p} <- ${offenders:-no commit found}"
    done
    refuse 12 "V4 blob equality" "${#mismatched[@]} path(s) of the task differ between the tip of '${integration_branch}' and the task's end commit ${end_commit:0:12}, changed afterwards by: ${detail}. No ref was changed. Remedy: reconcile the named commit(s) with the task's work in a new commit under the task's subject convention, then re-run."
  fi
fi

# --- V5: nothing left behind -----------------------------------------------------------------
reported=()
source_store_commits="[]"
if [ -n "$meta_file" ] && [ -f "$meta_file" ]; then
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      "$PROJECT_ROOT"/*) p="${p#"$PROJECT_ROOT"/}" ;;
      /*) continue ;;
    esac
    p="${p#./}"
    case "/$p/" in */../*) continue ;; esac
    in_territory "$p" && continue
    [ -n "${path_seen[$p]:-}" ] && continue
    reported+=("$p")
  done < <(jq -r '(.modified_files // [])[]? | select(type == "string")' "$meta_file" 2>/dev/null || true)
  source_store_commits="$(jq -c '
    [(.source_store_commits // [])[]? | select(type == "object")
     | {repository: (.repository // null), commit: (.commit // null)}]' "$meta_file" 2>/dev/null || echo '[]')"
  [ -n "$source_store_commits" ] || source_store_commits="[]"
fi
v5_spec=()
[ "${#paths[@]}" -gt 0 ] && v5_spec+=("${paths[@]}")
[ "${#reported[@]}" -gt 0 ] && v5_spec+=("${reported[@]}")
if [ "${#v5_spec[@]}" -gt 0 ]; then
  left="$(g status --porcelain --untracked-files=all -- "${v5_spec[@]}" 2>/dev/null || true)"
  if [ -n "$left" ]; then
    count="$(printf '%s\n' "$left" | grep -c . || true)"
    listed="$(printf '%s\n' "$left" | sed 's/^...//' | paste -sd, - | sed 's/,/, /g')"
    refuse 13 "V5 nothing left behind" "${count} path(s) differ between the working tree and the tip of '${integration_branch}': ${listed}. That work is on disk and in no commit. Remedy: commit each path under the task's subject convention ('task ${task_number}: ...'), or revert it, then re-run."
  fi
fi

[ "$check_only" = "true" ] && pass "check only, no proof written."

# --- The proof -------------------------------------------------------------------------------
if [ -z "$record" ]; then
  pass "no batch record lists this task, so no landing proof was recorded."
fi

# shared_paths: paths of the set that a commit outside the task also touched between the
# task's first attributed commit and its end commit.
declare -A own_set=()
for sha in "${own[@]}"; do own_set[$sha]=1; done
shared=()
if [ "${#paths[@]}" -gt 0 ]; then
  declare -A shared_seen=()
  current=""
  while IFS= read -r line; do
    case "$line" in
      @*) current="${line#@}" ;;
      "") ;;
      *)
        if [ -n "$current" ] && [ -z "${own_set[$current]:-}" ] && [ -z "${shared_seen[$line]:-}" ]; then
          shared_seen[$line]=1
          shared+=("$line")
        fi
        ;;
    esac
  done < <(g log --no-merges --no-renames --format='@%H' --name-only "${own[0]}..${end_commit}" -- "${paths[@]}" 2>/dev/null)
fi

# phases: the completed phase headings of the task's newest plan file.
phases="[]"
task_dir=""
[ -n "$project_name" ] && task_dir="$(task_lookup_dir "$task_number" "$project_name" "$PROJECT_ROOT" 2>/dev/null || true)"
plan_file=""
if [ -n "$task_dir" ] && [ -d "${task_dir}/plans" ]; then
  plan_file="$(find "${task_dir}/plans" -maxdepth 1 -type f -name '*.md' 2>/dev/null | LC_ALL=C sort | tail -n 1)"
fi
if [ -n "$plan_file" ] && [ -f "$plan_file" ]; then
  phases="$(grep -E "$PHASE_HEADING_DONE_ERE" "$plan_file" 2>/dev/null \
    | sed -E 's/^### Phase ([0-9]+(\.[0-9]+)?): (.*)[[:space:]]\[[A-Z ]+\][[:space:]]*$/\1\t\3/' \
    | jq -R -s -c 'split("\n") | map(select(length > 0) | split("\t") | {phase: .[0], name: (.[1] // "")})' \
      2>/dev/null || echo '[]')"
  [ -n "$phases" ] || phases="[]"
fi

json_array() { # <items...> -- a JSON array of strings
  if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | jq -R . | jq -s -c .; fi
}

proof="$(jq -n -c \
  --argjson task "$task_number" --arg session "$session_id" \
  --arg landed "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg branch "$integration_branch" \
  --argjson commits "$(json_array "${own[@]}")" --arg end "$end_commit" --arg tip "$tip" \
  --argjson paths "$(json_array "${paths[@]}")" --argjson shared "$(json_array "${shared[@]}")" \
  --argjson phases "$phases" --argjson ssc "$source_store_commits" \
  '{task_number: $task, session_id: $session, landed_at: $landed, integration_branch: $branch,
    commits: $commits, end_commit: $end, tip_at_verification: $tip, paths: $paths,
    shared_paths: $shared, phases: $phases, source_store_commits: $ssc}' 2>/dev/null || true)"

appended=""
[ -n "$proof" ] && appended="$(batch_admission_append_landing_proof "$record" "$proof")"
if [ "$appended" = "appended" ]; then
  pass "landing proof recorded in ${record#"$PROJECT_ROOT"/}."
fi
echo "WARNING: [${ME}] the predicate passed for task ${task_number} but its landing proof could not be written to ${record#"$PROJECT_ROOT"/}." >&2
pass "no landing proof was recorded."
