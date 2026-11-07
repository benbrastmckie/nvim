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
# Check L fixtures (added alongside Check L's implementation): 1 missing-copy positive FAIL
# (z3-implementation-agent.md, a real Check L in-scope path carrying neither canonical line nor
# a "modified_files" key), 1 near-miss paraphrase positive FAIL (lean-implementation-agent.md,
# proving the match is verbatim rather than loose), 1 no-FAIL/explicit-PASS negative pair
# (cslib-implementation-agent.md), and 1 fragment-missing assertion against the bare FRAGDIR
# scratch tree. Required fixture repair (done in the same rollout, mirroring Check E's own
# repair note above): cslib-implementation-agent.md is a real Check L in-scope path and was
# already asserted twice (by Check G's and Check H's own "no FAIL at all" cases) to produce no
# FAIL whatsoever, so it was repaired with MODIFIED_FILES_BULLET_LINE, MODIFIED_FILES_TRACK_LINE,
# and a "modified_files": [] key -- otherwise Check L would newly break both of those
# pre-existing assertions the moment it landed.
#
# Check J fixture repair, required when Check J's content gate was replaced with a fail-closed
# iteration over every dispatchable agent (same repair pattern as the two notes above -- a new
# or newly-widened check landing retroactively breaks a shared "no FAIL at all" fixture that was
# clean against every check in place before it landed, unless repaired in the same rollout):
#   - A new shared HANDOFF_SECTION_BLOCK (a minimal recognized `.orchestrator-handoff.json`
#     handoff-writing section) was added to compliant-agent.md, check-f-conforming-agent.md,
#     check-e-falsepositive-guard-agent.md, and cslib-implementation-agent.md -- all four are
#     asserted elsewhere in this file to produce no FAIL whatsoever, and each would otherwise
#     newly FAIL Check J's missing-section branch, since Check J's fail-closed design evaluates
#     every dispatchable agent directly instead of pre-filtering by content.
#   - This suite's WORKDIR already creates core/agents/ (for Checks A/B/C/E/F/G/H/K/L fixtures)
#     and cslib/agents/ (for the cslib-implementation-agent.md fixture above), which brings
#     Check J's stale-exclusion sweep (added in a later plan phase) into scope for every
#     CHECK_J_EXCLUDED_RELATIVE_PATHS entry under those two extensions, per that sweep's
#     per-extension-agents-directory-presence guard (see lint-agent-contracts.sh's
#     _check_j_sweep_stale_exclusions() header comment). Three real entries
#     (core/agents/code-reviewer-agent.md, core/agents/spawn-agent.md,
#     cslib/agents/cslib-vet-agent.md) have no corresponding file in this WORKDIR at all, so
#     without repair the sweep would report them stale (nonexistent path) in this tree -- never
#     asserted on by name below, but still unvetted noise in the raw lint output this suite
#     captures. Three minimal stub fixtures were added at those exact real paths (mirroring the
#     real files' own recorded exclusion reason: invoked only via the forked-subagent pattern)
#     to keep the sweep clean here too. spawn-agent.md and cslib-vet-agent.md additionally carry
#     ARTIFACTS_TEMPLATE_BLOCK, since -- unlike code-reviewer-agent.md, which is independently a
#     recorded exclusion on BOTH Check E's and Check F's own arrays -- neither is excluded from
#     Check E or Check F, so a contentless stub would newly fail those two checks instead.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md:
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d workdir with a trap
# EXIT cleanup, exit 0 on all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
LINT_SRC="$SCRIPT_DIR/../lint/lint-agent-contracts.sh"
FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/no-task-references-bullet.md"
ARTIFACTS_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/return-meta-artifacts-template.md"
STATUS_LIB_SRC="$SCRIPT_DIR/../lib/return-meta-status-vocabulary.sh"
PLAN_STATUS_OWNERSHIP_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/plan-status-ownership.md"
BOUNDED_WAIT_FRAGMENT_SRC="$SCRIPT_DIR/../../context/patterns/bounded-build-waiter.md"
MODIFIED_FILES_FRAGMENT_SRC="$SCRIPT_DIR/../../context/contracts/modified-files-bullet.md"

PASSED=0
FAILED=0


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
if [ ! -f "$MODIFIED_FILES_FRAGMENT_SRC" ]; then
  echo "ERROR: expected canonical fragment at $MODIFIED_FILES_FRAGMENT_SRC" >&2
  exit 1
fi

common_test_workdir_init

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
cp "$MODIFIED_FILES_FRAGMENT_SRC" "$WORKDIR/agent-system/extensions/core/context/contracts/modified-files-bullet.md"

BULLET_LINE='Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead'
OWNERSHIP_BULLET_LINE='Hand-edit the plan METADATA `- **Status**:` field -- it is owned by update-plan-status.sh (invoked from update-task-status.sh postflight), never by this agent; this agent'"'"'s plan-file write authority is limited to `### Phase N: ... [MARKER]` headings and `- [ ]` checklist items'
# shellcheck disable=SC2016
BOUNDED_WAIT_MUST_LINE='Whenever a local verification/gate/build/test process is backgrounded at all, use bounded-build-waiter.md'"'"'s canonical idiom VERBATIM: a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside one Bash call that does not return control until the wait resolves -- and prefer the plain foreground form `timeout N cmd` whenever the command plausibly fits within the Bash tool'"'"'s own ceiling'
# shellcheck disable=SC2016
BOUNDED_WAIT_MUSTNOT_LINE='Use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent, and never end the turn on an unresolved local background wait -- the harness'"'"'s own asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it'
# shellcheck disable=SC2016
MODIFIED_FILES_BULLET_LINE='Emit the top-level `modified_files` field in `.return-meta.json` on every dispatch: repo-relative paths only (never absolute), individual file paths only (never directory prefixes), paths inside this repository only, and `[]` when nothing was touched -- never omit the field -- per the "How Implementation Agents Populate modified_files" section of `.claude/context/formats/return-metadata-file.md`'
# shellcheck disable=SC2016
MODIFIED_FILES_TRACK_LINE='Track on write: at the moment of every `Write`/`Edit`, append that file'"'"'s repo-relative path to this run'"'"'s flat touched-paths list immediately -- never reconstruct the list from memory at the end of the run -- then emit the deduped list as `modified_files` at the metadata-writing stage'

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

# A minimal, recognized handoff-writing section -- satisfies Check J for any fixture that must
# pass it (a required handoff writer, not on CHECK_J_EXCLUDED_RELATIVE_PATHS, not a "never write
# one" research-agent contract). Used by fixtures elsewhere in this file that are asserted to
# produce no FAIL at all and were repaired to carry this section once Check J's content gate was
# replaced with a fail-closed iteration -- see this file's header comment's "Check J fixture
# repair" note.
# shellcheck disable=SC2016
HANDOFF_SECTION_BLOCK='### `.orchestrator-handoff.json` (orchestrator-mode dispatches)

Write this file always. `artifacts[]` entries use the {type, path, summary} object shape.'

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
# below carries neither bounded-wait bullet; lean/agents/lean-implementation-agent.md was a
# recorded Check H exclusion when this fixture was first written, but a later task (the lean
# bounded-wait migration) discharged that exclusion and added both lean implementation agents to
# BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS -- so this fixture now correctly PRODUCES a Check H FAIL
# by name, the same as any other in-scope file missing the bullet pair. See the assertion below
# (updated from its original "exclusion honored" expectation to match current scope).
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

$HANDOFF_SECTION_BLOCK

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $BOUNDED_WAIT_MUST_LINE
2. $MODIFIED_FILES_BULLET_LINE
3. $MODIFIED_FILES_TRACK_LINE

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
3. Always append touched file paths to a running list and emit them as modified_files eventually
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

$HANDOFF_SECTION_BLOCK

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

$HANDOFF_SECTION_BLOCK

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

$HANDOFF_SECTION_BLOCK

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

# =====================================================================
# Check J stale-exclusion sweep stub fixtures -- see this file's header comment's "Check J
# fixture repair" note. Each is a minimal stand-in placed at a REAL CHECK_J_EXCLUDED_RELATIVE_PATHS
# path, present-and-headingless, so the stale-exclusion sweep (which evaluates every entry whose
# extension's agents/ directory exists in this tree -- true here for core/ and cslib/, already
# created above for other fixtures' sake) stays clean rather than reporting these two paths
# stale purely because this suite's tree was never built with Check J's exclusion array in
# mind. code-reviewer-agent.md needs no artifacts/status content (it is independently a recorded
# exclusion on both Check E's and Check F's own arrays); spawn-agent.md and cslib-vet-agent.md
# are NOT excluded from either, so each carries ARTIFACTS_TEMPLATE_BLOCK to stay clean there too.
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/code-reviewer-agent.md" <<EOF
---
name: code-reviewer-agent
description: fixture standing in for the real code-reviewer-agent (CHECK_J_EXCLUDED_RELATIVE_PATHS entry)
model: sonnet
---

# Code Reviewer Agent (fixture)

Invoked only via the forked-subagent pattern; carries no handoff-writing contract of any kind.
EOF

cat > "$WORKDIR/agent-system/extensions/core/agents/spawn-agent.md" <<EOF
---
name: spawn-agent
description: fixture standing in for the real spawn-agent (CHECK_J_EXCLUDED_RELATIVE_PATHS entry)
model: sonnet
---

# Spawn Agent (fixture)

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

Invoked only via the forked-subagent pattern; carries no handoff-writing contract of any kind.
EOF

cat > "$WORKDIR/agent-system/extensions/cslib/agents/cslib-vet-agent.md" <<EOF
---
name: cslib-vet-agent
description: fixture standing in for the real cslib-vet-agent (CHECK_J_EXCLUDED_RELATIVE_PATHS entry)
model: sonnet
---

# CSLib Vet Agent (fixture)

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK

Invoked only via the forked-subagent pattern; carries no handoff-writing contract of any kind.
EOF

# =====================================================================
# Check M fixtures (added alongside Check M's implementation): a missing-bullet positive FAIL
# (nix-research-agent.md, a real BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS entry carrying
# neither bounded-wait bullet) and a near-miss paraphrase positive FAIL (rust-research-agent.md,
# proving the match is verbatim rather than loose) -- mirrors Check H's existing missing-bullet/
# near-miss pair exactly.
# =====================================================================
mkdir -p "$WORKDIR/agent-system/extensions/nix/agents"
mkdir -p "$WORKDIR/agent-system/extensions/rust/agents"

# nix-research-agent.md and rust-research-agent.md carry no in-scope-array membership besides
# Check M (research agents are never Check C/G/H/L/I members), so $ARTIFACTS_TEMPLATE_BLOCK is
# the only addition needed to keep Check E/F silent and isolate the FAIL to Check M alone.
cat > "$WORKDIR/agent-system/extensions/nix/agents/nix-research-agent.md" <<EOF
---
name: nix-research-agent
description: fixture standing in for the real nix-research-agent, carrying neither bounded-wait bullet
model: sonnet
---

# Nix Research Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST NOT**:
1. Do the wrong thing
EOF

cat > "$WORKDIR/agent-system/extensions/rust/agents/rust-research-agent.md" <<EOF
---
name: rust-research-agent
description: fixture standing in for the real rust-research-agent, carrying a near-miss paraphrase instead of the verbatim bounded-wait bullet pair
model: sonnet
---

# Rust Research Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST NOT**:
1. Never background a build and wait for a completion notification
EOF

# =====================================================================
# Line-wrap pinning fixtures (added alongside the line-wrap ruling): a Check C bullet and a
# Check G bullet, each CORRECTLY WORDED but wrapped across two physical lines, each asserted to
# FAIL by name -- proves the single-physical-line convention is enforced by the lint's own
# grep -qF matching, not merely documented in the fragments' prose. Real IN_SCOPE_RELATIVE_PATHS
# / OWNERSHIP_IN_SCOPE_RELATIVE_PATHS entries, previously unused by any fixture in this suite.
# Both are also real BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS (Check H) and
# MODIFIED_FILES_IN_SCOPE_RELATIVE_PATHS (Check L) members, so each carries every OTHER check's
# canonical line correctly, isolating the one deliberate FAIL to its own named check.
# =====================================================================
mkdir -p "$WORKDIR/agent-system/extensions/python/agents"
mkdir -p "$WORKDIR/agent-system/extensions/web/agents"

cat > "$WORKDIR/agent-system/extensions/python/agents/python-implementation-agent.md" <<EOF
---
name: python-implementation-agent
description: fixture standing in for the real python-implementation-agent, carrying a correctly-worded but line-wrapped Check C bullet
model: sonnet
---

# Python Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $MODIFIED_FILES_BULLET_LINE
2. $MODIFIED_FILES_TRACK_LINE

**MUST NOT**:
1. Reference task numbers ("task N", "tasks N-M") in files outside specs/** -- see
   .claude/rules/no-task-references-in-deliverables.md; reference durable anchors (filenames, section headings) instead
2. $OWNERSHIP_BULLET_LINE
3. $BOUNDED_WAIT_MUST_LINE
4. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

cat > "$WORKDIR/agent-system/extensions/web/agents/web-implementation-agent.md" <<EOF
---
name: web-implementation-agent
description: fixture standing in for the real web-implementation-agent, carrying a correctly-worded but line-wrapped Check G bullet
model: sonnet
---

# Web Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $MODIFIED_FILES_BULLET_LINE
2. $MODIFIED_FILES_TRACK_LINE

**MUST NOT**:
1. $BULLET_LINE
2. Hand-edit the plan METADATA \`- **Status**:\` field -- it is owned by update-plan-status.sh (invoked from update-task-status.sh postflight), never by this agent; this agent's plan-file write authority is limited to
   \`### Phase N: ... [MARKER]\` headings and \`- [ ]\` checklist items
3. $BOUNDED_WAIT_MUST_LINE
4. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

# =====================================================================
# Books PASS fixtures (added alongside Checks C/G's registration of the two real books files):
# dedicated scratch fixtures standing in for books-implementation-agent.md and
# books-implementation-hard-agent.md, carrying BOTH bullets correctly (single physical line,
# no stray backticks) -- asserted to explicitly PASS Check C and Check G by name. Both are also
# real Check H and Check L members, so each carries those canonical lines too, producing a
# fully clean (zero-FAIL) fixture rather than an unexplained Check H/L FAIL alongside the PASS.
# =====================================================================
mkdir -p "$WORKDIR/agent-system/extensions/books/agents"

cat > "$WORKDIR/agent-system/extensions/books/agents/books-implementation-agent.md" <<EOF
---
name: books-implementation-agent
description: fixture standing in for the real books-implementation-agent, carrying both the Check C and Check G bullets correctly
model: sonnet
---

# Books Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $MODIFIED_FILES_BULLET_LINE
2. $MODIFIED_FILES_TRACK_LINE
3. $BOUNDED_WAIT_MUST_LINE

**MUST NOT**:
1. $BULLET_LINE
2. $OWNERSHIP_BULLET_LINE
3. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

cat > "$WORKDIR/agent-system/extensions/books/agents/books-implementation-hard-agent.md" <<EOF
---
name: books-implementation-hard-agent
description: fixture standing in for the real books-implementation-hard-agent, carrying both the Check C and Check G bullets correctly
model: sonnet
---

# Books Implementation Hard Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $MODIFIED_FILES_BULLET_LINE
2. $MODIFIED_FILES_TRACK_LINE
3. $BOUNDED_WAIT_MUST_LINE

**MUST NOT**:
1. $BULLET_LINE
2. $OWNERSHIP_BULLET_LINE
3. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

# =====================================================================
# Check N fixtures (added alongside Check N's implementation): two positive FAILs (an
# unclassified *implementation*agent.md and *research*agent.md, in neither in-scope nor
# exclusion array -- each only subject to the glob-wide Check E/F and Check N, since neither is
# a member of any curated in-scope array) and two negatives (a real
# CHECK_G_EXCLUDED_RELATIVE_PATHS entry and a real CHECK_M_EXCLUDED_RELATIVE_PATHS entry, each
# asserted to produce no Check N FAIL and an explicit "recorded exclusions" PASS by name).
# =====================================================================
cat > "$WORKDIR/agent-system/extensions/core/agents/rogue-widget-implementation-agent.md" <<EOF
---
name: rogue-widget-implementation-agent
description: fixture agent matching the *implementation*agent.md glob but in neither Check G's in-scope array nor its recorded exclusions
model: sonnet
---

# Rogue Widget Implementation Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

A deliberately unclassified fixture -- proves Check N catches a glob match accounted for
nowhere.
EOF

cat > "$WORKDIR/agent-system/extensions/core/agents/rogue-widget-research-agent.md" <<EOF
---
name: rogue-widget-research-agent
description: fixture agent matching the *research*agent.md glob but in neither Check M's in-scope array nor its recorded exclusions
model: sonnet
---

# Rogue Widget Research Agent

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

A deliberately unclassified fixture -- proves Check N catches a glob match accounted for
nowhere.
EOF

mkdir -p "$WORKDIR/agent-system/extensions/cslib/agents"

# pr-review-implementation-agent.md is a real IN_SCOPE_RELATIVE_PATHS (Check C), Check H, and
# Check L member (though a recorded Check G exclusion) -- carries all three canonical lines so
# only Check N's exclusion-PASS branch has anything to say about it.
cat > "$WORKDIR/agent-system/extensions/cslib/agents/pr-review-implementation-agent.md" <<EOF
---
name: pr-review-implementation-agent
description: fixture standing in for the real pr-review-implementation-agent, a real Check G recorded exclusion
model: sonnet
---

# PR Review Implementation Agent (fixture)

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []

## Critical Requirements

**MUST**:
1. $MODIFIED_FILES_BULLET_LINE
2. $MODIFIED_FILES_TRACK_LINE

**MUST NOT**:
1. $BULLET_LINE
2. $BOUNDED_WAIT_MUST_LINE
3. $BOUNDED_WAIT_MUSTNOT_LINE
EOF

# pr-review-research-agent.md carries no curated-array membership besides Check N (it is a
# recorded Check M exclusion, never visited by Check M's own in-scope loop) -- only needs
# $ARTIFACTS_TEMPLATE_BLOCK to keep Check E/F silent.
cat > "$WORKDIR/agent-system/extensions/cslib/agents/pr-review-research-agent.md" <<EOF
---
name: pr-review-research-agent
description: fixture standing in for the real pr-review-research-agent, a real Check M recorded exclusion
model: sonnet
---

# PR Review Research Agent (fixture)

## Write Metadata

$ARTIFACTS_TEMPLATE_BLOCK
"modified_files": []
EOF

result="$(run_lint)"
code="${result%%$'\x1e'*}"
out="${result#*$'\x1e'}"

common_test_info "lint exit code: $code"

# The scratch fixture set is deliberately non-compliant overall (rogue-key-agent and
# no-model-agent are real violations), so the lint MUST exit 1.
if [ "$code" -eq 1 ]; then
  common_test_pass "lint exits 1 against a fixture tree with real violations"
else
  common_test_fail "lint expected exit 1, got exit=$code"
fi

# Positive: rogue-key-agent.md fails Check A on the invalid key.
if echo "$out" | grep -qF "rogue-key-agent.md: declares invalid key 'allowed-tools:'"; then
  common_test_pass "positive: rogue-key-agent.md fails Check A (invalid allowed-tools: key)"
else
  common_test_fail "positive: expected Check A failure for rogue-key-agent.md, not found in output"
fi

# Positive: no-model-agent.md fails Check B on missing model.
if echo "$out" | grep -qF "no-model-agent.md: missing required 'model:' field"; then
  common_test_pass "positive: no-model-agent.md fails Check B (missing model:)"
else
  common_test_fail "positive: expected Check B failure for no-model-agent.md, not found in output"
fi

# Positive: general-implementation-agent.md (fixture, no bullet) fails Check C.
if echo "$out" | grep -qF "core/agents/general-implementation-agent.md: missing the no-task-references MUST-NOT bullet"; then
  common_test_pass "positive: general-implementation-agent.md fixture fails Check C (missing bullet)"
else
  common_test_fail "positive: expected Check C failure for general-implementation-agent.md, not found in output"
fi

# Negative: README.md (no frontmatter) produces no Check A/B finding against it.
if echo "$out" | grep -qF "README.md:"; then
  common_test_fail "negative: README.md (frontmatter-less) was incorrectly treated as a dispatchable agent"
else
  common_test_pass "negative: README.md (frontmatter-less) produces no finding (correctly excluded)"
fi

# Negative: compliant-agent.md produces no FAIL line against it.
if echo "$out" | grep -F "compliant-agent.md" | grep -q "FAIL"; then
  common_test_fail "negative: compliant-agent.md unexpectedly failed a check"
else
  common_test_pass "negative: compliant-agent.md produces no FAIL against it"
fi

# Positive: check-f-templateless-agent.md (no artifacts key at all) fails Check F.
if echo "$out" | grep -qF "check-f-templateless-agent.md: missing an object-shaped artifacts array"; then
  common_test_pass "positive: check-f-templateless-agent.md fails Check F (no artifacts template)"
else
  common_test_fail "positive: expected Check F failure for check-f-templateless-agent.md, not found in output"
fi

# Positive: check-f-barestring-agent.md (bare-string array, the malformed shape this task
# closes) fails Check F.
if echo "$out" | grep -qF "check-f-barestring-agent.md: missing an object-shaped artifacts array"; then
  common_test_pass "positive: check-f-barestring-agent.md fails Check F (bare-string artifacts array)"
else
  common_test_fail "positive: expected Check F failure for check-f-barestring-agent.md, not found in output"
fi

# Negative: check-f-conforming-agent.md (correct object-shaped template) passes Check F --
# produces no FAIL line against it.
if echo "$out" | grep -F "check-f-conforming-agent.md" | grep -q "FAIL"; then
  common_test_fail "negative: check-f-conforming-agent.md unexpectedly failed a check"
else
  common_test_pass "negative: check-f-conforming-agent.md produces no FAIL against it"
fi

# Positive: check-f-conforming-agent.md explicitly PASSES Check F (not just "no FAIL" -- a
# genuine pass line naming it).
if echo "$out" | grep -qF "check-f-conforming-agent.md: carries an object-shaped artifacts template"; then
  common_test_pass "positive: check-f-conforming-agent.md explicitly passes Check F"
else
  common_test_fail "positive: expected an explicit Check F PASS line for check-f-conforming-agent.md, not found in output"
fi

# =====================================================================
# Check E assertions
# =====================================================================

# Positive: check-e-nostatus-agent.md (artifacts template, no status key) fails Check E.
if echo "$out" | grep -qF "check-e-nostatus-agent.md: no conformant terminal status found"; then
  common_test_pass "positive: check-e-nostatus-agent.md fails Check E (no status key at all)"
else
  common_test_fail "positive: expected Check E failure for check-e-nostatus-agent.md, not found in output"
fi

# Positive: check-e-completed-agent.md (literal "status": "completed") fails Check E by name.
if echo "$out" | grep -qF "check-e-completed-agent.md: carries a literal \"status\": \"completed\""; then
  common_test_pass "positive: check-e-completed-agent.md fails Check E by name (forbidden completed value)"
else
  common_test_fail "positive: expected Check E failure naming the forbidden completed value, not found in output"
fi

# Positive: check-e-inprogress-only-agent.md (only in_progress) fails Check E's presence detector.
if echo "$out" | grep -qF "check-e-inprogress-only-agent.md: no conformant terminal status found"; then
  common_test_pass "positive: check-e-inprogress-only-agent.md fails Check E (in_progress is not a terminal status)"
else
  common_test_fail "positive: expected Check E failure for check-e-inprogress-only-agent.md, not found in output"
fi

# Positive: check-e-pipeplaceholder-agent.md (pipe-alternatives value) fails Check E's presence
# detector -- an exact-match lookup never matches a pipe-joined string.
if echo "$out" | grep -qF "check-e-pipeplaceholder-agent.md: no conformant terminal status found"; then
  common_test_pass "positive: check-e-pipeplaceholder-agent.md fails Check E (pipe-alternatives placeholder is not a literal member)"
else
  common_test_fail "positive: expected Check E failure for check-e-pipeplaceholder-agent.md, not found in output"
fi

# Negative: check-e-falsepositive-guard-agent.md (conformant status + MUST-NOT prose containing
# "completed") produces no FAIL line against it -- proves Detector B matches only the quoted
# "status": "completed" pair, never the bare word in prose.
if echo "$out" | grep -F "check-e-falsepositive-guard-agent.md" | grep -q "FAIL"; then
  common_test_fail "negative: check-e-falsepositive-guard-agent.md unexpectedly failed a check (Detector B false-positived on MUST-NOT prose)"
else
  common_test_pass "negative: check-e-falsepositive-guard-agent.md produces no FAIL against it (Detector B does not false-positive on prose)"
fi

# Explicit positive: check-e-falsepositive-guard-agent.md passes Check E by name (not just "no
# FAIL" -- a genuine pass line naming it).
if echo "$out" | grep -qF "check-e-falsepositive-guard-agent.md: carries a conformant terminal status"; then
  common_test_pass "positive: check-e-falsepositive-guard-agent.md explicitly passes Check E"
else
  common_test_fail "positive: expected an explicit Check E PASS line for check-e-falsepositive-guard-agent.md, not found in output"
fi

# Negative: meta-builder-agent.md fixture (Check E exclusion-list entry, no conformant status at
# all) produces a named [INFO] skipped line, never a FAIL.
if echo "$out" | grep -qF "Check E: agent-system/extensions/core/agents/meta-builder-agent.md is a recorded exclusion"; then
  common_test_pass "negative: meta-builder-agent.md fixture produces a named Check E exclusion INFO line"
else
  common_test_fail "negative: expected a named Check E exclusion INFO line for meta-builder-agent.md, not found in output"
fi
if echo "$out" | grep -F "meta-builder-agent.md" | grep -q "FAIL"; then
  common_test_fail "negative: meta-builder-agent.md fixture (Check E exclusion) unexpectedly failed a check"
else
  common_test_pass "negative: meta-builder-agent.md fixture (Check E exclusion) produces no FAIL against it"
fi

# =====================================================================
# Check G assertions
# =====================================================================

# (a) Positive: general-implementation-agent.md fixture (missing the bullet) fails Check G.
if echo "$out" | grep -qF "core/agents/general-implementation-agent.md: missing the plan-level-Status ownership MUST-NOT bullet"; then
  common_test_pass "(a) positive: general-implementation-agent.md fixture fails Check G (missing bullet)"
else
  common_test_fail "(a) positive: expected Check G failure for general-implementation-agent.md, not found in output"
fi

# (b) Negative: cslib-implementation-agent.md fixture (verbatim bullet) produces no FAIL, and
# explicitly passes Check G by name.
if echo "$out" | grep -F "cslib/agents/cslib-implementation-agent.md" | grep -q "FAIL"; then
  common_test_fail "(b) negative: cslib-implementation-agent.md fixture unexpectedly failed a check"
else
  common_test_pass "(b) negative: cslib-implementation-agent.md fixture produces no FAIL against it"
fi
if echo "$out" | grep -qF "cslib/agents/cslib-implementation-agent.md: carries the plan-level-Status ownership bullet"; then
  common_test_pass "(b) positive: cslib-implementation-agent.md fixture explicitly passes Check G"
else
  common_test_fail "(b) positive: expected an explicit Check G PASS line for cslib-implementation-agent.md, not found in output"
fi

# (c) Positive: lean-implementation-agent.md fixture (near-miss paraphrase, not the verbatim
# bullet) still FAILs -- proves Check G compares against the fragment text, not a loose pattern.
if echo "$out" | grep -qF "lean/agents/lean-implementation-agent.md: missing the plan-level-Status ownership MUST-NOT bullet"; then
  common_test_pass "(c) positive: lean-implementation-agent.md near-miss paraphrase fixture fails Check G"
else
  common_test_fail "(c) positive: expected Check G failure for lean-implementation-agent.md near-miss fixture, not found in output"
fi

# =====================================================================
# Check H assertions
# =====================================================================

# (a) Negative/positive: cslib-implementation-agent.md fixture (now carrying both bounded-wait
# bullets) produces no FAIL at all, and explicitly passes Check H by name.
if echo "$out" | grep -F "cslib/agents/cslib-implementation-agent.md" | grep -q "FAIL"; then
  common_test_fail "(a) negative: cslib-implementation-agent.md fixture unexpectedly failed a check (Check H conforming fixture)"
else
  common_test_pass "(a) negative: cslib-implementation-agent.md fixture produces no FAIL against it (Check H conforming fixture)"
fi
if echo "$out" | grep -qF "cslib/agents/cslib-implementation-agent.md: carries the bounded-wait contract bullet pair"; then
  common_test_pass "(a) positive: cslib-implementation-agent.md fixture explicitly passes Check H"
else
  common_test_fail "(a) positive: expected an explicit Check H PASS line for cslib-implementation-agent.md, not found in output"
fi

# (b) Positive: neovim-implementation-agent.md fixture (neither bounded-wait bullet) fails
# Check H by name.
if echo "$out" | grep -qF "nvim/agents/neovim-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  common_test_pass "(b) positive: neovim-implementation-agent.md fixture fails Check H (missing bullet pair)"
else
  common_test_fail "(b) positive: expected Check H failure for neovim-implementation-agent.md, not found in output"
fi

# (c) Positive: z3-implementation-agent.md fixture (near-miss paraphrase, not the verbatim
# bullet pair) still FAILs -- proves Check H compares against the fragment text, not a loose
# pattern.
if echo "$out" | grep -qF "z3/agents/z3-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  common_test_pass "(c) positive: z3-implementation-agent.md near-miss paraphrase fixture fails Check H"
else
  common_test_fail "(c) positive: expected Check H failure for z3-implementation-agent.md near-miss fixture, not found in output"
fi

# (d) In-scope assertion: lean-implementation-agent.md fixture (a real
# BOUNDED_WAIT_IN_SCOPE_RELATIVE_PATHS entry since the lean bounded-wait migration discharged its
# former Check H exclusion) carries neither bounded-wait bullet, so it FAILs Check H by name --
# proving the check is not silently skipping this now-in-scope file.
if echo "$out" | grep -qF "lean/agents/lean-implementation-agent.md: missing the bounded-wait MUST/MUST-NOT bullet pair"; then
  common_test_pass "(d) in-scope: lean-implementation-agent.md fixture fails Check H (exclusion discharged, now in-scope)"
else
  common_test_fail "(d) in-scope: expected Check H failure for lean-implementation-agent.md fixture (now in-scope, not excluded), not found in output"
fi

# =====================================================================
# Check L assertions (modified_files MUST-DO bullet pair presence)
# =====================================================================

# (a) Positive: z3-implementation-agent.md fixture (a real Check L in-scope path carrying
# neither canonical line nor a "modified_files" key at all) fails Check L by name.
if echo "$out" | grep -qF "z3/agents/z3-implementation-agent.md: missing the modified_files MUST-DO bullet pair"; then
  common_test_pass "(a) positive: z3-implementation-agent.md fixture fails Check L (missing bullet pair)"
else
  common_test_fail "(a) positive: expected Check L failure for z3-implementation-agent.md, not found in output"
fi

# (b) Positive: lean-implementation-agent.md fixture (a real Check L in-scope path carrying a
# near-miss paraphrase, not the verbatim bullet pair) still FAILs -- proves Check L compares
# against the fragment text, not a loose pattern.
if echo "$out" | grep -qF "lean/agents/lean-implementation-agent.md: missing the modified_files MUST-DO bullet pair"; then
  common_test_pass "(b) positive: lean-implementation-agent.md near-miss paraphrase fixture fails Check L"
else
  common_test_fail "(b) positive: expected Check L failure for lean-implementation-agent.md near-miss fixture, not found in output"
fi

# (c) Negative/positive: cslib-implementation-agent.md fixture (repaired to carry both canonical
# lines plus a "modified_files" key) produces no FAIL at all, and explicitly passes Check L by
# name.
if echo "$out" | grep -F "cslib/agents/cslib-implementation-agent.md" | grep -q "FAIL"; then
  common_test_fail "(c) negative: cslib-implementation-agent.md fixture unexpectedly failed a check (Check L repaired fixture)"
else
  common_test_pass "(c) negative: cslib-implementation-agent.md fixture produces no FAIL against it (Check L repaired fixture)"
fi
if echo "$out" | grep -qF "cslib/agents/cslib-implementation-agent.md: carries the modified_files bullet pair"; then
  common_test_pass "(c) positive: cslib-implementation-agent.md fixture explicitly passes Check L"
else
  common_test_fail "(c) positive: expected an explicit Check L PASS line for cslib-implementation-agent.md, not found in output"
fi

# =====================================================================
# Check M assertions (bounded-wait research-agent contract bullet presence)
# =====================================================================

# (a) Positive: nix-research-agent.md fixture (a real Check M in-scope path carrying neither
# bounded-wait bullet) fails Check M by name.
if echo "$out" | grep -qF "nix/agents/nix-research-agent.md: missing the bounded-wait research-agent MUST/MUST-NOT bullet pair"; then
  common_test_pass "(a) positive: nix-research-agent.md fixture fails Check M (missing bullet pair)"
else
  common_test_fail "(a) positive: expected Check M failure for nix-research-agent.md, not found in output"
fi

# (b) Positive: rust-research-agent.md fixture (near-miss paraphrase, not the verbatim bullet
# pair) still FAILs -- proves Check M compares against the fragment text, not a loose pattern.
if echo "$out" | grep -qF "rust/agents/rust-research-agent.md: missing the bounded-wait research-agent MUST/MUST-NOT bullet pair"; then
  common_test_pass "(b) positive: rust-research-agent.md near-miss paraphrase fixture fails Check M"
else
  common_test_fail "(b) positive: expected Check M failure for rust-research-agent.md near-miss fixture, not found in output"
fi

# (c) Not-found assertions: the remaining 9 of the 11 BOUNDED_WAIT_RESEARCH_IN_SCOPE_RELATIVE_PATHS
# entries have no dedicated fixture in this scratch tree -- each must produce an explicit,
# named "in-scope agent file not found" Check M line rather than an unexplained FAIL silently
# absorbed by the suite's own exit-1 expectation.
for rel in \
  "books/agents/books-research-agent.md" \
  "books/agents/books-research-hard-agent.md" \
  "core/agents/general-research-agent.md" \
  "cslib/agents/cslib-research-agent.md" \
  "cslib/agents/cslib-research-hard-agent.md" \
  "nvim/agents/neovim-research-agent.md" \
  "python/agents/python-research-agent.md" \
  "web/agents/web-research-agent.md" \
  "z3/agents/z3-research-agent.md"; do
  if echo "$out" | grep -qF "$rel: in-scope research agent file not found"; then
    common_test_pass "(c) not-found: $rel accounted for by an explicit Check M not-found line"
  else
    common_test_fail "(c) not-found: expected an explicit Check M not-found line for $rel, not found in output"
  fi
done

# =====================================================================
# Line-wrap pinning assertions: a correctly-worded Check C/Check G bullet that is wrapped
# across two physical lines still FAILs -- pins the single-physical-line convention as
# enforced, not merely documented in the fragments' prose.
# =====================================================================
if echo "$out" | grep -qF "python/agents/python-implementation-agent.md: missing the no-task-references MUST-NOT bullet"; then
  common_test_pass "line-wrap: python-implementation-agent.md's wrapped-but-correct Check C bullet FAILs by name"
else
  common_test_fail "line-wrap: expected a Check C FAIL for python-implementation-agent.md's wrapped bullet, not found in output"
fi
if echo "$out" | grep -qF "web/agents/web-implementation-agent.md: missing the plan-level-Status ownership MUST-NOT bullet"; then
  common_test_pass "line-wrap: web-implementation-agent.md's wrapped-but-correct Check G bullet FAILs by name"
else
  common_test_fail "line-wrap: expected a Check G FAIL for web-implementation-agent.md's wrapped bullet, not found in output"
fi

# =====================================================================
# Books PASS assertions: dedicated scratch fixtures standing in for the two real books files
# explicitly PASS Check C and Check G by name (the scratch tree does not contain the real repo,
# so these are fixtures named to the real array paths, not the real files themselves).
# =====================================================================
if echo "$out" | grep -qF "books/agents/books-implementation-agent.md: carries the no-task-references bullet"; then
  common_test_pass "books: books-implementation-agent.md fixture explicitly passes Check C"
else
  common_test_fail "books: expected an explicit Check C PASS line for books-implementation-agent.md, not found in output"
fi
if echo "$out" | grep -qF "books/agents/books-implementation-agent.md: carries the plan-level-Status ownership bullet"; then
  common_test_pass "books: books-implementation-agent.md fixture explicitly passes Check G"
else
  common_test_fail "books: expected an explicit Check G PASS line for books-implementation-agent.md, not found in output"
fi
if echo "$out" | grep -qF "books/agents/books-implementation-hard-agent.md: carries the no-task-references bullet"; then
  common_test_pass "books: books-implementation-hard-agent.md fixture explicitly passes Check C"
else
  common_test_fail "books: expected an explicit Check C PASS line for books-implementation-hard-agent.md, not found in output"
fi
if echo "$out" | grep -qF "books/agents/books-implementation-hard-agent.md: carries the plan-level-Status ownership bullet"; then
  common_test_pass "books: books-implementation-hard-agent.md fixture explicitly passes Check G"
else
  common_test_fail "books: expected an explicit Check G PASS line for books-implementation-hard-agent.md, not found in output"
fi

# =====================================================================
# Check N assertions (curated-array completeness net)
# =====================================================================

# (a) Positive: an unclassified *implementation*agent.md (in neither Check G's in-scope array
# nor its recorded exclusions) FAILs Check N by name.
if echo "$out" | grep -qF "core/agents/rogue-widget-implementation-agent.md: matches *implementation*agent.md but is in neither Check G's in-scope array nor its recorded exclusions"; then
  common_test_pass "(a) positive: rogue-widget-implementation-agent.md fixture fails Check N's Check-G net"
else
  common_test_fail "(a) positive: expected a Check N failure for rogue-widget-implementation-agent.md against Check G's net, not found in output"
fi

# (a2) The same fixture also matches Check C's unconditional *implementation*agent.md subset
# net and FAILs it too -- Check N applies both nets to every glob match, independently.
if echo "$out" | grep -qF "core/agents/rogue-widget-implementation-agent.md: matches *implementation*agent.md but is not in Check C's in-scope array"; then
  common_test_pass "(a2) positive: rogue-widget-implementation-agent.md fixture also fails Check N's Check-C net"
else
  common_test_fail "(a2) positive: expected a Check N failure for rogue-widget-implementation-agent.md against Check C's net, not found in output"
fi

# (b) Positive: an unclassified *research*agent.md (in neither Check M's in-scope array nor its
# recorded exclusions) FAILs Check N by name.
if echo "$out" | grep -qF "core/agents/rogue-widget-research-agent.md: matches *research*agent.md but is in neither Check M's in-scope array nor its recorded exclusions"; then
  common_test_pass "(b) positive: rogue-widget-research-agent.md fixture fails Check N's Check-M net"
else
  common_test_fail "(b) positive: expected a Check N failure for rogue-widget-research-agent.md against Check M's net, not found in output"
fi

# (c) Negative: pr-review-implementation-agent.md (a real CHECK_G_EXCLUDED_RELATIVE_PATHS entry)
# produces no Check N FAIL against Check G's net, and explicitly PASSes via the recorded-
# exclusions branch by name.
if echo "$out" | grep -qF "cslib/agents/pr-review-implementation-agent.md: matches *implementation*agent.md but is in neither"; then
  common_test_fail "(c) negative: pr-review-implementation-agent.md unexpectedly failed Check N's Check-G net (should be a recorded exclusion)"
else
  common_test_pass "(c) negative: pr-review-implementation-agent.md fixture produces no Check N FAIL against Check G's net"
fi
if echo "$out" | grep -qF "cslib/agents/pr-review-implementation-agent.md: accounted for in Check G's recorded exclusions"; then
  common_test_pass "(c) positive: pr-review-implementation-agent.md fixture explicitly passes Check N via Check G's recorded exclusions"
else
  common_test_fail "(c) positive: expected an explicit Check N exclusions-PASS line for pr-review-implementation-agent.md, not found in output"
fi

# (d) Negative: pr-review-research-agent.md (a real CHECK_M_EXCLUDED_RELATIVE_PATHS entry)
# produces no Check N FAIL against Check M's net, and explicitly PASSes via the recorded-
# exclusions branch by name.
if echo "$out" | grep -qF "cslib/agents/pr-review-research-agent.md: matches *research*agent.md but is in neither"; then
  common_test_fail "(d) negative: pr-review-research-agent.md unexpectedly failed Check N's Check-M net (should be a recorded exclusion)"
else
  common_test_pass "(d) negative: pr-review-research-agent.md fixture produces no Check N FAIL against Check M's net"
fi
if echo "$out" | grep -qF "cslib/agents/pr-review-research-agent.md: accounted for in Check M's recorded exclusions"; then
  common_test_pass "(d) positive: pr-review-research-agent.md fixture explicitly passes Check N via Check M's recorded exclusions"
else
  common_test_fail "(d) positive: expected an explicit Check N exclusions-PASS line for pr-review-research-agent.md, not found in output"
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
  common_test_pass "fragment-missing: Check C fails loudly by name when the fragment file is absent"
else
  common_test_fail "fragment-missing: expected exit 1 + named fragment-missing failure, got exit=$frag_code"
fi

# (d) Fragment-missing fixture: Check G must ALSO fail loudly by name (never a silent pass) when
# plan-status-ownership.md specifically is absent from the same bare scratch tree.
if echo "$frag_out" | grep -qF "Check G: canonical fragment not found"; then
  common_test_pass "(d) fragment-missing: Check G fails loudly by name when plan-status-ownership.md is absent"
else
  common_test_fail "(d) fragment-missing: expected a named Check G fragment-missing failure, not found in output"
fi

# (e) Fragment-missing fixture: Check H must ALSO fail loudly by name (never a silent pass) when
# bounded-build-waiter.md specifically is absent from the same bare scratch tree.
if echo "$frag_out" | grep -qF "Check H: canonical fragment not found"; then
  common_test_pass "(e) fragment-missing: Check H fails loudly by name when bounded-build-waiter.md is absent"
else
  common_test_fail "(e) fragment-missing: expected a named Check H fragment-missing failure, not found in output"
fi

# (f) Fragment-missing fixture: Check L must ALSO fail loudly by name (never a silent pass) when
# modified-files-bullet.md specifically is absent from the same bare scratch tree.
if echo "$frag_out" | grep -qF "Check L: canonical fragment not found"; then
  common_test_pass "(f) fragment-missing: Check L fails loudly by name when modified-files-bullet.md is absent"
else
  common_test_fail "(f) fragment-missing: expected a named Check L fragment-missing failure, not found in output"
fi

# =====================================================================
# --help and unknown-argument fixtures
# =====================================================================
help_out="$(bash "$LINT_SRC" --help 2>&1)"
help_code=$?
if [ "$help_code" -eq 0 ] && echo "$help_out" | grep -qF "Usage: lint-agent-contracts.sh"; then
  common_test_pass "--help: exits 0 and prints usage"
else
  common_test_fail "--help: expected exit 0 + usage text, got exit=$help_code"
fi

bash "$LINT_SRC" --bogus-flag >/dev/null 2>&1
unknown_code=$?
if [ "$unknown_code" -eq 2 ]; then
  common_test_pass "unknown argument: exits 2"
else
  common_test_fail "unknown argument: expected exit 2, got exit=$unknown_code"
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
