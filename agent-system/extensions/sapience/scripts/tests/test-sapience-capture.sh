#!/usr/bin/env bash
# test-sapience-capture.sh - Regression suite for sapience-retrieve.sh's exit-code split: a
# genuine transport/HTTP failure (exit 2, with the HTTP status and a length-bounded body excerpt
# on stderr) versus a benign no-match (exit 1, nothing on stderr, exactly as before) versus
# success (exit 0, the <memory-context> envelope on stdout). Cases 1-4 cover the original split;
# cases 5-9 cover the bounded cold-start retry (503 + JSON + `.starting == true`): a retry that
# succeeds (5), a second 503 that still ends in the unchanged exit-2 degrade (6), a 4xx that is
# never retried (7), a non-JSON 503 body that is never retried (8), and a `retry_after` outside
# [1, 20] that is clamped to the ceiling rather than honored verbatim (9).
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup. `curl` is
# PATH-shadowed by a minimal inline stub (the same technique
# literature/scripts/tests/curl-stub.sh establishes: install a `curl` executable in a scratch
# directory prepended to PATH, dispatched by env vars, since the script under test calls bare
# `curl`, never an absolute path or `command curl`).
#
# Stub dispatch contract (sequenced curl + recording sleep, for the cold-start retry path):
#   - `build_curl_stub` writes both `curl` and `sleep` into its returned stub directory, plus two
#     empty recorder files: `.curl_call_count` (one line appended per `curl` invocation) and
#     `.sleep_durations` (one line appended per `sleep` invocation, the bare requested duration).
#   - `run_sr` exports `STUB_DIR` (the stub directory) alongside the `PATH` shadow, so both stubs
#     always know where their own recorder files live regardless of how `$0` resolves.
#   - The `curl` stub determines its 1-based call index from `.curl_call_count`'s line count
#     *after* recording the current call, then picks its response: for call 1, it prefers
#     `CURL_STUB_CODE_1`/`CURL_STUB_BODY_1`/`CURL_STUB_EXIT_1`; for call 2 and beyond, it prefers
#     `CURL_STUB_CODE_2`/`CURL_STUB_BODY_2`/`CURL_STUB_EXIT_2`. Either tier falls back to the
#     existing unsuffixed `CURL_STUB_CODE`/`CURL_STUB_BODY`/`CURL_STUB_EXIT`, and then to the
#     original defaults (`200`, `{}`, `0`) -- so every pre-existing single-shot case (which sets
#     only the unsuffixed vars and never calls `curl` a second time) is byte-identical in
#     behavior.
#   - The `sleep` stub records its first argument and exits 0 immediately -- it never actually
#     sleeps, so the suite stays fast on every retry path.
#   - Readback helpers `curl_call_count <stub_dir>` and `sleep_durations <stub_dir>` let a case
#     assert on these directly instead of inferring them from timing.
#
# Bootstrap note: this suite lives under a DIFFERENT extension (sapience) than the shared
# lib/common.sh it needs (core). Post-deploy, every extension's scripts/tests/ and scripts/lib/
# are flattened into one shared .claude/scripts/ tree, so the same-extension-relative path
# resolves correctly there; pre-deploy, in a source-store-only checkout, it falls back to core's
# own scripts/lib/common.sh directly, since sapience itself has no scripts/lib/ of its own.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (sapience-retrieve.sh, deploy-root-guard.sh, or lib/common.sh not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-capture.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-retrieve.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-retrieve.sh" \
  "$SCRIPT_DIR/../sapience-retrieve.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

GUARD_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
GUARD_CANDIDATE_SOURCE="$SCRIPT_DIR/../../../core/scripts/deploy-root-guard.sh"
if [ -f "$GUARD_CANDIDATE_DEPLOYED" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_DEPLOYED"
elif [ -f "$GUARD_CANDIDATE_SOURCE" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_SOURCE"
else
  echo "ERROR: deploy-root-guard.sh not found at $GUARD_CANDIDATE_DEPLOYED or $GUARD_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$GUARD_SCRIPT"
common_test_declare_subject "$COMMON_SH"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{sapience-retrieve.sh,
#     deploy-root-guard.sh,lib/common.sh} tree (so PROJECT_ROOT resolves to <scratch>, mirroring
#     test-issue-record.sh's own convention) and a scratch git repo. Echoes the scratch root. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-retrieve.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-retrieve.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

# --- build_curl_stub -- installs a minimal PATH-shadowing curl stub, plus a companion recording
#     sleep stub, into a fresh scratch directory (under $TOP_WORKDIR). The curl stub supports both
#     the original single-shot dispatch (CURL_STUB_CODE / CURL_STUB_BODY / CURL_STUB_EXIT, applied
#     to every call) and a sequenced two-response dispatch (the _1-suffixed vars for the first
#     call, the _2-suffixed vars for the second call and beyond), each falling back to the
#     unsuffixed var and then to the original default. See the header comment block above for the
#     full dispatch contract. Echoes the stub directory (to prepend to PATH, and to pass as
#     STUB_DIR so both stubs can find their recorder files). ---
build_curl_stub() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  : > "$stub_dir/.curl_call_count"
  : > "$stub_dir/.sleep_durations"
  cat > "$stub_dir/curl" <<'STUB'
#!/usr/bin/env bash
counter_file="${STUB_DIR:-$(dirname "$0")}/.curl_call_count"
echo x >> "$counter_file" 2>/dev/null || true
call_index="$(wc -l < "$counter_file" 2>/dev/null | tr -d ' ')"
[ -z "$call_index" ] && call_index=1

if [ "$call_index" -ge 2 ]; then
  code="${CURL_STUB_CODE_2:-${CURL_STUB_CODE:-200}}"
  body="${CURL_STUB_BODY_2:-${CURL_STUB_BODY:-{\}}}"
  exitcode="${CURL_STUB_EXIT_2:-${CURL_STUB_EXIT:-0}}"
else
  code="${CURL_STUB_CODE_1:-${CURL_STUB_CODE:-200}}"
  body="${CURL_STUB_BODY_1:-${CURL_STUB_BODY:-{\}}}"
  exitcode="${CURL_STUB_EXIT_1:-${CURL_STUB_EXIT:-0}}"
fi

if [ "$exitcode" != "0" ]; then
  echo "curl: (7) Failed to connect to host" >&2
  exit "$exitcode"
fi
printf '%s' "$body"
printf '\n%s' "$code"
exit 0
STUB
  chmod +x "$stub_dir/curl"

  cat > "$stub_dir/sleep" <<'STUB'
#!/usr/bin/env bash
recorder_file="${STUB_DIR:-$(dirname "$0")}/.sleep_durations"
echo "$1" >> "$recorder_file" 2>/dev/null || true
exit 0
STUB
  chmod +x "$stub_dir/sleep"

  echo "$stub_dir"
}

# curl_call_count <stub_dir> -- echoes the number of curl invocations recorded so far.
curl_call_count() {
  local stub_dir="$1"
  if [ -f "$stub_dir/.curl_call_count" ]; then
    wc -l < "$stub_dir/.curl_call_count" | tr -d ' '
  else
    echo 0
  fi
}

# sleep_durations <stub_dir> -- echoes the recorded sleep durations, one per line (empty if none).
sleep_durations() {
  local stub_dir="$1"
  if [ -f "$stub_dir/.sleep_durations" ]; then
    cat "$stub_dir/.sleep_durations"
  else
    printf ''
  fi
}

# run_sr <scratch> <stub_dir> [args...] -- invokes sapience-retrieve.sh with the stub curl/sleep
# shadowing PATH (STUB_DIR exported so both stubs resolve their recorder files) and a fixed
# SAPIENCE_TOKEN so host/token resolution always succeeds.
run_sr() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" STUB_DIR="$stub_dir" SAPIENCE_TOKEN="test-token-fixture" \
    bash "$scratch/.claude/scripts/sapience-retrieve.sh" "$@"
}

# =====================================================================================
# Case 1: a 503 body (the measured Sapience-starting shape) yields the genuine-failure exit
# code (2) with the HTTP status and the body excerpt on stderr.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_CODE=503 CURL_STUB_BODY='{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 15, "db_mb": 0}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(1) 503 body: genuine-failure exit code 2"
  else
    common_test_fail "(1) 503 body: genuine-failure exit code 2" "got rc=$rc"
  fi
  if [ -z "$out" ]; then
    common_test_pass "(1) 503 body: empty stdout"
  else
    common_test_fail "(1) 503 body: empty stdout" "stdout=$out"
  fi
  if echo "$err" | grep -q "503" && echo "$err" | grep -q "your Sapience is starting"; then
    common_test_pass "(1) 503 body: stderr carries the HTTP status and the body excerpt"
  else
    common_test_fail "(1) 503 body: stderr carries the HTTP status and the body excerpt" "err=$err"
  fi
}

# =====================================================================================
# Case 2: a 200 with an empty result set yields the benign exit code (1) with nothing on
# stderr -- the split must not flood the log with a zero-hit search.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_CODE=200 CURL_STUB_BODY='{"results":[]}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"

  if [ "$rc" -eq 1 ]; then
    common_test_pass "(2) zero-hit 200: benign exit code 1"
  else
    common_test_fail "(2) zero-hit 200: benign exit code 1" "got rc=$rc"
  fi
  if [ -z "$out" ]; then
    common_test_pass "(2) zero-hit 200: empty stdout"
  else
    common_test_fail "(2) zero-hit 200: empty stdout" "stdout=$out"
  fi
  if [ -z "$err" ]; then
    common_test_pass "(2) zero-hit 200: nothing on stderr"
  else
    common_test_fail "(2) zero-hit 200: nothing on stderr" "err=$err"
  fi
}

# =====================================================================================
# Case 3: a 200 with a real hit exits 0 and emits the <memory-context> envelope.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(CURL_STUB_CODE=200 CURL_STUB_BODY='{"results":[{"subject":"keybinding fault","predicate":"root cause","object_value":"stale cache","score":0.9}]}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>/dev/null)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(3) 200 with a hit: exit 0"
  else
    common_test_fail "(3) 200 with a hit: exit 0" "got rc=$rc"
  fi
  if echo "$out" | grep -q "<memory-context>" && echo "$out" | grep -q "keybinding fault"; then
    common_test_pass "(3) 200 with a hit: emits the memory-context envelope"
  else
    common_test_fail "(3) 200 with a hit: emits the memory-context envelope" "out=$out"
  fi
}

# =====================================================================================
# Case 4: a curl transport failure yields the genuine-failure exit code (2).
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_EXIT=7 \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(4) curl transport failure: genuine-failure exit code 2"
  else
    common_test_fail "(4) curl transport failure: genuine-failure exit code 2" "got rc=$rc"
  fi
  if [ -z "$out" ]; then
    common_test_pass "(4) curl transport failure: empty stdout"
  else
    common_test_fail "(4) curl transport failure: empty stdout" "stdout=$out"
  fi
  if echo "$err" | grep -qi "transport failure"; then
    common_test_pass "(4) curl transport failure: stderr names the transport failure"
  else
    common_test_fail "(4) curl transport failure: stderr names the transport failure" "err=$err"
  fi
}

# =====================================================================================
# Case 5: a cold-start 503 (starting: true, retry_after: 15) followed by a 200 with a hit
# yields exactly one retry, honors the hinted delay, and succeeds.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(CURL_STUB_CODE_1=503 CURL_STUB_BODY_1='{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 15, "db_mb": 0}' \
    CURL_STUB_CODE_2=200 CURL_STUB_BODY_2='{"results":[{"subject":"keybinding fault","predicate":"root cause","object_value":"stale cache","score":0.9}]}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>/dev/null)"
  rc=$?
  count="$(curl_call_count "$stub_dir")"
  sleeps="$(sleep_durations "$stub_dir")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(5) cold start then success: exit 0"
  else
    common_test_fail "(5) cold start then success: exit 0" "got rc=$rc"
  fi
  if echo "$out" | grep -q "<memory-context>" && echo "$out" | grep -q "keybinding fault"; then
    common_test_pass "(5) cold start then success: populated memory-context"
  else
    common_test_fail "(5) cold start then success: populated memory-context" "out=$out"
  fi
  if [ "$count" = "2" ]; then
    common_test_pass "(5) cold start then success: exactly one retry (curl call count 2)"
  else
    common_test_fail "(5) cold start then success: exactly one retry (curl call count 2)" "count=$count"
  fi
  if [ "$sleeps" = "15" ]; then
    common_test_pass "(5) cold start then success: honored the hinted 15s delay"
  else
    common_test_fail "(5) cold start then success: honored the hinted 15s delay" "sleeps=$sleeps"
  fi
}

# =====================================================================================
# Case 6: a second 503 (still starting: true) after the retry ends in the unchanged
# exit-2 degrade -- never a second retry.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_CODE_1=503 CURL_STUB_BODY_1='{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 15, "db_mb": 0}' \
    CURL_STUB_CODE_2=503 CURL_STUB_BODY_2='{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 15, "db_mb": 0}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"
  count="$(curl_call_count "$stub_dir")"

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(6) second 503 after retry: genuine-failure exit code 2"
  else
    common_test_fail "(6) second 503 after retry: genuine-failure exit code 2" "got rc=$rc"
  fi
  if [ -z "$out" ]; then
    common_test_pass "(6) second 503 after retry: empty stdout"
  else
    common_test_fail "(6) second 503 after retry: empty stdout" "stdout=$out"
  fi
  if echo "$err" | grep -q "503" && echo "$err" | grep -q "your Sapience is starting"; then
    common_test_pass "(6) second 503 after retry: unchanged diagnostic (status + body excerpt)"
  else
    common_test_fail "(6) second 503 after retry: unchanged diagnostic (status + body excerpt)" "err=$err"
  fi
  if [ "$count" = "2" ]; then
    common_test_pass "(6) second 503 after retry: no second retry (curl call count 2)"
  else
    common_test_fail "(6) second 503 after retry: no second retry (curl call count 2)" "count=$count"
  fi
}

# =====================================================================================
# Case 7: a 4xx is never retried.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_CODE=401 CURL_STUB_BODY='{"error": "unauthorized"}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"
  count="$(curl_call_count "$stub_dir")"
  sleeps="$(sleep_durations "$stub_dir")"

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(7) 4xx: genuine-failure exit code 2"
  else
    common_test_fail "(7) 4xx: genuine-failure exit code 2" "got rc=$rc"
  fi
  if [ "$count" = "1" ]; then
    common_test_pass "(7) 4xx: never retried (curl call count 1)"
  else
    common_test_fail "(7) 4xx: never retried (curl call count 1)" "count=$count"
  fi
  if [ -z "$sleeps" ]; then
    common_test_pass "(7) 4xx: no sleep recorded"
  else
    common_test_fail "(7) 4xx: no sleep recorded" "sleeps=$sleeps"
  fi
  if echo "$err" | grep -q "401"; then
    common_test_pass "(7) 4xx: unchanged diagnostic carries the status"
  else
    common_test_fail "(7) 4xx: unchanged diagnostic carries the status" "err=$err"
  fi
}

# =====================================================================================
# Case 8: a 503 with a non-JSON body is never retried (the predicate requires a parseable
# JSON body before it ever inspects `.starting`).
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(CURL_STUB_CODE=503 CURL_STUB_BODY='<html>Service Unavailable</html>' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>"$err_file")"
  rc=$?
  err="$(cat "$err_file")"
  count="$(curl_call_count "$stub_dir")"
  sleeps="$(sleep_durations "$stub_dir")"

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(8) 503 non-JSON body: genuine-failure exit code 2"
  else
    common_test_fail "(8) 503 non-JSON body: genuine-failure exit code 2" "got rc=$rc"
  fi
  if [ "$count" = "1" ]; then
    common_test_pass "(8) 503 non-JSON body: never retried (curl call count 1)"
  else
    common_test_fail "(8) 503 non-JSON body: never retried (curl call count 1)" "count=$count"
  fi
  if [ -z "$sleeps" ]; then
    common_test_pass "(8) 503 non-JSON body: no sleep recorded"
  else
    common_test_fail "(8) 503 non-JSON body: no sleep recorded" "sleeps=$sleeps"
  fi
  if echo "$err" | grep -q "503"; then
    common_test_pass "(8) 503 non-JSON body: unchanged diagnostic carries the status"
  else
    common_test_fail "(8) 503 non-JSON body: unchanged diagnostic carries the status" "err=$err"
  fi
}

# =====================================================================================
# Case 9: a retry_after hint outside [1, 20] is clamped to the ceiling, never honored
# verbatim.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(CURL_STUB_CODE_1=503 CURL_STUB_BODY_1='{"error": "your Sapience is starting, try again in a minute", "starting": true, "retry_after": 9999, "db_mb": 0}' \
    CURL_STUB_CODE_2=200 CURL_STUB_BODY_2='{"results":[{"subject":"keybinding fault","predicate":"root cause","object_value":"stale cache","score":0.9}]}' \
    run_sr "$scratch" "$stub_dir" "diagnosing a keybinding fault" "general" 2>/dev/null)"
  rc=$?
  sleeps="$(sleep_durations "$stub_dir")"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(9) retry_after 9999 clamped: exit 0"
  else
    common_test_fail "(9) retry_after 9999 clamped: exit 0" "got rc=$rc"
  fi
  if [ "$sleeps" = "20" ]; then
    common_test_pass "(9) retry_after 9999 clamped: slept the clamp ceiling (20), not 9999"
  else
    common_test_fail "(9) retry_after 9999 clamped: slept the clamp ceiling (20), not 9999" "sleeps=$sleeps"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
