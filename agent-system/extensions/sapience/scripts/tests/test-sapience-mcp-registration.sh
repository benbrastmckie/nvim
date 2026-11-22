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
# --capture-set writer cases (Phase 1, capture/activation coupling via the vendor CLI):
#   (56) --capture-set on with no existing entry invokes a PATH-shadowed `sapience` stub with
#        `projects on <path>` and SAPIENCE_NO_CAPTURE_SYNC=1 in its environment.
#   (57) --capture-set off against an enabled:true entry invokes `projects off <path>`.
#   (58) Steady state: --capture-set on against an already-enabled EXACT entry records no stub
#        invocation and prints nothing under --quiet.
#   (59) No `sapience` stub on PATH at all exits 0 silently.
#   (60) An enabled PARENT prefix with no exact entry for the CHILD still invokes `on` for the
#        child (the exact-path idempotence decision, not the longest-prefix match).
#   (61) --capture-set --dry-run records no stub invocation and mutates nothing.
#
# --reap-capture writer cases (Phase 2, cross-project capture reap sweep):
#   (62) A vanished enabled:true capture entry is turned off (stub invoked with
#        `projects off <vanished-path>`) while a sibling entry whose path exists is left
#        untouched, proved in the same fixture/invocation.
#   (63) A vanished entry already enabled:false records no stub invocation.
#   (64) --reap-capture --dry-run records no stub invocation and mutates nothing.
#   (65) No `sapience` on PATH exits 0 silently.
#
# Hook-level capture-coupling cases (Phase 3):
#   (66) An active repo emits a capture notice and the stub records 'projects on <checkout>'.
#   (67) An inactive repo with an existing enabled:true entry records 'projects off
#        <checkout>' and emits a notice.
#   (68) Steady state records no additional stub invocation and the hook prints {}.
#   (69) No sapience binary on PATH prints {}; the MCP-registration half's existing entry is
#        unaffected.
#   (70) Invoked from inside a linked worktree, the stub receives the PARENT CHECKOUT path and
#        no worktree-keyed capture.projects[] entry appears.
#   (71) A session with both an orphaned capture entry and an active current repo emits exactly
#        one parseable JSON line mentioning both actions.
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
# Check (g) cases -- machine-wide vendor hook recurrence detector (added once the verifier
# carries check (g)):
#   (37) A fixture settings.json carrying a vendor SessionStart --briefing-text hook fails
#        check (g) by name with exit 1.
#   (38) A fixture with no vendor entry passes check (g) and reports the config.json hooks
#        opt-out value (false).
#   (39) A vendor Stop hook fails check (g), and the hooks opt-out value is reported (true) on
#        the fail path too.
#   (40) A config.json omitting the "hooks" key entirely reports "absent" rather than crashing.
#
# Check (h) cases -- "active but hook fragment never merged" (added once the verifier carries
# check (h)):
#   (41) An active-status fixture whose merged_sections.settings carries only "permissions"
#        fails check (h) by name with exit 1.
#   (42) An active fixture carrying both "hooks" and "permissions" passes check (h).
#   (43) An inactive fixture logs a skip and neither passes nor fails check (h).
#
# Check (i) cases -- capture/activation coupling, scoped to this project (added once the
# verifier carries check (i)):
#   (44) An inactive fixture with a capture-enabled matching prefix fails check (i) by name with
#        exit 1 (synthetic -- no live instance of this direction exists on this machine).
#   (45) An active fixture with `enabled: false` emits the new lag-tolerant [WARN] (i) line
#        (never [FAIL] (i)), with exit 0.
#   (46) An active fixture with no matching path_prefix emits the same [WARN] (i) line.
#   (47) A nested-prefix fixture (a shorter enabled prefix and a longer disabled one both
#        matching) resolves to the LONGER entry.
#   (72) The resolved entry's name still appears in the [WARN] (i) line.
#
# Check (j) cases -- postflight tagged-write reachability, against the resolved project's
# DEPLOYED tree (added once the verifier carries check (j)):
#   (48) All four conditions met (both scripts deployed+executable, both core call sites wired)
#        passes check (j).
#   (49) A missing postflight-sapience-notes.sh fails check (j) by name.
#   (50) A non-executable sapience-remember.sh fails check (j) by name.
#   (51) orchestrate-cycle-postflight.sh present but carrying no invocation fails check (j) by
#        name, naming that call site.
#   (52) reconcile-task-status.sh present but carrying no invocation fails check (j) by name,
#        naming that call site.
#   (53) No deployed .claude/scripts tree at all logs a skip, never a pass or a fail.
#
# Token-removal regression cases -- pin "a registered entry contains no value equal to the
# configured token" so a future edit reintroducing SAPIENCE_TOKEN fails loudly, with a negative
# control proving the assertion discriminates rather than passing vacuously:
#   (54) A sentinel token value in config.json never appears anywhere in the written entry
#        (whole-entry scan, not just the SAPIENCE_TOKEN key) -- token-free regardless of
#        config.json content.
#   (55) Negative control: a hand-built ~/.claude.json entry that DOES embed the sentinel token
#        is flagged by both sides -- verify-sapience-mcp.sh fails check (b) with exit 1 and a
#        named remedy (55a), and the writer's own whole-entry comparison judges the same entry
#        divergent and replaces it with the token-free canonical shape (55b).
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
# verbatim for a new project-scoped entry, provided it still resolves to an executable.
#
# The fixture's pinned interpreter is a real executable stub rather than a bare path, because
# inheritance is conditional on the pin still being able to spawn the server. It is deliberately
# NOT the machine's own python3, so a pass proves inheritance actually happened rather than
# coinciding with whatever a fresh `command -v python3` would have returned anyway.
# =====================================================================
HOME9="$WORKDIR/case9/home"
PROJ9="$WORKDIR/case9/proj"
mkdir -p "$HOME9" "$PROJ9" "$WORKDIR/case9/bin"
PINNED9="$WORKDIR/case9/bin/pinned-python3"
printf '#!/bin/sh\nexit 0\n' > "$PINNED9"
chmod +x "$PINNED9"
jq -n --arg cmd "$PINNED9" '{"mcpServers": {"sapience": {"type": "stdio", "command": $cmd, "args": ["/home/x/.sapience/mcp.py"], "env": {"SAPIENCE_HOST": "https://app.spnc.ai"}}}}' \
  > "$HOME9/.claude.json"

HOME="$HOME9" bash "$WRITER_SRC" --project "$PROJ9" --scope project > /dev/null 2>&1
COMMAND9=$(jq -r --arg p "$PROJ9" '.projects[$p].mcpServers.sapience.command' "$HOME9/.claude.json")

if [ "$COMMAND9" = "$PINNED9" ]; then
  pass "Case 9: a usable top-level mcpServers.sapience.command is inherited verbatim for the new project-scoped entry"
else
  fail "Case 9: expected inherited pinned interpreter $PINNED9, got $COMMAND9"
fi

# =====================================================================
# Case 9b/9c: a top-level mcpServers.sapience.command that no longer resolves to an executable
# is NOT inherited -- the writer falls through to a fresh `command -v python3` resolution, so one
# unusable top-level value cannot propagate into every project entry written after it. The
# discard is reported on stderr, never stdout, since the resolver's stdout IS the interpreter.
# =====================================================================
HOME9B="$WORKDIR/case9b/home"
PROJ9B="$WORKDIR/case9b/proj"
mkdir -p "$HOME9B" "$PROJ9B"
jq -n '{"mcpServers": {"sapience": {"type": "stdio", "command": "/nix/store/collected-generation/bin/python3", "args": ["/home/x/.sapience/mcp.py"], "env": {"SAPIENCE_HOST": "https://app.spnc.ai"}}}}' \
  > "$HOME9B/.claude.json"

STDERR9B="$WORKDIR/case9b/stderr.txt"
HOME="$HOME9B" bash "$WRITER_SRC" --project "$PROJ9B" --scope project > /dev/null 2>"$STDERR9B"
COMMAND9B=$(jq -r --arg p "$PROJ9B" '.projects[$p].mcpServers.sapience.command' "$HOME9B/.claude.json")
EXPECTED9B="$(command -v python3 2>/dev/null || echo "")"

if [ -n "$EXPECTED9B" ] && [ "$COMMAND9B" = "$EXPECTED9B" ]; then
  pass "Case 9b: an unresolvable top-level interpreter is discarded and python3 is resolved afresh"
else
  fail "Case 9b: expected fresh resolution '$EXPECTED9B', got '$COMMAND9B'"
fi

if grep -q "does not resolve to an executable" "$STDERR9B"; then
  pass "Case 9c: discarding an unresolvable inherited interpreter is reported on stderr, not stdout"
else
  fail "Case 9c: expected a stderr notice naming the discarded interpreter, got: $(cat "$STDERR9B")"
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
# build_sapience_stub -- installs a minimal PATH-shadowing `sapience` stub into a fresh scratch
# directory (under $WORKDIR), modelled on test-sapience-capture.sh's build_curl_stub. Records
# each invocation's full argv and whether SAPIENCE_NO_CAPTURE_SYNC was "1" in its environment
# into a recorder file inside the stub directory, then MUTATES the fixture
# $HOME/.sapience/config.json's capture.projects[] the way the real vendor CLI's set_project()
# would -- `projects on <path>` sets (or creates) that exact path_prefix's "enabled": true;
# `projects off <path>` sets it false if present, and is a no-op if absent -- so a steady-state
# second call can be observed as "no stub invocation" rather than only inferred.
# =====================================================================
build_sapience_stub() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$WORKDIR")"
  install_sapience_stub_into "$stub_dir"
  echo "$stub_dir"
}

# install_sapience_stub_into <dir> -- writes the recording `sapience` stub (same body
# build_sapience_stub uses) into an EXISTING directory, so a case needing byte-identical
# interpreter resolution across two invocations (sapience present vs. absent) can add/remove
# just the `sapience` file from ONE shared scratch PATH directory rather than using two
# different directories whose OTHER resolved binaries (python3, in particular) could differ.
install_sapience_stub_into() {
  local stub_dir="$1"
  : > "$stub_dir/.calls"
  cat > "$stub_dir/sapience" <<'STUB'
#!/usr/bin/env bash
calls_file="${STUB_DIR:-$(dirname "$0")}/.calls"
{
  printf 'ARGS:%s\n' "$*"
  printf 'NO_CAPTURE_SYNC:%s\n' "${SAPIENCE_NO_CAPTURE_SYNC:-}"
} >> "$calls_file" 2>/dev/null || true
if [ "$1" = "projects" ]; then
  verb="$2"; path="$3"
  cfg="$HOME/.sapience/config.json"
  if [ -f "$cfg" ]; then
    tmp="$(mktemp)"
    if [ "$verb" = "on" ]; then
      jq --arg p "$path" '
        (.capture.projects // []) as $ps |
        ($ps | map(.path_prefix) | index($p)) as $idx |
        if $idx == null then .capture.projects = ($ps + [{"path_prefix": $p, "enabled": true}])
        else .capture.projects[$idx].enabled = true end
      ' "$cfg" > "$tmp" 2>/dev/null && mv "$tmp" "$cfg"
    else
      jq --arg p "$path" '
        (.capture.projects // []) as $ps |
        ($ps | map(.path_prefix) | index($p)) as $idx |
        if $idx == null then . else .capture.projects[$idx].enabled = false end
      ' "$cfg" > "$tmp" 2>/dev/null && mv "$tmp" "$cfg"
    fi
  fi
fi
exit 0
STUB
  chmod +x "$stub_dir/sapience"
}

# sapience_stub_call_count <stub_dir> -- number of recorded invocations. `grep -c` on a
# no-match file already prints "0" AND exits nonzero, so a trailing `|| echo 0` would double it
# to "0\n0" -- the count is captured separately from the exit status instead.
sapience_stub_call_count() {
  local stub_dir="$1" n
  if [ -f "$stub_dir/.calls" ]; then
    n="$(grep -c '^ARGS:' "$stub_dir/.calls" 2>/dev/null)"
    [ -z "$n" ] && n=0
    printf '%s' "$n"
  else
    printf '0'
  fi
}

# build_path_without_sapience -- a fresh, single-directory PATH (symlinks to every executable
# reachable on the CURRENT $PATH, EXCEPT any file named `sapience`) so a test case can simulate
# "no sapience binary installed" while bash/jq/realpath/readlink/timeout and everything else
# this writer needs still resolve normally -- removing the real sapience binary's own containing
# directory wholesale would also remove jq, since both live in the same nix-profile bin/ on this
# machine.
build_path_without_sapience() {
  local scratch dir entry base
  scratch="$(mktemp -d -p "$WORKDIR")"
  local old_ifs="$IFS"
  IFS=':'
  for dir in $PATH; do
    [ -d "$dir" ] || continue
    for entry in "$dir"/*; do
      [ -e "$entry" ] || continue
      base="$(basename "$entry")"
      [ "$base" = "sapience" ] && continue
      [ -e "$scratch/$base" ] && continue
      ln -s "$entry" "$scratch/$base" 2>/dev/null || true
    done
  done
  IFS="$old_ifs"
  printf '%s' "$scratch"
}

# sapience_stub_last_args <stub_dir> -- the most recent recorded invocation's argv line.
sapience_stub_last_args() {
  local stub_dir="$1"
  grep '^ARGS:' "$stub_dir/.calls" 2>/dev/null | tail -1 | sed 's/^ARGS://'
}

# sapience_stub_last_no_capture_sync <stub_dir> -- the most recent invocation's recorded
# SAPIENCE_NO_CAPTURE_SYNC value.
sapience_stub_last_no_capture_sync() {
  local stub_dir="$1"
  grep '^NO_CAPTURE_SYNC:' "$stub_dir/.calls" 2>/dev/null | tail -1 | sed 's/^NO_CAPTURE_SYNC://'
}

# =====================================================================
# Case 56: --capture-set on with no existing entry invokes the stub with
# `projects on <path>` and SAPIENCE_NO_CAPTURE_SYNC=1 in its environment.
# =====================================================================
HOME56="$WORKDIR/case56/home"
PROJ56="$WORKDIR/case56/proj"
mkdir -p "$HOME56/.sapience" "$PROJ56"
echo '{}' > "$HOME56/.sapience/config.json"
STUB56="$(build_sapience_stub)"

PATH="$STUB56:$PATH" STUB_DIR="$STUB56" HOME="$HOME56" bash "$WRITER_SRC" --capture-set on --project "$PROJ56" --quiet > /dev/null 2>&1
CALLS56="$(sapience_stub_call_count "$STUB56")"
ARGS56="$(sapience_stub_last_args "$STUB56")"
NOCS56="$(sapience_stub_last_no_capture_sync "$STUB56")"
ENABLED56="$(jq -r --arg p "$PROJ56" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME56/.sapience/config.json")"

if [ "$CALLS56" = "1" ] && [ "$ARGS56" = "projects on $PROJ56" ] && [ "$NOCS56" = "1" ] && [ "$ENABLED56" = "true" ]; then
  pass "Case 56: --capture-set on with no existing entry invokes the stub with 'projects on <path>' and SAPIENCE_NO_CAPTURE_SYNC=1"
else
  fail "Case 56: calls=$CALLS56 args='$ARGS56' nocs=$NOCS56 enabled=$ENABLED56"
fi

# =====================================================================
# Case 57: --capture-set off against an enabled:true entry invokes `projects off <path>`.
# =====================================================================
HOME57="$WORKDIR/case57/home"
PROJ57="$WORKDIR/case57/proj"
mkdir -p "$HOME57/.sapience" "$PROJ57"
jq -n --arg p "$PROJ57" '{"capture": {"projects": [{"path_prefix": $p, "enabled": true}]}}' > "$HOME57/.sapience/config.json"
STUB57="$(build_sapience_stub)"

PATH="$STUB57:$PATH" STUB_DIR="$STUB57" HOME="$HOME57" bash "$WRITER_SRC" --capture-set off --project "$PROJ57" --quiet > /dev/null 2>&1
CALLS57="$(sapience_stub_call_count "$STUB57")"
ARGS57="$(sapience_stub_last_args "$STUB57")"
ENABLED57="$(jq -r --arg p "$PROJ57" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME57/.sapience/config.json")"

if [ "$CALLS57" = "1" ] && [ "$ARGS57" = "projects off $PROJ57" ] && [ "$ENABLED57" = "false" ]; then
  pass "Case 57: --capture-set off against an enabled:true entry invokes 'projects off <path>'"
else
  fail "Case 57: calls=$CALLS57 args='$ARGS57' enabled=$ENABLED57"
fi

# =====================================================================
# Case 58: steady state -- --capture-set on against an already-enabled EXACT entry records no
# stub invocation and prints nothing (--quiet).
# =====================================================================
HOME58="$WORKDIR/case58/home"
PROJ58="$WORKDIR/case58/proj"
mkdir -p "$HOME58/.sapience" "$PROJ58"
jq -n --arg p "$PROJ58" '{"capture": {"projects": [{"path_prefix": $p, "enabled": true}]}}' > "$HOME58/.sapience/config.json"
STUB58="$(build_sapience_stub)"

OUT58="$(PATH="$STUB58:$PATH" STUB_DIR="$STUB58" HOME="$HOME58" bash "$WRITER_SRC" --capture-set on --project "$PROJ58" --quiet 2>&1)"
CALLS58="$(sapience_stub_call_count "$STUB58")"

if [ "$CALLS58" = "0" ] && [ -z "$OUT58" ]; then
  pass "Case 58: steady state (--capture-set on against an already-enabled exact entry) records no stub invocation and prints nothing"
else
  fail "Case 58: calls=$CALLS58 out='$OUT58'"
fi

# =====================================================================
# Case 59: no `sapience` stub on PATH at all exits 0 silently (--quiet).
# =====================================================================
HOME59="$WORKDIR/case59/home"
PROJ59="$WORKDIR/case59/proj"
mkdir -p "$HOME59/.sapience" "$PROJ59"
echo '{}' > "$HOME59/.sapience/config.json"
NO_SAPIENCE_PATH="$(build_path_without_sapience)"

RC59=0
OUT59="$(PATH="$NO_SAPIENCE_PATH" HOME="$HOME59" bash "$WRITER_SRC" --capture-set on --project "$PROJ59" --quiet 2>&1)" || RC59=$?

if [ "$RC59" -eq 0 ] && [ -z "$OUT59" ]; then
  pass "Case 59: no sapience binary on PATH exits 0 silently"
else
  fail "Case 59: rc=$RC59 out='$OUT59'"
fi

# =====================================================================
# Case 60: an enabled PARENT prefix with no exact entry for the CHILD still invokes `on` for
# the child (the exact-path idempotence decision, not the longest-prefix match).
# =====================================================================
HOME60="$WORKDIR/case60/home"
PARENT60="$WORKDIR/case60/parent"
CHILD60="$PARENT60/child"
mkdir -p "$HOME60/.sapience" "$CHILD60"
jq -n --arg parent "$PARENT60" '{"capture": {"projects": [{"path_prefix": $parent, "enabled": true}]}}' > "$HOME60/.sapience/config.json"
STUB60="$(build_sapience_stub)"

PATH="$STUB60:$PATH" STUB_DIR="$STUB60" HOME="$HOME60" bash "$WRITER_SRC" --capture-set on --project "$CHILD60" --quiet > /dev/null 2>&1
CALLS60="$(sapience_stub_call_count "$STUB60")"
ARGS60="$(sapience_stub_last_args "$STUB60")"

if [ "$CALLS60" = "1" ] && [ "$ARGS60" = "projects on $CHILD60" ]; then
  pass "Case 60: an enabled parent prefix with no exact entry for the child still triggers an 'on' call for the child"
else
  fail "Case 60: calls=$CALLS60 args='$ARGS60'"
fi

# =====================================================================
# Case 61: --capture-set --dry-run records no stub invocation and mutates nothing.
# =====================================================================
HOME61="$WORKDIR/case61/home"
PROJ61="$WORKDIR/case61/proj"
mkdir -p "$HOME61/.sapience" "$PROJ61"
echo '{}' > "$HOME61/.sapience/config.json"
STUB61="$(build_sapience_stub)"
BEFORE61="$(md5sum "$HOME61/.sapience/config.json" | awk '{print $1}')"

PATH="$STUB61:$PATH" STUB_DIR="$STUB61" HOME="$HOME61" bash "$WRITER_SRC" --capture-set on --project "$PROJ61" --dry-run > /dev/null 2>&1
CALLS61="$(sapience_stub_call_count "$STUB61")"
AFTER61="$(md5sum "$HOME61/.sapience/config.json" | awk '{print $1}')"

if [ "$CALLS61" = "0" ] && [ "$BEFORE61" = "$AFTER61" ]; then
  pass "Case 61: --capture-set --dry-run records no stub invocation and mutates nothing"
else
  fail "Case 61: calls=$CALLS61 before=$BEFORE61 after=$AFTER61"
fi

# =====================================================================
# Case 62: a vanished enabled:true capture entry is turned off (stub invoked with
# `projects off <vanished-path>`) while a sibling entry whose path exists is left untouched,
# proved in the same fixture/invocation (mirrors case 31's sibling-row idiom).
# =====================================================================
HOME62="$WORKDIR/case62/home"
PRESENT62="$WORKDIR/case62/present-proj"
mkdir -p "$HOME62/.sapience" "$PRESENT62"
VANISHED62="$WORKDIR/case62/vanished-proj-never-created"
jq -n --arg vanished "$VANISHED62" --arg present "$PRESENT62" \
  '{"capture": {"projects": [
      {"path_prefix": $vanished, "enabled": true},
      {"path_prefix": $present, "enabled": true}
    ]}}' > "$HOME62/.sapience/config.json"
STUB62="$(build_sapience_stub)"

PATH="$STUB62:$PATH" STUB_DIR="$STUB62" HOME="$HOME62" bash "$WRITER_SRC" --reap-capture --quiet > /dev/null 2>&1
CALLS62="$(sapience_stub_call_count "$STUB62")"
ARGS62="$(sapience_stub_last_args "$STUB62")"
VANISHED_STATE62="$(jq -r --arg p "$VANISHED62" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME62/.sapience/config.json")"
PRESENT_STATE62="$(jq -r --arg p "$PRESENT62" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME62/.sapience/config.json")"

if [ "$CALLS62" = "1" ] && [ "$ARGS62" = "projects off $VANISHED62" ] && [ "$VANISHED_STATE62" = "false" ] && [ "$PRESENT_STATE62" = "true" ]; then
  pass "Case 62: --reap-capture turns off a vanished enabled:true entry while leaving a present-path sibling entry untouched"
else
  fail "Case 62: calls=$CALLS62 args='$ARGS62' vanished=$VANISHED_STATE62 present=$PRESENT_STATE62"
fi

# =====================================================================
# Case 63: a vanished entry already enabled:false records no stub invocation.
# =====================================================================
HOME63="$WORKDIR/case63/home"
mkdir -p "$HOME63/.sapience"
VANISHED63="$WORKDIR/case63/vanished-proj-never-created"
jq -n --arg vanished "$VANISHED63" \
  '{"capture": {"projects": [{"path_prefix": $vanished, "enabled": false}]}}' > "$HOME63/.sapience/config.json"
STUB63="$(build_sapience_stub)"

PATH="$STUB63:$PATH" STUB_DIR="$STUB63" HOME="$HOME63" bash "$WRITER_SRC" --reap-capture --quiet > /dev/null 2>&1
CALLS63="$(sapience_stub_call_count "$STUB63")"

if [ "$CALLS63" = "0" ]; then
  pass "Case 63: a vanished entry already enabled:false records no stub invocation"
else
  fail "Case 63: calls=$CALLS63"
fi

# =====================================================================
# Case 64: --reap-capture --dry-run records no stub invocation and mutates nothing.
# =====================================================================
HOME64="$WORKDIR/case64/home"
mkdir -p "$HOME64/.sapience"
VANISHED64="$WORKDIR/case64/vanished-proj-never-created"
jq -n --arg vanished "$VANISHED64" \
  '{"capture": {"projects": [{"path_prefix": $vanished, "enabled": true}]}}' > "$HOME64/.sapience/config.json"
STUB64="$(build_sapience_stub)"
BEFORE64="$(md5sum "$HOME64/.sapience/config.json" | awk '{print $1}')"

PATH="$STUB64:$PATH" STUB_DIR="$STUB64" HOME="$HOME64" bash "$WRITER_SRC" --reap-capture --dry-run > /dev/null 2>&1
CALLS64="$(sapience_stub_call_count "$STUB64")"
AFTER64="$(md5sum "$HOME64/.sapience/config.json" | awk '{print $1}')"

if [ "$CALLS64" = "0" ] && [ "$BEFORE64" = "$AFTER64" ]; then
  pass "Case 64: --reap-capture --dry-run records no stub invocation and mutates nothing"
else
  fail "Case 64: calls=$CALLS64 before=$BEFORE64 after=$AFTER64"
fi

# =====================================================================
# Case 65: no `sapience` on PATH exits 0 silently for --reap-capture.
# =====================================================================
HOME65="$WORKDIR/case65/home"
mkdir -p "$HOME65/.sapience"
VANISHED65="$WORKDIR/case65/vanished-proj-never-created"
jq -n --arg vanished "$VANISHED65" \
  '{"capture": {"projects": [{"path_prefix": $vanished, "enabled": true}]}}' > "$HOME65/.sapience/config.json"
NO_SAPIENCE_PATH65="$(build_path_without_sapience)"

RC65=0
OUT65="$(PATH="$NO_SAPIENCE_PATH65" HOME="$HOME65" bash "$WRITER_SRC" --reap-capture --quiet 2>&1)" || RC65=$?

if [ "$RC65" -eq 0 ] && [ -z "$OUT65" ]; then
  pass "Case 65: no sapience binary on PATH exits 0 silently for --reap-capture"
else
  fail "Case 65: rc=$RC65 out='$OUT65'"
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

  # =====================================================================
  # Hook-level capture-coupling cases (Phase 3). Each fixture needs its OWN copy of the (now
  # capture-aware) writer at $HOME/.claude/scripts/setup-sapience-mcp.sh plus a PATH-shadowed
  # recording `sapience` stub so the writer's internal sapience_cli call actually mutates
  # $HOME/.sapience/config.json the way the real vendor CLI would.
  # =====================================================================

  # Case 66: an active repo emits a capture notice and the stub records 'projects on <checkout>'.
  HOME66="$WORKDIR/case66/home"
  REPO66="$WORKDIR/case66/repo"
  mkdir -p "$HOME66/.sapience" "$HOME66/.claude/scripts" "$REPO66"
  echo '{}' > "$HOME66/.sapience/config.json"
  cp "$WRITER_SRC" "$HOME66/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME66/.claude/scripts/setup-sapience-mcp.sh"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO66/.claude-extensions.json"
  (cd "$REPO66" && git init -q 2>/dev/null || true)
  STUB66="$(build_sapience_stub)"

  OUT66=$(cd "$REPO66" && PATH="$STUB66:$PATH" STUB_DIR="$STUB66" HOME="$HOME66" bash "$HOOK_SRC" 2>&1)
  ARGS66="$(sapience_stub_last_args "$STUB66")"
  CAPTURE66="$(jq -r --arg p "$REPO66" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled // "ABSENT"' "$HOME66/.sapience/config.json")"

  if [ "$ARGS66" = "projects on $REPO66" ] && [ "$CAPTURE66" = "true" ] \
     && printf '%s' "$OUT66" | jq -e '.additionalContext | contains("capture")' > /dev/null 2>&1; then
    pass "Case 66: an active repo emits a capture notice and the stub records 'projects on <checkout>'"
  else
    fail "Case 66: args='$ARGS66' capture=$CAPTURE66 output=$OUT66"
  fi

  # Case 67: an inactive repo with an existing enabled:true entry records 'projects off
  # <checkout>' and emits a notice.
  HOME67="$WORKDIR/case67/home"
  REPO67="$WORKDIR/case67/repo"
  mkdir -p "$HOME67/.sapience" "$HOME67/.claude/scripts" "$REPO67"
  cp "$WRITER_SRC" "$HOME67/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME67/.claude/scripts/setup-sapience-mcp.sh"
  jq -n --arg p "$REPO67" '{"capture": {"projects": [{"path_prefix": $p, "enabled": true}]}}' > "$HOME67/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$REPO67/.claude-extensions.json"
  (cd "$REPO67" && git init -q 2>/dev/null || true)
  STUB67="$(build_sapience_stub)"

  OUT67=$(cd "$REPO67" && PATH="$STUB67:$PATH" STUB_DIR="$STUB67" HOME="$HOME67" bash "$HOOK_SRC" 2>&1)
  ARGS67="$(sapience_stub_last_args "$STUB67")"
  CAPTURE67="$(jq -r --arg p "$REPO67" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME67/.sapience/config.json")"

  if [ "$ARGS67" = "projects off $REPO67" ] && [ "$CAPTURE67" = "false" ] \
     && printf '%s' "$OUT67" | jq -e '.additionalContext | contains("capture")' > /dev/null 2>&1; then
    pass "Case 67: an inactive repo with an existing enabled:true entry records 'projects off <checkout>' and emits a notice"
  else
    fail "Case 67: args='$ARGS67' capture=$CAPTURE67 output=$OUT67"
  fi

  # Case 68: steady state -- a second invocation against case 66's already-settled fixture
  # records no additional stub invocation and the hook prints {}.
  CALLS66_BEFORE68="$(sapience_stub_call_count "$STUB66")"
  OUT68=$(cd "$REPO66" && PATH="$STUB66:$PATH" STUB_DIR="$STUB66" HOME="$HOME66" bash "$HOOK_SRC" 2>&1)
  CALLS66_AFTER68="$(sapience_stub_call_count "$STUB66")"

  if [ "$OUT68" = '{}' ] && [ "$CALLS66_BEFORE68" = "$CALLS66_AFTER68" ]; then
    pass "Case 68: steady state records no additional stub invocation and the hook prints {}"
  else
    fail "Case 68: out='$OUT68' calls_before=$CALLS66_BEFORE68 calls_after=$CALLS66_AFTER68"
  fi

  # Case 69: no sapience binary on PATH -- capture degrades silently, and the MCP-registration
  # half still works (demonstrated here as "unaffected": a fixture already settled for BOTH
  # halves stays at exactly {} when re-run with no sapience binary reachable).
  HOME69="$WORKDIR/case69/home"
  REPO69="$WORKDIR/case69/repo"
  mkdir -p "$HOME69/.sapience" "$HOME69/.claude/scripts" "$REPO69"
  echo '{}' > "$HOME69/.sapience/config.json"
  cp "$WRITER_SRC" "$HOME69/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME69/.claude/scripts/setup-sapience-mcp.sh"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO69/.claude-extensions.json"
  (cd "$REPO69" && git init -q 2>/dev/null || true)
  # ONE shared scratch PATH directory (no real sapience binary, everything else symlinked from
  # the ambient PATH) used for BOTH runs below, so python3's resolved absolute path is
  # byte-identical across them and the only variable is whether `sapience` itself is present --
  # using two DIFFERENT scratch directories here would make resolve_interpreter() see a
  # different `command -v python3` result each time and spuriously judge the entry "diverged".
  SHARED69="$(build_path_without_sapience)"
  install_sapience_stub_into "$SHARED69"
  # First run (sapience present) settles both the MCP entry and the capture entry.
  (cd "$REPO69" && PATH="$SHARED69" STUB_DIR="$SHARED69" HOME="$HOME69" bash "$HOOK_SRC" > /dev/null 2>&1)
  rm -f "$SHARED69/sapience"

  RC69=0
  OUT69=$(cd "$REPO69" && PATH="$SHARED69" HOME="$HOME69" bash "$HOOK_SRC" 2>&1) || RC69=$?
  ENTRY69="$(jq -c --arg p "$REPO69" '.projects[$p].mcpServers.sapience // "ABSENT"' "$HOME69/.claude.json")"

  if [ "$RC69" -eq 0 ] && [ "$OUT69" = '{}' ] && [ "$ENTRY69" != '"ABSENT"' ]; then
    pass "Case 69: no sapience binary on PATH prints {} and the MCP-registration half's existing entry is unaffected"
  else
    fail "Case 69: rc=$RC69 out='$OUT69' mcp_entry=$ENTRY69"
  fi

  # Case 71: a session with BOTH an orphaned capture entry (vanished project dir) and an active
  # current repo emits exactly one parseable JSON line mentioning both actions.
  HOME71="$WORKDIR/case71/home"
  REPO71="$WORKDIR/case71/repo"
  mkdir -p "$HOME71/.sapience" "$HOME71/.claude/scripts" "$REPO71"
  cp "$WRITER_SRC" "$HOME71/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOME71/.claude/scripts/setup-sapience-mcp.sh"
  VANISHED71="$WORKDIR/case71/vanished-proj-never-created"
  jq -n --arg v "$VANISHED71" '{"capture": {"projects": [{"path_prefix": $v, "enabled": true}]}}' > "$HOME71/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$REPO71/.claude-extensions.json"
  (cd "$REPO71" && git init -q 2>/dev/null || true)
  STUB71="$(build_sapience_stub)"

  OUT71=$(cd "$REPO71" && PATH="$STUB71:$PATH" STUB_DIR="$STUB71" HOME="$HOME71" bash "$HOOK_SRC" 2>&1)
  LINES71=$(printf '%s' "$OUT71" | wc -l)
  CTX71=$(printf '%s' "$OUT71" | jq -r '.additionalContext // ""' 2>/dev/null)
  VANISHED_STATE71="$(jq -r --arg p "$VANISHED71" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled' "$HOME71/.sapience/config.json")"
  REPO_STATE71="$(jq -r --arg p "$REPO71" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled // "ABSENT"' "$HOME71/.sapience/config.json")"

  if [ "$LINES71" -eq 0 ] && printf '%s' "$CTX71" | grep -qi "turned off capture" && printf '%s' "$CTX71" | grep -q "capture on" \
     && [ "$VANISHED_STATE71" = "false" ] && [ "$REPO_STATE71" = "true" ]; then
    pass "Case 71: an orphaned capture entry and an active current repo in one invocation both land, mentioned in a single JSON line"
  else
    fail "Case 71: lines=$LINES71 vanished=$VANISHED_STATE71 repo=$REPO_STATE71 output=$OUT71"
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
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"permissions": true, "hooks": true}}}}}' > "$PROJ20/.claude-extensions.json"
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

  # =====================================================================
  # Case 37: a fixture settings.json carrying a vendor SessionStart --briefing-text hook fails
  # check (g) by name with exit 1.
  # =====================================================================
  HOME37="$WORKDIR/case37/home"
  PROJ37="$WORKDIR/case37/repo"
  mkdir -p "$HOME37/.claude" "$HOME37/.sapience" "$PROJ37"
  echo '{"hooks": false}' > "$HOME37/.sapience/config.json"
  jq -n '{"hooks": {"SessionStart": [{"hooks": [{"command": "python3 /home/x/.sapience/mcp.py --briefing-text"}]}]}}' > "$HOME37/.claude/settings.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ37/.claude-extensions.json"

  RC37=0
  OUT37=$(cd "$PROJ37" && HOME="$HOME37" bash "$VERIFIER_SRC" --project "$PROJ37" 2>&1) || RC37=$?
  if [ "$RC37" -eq 1 ] && printf '%s' "$OUT37" | grep -q '\[FAIL\] (g)'; then
    pass "Case 37: a vendor SessionStart hook in settings.json fails check (g) by name with exit 1"
  else
    fail "Case 37: expected exit 1 and a [FAIL] (g) line; rc=$RC37 output=$OUT37"
  fi

  # =====================================================================
  # Case 38: a fixture with no vendor entry passes check (g) and reports the hooks opt-out
  # value (false).
  # =====================================================================
  HOME38="$WORKDIR/case38/home"
  PROJ38="$WORKDIR/case38/repo"
  mkdir -p "$HOME38/.claude" "$HOME38/.sapience" "$PROJ38"
  echo '{"hooks": false}' > "$HOME38/.sapience/config.json"
  jq -n '{"hooks": {}}' > "$HOME38/.claude/settings.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ38/.claude-extensions.json"

  OUT38=$(cd "$PROJ38" && HOME="$HOME38" bash "$VERIFIER_SRC" --project "$PROJ38" 2>&1)
  if printf '%s' "$OUT38" | grep -q '\[PASS\] (g)' && printf '%s' "$OUT38" | grep -q 'hooks opt-out value: false'; then
    pass "Case 38: no vendor hook passes check (g) and reports the hooks opt-out value (false)"
  else
    fail "Case 38: expected a [PASS] (g) line and 'hooks opt-out value: false'; output=$OUT38"
  fi

  # =====================================================================
  # Case 39: a vendor Stop hook fails check (g), and the hooks opt-out value is reported (true)
  # on the fail path too -- the value line is unconditional, not gated on pass/fail.
  # =====================================================================
  HOME39="$WORKDIR/case39/home"
  PROJ39="$WORKDIR/case39/repo"
  mkdir -p "$HOME39/.claude" "$HOME39/.sapience" "$PROJ39"
  echo '{"hooks": true}' > "$HOME39/.sapience/config.json"
  jq -n '{"hooks": {"Stop": [{"hooks": [{"command": "python3 /home/x/.sapience/mcp.py --effect-line"}]}]}}' > "$HOME39/.claude/settings.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ39/.claude-extensions.json"

  OUT39=$(cd "$PROJ39" && HOME="$HOME39" bash "$VERIFIER_SRC" --project "$PROJ39" 2>&1)
  if printf '%s' "$OUT39" | grep -q '\[FAIL\] (g)' && printf '%s' "$OUT39" | grep -q 'hooks opt-out value: true'; then
    pass "Case 39: a vendor Stop hook fails check (g), and the opt-out value is reported as true on the fail path too"
  else
    fail "Case 39: expected [FAIL] (g) and 'hooks opt-out value: true'; output=$OUT39"
  fi

  # =====================================================================
  # Case 40: a config.json omitting the "hooks" key entirely reports "absent" rather than
  # crashing.
  # =====================================================================
  HOME40="$WORKDIR/case40/home"
  PROJ40="$WORKDIR/case40/repo"
  mkdir -p "$HOME40/.claude" "$HOME40/.sapience" "$PROJ40"
  echo '{}' > "$HOME40/.sapience/config.json"
  jq -n '{"hooks": {}}' > "$HOME40/.claude/settings.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ40/.claude-extensions.json"

  OUT40=$(cd "$PROJ40" && HOME="$HOME40" bash "$VERIFIER_SRC" --project "$PROJ40" 2>&1)
  if printf '%s' "$OUT40" | grep -q 'hooks opt-out value: absent'; then
    pass "Case 40: a config.json omitting the hooks key reports 'absent' rather than crashing"
  else
    fail "Case 40: expected 'hooks opt-out value: absent'; output=$OUT40"
  fi

  # =====================================================================
  # Case 41: an active-status fixture whose merged_sections.settings carries only "permissions"
  # fails check (h) by name with exit 1.
  # =====================================================================
  HOME41="$WORKDIR/case41/home"
  PROJ41="$WORKDIR/case41/repo"
  mkdir -p "$HOME41" "$PROJ41"
  echo '{}' > "$HOME41/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"permissions": true}}}}}' > "$PROJ41/.claude-extensions.json"

  RC41=0
  OUT41=$(cd "$PROJ41" && HOME="$HOME41" bash "$VERIFIER_SRC" --project "$PROJ41" 2>&1) || RC41=$?
  if [ "$RC41" -eq 1 ] && printf '%s' "$OUT41" | grep -q '\[FAIL\] (h)'; then
    pass "Case 41: an active fixture whose merged_sections.settings lacks 'hooks' fails check (h) by name with exit 1"
  else
    fail "Case 41: expected exit 1 and [FAIL] (h); rc=$RC41 output=$OUT41"
  fi

  # =====================================================================
  # Case 42: an active fixture carrying both "hooks" and "permissions" passes check (h).
  # =====================================================================
  HOME42="$WORKDIR/case42/home"
  PROJ42="$WORKDIR/case42/repo"
  mkdir -p "$HOME42" "$PROJ42"
  echo '{}' > "$HOME42/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"permissions": true, "hooks": true}}}}}' > "$PROJ42/.claude-extensions.json"

  OUT42=$(cd "$PROJ42" && HOME="$HOME42" bash "$VERIFIER_SRC" --project "$PROJ42" 2>&1)
  if printf '%s' "$OUT42" | grep -q '\[PASS\] (h)'; then
    pass "Case 42: an active fixture carrying both hooks and permissions passes check (h)"
  else
    fail "Case 42: expected [PASS] (h); output=$OUT42"
  fi

  # =====================================================================
  # Case 43: an inactive fixture logs a skip and neither passes nor fails check (h).
  # =====================================================================
  HOME43="$WORKDIR/case43/home"
  PROJ43="$WORKDIR/case43/repo"
  mkdir -p "$HOME43" "$PROJ43"
  echo '{}' > "$HOME43/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ43/.claude-extensions.json"

  OUT43=$(cd "$PROJ43" && HOME="$HOME43" bash "$VERIFIER_SRC" --project "$PROJ43" 2>&1)
  if ! printf '%s' "$OUT43" | grep -q '\[PASS\] (h)' && ! printf '%s' "$OUT43" | grep -q '\[FAIL\] (h)' \
     && printf '%s' "$OUT43" | grep -q 'skipping hook-fragment-merged check'; then
    pass "Case 43: an inactive fixture logs a skip and neither passes nor fails check (h)"
  else
    fail "Case 43: expected a skip line and no [PASS]/[FAIL] (h); output=$OUT43"
  fi

  # =====================================================================
  # Case 44: an inactive fixture with a capture-enabled matching prefix fails check (i) by name
  # with exit 1 (synthetic -- no live instance of this direction exists on this machine).
  # =====================================================================
  HOME44="$WORKDIR/case44/home"
  PROJ44="$WORKDIR/case44/repo"
  mkdir -p "$HOME44/.sapience" "$PROJ44"
  echo '{}' > "$HOME44/.claude.json"
  jq -n --arg p "$PROJ44" '{"capture": {"mode": "opt-in", "projects": [{"path_prefix": $p, "name": "case44", "enabled": true}]}}' > "$HOME44/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ44/.claude-extensions.json"

  RC44=0
  OUT44=$(cd "$PROJ44" && HOME="$HOME44" bash "$VERIFIER_SRC" --project "$PROJ44" 2>&1) || RC44=$?
  if [ "$RC44" -eq 1 ] && printf '%s' "$OUT44" | grep -q '\[FAIL\] (i)'; then
    pass "Case 44: an inactive fixture with a capture-enabled matching prefix fails check (i) by name with exit 1"
  else
    fail "Case 44: expected exit 1 and [FAIL] (i); rc=$RC44 output=$OUT44"
  fi

  # =====================================================================
  # Case 45: an active fixture with enabled:false emits the new lag-tolerant [WARN] (i) line
  # (never [FAIL] (i)), and the verifier's own exit status is unaffected (still 0 here --
  # nothing else in this fixture fails).
  # =====================================================================
  HOME45="$WORKDIR/case45/home"
  PROJ45="$WORKDIR/case45/repo"
  mkdir -p "$HOME45/.claude" "$HOME45/.sapience" "$PROJ45"
  echo '{}' > "$HOME45/.claude/settings.json"
  jq -n --arg p "$PROJ45" '{"capture": {"mode": "opt-in", "projects": [{"path_prefix": $p, "name": "case45", "enabled": false}]}}' > "$HOME45/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"hooks": true, "permissions": true}}}}}' > "$PROJ45/.claude-extensions.json"
  # Otherwise-all-green fixture (mirrors case 20's recipe) so the ONLY check in play for the
  # overall exit status below is (i)'s new non-failing WARN, never the now-WARN line itself
  # masquerading as "still exit 0" while OTHER checks are actually what is failing.
  if [ -f "$INSTALLER_SRC" ]; then
    HOME="$HOME45" bash "$INSTALLER_SRC" > /dev/null 2>&1
  else
    mkdir -p "$HOME45/.claude/hooks" "$HOME45/.claude/scripts"
    cp "$HOOK_SRC" "$HOME45/.claude/hooks/sapience-mcp-register-project.sh" 2>/dev/null
    cp "$WRITER_SRC" "$HOME45/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
    chmod +x "$HOME45/.claude/hooks/sapience-mcp-register-project.sh" "$HOME45/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
  fi
  HOME="$HOME45" bash "$WRITER_SRC" --project "$PROJ45" --scope project > /dev/null 2>&1

  RC45=0
  OUT45=$(cd "$PROJ45" && HOME="$HOME45" bash "$VERIFIER_SRC" --project "$PROJ45" 2>&1) || RC45=$?
  if printf '%s' "$OUT45" | grep -q 'capture not enabled' && printf '%s' "$OUT45" | grep -q '\[WARN\] (i)' \
     && ! printf '%s' "$OUT45" | grep -q '\[FAIL\] (i)' && [ "$RC45" -eq 0 ]; then
    pass "Case 45: an active fixture with enabled:false emits the new [WARN] (i) line, never [FAIL] (i), with exit 0"
  else
    fail "Case 45: expected a [WARN] (i) line, no [FAIL] (i), and exit 0; rc=$RC45 output=$OUT45"
  fi

  # =====================================================================
  # Case 46: an active fixture with no matching path_prefix emits the same [WARN] (i) line.
  # =====================================================================
  HOME46="$WORKDIR/case46/home"
  PROJ46="$WORKDIR/case46/repo"
  OTHER46="$WORKDIR/case46/other-unrelated-path"
  mkdir -p "$HOME46/.claude" "$HOME46/.sapience" "$PROJ46"
  echo '{}' > "$HOME46/.claude/settings.json"
  jq -n --arg p "$OTHER46" '{"capture": {"mode": "opt-in", "projects": [{"path_prefix": $p, "name": "unrelated", "enabled": true}]}}' > "$HOME46/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"hooks": true, "permissions": true}}}}}' > "$PROJ46/.claude-extensions.json"
  if [ -f "$INSTALLER_SRC" ]; then
    HOME="$HOME46" bash "$INSTALLER_SRC" > /dev/null 2>&1
  else
    mkdir -p "$HOME46/.claude/hooks" "$HOME46/.claude/scripts"
    cp "$HOOK_SRC" "$HOME46/.claude/hooks/sapience-mcp-register-project.sh" 2>/dev/null
    cp "$WRITER_SRC" "$HOME46/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
    chmod +x "$HOME46/.claude/hooks/sapience-mcp-register-project.sh" "$HOME46/.claude/scripts/setup-sapience-mcp.sh" 2>/dev/null
  fi
  HOME="$HOME46" bash "$WRITER_SRC" --project "$PROJ46" --scope project > /dev/null 2>&1

  RC46=0
  OUT46=$(cd "$PROJ46" && HOME="$HOME46" bash "$VERIFIER_SRC" --project "$PROJ46" 2>&1) || RC46=$?
  if printf '%s' "$OUT46" | grep -q 'capture not enabled' && printf '%s' "$OUT46" | grep -q '\[WARN\] (i)' \
     && ! printf '%s' "$OUT46" | grep -q '\[FAIL\] (i)' && [ "$RC46" -eq 0 ]; then
    pass "Case 46: an active fixture with no matching path_prefix emits the same [WARN] (i) line, with exit 0"
  else
    fail "Case 46: expected a [WARN] (i) line, no [FAIL] (i), and exit 0; rc=$RC46 output=$OUT46"
  fi

  # =====================================================================
  # Case 72: the resolved entry's name still appears in the [WARN] (i) line (case 45's fixture
  # names its entry 'case45').
  # =====================================================================
  if printf '%s' "$OUT45" | grep '\[WARN\] (i)' | grep -q "'case45'"; then
    pass "Case 72: the resolved entry's name appears in the [WARN] (i) line"
  else
    fail "Case 72: expected the resolved entry name 'case45' in the [WARN] (i) line; output=$OUT45"
  fi

  # =====================================================================
  # Case 47: a nested-prefix fixture (a shorter enabled prefix and a longer disabled one, both
  # matching) resolves to the LONGER entry, mirroring sapience_capture.py's longest-prefix-wins
  # rule.
  # =====================================================================
  HOME47="$WORKDIR/case47/home"
  PARENT47="$WORKDIR/case47/parent"
  PROJ47="$PARENT47/nested-child"
  mkdir -p "$HOME47/.sapience" "$PROJ47"
  echo '{}' > "$HOME47/.claude.json"
  jq -n --arg outer "$PARENT47" --arg inner "$PROJ47" \
    '{"capture": {"mode": "opt-in", "projects": [
        {"path_prefix": $outer, "name": "nested-outer", "enabled": true},
        {"path_prefix": $inner, "name": "nested-inner", "enabled": false}
      ]}}' > "$HOME47/.sapience/config.json"
  jq -n '{"extensions": {"sapience": {"status": "active", "merged_sections": {"settings": {"hooks": true, "permissions": true}}}}}' > "$PROJ47/.claude-extensions.json"

  OUT47=$(cd "$PROJ47" && HOME="$HOME47" bash "$VERIFIER_SRC" --project "$PROJ47" 2>&1)
  if printf '%s' "$OUT47" | grep -q "'nested-inner'" && ! printf '%s' "$OUT47" | grep -q "'nested-outer'"; then
    pass "Case 47: a nested-prefix fixture resolves to the LONGER (inner) entry, not the shorter outer one"
  else
    fail "Case 47: expected resolution to the longer 'nested-inner' entry; output=$OUT47"
  fi

  # =====================================================================
  # Check (j) cases -- postflight tagged-write reachability, against the resolved project's
  # DEPLOYED tree (added once the verifier carries check (j)). A minimal, inactive
  # .claude-extensions.json is used throughout: check (j) does not depend on SAPIENCE_ACTIVE, and
  # an inactive fixture keeps checks (a)/(h)/(i) a silent fail/skip rather than noise this test
  # does not assert on.
  # =====================================================================

  # Case 48: all four conditions met -> [PASS] (j).
  HOME48="$WORKDIR/case48/home"
  PROJ48="$WORKDIR/case48/repo"
  mkdir -p "$HOME48" "$PROJ48/.claude/scripts"
  echo '{}' > "$HOME48/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ48/.claude-extensions.json"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ48/.claude/scripts/postflight-sapience-notes.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ48/.claude/scripts/sapience-remember.sh"
  chmod +x "$PROJ48/.claude/scripts/postflight-sapience-notes.sh" "$PROJ48/.claude/scripts/sapience-remember.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh --task-dir "$TASK_DIR"\n' > "$PROJ48/.claude/scripts/orchestrate-cycle-postflight.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh --task-dir "$TASK_DIR"\n' > "$PROJ48/.claude/scripts/reconcile-task-status.sh"

  OUT48=$(cd "$PROJ48" && HOME="$HOME48" bash "$VERIFIER_SRC" --project "$PROJ48" 2>&1)
  if printf '%s' "$OUT48" | grep -q '\[PASS\] (j)'; then
    pass "Case 48: all four conditions met passes check (j)"
  else
    fail "Case 48: expected a [PASS] (j) line; output=$OUT48"
  fi

  # Case 49: postflight-sapience-notes.sh missing entirely -> [FAIL] (j), naming that script.
  HOME49="$WORKDIR/case49/home"
  PROJ49="$WORKDIR/case49/repo"
  mkdir -p "$HOME49" "$PROJ49/.claude/scripts"
  echo '{}' > "$HOME49/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ49/.claude-extensions.json"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ49/.claude/scripts/sapience-remember.sh"
  chmod +x "$PROJ49/.claude/scripts/sapience-remember.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ49/.claude/scripts/orchestrate-cycle-postflight.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ49/.claude/scripts/reconcile-task-status.sh"

  RC49=0
  OUT49=$(cd "$PROJ49" && HOME="$HOME49" bash "$VERIFIER_SRC" --project "$PROJ49" 2>&1) || RC49=$?
  if [ "$RC49" -eq 1 ] && printf '%s' "$OUT49" | grep -q '\[FAIL\] (j)' && printf '%s' "$OUT49" | grep -q 'postflight-sapience-notes.sh missing or not executable'; then
    pass "Case 49: a missing postflight-sapience-notes.sh fails check (j) by name, naming the script"
  else
    fail "Case 49: expected exit 1, a [FAIL] (j) line, and the missing-script reason; rc=$RC49 output=$OUT49"
  fi

  # Case 50: sapience-remember.sh present but not executable -> [FAIL] (j), naming that script.
  HOME50="$WORKDIR/case50/home"
  PROJ50="$WORKDIR/case50/repo"
  mkdir -p "$HOME50" "$PROJ50/.claude/scripts"
  echo '{}' > "$HOME50/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ50/.claude-extensions.json"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ50/.claude/scripts/postflight-sapience-notes.sh"
  chmod +x "$PROJ50/.claude/scripts/postflight-sapience-notes.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ50/.claude/scripts/sapience-remember.sh"
  # deliberately NOT chmod +x'd
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ50/.claude/scripts/orchestrate-cycle-postflight.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ50/.claude/scripts/reconcile-task-status.sh"

  RC50=0
  OUT50=$(cd "$PROJ50" && HOME="$HOME50" bash "$VERIFIER_SRC" --project "$PROJ50" 2>&1) || RC50=$?
  if [ "$RC50" -eq 1 ] && printf '%s' "$OUT50" | grep -q '\[FAIL\] (j)' && printf '%s' "$OUT50" | grep -q 'sapience-remember.sh missing or not executable'; then
    pass "Case 50: a non-executable sapience-remember.sh fails check (j) by name, naming the script"
  else
    fail "Case 50: expected exit 1, a [FAIL] (j) line, and the non-executable reason; rc=$RC50 output=$OUT50"
  fi

  # Case 51: orchestrate-cycle-postflight.sh present but carries no postflight-sapience-notes.sh
  # invocation -> [FAIL] (j), naming that call site as unwired.
  HOME51="$WORKDIR/case51/home"
  PROJ51="$WORKDIR/case51/repo"
  mkdir -p "$HOME51" "$PROJ51/.claude/scripts"
  echo '{}' > "$HOME51/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ51/.claude-extensions.json"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ51/.claude/scripts/postflight-sapience-notes.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ51/.claude/scripts/sapience-remember.sh"
  chmod +x "$PROJ51/.claude/scripts/postflight-sapience-notes.sh" "$PROJ51/.claude/scripts/sapience-remember.sh"
  printf '#!/usr/bin/env bash\necho unwired\n' > "$PROJ51/.claude/scripts/orchestrate-cycle-postflight.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ51/.claude/scripts/reconcile-task-status.sh"

  RC51=0
  OUT51=$(cd "$PROJ51" && HOME="$HOME51" bash "$VERIFIER_SRC" --project "$PROJ51" 2>&1) || RC51=$?
  if [ "$RC51" -eq 1 ] && printf '%s' "$OUT51" | grep -q '\[FAIL\] (j)' && printf '%s' "$OUT51" | grep -q 'orchestrate-cycle-postflight.sh carries no postflight-sapience-notes.sh invocation'; then
    pass "Case 51: an unwired orchestrate-cycle-postflight.sh fails check (j) by name, naming the call site"
  else
    fail "Case 51: expected exit 1, a [FAIL] (j) line, and the unwired-call-site reason; rc=$RC51 output=$OUT51"
  fi

  # Case 52: reconcile-task-status.sh present but carries no postflight-sapience-notes.sh
  # invocation -> [FAIL] (j), naming that call site as unwired.
  HOME52="$WORKDIR/case52/home"
  PROJ52="$WORKDIR/case52/repo"
  mkdir -p "$HOME52" "$PROJ52/.claude/scripts"
  echo '{}' > "$HOME52/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ52/.claude-extensions.json"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ52/.claude/scripts/postflight-sapience-notes.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$PROJ52/.claude/scripts/sapience-remember.sh"
  chmod +x "$PROJ52/.claude/scripts/postflight-sapience-notes.sh" "$PROJ52/.claude/scripts/sapience-remember.sh"
  printf '#!/usr/bin/env bash\nbash .claude/scripts/postflight-sapience-notes.sh\n' > "$PROJ52/.claude/scripts/orchestrate-cycle-postflight.sh"
  printf '#!/usr/bin/env bash\necho unwired\n' > "$PROJ52/.claude/scripts/reconcile-task-status.sh"

  RC52=0
  OUT52=$(cd "$PROJ52" && HOME="$HOME52" bash "$VERIFIER_SRC" --project "$PROJ52" 2>&1) || RC52=$?
  if [ "$RC52" -eq 1 ] && printf '%s' "$OUT52" | grep -q '\[FAIL\] (j)' && printf '%s' "$OUT52" | grep -q 'reconcile-task-status.sh carries no postflight-sapience-notes.sh invocation'; then
    pass "Case 52: an unwired reconcile-task-status.sh fails check (j) by name, naming the call site"
  else
    fail "Case 52: expected exit 1, a [FAIL] (j) line, and the unwired-call-site reason; rc=$RC52 output=$OUT52"
  fi

  # Case 53: no deployed .claude/scripts tree at all -> a skip line, never a [PASS]/[FAIL] (j).
  HOME53="$WORKDIR/case53/home"
  PROJ53="$WORKDIR/case53/repo"
  mkdir -p "$HOME53" "$PROJ53"
  echo '{}' > "$HOME53/.claude.json"
  jq -n '{"extensions": {"sapience": {"status": "inactive"}}}' > "$PROJ53/.claude-extensions.json"

  OUT53=$(cd "$PROJ53" && HOME="$HOME53" bash "$VERIFIER_SRC" --project "$PROJ53" 2>&1)
  if printf '%s' "$OUT53" | grep -q 'skipping postflight tagged-write reachability check' && ! printf '%s' "$OUT53" | grep -qE '\[(PASS|FAIL)\] \(j\)'; then
    pass "Case 53: no deployed .claude/scripts tree logs a skip and neither passes nor fails check (j)"
  else
    fail "Case 53: expected a skip line and no [PASS]/[FAIL] (j) line; output=$OUT53"
  fi
fi

# =====================================================================
# Token-removal regression cases: pin "a registered entry contains no value equal to the
# configured token", with a negative control proving the assertion discriminates.
# =====================================================================

# Case 54: a sentinel token value in config.json never appears anywhere in the written entry
# (whole-entry scan, not just the SAPIENCE_TOKEN key -- this still catches a future change that
# relocates the token to a different field).
HOME54="$WORKDIR/case54/home"
PROJ54="$WORKDIR/case54/proj"
mkdir -p "$HOME54" "$PROJ54" "$HOME54/.sapience"
SENTINEL54="sapience-test-sentinel-token-54"
echo '{}' > "$HOME54/.claude.json"
jq -n --arg t "$SENTINEL54" '{"token": $t}' > "$HOME54/.sapience/config.json"

HOME="$HOME54" bash "$WRITER_SRC" --project "$PROJ54" --scope project > /dev/null 2>&1
MATCH54=$(jq -r --arg p "$PROJ54" '.projects[$p].mcpServers.sapience | .. | strings' "$HOME54/.claude.json" 2>/dev/null | grep -F -x "$SENTINEL54" || true)

if [ -z "$MATCH54" ]; then
  pass "Case 54: a sentinel token in config.json never appears anywhere in the written entry (whole-entry scan)"
else
  fail "Case 54: sentinel token leaked into the written entry: $MATCH54"
fi

# Case 55: negative control -- a hand-built ~/.claude.json entry that DOES embed the sentinel
# token must be flagged by both sides. A positive assertion that cannot fail is not coverage.
HOME55="$WORKDIR/case55/home"
PROJ55="$WORKDIR/case55/repo"
mkdir -p "$HOME55/.sapience" "$PROJ55"
SENTINEL55="sapience-test-sentinel-token-55"
echo '{}' > "$HOME55/.sapience/config.json"
jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$PROJ55/.claude-extensions.json"
RESOLVED_PY55="$(command -v python3 2>/dev/null || echo /usr/bin/python3)"
jq -n --arg p "$PROJ55" --arg t "$SENTINEL55" --arg cmd "$RESOLVED_PY55" --arg script "$HOME55/.sapience/mcp.py" \
  '{"projects": {($p): {"mcpServers": {"sapience": {"type": "stdio", "command": $cmd, "args": [$script], "env": {"SAPIENCE_HOST": "https://app.spnc.ai", "SAPIENCE_TOKEN": $t}}}}}}' \
  > "$HOME55/.claude.json"

# 55a: the verifier (no --quiet, so the named message is visible) fails check (b) with exit 1
# and a remedy, BEFORE anything repairs the fixture.
RC55=0
OUT55=$(cd "$PROJ55" && HOME="$HOME55" bash "$VERIFIER_SRC" --project "$PROJ55" 2>&1) || RC55=$?

if [ "$RC55" -eq 1 ] && printf '%s' "$OUT55" | grep -q '\[FAIL\] (b)' && printf '%s' "$OUT55" | grep -qi 'remedy'; then
  pass "Case 55a: a token-bearing entry fails the verifier with exit 1, a [FAIL] (b) line, and a named remedy"
else
  fail "Case 55a: expected exit 1 with a [FAIL] (b) remedy line; rc=$RC55 output=$OUT55"
fi

# 55b: the writer's OWN whole-entry comparison, run against the SAME unpatched fixture, judges
# it divergent and replaces it with the token-free canonical shape.
HOME="$HOME55" bash "$WRITER_SRC" --project "$PROJ55" --scope project > /dev/null 2>&1
HAS_TOKEN55=$(jq -r --arg p "$PROJ55" '.projects[$p].mcpServers.sapience.env | has("SAPIENCE_TOKEN")' "$HOME55/.claude.json")
MATCH55=$(jq -r --arg p "$PROJ55" '.projects[$p].mcpServers.sapience | .. | strings' "$HOME55/.claude.json" 2>/dev/null | grep -F -x "$SENTINEL55" || true)

if [ "$HAS_TOKEN55" = "false" ] && [ -z "$MATCH55" ]; then
  pass "Case 55b: the writer's own whole-entry comparison judges the token-bearing entry divergent and replaces it with the token-free canonical shape"
else
  fail "Case 55b: expected the token removed and the sentinel absent; has_token=$HAS_TOKEN55 leftover_match=$MATCH55"
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

  # Case 70: invoked from inside a linked worktree, the capture coupling call keys on the
  # PARENT CHECKOUT (never the worktree): the stub receives the checkout path and no
  # worktree-keyed capture.projects[] entry appears.
  HOMEWT3="$WORKDIR/casewt3/home"
  CHECKOUTWT3="$WORKDIR/casewt3/checkout"
  mkdir -p "$HOMEWT3/.sapience" "$CHECKOUTWT3" "$HOMEWT3/.claude/scripts"
  echo '{}' > "$HOMEWT3/.claude.json"
  echo '{}' > "$HOMEWT3/.sapience/config.json"
  cp "$WRITER_SRC" "$HOMEWT3/.claude/scripts/setup-sapience-mcp.sh"
  chmod +x "$HOMEWT3/.claude/scripts/setup-sapience-mcp.sh"
  (cd "$CHECKOUTWT3" && git init -q && git -c user.email="t@t.t" -c user.name="t" commit --allow-empty -q -m init) >/dev/null 2>&1
  jq -n '{"extensions": {"sapience": {"status": "active"}}}' > "$CHECKOUTWT3/.claude-extensions.json"
  WORKTREEWT3="$WORKDIR/casewt3/wt1"
  (cd "$CHECKOUTWT3" && git worktree add -q --detach "$WORKTREEWT3") >/dev/null 2>&1
  STUB70="$(build_sapience_stub)"

  OUT70=$(cd "$WORKTREEWT3" && PATH="$STUB70:$PATH" STUB_DIR="$STUB70" HOME="$HOMEWT3" bash "$HOOK_SRC" 2>&1)
  ARGS70="$(sapience_stub_last_args "$STUB70")"
  CAPTURE_CHECKOUT70="$(jq -r --arg p "$CHECKOUTWT3" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled // "ABSENT"' "$HOMEWT3/.sapience/config.json")"
  CAPTURE_WT70="$(jq -r --arg p "$WORKTREEWT3" '(.capture.projects // []) | map(select(.path_prefix == $p)) | last.enabled // "ABSENT"' "$HOMEWT3/.sapience/config.json")"

  if [ "$ARGS70" = "projects on $CHECKOUTWT3" ] && [ "$CAPTURE_CHECKOUT70" = "true" ] && [ "$CAPTURE_WT70" = "ABSENT" ]; then
    pass "Case 70: a worktree invocation keys the capture call on the parent checkout, never the worktree"
  else
    fail "Case 70: args='$ARGS70' checkout=$CAPTURE_CHECKOUT70 (want true) worktree=$CAPTURE_WT70 (want ABSENT)"
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
  # byte-identical across every copy (the hook, the verifier, and the seven slug-derivation
  # scripts). Replaces the prose-only "keep in lockstep" comment with a mechanical check.
  LOCKSTEP_FILES=(
    "$HOOK_SRC"
    "$VERIFIER_SRC"
    "$SCRIPT_DIR/../sapience-retrieve.sh"
    "$SCRIPT_DIR/../sapience-remember.sh"
    "$SCRIPT_DIR/../verify-sapience-context-scoping.sh"
    "$SCRIPT_DIR/../sapience-project-bind.sh"
    "$SCRIPT_DIR/../sapience-vault-read.sh"
    "$SCRIPT_DIR/../sapience-publish.sh"
    "$SCRIPT_DIR/../sapience-tag-pending.sh"
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
    pass "Case 30: the marker-delimited worktree-checkout-resolution block is byte-identical across all nine copies"
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
