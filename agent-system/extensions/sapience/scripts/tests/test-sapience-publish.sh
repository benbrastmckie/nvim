#!/usr/bin/env bash
# test-sapience-publish.sh - Regression suite for sapience-publish.sh: the four Sapience
# write-surface publishers (doc-comment, doc-version, dm, ko) behind one entry point.
#
# Curl-stub URL dispatch ordering note (load-bearing -- see Phase 1's own Risk row): the
# doc-version POST (`POST /v1/docs/<slug>`) and the doc-comment POST
# (`POST /v1/docs/<slug>/comments`) share the `*v1/docs/*` substring, so the stub's `case`
# dispatch below lists the `*/comments*` pattern BEFORE the bare `*v1/docs/*` pattern -- shell
# `case` matches first-listed-first, so this ordering is what keeps the two branches
# distinguishable. At least one doc-version test case additionally asserts the bare-slug branch
# (never the comments branch) was the one actually hit, so a reversed-order regression fails for
# the right reason rather than passing by accident.
#
# Cases:
#   (1) --help exits 0 and names all four subcommands.
#   (2) An unknown subcommand exits non-zero.
#   (3) No subcommand at all exits non-zero.
#   (4) --dry-run and --confirm together are refused (non-zero exit), for every subcommand.
#   (5) The script's header names no MCP write tool (sapience_remember/sapience_wrapup/
#       sapience_handoff/sapience_adddoc) as a prescribed write path.
#   (6) The marker-delimited worktree-checkout-resolution block is byte-identical to
#       sapience-remember.sh's own copy (local lockstep guard, a second line of defense
#       independent of test-sapience-mcp-registration.sh's Case 30).
#   (7) doc-comment dry-run (no --confirm): prints the literal payload, makes no curl call.
#   (8) doc-comment --confirm on a 201 {slug,n,hash,author,at}: exits 0.
#   (9) doc-comment --confirm on a 413 over-length server response: exits non-zero.
#   (10) doc-comment --confirm on a 2xx body missing hash: exits non-zero.
#   (11) doc-comment: a body over DOC_COMMENT_MAX is refused locally, before any network call.
#   (12) dm --confirm on a 201 (new conversation) then a 201 comment: exits 0, outcome names
#        "new conversation created".
#   (13) dm --confirm on a 200 (existing conversation reused) then a 201 comment: exits 0,
#        outcome names "existing conversation reused" -- distinguishable from case 12's message.
#   (14) dm --confirm with a non-2xx from POST /v1/people/dm: exits non-zero and the comment
#        POST is never reached (asserted via a stub that would exit 7 on an unrecognized URL if
#        the comment endpoint were ever hit).
#   (15) The comments-suffix stub branch is confirmed hit (not the bare-slug branch) by a
#        doc-comment call.
#
# Follows the core shell-test convention: common_test_pass/_fail/_info from lib/common.sh,
# PASSED/FAILED integer counters, a mktemp -d workdir with a trap EXIT cleanup,
# common_test_resolve_subject/common_test_declare_subject source-store-first resolution.
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
  echo "ERROR: test-sapience-publish.sh cannot locate lib/common.sh at any candidate path" >&2
  exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_SH"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "sapience-publish.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/sapience-publish.sh" \
  "$SCRIPT_DIR/../sapience-publish.sh")" || exit 2
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

# --- build_scratch -- an isolated <scratch>/.claude/scripts/{sapience-publish.sh,
#     deploy-root-guard.sh,lib/{common.sh,sapience-api-lib.sh}} tree plus a scratch git repo.
#     Echoes the scratch repo root. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/sapience-publish.sh"
  cp "$API_LIB" "$scratch/.claude/scripts/lib/sapience-api-lib.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SH" "$scratch/.claude/scripts/lib/common.sh"
  chmod +x "$scratch/.claude/scripts/sapience-publish.sh"
  git -C "$scratch" init -q
  git -C "$scratch" config user.email "test@example.com"
  git -C "$scratch" config user.name "test"
  git -C "$scratch" commit -q --allow-empty -m "seed"
  echo "$scratch"
}

BIN_REL=".claude/scripts/sapience-publish.sh"

# run_publish <scratch> [args...] -- no curl stub installed; a network call reaching the real
# system curl would fail/hang, so a case using this helper is asserting "no network call" as a
# structural fact, not an assumption.
run_publish() {
  local scratch="$1"; shift
  env HOME="$TOP_WORKDIR" bash "$scratch/$BIN_REL" "$@"
}

TOKEN_FIXTURE="sapience-publish-test-fixture-token-DO-NOT-LEAK-7c1a"

# build_curl_stub -- installs a curl stub dispatching on URL substring, driven by
# STUB_DM_BODY/STUB_DM_CODE and STUB_COMMENT_BODY/STUB_COMMENT_CODE env vars (doc-version's GET/POST env vars are
# added in that phase). ORDER MATTERS: the `*/comments*` pattern is listed BEFORE the bare
# `*v1/docs/*` pattern (see this file's header note) so a doc-version call in a later phase
# cannot be silently matched by this comments branch. Also tracks, via a file under the given
# tracking dir, whether the comments branch or a later-added bare-docs branch was the one hit,
# for case 15's assertion. Echoes the stub directory (to prepend to PATH).
build_curl_stub() {
  local stub_dir="$1" hit_dir="$2"
  mkdir -p "$stub_dir" "$hit_dir"
  cat > "$stub_dir/curl" <<STUB
#!/usr/bin/env bash
url="\${!#}"
case "\$url" in
  *v1/people/dm*)
    printf '%s' "\${STUB_DM_BODY:-{\\}}"
    printf '\\n%s' "\${STUB_DM_CODE:-200}"
    ;;
  */comments*)
    echo "comments" >> "$hit_dir/branch_hits"
    printf '%s' "\${STUB_COMMENT_BODY:-{\\}}"
    printf '\\n%s' "\${STUB_COMMENT_CODE:-200}"
    ;;
  *v1/docs/*)
    echo "bare-docs" >> "$hit_dir/branch_hits"
    printf '%s' "\${STUB_DOCVER_BODY:-{\\}}"
    printf '\\n%s' "\${STUB_DOCVER_CODE:-200}"
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

# run_publish_stubbed <scratch> <stub_dir> [args...] -- invokes with curl PATH-shadowed and a
# fixed SAPIENCE_TOKEN so token resolution always succeeds without touching any real config.json.
run_publish_stubbed() {
  local scratch="$1" stub_dir="$2"; shift 2
  env PATH="$stub_dir:$PATH" SAPIENCE_TOKEN="test-token-fixture" HOME="$TOP_WORKDIR" \
    bash "$scratch/$BIN_REL" "$@"
}

# =====================================================================================
# Case 7: doc-comment dry-run (no --confirm) -- prints the literal payload, no curl call (no
# stub installed for this case).
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" doc-comment "oliver-ben-decisions" --body "hello" 2>/dev/null)"
  rc=$?
  payload="$(echo "$out" | tail -n +2)"
  body_val="$(echo "$payload" | jq -r '.body // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$body_val" = "hello" ]; then
    common_test_pass "(7) doc-comment dry-run: exits 0 and prints the literal payload with no curl stub installed"
  else
    common_test_fail "(7) doc-comment dry-run: exits 0 and prints the literal payload with no curl stub installed" "rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 8: doc-comment --confirm on a 201 {slug,n,hash,author,at} -- exits 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_COMMENT_CODE="201" STUB_COMMENT_BODY='{"slug":"oliver-ben-decisions","n":1,"hash":"h1","author":"me","at":"2026-11-19T00:00:00Z"}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-comment "oliver-ben-decisions" --body "hello" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(8) doc-comment --confirm, 201 success: exits 0"
  else
    common_test_fail "(8) doc-comment --confirm, 201 success: exits 0" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 9: doc-comment --confirm on a 413 over-length server response -- exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_COMMENT_CODE="413" STUB_COMMENT_BODY='{"error":"comment over 4000 chars"}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-comment "oliver-ben-decisions" --body "hello" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(9) doc-comment --confirm, 413 over-length: exits non-zero"
  else
    common_test_fail "(9) doc-comment --confirm, 413 over-length: exits non-zero" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 10: doc-comment --confirm on a 2xx body missing hash -- exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_COMMENT_CODE="200" STUB_COMMENT_BODY='{"slug":"oliver-ben-decisions","n":1}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-comment "oliver-ben-decisions" --body "hello" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(10) doc-comment --confirm, 2xx missing hash: exits non-zero"
  else
    common_test_fail "(10) doc-comment --confirm, 2xx missing hash: exits non-zero" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 11: a body over DOC_COMMENT_MAX is refused locally, before any network call (no stub
# installed).
# =====================================================================================
{
  scratch="$(build_scratch)"
  long_body="$(printf 'a%.0s' $(seq 1 4001))"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" doc-comment "oliver-ben-decisions" --body "$long_body" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(11) over-length body: refused locally before any network call"
  else
    common_test_fail "(11) over-length body: refused locally before any network call" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 12: dm --confirm on a 201 (new conversation) then a 201 comment -- exits 0, outcome names
# "new conversation created".
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_DM_CODE="201" STUB_DM_BODY='{"slug":"chat-abc123","share":{}}' \
    STUB_COMMENT_CODE="201" STUB_COMMENT_BODY='{"slug":"chat-abc123","n":1,"hash":"h1","author":"me","at":"2026-11-19T00:00:00Z"}' \
    run_publish_stubbed "$scratch" "$stub_dir" dm --to "0f0191b3b0d2" --body "hi there" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(12) dm --confirm, 201 new conversation: exits 0"
  else
    common_test_fail "(12) dm --confirm, 201 new conversation: exits 0" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "new conversation created"; then
    common_test_pass "(12) dm --confirm, 201: outcome names \"new conversation created\""
  else
    common_test_fail "(12) dm --confirm, 201: outcome names \"new conversation created\"" "out=$out"
  fi
}

# =====================================================================================
# Case 13: dm --confirm on a 200 (existing conversation reused) then a 201 comment -- exits 0,
# outcome names "existing conversation reused" -- distinguishable from case 12's message.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_DM_CODE="200" STUB_DM_BODY='{"slug":"chat-abc123","share":{}}' \
    STUB_COMMENT_CODE="201" STUB_COMMENT_BODY='{"slug":"chat-abc123","n":2,"hash":"h2","author":"me","at":"2026-11-19T00:00:00Z"}' \
    run_publish_stubbed "$scratch" "$stub_dir" dm --to "0f0191b3b0d2" --body "hi again" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(13) dm --confirm, 200 reused conversation: exits 0"
  else
    common_test_fail "(13) dm --confirm, 200 reused conversation: exits 0" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "existing conversation reused"; then
    common_test_pass "(13) dm --confirm, 200: outcome names \"existing conversation reused\""
  else
    common_test_fail "(13) dm --confirm, 200: outcome names \"existing conversation reused\"" "out=$out"
  fi
}

# =====================================================================================
# Case 14: dm --confirm with a non-2xx from POST /v1/people/dm -- exits non-zero, and the
# comment POST is never reached (the stub would exit 7 on an unrecognized URL only if the
# comments endpoint were somehow reached without STUB_COMMENT_CODE/STUB_COMMENT_BODY set -- it IS set
# here deliberately to a failure shape too, so reaching it would ALSO fail, making this
# assertion robust to either failure mode).
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_DM_CODE="500" STUB_DM_BODY='{"error":"server error"}' \
    run_publish_stubbed "$scratch" "$stub_dir" dm --to "0f0191b3b0d2" --body "hi" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(14) dm --confirm, non-2xx from /v1/people/dm: exits non-zero"
  else
    common_test_fail "(14) dm --confirm, non-2xx from /v1/people/dm: exits non-zero" "got rc=$rc out=$out"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "comments" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(14) dm --confirm, non-2xx from /v1/people/dm: the comment POST was never reached"
  else
    common_test_fail "(14) dm --confirm, non-2xx from /v1/people/dm: the comment POST was never reached" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 15: the comments-suffix stub branch is confirmed hit (not the bare-slug branch) by a
# doc-comment call.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  STUB_COMMENT_CODE="201" STUB_COMMENT_BODY='{"slug":"oliver-ben-decisions","n":1,"hash":"h1","author":"me","at":"2026-11-19T00:00:00Z"}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-comment "oliver-ben-decisions" --body "hello" --confirm >/dev/null 2>&1
  hits="$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  if [ "$hits" = "comments" ]; then
    common_test_pass "(15) doc-comment hits the comments-suffix stub branch, not the bare-slug branch"
  else
    common_test_fail "(15) doc-comment hits the comments-suffix stub branch, not the bare-slug branch" "hits=$hits"
  fi
}

# =====================================================================================
# Case 1: --help exits 0 and names all four subcommands.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" --help 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(1) --help: exits 0"
  else
    common_test_fail "(1) --help: exits 0" "got rc=$rc out=$out"
  fi
  missing=""
  for sub in doc-comment doc-version dm ko; do
    echo "$out" | grep -qF "$sub" || missing="$missing $sub"
  done
  if [ -z "$missing" ]; then
    common_test_pass "(1) --help: names all four subcommands"
  else
    common_test_fail "(1) --help: names all four subcommands" "missing:$missing out=$out"
  fi
}

# =====================================================================================
# Case 2: an unknown subcommand exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" bogus-subcommand 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(2) unknown subcommand: refused with a non-zero exit"
  else
    common_test_fail "(2) unknown subcommand: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 3: no subcommand at all exits non-zero.
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(run_publish "$scratch" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(3) no subcommand: refused with a non-zero exit"
  else
    common_test_fail "(3) no subcommand: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 4: --dry-run and --confirm together are refused, for every subcommand.
# =====================================================================================
for sub in doc-comment doc-version dm ko; do
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" "$sub" --dry-run --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(4) $sub: --dry-run and --confirm together are refused"
  else
    common_test_fail "(4) $sub: --dry-run and --confirm together are refused" "got rc=$rc out=$out"
  fi
done

# =====================================================================================
# Case 5: the script's header names no MCP write tool as a prescribed write path.
# =====================================================================================
{
  if grep -n 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc' "$SCRIPT_UNDER_TEST" >/dev/null 2>&1; then
    common_test_fail "(5) no MCP write tool named as a prescribed write path" \
      "$(grep -n 'sapience_remember\|sapience_wrapup\|sapience_handoff\|sapience_adddoc' "$SCRIPT_UNDER_TEST")"
  else
    common_test_pass "(5) no MCP write tool named as a prescribed write path"
  fi
}

# =====================================================================================
# Case 6: the marker-delimited worktree-checkout-resolution block is byte-identical to
# sapience-remember.sh's own copy.
# =====================================================================================
{
  BLOCK_PUBLISH="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$SCRIPT_UNDER_TEST")"
  BLOCK_REMEMBER="$(sed -n '/^# === BEGIN sapience-worktree-checkout-resolution/,/^# === END sapience-worktree-checkout-resolution ===$/p' "$REMEMBER_SCRIPT")"
  if [ -n "$BLOCK_PUBLISH" ] && [ "$BLOCK_PUBLISH" = "$BLOCK_REMEMBER" ]; then
    common_test_pass "(6) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  else
    common_test_fail "(6) worktree-checkout-resolution block is byte-identical to sapience-remember.sh's"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
