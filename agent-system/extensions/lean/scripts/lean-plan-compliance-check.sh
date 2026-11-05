#!/usr/bin/env bash
# lean-plan-compliance-check.sh -- Final Verification Stage step 5's plan-compliance spot-check,
# extracted from lean-implementation-agent.md's inline bash block into a standalone, testable
# script. Behaviour-identical to the pre-extraction block: the Goals-block sed range extraction,
# the backticked-token harvest, the per-name declaration grep across the resolved Lean source
# roots, the replacement_targets integrity sweep, and the passed/failed/skipped verdict --
# EXCEPT for the deliberate changes below, each named so a later reader does not mistake them
# for the original extraction's own behaviour.
#
# Changes beyond the original (behaviour-preserving) extraction:
#
#   GOAL POLARITY (opt-in, default unchanged): an optional `- **Goal Polarity**:` plan-level
#   metadata line lets a refutation-shaped plan -- one whose Goals name identifiers that must be
#   ABSENT from the tree, not present -- reach a correct, positively confirming verdict instead
#   of being failed for achieving its goal. Three states:
#     - absent (no such line in the plan): today's must-exist behaviour, unchanged. Every plan
#       written before this field existed keeps its current verdict.
#     - `refutation`: every harvested name must be ABSENT from the resolved source roots -- all
#       absent -> passed; any present -> failed, naming the present ones. The replacement_targets
#       integrity sweep does not apply under this polarity (it assumes a present declaration
#       whose body can be inspected) and is skipped.
#     - any other explicit value (e.g. `mixed`): a plan whose Goals block genuinely mixes
#       must-exist and must-be-absent identifiers cannot be expressed by this single global
#       field. Such a plan declares an explicit non-refutation value rather than leaving the
#       field absent (which would wrongly apply must-exist semantics to an identifier that must
#       be absent), and the script records `skipped` with a stated reason -- the honest outcome a
#       human previously had to reach by hand, now reached mechanically.
#
#   RESERVED-KEYWORD DENYLIST: `LEAN_KEYWORDS` below subtracts Lean's reserved keywords from the
#   harvested identifier set, mirroring (independently -- see the comment at `LEAN_KEYWORDS`
#   itself for why this is NOT shared code with) lean-challenge-snapshot.sh's own denylist of the
#   same name. A backticked `sorry` or `box` in prose is no longer harvested as a declaration to
#   find.
#
#   COLON-OPTIONAL GOALS RANGE: the Goals-block `sed` range now accepts `**Goals**` with or
#   without a trailing colon (`**Goals**:`, `**Goals**`, `**Goals** (parenthetical):`), matching
#   the same widening lean-challenge-snapshot.sh's own extract_goal_names() made to its START_RE.
#   See the comment at the `sed` call itself for why the two Goals-block readers must not drift
#   apart on this point.
#
# See test-lean-plan-compliance-check.sh's characterization cases (which this phase's new cases
# sit alongside) for the pre-existing quirks this extraction otherwise still preserves.
#
# Usage: lean-plan-compliance-check.sh <plan_file> <lean_root> [<lean_root> ...]
#
# Prints the per-name [OK]/[MISSING]/[PRESENT]/[INTEGRITY FAIL] lines on stdout, followed by a
# single parseable verdict line:
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

# GOAL POLARITY resolution -- see the header comment's full three-state description. Accepts an
# optional leading `- ` (list-item form) ahead of the label, matching plan-format.md's own
# metadata-line convention for other plan-level fields.
goal_polarity_raw=$(grep -oP '^\s*-?\s*\*\*Goal Polarity\*\*:\s*\K.+' "$plan_file" 2>/dev/null | head -1)
goal_polarity=$(printf '%s' "${goal_polarity_raw:-}" | tr '[:upper:]' '[:lower:]' | sed -E 's/^\s+|\s+$//g')

if [ -n "$goal_polarity" ] && [ "$goal_polarity" != "refutation" ]; then
  echo "COMPLIANCE_CHECK: skipped (declared Goal Polarity '$goal_polarity_raw' is not 'refutation' -- a mixed or otherwise non-refutation polarity cannot be expressed by this single global field; spot-check deliberately not attempted)"
  exit 0
fi

# RESERVED-KEYWORD DENYLIST -- independently maintained from lean-challenge-snapshot.sh's own
# LEAN_KEYWORDS (a Python set there, this script's own bash-side list here). Do not attempt to
# share one across the two languages/implementations in this phase; a future consolidation
# should start from this comment and the matching one in lean-challenge-snapshot.sh.
LEAN_KEYWORDS="theorem lemma def abbrev instance structure class inductive axiom sorry by let fun do match with where have show suffices calc exact from if then else end open import namespace section universe variable variables mutual noncomputable private protected partial unsafe deriving extends attribute local scoped macro syntax notation"
is_lean_keyword() {
  local tok="$1" kw
  for kw in $LEAN_KEYWORDS; do
    [ "$tok" = "$kw" ] && return 0
  done
  return 1
}

# COLON-OPTIONAL GOALS RANGE -- see the header comment. END_RE-equivalent (`^\*\*[^G]`) is
# unaffected: it only tests the character immediately after `**`, so `**Non-Goals**` still never
# extends the range.
#
# SHARED FRAGILITY: lean-challenge-snapshot.sh's own extract_goal_names() applies the same
# colon-optional widening independently (not shared code -- POSIX `sed` here, Python regex
# there). The two readers must not drift apart on which Goals-header shapes they accept; see the
# comment at that script's own START_RE for its half of this cross-reference.
goal_names_raw=$(sed -n '/^\*\*Goals\*\*/,/^\*\*[^G]/p' "$plan_file" \
  | grep -oP '`[a-zA-Z_][a-zA-Z0-9_'"'"']*`' | tr -d '`' | sort -u)

goal_names=""
for name in $goal_names_raw; do
  is_lean_keyword "$name" && continue
  goal_names="$goal_names $name"
done
goal_names=$(printf '%s\n' $goal_names | sort -u)

if [ -z "$goal_names" ]; then
  echo "COMPLIANCE_CHECK: skipped (no non-keyword backticked identifiers found under **Goals** in $plan_file)"
  exit 0
fi

compliance_failed=false

if [ "$goal_polarity" = "refutation" ]; then
  # REFUTATION POLARITY: every harvested name must be ABSENT from the resolved source roots.
  for name in $goal_names; do
    if grep -rq "^\(noncomputable \)\?\(theorem\|def\|lemma\|instance\) ${name}\b" "${lean_roots[@]}" 2>/dev/null; then
      echo "  [PRESENT] $name — found in the resolved source roots (must be ABSENT under refutation polarity)"
      compliance_failed=true
    else
      echo "  [OK] $name — absent from the resolved source roots, as required under refutation polarity"
    fi
  done
  # The replacement_targets integrity sweep assumes a present declaration whose body can be
  # inspected -- it does not apply under refutation polarity and is deliberately skipped.
else
  # MUST-EXIST POLARITY (default, unchanged): every harvested name must be PRESENT.
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
fi

if [ "$compliance_failed" = true ]; then
  echo "COMPLIANCE_CHECK: failed"
  exit 1
else
  echo "COMPLIANCE_CHECK: passed"
  exit 0
fi
