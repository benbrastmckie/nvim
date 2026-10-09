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
#
# Structural model: tests/test-assess-repo-health.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, deploy-tree-first/source-store-fallback resolution, exit 0 on all-pass /
# exit 1 on any-fail).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (script-inventory.sh not found, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/script-inventory.sh"
  "$SCRIPT_DIR/../script-inventory.sh"
)
TOOL=""
for candidate in "${SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TOOL="$candidate"
    break
  fi
done
if [[ -z "$TOOL" ]]; then
  echo "ERROR: script-inventory.sh not found at any of:" >&2
  for candidate in "${SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot exercise script-inventory.sh" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

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
  pass "enumeration: candidate_count == 1 (tests/ and test-* excluded)"
else
  fail "enumeration: candidate_count == $enum_count (expected 1); stderr: $(cat "$WORKDIR/enum_stderr")"
fi
if [ "$enum_paths" = "agent-system/extensions/core/scripts/real.sh" ]; then
  pass "enumeration: only real.sh enumerated"
else
  fail "enumeration: unexpected enumerated set: $enum_paths"
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
  pass "size metrics: lines == $expected_lines"
else
  fail "size metrics: lines == $got_lines (expected $expected_lines)"
fi
if [ "$got_bytes" = "$expected_bytes" ]; then
  pass "size metrics: bytes == $expected_bytes"
else
  fail "size metrics: bytes == $got_bytes (expected $expected_bytes)"
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
  pass "caller counting: a.sh has exactly 1 caller (b.sh), excluding itself"
else
  fail "caller counting: a.sh callers=$a_callers paths=[$a_caller_paths] (expected 1, b.sh only)"
fi
if [ "$b_zero" = "true" ]; then
  pass "caller counting: b.sh (referenced by nothing) has zero_caller_finding == true"
else
  fail "caller counting: b.sh zero_caller_finding == $b_zero (expected true)"
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
  pass "has_test: tested.sh reports true with correct test_paths"
else
  fail "has_test: tested.sh has_test=$tested_has test_paths=[$tested_paths]"
fi
if [ "$untested_has" = "false" ] && [ "$untested_paths_count" = "0" ]; then
  pass "has_test: untested.sh reports false with empty test_paths"
else
  fail "has_test: untested.sh has_test=$untested_has test_paths_count=$untested_paths_count"
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
    pass "degenerate root: candidate_count 0, scripts [], summary null"
  else
    fail "degenerate root: count=$degen_count scripts_len=$degen_scripts_len summary=$degen_summary"
  fi
else
  fail "degenerate root: script-inventory.sh exited non-zero; stderr: $(cat "$WORKDIR/degen_stderr")"
fi

# =====================================================================
# Usage error: --root with no following argument exits 1.
# =====================================================================
set +e
bash "$TOOL" --root >/dev/null 2>"$WORKDIR/usage_stderr"
usage_exit=$?
set -e 2>/dev/null || true
if [ "$usage_exit" -eq 1 ]; then
  pass "usage error: --root with no argument exits 1"
else
  fail "usage error: --root with no argument exited $usage_exit (expected 1)"
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
  pass "no side effects: fixture root file manifest unchanged across a run"
else
  fail "no side effects: fixture root file manifest changed; before=[$before_manifest] after=[$after_manifest]"
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
    pass "manifest_registered: registered.sh (declared in provides.scripts) reports true"
  else
    fail "manifest_registered: registered.sh reports $reg_val (expected true); stderr: $(cat "$WORKDIR/manifest_stderr")"
  fi
  if [ "$unreg_val" = "false" ]; then
    pass "manifest_registered: unregistered.sh (absent from provides.scripts) reports false"
  else
    fail "manifest_registered: unregistered.sh reports $unreg_val (expected false)"
  fi
  if [ "$unreg_zero" = "false" ]; then
    pass "manifest_registered isolation: unregistered.sh has a real caller, so its finding is manifest-drift only, not also zero-caller"
  else
    fail "manifest_registered isolation: unregistered.sh zero_caller_finding == $unreg_zero (expected false -- registered.sh references it)"
  fi

  set +e
  bash "$TOOL" --root "$MANIFEST_DIR" --check >/dev/null 2>"$WORKDIR/manifest_check_stderr"
  manifest_check_exit=$?
  set -e 2>/dev/null || true
  if [ "$manifest_check_exit" -eq 1 ]; then
    pass "--check: manifest-drift-only fixture exits 1 (zero zero-caller findings present)"
  else
    fail "--check: manifest-drift fixture exited $manifest_check_exit (expected 1)"
  fi
else
  info "git not on PATH -- skipping manifest_registered git-fixture cases"
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
  pass "--check: fully clean fixture (registered + referenced via its own test file) exits 0"
else
  fail "--check: clean fixture exited $cleancheck_exit (expected 0); stderr: $(cat "$WORKDIR/cleancheck_stderr")"
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
  pass "duplicate-block detection: dup1.sh/dup2.sh's shared 10-line block is detected, cross-referenced to its peer"
else
  fail "duplicate-block detection: dup1.sh duplicate_blocks=$dup1_count peers=[$dup1_peers] (expected >=1, peer dup2.sh); stderr: $(cat "$WORKDIR/dup_stderr")"
fi
if [ "$lone_count" = "0" ]; then
  pass "duplicate-block detection: a same-length but unshared block is NOT reported (below the 2-file / 3-occurrence threshold)"
else
  fail "duplicate-block detection: lone.sh duplicate_blocks=$lone_count (expected 0)"
fi

# =====================================================================
# Rank ordering stable across two runs on the same fixture (full-output diff excluding the one
# documented non-reproducible field, generated_at).
# =====================================================================
RANK_RUN1="$(bash "$TOOL" --root "$DUP_DIR" 2>/dev/null | jq 'del(.generated_at)')"
RANK_RUN2="$(bash "$TOOL" --root "$DUP_DIR" 2>/dev/null | jq 'del(.generated_at)')"
if [ "$RANK_RUN1" = "$RANK_RUN2" ]; then
  pass "rank ordering: two consecutive runs on the same fixture are identical modulo generated_at"
else
  fail "rank ordering: two consecutive runs diverged"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
