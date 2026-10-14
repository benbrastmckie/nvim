#!/usr/bin/env bash
# test-gate-out-derived-staleness.sh - Fixture suite for command-gate-out.sh's single-task-engine
# parity with orchestrate-cycle-postflight.sh's blocking derived-artifact staleness probe (see
# that script's own WORK (f) pre-case probe call and scripts/lib/derived-artifact-probe-lib.sh's
# header for the shared mechanism both engines call).
#
# Fixture shape, modelled on test-gate-out-self-attribution.sh's own header rationale: a minimal
# fixture repo carrying only what this gate needs, NOT the full test-gate-out-repair-reporting.sh
# dependency chain. Real code under test: command-gate-out.sh, skill-base.sh (sourced), and
# scripts/lib/derived-artifact-probe-lib.sh (sourced -- this IS the new collaborator this suite
# exists to exercise, so it is never stubbed). deploy-baseline-lib.sh is sourced unconditionally
# at the top of command-gate-out.sh (even though unused by any case below, since none of these
# fixtures reach the rc==6 branch) -- the real copy is still provided so that source does not
# fail. update-task-status.sh and task-lock.sh are call-counting/no-op STUBS, same convention as
# test-gate-out-self-attribution.sh's write_utas_stub.
#
# No plans/reports/summaries artifacts are created in the fixture's own task directory, so
# skill_validate_task_artifacts's per-file loop never iterates and validate-artifact.sh does not
# need to be present (same precedent as test-gate-out-self-attribution.sh).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required source-store script was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE_SRC="$(resolve_candidate "skill-base.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh")" || exit 2
GATE_OUT_SRC="$(resolve_candidate "command-gate-out.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/command-gate-out.sh" \
  "$REPO_ROOT/.claude/scripts/command-gate-out.sh")" || exit 2
BASELINE_LIB_SRC="$(resolve_candidate "deploy-baseline-lib.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/deploy-baseline-lib.sh")" || exit 2
PROBE_LIB_SRC="$(resolve_candidate "derived-artifact-probe-lib.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/derived-artifact-probe-lib.sh")" || exit 2

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# write_utas_stub <root> <exit_code>: call-counting stub for update-task-status.sh. Marker file
# lives OUTSIDE $root/specs so a fixture's own specs/ tree stays a faithful minimal snapshot.
write_utas_stub() {
  local root="$1" rc="$2"
  local marker="$root/.utas_call_count"
  cat > "$root/.claude/scripts/update-task-status.sh" <<EOF
#!/usr/bin/env bash
marker="$marker"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
echo "[stub update-task-status.sh] call #\$count args: \$*" >&2
exit $rc
EOF
  chmod +x "$root/.claude/scripts/update-task-status.sh"
}

# build_fixture_repo <root> <expected_status> <current_status> <skill_status>: a minimal fixture
# repo carrying only what the derived-staleness gate needs. $root/.claude-extensions.json is
# written SEPARATELY per case (or omitted) by each case below -- derived_probe_run_all resolves
# it from $(pwd), i.e. $root at command-gate-out.sh's own invocation time.
build_fixture_repo() {
  local root="$1" skill_status="$2"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs/001_fixture_task"
  cp "$SKILL_BASE_SRC" "$root/.claude/scripts/skill-base.sh"
  cp "$GATE_OUT_SRC" "$root/.claude/scripts/command-gate-out.sh"
  cp "$BASELINE_LIB_SRC" "$root/.claude/scripts/lib/deploy-baseline-lib.sh"
  cp "$PROBE_LIB_SRC" "$root/.claude/scripts/lib/derived-artifact-probe-lib.sh"
  chmod +x "$root/.claude/scripts/skill-base.sh" "$root/.claude/scripts/command-gate-out.sh"
  cat > "$root/.claude/scripts/task-lock.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$root/.claude/scripts/task-lock.sh"
  cat > "$root/specs/state.json" <<'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "implementing",
      "task_type": "general",
      "next_artifact_number": 2
    }
  ]
}
EOF
  cat > "$root/specs/001_fixture_task/.return-meta.json" <<EOF
{"status": "${skill_status}", "modified_files": []}
EOF
}

write_extensions_decl() {
  local root="$1" check_cmd="$2"
  cat > "$root/.claude-extensions.json" <<EOF
{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compA","check_command":"${check_cmd}","derived_output_dirs":["components/compA/certs"]}]}
EOF
}

# =====================================================================
# Case 1: no .claude-extensions.json declaration at all -- transition proceeds exactly as today.
# =====================================================================
CASE1_ROOT="$WORKDIR/case1"
build_fixture_repo "$CASE1_ROOT" "implemented"
write_utas_stub "$CASE1_ROOT" 0
CASE1_OUT="$(cd "$CASE1_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case1 2>&1)"
CASE1_UTAS_CALLS="$(cat "$CASE1_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE1_UTAS_CALLS" = "1" ]; then
  pass "Case 1 (no declaration): update-task-status.sh is called exactly once -- transition proceeds unaffected"
else
  fail "Case 1 (no declaration): expected exactly 1 update-task-status.sh call, got $CASE1_UTAS_CALLS. Output:
$CASE1_OUT"
fi
if grep -qF "DERIVED-STALENESS" <<< "$CASE1_OUT"; then
  fail "Case 1 (no declaration): unexpected DERIVED-STALENESS line with no declaration present"
else
  pass "Case 1 (no declaration): no DERIVED-STALENESS line emitted"
fi

# =====================================================================
# Case 2: declaration present, probe passes -- transition proceeds.
# =====================================================================
CASE2_ROOT="$WORKDIR/case2"
build_fixture_repo "$CASE2_ROOT" "implemented"
write_extensions_decl "$CASE2_ROOT" "true"
write_utas_stub "$CASE2_ROOT" 0
CASE2_OUT="$(cd "$CASE2_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case2 2>&1)"
CASE2_UTAS_CALLS="$(cat "$CASE2_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE2_UTAS_CALLS" = "1" ]; then
  pass "Case 2 (declared, all probes pass): update-task-status.sh is called exactly once -- transition proceeds"
else
  fail "Case 2 (declared, all probes pass): expected exactly 1 update-task-status.sh call, got $CASE2_UTAS_CALLS. Output:
$CASE2_OUT"
fi
if grep -qF "DERIVED-STALENESS" <<< "$CASE2_OUT"; then
  fail "Case 2 (declared, all probes pass): unexpected DERIVED-STALENESS line"
else
  pass "Case 2 (declared, all probes pass): no DERIVED-STALENESS line emitted"
fi

# =====================================================================
# Case 3: declaration present, probe fails -- transition SKIPPED, status unchanged, named line
# emitted.
# =====================================================================
CASE3_ROOT="$WORKDIR/case3"
build_fixture_repo "$CASE3_ROOT" "implemented"
write_extensions_decl "$CASE3_ROOT" "false"
write_utas_stub "$CASE3_ROOT" 0
CASE3_OUT="$(cd "$CASE3_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case3 2>&1)"
CASE3_UTAS_CALLS="$(cat "$CASE3_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE3_UTAS_CALLS" = "0" ]; then
  pass "Case 3 (declared, one probe fails): update-task-status.sh is NEVER called -- transition skipped"
else
  fail "Case 3 (declared, one probe fails): expected 0 update-task-status.sh calls, got $CASE3_UTAS_CALLS. Output:
$CASE3_OUT"
fi
if grep -qF "DERIVED-STALENESS: task 1's declared derived-artifact probe(s) failed" <<< "$CASE3_OUT"; then  # task-ref-ok literal fixture stderr wording from command-gate-out.sh, fixture task number is 1
  pass "Case 3 (declared, one probe fails): named DERIVED-STALENESS skip line emitted"
else
  fail "Case 3 (declared, one probe fails): expected named DERIVED-STALENESS line. Output:
$CASE3_OUT"
fi
CASE3_STATUS="$(jq -r '.active_projects[0].status' "$CASE3_ROOT/specs/state.json")"
if [ "$CASE3_STATUS" = "implementing" ]; then
  pass "Case 3 (declared, one probe fails): state.json status left unchanged ('implementing')"
else
  fail "Case 3 (declared, one probe fails): expected status to remain 'implementing', got '$CASE3_STATUS'"
fi

# =====================================================================
# Case 4: a non-implement status_token (research) with a failing probe declared -- the probe is
# NOT run (phase-token gated), transition proceeds exactly as an ordinary research correction.
# =====================================================================
CASE4_ROOT="$WORKDIR/case4"
build_fixture_repo "$CASE4_ROOT" "researched"
write_extensions_decl "$CASE4_ROOT" "false"
write_utas_stub "$CASE4_ROOT" 0
# Research's expected_status is "researched"; current_status in state.json is "implementing"
# (from build_fixture_repo), which differs, so the defensive-correction branch still fires.
CASE4_OUT="$(cd "$CASE4_ROOT" && bash .claude/scripts/command-gate-out.sh 1 research sess_case4 2>&1)"
CASE4_UTAS_CALLS="$(cat "$CASE4_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE4_UTAS_CALLS" = "1" ]; then
  pass "Case 4 (non-implement token, failing probe declared): update-task-status.sh is called exactly once -- the probe is not run for this token"
else
  fail "Case 4 (non-implement token, failing probe declared): expected exactly 1 update-task-status.sh call, got $CASE4_UTAS_CALLS. Output:
$CASE4_OUT"
fi
if grep -qF "DERIVED-STALENESS" <<< "$CASE4_OUT"; then
  fail "Case 4 (non-implement token, failing probe declared): unexpected DERIVED-STALENESS line -- the probe must not run for a non-implement status_token"
else
  pass "Case 4 (non-implement token, failing probe declared): no DERIVED-STALENESS line -- probe correctly skipped for this token"
fi

# =====================================================================
# Contamination guard: no case ever touches the real specs/ tree.
# =====================================================================
AFTER_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [ "$BASELINE_SPECS_STATUS" = "$AFTER_SPECS_STATUS" ]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status CHANGED during this suite's run -- contamination (before: '$BASELINE_SPECS_STATUS' after: '$AFTER_SPECS_STATUS')"
fi

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
