#!/usr/bin/env bash
# test-scope-excursion-record-lib.sh - Regression suite for lib/scope-excursion-record-lib.sh,
# the single home of the batched "scope excursion" issue-record call shape: one non-fatal
# issue-record.sh call per drop event, carrying every dropped path through --tags-json, rather
# than one call per dropped path.
#
# Structural model: test-issue-record.sh's build_scratch/run_ir pattern (an isolated
# <scratch>/.claude/scripts/{issue-record.sh,deploy-root-guard.sh,lib/common.sh,
# lib/task-lookup-lib.sh,lib/central-log-lib.sh} tree with a scratch specs/state.json) combined
# with test-derived-artifact-probe-lib.sh's library-direct testing style (source the real
# library in a scratch subshell and call its exported function directly).
#
# A final guard case scans the extension's whole scripts/ tree (excluding tests/) for the
# "scope excursion" class literal in a --class position, asserting the library here is the
# ONLY non-test home -- the repo-wide single-emitter check required by the implementation plan.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (library, issue-record.sh, or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "scope-excursion-record-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/scope-excursion-record-lib.sh" \
  "$SCRIPT_DIR/../lib/scope-excursion-record-lib.sh")" || exit 2
common_test_declare_subject "$LIB"
ISSUE_RECORD_SCRIPT="$(common_test_resolve_subject "issue-record.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/issue-record.sh" \
  "$SCRIPT_DIR/../issue-record.sh")" || exit 2
common_test_declare_subject "$ISSUE_RECORD_SCRIPT"
GUARD_SCRIPT="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" \
  "$SCRIPT_DIR/../deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SCRIPT"
COMMON_SCRIPT="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/common.sh" \
  "$SCRIPT_DIR/../lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SCRIPT"
TASK_LOOKUP_SCRIPT="$(common_test_resolve_subject "lib/task-lookup-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/task-lookup-lib.sh" \
  "$SCRIPT_DIR/../lib/task-lookup-lib.sh")" || exit 2
common_test_declare_subject "$TASK_LOOKUP_SCRIPT"
CENTRAL_LOG_SCRIPT="$(common_test_resolve_subject "lib/central-log-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/central-log-lib.sh" \
  "$SCRIPT_DIR/../lib/central-log-lib.sh")" || exit 2
common_test_declare_subject "$CENTRAL_LOG_SCRIPT"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- isolated <scratch>/.claude/scripts/{...} + <scratch>/specs/ tree with one
#     active project (number 1, dir specs/001_demo_task/). Never touches the live repo's own
#     specs/. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs/001_demo_task"
  cp "$ISSUE_RECORD_SCRIPT" "$scratch/.claude/scripts/issue-record.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  cp "$CENTRAL_LOG_SCRIPT" "$scratch/.claude/scripts/lib/central-log-lib.sh"
  chmod +x "$scratch/.claude/scripts/issue-record.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "demo_task", "status": "implementing"}
  ]
}
EOF
  echo "$scratch"
}

ISSUES_REL="specs/001_demo_task/issues.jsonl"

common_test_info "Using library: $LIB"

# =====================================================================
# Case 1: a 3-path drop event writes exactly one issues.jsonl line.
# =====================================================================
scratch1="$(build_scratch)"
doc1="$scratch1/$ISSUES_REL"
(
  # shellcheck disable=SC1090
  . "$LIB"
  scope_excursion_record_emit "$scratch1/.claude/scripts" 1 \
    "test-case-1: dropped 3 paths" "2026-01-01T00:00:00Z" "2026-01-01T00:00:05Z" \
    --phase implement -- "a/one.txt" "b/two.txt" "c/three.txt"
)
line_count1="$(wc -l < "$doc1" 2>/dev/null || echo 0)"
if [ "$line_count1" -eq 1 ]; then
  common_test_pass "Case 1: a 3-path drop event writes exactly one issues.jsonl line"
else
  common_test_fail "Case 1: expected exactly 1 line, got ${line_count1}: $(cat "$doc1" 2>/dev/null)"
fi

# =====================================================================
# Case 2: tags.dropped_paths holds all three paths, in order.
# =====================================================================
dropped_json2="$(jq -r '.tags.dropped_paths | @json' "$doc1" 2>/dev/null)"
if [ "$dropped_json2" = '["a/one.txt","b/two.txt","c/three.txt"]' ]; then
  common_test_pass "Case 2: tags.dropped_paths holds all three paths, in drop order"
else
  common_test_fail "Case 2: expected [\"a/one.txt\",\"b/two.txt\",\"c/three.txt\"], got ${dropped_json2}"
fi

# =====================================================================
# Case 3: tags.occurrence.count equals 3, and first_seen/last_seen are the given timestamps.
# =====================================================================
occ3="$(jq -c '.tags.occurrence' "$doc1" 2>/dev/null)"
if [ "$occ3" = '{"count":3,"first_seen":"2026-01-01T00:00:00Z","last_seen":"2026-01-01T00:00:05Z"}' ]; then
  common_test_pass "Case 3: tags.occurrence carries count=3 and the measured first_seen/last_seen"
else
  common_test_fail "Case 3: expected count=3 with the measured timestamps, got ${occ3}"
fi

# =====================================================================
# Case 4: class/severity/kind are the expected literals.
# =====================================================================
class4="$(jq -r '.class' "$doc1" 2>/dev/null)"
severity4="$(jq -r '.severity' "$doc1" 2>/dev/null)"
kind4="$(jq -r '.kind' "$doc1" 2>/dev/null)"
if [ "$class4" = "scope excursion" ] && [ "$severity4" = "minor" ] && [ "$kind4" = "issue" ]; then
  common_test_pass "Case 4: class='scope excursion', severity='minor', kind='issue'"
else
  common_test_fail "Case 4: expected class/severity/kind literals, got class=${class4} severity=${severity4} kind=${kind4}"
fi

# =====================================================================
# Case 5: a 1-path call is well-formed too (not just the multi-path shape).
# =====================================================================
scratch5="$(build_scratch)"
doc5="$scratch5/$ISSUES_REL"
(
  # shellcheck disable=SC1090
  . "$LIB"
  scope_excursion_record_emit "$scratch5/.claude/scripts" 1 \
    "test-case-5: dropped 1 path" "2026-01-01T00:00:00Z" "2026-01-01T00:00:00Z" \
    -- "solo/path.txt"
)
line_count5="$(wc -l < "$doc5" 2>/dev/null || echo 0)"
dropped_json5="$(jq -r '.tags.dropped_paths | @json' "$doc5" 2>/dev/null)"
if [ "$line_count5" -eq 1 ] && [ "$dropped_json5" = '["solo/path.txt"]' ]; then
  common_test_pass "Case 5: a 1-path call is well-formed (one line, dropped_paths=['solo/path.txt'])"
else
  common_test_fail "Case 5: expected 1 line with dropped_paths=['solo/path.txt'], got lines=${line_count5} dropped_paths=${dropped_json5}"
fi

# =====================================================================
# Case 6: an absent issue-record.sh is a silent no-op returning 0.
# =====================================================================
scratch6="$(mktemp -d -p "$TOP_WORKDIR")"
mkdir -p "$scratch6/empty-scripts-dir"
rc6=0
out6="$(
  (
    # shellcheck disable=SC1090
    . "$LIB"
    scope_excursion_record_emit "$scratch6/empty-scripts-dir" 1 \
      "test-case-6: issue-record.sh absent" "2026-01-01T00:00:00Z" "2026-01-01T00:00:00Z" \
      -- "whatever.txt"
  )
  echo "RC=$?"
)" || true
rc6="$(echo "$out6" | grep -oE 'RC=[0-9]+' | cut -d= -f2)"
if [ "$rc6" = "0" ] && [ ! -e "$scratch6/empty-scripts-dir/specs" ]; then
  common_test_pass "Case 6: an absent issue-record.sh is a silent no-op returning 0"
else
  common_test_fail "Case 6: expected rc=0 and no side effect; got rc=${rc6} out=${out6}"
fi

# =====================================================================
# Case 7: the jq-absent fallback still names every dropped path (never fewer paths, only
# fewer/no --tags-json). Simulated by shadowing `command` inside the subshell so `command -v jq`
# reports not-found without actually uninstalling jq from the test host.
# =====================================================================
scratch7="$(build_scratch)"
doc7="$scratch7/$ISSUES_REL"
(
  # shellcheck disable=SC1090
  . "$LIB"
  command() {
    if [ "$1" = "-v" ] && [ "$2" = "jq" ]; then
      return 1
    fi
    builtin command "$@"
  }
  scope_excursion_record_emit "$scratch7/.claude/scripts" 1 \
    "test-case-7: jq-absent fallback" "2026-01-01T00:00:00Z" "2026-01-01T00:00:05Z" \
    -- "fallback/one.txt" "fallback/two.txt"
)
line_count7="$(wc -l < "$doc7" 2>/dev/null || echo 0)"
if [ "$line_count7" -eq 1 ] \
   && grep -q "fallback/one.txt" "$doc7" 2>/dev/null \
   && grep -q "fallback/two.txt" "$doc7" 2>/dev/null; then
  common_test_pass "Case 7: jq-absent fallback writes exactly one line naming every dropped path"
else
  common_test_fail "Case 7: expected 1 line naming both fallback paths, got lines=${line_count7}: $(cat "$doc7" 2>/dev/null)"
fi

# =====================================================================
# Case 8 (repo-wide single-emitter guard): scanning the extension's whole scripts/ tree
# (excluding tests/) for the "scope excursion" class literal in a --class position must find
# exactly this library's own occurrence -- a future per-path emitter is caught here at suite
# time, never silently reintroduced. Both Containment emitters (git-commit-phase.sh,
# git-commit-scoped.sh) were converted to call this library instead of recording per-path
# before this case was added.
# =====================================================================
EXT_SCRIPTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# grep -R over scripts/, excluding the tests/ directory, for a non-comment --class "scope
# excursion" occurrence. -n for line numbers (diagnostic only); filter out lines whose first
# non-whitespace character is '#' (a comment line) before counting.
guard_hits="$(grep -RnF --include='*.sh' -- '--class "scope excursion"' "$EXT_SCRIPTS_ROOT" \
  | grep -v '/tests/' \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
  || true)"
guard_hit_count="$(echo "$guard_hits" | grep -c . || true)"
guard_hit_files="$(echo "$guard_hits" | cut -d: -f1 | sort -u)"
if [ "$guard_hit_count" -eq 1 ] && echo "$guard_hit_files" | grep -qF "lib/scope-excursion-record-lib.sh"; then
  common_test_pass "Case 8: the only non-comment, non-test --class \"scope excursion\" occurrence is this library's own"
else
  common_test_fail "Case 8: expected exactly one occurrence, in lib/scope-excursion-record-lib.sh; got ${guard_hit_count} occurrence(s) in: ${guard_hit_files}"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
