#!/usr/bin/env bash
# test-lean-challenge-snapshot.sh -- regression suite for lean-challenge-snapshot.sh.
#
# Covers the acceptance-relevant regression concerns for the Challenge-statement snapshot tool:
#
# (1) R1 extraction and cross-validation (Cases R1, R2, R4): a plan carrying a
# `## Lean Challenge Statements` section is assembled and forced to `sorry` correctly; an
# identifier-set mismatch between that section and `**Goals**:` is a hard 71 naming the specific
# offending identifier(s); a name resolvable by neither R1 nor R2 is a hard 71 naming that
# identifier, with NO partial Challenge emitted.
#
# (2) R2 legacy fallback (Case R3): a plan with no `## Lean Challenge Statements` section falls
# back to extracting an existing sorried declaration from the target project's git tree, and
# prints the mandatory, unmissable degradation notice.
#
# (3) Commit/manifest/immutability (Cases M1-M3): a snapshot at `planned` commits the Challenge
# and records a manifest with a real commit SHA; re-running past `planned` without `--force`
# refuses with exit 73 and leaves the working tree unchanged; `--force` past `planned` succeeds
# but prints the incident-shaped warning, and the ORIGINAL commit's content is unaffected.
#
# (4) `--check` statement-drift mode (Cases C1-C4): a weakened statement is flagged (65, naming
# only the drifted theorem); an honest re-implementation is not (0); a cosmetically reformatted
# but semantically identical statement is not (0, no false positive); an identifier missing from
# the current tree is distinguishable (71) from a drift finding (65).
#
# Anti-vacuous-test guard (Case AV1, carrying test-lean-comparator-run.sh's and
# test-lean-sorry-census.sh's own discipline): a naive "exit code non-zero means bad" classifier
# is asserted to DISAGREE with this tool's classification on the drift (65) vs config-error (71)
# fixtures -- both are non-zero, so a vacuous suite that only checked "exit code == 0" could not
# tell a real drift finding apart from an authoring/config mistake. This proves the exit-code
# vocabulary is doing real work, not just signalling generic failure.
#
# Follows the core shell-test convention (see test-lean-comparator-run.sh and
# test-lean-sorry-census.sh): pass()/fail()/info()/skip() helpers, PASSED/FAILED counters,
# mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS (skips do not count as failures); 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../lean-challenge-snapshot.sh"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/challenge"

PASSED=0
FAILED=0
SKIPPED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }
skip() { echo "[SKIP] $1"; SKIPPED=$((SKIPPED + 1)); }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected lean-challenge-snapshot.sh at $TOOL_SRC" >&2
  exit 1
fi
if [ ! -d "$FIXTURES_DIR" ]; then
  echo "ERROR: expected fixtures at $FIXTURES_DIR" >&2
  exit 1
fi

for dep in python3 git sha256sum; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "ERROR: $dep is required by this suite and is not on PATH" >&2
    exit 1
  fi
done

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Shared fixture helpers
# ---------------------------------------------------------------------------

# make_repo <name> <task_number> <plan_fixture> -- a throwaway git repo with a plan at
# specs/<padded>_proj/plans/01_test.md (task-number substituted in for {N}) and a state.json
# entry at status "planned". Prints the repo path.
make_repo() {
  local name="$1" task_number="$2" plan_fixture="$3"
  local dir="$WORKDIR/repo-$name"
  local padded
  padded=$(printf '%03d' "$task_number")
  mkdir -p "$dir/specs/${padded}_proj/plans"
  sed "s/{N}/$task_number/" "$FIXTURES_DIR/$plan_fixture" > "$dir/specs/${padded}_proj/plans/01_test.md"
  cat > "$dir/specs/state.json" <<EOF
{"active_projects":[{"project_number": $task_number, "project_name": "proj", "status": "planned"}]}
EOF
  ( cd "$dir" \
    && git init -q \
    && git config user.email test@test.com \
    && git config user.name test \
    && git add specs/ \
    && git commit -q -m "init" )
  echo "$dir"
}

set_status() {
  local repo="$1" task_number="$2" status="$3"
  python3 -c "
import json
path = '$repo/specs/state.json'
with open(path) as f:
    d = json.load(f)
for e in d['active_projects']:
    if e['project_number'] == $task_number:
        e['status'] = '$status'
with open(path, 'w') as f:
    json.dump(d, f)
"
}


# run_tool <repo> [args...] -- invokes the tool with CWD set to <repo>, matching the tool's own
# documented convention (specs/ is resolved relative to the invocation directory).
run_tool() {
  local d="$1"
  shift
  ( cd "$d" && bash "$TOOL_SRC" "$@" )
}

# ===========================================================================
# Case R1: R1 extraction (--dry-run)
# ===========================================================================
repo=$(make_repo "r1" 901 plan_r1.md)
out=$(run_tool "$repo" 901 "$repo" --dry-run 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "theorem_names: comm" && echo "$out" | grep -q ":= sorry"; then
  pass "R1: --dry-run assembles the Challenge module with theorem_names=comm and a forced sorry body"
else
  fail "R1: unexpected output (rc=$rc): $out"
fi

# ===========================================================================
# Case R2: identifier-set mismatch -> 71, names the offending identifier
# ===========================================================================
repo=$(make_repo "r2" 902 plan_mismatched.md)
out=$(run_tool "$repo" 902 "$repo" --dry-run 2>&1)
rc=$?
if [ "$rc" -eq 71 ] && echo "$out" | grep -q "assoc"; then
  pass "R2: identifier-set mismatch exits 71 and names 'assoc'"
else
  fail "R2: expected exit 71 naming 'assoc', got rc=$rc: $out"
fi

# ===========================================================================
# Case R3: R2 legacy fallback success + degradation notice
# ===========================================================================
# Built manually (not via make_repo) so the baseline .lean declaration and the plan land in the
# SAME commit -- R2 resolves declarations at "the plan's approval commit"
# (`git log -1 -- <plan_path>`), so a baseline added in a LATER commit would not be visible there.
repo="$WORKDIR/repo-r3"
mkdir -p "$repo/specs/903_proj/plans" "$repo/Theories"
sed "s/{N}/903/" "$FIXTURES_DIR/plan_legacy.md" > "$repo/specs/903_proj/plans/01_test.md"
cat > "$repo/specs/state.json" <<'EOF'
{"active_projects":[{"project_number": 903, "project_name": "proj", "status": "planned"}]}
EOF
cat > "$repo/Theories/Basic.lean" <<'EOF'
import Mathlib.Algebra.Group.Basic

theorem comm (n m : Nat) : n + m = m + n := by
  sorry
EOF
( cd "$repo" \
  && git init -q \
  && git config user.email test@test.com \
  && git config user.name test \
  && git add specs/ Theories/ \
  && git commit -q -m "init" )
out=$(run_tool "$repo" 903 "$repo" --dry-run 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "DEGRADED FALLBACK" && echo "$out" | grep -q "route: git-baseline" && echo "$out" | grep -q ":= sorry"; then
  pass "R3: R2 fallback succeeds, prints the degradation notice, and forces sorry"
else
  fail "R3: expected R2 fallback success with degradation notice, got rc=$rc: $out"
fi

# ===========================================================================
# Case R4: greenfield unresolvable (neither R1 nor R2) -> 71, no partial Challenge
# ===========================================================================
repo=$(make_repo "r4" 904 plan_legacy.md)
# No Theories/ tree at all -- 'comm' resolvable by neither R1 (no section) nor R2 (no declaration).
out=$(run_tool "$repo" 904 "$repo" --dry-run 2>&1)
rc=$?
if [ "$rc" -eq 71 ] && echo "$out" | grep -q "comm" && ! echo "$out" | grep -q "^theorem"; then
  pass "R4: greenfield unresolvable identifier exits 71 naming it, no Challenge content emitted"
else
  fail "R4: expected exit 71 naming 'comm' with no Challenge content, got rc=$rc: $out"
fi

# ===========================================================================
# Case R5: mixed-case identifiers -- ambient-locale dictionary sort on the goals side vs.
# code-point sort on the declared side must not produce a false identifier-set mismatch.
#
# Mutation this case kills: removing the `LC_ALL=C` pin from the goals-side `sort -u` in
# extract_goal_names() (with or without also removing the `comm` pins) turns this case RED --
# under a UTF-8 dictionary-collation locale the goals list sorts as
# hnOpenMirror, hn_stab, hnStabMirror while the declared list (Python sorted(), code-point order)
# is hnOpenMirror, hnStabMirror, hn_stab. `comm` assumes both inputs share one collation, so the
# unpinned run exits 71 naming 'hn_stab'/'hnStabMirror' as spuriously mismatched on both sides.
# ===========================================================================
r5_locale=""
for candidate in en_US.UTF-8 en_US.utf8; do
  if locale -a 2>/dev/null | grep -qix "$candidate"; then
    r5_locale="$candidate"
    break
  fi
done
if [ -z "$r5_locale" ]; then
  skip "R5: no UTF-8 dictionary-collation locale (en_US.UTF-8/en_US.utf8) available on this system"
else
  repo=$(make_repo "r5" 908 plan_mixed_case.md)
  out=$(cd "$repo" && LC_ALL="$r5_locale" bash "$TOOL_SRC" 908 "$repo" --dry-run 2>&1)
  rc=$?
  out_c=$(cd "$repo" && LC_ALL=C bash "$TOOL_SRC" 908 "$repo" --dry-run 2>&1)
  rc_c=$?
  if [ "$rc" -eq 0 ] \
    && ! echo "$out" | grep -q "identifier-set mismatch" \
    && ! echo "$out" | grep -qi "^comm:" \
    && echo "$out" | grep -q "theorem_names:.*hnOpenMirror" \
    && echo "$out" | grep -q "theorem_names:.*hnStabMirror" \
    && echo "$out" | grep -q "theorem_names:.*hn_stab" \
    && [ "$rc_c" -eq 0 ] \
    && [ "$out" = "$out_c" ]; then
    pass "R5: mixed-case identifiers under a dictionary-collation locale exit 0 with all three names present, byte-identical to the LC_ALL=C run"
  else
    fail "R5: expected exit 0 with all three mixed-case names under $r5_locale, byte-identical to LC_ALL=C, got rc=$rc rc_c=$rc_c: $out"
  fi
fi

# ===========================================================================
# Case M1: commit + manifest + SHA round-trip
# ===========================================================================
repo=$(make_repo "m1" 905 plan_r1.md)
out=$(run_tool "$repo" 905 "$repo" 2>&1)
rc=$?
manifest="$repo/specs/905_proj/challenge/manifest.json"
if [ "$rc" -eq 0 ] && [ -f "$manifest" ]; then
  sha=$(python3 -c "import json; print(json.load(open('$manifest'))['commit'])")
  committed=$(git -C "$repo" show "${sha}:Challenge.lean" 2>/dev/null)
  if [ -n "$sha" ] && echo "$committed" | grep -q ":= sorry"; then
    pass "M1: snapshot commits the Challenge and the manifest's SHA retrieves exactly that content"
  else
    fail "M1: manifest SHA did not retrieve the expected committed content"
  fi
else
  fail "M1: expected a successful snapshot with a manifest, got rc=$rc: $out"
fi

# ===========================================================================
# Case M2: status gate refusal -> 73, working tree unchanged
# ===========================================================================
repo=$(make_repo "m2" 906 plan_r1.md)
run_tool "$repo" 906 "$repo" >/dev/null 2>&1
set_status "$repo" 906 implementing
before_status=$(git -C "$repo" status --porcelain)
out=$(run_tool "$repo" 906 "$repo" 2>&1)
rc=$?
after_status=$(git -C "$repo" status --porcelain)
if [ "$rc" -eq 73 ] && echo "$out" | grep -q "implementing" && [ "$before_status" = "$after_status" ]; then
  pass "M2: status-gate refusal exits 73, names the status, and leaves the working tree unchanged"
else
  fail "M2: expected exit 73 with unchanged working tree, got rc=$rc: $out"
fi

# ===========================================================================
# Case M3: --force incident warning; original SHA content survives the bypass
# ===========================================================================
original_sha=$(python3 -c "import json; print(json.load(open('$repo/specs/906_proj/challenge/manifest.json'))['commit'])")
out=$(run_tool "$repo" 906 "$repo" --force 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -qi "INCIDENT" && echo "$out" | grep -q "906"; then
  survived=$(git -C "$repo" show "${original_sha}:Challenge.lean" 2>/dev/null)
  if echo "$survived" | grep -q ":= sorry"; then
    pass "M3: --force past 'planned' succeeds with an incident warning; original SHA content survives"
  else
    fail "M3: original SHA content did not survive the --force bypass"
  fi
else
  fail "M3: expected --force to succeed with an incident warning, got rc=$rc: $out"
fi

# ===========================================================================
# Cases C1-C4: --check statement-drift mode
# ===========================================================================
check_repo=$(make_repo "check" 907 plan_r1.md)
run_tool "$check_repo" 907 "$check_repo" >/dev/null 2>&1
mkdir -p "$check_repo/Theories"

# C1: weakened -> 65
cp "$FIXTURES_DIR/solution_weakened.lean" "$check_repo/Theories/Basic.lean"
out=$(run_tool "$check_repo" --check 907 "$check_repo" 2>&1)
c1_rc=$?
if [ "$c1_rc" -eq 65 ] && echo "$out" | grep -q "comm"; then
  pass "C1: weakened statement exits 65, naming 'comm'"
else
  fail "C1: expected exit 65 naming 'comm' for the weakened case, got rc=$c1_rc: $out"
fi

# C2: honest -> 0
cp "$FIXTURES_DIR/solution_honest.lean" "$check_repo/Theories/Basic.lean"
out=$(run_tool "$check_repo" --check 907 "$check_repo" 2>&1)
c2_rc=$?
if [ "$c2_rc" -eq 0 ]; then
  pass "C2: honest re-implementation exits 0 (no drift)"
else
  fail "C2: expected exit 0 for the honest case, got rc=$c2_rc: $out"
fi

# C3: cosmetic reformat -> 0 (no false positive)
cp "$FIXTURES_DIR/solution_cosmetic.lean" "$check_repo/Theories/Basic.lean"
out=$(run_tool "$check_repo" --check 907 "$check_repo" 2>&1)
c3_rc=$?
if [ "$c3_rc" -eq 0 ]; then
  pass "C3: cosmetically reformatted statement exits 0 (no false positive)"
else
  fail "C3: expected exit 0 for the cosmetic case, got rc=$c3_rc: $out"
fi

# C4: missing identifier -> 71, distinguishable from 65
rm -f "$check_repo/Theories/Basic.lean"
out=$(run_tool "$check_repo" --check 907 "$check_repo" 2>&1)
c4_rc=$?
if [ "$c4_rc" -eq 71 ] && echo "$out" | grep -q "comm"; then
  pass "C4: identifier missing from the current tree exits 71, naming 'comm'"
else
  fail "C4: expected exit 71 naming 'comm' for the missing case, got rc=$c4_rc: $out"
fi

before_porcelain=$(git -C "$check_repo" status --porcelain)
run_tool "$check_repo" --check 907 "$check_repo" >/dev/null 2>&1 || true
after_porcelain=$(git -C "$check_repo" status --porcelain)
if [ "$before_porcelain" = "$after_porcelain" ]; then
  pass "C5: --check is read-only -- git status --porcelain is unchanged across a --check run"
else
  fail "C5: --check mutated the working tree"
fi

# ===========================================================================
# Case AV1: anti-vacuous-test guard -- a naive exit-code-only classifier cannot distinguish
# the 65 (drift) case from the 71 (config-error) case; both are simply "non-zero".
# ===========================================================================
if [ "${c1_rc:-}" != "0" ] && [ "${c4_rc:-}" != "0" ] && [ "$c1_rc" != "$c4_rc" ]; then
  naive_c1="bad"; naive_c4="bad"
  if [ "$naive_c1" = "$naive_c4" ]; then
    pass "AV1: a naive exit-code-nonzero classifier cannot distinguish drift (65) from config-error (71) -- this suite's own exit-code-VALUE assertions above are doing the real work"
  else
    fail "AV1: naive classifier unexpectedly distinguished the two cases"
  fi
else
  fail "AV1: precondition failed -- c1_rc=$c1_rc c4_rc=$c4_rc (expected two distinct non-zero codes)"
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "================================================================================"
echo "Results: $PASSED passed, $FAILED failed, $SKIPPED skipped"
echo "================================================================================"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
