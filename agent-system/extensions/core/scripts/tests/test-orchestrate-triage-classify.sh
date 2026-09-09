#!/usr/bin/env bash
# test-orchestrate-triage-classify.sh - Fixture-driven regression suite for
# orchestrate-triage-classify.sh. ORIGINALLY scoped to only the `partial`-status
# continuation-pointer predicate (see "THE DEFECT UNDER TEST" below); EXTENDED (see
# "Full status-to-group coverage" further down) to be the full status-to-group regression suite
# for both engines, covering every row of the classifier's header table except
# `researching`/`planning` (those two rows' mutation-check fixtures belong to, and are written and
# run against the pre-fix classifier by, the change that adds them — see that change's own commit
# body for the required RED evidence), and FURTHER EXTENDED (see "Discriminated blocked sub-cases"
# further down) to cover the six discriminated `blocked`-row sub-cases (discharged / discharged
# with handoff blockers / dependency outstanding / dependency abandoned or expanded / empty
# dependencies[] / discharged but missing previous_status) in place of the single, no-longer-
# accurate `fixture_blocked` divergence pair this suite originally carried.
#
# THE DEFECT UNDER TEST (original scope): the sole active .orchestrator-handoff.json writer (H9
# hard-mode wrap-up) emits a FLAT top-level `continuation_path` string. Before the fix, the
# classifier's `continuation_ok` jq expression checks ONLY the NESTED
# `continuation_context.handoff_path` — a key the active writer never produces. A real, actionable
# continuation therefore classifies as handoff_state "empty" instead of "continuation", stranding
# the task. This suite locks in the fix: accept EITHER form, per
# context/standards/shell-script-testing.md's mutation-check discipline (a suite that passes
# unchanged pre- and post-fix proves nothing).
#
# Sandbox shape: the classifier sources deploy-root-guard.sh, which hard-requires the script's
# parent directory to match `*/.claude` or `*/.opencode` and derives
# PROJECT_ROOT="$SCRIPT_DIR/../..". This suite copies both scripts into a synthetic
# $WORKDIR/.claude/scripts/ so PROJECT_ROOT resolves to $WORKDIR, with a sibling $WORKDIR/specs/
# holding a synthetic state.json and per-fixture .orchestrator-handoff.json files — no STATE_FILE
# override is needed (empirically confirmed at implementation time).
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, inline heredoc fixtures (no committed fixture tree), exit 0 iff FAILED == 0.
#
# Exit codes: 0 -- all cases PASS; 1 (or the last failing `bash` invocation's non-zero status,
# treated as a fixture failure) -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_SRC="$SCRIPT_DIR/../orchestrate-triage-classify.sh"
GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"
COMMON_SRC="$SCRIPT_DIR/../lib/common.sh"
CONT_LIB_SRC="$SCRIPT_DIR/../lib/continuation-pointer-lib.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$TOOL_SRC" ]; then
  echo "ERROR: expected orchestrate-triage-classify.sh at $TOOL_SRC" >&2
  exit 1
fi

if [ ! -f "$GUARD_SRC" ]; then
  echo "ERROR: expected deploy-root-guard.sh at $GUARD_SRC" >&2
  exit 1
fi

if [ ! -f "$COMMON_SRC" ]; then
  echo "ERROR: expected lib/common.sh at $COMMON_SRC" >&2
  exit 1
fi

if [ ! -f "$CONT_LIB_SRC" ]; then
  echo "ERROR: expected lib/continuation-pointer-lib.sh at $CONT_LIB_SRC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required by orchestrate-triage-classify.sh and this suite, and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs"
cp "$TOOL_SRC" "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
cp "$GUARD_SRC" "$WORKDIR/.claude/scripts/deploy-root-guard.sh"
cp "$COMMON_SRC" "$WORKDIR/.claude/scripts/lib/common.sh"
cp "$CONT_LIB_SRC" "$WORKDIR/.claude/scripts/lib/continuation-pointer-lib.sh"
chmod +x "$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"
TOOL="$WORKDIR/.claude/scripts/orchestrate-triage-classify.sh"

# =====================================================================
# Scope Hypothesis (a): confirm the sandbox shape satisfies deploy-root-guard.sh and yields
# PROJECT_ROOT == $WORKDIR with no source change to the tool, before any fixture is built on
# top of it.
# =====================================================================

cat > "$WORKDIR/specs/state.json" <<'EOF'
{"active_projects":[{"project_number":999,"project_name":"sandbox_probe","status":"not_started"}]}
EOF

probe_out="$(bash "$TOOL" single 999 2>&1)"
probe_exit=$?
probe_group="$(echo "$probe_out" | jq -r '.group' 2>/dev/null)"

if [ "$probe_exit" -eq 0 ] && [ "$probe_group" = "research" ]; then
  pass "sandbox shape: \$WORKDIR/.claude/scripts/ satisfies deploy-root-guard.sh, PROJECT_ROOT == \$WORKDIR (no STATE_FILE override needed)"
else
  fail "sandbox shape: expected exit 0 and group=research for the not_started probe task (research-first default, no --effort), got exit=$probe_exit output=$probe_out"
  echo ""
  echo "Results: ${PASSED} passed, ${FAILED} failed"
  echo "ERROR: sandbox probe failed; aborting before building fixtures (per Rollback/Contingency: escalate rather than route around the friction)." >&2
  exit 1
fi

# =====================================================================
# Fixtures A-D: all four live as sibling `partial`-status projects in one shared state.json, so
# a single classifier invocation per engine covers all four in one pass.
# =====================================================================

mkdir -p "$WORKDIR/specs/101_fixture_a" "$WORKDIR/specs/102_fixture_b" \
         "$WORKDIR/specs/103_fixture_c" "$WORKDIR/specs/104_fixture_d"

cat > "$WORKDIR/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 101, "project_name": "fixture_a", "status": "partial"},
    {"project_number": 102, "project_name": "fixture_b", "status": "partial"},
    {"project_number": 103, "project_name": "fixture_c", "status": "partial"},
    {"project_number": 104, "project_name": "fixture_d", "status": "partial"}
  ]
}
EOF

# Fixture A (the mutation-check fixture, load-bearing): flat top-level continuation_path only,
# continuation_context explicitly null -- the exact shape the sole active H9 writer emits.
cat > "$WORKDIR/specs/101_fixture_a/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": "specs/101_fixture_a/handoffs/phase-2-handoff-TS.md",
  "blockers": []
}
EOF

# Fixture B (no-regression on the nested form): nested continuation_context.handoff_path
# populated, no top-level continuation_path key at all.
cat > "$WORKDIR/specs/102_fixture_b/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": {"handoff_path": "specs/102_fixture_b/handoffs/phase-1-handoff-TS.md", "orchestrator_mode": true},
  "blockers": []
}
EOF

# Fixture C (anti-over-relaxation guard): both forms null, no blockers -- must stay "empty".
cat > "$WORKDIR/specs/103_fixture_c/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": null,
  "blockers": []
}
EOF

# Fixture D (blockers precedence preserved): continuation_path populated AND blockers non-empty
# -- continuation must still outrank blockers.
cat > "$WORKDIR/specs/104_fixture_d/.orchestrator-handoff.json" <<'EOF'
{
  "continuation_context": null,
  "continuation_path": "specs/104_fixture_d/handoffs/phase-3-handoff-TS.md",
  "blockers": ["some unresolved blocker"]
}
EOF

check_fixture() {
  # check_fixture <engine> <task_number> <expected_handoff_state> <expected_group> <label>
  local engine="$1" task="$2" expected_state="$3" expected_group="$4" label="$5"
  local out
  out="$(bash "$TOOL" "$engine" "$task" 2>&1)"
  local got_state got_group
  got_state="$(echo "$out" | jq -r '.handoff_state' 2>/dev/null)"
  got_group="$(echo "$out" | jq -r '.group' 2>/dev/null)"
  if [ "$got_state" = "$expected_state" ] && [ "$got_group" = "$expected_group" ]; then
    pass "$label (engine=$engine): handoff_state=$got_state group=$got_group"
  else
    fail "$label (engine=$engine): expected handoff_state=$expected_state group=$expected_group, got handoff_state=$got_state group=$got_group (raw: $out)"
  fi
}

# check_fixture_effort <effort|""> <engine> <task_number> <expected_handoff_state> <expected_group> <label>
# Effort-aware sibling of check_fixture, added as a separate wrapper rather than widening
# check_fixture's own signature at its ~40 existing call sites. Empty effort omits --effort
# entirely, matching the classifier's own "no flag" convention.
check_fixture_effort() {
  local effort="$1" engine="$2" task="$3" expected_state="$4" expected_group="$5" label="$6"
  local out
  if [ -n "$effort" ]; then
    out="$(bash "$TOOL" --effort "$effort" "$engine" "$task" 2>&1)"
  else
    out="$(bash "$TOOL" "$engine" "$task" 2>&1)"
  fi
  local got_state got_group
  got_state="$(echo "$out" | jq -r '.handoff_state' 2>/dev/null)"
  got_group="$(echo "$out" | jq -r '.group' 2>/dev/null)"
  if [ "$got_state" = "$expected_state" ] && [ "$got_group" = "$expected_group" ]; then
    pass "$label (effort=${effort:-none}, engine=$engine): handoff_state=$got_state group=$got_group"
  else
    fail "$label (effort=${effort:-none}, engine=$engine): expected handoff_state=$expected_state group=$expected_group, got handoff_state=$got_state group=$got_group (raw: $out)"
  fi
}

# --- Fixture A: single engine (this is the mutation-check assertion) ---
check_fixture "single" 101 "continuation" "implement" \
  "Fixture A (flat continuation_path only, the H9 writer's real shape)"

# --- Fixture A: mt engine, to confirm both engines agree on the converged 'partial + continuation' row ---
check_fixture "mt" 101 "continuation" "implement" \
  "Fixture A (flat continuation_path only) cross-engine agreement"

# --- Fixture B: nested form, no regression ---
check_fixture "single" 102 "continuation" "implement" \
  "Fixture B (nested continuation_context.handoff_path, pre-existing behavior)"
check_fixture "mt" 102 "continuation" "implement" \
  "Fixture B (nested continuation_context.handoff_path) cross-engine agreement"

# --- Fixture C: both forms null, still empty ---
check_fixture "single" 103 "empty" "implement" \
  "Fixture C (both forms null, anti-over-relaxation guard)"
check_fixture "mt" 103 "empty" "implement" \
  "Fixture C (both forms null) cross-engine agreement"

# --- Fixture D: continuation outranks blockers ---
check_fixture "single" 104 "continuation" "implement" \
  "Fixture D (continuation_path populated AND blockers non-empty; continuation must outrank blockers)"
check_fixture "mt" 104 "continuation" "implement" \
  "Fixture D (continuation outranks blockers) cross-engine agreement"

# =====================================================================
# Full status-to-group coverage (EXTENSION to this suite's original `partial`-only scope): every
# status-to-group row for both engines EXCEPT `researching`/`planning` (those two rows' fixtures
# are added, and demonstrated RED against the pre-fix classifier, by the change that maps them —
# not here). This gives a green baseline that would catch collateral damage from that later
# change. None of these fixtures carry a status of `partial`, so none needs an
# .orchestrator-handoff.json file — the classifier only reads a handoff for `partial` candidates.
# =====================================================================

cat > "$WORKDIR/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 105, "project_name": "fixture_not_started", "status": "not_started"},
    {"project_number": 106, "project_name": "fixture_researched", "status": "researched"},
    {"project_number": 107, "project_name": "fixture_planned", "status": "planned"},
    {"project_number": 108, "project_name": "fixture_implementing", "status": "implementing"},
    {"project_number": 109, "project_name": "fixture_terminal", "status": "completed"},
    {"project_number": 110, "project_name": "fixture_garbage_status", "status": "not_a_real_status"}
  ]
}
EOF

# --- not_started: mt engine (pairs with the single-engine sandbox probe above) ---
# Research-first default (no --effort or --effort hard): not_started routes to research. Passing
# --effort fast preserves the prior plan-first behavior as an escape hatch -- the planner can
# still request research via needs_research if the description does not suffice. See the
# researching -> research mutation-check fixture (project 112) below for the always-research row.
check_fixture "mt" 105 "not_applicable" "research" \
  "not_started (mt engine, pairs with the single-engine sandbox probe) -- research-first default, no --effort"
check_fixture_effort "" "single" 105 "not_applicable" "research" \
  "not_started (single engine) -- research-first default, no --effort"
check_fixture_effort "fast" "single" 105 "not_applicable" "plan" \
  "not_started (single engine) -- --effort fast preserves plan-first"
check_fixture_effort "fast" "mt" 105 "not_applicable" "plan" \
  "not_started (mt engine) -- --effort fast preserves plan-first"
check_fixture_effort "hard" "single" 105 "not_applicable" "research" \
  "not_started (single engine) -- --effort hard is NOT --fast, stays research-first"

# --- researched -> plan, both engines (unaffected by --effort; a report already exists) ---
check_fixture "single" 106 "not_applicable" "plan" \
  "researched -> plan"
check_fixture "mt" 106 "not_applicable" "plan" \
  "researched -> plan cross-engine agreement"
check_fixture_effort "fast" "single" 106 "not_applicable" "plan" \
  "researched -> plan even under --effort fast (never re-researches)"

# --- planned -> implement, both engines ---
check_fixture "single" 107 "not_applicable" "implement" \
  "planned -> implement"
check_fixture "mt" 107 "not_applicable" "implement" \
  "planned -> implement cross-engine agreement"

# --- implementing -> implement, both engines ---
check_fixture "single" 108 "not_applicable" "implement" \
  "implementing -> implement"
check_fixture "mt" 108 "not_applicable" "implement" \
  "implementing -> implement cross-engine agreement"

# --- terminal status -> terminal, both engines ---
check_fixture "single" 109 "not_applicable" "terminal" \
  "terminal status (completed) -> terminal"
check_fixture "mt" 109 "not_applicable" "terminal" \
  "terminal status (completed) -> terminal cross-engine agreement"

# --- unrecognized/garbage status -> skip, both engines ---
check_fixture "single" 110 "not_applicable" "skip" \
  "unrecognized status string -> skip"
check_fixture "mt" 110 "not_applicable" "skip" \
  "unrecognized status string -> skip cross-engine agreement"

# =====================================================================
# Discriminated blocked sub-cases (REPLACES the old single fixture_blocked divergence pair --
# `blocked` is no longer unconditional; see orchestrate-triage-classify.sh's own header table and
# justification paragraph for the full discriminator). All six sub-cases below share one
# state.json so cross-referenced dependency lookups resolve within a single classifier
# invocation. Per-candidate check_fixture calls below pass exactly ONE task number each -- the
# discharged fixture (120)'s dependency (121) is present in state.json but is NEVER itself passed
# as a classifier argument, which is exactly what distinguishes the correct state.json-lookup
# mechanism from an incorrect candidate-list-membership mechanism (a membership-based
# implementation would read dependency 121 as absent from the argument list and fail this case).
# =====================================================================

mkdir -p "$WORKDIR/specs/122_fixture_discharged_blockers"

cat > "$WORKDIR/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 120, "project_name": "fixture_discharged", "status": "blocked", "previous_status": "planned", "dependencies": [121]},
    {"project_number": 121, "project_name": "fixture_dep_completed", "status": "completed"},
    {"project_number": 122, "project_name": "fixture_discharged_blockers", "status": "blocked", "previous_status": "planned", "dependencies": [121]},
    {"project_number": 123, "project_name": "fixture_dep_outstanding", "status": "blocked", "previous_status": "planned", "dependencies": [124]},
    {"project_number": 124, "project_name": "fixture_dep_researching", "status": "researching"},
    {"project_number": 125, "project_name": "fixture_dep_abandoned", "status": "blocked", "previous_status": "planned", "dependencies": [126]},
    {"project_number": 126, "project_name": "fixture_dep_abandoned_target", "status": "abandoned"},
    {"project_number": 127, "project_name": "fixture_empty_deps", "status": "blocked", "previous_status": "planned", "dependencies": []},
    {"project_number": 128, "project_name": "fixture_missing_prev_status", "status": "blocked", "dependencies": [121]},
    {"project_number": 129, "project_name": "fixture_discharged_not_started", "status": "blocked", "previous_status": "not_started", "dependencies": [121]}
  ]
}
EOF

# Sub-case (b) needs a handoff carrying non-empty blockers -- directory name must match this
# candidate's OWN project_name (122_fixture_discharged_blockers), not its dependency's.
cat > "$WORKDIR/specs/122_fixture_discharged_blockers/.orchestrator-handoff.json" <<'EOF'
{"continuation_context": null, "continuation_path": null, "blockers": ["some unresolved blocker"]}
EOF

# --- (a) discharged: sole dependency completed, previous_status set, no handoff -- routes via
# previous_status to the group it names, for BOTH engines. Dependency 121 is NOT passed as a
# classifier argument below -- see this block's header comment. ---
check_fixture "single" 120 "absent" "implement" \
  "blocked, discharged (dependency completed, previous_status=planned) -> implement"
check_fixture "mt" 120 "absent" "implement" \
  "blocked, discharged (dependency completed, previous_status=planned) -> implement cross-engine agreement"

# --- (a2) discharged, previous_status=not_started -- research-first default: routes to research,
# mirroring the live not_started row's own flip. --effort fast preserves plan-first here too.
# Dependency 121 is NOT passed as a classifier argument below, same mechanism-discrimination
# shape as (a) above. ---
check_fixture "single" 129 "absent" "research" \
  "blocked, discharged (dependency completed, previous_status=not_started) -> research (research-first default)"
check_fixture "mt" 129 "absent" "research" \
  "blocked, discharged (dependency completed, previous_status=not_started) -> research cross-engine agreement"
check_fixture_effort "fast" "single" 129 "absent" "plan" \
  "blocked, discharged (previous_status=not_started) -> plan under --effort fast, mirrors the live row"
check_fixture_effort "fast" "mt" 129 "absent" "plan" \
  "blocked, discharged (previous_status=not_started) -> plan under --effort fast cross-engine agreement"

# --- (b) discharged but handoff blockers present -- needs_human overrides discharge, BOTH engines ---
check_fixture "single" 122 "blockers" "needs_human" \
  "blocked, discharged but handoff blockers present -> needs_human"
check_fixture "mt" 122 "blockers" "needs_human" \
  "blocked, discharged but handoff blockers present -> needs_human cross-engine agreement"

# --- (c) dependency still outstanding (researching, not completed) -- unchanged divergent shape:
# skip (mt) / needs_human (single) ---
check_fixture "single" 123 "absent" "needs_human" \
  "blocked, dependency outstanding (researching) -> needs_human (single)"
check_fixture "mt" 123 "absent" "skip" \
  "blocked, dependency outstanding (researching) -> skip (mt)"

# --- (d) dependency reached a non-completed terminal status (abandoned) -- needs_human, BOTH
# engines, since this precondition can never be met (never the broader is_terminal discharge) ---
check_fixture "single" 125 "absent" "needs_human" \
  "blocked, dependency abandoned -> needs_human"
check_fixture "mt" 125 "absent" "needs_human" \
  "blocked, dependency abandoned -> needs_human cross-engine agreement"

# --- (e) empty dependencies[] -- must never vacuously discharge; unchanged divergent shape:
# skip (mt) / needs_human (single) ---
check_fixture "single" 127 "absent" "needs_human" \
  "blocked, empty dependencies[] -> needs_human (single, never vacuous discharge)"
check_fixture "mt" 127 "absent" "skip" \
  "blocked, empty dependencies[] -> skip (mt, never vacuous discharge)"

# --- (f) discharged (dependency completed) but previous_status missing -- needs_human, BOTH
# engines, never guesses the discharge target phase ---
check_fixture "single" 128 "absent" "needs_human" \
  "blocked, discharged but previous_status missing -> needs_human (never guesses)"
check_fixture "mt" 128 "absent" "needs_human" \
  "blocked, discharged but previous_status missing -> needs_human cross-engine agreement"

# =====================================================================
# Mutation-check fixtures (per context/standards/shell-script-testing.md): researching -> research
# and planning -> plan, both engines. These are RUN AND CONFIRMED RED against the pre-fix
# classifier (`git show HEAD:` copy) BEFORE the jq arms are added -- see the phase's commit body
# for the captured RED output. Pre-fix, both statuses fall through to the classifier's final
# `else` arm and are emitted as group "skip" (reason: "transitional/unknown"), matching the
# now-removed header table row `| researching, planning, unknown | skip | skip |`.
# =====================================================================

cat > "$WORKDIR/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 112, "project_name": "fixture_researching", "status": "researching"},
    {"project_number": 113, "project_name": "fixture_planning", "status": "planning"}
  ]
}
EOF

check_fixture "single" 112 "not_applicable" "research" \
  "researching -> research (mutation-check fixture)"
check_fixture "mt" 112 "not_applicable" "research" \
  "researching -> research cross-engine agreement (mutation-check fixture)"
check_fixture "single" 113 "not_applicable" "plan" \
  "planning -> plan (mutation-check fixture)"
check_fixture "mt" 113 "not_applicable" "plan" \
  "planning -> plan cross-engine agreement (mutation-check fixture)"

# --effort fast must NOT skip a research phase the planner explicitly requested by returning
# needs_research (status researching): only the not_started rows read effort.
check_fixture_effort "fast" "single" 112 "not_applicable" "research" \
  "researching -> research even under --effort fast (planner-requested research never skipped)"
check_fixture_effort "fast" "mt" 112 "not_applicable" "research" \
  "researching -> research even under --effort fast cross-engine agreement"

# =====================================================================
# Invalid --effort value: exits 2 with a loud stderr line, matching the unknown-engine precedent.
# =====================================================================

invalid_out="$(bash "$TOOL" --effort bogus single 112 2>&1)"
invalid_exit=$?
if [ "$invalid_exit" -eq 2 ] && echo "$invalid_out" | grep -qF -- "--effort must be 'fast' or 'hard'"; then
  pass "--effort bogus -> exit 2 with loud stderr line"
else
  fail "--effort bogus -> expected exit 2 with '--effort must be fast or hard' message, got exit=$invalid_exit output=$invalid_out"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
