#!/usr/bin/env bash
# test-update-plan-status.sh - Fixture-driven regression suite for
# scripts/update-plan-status.sh: the plan-level Status-line diagnostics (M1/M2/M3), the
# trailing-annotation tolerance policy, and the corrected stdout contract (plan path echoed on
# both a successful stamp and the already-at-target no-op).
#
# Structural model: test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error, and
# git-root-first REPO_ROOT resolution so the suite runs from both the source-store and deployed
# locations). Unlike that suite, this one drives update-plan-status.sh as a SUBPROCESS (it is an
# executable script, not a sourced library), using the same deploy-tree-first /
# source-store-fallback candidate list for the script under test, so this identical file can
# later be run against the deployed copy (.claude/scripts/tests/) to confirm the fix survives
# regeneration.
#
# Fixture shape: update-plan-status.sh resolves everything via RELATIVE paths from cwd
# (specs/{NNN}_{project}/plans/*.md) rather than a BASH_SOURCE-relative PROJECT_ROOT, so each
# case only needs a `cd` into a mktemp -d scratch root containing that one relative directory --
# no deployed dependency chain to copy in.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (script
# under test not found at any candidate path).

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
  "$REPO_ROOT/.claude/scripts/update-plan-status.sh"
  "$SCRIPT_DIR/../update-plan-status.sh"
)
TARGET=""
for candidate in "${SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TARGET="$candidate"
    break
  fi
done
if [[ -z "$TARGET" ]]; then
  echo "ERROR: update-plan-status.sh not found at any of:" >&2
  for candidate in "${SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# make_fixture CONTENT: builds a fresh scratch root under WORKDIR with a single conforming
# plan file (specs/001_demo/plans/01_x.md) containing CONTENT, and echoes the scratch root path.
make_fixture() {
  local content="$1"
  local dir
  dir="$(mktemp -d --tmpdir="$WORKDIR")"
  mkdir -p "$dir/specs/001_demo/plans"
  printf '%s\n' "$content" > "$dir/specs/001_demo/plans/01_x.md"
  echo "$dir"
}

plan_file_in() { echo "$1/specs/001_demo/plans/01_x.md"; }
# The script under test resolves everything via RELATIVE paths from cwd, so its stdout is
REL_PLAN_PATH="specs/001_demo/plans/01_x.md"

checksum() { md5sum "$1" | cut -d' ' -f1; }

# ─── M1: missing prefix ───────────────────────────────────────────────────────────────────────
dir=$(make_fixture "# Plan
No status line here.")
pf=$(plan_file_in "$dir")
before=$(checksum "$pf")
stderr_m1=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>&1 1>/dev/null)
rc=$?
after=$(checksum "$pf")
if [[ $rc -eq 1 ]]; then pass "M1 exits 1"; else fail "M1 exit code (got $rc)"; fi
if [[ "$stderr_m1" == *"not found"* ]]; then pass "M1 message names missing-prefix condition"; else fail "M1 message: $stderr_m1"; fi
if [[ "$before" == "$after" ]]; then pass "M1 does not mutate the file"; else fail "M1 mutated the file"; fi

# ─── M2: no bracket pair ──────────────────────────────────────────────────────────────────────
dir=$(make_fixture "# Plan
- **Status**: IMPLEMENTING")
pf=$(plan_file_in "$dir")
before=$(checksum "$pf")
stderr_m2=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>&1 1>/dev/null)
rc=$?
after=$(checksum "$pf")
if [[ $rc -eq 1 ]]; then pass "M2 exits 1"; else fail "M2 exit code (got $rc)"; fi
if [[ "$stderr_m2" == *"no [STATUS] bracket pair"* ]]; then pass "M2 message names missing-bracket condition"; else fail "M2 message: $stderr_m2"; fi
if [[ "$stderr_m2" == *"Line 2: - **Status**: IMPLEMENTING"* ]]; then pass "M2 quotes the offending line verbatim with line number"; else fail "M2 did not quote offending line: $stderr_m2"; fi
if [[ "$before" == "$after" ]]; then pass "M2 does not mutate the file"; else fail "M2 mutated the file"; fi

# ─── M3: text before the bracket ──────────────────────────────────────────────────────────────
dir=$(make_fixture "# Plan
- **Status**: see [NOTE]")
pf=$(plan_file_in "$dir")
before=$(checksum "$pf")
stderr_m3=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>&1 1>/dev/null)
rc=$?
after=$(checksum "$pf")
if [[ $rc -eq 1 ]]; then pass "M3 exits 1"; else fail "M3 exit code (got $rc)"; fi
if [[ "$stderr_m3" == *"unexpected text between the prefix and the bracket"* ]]; then pass "M3 message names unexpected-text condition"; else fail "M3 message: $stderr_m3"; fi
if [[ "$stderr_m3" == *"Line 2: - **Status**: see [NOTE]"* ]]; then pass "M3 quotes the offending line verbatim with line number"; else fail "M3 did not quote offending line: $stderr_m3"; fi
if [[ "$before" == "$after" ]]; then pass "M3 does not mutate the file"; else fail "M3 mutated the file"; fi

# ─── Distinctness: M1, M2, M3 messages must be pairwise distinct ─────────────────────────────
if [[ "$stderr_m1" != "$stderr_m2" && "$stderr_m1" != "$stderr_m3" && "$stderr_m2" != "$stderr_m3" ]]; then
  pass "M1/M2/M3 stderr messages are pairwise distinct"
else
  fail "M1/M2/M3 stderr messages collapsed (not pairwise distinct)"
fi

# ─── Trailing annotation: success, annotation preserved ──────────────────────────────────────
dir=$(make_fixture "# Plan
- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)")
pf=$(plan_file_in "$dir")
out=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>"$WORKDIR/err.log")
rc=$?
if [[ $rc -eq 0 ]]; then pass "trailing-annotation shape stamps successfully (rc=0)"; else fail "trailing-annotation shape rc=$rc: $(cat "$WORKDIR/err.log")"; fi
if [[ "$out" == "$REL_PLAN_PATH" ]]; then pass "trailing-annotation stdout is the plan path"; else fail "trailing-annotation stdout mismatch: $out"; fi
if grep -qF -- '- **Status**: [COMPLETED] (resumed; Phases 1R-10R closed)' "$pf"; then
  pass "trailing-annotation preserved verbatim after the stamp"
else
  fail "trailing-annotation not preserved: $(cat "$pf")"
fi
rm -f "$WORKDIR/err.log"

# ─── Two bracket pairs on one line: only the first is rewritten, remainder preserved ─────────
dir=$(make_fixture "# Plan
- **Status**: [IMPLEMENTING] and [PARTIAL] elsewhere")
pf=$(plan_file_in "$dir")
out=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>"$WORKDIR/err.log")
rc=$?
if [[ $rc -eq 0 ]]; then pass "two-bracket-pairs shape stamps successfully (rc=0)"; else fail "two-bracket-pairs shape rc=$rc: $(cat "$WORKDIR/err.log")"; fi
if grep -qF -- '- **Status**: [COMPLETED] and [PARTIAL] elsewhere' "$pf"; then
  pass "two-bracket-pairs: only the first pair rewritten, remainder preserved verbatim"
else
  fail "two-bracket-pairs mutation incorrect: $(cat "$pf")"
fi
rm -f "$WORKDIR/err.log"

# ─── Well-formed: still stamps correctly ─────────────────────────────────────────────────────
dir=$(make_fixture "# Plan
- **Status**: [NOT STARTED]")
pf=$(plan_file_in "$dir")
out=$(cd "$dir" && "$TARGET" 1 demo IMPLEMENTING 2>"$WORKDIR/err.log")
rc=$?
if [[ $rc -eq 0 ]]; then pass "well-formed shape stamps successfully (rc=0)"; else fail "well-formed shape rc=$rc: $(cat "$WORKDIR/err.log")"; fi
if [[ "$out" == "$REL_PLAN_PATH" ]]; then pass "well-formed stdout is the plan path"; else fail "well-formed stdout mismatch: $out"; fi
if grep -qF -- '- **Status**: [IMPLEMENTING]' "$pf"; then pass "well-formed file correctly stamped"; else fail "well-formed file not stamped: $(cat "$pf")"; fi
rm -f "$WORKDIR/err.log"

# ─── Already-at-target: no-op, file unchanged, stdout now the plan path ──────────────────────
dir=$(make_fixture "# Plan
- **Status**: [COMPLETED]")
pf=$(plan_file_in "$dir")
before=$(checksum "$pf")
out=$(cd "$dir" && "$TARGET" 1 demo COMPLETED 2>"$WORKDIR/err.log")
rc=$?
after=$(checksum "$pf")
if [[ $rc -eq 0 ]]; then pass "already-at-target no-op exits 0"; else fail "already-at-target rc=$rc: $(cat "$WORKDIR/err.log")"; fi
if [[ "$before" == "$after" ]]; then pass "already-at-target no-op leaves file byte-identical"; else fail "already-at-target no-op mutated the file"; fi
if [[ "$out" == "$REL_PLAN_PATH" ]]; then pass "already-at-target no-op echoes the plan path on stdout"; else fail "already-at-target no-op stdout mismatch (got '$out')"; fi
rm -f "$WORKDIR/err.log"

# ─── Unknown status token: still rejected, unaffected by this fix ────────────────────────────
dir=$(make_fixture "# Plan
- **Status**: [NOT STARTED]")
pf=$(plan_file_in "$dir")
before=$(checksum "$pf")
(cd "$dir" && "$TARGET" 1 demo BOGUS >/dev/null 2>"$WORKDIR/err.log")
rc=$?
after=$(checksum "$pf")
if [[ $rc -eq 1 ]]; then pass "unknown status token still rejected (rc=1)"; else fail "unknown status token rc=$rc"; fi
if grep -q "Unknown status" "$WORKDIR/err.log"; then pass "unknown status token message unchanged"; else fail "unknown status token message: $(cat "$WORKDIR/err.log")"; fi
if [[ "$before" == "$after" ]]; then pass "unknown status token does not mutate the file"; else fail "unknown status token mutated the file"; fi
rm -f "$WORKDIR/err.log"

# ─── Missing plan directory / missing plan file: pre-existing messages unaffected ────────────
dir="$(mktemp -d --tmpdir="$WORKDIR")"
(cd "$dir" && "$TARGET" 1 demo COMPLETED >/dev/null 2>"$WORKDIR/err.log")
rc=$?
if [[ $rc -eq 1 ]] && grep -q "Plan directory not found" "$WORKDIR/err.log"; then
  pass "missing plan directory still produces its own pre-existing message"
else
  fail "missing plan directory case: rc=$rc, stderr=$(cat "$WORKDIR/err.log")"
fi
rm -f "$WORKDIR/err.log"

dir="$(mktemp -d --tmpdir="$WORKDIR")"
mkdir -p "$dir/specs/001_demo/plans"
(cd "$dir" && "$TARGET" 1 demo COMPLETED >/dev/null 2>"$WORKDIR/err.log")
rc=$?
if [[ $rc -eq 1 ]] && grep -q "No plan file found" "$WORKDIR/err.log"; then
  pass "missing plan file still produces its own pre-existing message"
else
  fail "missing plan file case: rc=$rc, stderr=$(cat "$WORKDIR/err.log")"
fi
rm -f "$WORKDIR/err.log"

echo ""
info "Target script: $TARGET"
echo "PASSED: $PASSED"
echo "FAILED: $FAILED"

if [[ $FAILED -gt 0 ]]; then
  exit 1
fi
exit 0
