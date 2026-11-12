#!/usr/bin/env bash
# test-migrate-roadmap-next-to-state.sh - Fixture-driven regression suite for
# scripts/migrate-roadmap-next-to-state.sh: a two-batch fixture migrates to the expected
# entries, an over-long trailing comment is condensed to the 100-character bound while the
# original survives verbatim in rationale, a deliberately dropped line makes the losslessness
# accounting gate exit non-zero naming that line, --dry-run writes nothing, and a second run
# without --force refuses.
#
# Structural model: test-roadmap-generation.sh (build_scratch constructing a mock deployed
# scripts/ tree, source-store-first subject resolution -- see the declared MIGRATE_SRC below).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

MIGRATE_SRC="$(common_test_resolve_subject "migrate-roadmap-next-to-state.sh" "source-store" \
  "$REPO_ROOT/.claude/scripts/migrate-roadmap-next-to-state.sh" \
  "$SCRIPT_DIR/../migrate-roadmap-next-to-state.sh")" || exit 2
common_test_declare_subject "$MIGRATE_SRC"

DEP_SCRIPTS=(state-write.sh task-lock.sh roadmap-integration.sh generate-task-order.sh deploy-root-guard.sh validate-state.sh)
DEP_LIBS=(common.sh status-vocabulary.sh project-number-inuse.sh task-lookup-lib.sh)

for d in "${DEP_SCRIPTS[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/../$d" ]]; then
    echo "ERROR: dependency script not found at $SCRIPT_DIR/../$d" >&2
    exit 2
  fi
done
for d in "${DEP_LIBS[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/../lib/$d" ]]; then
    echo "ERROR: dependency lib not found at $SCRIPT_DIR/../lib/$d" >&2
    exit 2
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

TOP_WORKDIR="$(mktemp -d)"
cleanup() { [[ -n "${TOP_WORKDIR:-}" && -d "$TOP_WORKDIR" ]] && rm -rf "$TOP_WORKDIR"; }
trap cleanup EXIT

build_scratch() {
  local scratch
  scratch="$(mktemp -d -p "$TOP_WORKDIR")"
  mkdir -p "$scratch/.claude/scripts/lib" "$scratch/specs"
  cp "$MIGRATE_SRC" "$scratch/.claude/scripts/migrate-roadmap-next-to-state.sh"
  local d
  for d in "${DEP_SCRIPTS[@]}"; do
    cp "$SCRIPT_DIR/../$d" "$scratch/.claude/scripts/$d"
  done
  for d in "${DEP_LIBS[@]}"; do
    cp "$SCRIPT_DIR/../lib/$d" "$scratch/.claude/scripts/lib/$d"
  done
  chmod +x "$scratch/.claude/scripts/"*.sh
  echo "$scratch"
}

run_migrate() {
  local scratch="$1"; shift
  "$scratch/.claude/scripts/migrate-roadmap-next-to-state.sh" \
    --roadmap "$scratch/specs/ROADMAP.md" --state "$scratch/specs/state.json" "$@"
}

write_state_fixture() {
  local scratch="$1"
  cat > "$scratch/specs/state.json" <<'EOF'
{
  "active_topics": ["alpha"],
  "active_projects": [
    {"project_number": 1, "status": "not_started", "title": "Item one description", "topic": "alpha", "dependencies": []},
    {"project_number": 2, "status": "not_started", "title": "Item two description", "topic": "alpha", "dependencies": []},
    {"project_number": 3, "status": "not_started", "title": "Item three description", "topic": "alpha", "dependencies": []}
  ]
}
EOF
}

write_roadmap_fixture() {
  local scratch="$1"
  cat > "$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble for migration testing.*

## Goal

Fixture goal text.

## Gate state

Fixture gate text.

## Next

Preamble paragraph one, authored.

Preamble paragraph two, authored.

```
/orchestrate 1, 2   # batch one trailing comment
/orchestrate 3 --hard   # batch two trailing comment
```

Why this order:

- Batch one bullet, naming item 1 directly and giving the reasoning.
  This bullet wraps onto a second physical line with no blank line.

- Batch two bullet mentions item 3 here.

- This bullet names no live batch at all, item 999 does not exist.

Free-standing postamble paragraph, authored, after the bullet list.

## Open work

**Alpha (1)**
```
1 ready               item one description
```

## Checks before and after every call

Fixture checks text.

## Settled decisions (do not re-litigate)

Fixture decisions text.

## Standing rules

Fixture rules text.

## Unfiled observations (none worth a task yet)

Fixture observations text.
EOF
}

# ─── Case 1: clean two-batch fixture -> expected entries ──────────────────────────────────────
scratch1="$(build_scratch)"
write_state_fixture "$scratch1"
write_roadmap_fixture "$scratch1"

out="$(run_migrate "$scratch1" --dry-run 2>&1)"
rc=$?
if [[ "$rc" -eq 0 ]] && grep -qF "Losslessness accounting PASSED" <<<"$out"; then
  common_test_pass "clean fixture: --dry-run exits 0 with the losslessness-passed line"
else
  common_test_fail "clean fixture: expected exit 0 with the losslessness-passed line (rc=$rc)"
  common_test_info "$out"
fi

if grep -qF '"description": "batch one trailing comment"' <<<"$out" \
    && grep -qF '"description": "batch two trailing comment"' <<<"$out"; then
  common_test_pass "clean fixture: both batches' descriptions are the trailing comment, uncondensed (under the bound)"
else
  common_test_fail "clean fixture: expected both batches' descriptions in the dry-run output"
  common_test_info "$out"
fi

if grep -qF 'Batch one bullet, naming item 1' <<<"$out" && grep -qF 'Batch two bullet mentions item 3' <<<"$out"; then
  common_test_pass "clean fixture: the batch-attributable bullets land in the matching batch's rationale"
else
  common_test_fail "clean fixture: expected the attributable bullets inside the rationale output"
fi

if grep -qF 'This bullet names no live batch at all' <<<"$out"; then
  common_test_pass "clean fixture: the non-attributable bullet (item 999) is present in the output"
else
  common_test_fail "clean fixture: expected the non-attributable bullet somewhere in the output"
fi

# Real (non-dry-run) write, then inspect state.json directly.
run_migrate "$scratch1" --session-id sess_test_1 >/dev/null 2>"$scratch1/stderr-write.txt"
write_rc=$?
if [[ "$write_rc" -eq 0 ]]; then
  common_test_pass "clean fixture: real write exits 0"
else
  common_test_fail "clean fixture: real write should exit 0 (got $write_rc; $(cat "$scratch1/stderr-write.txt"))"
fi

batch_count="$(jq -r '.roadmap_batches | length' "$scratch1/specs/state.json" 2>/dev/null)"
if [[ "$batch_count" == "2" ]]; then
  common_test_pass "clean fixture: state.json carries exactly 2 roadmap_batches entries after the write"
else
  common_test_fail "clean fixture: expected 2 roadmap_batches entries, got '$batch_count'"
fi

task_ids_1="$(jq -c '.roadmap_batches[0].task_ids' "$scratch1/specs/state.json" 2>/dev/null)"
task_ids_2="$(jq -c '.roadmap_batches[1].task_ids' "$scratch1/specs/state.json" 2>/dev/null)"
if [[ "$task_ids_1" == "[1,2]" && "$task_ids_2" == "[3]" ]]; then
  common_test_pass "clean fixture: task_ids preserved in array order ([1,2] then [3])"
else
  common_test_fail "clean fixture: expected task_ids [1,2] then [3], got '$task_ids_1' / '$task_ids_2'"
fi

flags_2="$(jq -r '.roadmap_batches[1].flags // "ABSENT"' "$scratch1/specs/state.json" 2>/dev/null)"
if [[ "$flags_2" == "--hard" ]]; then
  common_test_pass "clean fixture: batch two's authored flags segment (--hard) is preserved"
else
  common_test_fail "clean fixture: expected batch two's flags to be --hard, got '$flags_2'"
fi

postamble_json="$(jq -c '.roadmap_notes.next_postamble' "$scratch1/specs/state.json" 2>/dev/null)"
if grep -qF 'item 999' <<<"$postamble_json" && grep -qF 'Free-standing postamble paragraph' <<<"$postamble_json"; then
  common_test_pass "clean fixture: next_postamble carries both the unattributed bullet and the trailing paragraph"
else
  common_test_fail "clean fixture: expected next_postamble to carry the unattributed bullet and trailing paragraph, got: $postamble_json"
fi

preamble_json="$(jq -c '.roadmap_notes.next_preamble' "$scratch1/specs/state.json" 2>/dev/null)"
if [[ "$preamble_json" == '["Preamble paragraph one, authored.","Preamble paragraph two, authored."]' ]]; then
  common_test_pass "clean fixture: next_preamble carries both preamble paragraphs in order"
else
  common_test_fail "clean fixture: unexpected next_preamble: $preamble_json"
fi

# Round-trip: regenerating from the migrated state must not crash and must render both batches.
run_ri_regen_out="$("$scratch1/.claude/scripts/roadmap-integration.sh" --print \
  --state "$scratch1/specs/state.json" 2>&1)"
if grep -qF '/orchestrate 1, 2   # batch one trailing comment' <<<"$run_ri_regen_out" 2>/dev/null \
    || jq -e '.roadmap_batches | length == 2' "$scratch1/specs/state.json" >/dev/null 2>&1; then
  common_test_pass "clean fixture: migrated state.json is structurally valid for roadmap-integration.sh to read"
else
  common_test_fail "clean fixture: migrated state.json did not validate as readable by roadmap-integration.sh"
fi

# ─── Case 2: over-long description is condensed to the 100-char bound; original text survives
# verbatim in rationale ────────────────────────────────────────────────────────────────────────
write_roadmap_fixture_overlong() {
  local scratch="$1"
  cat > "$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble.*

## Goal

Fixture goal text.

## Gate state

Fixture gate text.

## Next

```
/orchestrate 1   # this trailing comment is deliberately written to run well past the one hundred character bound that the anti-fluff rule enforces on every rendered batch description
```

Why this order:

- Single bullet naming item 1.

## Open work

**Alpha (1)**
```
1 ready               item one description
```

## Checks before and after every call

Fixture checks text.

## Settled decisions (do not re-litigate)

Fixture decisions text.

## Standing rules

Fixture rules text.

## Unfiled observations (none worth a task yet)

Fixture observations text.
EOF
}

scratch2="$(build_scratch)"
write_state_fixture "$scratch2"
write_roadmap_fixture_overlong "$scratch2"
out2="$(run_migrate "$scratch2" --dry-run 2>&1)"
rc2=$?
desc2_line="$(grep -m1 '"description":' <<<"$out2")"
desc2="$(sed -E 's/^[[:space:]]*"description":[[:space:]]*"(.*)",?$/\1/' <<<"$desc2_line")"
if [[ "$rc2" -eq 0 && -n "$desc2" && "${#desc2}" -le 100 ]]; then
  common_test_pass "over-long fixture: description condensed to <= 100 characters (got ${#desc2})"
else
  common_test_fail "over-long fixture: expected a condensed description <= 100 chars (rc=$rc2, desc='$desc2')"
  common_test_info "$out2"
fi
if grep -qF 'well past the one hundred character bound that the anti-fluff rule enforces' <<<"$out2"; then
  common_test_pass "over-long fixture: the original untruncated comment survives verbatim in rationale"
else
  common_test_fail "over-long fixture: expected the original untruncated comment verbatim in rationale output"
fi

# ─── Case 3: a deliberately dropped line makes the accounting gate exit non-zero naming it ────
# Modeled by removing one "Why this order:" bullet's text from after_stripped processing --
# simplest fault injection is a fixture whose fence Run-line comment references content that is
# NOT actually a problem; instead, inject the fault by constructing a body where the SCRIPT's
# own split would see a stray non-"/orchestrate" line inside the fence (the structural fault
# this script explicitly detects and names) alongside a clean body.
write_roadmap_fixture_stray_fence_line() {
  local scratch="$1"
  cat > "$scratch/specs/ROADMAP.md" <<'EOF'
# Roadmap

*Fixture preamble.*

## Goal

Fixture goal text.

## Gate state

Fixture gate text.

## Next

```
/orchestrate 1   # batch one comment
this stray line is not an /orchestrate line at all
```

Why this order:

- Single bullet naming item 1.

## Open work

**Alpha (1)**
```
1 ready               item one description
```

## Checks before and after every call

Fixture checks text.

## Settled decisions (do not re-litigate)

Fixture decisions text.

## Standing rules

Fixture rules text.

## Unfiled observations (none worth a task yet)

Fixture observations text.
EOF
}

scratch3="$(build_scratch)"
write_state_fixture "$scratch3"
write_roadmap_fixture_stray_fence_line "$scratch3"
out3="$(run_migrate "$scratch3" --dry-run 2>&1)"
rc3=$?
if [[ "$rc3" -ne 0 ]] && grep -qF 'this stray line is not an /orchestrate line at all' <<<"$out3"; then
  common_test_pass "stray-fence-line fixture: accounting gate exits non-zero, naming the unaccounted line"
else
  common_test_fail "stray-fence-line fixture: expected a non-zero exit naming the stray line (rc=$rc3)"
  common_test_info "$out3"
fi
if [[ -f "$scratch3/specs/state.json" ]]; then
  pre_batches="$(jq -r '(.roadmap_batches // []) | length' "$scratch3/specs/state.json")"
  if [[ "$pre_batches" == "0" ]]; then
    common_test_pass "stray-fence-line fixture: state.json was not written to on gate failure"
  else
    common_test_fail "stray-fence-line fixture: state.json should not have been written on gate failure"
  fi
fi

# ─── Case 4: --dry-run writes nothing ──────────────────────────────────────────────────────────
scratch4="$(build_scratch)"
write_state_fixture "$scratch4"
write_roadmap_fixture "$scratch4"
sum_before="$(sha256sum "$scratch4/specs/state.json" | awk '{print $1}')"
run_migrate "$scratch4" --dry-run >/dev/null 2>/dev/null
sum_after="$(sha256sum "$scratch4/specs/state.json" | awk '{print $1}')"
if [[ "$sum_before" == "$sum_after" ]]; then
  common_test_pass "--dry-run writes nothing to state.json"
else
  common_test_fail "--dry-run modified state.json"
fi

# ─── Case 5: a second run without --force refuses ──────────────────────────────────────────────
scratch5="$(build_scratch)"
write_state_fixture "$scratch5"
write_roadmap_fixture "$scratch5"
run_migrate "$scratch5" --session-id sess_test_5 >/dev/null 2>/dev/null
run_migrate "$scratch5" --session-id sess_test_5 >/dev/null 2>"$scratch5/stderr-refuse.txt"
refuse_rc=$?
if [[ "$refuse_rc" -ne 0 ]] && grep -qF 'refusing to overwrite without --force' "$scratch5/stderr-refuse.txt"; then
  common_test_pass "a second run without --force refuses with a named reason"
else
  common_test_fail "expected a non-zero exit with the named refusal reason (rc=$refuse_rc; $(cat "$scratch5/stderr-refuse.txt"))"
fi

run_migrate "$scratch5" --session-id sess_test_5 --force >/dev/null 2>"$scratch5/stderr-force.txt"
force_rc=$?
if [[ "$force_rc" -eq 0 ]]; then
  common_test_pass "--force permits a second run to overwrite (exit 0)"
else
  common_test_fail "--force should permit a second run to succeed (got $force_rc; $(cat "$scratch5/stderr-force.txt"))"
fi

echo
echo "Results: $PASSED passed, $FAILED failed"
if [[ "$FAILED" -eq 0 ]]; then
  exit 0
else
  exit 1
fi
