#!/usr/bin/env bash
# lint-routing-wiring.sh - Routing wiring validation for extension manifests
#
# Validates, across every manifest under agent-system/extensions/*/manifest.json:
#   A. Research-anchored completeness: every task_type key present under
#      `.routing_agents.research` has a counterpart key under `.routing_agents.plan` and
#      `.routing_agents.implement` on the same manifest. A missing counterpart is a FAIL, not a
#      silent fallback -- this is the class of defect that let sed-derived agent names silently
#      resolve to non-existent files. Keys present in `plan`/`implement` but absent from
#      `research` (including an extension-specific op's own keys, e.g. `present`'s bare `slides`
#      key) are REPORTed, never failed.
#   B. Every value in `.routing_agents` / `.routing_agents_hard` names an agent file that exists
#      somewhere under agent-system/extensions/*/agents/ in the source store. A declaration
#      pointing at a non-existent agent is a FAIL.
#   C. `routing_agents_hard` internal completeness: every task_type declared under any
#      `.routing_agents_hard.{op}` has a same-op counterpart key under `.routing_agents.{op}` (a
#      hard-mode entry for a task_type standard mode cannot route is the gap this catches). Plan
#      parity is NOT required in `routing_agents_hard` -- `cslib` and `lean` legitimately declare
#      `research` + `implement` only.
#   D. (Report, never fail) Every `(op, task_type)` pair whose declared routing_agents value is a
#      `general-*` agent, so deliberate general-routing stays visible and auditable rather than
#      indistinguishable from an accidental gap.
#
# Sources manifest-routing-lib.sh (with ROUTE_MANIFEST_ROOT=agent-system, so the exact same
# ladder that validates deployed resolution also validates the source store pre-deploy) rather
# than re-deriving manifest-scanning logic -- see that library's header for the
# ROUTE_MANIFEST_ROOT contract.
#
# Root resolution: uses `git rev-parse --show-toplevel` (falling back to a `REPO_ROOT` env
# override, then to a script-relative default), matching lint-agent-contracts.sh's convention --
# this script lives at the same scripts/lint/ depth and is designed to run identically from
# either the deployed .claude/scripts/lint/ copy or the agent-system/extensions/core/scripts/lint/
# source-store copy.
#
# Usage: lint-routing-wiring.sh [--verbose] [--help]
#
# Exit codes:
#   0 - all checks pass (warnings/Check D report allowed)
#   1 - one or more checks failed
#   2 - environment/usage error (manifest-routing-lib.sh missing, unknown argument, jq missing)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: lint-routing-wiring.sh [--verbose] [--help]"
      echo ""
      echo "Routing wiring validation for extension manifests."
      echo ""
      echo "Checks:"
      echo "  A. Every routing_agents.research task_type has routing_agents.plan/.implement counterparts"
      echo "  B. Every routing_agents/routing_agents_hard value names an agent file that exists"
      echo "  C. Every routing_agents_hard.{op} task_type has a routing_agents.{op} counterpart"
      echo "  D. (Report only) general-* agent declarations, for visibility"
      echo ""
      echo "Exit codes: 0 = all pass, 1 = failures found, 2 = environment/usage error"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1. Use --help for usage." >&2
      exit 2
      ;;
  esac
done

# ── Root resolution ──────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-}"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
fi

EXT_ROOT="$REPO_ROOT/agent-system/extensions"
LIB_FILE="$REPO_ROOT/agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh"

if [[ ! -d "$EXT_ROOT" ]]; then
  echo "ERROR: extensions root not found at $EXT_ROOT" >&2
  exit 2
fi
if [[ ! -f "$LIB_FILE" ]]; then
  echo "ERROR: manifest-routing-lib.sh not found at $LIB_FILE" >&2
  exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi

# Source the shared ladder against the SOURCE STORE (not the deployed tree) -- see this script's
# header and manifest-routing-lib.sh's ROUTE_MANIFEST_ROOT contract.
export ROUTE_MANIFEST_ROOT="$REPO_ROOT/agent-system"
# shellcheck source=../lib/manifest-routing-lib.sh
source "$LIB_FILE"

PASSED=0
FAILED=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_info() { $VERBOSE && echo -e "${BLUE}[INFO]${NC} $1" || true; }
log_report() { echo -e "${YELLOW}[REPORT]${NC} $1"; }

rel_path() {
  local f="$1"
  echo "${f#"$REPO_ROOT"/}"
}

# ── Check A: routing_agents.research task_types have routing_agents.plan/.implement counterparts ──
check_a() {
  echo ""
  echo "--- Check A: routing_agents.research task_types have routing_agents.plan/.implement counterparts ---"

  local any_manifest=false
  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    any_manifest=true
    local rel
    rel="$(rel_path "$manifest")"
    log_info "Checking $rel"

    # Research-anchored: every task_type key under routing_agents.research must have a
    # same-key counterpart under routing_agents.plan and routing_agents.implement.
    while IFS= read -r tt; do
      [[ -z "$tt" ]] && continue
      local has_plan has_impl
      has_plan=$(jq -r --arg tt "$tt" \
        '((.routing_agents.plan // {}) | has($tt))' "$manifest" 2>/dev/null)
      has_impl=$(jq -r --arg tt "$tt" \
        '((.routing_agents.implement // {}) | has($tt))' "$manifest" 2>/dev/null)
      if [[ "$has_plan" == "true" ]]; then
        log_pass "$rel: routing_agents.research.$tt has a routing_agents.plan counterpart"
      else
        log_fail "$rel: routing_agents.research.$tt has NO routing_agents.plan counterpart"
      fi
      if [[ "$has_impl" == "true" ]]; then
        log_pass "$rel: routing_agents.research.$tt has a routing_agents.implement counterpart"
      else
        log_fail "$rel: routing_agents.research.$tt has NO routing_agents.implement counterpart"
      fi
    done < <(jq -r '(.routing_agents.research // {}) | keys[]' "$manifest" 2>/dev/null)

    # Keys present in plan/implement but absent from research are REPORTed, never failed -- this
    # is the one-directional half of the rule (e.g. present.plan's extra bare "slides" key).
    while IFS=$'\t' read -r op tt; do
      [[ -z "$op" ]] && continue
      local in_research
      in_research=$(jq -r --arg tt "$tt" \
        '((.routing_agents.research // {}) | has($tt))' "$manifest" 2>/dev/null)
      if [[ "$in_research" != "true" ]]; then
        log_report "$rel: routing_agents.$op.$tt has no routing_agents.research counterpart (extra, not failed)"
      fi
    done < <(jq -r '
      ["plan","implement"][] as $op
      | (.routing_agents[$op] // {}) | keys[] as $tt
      | "\($op)\t\($tt)"
    ' "$manifest" 2>/dev/null)
  done < <(find "$EXT_ROOT" -maxdepth 2 -name "manifest.json" -type f | sort)

  if [[ "$any_manifest" == false ]]; then
    log_fail "Check A: no manifests found under $EXT_ROOT"
  fi
}

# ── Check C: routing_agents_hard.{op}.{tt} has a same-op routing_agents.{op}.{tt} counterpart ──
check_c() {
  echo ""
  echo "--- Check C: routing_agents_hard.{op} task_types have routing_agents.{op} counterparts ---"

  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    local rel
    rel="$(rel_path "$manifest")"

    while IFS=$'\t' read -r op tt; do
      [[ -z "$op" ]] && continue
      local has_counterpart
      has_counterpart=$(jq -r --arg op "$op" --arg tt "$tt" \
        '((.routing_agents[$op] // {}) | has($tt))' "$manifest" 2>/dev/null)
      if [[ "$has_counterpart" == "true" ]]; then
        log_pass "$rel: routing_agents_hard.$op.$tt has a routing_agents.$op counterpart"
      else
        log_fail "$rel: routing_agents_hard.$op.$tt has NO routing_agents.$op counterpart"
      fi
    done < <(jq -r '(.routing_agents_hard // {}) | to_entries[] | .key as $op | (.value | keys[]) as $tt | "\($op)\t\($tt)"' "$manifest" 2>/dev/null)
  done < <(find "$EXT_ROOT" -maxdepth 2 -name "manifest.json" -type f | sort)
}

# ── Check B: every routing_agents/routing_agents_hard value names an agent that exists ─────────
check_b() {
  echo ""
  echo "--- Check B: every routing_agents/routing_agents_hard value names an existing agent file ---"

  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    local rel
    rel="$(rel_path "$manifest")"

    for block in routing_agents routing_agents_hard; do
      while IFS=$'\t' read -r op tt agent; do
        [[ -z "$op" ]] && continue
        local found=false
        while IFS= read -r agent_file; do
          [[ -n "$agent_file" ]] && found=true && break
        done < <(find "$EXT_ROOT" -maxdepth 3 -path "*/agents/${agent}.md" -type f 2>/dev/null)
        if [[ "$found" == true ]]; then
          log_pass "$rel: $block.$op.$tt = $agent (agent file exists)"
        else
          log_fail "$rel: $block.$op.$tt = $agent (no such agent file under any extension's agents/)"
        fi
      done < <(jq -r --arg b "$block" \
        '(.[$b] // {}) | to_entries[] | .key as $op | (.value | to_entries[]) | "\($op)\t\(.key)\t\(.value)"' \
        "$manifest" 2>/dev/null)
    done
  done < <(find "$EXT_ROOT" -maxdepth 2 -name "manifest.json" -type f | sort)
}

# ── Check D: report (never fail) general-* declarations ────────────────────────────────────────
check_d() {
  echo ""
  echo "--- Check D (report only): (op, task_type) pairs declared to a general-* agent ---"

  local any_general=false
  while IFS= read -r manifest; do
    [[ -z "$manifest" ]] && continue
    local rel
    rel="$(rel_path "$manifest")"

    while IFS=$'\t' read -r op tt agent; do
      [[ -z "$op" ]] && continue
      any_general=true
      log_report "$rel: routing_agents.$op.$tt = $agent"
    done < <(jq -r \
      '(.routing_agents // {}) | to_entries[] | .key as $op | (.value | to_entries[] | select(.value | startswith("general-"))) | "\($op)\t\(.key)\t\(.value)"' \
      "$manifest" 2>/dev/null)
  done < <(find "$EXT_ROOT" -maxdepth 2 -name "manifest.json" -type f | sort)

  if [[ "$any_general" == false ]]; then
    log_info "No general-* routing_agents declarations found"
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────────────────────
main() {
  echo "========================================"
  echo "Routing Wiring Lint"
  echo "========================================"
  echo "Repo root:  $REPO_ROOT"
  echo "Ext root:   $EXT_ROOT"

  check_a
  check_b
  check_c
  check_d

  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}ROUTING WIRING LINT FAILED ($FAILED failures)${NC}"
    exit 1
  else
    echo -e "${GREEN}ROUTING WIRING LINT PASSED${NC}"
    exit 0
  fi
}

main "$@"
