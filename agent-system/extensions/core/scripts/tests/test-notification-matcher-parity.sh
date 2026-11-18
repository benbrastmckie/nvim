#!/usr/bin/env bash
# test-notification-matcher-parity.sh - Asserts that merge-sources/settings-hooks.json and
# root-files/settings.json declare a byte-equal Notification matcher, that the shared matcher
# contains idle_prompt, and that a deliberately divergent fixture pair is detected as a
# failure (proving the check can fail, not only pass).
#
# This closes acceptance criterion 4: both settings surfaces agree on the Notification matcher,
# with a check that asserts it. No prior check in this corpus compared these two files against
# each other.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Siblings under the extension root in both the source store and the deployed tree.
FILE_A="$SCRIPT_DIR/../../merge-sources/settings-hooks.json"
FILE_B="$SCRIPT_DIR/../../root-files/settings.json"

for f in "$FILE_A" "$FILE_B"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file at $f" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0
common_test_workdir_init

# matcher_of <file> -- echoes the .hooks.Notification[].matcher value(s), newline-joined.
matcher_of() {
  jq -r '.hooks.Notification[].matcher' "$1" 2>/dev/null
}

# =====================================================================
# (a) The real two surfaces' matchers are byte-equal.
# =====================================================================
matcher_a="$(matcher_of "$FILE_A")"
matcher_b="$(matcher_of "$FILE_B")"
if [ -n "$matcher_a" ] && [ "$matcher_a" = "$matcher_b" ]; then
  common_test_pass "matcher parity: settings-hooks.json and settings.json declare a byte-equal Notification matcher ('$matcher_a')"
else
  common_test_fail "matcher parity: expected byte-equal matchers, got A='$matcher_a' B='$matcher_b'"
fi

# =====================================================================
# (b) The shared matcher contains idle_prompt.
# =====================================================================
if echo "$matcher_a" | grep -q 'idle_prompt'; then
  common_test_pass "matcher contains idle_prompt"
else
  common_test_fail "matcher expected to contain idle_prompt, got '$matcher_a'"
fi

# =====================================================================
# (c) A deliberately divergent fixture pair is detected as a failure -- proves this check can
# fail, not only pass. Fixtures are built fresh in WORKDIR, never by mutating the real files.
# =====================================================================
fixture_a="${WORKDIR}/fixture-a.json"
fixture_b="${WORKDIR}/fixture-b.json"
cat > "$fixture_a" <<'EOF'
{"hooks":{"Notification":[{"matcher":"permission_prompt|idle_prompt|elicitation_dialog"}]}}
EOF
cat > "$fixture_b" <<'EOF'
{"hooks":{"Notification":[{"matcher":"permission_prompt|elicitation_dialog"}]}}
EOF
fixture_matcher_a="$(matcher_of "$fixture_a")"
fixture_matcher_b="$(matcher_of "$fixture_b")"
if [ "$fixture_matcher_a" != "$fixture_matcher_b" ]; then
  common_test_pass "non-vacuousness: a deliberately divergent fixture pair IS detected as unequal (A='$fixture_matcher_a' B='$fixture_matcher_b')"
else
  common_test_fail "non-vacuousness: expected the divergent fixture pair to be detected as unequal, got equal matchers"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
