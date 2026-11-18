#!/usr/bin/env bash
# test-verify-touched.sh - Fixture-driven regression suite for scripts/verify-touched.sh (the
# touched-path entry point), scripts/lib/suite-resolver-lib.sh (the resolver interface), and
# scripts/lib/unmapped-fallback-lib.sh (the classified fallback) composed together through the
# one real entry point a caller actually runs.
#
# STRUCTURAL MODEL: test-gate8-suite-selection.sh's STUBBED-run-all.sh precedent (record every
# argument a real invocation received to a marker file beside the stub, so this suite asserts on
# verify-touched.sh's own CONSTRUCTED invocation directly rather than inferring it from a real,
# ~200-suite battery's output) combined with test-derived-artifact-probe-lib.sh's throwaway
# fixture-directory style. A self-contained sandbox mirrors the deployed layout
# ($SANDBOX/.claude/scripts/{verify-touched.sh,lib/*.sh,tests/{run-all.sh,test-*.sh,*.data}})
# built from REAL copies of the four subject files under test -- never the source store itself,
# and never the real ~200-suite corpus, which would make every case here pay minutes instead of
# milliseconds for no additional coverage (run-all.sh's OWN suite-discovery/scheduling/--class
# token-validation behaviour is already covered by test-run-all-selection.sh and
# test-gate8-suite-selection.sh; this suite's job is verify-touched.sh's OWN resolve/classify/
# invoke/report logic, which the stub exposes directly).
#
# Explicit deployed/source-store subject resolution, "deploy-tree-first" mode (see lib/common.sh
# for the resolver and declarer this uses): the main subject file is resolved once, then copied
# into the sandbox along with its three library dependencies; the sandbox copy is what every
# case actually executes.
#
# Non-vacuousness: every positive assertion below is paired with a contrasting case that would
# fail it if the underlying mechanism were broken -- a narrowed run's recorded args are checked
# for the PRESENCE of "--only", a full-sweep run's recorded args are checked for the ABSENCE of
# "--only" (Case G contrasts directly with Case D); a conforming declared backend is accepted
# (Case I) where a malformed one is refused (Case H), so the conformance gate is shown to do
# real work, not merely always refuse; a stub forced to report a suite failure (Case J) flips
# verify-touched.sh's own exit code and verdict wording, contrasting with every PASS case.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

VERIFY_TOUCHED_SRC="$(common_test_resolve_subject "verify-touched.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/verify-touched.sh" \
  "$SCRIPT_DIR/../verify-touched.sh")" || exit 2
common_test_declare_subject "$VERIFY_TOUCHED_SRC"
SUBJECT_SCRIPTS_DIR="$(cd "$(dirname "$VERIFY_TOUCHED_SRC")" && pwd)"

REQUIRED_LIB_SCRIPTS=(
  "verification-scope-lib.sh"
  "suite-selection-lib.sh"
  "suite-resolver-lib.sh"
  "unmapped-fallback-lib.sh"
)
for _vt_req in "${REQUIRED_LIB_SCRIPTS[@]}"; do
  if [ ! -f "${SUBJECT_SCRIPTS_DIR}/lib/${_vt_req}" ]; then
    echo "ERROR: expected ${SUBJECT_SCRIPTS_DIR}/lib/${_vt_req}" >&2
    exit 2
  fi
done
unset _vt_req

PASSED=0
FAILED=0
common_test_workdir_init

SANDBOX="$WORKDIR/sandbox"
TASKDIR="$WORKDIR/taskdir"
mkdir -p "$SANDBOX/.claude/scripts/lib" "$SANDBOX/.claude/scripts/tests" "$TASKDIR"

cp "$VERIFY_TOUCHED_SRC" "$SANDBOX/.claude/scripts/verify-touched.sh"
for _vt_req in "${REQUIRED_LIB_SCRIPTS[@]}"; do
  cp "${SUBJECT_SCRIPTS_DIR}/lib/${_vt_req}" "$SANDBOX/.claude/scripts/lib/${_vt_req}"
done
unset _vt_req

# Placeholder suite files: never run for real (run-all.sh itself is a stub below) -- they exist
# only so suite-selection-lib.sh's own basename-pairing/existence checks, and verify-touched.sh's
# own preflight existence check, find something real on disk.
: > "$SANDBOX/.claude/scripts/tests/test-foo.sh"
: > "$SANDBOX/.claude/scripts/tests/test-lint-fake.sh"

cat > "$SANDBOX/.claude/scripts/tests/suite-cost-hints.txt" << 'EOF'
test-foo.sh,10
EOF

printf 'agent-system/extensions/core/scripts/mapped/explicit-row.sh\ttest-foo.sh\tfixture map row\n' \
  > "$SANDBOX/.claude/scripts/tests/suite-selection-map.data"
printf 'agent-system/extensions/core/docs/*.md\ttest-lint-fake.sh\tfixture noclass row\n' \
  > "$SANDBOX/.claude/scripts/tests/suite-selection-noclass.data"

# STUBBED run-all.sh: records every argument received (one per line) to .stub-received-args
# beside itself, writes a plausible per-suite --timings CSV when --timings names a file, and
# exits 1 (naming a seeded failure) only when .stub-force-fail exists -- otherwise exits 0.
cat > "$SANDBOX/.claude/scripts/tests/run-all.sh" << 'STUBEOF'
#!/usr/bin/env bash
set -uo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' "$@" > "$SELF_DIR/.stub-received-args"
timings_file=""
args=("$@")
for ((_i = 0; _i < ${#args[@]}; _i++)); do
  if [ "${args[$_i]}" = "--timings" ]; then
    timings_file="${args[$((_i + 1))]}"
  fi
done
if [ -n "$timings_file" ]; then
  {
    echo "test-foo.sh,42,PASS"
    echo "TOTAL,42,1/0/0/1"
  } > "$timings_file"
fi
if [ -f "$SELF_DIR/.stub-force-fail" ]; then
  echo "[run-all] Failing suites (1):"
  echo "    stub-seeded-suite"
  echo "[run-all] 0 passed, 1 failed (0 expected, 1 NEW), 0 skipped, 1 total"
  exit 1
fi
echo "stub: all discovered suites passed (not real -- see test-verify-touched.sh)"
exit 0
STUBEOF
chmod +x "$SANDBOX/.claude/scripts/tests/run-all.sh"

run_vt() {
  ( cd "$SANDBOX" && bash .claude/scripts/verify-touched.sh --jobs 1 \
      --task-dir "$TASKDIR" --session sess_test --dispatch-seq 1 "$@" )
}

stub_args_file="$SANDBOX/.claude/scripts/tests/.stub-received-args"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case A: preflight refuses a malformed map-data row (not exactly 3 TAB fields) before any
# suite runs.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
printf 'malformed-row-no-tabs-at-all\n' > "$WORKDIR/bad-map-malformed.data"
A_OUT="$(SUITE_RESOLVER_MAP_DATA="$WORKDIR/bad-map-malformed.data" run_vt "agent-system/extensions/core/scripts/mapped/explicit-row.sh" 2>&1)"
A_RC=$?
if [ "$A_RC" -eq 2 ] && printf '%s' "$A_OUT" | grep -qF "FINDING preflight"; then
  common_test_pass "Case A: malformed map row refused by preflight (exit 2, named FINDING)"
else
  common_test_fail "Case A: expected exit 2 + FINDING, got rc=$A_RC output=<<<$A_OUT>>>"
fi
if [ ! -f "$stub_args_file" ]; then
  common_test_pass "Case A: no suite ran (stub never invoked)"
else
  common_test_fail "Case A: stub was invoked despite preflight failure"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case B: preflight refuses a map row naming a suite that does not exist on disk.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
printf 'some/path.sh\ttest-does-not-exist-anywhere.sh\tbad row\n' > "$WORKDIR/bad-map-missing-suite.data"
B_OUT="$(SUITE_RESOLVER_MAP_DATA="$WORKDIR/bad-map-missing-suite.data" run_vt "agent-system/extensions/core/scripts/mapped/explicit-row.sh" 2>&1)"
B_RC=$?
if [ "$B_RC" -eq 2 ] && printf '%s' "$B_OUT" | grep -qF "test-does-not-exist-anywhere.sh"; then
  common_test_pass "Case B: map row naming a nonexistent suite refused by preflight, names the suite"
else
  common_test_fail "Case B: expected exit 2 naming the missing suite, got rc=$B_RC output=<<<$B_OUT>>>"
fi
if [ ! -f "$stub_args_file" ]; then
  common_test_pass "Case B: no suite ran (stub never invoked)"
else
  common_test_fail "Case B: stub was invoked despite preflight failure"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case C: preflight refuses when the declared OWED fallback cost-class resolves to an empty set.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
C_OUT="$(UNMAPPED_FALLBACK_COST_CLASS="slow" run_vt "agent-system/extensions/core/scripts/mapped/explicit-row.sh" 2>&1)"
C_RC=$?
if [ "$C_RC" -eq 2 ] && printf '%s' "$C_OUT" | grep -qF "fallback set"; then
  common_test_pass "Case C: empty declared OWED fallback set refused by preflight"
else
  common_test_fail "Case C: expected exit 2 naming the empty fallback set, got rc=$C_RC output=<<<$C_OUT>>>"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case D: a one-file edit to a basename-mapped source file executes a strict subset (the SELECT
# roster matches the resolver output exactly) and the verdict says so.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
D_OUT="$(run_vt "agent-system/extensions/core/scripts/lib/foo.sh" 2>&1)"
D_RC=$?
if [ "$D_RC" -eq 0 ] && printf '%s' "$D_OUT" | grep -qF "test-foo.sh"; then
  common_test_pass "Case D: resolved SELECT roster names test-foo.sh"
else
  common_test_fail "Case D: expected test-foo.sh in SELECT roster, got rc=$D_RC output=<<<$D_OUT>>>"
fi
if [ -f "$stub_args_file" ] && grep -qF -- "--only" "$stub_args_file" && grep -qF "test-foo.sh" "$stub_args_file"; then
  common_test_pass "Case D: stub invoked with --only naming test-foo.sh (strict subset, not a full sweep)"
else
  common_test_fail "Case D: stub args did not show a narrowed --only test-foo.sh invocation: $(cat "$stub_args_file" 2>/dev/null)"
fi
if printf '%s' "$D_OUT" | grep -qF "touched-path narrowed via verify-touched.sh, NOT a full-battery pass"; then
  common_test_pass "Case D: verdict says touched-path narrowed, not a full-battery pass"
else
  common_test_fail "Case D: verdict string missing or wrong: <<<$D_OUT>>>"
fi
if printf '%s' "$D_OUT" | grep -qE "^verify-touched\.sh: timings file"; then
  common_test_pass "Case D: timings path is printed"
else
  common_test_fail "Case D: timings path line missing: <<<$D_OUT>>>"
fi
D_TIMINGS_PATH="$(printf '%s\n' "$D_OUT" | sed -n 's/^verify-touched\.sh: timings file (diagnostic-only; NOT an input to suite-cost-hints\.txt): //p' | head -1)"
if [ -n "$D_TIMINGS_PATH" ] && [ -f "${D_TIMINGS_PATH}.root.main" ] && grep -qF "test-foo.sh,42,PASS" "${D_TIMINGS_PATH}.root.main"; then
  common_test_pass "Case D: timings file contains the per-suite row run-all.sh writes"
else
  common_test_fail "Case D: timings file missing or lacks the expected per-suite row (path='${D_TIMINGS_PATH}')"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case E: an explicit map row resolves a path basename pairing alone would miss.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
E_OUT="$(run_vt "agent-system/extensions/core/scripts/mapped/explicit-row.sh" 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$E_OUT" | grep -qF "test-foo.sh" && [ -f "$stub_args_file" ] && grep -qF "test-foo.sh" "$stub_args_file"; then
  common_test_pass "Case E: explicit map row (EXPLICIT MAP ROW outcome) resolves to test-foo.sh"
else
  common_test_fail "Case E: expected map-row resolution to test-foo.sh, got output=<<<$E_OUT>>>"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case F: a path matching the NO-SUITE-BY-CLASS data classifies and runs only the named lint.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
F_OUT="$(run_vt "agent-system/extensions/core/docs/brand-new-prose-file.md" 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$F_OUT" | grep -qF "NO-SUITE-BY-CLASS" && printf '%s' "$F_OUT" | grep -qF "test-lint-fake.sh"; then
  common_test_pass "Case F: NO-SUITE-BY-CLASS outcome names test-lint-fake.sh"
else
  common_test_fail "Case F: expected NO-SUITE-BY-CLASS naming test-lint-fake.sh, got output=<<<$F_OUT>>>"
fi
if [ -f "$stub_args_file" ] && grep -qF "test-lint-fake.sh" "$stub_args_file" && ! grep -qF "test-foo.sh" "$stub_args_file"; then
  common_test_pass "Case F: stub invoked with only the no-class lint, not the unrelated mapped suite"
else
  common_test_fail "Case F: stub args wrong: $(cat "$stub_args_file" 2>/dev/null)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case G: a genuinely unmapped path (no suite, no map row, no class row) is OWED-NOT-PAID: runs
# the --cost-class fallback set, writes exactly one owed record, and a re-classification of the
# SAME path does not duplicate it or discharge it (owed survives until a discharge run clears
# it -- that discharge mechanism belongs to scripts/orchestrate-batch-gate.sh, not this entry
# point, so "survives" here means verify-touched.sh itself never clears discharged_ts).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
rm -rf "$TASKDIR/records"
G_OUT="$(run_vt "totally/unmapped/unknown/path.sh" 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$G_OUT" | grep -qF "OWED"; then
  common_test_pass "Case G: genuinely unmapped path classifies OWED"
else
  common_test_fail "Case G: expected OWED classification, got output=<<<$G_OUT>>>"
fi
if [ -f "$stub_args_file" ] && grep -qF -- "--cost-class" "$stub_args_file" && grep -qF -- "free" "$stub_args_file" && ! grep -qF -- "--only" "$stub_args_file"; then
  common_test_pass "Case G: stub's second invocation ran the --cost-class fallback set alone (never --only)"
else
  common_test_fail "Case G: expected a bare --cost-class free invocation, got: $(cat "$stub_args_file" 2>/dev/null)"
fi
OWED_FILE="$TASKDIR/records/full-sweep-owed.jsonl"
OWED_ROWS="$(wc -l < "$OWED_FILE" 2>/dev/null || echo 0)"
if [ "$OWED_ROWS" -eq 1 ] && grep -qF '"discharged_ts":null' "$OWED_FILE"; then
  common_test_pass "Case G: exactly one open owed record written"
else
  common_test_fail "Case G: expected exactly one open owed row, got $OWED_ROWS row(s): $(cat "$OWED_FILE" 2>/dev/null)"
fi
run_vt "totally/unmapped/unknown/path.sh" >/dev/null 2>&1
OWED_ROWS_AFTER="$(wc -l < "$OWED_FILE" 2>/dev/null || echo 0)"
if [ "$OWED_ROWS_AFTER" -eq 1 ] && grep -qF '"discharged_ts":null' "$OWED_FILE"; then
  common_test_pass "Case G: re-classifying the same owed path does not duplicate the row, and it survives open"
else
  common_test_fail "Case G: expected the owed row to stay a single open row after re-classification, got $OWED_ROWS_AFTER row(s)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case H: a declared resolver backend that violates the output shape is REFUSED by the
# conformance check before its output is ever trusted (preflight failure).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$SANDBOX/bad-backend.sh" << 'EOF'
#!/usr/bin/env bash
cat >/dev/null
echo "this line matches neither SELECT nor UNRESOLVED"
exit 0
EOF
chmod +x "$SANDBOX/bad-backend.sh"
printf '{"verification_scope":{"resolver":{"command":"bash %s/bad-backend.sh"}}}\n' "$SANDBOX" > "$SANDBOX/.claude-extensions.json"
rm -f "$stub_args_file"
H_OUT="$(run_vt "agent-system/extensions/core/scripts/lib/foo.sh" 2>&1)"
H_RC=$?
if [ "$H_RC" -eq 2 ] && printf '%s' "$H_OUT" | grep -qF "REFUSED"; then
  common_test_pass "Case H: malformed declared backend refused by the conformance check (preflight failure)"
else
  common_test_fail "Case H: expected exit 2 naming REFUSED, got rc=$H_RC output=<<<$H_OUT>>>"
fi
if [ ! -f "$stub_args_file" ]; then
  common_test_pass "Case H: no suite ran (refused before resolution)"
else
  common_test_fail "Case H: stub was invoked despite the declared backend being non-conforming"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case I: a CONFORMING declared backend is accepted and composed (union) with the default
# backend -- the conformance gate does real work, not merely always refuse.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat > "$SANDBOX/good-backend.sh" << 'EOF'
#!/usr/bin/env bash
cat >/dev/null
echo "SELECT test-declared-backend-suite.sh"
exit 0
EOF
chmod +x "$SANDBOX/good-backend.sh"
: > "$SANDBOX/.claude/scripts/tests/test-declared-backend-suite.sh"
printf '{"verification_scope":{"resolver":{"command":"bash %s/good-backend.sh","compose":"union"}}}\n' "$SANDBOX" > "$SANDBOX/.claude-extensions.json"
rm -f "$stub_args_file"
I_OUT="$(run_vt "agent-system/extensions/core/scripts/lib/foo.sh" 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$I_OUT" | grep -qF "test-declared-backend-suite.sh" && printf '%s' "$I_OUT" | grep -qF "test-foo.sh"; then
  common_test_pass "Case I: conforming declared backend accepted and unioned with the default backend"
else
  common_test_fail "Case I: expected both test-foo.sh (default) and test-declared-backend-suite.sh (declared) in output: <<<$I_OUT>>>"
fi
rm -f "$SANDBOX/.claude-extensions.json"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case J: --full-sweep restores the unnarrowed behaviour (no --only in the recorded invocation)
# and labels itself distinctly from the narrowed verdict (Case D above).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$stub_args_file"
J_OUT="$(run_vt --full-sweep "agent-system/extensions/core/scripts/lib/foo.sh" 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$J_OUT" | grep -qF "full-sweep requested -- ran the complete, unnarrowed battery" && printf '%s' "$J_OUT" | grep -qF "this IS a full-battery pass"; then
  common_test_pass "Case J: --full-sweep labels itself as a full-battery pass"
else
  common_test_fail "Case J: expected the --full-sweep verdict wording, got <<<$J_OUT>>>"
fi
if [ -f "$stub_args_file" ] && ! grep -qF -- "--only" "$stub_args_file"; then
  common_test_pass "Case J: --full-sweep invocation never carries --only (contrasts with Case D)"
else
  common_test_fail "Case J: --full-sweep invocation unexpectedly carried --only: $(cat "$stub_args_file" 2>/dev/null)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case K: when the underlying battery genuinely fails, verify-touched.sh's own exit code and
# verdict wording flip accordingly -- the PASS-path assertions above are not vacuously true
# regardless of the real result.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
: > "$SANDBOX/.claude/scripts/tests/.stub-force-fail"
K_OUT="$(run_vt "agent-system/extensions/core/scripts/lib/foo.sh" 2>&1)"
K_RC=$?
rm -f "$SANDBOX/.claude/scripts/tests/.stub-force-fail"
if [ "$K_RC" -ne 0 ] && printf '%s' "$K_OUT" | grep -qF "touched-path run reported a failure"; then
  common_test_pass "Case K: a genuine suite failure flips verify-touched.sh's own exit code and verdict wording"
else
  common_test_fail "Case K: expected a nonzero exit and failure wording, got rc=$K_RC output=<<<$K_OUT>>>"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case L: the verdict strings are byte-distinct from both pre-existing pass strings (static
# check against the real source files, not the fixture -- same claim Phase 4 verified by hand).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Comment lines (this file's own header, correctly DISCUSSING the distinction) are excluded --
# only actual emitted ("echo ...") lines matter for byte-distinctness.
VT_NONCOMMENT="$(grep -vE '^\s*#' "$VERIFY_TOUCHED_SRC")"
if ! printf '%s' "$VT_NONCOMMENT" | grep -qF "all discovered suites passed" \
   && ! printf '%s' "$VT_NONCOMMENT" | grep -qF "narrowed by --gate8-touched -- NOT a full-battery pass"; then
  common_test_pass "Case L: verify-touched.sh's own emitted lines never reproduce either pre-existing pass string verbatim"
else
  common_test_fail "Case L: verify-touched.sh's emitted lines unexpectedly contain a pre-existing pass string verbatim"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
