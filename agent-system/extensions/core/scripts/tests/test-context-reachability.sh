#!/usr/bin/env bash
# test-context-reachability.sh - Fixture-driven regression suite for context-reachability.sh.
#
# Cases:
#   Enumeration        -- a fixture with a context .md, a non-context .md, and a non-.md file
#                         enumerates exactly the context .md.
#   Style 1 (filename)  -- a referrer outside context/ naming a candidate's basename yields
#                         reachable_by_filename: true and "filename" in reachable_styles.
#   Style 2, present-shape -- a directory-only reference (zero basename mentions anywhere)
#                         yields reachable: true with reachable_styles == ["directory"] exactly.
#   Style 2, founder-shape -- the same directory reference PLUS a basename mention living inside
#                         another context/ file, with the directory referrer using a DIFFERENT
#                         path prefix than the file's real location, yields reachable: true with
#                         BOTH "directory" and "filename" recorded.
#   Style 3 (index)     -- an index-entries.json entry with non-empty load_when yields "index" in
#                         reachable_styles; a sibling entry with an empty load_when and no
#                         always:true does not.
#   Genuine orphan      -- a context file referenced by nothing at all reports reachable: false,
#                         zero_reference_finding: true, and makes --check exit non-zero.
#   Eager degradation   -- a fixture with no CLAUDE.md chain reports eager: null, exit 0.
#   No .claude/** reads -- a fixture with both a real context tree and a decoy .claude/context/**
#                         tree never surfaces the decoy path anywhere in the output.
#   Reproducibility     -- two consecutive default-mode runs against the same root are
#                         byte-identical modulo generated_at.
#   No side effects     -- a before/after find-based manifest of the fixture root is unchanged.
#   Degenerate root / usage error -- as in test-script-inventory.sh.
#   LIVE-TREE REGRESSION PROPERTY -- every file under present's talk/contents/** and founder's
#                         deck/contents/** reports reachable: true with "directory" among its
#                         styles, combined count >= 39 (never a hardcoded exact total).
#
# Structural model: test-script-inventory.sh (pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, deploy-tree-first/source-store-fallback resolution, mk_git_fixture()).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (context-reachability.sh not found, or jq unavailable).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

TOOL_CANDIDATES=(
  "$REPO_ROOT/.claude/scripts/context-reachability.sh"
  "$SCRIPT_DIR/../context-reachability.sh"
)
TOOL=""
for candidate in "${TOOL_CANDIDATES[@]}"; do
  if [[ -f "$candidate" ]]; then
    TOOL="$candidate"
    break
  fi
done
if [[ -z "$TOOL" ]]; then
  echo "ERROR: context-reachability.sh not found at any of:" >&2
  for candidate in "${TOOL_CANDIDATES[@]}"; do
    echo "  $candidate" >&2
  done
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; cannot exercise context-reachability.sh" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mk_git_fixture() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "test"
}

# =====================================================================
# Enumeration: context .md + non-context .md + non-.md file.
# =====================================================================
ENUM_DIR="$WORKDIR/enum"
mkdir -p "$ENUM_DIR/agent-system/extensions/core/context" "$ENUM_DIR/agent-system/extensions/core/scripts"
echo "ctx" > "$ENUM_DIR/agent-system/extensions/core/context/ctx.md"
echo "notctx" > "$ENUM_DIR/agent-system/extensions/core/scripts/notctx.md"
echo "nonmd" > "$ENUM_DIR/agent-system/extensions/core/context/nonmd.txt"
mk_git_fixture "$ENUM_DIR"
git -C "$ENUM_DIR" add -A
git -C "$ENUM_DIR" commit -q -m init

ENUM_OUT="$(bash "$TOOL" --root "$ENUM_DIR" 2>"$WORKDIR/enum_stderr")"
enum_count="$(echo "$ENUM_OUT" | jq -r '.candidate_count')"
enum_paths="$(echo "$ENUM_OUT" | jq -r '.files[].path')"
if [ "$enum_count" = "1" ] && [ "$enum_paths" = "agent-system/extensions/core/context/ctx.md" ]; then
  pass "enumeration: candidate_count == 1, only the context .md enumerated"
else
  fail "enumeration: count=$enum_count paths=[$enum_paths] (expected 1, ctx.md only); stderr: $(cat "$WORKDIR/enum_stderr")"
fi

# =====================================================================
# Style 1 (filename): a referrer outside context/ naming the candidate's basename.
# =====================================================================
S1_DIR="$WORKDIR/style1"
mkdir -p "$S1_DIR/agent-system/extensions/core/context/standards" "$S1_DIR/agent-system/extensions/core/agents"
echo "some policy text" > "$S1_DIR/agent-system/extensions/core/context/standards/unique-style1-file.md"
echo "see unique-style1-file.md for the policy" > "$S1_DIR/agent-system/extensions/core/agents/some-agent.md"
mk_git_fixture "$S1_DIR"
git -C "$S1_DIR" add -A
git -C "$S1_DIR" commit -q -m init

S1_OUT="$(bash "$TOOL" --root "$S1_DIR" 2>"$WORKDIR/s1_stderr")"
s1_reachable_filename="$(echo "$S1_OUT" | jq -r '.files[0].reachable_by_filename')"
s1_styles="$(echo "$S1_OUT" | jq -r '.files[0].reachable_styles | join(",")')"
if [ "$s1_reachable_filename" = "true" ] && [[ "$s1_styles" == *"filename"* ]]; then
  pass "style 1: outside-context referrer naming the basename yields reachable_by_filename and 'filename' in styles"
else
  fail "style 1: reachable_by_filename=$s1_reachable_filename styles=[$s1_styles]; stderr: $(cat "$WORKDIR/s1_stderr")"
fi

# =====================================================================
# Style 2, present-shape: directory-only reference, zero basename mentions anywhere.
# =====================================================================
S2P_DIR="$WORKDIR/style2present"
mkdir -p "$S2P_DIR/agent-system/extensions/present/context/project/present/talk/contents/zzzcat" "$S2P_DIR/agent-system/extensions/present/agents"
echo "slide body, never named by basename anywhere" > "$S2P_DIR/agent-system/extensions/present/context/project/present/talk/contents/zzzcat/zzzcat-slide.md"
echo 'Slides: talk/contents/zzzcat/' > "$S2P_DIR/agent-system/extensions/present/agents/assembly-agent.md"
mk_git_fixture "$S2P_DIR"
git -C "$S2P_DIR" add -A
git -C "$S2P_DIR" commit -q -m init

S2P_OUT="$(bash "$TOOL" --root "$S2P_DIR" 2>"$WORKDIR/s2p_stderr")"
s2p_reachable="$(echo "$S2P_OUT" | jq -r '.files[0].reachable')"
s2p_styles="$(echo "$S2P_OUT" | jq -c '.files[0].reachable_styles')"
if [ "$s2p_reachable" = "true" ] && [ "$s2p_styles" = '["directory"]' ]; then
  pass "style 2 (present-shape): directory-only reference yields reachable_styles == [\"directory\"] exactly"
else
  fail "style 2 (present-shape): reachable=$s2p_reachable styles=$s2p_styles (expected true, [\"directory\"]); stderr: $(cat "$WORKDIR/s2p_stderr")"
fi

# =====================================================================
# Style 2, founder-shape: directory reference (different path prefix) PLUS a basename mention
# living inside ANOTHER context/ file.
# =====================================================================
S2F_DIR="$WORKDIR/style2founder"
mkdir -p "$S2F_DIR/agent-system/extensions/founder/context/project/founder/deck/contents/zzzcat" \
  "$S2F_DIR/agent-system/extensions/founder/context/project/founder/patterns" \
  "$S2F_DIR/agent-system/extensions/founder/agents"
echo "slide body" > "$S2F_DIR/agent-system/extensions/founder/context/project/founder/deck/contents/zzzcat/zzzcat-slide.md"
# A DIFFERENT path prefix than the file's real location (founder's own ".context/deck/contents/"
# agent-prose quirk), referencing only the generic top-level directory with no subdirectory name.
echo 'Read from `.context/deck/contents/{path}`' > "$S2F_DIR/agent-system/extensions/founder/agents/builder-agent.md"
# Basename mention inside ANOTHER context/ file (not the candidate itself).
echo 'src: ../../.context/deck/contents/zzzcat/zzzcat-slide.md' > "$S2F_DIR/agent-system/extensions/founder/context/project/founder/patterns/template.md"
mk_git_fixture "$S2F_DIR"
git -C "$S2F_DIR" add -A
git -C "$S2F_DIR" commit -q -m init

S2F_OUT="$(bash "$TOOL" --root "$S2F_DIR" 2>"$WORKDIR/s2f_stderr")"
s2f_candidate="$(echo "$S2F_OUT" | jq -r '.files[] | select(.path | test("zzzcat-slide.md"))')"
s2f_reachable="$(echo "$s2f_candidate" | jq -r '.reachable')"
s2f_styles="$(echo "$s2f_candidate" | jq -c '.reachable_styles | sort')"
if [ "$s2f_reachable" = "true" ] && [ "$s2f_styles" = '["directory","filename"]' ]; then
  pass "style 2 (founder-shape): prefix-mismatched directory reference PLUS a context-file basename mention yields BOTH styles"
else
  fail "style 2 (founder-shape): reachable=$s2f_reachable styles=$s2f_styles (expected true, [\"directory\",\"filename\"]); stderr: $(cat "$WORKDIR/s2f_stderr")"
fi

# =====================================================================
# Style 3 (index): a non-empty load_when entry fires; an empty-load_when sibling does not.
# =====================================================================
S3_DIR="$WORKDIR/style3"
mkdir -p "$S3_DIR/agent-system/extensions/widgets/context"
echo "indexed content" > "$S3_DIR/agent-system/extensions/widgets/context/onlyindex.md"
echo "not indexed, not referenced" > "$S3_DIR/agent-system/extensions/widgets/context/noindex.md"
cat > "$S3_DIR/agent-system/extensions/widgets/index-entries.json" <<'EOF'
{
  "entries": [
    {"path": "onlyindex.md", "load_when": {"agents": [], "task_types": [], "commands": ["/widget"]}},
    {"path": "noindex.md", "load_when": {"agents": [], "task_types": [], "commands": []}}
  ]
}
EOF
mk_git_fixture "$S3_DIR"
git -C "$S3_DIR" add -A
git -C "$S3_DIR" commit -q -m init

S3_OUT="$(bash "$TOOL" --root "$S3_DIR" 2>"$WORKDIR/s3_stderr")"
s3_only_index="$(echo "$S3_OUT" | jq -r '.files[] | select(.path | test("onlyindex.md")) | .reachable_by_index')"
s3_only_styles="$(echo "$S3_OUT" | jq -c '.files[] | select(.path | test("onlyindex.md")) | .reachable_styles')"
# NOTE: index-entries.json's own content literally contains the string "onlyindex.md" (its JSON
# path VALUE) and lives outside context/ in this fixture, so style 1 (whole-source-store
# basename scope, by design -- see the probe's header) legitimately ALSO fires here. The plan's
# own requirement is that "index" appears among reachable_styles, not that it appears alone;
# assert containment, not exclusivity.
if [ "$s3_only_index" = "true" ] && [[ "$s3_only_styles" == *'"index"'* ]]; then
  pass "style 3: non-empty load_when entry yields reachable_by_index and 'index' in styles"
else
  fail "style 3: onlyindex.md reachable_by_index=$s3_only_index styles=$s3_only_styles; stderr: $(cat "$WORKDIR/s3_stderr")"
fi
s3_no_index="$(echo "$S3_OUT" | jq -r '.files[] | select(.path | test("noindex.md")) | .reachable_by_index')"
if [ "$s3_no_index" = "false" ]; then
  pass "style 3: empty-load_when sibling (no always:true) does NOT report reachable_by_index"
else
  fail "style 3: noindex.md reachable_by_index=$s3_no_index (expected false)"
fi

# =====================================================================
# Genuine orphan: referenced by nothing at all.
# =====================================================================
ORPHAN_DIR="$WORKDIR/orphan"
mkdir -p "$ORPHAN_DIR/agent-system/extensions/core/context"
echo "truly unreferenced content" > "$ORPHAN_DIR/agent-system/extensions/core/context/trulyorphanedfile.md"
mk_git_fixture "$ORPHAN_DIR"
git -C "$ORPHAN_DIR" add -A
git -C "$ORPHAN_DIR" commit -q -m init

ORPHAN_OUT="$(bash "$TOOL" --root "$ORPHAN_DIR" 2>"$WORKDIR/orphan_stderr")"
orphan_reachable="$(echo "$ORPHAN_OUT" | jq -r '.files[0].reachable')"
orphan_finding="$(echo "$ORPHAN_OUT" | jq -r '.files[0].zero_reference_finding')"
if [ "$orphan_reachable" = "false" ] && [ "$orphan_finding" = "true" ]; then
  pass "genuine orphan: reachable == false, zero_reference_finding == true"
else
  fail "genuine orphan: reachable=$orphan_reachable zero_reference_finding=$orphan_finding; stderr: $(cat "$WORKDIR/orphan_stderr")"
fi

set +e
bash "$TOOL" --root "$ORPHAN_DIR" --check >/dev/null 2>"$WORKDIR/orphan_check_stderr"
orphan_check_exit=$?
set -e 2>/dev/null || true
if [ "$orphan_check_exit" -eq 1 ]; then
  pass "genuine orphan: --check exits non-zero (1) on the orphaned fixture"
else
  fail "genuine orphan: --check exited $orphan_check_exit (expected 1)"
fi

# =====================================================================
# Eager degradation: no CLAUDE.md chain reports eager: null, exit 0.
# =====================================================================
EAGER_DIR="$WORKDIR/eagerdegrade"
mkdir -p "$EAGER_DIR/agent-system/extensions/core/context" "$EAGER_DIR/agent-system/extensions/core/agents"
echo "content" > "$EAGER_DIR/agent-system/extensions/core/context/degraded.md"
echo "see degraded.md" > "$EAGER_DIR/agent-system/extensions/core/agents/x.md"
mk_git_fixture "$EAGER_DIR"
git -C "$EAGER_DIR" add -A
git -C "$EAGER_DIR" commit -q -m init

if EAGER_OUT="$(bash "$TOOL" --root "$EAGER_DIR" 2>"$WORKDIR/eager_stderr")"; then
  eager_val="$(echo "$EAGER_OUT" | jq -r '.files[0].eager')"
  eager_summary_count="$(echo "$EAGER_OUT" | jq -r '.summary.eager_count')"
  lazy_summary_count="$(echo "$EAGER_OUT" | jq -r '.summary.lazy_count')"
  if [ "$eager_val" = "null" ] && [ "$eager_summary_count" = "null" ] && [ "$lazy_summary_count" = "null" ]; then
    pass "eager degradation: no CLAUDE.md chain -> eager:null and summary eager_count/lazy_count:null, exit 0"
  else
    fail "eager degradation: eager=$eager_val summary.eager_count=$eager_summary_count summary.lazy_count=$lazy_summary_count (expected null/null/null)"
  fi
else
  fail "eager degradation: context-reachability.sh exited non-zero; stderr: $(cat "$WORKDIR/eager_stderr")"
fi

# =====================================================================
# Never reads .claude/**: a decoy .claude/context/** tree must never surface in the output.
# =====================================================================
DECOY_DIR="$WORKDIR/decoy"
mkdir -p "$DECOY_DIR/agent-system/extensions/core/context" "$DECOY_DIR/.claude/context"
echo "real" > "$DECOY_DIR/agent-system/extensions/core/context/real.md"
echo "decoy, must never appear" > "$DECOY_DIR/.claude/context/decoy-should-not-appear.md"
mk_git_fixture "$DECOY_DIR"
git -C "$DECOY_DIR" add -A
git -C "$DECOY_DIR" commit -q -m init

DECOY_OUT="$(bash "$TOOL" --root "$DECOY_DIR" 2>"$WORKDIR/decoy_stderr")"
if echo "$DECOY_OUT" | grep -q "decoy-should-not-appear"; then
  fail "no .claude/** reads: decoy path leaked into probe output"
else
  pass "no .claude/** reads: decoy .claude/context/** path never appears in probe output"
fi

# =====================================================================
# Reproducibility: two consecutive default-mode runs are identical modulo generated_at.
# =====================================================================
REPRO_RUN1="$(bash "$TOOL" --root "$S2F_DIR" 2>/dev/null | jq 'del(.generated_at)')"
REPRO_RUN2="$(bash "$TOOL" --root "$S2F_DIR" 2>/dev/null | jq 'del(.generated_at)')"
if [ "$REPRO_RUN1" = "$REPRO_RUN2" ]; then
  pass "reproducibility: two consecutive runs on the same fixture are identical modulo generated_at"
else
  fail "reproducibility: two consecutive runs diverged"
fi

# =====================================================================
# No side effects: before/after find-based manifest of the fixture root is unchanged.
# =====================================================================
before_manifest="$(find "$S2F_DIR" -type f | sort)"
bash "$TOOL" --root "$S2F_DIR" >/dev/null 2>"$WORKDIR/nofx_stderr"
after_manifest="$(find "$S2F_DIR" -type f | sort)"
if [ "$before_manifest" = "$after_manifest" ]; then
  pass "no side effects: fixture root file manifest unchanged across a run"
else
  fail "no side effects: fixture root file manifest changed"
fi

# =====================================================================
# Degenerate root: no agent-system/extensions/ tree at all.
# =====================================================================
DEGENERATE_DIR="$WORKDIR/degenerate"
mkdir -p "$DEGENERATE_DIR"
if DEGEN_OUT="$(bash "$TOOL" --root "$DEGENERATE_DIR" 2>"$WORKDIR/degen_stderr")"; then
  degen_count="$(echo "$DEGEN_OUT" | jq -r '.candidate_count')"
  degen_files_len="$(echo "$DEGEN_OUT" | jq -r '.files | length')"
  degen_summary="$(echo "$DEGEN_OUT" | jq -c '.summary')"
  if [ "$degen_count" = "0" ] && [ "$degen_files_len" = "0" ] && [ "$degen_summary" = "null" ]; then
    pass "degenerate root: candidate_count 0, files [], summary null"
  else
    fail "degenerate root: count=$degen_count files_len=$degen_files_len summary=$degen_summary"
  fi
else
  fail "degenerate root: context-reachability.sh exited non-zero; stderr: $(cat "$WORKDIR/degen_stderr")"
fi

# =====================================================================
# Usage error: --root with no following argument exits 1.
# =====================================================================
set +e
bash "$TOOL" --root >/dev/null 2>"$WORKDIR/usage_stderr"
usage_exit=$?
set -e 2>/dev/null || true
if [ "$usage_exit" -eq 1 ]; then
  pass "usage error: --root with no argument exits 1"
else
  fail "usage error: --root with no argument exited $usage_exit (expected 1)"
fi

# =====================================================================
# LIVE-TREE REGRESSION PROPERTY: every file under present's talk/contents/** and founder's
# deck/contents/** reports reachable:true with "directory" among its styles, floor >= 39.
# =====================================================================
PRESENT_DIR="$REPO_ROOT/agent-system/extensions/present/context/project/present/talk/contents"
FOUNDER_DIR="$REPO_ROOT/agent-system/extensions/founder/context/project/founder/deck/contents"
if [ -d "$PRESENT_DIR" ] && [ -d "$FOUNDER_DIR" ]; then
  LIVE_OUT="$(bash "$TOOL" --root "$REPO_ROOT" 2>"$WORKDIR/live_stderr")"
  live_rc=$?
  if [ "$live_rc" -eq 0 ]; then
    covered_total="$(echo "$LIVE_OUT" | jq -r '
      [.files[]
        | select(.path | test("present/context/project/present/talk/contents/|founder/context/project/founder/deck/contents/"))
        | select(.reachable == true and (.reachable_styles | index("directory")))
      ] | length')"
    not_covered="$(echo "$LIVE_OUT" | jq -r '
      [.files[]
        | select(.path | test("present/context/project/present/talk/contents/|founder/context/project/founder/deck/contents/"))
        | select((.reachable == true and (.reachable_styles | index("directory"))) | not)
        | .path
      ] | join(", ")')"
    if [ "$covered_total" -ge 39 ] && [ -z "$not_covered" ]; then
      pass "live-tree regression property: $covered_total present+founder template files report reachable:true with 'directory' in styles (floor 39)"
    else
      fail "live-tree regression property: covered_total=$covered_total (expected >= 39), uncovered=[$not_covered]; stderr: $(cat "$WORKDIR/live_stderr")"
    fi
  else
    fail "live-tree regression property: context-reachability.sh exited $live_rc against the live repo root; stderr: $(cat "$WORKDIR/live_stderr")"
  fi
else
  info "live-tree regression property: present/founder template directories not found under $REPO_ROOT -- skipping (not a failure)"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
