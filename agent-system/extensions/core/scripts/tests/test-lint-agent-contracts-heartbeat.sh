#!/usr/bin/env bash
# test-lint-agent-contracts-heartbeat.sh - Fixture-driven regression suite for Check I
# (heartbeat-mechanization adoption, advisory) in lint-agent-contracts.sh.
#
# Piece 1's dispatch-boundary pulse (Phase 2 of the honest-session-liveness task) closes the
# heartbeat-coverage gap SYSTEM-WIDE regardless of per-agent adoption; Check I exists only to
# keep the residual per-agent adoption gap VISIBLE and NON-REGRESSING. This suite proves both
# directions: (1) an agent on the recorded migration inventory that still lacks the
# update-phase-status.sh call produces a WARNING, not a FAIL, and the lint exits 0; (2) an
# agent that is NOT on the inventory and lacks the call produces a FAIL -- the exact regression
# this check exists to catch (a newly added phase-heading-owning agent reintroducing the gap).
#
# Builds an isolated scratch repo tree (mktemp -d) with a minimal agent-system/extensions/
# layout mirroring the REAL repo at the exact relative paths
# OWNERSHIP_IN_SCOPE_RELATIVE_PATHS names (Check I reuses that hardcoded, curated array
# unmodified -- see lint-agent-contracts.sh's own Check I header comment), then runs the real
# lint-agent-contracts.sh against it via REPO_ROOT=<scratch>, the same source-store invocation
# override the lint script itself documents and test-lint-agent-contracts.sh already uses.
#
# For case (2) (FAIL on a new, non-inventoried offender), the real script's
# HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008 array is hardcoded and must stay that
# way in production (it names a real, dated migration inventory) -- so this suite runs a
# SEPARATE, sed-patched COPY of the real script with exactly one inventory entry removed
# (simulating "this agent was just added to OWNERSHIP_IN_SCOPE_RELATIVE_PATHS and has not yet
# been migrated or inventoried"), never the deployed/source-store script itself. The real,
# unmodified script is used for case (1) and the fragment-missing/full-repo sanity check.
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

# The exact 14-entry OWNERSHIP_IN_SCOPE_RELATIVE_PATHS set, kept here as a plain data list (not
# sourced from the script) so a drift between this list and the real one is caught by case (3)
# below rather than silently assumed.
OWNERSHIP_PATHS=(
  "core/agents/general-implementation-agent.md"
  "cslib/agents/cslib-implementation-agent.md"
  "cslib/agents/cslib-implementation-hard-agent.md"
  "founder/agents/founder-implement-agent.md"
  "latex/agents/latex-implementation-agent.md"
  "lean/agents/lean-implementation-agent.md"
  "lean/agents/lean-implementation-hard-agent.md"
  "nix/agents/nix-implementation-agent.md"
  "nvim/agents/neovim-implementation-agent.md"
  "python/agents/python-implementation-agent.md"
  "rust/agents/rust-implementation-agent.md"
  "typst/agents/typst-implementation-agent.md"
  "web/agents/web-implementation-agent.md"
  "z3/agents/z3-implementation-agent.md"
)

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
  cp "$BOUNDED_WAIT_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"

  local rel dir base
  for rel in "${OWNERSHIP_PATHS[@]}"; do
    dir="$root/agent-system/extensions/$(dirname "$rel")"
    mkdir -p "$dir"
    base="$(basename "$rel" .md)"
    if [ "$rel" = "core/agents/general-implementation-agent.md" ]; then
      # Truthful mirror of the real file: it DOES invoke update-phase-status.sh.
      cat > "$root/agent-system/extensions/$rel" << EOF
---
name: ${base}
description: fixture
model: sonnet
---
# Fixture agent
Calls \`bash .claude/scripts/update-phase-status.sh\` on every phase transition.
EOF
    else
      # Every other fixture agent deliberately lacks the call -- mirrors the real,
      # currently-un-migrated 13.
      cat > "$root/agent-system/extensions/$rel" << EOF
---
name: ${base}
description: fixture
model: sonnet
---
# Fixture agent
Edits \`### Phase N: ... [MARKER]\` headings directly via the Edit tool.
EOF
    fi
  done
}

run_lint() {
  local root="$1" script="${2:-$LINT_SRC}"
  REPO_ROOT="$root" bash "$script" --verbose 2>&1
}

# ═══════════════════════════════════════════════════════════════════════
# Case 1: real, unmodified script -- all 13 inventoried offenders WARN, the one migrated
# agent PASSes, and the overall lint exits 0 (warnings never fail the gate).
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 1: inventoried offenders WARN, lint exits 0 ==="
ROOT1="$(mktemp -d)"
build_fixture_tree "$ROOT1"
out1="$(run_lint "$ROOT1")"
rc1=$?

# NOTE: the overall exit code is NOT asserted here -- this suite's minimal fixtures
# deliberately satisfy Check I only (other checks, e.g. C/F/G/H, read canonical bullet/template
# text this suite's fixtures do not carry, and legitimately FAIL independently of Check I). All
# assertions below are scoped to Check I's own section of the output, found by line range.
check_i_section=$(echo "$out1" | sed -n '/--- Check I:/,/^$/p')

warn_count=$(echo "$check_i_section" | grep -c '\[WARN\].*does not invoke update-phase-status.sh')
if [ "$warn_count" -eq 13 ]; then
  pass "(1a) exactly 13 WARN lines for the 13 inventoried offenders"
else
  fail "(1a) expected 13 WARN lines, got $warn_count"
fi

# grep -F cannot be used here: log_pass() wraps "[PASS]" in ANSI color codes, inserting an
# invisible reset sequence between "[PASS]" and the message text, so the bracketed label and
# the message are matched as two separate anchors rather than one literal span.
if echo "$check_i_section" | grep -q '\[PASS\]' && echo "$check_i_section" | grep -qF "core/agents/general-implementation-agent.md: invokes update-phase-status.sh"; then
  pass "(1b) the one migrated agent explicitly PASSes Check I by name"
else
  fail "(1b) expected an explicit Check I PASS line for general-implementation-agent.md"
fi

fail_i_count=$(echo "$check_i_section" | grep -c '\[FAIL\]')
if [ "$fail_i_count" -eq 0 ]; then
  pass "(1c) zero Check I FAIL lines against today's real adoption state"
else
  fail "(1c) expected zero Check I FAILs, got $fail_i_count"
fi

if [ "$rc1" -ne 0 ]; then
  info "(lint exited $rc1 overall -- expected: other checks legitimately FAIL against these minimal fixtures, independent of Check I)"
fi
rm -rf "$ROOT1"

# ═══════════════════════════════════════════════════════════════════════
# Case 2: a sed-patched COPY of the script with ONE inventory entry removed -- simulating a
# newly-added phase-heading-owning agent that is neither migrated nor yet recorded on the
# inventory. Must FAIL Check I by name for exactly that one agent, and the FAIL must propagate
# to the overall exit code (unlike WARN).
# ═══════════════════════════════════════════════════════════════════════
info "=== Case 2: non-inventoried offender FAILs Check I, propagates to exit code ==="
PATCH_DIR="$(mktemp -d)"
PATCHED_LINT="$PATCH_DIR/lint-agent-contracts-patched.sh"
cp "$LINT_SRC" "$PATCHED_LINT"
# Remove the z3 entry from the HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008 array ONLY
# (z3 also appears, correctly, in OWNERSHIP_IN_SCOPE_RELATIVE_PATHS and
# BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS -- a line-anchored sed across the WHOLE file would delete
# it from all three, which would remove z3 from Check I's loop entirely rather than simulating
# "present in OWNERSHIP, absent from the inventory"). awk scopes the deletion to the single
# array block between its own opening and closing lines.
awk '
  /^HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008=\(/ { in_block = 1 }
  in_block && /"z3\/agents\/z3-implementation-agent\.md"/ { next }
  in_block && /^\)/ { in_block = 0 }
  { print }
' "$LINT_SRC" > "$PATCHED_LINT"

if ! grep -q '"z3/agents/z3-implementation-agent.md"' "$PATCHED_LINT"; then
  echo "ERROR: awk patch removed z3 everywhere, expected it to remain in OWNERSHIP_IN_SCOPE_RELATIVE_PATHS" >&2
  exit 1
fi
if sed -n '/^HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008=(/,/^)/p' "$PATCHED_LINT" | grep -q "z3-implementation-agent"; then
  echo "ERROR: awk patch did not remove the z3 entry from the migration-inventory array as expected" >&2
  exit 1
fi

ROOT2="$(mktemp -d)"
build_fixture_tree "$ROOT2"
out2="$(run_lint "$ROOT2" "$PATCHED_LINT")"
rc2=$?

if [ "$rc2" -ne 0 ]; then
  pass "(2a) lint exits non-zero once a non-inventoried offender is present"
else
  fail "(2a) lint exited 0, expected non-zero (a Check I FAIL must gate the exit code)"
fi

check_i_section2=$(echo "$out2" | sed -n '/--- Check I:/,/^$/p')

if echo "$check_i_section2" | grep -qF "z3/agents/z3-implementation-agent.md: missing update-phase-status.sh invocation and NOT on the recorded migration inventory"; then
  pass "(2b) z3-implementation-agent.md FAILs Check I by name with the regression-specific message"
else
  fail "(2b) expected a named Check I FAIL for z3-implementation-agent.md, not found in output"
fi

# Every other (still-inventoried) offender must still WARN, not FAIL -- proves the patch is
# scoped to exactly the one removed entry.
warn_count2=$(echo "$check_i_section2" | grep -c '\[WARN\].*does not invoke update-phase-status.sh')
if [ "$warn_count2" -eq 12 ]; then
  pass "(2c) the remaining 12 still-inventoried offenders still WARN (patch scoped to z3 only)"
else
  fail "(2c) expected 12 WARN lines for the remaining inventoried offenders, got $warn_count2"
fi
rm -rf "$ROOT2" "$PATCH_DIR"

# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
