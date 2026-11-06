#!/usr/bin/env bash
# test-install-uninstall-extension.sh - Characterization suite for install-extension.sh /
# uninstall-extension.sh, written BEFORE the pair's duplicate-block extraction (the
# install/uninstall shared-helper consolidation) so the refactor has a regression test to run
# before and after.
#
# Neither script was fixture-tested previously (has_test: false per script-inventory.sh).
# Both scripts require a deployed-tree shape to pass deploy-root-guard.sh's default structural
# check (guard_dir's parent literally named ".claude"), so this suite builds a FAKE deploy tree
# under its own mktemp workdir -- "$WORKDIR/.claude/scripts/{install,uninstall}-extension.sh" --
# copying the SOURCE-STORE copies under test (this task's edit target) into that shape, rather
# than opting into DEPLOY_ROOT_GUARD_SELF_CORRECT. This mirrors the real deploy layout exactly,
# so PROJECT_ROOT/CLAUDE_DIR resolve the same way a real deployed invocation would.
#
# validate-index.sh is deliberately NOT copied into the fake tree: install-extension.sh's own
# validate_index() degrades to "Validation script not found, skipping validation" when absent,
# which keeps this suite independent of that script's own behavior.
#
# Coverage: fresh install (symlinks for a command, a skill directory, an agent file, plus merged
# index-entries.json), idempotent re-install (symlink already correct), a pre-existing
# conflicting file left untouched, uninstall's ownership check (a foreign symlink is left
# alone), full uninstall (symlinks + index entries removed), and a round-trip tree-identity
# check (the fake deploy tree's state after install+uninstall matches its state before install,
# modulo index.json's own `generated` timestamp field).
#
# Structural model: common.sh harness, SCRIPT_UNDER_TEST resolved source-store-first (this is
# the file this task edits), mktemp -d workdir, set -uo pipefail.
#
# Exit codes: 0 all cases PASS; 1 at least one case FAILED; 2 environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

INSTALL_SCRIPT="$(common_test_resolve_subject "install-extension.sh" "source-store" \
  "$SCRIPT_DIR/../install-extension.sh" \
  "$REPO_ROOT/.claude/scripts/install-extension.sh")" || exit 2
common_test_declare_subject "$INSTALL_SCRIPT"
UNINSTALL_SCRIPT="$(common_test_resolve_subject "uninstall-extension.sh" "source-store" \
  "$SCRIPT_DIR/../uninstall-extension.sh" \
  "$REPO_ROOT/.claude/scripts/uninstall-extension.sh")" || exit 2
common_test_declare_subject "$UNINSTALL_SCRIPT"
COMMON_LIB="$(common_test_resolve_subject "lib/common.sh" "source-store" \
  "$SCRIPT_DIR/../lib/common.sh" \
  "$REPO_ROOT/.claude/scripts/lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_LIB"
GUARD_SCRIPT="$(common_test_resolve_subject "deploy-root-guard.sh" "source-store" \
  "$SCRIPT_DIR/../deploy-root-guard.sh" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SCRIPT"
# Optional: the shared helper lib this phase extracts. Not present before the refactor lands;
# copied into the fake tree when it exists so a post-refactor run resolves it correctly.
EXTLIB_CANDIDATE="$SCRIPT_DIR/../lib/extension-install-lib.sh"

PASSED=0
FAILED=0
common_test_workdir_init

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Build the fake deploy tree.
# ─────────────────────────────────────────────────────────────────────────────────────────────
DEPLOY_SCRIPTS="$WORKDIR/.claude/scripts"
mkdir -p "$DEPLOY_SCRIPTS/lib" "$WORKDIR/.claude/commands" "$WORKDIR/.claude/skills" \
  "$WORKDIR/.claude/agents" "$WORKDIR/.claude/context" "$WORKDIR/specs/tmp"
# Both scripts write their index-merge scratch file to the CWD-relative "specs/tmp/" (an
# existing precondition of real invocations, which always run from the repo root where
# specs/tmp/ already exists) -- pre-created here to match that precondition, and run_install/
# run_uninstall below `cd "$WORKDIR"` first so the relative path resolves into it.
cp "$INSTALL_SCRIPT" "$DEPLOY_SCRIPTS/install-extension.sh"
cp "$UNINSTALL_SCRIPT" "$DEPLOY_SCRIPTS/uninstall-extension.sh"
cp "$COMMON_LIB" "$DEPLOY_SCRIPTS/lib/common.sh"
cp "$GUARD_SCRIPT" "$DEPLOY_SCRIPTS/deploy-root-guard.sh"
if [ -f "$EXTLIB_CANDIDATE" ]; then
  cp "$EXTLIB_CANDIDATE" "$DEPLOY_SCRIPTS/lib/extension-install-lib.sh"
fi
chmod +x "$DEPLOY_SCRIPTS/install-extension.sh" "$DEPLOY_SCRIPTS/uninstall-extension.sh"

cat > "$WORKDIR/.claude/context/index.json" <<'EOF'
{
  "version": 1,
  "generated": "2026-01-01T00:00:00Z",
  "entries": [
    {"path": "pre-existing.md", "domain": "project", "subdomain": "core", "topics": [], "keywords": [], "summary": "pre-existing", "line_count": 10, "load_when": {"agents": [], "task_types": []}}
  ]
}
EOF

# A pre-existing, non-symlink command file and a foreign symlink (owned by a different
# extension name) in the agents dir, to exercise the ownership/conflict-skip branches.
echo "not a symlink" > "$WORKDIR/.claude/commands/conflict.md"
ln -s "../../agent-system/extensions/otherext/agents/foreign.md" "$WORKDIR/.claude/agents/foreign.md"

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Fake extension fixture.
# ─────────────────────────────────────────────────────────────────────────────────────────────
EXT_DIR="$WORKDIR/fixture-ext"
mkdir -p "$EXT_DIR/commands" "$EXT_DIR/skills/skill-foo" "$EXT_DIR/agents"
cat > "$EXT_DIR/manifest.json" <<'EOF'
{"name": "fooext"}
EOF
echo "# foo command" > "$EXT_DIR/commands/foo.md"
echo "# foo skill" > "$EXT_DIR/skills/skill-foo/SKILL.md"
echo "# foo agent" > "$EXT_DIR/agents/foo-agent.md"
cat > "$EXT_DIR/index-entries.json" <<'EOF'
{
  "entries": [
    {"path": "fooext-doc.md", "category": "fooext", "tags": ["foo"], "description": "fooext doc", "line_count": 42, "load_when": {"agents": ["general-implementation-agent"], "task_types": ["general"]}}
  ]
}
EOF

run_install() {
  ( cd "$WORKDIR" && bash "$DEPLOY_SCRIPTS/install-extension.sh" "$EXT_DIR" )
}
run_uninstall() {
  ( cd "$WORKDIR" && bash "$DEPLOY_SCRIPTS/uninstall-extension.sh" "$EXT_DIR" )
}
snapshot_tree() {
  ( cd "$WORKDIR/.claude" && find . \( -type f -o -type l -o -type d \) -printf '%y|%P|%l\n' | sort )
  jq -S 'del(.generated)' "$WORKDIR/.claude/context/index.json"
}

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Case 1: fresh install.
# ─────────────────────────────────────────────────────────────────────────────────────────────
INSTALL_OUT_1="$(run_install 2>&1)"
INSTALL_RC_1=$?

if [ "$INSTALL_RC_1" -eq 0 ]; then
  common_test_pass "(1) fresh install: exit 0"
else
  common_test_fail "(1) fresh install: expected exit 0, got $INSTALL_RC_1" "$INSTALL_OUT_1"
fi

if [[ "$INSTALL_OUT_1" == *"Installing extension: fooext"* && "$INSTALL_OUT_1" == *"installed successfully"* ]]; then
  common_test_pass "(1) fresh install: start/success log lines present"
else
  common_test_fail "(1) fresh install: missing start/success log lines" "$INSTALL_OUT_1"
fi

if [ -L "$WORKDIR/.claude/commands/foo.md" ] && \
   [ "$(readlink "$WORKDIR/.claude/commands/foo.md")" = "../../agent-system/extensions/fooext/commands/foo.md" ]; then
  common_test_pass "(1) fresh install: command symlink created with correct relative target"
else
  common_test_fail "(1) fresh install: command symlink missing or wrong target"
fi

if [ -L "$WORKDIR/.claude/skills/skill-foo" ] && \
   [ "$(readlink "$WORKDIR/.claude/skills/skill-foo")" = "../../agent-system/extensions/fooext/skills/skill-foo" ]; then
  common_test_pass "(1) fresh install: skill symlink created with correct relative target"
else
  common_test_fail "(1) fresh install: skill symlink missing or wrong target"
fi

if [ -L "$WORKDIR/.claude/agents/foo-agent.md" ] && \
   [ "$(readlink "$WORKDIR/.claude/agents/foo-agent.md")" = "../../agent-system/extensions/fooext/agents/foo-agent.md" ]; then
  common_test_pass "(1) fresh install: agent symlink created with correct relative target"
else
  common_test_fail "(1) fresh install: agent symlink missing or wrong target"
fi

MERGED_ENTRY="$(jq -r '.entries[] | select(.path == "fooext-doc.md") | .path' "$WORKDIR/.claude/context/index.json" 2>/dev/null)"
if [ "$MERGED_ENTRY" = "fooext-doc.md" ]; then
  common_test_pass "(1) fresh install: index-entries.json merged into context/index.json"
else
  common_test_fail "(1) fresh install: merged entry not found in index.json"
fi

PRE_EXISTING_STILL_PRESENT="$(jq -r '.entries[] | select(.path == "pre-existing.md") | .path' "$WORKDIR/.claude/context/index.json" 2>/dev/null)"
if [ "$PRE_EXISTING_STILL_PRESENT" = "pre-existing.md" ]; then
  common_test_pass "(1) fresh install: pre-existing index entry preserved"
else
  common_test_fail "(1) fresh install: pre-existing index entry lost"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Case 2: idempotent re-install (symlink already correct) -> info message, no error.
# ─────────────────────────────────────────────────────────────────────────────────────────────
INSTALL_OUT_2="$(run_install 2>&1)"
INSTALL_RC_2=$?

if [ "$INSTALL_RC_2" -eq 0 ] && [[ "$INSTALL_OUT_2" == *"Command symlink already exists: foo.md"* ]]; then
  common_test_pass "(2) idempotent re-install: already-exists info message, exit 0"
else
  common_test_fail "(2) idempotent re-install: expected already-exists message and exit 0" "$INSTALL_OUT_2 (rc=$INSTALL_RC_2)"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Case 3: pre-existing conflicting (non-symlink) file is left untouched by install.
# ─────────────────────────────────────────────────────────────────────────────────────────────
if [ "$(cat "$WORKDIR/.claude/commands/conflict.md")" = "not a symlink" ] && [ ! -L "$WORKDIR/.claude/commands/conflict.md" ]; then
  common_test_pass "(3) conflicting pre-existing file: left untouched by install"
else
  common_test_fail "(3) conflicting pre-existing file: was modified"
fi

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Case 4: uninstall's ownership check leaves a foreign-owned symlink alone.
# ─────────────────────────────────────────────────────────────────────────────────────────────
UNINSTALL_OUT_1="$(run_uninstall 2>&1)"
UNINSTALL_RC_1=$?

if [ "$UNINSTALL_RC_1" -eq 0 ]; then
  common_test_pass "(4) uninstall: exit 0"
else
  common_test_fail "(4) uninstall: expected exit 0, got $UNINSTALL_RC_1" "$UNINSTALL_OUT_1"
fi

if [ -L "$WORKDIR/.claude/agents/foreign.md" ] && \
   [ "$(readlink "$WORKDIR/.claude/agents/foreign.md")" = "../../agent-system/extensions/otherext/agents/foreign.md" ]; then
  common_test_pass "(4) uninstall: foreign-owned symlink left alone"
else
  common_test_fail "(4) uninstall: foreign-owned symlink was removed or altered"
fi

if [ ! -e "$WORKDIR/.claude/commands/foo.md" ]; then
  common_test_pass "(4) uninstall: this extension's command symlink removed"
else
  common_test_fail "(4) uninstall: command symlink still present"
fi

if [ ! -e "$WORKDIR/.claude/skills/skill-foo" ]; then
  common_test_pass "(4) uninstall: this extension's skill symlink removed"
else
  common_test_fail "(4) uninstall: skill symlink still present"
fi

if [ ! -e "$WORKDIR/.claude/agents/foo-agent.md" ]; then
  common_test_pass "(4) uninstall: this extension's agent symlink removed"
else
  common_test_fail "(4) uninstall: agent symlink still present"
fi

REMOVED_ENTRY="$(jq -r '.entries[] | select(.path == "fooext-doc.md") | .path' "$WORKDIR/.claude/context/index.json" 2>/dev/null)"
if [ -z "$REMOVED_ENTRY" ]; then
  common_test_pass "(4) uninstall: merged index entry removed"
else
  common_test_fail "(4) uninstall: merged index entry still present"
fi

if [ "$(jq -r '.entries[] | select(.path == "pre-existing.md") | .path' "$WORKDIR/.claude/context/index.json" 2>/dev/null)" = "pre-existing.md" ]; then
  common_test_pass "(4) uninstall: pre-existing index entry preserved"
else
  common_test_fail "(4) uninstall: pre-existing index entry lost"
fi

# Remove the conflict/foreign fixtures (not part of install/uninstall's own round-trip) before
# the tree-identity baseline below, which must compare against a state install/uninstall alone
# are responsible for restoring.
rm -f "$WORKDIR/.claude/commands/conflict.md" "$WORKDIR/.claude/agents/foreign.md"
SNAPSHOT_BASELINE="$(snapshot_tree)"

# ─────────────────────────────────────────────────────────────────────────────────────────────
# Case 5: round-trip tree identity. Re-add the conflict/foreign fixtures, run a full
# install+uninstall cycle, strip those two non-owned fixtures again, and compare to the
# baseline captured right after the first strip above.
# ─────────────────────────────────────────────────────────────────────────────────────────────
echo "not a symlink" > "$WORKDIR/.claude/commands/conflict.md"
ln -s "../../agent-system/extensions/otherext/agents/foreign.md" "$WORKDIR/.claude/agents/foreign.md"

run_install >/dev/null 2>&1
run_uninstall >/dev/null 2>&1

rm -f "$WORKDIR/.claude/commands/conflict.md" "$WORKDIR/.claude/agents/foreign.md"
SNAPSHOT_AFTER="$(snapshot_tree)"

if [ "$SNAPSHOT_BASELINE" = "$SNAPSHOT_AFTER" ]; then
  common_test_pass "(5) round-trip: install then uninstall returns the deploy tree to its prior state"
else
  common_test_fail "(5) round-trip: tree state diverged" "$(diff <(echo "$SNAPSHOT_BASELINE") <(echo "$SNAPSHOT_AFTER"))"
fi

echo ""
echo "Passed: $PASSED"
echo "Failed: $FAILED"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
