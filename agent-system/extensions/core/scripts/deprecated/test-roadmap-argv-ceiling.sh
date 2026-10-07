#!/usr/bin/env bash
# task-ref-ok:begin -- this entire file is a fixture/regression suite for
# roadmap-integration.sh, whose own domain vocabulary is the literal "(task N)" reference format
# it parses out of ROADMAP.md. Every "(task N)"/"task N" occurrence below is quoted test-fixture
# data or a comment describing that fixture data, not a live task-management-system citation --
# see .claude/context/standards/task-reference-exemptions.md category 6 (test fixtures for a
# reference-pattern detector) and category 3 (quoted historical anti-pattern), both of which this
# file's content matches.
#
# test-roadmap-argv-ceiling.sh - Isolated-temp-root suite proving roadmap-integration.sh's three
# fixes: the >128KB ROADMAP_MATCHES argv ceiling (final jq -n --slurpfile fix), --annotate
# atomicity via a staging copy (a forced mid-run failure leaves ROADMAP.md byte-identical), and
# the tightened explicit_task_ref heuristic (rejects a match when a sibling task reference is
# still non-terminal).
#
# Follows the state-write.sh isolated-temp-root suites' precedent: build a throwaway $TMPROOT,
# copy roadmap-integration.sh byte-for-byte (it is self-contained -- no sourced dependencies,
# just python3/jq on PATH), never touch the real specs/ tree, pass()/fail() counters, exit 0/1 on
# suite result. Deliberately does NOT use test-roadmap-items-producer.sh's "deployed tree first"
# resolution convention -- that would silently validate against the OLD, un-redeployed
# .claude/scripts/ copy instead of this task's source-store fix, which is exactly the live
# .claude/scripts/ tree this task must not touch or redeploy itself (redeploy is Phase 7's job).
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/../roadmap-integration.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAILED=$((FAILED + 1)); }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

if [ ! -f "$SOURCE_SCRIPT" ]; then
  echo "ERROR: expected roadmap-integration.sh alongside this suite's parent dir at $SOURCE_SCRIPT" >&2
  exit 2
fi

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/roadmap-argv-ceiling-test.XXXXXX")"
cleanup_root() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup_root EXIT

RI="$TMPROOT/roadmap-integration.sh"
cp "$SOURCE_SCRIPT" "$RI"
chmod +x "$RI"

# A second copy with a forced failure injected right after the report-building step begins (i.e.
# after the annotate loop has already run and mutated ANNOTATE_TARGET, but before the commit
# mv ANNOTATE_TARGET -> ROADMAP_PATH) -- used by Case B to prove atomicity under a real crash.
RI_BROKEN="$TMPROOT/roadmap-integration-broken.sh"
python3 - "$RI" "$RI_BROKEN" << 'PYEOF'
import sys
src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()
marker = '# ─── Build output JSON ────────────────────────────────────────────────────────'
assert marker in content, "marker not found -- roadmap-integration.sh structure changed"
injected = marker + '\n\necho "INJECTED TEST FAILURE" >&2\nexit 77\n'
content = content.replace(marker, injected, 1)
with open(dst, 'w') as f:
    f.write(content)
PYEOF
chmod +x "$RI_BROKEN"

info "Fixture root: $TMPROOT"

# Generate a JSON array payload of at least $1 bytes worth of table rows for a ROADMAP.md fixture,
# each row referencing a distinct completed task so it becomes a high-confidence match. Prints the
# row count used to stdout.
gen_large_roadmap_and_state() {
  local roadmap_out="$1" state_out="$2" min_matches_bytes="$3"
  python3 -c "
import json

roadmap_lines = ['# Roadmap', '', '## Phase 1: Large Fixture (High Priority)', '',
                  '| Component | Status | Location |', '|---|---|---|']
active_projects = []
i = 1
# Each row's Location cell carries a long synthetic path so raw_line (captured verbatim per
# match) is large -- mirrors the live repo's own ~20KB-per-match table rows.
long_suffix = 'x' * 400
while True:
    roadmap_lines.append(
        f'| Component{i} | Complete (task {i}) | /some/long/synthetic/path/component_{i}/{long_suffix}.md |'
    )
    active_projects.append({
        'project_number': i,
        'project_name': f'component_{i}',
        'status': 'completed',
        'description': f'Component {i} task',
        'completion_summary': 'done',
        'completion_date': '2026-01-01',
        'roadmap_items': []
    })
    # Rough estimate: stop once we likely have enough (checked precisely by the caller after a
    # real run, per the Scope Hypothesis -- measure, don't guess).
    if i * 500 > $min_matches_bytes:
        break
    i += 1

with open('$roadmap_out', 'w') as f:
    f.write('\n'.join(roadmap_lines) + '\n')

state = {'next_project_number': i + 1, 'active_projects': active_projects}
with open('$state_out', 'w') as f:
    json.dump(state, f)

print(i)
"
}

# =====================================================================
# Case A: a fixture ROADMAP.md large enough to push ROADMAP_MATCHES past 131,072 bytes; parse-only
# mode exits 0 with valid JSON (the exact shape that fails today with exit 126).
# =====================================================================
FIXDIR_A="$TMPROOT/case_a"
mkdir -p "$FIXDIR_A"
ROW_COUNT=$(gen_large_roadmap_and_state "$FIXDIR_A/ROADMAP.md" "$FIXDIR_A/state.json" 131072)
info "Case A fixture: $ROW_COUNT table rows"

"$RI" --roadmap "$FIXDIR_A/ROADMAP.md" --state "$FIXDIR_A/state.json" \
  > "$FIXDIR_A/output.json" 2> "$FIXDIR_A/stderr.log"
caseA_exit=$?

caseA_ok=true
[ "$caseA_exit" = "0" ] || { caseA_ok=false; info "Case A exited $caseA_exit (expected 0): $(tail -5 "$FIXDIR_A/stderr.log")"; }
if [ "$caseA_ok" = true ]; then
  jq empty "$FIXDIR_A/output.json" 2>/dev/null || { caseA_ok=false; info "Case A output is not valid JSON"; }
fi
if [ "$caseA_ok" = true ]; then
  matches_bytes=$(jq -c '.roadmap_matches' "$FIXDIR_A/output.json" | wc -c)
  info "Case A roadmap_matches serialized size: ${matches_bytes} bytes"
  [ "$matches_bytes" -gt 131072 ] || { caseA_ok=false; info "Case A fixture did not actually exceed the 131,072-byte ceiling -- test proves nothing, size by measurement not guess"; }
fi
if [ "$caseA_ok" = true ]; then
  keys=$(jq -S -c 'keys' "$FIXDIR_A/output.json")
  [ "$keys" = '["annotation_summary","roadmap_matches","roadmap_state","roadmap_structure","warnings"]' ] || { caseA_ok=false; info "Case A: unexpected top-level keys: $keys"; }
fi

if [ "$caseA_ok" = true ]; then
  pass "A: fixture with $ROW_COUNT table rows (roadmap_matches > 131,072 bytes) exits 0 in parse-only mode with valid JSON"
else
  fail "A: oversized-fixture parse-only case failed (see INFO lines above)"
fi

# =====================================================================
# Case B: atomicity -- run --annotate against the oversized fixture with an injected mid-run
# failure and assert the fixture ROADMAP.md is diff-identical to a pre-run copy.
# =====================================================================
FIXDIR_B="$TMPROOT/case_b"
mkdir -p "$FIXDIR_B"
gen_large_roadmap_and_state "$FIXDIR_B/ROADMAP.md" "$FIXDIR_B/state.json" 131072 > /dev/null
cp "$FIXDIR_B/ROADMAP.md" "$FIXDIR_B/ROADMAP.pre.md"
before_hash=$(md5sum "$FIXDIR_B/ROADMAP.md" | awk '{print $1}')

"$RI_BROKEN" --roadmap "$FIXDIR_B/ROADMAP.md" --state "$FIXDIR_B/state.json" --annotate \
  > "$FIXDIR_B/output.json" 2> "$FIXDIR_B/stderr.log"
caseB_exit=$?
after_hash=$(md5sum "$FIXDIR_B/ROADMAP.md" | awk '{print $1}')

caseB_ok=true
[ "$caseB_exit" = "77" ] || { caseB_ok=false; info "Case B: injected-failure run exited $caseB_exit (expected 77 -- the injected exit code); the failure injection may not have fired"; }
grep -q "Annotated" "$FIXDIR_B/stderr.log" || { caseB_ok=false; info "Case B: no annotations were logged before the injected failure -- fixture may not have any high-confidence matches to test with"; }
[ "$before_hash" = "$after_hash" ] || { caseB_ok=false; info "Case B: ROADMAP.md was mutated despite the mid-run failure (before=$before_hash after=$after_hash)"; }
diff -q "$FIXDIR_B/ROADMAP.pre.md" "$FIXDIR_B/ROADMAP.md" > /dev/null 2>&1 || { caseB_ok=false; info "Case B: ROADMAP.md diff is not empty"; }

if [ "$caseB_ok" = true ]; then
  pass "B: forced mid-run failure (after annotations already applied to the staging copy) leaves ROADMAP.md byte-identical"
else
  fail "B: atomicity forced-failure case failed (see INFO lines above)"
fi

# =====================================================================
# Case C: atomicity, success path -- a clean --annotate run applies all expected annotations in
# one final move.
# =====================================================================
FIXDIR_C="$TMPROOT/case_c"
mkdir -p "$FIXDIR_C"
cat > "$FIXDIR_C/ROADMAP.md" << 'EOF'
# Roadmap

## Phase 1: Small Success Fixture (High Priority)

- [ ] Pending item one (task 1)
- [ ] Pending item two (task 2)
EOF
cat > "$FIXDIR_C/state.json" << 'EOF'
{
  "next_project_number": 3,
  "active_projects": [
    {"project_number": 1, "project_name": "t1", "status": "completed", "description": "Task one", "completion_summary": "done", "completion_date": "2026-01-01", "roadmap_items": []},
    {"project_number": 2, "project_name": "t2", "status": "completed", "description": "Task two", "completion_summary": "done", "completion_date": "2026-01-02", "roadmap_items": []}
  ]
}
EOF

"$RI" --roadmap "$FIXDIR_C/ROADMAP.md" --state "$FIXDIR_C/state.json" --annotate \
  > "$FIXDIR_C/output.json" 2> "$FIXDIR_C/stderr.log"
caseC_exit=$?

caseC_ok=true
[ "$caseC_exit" = "0" ] || { caseC_ok=false; info "Case C exited $caseC_exit (expected 0): $(tail -5 "$FIXDIR_C/stderr.log")"; }
grep -qF -- '- [x] Pending item one (task 1) *(Completed: Task 1)*' "$FIXDIR_C/ROADMAP.md" || { caseC_ok=false; info "Case C: item one was not annotated"; }
grep -qF -- '- [x] Pending item two (task 2) *(Completed: Task 2)*' "$FIXDIR_C/ROADMAP.md" || { caseC_ok=false; info "Case C: item two was not annotated"; }
[ "$(jq '.annotation_summary.annotations_made' "$FIXDIR_C/output.json" 2>/dev/null)" = "2" ] || { caseC_ok=false; info "Case C: annotations_made != 2"; }

if [ "$caseC_ok" = true ]; then
  pass "C: clean --annotate run applies all expected annotations in one final move"
else
  fail "C: atomicity success-path case failed (see INFO lines above)"
fi

# =====================================================================
# Case D: heuristic -- the tightened explicit_task_ref heuristic's three fixture cases as
# assertions in this suite (matches only completed refs; rejected when any ref is non-terminal;
# rejected even when the non-terminal ref is not the first one, proving re.finditer is in effect).
# =====================================================================
FIXDIR_D="$TMPROOT/case_d"
mkdir -p "$FIXDIR_D"
cat > "$FIXDIR_D/ROADMAP.md" << 'EOF'
# Roadmap

## Phase 1: Heuristic Fixture (High Priority)

- [ ] Only completed refs (task 1)
- [ ] Completed and in-flight refs (task 1) and (task 2)
- [ ] Completed then later in-flight ref (task 1) and (task 3)
EOF
cat > "$FIXDIR_D/state.json" << 'EOF'
{
  "next_project_number": 4,
  "active_projects": [
    {"project_number": 1, "project_name": "done_task", "status": "completed", "description": "Done task", "completion_summary": "done", "completion_date": "2026-01-01", "roadmap_items": []},
    {"project_number": 2, "project_name": "inflight_task", "status": "implementing", "description": "In flight task"},
    {"project_number": 3, "project_name": "inflight_task_2", "status": "not_started", "description": "Another in flight task"}
  ]
}
EOF

"$RI" --roadmap "$FIXDIR_D/ROADMAP.md" --state "$FIXDIR_D/state.json" \
  > "$FIXDIR_D/output.json" 2> "$FIXDIR_D/stderr.log"
caseD_exit=$?

caseD_ok=true
[ "$caseD_exit" = "0" ] || { caseD_ok=false; info "Case D exited $caseD_exit (expected 0)"; }
if [ "$caseD_ok" = true ]; then
  explicit_matches=$(jq -c '[.roadmap_matches[] | select(.match_type == "explicit_task_ref" and .confidence == "high") | .roadmap_item]' "$FIXDIR_D/output.json")
  info "Case D explicit_task_ref high-confidence matches: $explicit_matches"
  echo "$explicit_matches" | jq -e 'length == 1' > /dev/null 2>&1 || { caseD_ok=false; info "Case D: expected exactly 1 high-confidence explicit_task_ref match (only the all-completed-refs item), got: $explicit_matches"; }
  echo "$explicit_matches" | jq -e '.[0] | contains("Only completed refs")' > /dev/null 2>&1 || { caseD_ok=false; info "Case D: the surviving match was not the all-completed-refs item"; }
fi

if [ "$caseD_ok" = true ]; then
  pass "D: explicit_task_ref matches only the all-completed-refs item; both mixed-reference items (including the later-non-terminal-ref case) are correctly rejected"
else
  fail "D: heuristic case failed (see INFO lines above)"
fi

# =====================================================================
# Case E: no temp-file leakage after each of the above (parse-only, --annotate success, --annotate
# forced failure).
# =====================================================================
FIXDIR_E="$TMPROOT/case_e"
mkdir -p "$FIXDIR_E"
cat > "$FIXDIR_E/ROADMAP.md" << 'EOF'
# Roadmap

## Phase 1: Leak Check (High Priority)

- [ ] Pending item (task 1)
EOF
cat > "$FIXDIR_E/state.json" << 'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {"project_number": 1, "project_name": "t1", "status": "completed", "description": "Task one", "completion_summary": "done", "completion_date": "2026-01-01", "roadmap_items": []}
  ]
}
EOF

"$RI" --roadmap "$FIXDIR_E/ROADMAP.md" --state "$FIXDIR_E/state.json" > /dev/null 2>&1
after_parseonly=$(find "$FIXDIR_E" -type f | sort)

cp "$FIXDIR_E/ROADMAP.md" "$FIXDIR_E/ROADMAP.md.bak"
"$RI" --roadmap "$FIXDIR_E/ROADMAP.md" --state "$FIXDIR_E/state.json" --annotate > /dev/null 2>&1
cp "$FIXDIR_E/ROADMAP.md.bak" "$FIXDIR_E/ROADMAP.md"
rm -f "$FIXDIR_E/ROADMAP.md.bak"
after_annotate=$(find "$FIXDIR_E" -type f | sort)

"$RI_BROKEN" --roadmap "$FIXDIR_E/ROADMAP.md" --state "$FIXDIR_E/state.json" --annotate > /dev/null 2>&1
after_broken=$(find "$FIXDIR_E" -type f | sort)

caseE_ok=true
# Only ROADMAP.md and state.json should exist before/after each run; no stray temp files under
# the fixture dir. Note: system /tmp mktemp files are outside FIXDIR_E and thus untracked by this
# check by design (the trap-based cleanup already covers those; this check is fixture-dir-scoped).
expected_after_parseonly="$FIXDIR_E/ROADMAP.md
$FIXDIR_E/state.json"
[ "$after_parseonly" = "$expected_after_parseonly" ] || { caseE_ok=false; info "Case E: unexpected files in fixture dir after parse-only run: $after_parseonly"; }
[ "$after_annotate" = "$expected_after_parseonly" ] || { caseE_ok=false; info "Case E: unexpected files in fixture dir after --annotate success run: $after_annotate"; }
[ "$after_broken" = "$expected_after_parseonly" ] || { caseE_ok=false; info "Case E: unexpected files in fixture dir after --annotate forced-failure run: $after_broken"; }

if [ "$caseE_ok" = true ]; then
  pass "E: no temp-file leakage in the fixture dir after parse-only, --annotate success, or --annotate forced-failure runs"
else
  fail "E: temp-file leakage case failed (see INFO lines above)"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
