#!/usr/bin/env bash
# test-validate-handoff-location.sh - Fixture-driven regression suite for
# validate-handoff-location.sh's task-directory digit-count matcher AND its blocking
# PostToolUse behavior (exit code 0 on an allowed path, exit 2 on a misplaced one).
#
# Drives the hook as a real subprocess: copies it byte-for-byte into an isolated mktemp -d
# workdir at the relative path its own SCRIPT_DIR resolution expects
# (<workdir>/hooks/validate-handoff-location.sh) and pipes a synthetic PostToolUse JSON payload
# ({"tool_input":{"file_path":...}}) on stdin for every case, asserting on the hook's EXIT CODE
# (0 = allowed, 2 = misplaced) and, for the required 4-digit negative fixture, on the absence of
# "MISPLACED" text on stderr. The hook is never instrumented or modified for testability.
#
# system-defect-record.sh is deliberately NOT copied into the workdir. The hook's reject branch
# invokes it via `bash "$SYSTEM_DEFECT_RECORD" ... >/dev/null 2>&1 || echo "Note: ..." >&2` -- a
# missing script fails that subshell silently (both stdout and stderr redirected to /dev/null),
# the swallow-and-note `echo` goes to the hook's real stderr, and `exit 2` follows unconditionally
# on the next line regardless. The reject-side assertions below therefore exercise the hook's
# real, unmocked behavior when the recorder is absent from a minimal test workdir -- this is not
# a gap in coverage, it is exactly what the accept-path note in the implementation plan's research
# integration section describes: the accept branch never reaches the recorder at all, and the
# reject branch's call to it is already designed to be non-fatal on failure.
#
# Follows the core shell-test convention in
# context/standards/shell-script-testing.md: pass()/fail()/info() helpers, PASSED/FAILED
# integer counters, mktemp -d workdir with a trap EXIT cleanup.
#
# Exit codes: 0 -- all fixtures PASS; 1 -- at least one fixture FAILED; 2 -- environment error
# (missing hook or missing jq).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/../../hooks/validate-handoff-location.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [ ! -f "$HOOK_SRC" ]; then
  echo "ERROR: expected validate-handoff-location.sh at $HOOK_SRC" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to build synthetic PostToolUse payloads and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# Mirror the hook's expected sibling layout: hooks/validate-handoff-location.sh resolves
# SCRIPT_DIR from its OWN directory (used only to locate system-defect-record.sh, which this
# suite deliberately omits -- see header note).
mkdir -p "$WORKDIR/hooks"
HOOK="$WORKDIR/hooks/validate-handoff-location.sh"
cp "$HOOK_SRC" "$HOOK"
chmod +x "$HOOK"

# The content check resolves its validator as a sibling of system-defect-record.sh
# ($SCRIPT_DIR/../scripts/validate-handoff.sh, where the hook's SCRIPT_DIR is $WORKDIR/hooks) --
# copy the real validator into that same layout so the on-disk content-check fixtures below
# exercise the real, unmocked validator, never a stub.
mkdir -p "$WORKDIR/scripts"
VALIDATOR_SRC="$SCRIPT_DIR/../validate-handoff.sh"
if [ ! -f "$VALIDATOR_SRC" ]; then
  echo "ERROR: expected validate-handoff.sh at $VALIDATOR_SRC" >&2
  exit 2
fi
cp "$VALIDATOR_SRC" "$WORKDIR/scripts/validate-handoff.sh"
chmod +x "$WORKDIR/scripts/validate-handoff.sh"

# run_hook <file_path>
# Builds a synthetic PostToolUse payload via jq and pipes it to the copied hook. Echoes
# "EXITCODE|STDERR" so callers can assert on both.
run_hook() {
  local file_path="$1" out exit_code
  out="$(jq -n --arg fp "$file_path" \
    '{tool_input: {file_path: $fp}, session_id: "sess_test_0000", cwd: "/tmp"}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

# assert_allowed <label> <file_path>
# Expects exit 0 (allowed).
assert_allowed() {
  local label="$1" file_path="$2" result code stderr_out
  result="$(run_hook "$file_path")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 0 ]; then
    pass "$label: exits 0 (allowed)"
  else
    fail "$label: expected exit 0, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_allowed_no_misplaced_text <label> <file_path>
# Expects exit 0 AND no "MISPLACED" text anywhere on stderr -- pins the diagnostic's absence,
# not merely the exit code. Used for the required 4-digit negative-test fixture.
assert_allowed_no_misplaced_text() {
  local label="$1" file_path="$2" result code stderr_out
  result="$(run_hook "$file_path")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 0 ] && ! printf '%s' "$stderr_out" | grep -q 'MISPLACED'; then
    pass "$label: exits 0 with no MISPLACED diagnostic on stderr"
  else
    fail "$label: expected exit 0 + no MISPLACED text, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_misplaced <label> <file_path>
# Expects exit 2 (misplaced) with a MISPLACED diagnostic on stderr.
assert_misplaced() {
  local label="$1" file_path="$2" result code stderr_out
  result="$(run_hook "$file_path")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 2 ] && printf '%s' "$stderr_out" | grep -q 'MISPLACED'; then
    pass "$label: exits 2 with MISPLACED diagnostic"
  else
    fail "$label: expected exit 2 + MISPLACED text, got exit=$code stderr='$stderr_out'"
  fi
}

# run_hook_on_disk <relative_file_path_under_WORKDIR>
# Like run_hook, but cds into $WORKDIR first so the relative $FILE argument (and the hook's own
# content-check [ -f "$FILE" ] test) resolves against a REAL on-disk fixture created under
# $WORKDIR, rather than a synthetic non-existent path. Required for every content-check fixture
# below -- the content check is deliberately a no-op (fail-safe) against a path that does not
# exist on disk, which is exactly what every pre-existing fixture above continues to exercise.
run_hook_on_disk() {
  local file_path="$1" out exit_code
  out="$(cd "$WORKDIR" && jq -n --arg fp "$file_path" \
    '{tool_input: {file_path: $fp}, session_id: "sess_test_0000", cwd: "/tmp"}' \
    | bash "$HOOK" 2>&1 1>/dev/null)"
  exit_code=$?
  printf '%s|%s' "$exit_code" "$out"
}

# assert_allowed_on_disk <label> <relative_file_path>
# Expects exit 0 for an on-disk content-check fixture (conforming handoff, or the fail-safe
# case).
assert_allowed_on_disk() {
  local label="$1" file_path="$2" result code stderr_out
  result="$(run_hook_on_disk "$file_path")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 0 ]; then
    pass "$label: exits 0 (allowed)"
  else
    fail "$label: expected exit 0, got exit=$code stderr='$stderr_out'"
  fi
}

# assert_field_rejected <label> <relative_file_path>
# Expects exit 2 with the content-check's own banner (distinct from the MISPLACED one) on
# stderr.
assert_field_rejected() {
  local label="$1" file_path="$2" result code stderr_out
  result="$(run_hook_on_disk "$file_path")"
  code="${result%%|*}"
  stderr_out="${result#*|}"
  if [ "$code" -eq 2 ] && printf '%s' "$stderr_out" | grep -q 'HANDOFF VALIDATION FAILED'; then
    pass "$label: exits 2 with HANDOFF VALIDATION FAILED diagnostic"
  else
    fail "$label: expected exit 2 + HANDOFF VALIDATION FAILED text, got exit=$code stderr='$stderr_out'"
  fi
}

# =====================================================================
# Accept fixtures (must exit 0) -- neutral synthetic directory numbers only, never a live task
# number, per rules/no-task-references-in-deliverables.md.
# =====================================================================
assert_allowed "accept: 3-digit legacy task directory" \
  "specs/042_synthetic-fixture/.orchestrator-handoff.json"

# The required negative-test fixture: a 4-digit task directory must NOT trip HANDOFF_MISLOCATED.
assert_allowed_no_misplaced_text "accept: 4-digit task directory (required negative fixture)" \
  "specs/8842_synthetic-fixture/.orchestrator-handoff.json"

assert_allowed "accept: 4-digit OC_-prefixed task directory" \
  "specs/OC_8842_synthetic-fixture/.orchestrator-handoff.json"

assert_allowed "accept: 5-digit task directory (future-proofing)" \
  "specs/88420_synthetic-fixture/.orchestrator-handoff.json"

# =====================================================================
# Reject fixtures (must exit 2 with a MISPLACED diagnostic)
# =====================================================================
assert_misplaced "reject: bare filename, no directory" \
  ".orchestrator-handoff.json"

assert_misplaced "reject: specs/ root, outside any task directory" \
  "specs/.orchestrator-handoff.json"

assert_misplaced "reject: non-numeric directory prefix" \
  "specs/abc_synthetic-fixture/.orchestrator-handoff.json"

assert_misplaced "reject: 2-digit directory prefix (below the 3-digit minimum)" \
  "specs/42_synthetic-fixture/.orchestrator-handoff.json"

# =====================================================================
# Non-trigger fixture: exact-basename guard is untouched by this change.
# =====================================================================
assert_allowed "non-trigger: differently-named file is ignored entirely" \
  "specs/8842_synthetic-fixture/handoff-example.json"

# =====================================================================
# Content-check fixtures (Phase 3): the write-time required-field gate, against REAL on-disk
# files created under $WORKDIR at a valid, allowed task path. Every pre-existing fixture above
# stays unchanged and must still pass -- that is the fail-safe proof, not a formality: the
# content check must be a strict no-op against a synthetic, non-existent path.
# =====================================================================

mkdir -p "$WORKDIR/specs/100_field-fixture/summaries"
cat > "$WORKDIR/specs/100_field-fixture/.orchestrator-handoff.json" << 'EOF'
{"status": "implemented", "summary": "Implemented everything and verified the result.", "artifacts": [{"type": "summary", "path": "specs/100_field-fixture/summaries/01_x.md"}], "phases_completed": 1, "phases_total": 1, "blockers": []}
EOF
assert_allowed_on_disk "content-check accept: conforming on-disk handoff" \
  "specs/100_field-fixture/.orchestrator-handoff.json"

mkdir -p "$WORKDIR/specs/101_field-fixture/summaries"
cat > "$WORKDIR/specs/101_field-fixture/.orchestrator-handoff.json" << 'EOF'
{"status": "implemented", "summary": "Implemented everything and verified the result.", "artifacts": [{"type": "summary", "path": "specs/101_field-fixture/summaries/01_x.md"}], "phases_completed": 1, "phases_total": 1}
EOF
assert_field_rejected "content-check reject: blockers absent" \
  "specs/101_field-fixture/.orchestrator-handoff.json"

mkdir -p "$WORKDIR/specs/102_field-fixture/summaries"
cat > "$WORKDIR/specs/102_field-fixture/.orchestrator-handoff.json" << 'EOF'
{"status": "implemented", "artifacts": [{"type": "summary", "path": "specs/102_field-fixture/summaries/01_x.md"}], "phases_completed": 1, "phases_total": 1, "blockers": []}
EOF
assert_field_rejected "content-check reject: summary absent" \
  "specs/102_field-fixture/.orchestrator-handoff.json"

mkdir -p "$WORKDIR/specs/103_field-fixture"
printf '%s' '{not valid json' > "$WORKDIR/specs/103_field-fixture/.orchestrator-handoff.json"
assert_field_rejected "content-check reject: unparsable JSON" \
  "specs/103_field-fixture/.orchestrator-handoff.json"

# Fail-safe fixture: the sibling validator is removed from the copied layout -- the content
# check must degrade to a silent exit 0, never exit 2 on an unknowable input. Placed last among
# the content-check fixtures since it removes the validator for the remainder of the run.
mkdir -p "$WORKDIR/specs/104_field-fixture"
cat > "$WORKDIR/specs/104_field-fixture/.orchestrator-handoff.json" << 'EOF'
{"status": "implemented"}
EOF
mv "$WORKDIR/scripts/validate-handoff.sh" "$WORKDIR/scripts/validate-handoff.sh.removed"
assert_allowed_on_disk "content-check fail-safe: sibling validator removed, silent exit 0" \
  "specs/104_field-fixture/.orchestrator-handoff.json"
mv "$WORKDIR/scripts/validate-handoff.sh.removed" "$WORKDIR/scripts/validate-handoff.sh"

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
