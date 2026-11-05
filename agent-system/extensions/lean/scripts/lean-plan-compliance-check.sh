#!/usr/bin/env bash
# lean-plan-compliance-check.sh -- Final Verification Stage step 5's plan-compliance spot-check,
# extracted from lean-implementation-agent.md's inline bash block into a standalone, testable
# script. Behaviour-identical to the pre-extraction block: the Goals-block sed range extraction,
# the backticked-token harvest, the per-name declaration grep across the resolved Lean source
# roots, the replacement_targets integrity sweep, and the passed/failed/skipped verdict.
#
# This extraction is deliberately behaviour-preserving -- see
# test-lean-plan-compliance-check.sh's characterization cases, which pin today's quirks
# (colon-anchored Goals range; no reserved-keyword denylist, so a backticked `sorry` is
# harvested as a name to find) so a later phase's changes are visible as deliberate diffs
# rather than silent drift.
#
# Usage: lean-plan-compliance-check.sh <plan_file> <lean_root> [<lean_root> ...]
#
# Prints the per-name [OK]/[MISSING]/[INTEGRITY FAIL] lines on stdout exactly as the
# pre-extraction block did, followed by a single parseable verdict line:
#   COMPLIANCE_CHECK: passed
#   COMPLIANCE_CHECK: failed
#   COMPLIANCE_CHECK: skipped (<reason>)
#
# Exit codes: 0 (passed or skipped -- neither is a script failure, matching the caller's own
# `If "failed", set status: "partial"` instruction, which fires only on the failed verdict),
# 1 (failed), 2 (usage error: missing plan_file argument or no lean_root given).

set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <plan_file> <lean_root> [<lean_root> ...]" >&2
  exit 2
fi

plan_file="$1"
shift
lean_roots=("$@")

if [ -z "$plan_file" ] || [ ! -f "$plan_file" ]; then
  echo "COMPLIANCE_CHECK: skipped (plan file not found: $plan_file)"
  exit 0
fi

goal_names=$(sed -n '/^\*\*Goals\*\*:/,/^\*\*[^G]/p' "$plan_file" \
  | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`' | sort -u)

if [ -z "$goal_names" ]; then
  echo "COMPLIANCE_CHECK: skipped (no backticked identifiers found under **Goals**: in $plan_file)"
  exit 0
fi

compliance_failed=false
for name in $goal_names; do
  if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b" "${lean_roots[@]}" 2>/dev/null; then
    echo "  [OK] $name — found in the resolved source roots"
  else
    echo "  [MISSING] $name — not found in the resolved source roots"
    compliance_failed=true
  fi
done

replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses|supersedes)\s+`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' "$plan_file" 2>/dev/null \
  | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`')
for replaced in $replacement_targets; do
  for new_name in $goal_names; do
    new_file=$(grep -rl "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${new_name}\b" "${lean_roots[@]}" 2>/dev/null | head -1)
    if [ -n "$new_file" ] && grep -q "\b${replaced}\b" "$new_file"; then
      echo "  [INTEGRITY FAIL] $new_name delegates to $replaced"
      compliance_failed=true
    fi
  done
done

if [ "$compliance_failed" = true ]; then
  echo "COMPLIANCE_CHECK: failed"
  exit 1
else
  echo "COMPLIANCE_CHECK: passed"
  exit 0
fi
