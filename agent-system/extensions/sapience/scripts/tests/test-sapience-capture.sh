#!/usr/bin/env bash
# test-sapience-capture.sh - Regression suite for sapience-retrieve.sh's exit-code split: a
# genuine transport/HTTP failure (exit 2, with the HTTP status and a length-bounded body excerpt
# on stderr) versus a benign no-match (exit 1, nothing on stderr, exactly as before) versus
# success (exit 0, the <memory-context> envelope on stdout).
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup. `curl` is
# PATH-shadowed by a minimal inline stub (the same technique
# literature/scripts/tests/curl-stub.sh establishes: install a `curl` executable in a scratch
# directory prepended to PATH, dispatched by env vars, since the script under test calls bare
# `curl`, never an absolute path or `command curl`).
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

# --- build_curl_stub -- installs a minimal PATH-shadowing curl stub into a fresh scratch
#     directory (under $TOP_WORKDIR), dispatched by CURL_STUB_CODE / CURL_STUB_BODY /
#     CURL_STUB_EXIT env vars. Echoes the directory to prepend to PATH. ---
build_curl_stub() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  cat > "$stub_dir/curl" <<'STUB'
#!/usr/bin/env bash
code="${CURL_STUB_CODE:-200}"
body="${CURL_STUB_BODY:-{\}}"
exitcode="${CURL_STUB_EXIT:-0}"
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

# run_sr <scratch> <stub_dir> [args...] -- invokes sapience-retrieve.sh with the stub curl
# shadowing PATH and a fixed SAPIENCE_TOKEN so host/token resolution always succeeds.
run_sr() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" SAPIENCE_TOKEN="test-token-fixture" \
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

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
