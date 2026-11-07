#!/usr/bin/env bash
# test-script-inventory.sh - Fixture-driven regression suite for script-inventory.sh.
#
# Cases:
#   Enumeration    -- a fixture with one real script, one tests/-dir script, and one flat
#                     test-*.sh script. Asserts only the real script is enumerated.
#   Size metrics   -- line/byte counts for a fixture file with a known, deliberately-crafted
#                     content match wc -l / wc -c exactly.
#   Caller counting -- a fixture where script B's content references script A's basename.
#                     Asserts A's inbound_callers excludes A itself and includes B, and that B
#                     (referenced by nothing) reports zero_caller_finding == true.
#   has_test (true)  -- a script paired with tests/test-<basename> reports has_test == true and
#                     test_paths naming that file.
#   has_test (false) -- a script with no paired test file reports has_test == false and
#                     test_paths == [].
#   Degenerate root  -- an empty fixture (no agent-system/extensions/ tree at all) reports
#                     candidate_count == 0, scripts == [], summary == null, and exit 0.
#   Usage error      -- --root with no following argument exits 1 (not 0, not 2).
#   No side effects  -- a before/after find-based manifest of the fixture root is byte-identical
#                     across a full default-mode run, proving the probe writes nothing under the
#                     tree it inspects.
#   --size-line      -- a fixture with 2 non-test scripts (known line totals), 2 test suites (one
#                     tests/-dir, one flat test-*.sh), and 1 markdown file (known line total).
#                     Asserts the mode emits exactly one line, exits 0, and that line's counts
#                     match the fixture exactly, including cost_per_assertion_ms=n/a when no
#                     suite-cost-hints.txt is present. Also asserts --size-line composed with
#                     --check is a usage error (exit 1).
#   cost_per_assertion_ms -- a fixture carrying a real suite-cost-hints.txt (1500ms pool) and one
#                     suite with 4 mixed-shape assertion calls proves the figure is a real
#                     computed ratio (375.0), not a constant fallback.
#   Untracked        -- a fixture with one tracked non-test script, one UNSTAGED non-test script,
#     inclusion         one UNSTAGED tests/-dir script, one UNSTAGED markdown file, and one
#                     UNSTAGED file matched by a fixture .gitignore. Asserts --size-line and the
#                     default JSON mode count both the tracked and unstaged files (scripts,
#                     test-suite, and markdown figures alike), exclude the gitignored file
#                     entirely, report the correct untracked=N total and JSON
#                     untracked_count/untracked_paths/per-script tracked boolean, and that two
#                     scratch-reverted copies of the tool (the *.sh union dropped; and
#                     --exclude-standard dropped) each fail the corresponding assertion, proving
#                     the case is not vacuous.
#
# Structural model: tests/test-assess-repo-health.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, deploy-tree-first/source-store-fallback resolution, exit 0 on all-pass /
# exit 1 on any-fail).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (script-inventory.sh not found, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

TOOL="$(common_test_resolve_subject "script-inventory.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/script-inventory.sh" \
  "$SCRIPT_DIR/../script-inventory.sh")" || exit 2
common_test_declare_subject "$TOOL"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot exercise script-inventory.sh" >&2
  exit 2
fi

PASSED=0
FAILED=0


common_test_workdir_init

mk_git_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "test"
}

# =====================================================================
# Enumeration: real script + tests/-dir script + flat test-*.sh script.
# Only the real script must be enumerated.
# =====================================================================
ENUM_DIR="$WORKDIR/enum"
mkdir -p "$ENUM_DIR/agent-system/extensions/core/scripts/tests"
cat > "$ENUM_DIR/agent-system/extensions/core/scripts/real.sh" <<'EOF'
#!/usr/bin/env bash
echo real
EOF
cat > "$ENUM_DIR/agent-system/extensions/core/scripts/tests/test-real.sh" <<'EOF'
#!/usr/bin/env bash
echo "testing real.sh"
EOF
cat > "$ENUM_DIR/agent-system/extensions/core/scripts/test-flat.sh" <<'EOF'
#!/usr/bin/env bash
echo flat
EOF
mk_git_fixture "$ENUM_DIR"
git -C "$ENUM_DIR" add agent-system/extensions/core/scripts/real.sh \
  agent-system/extensions/core/scripts/tests/test-real.sh \
  agent-system/extensions/core/scripts/test-flat.sh
git -C "$ENUM_DIR" commit -q -m init

ENUM_OUT="$(bash "$TOOL" --root "$ENUM_DIR" 2>"$WORKDIR/enum_stderr")"
enum_count="$(echo "$ENUM_OUT" | jq -r '.candidate_count')"
enum_paths="$(echo "$ENUM_OUT" | jq -r '.scripts[].path' | sort)"
if [ "$enum_count" = "1" ]; then
  common_test_pass "enumeration: candidate_count == 1 (tests/ and test-* excluded)"
else
  common_test_fail "enumeration: candidate_count == $enum_count (expected 1); stderr: $(cat "$WORKDIR/enum_stderr")"
fi
if [ "$enum_paths" = "agent-system/extensions/core/scripts/real.sh" ]; then
  common_test_pass "enumeration: only real.sh enumerated"
else
  common_test_fail "enumeration: unexpected enumerated set: $enum_paths"
fi

# =====================================================================
# Size metrics: known line/byte counts.
# =====================================================================
SIZE_DIR="$WORKDIR/size"
mkdir -p "$SIZE_DIR/agent-system/extensions/core/scripts"
printf 'line1\nline2\nline3\n' > "$SIZE_DIR/agent-system/extensions/core/scripts/sized.sh"
mk_git_fixture "$SIZE_DIR"
git -C "$SIZE_DIR" add agent-system/extensions/core/scripts/sized.sh
git -C "$SIZE_DIR" commit -q -m init

expected_lines="$(wc -l < "$SIZE_DIR/agent-system/extensions/core/scripts/sized.sh" | tr -d ' ')"
expected_bytes="$(wc -c < "$SIZE_DIR/agent-system/extensions/core/scripts/sized.sh" | tr -d ' ')"
SIZE_OUT="$(bash "$TOOL" --root "$SIZE_DIR" 2>"$WORKDIR/size_stderr")"
got_lines="$(echo "$SIZE_OUT" | jq -r '.scripts[0].lines')"
got_bytes="$(echo "$SIZE_OUT" | jq -r '.scripts[0].bytes')"
if [ "$got_lines" = "$expected_lines" ]; then
  common_test_pass "size metrics: lines == $expected_lines"
else
  common_test_fail "size metrics: lines == $got_lines (expected $expected_lines)"
fi
if [ "$got_bytes" = "$expected_bytes" ]; then
  common_test_pass "size metrics: bytes == $expected_bytes"
else
  common_test_fail "size metrics: bytes == $got_bytes (expected $expected_bytes)"
fi

# =====================================================================
# Caller counting: B references A's basename; A is referenced, B is not.
# =====================================================================
CALLER_DIR="$WORKDIR/caller"
mkdir -p "$CALLER_DIR/agent-system/extensions/core/scripts"
cat > "$CALLER_DIR/agent-system/extensions/core/scripts/a.sh" <<'EOF'
#!/usr/bin/env bash
echo a
EOF
cat > "$CALLER_DIR/agent-system/extensions/core/scripts/b.sh" <<'EOF'
#!/usr/bin/env bash
# this references a.sh
bash a.sh
EOF
mk_git_fixture "$CALLER_DIR"
git -C "$CALLER_DIR" add agent-system/extensions/core/scripts/a.sh agent-system/extensions/core/scripts/b.sh
git -C "$CALLER_DIR" commit -q -m init

CALLER_OUT="$(bash "$TOOL" --root "$CALLER_DIR" 2>"$WORKDIR/caller_stderr")"
a_callers="$(echo "$CALLER_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/a.sh") | .inbound_callers')"
a_caller_paths="$(echo "$CALLER_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/a.sh") | .inbound_caller_paths[]')"
b_zero="$(echo "$CALLER_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/b.sh") | .zero_caller_finding')"
if [ "$a_callers" = "1" ] && [ "$a_caller_paths" = "agent-system/extensions/core/scripts/b.sh" ]; then
  common_test_pass "caller counting: a.sh has exactly 1 caller (b.sh), excluding itself"
else
  common_test_fail "caller counting: a.sh callers=$a_callers paths=[$a_caller_paths] (expected 1, b.sh only)"
fi
if [ "$b_zero" = "true" ]; then
  common_test_pass "caller counting: b.sh (referenced by nothing) has zero_caller_finding == true"
else
  common_test_fail "caller counting: b.sh zero_caller_finding == $b_zero (expected true)"
fi

# =====================================================================
# has_test true/false.
# =====================================================================
TEST_DIR="$WORKDIR/hastest"
mkdir -p "$TEST_DIR/agent-system/extensions/core/scripts/tests"
cat > "$TEST_DIR/agent-system/extensions/core/scripts/tested.sh" <<'EOF'
#!/usr/bin/env bash
echo tested
EOF
cat > "$TEST_DIR/agent-system/extensions/core/scripts/tests/test-tested.sh" <<'EOF'
#!/usr/bin/env bash
echo "testing tested"
EOF
cat > "$TEST_DIR/agent-system/extensions/core/scripts/untested.sh" <<'EOF'
#!/usr/bin/env bash
echo untested
EOF
mk_git_fixture "$TEST_DIR"
git -C "$TEST_DIR" add agent-system/extensions/core/scripts/tested.sh \
  agent-system/extensions/core/scripts/tests/test-tested.sh \
  agent-system/extensions/core/scripts/untested.sh
git -C "$TEST_DIR" commit -q -m init

HASTEST_OUT="$(bash "$TOOL" --root "$TEST_DIR" 2>"$WORKDIR/hastest_stderr")"
tested_has="$(echo "$HASTEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/tested.sh") | .has_test')"
tested_paths="$(echo "$HASTEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/tested.sh") | .test_paths[]')"
untested_has="$(echo "$HASTEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/untested.sh") | .has_test')"
untested_paths_count="$(echo "$HASTEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/untested.sh") | .test_paths | length')"
if [ "$tested_has" = "true" ] && [ "$tested_paths" = "agent-system/extensions/core/scripts/tests/test-tested.sh" ]; then
  common_test_pass "has_test: tested.sh reports true with correct test_paths"
else
  common_test_fail "has_test: tested.sh has_test=$tested_has test_paths=[$tested_paths]"
fi
if [ "$untested_has" = "false" ] && [ "$untested_paths_count" = "0" ]; then
  common_test_pass "has_test: untested.sh reports false with empty test_paths"
else
  common_test_fail "has_test: untested.sh has_test=$untested_has test_paths_count=$untested_paths_count"
fi

# =====================================================================
# Degenerate root: no agent-system/extensions/ tree at all.
# =====================================================================
DEGENERATE_DIR="$WORKDIR/degenerate"
mkdir -p "$DEGENERATE_DIR"
if DEGEN_OUT="$(bash "$TOOL" --root "$DEGENERATE_DIR" 2>"$WORKDIR/degen_stderr")"; then
  degen_count="$(echo "$DEGEN_OUT" | jq -r '.candidate_count')"
  degen_scripts_len="$(echo "$DEGEN_OUT" | jq -r '.scripts | length')"
  degen_summary="$(echo "$DEGEN_OUT" | jq -c '.summary')"
  if [ "$degen_count" = "0" ] && [ "$degen_scripts_len" = "0" ] && [ "$degen_summary" = "null" ]; then
    common_test_pass "degenerate root: candidate_count 0, scripts [], summary null"
  else
    common_test_fail "degenerate root: count=$degen_count scripts_len=$degen_scripts_len summary=$degen_summary"
  fi
else
  common_test_fail "degenerate root: script-inventory.sh exited non-zero; stderr: $(cat "$WORKDIR/degen_stderr")"
fi

# =====================================================================
# Usage error: --root with no following argument exits 1.
# =====================================================================
set +e
bash "$TOOL" --root >/dev/null 2>"$WORKDIR/usage_stderr"
usage_exit=$?
set -e 2>/dev/null || true
if [ "$usage_exit" -eq 1 ]; then
  common_test_pass "usage error: --root with no argument exits 1"
else
  common_test_fail "usage error: --root with no argument exited $usage_exit (expected 1)"
fi

# =====================================================================
# No side effects: before/after find-based manifest of the fixture root must be identical.
# =====================================================================
NOFX_DIR="$WORKDIR/nofx"
mkdir -p "$NOFX_DIR/agent-system/extensions/core/scripts"
cat > "$NOFX_DIR/agent-system/extensions/core/scripts/one.sh" <<'EOF'
#!/usr/bin/env bash
echo one
EOF
mk_git_fixture "$NOFX_DIR"
git -C "$NOFX_DIR" add agent-system/extensions/core/scripts/one.sh
git -C "$NOFX_DIR" commit -q -m init

before_manifest="$(find "$NOFX_DIR" -type f | sort)"
bash "$TOOL" --root "$NOFX_DIR" >/dev/null 2>"$WORKDIR/nofx_stderr"
after_manifest="$(find "$NOFX_DIR" -type f | sort)"
if [ "$before_manifest" = "$after_manifest" ]; then
  common_test_pass "no side effects: fixture root file manifest unchanged across a run"
else
  common_test_fail "no side effects: fixture root file manifest changed; before=[$before_manifest] after=[$after_manifest]"
fi

# =====================================================================
# --size-line: known script/test-suite/markdown counts and line totals, exactly one line, exit 0.
# =====================================================================
SIZELINE_DIR="$WORKDIR/sizeline"
mkdir -p "$SIZELINE_DIR/agent-system/extensions/core/scripts/tests"
printf 'line1\nline2\nline3\n' > "$SIZELINE_DIR/agent-system/extensions/core/scripts/one.sh"
printf 'line1\nline2\nline3\nline4\nline5\n' > "$SIZELINE_DIR/agent-system/extensions/core/scripts/two.sh"
printf 'line1\nline2\n' > "$SIZELINE_DIR/agent-system/extensions/core/scripts/tests/test-one.sh"
printf 'line1\nline2\nline3\nline4\n' > "$SIZELINE_DIR/agent-system/extensions/core/scripts/test-flat.sh"
printf 'l1\nl2\nl3\nl4\nl5\nl6\n' > "$SIZELINE_DIR/agent-system/extensions/core/README.md"
mk_git_fixture "$SIZELINE_DIR"
git -C "$SIZELINE_DIR" add agent-system/extensions/core/scripts/one.sh \
  agent-system/extensions/core/scripts/two.sh \
  agent-system/extensions/core/scripts/tests/test-one.sh \
  agent-system/extensions/core/scripts/test-flat.sh \
  agent-system/extensions/core/README.md
git -C "$SIZELINE_DIR" commit -q -m init

set +e
SIZELINE_OUT="$(bash "$TOOL" --root "$SIZELINE_DIR" --size-line 2>"$WORKDIR/sizeline_stderr")"
sizeline_exit=$?
set -e 2>/dev/null || true
sizeline_linecount="$(printf '%s' "$SIZELINE_OUT" | grep -c '^' || true)"
if [ "$sizeline_exit" -eq 0 ] && [ "$sizeline_linecount" -eq 1 ]; then
  common_test_pass "--size-line: emits exactly one line and exits 0"
else
  common_test_fail "--size-line: exit=$sizeline_exit line_count=$sizeline_linecount output=[$SIZELINE_OUT]; stderr: $(cat "$WORKDIR/sizeline_stderr")"
fi
if echo "$SIZELINE_OUT" | grep -q 'scripts=2 lines=8 test_suites=2 test_lines=6 md_files=1 md_lines=6'; then
  common_test_pass "--size-line: counts match the fixture (2 scripts/8 lines, 2 test suites/6 lines, 1 md file/6 lines)"
else
  common_test_fail "--size-line: unexpected output: $SIZELINE_OUT"
fi
if echo "$SIZELINE_OUT" | grep -q 'cost_per_assertion_ms=n/a'; then
  common_test_pass "--size-line: cost_per_assertion_ms reports n/a when this fixture has no suite-cost-hints.txt"
else
  common_test_fail "--size-line: expected cost_per_assertion_ms=n/a with no hints file; output: $SIZELINE_OUT"
fi

set +e
bash "$TOOL" --root "$SIZELINE_DIR" --size-line --check >/dev/null 2>"$WORKDIR/sizeline_both_stderr"
sizeline_both_exit=$?
set -e 2>/dev/null || true
if [ "$sizeline_both_exit" -eq 1 ]; then
  common_test_pass "--size-line: composed with --check is a usage error (exit 1)"
else
  common_test_fail "--size-line: --size-line --check exited $sizeline_both_exit (expected 1)"
fi

# =====================================================================
# cost_per_assertion_ms: a fixture with a real suite-cost-hints.txt (two rows, 1000ms + 500ms =
# 1500ms pool) and one test suite carrying four command-position assertion calls (two
# common_test_pass, one common_test_fail, one bare pass inside a case arm -- deliberately mixed
# shapes so this pins the same call-site recognition lint-test-harness-adoption.sh's call_re
# already uses, not just the simplest one-shape case) proves the figure is a real computed ratio
# (1500 / 4 = 375.0), not a constant fallback.
# =====================================================================
COSTLINE_DIR="$WORKDIR/costline"
mkdir -p "$COSTLINE_DIR/agent-system/extensions/core/scripts/tests"
cat > "$COSTLINE_DIR/agent-system/extensions/core/scripts/tests/test-cost-fixture.sh" << 'EOF'
#!/usr/bin/env bash
PASSED=0
FAILED=0
common_test_pass "case one"
common_test_pass "case two"
common_test_fail "case three"
case "$1" in
  x) pass "case four" ;;
esac
EOF
cat > "$COSTLINE_DIR/agent-system/extensions/core/scripts/tests/suite-cost-hints.txt" << 'EOF'
# comment line, ignored
test-cost-fixture.sh,1000
test-unrelated.sh,500
EOF
mk_git_fixture "$COSTLINE_DIR"
git -C "$COSTLINE_DIR" add agent-system/extensions/core/scripts/tests/test-cost-fixture.sh \
  agent-system/extensions/core/scripts/tests/suite-cost-hints.txt
git -C "$COSTLINE_DIR" commit -q -m init

set +e
COSTLINE_OUT="$(bash "$TOOL" --root "$COSTLINE_DIR" --size-line 2>"$WORKDIR/costline_stderr")"
set -e 2>/dev/null || true
if echo "$COSTLINE_OUT" | grep -q 'cost_per_assertion_ms=375.0'; then
  common_test_pass "--size-line: cost_per_assertion_ms computes the real ratio (1500ms pool / 4 assertions = 375.0) over mixed call-site shapes"
else
  common_test_fail "--size-line: expected cost_per_assertion_ms=375.0; output: $COSTLINE_OUT"
fi

# =====================================================================
# Untracked inclusion: a tracked non-test script, an UNSTAGED non-test script, an UNSTAGED
# tests/-dir script, an UNSTAGED markdown file, and an UNSTAGED file matched by a fixture
# .gitignore. Pins that the unstaged-but-not-ignored files ARE folded into every figure, the
# gitignored file is excluded from all of them, and the untracked= total is correct.
# =====================================================================
UNTRACKED_DIR="$WORKDIR/untracked"
mkdir -p "$UNTRACKED_DIR/agent-system/extensions/core/scripts/tests"
printf 'line1\nline2\nline3\n' > "$UNTRACKED_DIR/agent-system/extensions/core/scripts/tracked.sh"
echo 'agent-system/extensions/core/scripts/ignored.sh' > "$UNTRACKED_DIR/.gitignore"
mk_git_fixture "$UNTRACKED_DIR"
git -C "$UNTRACKED_DIR" add agent-system/extensions/core/scripts/tracked.sh .gitignore
git -C "$UNTRACKED_DIR" commit -q -m init

# Created AFTER the commit above and deliberately never `git add`-ed.
printf 'line1\nline2\nline3\nline4\nline5\n' > "$UNTRACKED_DIR/agent-system/extensions/core/scripts/untracked.sh"
printf 'line1\nline2\n' > "$UNTRACKED_DIR/agent-system/extensions/core/scripts/tests/test-untracked.sh"
printf 'l1\nl2\nl3\n' > "$UNTRACKED_DIR/agent-system/extensions/core/README.md"
printf 'ignored1\nignored2\n' > "$UNTRACKED_DIR/agent-system/extensions/core/scripts/ignored.sh"

set +e
UNTRACKED_SIZELINE_OUT="$(bash "$TOOL" --root "$UNTRACKED_DIR" --size-line 2>"$WORKDIR/untracked_sizeline_stderr")"
untracked_sizeline_exit=$?
set -e 2>/dev/null || true
untracked_sizeline_linecount="$(printf '%s' "$UNTRACKED_SIZELINE_OUT" | grep -c '^' || true)"
if [ "$untracked_sizeline_exit" -eq 0 ] && [ "$untracked_sizeline_linecount" -eq 1 ]; then
  common_test_pass "untracked inclusion: --size-line emits exactly one line and exits 0"
else
  common_test_fail "untracked inclusion: exit=$untracked_sizeline_exit line_count=$untracked_sizeline_linecount output=[$UNTRACKED_SIZELINE_OUT]; stderr: $(cat "$WORKDIR/untracked_sizeline_stderr")"
fi
if echo "$UNTRACKED_SIZELINE_OUT" | grep -q 'scripts=2 lines=8 test_suites=1 test_lines=2 md_files=1 md_lines=3 cost_per_assertion_ms=n/a untracked=3'; then
  common_test_pass "untracked inclusion: --size-line counts the tracked AND unstaged non-test scripts (2/8), the unstaged test suite (1/2), the unstaged markdown file (1/3), excludes the gitignored script, and reports untracked=3"
else
  common_test_fail "untracked inclusion: unexpected --size-line output: $UNTRACKED_SIZELINE_OUT"
fi

UNTRACKED_JSON_OUT="$(bash "$TOOL" --root "$UNTRACKED_DIR" 2>"$WORKDIR/untracked_json_stderr")"
untracked_candidate_count="$(echo "$UNTRACKED_JSON_OUT" | jq -r '.candidate_count')"
untracked_json_count="$(echo "$UNTRACKED_JSON_OUT" | jq -r '.untracked_count')"
untracked_json_paths="$(echo "$UNTRACKED_JSON_OUT" | jq -r '.untracked_paths[]')"
untracked_script_tracked="$(echo "$UNTRACKED_JSON_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/untracked.sh") | .tracked')"
tracked_script_tracked="$(echo "$UNTRACKED_JSON_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/tracked.sh") | .tracked')"
if [ "$untracked_candidate_count" = "2" ]; then
  common_test_pass "untracked inclusion: JSON candidate_count includes the unstaged script (2 total)"
else
  common_test_fail "untracked inclusion: JSON candidate_count == $untracked_candidate_count (expected 2); stderr: $(cat "$WORKDIR/untracked_json_stderr")"
fi
if [ "$untracked_json_count" = "1" ] && [ "$untracked_json_paths" = "agent-system/extensions/core/scripts/untracked.sh" ]; then
  common_test_pass "untracked inclusion: JSON untracked_count/untracked_paths name exactly untracked.sh"
else
  common_test_fail "untracked inclusion: untracked_count=$untracked_json_count untracked_paths=[$untracked_json_paths] (expected 1, untracked.sh only)"
fi
if [ "$untracked_script_tracked" = "false" ] && [ "$tracked_script_tracked" = "true" ]; then
  common_test_pass "untracked inclusion: per-script tracked boolean is false for untracked.sh, true for tracked.sh"
else
  common_test_fail "untracked inclusion: untracked.sh tracked=$untracked_script_tracked, tracked.sh tracked=$tracked_script_tracked (expected false, true)"
fi

# Gitignored file never appears anywhere: not in the ranked scripts, not in the ignored-aware
# ls-files pattern, and not reflected in any figure above (already proven by scripts=2/untracked=3
# above, which would be scripts=3/untracked=4 if ignored.sh leaked in).
ignored_present="$(echo "$UNTRACKED_JSON_OUT" | jq -r '[.scripts[].path] | any(. == "agent-system/extensions/core/scripts/ignored.sh")')"
if [ "$ignored_present" = "false" ]; then
  common_test_pass "untracked inclusion: gitignored ignored.sh is absent from the JSON scripts array"
else
  common_test_fail "untracked inclusion: gitignored ignored.sh unexpectedly present in the JSON scripts array"
fi

# Negative control: a scratch copy of script-inventory.sh with the Phase 2 *.sh union reverted
# (the --others --exclude-standard line dropped from enumerate_candidates) must NOT see
# untracked.sh at all -- proving the new case actually pins the union rather than passing
# vacuously against any enumeration. Script-only; the markdown/gitignore halves of this fixture
# are not exercised by this specific revert (enumerate_candidates covers only the *.sh pattern).
REVERTED_TOOL="$WORKDIR/script-inventory-reverted.sh"
sed '/ls-files -z --others --exclude-standard -- .agent-system\/extensions\/\*\*\/\*\.sh./d' "$TOOL" > "$REVERTED_TOOL"
chmod +x "$REVERTED_TOOL"
set +e
REVERTED_OUT="$(bash "$REVERTED_TOOL" --root "$UNTRACKED_DIR" --size-line 2>"$WORKDIR/reverted_stderr")"
set -e 2>/dev/null || true
if echo "$REVERTED_OUT" | grep -q 'scripts=1 '; then
  common_test_pass "negative control: reverting the *.sh union makes the untracked case FAIL to see untracked.sh (scripts=1, not 2) -- the new assertions are not vacuous"
else
  common_test_fail "negative control: reverted script unexpectedly still reports the untracked script; output: $REVERTED_OUT"
fi

# Negative control: dropping --exclude-standard entirely (so --others would see gitignored files
# too) must make ignored.sh leak into the candidate count -- proving the gitignore exclusion
# assertion above is also not vacuous.
NOEXCLUDE_TOOL="$WORKDIR/script-inventory-noexclude.sh"
sed 's/ls-files -z --others --exclude-standard --/ls-files -z --others --/' "$TOOL" > "$NOEXCLUDE_TOOL"
chmod +x "$NOEXCLUDE_TOOL"
set +e
NOEXCLUDE_OUT="$(bash "$NOEXCLUDE_TOOL" --root "$UNTRACKED_DIR" --size-line 2>"$WORKDIR/noexclude_stderr")"
set -e 2>/dev/null || true
if echo "$NOEXCLUDE_OUT" | grep -q 'scripts=3 '; then
  common_test_pass "negative control: dropping --exclude-standard lets the gitignored script leak in (scripts=3) -- the gitignore-exclusion assertion is not vacuous"
else
  common_test_fail "negative control: dropping --exclude-standard did not surface the gitignored script as expected; output: $NOEXCLUDE_OUT"
fi

# =====================================================================
# manifest_registered true/false (Rule Q reuse), and the --check manifest-drift exit path.
# registered.sh declares unregistered.sh as a caller (via its basename appearing in registered.sh's
# content) so unregistered.sh's inbound_callers is nonzero -- isolating the manifest-drift finding
# from the zero-caller finding for the --check exit-code case below.
# =====================================================================
MANIFEST_DIR="$WORKDIR/manifest"
mkdir -p "$MANIFEST_DIR/agent-system/extensions/core/scripts"
cat > "$MANIFEST_DIR/agent-system/extensions/core/scripts/registered.sh" <<'EOF'
#!/usr/bin/env bash
# calls unregistered.sh
bash unregistered.sh
EOF
cat > "$MANIFEST_DIR/agent-system/extensions/core/scripts/unregistered.sh" <<'EOF'
#!/usr/bin/env bash
echo unregistered
EOF
cat > "$MANIFEST_DIR/agent-system/extensions/core/manifest.json" <<'EOF'
{"provides": {"scripts": ["registered.sh"]}}
EOF
mk_git_fixture "$MANIFEST_DIR"
git -C "$MANIFEST_DIR" add agent-system/extensions/core/scripts/registered.sh \
  agent-system/extensions/core/scripts/unregistered.sh \
  agent-system/extensions/core/manifest.json
git -C "$MANIFEST_DIR" commit -q -m init

if command -v git >/dev/null 2>&1; then
  MANIFEST_OUT="$(bash "$TOOL" --root "$MANIFEST_DIR" 2>"$WORKDIR/manifest_stderr")"
  reg_val="$(echo "$MANIFEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/registered.sh") | .manifest_registered')"
  unreg_val="$(echo "$MANIFEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/unregistered.sh") | .manifest_registered')"
  unreg_zero="$(echo "$MANIFEST_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/unregistered.sh") | .zero_caller_finding')"
  if [ "$reg_val" = "true" ]; then
    common_test_pass "manifest_registered: registered.sh (declared in provides.scripts) reports true"
  else
    common_test_fail "manifest_registered: registered.sh reports $reg_val (expected true); stderr: $(cat "$WORKDIR/manifest_stderr")"
  fi
  if [ "$unreg_val" = "false" ]; then
    common_test_pass "manifest_registered: unregistered.sh (absent from provides.scripts) reports false"
  else
    common_test_fail "manifest_registered: unregistered.sh reports $unreg_val (expected false)"
  fi
  if [ "$unreg_zero" = "false" ]; then
    common_test_pass "manifest_registered isolation: unregistered.sh has a real caller, so its finding is manifest-drift only, not also zero-caller"
  else
    common_test_fail "manifest_registered isolation: unregistered.sh zero_caller_finding == $unreg_zero (expected false -- registered.sh references it)"
  fi

  set +e
  bash "$TOOL" --root "$MANIFEST_DIR" --check >/dev/null 2>"$WORKDIR/manifest_check_stderr"
  manifest_check_exit=$?
  set -e 2>/dev/null || true
  if [ "$manifest_check_exit" -eq 1 ]; then
    common_test_pass "--check: manifest-drift-only fixture exits 1 (zero zero-caller findings present)"
  else
    common_test_fail "--check: manifest-drift fixture exited $manifest_check_exit (expected 1)"
  fi
else
  common_test_info "git not on PATH -- skipping manifest_registered git-fixture cases"
fi

# =====================================================================
# --check: a fully clean fixture (registered, referenced, has_test) exits 0.
# =====================================================================
CLEANCHECK_DIR="$WORKDIR/cleancheck"
mkdir -p "$CLEANCHECK_DIR/agent-system/extensions/core/scripts/tests"
cat > "$CLEANCHECK_DIR/agent-system/extensions/core/scripts/clean.sh" <<'EOF'
#!/usr/bin/env bash
echo clean
EOF
cat > "$CLEANCHECK_DIR/agent-system/extensions/core/scripts/tests/test-clean.sh" <<'EOF'
#!/usr/bin/env bash
echo "testing clean.sh"
EOF
cat > "$CLEANCHECK_DIR/agent-system/extensions/core/manifest.json" <<'EOF'
{"provides": {"scripts": ["clean.sh", "tests/test-clean.sh"]}}
EOF
mk_git_fixture "$CLEANCHECK_DIR"
git -C "$CLEANCHECK_DIR" add agent-system/extensions/core/scripts/clean.sh \
  agent-system/extensions/core/scripts/tests/test-clean.sh \
  agent-system/extensions/core/manifest.json
git -C "$CLEANCHECK_DIR" commit -q -m init

set +e
bash "$TOOL" --root "$CLEANCHECK_DIR" --check >/dev/null 2>"$WORKDIR/cleancheck_stderr"
cleancheck_exit=$?
set -e 2>/dev/null || true
if [ "$cleancheck_exit" -eq 0 ]; then
  common_test_pass "--check: fully clean fixture (registered + referenced via its own test file) exits 0"
else
  common_test_fail "--check: clean fixture exited $cleancheck_exit (expected 0); stderr: $(cat "$WORKDIR/cleancheck_stderr")"
fi

# =====================================================================
# Duplicate-block detection: a synthesized 10-line block shared verbatim across two files is
# detected (spans 2+ files); a lone, unshared block (even though it is the same length) is NOT.
# =====================================================================
DUP_DIR="$WORKDIR/dup"
mkdir -p "$DUP_DIR/agent-system/extensions/core/scripts"
SHARED_BLOCK='echo step_one
echo step_two
echo step_three
echo step_four
echo step_five
echo step_six
echo step_seven
echo step_eight
echo step_nine
echo step_ten'
{
  echo '#!/usr/bin/env bash'
  echo "$SHARED_BLOCK"
  echo 'echo "dup1 unique tail"'
} > "$DUP_DIR/agent-system/extensions/core/scripts/dup1.sh"
{
  echo '#!/usr/bin/env bash'
  echo "$SHARED_BLOCK"
  echo 'echo "dup2 unique tail"'
} > "$DUP_DIR/agent-system/extensions/core/scripts/dup2.sh"
cat > "$DUP_DIR/agent-system/extensions/core/scripts/lone.sh" <<'EOF'
#!/usr/bin/env bash
echo alpha
echo beta
echo gamma
echo delta
echo epsilon
echo zeta
echo eta
echo theta
echo iota
echo kappa
EOF
mk_git_fixture "$DUP_DIR"
git -C "$DUP_DIR" add agent-system/extensions/core/scripts/dup1.sh \
  agent-system/extensions/core/scripts/dup2.sh \
  agent-system/extensions/core/scripts/lone.sh
git -C "$DUP_DIR" commit -q -m init

DUP_OUT="$(bash "$TOOL" --root "$DUP_DIR" 2>"$WORKDIR/dup_stderr")"
dup1_count="$(echo "$DUP_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/dup1.sh") | .duplicate_blocks')"
dup1_peers="$(echo "$DUP_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/dup1.sh") | .duplicate_block_peers[]')"
lone_count="$(echo "$DUP_OUT" | jq -r '.scripts[] | select(.path == "agent-system/extensions/core/scripts/lone.sh") | .duplicate_blocks')"
if [ "$dup1_count" -ge 1 ] 2>/dev/null && [ "$dup1_peers" = "agent-system/extensions/core/scripts/dup2.sh" ]; then
  common_test_pass "duplicate-block detection: dup1.sh/dup2.sh's shared 10-line block is detected, cross-referenced to its peer"
else
  common_test_fail "duplicate-block detection: dup1.sh duplicate_blocks=$dup1_count peers=[$dup1_peers] (expected >=1, peer dup2.sh); stderr: $(cat "$WORKDIR/dup_stderr")"
fi
if [ "$lone_count" = "0" ]; then
  common_test_pass "duplicate-block detection: a same-length but unshared block is NOT reported (below the 2-file / 3-occurrence threshold)"
else
  common_test_fail "duplicate-block detection: lone.sh duplicate_blocks=$lone_count (expected 0)"
fi

# =====================================================================
# Rank ordering stable across two runs on the same fixture (full-output diff excluding the one
# documented non-reproducible field, generated_at).
# =====================================================================
RANK_RUN1="$(bash "$TOOL" --root "$DUP_DIR" 2>/dev/null | jq 'del(.generated_at)')"
RANK_RUN2="$(bash "$TOOL" --root "$DUP_DIR" 2>/dev/null | jq 'del(.generated_at)')"
if [ "$RANK_RUN1" = "$RANK_RUN2" ]; then
  common_test_pass "rank ordering: two consecutive runs on the same fixture are identical modulo generated_at"
else
  common_test_fail "rank ordering: two consecutive runs diverged"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
