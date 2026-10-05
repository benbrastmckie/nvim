#!/usr/bin/env bash
# validate-handoff.sh - Validate orchestrator handoff JSON files
#
# Validates .orchestrator-handoff.json files produced by a hard-mode implementation agent
# (cslib/lean today; core's own standalone hard-mode engine is deleted) and read by
# skill-orchestrate, checking JSON structure, required fields, and status/continuation
# consistency.
#
# Contract reference: .claude/context/schemas/orchestrator-handoff-schema.json
# (the machine-checkable authority) and .claude/context/contracts/wrap-up.md (H9, prose)
#
# Usage: validate-handoff.sh <handoff-file-path> [--help]
#
# Exit codes:
#   0 - Valid (required fields present, status consistent)
#   1 - Invalid (JSON parse failure or critical field missing)
#   3 - File not found

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
HANDOFF_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      echo "Usage: validate-handoff.sh <handoff-file-path>"
      echo ""
      echo "Validates an .orchestrator-handoff.json file against"
      echo "context/schemas/orchestrator-handoff-schema.json (the machine-checkable authority;"
      echo "see also wrap-up.md's H9 prose contract)."
      echo ""
      echo "Required fields: status, summary, artifacts, phases_completed, phases_total, blockers"
      echo "Optional fields: phase, plan_markers_verified, skeleton, sorry_inventory, dispatch_seq,"
      echo "  continuation_path, continuation_context (deprecated, read-only), next_action_hint,"
      echo "  git_checkpoint"
      echo "Conditionally-required field: skeleton (boolean, defaults to false)"
      echo ""
      echo "Validation rules:"
      echo "  - JSON must be parsable"
      echo "  - status must be: researched | planned | implemented | partial | failed | blocked"
      echo "  - artifacts must be present and be a JSON array; non-empty required when status is"
      echo "    researched, planned, or implemented (empty [] is legal for partial/blocked/failed)"
      echo "  - summary must be present and a non-empty string"
      echo "  - When status is partial or blocked: continuation_path or continuation_context must be non-null"
      echo "  - When status is partial: phases_completed must be < phases_total"
      echo "  - skeleton=true requires status=='implemented', a non-empty sorry_inventory, and every"
      echo "    strategic:true entry must have non-empty assumption/why_deferred and non-null"
      echo "    follow_up_task"
      echo "  - dispatch_seq: present-and-integer passes; absent WARNs (never rejects -- the strict"
      echo "    reject-on-absent form is deliberately not adopted); present-but-non-integer FAILs"
      echo "  - sorry_inventory absence is not reported outside skeleton mode (hard-mode-only field;"
      echo "    expected absent on every base-mode handoff)"
      echo "  - continuation-pointer (continuation_path/continuation_context) absence is reported"
      echo "    only when status is partial or blocked (Check 5); not reported for other statuses"
      echo ""
      echo "Exit codes: 0 = valid, 1 = invalid, 3 = file not found"
      exit 0
      ;;
    *)
      HANDOFF_FILE="$1"
      shift
      ;;
  esac
done

if [[ -z "$HANDOFF_FILE" ]]; then
  echo "Usage: validate-handoff.sh <handoff-file-path>"
  exit 1
fi

if [[ ! -f "$HANDOFF_FILE" ]]; then
  echo -e "${RED}[FAIL]${NC} File not found: $HANDOFF_FILE"
  exit 3
fi

# Counters
PASSED=0
FAILED=0
WARNINGS=0

log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  WARNINGS=$((WARNINGS + 1))
}

echo "Validating handoff: $HANDOFF_FILE"
echo ""

# --- Check 1: JSON parsability ---
if jq empty "$HANDOFF_FILE" 2>/dev/null; then
  log_pass "JSON is valid and parsable"
else
  echo -e "${RED}[FAIL]${NC} Invalid JSON: $(jq empty "$HANDOFF_FILE" 2>&1)"
  echo ""
  echo "VALIDATION FAILED (invalid JSON)"
  exit 1
fi

# --- Read status and skeleton early (needed for skeleton-aware Check 3 below) ---
status=$(jq -r ".status // \"\"" "$HANDOFF_FILE" 2>/dev/null)
skeleton=$(jq -r ".skeleton // false" "$HANDOFF_FILE" 2>/dev/null)

# --- Check 2: Required field existence ---
required_fields=("status" "phases_completed" "phases_total" "blockers")
for field in "${required_fields[@]}"; do
  value=$(jq -r ".$field // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
  if [[ "$value" == "__MISSING__" ]] || [[ "$value" == "null" && "$field" != "blockers" ]]; then
    log_fail "Required field missing or null: $field"
  else
    log_pass "Required field present: $field"
  fi
done

# --- Check 2b: summary (required, non-empty string) ---
summary_value=$(jq -r ".summary // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
if [[ "$summary_value" == "__MISSING__" ]] || [[ "$summary_value" == "null" ]] || [[ -z "$summary_value" ]]; then
  log_fail "Required field missing or empty: summary"
else
  log_pass "Required field present: summary"
fi

# --- Check 2c: artifacts (required array; non-empty required for researched/planned/implemented) ---
artifacts_is_array=$(jq -r "if has(\"artifacts\") and (.artifacts | type) == \"array\" then \"true\" else \"false\" end" "$HANDOFF_FILE" 2>/dev/null)
if [[ "$artifacts_is_array" != "true" ]]; then
  log_fail "Required field missing or not an array: artifacts"
else
  artifacts_count=$(jq -r ".artifacts | length" "$HANDOFF_FILE" 2>/dev/null || echo "0")
  case "$status" in
    researched|planned|implemented)
      if [[ "$artifacts_count" -gt 0 ]]; then
        log_pass "Required field present: artifacts ($artifacts_count entry(s), non-empty required for status='$status')"
      else
        log_fail "artifacts must be non-empty when status is researched/planned/implemented (found empty array for status='$status')"
      fi
      ;;
    *)
      log_pass "Required field present: artifacts ($artifacts_count entry(s); empty is legal for status='$status')"
      ;;
  esac

  if [[ "$artifacts_count" -gt 0 ]]; then
    entry0_kind=$(jq -r ".artifacts[0] | type" "$HANDOFF_FILE" 2>/dev/null)
    if [[ "$entry0_kind" != "object" ]]; then
      log_fail "artifacts[0] is a $entry0_kind, not an object -- a bare-string (or other non-object) artifacts element is never valid, per handoff-schema.md's ### artifacts (required) section; repair to {\"type\": ..., \"path\": ..., \"summary\": ...}"
    else
      entry0_type=$(jq -r ".artifacts[0].type // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
      entry0_path=$(jq -r ".artifacts[0].path // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
      entry0_summary=$(jq -r ".artifacts[0].summary // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
      if [[ "$entry0_type" == "__MISSING__" ]] || [[ "$entry0_path" == "__MISSING__" ]]; then
        log_fail "artifacts[0] missing required field(s): type and/or path"
      else
        log_pass "artifacts[0] has required fields (type, path)"
      fi
      if [[ "$entry0_summary" == "__MISSING__" ]]; then
        log_warn "artifacts[0].summary absent (optional per schema, but read by both orchestrate engines)"
      fi
    fi
  fi
fi

# --- Check 3: sorry_inventory validation (skeleton-aware) ---
sorry_inventory_present=true
if [[ "$(jq -r ".sorry_inventory // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)" == "__MISSING__" ]]; then
  sorry_inventory_present=false
fi
sorry_count=$(jq -r ".sorry_inventory | length" "$HANDOFF_FILE" 2>/dev/null || echo "0")

if [[ "$skeleton" == "true" ]]; then
  # --- status/skeleton combination (wrap-up.md interaction table) ---
  if [[ "$status" != "implemented" ]]; then
    log_fail "Invalid status/skeleton combination: skeleton=true requires status=='implemented' (found status='$status'); see wrap-up.md status/skeleton interaction table"
  else
    log_pass "skeleton=true paired with status='implemented' (valid combination)"
  fi

  # --- skeleton mode requires a non-empty sorry_inventory ---
  if [[ "$sorry_inventory_present" == "false" ]] || [[ "$sorry_count" -eq 0 ]]; then
    log_fail "skeleton=true requires non-empty sorry_inventory enumerating every strategic sorry"
  else
    log_pass "sorry_inventory present with $sorry_count entry(s) (skeleton mode)"

    invalid_entries=0
    strategic_count=0
    for i in $(seq 0 $((sorry_count - 1))); do
      strategic=$(jq -r ".sorry_inventory[$i].strategic // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
      if [[ "$strategic" == "true" ]]; then
        strategic_count=$((strategic_count + 1))
        assumption=$(jq -r ".sorry_inventory[$i].assumption // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        why_deferred=$(jq -r ".sorry_inventory[$i].why_deferred // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        follow_up_task=$(jq -r ".sorry_inventory[$i].follow_up_task // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
        entry_bad=false
        if [[ -z "$assumption" ]] || [[ "$assumption" == "__MISSING__" ]] || [[ "$assumption" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but assumption is empty/missing"
          entry_bad=true
        fi
        if [[ -z "$why_deferred" ]] || [[ "$why_deferred" == "__MISSING__" ]] || [[ "$why_deferred" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but why_deferred is empty/missing"
          entry_bad=true
        fi
        if [[ "$follow_up_task" == "__MISSING__" ]] || [[ "$follow_up_task" == "null" ]]; then
          log_fail "sorry_inventory[$i]: strategic=true but follow_up_task is null/missing (untracked strategic sorry -- relaxed zero-debt must stay tracked)"
          entry_bad=true
        fi
        if [[ "$entry_bad" == "true" ]]; then
          invalid_entries=$((invalid_entries + 1))
        fi
      fi
    done

    if [[ "$strategic_count" -eq 0 ]]; then
      log_fail "skeleton=true but no sorry_inventory entry has strategic:true (skeleton dispatch requires at least one tracked strategic sorry)"
    elif [[ "$invalid_entries" -eq 0 ]]; then
      log_pass "All $strategic_count strategic sorry entry(s) are fully tracked (assumption, why_deferred, follow_up_task all present)"
    fi
  fi
else
  # --- STANDARD mode (skeleton absent/false) ---
  # sorry_inventory is a hard-mode-only field (see handoff-schema.md's ### sorry_inventory
  # section): its absence is the expected, universal case for every base-mode writer, so
  # absence is silent here -- WARNing on it would fire on ~100% of ordinary dispatches.
  if [[ "$sorry_inventory_present" == "true" ]]; then
    log_pass "Optional field present: sorry_inventory"
  fi
fi

# --- Check 3b: dispatch_seq validation (conditionally-required, same idiom as skeleton) ---
dispatch_seq_raw=$(jq -r ".dispatch_seq // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
if [[ "$dispatch_seq_raw" == "__MISSING__" ]] || [[ "$dispatch_seq_raw" == "null" ]]; then
  log_warn "Optional field absent: dispatch_seq (writer contract: echo back the delegation context's dispatch_seq unchanged; see context/patterns/dispatch-report-not-termination.md and docs/architecture/handoff-schema.md)"
elif [[ "$dispatch_seq_raw" =~ ^-?[0-9]+$ ]]; then
  log_pass "dispatch_seq present and is an integer: $dispatch_seq_raw"
else
  log_fail "dispatch_seq present but not an integer: '$dispatch_seq_raw'"
fi

# continuation_path or continuation_context (one of these two forms is acceptable).
# Pure variable capture here -- Check 5 below is the single, correctly status-conditioned
# reporting site for this field (it WARNs exactly when status is partial/blocked with no
# continuation pointer set); reporting unconditionally here was redundant and fired on every
# implemented-status handoff, where absence is schematically correct.
continuation_path=$(jq -r ".continuation_path // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
continuation_context=$(jq -r ".continuation_context // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)

# --- Check 4: Status value validation ---
status=$(jq -r ".status // \"\"" "$HANDOFF_FILE" 2>/dev/null)
valid_statuses=("researched" "planned" "implemented" "needs_research" "partial" "failed" "blocked")
status_valid=false
for valid in "${valid_statuses[@]}"; do
  if [[ "$status" == "$valid" ]]; then
    status_valid=true
    break
  fi
done

if [[ "$status_valid" == "true" ]]; then
  log_pass "Status value is valid: $status"
else
  log_fail "Status value invalid: '$status' (expected: researched | planned | implemented | partial | failed | blocked)"
fi

# --- Check 5: Status/continuation consistency ---
if [[ "$status" == "partial" ]] || [[ "$status" == "blocked" ]]; then
  # Continuation must be non-null
  path_is_set=false
  if [[ "$continuation_path" != "__MISSING__" ]] && [[ "$continuation_path" != "null" ]]; then
    path_is_set=true
  fi
  context_is_set=false
  if [[ "$continuation_context" != "__MISSING__" ]] && [[ "$continuation_context" != "null" ]]; then
    context_is_set=true
  fi

  if [[ "$path_is_set" == "true" ]] || [[ "$context_is_set" == "true" ]]; then
    log_pass "Status is '$status' and continuation field is non-null (consistent)"
  else
    log_warn "Status is '$status' but continuation_path and continuation_context are both null or absent (inconsistent)"
  fi
fi

# --- Check 6: Phase count consistency for partial status ---
if [[ "$status" == "partial" ]]; then
  phases_completed=$(jq -r ".phases_completed // -1" "$HANDOFF_FILE" 2>/dev/null)
  phases_total=$(jq -r ".phases_total // -1" "$HANDOFF_FILE" 2>/dev/null)

  if [[ "$phases_completed" -ne -1 ]] && [[ "$phases_total" -ne -1 ]]; then
    if [[ "$phases_completed" -lt "$phases_total" ]]; then
      log_pass "Partial status: phases_completed ($phases_completed) < phases_total ($phases_total)"
    else
      log_warn "Partial status: phases_completed ($phases_completed) >= phases_total ($phases_total) (expected incomplete)"
    fi
  fi
fi

# --- Check 7: Blockers array structure (when non-empty) ---
blockers_count=$(jq -r ".blockers | length" "$HANDOFF_FILE" 2>/dev/null || echo "0")
if [[ "$blockers_count" -gt 0 ]]; then
  log_pass "Blockers array present with $blockers_count entry(s)"
  # Validate each blocker has the minimum expected fields
  invalid_blockers=0
  for i in $(seq 0 $((blockers_count - 1))); do
    has_phase=$(jq -r ".blockers[$i].phase // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
    has_target=$(jq -r ".blockers[$i].target // \"__MISSING__\"" "$HANDOFF_FILE" 2>/dev/null)
    if [[ "$has_phase" == "__MISSING__" ]] || [[ "$has_target" == "__MISSING__" ]]; then
      invalid_blockers=$((invalid_blockers + 1))
    fi
  done
  if [[ "$invalid_blockers" -eq 0 ]]; then
    log_pass "All blockers have required fields (phase, target)"
  else
    log_warn "$invalid_blockers blocker(s) missing required fields (phase and/or target)"
  fi
else
  log_pass "Blockers array is empty or absent (normal for implemented status)"
fi

# --- Summary ---
echo ""
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}HANDOFF VALIDATION FAILED${NC}"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo -e "${YELLOW}HANDOFF VALIDATION PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "${GREEN}HANDOFF VALIDATION PASSED${NC}"
  exit 0
fi
