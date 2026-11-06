#!/usr/bin/env bash
# test-lint-branch-gated-sections.sh - Fixture-driven regression test for
# scripts/lint/lint-branch-gated-sections.sh.
#
# Pins the lint's behaviour against synthetic fixtures only; this suite never depends on the
# live tree being clean (that is a separate, whole-tree assertion covered by verify-deploy.sh
# gate 19) and never mutates the repository.
#
# Structural model: test-lint-task-lookup-adoption.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-branch-gated-sections.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-branch-gated-sections.sh" \
  "$SCRIPT_DIR/../lint/lint-branch-gated-sections.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# THRESHOLD_BYTES mirrors the lint's own constant. Re-derived here (not sourced) so a future
# re-calibration of the lint is forced to be a conscious, visible edit to this test too.
THRESHOLD_BYTES=8000

# padding <n> -- emits exactly <n> bytes of filler text (content is irrelevant to a byte-count
# lint; 'x' repeated is simplest to reason about).
padding() {
  local n="$1"
  head -c "$n" /dev/zero | tr '\0' 'x'
}

# =====================================================================
# Case 1 (acceptance criterion): a marked section ABOVE threshold -> lint exits 1, names the file
# =====================================================================
common_test_info "=== acceptance criterion: marked section above threshold ==="

C1_DIR="$WORKDIR/case1"
mkdir -p "$C1_DIR/skills/skill-x"
C1_FIXTURE="$C1_DIR/skills/skill-x/SKILL.md"
{
  echo "# Fixture"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  echo "## Big Mode"
  padding 8500
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C1_FIXTURE"

c1_out="$(bash "$LINT_SCRIPT" "$C1_DIR" 2>&1)"
c1_status=$?
if [[ $c1_status -ne 0 ]]; then
  common_test_pass "lint exits non-zero for a marked section above the ${THRESHOLD_BYTES} B threshold"
else
  common_test_fail "lint exited 0 for an over-threshold marked section (expected non-zero):
$c1_out"
fi
if grep -q "SKILL.md" <<< "$c1_out" && grep -q "VIOLATION" <<< "$c1_out"; then
  common_test_pass "lint names the violating file"
else
  common_test_fail "lint output did not name the violating file:
$c1_out"
fi

# =====================================================================
# Case 2: a marked section BELOW threshold -> lint exits 0
# =====================================================================
common_test_info "=== boundary: marked section below threshold ==="

C2_DIR="$WORKDIR/case2"
mkdir -p "$C2_DIR/skills/skill-x"
C2_FIXTURE="$C2_DIR/skills/skill-x/SKILL.md"
{
  echo "# Fixture"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  echo "## Small Mode"
  padding 500
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C2_FIXTURE"

if bash "$LINT_SCRIPT" "$C2_DIR" >"$WORKDIR/case2-out.txt" 2>&1; then
  common_test_pass "lint exits 0 for a marked section below threshold (not worth extracting)"
else
  common_test_fail "lint flagged a below-threshold marked section:
$(cat "$WORKDIR/case2-out.txt")"
fi

# =====================================================================
# Case 3: two marked sections, each below threshold, SUMMING above it -> lint exits 1
# =====================================================================
common_test_info "=== sum-not-max: two below-threshold sections summing above threshold ==="

C3_DIR="$WORKDIR/case3"
mkdir -p "$C3_DIR/skills/skill-x"
C3_FIXTURE="$C3_DIR/skills/skill-x/SKILL.md"
{
  echo "# Fixture"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  echo "## Mode A"
  padding 4500
  echo ""
  echo '<!-- branch-gated:end -->'
  echo ""
  echo '<!-- branch-gated:begin condition="mode=other" -->'
  echo "## Mode B"
  padding 4500
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C3_FIXTURE"

c3_out="$(bash "$LINT_SCRIPT" "$C3_DIR" 2>&1)"
c3_status=$?
if [[ $c3_status -ne 0 ]]; then
  common_test_pass "lint exits non-zero when two below-threshold sections sum above threshold"
else
  common_test_fail "lint exited 0 when the SUM of two marked sections exceeds threshold (expected non-zero):
$c3_out"
fi

# =====================================================================
# Case 4: an already-extracted file (pointer present, no markers) -> lint exits 0
# =====================================================================
common_test_info "=== extracted state: pointer present, no markers -> clean ==="

C4_DIR="$WORKDIR/case4"
mkdir -p "$C4_DIR/skills/skill-x"
C4_FIXTURE="$C4_DIR/skills/skill-x/SKILL.md"
cat > "$C4_FIXTURE" << 'EOF'
# Fixture

READ .claude/context/patterns/example-extracted-mode.md now and follow it exactly.
EOF

if bash "$LINT_SCRIPT" "$C4_DIR" >"$WORKDIR/case4-out.txt" 2>&1; then
  common_test_pass "lint exits 0 for an already-extracted file (pointer only, no markers)"
else
  common_test_fail "lint flagged an already-extracted (pointer-only) file:
$(cat "$WORKDIR/case4-out.txt")"
fi

# =====================================================================
# Case 5: an over-threshold marked section in an OUT-OF-SCOPE location -> lint exits 0
# =====================================================================
common_test_info "=== scope boundary: context/ and docs/ are out of scope by construction ==="

C5_DIR="$WORKDIR/case5"
mkdir -p "$C5_DIR/context/patterns"
C5_FIXTURE="$C5_DIR/context/patterns/illustrative.md"
{
  echo "# Illustrative context doc (not a runtime-loaded surface)"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  padding 9000
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C5_FIXTURE"

if bash "$LINT_SCRIPT" "$C5_DIR" >"$WORKDIR/case5-out.txt" 2>&1; then
  common_test_pass "lint exits 0 for an over-threshold marked section under context/ (out of scope by construction)"
else
  common_test_fail "lint flagged a context/ file (should be out of scope, not merely exempt):
$(cat "$WORKDIR/case5-out.txt")"
fi
if grep -q "Files checked: 0" "$WORKDIR/case5-out.txt"; then
  common_test_pass "context/ is excluded by scan scope, not by a growing exclusion list (0 files checked)"
else
  common_test_fail "expected 0 files checked scanning a context/-only root:
$(cat "$WORKDIR/case5-out.txt")"
fi

# =====================================================================
# Case 6: a file on the allowlist with an over-threshold marked section -> lint exits 0
# =====================================================================
# The shipped lint's EXCLUDED_FILES starts empty (see the lint's own CONVENTION-SELECTION header
# note), so there is no live entry to reuse the way test-lint-task-lookup-adoption.sh reuses its
# sibling's pre-populated canonical-implementation entries. To exercise the ALLOWLIST MECHANISM
# itself (is_excluded_file()'s exemption path) without permanently seeding the shipped lint's
# list, this case runs against a throwaway copy of the lint with exactly one test-only entry
# injected. This asserts the mechanism works, not that any particular file is (or should be) on
# the real allowlist.
common_test_info "=== allowlist mechanism: an over-threshold file with a reasoned allowlist entry -> clean ==="

# The copy must live at scripts/lint/<name>.sh relative to a scripts/lib/ directory, since the
# lint sources "${SCRIPT_DIR}/../lib/common.sh" by relative path. Mirror that shape under the
# workdir and symlink lib/ to the real shared library rather than duplicating it.
mkdir -p "$WORKDIR/scripts/lint" "$WORKDIR/scripts/lib"
ln -s "$SCRIPT_DIR/../lib"/* "$WORKDIR/scripts/lib/" 2>/dev/null
ALLOWLIST_TEST_LINT="$WORKDIR/scripts/lint/lint-with-test-allowlist-entry.sh"
sed 's|^EXCLUDED_FILES=($|EXCLUDED_FILES=(\n    "skills/skill-allowed/SKILL.md"  # test-only: exercises the allowlist mechanism (see test case 6)|' \
  "$LINT_SCRIPT" > "$ALLOWLIST_TEST_LINT"
chmod +x "$ALLOWLIST_TEST_LINT"

if ! diff -q "$LINT_SCRIPT" "$ALLOWLIST_TEST_LINT" >/dev/null 2>&1; then
  common_test_pass "allowlist-entry injection into the throwaway lint copy took effect"
else
  common_test_fail "sed injection did not modify the throwaway lint copy -- EXCLUDED_FILES anchor pattern may have drifted"
fi

C6_DIR="$WORKDIR/case6"
mkdir -p "$C6_DIR/skills/skill-allowed"
C6_FIXTURE="$C6_DIR/skills/skill-allowed/SKILL.md"
{
  echo "# Fixture"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  padding 9000
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C6_FIXTURE"

if bash "$ALLOWLIST_TEST_LINT" "$C6_DIR" >"$WORKDIR/case6-out.txt" 2>&1; then
  common_test_pass "an over-threshold file matching a reasoned allowlist entry is exempted (lint exits 0)"
else
  common_test_fail "allowlist mechanism did not exempt a matching over-threshold file:
$(cat "$WORKDIR/case6-out.txt")"
fi

# Control: the SAME fixture against the real (unmodified) lint IS a violation, proving case 6's
# clean result comes from the allowlist entry, not from some unrelated leniency.
if bash "$LINT_SCRIPT" "$C6_DIR" >"$WORKDIR/case6-control-out.txt" 2>&1; then
  common_test_fail "control: the unmodified lint (no allowlist entry) unexpectedly passed the same over-threshold fixture:
$(cat "$WORKDIR/case6-control-out.txt")"
else
  common_test_pass "control: the unmodified lint (no allowlist entry) correctly flags the same fixture"
fi

# =====================================================================
# Case 7: malformed markers -- unmatched begin, unmatched end -> named diagnostic, not silent
# =====================================================================
common_test_info "=== malformed markers are reported, never silently treated as clean ==="

C7A_DIR="$WORKDIR/case7a"
mkdir -p "$C7A_DIR/skills/skill-x"
cat > "$C7A_DIR/skills/skill-x/SKILL.md" << 'EOF'
# Fixture
<!-- branch-gated:begin condition="mode=all" -->
## Never closed
content
EOF

c7a_out="$(bash "$LINT_SCRIPT" "$C7A_DIR" 2>&1)"
c7a_status=$?
if [[ $c7a_status -ne 0 ]] && grep -q "UNMATCHED_BEGIN" <<< "$c7a_out"; then
  common_test_pass "unmatched begin marker is reported as a named diagnostic (UNMATCHED_BEGIN), not silently clean"
else
  common_test_fail "unmatched begin marker was not reported correctly:
$c7a_out"
fi

C7B_DIR="$WORKDIR/case7b"
mkdir -p "$C7B_DIR/skills/skill-x"
cat > "$C7B_DIR/skills/skill-x/SKILL.md" << 'EOF'
# Fixture
## Section with no begin
content
<!-- branch-gated:end -->
EOF

c7b_out="$(bash "$LINT_SCRIPT" "$C7B_DIR" 2>&1)"
c7b_status=$?
if [[ $c7b_status -ne 0 ]] && grep -q "UNMATCHED_END" <<< "$c7b_out"; then
  common_test_pass "unmatched end marker is reported as a named diagnostic (UNMATCHED_END), not silently clean"
else
  common_test_fail "unmatched end marker was not reported correctly:
$c7b_out"
fi

C7C_DIR="$WORKDIR/case7c"
mkdir -p "$C7C_DIR/skills/skill-x"
cat > "$C7C_DIR/skills/skill-x/SKILL.md" << 'EOF'
# Fixture
<!-- branch-gated:begin condition="mode=all" -->
## Outer
<!-- branch-gated:begin condition="mode=nested" -->
## Inner
content
<!-- branch-gated:end -->
EOF

c7c_out="$(bash "$LINT_SCRIPT" "$C7C_DIR" 2>&1)"
c7c_status=$?
if [[ $c7c_status -ne 0 ]] && grep -q "NESTED" <<< "$c7c_out"; then
  common_test_pass "nested/overlapping begin marker is reported as a named diagnostic (NESTED), not silently clean"
else
  common_test_fail "nested/overlapping marker was not reported correctly:
$c7c_out"
fi

# =====================================================================
# Case 8 (fence-interior decoy): heading-shaped lines inside a fenced block do not corrupt
# boundary resolution -- the whole reason the paired marker exists.
# =====================================================================
common_test_info "=== fence-interior decoy: boundaries resolve to the literal markers, not to decoy headings ==="

C8_DIR="$WORKDIR/case8"
mkdir -p "$C8_DIR/skills/skill-x"
C8_FIXTURE="$C8_DIR/skills/skill-x/SKILL.md"
{
  echo "# Fixture"
  echo '<!-- branch-gated:begin condition="mode=all" -->'
  echo "## Real Section"
  echo ""
  echo '```bash'
  echo "# --- decoy:begin --- (a bash comment, NOT a markdown heading)"
  echo "## this looks like a level-2 heading but is inside a fenced block"
  echo "# --- decoy:end ---"
  echo '```'
  echo ""
  # Pad well past threshold AFTER the decoy, so a naive heading-scan that stopped at the decoy
  # (which appears early, well under threshold) would produce a small, non-violating total --
  # while the correct marker-literal scan produces a large, violating total. This distinguishes
  # correct behavior from the exact defect the paired marker exists to prevent.
  padding 8500
  echo ""
  echo '<!-- branch-gated:end -->'
} > "$C8_FIXTURE"

c8_out="$(bash "$LINT_SCRIPT" "$C8_DIR" 2>&1)"
c8_status=$?
if [[ $c8_status -ne 0 ]] && grep -q "VIOLATION" <<< "$c8_out"; then
  common_test_pass "fence-interior decoy heading does not truncate the span early -- the real over-threshold total is still detected"
else
  common_test_fail "fence-interior decoy corrupted boundary resolution (expected a violation from the full span, not an early truncation):
$c8_out"
fi

# =====================================================================
# Case 9: both root-resolution modes exercised, each producing a non-empty scan
# =====================================================================
common_test_info "=== mode probe: source-store fixture (core/manifest.json present) ==="

C9_SRCSTORE="$WORKDIR/srcstore"
mkdir -p "$C9_SRCSTORE/core/skills/skill-y"
echo '{}' > "$C9_SRCSTORE/core/manifest.json"
cat > "$C9_SRCSTORE/core/skills/skill-y/SKILL.md" << 'EOF'
# Fixture, no markers -- just proves the file is enumerated by the scan
EOF

srcstore_out="$(bash "$LINT_SCRIPT" --verbose "$C9_SRCSTORE" 2>&1)"
if grep -q "Files checked: 1" <<< "$srcstore_out"; then
  common_test_pass "mode probe: source-store fixture (core/manifest.json present) resolves to source-store and scans nested extension dirs (non-empty)"
else
  common_test_fail "source-store mode probe did not enumerate the nested skill file:
$srcstore_out"
fi

common_test_info "=== mode probe: deployed fixture (no manifest.json, flat layout) ==="

C9_DEPLOYED="$WORKDIR/deployshape"
mkdir -p "$C9_DEPLOYED/commands" "$C9_DEPLOYED/skills/skill-z"
cat > "$C9_DEPLOYED/commands/example.md" << 'EOF'
# Fixture command, no markers
EOF
cat > "$C9_DEPLOYED/skills/skill-z/SKILL.md" << 'EOF'
# Fixture skill, no markers
EOF

deployed_out="$(bash "$LINT_SCRIPT" --verbose "$C9_DEPLOYED" 2>&1)"
if grep -q "Files checked: 2" <<< "$deployed_out"; then
  common_test_pass "mode probe: deployed fixture (no manifest.json) resolves to deployed and scans the flat commands/skills layout directly (non-empty, both files found)"
else
  common_test_fail "deployed mode probe did not enumerate both fixture files:
$deployed_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
