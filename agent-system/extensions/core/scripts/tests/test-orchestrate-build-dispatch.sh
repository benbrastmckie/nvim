#!/usr/bin/env bash
# test-orchestrate-build-dispatch.sh - Fixture suite for orchestrate-build-dispatch.sh, proving
# the generated per-dispatch context file carries every input the inline Stage 3.5 recipe it
# replaces would have interpolated, that the four optional blocks are skipped (never emitted
# empty) when their gate is off, and that the continuation-pointer resolution it shares with
# orchestrate-triage-classify.sh cannot silently drift back into two copies.
#
# Structural model: test-skill-base-lifecycle.sh / test-validate-return-meta.sh (mktemp -d
# WORKDIR with an EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate
# resolution, pass()/fail()/info() helpers with integer counters, exit 0 all-pass / 1 any-fail /
# 2 environment error).
#
# ISOLATION CONTRACT (never touches the real specs/ tree or real state.json): the SUT
# (orchestrate-build-dispatch.sh) is invoked as a subprocess with SKILL_REPO_ROOT exported to a
# scratch fixture directory under WORKDIR. skill-base.sh's own `SKILL_REPO_ROOT="${SKILL_REPO_ROOT
# :-...}"` line honors an already-exported value rather than recomputing it, so `cd
# "$SKILL_REPO_ROOT"` inside the SUT lands in the fixture, and every bare-relative path the SUT's
# collaborators use (specs/state.json, specs/{padded}_{project}/...) resolves there -- never
# against the real repo. The SUT's own three `${SKILL_REPO_ROOT}/.claude/scripts/*.sh` calls
# (memory-retrieve.sh, literature-lit-flag-resolve.sh, literature-briefing-invoke.sh) are pointed
# at deterministic STUBS installed in the fixture, so this suite is immune to the real memory
# vault's contents and the real (or absent) Literature corpus -- what is under test is the SUT's
# OWN gating/branching logic, not those collaborators' real behavior. The SUT's `source
# "${SCRIPT_DIR}/skill-base.sh"` / `lib/manifest-routing-lib.sh` / `lib/continuation-pointer-lib.sh`
# lines are NOT overridden -- they resolve to the real, deployed (or source-store) copies
# alongside the SUT itself, which is exactly what should be under test.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the SUT
# or a required library was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

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

SUT="$(resolve_candidate "orchestrate-build-dispatch.sh" \
  "$REPO_ROOT/.claude/scripts/orchestrate-build-dispatch.sh" \
  "$SCRIPT_DIR/../orchestrate-build-dispatch.sh")" || exit 2
TRIAGE_CLASSIFY="$(resolve_candidate "orchestrate-triage-classify.sh" \
  "$REPO_ROOT/.claude/scripts/orchestrate-triage-classify.sh" \
  "$SCRIPT_DIR/../orchestrate-triage-classify.sh")" || exit 2
CONT_LIB="$(resolve_candidate "continuation-pointer-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/continuation-pointer-lib.sh" \
  "$SCRIPT_DIR/../lib/continuation-pointer-lib.sh")" || exit 2

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

FIXTURE="$WORKDIR/fixture-repo"
TASK_NUM=999
PADDED="999"
PROJECT="fixture_task"
TASK_DIR_REL="specs/${PADDED}_${PROJECT}"

# ─── Fixture repo construction ──────────────────────────────────────────────────────────────────
# Only the three SKILL_REPO_ROOT-qualified collaborator scripts need fixture stubs (see the
# ISOLATION CONTRACT above); skill-base.sh, manifest-routing-lib.sh, and continuation-pointer-lib.sh
# are the SUT's own real, unmodified neighbors and are never copied into the fixture.
build_fixture() {
  mkdir -p "$FIXTURE/.claude/scripts" "$FIXTURE/${TASK_DIR_REL}/plans" "$FIXTURE/${TASK_DIR_REL}/reports"

  cat > "$FIXTURE/specs/state.json" <<EOF
{
  "active_projects": [
    {
      "project_number": ${TASK_NUM},
      "project_name": "${PROJECT}",
      "task_type": "general",
      "status": "researched",
      "description": "Fixture task description for orchestrate-build-dispatch.sh test suite -- exercises every gatherer.",
      "next_artifact_number": 2,
      "artifacts": [
        {"type": "report", "path": "${TASK_DIR_REL}/reports/01_fixture-report.md", "summary": "fixture report"}
      ]
    }
  ]
}
EOF

  printf '# Fixture report\n' > "$FIXTURE/${TASK_DIR_REL}/reports/01_fixture-report.md"
  printf '# Fixture plan\n\n### Phase 1: Fixture phase [NOT STARTED]\n' > "$FIXTURE/${TASK_DIR_REL}/plans/01_fixture-plan.md"

  # STUB: memory-retrieve.sh -- unconditionally emits a marker, ignoring its 3 positional args.
  # Deterministic stand-in for the real memory vault, whose contents this suite must not depend on.
  cat > "$FIXTURE/.claude/scripts/memory-retrieve.sh" <<'EOF'
#!/usr/bin/env bash
echo "<memory-context>"
echo "STUB_MEMORY_CONTENT"
echo "</memory-context>"
EOF
  chmod +x "$FIXTURE/.claude/scripts/memory-retrieve.sh"

  # STUB: literature-lit-flag-resolve.sh -- echoes $STUB_LIT_DIRECTIVE (default GLOBAL_MISSING)
  # to stdout and a fixed rationale to stderr, matching the real script's output contract
  # (directive on stdout, rationale on stderr) without depending on a real Literature corpus.
  cat > "$FIXTURE/.claude/scripts/literature-lit-flag-resolve.sh" <<'EOF'
#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    --lit-flag|--orchestrator-mode|--query) shift 2 ;;
    *) shift ;;
  esac
done
echo "Rationale: stub rationale (directive=${STUB_LIT_DIRECTIVE:-GLOBAL_MISSING})" >&2
echo "${STUB_LIT_DIRECTIVE:-GLOBAL_MISSING}"
EOF
  chmod +x "$FIXTURE/.claude/scripts/literature-lit-flag-resolve.sh"

  # STUB: literature-briefing-invoke.sh -- unconditionally emits a marker, ignoring --query/--global.
  cat > "$FIXTURE/.claude/scripts/literature-briefing-invoke.sh" <<'EOF'
#!/usr/bin/env bash
echo "<literature-briefing>"
echo "STUB_LIT_CONTENT"
echo "</literature-briefing>"
EOF
  chmod +x "$FIXTURE/.claude/scripts/literature-briefing-invoke.sh"
}

build_fixture

# ─── run_sut: invoke the SUT against the fixture, capturing stdout/stderr/exit separately ──────
# Usage: run_sut <phase> [extra SUT args...]
# Populates: LAST_STDOUT, LAST_STDERR, LAST_EXIT, LAST_DISPATCH_FILE
run_sut() {
  local phase="$1"; shift
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  SKILL_REPO_ROOT="$FIXTURE" bash "$SUT" "$TASK_NUM" "$phase" --session sess_test_fixture "$@" \
    >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
  LAST_DISPATCH_FILE=""
  if [ "$LAST_EXIT" -eq 0 ]; then
    LAST_DISPATCH_FILE="$(echo "$LAST_STDOUT" | jq -r '.dispatch_file // empty' 2>/dev/null)"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    pass "$label"
  else
    fail "$label (expected to find: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    fail "$label (unexpectedly found: $needle)"
  else
    pass "$label"
  fi
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 1: Parity -- research phase, --clean (memory suppressed), no --lit, no --hard
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 1: research phase parity (--clean, no --lit, no --hard)"
run_sut research --clean --seq 1 --dispatch-start-ts 1234567890
if [ "$LAST_EXIT" -eq 0 ] && [ -n "$LAST_DISPATCH_FILE" ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  pass "research: SUT exits 0 and dispatch file exists"
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "task_number: 999" "research: task_number present"
  assert_contains "$content" "phase: research" "research: phase present"
  assert_contains "$content" "task_type: general" "research: task_type present"
  assert_contains "$content" "Fixture task description for orchestrate-build-dispatch.sh test suite" "research: description present"
  assert_contains "$content" "dispatch_seq: 1" "research: dispatch_seq present"
  assert_contains "$content" "dispatch_start_ts: 1234567890" "research: dispatch_start_ts present (caller-supplied, recorded not generated)"
  assert_contains "$content" "artifact_number: 2" "research: artifact_number (mode=current, next_artifact_number=2)"
  assert_contains "$content" "artifact_padded: 02" "research: artifact_padded present"
  assert_contains "$content" "output_dir: ${TASK_DIR_REL}/reports/" "research: output_dir present"
  assert_contains "$content" "handoff_path:" "research: handoff_path present"
  assert_contains "$content" "user-decision-contract.md" "research: user-decision contract reference always present"
  assert_not_contains "$content" "<memory-context>" "research --clean: memory block suppressed"
  assert_not_contains "$content" "<literature-briefing>" "research (no --lit): lit block suppressed"
  assert_not_contains "$content" "<hard-mode-contracts>" "research (no --hard): hard-contracts block suppressed"
  assert_not_contains "$content" "Reasoning-depth guidance" "research (no --fast/--hard): effort note suppressed"
  if echo "$LAST_STDOUT" | jq -e '.model == ""' >/dev/null 2>&1; then
    pass "research: model is empty string (never the literal \"null\") when --model unset"
  else
    fail "research: model field wrong shape: $LAST_STDOUT"
  fi
else
  fail "research: SUT did not exit 0 / dispatch file missing (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 2: Parity -- research phase, memory ON (no --clean), --lit ON (SUBINDEX_PRESENT stub),
# --fast, --model opus
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 2: research phase, memory+lit+effort+model all active"
STUB_LIT_DIRECTIVE="SUBINDEX_PRESENT" run_sut research --seq 2 --lit --fast --model opus --focus "test focus"
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "<memory-context>" "research (not --clean): memory block present"
  assert_contains "$content" "STUB_MEMORY_CONTENT" "research: memory block carries stub content"
  assert_contains "$content" "<literature-briefing>" "research (--lit, SUBINDEX_PRESENT): lit block present"
  assert_contains "$content" "STUB_LIT_CONTENT" "research: lit block carries stub content"
  assert_contains "$content" "Reasoning-depth guidance: this dispatch runs in --fast mode." "research (--fast): effort note present"
  assert_contains "$content" "User focus: test focus" "research: focus_prompt threaded into prompt text"
  if echo "$LAST_STDOUT" | jq -e '.model == "opus"' >/dev/null 2>&1; then
    pass "research: --model opus passes through unchanged"
  else
    fail "research: model pass-through wrong: $LAST_STDOUT"
  fi
else
  fail "research (memory+lit+effort+model): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 3: Headless assertion -- AUTONOMOUS_GLOBAL directive never attempts an interactive prompt
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 3: headless lit resolution (AUTONOMOUS_GLOBAL, orchestrator_mode always true)"
STUB_LIT_DIRECTIVE="AUTONOMOUS_GLOBAL" run_sut research --clean --seq 3 --lit
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  pass "research (AUTONOMOUS_GLOBAL): SUT completes without attempting an interactive prompt"
  assert_contains "$LAST_STDERR" "[lit:auto]" "research (AUTONOMOUS_GLOBAL): [lit:auto] notice emitted, not a prompt"
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "<literature-briefing>" "research (AUTONOMOUS_GLOBAL): lit block still injected via the deterministic default"
else
  fail "research (AUTONOMOUS_GLOBAL): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# GLOBAL_MISSING: no literature available at all -- must degrade to empty lit_context with a
# visible (non-prompting) notice, never a crash.
STUB_LIT_DIRECTIVE="GLOBAL_MISSING" run_sut research --clean --seq 3b --lit
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  pass "research (GLOBAL_MISSING): SUT completes cleanly, no crash"
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content" "<literature-briefing>" "research (GLOBAL_MISSING): lit block stays empty (no empty tag pair emitted)"
else
  fail "research (GLOBAL_MISSING): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 4: Parity -- plan phase (mode=prev artifact round, research_artifact path)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 4: plan phase parity"
run_sut plan --clean --seq 4
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "artifact_number: 1" "plan: artifact_number (mode=prev, next_artifact_number-1=1)"
  assert_contains "$content" "output_dir: ${TASK_DIR_REL}/plans/" "plan: output_dir present"
  assert_contains "$content" "research_artifact: ${TASK_DIR_REL}/reports/01_fixture-report.md" "plan: research_artifact path resolved from state.json"
else
  fail "plan: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 5: Parity -- implement phase, no continuation, no territory
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 5: implement phase parity (no continuation, no territory)"
run_sut implement --clean --seq 5
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "plan_path: ${TASK_DIR_REL}/plans/01_fixture-plan.md" "implement: plan_path resolved (sort -V, latest)"
  assert_contains "$content" "## Continuation" "implement: continuation section present"
  if grep -A4 "## Continuation" "$LAST_DISPATCH_FILE" | grep -q "^null$"; then
    pass "implement: continuation is null when no handoff file exists"
  else
    fail "implement: expected null continuation, got: $(grep -A4 '## Continuation' "$LAST_DISPATCH_FILE")"
  fi
  assert_not_contains "$content" "## Territory" "implement (no --territory): territory section absent"
else
  fail "implement (no continuation): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 6: Parity -- implement phase, continuation present (both accepted forms), --hard +
# --territory (territory.md appended, phase mission's hard_contracts_block)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 6: implement phase, continuation (flat form) + --hard + --territory"
cat > "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json" <<'EOF'
{"continuation_path": "/abs/path/to/predecessor-handoff.json", "blockers": []}
EOF
territory_json='{"owned_files":"phase 1 files","read_only_files":[],"forbidden_files":[],"concurrency_note":"test"}'
run_sut implement --seq 6 --hard --clean --territory "$territory_json"
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "/abs/path/to/predecessor-handoff.json" "implement: continuation (flat form) resolved and normalized"
  assert_contains "$content" '"orchestrator_mode":true' "implement: continuation normalized to {handoff_path, orchestrator_mode: true}"
  assert_contains "$content" "## Territory" "implement (--territory): territory section present"
  assert_contains "$content" "phase 1 files" "implement: territory JSON carried through opaque, not reconstructed"
  assert_contains "$content" "<hard-mode-contracts>" "implement (--hard): hard-contracts block present"
  assert_contains "$content" "context/contracts/territory.md" "implement (--hard, territory set): territory.md appended to core_contracts"
  assert_contains "$content" "context/contracts/anti-analysis.md" "implement (--hard): anti-analysis.md present (core_contracts baseline)"
  assert_contains "$content" "context/contracts/recovery.md" "implement (--hard): recovery.md present (core_contracts baseline)"
else
  fail "implement (continuation flat + hard + territory): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

info "Group 6b: implement phase, continuation (deprecated nested form)"
cat > "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json" <<'EOF'
{"continuation_context": {"handoff_path": "/abs/path/to/nested-handoff.json"}, "blockers": []}
EOF
run_sut implement --clean --seq 6b
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "/abs/path/to/nested-handoff.json" "implement: continuation (deprecated nested form) still accepted"
else
  fail "implement (continuation nested form): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
rm -f "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 6c: --phase-number (hard mode's per-phase dispatch, H1) -- Phase Mission section, and
# absence from every base-mode / no-flag call.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 6c: --phase-number adds a Phase Mission section; absent without the flag"
cat > "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json" <<'EOF'
{"status": "partial", "phases_completed": 2, "phases_total": 5, "blockers": []}
EOF
run_sut implement --seq 6c --hard --clean --phase-number 3
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Phase Mission" "phase-number: Phase Mission section present"
  assert_contains "$content" "Implement phase 3 only" "phase-number: mission names the exact phase number"
  assert_contains "$content" "PHASES COMPLETED: 2 of 5" "phase-number: phases_completed/phases_total read from the handoff"
else
  fail "phase-number: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# No handoff at all (first cycle for this task) -- defaults to 0 of 0, matching single-task
# Stage 4's H1 branch's own defaults.
rm -f "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json"
run_sut implement --seq 6c2 --hard --clean --phase-number 1
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "PHASES COMPLETED: 0 of 0" "phase-number: absent handoff defaults phases_completed/phases_total to 0/0"
else
  fail "phase-number (no handoff): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Base-mode / no-flag call: never emits a Phase Mission section.
run_sut implement --seq 6c3 --clean
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content" "## Phase Mission" "phase-number: absent from a call with no --phase-number"
else
  fail "phase-number (absent flag): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
rm -f "$FIXTURE/${TASK_DIR_REL}/.orchestrator-handoff.json"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 7: Anti-drift -- the continuation-pointer resolution is a SHARED helper, not two
# independently hand-copied jq expressions. Structural check: both this SUT and
# orchestrate-triage-classify.sh source the same library file (scripts/lib/continuation-pointer-lib.sh)
# rather than each carrying their own inline jq.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 7: anti-drift -- shared continuation-pointer-lib.sh, not hand-copied jq"
if grep -q "continuation-pointer-lib.sh" "$SUT"; then
  pass "orchestrate-build-dispatch.sh sources the shared continuation-pointer-lib.sh"
else
  fail "orchestrate-build-dispatch.sh does not reference continuation-pointer-lib.sh -- drift risk"
fi
if grep -q "continuation-pointer-lib.sh" "$TRIAGE_CLASSIFY"; then
  pass "orchestrate-triage-classify.sh sources the shared continuation-pointer-lib.sh"
else
  fail "orchestrate-triage-classify.sh does not reference continuation-pointer-lib.sh -- drift risk"
fi
# shellcheck disable=SC1090
source "$CONT_LIB"
tmp_handoff="$(mktemp)"
echo '{"continuation_path": "/x/y.json", "blockers": []}' > "$tmp_handoff"
lib_result="$(resolve_continuation_pointer "$tmp_handoff")"
if [ "$lib_result" = '{"handoff_path":"/x/y.json","orchestrator_mode":true}' ]; then
  pass "shared helper resolve_continuation_pointer normalizes the flat form correctly (single implementation both scripts call)"
else
  fail "shared helper resolve_continuation_pointer returned unexpected shape: $lib_result"
fi
rm -f "$tmp_handoff"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 8: Negative -- --model unset never emits the literal string "null"
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 8: negative -- model emptiness, not the string null"
run_sut research --clean --seq 8
if echo "$LAST_STDOUT" | jq -e '.model == "" and (.model != "null")' >/dev/null 2>&1; then
  pass "model field is empty string, never the literal \"null\", when --model is unset"
else
  fail "model field shape wrong: $LAST_STDOUT"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 9: --compare -- the dispatch file's Identity section gains a single `compare_flag: true`
# line ONLY when --compare is passed; a no-flag dispatch file is byte-identical to one built
# without this flag's support at all.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 9: --compare emits compare_flag: true ONLY when passed (byte-identity otherwise)"
run_sut implement --clean --seq 9 --dispatch-start-ts 1234567890
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_no_compare="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content_no_compare" "compare_flag:" "implement (no --compare): compare_flag line absent"
  cp "$LAST_DISPATCH_FILE" "$WORKDIR/dispatch-no-compare.md"
else
  fail "implement (no --compare): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

run_sut implement --clean --seq 9 --dispatch-start-ts 1234567890 --compare
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_compare="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content_compare" "- compare_flag: true" "implement (--compare): compare_flag: true line present"
  if diff -q "$WORKDIR/dispatch-no-compare.md" "$LAST_DISPATCH_FILE" >/dev/null 2>&1; then
    fail "implement (--compare): expected a diff against the no-flag dispatch file, got none"
  else
    diff_line_count="$(diff "$WORKDIR/dispatch-no-compare.md" "$LAST_DISPATCH_FILE" | grep -c '^>')"
    if [ "$diff_line_count" -eq 1 ]; then
      pass "implement (--compare): differs from the no-flag dispatch file by exactly one added line"
    else
      fail "implement (--compare): expected exactly 1 added line vs. no-flag dispatch file, got $diff_line_count"
    fi
  fi
else
  fail "implement (--compare): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# The SUT itself is phase-agnostic for --compare (it just records whatever it was told) --
# implement-only scoping is a CALLER-side decision (orchestrate-cycle-plan.sh only ever passes
# --compare to this script for an implement-phase candidate; SKILL.md's own single-task dispatch
# sites only add --compare at the three implement dispatch sites). So an explicit --compare
# passed directly to the SUT for phase=research DOES emit the line -- that scoping is exercised
# in orchestrate-cycle-plan.sh's own test suite, not here.
run_sut research --clean --seq 9 --compare
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_research_compare="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content_research_compare" "- compare_flag: true" "research (--compare passed explicitly): SUT itself is phase-agnostic and still records compare_flag: true (implement-only scoping is a caller-side decision, tested in orchestrate-cycle-plan.sh's own suite)"
else
  fail "research (--compare): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "========================================"
echo "test-orchestrate-build-dispatch.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
