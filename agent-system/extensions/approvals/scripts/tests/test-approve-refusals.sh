#!/usr/bin/env bash
# test-approve-refusals.sh - One named case per refusal approve-guard.sh's four subcommands
# own, per the task's acceptance criteria: stale review, unsurfaced declaration-level change,
# no human attached (and its three variants), plus the label pairing in both directions.
#
# Structural model: test-askuserquestion-rehome.sh (SCRIPT_DIR/git-worktree-first REPO_ROOT
# resolution, pass()/fail()/info() helpers, PASSED/FAILED counters, exit 0/1/2).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

SOURCE_STORE_SCRIPT="$REPO_ROOT/agent-system/extensions/approvals/scripts/approve-guard.sh"
DEPLOYED_SCRIPT="$REPO_ROOT/.claude/scripts/approve-guard.sh"
if [[ -f "$SOURCE_STORE_SCRIPT" ]]; then
  APPROVE_GUARD="$SOURCE_STORE_SCRIPT"
elif [[ -f "$DEPLOYED_SCRIPT" ]]; then
  APPROVE_GUARD="$DEPLOYED_SCRIPT"
else
  echo "ERROR: approve-guard.sh not found at either:" >&2
  echo "  $SOURCE_STORE_SCRIPT" >&2
  echo "  $DEPLOYED_SCRIPT" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and was not found on PATH." >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

# =========================================================================================
# Refusal case 1: stale review (--check-freshness)
# =========================================================================================
REPO="$WORKDIR/stale-repo"
mkdir -p "$REPO"
(
  cd "$REPO" || exit 2
  git init -q
  git config user.email t@t.com
  git config user.name t
  git commit -q --allow-empty -m init
)
head1="$(cd "$REPO" && git rev-parse --short HEAD)"
echo "{\"component_head\":\"$head1\",\"items\":[]}" > "$WORKDIR/class-fresh.json"

if (cd "$REPO" && bash "$APPROVE_GUARD" --check-freshness --classification "$WORKDIR/class-fresh.json") >/dev/null 2>&1; then
  pass "refusal case 1 (stale review): an UNMOVED tree passes"
else
  fail "refusal case 1 (stale review): an unmoved tree should pass but refused"
fi

(cd "$REPO" && git commit -q --allow-empty -m second)
if err_out="$( (cd "$REPO" && bash "$APPROVE_GUARD" --check-freshness --classification "$WORKDIR/class-fresh.json") 2>&1)"; then
  fail "refusal case 1 (stale review): a MOVED tree should refuse but passed ($err_out)"
else
  if grep -qi "stale review" <<< "$err_out"; then
    pass "refusal case 1 (stale review): a moved tree refuses, nothing recorded, named 'stale review'"
  else
    fail "refusal case 1 (stale review): refused, but message did not name 'stale review': $err_out"
  fi
fi

# =========================================================================================
# Refusal case 2: unsurfaced declaration-level change (--check-surfaced), refuses BEFORE
# any record step (this guard is itself the record-step gate -- a non-zero exit here IS
# "before the record step" by construction, since skill-approve calls it prior to Stage 11).
# =========================================================================================
cat > "$WORKDIR/class-surfaced.json" <<'EOF'
{"component_head":"x","items":[{"id":"Foo.Bar","class":"declaration-level","decl_added":["Foo.NewClaim"],"decl_removed":[],"decl_restated":[]},{"id":"selection","class":"mechanical","decl_added":[],"decl_removed":[],"decl_restated":[]}]}
EOF
echo '{"discrepancies":[]}' > "$WORKDIR/presented-empty.json"
echo '{"discrepancies":["Foo.Bar"]}' > "$WORKDIR/presented-full.json"

if err_out="$(bash "$APPROVE_GUARD" --check-surfaced --classification "$WORKDIR/class-surfaced.json" --presented "$WORKDIR/presented-empty.json" 2>&1)"; then
  fail "refusal case 2 (unsurfaced declaration-level change): expected refusal, got pass ($err_out)"
else
  if grep -q "Foo.Bar" <<< "$err_out" && grep -qi "unsurfaced" <<< "$err_out"; then
    pass "refusal case 2 (unsurfaced declaration-level change): refuses, names the item by id"
  else
    fail "refusal case 2: refused, but did not name the item or the reason: $err_out"
  fi
fi

if bash "$APPROVE_GUARD" --check-surfaced --classification "$WORKDIR/class-surfaced.json" --presented "$WORKDIR/presented-full.json" >/dev/null 2>&1; then
  pass "refusal case 2: a fully-surfaced classification passes"
else
  fail "refusal case 2: a fully-surfaced classification should pass but refused"
fi

# =========================================================================================
# Refusal case 3: no human attached (--check-human) -- three named variants
# =========================================================================================
if err_out="$(bash "$APPROVE_GUARD" --check-human --answer-file "$WORKDIR/does-not-exist.txt" 2>&1)"; then
  fail "refusal case 3 (no human attached, absent file): expected refusal, got pass ($err_out)"
else
  if grep -qi "no human attached" <<< "$err_out"; then
    pass "refusal case 3 (no human attached): an absent answer file refuses"
  else
    fail "refusal case 3: refused, but did not name 'no human attached': $err_out"
  fi
fi

printf 'Answer: yes\n' > "$WORKDIR/answer-no-question.txt"
if bash "$APPROVE_GUARD" --check-human --answer-file "$WORKDIR/answer-no-question.txt" >/dev/null 2>&1; then
  fail "refusal case 3: a file with no 'Question:' line should refuse but passed"
else
  pass "refusal case 3 (no human attached): a file missing 'Question:' refuses"
fi

printf 'Question: approve?\n' > "$WORKDIR/answer-no-answer.txt"
if bash "$APPROVE_GUARD" --check-human --answer-file "$WORKDIR/answer-no-answer.txt" >/dev/null 2>&1; then
  fail "refusal case 3: a file with no 'Answer:' line should refuse but passed"
else
  pass "refusal case 3 (no human attached): a file missing 'Answer:' refuses"
fi

printf 'Question: approve?\nAnswer: yes\n' > "$WORKDIR/answer-complete.txt"
if bash "$APPROVE_GUARD" --check-human --answer-file "$WORKDIR/answer-complete.txt" >/dev/null 2>&1; then
  pass "refusal case 3 (no human attached): a complete Question:/Answer: file passes"
else
  fail "refusal case 3: a complete answer file should pass but refused"
fi

# =========================================================================================
# Label pairing (--check-labels), both directions, independent predicates
# =========================================================================================
if bash "$APPROVE_GUARD" --check-labels --approver "Jane Doe (agent) <j@x.com>" --assisted-by "Bot (agent) <b@x.com>" >/dev/null 2>&1; then
  fail "label pairing: an (agent)-suffixed approver should refuse but passed"
else
  pass "label pairing: an (agent)-suffixed approver refuses"
fi

if bash "$APPROVE_GUARD" --check-labels --approver "Jane Doe <j@x.com>" --assisted-by "Bot <b@x.com>" >/dev/null 2>&1; then
  fail "label pairing: a non-(agent) assisted-by should refuse but passed"
else
  pass "label pairing: a non-(agent) assisted-by refuses"
fi

if bash "$APPROVE_GUARD" --check-labels --approver "Jane Doe <j@x.com>" --assisted-by "Bot (agent) <b@x.com>" >/dev/null 2>&1; then
  pass "label pairing: the correct pairing (owner plain, agent (agent)-suffixed) passes"
else
  fail "label pairing: the correct pairing should pass but refused"
fi

echo
echo "=== test-approve-refusals.sh: $PASSED passed, $FAILED failed ==="
[[ "$FAILED" -eq 0 ]]
