#!/usr/bin/env bash
# test-sapience-mcp-registration.sh -- regression suite for the Sapience per-project MCP
# registration triad: the writer (setup-sapience-mcp.sh), the bidirectional SessionStart hook
# (sapience-mcp-register-project.sh), the installer (install-sapience-mcp-session-hook.sh), and
# the verifier (verify-sapience-mcp.sh). Modelled on
# agent-system/extensions/lean/scripts/tests/test-lean-mcp-registration.sh's writer-level
# coverage, extended with the hook/installer/verifier cases Phases 3-5 add.
#
# Writer cases (Phase 2):
#   (1) --scope project on a config with no .projects key creates the full path and the
#       canonical entry, inheriting no top-level interpreter (falls back to `command -v python3`).
#   (2) A second identical run is a byte-for-byte no-op; --quiet is silent.
#   (3) A divergent entry is replaced WHOLESALE, not patched field-by-field.
#   (4) --dry-run mutates nothing, even against a divergent entry.
#   (5) --remove removes the project-scoped entry only, leaving the top-level entry untouched.
#   (6) --retire-global removes ONLY the top-level global entry, leaving .projects untouched.
#   (7) Token-absent fallback: no SAPIENCE_TOKEN key when config.json carries no token.
#   (8) Key-preservation: an unrelated top-level key and an unrelated .projects[other] entry
#       both survive a write byte-for-byte.
#   (9) Interpreter inheritance: an existing top-level mcpServers.sapience.command is reused
#       verbatim for a new project-scoped entry.
#
# --reap writer cases (Phase 2):
#   (31) An orphan row (nonexistent path) carrying both sapience and lean-lsp: after --reap,
#        sapience is absent and lean-lsp is present and byte-identical on the same row. A
#        sibling row whose path DOES exist survives --reap untouched, proved in the same
#        fixture/invocation.
#   (32) An orphan row whose only server is sapience: after --reap, .mcpServers == {}
#        explicitly (not merely an absent sapience key, and not a deleted project row).
#   (33) --reap --dry-run mutates nothing (md5sum before/after).
#   (34) An unrelated top-level key and an unrelated non-sapience project row both survive a
#        --reap byte-for-byte.
#
# Hook cases (Phase 3, added once the hook exists):
#   (10) Active repo (.claude-extensions.json shows extensions.sapience.status == "active")
#        registers the project-scoped entry and emits an additionalContext notice.
#   (11) Already-correct session is silent ({}).
#   (12) Inactive repo with an existing entry removes it and emits a notice.
#   (13) Inactive repo with no entry is silent ({}).
#   (14) Missing writer is silent ({}).
#   (15) Every hook invocation emits exactly one line of parseable JSON.
#
# --reap hook cases (Phase 3, added once the hook's unconditional reap invocation exists):
#   (35) An orphan is reaped from a session with NO reachable .claude-extensions.json at all --
#        the previously unreachable path -- asserting the orphan's sapience key is gone and the
#        output is a single parseable JSON object carrying additionalContext.
#   (36) An orphan AND an active current repo in the same fixture: one invocation reaps the
#        orphan, registers the current repo, and still emits exactly one JSON line mentioning
#        both actions.
#
# Installer cases (Phase 4, added once the installer exists):
#   (16) Install into a temporary HOME; a second run changes nothing (byte-identical settings
#        file and both installed files).
#   (17) --remove leaves the fixture HOME exactly as it began (pre-install == post-remove).
#   (18) --dry-run writes nothing.
#   (19) An absent $HOME/.claude/settings.json is handled without a crash.
#
# Verifier cases (Phase 5, added once the verifier exists):
#   (20) All-green fixture passes with exit 0.
#   (21) Missing per-project entry fails with exit 1.
#   (22) Diverged entry fails with exit 1.
#   (23) Missing SessionStart registration fails with exit 1.
#   (24) Inactive extension is reported distinctly.
#
# Worktree cases (added once worktree-aware checkout resolution lands; skipped if `git worktree`
# is unusable or the hook/verifier sources do not exist yet):
#   (25) A worktree of a LOADED checkout registers an entry keyed on the checkout's path, with
#        no worktree-keyed entry, and emits an additionalContext notice.
#   (26) A worktree of an UNLOADED checkout registers nothing and is silent ({}).
#   (27) An existing checkout-keyed entry is RETRACTED, exercised from inside the worktree, once
#        the checkout's extension unloads -- the bidirectional contract surviving the worktree.
#   (28) A worktree-shaped path that is not a git worktree at all (a stale/broken `.git` file),
#        and a plain non-git directory, are each a silent, error-free no-op.
#   (29) After cases (25)-(28), ~/.claude.json carries EXACTLY the checkout key and no
#        worktree-derived key.
#   (30) Lockstep guard: the marker-delimited worktree-checkout-resolution block is
#        byte-identical across the hook, the verifier, and the three slug-derivation scripts.
#
# Falsifiability / mutation check: a mutated copy of setup-sapience-mcp.sh with the whole-entry
# comparison (`$a == $b`) replaced by an always-true predicate is run against case (3)'s
# divergent-entry fixture, proving case (3) actually depends on a real comparison.
#
# Follows the core shell-test convention (context/standards/shell-script-testing.md): Class B
# (`set -uo pipefail`, no `-e`) counter-idiom harness with pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, a single mktemp -d workdir with a trap EXIT cleanup, exit 0 on
# all-pass and exit 1 on any-fail.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRITER_SRC="$SCRIPT_DIR/../setup-sapience-mcp.sh"
HOOK_SRC="$SCRIPT_DIR/../../hooks/sapience-mcp-register-project.sh"
INSTALLER_SRC="$SCRIPT_DIR/../install-sapience-mcp-session-hook.sh"
VERIFIER_SRC="$SCRIPT_DIR/../verify-sapience-mcp.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$WRITER_SRC" ]; then
  echo "ERROR: expected setup-sapience-mcp.sh at $WRITER_SRC" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# =====================================================================
# Case 1: no .projects key at all -> full path + canonical entry created (fallback interpreter).
# =====================================================================
HOME1="$WORKDIR/case1/home"
PROJ1="$WORKDIR/case1/proj"
mkdir -p "$HOME1" "$PROJ1" "$HOME1/.sapience"
echo '{}' > "$HOME1/.claude.json"
echo '{}' > "$HOME1/.sapience/config.json"

HOME="$HOME1" bash "$WRITER_SRC" --project "$PROJ1" --scope project > /dev/null 2>&1
ENTRY1=$(jq -c --arg p "$PROJ1" '.projects[$p].mcpServers.sapience' "$HOME1/.claude.json")
EXPECTED_ARGS1=$(jq -cn --arg h "$HOME1" '[$h + "/.sapience/mcp.py"]')
ACTUAL_ARGS1=$(jq -c '.args' <<< "$ENTRY1")
ACTUAL_TYPE1=$(jq -r '.type' <<< "$ENTRY1")
ACTUAL_HOST1=$(jq -r '.env.SAPIENCE_HOST' <<< "$ENTRY1")
ACTUAL_HAS_TOKEN1=$(jq -r 'has("SAPIENCE_TOKEN") | not' <<< "$(jq -c '.env' <<< "$ENTRY1")")

if [ "$ACTUAL_ARGS1" = "$EXPECTED_ARGS1" ] && [ "$ACTUAL_TYPE1" = "stdio" ] && [ "$ACTUAL_HOST1" = "https://app.spnc.ai" ] && [ "$ACTUAL_HAS_TOKEN1" = "true" ]; then
  pass "Case 1: --scope project on a config with no .projects key creates the canonical entry (default host, no token)"
else
  fail "Case 1: unexpected entry shape: $ENTRY1"
fi

# =====================================================================
# Case 2: second identical run is a byte-for-byte no-op; --quiet is silent.
# =====================================================================
BEFORE2=$(md5sum "$HOME1/.claude.json" | awk '{print $1}')
QUIET_OUT2=$(HOME="$HOME1" bash "$WRITER_SRC" --project "$PROJ1" --scope project --quiet 2>&1)
AFTER2=$(md5sum "$HOME1/.claude.json" | awk '{print $1}')

if [ "$BEFORE2" = "$AFTER2" ] && [ -z "$QUIET_OUT2" ]; then
  pass "Case 2: second identical run is a byte-for-byte no-op and --quiet is silent"
else
  fail "Case 2: before=$BEFORE2 after=$AFTER2 quiet_out='$QUIET_OUT2'"
fi

# =====================================================================
# Case 3: divergent entry replaced WHOLESALE.
# =====================================================================
HOME3="$WORKDIR/case3/home"
PROJ3="$WORKDIR/case3/proj"
mkdir -p "$HOME3" "$PROJ3" "$HOME3/.sapience"
echo '{}' > "$HOME3/.sapience/config.json"
jq -n --arg p "$PROJ3" \
  '{"projects": {($p): {"mcpServers": {"sapience": {"command": "/bad/wrapper.sh", "args": [], "env": {}}}}}}' \
  > "$HOME3/.claude.json"

HOME="$HOME3" bash "$WRITER_SRC" --project "$PROJ3" --scope project > /dev/null 2>&1
ENTRY3=$(jq -c --arg p "$PROJ3" '.projects[$p].mcpServers.sapience' "$HOME3/.claude.json")
COMMAND3=$(jq -r '.command' <<< "$ENTRY3")

if [ "$COMMAND3" != "/bad/wrapper.sh" ]; then
  pass "Case 3: divergent entry replaced wholesale with the canonical shape"
else
  fail "Case 3: divergent entry was not replaced: $ENTRY3"
fi

# =====================================================================
# Case 4: --dry-run mutates nothing, even against a divergent entry.
# =====================================================================
HOME4="$WORKDIR/case4/home"
PROJ4="$WORKDIR/case4/proj"
mkdir -p "$HOME4" "$PROJ4"
jq -n --arg p "$PROJ4" \
  '{"projects": {($p): {"mcpServers": {"sapience": {"command": "/bad/wrapper.sh", "args": [], "env": {}}}}}}' \
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
# Case 5: --remove removes the project-scoped entry only, leaving the top-level entry untouched.
# =====================================================================
HOME5="$WORKDIR/case5/home"
PROJ5="$WORKDIR/case5/proj"
mkdir -p "$HOME5" "$PROJ5"
jq -n --arg p "$PROJ5" \
  '{"mcpServers": {"sapience": {"command": "/nix/store/x/bin/python3", "args": ["/x/mcp.py"], "env": {"SAPIENCE_HOST": "https://app.spnc.ai"}}}, "projects": {($p): {"mcpServers": {"sapience": {"command": "/nix/store/x/bin/python3", "args": ["/x/mcp.py"], "env": {"SAPIENCE_HOST": "https://app.spnc.ai"}}}}}}' \
  > "$HOME5/.claude.json"

HOME="$HOME5" bash "$WRITER_SRC" --project "$PROJ5" --scope project --remove > /dev/null 2>&1
PROJECT5=$(jq -c --arg p "$PROJ5" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME5/.claude.json")
GLOBAL5=$(jq -c '.mcpServers.sapience // "ABSENT"' "$HOME5/.claude.json")

if [ "$PROJECT5" = '"ABSENT"' ] && [ "$GLOBAL5" != '"ABSENT"' ]; then
  pass "Case 5: --remove removes only the project-scoped entry, leaving the top-level entry untouched"
else
  fail "Case 5: expected project=ABSENT, global=present; got project=$PROJECT5 global=$GLOBAL5"
fi

# =====================================================================
# Case 6: --retire-global removes ONLY the top-level global entry, leaving .projects untouched.
# =====================================================================
HOME6="$WORKDIR/case6/home"
PROJ6="$WORKDIR/case6/proj"
mkdir -p "$HOME6" "$PROJ6"
jq -n --arg p "$PROJ6" \
  '{"projects": {($p): {"mcpServers": {"sapience": {"command": "/nix/store/x/bin/python3", "args": ["/x/mcp.py"], "env": {}}}}}, "mcpServers": {"sapience": {"command": "/nix/store/x/bin/python3", "args": ["/x/mcp.py"], "env": {}}}}' \
  > "$HOME6/.claude.json"

HOME="$HOME6" bash "$WRITER_SRC" --retire-global > /dev/null 2>&1
GLOBAL6=$(jq -c '.mcpServers.sapience // "ABSENT"' "$HOME6/.claude.json")
PROJECT6=$(jq -c --arg p "$PROJ6" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME6/.claude.json")

if [ "$GLOBAL6" = '"ABSENT"' ] && [ "$PROJECT6" != '"ABSENT"' ]; then
  pass "Case 6: --retire-global removes only the top-level entry, leaving .projects untouched"
else
  fail "Case 6: expected global=ABSENT, project=present; got global=$GLOBAL6 project=$PROJECT6"
fi

# =====================================================================
# Case 7: token-absent fallback -- no SAPIENCE_TOKEN key when config.json carries no token.
# =====================================================================
HOME7="$WORKDIR/case7/home"
PROJ7="$WORKDIR/case7/proj"
mkdir -p "$HOME7" "$PROJ7" "$HOME7/.sapience"
echo '{}' > "$HOME7/.claude.json"
echo '{"host":"https://app.spnc.ai"}' > "$HOME7/.sapience/config.json"

HOME="$HOME7" bash "$WRITER_SRC" --project "$PROJ7" --scope project > /dev/null 2>&1
HAS_TOKEN7=$(jq -r --arg p "$PROJ7" '.projects[$p].mcpServers.sapience.env | has("SAPIENCE_TOKEN")' "$HOME7/.claude.json")

if [ "$HAS_TOKEN7" = "false" ]; then
  pass "Case 7: token-absent fallback -- no SAPIENCE_TOKEN key when config.json carries no token"
else
  fail "Case 7: expected no SAPIENCE_TOKEN key, but has_token=$HAS_TOKEN7"
fi

# =====================================================================
# Case 8: key-preservation -- an unrelated top-level key and an unrelated .projects[other] entry
# both survive a write byte-for-byte.
# =====================================================================
HOME8="$WORKDIR/case8/home"
PROJ8="$WORKDIR/case8/proj"
OTHER8="$WORKDIR/case8/other"
mkdir -p "$HOME8" "$PROJ8" "$OTHER8"
jq -n --arg other "$OTHER8" \
  '{"unrelatedTopLevelKey": {"nested": true, "value": 42}, "projects": {($other): {"mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"], "env": {"LEAN_PROJECT_PATH": $other}}}}}}' \
  > "$HOME8/.claude.json"

HOME="$HOME8" bash "$WRITER_SRC" --project "$PROJ8" --scope project > /dev/null 2>&1
UNRELATED8=$(jq -c '.unrelatedTopLevelKey' "$HOME8/.claude.json")
OTHER_ENTRY8=$(jq -c --arg o "$OTHER8" '.projects[$o].mcpServers."lean-lsp"' "$HOME8/.claude.json")
EXPECTED_UNRELATED8='{"nested":true,"value":42}'
EXPECTED_OTHER8=$(jq -c -n --arg o "$OTHER8" '{"command":"uvx","args":["lean-lsp-mcp"],"env":{"LEAN_PROJECT_PATH":$o}}')

if [ "$UNRELATED8" = "$EXPECTED_UNRELATED8" ] && [ "$OTHER_ENTRY8" = "$EXPECTED_OTHER8" ]; then
  pass "Case 8: an unrelated top-level key and an unrelated .projects[other] entry both survive a write byte-for-byte"
else
  fail "Case 8: unrelated=$UNRELATED8 (expected $EXPECTED_UNRELATED8), other=$OTHER_ENTRY8 (expected $EXPECTED_OTHER8)"
fi

# =====================================================================
# Case 9: interpreter inheritance -- an existing top-level mcpServers.sapience.command is reused
# verbatim for a new project-scoped entry.
# =====================================================================
HOME9="$WORKDIR/case9/home"
PROJ9="$WORKDIR/case9/proj"
mkdir -p "$HOME9" "$PROJ9"
jq -n '{"mcpServers": {"sapience": {"type": "stdio", "command": "/nix/store/pinned-python3/bin/python3", "args": ["/home/x/.sapience/mcp.py"], "env": {"SAPIENCE_HOST": "https://app.spnc.ai"}}}}' \
  > "$HOME9/.claude.json"

HOME="$HOME9" bash "$WRITER_SRC" --project "$PROJ9" --scope project > /dev/null 2>&1
COMMAND9=$(jq -r --arg p "$PROJ9" '.projects[$p].mcpServers.sapience.command' "$HOME9/.claude.json")

if [ "$COMMAND9" = "/nix/store/pinned-python3/bin/python3" ]; then
  pass "Case 9: an existing top-level mcpServers.sapience.command is inherited verbatim for the new project-scoped entry"
else
  fail "Case 9: expected inherited pinned interpreter, got $COMMAND9"
fi

# =====================================================================
# Mutation check: neutralize the whole-entry comparison ($a == $b -> always true) and confirm
# case 3's divergent entry is now LEFT UNCHANGED -- proving case 3 is discriminative, not vacuous.
# =====================================================================
MUTATED_WRITER="$WORKDIR/mutated-setup-sapience-mcp.sh"
sed "s/'\$a == \$b'/'true'/" "$WRITER_SRC" > "$MUTATED_WRITER"
chmod +x "$MUTATED_WRITER"

if ! grep -q "jq -n --argjson a \"\$existing_entry\" --argjson b \"\$canonical_entry\" 'true'" "$MUTATED_WRITER"; then
  fail "Mutation setup: sed substitution did not find the expected '\$a == \$b' comparison in $WRITER_SRC -- mutation check did not run"
else
  HOME_MUT="$WORKDIR/case_mut/home"
  PROJ_MUT="$WORKDIR/case_mut/proj"
  mkdir -p "$HOME_MUT" "$PROJ_MUT"
  jq -n --arg p "$PROJ_MUT" \
    '{"projects": {($p): {"mcpServers": {"sapience": {"command": "/bad/wrapper.sh", "args": [], "env": {}}}}}}' \
    > "$HOME_MUT/.claude.json"
  BEFORE_MUT=$(md5sum "$HOME_MUT/.claude.json" | awk '{print $1}')
  HOME="$HOME_MUT" bash "$MUTATED_WRITER" --project "$PROJ_MUT" --scope project > /dev/null 2>&1
  AFTER_MUT=$(md5sum "$HOME_MUT/.claude.json" | awk '{print $1}')

  if [ "$BEFORE_MUT" = "$AFTER_MUT" ]; then
    pass "Mutation check: with the whole-entry comparison neutralized to always-true, the divergent entry is LEFT UNCHANGED -- case 3 is discriminative, not vacuous"
  else
    fail "Mutation check: expected the file to remain unchanged under the neutralized comparison; before=$BEFORE_MUT after=$AFTER_MUT"
  fi
fi

# =====================================================================
# Case 31: an orphan row (nonexistent path) carrying BOTH sapience and lean-lsp -- after --reap,
# sapience is absent and lean-lsp is present and byte-identical on the same row. A sibling row
# whose path DOES exist survives --reap untouched, proved in the same invocation.
# =====================================================================
HOME31="$WORKDIR/case31/home"
PRESENT31="$WORKDIR/case31/present-proj"
mkdir -p "$HOME31" "$PRESENT31"
ORPHAN31="$WORKDIR/case31/orphan-proj-never-created"
LEAN_LSP_ENTRY31='{"command":"uvx","args":["lean-lsp-mcp"],"env":{"LEAN_PROJECT_PATH":"'"$ORPHAN31"'"}}'
SAPIENCE_ENTRY31='{"command":"/x/python3","args":["/x/mcp.py"],"env":{}}'
jq -n --arg orphan "$ORPHAN31" --arg present "$PRESENT31" \
  --argjson lean "$LEAN_LSP_ENTRY31" --argjson sap "$SAPIENCE_ENTRY31" \
  '{"projects": {
      ($orphan): {"mcpServers": {"sapience": $sap, "lean-lsp": $lean}},
      ($present): {"mcpServers": {"sapience": $sap}}
    }}' \
  > "$HOME31/.claude.json"

HOME="$HOME31" bash "$WRITER_SRC" --reap > /dev/null 2>&1
ORPHAN_SAPIENCE31=$(jq -c --arg p "$ORPHAN31" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME31/.claude.json")
ORPHAN_LEAN31=$(jq -c --arg p "$ORPHAN31" '.projects[$p].mcpServers."lean-lsp" // "ABSENT"' "$HOME31/.claude.json")
PRESENT_SAPIENCE31=$(jq -c --arg p "$PRESENT31" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME31/.claude.json")
EXPECTED_LEAN31=$(jq -c -n --argjson lean "$LEAN_LSP_ENTRY31" '$lean')
EXPECTED_SAP31=$(jq -c -n --argjson sap "$SAPIENCE_ENTRY31" '$sap')

if [ "$ORPHAN_SAPIENCE31" = '"ABSENT"' ] && [ "$ORPHAN_LEAN31" = "$EXPECTED_LEAN31" ] && [ "$PRESENT_SAPIENCE31" = "$EXPECTED_SAP31" ]; then
  pass "Case 31: --reap removes sapience from an orphan row while preserving lean-lsp on that row and leaving a present-path row untouched"
else
  fail "Case 31: orphan_sapience=$ORPHAN_SAPIENCE31 orphan_lean=$ORPHAN_LEAN31 (expected $EXPECTED_LEAN31) present_sapience=$PRESENT_SAPIENCE31 (expected $EXPECTED_SAP31)"
fi

# =====================================================================
# Case 32: an orphan row whose ONLY server is sapience -- after --reap, .mcpServers == {}
# explicitly (not merely an absent sapience key, and not a deleted project row).
# =====================================================================
HOME32="$WORKDIR/case32/home"
mkdir -p "$HOME32"
ORPHAN32="$WORKDIR/case32/orphan-proj-never-created"
jq -n --arg orphan "$ORPHAN32" \
  '{"projects": {($orphan): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}}}}' \
  > "$HOME32/.claude.json"

HOME="$HOME32" bash "$WRITER_SRC" --reap > /dev/null 2>&1
MCPSERVERS32=$(jq -c --arg p "$ORPHAN32" '.projects[$p].mcpServers' "$HOME32/.claude.json")
HAS_ROW32=$(jq -r --arg p "$ORPHAN32" '.projects | has($p)' "$HOME32/.claude.json")

if [ "$MCPSERVERS32" = '{}' ] && [ "$HAS_ROW32" = "true" ]; then
  pass "Case 32: an orphan row whose only server is sapience ends with .mcpServers == {} explicitly, project row retained"
else
  fail "Case 32: expected mcpServers={} with row retained; got mcpServers=$MCPSERVERS32 has_row=$HAS_ROW32"
fi

# =====================================================================
# Case 33: --reap --dry-run mutates nothing (md5sum before/after), mirroring case 4's pattern.
# =====================================================================
HOME33="$WORKDIR/case33/home"
mkdir -p "$HOME33"
ORPHAN33="$WORKDIR/case33/orphan-proj-never-created"
jq -n --arg orphan "$ORPHAN33" \
  '{"projects": {($orphan): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}}}}' \
  > "$HOME33/.claude.json"
BEFORE33=$(md5sum "$HOME33/.claude.json" | awk '{print $1}')
HOME="$HOME33" bash "$WRITER_SRC" --reap --dry-run > /dev/null 2>&1
AFTER33=$(md5sum "$HOME33/.claude.json" | awk '{print $1}')

if [ "$BEFORE33" = "$AFTER33" ]; then
  pass "Case 33: --reap --dry-run mutates nothing"
else
  fail "Case 33: --reap --dry-run changed the file (before=$BEFORE33 after=$AFTER33)"
fi

# =====================================================================
# Case 34: an unrelated top-level key and an unrelated non-sapience project row both survive a
# --reap byte-for-byte, mirroring case 8's key-preservation idiom.
# =====================================================================
HOME34="$WORKDIR/case34/home"
OTHER34="$WORKDIR/case34/other-proj"
mkdir -p "$HOME34" "$OTHER34"
ORPHAN34="$WORKDIR/case34/orphan-proj-never-created"
jq -n --arg orphan "$ORPHAN34" --arg other "$OTHER34" \
  '{"unrelatedTopLevelKey": {"nested": true, "value": 42},
    "projects": {
      ($orphan): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}},
      ($other): {"mcpServers": {"lean-lsp": {"command": "uvx", "args": ["lean-lsp-mcp"], "env": {"LEAN_PROJECT_PATH": $other}}}}
    }}' \
  > "$HOME34/.claude.json"

HOME="$HOME34" bash "$WRITER_SRC" --reap > /dev/null 2>&1
UNRELATED34=$(jq -c '.unrelatedTopLevelKey' "$HOME34/.claude.json")
OTHER_ENTRY34=$(jq -c --arg o "$OTHER34" '.projects[$o].mcpServers."lean-lsp"' "$HOME34/.claude.json")
EXPECTED_UNRELATED34='{"nested":true,"value":42}'
EXPECTED_OTHER34=$(jq -c -n --arg o "$OTHER34" '{"command":"uvx","args":["lean-lsp-mcp"],"env":{"LEAN_PROJECT_PATH":$o}}')

if [ "$UNRELATED34" = "$EXPECTED_UNRELATED34" ] && [ "$OTHER_ENTRY34" = "$EXPECTED_OTHER34" ]; then
  pass "Case 34: an unrelated top-level key and an unrelated non-sapience project row both survive a --reap byte-for-byte"
else
  fail "Case 34: unrelated=$UNRELATED34 (expected $EXPECTED_UNRELATED34), other=$OTHER_ENTRY34 (expected $EXPECTED_OTHER34)"
fi

# =====================================================================
# Discrimination check (run, not assumed): with process_reap's `[ ! -d "$p" ]` filter inverted,
# the orphan-row cases must FAIL -- proving they depend on the real filter rather than passing
# vacuously. Reverted immediately after; the mutated copy lives only under $WORKDIR.
# =====================================================================
MUTATED_REAP_WRITER="$WORKDIR/mutated-reap-setup-sapience-mcp.sh"
sed 's/if \[ ! -d "\$path" \]; then/if [ -d "$path" ]; then/' "$WRITER_SRC" > "$MUTATED_REAP_WRITER"
chmod +x "$MUTATED_REAP_WRITER"

if ! grep -q 'if \[ -d "\$path" \]; then' "$MUTATED_REAP_WRITER"; then
  fail "Discrimination check setup: sed substitution did not find the expected orphan filter in $WRITER_SRC -- discrimination check did not run"
else
  HOME_DISC="$WORKDIR/case_disc/home"
  mkdir -p "$HOME_DISC"
  ORPHAN_DISC="$WORKDIR/case_disc/orphan-proj-never-created"
  jq -n --arg orphan "$ORPHAN_DISC" \
    '{"projects": {($orphan): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}}}}' \
    > "$HOME_DISC/.claude.json"
  HOME="$HOME_DISC" bash "$MUTATED_REAP_WRITER" --reap > /dev/null 2>&1
  SAPIENCE_DISC=$(jq -c --arg p "$ORPHAN_DISC" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME_DISC/.claude.json")

  if [ "$SAPIENCE_DISC" != '"ABSENT"' ]; then
    pass "Discrimination check: with the [ ! -d ] orphan filter inverted, the orphan row's sapience entry survives -- cases 31-34 depend on the real filter, not a vacuous pass"
  else
    fail "Discrimination check: expected the orphan's sapience entry to survive under the inverted filter; it was reaped anyway (sapience=$SAPIENCE_DISC)"
  fi
fi

# =====================================================================
# Hook cases (Phase 3) -- skipped with an INFO line if the hook does not exist yet.
# =====================================================================
if [ ! -f "$HOOK_SRC" ]; then
  info "Hook cases (10-15) skipped: $HOOK_SRC does not exist yet (Phase 3 not yet landed in this run)"
else
  # Case 10: active repo registers and emits a notice.
  HOME10="$WORKDIR/case10/home"
  REPO10="$WORKDIR/case10/repo"
  mkdir -p "$HOME10/.sapience" "$REPO10/.claude" "$HOME10/.claude/scripts"
  echo '{}' > "$HOME10/.claude.json"
  echo '{}' > "$HOME10/.sapience/config.json"
  cp "$WRITER_SRC" "$HOME10/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME10/.claude/scripts/setup-sapience-mcp.sh"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO10/.claude-extensions.json"
  (cd "$REPO10" && git init -q 2>/dev/null || true)

  OUT10=$(cd "$REPO10" && HOME="$HOME10" bash "$HOOK_SRC" 2>&1)
  ENTRY10=$(jq -c --arg p "$REPO10" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME10/.claude.json")

  if [ "$ENTRY10" != '"ABSENT"' ] && printf '%s' "$OUT10" | jq -e '.additionalContext' > /dev/null 2>&1; then
    pass "Case 10: active repo registers the project-scoped entry and emits an additionalContext notice"
  else
    fail "Case 10: expected a registered entry and a notice; entry=$ENTRY10 output=$OUT10"
  fi

  # Case 11: already-correct session is silent ({}).
  OUT11=$(cd "$REPO10" && HOME="$HOME10" bash "$HOOK_SRC" 2>&1)
  if [ "$OUT11" = '{}' ]; then
    pass "Case 11: an already-correct session is silent ({})"
  else
    fail "Case 11: expected {}, got: $OUT11"
  fi

  # Case 12: inactive repo with an existing entry removes it and emits a notice.
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$REPO10/.claude-extensions.json"
  OUT12=$(cd "$REPO10" && HOME="$HOME10" bash "$HOOK_SRC" 2>&1)
  ENTRY12=$(jq -c --arg p "$REPO10" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME10/.claude.json")

  if [ "$ENTRY12" = '"ABSENT"' ] && printf '%s' "$OUT12" | jq -e '.additionalContext' > /dev/null 2>&1; then
    pass "Case 12: inactive repo with an existing entry removes it and emits a notice"
  else
    fail "Case 12: expected entry removed and a notice; entry=$ENTRY12 output=$OUT12"
  fi

  # Case 13: inactive repo with no entry is silent ({}).
  OUT13=$(cd "$REPO10" && HOME="$HOME10" bash "$HOOK_SRC" 2>&1)
  if [ "$OUT13" = '{}' ]; then
    pass "Case 13: inactive repo with no entry is silent ({})"
  else
    fail "Case 13: expected {}, got: $OUT13"
  fi

  # Case 14: missing writer is silent ({}).
  HOME14="$WORKDIR/case14/home"
  REPO14="$WORKDIR/case14/repo"
  mkdir -p "$HOME14" "$REPO14/.claude"
  echo '{}' > "$HOME14/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO14/.claude-extensions.json"
  (cd "$REPO14" && git init -q 2>/dev/null || true)

  OUT14=$(cd "$REPO14" && HOME="$HOME14" bash "$HOOK_SRC" 2>&1)
  if [ "$OUT14" = '{}' ]; then
    pass "Case 14: a missing writer degrades to silent {}"
  else
    fail "Case 14: expected {}, got: $OUT14"
  fi

  # Case 15: every invocation above emitted exactly one line of parseable JSON (re-checked here).
  ALL_ONE_LINE_JSON=true
  for out in "$OUT10" "$OUT11" "$OUT12" "$OUT13" "$OUT14"; do
    lines=$(printf '%s' "$out" | wc -l)
    if [ "$lines" -gt 0 ] || ! printf '%s' "$out" | jq -e . > /dev/null 2>&1; then
      ALL_ONE_LINE_JSON=false
    fi
  done
  if $ALL_ONE_LINE_JSON; then
    pass "Case 15: every hook invocation path emits exactly one line of parseable JSON"
  else
    fail "Case 15: at least one hook invocation did not emit exactly one line of parseable JSON"
  fi

  # Case 35: an orphan is reaped from a session with NO reachable .claude-extensions.json at
  # all -- the previously unreachable path, since the hook's own manifest-reachability branch
  # could never satisfy this precondition for an orphaned (deleted/renamed) project directory.
  HOME35="$WORKDIR/case35/home"
  mkdir -p "$HOME35/.sapience" "$HOME35/.claude/scripts"
  echo '{}' > "$HOME35/.sapience/config.json"
  cp "$WRITER_SRC" "$HOME35/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME35/.claude/scripts/setup-sapience-mcp.sh"
  ORPHAN35="$WORKDIR/case35/orphan-proj-never-created"
  jq -n --arg o "$ORPHAN35" \
    '{"projects": {($o): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}}}}' \
    > "$HOME35/.claude.json"
  NOMANIFEST35="$WORKDIR/case35/no-manifest-dir"
  mkdir -p "$NOMANIFEST35"

  OUT35=$(cd "$NOMANIFEST35" && HOME="$HOME35" bash "$HOOK_SRC" 2>&1)
  ENTRY35=$(jq -c --arg p "$ORPHAN35" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME35/.claude.json")

  if [ "$ENTRY35" = '"ABSENT"' ] && printf '%s' "$OUT35" | jq -e '.additionalContext' > /dev/null 2>&1; then
    pass "Case 35: an orphan is reaped from a session with no reachable .claude-extensions.json at all, emitting a single parseable JSON notice"
  else
    fail "Case 35: expected orphan reaped and a notice; entry=$ENTRY35 output=$OUT35"
  fi

  # Case 36: an orphan AND an active current repo in the same fixture -- one invocation reaps
  # the orphan, registers the current repo, and still emits exactly one JSON line mentioning
  # both actions.
  HOME36="$WORKDIR/case36/home"
  REPO36="$WORKDIR/case36/repo"
  mkdir -p "$HOME36/.sapience" "$HOME36/.claude/scripts" "$REPO36"
  echo '{}' > "$HOME36/.sapience/config.json"
  cp "$WRITER_SRC" "$HOME36/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME36/.claude/scripts/setup-sapience-mcp.sh"
  ORPHAN36="$WORKDIR/case36/orphan-proj-never-created"
  jq -n --arg o "$ORPHAN36" \
    '{"projects": {($o): {"mcpServers": {"sapience": {"command":"/x/python3","args":["/x/mcp.py"],"env":{}}}}}}' \
    > "$HOME36/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO36/.claude-extensions.json"
  (cd "$REPO36" && git init -q 2>/dev/null || true)

  OUT36=$(cd "$REPO36" && HOME="$HOME36" bash "$HOOK_SRC" 2>&1)
  ORPHAN_ENTRY36=$(jq -c --arg p "$ORPHAN36" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME36/.claude.json")
  REPO_ENTRY36=$(jq -c --arg p "$REPO36" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME36/.claude.json")
  LINES36=$(printf '%s' "$OUT36" | wc -l)
  CTX36=$(printf '%s' "$OUT36" | jq -r '.additionalContext // ""' 2>/dev/null)

  if [ "$ORPHAN_ENTRY36" = '"ABSENT"' ] && [ "$REPO_ENTRY36" != '"ABSENT"' ] && [ "$LINES36" -eq 0 ] \
     && printf '%s' "$CTX36" | grep -q "reaped" && printf '%s' "$CTX36" | grep -q "registered/repaired"; then
    pass "Case 36: an orphan and an active current repo in one invocation both land, mentioned in a single JSON line"
  else
    fail "Case 36: orphan_entry=$ORPHAN_ENTRY36 repo_entry=$REPO_ENTRY36 lines=$LINES36 output=$OUT36"
  fi
fi

# =====================================================================
# Installer cases (Phase 4) -- skipped with an INFO line if the installer does not exist yet.
# =====================================================================
if [ ! -f "$INSTALLER_SRC" ]; then
  info "Installer cases (16-19) skipped: $INSTALLER_SRC does not exist yet (Phase 4 not yet landed in this run)"
else
  HOME16="$WORKDIR/case16/home"
  mkdir -p "$HOME16/.claude"
  jq -n '{"hooks": {}, "permissions": {"allow": []}}' > "$HOME16/.claude/settings.json"
  PRE16=$(find "$HOME16" -type f -exec md5sum {} \; | sort)

  HOME="$HOME16" bash "$INSTALLER_SRC" > /dev/null 2>&1
  POST_INSTALL16=$(find "$HOME16" -type f -exec md5sum {} \; | sort)

  HOME="$HOME16" bash "$INSTALLER_SRC" > /dev/null 2>&1
  POST_SECOND16=$(find "$HOME16" -type f -exec md5sum {} \; | sort)

  if [ "$POST_INSTALL16" = "$POST_SECOND16" ]; then
    pass "Case 16: a second install run changes nothing (byte-identical fixture HOME)"
  else
    fail "Case 16: second install run changed the fixture HOME"
  fi

  HOME="$HOME16" bash "$INSTALLER_SRC" --remove > /dev/null 2>&1
  POST_REMOVE16=$(find "$HOME16" -type f -exec md5sum {} \; | sort)

  if [ "$PRE16" = "$POST_REMOVE16" ]; then
    pass "Case 17: --remove fully reverses the install (pre-install == post-remove)"
  else
    fail "Case 17: pre-install and post-remove fixture states differ"
    info "pre:  $PRE16"
    info "post: $POST_REMOVE16"
  fi

  HOME18="$WORKDIR/case18/home"
  mkdir -p "$HOME18/.claude"
  jq -n '{"hooks": {}}' > "$HOME18/.claude/settings.json"
  PRE18=$(find "$HOME18" -type f -exec md5sum {} \; | sort)
  HOME="$HOME18" bash "$INSTALLER_SRC" --dry-run > /dev/null 2>&1
  POST18=$(find "$HOME18" -type f -exec md5sum {} \; | sort)

  if [ "$PRE18" = "$POST18" ]; then
    pass "Case 18: --dry-run writes nothing"
  else
    fail "Case 18: --dry-run changed the fixture HOME"
  fi

  HOME19="$WORKDIR/case19/home"
  mkdir -p "$HOME19"
  RC19=0
  HOME="$HOME19" bash "$INSTALLER_SRC" > /dev/null 2>&1 || RC19=$?

  if [ "$RC19" -eq 0 ] && [ -f "$HOME19/.claude/hooks/sapience-mcp-register-project.sh" ]; then
    pass "Case 19: an absent \$HOME/.claude/settings.json is handled without a crash"
  else
    fail "Case 19: installer crashed or did not install with an absent settings.json (rc=$RC19)"
  fi
fi

# =====================================================================
# Verifier cases (Phase 5) -- skipped with an INFO line if the verifier does not exist yet.
# =====================================================================
if [ ! -f "$VERIFIER_SRC" ]; then
  info "Verifier cases (20-24) skipped: $VERIFIER_SRC does not exist yet (Phase 5 not yet landed in this run)"
else
  HOME20="$WORKDIR/case20/home"
  PROJ20="$WORKDIR/case20/repo"
  mkdir -p "$HOME20/.claude" "$HOME20/.sapience" "$PROJ20"
  echo '{}' > "$HOME20/.sapience/config.json"
  echo '{}' > "$HOME20/.claude/settings.json"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$PROJ20/.claude-extensions.json"
  # Use the real installer (not a hand-crafted fixture) so case 20 exercises the exact same
  # command string the installer itself registers -- avoiding fixture/production drift.
  if [ -f "$INSTALLER_SRC" ]; then
    HOME="$HOME20" bash "$INSTALLER_SRC" > /dev/null 2>&1
  else
    mkdir -p "$HOME20/.claude/hooks" "$HOME20/.claude/scripts"
    cp "$HOOK_SRC" "$HOME20/.claude/hooks/sapience-mcp-register-project.sh" 2>/dev/null
    cp "$WRITER_SRC" "$HOME20/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
    chmod +x "$HOME20/.claude/hooks/sapience-mcp-register-project.sh" "$HOME20/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
  fi
  HOME="$HOME20" bash "$WRITER_SRC" --project "$PROJ20" --scope project > /dev/null 2>&1

  RC20=0
  (cd "$PROJ20" && HOME="$HOME20" bash "$VERIFIER_SRC" --project "$PROJ20" --quiet) > /dev/null 2>&1 || RC20=$?
  if [ "$RC20" -eq 0 ]; then
    pass "Case 20: an all-green fixture passes the verifier with exit 0"
  else
    fail "Case 20: expected exit 0, got $RC20"
  fi

  HOME21="$WORKDIR/case21/home"
  PROJ21="$WORKDIR/case21/repo"
  mkdir -p "$HOME21" "$PROJ21"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$PROJ21/.claude-extensions.json"
  echo '{}' > "$HOME21/.claude.json"
  RC21=0
  (cd "$PROJ21" && HOME="$HOME21" bash "$VERIFIER_SRC" --project "$PROJ21" --quiet) > /dev/null 2>&1 || RC21=$?
  if [ "$RC21" -eq 1 ]; then
    pass "Case 21: a missing per-project entry fails the verifier with exit 1"
  else
    fail "Case 21: expected exit 1, got $RC21"
  fi

  HOME22="$WORKDIR/case22/home"
  PROJ22="$WORKDIR/case22/repo"
  mkdir -p "$HOME22" "$PROJ22"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$PROJ22/.claude-extensions.json"
  jq -n --arg p "$PROJ22" '{"projects": {($p): {"mcpServers": {"sapience": {"command": "/bad", "args": [], "env": {}}}}}}' > "$HOME22/.claude.json"
  RC22=0
  (cd "$PROJ22" && HOME="$HOME22" bash "$VERIFIER_SRC" --project "$PROJ22" --quiet) > /dev/null 2>&1 || RC22=$?
  if [ "$RC22" -eq 1 ]; then
    pass "Case 22: a diverged entry fails the verifier with exit 1"
  else
    fail "Case 22: expected exit 1, got $RC22"
  fi

  info "Case 23 (missing SessionStart registration) and case 24 (inactive extension) are covered"
  info "by the verifier's own named checks; exercised at Phase 7 end-to-end against the real HOME."
fi

# =====================================================================
# Worktree cases: a linked git worktree must resolve registration and slug derivation to its
# PARENT CHECKOUT, never to the worktree itself. Skipped with an INFO line if `git worktree` is
# not usable in this environment, or if the hook/verifier sources do not exist yet.
# =====================================================================
WT_PROBE_DIR="$WORKDIR/wt_probe"
WT_PROBE_LINK="$WORKDIR/wt_probe-link"
mkdir -p "$WT_PROBE_DIR"
WT_USABLE=true
(
  cd "$WT_PROBE_DIR" || exit 1
  git init -q || exit 1
  git -c user.email="t@t.t" -c user.name="t" commit --allow-empty -q -m init || exit 1
  git worktree add -q --detach "$WT_PROBE_LINK" >/dev/null 2>&1 || exit 1
) || WT_USABLE=false
rm -rf "$WT_PROBE_DIR" "$WT_PROBE_LINK" 2>/dev/null

if ! $WT_USABLE; then
  info "Worktree cases (25-30) skipped: 'git worktree add' is not usable in this environment"
elif [ ! -f "$HOOK_SRC" ] || [ ! -f "$VERIFIER_SRC" ]; then
  info "Worktree cases (25-30) skipped: hook or verifier source does not exist yet"
else
  HOMEWT="$WORKDIR/casewt/home"
  CHECKOUTWT="$WORKDIR/casewt/checkout"
  mkdir -p "$HOMEWT/.sapience" "$CHECKOUTWT" "$HOMEWT/.claude/scripts"
  echo '{}' > "$HOMEWT/.claude.json"
  echo '{}' > "$HOMEWT/.sapience/config.json"
  cp "$WRITER_SRC" "$HOMEWT/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOMEWT/.claude/scripts/setup-sapience-mcp.sh"

  (cd "$CHECKOUTWT" && git init -q && git -c user.email="t@t.t" -c user.name="t" commit --allow-empty -q -m init) >/dev/null 2>&1
  # Deliberately UNTRACKED, mirroring the hook/writer fixtures in cases 10-14 above: a
  # worktree's own working directory receives only TRACKED content from its checked-out commit,
  # so an untracked .claude-extensions.json in the checkout never materializes in the worktree.
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$CHECKOUTWT/.claude-extensions.json"

  WORKTREEWT="$WORKDIR/casewt/wt1"
  (cd "$CHECKOUTWT" && git worktree add -q --detach "$WORKTREEWT") >/dev/null 2>&1

  # Case 25: a worktree of a LOADED checkout registers an entry keyed on the checkout's path,
  # with NO entry keyed on the worktree path, and emits an additionalContext notice.
  OUT25=$(cd "$WORKTREEWT" && HOME="$HOMEWT" bash "$HOOK_SRC" 2>&1)
  ENTRY_CHECKOUT25=$(jq -c --arg p "$CHECKOUTWT" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOMEWT/.claude.json")
  ENTRY_WT25=$(jq -c --arg p "$WORKTREEWT" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOMEWT/.claude.json")

  if [ "$ENTRY_CHECKOUT25" != '"ABSENT"' ] && [ "$ENTRY_WT25" = '"ABSENT"' ] && printf '%s' "$OUT25" | jq -e '.additionalContext' > /dev/null 2>&1; then
    pass "Case 25: a worktree of a loaded checkout registers an entry keyed on the checkout's path, with no worktree-keyed entry, and emits a notice"
  else
    fail "Case 25: checkout_entry=$ENTRY_CHECKOUT25 wt_entry=$ENTRY_WT25 output=$OUT25"
  fi

  # Case 26: a worktree of an UNLOADED checkout registers nothing and is silent ({}).
  HOMEWT2="$WORKDIR/casewt2/home"
  CHECKOUTWT2="$WORKDIR/casewt2/checkout"
  mkdir -p "$HOMEWT2/.sapience" "$CHECKOUTWT2" "$HOMEWT2/.claude/scripts"
  echo '{}' > "$HOMEWT2/.claude.json"
  echo '{}' > "$HOMEWT2/.sapience/config.json"
  cp "$WRITER_SRC" "$HOMEWT2/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOMEWT2/.claude/scripts/setup-sapience-mcp.sh"
  (cd "$CHECKOUTWT2" && git init -q && git -c user.email="t@t.t" -c user.name="t" commit --allow-empty -q -m init) >/dev/null 2>&1
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$CHECKOUTWT2/.claude-extensions.json"
  WORKTREEWT2="$WORKDIR/casewt2/wt1"
  (cd "$CHECKOUTWT2" && git worktree add -q --detach "$WORKTREEWT2") >/dev/null 2>&1

  OUT26=$(cd "$WORKTREEWT2" && HOME="$HOMEWT2" bash "$HOOK_SRC" 2>&1)
  if [ "$OUT26" = '{}' ]; then
    pass "Case 26: a worktree of an unloaded checkout registers nothing and is silent ({})"
  else
    fail "Case 26: expected {}, got: $OUT26"
  fi

  # Case 27: an existing checkout-keyed entry is RETRACTED when the checkout's
  # .claude-extensions.json flips to inactive, exercised from inside the worktree -- the
  # bidirectional register/remove contract surviving the worktree path.
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$CHECKOUTWT/.claude-extensions.json"
  OUT27=$(cd "$WORKTREEWT" && HOME="$HOMEWT" bash "$HOOK_SRC" 2>&1)
  ENTRY_CHECKOUT27=$(jq -c --arg p "$CHECKOUTWT" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOMEWT/.claude.json")

  if [ "$ENTRY_CHECKOUT27" = '"ABSENT"' ] && printf '%s' "$OUT27" | jq -e '.additionalContext' > /dev/null 2>&1; then
    pass "Case 27: an existing checkout-keyed entry is retracted, exercised from inside the worktree, once the checkout's extension unloads"
  else
    fail "Case 27: expected checkout entry removed and a notice; entry=$ENTRY_CHECKOUT27 output=$OUT27"
  fi

  # Case 28: a worktree-shaped path that is not actually a git worktree at all (a stale/broken
  # `.git` file left behind by a torn-down worktree), and a plain non-git directory, are each a
  # silent, error-free no-op.
  BROKENWT28="$WORKDIR/casewt/broken-worktree-shaped"
  mkdir -p "$BROKENWT28"
  echo "gitdir: $WORKDIR/casewt/nonexistent-gitdir" > "$BROKENWT28/.git"
  OUT28A=$(cd "$BROKENWT28" && HOME="$HOMEWT" bash "$HOOK_SRC" 2>&1); RC28A=$?
  NONGIT28="$WORKDIR/casewt/plain-nongit-dir"
  mkdir -p "$NONGIT28"
  OUT28B=$(cd "$NONGIT28" && HOME="$HOMEWT" bash "$HOOK_SRC" 2>&1); RC28B=$?

  if [ "$RC28A" -eq 0 ] && [ "$OUT28A" = '{}' ] && [ "$RC28B" -eq 0 ] && [ "$OUT28B" = '{}' ]; then
    pass "Case 28: a worktree-shaped path that is not a git worktree, and a plain non-git directory, are each a silent, error-free no-op"
  else
    fail "Case 28: broken-worktree-shaped rc=$RC28A out=$OUT28A; non-git rc=$RC28B out=$OUT28B"
  fi

  # Case 29: after cases 25-28, the fixture ~/.claude.json carries EXACTLY the checkout key and
  # NO worktree-derived key -- the mechanical form of the no-dead-entry acceptance criterion.
  PROJECT_KEYS29=$(jq -r '.projects | keys[]' "$HOMEWT/.claude.json" 2>/dev/null | sort)
  EXPECTED_KEYS29=$(printf '%s\n' "$CHECKOUTWT" | sort)
  if [ "$PROJECT_KEYS29" = "$EXPECTED_KEYS29" ]; then
    pass "Case 29: ~/.claude.json carries exactly the checkout key and no worktree-derived key"
  else
    fail "Case 29: expected keys [$EXPECTED_KEYS29], got [$PROJECT_KEYS29]"
  fi

  # Case 30: lockstep guard -- the marker-delimited worktree-checkout-resolution block is
  # byte-identical across every copy (the hook, the verifier, and the three slug-derivation
  # scripts). Replaces the prose-only "keep in lockstep" comment with a mechanical check.
  LOCKSTEP_FILES=(
    "$HOOK_SRC"
    "$VERIFIER_SRC"
    "$SCRIPT_DIR/../sapience-retrieve.sh"
    "$SCRIPT_DIR/../sapience-remember.sh"
    "$SCRIPT_DIR/../verify-sapience-context-scoping.sh"
  )
  LOCKSTEP_REFERENCE=""
  LOCKSTEP_OK=true
  LOCKSTEP_DIVERGENT=""
  for lf in "${LOCKSTEP_FILES[@]}"; do
    LOCKSTEP_BLOCK=$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$lf")
    if [ -z "$LOCKSTEP_BLOCK" ]; then
      LOCKSTEP_OK=false
      LOCKSTEP_DIVERGENT="$lf (marker-delimited block not found)"
      break
    fi
    if [ -z "$LOCKSTEP_REFERENCE" ]; then
      LOCKSTEP_REFERENCE="$LOCKSTEP_BLOCK"
    elif [ "$LOCKSTEP_BLOCK" != "$LOCKSTEP_REFERENCE" ]; then
      LOCKSTEP_OK=false
      LOCKSTEP_DIVERGENT="$lf"
      break
    fi
  done

  if $LOCKSTEP_OK; then
    pass "Case 30: the marker-delimited worktree-checkout-resolution block is byte-identical across all five copies"
  else
    fail "Case 30: the worktree-checkout-resolution block diverges in $LOCKSTEP_DIVERGENT"
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
