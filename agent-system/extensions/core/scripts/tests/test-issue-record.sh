#!/usr/bin/env bash
# test-issue-record.sh - Regression suite for issue-record.sh, proving the load-bearing claims
# mechanically: schema validation refuses and writes nothing, concurrent appends lose nothing,
# an unrecognized --class warns-and-appends rather than refusing, a recording failure is
# non-fatal to a caller using the documented invocation form, win entries are recordable on
# equal footing with issue entries, and --task N resolution works (and fails cleanly when
# unresolvable).
#
# Structural model: scripts/tests/test-orchestrate-record-decision.sh (set -uo pipefail,
# pass()/fail()/info() helpers, PASSED/FAILED integer counters, exit 0 on all-pass / 1 on
# any-fail / 2 on environment error). Script-under-test resolution mirrors the deploy-tree-first
# / source-store-fallback candidate list used by that suite, so this one runs correctly both
# post-deploy (.claude/scripts/issue-record.sh) and in a source-store-only checkout
# (agent-system/extensions/core/scripts/issue-record.sh).
#
# Harness: each case builds an isolated scratch project root under mktemp -d, with
# <scratch>/.claude/scripts/{issue-record.sh,deploy-root-guard.sh,lib/common.sh,
# lib/task-lookup-lib.sh} copied in so deploy-root-guard.sh's `*/.claude` case matches and
# PROJECT_ROOT resolves to <scratch>, plus a scratch specs/state.json carrying one active
# project entry and that project's own directory -- the real script runs against a real scratch
# specs/{N}_{slug}/ tree, never the live repo's own specs/.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error
# (issue-record.sh not found at any candidate path).

# task-ref-ok:begin inline, category 3: command-usage examples -- the script under test's own
# --task flag takes a concrete integer project/task number, used literally throughout this
# suite's invocations and scratch state.json fixtures.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

SCRIPT_UNDER_TEST="$(common_test_resolve_subject "issue-record.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/issue-record.sh" \
  "$SCRIPT_DIR/../issue-record.sh")" || exit 2
common_test_declare_subject "$SCRIPT_UNDER_TEST"
GUARD_SCRIPT="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/deploy-root-guard.sh" \
  "$SCRIPT_DIR/../deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SCRIPT"
COMMON_SCRIPT="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/common.sh" \
  "$SCRIPT_DIR/../lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SCRIPT"
TASK_LOOKUP_SCRIPT="$(common_test_resolve_subject "lib/task-lookup-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/task-lookup-lib.sh" \
  "$SCRIPT_DIR/../lib/task-lookup-lib.sh")" || exit 2
common_test_declare_subject "$TASK_LOOKUP_SCRIPT"
CENTRAL_LOG_SCRIPT="$(common_test_resolve_subject "lib/central-log-lib.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/scripts/lib/central-log-lib.sh" \
  "$SCRIPT_DIR/../lib/central-log-lib.sh")" || exit 2
common_test_declare_subject "$CENTRAL_LOG_SCRIPT"

PASSED=0
FAILED=0


TOP_WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${TOP_WORKDIR:-}" ] && [ -d "$TOP_WORKDIR" ] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# --- build_scratch -- builds an isolated <scratch>/.claude/scripts/{...} + <scratch>/specs/
#     tree with one active project (number 1, dir specs/001_demo_task/), echoes the scratch
#     root on stdout. Never touches the live repo's own specs/. ---
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs/001_demo_task"
  cp "$SCRIPT_UNDER_TEST" "$scratch/.claude/scripts/issue-record.sh"
  cp "$GUARD_SCRIPT" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SCRIPT" "$scratch/.claude/scripts/lib/common.sh"
  cp "$TASK_LOOKUP_SCRIPT" "$scratch/.claude/scripts/lib/task-lookup-lib.sh"
  cp "$CENTRAL_LOG_SCRIPT" "$scratch/.claude/scripts/lib/central-log-lib.sh"
  chmod +x "$scratch/.claude/scripts/issue-record.sh"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_projects": [
    {"project_number": 1, "project_name": "demo_task", "status": "implementing"}
  ]
}
EOF
  echo "$scratch"
}

# run_ir <scratch> [args...] -- invokes issue-record.sh from the scratch's .claude tree.
run_ir() {
  local scratch="$1"; shift
  bash "$scratch/.claude/scripts/issue-record.sh" "$@"
}

ISSUES_REL="specs/001_demo_task/issues.jsonl"

# =====================================================================================
# Case (a): missing --what-happened refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor >/dev/null 2>&1; then
    common_test_fail "(a) missing-what-happened: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(a) missing-what-happened: issues.jsonl was created (must not write on a validation failure)"
  else
    common_test_pass "(a) missing-what-happened: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (b): empty --what-happened refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor --what-happened "" \
      >/dev/null 2>&1; then
    common_test_fail "(b) empty-what-happened: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(b) empty-what-happened: issues.jsonl was created (must not write on a validation failure)"
  else
    common_test_pass "(b) empty-what-happened: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (c): --kind outside issue|win refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind bogus --class "tooling bug or gap" --severity minor \
      --what-happened "test" >/dev/null 2>&1; then
    common_test_fail "(c) invalid-kind: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(c) invalid-kind: issues.jsonl was created (must not write on a validation failure)"
  else
    common_test_pass "(c) invalid-kind: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (d): a malformed --tags-json refuses and writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "test" --tags-json '{not valid json' >/dev/null 2>&1; then
    common_test_fail "(d) malformed-tags-json: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(d) malformed-tags-json: issues.jsonl was created (must not write on a validation failure)"
  else
    common_test_pass "(d) malformed-tags-json: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (e): an invalid --severity refuses and writes nothing (true closed-set field).
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity catastrophic \
      --what-happened "test" >/dev/null 2>&1; then
    common_test_fail "(e) invalid-severity: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(e) invalid-severity: issues.jsonl was created (must not write on a validation failure)"
  else
    common_test_pass "(e) invalid-severity: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (f): refusals above leave issues.jsonl byte-for-byte unchanged, not merely
# line-count-equal, when a prior valid entry already exists.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "seed entry" >/dev/null 2>&1
  before="$(md5sum "$doc")"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor --what-happened "" >/dev/null 2>&1
  after="$(md5sum "$doc")"
  if [ "$before" = "$after" ]; then
    common_test_pass "(f) byte-identical-on-refusal: a refused call after a valid entry leaves the file byte-for-byte unchanged"
  else
    common_test_fail "(f) byte-identical-on-refusal: file changed on a refused call (before=$before after=$after)"
  fi
}

# =====================================================================================
# Case (g): append-atomicity -- N concurrent background invocations yield exactly N
# well-formed lines, every one parsing with jq -e, with no interleaved or truncated line.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  N=15
  pids=()
  for i in $(seq 1 "$N"); do
    run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "concurrent entry $i" >/dev/null 2>&1 &
    pids+=($!)
  done
  ok=true
  for pid in "${pids[@]}"; do
    wait "$pid" || ok=false
  done
  line_count=0
  bad_lines=0
  if [ -f "$doc" ]; then
    line_count="$(wc -l < "$doc" | tr -d ' ')"
    while IFS= read -r line; do
      if ! printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
        bad_lines=$((bad_lines + 1))
      fi
    done < "$doc"
  fi
  if [ "$ok" = "true" ] && [ "$line_count" -eq "$N" ] && [ "$bad_lines" -eq 0 ]; then
    common_test_pass "(g) concurrency: $N parallel appends yield exactly $N well-formed lines"
  else
    common_test_fail "(g) concurrency: expected $N well-formed lines, got line_count=$line_count bad_lines=$bad_lines ok=$ok"
  fi
}

# =====================================================================================
# Case (h): an unrecognized --class exits 0, appends one line carrying that class
# verbatim, and emits a warning on stderr.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  stderr_file="$TOP_WORKDIR/ir_stderr_h.txt"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "a brand new never-before-seen class" --severity minor \
    --what-happened "unknown class test" >/dev/null 2>"$stderr_file" || exit_code=$?
  stderr_out="$(cat "$stderr_file" 2>/dev/null)"
  if [ "$exit_code" -eq 0 ] \
    && jq -e '.class == "a brand new never-before-seen class"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
    && printf '%s' "$stderr_out" | grep -qi "warning.*class"; then
    common_test_pass "(h) unknown-class: exits 0, appends the class verbatim, warns on stderr"
  else
    common_test_fail "(h) unknown-class: exit_code=$exit_code stderr=[$stderr_out]"
  fi
}

# =====================================================================================
# Case (i): non-fatal failure -- a call against a nonexistent target leaves the caller's
# exit status unaffected when invoked in the documented non-fatal form, while the script
# itself still signals failure via its own exit code when invoked directly.
# =====================================================================================
{
  scratch="$(build_scratch)"
  direct_exit=0
  run_ir "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
    --kind issue --class "environment" --severity minor --what-happened "test" \
    >/dev/null 2>&1 || direct_exit=$?

  caller_exit=0
  (
    run_ir "$scratch" --task-dir "$scratch/specs/999_nonexistent_task" \
      --kind issue --class "environment" --severity minor --what-happened "test" \
      >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
    exit 0
  ) || caller_exit=$?

  if [ "$direct_exit" -ne 0 ] && [ "$caller_exit" -eq 0 ]; then
    common_test_pass "(i) non-fatal-failure: direct exit nonzero (direct_exit=$direct_exit), documented non-fatal form leaves caller exit 0"
  else
    common_test_fail "(i) non-fatal-failure: direct_exit=$direct_exit caller_exit=$caller_exit"
  fi
}

# =====================================================================================
# Case (j): kind: "win" is accepted and appended on equal footing with an issue.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind win --class "orchestration defect" --severity none \
      --what-happened "a win entry" >/dev/null 2>&1; then
    if jq -e '.kind == "win"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1; then
      common_test_pass "(j) win-entry: a kind=win entry is accepted and appended"
    else
      common_test_fail "(j) win-entry: appended but kind != win: $(tail -1 "$doc")"
    fi
  else
    common_test_fail "(j) win-entry: expected exit 0, got nonzero"
  fi
}

# =====================================================================================
# Case (k): --task N resolution -- a bare task number resolves to the right task
# directory via task-lookup-lib.sh.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task 1 \
      --kind issue --class "environment" --severity minor \
      --what-happened "task-number resolution test" >/dev/null 2>&1; then
    if [ -f "$doc" ] && jq -e '.task_dir == "specs/001_demo_task"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1; then
      common_test_pass "(k) task-number-resolution: --task 1 resolves to specs/001_demo_task"
    else
      common_test_fail "(k) task-number-resolution: resolved but task_dir field wrong or file missing"
    fi
  else
    common_test_fail "(k) task-number-resolution: expected exit 0, got nonzero"
  fi
}

# =====================================================================================
# Case (l): an unresolvable --task number refuses cleanly.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task 999 \
      --kind issue --class "environment" --severity minor \
      --what-happened "should refuse" >/dev/null 2>&1; then
    common_test_fail "(l) unresolvable-task: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(l) unresolvable-task: issues.jsonl was created for an unresolvable task"
  else
    common_test_pass "(l) unresolvable-task: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (m): --task-dir and --task together refuses (mutually exclusive).
# =====================================================================================
{
  scratch="$(build_scratch)"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" --task 1 \
      --kind issue --class "environment" --severity minor \
      --what-happened "should refuse" >/dev/null 2>&1; then
    common_test_fail "(m) mutually-exclusive-task-args: expected nonzero exit, got exit 0"
  else
    common_test_pass "(m) mutually-exclusive-task-args: exited nonzero when both --task-dir and --task given"
  fi
}

# =====================================================================================
# Case (n): --cost-value without --cost-unit refuses.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  if run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "environment" --severity minor --what-happened "test" \
      --cost-value 5 >/dev/null 2>&1; then
    common_test_fail "(n) cost-value-without-unit: expected nonzero exit, got exit 0"
  elif [ -f "$doc" ]; then
    common_test_fail "(n) cost-value-without-unit: issues.jsonl was created"
  else
    common_test_pass "(n) cost-value-without-unit: exited nonzero and wrote nothing"
  fi
}

# =====================================================================================
# Case (o): a well-formed call with every optional field populates all fields correctly
# and the appended line parses with jq -e.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "gate collision" --severity costly --phase implement \
    --dispatch-seq 7 --what-happened "full-field test" \
    --evidence-path "scripts/issue-record.sh:1" --cost-value 12 --cost-unit minutes \
    --resolution fixed_inline --suggested-channel fix_now --tags-json '{"a":1}' \
    --session sess_1000000000_aaaaaa >/dev/null 2>&1
  entry="$(tail -1 "$doc")"
  if printf '%s' "$entry" | jq -e . >/dev/null 2>&1 \
    && jq -e '.phase == "implement" and .dispatch_seq == 7 and .estimated_cost.value == 12
      and .estimated_cost.unit == "minutes" and .resolution == "fixed_inline"
      and .suggested_channel == "fix_now" and .tags.a == 1
      and .session_id == "sess_1000000000_aaaaaa"' <<<"$entry" >/dev/null 2>&1; then
    common_test_pass "(o) full-field: all optional fields populate correctly and the line parses"
  else
    common_test_fail "(o) full-field: $entry"
  fi
}

# =====================================================================================
# Case (p): central-log promotion -- a kind:"issue" append in a scratch wired to a synthetic
# foreign owning repo (via .claude-extensions.json) lands exactly one envelope line in that
# owning repo's central log, stdout stays exactly the entry_id, and the exit code stays 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  owning="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$owning/agent-system/extensions/core" "$owning/specs"
  git -C "$owning" init -q
  git -C "$owning" config user.email "test@example.com"
  git -C "$owning" config user.name "test"
  cat > "$scratch/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$owning/agent-system/extensions/core"}}}
EOF

  out="$(run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "central log promotion" --session sess_1000000000_bbbbbb)"
  rc=$?
  central_log="$owning/specs/central-errors.jsonl"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(p) central promotion: exit 0"
  else
    common_test_fail "(p) central promotion: exit 0" "got rc=$rc"
  fi
  if [ "$out" = "$(tail -1 "$scratch/$ISSUES_REL" | jq -r .entry_id)" ]; then
    common_test_pass "(p) central promotion: stdout is still exactly the entry_id"
  else
    common_test_fail "(p) central promotion: stdout is still exactly the entry_id" "stdout=$out"
  fi
  if [ -f "$central_log" ] && [ "$(wc -l < "$central_log")" -eq 1 ] \
    && jq -e --arg id "$out" '.entry.entry_id == $id and .origin_store == "issues.jsonl"' \
      "$central_log" >/dev/null 2>&1; then
    common_test_pass "(p) central promotion: exactly one well-formed envelope line in the owning repo"
  else
    common_test_fail "(p) central promotion: exactly one well-formed envelope line in the owning repo" "$(cat "$central_log" 2>/dev/null)"
  fi
}

# =====================================================================================
# Case (q): a kind:"win" append is NOT promoted to the central log.
# =====================================================================================
{
  scratch="$(build_scratch)"
  owning="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$owning/agent-system/extensions/core" "$owning/specs"
  git -C "$owning" init -q
  git -C "$owning" config user.email "test@example.com"
  git -C "$owning" config user.name "test"
  cat > "$scratch/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$owning/agent-system/extensions/core"}}}
EOF

  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind win --class "tooling bug or gap" --severity none \
    --what-happened "a win, not promoted" --session sess_1000000000_cccccc >/dev/null 2>&1
  rc=$?
  central_log="$owning/specs/central-errors.jsonl"

  if [ "$rc" -eq 0 ] && [ ! -f "$central_log" ]; then
    common_test_pass "(q) kind=win is not promoted: exit 0, central log not created"
  else
    common_test_fail "(q) kind=win is not promoted: exit 0, central log not created" "rc=$rc file_exists=$([ -f "$central_log" ] && echo yes || echo no)"
  fi
}

# =====================================================================================
# Case (r): an unwritable central target leaves issue-record.sh's own exit code at 0 and its
# local append unaffected.
# =====================================================================================
{
  scratch="$(build_scratch)"
  owning="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$owning/agent-system/extensions/core" "$owning/specs"
  git -C "$owning" init -q
  git -C "$owning" config user.email "test@example.com"
  git -C "$owning" config user.name "test"
  chmod 555 "$owning/specs"
  cat > "$scratch/.claude-extensions.json" <<EOF
{"extensions":{"core":{"source_dir":"$owning/agent-system/extensions/core"}}}
EOF

  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "unwritable central target" --session sess_1000000000_dddddd >/dev/null 2>&1
  rc=$?
  chmod 755 "$owning/specs"

  if [ "$rc" -eq 0 ]; then
    common_test_pass "(r) unwritable central target: issue-record.sh's own exit code stays 0"
  else
    common_test_fail "(r) unwritable central target: issue-record.sh's own exit code stays 0" "got rc=$rc"
  fi
  if [ -s "$scratch/$ISSUES_REL" ]; then
    common_test_pass "(r) unwritable central target: local issues.jsonl append unaffected"
  else
    common_test_fail "(r) unwritable central target: local issues.jsonl append unaffected" "local file missing or empty"
  fi
}

# =====================================================================================
# Case (s): each of the three dispatch's free-text-sentence examples warns (the outside-
# the-seed-enum warning, extended to cite the class-shape convention) and still appends
# its line, class value unchanged, verbatim.
# =====================================================================================
{
  for sentence_class in "research-confirmed-hypothesis" "reuse_of_existing_machinery" \
    "reuse-not-reimplement confirmed by direct source read"; do
    scratch="$(build_scratch)"
    doc="$scratch/$ISSUES_REL"
    stderr_file="$TOP_WORKDIR/ir_stderr_s_$$_$RANDOM.txt"
    exit_code=0
    run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "$sentence_class" --severity minor \
      --what-happened "free-text class shape test" >/dev/null 2>"$stderr_file" || exit_code=$?
    stderr_out="$(cat "$stderr_file" 2>/dev/null)"
    if [ "$exit_code" -eq 0 ] \
      && jq -e --arg c "$sentence_class" '.class == $c' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
      && printf '%s' "$stderr_out" | grep -qi "class value shape"; then
      common_test_pass "(s) free-text-class-shape-warning: '$sentence_class' warns naming the class-shape convention and still appends verbatim"
    else
      common_test_fail "(s) free-text-class-shape-warning: '$sentence_class' exit_code=$exit_code stderr=[$stderr_out]"
    fi
  done
}

# =====================================================================================
# Case (t): a non-canonical spelling of a known seed class (Scope_Excursion) warns
# naming the canonical spelling (scope excursion) and still appends the raw value
# verbatim.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  stderr_file="$TOP_WORKDIR/ir_stderr_t.txt"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "Scope_Excursion" --severity minor \
    --what-happened "non-canonical spelling test" >/dev/null 2>"$stderr_file" || exit_code=$?
  stderr_out="$(cat "$stderr_file" 2>/dev/null)"
  if [ "$exit_code" -eq 0 ] \
    && jq -e '.class == "Scope_Excursion"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
    && printf '%s' "$stderr_out" | grep -qi "canonical" \
    && printf '%s' "$stderr_out" | grep -q "scope excursion"; then
    common_test_pass "(t) canonical-spelling-warning: 'Scope_Excursion' warns naming 'scope excursion' and still appends verbatim"
  else
    common_test_fail "(t) canonical-spelling-warning: exit_code=$exit_code stderr=[$stderr_out]"
  fi
}

# =====================================================================================
# Case (u): a folded class above 6 whitespace-separated tokens emits the additional
# style warning (on top of the outside-the-seed-enum warning) and still appends.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  stderr_file="$TOP_WORKDIR/ir_stderr_u.txt"
  long_class="reuse-not-reimplement confirmed by direct source read"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "$long_class" --severity minor \
    --what-happened "token-count style warning test" >/dev/null 2>"$stderr_file" || exit_code=$?
  stderr_out="$(cat "$stderr_file" 2>/dev/null)"
  if [ "$exit_code" -eq 0 ] \
    && jq -e --arg c "$long_class" '.class == $c' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
    && printf '%s' "$stderr_out" | grep -qi "tokens long"; then
    common_test_pass "(u) token-count-style-warning: an 8-token class emits the style warning and still appends"
  else
    common_test_fail "(u) token-count-style-warning: exit_code=$exit_code stderr=[$stderr_out]"
  fi
}

# =====================================================================================
# Case (v): a canonical seed-class spelling (scope excursion) produces NO warning at
# all -- the clean, expected-usage control case for (s)/(t)/(u) above.
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  stderr_file="$TOP_WORKDIR/ir_stderr_v.txt"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "scope excursion" --severity minor \
    --what-happened "canonical spelling, no warning expected" >/dev/null 2>"$stderr_file" || exit_code=$?
  stderr_out="$(cat "$stderr_file" 2>/dev/null)"
  if [ "$exit_code" -eq 0 ] \
    && jq -e '.class == "scope excursion"' <<<"$(tail -1 "$doc")" >/dev/null 2>&1 \
    && [ -z "$stderr_out" ]; then
    common_test_pass "(v) canonical-no-warning: 'scope excursion' produces no warning at all"
  else
    common_test_fail "(v) canonical-no-warning: exit_code=$exit_code stderr=[$stderr_out]"
  fi
}

# =====================================================================================
# Case (w): mistyped flag under the documented non-fatal form -- an argument-shaped
# refusal self-records exactly one attributable entry while the caller's exit stays 0
# (criteria 1-3; mirrors the exact flag-order task-275 scenario: the mistyped flag comes
# after --what-happened).
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  caller_exit=0
  (
    run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "case w caller prose" --session-id sess_x \
      >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
    exit 0
  ) || caller_exit=$?
  line_count=0
  [ -f "$doc" ] && line_count="$(wc -l < "$doc" | tr -d ' ')"
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ "$caller_exit" -eq 0 ] && [ "$line_count" -eq 1 ] \
    && jq -e '.tags.issue_record_refusal.flag == "--session-id"' <<<"$entry" >/dev/null 2>&1 \
    && jq -e '.what_happened | contains("case w caller prose")' <<<"$entry" >/dev/null 2>&1; then
    common_test_pass "(w) mistyped-flag-non-fatal: caller exit 0, exactly one refusal entry naming --session-id, caller prose preserved"
  else
    common_test_fail "(w) mistyped-flag-non-fatal: caller_exit=$caller_exit line_count=$line_count entry=$entry"
  fi
}

# =====================================================================================
# Case (x): exit-code discrimination -- an argument-shaped refusal (mistyped flag)
# exits exactly 2 directly, while a content-shaped refusal (an unresolvable --task-dir,
# reusing case (i)'s scenario) still exits exactly 1 and still writes nothing.
# =====================================================================================
{
  scratch="$(build_scratch)"
  arg_exit=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "case x argument-shaped" --session-id sess_x \
    >/dev/null 2>&1 || arg_exit=$?

  scratch2="$(build_scratch)"
  content_exit=0
  run_ir "$scratch2" --task-dir "$scratch2/specs/999_nonexistent_task" \
    --kind issue --class "environment" --severity minor --what-happened "case x content-shaped" \
    >/dev/null 2>&1 || content_exit=$?

  if [ "$arg_exit" -eq 2 ] && [ "$content_exit" -eq 1 ] \
    && [ ! -f "$scratch2/specs/999_nonexistent_task/issues.jsonl" ]; then
    common_test_pass "(x) exit-code-discrimination: argument-shaped exits 2, content-shaped exits 1 and writes nothing"
  else
    common_test_fail "(x) exit-code-discrimination: arg_exit=$arg_exit content_exit=$content_exit"
  fi
}

# =====================================================================================
# Case (y): refusal mode is not derailed by an unrelated optional-field error -- a
# malformed --tags-json and a non-integer --dispatch-seq, both parsed before the
# mistyped flag, are forcibly cleared by refusal mode, so exactly one refusal entry
# still appends and the call still exits 2 (rather than refusing with nothing written
# on the unrelated field, as a non-refusal invocation would -- see case (d)).
# =====================================================================================
{
  scratch="$(build_scratch)"
  doc="$scratch/$ISSUES_REL"
  exit_code=0
  run_ir "$scratch" --task-dir "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "case y caller prose" --tags-json '{not valid json' \
    --dispatch-seq notanumber --session-id sess_x \
    >/dev/null 2>&1 || exit_code=$?
  line_count=0
  [ -f "$doc" ] && line_count="$(wc -l < "$doc" | tr -d ' ')"
  entry="$(tail -1 "$doc" 2>/dev/null)"
  if [ "$exit_code" -eq 2 ] && [ "$line_count" -eq 1 ] \
    && jq -e '.tags.issue_record_refusal.flag == "--session-id"' <<<"$entry" >/dev/null 2>&1; then
    common_test_pass "(y) refusal-mode-not-derailed: malformed --tags-json/--dispatch-seq parsed before the mistyped flag does not prevent the refusal entry; exits 2"
  else
    common_test_fail "(y) refusal-mode-not-derailed: exit_code=$exit_code line_count=$line_count entry=$entry"
  fi
}

# =====================================================================================
# Case (z): stated residual -- a mistyped flag that IS the caller's only task-resolution
# attempt (e.g. --task-dirr) prevents --task-dir/--task from ever being parsed, so no
# task directory resolves and nothing can be appended; this still exits 2 (argument-
# shaped), and the documented non-fatal form still leaves the caller at exit 0.
# =====================================================================================
{
  scratch="$(build_scratch)"
  direct_exit=0
  run_ir "$scratch" --task-dirr "$scratch/specs/001_demo_task" \
    --kind issue --class "tooling bug or gap" --severity minor \
    --what-happened "case z residual" >/dev/null 2>&1 || direct_exit=$?

  caller_exit=0
  (
    run_ir "$scratch" --task-dirr "$scratch/specs/001_demo_task" \
      --kind issue --class "tooling bug or gap" --severity minor \
      --what-happened "case z residual" \
      >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
    exit 0
  ) || caller_exit=$?

  if [ "$direct_exit" -eq 2 ] && [ "$caller_exit" -eq 0 ] \
    && [ ! -f "$scratch/$ISSUES_REL" ]; then
    common_test_pass "(z) unresolvable-task-residual: exits 2, appends nothing, documented-form caller stays exit 0"
  else
    common_test_fail "(z) unresolvable-task-residual: direct_exit=$direct_exit caller_exit=$caller_exit"
  fi
}

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
