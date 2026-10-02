#!/usr/bin/env bash
# test-validate-state.sh - Fixture-driven regression suite for scripts/validate-state.sh.
#
# Four seeded defect fixtures (stray undocumented field, duplicate project_number, off-schema
# status, dangling dependency), each asserted to produce a nonzero exit and a named error line,
# plus a positive fixture asserting exit 0 on valid state.
#
# Structural model: scripts/tests/test-validate-handoff.sh / test-phase-heading-patterns.sh
# (pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (validate-state.sh not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

VALIDATOR_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
  "$SCRIPT_DIR/../validate-state.sh"
)
VALIDATOR=""
for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    VALIDATOR="$candidate"
    break
  fi
done
if [[ -z "$VALIDATOR" ]]; then
  echo "ERROR: validate-state.sh not found at any of:" >&2
  for candidate in "${VALIDATOR_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

# --- D5 (per-type artifact-loss) validator resolution ---
# Deliberately source-store-first (opposite order from VALIDATOR_CANDIDATES above), because the
# D5 fixtures below must exercise the new check without depending on a prior deploy step. Every
# candidate is still verified via grep for the check's identifier ("Check D5") before being
# trusted -- this is what prevents a stale deployed copy from producing a false green, per the
# suite's existing structural precedent (VALIDATOR resolution above).
D5_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
D5_VALIDATOR=""
for candidate in "${D5_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check D5" "$candidate" 2>/dev/null; then
    D5_VALIDATOR="$candidate"
    break
  fi
done

# --- Check 8 / Check 9 (coarse + duplicate file_scope) validator resolution ---
# Same source-store-first precedent as D5_VALIDATOR above, for the same reason: these fixtures
# must exercise the new checks without depending on a prior deploy step. A candidate is trusted
# only after grepping for BOTH check identifiers ("Check 8" and "Check 9"), so a stale deployed
# copy that has one but not the other cannot produce a false green.
FS_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
FS_VALIDATOR=""
for candidate in "${FS_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check 8" "$candidate" 2>/dev/null && grep -q "Check 9" "$candidate" 2>/dev/null; then
    FS_VALIDATOR="$candidate"
    break
  fi
done

# --- Check 10 / Check 11 (missing/null/empty + glob file_scope) validator resolution ---
# Same source-store-first precedent as FS_VALIDATOR above. A candidate is trusted only after
# grepping for BOTH check identifiers ("Check 10" and "Check 11"), so a stale deployed copy that
# has one but not the other cannot produce a false green.
SCOPE_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
SCOPE_VALIDATOR=""
for candidate in "${SCOPE_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check 10" "$candidate" 2>/dev/null && grep -q "Check 11" "$candidate" 2>/dev/null; then
    SCOPE_VALIDATOR="$candidate"
    break
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# =====================================================================
# Positive fixture: valid state -> exit 0
# =====================================================================
cat > "$WORKDIR/valid-state.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    },
    {
      "project_number": 2,
      "project_name": "beta",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/valid-state.json" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]]; then
  pass "positive fixture: valid state exits 0"
else
  fail "positive fixture: expected exit 0, got $rc"
  info "$out"
fi

out_deep=$(bash "$VALIDATOR" --deep "$WORKDIR/valid-state.json" 2>&1)
rc_deep=$?
if [[ "$rc_deep" -eq 0 ]]; then
  pass "positive fixture: valid state exits 0 under --deep"
else
  fail "positive fixture: expected exit 0 under --deep, got $rc_deep"
  info "$out_deep"
fi

# =====================================================================
# Positive fixture: hold status + the three new entry fields -> exit 0
# =====================================================================
cat > "$WORKDIR/hold-state.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "hold",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [],
      "hold_reason": "Awaiting upstream decision",
      "held_at": "2026-01-01",
      "prior_status": "planned"
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/hold-state.json" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]]; then
  pass "positive fixture: status 'hold' + hold_reason/held_at/prior_status exits 0 (no off-schema-status FAIL, no unknown-entry-field FAIL)"
else
  fail "positive fixture: hold state expected exit 0, got $rc"
  info "$out"
fi

out_deep=$(bash "$VALIDATOR" --deep "$WORKDIR/hold-state.json" 2>&1)
rc_deep=$?
if [[ "$rc_deep" -eq 0 ]]; then
  pass "positive fixture: hold state exits 0 under --deep"
else
  fail "positive fixture: hold state expected exit 0 under --deep, got $rc_deep"
  info "$out_deep"
fi

# =====================================================================
# Defect fixture 1: stray undocumented field (top-level)
#
# NOTE: Checks 3/4 moved from hard-FAIL to an advisory-first WARN-by-default posture (see
# validate-state.sh's own PROMOTION CRITERION comment above Check 3). This fixture's expectation
# was updated accordingly: default mode now reports a named WARN with exit 0, and a companion
# --strict case proves the field is still detectable/escalatable, preserving this fixture's
# original detection intent without re-asserting the now-superseded hard-FAIL behavior.
# =====================================================================
cat > "$WORKDIR/stray-field.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    }
  ],
  "totally_undocumented_field": "should trigger a WARN (advisory-first, not FAIL)"
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/stray-field.json" 2>&1)
rc=$?
if [[ "$rc" -eq 0 ]] && grep -q "\[WARN\].*Unknown top-level field: totally_undocumented_field" <<< "$out"; then
  pass "defect fixture: stray top-level field -> advisory WARN with named field, exit 0 (default mode)"
else
  fail "defect fixture: stray top-level field did not produce the expected WARN + exit 0 (rc=$rc)"
  info "$out"
fi

out=$(bash "$VALIDATOR" --strict "$WORKDIR/stray-field.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Unknown top-level field: totally_undocumented_field" <<< "$out"; then
  pass "defect fixture: stray top-level field -> nonzero exit with named error under --strict"
else
  fail "defect fixture: stray top-level field did not produce the expected nonzero exit + named error under --strict (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 2: duplicate project_number (--deep)
# =====================================================================
cat > "$WORKDIR/dup-pnum.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "completed",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    },
    {
      "project_number": 1,
      "project_name": "alpha-dup",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": []
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" --deep "$WORKDIR/dup-pnum.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Duplicate project_number: 1" <<< "$out"; then
  pass "defect fixture: duplicate project_number -> nonzero exit with named error"
else
  fail "defect fixture: duplicate project_number did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 3: off-schema status
# =====================================================================
cat > "$WORKDIR/bad-status.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "foobar",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": []
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" "$WORKDIR/bad-status.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "off-schema status 'foobar'" <<< "$out"; then
  pass "defect fixture: off-schema status -> nonzero exit with named error"
else
  fail "defect fixture: off-schema status did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Defect fixture 4: dangling dependency (--deep)
# =====================================================================
cat > "$WORKDIR/dangling-dep.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [999]
    }
  ]
}
JSON

out=$(bash "$VALIDATOR" --deep "$WORKDIR/dangling-dep.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Dangling dependency reference: 1 -> 999" <<< "$out"; then
  pass "defect fixture: dangling dependency -> nonzero exit with named error"
else
  fail "defect fixture: dangling dependency did not produce the expected nonzero exit + named error (rc=$rc)"
  info "$out"
fi

# =====================================================================
# Bonus: self-referential dependency and cycle detection (--deep), beyond the four required
# fixtures but exercising the same D3 code path.
# =====================================================================
cat > "$WORKDIR/self-ref.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON
out=$(bash "$VALIDATOR" --deep "$WORKDIR/self-ref.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Self-referential dependencies" <<< "$out"; then
  pass "bonus fixture: self-referential dependency -> nonzero exit with named error"
else
  fail "bonus fixture: self-referential dependency did not produce the expected result (rc=$rc)"
  info "$out"
fi

cat > "$WORKDIR/cycle.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "alpha",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [2]
    },
    {
      "project_number": 2,
      "project_name": "beta",
      "status": "not_started",
      "task_type": "general",
      "created": "2026-01-02T00:00:00Z",
      "last_updated": "2026-01-02T00:00:00Z",
      "dependencies": [1]
    }
  ]
}
JSON
out=$(bash "$VALIDATOR" --deep "$WORKDIR/cycle.json" 2>&1)
rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "Dependency cycle detected" <<< "$out"; then
  pass "bonus fixture: dependency cycle -> nonzero exit with named error"
else
  fail "bonus fixture: dependency cycle did not produce the expected result (rc=$rc)"
  info "$out"
fi

# =====================================================================
# D5 per-type artifact-loss invariant fixtures (git-backed, both directions of the verification
# bar: rejection and the same write accepted under --allow-artifact-removal), plus regression,
# pure-append, untyped-entry, and scoped-flag cases.
# =====================================================================
if [[ -z "$D5_VALIDATOR" ]]; then
  info "SKIPPING D5 fixtures: no candidate validator (source-store or deployed) contains the D5"
  info "per-type artifact-loss check (grepped for \"Check D5\"). Candidates checked:"
  for candidate in "${D5_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "D5 fixtures running against: $D5_VALIDATOR (confirmed to contain the D5 check)"

  # Creates a fresh git-backed fixture repo under $1 with a committed baseline state.json
  # containing project_number 42 with: 1 report, 1 plan, 5 summaries (mirroring the observed
  # 5-dropped incident shape), and 2 untyped entries (no .type field). Required because D5 reads
  # the *prior committed* version via git show -- a non-git fixture cannot exercise it.
  make_d5_baseline() {
    local repo_dir="$1"
    mkdir -p "$repo_dir/specs"
    cat > "$repo_dir/specs/state.json" <<'JSON'
{
  "next_project_number": 43,
  "active_projects": [
    {
      "project_number": 42,
      "project_name": "d5-fixture",
      "status": "implementing",
      "task_type": "general",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "dependencies": [],
      "artifacts": [
        {"path": "specs/042_d5/reports/01_r1.md", "type": "report", "summary": "r1"},
        {"path": "specs/042_d5/plans/01_p1.md", "type": "plan", "summary": "p1"},
        {"path": "specs/042_d5/summaries/01_s1.md", "type": "summary", "summary": "s1"},
        {"path": "specs/042_d5/summaries/02_s2.md", "type": "summary", "summary": "s2"},
        {"path": "specs/042_d5/summaries/03_s3.md", "type": "summary", "summary": "s3"},
        {"path": "specs/042_d5/summaries/04_s4.md", "type": "summary", "summary": "s4"},
        {"path": "specs/042_d5/summaries/05_s5.md", "type": "summary", "summary": "s5"},
        {"path": "specs/042_d5/notes/01_n1.md", "summary": "n1"},
        {"path": "specs/042_d5/notes/02_n2.md", "summary": "n2"}
      ]
    }
  ]
}
JSON
    git -C "$repo_dir" init -q
    git -C "$repo_dir" config user.email "d5-fixture@example.com"
    git -C "$repo_dir" config user.name "D5 Fixture"
    git -C "$repo_dir" add specs/state.json
    git -C "$repo_dir" commit -q -m "baseline"
  }

  # --- Negative fixture (rejection): raw jq-composed write dropping all 5 summaries, adding 2 ---
  # This mirrors the observed 5-dropped/2-added incident shape, and the mutation is a literal,
  # hand-composed `jq '... .artifacts = [...]' > tmp && mv tmp state.json` sequence -- not a
  # helper call -- which is what proves the check is writer-agnostic.
  d5_neg_dir="$WORKDIR/d5-negative"
  make_d5_baseline "$d5_neg_dir"
  d5_neg_state="$d5_neg_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "summary" | not)]
        + [{"path":"specs/042_d5/summaries/06_s6.md","type":"summary","summary":"s6"},
           {"path":"specs/042_d5/summaries/07_s7.md","type":"summary","summary":"s7"}]' \
    "$d5_neg_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_neg_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_neg_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "Artifact loss: project_number 42, type 'summary'" <<< "$out" \
      && grep -q "removed=5 added=2" <<< "$out"; then
    pass "D5 negative fixture: 5-dropped/2-added summary loss (raw jq write) -> FAIL naming project, type, counts, paths"
  else
    fail "D5 negative fixture: expected FAIL naming project 42/type summary/removed=5 added=2 (rc=$rc)"
    info "$out"
  fi

  # --- Positive fixture (opt-in accepted): the IDENTICAL mutated fixture, re-run with the flag ---
  out=$(bash "$D5_VALIDATOR" --deep --allow-artifact-removal 42 "$d5_neg_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "ALLOWED by --allow-artifact-removal" <<< "$out"; then
    pass "D5 positive fixture: identical mutation accepted under --allow-artifact-removal 42, opt-in line logged"
  else
    fail "D5 positive fixture: expected exit 0 with opt-in line under --allow-artifact-removal 42 (rc=$rc)"
    info "$out"
  fi

  # --- Regression fixture (sanctioned supersession): 1-for-1 same-type (report) replacement ---
  d5_reg_dir="$WORKDIR/d5-regression"
  make_d5_baseline "$d5_reg_dir"
  d5_reg_state="$d5_reg_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "report" | not)]
        + [{"path":"specs/042_d5/reports/02_r2.md","type":"report","summary":"r2"}]' \
    "$d5_reg_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_reg_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_reg_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Artifact loss" <<< "$out"; then
    pass "D5 regression fixture: 1-for-1 same-type (report) supersession passes with no finding"
  else
    fail "D5 regression fixture: expected exit 0 with no artifact-loss finding for 1-for-1 report supersession (rc=$rc)"
    info "$out"
  fi

  # --- Pure-append fixture: adding one artifact with nothing removed ---
  d5_app_dir="$WORKDIR/d5-append"
  make_d5_baseline "$d5_app_dir"
  d5_app_state="$d5_app_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts += [{"path":"specs/042_d5/reports/02_r2.md","type":"report","summary":"r2"}]' \
    "$d5_app_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_app_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_app_state" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Artifact loss" <<< "$out"; then
    pass "D5 pure-append fixture: adding one artifact with nothing removed passes with no finding"
  else
    fail "D5 pure-append fixture: expected exit 0 with no artifact-loss finding (rc=$rc)"
    info "$out"
  fi

  # --- Untyped-entry fixture: dropping both untyped entries, adding none ---
  d5_unt_dir="$WORKDIR/d5-untyped"
  make_d5_baseline "$d5_unt_dir"
  d5_unt_state="$d5_unt_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(has("type"))]' \
    "$d5_unt_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_unt_state"

  out=$(bash "$D5_VALIDATOR" --deep "$d5_unt_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "type '(untyped)'" <<< "$out" && grep -q "removed=2 added=0" <<< "$out"; then
    pass "D5 untyped-entry fixture: dropping 2 untyped entries with none added -> FAIL under sentinel grouping"
  else
    fail "D5 untyped-entry fixture: expected FAIL naming type (untyped), removed=2 added=0 (rc=$rc)"
    info "$out"
  fi

  # --- Scoped-flag fixture: wrong-type opt-in must not over-permit a different type's loss ---
  d5_scoped_dir="$WORKDIR/d5-scoped"
  make_d5_baseline "$d5_scoped_dir"
  d5_scoped_state="$d5_scoped_dir/specs/state.json"
  d5_tmp="$(mktemp)"
  jq '(.active_projects[0]).artifacts =
        [(.active_projects[0]).artifacts[] | select(.type == "summary" | not)]
        + [{"path":"specs/042_d5/summaries/06_s6.md","type":"summary","summary":"s6"},
           {"path":"specs/042_d5/summaries/07_s7.md","type":"summary","summary":"s7"}]' \
    "$d5_scoped_state" > "$d5_tmp" && mv "$d5_tmp" "$d5_scoped_state"

  out=$(bash "$D5_VALIDATOR" --deep --allow-artifact-removal 42:report "$d5_scoped_state" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "Artifact loss: project_number 42, type 'summary'" <<< "$out"; then
    pass "D5 scoped-flag fixture: --allow-artifact-removal 42:report does not over-permit a summary-type loss"
  else
    fail "D5 scoped-flag fixture: expected FAIL for summary loss even with --allow-artifact-removal 42:report (rc=$rc)"
    info "$out"
  fi
fi

# =====================================================================
# Check 8 (coarse blast-radius) / Check 9 (duplicate) / --fix fixtures
# =====================================================================
if [[ -z "$FS_VALIDATOR" ]]; then
  info "SKIPPING Check 8/Check 9/--fix fixtures: no candidate validator (source-store or"
  info "deployed) contains BOTH Check 8 and Check 9 (grepped for \"Check 8\" and \"Check 9\")."
  info "Candidates checked:"
  for candidate in "${FS_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "Check 8/Check 9/--fix fixtures running against: $FS_VALIDATOR (confirmed to contain Check 8 and Check 9)"

  # --- Check 8 fixture: one directory-shaped entry overlapping >= 3 non-terminal tasks ---
  # project_number 1 declares "shared/lib/" (trailing slash); 2, 3, 4 each declare a distinct
  # file underneath it, so scopes_overlap_first fires for all three -> blast radius 3, meeting the
  # N=3 default threshold.
  cat > "$WORKDIR/coarse-fixture.json" <<'JSON'
{
  "next_project_number": 5,
  "active_projects": [
    {"project_number": 1, "project_name": "a", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "file_scope": ["shared/lib/"]},
    {"project_number": 2, "project_name": "b", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "file_scope": ["shared/lib/foo.sh"]},
    {"project_number": 3, "project_name": "c", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "file_scope": ["shared/lib/bar.sh"]},
    {"project_number": 4, "project_name": "d", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "file_scope": ["shared/lib/baz.sh"]}
  ]
}
JSON
  out=$(bash "$FS_VALIDATOR" "$WORKDIR/coarse-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "Coarse file_scope declaration: project_number 1, entry 'shared/lib/' overlaps 3 distinct non-terminal task(s): 2,3,4" <<< "$out"; then
    pass "Check 8 fixture: coarse directory-shaped entry overlapping 3 non-terminal tasks -> named WARN, exit 0"
  else
    fail "Check 8 fixture: expected exit 0 with the named Check 8 WARN line (rc=$rc)"
    info "$out"
  fi

  # --- Threshold fixture: same coarse fixture, FILE_SCOPE_COARSE_MIN_OVERLAP above the measured
  # radius (3) -> no Coarse WARN ---
  out=$(FILE_SCOPE_COARSE_MIN_OVERLAP=4 bash "$FS_VALIDATOR" "$WORKDIR/coarse-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Coarse file_scope declaration" <<< "$out"; then
    pass "Check 8 threshold fixture: FILE_SCOPE_COARSE_MIN_OVERLAP=4 (above the measured radius of 3) suppresses the WARN"
  else
    fail "Check 8 threshold fixture: expected exit 0 with no Coarse WARN under min-overlap=4 (rc=$rc)"
    info "$out"
  fi

  # --- Check 9 fixture: one exact duplicate (Class A) and one normalization-equivalent pair
  # (Class B) in the same file_scope array -> both classes fire with distinct labels, exit 0 ---
  cat > "$WORKDIR/dup-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {"project_number": 1, "project_name": "a", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "file_scope": ["docs/README.md", "docs/README.md", "src/foo/", "src/foo"]}
  ]
}
JSON
  out=$(bash "$FS_VALIDATOR" "$WORKDIR/dup-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "Duplicate file_scope entry (Class A, exact -- repairable by --fix): project_number 1, entry 'docs/README.md' appears 2 times" <<< "$out" \
      && grep -q "Duplicate file_scope entry (Class B, normalization-equivalent -- NOT auto-repaired): project_number 1, entries 'src/foo' and 'src/foo/' collide after normalization" <<< "$out"; then
    pass "Check 9 fixture: exact duplicate (Class A) and normalization-equivalent (Class B) both fire with distinct labels, exit 0"
  else
    fail "Check 9 fixture: expected exit 0 with both Class A and Class B WARN lines (rc=$rc)"
    info "$out"
  fi

  # --- --fix fixture: exact duplicates removed order-preservingly (project 1, Class A),
  # Class B untouched (project 2), null-valued file_scope untouched (project 3 -- this is the
  # crash-triggering shape: has("file_scope") is true for a literal null, so a has()-gated
  # mutation filter aborts jq mid-reduce on this entry), absent-key file_scope untouched
  # (project 4), other fields unchanged. D3 requires --fix to write ONLY through a DEPLOYED
  # state-write.sh, so this fixture's state file is placed inside THIS repo's own git tree
  # (under specs/) rather than the generic $WORKDIR (which sits outside the repo, under /tmp,
  # where no deployed tree can resolve) -- letting the D3 git-toplevel candidate reach the real
  # deployed .claude/scripts/state-write.sh, exactly as a real invocation would. Gracefully
  # SKIPPED (not FAILED) when no deployed state-write.sh exists yet (e.g. before a first deploy).
  if [[ -f "$REPO_ROOT/.claude/scripts/state-write.sh" ]]; then
    FIX_FIXTURE_DIR="$REPO_ROOT/specs/_tmp_fso_fix_fixture_$$"
    mkdir -p "$FIX_FIXTURE_DIR"
    cat > "$FIX_FIXTURE_DIR/state.json" <<'JSON'
{
  "next_project_number": 5,
  "active_projects": [
    {"project_number": 1, "project_name": "a", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "dependencies": [],
     "file_scope": ["docs/README.md", "src/foo.lua", "docs/README.md", "src/bar.lua", "src/foo.lua"]},
    {"project_number": 2, "project_name": "b", "status": "not_started", "task_type": "general",
     "created": "2026-01-02T00:00:00Z", "last_updated": "2026-01-02T00:00:00Z",
     "dependencies": [],
     "file_scope": ["src/foo/", "src/foo"]},
    {"project_number": 3, "project_name": "c", "status": "not_started", "task_type": "general",
     "created": "2026-01-03T00:00:00Z", "last_updated": "2026-01-03T00:00:00Z",
     "dependencies": [],
     "file_scope": null},
    {"project_number": 4, "project_name": "d", "status": "not_started", "task_type": "general",
     "created": "2026-01-04T00:00:00Z", "last_updated": "2026-01-04T00:00:00Z",
     "dependencies": []}
  ]
}
JSON
    cp "$FIX_FIXTURE_DIR/state.json" "$FIX_FIXTURE_DIR/state.json.orig"

    out=$(bash "$FS_VALIDATOR" --fix "$FIX_FIXTURE_DIR/state.json" 2>&1)
    rc=$?
    fix_fs1=$(jq -c '.active_projects[] | select(.project_number==1) | .file_scope' "$FIX_FIXTURE_DIR/state.json" 2>/dev/null)
    fix_fs2=$(jq -c '.active_projects[] | select(.project_number==2) | .file_scope' "$FIX_FIXTURE_DIR/state.json" 2>/dev/null)
    fix_p3_null=$(jq -r '.active_projects[] | select(.project_number==3) | [has("file_scope"), (.file_scope == null)] | @tsv' "$FIX_FIXTURE_DIR/state.json" 2>/dev/null)
    fix_p4_has_key=$(jq -r '.active_projects[] | select(.project_number==4) | has("file_scope")' "$FIX_FIXTURE_DIR/state.json" 2>/dev/null)
    fix_other_diff=$(diff <(jq -S 'del(.active_projects[].file_scope)' "$FIX_FIXTURE_DIR/state.json.orig") \
                           <(jq -S 'del(.active_projects[].file_scope)' "$FIX_FIXTURE_DIR/state.json"))
    if [[ "$rc" -eq 0 ]] \
        && [[ "$fix_fs1" == '["docs/README.md","src/foo.lua","src/bar.lua"]' ]] \
        && [[ "$fix_fs2" == '["src/foo/","src/foo"]' ]] \
        && [[ "$fix_p3_null" == $'true\ttrue' ]] \
        && [[ "$fix_p4_has_key" == "false" ]] \
        && [[ -z "$fix_other_diff" ]] \
        && ! grep -q -- '--fix: state-write.sh failed' <<< "$out"; then
      pass "--fix fixture: exact duplicates removed order-preservingly (project 1), Class B untouched (project 2), null-valued file_scope untouched (project 3), absent-key file_scope untouched (project 4), other fields unchanged"
    else
      fail "--fix fixture: expected order-preserving dedup on project 1, untouched Class B on project 2, null-valued project 3 untouched, absent-key project 4 untouched, unchanged other fields, and no state-write.sh failure (rc=$rc)"
      info "$out"
      info "project 1 file_scope: $fix_fs1"
      info "project 2 file_scope: $fix_fs2"
      info "project 3 has(file_scope)\\tis-null: $fix_p3_null"
      info "project 4 has(file_scope): $fix_p4_has_key"
      info "other-fields diff: $fix_other_diff"
    fi
    rm -rf "$FIX_FIXTURE_DIR"
  else
    info "SKIPPING --fix fixture: no deployed state-write.sh at $REPO_ROOT/.claude/scripts/state-write.sh"
    info "(run bash .claude/scripts/deploy-headless.sh first, then re-run this suite)"
  fi
fi

# =====================================================================
# Check 10 (missing/null/empty file_scope) / Check 11 (glob file_scope) / --strict / --fix
# non-manufacture fixtures
# =====================================================================
if [[ -z "$SCOPE_VALIDATOR" ]]; then
  info "SKIPPING Check 10/Check 11/--strict fixtures: no candidate validator (source-store or"
  info "deployed) contains BOTH Check 10 and Check 11 (grepped for \"Check 10\" and \"Check 11\")."
  info "Candidates checked:"
  for candidate in "${SCOPE_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "Check 10/Check 11/--strict fixtures running against: $SCOPE_VALIDATOR (confirmed to contain Check 10 and Check 11)"

  # --- Check 10 fixture: one entry each of missing_key / null_value / empty_array / a concrete
  # (unaffected) entry, all non-terminal -> all three sub-state WARN lines, the summary counts,
  # and exit 0 ---
  cat > "$WORKDIR/scope10-fixture.json" <<'JSON'
{
  "next_project_number": 5,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-missing", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"},
    {"project_number": 2, "project_name": "cand-null", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": null},
    {"project_number": 3, "project_name": "cand-empty", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": []},
    {"project_number": 4, "project_name": "cand-ok", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["a/b.sh"]}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "file_scope missing_key: project_number 1 (cand-missing)" <<< "$out" \
      && grep -q "file_scope null_value: project_number 2 (cand-null)" <<< "$out" \
      && grep -q "file_scope empty_array: project_number 3 (cand-empty)" <<< "$out" \
      && grep -q "file_scope visibility: 1 missing-key, 1 literal-null, 1 empty-array, out of 4 non-terminal task(s)" <<< "$out"; then
    pass "Check 10 fixture: missing_key/null_value/empty_array all fire with distinct sub-state lines plus a summary count line, exit 0"
  else
    fail "Check 10 fixture: expected exit 0 with all three sub-state WARN lines plus the summary line (rc=$rc)"
    info "$out"
  fi

  # --- Check 10 negative fixture: the sole non-terminal entry declares a concrete non-empty
  # file_scope -> the log_pass negative fires, no Check 10 WARN ---
  cat > "$WORKDIR/scope10-negative-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-ok", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["a/b.sh"]}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-negative-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "No missing/null/empty file_scope found among 1 non-terminal task(s)" <<< "$out" \
      && ! grep -q "file_scope visibility:" <<< "$out"; then
    pass "Check 10 negative fixture: every non-terminal entry declares a non-empty file_scope -> log_pass, no WARN"
  else
    fail "Check 10 negative fixture: expected exit 0 with the log_pass negative and no Check 10 WARN (rc=$rc)"
    info "$out"
  fi

  # --- Check 10 terminal-exclusion fixture: a completed entry with no file_scope key must NOT
  # produce a finding (confirming the non-terminal filter); the sole non-terminal entry declares
  # a concrete scope, so the log_pass negative fires against a denominator of 1, not 2 ---
  cat > "$WORKDIR/scope10-terminal-fixture.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-terminal", "status": "completed", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"},
    {"project_number": 2, "project_name": "cand-ok", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["a/b.sh"]}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-terminal-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "No missing/null/empty file_scope found among 1 non-terminal task(s)" <<< "$out" \
      && ! grep -q "cand-terminal" <<< "$out"; then
    pass "Check 10 terminal-exclusion fixture: a completed entry with no file_scope produces no finding"
  else
    fail "Check 10 terminal-exclusion fixture: expected the terminal entry excluded from both the finding set and the denominator (rc=$rc)"
    info "$out"
  fi

  # --- Check 11 fixture: a glob-shaped entry fires the named WARN; a non-glob control entry
  # must not ---
  cat > "$WORKDIR/scope11-fixture.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-glob", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["*/agents/**"]},
    {"project_number": 2, "project_name": "cand-plain", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["a/b/c.sh"]}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope11-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "Glob-shaped file_scope entry: project_number 1, entry '\*/agents/\*\*'" <<< "$out" \
      && ! grep -q "Glob-shaped file_scope entry: project_number 2" <<< "$out"; then
    pass "Check 11 fixture: glob-shaped entry fires the named WARN, non-glob control entry does not, exit 0"
  else
    fail "Check 11 fixture: expected the named Check 11 WARN for project 1 only (rc=$rc)"
    info "$out"
  fi

  # --- --strict fixtures: the Check 10 fixture (WARN-only in default mode) becomes exit 1 under
  # --strict; the warning-free negative fixture stays exit 0 under --strict ---
  out=$(bash "$SCOPE_VALIDATOR" --strict "$WORKDIR/scope10-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q "STATE VALIDATION FAILED (--strict:" <<< "$out"; then
    pass "--strict fixture: a WARN-only Check 10 finding becomes exit 1 under --strict"
  else
    fail "--strict fixture: expected exit 1 with the strict-mode summary line against the Check 10 fixture (rc=$rc)"
    info "$out"
  fi

  out=$(bash "$SCOPE_VALIDATOR" --strict "$WORKDIR/scope10-negative-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    pass "--strict fixture: a warning-free fixture still exits 0 under --strict"
  else
    fail "--strict fixture: expected exit 0 against a warning-free fixture under --strict (rc=$rc)"
    info "$out"
  fi

  # --- --fix non-manufacture fixture (D4): an entry with no file_scope key must still have no
  # file_scope key after --fix, alongside a sibling entry with an exact duplicate so --fix
  # actually performs a repair in the same run. Placed inside THIS repo's own git tree (matching
  # the existing --fix fixture above), since --fix writes only through a DEPLOYED
  # state-write.sh. Gracefully SKIPPED (not FAILED) when no deployed state-write.sh exists yet.
  if [[ -f "$REPO_ROOT/.claude/scripts/state-write.sh" ]]; then
    NOMFG_FIXTURE_DIR="$REPO_ROOT/specs/_tmp_scope_nomfg_fixture_$$"
    mkdir -p "$NOMFG_FIXTURE_DIR"
    cat > "$NOMFG_FIXTURE_DIR/state.json" <<'JSON'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "a", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z",
     "dependencies": [],
     "file_scope": ["docs/README.md", "docs/README.md", "src/foo.lua"]},
    {"project_number": 2, "project_name": "b", "status": "not_started", "task_type": "general",
     "created": "2026-01-02T00:00:00Z", "last_updated": "2026-01-02T00:00:00Z",
     "dependencies": []}
  ]
}
JSON
    out=$(bash "$SCOPE_VALIDATOR" --fix "$NOMFG_FIXTURE_DIR/state.json" 2>&1)
    rc=$?
    nomfg_fs1=$(jq -c '.active_projects[] | select(.project_number==1) | .file_scope' "$NOMFG_FIXTURE_DIR/state.json" 2>/dev/null)
    nomfg_p2_has_key=$(jq -r '.active_projects[] | select(.project_number==2) | has("file_scope")' "$NOMFG_FIXTURE_DIR/state.json" 2>/dev/null)
    if [[ "$rc" -eq 0 ]] \
        && [[ "$nomfg_fs1" == '["docs/README.md","src/foo.lua"]' ]] \
        && [[ "$nomfg_p2_has_key" == "false" ]]; then
      pass "--fix non-manufacture fixture (D4): project 1's exact duplicate is repaired, project 2 still has no file_scope key"
    else
      fail "--fix non-manufacture fixture: expected project 1 deduped and project 2 to remain keyless (rc=$rc)"
      info "$out"
      info "project 1 file_scope: $nomfg_fs1"
      info "project 2 has file_scope key: $nomfg_p2_has_key"
    fi
    rm -rf "$NOMFG_FIXTURE_DIR"
  else
    info "SKIPPING --fix non-manufacture fixture: no deployed state-write.sh at $REPO_ROOT/.claude/scripts/state-write.sh"
    info "(run bash .claude/scripts/deploy-headless.sh first, then re-run this suite)"
  fi
fi

# =====================================================================
# Widened-field ruling fixtures (Checks 3/4 advisory-first posture) + schema/validator drift test
# =====================================================================
# Source-store-first resolution (same precedent as D5_VALIDATOR/FS_VALIDATOR/SCOPE_VALIDATOR
# above): these fixtures exercise the widened fields and the advisory-first posture without
# depending on a prior deploy step. A candidate is trusted only after grepping for both
# "resume_phase" (confirms the schema-widening-mirroring KNOWN_ENTRY_FIELDS entry landed) and
# "model it there and in KNOWN_TOP_LEVEL_FIELDS" (confirms Check 3's advisory WARN message
# landed), so a stale deployed copy that has neither cannot produce a false green.
WIDEN_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
WIDEN_VALIDATOR=""
for candidate in "${WIDEN_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "resume_phase" "$candidate" 2>/dev/null \
      && grep -q "model it there and in KNOWN_TOP_LEVEL_FIELDS" "$candidate" 2>/dev/null; then
    WIDEN_VALIDATOR="$candidate"
    break
  fi
done

if [[ -z "$WIDEN_VALIDATOR" ]]; then
  info "SKIPPING widened-field fixtures: no candidate validator (source-store or deployed)"
  info "contains both the resume_phase known-field name and the Check 3 advisory WARN message."
  info "Candidates checked:"
  for candidate in "${WIDEN_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
else
  info "Widened-field fixtures running against: $WIDEN_VALIDATOR (confirmed to contain the widened fields and the advisory posture)"

  # --- Positive fixture: all five widened fields with realistic values -> exit 0, no Check 3/4
  # finding of any severity ---
  cat > "$WORKDIR/widen-positive-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_goal": "Close the residual repository-hygiene backlog",
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "widened",
      "status": "blocked",
      "task_type": "general",
      "title": "Widened fixture",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "blockers": ["waiting on a Hugging Face write token"],
      "previous_status": "implementing",
      "resume_phase": 1,
      "researched": "2026-06-09T06:07:43Z"
    }
  ]
}
JSON
  out=$(bash "$WIDEN_VALIDATOR" "$WORKDIR/widen-positive-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && ! grep -q "Unknown top-level field" <<< "$out" \
      && ! grep -q "Unknown entry field" <<< "$out"; then
    pass "widened-field positive fixture: active_goal, blockers (array), previous_status, resume_phase, researched all accepted, exit 0, no Check 3/4 finding"
  else
    fail "widened-field positive fixture: expected exit 0 with no Check 3/4 finding (rc=$rc)"
    info "$out"
  fi

  # --- Legacy scalar-string blockers tolerated in default mode (transitional tolerance) ---
  cat > "$WORKDIR/widen-scalar-blockers-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "legacy-blockers",
      "status": "blocked",
      "task_type": "general",
      "title": "Legacy scalar blockers",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "blockers": "a plain legacy string, not yet migrated to an array"
    }
  ]
}
JSON
  out=$(bash "$WIDEN_VALIDATOR" "$WORKDIR/widen-scalar-blockers-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Unknown entry field: blockers" <<< "$out"; then
    pass "legacy scalar-string blockers fixture: accepted in default mode (transitional tolerance), exit 0"
  else
    fail "legacy scalar-string blockers fixture: expected exit 0 with no unknown-field finding for blockers (rc=$rc)"
    info "$out"
  fi

  # --- research_questions on an entry -> no Check 4 finding (regression guard for the
  # pre-existing schema/validator drift this phase closed) ---
  cat > "$WORKDIR/widen-research-questions-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "needs-research",
      "status": "researching",
      "task_type": "general",
      "title": "Research questions fixture",
      "created": "2026-01-01T00:00:00Z",
      "last_updated": "2026-01-01T00:00:00Z",
      "research_questions": ["what is x?", "what is y?"]
    }
  ]
}
JSON
  out=$(bash "$WIDEN_VALIDATOR" "$WORKDIR/widen-research-questions-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && ! grep -q "Unknown entry field: research_questions" <<< "$out"; then
    pass "research_questions fixture: no Check 4 finding (regression guard for the pre-existing schema/validator drift)"
  else
    fail "research_questions fixture: expected exit 0 with no unknown-field finding for research_questions (rc=$rc)"
    info "$out"
  fi

  # --- Negative fixture: the three retired top-level fields still produce an unknown-field WARN
  # (not silence, not FAIL) -- guards against re-admitting them as "known" ---
  cat > "$WORKDIR/widen-retired-fixture.json" <<'JSON'
{
  "next_project_number": 1,
  "artifacts": [{"path": "specs/000_example/plans/implementation-001.md", "type": "plan"}],
  "metadata": {"generated_at": "2026-08-24T21:34:14.522352", "total_tasks": 44},
  "last_updated": "2026-09-29T05:45:37Z",
  "active_projects": []
}
JSON
  out=$(bash "$WIDEN_VALIDATOR" "$WORKDIR/widen-retired-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "\[WARN\].*Unknown top-level field: artifacts" <<< "$out" \
      && grep -q "\[WARN\].*Unknown top-level field: metadata" <<< "$out" \
      && grep -q "\[WARN\].*Unknown top-level field: last_updated" <<< "$out" \
      && ! grep -q "\[FAIL\].*Unknown top-level field" <<< "$out"; then
    pass "retired top-level fields fixture: artifacts/metadata/last_updated each produce a WARN (not FAIL, not silence), exit 0"
  else
    fail "retired top-level fields fixture: expected exit 0 with a WARN (not FAIL) for each retired field (rc=$rc)"
    info "$out"
  fi

  # --- --strict promotes the retired-fields WARN to exit-blocking ---
  out=$(bash "$WIDEN_VALIDATOR" --strict "$WORKDIR/widen-retired-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q "STATE VALIDATION FAILED (--strict:" <<< "$out"; then
    pass "retired top-level fields fixture under --strict: the WARN is promoted to exit-blocking"
  else
    fail "retired top-level fields fixture under --strict: expected exit 1 (rc=$rc)"
    info "$out"
  fi
fi

# =====================================================================
# Schema-to-validator drift test: state-schema.json's property key sets must be byte-equal (as
# sorted sets, both directions) to validate-state.sh's KNOWN_TOP_LEVEL_FIELDS/KNOWN_ENTRY_FIELDS.
# Modelled on test-status-vocabulary.sh's library/schema anti-drift assertion -- the in-repo
# precedent for exactly this pattern, applied here to a different hand-maintained pair.
# =====================================================================
SCHEMA_CANDIDATES=(
  "$REPO_ROOT/.claude/context/schemas/state-schema.json"
  "$SCRIPT_DIR/../../context/schemas/state-schema.json"
)
SCHEMA=""
for candidate in "${SCHEMA_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    SCHEMA="$candidate"
    break
  fi
done

if [[ -z "$SCHEMA" ]]; then
  info "SKIPPING schema-to-validator drift test: state-schema.json not found at any of:"
  for candidate in "${SCHEMA_CANDIDATES[@]}"; do
    info "  $candidate"
  done
elif [[ -z "$WIDEN_VALIDATOR" ]]; then
  info "SKIPPING schema-to-validator drift test: no validator candidate confirmed to contain the widened fields (see above)."
elif ! command -v jq >/dev/null 2>&1; then
  info "SKIPPING schema-to-validator drift test: jq not available."
else
  # Extract KNOWN_TOP_LEVEL_FIELDS / KNOWN_ENTRY_FIELDS array bodies from the validator by
  # sourcing it in a subshell with its own main-body logic disabled -- not attempted here, since
  # the arrays are declared before any early-exit path; instead, extract them textually via awk,
  # matching the array literal's own `NAME=(\n ... \n)` shape.
  top_schema_sorted=$(jq -r '.properties | keys[]' "$SCHEMA" | sort)
  entry_schema_sorted=$(jq -r '.definitions.projectEntry.properties | keys[]' "$SCHEMA" | sort)

  top_validator_sorted=$(awk '/^KNOWN_TOP_LEVEL_FIELDS=\(/,/^\)/' "$WIDEN_VALIDATOR" | grep -v '(' | grep -v ')' | tr -s ' \t\n' '\n' | sed '/^$/d' | sort)
  entry_validator_sorted=$(awk '/^KNOWN_ENTRY_FIELDS=\(/,/^\)/' "$WIDEN_VALIDATOR" | grep -v '(' | grep -v ')' | tr -s ' \t\n' '\n' | sed '/^$/d' | sort)

  if [[ "$top_schema_sorted" == "$top_validator_sorted" ]]; then
    pass "drift test: state-schema.json top-level properties == validate-state.sh KNOWN_TOP_LEVEL_FIELDS (sorted sets)"
  else
    fail "drift test: top-level DRIFT detected between state-schema.json and KNOWN_TOP_LEVEL_FIELDS"
    info "schema (sorted):"
    info "$top_schema_sorted"
    info "validator (sorted):"
    info "$top_validator_sorted"
    info "in schema but not validator:"
    info "$(comm -23 <(echo "$top_schema_sorted") <(echo "$top_validator_sorted"))"
    info "in validator but not schema:"
    info "$(comm -13 <(echo "$top_schema_sorted") <(echo "$top_validator_sorted"))"
  fi

  if [[ "$entry_schema_sorted" == "$entry_validator_sorted" ]]; then
    pass "drift test: state-schema.json definitions.projectEntry.properties == validate-state.sh KNOWN_ENTRY_FIELDS (sorted sets)"
  else
    fail "drift test: entry-field DRIFT detected between state-schema.json and KNOWN_ENTRY_FIELDS"
    info "schema (sorted):"
    info "$entry_schema_sorted"
    info "validator (sorted):"
    info "$entry_validator_sorted"
    info "in schema but not validator:"
    info "$(comm -23 <(echo "$entry_schema_sorted") <(echo "$entry_validator_sorted"))"
    info "in validator but not schema:"
    info "$(comm -13 <(echo "$entry_schema_sorted") <(echo "$entry_validator_sorted"))"
  fi
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
