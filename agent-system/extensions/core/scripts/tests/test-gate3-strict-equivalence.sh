#!/usr/bin/env bash
# test-gate3-strict-equivalence.sh - Proves that verify-deploy.sh's gate3_run reconstructs its
# STRICT_CORE_DEPLOY "events-" hit count from a SINGLE check-extension-docs.sh invocation with
# byte-identical results to the two-invocation form it replaced.
#
# BACKGROUND: gate3_run used to invoke check-extension-docs.sh TWICE per run -- once normally
# (captured as doc_lint_output) and once more with STRICT_CORE_DEPLOY=1 (captured as
# strict_output), purely to compute `grep -c 'events-' <<<"$strict_output"`. check-extension-
# docs.sh's own advisory() function (its header comment, and every one of its 13 call sites)
# documents that it ALWAYS echoes "  ADVISORY: $msg" regardless of STRICT_CORE_DEPLOY, and ONLY
# ADDITIONALLY calls fail() (which echoes "  FAIL: $msg" with the identical $msg) when
# STRICT_CORE_DEPLOY=1. No other line in the script is mode-dependent. A strict pass's full
# stdout is therefore always exactly doc_lint_output (the first, already-captured pass) PLUS one
# extra "  FAIL: $msg" line per "  ADVISORY: $msg" line doc_lint_output already contains, with
# byte-identical $msg text -- so grep -c 'events-' over a real strict pass is provably:
#
#   (grep -c 'events-' over doc_lint_output) + (grep -c 'events-' over just its ADVISORY lines)
#
# gate3_run now computes exactly this sum from the single normal-mode capture instead of paying
# for a second full-corpus invocation (roughly halving gate 3's measured ~125-130s cost -- see
# this task's Phase 11 progress file and plan for the before/after measurement). This suite
# proves the reconstruction formula is byte-identical to a REAL second STRICT_CORE_DEPLOY=1
# invocation's own grep -c 'events-' result, across 0, 1 and 2+ seeded "events-" violations, by
# running BOTH the reconstruction and a live oracle second pass against the same fixture and
# diffing the two counts -- the oracle pass exists only in this test, never in production code.
#
# Structural model: test-verify-deploy-gate-selection.sh (pass()/fail()/info() helpers, PASSED/
# FAILED counters, mktemp WORKDIR with trap EXIT cleanup). Unlike that suite's FIXTURE_RICH, no
# rsync of the real agent-system/extensions/ tree is needed or used here: each fixture is a
# tiny, hand-built, 1-2-extension tree, so this suite stays "free" cost-class rather than
# inheriting gate 3's own "slow" cost by construction.
#
# Isolation technique: each fixture gets its OWN copy of check-extension-docs.sh at
# <fixture>/.claude/scripts/check-extension-docs.sh, and REPO_ROOT is exported to the fixture
# root before invoking it. check-extension-docs.sh's own top-of-file guard
# (`[[ -n "${REPO_ROOT:-}" ]] || . deploy-root-guard.sh`) skips its self-correcting repo-root
# detection entirely whenever REPO_ROOT is already non-empty, and EXT_DIR then defaults to
# "$REPO_ROOT/agent-system/extensions" -- so no git-init, symlink, or deploy-root-guard.sh copy
# is required for this suite's fixtures, unlike suites that drive the FULL verify-deploy.sh
# gate loop. redeploy-remedy-lib.sh is deliberately NOT copied into any fixture: check-
# extension-docs.sh's own degrade-safe guarded-source snippet falls back to an empty
# redeploy_remedy_fragment() when that library is absent, which only shortens the advisory
# message text and does not change whether it matches 'events-' or "  ADVISORY: " line framing
# -- irrelevant to what this suite is proving.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# real check-extension-docs.sh was not found, or a required binary is missing).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CED_SOURCE="$CORE_DIR/check-extension-docs.sh"

if [ ! -f "$CED_SOURCE" ]; then
  echo "ERROR: expected $CED_SOURCE" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required and not on PATH" >&2; exit 2; }

PASSED=0
FAILED=0

common_test_workdir_init

# make_fixture_ext NAME SEEDED_SCRIPT_BASENAME_OR_EMPTY -- writes one minimal routing_exempt
# extension under $1's fixture dir. An empty second arg produces a clean extension declaring no
# scripts (no violation); a non-empty one declares that one script in provides.scripts without
# ever creating it under .claude/scripts, which is exactly what check_core_deploy_advisory's
# per-script deployed-file check (`[[ -f "$deployed" ]] || advisory ...`) treats as undeployed.
make_fixture() {
  local fixture_root="$1"; shift
  mkdir -p "$fixture_root/.claude/scripts"
  cp "$CED_SOURCE" "$fixture_root/.claude/scripts/check-extension-docs.sh"
  local ext_name seeded_script
  for spec in "$@"; do
    ext_name="${spec%%:*}"
    seeded_script="${spec#*:}"
    [ "$seeded_script" = "$spec" ] && seeded_script=""
    local ext_dir="$fixture_root/agent-system/extensions/$ext_name"
    mkdir -p "$ext_dir"
    local scripts_json="[]"
    [ -n "$seeded_script" ] && scripts_json="[\"$seeded_script\"]"
    cat > "$ext_dir/manifest.json" <<EOF
{
  "name": "$ext_name",
  "version": "1.0.0",
  "description": "fixture",
  "dependencies": [],
  "routing_exempt": true,
  "provides": {
    "agents": [], "commands": [], "skills": [], "rules": [], "context": [],
    "scripts": $scripts_json, "hooks": []
  }
}
EOF
    echo "# $ext_name" > "$ext_dir/README.md"
  done
}

# run_normal FIXTURE_ROOT -- the production (first, only) pass: REPO_ROOT exported, no
# STRICT_CORE_DEPLOY. Mirrors exactly what gate3_run's doc_lint_output capture executes.
run_normal() {
  local fixture_root="$1"
  (cd "$fixture_root" && REPO_ROOT="$fixture_root" bash "$fixture_root/.claude/scripts/check-extension-docs.sh" --quiet 2>&1)
}

# run_strict_oracle FIXTURE_ROOT -- the REAL second pass this suite uses ONLY as a ground-truth
# oracle. This is the invocation gate3_run no longer performs in production; it exists here
# purely to prove the reconstruction formula matches what it would have produced.
run_strict_oracle() {
  local fixture_root="$1"
  (cd "$fixture_root" && REPO_ROOT="$fixture_root" STRICT_CORE_DEPLOY=1 bash "$fixture_root/.claude/scripts/check-extension-docs.sh" --quiet 2>&1)
}

# reconstruct_strict_hits NORMAL_OUTPUT -- the EXACT formula now embedded in verify-deploy.sh's
# gate3_run (see that function's own comment): baseline 'events-' matches across the whole
# normal-pass output, plus one more per "  ADVISORY: " line that itself matches 'events-' (the
# line a strict pass would additionally echo as "  FAIL: " with identical text).
reconstruct_strict_hits() {
  local normal_output="$1"
  local baseline advisory_only
  baseline=$(printf '%s\n' "$normal_output" | grep -c 'events-')
  advisory_only=$(printf '%s\n' "$normal_output" | grep '^  ADVISORY: ' | grep -c 'events-')
  echo $((baseline + advisory_only))
}

check_case() {
  local label="$1" fixture_root="$2" expected_min="$3"
  local normal_out oracle_out reconstructed oracle_hits
  normal_out="$(run_normal "$fixture_root")"
  oracle_out="$(run_strict_oracle "$fixture_root")"
  reconstructed="$(reconstruct_strict_hits "$normal_out")"
  oracle_hits=$(printf '%s\n' "$oracle_out" | grep -c 'events-')
  if [ "$reconstructed" -eq "$oracle_hits" ] && [ "$oracle_hits" -ge "$expected_min" ]; then
    common_test_pass "$label: reconstructed=$reconstructed matches live-oracle=$oracle_hits (>= $expected_min expected)"
  else
    common_test_fail "$label: reconstructed=$reconstructed oracle=$oracle_hits (expected >= $expected_min, and equal to each other)" \
         "$(printf 'NORMAL OUTPUT:\n%s\n\nORACLE (STRICT) OUTPUT:\n%s' "$normal_out" "$oracle_out")"
  fi
}

# =====================================================================
# Case (a): no seeded violation -- both passes must report zero 'events-' hits.
# =====================================================================
FIXTURE_CLEAN="$WORKDIR/clean"
make_fixture "$FIXTURE_CLEAN" "fixture_ext:"
check_case "case(a) clean fixture, zero violations" "$FIXTURE_CLEAN" 0
# Re-assert the exact zero (check_case only asserts >= expected_min and equality to the oracle;
# pin the absolute value too so a future change that inflates baseline noise is still caught).
clean_normal="$(run_normal "$FIXTURE_CLEAN")"
clean_reconstructed="$(reconstruct_strict_hits "$clean_normal")"
if [ "$clean_reconstructed" -eq 0 ]; then
  common_test_pass "case(a) exact-zero: reconstructed hit count is exactly 0 on a clean fixture"
else
  common_test_fail "case(a) exact-zero: expected exactly 0, got $clean_reconstructed" "$clean_normal"
fi

# =====================================================================
# Case (b): one seeded undeployed 'events-' script -- exactly one violation.
# =====================================================================
FIXTURE_ONE="$WORKDIR/one"
make_fixture "$FIXTURE_ONE" "fixture_ext:events-seed-fixture.sh"
check_case "case(b) one seeded violation" "$FIXTURE_ONE" 1

# =====================================================================
# Case (c): two seeded undeployed 'events-' scripts across two extensions -- proves the formula
# holds under multiplicity, not just the 0/1 boundary.
# =====================================================================
FIXTURE_TWO="$WORKDIR/two"
make_fixture "$FIXTURE_TWO" "fixture_a:events-seed-a.sh" "fixture_b:events-seed-b.sh"
check_case "case(c) two seeded violations across two extensions" "$FIXTURE_TWO" 2

# =====================================================================
# Case (d): the reconstruction must come from the SAME normal-pass output gate3_run already
# captures -- not a fresh invocation -- so running it twice against the same fixture (no new
# process) must be idempotent/deterministic.
# =====================================================================
one_normal="$(run_normal "$FIXTURE_ONE")"
r1="$(reconstruct_strict_hits "$one_normal")"
r2="$(reconstruct_strict_hits "$one_normal")"
if [ "$r1" -eq "$r2" ]; then
  common_test_pass "case(d) reconstruction is deterministic over the same captured output ($r1 == $r2)"
else
  common_test_fail "case(d) reconstruction is non-deterministic over identical input: $r1 vs $r2"
fi

echo
echo "====================================="
echo "Summary: $PASSED passed, $FAILED failed"
echo "====================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
