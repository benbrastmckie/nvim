#!/usr/bin/env bash
# test-task-lock-reap.sh - Isolated-temp-root suite proving task-lock.sh's `reap` contract.
#
# Never touches the real specs/ tree. Builds a throwaway root satisfying
# deploy-root-guard.sh's ".claude/scripts/ or .opencode/scripts/, two levels under root" check
# by copying the real task-lock.sh and deploy-root-guard.sh into $TMPROOT/.claude/scripts/,
# alongside a fixture $TMPROOT/specs/ tree with controlled holder.json timestamps (no sleeping).
# This is what makes an isolated temp root work with zero testability hooks added to production
# code -- task-lock.sh itself is copied byte-for-byte and never learns it is under test.
#
# Runnable directly from the source store (this file's own location) or from a deployed
# .claude/scripts/ copy -- either way it locates its sibling task-lock.sh/deploy-root-guard.sh
# by relative path and copies THOSE into the temp root; it never resolves its own PROJECT_ROOT
# via the SCRIPT_DIR/../.. convention deploy-root-guard.sh exists to protect, so it needs no
# guard of its own.
#
# See context/patterns/task-lock.md's "Reap Contract" section for the full subcommand contract
# this suite verifies.
#
# Exit 0 when all cases PASS, exit 1 when any case FAILS.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  FAILED=$((FAILED + 1))
}

info() {
  echo -e "${YELLOW}[INFO]${NC} $1"
}

# --- Locate the real task-lock.sh, deploy-root-guard.sh, and lib/common.sh to copy into the
# fixture ---
if [ ! -f "$SCRIPT_DIR/task-lock.sh" ] || [ ! -f "$SCRIPT_DIR/deploy-root-guard.sh" ] \
    || [ ! -f "$SCRIPT_DIR/lib/common.sh" ] || [ ! -f "$SCRIPT_DIR/lib/task-lookup-lib.sh" ]; then
  echo "ERROR: expected task-lock.sh, deploy-root-guard.sh, lib/common.sh, and lib/task-lookup-lib.sh alongside this script in $SCRIPT_DIR" >&2
  exit 1
fi

# --- Build the isolated temp root ---
TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/task-lock-reap-test.XXXXXX")"

cleanup() {
  [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"
}
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/archive"
cp "$SCRIPT_DIR/task-lock.sh" "$TMPROOT/.claude/scripts/task-lock.sh"
cp "$SCRIPT_DIR/deploy-root-guard.sh" "$TMPROOT/.claude/scripts/deploy-root-guard.sh"
cp "$SCRIPT_DIR/lib/common.sh" "$TMPROOT/.claude/scripts/lib/common.sh"
cp "$SCRIPT_DIR/lib/task-lookup-lib.sh" "$TMPROOT/.claude/scripts/lib/task-lookup-lib.sh"
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh"

TL="$TMPROOT/.claude/scripts/task-lock.sh"

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_holder_fixture() {
  # write_holder_fixture <lock_dir> <task_number> <session_id> <heartbeat_minutes_ago>
  local lock_dir="$1" task_number="$2" session_id="$3" mins_ago="$4"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$lock_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$task_number" \
    --arg operation "implement" \
    --arg ts "$ts" \
    --arg command "/implement $task_number" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $ts, heartbeat_at: $ts, command: $command}' \
    > "$lock_dir/holder.json"
}

write_corrupt_holder_fixture() {
  # write_corrupt_holder_fixture <lock_dir> <mtime_minutes_ago>
  local lock_dir="$1" mins_ago="$2" epoch
  mkdir -p "$lock_dir"
  echo "not valid json" > "$lock_dir/holder.json"
  epoch=$(( $(now_epoch) - (mins_ago * 60) ))
  touch -d "@$epoch" "$lock_dir"
}

# --- Fixture state.json ---
cat > "$TMPROOT/specs/state.json" << 'EOF'
{
  "next_project_number": 700,
  "active_projects": [
    {"project_number": 601, "project_name": "fresh_lock", "status": "implementing", "task_type": "general"},
    {"project_number": 602, "project_name": "stale_lock", "status": "implementing", "task_type": "general"},
    {"project_number": 604, "project_name": "corrupt_fresh", "status": "implementing", "task_type": "general"},
    {"project_number": 605, "project_name": "corrupt_stale", "status": "implementing", "task_type": "general"},
    {"project_number": 606, "project_name": "foreign_stale", "status": "implementing", "task_type": "general", "file_scope": ["specs/coordination"]},
    {"project_number": 607, "project_name": "acquire_probe", "status": "implementing", "task_type": "general", "file_scope": ["specs/coordination/topic.md"]}
  ]
}
EOF

# --- Fixture lock directories ---
FRESH_DIR="$TMPROOT/specs/601_fresh_lock/.lock"
STALE_DIR="$TMPROOT/specs/602_stale_lock/.lock"
ARCHIVE_DIR="$TMPROOT/specs/archive/603_archived_stale/.lock"
CORRUPT_FRESH_DIR="$TMPROOT/specs/604_corrupt_fresh/.lock"
CORRUPT_STALE_DIR="$TMPROOT/specs/605_corrupt_stale/.lock"
FOREIGN_STALE_DIR="$TMPROOT/specs/606_foreign_stale/.lock"

# TASK_LOCK_STALE_MIN=30, TASK_LOCK_REAP_MIN=120 (defaults; not overridden -- exercised at
# real production thresholds).
write_holder_fixture "$FRESH_DIR" 601 "sess_fixture_601" 0
write_holder_fixture "$STALE_DIR" 602 "sess_fixture_602" 200
write_holder_fixture "$ARCHIVE_DIR" 603 "sess_fixture_603" 300
write_corrupt_holder_fixture "$CORRUPT_FRESH_DIR" 5
write_corrupt_holder_fixture "$CORRUPT_STALE_DIR" 300
write_holder_fixture "$FOREIGN_STALE_DIR" 606 "sess_fixture_606" 200

info "Fixture built at $TMPROOT"

# =====================================================================
# Case C: --dry-run removes nothing (run FIRST, against the full fixture)
# =====================================================================
dry_run_out=$("$TL" reap --dry-run 2>&1)
dry_run_exit=$?

c_ok=true
[ "$dry_run_exit" -eq 0 ] || { c_ok=false; info "dry-run exit code was $dry_run_exit, expected 0"; }
for d in "$FRESH_DIR" "$STALE_DIR" "$ARCHIVE_DIR" "$CORRUPT_FRESH_DIR" "$CORRUPT_STALE_DIR" "$FOREIGN_STALE_DIR"; do
  [ -d "$d" ] || { c_ok=false; info "dry-run removed $d"; }
done
echo "$dry_run_out" | grep -qF "602_stale_lock" || { c_ok=false; info "dry-run output missing 602_stale_lock"; }
echo "$dry_run_out" | grep -q "would reap" || { c_ok=false; info "dry-run output missing 'would reap'"; }

if [ "$c_ok" = true ]; then
  pass "C: --dry-run reports would-reap candidates and removes nothing"
else
  fail "C: --dry-run case failed (see INFO lines above)"
fi

# =====================================================================
# Case D: acquire/check/heartbeat/release never implicitly reap
# =====================================================================
"$TL" check 606 >/dev/null 2>&1
"$TL" heartbeat 699 "sess_fixture_x" >/dev/null 2>&1
"$TL" acquire 607 "test" "sess_fixture_607" "/implement 607" >/dev/null 2>&1
"$TL" release 698 "sess_fixture_x" >/dev/null 2>&1

if [ -d "$FOREIGN_STALE_DIR" ]; then
  pass "D: acquire/check/heartbeat/release never implicitly reap a stale foreign lock"
else
  fail "D: stale foreign lock at $FOREIGN_STALE_DIR was removed by a non-reap subcommand"
fi

# =====================================================================
# Live reap: exercises cases A, B, E, and the archive depth-3 case
# =====================================================================
live_out=$("$TL" reap 2>&1)
live_exit=$?

# --- Case A: fresh lock NOT reaped, path absent from output ---
a_ok=true
[ "$live_exit" -eq 0 ] || { a_ok=false; info "live reap exit code was $live_exit, expected 0"; }
[ -d "$FRESH_DIR" ] || { a_ok=false; info "fresh lock $FRESH_DIR was reaped"; }
echo "$live_out" | grep -qF "601_fresh_lock" && { a_ok=false; info "fresh lock path 601_fresh_lock appeared in live output"; }

if [ "$a_ok" = true ]; then
  pass "A: fresh lock survives a live reap and its path is absent from output"
else
  fail "A: fresh-lock case failed (see INFO lines above)"
fi

# --- Case B: stale lock IS reaped AND reported (task number + age) ---
b_ok=true
[ -d "$STALE_DIR" ] && { b_ok=false; info "stale lock $STALE_DIR was NOT reaped"; }
echo "$live_out" | grep -qF "602_stale_lock" || { b_ok=false; info "live output missing 602_stale_lock path"; }
echo "$live_out" | grep -E "reaped:.*task=602.*age_min=[0-9]+" >/dev/null || { b_ok=false; info "live output missing task=602 with age_min for stale lock"; }

if [ "$b_ok" = true ]; then
  pass "B: stale lock is reaped and reported with task number and age"
else
  fail "B: stale-lock case failed (see INFO lines above)"
fi

# --- Case E: missing/corrupt holder.json skip-vs-reap branch ---
e_ok=true
[ -d "$CORRUPT_FRESH_DIR" ] || { e_ok=false; info "corrupt-fresh lock $CORRUPT_FRESH_DIR was incorrectly reaped"; }
echo "$live_out" | grep -qF "604_corrupt_fresh" || { e_ok=false; info "live output missing SKIP line for 604_corrupt_fresh"; }
echo "$live_out" | grep -E "SKIP:.*604_corrupt_fresh" >/dev/null || { e_ok=false; info "live output missing SKIP: prefix for 604_corrupt_fresh"; }
[ -d "$CORRUPT_STALE_DIR" ] && { e_ok=false; info "corrupt-stale lock $CORRUPT_STALE_DIR was NOT reaped despite an old directory mtime"; }
echo "$live_out" | grep -qF "605_corrupt_stale" || { e_ok=false; info "live output missing reaped line for 605_corrupt_stale"; }

if [ "$e_ok" = true ]; then
  pass "E: missing/corrupt holder.json is skipped when mtime-fresh and reaped when mtime-stale"
else
  fail "E: corrupt-holder skip-vs-reap case failed (see INFO lines above)"
fi

# --- Archive depth-3 case: proves the reaper does NOT reinherit find_held_locks()'s -maxdepth 2 ---
f_ok=true
[ -d "$ARCHIVE_DIR" ] && { f_ok=false; info "archived stale lock $ARCHIVE_DIR (depth 3) was NOT reaped"; }
echo "$live_out" | grep -E "reaped:.*archive/603_archived_stale.*task=603" >/dev/null || { f_ok=false; info "live output missing reaped line for depth-3 archive lock 603"; }

if [ "$f_ok" = true ]; then
  pass "F: depth-3 specs/archive/{N}_{slug}/.lock is found and reaped (proves -maxdepth 3, not 2)"
else
  fail "F: archive depth-3 case failed (see INFO lines above) -- reaper may have reinherited find_held_locks()'s -maxdepth 2"
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
