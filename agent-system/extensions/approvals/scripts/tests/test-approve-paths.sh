#!/usr/bin/env bash
# test-approve-paths.sh - Regression suite for approve-paths.sh: component resolution and
# refusal, the task-keyed and no-task-keyed stems, instance-number increment and non-collision
# for both forms, the caller-supplied --out refusal, and the specs/certificates/ tracked-
# directory assertion against the generated specs/.gitignore managed block.
#
# Structural model: test-askuserquestion-rehome.sh (SCRIPT_DIR/git-worktree-first REPO_ROOT
# resolution so this suite works from both the source-store copy and a deployed copy,
# pass()/fail()/info() helpers, PASSED/FAILED counters, exit 0/1/2).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

SOURCE_STORE_SCRIPT="$REPO_ROOT/agent-system/extensions/approvals/scripts/approve-paths.sh"
DEPLOYED_SCRIPT="$REPO_ROOT/.claude/scripts/approve-paths.sh"
if [[ -f "$SOURCE_STORE_SCRIPT" ]]; then
  APPROVE_PATHS="$SOURCE_STORE_SCRIPT"
elif [[ -f "$DEPLOYED_SCRIPT" ]]; then
  APPROVE_PATHS="$DEPLOYED_SCRIPT"
else
  echo "ERROR: approve-paths.sh not found at either:" >&2
  echo "  $SOURCE_STORE_SCRIPT" >&2
  echo "  $DEPLOYED_SCRIPT" >&2
  exit 2
fi

if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required and was not found on PATH." >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

(
  cd "$WORKDIR" || exit 2
  git init -q
  git config user.email "test@test.com"
  git config user.name "test"
  git commit -q --allow-empty -m init
)

# --- Case 1: missing component refuses --------------------------------------------------
if out="$(bash "$APPROVE_PATHS" --component nonexistent --emit-paths 2>&1)"; then
  fail "missing component: expected non-zero exit, got 0 ($out)"
else
  if grep -q "refused.*no such component" <<< "$out"; then
    pass "missing component refuses with a named message"
  else
    fail "missing component: refused, but message was not the expected named form: $out"
  fi
fi

# --- Set up a fake component for the remaining cases ------------------------------------
mkdir -p "$WORKDIR/components/framed_channel"
cat > "$WORKDIR/components/framed_channel/approve.sh" <<'EOF'
#!/usr/bin/env bash
echo "fake approve.sh"
EOF
chmod +x "$WORKDIR/components/framed_channel/approve.sh"

run_in_workdir() {
  (cd "$WORKDIR" && bash "$APPROVE_PATHS" "$@")
}

# task-ref-ok:begin category 3, command-usage examples for approve-paths.sh's own --task N flag
# --- Case 2: task-keyed stem, instance increment -----------------------------------------
out1="$(run_in_workdir --component framed_channel --task 7 --emit-paths)"
review1="$(head -n1 <<< "$out1")"
if [[ "$review1" == */task-7-01.md ]]; then
  pass "task-keyed stem yields task-7-01 on first call"
else
  fail "task-keyed stem: expected .../task-7-01.md, got: $review1"
fi

touch "$review1"

out2="$(run_in_workdir --component framed_channel --task 7 --emit-paths)"
review2="$(head -n1 <<< "$out2")"
if [[ "$review2" == */task-7-02.md ]]; then
  pass "task-keyed stem increments to task-7-02 after the first file exists"
else
  fail "task-keyed stem increment: expected .../task-7-02.md, got: $review2"
fi

# --- Case 3: no-task (adhoc) stem, instance increment, injectable --date ----------------
out3="$(run_in_workdir --component framed_channel --date 20261009 --emit-paths)"
review3="$(head -n1 <<< "$out3")"
if [[ "$review3" == */adhoc-20261009-01.md ]]; then
  pass "no-task stem yields adhoc-20261009-01 on first call"
else
  fail "no-task stem: expected .../adhoc-20261009-01.md, got: $review3"
fi

touch "$review3"

out4="$(run_in_workdir --component framed_channel --date 20261009 --emit-paths)"
review4="$(head -n1 <<< "$out4")"
if [[ "$review4" == */adhoc-20261009-02.md ]]; then
  pass "second taskless cycle same date yields adhoc-20261009-02 -- no collision"
else
  fail "no-task stem increment: expected .../adhoc-20261009-02.md, got: $review4"
fi

# --- Case 4: an earlier cycle is never overwritten (task-7-01 untouched after task-7-02) -
if [[ -f "$review1" ]]; then
  pass "an earlier cycle (task-7-01) is not overwritten by a later one"
else
  fail "earlier cycle file vanished -- it should never be removed by a later --emit-paths call"
fi

# --- Case 5: caller-supplied --out is refused --------------------------------------------
if out="$(run_in_workdir --component framed_channel --task 7 --out /tmp/whatever --emit-paths 2>&1)"; then
  fail "caller-supplied --out: expected non-zero exit, got 0 ($out)"
else
  if grep -qi "refused.*--out" <<< "$out"; then
    pass "caller-supplied --out is refused"
  else
    fail "caller-supplied --out: refused, but message was not the expected named form: $out"
  fi
fi
# task-ref-ok:end

# --- Case 6: tracked-directory assertion -------------------------------------------------
# specs/certificates/ must NOT be matched by the generated specs/.gitignore managed block.
# Resolve the generating lib source-store-first, deployed second; loud [SKIP] if neither exists
# (never a silent pass).
LIB_SOURCE_STORE="$REPO_ROOT/agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh"
LIB_DEPLOYED="$REPO_ROOT/.claude/scripts/lib/runtime-file-patterns.sh"
if [[ -f "$LIB_SOURCE_STORE" ]]; then
  RUNTIME_FILE_PATTERNS_LIB="$LIB_SOURCE_STORE"
elif [[ -f "$LIB_DEPLOYED" ]]; then
  RUNTIME_FILE_PATTERNS_LIB="$LIB_DEPLOYED"
else
  RUNTIME_FILE_PATTERNS_LIB=""
fi

if [[ -z "$RUNTIME_FILE_PATTERNS_LIB" ]]; then
  info "[SKIP] tracked-directory assertion: runtime-file-patterns.sh not found at either:"
  info "  $LIB_SOURCE_STORE"
  info "  $LIB_DEPLOYED"
else
  (
    # shellcheck source=/dev/null
    source "$RUNTIME_FILE_PATTERNS_LIB"
    mkdir -p "$WORKDIR/gitignore-check/specs"
    cd "$WORKDIR/gitignore-check" || exit 2
    git init -q
    runtime_specs_ignore_block > specs/.gitignore
    mkdir -p specs/certificates
    touch specs/certificates/x.md
    if git check-ignore specs/certificates/x.md >/dev/null 2>&1; then
      echo "MATCHED"
    else
      echo "NOT_MATCHED"
    fi
  ) > "$WORKDIR/gitignore-check.out" 2>&1
  result="$(tail -n1 "$WORKDIR/gitignore-check.out")"
  if [[ "$result" == "NOT_MATCHED" ]]; then
    pass "specs/certificates/ is not matched by the generated specs/.gitignore managed block"
  else
    fail "specs/certificates/ WAS matched by the generated managed block (result: $result) --" \
         "this would make the tracked-directory ruling false; see" \
         "approval-artifact-convention.md"
  fi
fi

echo
echo "=== test-approve-paths.sh: $PASSED passed, $FAILED failed ==="
[[ "$FAILED" -eq 0 ]]
