#!/usr/bin/env bash
# test-git-corpus-enum-lib.sh - Fixture-driven regression suite for
# scripts/lib/git-corpus-enum-lib.sh, the shared tracked-plus-untracked union enumeration this
# task extracted to fix check-record-versioning.sh's and check-task-references.sh's PATH_SCOPE
# false-clean defect (an on-disk-but-untracked file enumerating zero rows from a bare
# `git ls-files PATH_SCOPE`).
#
# Structural model: scripts/tests/test-record-version-patterns.sh (deploy-tree-first /
# source-store-fallback library resolution, sourced directly rather than driven as a subprocess,
# pass()/fail() counters via lib/common.sh's common_test_pass/_fail, exit 0/1/2 convention from
# context/standards/shell-script-testing.md). This suite builds its own throwaway git fixtures
# per case via mktemp, since the library's whole contract is about git tracked/untracked state.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# not found, git not on PATH).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "shared library git-corpus-enum-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/git-corpus-enum-lib.sh" \
  "$SCRIPT_DIR/../lib/git-corpus-enum-lib.sh")" || exit 2
common_test_declare_subject "$LIB"
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git not found on PATH" >&2
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB"

PASSED=0
FAILED=0

common_test_workdir_init

# =====================================================================
# Shared fixture: a tracked file, an untracked-but-not-ignored file, and a gitignored file, each
# under docs/, plus a second top-level directory (ignored/) that is wholly gitignored.
# =====================================================================
FIXTURE="$WORKDIR/fixture"
mkdir -p "$FIXTURE/docs" "$FIXTURE/ignored"
git init -q "$FIXTURE"
git -C "$FIXTURE" config user.email "test@example.com"
git -C "$FIXTURE" config user.name "Test"
echo "tracked" > "$FIXTURE/docs/tracked.md"
echo "ignored/" > "$FIXTURE/.gitignore"
git -C "$FIXTURE" add -- docs/tracked.md .gitignore
git -C "$FIXTURE" commit -q -m "fixture: tracked file + gitignore"
echo "untracked" > "$FIXTURE/docs/untracked.md"
echo "ignored content" > "$FIXTURE/ignored/scratch.md"

# =====================================================================
# Case 1: tracked file is included in the union.
# =====================================================================
out1="$(git_corpus_enum "$FIXTURE" docs)"
if echo "$out1" | grep -qxF "docs/tracked.md"; then
  common_test_pass "tracked file included in git_corpus_enum"
else
  common_test_fail "tracked file missing from union; got:
$out1"
fi

# =====================================================================
# Case 2: untracked-but-not-ignored file is included in the union (the acceptance-critical case).
# =====================================================================
if echo "$out1" | grep -qxF "docs/untracked.md"; then
  common_test_pass "untracked-not-ignored file included in git_corpus_enum"
else
  common_test_fail "untracked file missing from union; got:
$out1"
fi

# =====================================================================
# Case 3: gitignored file is excluded from the union.
# =====================================================================
out3="$(git_corpus_enum "$FIXTURE" ignored)"
if echo "$out3" | grep -qxF "ignored/scratch.md"; then
  common_test_fail "gitignored file was included in union (should be excluded); got:
$out3"
else
  common_test_pass "gitignored file correctly excluded from git_corpus_enum"
fi

# =====================================================================
# Case 4: scoped single untracked file is enumerated by name.
# =====================================================================
out4="$(git_corpus_enum "$FIXTURE" docs/untracked.md)"
if [[ "$out4" == "docs/untracked.md" ]]; then
  common_test_pass "scoped single untracked file enumerated by name"
else
  common_test_fail "scoped single untracked file not enumerated; got: $out4"
fi

# =====================================================================
# Case 5: union is deduplicated and sorted (lexicographic, stable across repeated calls).
# =====================================================================
out5a="$(git_corpus_enum "$FIXTURE" docs)"
out5b="$(git_corpus_enum "$FIXTURE" docs)"
expected_sorted="$(printf '%s\n' "$out5a" | sort -u)"
if [[ "$out5a" == "$out5b" ]] && [[ "$out5a" == "$expected_sorted" ]]; then
  common_test_pass "union deduplicated and sorted, stable across repeated calls"
else
  common_test_fail "union not stable/sorted; first=$out5a second=$out5b"
fi

# =====================================================================
# Case 6: non-existent enum_path returns empty without error.
# =====================================================================
out6="$(git_corpus_enum "$FIXTURE" "nonexistent-scope-xyz" 2>&1)"
rc6=$?
if [[ "$rc6" -eq 0 ]] && [[ -z "$out6" ]]; then
  common_test_pass "non-existent enum_path returns empty without error"
else
  common_test_fail "non-existent enum_path expected empty/0, got rc=$rc6 output: $out6"
fi

# =====================================================================
# Case 7: git_corpus_unenumerated_report names a gitignored file under a scoped path.
# =====================================================================
out7="$(git_corpus_unenumerated_report "$FIXTURE" ignored)"
if echo "$out7" | grep -qF "[SKIP] ignored/scratch.md: gitignored (not scanned)"; then
  common_test_pass "git_corpus_unenumerated_report names the gitignored file and reason"
else
  common_test_fail "unenumerated report did not name ignored/scratch.md; got:
$out7"
fi

# =====================================================================
# Case 8: git_corpus_unenumerated_report is silent when there is nothing excluded.
# =====================================================================
out8="$(git_corpus_unenumerated_report "$FIXTURE" docs)"
if [[ -z "$out8" ]]; then
  common_test_pass "git_corpus_unenumerated_report silent when nothing is excluded"
else
  common_test_fail "expected silence for docs/ (nothing excluded); got:
$out8"
fi

# =====================================================================
# Case 9: git_corpus_untracked_count is accurate.
# =====================================================================
count9="$(git_corpus_untracked_count "$FIXTURE" docs)"
if [[ "$count9" == "1" ]]; then
  common_test_pass "git_corpus_untracked_count accurate for docs/ (1 untracked file)"
else
  common_test_fail "expected untracked count 1 for docs/, got: $count9"
fi
count9b="$(git_corpus_untracked_count "$FIXTURE" ignored)"
if [[ "$count9b" == "0" ]]; then
  common_test_pass "git_corpus_untracked_count is 0 for ignored/ (the one file there is gitignored, not merely untracked)"
else
  common_test_fail "expected untracked count 0 for ignored/, got: $count9b"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
