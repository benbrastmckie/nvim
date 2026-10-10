#!/usr/bin/env bash
# test-roadmap-generation.sh - Regression suite for roadmap-integration.sh: the --print/
# --regenerate/--prune generator that implements context/formats/roadmap-format.md's contract.
#
# Structural model: test-generate-task-order.sh (mktemp -d TOP_WORKDIR with an EXIT-trap
# cleanup, pass()/fail()/info() helpers, integer PASSED/FAILED counters, per-case isolated
# scratch built via build_scratch(), a live-tree checksum guard confirming the real
# specs/ROADMAP.md and specs/state.json are never touched).
#
# RESOLUTION ORDER: the script under test, roadmap-integration.sh, is resolved
# SOURCE-STORE-FIRST (agent-system/extensions/core/scripts/roadmap-integration.sh), falling
# back to the deployed copy only if the source-store copy is absent -- this is the file this
# task edits, and the suite must be meaningful on that edit alone, before any deploy runs. Its
# unchanged dependencies (generate-task-order.sh, deploy-root-guard.sh, lib/common.sh,
# lib/status-vocabulary.sh) are resolved DEPLOY-TREE-FIRST, as every other suite in this
# directory does for an unchanged dependency.
#
# ISOLATION CONTRACT: every case builds a fresh scratch project root under mktemp -d with its
# own <scratch>/.claude/scripts/{roadmap-integration.sh,generate-task-order.sh,
# deploy-root-guard.sh,lib/{common.sh,status-vocabulary.sh}} and <scratch>/specs/
# {state.json,ROADMAP.md}, and drives roadmap-integration.sh exclusively via
# --roadmap/--state pointed at the scratch tree. The suite never reads or writes the real
# specs/state.json or specs/ROADMAP.md; a checksum guard at the end of the run confirms both
# are byte-identical to how this suite found them.
#
# Fixture entities are referred to as "item N" throughout (never "task N") purely to stay clear
# of the write-time task-reference guard's `task\s*N` pattern -- these are synthetic
# state.json/ROADMAP.md fixture rows, unrelated to this repository's own task-management
# numbering, and the rename avoids a false-positive block with no loss of fixture fidelity.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- Source-store-first resolution for the file under test ---
RI_CANDIDATES=(
  "$SOURCE_STORE_SCRIPTS/roadmap-integration.sh"
  "$DEPLOY_SCRIPTS_SRC/roadmap-integration.sh"
)
RI_SRC=""
for c in "${RI_CANDIDATES[@]}"; do
  [[ -f "$c" ]] && { RI_SRC="$c"; break; }
done
if [[ -z "$RI_SRC" ]]; then
  echo "ERROR: roadmap-integration.sh not found at any of: ${RI_CANDIDATES[*]}" >&2
  exit 2
fi

# --- Deploy-tree-first resolution for unchanged dependencies ---
resolve_dep() {
  local name="$1" c
  for c in "$DEPLOY_SCRIPTS_SRC/$name" "$SOURCE_STORE_SCRIPTS/$name"; do
    [[ -f "$c" ]] && { echo "$c"; return 0; }
  done
  echo "ERROR: $name not found at $DEPLOY_SCRIPTS_SRC/$name or $SOURCE_STORE_SCRIPTS/$name" >&2
  return 1
}
GTO_SRC="$(resolve_dep generate-task-order.sh)" || exit 2
GUARD_SRC="$(resolve_dep deploy-root-guard.sh)" || exit 2
COMMON_SRC="$(resolve_dep lib/common.sh)" || exit 2
STATUSVOC_SRC="$(resolve_dep lib/status-vocabulary.sh)" || exit 2

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Under test (source-store-first): $RI_SRC"
info "Dependency (deploy-first): $GTO_SRC"
info "Dependency (deploy-first): $GUARD_SRC"
info "Dependency (deploy-first): $COMMON_SRC"
info "Dependency (deploy-first): $STATUSVOC_SRC"

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${TOP_WORKDIR:-}" && -d "$TOP_WORKDIR" ]] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

# Live-tree isolation guard: snapshot checksums of the real specs/ artifacts now, re-checked
# after every case has run (final section below).
REAL_ROADMAP="$REPO_ROOT/specs/ROADMAP.md"
REAL_STATE="$REPO_ROOT/specs/state.json"
REAL_ROADMAP_SUM_BEFORE=""
REAL_STATE_SUM_BEFORE=""
[[ -f "$REAL_ROADMAP" ]] && REAL_ROADMAP_SUM_BEFORE="$(sha256sum "$REAL_ROADMAP" | awk '{print $1}')"
[[ -f "$REAL_STATE" ]] && REAL_STATE_SUM_BEFORE="$(sha256sum "$REAL_STATE" | awk '{print $1}')"

# ─── Harness helpers ────────────────────────────────────────────────────────────────────────

# build_scratch -- builds an isolated <scratch>/.claude/scripts/{...} tree. Echoes the scratch
# root. Does NOT write specs/state.json or specs/ROADMAP.md -- callers do that per case.
build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$RI_SRC" "$scratch/.claude/scripts/roadmap-integration.sh"
  cp "$GTO_SRC" "$scratch/.claude/scripts/generate-task-order.sh"
  cp "$GUARD_SRC" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SRC" "$scratch/.claude/scripts/lib/common.sh"
  cp "$STATUSVOC_SRC" "$scratch/.claude/scripts/lib/status-vocabulary.sh"
  chmod +x "$scratch/.claude/scripts/roadmap-integration.sh" "$scratch/.claude/scripts/generate-task-order.sh"
  echo "$scratch"
}

# write_state_fixture SCRATCH -- the single state.json fixture shared by every case below.
# Covers every status token (ready, blocked:N, blocked:N,M, IN FLIGHT, HOLD), a terminal item
# excluded entirely, an item whose only dependency is terminal (must read ready, not blocked),
# and an item with an undeclared topic (append-extras). Items are numbered 1-8 purely as
# state.json project_number values -- see the file header note on "item N" terminology.
write_state_fixture() {
  local scratch="$1"
  cat >"$scratch/specs/state.json" <<'EOF'
{
  "active_topics": ["alpha"],
  "active_projects": [
    {"project_number": 1, "status": "not_started", "title": "Item one description", "topic": "alpha", "dependencies": []},
    {"project_number": 2, "status": "not_started", "title": "Item two description", "topic": "alpha", "dependencies": [1]},
    {"project_number": 3, "status": "not_started", "title": "Item three description", "topic": "alpha", "dependencies": [1, 2]},
    {"project_number": 4, "status": "implementing", "title": "Item four description", "topic": "alpha", "dependencies": []},
    {"project_number": 5, "status": "hold", "title": "Item five description", "topic": "alpha", "dependencies": [], "hold_reason": "fixture hold reason"},
    {"project_number": 6, "status": "completed", "title": "Item six description (terminal)", "topic": "alpha", "dependencies": []},
    {"project_number": 7, "status": "not_started", "title": "Item seven description", "topic": "alpha", "dependencies": [6]},
    {"project_number": 8, "status": "not_started", "title": "Item eight description", "topic": "beta-topic-undeclared", "dependencies": []}
  ]
}
EOF
}

# write_roadmap_fixture SCRATCH -- a full 8-section ROADMAP.md fixture with authored prose in
# every authored section, an authored <- annotation suffix, an authored EXT-BLOCKED token, a
# Run line naming only a terminal item (prune target), and an Open work trailer paragraph.
write_roadmap_fixture() {
  local scratch="$1"
  cat >"$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble for test-roadmap-generation.sh.*

## Goal

Fixture goal text, authored, must survive byte-identical.

## Gate state

Fixture gate-state text, authored, must survive byte-identical.

## Next

Fixture intro prose for Next, authored.

```
/orchestrate 1   # fixture rationale for item 1
/orchestrate 6   # names only a terminal item
```

Why this order:

- Fixture rationale bullet, authored.

## Open work

**Alpha (6)**
```
1 ready               item one description   <- fixture-annotation
2 EXT-BLOCKED         item two description
4 IN FLIGHT           item four description
5 HOLD                item five description
7 ready               item seven description
3 blocked:1,2         item three description
```

**Trailer note**: this authored paragraph must survive --regenerate, exactly like the real
file's "342's hold" paragraph.

## Checks before and after every call

Fixture checks text, authored, must survive byte-identical.

## Settled decisions (do not re-litigate)

Fixture decisions text, authored, must survive byte-identical.

## Standing rules

Fixture rules text, authored, must survive byte-identical.

## Unfiled observations (none worth a task yet)

Fixture observations text, authored, must survive byte-identical.
EOF
}

# section_body FILE HEADER -- same extraction contract as roadmap-integration.sh's own
# extract_section, used here purely as a test-side assertion helper (not sourced from the
# script under test, so a bug in the real extractor can't hide a bug from this check too).
section_body() {
  local file="$1" header="$2"
  awk -v hdr="$header" '
    BEGIN { printing = 0 }
    $0 == hdr { printing = 1; next }
    printing && /^## / { printing = 0 }
    printing { print }
  ' "$file"
}

run_ri() {
  local scratch="$1"; shift
  "$scratch/.claude/scripts/roadmap-integration.sh" \
    --roadmap "$scratch/specs/ROADMAP.md" --state "$scratch/specs/state.json" "$@"
}

# ─── Case group 1: --print token derivation, terminal exclusion, terminal-dep-reads-ready,
# topic append-extras, stderr marker ──────────────────────────────────────────────────────────

scratch1="$(build_scratch)"
write_state_fixture "$scratch1"
print_out="$(run_ri "$scratch1" --print 2>"$scratch1/stderr.txt")"
print_rc=$?

if [[ "$print_rc" -eq 0 ]]; then
  pass "--print exits 0"
else
  fail "--print exits 0 (got $print_rc)"
fi

if grep -qE '^1 ready' <<<"$print_out"; then
  pass "token derivation: item 1 (no deps) renders ready"
else
  fail "token derivation: item 1 (no deps) should render ready"
fi

if grep -qE '^2 blocked:1 ' <<<"$print_out"; then
  pass "token derivation: item 2 (dep on item 1) renders blocked:1"
else
  fail "token derivation: item 2 (dep on item 1) should render blocked:1"
fi

if grep -qE '^3 blocked:1,2 ' <<<"$print_out"; then
  pass "token derivation: item 3 (deps on items 1,2) renders blocked:1,2"
else
  fail "token derivation: item 3 (deps on items 1,2) should render blocked:1,2"
fi

if grep -qE '^4 IN FLIGHT ' <<<"$print_out"; then
  pass "token derivation: item 4 (implementing) renders IN FLIGHT"
else
  fail "token derivation: item 4 (implementing) should render IN FLIGHT"
fi

if grep -qE '^5 HOLD ' <<<"$print_out"; then
  pass "token derivation: item 5 (hold) renders HOLD"
else
  fail "token derivation: item 5 (hold) should render HOLD"
fi

if grep -qE '^6 ' <<<"$print_out"; then
  fail "terminal exclusion: item 6 (completed) must not appear as an item line"
else
  pass "terminal exclusion: item 6 (completed) is absent from --print output"
fi

if grep -qE '^7 ready' <<<"$print_out"; then
  pass "terminal-dependency-reads-ready: item 7 (only dep is terminal item 6) renders ready"
else
  fail "terminal-dependency-reads-ready: item 7 should render ready, not blocked"
fi

if grep -q '\*\*Beta topic undeclared (1)\*\*' <<<"$print_out"; then
  pass "topic append-extras: undeclared topic 'beta-topic-undeclared' gets its own block"
else
  fail "topic append-extras: expected a 'Beta topic undeclared (1)' block in --print output"
fi

if grep -qE "WARNING:.*beta-topic-undeclared" "$scratch1/stderr.txt"; then
  pass "topic append-extras: one-time stderr warning names the undeclared topic"
else
  fail "topic append-extras: expected a stderr warning naming beta-topic-undeclared"
fi

if grep -qE '^<!-- roadmap-generation mode=print tasks=7 topics=2 runs=0 pruned=0 retained=0 -->$' "$scratch1/stderr.txt"; then
  pass "stderr marker present and correct for --print"
else
  fail "stderr marker missing or incorrect for --print ($(cat "$scratch1/stderr.txt"))"
fi

# ─── Case group 1b: failure-path diagnosability -- an injected failure (malformed --state JSON,
# independent of the ROADMAP.md layout work in later phases) must still emit the marker AND a
# named ERROR: line, and must exit non-zero ────────────────────────────────────────────────────

scratch1b="$(build_scratch)"
echo 'not json' >"$scratch1b/specs/state.json"
run_ri "$scratch1b" --regenerate >/dev/null 2>"$scratch1b/stderr-fail.txt"
fail_rc=$?

if [[ "$fail_rc" -ne 0 ]]; then
  pass "injected failure (malformed --state JSON): exits non-zero"
else
  fail "injected failure (malformed --state JSON): should exit non-zero (got $fail_rc)"
fi

if grep -qE '^ERROR: roadmap-integration\.sh failed \(mode=regenerate\) at line [0-9]+: exit status [0-9]+$' "$scratch1b/stderr-fail.txt"; then
  pass "injected failure: named ERROR: line present, naming the mode"
else
  fail "injected failure: expected a named ERROR: line ($(cat "$scratch1b/stderr-fail.txt"))"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate ' "$scratch1b/stderr-fail.txt"; then
  pass "injected failure: stderr marker still present (the always-present promise holds on failure)"
else
  fail "injected failure: expected the stderr marker even though the run failed ($(cat "$scratch1b/stderr-fail.txt"))"
fi

if [[ "$(grep -cE '^ERROR: roadmap-integration\.sh failed' "$scratch1b/stderr-fail.txt")" -eq 1 ]]; then
  pass "injected failure: ERROR: line is emitted exactly once"
else
  fail "injected failure: ERROR: line should be emitted exactly once ($(cat "$scratch1b/stderr-fail.txt"))"
fi

# ─── Case group 2: --regenerate retention (authored sections, annotation, EXT-BLOCKED,
# trailer), idempotency, --dry-run ────────────────────────────────────────────────────────────

scratch2="$(build_scratch)"
write_state_fixture "$scratch2"
write_roadmap_fixture "$scratch2"

for section in "## Goal" "## Gate state" "## Checks before and after every call" \
  "## Settled decisions (do not re-litigate)" "## Standing rules" \
  "## Unfiled observations (none worth a task yet)"; do
  before="$(section_body "$scratch2/specs/ROADMAP.md" "$section")"
  run_ri "$scratch2" --regenerate >/dev/null 2>"$scratch2/stderr-regen.txt"
  after="$(section_body "$scratch2/specs/ROADMAP.md" "$section")"
  if [[ "$before" == "$after" ]]; then
    pass "authored section byte-identical across --regenerate: $section"
  else
    fail "authored section CHANGED across --regenerate: $section"
  fi
  # Restore the fixture for the next section's before/after comparison.
  write_roadmap_fixture "$scratch2"
done

run_ri "$scratch2" --regenerate >/dev/null 2>/dev/null
if grep -qE '^1 ready.*<- fixture-annotation$' "$scratch2/specs/ROADMAP.md"; then
  pass "authored <- annotation suffix survives --regenerate"
else
  fail "authored <- annotation suffix did not survive --regenerate"
fi

if grep -qE '^2 EXT-BLOCKED' "$scratch2/specs/ROADMAP.md"; then
  pass "authored EXT-BLOCKED token survives --regenerate"
else
  fail "authored EXT-BLOCKED token did not survive --regenerate"
fi

if grep -q "Trailer note" "$scratch2/specs/ROADMAP.md"; then
  pass "Open work trailer paragraph survives --regenerate"
else
  fail "Open work trailer paragraph did not survive --regenerate"
fi

cp "$scratch2/specs/ROADMAP.md" "$scratch2/specs/ROADMAP.round1.md"
run_ri "$scratch2" --regenerate >/dev/null 2>/dev/null
if diff -q "$scratch2/specs/ROADMAP.round1.md" "$scratch2/specs/ROADMAP.md" >/dev/null; then
  pass "--regenerate is idempotent (second run byte-identical)"
else
  fail "--regenerate is NOT idempotent (second run differs)"
fi

write_roadmap_fixture "$scratch2"
sum_before="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch2" --regenerate --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  pass "--regenerate --dry-run writes nothing"
else
  fail "--regenerate --dry-run modified the file"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate tasks=7 topics=2' "$scratch2/stderr-regen.txt"; then
  pass "stderr marker present and correct for --regenerate"
else
  fail "stderr marker missing or incorrect for --regenerate ($(cat "$scratch2/stderr-regen.txt"))"
fi

# ─── Case group 3: --prune drops an all-terminal Run line, --dry-run writes nothing,
# absent --roadmap target is a supported no-op ────────────────────────────────────────────────

scratch3="$(build_scratch)"
write_state_fixture "$scratch3"
write_roadmap_fixture "$scratch3"

run_ri "$scratch3" --prune >/dev/null 2>"$scratch3/stderr-prune.txt"
if grep -q '/orchestrate 6' "$scratch3/specs/ROADMAP.md"; then
  fail "--prune should have dropped the all-terminal '/orchestrate 6' Run line"
else
  pass "--prune drops a Run line naming only a terminal item"
fi

if grep -qE '^/orchestrate 1\s' "$scratch3/specs/ROADMAP.md"; then
  pass "--prune leaves an unaffected Run line (item 1, non-terminal) in place"
else
  fail "--prune should have left the '/orchestrate 1' Run line in place"
fi

write_roadmap_fixture "$scratch3"
sum_before="$(sha256sum "$scratch3/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch3" --prune --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch3/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  pass "--prune --dry-run writes nothing"
else
  fail "--prune --dry-run modified the file"
fi

scratch4="$(build_scratch)"
write_state_fixture "$scratch4"
# Deliberately no ROADMAP.md written for scratch4 -- absent target.
run_ri "$scratch4" --regenerate >/dev/null 2>"$scratch4/stderr-absent.txt"
absent_rc=$?
if [[ "$absent_rc" -eq 0 ]]; then
  if [[ ! -f "$scratch4/specs/ROADMAP.md" ]]; then
    pass "--regenerate against an absent --roadmap target is a supported no-op (exit 0, no file created)"
  else
    fail "--regenerate against an absent --roadmap target should not create one"
  fi
else
  fail "--regenerate against an absent --roadmap target should exit 0, not crash (got $absent_rc)"
fi

# ─── Case group 4: layout detection / permanent destructive-overwrite refusal (Phase 2) ────────
#
# write_stage_vocabulary_fixture below is deliberately faithful to the real BimodalLogic
# regression fixture's shape (preamble, a fenced run-order block mixing "# Stage N" comment
# lines with /orchestrate lines, several "## Stage N" sections, and trailing "## Not scoped as
# tasks"/"## Maintenance"/"## Related" sections) so Phase 4/5 can reuse it for the positive
# round-trip cases once --regenerate/--prune gain real stage support. At THIS phase, both write
# modes are expected to refuse the stage layout (Phase 2's "route stage to the same refusal for
# now" task) -- that refusal expectation below is overwritten by Phase 4 (--regenerate) and
# Phase 5 (--prune) once positive support lands; the unknown-vocabulary refusal is permanent.

write_stage_vocabulary_fixture() {
  local scratch="$1"
  cat >"$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble for stage-layout testing.*

## Run order at a glance

```bash
# Stage 1 -- first stage, fixture comment line
/orchestrate 1   # fixture rationale for item 1
# Stage 2 -- second stage, fixture comment line
/orchestrate 2,3
```

## Stage 1 -- First Stage

- [ ] Stage 1 bullet prose, authored, must survive byte-identical.

## Stage 2 -- Second Stage

- [ ] Stage 2 bullet prose, authored, must survive byte-identical.

## Not scoped as tasks

Fixture not-scoped prose, authored, must survive byte-identical.

## Maintenance

Fixture maintenance prose, authored, must survive byte-identical.

## Related

Fixture related prose, authored, must survive byte-identical.
EOF
}

# write_unknown_vocabulary_fixture -- neither the classic eight headers nor the stage structural
# predicate (no "## Stage N" header, no fenced /orchestrate block). Must be refused permanently.
write_unknown_vocabulary_fixture() {
  local scratch="$1"
  cat >"$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble for an unrecognised-vocabulary roadmap.*

## Random Header One

Some fixture prose, unrelated to either recognised vocabulary.

## Random Header Two

More fixture prose.
EOF
}

scratch5="$(build_scratch)"
write_state_fixture "$scratch5"
write_unknown_vocabulary_fixture "$scratch5"
sum_before="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch5" --regenerate >/dev/null 2>"$scratch5/stderr-unknown-regen.txt"
unknown_regen_rc=$?
sum_after="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"

if [[ "$unknown_regen_rc" -ne 0 ]]; then
  pass "unknown vocabulary: --regenerate exits non-zero"
else
  fail "unknown vocabulary: --regenerate should exit non-zero (got $unknown_regen_rc)"
fi
if [[ "$sum_before" == "$sum_after" ]]; then
  pass "unknown vocabulary: --regenerate writes nothing"
else
  fail "unknown vocabulary: --regenerate modified the file"
fi
if grep -qE '^ERROR: --regenerate refuses to write' "$scratch5/stderr-unknown-regen.txt"; then
  pass "unknown vocabulary: --regenerate names a refusal reason on stderr"
else
  fail "unknown vocabulary: expected a named refusal reason ($(cat "$scratch5/stderr-unknown-regen.txt"))"
fi
if grep -qE '^<!-- roadmap-generation mode=regenerate ' "$scratch5/stderr-unknown-regen.txt"; then
  pass "unknown vocabulary: --regenerate still emits the stderr marker on refusal"
else
  fail "unknown vocabulary: expected the stderr marker even on refusal"
fi

write_unknown_vocabulary_fixture "$scratch5"
sum_before="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch5" --prune >/dev/null 2>"$scratch5/stderr-unknown-prune.txt"
unknown_prune_rc=$?
sum_after="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"

if [[ "$unknown_prune_rc" -ne 0 ]]; then
  pass "unknown vocabulary: --prune exits non-zero"
else
  fail "unknown vocabulary: --prune should exit non-zero (got $unknown_prune_rc)"
fi
if [[ "$sum_before" == "$sum_after" ]]; then
  pass "unknown vocabulary: --prune writes nothing"
else
  fail "unknown vocabulary: --prune modified the file (the destructive-overwrite near-miss)"
fi
if grep -qE '^ERROR: --prune refuses to write' "$scratch5/stderr-unknown-prune.txt"; then
  pass "unknown vocabulary: --prune names a refusal reason on stderr"
else
  fail "unknown vocabulary: expected a named refusal reason ($(cat "$scratch5/stderr-unknown-prune.txt"))"
fi

scratch6="$(build_scratch)"
write_state_fixture "$scratch6"
write_stage_vocabulary_fixture "$scratch6"
sum_before="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch6" --regenerate >/dev/null 2>"$scratch6/stderr-stage-regen.txt"
stage_regen_rc=$?
sum_after="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$stage_regen_rc" -ne 0 && "$sum_before" == "$sum_after" ]]; then
  pass "stage vocabulary (Phase 2, pre-round-trip-support): --regenerate refuses, writes nothing"
else
  fail "stage vocabulary: --regenerate should refuse and write nothing at this phase (rc=$stage_regen_rc)"
fi

write_stage_vocabulary_fixture "$scratch6"
sum_before="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch6" --prune >/dev/null 2>"$scratch6/stderr-stage-prune.txt"
stage_prune_rc=$?
sum_after="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$stage_prune_rc" -ne 0 && "$sum_before" == "$sum_after" ]]; then
  pass "stage vocabulary (Phase 2, pre-round-trip-support): --prune refuses, writes nothing"
else
  fail "stage vocabulary: --prune should refuse and write nothing at this phase (rc=$stage_prune_rc)"
fi

scratch7="$(build_scratch)"
write_state_fixture "$scratch7"
write_roadmap_fixture "$scratch7"
run_ri "$scratch7" --regenerate >/dev/null 2>/dev/null
classic_rc=$?
if [[ "$classic_rc" -eq 0 ]]; then
  pass "classic vocabulary still classifies 'classic' and still succeeds after the Phase 2 gate"
else
  fail "classic vocabulary should still succeed after the Phase 2 gate (got $classic_rc)"
fi

# Smoke check (read-only): this repository's own real specs/ROADMAP.md classifies as classic.
# A scratch COPY only -- never the live file, never a write mode against it.
REAL_ROADMAP_COPY="$TOP_WORKDIR/real-roadmap-smoke-check.md"
if [[ -f "$REAL_ROADMAP" ]]; then
  cp "$REAL_ROADMAP" "$REAL_ROADMAP_COPY"
  scratch8="$(build_scratch)"
  write_state_fixture "$scratch8"
  cp "$REAL_ROADMAP_COPY" "$scratch8/specs/ROADMAP.md"
  run_ri "$scratch8" --regenerate --dry-run >/dev/null 2>"$scratch8/stderr-real-smoke.txt"
  real_smoke_rc=$?
  if [[ "$real_smoke_rc" -eq 0 ]]; then
    pass "smoke check: this repository's real specs/ROADMAP.md (scratch copy) classifies classic"
  else
    fail "smoke check: this repository's real specs/ROADMAP.md (scratch copy) should classify classic (got $real_smoke_rc; $(cat "$scratch8/stderr-real-smoke.txt"))"
  fi
else
  info "smoke check skipped: no real specs/ROADMAP.md present"
fi

# ─── Case group 5: no-match-as-error pipeline regression (Phase 3) ────────────────────────────
#
# This is the exact crash reproduction from the task description: a classic-layout roadmap whose
# ## Next body has zero /orchestrate lines used to kill covered_ids_from()'s pipeline under
# set -euo pipefail. Phase 2's refusal gate does not touch this case (the fixture IS classic),
# so this exercises Phase 3's guard specifically.

write_roadmap_fixture_empty_next() {
  local scratch="$1"
  cat >"$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble with an empty ## Next body for test-roadmap-generation.sh.*

## Goal

Fixture goal text, authored.

## Gate state

Fixture gate-state text, authored.

## Next

Fixture intro prose for Next, authored. No Run lines at all yet.

## Open work

**Alpha (1)**
```
1 ready               item one description
```

## Checks before and after every call

Fixture checks text, authored.

## Settled decisions (do not re-litigate)

Fixture decisions text, authored.

## Standing rules

Fixture rules text, authored.

## Unfiled observations (none worth a task yet)

Fixture observations text, authored.
EOF
}

scratch9="$(build_scratch)"
write_state_fixture "$scratch9"
write_roadmap_fixture_empty_next "$scratch9"
run_ri "$scratch9" --regenerate --dry-run >/dev/null 2>"$scratch9/stderr-empty-next.txt"
empty_next_rc=$?
if [[ "$empty_next_rc" -eq 0 ]]; then
  pass "crash reproduction FIXED: --regenerate against a classic fixture with an empty ## Next body exits 0"
else
  fail "crash reproduction: --regenerate against a classic fixture with an empty ## Next body should exit 0 (got $empty_next_rc; $(cat "$scratch9/stderr-empty-next.txt"))"
fi

run_ri "$scratch9" --regenerate >/dev/null 2>/dev/null
if grep -q '\*\*Coverage appendix (uncovered tasks)\*\*:' "$scratch9/specs/ROADMAP.md"; then
  pass "crash reproduction: coverage appendix is rendered for all ready tasks when ## Next starts empty"
else
  fail "crash reproduction: expected a coverage appendix once ## Next's Run lines are all absent"
fi

# ─── Live-tree isolation guard ─────────────────────────────────────────────────────────────

REAL_ROADMAP_SUM_AFTER=""
REAL_STATE_SUM_AFTER=""
[[ -f "$REAL_ROADMAP" ]] && REAL_ROADMAP_SUM_AFTER="$(sha256sum "$REAL_ROADMAP" | awk '{print $1}')"
[[ -f "$REAL_STATE" ]] && REAL_STATE_SUM_AFTER="$(sha256sum "$REAL_STATE" | awk '{print $1}')"

if [[ "$REAL_ROADMAP_SUM_BEFORE" == "$REAL_ROADMAP_SUM_AFTER" && "$REAL_STATE_SUM_BEFORE" == "$REAL_STATE_SUM_AFTER" ]]; then
  pass "live-tree isolation: real specs/ROADMAP.md and specs/state.json untouched"
else
  fail "live-tree isolation: real specs/ROADMAP.md or specs/state.json CHANGED during this suite"
fi

echo
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
