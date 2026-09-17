#!/usr/bin/env bash
# test-postflight-deploy-gate.sh - Fixture-driven regression suite for the postflight
# completion-deploy gate: update-task-status.sh's "PHASE 0.5" block (exit 6) and its dependency
# scripts/lib/deploy-freshness-lib.sh.
#
# Structural model: test-update-task-status.sh (mktemp -d WORKDIR with an EXIT-trap cleanup, a
# real dependency chain copied into a private fixture repo, pass()/fail()/info() helpers with
# integer counters, exit 0 all-pass / 1 any-fail / 2 environment error).
#
# RESOLUTION ORDER INVERSION (deliberate, and different from every other suite in this
# directory): the TWO files this suite actually exercises --
# scripts/update-task-status.sh and scripts/lib/deploy-freshness-lib.sh -- are resolved
# SOURCE-STORE-FIRST (agent-system/extensions/core/scripts/...), falling back to the deployed
# copy (.claude/scripts/...) only if the source-store copy is absent. This is the opposite order
# from test-update-task-status.sh and test-deploy-freshness.sh, and is required here
# specifically: this suite is meant to be meaningful BEFORE a deploy has run (deploy-freshness-
# lib.sh does not exist in the deployed tree at all until Phase 8's deploy, and a deploy-tree-
# first resolution of update-task-status.sh would silently test the OLD, pre-Phase-3 script).
# Every OTHER dependency this fixture needs (state-write.sh, task-lock.sh, generate-todo.sh,
# deploy-root-guard.sh, update-plan-status.sh, lib/common.sh, lib/phase-heading-patterns.sh,
# lib/status-vocabulary.sh, lib/file-scope-overlap.sh) is UNCHANGED by this task and keeps the
# existing deploy-tree-first / source-store-fallback order every other suite already uses.
#
# ISOLATION CONTRACT: every case runs against a complete, isolated fixture repo built fresh
# under mktemp -d WORKDIR -- a real dependency chain copied in, plus a private specs/state.json,
# task directory, .return-meta.json, and .claude-extensions.json/source-repo pair standing in
# for the deploy-freshness comparison. The suite never touches the real specs/ tree, real
# state.json, or the real .claude-extensions.json.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- Source-store-first resolution for the two files under test ---
UTS_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/update-task-status.sh"
  "$DEPLOY_SCRIPTS_SRC/update-task-status.sh"
)
UTS_SRC=""
for c in "${UTS_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { UTS_SRC="$c"; break; }
done
if [[ -z "$UTS_SRC" ]]; then
  echo "ERROR: update-task-status.sh not found at any of: ${UTS_CANDIDATES[*]}" >&2
  exit 2
fi

FRESHNESS_LIB_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/lib/deploy-freshness-lib.sh"
  "$DEPLOY_SCRIPTS_SRC/lib/deploy-freshness-lib.sh"
)
FRESHNESS_LIB_SRC=""
for c in "${FRESHNESS_LIB_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { FRESHNESS_LIB_SRC="$c"; break; }
done
if [[ -z "$FRESHNESS_LIB_SRC" ]]; then
  echo "ERROR: deploy-freshness-lib.sh not found at any of: ${FRESHNESS_LIB_CANDIDATES[*]}" >&2
  exit 2
fi

# --- Deploy-tree-first resolution (unchanged dependencies) ---
if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: deployed scripts tree not found at $DEPLOY_SCRIPTS_SRC -- this suite needs a" >&2
  echo "       real deployed .claude/scripts/ tree to copy update-task-status.sh's unchanged" >&2
  echo "       dependency chain from." >&2
  exit 2
fi
REQUIRED_SCRIPTS=(state-write.sh task-lock.sh generate-todo.sh generate-task-order.sh
                   update-plan-status.sh update-phase-status.sh deploy-root-guard.sh)
for req in "${REQUIRED_SCRIPTS[@]}"; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required deployed script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done
REQUIRED_LIBS=(common.sh phase-heading-patterns.sh status-vocabulary.sh file-scope-overlap.sh task-lookup-lib.sh)
for req in "${REQUIRED_LIBS[@]}"; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/lib/$req" ]]; then
    echo "ERROR: required deployed library missing: $DEPLOY_SCRIPTS_SRC/lib/$req" >&2
    exit 2
  fi
done

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Under test (source-store-first): $UTS_SRC"
info "Under test (source-store-first): $FRESHNESS_LIB_SRC"

# ─── build_fixture_repo <root>: isolated repo shape -- SOURCE-STORE copies of the two files
# under test, DEPLOY-TREE copies of everything else ─────────────────────────────────────────
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  cp "$UTS_SRC" "$root/.claude/scripts/update-task-status.sh"
  chmod +x "$root/.claude/scripts/update-task-status.sh"
  cp "$FRESHNESS_LIB_SRC" "$root/.claude/scripts/lib/deploy-freshness-lib.sh"
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  for f in "${REQUIRED_LIBS[@]}"; do
    cp "$DEPLOY_SCRIPTS_SRC/lib/$f" "$root/.claude/scripts/lib/$f"
  done
  cat > "$root/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "implementing",
      "task_type": "meta",
      "next_artifact_number": 1
    }
  ]
}
EOF
  mkdir -p "$root/specs/001_fixture_task/plans"
  cat > "$root/specs/001_fixture_task/plans/01_fixture-plan.md" << 'PLANEOF'
# Implementation Plan: Fixture Task

- **Status**: [IMPLEMENTING]

## Implementation Phases

### Phase 1: Only phase [COMPLETED]
PLANEOF
}

# ─── build_source_and_extensions <root> <ext_head>: fabricated .claude-extensions.json plus a
# throwaway source-store stand-in repo with a committed "core" extension subdirectory. Returns
# (via globals) the source_dir and its HEAD after the initial commit. ────────────────────────
SRC_REPO=""
SRC_HEAD_V1=""
build_source_and_extensions() {
  local root="$1"
  SRC_REPO="$root/source-repo"
  mkdir -p "$SRC_REPO/agent-system/extensions/core/scripts"
  git init -q "$SRC_REPO"
  git -C "$SRC_REPO" config user.email "test@example.com"
  git -C "$SRC_REPO" config user.name "Test"
  echo "v1" > "$SRC_REPO/agent-system/extensions/core/scripts/foo.sh"
  git -C "$SRC_REPO" add agent-system/extensions/core/scripts/foo.sh
  git -C "$SRC_REPO" commit -q -m "initial"
  SRC_HEAD_V1="$(git -C "$SRC_REPO" log -1 --format=%H -- "$SRC_REPO/agent-system/extensions")"
  cat > "$root/.claude-extensions.json" << EOF
{"version":"1.0.0","extensions":{"core":{"version":"1.0.0","source_dir":"${SRC_REPO}/agent-system/extensions/core","source_git_head":"${SRC_HEAD_V1}"}}}
EOF
}

write_return_meta() {
  local root="$1" modified_files_json="$2"
  cat > "$root/specs/001_fixture_task/.return-meta.json" << EOF
{"status": "implemented", "modified_files": ${modified_files_json}}
EOF
}

UTS() { "$FIXTURE_ROOT/.claude/scripts/update-task-status.sh" "$@"; }
task_status() { jq -r '.active_projects[0].status' "$FIXTURE_ROOT/specs/state.json" 2>/dev/null; }

# =====================================================================
# Case 1: overlap + STALE -> exit 6, state.json unchanged, no plan-file stamp
# =====================================================================
info "=== Case 1: overlap + stale -> exit 6 ==="
FIXTURE_ROOT="$WORKDIR/case1"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["agent-system/extensions/core/scripts/foo.sh"]'
# Advance the source repo without updating the recorded head -> stale.
echo "v2" > "$SRC_REPO/agent-system/extensions/core/scripts/foo.sh"
git -C "$SRC_REPO" add agent-system/extensions/core/scripts/foo.sh
git -C "$SRC_REPO" commit -q -m "v2"

before_status="$(task_status)"
UTS postflight 1 implement sess_test_c1 >"$WORKDIR/c1.out" 2>"$WORKDIR/c1.err"
C1_EXIT=$?
after_status="$(task_status)"
if [[ "$C1_EXIT" -eq 6 ]]; then
  pass "overlap+stale exits 6"
else
  fail "overlap+stale expected exit 6, got $C1_EXIT (see $WORKDIR/c1.err)"
fi
if [[ "$before_status" == "$after_status" && "$after_status" == "implementing" ]]; then
  pass "overlap+stale leaves state.json status unchanged (implementing)"
else
  fail "overlap+stale changed status: before=$before_status after=$after_status"
fi
if grep -q "refusing postflight implement" "$WORKDIR/c1.err"; then
  pass "overlap+stale prints the refusal message"
else
  fail "overlap+stale did not print the expected refusal message (see $WORKDIR/c1.err)"
fi

# =====================================================================
# Case 2: overlap + FRESH -> exit 0, transition applied
# =====================================================================
info "=== Case 2: overlap + fresh -> exit 0, transition applied ==="
FIXTURE_ROOT="$WORKDIR/case2"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["agent-system/extensions/core/scripts/foo.sh"]'

UTS postflight 1 implement sess_test_c2 >"$WORKDIR/c2.out" 2>"$WORKDIR/c2.err"
C2_EXIT=$?
if [[ "$C2_EXIT" -eq 0 ]]; then
  pass "overlap+fresh exits 0"
else
  fail "overlap+fresh expected exit 0, got $C2_EXIT (see $WORKDIR/c2.err)"
fi
st="$(task_status)"
if [[ "$st" == "completed" ]]; then
  pass "overlap+fresh applies the transition (implementing -> completed)"
else
  fail "overlap+fresh expected status 'completed', got '$st'"
fi

# =====================================================================
# Case 3: no overlap -> exit 0
# =====================================================================
info "=== Case 3: no overlap -> exit 0 ==="
FIXTURE_ROOT="$WORKDIR/case3"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["specs/001_fixture_task/plans/01_plan.md"]'

UTS postflight 1 implement sess_test_c3 >"$WORKDIR/c3.out" 2>"$WORKDIR/c3.err"
C3_EXIT=$?
if [[ "$C3_EXIT" -eq 0 ]]; then
  pass "no overlap exits 0"
else
  fail "no overlap expected exit 0, got $C3_EXIT (see $WORKDIR/c3.err)"
fi
if grep -q "not applicable" "$WORKDIR/c3.err"; then
  pass "no overlap logs the not-applicable branch"
else
  fail "no overlap did not log the expected not-applicable note (see $WORKDIR/c3.err)"
fi

# =====================================================================
# Case 4: missing .return-meta.json -> exit 0 with the inconclusive note
# =====================================================================
info "=== Case 4: missing .return-meta.json -> inconclusive ==="
FIXTURE_ROOT="$WORKDIR/case4"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
# Deliberately do NOT write .return-meta.json.

UTS postflight 1 implement sess_test_c4 >"$WORKDIR/c4.out" 2>"$WORKDIR/c4.err"
C4_EXIT=$?
if [[ "$C4_EXIT" -eq 0 ]]; then
  pass "missing .return-meta.json exits 0"
else
  fail "missing .return-meta.json expected exit 0, got $C4_EXIT (see $WORKDIR/c4.err)"
fi
if grep -q "no .return-meta.json resolved -- inconclusive" "$WORKDIR/c4.err"; then
  pass "missing .return-meta.json logs the inconclusive note"
else
  fail "missing .return-meta.json did not log the expected note (see $WORKDIR/c4.err)"
fi

# =====================================================================
# Case 5: missing freshness library -> exit 0 with the loud D4 note
# =====================================================================
info "=== Case 5: missing freshness library -> inconclusive (D4) ==="
FIXTURE_ROOT="$WORKDIR/case5"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["agent-system/extensions/core/scripts/foo.sh"]'
rm -f "$FIXTURE_ROOT/.claude/scripts/lib/deploy-freshness-lib.sh"

UTS postflight 1 implement sess_test_c5 >"$WORKDIR/c5.out" 2>"$WORKDIR/c5.err"
C5_EXIT=$?
if [[ "$C5_EXIT" -eq 0 ]]; then
  pass "missing freshness library exits 0 (D4: never a hard exit)"
else
  fail "missing freshness library expected exit 0, got $C5_EXIT (see $WORKDIR/c5.err)"
fi
if grep -q "deploy-freshness-lib.sh not found -- inconclusive" "$WORKDIR/c5.err"; then
  pass "missing freshness library logs the loud D4 note"
else
  fail "missing freshness library did not log the expected note (see $WORKDIR/c5.err)"
fi
st="$(task_status)"
if [[ "$st" == "completed" ]]; then
  pass "missing freshness library still allows the transition to proceed (pass-through)"
else
  fail "missing freshness library expected status 'completed' (pass-through), got '$st'"
fi

# =====================================================================
# Case 6: --dry-run + stale -> exit 0 with the preview line, no write
# =====================================================================
info "=== Case 6: --dry-run + stale -> exit 0 with preview ==="
FIXTURE_ROOT="$WORKDIR/case6"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["agent-system/extensions/core/scripts/foo.sh"]'
echo "v2" > "$SRC_REPO/agent-system/extensions/core/scripts/foo.sh"
git -C "$SRC_REPO" add agent-system/extensions/core/scripts/foo.sh
git -C "$SRC_REPO" commit -q -m "v2"

before_status="$(task_status)"
UTS --dry-run postflight 1 implement sess_test_c6 >"$WORKDIR/c6.out" 2>"$WORKDIR/c6.err"
C6_EXIT=$?
after_status="$(task_status)"
if [[ "$C6_EXIT" -eq 0 ]]; then
  pass "--dry-run + stale exits 0"
else
  fail "--dry-run + stale expected exit 0, got $C6_EXIT (see $WORKDIR/c6.err)"
fi
if grep -q "\[dry-run\] Deploy-check would block this transition" "$WORKDIR/c6.out"; then
  pass "--dry-run + stale prints the preview line"
else
  fail "--dry-run + stale did not print the expected preview line (see $WORKDIR/c6.out)"
fi
if [[ "$before_status" == "$after_status" ]]; then
  pass "--dry-run + stale writes nothing to state.json"
else
  fail "--dry-run + stale unexpectedly changed status: before=$before_status after=$after_status"
fi

# =====================================================================
# Case 7: postflight ... research -> the gate does not fire at all
# =====================================================================
info "=== Case 7: postflight research -> gate does not fire ==="
FIXTURE_ROOT="$WORKDIR/case7"
build_fixture_repo "$FIXTURE_ROOT"
build_source_and_extensions "$FIXTURE_ROOT"
write_return_meta "$FIXTURE_ROOT" '["agent-system/extensions/core/scripts/foo.sh"]'
echo "v2" > "$SRC_REPO/agent-system/extensions/core/scripts/foo.sh"
git -C "$SRC_REPO" add agent-system/extensions/core/scripts/foo.sh
git -C "$SRC_REPO" commit -q -m "v2"

UTS postflight 1 research sess_test_c7 >"$WORKDIR/c7.out" 2>"$WORKDIR/c7.err"
C7_EXIT=$?
if [[ "$C7_EXIT" -eq 0 ]]; then
  pass "postflight research exits 0"
else
  fail "postflight research expected exit 0, got $C7_EXIT (see $WORKDIR/c7.err)"
fi
if grep -q "deploy-check" "$WORKDIR/c7.err" "$WORKDIR/c7.out" 2>/dev/null; then
  fail "postflight research unexpectedly mentions [deploy-check] -- the gate must not fire for non-implement targets (see $WORKDIR/c7.err)"
else
  pass "postflight research: the deploy-check gate does not fire at all"
fi

# =====================================================================
# Contract assertion: the backstop block in update-task-status.sh contains no literal
# reference to the deploy/regeneration script name or the deploy-verification script name --
# the mechanical enforcement of the check-only contract (research constraint 3), run as a test
# rather than relying on reviewer memory.
# =====================================================================
info "=== Contract: check-only (no deploy-headless/verify-deploy references) ==="
DH_COUNT="$(grep -c 'deploy-headless' "$UTS_SRC" || true)"
VD_COUNT="$(grep -c 'verify-deploy' "$UTS_SRC" || true)"
if [[ "${DH_COUNT:-0}" -eq 0 ]]; then
  pass "update-task-status.sh contains zero 'deploy-headless' references"
else
  fail "update-task-status.sh contains ${DH_COUNT} 'deploy-headless' reference(s) -- check-only contract violated"
fi
if [[ "${VD_COUNT:-0}" -eq 0 ]]; then
  pass "update-task-status.sh contains zero 'verify-deploy' references"
else
  fail "update-task-status.sh contains ${VD_COUNT} 'verify-deploy' reference(s) -- check-only contract violated"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
