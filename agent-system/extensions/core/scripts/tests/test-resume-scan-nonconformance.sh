#!/usr/bin/env bash
# test-resume-scan-nonconformance.sh - Fixture-driven regression suite for the resume-scan
# conformance gate wired into the remaining hard-mode per-phase dispatch site (core's Site D
# structural check). Exercises the ordering contract directly: PHASE_HEADING_ERE-filtered scans
# MUST run has_nonconforming_phase_headings over the whole plan file first, or a non-conforming
# heading is silently invisible to the scan rather than merely unmatched by it -- see
# scripts/lib/phase-heading-patterns.sh's "Ordering contract for filtered scans" header note and
# context/formats/plan-format.md's "Canonical phase-heading shape" subsection.
#
# Former Site B (the standalone core implementer-hard skill file) is REMOVED, not retargeted: that
# file is deleted outright.
#
# Former Site A (skill-orchestrate/SKILL.md's single-task hard_mode-gated per-phase-dispatch (H1)
# branch) is likewise REMOVED, not retargeted here: the four-move loop rewrite (see
# docs/architecture/orchestrate-state-machine.md) deleted the single-task engine entirely, and
# H1's actual mechanism (the conformance gate, the heading-scan next_phase selection, the
# marker/handoff crosscheck, the disputed-heading downgrade) already lives as real, executable
# bash inside `scripts/orchestrate-cycle-plan.sh` -- ported there, with full equivalent coverage
# (non-conforming heading -> blocked; marker/handoff mismatch -> blocked + downgrade; successful
# phase selection; no-open-heading fallthrough; --dry-run parity), by
# `scripts/tests/test-orchestrate-cycle-plan.sh`'s own "Group 9: H1 hard-mode per-phase dispatch".
#
# Former Site C (skill-lean-implementation-hard/SKILL.md's sentinel-delimited
# `resume-scan-conformance-gate:begin`/`:end` region, plus its fixture-driven execution harness
# and Fixtures A/B/C which existed solely to drive it) is ALSO now REMOVED, not retargeted: the
# routing_agents_hard-to-hard_contracts migration task retired the six orphaned hard skill
# directories outright, including skill-lean-implementation-hard itself. That file's logic was
# already routing-unreachable before its deletion -- no routing block has named a skill by a
# "-hard" suffix convention since an earlier retirement of the skill-level router (see Site A's
# own history above) -- so this is a loss of dead-code test coverage, not of live behavior. The
# standard (non-hard) skill-lean-implementation/SKILL.md carries no equivalent
# resume-scan-conformance-gate region to retarget onto: the standard skill dispatches the whole
# implementation agent, which resolves its own resume point internally (see
# lean-implementation-agent.md's own "Stage 3: Find Resume Point"), rather than the skill layer
# pre-scanning for a phase number the way the hard-mode per-phase dispatch skill did.
#
# Structural model: scripts/tests/test-phase-heading-patterns.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, exit 0 all-pass / 1 any-fail / 2 environment error,
# deploy-tree-first then source-store-fallback library resolution).
#
# HONEST SCOPE LIMIT: Site D (update-task-status.sh) is covered by `bash -n` and structural grep
# only in this suite, not by execution -- it is a real standalone script; see Phase 4 of the
# implementation plan this suite originally verified. The preflight phase auto-advance
# convenience Site D used to guard (the first_phase_heading path, and its
# has_nonconforming_phase_headings guard) has since been deleted outright -- update_plan_file()
# no longer writes any per-phase marker, on any path -- so Site D now asserts the ABSENCE of that
# deleted path's guard invocation rather than its presence, confirming a full deletion rather
# than a partial edit that left the guard behind without its caller.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (library
# or Site D's required file not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
# REPO_ROOT resolution must work from BOTH invocation sites this suite supports: the
# source-store copy (agent-system/extensions/core/scripts/tests/) and the deployed copy
# (.claude/scripts/tests/), which sit at different depths below the repo root. A single
# fixed levels-up count cannot be correct for both depths at once, so resolve via the git
# worktree root first (depth-independent) and only fall back to the fixed-depth guess
# (matching the source-store depth) when SCRIPT_DIR is not inside a git work tree.
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

LIB="$(common_test_resolve_subject "phase-heading-patterns.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/phase-heading-patterns.sh" \
  "$SCRIPT_DIR/../lib/phase-heading-patterns.sh")" || exit 2
common_test_declare_subject "$LIB"

SITE_D_FILE="$REPO_ROOT/agent-system/extensions/core/scripts/update-task-status.sh"

if [[ ! -f "$SITE_D_FILE" ]]; then
  echo "ERROR: required file not found: $SITE_D_FILE" >&2
  exit 2
fi

PASSED=0
FAILED=0


common_test_workdir_init

# =====================================================================
# Repo-wide assertion: zero occurrences of the racy `nonconforming_phase_headings | grep -q`
# invocation form under agent-system/extensions/. Excludes backtick-quoted doc-comment
# references to the forbidden form (the canonical gate snippet's own header comment
# intentionally quotes the literal forbidden form as documentation, e.g. "the
# `nonconforming_phase_headings | grep -q .` pipe form is forbidden") -- real invocation syntax
# is never backtick-wrapped, so this exclusion cannot hide a genuine violation.
# =====================================================================
forbidden_hits="$(grep -rnE 'nonconforming_phase_headings[[:space:]]*\|[[:space:]]*grep -q' \
  "$REPO_ROOT/agent-system/extensions" 2>/dev/null | grep -v '`' || true)"
if [[ -z "$forbidden_hits" ]]; then
  common_test_pass "Repo-wide: zero occurrences of the racy \`nonconforming_phase_headings | grep -q\` invocation form under agent-system/extensions/"
else
  common_test_fail "Repo-wide: found racy pipe-form invocation(s):"$'\n'"${forbidden_hits}"
fi

# =====================================================================
# Site D: bash -n only (structural, not executed -- see header note).
# =====================================================================
if bash -n "$SITE_D_FILE" 2>"$WORKDIR/site-d.err"; then
  common_test_pass "Site D (update-task-status.sh): bash -n clean"
else
  common_test_fail "Site D (update-task-status.sh): bash -n failed: $(cat "$WORKDIR/site-d.err")"
fi
if grep -q 'has_nonconforming_phase_headings "\$plan_file"' "$SITE_D_FILE"; then
  common_test_fail "Site D: the first_phase_heading auto-advance convenience (and its has_nonconforming_phase_headings guard) should have been deleted outright, but the guard invocation is still present"
else
  common_test_pass "Site D: first_phase_heading auto-advance convenience and its guard were fully deleted -- update_plan_file() writes no per-phase marker on any path"
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
