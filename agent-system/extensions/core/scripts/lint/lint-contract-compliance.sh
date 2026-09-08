#!/usr/bin/env bash
# lint-contract-compliance.sh - Static compliance checks for hard-mode behavioral contracts
#
# Validates that hard-mode agents, skills, and contract files structurally comply
# with the H-technique contracts defined in agent-system/extensions/core/context/contracts/
# (source store) -- deployed at .claude/context/contracts/ in a consuming repo.
#
# WHAT THIS SCRIPT CHECKS (Tier 1 static file-content checks):
#   A. skill-orchestrate/SKILL.md's hard-mode contract injection references the required
#      contracts per phase (the standalone hard agents that used to declare these were deleted)
#   B. All 5 contract files exist and contain H-technique identifiers
#   C. orchestrate-cycle-plan.sh's resolve_agent() wires the correct per-phase caller-default
#      agent (retargeted from the deleted skill-orchestrate/SKILL.md Stage 1b -- the four-move
#      loop rewrite absorbed per-phase routing into this script; see
#      docs/architecture/orchestrate-state-machine.md)
#   D. orchestrate-churn.sh contains convergence policing fields (retargeted from the deleted
#      skill-orchestrate/SKILL.md hard_mode branch, which now calls this script instead of
#      inlining the churn state)
#   E. context/contracts/anti-analysis.md contains H2 vocabulary
#   F. index-entries.json carries no dangling references to a deleted core hard agent
#
# WHAT THIS SCRIPT DOES NOT CHECK (Tier 3 runtime behavior -- deferred):
#   - Whether agents actually honor read budgets at runtime
#   - Whether forbidden conclusions are actually absent from outputs
#   - Whether territory boundaries are enforced during parallel dispatch
#   - Whether handoff JSON is actually written at dispatch end
#   - Whether churn detection actually fires on repeated-target signatures
#
# Usage: lint-contract-compliance.sh [--verbose] [--help]
#
# Exit codes:
#   0 - All checks pass
#   1 - One or more checks failed

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: lint-contract-compliance.sh [--verbose] [--help]"
      echo ""
      echo "Runs static compliance checks for hard-mode behavioral contracts."
      echo ""
      echo "Checks:"
      echo "  A. Engine hard-mode contract injection references"
      echo "  B. Contract file existence and H-technique identifiers"
      echo "  C. Engine dispatch wiring (orchestrate-cycle-plan.sh resolve_agent caller-default agents)"
      echo "  D. Convergence policing fields in orchestrate-churn.sh"
      echo "  E. H2 vocabulary in context/contracts/anti-analysis.md"
      echo "  F. index-entries.json has no dangling deleted-hard-agent references"
      echo ""
      echo "Exit codes: 0 = all pass, 1 = failures found"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1. Use --help for usage."
      exit 2
      ;;
  esac
done

# ── Root resolution ──────────────────────────────────────────────────────────────────────────
# Uses `git rev-parse --show-toplevel` (falling back to a `REPO_ROOT` env override, then to a
# script-relative default), mirroring the sibling pattern in lint-agent-contracts.sh -- NOT the
# scripts/-depth-specific common_repo_root("$SCRIPT_DIR", N) convention used by flat scripts/*.sh.
# This script lives two levels deeper, at scripts/lint/, and validates the SOURCE STORE
# (agent-system/extensions/core/**) directly rather than a deployed .claude/ tree, so it produces
# identical results whether invoked from the deployed .claude/scripts/lint/ copy or directly from
# the agent-system/extensions/core/scripts/lint/ source-store copy.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi
PROJECT_ROOT="$REPO_ROOT"
CORE_ROOT="$REPO_ROOT/agent-system/extensions/core"

if [[ ! -d "$CORE_ROOT" ]]; then
  echo "ERROR: core extension root not found at $CORE_ROOT" >&2
  exit 2
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

log_info() {
  $VERBOSE && echo -e "${BLUE}[INFO]${NC} $1" || true
}

# ---------------------------------------------------------------------------
# Check A: Hard-mode contract injection references (scripts/orchestrate-build-dispatch.sh)
# The three standalone hard agents were deleted; the hard-mode contract set they used to
# @-reference used to live inline in skill-orchestrate/SKILL.md's Stage 3.5 Dispatch Prep
# `<hard-mode-contracts>` injection block. That whole procedure -- including this exact
# per-phase `core_contracts` case statement -- was subsequently extracted into
# scripts/orchestrate-build-dispatch.sh (the sole implementation of Stage 3.5 Dispatch Prep;
# SKILL.md itself no longer contains a `case "$phase" in` core_contracts arm at all), so this
# check now reads the script instead of the skill.
# ---------------------------------------------------------------------------
check_a_hard_agent_contract_references() {
  echo ""
  echo "--- Check A: Hard-mode contract injection references (scripts/orchestrate-build-dispatch.sh) ---"

  local orchestrate_skill="$CORE_ROOT/scripts/orchestrate-build-dispatch.sh"
  if [[ ! -f "$orchestrate_skill" ]]; then
    log_fail "scripts/orchestrate-build-dispatch.sh not found"
    return
  fi

  log_info "Checking $orchestrate_skill"

  # orchestrate-build-dispatch.sh contains THREE `case "$phase" in` statements (phase-argument
  # validation, artifact-round mode selection, and the core_contracts block this check actually
  # wants) -- unlike SKILL.md's former single occurrence, a bare `/case "\$phase" in/,/^esac/`
  # range would silently capture the wrong one (or, since only the core_contracts case's closing
  # `esac` is indented rather than column-0, run all the way to EOF). Anchor precisely instead:
  # from the hard-mode gate that guards the core_contracts case down to that case's own
  # (indented) closing `esac`.
  local case_block
  local start_line end_line
  start_line=$(grep -n 'if \[ "\$hard_mode" = "true" \]; then' "$orchestrate_skill" | head -1 | cut -d: -f1)
  if [[ -z "$start_line" ]]; then
    log_fail "scripts/orchestrate-build-dispatch.sh: hard_mode gate not found"
    return
  fi
  end_line=$(awk -v s="$start_line" 'NR > s && /^  esac$/ { print NR; exit }' "$orchestrate_skill")
  if [[ -z "$end_line" ]]; then
    log_fail "scripts/orchestrate-build-dispatch.sh: core_contracts case statement not found"
    return
  fi
  case_block=$(sed -n "${start_line},${end_line}p" "$orchestrate_skill")

  if [[ -z "$case_block" ]]; then
    log_fail "scripts/orchestrate-build-dispatch.sh: core_contracts case statement not found"
    return
  fi

  # research phase requires: anti-analysis, reference-grounding
  local research_arm
  research_arm=$(echo "$case_block" | awk '/research\)/,/;;/')
  if echo "$research_arm" | grep -qF "anti-analysis.md"; then
    log_pass "orchestrate-build-dispatch.sh: research phase: references anti-analysis contract"
  else
    log_fail "orchestrate-build-dispatch.sh: research phase: missing anti-analysis.md reference"
  fi
  if echo "$research_arm" | grep -qF "reference-grounding.md"; then
    log_pass "orchestrate-build-dispatch.sh: research phase: references reference-grounding contract"
  else
    log_fail "orchestrate-build-dispatch.sh: research phase: missing reference-grounding.md reference"
  fi

  # plan phase requires: reference-grounding
  local plan_arm
  plan_arm=$(echo "$case_block" | awk '/plan\)/,/;;/')
  if echo "$plan_arm" | grep -qF "reference-grounding.md"; then
    log_pass "orchestrate-build-dispatch.sh: plan phase: references reference-grounding contract"
  else
    log_fail "orchestrate-build-dispatch.sh: plan phase: missing reference-grounding.md reference"
  fi

  # implement phase requires: anti-analysis, wrap-up, territory (territory conditional on $territory)
  local implement_arm
  implement_arm=$(echo "$case_block" | awk '/implement\)/,/esac/')
  if echo "$implement_arm" | grep -qF "anti-analysis.md"; then
    log_pass "orchestrate-build-dispatch.sh: implement phase: references anti-analysis contract"
  else
    log_fail "orchestrate-build-dispatch.sh: implement phase: missing anti-analysis.md reference"
  fi
  if echo "$implement_arm" | grep -qF "wrap-up.md"; then
    log_pass "orchestrate-build-dispatch.sh: implement phase: references wrap-up contract"
  else
    log_fail "orchestrate-build-dispatch.sh: implement phase: missing wrap-up.md reference"
  fi
  if echo "$implement_arm" | grep -qF "territory.md"; then
    log_pass "orchestrate-build-dispatch.sh: implement phase: references territory contract (conditional)"
  else
    log_fail "orchestrate-build-dispatch.sh: implement phase: missing territory.md reference"
  fi
}

# ---------------------------------------------------------------------------
# Check B: Contract file existence and H-technique identifiers
# All 5 contract files must exist and contain their respective H-technique identifier
# ---------------------------------------------------------------------------
check_b_contract_files() {
  echo ""
  echo "--- Check B: Contract file existence and H-technique identifiers ---"

  local contracts_dir="$CORE_ROOT/context/contracts"

  declare -A CONTRACT_FILES=(
    ["anti-analysis.md"]="H2"
    ["reference-grounding.md"]="H3"
    ["convergence.md"]="H6"
    ["territory.md"]="H7"
    ["wrap-up.md"]="H9"
  )

  for contract_file in "${!CONTRACT_FILES[@]}"; do
    local technique="${CONTRACT_FILES[$contract_file]}"
    local full_path="$contracts_dir/$contract_file"

    if [[ ! -f "$full_path" ]]; then
      log_fail "Contract file missing: contracts/$contract_file"
    else
      log_info "Checking $full_path for $technique identifier"
      if grep -qE "^# .*\($technique\)|$technique:" "$full_path" 2>/dev/null; then
        log_pass "contracts/$contract_file: contains $technique identifier"
      elif grep -qF "$technique" "$full_path" 2>/dev/null; then
        log_pass "contracts/$contract_file: contains $technique reference"
      else
        log_fail "contracts/$contract_file: missing $technique identifier"
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Check C: Engine dispatch wiring (orchestrate-cycle-plan.sh resolve_agent)
# The three standalone hard skills were deleted, and the four-move loop rewrite (see
# docs/architecture/orchestrate-state-machine.md) absorbed skill-orchestrate/SKILL.md's former
# Stage 1b per-phase routing into orchestrate-cycle-plan.sh's own resolve_agent() function. This
# check asserts the three caller-default agent names are still wired there.
# ---------------------------------------------------------------------------
check_c_hard_skill_dispatch() {
  echo ""
  echo "--- Check C: Engine dispatch wiring (orchestrate-cycle-plan.sh resolve_agent) ---"

  local cycle_plan="$CORE_ROOT/scripts/orchestrate-cycle-plan.sh"

  if [[ ! -f "$cycle_plan" ]]; then
    log_fail "orchestrate-cycle-plan.sh: not found"
    return
  fi

  if grep -qF 'command-route-agent.sh' "$cycle_plan"; then
    log_pass "orchestrate-cycle-plan.sh: sources command-route-agent.sh for per-task routing"
  else
    log_fail "orchestrate-cycle-plan.sh: missing command-route-agent.sh sourcing"
  fi

  declare -A PHASE_DEFAULT_AGENTS=(
    ["research"]="general-research-agent"
    ["plan"]="planner-agent"
    ["implement"]="general-implementation-agent"
  )

  for phase in "${!PHASE_DEFAULT_AGENTS[@]}"; do
    local default_agent="${PHASE_DEFAULT_AGENTS[$phase]}"
    log_info "Checking resolve_agent() caller default for phase '$phase' -> '$default_agent'"
    if grep -qF "$default_agent" "$cycle_plan"; then
      log_pass "orchestrate-cycle-plan.sh: $phase phase wired to $default_agent (caller default)"
    else
      log_fail "orchestrate-cycle-plan.sh: $phase phase missing wired caller default $default_agent"
    fi
  done
}

# ---------------------------------------------------------------------------
# Check D: Convergence policing fields in orchestrate-churn.sh (hard_mode branch)
# Churn state file must declare total_churn, target_churn, adversarial_triggers fields. The
# four-move loop rewrite moved skill-orchestrate/SKILL.md's former inline churn-state jq into
# a single call to this script (--burnout-signal); the fields now live here, not in SKILL.md.
# ---------------------------------------------------------------------------
check_d_convergence_policing() {
  echo ""
  echo "--- Check D: Convergence policing fields in orchestrate-churn.sh ---"

  local churn_file="$CORE_ROOT/scripts/orchestrate-churn.sh"

  if [[ ! -f "$churn_file" ]]; then
    log_fail "orchestrate-churn.sh: not found -- skipping convergence checks"
    return
  fi

  log_info "Checking for convergence policing fields in $churn_file"

  for field in "total_churn" "target_churn" "adversarial_triggers"; do
    if grep -qF "$field" "$churn_file" 2>/dev/null; then
      log_pass "orchestrate-churn.sh: contains '$field' churn field"
    else
      log_fail "orchestrate-churn.sh: missing '$field' convergence policing field"
    fi
  done
}

# ---------------------------------------------------------------------------
# Check E: H2 vocabulary in context/contracts/anti-analysis.md
# The standalone core implementation-hard agent that used to restate this vocabulary is deleted;
# it now has a single home in the contract file itself, which the engine's hard-mode contract
# injection (Check A) points every implement-phase dispatch at via `<hard-mode-contracts>`.
# ---------------------------------------------------------------------------
check_e_h2_vocabulary() {
  echo ""
  echo "--- Check E: H2 vocabulary in context/contracts/anti-analysis.md ---"

  local anti_analysis="$CORE_ROOT/context/contracts/anti-analysis.md"

  if [[ ! -f "$anti_analysis" ]]; then
    log_fail "context/contracts/anti-analysis.md not found -- skipping H2 vocabulary checks"
    return
  fi

  log_info "Checking H2 vocabulary in $anti_analysis"

  # forbidden conclusions (exact phrase or close variant)
  if grep -qiE "Forbidden [Cc]onclusions|forbidden-conclusions|forbidden conclusions" "$anti_analysis" 2>/dev/null; then
    log_pass "anti-analysis.md: contains 'Forbidden Conclusions' H2 term"
  else
    log_fail "anti-analysis.md: missing 'Forbidden Conclusions' H2 vocabulary"
  fi

  # defect bar (exact phrase or variant)
  if grep -qiE "[Dd]efect [Bb]ar|defect-bar" "$anti_analysis" 2>/dev/null; then
    log_pass "anti-analysis.md: contains 'Defect Bar' H2 term"
  else
    log_fail "anti-analysis.md: missing 'Defect Bar' H2 vocabulary"
  fi

  # settled-design (H2 concept: re-opening settled decisions requires counterexample)
  if grep -qiE "settled[- ][Dd]esign|settled design" "$anti_analysis" 2>/dev/null; then
    log_pass "anti-analysis.md: contains 'settled-design' H2 term"
  else
    log_warn "anti-analysis.md: 'settled-design' term not found (optional H2 vocabulary)"
  fi
}

# ---------------------------------------------------------------------------
# Check F: index-entries.json contract coverage for hard agents
# The three standalone core hard agents this check used to assert coverage for are deleted from
# agent-system/extensions/core/. Coverage is no longer a meaningful assertion for them -- there
# is nothing left in core to have "at least one context entry" for -- so the coverage list is
# emptied rather than repointed. Pruning the dangling load_when.agents[] entries that still name
# these deleted agents is a SEPARATE, already-tracked concern (index-entries.json cleanup, plus
# test-index-entries-schema.sh), not this check's job: asserting their absence here would fail
# immediately, before that pruning has landed, breaking this lint's baseline.
# cslib's and lean's own `-hard` agents are unaffected and were never in this check's scope.
# Reads core's SOURCE `index-entries.json` (not the deployed, merged `.claude/context/index.json`
# artifact) -- consistent with this script validating the source store throughout.
# ---------------------------------------------------------------------------
check_f_index_coverage() {
  echo ""
  echo "--- Check F: index-entries.json contract coverage for hard agents ---"

  local index_file="$CORE_ROOT/index-entries.json"

  if [[ ! -f "$index_file" ]]; then
    log_fail "index-entries.json not found at $index_file"
    return
  fi

  if ! jq empty "$index_file" 2>/dev/null; then
    log_fail "index-entries.json is not valid JSON"
    return
  fi

  # No core hard agents remain to check coverage for -- see header comment.
  local hard_agents=()

  if [[ ${#hard_agents[@]} -eq 0 ]]; then
    log_pass "index-entries.json: no core hard agents remain to check coverage for (deleted)"
  fi

  for agent in "${hard_agents[@]}"; do
    local count
    count=$(jq -r "[.entries[] | select(.load_when.agents[]? == \"$agent\")] | length" "$index_file" 2>/dev/null || echo "0")
    if [[ "$count" -gt 0 ]]; then
      log_pass "index-entries.json: $agent has $count context entries"
    else
      log_warn "index-entries.json: $agent has 0 context entries (contracts not indexed?)"
    fi
  done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "========================================"
  echo "Contract Compliance Lint"
  echo "========================================"
  echo "Project root: $PROJECT_ROOT"

  check_a_hard_agent_contract_references
  check_b_contract_files
  check_c_hard_skill_dispatch
  check_d_convergence_policing
  check_e_h2_vocabulary
  check_f_index_coverage

  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}CONTRACT COMPLIANCE LINT FAILED ($FAILED failures)${NC}"
    echo ""
    echo "Reference: agent-system/extensions/core/context/contracts/ for contract definitions"
    exit 1
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo -e "${YELLOW}CONTRACT COMPLIANCE LINT PASSED WITH WARNINGS${NC}"
    exit 0
  else
    echo -e "${GREEN}CONTRACT COMPLIANCE LINT PASSED${NC}"
    exit 0
  fi
}

main "$@"
