#!/usr/bin/env bash
# test-sapience-project-bind.sh - Regression suite for sapience-project-bind.sh: the
# confirm-or-refuse creation of a fresh Sapience project and the byte-identical
# .sapience/project.json writer.
#
# Interpretation note (recorded here since the governing plan's own Phase 2/Phase 4 task text is
# ambiguous on this exact point): "refusal without --name" below means an invocation missing
# --name entirely (a malformed-argument refusal, exit non-zero, no network call at all -- not
# even the dry-run print, since --name is validated before anything else runs). "refusal without
# --confirm" means a well-formed `--name "<value>"` invocation with NO --confirm: this is the
# scripts's DEFAULT DRY-RUN POSTURE (exit 0, prints the literal payload, makes NO network call
# and writes no file) -- the safety property under test is that the outward-facing mutation
# never fires without --confirm, which both the exit-0 dry-run path and an exit-non-zero refusal
# would equally satisfy; this script chooses the dry-run shape so a caller always sees what WOULD
# be sent. Case 3 below asserts the "no mutation happened" half of that property directly
# (no network call, no file written); the dedicated dry-run cases (4-6) assert the payload shape.
#
# Cases:
#   (1) No arguments at all: refused, non-zero exit, no network call.
#   (2) --confirm alone (no --name): refused, non-zero exit, no network call.
#   (3) --name alone (no --confirm): the default dry-run posture -- exit 0, no network call
#       (no curl stub installed at all, proving it rather than assuming it), no file written.
#   (4) --dry-run default path: the printed payload carries the literal shape (to, project.kind,
#       project.key, follow) with a "<person id>" placeholder (never resolved via a network
#       call) when --to is not given.
#   (5) --dry-run with --to: the printed payload's `to` carries the given override, still no
#       network call.
#   (6) --dry-run: the live token value never appears anywhere in stdout (redaction leak check,
#       mirroring test-sapience-capture.sh's Case 11 convention).
#   (7) --confirm, success: GET /v1/people resolves a sole connection, POST succeeds, the
#       written .sapience/project.json is byte-identical to repo_link.py's link_text() output
#       (project=.share.id, name, repo -- 2-space indent, trailing newline, exactly 3 keys).
#   (8) --confirm with multiple connections and no --to: refused (never guessing among several).
#   (9) --confirm, loud-failure: non-2xx HTTP status -> non-zero exit, no file written.
#   (10) --confirm, loud-failure: non-JSON response body -> non-zero exit, no file written.
#   (11) --confirm, loud-failure: empty `to` array -> non-zero exit, no file written.
#   (12) --confirm, loud-failure: missing `ok: true` -> non-zero exit, no file written.
#   (13) A path-shaped repo short name is refused BEFORE any network call (basename cannot
#        literally contain '/', so this is exercised via a leading-dot basename that fails the
#        REPO_NAME_RE pattern -- the same refusal path a path-shaped value would hit).
#   (14) The marker-delimited worktree-checkout-resolution block is byte-identical to
#        sapience-remember.sh's copy (the lockstep guard's own precondition, checked here too so
#        a divergence is caught at this suite's own level, not only in test-sapience-mcp-
#        registration.sh's Case 30).
#   (15) Pick mode (no --name, no --project) lists one `shared` row and one `received` accepted
#        row with the correct [creator]/[member] labels, exits non-zero, writes nothing.
#   (16) A `received` row with accepted:false and owner:false is excluded from the pick listing.
#   (17) `--project nonexistent` refuses with a non-zero exit and writes nothing.
#   (18) `--project <value> --confirm`, link route success: the written
#        .sapience/project.json is byte-identical to repo_link.py's link_text() output
#        (project=the picked row's id, name, repo) and the link route is called exactly once.
#   (19) `--project <value> --confirm`, link route 404: the file is still written and the
#        reply names the degraded ("recorded locally only") state, exit 0.
#   (20) `--project <value> --confirm`, link route 403: writes nothing, exits non-zero.
#   (21) Create mode (--name, no --confirm) still fires no mutation under the new mode
#        selector -- restates Case 3's safety property after Phase 2's changes.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution. `curl`
# is PATH-shadowed by a minimal inline stub for the network-touching cases only; cases 1-6 and
# 13 install NO stub at all, so "no network call" is an assertion (the real system curl would
# simply fail/hang against app.spnc.ai if ever reached), never an assumption.
#
# Bootstrap note: this suite lives under a DIFFERENT extension (sapience) than the shared
# lib/common.sh it needs (core). Post-deploy, every extension's scripts/tests/ and scripts/lib/
# are flattened into one shared .claude/scripts/ tree; pre-deploy, in a source-store-only
# checkout, it falls back to core's own scripts/lib/common.sh directly.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../lib/common.sh"
elif [ -f "$SCRIPT_DIR/../../../core/scripts/lib/common.sh" ]; then
  COMMON_SH="$SCRIPT_DIR/../../../core/scripts/lib/common.sh"
else
  echo "ERROR: test-sapience-project-bind.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-project-bind.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-project-bind.sh" \
  "$SCRIPT_DIR/../sapience-project-bind.sh")" || exit 2
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

# --- build_scratch -- an isolated <scratch>/.claude/scripts/{sapience-project-bind.sh,
#     deploy-root-guard.sh,lib/{common.sh,sapience-api-lib.sh}} tree plus a scratch git repo.
#     Echoes the scratch repo root. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-project-bind.sh"
  cp "$API_LIB" "$scratch/.claude/scripts/lib/sapience-api-lib.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-project-bind.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

BIN_REL=".claude/scripts/sapience-project-bind.sh"

# run_bind <scratch> [args...] -- no curl stub installed; a network call reaching the real
# system curl would fail/hang, so a case using this helper is asserting "no network call" as a
# structural fact, not an assumption.
run_bind() {
  local scratch="$1"; shift
  # HOME is isolated to this suite's own scratch workdir (never the real ~/.sapience/config.json)
  # as defense in depth: every case that reaches token resolution at all already sets
  # SAPIENCE_TOKEN explicitly, which wins regardless, but isolating HOME too means no real
  # credential or host value is ever read, not even harmlessly.
  env HOME="$TOP_WORKDIR" bash "$scratch/$BIN_REL" "$@"
}

# build_curl_stub <scratch> -- installs a curl stub dispatching on URL substring, driven by
# GET_PEOPLE_BODY/GET_PEOPLE_CODE and POST_SHARE_BODY/POST_SHARE_CODE env vars. Echoes the stub
# directory (to prepend to PATH).
build_curl_stub() {
  local stub_dir
  stub_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  cat > "$stub_dir/curl" <<'STUB'
#!/usr/bin/env bash
url="${!#}"
case "$url" in
  *v1/people\?*)
    printf '%s' "${GET_PEOPLE_BODY:-{\}}"
    printf '\n%s' "${GET_PEOPLE_CODE:-200}"
    ;;
  *v1/people/projects/share*)
    printf '%s' "${POST_SHARE_BODY:-{\}}"
    printf '\n%s' "${POST_SHARE_CODE:-200}"
    ;;
  *v1/people/projects\?*)
    printf '%s' "${GET_PROJECTS_BODY:-{\}}"
    printf '\n%s' "${GET_PROJECTS_CODE:-200}"
    ;;
  *v1/people/projects/*/link*)
    echo "1" >> "$(dirname "$0")/.link_calls"
    printf '%s' "${LINK_BODY:-{\}}"
    printf '\n%s' "${LINK_CODE:-200}"
    ;;
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

# link_call_count <stub_dir> -- echoes the number of times the link route
# (*v1/people/projects/*/link*) was hit against this stub, 0 if never.
link_call_count() {
  local stub_dir="$1"
  if [ -f "$stub_dir/.link_calls" ]; then
    wc -l < "$stub_dir/.link_calls" | tr -d ' '
  else
    echo 0
  fi
}

# run_bind_stubbed <scratch> <stub_dir> [args...] -- invokes with curl PATH-shadowed and a fixed
# SAPIENCE_TOKEN so token resolution always succeeds without touching any real config.json.
run_bind_stubbed() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" SAPIENCE_TOKEN="test-token-fixture" HOME="$TOP_WORKDIR" \
    bash "$scratch/$BIN_REL" "$@"
}

TOKEN_FIXTURE="sapience-bind-test-fixture-token-DO-NOT-LEAK-9d2f"

# =====================================================================================
# Case 1: no arguments at all -- refused, non-zero exit, no network call (no curl stub).
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_bind "$scratch" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(1) no arguments: refused with a non-zero exit"
  else
    common_test_fail "(1) no arguments: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(1) no arguments: no file written"
  else
    common_test_fail "(1) no arguments: no file written"
  fi
}

# =====================================================================================
# Case 2: --confirm alone (no --name) -- refused, non-zero exit, no network call.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_bind "$scratch" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(2) --confirm alone: refused with a non-zero exit"
  else
    common_test_fail "(2) --confirm alone: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "name"; then
    common_test_pass "(2) --confirm alone: message names the missing --name"
  else
    common_test_fail "(2) --confirm alone: message names the missing --name" "out=$out"
  fi
}

# =====================================================================================
# Case 3: --name alone (no --confirm) -- the default dry-run posture: exit 0, no network call
# (NO curl stub installed for this case), no file written.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_bind "$scratch" --name "Agent System Work" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(3) --name alone (no --confirm): exit 0 with no curl stub installed"
  else
    common_test_fail "(3) --name alone (no --confirm): exit 0 with no curl stub installed" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(3) --name alone (no --confirm): no file written (no mutation occurred)"
  else
    common_test_fail "(3) --name alone (no --confirm): no file written (no mutation occurred)"
  fi
}

# =====================================================================================
# Case 4: --dry-run default path payload shape -- "<person id>" placeholder when --to absent.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_bind "$scratch" --name "Agent System Work" 2>/dev/null)"
  payload="$(echo "$out" | tail -n +2)"
  to0="$(echo "$payload" | jq -r '.to[0] // empty' 2>/dev/null)"
  kind="$(echo "$payload" | jq -r '.project.kind // empty' 2>/dev/null)"
  key="$(echo "$payload" | jq -r '.project.key // empty' 2>/dev/null)"
  follow="$(echo "$payload" | jq -r '.follow // empty' 2>/dev/null)"

  if [ "$to0" = "<person id>" ]; then
    common_test_pass "(4) dry-run payload: to[0] is the literal <person id> placeholder"
  else
    common_test_fail "(4) dry-run payload: to[0] is the literal <person id> placeholder" "to0=$to0 out=$out"
  fi
  if [ "$kind" = "project" ] && [ "$key" = "agent-system-work" ] && [ "$follow" = "true" ]; then
    common_test_pass "(4) dry-run payload: project.kind/project.key/follow match the expected shape"
  else
    common_test_fail "(4) dry-run payload: project.kind/project.key/follow match the expected shape" "kind=$kind key=$key follow=$follow"
  fi
}

# =====================================================================================
# Case 5: --dry-run with --to -- the printed payload's `to` carries the given override.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_bind "$scratch" --name "Agent System Work" --to "0f0191b3b0d2" 2>/dev/null)"
  to0="$(echo "$out" | tail -n +2 | jq -r '.to[0] // empty' 2>/dev/null)"
  if [ "$to0" = "0f0191b3b0d2" ]; then
    common_test_pass "(5) dry-run with --to: payload's to[0] is the given override"
  else
    common_test_fail "(5) dry-run with --to: payload's to[0] is the given override" "to0=$to0 out=$out"
  fi
}

# =====================================================================================
# Case 6: --dry-run token redaction -- the live token value never appears anywhere in stdout.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_bind "$scratch" --name "Agent System Work" 2>/dev/null)"
  token_field="$(echo "$out" | tail -n +2 | jq -r '.token // empty' 2>/dev/null)"

  if [ "$token_field" = "***REDACTED***" ]; then
    common_test_pass "(6) dry-run: .token is exactly \"***REDACTED***\""
  else
    common_test_fail "(6) dry-run: .token is exactly \"***REDACTED***\"" "token=$token_field"
  fi
  if echo "$out" | grep -qF "$TOKEN_FIXTURE"; then
    common_test_fail "(6) dry-run: fixture token never appears in stdout" "leaked in: $out"
  else
    common_test_pass "(6) dry-run: fixture token never appears in stdout"
  fi
}

# =====================================================================================
# Case 7: --confirm, success -- byte-identical .sapience/project.json.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PEOPLE_BODY='{"ok":true,"people":[{"id":"0f0191b3b0d2","name":"Oliver"}],"count":1,"me":"Me","me_id":"3951304fedbf"}' \
    POST_SHARE_BODY='{"ok":true,"project":{"kind":"project","key":"agent-system-work","name":"Agent System Work"},"to":["Oliver"],"share":{"id":"NEWCID123456"}}' \
    run_bind_stubbed "$scratch" "$stub_dir" --name "Agent System Work" --confirm 2>&1)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(7) --confirm success: exit 0"
  else
    common_test_fail "(7) --confirm success: exit 0" "got rc=$rc out=$out"
  fi

  expected_file="$(mktemp -p "$TOP_WORKDIR")"
  python3 -c "
import json
print(json.dumps({'project':'NEWCID123456','name':'Agent System Work','repo':'$(basename "$scratch")'}, indent=2, sort_keys=False)+'\n', end='')
" > "$expected_file" 2>/dev/null

  if [ -f "$scratch/.sapience/project.json" ] && cmp -s "$scratch/.sapience/project.json" "$expected_file"; then
    common_test_pass "(7) --confirm success: .sapience/project.json is byte-identical to the expected link_text output"
  else
    common_test_fail "(7) --confirm success: .sapience/project.json is byte-identical to the expected link_text output" \
      "$(cat "$scratch/.sapience/project.json" 2>/dev/null) vs expected $(cat "$expected_file")"
  fi

  keys="$(jq -c 'keys' "$scratch/.sapience/project.json" 2>/dev/null)"
  if [ "$keys" = '["name","project","repo"]' ]; then
    common_test_pass "(7) --confirm success: exactly three keys {name, project, repo}"
  else
    common_test_fail "(7) --confirm success: exactly three keys {name, project, repo}" "keys=$keys"
  fi
}

# =====================================================================================
# Case 8: --confirm with multiple connections and no --to -- refused (never guessing).
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PEOPLE_BODY='{"ok":true,"people":[{"id":"a1"},{"id":"a2"}],"count":2,"me":"Me","me_id":"m1"}' \
    run_bind_stubbed "$scratch" "$stub_dir" --name "Agent System Work" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(8) multiple connections, no --to: refused with a non-zero exit"
  else
    common_test_fail "(8) multiple connections, no --to: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(8) multiple connections, no --to: no file written"
  else
    common_test_fail "(8) multiple connections, no --to: no file written"
  fi
}

# =====================================================================================
# Cases 9-12: the four loud-failure response shapes on the confirmed path, each refused with a
# non-zero exit and no file written.
# =====================================================================================
run_loud_failure_case() {
  local case_num="$1" desc="$2" post_code="$3" post_body="$4"
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PEOPLE_BODY='{"ok":true,"people":[{"id":"abc"}],"count":1,"me":"Me","me_id":"m1"}' \
    POST_SHARE_CODE="$post_code" POST_SHARE_BODY="$post_body" \
    run_bind_stubbed "$scratch" "$stub_dir" --name "Agent System Work" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "($case_num) $desc: refused with a non-zero exit"
  else
    common_test_fail "($case_num) $desc: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "($case_num) $desc: no file written"
  else
    common_test_fail "($case_num) $desc: no file written"
  fi
}

run_loud_failure_case 9 "non-2xx HTTP status" "500" '{"error":"server error"}'
run_loud_failure_case 10 "non-JSON response body" "200" '<html>not json</html>'
run_loud_failure_case 11 "empty to array" "200" '{"ok":true,"to":[],"share":{"id":"c1"}}'
run_loud_failure_case 12 "missing ok:true" "200" '{"to":["X"],"share":{"id":"c1"}}'

# =====================================================================================
# Case 13: a path-shaped/invalid repo short name is refused before any network call (no curl
# stub installed). Exercised via a leading-dot basename, which fails REPO_NAME_RE the same way
# a path-shaped value would.
# =====================================================================================
{
  parent="$(mktemp -d -p "$TOP_WORKDIR")"
  repo="$parent/.hidden-repo"
  mkdir -p "$repo/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$repo/.claude/scripts/sapience-project-bind.sh"
  cp "$API_LIB" "$repo/.claude/scripts/lib/sapience-api-lib.sh"
  cp "$GUARD_SCRIPT" "$repo/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$repo/.claude/scripts/lib/common.sh"
  chmod +x "$repo/.claude/scripts/sapience-project-bind.sh"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "test"
  git -C "$repo" commit -q --allow-empty -m "seed"

  out="$(env SAPIENCE_TOKEN="$TOKEN_FIXTURE" HOME="$TOP_WORKDIR" bash "$repo/$BIN_REL" --name "Agent System Work" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(13) invalid repo short name: refused with a non-zero exit before any write"
  else
    common_test_fail "(13) invalid repo short name: refused with a non-zero exit before any write" "got rc=$rc out=$out"
  fi
  if ! [ -e "$repo/.sapience/project.json" ]; then
    common_test_pass "(13) invalid repo short name: no file written"
  else
    common_test_fail "(13) invalid repo short name: no file written"
  fi
}

# =====================================================================================
# Case 14: the marker-delimited worktree-checkout-resolution block is byte-identical to
# sapience-remember.sh's own copy.
# =====================================================================================
{
  BLOCK_BIND="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$SCRIPT_UNDER_TEST")"
  BLOCK_REMEMBER="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$REMEMBER_SCRIPT")"
  if [ -n "$BLOCK_BIND" ] && [ "$BLOCK_BIND" = "$BLOCK_REMEMBER" ]; then
    common_test_pass "(14) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  else
    common_test_fail "(14) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  fi
}

# =====================================================================================
# Case 15: pick mode lists one `shared` row and one `received` accepted row with the correct
# [creator]/[member] labels, exits non-zero, writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[{"id":"cid-owner","title":"Owner Project","owner":true,"accepted":true,"project":{"key":"owner-project"}}],"received":[{"id":"cid-member","title":"Member Project","owner":false,"accepted":true,"project":{"key":"member-project"}}]}' \
    run_bind_stubbed "$scratch" "$stub_dir" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(15) pick mode: exits non-zero"
  else
    common_test_fail "(15) pick mode: exits non-zero" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -q "Owner Project  (cid-owner)  \[creator\]"; then
    common_test_pass "(15) pick mode: lists the owned shared row as [creator]"
  else
    common_test_fail "(15) pick mode: lists the owned shared row as [creator]" "out=$out"
  fi
  if echo "$out" | grep -q "Member Project  (cid-member)  \[member\]"; then
    common_test_pass "(15) pick mode: lists the accepted received row as [member]"
  else
    common_test_fail "(15) pick mode: lists the accepted received row as [member]" "out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(15) pick mode: writes nothing"
  else
    common_test_fail "(15) pick mode: writes nothing"
  fi
}

# =====================================================================================
# Case 16: a `received` row with accepted:false and owner:false is excluded from the listing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[],"received":[{"id":"cid-unaccepted","title":"Unaccepted Project","owner":false,"accepted":false,"project":{"key":"unaccepted-project"}}]}' \
    run_bind_stubbed "$scratch" "$stub_dir" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(16) unaccepted received row: pick mode still exits non-zero"
  else
    common_test_fail "(16) unaccepted received row: pick mode still exits non-zero" "got rc=$rc out=$out"
  fi
  if ! echo "$out" | grep -q "Unaccepted Project"; then
    common_test_pass "(16) unaccepted received row: excluded from the listing"
  else
    common_test_fail "(16) unaccepted received row: excluded from the listing" "out=$out"
  fi
  if echo "$out" | grep -qi "not on any shared project"; then
    common_test_pass "(16) unaccepted received row: empty filtered set names its own refusal"
  else
    common_test_fail "(16) unaccepted received row: empty filtered set names its own refusal" "out=$out"
  fi
}

# =====================================================================================
# Case 17: --project nonexistent refuses with a non-zero exit and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[{"id":"cid-owner","title":"Owner Project","owner":true,"accepted":true,"project":{"key":"owner-project"}}],"received":[]}' \
    run_bind_stubbed "$scratch" "$stub_dir" --project "nonexistent" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(17) --project nonexistent: refused with a non-zero exit"
  else
    common_test_fail "(17) --project nonexistent: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(17) --project nonexistent: no file written"
  else
    common_test_fail "(17) --project nonexistent: no file written"
  fi
}

# =====================================================================================
# Case 18: --project <value> --confirm, link route success -- byte-identical
# .sapience/project.json and the link route called exactly once.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[{"id":"cid-owner","title":"Owner Project","owner":true,"accepted":true,"project":{"key":"owner-project"}}],"received":[]}' \
    LINK_CODE=200 LINK_BODY='{"ok":true}' \
    run_bind_stubbed "$scratch" "$stub_dir" --project "Owner Project" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(18) bind --confirm success: exit 0"
  else
    common_test_fail "(18) bind --confirm success: exit 0" "got rc=$rc out=$out"
  fi

  expected_file="$(mktemp -p "$TOP_WORKDIR")"
  python3 -c "
import json
print(json.dumps({'project':'cid-owner','name':'Owner Project','repo':'$(basename "$scratch")'}, indent=2, sort_keys=False)+'\n', end='')
" > "$expected_file" 2>/dev/null

  if [ -f "$scratch/.sapience/project.json" ] && cmp -s "$scratch/.sapience/project.json" "$expected_file"; then
    common_test_pass "(18) bind --confirm success: .sapience/project.json is byte-identical to the expected link_text output"
  else
    common_test_fail "(18) bind --confirm success: .sapience/project.json is byte-identical to the expected link_text output" \
      "$(cat "$scratch/.sapience/project.json" 2>/dev/null) vs expected $(cat "$expected_file")"
  fi

  link_calls="$(link_call_count "$stub_dir")"
  if [ "$link_calls" = "1" ]; then
    common_test_pass "(18) bind --confirm success: link route called exactly once"
  else
    common_test_fail "(18) bind --confirm success: link route called exactly once" "link_calls=$link_calls"
  fi

  if echo "$out" | grep -q "commit this file: $scratch/.sapience/project.json"; then
    common_test_pass "(18) bind --confirm success: reply ends with the exact file to commit"
  else
    common_test_fail "(18) bind --confirm success: reply ends with the exact file to commit" "out=$out"
  fi
}

# =====================================================================================
# Case 19: --project <value> --confirm, link route 404 -- the file is still written and the
# reply names the degraded state, exit 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[],"received":[{"id":"cid-member","title":"Member Project","owner":false,"accepted":true,"project":{"key":"member-project"}}]}' \
    LINK_CODE=404 LINK_BODY='{"error":"not enabled"}' \
    run_bind_stubbed "$scratch" "$stub_dir" --project "Member Project" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(19) bind --confirm, link route 404: exit 0"
  else
    common_test_fail "(19) bind --confirm, link route 404: exit 0" "got rc=$rc out=$out"
  fi
  if [ -f "$scratch/.sapience/project.json" ] && [ "$(jq -r '.project' "$scratch/.sapience/project.json" 2>/dev/null)" = "cid-member" ]; then
    common_test_pass "(19) bind --confirm, link route 404: file is still written"
  else
    common_test_fail "(19) bind --confirm, link route 404: file is still written"
  fi
  if echo "$out" | grep -qi "404" && echo "$out" | grep -qi "locally only"; then
    common_test_pass "(19) bind --confirm, link route 404: reply names the degraded state"
  else
    common_test_fail "(19) bind --confirm, link route 404: reply names the degraded state" "out=$out"
  fi
  if echo "$out" | grep -qi "suggestions only the project's author sees"; then
    common_test_pass "(19) bind --confirm, link route 404: non-creator member role note is printed"
  else
    common_test_fail "(19) bind --confirm, link route 404: non-creator member role note is printed" "out=$out"
  fi
}

# =====================================================================================
# Case 20: --project <value> --confirm, link route 403 -- writes nothing, exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  stub_dir="$(build_curl_stub)"
  out="$(GET_PROJECTS_BODY='{"ok":true,"shared":[{"id":"cid-owner","title":"Owner Project","owner":true,"accepted":true,"project":{"key":"owner-project"}}],"received":[]}' \
    LINK_CODE=403 LINK_BODY='{"error":"forbidden"}' \
    run_bind_stubbed "$scratch" "$stub_dir" --project "Owner Project" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(20) bind --confirm, link route 403: refused with a non-zero exit"
  else
    common_test_fail "(20) bind --confirm, link route 403: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(20) bind --confirm, link route 403: no file written"
  else
    common_test_fail "(20) bind --confirm, link route 403: no file written"
  fi
  if echo "$out" | grep -qi "join the project first"; then
    common_test_pass "(20) bind --confirm, link route 403: reply names the refusal"
  else
    common_test_fail "(20) bind --confirm, link route 403: reply names the refusal" "out=$out"
  fi
}

# =====================================================================================
# Case 21: create mode (--name, no --confirm) still fires no mutation under the new mode
# selector -- restates Case 3's safety property after Phase 2's changes.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_bind "$scratch" --name "Agent System Work" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(21) create mode, no --confirm: exit 0 with no curl stub installed"
  else
    common_test_fail "(21) create mode, no --confirm: exit 0 with no curl stub installed" "got rc=$rc out=$out"
  fi
  if ! [ -e "$scratch/.sapience/project.json" ]; then
    common_test_pass "(21) create mode, no --confirm: no file written (no mutation occurred)"
  else
    common_test_fail "(21) create mode, no --confirm: no file written (no mutation occurred)"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
