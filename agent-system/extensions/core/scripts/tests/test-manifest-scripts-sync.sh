#!/usr/bin/env bash
# test-manifest-scripts-sync.sh - Fixture-driven regression suite for sync-manifest-scripts.sh
# (--check/--write) AND for check-extension-docs.sh's Rule Q (check_undeclared_scripts), whose
# only prior coverage was indirect (the real repo's own extensions happening to be clean).
# This is Rule Q's first dedicated fixture.
#
# Structural model: test-index-entries-schema.sh (pass()/fail() counters, mktemp -d workdir with
# a trap EXIT cleanup, a synthetic EXT_DIR holding ONLY fixture extensions, REPO_ROOT/EXT_DIR
# always passed explicitly to the scripts under test rather than left to auto-detect). Unlike
# that suite, two scripts are under test here (sync-manifest-scripts.sh and, for its own first-
# ever fixture, check-extension-docs.sh's Rule Q), both resolved SOURCE-STORE-first for the same
# reason that suite documents: this suite validates logic as it is developed in the source
# store, and preferring a deployed copy would silently test stale logic.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (a script under test was not found at any candidate path, or jq is missing).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SYNC_CANDIDATES=(
  "$SCRIPT_DIR/../sync-manifest-scripts.sh"
  "$REPO_ROOT/.claude/scripts/sync-manifest-scripts.sh"
)
SYNC_SCRIPT=""
for candidate in "${SYNC_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SYNC_SCRIPT="$candidate"
    break
  fi
done
if [[ -z "$SYNC_SCRIPT" ]]; then
  echo "ERROR: sync-manifest-scripts.sh not found at any of:" >&2
  for candidate in "${SYNC_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

DOCS_CANDIDATES=(
  "$SCRIPT_DIR/../check-extension-docs.sh"
  "$REPO_ROOT/.claude/scripts/check-extension-docs.sh"
)
DOCS_SCRIPT=""
for candidate in "${DOCS_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    DOCS_SCRIPT="$candidate"
    break
  fi
done
if [[ -z "$DOCS_SCRIPT" ]]; then
  echo "ERROR: check-extension-docs.sh not found at any of:" >&2
  for candidate in "${DOCS_CANDIDATES[@]}"; do
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
FIXTURE_REPO="$WORKDIR/repo"
mkdir -p "$FIXTURE_REPO"

# A real git repo is required: both scripts under test resolve tracked files via
# `git ls-files`, and sync-manifest-scripts.sh's REPO_ROOT-bypass path needs a `.git` to exist
# somewhere sensible even though it is never walked for this suite's EXT_DIR-scoped calls.
( cd "$FIXTURE_REPO" && git init -q && git config user.email t@t.com && git config user.name t )

write_manifest() {
  # Usage: write_manifest <scripts_json_array_literal>
  cat > "$FIXTURE/manifest.json" <<EOF
{
  "name": "fixture",
  "version": "0.0.1",
  "provides": {
    "scripts": $1
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md"
    }
  }
}
EOF
}

# EXT_DIR lives INSIDE $FIXTURE_REPO so `git ls-files` (run with -C "$REPO_ROOT", i.e.
# -C "$FIXTURE_REPO") returns REPO_ROOT-relative paths that both scripts under test can
# prefix-strip correctly against this fixture's own ext_rel.
FIXTURE_EXT_DIR="$FIXTURE_REPO/extensions"
FIXTURE="$FIXTURE_EXT_DIR/fixture"
mkdir -p "$FIXTURE/context" "$FIXTURE/scripts/tests" "$FIXTURE/scripts/deprecated"
printf '# fixture\n' > "$FIXTURE/README.md"
printf 'line\n' > "$FIXTURE/EXTENSION.md"
cat > "$FIXTURE/index-entries.json" <<'EOF'
{
  "entries": []
}
EOF
: > "$FIXTURE/scripts/state-write.sh"
: > "$FIXTURE/scripts/system-defect-record.sh"
: > "$FIXTURE/scripts/sync.sh"
: > "$FIXTURE/scripts/zzz-last.sh"
: > "$FIXTURE/scripts/deprecated/old.sh"

write_manifest '[
      "state-write.sh",
      "system-defect-record.sh"
    ]'

( cd "$FIXTURE_REPO" && git add extensions/fixture && git commit -q -m fixture )

run_sync() {
  local mode="$1"
  SYNC_OUTPUT="$(REPO_ROOT="$FIXTURE_REPO" EXT_DIR="$FIXTURE_EXT_DIR" bash "$SYNC_SCRIPT" "$mode" 2>&1)"
  SYNC_EXIT=$?
}

# ── --check: names both missing files, exits nonzero ───────────────────────────────────────────
run_sync --check
if [[ "$SYNC_EXIT" -ne 0 ]]; then
  pass "sync-manifest-scripts.sh --check exits nonzero on an unregistered-script fixture"
else
  fail "sync-manifest-scripts.sh --check exited 0 on an unregistered-script fixture"
fi
if grep -q "script file on disk NOT in provides.scripts: scripts/sync.sh" <<< "$SYNC_OUTPUT"; then
  pass "sync-manifest-scripts.sh --check names scripts/sync.sh"
else
  fail "sync-manifest-scripts.sh --check did not name scripts/sync.sh (output: $SYNC_OUTPUT)"
fi
if grep -q "script file on disk NOT in provides.scripts: scripts/zzz-last.sh" <<< "$SYNC_OUTPUT"; then
  pass "sync-manifest-scripts.sh --check names scripts/zzz-last.sh"
else
  fail "sync-manifest-scripts.sh --check did not name scripts/zzz-last.sh"
fi
if grep -q "deprecated/old.sh" <<< "$SYNC_OUTPUT"; then
  fail "sync-manifest-scripts.sh --check incorrectly flagged deprecated/old.sh"
else
  pass "sync-manifest-scripts.sh --check exempts deprecated/old.sh"
fi

# ── --check on a fully-declared fixture: exits 0 ────────────────────────────────────────────────
write_manifest '[
      "state-write.sh",
      "sync.sh",
      "system-defect-record.sh",
      "zzz-last.sh"
    ]'
run_sync --check
if [[ "$SYNC_EXIT" -eq 0 ]]; then
  pass "sync-manifest-scripts.sh --check exits 0 when every tracked script is declared"
else
  fail "sync-manifest-scripts.sh --check exited nonzero on a fully-declared fixture (output: $SYNC_OUTPUT)"
fi

# ── --write: adds exactly the missing entries, alphabetical position, full-file diff ───────────
write_manifest '[
      "state-write.sh",
      "system-defect-record.sh"
    ]'
run_sync --write
AFTER_WRITE="$(cat "$FIXTURE/manifest.json")"
if jq -e . <<< "$AFTER_WRITE" > /dev/null 2>&1; then
  pass "sync-manifest-scripts.sh --write leaves valid JSON"
else
  fail "sync-manifest-scripts.sh --write produced invalid JSON"
fi
EXPECTED_AFTER='{
  "name": "fixture",
  "version": "0.0.1",
  "provides": {
    "scripts": [
      "state-write.sh",
      "sync.sh",
      "system-defect-record.sh",
      "zzz-last.sh"
    ]
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md"
    }
  }
}'
if [[ "$AFTER_WRITE" == "$EXPECTED_AFTER" ]]; then
  pass "sync-manifest-scripts.sh --write inserts exactly the two missing entries, alphabetically, and changes nothing else"
else
  fail "sync-manifest-scripts.sh --write produced unexpected content:
--- expected ---
$EXPECTED_AFTER
--- actual ---
$AFTER_WRITE"
fi
run_sync --check
if [[ "$SYNC_EXIT" -eq 0 ]]; then
  pass "sync-manifest-scripts.sh --check is clean immediately after --write (idempotent repair)"
else
  fail "sync-manifest-scripts.sh --check still reports a gap after --write"
fi

# ── --write on a non-jq-canonical manifest leaves unrelated formatting intact ───────────────────
cat > "$FIXTURE/manifest.json" <<'EOF'
{
  "name": "fixture",
  "version": "0.0.1",
  "provides": {
    "scripts": [
      "state-write.sh",
      "system-defect-record.sh"
    ],
    "hooks": ["a-compact-array.sh", "left-exactly-as-is.sh"]
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md"
    }
  }
}
EOF
run_sync --write
if grep -q '"hooks": \["a-compact-array.sh", "left-exactly-as-is.sh"\]' "$FIXTURE/manifest.json"; then
  pass "sync-manifest-scripts.sh --write leaves an unrelated compact array (non-jq-canonical formatting) untouched"
else
  fail "sync-manifest-scripts.sh --write reformatted an unrelated array it should not have touched"
fi
if grep -q '"sync.sh"' "$FIXTURE/manifest.json" && grep -q '"zzz-last.sh"' "$FIXTURE/manifest.json"; then
  pass "sync-manifest-scripts.sh --write still repaired provides.scripts on the non-canonical manifest"
else
  fail "sync-manifest-scripts.sh --write did not repair provides.scripts on the non-canonical manifest"
fi

# ── declared-but-absent: reported, never auto-removed ───────────────────────────────────────────
write_manifest '[
      "ghost-entry.sh",
      "state-write.sh",
      "sync.sh",
      "system-defect-record.sh",
      "zzz-last.sh"
    ]'
run_sync --check
if grep -q "declares 'scripts/ghost-entry.sh' but no such file is tracked on disk" <<< "$SYNC_OUTPUT"; then
  pass "sync-manifest-scripts.sh --check reports a declared-but-absent entry"
else
  fail "sync-manifest-scripts.sh --check did not report the declared-but-absent entry (output: $SYNC_OUTPUT)"
fi
if [[ "$SYNC_EXIT" -ne 0 ]]; then
  pass "sync-manifest-scripts.sh --check exits nonzero on a declared-but-absent gap alone"
else
  fail "sync-manifest-scripts.sh --check exited 0 despite a declared-but-absent gap"
fi
run_sync --write
if grep -q '"ghost-entry.sh"' "$FIXTURE/manifest.json"; then
  pass "sync-manifest-scripts.sh --write never auto-removes a declared-but-absent entry"
else
  fail "sync-manifest-scripts.sh --write incorrectly removed a declared-but-absent entry"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Rule Q (check-extension-docs.sh / check_undeclared_scripts) -- its own first fixture coverage.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
write_manifest '[
      "state-write.sh",
      "system-defect-record.sh"
    ]'
RULEQ_OUTPUT="$(cd "$FIXTURE_REPO" && REPO_ROOT="$FIXTURE_REPO" EXT_DIR="$FIXTURE_EXT_DIR" bash "$DOCS_SCRIPT" --quiet 2>&1)"
RULEQ_EXIT=$?
if grep -qF "  FAIL: script file on disk NOT in provides.scripts: scripts/sync.sh" <<< "$RULEQ_OUTPUT"; then
  pass "Rule Q (check-extension-docs.sh) emits the exact FAIL text for an unregistered script"
else
  fail "Rule Q did not emit the expected FAIL text (output: $RULEQ_OUTPUT)"
fi
if [[ "$RULEQ_EXIT" -ne 0 ]]; then
  pass "Rule Q exits nonzero on the unregistered-script fixture"
else
  fail "Rule Q exited 0 despite the unregistered-script fixture"
fi
if grep -qF "repair: bash scripts/sync-manifest-scripts.sh --write" <<< "$RULEQ_OUTPUT"; then
  pass "Rule Q's repair-pointer line is present alongside its FAIL line"
else
  fail "Rule Q's repair-pointer line is missing from its output"
fi

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
