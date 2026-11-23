#!/usr/bin/env bash
# batch-admission-lib.sh - Single home of orchestration admission: the readers for the two
# repo-level declarations `integration_branch` and `worktree_isolation`, the admission predicate
# that decides whether an /orchestrate invocation may proceed, and the writer of the one batch
# record an admitted invocation leaves under the primary tree's state directory. See
# context/standards/repo-level-declarations.md's "The integration_branch Declaration" and "The
# worktree_isolation Declaration" sections for the schema, and
# context/standards/orchestrator-runtime-files.md's "The batch record" section for the record.
#
# Sourced (never executed), safe under a caller's `set -euo pipefail`:
#   - Sets no shell options -- sourcing this file never changes the caller's error handling.
#   - Never calls `exit` -- every public function returns 0 and reports through stdout or the
#     BATCH_ADMISSION_* result variables. The caller decides what a refusal does.
#   - Internal helpers are prefixed `_bal_`; the public surface is `batch_admission_*` plus the
#     two constants below.
#
# Public surface:
#
#   BATCH_ADMISSION_STATE_TERRITORY  array constant: the repository-root-relative paths whose
#       tracked dirt never refuses an invocation.
#   BATCH_ADMISSION_ISOLATION_WORK   the name of the work that implements `worktree_isolation:
#       batch`, named in the refusal message.
#
#   batch_admission_worktree_isolation <project_root>
#       Prints `off`, `batch`, or the raw unrecognised declared value (a string verbatim, any
#       other JSON type as its compact JSON text). Absent key, JSON null, missing `jq`, missing
#       or unparseable declarations file all print `off`.
#
#   batch_admission_integration_branch <project_root>
#       Prints the declared branch name, or nothing for undeclared, empty-string or non-string.
#
#   batch_admission_dirty_paths <project_root>
#       Prints, one per line, every tracked path outside the state territory that differs from
#       HEAD (staged or unstaged; untracked files never appear). Prints nothing when HEAD does
#       not resolve (an unborn branch) or the root is not a git work tree.
#
#   batch_admission_record_path <specs_dir> <session_id>
#       Prints the batch record's path (via runtime_batch_record_path when that resolver is
#       loaded, else the same string computed here).
#
#   batch_admission_evaluate <project_root> <specs_dir> <session_id> <dry_run> \
#                            [task_numbers_json] [orchestration_id]
#       The predicate. Sets:
#         BATCH_ADMISSION_VERDICT  `admit`, `skip` (not a git work tree), or `refuse`
#         BATCH_ADMISSION_REASON   on refuse: `isolation_unimplemented`,
#                                  `off_integration_branch`, or `dirty_primary_tree`; else empty
#         BATCH_ADMISSION_MESSAGE  on refuse: the operator-facing message; else empty
#       On `admit` it writes the batch record when none exists for the session and <dry_run> is
#       not `true`. One named advisory goes to standard error when `integration_branch` is
#       undeclared, on the first cycle only. Nothing is ever written to standard output.
#
# Predicate order (each step only reached when the one before it did not decide):
#   1. `worktree_isolation` is neither absent nor `off`          -> refuse, isolation_unimplemented
#   2. <project_root> is not a git work tree                     -> skip
#   3. `integration_branch` undeclared                           -> advisory, admit
#   4. declared, and the checked-out branch differs or HEAD is
#      detached (tested every cycle)                             -> refuse, off_integration_branch
#   5. declared, no batch record for this session (the first
#      cycle), tracked dirt outside the state territory          -> refuse, dirty_primary_tree
#   6. otherwise                                                 -> admit
#
# Step 1 is the one deliberate exception to the declarations surface's fail-open posture: a
# repository that declares a mode the system cannot honour is refused loudly, never run as if
# the mode were off. Absence stays fail-open at every step.
#
# The record's batch-branch name and absolute worktree path are not written here. They belong
# to the isolation-on path and arrive as one `isolation` object beside the fields this library
# writes -- an additive field write that changes no existing field.

[ -n "${_BATCH_ADMISSION_LIB_LOADED:-}" ] && return 0
_BATCH_ADMISSION_LIB_LOADED=1

# The state territory, exactly. Pinned against repo-level-declarations.md by
# tests/test-batch-admission-lib.sh; change both together.
BATCH_ADMISSION_STATE_TERRITORY=("specs" ".claude-extensions.json" ".memory")

BATCH_ADMISSION_ISOLATION_WORK="batch_worktree_creation_when_isolation_on"

BATCH_ADMISSION_VERDICT=""
BATCH_ADMISSION_REASON=""
BATCH_ADMISSION_MESSAGE=""

# _bal_declared <project_root> <jq_filter> -- stdout: the filter's raw output over
# <project_root>/.claude-extensions.json, or nothing for every absence/cannot-parse case.
_bal_declared() {
  local root="$1" filter="$2" file
  file="${root}/.claude-extensions.json"
  [ -f "$file" ] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq -r "$filter" "$file" 2>/dev/null || true
  return 0
}

batch_admission_worktree_isolation() {
  local root="${1:-.}" raw
  raw="$(_bal_declared "$root" '
    if (type == "object") and has("worktree_isolation") and (.worktree_isolation != null)
    then (.worktree_isolation | if type == "string" then "s:" + . else "j:" + tojson end)
    else "absent" end')"
  case "$raw" in
    ""|absent|s:off) echo "off" ;;
    s:batch) echo "batch" ;;
    s:*) printf '%s\n' "${raw#s:}" ;;
    j:*) printf '%s\n' "${raw#j:}" ;;
    *) echo "off" ;;
  esac
  return 0
}

batch_admission_integration_branch() {
  local root="${1:-.}"
  _bal_declared "$root" '
    if (type == "object") and ((.integration_branch | type) == "string")
       and (.integration_branch != "")
    then .integration_branch else empty end'
  return 0
}

_bal_is_work_tree() {
  local root="$1"
  command -v git >/dev/null 2>&1 || return 1
  [ "$(git -C "$root" rev-parse --is-inside-work-tree 2>/dev/null || true)" = "true" ]
}

batch_admission_dirty_paths() {
  local root="${1:-.}" member
  local -a spec=(".")
  _bal_is_work_tree "$root" || return 0
  git -C "$root" rev-parse -q --verify 'HEAD^{commit}' >/dev/null 2>&1 || return 0
  for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
    spec+=(":(exclude)${member}")
  done
  git -C "$root" diff --name-only -z HEAD -- "${spec[@]}" 2>/dev/null | tr '\0' '\n' || true
  return 0
}

batch_admission_record_path() {
  local specs_dir="$1" session_id="$2"
  if declare -F runtime_batch_record_path >/dev/null 2>&1; then
    runtime_batch_record_path "$specs_dir" "$session_id"
  else
    echo "${specs_dir}/.orchestration/batch/${session_id}.json"
  fi
  return 0
}

# _bal_write_record <project_root> <record_path> <session_id> <task_numbers_json>
#                   <orchestration_id> <branch> <declared: true|false> <isolation>
# Tmp-file-then-rename; creates the record's directory on demand. A failure to write is a named
# warning on standard error, never a refusal.
_bal_write_record() {
  local root="$1" record="$2" session_id="$3" tasks_json="$4" orch_id="$5"
  local branch="$6" declared="$7" isolation="$8"
  local tip dir tmp now
  command -v jq >/dev/null 2>&1 || return 0
  if [ -n "$branch" ] && [ "$declared" = "true" ]; then
    tip="$(git -C "$root" rev-parse -q --verify "refs/heads/${branch}^{commit}" 2>/dev/null || true)"
  else
    tip="$(git -C "$root" rev-parse -q --verify 'HEAD^{commit}' 2>/dev/null || true)"
  fi
  printf '%s' "$tasks_json" | jq -e 'type == "array"' >/dev/null 2>&1 || tasks_json="[]"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  dir="$(dirname "$record")"
  if ! mkdir -p "$dir" 2>/dev/null; then
    echo "WARNING: batch-admission-lib.sh: could not create ${dir}; no batch record written." >&2
    return 0
  fi
  tmp="${record}.tmp.$$"
  if jq -n \
      --arg session_id "$session_id" --arg orch_id "$orch_id" --argjson tasks "$tasks_json" \
      --arg admitted_at "$now" --arg branch "$branch" --arg declared "$declared" \
      --arg tip "$tip" --arg isolation "$isolation" \
      '{
        schema: 1,
        session_id: $session_id,
        orchestration_id: (if $orch_id == "" then null else $orch_id end),
        task_numbers: $tasks,
        admitted_at: $admitted_at,
        integration_branch: (if $branch == "" then null else $branch end),
        integration_branch_declared: ($declared == "true"),
        integration_tip_at_cut: (if $tip == "" then null else $tip end),
        worktree_isolation: $isolation,
        landing_proofs: []
      }' > "$tmp" 2>/dev/null && mv -f "$tmp" "$record" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp" 2>/dev/null || true
  echo "WARNING: batch-admission-lib.sh: could not write batch record ${record}." >&2
  return 0
}

batch_admission_evaluate() {
  local root="${1:-.}" specs_dir="${2:-}" session_id="${3:-}" dry_run="${4:-false}"
  local tasks_json="${5:-[]}" orch_id="${6:-}"
  local isolation declared_branch current_branch record="" first_cycle="true"
  local dirty count listed territory member shown

  BATCH_ADMISSION_VERDICT="admit"
  BATCH_ADMISSION_REASON=""
  BATCH_ADMISSION_MESSAGE=""

  # 1. Isolation mode. Needs no git; runs every cycle.
  isolation="$(batch_admission_worktree_isolation "$root")"
  if [ "$isolation" != "off" ]; then
    BATCH_ADMISSION_VERDICT="refuse"
    BATCH_ADMISSION_REASON="isolation_unimplemented"
    if [ "$isolation" = "batch" ]; then
      BATCH_ADMISSION_MESSAGE="Admission refused: .claude-extensions.json declares worktree_isolation \"batch\", which is declared but not implemented. No worktree machinery exists; it is built by ${BATCH_ADMISSION_ISOLATION_WORK}. Remove the key or declare \"off\" to run in the primary working tree."
    else
      shown="$(_bal_declared "$root" '.worktree_isolation | tojson')"
      BATCH_ADMISSION_MESSAGE="Admission refused: .claude-extensions.json declares worktree_isolation ${shown:-$isolation}, which is not a recognised value. The live value is \"off\"; \"batch\" is declared but not implemented, pending ${BATCH_ADMISSION_ISOLATION_WORK}. Remove the key or declare \"off\" to run in the primary working tree."
    fi
    return 0
  fi

  # 2. Not a git work tree: nothing below can be tested, and no record is written.
  if ! _bal_is_work_tree "$root"; then
    BATCH_ADMISSION_VERDICT="skip"
    return 0
  fi

  if [ -n "$specs_dir" ] && [ -n "$session_id" ]; then
    record="$(batch_admission_record_path "$specs_dir" "$session_id")"
    [ -f "$record" ] && first_cycle="false"
  fi

  declared_branch="$(batch_admission_integration_branch "$root")"
  current_branch="$(git -C "$root" symbolic-ref -q --short HEAD 2>/dev/null || true)"

  if [ -z "$declared_branch" ]; then
    # 3. Undeclared: one named advisory on the first cycle, neither refusal armed.
    if [ "$first_cycle" = "true" ]; then
      if [ -n "$current_branch" ]; then
        echo "ADVISORY: integration_branch is not declared in .claude-extensions.json; admission falls back to the checked-out branch '${current_branch}' and tests neither the branch nor the tree. Declare integration_branch to arm admission (see context/standards/repo-level-declarations.md)." >&2
      else
        echo "ADVISORY: integration_branch is not declared in .claude-extensions.json and HEAD is detached; admission tests neither the branch nor the tree. Declare integration_branch to arm admission (see context/standards/repo-level-declarations.md)." >&2
      fi
    fi
  else
    # 4. Branch test, every cycle. symbolic-ref (not rev-parse --abbrev-ref) so a detached HEAD
    #    reads as no branch rather than as the literal string "HEAD".
    if [ "$current_branch" != "$declared_branch" ]; then
      BATCH_ADMISSION_VERDICT="refuse"
      BATCH_ADMISSION_REASON="off_integration_branch"
      if [ -n "$current_branch" ]; then
        BATCH_ADMISSION_MESSAGE="Admission refused: the primary working tree is on branch '${current_branch}', but .claude-extensions.json declares integration_branch '${declared_branch}'. Switch the primary tree to '${declared_branch}' before invoking /orchestrate."
      else
        BATCH_ADMISSION_MESSAGE="Admission refused: the primary working tree has a detached HEAD, but .claude-extensions.json declares integration_branch '${declared_branch}'. Switch the primary tree to '${declared_branch}' before invoking /orchestrate."
      fi
      return 0
    fi

    # 5. Dirty test, first cycle only: later cycles see this invocation's own uncommitted work.
    if [ "$first_cycle" = "true" ]; then
      dirty="$(batch_admission_dirty_paths "$root")"
      if [ -n "$dirty" ]; then
        count="$(printf '%s\n' "$dirty" | grep -c . || true)"
        listed="$(printf '%s\n' "$dirty" | paste -sd, - | sed 's/,/, /g')"
        territory=""
        for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
          territory="${territory:+${territory}, }${member}"
        done
        BATCH_ADMISSION_VERDICT="refuse"
        BATCH_ADMISSION_REASON="dirty_primary_tree"
        BATCH_ADMISSION_MESSAGE="Admission refused: ${count} tracked path(s) outside the state territory (${territory}) differ from HEAD: ${listed}. Commit them or set them aside, then re-run."
        return 0
      fi
    fi
  fi

  # 6. Admit. One record per invocation: written only when none exists for this session.
  if [ "$first_cycle" = "true" ] && [ "$dry_run" != "true" ] && [ -n "$record" ]; then
    if [ -n "$declared_branch" ]; then
      _bal_write_record "$root" "$record" "$session_id" "$tasks_json" "$orch_id" \
        "$declared_branch" "true" "$isolation"
    else
      _bal_write_record "$root" "$record" "$session_id" "$tasks_json" "$orch_id" \
        "$current_branch" "false" "$isolation"
    fi
  fi
  return 0
}
