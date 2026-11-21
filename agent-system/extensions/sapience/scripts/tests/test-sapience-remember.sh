#!/usr/bin/env bash
# test-sapience-remember.sh - The first regression suite for sapience-remember.sh: the
# repo-tagged, explicit Sapience vault write script, covering the Phase 2 project-key
# resolution/degrade rule it adds.
#
# Modelled on test-sapience-publish.sh's own harness (build_scratch, write_binding,
# build_curl_stub, common_test_pass/_fail), scoped down to sapience-remember.sh's simpler
# --subject/--value CLI and its one GET call (/v1/people/projects) -- it never reaches a
# POST, so no POST/ingest-kos stub branch is needed here.
#
# Cases:
#   (1) A fixture .sapience/project.json binding plus a stubbed GET /v1/people/projects list
#       yields a --dry-run body containing "project": "<key>".
#   (2) No binding at all yields a --dry-run body with no `project` key, byte-identical in
#       shape to pre-tagging behavior.
#   (3) No `project_cid` key appears anywhere in any case's printed body.
#   (4) --project-key wins over the binding and makes no GET /v1/people/projects call.
#   (5) Binding present but the project list has no matching entry: still writes (exits 0),
#       untagged, with a stderr warning -- never a refusal, never a dropped note.
#   (6) Policy invariant (Ruling 1): settings-fragment.json's permissions.allow[] holds
#       exactly the seven mcp__sapience__* read grants and none of sapience_remember/
#       sapience_wrapup/sapience_handoff/sapience_adddoc.
#   (7) Policy invariant (Ruling 3): sapience-project-bind.sh contains zero references to
#       ~/.sapience/config.json or capture.projects (measured baseline today: zero).
#
# Cases 6-7 live in this suite rather than one of their own, per the governing plan: both are
# cheap, static, whole-extension policy assertions with no script-under-test behavior of their
# own to exercise, and this suite is the one new test entry point this phase's own plan item
# adds.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution.
#
# Bootstrap note: this suite lives under a DIFFERENT extension (sapience) than the shared
# lib/common.sh and deploy-root-guard.sh it needs (core). Post-deploy, every extension's
# scripts/tests/ and scripts/lib/ are flattened into one shared .claude/scripts/ tree;
# pre-deploy, in a source-store-only checkout, it falls back to core's own copies directly.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-remember.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-remember.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-remember.sh" \
  "$SCRIPT_DIR/../sapience-remember.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

GUARD_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/deploy-root-guard.sh"
GUARD_CANDIDATE_SOURCE="$SCRIPT_DIR/../../../core/scripts/deploy-root-guard.sh"
if [ -f "$GUARD_CANDIDATE_DEPLOYED" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_DEPLOYED"
elif [ -f "$GUARD_CANDIDATE_SOURCE" ]; then
  GUARD_SCRIPT="$GUARD_CANDIDATE_SOURCE"
else
  echo "ERROR: deploy-root-guard.sh not found at $GUARD_CANDIDATE_DEPLOYED or $GUARD_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$GUARD_SCRIPT"
common_test_declare_subject "$COMMON_SH"

# --- Case 6/7 fixed-content subjects: not a deploy/source "script under test" pair. The
# settings fragment has no standalone deployed copy at all -- it is merge-targeted into
# .claude/settings.local.json -- so it is ALWAYS read from the source store, resolved via
# common_test_ext_root (works whether this suite itself is running from the source tree or a
# deployed .claude/scripts/tests/ copy). sapience-project-bind.sh's deployed copy is checked
# deploy-tree-first exactly like the script under test above. ---
EXT_ROOT="$(common_test_ext_root "$REPO_ROOT")" || {
  echo "ERROR: could not resolve the extensions root from REPO_ROOT=$REPO_ROOT" >&2
  exit 2
}
SETTINGS_FRAGMENT="$EXT_ROOT/sapience/settings-fragment.json"
if [ ! -f "$SETTINGS_FRAGMENT" ]; then
  echo "ERROR: settings-fragment.json not found at $SETTINGS_FRAGMENT" >&2
  exit 2
fi
common_test_declare_subject "$SETTINGS_FRAGMENT"

PROJECT_BIND_SCRIPT="$(common_test_resolve_subject "sapience-project-bind.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-project-bind.sh" \
  "$SCRIPT_DIR/../sapience-project-bind.sh")" || exit 2
common_test_declare_subject "$PROJECT_BIND_SCRIPT"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked indirectly via `trap cleanup EXIT`
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- an isolated <scratch>/.claude/scripts/{sapience-remember.sh,
#     deploy-root-guard.sh,lib/common.sh} tree plus a scratch git repo. Echoes the scratch
#     repo root. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-remember.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-remember.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

# write_binding <scratch> <cid> -- writes a minimal .sapience/project.json binding at the
# scratch repo's toplevel, matching repo_link.py's three-key link_text shape closely enough
# for this suite's own reader (sapience-remember.sh only reads `.project`).
write_binding() {
  local scratch="$1" cid="$2"
  mkdir -p "$scratch/.sapience"
  jq -n --arg project "$cid" --arg name "Test Project" --arg repo "$(basename "$scratch")" \
    '{project: $project, name: $name, repo: $repo}' > "$scratch/.sapience/project.json"
}

BIN_REL=".claude/scripts/sapience-remember.sh"

# run_remember <scratch> [args...] -- no curl stub installed; a network call reaching the real
# system curl would fail/hang, so a case using this helper is asserting "no network call" as a
# structural fact, not an assumption.
run_remember() {
  local scratch="$1"; shift
  env HOME="$TOP_WORKDIR" SAPIENCE_TOKEN="test-token-fixture" bash "$scratch/$BIN_REL" "$@"
}

# build_curl_stub -- installs a curl stub dispatching on URL substring, driven by
# STUB_PROJECTS_BODY/STUB_PROJECTS_CODE (GET /v1/people/projects, the only call this script
# ever makes under --dry-run -- it never reaches a POST under --dry-run). Tracks, via a file
# under the given tracking dir, which branch was hit. Echoes the stub directory (to prepend to
# PATH).
build_curl_stub() {
  local stub_dir="$1" hit_dir="$2"
  mkdir -p "$stub_dir" "$hit_dir"
  cat > "$stub_dir/curl" <<STUB
#!/usr/bin/env bash
url="\${!#}"
case "\$url" in
  *v1/people/projects*)
    echo "projects" >> "$hit_dir/branch_hits"
    printf '%s' "\${STUB_PROJECTS_BODY:-{\\}}"
    ;;
  *)
    echo "test stub: unrecognized URL: \$url" >&2
    exit 7
    ;;
esac
exit 0
STUB
  chmod +x "$stub_dir/curl"
  echo "$stub_dir"
}

# run_remember_stubbed <scratch> <stub_dir> [args...]
run_remember_stubbed() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" SAPIENCE_TOKEN="test-token-fixture" HOME="$TOP_WORKDIR" \
    bash "$scratch/$BIN_REL" "$@"
}

# Fixture values (the dispatch's own live reference values, used here only as realistic test
# fixtures -- never hardcoded into the script itself): cid=mEdYrFW_qClSGDfx, key=oliver-ben.
PROJECTS_FIXTURE='{"ok":true,"projects":[{"cid":"mEdYrFW_qClSGDfx","key":"oliver-ben","name":"Oliver+Ben"}]}'

# =====================================================================================
# Case 1: fixture binding + stubbed project list -- --dry-run body contains "project": "<key>".
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$PROJECTS_FIXTURE" \
    run_remember_stubbed "$scratch" "$stub_dir" --subject X --value Y --dry-run 2>/dev/null)"
  rc=$?
  project_shown="$(echo "$out" | jq -r '.kos[0].project // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$project_shown" = "oliver-ben" ]; then
    common_test_pass "(1) binding + stubbed project list: --dry-run body carries project=\"oliver-ben\""
  else
    common_test_fail "(1) binding + stubbed project list: --dry-run body carries project=\"oliver-ben\"" "rc=$rc project_shown=$project_shown out=$out"
  fi
  CASE1_OUT="$out"
}

# =====================================================================================
# Case 2: no binding at all -- --dry-run body has no `project` key (byte-identical in shape to
# pre-tagging behavior). No stub installed: this case asserts no network call is made.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_remember "$scratch" --subject X --value Y --dry-run 2>/dev/null)"
  rc=$?
  has_project="$(echo "$out" | jq -r 'has("project")' 2>/dev/null)"
  has_project_in_ko="$(echo "$out" | jq -r '.kos[0] | has("project")' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$has_project_in_ko" = "false" ]; then
    common_test_pass "(2) no binding: --dry-run body has no \`project\` key"
  else
    common_test_fail "(2) no binding: --dry-run body has no \`project\` key" "rc=$rc has_project=$has_project has_project_in_ko=$has_project_in_ko out=$out"
  fi
  CASE2_OUT="$out"
}

# =====================================================================================
# Case 3: no `project_cid` key appears anywhere in any case's printed body (checked across
# Case 1's and Case 2's captured output plus a fresh --project-key override run).
# =====================================================================================
{
  scratch="$(build_scratch)"
  out3="$(run_remember "$scratch" --subject X --value Y --project-key "override-key" --dry-run 2>/dev/null)"
  combined="${CASE1_OUT}
${CASE2_OUT}
${out3}"
  if ! echo "$combined" | grep -q "project_cid"; then
    common_test_pass "(3) no project_cid key appears anywhere in any printed body"
  else
    common_test_fail "(3) no project_cid key appears anywhere in any printed body" "$combined"
  fi
}

# =====================================================================================
# Case 4: --project-key wins over the binding and makes no GET /v1/people/projects call.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$PROJECTS_FIXTURE" \
    run_remember_stubbed "$scratch" "$stub_dir" --subject X --value Y --project-key "override-key" --dry-run 2>/dev/null)"
  rc=$?
  project_shown="$(echo "$out" | jq -r '.kos[0].project // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$project_shown" = "override-key" ]; then
    common_test_pass "(4) --project-key override: --dry-run body carries the override, not the binding's resolved key"
  else
    common_test_fail "(4) --project-key override: --dry-run body carries the override, not the binding's resolved key" "rc=$rc project_shown=$project_shown out=$out"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "projects" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(4) --project-key override: GET /v1/people/projects was never called"
  else
    common_test_fail "(4) --project-key override: GET /v1/people/projects was never called" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 5: binding present but the project list has no matching entry -- still writes (exits
# 0), untagged, with a stderr warning.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "some-other-cid-not-in-the-list"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  err_file="$(mktemp -p "$TOP_WORKDIR")"
  out="$(STUB_PROJECTS_BODY="$PROJECTS_FIXTURE" \
    run_remember_stubbed "$scratch" "$stub_dir" --subject X --value Y --dry-run 2>"$err_file")"
  rc=$?
  has_project_in_ko="$(echo "$out" | jq -r '.kos[0] | has("project")' 2>/dev/null)"
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(5) no matching project-list entry: exits 0 (never a refusal)"
  else
    common_test_fail "(5) no matching project-list entry: exits 0 (never a refusal)" "got rc=$rc out=$out"
  fi
  if [ "$has_project_in_ko" = "false" ]; then
    common_test_pass "(5) no matching project-list entry: writes untagged (no \`project\` key)"
  else
    common_test_fail "(5) no matching project-list entry: writes untagged (no \`project\` key)" "out=$out"
  fi
  if grep -qi "warning" "$err_file" 2>/dev/null; then
    common_test_pass "(5) no matching project-list entry: a warning is printed to stderr"
  else
    common_test_fail "(5) no matching project-list entry: a warning is printed to stderr" "stderr=$(cat "$err_file" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 6 (Ruling 1 policy invariant): settings-fragment.json's permissions.allow[] holds
# exactly the seven mcp__sapience__* read grants and none of the four write tools.
# =====================================================================================
{
  EXPECTED_READ_GRANTS='mcp__sapience__sapience
mcp__sapience__sapience_search
mcp__sapience__sapience_briefing
mcp__sapience__sapience_context
mcp__sapience__sapience_ask
mcp__sapience__sapience_outstanding
mcp__sapience__sapience_papers'

  actual_allow="$(jq -r '.permissions.allow[]' "$SETTINGS_FRAGMENT" 2>/dev/null | sort)"
  expected_sorted="$(echo "$EXPECTED_READ_GRANTS" | sort)"
  if [ "$actual_allow" = "$expected_sorted" ]; then
    common_test_pass "(6) settings-fragment.json grants exactly the seven read-shaped mcp__sapience__* tools"
  else
    common_test_fail "(6) settings-fragment.json grants exactly the seven read-shaped mcp__sapience__* tools" "actual=$actual_allow"
  fi

  write_tool_count="$(jq -r '.permissions.allow[]' "$SETTINGS_FRAGMENT" 2>/dev/null | \
    grep -c -E 'mcp__sapience__(sapience_remember|sapience_wrapup|sapience_handoff|sapience_adddoc)$')"
  if [ "$write_tool_count" = "0" ]; then
    common_test_pass "(6) settings-fragment.json grants none of the four MCP write tools"
  else
    common_test_fail "(6) settings-fragment.json grants none of the four MCP write tools" "write_tool_count=$write_tool_count"
  fi
}

# =====================================================================================
# Case 7 (Ruling 3 policy invariant): sapience-project-bind.sh contains zero references to
# ~/.sapience/config.json or capture.projects.
# =====================================================================================
{
  bind_hits="$(grep -c -E 'config\.json|capture\.projects' "$PROJECT_BIND_SCRIPT" 2>/dev/null)" || bind_hits=0
  if [ "$bind_hits" = "0" ]; then
    common_test_pass "(7) sapience-project-bind.sh has zero references to config.json/capture.projects"
  else
    common_test_fail "(7) sapience-project-bind.sh has zero references to config.json/capture.projects" "bind_hits=$bind_hits"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
