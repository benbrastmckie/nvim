#!/usr/bin/env bash
# test-manage-topics-create-order.sh - Fixture-driven regression suite for /task Create Mode's
# topic-assignment order (commands/task.md steps 4.5/6). Proves the reordering fix: Create Mode's
# manage-topics.sh set call now runs AFTER the project entry exists in active_projects (not
# before, which always exited 4), and confirms the source doc's text order reflects the fix so
# the defect cannot silently regress.
#
# Structural model: build_fixture_repo() (test-skill-base-lifecycle.sh's canonical shape) -- a
# mktemp -d root with a real .claude/scripts/{,lib/} tree copied in and a synthetic specs/
# state.json underneath -- redirects manage-topics.sh's own PROJECT_ROOT resolution
# (common_repo_root, relative to its own SCRIPT_DIR) at the fixture, never at the live repo.
#
# Follows the core shell-test convention: pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, mktemp -d workdir with a trap EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required deployed script was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# TREE_ROOT resolution must work from both invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/) -- both sit at the same relative depth below their own tree root
# (scripts/tests/ -> two levels up -> the tree root), so a single fixed-depth guess works for
# both without needing git worktree resolution.
TREE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPLOY_SCRIPTS_SRC="$TREE_ROOT/scripts"
TASK_MD="$TREE_ROOT/commands/task.md"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -d "$DEPLOY_SCRIPTS_SRC" ]]; then
  echo "ERROR: scripts tree not found at $DEPLOY_SCRIPTS_SRC" >&2
  exit 2
fi
for req in manage-topics.sh state-write.sh task-lock.sh deploy-root-guard.sh; do
  if [[ ! -f "$DEPLOY_SCRIPTS_SRC/$req" ]]; then
    echo "ERROR: required script missing: $DEPLOY_SCRIPTS_SRC/$req" >&2
    exit 2
  fi
done
if [[ ! -f "$TASK_MD" ]]; then
  echo "ERROR: task.md not found at $TASK_MD" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── build_fixture_repo: an isolated repo shape under $1, real deployed scripts copied in ──────
build_fixture_repo() {
  local root="$1"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs"
  for f in manage-topics.sh state-write.sh task-lock.sh deploy-root-guard.sh; do
    cp "$DEPLOY_SCRIPTS_SRC/$f" "$root/.claude/scripts/$f"
    chmod +x "$root/.claude/scripts/$f"
  done
  cp "$DEPLOY_SCRIPTS_SRC"/lib/*.sh "$root/.claude/scripts/lib/" 2>/dev/null || true
}

manage_topics() {
  # Invoke the fixture's own manage-topics.sh (its PROJECT_ROOT resolves relative to its own
  # copied SCRIPT_DIR, i.e. into the fixture root -- never the live repo).
  local root="$1"; shift
  bash "$root/.claude/scripts/manage-topics.sh" "$@"
}

# =====================================================================
# Case 1: zero existing topics. Simulate Create Mode's CORRECTED order: state write (project
# entry #1 already present with no topic), then manage-topics.sh set. Assert exit 0, the
# project's topic set, and active_topics contains it.
# =====================================================================
info "=== Case 1: zero existing topics ==="
FIXTURE1="$WORKDIR/case1"
build_fixture_repo "$FIXTURE1"
cat > "$FIXTURE1/specs/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_project",
      "status": "not_started",
      "task_type": "general",
      "description": "Fixture project entry with no topic yet"
    }
  ],
  "active_topics": []
}
EOF

if manage_topics "$FIXTURE1" set 1 "agent-system" >/tmp/mtco-case1.$$ 2>&1; then
  pass "Case 1: manage-topics.sh set exits 0 when called after the project entry exists"
else
  fail "Case 1: manage-topics.sh set exited non-zero -- $(cat /tmp/mtco-case1.$$)"
fi
rm -f /tmp/mtco-case1.$$

case1_topic=$(jq -r '.active_projects[] | select(.project_number == 1) | .topic // empty' "$FIXTURE1/specs/state.json")
if [[ "$case1_topic" == "agent-system" ]]; then
  pass "Case 1: project entry #1's topic field is set to 'agent-system'"
else
  fail "Case 1: expected project entry #1's topic to be 'agent-system', got '$case1_topic'"
fi

case1_active=$(jq -r '.active_topics | index("agent-system") != null' "$FIXTURE1/specs/state.json")
if [[ "$case1_active" == "true" ]]; then
  pass "Case 1: active_topics contains 'agent-system'"
else
  fail "Case 1: expected active_topics to contain 'agent-system'"
fi

# =====================================================================
# Case 2: existing topics (idempotent append, no duplicate). Seed active_topics with two
# entries, run the same corrected-order sequence assigning an ALREADY-PRESENT topic to a second
# project entry, and assert active_topics' length is unchanged (no duplicate entry).
# =====================================================================
info "=== Case 2: existing topics (idempotent) ==="
FIXTURE2="$WORKDIR/case2"
build_fixture_repo "$FIXTURE2"
cat > "$FIXTURE2/specs/state.json" << 'EOF'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "existing_project",
      "status": "not_started",
      "task_type": "general",
      "topic": "neovim"
    },
    {
      "project_number": 2,
      "project_name": "fixture_project_two",
      "status": "not_started",
      "task_type": "general",
      "description": "Fixture project entry with no topic yet"
    }
  ],
  "active_topics": ["neovim", "agent-system"]
}
EOF

before_len=$(jq -r '.active_topics | length' "$FIXTURE2/specs/state.json")

if manage_topics "$FIXTURE2" set 2 "agent-system" >/tmp/mtco-case2.$$ 2>&1; then
  pass "Case 2: manage-topics.sh set exits 0 against a state with existing topics"
else
  fail "Case 2: manage-topics.sh set exited non-zero -- $(cat /tmp/mtco-case2.$$)"
fi
rm -f /tmp/mtco-case2.$$

case2_topic=$(jq -r '.active_projects[] | select(.project_number == 2) | .topic // empty' "$FIXTURE2/specs/state.json")
if [[ "$case2_topic" == "agent-system" ]]; then
  pass "Case 2: project entry #2's topic field is set to 'agent-system'"
else
  fail "Case 2: expected project entry #2's topic to be 'agent-system', got '$case2_topic'"
fi

after_len=$(jq -r '.active_topics | length' "$FIXTURE2/specs/state.json")
if [[ "$after_len" == "$before_len" ]]; then
  pass "Case 2: active_topics length unchanged ($before_len -> $after_len; idempotent, no duplicate)"
else
  fail "Case 2: expected active_topics length to stay $before_len, got $after_len"
fi

# =====================================================================
# Case 3 (regression guard): call manage-topics.sh set against a project number absent from
# active_projects. Pins the exit-4 contract this suite must NOT change -- this is the original
# defect's exact failure branch (Create Mode's old, pre-fix order called set BEFORE the project
# entry existed, which always hit this exact branch).
# =====================================================================
info "=== Case 3: exit-4 contract guard (project entry not found) ==="
FIXTURE3="$WORKDIR/case3"
build_fixture_repo "$FIXTURE3"
cat > "$FIXTURE3/specs/state.json" << 'EOF'
{
  "next_project_number": 1,
  "active_projects": [],
  "active_topics": []
}
EOF

manage_topics "$FIXTURE3" set 999 "agent-system" >/tmp/mtco-case3.$$ 2>&1
case3_exit=$?
if [[ "$case3_exit" -eq 4 ]]; then
  pass "Case 3: manage-topics.sh set against an absent project entry exits 4 (not-found contract preserved)"
else
  fail "Case 3: expected exit 4 for an absent project entry, got exit $case3_exit -- $(cat /tmp/mtco-case3.$$)"
fi
rm -f /tmp/mtco-case3.$$

# =====================================================================
# Case 4 (text-order assertion): commands/task.md's Create Mode text must place its
# manage-topics.sh set call AFTER state-write.sh's Step 6 invocation, not before (step 4.5). A
# future re-introduction of the original defect (set called before the project entry is written)
# fails this suite, not just at runtime.
# =====================================================================
info "=== Case 4: task.md text-order assertion ==="

step45_line=$(grep -n '^4\.5\. \*\*Assign topic\*\*' "$TASK_MD" | head -1 | cut -d: -f1)
step6_statewrite_line=$(awk '/^6\. \*\*Update state.json\*\*/{f=1} f && /state-write\.sh \\\\?$/{print NR; exit}' "$TASK_MD")
create_mode_set_line=$(awk -v start="$step6_statewrite_line" 'NR > start && /manage-topics\.sh set "\$next_num" "\$topic"/{print NR; exit}' "$TASK_MD")
# Only counts an actual invocation of manage-topics.sh set (a line beginning with "bash" or
# "if ! bash", after leading whitespace) -- NOT a prose mention such as the step 4.5 note
# explaining that the call happens later.
step45_set_line=$(awk -v start="$step45_line" -v stop="$step6_statewrite_line" \
  'NR > start && NR < stop && /^[[:space:]]*(if ! )?bash .*manage-topics\.sh set/{print NR; exit}' "$TASK_MD")

if [[ -z "$step45_line" || -z "$step6_statewrite_line" ]]; then
  fail "Case 4: could not locate step 4.5 or step 6's state-write.sh anchor in $TASK_MD"
else
  if [[ -n "$step45_set_line" ]]; then
    fail "Case 4: step 4.5 still contains a manage-topics.sh set call (line $step45_set_line) -- the original defect has regressed"
  else
    pass "Case 4: step 4.5 no longer contains a manage-topics.sh set call"
  fi

  if [[ -n "$create_mode_set_line" && "$create_mode_set_line" -gt "$step6_statewrite_line" ]]; then
    pass "Case 4: Create Mode's manage-topics.sh set call (line $create_mode_set_line) is after step 6's state-write.sh (line $step6_statewrite_line)"
  else
    fail "Case 4: expected a manage-topics.sh set call after step 6's state-write.sh (line $step6_statewrite_line); found at line '${create_mode_set_line:-<none>}'"
  fi
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
