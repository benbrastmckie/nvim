#!/usr/bin/env bash
# test-backfill-file-scope.sh - Fixture-driven regression suite for
# scripts/backfill-file-scope.sh: the one-shot, idempotent, dry-run-capable backfill of
# `file_scope` for existing plan-bearing tasks.
#
# Drives the DEPLOYED backfill-file-scope.sh as a real subprocess, never the source-store
# sibling: backfill-file-scope.sh itself has no REPO_ROOT/deploy-root-guard dependency (it derives
# its own repo root from --state-file, not from its own location), but its sibling dependency
# state-write.sh DOES guard against running from the source store (deploy-root-guard.sh), and
# backfill-file-scope.sh calls state-write.sh via a same-directory relative path -- so the whole
# chain only resolves correctly when invoked from a real deployed .claude/scripts/ tree. Fixture
# isolation therefore needs only a throwaway specs/state.json + plan directories (no script
# copying at all): the DEPLOYED backfill-file-scope.sh + state-write.sh + plan-file-scope-harvest.sh
# are used as-is, pointed at the fixture purely via --state-file. Same technique
# test-double-loading-check.sh uses for its own deployed-script-only dependency.
#
# Cases (matching this task's Phase 5 acceptance criteria):
#   1. Dry-run writes nothing (state.json byte-for-byte unchanged).
#   2. A real run populates a plan-bearing task's file_scope from its plan's Files to modify union.
#   3. A second run is a byte-for-byte no-op (idempotence).
#   4. A task with an existing non-empty file_scope is left untouched (never-overwrite guard).
#   5. A plan-less task is left absent (file_scope stays null, never []) and counted in the summary.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via the
# git worktree root first (depth-independent); only fall back to the fixed-depth guess (matching
# the source-store depth) when SCRIPT_DIR is not inside a git work tree. DEPLOYED_SCRIPT always
# targets `.claude/scripts/...` off the resolved REPO_ROOT -- the object under test is always the
# .claude deploy tree, never .opencode.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOYED_BACKFILL="$REPO_ROOT/.claude/scripts/backfill-file-scope.sh"
if [[ ! -f "$DEPLOYED_BACKFILL" ]]; then
  echo "ERROR: deployed backfill-file-scope.sh not found at $DEPLOYED_BACKFILL -- this suite" >&2
  echo "       needs a real deployed .claude/scripts/ tree (state-write.sh's deploy-root-guard.sh" >&2
  echo "       blocks the source-store sibling from running directly). Run deploy-headless.sh first." >&2
  exit 2
fi
for req in state-write.sh plan-file-scope-harvest.sh task-lock.sh; do
  if [[ ! -f "$REPO_ROOT/.claude/scripts/$req" ]]; then
    echo "ERROR: required deployed script missing: $REPO_ROOT/.claude/scripts/$req" >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Driving deployed backfill-file-scope.sh at: $DEPLOYED_BACKFILL"

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# --- build_fixture <root>: a throwaway specs/state.json plus two plan-bearing fixture entries
# and one plan-less fixture entry, keyed by fixture project_number (1, 2, 3 -- arbitrary fixture
# labels, not references to any real task in this or any other repo's specs/state.json). No
# script copying: the deployed dependency chain resolves this fixture purely via --state-file. --
build_fixture() {
  local root="$1"
  mkdir -p "$root/specs/001_covered_fixture/plans" \
           "$root/specs/002_alreadyset_fixture/plans" \
           "$root/specs/003_planless_fixture"
  cat > "$root/specs/state.json" << 'EOF'
{
  "next_project_number": 4,
  "active_projects": [
    {"project_number": 1, "project_name": "covered_fixture", "status": "planned", "task_type": "general", "next_artifact_number": 2, "file_scope": null},
    {"project_number": 2, "project_name": "alreadyset_fixture", "status": "planned", "task_type": "general", "next_artifact_number": 2, "file_scope": ["existing/hand-declared.sh"]},
    {"project_number": 3, "project_name": "planless_fixture", "status": "not_started", "task_type": "general", "next_artifact_number": 1, "file_scope": null}
  ]
}
EOF
  cat > "$root/specs/001_covered_fixture/plans/01_fixture-plan.md" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/backfill-one.sh`
- `scripts/backfill-two.sh`

**Verification**:
- ok
EOF
  # fixture entry 2 also has a plan on disk, but its file_scope is already non-empty above --
  # this exercises the never-overwrite guard: the plan exists and IS harvestable, yet must be
  # skipped.
  cat > "$root/specs/002_alreadyset_fixture/plans/01_fixture-plan.md" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/should-never-be-added.sh`

**Verification**:
- ok
EOF
  # fixture entry 3 deliberately has NO plans/ directory at all -- the plan-less case.
}

file_scope_of() {
  local root="$1" num="$2"
  jq -c --argjson n "$num" '.active_projects[] | select(.project_number == $n) | .file_scope' "$root/specs/state.json"
}

# -- Case 1: dry-run writes nothing ------------------------------------------------------------
CASE1_ROOT="$WORKDIR/case1"
build_fixture "$CASE1_ROOT"
BEFORE_1="$(cat "$CASE1_ROOT/specs/state.json")"
OUT_1="$(bash "$DEPLOYED_BACKFILL" --dry-run --state-file "$CASE1_ROOT/specs/state.json" 2>&1)"
EXIT_1=$?
AFTER_1="$(cat "$CASE1_ROOT/specs/state.json")"
if [[ "$EXIT_1" -eq 0 ]]; then
  pass "Case 1 (dry-run): exit code 0"
else
  fail "Case 1 (dry-run): expected exit 0, got $EXIT_1 (see output below)
$OUT_1"
fi
if [[ "$BEFORE_1" == "$AFTER_1" ]]; then
  pass "Case 1 (dry-run): state.json byte-for-byte unchanged"
else
  fail "Case 1 (dry-run): state.json was modified despite --dry-run"
fi
if echo "$OUT_1" | grep -qF "scripts/backfill-one.sh"; then
  pass "Case 1 (dry-run): proposed diff names the harvested path"
else
  fail "Case 1 (dry-run): expected proposed diff to name scripts/backfill-one.sh, got:
$OUT_1"
fi

# -- Case 2: a real run populates a plan-bearing fixture entry's file_scope -------------------
CASE2_ROOT="$WORKDIR/case2"
build_fixture "$CASE2_ROOT"
OUT_2="$(bash "$DEPLOYED_BACKFILL" --state-file "$CASE2_ROOT/specs/state.json" 2>&1)"
EXIT_2=$?
FS_ENTRY1="$(file_scope_of "$CASE2_ROOT" 1)"
if [[ "$EXIT_2" -eq 0 ]]; then
  pass "Case 2 (real run): exit code 0"
else
  fail "Case 2 (real run): expected exit 0, got $EXIT_2 (see output below)
$OUT_2"
fi
if [[ "$(echo "$FS_ENTRY1" | jq -c 'sort')" == '["scripts/backfill-one.sh","scripts/backfill-two.sh"]' ]]; then
  pass "Case 2 (real run): fixture entry 1's file_scope populated from its plan's Files to modify union"
else
  fail "Case 2 (real run): expected fixture entry 1 file_scope [\"scripts/backfill-one.sh\",\"scripts/backfill-two.sh\"], got '$FS_ENTRY1'"
fi

# -- Case 3: a second run is a byte-for-byte no-op (idempotence) ------------------------------
BEFORE_3="$(cat "$CASE2_ROOT/specs/state.json")"
OUT_3="$(bash "$DEPLOYED_BACKFILL" --state-file "$CASE2_ROOT/specs/state.json" 2>&1)"
EXIT_3=$?
AFTER_3="$(cat "$CASE2_ROOT/specs/state.json")"
if [[ "$EXIT_3" -eq 0 ]]; then
  pass "Case 3 (idempotence): second run exits 0"
else
  fail "Case 3 (idempotence): expected exit 0, got $EXIT_3 (see output below)
$OUT_3"
fi
if [[ "$BEFORE_3" == "$AFTER_3" ]]; then
  pass "Case 3 (idempotence): second run over an already-backfilled state.json is a byte-for-byte no-op"
else
  fail "Case 3 (idempotence): second run changed state.json unexpectedly"
fi

# -- Case 4: a fixture entry with an existing non-empty file_scope is left untouched ----------
FS_ENTRY2="$(file_scope_of "$CASE2_ROOT" 2)"
if [[ "$(echo "$FS_ENTRY2" | jq -c .)" == '["existing/hand-declared.sh"]' ]]; then
  pass "Case 4 (never-overwrite): fixture entry 2's pre-existing file_scope is untouched, despite having a harvestable plan"
else
  fail "Case 4 (never-overwrite): expected fixture entry 2 file_scope [\"existing/hand-declared.sh\"] unchanged, got '$FS_ENTRY2'"
fi
if echo "$OUT_2" | grep -qF "scripts/should-never-be-added.sh"; then
  fail "Case 4 (never-overwrite): fixture entry 2's harvestable-but-skipped path leaked into the real-run output as an addition"
else
  pass "Case 4 (never-overwrite): fixture entry 2's plan content never appears as an added path in the real-run output"
fi

# -- Case 5: a plan-less fixture entry is left absent (null, never []) and counted ------------
FS_ENTRY3="$(file_scope_of "$CASE2_ROOT" 3)"
if [[ "$FS_ENTRY3" == "null" ]]; then
  pass "Case 5 (plan-less): fixture entry 3's file_scope stays absent (null), never a bogus []"
else
  fail "Case 5 (plan-less): expected fixture entry 3 file_scope null, got '$FS_ENTRY3'"
fi
if echo "$OUT_2" | grep -qE "Plan-less tasks \(left absent\):\s*1"; then
  pass "Case 5 (plan-less): closing summary reports exactly 1 plan-less entry"
else
  fail "Case 5 (plan-less): expected closing summary to report 1 plan-less entry, got:
$OUT_2"
fi

# -- Case 6: usage errors ----------------------------------------------------------------------
bash "$DEPLOYED_BACKFILL" --state-file "$WORKDIR/does-not-exist/state.json" >/dev/null 2>&1
EXIT_6="$?"
if [[ "$EXIT_6" -ne 0 ]]; then
  pass "Case 6 (usage error): a nonexistent --state-file target exits non-zero"
else
  fail "Case 6 (usage error): expected non-zero exit for a nonexistent state file, got 0"
fi

# =====================================================================
# Real-tree contamination guard (delta check against the pre-suite baseline; see
# test-update-task-status.sh's identical guard for why this is a delta, not an absolute
# emptiness check).
# =====================================================================
AFTER_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [[ "$BASELINE_SPECS_STATUS" == "$AFTER_SPECS_STATUS" ]]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status changed during this suite's run (see git status --short specs/)"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
