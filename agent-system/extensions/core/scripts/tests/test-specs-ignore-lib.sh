#!/usr/bin/env bash
# test-specs-ignore-lib.sh - Regression suite for lib/specs-ignore-lib.sh, the single canonical
# predicate answering whether a repository's specs tree, or one path inside it, is gitignored.
#
# Structural model: test-engine-written-state-paths-lib.sh's library-direct testing style (source
# the real library in a scratch subshell, exercise its exported functions) combined with this
# corpus's scratch-git-repo harness pattern (mktemp -d, per-fixture `git init`), since this
# library's functions are predicates over live repository state rather than a fixed constant.
#
# Follows context/standards/shell-script-testing.md: set -uo pipefail, PASSED/FAILED counters
# with pass()/fail()/info(), mktemp -d workdir with a trap EXIT cleanup, loud-skip discipline.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (library not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "specs-ignore-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/specs-ignore-lib.sh" \
  "$SCRIPT_DIR/../lib/specs-ignore-lib.sh")" || exit 2
common_test_declare_subject "$LIB"

PASSED=0
FAILED=0

common_test_info "Using library: $LIB"

TOP_WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_repo_tracked_specs -- a repo whose specs/ tree is tracked, no .gitignore at all. ---
build_repo_tracked_specs() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  mkdir -p "$repo/specs/999_probe"
  echo "line1" > "$repo/specs/999_probe/file.txt"
  echo "line1" > "$repo/specs/TODO.md"
  git -C "$repo" add specs/999_probe/file.txt specs/TODO.md
  git -C "$repo" commit -q -m "initial (specs tracked)"
  echo "$repo"
}

# --- build_repo_specs_ignored -- a repo whose whole specs/ tree is gitignored, never tracked. ---
build_repo_specs_ignored() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  echo "specs/" > "$repo/.gitignore"
  git -C "$repo" add .gitignore
  git -C "$repo" commit -q -m "initial (.gitignore only)"
  mkdir -p "$repo/specs/999_probe"
  echo "line1" > "$repo/specs/999_probe/file.txt"
  echo "line1" > "$repo/specs/TODO.md"
  echo "$repo"
}

# --- build_repo_specs_subdir_ignored -- specs/ itself NOT ignored (no rule matches the bare
# "specs" pathspec), but one specific task subdirectory inside it is. ---
build_repo_specs_subdir_ignored() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  echo "specs/777_ignored_subdir/" > "$repo/.gitignore"
  git -C "$repo" add .gitignore
  mkdir -p "$repo/specs/999_probe"
  echo "line1" > "$repo/specs/999_probe/file.txt"
  echo "line1" > "$repo/specs/TODO.md"
  git -C "$repo" add specs/999_probe/file.txt specs/TODO.md
  git -C "$repo" commit -q -m "initial (one subdirectory ignored, rest tracked)"
  mkdir -p "$repo/specs/777_ignored_subdir"
  echo "line1" > "$repo/specs/777_ignored_subdir/plan.md"
  echo "$repo"
}

# --- build_repo_tracked_but_ignore_matching -- a file TRACKED FIRST, with a .gitignore rule
# landing afterwards that would ignore-match it if it were untracked (index-awareness property).
build_repo_tracked_but_ignore_matching() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  mkdir -p "$repo/specs/999_probe/archive"
  echo "line1" > "$repo/specs/999_probe/archive/state.json"
  git -C "$repo" add specs/999_probe/archive/state.json
  git -C "$repo" commit -q -m "initial (tracked before any ignore rule exists)"
  echo "specs/999_probe/archive/" > "$repo/.gitignore"
  echo "$repo"
}

# =====================================================================
# Case 1: a tracked-specs repo -> specs_tree_is_gitignored rc 1 (not ignored)
# =====================================================================
repo1="$(build_repo_tracked_specs)"
(
  # shellcheck disable=SC1090
  . "$LIB"
  specs_tree_is_gitignored "$repo1"
)
rc1=$?
if [ "$rc1" -eq 1 ]; then
  common_test_pass "tracked-specs repo: specs_tree_is_gitignored returns rc 1 (not ignored)"
else
  common_test_fail "tracked-specs repo: expected rc 1, got rc ${rc1}"
fi

# =====================================================================
# Case 2: a wholly-ignored-specs repo -> specs_tree_is_gitignored rc 0 (ignored)
# =====================================================================
repo2="$(build_repo_specs_ignored)"
(
  # shellcheck disable=SC1090
  . "$LIB"
  specs_tree_is_gitignored "$repo2"
)
rc2=$?
if [ "$rc2" -eq 0 ]; then
  common_test_pass "wholly-ignored-specs repo: specs_tree_is_gitignored returns rc 0 (ignored)"
else
  common_test_fail "wholly-ignored-specs repo: expected rc 0, got rc ${rc2}"
fi

# Companion: path_is_gitignored on a path inside that same wholly-ignored tree is also rc 0.
(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$repo2" "specs/TODO.md"
)
rc2b=$?
if [ "$rc2b" -eq 0 ]; then
  common_test_pass "wholly-ignored-specs repo: path_is_gitignored(specs/TODO.md) returns rc 0"
else
  common_test_fail "wholly-ignored-specs repo: path_is_gitignored(specs/TODO.md) expected rc 0, got rc ${rc2b}"
fi

# =====================================================================
# Case 3: a repo ignoring only one task subdirectory -> rc 1 for the whole tree, rc 0 for
# path_is_gitignored on that one subdirectory.
# =====================================================================
repo3="$(build_repo_specs_subdir_ignored)"
(
  # shellcheck disable=SC1090
  . "$LIB"
  specs_tree_is_gitignored "$repo3"
)
rc3a=$?
if [ "$rc3a" -eq 1 ]; then
  common_test_pass "partially-ignored repo: specs_tree_is_gitignored returns rc 1 (whole tree not ignored)"
else
  common_test_fail "partially-ignored repo: expected rc 1 for the whole tree, got rc ${rc3a}"
fi

(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$repo3" "specs/777_ignored_subdir"
)
rc3b=$?
if [ "$rc3b" -eq 0 ]; then
  common_test_pass "partially-ignored repo: path_is_gitignored on the ignored subdirectory returns rc 0"
else
  common_test_fail "partially-ignored repo: expected rc 0 for the ignored subdirectory, got rc ${rc3b}"
fi

(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$repo3" "specs/999_probe/file.txt"
)
rc3c=$?
if [ "$rc3c" -eq 1 ]; then
  common_test_pass "partially-ignored repo: path_is_gitignored on the tracked sibling returns rc 1"
else
  common_test_fail "partially-ignored repo: expected rc 1 for the tracked sibling, got rc ${rc3c}"
fi

# =====================================================================
# Case 4: index-awareness -- a tracked-but-ignore-matching file reports path_is_gitignored rc 1,
# asserted directly rather than assumed. This is the property that makes a separate
# tracked/untracked test unnecessary at any call site.
# =====================================================================
repo4="$(build_repo_tracked_but_ignore_matching)"
(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$repo4" "specs/999_probe/archive/state.json"
)
rc4=$?
if [ "$rc4" -eq 1 ]; then
  common_test_pass "tracked-but-ignore-matching file: path_is_gitignored returns rc 1 (index-awareness)"
else
  common_test_fail "tracked-but-ignore-matching file: expected rc 1 (not ignored, already tracked), got rc ${rc4}"
fi

# =====================================================================
# Case 5: fail-open direction -- a nonexistent repo_root yields a non-zero rc from both
# functions, never rc 0.
# =====================================================================
NONEXISTENT_ROOT="$TOP_WORKDIR/does-not-exist-$$"
(
  # shellcheck disable=SC1090
  . "$LIB"
  specs_tree_is_gitignored "$NONEXISTENT_ROOT"
)
rc5a=$?
if [ "$rc5a" -ne 0 ]; then
  common_test_pass "fail-open: specs_tree_is_gitignored on a nonexistent repo_root returns non-zero"
else
  common_test_fail "fail-open: specs_tree_is_gitignored on a nonexistent repo_root returned rc 0 -- must never fail-open to 'ignored'"
fi

(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$NONEXISTENT_ROOT" "specs/TODO.md"
)
rc5b=$?
if [ "$rc5b" -ne 0 ]; then
  common_test_pass "fail-open: path_is_gitignored on a nonexistent repo_root returns non-zero"
else
  common_test_fail "fail-open: path_is_gitignored on a nonexistent repo_root returned rc 0 -- must never fail-open to 'ignored'"
fi

# Companion: empty arguments also fail open, never rc 0.
(
  # shellcheck disable=SC1090
  . "$LIB"
  specs_tree_is_gitignored ""
)
rc5c=$?
if [ "$rc5c" -ne 0 ]; then
  common_test_pass "fail-open: specs_tree_is_gitignored with an empty repo_root returns non-zero"
else
  common_test_fail "fail-open: specs_tree_is_gitignored with an empty repo_root returned rc 0"
fi

(
  # shellcheck disable=SC1090
  . "$LIB"
  path_is_gitignored "$repo1" ""
)
rc5d=$?
if [ "$rc5d" -ne 0 ]; then
  common_test_pass "fail-open: path_is_gitignored with an empty path returns non-zero"
else
  common_test_fail "fail-open: path_is_gitignored with an empty path returned rc 0"
fi

# =====================================================================
# Case 6: sourcing the library emits nothing on stdout or stderr at source time.
# =====================================================================
SOURCE_SILENT="$(
  # shellcheck disable=SC1090
  { . "$LIB"; } 2>&1
  echo "SOURCE_SILENT_MARKER"
)"
if [ "$(echo "$SOURCE_SILENT" | head -1)" = "SOURCE_SILENT_MARKER" ]; then
  common_test_pass "sourcing emits nothing on stdout or stderr at source time"
else
  common_test_fail "sourcing produced unexpected output before the marker: <<<${SOURCE_SILENT}>>>"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
