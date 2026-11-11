#!/usr/bin/env bash
# test-commit-source-store-path.sh - Regression suite for commit-source-store-path.sh: the
# single-pathspec, fail-open mechanism that commits a SOURCE_STORE-classified path in its own
# (second) repository, as part of phase closure rather than left to agent vigilance.
#
# Harness: each case builds the DEPLOYING repo's scratch fixture (mirroring
# test-git-commit-phase.sh's and test-git-commit-scoped.sh's own convention: the script and its
# runtime dependency, lib/common.sh, copied into <scratch>/.claude/scripts/, so
# common_repo_root resolves <scratch> as "this script's own repository root") and a genuinely
# SEPARATE second `git init` repository as the commit target -- the disjoint scenario the
# containment remedy requires.
#
# Follows context/standards/shell-script-testing.md: set -uo pipefail, PASSED/FAILED counters
# with common_test_pass/_fail/_info, mktemp -d workdir with a trap EXIT cleanup, loud-skip
# discipline for a genuinely missing dependency, and assertions that read HEAD/working-tree
# content directly rather than trusting exit code alone.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required script is
# missing, reported loudly).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

REQUIRED_SCRIPTS=(commit-source-store-path.sh lib/common.sh)
missing=()
for f in "${REQUIRED_SCRIPTS[@]}"; do
  [ -f "$SRC_SCRIPTS_DIR/$f" ] || missing+=("$f")
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "ERROR: test-commit-source-store-path.sh cannot run -- missing required script(s) under $SRC_SCRIPTS_DIR: ${missing[*]}" >&2
  exit 1
fi

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_caller_repo -- the "this repository" fixture: a scratch git repo carrying
# commit-source-store-path.sh plus lib/common.sh deployed at .claude/scripts/, satisfying
# common_repo_root's own resolution. Echoes the repo path. ---
build_caller_repo() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"

  mkdir -p "$repo/.claude/scripts/lib"
  local f
  for f in "${REQUIRED_SCRIPTS[@]}"; do
    mkdir -p "$repo/.claude/scripts/$(dirname "$f")"
    cp "$SRC_SCRIPTS_DIR/$f" "$repo/.claude/scripts/$f"
  done
  chmod +x "$repo/.claude/scripts/commit-source-store-path.sh"

  echo "placeholder" > "$repo/placeholder.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "initial"

  echo "$repo"
}

# --- build_target_repo -- a genuinely SEPARATE "second repository" fixture, with one tracked
# file (doc.md) and one other tracked file (unrelated.txt) left dirty by the caller to prove the
# untouched-foreign-dirty-file property. Echoes the repo path. ---
build_target_repo() {
  local repo
  repo="$(mktemp -d -p "$TOP_WORKDIR")"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  echo "original" > "$repo/doc.md"
  echo "original unrelated" > "$repo/unrelated.txt"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "seed"
  echo "$repo"
}

run_commit() {
  local caller_repo="$1"
  shift
  bash "$caller_repo/.claude/scripts/commit-source-store-path.sh" "$@"
}

# =====================================================================
# Case 1 (happy path): the named path lands in the second repository; nothing else is staged
# there; a concurrently dirty unrelated file in that repository is left untouched and
# uncommitted.
# =====================================================================
common_test_info "=== Case 1: happy path ==="

caller1="$(build_caller_repo)"
target1="$(build_target_repo)"
echo "modified doc" > "$target1/doc.md"
echo "concurrently dirty" > "$target1/unrelated.txt"

before1=$(git -C "$target1" rev-list --count HEAD)
out1="$(run_commit "$caller1" "$target1" "doc.md" "commit the doc" "sess_1" 2>&1)"
rc1=$?
after1=$(git -C "$target1" rev-list --count HEAD)
show1="$(git -C "$target1" show --name-only --format= HEAD)"

if [ "$rc1" -eq 0 ] && [ "$after1" -eq $((before1 + 1)) ] && echo "$show1" | grep -qF "doc.md" && ! echo "$show1" | grep -qF "unrelated.txt"; then
  common_test_pass "Case 1: doc.md landed in the second repository; unrelated.txt was not swept in"
else
  common_test_fail "Case 1: expected rc=0, HEAD+1, doc.md only; got rc=$rc1 before=$before1 after=$after1 show='$show1' out=$out1"
fi

status1="$(git -C "$target1" status --porcelain -- unrelated.txt)"
if [ -n "$status1" ]; then
  common_test_pass "Case 1: the concurrently dirty unrelated.txt is left untouched and still dirty"
else
  common_test_fail "Case 1: unrelated.txt should still be dirty (uncommitted) after the targeted commit"
fi

sha1="$(echo "$out1" | tail -1)"
headsha1="$(git -C "$target1" rev-parse HEAD)"
if [ "$sha1" = "$headsha1" ]; then
  common_test_pass "Case 1: stdout's last line is the resulting commit SHA"
else
  common_test_fail "Case 1: expected stdout to end with the commit SHA ($headsha1); got: $out1"
fi

# =====================================================================
# Case 2 (benign no-op): the path is already clean -- exit 1, NOT a failure, no commit created.
# =====================================================================
common_test_info "=== Case 2: already-clean path is a benign no-op (exit 1) ==="

before2=$(git -C "$target1" rev-list --count HEAD)
out2="$(run_commit "$caller1" "$target1" "doc.md" "again" "sess_2" 2>&1)"
rc2=$?
after2=$(git -C "$target1" rev-list --count HEAD)

if [ "$rc2" -eq 1 ] && [ "$after2" -eq "$before2" ]; then
  common_test_pass "Case 2: exit 1, no new commit created"
else
  common_test_fail "Case 2: expected rc=1 and no new commit; got rc=$rc2 before=$before2 after=$after2 out=$out2"
fi

if echo "$out2" | grep -qF "nothing to commit"; then
  common_test_pass "Case 2: stderr explains the benign no-op"
else
  common_test_fail "Case 2: expected a 'nothing to commit' message; got: $out2"
fi

# =====================================================================
# Case 3 (refusal: target equals caller's own repository root).
# =====================================================================
common_test_info "=== Case 3: target_root equals this script's own repository root ==="

out3="$(run_commit "$caller1" "$caller1" "placeholder.txt" "x" "sess_3" 2>&1)"
rc3=$?
if [ "$rc3" -eq 3 ]; then
  common_test_pass "Case 3: exit 3"
else
  common_test_fail "Case 3: expected exit 3; got rc=$rc3 out=$out3"
fi
if echo "$out3" | grep -qF "equals this script's own repository root"; then
  common_test_pass "Case 3: stderr names the reason"
else
  common_test_fail "Case 3: expected the own-repository-root reason; got: $out3"
fi
if echo "$out3" | grep -qF "Manual recovery:"; then
  common_test_pass "Case 3: the exact manual command is printed"
else
  common_test_fail "Case 3: expected a manual-recovery line; got: $out3"
fi

# =====================================================================
# Case 4 (refusal: target is not a git working tree).
# =====================================================================
common_test_info "=== Case 4: target_root is not a git working tree ==="

notgit4="$(mktemp -d -p "$TOP_WORKDIR")"
echo "x" > "$notgit4/a.txt"
out4="$(run_commit "$caller1" "$notgit4" "a.txt" "x" "sess_4" 2>&1)"
rc4=$?
if [ "$rc4" -eq 4 ]; then
  common_test_pass "Case 4: exit 4"
else
  common_test_fail "Case 4: expected exit 4; got rc=$rc4 out=$out4"
fi
if echo "$out4" | grep -qF "is not a git working tree"; then
  common_test_pass "Case 4: stderr names the reason"
else
  common_test_fail "Case 4: expected the not-a-git-working-tree reason; got: $out4"
fi

# =====================================================================
# Case 5 (refusal: detached HEAD).
# =====================================================================
common_test_info "=== Case 5: detached HEAD ==="

target5="$(build_target_repo)"
git -C "$target5" checkout -q --detach HEAD
echo "modified" > "$target5/doc.md"
out5="$(run_commit "$caller1" "$target5" "doc.md" "x" "sess_5" 2>&1)"
rc5=$?
if [ "$rc5" -eq 5 ]; then
  common_test_pass "Case 5: exit 5"
else
  common_test_fail "Case 5: expected exit 5; got rc=$rc5 out=$out5"
fi
if echo "$out5" | grep -qF "detached"; then
  common_test_pass "Case 5: stderr names the reason"
else
  common_test_fail "Case 5: expected the detached-HEAD reason; got: $out5"
fi
status5="$(git -C "$target5" status --porcelain -- doc.md)"
if [ -n "$status5" ]; then
  common_test_pass "Case 5: doc.md is left uncommitted"
else
  common_test_fail "Case 5: doc.md should remain uncommitted"
fi

# =====================================================================
# Case 6 (refusal: an in-progress merge -- MERGE_HEAD planted).
# =====================================================================
common_test_info "=== Case 6: in-progress merge (MERGE_HEAD) ==="

target6="$(build_target_repo)"
git -C "$target6" rev-parse HEAD > "$target6/.git/MERGE_HEAD"
echo "modified" > "$target6/doc.md"
out6="$(run_commit "$caller1" "$target6" "doc.md" "x" "sess_6" 2>&1)"
rc6=$?
if [ "$rc6" -eq 6 ]; then
  common_test_pass "Case 6: exit 6"
else
  common_test_fail "Case 6: expected exit 6; got rc=$rc6 out=$out6"
fi
if echo "$out6" | grep -qF "in-progress merge"; then
  common_test_pass "Case 6: stderr names the reason"
else
  common_test_fail "Case 6: expected the in-progress-merge reason; got: $out6"
fi

# =====================================================================
# Case 7 (refusal: an existing index.lock).
# =====================================================================
common_test_info "=== Case 7: existing index.lock ==="

target7="$(build_target_repo)"
touch "$target7/.git/index.lock"
echo "modified" > "$target7/doc.md"
out7="$(run_commit "$caller1" "$target7" "doc.md" "x" "sess_7" 2>&1)"
rc7=$?
rm -f "$target7/.git/index.lock"
if [ "$rc7" -eq 7 ]; then
  common_test_pass "Case 7: exit 7"
else
  common_test_fail "Case 7: expected exit 7; got rc=$rc7 out=$out7"
fi
if echo "$out7" | grep -qF "index.lock"; then
  common_test_pass "Case 7: stderr names the reason"
else
  common_test_fail "Case 7: expected the index.lock reason; got: $out7"
fi

# =====================================================================
# Case 8 (refusal: missing target file).
# =====================================================================
common_test_info "=== Case 8: missing target file ==="

target8="$(build_target_repo)"
out8="$(run_commit "$caller1" "$target8" "does-not-exist.md" "x" "sess_8" 2>&1)"
rc8=$?
if [ "$rc8" -eq 8 ]; then
  common_test_pass "Case 8: exit 8"
else
  common_test_fail "Case 8: expected exit 8; got rc=$rc8 out=$out8"
fi
if echo "$out8" | grep -qF "does not exist"; then
  common_test_pass "Case 8: stderr names the reason"
else
  common_test_fail "Case 8: expected the missing-file reason; got: $out8"
fi

# =====================================================================
# Case 9 (usage error: wrong argument count).
# =====================================================================
common_test_info "=== Case 9: usage error ==="

out9="$(bash "$caller1/.claude/scripts/commit-source-store-path.sh" "$target1" "doc.md" 2>&1)"
rc9=$?
if [ "$rc9" -eq 2 ]; then
  common_test_pass "Case 9: exit 2 on wrong argument count"
else
  common_test_fail "Case 9: expected exit 2; got rc=$rc9 out=$out9"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
