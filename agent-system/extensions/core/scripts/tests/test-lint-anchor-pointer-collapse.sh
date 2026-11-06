#!/usr/bin/env bash
# test-lint-anchor-pointer-collapse.sh - Both-polarity fixture test for
# scripts/lint/lint-anchor-pointer-collapse.sh.
#
# The lint's job is to fail when a file already registered as collapsed has its removed block
# text reappear verbatim, while staying silent on a registered file that correctly carries only
# the pointer, on a file not registered at all (even if it still carries the full block -- that
# is the expected, not-yet-migrated state mid-tranche), and on an empty/missing registry. Every
# fixture is built in a scratch directory (`--root`) with a scratch registry (`--registry`); this
# suite never depends on, or mutates, the real repository or the real production registry.
#
# Structural model: test-lint-verdict-extraction-anchoring.sh (mktemp -d WORKDIR, deploy-tree-
# first / source-store-fallback candidate resolution, common_test_pass/_fail/_info helpers).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.
# Note this is a test OF a lint: its exit code reports test success, not lint success.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
LINT_SCRIPT="$(common_test_resolve_subject "lint-anchor-pointer-collapse.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lint/lint-anchor-pointer-collapse.sh" \
  "$SCRIPT_DIR/../lint/lint-anchor-pointer-collapse.sh")" || exit 2
common_test_declare_subject "$LINT_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

# Every case builds its own isolated root + registry under $WORKDIR/caseN; nothing is shared
# across cases, so case order and leftover state never matter.

run_lint() {
  # run_lint <root> <registry> [extra args...] -- echoes combined output, returns the lint's exit
  # code via $? (captured by the caller immediately after the call).
  local root="$1" registry="$2"
  shift 2
  bash "$LINT_SCRIPT" --root "$root" --registry "$registry" "$@" 2>&1
}

# =====================================================================
# Case 1 (PASSING): no registry file at all -- nothing collapsed yet.
# =====================================================================
common_test_info "=== PASSING: missing registry is a no-op pass ==="
CASE1="$WORKDIR/case1"
mkdir -p "$CASE1/root"
out="$(run_lint "$CASE1/root" "$CASE1/registry.tsv" --quiet)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "missing registry file exits 0"
else
  common_test_fail "missing registry file exits 0" "exit=$rc; output: $out"
fi

# =====================================================================
# Shared fixture builder for cases 2-5: one anchor file + one registered block text + a handful
# of candidate files.
# =====================================================================
build_shared_fixture() {
  local base="$1"
  mkdir -p "$base/root/agent-system/extensions/core/context/standards"
  mkdir -p "$base/root/agent-system/extensions/core/agents"
  mkdir -p "$base/reg"

  cat > "$base/root/agent-system/extensions/core/context/standards/anchor.md" << 'EOF'
# Anchor Doc

## Owning Heading

Line one of the shared block.
Line two of the shared block.
Line three of the shared block.
EOF

  cat > "$base/reg/block.txt" << 'EOF'
Line one of the shared block.
Line two of the shared block.
Line three of the shared block.
EOF
}

# =====================================================================
# Case 2 (PASSING): a registered migrated file correctly carries only the pointer (block absent).
# =====================================================================
common_test_info "=== PASSING: migrated file carries pointer, not the block ==="
CASE2="$WORKDIR/case2"
build_shared_fixture "$CASE2"
cat > "$CASE2/root/agent-system/extensions/core/agents/collapsed.md" << 'EOF'
# Collapsed agent

See `context/standards/anchor.md` for the owning heading.
EOF
printf 'agent-system/extensions/core/context/standards/anchor.md\tOwning Heading\tagent-system/extensions/core/agents/collapsed.md\tblock.txt\n' \
  > "$CASE2/reg/registry.tsv"
out="$(run_lint "$CASE2/root" "$CASE2/reg/registry.tsv" --quiet)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "migrated file with only the pointer does not trip the lint"
else
  common_test_fail "migrated file with only the pointer does not trip the lint" "exit=$rc; output: $out"
fi

# =====================================================================
# Case 3 (FAILING): a registered migrated file has regressed -- the full block reappeared.
# =====================================================================
common_test_info "=== FAILING: migrated file regressed, block text reintroduced ==="
CASE3="$WORKDIR/case3"
build_shared_fixture "$CASE3"
cat > "$CASE3/root/agent-system/extensions/core/agents/regressed.md" << 'EOF'
# Regressed agent

Line one of the shared block.
Line two of the shared block.
Line three of the shared block.
EOF
printf 'agent-system/extensions/core/context/standards/anchor.md\tOwning Heading\tagent-system/extensions/core/agents/regressed.md\tblock.txt\n' \
  > "$CASE3/reg/registry.tsv"
out="$(run_lint "$CASE3/root" "$CASE3/reg/registry.tsv" --verbose)"
rc=$?
if [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -q 'VIOLATION'; then
  common_test_pass "regressed migrated file trips the lint with a VIOLATION line"
else
  common_test_fail "regressed migrated file trips the lint with a VIOLATION line" "exit=$rc; output: $out"
fi

# =====================================================================
# Case 4 (PASSING): a file NOT registered still carries the full block (expected
# not-yet-migrated mid-tranche state) -- must stay silent, proving this lint is scoped to
# registered files only, never a whole-corpus scan.
# =====================================================================
common_test_info "=== PASSING: not-yet-migrated sibling file is out of scope ==="
CASE4="$WORKDIR/case4"
build_shared_fixture "$CASE4"
cat > "$CASE4/root/agent-system/extensions/core/agents/collapsed.md" << 'EOF'
# Collapsed agent

See `context/standards/anchor.md` for the owning heading.
EOF
# Not-yet-migrated sibling: still carries the full block verbatim, and is deliberately NOT named
# in the file column below.
cat > "$CASE4/root/agent-system/extensions/core/agents/not-yet-migrated.md" << 'EOF'
# Not-yet-migrated agent

Line one of the shared block.
Line two of the shared block.
Line three of the shared block.
EOF
printf 'agent-system/extensions/core/context/standards/anchor.md\tOwning Heading\tagent-system/extensions/core/agents/collapsed.md\tblock.txt\n' \
  > "$CASE4/reg/registry.tsv"
out="$(run_lint "$CASE4/root" "$CASE4/reg/registry.tsv" --quiet)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "a not-yet-migrated sibling carrying the full block does not trip the lint"
else
  common_test_fail "a not-yet-migrated sibling carrying the full block does not trip the lint" "exit=$rc; output: $out"
fi

# =====================================================================
# Case 5 (ENVIRONMENT ERROR): a registry row naming a block_file that does not exist on disk.
# =====================================================================
common_test_info "=== ERROR: registry row with a missing block_file exits 2 ==="
CASE5="$WORKDIR/case5"
build_shared_fixture "$CASE5"
cat > "$CASE5/root/agent-system/extensions/core/agents/collapsed.md" << 'EOF'
# Collapsed agent
EOF
printf 'agent-system/extensions/core/context/standards/anchor.md\tOwning Heading\tagent-system/extensions/core/agents/collapsed.md\tdoes-not-exist.txt\n' \
  > "$CASE5/reg/registry.tsv"
out="$(run_lint "$CASE5/root" "$CASE5/reg/registry.tsv" --quiet)"
rc=$?
if [[ $rc -eq 2 ]]; then
  common_test_pass "missing block_file is reported as an environment error (exit 2)"
else
  common_test_fail "missing block_file is reported as an environment error (exit 2)" "exit=$rc; output: $out"
fi

# =====================================================================
# Case 6 (PASSING): comment and blank lines in the registry are skipped, not misread as rows.
# =====================================================================
common_test_info "=== PASSING: comment/blank registry lines are skipped ==="
CASE6="$WORKDIR/case6"
build_shared_fixture "$CASE6"
cat > "$CASE6/root/agent-system/extensions/core/agents/collapsed.md" << 'EOF'
# Collapsed agent

See `context/standards/anchor.md` for the owning heading.
EOF
{
  echo "# registry.tsv - header comment"
  echo ""
  printf 'agent-system/extensions/core/context/standards/anchor.md\tOwning Heading\tagent-system/extensions/core/agents/collapsed.md\tblock.txt\n'
} > "$CASE6/reg/registry.tsv"
out="$(run_lint "$CASE6/root" "$CASE6/reg/registry.tsv" --quiet)"
rc=$?
if [[ $rc -eq 0 ]]; then
  common_test_pass "comment and blank registry lines are skipped without error"
else
  common_test_fail "comment and blank registry lines are skipped without error" "exit=$rc; output: $out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "================================"
echo "test-lint-anchor-pointer-collapse.sh Summary"
echo "================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ $FAILED -eq 0 ]]; then
  exit 0
else
  exit 1
fi
