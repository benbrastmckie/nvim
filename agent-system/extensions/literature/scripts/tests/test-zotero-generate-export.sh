#!/usr/bin/env bash
# test-zotero-generate-export.sh - Regression and scenario tests for
# zotero-generate-export.sh's Path 1 (Zotero local API pull, temp-file accumulator,
# Total-Results-driven pagination, authoritative itemType filter), the content-keyed shrink
# guard, and Path 3's corrected itemTypeID exclusion set. Driven entirely by the
# PATH-shadowing curl-stub.sh (Zotero local-API routes) and generate-zotero-sqlite-fixture.sh
# (Path 3), both in this same directory. No real network access, no running Zotero, and no
# read of the user's actual $LITERATURE_DIR/zotero-library.json is used or required.
#
# Scenarios (pass one or more names as argv; default is "all"):
#   boundary-128kib        - a single page's byte size crosses 131072 bytes and the full
#                             synthetic library still exports completely (the accumulator
#                             never transits argv)
#   short-mid-page          - a mid-library window whose csljson body is shorter than `limit`
#                             (annotations silently dropped) still reaches the true end,
#                             driven by Total-Results, not page length
#   loud-fail-transport     - a mid-sweep curl transport failure aborts non-zero with the
#                             pre-existing output file byte-unchanged
#   loud-fail-malformed     - a mid-sweep malformed JSON body aborts non-zero, file unchanged
#   itemtype-exclusion      - a synthetic mix of attachment/note/annotation items yields NO
#                             excluded key in the written export
#   stub-dispatch           - a BBT-RPC URL is never served an items body (shared host:port
#                             regression guard)
#   shrink-guard-blocks     - a dramatically smaller candidate is blocked (distinct exit code,
#                             file unchanged, diagnostic names --allow-shrink)
#   shrink-guard-optout     - same scenario with --allow-shrink: exits 0, smaller file written
#   shrink-guard-no-baseline - no existing export/stamp: exits 0, writes, logs not-applicable
#   path3-itemtype          - fetch_path3() over a fixture sqlite db excludes
#                             attachment/note/annotation by NAME, not by stale numeric ID
#   pre-existing-suite      - the pre-existing test-literature-discover-tier3.sh suite (which
#                             shares this stub) still passes unmodified
#
# Usage:
#   test-zotero-generate-export.sh [scenario ...]
#
# Exit codes: 0 - all run scenarios passed; 1 - a scenario failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
GENERATOR_SH="$SCRIPT_DIR/zotero-generate-export.sh"
CURL_STUB="$TESTS_DIR/curl-stub.sh"
SQLITE_FIXTURE_GEN="$TESTS_DIR/generate-zotero-sqlite-fixture.sh"

PASS=0
FAIL=0

t_log() { echo "[test-zotero-export] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -f "$GENERATOR_SH" ]; then
  t_log "zotero-generate-export.sh not found at $GENERATOR_SH"
  exit 1
fi

# ---------------------------------------------------------------------------
# Scratch PATH dir with curl-stub.sh SYMLINKED (not copied) as `curl` -- a symlink lets the
# stub's own readlink -f self-location still find its sibling generator/fixtures. Every test
# also gets its own scratch output dir so no test can ever touch the real $LITERATURE_DIR.
# ---------------------------------------------------------------------------
STUB_PATH_DIR="$(mktemp -d)"
ln -s "$CURL_STUB" "$STUB_PATH_DIR/curl"

cleanup() {
  rm -rf "$STUB_PATH_DIR"
}
trap cleanup EXIT

# run_export [env_vars...] -- ARGS... -- invokes zotero-generate-export.sh with the stub first
# on PATH, ZOTERO_SQLITE_PATH pointed at a nonexistent path by default (forcing Path 1 or the
# no-data-source branch, never an accidental real Path 3), and a fresh scratch ZOTERO_LIBRARY
# unless the caller already exported one. Sets globals: OUT_FILE, ERR, RC.
SCRATCH_COUNTER=0
run_export() {
  local envs=()
  while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do
    envs+=("$1")
    shift
  done
  shift  # consume the "--"

  SCRATCH_COUNTER=$((SCRATCH_COUNTER + 1))
  local scratch_dir="$STUB_PATH_DIR/scratch_${SCRATCH_COUNTER}"
  mkdir -p "$scratch_dir"
  if [ -z "${OUT_FILE:-}" ] || [ "${OUT_FILE_AUTO:-1}" = "1" ]; then
    OUT_FILE="$scratch_dir/zotero-library.json"
    OUT_FILE_AUTO=1
  fi

  local err rc
  err="$(mktemp)"
  PATH="$STUB_PATH_DIR:$PATH" ZOTERO_SQLITE_PATH="${ZOTERO_SQLITE_PATH:-/nonexistent/zotero.sqlite}" \
    ZOTERO_LIBRARY="$OUT_FILE" \
    env "${envs[@]}" "$GENERATOR_SH" "$@" >/dev/null 2>"$err"
  rc=$?
  ERR="$(cat "$err")"
  RC=$rc
  rm -f "$err"
}

reset_scratch() {
  OUT_FILE=""
  OUT_FILE_AUTO=1
}

# ---------------------------------------------------------------------------
# boundary-128kib
# ---------------------------------------------------------------------------
t_boundary_128kib() {
  reset_scratch
  run_export CURL_STUB_ZOTERO_TOTAL=500 CURL_STUB_ZOTERO_PAD_BYTES=2000 -- --orchestrator-mode true
  if [ "$RC" -ne 0 ]; then
    t_fail "boundary-128kib: export failed (rc=$RC): $ERR"
    return
  fi
  local size count
  size="$(stat -c %s "$OUT_FILE" 2>/dev/null || echo 0)"
  count="$(jq 'length' "$OUT_FILE" 2>/dev/null || echo 0)"
  if [ "$size" -le 131072 ]; then
    t_fail "boundary-128kib: output size ($size bytes) did not cross the 131072-byte boundary -- test is not exercising it"
    return
  fi
  # ratio 10 default: 500 items -> 50 annotations dropped, 50 attachment + 50 note excluded by
  # itemType filter -> 350 true bibliographic entries.
  if [ "$count" -eq 350 ]; then
    t_pass "boundary-128kib: output size $size bytes crossed the boundary, item count $count matches the full synthetic library exactly (no loss)"
  else
    t_fail "boundary-128kib: expected 350 items, got $count"
  fi
}

# ---------------------------------------------------------------------------
# short-mid-page
# ---------------------------------------------------------------------------
t_short_mid_page() {
  reset_scratch
  run_export CURL_STUB_ZOTERO_TOTAL=4042 -- --orchestrator-mode true
  if [ "$RC" -ne 0 ]; then
    t_fail "short-mid-page: export failed (rc=$RC): $ERR"
    return
  fi
  local count
  count="$(jq 'length' "$OUT_FILE" 2>/dev/null || echo 0)"
  # ratio 10 default over 4042 items: floor-based counts computed the same way the generator
  # assigns type by (index % 10); bibliographic = indices where (i%10) not in (0,1,2).
  local expected
  expected="$(python3 -c "print(sum(1 for i in range(4042) if i % 10 not in (0,1,2)))")"
  if [ "$count" = "$expected" ]; then
    t_pass "short-mid-page: 4042-item library (with mid-sweep short csljson pages from dropped annotations) reached the true end, item count $count matches expected $expected"
  else
    t_fail "short-mid-page: expected $expected items, got $count -- pagination stopped early or over-collected"
  fi
}

# ---------------------------------------------------------------------------
# loud-fail-transport
# ---------------------------------------------------------------------------
t_loud_fail_transport() {
  reset_scratch
  local scratch_dir="$STUB_PATH_DIR/preexisting_transport"
  mkdir -p "$scratch_dir"
  OUT_FILE="$scratch_dir/zotero-library.json"
  OUT_FILE_AUTO=0
  echo '[{"pre":"existing"}]' > "$OUT_FILE"
  local before after
  before="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  run_export CURL_STUB_ZOTERO_TOTAL=500 CURL_STUB_ZOTERO_FAIL_AT=300 -- --orchestrator-mode true --force
  after="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  if [ "$RC" -eq 0 ]; then
    t_fail "loud-fail-transport: expected non-zero exit on mid-sweep transport failure, got 0"
    return
  fi
  if [ "$before" != "$after" ]; then
    t_fail "loud-fail-transport: output file changed despite the fetch failure"
    return
  fi
  t_pass "loud-fail-transport: mid-sweep transport failure aborted (rc=$RC), output file byte-unchanged"
}

# ---------------------------------------------------------------------------
# loud-fail-malformed
# ---------------------------------------------------------------------------
t_loud_fail_malformed() {
  reset_scratch
  local scratch_dir="$STUB_PATH_DIR/preexisting_malformed"
  mkdir -p "$scratch_dir"
  OUT_FILE="$scratch_dir/zotero-library.json"
  OUT_FILE_AUTO=0
  echo '[{"pre":"existing"}]' > "$OUT_FILE"
  local before after
  before="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  run_export CURL_STUB_ZOTERO_TOTAL=500 CURL_STUB_ZOTERO_MALFORMED_AT=200 -- --orchestrator-mode true --force
  after="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  if [ "$RC" -eq 0 ]; then
    t_fail "loud-fail-malformed: expected non-zero exit on mid-sweep malformed JSON, got 0"
    return
  fi
  if [ "$before" != "$after" ]; then
    t_fail "loud-fail-malformed: output file changed despite the malformed body"
    return
  fi
  t_pass "loud-fail-malformed: mid-sweep malformed JSON aborted (rc=$RC), output file byte-unchanged"
}

# ---------------------------------------------------------------------------
# itemtype-exclusion
# ---------------------------------------------------------------------------
t_itemtype_exclusion() {
  reset_scratch
  run_export CURL_STUB_ZOTERO_TOTAL=200 -- --orchestrator-mode true
  if [ "$RC" -ne 0 ]; then
    t_fail "itemtype-exclusion: export failed (rc=$RC): $ERR"
    return
  fi
  local doc_count
  doc_count="$(jq '[.[] | select(.type == "document")] | length' "$OUT_FILE" 2>/dev/null || echo -1)"
  if [ "$doc_count" -eq 0 ]; then
    t_pass "itemtype-exclusion: no CSL type=document (attachment/note-derived) entries survived in the written export"
  else
    t_fail "itemtype-exclusion: $doc_count document-typed entries leaked into the written export"
  fi
}

# ---------------------------------------------------------------------------
# stub-dispatch
# ---------------------------------------------------------------------------
t_stub_dispatch() {
  local log
  log="$(mktemp)"
  local items_body rpc_body
  items_body="$(PATH="$STUB_PATH_DIR:$PATH" CURL_STUB_LOG="$log" CURL_STUB_ZOTERO_TOTAL=5 \
    curl -s "http://127.0.0.1:23119/api/users/0/items?format=csljson&limit=100&start=0")"
  rpc_body="$(PATH="$STUB_PATH_DIR:$PATH" CURL_STUB_LOG="$log" \
    curl -s -X POST -d '{}' "http://localhost:23119/better-bibtex/json-rpc")"
  rm -f "$log"

  if echo "$items_body" | jq -e 'type == "array"' >/dev/null 2>&1 && [ "$rpc_body" = '{"result":{}}' ]; then
    t_pass "stub-dispatch: items URL served an array body, BBT-RPC URL served its own distinct body (never an items array)"
  else
    t_fail "stub-dispatch: items_body='$items_body' rpc_body='$rpc_body' -- one route served the other's body"
  fi
}

# ---------------------------------------------------------------------------
# shrink-guard-blocks / shrink-guard-optout / shrink-guard-no-baseline
# ---------------------------------------------------------------------------
_seed_large_baseline() {
  local dir="$1"
  mkdir -p "$dir"
  OUT_FILE="$dir/zotero-library.json"
  OUT_FILE_AUTO=0
  jq -n '[range(4000) | {id: ("x" + (. | tostring)), title: "x"}]' > "$OUT_FILE"
  jq -n --argjson count 4000 \
    '{"_generated":"2026-01-01T00:00:00Z","source":"sqlite-reconstruction","source_path":"/x","item_count":$count}' \
    > "$dir/.zotero-library.meta.json"
}

t_shrink_guard_blocks() {
  reset_scratch
  local dir="$STUB_PATH_DIR/shrink_blocks"
  _seed_large_baseline "$dir"
  local before after
  before="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  run_export CURL_STUB_ZOTERO_TOTAL=500 -- --orchestrator-mode true --force
  after="$(md5sum "$OUT_FILE" | awk '{print $1}')"

  if [ "$RC" -eq 0 ] || [ "$RC" -eq 3 ]; then
    t_fail "shrink-guard-blocks: expected a distinct non-zero, non-3 exit code, got $RC"
    return
  fi
  if [ "$before" != "$after" ]; then
    t_fail "shrink-guard-blocks: output file changed despite the shrink guard"
    return
  fi
  if ! echo "$ERR" | grep -q -- "--allow-shrink"; then
    t_fail "shrink-guard-blocks: diagnostic did not name --allow-shrink: $ERR"
    return
  fi
  t_pass "shrink-guard-blocks: blocked with distinct exit code $RC, file unchanged, diagnostic names --allow-shrink"
}

t_shrink_guard_optout() {
  reset_scratch
  local dir="$STUB_PATH_DIR/shrink_optout"
  _seed_large_baseline "$dir"

  run_export CURL_STUB_ZOTERO_TOTAL=500 -- --orchestrator-mode true --force --allow-shrink
  if [ "$RC" -ne 0 ]; then
    t_fail "shrink-guard-optout: expected exit 0 with --allow-shrink, got $RC: $ERR"
    return
  fi
  local count
  count="$(jq 'length' "$OUT_FILE" 2>/dev/null || echo -1)"
  if [ "$count" -eq 350 ]; then
    t_pass "shrink-guard-optout: --allow-shrink bypassed the guard, smaller file ($count items) written"
  else
    t_fail "shrink-guard-optout: expected 350 items after opt-out, got $count"
  fi
}

t_shrink_guard_no_baseline() {
  reset_scratch
  run_export CURL_STUB_ZOTERO_TOTAL=500 -- --orchestrator-mode true
  if [ "$RC" -ne 0 ]; then
    t_fail "shrink-guard-no-baseline: expected exit 0 with no prior export, got $RC: $ERR"
    return
  fi
  if ! echo "$ERR" | grep -qi "not applicable"; then
    t_fail "shrink-guard-no-baseline: expected a 'not applicable' log line, got: $ERR"
    return
  fi
  local count
  count="$(jq 'length' "$OUT_FILE" 2>/dev/null || echo -1)"
  if [ "$count" -eq 350 ]; then
    t_pass "shrink-guard-no-baseline: no prior export/stamp -> proceeded, logged not-applicable, wrote $count items"
  else
    t_fail "shrink-guard-no-baseline: expected 350 items, got $count"
  fi
}

# ---------------------------------------------------------------------------
# path3-itemtype
# ---------------------------------------------------------------------------
t_path3_itemtype() {
  local db
  db="$(mktemp -u).sqlite"
  bash "$SQLITE_FIXTURE_GEN" "$db" --bib 10 --attachment 3 --note 2 --annotation 4 >/dev/null 2>&1

  reset_scratch
  local dir="$STUB_PATH_DIR/path3_itemtype"
  mkdir -p "$dir"
  OUT_FILE="$dir/zotero-library.json"
  OUT_FILE_AUTO=0

  local err rc
  err="$(mktemp)"
  # Force the Zotero local-API probe to look unreachable so this scenario actually exercises
  # Path 3 (sqlite reconstruction) rather than the stub's default-200 Path 1.
  PATH="$STUB_PATH_DIR:$PATH" CURL_STUB_ZOTERO_API_CODE="000" \
    ZOTERO_SQLITE_PATH="$db" ZOTERO_LIBRARY="$OUT_FILE" \
    "$GENERATOR_SH" --orchestrator-mode true >/dev/null 2>"$err"
  rc=$?
  ERR="$(cat "$err")"
  rm -f "$err" "$db"

  if [ "$rc" -ne 0 ]; then
    t_fail "path3-itemtype: export failed (rc=$rc): $ERR"
    return
  fi
  local count
  count="$(jq 'length' "$OUT_FILE" 2>/dev/null || echo -1)"
  if [ "$count" -eq 10 ]; then
    t_pass "path3-itemtype: fixture sqlite db (10 bib + 3 attachment + 2 note + 4 annotation) yielded exactly 10 bibliographic items"
  else
    t_fail "path3-itemtype: expected 10 items, got $count"
  fi
}

# ---------------------------------------------------------------------------
# pre-existing-suite
# ---------------------------------------------------------------------------
t_pre_existing_suite() {
  if bash "$TESTS_DIR/test-literature-discover-tier3.sh" >/tmp/tier3-rerun-out.$$ 2>&1; then
    t_pass "pre-existing-suite: test-literature-discover-tier3.sh still passes unmodified"
  else
    t_fail "pre-existing-suite: test-literature-discover-tier3.sh failed after the curl-stub.sh changes"
    tail -20 /tmp/tier3-rerun-out.$$ >&2
  fi
  rm -f /tmp/tier3-rerun-out.$$
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
declare -A SCENARIOS=(
  [boundary-128kib]=t_boundary_128kib
  [short-mid-page]=t_short_mid_page
  [loud-fail-transport]=t_loud_fail_transport
  [loud-fail-malformed]=t_loud_fail_malformed
  [itemtype-exclusion]=t_itemtype_exclusion
  [stub-dispatch]=t_stub_dispatch
  [shrink-guard-blocks]=t_shrink_guard_blocks
  [shrink-guard-optout]=t_shrink_guard_optout
  [shrink-guard-no-baseline]=t_shrink_guard_no_baseline
  [path3-itemtype]=t_path3_itemtype
  [pre-existing-suite]=t_pre_existing_suite
)

ORDER=(boundary-128kib short-mid-page loud-fail-transport loud-fail-malformed \
  itemtype-exclusion stub-dispatch shrink-guard-blocks shrink-guard-optout \
  shrink-guard-no-baseline path3-itemtype pre-existing-suite)

if [ "$#" -eq 0 ] || [ "$1" = "all" ]; then
  TO_RUN=("${ORDER[@]}")
else
  TO_RUN=("$@")
fi

for name in "${TO_RUN[@]}"; do
  fn="${SCENARIOS[$name]:-}"
  if [ -z "$fn" ]; then
    t_log "unknown scenario: $name"
    FAIL=$((FAIL + 1))
    continue
  fi
  "$fn"
done

t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
