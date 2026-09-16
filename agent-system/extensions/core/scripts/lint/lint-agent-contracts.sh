#!/usr/bin/env bash
# lint-agent-contracts.sh - Frontmatter and no-task-references contract checks for agent files
#
# Validates, across every dispatchable subagent file under agent-system/extensions/*/agents/**
# and agent-system/extensions/*/context/project/*/agents/**:
#   A. Frontmatter key validity -- no `allowed-tools:` or `mcp-servers:` (both are silent
#      no-ops on subagent frontmatter, not errors -- see
#      docs/reference/standards/agent-frontmatter-standard.md's Invalid on Agent Files section);
#      warn on any frontmatter key outside the documented supported-field set.
#   B. `model:` presence and validity (must be one of opus|sonnet|haiku) on every dispatchable
#      agent.
#   C. No-task-references MUST-NOT bullet presence, for the curated in-scope agent set defined by
#      the classification rule in context/contracts/no-task-references-bullet.md. The expected
#      bullet text is read from that fragment file at runtime, never hardcoded here, so the
#      fragment stays load-bearing rather than decorative.
#   F. Return-meta `artifacts` template presence: every dispatchable agent that writes
#      `.return-meta.json` must carry an object-shaped `artifacts` array (keys `type`, `path`,
#      `summary`) somewhere in its file -- a bare-string array or a missing template both FAIL.
#      The required key set is read from context/contracts/return-meta-artifacts-template.md's
#      fenced JSON template at runtime, never hardcoded here, mirroring Check C's own
#      read-from-fragment mechanism. A small, explicitly recorded exclusion list (agents that do
#      NOT write `.return-meta.json` at all -- see that fragment's classification rule) is
#      skipped, not failed.
#
# Dispatchable-agent detector (shared, reusable): a file under an `agents/`-named path counts as
# a dispatchable agent only if its first line is `---` and its frontmatter block contains a
# `name:` key. This is deliberately frontmatter-gated, not path-gated -- three files sit under
# `agents/`-named directories without being real dispatchable agents (`core/agents/README.md`
# and the two `lean/context/project/lean4/agents/lean-{research,implementation}-flow.md` files,
# neither of which has a frontmatter block at all) and must be excluded. Both the deferred
# body-skeleton-drift lint (Check D) and the deferred terminal-metadata-presence lint (Check E)
# are expected to reuse `is_dispatchable_agent`/`enumerate_dispatchable_agents` rather than
# re-deriving the detector -- see the commented insertion point near the bottom of this file.
# Check F (implemented, unlike D/E) already reuses both, per the same instruction.
#
# Root resolution: uses `git rev-parse --show-toplevel` (falling back to a `REPO_ROOT` env
# override, then to a script-relative default) rather than the scripts/-depth-specific
# deploy-root-guard.sh convention used by scripts/*.sh -- this script lives two levels deeper, at
# scripts/lint/, and is designed to run identically from either the deployed
# .claude/scripts/lint/ copy or directly from the agent-system/extensions/core/scripts/lint/
# source-store copy (read-only, so there is no destructive-write risk `git rev-parse` would mask).
#
# Usage: lint-agent-contracts.sh [--verbose] [--help]
#
# Exit codes:
#   0 - all checks pass (warnings allowed)
#   1 - one or more checks failed
#   2 - environment/usage error (fragment file missing, unknown argument)

set -euo pipefail

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
      echo "Usage: lint-agent-contracts.sh [--verbose] [--help]"
      echo ""
      echo "Frontmatter and no-task-references contract checks for dispatchable agent files."
      echo ""
      echo "Checks:"
      echo "  A. Frontmatter key validity (allowed-tools:/mcp-servers: forbidden; unknown keys warned)"
      echo "  B. model: presence and validity (opus|sonnet|haiku)"
      echo "  C. No-task-references MUST-NOT bullet presence for the curated in-scope agent set"
      echo "  F. Return-meta artifacts template presence (object-shaped, keys read from the fragment)"
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

AGENTS_ROOT="$REPO_ROOT/agent-system/extensions"
STANDARD_FILE="$REPO_ROOT/agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md"
FRAGMENT_FILE="$REPO_ROOT/agent-system/extensions/core/context/contracts/no-task-references-bullet.md"
ARTIFACTS_TEMPLATE_FRAGMENT="$REPO_ROOT/agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md"

if [[ ! -d "$AGENTS_ROOT" ]]; then
  echo "ERROR: agents root not found at $AGENTS_ROOT" >&2
  exit 2
fi

PASSED=0
FAILED=0
WARNINGS=0

log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
log_info() { $VERBOSE && echo -e "${BLUE}[INFO]${NC} $1" || true; }

# ── Shared dispatchable-agent detector ──────────────────────────────────────────────────────
# A file under an `agents/`-named path qualifies as a dispatchable agent only if its first line
# is `---` AND its frontmatter block contains a `name:` key. Excludes core/agents/README.md and
# the two lean4 flow files (neither has any frontmatter at all).
is_dispatchable_agent() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local first_line
  first_line="$(head -n1 "$f")"
  [[ "$first_line" == "---" ]] || return 1
  # Extract the frontmatter body: everything between the opening and closing `---` lines.
  local fm
  fm="$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")"
  grep -qE '^name:' <<<"$fm" && return 0
  return 1
}

# Prints the frontmatter body (between the opening and closing `---` markers) of a dispatchable
# agent file. Caller is responsible for having already confirmed is_dispatchable_agent.
frontmatter_body() {
  local f="$1"
  awk 'NR==1{next} /^---$/{exit} {print}' "$f"
}

enumerate_dispatchable_agents() {
  find "$AGENTS_ROOT" -path "*/agents/*.md" -type f 2>/dev/null | sort | while IFS= read -r f; do
    if is_dispatchable_agent "$f"; then
      echo "$f"
    fi
  done
}

rel_path() {
  local f="$1"
  echo "${f#"$REPO_ROOT"/}"
}

# ── Check A: Frontmatter key validity ───────────────────────────────────────────────────────
# Documented supported-field set, per agent-frontmatter-standard.md's Supported Fields table.
declare -A SUPPORTED_KEYS=(
  ["name"]=1 ["description"]=1 ["tools"]=1 ["disallowedTools"]=1 ["model"]=1
  ["permissionMode"]=1 ["maxTurns"]=1 ["skills"]=1 ["mcpServers"]=1 ["hooks"]=1
  ["memory"]=1 ["background"]=1 ["effort"]=1 ["isolation"]=1 ["color"]=1 ["initialPrompt"]=1
)

check_a_frontmatter_key_validity() {
  echo ""
  echo "--- Check A: Frontmatter key validity ---"

  local any_agent=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    any_agent=true
    local rel
    rel="$(rel_path "$f")"
    log_info "Checking $rel"

    local fm
    fm="$(frontmatter_body "$f")"

    if grep -qE '^allowed-tools:' <<<"$fm"; then
      log_fail "$rel: declares invalid key 'allowed-tools:' (use 'tools:' -- see agent-frontmatter-standard.md)"
    fi
    if grep -qE '^mcp-servers:' <<<"$fm"; then
      log_fail "$rel: declares invalid key 'mcp-servers:' (hyphenated misspelling -- use 'mcpServers:')"
    fi

    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      if [[ -z "${SUPPORTED_KEYS[$key]:-}" ]]; then
        log_warn "$rel: frontmatter key '$key' is outside the documented supported-field set"
      fi
    done < <(grep -oE '^[A-Za-z_-]+:' <<<"$fm" | sed 's/:$//' | sort -u)
  done < <(enumerate_dispatchable_agents)

  if [[ "$any_agent" == false ]]; then
    log_fail "Check A: no dispatchable agents found under $AGENTS_ROOT"
  else
    log_pass "Check A: scanned all dispatchable agents for invalid/unknown frontmatter keys"
  fi
}

# ── Check B: model presence and validity ────────────────────────────────────────────────────
check_b_model_presence() {
  echo ""
  echo "--- Check B: model presence and validity ---"

  local any_agent=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    any_agent=true
    local rel
    rel="$(rel_path "$f")"
    log_info "Checking $rel"

    local fm model_value
    fm="$(frontmatter_body "$f")"
    if ! grep -qE '^model:' <<<"$fm"; then
      log_fail "$rel: missing required 'model:' field"
      continue
    fi
    model_value="$(grep -E '^model:' <<<"$fm" | head -n1 | sed -E 's/^model:[[:space:]]*//')"
    case "$model_value" in
      opus|sonnet|haiku)
        : # valid
        ;;
      *)
        log_fail "$rel: 'model:' value '$model_value' is not one of opus|sonnet|haiku"
        ;;
    esac
  done < <(enumerate_dispatchable_agents)

  if [[ "$any_agent" == false ]]; then
    log_fail "Check B: no dispatchable agents found under $AGENTS_ROOT"
  else
    log_pass "Check B: scanned all dispatchable agents for model: presence and validity"
  fi
}

# ── Check C: no-task-references bullet presence ─────────────────────────────────────────────
# In-scope set per context/contracts/no-task-references-bullet.md's classification rule (an
# agent must carry the bullet iff it authors deliverable files outside specs/**). This set is
# NOT mechanically derivable from a file's own content -- "does this agent write outside
# specs/**" is a judgment call made by reading each agent's body -- so it is enumerated here as
# a curated, path-relative list, confirmed against the fragment's rule as of this task's Phase 5
# rollout. A future agent addition that should carry the bullet must be added to this list by a
# human/agent applying the same classification rule; this check does not infer scope on its own.
IN_SCOPE_RELATIVE_PATHS=(
  "core/agents/general-implementation-agent.md"
  "cslib/agents/cslib-implementation-agent.md"
  "cslib/agents/cslib-implementation-hard-agent.md"
  "cslib/agents/pr-review-implementation-agent.md"
  "email/agents/email-implementation-agent.md"
  "epidemiology/agents/epi-implement-agent.md"
  "founder/agents/founder-implement-agent.md"
  "latex/agents/latex-implementation-agent.md"
  "lean/agents/lean-implementation-agent.md"
  "lean/agents/lean-implementation-hard-agent.md"
  "nix/agents/nix-implementation-agent.md"
  "nvim/agents/neovim-implementation-agent.md"
  "python/agents/python-implementation-agent.md"
  "rust/agents/rust-implementation-agent.md"
  "typst/agents/typst-implementation-agent.md"
  "web/agents/web-implementation-agent.md"
  "z3/agents/z3-implementation-agent.md"
  "core/agents/planner-agent.md"
  "core/agents/reviser-agent.md"
  "core/agents/meta-builder-agent.md"
  "filetypes/agents/document-agent.md"
  "filetypes/agents/docx-edit-agent.md"
  "filetypes/agents/filetypes-spreadsheet-agent.md"
  "filetypes/agents/presentation-agent.md"
  "filetypes/agents/scrape-agent.md"
  "filetypes/agents/sheet-agent.md"
  "founder/agents/deck-builder-agent.md"
  "founder/agents/meeting-agent.md"
  "present/agents/pptx-assembly-agent.md"
  "present/agents/slidev-assembly-agent.md"
)

check_c_no_task_references_bullet() {
  echo ""
  echo "--- Check C: no-task-references bullet presence ---"

  if [[ ! -f "$FRAGMENT_FILE" ]]; then
    log_fail "Check C: canonical fragment not found at ${FRAGMENT_FILE#"$REPO_ROOT"/} -- cannot verify bullet text"
    return
  fi

  # Extract the bullet text from the fragment's fenced code block (the line containing
  # 'Reference task numbers').
  local expected
  expected="$(grep -F 'Reference task numbers' "$FRAGMENT_FILE" | head -n1)"
  if [[ -z "$expected" ]]; then
    log_fail "Check C: could not extract bullet text from fragment file"
    return
  fi

  for rel in "${IN_SCOPE_RELATIVE_PATHS[@]}"; do
    local f="$AGENTS_ROOT/$rel"
    if [[ ! -f "$f" ]]; then
      log_fail "$rel: in-scope agent file not found"
      continue
    fi
    log_info "Checking $rel"
    if grep -qF "$expected" "$f"; then
      log_pass "$rel: carries the no-task-references bullet"
    else
      log_fail "$rel: missing the no-task-references MUST-NOT bullet (expected text from $(rel_path "$FRAGMENT_FILE"))"
    fi
  done
}

# ── Check F: return-meta artifacts template presence ────────────────────────────────────────
# Recorded exclusions: dispatchable agents that do NOT write `.return-meta.json` at all, per
# context/contracts/return-meta-artifacts-template.md's classification rule ("An agent MUST
# carry this template if and only if it writes .return-meta.json"). Confirmed by reading each
# file's full terminal-metadata behavior, not inferred from absence alone:
#   - core/agents/code-reviewer-agent.md: console-only bullet-summary return, no file-based
#     metadata exchange anywhere in the file.
#   - literature/agents/literature-agent.md: zero occurrences of ".return-meta.json" anywhere.
EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS=(
  "agent-system/extensions/core/agents/code-reviewer-agent.md"
  "agent-system/extensions/literature/agents/literature-agent.md"
)

is_excluded_from_artifacts_template() {
  local rel="$1"
  local ex
  for ex in "${EXCLUDED_ARTIFACTS_TEMPLATE_RELATIVE_PATHS[@]}"; do
    [[ "$rel" == "$ex" ]] && return 0
  done
  return 1
}

# Scans $1 for an "artifacts" occurrence whose following ~6 lines contain ALL of the required
# keys (passed as remaining args) as quoted-key patterns ("key":). This is the same
# window-and-key-set logic used to re-verify Phase 3/4's scope live during authoring -- a bare
# `"artifacts": []` or `"artifacts": ["path.md"]` never satisfies this (no `"type":`/`"path":`/
# `"summary":` keys appear together in its window), only a genuine object-shaped element does.
has_artifacts_object_shape() {
  local f="$1"
  shift
  local -a keys=("$@")
  local lines
  lines="$(grep -n '"artifacts"' "$f" 2>/dev/null | cut -d: -f1)"
  [[ -z "$lines" ]] && return 1
  local line window all_present k
  for line in $lines; do
    window="$(sed -n "${line},$((line + 6))p" "$f")"
    all_present=true
    for k in "${keys[@]}"; do
      if ! grep -qE "\"${k}\"[[:space:]]*:" <<<"$window"; then
        all_present=false
        break
      fi
    done
    [[ "$all_present" == "true" ]] && return 0
  done
  return 1
}

check_f_artifacts_template() {
  echo ""
  echo "--- Check F: return-meta artifacts template presence ---"

  if [[ ! -f "$ARTIFACTS_TEMPLATE_FRAGMENT" ]]; then
    log_fail "Check F: canonical fragment not found at ${ARTIFACTS_TEMPLATE_FRAGMENT#"$REPO_ROOT"/} -- cannot verify template shape"
    return
  fi

  # Extract the required key set from the fragment's fenced JSON block at runtime -- never
  # hardcoded here, mirroring Check C's read-from-fragment mechanism.
  local fragment_json
  fragment_json="$(awk '/^```json$/{flag=1;next} /^```$/{if(flag) exit} flag' "$ARTIFACTS_TEMPLATE_FRAGMENT")"
  if [[ -z "$fragment_json" ]]; then
    log_fail "Check F: could not extract fenced JSON template from fragment file"
    return
  fi
  local -a required_keys
  mapfile -t required_keys < <(grep -oE '"[a-zA-Z_]+":' <<<"$fragment_json" | tr -d '":' | sort -u)
  if [[ "${#required_keys[@]}" -eq 0 ]]; then
    log_fail "Check F: could not extract any keys from the fragment's fenced JSON template"
    return
  fi
  log_info "Check F: required keys from fragment: ${required_keys[*]}"

  local any_agent=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    any_agent=true
    local rel
    rel="$(rel_path "$f")"
    if is_excluded_from_artifacts_template "$rel"; then
      log_info "Check F: $rel is a recorded exclusion (does not write .return-meta.json) -- skipped"
      continue
    fi
    log_info "Checking $rel"
    if has_artifacts_object_shape "$f" "${required_keys[@]}"; then
      log_pass "$rel: carries an object-shaped artifacts template (keys: ${required_keys[*]})"
    else
      log_fail "$rel: missing an object-shaped artifacts array with keys (${required_keys[*]}) -- expected shape from $(rel_path "$ARTIFACTS_TEMPLATE_FRAGMENT")"
    fi
  done < <(enumerate_dispatchable_agents)

  if [[ "$any_agent" == false ]]; then
    log_fail "Check F: no dispatchable agents found under $AGENTS_ROOT"
  else
    log_pass "Check F: scanned all dispatchable agents for the return-meta artifacts template"
  fi
}

# ── Deferred follow-up insertion point ──────────────────────────────────────────────────────
# Check D (required body sections -- ## Agent Metadata, ## Allowed Tools, ## Error Handling) and
# Check E (terminal-metadata section presence, keyed off return-metadata-file.md's normative
# status vocabulary) are deferred follow-up work -- see this task's plan, "Deferred Follow-Up
# Tasks" section. Both are expected to call enumerate_dispatchable_agents/is_dispatchable_agent
# above rather than re-deriving the frontmatter-gated detector.
#
# check_d_required_body_sections() { ... }
# check_e_terminal_metadata_presence() { ... }

# ── Main ─────────────────────────────────────────────────────────────────────────────────────
main() {
  echo "========================================"
  echo "Agent Contracts Lint"
  echo "========================================"
  echo "Repo root:   $REPO_ROOT"
  echo "Agents root: $AGENTS_ROOT"

  check_a_frontmatter_key_validity
  check_b_model_presence
  check_c_no_task_references_bullet
  check_f_artifacts_template

  echo ""
  echo "========================================"
  echo "Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}AGENT CONTRACTS LINT FAILED ($FAILED failures)${NC}"
    echo ""
    echo "Reference: $STANDARD_FILE"
    exit 1
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo -e "${YELLOW}AGENT CONTRACTS LINT PASSED WITH WARNINGS${NC}"
    exit 0
  else
    echo -e "${GREEN}AGENT CONTRACTS LINT PASSED${NC}"
    exit 0
  fi
}

main "$@"
