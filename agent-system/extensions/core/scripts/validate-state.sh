#!/usr/bin/env bash
# validate-state.sh - Validate a specs/state.json-shaped file against
# context/schemas/state-schema.json.
#
# Follows the hand-rolled bash+jq idiom documented in context/formats/errors-format.md (see that
# file's explicit no-runtime-JSON-Schema-engine policy statement, which names the two tools this
# codebase deliberately avoids). Both subcommands are hand-validated in the events-append.sh
# idiom -- required-arg presence, closed-enum case checks, integer regex checks, and jq-shape
# checks. This script references context/schemas/state-schema.json and
# scripts/lib/status-vocabulary.sh in comments/sourcing only -- it never shells out to any
# external schema-validation engine or library. Structural model: scripts/validate-handoff.sh
# (argument parsing, --help, colored PASS/FAIL/WARN counters, hand-rolled checks).
#
# Deliberately argument-relative, not PROJECT_ROOT-relative: this script takes a state-file path
# directly (mirroring validate-handoff.sh, which takes a handoff-file path directly) rather than
# resolving a repo root via scripts/lib/common.sh + deploy-root-guard.sh. The sibling TODO.md and
# sibling archive/state.json used by the --deep checks below are located relative to STATE_FILE's
# own directory, not PROJECT_ROOT, so this script runs correctly from either the deployed tree
# (.claude/scripts/validate-state.sh) or the source store
# (agent-system/extensions/core/scripts/validate-state.sh) without deploy-root-guard.sh's
# deploy-tree-only restriction.
#
# Usage:
#   validate-state.sh [--deep] [--allow-artifact-removal <project_number>[:<type>]]...
#                      [--fix] [--session-id SID] [STATE_FILE]
#   validate-state.sh --help
#
# STATE_FILE defaults to specs/state.json relative to the current working directory when omitted.
#
# --allow-artifact-removal <project_number>[:<type>] (repeatable): explicit, named opt-in for the
#   --deep per-type artifact-loss check below. `6` permits net artifact removal of any type for
#   project_number 6; `6:summary` permits it only for type "summary" on project_number 6. A
#   malformed value (non-integer project_number, or an empty type after ':') is a hard error,
#   exit 2 -- never a silent ignore.
#
# --fix: opt-in only, never implicit. Repairs Check 9 Class A (exact-duplicate) file_scope
#   entries, order-preservingly, then re-validates (repair-then-revalidate). Writes ONLY through a
#   DEPLOYED state-write.sh (a path matching */.claude/scripts/ or */.opencode/scripts/) --
#   candidates, in order: $SCRIPT_DIR/state-write.sh, $SCRIPT_DIR/../../.claude/scripts/, then the
#   git toplevel of STATE_FILE's own directory + /.claude/scripts/. Refuses loudly (exit 2, naming
#   every candidate checked) when none resolves; NEVER falls back to a hand-rolled write. Refuses
#   (exit 1) on unparseable JSON before attempting any repair. Class B (normalization-equivalent)
#   duplicates are never touched by --fix -- see Check 9 above. `--session-id SID` optionally
#   supplies the session id state-write.sh attributes the write to; a session id is
#   self-generated via lib/common.sh's common_session_id() when omitted.
#
# FILE_SCOPE_COARSE_MIN_OVERLAP (environment variable, optional, default 3): the minimum distinct
#   non-terminal-task blast radius (see Check 8 below) an entry must have, in addition to the
#   trailing-slash structural pre-filter, before it is flagged coarse. A non-integer value is a
#   hard error, exit 2 -- never a silent fallback to the default.
#
# Exit codes:
#   0 - valid (no FAIL-level finding; Checks 8, 9, 10 and 11 below are WARN-only and never fail
#       the run)
#   1 - invalid (at least one FAIL-level finding), OR --fix given unparseable JSON
#   2 - environment error (file not found, jq unavailable, a required shared library could not be
#       found at any candidate path, a malformed --allow-artifact-removal value, a non-integer
#       FILE_SCOPE_COARSE_MIN_OVERLAP, a missing --session-id argument, or --fix unable to resolve
#       a deployed state-write.sh)
#
# Base-mode checks (always run):
#   - JSON is parsable
#   - required top-level fields present: next_project_number, active_projects
#   - no unknown top-level fields (mirrors the schema's additionalProperties: false)
#   - no unknown active_projects[] entry fields (same)
#   - every active_projects[].status value is a member of the closed 12-value enum
#     (scripts/lib/status-vocabulary.sh)
#   - every active_projects[].project_number is a number
#   - every active_projects[].task_type is a non-empty string
#   - Check 8 (WARN-only): coarse, whole-directory-root file_scope declarations. An entry is
#     flagged iff it is declared with a trailing slash (structural pre-filter) AND overlaps at
#     least FILE_SCOPE_COARSE_MIN_OVERLAP distinct OTHER non-terminal tasks, using the canonical
#     scopes_overlap_first predicate from scripts/lib/file-scope-overlap.sh. Non-terminal means
#     status not in {completed, abandoned, expanded}. Known, accepted limitation: a directory
#     declared WITHOUT a trailing slash is not flagged -- the alternative "no file extension"
#     heuristic produces false positives on every extensionless file, and this repo declares its
#     directories with trailing slashes in all observed live cases. Never blocking: this check
#     exists to surface declaration-quality issues at review/creation time, not to gate deploy.
#   - Check 9 (WARN-only): duplicate file_scope entries within a single task's own array, in two
#     labelled classes. Class A (exact duplicates -- the same string twice) is repairable via
#     --fix (see below). Class B (normalization-equivalent -- distinct strings that collapse
#     under the shared `norm` def, e.g. "a/" vs "a") is reported but never auto-repaired, since
#     choosing which spelling survives is a judgment call. Never blocking.
#   - Check 10 (WARN-only): missing / literal-null / empty-array file_scope, over the same
#     non-terminal population as Check 8/9. Absence is a property of the FIELD, not of an entry
#     -- Checks 8/9 both silently skip it via the `// []` idiom, so this check exists specifically
#     to make that invisible-by-construction state visible. Reports three separately-labelled
#     sub-states, all WARN: missing_key (the field is absent), null_value (a literal `null` --
#     also orchestrate-predispatch-review.sh's Class B territory, but that script only reviews a
#     caller-supplied batch, not the whole file), and empty_array (an explicit `[]`, possibly a
#     deliberate "this task touches nothing" assertion). PROMOTION CRITERION (advisory-first, per
#     plan-format.md's "Enforcement level" subsection -- the in-repo precedent for this exact
#     rollout shape): promote missing_key and null_value from WARN to FAIL once no non-terminal
#     task under specs/ lacks a usable file_scope. empty_array stays advisory INDEFINITELY and is
#     never a promotion candidate. This task does NOT perform the promotion; --strict (see below)
#     makes all three exit-blocking today for an opt-in caller.
#   - Check 11 (WARN-only): glob-shaped file_scope entries (containing `*`, `?`, or `[`), via the
#     canonical is_glob_entry predicate in scripts/lib/file-scope-overlap.sh. A glob entry is
#     invisible to the symmetric Overlap predicate (Check 8 above) BY DESIGN -- see
#     context/patterns/file-footprint-overlap.md's Non-Goals -- so the WARN names that concrete
#     consequence rather than calling the shape invalid; a glob remains fully valid for the
#     separate Containment predicate (path_covered_by_scope(), consumed by git-snapshot.sh).
#     PROMOTION CRITERION: advisory indefinitely -- globs remain legitimate for the Containment
#     consumer, so there is no promotion bar to reach; this is a deliberate permanent WARN, not an
#     oversight.
#
# --deep mode additionally checks:
#   - active_projects[].project_number uniqueness
#   - TODO.md sync: regenerates TODO.md from STATE_FILE to a temp file via generate-todo.sh and
#     diffs it against STATE_FILE's sibling TODO.md (skipped with a note if no sibling TODO.md
#     exists, e.g. when validating an isolated fixture)
#   - dependency-graph integrity: dangling dependencies (a referenced project_number absent from
#     both active_projects and the sibling archive/state.json's archived/abandoned/completed
#     project arrays), self-references, and cycles
#   - terminal-status immutability (WARN-level, best-effort): compares each entry's current status
#     against the status recorded for the same project_number in the most recent git-committed
#     version of STATE_FILE, since state.json carries no previous-status field to diff against
#     in-place. Skipped with a WARN when STATE_FILE is not inside a git work tree or has no prior
#     committed version.
#   - per-type artifact-loss invariant (D5, FAIL-level): reusing the same prior git-committed
#     version fetched for the terminal-status check above, for every project_number present in
#     BOTH the prior and live active_projects, and for every distinct artifacts[].type (entries
#     with absent/null .type grouped under the sentinel "(untyped)"), the count of distinct paths
#     removed must not exceed the count of distinct paths added -- see
#     rules/state-management.md's "Artifacts Are Append-Only" subsection. A project_number present
#     in the prior version but absent from the live active_projects is skipped (archival, covered
#     elsewhere). Suppressible per (project_number[, type]) via --allow-artifact-removal; every
#     suppression is still logged, never silent. Skipped with the same style of warning as the
#     terminal-status check when the prior-commit fetch is unavailable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DEEP=false
STATE_FILE=""
ALLOW_ARTIFACT_REMOVAL=()
FIX_MODE=false
FIX_SESSION_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deep)
      DEEP=true
      shift
      ;;
    --fix)
      FIX_MODE=true
      shift
      ;;
    --session-id)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --session-id requires an argument" >&2
        exit 2
      fi
      FIX_SESSION_ID="$2"
      shift 2
      ;;
    --allow-artifact-removal)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --allow-artifact-removal requires an argument: <project_number>[:<type>]" >&2
        exit 2
      fi
      _aar_val="$2"
      _aar_proj="${_aar_val%%:*}"
      if [[ "$_aar_val" == *:* ]]; then
        _aar_type="${_aar_val#*:}"
        if [[ -z "$_aar_type" ]]; then
          echo "ERROR: --allow-artifact-removal: empty type after ':' in '$_aar_val'" >&2
          exit 2
        fi
      fi
      if ! [[ "$_aar_proj" =~ ^[0-9]+$ ]]; then
        echo "ERROR: --allow-artifact-removal: invalid project_number in '$_aar_val' (must be an integer)" >&2
        exit 2
      fi
      ALLOW_ARTIFACT_REMOVAL+=("$_aar_val")
      shift 2
      ;;
    --help|-h)
      # Dynamic range (never a hardcoded line count): prints every leading `#`-comment line
      # starting at line 2, stopping at the first non-`#` line (the blank line before
      # `set -uo pipefail`). A hardcoded `sed -n 'START,ENDp'` range went stale and silently
      # truncated --help output the moment Check 10/11 grew this header past its old end line --
      # this form cannot go stale again as the header grows.
      awk 'NR==1{next} /^#/{print; next} {exit}' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      STATE_FILE="$1"
      shift
      ;;
  esac
done

# Returns success (0) iff a prior (project_number, type) artifact-loss finding is covered by an
# --allow-artifact-removal entry. An entry without a ':type' suffix matches any type for that
# project_number; an entry with a ':type' suffix matches only that exact type.
allow_artifact_removal_matches() {
  local pnum="$1" ptype="$2" entry proj etype
  for entry in "${ALLOW_ARTIFACT_REMOVAL[@]:-}"; do
    [[ -z "$entry" ]] && continue
    proj="${entry%%:*}"
    if [[ "$entry" == *:* ]]; then
      etype="${entry#*:}"
    else
      etype=""
    fi
    if [[ "$proj" == "$pnum" ]] && { [[ -z "$etype" ]] || [[ "$etype" == "$ptype" ]]; }; then
      return 0
    fi
  done
  return 1
}

if [[ -z "$STATE_FILE" ]]; then
  STATE_FILE="specs/state.json"
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo -e "${RED}[FAIL]${NC} File not found: $STATE_FILE"
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}[FAIL]${NC} jq not available" >&2
  exit 2
fi

# ─── --fix: opt-in-only repair of exact-duplicate (Check 9 Class A) file_scope entries ─────────
# D3: writes ONLY through a DEPLOYED state-write.sh (matched against */.claude/scripts/ or
# */.opencode/scripts/) -- never a hand-rolled `jq > tmp && mv` sequence, which would reopen the
# two corruption channels state-write.sh's own header says it exists to close. Refuses loudly
# (exit 2) when no deployed copy resolves; never falls back to an in-script write. Class B
# (normalization-equivalent) entries are NEVER touched by --fix -- see D2. Repair-then-revalidate:
# this block does not exit early on success: execution falls through into the normal Checks 1-9
# (and --deep, if requested) below, re-reading $STATE_FILE fresh from disk.
if [[ "$FIX_MODE" == "true" ]]; then
  if ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo -e "${RED}[FAIL]${NC} --fix refuses: unparseable JSON in $STATE_FILE"
    exit 1
  fi

  # Candidate order (D3): $SCRIPT_DIR/state-write.sh, then $SCRIPT_DIR/../../.claude/scripts/,
  # then the git toplevel of STATE_FILE's own directory + /.claude/scripts/. A candidate is only
  # accepted if it BOTH exists AND its own path matches a deployed-tree shape -- this is what
  # correctly excludes the source-store copy of state-write.sh (which sits right next to this
  # script and would otherwise satisfy the first candidate purely by existing).
  _fix_state_dir="$(cd "$(dirname "$STATE_FILE")" && pwd)"
  _fix_toplevel="$(git -C "$_fix_state_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  FIX_STATE_WRITE_CANDIDATES=(
    "$SCRIPT_DIR/state-write.sh"
    "$SCRIPT_DIR/../../.claude/scripts/state-write.sh"
  )
  if [[ -n "$_fix_toplevel" ]]; then
    FIX_STATE_WRITE_CANDIDATES+=("$_fix_toplevel/.claude/scripts/state-write.sh")
  fi
  FIX_STATE_WRITE=""
  for _candidate in "${FIX_STATE_WRITE_CANDIDATES[@]}"; do
    if [[ -f "$_candidate" ]] && [[ "$_candidate" == *"/.claude/scripts/"* || "$_candidate" == *"/.opencode/scripts/"* ]]; then
      FIX_STATE_WRITE="$_candidate"
      break
    fi
  done
  if [[ -z "$FIX_STATE_WRITE" ]]; then
    echo "ERROR: --fix requires a DEPLOYED state-write.sh (path matching */.claude/scripts/ or */.opencode/scripts/); none found at any of:" >&2
    for _candidate in "${FIX_STATE_WRITE_CANDIDATES[@]}"; do
      echo "  $_candidate" >&2
    done
    echo "Deploy first (bash .claude/scripts/deploy-headless.sh), then re-run --fix." >&2
    exit 2
  fi

  # Order-preserving dedup filter (D3): `unique` sorts and must not be used. Only entries that
  # ALREADY have a file_scope field are touched (`if has("file_scope") then ... else . end`) --
  # never introduces a file_scope: [] field on an entry that never had one, and an entry whose
  # file_scope already has no duplicates is left byte-identical (the filter is idempotent there).
  _fix_report=$(jq -c '
    [ .active_projects[] | . as $t |
      select(has("file_scope")) |
      ($t.file_scope // []) as $fs |
      ($fs | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) as $dedup |
      select(($fs | length) != ($dedup | length)) |
      {project_number: $t.project_number, removed: (($fs | length) - ($dedup | length))}
    ]' "$STATE_FILE")
  _fix_count=$(jq 'length' <<< "${_fix_report:-[]}" 2>/dev/null || echo 0)
  if [[ -z "$_fix_count" || "$_fix_count" -eq 0 ]]; then
    echo "--fix: nothing to repair (no exact-duplicate file_scope entries found in $STATE_FILE)."
  else
    while IFS=$'\t' read -r _fp _fr; do
      [[ -z "$_fp" ]] && continue
      echo "--fix: project_number $_fp: removing $_fr exact-duplicate file_scope entry(ies)"
    done < <(jq -r '.[] | [(.project_number|tostring), (.removed|tostring)] | @tsv' <<< "$_fix_report")
    _fix_session="${FIX_SESSION_ID:-$(common_session_id)}"
    _fix_state_abs="$_fix_state_dir/$(basename "$STATE_FILE")"
    bash "$FIX_STATE_WRITE" \
      '.active_projects = [.active_projects[] | if has("file_scope") then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]' \
      --state-file "$_fix_state_abs" \
      --session-id "$_fix_session"
    _fix_rc=$?
    if [[ "$_fix_rc" -ne 0 ]]; then
      echo -e "${RED}[FAIL]${NC} --fix: state-write.sh failed (exit $_fix_rc); re-validating current on-disk state" >&2
    else
      echo "--fix applied via $FIX_STATE_WRITE."
    fi
  fi
  echo "Re-validating..."
  echo ""
fi

# --- Shared status-vocabulary library (deploy-tree-first / source-store-fallback) ---
VOCAB_LIB_CANDIDATES=(
  "$SCRIPT_DIR/lib/status-vocabulary.sh"
  "$SCRIPT_DIR/../../.claude/scripts/lib/status-vocabulary.sh"
)
VOCAB_LIB=""
for _candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    VOCAB_LIB="$_candidate"
    break
  fi
done
if [[ -z "$VOCAB_LIB" ]]; then
  echo "ERROR: shared library status-vocabulary.sh not found at any of:" >&2
  for _candidate in "${VOCAB_LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$VOCAB_LIB"

# --- Shared file-scope-overlap library (deploy-tree-first / source-store-fallback) ---
# Exports FILE_SCOPE_OVERLAP_JQ_DEFS -- the canonical, single-source-of-truth jq def text for the
# overlap predicate (norm / scopes_overlap_first). Check 8 below splices this text into its own
# jq -n program rather than re-deriving the algorithm locally -- see that library's own header.
FSO_LIB_CANDIDATES=(
  "$SCRIPT_DIR/lib/file-scope-overlap.sh"
  "$SCRIPT_DIR/../../.claude/scripts/lib/file-scope-overlap.sh"
)
FSO_LIB=""
for _candidate in "${FSO_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    FSO_LIB="$_candidate"
    break
  fi
done
if [[ -z "$FSO_LIB" ]]; then
  echo "ERROR: shared library file-scope-overlap.sh not found at any of:" >&2
  for _candidate in "${FSO_LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$FSO_LIB"

# --- FILE_SCOPE_COARSE_MIN_OVERLAP: default 3, hard error (exit 2) on a non-integer override ---
if [[ -n "${FILE_SCOPE_COARSE_MIN_OVERLAP:-}" ]]; then
  if ! [[ "$FILE_SCOPE_COARSE_MIN_OVERLAP" =~ ^[0-9]+$ ]]; then
    echo "ERROR: FILE_SCOPE_COARSE_MIN_OVERLAP must be a non-negative integer, got '$FILE_SCOPE_COARSE_MIN_OVERLAP'" >&2
    exit 2
  fi
  COARSE_MIN_OVERLAP="$FILE_SCOPE_COARSE_MIN_OVERLAP"
else
  COARSE_MIN_OVERLAP=3
fi

PASSED=0
FAILED=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }

echo "Validating state file: $STATE_FILE"
[[ "$DEEP" == "true" ]] && echo "Mode: base + --deep"
echo ""

# ─── Check 1: JSON parsability ─────────────────────────────────────────────────────────────────
if jq empty "$STATE_FILE" 2>/dev/null; then
  log_pass "JSON is valid and parsable"
else
  echo -e "${RED}[FAIL]${NC} Invalid JSON: $(jq empty "$STATE_FILE" 2>&1)"
  echo ""
  echo "VALIDATION FAILED (invalid JSON)"
  exit 1
fi

# ─── Check 2: Required top-level fields ────────────────────────────────────────────────────────
for field in next_project_number active_projects; do
  if jq -e --arg f "$field" 'has($f)' "$STATE_FILE" >/dev/null 2>&1; then
    log_pass "Required top-level field present: $field"
  else
    log_fail "Required top-level field missing: $field"
  fi
done

# ─── Check 3: No unknown top-level fields ──────────────────────────────────────────────────────
# Mirrors context/schemas/state-schema.json's top-level additionalProperties: false. Hardcoded
# here (not parsed from the schema at runtime) matching validate-handoff.sh's own precedent of
# hand-coded required-field lists.
KNOWN_TOP_LEVEL_FIELDS=(
  next_project_number default_task_type active_projects active_topics completed_projects
  repository_health memory_health version vault_count vault_history
)
unknown_top=$(jq -r 'keys[]' "$STATE_FILE" 2>/dev/null | while IFS= read -r k; do
  known=0
  for kf in "${KNOWN_TOP_LEVEL_FIELDS[@]}"; do
    [[ "$k" == "$kf" ]] && known=1 && break
  done
  [[ "$known" -eq 0 ]] && printf '%s\n' "$k"
done)
if [[ -z "$unknown_top" ]]; then
  log_pass "No unknown top-level fields (matches state-schema.json's additionalProperties: false)"
else
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    log_fail "Unknown top-level field: $k (not in state-schema.json)"
  done <<< "$unknown_top"
fi

# ─── Check 4: No unknown per-entry fields ──────────────────────────────────────────────────────
# NOTE: this list duplicates context/schemas/state-schema.json's project-object properties and
# is kept in sync by hand -- there is no drift test for the pair (unlike the status enum, which
# scripts/tests/test-status-vocabulary.sh guards). Adding a field here without adding it to the
# schema, or vice versa, produces a validator that disagrees with the schema it enforces.
KNOWN_ENTRY_FIELDS=(
  project_number project_name status task_type title topic description session_id effort
  priority created last_updated dependencies file_scope artifacts next_artifact_number
  completion_summary roadmap_items memory_candidates reflection
)
unknown_entry=$(jq -r '.active_projects[] | keys[]' "$STATE_FILE" 2>/dev/null | sort -u | while IFS= read -r k; do
  known=0
  for kf in "${KNOWN_ENTRY_FIELDS[@]}"; do
    [[ "$k" == "$kf" ]] && known=1 && break
  done
  [[ "$known" -eq 0 ]] && printf '%s\n' "$k"
done)
if [[ -z "$unknown_entry" ]]; then
  log_pass "No unknown active_projects[] entry fields"
else
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    bad_entries=$(jq -r --arg f "$k" '[.active_projects[] | select(has($f)) | .project_number] | join(",")' "$STATE_FILE")
    log_fail "Unknown entry field: $k (on project_number(s): $bad_entries)"
  done <<< "$unknown_entry"
fi

# ─── Check 5: status enum membership ───────────────────────────────────────────────────────────
bad_status_count=0
while IFS=$'\t' read -r pnum status; do
  [[ -z "$pnum" ]] && continue
  if status_vocabulary_is_valid "$status"; then
    :
  else
    log_fail "project_number $pnum has off-schema status '$status' (not in the closed 12-value enum)"
    bad_status_count=$((bad_status_count + 1))
  fi
done < <(jq -r '.active_projects[] | [(.project_number|tostring), (.status // "__MISSING__")] | @tsv' "$STATE_FILE")
if [[ "$bad_status_count" -eq 0 ]]; then
  log_pass "All active_projects[].status values are members of the closed enum"
fi

# ─── Check 6: project_number is a number ───────────────────────────────────────────────────────
bad_pnum=$(jq -r '[.active_projects[] | select((.project_number | type) != "number") | (.project_name // "unknown")] | join(",")' "$STATE_FILE")
if [[ -z "$bad_pnum" ]]; then
  log_pass "All active_projects[].project_number values are numbers"
else
  log_fail "Non-numeric project_number on entries: $bad_pnum"
fi

# ─── Check 7: task_type is a non-empty string ──────────────────────────────────────────────────
bad_ttype=$(jq -r '[.active_projects[] | select(((.task_type | type) != "string") or (.task_type | length) == 0) | (.project_number|tostring)] | join(",")' "$STATE_FILE")
if [[ -z "$bad_ttype" ]]; then
  log_pass "All active_projects[].task_type values are non-empty strings"
else
  log_fail "Missing/empty task_type on project_number(s): $bad_ttype"
fi

# ─── Check 8: coarse (blast-radius) file_scope declarations (WARN-only, base mode) ─────────────
# D1: flagged iff the entry, as declared (pre-normalization), ends with "/" AND overlaps at least
# COARSE_MIN_OVERLAP distinct OTHER non-terminal tasks, via the canonical scopes_overlap_first
# predicate spliced from file-scope-overlap.sh (never re-derived locally). Non-terminal means
# status not in {completed, abandoned, expanded}; both sides of the comparison are filtered to
# non-terminal. WARN-only, always -- see the header note on why log_fail here would turn today's
# live declarations into deploy blockers.
_check8_prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
def is_terminal: . == \"completed\" or . == \"abandoned\" or . == \"expanded\";
(.active_projects) as \$all |
[ \$all[] | select(((.status // \"\") | is_terminal) | not) ] as \$nonterm |
[
  \$nonterm[] as \$task |
  (\$task.file_scope // [])[] as \$entry |
  select(\$entry | endswith(\"/\")) |
  (
    [
      \$nonterm[] as \$other |
      select(\$other.project_number != \$task.project_number) |
      select( scopes_overlap_first([\$entry]; (\$other.file_scope // [])) ) |
      \$other.project_number
    ] | unique
  ) as \$overlaps |
  select((\$overlaps | length) >= \$min) |
  {project_number: \$task.project_number, entry: \$entry, count: (\$overlaps | length), overlaps: \$overlaps}
] | sort_by(-.count, .project_number, .entry)"
coarse_findings=$(jq -c --argjson min "$COARSE_MIN_OVERLAP" "$_check8_prog" "$STATE_FILE" 2>/dev/null)
coarse_count=$(jq 'length' <<< "${coarse_findings:-[]}" 2>/dev/null || echo 0)
if [[ -z "$coarse_count" || "$coarse_count" -eq 0 ]]; then
  log_pass "No coarse (blast radius >= $COARSE_MIN_OVERLAP) file_scope declarations found"
else
  while IFS=$'\t' read -r _c8_pnum _c8_entry _c8_count _c8_overlaps; do
    [[ -z "$_c8_pnum" ]] && continue
    log_warn "Coarse file_scope declaration: project_number $_c8_pnum, entry '$_c8_entry' overlaps $_c8_count distinct non-terminal task(s): $_c8_overlaps"
  done < <(jq -r '.[:10][] | [(.project_number|tostring), .entry, (.count|tostring), (.overlaps | map(tostring) | join(","))] | @tsv' <<< "$coarse_findings")
  if [[ "$coarse_count" -gt 10 ]]; then
    _c8_remaining=$((coarse_count - 10))
    log_warn "... and $_c8_remaining more coarse file_scope declaration(s) not shown (see FILE_SCOPE_COARSE_MIN_OVERLAP to narrow)"
  fi
fi

# ─── Check 9: duplicate file_scope entries (WARN-only, base mode) ──────────────────────────────
# D2: two distinct, separately-labelled classes, computed per task's own file_scope array (no
# cross-task comparison, unlike Check 8). Class A (exact duplicates -- the same string appears
# twice) is repairable by --fix (Phase 4); Class B (normalization-equivalent -- distinct strings
# that collapse to the same value under the canonical `norm` def, e.g. "a/" vs "a") is reported
# but never auto-repaired, since choosing which spelling survives is a judgment call. `norm` is
# reused from the spliced $FILE_SCOPE_OVERLAP_JQ_DEFS, never re-derived locally. WARN-only, always.
_check9_prog="${FILE_SCOPE_OVERLAP_JQ_DEFS}
[
  .active_projects[] | . as \$task |
  (\$task.file_scope // []) as \$fs |
  (\$fs | group_by(.) | map(select(length > 1) | {value: .[0], count: length})) as \$classA |
  (
    (\$fs | unique) as \$uniq |
    [
      range(0; \$uniq | length) as \$i |
      range(\$i + 1; \$uniq | length) as \$j |
      (\$uniq[\$i]) as \$a | (\$uniq[\$j]) as \$b |
      select((\$a | norm) == (\$b | norm)) |
      {a: \$a, b: \$b}
    ]
  ) as \$classB |
  select((\$classA | length) > 0 or (\$classB | length) > 0) |
  {project_number: \$task.project_number, classA: \$classA, classB: \$classB}
]"
dup_findings=$(jq -c "$_check9_prog" "$STATE_FILE" 2>/dev/null)
dup_count=$(jq 'length' <<< "${dup_findings:-[]}" 2>/dev/null || echo 0)
if [[ -z "$dup_count" || "$dup_count" -eq 0 ]]; then
  log_pass "No duplicate file_scope entries found (exact or normalization-equivalent)"
else
  while IFS=$'\t' read -r _c9_pnum _c9_value _c9_count; do
    [[ -z "$_c9_pnum" ]] && continue
    log_warn "Duplicate file_scope entry (Class A, exact -- repairable by --fix): project_number $_c9_pnum, entry '$_c9_value' appears $_c9_count times"
  done < <(jq -r '.[] | .project_number as $p | .classA[] | [($p|tostring), .value, (.count|tostring)] | @tsv' <<< "$dup_findings")
  while IFS=$'\t' read -r _c9_pnum _c9_a _c9_b; do
    [[ -z "$_c9_pnum" ]] && continue
    log_warn "Duplicate file_scope entry (Class B, normalization-equivalent -- NOT auto-repaired): project_number $_c9_pnum, entries '$_c9_a' and '$_c9_b' collide after normalization"
  done < <(jq -r '.[] | .project_number as $p | .classB[] | [($p|tostring), .a, .b] | @tsv' <<< "$dup_findings")
fi

# ─── Check 10: missing / null / empty file_scope (WARN-only, base mode) ────────────────────────
# D1: file_scope ABSENCE is a property of the FIELD, not of an entry -- a different question from
# Check 8 (blast radius) and Check 9 (intra-array duplication), both of which legitimately operate
# on an entry LIST and are silently skipped (via the `// []` idiom) whenever file_scope is absent,
# null, or empty. This check makes that invisible-by-construction state visible, over the same
# non-terminal population as Check 8/9 (status not in {completed, abandoned, expanded}).
#
# D2: reports THREE separately-labelled sub-states, all WARN, never one merged count:
#   - missing_key  -- the field is absent entirely (an omission).
#   - null_value   -- a literal `null` (a schema-default violation; already
#                     orchestrate-predispatch-review.sh's Class B territory, but that script only
#                     reviews a caller-supplied batch, never the whole state file, so this check
#                     surfaces it here too for full-file coverage).
#   - empty_array  -- an explicit `[]` (possibly a deliberate "this task touches nothing"
#                     assertion, not necessarily an omission).
# All three warn (the task title covers "and empty"), labelled separately so a future promotion
# can bind to a subset. Supporting data point: the historical BimodalLogic measurement of "22
# lacking a usable value" this task's dispatch cites tallied missing-key plus literal-null and
# EXCLUDED empty-array -- i.e. that original measurement already treated empty-array as the
# lesser concern.
#
# PROMOTION CRITERION (advisory-first, per plan-format.md's "Enforcement level" subsection -- the
# in-repo precedent for this exact rollout shape: a missing field warns, never fails, until usage
# converges). Applied here per the same three-part pattern: (a) start WARN in default mode; (b)
# write the criterion down, here; (c) do NOT promote in this task. Promote the missing_key and
# null_value sub-states from WARN to FAIL once no non-terminal task under specs/ lacks a usable
# file_scope. The empty_array sub-state stays advisory INDEFINITELY and is never a promotion
# candidate -- an explicit `[]` may be a deliberate assertion. `--strict` (Phase 4/Check 11 below)
# makes all three exit-blocking TODAY for an opt-in caller; this task does not perform the
# promotion in default mode.
_check10_prog="
def is_terminal: . == \"completed\" or . == \"abandoned\" or . == \"expanded\";
(.active_projects) as \$all |
[ \$all[] | select(((.status // \"\") | is_terminal) | not) ] as \$nonterm |
{
  denominator: (\$nonterm | length),
  findings: [
    \$nonterm[] |
    (if (has(\"file_scope\") | not) then \"missing_key\"
     elif (.file_scope == null) then \"null_value\"
     elif (.file_scope == []) then \"empty_array\"
     else empty end) as \$sub_state |
    {project_number: .project_number, project_name: (.project_name // \"\"), sub_state: \$sub_state}
  ] | sort_by(.project_number)
}"
_check10_result=$(jq -c "$_check10_prog" "$STATE_FILE" 2>/dev/null)
scope_denominator=$(jq -r '.denominator // 0' <<< "${_check10_result:-null}" 2>/dev/null || echo 0)
scope_findings=$(jq -c '.findings // []' <<< "${_check10_result:-null}" 2>/dev/null || echo '[]')
scope_count=$(jq 'length' <<< "${scope_findings:-[]}" 2>/dev/null || echo 0)
scope_missing=$(jq '[.[] | select(.sub_state == "missing_key")] | length' <<< "$scope_findings" 2>/dev/null || echo 0)
scope_null=$(jq '[.[] | select(.sub_state == "null_value")] | length' <<< "$scope_findings" 2>/dev/null || echo 0)
scope_empty=$(jq '[.[] | select(.sub_state == "empty_array")] | length' <<< "$scope_findings" 2>/dev/null || echo 0)
if [[ -z "$scope_count" || "$scope_count" -eq 0 ]]; then
  log_pass "No missing/null/empty file_scope found among $scope_denominator non-terminal task(s)"
else
  log_warn "file_scope visibility: $scope_missing missing-key, $scope_null literal-null, $scope_empty empty-array, out of $scope_denominator non-terminal task(s)"
  while IFS=$'\t' read -r _c10_pnum _c10_sub _c10_name; do
    [[ -z "$_c10_pnum" ]] && continue
    log_warn "file_scope $_c10_sub: project_number $_c10_pnum ($_c10_name)"
  done < <(jq -r '.[:10][] | [(.project_number|tostring), .sub_state, .project_name] | @tsv' <<< "$scope_findings")
  if [[ "$scope_count" -gt 10 ]]; then
    _c10_remaining=$((scope_count - 10))
    log_warn "... and $_c10_remaining more file_scope visibility finding(s) not shown"
  fi
fi

# ══════════════════════════════════════════════════════════════════════════════════════════════
# --deep checks
# ══════════════════════════════════════════════════════════════════════════════════════════════
if [[ "$DEEP" == "true" ]]; then
  echo ""
  echo "--- --deep checks ---"

  # --- Check D1: project_number uniqueness ---
  dup_pnums=$(jq -r '[.active_projects[]] | group_by(.project_number) | map(select(length > 1) | .[0].project_number) | .[]' "$STATE_FILE" 2>/dev/null)
  if [[ -z "$dup_pnums" ]]; then
    log_pass "All active_projects[].project_number values are unique"
  else
    while IFS= read -r p; do
      [[ -z "$p" ]] && continue
      log_fail "Duplicate project_number: $p"
    done <<< "$dup_pnums"
  fi

  # --- Check D2: TODO.md sync ---
  state_dir="$(cd "$(dirname "$STATE_FILE")" && pwd)"
  sibling_todo="$state_dir/TODO.md"
  gen_todo_script="$SCRIPT_DIR/generate-todo.sh"
  if [[ ! -f "$sibling_todo" ]]; then
    log_warn "No sibling TODO.md next to $STATE_FILE -- skipping TODO.md sync check"
  elif [[ ! -x "$gen_todo_script" && ! -f "$gen_todo_script" ]]; then
    log_warn "generate-todo.sh not found next to validate-state.sh -- skipping TODO.md sync check"
  else
    tmp_todo="$(mktemp)"
    if bash "$gen_todo_script" --state "$STATE_FILE" --todo "$tmp_todo" --no-log >/dev/null 2>&1; then
      if diff -q "$tmp_todo" "$sibling_todo" >/dev/null 2>&1; then
        log_pass "TODO.md is in sync with $STATE_FILE (regenerated content is byte-identical)"
      else
        log_fail "TODO.md is OUT OF SYNC with $STATE_FILE (regenerated content differs)" \
                  "diff -u '$sibling_todo' '$tmp_todo' for detail"
      fi
    else
      log_fail "generate-todo.sh failed while regenerating TODO.md for the sync check"
    fi
    rm -f "$tmp_todo"
  fi

  # --- Check D3: dependency-graph integrity ---
  self_refs=$(jq -r '[.active_projects[] | . as $e | select(($e.dependencies // []) | index($e.project_number)) | $e.project_number] | join(",")' "$STATE_FILE")
  if [[ -z "$self_refs" ]]; then
    log_pass "No self-referential dependencies"
  else
    log_fail "Self-referential dependencies on project_number(s): $self_refs"
  fi

  # Known project numbers: active_projects union sibling archive/state.json's terminal arrays
  # (archived_projects / abandoned_projects / completed_projects -- archive's own, looser shape;
  # see state-schema.json's header note on why archive is not itself schema-validated here).
  archive_file="$state_dir/archive/state.json"
  known_pnums_file="$(mktemp)"
  jq -r '[.active_projects[].project_number] | .[]' "$STATE_FILE" > "$known_pnums_file"
  if [[ -f "$archive_file" ]]; then
    jq -r '[(.archived_projects // [])[], (.abandoned_projects // [])[], (.completed_projects // [])[] | .project_number] | .[]' \
      "$archive_file" 2>/dev/null >> "$known_pnums_file" || true
  fi

  dangling=$(jq -r '[.active_projects[] | . as $e | ($e.dependencies // [])[] | {from: $e.project_number, to: .}] | .[] | "\(.from)\t\(.to)"' "$STATE_FILE" \
    | while IFS=$'\t' read -r from to; do
        [[ -z "$to" ]] && continue
        if ! grep -qxF "$to" "$known_pnums_file"; then
          printf '%s -> %s\n' "$from" "$to"
        fi
      done)
  if [[ -z "$dangling" ]]; then
    log_pass "No dangling dependency references"
  else
    while IFS= read -r d; do
      [[ -z "$d" ]] && continue
      log_fail "Dangling dependency reference: $d (target project_number not found in active_projects or archive)"
    done <<< "$dangling"
  fi
  rm -f "$known_pnums_file"

  # Cycle detection over active_projects' dependency edges only (archive entries are terminal and
  # cannot participate in an active cycle). Kahn's algorithm: repeatedly remove nodes whose
  # entire dependency list points only at already-removed (or external/non-active) nodes; any
  # node left unremoved after the loop converges is part of a cycle. Adjacency is built directly
  # from jq TSV output (task \t dependency) into bash associative arrays.
  declare -A _adj_count
  declare -A _adj_list
  while IFS=$'\t' read -r from to; do
    [[ -z "$from" ]] && continue
    _adj_count["$from"]=${_adj_count["$from"]:-0}
    if [[ -n "$to" ]]; then
      _adj_list["$from"]="${_adj_list[$from]:-} $to"
      _adj_count["$from"]=$(( ${_adj_count["$from"]} + 1 ))
    fi
  done < <(jq -r '.active_projects[] | . as $e | if ($e.dependencies // [] | length) == 0 then "\($e.project_number)\t" else ($e.dependencies[] | "\($e.project_number)\t\(.)") end' "$STATE_FILE")

  # Kahn's algorithm over the "depends on" edges: a node's in-degree here is its OWN outgoing
  # dependency count (edge direction: task -> dependency). Cycles are detected by repeatedly
  # removing nodes whose entire dependency list points only at already-removed (or external,
  # non-active) nodes; whatever remains once no further removal is possible is the cycle set.
  # Tracked via an associative "still remaining" set rather than a newline-joined string, so
  # membership tests never depend on delimiter-matching (a newline-joined string compared with a
  # space-delimited `*" $d "*` glob silently mismatches whenever a candidate sits at a string
  # boundary next to a newline instead of a space).
  declare -A _still_remaining
  for _node in "${!_adj_count[@]}"; do
    _still_remaining["$_node"]=1
  done
  changed=1
  while [[ "$changed" -eq 1 && "${#_still_remaining[@]}" -gt 0 ]]; do
    changed=0
    for node in "${!_still_remaining[@]}"; do
      deps="${_adj_list[$node]:-}"
      all_resolved=1
      for d in $deps; do
        if [[ -n "${_still_remaining[$d]:-}" ]]; then
          all_resolved=0
          break
        fi
      done
      if [[ "$all_resolved" -eq 1 ]]; then
        unset '_still_remaining[$node]'
        changed=1
      fi
    done
  done
  if [[ "${#_still_remaining[@]}" -eq 0 ]]; then
    log_pass "No dependency cycles detected among active_projects"
  else
    cyc_list=$(printf '%s,' "${!_still_remaining[@]}" | sed 's/,$//')
    log_fail "Dependency cycle detected among project_number(s): $cyc_list"
  fi
  unset _adj_count _adj_list _still_remaining

  # --- Check D4: terminal-status immutability (WARN-level, best-effort) ---
  if command -v git >/dev/null 2>&1 && git -C "$state_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Deliberately WITHOUT --full-name: every git call below is scoped via `-C "$state_dir"`, so
    # rel_path must stay relative to state_dir (git's cwd for these calls), not repo-root-relative
    # -- mixing the two produced a spurious "no history" result during development.
    rel_path=$(git -C "$state_dir" ls-files "$(basename "$STATE_FILE")" 2>/dev/null | head -1)
    prior_commit=""
    if [[ -n "$rel_path" ]]; then
      prior_commit=$(git -C "$state_dir" log -1 --format=%H -- "$rel_path" 2>/dev/null || echo "")
    fi
    if [[ -z "$prior_commit" ]]; then
      log_warn "No git history found for $STATE_FILE -- skipping terminal-status immutability check"
      log_warn "No git history found for $STATE_FILE -- skipping per-type artifact-loss check (D5)"
    else
      # `git show <sha>:<path>` requires a "./"-prefixed (or repo-root-relative) path even under
      # `-C`; a bare relative path that resolves fine for `git log -- <path>` is rejected here
      # with "path 'X' exists, but not '<path>'" -- confirmed empirically during implementation.
      prior_json="$(git -C "$state_dir" show "${prior_commit}:./${rel_path}" 2>/dev/null || echo "")"
      if [[ -z "$prior_json" ]]; then
        log_warn "Could not read prior committed version of $STATE_FILE -- skipping terminal-status immutability check"
        log_warn "Could not read prior committed version of $STATE_FILE -- skipping per-type artifact-loss check (D5)"
      else
        violations=0
        while IFS=$'\t' read -r pnum prior_status; do
          [[ -z "$pnum" ]] && continue
          case "$prior_status" in
            completed|abandoned|expanded)
              cur_status=$(jq -r --arg n "$pnum" '.active_projects[] | select((.project_number|tostring) == $n) | .status // ""' "$STATE_FILE")
              if [[ -n "$cur_status" && "$cur_status" != "$prior_status" ]]; then
                log_warn "project_number $pnum was terminal ('$prior_status') in the prior commit but is now '$cur_status' -- terminal-status immutability violation"
                violations=$((violations + 1))
              fi
              ;;
          esac
        done < <(jq -r '.active_projects[] | [(.project_number|tostring), (.status // "")] | @tsv' <<< "$prior_json" 2>/dev/null)
        if [[ "$violations" -eq 0 ]]; then
          log_pass "No terminal-status immutability violations found against prior git history"
        fi

        # --- Check D5: per-type artifact-loss invariant (FAIL-level) ---
        # Reuses the same $prior_json fetched above rather than issuing a second `git show`. For
        # every project_number present in BOTH prior_json and the live active_projects, compute
        # per-type distinct-path sets and require removed(T) <= added(T). Entries with absent/null
        # .type are grouped under the sentinel key "(untyped)" so they participate in the
        # invariant rather than being silently dropped. A project_number present in prior_json but
        # absent from the live active_projects is skipped -- archival is covered by other checks,
        # not this one.
        d5_unsuppressed=0
        d5_pnums=$(jq -r '[.active_projects[].project_number] | .[]' <<< "$prior_json" 2>/dev/null)
        while IFS= read -r d5_pnum; do
          [[ -z "$d5_pnum" ]] && continue
          if ! jq -e --arg n "$d5_pnum" '.active_projects[] | select((.project_number|tostring) == $n)' "$STATE_FILE" >/dev/null 2>&1; then
            continue
          fi
          d5_prior_types=$(jq -r --arg n "$d5_pnum" \
            '[.active_projects[] | select((.project_number|tostring) == $n) | (.artifacts // [])[] | (.type // "(untyped)")] | unique | .[]' \
            <<< "$prior_json" 2>/dev/null)
          d5_live_types=$(jq -r --arg n "$d5_pnum" \
            '[.active_projects[] | select((.project_number|tostring) == $n) | (.artifacts // [])[] | (.type // "(untyped)")] | unique | .[]' \
            "$STATE_FILE" 2>/dev/null)
          d5_all_types=$(printf '%s\n%s\n' "$d5_prior_types" "$d5_live_types" | sort -u | grep -v '^$')
          [[ -z "$d5_all_types" ]] && continue
          while IFS= read -r d5_type; do
            [[ -z "$d5_type" ]] && continue
            d5_prior_paths=$(jq -r --arg n "$d5_pnum" --arg t "$d5_type" \
              '[.active_projects[] | select((.project_number|tostring) == $n) | (.artifacts // [])[] | select((.type // "(untyped)") == $t) | .path] | unique | .[]' \
              <<< "$prior_json" 2>/dev/null)
            d5_live_paths=$(jq -r --arg n "$d5_pnum" --arg t "$d5_type" \
              '[.active_projects[] | select((.project_number|tostring) == $n) | (.artifacts // [])[] | select((.type // "(untyped)") == $t) | .path] | unique | .[]' \
              "$STATE_FILE" 2>/dev/null)
            d5_removed_count=$(comm -23 <(sort <<< "$d5_prior_paths") <(sort <<< "$d5_live_paths") | grep -c -v '^$')
            d5_added_count=$(comm -13 <(sort <<< "$d5_prior_paths") <(sort <<< "$d5_live_paths") | grep -c -v '^$')
            if [[ "$d5_removed_count" -gt "$d5_added_count" ]]; then
              if allow_artifact_removal_matches "$d5_pnum" "$d5_type"; then
                log_warn "Artifact removal ALLOWED by --allow-artifact-removal opt-in: project_number $d5_pnum, type '$d5_type' (removed=$d5_removed_count added=$d5_added_count)"
              else
                d5_dropped=$(comm -23 <(sort <<< "$d5_prior_paths") <(sort <<< "$d5_live_paths") | grep -v '^$' | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')
                log_fail "Artifact loss: project_number $d5_pnum, type '$d5_type' -- removed=$d5_removed_count added=$d5_added_count, dropped path(s): $d5_dropped (opt in with --allow-artifact-removal $d5_pnum:$d5_type if intentional)"
                d5_unsuppressed=$((d5_unsuppressed + 1))
              fi
            fi
          done <<< "$d5_all_types"
        done <<< "$d5_pnums"
        if [[ "$d5_unsuppressed" -eq 0 ]]; then
          log_pass "No unsuppressed per-type artifact-loss violations found against prior git history"
        fi
      fi
    fi
  else
    log_warn "Not inside a git work tree -- skipping terminal-status immutability check"
    log_warn "Not inside a git work tree -- skipping per-type artifact-loss check (D5)"
  fi
fi

# ─── Summary ────────────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}STATE VALIDATION FAILED${NC}"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo -e "${YELLOW}STATE VALIDATION PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "${GREEN}STATE VALIDATION PASSED${NC}"
  exit 0
fi
