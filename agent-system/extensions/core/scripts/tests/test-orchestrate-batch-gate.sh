#!/usr/bin/env bash
# test-orchestrate-batch-gate.sh - Fixture-driven coverage for orchestrate-batch-gate.sh, the
# once-per-invocation shared verify-deploy.sh gate stage for a multi-task /orchestrate batch
# (Mechanism B of the batch-shared verify-deploy-gate design). See that script's own header for
# the full contract this suite exercises.
#
# Coverage: no-implement no-op (no `batch_gate` key written); a finding attributed to exactly one
# of two candidate tasks; a finding attributable to neither candidate landing in the unattributed
# set; an identifier-free finding never cleared; a non-reproducing (flaky) candidate finding
# dropped by the confirmation re-run; the `batch_gate` record shape; and the usage-error/
# degenerate paths the sibling suites already pin (no args, missing --state-file).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the SUT
# was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT_SRC="$CORE_DIR/orchestrate-batch-gate.sh"
GVEL_LIB="$CORE_DIR/lib/gate-verdict-extract-lib.sh"

if [[ ! -f "$SUT_SRC" ]]; then
  echo "ERROR: expected $SUT_SRC" >&2
  exit 2
fi
if [[ ! -f "$GVEL_LIB" ]]; then
  echo "ERROR: expected $GVEL_LIB" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$GVEL_LIB"

PASSED=0
FAILED=0

common_test_workdir_init

# ─── Sandbox: a deployed-shaped scripts/ tree ($WORKDIR/.claude/scripts/) so deploy-root-guard.sh
# (sourced by the SUT) does not refuse the invocation -- mirrors test-orchestrate-cycle-plan.sh's
# own fixture convention for this exact guard. ───────────────────────────────────────────────────
setup_sandbox() {
  rm -rf "$WORKDIR/sandbox"
  mkdir -p "$WORKDIR/sandbox/.claude/scripts/lib" "$WORKDIR/sandbox/specs/.orchestration"
  cp "$SUT_SRC" "$WORKDIR/sandbox/.claude/scripts/orchestrate-batch-gate.sh"
  cp "$CORE_DIR/deploy-root-guard.sh" "$WORKDIR/sandbox/.claude/scripts/deploy-root-guard.sh"
  cp "$CORE_DIR/lib/common.sh" "$WORKDIR/sandbox/.claude/scripts/lib/common.sh"
  cp "$CORE_DIR/lib/deploy-baseline-lib.sh" "$WORKDIR/sandbox/.claude/scripts/lib/deploy-baseline-lib.sh"
  chmod +x "$WORKDIR/sandbox/.claude/scripts/orchestrate-batch-gate.sh"
  SUT="$WORKDIR/sandbox/.claude/scripts/orchestrate-batch-gate.sh"
  VERIFY_STUB="$WORKDIR/sandbox/.claude/scripts/verify-deploy.sh"
  STATE_FILE="$WORKDIR/sandbox/specs/.orchestration/.orchestrator-multi-state-sess_test.json"
}

# write_fake_verify_two_call <rc> <call1_line_or_empty> <call2_line_or_empty>
# Call-counting stub (modelled on test-orchestrate-cycle-plan.sh's Group 11
# write_g11_verify_stub): 1st invocation prints <call1> (the "first"/candidate snapshot), 2nd+
# invocation prints <call2> (the "confirm" snapshot). Either argument may itself be a
# multi-line (embedded-newline) string to emit more than one FINDING line per call.
write_fake_verify_two_call() {
  local rc="$1" l1="$2" l2="$3"
  local marker="${VERIFY_STUB}.callcount"
  rm -f "$marker"
  cat > "$VERIFY_STUB" <<EOF
#!/usr/bin/env bash
marker="$marker"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
if [ "\$count" -eq 1 ]; then
cat <<'L1EOF'
$l1
L1EOF
fi
if [ "\$count" -ge 2 ]; then
cat <<'L2EOF'
$l2
L2EOF
fi
exit $rc
EOF
  chmod +x "$VERIFY_STUB"
}

run_sut() {
  # Usage: run_sut [extra args...]
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$SUT" "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

write_state() {
  # Usage: write_state <<'EOF' ... EOF
  cat > "$STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 1: usage errors -- no arguments, and missing --state-file target.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 1: usage-error/degenerate paths"
setup_sandbox
run_sut
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -qi "usage"; then
  common_test_pass "Case 1: no arguments exits 2 with a usage message"
else
  common_test_fail "Case 1: expected exit 2 + usage message with no arguments, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

run_sut --session sess_test --state-file "$WORKDIR/sandbox/specs/.orchestration/does-not-exist.json"
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -qi "not found"; then
  common_test_pass "Case 1: a missing --state-file target exits 2 with a clear error"
else
  common_test_fail "Case 1: expected exit 2 for a missing --state-file target, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 2: no-implement no-op -- a fixture state file with no implement-phase dispatch (empty
# .implement_agents) yields exit 0 and no `batch_gate` key written, and never even invokes the
# (absent, in this case) verify-deploy.sh.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 2: no-implement no-op"
setup_sandbox
write_state <<'EOF'
{"task_numbers": [901, 902], "implement_agents": {}, "invocation_modified_files": {}}
EOF
run_sut --session sess_test --state-file "$STATE_FILE"
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 2: no-implement fixture exits 0"
else
  common_test_fail "Case 2: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if jq -e 'has("batch_gate") | not' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 2: no batch_gate key written on the no-implement no-op path"
else
  common_test_fail "Case 2: unexpected batch_gate key written: $(cat "$STATE_FILE")"
fi
if echo "$LAST_STDERR" | grep -qi "no-op"; then
  common_test_pass "Case 2: a no-op explanatory line is printed"
else
  common_test_fail "Case 2: expected a no-op explanatory line on stderr, got: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 3: a finding attributed to exactly one of two candidate tasks.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 3: a finding attributed to exactly one of two candidate tasks"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [903, 904],
  "implement_agents": {"903": "general-implementation-agent"},
  "invocation_modified_files": {
    "903": ["agent-system/extensions/core/scripts/foo.sh"],
    "904": ["agent-system/extensions/core/scripts/bar.sh"]
  }
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate8 test-foo.sh failure referencing agent-system/extensions/core/scripts/foo.sh" \
  "FINDING gate8 test-foo.sh failure referencing agent-system/extensions/core/scripts/foo.sh"
run_sut --session sess_test --state-file "$STATE_FILE"
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 3: exits 0"
else
  common_test_fail "Case 3: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if jq -e '.batch_gate.attributed["903"] | length == 1' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 3: the finding is attributed to candidate #903 (whose modified_files names foo.sh)"
else
  common_test_fail "Case 3: expected exactly one finding attributed to candidate #903: $(cat "$STATE_FILE")"
fi
if jq -e '(.batch_gate.attributed["904"] // []) | length == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 3: the finding is NOT also attributed to candidate #904"
else
  common_test_fail "Case 3: expected no finding attributed to candidate #904: $(cat "$STATE_FILE")"
fi
if jq -e '.batch_gate.unattributed | length == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 3: the finding is not also recorded as unattributed (it was claimed by candidate #903)"
else
  common_test_fail "Case 3: expected an empty unattributed set: $(cat "$STATE_FILE")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 4: a finding attributable to NEITHER candidate lands in the unattributed set, never
# dropped and never pinned on one arbitrary candidate.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 4: a finding attributable to neither candidate lands in the unattributed set"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [905, 906],
  "implement_agents": {"905": "general-implementation-agent"},
  "invocation_modified_files": {
    "905": ["agent-system/extensions/core/scripts/alpha.sh"],
    "906": ["agent-system/extensions/core/scripts/beta.sh"]
  }
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate8 test-gamma.sh failure referencing agent-system/extensions/core/scripts/gamma.sh" \
  "FINDING gate8 test-gamma.sh failure referencing agent-system/extensions/core/scripts/gamma.sh"
run_sut --session sess_test --state-file "$STATE_FILE"
if jq -e '.batch_gate.unattributed | length == 1' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 4: the finding lands in the batch-level unattributed set"
else
  common_test_fail "Case 4: expected exactly one unattributed finding: $(cat "$STATE_FILE")"
fi
if jq -e '(.batch_gate.attributed | to_entries | map(.value) | flatten | length) == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 4: the finding is not pinned on either candidate"
else
  common_test_fail "Case 4: expected no per-candidate attribution: $(cat "$STATE_FILE")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 5: an identifier-free finding is never cleared -- it stays in the unattributed (blocking)
# set even though no candidate's modified_files could possibly match it.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 5: an identifier-free finding is never cleared"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [907],
  "implement_agents": {"907": "general-implementation-agent"},
  "invocation_modified_files": {"907": ["agent-system/extensions/core/scripts/delta.sh"]}
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate14 some advisory prose with no file identifier at all" \
  "FINDING gate14 some advisory prose with no file identifier at all"
run_sut --session sess_test --state-file "$STATE_FILE"
if jq -e '.batch_gate.unattributed | length == 1' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 5: the identifier-free finding lands in the unattributed set (never cleared)"
else
  common_test_fail "Case 5: expected the identifier-free finding to remain unattributed: $(cat "$STATE_FILE")"
fi
if jq -e '(.batch_gate.attributed["907"] // []) | length == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 5: the identifier-free finding is not attributed to candidate #907 either"
else
  common_test_fail "Case 5: expected no attribution for the identifier-free finding: $(cat "$STATE_FILE")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 6: a non-reproducing (flaky) candidate finding is dropped by the confirmation re-run --
# present on the first capture, absent on the second -- and never appears in confirmed_findings,
# the attributed map, or the unattributed set.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 6: a non-reproducing candidate finding is dropped by confirmation"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [908],
  "implement_agents": {"908": "general-implementation-agent"},
  "invocation_modified_files": {"908": ["agent-system/extensions/core/scripts/epsilon.sh"]}
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate8 test-epsilon.sh failure referencing agent-system/extensions/core/scripts/epsilon.sh" \
  ""
run_sut --session sess_test --state-file "$STATE_FILE"
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 6: exits 0"
else
  common_test_fail "Case 6: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if jq -e '.batch_gate.confirmed_findings | length == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 6: the flaky candidate is absent from confirmed_findings"
else
  common_test_fail "Case 6: expected an empty confirmed_findings set: $(cat "$STATE_FILE")"
fi
if jq -e '.batch_gate.unattributed | length == 0' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 6: the flaky candidate does not land in the unattributed set either"
else
  common_test_fail "Case 6: expected an empty unattributed set: $(cat "$STATE_FILE")"
fi
if echo "$LAST_STDERR" | grep -qi "flaky"; then
  common_test_pass "Case 6: a flaky-drop notice is printed"
else
  common_test_fail "Case 6: expected a flaky-drop notice on stderr, got: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 7: batch_gate record shape -- every required field present with the right JSON type.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 7: batch_gate record shape"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [909],
  "implement_agents": {"909": "general-implementation-agent"},
  "invocation_modified_files": {"909": ["agent-system/extensions/core/scripts/zeta.sh"]}
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate8 test-zeta.sh failure referencing agent-system/extensions/core/scripts/zeta.sh" \
  "FINDING gate8 test-zeta.sh failure referencing agent-system/extensions/core/scripts/zeta.sh"
run_sut --session sess_test --state-file "$STATE_FILE"
if jq -e '
    (.batch_gate.ran_at | type) == "string" and
    (.batch_gate.gate_exit_code | type) == "number" and
    (.batch_gate.confirmed_findings | type) == "array" and
    (.batch_gate.attributed | type) == "object" and
    (.batch_gate.unattributed | type) == "array"
  ' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 7: batch_gate record carries ran_at, gate_exit_code, confirmed_findings, attributed, unattributed with the expected JSON types"
else
  common_test_fail "Case 7: batch_gate record shape mismatch: $(cat "$STATE_FILE")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 8: a clean shared run (0 findings, 2nd call never even needed) records gate_exit_code 0
# and empty confirmed_findings/attributed/unattributed.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 8: a clean shared run records gate_exit_code 0 with empty findings sets"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [910],
  "implement_agents": {"910": "general-implementation-agent"},
  "invocation_modified_files": {"910": ["agent-system/extensions/core/scripts/eta.sh"]}
}
EOF
write_fake_verify_two_call 0 "" ""
run_sut --session sess_test --state-file "$STATE_FILE"
if jq -e '.batch_gate.gate_exit_code == 0 and (.batch_gate.confirmed_findings | length == 0) and (.batch_gate.unattributed | length == 0)' "$STATE_FILE" >/dev/null 2>&1; then
  common_test_pass "Case 8: clean run recorded with gate_exit_code 0 and empty findings sets"
else
  common_test_fail "Case 8: expected a clean batch_gate record: $(cat "$STATE_FILE")"
fi
_call_count="$(cat "${VERIFY_STUB}.callcount" 2>/dev/null || echo 0)"
if [ "$_call_count" -eq 1 ]; then
  common_test_pass "Case 8: verify-deploy.sh was called exactly once (no confirmation call needed on a clean first capture)"
else
  common_test_fail "Case 8: expected exactly one verify-deploy.sh call on a clean first capture, got $_call_count"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 9: --dry-run computes and prints the same summary but writes nothing to --state-file.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 9: --dry-run writes nothing to --state-file"
setup_sandbox
write_state <<'EOF'
{
  "task_numbers": [911],
  "implement_agents": {"911": "general-implementation-agent"},
  "invocation_modified_files": {"911": ["agent-system/extensions/core/scripts/theta.sh"]}
}
EOF
write_fake_verify_two_call 1 \
  "FINDING gate8 test-theta.sh failure referencing agent-system/extensions/core/scripts/theta.sh" \
  "FINDING gate8 test-theta.sh failure referencing agent-system/extensions/core/scripts/theta.sh"
state_before="$(cat "$STATE_FILE")"
run_sut --session sess_test --state-file "$STATE_FILE" --dry-run
state_after="$(cat "$STATE_FILE")"
if [ "$state_before" = "$state_after" ]; then
  common_test_pass "Case 9: --dry-run leaves --state-file byte-unchanged"
else
  common_test_fail "Case 9: --dry-run unexpectedly modified --state-file: before='$state_before' after='$state_after'"
fi
if echo "$LAST_STDOUT" | jq -e '.gate_exit_code == 1' >/dev/null 2>&1; then
  common_test_pass "Case 9: --dry-run still prints the computed record to stdout"
else
  common_test_fail "Case 9: expected the computed batch_gate record on stdout, got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 10: the shared gate-verdict-extract-lib.sh selection contract, re-pinned HERE because this
# suite is one of deploy_findings_snapshot's five real callers (see
# context/standards/shell-script-testing.md's "Verdict-line extraction contract" section and the
# BLAST RADIUS note in this task's own research/plan): a regression in the extraction helper
# that slipped past test-deploy-baseline-lib.sh's own direct coverage would, left unpinned here
# too, silently reach this consumer's batch-blocking attribution decision. Four shapes:
# line-initial [FAIL] selected; a [PASS] line quoting [FAIL] in its message NOT selected; an
# indented fixture-internal [FAIL] NOT selected; an SGR-prefixed [FAIL] selected after stripping.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 10: gate-verdict-extract-lib.sh selection contract (re-pinned for this consumer)"

gvel_out_a="$(verify_deploy_extract_verdict_lines '[FAIL]' '[FAIL] /path/test-real.sh')"
if [ "$gvel_out_a" = "/path/test-real.sh" ]; then
  common_test_pass "Case 10a: a line-initial [FAIL] <path> row is selected"
else
  common_test_fail "Case 10a: line-initial [FAIL] row mismatch (got: '$gvel_out_a')"
fi

gvel_out_b="$(verify_deploy_extract_verdict_lines '[FAIL]' '[PASS] case3: exactly one [FAIL] line for X under hard mode')"
if [ -z "$gvel_out_b" ]; then
  common_test_pass "Case 10b: a [PASS] line quoting [FAIL] in its message is NOT selected"
else
  common_test_fail "Case 10b: [PASS]-quoting-[FAIL] line wrongly selected (got: '$gvel_out_b')"
fi

gvel_out_c="$(verify_deploy_extract_verdict_lines '[FAIL]' '    [FAIL] baseline fixture is not clean (rc=1, ...)')"
if [ -z "$gvel_out_c" ]; then
  common_test_pass "Case 10c: an indented fixture-internal [FAIL] line is NOT selected"
else
  common_test_fail "Case 10c: indented fixture-internal line wrongly selected (got: '$gvel_out_c')"
fi

gvel_sgr=$'\x1b[31m[FAIL]\x1b[0m lint-lifecycle-status-var: 3 violation(s) across 10 file(s)'
gvel_out_d="$(verify_deploy_extract_verdict_lines '[FAIL]' "$gvel_sgr")"
if [ "$gvel_out_d" = "lint-lifecycle-status-var: 3 violation(s) across 10 file(s)" ]; then
  common_test_pass "Case 10d: an SGR-prefixed [FAIL] row is selected after stripping"
else
  common_test_fail "Case 10d: SGR-prefixed [FAIL] row mismatch (got: '$gvel_out_d')"
fi

echo ""
echo "========================================"
echo "test-orchestrate-batch-gate.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
