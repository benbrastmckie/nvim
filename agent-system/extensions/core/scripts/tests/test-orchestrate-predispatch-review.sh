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
require_file "$CORE_DIR/lib/task-lookup-lib.sh"
# lib/file-scope-overlap.sh: NEW as of Class F/G -- the SUT now fails CLOSED (exit 2) if this
# library is unsourceable, so the sandbox must carry a real copy, not a stub.
require_file "$CORE_DIR/lib/file-scope-overlap.sh"
# task-lock.sh: NEW as of the Scenario 10 --repair fixture -- state-write.sh's mutex acquisition
# shells out to task-lock.sh scope-acquire/scope-release, which no earlier scenario in this suite
# exercised (every prior --repair-free scenario never reaches state-write.sh at all).
require_file "$CORE_DIR/task-lock.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

setup_sandbox() {
  rm -rf "$WORKDIR"
  mkdir -p "$WORKDIR/.claude/scripts/lib" "$WORKDIR/specs/archive"
  for f in orchestrate-predispatch-review.sh deploy-root-guard.sh state-write.sh task-lock.sh; do
    cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"
  done
  cp "$CORE_DIR/lib/common.sh" "$WORKDIR/.claude/scripts/lib/common.sh"
  cp "$CORE_DIR/lib/task-lookup-lib.sh" "$WORKDIR/.claude/scripts/lib/task-lookup-lib.sh"
  cp "$CORE_DIR/lib/file-scope-overlap.sh" "$WORKDIR/.claude/scripts/lib/file-scope-overlap.sh"
  chmod +x "$WORKDIR"/.claude/scripts/*.sh
}

SUT="$WORKDIR/.claude/scripts/orchestrate-predispatch-review.sh"
STATE_FILE="$WORKDIR/specs/state.json"
ARCHIVE_STATE_FILE="$WORKDIR/specs/archive/state.json"

write_state() {
  # Usage: write_state <<'EOF' ... EOF
  cat > "$STATE_FILE"
}

write_archive_state() {
  # Usage: write_archive_state <<'EOF' ... EOF
  # Mirrors write_state, but targets specs/archive/state.json -- the path
  # task_lookup_archived_projects_json derives as "${state_file%state.json}archive/state.json".
  # Scenarios that do not call this leave no archive/state.json in the sandbox at all, exercising
  # task_lookup_archived_projects_json's documented "[]" on-absent-archive contract.
  mkdir -p "$(dirname "$ARCHIVE_STATE_FILE")"
  cat > "$ARCHIVE_STATE_FILE"
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
# Doubles as the Class F/G "negative fixture": the sole candidate declares a concrete non-empty,
# non-glob file_scope, so both new sections must print their explicit negatives too.
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
for marker in "-- Class A:" "-- Class B:" "-- Class C:" "-- Class D:" "-- Class E:" "-- Class F:" "-- Class G:"; do
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
if echo "$LAST_STDOUT" | grep -qF "0 findings (every candidate declares a file_scope that is neither missing, literal null, nor an empty array)."; then
  pass "scenario 4: Class F's negative fires (candidate declares a concrete non-empty file_scope)"
else
  fail "scenario 4: expected Class F's negative; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "0 findings (no candidate declares a glob-shaped file_scope entry)."; then
  pass "scenario 4: Class G's negative fires (candidate declares a non-glob-shaped entry)"
else
  fail "scenario 4: expected Class G's negative; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 5: candidate depends on a task that was completed and then archived by /todo -- the
# false-positive this whole fix exists to close. The archived task is resolvable ONLY via
# specs/archive/state.json (task_lookup_archived_projects_json), never active_projects[].
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 5: dependency satisfied by an archived task renders archived_satisfied, never nonexistent"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2020, "project_name": "depends_on_archived", "task_type": "general", "status": "not_started", "description": "candidate #2020", "dependencies": [2021], "file_scope": ["lua/quux.lua"]}]}
EOF
write_archive_state <<'EOF'
{"completed_projects": [{"project_number": 2021, "project_name": "archived_dep", "status": "completed"}], "archived_projects": []}
EOF
run_sut -- 2020

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 5: SUT exits 0"
else
  fail "scenario 5: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "#2020 depends on #2021: archived (satisfied)"; then
  pass "scenario 5: archived-satisfied edge is rendered under the informational label"
else
  fail "scenario 5: expected an archived (satisfied) row for #2020/#2021; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "#2020 depends on #2021: nonexistent"; then
  fail "scenario 5: the archived dependency is falsely reported as nonexistent"
else
  pass "scenario 5: the archived dependency is never reported as nonexistent"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 6: candidate depends on a task number resolvable in neither active_projects[] nor the
# archive -- a genuinely absent target must still report loudly as nonexistent.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 6: a genuinely absent dependency still reports nonexistent"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2022, "project_name": "depends_on_absent", "task_type": "general", "status": "not_started", "description": "candidate #2022", "dependencies": [2023], "file_scope": ["lua/corge.lua"]}]}
EOF
write_archive_state <<'EOF'
{"completed_projects": [{"project_number": 2021, "project_name": "archived_dep", "status": "completed"}], "archived_projects": []}
EOF
run_sut -- 2022

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 6: SUT exits 0"
else
  fail "scenario 6: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "#2022 depends on #2023: nonexistent"; then
  pass "scenario 6: the genuinely absent dependency still reports nonexistent"
else
  fail "scenario 6: expected a nonexistent row for #2022/#2023; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 7: no specs/archive/state.json at all -- task_lookup_archived_projects_json's
# documented "[]" on-absent-archive contract; the SUT must still exit 0 and render Class A.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 7: no archive/state.json present -- SUT still exits 0 and renders Class A"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 2, "active_projects": [{"project_number": 2024, "project_name": "no_archive_file", "task_type": "general", "status": "not_started", "description": "candidate #2024", "dependencies": [], "file_scope": ["lua/grault.lua"]}]}
EOF
run_sut -- 2024

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 7: SUT exits 0 with no archive/state.json present"
else
  fail "scenario 7: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF -- "-- Class A: Dependency edge classification --"; then
  pass "scenario 7: Class A section still renders with no archive file present"
else
  fail "scenario 7: expected the Class A section header; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 8: Class F -- missing/null/empty file_scope on a batch candidate. The null-value
# candidate must ALSO still fire the pre-existing Class B line (both lines print; neither
# suppresses the other, per this class's own header record).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 8: Class F fires for missing/null/empty file_scope candidates; the null-value candidate also still fires Class B"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 4, "active_projects": [
  {"project_number": 3001, "project_name": "cand_missing", "task_type": "general", "status": "not_started", "description": "candidate #3001", "dependencies": []},
  {"project_number": 3002, "project_name": "cand_null", "task_type": "general", "status": "not_started", "description": "candidate #3002", "dependencies": [], "file_scope": null},
  {"project_number": 3003, "project_name": "cand_empty", "task_type": "general", "status": "not_started", "description": "candidate #3003", "dependencies": [], "file_scope": []}
]}
EOF
stub_admit <<'EOF'
{"decision":"admit","task_number":3001,"self_modifying":false}
{"decision":"admit","task_number":3002,"self_modifying":false}
{"decision":"admit","task_number":3003,"self_modifying":false}
EOF
run_sut --session-id sess_test_caller_f -- 3001 3002 3003

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 8: SUT exits 0"
else
  fail "scenario 8: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "#3001 (cand_missing): file_scope is missing_key"; then
  pass "scenario 8: Class F missing_key line rendered for candidate #3001"
else
  fail "scenario 8: expected Class F missing_key line for #3001; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "#3002 (cand_null): file_scope is null_value"; then
  pass "scenario 8: Class F null_value line rendered for candidate #3002"
else
  fail "scenario 8: expected Class F null_value line for #3002; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "#3003 (cand_empty): file_scope is empty_array"; then
  pass "scenario 8: Class F empty_array line rendered for candidate #3003"
else
  fail "scenario 8: expected Class F empty_array line for #3003; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF '#3002: field "file_scope" is null'; then
  pass "scenario 8: candidate #3002 still fires the pre-existing Class B line alongside Class F (neither suppresses the other)"
else
  fail "scenario 8: expected the Class B line for #3002 to still fire; got: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 9: Class G -- a glob-shaped file_scope entry on a batch candidate; a control candidate
# with a concrete entry must not fire.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 9: Class G fires for a glob-shaped file_scope entry; a concrete control candidate does not fire"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 3, "active_projects": [
  {"project_number": 3010, "project_name": "cand_glob", "task_type": "general", "status": "not_started", "description": "candidate #3010", "dependencies": [], "file_scope": ["*/agents/**"]},
  {"project_number": 3011, "project_name": "cand_plain", "task_type": "general", "status": "not_started", "description": "candidate #3011", "dependencies": [], "file_scope": ["lua/plain.lua"]}
]}
EOF
stub_admit <<'EOF'
{"decision":"admit","task_number":3010,"self_modifying":false}
{"decision":"admit","task_number":3011,"self_modifying":false}
EOF
run_sut --session-id sess_test_caller_g -- 3010 3011

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 9: SUT exits 0"
else
  fail "scenario 9: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if echo "$LAST_STDOUT" | grep -qF "#3010: entry */agents/** is invisible to overlap-based collision detection"; then
  pass "scenario 9: Class G fires for candidate #3010's glob-shaped entry"
else
  fail "scenario 9: expected the Class G line for #3010; got: $LAST_STDOUT"
fi
if echo "$LAST_STDOUT" | grep -qF "#3011: entry"; then
  fail "scenario 9: expected NO Class G line for control candidate #3011; got: $LAST_STDOUT"
else
  pass "scenario 9: control candidate #3011 (concrete entry) does not fire Class G"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Scenario 10: --repair D4 non-manufacture -- a candidate with an ABSENT file_scope key, named in
# the same --repair invocation as a candidate with a REAL literal null, must be left completely
# untouched. This also pins the bugfix discovered during this task's own verification: the
# pre-existing write filter used plain `.file_scope == null` (matching absent AND literal-null
# alike) rather than `has("file_scope") and .file_scope == null`, so a candidate sharing an
# invocation with a genuinely-null sibling had `file_scope: []` silently manufactured onto it.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Scenario 10: --repair leaves an absent file_scope key untouched even when a co-invoked sibling has a real literal null (D4)"
setup_sandbox
write_state <<'EOF'
{"next_project_number": 3, "active_projects": [
  {"project_number": 3020, "project_name": "cand_missing", "task_type": "general", "status": "not_started", "description": "candidate #3020", "dependencies": []},
  {"project_number": 3021, "project_name": "cand_null", "task_type": "general", "status": "not_started", "description": "candidate #3021", "dependencies": [], "file_scope": null}
]}
EOF
run_sut --repair --session-id sess_test_repair_d4 -- 3020 3021

if [ "$LAST_EXIT" -eq 0 ]; then
  pass "scenario 10: --repair exits 0"
else
  fail "scenario 10: --repair exited $LAST_EXIT ($LAST_STDERR)"
fi
repair_p3020_has_key=$(jq -r '.active_projects[] | select(.project_number==3020) | has("file_scope")' "$STATE_FILE" 2>/dev/null)
repair_p3021_fs=$(jq -c '.active_projects[] | select(.project_number==3021) | .file_scope' "$STATE_FILE" 2>/dev/null)
if [ "$repair_p3020_has_key" = "false" ]; then
  pass "scenario 10: candidate #3020's absent file_scope key was NOT manufactured (D4 holds)"
else
  fail "scenario 10: expected candidate #3020 to still lack a file_scope key; has(\"file_scope\")=$repair_p3020_has_key"
fi
if [ "$repair_p3021_fs" = "[]" ]; then
  pass "scenario 10: candidate #3021's genuine literal null was correctly repaired to []"
else
  fail "scenario 10: expected candidate #3021's file_scope to become []; got: $repair_p3021_fs"
fi

echo ""
echo "==================================================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "==================================================================="
[ "$FAILED" -eq 0 ]
