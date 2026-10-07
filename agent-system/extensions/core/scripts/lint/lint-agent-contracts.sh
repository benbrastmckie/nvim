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
#   E. Terminal-metadata status presence: every non-excluded dispatchable agent must carry a
#      fenced `"status": "<value>"` line for a value drawn from
#      scripts/lib/return-meta-status-vocabulary.sh's 8-value canonical enum, other than
#      `in_progress` (never a terminal outcome). Independently, EVERY dispatchable agent --
#      excluded or not -- fails if it carries a literal `"status": "completed"` key/value pair
#      anywhere in its body (the value the vocabulary explicitly forbids). A recorded exclusion
#      list (agents using a legitimate extension-local, non-canonical terminal vocabulary) is
#      skipped by the presence detector only, never by the completed-value prohibition.
#   G. Plan-level-Status ownership bullet presence, for the curated in-scope agent set defined
#      by the classification rule in context/contracts/plan-status-ownership.md (an agent must
#      carry the bullet iff its contract instructs editing a `### Phase N: ... [MARKER]` heading
#      during plan execution). The expected bullet text is read from that fragment file at
#      runtime, never hardcoded here, mirroring Check C's own read-from-fragment mechanism.
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
      echo "  E. Terminal-metadata status presence (conformant inline status) + completed-value prohibition"
      echo "  F. Return-meta artifacts template presence (object-shaped, keys read from the fragment)"
      echo "  G. Plan-level-Status ownership bullet presence for the curated in-scope agent set"
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
PLAN_STATUS_OWNERSHIP_FRAGMENT="$REPO_ROOT/agent-system/extensions/core/context/contracts/plan-status-ownership.md"
BOUNDED_WAIT_FRAGMENT="$REPO_ROOT/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"

if [[ ! -d "$AGENTS_ROOT" ]]; then
  echo "ERROR: agents root not found at $AGENTS_ROOT" >&2
  exit 2
fi

# ── Shared status vocabulary library (deploy-tree-first / source-store-fallback) ────────────────
# Check E's accepted values are never hardcoded here, mirroring Check C/F's read-from-source
# discipline. Never scripts/lib/status-vocabulary.sh -- the unrelated 13-value TASK-LEVEL enum
# that legitimately contains "completed"; see return-meta-status-vocabulary.sh's own header.
STATUS_LIB_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/lib/return-meta-status-vocabulary.sh"
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh"
)
STATUS_LIB_FILE=""
for _candidate in "${STATUS_LIB_CANDIDATES[@]}"; do
  if [[ -f "$_candidate" ]]; then
    STATUS_LIB_FILE="$_candidate"
    break
  fi
done
if [[ -z "$STATUS_LIB_FILE" ]]; then
  echo "ERROR: shared library return-meta-status-vocabulary.sh not found at any of:" >&2
  for _candidate in "${STATUS_LIB_CANDIDATES[@]}"; do
    echo "  $_candidate" >&2
  done
  exit 2
fi
# shellcheck disable=SC1090
. "$STATUS_LIB_FILE"

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
  ["memory"]=1 ["background"]=1 ["effort"]=1 ["color"]=1 ["initialPrompt"]=1
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

# ── Check E: terminal-metadata status presence + completed-value prohibition ────────────────────
# Two independent detectors, both reusing enumerate_dispatchable_agents/is_dispatchable_agent
# above rather than re-deriving the frontmatter-gated detector:
#   Detector A (presence): FAILs a non-excluded dispatchable agent whose file carries no fenced
#     `"status": "<member>"` line for any RETURN_META_STATUS_VALUES member OTHER THAN
#     `in_progress` -- an in_progress-only file (the pre-fix `grant-agent`-style shape) does not
#     satisfy the terminal-status requirement, since in_progress is never a terminal outcome.
#   Detector B (prohibition): FAILs ANY dispatchable agent -- excluded or not -- that carries a
#     literal `"status": "completed"` key/value PAIR. Matches the quoted key/value pair only,
#     never the bare word `completed`, which appears legitimately inside the MUST-NOT bullet's
#     own prose (`Use status value "completed" (triggers Claude stop behavior)`) in ~30 agent
#     bodies -- that prose never matches this pattern because `"status"` is not immediately
#     followed by a colon and `"completed"` there. This mirrors Check F's window-and-key-set
#     precedent over a loose grep.
# The pipe-alternatives placeholder shape (`"implemented | partial | blocked"`) is rejected by
# construction: Detector A requires an EXACT match against a single enum member, so a
# pipe-joined string satisfies no single member and fails Detector A. This is the decided
# treatment (fail, then rewrite to a concrete value at the call site) -- not an accident of the
# regex.
#
# Recorded exclusions: dispatchable agents whose file carries NO canonical-vocabulary status
# anywhere (Detector A would otherwise FAIL them), confirmed by reading each file's full
# terminal-metadata behavior -- never inferred from `routing_agents` membership, which does NOT
# predict canonical-vocabulary use.
#
# SCOPE, RE-VERIFIED LIVE against the real source store while authoring this check (the plan's
# own "13 entries" scope hypothesis was WRONG -- do not trust it uncritically):
# `filetypes/agents/{filetypes-router,filetypes-spreadsheet,presentation,scrape,docx-edit,sheet,
# document}-agent.md` and `founder/agents/legal-analysis-agent.md` all use a non-canonical
# vocabulary for their SUCCESS branch (converted/edited/scraped/consulted/etc.), but every one of
# them ALSO carries a genuine `"status": "failed"` and/or `"status": "partial"` branch for their
# error path -- both of which ARE canonical members. Detector A does not distinguish a success
# branch from a failure branch; it only requires ANY non-`in_progress` canonical member present
# anywhere. These 8 files therefore already PASS Detector A on their own merit and are
# deliberately NOT listed below -- adding them would be excluding a file that is not actually
# unfixed, contradicting the "a file that is merely unfixed gets fixed, never excluded" rule.
# The same reasoning keeps `founder/agents/project-agent.md` and `present/agents/grant-agent.md`
# off this list: both carry a passing `"researched"` example alongside their agent-local values.
#
# Only 5 files genuinely carry NO canonical-vocabulary status anywhere in the file (confirmed by
# a full `"status":` occurrence grep against each, not by routing-registration inference):
EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS=(
  "agent-system/extensions/core/agents/meta-builder-agent.md"
  "agent-system/extensions/present/agents/pptx-assembly-agent.md"
  "agent-system/extensions/present/agents/slidev-assembly-agent.md"
  "agent-system/extensions/core/agents/code-reviewer-agent.md"
  "agent-system/extensions/literature/agents/literature-agent.md"
)

is_excluded_from_terminal_status() {
  local rel="$1"
  local ex
  for ex in "${EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS[@]}"; do
    [[ "$rel" == "$ex" ]] && return 0
  done
  return 1
}

check_e_terminal_metadata_presence() {
  echo ""
  echo "--- Check E: terminal-metadata status presence ---"

  local any_agent=false
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    any_agent=true
    local rel
    rel="$(rel_path "$f")"

    # Detector B runs unconditionally, before the exclusion check -- "completed" is forbidden
    # everywhere, regardless of an agent's vocabulary.
    if grep -qE '"status"[[:space:]]*:[[:space:]]*"completed"' "$f"; then
      log_fail "$rel: carries a literal \"status\": \"completed\" key/value pair -- forbidden (triggers Claude stop behavior); use \"implemented\" instead"
      continue
    fi

    if is_excluded_from_terminal_status "$rel"; then
      log_info "Check E: $rel is a recorded exclusion (legitimate extension-local terminal vocabulary) -- skipped"
      continue
    fi

    log_info "Checking $rel"
    local found=false member
    for member in "${RETURN_META_STATUS_VALUES[@]}"; do
      [[ "$member" == "in_progress" ]] && continue
      if grep -qE "\"status\"[[:space:]]*:[[:space:]]*\"${member}\"" "$f"; then
        found=true
        break
      fi
    done
    if [[ "$found" == "true" ]]; then
      log_pass "$rel: carries a conformant terminal status"
    else
      log_fail "$rel: no conformant terminal status found (expected one of: ${RETURN_META_STATUS_VALUES[*]}, excluding in_progress) -- either add one or add a reasoned exclusion entry to EXCLUDED_TERMINAL_STATUS_RELATIVE_PATHS"
    fi
  done < <(enumerate_dispatchable_agents)

  if [[ "$any_agent" == false ]]; then
    log_fail "Check E: no dispatchable agents found under $AGENTS_ROOT"
  else
    log_pass "Check E: scanned all dispatchable agents for terminal-metadata status presence"
  fi
}

# ── Check G: plan-level-Status ownership bullet presence ────────────────────────────────────
# In-scope set per context/contracts/plan-status-ownership.md's classification rule (an agent
# must carry the bullet iff its contract instructs editing a `### Phase N: ... [MARKER]` heading
# during plan execution). This set is derived by a predicate sweep over every
# agent-system/extensions/*/agents/*.md file (never a filename glob), NOT mechanically re-derived
# by this lint at runtime -- the sweep itself requires reading each candidate's body for the
# marker-editing instruction, which is not a single grep pattern. It is recorded here as a
# curated, path-relative list, exactly as Check C's IN_SCOPE_RELATIVE_PATHS is recorded. A future
# agent addition that should carry the bullet must be added to this list by a human/agent
# applying the same classification rule; this check does not infer scope on its own.
#
# The set is 14 files, not the plan's own planning-time hypothesis of 13:
# founder/agents/founder-implement-agent.md was re-swept at implementation time and found to
# genuinely instruct editing `### Phase N: {Phase Name} [MARKER]` headings via the Edit tool,
# identically to the other 13 confirmed agents -- see plan-status-ownership.md's own "Sweep
# result diverges..." note for the full evidence.
OWNERSHIP_IN_SCOPE_RELATIVE_PATHS=(
  "core/agents/general-implementation-agent.md"
  "cslib/agents/cslib-implementation-agent.md"
  "cslib/agents/cslib-implementation-hard-agent.md"
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
)

check_g_plan_status_ownership_bullet() {
  echo ""
  echo "--- Check G: plan-level-Status ownership bullet presence ---"

  if [[ ! -f "$PLAN_STATUS_OWNERSHIP_FRAGMENT" ]]; then
    log_fail "Check G: canonical fragment not found at ${PLAN_STATUS_OWNERSHIP_FRAGMENT#"$REPO_ROOT"/} -- cannot verify bullet text"
    return
  fi

  # Extract the bullet text from the fragment's fenced code block (the line containing
  # 'Hand-edit the plan METADATA').
  local expected
  expected="$(grep -F 'Hand-edit the plan METADATA' "$PLAN_STATUS_OWNERSHIP_FRAGMENT" | head -n1)"
  if [[ -z "$expected" ]]; then
    log_fail "Check G: could not extract bullet text from fragment file"
    return
  fi

  for rel in "${OWNERSHIP_IN_SCOPE_RELATIVE_PATHS[@]}"; do
    local f="$AGENTS_ROOT/$rel"
    if [[ ! -f "$f" ]]; then
      log_fail "$rel: in-scope agent file not found"
      continue
    fi
    log_info "Checking $rel"
    if grep -qF "$expected" "$f"; then
      log_pass "$rel: carries the plan-level-Status ownership bullet"
    else
      log_fail "$rel: missing the plan-level-Status ownership MUST-NOT bullet (expected text from $(rel_path "$PLAN_STATUS_OWNERSHIP_FRAGMENT"))"
    fi
  done
}

# ── Check H: bounded-wait contract bullet presence ──────────────────────────────────────────
# (a) Curated, not a filename glob: three of the 17 files matching `*implementation*agent.md`
# are legitimate, already-correct exclusions that a literal-text check cannot recognize
# uniformly (one is the contract's own authoritative prose home; two carry a differently-shaped
# but equally sanctioned mechanism), so the in-scope set below is a hand-maintained list, exactly
# as Check C's IN_SCOPE_RELATIVE_PATHS and Check G's OWNERSHIP_IN_SCOPE_RELATIVE_PATHS are.
# (b) The three recorded exclusions and their per-file reasons:
#   - core/agents/general-implementation-agent.md -- the contract's authoritative home: the full
#     prose block the bullet pair below is condensed from. Deliberately not edited to carry the
#     condensed copy of its own source text.
#   - lean/agents/lean-implementation-agent.md and lean/agents/lean-implementation-hard-agent.md
#     -- carry a domain-adapted, sanctioned background-build path routed through the Lean build
#     guard (lake-build-guard.sh), a different legitimate mechanism satisfying the same
#     underlying rule rather than an unfixed gap.
# (c) Re-audit reproduce command (verbatim, so a future auditor can re-derive the set):
#   cd agent-system/extensions && for f in $(find . -name '*implementation*agent.md' | sort); do
#     echo "$(grep -c run_in_background "$f") $(grep -c bounded-build-waiter "$f") $f"; done
# (d) A future agent addition must be added here by applying
#   bounded-build-waiter.md's "Classification Rule" subsection -- this check does not infer scope
#   on its own.
BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS=(
  "books/agents/books-implementation-agent.md"
  "books/agents/books-implementation-hard-agent.md"
  "cslib/agents/cslib-implementation-agent.md"
  "cslib/agents/cslib-implementation-hard-agent.md"
  "cslib/agents/pr-review-implementation-agent.md"
  "email/agents/email-implementation-agent.md"
  "latex/agents/latex-implementation-agent.md"
  "nix/agents/nix-implementation-agent.md"
  "nvim/agents/neovim-implementation-agent.md"
  "python/agents/python-implementation-agent.md"
  "rust/agents/rust-implementation-agent.md"
  "typst/agents/typst-implementation-agent.md"
  "web/agents/web-implementation-agent.md"
  "z3/agents/z3-implementation-agent.md"
)

check_h_bounded_wait_contract_bullet() {
  echo ""
  echo "--- Check H: bounded-wait contract bullet presence ---"

  if [[ ! -f "$BOUNDED_WAIT_FRAGMENT" ]]; then
    log_fail "Check H: canonical fragment not found at ${BOUNDED_WAIT_FRAGMENT#"$REPO_ROOT"/} -- cannot verify bullet text"
    return
  fi

  # Extract both anchors from the fragment's fenced "Copy this exact text" block.
  local expected_must expected_mustnot
  expected_must="$(grep -F 'canonical idiom VERBATIM' "$BOUNDED_WAIT_FRAGMENT" | head -n1)"
  # shellcheck disable=SC2016
  expected_mustnot="$(grep -F 'arm a `Monitor` to watch a local verification' "$BOUNDED_WAIT_FRAGMENT" | head -n1)"
  if [[ -z "$expected_must" || -z "$expected_mustnot" ]]; then
    log_fail "Check H: could not extract bullet text from fragment file"
    return
  fi

  for rel in "${BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS[@]}"; do
    local f="$AGENTS_ROOT/$rel"
    if [[ ! -f "$f" ]]; then
      log_fail "$rel: in-scope agent file not found"
      continue
    fi
    log_info "Checking $rel"
    if grep -qF "$expected_must" "$f" && grep -qF "$expected_mustnot" "$f"; then
      log_pass "$rel: carries the bounded-wait contract bullet pair"
    else
      log_fail "$rel: missing the bounded-wait MUST/MUST-NOT bullet pair (expected text from $(rel_path "$BOUNDED_WAIT_FRAGMENT"))"
    fi
  done
}

# ── Deferred follow-up insertion point ──────────────────────────────────────────────────────
# Check D (required body sections -- ## Agent Metadata, ## Allowed Tools, ## Error Handling) is
# STILL DEFERRED follow-up work -- see the inline-terminal-status-contracts plan's "Deferred
# Follow-Up Tasks" section. Check D is expected to call
# enumerate_dispatchable_agents/is_dispatchable_agent above rather than re-deriving the
# frontmatter-gated detector.
#
# check_d_required_body_sections() { ... }
#
# Check E (terminal-metadata status presence + completed-value prohibition) IS IMPLEMENTED,
# above -- it is no longer part of this deferral. It is a STATIC lint over agent-body examples
# only: it prevents the WORKED EXAMPLE an agent reads from drifting, but cannot by itself stop
# an agent that writes "completed" anyway despite a correct example in front of it. Two related,
# deliberately deferred follow-up questions this check's existence does NOT answer (recorded in
# the same plan's "Deferred Follow-Up Tasks" section, items 1-2 -- read that section for the
# full rationale before acting on either):
#   1. WIRE A RUNTIME VALIDATOR INTO THE DISPATCH READ PATH. validate-return-meta.sh already
#      rejects "completed" with the right message and has ZERO runtime callers -- it would have
#      caught the incident this task's plan was written to fix, and did not run. The two live,
#      currently-unguarded chokepoints are orchestrate-recover-outcome.sh's read and
#      skill-base.sh's skill_read_metadata() (the base-mode path). Blocked on item 2 below: wiring
#      the 8-value rejection in today would newly break several registered agents' intentional
#      non-canonical vocabularies (e.g. legal-analysis-agent's "consulted",
#      slidev-assembly-agent's "assembled", every filetypes/* vocabulary).
#   2. WIDEN orchestrate-recover-outcome.sh's SUCCESS-OUTCOME ACCEPTANCE SET. Its 3-value arm
#      (researched|planned|implemented) is narrower than the set of intentionally-designed
#      success vocabularies bona fide registered phase-routing targets use. Any such agent
#      dispatched under orchestrator_mode: true has a genuinely successful outcome misclassified
#      as STATUS_NOT_SUCCESS today -- the same defect class this task's plan fixes, triggered by
#      an intentional value instead of an accidental one. See that script's own success-arm
#      comment (Phase 3 of the same plan) for the seam this would extend.

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
  check_e_terminal_metadata_presence
  check_g_plan_status_ownership_bullet
  check_h_bounded_wait_contract_bullet

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
