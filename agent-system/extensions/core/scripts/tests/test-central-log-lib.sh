#!/usr/bin/env bash
# test-central-log-lib.sh - Regression suite for scripts/lib/central-log-lib.sh: the cross-repo
# error-log promotion algorithm shared by issue-record.sh and events-append.sh.
#
# Follows context/standards/shell-script-testing.md and this directory's own house convention:
# common_test_pass/_fail/_info from lib/common.sh, PASSED/FAILED counters, a mktemp -d workdir
# with a trap EXIT cleanup, and fixture-driven synthetic repositories rather than the live repo.
#
# Fixture model: central_log_promote resolves the WRITING repository's root from its own
# deployed location (<repo_root>/.claude/scripts/lib/central-log-lib.sh, via common_repo_root
# levels=3), so every fixture below places the library (and lib/common.sh, which it sources
# internally) at that exact relative depth inside a synthetic "writing" repo, mirroring
# test-issue-record.sh's own <scratch>/.claude/scripts/... convention.
#
# Classification: unit (asserted via scripts/tests/suite-classification.data) -- this suite
# spawns none of the three heavyweight deploy/verification/test-harness entry points; every case
# runs entirely inside synthetic mktemp -d fixtures.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required file is missing,
# reported loudly rather than silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

LIB_SOURCE="$SRC_SCRIPTS_DIR/lib/central-log-lib.sh"
COMMON_SOURCE="$SRC_SCRIPTS_DIR/lib/common.sh"
if [ ! -f "$LIB_SOURCE" ]; then
  echo "ERROR: test-central-log-lib.sh cannot run -- missing required file: $LIB_SOURCE" >&2
  exit 1
fi
if [ ! -f "$COMMON_SOURCE" ]; then
  echo "ERROR: test-central-log-lib.sh cannot run -- missing required file: $COMMON_SOURCE" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_writing_repo <base> -- creates <base>/writing/.claude/scripts/lib/{central-log-lib.sh,
#     common.sh} and a git repo at <base>/writing. Echoes the writing repo's absolute path. ---
build_writing_repo() {
  local base="$1" writing
  writing="$base/writing"
  mkdir -p "$writing/.claude/scripts/lib"
  cp "$LIB_SOURCE" "$writing/.claude/scripts/lib/central-log-lib.sh"
  cp "$COMMON_SOURCE" "$writing/.claude/scripts/lib/common.sh"
  git -C "$writing" init -q
  git -C "$writing" config user.email "test@example.com"
  git -C "$writing" config user.name "test"
  echo "$writing"
}

# --- build_owning_repo <base> [--no-specs] -- creates <base>/owning as a real git repo with
#     agent-system/extensions/core/ (the resolvable source_dir target) and, unless --no-specs is
#     passed, a specs/ directory. Echoes the owning repo's absolute path. ---
build_owning_repo() {
  local base="$1" with_specs="${2:-}" owning
  owning="$base/owning"
  mkdir -p "$owning/agent-system/extensions/core"
  git -C "$owning" init -q
  git -C "$owning" config user.email "test@example.com"
  git -C "$owning" config user.name "test"
  if [ "$with_specs" != "--no-specs" ]; then
    mkdir -p "$owning/specs"
  fi
  echo "$owning"
}

# --- wire_extensions_json <writing> <source_dir> -- writes <writing>/.claude-extensions.json
#     pointing extension "core" at <source_dir>. ---
wire_extensions_json() {
  local writing="$1" source_dir="$2"
  cat > "$writing/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$source_dir"}}}
EOF
}

# --- call_promote <writing> <origin_store> <json_line> -- sources the library from <writing>'s
#     deployed location and calls central_log_promote, in a fresh bash subprocess so each case
#     starts from a clean function/variable namespace. Prints nothing; returns the function's
#     own exit code. ---
call_promote() {
  local writing="$1" origin_store="$2" json_line="$3"
  bash -c '
    source "$1/.claude/scripts/lib/central-log-lib.sh"
    central_log_promote "$2" "$3"
  ' _ "$writing" "$origin_store" "$json_line"
}

# =====================================================================================
# Case 1: owning-repo skip -- writing repo's .claude-extensions.json source_dir resolves to a
# git toplevel equal to the writing repo's own root. Nothing written, exit 0.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  mkdir -p "$writing/agent-system/extensions/core"
  wire_extensions_json "$writing" "$writing/agent-system/extensions/core"

  call_promote "$writing" "issues.jsonl" '{"kind":"issue","what_happened":"self"}'
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "owning-repo skip: exit 0"
  else
    common_test_fail "owning-repo skip: exit 0" "got rc=$rc"
  fi
  if [ ! -f "$writing/specs/central-errors.jsonl" ]; then
    common_test_pass "owning-repo skip: no central log file created"
  else
    common_test_fail "owning-repo skip: no central log file created" "file exists"
  fi
}

# =====================================================================================
# Case 2: successful foreign-repo promotion -- issues.jsonl, kind=issue, lands exactly one
# well-formed envelope line in the owning repo's central log.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"

  call_promote "$writing" "issues.jsonl" '{"kind":"issue","what_happened":"foreign promotion"}'
  rc=$?
  central_log="$owning/specs/central-errors.jsonl"
  if [ "$rc" -eq 0 ] && [ -f "$central_log" ]; then
    common_test_pass "foreign promotion: exit 0 and central log created"
  else
    common_test_fail "foreign promotion: exit 0 and central log created" "rc=$rc file_exists=$([ -f "$central_log" ] && echo yes || echo no)"
  fi
  line_count="$(wc -l < "$central_log" 2>/dev/null || echo 0)"
  if [ "$line_count" -eq 1 ]; then
    common_test_pass "foreign promotion: exactly one line written"
  else
    common_test_fail "foreign promotion: exactly one line written" "line_count=$line_count"
  fi
  envelope="$(cat "$central_log" 2>/dev/null)"
  if echo "$envelope" | jq -e '.central_id and .recorded_at and .origin_repo and (.origin_store=="issues.jsonl") and (.entry.kind=="issue")' >/dev/null 2>&1; then
    common_test_pass "foreign promotion: envelope carries all required fields"
  else
    common_test_fail "foreign promotion: envelope carries all required fields" "$envelope"
  fi
  if echo "$envelope" | jq -e --arg wr "$(cd "$writing" && pwd)" '.origin_repo == $wr' >/dev/null 2>&1; then
    common_test_pass "foreign promotion: origin_repo is the writing repo's own root"
  else
    common_test_fail "foreign promotion: origin_repo is the writing repo's own root" "$envelope"
  fi
}

# =====================================================================================
# Case 3: kind=win is filtered -- writes nothing.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"

  call_promote "$writing" "issues.jsonl" '{"kind":"win","what_happened":"a win, not promoted"}'
  rc=$?
  central_log="$owning/specs/central-errors.jsonl"
  if [ "$rc" -eq 0 ] && [ ! -f "$central_log" ]; then
    common_test_pass "kind=win filter: exit 0, nothing written"
  else
    common_test_fail "kind=win filter: exit 0, nothing written" "rc=$rc file_exists=$([ -f "$central_log" ] && echo yes || echo no)"
  fi
}

# =====================================================================================
# Case 4: events.jsonl, category != blocker is filtered -- writes nothing.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"

  call_promote "$writing" "events.jsonl" '{"category":"lifecycle","what_happened":"not a blocker"}'
  rc=$?
  central_log="$owning/specs/central-errors.jsonl"
  if [ "$rc" -eq 0 ] && [ ! -f "$central_log" ]; then
    common_test_pass "events non-blocker filter: exit 0, nothing written"
  else
    common_test_fail "events non-blocker filter: exit 0, nothing written" "rc=$rc file_exists=$([ -f "$central_log" ] && echo yes || echo no)"
  fi

  call_promote "$writing" "events.jsonl" '{"category":"blocker","what_happened":"a genuine blocker"}'
  rc=$?
  if [ "$rc" -eq 0 ] && [ -f "$central_log" ]; then
    common_test_pass "events blocker promotion: exit 0 and central log created"
  else
    common_test_fail "events blocker promotion: exit 0 and central log created" "rc=$rc file_exists=$([ -f "$central_log" ] && echo yes || echo no)"
  fi
}

# =====================================================================================
# Case 5: missing <owning>/specs directory -- writes nothing, returns 0, never bootstraps specs/.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base" "--no-specs")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"

  call_promote "$writing" "issues.jsonl" '{"kind":"issue","what_happened":"no specs dir"}'
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "missing owning specs/: exit 0"
  else
    common_test_fail "missing owning specs/: exit 0" "got rc=$rc"
  fi
  if [ ! -d "$owning/specs" ]; then
    common_test_pass "missing owning specs/: never bootstrapped"
  else
    common_test_fail "missing owning specs/: never bootstrapped" "specs/ was created"
  fi
}

# =====================================================================================
# Case 6: unwritable target -- owning specs/ exists but is not writable. Exit 0, nothing crashes.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"
  chmod 555 "$owning/specs"

  call_promote "$writing" "issues.jsonl" '{"kind":"issue","what_happened":"unwritable target"}'
  rc=$?
  chmod 755 "$owning/specs"
  if [ "$rc" -eq 0 ]; then
    common_test_pass "unwritable target: exit 0, no crash"
  else
    common_test_fail "unwritable target: exit 0, no crash" "got rc=$rc"
  fi
  if [ ! -f "$owning/specs/central-errors.jsonl" ]; then
    common_test_pass "unwritable target: nothing written"
  else
    common_test_fail "unwritable target: nothing written" "file exists despite unwritable dir"
  fi
}

# =====================================================================================
# Case 7: rotation fires at the line ceiling -- prior generation present at .jsonl.1 afterward.
# =====================================================================================
{
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  writing="$(build_writing_repo "$base")"
  owning="$(build_owning_repo "$base")"
  wire_extensions_json "$writing" "$owning/agent-system/extensions/core"

  central_log="$owning/specs/central-errors.jsonl"
  seq 1 20000 | awk '{print "{\"n\":"$1"}"}' > "$central_log"
  pre_count="$(wc -l < "$central_log")"

  call_promote "$writing" "issues.jsonl" '{"kind":"issue","what_happened":"rotation trigger"}'
  rc=$?
  post_count="$(wc -l < "$central_log" 2>/dev/null || echo 0)"
  prior_gen="$central_log.1"
  prior_count="$(wc -l < "$prior_gen" 2>/dev/null || echo 0)"

  if [ "$rc" -eq 0 ] && [ -f "$prior_gen" ] && [ "$prior_count" -eq "$pre_count" ]; then
    common_test_pass "rotation: prior generation present with the pre-rotation line count"
  else
    common_test_fail "rotation: prior generation present with the pre-rotation line count" "rc=$rc prior_count=$prior_count pre_count=$pre_count"
  fi
  if [ "$post_count" -eq 1 ]; then
    common_test_pass "rotation: fresh file holds exactly the one newly-appended line"
  else
    common_test_fail "rotation: fresh file holds exactly the one newly-appended line" "post_count=$post_count"
  fi
}

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
