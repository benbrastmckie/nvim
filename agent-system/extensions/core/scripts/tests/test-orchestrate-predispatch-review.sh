#!/usr/bin/env bash
# test-orchestrate-predispatch-review.sh - Fixture suite for orchestrate-predispatch-review.sh,
# covering Phase 4's "never print an untested negative" fix for Classes C and D: an ADMITTED
# verdict that carries self_modifying:true or an idle_overlap_advisory used to render as a
# blanket "0 findings" line, even though the hazard was live and carried on the verdict all
# along. This suite stubs orchestrate-batch-admit.sh (the SUT's only subprocess collaborator) so
# each scenario is driven by a synthetic verdict, never the real admission predicate -- this
# script is a REPORT-ONLY consumer of that verdict and never re-derives it (see the SUT's own
# header, Non-Goals).
#
# Structural model: same WORKDIR sandbox shape as the other orchestrate-*.sh test suites (copy
# real collaborator scripts into a synthetic $WORKDIR/.claude/scripts/ tree so
# deploy-root-guard.sh's `*/.claude` parent-directory check passes).
#
# Fixture numbers are synthetic, referred to as "candidate #N" -- never "task N" -- per
# rules/no-task-references-in-deliverables.md.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: expected $1" >&2
    exit 2
  fi
}

SUT_SRC="$CORE_DIR/orchestrate-predispatch-review.sh"
require_file "$SUT_SRC"
for f in orchestrate-predispatch-review.sh deploy-root-guard.sh state-write.sh; do
  require_file "$CORE_DIR/$f"
done
require_file "$CORE_DIR/lib/common.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

setup_sandbox() {
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs"
  for f in orchestrate-predispatch-review.sh deploy-root-guard.sh state-write.sh; do
    cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
  done
  cp "$CORE_DIR/lib/common.sh" "$WORKDIR/.claude/scripts/lib/common.sh"
  chmod +x "$WORKDIR"/.claude/scripts/*.sh
}

SUT="$WORKDIR/.claude/scripts/orchestrate-predispatch-review.sh"
STATE_FILE="$WORKDIR/specs/state.json"

write_state() {
  # Usage: write_state <<'EOF' ... EOF
  cat > "$STATE_FILE"
}

stub_admit() {
  # Usage: stub_admit <<'EOF' ... EOF   (each line is one NDJSON verdict object printed verbatim)
  cat > "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh" <<INNEREOF
#!/usr/bin/env bash
cat <<'VERDICTS'
$(cat)
VERDICTS
INNEREOF
  chmod +x "$WORKDIR/.claude/scripts/orchestrate-batch-admit.sh"
}

run_sut() {
  # Usage: run_sut [extra args...] -- <candidate_number...>
  local args=() nums=() in_nums=false
  for a in "$@"; do
    if [ "$a" = "--" ]; then in_nums=true; continue; fi
    if [ "$in_nums" = "true" ]; then nums+=("$a"); else args+=("$a"); fi
  done
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  ( cd "$WORKDIR" && bash "$SUT" "${args[@]}" "${nums[@]}" >"$stdout_file" 2>"$stderr_file" )
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 1: solo admit self_modifying:true -- the primary false negative this phase fixes.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 1: solo admit carrying self_modifying:true renders as an admitted-hazard row, not 0 findings"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2001, "project_name": "solo_sm", "task_type": "meta", "status": "not_started", "description": "solo self-modifying candidate #2001", "dependencies": [], "file_scope": ["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]}]}
EOF
stub_admit <<'EOF'
{"decision":"admit","task_number":2001,"self_modifying":true}
EOF
run_sut -- 2001

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 1: SUT exits 0"
else
  fail "scenario 1: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "ADMITTED carrying self_modifying: true"; then
  pass "scenario 1: the admitted-hazard row is rendered"
else
  fail "scenario 1: expected an admitted-hazard row; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF '0 findings (no candidate'"'"'s file_scope names an orchestrator-critical path)'; then
  fail "scenario 1: the FALSE '0 findings' negative is still present"
else
  pass "scenario 1: the false '0 findings' negative is gone"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 2: admit carrying an idle_overlap_advisory -- Class D's identical false negative.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 2: admit carrying idle_overlap_advisory renders as an admitted row, not 0 findings"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2002, "project_name": "idle_overlap", "task_type": "general", "status": "not_started", "description": "idle overlap advisory candidate #2002", "dependencies": [], "file_scope": ["lua/foo.lua"]}]}
EOF
stub_admit <<'EOF'
{"decision":"admit","task_number":2002,"self_modifying":false,"idle_overlap_advisory":{"colliding_task_number":2003,"colliding_task_status":"not_started","overlapping_path":"lua/foo.lua","collision_scope":"cross_batch","reason":"fixture"}}
EOF
run_sut -- 2002

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 2: SUT exits 0"
else
  fail "scenario 2: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "ADMITTED (no execution evidence)"; then
  pass "scenario 2: the admitted idle-overlap row is rendered"
else
  fail "scenario 2: expected an admitted idle-overlap row; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 3: defer verdict of each class (C, D, E) -- the pre-existing, unchanged rendering.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 3: a defer verdict of each class still renders its Deferred row"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [
  {"project_number": 2010, "project_name": "defer_c", "task_type": "meta", "status": "not_started", "description": "defer self-modification #2010", "dependencies": [], "file_scope": ["agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"]},
  {"project_number": 2011, "project_name": "defer_d", "task_type": "general", "status": "not_started", "description": "defer file_scope_collision #2011", "dependencies": [], "file_scope": ["lua/bar.lua"]},
  {"project_number": 2012, "project_name": "defer_e", "task_type": "general", "status": "not_started", "description": "defer session_active #2012", "dependencies": [], "file_scope": ["lua/baz.lua"]}
]}
EOF
stub_admit <<'EOF'
{"decision":"defer","task_number":2010,"self_modifying":true,"defer_reason":"self_modifying","critical_path":"agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh","critical_label":"orchestrate-cycle-plan.sh"}
{"decision":"defer","task_number":2011,"self_modifying":false,"defer_reason":"file_scope_collision","colliding_task_number":2013,"colliding_task_status":"not_started","overlapping_path":"lua/bar.lua","collision_scope":"cross_batch","corroborated_by":[]}
{"decision":"defer","task_number":2012,"self_modifying":false,"defer_reason":"session_active","session_id":"sess_live_1","colliding_task_number":2014,"overlapping_path":"lua/baz.lua","session_liveness_reason":"heartbeat within window"}
EOF
run_sut --session-id sess_test_caller -- 2010 2011 2012

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 3: SUT exits 0"
else
  fail "scenario 3: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "orchestrator-critical path agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh"; then
  pass "scenario 3: Class C defer row rendered"
else
  fail "scenario 3: expected a Class C defer row; got: $LAST_STDOUT"
fi
g3_colliding_num=2013
g3_d_marker="file_scope collision with out-of-batch task #${g3_colliding_num}"
if echo "$LAST_STDOUT" | grep -qF "$g3_d_marker"; then
  pass "scenario 3: Class D defer row rendered"
else
  fail "scenario 3: expected a Class D defer row; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "live registered session sess_live_1"; then
  pass "scenario 3: Class E defer row rendered"
else
  fail "scenario 3: expected a Class E defer row; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 4: an all-clean batch -- every class still prints an explicit, precise zero line.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 4: an all-clean batch prints an explicit zero line for every class, none omitted"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2004, "project_name": "clean", "task_type": "general", "status": "not_started", "description": "all-clean candidate #2004", "dependencies": [], "file_scope": ["lua/qux.lua"]}]}
EOF
stub_admit <<'EOF'
{"decision":"admit","task_number":2004,"self_modifying":false}
EOF
run_sut --session-id sess_test_caller_2 -- 2004

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 4: SUT exits 0"
else
  fail "scenario 4: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
g4_missing=""
for marker in "-- Class A:" "-- Class B:" "-- Class C:" "-- Class D:" "-- Class E:"; do
  echo "$LAST_STDOUT" | grep -qF -- "$marker" || g4_missing="${g4_missing}${marker}; "
done
if [ -z "$g4_missing" ]; then
  pass "scenario 4: every class section header is present (none silently omitted)"
else
  fail "scenario 4: missing section header(s): $g4_missing"
fi
if echo "$LAST_STDOUT" | grep -qF "0 findings (no candidate carries the self-modification hazard, deferred or admitted)."; then
  pass "scenario 4: Class C's combined zero-line fires (nothing deferred AND nothing admitted)"
else
  fail "scenario 4: expected Class C's combined zero-line; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "0 findings (no missing cross-batch serializing edges, deferred or admitted)."; then
  pass "scenario 4: Class D's combined zero-line fires"
else
  fail "scenario 4: expected Class D's combined zero-line; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "0 deferred for session contention (this signal exists only on defer verdicts"; then
  pass "scenario 4: Class E's precise zero-line fires"
else
  fail "scenario 4: expected Class E's precise zero-line; got: $LAST_STDOUT"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="
[ "$FAILED" -eq 0 ]
