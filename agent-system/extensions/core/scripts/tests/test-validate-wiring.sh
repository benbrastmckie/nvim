#!/usr/bin/env bash
# test-validate-wiring.sh - Fixture-driven regression suite for validate-wiring.sh's
# missing-tree-root SKIP guards: a consumer layout with .claude present and .opencode absent
# (the normal, supported configuration exposed by ModelChecker deleting its stale .opencode/
# deploy) must skip the absent arm with an [SKIP] line rather than cascading [FAIL] rows that
# mask the real .claude-side result.
#
# Cases (f) and (g) cover validate_context_files' tree-attribution contract in both directions:
# (f) builds a .claude-only fixture with one context index entry whose file exists and one whose
# file is deliberately absent, and asserts exactly one "Missing context file" line appears,
# naming the absent entry and the tree ([.claude]), never the present entry. (g) repeats the same
# two-entry setup against the opencode-only fixture (case (d)'s tree transform) and asserts the
# failure line instead names [.opencode] -- proving a reader can tell which deployed tree a
# failure belongs to without inferring it from context. Both also assert the per-tree
# "N of M context index entries missing on disk" info line Phase 1 added.
#
# Fixture model: test-deploy-verify-wiring.sh's mktemp -d + trap cleanup + git-init-free
# throwaway consumer directory. validate-wiring.sh sources deploy-root-guard.sh unconditionally
# (no REPO_ROOT override, unlike check-task-references.sh), which requires the running script's
# own parent-of-parent directory to be literally .claude or .opencode -- so the fixture places a
# COPY of the script (plus its lib/common.sh and deploy-root-guard.sh dependencies) at
# <fixture>/.claude/scripts/validate-wiring.sh, exactly as test-deploy-verify-wiring.sh's
# established layout does for other core/scripts/*.sh under test.
#
# A minimal-but-genuinely-passing .claude fixture is achievable: validate_index_entries and
# validate_task_type_entries only WARN (never FAIL, always return 0) on zero matching entries, so
# an empty context/index.json ({"entries":[]}) satisfies every non-agent/non-rule check without
# fabricating real context content. This is what makes assertion (c) (clean .claude -> exit 0)
# possible without narrowing the suite per the plan's Scope Hypothesis fallback.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (validate-wiring.sh, lib/common.sh, or deploy-root-guard.sh not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
WIRING_SRC="$SCRIPT_DIR/../validate-wiring.sh"
COMMON_SRC="$SCRIPT_DIR/../lib/common.sh"
GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"

PASSED=0
FAILED=0

for f in "$WIRING_SRC" "$COMMON_SRC" "$GUARD_SRC"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: expected dependency at $f" >&2
    exit 2
  fi
done

common_test_workdir_init

# build_fixture <name>
# Creates <WORKDIR>/<name> with a minimal, genuinely-passing .claude tree (no .opencode) and
# returns its path via the FIXTURE global.
build_fixture() {
  local name="$1"
  FIXTURE="$WORKDIR/$name"
  mkdir -p "$FIXTURE/.claude/scripts/lib" "$FIXTURE/.claude/agents" \
    "$FIXTURE/.claude/skills/skill-meta" "$FIXTURE/.claude/rules" "$FIXTURE/.claude/context"

  cp "$WIRING_SRC" "$FIXTURE/.claude/scripts/validate-wiring.sh"
  cp "$COMMON_SRC" "$FIXTURE/.claude/scripts/lib/common.sh"
  cp "$GUARD_SRC" "$FIXTURE/.claude/scripts/deploy-root-guard.sh"

  for agent in general-research-agent general-implementation-agent planner-agent meta-builder-agent; do
    echo "# $agent" > "$FIXTURE/.claude/agents/$agent.md"
  done

  for rule in artifact-formats.md error-handling.md git-workflow.md state-management.md workflows.md; do
    echo "# $rule" > "$FIXTURE/.claude/rules/$rule"
  done

  echo '{"entries": []}' > "$FIXTURE/.claude/context/index.json"
}

run_wiring() {
  # Locates the fixture's own copy of the runner under whichever of .claude/.opencode it was
  # placed under (case (d) moves the whole tree from .claude to .opencode).
  local mode="$1" out_file="$2" runner
  if [[ -f "$FIXTURE/.claude/scripts/validate-wiring.sh" ]]; then
    runner="$FIXTURE/.claude/scripts/validate-wiring.sh"
  else
    runner="$FIXTURE/.opencode/scripts/validate-wiring.sh"
  fi
  ( cd "$FIXTURE" && bash "$runner" "$mode" ) > "$out_file" 2>&1
  echo $?
}

# =====================================================================
# Case (a)/(b)/(c): .claude present, .opencode absent.
# =====================================================================
build_fixture "claude-only"
out_a="$WORKDIR/case-a.txt"
code_a="$(run_wiring "all" "$out_a")"

if grep -q '\[SKIP\].*\.opencode' "$out_a"; then
  common_test_pass "(a) [SKIP] line names .opencode"
else
  common_test_fail "(a) expected a [SKIP] line naming .opencode; output:
$(cat "$out_a")"
fi

if grep -qE '\[FAIL\].*\.opencode|\.opencode.*\[FAIL\]' "$out_a"; then
  common_test_fail "(b) a [FAIL] line mentions .opencode"
else
  common_test_pass "(b) no [FAIL] line mentions .opencode"
fi

if [[ "$code_a" -eq 0 ]]; then
  common_test_pass "(c) clean .claude / absent .opencode: exit 0"
else
  common_test_fail "(c) clean .claude / absent .opencode expected exit 0, got $code_a; output:
$(cat "$out_a")"
fi

# Break one .claude file and confirm the SAME run now fails, attributed to .claude.
rm -f "$FIXTURE/.claude/rules/git-workflow.md"
out_a_broken="$WORKDIR/case-a-broken.txt"
code_a_broken="$(run_wiring "all" "$out_a_broken")"
if [[ "$code_a_broken" -eq 1 ]] && grep -q 'Rule missing: git-workflow.md' "$out_a_broken"; then
  common_test_pass "(c) broken .claude file: exit 1 with .claude-attributed failure"
else
  common_test_fail "(c) broken .claude file expected exit 1 + 'Rule missing: git-workflow.md', got exit=$code_a_broken; output:
$(cat "$out_a_broken")"
fi

# =====================================================================
# Case (d): mirror case -- .opencode present, .claude absent -- skips .claude symmetrically.
# =====================================================================
build_fixture "opencode-only"
mv "$FIXTURE/.claude" "$FIXTURE/.opencode"
# validate-wiring.sh's --opencode arm expects agents under "agent/subagents" (see main()'s
# validate_core_system call), not "agents" -- mirror that subdir name for a fair validation run.
mv "$FIXTURE/.opencode/agents" "$FIXTURE/.opencode/agent"
mkdir -p "$FIXTURE/.opencode/agent/subagents"
mv "$FIXTURE/.opencode/agent"/*.md "$FIXTURE/.opencode/agent/subagents/" 2>/dev/null || true
out_d="$WORKDIR/case-d.txt"
code_d="$(run_wiring "all" "$out_d")"
if grep -q '\[SKIP\].*\.claude' "$out_d" && ! grep -qE '\[FAIL\].*\.claude|\.claude.*\[FAIL\]' "$out_d"; then
  common_test_pass "(d) mirror case: .opencode present / .claude absent skips .claude symmetrically"
else
  common_test_fail "(d) expected [SKIP] naming .claude and no .claude-attributed [FAIL], got exit=$code_d; output:
$(cat "$out_d")"
fi

# =====================================================================
# Case (e): both trees absent -- exit 0 with two [SKIP] lines and zero failures.
#
# STRUCTURAL NOTE (deviation from the plan's literal wording, recorded here and in this phase's
# progress file): deploy-root-guard.sh requires the running script's own parent-of-parent
# directory to be LITERALLY ".claude" or ".opencode" -- there is no REPO_ROOT-style override for
# validate-wiring.sh the way check-task-references.sh has one. This means the tree that hosts the
# runner necessarily exists as a real directory on disk; "both trees absent from disk" cannot be
# constructed via a real subprocess invocation, only "the tree I did not ask to validate is
# absent." The realizable equivalent tested below: the runner lives under .claude/scripts/ with
# NO payload directories at all (not merely missing files -- agents/skills/rules/context
# themselves absent), .opencode is genuinely absent, and the invocation requests ONLY the absent
# tree (--opencode) so the .claude arm's conditional is never even entered. This still proves the
# core guarantee case (e) is after: requesting a tree that is not deployed yields SKIP and zero
# failures, never a cascade of [FAIL] rows.
# =====================================================================
FIXTURE="$WORKDIR/neither"
mkdir -p "$FIXTURE/.claude/scripts/lib"
cp "$WIRING_SRC" "$FIXTURE/.claude/scripts/validate-wiring.sh"
cp "$COMMON_SRC" "$FIXTURE/.claude/scripts/lib/common.sh"
cp "$GUARD_SRC" "$FIXTURE/.claude/scripts/deploy-root-guard.sh"
out_e="$WORKDIR/case-e.txt"
code_e="$(run_wiring "--opencode" "$out_e")"
skip_count=$(grep -c '\[SKIP\]' "$out_e")
if [[ "$code_e" -eq 0 ]] && [[ "$skip_count" -ge 1 ]] && ! grep -q '\[FAIL\]' "$out_e"; then
  common_test_pass "(e) requested tree absent (both trees carry no real payload): exit 0, [SKIP] line(s), zero failures"
else
  common_test_fail "(e) expected exit 0 with SKIP lines and no failures, got exit=$code_e skip_count=$skip_count; output:
$(cat "$out_e")"
fi

# =====================================================================
# Case (f): .claude-only fixture, two context index entries (one present, one absent) --
# the failure line must attribute to .claude, name the absent entry, and never name the
# present entry. Also asserts the Phase 1 per-tree "N of M ... missing on disk" info line.
# =====================================================================
build_fixture "claude-only-ctx"
cat > "$FIXTURE/.claude/context/present.md" <<'EOF'
# present
EOF
cat > "$FIXTURE/.claude/context/index.json" <<'EOF'
{"entries": [{"path": "present.md"}, {"path": "absent.md"}]}
EOF
out_f="$WORKDIR/case-f.txt"
code_f="$(run_wiring "all" "$out_f")"
missing_lines_f=$(grep -c 'Missing context file' "$out_f")
if [[ "$code_f" -eq 1 ]] && [[ "$missing_lines_f" -eq 1 ]] \
  && grep -q 'Missing context file \[\.claude\]: absent.md' "$out_f" \
  && ! grep -q 'Missing context file.*present.md' "$out_f"; then
  common_test_pass "(f) present entry produces no failure; absent entry's failure names .claude"
else
  common_test_fail "(f) expected exactly one .claude-attributed failure naming absent.md and none naming present.md, got exit=$code_f missing_lines=$missing_lines_f; output:
$(cat "$out_f")"
fi

if grep -q '\[\.claude\] 1 of 2 context index entries missing on disk' "$out_f"; then
  common_test_pass "(f) per-tree count line reports 1 of 2 for .claude"
else
  common_test_fail "(f) expected a '[.claude] 1 of 2 context index entries missing on disk' line; output:
$(cat "$out_f")"
fi

# =====================================================================
# Case (g): mirror of (f) against the opencode-only fixture -- the failure line must instead
# name .opencode, proving attribution tracks the tree being validated, not a hardcoded label.
# =====================================================================
build_fixture "opencode-only-ctx"
mv "$FIXTURE/.claude" "$FIXTURE/.opencode"
mv "$FIXTURE/.opencode/agents" "$FIXTURE/.opencode/agent"
mkdir -p "$FIXTURE/.opencode/agent/subagents"
mv "$FIXTURE/.opencode/agent"/*.md "$FIXTURE/.opencode/agent/subagents/" 2>/dev/null || true
cat > "$FIXTURE/.opencode/context/present.md" <<'EOF'
# present
EOF
cat > "$FIXTURE/.opencode/context/index.json" <<'EOF'
{"entries": [{"path": "present.md"}, {"path": "absent.md"}]}
EOF
out_g="$WORKDIR/case-g.txt"
code_g="$(run_wiring "all" "$out_g")"
missing_lines_g=$(grep -c 'Missing context file' "$out_g")
if [[ "$code_g" -eq 1 ]] && [[ "$missing_lines_g" -eq 1 ]] \
  && grep -q 'Missing context file \[\.opencode\]: absent.md' "$out_g" \
  && ! grep -q 'Missing context file.*present.md' "$out_g"; then
  common_test_pass "(g) present entry produces no failure; absent entry's failure names .opencode"
else
  common_test_fail "(g) expected exactly one .opencode-attributed failure naming absent.md and none naming present.md, got exit=$code_g missing_lines=$missing_lines_g; output:
$(cat "$out_g")"
fi

if grep -q '\[\.opencode\] 1 of 2 context index entries missing on disk' "$out_g"; then
  common_test_pass "(g) per-tree count line reports 1 of 2 for .opencode"
else
  common_test_fail "(g) expected a '[.opencode] 1 of 2 context index entries missing on disk' line; output:
$(cat "$out_g")"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
