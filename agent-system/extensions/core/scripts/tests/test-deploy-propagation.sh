#!/usr/bin/env bash
# test-deploy-propagation.sh - Scratch-tree regression harness for the deploy-engine
# consolidation. Runs the REAL headless deploy (deploy-headless.sh, unmodified) against a
# throwaway scratch git repo and asserts the deployed tree actually matches what the core
# manifest declares -- the exact surface the two-engine defect class breaks.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, a trap-based scratch WORKDIR, exit 0 on all-pass / exit 1 on
# any-fail). Unlike that suite, this one drives a real subprocess (deploy-headless.sh, which
# itself launches a headless `nvim`) rather than sourcing a library directly, since the code
# under test is the Lua deploy engine, not a shell function.
#
# Source resolution: deploy-headless.sh always reads extension SOURCE content from the real
# `~/.config/nvim` checkout (global_source_dir has no override plumbed through
# `sync.load_all_globally`'s `config` argument -- see manager.load's counterpart, which DOES
# accept a source override via extensions/config.lua's `global_dir` parameter). This harness
# therefore does not fabricate a fixture extension tree; it deploys the real core manifest's
# declared entries into a scratch TARGET and checks them there. This is deliberately hermetic on
# the TARGET side (a fresh git repo under mktemp, discarded on exit) even though the SOURCE side
# is the live checkout -- matching deploy-headless.sh's own real usage (one global source, many
# target repos).
#
# Canary file: `scripts/lib/phase-heading-patterns.sh` is used as Assertions A/B/D's concrete
# example. It is a real, pre-existing `provides.scripts` entry naming a subdirectory path
# ("lib/phase-heading-patterns.sh") -- exactly the shape the allow-list top-path-segment bug
# (picker/operations/sync.lua's `load_all_globally` -> `scan_all_artifacts`'s `sync_scan` allow-
# list post-filter) drops. No manifest mutation is needed to reproduce the defect; the bug
# already fires on this real entry today.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (deploy-headless.sh or nvim not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this harness supports:
# the source-store copy (agent-system/extensions/core/scripts/tests/, 5 directories
# below repo root) and the deployed copy (.claude/scripts/tests/, only 3 directories
# below repo root) -- see the DEPLOY_SCRIPT_CANDIDATES dual-lookup below, which already
# treats the deployed copy as the preferred resolution path. A single fixed levels-up
# count cannot be correct for both depths at once, so resolve via the git worktree root
# first (depth-independent) and only fall back to the fixed-depth guess (matching the
# source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPT_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/deploy-headless.sh"
  "$SCRIPT_DIR/../deploy-headless.sh"
)
DEPLOY_SCRIPT=""
for candidate in "${DEPLOY_SCRIPT_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    DEPLOY_SCRIPT="$candidate"
    break
  fi
done
if [[ -z "$DEPLOY_SCRIPT" ]]; then
  echo "ERROR: deploy-headless.sh not found at any of:" >&2
  for candidate in "${DEPLOY_SCRIPT_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: nvim not found on PATH; cannot run the real headless deploy." >&2
  exit 2
fi

MANIFEST="$REPO_ROOT/agent-system/extensions/core/manifest.json"
if [[ ! -f "$MANIFEST" ]]; then
  echo "ERROR: core manifest not found at $MANIFEST" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${WORKDIR:-}" && -d "$WORKDIR" ]] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

TARGET="$WORKDIR/scratch-repo"
mkdir -p "$TARGET"
git -C "$TARGET" init -q
# Seeded from scripts/lib/runtime-file-patterns.sh's runtime_ignore_block() -- the single
# canonical source for the ephemeral-runtime-state gitignore block, also consumed by
# check-runtime-file-tracking.sh and pinned to context/standards/orchestrator-runtime-files.md's
# "Consumer Repo Setup" block by tests/test-runtime-file-tracking.sh Case 3. This is generated,
# not hand-mirrored, so it cannot drift ahead of or behind that block again -- seeded here only
# so this scratch repo represents a properly-onboarded consumer for gate14
# (check-runtime-file-tracking.sh)'s ignore-coverage check; a bare, never-onboarded git repo
# would fail Check A for reasons unrelated to what this harness actually tests (deploy
# propagation).
# shellcheck disable=SC1090,SC1091
. "${SCRIPT_DIR}/../lib/runtime-file-patterns.sh"
runtime_ignore_block > "$TARGET/.gitignore"
git -C "$TARGET" -c user.email="test@test.local" -c user.name="deploy-propagation-test" \
  commit -q --allow-empty -m "scratch init"

CANARY_REL="scripts/lib/phase-heading-patterns.sh"
CANARY_SOURCE="$REPO_ROOT/agent-system/extensions/core/scripts/lib/phase-heading-patterns.sh"
if [[ ! -f "$CANARY_SOURCE" ]]; then
  echo "ERROR: canary source file not found: $CANARY_SOURCE" >&2
  echo "This harness assumes the file exists as a real subdirectory-declared" >&2
  echo "provides.scripts entry; if it has moved, update CANARY_REL/CANARY_SOURCE." >&2
  exit 2
fi

run_deploy() {
  local label="$1"
  local output
  output="$(bash "$DEPLOY_SCRIPT" "$TARGET" 2>&1)"
  local code=$?
  if [[ "$code" -ne 0 ]]; then
    fail "$label: deploy-headless.sh exited $code (expected 0). Output:"
    echo "$output" | sed 's/^/    /'
    return 1
  fi
  info "$label: deploy completed ($(echo "$output" | grep -oE '(Resynced|Wiped and regenerated) [0-9]+ extension' || echo 'no count line'))"
  return 0
}

# =====================================================================
# Assertion A (fresh deploy): a manifest-declared scripts/lib/*.sh entry exists in the deployed
# tree after a from-scratch deploy. Expected RED at authorship time (this is the defect).
# =====================================================================
info "Assertion A: fresh deploy against scratch tree $TARGET"
if run_deploy "fresh deploy"; then
  if [[ -f "$TARGET/.claude/$CANARY_REL" ]]; then
    pass "Assertion A: $CANARY_REL present after fresh deploy"
  else
    fail "Assertion A: $CANARY_REL MISSING after fresh deploy (subdirectory-declared scripts entry dropped)"
  fi
else
  fail "Assertion A: fresh deploy did not complete; cannot check canary"
fi

# =====================================================================
# Assertion B (resync): the same assertion holds after a second deploy against the
# already-deployed tree. Expected RED at authorship time (manager.load's already-loaded abort /
# load_all_globally's same allow-list bug on the resync path).
# =====================================================================
info "Assertion B: resync deploy against already-deployed tree"
if run_deploy "resync deploy"; then
  if [[ -f "$TARGET/.claude/$CANARY_REL" ]]; then
    pass "Assertion B: $CANARY_REL present after resync deploy"
  else
    fail "Assertion B: $CANARY_REL MISSING after resync deploy"
  fi
else
  fail "Assertion B: resync deploy did not complete; cannot check canary"
fi

# =====================================================================
# Assertion C (parity): every entry of every provides.* category present in the source manifest
# exists in the deployed tree. Driven directly from the manifest (jq), independent of verify.lua
# (which does not cover most categories until Phase 7) so this harness has real teeth from
# authorship.
# =====================================================================
info "Assertion C: declared-vs-deployed parity across all provides.* categories"
parity_missing=0
parity_checked=0

check_flat_category() {
  local category="$1" target_subdir="$2"
  local entry
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    parity_checked=$((parity_checked + 1))
    if [[ ! -f "$TARGET/.claude/$target_subdir/$entry" ]]; then
      parity_missing=$((parity_missing + 1))
      echo "    missing: $category/$entry"
    fi
  done < <(jq -r --arg c "$category" '.provides[$c][]? // empty' "$MANIFEST")
}

check_flat_category "agents" "agents"
check_flat_category "commands" "commands"
check_flat_category "rules" "rules"
check_flat_category "scripts" "scripts"
check_flat_category "hooks" "hooks"
check_flat_category "systemd" "systemd"

# docs and templates: entries may be files OR directories (recursive copy) -- existence of
# either the file or the directory counts as present.
for category in docs templates; do
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    parity_checked=$((parity_checked + 1))
    if [[ ! -e "$TARGET/.claude/$category/$entry" ]]; then
      parity_missing=$((parity_missing + 1))
      echo "    missing: $category/$entry"
    fi
  done < <(jq -r --arg c "$category" '.provides[$c][]? // empty' "$MANIFEST")
done

# root_files: land directly at .claude/ root, but settings.json/settings.local.json are
# install-once (never overwritten once present) -- their presence after a fresh deploy into an
# empty scratch tree is still a valid presence check since nothing pre-existed to skip them.
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  parity_checked=$((parity_checked + 1))
  if [[ ! -f "$TARGET/.claude/$entry" ]]; then
    parity_missing=$((parity_missing + 1))
    echo "    missing: root_files/$entry"
  fi
done < <(jq -r '.provides.root_files[]? // empty' "$MANIFEST")

# skills: directory-shaped entries; presence checked via SKILL.md.
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  parity_checked=$((parity_checked + 1))
  if [[ ! -f "$TARGET/.claude/skills/$entry/SKILL.md" ]]; then
    parity_missing=$((parity_missing + 1))
    echo "    missing: skills/$entry/SKILL.md"
  fi
done < <(jq -r '.provides.skills[]? // empty' "$MANIFEST")

# context: entries may be top-level files or directories.
while IFS= read -r entry; do
  [[ -z "$entry" ]] && continue
  parity_checked=$((parity_checked + 1))
  if [[ ! -e "$TARGET/.claude/context/$entry" ]]; then
    parity_missing=$((parity_missing + 1))
    echo "    missing: context/$entry"
  fi
done < <(jq -r '.provides.context[]? // empty' "$MANIFEST")

if [[ "$parity_missing" -eq 0 ]]; then
  pass "Assertion C: declared-vs-deployed parity ($parity_checked entries checked, 0 missing)"
else
  fail "Assertion C: declared-vs-deployed parity ($parity_missing of $parity_checked entries missing -- see 'missing:' lines above)"
fi

# =====================================================================
# Assertion D (content equality): a deliberately-staled deployed file is detected as differing
# from source. No verifier hashes content yet (that lands in Phase 7); this assertion establishes
# the invariant directly via `diff` so the harness has real content even before Phase 7 gives
# verify.lua the same teeth. If the canary was never deployed (Assertion A/B RED), the file is
# staled anyway to exercise the diff mechanics, but is noted as synthetic in that case.
# =====================================================================
info "Assertion D: deliberately-staled deployed file is detected as differing from source"
CANARY_DEPLOYED="$TARGET/.claude/$CANARY_REL"
if [[ ! -f "$CANARY_DEPLOYED" ]]; then
  mkdir -p "$(dirname "$CANARY_DEPLOYED")"
  cp "$CANARY_SOURCE" "$CANARY_DEPLOYED"
  info "Assertion D: canary was absent (Assertion A/B red) -- seeded a synthetic copy to exercise diff mechanics"
fi
echo "# deliberately staled by test-deploy-propagation.sh $(date -u +%FT%TZ)" >> "$CANARY_DEPLOYED"
if diff -q "$CANARY_SOURCE" "$CANARY_DEPLOYED" >/dev/null 2>&1; then
  fail "Assertion D: staled deployed file does NOT differ from source (diff mechanics broken)"
else
  pass "Assertion D: staled deployed file correctly detected as differing from source"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
echo ""
echo "Expected-red baseline at harness authorship: Assertions A and B are RED (the two-engine"
echo "defect: load_all_globally's allow-list top-path-segment bug drops every subdirectory-"
echo "declared scripts entry on both fresh and resync deploys). A green A/B at this point in the"
echo "plan means the diagnosis is wrong -- stop and re-investigate rather than proceeding."

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
