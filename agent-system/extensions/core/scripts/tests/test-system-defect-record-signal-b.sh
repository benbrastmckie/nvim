#!/usr/bin/env bash
# test-system-defect-record-signal-b.sh - Fixture suite for system-defect-record.sh's Signal B
# --dispatched-agent attribution resolver: the agent-system/extensions/*/agents/NAME.md glob and
# its .claude-extensions.json source_dir fallback (the latter added to serve a deploy consumer
# with no agent-system/ subtree of its own -- see context/patterns/system-defect-discrimination.md's
# resolver paragraph).
#
# Structural model: test-deploy-root-guard.sh (bash -c subshell per case, since the subject calls
# `exit` directly on refusal; mktemp -d workdir via common_test_workdir_init). Resolved
# SOURCE-STORE-first (mirroring test-manifest-scripts-sync.sh's own rationale): this suite
# validates the resolver as it is developed in the source store, and preferring a deployed copy
# would silently test stale logic.
#
# Each fixture is a self-contained `<workdir>/<case>/.claude/scripts/`-shaped directory (so
# `common_repo_root "$SCRIPT_DIR" 2` -- the subject's own PROJECT_ROOT computation -- resolves by
# pure path arithmetic to `<workdir>/<case>`, no git root needed) holding the subject plus its
# three sibling dependencies (deploy-root-guard.sh, lib/common.sh, lib/file-scope-overlap.sh).
# `redeploy-remedy-lib.sh` is never copied in: every case here is deploy-tree-shaped
# (`<case>/.claude/scripts`), so deploy-root-guard.sh always takes its success branch and never
# reaches the failure branch that sources it.
#
# Resolution is proven via the recursion-guard echo, not an event write: each fixture's
# `orchestrator-critical-paths.json` marks the expected resolved path `recursion_guard: true`,
# so the subject exits 0 printing `SUPPRESSED:recursion_guard` to stdout with the resolved path
# quoted verbatim in its stderr -- pinning the exact resolved string without copying
# events-append.sh/events-query.sh and their transitive dependencies into the fixture, and
# without writing an event row anywhere (see the plan's Decisions section).
#
# Coverage:
#   (a) consumer route resolves: .claude-extensions.json's core.source_dir points at a fake
#       store with no local agent-system/ subtree -> resolves, same path shape as the glob
#   (b) non-core extension discrimination: source_dir under a second extension key (lean) ->
#       resolved path names that key, not core
#   (c) glob route unchanged: literal agent-system/extensions/core/agents/NAME.md, no
#       .claude-extensions.json -> identical resolved path to (a), proving no regression
#   (d) refusal preserved: .claude-extensions.json present but core.source_dir unreachable, no
#       agent file anywhere -> exit 3, unchanged message
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (the subject or a sibling dependency was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SUBJECT="$(common_test_resolve_subject "system-defect-record.sh" "source-store" \
  "$REPO_ROOT/.claude/scripts/system-defect-record.sh" \
  "$SCRIPT_DIR/../system-defect-record.sh")" || exit 2
common_test_declare_subject "$SUBJECT"
SUBJECT="$(cd "$(dirname "$SUBJECT")" && pwd)/$(basename "$SUBJECT")"
SUBJECT_DIR="$(dirname "$SUBJECT")"

DEPLOY_GUARD="$SUBJECT_DIR/deploy-root-guard.sh"
COMMON_LIB="$SUBJECT_DIR/lib/common.sh"
OVERLAP_LIB="$SUBJECT_DIR/lib/file-scope-overlap.sh"

for dep in "$DEPLOY_GUARD" "$COMMON_LIB" "$OVERLAP_LIB"; do
  if [ ! -f "$dep" ]; then
    echo "ERROR: required sibling dependency not found: $dep" >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build fixture JSON and is not on PATH" >&2
  exit 1
fi

PASSED=0
FAILED=0

common_test_workdir_init

# build_fixture <case_dir> -- populates <case_dir>/.claude/scripts/ with the subject and its
# three sibling dependencies, in the shape the subject's own PROJECT_ROOT computation expects.
build_fixture() {
  local case_dir="$1"
  local scripts_dir="$case_dir/.claude/scripts"
  mkdir -p "$scripts_dir/lib"
  cp "$SUBJECT" "$scripts_dir/system-defect-record.sh"
  cp "$DEPLOY_GUARD" "$scripts_dir/deploy-root-guard.sh"
  cp "$COMMON_LIB" "$scripts_dir/lib/common.sh"
  cp "$OVERLAP_LIB" "$scripts_dir/lib/file-scope-overlap.sh"
}

# write_critical_paths <case_dir> <resolved_path> -- writes a critical-paths fixture marking
# <resolved_path> (verbatim, no scope_roots stripping -- scope_roots is deliberately empty) as
# recursion_guard: true.
write_critical_paths() {
  local case_dir="$1"
  local resolved_path="$2"
  mkdir -p "$case_dir/.claude/context/reference"
  jq -n --arg p "$resolved_path" '{
    "$schema": "orchestrator-critical-paths-v1",
    "scope_roots": [],
    "critical_paths": [ { "path": $p, "label": "fixture probe agent (test)", "recursion_guard": true } ]
  }' > "$case_dir/.claude/context/reference/orchestrator-critical-paths.json"
}

AGENT_NAME="fixture-probe-agent"

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (a) Consumer route resolves: .claude-extensions.json's core.source_dir points at a fake store
#     with no local agent-system/ subtree.
# ─────────────────────────────────────────────────────────────────────────────────────────────
CASE_A="$WORKDIR/case_a"
build_fixture "$CASE_A"
mkdir -p "$CASE_A/fake-store/core/agents"
echo "# fixture probe agent" > "$CASE_A/fake-store/core/agents/${AGENT_NAME}.md"
EXPECTED_A="agent-system/extensions/core/agents/${AGENT_NAME}.md"
write_critical_paths "$CASE_A" "$EXPECTED_A"
jq -n --arg sd "$CASE_A/fake-store/core" '{"extensions": {"core": {"source_dir": $sd}}}' \
  > "$CASE_A/.claude-extensions.json"

OUT_A="$(bash "$CASE_A/.claude/scripts/system-defect-record.sh" \
  --defect-class RECOVERY_DECLINED --detecting-site "test-signal-b" --message "fixture probe" \
  --dispatched-agent "$AGENT_NAME" 2>&1)"
RC_A=$?
if [[ "$RC_A" -eq 0 ]]; then
  common_test_pass "(a) consumer route: exits 0"
else
  common_test_fail "(a) consumer route: expected exit 0, got $RC_A" "$OUT_A"
fi
if grep -qF "SUPPRESSED:recursion_guard" <<< "$OUT_A"; then
  common_test_pass "(a) consumer route: recursion guard suppressed (resolution succeeded)"
else
  common_test_fail "(a) consumer route: recursion-guard suppression not observed" "$OUT_A"
fi
if grep -qF "'${EXPECTED_A}'" <<< "$OUT_A"; then
  common_test_pass "(a) consumer route: resolved path quoted verbatim ($EXPECTED_A)"
else
  common_test_fail "(a) consumer route: resolved path not found verbatim in output" "$OUT_A"
fi
RESOLVED_A="$EXPECTED_A"

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (b) Non-core extension discrimination: source_dir under a second extension key (lean) ->
#     resolved path names that key, not core.
# ─────────────────────────────────────────────────────────────────────────────────────────────
CASE_B="$WORKDIR/case_b"
build_fixture "$CASE_B"
mkdir -p "$CASE_B/fake-store/lean/agents"
echo "# fixture probe agent" > "$CASE_B/fake-store/lean/agents/${AGENT_NAME}.md"
EXPECTED_B="agent-system/extensions/lean/agents/${AGENT_NAME}.md"
write_critical_paths "$CASE_B" "$EXPECTED_B"
jq -n --arg sd "$CASE_B/fake-store/lean" '{"extensions": {"lean": {"source_dir": $sd}}}' \
  > "$CASE_B/.claude-extensions.json"

OUT_B="$(bash "$CASE_B/.claude/scripts/system-defect-record.sh" \
  --defect-class RECOVERY_DECLINED --detecting-site "test-signal-b" --message "fixture probe" \
  --dispatched-agent "$AGENT_NAME" 2>&1)"
RC_B=$?
if [[ "$RC_B" -eq 0 ]]; then
  common_test_pass "(b) non-core extension: exits 0"
else
  common_test_fail "(b) non-core extension: expected exit 0, got $RC_B" "$OUT_B"
fi
if grep -qF "'${EXPECTED_B}'" <<< "$OUT_B"; then
  common_test_pass "(b) non-core extension: resolved path names 'lean' ($EXPECTED_B)"
else
  common_test_fail "(b) non-core extension: resolved path did not name 'lean'" "$OUT_B"
fi
if grep -qF "agent-system/extensions/core/agents/${AGENT_NAME}.md" <<< "$OUT_B"; then
  common_test_fail "(b) non-core extension: resolved path wrongly named 'core'" "$OUT_B"
else
  common_test_pass "(b) non-core extension: resolved path did not wrongly name 'core'"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (c) Glob route unchanged: literal agent-system/extensions/core/agents/NAME.md, no
#     .claude-extensions.json at all -> identical resolved path to (a), proving no regression.
# ─────────────────────────────────────────────────────────────────────────────────────────────
CASE_C="$WORKDIR/case_c"
build_fixture "$CASE_C"
mkdir -p "$CASE_C/agent-system/extensions/core/agents"
echo "# fixture probe agent" > "$CASE_C/agent-system/extensions/core/agents/${AGENT_NAME}.md"
EXPECTED_C="agent-system/extensions/core/agents/${AGENT_NAME}.md"
write_critical_paths "$CASE_C" "$EXPECTED_C"
# Deliberately NO .claude-extensions.json in this fixture.

OUT_C="$(bash "$CASE_C/.claude/scripts/system-defect-record.sh" \
  --defect-class RECOVERY_DECLINED --detecting-site "test-signal-b" --message "fixture probe" \
  --dispatched-agent "$AGENT_NAME" 2>&1)"
RC_C=$?
if [[ "$RC_C" -eq 0 ]]; then
  common_test_pass "(c) glob route: exits 0"
else
  common_test_fail "(c) glob route: expected exit 0, got $RC_C" "$OUT_C"
fi
if grep -qF "'${EXPECTED_C}'" <<< "$OUT_C"; then
  common_test_pass "(c) glob route: resolved path quoted verbatim ($EXPECTED_C)"
else
  common_test_fail "(c) glob route: resolved path not found verbatim in output" "$OUT_C"
fi
RESOLVED_C="$EXPECTED_C"

if [[ "$RESOLVED_A" == "$RESOLVED_C" ]]; then
  common_test_pass "(a)/(c) parity: consumer route and glob route emit the identical resolved-path string"
else
  common_test_fail "(a)/(c) parity: resolved-path strings diverge (a=$RESOLVED_A c=$RESOLVED_C)"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# (d) Refusal preserved: .claude-extensions.json present but core.source_dir unreachable, no
#     agent file anywhere -> exit 3, unchanged message.
# ─────────────────────────────────────────────────────────────────────────────────────────────
CASE_D="$WORKDIR/case_d"
build_fixture "$CASE_D"
jq -n '{"extensions": {"core": {"source_dir": "/nonexistent/path/does-not-exist-signal-b"}}}' \
  > "$CASE_D/.claude-extensions.json"
# Deliberately no agent file anywhere (no fake-store, no agent-system/ subtree).

OUT_D="$(bash "$CASE_D/.claude/scripts/system-defect-record.sh" \
  --defect-class RECOVERY_DECLINED --detecting-site "test-signal-b" --message "fixture probe" \
  --dispatched-agent "$AGENT_NAME" 2>&1)"
RC_D=$?
if [[ "$RC_D" -eq 3 ]]; then
  common_test_pass "(d) refusal preserved: exits 3"
else
  common_test_fail "(d) refusal preserved: expected exit 3, got $RC_D" "$OUT_D"
fi
if grep -qF "Signal B attribution unresolvable" <<< "$OUT_D" && \
   grep -qF "did not resolve to a path under agent-system/extensions/**" <<< "$OUT_D"; then
  common_test_pass "(d) refusal preserved: unchanged refusal message"
else
  common_test_fail "(d) refusal preserved: refusal message changed or missing" "$OUT_D"
fi

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
