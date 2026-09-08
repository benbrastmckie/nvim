#!/usr/bin/env bash
# test-lint-postflight-boundary.sh - Both-polarity fixture test for the section-presence check
# added to scripts/lint/lint-postflight-boundary.sh: a delegating skill missing the
# "## MUST NOT (Postflight Boundary)" heading must fail the lint (exit non-zero); the same skill
# with the section present must pass (exit 0).
#
# This closes a real gap the shared-skill-stage-skeleton report found: 28/91 skills carried the
# exact heading and 32/91 carried any MUST NOT heading, but the lint itself never asserted
# section PRESENCE -- only pattern ABSENCE within an already-found postflight section. A skill
# missing the section entirely produced a silent pass, not a loud failure.
#
# Structural model: test-postflight-marker-schema.sh (mktemp -d workdir, deploy-tree-first /
# source-store-fallback candidate resolution, pass()/fail()/info() helpers, exit 0 all-pass /
# 1 any-fail / 2 environment error).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

LINT_SCRIPT="$(resolve_candidate "lint-postflight-boundary.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-postflight-boundary.sh" \
  "$SCRIPT_DIR/../lint/lint-postflight-boundary.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# A minimal synthetic DELEGATING skill (matches the tightened does_skill_delegate() predicate via
# `subagent_type:`), with no MUST NOT section of any kind.
SYNTHETIC_NO_SECTION="$WORKDIR/skill-synthetic-no-section.md"
cat > "$SYNTHETIC_NO_SECTION" << 'EOF'
---
name: skill-synthetic-no-section
description: Synthetic fixture skill for test-lint-postflight-boundary.sh
---

# Synthetic Skill

## Execution Flow

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "general-research-agent"
```

### Stage 6: Postflight

Read metadata and update status.

## Return Format

Returns a brief text summary.
EOF

# =====================================================================
# Case 1 (negative polarity): delegating skill WITHOUT the section -> lint must fail (non-zero)
# =====================================================================
info "=== negative case: missing section ==="

if bash "$LINT_SCRIPT" "$SYNTHETIC_NO_SECTION" >/tmp/lint-neg-out.$$ 2>&1; then
  fail "lint exited 0 for a delegating skill missing the MUST NOT (Postflight Boundary) section (expected non-zero)"
else
  pass "lint exited non-zero for a delegating skill missing the section"
fi

if grep -q "missing '## MUST NOT (Postflight Boundary)' section" /tmp/lint-neg-out.$$; then
  pass "lint names the specific missing-section violation"
else
  fail "lint output did not name the missing-section violation"
fi
rm -f /tmp/lint-neg-out.$$

# =====================================================================
# Case 2 (positive polarity): same skill WITH the section -> lint must pass (exit 0)
# =====================================================================
info "=== positive case: section present ==="

SYNTHETIC_WITH_SECTION="$WORKDIR/skill-synthetic-with-section.md"
cat > "$SYNTHETIC_WITH_SECTION" << 'EOF'
---
name: skill-synthetic-with-section
description: Synthetic fixture skill for test-lint-postflight-boundary.sh
---

# Synthetic Skill

## Execution Flow

### Stage 5: Invoke Subagent

```
Tool: Agent
Parameters:
  - subagent_type: "general-research-agent"
```

### Stage 6: Postflight

Read metadata and update status.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All work is done by agent

The postflight phase is LIMITED TO:
- Reading agent metadata file

## Return Format

Returns a brief text summary.
EOF

if bash "$LINT_SCRIPT" "$SYNTHETIC_WITH_SECTION" >/tmp/lint-pos-out.$$ 2>&1; then
  pass "lint exited 0 for a delegating skill with the section present"
else
  fail "lint exited non-zero for a delegating skill WITH the section present (unexpected):
$(cat /tmp/lint-pos-out.$$)"
fi
rm -f /tmp/lint-pos-out.$$

# =====================================================================
# Case 3 (control): a non-delegating synthetic skill without the section must NOT be flagged
# (the section-presence check is gated behind does_skill_delegate(), like the pattern checks).
# =====================================================================
info "=== control case: non-delegating skill, no section, must be skipped ==="

SYNTHETIC_NON_DELEGATING="$WORKDIR/skill-synthetic-direct-exec.md"
cat > "$SYNTHETIC_NON_DELEGATING" << 'EOF'
---
name: skill-synthetic-direct-exec
description: Synthetic fixture skill for test-lint-postflight-boundary.sh
---

# Synthetic Skill

Direct execution skill. Executes inline without spawning a subagent.

## Execution Flow

### Stage 1: Do the work directly

No delegation of any kind.
EOF

if bash "$LINT_SCRIPT" "$SYNTHETIC_NON_DELEGATING" >/tmp/lint-ctrl-out.$$ 2>&1; then
  pass "lint exited 0 for a non-delegating skill lacking the section (correctly skipped)"
else
  fail "lint exited non-zero for a non-delegating skill (should be skipped, not flagged):
$(cat /tmp/lint-ctrl-out.$$)"
fi
rm -f /tmp/lint-ctrl-out.$$

# =====================================================================
# Case 4 (real target, fail-open regression guard): skill-orchestrate/SKILL.md -- the four-move
# loop rewrite (see docs/architecture/orchestrate-state-machine.md) abandoned the deleted
# single-task engine's "### Stage N" numbering entirely, which is exactly the shape
# check_postflight_violations()'s ^### Stage [6-9]|^### Stage 1[0-9] heading heuristic used to
# locate a postflight section by. Without a heading that heuristic can still match, the
# section-content scan silently SKIPs (verbose-only, exit 0, no violations found) even though
# has_postflight_boundary_section()'s separate, loud presence check still runs -- this case
# proves BOTH halves fire correctly against the real, live file rather than being fooled by the
# rewrite's new heading shape.
# =====================================================================
info "=== real target: skill-orchestrate/SKILL.md is not silently SKIPped ==="

ORCH_SKILL_CANDIDATES=(
  "$REPO_ROOT/.claude/skills/skill-orchestrate/SKILL.md"
  "$REPO_ROOT/agent-system/extensions/core/skills/skill-orchestrate/SKILL.md"
)
ORCH_SKILL=""
for candidate in "${ORCH_SKILL_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    ORCH_SKILL="$candidate"
    break
  fi
done

if [[ -z "$ORCH_SKILL" ]]; then
  fail "skill-orchestrate/SKILL.md not found at any candidate path -- cannot run the real-target case"
else
  real_out="$(bash "$LINT_SCRIPT" --verbose "$ORCH_SKILL" 2>&1)"
  real_exit=$?
  if [[ "$real_exit" -eq 0 ]]; then
    pass "lint exits 0 for the real skill-orchestrate/SKILL.md"
  else
    fail "lint exited non-zero for the real skill-orchestrate/SKILL.md:
$real_out"
  fi
  if echo "$real_out" | grep -q '\[SKIP\] No postflight section found'; then
    fail "skill-orchestrate/SKILL.md is silently SKIPped (No postflight section found) -- the fail-open gap has regressed"
  else
    pass "skill-orchestrate/SKILL.md is not reported as SKIPped"
  fi
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
