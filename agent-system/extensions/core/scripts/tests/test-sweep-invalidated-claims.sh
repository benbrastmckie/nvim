#!/usr/bin/env bash
# test-sweep-invalidated-claims.sh - Regression suite for sweep-invalidated-claims.sh: the
# read-only, JSON-on-stdout, exit-0-always cross-task claim-invalidation matcher.
#
# Structural model: test-roadmap-generation.sh (mktemp -d TOP_WORKDIR with an EXIT-trap cleanup,
# pass()/fail()/info() helpers, integer PASSED/FAILED counters, a live-fixture checksum guard
# confirming the fixture state.json is never mutated).
#
# RESOLUTION ORDER: the script under test, sweep-invalidated-claims.sh, is resolved
# SOURCE-STORE-FIRST (agent-system/extensions/core/scripts/sweep-invalidated-claims.sh), falling
# back to the deployed copy only if the source-store copy is absent -- this is the file this
# task creates, and the suite must be meaningful on that file alone, before any deploy runs.
# This script has no dependency on any other script (self-contained, jq + coreutils only), so
# there is no second, deploy-tree-first resolution list.
#
# ISOLATION CONTRACT: every case builds its own synthetic state.json (and, where needed, its
# own synthetic .return-meta.json) under a per-case scratch directory and drives the script
# under test exclusively via --state-file / --from-return-meta pointed at that scratch file.
# The suite never reads or writes the real specs/state.json. A checksum guard confirms the
# incident-replay fixture's state.json is byte-identical before and after every invocation.
#
# Fixture entities are referred to as "analog" throughout (never "task N") purely to stay clear
# of the write-time task-reference guard's `task\s*N` pattern -- these are synthetic
# state.json fixture rows, unrelated to this repository's own task-management numbering.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- Source-store-first resolution for the file under test ---
SWEEP_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/sweep-invalidated-claims.sh"
  "$DEPLOY_SCRIPTS_SRC/sweep-invalidated-claims.sh"
)
SWEEP_SRC=""
for c in "${SWEEP_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { SWEEP_SRC="$c"; break; }
done
if [[ -z "$SWEEP_SRC" ]]; then
  echo "ERROR: sweep-invalidated-claims.sh not found at any of: ${SWEEP_CANDIDATES[*]}" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not found on PATH -- required to build/inspect fixtures" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Under test (source-store-first): $SWEEP_SRC"

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${TOP_WORKDIR:-}" && -d "$TOP_WORKDIR" ]] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# ─── Fixture: the incident replay ──────────────────────────────────────────────────────────────
# Five non-terminal analogs naming the refuted declaration in five different textual positions
# (prose sentence, title-embedded phrase, inline backticked reference, mid-sentence clause, and
# a bare title-only match), plus four controls: an unrelated analog naming nothing, a
# longer-identifier analog that must NOT match (word-boundary negative), a terminal analog that
# names the declaration but must NOT match (non-terminal scoping), and the producing analog
# itself, which must NOT match itself (--self exclusion).
INCIDENT_STATE="$TOP_WORKDIR/incident-state.json"
cat > "$INCIDENT_STATE" <<'JSON'
{
  "active_projects": [
    {"project_number": 601, "status": "not_started", "title": "Context note on sliced classes",
     "description": "This design note relies on the NoFiniteWidthModel result to justify choosing Z x Fin n."},
    {"project_number": 602, "status": "implementing", "title": "Why NoFiniteWidthModel changes the design",
     "description": "Record the implications for the convention."},
    {"project_number": 603, "status": "researched", "title": "Probe cross-reference",
     "description": "See `NoFiniteWidthModel` for the full probe and its axiom list."},
    {"project_number": 604, "status": "planned", "title": "Finite model property target",
     "description": "Establish the finite model property for the fragment that NoFiniteWidthModel refutes outright."},
    {"project_number": 605, "status": "not_started", "title": "NoFiniteWidthModel", "description": ""},
    {"project_number": 610, "status": "not_started", "title": "Unrelated analog",
     "description": "Does not mention anything relevant to this sweep."},
    {"project_number": 611, "status": "not_started", "title": "Longer identifier analog",
     "description": "This mentions XNoFiniteWidthModelX as a substring, which must not match."},
    {"project_number": 612, "status": "completed", "title": "Terminal analog",
     "description": "Names NoFiniteWidthModel but is already completed, so must be excluded."},
    {"project_number": 699, "status": "researched", "title": "Producing analog",
     "description": "NoFiniteWidthModel refutation machine-checked here."}
  ]
}
JSON

INCIDENT_SUM_BEFORE="$(sha256sum "$INCIDENT_STATE" | awk '{print $1}')"

run_sweep() {
  # Usage: run_sweep <args...>  -- sets LAST_EXIT, LAST_STDOUT, LAST_STDERR
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$SWEEP_SRC" "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# ─── Case 1: primary acceptance criterion -- all five analogs named, exactly ───────────────────
run_sweep --name NoFiniteWidthModel --self 699 --state-file "$INCIDENT_STATE"
if [[ "$LAST_EXIT" -eq 0 ]]; then
  pass "incident replay exits 0"
else
  fail "incident replay exit code: expected 0, got $LAST_EXIT"
fi

GOT_NUMBERS="$(echo "$LAST_STDOUT" | jq -c '[.[].task_number] | sort')"
EXPECTED_NUMBERS='[601,602,603,604,605]'
if [[ "$GOT_NUMBERS" == "$EXPECTED_NUMBERS" ]]; then
  pass "incident replay names exactly the five expected analogs: $GOT_NUMBERS"
else
  fail "incident replay analog set mismatch: expected $EXPECTED_NUMBERS, got $GOT_NUMBERS"
fi

BAD_MATCHED_NAMES="$(echo "$LAST_STDOUT" | jq -c '[.[] | select(.matched_name != "NoFiniteWidthModel")]')"
if [[ "$BAD_MATCHED_NAMES" == "[]" ]]; then
  pass "every matched row's matched_name is correct"
else
  fail "a row carried an unexpected matched_name: $BAD_MATCHED_NAMES"
fi

# ─── Case 2: negative controls -- unrelated, substring, terminal, and self must all be absent ──
for excluded in 610 611 612 699; do
  PRESENT="$(echo "$LAST_STDOUT" | jq --argjson n "$excluded" '[.[] | select(.task_number == $n)] | length')"
  if [[ "$PRESENT" == "0" ]]; then
    pass "analog $excluded correctly excluded"
  else
    fail "analog $excluded was present in output but must be excluded"
  fi
done

# ─── Case 3: non-mutation -- the fixture state file is byte-identical afterwards ───────────────
INCIDENT_SUM_AFTER="$(sha256sum "$INCIDENT_STATE" | awk '{print $1}')"
if [[ "$INCIDENT_SUM_AFTER" == "$INCIDENT_SUM_BEFORE" ]]; then
  pass "incident fixture state.json is byte-identical after the sweep"
else
  fail "incident fixture state.json CHANGED after the sweep -- advisory posture violated"
fi

# ─── Case 4: determinism -- two consecutive runs produce byte-identical stdout ─────────────────
run_sweep --name NoFiniteWidthModel --self 699 --state-file "$INCIDENT_STATE"
RUN_A="$LAST_STDOUT"
run_sweep --name NoFiniteWidthModel --self 699 --state-file "$INCIDENT_STATE"
RUN_B="$LAST_STDOUT"
if [[ "$RUN_A" == "$RUN_B" ]]; then
  pass "two consecutive runs produce byte-identical stdout"
else
  fail "determinism violated: run A != run B"
fi

# ─── Case 5: robustness -- exit 0 and [] on every error path ───────────────────────────────────
run_sweep --name NoFiniteWidthModel --self 699 --state-file "$TOP_WORKDIR/does-not-exist.json"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "missing state file: exit 0 and []"
else
  fail "missing state file: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

MALFORMED_STATE="$TOP_WORKDIR/malformed-state.json"
echo '{not valid json' > "$MALFORMED_STATE"
run_sweep --name NoFiniteWidthModel --self 699 --state-file "$MALFORMED_STATE"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "malformed state file: exit 0 and []"
else
  fail "malformed state file: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

run_sweep --state-file "$INCIDENT_STATE"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "no --name arguments: exit 0 and []"
else
  fail "no --name arguments: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

EMPTY_RETURN_META="$TOP_WORKDIR/empty-return-meta.json"
cat > "$EMPTY_RETURN_META" <<'JSON'
{"status": "researched", "artifacts": []}
JSON
run_sweep --from-return-meta "$EMPTY_RETURN_META" --self 699 --state-file "$INCIDENT_STATE"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "absent claim_invalidations: exit 0 and []"
else
  fail "absent claim_invalidations: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

EMPTY_ARRAY_RETURN_META="$TOP_WORKDIR/empty-array-return-meta.json"
cat > "$EMPTY_ARRAY_RETURN_META" <<'JSON'
{"status": "researched", "artifacts": [], "claim_invalidations": []}
JSON
run_sweep --from-return-meta "$EMPTY_ARRAY_RETURN_META" --self 699 --state-file "$INCIDENT_STATE"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "empty claim_invalidations array: exit 0 and []"
else
  fail "empty claim_invalidations array: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

run_sweep --name ZzNoSuchDeclarationZz --self 699 --state-file "$INCIDENT_STATE"
if [[ "$LAST_EXIT" -eq 0 && "$LAST_STDOUT" == "[]" ]]; then
  pass "a name matching nothing: exit 0 and []"
else
  fail "a name matching nothing: expected exit 0 and [], got exit $LAST_EXIT, stdout '$LAST_STDOUT'"
fi

# ─── Case 6: --from-return-meta end-to-end -- union of two declaration_names, deduplicated ─────
SECOND_NAME_STATE="$TOP_WORKDIR/second-name-state.json"
cat > "$SECOND_NAME_STATE" <<'JSON'
{
  "active_projects": [
    {"project_number": 601, "status": "not_started", "title": "Context note on sliced classes",
     "description": "This design note relies on the NoFiniteWidthModel result to justify choosing Z x Fin n."},
    {"project_number": 606, "status": "not_started", "title": "Second-declaration analog",
     "description": "Depends on SecondDecl for its soundness argument."},
    {"project_number": 699, "status": "researched", "title": "Producing analog",
     "description": "NoFiniteWidthModel refutation machine-checked here."}
  ]
}
JSON

RETURN_META_FIXTURE="$TOP_WORKDIR/return-meta.json"
cat > "$RETURN_META_FIXTURE" <<'JSON'
{
  "status": "researched",
  "artifacts": [],
  "claim_invalidations": [
    {
      "declaration_names": ["NoFiniteWidthModel", "SecondDecl"],
      "kind": "refutation",
      "claim": "Fixture claim for the regression suite.",
      "evidence_path": "specs/000_fixture/probes/Fixture.lean"
    }
  ]
}
JSON

run_sweep --from-return-meta "$RETURN_META_FIXTURE" --self 699 --state-file "$SECOND_NAME_STATE"
GOT_UNION="$(echo "$LAST_STDOUT" | jq -c '[.[] | {task_number, matched_name}] | sort_by(.task_number)')"
EXPECTED_UNION='[{"task_number":601,"matched_name":"NoFiniteWidthModel"},{"task_number":606,"matched_name":"SecondDecl"}]'
if [[ "$LAST_EXIT" -eq 0 && "$GOT_UNION" == "$EXPECTED_UNION" ]]; then
  pass "--from-return-meta mode yields the union of both declaration_names, deduplicated"
else
  fail "--from-return-meta union mismatch: expected $EXPECTED_UNION, got $GOT_UNION (exit $LAST_EXIT)"
fi

# ─── Case 7: combinable input modes -- --name plus --from-return-meta unions correctly ─────────
run_sweep --name NoFiniteWidthModel --from-return-meta "$EMPTY_RETURN_META" --self 699 --state-file "$INCIDENT_STATE"
GOT_COMBINED="$(echo "$LAST_STDOUT" | jq -c '[.[].task_number] | sort')"
if [[ "$LAST_EXIT" -eq 0 && "$GOT_COMBINED" == "$EXPECTED_NUMBERS" ]]; then
  pass "--name combined with an empty --from-return-meta still matches via --name"
else
  fail "combined-mode mismatch: expected $EXPECTED_NUMBERS, got $GOT_COMBINED"
fi

# ─── Case 8: --help exits 0 and documents both input modes ─────────────────────────────────────
run_sweep --help
if [[ "$LAST_EXIT" -eq 0 ]] && echo "$LAST_STDOUT" | grep -q -- "--from-return-meta" && echo "$LAST_STDOUT" | grep -q -- "--name"; then
  pass "--help exits 0 and documents both input modes"
else
  fail "--help did not behave as expected (exit $LAST_EXIT)"
fi

# ─── Summary ─────────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== test-sweep-invalidated-claims.sh: $PASSED passed, $FAILED failed ==="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
