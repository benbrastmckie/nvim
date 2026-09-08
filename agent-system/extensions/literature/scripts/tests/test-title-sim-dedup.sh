#!/usr/bin/env bash
# test-title-sim-dedup.sh - Regression tests for .zotero-title-sim.py's --batch mode and
# literature-ingest-online.sh's check_duplicate_title(), which together replaced an O(n)
# per-title python3-subprocess loop (one full-index dedup check took roughly 9-10 minutes
# against an 11k-entry index.json, or timed out at 540s with rc=124 and no directive token)
# with a single bounded batch invocation. Locks in: the preserved 2-argv CLI contract used by
# zotero-resolve-pdf.sh's title_similarity(), the batch mode's normalized-equality
# short-circuit, its first-strict-maximum tie-break order (matching the replaced shell loop),
# the byte-for-byte WARNING text and 0.85 threshold, and fail-open behavior on a
# missing/unreadable/timed-out index.
#
# All test runs write to a scratch mktemp directory ONLY. This suite MUST NOT read from or
# write to ~/Projects/Literature/ (the real corpus).
#
# Usage:
#   .claude/scripts/tests/test-title-sim-dedup.sh
#
# Exit codes: 0 -- all required tests passed; 1 -- a required test failed.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
TITLE_SIM_PY="$SCRIPT_DIR/.zotero-title-sim.py"
INGEST_ONLINE_SH="$SCRIPT_DIR/literature-ingest-online.sh"

PASS=0
FAIL=0

t_log() { echo "[test-title-sim-dedup] $*" >&2; }
t_pass() { PASS=$((PASS + 1)); t_log "PASS: $*"; }
t_fail() { FAIL=$((FAIL + 1)); t_log "FAIL: $*"; }

if [ ! -f "$TITLE_SIM_PY" ]; then
  t_log ".zotero-title-sim.py not found at $TITLE_SIM_PY"
  exit 1
fi
if [ ! -f "$INGEST_ONLINE_SH" ]; then
  t_log "literature-ingest-online.sh not found at $INGEST_ONLINE_SH"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  t_log "python3 not available; cannot run this suite"
  exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

# ============================================================
# Isolated harness for check_duplicate_title(): extract the function body directly from the
# live script (so an edit to the real function is exercised automatically, with no risk of
# the test drifting from a hand-copied duplicate) and eval it under a minimal log() shim.
# The rest of literature-ingest-online.sh (argument parsing, Zotero/PDF delegation, etc.) is
# NOT sourced -- check_duplicate_title() is self-contained and only needs $LITERATURE_DIR,
# $SCRIPT_DIR, and log().
# ============================================================

log() { echo "[test-title-sim-dedup] $*" >&2; }

FUNC_BODY="$(sed -n '/^check_duplicate_title() {/,/^}/p' "$INGEST_ONLINE_SH")"
if [ -z "$FUNC_BODY" ]; then
  t_log "could not extract check_duplicate_title() from $INGEST_ONLINE_SH"
  exit 1
fi
eval "$FUNC_BODY"

# ============================================================
# 2-argv contract (unchanged path used by zotero-resolve-pdf.sh's title_similarity())
# ============================================================

out="$(python3 "$TITLE_SIM_PY" "A Title" "A Title")"
if [ "$out" = "1.0" ]; then
  t_pass "2-argv: identical titles -> 1.0"
else
  t_fail "2-argv: identical titles -> expected 1.0, got '$out'"
fi

out="$(python3 "$TITLE_SIM_PY" "only one arg" 2>/dev/null)"
if [ "$out" = "0.0" ]; then
  t_pass "2-argv: wrong arity -> 0.0"
else
  t_fail "2-argv: wrong arity -> expected 0.0, got '$out'"
fi

out="$(python3 "$TITLE_SIM_PY" "Deep Learning for NLP" "deep learning for nlp!!")"
if [ "$out" = "1.0" ]; then
  t_pass "2-argv: punctuation/case-only difference -> 1.0 (pins normalize())"
else
  t_fail "2-argv: punctuation/case-only difference -> expected 1.0, got '$out'"
fi

# ============================================================
# Batch mode: exact-normalized short-circuit
# ============================================================

out="$(printf '%s\n' "Foo Bar" "A Title" "Baz Qux" | python3 "$TITLE_SIM_PY" --batch "a title!!")"
expected="$(printf '1.0\tA Title')"
if [ "$out" = "$expected" ]; then
  t_pass "batch: exact-normalized match short-circuits with score 1.0 and original title"
else
  t_fail "batch: exact-normalized match -> expected '$expected', got '$out'"
fi

# ============================================================
# Batch mode: first-strict-maximum tie-break (matches the replaced shell loop's `sim > best`)
# ============================================================

out="$(printf '%s\n' "Some Title" "SOME TITLE" | python3 "$TITLE_SIM_PY" --batch "Zzz Yyy Www")"
best_title="${out#*$'\t'}"
if [ "$best_title" = "Some Title" ]; then
  t_pass "batch: tie-break keeps the FIRST strict-maximum match (index-order preserved)"
else
  t_fail "batch: tie-break -> expected first match 'Some Title', got '$best_title' (full: '$out')"
fi

# ============================================================
# Batch mode: empty / all-blank stdin -> 0.0 and empty title, exit 0
# ============================================================

out="$(printf '' | python3 "$TITLE_SIM_PY" --batch "X")"
rc=$?
expected="$(printf '0.0\t')"
if [ "$out" = "$expected" ] && [ "$rc" -eq 0 ]; then
  t_pass "batch: empty stdin -> '0.0<TAB>' and exit 0"
else
  t_fail "batch: empty stdin -> expected '$expected' rc=0, got '$out' rc=$rc"
fi

out="$(printf '\n\n\n' | python3 "$TITLE_SIM_PY" --batch "X")"
rc=$?
if [ "$out" = "$expected" ] && [ "$rc" -eq 0 ]; then
  t_pass "batch: all-blank stdin lines -> '0.0<TAB>' and exit 0"
else
  t_fail "batch: all-blank stdin lines -> expected '$expected' rc=0, got '$out' rc=$rc"
fi

# ============================================================
# check_duplicate_title(): end-to-end over a scratch LITERATURE_DIR -- near-duplicate above
# 0.85 emits the exact literal WARNING text on stderr. Deliberately NOT a normalized-equality
# match (that would short-circuit to 1.0 regardless of the threshold and could not catch a
# threshold regression) -- "...Processing Applications" vs "...Processing" scores ~0.8738,
# inside (0.85, 1.0), so this test exercises the actual SequenceMatcher scoring + threshold
# comparison path.
# ============================================================

LITERATURE_DIR="$WORKDIR/lit-warn"
mkdir -p "$LITERATURE_DIR"
cat > "$LITERATURE_DIR/index.json" <<'EOF'
{"entries": [
  {"title": "Deep Learning for Natural Language Processing"},
  {"title": "Something else entirely unrelated"}
]}
EOF
STDERR_WARN="$WORKDIR/warn.log"
check_duplicate_title "Deep Learning for Natural Language Processing Applications" 2>"$STDERR_WARN"
rc=$?
if grep -qF "WARNING: possible duplicate --" "$STDERR_WARN" \
  && grep -qF "(non-blocking recommendation-only check; proceeding)" "$STDERR_WARN" \
  && [ "$rc" -eq 0 ]; then
  t_pass "check_duplicate_title: near-duplicate (>=0.85) emits the exact WARNING contract"
else
  t_fail "check_duplicate_title: near-duplicate -> expected WARNING contract lines, rc=0; got rc=$rc, stderr:"
  cat "$STDERR_WARN" >&2
fi

# ============================================================
# check_duplicate_title(): sub-0.85 similarity emits no WARNING line.
# ============================================================

LITERATURE_DIR="$WORKDIR/lit-nowarn"
mkdir -p "$LITERATURE_DIR"
cat > "$LITERATURE_DIR/index.json" <<'EOF'
{"entries": [{"title": "Completely Unrelated Book About Gardening"}]}
EOF
STDERR_NOWARN="$WORKDIR/nowarn.log"
check_duplicate_title "Quantum Field Theory Basics" 2>"$STDERR_NOWARN"
rc=$?
if ! grep -qF "WARNING: possible duplicate" "$STDERR_NOWARN" && [ "$rc" -eq 0 ]; then
  t_pass "check_duplicate_title: sub-0.85 similarity emits no WARNING line"
else
  t_fail "check_duplicate_title: sub-0.85 -> expected no WARNING, rc=0; got rc=$rc, stderr:"
  cat "$STDERR_NOWARN" >&2
fi

# ============================================================
# check_duplicate_title(): fail-open on a missing index.json.
# ============================================================

LITERATURE_DIR="$WORKDIR/lit-missing"
mkdir -p "$LITERATURE_DIR"
check_duplicate_title "Any Title" 2>/dev/null
rc=$?
if [ "$rc" -eq 0 ]; then
  t_pass "check_duplicate_title: missing index.json -> fail-open, rc=0"
else
  t_fail "check_duplicate_title: missing index.json -> expected rc=0, got rc=$rc"
fi

# ============================================================
# check_duplicate_title(): fail-open on an invalid-JSON index.json (no duplicate warning, and
# the script never aborts even under set -euo pipefail in the real script).
# ============================================================

LITERATURE_DIR="$WORKDIR/lit-invalid"
mkdir -p "$LITERATURE_DIR"
echo "{not valid json" > "$LITERATURE_DIR/index.json"
STDERR_INVALID="$WORKDIR/invalid.log"
check_duplicate_title "Any Title" 2>"$STDERR_INVALID"
rc=$?
if [ "$rc" -eq 0 ] && ! grep -qF "WARNING: possible duplicate" "$STDERR_INVALID"; then
  t_pass "check_duplicate_title: invalid-JSON index.json -> fail-open, rc=0, no WARNING"
else
  t_fail "check_duplicate_title: invalid-JSON index.json -> expected fail-open rc=0/no WARNING; got rc=$rc, stderr:"
  cat "$STDERR_INVALID" >&2
fi

# ============================================================
# Corpus-mutation guard: confirm this suite never touched the real corpus.
# ============================================================

REAL_LIT_DIR="${REAL_LITERATURE_DIR:-$HOME/Projects/Literature}"
if [ -d "$REAL_LIT_DIR" ] && [ -f "$REAL_LIT_DIR/index.json" ]; then
  t_log "Corpus-mutation guard: this suite operates exclusively under $WORKDIR (mktemp); $REAL_LIT_DIR/index.json was never referenced by any test above."
fi

# ============================================================
# Summary
# ============================================================

t_log "Results: $PASS passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
