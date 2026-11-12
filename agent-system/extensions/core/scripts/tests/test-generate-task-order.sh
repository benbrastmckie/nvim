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
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- mode=source-store resolution for the file under test ---
GTO_SRC="$(common_test_resolve_subject "generate-task-order.sh" "source-store" \
  "$DEPLOY_SCRIPTS_SRC/generate-task-order.sh" "$SOURCE_STORE_SCRIPTS/generate-task-order.sh")" || exit 2
common_test_declare_subject "$GTO_SRC"

# --- mode=deploy-tree-first resolution for the two unchanged dependencies ---
GUARD_SRC="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/deploy-root-guard.sh" "$SOURCE_STORE_SCRIPTS/deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SRC"
COMMON_SRC="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/common.sh" "$SOURCE_STORE_SCRIPTS/lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SRC"

PASSED=0
FAILED=0

common_test_info "Under test (source-store-first): $GTO_SRC"
common_test_info "Dependency (deploy-first): $GUARD_SRC"
common_test_info "Dependency (deploy-first): $COMMON_SRC"

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

# build_state_goal <scratch> <active_topics_json> <active_goal_json> <fixture_json...> --
# writes state.json from fixture project objects (one per remaining positional arg).
# <active_goal_json> is a raw JSON value: the literal string `null` omits the `active_goal` key
# entirely, `""` writes an empty string, any other JSON string writes it verbatim.
build_state_goal() {
  local scratch="$1" active_topics="$2" active_goal_json="$3"; shift 3
  printf '%s\n' "$@" | jq -s --argjson at "$active_topics" --argjson ag "$active_goal_json" \
    '{next_project_number: 9999, active_topics: $at, active_projects: .}
     + (if $ag == null then {} else {active_goal: $ag} end)' \
    > "$scratch/specs/state.json"
}

# build_state <scratch> <active_topics_json> <fixture_json...> -- writes state.json from
# fixture project objects (one per remaining positional arg). Thin wrapper over
# build_state_goal with active_goal omitted, so every pre-existing call site is untouched.
build_state() {
  local scratch="$1" active_topics="$2"; shift 2
  build_state_goal "$scratch" "$active_topics" 'null' "$@"
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

# run_gto_print <scratch> -- runs the script under test in --print mode against the scratch
# fixture. No positional file arguments: print mode resolves TODO_FILE/STATE_FILE from
# PROJECT_ROOT, which common_repo_root derives from the scratch tree's own .claude/scripts
# location, so the scratch fixture is already the target. stdout/stderr captured to files.
run_gto_print() {
  local scratch="$1"
  bash "$scratch/.claude/scripts/generate-task-order.sh" \
    --print \
    >"$scratch/print-stdout.log" 2>"$scratch/print-stderr.log"
}

# goal_line_from <file-or-text-source> -- prints the captured group of the first
# "^**Goal**: (.+)$" line within the "## Task Order" section of <source>, or empty if none.
# <source> may be a path to an existing file (its contents are read) or raw text passed
# directly (used against print-mode stdout, which has no backing file).
goal_line_from() {
  local source="$1" text
  if [[ -f "$source" ]]; then
    text="$(cat "$source")"
  else
    text="$source"
  fi
  awk '
    /^## Task Order$/ { insec=1; next }
    insec && /^## / { exit }
    insec && /^\*\*Goal\*\*: / { sub(/^\*\*Goal\*\*: /, ""); print; exit }
  ' <<< "$text"
}

# seed_goal_line <scratch> <text> -- inserts a "**Goal**: <text>" line into the scratch
# TODO.md's "## Task Order" section, for the preserve-behavior cases. build_scratch()'s default
# fixture is left Goal-line-free; call this only from cases that need a pre-existing hand-written
# line to preserve.
seed_goal_line() {
  local scratch="$1" text="$2" todo_file
  todo_file="$scratch/specs/TODO.md"
  awk -v goal="$text" '
    /^## Task Order$/ { print; print "**Goal**: " goal; next }
    { print }
  ' "$todo_file" > "$todo_file.tmp" && mv "$todo_file.tmp" "$todo_file"
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

# has_markup_hazard <text> -- exit 0 if any line still carries a raw markup-hazard character
# (backtick, asterisk, underscore, or open-bracket). Declared for documentation/reuse even where
# a case checks a narrower symbol directly. NOTE: backtick, asterisk, and open-bracket are
# STRIPPED (deleted) by build_graph()'s markup pass, so their raw presence in rendered output is
# always a hazard. Underscore is the one exception -- it is ESCAPED (gsub("_"; "\_")) rather
# than deleted, so a raw underscore is EXPECTED and SAFE in correctly-rendered output (it always
# appears as the two-character sequence "\_", never bare). This helper has zero call sites in
# this suite today; a future caller must not treat a bare underscore match as a hazard without
# also checking that it is not preceded by a backslash.
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
  common_test_fail "case-group-1 setup: PREFIX64 is ${#PREFIX64} chars, expected 64 -- fixture invalid"
fi

# --- 1a: backtick placed EXACTLY at the cut boundary (character 65 of 65) ---
{
  desc="${PREFIX64}\`inline code that closes well beyond the cut boundary\` trailing prose padding the source past the sixty five character budget for certain"
  naive="${desc:0:65}"
  naive_bt_count=$(printf '%s' "$naive" | grep -o '`' | wc -l)
  if (( naive_bt_count % 2 == 0 )); then
    common_test_fail "1a-fixture-adversarial: naive 65-char slice has an EVEN backtick count ($naive_bt_count) -- fixture does not actually exercise the bug"
  else
    common_test_pass "1a-fixture-adversarial: naive 65-char slice has an odd backtick count ($naive_bt_count), confirming the fixture is adversarial"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 901 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 901)"
  if [[ -z "$line" ]]; then
    common_test_fail "1a-actual: no rendered line found for fixture 901"
  else
    bt_count=$(printf '%s' "$line" | grep -o '`' | wc -l)
    if (( bt_count % 2 == 0 )); then
      common_test_pass "1a-actual: rendered line has an even backtick count ($bt_count) -- markdown-safe: $line"
    else
      common_test_fail "1a-actual: rendered line has an ODD backtick count ($bt_count) -- unsafe: $line"
    fi
  fi
}

# --- 1b: unbalanced asterisk at the cut boundary (companion case) ---
{
  desc="${PREFIX64}*bold text spanning well beyond the cut boundary* trailing prose padding the source past budget for certain and then some more"
  naive="${desc:0:65}"
  naive_star_count=$(printf '%s' "$naive" | grep -o '\*' | wc -l)
  if (( naive_star_count % 2 == 0 )); then
    common_test_fail "1b-fixture-adversarial: naive 65-char slice has an EVEN asterisk count ($naive_star_count) -- fixture does not exercise the bug"
  else
    common_test_pass "1b-fixture-adversarial: naive 65-char slice has an odd asterisk count ($naive_star_count), confirming the fixture is adversarial"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 902 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 902)"
  if [[ -z "$line" ]]; then
    common_test_fail "1b-actual: no rendered line found for fixture 902"
  else
    star_count=$(printf '%s' "$line" | grep -o '\*' | wc -l)
    if (( star_count % 2 == 0 )); then
      common_test_pass "1b-actual: rendered line has an even asterisk count ($star_count)"
    else
      common_test_fail "1b-actual: rendered line has an ODD asterisk count ($star_count) -- unsafe: $line"
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
    common_test_pass "1c-fixture-adversarial: naive 65-char slice contains an unclosed '[' with no matching ']', confirming the fixture is adversarial"
  else
    common_test_fail "1c-fixture-adversarial: naive 65-char slice does not contain an orphaned '[' -- fixture does not exercise the bug"
  fi

  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 903 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 903)"
  if [[ -z "$line" ]]; then
    common_test_fail "1c-actual: no rendered line found for fixture 903"
  else
    # Isolate the description field: the whole line legitimately contains "[NOT STARTED]",
    # so the bracket check must exclude the leading "<num> [STATUS] — " prefix.
    rendered_desc="${line#*] }"
    rendered_desc="${rendered_desc#$'\xe2\x80\x94 '}"
    if printf '%s' "$rendered_desc" | grep -q '\['; then
      common_test_fail "1c-actual: rendered description still carries an open bracket -- unsafe: $line"
    else
      common_test_pass "1c-actual: rendered description carries no open bracket"
    fi
  fi
}

# --- 1d: underscore SURVIVES (escaped, not deleted) -- the "parenttask" renderer defect ---
{
  desc="a snake_case project_name style description with an embedded_underscore in the middle"
  scratch="$(build_scratch)"
  build_state "$scratch" '[]' "$(mk_fixture 913 not_started "$desc" "" "" '[]')"
  run_gto "$scratch"
  grouped="$(extract_grouped "$scratch")"
  line="$(line_for_fixture "$grouped" 913)"
  if [[ -z "$line" ]]; then
    common_test_fail "1d-actual: no rendered line found for fixture 913"
  else
    rendered_desc="${line#*] }"
    rendered_desc="${rendered_desc#$'\xe2\x80\x94 '}"
    if [[ "$rendered_desc" == *'\_'* ]]; then
      common_test_pass "1d-actual: rendered description preserves the underscore as an escaped '\\_' rather than deleting it: $line"
    else
      common_test_fail "1d-actual: rendered description lost the underscore (expected an escaped '\\_'): $line"
    fi
    # Budget/word-boundary invariant: escaping lengthens the string by one character per
    # underscore, so the invariant must still hold after escaping, not just before it.
    expected_escaped="${desc//_/\\_}"
    if err="$(check_word_boundary_truncation "$expected_escaped" "$rendered_desc" 65)"; then
      common_test_pass "1d-actual: escaped description respects the 65-char budget/word-boundary invariant"
    else
      common_test_fail "1d-actual: budget/word-boundary check failed ($err): $line"
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
    common_test_fail "2a-actual: no rendered line found for fixture 904"
  elif [[ "$line" == *"Slim the fixture generator"* && "$line" != *"deliberately unrelated"* ]]; then
    common_test_pass "2a-actual: line derives from .title, not .description: $line"
  else
    common_test_fail "2a-actual: line did not prefer .title over .description: $line"
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
    common_test_fail "2b-actual: no rendered line found for fixture 905"
  elif [[ "$line" == *"ordinary description"* ]]; then
    common_test_pass "2b-actual: title-less fixture still renders from .description: $line"
  else
    common_test_fail "2b-actual: title-less fixture rendering degraded or empty: $line"
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
    common_test_fail "2c-actual: no rendered line found for fixture 906"
  elif [[ "$line" == *"fixture-project-906"* ]]; then
    common_test_pass "2c-actual: line falls back to .project_name when neither .title nor .description exist: $line"
  else
    common_test_fail "2c-actual: line did not fall back to .project_name: $line"
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
    common_test_fail "3a-actual: no rendered line found for fixture 907"
  else
    # Isolate just the description field of the rendered line (after the "] — " separator).
    rendered_desc="${line#*] }"
    rendered_desc="${rendered_desc#$'\xe2\x80\x94 '}"
    if [[ "$rendered_desc" != *"..." ]]; then
      common_test_fail "3a-actual: over-budget source was not marked as truncated: $line"
    else
      if err="$(check_word_boundary_truncation "$desc" "$rendered_desc" 65)"; then
        common_test_pass "3a-actual: over-budget source truncated at a word boundary within budget, with marker: $line"
      else
        common_test_fail "3a-actual: word-boundary/budget check failed ($err): $line"
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
    common_test_fail "3b-actual: no rendered line found for fixture 908"
  elif [[ "$line" == *"..."* ]]; then
    common_test_fail "3b-actual: under-budget line unexpectedly carries a truncation marker: $line"
  elif [[ "$line" == *"$desc"* ]]; then
    common_test_pass "3b-actual: under-budget line is untouched and carries no marker: $line"
  else
    common_test_fail "3b-actual: under-budget line does not contain the original description: $line"
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
    common_test_fail "4a-actual: no cross-topic '(Alpha: ...)' (see above) line found -- recipe did not fire; grouped output was: $grouped"
  else
    short="${see_above_line#*Alpha: }"
    short="${short% (see above)}"
    short="${short%)}"
    if (( ${#short} > 40 )); then
      common_test_fail "4a-actual: cross-topic short_desc exceeds the 40-char budget (${#short} chars): $see_above_line"
    else
      common_test_pass "4a-actual: cross-topic short_desc respects the 40-char budget: $see_above_line"
    fi
    if [[ "$short" == *"..." ]]; then
      core="${short%...}"
      prefix_in_original="${t_desc:0:${#core}}"
      next_char="${t_desc:${#core}:1}"
      if [[ "$prefix_in_original" == "$core" && ( -z "$next_char" || "$next_char" == " " ) ]]; then
        common_test_pass "4a-actual: cross-topic truncation lands on a word boundary with a marker"
      else
        common_test_fail "4a-actual: cross-topic truncation cut mid-word: $see_above_line"
      fi
    else
      common_test_fail "4a-actual: expected the primary description to be truncated by the 40-char secondary cut, but no marker present: $see_above_line"
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
    common_test_fail "4b-actual: no cross-topic '(Alpha: ...)' (see above) line found; grouped output was: $grouped"
  else
    short="${see_above_line#*Alpha: }"
    short="${short% (see above)}"
    short="${short%)}"
    markers=$(marker_count "$short")
    if [[ "$markers" -gt 1 ]]; then
      common_test_fail "4b-actual: cross-topic short_desc carries a DOUBLED marker ($markers occurrences): $see_above_line"
    else
      common_test_pass "4b-actual: cross-topic short_desc carries at most one truncation marker ($markers occurrence(s))"
    fi
    if (( ${#short} > 40 )); then
      common_test_fail "4b-actual: cross-topic short_desc exceeds the 40-char budget (${#short} chars): $see_above_line"
    else
      common_test_pass "4b-actual: cross-topic short_desc respects the 40-char budget even though the primary slice already truncated it: $see_above_line"
    fi
  fi
}

# ═════════════════════════════════════════════════════════════════════════════════════════════
# Case group 5: active_goal precedence chain (Outcomes #1, #4) -- --goal override > non-empty
# state.json active_goal > existing TODO.md Goal line > omit, applied identically in
# --update-todo and --print.
# ═════════════════════════════════════════════════════════════════════════════════════════════

# --- 5a: active_goal set, no prior Goal line -- --update-todo must render it ---
{
  g_text="Finish the widget migration"
  scratch="$(build_scratch)"
  build_state_goal "$scratch" '[]' "$(jq -n --arg g "$g_text" '$g')" \
    "$(mk_fixture 920 not_started "fixture for case 5a" "" "" '[]')"
  run_gto "$scratch"
  rendered="$(goal_line_from "$scratch/specs/TODO.md")"
  if [[ "$rendered" == "$g_text" ]]; then
    common_test_pass "5a-actual: --update-todo renders the Goal line from active_goal when no prior Goal line exists: $rendered"
  else
    common_test_fail "5a-actual: --update-todo did not render active_goal as the Goal line (expected '$g_text', got '$rendered')"
  fi
}

# --- 5b: same condition under --print -- the mode the motivating caller actually reaches ---
{
  g_text="Finish the widget migration"
  scratch="$(build_scratch)"
  build_state_goal "$scratch" '[]' "$(jq -n --arg g "$g_text" '$g')" \
    "$(mk_fixture 921 not_started "fixture for case 5b" "" "" '[]')"
  run_gto_print "$scratch"
  rendered="$(goal_line_from "$scratch/print-stdout.log")"
  if [[ "$rendered" == "$g_text" ]]; then
    common_test_pass "5b-actual: --print renders the Goal line from active_goal when no prior Goal line exists: $rendered"
  else
    common_test_fail "5b-actual: --print did not render active_goal as the Goal line (expected '$g_text', got '$rendered')"
  fi
}

# --- 5c: --goal override wins over a non-empty active_goal; active_goal text leaks nowhere ---
{
  g_text="SHOULD_NOT_RENDER_ACTIVE_GOAL_TEXT_5c"
  override_text="Explicit override"
  scratch="$(build_scratch)"
  build_state_goal "$scratch" '[]' "$(jq -n --arg g "$g_text" '$g')" \
    "$(mk_fixture 922 not_started "fixture for case 5c" "" "" '[]')"
  bash "$scratch/.claude/scripts/generate-task-order.sh" \
    --update-todo "$scratch/specs/TODO.md" "$scratch/specs/state.json" --goal "$override_text" \
    >"$scratch/stdout.log" 2>"$scratch/stderr.log"
  rendered="$(goal_line_from "$scratch/specs/TODO.md")"
  if [[ "$rendered" == "$override_text" ]]; then
    common_test_pass "5c-actual: --goal override wins over a non-empty active_goal: $rendered"
  else
    common_test_fail "5c-actual: --goal override did not win (expected '$override_text', got '$rendered')"
  fi
  if grep -q "$g_text" "$scratch/specs/TODO.md"; then
    common_test_fail "5c-actual: active_goal text leaked into TODO.md despite --goal override"
  else
    common_test_pass "5c-actual: active_goal text does not appear anywhere in the output"
  fi
}

# --- 5d: active_goal absent (null) plus a seeded hand-written Goal line -- the seeded line
#     survives in BOTH modes; the print half is the preserve-across-regeneration guarantee that
#     does not hold today ---
{
  seeded="Pre-existing hand-written goal line"

  scratch="$(build_scratch)"
  seed_goal_line "$scratch" "$seeded"
  build_state "$scratch" '[]' "$(mk_fixture 923 not_started "fixture for case 5d update" "" "" '[]')"
  run_gto "$scratch"
  rendered_update="$(goal_line_from "$scratch/specs/TODO.md")"
  if [[ "$rendered_update" == "$seeded" ]]; then
    common_test_pass "5d-actual: --update-todo preserves a hand-written Goal line when active_goal is absent: $rendered_update"
  else
    common_test_fail "5d-actual: --update-todo did not preserve the hand-written Goal line (expected '$seeded', got '$rendered_update')"
  fi

  scratch2="$(build_scratch)"
  seed_goal_line "$scratch2" "$seeded"
  build_state "$scratch2" '[]' "$(mk_fixture 924 not_started "fixture for case 5d print" "" "" '[]')"
  run_gto_print "$scratch2"
  rendered_print="$(goal_line_from "$scratch2/print-stdout.log")"
  if [[ "$rendered_print" == "$seeded" ]]; then
    common_test_pass "5d-actual: --print preserves a hand-written Goal line when active_goal is absent: $rendered_print"
  else
    common_test_fail "5d-actual: --print did not preserve the hand-written Goal line (expected '$seeded', got '$rendered_print')"
  fi
}

# --- 5e: active_goal = "" plus the same seeded line -- empty string treated as absent, in
#     BOTH modes ---
{
  seeded="Pre-existing hand-written goal line for case 5e"

  scratch="$(build_scratch)"
  seed_goal_line "$scratch" "$seeded"
  build_state_goal "$scratch" '[]' '""' \
    "$(mk_fixture 925 not_started "fixture for case 5e update" "" "" '[]')"
  run_gto "$scratch"
  rendered_update="$(goal_line_from "$scratch/specs/TODO.md")"
  if [[ "$rendered_update" == "$seeded" ]]; then
    common_test_pass "5e-actual: --update-todo treats an empty-string active_goal as absent and preserves the hand-written Goal line: $rendered_update"
  else
    common_test_fail "5e-actual: --update-todo did not preserve the hand-written Goal line with empty active_goal (expected '$seeded', got '$rendered_update')"
  fi

  scratch2="$(build_scratch)"
  seed_goal_line "$scratch2" "$seeded"
  build_state_goal "$scratch2" '[]' '""' \
    "$(mk_fixture 926 not_started "fixture for case 5e print" "" "" '[]')"
  run_gto_print "$scratch2"
  rendered_print="$(goal_line_from "$scratch2/print-stdout.log")"
  if [[ "$rendered_print" == "$seeded" ]]; then
    common_test_pass "5e-actual: --print treats an empty-string active_goal as absent and preserves the hand-written Goal line: $rendered_print"
  else
    common_test_fail "5e-actual: --print did not preserve the hand-written Goal line with empty active_goal (expected '$seeded', got '$rendered_print')"
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
    common_test_pass "isolation: real specs/TODO.md and specs/state.json are unchanged after the full run"
  else
    common_test_fail "isolation: real specs/TODO.md or specs/state.json changed during this suite's run"
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
