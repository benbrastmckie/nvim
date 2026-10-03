#!/usr/bin/env bash
# test-books-certify.sh - Narrow, fixture-driven suite for books-certify.sh.
#
# Per context/standards/shell-script-testing.md: fixtures are constructed inline via a mktemp -d
# workdir (each made into its own git repo, since books-certify.sh resolves the repository root
# via `git rev-parse --show-toplevel`) created at suite start; nothing here depends on the
# external Logos/Verification repository or on any real specs/ tree. Class B strict mode (this
# is a PASSED/FAILED-counter harness that must report every case, not abort on the first
# failure).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER="${SCRIPT_DIR}/../books-certify.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -x "$WRAPPER" ]]; then
  fail "prerequisite: $WRAPPER is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi

# assert_exit CASE_NAME EXPECTED_EXIT ACTUAL_EXIT
assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "${name}: exit code ${actual} (expected ${expected})"
  else
    fail "${name}: exit code ${actual}, expected ${expected}"
  fi
}

# assert_contains CASE_NAME OUTPUT NEEDLE
assert_contains() {
  local name="$1" output="$2" needle="$3"
  if [[ "$output" == *"$needle"* ]]; then
    pass "${name}: output contains '${needle}'"
  else
    fail "${name}: output does NOT contain '${needle}'"
    info "  --- actual output ---"
    while IFS= read -r line; do info "  $line"; done <<< "$output"
  fi
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# ─── Case 1: driver present, invoked with arguments forwarded in order ─────────────────────────
repo1="${WORKDIR}/repo-with-driver"
mkdir -p "${repo1}/books/scripts"
(cd "$repo1" && git init -q)
cat > "${repo1}/books/scripts/certify.sh" <<'EOF'
#!/usr/bin/env bash
# Fake driver: echo back every argument, one per line, prefixed so the test can tell this fake
# driver ran (and in what order the arguments arrived).
for a in "$@"; do
  echo "FAKE-DRIVER-ARG: $a"
done
exit 0
EOF
chmod +x "${repo1}/books/scripts/certify.sh"

output1=$(cd "$repo1" && "$WRAPPER" --no-build --only Queue components/framed_channel 2>&1)
exit1=$?
assert_exit "case1-driver-present-exit" 0 "$exit1"
assert_contains "case1-arg1-order" "$output1" $'FAKE-DRIVER-ARG: --no-build\nFAKE-DRIVER-ARG: --only'
assert_contains "case1-arg2-name" "$output1" "FAKE-DRIVER-ARG: Queue"
assert_contains "case1-arg3-root" "$output1" "FAKE-DRIVER-ARG: components/framed_channel"

# ─── Case 2: driver absent, loud failure path taken with a non-zero exit ───────────────────────
repo2="${WORKDIR}/repo-without-driver"
mkdir -p "$repo2"
(cd "$repo2" && git init -q)

output2=$(cd "$repo2" && "$WRAPPER" --check 2>&1)
exit2=$?
assert_exit "case2-driver-absent-exit" 3 "$exit2"
assert_contains "case2-actionable-message" "$output2" "no book certification driver found"

# ─── Case 3: the suppressed flag is rejected rather than silently forwarded ────────────────────
repo3="${WORKDIR}/repo-with-driver-again"
mkdir -p "${repo3}/books/scripts"
(cd "$repo3" && git init -q)
cat > "${repo3}/books/scripts/certify.sh" <<'EOF'
#!/usr/bin/env bash
# If this fake driver ever runs with --graph-from, the wrapper failed to suppress it.
echo "FAKE-DRIVER-RAN-WITH: $*"
exit 0
EOF
chmod +x "${repo3}/books/scripts/certify.sh"

output3=$(cd "$repo3" && "$WRAPPER" --graph-from /tmp/some-graph.txt 2>&1)
exit3=$?
assert_exit "case3-graph-from-rejected-exit" 2 "$exit3"
assert_contains "case3-rejection-message" "$output3" "--graph-from"
if [[ "$output3" == *"FAKE-DRIVER-RAN-WITH"* ]]; then
  fail "case3-not-forwarded: the fake driver ran -- --graph-from was forwarded instead of refused"
else
  pass "case3-not-forwarded: the fake driver never ran"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]] || exit 1
