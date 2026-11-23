#!/usr/bin/env bash
# test-review-stack-prepare.sh - Fixture-driven regression suite for review-stack-prepare.sh's
# Phase 1 surface: integration-branch resolution, every PD1 review_base refusal, every PD9
# platform refusal, every remote-resolution branch, and the two static assertions (no
# push/forge/branch-switching invocation; no literal remote or branch name). Each case uses a
# fixture whose remote is named neither `origin` nor `upstream` and whose branch is named
# neither `main` nor `master`, so a hardcoded assumption of any of those names would make the
# matching case fail rather than pass by accident.
#
# Follows the deployed-shape sandbox convention established by test-milestone-review-handoff.sh
# (deploy-root-guard.sh's default structural check requires the script's own directory to end
# in /.claude or /.opencode).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
RSP="$SCRIPT_DIR/../review-stack-prepare.sh"
GUARD="$SCRIPT_DIR/../deploy-root-guard.sh"

PASSED=0
FAILED=0

if [ ! -f "$RSP" ]; then
  echo "ERROR: expected review-stack-prepare.sh at $RSP" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

REMOTE_NAME="fixremote"
REMOTE2_NAME="fixremote2"
BRANCH="integration-work"

# install_scripts <repo> -- the deployed-shape copies the script under test needs.
install_scripts() {
  local d="$1"
  mkdir -p "$d/specs" "$d/.claude/scripts/lib"
  cp -r "$SCRIPT_DIR/../lib/." "$d/.claude/scripts/lib/"
  cp "$GUARD" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$RSP" "$d/.claude/scripts/review-stack-prepare.sh"
  chmod +x "$d"/.claude/scripts/*.sh
}

# make_fixture_repo [review_base_json] -- a sandbox on $BRANCH with a bare remote reachable over
# a file:// URL that LOOKS like a GitHub remote (it embeds "github.com" in its path so the
# platform detector's substring match recognises it without needing a real network remote). Two
# commits exist; the first is tagged "basepoint" so a review base distinct from $BRANCH is
# always resolvable. [review_base_json] is written into .claude-extensions.json verbatim when
# given (a JSON object literal, e.g. '{"review_base":"basepoint"}'); omitted means no
# .claude-extensions.json is written at all (review_base undeclared).
make_fixture_repo() {
  local ext_json="${1:-}"
  local d bare
  d="$(mktemp -d -p "$WORKDIR")"
  bare="$(mktemp -d -p "$WORKDIR")/github.com/fixture/repo.git"
  mkdir -p "$(dirname "$bare")"
  git init -q --bare "$bare"
  git init -q -b "$BRANCH" "$d"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  install_scripts "$d"
  echo seed > "$d/f.txt"
  git -C "$d" add f.txt >/dev/null 2>&1
  git -C "$d" commit -q -m seed >/dev/null 2>&1
  git -C "$d" tag basepoint
  echo more > "$d/f.txt"
  git -C "$d" add f.txt >/dev/null 2>&1
  git -C "$d" commit -q -m advance >/dev/null 2>&1
  git -C "$d" remote add "$REMOTE_NAME" "file://${bare}"
  if [ -n "$ext_json" ]; then
    printf '%s' "$ext_json" > "$d/.claude-extensions.json"
  fi
  printf '%s' "$d"
}

run_rsp() {
  local repo="$1"
  shift
  LAST_OUT="$(cd "$repo" && bash .claude/scripts/review-stack-prepare.sh "$@" 2>&1)"
  LAST_CODE=$?
}

assert_refusal() {
  local label="$1" expected_code="$2" expected_reason="$3"
  if [ "$LAST_CODE" -eq "$expected_code" ] && printf '%s' "$LAST_OUT" | grep -q "REFUSED: review-stack-prepare.sh: ${expected_reason}:"; then
    common_test_pass "$label"
  else
    common_test_fail "$label" "expected exit ${expected_code} with reason ${expected_reason}, got exit ${LAST_CODE}: ${LAST_OUT}"
  fi
}

# =====================================================================
# PD1 refusals
# =====================================================================

repo="$(make_fixture_repo)"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: review_base undeclared refuses with review_base_undeclared, exit 10" 10 review_base_undeclared
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": ""}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base is an empty string refuses with review_base_invalid, exit 11" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": 42}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base is a non-string refuses with review_base_invalid, exit 11" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "no-such-ref-anywhere"}')"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base does not resolve to a commit refuses with review_base_unresolvable, exit 12" 12 review_base_unresolvable
rm -rf "$repo"

repo="$(make_fixture_repo "{\"review_base\": \"${BRANCH}\"}")"
run_rsp "$repo" cut --dry-run
assert_refusal "PD1: declared review_base names the integration branch refuses with review_base_is_integration_branch, exit 13" 13 review_base_is_integration_branch
rm -rf "$repo"

# --review-base override hits the same five refusals (checked once, the undeclared case, since
# the override bypasses "undeclared" by construction -- empty override still refuses invalid).
repo="$(make_fixture_repo)"
run_rsp "$repo" cut --dry-run --review-base ""
assert_refusal "PD1: an empty --review-base override refuses with review_base_invalid, exit 11 (not undeclared)" 11 review_base_invalid
rm -rf "$repo"

repo="$(make_fixture_repo)"
run_rsp "$repo" cut --dry-run --review-base basepoint
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "review_base='basepoint'"; then
  common_test_pass "PD1: a valid --review-base override resolves and is not refused"
else
  common_test_fail "PD1: valid --review-base override" "expected exit 0 with review_base=basepoint, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# PD9 platform refusals (review_base valid throughout, via basepoint)
# =====================================================================

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://gitlab.com/fixture/repo.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: a GitLab remote refuses with platform_gitlab_unsupported, exit 30" 30 platform_gitlab_unsupported
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://example.com/fixture/repo.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: an unrecognised host refuses with platform_unrecognized_host, exit 31" 31 platform_unrecognized_host
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote set-url "$REMOTE_NAME" "https://github.com/fixture/repo.git"
git -C "$repo" remote set-url --push "$REMOTE_NAME" "https://github.com/fixture/other.git"
run_rsp "$repo" cut --dry-run
assert_refusal "PD9: a push URL differing from the fetch URL refuses with platform_push_url_mismatch, exit 32" 32 platform_push_url_mismatch
rm -rf "$repo"

repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
run_rsp "$repo" cut --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "platform='github'"; then
  common_test_pass "PD9: a github.com remote with matching fetch/push URLs resolves to platform=github"
else
  common_test_fail "PD9: github platform resolution" "expected exit 0 with platform=github, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# =====================================================================
# Remote-resolution branches
# =====================================================================

# Branch: --remote always wins, even with no remote of that name configured's URL unresolved by
# other means (ambiguous remotes still resolved explicitly).
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote rename "$REMOTE_NAME" "$REMOTE2_NAME"
bare2_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/other.git"
mkdir -p "$(dirname "$bare2_dir")"
git init -q --bare "$bare2_dir"
git -C "$repo" remote add "$REMOTE_NAME" "file://${bare2_dir}"
run_rsp "$repo" cut --dry-run --remote "$REMOTE_NAME"
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: --remote NAME is used even with another remote present"
else
  common_test_fail "remote resolution: --remote override" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: the integration branch's configured remote (git config branch.<name>.remote) wins
# when --remote is not given and more than one remote exists.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote rename "$REMOTE_NAME" "$REMOTE2_NAME"
bare3_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/third.git"
mkdir -p "$(dirname "$bare3_dir")"
git init -q --bare "$bare3_dir"
git -C "$repo" remote add "$REMOTE_NAME" "file://${bare3_dir}"
git -C "$repo" config "branch.${BRANCH}.remote" "$REMOTE_NAME"
run_rsp "$repo" cut --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: the integration branch's configured remote wins over an unconfigured second remote"
else
  common_test_fail "remote resolution: configured-remote branch" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: with no --remote and no branch config, the repository's single remote is used.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
run_rsp "$repo" cut --dry-run
if [ "$LAST_CODE" -eq 0 ] && printf '%s' "$LAST_OUT" | grep -q "remote='${REMOTE_NAME}'"; then
  common_test_pass "remote resolution: the repository's only remote is used with no --remote and no branch config"
else
  common_test_fail "remote resolution: only-remote branch" "expected exit 0 with remote=${REMOTE_NAME}, got exit ${LAST_CODE}: ${LAST_OUT}"
fi
rm -rf "$repo"

# Branch: two remotes, no --remote, no branch config -> ambiguous, refuses asking for --remote.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
bare4_dir="$(mktemp -d -p "$WORKDIR")/github.com/fixture/fourth.git"
mkdir -p "$(dirname "$bare4_dir")"
git init -q --bare "$bare4_dir"
git -C "$repo" remote add "$REMOTE2_NAME" "file://${bare4_dir}"
run_rsp "$repo" cut --dry-run
assert_refusal "remote resolution: two remotes with no override or branch config refuses with remote_unresolvable, exit 20" 20 remote_unresolvable
rm -rf "$repo"

# Branch: zero remotes, no --remote -> refuses with remote_unresolvable.
repo="$(make_fixture_repo '{"review_base": "basepoint"}')"
git -C "$repo" remote remove "$REMOTE_NAME"
run_rsp "$repo" cut --dry-run
assert_refusal "remote resolution: zero remotes with no override refuses with remote_unresolvable, exit 20" 20 remote_unresolvable
rm -rf "$repo"

# =====================================================================
# Writes-nothing check: a refusing invocation leaves the fixture's git state byte-identical.
# =====================================================================
repo="$(make_fixture_repo)"
before_head="$(git -C "$repo" rev-parse HEAD)"
before_status="$(git -C "$repo" status --porcelain)"
run_rsp "$repo" cut --dry-run
after_head="$(git -C "$repo" rev-parse HEAD)"
after_status="$(git -C "$repo" status --porcelain)"
if [ "$LAST_CODE" -ne 0 ] && [ "$before_head" = "$after_head" ] && [ "$before_status" = "$after_status" ]; then
  common_test_pass "a refused cut --dry-run writes no ref, no file, and leaves HEAD and status unchanged"
else
  common_test_fail "writes-nothing check" "exit=${LAST_CODE} before_head=${before_head} after_head=${after_head} before_status=[${before_status}] after_status=[${after_status}]"
fi
rm -rf "$repo"

# =====================================================================
# Static checks over the script's non-comment lines.
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+(push|checkout|switch|rebase)\b|\bgit[[:space:]]+merge([[:space:]]|$)|git-replay|\bgh[[:space:]]+(pr|api)\b|\bglab[[:space:]]+mr\b' "$RSP" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: review-stack-prepare.sh contains no push/checkout/switch/merge/rebase/replay/gh/glab invocation"
else
  common_test_fail "static check: found forbidden invocation(s): $forbidden_hits"
fi

literal_hits="$(grep -nE '\b(origin|main|master|upstream)\b' "$RSP" | grep -v '^[0-9]*:#' || true)"
if [ -z "$literal_hits" ]; then
  common_test_pass "static check: review-stack-prepare.sh contains no literal origin/main/master/upstream word outside comments"
else
  common_test_fail "static check: found literal name(s): $literal_hits"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
