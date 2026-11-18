#!/usr/bin/env bash
# test-claude-stop-notify.sh - Fixture-driven regression suite for hooks/claude-stop-notify.sh:
# the agent_id subagent guard, the global workflow-active-marker suppression (including a
# foreign session's marker), and the single tts-notify.sh --stop invocation on the no-marker
# interactive path.
#
# The hook resolves its siblings (wezterm-notify.sh, tts-notify.sh) through SCRIPT_DIR, so this
# suite builds a deployed-tree-shaped fixture (a real hooks/ directory holding the real
# claude-stop-notify.sh beside a recording STUB for tts-notify.sh and a no-op stub for
# wezterm-notify.sh) and observes invocation by inspecting what the stub recorded -- never by
# relying on audio or the real tts-notify.sh.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

HOOK_SRC="$SCRIPT_DIR/../../hooks/claude-stop-notify.sh"

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected hook at $HOOK_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0
common_test_workdir_init

# build_fixture -- a fresh deployed-tree-shaped hooks/ directory under WORKDIR holding the real
# claude-stop-notify.sh, a no-op wezterm-notify.sh stub, and a recording tts-notify.sh stub (it
# appends its own argv to a call-log file so the suite can assert exactly how many times, and
# with what arguments, it was invoked). Echoes the fixture's hooks/ dir and a parallel "project
# root" dir that holds tmp/ (for the workflow-active markers, which the hook resolves as
# "$SCRIPT_DIR/../tmp/workflow-active-*").
build_fixture() {
  local base hooks_dir
  base="$(mktemp -d -p "$WORKDIR")"
  hooks_dir="${base}/hooks"
  mkdir -p "$hooks_dir" "${base}/tmp"
  cp "$HOOK_SRC" "${hooks_dir}/claude-stop-notify.sh"
  chmod +x "${hooks_dir}/claude-stop-notify.sh"

  cat > "${hooks_dir}/wezterm-notify.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "${hooks_dir}/wezterm-notify.sh"

  cat > "${hooks_dir}/tts-notify.sh" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${base}/tts-call-log.txt"
echo '{}'
exit 0
EOF
  chmod +x "${hooks_dir}/tts-notify.sh"

  echo "$base"
}

call_count() {
  if [ -f "${1}/tts-call-log.txt" ]; then
    wc -l < "${1}/tts-call-log.txt" | tr -d ' '
  else
    echo 0
  fi
}

run_hook() {
  # run_hook <base> <stdin_json> -- echoes exit code
  local base="$1" stdin_json="$2" code
  echo "$stdin_json" | bash "${base}/hooks/claude-stop-notify.sh" >/dev/null 2>"${base}/stderr.log"
  code=$?
  echo "$code"
}

# =====================================================================
# (a) stdin JSON carrying agent_id exits via the subagent guard with zero TTS invocation.
# =====================================================================
base="$(build_fixture)"
code="$(run_hook "$base" '{"agent_id":"sub-123"}')"
count="$(call_count "$base")"
rm -rf "$base"
if [ "$code" -eq 0 ] && [ "$count" -eq 0 ]; then
  common_test_pass "agent_id guard: subagent stop exits 0 with zero tts-notify.sh invocations"
else
  common_test_fail "agent_id guard: expected exit=0 count=0, got exit=$code count=$count"
fi

# =====================================================================
# (b) A present workflow-active-<anything> marker exits via the suppression loop with zero TTS
# invocation, including a marker belonging to a DIFFERENT session id (the global-scope property).
# =====================================================================
base="$(build_fixture)"
touch "${base}/tmp/workflow-active-some-other-session-uuid"
code="$(run_hook "$base" '{}')"
count="$(call_count "$base")"
rm -rf "$base"
if [ "$code" -eq 0 ] && [ "$count" -eq 0 ]; then
  common_test_pass "workflow-active suppression: a foreign session's marker suppresses with zero tts-notify.sh invocations"
else
  common_test_fail "workflow-active suppression: expected exit=0 count=0, got exit=$code count=$count"
fi

# =====================================================================
# (c) No marker and no agent_id reaches exactly one tts-notify.sh --stop invocation.
# =====================================================================
base="$(build_fixture)"
code="$(run_hook "$base" '{}')"
count="$(call_count "$base")"
call_args="$(cat "${base}/tts-call-log.txt" 2>/dev/null || echo "")"
rm -rf "$base"
if [ "$code" -eq 0 ] && [ "$count" -eq 1 ] && [ "$call_args" = "--stop" ]; then
  common_test_pass "no-marker path: exactly one tts-notify.sh --stop invocation"
else
  common_test_fail "no-marker path: expected exit=0 count=1 args='--stop', got exit=$code count=$count args='$call_args'"
fi

# =====================================================================
# (d) The hook still emits valid '{}' JSON on stdout and exits 0 on every one of those paths.
# =====================================================================
check_json_and_exit() {
  local label="$1" stdin_json="$2" base out code valid
  base="$(build_fixture)"
  out="$(echo "$stdin_json" | bash "${base}/hooks/claude-stop-notify.sh" 2>/dev/null)"
  code=$?
  rm -rf "$base"
  valid="$(echo "$out" | jq -e . >/dev/null 2>&1 && echo yes || echo no)"
  if [ "$code" -eq 0 ] && [ "$valid" = "yes" ]; then
    common_test_pass "stdout JSON + exit 0: $label (got '$out')"
  else
    common_test_fail "stdout JSON + exit 0: $label expected valid JSON + exit 0, got exit=$code out='$out'"
  fi
}

check_json_and_exit "agent_id path" '{"agent_id":"sub-456"}'

base2="$(build_fixture)"
touch "${base2}/tmp/workflow-active-another-session"
out2="$(echo '{}' | bash "${base2}/hooks/claude-stop-notify.sh" 2>/dev/null)"
code2=$?
rm -rf "$base2"
valid2="$(echo "$out2" | jq -e . >/dev/null 2>&1 && echo yes || echo no)"
if [ "$code2" -eq 0 ] && [ "$valid2" = "yes" ]; then
  common_test_pass "stdout JSON + exit 0: workflow-active-marker path (got '$out2')"
else
  common_test_fail "stdout JSON + exit 0: workflow-active-marker path expected valid JSON + exit 0, got exit=$code2 out='$out2'"
fi

check_json_and_exit "no-marker path" '{}'

# =====================================================================
# Regression anchor: with the --stop call and its guard removed (sandbox copy only), the
# no-marker path must NOT invoke tts-notify.sh -- proving case (c) is not vacuously passing.
# =====================================================================
anchor_base="$(build_fixture)"
sed -i '/tts_script="\$SCRIPT_DIR\/tts-notify.sh"/,/^fi$/d' "${anchor_base}/hooks/claude-stop-notify.sh"
if grep -q 'bash "\$tts_script" --stop' "${anchor_base}/hooks/claude-stop-notify.sh"; then
  common_test_fail "regression anchor: sed removal of the --stop call block did not take effect in the sandbox copy"
else
  anchor_code="$(run_hook "$anchor_base" '{}')"
  anchor_count="$(call_count "$anchor_base")"
  if [ "$anchor_code" -eq 0 ] && [ "$anchor_count" -eq 0 ]; then
    common_test_pass "regression anchor: removing the --stop call from a sandbox copy makes case (c) go red (0 invocations), confirming non-vacuousness"
  else
    common_test_fail "regression anchor: expected 0 invocations after removing the --stop call, got count=$anchor_count exit=$anchor_code"
  fi
fi
rm -rf "$anchor_base"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
