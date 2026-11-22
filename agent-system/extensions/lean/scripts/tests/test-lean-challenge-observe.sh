#!/usr/bin/env bash
# test-lean-challenge-observe.sh -- hermetic, direct-invocation regression suite for
# lean-challenge-observe.sh. Modeled on
# agent-system/extensions/books/scripts/tests/test-books-observe.sh: pass/fail counters, a
# `mktemp -d` workdir with a `trap EXIT` cleanup, and a STUB snapshot script placed on the
# observer's own resolution path (`.claude/scripts/lean-challenge-snapshot.sh` relative to the
# observer's inherited working directory) so this suite never runs the real snapshot script and
# never performs a real git commit.
#
# Phase 3 extends this same file with the end-to-end resolution, inertness, non-blocking and CWD
# assertions driven by run-task-observers.sh --dry-run; this phase's own cases cover only the
# observer's direct-invocation status dispatch.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS="${SCRIPT_DIR}/../lean-challenge-observe.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -x "$OBS" ]]; then
  fail "prerequisite: $OBS is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

STUB_DIR="${WORKDIR}/.claude/scripts"
STUB="${STUB_DIR}/lean-challenge-snapshot.sh"
CALL_LOG="${WORKDIR}/stub-calls.log"
export CALL_LOG
mkdir -p "$STUB_DIR"

# A real git repo is not required: the observer's own resolution is relative-path-based against
# the inherited CWD, and the stub never shells out to git.
write_stub() {
  cat > "$STUB" <<'STUBEOF'
#!/usr/bin/env bash
# Records its full argv (one line, space-joined) to CALL_LOG, then exits STUB_EXIT_CODE
# (default 0). Never touches git or the filesystem beyond the log -- this is the hermetic stand-
# in the plan's Phase 1 calls for.
printf '%s\n' "$*" >> "$CALL_LOG"
exit "${STUB_EXIT_CODE:-0}"
STUBEOF
  chmod +x "$STUB"
}
write_stub

# run_observer TASK TASK_TYPE TOPIC TASK_DIR SESSION RESTING_STATUS
# Runs $OBS from $WORKDIR (so its relative .claude/scripts/ resolution hits the stub), discarding
# stdout, capturing stderr to a fresh temp file, and setting OBS_RC/OBS_STDERR for the caller.
run_observer() {
  local t="$1" ty="$2" tp="$3" td="$4" sess="$5" rs="$6"
  local stderr_file
  stderr_file="$(mktemp "${WORKDIR}/stderr.XXXXXX")"
  ( cd "$WORKDIR" && bash "$OBS" "$t" "$ty" "$tp" "$td" "$sess" "$rs" >/dev/null 2>"$stderr_file" )
  OBS_RC=$?
  OBS_STDERR="$stderr_file"
}

call_count() {
  [[ -f "$CALL_LOG" ]] || { echo 0; return; }
  wc -l < "$CALL_LOG" | tr -d ' '
}

reset_log() { rm -f "$CALL_LOG"; }

# ── Case 1: resting_status=planned invokes the snapshot WITHOUT --force ───────────────────────
reset_log
run_observer 451 lean4 "" specs/451_x sess1 planned
if [[ "$OBS_RC" -eq 0 ]]; then
  pass "planned: observer exits 0"
else
  fail "planned: observer exited ${OBS_RC}, expected 0"
fi
if [[ "$(call_count)" -eq 1 ]]; then
  pass "planned: snapshot invoked exactly once"
else
  fail "planned: snapshot invoked $(call_count) times, expected 1"
fi
if [[ -f "$CALL_LOG" ]] && ! grep -q -- '--force' "$CALL_LOG"; then
  pass "planned: invocation carries no --force"
else
  fail "planned: invocation unexpectedly carries --force (or log missing)"
fi
if [[ -f "$CALL_LOG" ]] && grep -qE '^451 \.$' "$CALL_LOG"; then
  pass "planned: invocation argv is exactly '451 .' (task_number then project_root)"
else
  fail "planned: invocation argv did not match '451 .' -- got: $(cat "$CALL_LOG" 2>/dev/null)"
fi

# ── Case 2: each implement-side status invokes the snapshot WITH --check ──────────────────────
for status in implementing partial pr_ready completed; do
  reset_log
  run_observer 451 lean4 "" specs/451_x sess1 "$status"
  if [[ "$OBS_RC" -eq 0 ]] && [[ "$(call_count)" -eq 1 ]] && grep -qE '^--check 451 \.$' "$CALL_LOG" 2>/dev/null; then
    pass "${status}: invokes --check exactly once with argv '--check 451 .'"
  else
    fail "${status}: expected one '--check 451 .' invocation and rc 0; got rc=${OBS_RC}, calls=$(call_count), log=$(cat "$CALL_LOG" 2>/dev/null)"
  fi
done

# ── Case 3: every other resting status is a no-op (zero invocations) ──────────────────────────
for status in researched planning blocked abandoned expanded not_started some_unknown_value; do
  reset_log
  run_observer 451 lean4 "" specs/451_x sess1 "$status"
  if [[ "$OBS_RC" -eq 0 ]] && [[ "$(call_count)" -eq 0 ]]; then
    pass "${status}: no-op, zero invocations, exits 0"
  else
    fail "${status}: expected zero invocations and rc 0; got rc=${OBS_RC}, calls=$(call_count)"
  fi
done

# ── Case 4: a stub exiting 73 (the real script's status-gate refusal code) still leaves the ───
# ── observer's own exit code at 0 -- the non-blocking contract. ───────────────────────────────
reset_log
STUB_EXIT_CODE=73 run_observer 451 lean4 "" specs/451_x sess1 planned
if [[ "$OBS_RC" -eq 0 ]]; then
  pass "stub-exit-73: observer still exits 0 (non-blocking)"
else
  fail "stub-exit-73: observer exited ${OBS_RC}, expected 0"
fi

# ── Case 5: a missing stub still leaves the observer's own exit code at 0, with zero attempted
# ── invocations and a stderr NOTE. ─────────────────────────────────────────────────────────────
reset_log
rm -f "$STUB"
run_observer 451 lean4 "" specs/451_x sess1 planned
if [[ "$OBS_RC" -eq 0 ]]; then
  pass "missing-stub: observer still exits 0 (non-blocking)"
else
  fail "missing-stub: observer exited ${OBS_RC}, expected 0"
fi
if [[ "$(call_count)" -eq 0 ]]; then
  pass "missing-stub: zero invocations attempted"
else
  fail "missing-stub: expected zero invocations, got $(call_count)"
fi
if grep -q "NOTE" "$OBS_STDERR" 2>/dev/null; then
  pass "missing-stub: stderr carries a NOTE"
else
  fail "missing-stub: stderr missing expected NOTE -- got: $(cat "$OBS_STDERR" 2>/dev/null)"
fi
write_stub

# ── Case 6: a non-executable stub also degrades to the same advisory no-op. ───────────────────
reset_log
chmod -x "$STUB"
run_observer 451 lean4 "" specs/451_x sess1 planned
if [[ "$OBS_RC" -eq 0 ]] && [[ "$(call_count)" -eq 0 ]]; then
  pass "non-executable-stub: observer exits 0 with zero invocations"
else
  fail "non-executable-stub: expected rc 0 and zero invocations; got rc=${OBS_RC}, calls=$(call_count)"
fi
chmod +x "$STUB"

# ── Case 7: the single-repo CWD assumption -- project_root is passed as '.' and the observer
# ── never cd's anywhere, so the invocation argv's project_root is literally '.', pinned here in
# ── a test rather than only in prose (per the plan's Decisions on `project_root`). ─────────────
reset_log
run_observer 451 lean4 "" specs/451_x sess1 planned
project_root_arg="$(awk '{print $NF}' "$CALL_LOG" 2>/dev/null)"
if [[ "$project_root_arg" == "." ]]; then
  pass "project_root: observer passes '.' and relies on its inherited working directory"
else
  fail "project_root: expected '.', got '${project_root_arg}'"
fi

# ── Case 8: a usage error (wrong argument count) in the observer's OWN arguments exits 2. ─────
( cd "$WORKDIR" && bash "$OBS" 451 lean4 "" specs/451_x sess1 >/dev/null 2>&1 )
usage_rc=$?
if [[ "$usage_rc" -eq 2 ]]; then
  pass "usage error: wrong argument count exits 2"
else
  fail "usage error: expected exit 2, got ${usage_rc}"
fi

# ── End-to-end resolution, inertness, non-blocking, and CWD assertions (driven by the deployed
# ── run-task-observers.sh, never --dry-run's own resolution logic in isolation) -- added once
# ── this observer is also registered in manifest.json and deployed, so resolution is real. ────
# A placeholder fixture identifier, never this record's own number -- resolution behavior does
# not depend on which number is used, and run-task-observers.sh's own task-dir argument need
# not resolve to a real directory for these cases (no filesystem check on it).
FIXTURE_ID="999"
FIXTURE_TASK_DIR="specs/${FIXTURE_ID}_lean_challenge_observe_fixture"

REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
RTO="${REPO_ROOT:-}/.claude/scripts/run-task-observers.sh"

if [[ -n "$REPO_ROOT" ]] && [[ -x "$RTO" ]]; then
  # ── Case 9: resolution -- lean4/planned resolves to exactly one lean-challenge-observe
  # ── match, matched_on=task_type. ───────────────────────────────────────────────────────────
  dryrun_out="$( ( cd "$REPO_ROOT" && bash "$RTO" --task "$FIXTURE_ID" --task-type lean4 --topic "" \
    --task-dir "$FIXTURE_TASK_DIR" --session plan-verify \
    --status planned --dry-run ) 2>&1 )"
  match_lines="$(printf '%s\n' "$dryrun_out" | grep -c 'would invoke observer lean-challenge-observe' || true)"
  if [[ "$match_lines" -eq 1 ]]; then
    pass "resolution: lean4/planned resolves to exactly one lean-challenge-observe match"
  else
    fail "resolution: expected exactly one match, got ${match_lines} -- output: ${dryrun_out}"
  fi
  if printf '%s\n' "$dryrun_out" | grep -q 'matched_on=task_type'; then
    pass "resolution: match is matched_on=task_type"
  else
    fail "resolution: expected matched_on=task_type -- output: ${dryrun_out}"
  fi

  # ── Case 10: inertness -- task_type=general and task_type=nix each resolve ZERO ───────────
  # ── lean-challenge-observe matches -- the observer is unreachable for a non-lean4 task. ────
  for tt in general nix; do
    inert_out="$( ( cd "$REPO_ROOT" && bash "$RTO" --task "$FIXTURE_ID" --task-type "$tt" --topic "" \
      --task-dir "$FIXTURE_TASK_DIR" --session plan-verify \
      --status planned --dry-run ) 2>&1 )"
    if printf '%s\n' "$inert_out" | grep -q 'lean-challenge-observe'; then
      fail "inertness: task_type=${tt} unexpectedly resolved lean-challenge-observe"
    else
      pass "inertness: task_type=${tt} resolves zero lean-challenge-observe matches"
    fi
  done
else
  info "SKIP resolution/inertness cases: ${RTO} not deployed or not executable (run deploy-headless.sh first)"
fi

# ── Non-blocking (fixture observer exits non-zero / hangs past timeout) and CWD pins, in an ───
# ── isolated scratch sandbox around the REAL run-task-observers.sh + its library collaborators
# ── -- modeled on agent-system/extensions/core/scripts/tests/test-run-task-observers.sh's own
# ── build_scratch/declare_observer pattern, scoped down to this observer's own registration. ──
RTO_LIB_DIR="${REPO_ROOT:-}/.claude/scripts"
if [[ -n "$REPO_ROOT" ]] && [[ -x "${RTO_LIB_DIR}/run-task-observers.sh" ]] \
    && [[ -f "${RTO_LIB_DIR}/lib/common.sh" ]] && [[ -f "${RTO_LIB_DIR}/lib/manifest-routing-lib.sh" ]]; then
  NB_SCRATCH="$(mktemp -d "${WORKDIR}/nb-scratch.XXXXXX")"
  mkdir -p "${NB_SCRATCH}/.claude/scripts/lib" "${NB_SCRATCH}/.claude/extensions/lean" "${NB_SCRATCH}/specs/fixture_demo_task"
  cp "${RTO_LIB_DIR}/run-task-observers.sh" "${NB_SCRATCH}/.claude/scripts/run-task-observers.sh"
  cp "${RTO_LIB_DIR}/events-append.sh" "${NB_SCRATCH}/.claude/scripts/events-append.sh"
  cp "${RTO_LIB_DIR}/deploy-root-guard.sh" "${NB_SCRATCH}/.claude/scripts/deploy-root-guard.sh"
  cp "${RTO_LIB_DIR}/lib/common.sh" "${NB_SCRATCH}/.claude/scripts/lib/common.sh"
  cp "${RTO_LIB_DIR}/lib/manifest-routing-lib.sh" "${NB_SCRATCH}/.claude/scripts/lib/manifest-routing-lib.sh"
  chmod +x "${NB_SCRATCH}/.claude/scripts/run-task-observers.sh" "${NB_SCRATCH}/.claude/scripts/events-append.sh"
  : > "${NB_SCRATCH}/specs/fixture_demo_task/issues.jsonl"
  : > "${NB_SCRATCH}/specs/fixture_demo_task/metrics.jsonl"

  write_nb_manifest() {
    local to="$1"
    printf '{"name": "lean", "observers": {"lean-challenge-observe": {"script": "scripts/lean-challenge-observe.sh", "task_type": "lean4", "timeout_seconds": %s}}}\n' "$to" \
      > "${NB_SCRATCH}/.claude/extensions/lean/manifest.json"
  }

  run_nb_rto() {
    ( cd "${NB_SCRATCH}" && bash .claude/scripts/run-task-observers.sh \
      --task "$FIXTURE_ID" --task-type lean4 --topic "" --task-dir specs/fixture_demo_task \
      --session nb-sess --status planned )
  }

  # ── Case 11: a fixture observer forced to exit non-zero still leaves ───────────────────────
  # ── run-task-observers.sh exiting 0. ────────────────────────────────────────────────────────
  write_nb_manifest 10
  printf '#!/usr/bin/env bash\nexit 7\n' > "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  chmod +x "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  run_nb_rto >/dev/null 2>&1
  nb_rc=$?
  if [[ "$nb_rc" -eq 0 ]]; then
    pass "non-blocking: a fixture observer exiting 7 still leaves run-task-observers.sh at rc 0"
  else
    fail "non-blocking: run-task-observers.sh exited ${nb_rc}, expected 0"
  fi

  # ── Case 12: a fixture observer hanging past its (short) timeout_seconds is killed, and ────
  # ── run-task-observers.sh still exits 0, within a bounded wall-clock margin. ────────────────
  write_nb_manifest 1
  printf '#!/usr/bin/env bash\nsleep 30\nexit 0\n' > "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  chmod +x "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  start_ts=$(date +%s)
  run_nb_rto >/dev/null 2>&1
  nb_rc=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  if [[ "$nb_rc" -eq 0 ]] && [[ "$elapsed" -lt 20 ]]; then
    pass "non-blocking: a fixture observer hanging past its 1s timeout is killed (elapsed=${elapsed}s) and run-task-observers.sh still exits 0"
  else
    fail "non-blocking: expected rc 0 and elapsed <20s, got rc=${nb_rc} elapsed=${elapsed}s"
  fi

  # ── Case 13: CWD pin -- the observer is invoked with CWD == the scratch root (the repo ────
  # ── root that owns specs/), never .claude/scripts/ or anywhere else. ────────────────────────
  write_nb_manifest 10
  cwd_seen_file="${NB_SCRATCH}/cwd-seen.txt"
  printf '#!/usr/bin/env bash\npwd > %q\nexit 0\n' "$cwd_seen_file" > "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  chmod +x "${NB_SCRATCH}/.claude/scripts/lean-challenge-observe.sh"
  run_nb_rto >/dev/null 2>&1
  seen_cwd="$(cat "$cwd_seen_file" 2>/dev/null || echo "")"
  resolved_scratch="$(cd "$NB_SCRATCH" && pwd)"
  if [[ "$seen_cwd" == "$resolved_scratch" ]]; then
    pass "CWD: the observer inherits the repo root as its working directory (${seen_cwd})"
  else
    fail "CWD: expected '${resolved_scratch}', observer saw '${seen_cwd}'"
  fi
else
  info "SKIP non-blocking/CWD scratch cases: run-task-observers.sh collaborators not resolvable from ${REPO_ROOT:-<unresolved>}"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[[ "$FAILED" -eq 0 ]]
