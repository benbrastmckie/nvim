#!/usr/bin/env bash
# test-plan-file-scope-harvest.sh - Fixture-driven regression suite for
# scripts/plan-file-scope-harvest.sh, the harvester that unions every phase's "Files to modify"
# path list in a plan file into a deduplicated JSON array.
#
# Unlike several sibling suites in this directory, plan-file-scope-harvest.sh takes no REPO_ROOT
# dependency (a single positional plan-file argument, no specs/state.json access, no
# deploy-root-guard.sh), so this suite drives the SOURCE-STORE copy directly rather than
# requiring a prior deploy -- there is no bogus-root risk to guard against for a script that
# never derives a root from its own location.
#
# Cases (matching this task's Phase 2 Scope Hypothesis and the research report's four grammar
# wrinkles):
#   1. Colon-outside-bold punctuation form (`**Files to modify**:`).
#   2. Colon-inside-bold punctuation form (`**Files to modify:**`).
#   3. Backtick path with trailing ` - {description}` text (description discarded).
#   4. Indented wrapped continuation line contributes nothing (not a second entry).
#   5. A "none planned" prose sentinel line contributes nothing (not an error).
#   6. Multi-phase union and dedup (same path named in two phases collapses to one entry).
#   7. Zero "Files to modify" occurrences in the whole file returns `[]` with exit 0.
#   8. Missing-file argument exits non-zero.
#   9. Missing argument (usage error) exits non-zero.
#   10. List-item-wrapped field form (`- **Files to modify**:` with indented `  - \`path\`` entries,
#       as plan-format.md's own compact example template renders every field, and as a real local
#       plan under specs/*/plans/ was found to use during this phase's implementation-time
#       verification) is harvested correctly, and the following `- **Verification**:` field's own
#       indented sub-bullets are NOT swept in as bogus path entries.
#   11. A `.lean`-containing fixture plan under a capability-gate-closed fake repo (no generator
#       scripts) returns exactly the same array as it does with no root at all.
#   12. `PLAN_FILE_SCOPE_HARVEST_ROOT` pointing at a nonexistent path falls back without error.
#   13. `status.typ` is appended when present under a capable fake repo.
#   14. `status.typ` is NOT appended when absent under an otherwise-capable fake repo
#       (existence-conditional).
#   15. A no-`.lean` fixture in a fully capable fake repo appends nothing (no-op regression guard).
#   16. Three-level ancestor-chain README scan: a deep `.lean` file's chain hits exactly the
#       registered READMEs at three nesting levels, not the two unregistered deeper levels.
#   17. A fenced marker (inside a ` ```markdown ` block) is excluded (fence awareness).
#   18. A README registered for a sibling directory not on the chain is excluded (string
#       equality, not prefix matching).
#   19. A hand-maintained `<!-- INVENTORY: hand-maintained (dir=...) -->` opt-out marker is not
#       treated as a generated block.
#   20. The `automation-module-map.typ` narrow glob: positive for `Automation/Tactics/*.lean`,
#       negative for a sibling `Automation/Other/*.lean`.
#   21. The `machine-appendix.{jsonl,typ}` narrow pair: positive for `ProofSystem/Axioms.lean`,
#       negative for `ProofSystem/Other.lean`.
#
# Structural model: pass()/fail()/info() helpers, PASSED/FAILED integer counters, mktemp -d
# workdir with an EXIT-trap cleanup, exit 0 all-pass / 1 any-fail / 2 environment error.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARVESTER="$SCRIPT_DIR/../plan-file-scope-harvest.sh"

if [[ ! -f "$HARVESTER" ]]; then
  echo "ERROR: plan-file-scope-harvest.sh not found at $HARVESTER" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required by this suite (to validate harvested JSON) and is not on PATH" >&2
  exit 2
fi

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

info "Driving harvester at: $HARVESTER"

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# make_fake_repo: mktemps a directory carrying scripts/check-module-invariants.sh and
# scripts/typst-sync-check.sh stub files (capability gate OPEN) plus a specs/ subdirectory for
# fixture plans. Prints the repo path.
make_fake_repo() {
  local repo
  repo="$(mktemp -d)"
  mkdir -p "$repo/scripts" "$repo/specs"
  printf '#!/usr/bin/env bash\ntrue\n' > "$repo/scripts/check-module-invariants.sh"
  printf '#!/usr/bin/env bash\ntrue\n' > "$repo/scripts/typst-sync-check.sh"
  printf '%s\n' "$repo"
}

# make_bare_repo: the same tree, WITHOUT the two generator scripts (capability gate CLOSED).
make_bare_repo() {
  local repo
  repo="$(mktemp -d)"
  mkdir -p "$repo/specs"
  printf '%s\n' "$repo"
}

assert_json_array_eq() {
  # $1 = actual JSON, $2 = expected JSON (both as compact arrays), $3 = case label
  local actual="$1" expected="$2" label="$3"
  if ! echo "$actual" | jq -e 'type == "array"' >/dev/null 2>&1; then
    fail "$label: output is not a valid JSON array: $actual"
    return
  fi
  local norm_actual norm_expected
  norm_actual="$(echo "$actual" | jq -c 'sort')"
  norm_expected="$(echo "$expected" | jq -c 'sort')"
  if [[ "$norm_actual" == "$norm_expected" ]]; then
    pass "$label: harvested set matches expected ($norm_expected)"
  else
    fail "$label: expected $norm_expected, got $norm_actual"
  fi
}

# ── Case 1: colon-outside-bold punctuation form ──────────────────────────────────────────────
FIXTURE_1="$WORKDIR/case1.md"
cat > "$FIXTURE_1" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/foo.sh` - add the thing

**Verification**:
- ok
EOF
OUT_1="$(bash "$HARVESTER" "$FIXTURE_1")"
EXIT_1=$?
assert_json_array_eq "$OUT_1" '["scripts/foo.sh"]' "Case 1 (colon-outside-bold)"
if [[ "$EXIT_1" -eq 0 ]]; then pass "Case 1: exit code 0"; else fail "Case 1: expected exit 0, got $EXIT_1"; fi

# ── Case 2: colon-inside-bold punctuation form ───────────────────────────────────────────────
FIXTURE_2="$WORKDIR/case2.md"
cat > "$FIXTURE_2" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify:**
- `scripts/bar.sh`

**Verification**:
- ok
EOF
OUT_2="$(bash "$HARVESTER" "$FIXTURE_2")"
assert_json_array_eq "$OUT_2" '["scripts/bar.sh"]' "Case 2 (colon-inside-bold)"

# ── Case 3: backtick path with trailing description discarded ───────────────────────────────
FIXTURE_3="$WORKDIR/case3.md"
cat > "$FIXTURE_3" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `path/to/file.md` - add the required field with grammar and consumers subsection

**Verification**:
- ok
EOF
OUT_3="$(bash "$HARVESTER" "$FIXTURE_3")"
assert_json_array_eq "$OUT_3" '["path/to/file.md"]' "Case 3 (description discarded)"
if echo "$OUT_3" | grep -qF ' - '; then
  fail "Case 3: description fragment leaked into harvested output: $OUT_3"
else
  pass "Case 3: no description fragment in harvested output"
fi

# ── Case 4: indented wrapped continuation line contributes nothing ──────────────────────────
FIXTURE_4="$WORKDIR/case4.md"
cat > "$FIXTURE_4" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `path/one.sh` - a longer description that
  wraps onto a continuation line that must
  not be treated as a second entry

**Verification**:
- ok
EOF
OUT_4="$(bash "$HARVESTER" "$FIXTURE_4")"
assert_json_array_eq "$OUT_4" '["path/one.sh"]' "Case 4 (wrapped continuation contributes nothing)"

# ── Case 5: "none planned" prose sentinel contributes nothing, never errors ─────────────────
FIXTURE_5="$WORKDIR/case5.md"
cat > "$FIXTURE_5" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
No files planned for this phase.

**Verification**:
- ok
EOF
OUT_5="$(bash "$HARVESTER" "$FIXTURE_5")"
EXIT_5=$?
assert_json_array_eq "$OUT_5" '[]' "Case 5 (prose sentinel)"
if [[ "$EXIT_5" -eq 0 ]]; then
  pass "Case 5: prose sentinel does not cause a non-zero exit"
else
  fail "Case 5: expected exit 0 for a harmless prose sentinel, got $EXIT_5"
fi

# ── Case 6: multi-phase union and dedup ──────────────────────────────────────────────────────
FIXTURE_6="$WORKDIR/case6.md"
cat > "$FIXTURE_6" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/shared.sh` - initial change
- `scripts/only-in-phase-1.sh`

**Verification**:
- ok

---

### Phase 2: Example Two [NOT STARTED]

**Files to modify:**
- `scripts/shared.sh` - second change to the same file
- `scripts/only-in-phase-2.sh`

**Verification**:
- ok
EOF
OUT_6="$(bash "$HARVESTER" "$FIXTURE_6")"
assert_json_array_eq "$OUT_6" '["scripts/shared.sh","scripts/only-in-phase-1.sh","scripts/only-in-phase-2.sh"]' "Case 6 (multi-phase union/dedup)"
DUP_COUNT="$(echo "$OUT_6" | jq '[.[] | select(. == "scripts/shared.sh")] | length')"
if [[ "$DUP_COUNT" == "1" ]]; then
  pass "Case 6: shared path deduplicated to a single entry"
else
  fail "Case 6: expected shared path to appear exactly once, got count=$DUP_COUNT"
fi

# ── Case 7: zero "Files to modify" occurrences returns [] with exit 0 ───────────────────────
FIXTURE_7="$WORKDIR/case7.md"
cat > "$FIXTURE_7" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Verification**:
- this phase touches no files worth enumerating
EOF
OUT_7="$(bash "$HARVESTER" "$FIXTURE_7")"
EXIT_7=$?
assert_json_array_eq "$OUT_7" '[]' "Case 7 (no Files to modify field at all)"
if [[ "$EXIT_7" -eq 0 ]]; then
  pass "Case 7: exit code 0 for the no-field case"
else
  fail "Case 7: expected exit 0, got $EXIT_7"
fi

# ── Case 10: list-item-wrapped field form, indented entries, no bleed into next field ────────
FIXTURE_10="$WORKDIR/case10.md"
cat > "$FIXTURE_10" << 'EOF'
### Phase 1: Example [NOT STARTED]

- **Timing:** 1.5 hours
- **Depends on:** none
- **Verification Tier:** local
- **Files to modify**:
  - `scripts/tests/curl-stub.sh` - path dispatch, query parsing, new scenario knobs
  - `scripts/tests/generate-test-fixtures.py` - synthetic paged generator
  - `scripts/tests/fixtures/` - any static fixture files added
- **Verification**:
  - `bash -n` clean on the stub.
  - Scratch driver shows: items URL and RPC URL served different bodies.
EOF
OUT_10="$(bash "$HARVESTER" "$FIXTURE_10")"
EXIT_10=$?
assert_json_array_eq "$OUT_10" '["scripts/tests/curl-stub.sh","scripts/tests/generate-test-fixtures.py","scripts/tests/fixtures/"]' "Case 10 (list-item-wrapped field form)"
if [[ "$EXIT_10" -eq 0 ]]; then
  pass "Case 10: exit code 0"
else
  fail "Case 10: expected exit 0, got $EXIT_10"
fi
if echo "$OUT_10" | grep -qi "bash -n\|Scratch driver"; then
  fail "Case 10: the following Verification field's indented sub-bullets leaked into the harvest: $OUT_10"
else
  pass "Case 10: the following Verification field's indented sub-bullets did not leak into the harvest"
fi

# ── Case 11: capability gate closed (bare repo) == no root at all ───────────────────────────
FIXTURE_11="$WORKDIR/case11.md"
cat > "$FIXTURE_11" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Foo.lean` - a change

**Verification**:
- ok
EOF
BARE_REPO="$(make_bare_repo)"
OUT_11_BARE="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$BARE_REPO" bash "$HARVESTER" "$FIXTURE_11")"
# "No root at all" must deterministically fail BOTH resolve_repo_root() fallback legs (the
# plan-file-directory git resolve, then the CWD git resolve) regardless of which directory this
# suite itself happens to be invoked from -- otherwise this case is silently environment-
# dependent (it passes when invoked from a git repo lacking the two generators, e.g. this
# source-store checkout, and spuriously fails once deployed into a target repo that DOES carry
# them, e.g. the one this harvester actually ships into). WORKDIR (under mktemp -d, i.e. /tmp)
# has no git ancestor on any platform this suite runs on, so cd'ing into it before invoking the
# harvester pins the CWD-resolve leg to "unresolvable" independent of the caller's own CWD.
OUT_11_NOROOT="$(cd "$WORKDIR" && PLAN_FILE_SCOPE_HARVEST_ROOT="/nonexistent-root-$$" bash "$HARVESTER" "$FIXTURE_11")"
assert_json_array_eq "$OUT_11_BARE" '["FormalSystem/Foo.lean"]' "Case 11 (capability gate closed)"
norm_bare="$(echo "$OUT_11_BARE" | jq -c 'sort')"
norm_noroot="$(echo "$OUT_11_NOROOT" | jq -c 'sort')"
if [[ "$norm_bare" == "$norm_noroot" ]]; then
  pass "Case 11: capability-gate-closed output matches no-root output"
else
  fail "Case 11: capability-gate-closed ($norm_bare) differs from no-root ($norm_noroot)"
fi
rm -rf "$BARE_REPO"

# ── Case 12: PLAN_FILE_SCOPE_HARVEST_ROOT pointing at a nonexistent path falls back ──────────
# Same CWD pinning as Case 11, for the same reason (deterministic unresolvable root regardless
# of the suite's own invocation directory).
OUT_12="$(cd "$WORKDIR" && PLAN_FILE_SCOPE_HARVEST_ROOT="/nonexistent-root-$$" bash "$HARVESTER" "$FIXTURE_11")"
EXIT_12=$?
assert_json_array_eq "$OUT_12" '["FormalSystem/Foo.lean"]' "Case 12 (nonexistent PLAN_FILE_SCOPE_HARVEST_ROOT falls back)"
if [[ "$EXIT_12" -eq 0 ]]; then
  pass "Case 12: exit code 0 on unresolvable override root"
else
  fail "Case 12: expected exit 0, got $EXIT_12"
fi

# ── Case 13: status.typ appended when present under a capable fake repo ─────────────────────
FAKE_REPO_13="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_13/typst/generated"
: > "$FAKE_REPO_13/typst/generated/status.typ"
OUT_13="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_13" bash "$HARVESTER" "$FIXTURE_11")"
assert_json_array_eq "$OUT_13" '["FormalSystem/Foo.lean","typst/generated/status.typ"]' "Case 13 (status.typ present, appended)"
rm -rf "$FAKE_REPO_13"

# ── Case 14: status.typ NOT appended when absent under an otherwise-capable fake repo ───────
FAKE_REPO_14="$(make_fake_repo)"
OUT_14="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_14" bash "$HARVESTER" "$FIXTURE_11")"
assert_json_array_eq "$OUT_14" '["FormalSystem/Foo.lean"]' "Case 14 (status.typ absent, not appended)"
rm -rf "$FAKE_REPO_14"

# ── Case 15: no-.lean fixture in a fully capable fake repo appends nothing ──────────────────
FIXTURE_15="$WORKDIR/case15.md"
cat > "$FIXTURE_15" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `scripts/foo.sh`
- `docs/bar.md`

**Verification**:
- ok
EOF
FAKE_REPO_15="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_15/typst/generated"
: > "$FAKE_REPO_15/typst/generated/status.typ"
OUT_15="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_15" bash "$HARVESTER" "$FIXTURE_15")"
assert_json_array_eq "$OUT_15" '["scripts/foo.sh","docs/bar.md"]' "Case 15 (no-.lean no-op)"
rm -rf "$FAKE_REPO_15"

# ── Case 16: three-level ancestor-chain README scan ──────────────────────────────────────────
FIXTURE_16="$WORKDIR/case16.md"
cat > "$FIXTURE_16" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Metalogic/Decidability/RaySummary/Deep.lean`

**Verification**:
- ok
EOF
FAKE_REPO_16="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_16/FormalSystem/Metalogic/Decidability/RaySummary"
cat > "$FAKE_REPO_16/README.md" << 'EOF'
<!-- BEGIN GENERATED: inventory dir=FormalSystem rows=totals -->
| x |
|---|
<!-- END GENERATED -->
EOF
cat > "$FAKE_REPO_16/FormalSystem/README.md" << 'EOF'
<!-- BEGIN GENERATED: inventory dir=FormalSystem rows=loose -->
| x |
|---|
<!-- END GENERATED -->
EOF
cat > "$FAKE_REPO_16/FormalSystem/Metalogic/README.md" << 'EOF'
<!-- BEGIN GENERATED: inventory dir=FormalSystem/Metalogic rows=loose -->
| x |
|---|
<!-- END GENERATED -->
EOF
# Two deeper, unregistered levels: no markers at all.
cat > "$FAKE_REPO_16/FormalSystem/Metalogic/Decidability/README.md" << 'EOF'
# Decidability

Hand-authored, no inventory marker.
EOF
cat > "$FAKE_REPO_16/FormalSystem/Metalogic/Decidability/RaySummary/README.md" << 'EOF'
# RaySummary

Hand-authored, no inventory marker.
EOF
OUT_16="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_16" bash "$HARVESTER" "$FIXTURE_16")"
assert_json_array_eq "$OUT_16" '["FormalSystem/Metalogic/Decidability/RaySummary/Deep.lean","README.md","FormalSystem/README.md","FormalSystem/Metalogic/README.md"]' "Case 16 (three-level ancestor chain, two deeper levels excluded)"
rm -rf "$FAKE_REPO_16"

# ── Case 17: fenced marker excluded (fence awareness) ────────────────────────────────────────
FAKE_REPO_17="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_17/FormalSystem" "$FAKE_REPO_17/docs"
cat > "$FAKE_REPO_17/docs/readme-standard.md" << 'EOF'
# README standard

Example of the marker syntax:

```markdown
<!-- BEGIN GENERATED: inventory dir=FormalSystem -->
| x |
|---|
<!-- END GENERATED -->
```

That was inside a fence and must not be treated as a live marker.
EOF
OUT_17="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_17" bash "$HARVESTER" "$FIXTURE_11")"
assert_json_array_eq "$OUT_17" '["FormalSystem/Foo.lean"]' "Case 17 (fenced marker excluded)"
rm -rf "$FAKE_REPO_17"

# ── Case 18: sibling-directory README excluded (string equality, not prefix matching) ───────
FAKE_REPO_18="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_18/FormalSystem/Metalogic/BXCanonical" "$FAKE_REPO_18/FormalSystem/Metalogic/WeakCanonical"
cat > "$FAKE_REPO_18/FormalSystem/Metalogic/BXCanonical/README.md" << 'EOF'
<!-- BEGIN GENERATED: inventory dir=FormalSystem/Metalogic/BXCanonical rows=loose -->
| x |
|---|
<!-- END GENERATED -->
EOF
FIXTURE_18="$WORKDIR/case18.md"
cat > "$FIXTURE_18" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Metalogic/WeakCanonical/Sibling.lean`

**Verification**:
- ok
EOF
OUT_18="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_18" bash "$HARVESTER" "$FIXTURE_18")"
assert_json_array_eq "$OUT_18" '["FormalSystem/Metalogic/WeakCanonical/Sibling.lean"]' "Case 18 (sibling directory excluded)"
rm -rf "$FAKE_REPO_18"

# ── Case 19: hand-maintained opt-out marker is NOT treated as a generated block ──────────────
FAKE_REPO_19="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_19/FormalSystem/Semantics"
cat > "$FAKE_REPO_19/FormalSystem/Semantics/README.md" << 'EOF'
<!-- INVENTORY: hand-maintained (dir=FormalSystem/Semantics) -->
| x |
|---|
EOF
FIXTURE_19="$WORKDIR/case19.md"
cat > "$FIXTURE_19" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Semantics/Foo.lean`

**Verification**:
- ok
EOF
OUT_19="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_19" bash "$HARVESTER" "$FIXTURE_19")"
assert_json_array_eq "$OUT_19" '["FormalSystem/Semantics/Foo.lean"]' "Case 19 (hand-maintained opt-out not treated as generated)"
rm -rf "$FAKE_REPO_19"

# ── Case 20: automation-module-map.typ narrow glob (positive and negative) ──────────────────
FAKE_REPO_20="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_20/typst/generated"
: > "$FAKE_REPO_20/typst/generated/automation-module-map.typ"
FIXTURE_20_POS="$WORKDIR/case20pos.md"
cat > "$FIXTURE_20_POS" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Automation/Tactics/Foo.lean`

**Verification**:
- ok
EOF
FIXTURE_20_NEG="$WORKDIR/case20neg.md"
cat > "$FIXTURE_20_NEG" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/Automation/Other/Foo.lean`

**Verification**:
- ok
EOF
OUT_20_POS="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_20" bash "$HARVESTER" "$FIXTURE_20_POS")"
OUT_20_NEG="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_20" bash "$HARVESTER" "$FIXTURE_20_NEG")"
assert_json_array_eq "$OUT_20_POS" '["FormalSystem/Automation/Tactics/Foo.lean","typst/generated/automation-module-map.typ"]' "Case 20 (positive: Automation/Tactics glob)"
assert_json_array_eq "$OUT_20_NEG" '["FormalSystem/Automation/Other/Foo.lean"]' "Case 20 (negative: sibling Automation/Other dir)"
rm -rf "$FAKE_REPO_20"

# ── Case 21: machine-appendix.{jsonl,typ} narrow pair (positive and negative) ───────────────
FAKE_REPO_21="$(make_fake_repo)"
mkdir -p "$FAKE_REPO_21/typst/generated"
: > "$FAKE_REPO_21/typst/generated/machine-appendix.jsonl"
: > "$FAKE_REPO_21/typst/generated/machine-appendix.typ"
FIXTURE_21_POS="$WORKDIR/case21pos.md"
cat > "$FIXTURE_21_POS" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/ProofSystem/Axioms.lean`

**Verification**:
- ok
EOF
FIXTURE_21_NEG="$WORKDIR/case21neg.md"
cat > "$FIXTURE_21_NEG" << 'EOF'
### Phase 1: Example [NOT STARTED]

**Files to modify**:
- `FormalSystem/ProofSystem/Other.lean`

**Verification**:
- ok
EOF
OUT_21_POS="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_21" bash "$HARVESTER" "$FIXTURE_21_POS")"
OUT_21_NEG="$(PLAN_FILE_SCOPE_HARVEST_ROOT="$FAKE_REPO_21" bash "$HARVESTER" "$FIXTURE_21_NEG")"
assert_json_array_eq "$OUT_21_POS" '["FormalSystem/ProofSystem/Axioms.lean","typst/generated/machine-appendix.jsonl","typst/generated/machine-appendix.typ"]' "Case 21 (positive: Axioms.lean)"
assert_json_array_eq "$OUT_21_NEG" '["FormalSystem/ProofSystem/Other.lean"]' "Case 21 (negative: ProofSystem/Other.lean)"
rm -rf "$FAKE_REPO_21"

# ── Case 8: missing-file argument exits non-zero ─────────────────────────────────────────────
bash "$HARVESTER" "$WORKDIR/does-not-exist.md" >/dev/null 2>&1
EXIT_8=$?
if [[ "$EXIT_8" -ne 0 ]]; then
  pass "Case 8: nonexistent plan file argument exits non-zero ($EXIT_8)"
else
  fail "Case 8: expected non-zero exit for a nonexistent plan file, got 0"
fi

# ── Case 9: missing argument (usage error) exits non-zero ───────────────────────────────────
bash "$HARVESTER" >/dev/null 2>&1
EXIT_9=$?
if [[ "$EXIT_9" -ne 0 ]]; then
  pass "Case 9: missing positional argument exits non-zero ($EXIT_9)"
else
  fail "Case 9: expected non-zero exit for a missing argument, got 0"
fi

echo ""
echo "=== Summary ==="
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
