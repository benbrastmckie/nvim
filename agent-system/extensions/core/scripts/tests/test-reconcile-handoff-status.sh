#!/usr/bin/env bash
# test-reconcile-handoff-status.sh - Fixture-driven regression suite for
# reconcile-task-status.sh's handoff_permits_promotion() three-way classification: exact match
# permits, an on-enum terminal mismatch refuses unchanged, and any value carrying no terminal
# claim (off-vocabulary, empty/absent .status, unparseable JSON, or in_progress) permits with a
# mandatory diagnostic -- treating the handoff exactly as if it were absent.
#
# Structural model: test-phase-heading-patterns.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, mktemp -d + trap cleanup EXIT, exit 0 all-pass / 1 any-fail / 2 environment
# error). Unlike that suite, this one cannot source the target script directly -- it is a
# `set -euo pipefail` executable with real side effects, not a sourceable function library -- so
# it drives it as a subprocess against a throwaway sandbox deploy tree.
#
# Sandbox rationale: reconcile-task-status.sh sources deploy-root-guard.sh, which hard-fails when
# invoked from a `scripts/` directory not parented by `.claude/` or `.opencode/` -- exactly the
# shape of the source-store checkout this test file itself lives in. Running the modified script
# in place would therefore abort every case with an environment error before any fixture logic
# runs. The sandbox builds a real `$SANDBOX/.claude/scripts/` tree (copied from whichever
# candidate below resolves first) plus a throwaway `$SANDBOX/specs/state.json`, and every case
# runs the sandboxed copy via `--dry-run`. The real repo's `.claude/` tree is never touched by
# this suite.
#
# Candidate order is SOURCE-STORE-FIRST, deploy-tree-fallback -- the inverse of the
# deploy-tree-first order used by test-phase-heading-patterns.sh for its shared library. That
# inverse order is correct there because phase-heading-patterns.sh is a stable, already-deployed
# library the test regression-guards over time. This suite instead exists specifically to
# regression-guard the SAME fix being landed to reconcile-task-status.sh in this change --
# `.claude/**` is a gitignored, disposable deploy artifact regenerated only on an explicit
# redeploy (see rules/source-store-deploy-boundary.md), so a deploy-tree-first order would
# silently validate a stale pre-fix mirror instead of the just-edited source-store file whenever
# the deployed copy has not yet been refreshed. Preferring the source store here is what makes
# the suite actually test the code this task changed.
#
# All eleven cases assert on the emitted TEXT (stdout "Would promote" vs stderr "refusing
# promotion" / the two distinct WARNING diagnostics), never on exit status -- reconcile-task-
# status.sh exits 0 on both the permit and refuse paths by design (a refusal is a handled no-op,
# not a script error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (no
# resolvable scripts/ tree, or the sandbox could not be constructed).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

# Source-store-first / deploy-tree-fallback -- see the header comment above for why this suite
# deliberately inverts the deploy-tree-first order used elsewhere in this codebase (e.g.
# check-task-references.sh, update-task-status.sh's PHASE_LIB_CANDIDATES).
SCRIPTS_SRC_CANDIDATES=(
  "$REPO_ROOT/agent-system/extensions/core/scripts"
  "$REPO_ROOT/.claude/scripts"
)
SCRIPTS_SRC=""
for candidate in "${SCRIPTS_SRC_CANDIDATES[@]}"; do
  if [[ -f "$candidate/reconcile-task-status.sh" ]]; then
    SCRIPTS_SRC="$candidate"
    break
  fi
done
if [[ -z "$SCRIPTS_SRC" ]]; then
  echo "ERROR: reconcile-task-status.sh not found at any of:" >&2
  for candidate in "${SCRIPTS_SRC_CANDIDATES[@]}"; do
    echo "  $candidate/reconcile-task-status.sh" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0


SANDBOX="$(mktemp -d)"
cleanup() { [ -n "${SANDBOX:-}" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"; }
trap cleanup EXIT

mkdir -p "$SANDBOX/.claude/scripts"
if ! cp -r "$SCRIPTS_SRC/." "$SANDBOX/.claude/scripts/"; then
  echo "ERROR: failed to populate sandbox scripts tree from $SCRIPTS_SRC" >&2
  exit 2
fi
RECONCILE="$SANDBOX/.claude/scripts/reconcile-task-status.sh"
if [[ ! -f "$RECONCILE" ]]; then
  echo "ERROR: sandbox reconcile-task-status.sh missing after copy" >&2
  exit 2
fi

TASK_NUMBER=1
SESSION_ID="test-session"
PROJECT_NAME="fixture_task"
PADDED="001"
TASK_DIR="$SANDBOX/specs/${PADDED}_${PROJECT_NAME}"

# --- Fixture builders -------------------------------------------------------------------------

# Rebuilds specs/ from scratch for each case so no state leaks between fixtures.
reset_specs() {
  rm -rf "$SANDBOX/specs"
  mkdir -p "$TASK_DIR"
}

write_state_json() {
  local status="$1"
  cat > "$SANDBOX/specs/state.json" <<EOF
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": $TASK_NUMBER,
      "project_name": "$PROJECT_NAME",
      "status": "$status",
      "task_type": "general",
      "last_updated": "2020-01-01T00:00:00Z"
    }
  ]
}
EOF
}

write_report_artifact() {
  mkdir -p "$TASK_DIR/reports"
  echo "# Fixture Report" > "$TASK_DIR/reports/01_report.md"
}

write_summary_artifact() {
  mkdir -p "$TASK_DIR/summaries"
  echo "# Fixture Summary" > "$TASK_DIR/summaries/01_summary.md"
}

# handoff_kind: NONE (no file), INVALID (unparseable JSON), NOKEY (valid JSON, no .status key),
# or any other string -> written verbatim as {"status": "<value>"}.
write_handoff() {
  local kind="$1"
  case "$kind" in
    NONE)
      rm -f "$TASK_DIR/.orchestrator-handoff.json"
      ;;
    INVALID)
      printf '{ this is not valid json' > "$TASK_DIR/.orchestrator-handoff.json"
      ;;
    NOKEY)
      echo '{}' > "$TASK_DIR/.orchestrator-handoff.json"
      ;;
    *)
      printf '{"status": "%s"}' "$kind" > "$TASK_DIR/.orchestrator-handoff.json"
      ;;
  esac
}

STDOUT_FILE="$SANDBOX/_stdout.txt"
STDERR_FILE="$SANDBOX/_stderr.txt"

run_reconcile() {
  (cd "$SANDBOX" && bash "$RECONCILE" "$TASK_NUMBER" "$SESSION_ID" --dry-run) \
    >"$STDOUT_FILE" 2>"$STDERR_FILE"
}

SIX_LEGAL_VALUES="researched|planned|implemented|partial|failed|blocked"

# =====================================================================
# Case 1: exact match -> permits.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "researched"
run_reconcile
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 1 (exact match): permits promotion"
else
  common_test_fail "case 1 (exact match): expected a promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 2: on-enum terminal mismatch (blocked) -> refuses, unchanged.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "blocked"
run_reconcile
if grep -qF "refusing promotion" "$STDOUT_FILE" && ! grep -qF "Would promote" "$STDOUT_FILE"; then
  common_test_pass "case 2 (on-enum mismatch: blocked): refuses promotion"
else
  common_test_fail "case 2 (on-enum mismatch: blocked): expected a refusal, no promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 3: another phase's success value (implemented, where researched is expected) -> refuses.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "implemented"
run_reconcile
if grep -qF "refusing promotion" "$STDOUT_FILE" && ! grep -qF "Would promote" "$STDOUT_FILE"; then
  common_test_pass "case 3 (cross-phase success value: implemented): refuses promotion"
else
  common_test_fail "case 3 (cross-phase success value: implemented): expected a refusal. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 4: off-vocabulary ("success") -> permits, stderr names the offending value and the six
# legal values.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "success"
run_reconcile
case4_stdout="$(cat "$STDOUT_FILE")"
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 4 (off-vocabulary: success): permits promotion"
else
  common_test_fail "case 4 (off-vocabulary: success): expected a promotion preview. stdout=$case4_stdout"
fi
if grep -qF "success" "$STDERR_FILE" && grep -qF "$SIX_LEGAL_VALUES" "$STDERR_FILE"; then
  common_test_pass "case 4 (off-vocabulary: success): stderr names the offending value and all six legal values"
else
  common_test_fail "case 4 (off-vocabulary: success): stderr missing offending value or legal set. stderr=$(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 5: off-vocabulary ("research_complete", the second live-incident value) -> permits.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "research_complete"
run_reconcile
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 5 (off-vocabulary: research_complete): permits promotion"
else
  common_test_fail "case 5 (off-vocabulary: research_complete): expected a promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 6: in_progress -> permits, and the stderr diagnostic does NOT use off-schema/malformed
# framing (distinct wording from the off-vocabulary case).
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "in_progress"
run_reconcile
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 6 (in_progress): permits promotion"
else
  common_test_fail "case 6 (in_progress): expected a promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi
if grep -qF "in_progress" "$STDERR_FILE" \
  && grep -qF "recognized non-terminal marker" "$STDERR_FILE" \
  && ! grep -qiF "off-schema" "$STDERR_FILE" \
  && ! grep -qiF "malformed" "$STDERR_FILE"; then
  common_test_pass "case 6 (in_progress): diagnostic is distinct -- no off-schema/malformed framing"
else
  common_test_fail "case 6 (in_progress): diagnostic wording incorrect. stderr=$(cat "$STDERR_FILE")"
fi

# =====================================================================
# Case 7: handoff present with no .status key -> permits.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "NOKEY"
run_reconcile
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 7 (no .status key): permits promotion"
else
  common_test_fail "case 7 (no .status key): expected a promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 8: handoff present but unparseable JSON -> permits, no crash.
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "INVALID"
run_reconcile
case8_rc=$?
if [[ "$case8_rc" -eq 0 ]] && grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 8 (unparseable JSON): permits promotion, no crash"
else
  common_test_fail "case 8 (unparseable JSON): expected exit 0 + promotion preview, got rc=$case8_rc stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 9: parity assertion. The same fixture directory with .orchestrator-handoff.json deleted
# must permit, and case 4's off-vocabulary outcome must equal it (same promotion-preview line).
# =====================================================================
reset_specs
write_state_json "researching"
write_report_artifact
write_handoff "NONE"
run_reconcile
deleted_handoff_stdout="$(cat "$STDOUT_FILE")"
if grep -qF "Would promote: researching -> researched" "$STDOUT_FILE"; then
  common_test_pass "case 9 (handoff deleted): permits promotion"
else
  common_test_fail "case 9 (handoff deleted): expected a promotion preview. stdout=$deleted_handoff_stdout"
fi

case4_promote_line="$(grep -F "Would promote:" <<< "$case4_stdout")"
deleted_promote_line="$(grep -F "Would promote:" <<< "$deleted_handoff_stdout")"
if [[ -n "$case4_promote_line" && "$case4_promote_line" == "$deleted_promote_line" ]]; then
  common_test_pass "case 9 (parity bar): off-vocabulary (case 4) promotion line matches handoff-deleted promotion line exactly"
else
  common_test_fail "case 9 (parity bar): promotion lines diverge. case4='$case4_promote_line' deleted='$deleted_promote_line'"
fi

# =====================================================================
# Case 10: the partial branch with an off-vocabulary status -> permits (exercises the Phase 2
# consolidation onto the shared helper).
# =====================================================================
reset_specs
write_state_json "partial"
write_summary_artifact
write_handoff "success"
run_reconcile
if grep -qF "Would promote: partial -> completed" "$STDOUT_FILE"; then
  common_test_pass "case 10 (partial branch, off-vocabulary): permits promotion"
else
  common_test_fail "case 10 (partial branch, off-vocabulary): expected a promotion preview. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Case 11: the partial branch with an on-enum mismatch (blocked) -> refuses AND emits the
# refusal line (regression guard for the previously dry-run-only-silent no-op).
# =====================================================================
reset_specs
write_state_json "partial"
write_summary_artifact
write_handoff "blocked"
run_reconcile
if grep -qF "refusing promotion" "$STDOUT_FILE" && ! grep -qF "Would promote" "$STDOUT_FILE"; then
  common_test_pass "case 11 (partial branch, on-enum mismatch: blocked): refuses AND emits the refusal line"
else
  common_test_fail "case 11 (partial branch, on-enum mismatch: blocked): expected a refusal line. stdout=$(cat "$STDOUT_FILE")"
fi

# =====================================================================
# Deliberate-break check (documented here, not run automatically): reverting
# handoff_permits_promotion() to the old bare `[[ "$handoff_status" == "$expected_status" ]]`
# fallthrough in a scratch copy of reconcile-task-status.sh must make cases 4-9 fail (the old
# code refuses every off-vocabulary/in_progress/empty/unparseable value instead of permitting).
# Verified manually during implementation; not re-run on every invocation since it requires
# mutating the sandboxed script in place. See the implementation summary for the actual output
# captured during that manual verification.
# =====================================================================

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
