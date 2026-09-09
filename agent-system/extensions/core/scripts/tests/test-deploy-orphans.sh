#!/usr/bin/env bash
# test-deploy-orphans.sh - Scratch-tree regression harness for whole-tree orphan detection
# (verify.lua's M.find_orphans, exposed via init.lua's manager.find_orphans and verify-deploy.sh
# gate 13). Proves the gate fires on a planted orphan and a planted ghost index row, and stays
# silent on each documented exclusion class -- see
# context/patterns/deploy-orphan-detection.md for the exclusion contract this harness exercises.
#
# Structural model: test-deploy-propagation.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, a trap-based scratch WORKDIR, real deploy-headless.sh subprocess, exit
# 0/1/2 convention). This harness additionally plants files directly into the scratch deploy
# tree after the real deploy completes, then re-invokes manager.find_orphans via a headless nvim
# subprocess (mirroring gate 13's own invocation shape in verify-deploy.sh) to check the planted
# set is classified correctly.
#
# Source resolution: like test-deploy-propagation.sh, the Lua module under test
# (neotex.plugins.ai.shared.extensions.*) always resolves from the real ~/.config/nvim
# runtimepath regardless of the headless nvim's cwd -- only the TARGET project directory passed
# to manager.find_orphans is the scratch tree. This is deliberately hermetic on the TARGET side
# (a fresh git repo under mktemp, discarded on exit) even though the SOURCE/runtime side is the
# live checkout, matching every other scratch-tree harness in this suite.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (deploy-headless.sh or nvim not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
  echo "ERROR: nvim not found on PATH; cannot run the real headless deploy / find_orphans." >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH; cannot plant a ghost context/index.json row." >&2
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
# propagation / orphan detection).
# shellcheck disable=SC1090,SC1091
. "${SCRIPT_DIR}/../lib/runtime-file-patterns.sh"
runtime_ignore_block > "$TARGET/.gitignore"
git -C "$TARGET" -c user.email="test@test.local" -c user.name="deploy-orphans-test" \
  commit -q --allow-empty -m "scratch init"

info "Deploying real core manifest into scratch tree $TARGET"
deploy_output="$(bash "$DEPLOY_SCRIPT" "$TARGET" 2>&1)"
deploy_status=$?
if [[ "$deploy_status" -ne 0 ]]; then
  echo "ERROR: deploy-headless.sh exited $deploy_status (expected 0). Output:" >&2
  echo "$deploy_output" | sed 's/^/    /' >&2
  exit 2
fi

# Runs manager.find_orphans(TARGET) via a headless nvim subprocess and prints the SAME tokens
# gate 13 in verify-deploy.sh emits (ORPHAN_FINDING/ORPHAN_ERROR/ORPHAN_DONE), so this harness
# exercises the identical code path the real gate runs, not a parallel hand-rolled call.
run_find_orphans() {
  cd "$REPO_ROOT" && nvim --headless \
    -c "lua local ok1, ext_config = pcall(require, 'neotex.plugins.ai.shared.extensions.config'); local ok2, ext_init = pcall(require, 'neotex.plugins.ai.shared.extensions.init'); if not (ok1 and ok2) then print('ORPHAN_ERROR require: ' .. tostring(ok1 and ext_init or ext_config)) else local manager = ext_init.create(ext_config.claude()); local pok, result = pcall(manager.find_orphans, '${TARGET}'); if not pok then print('ORPHAN_ERROR call: ' .. tostring(result)) else for _, rel in ipairs(result.orphans) do print('ORPHAN_FINDING orphan file: ' .. rel) end for _, path in ipairs(result.ghost_index_entries) do print('ORPHAN_FINDING ghost index row: ' .. path) end print('ORPHAN_DONE checked=' .. tostring(result.checked)) end end" \
    -c "qa!" 2>&1
}

# =====================================================================
# Assertion E (no-false-positive baseline): an unmodified scratch regenerate reports zero
# orphans and zero ghost rows. Run FIRST, before any planting, so a failure here means the
# detector itself is miscalibrated against a clean deploy rather than reacting to this harness's
# own plants.
# =====================================================================
info "Assertion E: unmodified scratch regenerate baseline"
baseline_output="$(run_find_orphans)"
if echo "$baseline_output" | grep -q 'ORPHAN_ERROR'; then
  fail "Assertion E: find_orphans could not run: $(echo "$baseline_output" | grep 'ORPHAN_ERROR' | head -1)"
elif ! echo "$baseline_output" | grep -q 'ORPHAN_DONE'; then
  fail "Assertion E: find_orphans produced no result"
else
  baseline_finding_count=$(echo "$baseline_output" | grep -c 'ORPHAN_FINDING ')
  if [[ "$baseline_finding_count" -eq 0 ]]; then
    pass "Assertion E: unmodified scratch regenerate reports zero orphans and zero ghost rows"
  else
    fail "Assertion E: unmodified scratch regenerate reported $baseline_finding_count finding(s) (expected 0):"
    echo "$baseline_output" | grep 'ORPHAN_FINDING ' | sed 's/^/    /'
  fi
fi

# =====================================================================
# Plant the four scenarios covering Assertions A/B/C/D, then run find_orphans ONCE more so all
# four are checked against a single consistent snapshot.
# =====================================================================

# A: a file under a declared category directory (scripts/) but absent from every manifest.
CANARY_ORPHAN_REL="scripts/orphan-test-canary.sh"
mkdir -p "$(dirname "$TARGET/.claude/$CANARY_ORPHAN_REL")"
cat > "$TARGET/.claude/$CANARY_ORPHAN_REL" <<'EOF'
#!/usr/bin/env bash
# Planted by test-deploy-orphans.sh -- not declared by any manifest.
echo "orphan canary"
EOF

# B: a runtime-artifact-shaped path (tmp/workflow-active-*) -- must NOT be reported.
mkdir -p "$TARGET/.claude/tmp"
echo "planted runtime artifact" > "$TARGET/.claude/tmp/workflow-active-test-canary"

# C: context/index.json itself is already present from the real deploy (a merged/generated
# artifact) -- no additional planting needed, only the negative assertion below.

# D: inject a ghost row into context/index.json with no corresponding index-entries.json
# declaration anywhere in the source store.
INDEX_JSON="$TARGET/.claude/context/index.json"
if [[ ! -f "$INDEX_JSON" ]]; then
  echo "ERROR: expected context/index.json at $INDEX_JSON after deploy; cannot plant ghost row." >&2
  exit 2
fi
GHOST_PATH="orphan-test-ghost.md"
tmp_index="$(mktemp)"
jq --arg p "$GHOST_PATH" \
  '.entries += [{"path": $p, "domain": "test", "subdomain": "test", "summary": "planted ghost row", "line_count": 1, "keywords": [], "topics": [], "load_when": {"agents": [], "task_types": []}}]' \
  "$INDEX_JSON" > "$tmp_index"
if jq -e . "$tmp_index" >/dev/null 2>&1; then
  mv "$tmp_index" "$INDEX_JSON"
else
  echo "ERROR: planted context/index.json failed to parse as JSON; aborting." >&2
  rm -f "$tmp_index"
  exit 2
fi

info "Re-running find_orphans against the planted scratch tree"
planted_output="$(run_find_orphans)"

if echo "$planted_output" | grep -q 'ORPHAN_ERROR'; then
  fail "Assertions A/B/C/D: find_orphans could not run: $(echo "$planted_output" | grep 'ORPHAN_ERROR' | head -1)"
elif ! echo "$planted_output" | grep -q 'ORPHAN_DONE'; then
  fail "Assertions A/B/C/D: find_orphans produced no result"
else
  # Assertion A: the planted orphan file IS reported.
  if echo "$planted_output" | grep -qF "ORPHAN_FINDING orphan file: $CANARY_ORPHAN_REL"; then
    pass "Assertion A: planted orphan '$CANARY_ORPHAN_REL' reported"
  else
    fail "Assertion A: planted orphan '$CANARY_ORPHAN_REL' NOT reported (expected orphan finding)"
  fi

  # Assertion B: the runtime-artifact path is NOT reported.
  if echo "$planted_output" | grep -qF "ORPHAN_FINDING orphan file: tmp/workflow-active-test-canary"; then
    fail "Assertion B: runtime artifact 'tmp/workflow-active-test-canary' WAS reported (should be excluded)"
  else
    pass "Assertion B: runtime artifact 'tmp/workflow-active-test-canary' correctly excluded"
  fi

  # Assertion C: the merged/generated artifact context/index.json is NOT reported.
  if echo "$planted_output" | grep -qF "ORPHAN_FINDING orphan file: context/index.json"; then
    fail "Assertion C: merged/generated artifact 'context/index.json' WAS reported (should be excluded)"
  else
    pass "Assertion C: merged/generated artifact 'context/index.json' correctly excluded"
  fi

  # Assertion D: the planted ghost index row IS reported.
  if echo "$planted_output" | grep -qF "ORPHAN_FINDING ghost index row: $GHOST_PATH"; then
    pass "Assertion D: planted ghost index row '$GHOST_PATH' reported"
  else
    fail "Assertion D: planted ghost index row '$GHOST_PATH' NOT reported (expected ghost-index finding)"
  fi
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
