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
#   (16) doc-version --confirm on 409 head_moved: exits non-zero, prints the server's head,
#        nothing retried.
#   (17) doc-version --confirm on 202 (people_propose route): exits 0 with an outcome string
#        distinguishable from "saved".
#   (18) doc-version --confirm on 404 share_gone: exits non-zero, message names the route
#        cannot create a shared-* slug.
#   (19) doc-version --confirm on a normal 200/201 save: exits 0, prints the new revision.
#   (20) doc-version sends the GET's `rev` as base_rev, NOT its `hash` (asserted on the captured
#        request body) -- the single most consequential correctness property of this phase.
#   (21) doc-version --dry-run performs the GET but makes no POST.
#   (22) doc-version: an over-length body and a malformed slug are both refused locally before
#        any network call.
#   (23) At least one doc-version case asserts the bare-docs-GET/POST stub branches (not the
#        comments branch) were the ones hit.
#   (24) ko: key resolution from a scratch .sapience/project.json binding matched against a
#        stubbed GET /v1/people/projects list -- --confirm exits 0.
#   (25) ko --project override wins over the binding (no GET /v1/people/projects call made).
#   (26) ko: no binding and no --project -- non-zero exit, no POST.
#   (27) ko: binding cid present but GET /v1/people/projects has no matching entry -- non-zero
#        exit, no POST.
#   (28) ko: each of the four loud-failure shapes (set_aside non-empty, gated:1, written:0,
#        ok:false) exits non-zero even when the response is otherwise success-shaped.
#   (29) ko: a genuine written >= 1 exits 0.
#   (30) ko: the posted body carries explicit:true on every KO and carries no project_cid key
#        anywhere.
#   (31) ko --dry-run prints the literal /ingest-kos payload with the resolved project key, no
#        network write call made.
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

# write_binding <scratch> <cid> -- writes a minimal .sapience/project.json binding at the
# scratch repo's toplevel (PROJECT_ROOT resolves to the scratch root itself, two levels up from
# .claude/scripts/), matching repo_link.py's three-key link_text shape closely enough for this
# suite's own reader (sapience-publish.sh only reads `.project`).
write_binding() {
  local scratch="$1" cid="$2"
  mkdir -p "$scratch/.sapience"
  jq -n --arg project "$cid" --arg name "Test Project" --arg repo "$(basename "$scratch")" \
    '{project: $project, name: $name, repo: $repo}' > "$scratch/.sapience/project.json"
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
# STUB_DM_BODY/STUB_DM_CODE, STUB_COMMENT_BODY/STUB_COMMENT_CODE, STUB_DOCGET_BODY (the
# pre-write GET's response, always 200), STUB_DOCVER_BODY/STUB_DOCVER_CODE (the doc-version
# POST's response), STUB_PROJECTS_BODY/STUB_PROJECTS_CODE (GET /v1/people/projects, the ko
# subcommand's key-resolution list), and STUB_KO_BODY/STUB_KO_CODE (POST /ingest-kos) env vars.
# ORDER MATTERS: `*/comments*` is listed before the bare `*v1/docs/*` pattern (see this file's
# header note) so a doc-version call cannot be silently matched by the comments branch; the
# `*v1/people/projects*` and `*ingest-kos*` patterns are listed before the bare `*v1/docs/*`
# pattern too, since neither substring overlaps it but ordering them first keeps the dispatch
# readable top-to-bottom by endpoint family. The bare `*v1/docs/*` branch further distinguishes
# GET from POST by the presence of a `--data` argument (sapience_get never sends one;
# sapience_post always does) -- real curl distinguishes these by HTTP method, which this stub
# does not model, so this is the deliberate stand-in. Also tracks, via a file under the given
# tracking dir, which branch was hit, and captures the most recent POST's request body to
# `<hit_dir>/last_post_body`, for the stub-identity and request-body assertions throughout this
# suite. Echoes the stub directory (to prepend to PATH).
build_curl_stub() {
  local stub_dir="$1" hit_dir="$2"
  mkdir -p "$stub_dir" "$hit_dir"
  cat > "$stub_dir/curl" <<STUB
#!/usr/bin/env bash
url="\${!#}"
has_data="false"
post_body=""
prev=""
for a in "\$@"; do
  [ "\$a" = "--data" ] && has_data="true"
  [ "\$prev" = "--data" ] && post_body="\$a"
  prev="\$a"
done
[ -n "\$post_body" ] && printf '%s' "\$post_body" > "$hit_dir/last_post_body"
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
  *v1/people/projects*)
    echo "projects" >> "$hit_dir/branch_hits"
    printf '%s' "\${STUB_PROJECTS_BODY:-{\\}}"
    printf '\\n%s' "\${STUB_PROJECTS_CODE:-200}"
    ;;
  *ingest-kos*)
    echo "ingest-kos" >> "$hit_dir/branch_hits"
    printf '%s' "\${STUB_KO_BODY:-{\\}}"
    printf '\\n%s' "\${STUB_KO_CODE:-200}"
    ;;
  *v1/docs/*)
    if [ "\$has_data" = "true" ]; then
      echo "bare-docs-post" >> "$hit_dir/branch_hits"
      printf '%s' "\${STUB_DOCVER_BODY:-{\\}}"
      printf '\\n%s' "\${STUB_DOCVER_CODE:-200}"
    else
      echo "bare-docs-get" >> "$hit_dir/branch_hits"
      printf '%s' "\${STUB_DOCGET_BODY:-{\\}}"
      printf '\\n200'
    fi
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

# Fixture GET response used by every doc-version case below: rev=7, hash=differs-from-rev so a
# case 20 regression (sending hash instead of rev) is distinguishable from the correct behavior.
DV_GET_FIXTURE='{"slug":"oliver-ben-decisions","rev":7,"hash":"some-content-hash-not-7","body":"old body"}'

# =====================================================================================
# Case 16: doc-version --confirm on 409 head_moved -- exits non-zero, prints the server's head,
# nothing retried (single POST only -- enforced structurally since the stub exits 7 on any
# unrecognized second call, and none occurs here).
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "new body" > "$body_file"
  out="$(STUB_DOCGET_BODY="$DV_GET_FIXTURE" \
    STUB_DOCVER_CODE="409" STUB_DOCVER_BODY='{"code":"head_moved","head":{"rev":8,"body":"someone else wrote this"}}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(16) doc-version --confirm, 409 head_moved: exits non-zero"
  else
    common_test_fail "(16) doc-version --confirm, 409 head_moved: exits non-zero" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "head_moved" && echo "$out" | grep -q '"rev":8'; then
    common_test_pass "(16) doc-version --confirm, 409 head_moved: prints the server's head"
  else
    common_test_fail "(16) doc-version --confirm, 409 head_moved: prints the server's head" "out=$out"
  fi
}

# =====================================================================================
# Case 17: doc-version --confirm on 202 (people_propose route) -- exits 0 with an outcome
# distinguishable from "saved".
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "proposed body" > "$body_file"
  out="$(STUB_DOCGET_BODY="$DV_GET_FIXTURE" \
    STUB_DOCVER_CODE="202" STUB_DOCVER_BODY='{"status":"pending_review"}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(17) doc-version --confirm, 202 people_propose: exits 0"
  else
    common_test_fail "(17) doc-version --confirm, 202 people_propose: exits 0" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "proposed" && ! echo "$out" | grep -qi "^sapience-publish.sh: doc-version: saved"; then
    common_test_pass "(17) doc-version --confirm, 202: outcome is distinguishable from \"saved\""
  else
    common_test_fail "(17) doc-version --confirm, 202: outcome is distinguishable from \"saved\"" "out=$out"
  fi
}

# =====================================================================================
# Case 18: doc-version --confirm on 404 share_gone -- exits non-zero, message names the route
# cannot create a shared-* slug.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "new shared doc body" > "$body_file"
  out="$(STUB_DOCGET_BODY="$DV_GET_FIXTURE" \
    STUB_DOCVER_CODE="404" STUB_DOCVER_BODY='{"code":"share_gone"}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "shared-deadbeef00000000" --body-file "$body_file" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(18) doc-version --confirm, 404 share_gone: exits non-zero"
  else
    common_test_fail "(18) doc-version --confirm, 404 share_gone: exits non-zero" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -qi "share_gone" && echo "$out" | grep -qi "cannot be created"; then
    common_test_pass "(18) doc-version --confirm, 404 share_gone: message names the route cannot create a shared-* slug"
  else
    common_test_fail "(18) doc-version --confirm, 404 share_gone: message names the route cannot create a shared-* slug" "out=$out"
  fi
}

# =====================================================================================
# Case 19: doc-version --confirm on a normal 200/201 save -- exits 0, prints the new revision.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "new saved body" > "$body_file"
  out="$(STUB_DOCGET_BODY="$DV_GET_FIXTURE" \
    STUB_DOCVER_CODE="200" STUB_DOCVER_BODY='{"rev":8,"ok":true}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(19) doc-version --confirm, 200 save: exits 0"
  else
    common_test_fail "(19) doc-version --confirm, 200 save: exits 0" "got rc=$rc out=$out"
  fi
  if echo "$out" | grep -q "new_rev=8"; then
    common_test_pass "(19) doc-version --confirm, 200 save: prints the new revision"
  else
    common_test_fail "(19) doc-version --confirm, 200 save: prints the new revision" "out=$out"
  fi
}

# =====================================================================================
# Case 20: doc-version sends the GET's `rev` as base_rev, NOT its `hash` -- asserted on the
# captured request body. This is the single most consequential correctness property of this
# phase (Research Integration finding 2).
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "new body" > "$body_file"
  STUB_DOCGET_BODY="$DV_GET_FIXTURE" STUB_DOCVER_CODE="200" STUB_DOCVER_BODY='{"rev":8,"ok":true}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" --confirm >/dev/null 2>&1
  sent_base_rev="$(jq -r '.base_rev' "$hit_dir/last_post_body" 2>/dev/null)"
  if [ "$sent_base_rev" = "7" ]; then
    common_test_pass "(20) doc-version sends base_rev=7 (the GET's rev), not the hash"
  else
    common_test_fail "(20) doc-version sends base_rev=7 (the GET's rev), not the hash" "sent_base_rev=$sent_base_rev body=$(cat "$hit_dir/last_post_body" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 21: doc-version --dry-run performs the GET but makes no POST.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "dry run body" > "$body_file"
  out="$(STUB_DOCGET_BODY="$DV_GET_FIXTURE" \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" 2>/dev/null)"
  rc=$?
  base_rev_shown="$(echo "$out" | tail -n +2 | jq -r '.base_rev // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$base_rev_shown" = "7" ]; then
    common_test_pass "(21) doc-version --dry-run: performs the GET and shows the real base_rev=7"
  else
    common_test_fail "(21) doc-version --dry-run: performs the GET and shows the real base_rev=7" "rc=$rc base_rev_shown=$base_rev_shown out=$out"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "bare-docs-post" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(21) doc-version --dry-run: makes no POST"
  else
    common_test_fail "(21) doc-version --dry-run: makes no POST" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 22: an over-length body and a malformed slug are both refused locally, before any
# network call (no stub installed for either sub-case).
# =====================================================================================
{
  scratch="$(build_scratch)"
  long_file="$(mktemp -p "$TOP_WORKDIR")"
  python3 -c "print('a' * 200001, end='')" > "$long_file" 2>/dev/null || printf 'a%.0s' $(seq 1 200001) > "$long_file"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" doc-version "oliver-ben-decisions" --body-file "$long_file" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(22) doc-version: over-length body refused locally before any network call"
  else
    common_test_fail "(22) doc-version: over-length body refused locally before any network call" "got rc=$rc"
  fi

  short_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "body" > "$short_file"
  out2="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" doc-version "BAD SLUG!!" --body-file "$short_file" --confirm 2>&1)"
  rc2=$?
  if [ "$rc2" -ne 0 ]; then
    common_test_pass "(22) doc-version: malformed slug refused locally before any network call"
  else
    common_test_fail "(22) doc-version: malformed slug refused locally before any network call" "got rc=$rc2 out=$out2"
  fi
}

# =====================================================================================
# Case 23: the bare-docs GET and POST stub branches (not the comments branch) are the ones hit
# by a doc-version call.
# =====================================================================================
{
  scratch="$(build_scratch)"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  body_file="$(mktemp -p "$TOP_WORKDIR")"
  echo "body" > "$body_file"
  STUB_DOCGET_BODY="$DV_GET_FIXTURE" STUB_DOCVER_CODE="200" STUB_DOCVER_BODY='{"rev":8,"ok":true}' \
    run_publish_stubbed "$scratch" "$stub_dir" doc-version "oliver-ben-decisions" --body-file "$body_file" --confirm >/dev/null 2>&1
  hits="$(cat "$hit_dir/branch_hits" 2>/dev/null | sort -u | tr '\n' ',')"
  if [ "$hits" = "bare-docs-get,bare-docs-post," ]; then
    common_test_pass "(23) doc-version hits bare-docs-get then bare-docs-post, never the comments branch"
  else
    common_test_fail "(23) doc-version hits bare-docs-get then bare-docs-post, never the comments branch" "hits=$hits"
  fi
}

# Fixture project list used by every ko case below: one project with cid=mEdYrFW_qClSGDfx,
# key=oliver-ben (the dispatch's live reference values, used here only as realistic test
# fixtures -- never hardcoded into the script itself).
KO_PROJECTS_FIXTURE='{"ok":true,"projects":[{"cid":"mEdYrFW_qClSGDfx","key":"oliver-ben","name":"Oliver+Ben"}]}'

# =====================================================================================
# Case 24: ko key resolution from a scratch .sapience/project.json binding matched against a
# stubbed GET /v1/people/projects list -- --confirm exits 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" STUB_KO_CODE="200" STUB_KO_BODY='{"ok":true,"written":1,"gated":0,"threads":1}' \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(24) ko: key resolution from binding + stubbed project list, --confirm exits 0"
  else
    common_test_fail "(24) ko: key resolution from binding + stubbed project list, --confirm exits 0" "got rc=$rc out=$out"
  fi
  sent_project="$(jq -r '.kos[0].project' "$hit_dir/last_post_body" 2>/dev/null)"
  if [ "$sent_project" = "oliver-ben" ]; then
    common_test_pass "(24) ko: posted body's project is the resolved key \"oliver-ben\", not the cid"
  else
    common_test_fail "(24) ko: posted body's project is the resolved key \"oliver-ben\", not the cid" "sent_project=$sent_project"
  fi
}

# =====================================================================================
# Case 25: ko --project override wins over the binding (no GET /v1/people/projects call made).
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_KO_CODE="200" STUB_KO_BODY='{"ok":true,"written":1,"gated":0,"threads":1}' \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" --project "override-key" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(25) ko --project override: --confirm exits 0"
  else
    common_test_fail "(25) ko --project override: --confirm exits 0" "got rc=$rc out=$out"
  fi
  sent_project="$(jq -r '.kos[0].project' "$hit_dir/last_post_body" 2>/dev/null)"
  if [ "$sent_project" = "override-key" ]; then
    common_test_pass "(25) ko --project override: posted body's project is the override, not the binding's resolved key"
  else
    common_test_fail "(25) ko --project override: posted body's project is the override, not the binding's resolved key" "sent_project=$sent_project"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "projects" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(25) ko --project override: GET /v1/people/projects was never called"
  else
    common_test_fail "(25) ko --project override: GET /v1/people/projects was never called" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 26: ko with no binding and no --project -- non-zero exit, no POST (no stub installed).
# =====================================================================================
{
  scratch="$(build_scratch)"
  out="$(SAPIENCE_TOKEN="$TOKEN_FIXTURE" run_publish "$scratch" ko --note "a finding" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(26) ko: no binding, no --project: refused with a non-zero exit, no POST"
  else
    common_test_fail "(26) ko: no binding, no --project: refused with a non-zero exit, no POST" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 27: ko: binding cid present but GET /v1/people/projects has no matching entry -- non-zero
# exit, no POST.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "some-other-cid-not-in-the-list"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "(27) ko: binding cid with no matching project-list entry: refused with a non-zero exit"
  else
    common_test_fail "(27) ko: binding cid with no matching project-list entry: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "ingest-kos" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(27) ko: binding cid with no matching project-list entry: no POST to /ingest-kos"
  else
    common_test_fail "(27) ko: binding cid with no matching project-list entry: no POST to /ingest-kos" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 28: each of the four loud-failure shapes exits non-zero even when the response is
# otherwise success-shaped.
# =====================================================================================
run_ko_loud_failure_case() {
  local case_num="$1" desc="$2" ko_body="$3"
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" STUB_KO_CODE="200" STUB_KO_BODY="$ko_body" \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    common_test_pass "($case_num) $desc: refused with a non-zero exit"
  else
    common_test_fail "($case_num) $desc: refused with a non-zero exit" "got rc=$rc out=$out"
  fi
}

run_ko_loud_failure_case 28a "set_aside non-empty" '{"ok":true,"written":0,"gated":0,"set_aside":[{"why":"needs review","id":"x1"}]}'
run_ko_loud_failure_case 28b "gated=1" '{"ok":true,"written":0,"gated":1}'
run_ko_loud_failure_case 28c "written=0" '{"ok":true,"written":0,"gated":0}'
run_ko_loud_failure_case 28d "ok=false" '{"ok":false,"written":1,"gated":0}'

# =====================================================================================
# Case 29: a genuine written >= 1 exits 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" STUB_KO_CODE="200" STUB_KO_BODY='{"ok":true,"written":1,"gated":0,"threads":1}' \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" --confirm 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    common_test_pass "(29) ko: a genuine written >= 1 exits 0"
  else
    common_test_fail "(29) ko: a genuine written >= 1 exits 0" "got rc=$rc out=$out"
  fi
}

# =====================================================================================
# Case 30: the posted body carries explicit:true on every KO and carries no project_cid key
# anywhere.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" STUB_KO_CODE="200" STUB_KO_BODY='{"ok":true,"written":2,"gated":0,"threads":2}' \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "finding one" --note "finding two" --confirm >/dev/null 2>&1
  explicit_count="$(jq '[.kos[] | select(.explicit == true)] | length' "$hit_dir/last_post_body" 2>/dev/null)"
  kos_count="$(jq '.kos | length' "$hit_dir/last_post_body" 2>/dev/null)"
  if [ "$explicit_count" = "2" ] && [ "$kos_count" = "2" ]; then
    common_test_pass "(30) ko: explicit:true on every KO (2 of 2)"
  else
    common_test_fail "(30) ko: explicit:true on every KO (2 of 2)" "explicit_count=$explicit_count kos_count=$kos_count"
  fi
  if ! grep -q "project_cid" "$hit_dir/last_post_body" 2>/dev/null; then
    common_test_pass "(30) ko: posted body carries no project_cid key anywhere"
  else
    common_test_fail "(30) ko: posted body carries no project_cid key anywhere" "$(cat "$hit_dir/last_post_body" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case 31: ko --dry-run prints the literal /ingest-kos payload with the resolved project key, no
# network write call made.
# =====================================================================================
{
  scratch="$(build_scratch)"
  write_binding "$scratch" "mEdYrFW_qClSGDfx"
  hit_dir="$(mktemp -d -p "$TOP_WORKDIR")"
  stub_dir="$(build_curl_stub "$(mktemp -d -p "$TOP_WORKDIR")" "$hit_dir")"
  out="$(STUB_PROJECTS_BODY="$KO_PROJECTS_FIXTURE" \
    run_publish_stubbed "$scratch" "$stub_dir" ko --note "a finding" 2>/dev/null)"
  rc=$?
  project_shown="$(echo "$out" | tail -n +2 | jq -r '.kos[0].project // empty' 2>/dev/null)"
  if [ "$rc" -eq 0 ] && [ "$project_shown" = "oliver-ben" ]; then
    common_test_pass "(31) ko --dry-run: prints the literal payload with the resolved project key \"oliver-ben\""
  else
    common_test_fail "(31) ko --dry-run: prints the literal payload with the resolved project key \"oliver-ben\"" "rc=$rc project_shown=$project_shown out=$out"
  fi
  if [ ! -f "$hit_dir/branch_hits" ] || ! grep -qF "ingest-kos" "$hit_dir/branch_hits" 2>/dev/null; then
    common_test_pass "(31) ko --dry-run: no network write call made to /ingest-kos"
  else
    common_test_fail "(31) ko --dry-run: no network write call made to /ingest-kos" "branch_hits=$(cat "$hit_dir/branch_hits" 2>/dev/null)"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
