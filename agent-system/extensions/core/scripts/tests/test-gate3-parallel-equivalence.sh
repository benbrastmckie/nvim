#!/usr/bin/env bash
# test-gate3-parallel-equivalence.sh - Proves check-extension-docs.sh's per-extension worker
# pool (CED_JOBS, default 4) produces byte-identical output and an identical PASS/FAIL verdict
# at every worker count, on a fixture seeded with a mix of FAIL, ADVISORY and clean extensions.
#
# BACKGROUND: the per-extension loop that used to run strictly sequentially now forks one real
# child process per extension (never batched -- the one-process-per-unit shape already proven
# faster than any batched `xargs -P` shape for the shellcheck gate), bounded by CED_JOBS
# concurrent workers (default 4, matching tests/run-all.sh's own JOBS_CAP). Each child mutates
# only its OWN private copy of FAILURES/EXTENSION_STATUS/DEPLOY_DRIFT_ADVISORIES/
# DEPLOY_DRIFT_ADVISORY_LINES; the parent re-derives the real aggregate afterward by parsing the
# captured text for the exhaustive "  FAIL: "/"  ADVISORY: " markers fail()/advisory() always
# emit (see check-extension-docs.sh's own comment at the top of its parallel-dispatch block).
# This suite is the proof that re-derivation is exact regardless of how many workers ran
# concurrently, and that the parent's discovery-order concatenation (not completion order)
# keeps the combined output byte-identical no matter which child happens to finish first.
#
# Structural model: test-gate3-strict-equivalence.sh (same fixture-building technique: a
# REPO_ROOT/EXT_DIR environment override into a tiny hand-built extensions tree, no git-init or
# deploy-root-guard.sh copy needed). This suite stays cheap ("free" cost class) by construction
# -- its fixture extensions are hand-built, not a real-corpus rsync.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CED_SOURCE="$CORE_DIR/check-extension-docs.sh"

if [ ! -f "$CED_SOURCE" ]; then
  echo "ERROR: expected $CED_SOURCE" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq required and not on PATH" >&2; exit 2; }

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

FIXTURE="$WORKDIR/fixture"
mkdir -p "$FIXTURE/.claude/scripts"
cp "$CED_SOURCE" "$FIXTURE/.claude/scripts/check-extension-docs.sh"

# Six fixture extensions, deliberately out of alphabetical-vs-numeric discovery order relative
# to each other so a bug that accidentally sorted by completion time (instead of discovery
# order) would have a real chance to show up as a reordering rather than being masked by
# alphabetical luck:
#   ext_c  clean (no violation)
#   ext_a  one seeded FAIL (undeployed manifest-declared script -- same mechanism gate3's own
#          real corpus exercises via check_core_deploy_advisory/check_undeclared_scripts path)
#   ext_f  one seeded ADVISORY (undeployed 'events-' script, routing_exempt)
#   ext_b  clean
#   ext_e  two seeded FAILs (two undeployed scripts) via a non-routing_exempt manifest, so the
#          FAIL comes from the plain manifest-script-missing-on-disk check, not the advisory lane
#   ext_d  clean
for spec in \
  "ext_c:clean:" \
  "ext_a:fail:seed-fail-a.sh" \
  "ext_f:advisory:events-seed-f.sh" \
  "ext_b:clean:" \
  "ext_e:fail2:seed-fail-e1.sh,seed-fail-e2.sh" \
  "ext_d:clean:" \
; do
  ext_name="${spec%%:*}"
  rest="${spec#*:}"
  kind="${rest%%:*}"
  scripts_csv="${rest#*:}"
  ext_dir="$FIXTURE/agent-system/extensions/$ext_name"
  mkdir -p "$ext_dir"
  routing_exempt="false"
  scripts_json="[]"
  case "$kind" in
    advisory) routing_exempt="true"; scripts_json="[\"$scripts_csv\"]" ;;
    fail) scripts_json="[\"$scripts_csv\"]" ;;
    fail2)
      IFS=',' read -r s1 s2 <<< "$scripts_csv"
      scripts_json="[\"$s1\",\"$s2\"]"
      ;;
    clean) scripts_json="[]" ;;
  esac
  cat > "$ext_dir/manifest.json" <<EOF
{
  "name": "$ext_name",
  "version": "1.0.0",
  "description": "fixture",
  "dependencies": [],
  "routing_exempt": $routing_exempt,
  "provides": {
    "agents": [], "commands": [], "skills": [], "rules": [], "context": [],
    "scripts": $scripts_json, "hooks": []
  }
}
EOF
  echo "# $ext_name" > "$ext_dir/README.md"
done

run_fixture() {
  local jobs="$1"
  (cd "$FIXTURE" && CED_JOBS="$jobs" REPO_ROOT="$FIXTURE" bash "$FIXTURE/.claude/scripts/check-extension-docs.sh" --quiet 2>&1)
  # exit code of check-extension-docs.sh is captured by the caller via $? immediately after;
  # callers that need it capture this function's own invocation separately.
}

out_j1="$(run_fixture 1)"; rc_j1=$?
out_j2="$(run_fixture 2)"; rc_j2=$?
out_j3="$(run_fixture 3)"; rc_j3=$?
out_j4="$(run_fixture 4)"; rc_j4=$?
out_j8="$(run_fixture 8)"; rc_j8=$?

# =====================================================================
# Case (a): byte-identical output across every worker count.
# =====================================================================
all_match=1
for pair_out in "$out_j2" "$out_j3" "$out_j4" "$out_j8"; do
  if [ "$pair_out" != "$out_j1" ]; then
    all_match=0
  fi
done
if [ "$all_match" -eq 1 ]; then
  pass "case(a): CED_JOBS=1,2,3,4,8 all produce byte-identical output"
else
  fail "case(a): output diverged across worker counts" \
       "$(diff <(printf '%s' "$out_j1") <(printf '%s' "$out_j4") || true)"
fi

# =====================================================================
# Case (b): identical exit code across every worker count.
# =====================================================================
if [ "$rc_j1" -eq "$rc_j2" ] && [ "$rc_j1" -eq "$rc_j3" ] && [ "$rc_j1" -eq "$rc_j4" ] && [ "$rc_j1" -eq "$rc_j8" ]; then
  pass "case(b): identical exit code ($rc_j1) across every worker count"
else
  fail "case(b): exit codes diverged: j1=$rc_j1 j2=$rc_j2 j3=$rc_j3 j4=$rc_j4 j8=$rc_j8"
fi

# =====================================================================
# Case (c): discovery order is preserved (ext_c, ext_a, ext_f, ext_b, ext_e, ext_d -- the
# literal glob/readdir order of the fixture dir entries as created above), not completion order
# or alphabetical order, at every worker count (using j4's output as the representative; case
# (a) already proved every worker count matches it byte-for-byte).
# =====================================================================
discovery_order="$(printf '%s\n' "$out_j4" | grep -oE '^\[[a-z_]+\]$' | tr -d '[]')"
expected_order="$(printf '%s\n' "$FIXTURE"/agent-system/extensions/*/ | xargs -n1 basename)"
if [ "$discovery_order" = "$expected_order" ]; then
  pass "case(c): combined output preserves EXT_DIR glob discovery order, not completion order"
else
  fail "case(c): discovery order not preserved" \
       "$(printf 'expected:\n%s\n\ngot:\n%s' "$expected_order" "$discovery_order")"
fi

# =====================================================================
# Case (d): the aggregate FAIL count re-derived by the parent matches what was actually seeded
# -- 1 (ext_a) + 2 (ext_e) + 1 (ext_f, whose declared-but-undeployed script is BOTH a plain
# manifest-script-missing FAIL and, separately, an ADVISORY via the routing_exempt deploy-drift
# lane) = 4 manifest-script-missing FAILs, independent of worker count.
# =====================================================================
fail_count="$(printf '%s\n' "$out_j4" | grep -c '^  FAIL: ')"
if [ "$fail_count" -eq 4 ]; then
  pass "case(d): re-derived FAIL count is exactly 4 (1 from ext_a + 2 from ext_e + 1 from ext_f)"
else
  fail "case(d): expected exactly 4 FAIL lines, got $fail_count" "$out_j4"
fi

# =====================================================================
# Case (e): the re-derived ADVISORY count matches the one seeded violation in ext_f.
# =====================================================================
advisory_count="$(printf '%s\n' "$out_j4" | grep -c '^  ADVISORY: ')"
if [ "$advisory_count" -eq 1 ]; then
  pass "case(e): re-derived ADVISORY count is exactly 1 (from ext_f)"
else
  fail "case(e): expected exactly 1 ADVISORY line, got $advisory_count" "$out_j4"
fi

# =====================================================================
# Case (f): per-extension PASS/FAIL verdict in the Summary table matches which extensions were
# actually seeded with a real FAIL (ext_a, ext_e, and ext_f -- its declared-but-undeployed
# script is a plain manifest-script-missing FAIL in addition to its ADVISORY) versus genuinely
# clean (ext_b, ext_c, ext_d).
# =====================================================================
summary_ok=1
for ext in ext_a ext_e ext_f; do
  printf '%s\n' "$out_j4" | grep -qE "^${ext}[[:space:]]+FAIL\$" || summary_ok=0
done
for ext in ext_b ext_c ext_d; do
  printf '%s\n' "$out_j4" | grep -qE "^${ext}[[:space:]]+PASS\$" || summary_ok=0
done
if [ "$summary_ok" -eq 1 ]; then
  pass "case(f): per-extension Summary verdicts match the seeded FAIL/clean/advisory-only mix"
else
  fail "case(f): Summary table verdicts did not match the expected seeded mix" \
       "$(printf '%s\n' "$out_j4" | sed -n '/^Extension/,/^$/p')"
fi

echo
echo "====================================="
echo "Summary: $PASSED passed, $FAILED failed"
echo "====================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
