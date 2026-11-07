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
#   DECLARATION-KIND AND DOTTED-NAME WIDENING: the per-name declaration lookup used to grep only
#   `theorem|def|lemma|instance`, so a Goal naming a `structure` (or `abbrev`, `inductive`, ...)
#   was reported [MISSING] even when the declaration plainly existed, and a Goal naming a
#   structure FIELD -- which is not a top-level declaration at all -- was reported [MISSING] too.
#   Independently, the backticked-token harvest rejected dotted names, so a namespaced Goal such
#   as `Foo.bar` was never checked: neither found nor reported missing, simply skipped. Both are
#   fixed by `find_decl_files` / `find_field_files` / `find_module_files` below (see the comments
#   there for the exact kinds, modifiers, namespace resolution, the structure-field fallback, and
#   the module-path fallback) and by the harvest's dotted-token form. Two deliberate harvest exclusions keep the widening from manufacturing new
#   false [MISSING] reports: a dotted token whose FIRST component starts lowercase (`fine.taskRel`,
#   `h.symm`) is a projection on a local variable, not a declaration, and a token whose last
#   component is a file extension (`Refinement.lean`) is a filename. Verdict strings and exit
#   codes are unchanged; only which names are checked and how a present declaration is recognised.
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

# COLON-OPTIONAL GOALS RANGE -- see the header comment. END_RE terminates the range at the next
# `**`-prefixed bold lead-in, full stop -- it does NOT special-case the first character after
# `**` to exclude `G`. An earlier `^\*\*[^G]` form tried to dodge re-matching the `**Goals**`
# start line itself by excluding every bold line beginning with `G`, but GNU sed's range
# end-address is already tested starting from the line AFTER the one that matched the start
# address (verified: `/A/,/A/p` over `A`,`B`,`A` prints all three, not just the first), so that
# exclusion was both unnecessary and actively wrong: a later bold lead-in that itself happens to
# start with `G` (e.g. a `**Goals-set policy**` paragraph) failed to terminate the range, letting
# the harvest run on into following prose and pick up unrelated backticked identifiers (see
# iss_1793949902436_VH60CH -- a stray `valid_m4` mention was harvested this way). `^\*\*/` alone
# correctly stops at `**Non-Goals**`, at a `**Goals-`-prefixed lead-in, or at any other bold
# lead-in, with no false "still inside Goals" extension.
#
# SHARED FRAGILITY: lean-challenge-snapshot.sh's own extract_goal_names() applies the same
# colon-optional widening independently (not shared code -- POSIX `sed` here, Python regex
# there). The two readers must not drift apart on which Goals-header shapes they accept; see the
# comment at that script's own START_RE for its half of this cross-reference.
# IDENT_PCRE: one Lean identifier, optionally dotted (`Foo`, `Foo.bar`, `Foo.Bar.baz`). Shared by
# the Goals harvest and the replacement_targets harvest below so the two cannot drift apart on
# which token shapes they accept.
IDENT_PCRE='[a-zA-Z_][a-zA-Z0-9_'"'"']*(?:\.[a-zA-Z_][a-zA-Z0-9_'"'"']*)*'

# Harvest exclusions beyond the reserved-keyword denylist -- see the header comment's
# DECLARATION-KIND AND DOTTED-NAME WIDENING paragraph for why each exists.
FILE_EXTENSIONS_ERE='^(lean|olean|md|sh|json|typ|txt|py|toml|yaml|yml|tex|bib|csv|pdf|html|log)$'
is_excluded_token() {
  local tok="$1"
  is_lean_keyword "$tok" && return 0
  case "$tok" in
    *.*)
      # Filename-shaped: last component is a file extension.
      printf '%s' "${tok##*.}" | grep -qE "$FILE_EXTENSIONS_ERE" && return 0
      # Projection-shaped: a dotted token whose first component starts lowercase (or `_`) is a
      # field/method access on a local variable (`fine.taskRel`, `hcoarse.trans`), not a
      # namespaced declaration. Lean namespaces and types are capitalised by convention; a
      # lowercase-rooted dotted declaration (`foo.aux`) is the one shape this heuristic forgoes,
      # and it was never checked before this widening either.
      case "${tok%%.*}" in [a-z_]*) return 0 ;; esac
      ;;
  esac
  return 1
}

goal_names_raw=$(sed -n '/^\*\*Goals\*\*/,/^\*\*/p' "$plan_file" \
  | grep -oP '`'"$IDENT_PCRE"'`' | tr -d '`' | sort -u)

goal_names=""
for name in $goal_names_raw; do
  is_excluded_token "$name" && continue
  goal_names="$goal_names $name"
done
goal_names=$(printf '%s\n' $goal_names | sort -u)

if [ -z "$goal_names" ]; then
  echo "COMPLIANCE_CHECK: skipped (no non-keyword backticked identifiers found under **Goals** in $plan_file)"
  exit 0
fi

# ---------------------------------------------------------------------------------------------
# Declaration lookup -- see the header comment's DECLARATION-KIND AND DOTTED-NAME WIDENING.
#
# A declaration line is recognised as: optional indentation, zero or more `@[...]` attribute
# groups, zero or more modifiers, a declaration kind, whitespace, the name, and a terminator that
# is not an identifier character or `.` (so `foo` never matches `theorem foo.bar` or `theorem
# foobar`). All three pieces are ERE fragments consumed by `grep -E`.
DECL_ATTR_ERE='(@\[[^]]*\][[:space:]]*)*'
DECL_MOD_ERE='((private|protected|noncomputable|partial|unsafe|nonrec)[[:space:]]+)*'
DECL_KINDS_ERE='(theorem|lemma|def|abbrev|instance|structure|class[[:space:]]+inductive|class|inductive|opaque|axiom)'
NAME_END_ERE="([^A-Za-z0-9_'.]|\$)"

escape_dots() { printf '%s' "$1" | sed 's/\./\\./g'; }

# decl_line_ere NAME -> the ERE matching a top-level declaration of exactly NAME (dots literal).
decl_line_ere() {
  printf '^[[:space:]]*%s%s%s[[:space:]]+%s%s' \
    "$DECL_ATTR_ERE" "$DECL_MOD_ERE" "$DECL_KINDS_ERE" "$(escape_dots "$1")" "$NAME_END_ERE"
}

# find_decl_files NAME -> prints every file under the resolved roots that declares NAME, one per
# line; prints nothing when none does.
#
# Step 1 matches the fully-qualified spelling verbatim (`theorem Foo.bar`). Step 2, for a dotted
# NAME only, resolves the namespaced spelling: for each split `P.S` of NAME (P = leading
# components, S = the rest), a file declaring `S` counts iff it also opens a `namespace` whose
# own dotted path ENDS with P -- `namespace P`, `namespace Outer.P`, or (for nested namespaces)
# just P's last component. This is a same-file approximation: it does not prove the declaration
# sits textually inside that namespace block, but it rules out the loose reading in which
# `Foo.comm` would be satisfied by any `theorem comm` anywhere in the tree.
find_decl_files() {
  local name="$1" files
  files=$(grep -rlE "$(decl_line_ere "$name")" "${lean_roots[@]}" 2>/dev/null)
  if [ -z "$files" ] && [[ "$name" == *.* ]]; then
    local rest="$name" prefix="" f
    while [[ "$rest" == *.* ]]; do
      prefix="${prefix:+$prefix.}${rest%%.*}"
      rest="${rest#*.}"
      local prefix_last="${prefix##*.}"
      local ns_ere="^[[:space:]]*namespace[[:space:]]+([A-Za-z_][A-Za-z0-9_']*\.)*($(escape_dots "$prefix")|${prefix_last})[[:space:]]*$"
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        grep -qE "$ns_ere" "$f" 2>/dev/null && files="${files:+$files
}$f"
      done < <(grep -rlE "$(decl_line_ere "$rest")" "${lean_roots[@]}" 2>/dev/null)
    done
  fi
  [ -n "$files" ] && printf '%s\n' "$files" | sort -u
}

# find_field_files NAME -> prints every file in which NAME is declared as a `structure`/`class`
# FIELD: an indented line of the form `name : ...` or `name (binders) : ...`, with the colon not
# immediately followed by `=` (which would be a `where`-instance assignment, not a field). For a
# dotted NAME (`Struct.field`) the search is confined to the files that declare `Struct` (via
# find_decl_files, so a namespaced structure resolves too); for a bare NAME it is tree-wide. A
# field is not a top-level declaration, so the main loops report it [OK] with its own note rather
# than [MISSING] -- the false-negative this fallback exists to remove.
field_line_ere() {
  printf '^[[:space:]]+%s([[:space:]]*\\([^)]*\\))*[[:space:]]*:([^=]|$)' "$(escape_dots "$1")"
}
find_field_files() {
  local name="$1" f
  if [[ "$name" == *.* ]]; then
    local struct="${name%.*}" field="${name##*.}"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qE "$(field_line_ere "$field")" "$f" 2>/dev/null && printf '%s\n' "$f"
    done < <(find_decl_files "$struct")
  else
    grep -rlE "$(field_line_ere "$name")" "${lean_roots[@]}" 2>/dev/null
  fi
}

# find_module_files NAME -> prints the `.lean` file NAME denotes as a Lean MODULE path, if any:
# `A.B.C` is `<root>/A/B/C.lean` under some resolved root, or `<root>/B/C.lean` when `A` is that
# root's own directory name (`Logos.Foundations.Truth` under root `Logos/`). A Goal that names a
# module (one it creates or revises) is neither a declaration nor a field, and was never checked
# before dotted names were harvested; without this step the harvest widening would have turned
# such a Goal from silently skipped into a false [MISSING].
find_module_files() {
  local name="$1" root rel
  rel="${name//.//}.lean"
  for root in "${lean_roots[@]}"; do
    [ -f "$root/$rel" ] && printf '%s\n' "$root/$rel"
    if [ "${name%%.*}" = "$(basename "$root")" ] && [[ "$name" == *.* ]]; then
      local rel_inner="${name#*.}"
      rel_inner="${rel_inner//.//}.lean"
      [ -f "$root/$rel_inner" ] && printf '%s\n' "$root/$rel_inner"
    fi
  done
}
# ---------------------------------------------------------------------------------------------

compliance_failed=false

if [ "$goal_polarity" = "refutation" ]; then
  # REFUTATION POLARITY: every harvested name must be ABSENT from the resolved source roots.
  for name in $goal_names; do
    if [ -n "$(find_decl_files "$name")" ]; then
      echo "  [PRESENT] $name — found in the resolved source roots (must be ABSENT under refutation polarity)"
      compliance_failed=true
    elif [ -n "$(find_field_files "$name")" ]; then
      echo "  [PRESENT] $name — found as a structure/class field in the resolved source roots (must be ABSENT under refutation polarity)"
      compliance_failed=true
    elif [ -n "$(find_module_files "$name")" ]; then
      echo "  [PRESENT] $name — found as a Lean module under the resolved source roots (must be ABSENT under refutation polarity)"
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
    if [ -n "$(find_decl_files "$name")" ]; then
      echo "  [OK] $name — found in the resolved source roots"
    elif [ -n "$(find_field_files "$name")" ]; then
      echo "  [OK] $name — found as a structure/class field in the resolved source roots"
    elif [ -n "$(find_module_files "$name")" ]; then
      echo "  [OK] $name — found as a Lean module under the resolved source roots"
    else
      echo "  [MISSING] $name — not found in the resolved source roots"
      compliance_failed=true
    fi
  done

  replacement_targets=$(grep -oP '(?:replacement for|replaces|bypasses|supersedes)\s+`'"$IDENT_PCRE"'`' "$plan_file" 2>/dev/null \
    | grep -oP '`'"$IDENT_PCRE"'`' | tr -d '`')
  for replaced in $replacement_targets; do
    for new_name in $goal_names; do
      new_file=$(find_decl_files "$new_name" | head -1)
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
