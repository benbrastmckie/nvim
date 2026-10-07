#!/usr/bin/env bash
# test-stall-reprompt-wiring.sh - Producer/consumer wiring regression suite for the
# stall_suspected signal and its re-prompt relay.
#
# The defect this suite guards against is a distinct class from every other suite in this
# directory: a signal that is computed, emitted in both output arms, unit-tested at the
# producer, and documented as a loop obligation -- yet has NO CONSUMER. Every existing test
# (test-orchestrate-cycle-postflight.sh's S1-S4 assertions among them) exercises the PRODUCER
# (orchestrate-cycle-postflight.sh) in isolation; none of them can catch the consumer silently
# disappearing from skill-orchestrate/SKILL.md, because none of them read SKILL.md at all. This
# suite is purely static (grep-based) over the real prose/shell-block files -- it does not drive
# either script end-to-end (that is test-orchestrate-cycle-postflight.sh's and
# test-handoff-dispatch-identity.sh's job), it only asserts that the wiring between producer and
# consumer still exists in both directions.
#
# Overridable target (for the negative-control verification this suite's own authoring required,
# and for any future re-verification): set SKILL_MD_PATH / STATE_MACHINE_DOC_PATH /
# POSTFLIGHT_SCRIPT_PATH to point at a scratch copy instead of the real file. Defaults to the
# real source-store paths. See the bottom of this file for the authoring-time negative-control
# note (not re-run automatically every invocation, per the precedent in
# test-handoff-dispatch-identity.sh's own "Negative-control note (not automated)").
#
# Exit codes: 0 -- all assertions PASS; 1 -- at least one assertion FAILED; 2 -- environment
# error (a required file does not exist).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_MD_PATH="${SKILL_MD_PATH:-$CORE_DIR/../skills/skill-orchestrate/SKILL.md}"
STATE_MACHINE_DOC_PATH="${STATE_MACHINE_DOC_PATH:-$CORE_DIR/../docs/architecture/orchestrate-state-machine.md}"
POSTFLIGHT_SCRIPT_PATH="${POSTFLIGHT_SCRIPT_PATH:-$CORE_DIR/orchestrate-cycle-postflight.sh}"

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

require_file "$SKILL_MD_PATH"
require_file "$STATE_MACHINE_DOC_PATH"
require_file "$POSTFLIGHT_SCRIPT_PATH"

# Extract the region between "### Move 3: Postflight" and "### Move 4: Branch" so the
# relay-siting assertions below can be scoped to the right half of the file without re-deriving
# the heading pair in every assertion.
move3_region() { awk '/^### Move 3: Postflight/{flag=1; next} /^### Move 4: Branch/{flag=0} flag' "$SKILL_MD_PATH"; }
move4_region() { awk '/^### Move 4: Branch/{flag=1} flag' "$SKILL_MD_PATH"; }

# ── Assertion 1: producer/consumer pairing, both directions ────────────────────────────────────
# At minimum, stall_suspected (the field that was dead) must be both emitted by the producer and
# read by the consumer. A full bidirectional scan of every postflight output-contract field
# against SKILL.md is deliberately NOT attempted here -- several fields (status, persisted_status,
# verdict, halt, infra_exempt_cycle, report_missing) are already known-wired and asserted
# elsewhere; this suite's job is the ONE field class that escaped every existing test, not a
# general-purpose schema linter.
if grep -q "stall_suspected" "$POSTFLIGHT_SCRIPT_PATH"; then
  pass "producer: orchestrate-cycle-postflight.sh still emits stall_suspected"
else
  fail "producer: orchestrate-cycle-postflight.sh no longer emits stall_suspected"
fi

if grep -q "stall_suspected" "$SKILL_MD_PATH"; then
  pass "consumer: skill-orchestrate/SKILL.md reads stall_suspected (this is the assertion that was previously impossible to write, because it was previously false)"
else
  fail "consumer: skill-orchestrate/SKILL.md does not read stall_suspected -- the signal is dead again"
fi

# ── Assertion 2: the suppression guard exists ───────────────────────────────────────────────────
# Move 3's failed_tasks append on a failed verdict must be conditioned on stall_suspected (or on
# stall_reprompted, for the one-re-prompt-already-spent case) -- not an unconditional append.
if move3_region | grep -q "stall_suspected" && move3_region | grep -q "stall_reprompted"; then
  pass "suppression guard: Move 3 region references both stall_suspected and stall_reprompted"
else
  fail "suppression guard: Move 3 region is missing a reference to stall_suspected and/or stall_reprompted"
fi

if move3_region | grep -qE '\.stall_reprompted\b'; then
  pass "suppression guard: Move 3 region keys its guard on a stall_reprompted lookup, not stall_suspected alone"
else
  fail "suppression guard: Move 3 region does not appear to key its guard on stall_reprompted"
fi

# ── Assertion 3: relay siting (writer in Move 3, reader in Move 4, no Agent call in Move 3) ────
if move3_region | grep -q "pending_stall_reprompt"; then
  pass "relay siting: Move 3 region writes pending_stall_reprompt"
else
  fail "relay siting: Move 3 region does not write pending_stall_reprompt"
fi

if move4_region | grep -q "pending_stall_reprompt"; then
  pass "relay siting: Move 4 region reads pending_stall_reprompt"
else
  fail "relay siting: Move 4 region does not read pending_stall_reprompt"
fi

if move3_region | grep -qiE '^\s*#\s*agent tool|agent\(|AskUserQuestion\('; then
  fail "relay siting: Move 3 region appears to contain an Agent-tool call -- this crosses the Postflight Boundary"
else
  pass "relay siting: Move 3 region contains no Agent-tool call"
fi

# ── Assertion 4: the three new mt_state_file fields are documented ─────────────────────────────
for field in pending_stall_reprompt stall_reprompted stall_ledger; do
  if grep -q "$field" "$STATE_MACHINE_DOC_PATH"; then
    pass "mt_state_file field reference: $field is documented in orchestrate-state-machine.md"
  else
    fail "mt_state_file field reference: $field is MISSING from orchestrate-state-machine.md"
  fi
done

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0

# =====================================================================
# Negative-control note (not automated every run, per test-handoff-dispatch-identity.sh's own
# precedent): verified at authoring time that this suite FAILS (exit 1, Assertion 1's consumer
# check) when pointed at a scratch copy of SKILL.md with every stall_suspected line removed:
#
#   cp "$CORE_DIR/skills/skill-orchestrate/SKILL.md" /tmp/SKILL-scratch.md
#   sed -i '/stall_suspected/d' /tmp/SKILL-scratch.md
#   SKILL_MD_PATH=/tmp/SKILL-scratch.md bash test-stall-reprompt-wiring.sh
#   # => Assertion 1's consumer check FAILs; exit 1. Confirms the assertion is live, not
#   # vacuously true. The real SKILL.md is never touched by this verification.
# =====================================================================
