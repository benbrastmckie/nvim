#!/usr/bin/env bash
# test-index-entries-schema.sh - Fixture-driven regression suite for check-extension-docs.sh's
# Rule T (check_index_entries_schema) and Rule U (check_extension_md_length).
#
# Structural model: test-validate-no-task-references.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass
# and exit 1 on any-fail). Unlike that suite, this one drives check-extension-docs.sh as a real
# subprocess against a single synthetic fixture extension (EXT_DIR pointed at a tree containing
# ONLY the fixture), rather than sourcing a library directly -- Rule T/U are check-extension-
# docs.sh's own per-extension checks, not standalone library functions.
#
# check-extension-docs.sh resolution DELIBERATELY prefers the SOURCE-STORE sibling copy over
# a deployed .claude/scripts/ copy -- the opposite priority from the deploy-tree-first /
# source-store-fallback pattern other tests in this directory use for stable, rarely-edited
# libraries. This suite exists specifically to validate Rule T/U as they are developed in the
# source store; a deployed copy is regenerated only by a later, separate deploy step, so
# preferring it here would silently test stale logic (confirmed empirically: preferring deploy
# first here made every assertion fail against a source-store change not yet redeployed). REPO_ROOT
# is always passed explicitly to the script under test (the sanctioned override -- see
# check-extension-docs.sh's own REPO_ROOT auto-detect comment), never left to auto-detect, since
# this test is expected to run directly from the source store per this task's own Risk table.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (script under test not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$SCRIPT_DIR/../check-extension-docs.sh"
  "$REPO_ROOT/.claude/scripts/check-extension-docs.sh"
)
DOCS_SCRIPT=""
for candidate in "${SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    DOCS_SCRIPT="$candidate"
    break
  fi
done
if [[ -z "$DOCS_SCRIPT" ]]; then
  echo "ERROR: check-extension-docs.sh not found at any of:" >&2
  for candidate in "${SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixture JSON and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

FIXTURE_EXT_DIR="$WORKDIR/extensions"
FIXTURE="$FIXTURE_EXT_DIR/fixture"
mkdir -p "$FIXTURE/context"

cat > "$FIXTURE/manifest.json" << 'EOF'
{
  "name": "fixture",
  "version": "0.0.1",
  "provides": {},
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md"
    }
  }
}
EOF

# One conformant entry plus five Rule T positive-case entries, each isolating exactly one
# violation so a failing assertion below points at a single predicate branch.
cat > "$FIXTURE/index-entries.json" << 'EOF'
{
  "entries": [
    {
      "path": "domain/conformant.md",
      "domain": "core",
      "subdomain": "domain",
      "summary": "A fully conformant entry",
      "line_count": 1,
      "load_when": {
        "agents": ["some-agent"],
        "task_types": ["meta"]
      }
    },
    {
      "path": "domain/has-description.md",
      "domain": "core",
      "subdomain": "domain",
      "description": "A forbidden description field",
      "summary": "Entry with a forbidden description key",
      "line_count": 1,
      "load_when": { "always": true }
    },
    {
      "path": "domain/has-tags.md",
      "domain": "core",
      "subdomain": "domain",
      "summary": "Entry with a forbidden tags key",
      "tags": ["a", "b"],
      "line_count": 1,
      "load_when": { "always": true }
    },
    {
      "path": "domain/has-languages.md",
      "domain": "core",
      "subdomain": "domain",
      "summary": "Entry with a forbidden load_when.languages key",
      "line_count": 1,
      "load_when": { "languages": ["nix"] }
    },
    {
      "path": "domain/missing-line-count.md",
      "domain": "core",
      "subdomain": "domain",
      "summary": "Entry missing line_count"
    },
    {
      "path": "domain/bad-domain.md",
      "domain": "not-a-real-domain",
      "subdomain": "domain",
      "summary": "Entry with an out-of-enum domain",
      "line_count": 1,
      "load_when": { "always": true }
    }
  ]
}
EOF

# Source files backing the fixture entries (line_count accuracy is Rule R's concern, not this
# suite's -- create matching files so Rule R stays silent and does not obscure Rule T output).
mkdir -p "$FIXTURE/context/domain"
for f in conformant has-description has-tags has-languages bad-domain; do
  printf 'line1\n' > "$FIXTURE/context/domain/${f}.md"
done

# README.md is required by check_file but irrelevant to Rule T/U; keep it minimal.
printf '# fixture\n' > "$FIXTURE/README.md"

# run_check <extension_md_line_count> <gate_mode>
# Writes EXTENSION.md with exactly N lines, runs check-extension-docs.sh against the fixture-
# only EXT_DIR, and captures combined stdout+stderr plus the exit code.
run_check() {
  local ext_md_lines="$1" gate_mode="${2:-advisory}"
  : > "$FIXTURE/EXTENSION.md"
  for ((i = 0; i < ext_md_lines; i++)); do
    printf 'line\n' >> "$FIXTURE/EXTENSION.md"
  done
  # Deliberately NOT --quiet: ADVISORY lines are emitted via info(), which --quiet silences,
  # and the whole point of these assertions is to inspect ADVISORY output text.
  SCHEMA_CONFORMANCE_GATE_MODE="$gate_mode" EXT_DIR="$FIXTURE_EXT_DIR" REPO_ROOT="$REPO_ROOT" \
    bash "$DOCS_SCRIPT"
  LAST_EXIT=$?
}

OUTPUT="$(run_check 5 advisory; echo "EXIT:$LAST_EXIT")"
LAST_EXIT="${OUTPUT##*EXIT:}"
OUTPUT="${OUTPUT%EXIT:*}"

# Rule T positive cases: one ADVISORY line naming the entry, for each isolated violation.
if grep -q "Rule T:.*has-description\.md.*forbidden key 'description'" <<< "$OUTPUT"; then
  pass "Rule T fires on a present 'description' key"
else
  fail "Rule T did not fire on a present 'description' key"
fi

if grep -q "Rule T:.*has-tags\.md.*forbidden key 'tags'" <<< "$OUTPUT"; then
  pass "Rule T fires on a present 'tags' key"
else
  fail "Rule T did not fire on a present 'tags' key"
fi

if grep -q "Rule T:.*has-languages\.md.*forbidden load_when key 'languages'" <<< "$OUTPUT"; then
  pass "Rule T fires on a present load_when.languages key"
else
  fail "Rule T did not fire on a present load_when.languages key"
fi

if grep -q "Rule T:.*missing-line-count\.md.*missing the line_count key" <<< "$OUTPUT"; then
  pass "Rule T fires on a missing line_count key"
else
  fail "Rule T did not fire on a missing line_count key"
fi

if grep -q "Rule T:.*bad-domain\.md.*domain 'not-a-real-domain' outside the enum" <<< "$OUTPUT"; then
  pass "Rule T fires on a domain value outside the enum"
else
  fail "Rule T did not fire on a domain value outside the enum"
fi

# Rule T negative case: the conformant entry must never be named in a Rule T line.
if grep -q "Rule T:.*conformant\.md" <<< "$OUTPUT"; then
  fail "Rule T incorrectly fired on the fully conformant entry"
else
  pass "Rule T stays silent on the fully conformant entry"
fi

# Rule U positive case: 61 lines exceeds the limit.
OUTPUT_61="$(run_check 61 advisory; echo "EXIT:$LAST_EXIT")"
OUTPUT_61="${OUTPUT_61%EXIT:*}"
if grep -q "Rule U: EXTENSION.md is 61 lines, exceeding the 60-line limit" <<< "$OUTPUT_61"; then
  pass "Rule U fires on a 61-line EXTENSION.md"
else
  fail "Rule U did not fire on a 61-line EXTENSION.md"
fi

# Rule U negative case: exactly 60 lines is the limit, not a violation ("exceeds 60", not
# "reaches 60" -- the research recorded the formal extension at exactly 60L as OK).
OUTPUT_60="$(run_check 60 advisory; echo "EXIT:$LAST_EXIT")"
OUTPUT_60="${OUTPUT_60%EXIT:*}"
if grep -q "Rule U:" <<< "$OUTPUT_60"; then
  fail "Rule U incorrectly fired on a 60-line EXTENSION.md"
else
  pass "Rule U stays silent on a 60-line EXTENSION.md"
fi

# Severity wiring: SCHEMA_CONFORMANCE_GATE_MODE=hard must turn these into a non-zero exit,
# pinning the severity switch, not just the message text.
run_check 61 hard
if [[ "$LAST_EXIT" -ne 0 ]]; then
  pass "SCHEMA_CONFORMANCE_GATE_MODE=hard yields a non-zero exit on the fixture"
else
  fail "SCHEMA_CONFORMANCE_GATE_MODE=hard did not yield a non-zero exit on the fixture"
fi

echo
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
