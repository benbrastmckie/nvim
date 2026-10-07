#!/usr/bin/env bash
# test-askuserquestion-rehome.sh - Structural regression fixture for the AskUserQuestion
# rehoming fix: AskUserQuestion is measured categorically withheld from every Agent-tool
# dispatch of a named subagent_type (plain or subagent_type: "fork"), independent of
# tools:/disallowedTools: configuration -- see
# docs/reference/standards/agent-frontmatter-standard.md's "Tool Withholding from Dispatched
# Subagents" section for the full measured probe matrix.
#
# IMPORTANT -- WHAT THIS FIXTURE DOES AND DOES NOT PROVE: this is a shell script. It cannot
# itself invoke ToolSearch or the Agent tool, so it CANNOT re-verify the underlying harness
# fact (that AskUserQuestion is withheld from a dispatched subagent). That fact can only be
# re-confirmed by a LIVE dispatch probe (ToolSearch with select:AskUserQuestion inside a freshly
# dispatched subagent) -- see agent-frontmatter-standard.md's corrected section for the exact
# probe and its five recorded configurations. This fixture only protects the FIX: it asserts
# the structural postconditions of the rehoming (no agent file instructs itself to call the
# withheld tool, the interview lives where the tool works, the documentation claims agree with
# the measurement). A green run here is NOT a harness re-verification; do not read it as one.
#
# Structural model: test-check-task-references.sh / test-lint-agent-contracts.sh (SCRIPT_DIR
# resolution, pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass /
# exit 1 on any-fail) crossed with test-status-vocabulary.sh (git-worktree-root-first REPO_ROOT
# resolution so this suite works from both the source-store copy and a deployed copy).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

# ---------------------------------------------------------------------------
# Resolve the agent-file scan root: source-store layout preferred (matches this task's own
# file_scope exactly: agent-system/extensions/*/agents/**), deployed flat .claude/agents/ as
# fallback for a tree where only the deploy output is present.
# ---------------------------------------------------------------------------
SOURCE_STORE_AGENTS_GLOB="$REPO_ROOT/agent-system/extensions/*/agents/*.md"
DEPLOYED_AGENTS_GLOB="$REPO_ROOT/.claude/agents/*.md"

shopt -s nullglob
AGENT_FILES=($SOURCE_STORE_AGENTS_GLOB)
SCAN_MODE="source-store"
if [[ ${#AGENT_FILES[@]} -eq 0 ]]; then
  AGENT_FILES=($DEPLOYED_AGENTS_GLOB)
  SCAN_MODE="deployed (flat)"
fi
shopt -u nullglob

if [[ ${#AGENT_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no agent files found at either:" >&2
  echo "  $SOURCE_STORE_AGENTS_GLOB" >&2
  echo "  $DEPLOYED_AGENTS_GLOB" >&2
  exit 2
fi
info "Scanning ${#AGENT_FILES[@]} agent files ($SCAN_MODE)"

STANDARD_PATH="$REPO_ROOT/agent-system/extensions/core/docs/reference/standards/agent-frontmatter-standard.md"
TEMPLATE_PATH="$REPO_ROOT/agent-system/extensions/core/docs/templates/agent-template.md"
LINT_PATH="$REPO_ROOT/agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh"
SKILL_META_PATH="$REPO_ROOT/agent-system/extensions/core/skills/skill-meta/SKILL.md"
INTERVIEW_PATH="$REPO_ROOT/agent-system/extensions/core/context/workflows/meta-interview.md"
SKILL_SPAWN_PATH="$REPO_ROOT/agent-system/extensions/core/skills/skill-spawn/SKILL.md"
SKILL_FIXIT_PATH="$REPO_ROOT/agent-system/extensions/core/skills/skill-fix-it/SKILL.md"

for req in "$STANDARD_PATH" "$TEMPLATE_PATH" "$LINT_PATH" "$SKILL_META_PATH" "$SKILL_SPAWN_PATH" "$SKILL_FIXIT_PATH"; do
  if [[ ! -f "$req" ]]; then
    echo "ERROR: required file not found: $req" >&2
    exit 2
  fi
done

# ===========================================================================
# Case 1: no agent file instructs ITSELF to call AskUserQuestion.
#
# Detection function: check_file_for_self_instruction <path>
#   Prints offending "file:line:text" entries to stdout (one per line); prints nothing and
#   returns 0 if the file is clean. Two independent checks:
#     (a) a tools/capability-list entry of the shape "- AskUserQuestion - <description>"
#         (declaring the tool as something this agent uses) -- always flagged, no admission
#         text can rescue this shape, because the whole point is this is a tools listing.
#     (b) an imperative line containing "Use AskUserQuestion" (case-insensitive) or
#         "via AskUserQuestion" or "ask ONE ... AskUserQuestion" that does NOT also carry an
#         admission marker proving it states unavailability/relocation rather than
#         instructing a call. A bare "AskUserQuestion:" format-label line (nothing else on
#         the line) is never flagged -- it is pseudocode-block structure, not a directive.
# ===========================================================================
ADMISSION_MARKERS='cannot call|do not use|not AskUserQuestion|runs as a dispatched subagent|invoking skill|skill-consult|skill-timeline|skill handles|skill'\''s responsibility|Architecture Note|measured categorically withheld|not a spawnable agent'

check_file_for_self_instruction() {
  local f="$1"
  # (a) tools-list entry shape, e.g. "- AskUserQuestion - For forcing questions"
  grep -nE '^[[:space:]]*-[[:space:]]*AskUserQuestion[[:space:]]*-' "$f" 2>/dev/null \
    | while IFS=: read -r lineno text; do
        echo "$f:$lineno:$text"
      done

  # (b) imperative/directive phrasing without an admission marker nearby
  grep -niE 'use AskUserQuestion|via AskUserQuestion|ask ONE.*AskUserQuestion' "$f" 2>/dev/null \
    | while IFS=: read -r lineno text; do
        # Skip bare format-label lines (nothing but "AskUserQuestion:" once whitespace trimmed)
        trimmed="$(echo "$text" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
        if [[ "$trimmed" == "AskUserQuestion:" ]]; then
          continue
        fi
        if ! echo "$text" | grep -qiE "$ADMISSION_MARKERS"; then
          echo "$f:$lineno:$text"
        fi
      done
}

SELF_INSTRUCTION_FOUND=0
OFFENDER_LIST=""
for f in "${AGENT_FILES[@]}"; do
  # File-level exemption: a file whose own body states it is NOT a spawnable agent
  # definition (pure architectural description, e.g. literature-agent.md) is describing
  # another component's UX, not instructing itself -- the per-line admission-marker grammar
  # cannot distinguish "the skill does X via AskUserQuestion" prose from a self-instruction
  # without false-flagging this legitimate descriptive case, so the file-level disclaimer
  # itself is the admission.
  if grep -qiE 'NOT a spawnable agent definition' "$f" 2>/dev/null; then
    continue
  fi
  result="$(check_file_for_self_instruction "$f")"
  if [[ -n "$result" ]]; then
    SELF_INSTRUCTION_FOUND=1
    OFFENDER_LIST="${OFFENDER_LIST}${result}"$'\n'
  fi
done

if [[ "$SELF_INSTRUCTION_FOUND" -eq 0 ]]; then
  pass "no agent file instructs itself to call AskUserQuestion"
else
  fail "agent file(s) instruct themselves to call AskUserQuestion:"
  echo "$OFFENDER_LIST" | sed 's/^/       /' >&2
fi

# Case 1b: the fixture must pass UNCHANGED against cslib-vet-agent.md, the admitted-form
# precedent the plan names explicitly.
CSLIB_VET="$REPO_ROOT/agent-system/extensions/cslib/agents/cslib-vet-agent.md"
if [[ -f "$CSLIB_VET" ]]; then
  cslib_result="$(check_file_for_self_instruction "$CSLIB_VET")"
  if [[ -z "$cslib_result" ]]; then
    pass "fixture passes against cslib-vet-agent.md unchanged (admitted-form precedent)"
  else
    fail "fixture incorrectly flags cslib-vet-agent.md's admitted MUST NOT phrasing:"
    echo "$cslib_result" | sed 's/^/       /' >&2
  fi
else
  info "cslib-vet-agent.md not present in this deployment -- skipping precedent check (not an error; cslib extension may not be loaded)"
fi

# ===========================================================================
# Case 1c: deliberate-regression spot check -- reintroduce one instructing line in a SCRATCH
# COPY (never the real file) and confirm the detector FAILS, proving Case 1 is not vacuous.
# ===========================================================================
SCRATCH="$(mktemp)"
trap 'rm -f "$SCRATCH"' EXIT
cat > "$SCRATCH" <<'EOF'
---
name: scratch-regression-fixture
description: throwaway fixture, never committed
model: sonnet
---

## Allowed Tools

### Interactive Tools
- AskUserQuestion - Multi-turn interview for interactive mode

Use AskUserQuestion with `options` array for EVERY user choice point.
EOF
scratch_result="$(check_file_for_self_instruction "$SCRATCH")"
if [[ -n "$scratch_result" ]]; then
  pass "deliberate-regression spot check: detector correctly FAILS a reintroduced instructing line"
else
  fail "deliberate-regression spot check: detector did not flag a known-bad reintroduced line -- Case 1 may be vacuous"
fi
rm -f "$SCRATCH"
trap - EXIT

# ===========================================================================
# Case 2: skill-meta/SKILL.md's allowed-tools: line includes AskUserQuestion.
# ===========================================================================
if head -10 "$SKILL_META_PATH" | grep -qE '^allowed-tools:.*AskUserQuestion'; then
  pass "skill-meta/SKILL.md's allowed-tools includes AskUserQuestion"
else
  fail "skill-meta/SKILL.md's allowed-tools does not include AskUserQuestion"
fi

# ===========================================================================
# Case 3: core/context/workflows/meta-interview.md exists and is referenced from
# skill-meta/SKILL.md.
# ===========================================================================
if [[ -f "$INTERVIEW_PATH" ]]; then
  pass "core/context/workflows/meta-interview.md exists"
else
  fail "core/context/workflows/meta-interview.md not found at $INTERVIEW_PATH"
fi

if grep -q 'meta-interview.md' "$SKILL_META_PATH" 2>/dev/null; then
  pass "skill-meta/SKILL.md references meta-interview.md"
else
  fail "skill-meta/SKILL.md does not reference meta-interview.md"
fi

# ===========================================================================
# Case 4: no "inherit the full tool set" / "inherits the full" claim remains in
# agent-frontmatter-standard.md or agent-template.md without the measured exception within a
# bounded window (10 lines) of the same line.
# ===========================================================================
check_inheritance_claim_qualified() {
  local f="$1"
  local total_lines offending=0
  total_lines=$(wc -l < "$f")
  while IFS=: read -r lineno _rest; do
    local window_start window_end window_text
    window_start=$((lineno > 10 ? lineno - 10 : 1))
    window_end=$((lineno + 10 > total_lines ? total_lines : lineno + 10))
    window_text="$(sed -n "${window_start},${window_end}p" "$f")"
    if ! echo "$window_text" | grep -qiE 'measured|withheld|AskUserQuestion'; then
      echo "$f:$lineno: unqualified inheritance claim (no measured/withheld/AskUserQuestion mention within 10 lines)"
      offending=1
    fi
  done < <(grep -niE 'inherit the full tool set|inherits the full' "$f" 2>/dev/null | cut -d: -f1 | while read -r ln; do echo "$ln:x"; done)
  return $offending
}

INHERITANCE_OK=1
for f in "$STANDARD_PATH" "$TEMPLATE_PATH"; do
  out="$(check_inheritance_claim_qualified "$f")" || INHERITANCE_OK=0
  if [[ -n "$out" ]]; then
    echo "$out" | sed 's/^/       /' >&2
  fi
done
if [[ "$INHERITANCE_OK" -eq 1 ]]; then
  pass "every remaining inheritance-claim occurrence is qualified with the measured exception"
else
  fail "an inheritance-claim occurrence lacks the measured exception nearby"
fi

# ===========================================================================
# Case 5: the isolation DROP branch holds -- no isolation row in the Supported Fields table,
# no ["isolation"]=1 in lint-agent-contracts.sh's SUPPORTED_KEYS, and the justifying probe
# record is present in the standard.
# ===========================================================================
if awk '/^## Supported Fields/,/^## Optional Fields/' "$STANDARD_PATH" | grep -qE '^\| `isolation`'; then
  fail "agent-frontmatter-standard.md's Supported Fields table still carries an isolation row"
else
  pass "agent-frontmatter-standard.md's Supported Fields table carries no isolation row"
fi

if grep -q '"isolation"' "$LINT_PATH"; then
  fail "lint-agent-contracts.sh's SUPPORTED_KEYS still carries [\"isolation\"]=1"
else
  pass "lint-agent-contracts.sh's SUPPORTED_KEYS no longer carries isolation"
fi

if grep -q 'isolation.*removed' "$STANDARD_PATH"; then
  pass "agent-frontmatter-standard.md records the isolation removal with its justifying probes"
else
  fail "agent-frontmatter-standard.md does not record the isolation removal"
fi

if grep -q '`isolation`' "$TEMPLATE_PATH"; then
  fail "agent-template.md's field-name pointer list still names isolation"
else
  pass "agent-template.md's field-name pointer list no longer names isolation"
fi

# ===========================================================================
# Case 6: skill-spawn/SKILL.md and skill-fix-it/SKILL.md still declare no agent: frontmatter
# field (structural guard on the two confirmed-unaffected direct-execution skills).
# ===========================================================================
for f in "$SKILL_SPAWN_PATH" "$SKILL_FIXIT_PATH"; do
  name="$(basename "$(dirname "$f")")"
  if head -10 "$f" | grep -qE '^agent:'; then
    fail "$name/SKILL.md unexpectedly declares agent: -- it is supposed to stay direct-execution"
  else
    pass "$name/SKILL.md declares no agent: field (stays direct-execution)"
  fi
done

# ===========================================================================
# Case 7: the worktree-isolation removal layer stays absent.
# ===========================================================================
REMOVAL_LAYER_HITS="$(grep -rl --exclude='test-askuserquestion-rehome.sh' \
  'dispatch-worktree.sh\|task_selected_for_worktree_isolation' "$REPO_ROOT/agent-system" 2>/dev/null)"
if [[ -n "$REMOVAL_LAYER_HITS" ]]; then
  fail "removal layer (dispatch-worktree.sh / task_selected_for_worktree_isolation) is present again:"
  echo "$REMOVAL_LAYER_HITS" | sed 's/^/       /' >&2
else
  pass "removal layer (dispatch-worktree.sh / task_selected_for_worktree_isolation) stays absent"
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
