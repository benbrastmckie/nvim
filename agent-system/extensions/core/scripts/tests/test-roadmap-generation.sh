#!/usr/bin/env bash
# test-roadmap-generation.sh - Regression suite for roadmap-integration.sh (the --print/
# --regenerate/--prune generator that implements context/formats/roadmap-format.md's contract)
# and for lib/roadmap-preflight-lib.sh's classify and scaffold entry points.
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
# unchanged dependencies (deploy-root-guard.sh, lib/common.sh,
# lib/status-vocabulary.sh, lib/roadmap-preflight-lib.sh, lib/roadmap-entries-lib.sh) are resolved DEPLOY-TREE-FIRST, as every other suite in this
# directory does for an unchanged dependency.
#
# ISOLATION CONTRACT: every case builds a fresh scratch project root under mktemp -d with its
# own <scratch>/.claude/scripts/{roadmap-integration.sh,deploy-root-guard.sh,
# lib/{common.sh,status-vocabulary.sh,roadmap-preflight-lib.sh,roadmap-entries-lib.sh}} and
# <scratch>/specs/
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
GUARD_SRC="$(common_test_resolve_subject "deploy-root-guard.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/deploy-root-guard.sh" "$SOURCE_STORE_SCRIPTS/deploy-root-guard.sh")" || exit 2
common_test_declare_subject "$GUARD_SRC"
COMMON_SRC="$(common_test_resolve_subject "lib/common.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/common.sh" "$SOURCE_STORE_SCRIPTS/lib/common.sh")" || exit 2
common_test_declare_subject "$COMMON_SRC"
STATUSVOC_SRC="$(common_test_resolve_subject "lib/status-vocabulary.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/status-vocabulary.sh" "$SOURCE_STORE_SCRIPTS/lib/status-vocabulary.sh")" || exit 2
common_test_declare_subject "$STATUSVOC_SRC"
PREFLIGHT_SRC="$(common_test_resolve_subject "lib/roadmap-preflight-lib.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/roadmap-preflight-lib.sh" "$SOURCE_STORE_SCRIPTS/lib/roadmap-preflight-lib.sh")" || exit 2
common_test_declare_subject "$PREFLIGHT_SRC"
ENTRIES_SRC="$(common_test_resolve_subject "lib/roadmap-entries-lib.sh" "deploy-tree-first" \
  "$DEPLOY_SCRIPTS_SRC/lib/roadmap-entries-lib.sh" "$SOURCE_STORE_SCRIPTS/lib/roadmap-entries-lib.sh")" || exit 2
common_test_declare_subject "$ENTRIES_SRC"

PASSED=0
FAILED=0

common_test_info "Under test (source-store-first): $RI_SRC"
common_test_info "Dependency (deploy-first): $GUARD_SRC"
common_test_info "Dependency (deploy-first): $COMMON_SRC"
common_test_info "Dependency (deploy-first): $STATUSVOC_SRC"
common_test_info "Dependency (deploy-first): $PREFLIGHT_SRC"
common_test_info "Dependency (deploy-first): $ENTRIES_SRC"

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
  cp "$GUARD_SRC" "$scratch/.claude/scripts/deploy-root-guard.sh"
  cp "$COMMON_SRC" "$scratch/.claude/scripts/lib/common.sh"
  cp "$STATUSVOC_SRC" "$scratch/.claude/scripts/lib/status-vocabulary.sh"
  cp "$PREFLIGHT_SRC" "$scratch/.claude/scripts/lib/roadmap-preflight-lib.sh"
  cp "$ENTRIES_SRC" "$scratch/.claude/scripts/lib/roadmap-entries-lib.sh"
  chmod +x "$scratch/.claude/scripts/roadmap-integration.sh"
  echo "$scratch"
}

# write_state_fixture SCRATCH -- a flat store with no milestone, shared by most cases below.
# Covers every status token (ready, blocked:N, blocked:N,M, IN FLIGHT, HOLD), a terminal item
# excluded entirely, an item whose only dependency is terminal (must read ready, not blocked),
# and two distinct topics. Items are numbered 1-8 purely as
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

# write_roadmap_fixture SCRATCH -- a hand-authored classic eight-header ROADMAP.md, the kind of
# file the generator must refuse to overwrite.
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

# write_stage_vocabulary_fixture SCRATCH -- a hand-authored stage-layout file: a preamble, a
# fenced run-order block mixing "# Stage N" comment lines with /orchestrate lines, several
# "## Stage N" sections, and trailing free-form sections.
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
# predicate (no "## Stage N" header, no fenced /orchestrate block). Refused like any other hand-authored file.
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

run_ri() {
  local scratch="$1"; shift
  "$scratch/.claude/scripts/roadmap-integration.sh" \
    --roadmap "$scratch/specs/ROADMAP.md" --state "$scratch/specs/state.json" "$@"
}

# PREFLIGHT_CLI invokes the library as a run-as-script CLI (bash PREFLIGHT_CLI classify|scaffold
# PATH), the same invocation shape its Bash-only callers use -- never sourced here, so a bug in the
# BASH_SOURCE run-as-script guard would surface as a suite failure too.

preflight_classify() {
  local scratch="$1"
  bash "$scratch/.claude/scripts/lib/roadmap-preflight-lib.sh" classify "$scratch/specs/ROADMAP.md"
}

preflight_scaffold() {
  local scratch="$1"
  bash "$scratch/.claude/scripts/lib/roadmap-preflight-lib.sh" scaffold "$scratch/specs/ROADMAP.md"
}

# The fixed first line of a generated file (lib/roadmap-preflight-lib.sh owns the constant; the
# literal is repeated here so a change to it is a visible suite failure).
GENERATED_SENTINEL='<!-- generated by roadmap-integration.sh from specs/state.json; do not edit -->'

# ─── Case group 1: --print on a store with no milestone -- status tokens, terminal exclusion,
# ordering, annotations, the stderr marker ────────────────────────────────────────────────────
#
# With no milestone and no batch, every open item is "in no batch", so the whole token
# vocabulary is observable in the last section's list.

scratch1="$(build_scratch)"
write_state_fixture "$scratch1"
print_out="$(run_ri "$scratch1" --print 2>"$scratch1/stderr.txt")"
print_rc=$?

if [[ "$print_rc" -eq 0 ]]; then
  common_test_pass "--print exits 0"
else
  common_test_fail "--print exits 0 (got $print_rc)"
fi

if [[ "$(sed -n '1p' <<<"$print_out")" == "$GENERATED_SENTINEL" ]] \
    && grep -qxF '_No milestones recorded._' <<<"$print_out" \
    && grep -qxF '### Open tasks in no batch' <<<"$print_out"; then
  common_test_pass "--print renders the whole file for a store with no milestone (sentinel, empty table note, open-task list)"
else
  common_test_fail "--print should render the whole file for a store with no milestone"
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

token_order="$(grep -E '^[0-9]+ ' <<<"$print_out" | awk '{print $1}' | tr '\n' ' ')"
if [[ "$token_order" == "5 4 2 3 1 7 8 " ]]; then
  common_test_pass "ordering: closed-vocabulary tokens, then blocked:N, then ready, each by number"
else
  common_test_fail "ordering: expected '5 4 2 3 1 7 8', got '$token_order'"
fi

if ! grep -qF '**Alpha' <<<"$print_out" && ! grep -qF 'Coverage appendix' <<<"$print_out" \
    && ! grep -qF '## Open work' <<<"$print_out" && ! grep -qF '## Next' <<<"$print_out"; then
  common_test_pass "no per-topic blocks, no coverage appendix, no ## Next or ## Open work section"
else
  common_test_fail "a retired section (topic block, coverage appendix, ## Next, ## Open work) was rendered"
fi

if grep -qE '^<!-- roadmap-generation mode=print tasks=7 topics=2 runs=0 pruned=0 retained=0 -->$' "$scratch1/stderr.txt"; then
  common_test_pass "stderr marker present and correct for --print"
else
  common_test_fail "stderr marker missing or incorrect for --print ($(cat "$scratch1/stderr.txt"))"
fi

# -- annotation, EXT-BLOCKED and description truncation, all read from state --
scratch1a="$(build_scratch)"
write_state_fixture "$scratch1a"
long_title="$(printf 'w%.0s' $(seq 1 140))"
jq --arg long "$long_title" '
  (.active_projects[] | select(.project_number == 1)).roadmap_annotation = "do first"
  | (.active_projects[] | select(.project_number == 2)).roadmap_ext_blocked = true
  | (.active_projects[] | select(.project_number == 7)).title = $long' \
  "$scratch1a/specs/state.json" >"$scratch1a/specs/state.json.new" \
  && mv "$scratch1a/specs/state.json.new" "$scratch1a/specs/state.json"
annot_out="$(run_ri "$scratch1a" --print 2>/dev/null)"

if grep -qE '^1 ready +Item one description   <- do first$' <<<"$annot_out"; then
  common_test_pass "annotation: roadmap_annotation renders as a '<-' suffix"
else
  common_test_fail "annotation: expected item 1 to carry '   <- do first'"
fi

if grep -qE '^2 EXT-BLOCKED ' <<<"$annot_out"; then
  common_test_pass "token derivation: roadmap_ext_blocked renders EXT-BLOCKED ahead of a blocked:N token"
else
  common_test_fail "token derivation: item 2 with roadmap_ext_blocked should render EXT-BLOCKED"
fi

long_line="$(grep -E '^7 ready' <<<"$annot_out")"
if [[ "${#long_line}" -eq 100 && "$long_line" == *... ]]; then
  common_test_pass "truncation: a long title is cut so the line is 100 characters, ending in an ellipsis"
else
  common_test_fail "truncation: expected a 100-character line ending in '...', got ${#long_line} characters"
fi

# ─── Case group 1b: failure-path diagnosability -- an injected failure (malformed --state JSON)
# must still emit the marker AND a named ERROR: line, and must exit non-zero ──────────────────

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

# ─── Case group 2: --regenerate -- the absent no-op, the write onto a generated file, the
# OUTCOME: line, idempotence ──────────────────────────────────────────────────────────────────

scratch2="$(build_scratch)"
write_state_fixture "$scratch2"
run_ri "$scratch2" --regenerate >/dev/null 2>"$scratch2/stderr-absent.txt"
absent_rc=$?
if [[ "$absent_rc" -eq 0 && ! -e "$scratch2/specs/ROADMAP.md" ]] \
    && ! grep -q '^OUTCOME:' "$scratch2/stderr-absent.txt" \
    && grep -qF 'supported no-op' "$scratch2/stderr-absent.txt"; then
  common_test_pass "--regenerate with no file and no milestone is a supported no-op (exit 0, no file, no OUTCOME: line)"
else
  common_test_fail "--regenerate with no file and no milestone should be a no-op (rc=$absent_rc: $(cat "$scratch2/stderr-absent.txt"))"
fi

printf '%s\n' "$GENERATED_SENTINEL" >"$scratch2/specs/ROADMAP.md"
run_ri "$scratch2" --regenerate --dry-run >"$scratch2/stdout-dry1.txt" 2>"$scratch2/stderr-dry1.txt"
if grep -qE 'OUTCOME: --regenerate --dry-run diffed .*; wrote nothing \(layout=generated, content would change\)$' "$scratch2/stderr-dry1.txt" \
    && [[ "$(cat "$scratch2/specs/ROADMAP.md")" == "$GENERATED_SENTINEL" ]] \
    && [[ -s "$scratch2/stdout-dry1.txt" ]]; then
  common_test_pass "OUTCOME: line reports a would-change --regenerate --dry-run, a diff is printed, nothing is written"
else
  common_test_fail "--regenerate --dry-run should report 'content would change' and write nothing ($(cat "$scratch2/stderr-dry1.txt"))"
fi

run_ri "$scratch2" --regenerate >/dev/null 2>"$scratch2/stderr-regen1.txt"
regen_rc=$?
if [[ "$regen_rc" -eq 0 ]] \
    && grep -qE 'OUTCOME: --regenerate rewrote .* \(layout=generated, content changed\)$' "$scratch2/stderr-regen1.txt" \
    && grep -qE '^1 ready' "$scratch2/specs/ROADMAP.md"; then
  common_test_pass "OUTCOME: line reports a changed --regenerate write onto a generated file (layout=generated)"
else
  common_test_fail "--regenerate onto a generated file should rewrite it (rc=$regen_rc: $(cat "$scratch2/stderr-regen1.txt"))"
fi

outcome_line_no="$(grep -n '^OUTCOME:' "$scratch2/stderr-regen1.txt" | head -1 | cut -d: -f1)"
marker_line_no="$(grep -n '^<!-- roadmap-generation ' "$scratch2/stderr-regen1.txt" | head -1 | cut -d: -f1)"
if [[ -n "$outcome_line_no" && -n "$marker_line_no" && "$outcome_line_no" -lt "$marker_line_no" ]]; then
  common_test_pass "OUTCOME: line precedes the trap-emitted marker on stderr"
else
  common_test_fail "OUTCOME: line should precede the marker (outcome=$outcome_line_no marker=$marker_line_no)"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate tasks=7 topics=2 runs=0 pruned=0 retained=0 -->$' "$scratch2/stderr-regen1.txt"; then
  common_test_pass "stderr marker present and correct for --regenerate"
else
  common_test_fail "stderr marker missing or incorrect for --regenerate ($(cat "$scratch2/stderr-regen1.txt"))"
fi

regen_sum1="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
run_ri "$scratch2" --regenerate >/dev/null 2>"$scratch2/stderr-regen2.txt"
regen_sum2="$(sha256sum "$scratch2/specs/ROADMAP.md" | awk '{print $1}')"
if [[ "$regen_sum1" == "$regen_sum2" ]] \
    && grep -qE 'OUTCOME: --regenerate left .* unchanged \(layout=generated, no content change\)$' "$scratch2/stderr-regen2.txt"; then
  common_test_pass "OUTCOME: line reports a no-op --regenerate write (second consecutive run is byte-identical)"
else
  common_test_fail "second --regenerate should be byte-identical and report no content change ($(cat "$scratch2/stderr-regen2.txt"))"
fi

run_ri "$scratch2" --regenerate --dry-run >"$scratch2/stdout-dry2.txt" 2>"$scratch2/stderr-dry2.txt"
if grep -qE 'OUTCOME: --regenerate --dry-run diffed .*; wrote nothing \(layout=generated, no content change\)$' "$scratch2/stderr-dry2.txt" \
    && [[ ! -s "$scratch2/stdout-dry2.txt" ]]; then
  common_test_pass "OUTCOME: line reports a no-change --regenerate --dry-run with an empty diff"
else
  common_test_fail "--regenerate --dry-run on a current file should report no content change ($(cat "$scratch2/stderr-dry2.txt"))"
fi

# ─── Case group 3: --prune is a deprecated alias for --regenerate ─────────────────────────────

scratch3="$(build_scratch)"
write_state_fixture "$scratch3"
printf '%s\n' "$GENERATED_SENTINEL" >"$scratch3/specs/ROADMAP.md"
run_ri "$scratch3" --prune --dry-run >/dev/null 2>"$scratch3/stderr-prune-dry.txt"
if [[ "$(cat "$scratch3/specs/ROADMAP.md")" == "$GENERATED_SENTINEL" ]]; then
  common_test_pass "--prune --dry-run writes nothing"
else
  common_test_fail "--prune --dry-run must not write"
fi

run_ri "$scratch3" --prune >/dev/null 2>"$scratch3/stderr-prune.txt"
prune_rc=$?
if [[ "$prune_rc" -eq 0 ]]; then
  common_test_pass "--prune (deprecated alias) exits 0"
else
  common_test_fail "--prune should exit 0 (got $prune_rc: $(cat "$scratch3/stderr-prune.txt"))"
fi

if grep -qF 'NOTE: --prune is deprecated' "$scratch3/stderr-prune.txt"; then
  common_test_pass "--prune emits its named deprecation note"
else
  common_test_fail "--prune should emit its deprecation note"
fi

if cmp -s "$scratch2/specs/ROADMAP.md" "$scratch3/specs/ROADMAP.md"; then
  common_test_pass "--prune produces the same file --regenerate would"
else
  common_test_fail "--prune output differs from --regenerate output for the same state"
fi

if grep -qE '^<!-- roadmap-generation mode=regenerate tasks=7 topics=2 runs=0 pruned=0 retained=0 -->$' "$scratch3/stderr-prune.txt" \
    && grep -qE '^OUTCOME: --regenerate rewrote ' "$scratch3/stderr-prune.txt"; then
  common_test_pass "--prune's marker and OUTCOME: line both name the regenerate mode, with pruned=0"
else
  common_test_fail "--prune should report mode=regenerate in the marker and the OUTCOME: line ($(cat "$scratch3/stderr-prune.txt"))"
fi

# ─── Case group 4: the destructive-overwrite refusal -- any file whose first line is not the
# sentinel is hand-authored content, never overwritten ─────────────────────────────────────────

refusal_case() {
  local label="$1" writer="$2" expect_verdict="$3" scratch
  scratch="$(build_scratch)"
  write_state_fixture "$scratch"
  "$writer" "$scratch"
  cp "$scratch/specs/ROADMAP.md" "$scratch/before.md"

  run_ri "$scratch" --regenerate >/dev/null 2>"$scratch/stderr-regen.txt"
  local rc=$?
  if [[ "$rc" -ne 0 ]] && cmp -s "$scratch/before.md" "$scratch/specs/ROADMAP.md"; then
    common_test_pass "${label}: --regenerate exits non-zero and writes nothing"
  else
    common_test_fail "${label}: --regenerate should refuse without writing (rc=$rc)"
  fi

  if grep -qF "(verdict: ${expect_verdict})" "$scratch/stderr-regen.txt" \
      && grep -qF 'migrate-roadmap-to-milestones.sh' "$scratch/stderr-regen.txt" \
      && grep -qF 'Actual headers in this file:' "$scratch/stderr-regen.txt"; then
    common_test_pass "${label}: the refusal names the verdict, the file's headers and the migration"
  else
    common_test_fail "${label}: refusal message incomplete ($(cat "$scratch/stderr-regen.txt"))"
  fi

  if grep -qE '^<!-- roadmap-generation mode=regenerate ' "$scratch/stderr-regen.txt" \
      && ! grep -q '^OUTCOME:' "$scratch/stderr-regen.txt"; then
    common_test_pass "${label}: the refusal still emits the stderr marker and no OUTCOME: line"
  else
    common_test_fail "${label}: refusal should emit the marker and no OUTCOME: line"
  fi

  run_ri "$scratch" --prune >/dev/null 2>"$scratch/stderr-prune.txt"
  rc=$?
  if [[ "$rc" -ne 0 ]] && cmp -s "$scratch/before.md" "$scratch/specs/ROADMAP.md" \
      && grep -qF 'NOTE: --prune is deprecated' "$scratch/stderr-prune.txt" \
      && grep -qF -- '--regenerate refuses to write' "$scratch/stderr-prune.txt"; then
    common_test_pass "${label}: --prune prints its deprecation note, then the same refusal, and writes nothing"
  else
    common_test_fail "${label}: --prune should refuse like --regenerate (rc=$rc)"
  fi
}

refusal_case "classic file" write_roadmap_fixture classic
refusal_case "stage file" write_stage_vocabulary_fixture stage
refusal_case "unrecognised file" write_unknown_vocabulary_fixture unknown

# ─── Case group 5: roadmap-preflight-lib.sh -- classify and scaffold ──────────────────────────

classify_case() {
  local label="$1" writer="$2" expect="$3" scratch got
  scratch="$(build_scratch)"
  write_state_fixture "$scratch"
  [[ -n "$writer" ]] && "$writer" "$scratch"
  got="$(preflight_classify "$scratch" 2>/dev/null)"
  if [[ "$got" == "$expect" ]]; then
    common_test_pass "preflight classify: ${label} reports '${expect}'"
  else
    common_test_fail "preflight classify: ${label} should report '${expect}', got '${got}'"
  fi
}

classify_case "absent file" "" absent
classify_case "unrecognised fixture" write_unknown_vocabulary_fixture unknown
classify_case "classic fixture" write_roadmap_fixture classic
classify_case "stage fixture" write_stage_vocabulary_fixture stage

scratch_sc="$(build_scratch)"
write_state_fixture "$scratch_sc"
preflight_scaffold "$scratch_sc" >/dev/null 2>"$scratch_sc/stderr-scaffold.txt"
scaffold_rc=$?
if [[ "$scaffold_rc" -eq 0 ]] && [[ "$(cat "$scratch_sc/specs/ROADMAP.md" 2>/dev/null)" == "$GENERATED_SENTINEL" ]] \
    && [[ "$(preflight_classify "$scratch_sc")" == "generated" ]]; then
  common_test_pass "preflight scaffold: an absent path becomes a sentinel-only file that classifies 'generated'"
else
  common_test_fail "preflight scaffold: absent path should become a sentinel-only generated file (rc=$scaffold_rc)"
fi

run_ri "$scratch_sc" --regenerate >/dev/null 2>/dev/null
run_ri "$scratch_sc" --regenerate --dry-run >/dev/null 2>"$scratch_sc/stderr-idem.txt"
if grep -qE 'OUTCOME: --regenerate --dry-run diffed .*; wrote nothing \(layout=generated, no content change\)$' "$scratch_sc/stderr-idem.txt"; then
  common_test_pass "preflight scaffold-then-regenerate: idempotent (second --regenerate --dry-run reports no content change)"
else
  common_test_fail "preflight scaffold-then-regenerate: expected 'no content change' ($(cat "$scratch_sc/stderr-idem.txt"))"
fi

scaffold_refusal_case() {
  local label="$1" writer="$2" scratch rc
  scratch="$(build_scratch)"
  write_state_fixture "$scratch"
  "$writer" "$scratch"
  cp "$scratch/specs/ROADMAP.md" "$scratch/before.md"
  preflight_scaffold "$scratch" >/dev/null 2>"$scratch/stderr-scaffold.txt"
  rc=$?
  if [[ "$rc" -ne 0 ]] && cmp -s "$scratch/before.md" "$scratch/specs/ROADMAP.md" \
      && grep -qF 'migrate-roadmap-to-milestones.sh' "$scratch/stderr-scaffold.txt"; then
    common_test_pass "preflight scaffold: ${label} refuses, writes nothing and names the migration"
  else
    common_test_fail "preflight scaffold: ${label} should refuse without writing (rc=$rc)"
  fi
}

scaffold_refusal_case "a classic file" write_roadmap_fixture
scaffold_refusal_case "a stage file" write_stage_vocabulary_fixture
scaffold_refusal_case "an unrecognised file" write_unknown_vocabulary_fixture

# ─── Case group: whole-file milestone render (a store carrying roadmap_milestones) ───────────
#
# Fixture: three milestones in order -- M0 closed with no batches, M1 active with three batches
# (one holding a completed member beside open ones, one whose members are all done, one open),
# M2 planned and empty. Item 6 is terminal in active_projects, item 9 exists only in the sibling
# archive, item 8 is open and sits in no batch.

write_state_fixture_milestones() {
  local scratch="$1"
  mkdir -p "$scratch/specs/archive"
  cat >"$scratch/specs/state.json" <<'EOF'
{
  "active_goal": "fallback goal text",
  "primary_goals": ["Ship the generated roadmap", "Keep review cheap"],
  "roadmap_context": {
    "overview": ["A fixture repository."],
    "rules": ["Never push."],
    "conventions": ["Run the suite first."]
  },
  "roadmap_milestones": [
    {"id": "M0", "title": "Ground truth", "aim": "Measure.",
     "progress": {"status": "closed", "closed": "2026-11-17"},
     "review": {"state": "merged"}, "batches": []},
    {"id": "M1", "title": "Workflow", "aim": "Make the workflow run.",
     "gate": "All suites green.",
     "progress": {"status": "active", "note": "halfway"},
     "review": {"state": "in_review", "ref": "feat/m1", "request": "PR #34", "updated": "2026-11-18"},
     "batches": [
       {"task_ids": [1, 2, 6], "description": "Foundations", "rationale": "UNRENDERED RATIONALE", "flags": "--hard"},
       {"task_ids": [6, 9], "description": "Already finished"},
       {"task_ids": [4, 5], "description": "In flight pair"}
     ]},
    {"id": "M2", "title": "Later", "aim": "Later work.",
     "progress": {"status": "planned"}, "batches": []}
  ],
  "active_projects": [
    {"project_number": 1, "status": "not_started", "title": "Item one", "dependencies": [], "roadmap_annotation": "start here"},
    {"project_number": 2, "status": "not_started", "title": "Item two", "dependencies": [1]},
    {"project_number": 4, "status": "implementing", "title": "Item four", "dependencies": []},
    {"project_number": 5, "status": "hold", "title": "Item five", "dependencies": []},
    {"project_number": 6, "status": "completed", "title": "Item six", "dependencies": []},
    {"project_number": 8, "status": "not_started", "project_name": "item_eight", "dependencies": []}
  ]
}
EOF
  cat >"$scratch/specs/archive/state.json" <<'EOF'
{"completed_projects": [{"project_number": 9, "title": "Archived nine"}]}
EOF
}

# line_of FILE LITERAL -> 1-based number of the first line equal to LITERAL, or empty.
line_of() {
  grep -nxF -- "$2" "$1" | head -1 | cut -d: -f1
}

scratch_ms="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms"
# The scratch tree holds no generate-task-order.sh: the render must not need it.
run_ri "$scratch_ms" --print >"$scratch_ms/print.md" 2>"$scratch_ms/stderr-print.txt"
ms_print_rc=$?

if [[ "$ms_print_rc" -eq 0 ]]; then
  common_test_pass "milestone render: --print exits 0 with generate-task-order.sh absent"
else
  common_test_fail "milestone render: --print should exit 0 without generate-task-order.sh (got $ms_print_rc: $(cat "$scratch_ms/stderr-print.txt"))"
fi

if [[ "$(sed -n '1p' "$scratch_ms/print.md")" == "$GENERATED_SENTINEL" ]]; then
  common_test_pass "milestone render: line 1 is the generated sentinel"
else
  common_test_fail "milestone render: line 1 should be the sentinel (got '$(sed -n '1p' "$scratch_ms/print.md")')"
fi

ms_l_title="$(line_of "$scratch_ms/print.md" "# Roadmap")"
ms_l_goal="$(line_of "$scratch_ms/print.md" "- Ship the generated roadmap")"
ms_l_table="$(line_of "$scratch_ms/print.md" "| Milestone | Status | Tasks done | Review |")"
ms_l_link="$(line_of "$scratch_ms/print.md" "See also: [Rules, conventions and repo context](#roadmap-context)")"
ms_l_m0="$(line_of "$scratch_ms/print.md" "## M0: Ground truth")"
ms_l_m1="$(line_of "$scratch_ms/print.md" "## M1: Workflow")"
ms_l_m2="$(line_of "$scratch_ms/print.md" "## M2: Later")"
ms_l_rules="$(line_of "$scratch_ms/print.md" "## Rules, conventions and repo context")"
if [[ -n "$ms_l_title" && -n "$ms_l_goal" && -n "$ms_l_table" && -n "$ms_l_link" && -n "$ms_l_m0" \
      && -n "$ms_l_m1" && -n "$ms_l_m2" && -n "$ms_l_rules" \
      && "$ms_l_title" -lt "$ms_l_goal" && "$ms_l_goal" -lt "$ms_l_table" \
      && "$ms_l_table" -lt "$ms_l_link" && "$ms_l_link" -lt "$ms_l_m0" \
      && "$ms_l_m0" -lt "$ms_l_m1" && "$ms_l_m1" -lt "$ms_l_m2" && "$ms_l_m2" -lt "$ms_l_rules" ]]; then
  common_test_pass "milestone render: intro, then milestones in array order, then the rules section"
else
  common_test_fail "milestone render: section order wrong (title=$ms_l_title goal=$ms_l_goal table=$ms_l_table link=$ms_l_link m0=$ms_l_m0 m1=$ms_l_m1 m2=$ms_l_m2 rules=$ms_l_rules)"
fi

if [[ "$(grep -E '^## ' "$scratch_ms/print.md" | tail -1)" == "## Rules, conventions and repo context" \
      && "$(grep -cE '^## ' "$scratch_ms/print.md")" -eq 4 ]]; then
  common_test_pass "milestone render: the rules section is the last of exactly four sections"
else
  common_test_fail "milestone render: expected four '## ' sections ending with the rules section ($(grep -E '^## ' "$scratch_ms/print.md" | tr '\n' ';'))"
fi

if [[ -n "$ms_l_m1" && "$(sed -n "$((ms_l_m1 - 1))p" "$scratch_ms/print.md")" == '<a id="milestone-m1"></a>' ]] \
    && grep -qF '| [M1: Workflow](#milestone-m1) | active | 2/6 | in_review (PR #34) |' "$scratch_ms/print.md" \
    && grep -qxF '<a id="roadmap-context"></a>' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: anchors derive from the stored id and the table links to them"
else
  common_test_fail "milestone render: expected the milestone-m1 anchor above its heading and a table row linking to it"
fi

if grep -qxF -- '- **Progress**: active -- 1/3 batches, 2/6 tasks done -- halfway' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: batch and member done-counts are derived (1/3 batches, 2/6 members)"
else
  common_test_fail "milestone render: Progress line wrong ($(grep -F -- '**Progress**' "$scratch_ms/print.md" | tr '\n' ';'))"
fi

if grep -qxF -- '- **Review**: in_review on `feat/m1`, PR #34 (updated 2026-11-18)' "$scratch_ms/print.md" \
    && grep -qxF -- '- **Gate**: All suites green.' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: Review line (state, ref, request, updated) and Gate line"
else
  common_test_fail "milestone render: Review or Gate line wrong ($(grep -F -e '**Review**' -e '**Gate**' "$scratch_ms/print.md" | tr '\n' ';'))"
fi

if grep -qxF '**Batch 1** -- Foundations (1/3 done)' "$scratch_ms/print.md" \
    && grep -qxF '/orchestrate 1, 2 --hard' "$scratch_ms/print.md" \
    && grep -qE '^6 done +Item six$' "$scratch_ms/print.md" \
    && grep -qE '^1 ready +Item one   <- start here$' "$scratch_ms/print.md" \
    && grep -qE '^2 blocked:1 +Item two$' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: a completed member is counted, listed as done, and left off the /orchestrate line"
else
  common_test_fail "milestone render: batch 1 block wrong ($(sed -n '/Batch 1/,/Batch 2/p' "$scratch_ms/print.md" | tr '\n' ';'))"
fi

if grep -qxF '**Batch 2** (done) -- Already finished' "$scratch_ms/print.md" \
    && ! grep -qE '^/orchestrate (6|9)' "$scratch_ms/print.md" \
    && [[ "$(grep -c '^/orchestrate ' "$scratch_ms/print.md")" -eq 2 ]]; then
  common_test_pass "milestone render: a batch with no open member renders as done with no /orchestrate line"
else
  common_test_fail "milestone render: done batch wrong ($(grep -e 'Batch 2' -e '^/orchestrate' "$scratch_ms/print.md" | tr '\n' ';'))"
fi

ms_m0_body="$(sed -n "$((ms_l_m0 + 1)),$((ms_l_m1 - 2))p" "$scratch_ms/print.md" | sed '/^$/d')"
if [[ "$ms_m0_body" == "Closed 2026-11-17 -- review: merged" ]]; then
  common_test_pass "milestone render: a closed milestone collapses to its heading plus one line"
else
  common_test_fail "milestone render: closed milestone body should be one line (got '$ms_m0_body')"
fi

if grep -qxF -- '- **Progress**: planned -- no batches yet' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: an open milestone with no batches says so instead of 0/0"
else
  common_test_fail "milestone render: empty open milestone Progress line wrong"
fi

ms_l_unsched="$(line_of "$scratch_ms/print.md" "### Open tasks in no batch")"
if [[ -n "$ms_l_unsched" && "$ms_l_unsched" -gt "$ms_l_rules" ]] \
    && [[ "$(sed -n "$((ms_l_unsched + 1)),\$p" "$scratch_ms/print.md" | grep -cE '^[0-9]+ ')" -eq 1 ]] \
    && sed -n "$((ms_l_unsched + 1)),\$p" "$scratch_ms/print.md" | grep -qE '^8 ready +item_eight$'; then
  common_test_pass "milestone render: open tasks in no batch are listed once, at the end of the last section"
else
  common_test_fail "milestone render: unscheduled list wrong ($(sed -n "${ms_l_rules:-1},\$p" "$scratch_ms/print.md" | tr '\n' ';'))"
fi

ms_l_repo="$(line_of "$scratch_ms/print.md" "### Repository")"
ms_l_rsub="$(line_of "$scratch_ms/print.md" "### Rules")"
ms_l_conv="$(line_of "$scratch_ms/print.md" "### Conventions")"
if [[ -n "$ms_l_repo" && -n "$ms_l_rsub" && -n "$ms_l_conv" && -n "$ms_l_unsched" \
      && "$ms_l_rules" -lt "$ms_l_repo" && "$ms_l_repo" -lt "$ms_l_rsub" \
      && "$ms_l_rsub" -lt "$ms_l_conv" && "$ms_l_conv" -lt "$ms_l_unsched" ]] \
    && grep -qxF -- '- A fixture repository.' "$scratch_ms/print.md" \
    && grep -qxF -- '- Never push.' "$scratch_ms/print.md" \
    && grep -qxF -- '- Run the suite first.' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: last section holds overview, rules, conventions, then the unscheduled list"
else
  common_test_fail "milestone render: last section order wrong (repo=$ms_l_repo rules=$ms_l_rsub conv=$ms_l_conv unsched=$ms_l_unsched)"
fi

if ! grep -qF 'UNRENDERED RATIONALE' "$scratch_ms/print.md" \
    && ! grep -qF 'fallback goal text' "$scratch_ms/print.md" \
    && ! grep -qF 'Coverage appendix' "$scratch_ms/print.md"; then
  common_test_pass "milestone render: rationale, the unused active_goal fallback and the coverage appendix are not rendered"
else
  common_test_fail "milestone render: rationale, active_goal fallback or coverage appendix leaked into the output"
fi

if grep -qE '^<!-- roadmap-generation mode=print tasks=5 topics=0 runs=3 pruned=0 retained=0 -->$' "$scratch_ms/stderr-print.txt"; then
  common_test_pass "milestone render: stderr marker keeps six fields (runs = open-milestone batches, retained = 0)"
else
  common_test_fail "milestone render: stderr marker wrong ($(cat "$scratch_ms/stderr-print.txt"))"
fi

# -- active_goal fallback when primary_goals is absent --
scratch_ms_goal="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms_goal"
jq 'del(.primary_goals)' "$scratch_ms_goal/specs/state.json" >"$scratch_ms_goal/specs/state.json.new" \
  && mv "$scratch_ms_goal/specs/state.json.new" "$scratch_ms_goal/specs/state.json"
ms_goal_out="$(run_ri "$scratch_ms_goal" --print 2>/dev/null)"
if grep -qxF -- '- fallback goal text' <<<"$ms_goal_out"; then
  common_test_pass "milestone render: falls back to active_goal when primary_goals is absent"
else
  common_test_fail "milestone render: active_goal fallback bullet missing"
fi

# -- --regenerate onto an absent target, byte-identical second run, the generated verdict --
scratch_ms_regen="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms_regen"
run_ri "$scratch_ms_regen" --regenerate >/dev/null 2>"$scratch_ms_regen/stderr-regen1.txt"
ms_regen_rc=$?
if [[ "$ms_regen_rc" -eq 0 && -f "$scratch_ms_regen/specs/ROADMAP.md" ]] \
    && grep -qE 'OUTCOME: --regenerate rewrote .* \(layout=generated, content changed\)$' "$scratch_ms_regen/stderr-regen1.txt"; then
  common_test_pass "milestone render: --regenerate writes onto an absent target and reports layout=generated"
else
  common_test_fail "milestone render: --regenerate onto an absent target failed (rc=$ms_regen_rc: $(cat "$scratch_ms_regen/stderr-regen1.txt"))"
fi

ms_sum1="$(sha256sum "$scratch_ms_regen/specs/ROADMAP.md" 2>/dev/null | awk '{print $1}')"
run_ri "$scratch_ms_regen" --regenerate >/dev/null 2>"$scratch_ms_regen/stderr-regen2.txt"
ms_sum2="$(sha256sum "$scratch_ms_regen/specs/ROADMAP.md" 2>/dev/null | awk '{print $1}')"
run_ri "$scratch_ms_regen" --regenerate --dry-run >"$scratch_ms_regen/stdout-dry.txt" 2>"$scratch_ms_regen/stderr-dry.txt"
if [[ -n "$ms_sum1" && "$ms_sum1" == "$ms_sum2" ]] \
    && grep -qE 'OUTCOME: --regenerate left .* unchanged \(layout=generated, no content change\)$' "$scratch_ms_regen/stderr-regen2.txt" \
    && grep -qE 'OUTCOME: --regenerate --dry-run diffed .*; wrote nothing \(layout=generated, no content change\)$' "$scratch_ms_regen/stderr-dry.txt" \
    && [[ ! -s "$scratch_ms_regen/stdout-dry.txt" ]]; then
  common_test_pass "milestone render: a second --regenerate is byte-identical and reports no content change"
else
  common_test_fail "milestone render: second --regenerate was not byte-identical ($(cat "$scratch_ms_regen/stderr-regen2.txt" "$scratch_ms_regen/stderr-dry.txt"))"
fi

if cmp -s "$scratch_ms/print.md" "$scratch_ms_regen/specs/ROADMAP.md"; then
  common_test_pass "milestone render: --print and --regenerate produce the same bytes"
else
  common_test_fail "milestone render: --print output differs from the regenerated file"
fi

classify_generated="$(preflight_classify "$scratch_ms_regen" 2>/dev/null)"
if [[ "$classify_generated" == "generated" ]]; then
  common_test_pass "preflight classify: a file whose first line is the sentinel reports 'generated'"
else
  common_test_fail "preflight classify: expected 'generated', got '$classify_generated'"
fi

cp "$scratch_ms_regen/specs/ROADMAP.md" "$scratch_ms_regen/before-scaffold.md"
preflight_scaffold "$scratch_ms_regen" >/dev/null 2>"$scratch_ms_regen/stderr-scaffold.txt"
ms_scaffold_rc=$?
if [[ "$ms_scaffold_rc" -ne 0 ]] && cmp -s "$scratch_ms_regen/before-scaffold.md" "$scratch_ms_regen/specs/ROADMAP.md" \
    && grep -qF "'generated'" "$scratch_ms_regen/stderr-scaffold.txt"; then
  common_test_pass "preflight scaffold: refuses a generated file and leaves it untouched"
else
  common_test_fail "preflight scaffold: should refuse a generated file (rc=$ms_scaffold_rc)"
fi

# The sentinel classifies ahead of any header the body holds: a generated file that happens to
# carry all eight classic headers still reads as generated.
scratch_ms_prec="$(build_scratch)"
write_state_fixture "$scratch_ms_prec"
write_roadmap_fixture "$scratch_ms_prec"
{ printf '%s\n' "$GENERATED_SENTINEL"; cat "$scratch_ms_prec/specs/ROADMAP.md"; } >"$scratch_ms_prec/specs/ROADMAP.md.new" \
  && mv "$scratch_ms_prec/specs/ROADMAP.md.new" "$scratch_ms_prec/specs/ROADMAP.md"
classify_prec="$(preflight_classify "$scratch_ms_prec" 2>/dev/null)"
if [[ "$classify_prec" == "generated" ]]; then
  common_test_pass "preflight classify: the sentinel is tested before the classic header vocabulary"
else
  common_test_fail "preflight classify: sentinel-first file with classic headers should read 'generated', got '$classify_prec'"
fi

# -- roadmap_context.output_path is honoured when --roadmap is not given --
scratch_ms_out="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms_out"
jq '.roadmap_context.output_path = "docs/plan/ROADMAP.md"' "$scratch_ms_out/specs/state.json" >"$scratch_ms_out/specs/state.json.new" \
  && mv "$scratch_ms_out/specs/state.json.new" "$scratch_ms_out/specs/state.json"
"$scratch_ms_out/.claude/scripts/roadmap-integration.sh" --state "$scratch_ms_out/specs/state.json" \
  --regenerate >/dev/null 2>"$scratch_ms_out/stderr-out.txt"
ms_out_rc=$?
if [[ "$ms_out_rc" -eq 0 && ! -e "$scratch_ms_out/specs/ROADMAP.md" ]] \
    && [[ "$(sed -n '1p' "$scratch_ms_out/docs/plan/ROADMAP.md" 2>/dev/null)" == "$GENERATED_SENTINEL" ]]; then
  common_test_pass "milestone render: roadmap_context.output_path is honoured when --roadmap is not given"
else
  common_test_fail "milestone render: output_path not honoured (rc=$ms_out_rc: $(cat "$scratch_ms_out/stderr-out.txt"))"
fi

jq '.roadmap_context.output_path = "../escape.md"' "$scratch_ms_out/specs/state.json" >"$scratch_ms_out/specs/state.json.new" \
  && mv "$scratch_ms_out/specs/state.json.new" "$scratch_ms_out/specs/state.json"
"$scratch_ms_out/.claude/scripts/roadmap-integration.sh" --state "$scratch_ms_out/specs/state.json" \
  --regenerate >/dev/null 2>"$scratch_ms_out/stderr-escape.txt"
ms_escape_rc=$?
if [[ "$ms_escape_rc" -ne 0 && ! -e "$(dirname "$scratch_ms_out")/escape.md" ]] \
    && grep -qF 'must be a repository-relative path' "$scratch_ms_out/stderr-escape.txt"; then
  common_test_pass "milestone render: an output_path that leaves the repository is refused"
else
  common_test_fail "milestone render: an escaping output_path should be refused (rc=$ms_escape_rc)"
fi

# -- a milestone store whose target is a classic file is refused like any other --
scratch_ms_classic="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms_classic"
write_roadmap_fixture "$scratch_ms_classic"
run_ri "$scratch_ms_classic" --regenerate >/dev/null 2>"$scratch_ms_classic/stderr.txt"
if [[ "$(sed -n '1p' "$scratch_ms_classic/specs/ROADMAP.md")" != "$GENERATED_SENTINEL" ]] \
    && ! grep -qF 'layout=generated' "$scratch_ms_classic/stderr.txt"; then
  common_test_pass "milestone render: a classic target is never overwritten by the whole-file write"
else
  common_test_fail "milestone render: a classic target must not take the whole-file write ($(cat "$scratch_ms_classic/stderr.txt"))"
fi

# -- an empty roadmap_milestones array with no file: a supported no-op, nothing written --
scratch_ms_empty="$(build_scratch)"
write_state_fixture_milestones "$scratch_ms_empty"
jq '.roadmap_milestones = []' "$scratch_ms_empty/specs/state.json" >"$scratch_ms_empty/specs/state.json.new" \
  && mv "$scratch_ms_empty/specs/state.json.new" "$scratch_ms_empty/specs/state.json"
run_ri "$scratch_ms_empty" --regenerate >/dev/null 2>"$scratch_ms_empty/stderr.txt"
ms_empty_rc=$?
if [[ "$ms_empty_rc" -eq 0 && ! -e "$scratch_ms_empty/specs/ROADMAP.md" ]]; then
  common_test_pass "milestone render: no milestones and no file is a no-op that writes nothing"
else
  common_test_fail "milestone render: empty milestones with no file should write nothing (rc=$ms_empty_rc)"
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
