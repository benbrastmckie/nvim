#!/usr/bin/env bash
# test-tts-notify.sh - Fixture-driven regression suite for hooks/tts-notify.sh: the three
# utterance vocabularies (interactive "Tab N", lifecycle "Tab N STATUS", stop "Tab N done"), the
# pane-keyed cooldown gate in both directions, pane independence, and TTS_ENABLED=0.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md: pass()/
# fail()/info() via lib/common.sh, PASSED/FAILED integer counters, mktemp -d workdirs with an
# EXIT trap, and content-based assertions. The real hook is driven as a subprocess with a fake
# `piper`/`paplay` pair placed on PATH (so the script's own `command -v piper` guard and
# speak()'s `command -v paplay` guard both resolve) and a dummy PIPER_VOICE file -- no real
# audio synthesis is required or attempted. The cooldown cases pre-seed the stamp file with a
# chosen `date +%s` offset rather than sleeping, per the plan's own "inject the clock" guidance
# for this suite.
#
# Ambient-host-state isolation: COOLDOWN_FILE is keyed by XDG_RUNTIME_DIR/UID/WEZTERM_PANE, all
# three of which this suite redirects at fixture-local values, so no case reads or writes real
# host runtime state, and a concurrently running real session on this same host cannot collide
# with or be disturbed by this suite.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Resolves to agent-system/extensions/core/hooks/tts-notify.sh in source-store mode and to
# .claude/hooks/tts-notify.sh in deployed mode, with no branching -- hooks/ and scripts/ are
# always siblings under the extension root in both trees.
HOOK="$SCRIPT_DIR/../../hooks/tts-notify.sh"

if [ ! -f "$HOOK" ]; then
  echo "ERROR: expected hook at $HOOK" >&2
  exit 1
fi

PASSED=0
FAILED=0
common_test_workdir_init

# --- Fixture scaffold shared by every case ---
FAKE_BIN="${WORKDIR}/fakebin"
mkdir -p "$FAKE_BIN"
cat > "${FAKE_BIN}/piper" <<'EOF'
#!/usr/bin/env bash
# Fake piper: consumes stdin (the text to "synthesize"), writes nothing, exits 0.
cat >/dev/null
exit 0
EOF
cat > "${FAKE_BIN}/paplay" <<'EOF'
#!/usr/bin/env bash
# Fake paplay: consumes stdin (the "audio"), exits 0.
cat >/dev/null
exit 0
EOF
chmod +x "${FAKE_BIN}/piper" "${FAKE_BIN}/paplay"

DUMMY_VOICE="${WORKDIR}/dummy-voice.onnx"
: > "$DUMMY_VOICE"

RUNTIME_DIR="${WORKDIR}/xdg-runtime"
mkdir -p "$RUNTIME_DIR"

# run_hook <pane> <cooldown> <enabled> <mode...> -- invokes the real hook in a fresh scratch
# repo cwd (so LOG_FILE="specs/tmp/claude-tts-notify.log", a hardcoded repo-relative literal in
# the hook, resolves inside this suite's own workdir rather than the real repository). Echoes
# the hook's exit code; the caller reads $REPO/specs/tmp/claude-tts-notify.log directly.
run_hook() {
  local pane="$1" cooldown="$2" enabled="$3"
  shift 3
  local repo code
  repo="$(mktemp -d -p "$WORKDIR")"
  mkdir -p "${repo}/specs/tmp"
  (
    cd "$repo" || exit 1
    PATH="${FAKE_BIN}:${PATH}" \
      TTS_ENABLED="$enabled" \
      PIPER_VOICE="$DUMMY_VOICE" \
      TTS_COOLDOWN="$cooldown" \
      XDG_RUNTIME_DIR="$RUNTIME_DIR" \
      WEZTERM_PANE="$pane" \
      bash "$HOOK" "$@" >/dev/null 2>"${repo}/stderr.log"
  )
  code=$?
  echo "${repo}:${code}"
}

log_of() { cat "${1}/specs/tmp/claude-tts-notify.log" 2>/dev/null || true; }

stamp_path() { echo "${RUNTIME_DIR}/claude-tts-cooldown-${UID:-0}-${1}"; }

seed_stamp() {
  # seed_stamp <pane> <seconds_ago>
  local pane="$1" ago="$2" now
  now=$(date +%s)
  echo $(( now - ago )) > "$(stamp_path "$pane")"
}

clear_stamp() { rm -f "$(stamp_path "$1")"; }

# =====================================================================
# (a) --stop emits an utterance containing "done"; interactive mode does not.
# =====================================================================
clear_stamp "pane-a1"
result="$(run_hook "pane-a1" 75 1 --stop)"
repo="${result%:*}"; code="${result##*:}"
log="$(log_of "$repo")"
rm -rf "$repo"
if [ "$code" -eq 0 ] && echo "$log" | grep -q 'Stop notification sent: Tab done'; then
  common_test_pass "--stop utterance contains 'done' (Tab done, no WEZTERM_PANE resolver available in fixture -> bare 'Tab')"
else
  common_test_fail "--stop expected a logged 'Stop notification sent: Tab done' line, got: $log (exit=$code)"
fi

clear_stamp "pane-a2"
result="$(run_hook "pane-a2" 75 1)"
repo="${result%:*}"; code="${result##*:}"
log="$(log_of "$repo")"
rm -rf "$repo"
if [ "$code" -eq 0 ] && echo "$log" | grep -q 'Interactive notification sent: Tab$' && ! echo "$log" | grep -q 'done'; then
  common_test_pass "interactive mode (no args) emits bare 'Tab' with no 'done'"
else
  common_test_fail "interactive mode expected a bare 'Tab' line with no 'done', got: $log (exit=$code)"
fi

# =====================================================================
# (b) --lifecycle researched still emits exactly "Tab researched" (bare prefix in this fixture,
# since no real wezterm CLI is on PATH) with no "done".
# =====================================================================
clear_stamp "pane-b"
result="$(run_hook "pane-b" 75 1 --lifecycle researched)"
repo="${result%:*}"; code="${result##*:}"
log="$(log_of "$repo")"
rm -rf "$repo"
if [ "$code" -eq 0 ] && echo "$log" | grep -q 'Lifecycle notification sent: Tab researched (status=researched)' && ! echo "$log" | grep -q 'done'; then
  common_test_pass "--lifecycle researched emits 'Tab researched' with no 'done'"
else
  common_test_fail "--lifecycle researched expected 'Tab researched' with no 'done', got: $log (exit=$code)"
fi

# =====================================================================
# (c) Two invocations inside TTS_COOLDOWN produce one logged fire and one logged suppression.
# =====================================================================
clear_stamp "pane-c"
result1="$(run_hook "pane-c" 75 1 --stop)"
repo1="${result1%:*}"; code1="${result1##*:}"
log1="$(log_of "$repo1")"
stamp_before_second="$(cat "$(stamp_path "pane-c")" 2>/dev/null || echo "")"
# Carry the real pane-c stamp into the second invocation's own scratch repo so the gate sees it
# (COOLDOWN_FILE is keyed by XDG_RUNTIME_DIR+UID+WEZTERM_PANE, shared across both calls since
# XDG_RUNTIME_DIR and WEZTERM_PANE are held constant -- run_hook's per-call scratch repo only
# isolates specs/tmp/, never the cooldown stamp path itself).
result2="$(run_hook "pane-c" 75 1 --stop)"
repo2="${result2%:*}"; code2="${result2##*:}"
log2="$(log_of "$repo2")"
rm -rf "$repo1" "$repo2"
if [ "$code1" -eq 0 ] && [ "$code2" -eq 0 ] \
  && echo "$log1" | grep -q 'Stop notification sent' \
  && echo "$log2" | grep -q 'Suppressed by cooldown: mode=stop' \
  && ! echo "$log2" | grep -q 'Stop notification sent'; then
  common_test_pass "cooldown: second --stop inside TTS_COOLDOWN is suppressed, not re-fired"
else
  common_test_fail "cooldown: expected first=fire second=suppressed, got log1=[$log1] log2=[$log2] stamp_before_second=[$stamp_before_second]"
fi

# =====================================================================
# (d) Two invocations separated by more than TTS_COOLDOWN produce two fires.
# =====================================================================
clear_stamp "pane-d"
seed_stamp "pane-d" 100
result="$(run_hook "pane-d" 75 1 --stop)"
repo="${result%:*}"; code="${result##*:}"
log="$(log_of "$repo")"
rm -rf "$repo"
if [ "$code" -eq 0 ] && echo "$log" | grep -q 'Stop notification sent'; then
  common_test_pass "cooldown: an invocation 100s after the last stamp (TTS_COOLDOWN=75) fires"
else
  common_test_fail "cooldown: expected a fire past the window, got: $log (exit=$code)"
fi

# =====================================================================
# (e) TTS_ENABLED=0 produces zero fires in all three modes.
# =====================================================================
for args in "" "--stop" "--lifecycle researched"; do
  clear_stamp "pane-e"
  # shellcheck disable=SC2086
  result="$(run_hook "pane-e" 75 0 $args)"
  repo="${result%:*}"; code="${result##*:}"
  log="$(log_of "$repo")"
  rm -rf "$repo"
  if [ "$code" -eq 0 ] && [ -z "$log" ]; then
    common_test_pass "TTS_ENABLED=0 produces zero log lines (mode: '${args:-interactive}')"
  else
    common_test_fail "TTS_ENABLED=0 expected zero log lines (mode: '${args:-interactive}'), got: $log (exit=$code)"
  fi
done

# =====================================================================
# (f) Two distinct WEZTERM_PANE values do not suppress each other: seed pane-f1 inside the
# window, then confirm a FRESH pane (pane-f2, never seeded) still fires.
# =====================================================================
clear_stamp "pane-f1"
clear_stamp "pane-f2"
seed_stamp "pane-f1" 5
result="$(run_hook "pane-f2" 75 1 --stop)"
repo="${result%:*}"; code="${result##*:}"
log="$(log_of "$repo")"
rm -rf "$repo"
if [ "$code" -eq 0 ] && echo "$log" | grep -q 'Stop notification sent'; then
  common_test_pass "pane independence: pane-f1's fresh (5s-old) stamp does not suppress pane-f2"
else
  common_test_fail "pane independence: expected pane-f2 to fire regardless of pane-f1's stamp, got: $log (exit=$code)"
fi
clear_stamp "pane-f1"
clear_stamp "pane-f2"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
