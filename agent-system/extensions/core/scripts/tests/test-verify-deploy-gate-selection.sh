#!/usr/bin/env bash
# test-verify-deploy-gate-selection.sh - Regression suite for verify-deploy.sh's --only-gate
# gate-selection flag (GATES_FILTER / gate_selected()): the additive, opt-in mechanism that lets a
# caller run one gate (or a named set) instead of the full registered-gate battery.
#
# Structural model: test-verify-deploy-context-budget.sh (pass()/fail()/info() helpers, PASSED/
# FAILED counters, mktemp WORKDIR with trap EXIT cleanup, real-copy rsync fixture, git-init).
# Every verify-deploy.sh invocation below passes --skip-slow -- this is a hard requirement, not a
# style choice: without it, `--only-gate 8` (or a no-flag run) would recurse into gate 8's own
# tests/run-all.sh, which is precisely the suite that discovers and runs THIS FILE (the same
# ANTI-RECURSION INVARIANT test-deploy-verify-wiring.sh documents for itself).
#
# This suite deliberately invokes the SOURCE-STORE copy of verify-deploy.sh directly
# ($CORE_DIR/verify-deploy.sh), never the deployed .claude/ copy -- the --only-gate flag it tests
# exists only in the source store until this task's Phase 7 redeploy (see
# context/rules/source-store-deploy-boundary.md and this task's own plan Risks table).
#
# Case (s) is the durable answer to "registering a gate must not require editing this file": it
# builds a THROWAWAY, path-mirrored fixture store (gate_store_fixture_build, a copy, never the
# real scripts/gate-registry.data) carrying one extra synthetic gate id, and reuses
# noflag_header_set_check -- the exact function case (d)/Guard G2 above already use -- against
# the fixture store's own verify-deploy.sh. One comparison function serving both the real and
# fixture cases is what proves the acceptance bar, not merely a passing assertion.
#
# Three fixtures, chosen for cost:
#   - FIXTURE_RICH: a real-copy rsync of agent-system/extensions/ (same shape and rationale as
#     test-verify-deploy-context-budget.sh's fixture) -- needed so gate 20's real per-file-ceiling
#     and eager-load checks produce real content, for case (a)'s "only gate 20's output appears"
#     assertion and several later cases' --max-cost/--jobs selections. The "every gate id runs
#     clean standalone" cross-gate-variable net lives in its own suite,
#     test-verify-deploy-gate-selection-crash-net.sh (see that file's header): it is a genuine
#     full-battery crash net across every registered gate, split into its own schedulable unit rather than
#     narrowed, since there is nothing left to narrow without dropping gate coverage.
#   - FIXTURE_CHEAP: a deploy-consumer-style fixture with NO agent-system/extensions directory
#     (mirroring test-deploy-verify-wiring.sh's ANTI-RECURSION fixture) -- gates 3/5-13/15/17-20
#     all [SKIP] unconditionally against it (their own "not the source store" branch), so a
#     no-flag run still prints every registered gate's header (case (d)) without paying
#     full-battery cost.
#     NOTE: gate 4 is NOT in that SKIP list -- since gate 4's SKIP guard was removed, a no-flag
#     run against FIXTURE_CHEAP now reaches gate 4's "check-task-references.sh not deployed" FAIL
#     branch instead (FIXTURE_CHEAP's hand-built `.claude/scripts/` has no real scripts in it).
#     Case (d) asserts that exactly the registered gate set's headers appear (Guard G2, two-
#     directional set equality), which still holds regardless.
#   - FIXTURE_CONSUMER: a deploy-consumer shape (no agent-system/extensions, like FIXTURE_CHEAP)
#     whose `.claude` is a SYMLINK to a real, fully deployed tree (same technique FIXTURE_RICH
#     and test-verify-deploy-context-budget.sh's fixture already use for their own `.claude`) --
#     needed so `check-task-references.sh` is actually REACHABLE and runs a real scan, unlike
#     FIXTURE_CHEAP's hand-built empty `.claude/scripts/`, which makes a de-guarded gate 4 reach
#     the "not deployed" failure branch instead of a real check. FIXTURE_CHEAP therefore cannot
#     serve case (e)/(f)/(g)/(h) below, which need gate 4 to either genuinely pass or genuinely
#     have something to report.
# Case (c) (invalid gate id) needs no fixture at all: --only-gate argument validation happens in
# the arg-parsing loop, before TARGET is even resolved.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (verify-deploy.sh, rsync, git, or jq not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# Depth-independent resolution (git-toplevel-first, falling back to a fixed-depth guess only
# outside a git tree) -- a hardcoded "../../../.." assumes the source-store depth
# (agent-system/extensions/core/scripts) and overshoots by two levels when this suite runs from
# its deployed copy (.claude/scripts), which sits two levels shallower.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

VERIFY_DEPLOY="$CORE_DIR/verify-deploy.sh"

if [ ! -f "$VERIFY_DEPLOY" ]; then
  echo "ERROR: expected $VERIFY_DEPLOY" >&2
  exit 2
fi
for bin in rsync git jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: $bin required and not on PATH" >&2; exit 2; }
done

# shellcheck source=../lib/gate-registry-lib.sh
source "$CORE_DIR/lib/gate-registry-lib.sh"
gate_registry_load "$CORE_DIR/gate-registry.data"
REGISTRY_IDS="$(gate_registry_ids)"
REGISTRY_MAX="$(gate_registry_max_id)"
# Sanity-pin the 1,99 and --only-gate 99 probes below: they are only genuinely out-of-range
# while the registry stays under 99 ids. This fails loudly (not silently becomes vacuous) the
# day the registry would ever reach that size.
if [ "$REGISTRY_MAX" -ge 99 ]; then
  echo "ERROR: REGISTRY_MAX ($REGISTRY_MAX) is no longer < 99 -- the '1,99' and '--only-gate 99' probes below depend on 99 staying out of range; update them" >&2
  exit 2
fi

PASSED=0
FAILED=0

common_test_workdir_init

# =====================================================================
# FIXTURE_RICH: real-copy rsync, same shape/rationale as test-verify-deploy-context-budget.sh.
# =====================================================================
FIXTURE_RICH="$WORKDIR/rich"
mkdir -p "$FIXTURE_RICH/agent-system/extensions"
rsync -a --exclude='literature-pyenv' "$REPO_ROOT/agent-system/extensions/" "$FIXTURE_RICH/agent-system/extensions/"
cp "$REPO_ROOT/CLAUDE.md" "$FIXTURE_RICH/CLAUDE.md"
cp "$REPO_ROOT/.claude-extensions.json" "$FIXTURE_RICH/.claude-extensions.json"
[ -f "$REPO_ROOT/.gitignore" ] && cp "$REPO_ROOT/.gitignore" "$FIXTURE_RICH/.gitignore"
ln -s "$REPO_ROOT/.claude" "$FIXTURE_RICH/.claude"
git init -q "$FIXTURE_RICH"
git -C "$FIXTURE_RICH" config user.email "test@example.com"
git -C "$FIXTURE_RICH" config user.name "Test"

# =====================================================================
# FIXTURE_CHEAP: deploy-consumer shape (no agent-system/extensions) -- gates 3-13/15/17-20 all
# [SKIP] instantly against it. Only needs a minimal .claude/ so gate1/gate2/gate14/gate16 (which
# run unconditionally or on any target) have something to inspect.
# =====================================================================
FIXTURE_CHEAP="$WORKDIR/cheap"
mkdir -p "$FIXTURE_CHEAP/.claude/scripts" "$FIXTURE_CHEAP/.claude/hooks" "$FIXTURE_CHEAP/.claude/context/schemas" "$FIXTURE_CHEAP/.claude/context/formats" "$FIXTURE_CHEAP/.claude/extensions"
echo '{}' > "$FIXTURE_CHEAP/.claude/settings.json"
git init -q "$FIXTURE_CHEAP"
git -C "$FIXTURE_CHEAP" config user.email "test@example.com"
git -C "$FIXTURE_CHEAP" config user.name "Test"

# =====================================================================
# FIXTURE_GATE16_WARN: a dedicated synthetic fixture, built ONLY for case (r)'s WARN-channel
# demonstration, declaring routing_agents_hard itself in its own manifest rather than reading
# the REAL deployed lean manifest (which no longer declares either retired key, now that
# routing_agents_hard -> hard_contracts has landed). Deliberately NOT added to FIXTURE_CHEAP,
# which other cases share and must stay a clean "nothing to find" shape. Shares FIXTURE_CHEAP's
# minimal .claude/ skeleton so gate16 (which runs unconditionally) has the same non-extension
# surface to inspect; the one synthetic extension manifest is the only difference.
# =====================================================================
FIXTURE_GATE16_WARN="$WORKDIR/gate16-warn"
mkdir -p "$FIXTURE_GATE16_WARN/.claude/scripts" "$FIXTURE_GATE16_WARN/.claude/hooks" "$FIXTURE_GATE16_WARN/.claude/context/schemas" "$FIXTURE_GATE16_WARN/.claude/context/formats" "$FIXTURE_GATE16_WARN/.claude/extensions/zzz-synthetic"
echo '{}' > "$FIXTURE_GATE16_WARN/.claude/settings.json"
cat > "$FIXTURE_GATE16_WARN/.claude/extensions/zzz-synthetic/manifest.json" <<'EOF'
{
  "name": "zzz-synthetic",
  "routing_agents_hard": {
    "research": { "zzztest": "zzz-synthetic-research-hard-agent" }
  }
}
EOF
git init -q "$FIXTURE_GATE16_WARN"
git -C "$FIXTURE_GATE16_WARN" config user.email "test@example.com"
git -C "$FIXTURE_GATE16_WARN" config user.name "Test"

# =====================================================================
# FIXTURE_CONSUMER: deploy-consumer shape (no agent-system/extensions, like FIXTURE_CHEAP) whose
# .claude is a SYMLINK to the real, fully deployed tree at $REPO_ROOT/.claude -- same technique
# FIXTURE_RICH uses for its own .claude. This makes check-task-references.sh (and its shared
# pattern library) actually reachable, so gate 4 runs a real scan here instead of hitting the
# "not deployed" branch FIXTURE_CHEAP's hand-built empty .claude/scripts/ would force it into.
# =====================================================================
FIXTURE_CONSUMER="$WORKDIR/consumer"
mkdir -p "$FIXTURE_CONSUMER"
ln -s "$REPO_ROOT/.claude" "$FIXTURE_CONSUMER/.claude"
git init -q "$FIXTURE_CONSUMER"
git -C "$FIXTURE_CONSUMER" config user.email "test@example.com"
git -C "$FIXTURE_CONSUMER" config user.name "Test"

run_vd() {
  # Usage: run_vd TARGET [extra args...]
  local target="$1"; shift
  bash "$VERIFY_DEPLOY" --skip-slow "$@" "$target" 2>&1
}

# =====================================================================
# Case (a): --only-gate 20 runs gate 20 and no other gate's output appears.
# =====================================================================
only20_out="$(run_vd "$FIXTURE_RICH" --only-gate 20)"
only20_headers="$(printf '%s\n' "$only20_out" | grep -cE '^[0-9]+\. ')"
only20_has_gate20_header="$(printf '%s\n' "$only20_out" | grep -c '^20\. ')"
if [ "$only20_headers" -eq 1 ] && [ "$only20_has_gate20_header" -eq 1 ]; then
  common_test_pass "case(a): --only-gate 20 prints exactly one gate header, and it is gate 20's"
else
  common_test_fail "case(a): expected exactly one gate header (gate 20's), found $only20_headers header(s)" \
       "$(printf '%s\n' "$only20_out" | grep -E '^[0-9]+\. ')"
fi

# The "every registered gate id runs standalone against FIXTURE_RICH, no crash" net lives in its own
# suite, test-verify-deploy-gate-selection-crash-net.sh: a genuine full-battery crash check
# (~149.7s, dominated by a single real gate-3 run at ~114.7s) that `--only-gate` already narrows
# to one gate per call, leaving nothing further to narrow without dropping gate coverage -- split
# into its own schedulable unit instead. See that suite's own header for the full rationale;
# FIXTURE_RICH below is still built here for every OTHER case that uses it
# (a, i, j, k, l, m, n, o, p, q).

# =====================================================================
# Case (c): an invalid gate id exits 2 with a named error, and (under --findings) a FINDING gate0
# line. No fixture needed -- validation happens before TARGET is resolved.
# =====================================================================
ONE_PAST_MAX="$((REGISTRY_MAX + 1))"
invalid_cases=("abc" "0" "$ONE_PAST_MAX" "1,abc" "1,99")
case_c_all_ok=true
for bad in "${invalid_cases[@]}"; do
  bad_out="$(bash "$VERIFY_DEPLOY" --only-gate "$bad" 2>&1)"
  bad_rc=$?
  if [ "$bad_rc" -ne 2 ]; then
    common_test_fail "case(c): --only-gate $bad expected exit 2, got $bad_rc"
    case_c_all_ok=false
    continue
  fi
  if ! printf '%s\n' "$bad_out" | grep -q "ERROR: --only-gate:"; then
    common_test_fail "case(c): --only-gate $bad exited 2 but printed no named --only-gate error" "$bad_out"
    case_c_all_ok=false
  fi
done
[ "$case_c_all_ok" = "true" ] && common_test_pass "case(c): every invalid gate id (${invalid_cases[*]}) exits 2 with a named error"

# 99 is a bare literal here, deliberately: it is protected by the REGISTRY_MAX < 99 guard near
# the top of this file (exits 2 loudly if the registry ever reaches 99), so this probe stays
# genuinely out-of-range rather than silently becoming valid.
findings_bad_out="$(bash "$VERIFY_DEPLOY" --findings --only-gate 99 2>&1)"
findings_bad_rc=$?
if [ "$findings_bad_rc" -eq 2 ] && printf '%s\n' "$findings_bad_out" | grep -q '^FINDING gate0 '; then
  common_test_pass "case(c): --findings --only-gate 99 emits a FINDING gate0 line on exit 2"
else
  common_test_fail "case(c): --findings --only-gate 99 did not emit the expected FINDING gate0 line" "$findings_bad_out"
fi

# =====================================================================
# Case (d) / Guard G2: with no --only-gate flag, the EXACT registered gate set's headers appear
# in the output -- the "default unchanged" assertion, now TWO-DIRECTIONAL set equality rather
# than one-directional coverage. Uses FIXTURE_CHEAP so this stays fast (gates 3-13/15/17-20 all
# [SKIP] instantly; only gates 1/2/14/16 do any real, cheap work). Factored into a function
# (noflag_header_set_check) so Phase 6's fixture-gate case can reuse the identical comparison
# logic against a fixture store's own verify-deploy.sh, rather than keeping two copies that
# could silently diverge.
# =====================================================================
noflag_header_set_check() {
  # Usage: noflag_header_set_check <run_output> <expected_ids_space_separated>
  local _out="$1" _expected="$2"
  local _printed _missing=() _extra=()
  _printed="$(printf '%s\n' "$_out" | grep -oE '^[0-9]+\. ' | tr -d '. ' | sort -n)"
  local _printed_sorted _expected_sorted
  _printed_sorted="$(printf '%s\n' "$_printed" | tr '\n' ' ' | sed 's/ $//')"
  _expected_sorted="$(printf '%s\n' "$_expected" | tr ' ' '\n' | sort -n | tr '\n' ' ' | sed 's/ $//')"
  for _id in $_expected_sorted; do
    printf '%s\n' "$_printed" | grep -qx "$_id" || _missing+=("$_id")
  done
  for _id in $_printed; do
    printf '%s\n' "$_expected_sorted" | tr ' ' '\n' | grep -qx "$_id" || _extra+=("$_id")
  done
  if [ "${#_missing[@]}" -eq 0 ] && [ "${#_extra[@]}" -eq 0 ]; then
    echo "OK"
  else
    echo "MISSING:${_missing[*]:-none} EXTRA:${_extra[*]:-none}"
  fi
}

noflag_out="$(run_vd "$FIXTURE_CHEAP")"
noflag_g2_result="$(noflag_header_set_check "$noflag_out" "$REGISTRY_IDS")"
if [ "$noflag_g2_result" = "OK" ]; then
  common_test_pass "case(d)/G2: no --only-gate flag -- exactly the $(printf '%s\n' "$REGISTRY_IDS" | wc -w | tr -d ' ') registered gate headers appear, no fewer and no more (default unchanged, two-directional set equality)"
else
  common_test_fail "case(d)/G2: no --only-gate flag -- header set diverges from the registry ($noflag_g2_result)"
fi

# =====================================================================
# Case (e): --only-gate 4 against FIXTURE_CONSUMER (a deploy-consumer repo, no
# agent-system/extensions) produces a real, non-[SKIP], passing gate-4 check and a non-zero
# check count. Pins Phase 2's de-guard: before that change, this would have printed [SKIP] and
# PASS -- 0 check(s).
# =====================================================================
gate4_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 4)"
gate4_rc=$?
if [ "$gate4_rc" -eq 0 ] \
   && printf '%s\n' "$gate4_out" | grep -q '^  \[PASS\] task-reference lint reports no findings' \
   && ! printf '%s\n' "$gate4_out" | grep -q '\[SKIP\]' \
   && printf '%s\n' "$gate4_out" | grep -q 'PASS -- 1 check(s), 0 failure(s)'; then
  common_test_pass "case(e): --only-gate 4 against a deploy-consumer fixture runs a real, passing, non-SKIP check"
else
  common_test_fail "case(e): --only-gate 4 against FIXTURE_CONSUMER did not produce the expected real-check output (rc=$gate4_rc)" "$gate4_out"
fi

# =====================================================================
# Case (f): an all-SKIP selection (--only-gate 3, which always SKIPs against a deploy-consumer
# repo) exits 2 with the new named zero-check message and emits no PASS -- 0 check(s) line.
# Pins Phase 3's zero-check-under-filter detection.
# =====================================================================
gate3_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 3)"
gate3_rc=$?
if [ "$gate3_rc" -eq 2 ] \
   && printf '%s\n' "$gate3_out" | grep -q 'cannot attest:.*--only-gate 3.*skipped or was deferred' \
   && ! printf '%s\n' "$gate3_out" | grep -q 'PASS -- 0 check(s)'; then
  common_test_pass "case(f): an all-SKIP --only-gate 3 selection exits 2 with the named zero-check message"
else
  common_test_fail "case(f): --only-gate 3 against FIXTURE_CONSUMER did not produce the expected zero-check result (rc=$gate3_rc)" "$gate3_out"
fi

# =====================================================================
# Case (g): --findings --only-gate 3 against FIXTURE_CONSUMER emits the FINDING gate0 sentinel
# line for the zero-check condition, matching the existing gate0 "could not run" convention.
# =====================================================================
gate3_findings_out="$(bash "$VERIFY_DEPLOY" --skip-slow --findings --only-gate 3 "$FIXTURE_CONSUMER" 2>&1)"
gate3_findings_rc=$?
if [ "$gate3_findings_rc" -eq 2 ] && printf '%s\n' "$gate3_findings_out" | grep -q '^FINDING gate0 .*--only-gate 3.*skipped or was deferred'; then
  common_test_pass "case(g): --findings --only-gate 3 emits a FINDING gate0 line for the zero-check condition"
else
  common_test_fail "case(g): --findings --only-gate 3 against FIXTURE_CONSUMER did not emit the expected FINDING gate0 line (rc=$gate3_findings_rc)" "$gate3_findings_out"
fi

# =====================================================================
# Case (h): a deferred-gate-only selection (--skip-slow --only-gate 8) reaches the same loud
# zero-check result as an all-SKIP selection -- encodes Phase 3's explicit decision that a
# deferred gate also contributes no check, so the run attests to nothing either way.
# =====================================================================
gate8_out="$(run_vd "$FIXTURE_CONSUMER" --only-gate 8)"
gate8_rc=$?
if [ "$gate8_rc" -eq 2 ] \
   && printf '%s\n' "$gate8_out" | grep -q 'cannot attest:.*--only-gate 8.*skipped or was deferred' \
   && ! printf '%s\n' "$gate8_out" | grep -q 'PASS -- 0 check(s)'; then
  common_test_pass "case(h): a deferred-gate-only --skip-slow --only-gate 8 selection reaches the same zero-check result"
else
  common_test_fail "case(h): --skip-slow --only-gate 8 against FIXTURE_CONSUMER did not produce the expected zero-check result (rc=$gate8_rc)" "$gate8_out"
fi

# =====================================================================
# Case (i): --max-cost free against FIXTURE_RICH runs ONLY free-class gates. Cross-checked
# against the real registry data rather than a hardcoded id list, so this case tracks
# gate-registry.data's own classification instead of drifting from it.
# =====================================================================
free_ids_expected="$(awk -F'\t' '$1 ~ /^[0-9]+$/ && $7 == "free" {print $1}' "$CORE_DIR/gate-registry.data" | sort -n | tr '\n' ' ' | sed 's/ $//')"
maxcost_free_out="$(run_vd "$FIXTURE_RICH" --max-cost free)"
maxcost_free_headers="$(printf '%s\n' "$maxcost_free_out" | grep -oE '^[0-9]+\. ' | grep -oE '[0-9]+' | sort -n | tr '\n' ' ' | sed 's/ $//')"
if [ "$maxcost_free_headers" = "$free_ids_expected" ]; then
  common_test_pass "case(i): --max-cost free runs exactly the registry's free-class gates ($free_ids_expected)"
else
  common_test_fail "case(i): --max-cost free ran gates '$maxcost_free_headers', expected '$free_ids_expected'"
fi

# =====================================================================
# Case (j): --max-cost moderate is a superset of --max-cost free (free + moderate gates),
# proving the ordinal free < moderate < slow comparison, not an exact-class-only match.
# =====================================================================
moderate_ids_expected="$(awk -F'\t' '$1 ~ /^[0-9]+$/ && ($7 == "free" || $7 == "moderate") {print $1}' "$CORE_DIR/gate-registry.data" | sort -n | tr '\n' ' ' | sed 's/ $//')"
maxcost_moderate_out="$(run_vd "$FIXTURE_RICH" --max-cost moderate)"
maxcost_moderate_headers="$(printf '%s\n' "$maxcost_moderate_out" | grep -oE '^[0-9]+\. ' | grep -oE '[0-9]+' | sort -n | tr '\n' ' ' | sed 's/ $//')"
if [ "$maxcost_moderate_headers" = "$moderate_ids_expected" ]; then
  common_test_pass "case(j): --max-cost moderate runs exactly the registry's free+moderate gates (ordinal ceiling, not exact-class match)"
else
  common_test_fail "case(j): --max-cost moderate ran gates '$maxcost_moderate_headers', expected '$moderate_ids_expected'"
fi

# =====================================================================
# Case (k): an invalid --max-cost class name exits 2 with a named error, mirroring --only-gate's
# own invalid-id handling.
# =====================================================================
maxcost_bad_out="$(bash "$VERIFY_DEPLOY" --skip-slow --max-cost bogus "$FIXTURE_RICH" 2>&1)"
maxcost_bad_rc=$?
if [ "$maxcost_bad_rc" -eq 2 ] && printf '%s\n' "$maxcost_bad_out" | grep -q "invalid class 'bogus'"; then
  common_test_pass "case(k): --max-cost bogus exits 2 with a named invalid-class error"
else
  common_test_fail "case(k): --max-cost bogus did not produce the expected exit-2 error (rc=$maxcost_bad_rc)" "$maxcost_bad_out"
fi

# =====================================================================
# Case (l): --only-gate and --max-cost intersect, order-independent -- gate 1 (free) is the only
# member of {1,3,22} (3 and 22 are both slow) under --max-cost free, regardless of which flag is
# given first on the command line.
# =====================================================================
intersect_out1="$(run_vd "$FIXTURE_RICH" --only-gate 1,3,22 --max-cost free)"
intersect_out2="$(run_vd "$FIXTURE_RICH" --max-cost free --only-gate 1,3,22)"
intersect_headers1="$(printf '%s\n' "$intersect_out1" | grep -cE '^[0-9]+\. ')"
intersect_has1="$(printf '%s\n' "$intersect_out1" | grep -c '^1\. ')"
if [ "$intersect_headers1" -eq 1 ] && [ "$intersect_has1" -eq 1 ] && [ "$intersect_out1" = "$intersect_out2" ]; then
  common_test_pass "case(l): --only-gate 1,3,22 intersected with --max-cost free selects only gate 1, order-independent"
else
  common_test_fail "case(l): expected exactly gate 1 selected and flag-order-independence (got $intersect_headers1 header(s))" \
       "$intersect_out1"
fi

# =====================================================================
# Case (m): an --only-gate/--max-cost combination with a zero-gate intersection (gate 3 is slow,
# not free) reaches the same zero-check-under-filter exit-2 result as an all-SKIP --only-gate
# selection, with a message naming BOTH flags (not crediting --only-gate alone).
# =====================================================================
intersect_zero_out="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 3 --max-cost free "$FIXTURE_RICH" 2>&1)"
intersect_zero_rc=$?
if [ "$intersect_zero_rc" -eq 2 ] \
   && printf '%s\n' "$intersect_zero_out" | grep -q 'cannot attest:.*--only-gate 3 intersected with --max-cost free'; then
  common_test_pass "case(m): a zero-gate --only-gate/--max-cost intersection reaches the zero-check result, naming both flags"
else
  common_test_fail "case(m): --only-gate 3 --max-cost free did not produce the expected zero-check result (rc=$intersect_zero_rc)" "$intersect_zero_out"
fi

# =====================================================================
# Case (n): --jobs rejects an invalid value (neither a positive integer nor "auto") with exit 2
# and, under --findings, a FINDING gate0 line -- mirrors --only-gate's own invalid-id handling.
# =====================================================================
jobs_invalid_out="$(bash "$VERIFY_DEPLOY" --skip-slow --findings --jobs notanumber "$FIXTURE_CHEAP" 2>&1)"
jobs_invalid_rc=$?
if [ "$jobs_invalid_rc" -eq 2 ] && printf '%s\n' "$jobs_invalid_out" | grep -q "FINDING gate0.*--jobs invalid value 'notanumber'"; then
  common_test_pass "case(n): --jobs notanumber exits 2 with a named FINDING gate0 error"
else
  common_test_fail "case(n): --jobs notanumber did not produce the expected exit-2/FINDING result (rc=$jobs_invalid_rc)" "$jobs_invalid_out"
fi

# =====================================================================
# Case (o): --jobs auto resolves without error against a cheap selection (sanity: the nproc-
# capped resolution path itself does not crash or exit nonzero for an unrelated reason).
# =====================================================================
jobs_auto_out="$(run_vd "$FIXTURE_RICH" --jobs auto --only-gate 1,2)"
jobs_auto_rc=$?
if [ "$jobs_auto_rc" -eq 0 ] && printf '%s\n' "$jobs_auto_out" | grep -qE '^1\. '; then
  common_test_pass "case(o): --jobs auto resolves and runs cleanly"
else
  common_test_fail "case(o): --jobs auto did not run cleanly (rc=$jobs_auto_rc)" "$jobs_auto_out"
fi

# =====================================================================
# Case (p): determinism -- an identical gate selection against the SAME real-copy fixture
# produces byte-identical output at worker counts 1, 2, and 4 (Phase 7's own required property:
# CHECKS/FAILURES are pure sums, FINDINGS_LIST is already sort-u'd downstream, and per-gate
# narrative is always emitted in ascending gate-id order regardless of completion order).
# =====================================================================
det_out1="$(run_vd "$FIXTURE_RICH" --jobs 1 --findings --only-gate 1,2,4,9,11,14,20)"
det_out2="$(run_vd "$FIXTURE_RICH" --jobs 2 --findings --only-gate 1,2,4,9,11,14,20)"
det_out4="$(run_vd "$FIXTURE_RICH" --jobs 4 --findings --only-gate 1,2,4,9,11,14,20)"
if [ "$det_out1" = "$det_out2" ] && [ "$det_out2" = "$det_out4" ]; then
  common_test_pass "case(p): byte-identical output at --jobs 1, 2, and 4 for the same 7-gate selection"
else
  common_test_fail "case(p): output diverged across worker counts" \
       "jobs=1 vs jobs=2 diff:
$(diff <(echo "$det_out1") <(echo "$det_out2"))
jobs=2 vs jobs=4 diff:
$(diff <(echo "$det_out2") <(echo "$det_out4"))"
fi

# =====================================================================
# Case (q): the nested-invocation guard (VERIFY_DEPLOY_NESTED=1) forces --jobs down to 1
# regardless of what was requested -- proven by a RELATIVE wall-clock ratio (same technique
# test-run-all-selection.sh's own RUN_ALL_NESTED case uses: a deliberately generous one-
# directional assertion, never an absolute-ms threshold), not merely by output equality (output
# is ALREADY proven identical at every worker count by case(p), so equality alone cannot
# distinguish "ran sequentially" from "ran concurrently and still produced the same text").
# This selection (gates 1,2,4,9,11,14,20 against the real-copy fixture, including gate 20's real
# per-file reads) was measured directly during this phase's own implementation at ~2.3s
# unguarded (--jobs 4) vs ~4.6s under a forced nested guard -- a reliable ~2x gap, not a close
# call.
# =====================================================================
t0_unguarded=$(date +%s%3N)
run_vd "$FIXTURE_RICH" --jobs 4 --only-gate 1,2,4,9,11,14,20 >/dev/null
t1_unguarded=$(date +%s%3N)
ms_unguarded=$((t1_unguarded - t0_unguarded))

t0_nested=$(date +%s%3N)
VERIFY_DEPLOY_NESTED=1 run_vd "$FIXTURE_RICH" --jobs 4 --only-gate 1,2,4,9,11,14,20 >/dev/null
t1_nested=$(date +%s%3N)
ms_nested=$((t1_nested - t0_nested))

# Generous one-directional margin (nested must not be FASTER than 90% of unguarded) -- matches
# test-run-all-selection.sh case9's own "not faster than" posture rather than a tight ratio.
if [ "$ms_nested" -ge "$((ms_unguarded * 9 / 10))" ]; then
  common_test_pass "case(q): VERIFY_DEPLOY_NESTED=1 forces sequential execution -- nested ${ms_nested}ms is not faster than 90% of unguarded --jobs 4's ${ms_unguarded}ms"
else
  common_test_fail "case(q): VERIFY_DEPLOY_NESTED=1 (${ms_nested}ms) was FASTER than unguarded --jobs 4 (${ms_unguarded}ms) -- the nested guard may not be forcing sequential execution"
fi

# =====================================================================
# Case (r): gate16's WARN-level finding (routing_hard/routing_agents_hard) stays on the
# non-blocking `WARN-FINDING ` channel instead of escalating into the blocking `^FINDING `
# channel the batch-gate stage's deploy_findings_snapshot filters on with `grep '^FINDING '`.
# FIXTURE_GATE16_WARN's synthetic manifest declares routing_agents_hard itself (the REAL deployed
# lean manifest no longer does, now that routing_agents_hard -> hard_contracts has landed), so
# this exercises warn_advisory()'s real call site against a fixture-independent trigger rather
# than depending on live manifest content. Four sub-assertions, matching this task's own Defect 5
# acceptance evidence:
#   (a) --findings --quiet emits NO ^FINDING gate16 line;
#   (b) the [WARN] stderr line is still emitted (unconditional, not gated by --quiet);
#   (c) the exit code is unchanged (0 -- warn_advisory() never increments FAILURES);
#   (d) a real fail()-level finding from another gate (gate4 against FIXTURE_CHEAP, which has no
#       deployed check-task-references.sh) still appears on ^FINDING, proving the `grep
#       '^FINDING '` filter still passes a genuine blocking finding through unaffected.
# =====================================================================
# Single invocation capturing BOTH streams (not two separate runs of the same expensive
# fixture process) -- this closed a logged flaky-test class: run-all.sh observed this exact
# case (r-a2/r-b) transiently fail under resource contention with a concurrently-running
# sibling /orchestrate task's own verify-deploy.sh fixture processes, and re-running in
# isolation always passed cleanly. Spawning the fixture process TWICE back-to-back for what is
# otherwise an identical invocation doubled this case's exposure to that contention window for
# no benefit -- stdout and stderr of the SAME run are captured together via a scratch file
# (inside $WORKDIR, so the existing EXIT trap cleans it up) rather than re-running the command.
gate16_stderr_file="$(mktemp -p "$WORKDIR" gate16-stderr.XXXXXX)"
gate16_stdout="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 16 --findings --quiet "$FIXTURE_GATE16_WARN" 2>"$gate16_stderr_file")"
gate16_rc=$?
gate16_stderr="$(cat "$gate16_stderr_file")"

if ! printf '%s\n' "$gate16_stdout" | grep -q '^FINDING gate16'; then
  common_test_pass "case(r-a): gate16's routing_hard/routing_agents_hard notice emits no ^FINDING gate16 line"
else
  common_test_fail "case(r-a): expected no ^FINDING gate16 line, found one" "$gate16_stdout"
fi

if printf '%s\n' "$gate16_stdout" | grep -q '^WARN-FINDING gate16'; then
  common_test_pass "case(r-a2): gate16's notice is still present on the non-blocking WARN-FINDING channel"
else
  common_test_fail "case(r-a2): expected a ^WARN-FINDING gate16 line, found none" "$gate16_stdout"
fi

if printf '%s\n' "$gate16_stderr" | grep -q '\[WARN\].*routing_hard/routing_agents_hard'; then
  common_test_pass "case(r-b): the [WARN] stderr line is still emitted (unconditional, not gated by --quiet)"
else
  common_test_fail "case(r-b): expected a [WARN] stderr line naming routing_hard/routing_agents_hard" "$gate16_stderr"
fi

if [ "$gate16_rc" -eq 0 ]; then
  common_test_pass "case(r-c): exit code unchanged (0) -- warn_advisory() never flips the exit code"
else
  common_test_fail "case(r-c): expected exit 0, got $gate16_rc" "$gate16_stdout"
fi

gate4_findings_out="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 4 --findings --quiet "$FIXTURE_CHEAP" 2>/dev/null)"
if printf '%s\n' "$gate4_findings_out" | grep -q '^FINDING gate4'; then
  common_test_pass "case(r-d): a real fail()-level finding from another gate (gate4) still appears on ^FINDING, unaffected by gate16's channel split"
else
  common_test_fail "case(r-d): expected a ^FINDING gate4 line against FIXTURE_CHEAP" "$gate4_findings_out"
fi

# (r-e) Green side: against a fixture with no declaring manifest at all (FIXTURE_CHEAP's
# .claude/extensions/ is created but left empty), gate16 emits the `pass` line and no WARN
# finding of any kind -- the absence-guard's normal, expected outcome now that both keys are
# fully retired. The `pass` line itself is suppressed under `--quiet` (pass() routes through
# say(), which --quiet gates) -- a NON-quiet run checks for it; the --findings --quiet run
# checks for the finding-channel absence and the exit code, matching cases (r-a)-(r-c) above.
gate16_green_plain_stdout="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 16 "$FIXTURE_CHEAP" 2>/dev/null)"
if printf '%s\n' "$gate16_green_plain_stdout" | grep -q 'no extension manifest declares routing_hard/routing_agents_hard'; then
  common_test_pass "case(r-e): gate16 emits the pass line against a fixture with no declaring manifest"
else
  common_test_fail "case(r-e): expected gate16's pass line, not found" "$gate16_green_plain_stdout"
fi
gate16_green_stdout="$(bash "$VERIFY_DEPLOY" --skip-slow --only-gate 16 --findings --quiet "$FIXTURE_CHEAP" 2>/dev/null)"
gate16_green_rc=$?
if ! printf '%s\n' "$gate16_green_stdout" | grep -qE '^(WARN-)?FINDING gate16'; then
  common_test_pass "case(r-e): no WARN-FINDING or FINDING gate16 line against the no-declaration fixture"
else
  common_test_fail "case(r-e): unexpected gate16 finding line against the no-declaration fixture" "$gate16_green_stdout"
fi
if [ "$gate16_green_rc" -eq 0 ]; then
  common_test_pass "case(r-e): exit code 0 against the no-declaration fixture"
else
  common_test_fail "case(r-e): expected exit 0, got $gate16_green_rc" "$gate16_green_stdout"
fi

# =====================================================================
# Case (s): Throwaway-Gate Fixture Proof -- this suite's half of the acceptance bar. Build a
# path-mirrored fixture store (Phase 1's gate_store_fixture_build) carrying one extra, synthetic
# gate id (REGISTRY_MAX + 1, derived -- never a bare literal), and show a no-flag --skip-slow
# run of the FIXTURE's own verify-deploy.sh against FIXTURE_CHEAP prints a header for every
# fixture-registry id, including the extra one, under noflag_header_set_check -- the EXACT SAME
# function G2 (case (d)) uses, so this case and case (d) cannot silently diverge.
# =====================================================================
source "$CORE_DIR/lib/gate-store-fixture-lib.sh"
FIXTURE_EXTRA_ID="$((REGISTRY_MAX + 1))"
FIXTURE_VD="$(gate_store_fixture_build "$WORKDIR/fixture-store" "$FIXTURE_EXTRA_ID" 'Throwaway fixture gate')"
FIXTURE_DATA="$(dirname "$FIXTURE_VD")/gate-registry.data"
fixture_registry_ids="$(awk -F'\t' '$1 ~ /^[0-9]+$/ {print $1}' "$FIXTURE_DATA" | sort -n | tr '\n' ' ' | sed 's/ $//')"

fixture_noflag_out="$(bash "$FIXTURE_VD" --skip-slow "$FIXTURE_CHEAP" 2>&1)"
fixture_g2_result="$(noflag_header_set_check "$fixture_noflag_out" "$fixture_registry_ids")"
if [ "$fixture_g2_result" = "OK" ]; then
  common_test_pass "case(s): a no-flag run of the fixture store's verify-deploy.sh prints exactly the fixture registry's id set (including gate $FIXTURE_EXTRA_ID), via the identical noflag_header_set_check G2 uses -- zero suite edit between the real and fixture cases"
else
  common_test_fail "case(s): fixture store header set diverges from the fixture registry ($fixture_g2_result)"
fi
# The real gate-registry.data is untouched.
if [ "$(grep -c "^${FIXTURE_EXTRA_ID}	" "$CORE_DIR/gate-registry.data")" -eq 0 ]; then
  common_test_pass "case(s): the real gate-registry.data has no row for gate $FIXTURE_EXTRA_ID -- the fixture store never touched it"
else
  common_test_fail "case(s): unexpectedly found a row for gate $FIXTURE_EXTRA_ID in the REAL gate-registry.data"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="

[ "$FAILED" -eq 0 ] && exit 0 || exit 1
