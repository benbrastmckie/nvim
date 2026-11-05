#!/usr/bin/env bash
# test-lint-json-channel-discipline.sh - Fixture suite for
# scripts/lint/lint-json-channel-discipline.sh, covering both directions the lint detects:
#
#   INGEST: a collaborator captured with `2>&1` then consumed as JSON/NDJSON, in each of the
#   three shapes named by this lint's own header (jq pipe, jq here-string, while-read NDJSON
#   loop fed by a direct here-string).
#
#   EMIT: the two protection mechanisms this lint checks differently -- a STRUCTURAL regression
#   (the entry-point `exec 3>&1 1>&2` redirect missing from a file expected to carry it) and a
#   PER-LINE regression (two or more unredirected writes in a file relying on individual `>&2`
#   discipline, where the contract promises exactly one).
#
# Plus the real corpus: run the lint with no explicit paths (its own auto-discovery) against the
# real repo and assert it reports the real corpus clean, apart from the one documented
# verify-deploy.sh allowlist entry.
#
# Structural model: test-lint-postflight-boundary.sh's resolve_candidate (deploy-tree-first /
# source-store-fallback) and WORKDIR-fixture conventions.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

LINT_SCRIPT="$(resolve_candidate "lint-json-channel-discipline.sh" \
  "$REPO_ROOT/.claude/scripts/lint/lint-json-channel-discipline.sh" \
  "$SCRIPT_DIR/../lint/lint-json-channel-discipline.sh")" || exit 2

PASSED=0
FAILED=0

common_test_workdir_init

run_lint() {
  # Usage: run_lint <path...>
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$LINT_SCRIPT" --verbose "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  # Deliberate captured-stderr harness slot: this suite exists to test stdout/stderr channel
  # discipline, so the captured stderr stream must stay available to a future assertion even
  # though no case currently reads it.
  # shellcheck disable=SC2034
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# INGEST case 1: known-bad jq pipe (`echo "$x" | jq ...`)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "INGEST case 1: known-bad jq pipe"
cat > "$WORKDIR/bad-ingest-jq-pipe.sh" <<'EOF'
#!/usr/bin/env bash
build_output=$(bash some-collaborator.sh --flag 2>&1)
echo "$build_output" | jq -r '.dispatch_file'
EOF
run_lint "$WORKDIR/bad-ingest-jq-pipe.sh"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "INGEST case 1: jq-pipe shape flagged, non-zero exit"
else
  common_test_fail "INGEST case 1: expected a VIOLATION and non-zero exit; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# INGEST case 2: known-bad jq here-string (`jq ... <<< "$x"`)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "INGEST case 2: known-bad jq here-string"
cat > "$WORKDIR/bad-ingest-jq-herestring.sh" <<'EOF'
#!/usr/bin/env bash
verdict_json=$(bash some-collaborator.sh --flag 2>&1)
result=$(jq -r '.decision' <<< "$verdict_json")
EOF
run_lint "$WORKDIR/bad-ingest-jq-herestring.sh"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "INGEST case 2: jq here-string shape flagged, non-zero exit"
else
  common_test_fail "INGEST case 2: expected a VIOLATION and non-zero exit; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# INGEST case 3: known-bad while-read NDJSON loop fed by a direct here-string
# (`done <<< "$x"`) -- the shape that needed three authoring iterations to catch correctly.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "INGEST case 3: known-bad while-read NDJSON loop (direct here-string)"
cat > "$WORKDIR/bad-ingest-while-read.sh" <<'EOF'
#!/usr/bin/env bash
admit_ndjson=$(bash some-collaborator.sh --flag 2>&1)
while IFS= read -r row; do
  task=$(echo "$row" | jq -r '.task_number')
  echo "processing $task"
done <<< "$admit_ndjson"
EOF
run_lint "$WORKDIR/bad-ingest-while-read.sh"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "INGEST case 3: while-read NDJSON shape flagged, non-zero exit"
else
  common_test_fail "INGEST case 3: expected a VIOLATION and non-zero exit; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# INGEST negative control: a while-read loop fed through an intermediate `< <(cmd | grep ...)`
# process substitution (the verify-deploy.sh `*_lint_output` shape) must NOT be flagged.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "INGEST negative control: filtered process-substitution while-read is not flagged"
cat > "$WORKDIR/good-ingest-filtered-while-read.sh" <<'EOF'
#!/usr/bin/env bash
lint_output=$(bash some-lint.sh --verbose 2>&1)
while IFS= read -r finding; do
  echo "  $finding" >&2
done < <(printf '%s\n' "$lint_output" | grep -F '[VIOLATION]')
EOF
run_lint "$WORKDIR/good-ingest-filtered-while-read.sh"
if [ "$LAST_EXIT" -eq 0 ] && ! echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "INGEST negative control: filtered process-substitution while-read passes clean"
else
  common_test_fail "INGEST negative control: expected a clean pass; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# EMIT case 1 (STRUCTURAL): a file named orchestrate-cycle-plan.sh missing the entry-point
# `exec 3>&1 1>&2` redirect must be flagged.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "EMIT case 1 (structural): missing entry-point redirect is flagged"
cat > "$WORKDIR/orchestrate-cycle-plan.sh" <<'EOF'
#!/usr/bin/env bash
# Output: a single line of compact JSON on stdout.
set -euo pipefail
echo '{"cycle": 1}'
EOF
run_lint "$WORKDIR/orchestrate-cycle-plan.sh"
if [ "$LAST_EXIT" -ne 0 ] && echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "EMIT case 1: missing structural redirect flagged, non-zero exit"
else
  common_test_fail "EMIT case 1: expected a VIOLATION and non-zero exit; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# EMIT negative control (STRUCTURAL): the same filename WITH the redirect present passes clean,
# regardless of how many other bare echo/printf lines the file contains.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "EMIT negative control (structural): redirect present passes clean despite bare echoes"
cat > "$WORKDIR/orchestrate-cycle-postflight.sh" <<'EOF'
#!/usr/bin/env bash
# Output: a single line of compact JSON on stdout.
set -uo pipefail
exec 3>&1 1>&2
resolve_agent() {
  case "$1" in
    plan) echo "planner-agent" ;;
    *) echo "" ;;
  esac
}
printf '%s\n' '{"verdict":"ok"}' >&3
EOF
run_lint "$WORKDIR/orchestrate-cycle-postflight.sh"
if [ "$LAST_EXIT" -eq 0 ] && ! echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "EMIT negative control (structural): passes clean with the redirect present"
else
  common_test_fail "EMIT negative control (structural): expected a clean pass; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# EMIT case 2 (PER-LINE): a file named orchestrate-batch-admit.sh with TWO unredirected writes
# (the contract promises exactly one) must be flagged.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "EMIT case 2 (per-line): two unredirected writes flagged (contract promises exactly one)"
cat > "$WORKDIR/orchestrate-batch-admit.sh" <<'EOF'
#!/usr/bin/env bash
# Output: NDJSON on stdout, one compact JSON object per candidate.
set -euo pipefail
echo "debug: starting admission pass"
printf '%s\n' "$verdicts"
EOF
run_lint "$WORKDIR/orchestrate-batch-admit.sh"
if [ "$LAST_EXIT" -ne 0 ] && [ "$(echo "$LAST_STDOUT" | grep -c 'VIOLATION')" -ge 2 ]; then
  common_test_pass "EMIT case 2: both unredirected writes flagged, non-zero exit"
else
  common_test_fail "EMIT case 2: expected >=2 VIOLATION lines and non-zero exit; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# EMIT negative control (PER-LINE): exactly one unredirected write is the legitimate final emit,
# not a violation.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "EMIT negative control (per-line): exactly one unredirected write is the legitimate final emit"
cat > "$WORKDIR/orchestrate-triage-classify.sh" <<'EOF'
#!/usr/bin/env bash
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order.
set -euo pipefail
echo "debug: starting triage pass" >&2
printf '%s\n' "$verdicts"
EOF
run_lint "$WORKDIR/orchestrate-triage-classify.sh"
if [ "$LAST_EXIT" -eq 0 ] && ! echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "EMIT negative control (per-line): exactly one unredirected write passes clean"
else
  common_test_fail "EMIT negative control (per-line): expected a clean pass; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# EMIT case 3 (PER-LINE): a `> "$var"` file redirect must NOT be counted as an unredirected
# stdout write. A file with one such redirected write plus exactly one legitimate final
# unredirected emit must pass clean, with the redirected write excluded from the candidate set
# entirely (so the "exactly one surviving match" branch still fires on the real emit) -- this is
# the exact shape that produced a false positive at orchestrate-triage-classify.sh:225 before the
# check_emit_perline() predicate fix.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "EMIT case 3 (per-line): a > \"\$var\" file redirect is not a stdout write, one legitimate emit remains"
cat > "$WORKDIR/orchestrate-triage-classify.sh" <<'EOF'
#!/usr/bin/env bash
# Output: NDJSON on stdout, one compact JSON object per candidate, in input order.
set -euo pipefail
printf '%s' "$archived_projects_json" > "$archived_projects_tmpfile"
printf '%s\n' "$verdicts"
EOF
run_lint "$WORKDIR/orchestrate-triage-classify.sh"
if [ "$LAST_EXIT" -eq 0 ] && ! echo "$LAST_STDOUT" | grep -q 'VIOLATION'; then
  common_test_pass "EMIT case 3: > \"\$var\" file redirect excluded, remaining single emit passes clean"
else
  common_test_fail "EMIT case 3: expected a clean pass; got exit=$LAST_EXIT stdout=$LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Real corpus: no explicit paths (the lint's own auto-discovery) against the real repo reports
# it clean, apart from the one documented verify-deploy.sh allowlist entry.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Real corpus: auto-discovery across agent-system/extensions/ reports clean"
run_lint
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "real corpus: lint exits 0 (clean, apart from the documented allowlist entry)"
else
  common_test_fail "real corpus: lint exited $LAST_EXIT -- unexpected finding(s): $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -q 'doc_lint_output'; then
  common_test_pass "real corpus: the documented verify-deploy.sh allowlist entry is exercised"
else
  common_test_fail "real corpus: expected the doc_lint_output allowlist entry to be exercised in verbose output"
fi
if [ "$(echo "$LAST_STDOUT" | grep -c '\[VIOLATION\]')" -eq 0 ]; then
  common_test_pass "real corpus: zero VIOLATION lines"
else
  common_test_fail "real corpus: unexpected VIOLATION line(s): $(echo "$LAST_STDOUT" | grep '\[VIOLATION\]')"
fi

echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
