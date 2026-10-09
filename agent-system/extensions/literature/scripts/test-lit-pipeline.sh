#!/usr/bin/env bash
# test-lit-pipeline.sh - Validate the full --lit pipeline wiring for CSLib tasks
#
# Usage: .claude/scripts/test-lit-pipeline.sh [--runtime]
#
# Runs static checks (Sections A-D) by default. Pass --runtime to also execute
# Section E: a smoke test that exercises literature-briefing.sh with mock fixtures.
#
# Must be run from the project root (the directory containing .claude/).
#
# Exit 0 when all checks pass, exit 1 when any check fails.
#
# Sections:
#   A - Script existence and syntax (literature-briefing.sh, literature-create-setup-task.sh)
#   B - CSLib skill Stage 4a wiring (4 skills: lit_context init, briefing call, lit_flag gate)
#   C - CSLib agent acknowledgment (4 agents: <literature-briefing> reference)
#   D - General skill interactive detection (skill-orchestrate)
#   E - Runtime smoke test with mock fixtures (opt-in via --runtime)
#   F - id/FTS namespace unification regression tests (opt-in via --runtime): ingest-then-brief
#       shape, --validate schema-shape/divergence detection, project-filtered-search bridge.
#       A sibling to Section E (not an extension of it) -- needs its own sqlite fixture and a
#       SKILL.md bash-block extraction Section E's infra has no use for. Resolves the scripts
#       and SKILL.md it exercises relative to its OWN SCRIPT_DIR (never the hardcoded deployed
#       .claude/ path Section E uses), so it always tests whichever copy -- source-store or
#       deployed -- it is itself being run from.
#   G - coverage-marker resolution-failure regression tests (opt-in via --runtime): a
#       deliberately-unresolvable doc_id drives the lit-coverage marker's requested=/resolved=/
#       skipped=/skip_rate= fields and the sparse=true skip-rate disjunct, instead of the marker
#       falsely reporting sparse=false or (in the total-failure case) emitting no marker at all.
#       A sibling to Section F, following its fixture idiom.
#   H - topic-scoped coverage-delta guard regression tests (opt-in via --runtime): a sub-index
#       that clears the absolute sparsity floor still downgrades literature-lit-flag-resolve.sh's
#       directive to SPARSE_PROMPT_NEEDED, and literature-briefing.sh's marker/banner surface the
#       same delta, when the global index holds topic-matching documents absent from the
#       sub-index (H1); a non-matching query stays silent (H2, the anti-alarm-fatigue guarantee);
#       chunk children never inflate the delta (H3); an unqueried briefing reports
#       delta_checked=false rather than a false zero (H4); a missing LITERATURE_DIR still
#       fails open to SUBINDEX_PRESENT (H5); LITERATURE_COVERAGE_GAP_MIN's `>=` (not `>`)
#       boundary is exercised exactly at and one below the threshold (H6). A sibling to
#       Section G, following its fixture idiom.
#   I - global-mode FTS5 regression tests (opt-in via --runtime): a long, realistic
#       multi-word --global query (including a literal `<sec:representation>`-shaped
#       token) that previously either hard-errored or returned zero segments now returns
#       a non-empty, topically relevant result set (I1); sparse=true/false stays honest at
#       the exact LITERATURE_SPARSE_THRESHOLD boundary (I2); one FTS5-hostile filtered
#       term never poisons a query mixed with valid terms, while an all-hostile term set
#       surfaces a non-null query_error (I3); a chunk matched by several filtered terms
#       counts once, not once per term (I4). A sibling to Section G/H, following their
#       fixture idiom, but with a real FTS5-populated .literature.db (Section G/H's
#       fixture is metadata-only).

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Counters ---
PASSED=0
FAILED=0
WARNINGS=0

# --- Flags ---
RUN_RUNTIME=false
for arg in "$@"; do
  if [[ "$arg" == "--runtime" ]]; then
    RUN_RUNTIME=true
  fi
done

# --- Script location and project root ---
# Resolves correctly from two independent locations: the deployed copy
# (.claude/scripts/test-lit-pipeline.sh, two levels above .claude/) and the source-store copy
# (agent-system/extensions/literature/scripts/test-lit-pipeline.sh, four levels above the repo
# root). Rather than hardcode either depth, walk upward from SCRIPT_DIR to the nearest ancestor
# that contains a .claude/ directory -- true of the repo root in both cases.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT=""
_candidate="$SCRIPT_DIR"
for _ in 1 2 3 4 5 6; do
  if [[ -d "$_candidate/.claude" ]]; then
    PROJECT_ROOT="$_candidate"
    break
  fi
  _parent="$(dirname "$_candidate")"
  [[ "$_parent" == "$_candidate" ]] && break
  _candidate="$_parent"
done
unset _candidate _parent
if [[ -z "$PROJECT_ROOT" ]]; then
  # Fall back to the historical two-levels-up assumption so the original failure mode/message
  # is preserved when no ancestor has a .claude/ directory at all.
  PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

# --- Logging helpers ---
log_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASSED++))
}

log_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAILED++))
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
  ((WARNINGS++))
}

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# --- Validate project root ---
if [[ ! -d "$PROJECT_ROOT/.claude" ]]; then
  echo -e "${RED}[ERROR]${NC} .claude/ directory not found under $PROJECT_ROOT"
  echo "  Run this script from the project root directory."
  exit 1
fi

# --- Runtime cleanup state ---
TEMP_LIT_DIR=""
TEMP_SUB_INDEX=""
ORIGINAL_SUB_INDEX_EXISTS=false
SUB_INDEX_PATH="$PROJECT_ROOT/specs/literature-index.json"
TEMP_LIT_DIR_F=""
TEMP_LIT_DIR_G=""
TEMP_LIT_DIR_H=""
TEMP_LIT_DIR_I=""

cleanup() {
  if [[ -n "$TEMP_LIT_DIR" ]] && [[ -d "$TEMP_LIT_DIR" ]]; then
    rm -rf "$TEMP_LIT_DIR"
  fi
  # Only remove sub-index if we created it (it didn't exist before)
  if [[ -n "$TEMP_SUB_INDEX" ]] && [[ -f "$TEMP_SUB_INDEX" ]] && [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    rm -f "$TEMP_SUB_INDEX"
  fi
  # Restore original LITERATURE_DIR if we changed it
  if [[ -n "${SAVED_LITERATURE_DIR+x}" ]]; then
    export LITERATURE_DIR="$SAVED_LITERATURE_DIR"
  fi
  # Section F's own scratch corpus (separate from Section E's TEMP_LIT_DIR)
  if [[ -n "$TEMP_LIT_DIR_F" ]] && [[ -d "$TEMP_LIT_DIR_F" ]]; then
    rm -rf "$TEMP_LIT_DIR_F"
  fi
  # Section G's own scratch corpus (separate from Sections E/F's TEMP_LIT_DIR/TEMP_LIT_DIR_F)
  if [[ -n "$TEMP_LIT_DIR_G" ]] && [[ -d "$TEMP_LIT_DIR_G" ]]; then
    rm -rf "$TEMP_LIT_DIR_G"
  fi
  # Section H's own scratch corpus (separate from Sections E/F/G's own TEMP_LIT_DIR_*)
  if [[ -n "$TEMP_LIT_DIR_H" ]] && [[ -d "$TEMP_LIT_DIR_H" ]]; then
    rm -rf "$TEMP_LIT_DIR_H"
  fi
  # Section I's own scratch corpus (separate from Sections E/F/G/H's own TEMP_LIT_DIR_*)
  if [[ -n "$TEMP_LIT_DIR_I" ]] && [[ -d "$TEMP_LIT_DIR_I" ]]; then
    rm -rf "$TEMP_LIT_DIR_I"
  fi
}
trap 'cleanup' EXIT

# ============================================================
# SECTION A: Script existence and syntax
# ============================================================
section_a() {
  echo ""
  log_info "Section A: Script existence and syntax"
  echo "----------------------------------------"

  # Check if the literature extension is loaded; if not, skip with info -- mirrors Section B/C's
  # existing "extension not loaded" guard for cslib. Without this guard, a repo that simply never
  # loaded the literature extension would hard-fail here instead of gracefully skipping.
  if [[ ! -d "$PROJECT_ROOT/.claude/extensions/literature" ]]; then
    log_info "Literature extension not loaded in this project — skipping Section A"
    return
  fi

  local scripts_dir="$PROJECT_ROOT/.claude/scripts"

  # literature-briefing.sh: exists
  local briefing_script="$scripts_dir/literature-briefing.sh"
  if [[ -f "$briefing_script" ]]; then
    log_pass "literature-briefing.sh exists"
  else
    log_fail "literature-briefing.sh not found at $briefing_script"
    return
  fi

  # literature-briefing.sh: executable
  if [[ -x "$briefing_script" ]]; then
    log_pass "literature-briefing.sh is executable"
  else
    log_fail "literature-briefing.sh is not executable (run: chmod +x $briefing_script)"
  fi

  # literature-briefing.sh: bash -n syntax check
  if bash -n "$briefing_script" 2>/dev/null; then
    log_pass "literature-briefing.sh passes bash -n syntax check"
  else
    log_fail "literature-briefing.sh has bash syntax errors (bash -n failed)"
  fi

  # literature-create-setup-task.sh: exists
  local setup_script="$scripts_dir/literature-create-setup-task.sh"
  if [[ -f "$setup_script" ]]; then
    log_pass "literature-create-setup-task.sh exists"
  else
    log_fail "literature-create-setup-task.sh not found at $setup_script"
    return
  fi

  # literature-create-setup-task.sh: executable
  if [[ -x "$setup_script" ]]; then
    log_pass "literature-create-setup-task.sh is executable"
  else
    log_fail "literature-create-setup-task.sh is not executable (run: chmod +x $setup_script)"
  fi

  # literature-create-setup-task.sh: bash -n syntax check
  if bash -n "$setup_script" 2>/dev/null; then
    log_pass "literature-create-setup-task.sh passes bash -n syntax check"
  else
    log_fail "literature-create-setup-task.sh has bash syntax errors (bash -n failed)"
  fi
}

# ============================================================
# SECTION B: CSLib skill Stage 4a wiring
# ============================================================
section_b() {
  echo ""
  log_info "Section B: CSLib skill Stage 4a wiring"
  echo "----------------------------------------"

  # Check if cslib extension is loaded; if not, skip with info
  if [[ ! -d "$PROJECT_ROOT/.claude/skills/skill-cslib-research" ]]; then
    log_info "CSLib extension not loaded in this project — skipping Section B"
    return
  fi

  local skills=(
    "skill-cslib-research"
    "skill-cslib-implementation"
    "skill-cslib-research-hard"
    "skill-cslib-implementation-hard"
  )

  for skill in "${skills[@]}"; do
    local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found at $skill_file"
      continue
    fi

    # Check 1: lit_context="" initialization
    if grep -q 'lit_context=""' "$skill_file" 2>/dev/null; then
      log_pass "$skill: lit_context=\"\" initialization found"
    else
      log_fail "$skill: lit_context=\"\" initialization NOT found"
    fi

    # Check 2: literature-briefing.sh call
    if grep -q 'literature-briefing\.sh' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-briefing.sh call found"
    else
      log_fail "$skill: literature-briefing.sh call NOT found"
    fi

    # Check 3: lit_flag gate (lit_flag == "true" or lit_flag = "true")
    if grep -q 'lit_flag' "$skill_file" 2>/dev/null; then
      log_pass "$skill: lit_flag gate found"
    else
      log_fail "$skill: lit_flag gate NOT found"
    fi
  done
}

# ============================================================
# SECTION C: CSLib agent acknowledgment sections
# ============================================================
section_c() {
  echo ""
  log_info "Section C: CSLib agent acknowledgment sections"
  echo "----------------------------------------"

  # Check if cslib extension is loaded; if not, skip with info
  if [[ ! -f "$PROJECT_ROOT/.claude/agents/cslib-research-agent.md" ]]; then
    log_info "CSLib extension not loaded in this project — skipping Section C"
    return
  fi

  local agents=(
    "cslib-research-agent"
    "cslib-implementation-agent"
    "cslib-research-hard-agent"
    "cslib-implementation-hard-agent"
  )

  for agent in "${agents[@]}"; do
    local agent_file="$PROJECT_ROOT/.claude/agents/$agent.md"

    if [[ ! -f "$agent_file" ]]; then
      log_fail "$agent: agent file not found at $agent_file"
      continue
    fi

    # Check for <literature-briefing> tag reference or literature-briefing text
    if grep -q 'literature.briefing\|<literature-briefing>' "$agent_file" 2>/dev/null; then
      log_pass "$agent: literature-briefing acknowledgment found"
    else
      log_fail "$agent: literature-briefing acknowledgment NOT found"
    fi
  done
}

# ============================================================
# SECTION D: General skill interactive detection wiring
# ============================================================
section_d() {
  echo ""
  log_info "Section D: General skill interactive detection wiring"
  echo "----------------------------------------"

  local skills=(
    "skill-orchestrate"
  )

  # Six skills now delegate Section D's branching to ONE shared, directly-executable block
  # (context/patterns/lit-stage4a-flow.md) rather than each carrying its own inline copy of the
  # literature-index.json / literature-create-setup-task checks -- see CLAUDE.md's "Interactive
  # Sub-Index Setup Detection" section. A skill file satisfies each check below either directly
  # (inline pattern present) or indirectly (it imports the shared flow file, which itself carries
  # the pattern) -- both are valid wiring shapes.
  local shared_flow_file="$PROJECT_ROOT/.claude/context/patterns/lit-stage4a-flow.md"

  for skill in "${skills[@]}"; do
    local skill_file="$PROJECT_ROOT/.claude/skills/$skill/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      log_fail "$skill: SKILL.md not found at $skill_file"
      continue
    fi

    local imports_shared_flow=false
    if grep -q 'lit-stage4a-flow\.md' "$skill_file" 2>/dev/null; then
      imports_shared_flow=true
    fi

    # Check 1: literature-index.json sub-index detection (direct or via shared flow import)
    if grep -q 'literature-index\.json' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-index.json sub-index check found (inline)"
    elif [[ "$imports_shared_flow" == "true" ]] && [[ -f "$shared_flow_file" ]] \
        && grep -q 'literature-index\.json' "$shared_flow_file" 2>/dev/null; then
      log_pass "$skill: literature-index.json sub-index check found (via lit-stage4a-flow.md import)"
    else
      log_fail "$skill: literature-index.json sub-index check NOT found (inline or via shared flow import)"
    fi

    # Check 2: literature-create-setup-task reference (direct or via shared flow import)
    if grep -q 'literature-create-setup-task' "$skill_file" 2>/dev/null; then
      log_pass "$skill: literature-create-setup-task reference found (inline)"
    elif [[ "$imports_shared_flow" == "true" ]] && [[ -f "$shared_flow_file" ]] \
        && grep -q 'literature-create-setup-task' "$shared_flow_file" 2>/dev/null; then
      log_pass "$skill: literature-create-setup-task reference found (via lit-stage4a-flow.md import)"
    else
      log_fail "$skill: literature-create-setup-task reference NOT found (inline or via shared flow import)"
    fi
  done
}

# ============================================================
# SECTION E: Runtime smoke test (opt-in via --runtime)
# ============================================================
section_e() {
  echo ""
  log_info "Section E: Runtime smoke test (--runtime)"
  echo "----------------------------------------"

  local briefing_script="$PROJECT_ROOT/.claude/scripts/literature-briefing.sh"

  # --- Create temp LITERATURE_DIR with mock global index ---
  TEMP_LIT_DIR=$(mktemp -d)
  local test_doc_id="TestPaper2024"
  local test_title="A Test Paper on Literature Briefing"
  local test_author="Test Author"
  local test_year="2024"

  # Write mock global index.json
  cat > "$TEMP_LIT_DIR/index.json" <<GLOBAL_INDEX
{
  "entries": [
    {
      "id": "${test_doc_id}",
      "title": "${test_title}",
      "authors": ["${test_author}"],
      "year": ${test_year},
      "path": "sources/${test_doc_id}/",
      "parent_doc": null,
      "token_count": 1000
    }
  ]
}
GLOBAL_INDEX

  log_info "Created temp LITERATURE_DIR: $TEMP_LIT_DIR"

  # --- Save and override LITERATURE_DIR env var ---
  SAVED_LITERATURE_DIR="${LITERATURE_DIR:-}"
  export LITERATURE_DIR="$TEMP_LIT_DIR"

  # --- Track original sub-index existence ---
  if [[ -f "$SUB_INDEX_PATH" ]]; then
    ORIGINAL_SUB_INDEX_EXISTS=true
    TEMP_SUB_INDEX=""
    log_warn "specs/literature-index.json already exists — smoke test will use existing sub-index"
    # Still test with this sub-index if it has the test doc_id; otherwise add a temp entry
  else
    ORIGINAL_SUB_INDEX_EXISTS=false
    TEMP_SUB_INDEX="$SUB_INDEX_PATH"
    mkdir -p "$(dirname "$SUB_INDEX_PATH")"
  fi

  # Test 1: Missing sub-index -> empty output (silent exit)
  if [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    local output_no_index
    output_no_index=$(bash "$briefing_script" 2>/dev/null)
    if [[ -z "$output_no_index" ]]; then
      log_pass "Missing sub-index: briefing script produces empty output (silent exit)"
    else
      log_fail "Missing sub-index: expected empty output, got: $output_no_index"
    fi
  else
    log_info "Skipping missing-sub-index test (file already exists)"
  fi

  # Test 2: Empty sub-index entries -> empty output
  if [[ "$ORIGINAL_SUB_INDEX_EXISTS" == "false" ]]; then
    cat > "$SUB_INDEX_PATH" <<'EMPTY_SUB'
{"entries": []}
EMPTY_SUB
    local output_empty
    output_empty=$(bash "$briefing_script" 2>/dev/null)
    if [[ -z "$output_empty" ]]; then
      log_pass "Empty sub-index entries: briefing script produces empty output"
    else
      log_fail "Empty sub-index entries: expected empty output, got: $output_empty"
    fi
  fi

  # Test 3: Valid sub-index with matching doc_id -> briefing block with title
  cat > "$SUB_INDEX_PATH" <<SUB_INDEX
{
  "entries": [
    {
      "doc_id": "${test_doc_id}",
      "relevance": "Core reference for testing"
    }
  ]
}
SUB_INDEX

  local output_valid
  output_valid=$(bash "$briefing_script" 2>/dev/null)

  if echo "$output_valid" | grep -q '<literature-briefing>'; then
    log_pass "Valid sub-index: output contains <literature-briefing> tag"
  else
    log_fail "Valid sub-index: output does NOT contain <literature-briefing> tag"
    log_info "  Output was: $(echo "$output_valid" | head -5)"
  fi

  if echo "$output_valid" | grep -q "$test_title"; then
    log_pass "Valid sub-index: output contains test paper title"
  else
    log_fail "Valid sub-index: output does NOT contain expected title '$test_title'"
    log_info "  Output was: $(echo "$output_valid" | head -10)"
  fi

  # Test 4: Missing global index (after removing temp dir) -> empty output, exit 0
  local temp_index_backup="$TEMP_LIT_DIR/index.json.bak"
  mv "$TEMP_LIT_DIR/index.json" "$temp_index_backup"

  local output_no_global exit_code_no_global
  output_no_global=$(bash "$briefing_script" 2>/dev/null) || true
  exit_code_no_global=$?

  # Restore
  mv "$temp_index_backup" "$TEMP_LIT_DIR/index.json"

  if [[ -z "$output_no_global" ]] && [[ "$exit_code_no_global" -eq 0 ]]; then
    log_pass "Missing global index: empty output and exit 0 (graceful)"
  else
    log_fail "Missing global index: expected empty output + exit 0, got output='$output_no_global' exit=$exit_code_no_global"
  fi

  # Test 5: Invalid JSON sub-index -> exit 0 (graceful degradation)
  echo "NOT VALID JSON {{{" > "$SUB_INDEX_PATH"
  local output_invalid exit_code_invalid
  output_invalid=$(bash "$briefing_script" 2>/dev/null) || true
  exit_code_invalid=$?

  if [[ "$exit_code_invalid" -eq 0 ]]; then
    log_pass "Invalid JSON sub-index: exits 0 (graceful degradation)"
  else
    log_fail "Invalid JSON sub-index: expected exit 0, got exit $exit_code_invalid"
  fi

  if [[ -z "$output_invalid" ]]; then
    log_pass "Invalid JSON sub-index: empty output (no crash output)"
  else
    log_warn "Invalid JSON sub-index: non-empty output (may be acceptable): $output_invalid"
  fi

  # Cleanup happens via trap
  log_info "Runtime smoke test complete. Temp files will be cleaned up."
}

# ============================================================
# SECTION F: id/FTS namespace unification regression tests (opt-in via --runtime)
# ============================================================
# The Section E fixture above uses one id (TestPaper2024) for both the global-index .id and
# the sub-index doc_id, always -- it could never catch a regression in the .id-vs-
# chunks_data.doc_id divergence class this section guards. Case 4's fixture below is
# deliberately id-less (doc_id only) so a future .id-only regression fails a test here.
#
# NOTE: the companion coverage-marker regression (asserting a deliberately-unresolvable doc_id
# drives the lit-coverage marker to report the failure rather than falsely reporting
# sparse=false) lives in Section G below, not here.
section_f() {
  echo ""
  log_info "Section F: id/FTS namespace unification regression tests (--runtime)"
  echo "----------------------------------------"

  local search_script="$SCRIPT_DIR/literature-search.sh"
  local briefing_script_f="$SCRIPT_DIR/literature-briefing.sh"
  local skill_md_f="$SCRIPT_DIR/../skills/skill-literature/SKILL.md"

  if [[ ! -x "$search_script" ]] || [[ ! -x "$briefing_script_f" ]] || [[ ! -f "$skill_md_f" ]]; then
    log_fail "Section F: required script(s) or SKILL.md not found relative to $SCRIPT_DIR"
    return
  fi
  if ! command -v sqlite3 >/dev/null 2>&1; then
    log_warn "Section F: sqlite3 not available -- skipping (cannot build a chunks_data fixture)"
    return
  fi

  # --- Extract the CURRENT Validate Step 1/2/2b bash blocks from SKILL.md into a runnable
  # script, so Cases 2 and 4 exercise the same code that ships, not a second,
  # drift-prone reimplementation of the divergence/schema-shape logic. ---
  local validate_extract
  validate_extract=$(mktemp)
  python3 - "$skill_md_f" "$validate_extract" <<'PYEOF'
import re, sys
skill_path, out_path = sys.argv[1], sys.argv[2]
with open(skill_path) as f:
    text = f.read()
m = re.search(r"### Validate Step 1.*?(?=### Validate Step 3)", text, re.S)
if not m:
    sys.exit(1)
blocks = re.findall(r"```bash\n(.*?)```", m.group(0), re.S)
with open(out_path, "w") as f:
    f.write("#!/usr/bin/env bash\nset -uo pipefail\n\n")
    f.write("\n\n".join(blocks))
    f.write("""
echo "___SCHEMA_SHAPE_DEFECTS_COUNT___${#schema_shape_defects[@]}"
for x in "${schema_shape_defects[@]}"; do echo "___SCHEMA_SHAPE_DEFECT___$x"; done
echo "___STALE_ENTRIES_COUNT___${#stale_entries[@]}"
for x in "${stale_entries[@]}"; do echo "___STALE_ENTRY___$x"; done
echo "___DIVERGENCE_FTS_ONLY_COUNT___${#divergence_fts_only[@]}"
for x in "${divergence_fts_only[@]}"; do echo "___DIVERGENCE_FTS_ONLY___$x"; done
echo "___DIVERGENCE_INDEX_ONLY_COUNT___${#divergence_index_only[@]}"
for x in "${divergence_index_only[@]}"; do echo "___DIVERGENCE_INDEX_ONLY___$x"; done
""")
PYEOF
  if [[ ! -s "$validate_extract" ]]; then
    log_fail "Section F: could not extract Validate Step 1/2/2b logic from SKILL.md"
    rm -f "$validate_extract"
    return
  fi

  TEMP_LIT_DIR_F=$(mktemp -d)
  mkdir -p "$TEMP_LIT_DIR_F/sources/case1_doc" "$TEMP_LIT_DIR_F/sources/case3_fts_id"

  # --- Shared fixture index: Case 1 (realistic post-fix parent+children shape), Case 2
  # (parent with zero FTS coverage under either lookup strategy -- genuine divergence), Case 3
  # (curated .id differs from FTS doc_id, bridged via .path; project_tags set) ---
  cat > "$TEMP_LIT_DIR_F/index.json" <<'CASE_INDEX'
{
  "entries": [
    {
      "doc_id": "case1_doc", "parent_doc": null,
      "path": "sources/case1_doc/", "title": "Case One Regression Document",
      "authors": ["Regression Tester"], "year": 2026, "metadata_status": "resolved",
      "token_count": 0, "chunk_count": 3, "doc_type": "paper", "source_format": "pdf",
      "keywords": ["regression"],
      "summary": "Fixture matching the post-fix literature-ingest.sh output shape, deliberately without a .id key on the parent (doc_id only) so this case is revert-sensitive to the literature-briefing.sh .id-tolerance fix, not merely illustrative."
    },
    {
      "id": "c1chunk1", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0001.md", "title": "Section 1",
      "keywords": ["regression"], "summary": "Chunk 1 summary.", "token_count": 100
    },
    {
      "id": "c1chunk2", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0002.md", "title": "Section 2",
      "keywords": ["regression"], "summary": "Chunk 2 summary.", "token_count": 100
    },
    {
      "id": "c1chunk3", "doc_id": "case1_doc", "parent_doc": "case1_doc",
      "path": "sources/case1_doc/chunk_0003.md", "title": "Section 3",
      "keywords": ["regression"], "summary": "Chunk 3 summary.", "token_count": 100
    },
    {
      "id": "case2_orphan", "doc_id": "case2_orphan", "parent_doc": null,
      "path": "sources/case2_orphan_dir/", "title": "Case Two Orphan Document",
      "authors": [], "year": null, "token_count": 0, "chunk_count": 0,
      "doc_type": "paper", "source_format": "pdf", "keywords": [],
      "summary": "Neither .id nor its path-derived dir key has any FTS chunks -- genuine divergence."
    },
    {
      "id": "case3_curated_id", "doc_id": "case3_curated_id", "parent_doc": null,
      "path": "sources/case3_fts_id/", "title": "Case Three Bridged Document",
      "authors": ["Bridge Tester"], "year": 2026, "token_count": 0, "chunk_count": 1,
      "doc_type": "paper", "source_format": "pdf", "keywords": ["bridging"],
      "summary": "Curated .id differs from the FTS doc_id; resolved only via the .path bridge.",
      "project_tags": ["NamespaceBridgeRegressionProject"],
      "provenance_fidelity": "verified_conversion"
    },
    {
      "id": "case3_decoy_doc", "doc_id": "case3_decoy_doc", "parent_doc": null,
      "path": "sources/case3_decoy_doc/", "title": "Case Three Decoy Document",
      "authors": ["Bridge Tester"], "year": 2026, "token_count": 0, "chunk_count": 1,
      "doc_type": "paper", "source_format": "pdf", "keywords": ["bridging"],
      "summary": "Decoy whose .id matches its own FTS doc_id, so a project-filtered search for the shared query term returns a nonzero result set under BOTH the pre-fix and post-fix allow-list -- this prevents literature-search.sh's zero-result unfiltered-retry fallback from masking the bridge regression (an unfiltered retry would find case3_fts_id too, passing the test even with the bridge reverted).",
      "project_tags": ["NamespaceBridgeRegressionProject"],
      "provenance_fidelity": "verified_conversion"
    }
  ]
}
CASE_INDEX

  # Build the fixture .literature.db from the REAL schema file (never a hand-rolled
  # CREATE TABLE) so this fixture cannot silently drift from the columns
  # literature-search.sh's queries actually select (e.g. `level`, which a prior draft
  # of this fixture omitted and which made --toc fail silently, caught only by
  # literature-search.sh's own `except Exception` and never surfaced under `2>/dev/null`).
  sqlite3 "$TEMP_LIT_DIR_F/.literature.db" < "$SCRIPT_DIR/literature-schema.sql"
  sqlite3 "$TEMP_LIT_DIR_F/.literature.db" <<'CASE_SQL'
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk1', 'case1_doc', 'Section 1', 'Section 1', 'Chunk 1 summary.', 100, 'chunk_0001.md', 'content one for the ingest-then-brief regression case');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk2', 'case1_doc', 'Section 2', 'Section 2', 'Chunk 2 summary.', 100, 'chunk_0002.md', 'content two');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c1chunk3', 'case1_doc', 'Section 3', 'Section 3', 'Chunk 3 summary.', 100, 'chunk_0003.md', 'content three');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c3chunk1', 'case3_fts_id', 'Bridged Content', 'Bridged Content', 'Bridged chunk summary.', 50, 'chunk_0001.md', 'nsbridge9x7q unique marker for project-filtered search bridge regression');
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, summary, token_count, source_path, content) VALUES ('c3decoychunk1', 'case3_decoy_doc', 'Decoy Content', 'Decoy Content', 'Decoy chunk summary.', 50, 'chunk_0001.md', 'nsbridge9x7q also present in the decoy so the filtered query is nonzero under both pre-fix and post-fix code');
INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild');
CASE_SQL

  # --- Case 1: ingest-then-brief (actual post-fix output shape) ---
  mkdir -p "$TEMP_LIT_DIR_F/fakerepo/nested/scripts" "$TEMP_LIT_DIR_F/fakerepo/specs"
  ln -sf "$briefing_script_f" "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-briefing.sh"
  ln -sf "$search_script" "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-search.sh"
  cat > "$TEMP_LIT_DIR_F/fakerepo/specs/literature-index.json" <<'CASE1_SUBINDEX'
{"entries": [{"doc_id": "case1_doc", "relevance": "case 1 regression"}]}
CASE1_SUBINDEX

  local case1_stderr case1_briefing case1_toc_count case1_briefing_count
  case1_stderr=$(mktemp)
  case1_briefing=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$TEMP_LIT_DIR_F/fakerepo/nested/scripts/literature-briefing.sh" 2>"$case1_stderr")
  if grep -q "not found in global index" "$case1_stderr"; then
    log_fail "Case 1 (ingest-then-brief): skip warning present on stderr (should be zero)"
  elif echo "$case1_briefing" | grep -q "Case One Regression Document" && echo "$case1_briefing" | grep -q "Regression Tester"; then
    log_pass "Case 1 (ingest-then-brief): resolves with real title/authors, zero skip warnings"
  else
    log_fail "Case 1 (ingest-then-brief): expected title/authors not found in briefing output"
  fi
  rm -f "$case1_stderr"

  case1_toc_count=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$search_script" --toc case1_doc 2>/dev/null | jq 'length' 2>/dev/null || echo -1)
  case1_briefing_count=$(echo "$case1_briefing" | grep -oE '[0-9]+ chunk\(s\)' | head -1 | grep -oE '^[0-9]+')
  if [[ "$case1_toc_count" == "3" ]] && [[ "$case1_briefing_count" == "3" ]]; then
    log_pass "Case 1 (ingest-then-brief): --toc chunk count (3) equals briefing's reported chunk count"
  else
    log_fail "Case 1 (ingest-then-brief): chunk count mismatch (--toc=$case1_toc_count, briefing=$case1_briefing_count)"
  fi

  # --- Case 3: project-filtered-search bridge ---
  local case3_search case3_docids
  case3_search=$(LITERATURE_DIR="$TEMP_LIT_DIR_F" bash "$search_script" --project NamespaceBridgeRegressionProject "nsbridge9x7q" 2>/dev/null)
  case3_docids=$(echo "$case3_search" | jq -r '[.results[]?.doc_id] | unique | .[]' 2>/dev/null)
  if echo "$case3_docids" | grep -qx "case3_fts_id"; then
    log_pass "Case 3 (project-filtered-search bridge): returns case3_fts_id (curated .id case3_curated_id differs from FTS doc_id)"
  else
    log_fail "Case 3 (project-filtered-search bridge): case3_fts_id NOT returned. Got doc_ids: $case3_docids"
  fi

  # --- Case 2 + Case 4: run the extracted --validate logic once against the shared index,
  # plus a second id-less stub entry (Case 4) added to a COPY of the index so Case 1/2/3's
  # fixtures are untouched by Case 4's deliberately malformed record. ---
  cp "$TEMP_LIT_DIR_F/index.json" "$TEMP_LIT_DIR_F/index_case4.json"
  python3 - "$TEMP_LIT_DIR_F/index_case4.json" <<'PYEOF'
import json, sys
p = sys.argv[1]
with open(p) as f:
    idx = json.load(f)
# Case 4: a stub entry with NEITHER .id NOR .path -- the exact shape that used to be
# misreported as the literal string "null (missing)".
idx["entries"].append({"doc_id": "case4_stub", "title": "Case Four Schema-Shape Stub"})
with open(p, "w") as f:
    json.dump(idx, f, indent=2)
PYEOF

  local validate_out
  validate_out=$(SCRIPT_DIR="$SCRIPT_DIR" lit_dir="$TEMP_LIT_DIR_F" index_file="$TEMP_LIT_DIR_F/index_case4.json" bash "$validate_extract" 2>&1)
  rm -f "$validate_extract"

  if echo "$validate_out" | grep -q "^___DIVERGENCE_INDEX_ONLY___case2_orphan"; then
    log_pass "Case 2 (--validate divergence): case2_orphan reported in the index-only-no-FTS-chunks bucket"
  else
    log_fail "Case 2 (--validate divergence): case2_orphan NOT reported. Output: $(echo "$validate_out" | grep '___DIVERGENCE')"
  fi

  if echo "$validate_out" | grep -q "^___SCHEMA_SHAPE_DEFECT___case4_stub"; then
    log_pass "Case 4 (schema-shape): case4_stub reported in the schema-shape-defects bucket"
  else
    log_fail "Case 4 (schema-shape): case4_stub NOT reported in schema-shape-defects"
  fi

  if echo "$validate_out" | grep -qi "null (missing)"; then
    log_fail "Case 4 (schema-shape): the literal string 'null (missing)' appeared in --validate output -- the misreport this task fixes"
  else
    log_pass "Case 4 (schema-shape): the literal string 'null (missing)' never appears in --validate output"
  fi

  log_info "Section F complete. Temp corpus will be cleaned up."
}

# ============================================================
# SECTION G: coverage-marker resolution-failure regression (opt-in via --runtime)
# ============================================================
# Asserts that literature-briefing.sh's repo-mode skip path (a doc_id registered in the
# sub-index but absent from the global index.json) is counted, not silently dropped: the
# lit-coverage marker's requested=/resolved=/skipped=/skip_rate= fields report the failure,
# a high skip rate flips the existing sparse boolean via the new skip-rate disjunct (isolated
# from the pre-existing absolute-count rule in Case G2), the failure is surfaced in the body
# under "## Unresolved Documents", the total-failure case still emits a marker instead of
# exiting silently, and the genuinely-empty-sub-index silent-exit contract is unregressed.
section_g() {
  echo ""
  log_info "Section G: coverage-marker resolution-failure regression tests (--runtime)"
  echo "----------------------------------------"

  local briefing_script_g="$SCRIPT_DIR/literature-briefing.sh"

  if [[ ! -x "$briefing_script_g" ]]; then
    log_fail "Section G: literature-briefing.sh not found relative to $SCRIPT_DIR"
    return
  fi

  TEMP_LIT_DIR_G=$(mktemp -d)

  # --- Shared global index: four resolvable documents (g1-g4). Following Section F's fixture
  # idiom, the .literature.db is built from the real schema even though literature-briefing.sh's
  # repo mode never queries it -- kept for idiom consistency and in case a future case needs it. ---
  cat > "$TEMP_LIT_DIR_G/index.json" <<'GINDEX'
{
  "entries": [
    {"id": "g1", "doc_id": "g1", "parent_doc": null, "path": "sources/g1/", "title": "Section G Doc One", "authors": ["Regression Tester"], "year": 2026, "token_count": 50, "provenance_fidelity": "verified_conversion"},
    {"id": "g2", "doc_id": "g2", "parent_doc": null, "path": "sources/g2/", "title": "Section G Doc Two", "authors": ["Regression Tester"], "year": 2026, "token_count": 50, "provenance_fidelity": "verified_conversion"},
    {"id": "g3", "doc_id": "g3", "parent_doc": null, "path": "sources/g3/", "title": "Section G Doc Three", "authors": ["Regression Tester"], "year": 2026, "token_count": 50, "provenance_fidelity": "verified_conversion"},
    {"id": "g4", "doc_id": "g4", "parent_doc": null, "path": "sources/g4/", "title": "Section G Doc Four", "authors": ["Regression Tester"], "year": 2026, "token_count": 50, "provenance_fidelity": "verified_conversion"}
  ]
}
GINDEX

  if command -v sqlite3 >/dev/null 2>&1; then
    sqlite3 "$TEMP_LIT_DIR_G/.literature.db" < "$SCRIPT_DIR/literature-schema.sql"
  fi

  mkdir -p "$TEMP_LIT_DIR_G/fakerepo/nested/scripts" "$TEMP_LIT_DIR_G/fakerepo/specs"
  ln -sf "$briefing_script_g" "$TEMP_LIT_DIR_G/fakerepo/nested/scripts/literature-briefing.sh"
  local sub_index_g="$TEMP_LIT_DIR_G/fakerepo/specs/literature-index.json"
  local briefing_g="$TEMP_LIT_DIR_G/fakerepo/nested/scripts/literature-briefing.sh"

  # --- Case G1: partial failure (2 requested, 1 resolvable, 1 unresolvable) ---
  cat > "$sub_index_g" <<'G1_SUBINDEX'
{"entries": [{"doc_id": "g1"}, {"doc_id": "ghost_g1"}]}
G1_SUBINDEX
  local g1_out g1_marker
  g1_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_G" bash "$briefing_g" 2>/dev/null)
  g1_marker=$(echo "$g1_out" | grep -- '<!-- lit-coverage')
  if echo "$g1_marker" | grep -q 'requested=2 resolved=1 skipped=1 skip_rate=50' && echo "$g1_marker" | grep -q 'sparse=true'; then
    log_pass "Case G1 (partial failure): marker reports requested=2 resolved=1 skipped=1 skip_rate=50 sparse=true"
  else
    log_fail "Case G1 (partial failure): unexpected marker fields. Got: $g1_marker"
  fi
  if echo "$g1_out" | grep -q '## Unresolved Documents' && echo "$g1_out" | grep -q '^- ghost_g1$'; then
    log_pass "Case G1 (partial failure): body lists ghost_g1 under '## Unresolved Documents'"
  else
    log_fail "Case G1 (partial failure): '## Unresolved Documents' section or ghost_g1 entry missing"
  fi
  if echo "$g1_out" | grep -q '\[SKIPPED SOURCES'; then
    log_pass "Case G1 (partial failure): [SKIPPED SOURCES ...] banner present"
  else
    log_fail "Case G1 (partial failure): [SKIPPED SOURCES ...] banner missing"
  fi

  # --- Case G2: isolate the new skip-rate disjunct from the pre-existing absolute-count rule
  # (4 resolved is >= the default LITERATURE_SPARSE_THRESHOLD of 3, so sparse=true here can only
  # be caused by the new skip_rate >= LITERATURE_SKIP_RATE_THRESHOLD rule) ---
  cat > "$sub_index_g" <<'G2_SUBINDEX'
{"entries": [{"doc_id": "g1"}, {"doc_id": "g2"}, {"doc_id": "g3"}, {"doc_id": "g4"}, {"doc_id": "ghost1"}, {"doc_id": "ghost2"}, {"doc_id": "ghost3"}, {"doc_id": "ghost4"}]}
G2_SUBINDEX
  local g2_out g2_marker
  g2_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_G" bash "$briefing_g" 2>/dev/null)
  g2_marker=$(echo "$g2_out" | grep -- '<!-- lit-coverage')
  if echo "$g2_marker" | grep -q 'seg_count=4' && echo "$g2_marker" | grep -q 'requested=8 resolved=4 skipped=4 skip_rate=50' && echo "$g2_marker" | grep -q 'sparse=true'; then
    log_pass "Case G2 (isolated skip-rate disjunct): resolved=4 (above sparse threshold) yet sparse=true via skip_rate=50"
  else
    log_fail "Case G2 (isolated skip-rate disjunct): unexpected marker fields. Got: $g2_marker"
  fi

  # --- Case G3: total failure (sole requested doc_id unresolvable) -- must still emit a
  # marker/non-empty stdout, not exit 0 silently ---
  cat > "$sub_index_g" <<'G3_SUBINDEX'
{"entries": [{"doc_id": "ghost_total"}]}
G3_SUBINDEX
  local g3_out g3_marker
  g3_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_G" bash "$briefing_g" 2>/dev/null)
  if [[ -z "$g3_out" ]]; then
    log_fail "Case G3 (total failure): stdout was empty -- silent exit not fixed"
  else
    log_pass "Case G3 (total failure): stdout is non-empty (marker emitted instead of silent exit)"
    g3_marker=$(echo "$g3_out" | grep -- '<!-- lit-coverage')
    if echo "$g3_marker" | grep -q 'seg_count=0' && echo "$g3_marker" | grep -q 'resolved=0' && echo "$g3_marker" | grep -q 'skipped=1' && echo "$g3_marker" | grep -q 'sparse=true'; then
      log_pass "Case G3 (total failure): marker reports seg_count=0 resolved=0 skipped=1 sparse=true"
    else
      log_fail "Case G3 (total failure): unexpected marker fields. Got: $g3_marker"
    fi
  fi

  # --- Negative control: a genuinely empty sub-index (entries: []) must still exit silently --
  # confirms Phase 1's fallthrough-on-skip_count did not regress the pre-existing
  # legitimately-empty silent-exit contract at lines ~150-168. ---
  cat > "$sub_index_g" <<'G4_SUBINDEX'
{"entries": []}
G4_SUBINDEX
  local g4_out
  g4_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_G" bash "$briefing_g" 2>/dev/null)
  if [[ -z "$g4_out" ]]; then
    log_pass "Negative control (empty sub-index): stdout still empty -- silent-exit contract unregressed"
  else
    log_fail "Negative control (empty sub-index): stdout was non-empty -- silent-exit contract regressed"
  fi

  log_info "Section G complete. Temp corpus will be cleaned up."
}

# ============================================================
# SECTION H: topic-scoped coverage-delta guard regression (opt-in via --runtime)
# ============================================================
# Asserts the coverage-delta guard added alongside literature-lit-flag-resolve.sh's
# SUBINDEX_PRESENT branch and literature-briefing.sh's repo-mode marker/banner: a sub-index that
# clears the absolute sparsity floor still downgrades to SPARSE_PROMPT_NEEDED and surfaces a
# [COVERAGE DELTA ...] banner when the global index holds topic-matching documents it never
# references (H1); a non-matching query stays silent, the anti-alarm-fatigue guarantee (H2);
# chunk children never inflate the delta (H3, the single most load-bearing implementation
# detail in literature-coverage-delta.sh); an unqueried repo-mode briefing reports
# delta_checked=false rather than a false zero, D6 (H4); a missing LITERATURE_DIR still fails
# open to SUBINDEX_PRESENT, exit 0 (H5); LITERATURE_COVERAGE_GAP_MIN's `>=` (not `>`) boundary is
# exercised exactly at and one below the threshold (H6).
section_h() {
  echo ""
  log_info "Section H: topic-scoped coverage-delta guard regression tests (--runtime)"
  echo "----------------------------------------"

  local resolve_script_h="$SCRIPT_DIR/literature-lit-flag-resolve.sh"
  local briefing_script_h="$SCRIPT_DIR/literature-briefing.sh"
  local delta_script_h="$SCRIPT_DIR/literature-coverage-delta.sh"
  local term_match_script_h="$SCRIPT_DIR/literature-term-match.sh"

  if [[ ! -x "$resolve_script_h" ]] || [[ ! -x "$briefing_script_h" ]] || [[ ! -x "$delta_script_h" ]]; then
    log_fail "Section H: one of literature-lit-flag-resolve.sh/literature-briefing.sh/literature-coverage-delta.sh not found relative to $SCRIPT_DIR"
    return
  fi
  if [[ ! -f "$term_match_script_h" ]]; then
    log_fail "Section H: literature-term-match.sh not found relative to $SCRIPT_DIR"
    return
  fi

  TEMP_LIT_DIR_H=$(mktemp -d)

  # --- Shared global index (H1/H2): 30 top-level documents, one of which
  # ("wombat_target") topically matches the H1 query and none of which match the H2 query.
  # 30 top-level docs against a 3-entry sub-index gives delta_gap=27, above the default
  # LITERATURE_COVERAGE_GAP_MIN=25 pre-filter. ---
  python3 - "$TEMP_LIT_DIR_H/index.json" <<'PYEOF'
import json, sys
entries = [
    {"id": "wombat_target", "doc_id": "wombat_target", "parent_doc": None,
     "path": "sources/wombat_target/", "title": "Wombat Marsupial Taxonomy Survey",
     "authors": ["Regression Tester"], "year": 2026, "token_count": 50}
]
for i in range(1, 30):
    entries.append({
        "id": f"h_filler{i}", "doc_id": f"h_filler{i}", "parent_doc": None,
        "path": f"sources/h_filler{i}/", "title": f"Section H Filler Document {i}",
        "authors": ["Regression Tester"], "year": 2026, "token_count": 50,
    })
json.dump({"entries": entries}, open(sys.argv[1], "w"))
PYEOF

  mkdir -p "$TEMP_LIT_DIR_H/fakerepo/nested/scripts" "$TEMP_LIT_DIR_H/fakerepo/specs"
  ln -sf "$resolve_script_h" "$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-lit-flag-resolve.sh"
  ln -sf "$briefing_script_h" "$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-briefing.sh"
  ln -sf "$delta_script_h" "$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-coverage-delta.sh"
  ln -sf "$term_match_script_h" "$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-term-match.sh"
  local sub_index_h="$TEMP_LIT_DIR_H/fakerepo/specs/literature-index.json"
  local resolve_h="$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-lit-flag-resolve.sh"
  local briefing_h="$TEMP_LIT_DIR_H/fakerepo/nested/scripts/literature-briefing.sh"

  # Sub-index: 3 entries clearing the absolute floor (LITERATURE_SPARSE_THRESHOLD default 3),
  # none of which are present in the H1/H2 global index above (doc_ids never overlap
  # wombat_target/h_filler* -- the delta's SUB_KEYS exclusion has nothing to exclude here, and
  # is exercised separately by the Phase-2-level manual check, not re-duplicated in this suite).
  cat > "$sub_index_h" <<'H_SUBINDEX'
{"entries": [{"doc_id": "sub1"}, {"doc_id": "sub2"}, {"doc_id": "sub3"}]}
H_SUBINDEX

  # --- Case H1 (fires): topic-matching query ---
  local h1_resolve_out h1_directive h1_briefing_out h1_marker
  h1_resolve_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$resolve_h" --lit-flag true --orchestrator-mode false --query "wombat marsupial taxonomy" 2>/dev/null)
  h1_directive=$(echo "$h1_resolve_out" | tail -1)
  if [[ "$h1_directive" == "SPARSE_PROMPT_NEEDED" ]]; then
    log_pass "Case H1 (fires): resolver downgrades to SPARSE_PROMPT_NEEDED on a topic-scoped miss"
  else
    log_fail "Case H1 (fires): expected SPARSE_PROMPT_NEEDED, got '$h1_directive'"
  fi

  h1_briefing_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$briefing_h" --query "wombat marsupial taxonomy" 2>/dev/null)
  h1_marker=$(echo "$h1_briefing_out" | grep -- '<!-- lit-coverage')
  if echo "$h1_marker" | grep -q 'delta_checked=true' && echo "$h1_marker" | grep -qE 'delta_candidates=[1-9][0-9]*'; then
    log_pass "Case H1 (fires): briefing marker reports delta_checked=true delta_candidates>=1"
  else
    log_fail "Case H1 (fires): unexpected marker fields. Got: $h1_marker"
  fi
  if echo "$h1_briefing_out" | grep -q '\[COVERAGE DELTA' && echo "$h1_briefing_out" | grep -q 'wombat_target'; then
    log_pass "Case H1 (fires): [COVERAGE DELTA ...] banner present and lists wombat_target"
  else
    log_fail "Case H1 (fires): [COVERAGE DELTA ...] banner missing or does not list wombat_target"
  fi

  # --- Case H2 (negative control, does NOT fire): non-matching query. This is the
  # anti-alarm-fatigue guarantee and must not be dropped. ---
  local h2_resolve_out h2_directive h2_briefing_out h2_marker
  h2_resolve_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$resolve_h" --lit-flag true --orchestrator-mode false --query "underwater basket weaving techniques" 2>/dev/null)
  h2_directive=$(echo "$h2_resolve_out" | tail -1)
  if [[ "$h2_directive" == "SUBINDEX_PRESENT" ]]; then
    log_pass "Case H2 (negative control): resolver stays SUBINDEX_PRESENT on a non-matching query"
  else
    log_fail "Case H2 (negative control): expected SUBINDEX_PRESENT, got '$h2_directive'"
  fi

  h2_briefing_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$briefing_h" --query "underwater basket weaving techniques" 2>/dev/null)
  h2_marker=$(echo "$h2_briefing_out" | grep -- '<!-- lit-coverage')
  if echo "$h2_marker" | grep -q 'delta_candidates=0'; then
    log_pass "Case H2 (negative control): briefing marker reports delta_candidates=0"
  else
    log_fail "Case H2 (negative control): unexpected marker fields. Got: $h2_marker"
  fi
  if echo "$h2_briefing_out" | grep -q '\[COVERAGE DELTA'; then
    log_fail "Case H2 (negative control): [COVERAGE DELTA ...] banner unexpectedly present -- alarm-fatigue guarantee broken"
  else
    log_pass "Case H2 (negative control): [COVERAGE DELTA ...] banner absent"
  fi

  # --- Case H3 (chunk inflation): a dedicated global index of 30 top-level docs, each with 2
  # chunk children (parent_doc-bearing), for 90 flat .entries. global_docs must report 30, never
  # 90 -- this is the plan's single most load-bearing implementation detail. ---
  local chunk_index_h="$TEMP_LIT_DIR_H/index_chunked.json"
  python3 - "$chunk_index_h" <<'PYEOF'
import json, sys
entries = []
for i in range(1, 31):
    doc_id = f"h3_doc{i}"
    entries.append({"id": doc_id, "doc_id": doc_id, "parent_doc": None,
                     "path": f"sources/{doc_id}/", "title": f"Chunked Document {i}",
                     "authors": [], "year": 2026, "token_count": 50})
    for c in range(1, 3):
        entries.append({"id": f"{doc_id}_c{c}", "doc_id": f"{doc_id}_c{c}",
                         "parent_doc": doc_id, "title": f"Chunked Document {i} chunk {c}",
                         "token_count": 20})
json.dump({"entries": entries}, open(sys.argv[1], "w"))
PYEOF
  local h3_raw_entries h3_top_level
  h3_raw_entries=$(jq '.entries | length' "$chunk_index_h")
  h3_top_level=$(jq '[.entries[] | select(.parent_doc == null)] | length' "$chunk_index_h")
  if [[ "$h3_raw_entries" -eq 90 ]] && [[ "$h3_top_level" -eq 30 ]]; then
    log_pass "Case H3 (chunk inflation): fixture has 90 raw entries, 30 top-level docs (2 chunks per doc)"
  else
    log_fail "Case H3 (chunk inflation): fixture shape unexpected -- raw=$h3_raw_entries top_level=$h3_top_level"
  fi

  mkdir -p "$TEMP_LIT_DIR_H/chunkrepo/nested/scripts" "$TEMP_LIT_DIR_H/chunkrepo/specs"
  local chunk_lit_dir="$TEMP_LIT_DIR_H/chunk_lit_dir"
  mkdir -p "$chunk_lit_dir"
  cp "$chunk_index_h" "$chunk_lit_dir/index.json"
  cat > "$TEMP_LIT_DIR_H/chunkrepo/specs/literature-index.json" <<'H3_SUBINDEX'
{"entries": [{"doc_id": "sub1"}, {"doc_id": "sub2"}, {"doc_id": "sub3"}]}
H3_SUBINDEX
  ln -sf "$delta_script_h" "$TEMP_LIT_DIR_H/chunkrepo/nested/scripts/literature-coverage-delta.sh"
  ln -sf "$term_match_script_h" "$TEMP_LIT_DIR_H/chunkrepo/nested/scripts/literature-term-match.sh"

  local h3_delta_out h3_global_docs h3_gap
  h3_delta_out=$(LITERATURE_DIR="$chunk_lit_dir" bash "$TEMP_LIT_DIR_H/chunkrepo/nested/scripts/literature-coverage-delta.sh" --query "chunked document survey" 2>/dev/null)
  h3_global_docs=$(echo "$h3_delta_out" | grep -oE 'global_docs=[0-9]+' | cut -d= -f2)
  h3_gap=$(echo "$h3_delta_out" | grep -oE 'delta_gap=[0-9]+' | cut -d= -f2)
  if [[ "$h3_global_docs" == "30" ]]; then
    log_pass "Case H3 (chunk inflation): literature-coverage-delta.sh reports global_docs=30 (top-level only, not 90)"
  else
    log_fail "Case H3 (chunk inflation): expected global_docs=30, got '$h3_global_docs'. Full output: $h3_delta_out"
  fi
  if [[ "$h3_gap" == "27" ]]; then
    log_pass "Case H3 (chunk inflation): delta_gap=27 (30 top-level - 3 sub-index, not chunk-inflated)"
  else
    log_fail "Case H3 (chunk inflation): expected delta_gap=27, got '$h3_gap'. Full output: $h3_delta_out"
  fi

  # --- Case H4 (not computed): repo-mode briefing invoked WITHOUT --query -- delta_checked must
  # be false, never a false zero (D6), and the pre-existing marker fields must stay as expected
  # (requested=3 skipped=3, since none of sub1/sub2/sub3 resolve against the H1/H2 global index). ---
  local h4_out h4_marker
  h4_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$briefing_h" 2>/dev/null)
  h4_marker=$(echo "$h4_out" | grep -- '<!-- lit-coverage')
  if echo "$h4_marker" | grep -q 'delta_checked=false' && echo "$h4_marker" | grep -q 'delta_gap=0' && echo "$h4_marker" | grep -q 'delta_candidates=0'; then
    log_pass "Case H4 (not computed): marker reports delta_checked=false delta_gap=0 delta_candidates=0 (never a false zero)"
  else
    log_fail "Case H4 (not computed): unexpected delta_* fields. Got: $h4_marker"
  fi
  if echo "$h4_marker" | grep -q 'requested=3 resolved=0 skipped=3'; then
    log_pass "Case H4 (not computed): pre-existing marker fields (requested=/resolved=/skipped=) unaffected"
  else
    log_fail "Case H4 (not computed): pre-existing marker fields regressed. Got: $h4_marker"
  fi

  # --- Case H5 (fail-open): LITERATURE_DIR pointing at a nonexistent path -- resolver must
  # still emit SUBINDEX_PRESENT on stdout with exit 0, never abort a --lit run. ---
  local h5_out h5_exit
  h5_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H/does-not-exist" bash "$resolve_h" --lit-flag true --orchestrator-mode false --query "wombat marsupial taxonomy" 2>/dev/null)
  h5_exit=$?
  if [[ "$h5_exit" -eq 0 ]] && [[ "$(echo "$h5_out" | tail -1)" == "SUBINDEX_PRESENT" ]]; then
    log_pass "Case H5 (fail-open): missing LITERATURE_DIR still yields SUBINDEX_PRESENT, exit 0"
  else
    log_fail "Case H5 (fail-open): expected SUBINDEX_PRESENT/exit 0, got '$h5_out' (exit $h5_exit)"
  fi

  # --- Case H6 (boundary, per the Scope Hypothesis re-check against Section G's boundary
  # coverage): LITERATURE_COVERAGE_GAP_MIN's comparison is `>=` (D1), not `>` -- reuses the
  # shared 30-doc global index above (global_docs=30) with two sub-index sizes chosen so
  # delta_gap lands exactly on, and exactly one below, the default GAP_MIN=25. ---
  local h6_at_boundary_sub="$TEMP_LIT_DIR_H/h6_at_boundary_subindex.json"
  local h6_below_boundary_sub="$TEMP_LIT_DIR_H/h6_below_boundary_subindex.json"
  python3 - "$h6_at_boundary_sub" 5 <<'PYEOF'
import json, sys
n = int(sys.argv[2])
json.dump({"entries": [{"doc_id": f"h6_at_{i}"} for i in range(n)]}, open(sys.argv[1], "w"))
PYEOF
  python3 - "$h6_below_boundary_sub" 6 <<'PYEOF'
import json, sys
n = int(sys.argv[2])
json.dump({"entries": [{"doc_id": f"h6_below_{i}"} for i in range(n)]}, open(sys.argv[1], "w"))
PYEOF

  mkdir -p "$TEMP_LIT_DIR_H/h6repo/nested/scripts" "$TEMP_LIT_DIR_H/h6repo/specs"
  ln -sf "$delta_script_h" "$TEMP_LIT_DIR_H/h6repo/nested/scripts/literature-coverage-delta.sh"
  ln -sf "$term_match_script_h" "$TEMP_LIT_DIR_H/h6repo/nested/scripts/literature-term-match.sh"
  local delta_h6="$TEMP_LIT_DIR_H/h6repo/nested/scripts/literature-coverage-delta.sh"

  local h6_at_out h6_at_gap h6_at_checked h6_at_candidates
  cp "$h6_at_boundary_sub" "$TEMP_LIT_DIR_H/h6repo/specs/literature-index.json"
  h6_at_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$delta_h6" --query "wombat marsupial taxonomy" 2>/dev/null)
  h6_at_gap=$(echo "$h6_at_out" | grep -oE 'delta_gap=[0-9]+' | cut -d= -f2)
  h6_at_checked=$(echo "$h6_at_out" | grep -oE 'delta_checked=[a-z]+' | cut -d= -f2)
  h6_at_candidates=$(echo "$h6_at_out" | grep -oE 'delta_candidates=[0-9]+' | cut -d= -f2)
  if [[ "$h6_at_gap" == "25" ]] && [[ "$h6_at_checked" == "true" ]] && [[ "$h6_at_candidates" -ge 1 ]]; then
    log_pass "Case H6 (boundary, at GAP_MIN): delta_gap=25 (== LITERATURE_COVERAGE_GAP_MIN) still runs the keyword pass (>=, not >)"
  else
    log_fail "Case H6 (boundary, at GAP_MIN): expected gap=25/checked=true/candidates>=1. Got: $h6_at_out"
  fi

  local h6_below_out h6_below_gap
  cp "$h6_below_boundary_sub" "$TEMP_LIT_DIR_H/h6repo/specs/literature-index.json"
  h6_below_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_H" bash "$delta_h6" --query "wombat marsupial taxonomy" 2>/dev/null)
  h6_below_gap=$(echo "$h6_below_out" | grep -oE 'delta_gap=[0-9]+' | cut -d= -f2)
  if [[ "$h6_below_gap" == "24" ]] && echo "$h6_below_out" | grep -q 'delta_candidates=0'; then
    log_pass "Case H6 (boundary, below GAP_MIN): delta_gap=24 (one below GAP_MIN) skips the keyword pass, delta_candidates=0"
  else
    log_fail "Case H6 (boundary, below GAP_MIN): expected gap=24/candidates=0 (keyword pass skipped). Got: $h6_below_out"
  fi

  log_info "Section H complete. Temp corpus will be cleaned up."
}

# ============================================================
# SECTION I: global-mode FTS5 regression (opt-in via --runtime)
# ============================================================
# Asserts the --global AND-all-terms/`<`-syntax-error fix: a full-length, realistic
# multi-word query (including a literal `<sec:representation>`-shaped token) that
# previously either hard-errored (unhandled `<`/`>`) or returned zero segments (FTS5's
# bareword MATCH ANDs every term) now returns a non-empty, deduplicated result set
# (I1); the sparse=true/false boundary stays honest at the exact
# LITERATURE_SPARSE_THRESHOLD count, not just qualitatively "more" or "fewer" (I2);
# one FTS5-hostile filtered term never poisons a query mixed with valid terms, while
# an all-hostile term set surfaces a non-null query_error (I3); a chunk matched by
# several filtered terms is counted once, not once per matching term (I4). A sibling
# to Section G/H, following their fixture idiom -- its own temp LITERATURE_DIR, its
# own fixture DB (built from the real schema, unlike G/H's metadata-only DB, since
# this section exercises live FTS5 MATCH queries), resolved relative to test-lit-
# pipeline.sh's own SCRIPT_DIR (like Section F/G/H, never the hardcoded deployed
# .claude/ path Section E uses).
section_i() {
  echo ""
  log_info "Section I: global-mode FTS5 regression tests (--runtime)"
  echo "----------------------------------------"

  local briefing_script_i="$SCRIPT_DIR/literature-briefing.sh"

  if [[ ! -x "$briefing_script_i" ]] && [[ ! -f "$briefing_script_i" ]]; then
    log_fail "Section I: literature-briefing.sh not found relative to $SCRIPT_DIR"
    return
  fi

  if ! command -v sqlite3 >/dev/null 2>&1; then
    log_warn "Section I: sqlite3 not available -- skipping (cannot build a real FTS5 fixture)"
    return
  fi

  TEMP_LIT_DIR_I=$(mktemp -d)

  # --- Fixture global index: five top-level documents, all verified_conversion so
  # none is quarantined by do_search's/do_multi_search's fidelity filter. No
  # project_tags on any entry, so literature-search.sh's project filter (get_project_doc_ids)
  # matches every entry regardless of the repo_name literature-briefing.sh derives. ---
  cat > "$TEMP_LIT_DIR_I/index.json" <<'IINDEX'
{
  "entries": [
    {"id": "doc_alpha", "doc_id": "doc_alpha", "parent_doc": null, "path": "sources/doc_alpha/", "title": "Representation Theorem", "provenance_fidelity": "verified_conversion"},
    {"id": "doc_beta", "doc_id": "doc_beta", "parent_doc": null, "path": "sources/doc_beta/", "title": "Coalgebraic Semantics", "provenance_fidelity": "verified_conversion"},
    {"id": "doc_gamma", "doc_id": "doc_gamma", "parent_doc": null, "path": "sources/doc_gamma/", "title": "Bisimulation", "provenance_fidelity": "verified_conversion"},
    {"id": "doc_delta", "doc_id": "doc_delta", "parent_doc": null, "path": "sources/doc_delta/", "title": "Duality Theory", "provenance_fidelity": "verified_conversion"},
    {"id": "doc_epsilon", "doc_id": "doc_epsilon", "parent_doc": null, "path": "sources/doc_epsilon/", "title": "Cooking Recipes", "provenance_fidelity": "verified_conversion"}
  ]
}
IINDEX

  sqlite3 "$TEMP_LIT_DIR_I/.literature.db" < "$SCRIPT_DIR/literature-schema.sql"

  # --- Fixture chunks: terms are spread across chunks so the words a query needs
  # never appear contiguously in one place (the phrase_retry rung is syntax-safe but
  # recall-narrow, so this fixture must be un-findable via a whole-query phrase
  # match -- only per-term OR-of-AND-groups recall reaches it), and several chunks
  # deliberately share terms (I4's dedupe case) while one (doc_epsilon) shares none
  # (the off-corpus control for I2). ---
  sqlite3 "$TEMP_LIT_DIR_I/.literature.db" <<'ISQL'
INSERT INTO chunks_data (chunk_id, doc_id, section_path, title, keywords, summary, content, source_path)
VALUES
('i_c1','doc_alpha','Ch1 > Representation','Representation Theorem','representation modal theorem','About representation','This chunk discusses representation theorem for modal logic frames in depth.','doc_alpha/i_c1.md'),
('i_c2','doc_beta','Ch2 > Coalgebra','Coalgebraic Semantics','coalgebra modal semantics','About coalgebra','Coalgebraic modal logic generalizes Kripke frames using functor based semantics.','doc_beta/i_c2.md'),
('i_c3','doc_gamma','Ch3 > Bisimulation','Bisimulation','bisimulation modal invariance','About bisimulation','Bisimulation is a key notion relating modal logic frames and representation theorem.','doc_gamma/i_c3.md'),
('i_c4','doc_delta','Ch4 > Duality','Duality Theory','duality modal representation','About duality','Duality theory connects modal algebra representation and frames directly.','doc_delta/i_c4.md'),
('i_c5','doc_epsilon','Ch1 > Intro','Cooking Recipes','cooking recipes kitchen','About cooking','This document is entirely about cooking recipes and kitchen techniques, unrelated to logic.','doc_epsilon/i_c5.md');
INSERT INTO chunks_fts(rowid, title, keywords, summary, content)
  SELECT id, title, keywords, summary, content FROM chunks_data;
ISQL

  # --- Case I1: the core regression -- a long, realistic multi-word query including a
  # literal `<sec:representation>` token returns a non-empty result set. This case
  # must fail against the pre-fix scripts (no AND-all-terms query below matches all
  # words in one chunk, and the unhandled `<`/`>` used to raise a hard syntax error). ---
  local i1_query="Investigate the representation theorem for modal logic frames using coalgebraic semantics <sec:representation>"
  local i1_out i1_seg_count
  i1_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "$i1_query" --top-n 8 2>/dev/null)
  i1_seg_count=$(echo "$i1_out" | grep -oP '(?<=seg_count=)\d+' | head -1)
  if [[ -n "$i1_seg_count" ]] && [[ "$i1_seg_count" -gt 0 ]]; then
    log_pass "Case I1 (core regression): --global returned seg_count=$i1_seg_count (non-empty) for a long query with a literal <sec:representation> token"
  else
    log_fail "Case I1 (core regression): --global returned zero segments (or no marker) for the long query. Got: $i1_out"
  fi
  if echo "$i1_out" | grep -q 'doc_alpha\|doc_beta\|doc_gamma\|doc_delta'; then
    log_pass "Case I1 (core regression): result body references at least one topically relevant doc_id"
  else
    log_fail "Case I1 (core regression): no expected doc_id found in result body"
  fi

  # --- Case I2: sparse honesty at the exact threshold boundary ---
  # I2a: genuinely off-corpus query -> sparse=true (0 < LITERATURE_SPARSE_THRESHOLD default 3).
  local i2a_out i2a_marker
  i2a_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "quantum chromodynamics particle accelerator" --top-n 8 2>/dev/null)
  i2a_marker=$(echo "$i2a_out" | grep -- '<!-- lit-coverage')
  if echo "$i2a_marker" | grep -q 'seg_count=0' && echo "$i2a_marker" | grep -q 'sparse=true'; then
    log_pass "Case I2a (sparse honesty, below threshold): off-corpus query yields seg_count=0 sparse=true"
  else
    log_fail "Case I2a (sparse honesty, below threshold): unexpected marker. Got: $i2a_marker"
  fi
  # I2b: "theorem duality" matches exactly 3 distinct chunks (i_c1, i_c3 via "theorem";
  # i_c4 via "duality") -- exactly LITERATURE_SPARSE_THRESHOLD (default 3), so sparse
  # must be false (the boundary is strict `<`, never `<=`).
  local i2b_out i2b_marker
  i2b_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "theorem duality" --top-n 8 2>/dev/null)
  i2b_marker=$(echo "$i2b_out" | grep -- '<!-- lit-coverage')
  if echo "$i2b_marker" | grep -q 'seg_count=3' && echo "$i2b_marker" | grep -q 'sparse=false'; then
    log_pass "Case I2b (sparse honesty, at threshold): query matching exactly 3 distinct chunks yields seg_count=3 sparse=false"
  else
    log_fail "Case I2b (sparse honesty, at threshold): unexpected marker (expected seg_count=3 sparse=false). Got: $i2b_marker"
  fi

  # --- Case I3: error isolation ---
  # I3a: every filtered term is FTS5-hostile (a leading hyphen survives sanitize_query
  # unchanged -- only MID-word hyphens are folded -- and raises "no such column" from
  # FTS5's column-filter grammar) -> a non-null query_error must surface.
  local i3a_out
  i3a_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "-hostileterm1 -hostileterm2" --top-n 8 2>/dev/null)
  if echo "$i3a_out" | grep -qi 'syntax error\|Note: the original query triggered'; then
    log_pass "Case I3a (error isolation, all-hostile): non-null query_error surfaced in the briefing body"
  else
    log_fail "Case I3a (error isolation, all-hostile): expected a surfaced query_error message. Got: $i3a_out"
  fi
  # I3b: one hostile term mixed with a valid term ("theorem", matching i_c1/i_c3) ->
  # results are returned and no hard query_error is surfaced (one bad term must never
  # poison the whole multi-query response).
  local i3b_out
  i3b_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "-hostileterm1 theorem" --top-n 8 2>/dev/null)
  if echo "$i3b_out" | grep -q 'seg_count=[1-9]' && ! echo "$i3b_out" | grep -qi 'syntax error\|Note: the original query triggered'; then
    log_pass "Case I3b (error isolation, mixed): one hostile term among valid ones still returns results with no hard query_error"
  else
    log_fail "Case I3b (error isolation, mixed): expected non-zero seg_count and no surfaced query_error. Got: $i3b_out"
  fi

  # --- Case I4: dedupe -- "representation duality" is a genuine two-term merge case
  # (unlike a single-term query, which cannot exercise cross-term dedup at all): i_c4
  # is the ONLY chunk matching both terms (title "Duality Theory", keywords "duality
  # modal representation", content repeats both words), while "representation" alone
  # additionally matches i_c1 and i_c3. Pre-fix AND-all-terms semantics only ever
  # return i_c4 (seg_count=1) since no chunk need be deduped across separate queries
  # in a single bareword MATCH; this case demonstrably fails pre-fix. Post-fix, the
  # per-term merge must count i_c4 exactly ONCE (not twice, despite matching both
  # "representation" and "duality") alongside i_c1/i_c3, for seg_count=3.
  local i4_out i4_marker i4_body_hits
  i4_out=$(LITERATURE_DIR="$TEMP_LIT_DIR_I" bash "$briefing_script_i" --global "representation duality" --top-n 8 2>/dev/null)
  i4_marker=$(echo "$i4_out" | grep -- '<!-- lit-coverage')
  if echo "$i4_marker" | grep -q 'seg_count=3'; then
    log_pass "Case I4 (dedupe): two-term query matching 3 distinct chunks (one via both terms) reports seg_count=3"
  else
    log_fail "Case I4 (dedupe): expected seg_count=3. Got: $i4_marker"
  fi
  i4_body_hits=$(echo "$i4_out" | grep -c '^   Read: `bash .claude/scripts/literature-search.sh --read i_c4`$')
  if [[ "$i4_body_hits" -eq 1 ]]; then
    log_pass "Case I4 (dedupe): chunk i_c4 (matched by both terms) appears exactly once in the rendered body"
  else
    log_fail "Case I4 (dedupe): chunk i_c4 appears $i4_body_hits times in the rendered body (expected exactly once)"
  fi

  # --- Marker field order/adjacency: the eight original fields stay byte-adjacent
  # and in order, with the delta_* fields strictly after them, so
  # lit-stage4a-flow.md's `lit-coverage mode=global .*sparse=true` grep keeps matching. ---
  if echo "$i2a_marker" | grep -qP '^<!-- lit-coverage mode=global seg_count=\d+ sparse=(true|false) threshold=\d+ requested=\d+ resolved=\d+ skipped=\d+ skip_rate=\d+ delta_checked=(true|false) delta_gap=\d+ delta_candidates=\d+ -->$'; then
    log_pass "Marker field order/adjacency: the eight original fields plus delta_* stay in the documented order"
  else
    log_fail "Marker field order/adjacency: unexpected field order/shape. Got: $i2a_marker"
  fi

  log_info "Section I complete. Temp corpus will be cleaned up."
}

# ============================================================
# MAIN
# ============================================================
main() {
  echo "========================================"
  echo "--lit Pipeline Integration Test"
  echo "========================================"
  log_info "Project root: $PROJECT_ROOT"
  if [[ "$RUN_RUNTIME" == "true" ]]; then
    log_info "Mode: static + runtime smoke test (--runtime)"
  else
    log_info "Mode: static checks only (pass --runtime for smoke test)"
  fi

  section_a
  section_b
  section_c
  section_d

  if [[ "$RUN_RUNTIME" == "true" ]]; then
    section_e
    section_f
    section_g
    section_h
    section_i
  fi

  # --- Summary ---
  echo ""
  echo "========================================"
  echo "Test Summary"
  echo "========================================"
  echo -e "Passed:   ${GREEN}$PASSED${NC}"
  echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
  echo -e "Failed:   ${RED}$FAILED${NC}"
  echo ""

  if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}PIPELINE TEST FAILED${NC}"
    exit 1
  elif [[ "$WARNINGS" -gt 0 ]]; then
    echo -e "${YELLOW}PIPELINE TEST PASSED WITH WARNINGS${NC}"
    exit 0
  else
    echo -e "${GREEN}PIPELINE TEST PASSED${NC}"
    exit 0
  fi
}

main "$@"
