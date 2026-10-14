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

# --- --archive mode (Checks A1-A6, the base-mode unvalidatable-shape guard) validator
# resolution --- Same source-store-first precedent as D5_VALIDATOR/FS_VALIDATOR/SCOPE_VALIDATOR
# above. A candidate is trusted only after grepping for "Check A6" (the LAST archive check added,
# mirroring the existing precedent of grepping the last check in a batch) -- "Check A1" alone
# would also match the archive-mode top-level-key check's own "Check A1b" label, so A6 is the
# more specific anchor.
ARCHIVE_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
ARCHIVE_VALIDATOR=""
for candidate in "${ARCHIVE_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check A6" "$candidate" 2>/dev/null; then
    ARCHIVE_VALIDATOR="$candidate"
    break
  fi
done

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() {
  [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"
  # FIX_FIXTURE_DIR is sited under the real repository's specs/ rather than inside WORKDIR,
  # so WORKDIR removal does not reach it and it needs its own line here. Without this, an
  # interrupt or an early exit between its mkdir and its happy-path rm -rf leaves a
  # _tmp_fso_fix_fixture_* directory behind in the versioned tree.
  [ -n "${FIX_FIXTURE_DIR:-}" ] && [ -d "$FIX_FIXTURE_DIR" ] && rm -rf "$FIX_FIXTURE_DIR"
  return 0
}
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
    # rc is 1, not 0: project 3's file_scope stays a literal null (the whole point of this
    # fixture -- --fix must not mutate it), and null_value is FAIL-promoted (2026-10-03), so the
    # validation pass --fix runs before writing now reports exit 1. This is Check 10's FAIL firing
    # correctly on exactly the shape --fix deliberately leaves untouched, not a --fix regression.
    if [[ "$rc" -eq 1 ]] \
        && [[ "$fix_fs1" == '["docs/README.md","src/foo.lua","src/bar.lua"]' ]] \
        && [[ "$fix_fs2" == '["src/foo/","src/foo"]' ]] \
        && [[ "$fix_p3_null" == $'true\ttrue' ]] \
        && [[ "$fix_p4_has_key" == "false" ]] \
        && [[ -z "$fix_other_diff" ]] \
        && grep -q "file_scope null_value: project_number 3 (c)" <<< "$out" \
        && ! grep -q -- '--fix: state-write.sh failed' <<< "$out"; then
      pass "--fix fixture: exact duplicates removed order-preservingly (project 1), Class B untouched (project 2), null-valued file_scope untouched (project 3, now FAIL-promoted and correctly reported), absent-key file_scope untouched (project 4), other fields unchanged"
    else
      fail "--fix fixture: expected order-preserving dedup on project 1, untouched Class B on project 2, null-valued project 3 untouched and FAIL-reported, absent-key project 4 untouched, unchanged other fields, and no state-write.sh failure (rc=$rc)"
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
  # (unaffected) entry, all non-terminal -> all three sub-state lines plus the summary counts.
  # null_value is now FAIL-promoted (2026-10-03): this blended fixture exits 1, not 0, and carries
  # both the per-finding FAIL line and the aggregate "file_scope literal-null: N finding(s)" FAIL
  # line, alongside the unpromoted missing_key/empty_array WARN lines ---
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
  if [[ "$rc" -eq 1 ]] \
      && grep -q "file_scope missing_key: project_number 1 (cand-missing)" <<< "$out" \
      && grep -q "file_scope null_value: project_number 2 (cand-null)" <<< "$out" \
      && grep -q "file_scope empty_array: project_number 3 (cand-empty)" <<< "$out" \
      && grep -q "file_scope visibility: 1 missing-key, 1 literal-null, 1 empty-array, out of 4 non-terminal task(s)" <<< "$out" \
      && grep -q "file_scope literal-null: 1 finding(s)" <<< "$out" \
      && grep -q "STATE VALIDATION FAILED" <<< "$out"; then
    pass "Check 10 fixture: missing_key/null_value/empty_array all fire with distinct sub-state lines plus a summary count line and the promoted null_value FAIL, exit 1"
  else
    fail "Check 10 fixture: expected exit 1 with all three sub-state lines, the summary line, and the null_value FAIL lines (rc=$rc)"
    info "$out"
  fi

  # --- Check 10 pure-null_value fixture: a single non-terminal entry with a literal null
  # file_scope, no missing_key or empty_array entries at all -- pins the FAIL independently of
  # the blended fixture above, confirming the promotion fires on its own rather than only in
  # combination with the other two sub-states ---
  cat > "$WORKDIR/scope10-nullonly-fixture.json" <<'JSON'
{
  "next_project_number": 2,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-null-only", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": null}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-nullonly-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] \
      && grep -q "file_scope null_value: project_number 1 (cand-null-only)" <<< "$out" \
      && grep -q "file_scope literal-null: 1 finding(s)" <<< "$out" \
      && ! grep -q "missing_key\|empty_array" <<< "$out" \
      && grep -q "STATE VALIDATION FAILED" <<< "$out"; then
    pass "Check 10 pure-null_value fixture: a lone literal-null entry FAILs on its own, no missing_key/empty_array finding present"
  else
    fail "Check 10 pure-null_value fixture: expected exit 1 with the FAIL lines and no missing_key/empty_array finding (rc=$rc)"
    info "$out"
  fi

  # --- Check 10 display-cap fixture: 12 missing_key entries (sorted ahead by project_number,
  # exceeding the 10-item WARN display cap) plus one null_value entry at a HIGH project_number
  # that sorts past the cap -- regression guard for the display-cap exemption. Without the
  # exemption, a null_value finding sorting past the cap would emit no FAIL line and the
  # promotion would silently regress to cosmetic the moment missing_key findings outnumber 10 ---
  {
    echo '{'
    echo '  "next_project_number": 1000,'
    echo '  "active_projects": ['
    for i in $(seq 1 12); do
      echo "    {\"project_number\": $i, \"project_name\": \"cand-missing-$i\", \"status\": \"not_started\", \"task_type\": \"general\", \"created\": \"2026-01-01T00:00:00Z\", \"last_updated\": \"2026-01-01T00:00:00Z\"},"
    done
    echo '    {"project_number": 999, "project_name": "cand-null-high", "status": "not_started", "task_type": "general", "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": null}'
    echo '  ]'
    echo '}'
  } > "$WORKDIR/scope10-displaycap-fixture.json"
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-displaycap-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] \
      && grep -q "file_scope null_value: project_number 999 (cand-null-high)" <<< "$out" \
      && grep -q "file_scope literal-null: 1 finding(s)" <<< "$out" \
      && grep -q "more file_scope visibility finding(s) not shown" <<< "$out"; then
    pass "Check 10 display-cap fixture: a null_value finding sorting past the 10-item WARN cap still produces a FAIL line"
  else
    fail "Check 10 display-cap fixture: expected exit 1 with the high-project_number null_value FAIL line surviving the display cap (rc=$rc)"
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

  # --- WARN-only fixture: one missing_key entry, one empty_array entry, one concrete-scope
  # control, all non-terminal, deliberately NO null_value entry -- this is the fixture the
  # --strict assertion below exercises, since scope10-fixture.json now FAILs in default mode
  # (null_value is FAIL-promoted) and would take the plain "STATE VALIDATION FAILED" branch
  # before the --strict summary branch is ever reached, silently stopping the --strict assertion
  # from testing what it claims to test ---
  cat > "$WORKDIR/scope10-warnonly-fixture.json" <<'JSON'
{
  "next_project_number": 4,
  "active_projects": [
    {"project_number": 1, "project_name": "cand-missing", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"},
    {"project_number": 2, "project_name": "cand-empty", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": []},
    {"project_number": 3, "project_name": "cand-ok", "status": "not_started", "task_type": "general",
     "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z", "file_scope": ["a/b.sh"]}
  ]
}
JSON
  out=$(bash "$SCOPE_VALIDATOR" "$WORKDIR/scope10-warnonly-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "file_scope missing_key: project_number 1 (cand-missing)" <<< "$out" \
      && grep -q "file_scope empty_array: project_number 2 (cand-empty)" <<< "$out" \
      && ! grep -q "null_value\|literal-null: " <<< "$out"; then
    pass "Check 10 WARN-only fixture: missing_key/empty_array fire as WARN with no null_value, exit 0"
  else
    fail "Check 10 WARN-only fixture: expected exit 0 with missing_key/empty_array WARN lines and no null_value finding (rc=$rc)"
    info "$out"
  fi

  # --- --strict fixtures: the WARN-only Check 10 fixture becomes exit 1 under --strict; the
  # warning-free negative fixture stays exit 0 under --strict ---
  out=$(bash "$SCOPE_VALIDATOR" --strict "$WORKDIR/scope10-warnonly-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] && grep -q "STATE VALIDATION FAILED (--strict:" <<< "$out"; then
    pass "--strict fixture: a WARN-only Check 10 finding becomes exit 1 under --strict"
  else
    fail "--strict fixture: expected exit 1 with the strict-mode summary line against the WARN-only Check 10 fixture (rc=$rc)"
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
# Check D6 fixtures: parentage integrity (self-parent, orphaned-parent, cyclic-parentage).
# Source-store-first resolution (same precedent as D5_VALIDATOR/FS_VALIDATOR/SCOPE_VALIDATOR/
# WIDEN_VALIDATOR above): a candidate is trusted only after grepping for a signature confirming
# the Check D6 code actually landed, so a stale deployed copy cannot produce a false green.
# =====================================================================
D6_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
D6_VALIDATOR=""
for candidate in "${D6_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "Check D6: parentage integrity" "$candidate" 2>/dev/null; then
    D6_VALIDATOR="$candidate"
    break
  fi
done

if [[ -z "$D6_VALIDATOR" ]]; then
  info "SKIPPING Check D6 fixtures: no candidate validator (source-store or deployed) contains"
  info "the 'Check D6: parentage integrity' signature comment."
  info "Candidates checked:"
  for candidate in "${D6_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
else
  info "Check D6 fixtures running against: $D6_VALIDATOR (confirmed to contain Check D6)"

  # Shared sibling archive/state.json for the archived-parent fixture below. Lives once in
  # $WORKDIR (shared across every fixture in this suite), using a project-number range
  # (999210) that no other fixture in this file touches, so its presence cannot interfere with
  # any other check's known-number set.
  mkdir -p "$WORKDIR/archive"
  cat > "$WORKDIR/archive/state.json" <<'JSON'
{
  "completed_projects": [
    {"project_number": 999210, "project_name": "archived-parent", "status": "completed"}
  ],
  "abandoned_projects": [],
  "archived_projects": []
}
JSON

  # --- D6a: clean parentage -- not_started and blocked children under a still-active parent.
  # Regression-guards the "never examine parent/child status combinations" ruling, and doubles
  # as the Check 4 regression guard (an entry carrying parent_task produces no unknown-entry-
  # field WARN). ---
  cat > "$WORKDIR/d6-clean-fixture.json" <<'JSON'
{
  "next_project_number": 999103,
  "active_projects": [
    {"project_number": 999100, "project_name": "d6-parent", "status": "implementing", "task_type": "meta", "title": "parent", "description": "d", "dependencies": []},
    {"project_number": 999101, "project_name": "d6-child-a", "status": "not_started", "task_type": "meta", "title": "child a", "description": "d", "dependencies": [], "parent_task": 999100},
    {"project_number": 999102, "project_name": "d6-child-b", "status": "blocked", "task_type": "meta", "title": "child b", "description": "d", "dependencies": [], "parent_task": 999100}
  ]
}
JSON
  out=$(bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-clean-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] \
      && grep -q "No self-referential parent_task values" <<< "$out" \
      && grep -q "No orphaned parent_task references" <<< "$out" \
      && grep -q "No parentage cycles detected among active_projects" <<< "$out" \
      && ! grep -q "Unknown entry field: parent_task" <<< "$out"; then
    pass "D6a: clean parentage (not_started + blocked children under an active parent) -> all three PASS, no Check 4 finding"
  else
    fail "D6a: clean parentage fixture did not produce the expected three PASS lines (rc=$rc)"
    info "$out"
  fi

  # --- D6b: archived parent is expected, settled lineage -- not a finding (Ruling 3) ---
  cat > "$WORKDIR/d6-archived-fixture.json" <<'JSON'
{
  "next_project_number": 999201,
  "active_projects": [
    {"project_number": 999200, "project_name": "d6-archived-child", "status": "not_started", "task_type": "meta", "title": "child", "description": "d", "dependencies": [], "parent_task": 999210}
  ]
}
JSON
  out=$(bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-archived-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "No orphaned parent_task references" <<< "$out" && ! grep -q "Orphaned parent_task" <<< "$out"; then
    pass "D6b: parent present only in the sibling archive's terminal arrays -> PASS, not an orphan finding"
  else
    fail "D6b: archived-parent fixture unexpectedly produced an orphan finding (rc=$rc)"
    info "$out"
  fi

  # --- D6c: orphan -- parent_task present in neither active_projects nor the archive ---
  cat > "$WORKDIR/d6-orphan-fixture.json" <<'JSON'
{
  "next_project_number": 999301,
  "active_projects": [
    {"project_number": 999300, "project_name": "d6-orphan-child", "status": "not_started", "task_type": "meta", "title": "child", "description": "d", "dependencies": [], "parent_task": 999399}
  ]
}
JSON
  out=$(bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-orphan-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "Orphaned parent_task reference: 999300 -> 999399" <<< "$out"; then
    pass "D6c: orphaned parent_task (999300 -> 999399) names both numbers in a single WARN"
  else
    fail "D6c: orphan fixture did not produce the expected named WARN (rc=$rc)"
    info "$out"
  fi

  # --- D6c-strict: the same orphan fixture exits 1 under --strict, 0 without it. Asserts the
  # orphan WARN text specifically (not just overall exit 1), since an unrelated WARN on this
  # minimal fixture -- e.g. a missing file_scope key -- could otherwise promote to exit 1 under
  # --strict even with Check D6 entirely absent, making the assertion vacuous. ---
  out=$(bash "$D6_VALIDATOR" --deep --strict "$WORKDIR/d6-orphan-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 1 ]] \
      && grep -q "STATE VALIDATION FAILED (--strict:" <<< "$out" \
      && grep -q "Orphaned parent_task reference: 999300 -> 999399" <<< "$out"; then
    pass "D6c-strict: orphan WARN is promoted to exit-blocking under --strict"
  else
    fail "D6c-strict: expected exit 1 under --strict with the orphan WARN present (rc=$rc)"
    info "$out"
  fi

  # --- D6d: self-parent -- parent_task == project_number. Exactly one WARN, no orphan, no cycle
  # (self-parent edges are excluded from the cycle-walk map, so they never double-report). ---
  cat > "$WORKDIR/d6-selfparent-fixture.json" <<'JSON'
{
  "next_project_number": 999401,
  "active_projects": [
    {"project_number": 999400, "project_name": "d6-self-parent", "status": "not_started", "task_type": "meta", "title": "self", "description": "d", "dependencies": [], "parent_task": 999400}
  ]
}
JSON
  out=$(bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-selfparent-fixture.json" 2>&1)
  rc=$?
  self_warn_count=$(grep -c "Self-referential parent_task" <<< "$out")
  if [[ "$rc" -eq 0 ]] \
      && [[ "$self_warn_count" -eq 1 ]] \
      && grep -q "Self-referential parent_task on project_number(s): 999400" <<< "$out" \
      && grep -q "No orphaned parent_task references" <<< "$out" \
      && grep -q "No parentage cycles detected among active_projects" <<< "$out"; then
    pass "D6d: self-parent produces exactly one WARN, no orphan, no degenerate 1-node cycle"
  else
    fail "D6d: self-parent fixture did not produce exactly the expected single WARN (rc=$rc, self_warn_count=$self_warn_count)"
    info "$out"
  fi

  # --- D6e: two-node parentage cycle (A parents B, B parents A) -- names both numbers, and the
  # chain walk terminates (no hang), asserted via an explicit timeout wrapper. ---
  cat > "$WORKDIR/d6-cycle2-fixture.json" <<'JSON'
{
  "next_project_number": 999502,
  "active_projects": [
    {"project_number": 999500, "project_name": "d6-cycle2-a", "status": "not_started", "task_type": "meta", "title": "a", "description": "d", "dependencies": [], "parent_task": 999501},
    {"project_number": 999501, "project_name": "d6-cycle2-b", "status": "blocked", "task_type": "meta", "title": "b", "description": "d", "dependencies": [], "parent_task": 999500}
  ]
}
JSON
  out=$(timeout 10 bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-cycle2-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 124 ]]; then
    fail "D6e: two-node cycle fixture HUNG (timeout 10s exceeded) -- the seen-set chain walk did not terminate"
  elif [[ "$rc" -eq 0 ]] && grep -q "Parentage cycle detected among project_number(s): 999500,999501" <<< "$out"; then
    pass "D6e: two-node parentage cycle detected, names both numbers, chain walk terminates"
  else
    fail "D6e: two-node cycle fixture did not produce the expected named WARN (rc=$rc)"
    info "$out"
  fi

  # --- D6f: three-node parentage cycle (A -> B -> C -> A) -- names all three numbers, and
  # likewise terminates. ---
  cat > "$WORKDIR/d6-cycle3-fixture.json" <<'JSON'
{
  "next_project_number": 999603,
  "active_projects": [
    {"project_number": 999600, "project_name": "d6-cycle3-a", "status": "not_started", "task_type": "meta", "title": "a", "description": "d", "dependencies": [], "parent_task": 999601},
    {"project_number": 999601, "project_name": "d6-cycle3-b", "status": "not_started", "task_type": "meta", "title": "b", "description": "d", "dependencies": [], "parent_task": 999602},
    {"project_number": 999602, "project_name": "d6-cycle3-c", "status": "blocked", "task_type": "meta", "title": "c", "description": "d", "dependencies": [], "parent_task": 999600}
  ]
}
JSON
  out=$(timeout 10 bash "$D6_VALIDATOR" --deep "$WORKDIR/d6-cycle3-fixture.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 124 ]]; then
    fail "D6f: three-node cycle fixture HUNG (timeout 10s exceeded) -- the seen-set chain walk did not terminate"
  elif [[ "$rc" -eq 0 ]] && grep -q "Parentage cycle detected among project_number(s): 999600,999601,999602" <<< "$out"; then
    pass "D6f: three-node parentage cycle detected, names all three numbers, chain walk terminates"
  else
    fail "D6f: three-node cycle fixture did not produce the expected named WARN (rc=$rc)"
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
  "$SCRIPT_DIR/../../context/schemas/state-schema.json"
  "$REPO_ROOT/.claude/context/schemas/state-schema.json"
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
# Omitted-argument default resolution (XREPO) fixtures: proves the omitted-argument STATE_FILE
# default is script-anchored, never CWD-relative, and that the explicit-positional-argument path
# (including argument-relative sibling lookups) is unaffected.
#
# Source-store-first resolution (same precedent as D5_VALIDATOR/FS_VALIDATOR/SCOPE_VALIDATOR/
# WIDEN_VALIDATOR/D6_VALIDATOR above): a candidate is trusted only after grepping for the
# "default-resolution: script-anchored" marker comment, so a stale deployed copy predating this
# fix cannot produce a false green.
# =====================================================================
XREPO_VALIDATOR_CANDIDATES=(
  "$SCRIPT_DIR/../validate-state.sh"
  "$REPO_ROOT/.claude/scripts/validate-state.sh"
)
XREPO_VALIDATOR=""
for candidate in "${XREPO_VALIDATOR_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]] && grep -q "default-resolution: script-anchored" "$candidate" 2>/dev/null; then
    XREPO_VALIDATOR="$candidate"
    break
  fi
done

if [[ -z "$XREPO_VALIDATOR" ]]; then
  info "SKIPPING XREPO fixtures: no candidate validator (source-store or deployed) contains the"
  info "'default-resolution: script-anchored' marker comment. Candidates checked:"
  for candidate in "${XREPO_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "XREPO fixtures running against: $XREPO_VALIDATOR (confirmed to contain the"
  info "default-resolution: script-anchored marker)"

  # Foreign CWD used by both cases below: a directory outside this repository entirely, so any
  # output naming a path under it proves the validator read something it should not have.
  OTHER_CWD="$WORKDIR/other-repo"
  mkdir -p "$OTHER_CWD/specs"

  # --- Case A: cross-repo omitted-argument invocation (Acceptance #1, #2) ---
  # Non-vacuity device: $OTHER_CWD/specs/state.json is DELIBERATELY malformed JSON. The bare
  # pre-fix default ("specs/state.json" relative to CWD) would read exactly this file and fail
  # Check 1 with the script's own "VALIDATION FAILED (invalid JSON)" exit-1 message -- a failure
  # signature that cannot occur by coincidence from this repository's own (valid) specs/state.json.
  # Pre-fix, this case fails by construction: the bare relative default resolves to
  # $OTHER_CWD/specs/state.json and trips that exact signature. Post-fix, the omitted-argument
  # default is script-anchored, so this signature must never appear.
  cat > "$OTHER_CWD/specs/state.json" <<'JSON'
{ "sentinel": XREPO_CASE_A_OTHER_CWD_MALFORMED_PAYLOAD this is not valid JSON
JSON

  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" 2>&1)
  rc=$?
  if ! grep -qF "$OTHER_CWD" <<< "$out" \
      && ! grep -q "VALIDATION FAILED (invalid JSON)" <<< "$out" \
      && grep -qE '(Validating state file: /.*specs/state\.json|File not found: /.*specs/state\.json)' <<< "$out"; then
    pass "XREPO Case A: cross-repo omitted-argument invocation never reads \$OTHER_CWD's state.json (names an absolute path under the script-anchored repo instead, rc=$rc)"
  else
    fail "XREPO Case A: cross-repo omitted-argument invocation contaminated by \$OTHER_CWD or failed to name an absolute script-anchored path (rc=$rc)"
    info "$out"
  fi

  # --- Case B: explicit-argument argument-relativity regression (Acceptance #3), run from the
  # same foreign $OTHER_CWD so the property under test is isolated from the ambient CWD ---
  ARGREL_DIR="$WORKDIR/argrel"
  mkdir -p "$ARGREL_DIR/archive"
  cat > "$ARGREL_DIR/state.json" <<'JSON'
{
  "next_project_number": 999701,
  "active_projects": [
    {"project_number": 999700, "project_name": "argrel-case", "status": "not_started", "task_type": "meta", "title": "t", "description": "d", "dependencies": [999710]}
  ]
}
JSON
  cat > "$ARGREL_DIR/archive/state.json" <<'JSON'
{
  "completed_projects": [
    {"project_number": 999710, "project_name": "argrel-archived-dep", "status": "completed"}
  ],
  "abandoned_projects": [],
  "archived_projects": []
}
JSON

  # Sub-case B1: sibling archive present -> dependency on 999710 resolves, no dangling finding.
  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" --deep "$ARGREL_DIR/state.json" 2>&1)
  rc=$?
  if grep -q "No dangling dependency references" <<< "$out" && ! grep -q "Dangling dependency reference" <<< "$out"; then
    pass "XREPO Case B1: explicit-argument dependency resolves via the ARGUMENT-relative sibling archive (archive present), run from a foreign CWD"
  else
    fail "XREPO Case B1: explicit-argument invocation did not resolve the sibling archive relative to the argument (rc=$rc)"
    info "$out"
  fi

  # Sub-case B2: same invocation with the sibling archive removed -> the same dependency is now
  # dangling. The flip (B1 pass, B2 fail on an otherwise-identical fixture) proves the archive was
  # located relative to the ARGUMENT's own directory, not to CWD or any repo root.
  mv "$ARGREL_DIR/archive" "$ARGREL_DIR/archive.moved-aside"
  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" --deep "$ARGREL_DIR/state.json" 2>&1)
  rc=$?
  if grep -q "Dangling dependency reference: 999700 -> 999710" <<< "$out"; then
    pass "XREPO Case B2: removing the argument-relative sibling archive makes the SAME dependency dangling (confirms B1 was not coincidental)"
  else
    fail "XREPO Case B2: removing the sibling archive did not produce the expected dangling-dependency finding (rc=$rc)"
    info "$out"
  fi
  mv "$ARGREL_DIR/archive.moved-aside" "$ARGREL_DIR/archive"

  # Sub-case B3: no sibling TODO.md next to the fixture -> warning names the FIXTURE's own path,
  # not a path under $OTHER_CWD and not this repository's specs/TODO.md.
  argrel_abs="$(cd "$ARGREL_DIR" && pwd)/state.json"
  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" --deep "$ARGREL_DIR/state.json" 2>&1)
  rc=$?
  if grep -qF "No sibling TODO.md next to $argrel_abs" <<< "$out"; then
    pass "XREPO Case B3: missing-sibling-TODO.md warning names the explicit argument's own (ARGUMENT-relative) path"
  else
    fail "XREPO Case B3: missing-sibling-TODO.md warning did not name the fixture's own absolute path (rc=$rc)"
    info "$out"
  fi

  # Sub-case B4: with a sibling TODO.md created next to the fixture, that warning is absent.
  # Asserts WHICH sibling was addressed without depending on generate-todo.sh's deploy-root guard
  # succeeding (the sync check's PASS/FAIL outcome itself is not asserted here).
  : > "$ARGREL_DIR/TODO.md"
  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" --deep "$ARGREL_DIR/state.json" 2>&1)
  rc=$?
  if ! grep -qF "No sibling TODO.md next to" <<< "$out"; then
    pass "XREPO Case B4: missing-sibling-TODO.md warning is absent once a sibling TODO.md exists next to the fixture"
  else
    fail "XREPO Case B4: missing-sibling-TODO.md warning still present despite a sibling TODO.md existing (rc=$rc)"
    info "$out"
  fi
  rm -f "$ARGREL_DIR/TODO.md"

  # Sub-case B5: the banner for this explicit-argument invocation prints an absolute path equal
  # to the fixture's own absolute path (Acceptance #2, explicit-argument side).
  out=$(cd "$OTHER_CWD" && bash "$XREPO_VALIDATOR" "$ARGREL_DIR/state.json" 2>&1)
  rc=$?
  if grep -qF "Validating state file: $argrel_abs" <<< "$out"; then
    pass "XREPO Case B5: explicit-argument banner prints the absolute fixture path"
  else
    fail "XREPO Case B5: explicit-argument banner did not print the expected absolute fixture path (rc=$rc)"
    info "$out"
  fi
fi

# =====================================================================
# --archive mode (Checks A1-A6, the base-mode unvalidatable-shape guard) fixtures
# =====================================================================
if [[ -z "$ARCHIVE_VALIDATOR" ]]; then
  info "SKIPPING --archive fixtures: no candidate validator (source-store or deployed) contains"
  info "Check A6 (grepped for \"Check A6\"). Candidates checked:"
  for candidate in "${ARCHIVE_VALIDATOR_CANDIDATES[@]}"; do
    info "  $candidate"
  done
  info "Ensure agent-system/extensions/core/scripts/validate-state.sh is up to date (and, for the"
  info "deployed candidate, that a deploy has run) before re-running this suite."
else
  info "--archive fixtures running against: $ARCHIVE_VALIDATOR (confirmed to contain Check A6)"

  # --- Fixture (a): positive archive shape -- archived_projects + completed_projects, each with
  # a few well-formed entries -> exit 0 under --archive.
  cat > "$WORKDIR/archive-a-positive.json" <<'JSON'
{
  "archived_projects": [
    {"project_number": 501, "project_name": "alpha-archived", "status": "abandoned",
     "task_type": "general", "created": "2026-01-01T00:00:00Z",
     "last_updated": "2026-01-01T00:00:00Z", "archived_at": "2026-01-02T00:00:00Z"}
  ],
  "completed_projects": [
    {"project_number": 502, "project_name": "beta-completed", "status": "completed",
     "task_type": "general", "created": "2026-01-01T00:00:00Z",
     "last_updated": "2026-01-01T00:00:00Z", "archived_at": "2026-01-02T00:00:00Z"}
  ]
}
JSON
  out=$(bash "$ARCHIVE_VALIDATOR" --archive "$WORKDIR/archive-a-positive.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    pass "Fixture (a): positive archive shape exits 0 under --archive"
  else
    fail "Fixture (a): positive archive shape expected exit 0 under --archive, got $rc"
    info "$out"
  fi

  # --- Fixture (b): the literal /task --abandon write shape -- a completed_projects entry with
  # status: "abandoned" and an "abandoned" timestamp key, NO archived_at -> exit 0 under
  # --archive. This is the exact write named in this task's description.
  cat > "$WORKDIR/archive-b-task-abandon.json" <<'JSON'
{
  "archived_projects": [],
  "completed_projects": [
    {"project_number": 503, "project_name": "gamma-task-abandon", "status": "abandoned",
     "task_type": "general", "created": "2026-01-01T00:00:00Z",
     "last_updated": "2026-01-01T00:00:00Z", "abandoned": "2026-01-03T00:00:00Z"}
  ]
}
JSON
  out=$(bash "$ARCHIVE_VALIDATOR" --archive "$WORKDIR/archive-b-task-abandon.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]]; then
    pass "Fixture (b): literal /task --abandon write shape (completed_projects + status=abandoned + 'abandoned' timestamp key, no archived_at) exits 0 under --archive"
  else
    fail "Fixture (b): /task --abandon write shape expected exit 0 under --archive, got $rc"
    info "$out"
  fi

  # --- Fixture (c): archive defect -- a non-numeric project_number (Check A2, FAIL-level per the
  # Phase 3 live measurement) plus a status outside even the widened archive vocabulary (Check
  # A4, WARN-level) -> nonzero exit and a named Check A2 error line under plain --archive (no
  # --strict needed, since A2 is FAIL-level, not WARN).
  cat > "$WORKDIR/archive-c-defect.json" <<'JSON'
{
  "completed_projects": [
    {"project_number": "not-a-number", "project_name": "delta-defect", "status": "totally_bogus_status",
     "task_type": "general", "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"}
  ]
}
JSON
  out=$(bash "$ARCHIVE_VALIDATOR" --archive "$WORKDIR/archive-c-defect.json" 2>&1)
  rc=$?
  if [[ "$rc" -ne 0 ]] && grep -q "Check A2" <<< "$out" && grep -qF "non-numeric project_number" <<< "$out"; then
    pass "Fixture (c): non-numeric project_number produces a nonzero exit and a named Check A2 error under --archive"
  else
    fail "Fixture (c): expected nonzero exit + named Check A2 error, got rc=$rc"
    info "$out"
  fi

  # --- Fixture (d): base-mode regression guard -- an archive-shaped file validated WITHOUT
  # --archive asserts (i) Check 2's two required-field FAILs are still reported, (ii) the Phase 2
  # "could not validate" FAIL is reported, and (iii) NONE of the three
  # "All active_projects[]..." PASS lines appear. This is the assertion that catches a regression
  # to the false-PASS pattern this task exists to close.
  out=$(bash "$ARCHIVE_VALIDATOR" "$WORKDIR/archive-a-positive.json" 2>&1)
  rc=$?
  if grep -qF "Required top-level field missing: next_project_number" <<< "$out" \
     && grep -qF "Required top-level field missing: active_projects" <<< "$out" \
     && grep -qF "Cannot validate: active_projects is absent or not an array" <<< "$out" \
     && ! grep -q "All active_projects\[\]" <<< "$out"; then
    pass "Fixture (d): base-mode regression guard -- archive-shaped file validated without --archive reports both Check 2 FAILs + the Phase 2 'could not validate' FAIL, and zero 'All active_projects[]...' PASS lines"
  else
    fail "Fixture (d): base-mode regression guard assertions not all satisfied (rc=$rc)"
    info "$out"
  fi

  # --- Fixture (e): cross-array duplicate project_number -- Check A6, WARN-only (never FAIL) --
  # exits 0 with a named WARN under plain --archive (confirming A6 does not regress against live
  # data), and exits 1 under --archive --strict.
  cat > "$WORKDIR/archive-e-crossdup.json" <<'JSON'
{
  "archived_projects": [
    {"project_number": 600, "project_name": "epsilon-dup", "status": "abandoned",
     "task_type": "general", "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"}
  ],
  "completed_projects": [
    {"project_number": 600, "project_name": "epsilon-dup", "status": "completed",
     "task_type": "general", "created": "2026-01-01T00:00:00Z", "last_updated": "2026-01-01T00:00:00Z"}
  ]
}
JSON
  out=$(bash "$ARCHIVE_VALIDATOR" --archive "$WORKDIR/archive-e-crossdup.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -q "Check A6" <<< "$out"; then
    pass "Fixture (e): cross-array duplicate project_number exits 0 with a named Check A6 WARN under plain --archive"
  else
    fail "Fixture (e): expected exit 0 + named Check A6 WARN under plain --archive, got rc=$rc"
    info "$out"
  fi
  out_strict=$(bash "$ARCHIVE_VALIDATOR" --archive --strict "$WORKDIR/archive-e-crossdup.json" 2>&1)
  rc_strict=$?
  if [[ "$rc_strict" -eq 1 ]]; then
    pass "Fixture (e): cross-array duplicate project_number exits 1 under --archive --strict (WARN promoted)"
  else
    fail "Fixture (e): expected exit 1 under --archive --strict, got $rc_strict"
    info "$out_strict"
  fi

  # --- Fixture (f): abandoned_projects tolerance -- three variants (absent, present-and-empty,
  # present-with-entries) each exit 0 under --archive, pinning the dead-vocabulary decision.
  cat > "$WORKDIR/archive-f-absent.json" <<'JSON'
{"completed_projects": []}
JSON
  cat > "$WORKDIR/archive-f-empty.json" <<'JSON'
{"completed_projects": [], "abandoned_projects": []}
JSON
  cat > "$WORKDIR/archive-f-entries.json" <<'JSON'
{"completed_projects": [], "abandoned_projects": [
  {"project_number": 700, "project_name": "zeta-abandoned-vocab", "status": "abandoned"}
]}
JSON
  for f_variant in absent empty entries; do
    out=$(bash "$ARCHIVE_VALIDATOR" --archive "$WORKDIR/archive-f-${f_variant}.json" 2>&1)
    rc=$?
    if [[ "$rc" -eq 0 ]]; then
      pass "Fixture (f): abandoned_projects $f_variant variant exits 0 under --archive"
    else
      fail "Fixture (f): abandoned_projects $f_variant variant expected exit 0 under --archive, got $rc"
      info "$out"
    fi
  done

  # --- Fixture (g): flag-combination posture -- --archive --fix exits 2 with a named refusal;
  # --archive --deep exits 0 with the named "no --deep checks in archive mode" notice.
  out=$(bash "$ARCHIVE_VALIDATOR" --archive --fix "$WORKDIR/archive-a-positive.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 2 ]] && grep -qF "ERROR: --archive --fix is not supported" <<< "$out"; then
    pass "Fixture (g): --archive --fix exits 2 with a named refusal"
  else
    fail "Fixture (g): --archive --fix expected exit 2 + named refusal, got rc=$rc"
    info "$out"
  fi
  out=$(bash "$ARCHIVE_VALIDATOR" --archive --deep "$WORKDIR/archive-a-positive.json" 2>&1)
  rc=$?
  if [[ "$rc" -eq 0 ]] && grep -qF "NOTE: --archive --deep: no --deep checks exist in archive mode" <<< "$out"; then
    pass "Fixture (g): --archive --deep exits 0 with the named 'no --deep checks exist in archive mode' notice"
  else
    fail "Fixture (g): --archive --deep expected exit 0 + named notice, got rc=$rc"
    info "$out"
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
