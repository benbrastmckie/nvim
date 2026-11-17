#!/usr/bin/env bash
# test-sapience-context-scoping.sh -- regression suite for verify-sapience-context-scoping.sh's
# --repeat N unanimous-agreement verdict (the N iterations must ALL agree before a conclusive
# outcome is reported; a single dissenting iteration is INCONCLUSIVE, never a majority vote).
#
# Reuses test-sapience-capture.sh's curl-stub-on-PATH technique (a `curl` executable installed
# in a scratch directory prepended to PATH, dispatched by env vars, since the script under test
# calls bare `curl`), extended here to a SEQUENCED, per-call-index response table of arbitrary
# length: CURL_STUB_CODE_<n>/CURL_STUB_BODY_<n>/CURL_STUB_EXIT_<n> for call index n = 1, 2, 3,
# ..., each falling back to the unsuffixed CURL_STUB_CODE/CURL_STUB_BODY/CURL_STUB_EXIT and then
# to the original defaults (200, {}, 0). Call index n is odd for a real-project call and even
# for the matching sentinel-project call (the script's own per-iteration pairing).
#
# Deployed-tree-shaped fixture (mandatory, not stylistic): verify-sapience-context-scoping.sh
# sources ${SCRIPT_DIR}/lib/common.sh, which does not exist alongside it in the source store (no
# scripts/lib/ of sapience's own -- it is flattened in only post-deploy). Each case therefore
# builds a scratch <scratch>/.claude/scripts/{verify-sapience-context-scoping.sh,lib/common.sh}
# tree and a scratch git repo, mirroring test-sapience-capture.sh's build_scratch convention.
#
# Config bypass: SAPIENCE_HOST and SAPIENCE_TOKEN are exported directly on every invocation, so
# no ~/.sapience/config.json fixture is needed at all -- the script's own config() precedence
# resolves both from the environment before ever looking at a config file.
#
# Cases:
#   (1) Unanimous RESIDUAL_HOLDS over the default 3 iterations: every real/sentinel pair
#       returns byte-identical text/visible bodies. Exit 0.
#   (2) Unanimous RESIDUAL_LIFTED over 3 iterations: every real/sentinel pair differs, in the
#       same way, every iteration. Exit 0.
#   (3) A mixed tally (2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations) yields
#       INCONCLUSIVE and exit 2, naming the tally.
#   (4) One iteration's call returning a non-200 status yields INCONCLUSIVE and exit 2 even
#       though the other iterations agree -- proving a single iteration's failure is never
#       discarded as a non-vote.
#   (5) --repeat 1 reproduces today's single-run behavior (RESIDUAL_HOLDS, exit 0).
#   (6) A bad --repeat value (0, and a non-integer) exits 1 with no network call made.
#
# Follows the core shell-test convention (context/standards/shell-script-testing.md): Class B
# (`set -uo pipefail`, no `-e`) counter-idiom harness with pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, a single mktemp -d workdir with a trap EXIT cleanup.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (verify-sapience-context-scoping.sh or lib/common.sh not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/../verify-sapience-context-scoping.sh" ]; then
  SCRIPT_UNDER_TEST="$SCRIPT_DIR/../verify-sapience-context-scoping.sh"
else
  echo "ERROR: verify-sapience-context-scoping.sh not found at $SCRIPT_DIR/../verify-sapience-context-scoping.sh" >&2
  exit 2
fi

if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-context-scoping.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{verify-sapience-context-
#     scoping.sh,lib/common.sh} tree (mirroring test-sapience-capture.sh's own build_scratch
#     convention) and a scratch git repo so repo-toplevel/slug resolution succeeds. Echoes the
#     scratch root; its basename is the repo slug the script will mint. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/verify-sapience-context-scoping.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/verify-sapience-context-scoping.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

# --- build_curl_stub_n -- installs a minimal PATH-shadowing curl stub, into a fresh scratch
#     directory (under $TOP_WORKDIR), supporting an ARBITRARY-LENGTH per-call-index response
#     table via indirect variable expansion: call index n dispatches on
#     CURL_STUB_CODE_<n>/CURL_STUB_BODY_<n>/CURL_STUB_EXIT_<n>, falling back to the unsuffixed
#     CURL_STUB_CODE/CURL_STUB_BODY/CURL_STUB_EXIT and then to the original defaults (200, {},
#     0). Echoes the stub directory (to prepend to PATH, and to pass as STUB_DIR so the stub can
#     find its recorder file). ---
build_curl_stub_n() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  : > "$stub_dir/.curl_call_count"
  cat > "$stub_dir/curl" <<'STUB'
#!/usr/bin/env bash
counter_file="${STUB_DIR:-$(dirname "$0")}/.curl_call_count"
echo x >> "$counter_file" 2>/dev/null || true
call_index="$(wc -l < "$counter_file" 2>/dev/null | tr -d ' ')"
[ -z "$call_index" ] && call_index=1

code_var="CURL_STUB_CODE_${call_index}"
body_var="CURL_STUB_BODY_${call_index}"
exit_var="CURL_STUB_EXIT_${call_index}"

code="${!code_var:-${CURL_STUB_CODE:-200}}"
body="${!body_var:-${CURL_STUB_BODY:-{\}}}"
exitcode="${!exit_var:-${CURL_STUB_EXIT:-0}}"

if [ "$exitcode" != "0" ]; then
  echo "curl: (7) Failed to connect to host" >&2
  exit "$exitcode"
fi
printf '%s' "$body"
printf '\n%s' "$code"
exit 0
STUB
  chmod +x "$stub_dir/curl"
  echo "$stub_dir"
}

# --- run_probe <scratch> <stub_dir> [args...] -- invokes the scratch copy of the script under
#     test with PATH shadowed by the curl stub, STUB_DIR set so the stub finds its recorder
#     file, and SAPIENCE_HOST/SAPIENCE_TOKEN exported directly so no config.json fixture is
#     needed at all. HOME is pointed at an unused scratch directory, never the real $HOME. ---
run_probe() {
  local scratch="$1" stub_dir="$2"; shift 2
  local fake_home="$scratch/fake-home"
  mkdir -p "$fake_home"
  (
    cd "$scratch" || exit 2
    HOME="$fake_home" \
    SAPIENCE_HOST="http://stub.invalid" \
    SAPIENCE_TOKEN="dummy-test-token" \
    STUB_DIR="$stub_dir" \
    PATH="$stub_dir:$PATH" \
    bash "$scratch/.claude/scripts/verify-sapience-context-scoping.sh" "$@"
  )
}

HOLDS_BODY='{"text":"same content","visible":"same content"}'

# =====================================================================
# Case 1: unanimous RESIDUAL_HOLDS over the default 3 iterations.
# =====================================================================
SCRATCH1="$(build_scratch)"
STUB1="$(build_curl_stub_n)"
RC1=0
OUT1=$(CURL_STUB_BODY="$HOLDS_BODY" run_probe "$SCRATCH1" "$STUB1" --repeat 3 2>&1) || RC1=$?

if [ "$RC1" -eq 0 ] && printf '%s' "$OUT1" | grep -q '^RESIDUAL_HOLDS'; then
  pass "Case 1: unanimous RESIDUAL_HOLDS over 3 iterations yields exit 0"
else
  fail "Case 1: expected exit 0 and RESIDUAL_HOLDS; rc=$RC1 output=$OUT1"
fi

# =====================================================================
# Case 2: unanimous RESIDUAL_LIFTED over 3 iterations -- every real/sentinel pair differs, the
# same way, every iteration (odd call index = real, even = sentinel).
# =====================================================================
SCRATCH2="$(build_scratch)"
STUB2="$(build_curl_stub_n)"
RC2=0
OUT2=$(CURL_STUB_BODY_1='{"text":"R","visible":"R"}' CURL_STUB_BODY_2='{"text":"S","visible":"S"}' \
       CURL_STUB_BODY_3='{"text":"R","visible":"R"}' CURL_STUB_BODY_4='{"text":"S","visible":"S"}' \
       CURL_STUB_BODY_5='{"text":"R","visible":"R"}' CURL_STUB_BODY_6='{"text":"S","visible":"S"}' \
       run_probe "$SCRATCH2" "$STUB2" --repeat 3 2>&1) || RC2=$?

if [ "$RC2" -eq 0 ] && printf '%s' "$OUT2" | grep -q '^RESIDUAL_LIFTED'; then
  pass "Case 2: unanimous RESIDUAL_LIFTED over 3 iterations yields exit 0"
else
  fail "Case 2: expected exit 0 and RESIDUAL_LIFTED; rc=$RC2 output=$OUT2"
fi

# =====================================================================
# Case 3: a mixed tally (2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations) yields
# INCONCLUSIVE and exit 2, naming the tally -- proving unanimity, not a majority vote.
# =====================================================================
SCRATCH3="$(build_scratch)"
STUB3="$(build_curl_stub_n)"
RC3=0
OUT3=$(CURL_STUB_BODY_1="$HOLDS_BODY" CURL_STUB_BODY_2="$HOLDS_BODY" \
       CURL_STUB_BODY_3="$HOLDS_BODY" CURL_STUB_BODY_4="$HOLDS_BODY" \
       CURL_STUB_BODY_5='{"text":"R","visible":"R"}' CURL_STUB_BODY_6='{"text":"S","visible":"S"}' \
       run_probe "$SCRATCH3" "$STUB3" --repeat 3 2>&1) || RC3=$?

if [ "$RC3" -eq 2 ] && printf '%s' "$OUT3" | grep -q '^INCONCLUSIVE' \
   && printf '%s' "$OUT3" | grep -q '2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations'; then
  pass "Case 3: a mixed 2-1 tally yields INCONCLUSIVE with the named tally and exit 2 (unanimity, not majority)"
else
  fail "Case 3: expected INCONCLUSIVE with '2 RESIDUAL_HOLDS, 1 RESIDUAL_LIFTED over 3 iterations'; rc=$RC3 output=$OUT3"
fi

# =====================================================================
# Case 4: one iteration's call returning a non-200 status yields INCONCLUSIVE and exit 2 even
# though the other iterations agree -- a single iteration's failure is never discarded as a
# non-vote. Call 3 (iteration 2's real-project call) returns 500; calls 1,2 (iteration 1) agree.
# =====================================================================
SCRATCH4="$(build_scratch)"
STUB4="$(build_curl_stub_n)"
RC4=0
OUT4=$(CURL_STUB_BODY_1="$HOLDS_BODY" CURL_STUB_BODY_2="$HOLDS_BODY" \
       CURL_STUB_CODE_3=500 CURL_STUB_BODY_3='{"error":"server error"}' \
       CURL_STUB_BODY_5="$HOLDS_BODY" CURL_STUB_BODY_6="$HOLDS_BODY" \
       run_probe "$SCRATCH4" "$STUB4" --repeat 3 2>&1) || RC4=$?

if [ "$RC4" -eq 2 ] && printf '%s' "$OUT4" | grep -q '^INCONCLUSIVE' \
   && printf '%s' "$OUT4" | grep -q 'iteration 2/3'; then
  pass "Case 4: a non-200 on one iteration's call yields INCONCLUSIVE naming that iteration, even though the others agree"
else
  fail "Case 4: expected INCONCLUSIVE naming iteration 2/3; rc=$RC4 output=$OUT4"
fi

# =====================================================================
# Case 5: --repeat 1 reproduces today's single-run behavior (RESIDUAL_HOLDS, exit 0).
# =====================================================================
SCRATCH5="$(build_scratch)"
STUB5="$(build_curl_stub_n)"
RC5=0
OUT5=$(CURL_STUB_BODY="$HOLDS_BODY" run_probe "$SCRATCH5" "$STUB5" --repeat 1 2>&1) || RC5=$?

if [ "$RC5" -eq 0 ] && printf '%s' "$OUT5" | grep -q '^RESIDUAL_HOLDS' && printf '%s' "$OUT5" | grep -q '1 iteration'; then
  pass "Case 5: --repeat 1 reproduces today's single-run RESIDUAL_HOLDS behavior with exit 0"
else
  fail "Case 5: expected exit 0, RESIDUAL_HOLDS, and '1 iteration'; rc=$RC5 output=$OUT5"
fi

# =====================================================================
# Case 6: a bad --repeat value (0, and a non-integer) exits 1 with no network call made.
# =====================================================================
SCRATCH6="$(build_scratch)"
STUB6="$(build_curl_stub_n)"
RC6A=0
OUT6A=$(run_probe "$SCRATCH6" "$STUB6" --repeat 0 2>&1) || RC6A=$?
CALLS6A="$(wc -l < "$STUB6/.curl_call_count" 2>/dev/null | tr -d ' ')"

RC6B=0
OUT6B=$(run_probe "$SCRATCH6" "$STUB6" --repeat notanumber 2>&1) || RC6B=$?
CALLS6B="$(wc -l < "$STUB6/.curl_call_count" 2>/dev/null | tr -d ' ')"

if [ "$RC6A" -eq 1 ] && [ "${CALLS6A:-0}" -eq 0 ] && [ "$RC6B" -eq 1 ] && [ "${CALLS6B:-0}" -eq 0 ]; then
  pass "Case 6: --repeat 0 and --repeat notanumber both exit 1 with no network call made"
else
  fail "Case 6: expected exit 1 with zero calls for both; rc6a=$RC6A calls6a=$CALLS6A out6a=$OUT6A rc6b=$RC6B calls6b=$CALLS6B out6b=$OUT6B"
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
