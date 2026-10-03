#!/usr/bin/env bash
# test-guard-git-push.sh - Fixture-driven regression suite for guard-git-push.sh (the push
# guard + tamper guard) and scripts/git-push-granted.sh (the sanctioned wrapper).
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md and the
# fixture style of test-guard-destructive-git.sh: pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, mktemp -d workdirs with trap EXIT cleanup, exit 0 on all-pass and exit 1 on
# any-fail. The hook and wrapper are driven as real subprocesses with synthetic PreToolUse
# payloads / explicit CLI args; neither is instrumented or modified for testability.
#
# CRITICAL environmental requirement: PUSH_GRANT_KEY_PATH is overridden to a scratch location
# under this suite's own WORKDIR for every invocation below -- this suite NEVER touches the
# real ${XDG_STATE_HOME:-$HOME/.local/state}/claude-agent-system/push-grant.key. Every fixture
# repo gets its own specs/.push-grant/ (cwd-relative, per push-grant-lib.sh's contract), so
# grant files never cross between fixtures; only the HMAC key is shared across this suite's
# fixtures, which is harmless (it is a scratch key, discarded with WORKDIR).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolves to agent-system/extensions/core/{hooks,scripts}/ in source-store mode and to
# .claude/{hooks,scripts}/ in deployed mode, with no branching -- same convention as
# test-guard-destructive-git.sh.
HOOK="$SCRIPT_DIR/../../hooks/guard-git-push.sh"
WRAPPER="$SCRIPT_DIR/../../scripts/git-push-granted.sh"
LIB="$SCRIPT_DIR/../../scripts/lib/push-grant-lib.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

for f in "$HOOK" "$WRAPPER" "$LIB"; do
  if [ ! -f "$f" ]; then
    echo "ERROR: expected file at $f" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

export PUSH_GRANT_KEY_PATH="${WORKDIR}/push-grant.key"
export PUSH_GRANT_DIR="specs/.push-grant"

# make_push_fixture
# Creates a repo + bare remote pair under a fresh mktemp -d directory. The repo's
# init.defaultBranch is explicitly set to "master" (deterministic tier-2 resolution, never the
# fail-closed catch-all) and HEAD is left on "feature-x" (a genuinely non-default branch) so no
# later default-branch-exclusion case passes vacuously. Echoes the repo path.
make_push_fixture() {
  local base repo bare
  base="$(mktemp -d -p "$WORKDIR")"
  repo="${base}/repo"
  bare="${base}/bare.git"
  git init -q --bare "$bare"
  git init -q "$repo"
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test Suite"
  git -C "$repo" config init.defaultBranch master
  echo "line one" > "${repo}/tracked.txt"
  git -C "$repo" add tracked.txt
  git -C "$repo" commit -q -m "initial commit"
  git -C "$repo" remote add origin "$bare"
  git -C "$repo" checkout -q -b feature-x
  echo "$repo"
}

# mint_grant_in <repo> <action_class> <remote> <ref> <force> <request> <mint_source>
# Sources push-grant-lib.sh with cwd set to <repo> and mints exactly one grant, bound to that
# repo's current HEAD. Revokes any pre-existing grant first (at-most-one-live convention).
mint_grant_in() {
  local repo="$1" action="$2" remote="$3" ref="$4" force="$5" request="$6" mint_source="$7" sha
  (
    cd "$repo" || exit 1
    # shellcheck source=../lib/push-grant-lib.sh
    source "$LIB"
    pg_grant_revoke
    sha="$(git rev-parse HEAD)"
    pg_grant_mint "$action" "$remote" "$ref" "$force" "$sha" "$request" "$mint_source" >/dev/null 2>&1
  )
}

# run_hook_in <repo> <command> -- echoes exit code
run_hook_in() {
  local repo="$1" cmd="$2" code
  ( cd "$repo" && jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input: {command: $c}}' | bash "$HOOK" ) \
    >/dev/null 2>/dev/null
  code=$?
  echo "$code"
}

# run_hook_write_in <repo> <file_path> -- echoes exit code, for the tamper-guard Write/Edit path
run_hook_write_in() {
  local repo="$1" fp="$2" code
  ( cd "$repo" && jq -n --arg fp "$fp" '{tool_name:"Write", tool_input: {file_path: $fp}}' | bash "$HOOK" ) \
    >/dev/null 2>/dev/null
  code=$?
  echo "$code"
}

grant_count_in() {
  local repo="$1"
  find "${repo}/specs/.push-grant" -maxdepth 1 -name "grant-*.kv" -type f 2>/dev/null | wc -l | tr -d ' '
}

COMMON_LIB_SRC="$SCRIPT_DIR/../lib/common.sh"
DEPLOY_GUARD_SRC="$SCRIPT_DIR/../deploy-root-guard.sh"

# deployify <repo> -- gives <repo> a minimal .claude/scripts/{,lib/} tree so git-push-granted.sh
# (which, like git-commit-scoped.sh, refuses via deploy-root-guard.sh to run from the source
# store directly) can be invoked as "bash .claude/scripts/git-push-granted.sh" from inside
# <repo>, mirroring test-subagent-postflight-marker.sh's own fixture style. events-append.sh is
# included too, so the audit-trail assertion below is real, not a non-fatal no-op warning.
deployify() {
  local repo="$1"
  mkdir -p "${repo}/.claude/scripts/lib"
  cp "$WRAPPER" "${repo}/.claude/scripts/git-push-granted.sh"
  cp "$LIB" "${repo}/.claude/scripts/lib/push-grant-lib.sh"
  cp "$COMMON_LIB_SRC" "${repo}/.claude/scripts/lib/common.sh"
  cp "$DEPLOY_GUARD_SRC" "${repo}/.claude/scripts/deploy-root-guard.sh"
  cp "$SCRIPT_DIR/../events-append.sh" "${repo}/.claude/scripts/events-append.sh"
  chmod +x "${repo}/.claude/scripts/git-push-granted.sh" "${repo}/.claude/scripts/events-append.sh"
}

# =====================================================================
# Fixture self-check (MUST run first)
# =====================================================================
self_repo="$(make_push_fixture)"
self_branch="$(git -C "$self_repo" rev-parse --abbrev-ref HEAD)"
self_remote="$(git -C "$self_repo" remote get-url origin 2>/dev/null)"
if [ "$self_branch" = "feature-x" ] && [ -n "$self_remote" ]; then
  pass "fixture self-check: repo has a bare 'origin' remote and a non-default working branch ($self_branch)"
else
  fail "fixture self-check: expected branch=feature-x with an origin remote, got branch='$self_branch' remote='$self_remote'"
fi
rm -rf "$self_repo"

# =====================================================================
# Items 1-2: bare git push, no grant -> blocked, naming the sanctioned path
# =====================================================================
for cmd in \
  "git push origin feature-x" \
  "git push -u origin feature-x" \
  "git push --set-upstream origin feature-x" \
  "git push" \
  "git push origin HEAD" \
  "git push origin feature-x:feature-x" \
  ; do
  repo="$(make_push_fixture)"
  code="$(run_hook_in "$repo" "$cmd")"
  err="$( ( cd "$repo" && jq -n --arg c "$cmd" '{tool_name:"Bash", tool_input: {command: $c}}' | bash "$HOOK" ) 2>&1 >/dev/null )"
  rm -rf "$repo"
  if [ "$code" -eq 2 ]; then
    pass "no-grant block: '$cmd' blocked (exit 2)"
  else
    fail "no-grant block: '$cmd' expected exit 2, got $code"
  fi
  case "$err" in
    *"/please"*"git-push-granted.sh"*) pass "no-grant block: '$cmd' stderr names /please and the wrapper" ;;
    *) fail "no-grant block: '$cmd' stderr did not name /please and the wrapper -- got: $err" ;;
  esac
done

# =====================================================================
# Item 8: unchanged default -- a non-push git command is untouched
# =====================================================================
repo="$(make_push_fixture)"
code="$(run_hook_in "$repo" "git status")"
rm -rf "$repo"
if [ "$code" -eq 0 ]; then
  pass "unchanged-default: 'git status' (non-push) passes through (exit 0)"
else
  fail "unchanged-default: 'git status' expected exit 0, got $code"
fi

# =====================================================================
# Item 3: invalidation cases, one per predicate
# =====================================================================

# expired (TIMESTAMP 700s old)
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
grant_file="$(find "${repo}/specs/.push-grant" -maxdepth 1 -name 'grant-*.kv' | head -n1)"
sed -i "s/^TIMESTAMP=.*/TIMESTAMP=$(( $(date -u +%s) - 700 ))/" "$grant_file"
python3 - "$grant_file" "$PUSH_GRANT_KEY_PATH" <<'PYEOF'
import sys, hmac, hashlib
path, keypath = sys.argv[1], sys.argv[2]
lines = open(path).read().splitlines(keepends=True)
body = b"".join(l.encode() for l in lines if not l.startswith("HMAC="))
key = open(keypath, "rb").read()
digest = hmac.new(key, body, hashlib.sha256).hexdigest()
with open(path, "w") as f:
    for l in lines:
        if not l.startswith("HMAC="):
            f.write(l)
    f.write(f"HMAC={digest}\n")
PYEOF
code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "invalidation: expired grant (700s old) blocked" || fail "invalidation: expired grant expected exit 2, got $code"

# wrong branch
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin other-branch 0 "x" please
code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "invalidation: wrong branch blocked" || fail "invalidation: wrong branch expected exit 2, got $code"

# wrong remote
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch upstream feature-x 0 "x" please
code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "invalidation: wrong remote blocked" || fail "invalidation: wrong remote expected exit 2, got $code"

# HEAD moved since mint
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
echo more >> "${repo}/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit -q -m "moved HEAD"
code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "invalidation: HEAD moved since mint blocked" || fail "invalidation: HEAD moved expected exit 2, got $code"

# force-vs-non-force mismatch (grant is non-force, request is --force-with-lease)
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
code="$(run_hook_in "$repo" "git push origin feature-x --force-with-lease")"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "invalidation: force-vs-non-force mismatch blocked" || fail "invalidation: force mismatch expected exit 2, got $code"

# already-consumed
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
first_code="$(run_hook_in "$repo" "git push origin feature-x")"
second_code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
if [ "$first_code" -eq 0 ] && [ "$second_code" -eq 2 ]; then
  pass "invalidation: already-consumed grant blocked on second attempt"
else
  fail "invalidation: already-consumed expected first=0 second=2, got first=$first_code second=$second_code"
fi

# =====================================================================
# Item 4: categorical exclusions, each WITH an otherwise-valid grant present
# =====================================================================

assert_excluded_with_grant() {
  local label="$1" grant_ref="$2" grant_force="$3" cmd="$4" repo code remaining
  repo="$(make_push_fixture)"
  mint_grant_in "$repo" push_branch origin "$grant_ref" "$grant_force" "x" please
  code="$(run_hook_in "$repo" "$cmd")"
  remaining="$(grant_count_in "$repo")"
  rm -rf "$repo"
  if [ "$code" -eq 2 ] && [ "$remaining" -eq 1 ]; then
    pass "$label: excluded (exit 2), grant left unconsumed"
  else
    fail "$label: expected exit 2 with grant untouched, got exit=$code remaining-grants=$remaining"
  fi
}

assert_excluded_with_grant "exclusion: bare --force" feature-x 0 "git push --force origin feature-x"
assert_excluded_with_grant "exclusion: --force-with-lease on default branch" master lease "git push origin master --force-with-lease"
assert_excluded_with_grant "exclusion: --mirror" feature-x 0 "git push --mirror origin"
assert_excluded_with_grant "exclusion: --all" feature-x 0 "git push origin --all"
assert_excluded_with_grant "exclusion: --tags" feature-x 0 "git push origin --tags"
assert_excluded_with_grant "exclusion: --delete" feature-x 0 "git push origin --delete feature-x"
assert_excluded_with_grant "exclusion: :ref deletion refspec" feature-x 0 "git push origin :feature-x"
assert_excluded_with_grant "exclusion: two refspecs" feature-x 0 "git push origin feature-x other-branch"

# =====================================================================
# Item 5: valid-grant success case via the wrapper, against a real fixture remote
# =====================================================================
repo="$(make_push_fixture)"
deployify "$repo"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
wrapper_out="$( cd "$repo" && bash .claude/scripts/git-push-granted.sh --remote origin --ref feature-x 2>&1 )"
wrapper_code=$?
remote_sha="$(git -C "$repo" ls-remote origin feature-x 2>/dev/null | cut -f1)"
local_sha="$(git -C "$repo" rev-parse feature-x)"
remaining="$(grant_count_in "$repo")"
events_line="$(tail -n1 "${repo}/specs/events.jsonl" 2>/dev/null)"
rm -rf "$repo"
if [ "$wrapper_code" -eq 0 ] && [ "$remote_sha" = "$local_sha" ] && [ "$remaining" -eq 0 ]; then
  pass "success: wrapper pushed to fixture remote, remote ref moved, grant consumed"
else
  fail "success: expected wrapper exit 0 + remote moved + grant gone, got exit=$wrapper_code remote_sha=$remote_sha local_sha=$local_sha remaining=$remaining (out: $wrapper_out)"
fi
case "$events_line" in
  *'"push_grant_consumed"'*'"remote":"origin"'*'"ref":"feature-x"'*)
    pass "success: one push_grant_consumed audit event appended with remote/ref" ;;
  *)
    fail "success: expected a push_grant_consumed audit line, got: $events_line" ;;
esac

# =====================================================================
# Item 7: fail-safe cases -- malformed/unverifiable grant must BLOCK
# =====================================================================

assert_malformed_blocks() {
  local label="$1" mutate_fn="$2" repo code grant_file
  repo="$(make_push_fixture)"
  mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
  grant_file="$(find "${repo}/specs/.push-grant" -maxdepth 1 -name 'grant-*.kv' | head -n1)"
  "$mutate_fn" "$grant_file"
  code="$(run_hook_in "$repo" "git push origin feature-x")"
  rm -rf "$repo"
  [ "$code" -eq 2 ] && pass "fail-safe: $label blocked" || fail "fail-safe: $label expected exit 2, got $code"
}

mutate_truncate() { head -c 20 "$1" > "${1}.tmp" && mv "${1}.tmp" "$1"; }
mutate_flip_hmac() { sed -i 's/^HMAC=\(.\)/HMAC=X/' "$1"; }
mutate_remove_field() { sed -i '/^REMOTE=/d' "$1"; }
mutate_nonnumeric_ts() { sed -i 's/^TIMESTAMP=.*/TIMESTAMP=not-a-number/' "$1"; }

assert_malformed_blocks "grant truncated mid-line" mutate_truncate
assert_malformed_blocks "HMAC byte flipped" mutate_flip_hmac
assert_malformed_blocks "required field removed" mutate_remove_field
assert_malformed_blocks "TIMESTAMP non-numeric" mutate_nonnumeric_ts

# key file absent
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
mv "$PUSH_GRANT_KEY_PATH" "${PUSH_GRANT_KEY_PATH}.hidden"
code="$(run_hook_in "$repo" "git push origin feature-x")"
mv "${PUSH_GRANT_KEY_PATH}.hidden" "$PUSH_GRANT_KEY_PATH"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "fail-safe: key file absent blocked" || fail "fail-safe: key file absent expected exit 2, got $code"

# key file mode 0644
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
chmod 644 "$PUSH_GRANT_KEY_PATH"
code="$(run_hook_in "$repo" "git push origin feature-x")"
chmod 600 "$PUSH_GRANT_KEY_PATH"
rm -rf "$repo"
[ "$code" -eq 2 ] && pass "fail-safe: key file mode 0644 blocked" || fail "fail-safe: key file mode 0644 expected exit 2, got $code"

# =====================================================================
# Single-use case: re-write the consumed grant's exact bytes back to disk
# =====================================================================
repo="$(make_push_fixture)"
mint_grant_in "$repo" push_branch origin feature-x 0 "x" please
grant_file="$(find "${repo}/specs/.push-grant" -maxdepth 1 -name 'grant-*.kv' | head -n1)"
grant_bytes="$(cat "$grant_file")"
first_code="$(run_hook_in "$repo" "git push origin feature-x")"
printf '%s\n' "$grant_bytes" > "$grant_file"
second_code="$(run_hook_in "$repo" "git push origin feature-x")"
rm -rf "$repo"
if [ "$first_code" -eq 0 ] && [ "$second_code" -eq 2 ]; then
  pass "single-use: re-writing the consumed grant's exact bytes back does not re-authorize"
else
  fail "single-use: expected first=0 second=2, got first=$first_code second=$second_code"
fi

# =====================================================================
# Tamper cases: Write/Edit/Bash-redirect targeting the grant store or key path
# =====================================================================
repo="$(make_push_fixture)"
code="$(run_hook_write_in "$repo" "specs/.push-grant/grant-fake.kv")"
[ "$code" -eq 2 ] && pass "tamper: Write to grant dir blocked" || fail "tamper: Write to grant dir expected exit 2, got $code"

code="$( ( cd "$repo" && jq -n --arg fp "specs/.push-grant/grant-fake.kv" '{tool_name:"Edit", tool_input:{file_path:$fp}}' | bash "$HOOK" ) >/dev/null 2>/dev/null; echo $? )"
[ "$code" -eq 2 ] && pass "tamper: Edit to grant dir blocked" || fail "tamper: Edit to grant dir expected exit 2, got $code"

code="$( ( cd "$repo" && jq -n --arg fp "$PUSH_GRANT_KEY_PATH" '{tool_name:"Write", tool_input:{file_path:$fp}}' | bash "$HOOK" ) >/dev/null 2>/dev/null; echo $? )"
[ "$code" -eq 2 ] && pass "tamper: Write to key path blocked" || fail "tamper: Write to key path expected exit 2, got $code"

code="$(run_hook_in "$repo" "echo fake > specs/.push-grant/grant-fake.kv")"
[ "$code" -eq 2 ] && pass "tamper: Bash redirect into grant dir blocked" || fail "tamper: Bash redirect into grant dir expected exit 2, got $code"

code="$(run_hook_write_in "$repo" "unrelated-file.txt")"
[ "$code" -eq 0 ] && pass "tamper: Write to an unrelated file passes through" || fail "tamper: Write to unrelated file expected exit 0, got $code"
rm -rf "$repo"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
