#!/usr/bin/env bash
# test-lean-mcp-registration.sh -- writer-level regression suite for setup-lean-mcp.sh's
# per-project (--scope project) registration path, plus --retire-global.
#
# Complements test-lean-mcp-preflight-check.sh, which proves the WRAPPER's message selection is
# correct given an already-written config; this suite proves the WRITER itself produces that
# config correctly in the first place:
#
#   (1) --scope project on a config with no .projects key at all creates the full path
#       (.projects, then the project's own key, then .mcpServers) and the canonical entry.
#   (2) A second identical run is a byte-for-byte no-op (idempotent).
#   (3) A divergent entry (wrong command AND wrong project path) is replaced WHOLESALE, not
#       patched field-by-field.
#   (4) --dry-run mutates nothing, even against a divergent entry.
#   (5) --retire-global removes ONLY the top-level global entry, leaving .projects untouched.
#   (6) Two different project paths registered in sequence both survive, each with its own,
#       independent LEAN_PROJECT_PATH.
#
# Falsifiability / mutation check: a mutated copy of setup-lean-mcp.sh with the whole-entry
# comparison (`$a == $b`) replaced by an always-true predicate is run against case (3)'s
# divergent-entry fixture. Pre-mutation, the divergent entry is replaced (case 3 above).
# Post-mutation, with the comparison always reporting a match, the writer must report "already
# configured correctly" and leave the DIVERGENT entry in place unchanged -- proving case (3)
# actually depends on that comparison being real, not vacuously true.
#
# Follows the core shell-test convention (context/standards/shell-script-testing.md): Class B
# (`set -uo pipefail`, no `-e`) counter-idiom harness with pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, a single mktemp -d workdir with a trap EXIT cleanup, exit 0 on
# all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITER_SRC="$SCRIPT_DIR/../setup-lean-mcp.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$WRITER_SRC" ]; then
  echo "ERROR: expected setup-lean-mcp.sh at $WRITER_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

make_lean_project() {
  local dir="$1"
  mkdir -p "$dir"
  touch "$dir/lakefile.lean"
}

# =====================================================================
# Case 1: no .projects key at all -> full path + canonical entry created.
# =====================================================================
HOME1="$WORKDIR/case1/home"
PROJ1="$WORKDIR/case1/proj"
mkdir -p "$HOME1"
make_lean_project "$PROJ1"
echo '{}' > "$HOME1/.claude.json"

HOME="$HOME1" bash "$WRITER_SRC" --project "$PROJ1" --scope project > /dev/null 2>&1
ENTRY1=$(jq -c --arg p "$PROJ1" '.projects[$p].mcpServers."lean-lsp"' "$HOME1/.claude.json")
EXPECTED1=$(jq -c -n --arg p "$PROJ1" '{"type":"stdio","command":"uvx","args":["lean-lsp-mcp"],"env":{"LEAN_LOG_LEVEL":"WARNING","LEAN_PROJECT_PATH":$p}}')

if [ "$ENTRY1" = "$EXPECTED1" ]; then
  pass "Case 1: --scope project on a config with no .projects key creates the canonical entry"
else
  fail "Case 1: expected $EXPECTED1, got $ENTRY1"
fi

# =====================================================================
# Case 2: second identical run is a byte-for-byte no-op.
# =====================================================================
BEFORE2=$(md5sum "$HOME1/.claude.json" | awk '{print $1}')
HOME="$HOME1" bash "$WRITER_SRC" --project "$PROJ1" --scope project > /dev/null 2>&1
AFTER2=$(md5sum "$HOME1/.claude.json" | awk '{print $1}')

if [ "$BEFORE2" = "$AFTER2" ]; then
  pass "Case 2: second identical run is a byte-for-byte no-op"
else
  fail "Case 2: file changed on a no-op run (before=$BEFORE2 after=$AFTER2)"
fi

# =====================================================================
# Case 3: divergent entry (wrong command AND wrong project path) replaced WHOLESALE.
# =====================================================================
HOME3="$WORKDIR/case3/home"
PROJ3="$WORKDIR/case3/proj"
OTHER3="$WORKDIR/case3/other"
mkdir -p "$HOME3"
make_lean_project "$PROJ3"
make_lean_project "$OTHER3"
jq -n --arg p "$PROJ3" --arg other "$OTHER3" \
  '{"projects": {($p): {"mcpServers": {"lean-lsp": {"command": "/bad/wrapper.sh", "args": [], "env": {"LEAN_PROJECT_PATH": $other}}}}}}' \
  > "$HOME3/.claude.json"

HOME="$HOME3" bash "$WRITER_SRC" --project "$PROJ3" --scope project > /dev/null 2>&1
ENTRY3=$(jq -c --arg p "$PROJ3" '.projects[$p].mcpServers."lean-lsp"' "$HOME3/.claude.json")
EXPECTED3=$(jq -c -n --arg p "$PROJ3" '{"type":"stdio","command":"uvx","args":["lean-lsp-mcp"],"env":{"LEAN_LOG_LEVEL":"WARNING","LEAN_PROJECT_PATH":$p}}')

if [ "$ENTRY3" = "$EXPECTED3" ]; then
  pass "Case 3: divergent entry (wrong command AND wrong path) replaced wholesale with the canonical shape"
else
  fail "Case 3: expected $EXPECTED3, got $ENTRY3"
fi

# =====================================================================
# Case 4: --dry-run mutates nothing, even against a divergent entry.
# =====================================================================
HOME4="$WORKDIR/case4/home"
PROJ4="$WORKDIR/case4/proj"
mkdir -p "$HOME4"
make_lean_project "$PROJ4"
jq -n --arg p "$PROJ4" \
  '{"projects": {($p): {"mcpServers": {"lean-lsp": {"command": "/bad/wrapper.sh", "args": [], "env": {"LEAN_PROJECT_PATH": $p}}}}}}' \
  > "$HOME4/.claude.json"
BEFORE4=$(md5sum "$HOME4/.claude.json" | awk '{print $1}')
HOME="$HOME4" bash "$WRITER_SRC" --project "$PROJ4" --scope project --dry-run > /dev/null 2>&1
AFTER4=$(md5sum "$HOME4/.claude.json" | awk '{print $1}')

if [ "$BEFORE4" = "$AFTER4" ]; then
  pass "Case 4: --dry-run mutates nothing, even against a divergent entry"
else
  fail "Case 4: --dry-run changed the file (before=$BEFORE4 after=$AFTER4)"
fi

# =====================================================================
# Case 5: --retire-global removes ONLY the top-level global entry, leaving .projects untouched.
# =====================================================================
HOME5="$WORKDIR/case5/home"
PROJ5="$WORKDIR/case5/proj"
mkdir -p "$HOME5"
make_lean_project "$PROJ5"
jq -n --arg p "$PROJ5" \
  '{"projects": {($p): {"mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"], "env": {"LEAN_PROJECT_PATH": $p}}}}}, "mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"], "env": {"LEAN_PROJECT_PATH": $p}}}}' \
  > "$HOME5/.claude.json"

HOME="$HOME5" bash "$WRITER_SRC" --retire-global > /dev/null 2>&1
GLOBAL5=$(jq -c '.mcpServers."lean-lsp" // "ABSENT"' "$HOME5/.claude.json")
PROJECT5=$(jq -c --arg p "$PROJ5" '.projects[$p].mcpServers."lean-lsp" // "ABSENT"' "$HOME5/.claude.json")

if [ "$GLOBAL5" = '"ABSENT"' ] && [ "$PROJECT5" != '"ABSENT"' ]; then
  pass "Case 5: --retire-global removes only the top-level entry, leaving .projects untouched"
else
  fail "Case 5: expected global=ABSENT, project=present; got global=$GLOBAL5 project=$PROJECT5"
fi

# =====================================================================
# Case 6: two different project paths registered in sequence both survive independently.
# =====================================================================
HOME6="$WORKDIR/case6/home"
PROJ6A="$WORKDIR/case6/projA"
PROJ6B="$WORKDIR/case6/projB"
mkdir -p "$HOME6"
make_lean_project "$PROJ6A"
make_lean_project "$PROJ6B"
echo '{}' > "$HOME6/.claude.json"

HOME="$HOME6" bash "$WRITER_SRC" --project "$PROJ6A" --scope project > /dev/null 2>&1
HOME="$HOME6" bash "$WRITER_SRC" --project "$PROJ6B" --scope project > /dev/null 2>&1

PATH6A=$(jq -r --arg p "$PROJ6A" '.projects[$p].mcpServers."lean-lsp".env.LEAN_PROJECT_PATH' "$HOME6/.claude.json")
PATH6B=$(jq -r --arg p "$PROJ6B" '.projects[$p].mcpServers."lean-lsp".env.LEAN_PROJECT_PATH' "$HOME6/.claude.json")

if [ "$PATH6A" = "$PROJ6A" ] && [ "$PATH6B" = "$PROJ6B" ] && [ "$PATH6A" != "$PATH6B" ]; then
  pass "Case 6: two projects registered in sequence both survive with their own, differing LEAN_PROJECT_PATH"
else
  fail "Case 6: expected PATH6A=$PROJ6A PATH6B=$PROJ6B (differing); got PATH6A=$PATH6A PATH6B=$PATH6B"
fi

# =====================================================================
# Mutation check: neutralize the whole-entry comparison ($a == $b -> always true) and confirm
# case 3's divergent entry is now LEFT UNCHANGED (writer reports "already configured correctly"
# instead of replacing it) -- proving case 3 actually depends on a real comparison.
# =====================================================================
MUTATED_WRITER="$WORKDIR/mutated-setup-lean-mcp.sh"
sed "s/'\$a == \$b'/'true'/" "$WRITER_SRC" > "$MUTATED_WRITER"
chmod +x "$MUTATED_WRITER"

if ! grep -q "jq -n --argjson a \"\$existing_entry\" --argjson b \"\$canonical_entry\" 'true'" "$MUTATED_WRITER"; then
  fail "Mutation setup: sed substitution did not find the expected '\$a == \$b' comparison in $WRITER_SRC -- mutation check did not run"
else
  HOME_MUT="$WORKDIR/case_mut/home"
  PROJ_MUT="$WORKDIR/case_mut/proj"
  OTHER_MUT="$WORKDIR/case_mut/other"
  mkdir -p "$HOME_MUT"
  make_lean_project "$PROJ_MUT"
  make_lean_project "$OTHER_MUT"
  jq -n --arg p "$PROJ_MUT" --arg other "$OTHER_MUT" \
    '{"projects": {($p): {"mcpServers": {"lean-lsp": {"command": "/bad/wrapper.sh", "args": [], "env": {"LEAN_PROJECT_PATH": $other}}}}}}' \
    > "$HOME_MUT/.claude.json"
  BEFORE_MUT=$(md5sum "$HOME_MUT/.claude.json" | awk '{print $1}')
  HOME="$HOME_MUT" bash "$MUTATED_WRITER" --project "$PROJ_MUT" --scope project > /dev/null 2>&1
  AFTER_MUT=$(md5sum "$HOME_MUT/.claude.json" | awk '{print $1}')

  if [ "$BEFORE_MUT" = "$AFTER_MUT" ]; then
    pass "Mutation check: with the whole-entry comparison neutralized to always-true, the divergent entry from case 3's fixture shape is LEFT UNCHANGED -- case 3 is discriminative, not vacuous"
  else
    fail "Mutation check: expected the file to remain unchanged under the neutralized comparison; before=$BEFORE_MUT after=$AFTER_MUT"
  fi
fi

# =====================================================================
# Summary
# =====================================================================

info "Passed: $PASSED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
