#!/usr/bin/env bash
# test-orchestrate-build-dispatch.sh - Fixture suite for orchestrate-build-dispatch.sh, proving
# the generated per-dispatch context file carries every input the inline Stage 3.5 recipe it
# replaces would have interpolated, that the four optional blocks are skipped (never emitted
# empty) when their gate is off, and that the continuation-pointer resolution it shares with
# orchestrate-triage-classify.sh cannot silently drift back into two copies.
#
# Structural model: test-skill-base-lifecycle.sh / test-validate-return-meta.sh (mktemp -d
# WORKDIR with an EXIT-trap cleanup, deploy-tree-first / source-store-fallback candidate
# resolution for TRIAGE_CLASSIFY/CONT_LIB, pass()/fail()/info() helpers with integer counters,
# exit 0 all-pass / 1 any-fail / 2 environment error). The SUT itself uses an INVERTED
# source-store-first resolution -- see the CANDIDATE-RESOLUTION INVERSION comment at its own
# resolve_candidate call below for why.
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

# CANDIDATE-RESOLUTION INVERSION for the SUT only (deliberate -- same rationale as
# test-force-phases.sh's own documented inversion): this suite's Group 13 tests a PRE-DEPLOY
# SOURCE-STORE EDIT to orchestrate-build-dispatch.sh itself (the task that carries
# concurrent-sibling territory into base-mode dispatch briefs). Resolving deploy-tree-first here
# would silently validate the OLD, undeployed-against `.claude/scripts/` copy and report a false
# green on a source-store regression in the exact file under test. So, for the SUT only,
# resolution is inverted: agent-system/extensions/core/ FIRST, `.claude/scripts/` fallback only if
# the source-store copy is absent. TRIAGE_CLASSIFY and CONT_LIB below are NOT under test by this
# task and keep the ordinary deploy-tree-first / source-store-fallback order.
SUT="$(resolve_candidate "orchestrate-build-dispatch.sh" \
  "$SCRIPT_DIR/../orchestrate-build-dispatch.sh" \
  "$REPO_ROOT/.claude/scripts/orchestrate-build-dispatch.sh")" || exit 2
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
# Group 10: .decisions.json read path -- absent (byte-identical), present-and-empty (no section),
# present-with-entries (## Prior Decisions section emitted, content faithful).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 10: .decisions.json read path"

DECISIONS_FILE="$FIXTURE/${TASK_DIR_REL}/.decisions.json"

# Case A: absent file -- byte-identical to a dispatch built before this feature existed (no
# .decisions.json ever written in this fixture up to this point).
rm -f "$DECISIONS_FILE"
run_sut implement --clean --seq 10 --dispatch-start-ts 1234567890
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_absent="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content_absent" "## Prior Decisions" "decisions absent: no Prior Decisions section"
  cp "$LAST_DISPATCH_FILE" "$WORKDIR/dispatch-no-decisions.md"
else
  fail "decisions absent: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case B: present-and-empty file -- still no section, and still byte-identical to the absent case
# (an empty array is not a reason to change the rendered dispatch file at all).
echo '[]' > "$DECISIONS_FILE"
run_sut implement --clean --seq 10 --dispatch-start-ts 1234567890
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_empty="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content_empty" "## Prior Decisions" "decisions present-and-empty: no Prior Decisions section"
  if diff -q "$WORKDIR/dispatch-no-decisions.md" "$LAST_DISPATCH_FILE" >/dev/null 2>&1; then
    pass "decisions present-and-empty: byte-identical to the absent-file dispatch"
  else
    fail "decisions present-and-empty: expected byte-identical output to the absent-file dispatch, got a diff"
  fi
else
  fail "decisions present-and-empty: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case C: present-with-entries -- ## Prior Decisions section emitted, content faithful to the
# question/answer/cycle/timestamp fields.
cat > "$DECISIONS_FILE" <<'EOF'
[
  {
    "question": "Which logging backend should the new metrics pipeline use?",
    "answer": "Use the existing structured-logging module; do not add a new dependency.",
    "cycle": 3,
    "timestamp": "2026-09-08T04:00:00Z"
  }
]
EOF
run_sut implement --clean --seq 10 --dispatch-start-ts 1234567890
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content_entries="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content_entries" "## Prior Decisions" "decisions present-with-entries: Prior Decisions section present"
  assert_contains "$content_entries" "Which logging backend should the new metrics pipeline use?" "decisions present-with-entries: question text present"
  assert_contains "$content_entries" "Use the existing structured-logging module" "decisions present-with-entries: answer text present"
  assert_contains "$content_entries" "cycle 3" "decisions present-with-entries: cycle number present"
  assert_contains "$content_entries" "2026-09-08T04:00:00Z" "decisions present-with-entries: timestamp present"
else
  fail "decisions present-with-entries: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
rm -f "$DECISIONS_FILE"

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 11: Phase 5 (artifact-based admission) -- the plan branch's existing_plan_path/
# revision_reason rendering (reviser-agent.md's own Stage 1/2 field names), and a pin test that
# a plan dispatch names the NEWEST report after several research rounds (same-type artifact
# supersession -- context/reference/state-management-schema.md's "Artifacts Are Append-Only"
# section -- means the state.json artifacts array holds exactly one report entry at a time, so
# this pins that `.[0].path` already resolves correctly by construction; change code only if
# this fails).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 11: existing_plan_path/revision_reason rendering, newest-report pin"

# Case A: plan phase WITH an existing plan (the fixture's default state already seeds
# ${TASK_DIR_REL}/plans/01_fixture-plan.md) -- both new lines render, using the exact field
# names agents/reviser-agent.md's own Stage 1 expects.
run_sut plan --clean --seq 11
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "existing_plan_path: ${TASK_DIR_REL}/plans/01_fixture-plan.md" "plan (existing plan present): existing_plan_path renders with the newest plan's path"
  assert_contains "$content" "revision_reason: forced --plan round" "plan (existing plan present): revision_reason renders"
else
  fail "plan (existing plan present): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case B: plan phase with NO existing plan -- neither line renders (the ordinary planner-agent
# path stays byte-for-byte unchanged). Temporarily relocate the fixture's plan file.
mv "$FIXTURE/${TASK_DIR_REL}/plans/01_fixture-plan.md" "$WORKDIR/01_fixture-plan.md.setaside"
run_sut plan --clean --seq 11
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content" "existing_plan_path" "plan (no plan present): existing_plan_path line absent"
  assert_not_contains "$content" "revision_reason" "plan (no plan present): revision_reason line absent"
else
  fail "plan (no plan present): SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
mv "$WORKDIR/01_fixture-plan.md.setaside" "$FIXTURE/${TASK_DIR_REL}/plans/01_fixture-plan.md"

# Case C: newest-report pin -- simulate the state AFTER a second research round under real
# same-type supersession semantics (the round-1 report's artifact entry is REMOVED, not merely
# appended alongside): state.json's artifacts array holds ONLY the round-2 report. A plan
# dispatch must name round-2's path, not round-1's.
printf '# Fixture report round 2\n' > "$FIXTURE/${TASK_DIR_REL}/reports/02_fixture-report-round2.md"
cat > "$FIXTURE/specs/state.json" <<EOF
{
  "active_projects": [
    {
      "project_number": ${TASK_NUM},
      "project_name": "${PROJECT}",
      "task_type": "general",
      "status": "researched",
      "description": "Fixture task description for orchestrate-build-dispatch.sh test suite -- exercises every gatherer.",
      "next_artifact_number": 3,
      "artifacts": [
        {"type": "report", "path": "${TASK_DIR_REL}/reports/02_fixture-report-round2.md", "summary": "fixture report round 2"}
      ]
    }
  ]
}
EOF
run_sut plan --clean --seq 11
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "research_artifact: ${TASK_DIR_REL}/reports/02_fixture-report-round2.md" "plan dispatch after two research rounds names the NEWEST report (round 2, not round 1)"
  assert_not_contains "$content" "01_fixture-report.md" "plan dispatch after two research rounds does NOT name the superseded round-1 report"
else
  fail "newest-report pin: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
# Restore the original single-report fixture state for any suite appended after this one.
build_fixture

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 12: <deploy-freshness-context> injection -- present for a stale fixture extension, absent
# (byte-identical to a clean build) when nothing is stale. Reuses the SAME
# skill_deploy_freshness_stale_names helper skill-base.sh's skill_preflight_update calls (see
# that function's own Group 4b coverage in test-skill-base-lifecycle.sh); this suite is under
# test for the SEPARATE injection/gating logic in orchestrate-build-dispatch.sh's own Stage 3.5,
# not the underlying comparison algorithm again.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 12: <deploy-freshness-context> injection (stale vs. clean)"

# build_stale_extensions_json <fixture_root>: fabricates a `.claude-extensions.json` at the
# fixture root recording a "fixtureext" entry whose source_dir/source_git_head pair is
# genuinely STALE (a throwaway one-file scratch git repo advanced past the recorded head) --
# same shape as test-deploy-freshness.sh's own STALE case, reimplemented locally here.
build_stale_extensions_json() {
  local fixture_root="$1"
  local src_repo="$WORKDIR/g12-source-repo"
  rm -rf "$src_repo"
  mkdir -p "$src_repo"
  git init -q "$src_repo"
  git -C "$src_repo" config user.email "test@example.com"
  git -C "$src_repo" config user.name "Test"
  echo "v1" > "$src_repo/f.txt"
  git -C "$src_repo" add f.txt
  git -C "$src_repo" commit -q -m "initial"
  local head_v1
  head_v1="$(git -C "$src_repo" log -1 --format=%H -- f.txt)"
  cat > "$fixture_root/.claude-extensions.json" <<EOF
{"version":"1.0.0","extensions":{"fixtureext":{"version":"1.0.0","source_dir":"${src_repo}","source_git_head":"${head_v1}"}}}
EOF
  echo "v2" > "$src_repo/f.txt"
  git -C "$src_repo" add f.txt
  git -C "$src_repo" commit -q -m "v2 -- makes the recorded head stale"
}

# Case A: a stale extension present -> block appears, names the extension, states the
# partial-staleness caveat and the redeploy-not-hand-patch remedy.
build_stale_extensions_json "$FIXTURE"
run_sut implement --clean --seq 12
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "<deploy-freshness-context>" "stale fixture: <deploy-freshness-context> block present"
  assert_contains "$content" "fixtureext" "stale fixture: block names the stale extension"
  assert_contains "$content" "does NOT mean the tree is current" "stale fixture: partial-staleness caveat present"
  assert_contains "$content" "Do NOT hand-patch" "stale fixture: hand-patch prohibition present"
  assert_contains "$content" "deploy-headless.sh" "stale fixture: redeploy remedy present"
else
  fail "Group 12 stale case: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi
# Snapshot the CONTENT to a separate file -- both run_sut calls in this group use the same
# task/seq, so the dispatch file path itself is reused and overwritten by the next call; only a
# copy of the bytes survives the second run_sut invocation below.
STALE_DISPATCH_FILE="$WORKDIR/g12-stale-dispatch.md"
cp "$LAST_DISPATCH_FILE" "$STALE_DISPATCH_FILE"

# Case B: no .claude-extensions.json at all -> block absent, and the rest of the dispatch file is
# byte-identical to the stale-case build modulo exactly the freshness block (proves the injection
# is a pure addition, not a reformatting of anything else).
rm -f "$FIXTURE/.claude-extensions.json"
run_sut implement --clean --seq 12
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content" "<deploy-freshness-context>" "clean fixture: <deploy-freshness-context> block absent"
  if diff -q \
      <(sed -E 's/dispatch_seq: [0-9]+//' "$STALE_DISPATCH_FILE") \
      <(sed -E 's/dispatch_seq: [0-9]+//' "$LAST_DISPATCH_FILE") \
      >/dev/null 2>&1; then
    fail "clean fixture: dispatch file unexpectedly byte-identical to the stale one (the block never rendered any content in either case -- fixture broken)"
  else
    diff_line_count=$(diff <(sed -E 's/dispatch_seq: [0-9]+//' "$STALE_DISPATCH_FILE") <(sed -E 's/dispatch_seq: [0-9]+//' "$LAST_DISPATCH_FILE") | grep -c '^[<>]')
    if [ "$diff_line_count" -eq 7 ]; then
      pass "clean fixture: differs from the stale build by EXACTLY the 6-line injected block plus its blank-line separator (7 changed lines), nothing else"
    else
      fail "clean fixture: expected exactly 7 changed lines vs. the stale build (the block + separator), got $diff_line_count -- see $STALE_DISPATCH_FILE vs $LAST_DISPATCH_FILE"
    fi
  fi
else
  fail "Group 12 clean case: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Restore the original single-report fixture state (no .claude-extensions.json) for any suite
# appended after this one, and clean up the scratch source repo.
rm -rf "$WORKDIR/g12-source-repo"
build_fixture

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 13: base-mode --territory pointer (the task that carries concurrent-sibling territory
# into base-mode dispatch briefs) -- ## Territory + the territory.md pointer render in base mode
# (which never sees <hard-mode-contracts> at all), the pointer is likewise present for a hard-mode
# NON-implement phase (research/plan), the pointer is ABSENT for the one case where the contract
# is already pulled in elsewhere (hard_mode=true AND phase=implement), and a call with no
# --territory at all stays byte-identical to a pre-this-feature build (no pointer, no section).
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 13: base-mode --territory pointer to context/contracts/territory.md"

sibling_territory_json='{"concurrent_siblings":[{"task_number":42,"phase":"implement","file_scope":null,"scope_declared":false,"scope_granularity":"undeclared","entries":[],"note":"No file_scope declared for this task -- it may touch any file in the repository."}],"concurrency_note":"test sibling note"}'

# Case A: base mode (no --hard), --territory set -- ## Territory present, pointer present,
# <hard-mode-contracts> absent (base mode never renders it, --hard was not passed at all).
run_sut implement --seq 13a --clean --territory "$sibling_territory_json"
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Territory" "Case A (base mode, --territory): territory section present"
  assert_contains "$content" '"concurrent_siblings"' "Case A: sibling payload carried through opaque"
  assert_contains "$content" "Read context/contracts/territory.md (Cross-Task Territory section) before editing any file." "Case A: territory.md pointer present"
  assert_not_contains "$content" "<hard-mode-contracts>" "Case A: <hard-mode-contracts> absent in base mode"
else
  fail "Case A: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case B: hard mode, research phase, --territory set -- hard_contracts_block IS rendered (research
# has its own core_contracts list) but that list never includes territory.md (only the implement
# branch conditionally appends it), so the pointer must still appear here.
run_sut research --seq 13b --clean --hard --territory "$sibling_territory_json"
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Territory" "Case B (hard mode, research, --territory): territory section present"
  assert_contains "$content" "<hard-mode-contracts>" "Case B: hard-contracts block present (research's own core_contracts)"
  assert_contains "$content" "Read context/contracts/territory.md (Cross-Task Territory section) before editing any file." "Case B: pointer present (research's core_contracts never lists territory.md)"
else
  fail "Case B: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case C: hard mode, implement phase, --territory set -- the ONE case where territory.md is
# already pulled in via core_contracts/<hard-mode-contracts>; the standalone pointer sentence must
# be absent (never duplicated).
run_sut implement --seq 13c --clean --hard --territory "$sibling_territory_json"
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Territory" "Case C (hard mode, implement, --territory): territory section present"
  assert_contains "$content" "<hard-mode-contracts>" "Case C: hard-contracts block present"
  assert_contains "$content" "context/contracts/territory.md" "Case C: territory.md listed via core_contracts"
  assert_not_contains "$content" "Read context/contracts/territory.md (Cross-Task Territory section) before editing any file." "Case C: standalone pointer sentence absent (already covered by core_contracts)"
else
  fail "Case C: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Case D (regression guard): no --territory at all -- byte-identical to Group 5's no-territory
# case; neither the section nor the pointer ever appears.
run_sut implement --seq 13d --clean
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_not_contains "$content" "## Territory" "Case D (no --territory): territory section absent"
  assert_not_contains "$content" "context/contracts/territory.md" "Case D (no --territory): no territory.md reference anywhere"
else
  fail "Case D: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 14: wait-discipline pointer present in every dispatch -- the "## Wait Discipline" section
# (pointing at both context/patterns/external-process-wait.md and
# context/patterns/bounded-build-waiter.md) is UNCONDITIONAL, like "## User-Decision
# Contract": it must appear across the full base/--hard x research/plan/implement matrix, exactly
# once per dispatch file, and ahead of "## User-Decision Contract".
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 14: wait-discipline pointer present in every dispatch"

# Base mode: research, plan, implement.
run_sut research --clean --seq 14a
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "base research: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "base research: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "base research: pointer to bounded-build-waiter.md present"
else
  fail "base research: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

run_sut plan --clean --seq 14b
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "base plan: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "base plan: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "base plan: pointer to bounded-build-waiter.md present"
else
  fail "base plan: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

run_sut implement --clean --seq 14c
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "base implement: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "base implement: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "base implement: pointer to bounded-build-waiter.md present"
else
  fail "base implement: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

# Hard mode: research, plan, implement.
run_sut research --clean --hard --seq 14d
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "hard research: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "hard research: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "hard research: pointer to bounded-build-waiter.md present"
else
  fail "hard research: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

run_sut plan --clean --hard --seq 14e
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "hard plan: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "hard plan: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "hard plan: pointer to bounded-build-waiter.md present"
else
  fail "hard plan: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
fi

run_sut implement --clean --hard --seq 14f
if [ "$LAST_EXIT" -eq 0 ] && [ -f "$LAST_DISPATCH_FILE" ]; then
  content="$(cat "$LAST_DISPATCH_FILE")"
  assert_contains "$content" "## Wait Discipline" "hard implement: Wait Discipline section present"
  assert_contains "$content" "context/patterns/external-process-wait.md" "hard implement: pointer to external-process-wait.md present"
  assert_contains "$content" "context/patterns/bounded-build-waiter.md" "hard implement: pointer to bounded-build-waiter.md present"

  # Single-occurrence guard: the pointer must never be double-emitted (e.g. via a future
  # hard_contracts_block addition), even in the one mode/phase combination with the richest set
  # of conditionally-rendered sections.
  occurrence_count="$(grep -c "context/patterns/external-process-wait.md" "$LAST_DISPATCH_FILE")"
  if [ "$occurrence_count" -eq 1 ]; then
    pass "hard implement: external-process-wait.md pointer appears exactly once"
  else
    fail "hard implement: expected exactly 1 occurrence of the pointer, got $occurrence_count"
  fi

  bbw_occurrence_count="$(grep -c "context/patterns/bounded-build-waiter.md" "$LAST_DISPATCH_FILE")"
  if [ "$bbw_occurrence_count" -eq 1 ]; then
    pass "hard implement: bounded-build-waiter.md pointer appears exactly once"
  else
    fail "hard implement: expected exactly 1 occurrence of the pointer, got $bbw_occurrence_count"
  fi

  # Ordering guard: "## Wait Discipline" precedes "## User-Decision Contract" (both are
  # unconditional; Wait Discipline is written immediately before User-Decision Contract in the
  # SUT's write block).
  wait_line="$(grep -n "^## Wait Discipline$" "$LAST_DISPATCH_FILE" | head -1 | cut -d: -f1)"
  decision_line="$(grep -n "^## User-Decision Contract$" "$LAST_DISPATCH_FILE" | head -1 | cut -d: -f1)"
  if [ -n "$wait_line" ] && [ -n "$decision_line" ] && [ "$wait_line" -lt "$decision_line" ]; then
    pass "hard implement: Wait Discipline section precedes User-Decision Contract"
  else
    fail "hard implement: expected Wait Discipline ($wait_line) before User-Decision Contract ($decision_line)"
  fi
else
  fail "hard implement: SUT did not exit 0 (exit=$LAST_EXIT stderr=$LAST_STDERR)"
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
