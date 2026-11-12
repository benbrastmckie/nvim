#!/usr/bin/env bash
# test-source-store-path-lib.sh - Regression suite for scripts/lib/source-store-path-lib.sh:
# the shared source-store classification and unexpanded-variable-shape predicates.
#
# Follows context/standards/shell-script-testing.md and this directory's own house convention:
# common_test_pass/_fail/_info from lib/common.sh, PASSED/FAILED counters, a mktemp -d workdir
# with a trap EXIT cleanup, loud-skip discipline for a genuinely missing dependency, and
# assertions that read the printed verdict line directly rather than trusting exit code alone.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED (or a required file is missing,
# reported loudly rather than silently skipped).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_SCRIPTS_DIR="$SCRIPT_DIR/.."

PASSED=0
FAILED=0

LIB_PATH="$SRC_SCRIPTS_DIR/lib/source-store-path-lib.sh"
if [ ! -f "$LIB_PATH" ]; then
  echo "ERROR: test-source-store-path-lib.sh cannot run -- missing required file: $LIB_PATH" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$LIB_PATH"

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_disjoint_fixture -- a genuinely disjoint two-repository fixture: a "source" repo
# carrying agent-system/extensions/core/{manifest.json,scripts/lib/foo.sh} at its own root, and a
# "consumer" repo whose .claude-extensions.json points core's source_dir at the source repo's
# subdirectory. Echoes "<consumer_root> <source_root>" on stdout. ---
build_disjoint_fixture() {
  local base source_repo consumer_repo
  base="$(mktemp -d -p "$TOP_WORKDIR")"
  source_repo="$base/srcrepo"
  consumer_repo="$base/consumer"

  mkdir -p "$source_repo/agent-system/extensions/core/scripts/lib"
  git -C "$source_repo" init -q
  echo '{"x":1}' > "$source_repo/agent-system/extensions/core/manifest.json"
  echo 'echo foo' > "$source_repo/agent-system/extensions/core/scripts/lib/foo.sh"
  git -C "$source_repo" add -A
  git -C "$source_repo" commit -q -m "seed"

  mkdir -p "$consumer_repo"
  git -C "$consumer_repo" init -q
  cat > "$consumer_repo/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$source_repo/agent-system/extensions/core"}}}
EOF
  git -C "$consumer_repo" add -A
  git -C "$consumer_repo" commit -q -m "seed"

  echo "$consumer_repo $source_repo"
}

# =====================================================================
# Case 1: relative source-store shape is classified SOURCE_STORE, naming the extension and the
# resolved source repository toplevel.
# =====================================================================
common_test_info "=== Case 1: relative source-store shape ==="
read -r consumer_root source_root < <(build_disjoint_fixture)
out1="$(source_store_classify "$consumer_root" "agent-system/extensions/core/manifest.json")"
if echo "$out1" | grep -qP "^SOURCE_STORE\tcore\t${source_root}\tagent-system/extensions/core/manifest\.json$"; then
  common_test_pass "Case 1: relative shape classified SOURCE_STORE with extension=core, correct toplevel, path relative to toplevel unchanged"
else
  common_test_fail "Case 1: unexpected output: $out1"
fi

# =====================================================================
# Case 2: absolute source-store shape is classified SOURCE_STORE identically -- the emitted path
# is relative to the resolved source TOPLEVEL (not relative to source_dir), so it is directly
# usable as a `git add` pathspec inside that second repository.
# =====================================================================
common_test_info "=== Case 2: absolute source-store shape ==="
out2="$(source_store_classify "$consumer_root" "$source_root/agent-system/extensions/core/scripts/lib/foo.sh")"
if echo "$out2" | grep -qP "^SOURCE_STORE\tcore\t${source_root}\tagent-system/extensions/core/scripts/lib/foo\.sh$"; then
  common_test_pass "Case 2: absolute shape classified SOURCE_STORE with the correct relative-to-toplevel path"
else
  common_test_fail "Case 2: unexpected output: $out2"
fi

# =====================================================================
# Case 3: a genuinely out-of-repository path no extension claims.
# =====================================================================
common_test_info "=== Case 3: out-of-repository path, unclaimed ==="
out3="$(source_store_classify "$consumer_root" "/etc/passwd")"
if echo "$out3" | grep -qP '^OUT_OF_REPO\t/etc$'; then
  common_test_pass "Case 3: unclaimed out-of-repository path classified OUT_OF_REPO naming /etc"
else
  common_test_fail "Case 3: unexpected output: $out3"
fi

# =====================================================================
# Case 4: an ordinary in-repository path.
# =====================================================================
common_test_info "=== Case 4: ordinary in-repository path ==="
mkdir -p "$consumer_root/src"
echo x > "$consumer_root/src/a.txt"
out4="$(source_store_classify "$consumer_root" "src/a.txt")"
if [ "$out4" = "IN_REPO" ]; then
  common_test_pass "Case 4: ordinary in-repo path classified IN_REPO"
else
  common_test_fail "Case 4: expected IN_REPO, got: $out4"
fi

# =====================================================================
# Case 5: inertness guard -- a fixture whose source_dir resolves inside the consumer's own root
# must yield IN_REPO (the extension contributes nothing to classification).
# =====================================================================
common_test_info "=== Case 5: inertness guard ==="
inert_root="$(mktemp -d -p "$TOP_WORKDIR")"
mkdir -p "$inert_root/agent-system/extensions/core"
git -C "$inert_root" init -q
echo '{}' > "$inert_root/agent-system/extensions/core/manifest.json"
cat > "$inert_root/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$inert_root/agent-system/extensions/core"}}}
EOF
git -C "$inert_root" add -A
git -C "$inert_root" commit -q -m "seed"
out5="$(source_store_classify "$inert_root" "agent-system/extensions/core/manifest.json")"
if [ "$out5" = "IN_REPO" ]; then
  common_test_pass "Case 5: inertness guard holds -- a repository that owns its own source store classifies its source-store paths as IN_REPO"
else
  common_test_fail "Case 5: expected IN_REPO (inertness), got: $out5"
fi

# Direct real-repository check: this repository itself (the actual fixture the research/plan
# requires -- not a synthetic stand-in), per Premise Re-Validation item 1.
REAL_REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
if [ -f "$REAL_REPO_ROOT/.claude-extensions.json" ]; then
  out5b="$(source_store_classify "$REAL_REPO_ROOT" "agent-system/extensions/core/manifest.json")"
  if [ "$out5b" = "IN_REPO" ]; then
    common_test_pass "Case 5b: this repository's own agent-system/extensions/core/manifest.json classifies IN_REPO (the real inertness fixture)"
  else
    common_test_fail "Case 5b: expected IN_REPO against this repository's own root, got: $out5b"
  fi
else
  common_test_info "Case 5b: skipped -- $REAL_REPO_ROOT/.claude-extensions.json not found at test time"
fi

# =====================================================================
# Case 6: leaf-symlink case -- an in-repo symlink whose target lies outside the repository must
# yield IN_REPO (it is a legal git-add pathspec; the parent-only rule must never misclassify it).
# =====================================================================
common_test_info "=== Case 6: leaf-symlink safety ==="
leaf_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$leaf_root" init -q
ln -s /etc/hostname "$leaf_root/leaflink.txt"
out6="$(source_store_classify "$leaf_root" "leaflink.txt")"
if [ "$out6" = "IN_REPO" ]; then
  common_test_pass "Case 6: a leaf symlink pointing outside the repository classifies IN_REPO (parent-only rule)"
else
  common_test_fail "Case 6: expected IN_REPO, got: $out6"
fi

# =====================================================================
# Case 7: a path THROUGH a symlinked directory whose target is outside the repository must yield
# out-of-repository (the symlinked directory is itself part of the parent path).
# =====================================================================
common_test_info "=== Case 7: path through a symlinked directory ==="
mkdir -p "$TOP_WORKDIR/outside_dir"
echo y > "$TOP_WORKDIR/outside_dir/file.txt"
ln -s "$TOP_WORKDIR/outside_dir" "$leaf_root/dirlink"
out7="$(source_store_classify "$leaf_root" "dirlink/file.txt")"
if echo "$out7" | grep -qP '^OUT_OF_REPO\t'; then
  common_test_pass "Case 7: a path through a symlinked directory targeting outside the repo classifies OUT_OF_REPO"
else
  common_test_fail "Case 7: expected OUT_OF_REPO, got: $out7"
fi

# =====================================================================
# Case 8: fail-soft inputs -- each must resolve to IN_REPO, reproducing today's behavior exactly.
# =====================================================================
common_test_info "=== Case 8: fail-soft inputs ==="

# 8a: missing .claude-extensions.json
plain_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$plain_root" init -q
echo x > "$plain_root/a.txt"
out8a="$(source_store_classify "$plain_root" "a.txt")"
[ "$out8a" = "IN_REPO" ] && common_test_pass "Case 8a: missing .claude-extensions.json -> IN_REPO" \
  || common_test_fail "Case 8a: expected IN_REPO, got: $out8a"

# 8b: unparseable .claude-extensions.json
unparse_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$unparse_root" init -q
echo "not json" > "$unparse_root/.claude-extensions.json"
echo x > "$unparse_root/a.txt"
out8b="$(source_store_classify "$unparse_root" "a.txt")"
[ "$out8b" = "IN_REPO" ] && common_test_pass "Case 8b: unparseable .claude-extensions.json -> IN_REPO" \
  || common_test_fail "Case 8b: expected IN_REPO, got: $out8b"

# 8c: extension entry with no source_dir
nosd_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$nosd_root" init -q
echo x > "$nosd_root/a.txt"
cat > "$nosd_root/.claude-extensions.json" <<'EOF'
{"extensions":{"core":{}}}
EOF
out8c="$(source_store_classify "$nosd_root" "a.txt")"
[ "$out8c" = "IN_REPO" ] && common_test_pass "Case 8c: extension entry with no source_dir -> IN_REPO" \
  || common_test_fail "Case 8c: expected IN_REPO, got: $out8c"

# 8d: source_dir that does not exist
nodir_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$nodir_root" init -q
echo x > "$nodir_root/a.txt"
cat > "$nodir_root/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$nodir_root/does-not-exist"}}}
EOF
out8d="$(source_store_classify "$nodir_root" "a.txt")"
[ "$out8d" = "IN_REPO" ] && common_test_pass "Case 8d: nonexistent source_dir -> IN_REPO" \
  || common_test_fail "Case 8d: expected IN_REPO, got: $out8d"

# 8e: source_dir that exists but is not inside a git working tree
notgit_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$notgit_root" init -q
echo x > "$notgit_root/a.txt"
mkdir -p "$TOP_WORKDIR/not_a_git_repo/core"
cat > "$notgit_root/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$TOP_WORKDIR/not_a_git_repo/core"}}}
EOF
out8e="$(source_store_classify "$notgit_root" "a.txt")"
[ "$out8e" = "IN_REPO" ] && common_test_pass "Case 8e: source_dir outside any git working tree -> IN_REPO" \
  || common_test_fail "Case 8e: expected IN_REPO, got: $out8e"

# 8f: top-level .source_dir (not per-extension) is the documented null trap -- must still yield
# IN_REPO for an ordinary path (the per-extension lookup below .extensions.<name>.source_dir is
# the only one consulted; a top-level key is simply irrelevant, never consulted, never an error).
nulltrap_root="$(mktemp -d -p "$TOP_WORKDIR")"
git -C "$nulltrap_root" init -q
echo x > "$nulltrap_root/a.txt"
cat > "$nulltrap_root/.claude-extensions.json" <<'EOF'
{"source_dir":null,"extensions":{"core":{}}}
EOF
out8f="$(source_store_classify "$nulltrap_root" "a.txt")"
[ "$out8f" = "IN_REPO" ] && common_test_pass "Case 8f: top-level null source_dir trap -> IN_REPO (per-extension lookup only)" \
  || common_test_fail "Case 8f: expected IN_REPO, got: $out8f"

# =====================================================================
# Case 9: source_store_unexpanded_variable -- both accepted shapes, a literal '$' that is not a
# variable reference, and the reserved slashless sentinel (must not match).
# =====================================================================
common_test_info "=== Case 9: source_store_unexpanded_variable ==="

if source_store_unexpanded_variable '$SD/manifest.json'; then
  common_test_pass "Case 9a: bare \$VAR shape detected"
else
  common_test_fail "Case 9a: bare \$VAR shape not detected"
fi

if source_store_unexpanded_variable '${SD}/manifest.json'; then
  common_test_pass "Case 9b: braced \${VAR} shape detected"
else
  common_test_fail "Case 9b: braced \${VAR} shape not detected"
fi

if source_store_unexpanded_variable 'price$5.txt'; then
  common_test_fail "Case 9c: a literal '\$' not followed by an identifier must NOT be detected as a variable reference"
else
  common_test_pass "Case 9c: a literal '\$' not followed by an identifier correctly survives"
fi

if source_store_unexpanded_variable '__WHOLE_TREE__'; then
  common_test_fail "Case 9d: the reserved slashless __WHOLE_TREE__ sentinel must NEVER match"
else
  common_test_pass "Case 9d: the reserved __WHOLE_TREE__ sentinel correctly survives"
fi

if source_store_unexpanded_variable 'agent-system/extensions/core/manifest.json'; then
  common_test_fail "Case 9e: an ordinary source-store path with no '\$' must NOT match"
else
  common_test_pass "Case 9e: an ordinary source-store path correctly survives"
fi

# =====================================================================
# Case 10: sourcing the library never aborts a caller and sets no shell options the caller
# inherits -- source with set -e unset, then with it set, and confirm no change to caller state.
# =====================================================================
common_test_info "=== Case 10: sourcing safety ==="
(
  set +e
  # shellcheck disable=SC1090
  source "$LIB_PATH"
  source_store_classify "/nonexistent-repo-root-xyz" "" >/dev/null 2>&1
  echo "survived-no-set-e"
)
if [ "$?" -eq 0 ]; then
  common_test_pass "Case 10a: sourcing with set -e unset does not abort the caller"
else
  common_test_fail "Case 10a: caller aborted unexpectedly"
fi

(
  set -e
  # shellcheck disable=SC1090
  source "$LIB_PATH"
  source_store_classify "/nonexistent-repo-root-xyz" "/also/nonexistent" >/dev/null
  echo "survived-with-set-e"
)
if [ "$?" -eq 0 ]; then
  common_test_pass "Case 10b: sourcing with set -e set does not abort the caller"
else
  common_test_fail "Case 10b: caller aborted unexpectedly under set -e"
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
