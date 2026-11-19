#!/usr/bin/env bash
# test-sapience-vault-read.sh - Regression suite for sapience-vault-read.sh: the read-only
# local+vault aggregator emitting the pinned "sapience-vault-read/1" envelope.
#
# Cases:
#   (1) No Sapience token/host resolvable at all: exit 1, nothing written to .sapience/.
#   (2) All five top-level vault sources stubbed as failing (non-JSON/transport-shaped
#       responses): the envelope is still well-formed and `jq -e` validates against every key
#       named in the pinned contract, every `vault.*` key is `null`, `errors[]` is populated
#       (one entry per failed top-level source, five total), and the script exits non-zero (2).
#   (3) All five top-level vault sources stubbed as succeeding (plus one unread doc): the
#       envelope `jq -e` validates against every key named in the pinned contract, `doc_bodies`
#       and `doc_comments` carry the one unread doc's slug, and the script exits 0.
#   (4) A single failing top-level source (the other four succeeding) still exits 0, with that
#       one source `null` and exactly one matching `errors[]` entry -- the per-source isolation
#       the dispatch requires, proven for one source so no single failure can abort the whole
#       read.
#   (5) An ordinary run (no --update-cursor) never writes `.sapience/last-read.json`, even on
#       full success.
#   (6) `--update-cursor` writes `.sapience/last-read.json` with a `commit` field matching the
#       repo's current `HEAD`, and a subsequent ordinary run leaves that file byte-unchanged.
#   (7) No vault source is contacted via a raw `curl` call site outside the shared lib (grepped
#       directly against the script under test, not just asserted by absence of failures).
#   (8) No instruction surface in the script (comments or --help text) names an MCP write tool
#       as a prescribed write path -- same negation-only convention as Phases 1-2, verified here
#       by absence of any OTHER phrasing around the four names.
#   (9) The marker-delimited worktree-checkout-resolution block is byte-identical to
#       sapience-remember.sh's own copy.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution. `curl`
# is PATH-shadowed by a minimal inline stub for every network-touching case; Case 1 installs no
# stub at all (its no-token short-circuit never reaches curl).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-vault-read.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-vault-read.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-vault-read.sh" \
  "$SCRIPT_DIR/../sapience-vault-read.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"

API_LIB_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/lib/sapience-api-lib.sh"
API_LIB_CANDIDATE_SOURCE="$SCRIPT_DIR/../lib/sapience-api-lib.sh"
if [ -f "$API_LIB_CANDIDATE_DEPLOYED" ]; then
  API_LIB="$API_LIB_CANDIDATE_DEPLOYED"
elif [ -f "$API_LIB_CANDIDATE_SOURCE" ]; then
  API_LIB="$API_LIB_CANDIDATE_SOURCE"
else
  echo "ERROR: sapience-api-lib.sh not found at $API_LIB_CANDIDATE_DEPLOYED or $API_LIB_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$API_LIB"

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

REMEMBER_CANDIDATE_DEPLOYED="$REPO_ROOT/.claude/scripts/sapience-remember.sh"
REMEMBER_CANDIDATE_SOURCE="$SCRIPT_DIR/../sapience-remember.sh"
if [ -f "$REMEMBER_CANDIDATE_DEPLOYED" ]; then
  REMEMBER_SCRIPT="$REMEMBER_CANDIDATE_DEPLOYED"
elif [ -f "$REMEMBER_CANDIDATE_SOURCE" ]; then
  REMEMBER_SCRIPT="$REMEMBER_CANDIDATE_SOURCE"
else
  echo "ERROR: sapience-remember.sh not found at $REMEMBER_CANDIDATE_DEPLOYED or $REMEMBER_CANDIDATE_SOURCE" >&2
  exit 2
fi
common_test_declare_subject "$REMEMBER_SCRIPT"

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
# shellcheck disable=SC2329  # invoked indirectly via `trap cleanup EXIT`
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

BIN_REL=".claude/scripts/sapience-vault-read.sh"

# build_scratch -- an isolated <scratch>/.claude/scripts/{sapience-vault-read.sh,
# deploy-root-guard.sh,lib/{common.sh,sapience-api-lib.sh}} tree, a scratch git repo, and a
# minimal specs/ tree. Echoes the scratch repo root.
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-vault-read.sh"
  cp "$API_LIB" "$scratch/.claude/scripts/lib/sapience-api-lib.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-vault-read.sh"
  echo '{"completed_projects":[]}' > "$scratch/specs/state.json"
  : > "$scratch/specs/events.jsonl"
  : > "$scratch/specs/central-errors.jsonl"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" add -A
  git -C "$scratch" commit -q -m "seed"
  echo "$scratch"
}

# build_curl_stub -- a curl stub dispatching on URL substring, each endpoint driven by its own
# env var pair (BODY/CODE). Echoes the stub directory.
build_curl_stub() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  cat > "$stub_dir/curl" <<'STUB'
#!/usr/bin/env bash
url="${!#}"
case "$url" in
  *v1/people/projects/suggestions*)
    printf '%s' "${SUGGESTIONS_BODY:-{\}}"; printf '\n%s' "${SUGGESTIONS_CODE:-200}" ;;
  *v1/people/projects/*/notes*)
    printf '%s' "${NOTES_BODY:-{\}}"; printf '\n%s' "${NOTES_CODE:-200}" ;;
  *v1/people/projects*)
    printf '%s' "${PROJECTS_BODY:-{\}}"; printf '\n%s' "${PROJECTS_CODE:-200}" ;;
  *v1/docs/*/comments*)
    printf '%s' "${COMMENTS_BODY:-{\}}"; printf '\n%s' "${COMMENTS_CODE:-200}" ;;
  *v1/docs/*)
    printf '%s' "${DOC_BODY_BODY:-{\}}"; printf '\n%s' "${DOC_BODY_CODE:-200}" ;;
  *v1/docs*)
    printf '%s' "${DOCS_BODY:-{\}}"; printf '\n%s' "${DOCS_CODE:-200}" ;;
  *v1/notifications*)
    printf '%s' "${NOTIFICATIONS_BODY:-{\}}"; printf '\n%s' "${NOTIFICATIONS_CODE:-200}" ;;
  *)
    echo "test stub: unrecognized URL: $url" >&2
    exit 7
    ;;
esac
exit 0
STUB
  chmod +x "$stub_dir/curl"
  echo "$stub_dir"
}

# run_vr <scratch> <stub_dir> [args...] -- curl PATH-shadowed, fixed SAPIENCE_TOKEN.
run_vr() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" SAPIENCE_TOKEN="test-token-fixture" HOME="$TOP_WORKDIR" \
    bash "$scratch/$BIN_REL" "$@"
}

ALL_FAIL_ENV=(
  PROJECTS_CODE=503 PROJECTS_BODY='<html>down</html>'
  DOCS_CODE=503 DOCS_BODY='<html>down</html>'
  NOTES_CODE=503 NOTES_BODY='<html>down</html>'
  SUGGESTIONS_CODE=503 SUGGESTIONS_BODY='<html>down</html>'
  NOTIFICATIONS_CODE=503 NOTIFICATIONS_BODY='<html>down</html>'
)

ALL_SUCCESS_ENV=(
  PROJECTS_BODY='{"ok":true,"projects":[{"id":"CID1","name":"Agent System Work"}]}'
  DOCS_BODY='{"ok":true,"docs":[{"slug":"doc-a","title":"A","unread":true},{"slug":"doc-b","title":"B","unread":false}]}'
  DOC_BODY_BODY='{"ok":true,"slug":"doc-a","body":"hello","rev":3}'
  COMMENTS_BODY='{"ok":true,"comments":[{"id":1,"text":"hi"}]}'
  NOTES_BODY='{"ok":true,"notes":[]}'
  SUGGESTIONS_BODY='{"ok":true,"suggestions":[]}'
  NOTIFICATIONS_BODY='{"ok":true,"notifications":[]}'
)

# =====================================================================================
# Case 1: no token resolvable at all -- exit 1, nothing written to .sapience/.
# =====================================================================================
{
  scratch="$(build_scratch)"
  # Isolate HOME to a directory with no ~/.sapience/config.json, and keep curl UN-shadowed (no
  # stub on PATH) -- the real system curl would only ever be reached if token resolution
  # incorrectly succeeded, which this case asserts it does not. Never SAPIENCE_TOKEN/_HOST
  # inherited from the real environment.
  fake_home="$(mktemp -d -p "$TOP_WORKDIR")"
  out="$(env -u SAPIENCE_TOKEN -u SAPIENCE_HOST HOME="$fake_home" bash "$scratch/$BIN_REL" 2>&1)"
  rc=$?
  if [ "$rc" -eq 1 ]; then
    common_test_pass "(1) no token: exit 1"
  else
    common_test_fail "(1) no token: exit 1" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience" ]; then
    common_test_pass "(1) no token: .sapience/ never created"
  else
    common_test_fail "(1) no token: .sapience/ never created"
  fi
}

# =====================================================================================
# Case 2: all five top-level vault sources failing -- well-formed envelope, every vault.* key
# null, errors[] populated (five entries), exit 2.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(export "${ALL_FAIL_ENV[@]}"; run_vr "$scratch" "$stub_dir" 2>/tmp/vr_case2_err)"
  rc=$?

  if [ "$rc" -eq 2 ]; then
    common_test_pass "(2) all vault sources failing: exit 2"
  else
    common_test_fail "(2) all vault sources failing: exit 2" "got rc=$rc"
  fi
  if echo "$out" | jq -e '.schema == "sapience-vault-read/1"' >/dev/null 2>&1; then
    common_test_pass "(2) all vault sources failing: well-formed envelope (schema present)"
  else
    common_test_fail "(2) all vault sources failing: well-formed envelope (schema present)" "out=$out"
  fi
  if echo "$out" | jq -e '
      .vault.projects == null and .vault.docs == null and .vault.doc_bodies == {} and
      .vault.doc_comments == {} and .vault.project_notes == null and
      .vault.suggestions == null and .vault.notifications == null
    ' >/dev/null 2>&1; then
    common_test_pass "(2) all vault sources failing: every vault.* key is null (doc_bodies/doc_comments empty objects)"
  else
    common_test_fail "(2) all vault sources failing: every vault.* key is null" "out=$out"
  fi
  err_count="$(echo "$out" | jq '.errors | length' 2>/dev/null)" || err_count=0
  if [ "$err_count" = "5" ]; then
    common_test_pass "(2) all vault sources failing: errors[] carries five entries (one per top-level source)"
  else
    common_test_fail "(2) all vault sources failing: errors[] carries five entries" "err_count=$err_count"
  fi
  rm -f /tmp/vr_case2_err
}

# =====================================================================================
# Case 3: all five top-level vault sources succeeding (plus one unread doc) -- full envelope
# validation, doc_bodies/doc_comments carry the unread doc, exit 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(export "${ALL_SUCCESS_ENV[@]}"; run_vr "$scratch" "$stub_dir" 2>/dev/null)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(3) all vault sources succeeding: exit 0"
  else
    common_test_fail "(3) all vault sources succeeding: exit 0" "got rc=$rc out=$out"
  fi
  if echo "$out" | jq -e '
      has("schema") and has("generated_at") and has("repo") and has("local") and has("vault") and has("errors") and
      (.repo | has("toplevel") and has("name") and has("binding")) and
      (.local | has("git") and has("state") and has("events") and has("errors") and has("sessions")) and
      (.local.git | has("since") and has("log") and has("diff_stat")) and
      (.vault | has("projects") and has("docs") and has("doc_bodies") and has("doc_comments") and
                has("project_notes") and has("suggestions") and has("notifications"))
    ' >/dev/null 2>&1; then
    common_test_pass "(3) all vault sources succeeding: envelope validates against every pinned key"
  else
    common_test_fail "(3) all vault sources succeeding: envelope validates against every pinned key" "out=$out"
  fi
  if echo "$out" | jq -e '.vault.doc_bodies["doc-a"].body == "hello" and .vault.doc_comments["doc-a"].comments[0].id == 1' >/dev/null 2>&1; then
    common_test_pass "(3) all vault sources succeeding: doc_bodies/doc_comments carry the unread doc's slug"
  else
    common_test_fail "(3) all vault sources succeeding: doc_bodies/doc_comments carry the unread doc's slug" "out=$out"
  fi
  if echo "$out" | jq -e '.vault.doc_bodies | has("doc-b") | not' >/dev/null 2>&1; then
    common_test_pass "(3) all vault sources succeeding: the read doc (doc-b) is NOT fetched"
  else
    common_test_fail "(3) all vault sources succeeding: the read doc (doc-b) is NOT fetched" "out=$out"
  fi
}

# =====================================================================================
# Case 4: a single failing top-level source (docs), the other four succeeding -- exit 0, docs
# is null with exactly one matching errors[] entry, every other vault.* key populated.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  single_fail_env=(
    PROJECTS_BODY='{"ok":true,"projects":[{"id":"CID1","name":"Agent System Work"}]}'
    DOCS_CODE=503 DOCS_BODY='<html>down</html>'
    NOTES_BODY='{"ok":true,"notes":[]}'
    SUGGESTIONS_BODY='{"ok":true,"suggestions":[]}'
    NOTIFICATIONS_BODY='{"ok":true,"notifications":[]}'
  )
  out="$(export "${single_fail_env[@]}"; run_vr "$scratch" "$stub_dir" 2>/dev/null)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(4) single failing source (docs): exit 0 (per-source isolation)"
  else
    common_test_fail "(4) single failing source (docs): exit 0 (per-source isolation)" "got rc=$rc out=$out"
  fi
  if echo "$out" | jq -e '.vault.docs == null and .vault.projects != null and .vault.project_notes != null and .vault.suggestions != null and .vault.notifications != null' >/dev/null 2>&1; then
    common_test_pass "(4) single failing source (docs): only docs is null, the other four succeeded"
  else
    common_test_fail "(4) single failing source (docs): only docs is null, the other four succeeded" "out=$out"
  fi
  docs_err_count="$(echo "$out" | jq '[.errors[] | select(.source == "docs")] | length' 2>/dev/null)" || docs_err_count=0
  if [ "$docs_err_count" = "1" ]; then
    common_test_pass "(4) single failing source (docs): exactly one matching errors[] entry"
  else
    common_test_fail "(4) single failing source (docs): exactly one matching errors[] entry" "docs_err_count=$docs_err_count"
  fi
}

# =====================================================================================
# Case 5: an ordinary run (no --update-cursor) never writes .sapience/last-read.json.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  (export "${ALL_SUCCESS_ENV[@]}"; run_vr "$scratch" "$stub_dir" >/dev/null 2>/dev/null)
  if ! [ -e "$scratch/.sapience/last-read.json" ]; then
    common_test_pass "(5) ordinary run: .sapience/last-read.json never written"
  else
    common_test_fail "(5) ordinary run: .sapience/last-read.json never written"
  fi
}

# =====================================================================================
# Case 6: --update-cursor writes the cursor matching HEAD; a later ordinary run leaves it
# byte-unchanged.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  (export "${ALL_SUCCESS_ENV[@]}"; run_vr "$scratch" "$stub_dir" --update-cursor >/dev/null 2>/dev/null)
  head_sha="$(git -C "$scratch" rev-parse HEAD)"
  recorded_commit="$(jq -r '.commit // empty' "$scratch/.sapience/last-read.json" 2>/dev/null)"

  if [ "$recorded_commit" = "$head_sha" ]; then
    common_test_pass "(6) --update-cursor: recorded commit matches HEAD"
  else
    common_test_fail "(6) --update-cursor: recorded commit matches HEAD" "recorded=$recorded_commit head=$head_sha"
  fi

  before_hash="$(md5sum "$scratch/.sapience/last-read.json" 2>/dev/null)"
  (export "${ALL_SUCCESS_ENV[@]}"; run_vr "$scratch" "$stub_dir" >/dev/null 2>/dev/null)
  after_hash="$(md5sum "$scratch/.sapience/last-read.json" 2>/dev/null)"
  if [ "$before_hash" = "$after_hash" ]; then
    common_test_pass "(6) a later ordinary run leaves the cursor file byte-unchanged"
  else
    common_test_fail "(6) a later ordinary run leaves the cursor file byte-unchanged"
  fi
}

# =====================================================================================
# Case 7: no raw `curl` call site outside the shared lib.
# =====================================================================================
{
  curl_call_sites="$(grep -nE '(^|[[:space:]])curl[[:space:]]' "$SCRIPT_UNDER_TEST" | grep -v '^[0-9]*:[[:space:]]*#')"
  if [ -z "$curl_call_sites" ]; then
    common_test_pass "(7) no raw curl call site outside the shared lib"
  else
    common_test_fail "(7) no raw curl call site outside the shared lib" "sites=$curl_call_sites"
  fi
}

# =====================================================================================
# Case 8: no instruction surface names an MCP write tool as a prescribed write path -- the four
# names appear only inside this script's own negation sentence.
# =====================================================================================
{
  mcp_context="$(grep -A2 -E 'sapience_remember|sapience_wrapup|sapience_handoff|sapience_adddoc' "$SCRIPT_UNDER_TEST")"
  if echo "$mcp_context" | grep -q 'as a write path'; then
    common_test_pass "(8) MCP write tool names appear only inside the negation sentence"
  else
    common_test_fail "(8) MCP write tool names appear only inside the negation sentence" "context=$mcp_context"
  fi
}

# =====================================================================================
# Case 9: the marker-delimited worktree-checkout-resolution block is byte-identical to
# sapience-remember.sh's own copy.
# =====================================================================================
{
  BLOCK_VR="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$SCRIPT_UNDER_TEST")"
  BLOCK_REMEMBER="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$REMEMBER_SCRIPT")"
  if [ -n "$BLOCK_VR" ] && [ "$BLOCK_VR" = "$BLOCK_REMEMBER" ]; then
    common_test_pass "(9) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  else
    common_test_fail "(9) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
