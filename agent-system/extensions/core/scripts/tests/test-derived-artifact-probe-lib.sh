#!/usr/bin/env bash
# test-derived-artifact-probe-lib.sh - Fixture-driven regression suite for
# lib/derived-artifact-probe-lib.sh, the repo-declared, build-free derived-artifact staleness
# probe mechanism both implement-postflight engines call before their own status write.
#
# Structural model: test-deploy-freshness.sh's library-direct testing style (source the real
# library in a scratch subshell, exercise its exported functions against throwaway fixture
# consumer directories holding a fabricated .claude-extensions.json) combined with
# test-phase-heading-patterns.sh's pass()/fail()/info() counter helpers. This suite has no
# subprocess checker to invoke (unlike test-deploy-freshness.sh's checker+library pair) -- every
# case below sources the library directly and calls its three exported functions.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (library or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution: same dual-depth support as test-deploy-freshness.sh (source-store vs.
# deployed invocation sites sit at different depths below the repo root) -- resolve via the git
# worktree root first and only fall back to the fixed-depth guess when not inside a work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/derived-artifact-probe-lib.sh"
  "$SCRIPT_DIR/../lib/derived-artifact-probe-lib.sh"
)
LIB=""
for candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    LIB="$candidate"
    break
  fi
done
if [[ -z "$LIB" ]]; then
  echo "ERROR: derived-artifact-probe-lib.sh not found at any of:" >&2
  for candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

info "Using library: $LIB"

# write_fixture <dir> <extensions_json_fragment_without_outer_braces_or_absent>
# $2 omitted entirely (empty string) -> no .claude-extensions.json file at all.
write_fixture() {
  local dir="$1" body="${2-__OMIT__}"
  mkdir -p "$dir"
  if [[ "$body" == "__OMIT__" ]]; then
    return 0
  fi
  printf '%s' "$body" > "$dir/.claude-extensions.json"
}

# =====================================================================
# Case: absent file entirely
# =====================================================================
C_ABSENT="$WORKDIR/absent"
mkdir -p "$C_ABSENT"
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_ABSENT")"
  prefixes="$(derived_probe_output_prefixes "$C_ABSENT")"
  rc=0; derived_probe_run_all "$C_ABSENT" "[test]" >/dev/null 2>&1 || rc=$?
  echo "RESULT entries=<<<${entries}>>> prefixes=<<<${prefixes}>>> rc=${rc}"
) > "$WORKDIR/case-absent.out" 2>&1
if grep -q 'RESULT entries=<<<\[\]>>> prefixes=<<<\[\]>>> rc=0' "$WORKDIR/case-absent.out"; then
  pass "absent file: entries=[] prefixes=[] rc=0, no probe executed"
else
  fail "absent file: expected entries=[] prefixes=[] rc=0, got <<<$(cat "$WORKDIR/case-absent.out")>>>"
fi

# =====================================================================
# Case: file present but absent key
# =====================================================================
C_NOKEY="$WORKDIR/nokey"
write_fixture "$C_NOKEY" '{"version":"1.0.0","extensions":{}}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_NOKEY")"
  echo "RESULT entries=<<<${entries}>>>"
) > "$WORKDIR/case-nokey.out" 2>&1
if grep -q 'RESULT entries=<<<\[\]>>>' "$WORKDIR/case-nokey.out"; then
  pass "absent key: entries=[]"
else
  fail "absent key: expected entries=[], got <<<$(cat "$WORKDIR/case-nokey.out")>>>"
fi

# =====================================================================
# Case: key present but empty array
# =====================================================================
C_EMPTY="$WORKDIR/empty"
write_fixture "$C_EMPTY" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_EMPTY")"
  rc=0; derived_probe_run_all "$C_EMPTY" "[test]" >/dev/null 2>&1 || rc=$?
  echo "RESULT entries=<<<${entries}>>> rc=${rc}"
) > "$WORKDIR/case-empty.out" 2>&1
if grep -q 'RESULT entries=<<<\[\]>>> rc=0' "$WORKDIR/case-empty.out"; then
  pass "empty array: entries=[] rc=0"
else
  fail "empty array: expected entries=[] rc=0, got <<<$(cat "$WORKDIR/case-empty.out")>>>"
fi

# =====================================================================
# Case: one well-formed entry (passing probe)
# =====================================================================
C_ONE="$WORKDIR/one"
write_fixture "$C_ONE" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compA","check_command":"true","derived_output_dirs":["components/compA/certs"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_ONE")"
  count="$(echo "$entries" | jq 'length')"
  rc=0; derived_probe_run_all "$C_ONE" "[test]" >/dev/null 2>&1 || rc=$?
  echo "RESULT count=${count} rc=${rc}"
) > "$WORKDIR/case-one.out" 2>&1
if grep -q 'RESULT count=1 rc=0' "$WORKDIR/case-one.out"; then
  pass "one entry, passing probe: count=1 rc=0"
else
  fail "one entry, passing probe: expected count=1 rc=0, got <<<$(cat "$WORKDIR/case-one.out")>>>"
fi

# =====================================================================
# Case: two entries, both passing
# =====================================================================
C_TWO="$WORKDIR/two"
write_fixture "$C_TWO" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compA","check_command":"true","derived_output_dirs":["components/compA/certs"]},{"component":"compB","check_command":"true","derived_output_dirs":["components/compB/certs/"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_TWO")"
  count="$(echo "$entries" | jq 'length')"
  rc=0; derived_probe_run_all "$C_TWO" "[test]" >/dev/null 2>&1 || rc=$?
  echo "RESULT count=${count} rc=${rc}"
) > "$WORKDIR/case-two.out" 2>&1
if grep -q 'RESULT count=2 rc=0' "$WORKDIR/case-two.out"; then
  pass "two entries, both passing: count=2 rc=0"
else
  fail "two entries, both passing: expected count=2 rc=0, got <<<$(cat "$WORKDIR/case-two.out")>>>"
fi

# =====================================================================
# Case: malformed entry dropped with warning (missing check_command), alongside one valid entry
# =====================================================================
C_MALFORMED="$WORKDIR/malformed"
write_fixture "$C_MALFORMED" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"badOne","derived_output_dirs":["components/badOne/certs"]},{"component":"goodOne","check_command":"true","derived_output_dirs":["components/goodOne/certs"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_MALFORMED" 2>"$WORKDIR/malformed-stderr.txt")"
  count="$(echo "$entries" | jq 'length')"
  comp="$(echo "$entries" | jq -r '.[0].component')"
  echo "RESULT count=${count} comp=${comp}"
) > "$WORKDIR/case-malformed.out" 2>&1
if grep -q 'RESULT count=1 comp=goodOne' "$WORKDIR/case-malformed.out"; then
  pass "malformed entry dropped: only the valid entry survives"
else
  fail "malformed entry dropped: expected count=1 comp=goodOne, got <<<$(cat "$WORKDIR/case-malformed.out")>>>"
fi
if grep -q 'WARNING.*badOne' "$WORKDIR/malformed-stderr.txt" 2>/dev/null; then
  pass "malformed entry dropped: named WARNING naming the dropped entry emitted on stderr"
else
  fail "malformed entry dropped: expected a named WARNING, got <<<$(cat "$WORKDIR/malformed-stderr.txt" 2>/dev/null)>>>"
fi

# =====================================================================
# Case: malformed derived_output_dirs (non-array, and array with a non-string member)
# =====================================================================
C_BADDIRS="$WORKDIR/baddirs"
write_fixture "$C_BADDIRS" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"badDirsStr","check_command":"true","derived_output_dirs":"not-an-array"},{"component":"badDirsMember","check_command":"true","derived_output_dirs":["ok/path",42]},{"component":"goodOne","check_command":"true","derived_output_dirs":["components/goodOne/certs"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  entries="$(derived_probe_entries "$C_BADDIRS" 2>/dev/null)"
  count="$(echo "$entries" | jq 'length')"
  comp="$(echo "$entries" | jq -r '.[0].component')"
  echo "RESULT count=${count} comp=${comp}"
) > "$WORKDIR/case-baddirs.out" 2>&1
if grep -q 'RESULT count=1 comp=goodOne' "$WORKDIR/case-baddirs.out"; then
  pass "malformed derived_output_dirs (non-array and non-string member) both dropped"
else
  fail "malformed derived_output_dirs: expected count=1 comp=goodOne, got <<<$(cat "$WORKDIR/case-baddirs.out")>>>"
fi

# =====================================================================
# Case: prefix normalization (with and without trailing slash)
# =====================================================================
C_PREFIX="$WORKDIR/prefix"
write_fixture "$C_PREFIX" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compA","check_command":"true","derived_output_dirs":["components/compA/certs"]},{"component":"compB","check_command":"true","derived_output_dirs":["components/compB/certs/"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  prefixes="$(derived_probe_output_prefixes "$C_PREFIX")"
  echo "RESULT prefixes=<<<${prefixes}>>>"
) > "$WORKDIR/case-prefix.out" 2>&1
if grep -q 'RESULT prefixes=<<<\["components/compA/certs/","components/compB/certs/"\]>>>' "$WORKDIR/case-prefix.out"; then
  pass "prefix normalization: both members end with exactly one trailing slash"
else
  fail "prefix normalization: expected both members trailing-slash-normalized, got <<<$(cat "$WORKDIR/case-prefix.out")>>>"
fi

# =====================================================================
# Case: a failing probe (among two) -> run_all returns nonzero and names only the failing one
# =====================================================================
C_FAILING="$WORKDIR/failing"
write_fixture "$C_FAILING" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compGood","check_command":"true","derived_output_dirs":["components/compGood/certs"]},{"component":"compBad","check_command":"false","derived_output_dirs":["components/compBad/certs"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  rc=0
  derived_probe_run_all "$C_FAILING" "[test]" >/dev/null 2>"$WORKDIR/failing-stderr.txt" || rc=$?
  echo "RESULT rc=${rc}"
) > "$WORKDIR/case-failing.out" 2>&1
if grep -q 'RESULT rc=1' "$WORKDIR/case-failing.out"; then
  pass "failing probe: run_all returns nonzero"
else
  fail "failing probe: expected rc=1, got <<<$(cat "$WORKDIR/case-failing.out")>>>"
fi
if grep -q "compBad" "$WORKDIR/failing-stderr.txt" 2>/dev/null && ! grep -q "compGood" "$WORKDIR/failing-stderr.txt" 2>/dev/null; then
  pass "failing probe: named failure line mentions only the failing component"
else
  fail "failing probe: expected a failure line naming only compBad, got <<<$(cat "$WORKDIR/failing-stderr.txt" 2>/dev/null)>>>"
fi

# =====================================================================
# Case: a probe that exceeds the bound (timeout) -> treated as a failure, exit code 124 named
# =====================================================================
C_TIMEOUT="$WORKDIR/timeout"
write_fixture "$C_TIMEOUT" '{"version":"1.0.0","extensions":{},"derived_artifact_probes":[{"component":"compSlow","check_command":"sleep 5","derived_output_dirs":["components/compSlow/certs"]}]}'
(
  # shellcheck disable=SC1090
  . "$LIB"
  export DERIVED_PROBE_TIMEOUT_SECONDS=1
  rc=0
  derived_probe_run_all "$C_TIMEOUT" "[test]" >/dev/null 2>"$WORKDIR/timeout-stderr.txt" || rc=$?
  echo "RESULT rc=${rc}"
) > "$WORKDIR/case-timeout.out" 2>&1
if grep -q 'RESULT rc=1' "$WORKDIR/case-timeout.out"; then
  pass "timed-out probe: run_all returns nonzero (treated as a failure, not a hang)"
else
  fail "timed-out probe: expected rc=1, got <<<$(cat "$WORKDIR/case-timeout.out")>>>"
fi
if grep -q "compSlow" "$WORKDIR/timeout-stderr.txt" 2>/dev/null && grep -q "timed out" "$WORKDIR/timeout-stderr.txt" 2>/dev/null; then
  pass "timed-out probe: named failure line states the timeout explicitly"
else
  fail "timed-out probe: expected a failure line naming compSlow and 'timed out', got <<<$(cat "$WORKDIR/timeout-stderr.txt" 2>/dev/null)>>>"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
