#!/usr/bin/env bash
# validate-return-meta.sh - Validate .return-meta.json artifacts-shape files
#
# The missing sibling of validate-handoff.sh (which validates .orchestrator-handoff.json): this
# script validates a `.return-meta.json` file's structure, with particular emphasis on the
# `artifacts` array shape. Per the strict-contract-plus-normalizing-chokepoint decision recorded
# in context/formats/return-metadata-file.md's `### artifacts (required)` section: this validator
# is STRICT. A bare-string artifacts array element is a FAIL here, never silently accepted --
# normalization-with-recovery happens only at the separate consumer chokepoint
# (skill_read_metadata in scripts/skill-base.sh), not here.
#
# Contract reference: context/formats/return-metadata-file.md (the normative schema) and
# context/contracts/return-meta-artifacts-template.md (the canonical copyable artifacts template
# and path-segment type-inference table).
#
# Usage: validate-return-meta.sh <return-meta-file-path> [--fix] [--help]
#
# Exit codes:
#   0 - Valid (required fields present, artifacts correctly shaped)
#   1 - Invalid (JSON parse failure, bare-string artifacts element, or other critical failure)
#   3 - File not found

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ─── Root resolution (matches lint-agent-contracts.sh's git-rev-parse-first approach) ──────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# ─── Shared inference/normalization library (deploy-tree-first / source-store-fallback) ────────
LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/return-meta-artifacts-lib.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/return-meta-artifacts-lib.sh"
)
LIB_FILE=""
for _candidate in "${LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    LIB_FILE="$_candidate"
    break
  fi
done
if [[ -z "$LIB_FILE" ]]; then
  echo "Error: shared library return-meta-artifacts-lib.sh not found at any of:" >&2
  for _candidate in "${LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$LIB_FILE"

# ─── Argument parsing ───────────────────────────────────────────────────────────────────────────
META_FILE=""
FIX_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      FIX_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: validate-return-meta.sh <return-meta-file-path> [--fix]"
      echo ""
      echo "Validates a .return-meta.json file against context/formats/return-metadata-file.md."
      echo ""
      echo "Validation rules:"
      echo "  - JSON must be parsable."
      echo "  - status must be drawn from the normative vocabulary (in_progress | researched |"
      echo "    planned | implemented | partial | failed | blocked); 'completed' is rejected"
      echo "    explicitly."
      echo "  - artifacts must be present and be a JSON array."
      echo "  - Every element must be an OBJECT carrying non-empty type, path, and summary. A"
      echo "    bare string element is a FAIL naming the offending index and the exact repair."
      echo "  - type must be one of: report | plan | summary | implementation | handoff."
      echo "  - Each path must resolve on disk (relative to the repo root); a non-resolving path"
      echo "    is a FAIL."
      echo "  - Empty artifacts is legal for in_progress/partial/failed/blocked; required"
      echo "    non-empty for researched/planned/implemented."
      echo "  - metadata.session_id, metadata.agent_type, metadata.delegation_depth, and"
      echo "    metadata.delegation_path must be present."
      echo ""
      echo "--fix: opt-in only, never implicit. Promotes bare-string artifacts elements to the"
      echo "  object shape via the shared inference library, writes atomically (temp file plus"
      echo "  rename), and prints a per-element diff of what changed. Refuses on unparseable"
      echo "  JSON."
      echo ""
      echo "Exit codes: 0 = valid, 1 = invalid, 3 = file not found"
      exit 0
      ;;
    *)
      META_FILE="$1"
      shift
      ;;
  esac
done

if [[ -z "$META_FILE" ]]; then
  echo "Usage: validate-return-meta.sh <return-meta-file-path> [--fix]"
  exit 1
fi

if [[ ! -f "$META_FILE" ]]; then
  echo -e "${RED}[FAIL]${NC} File not found: $META_FILE"
  exit 3
fi

PASSED=0
FAILED=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }

echo "Validating return-meta: $META_FILE"
echo ""

# ─── --fix mode: promote bare strings before validating, atomically, opt-in only ───────────────
if [[ "$FIX_MODE" == "true" ]]; then
  if ! jq empty "$META_FILE" 2>/dev/null; then
    echo -e "${RED}[FAIL]${NC} --fix refuses: unparseable JSON in $META_FILE"
    exit 1
  fi
  artifacts_raw=$(jq -c '.artifacts // []' "$META_FILE")
  bare_count=$(echo "$artifacts_raw" | jq '[.[] | select(type == "string")] | length')
  if [[ "$bare_count" -gt 0 ]]; then
    echo "--fix: found $bare_count bare-string artifacts element(s), repairing..."
    normalized=$(normalize_artifacts_array "$artifacts_raw")
    tmp_file="$(mktemp "${META_FILE}.XXXXXX")"
    jq --argjson newartifacts "$normalized" '.artifacts = $newartifacts' "$META_FILE" > "$tmp_file"
    # Per-element diff report
    len=$(echo "$artifacts_raw" | jq 'length')
    for ((i = 0; i < len; i++)); do
      before=$(echo "$artifacts_raw" | jq -c ".[$i]")
      after=$(echo "$normalized" | jq -c ".[$i]")
      if [[ "$before" != "$after" ]]; then
        echo "  [$i] BEFORE: $before"
        echo "  [$i] AFTER:  $after"
      fi
    done
    mv "$tmp_file" "$META_FILE"
    echo -e "${GREEN}--fix applied.${NC} Re-validating..."
    echo ""
  else
    echo "--fix: no bare-string artifacts elements found; nothing to repair."
    echo ""
  fi
fi

# ─── Check 1: JSON parsability ──────────────────────────────────────────────────────────────────
if jq empty "$META_FILE" 2>/dev/null; then
  log_pass "JSON is valid and parsable"
else
  echo -e "${RED}[FAIL]${NC} Invalid JSON: $(jq empty "$META_FILE" 2>&1)"
  echo ""
  echo "VALIDATION FAILED (invalid JSON)"
  exit 1
fi

status=$(jq -r '.status // ""' "$META_FILE")

# ─── Check 2: status value validation ───────────────────────────────────────────────────────────
# Normative vocabulary per context/formats/return-metadata-file.md's status table.
valid_statuses=("in_progress" "researched" "planned" "implemented" "needs_research" "partial" "failed" "blocked")
status_valid=false
for valid in "${valid_statuses[@]}"; do
  if [[ "$status" == "$valid" ]]; then
    status_valid=true
    break
  fi
done
if [[ "$status" == "completed" ]]; then
  log_fail "status value is 'completed', which is explicitly forbidden (triggers Claude stop behavior) -- use 'implemented' instead"
elif [[ "$status_valid" == "true" ]]; then
  log_pass "status value is valid: $status"
else
  log_fail "status value invalid: '$status' (expected one of: ${valid_statuses[*]})"
fi

# ─── Check 3: artifacts is present and is a JSON array ─────────────────────────────────────────
artifacts_is_array=$(jq -r 'if has("artifacts") and (.artifacts | type) == "array" then "true" else "false" end' "$META_FILE")
if [[ "$artifacts_is_array" != "true" ]]; then
  log_fail "Required field missing or not an array: artifacts"
else
  artifacts_count=$(jq -r '.artifacts | length' "$META_FILE")
  case "$status" in
    researched|planned|implemented)
      if [[ "$artifacts_count" -gt 0 ]]; then
        log_pass "artifacts present ($artifacts_count entry(s), non-empty required for status='$status')"
      else
        log_fail "artifacts must be non-empty when status is researched/planned/implemented (found empty array for status='$status')"
      fi
      ;;
    *)
      log_pass "artifacts present ($artifacts_count entry(s); empty is legal for status='$status')"
      ;;
  esac

  # ─── Check 4: each artifacts element is a correctly-shaped object ────────────────────────────
  valid_types=("report" "plan" "summary" "implementation" "handoff")
  for ((idx = 0; idx < artifacts_count; idx++)); do
    el_type_kind=$(jq -r ".artifacts[$idx] | type" "$META_FILE")
    if [[ "$el_type_kind" == "string" ]]; then
      bare_val=$(jq -r ".artifacts[$idx]" "$META_FILE")
      log_fail "artifacts[$idx] is a bare string ('$bare_val'), not an object -- repair: {\"type\": \"<inferred-from-path-segment>\", \"path\": \"$bare_val\", \"summary\": \"<one-sentence description>\"} (run with --fix to apply this repair automatically)"
      continue
    fi
    if [[ "$el_type_kind" != "object" ]]; then
      log_fail "artifacts[$idx] is a $el_type_kind, not an object"
      continue
    fi

    el_type=$(jq -r ".artifacts[$idx].type // \"\"" "$META_FILE")
    el_path=$(jq -r ".artifacts[$idx].path // \"\"" "$META_FILE")
    el_summary=$(jq -r ".artifacts[$idx].summary // \"\"" "$META_FILE")

    el_ok=true
    if [[ -z "$el_type" ]]; then
      log_fail "artifacts[$idx].type is missing or empty"
      el_ok=false
    fi
    if [[ -z "$el_path" ]]; then
      log_fail "artifacts[$idx].path is missing or empty"
      el_ok=false
    fi
    if [[ -z "$el_summary" ]]; then
      log_fail "artifacts[$idx].summary is missing or empty"
      el_ok=false
    fi

    if [[ -n "$el_type" ]]; then
      type_valid=false
      for vt in "${valid_types[@]}"; do
        if [[ "$el_type" == "$vt" ]]; then
          type_valid=true
          break
        fi
      done
      if [[ "$type_valid" != "true" ]]; then
        log_fail "artifacts[$idx].type='$el_type' is not one of: ${valid_types[*]}"
        el_ok=false
      fi
    fi

    if [[ -n "$el_path" ]]; then
      if [[ ! -e "$REPO_ROOT/$el_path" ]] && [[ ! -e "$el_path" ]]; then
        log_fail "artifacts[$idx].path='$el_path' does not resolve on disk"
        el_ok=false
      fi
    fi

    if [[ "$el_ok" == "true" ]]; then
      log_pass "artifacts[$idx] is correctly shaped (type='$el_type', path='$el_path')"
    fi
  done
fi

# ─── Check 5: metadata required sub-fields ─────────────────────────────────────────────────────
for field in session_id agent_type delegation_depth delegation_path; do
  value=$(jq -r ".metadata.${field} // \"__MISSING__\"" "$META_FILE")
  if [[ "$value" == "__MISSING__" ]] || [[ "$value" == "null" ]]; then
    log_fail "Required field missing: metadata.${field}"
  else
    log_pass "Required field present: metadata.${field}"
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Validation Summary"
echo "========================================"
echo -e "Passed:   ${GREEN}$PASSED${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Failed:   ${RED}$FAILED${NC}"
echo ""

if [[ "$FAILED" -gt 0 ]]; then
  echo -e "${RED}RETURN-META VALIDATION FAILED${NC}"
  exit 1
elif [[ "$WARNINGS" -gt 0 ]]; then
  echo -e "${YELLOW}RETURN-META VALIDATION PASSED WITH WARNINGS${NC}"
  exit 0
else
  echo -e "${GREEN}RETURN-META VALIDATION PASSED${NC}"
  exit 0
fi
