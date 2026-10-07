#!/usr/bin/env bash
# test-lint-agent-contracts.sh - Fixture-driven regression suite for lint-agent-contracts.sh.
#
# Builds an isolated scratch repo tree (mktemp -d) with a minimal agent-system/extensions/
# layout, populates it with positive and negative fixture agent files, and runs the real
# lint-agent-contracts.sh against it via REPO_ROOT=<scratch> (the same source-store invocation
# override the lint script itself documents), asserting on its EXIT CODE and, where relevant,
# on specific [FAIL]/[PASS] lines in its stdout. The lint script is never instrumented or
# modified for testability -- it never learns it is under test.
#
# Check E fixtures (added alongside Check E's implementation): 4 positive fixtures (no status,
# forbidden "completed" value, in_progress-only, pipe-alternatives placeholder), 1 negative
# false-positive guard (conformant status + MUST-NOT prose containing the word "completed", to
# prove Detector B matches only the quoted key/value pair), and 1 negative exclusion-list
# fixture. The shared ARTIFACTS_TEMPLATE_BLOCK used by every other positive/negative fixture is
# wrapped in a status-carrying object (a required fixture repair -- see compliant-agent.md's and
# check-f-conforming-agent.md's "no FAIL" assertions below, which would otherwise break the
# moment Check E lands) rather than the bare fragment it carried before this task.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT_SRC="$SCRIPT_DIR/../lint/lint-agent-contracts.sh"
FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/no-task-references-bullet.md"
ARTIFACTS_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/return-meta-artifacts-template.md"
STATUS_LIB_SRC="$SCRIPT_DIR/../lib/return-meta-status-vocabulary.sh"
PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/plan-status-ownership.md"
BOUNDED_WAIT_FRAGMENT_SRC="$SCRIPT_DIR/../../context/patterns/bounded-build-waiter.md"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$LINT_SRC" ]; then
  echo "ERROR: expected lint-agent-contracts.sh at $LINT_SRC" >&2
  exit 1
fi
if [ ! -f "$FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $FRAGMENT_SRC" >&2
  exit 1
fi
if [ ! -f "$ARTIFACTS_FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $ARTIFACTS_FRAGMENT_SRC" >&2
  exit 1
fi
if [ ! -f "$STATUS_LIB_SRC" ]; then
  echo "ERROR: expected shared library at $STATUS_LIB_SRC" >&2
  exit 1
fi
if [ ! -f "$PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" >&2
  exit 1
fi
if [ ! -f "$BOUNDED_WAIT_FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $BOUNDED_WAIT_FRAGMENT_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Mirror the real repo layout the lint script expects, relative to the scratch REPO_ROOT.
mkdir -p "$WORKDIR/agent-system/extensions/core/agents"
mkdir -p "$WORKDIR/agent-system/extensions/core/context/contracts"
mkdir -p "$WORKDIR/agent-system/extensions/core/docs/reference/standards"
mkdir -p "$WORKDIR/agent-system/extensions/core/scripts/lib"
mkdir -p "$WORKDIR/agent-system/extensions/core/context/patterns"
cp "$FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/contracts/no-task-references-bullet.md"
cp "$ARTIFACTS_FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/contracts/return-meta-artifacts-template.md"
cp "$STATUS_LIB_SRC" "$WORKDIR/agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh"
cp "$PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/contracts/plan-status-ownership.md"
cp "$BOUNDED_WAIT_FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/patterns/bounded-build-waiter.md"

BULLET_LINE='Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead'
OWNERSHIP_BULLET_LINE='Hand-edit the plan METADATA `- **Status**:` field -- it is owned by update-plan-status.sh (invoked from update-task-status.sh postflight), never by this agent; this agent'"'"'s plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and `- [ ]` checklist items'
# shellcheck disable=SC2016
BOUNDED_WAIT_MUST_LINE='Whenever a local verification/gate/build/test process is backgrounded at all, use bounded-build-waiter.md'"'"'s canonical idiom VERBATIM: a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside one Bash call that does not return control until the wait resolves -- and prefer the plain foreground form `timeout N cmd` whenever the command plausibly fits within the Bash tool'"'"'s own ceiling'
# shellcheck disable=SC2016
BOUNDED_WAIT_MUSTNOT_LINE='Use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent, and never end the turn on an unresolved local background wait -- the harness'"'"'s own asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it'

# A correctly-shaped artifacts template, used by every fixture that should PASS Check F (i.e.
# every fixture not specifically testing a Check F violation). Wrapped in a status-carrying
# object (Check E's fixture repair -- see the header comment's "Required fixture repair" note):
# every fixture built from this block also carries a conformant inline "status": "implemented",
# so it passes Check E's presence detector, not just Check F's shape detector. Any fixture
# testing a Check E violation specifically defines its own inline block instead of this shared
# one (see the Check E fixtures below).
ARTIFACTS_TEMPLATE_BLOCK='```json
{
  "status": "implemented",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
      "summary": "One-line description."
    }
  ]
}
```'

# run_lint: invokes the real lint script against the scratch tree, capturing stdout+exit code.
run_lint() {
  local out code
  out="$(REPO_ROOT="$WORKDIR" bash "$LINT_SRC" --verbose 2>&1)"
  code=$?
  printf '%s\x1e%s' "$code" "$out"
}

# =====================================================================
# Fixture: rogue-key agent (allowed-tools:) -- must fail Check A
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/rogue-key-agent.md" <<EOF
---
name: rogue-key-agent
description: fixture agent with an invalid allowed-tools: key
model: sonnet
allowed-tools: Read, Write
---

# Rogue Key Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: agent missing model: -- must fail Check B
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/no-model-agent.md" <<EOF
---
name: no-model-agent
description: fixture agent with no model field
---

# No Model Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: implementation agent without the bullet -- must fail Check C.
# Named to match the lint's IN_SCOPE_RELATIVE_PATHS allowlist entry
# core/agents/general-implementation-agent.md (the lint checks this exact path).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/general-implementation-agent.md" <<EOF
---
name: general-implementation-agent
description: fixture standing in for the real general-implementation-agent, missing the bullet
model: sonnet
---

# General Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Check G fixtures (added alongside Check G's implementation): a positive conforming fixture
# (carries the verbatim bullet -> no Check G FAIL, explicit PASS by name) and a near-miss
# paraphrase fixture (a plausible-looking but non-verbatim bullet -> still FAILs, proving the
# check compares against the fragment text, not a loose pattern). Both use real
# OWNERSHIP_IN_SCOPE_RELATIVE_PATHS entries other than general-implementation-agent.md (already
# exercised above as the "missing bullet" negative case for both Check C and Check G).
#
# The cslib-implementation-agent.md fixture also now carries BOUNDED_WAIT_MUST_LINE and
# BOUNDED_WAIT_MUSTNOT_LINE, serving double duty as Check H's conforming positive fixture (it is
# a real BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS entry). The lean-implementation-agent.md fixture
# below carries neither bounded-wait bullet; it is a real exclusion-list entry for Check H
# (lean/agents/lean-implementation-agent.md), so it must produce no Check H FAIL despite lacking
# the bullet pair entirely -- see the exclusion-list assertion below.
# =====================================================================
mkdir -p "$WORKDIR/agent-system/extensions/cslib/agents"
mkdir -p "$WORKDIR/agent-system/extensions/lean/agents"

cat > "$WORKDIR/agent-system/extensions/cslib/agents/cslib-implementation-agent.md" <<EOF
---
name: cslib-implementation-agent
description: fixture standing in for the real cslib-implementation-agent, carrying the verbatim bullet
model: sonnet
---

# CSLib Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST**:
1. $BOUNDED_WAIT_MUST_LINE

**MUST NOT**:
1. Do the wrong thing
2. $BULLET_LINE
3. $OWNERSHIP_BULLET_LINE
4. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

cat > "$WORKDIR/agent-system/extensions/lean/agents/lean-implementation-agent.md" <<EOF
---
name: lean-implementation-agent
description: fixture standing in for the real lean-implementation-agent, carrying a near-miss paraphrase instead of the verbatim bullet
model: sonnet
---

# Lean Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
2. Never hand-edit the plan's Status metadata field -- that belongs to update-plan-status.sh
EOF

# =====================================================================
# Check H fixtures (added alongside Check H's implementation): a missing-bullet negative fixture
# (otherwise compliant, carrying BULLET_LINE/OWNERSHIP_BULLET_LINE/ARTIFACTS_TEMPLATE_BLOCK, but
# neither bounded-wait bullet -> FAILs Check H by name) and a near-miss paraphrase fixture
# (otherwise compliant, carrying a plausible-looking paraphrase instead of the verbatim text ->
# still FAILs, proving the match is verbatim rather than loose). Both use real
# BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS entries.
# =====================================================================
mkdir -p "$WORKDIR/agent-system/extensions/nvim/agents"
mkdir -p "$WORKDIR/agent-system/extensions/z3/agents"

cat > "$WORKDIR/agent-system/extensions/nvim/agents/neovim-implementation-agent.md" <<EOF
---
name: neovim-implementation-agent
description: fixture standing in for the real neovim-implementation-agent, carrying neither bounded-wait bullet
model: sonnet
---

# Neovim Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
2. $BULLET_LINE
3. $OWNERSHIP_BULLET_LINE
EOF

cat > "$WORKDIR/agent-system/extensions/z3/agents/z3-implementation-agent.md" <<EOF
---
name: z3-implementation-agent
description: fixture standing in for the real z3-implementation-agent, carrying a near-miss paraphrase instead of the verbatim bounded-wait bullet pair
model: sonnet
---

# Z3 Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
2. $BULLET_LINE
3. $OWNERSHIP_BULLET_LINE
4. Never background a build and wait for a notification
EOF

# =====================================================================
# Negative fixture: frontmatter-less file in an agents/-named directory -- must NOT be treated
# as a dispatchable agent (no Check A/B finding referencing it).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/README.md" <<EOF
# Agents

Not a dispatchable agent -- no frontmatter block at all.
EOF

# =====================================================================
# Negative fixture: fully compliant agent -- must pass all three checks, no findings against it.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/compliant-agent.md" <<EOF
---
name: compliant-agent
description: fixture agent that fully complies with all four checks
model: sonnet
tools: Read, Write
---

# Compliant Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. $BULLET_LINE
EOF

# =====================================================================
# Fixture: template-less agent -- no "artifacts" occurrence at all -- must fail Check F.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-f-templateless-agent.md" <<EOF
---
name: check-f-templateless-agent
description: fixture agent with no artifacts template at all
model: sonnet
---

# Check F Templateless Agent

## Write Metadata

Write to \`specs/{NNN}_{SLUG}/.return-meta.json\`.

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: bare-string artifacts array -- has the "artifacts" key, but never as an object with
# type/path/summary -- must fail Check F (the exact malformed shape this whole task closes).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-f-barestring-agent.md" <<EOF
---
name: check-f-barestring-agent
description: fixture agent whose artifacts array is a bare-string array (the malformed shape)
model: sonnet
---

# Check F Barestring Agent

## Write Metadata

\`\`\`json
"artifacts": ["specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md"]
\`\`\`

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Fixture: conforming Check F agent -- carries the correct object-shaped template -- must pass.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-f-conforming-agent.md" <<EOF
---
name: check-f-conforming-agent
description: fixture agent carrying a correct object-shaped artifacts template
model: sonnet
---

# Check F Conforming Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Positive fixture: artifacts template present, but no status key at all -- must fail Check E's
# presence detector.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-e-nostatus-agent.md" <<EOF
---
name: check-e-nostatus-agent
description: fixture agent with an artifacts template but no status key anywhere
model: sonnet
---

# Check E No-Status Agent

## Write Metadata

\`\`\`json
"artifacts": [
  {
    "type": "summary",
    "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
    "summary": "One-line description."
  }
]
\`\`\`

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Positive fixture: carries a literal "status": "completed" pair -- must fail Check E by name
# (Detector B), regardless of whether a conformant status is present elsewhere.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-e-completed-agent.md" <<EOF
---
name: check-e-completed-agent
description: fixture agent carrying the forbidden "status": "completed" pair
model: sonnet
---

# Check E Completed Agent

## Write Metadata

\`\`\`json
{
  "status": "completed",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
      "summary": "One-line description."
    }
  ]
}
\`\`\`

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Positive fixture: carries only "status": "in_progress" -- must fail Check E's presence
# detector (in_progress is never a terminal outcome, so it does not satisfy Detector A).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-e-inprogress-only-agent.md" <<EOF
---
name: check-e-inprogress-only-agent
description: fixture agent carrying only an in_progress status, no terminal status
model: sonnet
---

# Check E In-Progress-Only Agent

## Write Metadata

\`\`\`json
{
  "status": "in_progress",
  "artifacts": []
}
\`\`\`

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Positive fixture: carries a pipe-alternatives status value -- must fail Check E's presence
# detector (an exact-match enum lookup never matches a pipe-joined string).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-e-pipeplaceholder-agent.md" <<EOF
---
name: check-e-pipeplaceholder-agent
description: fixture agent carrying a pipe-alternatives status placeholder
model: sonnet
---

# Check E Pipe Placeholder Agent

## Write Metadata

\`\`\`json
{
  "status": "implemented | partial | blocked",
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
      "summary": "One-line description."
    }
  ]
}
\`\`\`

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

# =====================================================================
# Negative fixture: carries a conformant status AND the MUST-NOT bullet, whose own prose
# contains the word "completed" -- must PASS Check E, proving Detector B matches only the
# quoted "status": "completed" key/value pair and never the bare word in surrounding prose.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/check-e-falsepositive-guard-agent.md" <<EOF
---
name: check-e-falsepositive-guard-agent
description: fixture agent carrying a conformant status plus MUST-NOT prose containing "completed"
model: sonnet
---

# Check E False-Positive Guard Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

## Critical Requirements

**MUST NOT**:
1. Use status value "completed" (triggers Claude stop behavior)
EOF

# =====================================================================
# Negative fixture: a file on Check E's exclusion list -- must produce a named [INFO] skipped
# line, never a FAIL, even though it carries no conformant status at all.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/meta-builder-agent.md" <<EOF
---
name: meta-builder-agent
description: fixture standing in for the real meta-builder-agent (Check E exclusion-list entry)
model: opus
---

# Meta Builder Agent (fixture)

## Write Metadata

\`\`\`json
{
  "status": "tasks_created",
  "artifacts": [
    {
      "type": "task_entry",
      "path": "{target_root}/specs/TODO.md",
      "summary": "Task #{N} added to TODO.md"
    }
  ]
}
\`\`\`

## Critical Requirements

**MUST NOT**:
1. $BULLET_LINE
EOF

result="$(run_lint)"
code="${result%%$'\x1e'*}"
out="${result#*$'\x1e'}"

info "lint exit code: $code"

# The scratch fixture set is deliberately non-compliant overall (rogue-key-agent and
# no-model-agent are real violations), so the lint MUST exit 1.
if [ "$code" -eq 1 ]; then
  pass "lint exits 1 against a fixture tree with real violations"
else
  fail "lint expected exit 1, got exit=$code"
fi

# Positive: rogue-key-agent.md fails Check A on the invalid key.
if echo "$out" | grep -qF "rogue-key-agent.md: declares invalid key 'allowed-tools:'"; then
  pass "positive: rogue-key-agent.md fails Check A (invalid allowed-tools: key)"
else
  fail "positive: expected Check A failure for rogue-key-agent.md, not found in output"
fi

# Positive: no-model-agent.md fails Check B on missing model.
if echo "$out" | grep -qF "no-model-agent.md: missing required 'model:' field"; then
  pass "positive: no-model-agent.md fails Check B (missing model:)"
else
  fail "positive: expected Check B failure for no-model-agent.md, not found in output"
fi

# Positive: general-implementation-agent.md (fixture, no bullet) fails Check C.
if echo "$out" | grep -qF "core/agents/general-implementation-agent.md: missing the no-task-references MUST-NOT bullet"; then
  pass "positive: general-implementation-agent.md fixture fails Check C (missing bullet)"
else
  fail "positive: expected Check C failure for general-implementation-agent.md, not found in output"
fi

# Negative: README.md (no frontmatter) produces no Check A/B finding against it.
if echo "$out" | grep -qF "README.md:"; then
  fail "negative: README.md (frontmatter-less) was incorrectly treated as a dispatchable agent"
else
  pass "negative: README.md (frontmatter-less) produces no finding (correctly excluded)"
fi

# Negative: compliant-agent.md produces no FAIL line against it.
if echo "$out" | grep -F "compliant-agent.md" | grep -q "FAIL"; then
  fail "negative: compliant-agent.md unexpectedly failed a check"
else
  pass "negative: compliant-agent.md produces no FAIL against it"
fi

# Positive: check-f-templateless-agent.md (no artifacts key at all) fails Check F.
if echo "$out" | grep -qF "check-f-templateless-agent.md: missing an object-shaped artifacts array"; then
  pass "positive: check-f-templateless-agent.md fails Check F (no artifacts template)"
else
  fail "positive: expected Check F failure for check-f-templateless-agent.md, not found in output"
fi

# Positive: check-f-barestring-agent.md (bare-string array, the malformed shape this task
# closes) fails Check F.
if echo "$out" | grep -qF "check-f-barestring-agent.md: missing an object-shaped artifacts array"; then
  pass "positive: check-f-barestring-agent.md fails Check F (bare-string artifacts array)"
else
  fail "positive: expected Check F failure for check-f-barestring-agent.md, not found in output"
fi

# Negative: check-f-conforming-agent.md (correct object-shaped template) passes Check F --
# produces no FAIL line against it.
if echo "$out" | grep -F "check-f-conforming-agent.md" | grep -q "FAIL"; then
  fail "negative: check-f-conforming-agent.md unexpectedly failed a check"
else
  pass "negative: check-f-conforming-agent.md produces no FAIL against it"
fi

# Positive: check-f-conforming-agent.md explicitly PASSES Check F (not just "no FAIL" -- a
# genuine pass line naming it).
if echo "$out" | grep -qF "check-f-conforming-agent.md: carries an object-shaped artifacts template"; then
  pass "positive: check-f-conforming-agent.md explicitly passes Check F"
else
  fail "positive: expected an explicit Check F PASS line for check-f-conforming-agent.md, not found in output"
fi

# =====================================================================
# Check E assertions
# =====================================================================

# Positive: check-e-nostatus-agent.md (artifacts template, no status key) fails Check E.
if echo "$out" | grep -qF "check-e-nostatus-agent.md: no conformant terminal status found"; then
  pass "positive: check-e-nostatus-agent.md fails Check E (no status key at all)"
else
  fail "positive: expected Check E failure for check-e-nostatus-agent.md, not found in output"
fi

# Positive: check-e-completed-agent.md (literal "status": "completed") fails Check E by name.
if echo "$out" | grep -qF "check-e-completed-agent.md: carries a literal \"status\": \"completed\""; then
  pass "positive: check-e-completed-agent.md fails Check E by name (forbidden completed value)"
else
  fail "positive: expected Check E failure naming the forbidden completed value, not found in output"
fi

# Positive: check-e-inprogress-only-agent.md (only in_progress) fails Check E's presence detector.
if echo "$out" | grep -qF "check-e-inprogress-only-agent.md: no conformant terminal status found"; then
  pass "positive: check-e-inprogress-only-agent.md fails Check E (in_progress is not a terminal status)"
else
  fail "positive: expected Check E failure for check-e-inprogress-only-agent.md, not found in output"
fi

# Positive: check-e-pipeplaceholder-agent.md (pipe-alternatives value) fails Check E's presence
# detector -- an exact-match lookup never matches a pipe-joined string.
if echo "$out" | grep -qF "check-e-pipeplaceholder-agent.md: no conformant terminal status found"; then
  pass "positive: check-e-pipeplaceholder-agent.md fails Check E (pipe-alternatives placeholder is not a literal member)"
else
  fail "positive: expected Check E failure for check-e-pipeplaceholder-agent.md, not found in output"
fi

# Negative: check-e-falsepositive-guard-agent.md (conformant status + MUST-NOT prose containing
# "completed") produces no FAIL line against it -- proves Detector B matches only the quoted
# "status": "completed" pair, never the bare word in prose.
if echo "$out" | grep -F "check-e-falsepositive-guard-agent.md" | grep -q "FAIL"; then
  fail "negative: check-e-falsepositive-guard-agent.md unexpectedly failed a check (Detector B false-positived on MUST-NOT prose)"
else
  pass "negative: check-e-falsepositive-guard-agent.md produces no FAIL against it (Detector B does not false-positive on prose)"
fi

# Explicit positive: check-e-falsepositive-guard-agent.md passes Check E by name (not just "no
# FAIL" -- a genuine pass line naming it).
if echo "$out" | grep -qF "check-e-falsepositive-guard-agent.md: carries a conformant terminal status"; then
  pass "positive: check-e-falsepositive-guard-agent.md explicitly passes Check E"
else
  fail "positive: expected an explicit Check E PASS line for check-e-falsepositive-guard-agent.md, not found in output"
fi

# Negative: meta-builder-agent.md fixture (Check E exclusion-list entry, no conformant status at
# all) produces a named [INFO] skipped line, never a FAIL.
if echo "$out" | grep -qF "Check E: agent-system/extensions/core/agents/meta-builder-agent.md is a recorded exclusion"; then
  pass "negative: meta-builder-agent.md fixture produces a named Check E exclusion INFO line"
else
  fail "negative: expected a named Check E exclusion INFO line for meta-builder-agent.md, not found in output"
fi
if echo "$out" | grep -F "meta-builder-agent.md" | grep -q "FAIL"; then
  fail "negative: meta-builder-agent.md fixture (Check E exclusion) unexpectedly failed a check"
else
  pass "negative: meta-builder-agent.md fixture (Check E exclusion) produces no FAIL against it"
fi

# =====================================================================
# Check G assertions
# =====================================================================

# (a) Positive: general-implementation-agent.md fixture (missing the bullet) fails Check G.
if echo "$out" | grep -qF "core/agents/general-implementation-agent.md: missing the plan-level-Status ownership MUST-NOT bullet"; then
  pass "(a) positive: general-implementation-agent.md fixture fails Check G (missing bullet)"
else
  fail "(a) positive: expected Check G failure for general-implementation-agent.md, not found in output"
fi

# (b) Negative: cslib-implementation-agent.md fixture (verbatim bullet) produces no FAIL, and
# explicitly passes Check G by name.
if echo "$out" | grep -F "cslib/agents/cslib-implementation-agent.md" | grep -q "FAIL"; then
  fail "(b) negative: cslib-implementation-agent.md fixture unexpectedly failed a check"
else
  pass "(b) negative: cslib-implementation-agent.md fixture produces no FAIL against it"
fi
if echo "$out" | grep -qF "cslib/agents/cslib-implementation-agent.md: carries the plan-level-Status ownership bullet"; then
  pass "(b) positive: cslib-implementation-agent.md fixture explicitly passes Check G"
else
  fail "(b) positive: expected an explicit Check G PASS line for cslib-implementation-agent.md, not found in output"
fi

# (c) Positive: lean-implementation-agent.md fixture (near-miss paraphrase, not the verbatim
# bullet) still FAILs -- proves Check G compares against the fragment text, not a loose pattern.
if echo "$out" | grep -qF "lean/agents/lean-implementation-agent.md: missing the plan-level-Status ownership MUST-NOT bullet"; then
  pass "(c) positive: lean-implementation-agent.md near-miss paraphrase fixture fails Check G"
else
  fail "(c) positive: expected Check G failure for lean-implementation-agent.md near-miss fixture, not found in output"
fi

# =====================================================================
# Check H assertions
# =====================================================================

# (a) Negative/positive: cslib-implementation-agent.md fixture (now carrying both bounded-wait
# bullets) produces no FAIL at all, and explicitly passes Check H by name.
if echo "$out" | grep -F "cslib/agents/cslib-implementation-agent.md" | grep -q "FAIL"; then
  fail "(a) negative: cslib-implementation-agent.md fixture unexpectedly failed a check (Check H conforming fixture)"
else
  pass "(a) negative: cslib-implementation-agent.md fixture produces no FAIL against it (Check H conforming fixture)"
fi
if echo "$out" | grep -qF "cslib/agents/cslib-implementation-agent.md: carries the bounded-wait contract bullet pair"; then
  pass "(a) positive: cslib-implementation-agent.md fixture explicitly passes Check H"
else
  fail "(a) positive: expected an explicit Check H PASS line for cslib-implementation-agent.md, not found in output"
fi

# (b) Positive: neovim-implementation-agent.md fixture (neither bounded-wait bullet) fails
# Check H by name.
if echo "$out" | grep -qF "nvim/agents/neovim-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  pass "(b) positive: neovim-implementation-agent.md fixture fails Check H (missing bullet pair)"
else
  fail "(b) positive: expected Check H failure for neovim-implementation-agent.md, not found in output"
fi

# (c) Positive: z3-implementation-agent.md fixture (near-miss paraphrase, not the verbatim
# bullet pair) still FAILs -- proves Check H compares against the fragment text, not a loose
# pattern.
if echo "$out" | grep -qF "z3/agents/z3-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  pass "(c) positive: z3-implementation-agent.md near-miss paraphrase fixture fails Check H"
else
  fail "(c) positive: expected Check H failure for z3-implementation-agent.md near-miss fixture, not found in output"
fi

# (d) Exclusion-list assertion: lean-implementation-agent.md fixture (a real Check H exclusion,
# carrying neither bounded-wait bullet) produces NO Check H FAIL -- proves the recorded
# exclusions are honored even though the file genuinely lacks the bullet pair.
if echo "$out" | grep -qF "lean/agents/lean-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  fail "(d) exclusion-list: lean-implementation-agent.md fixture unexpectedly failed Check H (should be excluded)"
else
  pass "(d) exclusion-list: lean-implementation-agent.md fixture produces no Check H FAIL (recorded exclusion honored)"
fi

# =====================================================================
# Fragment-missing fixture: Check C must fail loudly, by name, when the fragment file itself
# is absent -- never a silent skip.
# =====================================================================
FRAGDIR="$(mktemp -d)"
mkdir -p "$FRAGDIR/agent-system/extensions/core/agents"
mkdir -p "$FRAGDIR/agent-system/extensions/core/docs/reference/standards"
mkdir -p "$FRAGDIR/agent-system/extensions/core/scripts/lib"
cp "$STATUS_LIB_SRC" "$FRAGDIR/agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh"
cat > "$FRAGDIR/agent-system/extensions/core/agents/placeholder-agent.md" <<EOF
---
name: placeholder-agent
description: minimal fixture so the agents root is non-empty
model: sonnet
---

# Placeholder Agent
EOF
frag_out="$(REPO_ROOT="$FRAGDIR" bash "$LINT_SRC" --verbose 2>&1)"
frag_code=$?
rm -rf "$FRAGDIR"

if [ "$frag_code" -eq 1 ] && echo "$frag_out" | grep -qF "canonical fragment not found"; then
  pass "fragment-missing: Check C fails loudly by name when the fragment file is absent"
else
  fail "fragment-missing: expected exit 1 + named fragment-missing failure, got exit=$frag_code"
fi

# (d) Fragment-missing fixture: Check G must ALSO fail loudly by name (never a silent pass) when
# plan-status-ownership.md specifically is absent from the same bare scratch tree.
if echo "$frag_out" | grep -qF "Check G: canonical fragment not found"; then
  pass "(d) fragment-missing: Check G fails loudly by name when plan-status-ownership.md is absent"
else
  fail "(d) fragment-missing: expected a named Check G fragment-missing failure, not found in output"
fi

# (e) Fragment-missing fixture: Check H must ALSO fail loudly by name (never a silent pass) when
# bounded-build-waiter.md specifically is absent from the same bare scratch tree.
if echo "$frag_out" | grep -qF "Check H: canonical fragment not found"; then
  pass "(e) fragment-missing: Check H fails loudly by name when bounded-build-waiter.md is absent"
else
  fail "(e) fragment-missing: expected a named Check H fragment-missing failure, not found in output"
fi

# =====================================================================
# --help and unknown-argument fixtures
# =====================================================================
help_out="$(bash "$LINT_SRC" --help 2>&1)"
help_code=$?
if [ "$help_code" -eq 0 ] && echo "$help_out" | grep -qF "Usage: lint-agent-contracts.sh"; then
  pass "--help: exits 0 and prints usage"
else
  fail "--help: expected exit 0 + usage text, got exit=$help_code"
fi

bash "$LINT_SRC" --bogus-flag >/dev/null 2>&1
unknown_code=$?
if [ "$unknown_code" -eq 2 ]; then
  pass "unknown argument: exits 2"
else
  fail "unknown argument: expected exit 2, got exit=$unknown_code"
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
