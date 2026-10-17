#!/usr/bin/env bash
# test-lint-agent-contracts-await-notification.sh - Fixture-driven regression suite for Check K
# (detach-then-await-a-notification antipattern absence) in lint-agent-contracts.sh.
#
# Modeled on test-lint-agent-contracts-heartbeat.sh's shape: an isolated scratch
# agent-system/extensions/ tree (mktemp -d), the real lint-agent-contracts.sh run against it via
# REPO_ROOT=<scratch> (the source-store invocation override the lint script itself documents),
# and assertions scoped to Check K's own section of the output (other checks read canonical
# bullet/template text these minimal fixtures do not carry and legitimately FAIL independently).
#
# Four cases:
#   1. A CLEAN agent (neither phrase at all) -- PASS.
#   2. A VIOLATING agent (pairs a backgrounding instruction with a wait-for-notification
#      instruction, no prohibitive marker nearby) -- FAIL.
#   3. A FORMERLY-EXCLUDED-PATH agent carrying the SAME violating text as case 2, at the path
#      (`lean/agents/lean-implementation-agent.md`) Check K's `CHECK_K_EXCLUDED_RELATIVE_PATHS`
#      used to exclude before that exclusion's own migration-complete removal condition was
#      discharged -- this now FAILs Check K like any other dispatchable agent contract, never a
#      silently-skipped exclusion. This is the removal condition's own stated purpose turned into
#      a regression test: a stale exclusion remaining after its own migration would mask a
#      reintroduced violation behind a silent skip instead of a FAIL.
#   4. A PROHIBITIVELY-QUOTING agent (both phrases present, but inside a sentence stating the
#      prohibition, e.g. "MUST NOT ... wait for ... completion notification") -- PASS.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SRC="$SCRIPT_DIR/../lint/lint-agent-contracts.sh"
FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/no-task-references-bullet.md"
ARTIFACTS_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/return-meta-artifacts-template.md"
STATUS_LIB_SRC="$SCRIPT_DIR/../lib/return-meta-status-vocabulary.sh"
PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/plan-status-ownership.md"
BOUNDED_WAIT_FRAGMENT_SRC="$SCRIPT_DIR/../../context/patterns/bounded-build-waiter.md"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

for req in "$LINT_SRC" "$FRAGMENT_SRC" "$ARTIFACTS_FRAGMENT_SRC" "$STATUS_LIB_SRC" \
           "$PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" "$BOUNDED_WAIT_FRAGMENT_SRC"; do
  if [ ! -f "$req" ]; then
    echo "ERROR: expected required file at $req" >&2
    exit 1
  fi
done

build_fixture_tree() {
  local root="$1"
  mkdir -p "$root/agent-system/extensions/core/context/contracts"
  mkdir -p "$root/agent-system/extensions/core/context/patterns"
  mkdir -p "$root/agent-system/extensions/core/docs/reference/standards"
  mkdir -p "$root/agent-system/extensions/core/scripts/lib"
  cp "$FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/no-task-references-bullet.md"
  cp "$ARTIFACTS_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md"
  cp "$STATUS_LIB_SRC" "$root/agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh"
  cp "$PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/plan-status-ownership.md"
  # The real fragment -- Check K reads its four anchor lines from THIS file, never hardcoded.
  cp "$BOUNDED_WAIT_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"

  mkdir -p "$root/agent-system/extensions/fixture/agents"
  cat > "$root/agent-system/extensions/fixture/agents/clean-agent.md" << 'EOF'
---
name: clean-agent
description: fixture
model: sonnet
---
## Body
Run this in the foreground with a bounded timeout and read the log directly. No backgrounding,
no waiting on a harness notification of any kind.
EOF

  cat > "$root/agent-system/extensions/fixture/agents/violating-agent.md" << 'EOF'
---
name: violating-agent
description: fixture
model: sonnet
---
## Body
Run this via `Bash(run_in_background: true)` -- a foreground call can livelock past the tool's
own timeout, and wait for the harness's completion notification before recording the result.
EOF

  # The FORMERLY curated exclusion path, carrying the SAME violating shape. Must now FAIL Check
  # K like any other dispatchable agent contract -- the exclusion that used to cover this path
  # has been discharged (CHECK_K_EXCLUDED_RELATIVE_PATHS is now empty).
  mkdir -p "$root/agent-system/extensions/lean/agents"
  cat > "$root/agent-system/extensions/lean/agents/lean-implementation-agent.md" << 'EOF'
---
name: lean-implementation-agent
description: fixture
model: sonnet
---
## Body
Run this via `Bash(run_in_background: true)` -- a foreground call can livelock past the tool's
own timeout, and wait for the harness's completion notification before recording the result.
EOF

  cat > "$root/agent-system/extensions/fixture/agents/prohibitive-agent.md" << 'EOF'
---
name: prohibitive-agent
description: fixture
model: sonnet
---
## Body
MUST NOT use `Bash(run_in_background: true)` and then wait for the harness's completion
notification before recording the result -- that is exactly the antipattern this contract
forbids.
EOF
}

run_lint() {
  local root="$1"
  REPO_ROOT="$root" bash "$LINT_SRC" --verbose 2>&1
}

ROOT="$(mktemp -d)"
build_fixture_tree "$ROOT"
out="$(run_lint "$ROOT")"
rc=$?
check_k_section=$(echo "$out" | sed -n '/--- Check K:/,/^$/p')

info "=== Check K section ==="
echo "$check_k_section"

# NOTE: the overall exit code of this single combined run DOES propagate the violating-agent
# FAIL (asserted directly below), so rc is expected non-zero here -- unlike the heartbeat
# suite's Case 1, this run deliberately includes a genuine violation.

if echo "$check_k_section" | grep -qF "fixture/agents/clean-agent.md: no unguarded detach-then-await-a-notification pairing found"; then
  pass "(1) clean agent PASSes Check K"
else
  fail "(1) expected a Check K PASS line for clean-agent.md"
fi

if echo "$check_k_section" | grep -qF "fixture/agents/violating-agent.md: pairs a backgrounding instruction"; then
  pass "(2) violating agent FAILs Check K"
else
  fail "(2) expected a Check K FAIL line for violating-agent.md"
fi

if echo "$check_k_section" | grep -qF "lean/agents/lean-implementation-agent.md is a recorded exclusion"; then
  fail "(3a) lean/agents/lean-implementation-agent.md must no longer be a recorded exclusion -- CHECK_K_EXCLUDED_RELATIVE_PATHS is now empty"
else
  pass "(3a) formerly-excluded path carries no recorded-exclusion info line"
fi
if echo "$check_k_section" | grep -qF "lean/agents/lean-implementation-agent.md: pairs a backgrounding instruction"; then
  pass "(3b) formerly-excluded path now FAILs Check K on the violating shape"
else
  fail "(3b) expected a Check K FAIL line for lean/agents/lean-implementation-agent.md -- a stale exclusion would mask this violation"
fi

if echo "$check_k_section" | grep -qF "fixture/agents/prohibitive-agent.md: no unguarded detach-then-await-a-notification pairing found"; then
  pass "(4) prohibitively-quoting agent PASSes Check K"
else
  fail "(4) expected a Check K PASS line for prohibitive-agent.md"
fi

if [ "$rc" -ne 0 ]; then
  pass "(5) overall lint exit code is non-zero (the violating-agent FAIL must propagate)"
else
  fail "(5) expected non-zero overall exit code given a genuine Check K violation"
fi

rm -rf "$ROOT"

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
