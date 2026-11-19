#!/usr/bin/env bash
# test-sapience-publish.sh - Regression suite for sapience-publish.sh: the four Sapience
# write-surface publishers (doc-comment, doc-version, dm, ko) behind one entry point.
#
# Curl-stub URL dispatch ordering note (load-bearing -- see Phase 1's own Risk row): the
# doc-version POST (`POST /v1/docs/<slug>`) and the doc-comment POST
# (`POST /v1/docs/<slug>/comments`) share the `*v1/docs/*` substring, so the stub's `case`
# dispatch below lists the `*/comments*` pattern BEFORE the bare `*v1/docs/*` pattern -- shell
# `case` matches first-listed-first, so this ordering is what keeps the two branches
# distinguishable. At least one doc-version test case additionally asserts the bare-slug branch
# (never the comments branch) was the one actually hit, so a reversed-order regression fails for
# the right reason rather than passing by accident.
#
# Cases (this phase -- structural + lockstep only; per-subcommand behavioral cases are added in
# their own governing plan phase):
#   (1) --help exits 0 and names all four subcommands.
#   (2) An unknown subcommand exits non-zero.
#   (3) No subcommand at all exits non-zero.
#   (4) --dry-run and --confirm together are refused (non-zero exit), for every subcommand.
#   (5) The script's header names no MCP write tool (sapience_remember/sapience_wrapup/
#       sapience_handoff/sapience_adddoc) as a prescribed write path.
#   (6) The marker-delimited worktree-checkout-resolution block is byte-identical to
#       sapience-remember.sh's own copy (local lockstep guard, a second line of defense
#       independent of test-sapience-mcp-registration.sh's Case 30).
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution.
#
# Bootstrap note: this suite lives under a DIFFERENT extension (sapience) than the shared
# lib/common.sh it needs (core). Post-deploy, every extension's scripts/tests/ and scripts/lib/
# are flattened into one shared .claude/scripts/ tree; pre-deploy, in a source-store-only
# checkout, it falls back to core's own scripts/lib/common.sh directly.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-publish.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-publish.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-publish.sh" \
  "$SCRIPT_DIR/../sapience-publish.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

API_LIB_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/lib/sapience-api-lib.sh"
API_LIB_CANDIDATE_SOURCE="$SCRIPT_DIR/../lib/sapience-api-lib.sh"
if [ -f "$API_LIB_CANDIDATE_DEPLOYED" ]; then
  API_LIB="$API_LIB_CANDIDATE_DEPLOYED"
elif [ -f "$API_LIB_CANDIDATE_SOURCE" ]; then
  API_LIB="$API_LIB_CANDIDATE_SOURCE"
else
  echo "ERROR: sapience-api-lib.sh not found at $API_LIB_CANDIDATE_DEPLOYED or $API_LIB_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$API_LIB"

GUARD_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
GUARD_CANDIDATE_SOURCE="$SCRIPT_DIR/../../../core/scripts/deploy-root-guard.sh"
if [ -f "$GUARD_CANDIDATE_DEPLOYED" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_DEPLOYED"
elif [ -f "$GUARD_CANDIDATE_SOURCE" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_SOURCE"
else
  echo "ERROR: deploy-root-guard.sh not found at $GUARD_CANDIDATE_DEPLOYED or $GUARD_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$GUARD_SCRIPT"
common_test_declare_subject "$COMMON_SH"

REMEMBER_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/sapience-remember.sh"
REMEMBER_CANDIDATE_SOURCE="$SCRIPT_DIR/../sapience-remember.sh"
if [ -f "$REMEMBER_CANDIDATE_DEPLOYED" ]; then
  REMEMBER_SCRIPT="$REMEMBER_CANDIDATE_DEPLOYED"
elif [ -f "$REMEMBER_CANDIDATE_SOURCE" ]; then
  REMEMBER_SCRIPT="$REMEMBER_CANDIDATE_SOURCE"
else
  echo "ERROR: sapience-remember.sh not found at $REMEMBER_CANDIDATE_DEPLOYED or $REMEMBER_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$REMEMBER_SCRIPT"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked indirectly via `trap cleanup EXIT`
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- an isolated <scratch>/.claude/scripts/{sapience-publish.sh,
#     deploy-root-guard.sh,lib/{common.sh,sapience-api-lib.sh}} tree plus a scratch git repo.
#     Echoes the scratch repo root. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-publish.sh"
  cp "$API_LIB" "$scratch/.claude/scripts/lib/sapience-api-lib.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-publish.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

BIN_REL=".claude/scripts/sapience-publish.sh"

# run_publish <scratch> [args...] -- no curl stub installed; a network call reaching the real
# system curl would fail/hang, so a case using this helper is asserting "no network call" as a
# structural fact, not an assumption.
run_publish() {
  local scratch="$1"; shift
  env HOME="$TOP_WORKDIR" bash "$scratch/$BIN_REL" "$@"
}

TOKEN_FIXTURE="sapience-publish-test-fixture-token-DO-NOT-LEAK-7c1a"

# =====================================================================================
# Case 1: --help exits 0 and names all four subcommands.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" --help 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(1) --help: exits 0"
  else
    common_test_fail "(1) --help: exits 0" "got rc=$rc out=$out"
  fi
  missing=""
  for sub in doc-comment doc-version dm ko; do
    echo "$out" | grep -qF "$sub" || missing="$missing $sub"
  done
  if [ -z "$missing" ]; then
    common_test_pass "(1) --help: names all four subcommands"
  else
    common_test_fail "(1) --help: names all four subcommands" "missing:$missing out=$out"
  fi
}

# =====================================================================================
# Case 2: an unknown subcommand exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" bogus-subcommand 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(2) unknown subcommand: refused with a non-zero exit"
  else
    common_test_fail "(2) unknown subcommand: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 3: no subcommand at all exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(3) no subcommand: refused with a non-zero exit"
  else
    common_test_fail "(3) no subcommand: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 4: --dry-run and --confirm together are refused, for every subcommand.
# =====================================================================================
for sub in doc-comment doc-version dm ko; do
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" "$sub" --dry-run --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(4) $sub: --dry-run and --confirm together are refused"
  else
    common_test_fail "(4) $sub: --dry-run and --confirm together are refused" "got rc=$rc out=$out"
  fi
done

# =====================================================================================
# Case 5: the script's header names no MCP write tool as a prescribed write path.
# =====================================================================================
{
  if grep -n 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc' "$SCRIPT_UNDER_TEST" >/dev/null 2>&1; then
    common_test_fail "(5) no MCP write tool named as a prescribed write path" \
      "$(grep -n 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc' "$SCRIPT_UNDER_TEST")"
  else
    common_test_pass "(5) no MCP write tool named as a prescribed write path"
  fi
}

# =====================================================================================
# Case 6: the marker-delimited worktree-checkout-resolution block is byte-identical to
# sapience-remember.sh's own copy.
# =====================================================================================
{
  BLOCK_PUBLISH="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$SCRIPT_UNDER_TEST")"
  BLOCK_REMEMBER="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$REMEMBER_SCRIPT")"
  if [ -n "$BLOCK_PUBLISH" ] && [ "$BLOCK_PUBLISH" = "$BLOCK_REMEMBER" ]; then
    common_test_pass "(6) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  else
    common_test_fail "(6) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
