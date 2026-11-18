#!/usr/bin/env bash
# test-orchestrate-recap.sh - Regression suite for orchestrate-recap.sh: the two-mode
# (--write / default speak) script backing /orchestrate's end-of-run spoken recap and the
# user-only /recap command (context/contracts/conclusion-stage.md Step 6, commands/recap.md).
#
# Structural model: test-orchestrate-conclusion-roadmap.sh's isolated-sandbox shape
# (common_test_repo_root, common_test_resolve_subject/common_test_declare_subject
# source-store-first resolution, a fresh <scratch>/.claude/scripts/{...} deploy-shaped tree per
# case so deploy-root-guard.sh's structural check passes without a real deploy) combined with
# test-tts-notify.sh's fake-binary-on-PATH technique (a fake piper/paplay/espeak-ng, each
# touching its own marker file when invoked, so presence/absence of an actual playback attempt
# is a file-existence assertion rather than an audio-content one).
#
# ISOLATION CONTRACT: every case builds a fresh scratch sandbox under mktemp -d with its own
# <scratch>/.claude/scripts/{orchestrate-recap.sh,deploy-root-guard.sh,
# lib/{common.sh,runtime-file-patterns.sh}} and its own <scratch>/specs/ tree. No case reads or
# writes the real specs/ directory.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# SUT or a hard dependency was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

resolve() {
  # resolve <desc> <relative-path-under-scripts/>
  common_test_resolve_subject "$1" "deploy-tree-first" "$DEPLOY_SCRIPTS_SRC/$2" "$SOURCE_STORE_SCRIPTS/$2"
}

SUT="$(resolve "orchestrate-recap.sh" "orchestrate-recap.sh")" || exit 2
common_test_declare_subject "$SUT"
GUARD_SRC="$(resolve "deploy-root-guard.sh" "deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SRC"
COMMON_SRC="$(resolve "lib/common.sh" "lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SRC"
RUNTIME_PATTERNS_SRC="$(resolve "lib/runtime-file-patterns.sh" "lib/runtime-file-patterns.sh")" || exit 2
common_test_declare_subject "$RUNTIME_PATTERNS_SRC"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# ─── Harness helpers ────────────────────────────────────────────────────────────────────────

# build_sandbox -- builds an isolated <scratch>/.claude/scripts/{...} deploy-shaped tree.
# Echoes the scratch root. No real git repo is needed: orchestrate-recap.sh never calls git.
build_sandbox() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$SUT" "$scratch/.claude/scripts/orchestrate-recap.sh"
  cp "$GUARD_SRC" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SRC" "$scratch/.claude/scripts/lib/common.sh"
  cp "$RUNTIME_PATTERNS_SRC" "$scratch/.claude/scripts/lib/runtime-file-patterns.sh"
  chmod +x "$scratch"/.claude/scripts/*.sh
  echo "$scratch"
}

# CORE_DEPS -- every external (non-builtin) command orchestrate-recap.sh and its sourced libs
# invoke, resolved ONCE from this test process's own real PATH and symlinked into each case's
# isolated bin directory below -- so a case asserting piper/paplay/espeak-ng ABSENCE gets a PATH
# that genuinely lacks them, rather than one where a real system install (this suite was
# authored on a host with all three genuinely installed) silently resolves underneath the fake.
CORE_DEPS=(jq mkdir mv date mktemp dirname basename cat find sort head cut timeout rm chmod env bash)

# Resolved once from this test process's OWN real PATH, before any case narrows PATH down to an
# isolated bin dir -- used to invoke the sandboxed script by absolute path so `env`'s own lookup
# of its target command never depends on the just-narrowed PATH it is about to set.
BASH_BIN="$(command -v bash)"

# fakebin_dir -- builds a fresh, SELF-CONTAINED bin directory: every CORE_DEPS tool symlinked in
# (so the sandboxed script has everything real it needs), plus fake piper/paplay/espeak-ng
# binaries, each touching a distinct marker file (under the SAME directory, named
# "<binary>.invoked") when run, then exiting 0. Echoes the directory. The caller sets
# PATH="<this dir>" with NO real-PATH fallback (see run_recap), so a binary this function does
# not place here is genuinely unreachable -- not merely shadowed.
#
#   build_fakebin <scratch> [piper] [paplay] [espeak-ng] -- pass "skip" for a binary that must
#   be ABSENT from PATH for that case (e.g. the piper-absent / paplay-absent cases).
build_fakebin() {
  local scratch="$1" want_piper="${2:-piper}" want_paplay="${3:-paplay}" want_espeak="${4:-skip}"
  local bindir="$scratch/fakebin"
  mkdir -p "$bindir"
  local dep dep_path
  for dep in "${CORE_DEPS[@]}"; do
    dep_path="$(command -v "$dep" 2>/dev/null)" || continue
    ln -sf "$dep_path" "$bindir/$dep"
  done
  if [ "$want_piper" != "skip" ]; then
    cat > "$bindir/piper" <<EOF
#!/usr/bin/env bash
cat >/dev/null
touch "$bindir/piper.invoked"
exit 0
EOF
    chmod +x "$bindir/piper"
  fi
  if [ "$want_paplay" != "skip" ]; then
    cat > "$bindir/paplay" <<EOF
#!/usr/bin/env bash
cat >/dev/null
touch "$bindir/paplay.invoked"
exit 0
EOF
    chmod +x "$bindir/paplay"
  fi
  if [ "$want_espeak" != "skip" ]; then
    cat > "$bindir/espeak-ng" <<EOF
#!/usr/bin/env bash
cat >/dev/null
touch "$bindir/espeak-ng.invoked"
exit 0
EOF
    chmod +x "$bindir/espeak-ng"
  fi
  echo "$bindir"
}

# run_recap <scratch> <fakebin> <env...> -- <args...> -- runs the sandboxed script with PATH
# set to ONLY <fakebin> (build_fakebin's CORE_DEPS symlinks plus whichever of
# piper/paplay/espeak-ng were requested) -- no real-PATH fallback, so a case asserting a
# binary's absence is genuinely testing absence. Echoes "<stdout_file>:<exit_code>".
run_recap() {
  local scratch="$1" fakebin="$2"
  shift 2
  local -a env_pairs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    env_pairs+=("$1")
    shift
  done
  shift # drop the "--"
  local out exit_code
  out="$(mktemp -p "$TOP_WORKDIR")"
  (
    cd "$scratch" || exit 1
    env "${env_pairs[@]}" PATH="${fakebin}" \
      "$BASH_BIN" "$scratch/.claude/scripts/orchestrate-recap.sh" "$@" \
      >"$out" 2>"${out}.err"
  )
  exit_code=$?
  echo "${out}:${exit_code}"
}

DUMMY_VOICE_NAME="dummy-voice.onnx"

# =====================================================================
# Case 1: --write persists session_id/created_ts/text, byte-identical to stdin.
# =====================================================================
SCRATCH1="$(build_sandbox)"
TEXT1="A plain recap sentence with no special punctuation."
printf '%s' "$TEXT1" | bash "$SCRATCH1/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case1" \
  >"$SCRATCH1/write.out" 2>"$SCRATCH1/write.err"
WRITE_EXIT=$?
RECAP_FILE1="$SCRATCH1/specs/.orchestration/.recap-sess_case1.json"
if [ "$WRITE_EXIT" -eq 0 ] && [ -f "$RECAP_FILE1" ] \
  && [ "$(jq -r '.session_id' "$RECAP_FILE1")" = "sess_case1" ] \
  && [ -n "$(jq -r '.created_ts' "$RECAP_FILE1")" ] \
  && [ "$(jq -r '.created_ts' "$RECAP_FILE1")" != "null" ] \
  && [ "$(jq -r '.text' "$RECAP_FILE1")" = "$TEXT1" ]; then
  common_test_pass "Case 1: --write persists session_id/created_ts/text, byte-identical"
else
  common_test_fail "Case 1: --write did not persist the expected JSON (exit=$WRITE_EXIT)" "$(cat "$SCRATCH1/write.err" 2>/dev/null)"
fi
rm -rf "$SCRATCH1"

# =====================================================================
# Case 2: speak mode with a recap file present prints that file's text and exits 0.
# =====================================================================
SCRATCH2="$(build_sandbox)"
TEXT2="The last run finished cleanly."
printf '%s' "$TEXT2" | bash "$SCRATCH2/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case2" >/dev/null 2>&1
FAKEBIN2="$(build_fakebin "$SCRATCH2" skip skip skip)"
RESULT2="$(run_recap "$SCRATCH2" "$FAKEBIN2" TTS_ENABLED=0 -- )"
OUT2="${RESULT2%:*}"; CODE2="${RESULT2##*:}"
if [ "$CODE2" -eq 0 ] && [ "$(cat "$OUT2")" = "$TEXT2" ]; then
  common_test_pass "Case 2: speak mode with a recap file present prints that file's text, exit 0"
else
  common_test_fail "Case 2: expected '$TEXT2', got '$(cat "$OUT2" 2>/dev/null)' (exit=$CODE2)"
fi
rm -rf "$SCRATCH2"

# =====================================================================
# Case 3: speak mode with no recap file recomposes from a fixture runtime metadata file, exit 0,
# non-empty output.
# =====================================================================
SCRATCH3="$(build_sandbox)"
mkdir -p "$SCRATCH3/specs/.orchestration"
cat > "$SCRATCH3/specs/.orchestration/.return-meta-multi-sess_case3.json" <<'EOF'
{"status":"partial","session_id":"sess_case3","metadata":{"tasks_completed":[1,2],"tasks_failed":[3]}}
EOF
FAKEBIN3="$(build_fakebin "$SCRATCH3" skip skip skip)"
RESULT3="$(run_recap "$SCRATCH3" "$FAKEBIN3" TTS_ENABLED=0 -- )"
OUT3="${RESULT3%:*}"; CODE3="${RESULT3##*:}"
TEXT3="$(cat "$OUT3")"
if [ "$CODE3" -eq 0 ] && [ -n "$TEXT3" ] && [[ "$TEXT3" == *"partial"* ]]; then
  common_test_pass "Case 3: no recap file recomposes from a fixture multi-meta file, exit 0, non-empty"
else
  common_test_fail "Case 3: expected a non-empty recomposed sentence mentioning 'partial', got '$TEXT3' (exit=$CODE3)"
fi
rm -rf "$SCRATCH3"

# =====================================================================
# Case 4: speak mode with neither file present prints the generic sentence and exits 0.
# =====================================================================
SCRATCH4="$(build_sandbox)"
FAKEBIN4="$(build_fakebin "$SCRATCH4" skip skip skip)"
RESULT4="$(run_recap "$SCRATCH4" "$FAKEBIN4" TTS_ENABLED=0 -- )"
OUT4="${RESULT4%:*}"; CODE4="${RESULT4##*:}"
TEXT4="$(cat "$OUT4")"
if [ "$CODE4" -eq 0 ] && [ -n "$TEXT4" ]; then
  common_test_pass "Case 4: neither file present prints a non-empty generic sentence, exit 0"
else
  common_test_fail "Case 4: expected a non-empty generic sentence, got '$TEXT4' (exit=$CODE4)"
fi
rm -rf "$SCRATCH4"

# =====================================================================
# Case 5: a malformed/truncated runtime metadata file yields the generic sentence and exit 0,
# never a non-zero exit.
# =====================================================================
SCRATCH5="$(build_sandbox)"
mkdir -p "$SCRATCH5/specs/.orchestration"
echo 'not valid json {{{' > "$SCRATCH5/specs/.orchestration/.return-meta-multi-sess_case5.json"
FAKEBIN5="$(build_fakebin "$SCRATCH5" skip skip skip)"
RESULT5="$(run_recap "$SCRATCH5" "$FAKEBIN5" TTS_ENABLED=0 -- )"
OUT5="${RESULT5%:*}"; CODE5="${RESULT5##*:}"
TEXT5="$(cat "$OUT5")"
if [ "$CODE5" -eq 0 ] && [ -n "$TEXT5" ]; then
  common_test_pass "Case 5: malformed multi-meta file degrades to the generic sentence, exit 0 (never non-zero)"
else
  common_test_fail "Case 5: expected exit 0 with non-empty text on a malformed fixture, got '$TEXT5' (exit=$CODE5)"
fi
rm -rf "$SCRATCH5"

# =====================================================================
# Case 6: TTS_ENABLED=0 prints the text and leaves the piper stub's marker file unwritten.
# =====================================================================
SCRATCH6="$(build_sandbox)"
TEXT6="Audio should stay silent here."
printf '%s' "$TEXT6" | bash "$SCRATCH6/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case6" >/dev/null 2>&1
FAKEBIN6="$(build_fakebin "$SCRATCH6" piper paplay)"
: > "$SCRATCH6/${DUMMY_VOICE_NAME}"
RESULT6="$(run_recap "$SCRATCH6" "$FAKEBIN6" TTS_ENABLED=0 "PIPER_VOICE=$SCRATCH6/${DUMMY_VOICE_NAME}" -- )"
OUT6="${RESULT6%:*}"; CODE6="${RESULT6##*:}"
sleep 0.2
if [ "$CODE6" -eq 0 ] && [ "$(cat "$OUT6")" = "$TEXT6" ] && [ ! -f "$FAKEBIN6/piper.invoked" ]; then
  common_test_pass "Case 6: TTS_ENABLED=0 prints text and never invokes the piper stub"
else
  common_test_fail "Case 6: expected text printed + no piper invocation (exit=$CODE6, piper.invoked exists=$([ -f "$FAKEBIN6/piper.invoked" ] && echo yes || echo no))"
fi
rm -rf "$SCRATCH6"

# =====================================================================
# Case 7: with piper absent from a shimmed PATH, the script prints and exits 0, and an
# espeak-ng stub's marker file is never written -- the no-second-engine guarantee.
# =====================================================================
SCRATCH7="$(build_sandbox)"
TEXT7="No second engine should ever fire."
printf '%s' "$TEXT7" | bash "$SCRATCH7/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case7" >/dev/null 2>&1
FAKEBIN7="$(build_fakebin "$SCRATCH7" skip paplay espeak-ng)"
: > "$SCRATCH7/${DUMMY_VOICE_NAME}"
RESULT7="$(run_recap "$SCRATCH7" "$FAKEBIN7" TTS_ENABLED=1 "PIPER_VOICE=$SCRATCH7/${DUMMY_VOICE_NAME}" -- )"
OUT7="${RESULT7%:*}"; CODE7="${RESULT7##*:}"
sleep 0.2
if [ "$CODE7" -eq 0 ] && [ "$(cat "$OUT7")" = "$TEXT7" ] && [ ! -f "$FAKEBIN7/espeak-ng.invoked" ]; then
  common_test_pass "Case 7: piper absent -> prints + exit 0, espeak-ng never invoked (no second engine)"
else
  common_test_fail "Case 7: expected text printed + no espeak-ng invocation (exit=$CODE7, espeak-ng.invoked exists=$([ -f "$FAKEBIN7/espeak-ng.invoked" ] && echo yes || echo no))"
fi
rm -rf "$SCRATCH7"

# =====================================================================
# Case 8: recap text containing an apostrophe and a double quote round-trips --write -> speak
# unmangled -- the regression guard against the existing hook's quoting shape.
# =====================================================================
SCRATCH8="$(build_sandbox)"
TEXT8='It didn'"'"'t go perfectly, and a step said "watch out" -- still, most of it landed.'
printf '%s' "$TEXT8" | bash "$SCRATCH8/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case8" >/dev/null 2>&1
FAKEBIN8="$(build_fakebin "$SCRATCH8" skip skip skip)"
RESULT8="$(run_recap "$SCRATCH8" "$FAKEBIN8" TTS_ENABLED=0 -- )"
OUT8="${RESULT8%:*}"; CODE8="${RESULT8##*:}"
if [ "$CODE8" -eq 0 ] && [ "$(cat "$OUT8")" = "$TEXT8" ]; then
  common_test_pass "Case 8: apostrophe + double-quote text round-trips --write -> speak unmangled"
else
  common_test_fail "Case 8: expected '$TEXT8', got '$(cat "$OUT8" 2>/dev/null)' (exit=$CODE8)"
fi
rm -rf "$SCRATCH8"

# =====================================================================
# Case 9: with paplay absent from a shimmed PATH (piper present), the script prints and exits 0,
# and the piper stub's own marker file is never written -- no playback is attempted without an
# audio sink, and still no second engine.
# =====================================================================
SCRATCH9="$(build_sandbox)"
TEXT9="No audio sink should still mean no synthesis attempt."
printf '%s' "$TEXT9" | bash "$SCRATCH9/.claude/scripts/orchestrate-recap.sh" --write --session "sess_case9" >/dev/null 2>&1
FAKEBIN9="$(build_fakebin "$SCRATCH9" piper skip)"
: > "$SCRATCH9/${DUMMY_VOICE_NAME}"
RESULT9="$(run_recap "$SCRATCH9" "$FAKEBIN9" TTS_ENABLED=1 "PIPER_VOICE=$SCRATCH9/${DUMMY_VOICE_NAME}" -- )"
OUT9="${RESULT9%:*}"; CODE9="${RESULT9##*:}"
sleep 0.2
if [ "$CODE9" -eq 0 ] && [ "$(cat "$OUT9")" = "$TEXT9" ] && [ ! -f "$FAKEBIN9/piper.invoked" ]; then
  common_test_pass "Case 9: paplay absent -> prints + exit 0, piper never invoked (no sink, no attempt)"
else
  common_test_fail "Case 9: expected text printed + no piper invocation (exit=$CODE9, piper.invoked exists=$([ -f "$FAKEBIN9/piper.invoked" ] && echo yes || echo no))"
fi
rm -rf "$SCRATCH9"

# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
