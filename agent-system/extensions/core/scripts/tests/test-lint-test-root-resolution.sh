#!/usr/bin/env bash
# test-lint-test-root-resolution.sh - Both-polarity fixture test for
# scripts/lint/lint-test-root-resolution.sh.
#
# The lint's job is to fail when a test suite computes its own repo root or extensions root with
# an unconditional fixed-depth parent walk that reaches PAST the extension-root boundary (the
# three shapes: single-line cd+pwd assignment, two-statement cd-then-pwd, and a bare inline use
# with no assignment at all), and to stay silent on: a git-first (or other first-attempt) guarded
# fallback, a validated-candidate shape, a file outside the test-suite scan scope, and an
# allowlisted path:line. This test asserts all of that against synthetic fixtures written to a
# scratch directory, so it never depends on the live tree being clean and never mutates the
# repository. Several negative cases additionally exercise the lint's DEFAULT (non-explicit-path)
# corpus scan by pointing it at a synthetic extensions tree via the `REPO_ROOT` environment
# override the lint itself already supports -- this is required specifically for the
# scan-scope-exclusion and allowlist cases, since an EXPLICIT path argument bypasses scope
# classification entirely (by design, matching the model lint's own precedent) and so cannot
# exercise either of those two behaviors.
#
# Structural model: test-lint-test-harness-adoption.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

# Sourced only for common_test_resolve_subject/common_test_declare_subject below -- this suite
# keeps its OWN local pass()/fail()/info() (below) for its own test-harness output, deliberately,
# since it is itself a fixture exercising lint-test-root-resolution.sh's sanctioned shapes; the
# local trio is never replaced by the common_test_* names this sourcing also makes available.
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

LINT_SCRIPT="$(common_test_resolve_subject "lint-test-root-resolution.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-test-root-resolution.sh" \
  "$SCRIPT_DIR/../lint/lint-test-root-resolution.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Case 1 (positive, single-line cd+pwd assignment): unconditional
# VAR="$(cd "$SCRIPT_DIR/../../../.." && pwd)" -> lint must fire.
# =====================================================================
info "=== positive case 1: unconditional single-line cd+pwd assignment ==="

POS1_FIXTURE="$WORKDIR/positive-single-line.sh"
cat > "$POS1_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
EOF

if bash "$LINT_SCRIPT" "$POS1_FIXTURE" >"$WORKDIR/pos1-out.txt" 2>&1; then
  fail "lint exited 0 for the unconditional single-line cd+pwd fixture (expected non-zero)"
else
  pass "lint exited non-zero for the unconditional single-line cd+pwd fixture"
fi
if grep -q "positive-single-line.sh:3" "$WORKDIR/pos1-out.txt"; then
  pass "lint reports the violating line (3) by file:line"
else
  fail "lint output did not name line 3:
$(cat "$WORKDIR/pos1-out.txt")"
fi

# =====================================================================
# Case 2 (positive, two-statement cd-then-pwd variant): a bare `cd "..."` line followed by
# `VAR=$(pwd)` -> lint must fire.
# =====================================================================
info "=== positive case 2: two-statement cd-then-pwd variant ==="

POS2_FIXTURE="$WORKDIR/positive-two-statement.sh"
cat > "$POS2_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/../../../.."
REAL_REPO_ROOT=$(pwd)
EOF

if bash "$LINT_SCRIPT" "$POS2_FIXTURE" >"$WORKDIR/pos2-out.txt" 2>&1; then
  fail "lint exited 0 for the two-statement cd-then-pwd fixture (expected non-zero)"
else
  pass "lint exited non-zero for the two-statement cd-then-pwd fixture"
fi
if grep -q "positive-two-statement.sh:3" "$WORKDIR/pos2-out.txt"; then
  pass "lint reports the violating cd line (3) by file:line"
else
  fail "lint output did not name line 3:
$(cat "$WORKDIR/pos2-out.txt")"
fi

# =====================================================================
# Case 3 (positive, bare inline use): the same unconditional literal consumed directly as a
# command argument, with no assignment step at all -> lint must fire.
# =====================================================================
info "=== positive case 3: bare inline use, no assignment ==="

POS3_FIXTURE="$WORKDIR/positive-bare-inline.sh"
cat > "$POS3_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git -C "$SCRIPT_DIR/../../../.." status --porcelain -- specs/
EOF

if bash "$LINT_SCRIPT" "$POS3_FIXTURE" >"$WORKDIR/pos3-out.txt" 2>&1; then
  fail "lint exited 0 for the bare-inline-use fixture (expected non-zero)"
else
  pass "lint exited non-zero for the bare-inline-use fixture"
fi
if grep -q "positive-bare-inline.sh:3" "$WORKDIR/pos3-out.txt"; then
  pass "lint reports the violating inline-use line (3) by file:line"
else
  fail "lint output did not name line 3:
$(cat "$WORKDIR/pos3-out.txt")"
fi

# =====================================================================
# Case 4 (negative, git-first guarded fallback): the fixed-depth walk sits inside an
# `if [[ -z "$VAR" ]]` block, run only after a git rev-parse --show-toplevel attempt already
# failed -> lint must stay silent.
# =====================================================================
info "=== negative case 4: git-first guarded fallback ==="

NEG4_FIXTURE="$WORKDIR/negative-git-first.sh"
cat > "$NEG4_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi
EOF

if bash "$LINT_SCRIPT" "$NEG4_FIXTURE" >"$WORKDIR/neg4-out.txt" 2>&1; then
  pass "lint exited 0 for the git-first-guarded fallback fixture (no false positive)"
else
  fail "lint exited non-zero for the git-first-guarded fallback fixture (false positive):
$(cat "$WORKDIR/neg4-out.txt")"
fi

# =====================================================================
# Case 5 (negative, validated-candidate shape): the computed path is tested with `[ -f ... ]`
# against the SAME variable before being accepted, with a differently-shaped fallthrough ->
# lint must stay silent.
# =====================================================================
info "=== negative case 5: validated-candidate shape ==="

NEG5_FIXTURE="$WORKDIR/negative-validated-candidate.sh"
cat > "$NEG5_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"
if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
  EXTENSIONS_ROOT="$CANDIDATE_EXT_ROOT"
else
  EXTENSIONS_ROOT=""
fi
EOF

if bash "$LINT_SCRIPT" "$NEG5_FIXTURE" >"$WORKDIR/neg5-out.txt" 2>&1; then
  pass "lint exited 0 for the validated-candidate fixture (no false positive)"
else
  fail "lint exited non-zero for the validated-candidate fixture (false positive):
$(cat "$WORKDIR/neg5-out.txt")"
fi

# =====================================================================
# Case 6 (negative, out-of-scope file + allowlisted path:line): both exercised against the
# lint's DEFAULT corpus scan by pointing it at a synthetic extensions tree via the REPO_ROOT
# environment override -- required because an EXPLICIT path argument bypasses scope
# classification and the allowlist is keyed by a specific repo-relative path, neither of which a
# bare explicit-path invocation can exercise.
# =====================================================================
info "=== negative case 6a: a file outside the test-suite scan scope carrying the shape ==="

SYNROOT="$WORKDIR/synthetic-repo"
mkdir -p "$SYNROOT/agent-system/extensions/fixtureext/scripts"
OUT_OF_SCOPE_FIXTURE="$SYNROOT/agent-system/extensions/fixtureext/scripts/helper-not-a-test.sh"
cat > "$OUT_OF_SCOPE_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
EOF

if REPO_ROOT="$SYNROOT" bash "$LINT_SCRIPT" >"$WORKDIR/neg6a-out.txt" 2>&1; then
  pass "lint exited 0 scanning a synthetic corpus containing only an out-of-scope-named file carrying the shape"
else
  fail "lint exited non-zero for a corpus containing only an out-of-scope file (false positive):
$(cat "$WORKDIR/neg6a-out.txt")"
fi

info "=== negative case 6b: an allowlisted path:line ==="

mkdir -p "$SYNROOT/agent-system/extensions/core/scripts/tests"
ALLOWLISTED_FIXTURE="$SYNROOT/agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh"
for _n in $(seq 1 50); do
  echo "# padding line $_n"
done > "$ALLOWLISTED_FIXTURE"
# Appended via a variable-built string (never a literal "$CORE_DIR/../../.." substring in THIS
# suite's own source) so this generator line itself can never be mistaken by the lint under test
# for a real violation when IT scans this suite's own source as part of the live corpus.
_dotdot_chain="/../../../.."
echo "REPO_ROOT=\"\$(cd \"\$CORE_DIR${_dotdot_chain}\" && pwd)\"" >> "$ALLOWLISTED_FIXTURE"
unset _dotdot_chain
ALLOWLISTED_LINE="$(grep -n 'REPO_ROOT=' "$ALLOWLISTED_FIXTURE" | head -1 | cut -d: -f1)"

if [ "$ALLOWLISTED_LINE" = "51" ]; then
  pass "allowlisted fixture places its violating line at exactly line 51, matching the lint's ALLOWLIST key"
else
  fail "allowlisted fixture's violating line landed at $ALLOWLISTED_LINE, not 51 -- fixture construction bug, not a lint result"
fi

if REPO_ROOT="$SYNROOT" bash "$LINT_SCRIPT" >"$WORKDIR/neg6b-out.txt" 2>&1; then
  pass "lint exited 0 scanning a synthetic corpus whose sole violation sits at the allowlisted path:line"
else
  fail "lint exited non-zero for a corpus whose sole violation is allowlisted (allowlist not honored):
$(cat "$WORKDIR/neg6b-out.txt")"
fi

# =====================================================================
# Case 7: exit-code contract (0/1/2) and explicit-path-replaces-not-adds-to-corpus semantics.
# =====================================================================
info "=== case 7: exit-code contract and explicit-path-replaces-corpus semantics ==="

if HELP_OUT="$(bash "$LINT_SCRIPT" --help 2>&1)"; then
  if echo "$HELP_OUT" | grep -q "Usage: lint-test-root-resolution.sh"; then
    pass "--help exits 0 and prints the usage line"
  else
    fail "--help exited 0 but did not print the expected usage line: $HELP_OUT"
  fi
else
  fail "--help exited non-zero (expected 0)"
fi

if bash "$LINT_SCRIPT" --totally-unknown-flag >/dev/null 2>&1; then
  fail "an unknown flag-shaped argument exited 0 (expected 2)"
else
  unknown_flag_rc=$?
  if [ "$unknown_flag_rc" -eq 2 ]; then
    pass "an unknown flag-shaped argument exits 2 (environment/usage error)"
  else
    fail "an unknown flag-shaped argument exited $unknown_flag_rc (expected 2)"
  fi
fi

# A genuinely violating, in-scope, NON-allowlisted fixture inside the same synthetic REPO_ROOT --
# this is the fixture that actually distinguishes "replaces" from "adds to": if explicit-path
# handling incorrectly added to the default corpus instead of replacing it, this unallowlisted
# violation would surface in the case 7 run below even though only CLEAN_EXPLICIT_FIXTURE was
# named on the command line.
ADD_VS_REPLACE_FIXTURE="$SYNROOT/agent-system/extensions/core/scripts/tests/test-definitely-violates.sh"
cat > "$ADD_VS_REPLACE_FIXTURE" << 'EOF'
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNGUARDED_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
EOF

CLEAN_EXPLICIT_FIXTURE="$WORKDIR/clean-explicit.sh"
cat > "$CLEAN_EXPLICIT_FIXTURE" << 'EOF'
#!/usr/bin/env bash
echo "nothing to see here"
EOF

if REPO_ROOT="$SYNROOT" bash "$LINT_SCRIPT" "$CLEAN_EXPLICIT_FIXTURE" >"$WORKDIR/case7-out.txt" 2>&1; then
  pass "an explicit clean path argument REPLACES the default corpus: a genuinely-violating, non-allowlisted fixture also present under the same synthetic REPO_ROOT is not swept in"
else
  fail "an explicit path argument appears to ADD TO rather than REPLACE the default corpus (unexpected violation):
$(cat "$WORKDIR/case7-out.txt")"
fi

# Sanity check on the sanity check: confirm the default (no-explicit-path) scan of the SAME
# synthetic REPO_ROOT DOES catch ADD_VS_REPLACE_FIXTURE's violation -- otherwise the case above
# would pass vacuously for the wrong reason (a fixture that was never actually detectable).
if REPO_ROOT="$SYNROOT" bash "$LINT_SCRIPT" >"$WORKDIR/case7-default-out.txt" 2>&1; then
  fail "default-corpus sanity check: expected the synthetic REPO_ROOT's unallowlisted violation to be caught, but the default scan exited 0:
$(cat "$WORKDIR/case7-default-out.txt")"
else
  if grep -q "test-definitely-violates.sh" "$WORKDIR/case7-default-out.txt"; then
    pass "default-corpus sanity check: the same synthetic REPO_ROOT's unallowlisted violation IS caught by a default (no-explicit-path) scan, confirming case 7 above is a meaningful test"
  else
    fail "default-corpus sanity check: scan failed but did not name test-definitely-violates.sh:
$(cat "$WORKDIR/case7-default-out.txt")"
  fi
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
