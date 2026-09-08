#!/usr/bin/env bash
# test-generate-task-order.sh - Regression suite for generate-task-order.sh's "Grouped by Topic"
# summary-line production: the single task_desc source expression (build_graph, ~line 155) and
# the cross-topic short_desc slice (_print_topic_node, ~line 592).
#
# Guards four independent guarantees the two slice sites must jointly satisfy:
#   1. Markdown safety   - no cut can leave an unbalanced inline-code/emphasis/link span.
#   2. Title preference  - .title is preferred over .description, which remains the fallback.
#   3. Budget + boundary - no line exceeds its budget; a cut backs off to a word boundary and
#                           is visibly marked; an untruncated line carries no marker.
#   4. Second slice site - the cross-topic "(see above)" annotation gets the same guarantees,
#                           without doubling a marker already applied by the first slice.
#
# Anti-vacuity discipline (case group 1): each markdown-safety fixture asserts BOTH that a naive
# character slice of the raw fixture text IS unsafe (proves the fixture is genuinely adversarial,
# not accidentally inert) AND that the script's actual output IS safe -- so a fixture both a
# broken and a fixed implementation would render identically never counts as coverage.
#
# Structural model: test-errors-append.sh (mktemp -d TOP_WORKDIR with an EXIT-trap cleanup,
# pass()/fail()/info() helpers, integer PASSED/FAILED counters, exit 0 all-pass / 1 any-fail /
# 2 environment error; per-case isolated scratch built via build_scratch()).
#
# RESOLUTION ORDER (deliberate, mirrors test-postflight-deploy-gate.sh's inversion): the script
# under test, generate-task-order.sh, is resolved SOURCE-STORE-FIRST
# (agent-system/extensions/core/scripts/generate-task-order.sh), falling back to the deployed
# copy (.claude/scripts/generate-task-order.sh) only if the source-store copy is absent. This is
# the file this fix lands in, and the suite must be meaningful on that edit alone, before any
# deploy runs. Its two unchanged dependencies (deploy-root-guard.sh, lib/common.sh) are resolved
# DEPLOY-TREE-FIRST, as every other suite in this directory does.
#
# ISOLATION CONTRACT: every case builds a fresh scratch project root under mktemp -d with its
# own <scratch>/.claude/scripts/{generate-task-order.sh,deploy-root-guard.sh,lib/common.sh} and
# <scratch>/specs/{state.json,TODO.md}, and drives the script exclusively through
# `--update-todo <scratch-todo> <scratch-state>` against synthetic fixture state.json content.
# The suite never reads or writes the real specs/state.json or specs/TODO.md; a checksum guard
# at the end of the run confirms both are byte-identical to how this suite found them.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- Source-store-first resolution for the file under test ---
GTO_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/generate-task-order.sh"
  "$DEPLOY_SCRIPTS_SRC/generate-task-order.sh"
)
GTO_SRC=""
for c in "${GTO_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { GTO_SRC="$c"; break; }
done
if [[ -z "$GTO_SRC" ]]; then
  echo "ERROR: generate-task-order.sh not found at any of: ${GTO_CANDIDATES[*]}" >&2
  exit 2
fi

# --- Deploy-tree-first resolution for the two unchanged dependencies ---
GUARD_CANDIDATES=(
  "$DEPLOY_SCRIPTS_SRC/deploy-root-guard.sh"
  "$SOURCE_STORE_SCRIPTS/deploy-root-guard.sh"
)
GUARD_SRC=""
for c in "${GUARD_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { GUARD_SRC="$c"; break; }
done
COMMON_CANDIDATES=(
  "$DEPLOY_SCRIPTS_SRC/lib/common.sh"
  "$SOURCE_STORE_SCRIPTS/lib/common.sh"
)
COMMON_SRC=""
for c in "${COMMON_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { COMMON_SRC="$c"; break; }
done
if [[ -z "$GUARD_SRC" ]]; then
  echo "ERROR: deploy-root-guard.sh not found at any of: ${GUARD_CANDIDATES[*]}" >&2
  exit 2
fi
if [[ -z "$COMMON_SRC" ]]; then
  echo "ERROR: lib/common.sh not found at any of: ${COMMON_CANDIDATES[*]}" >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Under test (source-store-first): $GTO_SRC"
info "Dependency (deploy-first): $GUARD_SRC"
info "Dependency (deploy-first): $COMMON_SRC"

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${TOP_WORKDIR:-}" && -d "$TOP_WORKDIR" ]] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# Live-tree isolation guard: snapshot checksums of the real specs/ artifacts now, re-checked
# after every case has run (final section below).
REAL_TODO="$REPO_ROOT/specs/TODO.md"
REAL_STATE="$REPO_ROOT/specs/state.json"
REAL_TODO_SUM_BEFORE=""
REAL_STATE_SUM_BEFORE=""
[[ -f "$REAL_TODO" ]] && REAL_TODO_SUM_BEFORE="$(sha256sum "$REAL_TODO" | awk '{print $1}')"
[[ -f "$REAL_STATE" ]] && REAL_STATE_SUM_BEFORE="$(sha256sum "$REAL_STATE" | awk '{print $1}')"

# ─── Harness helpers ────────────────────────────────────────────────────────────────────────

# build_scratch -- builds an isolated <scratch>/.claude/scripts/{generate-task-order.sh,
# deploy-root-guard.sh,lib/common.sh} + <scratch>/specs/TODO.md tree. Echoes the scratch root.
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$GTO_SRC" "$scratch/.claude/scripts/generate-task-order.sh"
  cp "$GUARD_SRC" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SRC" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/generate-task-order.sh"
  cat > "$scratch/specs/TODO.md" <<'TODOEOF'
# Scratch TODO

## Task Order

placeholder (replaced by the script under test)

## Tasks

placeholder (left alone by the script under test)
TODOEOF
  echo "$scratch"
}

# mk_fixture <num> <status> <desc> <title> <topic> <deps_json> -- emits one compact fixture
# project JSON object. desc/title/topic: pass "" to OMIT that field entirely (required for
# correct `//` fallback testing -- an empty jq string is truthy under `//` and would never fall
# through).
mk_fixture() {
  local num="$1" status="$2" desc="$3" title="$4" topic="$5" deps="${6:-[]}"
  jq -nc --argjson num "$num" --arg status "$status" --arg desc "$desc" --arg title "$title" \
    --arg topic "$topic" --argjson deps "$deps" \
    '{project_number: $num, project_name: ("fixture-project-" + ($num|tostring)),
      status: $status, dependencies: $deps}
     + (if $desc  != "" then {description: $desc}  else {} end)
     + (if $title != "" then {title: $title}       else {} end)
     + (if $topic != "" then {topic: $topic}        else {} end)'
}

# build_state <scratch> <active_topics_json> <fixture_json...> -- writes state.json from
# fixture project objects (one per remaining positional arg).
build_state() {
  local scratch="$1" active_topics="$2"; shift 2
  printf '%s\n' "$@" | jq -s --argjson at "$active_topics" \
    '{next_project_number: 9999, active_topics: $at, active_projects: .}' \
    > "$scratch/specs/state.json"
}

# run_gto <scratch> -- runs the script under test in --update-todo mode against the scratch
# fixture. stderr captured to a file (warnings about undeclared/uncategorized topics are
# expected noise from some fixtures, not failures).
run_gto() {
  local scratch="$1"
  bash "$scratch/.claude/scripts/generate-task-order.sh" \
    --update-todo "$scratch/specs/TODO.md" "$scratch/specs/state.json" \
    >"$scratch/stdout.log" 2>"$scratch/stderr.log"
}

# extract_grouped <scratch> -- prints the "Grouped by Topic" section body (heading line through
# the line before the next "## Tasks" heading).
extract_grouped() {
  local scratch="$1"
  awk '/^## Tasks$/{exit} /^\*\*Grouped by Topic\*\*/{flag=1} flag' "$scratch/specs/TODO.md"
}

# line_for_fixture <text> <num> -- prints the single line in <text> that begins with
# "<num> [" (the top-level rendering of that fixture; tolerates a leading tree-prefix on nested
# lines by anchoring on the number immediately preceded only by whitespace/tree glyphs).
line_for_fixture() {
  local text="$1" num="$2"
  printf '%s\n' "$text" | grep -E "(^|[^0-9])${num} \["
}

# has_markup_hazard <text> -- exit 0 if any line still carries a stripped-class character
# (backtick, asterisk, underscore, or open-bracket). Declared for documentation/reuse even where
# a case checks a narrower symbol directly.
has_markup_hazard() {
  grep -qE '[`*_[]'
}

# check_word_boundary_truncation <original> <result> <budget> -- generic, algorithm-independent
# correctness check: result must not exceed budget; if result ends with the truncation marker
# ("..."), the text before the marker must be an exact prefix of <original> whose next character
# in <original> is either end-of-string or a space (i.e. the cut landed on a word boundary, not
# mid-word); if result does NOT end with the marker, result must equal <original> verbatim.
check_word_boundary_truncation() {
  local original="$1" result="$2" budget="$3"
  if [[ ${#result} -gt $budget ]]; then
    echo "result exceeds budget: ${#result} > $budget"
    return 1
  fi
  if [[ "$result" == *"..." ]]; then
    local core="${result%...}"
    local prefix_in_original="${original:0:${#core}}"
    if [[ "$prefix_in_original" != "$core" ]]; then
      echo "marked core is not a prefix of the original text"
      return 1
    fi
    local next_char="${original:${#core}:1}"
    if [[ -n "$next_char" && "$next_char" != " " ]]; then
      echo "cut landed mid-word (next original char after cut: '${next_char}')"
      return 1
    fi
  else
    if [[ "$result" != "$original" ]]; then
      echo "unmarked result does not equal the original text verbatim"
      return 1
    fi
  fi
  return 0
}

# marker_count <text> -- number of non-overlapping "..." occurrences in <text> (used to detect a
# doubled truncation marker after the second, cross-topic slice).
marker_count() {
  local text="$1"
  printf '%s' "$text" | grep -o '\.\.\.' | wc -l
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Case group 1: markdown safety
# ═════════════════════════════════════════════════════════════════════════════════════════════

PREFIX64="$(printf 'x%.0s' $(seq 1 64))"
if [[ ${#PREFIX64} -ne 64 ]]; then
  fail "case-group-1 setup: PREFIX64 is ${#PREFIX64} chars, expected 64 -- fixture invalid"
fi

# --- 1a: backtick placed EXACTLY at the cut boundary (character 65 of 65) ---
{
  desc="${PREFIX64}\`inline code that closes well beyond the cut boundary\` trailing prose padding the source past the sixty five character budget for certain"
  naive="${desc:0:65}"
  naive_bt_count=$(printf '%s' "$naive" | grep -o '`' | wc -l)
  if (( naive_bt_count % 2 == 0 )); then
    fail "1a-fixture-adversarial: naive 65-char slice has an EVEN backtick count ($naive_bt_count) -- fixture does not actually exercise the bug"
  else
    pass "1a-fixture-adversarial: naive 65-char slice has an odd backtick count ($naive_bt_count), confirming the fixture is adversarial"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 901 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 901)"
  if [[ -z "$line" ]]; then
    fail "1a-actual: no rendered line found for fixture 901"
  else
    bt_count=$(printf '%s' "$line" | grep -o '`' | wc -l)
    if (( bt_count % 2 == 0 )); then
      pass "1a-actual: rendered line has an even backtick count ($bt_count) -- markdown-safe: $line"
    else
      fail "1a-actual: rendered line has an ODD backtick count ($bt_count) -- unsafe: $line"
    fi
  fi
}

# --- 1b: unbalanced asterisk at the cut boundary (companion case) ---
{
  desc="${PREFIX64}*bold text spanning well beyond the cut boundary* trailing prose padding the source past budget for certain and then some more"
  naive="${desc:0:65}"
  naive_star_count=$(printf '%s' "$naive" | grep -o '\*' | wc -l)
  if (( naive_star_count % 2 == 0 )); then
    fail "1b-fixture-adversarial: naive 65-char slice has an EVEN asterisk count ($naive_star_count) -- fixture does not exercise the bug"
  else
    pass "1b-fixture-adversarial: naive 65-char slice has an odd asterisk count ($naive_star_count), confirming the fixture is adversarial"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 902 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 902)"
  if [[ -z "$line" ]]; then
    fail "1b-actual: no rendered line found for fixture 902"
  else
    star_count=$(printf '%s' "$line" | grep -o '\*' | wc -l)
    if (( star_count % 2 == 0 )); then
      pass "1b-actual: rendered line has an even asterisk count ($star_count)"
    else
      fail "1b-actual: rendered line has an ODD asterisk count ($star_count) -- unsafe: $line"
    fi
  fi
}

# --- 1c: unclosed bracket at the cut boundary (companion case) ---
{
  desc="${PREFIX64}[reference label that never closes and runs on well past the cut boundary without a matching close bracket anywhere nearby at all"
  naive="${desc:0:65}"
  naive_has_open_bracket=0
  [[ "$naive" == *"["* ]] && naive_has_open_bracket=1
  naive_close_count=$(printf '%s' "$naive" | grep -o ']' | wc -l)
  if [[ "$naive_has_open_bracket" -eq 1 && "$naive_close_count" -eq 0 ]]; then
    pass "1c-fixture-adversarial: naive 65-char slice contains an unclosed '[' with no matching ']', confirming the fixture is adversarial"
  else
    fail "1c-fixture-adversarial: naive 65-char slice does not contain an orphaned '[' -- fixture does not exercise the bug"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 903 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 903)"
  if [[ -z "$line" ]]; then
    fail "1c-actual: no rendered line found for fixture 903"
  else
    # Isolate the description field: the whole line legitimately contains "[NOT STARTED]",
    # so the bracket check must exclude the leading "<num> [STATUS] — " prefix.
    rendered_desc="${line#*] }"
    rendered_desc="${rendered_desc#$'\xe2\x80\x94 '}"
    if printf '%s' "$rendered_desc" | grep -q '\['; then
      fail "1c-actual: rendered description still carries an open bracket -- unsafe: $line"
    else
      pass "1c-actual: rendered description carries no open bracket"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Case group 2: title preference
# ═════════════════════════════════════════════════════════════════════════════════════════════

# --- 2a: fixture with both .title and .description -- emitted line must derive from the title ---
{
  title="Slim the fixture generator to a manageable and readable size"
  desc="A deliberately unrelated and much longer description that would only ever be shown here if the generator incorrectly preferred description text over an available title"
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 904 not_started "$desc" "$title" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 904)"
  if [[ -z "$line" ]]; then
    fail "2a-actual: no rendered line found for fixture 904"
  elif [[ "$line" == *"Slim the fixture generator"* && "$line" != *"deliberately unrelated"* ]]; then
    pass "2a-actual: line derives from .title, not .description: $line"
  else
    fail "2a-actual: line did not prefer .title over .description: $line"
  fi
}

# --- 2b: fixture with .description only (no .title) -- still renders, not degraded ---
{
  desc="A perfectly ordinary description with no title present on this fixture at all"
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 905 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 905)"
  if [[ -z "$line" ]]; then
    fail "2b-actual: no rendered line found for fixture 905"
  elif [[ "$line" == *"ordinary description"* ]]; then
    pass "2b-actual: title-less fixture still renders from .description: $line"
  else
    fail "2b-actual: title-less fixture rendering degraded or empty: $line"
  fi
}

# --- 2c: fixture with neither .title nor .description -- falls back to .project_name ---
{
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 906 not_started "" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 906)"
  if [[ -z "$line" ]]; then
    fail "2c-actual: no rendered line found for fixture 906"
  elif [[ "$line" == *"fixture-project-906"* ]]; then
    pass "2c-actual: line falls back to .project_name when neither .title nor .description exist: $line"
  else
    fail "2c-actual: line did not fall back to .project_name: $line"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Case group 3: budget and word-boundary truncation
# ═════════════════════════════════════════════════════════════════════════════════════════════

# --- 3a: source exceeds the 65-char budget -- must truncate at a word boundary with a marker ---
{
  desc="alpha bravo charlie delta echo foxtrot golf hotel india juliett kilo lima mike november oscar papa quebec romeo sierra tango"
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 907 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 907)"
  if [[ -z "$line" ]]; then
    fail "3a-actual: no rendered line found for fixture 907"
  else
    # Isolate just the description field of the rendered line (after the "] — " separator).
    rendered_desc="${line#*] }"
    rendered_desc="${rendered_desc#$'\xe2\x80\x94 '}"
    if [[ "$rendered_desc" != *"..." ]]; then
      fail "3a-actual: over-budget source was not marked as truncated: $line"
    else
      if err="$(check_word_boundary_truncation "$desc" "$rendered_desc" 65)"; then
        pass "3a-actual: over-budget source truncated at a word boundary within budget, with marker: $line"
      else
        fail "3a-actual: word-boundary/budget check failed ($err): $line"
      fi
    fi
  fi
}

# --- 3b: source under the budget -- untouched, no marker ---
{
  desc="a short fixture description"
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 908 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 908)"
  if [[ -z "$line" ]]; then
    fail "3b-actual: no rendered line found for fixture 908"
  elif [[ "$line" == *"..."* ]]; then
    fail "3b-actual: under-budget line unexpectedly carries a truncation marker: $line"
  elif [[ "$line" == *"$desc"* ]]; then
    pass "3b-actual: under-budget line is untouched and carries no marker: $line"
  else
    fail "3b-actual: under-budget line does not contain the original description: $line"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Case group 4: second slice site (cross-topic "(see above)" annotation, ~line 592)
#
# Recipe (the only route through the live code that reaches the 40-char short_desc branch):
# an Uncategorized (topic-less) fixture U has no dependencies, so it is printed as an
# Uncategorized root at depth 0. U's successor T carries its OWN topic ("Alpha"), which was
# already printed under its own "Alpha" section earlier (topics_to_render is processed before
# Uncategorized). Because the skip-check that would normally block a cross-topic successor only
# fires when _current_section_topic is non-empty, and Uncategorized's _current_section_topic is
# "", T's recursion into U's subtree is NOT skipped -- so T is revisited at depth>0 with
# _globally_visited[T] already true and its own topic ("Alpha") differing from the current
# ("") section, landing in exactly the short_desc (40-char) branch.
# ═════════════════════════════════════════════════════════════════════════════════════════════

# --- 4a: primary description is short (<=65, unmarked) -- the 40-char cut alone must truncate ---
{
  t_desc="a moderately long cross topic description text field"  # > 40 chars, <= 65 chars
  scratch="$(build_scratch)"
  build_state "$scratch" '["Alpha"]' \
    "$(mk_fixture 909 not_started "$t_desc" "" "Alpha" '[910]')" \
    "$(mk_fixture 910 not_started "an uncategorized bridge fixture with no topic of its own" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  see_above_line="$(printf '%s\n' "$grouped" | grep -E '\(see above\)$' | grep 'Alpha:' || true)"
  if [[ -z "$see_above_line" ]]; then
    fail "4a-actual: no cross-topic '(Alpha: ...)' (see above) line found -- recipe did not fire; grouped output was: $grouped"
  else
    short="${see_above_line#*Alpha: }"
    short="${short% (see above)}"
    short="${short%)}"
    if (( ${#short} > 40 )); then
      fail "4a-actual: cross-topic short_desc exceeds the 40-char budget (${#short} chars): $see_above_line"
    else
      pass "4a-actual: cross-topic short_desc respects the 40-char budget: $see_above_line"
    fi
    if [[ "$short" == *"..." ]]; then
      core="${short%...}"
      prefix_in_original="${t_desc:0:${#core}}"
      next_char="${t_desc:${#core}:1}"
      if [[ "$prefix_in_original" == "$core" && ( -z "$next_char" || "$next_char" == " " ) ]]; then
        pass "4a-actual: cross-topic truncation lands on a word boundary with a marker"
      else
        fail "4a-actual: cross-topic truncation cut mid-word: $see_above_line"
      fi
    else
      fail "4a-actual: expected the primary description to be truncated by the 40-char secondary cut, but no marker present: $see_above_line"
    fi
  fi
}

# --- 4b: primary description is long (>65, already marked) -- the 40-char cut must not double
#     the marker or re-derive nonsense from an already-truncated value ---
{
  t_desc="alpha bravo charlie delta echo foxtrot golf hotel india juliett kilo lima mike november oscar papa quebec romeo sierra tango uniform victor whiskey"
  scratch="$(build_scratch)"
  build_state "$scratch" '["Alpha"]' \
    "$(mk_fixture 911 not_started "$t_desc" "" "Alpha" '[912]')" \
    "$(mk_fixture 912 not_started "another uncategorized bridge fixture with no topic" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  see_above_line="$(printf '%s\n' "$grouped" | grep -E '\(see above\)$' | grep 'Alpha:' || true)"
  if [[ -z "$see_above_line" ]]; then
    fail "4b-actual: no cross-topic '(Alpha: ...)' (see above) line found; grouped output was: $grouped"
  else
    short="${see_above_line#*Alpha: }"
    short="${short% (see above)}"
    short="${short%)}"
    markers=$(marker_count "$short")
    if [[ "$markers" -gt 1 ]]; then
      fail "4b-actual: cross-topic short_desc carries a DOUBLED marker ($markers occurrences): $see_above_line"
    else
      pass "4b-actual: cross-topic short_desc carries at most one truncation marker ($markers occurrence(s))"
    fi
    if (( ${#short} > 40 )); then
      fail "4b-actual: cross-topic short_desc exceeds the 40-char budget (${#short} chars): $see_above_line"
    else
      pass "4b-actual: cross-topic short_desc respects the 40-char budget even though the primary slice already truncated it: $see_above_line"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Environment / isolation checks
# ═════════════════════════════════════════════════════════════════════════════════════════════

{
  REAL_TODO_SUM_AFTER=""
  REAL_STATE_SUM_AFTER=""
  [[ -f "$REAL_TODO" ]] && REAL_TODO_SUM_AFTER="$(sha256sum "$REAL_TODO" | awk '{print $1}')"
  [[ -f "$REAL_STATE" ]] && REAL_STATE_SUM_AFTER="$(sha256sum "$REAL_STATE" | awk '{print $1}')"
  if [[ "$REAL_TODO_SUM_BEFORE" == "$REAL_TODO_SUM_AFTER" && "$REAL_STATE_SUM_BEFORE" == "$REAL_STATE_SUM_AFTER" ]]; then
    pass "isolation: real specs/TODO.md and specs/state.json are unchanged after the full run"
  else
    fail "isolation: real specs/TODO.md or specs/state.json changed during this suite's run"
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════════════════════════════

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
