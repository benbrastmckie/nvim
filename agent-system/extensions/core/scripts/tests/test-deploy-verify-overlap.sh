#!/usr/bin/env bash
# test-deploy-verify-overlap.sh - Scratch-tree regression harness for cross-extension
# content-hash ownership resolution (verify.lua's M.build_ownership_map and the owner-gated
# M.verify_manifest_category, consumed via init.lua's manager.verify/manager.verify_all and
# verify-deploy.sh gate 5). Locks in the three behaviors the owner-resolution fix guarantees:
# an overlapping path verifies clean against its resolved owner, genuine content drift on that
# same path still fires exactly once (attributed to the owner, never duplicated under a
# non-owner), and a single-owner path's hash-mismatch detection is completely unaffected.
#
# Structural model: test-deploy-orphans.sh (pass()/fail()/info() helpers, PASSED/FAILED integer
# counters, a trap-based scratch WORKDIR, exit 0/1/2 convention). Unlike that harness, this one
# does NOT run a real deploy-headless.sh deploy: `M.build_ownership_map` and
# `M.verify_manifest_category` are exposed "for the scratch-tree regression harness / direct
# inspection" specifically so a hermetic, fast two-extension scenario can be planted directly --
# two synthetic extension source trees plus a synthetic deployed tree, all under one scratch
# WORKDIR, with no real extension, no git repo, and no nvim config bootstrap beyond requiring the
# one Lua module under test.
#
# Source resolution: like test-deploy-orphans.sh, the Lua module under test
# (neotex.plugins.ai.shared.extensions.verify) always resolves from the real ~/.config/nvim
# runtimepath regardless of the headless nvim's cwd -- only the synthetic extension/target
# directories passed into the module's functions live under the scratch WORKDIR.
#
# Scenario (three categories, each isolated so one assertion's expected counts never leak into
# another's):
#   - "context": both ext-a and ext-b declare "overlap.md" with DIFFERENT content -- the single
#     overlapping leaf Assertions A and B exercise. ext-b is deploy-order-later (mirrors
#     `manager.compute_deploy_order`'s "later wins" rule), so it resolves as owner.
#   - "docs": both declare directory entry "shared-dir", but ext-a's copy contains an EXTRA file
#     ("file2.md") ext-b does not ship -- the per-leaf-granularity leaf Assertion D exercises.
#   - "templates": only ext-a declares "solo.md" -- the single-owner leaf Assertion C exercises.
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (nvim not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

if ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: nvim not found on PATH; cannot run the Lua module under test." >&2
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

EXT_A="$WORKDIR/ext-a"
EXT_B="$WORKDIR/ext-b"
TARGET="$WORKDIR/target"

mkdir -p "$EXT_A/context" "$EXT_A/docs/shared-dir" "$EXT_A/templates"
mkdir -p "$EXT_B/context" "$EXT_B/docs/shared-dir"
mkdir -p "$TARGET/context" "$TARGET/docs/shared-dir" "$TARGET/templates"

cat > "$EXT_A/manifest.json" <<'JSON'
{
  "name": "ext-a",
  "version": "0.0.1",
  "provides": {
    "context": ["overlap.md"],
    "docs": ["shared-dir"],
    "templates": ["solo.md"]
  }
}
JSON

cat > "$EXT_B/manifest.json" <<'JSON'
{
  "name": "ext-b",
  "version": "0.0.1",
  "dependencies": ["ext-a"],
  "provides": {
    "context": ["overlap.md"],
    "docs": ["shared-dir"]
  }
}
JSON

printf 'A overlap content\n' > "$EXT_A/context/overlap.md"
printf 'B overlap content\n' > "$EXT_B/context/overlap.md"
printf 'A shared file1\n' > "$EXT_A/docs/shared-dir/file1.md"
printf 'A-only file2\n' > "$EXT_A/docs/shared-dir/file2.md"
printf 'B shared file1\n' > "$EXT_B/docs/shared-dir/file1.md"
printf 'A solo content\n' > "$EXT_A/templates/solo.md"

# Clean baseline deploy matching the resolved owners: ext-b (deploy-order-later) owns
# "context/overlap.md" and "docs/shared-dir/file1.md"; ext-a is sole declarer (hence owner) of
# "docs/shared-dir/file2.md" and "templates/solo.md".
printf 'B overlap content\n' > "$TARGET/context/overlap.md"
printf 'B shared file1\n' > "$TARGET/docs/shared-dir/file1.md"
printf 'A-only file2\n' > "$TARGET/docs/shared-dir/file2.md"
printf 'A solo content\n' > "$TARGET/templates/solo.md"

LUA_PRELUDE="
local json = vim.json
local function read_manifest(path)
  local f = io.open(path, 'r')
  local content = f:read('*all')
  f:close()
  return json.decode(content)
end
local verify_mod = require('neotex.plugins.ai.shared.extensions.verify')
local EXT_A = '$EXT_A'
local EXT_B = '$EXT_B'
local TARGET = '$TARGET'
local ext_a = { name = 'ext-a', source_dir = EXT_A, manifest = read_manifest(EXT_A .. '/manifest.json') }
local ext_b = { name = 'ext-b', source_dir = EXT_B, manifest = read_manifest(EXT_B .. '/manifest.json') }
-- Already-ordered deploy-order array: ext-a first, ext-b second (mirrors
-- manager.compute_deploy_order's 'later wins' rule without depending on that function).
local map = verify_mod.build_ownership_map({ ext_a, ext_b }, TARGET, {})
local function dump(tag, res)
  print(tag .. ' hash_mismatch=' .. #res.hash_mismatch .. ' overridden=' .. #res.overridden)
  for _, rel in ipairs(res.hash_mismatch) do
    print('  ' .. tag .. ' HASH_MISMATCH ' .. rel)
  end
  for _, o in ipairs(res.overridden) do
    print('  ' .. tag .. ' OVERRIDDEN ' .. o.rel_path .. ' owner=' .. o.owner)
  end
end
"

run_lua() {
  local body="$1"
  (cd "$REPO_ROOT" && nvim --headless -c "lua ${LUA_PRELUDE} ${body}" -c "qa!" 2>&1)
}

# =====================================================================
# Round 1 (clean baseline): Assertion A (overlap clean), Assertion C's clean half, and
# Assertion D's clean half, all against the untouched scratch tree set up above.
# =====================================================================
info "Round 1: clean baseline (Assertions A, C-clean, D-clean)"
round1_output="$(run_lua "
dump('A_CTX_A', verify_mod.verify_manifest_category('context', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
dump('A_CTX_B', verify_mod.verify_manifest_category('context', ext_b.manifest, ext_b.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-b' }))
dump('C_TPL_A', verify_mod.verify_manifest_category('templates', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
dump('D_DOCS_A', verify_mod.verify_manifest_category('docs', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
dump('D_DOCS_B', verify_mod.verify_manifest_category('docs', ext_b.manifest, ext_b.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-b' }))
")"

if echo "$round1_output" | grep -qE 'E[0-9]+:|Error'; then
  echo "ERROR: round 1 Lua call reported an error:" >&2
  echo "$round1_output" | sed 's/^/    /' >&2
  exit 2
fi

# Assertion A: overlap clean. ext-a sees overlap.md as overridden (owner ext-b), zero
# hash_mismatch. ext-b sees zero hash_mismatch, zero overridden (it owns everything it declares).
if echo "$round1_output" | grep -q 'A_CTX_A hash_mismatch=0 overridden=1' \
  && echo "$round1_output" | grep -qF 'A_CTX_A OVERRIDDEN context/overlap.md owner=ext-b'; then
  pass "Assertion A: ext-a's overlapping declaration of context/overlap.md reports zero hash_mismatch and exactly one overridden entry naming ext-b"
else
  fail "Assertion A: unexpected ext-a context result (expected hash_mismatch=0, one overridden entry naming ext-b):"
  echo "$round1_output" | grep 'A_CTX_A' | sed 's/^/    /'
fi
if echo "$round1_output" | grep -q 'A_CTX_B hash_mismatch=0 overridden=0'; then
  pass "Assertion A: ext-b (the resolved owner) reports zero hash_mismatch and zero overridden for context/overlap.md"
else
  fail "Assertion A: unexpected ext-b context result (expected hash_mismatch=0, overridden=0):"
  echo "$round1_output" | grep 'A_CTX_B' | sed 's/^/    /'
fi

# Assertion C (clean half): single-owner templates/solo.md, matching deploy, zero findings.
if echo "$round1_output" | grep -q 'C_TPL_A hash_mismatch=0 overridden=0'; then
  pass "Assertion C (clean): single-owner templates/solo.md with a matching deploy reports zero findings"
else
  fail "Assertion C (clean): unexpected result (expected hash_mismatch=0, overridden=0):"
  echo "$round1_output" | grep 'C_TPL_A' | sed 's/^/    /'
fi

# Assertion D (clean half): ext-a hash-compares its own docs/shared-dir/file2.md (ext-b does not
# ship it) and it never appears in overridden; docs/shared-dir/file1.md IS overridden (owner
# ext-b). ext-b reports zero findings for its own declaration.
if echo "$round1_output" | grep -q 'D_DOCS_A hash_mismatch=0 overridden=1' \
  && echo "$round1_output" | grep -qF 'D_DOCS_A OVERRIDDEN docs/shared-dir/file1.md owner=ext-b' \
  && ! echo "$round1_output" | grep -qF 'D_DOCS_A OVERRIDDEN docs/shared-dir/file2.md'; then
  pass "Assertion D (clean): ext-a's docs/shared-dir/file2.md (ext-b does not ship it) hash-compares cleanly and is never in overridden; file1.md is overridden naming ext-b"
else
  fail "Assertion D (clean): unexpected ext-a docs result:"
  echo "$round1_output" | grep 'D_DOCS_A' | sed 's/^/    /'
fi
if echo "$round1_output" | grep -q 'D_DOCS_B hash_mismatch=0 overridden=0'; then
  pass "Assertion D (clean): ext-b (owner of docs/shared-dir/file1.md) reports zero findings"
else
  fail "Assertion D (clean): unexpected ext-b docs result (expected hash_mismatch=0, overridden=0):"
  echo "$round1_output" | grep 'D_DOCS_B' | sed 's/^/    /'
fi

# =====================================================================
# Round 2 (planted drift): stale context/overlap.md to a value matching NEITHER declarer (for
# Assertion B), append a line to templates/solo.md (Assertion C's staled half), and append a line
# to docs/shared-dir/file2.md (Assertion D's staled half). Re-run against the SAME ownership map
# (the source trees, and therefore ownership resolution, are unchanged -- only deployed content is
# staled).
# =====================================================================
info "Round 2: planted drift (Assertion B, C-staled, D-staled)"
printf 'NEITHER declarer content\n' > "$TARGET/context/overlap.md"
printf 'A solo content\nstaled appended line\n' > "$TARGET/templates/solo.md"
printf 'A-only file2\nstaled appended line\n' > "$TARGET/docs/shared-dir/file2.md"

round2_output="$(run_lua "
dump('B_CTX_B', verify_mod.verify_manifest_category('context', ext_b.manifest, ext_b.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-b' }))
dump('B_CTX_A', verify_mod.verify_manifest_category('context', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
dump('C_TPL_A_STALED', verify_mod.verify_manifest_category('templates', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
dump('D_DOCS_A_STALED', verify_mod.verify_manifest_category('docs', ext_a.manifest, ext_a.source_dir, TARGET, {}, { ownership = map, extension_name = 'ext-a' }))
")"

if echo "$round2_output" | grep -qE 'E[0-9]+:|Error'; then
  echo "ERROR: round 2 Lua call reported an error:" >&2
  echo "$round2_output" | sed 's/^/    /' >&2
  exit 2
fi

# Assertion B: genuine drift still fires, exactly once, attributed to the owner (ext-b), never
# duplicated under the non-owner (ext-a).
if echo "$round2_output" | grep -q 'B_CTX_B hash_mismatch=1 overridden=0' \
  && echo "$round2_output" | grep -qF 'B_CTX_B HASH_MISMATCH context/overlap.md'; then
  pass "Assertion B: staled context/overlap.md fires exactly one hash_mismatch under ext-b (the owner)"
else
  fail "Assertion B: unexpected ext-b context result (expected one hash_mismatch for context/overlap.md):"
  echo "$round2_output" | grep 'B_CTX_B' | sed 's/^/    /'
fi
if echo "$round2_output" | grep -q 'B_CTX_A hash_mismatch=0 overridden=1' \
  && echo "$round2_output" | grep -qF 'B_CTX_A OVERRIDDEN context/overlap.md owner=ext-b'; then
  pass "Assertion B: the same drift is NOT duplicated under ext-a (non-owner) -- it stays an overridden entry, never a hash_mismatch"
else
  fail "Assertion B: unexpected ext-a context result (expected zero hash_mismatch, overlap.md still overridden):"
  echo "$round2_output" | grep 'B_CTX_A' | sed 's/^/    /'
fi

# Assertion C (staled half): single-owner templates/solo.md now fires exactly one hash_mismatch,
# with zero overridden entries (no regression in real divergence detection).
if echo "$round2_output" | grep -q 'C_TPL_A_STALED hash_mismatch=1 overridden=0' \
  && echo "$round2_output" | grep -qF 'C_TPL_A_STALED HASH_MISMATCH templates/solo.md'; then
  pass "Assertion C (staled): single-owner templates/solo.md fires exactly one hash_mismatch with zero overridden entries"
else
  fail "Assertion C (staled): unexpected result (expected one hash_mismatch for templates/solo.md, zero overridden):"
  echo "$round2_output" | grep 'C_TPL_A_STALED' | sed 's/^/    /'
fi

# Assertion D (staled half): staling ext-a's own-owned docs/shared-dir/file2.md fires exactly one
# hash_mismatch attributed to ext-a, and it never appears in overridden (per-leaf granularity --
# the shared directory entry does not drag file2.md into ext-b's ownership).
if echo "$round2_output" | grep -q 'D_DOCS_A_STALED hash_mismatch=1 overridden=1' \
  && echo "$round2_output" | grep -qF 'D_DOCS_A_STALED HASH_MISMATCH docs/shared-dir/file2.md' \
  && echo "$round2_output" | grep -qF 'D_DOCS_A_STALED OVERRIDDEN docs/shared-dir/file1.md owner=ext-b' \
  && ! echo "$round2_output" | grep -qF 'D_DOCS_A_STALED OVERRIDDEN docs/shared-dir/file2.md'; then
  pass "Assertion D (staled): ext-a-only docs/shared-dir/file2.md fires exactly one hash_mismatch and never appears in overridden (per-leaf granularity holds)"
else
  fail "Assertion D (staled): unexpected ext-a docs result:"
  echo "$round2_output" | grep 'D_DOCS_A_STALED' | sed 's/^/    /'
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
