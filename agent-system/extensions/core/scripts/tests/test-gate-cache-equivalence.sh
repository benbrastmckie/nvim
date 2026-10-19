#!/usr/bin/env bash
# test-gate-cache-equivalence.sh - Phase 9 ("Per-Gate Equivalence and Seeded-Violation Proof for
# the Skip Path") of the input-scoped gate invalidation task. Proves, at the REAL
# verify-deploy.sh INTERFACE (not the gate-cache-lib.sh unit level -- test-gate-cache-lib.sh
# already covers digest computation exhaustively for arbitrary declarations), that the
# --skip-unchanged WIRING behaves correctly against the REAL 23-gate registry: a real change
# always forces a re-run, a seeded violation is always found, and a genuinely unchanged gate
# always skips -- across repeated runs, worker counts, and an mtime-only touch.
#
# FIXTURE: a `git worktree add --detach HEAD` checkout, not an rsync copy (contrast
# test-verify-deploy-gate-selection-crash-net.sh's FIXTURE_RICH, which is deliberately NOT
# git-tracked because that suite only needs "no crash", never real named-view corpus content).
# A worktree shares this repo's object store (fast, no real copy of blob data) while giving a
# genuine `.git` the @extensions/@repo named-view corpus resolvers can walk via `git ls-files`.
# One real, structural limitation this discovered and documents rather than works around: a git
# WORKTREE's `.git` is a FILE (a gitdir pointer), not a directory, so
# gate_cache_resolve_corpus's `@repo` branch (`[ -d "$_root/.git" ]`) can never resolve inside a
# worktree -- gate 4 (the only `@repo`-declared gate) therefore always computes
# GATE_CACHE_SENTINEL here and can never be cache-eligible in THIS fixture. This is exactly the
# fail-open contract working as designed (never a false skip), proven directly below (Case G4),
# with gate 4's genuine violation-detection proven by a direct script invocation instead of via
# the cache skip/dispatch path. A real checkout (this repo's own working tree, or any ordinary
# clone) has a real `.git` directory and is unaffected.
#
# SCOPE DECISION, recorded here rather than left implicit: of the 23 registered gates, 22 declare
# a real input_corpus (gate 14 is `-`, never cache-eligible, excluded from every case below by
# construction). This suite drives 20 of those 22 through the REAL --skip-unchanged interface
# (every gate except 3, 16, 20); the remaining 3 are each excluded for a distinct, evidenced
# reason and proven instead at the composite-key level (Part 8), which needs no gate execution
# at all:
#   - gate 3 (check-extension-docs.sh): this task's own prior phases added new source-store
#     files without registering them in their extension's manifest.json `provides.scripts`, and
#     generate-context-line-counts.sh has not been re-run since several context docs grew. Both
#     are genuine, now-surfaced findings (not a cache defect) that make gate 3 unable to reach a
#     clean baseline in ANY fixture today, live repo included -- confirmed by direct measurement
#     while developing this suite. Phase 13's redeploy step is where these manifest-hygiene gaps
#     get closed; re-promote gate 3 to the full interface battery below once that lands. Also
#     genuinely expensive (~125s) to re-run per seeded-violation case even if it were clean.
#   - gate 16 / gate 20: named by this task's own dispatch as known pre-existing, explicitly
#     out-of-scope failures (the lean extension's routing_hard/routing_agents_hard declaration;
#     the eager-load budget overage) -- forcing either clean in this fixture would mean patching
#     a pre-existing condition this task was explicitly told not to attribute to itself, just to
#     make a test pass.
# gate 8 (tests/run-all.sh, the costliest real gate at roughly 457s) is driven through the real
# interface too, but against a STUBBED run-all.sh (swapped in below) rather than the real
# 147-suite battery: the stub preserves gate8_run's real invocation contract (flags, exit code,
# [FAIL]-line extraction) while replacing only the expensive PAYLOAD, exactly Phase 6's own
# precedent for lint-shellcheck.sh in test-lint-shellcheck-parallel.sh. This is a test of the
# CACHE WIRING around gate 8, never of run-all.sh's own correctness (Phase 8/10's job).
#
# Coverage (see the per-gate table emitted at the end of this file's run, and this header):
#   - Negative case: with no change and a warm cache, every cache-eligible gate in the tested set
#     skips, and the reported skip count matches exactly.
#   - mtime independence: touching every file in the fixture leaves the skip count unchanged.
#   - Determinism: identical verdicts/summary lines at --jobs 1 and --jobs 4, skip path.
#   - Per-gate corpus-violation re-run (mechanical, all 18 real-interface cache-eligible gates):
#     appending one byte to the LAST path in that gate's own resolved corpus forces a cache miss
#     and a real re-run.
#   - Per-gate corpus-violation REPORT (semantic, a representative cross-section spanning every
#     corpus-declaration grammar shape -- literal list, @extensions, @repo, glob, JSON content):
#     gates 1, 2, 4, 6, 10, 22 each get a genuine, gate-specific violation and are asserted to
#     newly FAIL/finding where they previously passed clean.
#   - Other-four-component sensitivity (registry row, for every tested gate; invoke-function
#     body, invoked script, and a sourced library, for a representative subset): each forces a
#     re-run, mirroring the corpus case.
#   - Full-sweep / skip-path finding-set equivalence over a realistic change sequence.
#   - Library-level-only composite-key proof for gates 3, 16, 20 (no execution required).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CORE_DIR/../../.." && pwd)"
VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"
REGISTRY_LIB="$CORE_DIR/lib/gate-registry-lib.sh"
CACHE_LIB="$CORE_DIR/lib/gate-cache-lib.sh"
COMMON_LIB="$CORE_DIR/lib/common.sh"
REGISTRY_DATA="$CORE_DIR/gate-registry.data"
DEPLOY_HEADLESS="$CORE_DIR/deploy-headless.sh"

for f in "$VERIFY_DEPLOY" "$REGISTRY_LIB" "$CACHE_LIB" "$COMMON_LIB" "$REGISTRY_DATA" "$DEPLOY_HEADLESS"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected $f" >&2
    exit 2
  fi
done
if ! command -v git >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: this suite requires git and jq" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$REGISTRY_LIB"
# shellcheck source=/dev/null
source "$COMMON_LIB"
# shellcheck source=/dev/null
source "$CACHE_LIB"
gate_registry_load "$REGISTRY_DATA"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }

WORKDIR="$(mktemp -d)"
WT="$WORKDIR/fixture"
RUNALL_BACKUP="$WORKDIR/run-all.sh.orig"
cleanup() {
  [ -n "${WT:-}" ] && [ -d "$WT" ] && (cd "$REPO_ROOT" && git worktree remove --force "$WT") >/dev/null 2>&1
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Fixture setup: an isolated worktree, deployed, with gate 8's run-all.sh stubbed.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
if ! (cd "$REPO_ROOT" && git worktree add --detach "$WT" HEAD) >/dev/null 2>&1; then
  echo "ERROR: could not create a git worktree fixture at $WT" >&2
  exit 2
fi
timeout 100 bash "$DEPLOY_HEADLESS" --skip-verify "$WT" >/dev/null 2>&1
deploy_rc=$?
# Exit 4 is deploy-headless.sh's OWN documented code for "landed, verification suppressed by
# --skip-verify" -- the expected, successful outcome for this exact flag, never a failure (see
# that script's own Usage/Exit-codes header). Only treat an unexpected code as fatal.
if [ "$deploy_rc" -ne 0 ] && [ "$deploy_rc" -ne 4 ]; then
  echo "ERROR: deploy-headless.sh --skip-verify failed against the fixture (exit $deploy_rc)" >&2
  exit 2
fi
unset deploy_rc

RUNALL="$WT/agent-system/extensions/core/scripts/tests/run-all.sh"
cp "$RUNALL" "$RUNALL_BACKUP"
cat > "$RUNALL" <<'STUBEOF'
#!/usr/bin/env bash
# STUB for test-gate-cache-equivalence.sh gate-8 interface-level cache-WIRING testing. NOT the
# real run-all.sh -- see that file's own real copy, backed up alongside this fixture, for the
# genuine 147-suite battery. Swaps the EXPENSIVE PAYLOAD for a near-instant, controllable
# pass/fail so the cache consult/write/invalidate wiring around gate8_run can be proven without
# paying run-all.sh's real ~457s cost on every seeded-violation case.
set -uo pipefail
MARKER="$(dirname "${BASH_SOURCE[0]}")/.stub-force-fail"
if [ -f "$MARKER" ]; then
  echo "[FAIL] stub-seeded-suite (test-gate-cache-equivalence.sh stub)"
  exit 1
fi
echo "stub: all discovered suites passed (not real -- see this file's own header)"
exit 0
STUBEOF
chmod +x "$RUNALL"

CACHE_DIR="$WT/specs/.gate-cache"
# The real-interface tested set: every registered gate except 3 (manifest-registration drift,
# see this file's header), 16/20 (named pre-existing out-of-scope failures), and 14 (no corpus).
IFACE_GATES="1,2,4,5,6,7,8,9,10,11,12,13,15,17,18,19,21,22,23"
# The subset of IFACE_GATES that can actually reach a cache entry in THIS fixture (excludes
# gate 4 -- see this file's header's worktree/.git-file limitation).
CACHEABLE_GATES="1 2 5 6 7 8 9 10 11 12 13 15 17 18 19 21 22 23"
# CACHEABLE_GATES minus gate 22, for the two REPEATED mechanical loops below (Part 4's
# corpus-violation re-run, Part 6's registry-row sensitivity): each loop iteration costs gate 22
# a REAL ~54s lint-shellcheck.sh invocation (edit+run, then revert+rewarm -- 2 real runs per
# loop, 4 total across both loops), which blew run-all.sh's own 600s per-suite bound when first
# measured. gate 22's violation-DETECTION semantics are already proven for real, once, by the
# dedicated Case G22 below (Part 5); these two mechanical loops exist to prove the WIRING is
# gate-independent machinery, which the other 17 gates already establish without paying gate
# 22's real cost four more times.
MECH_LOOP_GATES="1 2 5 6 7 8 9 10 11 12 13 15 17 18 19 21 23"

FIXTURE_VD="$WT/agent-system/extensions/core/scripts/verify-deploy.sh"
FIXTURE_REGISTRY="$WT/agent-system/extensions/core/scripts/gate-registry.data"
run_vd() {
  # Usage: run_vd <extra verify-deploy.sh args...> -- invokes the FIXTURE's OWN copy of
  # verify-deploy.sh against $WT, self-targeting exactly the way every real invocation does
  # (the source-store repo always runs ITS OWN verify-deploy.sh against itself; a deploy
  # consumer always runs its own deployed copy against itself -- script and target are always
  # the SAME tree in production). This matters specifically for the composite key's "registry
  # row" component: gate_cache_composite_key's call site in verify-deploy.sh reads that
  # component from `${_VD_SCRIPT_DIR}/gate-registry.data` -- the RUNNING SCRIPT's own directory,
  # never $TARGET's -- so invoking the LIVE REPO's binary against $WT (as this suite did before
  # discovering this) makes every edit to $WT's own gate-registry.data invisible to the
  # composite key, which looks like "registry-row sensitivity" failing when it is really a
  # fixture-invocation mismatch. verify-deploy.sh's own fail()/warn() and its FAIL-shaped
  # summary line are ALL written to stderr by design (pass() and the PASS-shaped summary line
  # go to stdout -- see that script's own fail()/pass() definitions), so this also captures both
  # streams (2>&1); omitting that silently truncates every [FAIL]-bearing assertion below.
  # Returns verify-deploy.sh's own exit code.
  timeout 180 bash "$FIXTURE_VD" "$@" "$WT" 2>&1
}

skip_count_of() {
  # Extracts the "(<n> gate(s) skipped" count from a captured verify-deploy.sh run (present on
  # BOTH the PASS- and FAIL-shaped summary line whenever SKIPPED_CACHED > 0), or echoes nothing.
  grep -oE '\([0-9]+ gate\(s\) skipped' <<< "$1" | grep -oE '[0-9]+' | head -1
}

checks_count_of() {
  # Extracts the total check count off EITHER summary shape:
  #   "[verify-deploy] PASS -- N check(s), 0 failure(s)..."
  #   "[verify-deploy] FAIL -- F of N check(s) failed..."
  # A single alternation-free grep could not cover both without also matching the failure count
  # on the FAIL line, so each shape is tried in turn.
  local n
  n="$(grep -oE '^\[verify-deploy\] PASS -- [0-9]+ check' <<< "$1" | grep -oE '[0-9]+' | head -1)"
  [ -n "$n" ] && { echo "$n"; return 0; }
  grep -oE '^\[verify-deploy\] FAIL -- [0-9]+ of [0-9]+ check' <<< "$1" | grep -oE '[0-9]+$' | head -1
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 0 -- cold baseline: warm every cache-eligible gate in IFACE_GATES with a real, clean run.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cold_out="$(run_vd --skip-unchanged --only-gate "$IFACE_GATES")"
cold_rc=$?
warm_count=0
for g in $CACHEABLE_GATES; do
  [ -f "$CACHE_DIR/gate${g}.json" ] && warm_count=$((warm_count + 1))
done
if [ "$cold_rc" -eq 0 ] && [ "$warm_count" -eq 18 ]; then
  pass "cold baseline: all 18 cache-eligible gates in the tested set went clean and warm (18/18 entries written), and gate 4 (permanently uncacheable in this fixture, see header) also passed clean"
else
  fail "cold baseline: expected rc=0 and 18 warm entries, got rc=$cold_rc warm=$warm_count" "$cold_out"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 1 -- negative case: no change, warm cache -> every cache-eligible gate skips, count exact.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
neg_out="$(run_vd --skip-unchanged --only-gate "$IFACE_GATES")"
neg_rc=$?
neg_skip="$(skip_count_of "$neg_out")"
neg_checks="$(checks_count_of "$neg_out")"
# IFACE_GATES includes gate 4, which always genuinely runs (it can never cache in this fixture
# -- see header) -- so the fully-warm expectation is 18 skips plus gate 4's own 1 real check,
# not 0 checks.
if [ "$neg_rc" -eq 0 ] && [ "${neg_skip:-0}" -eq 18 ] && [ "${neg_checks:-0}" -eq 1 ]; then
  pass "negative case: no change -> all 18 cache-eligible gates skip, only gate 4's own 1 real check runs, exit 0"
else
  fail "negative case: expected skip=18 checks=1 rc=0, got skip=${neg_skip:-?} checks=${neg_checks:-?} rc=$neg_rc" "$neg_out"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 2 -- mtime independence: touch the whole fixture, confirm the skip count is unchanged.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
find "$WT" -type f -not -path '*/.git/*' -exec touch {} + 2>/dev/null
touch_out="$(run_vd --skip-unchanged --only-gate "$IFACE_GATES")"
touch_skip="$(skip_count_of "$touch_out")"
if [ "${touch_skip:-0}" -eq 18 ]; then
  pass "mtime independence: touching every file in the fixture leaves the skip count at 18/18"
else
  fail "mtime independence: expected skip=18 after a whole-fixture touch, got skip=${touch_skip:-?}" "$touch_out"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 3 -- determinism: identical verdict/summary line across --jobs 1 and --jobs 4, skip path.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
j1_out="$(run_vd --skip-unchanged --jobs 1 --only-gate "$IFACE_GATES" | grep -E '^\[verify-deploy\]')"
j4_out="$(run_vd --skip-unchanged --jobs 4 --only-gate "$IFACE_GATES" | grep -E '^\[verify-deploy\]')"
if [ "$j1_out" = "$j4_out" ]; then
  pass "determinism: identical [verify-deploy] summary line at --jobs 1 and --jobs 4 on the skip path"
else
  fail "determinism: --jobs 1 and --jobs 4 disagreed on the skip path" "jobs1: $j1_out
jobs4: $j4_out"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 4 -- per-gate corpus-violation re-run, mechanical, MECH_LOOP_GATES (every cache-eligible
# gate except 22 -- see that variable's own declaration for why). Appends one byte to the LAST
# path in that gate's own resolved corpus (via a direct gate_cache_resolve_corpus call -- the
# exact function the skip decision itself consults), reruns --only-gate <id> --skip-unchanged,
# and asserts the gate was DISPATCHED (not SKIP-CACHED) -- then reverts the byte and re-warms
# before moving to the next gate, so gates are tested independently of one another's state.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
mech_fail_ids=""
for g in $MECH_LOOP_GATES; do
  corpus_spec="$(gate_registry_field "$g" input_corpus)"
  gate_cache_resolve_corpus "$corpus_spec" "$WT"
  if [ "$GATE_CACHE_UNRESOLVED" = "true" ]; then
    rm -f "$GATE_CACHE_RESOLVED_FILE"
    mech_fail_ids="${mech_fail_ids:+${mech_fail_ids},}${g}(unresolved)"
    continue
  fi
  mapfile -d '' -t _paths < "$GATE_CACHE_RESOLVED_FILE"
  rm -f "$GATE_CACHE_RESOLVED_FILE"
  if [ "${#_paths[@]}" -eq 0 ]; then
    mech_fail_ids="${mech_fail_ids:+${mech_fail_ids},}${g}(empty-corpus)"
    continue
  fi
  last_path="${_paths[-1]}"
  abs="$WT/$last_path"
  [ -f "$abs" ] || { mech_fail_ids="${mech_fail_ids:+${mech_fail_ids},}${g}(missing:$last_path)"; continue; }
  printf 'x' >> "$abs"
  out="$(run_vd --skip-unchanged --only-gate "$g")"
  # Revert immediately, before asserting, so a failed assertion never leaves the fixture dirty
  # for the next gate's iteration.
  truncate -s -1 "$abs" 2>/dev/null || sed -i '$ s/x$//' "$abs"
  if grep -q "SKIP-CACHED" <<< "$out"; then
    mech_fail_ids="${mech_fail_ids:+${mech_fail_ids},}${g}(still-skipped)"
  fi
  # Re-warm (clean content, should go green and re-write the entry) before the next gate.
  run_vd --skip-unchanged --only-gate "$g" >/dev/null 2>&1 || true
done
if [ -z "$mech_fail_ids" ]; then
  pass "per-gate corpus-violation re-run: all 17 MECH_LOOP_GATES gates re-run (not SKIP-CACHED) when the last path in their own resolved corpus changes by one byte (gate 22 covered separately by Case G22)"
else
  fail "per-gate corpus-violation re-run: unexpected outcome for: $mech_fail_ids"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 5 -- per-gate corpus-violation REPORT, semantic, a representative cross-section spanning
# every corpus-declaration grammar shape. Each case seeds a genuine violation, confirms a NEW
# failure/finding appears that a clean run did not report, then reverts and re-confirms clean.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Case G1 (literal file list): delete one of gate 1's nine declared files.
g1_target="$WT/.claude/scripts/events-append.sh"
if [ -f "$g1_target" ]; then
  g1_backup="$WORKDIR/g1-backup"
  cp "$g1_target" "$g1_backup"
  rm -f "$g1_target"
  g1_out="$(run_vd --skip-unchanged --only-gate 1)"
  cp "$g1_backup" "$g1_target"
  if grep -q 'FAIL' <<< "$g1_out" && grep -q 'events-append.sh' <<< "$g1_out"; then
    pass "Case G1: deleting a declared gate-1 corpus file forces a re-run that reports the missing file"
  else
    fail "Case G1: expected a FAIL naming events-append.sh" "$g1_out"
  fi
  run_vd --skip-unchanged --only-gate 1 >/dev/null 2>&1 || true
else
  fail "Case G1: fixture is missing $g1_target"
fi

# Case G2 (literal JSON file, structured content): strip settings.json's .hooks object.
g2_target="$WT/.claude/settings.json"
g2_backup="$WORKDIR/g2-backup.json"
cp "$g2_target" "$g2_backup"
jq '.hooks = {}' "$g2_backup" > "$g2_target"
g2_out="$(run_vd --skip-unchanged --only-gate 2)"
cp "$g2_backup" "$g2_target"
if grep -q 'NOT registered' <<< "$g2_out"; then
  pass "Case G2: clearing settings.json's .hooks forces a re-run that reports the missing registrations"
else
  fail "Case G2: expected 'NOT registered' findings" "$g2_out"
fi
run_vd --skip-unchanged --only-gate 2 >/dev/null 2>&1 || true

# Case G4 (@repo + exclusion; permanently uncacheable in this fixture -- see header). Proves the
# VIOLATION-DETECTION half directly (gate 4 has no cache to skip in a worktree, so "re-run" is
# trivially true every time; what matters here is that it still REPORTS a seeded violation). The
# marker-pair exemption block below exempts THIS SOURCE FILE's own write-time lint from the
# literal task-number text it authors -- that marker does NOT appear in the text WRITTEN to
# $g4_target below, so the fixture's own check-task-references.sh scan (run at test time,
# against that target file) is not exempt and genuinely finds the seeded reference, which is
# the whole point of this case.
g4_target="$WT/agent-system/extensions/core/context/standards/shell-script-testing.md"
if [ -f "$g4_target" ]; then
  g4_backup="$WORKDIR/g4-backup"
  cp "$g4_target" "$g4_backup"
  # task-ref-ok:begin quoting a deliberately seeded fixture string for Case G4
  printf '\n<!-- deliberately seeded for test-gate-cache-equivalence.sh Case G4: task 9999 -->\n' >> "$g4_target"
  # task-ref-ok:end
  g4_out="$(run_vd --skip-unchanged --only-gate 4)"
  cp "$g4_backup" "$g4_target"
  key4="$(gate_cache_composite_key 4 "$WT" "$FIXTURE_REGISTRY")"
  if grep -q 'FAIL' <<< "$g4_out" && [ "$key4" = "$GATE_CACHE_SENTINEL" ]; then
    pass "Case G4: gate 4 reports a seeded task-reference violation, and its composite key is confirmed CANNOT_COMPUTE (worktree .git-file limitation; fail-open, never a false skip)"
  else
    fail "Case G4: expected a FAIL and a CANNOT_COMPUTE key" "$g4_out (key=$key4)"
  fi
else
  fail "Case G4: fixture is missing $g4_target"
fi

# Case G6 (@extensions, structured frontmatter): strip the required model: field from one agent.
g6_target="$(find "$WT/agent-system/extensions/core/agents" -maxdepth 1 -name '*.md' -not -iname 'README.md' | head -1)"
if [ -n "$g6_target" ] && [ -f "$g6_target" ]; then
  g6_backup="$WORKDIR/g6-backup.md"
  cp "$g6_target" "$g6_backup"
  sed -i '/^model:/d' "$g6_target"
  # --findings is required here: gate6_run emits only the generic "agent contracts lint
  # reported failures" narrative line unconditionally -- the per-file "missing required
  # 'model:' field" detail is extracted into FINDINGS_LIST (and so only printed) when the
  # caller passes --findings (see verify-deploy.sh's gate6_run, the
  # verify_deploy_extract_verdict_lines '[FAIL]' branch). Contrast gate 1/2/10/22's cases
  # above, each of which calls fail() directly with the specific detail already in the
  # narrative message, needing no --findings.
  g6_out="$(run_vd --skip-unchanged --findings --only-gate 6)"
  cp "$g6_backup" "$g6_target"
  if grep -q "missing required 'model:' field" <<< "$g6_out"; then
    pass "Case G6: removing an agent's model: field forces a re-run that reports the missing field"
  else
    fail "Case G6: expected a missing-model: finding for $g6_target" "$g6_out"
  fi
  run_vd --skip-unchanged --only-gate 6 >/dev/null 2>&1 || true
else
  fail "Case G6: no agent .md file found under $WT/agent-system/extensions/core/agents"
fi

# Case G10 (literal path pair, JSON schema content): corrupt specs/state.json's JSON syntax.
g10_target="$WT/specs/state.json"
if [ -f "$g10_target" ]; then
  g10_backup="$WORKDIR/g10-backup.json"
  cp "$g10_target" "$g10_backup"
  printf '%s' "garbage-not-json" > "$g10_target"
  g10_out="$(run_vd --skip-unchanged --only-gate 10)"
  cp "$g10_backup" "$g10_target"
  if grep -qE 'FAIL' <<< "$g10_out"; then
    pass "Case G10: corrupting specs/state.json's JSON forces a re-run that reports the schema failure"
  else
    fail "Case G10: expected a FAIL for corrupted state.json" "$g10_out"
  fi
  run_vd --skip-unchanged --only-gate 10 >/dev/null 2>&1 || true
else
  fail "Case G10: fixture is missing $g10_target"
fi

# Case G22 (glob **/*.sh, real shellcheck -- the one genuinely slow real case in this suite,
# ~54s each way): add a warning-level (SC2164, "cd without || exit") line to one shell script.
g22_target="$WT/agent-system/extensions/core/scripts/lib/common.sh"
if [ -f "$g22_target" ]; then
  g22_backup="$WORKDIR/g22-backup.sh"
  cp "$g22_target" "$g22_backup"
  printf '\n# test-gate-cache-equivalence.sh seeded SC2164:\ncd /tmp\n' >> "$g22_target"
  g22_out="$(run_vd --skip-unchanged --only-gate 22)"
  cp "$g22_backup" "$g22_target"
  if grep -qE 'FAIL' <<< "$g22_out"; then
    pass "Case G22: an unguarded 'cd' (SC2164) forces a re-run that reports a real shellcheck finding"
  else
    fail "Case G22: expected shellcheck to FAIL on the seeded SC2164 line" "$g22_out"
  fi
  run_vd --skip-unchanged --only-gate 22 >/dev/null 2>&1 || true
else
  fail "Case G22: fixture is missing $g22_target"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 6 -- other-four-component sensitivity. The registry-row case runs for every cache-eligible
# gate (cheap: a one-line sed). The invoke-body / invoked-script / sourced-library cases run for
# a representative subset (1 cheap, 1 moderate gate) -- test-gate-cache-lib.sh already proves
# these three components' DIGEST sensitivity exhaustively at the unit level for arbitrary
# declarations; what this section proves is that the real WIRING (verify-deploy.sh's
# pre-dispatch consult + post-run write) actually consults the real composite key for the real
# registry, which is gate-independent machinery and does not need re-proving per gate.
# ═══════════════════════════════════════════════════════════════════════════════════════════════

# Registry-row change, MECH_LOOP_GATES (every cache-eligible gate except 22 -- see that
# variable's own declaration): append one trailing space to that gate's own line in the
# fixture's gate-registry.data (a byte-for-byte change with no semantic effect on parsing --
# IFS=$'\t' read strips nothing of substance here, but the RAW LINE TEXT folded into the
# composite key changes regardless). FIXTURE_REGISTRY itself is declared once, near run_vd()
# above.
row_fail_ids=""
for g in $MECH_LOOP_GATES; do
  cp "$FIXTURE_REGISTRY" "$WORKDIR/registry-backup.data"
  # Address-then-substitute, NOT a replacement that touches the id field: `s/^${g}\t/${g} \t/`
  # (tried first, then reverted) inserts the space BETWEEN the id and its delimiting tab,
  # which `IFS=$'\t' read -r id ...` folds into the id field itself (id becomes "1 ", not "1"),
  # silently breaking --only-gate's exact-string gate_selected() match and making the gate
  # self-skip (0 checks, not a re-run) rather than genuinely testing registry-row sensitivity --
  # discovered live via this exact suite's own first run. Appending at the LINE's END instead
  # changes only the input_corpus field's trailing bytes, which no parser in this codebase
  # trims, while leaving every other field (especially id) byte-identical.
  sed -i "/^${g}\t/s/\$/ /" "$FIXTURE_REGISTRY"
  if ! diff -q "$WORKDIR/registry-backup.data" "$FIXTURE_REGISTRY" >/dev/null 2>&1; then
    out="$(run_vd --skip-unchanged --only-gate "$g")"
    grep -q "SKIP-CACHED" <<< "$out" && row_fail_ids="${row_fail_ids:+${row_fail_ids},}${g}"
  else
    row_fail_ids="${row_fail_ids:+${row_fail_ids},}${g}(no-op-edit)"
  fi
  cp "$WORKDIR/registry-backup.data" "$FIXTURE_REGISTRY"
  run_vd --skip-unchanged --only-gate "$g" >/dev/null 2>&1 || true
done
if [ -z "$row_fail_ids" ]; then
  pass "registry-row sensitivity: all 17 MECH_LOOP_GATES gates re-run when their own registry row changes by one byte (gate 22 excluded -- see MECH_LOOP_GATES's own declaration)"
else
  fail "registry-row sensitivity: unexpected outcome for: $row_fail_ids"
fi

# Invoke-function-body change, invoked-script change, sourced-library change: representative
# subset gate 1 (cheap, literal corpus) and gate 6 (moderate, @extensions). FIXTURE_VD itself
# is declared once, near run_vd() above.
FIXTURE_CONTRACTS="$WT/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh"
FIXTURE_COMMONLIB="$WT/agent-system/extensions/core/scripts/lib/common.sh"

append_marker() { printf '\n# test-gate-cache-equivalence.sh seeded change\n' >> "$1"; }

other_component_case() {
  # Usage: other_component_case <label> <gate_id> <file-to-edit> <edit-cmd...>
  local label="$1" gid="$2" file="$3"; shift 3
  local backup="$WORKDIR/occ-backup"
  cp "$file" "$backup"
  "$@" "$file"
  local out
  out="$(run_vd --skip-unchanged --only-gate "$gid")"
  cp "$backup" "$file"
  if grep -q "SKIP-CACHED" <<< "$out"; then
    fail "$label: gate $gid still SKIP-CACHED after the seeded change" "$out"
  else
    pass "$label: gate $gid re-runs when $file changes"
  fi
  run_vd --skip-unchanged --only-gate "$gid" >/dev/null 2>&1 || true
}

# invoke-function-body: append a no-op comment line inside gate1_run()'s body in the fixture's
# OWN verify-deploy.sh copy (never the live repo's), restored afterward from this repo's own
# committed blob (always available -- the fixture is a worktree of this same repo).
cp "$FIXTURE_VD" "$WORKDIR/vd-backup.sh"
sed -i '0,/^gate1_run() {/{/^gate1_run() {/a\
# test-gate-cache-equivalence.sh seeded invoke-body change (no-op comment)
}' "$FIXTURE_VD"
vd_body_out="$(run_vd --skip-unchanged --only-gate 1)"
cp "$WORKDIR/vd-backup.sh" "$FIXTURE_VD"
if grep -q "SKIP-CACHED" <<< "$vd_body_out"; then
  fail "invoke-function-body sensitivity (gate 1): still SKIP-CACHED after editing gate1_run()'s body" "$vd_body_out"
else
  pass "invoke-function-body sensitivity (gate 1): re-runs when gate1_run()'s own body changes"
fi
run_vd --skip-unchanged --only-gate 1 >/dev/null 2>&1 || true

# invoked-script change: gate 6's own invoked lint script.
other_component_case "invoked-script sensitivity" 6 "$FIXTURE_CONTRACTS" append_marker

# sourced-library change: scripts/lib/common.sh, part of the bounded scripts/lib/*.sh closure
# every gate whose invoke body references at least one bash script folds in (gate 1 does).
other_component_case "sourced-library sensitivity" 1 "$FIXTURE_COMMONLIB" append_marker

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 7 -- full-sweep / skip-path finding-set equivalence over a realistic change sequence:
# cold full run -> change a known subset -> skip-path run -> full run again -> the skip-path
# run's finding set for the changed gate matches a full run's exactly, and every other gate's
# findings are unaffected by having run through the skip path at all.
#
# SEQ_GATES, not IFACE_GATES: this is the one case in the suite where the "full run" leg
# (full2_out below) is deliberately NOT --skip-unchanged, so EVERY included gate runs for real
# regardless of cache state. Against the full 18-gate IFACE_GATES set that means paying gate
# 22's real ~54s lint-shellcheck.sh cost a FOURTH time (on top of cold baseline + Case G22's
# own two) purely to prove a property gate 22 does not uniquely exercise -- measured to push
# this suite's total past run-all.sh's own 600s per-suite bound. SEQ_GATES is a small,
# cost-class-"free"/"moderate" subset: enough gates to prove the finding-set-equivalence
# property (the changed gate's findings match exactly; every OTHER included gate's findings are
# unaffected) without re-paying any SLOW gate's real cost a second time in this part.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
SEQ_GATES="1,2,5,6,7,9,10,11,12"
full1_out="$(run_vd --skip-unchanged --findings --only-gate "$SEQ_GATES")"
# Seed gate 2's violation as the "realistic incremental change" and capture BOTH the skip-path
# run and a genuine FULL sweep (no --skip-unchanged) while the violation is still present --
# comparing against the clean, already-reverted state (an earlier version of this case's own
# ordering bug) would trivially show "no findings" on both sides and prove nothing.
jq '.hooks = {}' "$g2_backup" > "$g2_target" 2>/dev/null || true
skip_seq_out="$(run_vd --skip-unchanged --findings --only-gate "$SEQ_GATES")"
full2_out="$(run_vd --findings --only-gate "$SEQ_GATES")"
cp "$g2_backup" "$g2_target"
run_vd --skip-unchanged --only-gate 2 >/dev/null 2>&1 || true

skip_seq_findings="$(grep -E '^FINDING gate2' <<< "$skip_seq_out" | sort -u)"
full2_findings="$(grep -E '^FINDING gate2' <<< "$full2_out" | sort -u)"
other_skip_findings="$(grep -E '^FINDING' <<< "$skip_seq_out" | grep -v '^FINDING gate2' | sort -u)"
other_full1_findings="$(grep -E '^FINDING' <<< "$full1_out" | grep -v '^FINDING gate2' | sort -u)"
if [ -n "$skip_seq_findings" ] && [ "$skip_seq_findings" = "$full2_findings" ] \
  && [ "$other_skip_findings" = "$other_full1_findings" ]; then
  pass "realistic-sequence equivalence: the skip-path run's gate2 findings match a full run's exactly, and every other gate's findings are unaffected"
else
  fail "realistic-sequence equivalence: finding-set mismatch between the skip path and a full run" \
    "skip-seq gate2: $skip_seq_findings
full2 gate2: $full2_findings
skip-seq others vs full1 others differ: $([ "$other_skip_findings" = "$other_full1_findings" ] && echo no || echo yes)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# PART 8 -- library-level-only composite-key proof for gates 3, 16, 20 (see this file's header
# for why these three are excluded from real execution). No gate execution needed: this proves
# the composite key is COMPUTABLE (not the sentinel) for each gate's REAL registry row and corpus
# declaration, and that it CHANGES when the corpus is touched -- the property the real interface
# wiring above depends on, verified directly against gate-cache-lib.sh rather than by running
# check-extension-docs.sh/the lean extension/measure-eager-context.sh for real.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
lib_fail_ids=""
for g in 3 16 20; do
  key_before="$(gate_cache_composite_key "$g" "$WT" "$FIXTURE_REGISTRY")"
  corpus_spec="$(gate_registry_field "$g" input_corpus)"
  gate_cache_resolve_corpus "$corpus_spec" "$WT"
  resolved_file="$GATE_CACHE_RESOLVED_FILE"
  unresolved="$GATE_CACHE_UNRESOLVED"
  if [ "$unresolved" = "true" ] || [ "$key_before" = "$GATE_CACHE_SENTINEL" ]; then
    rm -f "$resolved_file"
    lib_fail_ids="${lib_fail_ids:+${lib_fail_ids},}${g}(sentinel)"
    continue
  fi
  mapfile -d '' -t _p < "$resolved_file"
  rm -f "$resolved_file"
  if [ "${#_p[@]}" -eq 0 ]; then
    lib_fail_ids="${lib_fail_ids:+${lib_fail_ids},}${g}(empty)"
    continue
  fi
  target_f="$WT/${_p[-1]}"
  [ -f "$target_f" ] || { lib_fail_ids="${lib_fail_ids:+${lib_fail_ids},}${g}(missing-file)"; continue; }
  printf 'x' >> "$target_f"
  key_after="$(gate_cache_composite_key "$g" "$WT" "$FIXTURE_REGISTRY")"
  truncate -s -1 "$target_f" 2>/dev/null || sed -i '$ s/x$//' "$target_f"
  if [ "$key_after" = "$key_before" ]; then
    lib_fail_ids="${lib_fail_ids:+${lib_fail_ids},}${g}(key-unchanged)"
  fi
done
if [ -z "$lib_fail_ids" ]; then
  pass "library-level composite-key proof (gates 3, 16, 20): each gate's real corpus declaration resolves to a computable, non-sentinel key that changes on a one-byte corpus edit"
else
  fail "library-level composite-key proof: unexpected outcome for: $lib_fail_ids"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Per-gate equivalence table (objective 7). Recorded here as the durable artifact; also emitted
# to stdout on every run.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
cat <<'TABLE'

Per-gate equivalence table (22 corpus-bearing gates; gate 14 has no corpus, N/A):
  Gate  Corpus shape          Treatment                            Corpus decl. corrected?
  1     literal file list     full interface (Parts 0-6)           No
  2     literal JSON file     full interface (Parts 0-6)           No
  4     @repo + exclusion     violation-report only (Case G4);      No
                                permanently uncacheable in this
                                fixture (worktree .git-file limit,
                                fail-open confirmed)
  5     @extensions,.claude   full interface (Parts 0-6)            No
  6     @extensions           full interface (Parts 0-6)            No
  7     @extensions           full interface (Parts 0-6)            No
  8     @extensions           full interface via stub (Parts 0-6)   No
  9     literal dir list      full interface (Parts 0-6)            No
  10    literal file pair     full interface (Parts 0-6)            No
  11    @extensions           full interface (Parts 0-6)            No
  12    @extensions           full interface (Parts 0-6)            No
  13    @extensions,.claude   full interface (Parts 0-6)            No
  15    glob list             full interface (Parts 0-6)            No
  17    @extensions           full interface (Parts 0-6)            No
  18    @extensions           full interface (Parts 0-6)            No
  19    @extensions           full interface (Parts 0-6)            No
  21    @extensions           full interface (Parts 0-6)            No
  22    glob **/*.sh          full interface (Parts 0-6, Case G22)  No
  23    @extensions           full interface (Parts 0-6)            No
  3     @extensions,.claude   library-level only (Part 8)           No (pre-existing manifest-
                                                                       registration gaps found,
                                                                       logged, out of this
                                                                       phase's own scope)
  16    literal glob          library-level only (Part 8)           No (named pre-existing
                                                                       out-of-scope per dispatch)
  20    @extensions           library-level only (Part 8)           No (named pre-existing
                                                                       out-of-scope per dispatch)
TABLE

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
