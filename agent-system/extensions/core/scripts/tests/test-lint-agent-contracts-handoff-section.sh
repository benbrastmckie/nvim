#!/usr/bin/env bash
# test-lint-agent-contracts-handoff-section.sh - Fixture-driven regression suite for Check J
# (section-scoped handoff `artifacts` requirement presence) in lint-agent-contracts.sh.
#
# Check F (the pre-existing whole-file check) greps the ENTIRE file for an "artifacts"
# occurrence, so it cannot distinguish a correct `.return-meta.json` Stage-7-style section from
# a broken `.orchestrator-handoff.json` handoff-writing section -- a file can pass Check F while
# its separate handoff-writing section omits `artifacts` entirely. This is exactly the measured
# incident Check J exists to catch: lean-implementation-hard-agent.md passed Check F (its own
# .return-meta.json section is correct) while its Stage 5 .orchestrator-handoff.json section had
# no `artifacts` key at all. See lint-agent-contracts.sh's own Check J header comment for the
# full section-bounding and detection-predicate rationale.
#
# Six fixture cases, each its own minimal dispatchable-agent file in an isolated scratch repo
# tree (mktemp -d), run against the REAL, unmodified lint-agent-contracts.sh via
# REPO_ROOT=<scratch> (the same source-store invocation override the script documents and
# test-lint-agent-contracts-heartbeat.sh already uses):
#   1. prose-form writer                              -> PASS
#   2. JSON-form writer                                -> PASS
#   3. writer whose handoff section omits `artifacts`  -> FAIL
#   4. correct .return-meta.json section, broken
#      handoff section (the exact Check F blind spot)  -> FAIL
#   5. a "never write one" research-agent contract     -> skipped (neither PASS nor FAIL)
#   6. a writer with an unrecognizable heading          -> FAIL (heading drift, never silent)
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
  mkdir -p "$root/agent-system/extensions/fixture/agents"
  cp "$FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/no-task-references-bullet.md"
  cp "$ARTIFACTS_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md"
  cp "$STATUS_LIB_SRC" "$root/agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh"
  cp "$PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/contracts/plan-status-ownership.md"
  cp "$BOUNDED_WAIT_FRAGMENT_SRC" "$root/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"

  local fx="$root/agent-system/extensions/fixture/agents"

  # Case 1: prose-form writer -> PASS
  cat > "$fx/case1-prose-agent.md" << 'EOF'
---
name: case1-prose-agent
description: fixture
model: sonnet
---
# Fixture agent

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

Write this file always. `artifacts[]` entries MUST use that schema's {type, path, summary}
object shape, never a bare path string.

### Stage 6: Create Implementation Summary

Write the summary file.
EOF

  # Case 2: JSON-form writer -> PASS
  cat > "$fx/case2-json-agent.md" << 'EOF'
---
name: case2-json-agent
description: fixture
model: sonnet
---
# Fixture agent

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

Write this file always:

```json
{
  "status": "implemented",
  "summary": "...",
  "artifacts": [{"path": "...", "type": "summary", "summary": "..."}]
}
```

### Stage 6: Create Implementation Summary

Write the summary file.
EOF

  # Case 3: writer whose handoff section omits artifacts entirely -> FAIL
  cat > "$fx/case3-missing-agent.md" << 'EOF'
---
name: case3-missing-agent
description: fixture
model: sonnet
---
# Fixture agent

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

Write this file always with status, summary, phases_completed, phases_total, blockers.

### Stage 6: Create Implementation Summary

Write the summary file.
EOF

  # Case 4: correct .return-meta.json section but broken handoff section -- the exact Check F
  # blind spot. Check F would PASS this file (object-shaped artifacts present somewhere), but
  # Check J must FAIL it because the bounded handoff section itself has no artifacts mention.
  cat > "$fx/case4-blindspot-agent.md" << 'EOF'
---
name: case4-blindspot-agent
description: fixture
model: sonnet
---
# Fixture agent

### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

Write this file always with status, summary, phases_completed, phases_total, blockers.

### Stage 7: Write Metadata File

Write to `.return-meta.json`:

```json
{
  "status": "implemented",
  "artifacts": [{"type": "summary", "path": "...", "summary": "..."}]
}
```
EOF

  # Case 5: a "never write one" research-agent contract -> skipped, never failed.
  cat > "$fx/case5-researchagent-agent.md" << 'EOF'
---
name: case5-researchagent-agent
description: fixture
model: sonnet
---
# Fixture agent

### `.orchestrator-handoff.json` — research agents never write one

Research agents are explicitly prohibited from writing this file in any mode.
EOF

  # Case 6: a writer with an unrecognizable heading -> FAIL loudly (heading drift).
  cat > "$fx/case6-headingdrift-agent.md" << 'EOF'
---
name: case6-headingdrift-agent
description: fixture
model: sonnet
---
# Fixture agent

## Final Steps

Write the orchestrator handoff file .orchestrator-handoff.json with status and artifacts
before returning.
EOF
}

run_lint() {
  local root="$1"
  REPO_ROOT="$root" bash "$LINT_SRC" --verbose 2>&1
}

info "=== Building fixture tree and running real, unmodified lint-agent-contracts.sh ==="
ROOT="$(mktemp -d)"
build_fixture_tree "$ROOT"
out="$(run_lint "$ROOT")"
rc=$?

# NOTE: the overall exit code is NOT asserted as a single pass/fail -- these minimal fixtures
# deliberately satisfy Check J's six cases only; other checks (A/B/C/E/F/G/H/I) legitimately
# FAIL or WARN independently against fixtures this narrow. All assertions below are scoped to
# Check J's own section of the output, found by line range (mirrors
# test-lint-agent-contracts-heartbeat.sh's own Check-I-scoping precedent).
check_j_section="$(echo "$out" | sed -n '/--- Check J:/,/^========/p')"

if echo "$check_j_section" | grep -qF "case1-prose-agent.md: handoff-writing section states the artifacts requirement"; then
  pass "(1) prose-form writer PASSes Check J"
else
  fail "(1) expected a Check J PASS for case1-prose-agent.md"
fi

if echo "$check_j_section" | grep -qF "case2-json-agent.md: handoff-writing section states the artifacts requirement"; then
  pass "(2) JSON-form writer PASSes Check J"
else
  fail "(2) expected a Check J PASS for case2-json-agent.md"
fi

if echo "$check_j_section" | grep -qF "case3-missing-agent.md: handoff-writing section" \
   && echo "$check_j_section" | grep -F "case3-missing-agent.md" | grep -q '\[FAIL\]'; then
  pass "(3) writer whose handoff section omits artifacts FAILs Check J"
else
  fail "(3) expected a Check J FAIL for case3-missing-agent.md"
fi

if echo "$check_j_section" | grep -qF "case4-blindspot-agent.md: handoff-writing section" \
   && echo "$check_j_section" | grep -F "case4-blindspot-agent.md" | grep -q '\[FAIL\]'; then
  pass "(4) correct .return-meta.json section with a broken handoff section still FAILs Check J (Check F blind spot closed)"
else
  fail "(4) expected a Check J FAIL for case4-blindspot-agent.md despite its correct Stage 7 section"
fi

# Case 5's filename legitimately appears in a "Checking ..." INFO line and in the dedicated
# skip-notice INFO line (both unconditional for any candidate under --verbose); the assertion is
# that NEITHER a [PASS] NOR a [FAIL] line names this file -- it must be a decided skip, never a
# scored outcome in either direction.
case5_lines="$(echo "$check_j_section" | grep -F "case5-researchagent-agent.md")"
if echo "$case5_lines" | grep -qF "is a 'never write one' non-writer contract -- skipped" \
   && ! echo "$case5_lines" | grep -qE '\[PASS\]|\[FAIL\]'; then
  pass "(5) 'never write one' research-agent contract is a decided skip -- no Check J PASS/FAIL line names it"
else
  fail "(5) expected case5-researchagent-agent.md to produce only the non-writer skip INFO line, with no [PASS]/[FAIL] line"
fi

if echo "$check_j_section" | grep -qF "case6-headingdrift-agent.md" \
   && echo "$check_j_section" | grep -F "case6-headingdrift-agent.md" | grep -q '\[FAIL\]' \
   && echo "$check_j_section" | grep -F "case6-headingdrift-agent.md" | grep -qF "heading drift"; then
  pass "(6) writer with an unrecognizable heading FAILs Check J loudly, named as heading drift"
else
  fail "(6) expected a named heading-drift Check J FAIL for case6-headingdrift-agent.md"
fi

rm -rf "$ROOT"

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
