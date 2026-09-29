#!/usr/bin/env bash
# test-plan-file-scope-harvest.sh - Fixture-driven regression suite for
# scripts/plan-file-scope-harvest.sh, the harvester that unions every phase's "Files to modify"
# path list in a plan file into a deduplicated JSON array.
#
# Unlike several sibling suites in this directory, plan-file-scope-harvest.sh takes no REPO_ROOT
# dependency (a single positional plan-file argument, no specs/state.json access, no
# deploy-root-guard.sh), so this suite drives the SOURCE-STORE copy directly rather than
# requiring a prior deploy -- there is no bogus-root risk to guard against for a script that
# never derives a root from its own location.
#
# Cases (matching this task's Phase 2 Scope Hypothesis and the research report's four grammar
# wrinkles):
#   1. Colon-outside-bold punctuation form (`**Files to modify**:`).
#   2. Colon-inside-bold punctuation form (`**Files to modify:**`).
#   3. Backtick path with trailing ` - {description}` text (description discarded).
#   4. Indented wrapped continuation line contributes nothing (not a second entry).
#   5. A "none planned" prose sentinel line contributes nothing (not an error).
#   6. Multi-phase union and dedup (same path named in two phases collapses to one entry).
#   7. Zero "Files to modify" occurrences in the whole file returns `[]` with exit 0.
#   8. Missing-file argument exits non-zero.
#   9. Missing argument (usage error) exits non-zero.
#   10. List-item-wrapped field form (`- **Files to modify**:` with indented `  - \`path\`` entries,
#       as plan-format.md's own compact example template renders every field, and as a real local
#       plan under specs/*/plans/ was found to use during this phase's implementation-time
#       verification) is harvested correctly, and the following `- **Verification**:` field's own
#       indented sub-bullets are NOT swept in as bogus path entries.
#
# Structural model: pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d
# workdir with an EXIT-trap cleanup, exit 0 all-pass / 1 any-fail / 2 environment error.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARVESTER="$SCRIPT_DIR/../plan-file-scope-harvest.sh"

if [[ ! -f "$HARVESTER" ]]; then
  echo "ERROR: plan-file-scope-harvest.sh not found at $HARVESTER" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required by this suite (to validate harvested JSON) and is not on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Driving harvester at: $HARVESTER"

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

assert_json_array_eq() {
  # $1 = actual JSON, $2 = expected JSON (both as compact arrays), $3 = case label
  local actual="$1" expected="$2" label="$3"
  if ! echo "$actual" | jq -e 'type == "array"' >/dev/null 2>&1; then
    fail "$label: output is not a valid JSON array: $actual"
    return
  fi
  local norm_actual norm_expected
  norm_actual="$(echo "$actual" | jq -c 'sort')"
  norm_expected="$(echo "$expected" | jq -c 'sort')"
  if [[ "$norm_actual" == "$norm_expected" ]]; then
    pass "$label: harvested set matches expected ($norm_expected)"
  else
    fail "$label: expected $norm_expected, got $norm_actual"
  fi
}

# ── Case 1: colon-outside-bold punctuation form ──────────────────────────────────────────────
FIXTURE_1="$WORKDIR/case1.md"
cat > "$FIXTURE_1" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/foo.sh` - add the thing

**Verification**:
- ok
EOF
OUT_1="$(bash "$HARVESTER" "$FIXTURE_1")"
EXIT_1=$?
assert_json_array_eq "$OUT_1" '["scripts/foo.sh"]' "Case 1 (colon-outside-bold)"
if [[ "$EXIT_1" -eq 0 ]]; then pass "Case 1: exit code 0"; else fail "Case 1: expected exit 0, got $EXIT_1"; fi

# ── Case 2: colon-inside-bold punctuation form ───────────────────────────────────────────────
FIXTURE_2="$WORKDIR/case2.md"
cat > "$FIXTURE_2" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify:**
- `scripts/bar.sh`

**Verification**:
- ok
EOF
OUT_2="$(bash "$HARVESTER" "$FIXTURE_2")"
assert_json_array_eq "$OUT_2" '["scripts/bar.sh"]' "Case 2 (colon-inside-bold)"

# ── Case 3: backtick path with trailing description discarded ───────────────────────────────
FIXTURE_3="$WORKDIR/case3.md"
cat > "$FIXTURE_3" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `path/to/file.md` - add the required field with grammar and consumers subsection

**Verification**:
- ok
EOF
OUT_3="$(bash "$HARVESTER" "$FIXTURE_3")"
assert_json_array_eq "$OUT_3" '["path/to/file.md"]' "Case 3 (description discarded)"
if echo "$OUT_3" | grep -qF ' - '; then
  fail "Case 3: description fragment leaked into harvested output: $OUT_3"
else
  pass "Case 3: no description fragment in harvested output"
fi

# ── Case 4: indented wrapped continuation line contributes nothing ──────────────────────────
FIXTURE_4="$WORKDIR/case4.md"
cat > "$FIXTURE_4" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `path/one.sh` - a longer description that
  wraps onto a continuation line that must
  not be treated as a second entry

**Verification**:
- ok
EOF
OUT_4="$(bash "$HARVESTER" "$FIXTURE_4")"
assert_json_array_eq "$OUT_4" '["path/one.sh"]' "Case 4 (wrapped continuation contributes nothing)"

# ── Case 5: "none planned" prose sentinel contributes nothing, never errors ─────────────────
FIXTURE_5="$WORKDIR/case5.md"
cat > "$FIXTURE_5" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
No files planned for this phase.

**Verification**:
- ok
EOF
OUT_5="$(bash "$HARVESTER" "$FIXTURE_5")"
EXIT_5=$?
assert_json_array_eq "$OUT_5" '[]' "Case 5 (prose sentinel)"
if [[ "$EXIT_5" -eq 0 ]]; then
  pass "Case 5: prose sentinel does not cause a non-zero exit"
else
  fail "Case 5: expected exit 0 for a harmless prose sentinel, got $EXIT_5"
fi

# ── Case 6: multi-phase union and dedup ──────────────────────────────────────────────────────
FIXTURE_6="$WORKDIR/case6.md"
cat > "$FIXTURE_6" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/shared.sh` - initial change
- `scripts/only-in-phase-1.sh`

**Verification**:
- ok

---

### Phase 2: Example Two [NOT STARTED]

**Files to modify:**
- `scripts/shared.sh` - second change to the same file
- `scripts/only-in-phase-2.sh`

**Verification**:
- ok
EOF
OUT_6="$(bash "$HARVESTER" "$FIXTURE_6")"
assert_json_array_eq "$OUT_6" '["scripts/shared.sh","scripts/only-in-phase-1.sh","scripts/only-in-phase-2.sh"]' "Case 6 (multi-phase union/dedup)"
DUP_COUNT="$(echo "$OUT_6" | jq '[.[] | select(. == "scripts/shared.sh")] | length')"
if [[ "$DUP_COUNT" == "1" ]]; then
  pass "Case 6: shared path deduplicated to a single entry"
else
  fail "Case 6: expected shared path to appear exactly once, got count=$DUP_COUNT"
fi

# ── Case 7: zero "Files to modify" occurrences returns [] with exit 0 ───────────────────────
FIXTURE_7="$WORKDIR/case7.md"
cat > "$FIXTURE_7" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Verification**:
- this phase touches no files worth enumerating
EOF
OUT_7="$(bash "$HARVESTER" "$FIXTURE_7")"
EXIT_7=$?
assert_json_array_eq "$OUT_7" '[]' "Case 7 (no Files to modify field at all)"
if [[ "$EXIT_7" -eq 0 ]]; then
  pass "Case 7: exit code 0 for the no-field case"
else
  fail "Case 7: expected exit 0, got $EXIT_7"
fi

# ── Case 10: list-item-wrapped field form, indented entries, no bleed into next field ────────
FIXTURE_10="$WORKDIR/case10.md"
cat > "$FIXTURE_10" << 'EOF'
### Phase 1: Example [NOT STARTED]

- **Timing:** 1.5 hours
- **Depends on:** none
- **Verification Tier:** local
- **Files to modify**:
  - `scripts/tests/curl-stub.sh` - path dispatch, query parsing, new scenario knobs
  - `scripts/tests/generate-test-fixtures.py` - synthetic paged generator
  - `scripts/tests/fixtures/` - any static fixture files added
- **Verification**:
  - `bash -n` clean on the stub.
  - Scratch driver shows: items URL and RPC URL served different bodies.
EOF
OUT_10="$(bash "$HARVESTER" "$FIXTURE_10")"
EXIT_10=$?
assert_json_array_eq "$OUT_10" '["scripts/tests/curl-stub.sh","scripts/tests/generate-test-fixtures.py","scripts/tests/fixtures/"]' "Case 10 (list-item-wrapped field form)"
if [[ "$EXIT_10" -eq 0 ]]; then
  pass "Case 10: exit code 0"
else
  fail "Case 10: expected exit 0, got $EXIT_10"
fi
if echo "$OUT_10" | grep -qi "bash -n\|Scratch driver"; then
  fail "Case 10: the following Verification field's indented sub-bullets leaked into the harvest: $OUT_10"
else
  pass "Case 10: the following Verification field's indented sub-bullets did not leak into the harvest"
fi

# ── Case 8: missing-file argument exits non-zero ─────────────────────────────────────────────
bash "$HARVESTER" "$WORKDIR/does-not-exist.md" >/dev/null 2>&1
EXIT_8=$?
if [[ "$EXIT_8" -ne 0 ]]; then
  pass "Case 8: nonexistent plan file argument exits non-zero ($EXIT_8)"
else
  fail "Case 8: expected non-zero exit for a nonexistent plan file, got 0"
fi

# ── Case 9: missing argument (usage error) exits non-zero ───────────────────────────────────
bash "$HARVESTER" >/dev/null 2>&1
EXIT_9=$?
if [[ "$EXIT_9" -ne 0 ]]; then
  pass "Case 9: missing positional argument exits non-zero ($EXIT_9)"
else
  fail "Case 9: expected non-zero exit for a missing argument, got 0"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
