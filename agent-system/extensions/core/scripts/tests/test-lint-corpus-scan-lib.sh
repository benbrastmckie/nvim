#!/usr/bin/env bash
# test-lint-corpus-scan-lib.sh - Fixture-driven regression suite for
# scripts/lib/lint-corpus-scan-lib.sh, the shared "collect files to scan" wrapper extracted from
# six of the seven-member lint cluster's byte-identical copy-pasted call-site block.
#
# Cases:
#   Single definition  -- the extracted function has EXACTLY ONE definition under
#                     agent-system/extensions, and no migrated lint file still carries its own
#                     inline copy of the collection wrapper.
#   No shell-option leakage -- sourcing this file must not change the calling shell's `$-` or
#                     `set -o` state (matches lib/common.sh's own contract).
#   Fast path (shared corpus cache)   -- when GATE_SHARED_CORPUS_FILE/_ROOT are set and the scan
#                     is exactly the unmodified default, the function returns the cached corpus
#                     filtered by the given glob patterns, matching the inline block's behavior.
#   Fallback path (find-based)        -- an explicit scan-path argument (standalone invocation,
#                     or a custom fixture root) falls through to a `find`-based walk, matching
#                     the inline block's behavior exactly, including a single-file scan path.
#   Missing-path error  -- a scan path that is neither a file nor a directory returns non-zero
#                     and reports the failing path, matching the inline block's `exit 2` contract.
#   Usage error         -- a missing `--` separator, or zero glob patterns, returns non-zero.
#   Behavioral equivalence -- the extracted helper returns the SAME file list the inline block
#                     used to produce, verified against a synthesized fixture tree.
#
# Structural model: tests/test-common-lib.sh (pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, `mktemp -d` workdir with a trap EXIT cleanup, exit 0 on all-pass / exit 1 on
# any-fail). This suite sources the library directly rather than driving a subprocess, since the
# library exports a shell function meant to be sourced, not a standalone executable.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (library or lint-cluster source tree not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB="$SCRIPT_DIR/../lib/lint-corpus-scan-lib.sh"
COMMON_LIB="$SCRIPT_DIR/../lib/common.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$LIB" ]; then
  echo "ERROR: shared library lint-corpus-scan-lib.sh not found at $LIB" >&2
  exit 2
fi
if [ ! -f "$COMMON_LIB" ]; then
  echo "ERROR: shared library common.sh not found at $COMMON_LIB" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ── Capture shell-option state BEFORE sourcing ────────────────────────────────
DASH_BEFORE="$-"
SET_O_BEFORE="$(set -o)"

# shellcheck source=/dev/null
source "$COMMON_LIB"
# shellcheck source=/dev/null
source "$LIB"

DASH_AFTER="$-"
SET_O_AFTER="$(set -o)"
if [ "$DASH_BEFORE" = "$DASH_AFTER" ] && [ "$SET_O_BEFORE" = "$SET_O_AFTER" ]; then
  pass "sourcing lint-corpus-scan-lib.sh does not change shell-option state"
else
  fail "sourcing lint-corpus-scan-lib.sh changed shell-option state (before=[$DASH_BEFORE] after=[$DASH_AFTER])"
fi

# =====================================================================
# Single definition: exactly one definition of the extracted function under
# agent-system/extensions, and no lint file still carries its own inline copy of the wrapper.
# =====================================================================
EXT_ROOT="$REPO_ROOT/agent-system/extensions"
if [ -d "$EXT_ROOT" ]; then
  # Anchored to the start of the line (no leading whitespace) so this does not also match this
  # very grep invocation's own quoted string literal inside this test file.
  def_count="$(grep -rcE '^lint_corpus_scan_collect_files\(\) \{' "$EXT_ROOT" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')"
  if [ "$def_count" = "1" ]; then
    pass "lint_corpus_scan_collect_files() has exactly one definition under agent-system/extensions"
  else
    fail "lint_corpus_scan_collect_files() has $def_count definition(s) under agent-system/extensions (expected 1)"
  fi

  # No PHASE-3-MIGRATED lint file still carries its own inline copy of the call-site wrapper (the
  # distinctive guard condition that previously appeared in each copy). Scoped to exactly the two
  # files this phase migrates -- the remaining four cluster members
  # (lint-scoped-commit-boundary.sh, lint-task-lookup-adoption.sh, lint-hook-registration-paths.sh,
  # lint-shellcheck.sh) still legitimately carry the inline wrapper until Phase 5 migrates them;
  # checking the whole scripts/lint/ directory here would be a false positive against those four.
  MIGRATED_LINTS=(
    "$EXT_ROOT/core/scripts/lint/lint-state-writer-boundary.sh"
    "$EXT_ROOT/core/scripts/lint/lint-directory-pathspec-boundary.sh"
  )
  inline_hits="$(grep -l 'SCAN_PATHS\[0\]}" == "${DEFAULT_SCAN:-}" ]] && common_shared_corpus_available' "${MIGRATED_LINTS[@]}" 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$inline_hits" = "0" ]; then
    pass "neither Phase-3-migrated lint file still carries the inline corpus-scan wrapper"
  else
    fail "inline corpus-scan wrapper still present in $inline_hits of the 2 Phase-3-migrated lint file(s)"
  fi
else
  info "agent-system/extensions not found under $REPO_ROOT -- skipping corpus-wide single-definition checks"
fi

# =====================================================================
# Fixture tree used by the remaining cases.
# =====================================================================
FIXTURE_DIR="$WORKDIR/fixture"
mkdir -p "$FIXTURE_DIR/sub"
echo "a" > "$FIXTURE_DIR/a.md"
echo "b" > "$FIXTURE_DIR/sub/b.sh"
echo "c" > "$FIXTURE_DIR/sub/c.txt"

# =====================================================================
# Fallback path (find-based): default scan root, no shared-corpus cache available.
# =====================================================================
unset GATE_SHARED_CORPUS_FILE GATE_SHARED_CORPUS_ROOT
declare -a FOUND=()
DEFAULT_SCAN="$FIXTURE_DIR"
SCAN_PATHS=("$FIXTURE_DIR")
lint_corpus_scan_collect_files FOUND "$DEFAULT_SCAN" '*.md' '*.sh' -- "${SCAN_PATHS[@]}"
rc=$?
sorted_found="$(printf '%s\n' "${FOUND[@]:-}" | sort)"
expected="$FIXTURE_DIR/a.md
$FIXTURE_DIR/sub/b.sh"
if [ "$rc" -eq 0 ] && [ "$sorted_found" = "$expected" ]; then
  pass "fallback path: default scan root returns the matched *.md/*.sh files, excluding *.txt"
else
  fail "fallback path: rc=$rc found=[${FOUND[*]:-}] (expected a.md and sub/b.sh)"
fi

# =====================================================================
# Fallback path: a single-file scan path is returned as-is.
# =====================================================================
declare -a FOUND2=()
lint_corpus_scan_collect_files FOUND2 "$DEFAULT_SCAN" '*.md' '*.sh' -- "$FIXTURE_DIR/a.md"
rc2=$?
if [ "$rc2" -eq 0 ] && [ "${#FOUND2[@]}" -eq 1 ] && [ "${FOUND2[0]}" = "$FIXTURE_DIR/a.md" ]; then
  pass "fallback path: a single-file scan path is returned as-is"
else
  fail "fallback path: single-file case rc=$rc2 found=[${FOUND2[*]:-}]"
fi

# =====================================================================
# Missing-path error: a scan path that is neither a file nor a directory.
# =====================================================================
set +e
# shellcheck disable=SC2034  # nameref out-param: passed by name; these error cases assert on rc only
declare -a FOUND3=()
lint_corpus_scan_collect_files FOUND3 "$DEFAULT_SCAN" '*.md' '*.sh' -- "$FIXTURE_DIR/does-not-exist" 2>"$WORKDIR/missing_stderr"
rc3=$?
set -e 2>/dev/null || true
if [ "$rc3" -eq 2 ] && grep -q "scan path not found: $FIXTURE_DIR/does-not-exist" "$WORKDIR/missing_stderr"; then
  pass "missing-path error: non-existent scan path returns 2 and names the failing path"
else
  fail "missing-path error: rc=$rc3 stderr=$(cat "$WORKDIR/missing_stderr")"
fi

# =====================================================================
# Usage errors: missing '--' separator, and zero glob patterns.
# =====================================================================
set +e
# shellcheck disable=SC2034  # nameref out-param: passed by name; these error cases assert on rc only
declare -a FOUND4=()
lint_corpus_scan_collect_files FOUND4 "$DEFAULT_SCAN" '*.md' '*.sh' "$FIXTURE_DIR" 2>/dev/null
rc4=$?
set -e 2>/dev/null || true
if [ "$rc4" -eq 2 ]; then
  pass "usage error: missing '--' separator returns 2"
else
  fail "usage error: missing '--' separator returned $rc4 (expected 2)"
fi

set +e
# shellcheck disable=SC2034  # nameref out-param: passed by name; these error cases assert on rc only
declare -a FOUND5=()
lint_corpus_scan_collect_files FOUND5 "$DEFAULT_SCAN" -- "$FIXTURE_DIR" 2>/dev/null
rc5=$?
set -e 2>/dev/null || true
if [ "$rc5" -eq 2 ]; then
  pass "usage error: zero glob patterns returns 2"
else
  fail "usage error: zero glob patterns returned $rc5 (expected 2)"
fi

# =====================================================================
# Fast path: GATE_SHARED_CORPUS_FILE/_ROOT set, scan is exactly the unmodified default.
# =====================================================================
CORPUS_FILE="$WORKDIR/shared_corpus_file"
printf 'a.md\0sub/b.sh\0sub/c.txt\0' > "$CORPUS_FILE"
export GATE_SHARED_CORPUS_FILE="$CORPUS_FILE"
export GATE_SHARED_CORPUS_ROOT="$FIXTURE_DIR"

declare -a FOUND6=()
lint_corpus_scan_collect_files FOUND6 "$FIXTURE_DIR" '*.md' '*.sh' -- "$FIXTURE_DIR"
rc6=$?
sorted_found6="$(printf '%s\n' "${FOUND6[@]:-}" | sort)"
if [ "$rc6" -eq 0 ] && [ "$sorted_found6" = "$expected" ]; then
  pass "fast path: shared-corpus cache is used and filtered by the given glob patterns, excluding *.txt"
else
  fail "fast path: rc=$rc6 found=[${FOUND6[*]:-}] (expected a.md and sub/b.sh)"
fi

# Fast path must NOT engage when an explicit (non-default) scan path is given, even with the
# cache available -- must fall through to the find-based walk on the explicit path instead.
EXPLICIT_DIR="$WORKDIR/explicit"
mkdir -p "$EXPLICIT_DIR"
echo "d" > "$EXPLICIT_DIR/d.md"
declare -a FOUND7=()
lint_corpus_scan_collect_files FOUND7 "$FIXTURE_DIR" '*.md' '*.sh' -- "$EXPLICIT_DIR"
rc7=$?
if [ "$rc7" -eq 0 ] && [ "${#FOUND7[@]}" -eq 1 ] && [ "${FOUND7[0]}" = "$EXPLICIT_DIR/d.md" ]; then
  pass "fast path is bypassed for an explicit (non-default) scan path, even with the cache available"
else
  fail "explicit-path-bypasses-fast-path case: rc=$rc7 found=[${FOUND7[*]:-}]"
fi

unset GATE_SHARED_CORPUS_FILE GATE_SHARED_CORPUS_ROOT

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
