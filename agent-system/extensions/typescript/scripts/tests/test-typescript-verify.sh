#!/usr/bin/env bash
# test-typescript-verify.sh -- regression suite for typescript-verify.sh's two-tier project
# detection (tier-1 cwd-local fast path, tier-2 bounded nested-project fallback search).
#
# Follows the core shell-test convention (see
# agent-system/extensions/core/scripts/tests/test-census-count.sh and the lean extension's
# test-lean-src-roots.sh): pass()/fail()/info() helpers, PASSED/FAILED integer counters,
# SCRIPT_DIR via $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd), mktemp -d workdir with a trap
# EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# HERMETIC: a stub npm/pnpm/yarn/bun is placed on PATH ahead of any real package manager for the
# entire run (every stub just echoes its own name+args and exits 0). No case invokes a real
# package manager, the network, or installs anything -- this suite is about the DISCOVERY logic
# (which project is found, how it is prefixed, how counters aggregate), not about the pass/fail
# behavior of an actual typecheck/test run, which is exercised with the real `eval`/`"$pm" run`
# machinery by this same script in plan-authoring-time manual fixtures, not re-litigated here.
#
# Mutation check (Case 3 / Case 4): if the bounded fallback search block were deleted entirely,
# Case 3 (no package.json at cwd, one discovered at a/b/) would FAIL -- it asserts the nested
# project IS discovered, prefixed, and verified, which a reverted fallback cannot produce. This
# is the suite's own direct evidence that Case 3 discriminates the fix rather than passing
# vacuously; see this phase's own plan Verification step, which performs exactly this revert as
# an independent check. Separately, if only the `-not -path '*/node_modules/*'` exclusion were
# dropped from the `find` invocation, Case 4 (the only package.json lives under node_modules/)
# would FAIL -- it asserts the terminal "no package.json found" SKIP line, which a package.json
# newly discovered under node_modules/ would contradict. Case 4 is therefore the assertion that
# kills a mutation dropping the node_modules exclusion specifically.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../typescript-verify.sh"
if [ ! -f "$TOOL_SRC" ]; then
  # Deployed-tree fallback: .claude/ flattens every extension's scripts/ (and scripts/tests/)
  # into one directory, so the sibling relationship between this test and the tool it covers is
  # preserved there too -- this fallback is reached only if the primary, source-store-relative
  # resolution above did not find the file on disk.
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
  TOOL_SRC="$REPO_ROOT/.claude/scripts/typescript-verify.sh"
fi

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected typescript-verify.sh at $SCRIPT_DIR/../typescript-verify.sh (source store) or a deployed .claude/scripts/typescript-verify.sh fallback" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required by typescript-verify.sh and is not on PATH" >&2
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

# ── Hermetic stub package managers ──────────────────────────────────────────────────────────
STUBBIN="$WORKDIR/.stubbin"
mkdir -p "$STUBBIN"
for stub_name in npm pnpm yarn bun; do
  cat > "$STUBBIN/$stub_name" <<'STUBEOF'
#!/usr/bin/env bash
echo "[stub-$(basename "$0")] $*"
exit 0
STUBEOF
  chmod +x "$STUBBIN/$stub_name"
done
export PATH="$STUBBIN:$PATH"

LAST_OUTPUT=""
LAST_RC=0

run_tool() {
  # run_tool <dir> -- runs the hook with cwd set to <dir>, capturing combined stdout+stderr.
  local dir="$1"
  LAST_OUTPUT="$(cd "$dir" && bash "$TOOL_SRC" 1 typescript "$dir" sess_test preflight 2>&1)"
  LAST_RC=$?
}

# =====================================================================
# Case 1: package.json at cwd -- fast path, no fallback search, output unchanged
# =====================================================================
CASE1="$WORKDIR/case1"
mkdir -p "$CASE1"
cat > "$CASE1/package.json" <<'EOF'
{"name":"case1","scripts":{"test":"echo ok"}}
EOF
run_tool "$CASE1"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify] running test: npm run test"* ]] \
  && [[ "$LAST_OUTPUT" != *"NOTICE"* ]] \
  && [[ "$LAST_OUTPUT" == *"summary: ran_pass=1 ran_fail=0 skipped_no_command=1"* ]]; then
  pass "Case 1: package.json at cwd uses the fast path with no fallback search"
else
  fail "Case 1: package.json at cwd uses the fast path with no fallback search -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 2: lockfile priority at cwd across all four lockfiles
# =====================================================================
for pair in "pnpm-lock.yaml:pnpm" "yarn.lock:yarn" "package-lock.json:npm" "bun.lockb:bun"; do
  lockfile="${pair%%:*}"
  expect_pm="${pair##*:}"
  dir="$WORKDIR/case2-$expect_pm"
  mkdir -p "$dir"
  touch "$dir/$lockfile"
  cat > "$dir/package.json" <<'EOF'
{"name":"case2","scripts":{"test":"echo ok"}}
EOF
  run_tool "$dir"
  if [ "$LAST_RC" -eq 0 ] && [[ "$LAST_OUTPUT" == *"running test: ${expect_pm} run test"* ]]; then
    pass "Case 2 (${lockfile}): resolves to ${expect_pm}"
  else
    fail "Case 2 (${lockfile}): expected ${expect_pm}, got: $LAST_OUTPUT"
  fi
done

# Priority ordering: all four lockfiles present together -- pnpm must win (checked first).
dir="$WORKDIR/case2-priority"
mkdir -p "$dir"
touch "$dir/pnpm-lock.yaml" "$dir/yarn.lock" "$dir/package-lock.json" "$dir/bun.lockb"
cat > "$dir/package.json" <<'EOF'
{"name":"case2p","scripts":{"test":"echo ok"}}
EOF
run_tool "$dir"
if [ "$LAST_RC" -eq 0 ] && [[ "$LAST_OUTPUT" == *"running test: pnpm run test"* ]]; then
  pass "Case 2 (priority): pnpm wins when all four lockfiles are present"
else
  fail "Case 2 (priority): expected pnpm to win, got: $LAST_OUTPUT"
fi

# =====================================================================
# Case 3: no package.json at cwd, one at a/b/ -- discovered, path-prefixed, typecheck SKIPped
# (no tsconfig fixture), test sub-check run
# =====================================================================
CASE3="$WORKDIR/case3"
mkdir -p "$CASE3/a/b"
cat > "$CASE3/a/b/package.json" <<'EOF'
{"name":"case3","scripts":{"test":"echo nested"}}
EOF
run_tool "$CASE3"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][a/b] SKIP: no tsconfig.json and no typecheck script found"* ]] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][a/b] running test: npm run test"* ]] \
  && [[ "$LAST_OUTPUT" == *"summary: ran_pass=1 ran_fail=0 skipped_no_command=1"* ]]; then
  pass "Case 3: nested project at a/b/ is discovered, path-prefixed, and verified"
else
  fail "Case 3: nested project at a/b/ is discovered, path-prefixed, and verified -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 4: the only package.json lives under node_modules/ -- NOT discovered, terminal SKIP
# preserved
# =====================================================================
CASE4="$WORKDIR/case4"
mkdir -p "$CASE4/node_modules/pkg"
cat > "$CASE4/node_modules/pkg/package.json" <<'EOF'
{"name":"case4"}
EOF
run_tool "$CASE4"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify] SKIP: no package.json found -- no Node/TypeScript project in scope, nothing to verify"* ]] \
  && [[ "$LAST_OUTPUT" == *"summary: ran_pass=0 ran_fail=0 skipped_no_command=1"* ]]; then
  pass "Case 4: a package.json reachable only through node_modules/ is never discovered"
else
  fail "Case 4: a package.json reachable only through node_modules/ is never discovered -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 5: nothing anywhere -- terminal SKIP line and summary byte-identical to today's
# =====================================================================
CASE5="$WORKDIR/case5"
mkdir -p "$CASE5"
run_tool "$CASE5"
EXPECTED5=$'[typescript-verify] SKIP: no package.json found -- no Node/TypeScript project in scope, nothing to verify\n[typescript-verify] summary: ran_pass=0 ran_fail=0 skipped_no_command=1'
if [ "$LAST_RC" -eq 0 ] && [ "$LAST_OUTPUT" = "$EXPECTED5" ]; then
  pass "Case 5: no package.json anywhere produces the byte-identical terminal SKIP + summary"
else
  fail "Case 5: no package.json anywhere produces the byte-identical terminal SKIP + summary -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 6: two nested projects -- counters aggregated across both
# =====================================================================
CASE6="$WORKDIR/case6"
mkdir -p "$CASE6/a" "$CASE6/c"
cat > "$CASE6/a/package.json" <<'EOF'
{"name":"case6a","scripts":{"test":"echo ok"}}
EOF
cat > "$CASE6/c/package.json" <<'EOF'
{"name":"case6c","scripts":{"test":"echo ok"}}
EOF
run_tool "$CASE6"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][a]"* ]] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][c]"* ]] \
  && [[ "$LAST_OUTPUT" == *"summary: ran_pass=2 ran_fail=0 skipped_no_command=2"* ]]; then
  pass "Case 6: two discovered projects aggregate their counters, each line naming its directory"
else
  fail "Case 6: two discovered projects aggregate their counters -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 7: package.json deeper than the depth bound -- deliberately not discovered
# =====================================================================
CASE7="$WORKDIR/case7"
mkdir -p "$CASE7/a/b/c/d/e"
cat > "$CASE7/a/b/c/d/e/package.json" <<'EOF'
{"name":"case7deep"}
EOF
run_tool "$CASE7"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"SKIP: no package.json found"* ]] \
  && [[ "$LAST_OUTPUT" != *"case7deep"* ]]; then
  pass "Case 7: a package.json deeper than the depth bound is not discovered"
else
  fail "Case 7: a package.json deeper than the depth bound is not discovered -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 8: npm placeholder test script at a nested project -- still rejected
# =====================================================================
CASE8="$WORKDIR/case8"
mkdir -p "$CASE8/x"
cat > "$CASE8/x/package.json" <<'EOF'
{"name":"case8","scripts":{"test":"echo \"Error: no test specified\" && exit 1"}}
EOF
run_tool "$CASE8"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][x] SKIP: no test script configured -- test verification not attempted"* ]] \
  && [[ "$LAST_OUTPUT" != *"[typescript-verify][x] running test:"* ]]; then
  pass "Case 8: the npm no-test-specified placeholder is rejected at a nested project too"
else
  fail "Case 8: the npm no-test-specified placeholder is rejected at a nested project too -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 9: malformed nested package.json -- warned, counted skipped, sibling projects still
# verified, exit 0
# =====================================================================
CASE9="$WORKDIR/case9"
mkdir -p "$CASE9/bad" "$CASE9/good"
echo '{not valid json' > "$CASE9/bad/package.json"
cat > "$CASE9/good/package.json" <<'EOF'
{"name":"case9good","scripts":{"test":"echo ok"}}
EOF
run_tool "$CASE9"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][bad] ERROR: package.json exists but is not valid JSON -- skipping"* ]] \
  && [[ "$LAST_OUTPUT" == *"[typescript-verify][good] running test: npm run test"* ]]; then
  pass "Case 9: a malformed nested package.json is skipped with a warning while siblings still verify, exit 0"
else
  fail "Case 9: a malformed nested package.json is skipped with a warning while siblings still verify, exit 0 -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Project cap: more than 10 discovered projects truncates with a loud notice (not one of the
# plan's nine enumerated cases, but directly asserts the cap task from this phase's own plan).
# =====================================================================
CASE_CAP="$WORKDIR/casecap"
mkdir -p "$CASE_CAP"
for i in $(seq 1 12); do
  mkdir -p "$CASE_CAP/proj$i"
  echo '{"name":"proj'"$i"'"}' > "$CASE_CAP/proj$i/package.json"
done
run_tool "$CASE_CAP"
if [ "$LAST_RC" -eq 0 ] \
  && [[ "$LAST_OUTPUT" == *"NOTICE: found 12 candidate projects"* ]] \
  && [[ "$LAST_OUTPUT" == *"INCOMPLETE"* ]]; then
  pass "Case cap: more than 10 discovered projects truncates with a loud NOTICE"
else
  fail "Case cap: more than 10 discovered projects truncates with a loud NOTICE -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

# =====================================================================
# Malformed cwd-local package.json keeps the unchanged exit-1 hook-input-error contract.
# =====================================================================
CASE_CWD_BAD="$WORKDIR/casecwdbad"
mkdir -p "$CASE_CWD_BAD"
echo '{not valid json' > "$CASE_CWD_BAD/package.json"
run_tool "$CASE_CWD_BAD"
if [ "$LAST_RC" -eq 1 ] && [[ "$LAST_OUTPUT" == *"ERROR: package.json exists but is not valid JSON -- this hook cannot run"* ]]; then
  pass "Case cwd-malformed: a malformed package.json at cwd still exits 1 (unchanged contract)"
else
  fail "Case cwd-malformed: a malformed package.json at cwd still exits 1 -- rc=$LAST_RC output=$LAST_OUTPUT"
fi

echo ""
info "Passed: $PASSED, Failed: $FAILED"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
