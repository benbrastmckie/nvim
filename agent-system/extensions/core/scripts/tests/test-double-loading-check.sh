#!/usr/bin/env bash
# test-double-loading-check.sh - Fixture-driven regression suite for the Double-Loading Check
# section of validate-context-budgets.sh: the mechanical three-bucket redundancy predicate
# (redundant / legitimate-dual / unclassifiable-command) that replaced the prior shape-only
# "both agents[] and commands[] hooks present" WARNING.
#
# Drives the DEPLOYED script as a real subprocess (`.claude/scripts/validate-context-budgets.sh
# --index <fixture>`), never the source-store copy: deploy-root-guard.sh hard-exits when a
# script's own SCRIPT_DIR is not under a `.claude`/`.opencode` deploy tree, so the source-store
# sibling cannot be executed directly. Route derivation inside the script still reads the real
# deployed manifest.json / skill SKILL.md files (via REPO_ROOT, auto-derived from the deployed
# script's own location) for every case except the degraded-derivation case below, which
# overrides one route source via an env var the script exposes specifically for this purpose
# (VALIDATE_BUDGETS_MANIFEST_OVERRIDE) rather than mutating the real deployed manifest.json.
#
# Five cases, matching the plan's Scope Hypothesis for this phase:
#   1. Positive     - the check still fires on the most common redundant shape.
#   2. Discrimination - a direct command does not trip the check (proves it isn't trivially firing).
#   3. Orchestrate  - /orchestrate's union reach never subsumes an entry's agents[].
#   4. Unclassifiable - an unroutable (e.g. extension) command lands in its own named bucket,
#                        not silently folded into "legitimate", and does not affect the exit code.
#   5. Degraded route derivation - an unreadable route source produces the loud
#      [DEGRADED ROUTE DERIVATION] banner and treats the affected command as unclassifiable,
#      never as direct and never as a silent no-op.
#
# Inversion check (this suite's own self-test, run last): temporarily inverts the redundancy
# predicate's sense (NOT instead of the true subset test) via a scratch-patched copy of the
# deployed script and re-runs cases 1 and 2, asserting they now FAIL -- proving the two positive
# assertions above are live and not vacuously true. This never touches the real deployed script;
# it operates on a throwaway copy in the test's own workdir.
#
# Structural model: test-index-entries-schema.sh / test-validate-no-task-references.sh
# (pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail).
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (deployed script not found -- this suite categorically cannot run against the
# source-store copy, see deploy-root-guard.sh above).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. Resolve via
# the git worktree root first (depth-independent); only fall back to this suite's original
# dual-mode manifest.json-probe detection (same technique as run-all.sh: present 3 levels up
# means source-store, absent means deployed) when SCRIPT_DIR is not inside a git work tree.
# DEPLOYED_SCRIPT always targets `.claude/scripts/...` off the resolved REPO_ROOT in either
# branch -- the object under test is always the .claude deploy tree, never .opencode.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  CANDIDATE_EXT_ROOT="$(cd "$SCRIPT_DIR/../../.." 2>/dev/null && pwd || true)"
  if [ -n "$CANDIDATE_EXT_ROOT" ] && [ -f "$CANDIDATE_EXT_ROOT/core/manifest.json" ]; then
    REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
  else
    REPO_ROOT="$CANDIDATE_EXT_ROOT"
  fi
fi

DEPLOYED_SCRIPT="$REPO_ROOT/.claude/scripts/validate-context-budgets.sh"
if [[ ! -f "$DEPLOYED_SCRIPT" ]]; then
  echo "ERROR: deployed validate-context-budgets.sh not found at $DEPLOYED_SCRIPT" >&2
  echo "This suite must run against the DEPLOYED copy -- deploy-root-guard.sh blocks the" >&2
  echo "source-store sibling from executing directly. Run deploy-headless.sh first." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixture JSON and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0


common_test_workdir_init

# ── Case 1: Positive (the check still fires) ─────────────────────────────────────────────────
FIXTURE_POSITIVE="$WORKDIR/fixture-positive.json"
cat > "$FIXTURE_POSITIVE" << 'EOF'
{"entries": [
  {"path": "fixture/positive.md", "load_when": {"agents": ["meta-builder-agent"], "commands": ["/meta"], "task_types": []}, "line_count": 10}
]}
EOF

OUT="$(bash "$DEPLOYED_SCRIPT" --index "$FIXTURE_POSITIVE" 2>&1)"
EXIT_CODE=$?
if echo "$OUT" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 1 -- VIOLATION"; then
  common_test_pass "Case 1 (positive): redundant count is 1"
else
  common_test_fail "Case 1 (positive): expected redundant count of 1 in output"
fi
if echo "$OUT" | grep -qF "fixture/positive.md"; then
  common_test_pass "Case 1 (positive): offending path named in output"
else
  common_test_fail "Case 1 (positive): offending path not named in output"
fi
if [[ "$EXIT_CODE" -ne 0 ]]; then
  common_test_pass "Case 1 (positive): exit code is non-zero ($EXIT_CODE)"
else
  common_test_fail "Case 1 (positive): expected non-zero exit code, got 0"
fi

# ── Case 2: Discrimination (a direct command does not trip the check) ───────────────────────
FIXTURE_DISCRIMINATION="$WORKDIR/fixture-discrimination.json"
cat > "$FIXTURE_DISCRIMINATION" << 'EOF'
{"entries": [
  {"path": "fixture/discrimination.md", "load_when": {"agents": ["meta-builder-agent"], "commands": ["/review"], "task_types": []}, "line_count": 10}
]}
EOF

OUT="$(bash "$DEPLOYED_SCRIPT" --index "$FIXTURE_DISCRIMINATION" 2>&1)"
EXIT_CODE=$?
if echo "$OUT" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 0 -- OK"; then
  common_test_pass "Case 2 (discrimination): redundant count is 0"
else
  common_test_fail "Case 2 (discrimination): expected redundant count of 0 in output"
fi
if [[ "$EXIT_CODE" -eq 0 ]]; then
  common_test_pass "Case 2 (discrimination): exit code is 0 (not affected)"
else
  common_test_fail "Case 2 (discrimination): expected exit code 0, got $EXIT_CODE"
fi

# ── Case 3: /orchestrate never subsumes an entry's agents[] ─────────────────────────────────
FIXTURE_ORCHESTRATE="$WORKDIR/fixture-orchestrate.json"
cat > "$FIXTURE_ORCHESTRATE" << 'EOF'
{"entries": [
  {"path": "fixture/orchestrate.md", "load_when": {"agents": ["meta-builder-agent"], "commands": ["/meta", "/orchestrate"], "task_types": []}, "line_count": 10}
]}
EOF

OUT="$(bash "$DEPLOYED_SCRIPT" --index "$FIXTURE_ORCHESTRATE" --verbose 2>&1)"
EXIT_CODE=$?
if echo "$OUT" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 0 -- OK"; then
  common_test_pass "Case 3 (orchestrate): redundant count is 0"
else
  common_test_fail "Case 3 (orchestrate): expected redundant count of 0 in output"
fi
if echo "$OUT" | grep -q "Legitimately dual-addressed (informational, not a violation): 1" \
  && echo "$OUT" | grep -qF "fixture/orchestrate.md"; then
  common_test_pass "Case 3 (orchestrate): entry lands in legitimate-dual bucket"
else
  common_test_fail "Case 3 (orchestrate): expected entry in legitimate-dual bucket"
fi
if [[ "$EXIT_CODE" -eq 0 ]]; then
  common_test_pass "Case 3 (orchestrate): exit code is 0 (not affected)"
else
  common_test_fail "Case 3 (orchestrate): expected exit code 0, got $EXIT_CODE"
fi

# ── Case 4: Unclassifiable-command bucket (extension command x extension agent) ─────────────
FIXTURE_UNCLASSIFIABLE="$WORKDIR/fixture-unclassifiable.json"
cat > "$FIXTURE_UNCLASSIFIABLE" << 'EOF'
{"entries": [
  {"path": "fixture/unclassifiable.md", "load_when": {"agents": ["grant-agent"], "commands": ["/grant"], "task_types": []}, "line_count": 10}
]}
EOF

OUT="$(bash "$DEPLOYED_SCRIPT" --index "$FIXTURE_UNCLASSIFIABLE" --verbose 2>&1)"
EXIT_CODE=$?
if echo "$OUT" | grep -q "Unclassifiable-command (informational; route not mechanically derivable, e.g. extension commands): 1" \
  && echo "$OUT" | grep -qF "fixture/unclassifiable.md"; then
  common_test_pass "Case 4 (unclassifiable): entry lands in unclassifiable-command bucket"
else
  common_test_fail "Case 4 (unclassifiable): expected entry in unclassifiable-command bucket"
fi
if echo "$OUT" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 0 -- OK"; then
  common_test_pass "Case 4 (unclassifiable): redundant count is 0"
else
  common_test_fail "Case 4 (unclassifiable): expected redundant count of 0 in output"
fi
if [[ "$EXIT_CODE" -eq 0 ]]; then
  common_test_pass "Case 4 (unclassifiable): exit code is 0 (informational only, not affected)"
else
  common_test_fail "Case 4 (unclassifiable): expected exit code 0, got $EXIT_CODE"
fi

# ── Case 5: Degraded route derivation ─────────────────────────────────────────────────────────
FIXTURE_DEGRADED="$WORKDIR/fixture-degraded.json"
cat > "$FIXTURE_DEGRADED" << 'EOF'
{"entries": [
  {"path": "fixture/degraded.md", "load_when": {"agents": ["general-research-agent"], "commands": ["/research"], "task_types": []}, "line_count": 10}
]}
EOF

OUT="$(VALIDATE_BUDGETS_MANIFEST_OVERRIDE="$WORKDIR/does-not-exist-manifest.json" \
  bash "$DEPLOYED_SCRIPT" --index "$FIXTURE_DEGRADED" --verbose 2>&1)"
EXIT_CODE=$?
if echo "$OUT" | grep -q '\[DEGRADED ROUTE DERIVATION\]'; then
  common_test_pass "Case 5 (degraded): [DEGRADED ROUTE DERIVATION] banner appears"
else
  common_test_fail "Case 5 (degraded): expected [DEGRADED ROUTE DERIVATION] banner in output"
fi
if echo "$OUT" | grep -q "Unclassifiable-command (informational; route not mechanically derivable, e.g. extension commands): 1" \
  && echo "$OUT" | grep -qF "fixture/degraded.md"; then
  common_test_pass "Case 5 (degraded): affected command treated as unclassifiable"
else
  common_test_fail "Case 5 (degraded): expected affected command in unclassifiable-command bucket"
fi
if echo "$OUT" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 0 -- OK"; then
  common_test_pass "Case 5 (degraded): affected command never silently treated as redundant (vacuous-subset trap)"
else
  common_test_fail "Case 5 (degraded): expected redundant count of 0 -- degraded route must never look vacuously redundant"
fi
common_test_info "Case 5 (degraded) exit code observed: $EXIT_CODE (WARNINGS-only path; degraded derivation is a warning, not a violation)"

# ── Inversion check: prove cases 1 and 2 are LIVE assertions, not vacuously true ─────────────
# Copies the deployed script into a fabricated .claude/scripts/ tree inside the workdir (NOT a
# bare copy dropped in $WORKDIR directly): deploy-root-guard.sh hard-exits unless the running
# script's own parent directory is literally named `.claude` or `.opencode`, and
# common_repo_root() derives REPO_ROOT from the script's own location two levels up -- both of
# which require the real deploy-tree shape to be present, including the sourced lib/common.sh
# and deploy-root-guard.sh siblings. Route derivation is repointed at the REAL deployed
# manifest.json / skill files via the VALIDATE_BUDGETS_*_OVERRIDE env vars (the same override
# mechanism Case 5 uses) so this check isolates the predicate inversion alone, not a side effect
# of the fabricated REPO_ROOT lacking real route sources.
INVERTED_ROOT="$WORKDIR/fake-deploy"
INVERTED_SCRIPTS_DIR="$INVERTED_ROOT/.claude/scripts"
mkdir -p "$INVERTED_SCRIPTS_DIR/lib"
cp "$DEPLOYED_SCRIPT" "$INVERTED_SCRIPTS_DIR/validate-context-budgets.sh"
cp "$REPO_ROOT/.claude/scripts/lib/common.sh" "$INVERTED_SCRIPTS_DIR/lib/common.sh"
cp "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" "$INVERTED_SCRIPTS_DIR/deploy-root-guard.sh"
INVERTED_SCRIPT="$INVERTED_SCRIPTS_DIR/validate-context-budgets.sh"

# The predicate's defining line is `is_redundant: ($cmds | all(. as $c | ...))`. Wrap the `all(...)`
# result in `| not` to flip every entry's redundancy classification.
if grep -q 'is_redundant: (\$cmds | all(\. as \$c |' "$INVERTED_SCRIPT"; then
  # Insert a trailing `| not` immediately after the `all(...)` block's matching close-paren by
  # targeting the known multi-line block boundary: the line containing `end\n          )),` that
  # closes the is_redundant all(...) call. This is fragile by nature (it edits generated-copy
  # script text), which is exactly why this check is self-verifying: if the sed find-pattern no
  # longer matches (e.g. the source changed shape), the case below fails loudly instead of
  # silently no-op'ing the inversion.
  python3 - "$INVERTED_SCRIPT" << 'PYEOF'
import sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()
needle = "is_redundant: ($cmds | all(. as $c |"
idx = content.find(needle)
if idx == -1:
    print("NEEDLE_NOT_FOUND")
    sys.exit(1)
# Find the matching "end\n            )),\n        unclassifiable_tokens" close after idx.
close_needle = "            end\n          )),"
close_idx = content.find(close_needle, idx)
if close_idx == -1:
    print("CLOSE_NOT_FOUND")
    sys.exit(1)
insert_at = close_idx + len("            end\n          )")
inverted = content[:insert_at] + " | not" + content[insert_at:]
with open(path, "w") as f:
    f.write(inverted)
print("OK")
PYEOF
  PY_STATUS=$?
else
  PY_STATUS=99
fi

if [[ "$PY_STATUS" -ne 0 ]]; then
  common_test_fail "Inversion check: could not locate/patch the is_redundant predicate in a scratch copy (needle drift -- update this suite's patch target)"
else
  chmod +x "$INVERTED_SCRIPT"
  REAL_MANIFEST="$REPO_ROOT/.claude/extensions/core/manifest.json"
  REAL_META_SKILL="$REPO_ROOT/.claude/skills/skill-meta/SKILL.md"
  REAL_SPAWN_SKILL="$REPO_ROOT/.claude/skills/skill-spawn/SKILL.md"
  REAL_REVISE_SKILL="$REPO_ROOT/.claude/skills/skill-reviser/SKILL.md"
  INV_OUT_1="$(VALIDATE_BUDGETS_MANIFEST_OVERRIDE="$REAL_MANIFEST" \
    VALIDATE_BUDGETS_META_SKILL_OVERRIDE="$REAL_META_SKILL" \
    VALIDATE_BUDGETS_SPAWN_SKILL_OVERRIDE="$REAL_SPAWN_SKILL" \
    VALIDATE_BUDGETS_REVISE_SKILL_OVERRIDE="$REAL_REVISE_SKILL" \
    bash "$INVERTED_SCRIPT" --index "$FIXTURE_POSITIVE" 2>&1)"
  INV_EXIT_1=$?
  if echo "$INV_OUT_1" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 0 -- OK" && [[ "$INV_EXIT_1" -eq 0 ]]; then
    common_test_pass "Inversion check: Case 1 (positive) FAILS to detect redundancy under the inverted predicate, as expected"
  else
    common_test_fail "Inversion check: Case 1 (positive) still reports redundant under inversion -- the assertion may not be live"
  fi

  INV_OUT_2="$(VALIDATE_BUDGETS_MANIFEST_OVERRIDE="$REAL_MANIFEST" \
    VALIDATE_BUDGETS_META_SKILL_OVERRIDE="$REAL_META_SKILL" \
    VALIDATE_BUDGETS_SPAWN_SKILL_OVERRIDE="$REAL_SPAWN_SKILL" \
    VALIDATE_BUDGETS_REVISE_SKILL_OVERRIDE="$REAL_REVISE_SKILL" \
    bash "$INVERTED_SCRIPT" --index "$FIXTURE_DISCRIMINATION" 2>&1)"
  INV_EXIT_2=$?
  if echo "$INV_OUT_2" | grep -q "Redundant (commands\[\] fully subsumed by agents\[\]): 1 -- VIOLATION" && [[ "$INV_EXIT_2" -ne 0 ]]; then
    common_test_pass "Inversion check: Case 2 (discrimination) now FALSELY flags a direct command as redundant under inversion, as expected"
  else
    common_test_fail "Inversion check: Case 2 (discrimination) did not flip under inversion -- the assertion may not be live"
  fi
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
