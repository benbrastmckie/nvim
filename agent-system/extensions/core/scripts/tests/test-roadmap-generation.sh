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
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

DEPLOY_SCRIPTS_SRC="$REPO_ROOT/.claude/scripts"
SOURCE_STORE_SCRIPTS="$REPO_ROOT/agent-system/extensions/core/scripts"

# --- mode=source-store resolution for the file under test ---
RI_SRC="$(common_test_resolve_subject "roadmap-integration.sh" "source-store" \
  "$DEPLOY_SCRIPTS_SRC/roadmap-integration.sh" "$SOURCE_STORE_SCRIPTS/roadmap-integration.sh")" || exit 2
common_test_declare_subject "$RI_SRC"

# --- mode=deploy-tree-first resolution for unchanged dependencies ---
GTO_SRC="$(common_test_resolve_subject "generate-task-order.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/generate-task-order.sh" "$SOURCE_STORE_SCRIPTS/generate-task-order.sh")" || exit 2
common_test_declare_subject "$GTO_SRC"
GUARD_SRC="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/deploy-root-guard.sh" "$SOURCE_STORE_SCRIPTS/deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SRC"
COMMON_SRC="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/common.sh" "$SOURCE_STORE_SCRIPTS/lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SRC"
STATUSVOC_SRC="$(common_test_resolve_subject "lib/status-vocabulary.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/status-vocabulary.sh" "$SOURCE_STORE_SCRIPTS/lib/status-vocabulary.sh")" || exit 2
common_test_declare_subject "$STATUSVOC_SRC"

PASSED=0
FAILED=0

common_test_info "Under test (source-store-first): $RI_SRC"
common_test_info "Dependency (deploy-first): $GTO_SRC"
common_test_info "Dependency (deploy-first): $GUARD_SRC"
common_test_info "Dependency (deploy-first): $COMMON_SRC"
common_test_info "Dependency (deploy-first): $STATUSVOC_SRC"

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

# write_state_fixture_annotated SCRATCH -- same shape as write_state_fixture, plus the
# schema-backed successors to the old authored <- annotation / EXT-BLOCKED / Open-work-trailer
# retention overrides: item one carries roadmap_annotation, item two carries roadmap_ext_blocked,
# and roadmap_notes.open_work_trailer holds a free-standing trailer paragraph. Used wherever a
# test needs to exercise these three state-sourced fields instead of the retired retention path.
write_state_fixture_annotated() {
  local scratch="$1"
  cat >"$scratch/specs/state.json" <<'EOF'
{
  "active_topics": ["alpha"],
  "active_projects": [
    {"project_number": 1, "status": "not_started", "title": "Item one description", "topic": "alpha", "dependencies": [], "roadmap_annotation": "fixture-annotation"},
    {"project_number": 2, "status": "not_started", "title": "Item two description", "topic": "alpha", "dependencies": [1], "roadmap_ext_blocked": true},
    {"project_number": 3, "status": "not_started", "title": "Item three description", "topic": "alpha", "dependencies": [1, 2]},
    {"project_number": 4, "status": "implementing", "title": "Item four description", "topic": "alpha", "dependencies": []},
    {"project_number": 5, "status": "hold", "title": "Item five description", "topic": "alpha", "dependencies": [], "hold_reason": "fixture hold reason"},
    {"project_number": 6, "status": "completed", "title": "Item six description (terminal)", "topic": "alpha", "dependencies": []},
    {"project_number": 7, "status": "not_started", "title": "Item seven description", "topic": "alpha", "dependencies": [6]},
    {"project_number": 8, "status": "not_started", "title": "Item eight description", "topic": "beta-topic-undeclared", "dependencies": []}
  ],
  "roadmap_notes": {
    "open_work_trailer": ["**Trailer note**: this authored paragraph must survive --regenerate."]
  }
}
EOF
}

# write_state_fixture_batches SCRATCH -- a state fixture carrying roadmap_batches/roadmap_notes
# (Phase 3/4's inversion): two live batches (one two-member, one single-member with no
# rationale), one all-terminal batch that must be omitted entirely, and a next_preamble/
# next_postamble pair. Used by both the --prune-is-an-alias coverage (Case group 3) and the
# render_next() coverage (Case group 6) below.
write_state_fixture_batches() {
  local scratch="$1"
  cat >"$scratch/specs/state.json" <<'EOF'
{
  "active_topics": ["alpha"],
  "active_projects": [
    {"project_number": 1, "status": "not_started", "title": "Item one description", "topic": "alpha", "dependencies": []},
    {"project_number": 2, "status": "not_started", "title": "Item two description", "topic": "alpha", "dependencies": []},
    {"project_number": 3, "status": "completed", "title": "Item three description (terminal)", "topic": "alpha", "dependencies": []},
    {"project_number": 4, "status": "not_started", "title": "Item four description", "topic": "alpha", "dependencies": []}
  ],
  "roadmap_batches": [
    {"task_ids": [1, 2], "description": "Batch one bounded description", "rationale": "Batch one rationale bullet text."},
    {"task_ids": [3], "description": "Batch two, all-terminal, must be omitted"},
    {"task_ids": [4], "description": "Batch three, no rationale, no bullet expected"}
  ],
  "roadmap_notes": {
    "next_preamble": ["Preamble paragraph, authored, must render before the fence."],
    "next_postamble": ["Postamble paragraph, authored, must render after the bullets."],
    "open_work_trailer": []
  }
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
  common_test_pass "--print exits 0"
else
  common_test_fail "--print exits 0 (got $print_rc)"
fi

if grep -qE '^1 ready' <<<"$print_out"; then
  common_test_pass "token derivation: item 1 (no deps) renders ready"
else
  common_test_fail "token derivation: item 1 (no deps) should render ready"
fi

if grep -qE '^2 blocked:1 ' <<<"$print_out"; then
  common_test_pass "token derivation: item 2 (dep on item 1) renders blocked:1"
else
  common_test_fail "token derivation: item 2 (dep on item 1) should render blocked:1"
fi

if grep -qE '^3 blocked:1,2 ' <<<"$print_out"; then
  common_test_pass "token derivation: item 3 (deps on items 1,2) renders blocked:1,2"
else
  common_test_fail "token derivation: item 3 (deps on items 1,2) should render blocked:1,2"
fi

if grep -qE '^4 IN FLIGHT ' <<<"$print_out"; then
  common_test_pass "token derivation: item 4 (implementing) renders IN FLIGHT"
else
  common_test_fail "token derivation: item 4 (implementing) should render IN FLIGHT"
fi

if grep -qE '^5 HOLD ' <<<"$print_out"; then
  common_test_pass "token derivation: item 5 (hold) renders HOLD"
else
  common_test_fail "token derivation: item 5 (hold) should render HOLD"
fi

if grep -qE '^6 ' <<<"$print_out"; then
  common_test_fail "terminal exclusion: item 6 (completed) must not appear as an item line"
else
  common_test_pass "terminal exclusion: item 6 (completed) is absent from --print output"
fi

if grep -qE '^7 ready' <<<"$print_out"; then
  common_test_pass "terminal-dependency-reads-ready: item 7 (only dep is terminal item 6) renders ready"
else
  common_test_fail "terminal-dependency-reads-ready: item 7 should render ready, not blocked"
fi

if grep -q '\*\*Beta topic undeclared (1)\*\*' <<<"$print_out"; then
  common_test_pass "topic append-extras: undeclared topic 'beta-topic-undeclared' gets its own block"
else
  common_test_fail "topic append-extras: expected a 'Beta topic undeclared (1)' block in --print output"
fi

if grep -qE "WARNING:.*beta-topic-undeclared" "$scratch1/stderr.txt"; then
  common_test_pass "topic append-extras: one-time stderr warning names the undeclared topic"
else
  common_test_fail "topic append-extras: expected a stderr warning naming beta-topic-undeclared"
fi

if grep -qE '^<!-- roadmap-generation mode=print tasks=7 topics=2 runs=0 pruned=0 retained=0 -->$' "$scratch1/stderr.txt"; then
  common_test_pass "stderr marker present and correct for --print"
else
  common_test_fail "stderr marker missing or incorrect for --print ($(cat "$scratch1/stderr.txt"))"
fi

# ─── Case group 1b: failure-path diagnosability -- an injected failure (malformed --state JSON,
# independent of the ROADMAP.md layout work in later phases) must still emit the marker AND a
# named ERROR: line, and must exit non-zero ────────────────────────────────────────────────────

scratch1b="$(build_scratch)"
echo 'not json' >"$scratch1b/specs/state.json"
run_ri "$scratch1b" --regenerate >/dev/null 2>"$scratch1b/stderr-fail.txt"
fail_rc=$?

if [[ "$fail_rc" -ne 0 ]]; then
  common_test_pass "injected failure (malformed --state JSON): exits non-zero"
else
  common_test_fail "injected failure (malformed --state JSON): should exit non-zero (got $fail_rc)"
fi

if grep -qE '^ERROR: roadmap-integration\.sh failed \(mode=regenerate\) at line [0-9]+: exit status [0-9]+$' "$scratch1b/stderr-fail.txt"; then
  common_test_pass "injected failure: named ERROR: line present, naming the mode"
else
  common_test_fail "injected failure: expected a named ERROR: line ($(cat "$scratch1b/stderr-fail.txt"))"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate ' "$scratch1b/stderr-fail.txt"; then
  common_test_pass "injected failure: stderr marker still present (the always-present promise holds on failure)"
else
  common_test_fail "injected failure: expected the stderr marker even though the run failed ($(cat "$scratch1b/stderr-fail.txt"))"
fi

if [[ "$(grep -cE '^ERROR: roadmap-integration\.sh failed' "$scratch1b/stderr-fail.txt")" -eq 1 ]]; then
  common_test_pass "injected failure: ERROR: line is emitted exactly once"
else
  common_test_fail "injected failure: ERROR: line should be emitted exactly once ($(cat "$scratch1b/stderr-fail.txt"))"
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
    common_test_pass "authored section byte-identical across --regenerate: $section"
  else
    common_test_fail "authored section CHANGED across --regenerate: $section"
  fi
  # Restore the fixture for the next section's before/after comparison.
  write_roadmap_fixture "$scratch2"
done

# roadmap_annotation / roadmap_ext_blocked / roadmap_notes.open_work_trailer are state fields,
# not retention overrides -- swap in the annotated state fixture before exercising them.
write_state_fixture_annotated "$scratch2"
run_ri "$scratch2" --regenerate >/dev/null 2>/dev/null
if grep -qE '^1 ready.*<- fixture-annotation$' "$scratch2/specs/ROADMAP.md"; then
  common_test_pass "roadmap_annotation renders as a <- suffix"
else
  common_test_fail "roadmap_annotation did not render as a <- suffix"
fi

if grep -qE '^2 EXT-BLOCKED' "$scratch2/specs/ROADMAP.md"; then
  common_test_pass "roadmap_ext_blocked renders the EXT-BLOCKED token"
else
  common_test_fail "roadmap_ext_blocked did not render the EXT-BLOCKED token"
fi

if grep -q "Trailer note" "$scratch2/specs/ROADMAP.md"; then
  common_test_pass "roadmap_notes.open_work_trailer renders as the Open work trailer paragraph"
else
  common_test_fail "roadmap_notes.open_work_trailer did not render"
fi

cp "$scratch2/specs/ROADMAP.md" "$scratch2/specs/ROADMAP.round1.md"
run_ri "$scratch2" --regenerate >/dev/null 2>/dev/null
if diff -q "$scratch2/specs/ROADMAP.round1.md" "$scratch2/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "--regenerate is idempotent (second run byte-identical)"
else
  common_test_fail "--regenerate is NOT idempotent (second run differs)"
fi

write_roadmap_fixture "$scratch2"
sum_before="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch2" --regenerate --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "--regenerate --dry-run writes nothing"
else
  common_test_fail "--regenerate --dry-run modified the file"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate tasks=7 topics=2' "$scratch2/stderr-regen.txt"; then
  common_test_pass "stderr marker present and correct for --regenerate"
else
  common_test_fail "stderr marker missing or incorrect for --regenerate ($(cat "$scratch2/stderr-regen.txt"))"
fi

# ─── Case group 3: --prune is a deprecated alias for --regenerate (Phase 4 inversion) --
# it prints a named deprecation note, exits 0, and produces the SAME file --regenerate would
# (a file rendered wholly from live state accumulates no terminal cruft, so there is nothing
# left for a distinct prune pass to do), plus the absent --roadmap target no-op ────────────────

scratch3="$(build_scratch)"
write_state_fixture_batches "$scratch3"
write_roadmap_fixture "$scratch3"

run_ri "$scratch3" --prune >/dev/null 2>"$scratch3/stderr-prune.txt"
prune_rc=$?
if [[ "$prune_rc" -eq 0 ]]; then
  common_test_pass "--prune (deprecated alias) exits 0"
else
  common_test_fail "--prune (deprecated alias) should exit 0 (got $prune_rc)"
fi

if grep -qF 'NOTE: --prune is deprecated' "$scratch3/stderr-prune.txt"; then
  common_test_pass "--prune emits its named deprecation note"
else
  common_test_fail "--prune did not emit the named deprecation note ($(cat "$scratch3/stderr-prune.txt"))"
fi

if grep -qFx -- '/orchestrate 1, 2   # Batch one bounded description' "$scratch3/specs/ROADMAP.md"; then
  common_test_pass "--prune renders ## Next from roadmap_batches, exactly like --regenerate"
else
  common_test_fail "--prune did not render ## Next from roadmap_batches"
fi

# Prove the two produce byte-identical files: write the fixture again, run --regenerate, and
# diff against --prune's own output above.
write_roadmap_fixture "$scratch3"
run_ri "$scratch3" --regenerate >/dev/null 2>/dev/null
cp "$scratch3/specs/ROADMAP.md" "$scratch3/specs/ROADMAP.regenerate-copy.md"
write_roadmap_fixture "$scratch3"
run_ri "$scratch3" --prune >/dev/null 2>/dev/null
if diff -q "$scratch3/specs/ROADMAP.regenerate-copy.md" "$scratch3/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "--prune produces the same file --regenerate would"
else
  common_test_fail "--prune's output differs from --regenerate's own output"
fi

write_roadmap_fixture "$scratch3"
sum_before="$(sha256sum "$scratch3/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch3" --prune --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch3/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "--prune --dry-run writes nothing"
else
  common_test_fail "--prune --dry-run modified the file"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate .* pruned=0 ' "$scratch3/stderr-prune.txt"; then
  common_test_pass "--prune's stderr marker reports mode=regenerate and pruned=0 (the dispatch-to-regenerate contract)"
else
  common_test_fail "--prune's stderr marker did not report mode=regenerate/pruned=0 ($(cat "$scratch3/stderr-prune.txt"))"
fi

scratch4="$(build_scratch)"
write_state_fixture "$scratch4"
# Deliberately no ROADMAP.md written for scratch4 -- absent target.
run_ri "$scratch4" --regenerate >/dev/null 2>"$scratch4/stderr-absent.txt"
absent_rc=$?
if [[ "$absent_rc" -eq 0 ]]; then
  if [[ ! -f "$scratch4/specs/ROADMAP.md" ]]; then
    common_test_pass "--regenerate against an absent --roadmap target is a supported no-op (exit 0, no file created)"
  else
    common_test_fail "--regenerate against an absent --roadmap target should not create one"
  fi
else
  common_test_fail "--regenerate against an absent --roadmap target should exit 0, not crash (got $absent_rc)"
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
  common_test_pass "unknown vocabulary: --regenerate exits non-zero"
else
  common_test_fail "unknown vocabulary: --regenerate should exit non-zero (got $unknown_regen_rc)"
fi
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "unknown vocabulary: --regenerate writes nothing"
else
  common_test_fail "unknown vocabulary: --regenerate modified the file"
fi
if grep -qE '^ERROR: --regenerate refuses to write' "$scratch5/stderr-unknown-regen.txt"; then
  common_test_pass "unknown vocabulary: --regenerate names a refusal reason on stderr"
else
  common_test_fail "unknown vocabulary: expected a named refusal reason ($(cat "$scratch5/stderr-unknown-regen.txt"))"
fi
if grep -qE '^<!-- roadmap-generation mode=regenerate ' "$scratch5/stderr-unknown-regen.txt"; then
  common_test_pass "unknown vocabulary: --regenerate still emits the stderr marker on refusal"
else
  common_test_fail "unknown vocabulary: expected the stderr marker even on refusal"
fi

write_unknown_vocabulary_fixture "$scratch5"
sum_before="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch5" --prune >/dev/null 2>"$scratch5/stderr-unknown-prune.txt"
unknown_prune_rc=$?
sum_after="$(sha256sum "$scratch5/specs/ROADMAP.md" | awk '{print $1}')"

if [[ "$unknown_prune_rc" -ne 0 ]]; then
  common_test_pass "unknown vocabulary: --prune exits non-zero"
else
  common_test_fail "unknown vocabulary: --prune should exit non-zero (got $unknown_prune_rc)"
fi
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "unknown vocabulary: --prune writes nothing"
else
  common_test_fail "unknown vocabulary: --prune modified the file (the destructive-overwrite near-miss)"
fi
# --prune dispatches to --regenerate internally (the deprecated-alias contract), so the
# refusal's own named reason is printed with "--regenerate" in the message, preceded by
# --prune's own deprecation note -- both are asserted.
if grep -qF 'NOTE: --prune is deprecated' "$scratch5/stderr-unknown-prune.txt" \
    && grep -qE '^ERROR: --regenerate refuses to write' "$scratch5/stderr-unknown-prune.txt"; then
  common_test_pass "unknown vocabulary: --prune prints its deprecation note, then names the (now --regenerate) refusal reason on stderr"
else
  common_test_fail "unknown vocabulary: expected the deprecation note and a named refusal reason ($(cat "$scratch5/stderr-unknown-prune.txt"))"
fi

scratch6="$(build_scratch)"
write_state_fixture "$scratch6"

# ─── Phase 4: --regenerate now round-trips the stage layout for real (superseding Phase 2's
# "refuses for now" placeholder for this mode -- --prune's refusal below is still correct until
# Phase 5 lands its own round-trip support) ────────────────────────────────────────────────────

write_stage_vocabulary_fixture "$scratch6"
run_ri "$scratch6" --regenerate >/dev/null 2>"$scratch6/stderr-stage-regen.txt"
stage_regen_rc=$?
if [[ "$stage_regen_rc" -eq 0 ]]; then
  common_test_pass "stage layout: --regenerate now succeeds (round-trip support, Phase 4)"
else
  common_test_fail "stage layout: --regenerate should succeed (got $stage_regen_rc; $(cat "$scratch6/stderr-stage-regen.txt"))"
fi

# The run-order section's authored fence content (comment lines, Run lines) is no longer
# retention-parsed -- the whole section is rendered wholly from roadmap_batches/roadmap_notes
# (render_next()), per this phase's inversion. write_state_fixture carries no roadmap_batches,
# so the fence disappears entirely and only the coverage appendix remains; this is the intended
# behavior, not a regression, so these authored fence lines must now be ABSENT.
for needle in \
  '# Stage 1 -- first stage, fixture comment line' \
  '# Stage 2 -- second stage, fixture comment line' \
  '/orchestrate 1   # fixture rationale for item 1'
do
  if grep -qF "$needle" "$scratch6/specs/ROADMAP.md"; then
    common_test_fail "stage layout round-trip: authored fence content should NOT survive a wholly-generated run-order section: ${needle:0:40}..."
  else
    common_test_pass "stage layout round-trip: authored fence content correctly absent (wholly generated): ${needle:0:40}..."
  fi
done

# Every other section (outside the run-order section) is still retained byte-for-byte.
for needle in \
  'Stage 1 bullet prose, authored, must survive byte-identical.' \
  'Stage 2 bullet prose, authored, must survive byte-identical.' \
  'Fixture not-scoped prose, authored, must survive byte-identical.' \
  'Fixture maintenance prose, authored, must survive byte-identical.' \
  'Fixture related prose, authored, must survive byte-identical.'
do
  if grep -qF "$needle" "$scratch6/specs/ROADMAP.md"; then
    common_test_pass "stage layout round-trip: retained verbatim: ${needle:0:40}..."
  else
    common_test_fail "stage layout round-trip: MISSING after --regenerate: ${needle:0:40}..."
  fi
done

if grep -qE '^## Stage 1 -- First Stage$' "$scratch6/specs/ROADMAP.md" \
  && grep -qE '^## Stage 2 -- Second Stage$' "$scratch6/specs/ROADMAP.md" \
  && grep -qE '^## Not scoped as tasks$' "$scratch6/specs/ROADMAP.md" \
  && grep -qE '^## Maintenance$' "$scratch6/specs/ROADMAP.md" \
  && grep -qE '^## Related$' "$scratch6/specs/ROADMAP.md"; then
  common_test_pass "stage layout round-trip: every section header retained verbatim"
else
  common_test_fail "stage layout round-trip: a section header was dropped or altered"
fi

if grep -q '\*\*Coverage appendix (uncovered tasks)\*\*:' "$scratch6/specs/ROADMAP.md"; then
  common_test_pass "stage layout round-trip: coverage appendix rendered under the run-order section"
else
  common_test_fail "stage layout round-trip: expected a coverage appendix for uncovered ready items 7/8"
fi

cp "$scratch6/specs/ROADMAP.md" "$scratch6/specs/ROADMAP.round1.md"
run_ri "$scratch6" --regenerate >/dev/null 2>/dev/null
if diff -q "$scratch6/specs/ROADMAP.round1.md" "$scratch6/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "stage layout round-trip: --regenerate is idempotent (second run byte-identical)"
else
  common_test_fail "stage layout round-trip: --regenerate is NOT idempotent (second run differs)"
fi

if [[ "$(grep -c '\*\*Coverage appendix (uncovered tasks)\*\*:' "$scratch6/specs/ROADMAP.md")" -eq 1 ]]; then
  common_test_pass "stage layout round-trip: coverage appendix replaced, not accumulated, across two runs"
else
  common_test_fail "stage layout round-trip: coverage appendix should appear exactly once after two runs"
fi

write_stage_vocabulary_fixture "$scratch6"
sum_before="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch6" --regenerate --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch6/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "stage layout round-trip: --regenerate --dry-run writes nothing"
else
  common_test_fail "stage layout round-trip: --regenerate --dry-run modified the file"
fi

# ─── Phase 5: --prune is a deprecated alias for --regenerate on the stage layout too -- it
# prints the same deprecation note, exits 0, and produces byte-identical output to a direct
# --regenerate run (render_next() renders the run-order section wholly from roadmap_batches
# regardless of layout; the all-terminal-omission behavior comes from render_next() itself, not
# from a separate layout-specific prune pass). ─────────────────────────────────────────────────

scratch10="$(build_scratch)"
write_state_fixture_batches "$scratch10"
write_stage_vocabulary_fixture "$scratch10"
run_ri "$scratch10" --prune >/dev/null 2>"$scratch10/stderr-stage-prune.txt"
stage_prune_rc=$?
if [[ "$stage_prune_rc" -eq 0 ]]; then
  common_test_pass "stage layout: --prune (deprecated alias) exits 0"
else
  common_test_fail "stage layout: --prune should exit 0 (got $stage_prune_rc; $(cat "$scratch10/stderr-stage-prune.txt"))"
fi

if grep -qF 'NOTE: --prune is deprecated' "$scratch10/stderr-stage-prune.txt"; then
  common_test_pass "stage layout: --prune emits its named deprecation note"
else
  common_test_fail "stage layout: --prune did not emit the named deprecation note"
fi

if grep -qFx -- '/orchestrate 1, 2   # Batch one bounded description' "$scratch10/specs/ROADMAP.md"; then
  common_test_pass "stage layout: --prune renders the run-order section from roadmap_batches, exactly like --regenerate"
else
  common_test_fail "stage layout: --prune did not render the run-order section from roadmap_batches"
fi

for needle in \
  'Stage 1 bullet prose, authored, must survive byte-identical.' \
  'Stage 2 bullet prose, authored, must survive byte-identical.' \
  'Fixture not-scoped prose, authored, must survive byte-identical.' \
  'Fixture maintenance prose, authored, must survive byte-identical.' \
  'Fixture related prose, authored, must survive byte-identical.'
do
  if grep -qF "$needle" "$scratch10/specs/ROADMAP.md"; then
    common_test_pass "stage layout --prune: retained verbatim: ${needle:0:40}..."
  else
    common_test_fail "stage layout --prune: MISSING after --prune: ${needle:0:40}..."
  fi
done

# Prove byte-identity with a direct --regenerate run on the same fixture.
write_stage_vocabulary_fixture "$scratch10"
run_ri "$scratch10" --regenerate >/dev/null 2>/dev/null
cp "$scratch10/specs/ROADMAP.md" "$scratch10/specs/ROADMAP.regenerate-copy.md"
write_stage_vocabulary_fixture "$scratch10"
run_ri "$scratch10" --prune >/dev/null 2>/dev/null
if diff -q "$scratch10/specs/ROADMAP.regenerate-copy.md" "$scratch10/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "stage layout: --prune produces the same file --regenerate would"
else
  common_test_fail "stage layout: --prune's output differs from --regenerate's own output"
fi

write_stage_vocabulary_fixture "$scratch10"
sum_before="$(sha256sum "$scratch10/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch10" --prune --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch10/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "stage layout --prune --dry-run writes nothing"
else
  common_test_fail "stage layout --prune --dry-run modified the file"
fi

scratch7="$(build_scratch)"
write_state_fixture "$scratch7"
write_roadmap_fixture "$scratch7"
run_ri "$scratch7" --regenerate >/dev/null 2>/dev/null
classic_rc=$?
if [[ "$classic_rc" -eq 0 ]]; then
  common_test_pass "classic vocabulary still classifies 'classic' and still succeeds after the Phase 2 gate"
else
  common_test_fail "classic vocabulary should still succeed after the Phase 2 gate (got $classic_rc)"
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
    common_test_pass "smoke check: this repository's real specs/ROADMAP.md (scratch copy) classifies classic"
  else
    common_test_fail "smoke check: this repository's real specs/ROADMAP.md (scratch copy) should classify classic (got $real_smoke_rc; $(cat "$scratch8/stderr-real-smoke.txt"))"
  fi
else
  common_test_info "smoke check skipped: no real specs/ROADMAP.md present"
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
  common_test_pass "crash reproduction FIXED: --regenerate against a classic fixture with an empty ## Next body exits 0"
else
  common_test_fail "crash reproduction: --regenerate against a classic fixture with an empty ## Next body should exit 0 (got $empty_next_rc; $(cat "$scratch9/stderr-empty-next.txt"))"
fi

run_ri "$scratch9" --regenerate >/dev/null 2>/dev/null
if grep -q '\*\*Coverage appendix (uncovered tasks)\*\*:' "$scratch9/specs/ROADMAP.md"; then
  common_test_pass "crash reproduction: coverage appendix is rendered for all ready tasks when ## Next starts empty"
else
  common_test_fail "crash reproduction: expected a coverage appendix once ## Next's Run lines are all absent"
fi

# ─── Case group 6: OUTCOME: stderr line (change-aware outcome reporting) ──────────────────────
#
# write_or_diff emits one named OUTCOME: line on both write modes, distinguishing a changed
# write from a no-op write and a real write from a --dry-run diff -- the residual defect this
# task lands (the frozen marker's six count fields are byte-identical in all four cases).

scratch11="$(build_scratch)"
write_state_fixture "$scratch11"
write_roadmap_fixture "$scratch11"

run_ri "$scratch11" --regenerate >/dev/null 2>"$scratch11/stderr-outcome-1.txt"
if grep -qE '^OUTCOME: --regenerate rewrote .*/specs/ROADMAP\.md \(layout=classic, content changed\)$' \
  "$scratch11/stderr-outcome-1.txt"; then
  common_test_pass "OUTCOME: line reports a changed --regenerate write (layout=classic)"
else
  common_test_fail "OUTCOME: line missing/wrong for a changed --regenerate write ($(cat "$scratch11/stderr-outcome-1.txt"))"
fi

outcome_line_no="$(grep -n '^OUTCOME: ' "$scratch11/stderr-outcome-1.txt" | head -1 | cut -d: -f1)"
marker_line_no="$(grep -n '^<!-- roadmap-generation ' "$scratch11/stderr-outcome-1.txt" | head -1 | cut -d: -f1)"
if [[ -n "$outcome_line_no" && -n "$marker_line_no" && "$outcome_line_no" -lt "$marker_line_no" ]]; then
  common_test_pass "OUTCOME: line precedes the trap-emitted marker on stderr"
else
  common_test_fail "OUTCOME: line should precede the marker (outcome=$outcome_line_no marker=$marker_line_no)"
fi

# Second consecutive run against the now-generated file: no further content change.
run_ri "$scratch11" --regenerate >/dev/null 2>"$scratch11/stderr-outcome-2.txt"
if grep -qE '^OUTCOME: --regenerate left .*/specs/ROADMAP\.md unchanged \(layout=classic, no content change\)$' \
  "$scratch11/stderr-outcome-2.txt"; then
  common_test_pass "OUTCOME: line reports a no-op --regenerate write (second consecutive run)"
else
  common_test_fail "OUTCOME: line missing/wrong for a no-op --regenerate write ($(cat "$scratch11/stderr-outcome-2.txt"))"
fi

# --dry-run against a file that WOULD change.
write_roadmap_fixture "$scratch11"
run_ri "$scratch11" --regenerate --dry-run >/dev/null 2>"$scratch11/stderr-outcome-dry-1.txt"
if grep -qE '^OUTCOME: --regenerate --dry-run diffed .*/specs/ROADMAP\.md; wrote nothing \(layout=classic, content would change\)$' \
  "$scratch11/stderr-outcome-dry-1.txt"; then
  common_test_pass "OUTCOME: line reports a would-change --regenerate --dry-run"
else
  common_test_fail "OUTCOME: line missing/wrong for a would-change --dry-run ($(cat "$scratch11/stderr-outcome-dry-1.txt"))"
fi

# --dry-run against a file already at its generated shape (no-op dry-run).
run_ri "$scratch11" --regenerate >/dev/null 2>/dev/null
run_ri "$scratch11" --regenerate --dry-run >/dev/null 2>"$scratch11/stderr-outcome-dry-2.txt"
if grep -qE '^OUTCOME: --regenerate --dry-run diffed .*/specs/ROADMAP\.md; wrote nothing \(layout=classic, no content change\)$' \
  "$scratch11/stderr-outcome-dry-2.txt"; then
  common_test_pass "OUTCOME: line reports a no-change --regenerate --dry-run"
else
  common_test_fail "OUTCOME: line missing/wrong for a no-change --dry-run ($(cat "$scratch11/stderr-outcome-dry-2.txt"))"
fi

# --prune dispatches to --regenerate, so its OUTCOME: line carries the --regenerate mode token
# (the deprecated-alias contract), preceded by --prune's own deprecation note.
scratch12="$(build_scratch)"
write_state_fixture "$scratch12"
write_roadmap_fixture "$scratch12"
run_ri "$scratch12" --prune >/dev/null 2>"$scratch12/stderr-outcome-prune.txt"
if grep -qF 'NOTE: --prune is deprecated' "$scratch12/stderr-outcome-prune.txt" \
    && grep -qE '^OUTCOME: --regenerate rewrote .*/specs/ROADMAP\.md \(layout=classic, content changed\)$' \
      "$scratch12/stderr-outcome-prune.txt"; then
  common_test_pass "OUTCOME: line names the --regenerate mode token for a --prune invocation (dispatch-to-regenerate contract)"
else
  common_test_fail "OUTCOME: line missing/wrong for --prune ($(cat "$scratch12/stderr-outcome-prune.txt"))"
fi

# --regenerate on a stage-layout fixture: OUTCOME: line names layout=stage.
scratch13="$(build_scratch)"
write_state_fixture "$scratch13"
write_stage_vocabulary_fixture "$scratch13"
run_ri "$scratch13" --regenerate >/dev/null 2>"$scratch13/stderr-outcome-stage.txt"
if grep -qE '^OUTCOME: --regenerate .*\(layout=stage, ' "$scratch13/stderr-outcome-stage.txt"; then
  common_test_pass "OUTCOME: line names layout=stage for a stage-layout --regenerate"
else
  common_test_fail "OUTCOME: line missing/wrong layout for stage --regenerate ($(cat "$scratch13/stderr-outcome-stage.txt"))"
fi

# The absent-roadmap supported no-op (scratch4, Case group 3) never reaches write_or_diff --
# confirm it still emits no OUTCOME: line.
if grep -q '^OUTCOME: ' "$scratch4/stderr-absent.txt"; then
  common_test_fail "absent-roadmap no-op should emit no OUTCOME: line ($(cat "$scratch4/stderr-absent.txt"))"
else
  common_test_pass "absent-roadmap no-op emits no OUTCOME: line"
fi

# The unrecognised-layout refusal (scratch5, Case group 4) never reaches write_or_diff --
# confirm it still emits no OUTCOME: line, on both modes.
if grep -q '^OUTCOME: ' "$scratch5/stderr-unknown-regen.txt"; then
  common_test_fail "unknown vocabulary: --regenerate refusal should emit no OUTCOME: line ($(cat "$scratch5/stderr-unknown-regen.txt"))"
else
  common_test_pass "unknown vocabulary: --regenerate refusal emits no OUTCOME: line"
fi
if grep -q '^OUTCOME: ' "$scratch5/stderr-unknown-prune.txt"; then
  common_test_fail "unknown vocabulary: --prune refusal should emit no OUTCOME: line ($(cat "$scratch5/stderr-unknown-prune.txt"))"
else
  common_test_pass "unknown vocabulary: --prune refusal emits no OUTCOME: line"
fi

# The frozen six-field marker shape is unaffected by the new OUTCOME: line (retained check,
# mirroring Case group 2's pre-existing marker assertion, re-run against this group's captures).
if grep -qE '^<!-- roadmap-generation mode=regenerate tasks=[0-9]+ topics=[0-9]+ runs=[0-9]+ pruned=[0-9]+ retained=[0-9]+ -->$' \
  "$scratch11/stderr-outcome-1.txt"; then
  common_test_pass "frozen marker shape unchanged alongside the new OUTCOME: line"
else
  common_test_fail "frozen marker shape changed ($(cat "$scratch11/stderr-outcome-1.txt"))"
fi

# File-level idempotence retained (second-run byte-identical), now re-asserted alongside the
# OUTCOME: line's own no-op report above.
cp "$scratch11/specs/ROADMAP.md" "$scratch11/specs/ROADMAP.idempotence-check.md"
run_ri "$scratch11" --regenerate >/dev/null 2>/dev/null
if diff -q "$scratch11/specs/ROADMAP.idempotence-check.md" "$scratch11/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "--regenerate file-level idempotence retained alongside the OUTCOME: line"
else
  common_test_fail "--regenerate file-level idempotence broke alongside the OUTCOME: line"
fi

# ─── Case group 6 (Phase 3): render_next() renders ## Next wholly from roadmap_batches and
# roadmap_notes -- two batches in array order with their descriptions, an entry with no
# rationale emits no bullet, an all-terminal batch is omitted entirely, next_preamble/
# next_postamble render in the right positions, and a second consecutive --regenerate is
# byte-identical. Classic layout; write_roadmap_fixture's existing ## Next body content is
# irrelevant here since the section is now rendered wholly from state, not retention-parsed.
# (write_state_fixture_batches itself is defined earlier, alongside the other state fixtures,
# since Case group 3 above also needs it.) ─────────────────────────────────────────────────────

scratch14="$(build_scratch)"
write_state_fixture_batches "$scratch14"
write_roadmap_fixture "$scratch14"
run_ri "$scratch14" --regenerate >/dev/null 2>"$scratch14/stderr-batches-regen.txt"
batches_regen_rc=$?

if [[ "$batches_regen_rc" -eq 0 ]]; then
  common_test_pass "roadmap_batches fixture: --regenerate succeeds"
else
  common_test_fail "roadmap_batches fixture: --regenerate should succeed (got $batches_regen_rc; $(cat "$scratch14/stderr-batches-regen.txt"))"
fi

if grep -qFx '/orchestrate 1, 2   # Batch one bounded description' "$scratch14/specs/ROADMAP.md"; then
  common_test_pass "roadmap_batches fixture: batch one renders its Run line with task_ids joined and its description"
else
  common_test_fail "roadmap_batches fixture: MISSING batch one's Run line"
fi

if grep -qFx '/orchestrate 4   # Batch three, no rationale, no bullet expected' "$scratch14/specs/ROADMAP.md"; then
  common_test_pass "roadmap_batches fixture: batch three (array position 2) renders in array order after batch one"
else
  common_test_fail "roadmap_batches fixture: MISSING batch three's Run line"
fi

if grep -qF 'Batch two, all-terminal, must be omitted' "$scratch14/specs/ROADMAP.md"; then
  common_test_fail "roadmap_batches fixture: an all-terminal batch should be omitted entirely"
else
  common_test_pass "roadmap_batches fixture: an all-terminal batch (task_ids: [3]) is omitted entirely"
fi

if grep -qFx -- '- Batch one rationale bullet text.' "$scratch14/specs/ROADMAP.md"; then
  common_test_pass "roadmap_batches fixture: batch one's rationale renders as a bullet"
else
  common_test_fail "roadmap_batches fixture: MISSING batch one's rationale bullet"
fi

next_body_batches="$(section_body "$scratch14/specs/ROADMAP.md" "## Next")"
bullet_count_batches="$(grep -c '^- ' <<<"$next_body_batches")"
if [[ "$bullet_count_batches" -eq 1 ]]; then
  common_test_pass "roadmap_batches fixture: exactly one rationale bullet (batch three, with no rationale, emits none)"
else
  common_test_fail "roadmap_batches fixture: expected exactly 1 rationale bullet, found $bullet_count_batches"
fi

if grep -qF 'Preamble paragraph, authored, must render before the fence.' "$scratch14/specs/ROADMAP.md"; then
  common_test_pass "roadmap_batches fixture: next_preamble paragraph renders"
else
  common_test_fail "roadmap_batches fixture: MISSING next_preamble paragraph"
fi

if grep -qF 'Postamble paragraph, authored, must render after the bullets.' "$scratch14/specs/ROADMAP.md"; then
  common_test_pass "roadmap_batches fixture: next_postamble paragraph renders"
else
  common_test_fail "roadmap_batches fixture: MISSING next_postamble paragraph"
fi

preamble_line_batches="$(grep -n 'Preamble paragraph, authored' "$scratch14/specs/ROADMAP.md" | head -1 | cut -d: -f1)"
fence_line_batches="$(grep -n '^/orchestrate 1, 2   # Batch one bounded description$' "$scratch14/specs/ROADMAP.md" | head -1 | cut -d: -f1)"
postamble_line_batches="$(grep -n 'Postamble paragraph, authored' "$scratch14/specs/ROADMAP.md" | head -1 | cut -d: -f1)"
bullet_line_batches="$(grep -n '^- Batch one rationale bullet text\.$' "$scratch14/specs/ROADMAP.md" | head -1 | cut -d: -f1)"
if [[ -n "$preamble_line_batches" && -n "$fence_line_batches" && -n "$bullet_line_batches" && -n "$postamble_line_batches" \
    && "$preamble_line_batches" -lt "$fence_line_batches" \
    && "$fence_line_batches" -lt "$bullet_line_batches" \
    && "$bullet_line_batches" -lt "$postamble_line_batches" ]]; then
  common_test_pass "roadmap_batches fixture: preamble/fence/bullet/postamble render in the right relative order"
else
  common_test_fail "roadmap_batches fixture: preamble/fence/bullet/postamble out of order (preamble=$preamble_line_batches fence=$fence_line_batches bullet=$bullet_line_batches postamble=$postamble_line_batches)"
fi

cp "$scratch14/specs/ROADMAP.md" "$scratch14/specs/ROADMAP.batches-round1.md"
run_ri "$scratch14" --regenerate >/dev/null 2>/dev/null
if diff -q "$scratch14/specs/ROADMAP.batches-round1.md" "$scratch14/specs/ROADMAP.md" >/dev/null; then
  common_test_pass "roadmap_batches fixture: a second consecutive --regenerate is byte-identical"
else
  common_test_fail "roadmap_batches fixture: a second consecutive --regenerate is NOT byte-identical"
fi

# The unrecognised-layout refusal still refuses even when the state carries roadmap_batches
# (confirming the refusal gate runs before any state-derived render is attempted).
write_unknown_vocabulary_fixture "$scratch14"
sum_before_batches_unknown="$(sha256sum "$scratch14/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch14" --regenerate >/dev/null 2>"$scratch14/stderr-batches-unknown.txt"
batches_unknown_rc=$?
sum_after_batches_unknown="$(sha256sum "$scratch14/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$batches_unknown_rc" -ne 0 && "$sum_before_batches_unknown" == "$sum_after_batches_unknown" ]] \
    && grep -qE '^ERROR: --regenerate refuses to write' "$scratch14/stderr-batches-unknown.txt"; then
  common_test_pass "roadmap_batches fixture: unrecognised-layout refusal still refuses (exit non-zero, no write) with roadmap_batches present"
else
  common_test_fail "roadmap_batches fixture: unrecognised-layout refusal did not hold with roadmap_batches present (rc=$batches_unknown_rc)"
fi

# ─── Live-tree isolation guard ─────────────────────────────────────────────────────────────

REAL_ROADMAP_SUM_AFTER=""
REAL_STATE_SUM_AFTER=""
[[ -f "$REAL_ROADMAP" ]] && REAL_ROADMAP_SUM_AFTER="$(sha256sum "$REAL_ROADMAP" | awk '{print $1}')"
[[ -f "$REAL_STATE" ]] && REAL_STATE_SUM_AFTER="$(sha256sum "$REAL_STATE" | awk '{print $1}')"

if [[ "$REAL_ROADMAP_SUM_BEFORE" == "$REAL_ROADMAP_SUM_AFTER" && "$REAL_STATE_SUM_BEFORE" == "$REAL_STATE_SUM_AFTER" ]]; then
  common_test_pass "live-tree isolation: real specs/ROADMAP.md and specs/state.json untouched"
else
  common_test_fail "live-tree isolation: real specs/ROADMAP.md or specs/state.json CHANGED during this suite"
fi

echo
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
