#!/usr/bin/env bash
# test-books-observe.sh - Fixture-driven, hermetic suite for books-observe.sh.
#
# Per context/standards/shell-script-testing.md: every fixture is an isolated `mktemp -d` git
# repo constructed inline at run time. Nothing here depends on a real specs/ tree or on the
# external consuming repository (~/Projects/Logos/Verification) -- no network either. Class B
# strict mode (this is a PASSED/FAILED-counter harness that must report every case, not abort on
# the first failure).
#
# Covers the plan's eleven named acceptance behaviors: THE JOIN (flat-index shape), THE
# ABSENT-PROBE PATH, THE PAIRED-BURDEN REQUIREMENT, POLARITY/DIMENSION VALIDATION, BACKFILL
# MARKING, NON-BLOCKING FAILURE, VACUOUS PASS, DIRECTORY SHAPE, TRANSITIONAL SHAPE, FAULT-FRAME
# HEADING GRAMMAR, and POINTER-ONLY EDIT. The last four (Cases 8-11) cover the record-shape
# split the consuming repository made to books/book-convention.md -- see
# context/project/books/README.md's convention-record paragraph for the shape itself.

# task-ref-ok:begin inline, category 3: command-usage examples -- every fixture below builds a
# throwaway git repo whose commit subjects and issues.jsonl/metrics.jsonl content follow this
# codebase's own `task {N}:` / `task {N} phase {P}:` commit-subject convention literally, because
# books-observe.sh's commit-range resolution greps for that exact literal shape; a placeholder
# would not match and would silently disable the assertion, mirroring
# scripts/tests/test-dispatch-metrics.sh's identical fixture convention.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OBS="${SCRIPT_DIR}/../books-observe.sh"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

if [[ ! -x "$OBS" ]]; then
  fail "prerequisite: $OBS is not executable (or does not exist)"
  echo ""
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "test-books-observe.sh: jq is required to read the observer's JSON output" >&2
  exit 2
fi

# assert_exit CASE_NAME EXPECTED_EXIT ACTUAL_EXIT
assert_exit() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    pass "${name}: exit code ${actual} (expected ${expected})"
  else
    fail "${name}: exit code ${actual}, expected ${expected}"
  fi
}

# assert_json CASE_NAME JSON_FILE JQ_FILTER EXPECTED
assert_json() {
  local name="$1" json_file="$2" filter="$3" expected="$4" actual
  actual="$(jq -r "$filter" "$json_file" 2>/dev/null)"
  if [[ "$actual" == "$expected" ]]; then
    pass "${name}: ${filter} == ${expected}"
  else
    fail "${name}: ${filter} == '${actual}', expected '${expected}'"
    if [[ -f "$json_file" ]]; then
      info "  --- actual record ---"
      while IFS= read -r line; do info "  $line"; done < "$json_file"
    else
      info "  --- record file does not exist: $json_file ---"
    fi
  fi
}

# assert_json_true CASE_NAME JSON_FILE JQ_BOOLEAN_FILTER
assert_json_true() {
  local name="$1" json_file="$2" filter="$3" actual
  actual="$(jq -r "$filter" "$json_file" 2>/dev/null)"
  if [[ "$actual" == "true" ]]; then
    pass "${name}: ${filter}"
  else
    fail "${name}: ${filter} was '${actual}', expected true"
  fi
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

init_repo() {
  local dir="$1"
  mkdir -p "$dir"
  (cd "$dir" && git init -q && git config user.email "t@t.local" && git config user.name "T")
}

commit_files() {
  # commit_files REPO MESSAGE PATH...
  local dir="$1" msg="$2"
  shift 2
  (cd "$dir" && git add "$@" && git commit -q -m "$msg")
}

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 1: THE JOIN -- a fixture with both issues.jsonl and metrics.jsonl, plus a book_requires
# commit and a Validated-by promotion commit, produces a record carrying all of it, grouped by
# dimension and polarity, with both mechanically-computed books facts present.
#
# SHAPE NOTE: this fixture is the FLAT-INDEX shape specifically (the pre-split
# `books/book-convention.md` carrying `## Decision N: ...` headings directly). It alone cannot
# detect directory-shape drift -- see Case 8 (directory), Case 9 (transitional), Case 10
# (fault-frame heading grammar), and Case 11 (pointer-only edit) below for the shapes the split
# introduced. Before those cases existed, this flat fixture stood in for the whole grammar and
# stayed green against a record shape the consuming repository no longer has -- the false green
# this suite now removes.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo1="${WORKDIR}/join-repo"
init_repo "$repo1"
mkdir -p "$repo1/books" "$repo1/components/pt/lean" "$repo1/specs/042_fixture-task"

cat > "$repo1/books/book-convention.md" <<'EOF'
## Decision 13: Exposure policy
- **Validated by**: none yet
EOF
echo "book_requires Foo" > "$repo1/components/pt/lean/A.lean"
commit_files "$repo1" "task 42: create fixture task" books/book-convention.md components/pt/lean/A.lean

cat > "$repo1/specs/042_fixture-task/issues.jsonl" <<'EOF'
{"entry_id":"iss_1","timestamp":"2026-10-04T00:00:00Z","kind":"issue","class":"gate collision","severity":"costly","what_happened":"layer lint collided with an unrelated gate","tags":{"dimension":["guardrails_qa"],"polarity":"negative"},"task_dir":"specs/042_fixture-task"}
{"entry_id":"iss_2","timestamp":"2026-10-04T00:01:00Z","kind":"win","class":"tooling bug or gap","severity":"none","what_happened":"identity computation moved into the certifier, lifting a stale-manifest burden","tags":{"dimension":["maintainability"],"polarity":"positive","burden":"lifted","convention_decision":"Decision 13: Exposure policy"},"task_dir":"specs/042_fixture-task"}
{"entry_id":"iss_3","timestamp":"2026-10-04T00:02:00Z","kind":"issue","class":"cost-forced exclusion or substituted verification","severity":"minor","what_happened":"reading identity now requires a certifier run, creating a build-dependency burden","tags":{"dimension":["compiling_composing"],"polarity":"negative","burden":"created","convention_decision":"Decision 13: Exposure policy"},"task_dir":"specs/042_fixture-task"}
{"entry_id":"iss_4","timestamp":"2026-10-04T00:03:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"an entry with no tags object at all","task_dir":"specs/042_fixture-task"}
EOF
cat > "$repo1/specs/042_fixture-task/metrics.jsonl" <<'EOF'
{"entry_id":"met_1","recorded_at":"2026-10-04T00:00:00Z","task":42,"phase":"implement","agent":"books-implementation-agent","outcome":"completed","dispatch_seq":1,"session_id":"sess_x","wall_clock_seconds":100,"backfilled":false,"phases_completed":1,"phases_total":2}
{"entry_id":"met_2","recorded_at":"2026-10-04T00:05:00Z","task":42,"phase":"implement","agent":"books-implementation-agent","outcome":"completed","dispatch_seq":2,"session_id":"sess_x","wall_clock_seconds":200,"backfilled":false,"phases_completed":2,"phases_total":2}
EOF
commit_files "$repo1" "task 42: write generic logs" specs/042_fixture-task/issues.jsonl specs/042_fixture-task/metrics.jsonl

sed -i 's/none yet/partially, see xyz/' "$repo1/books/book-convention.md"
echo "book_requires Bar" >> "$repo1/components/pt/lean/A.lean"
commit_files "$repo1" "task 42 phase 1: validate decision 13 and extend requires" books/book-convention.md components/pt/lean/A.lean

record1="$repo1/specs/042_fixture-task/book.observation.json"
(cd "$repo1" && bash "$OBS" 42 books books specs/042_fixture-task sess_x completed) >/dev/null
rc1=$?
assert_exit "(1) THE JOIN: live-mode exit code" 0 "$rc1"
if [[ -f "$record1" ]]; then
  pass "(1) THE JOIN: record file exists"
  assert_json_true "(1) THE JOIN: generic.issues_present" "$record1" '.generic.issues_present'
  assert_json_true "(1) THE JOIN: generic.metrics_present" "$record1" '.generic.metrics_present'
  assert_json "(1) THE JOIN: generic.dispatch_count" "$record1" '.generic.dispatch_count' "2"
  assert_json "(1) THE JOIN: generic.wall_clock_seconds_total" "$record1" '.generic.wall_clock_seconds_total' "300"
  assert_json "(1) THE JOIN: dimension_signals.by_dimension_polarity.guardrails_qa.negative" "$record1" '.dimension_signals.by_dimension_polarity.guardrails_qa.negative' "1"
  assert_json "(1) THE JOIN: dimension_signals.by_dimension_polarity.maintainability.positive" "$record1" '.dimension_signals.by_dimension_polarity.maintainability.positive' "1"
  assert_json "(1) THE JOIN: dimension_signals.untagged_count" "$record1" '.dimension_signals.untagged_count' "1"
  assert_json "(1) THE JOIN: validated_by_promotions.entries[0].decision" "$record1" '.validated_by_promotions.entries[0].decision' "Decision 13: Exposure policy"
  assert_json "(1) THE JOIN: validated_by_promotions.source" "$record1" '.validated_by_promotions.source' "collected"
  assert_json_true "(1) THE JOIN: book_requires_churn.added > 0" "$record1" '(.book_requires_churn.added // 0) > 0'
  assert_json "(1) THE JOIN: book_requires_churn.source" "$record1" '.book_requires_churn.source' "collected"
  assert_json "(1) THE JOIN: backfilled is false on a live record" "$record1" '.backfilled' "false"
else
  fail "(1) THE JOIN: record file does not exist at $record1"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 2: THE ABSENT-PROBE PATH -- no RUN log and no executable snapshot probe yields "absent"
# for both probe-dependent groups, with exit 0. This is the measured-today default and must be
# asserted as CORRECT output, not a defect.
# ════════════════════════════════════════════════════════════════════════════════════════════
if [[ -f "$record1" ]]; then
  assert_json "(2) ABSENT-PROBE: vacuous_passes" "$record1" '.vacuous_passes' "absent"
  assert_json "(2) ABSENT-PROBE: snapshot_delta" "$record1" '.snapshot_delta' "absent"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 3: THE PAIRED-BURDEN REQUIREMENT -- burdens_created[]/burdens_lifted[] are ALWAYS both
# present (default []); a record with one and not the other is a test failure.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo3="${WORKDIR}/burden-repo"
init_repo "$repo3"
mkdir -p "$repo3/specs/043_no-burden-task" "$repo3/specs/044_half-burden-task"
(cd "$repo3" && touch specs/.gitkeep && git add specs/.gitkeep && git commit -q -m "task 43: init")

cat > "$repo3/specs/043_no-burden-task/issues.jsonl" <<'EOF'
{"entry_id":"iss_1","timestamp":"2026-10-04T00:00:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"an ordinary issue with no burden tag","tags":{"dimension":["readability"],"polarity":"negative"},"task_dir":"specs/043_no-burden-task"}
EOF
commit_files "$repo3" "task 43: write logs" specs/043_no-burden-task/issues.jsonl

record3a="$repo3/specs/043_no-burden-task/book.observation.json"
(cd "$repo3" && bash "$OBS" 43 books books specs/043_no-burden-task sess_a completed) >/dev/null
assert_exit "(3) PAIRED-BURDEN (no burden tags): exit code" 0 "$?"
assert_json "(3) PAIRED-BURDEN (no burden tags): burdens_created == []" "$record3a" '.burdens_created' "[]"
assert_json "(3) PAIRED-BURDEN (no burden tags): burdens_lifted == []" "$record3a" '.burdens_lifted' "[]"
if jq -e 'has("burdens_created") and has("burdens_lifted")' "$record3a" >/dev/null 2>&1; then
  pass "(3) PAIRED-BURDEN (no burden tags): both keys present as a pair"
else
  fail "(3) PAIRED-BURDEN (no burden tags): one of burdens_created/burdens_lifted is MISSING, not merely empty"
fi

cat > "$repo3/specs/044_half-burden-task/issues.jsonl" <<'EOF'
{"entry_id":"iss_1","timestamp":"2026-10-04T00:00:00Z","kind":"issue","class":"cost-forced exclusion or substituted verification","severity":"minor","what_happened":"a burden created with no paired lifted entry recorded for this task","tags":{"dimension":["compiling_composing"],"polarity":"negative","burden":"created","convention_decision":"Decision 9: Identity computation"}}
EOF
commit_files "$repo3" "task 44: write logs" specs/044_half-burden-task/issues.jsonl

record3b="$repo3/specs/044_half-burden-task/book.observation.json"
(cd "$repo3" && bash "$OBS" 44 books books specs/044_half-burden-task sess_b completed) >/dev/null
assert_exit "(3) PAIRED-BURDEN (half-burden): exit code" 0 "$?"
assert_json "(3) PAIRED-BURDEN (half-burden): burdens_created has 1 entry" "$record3b" '.burdens_created | length' "1"
assert_json "(3) PAIRED-BURDEN (half-burden): burdens_lifted is STILL [] (never missing)" "$record3b" '.burdens_lifted' "[]"
if jq -e 'has("burdens_created") and has("burdens_lifted")' "$record3b" >/dev/null 2>&1; then
  pass "(3) PAIRED-BURDEN (half-burden): both keys present even when only one side has entries"
else
  fail "(3) PAIRED-BURDEN (half-burden): one of burdens_created/burdens_lifted is MISSING"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 4: POLARITY/DIMENSION VALIDATION -- a valid tag is read through; an unrecognized
# dimension or polarity is reported in its own dedicated field and never silently coerced; an
# untagged entry is counted untagged and never defaulted.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo4="${WORKDIR}/validation-repo"
init_repo "$repo4"
mkdir -p "$repo4/specs/045_validation-task"
(cd "$repo4" && touch specs/.gitkeep && git add specs/.gitkeep && git commit -q -m "task 45: init")

cat > "$repo4/specs/045_validation-task/issues.jsonl" <<'EOF'
{"entry_id":"iss_1","timestamp":"2026-10-04T00:00:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"a valid tag","tags":{"dimension":["readability"],"polarity":"positive"}}
{"entry_id":"iss_2","timestamp":"2026-10-04T00:01:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"an unrecognized dimension key","tags":{"dimension":["speed_of_light"],"polarity":"positive"}}
{"entry_id":"iss_3","timestamp":"2026-10-04T00:02:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"an unrecognized polarity value","tags":{"dimension":["readability"],"polarity":"sideways"}}
{"entry_id":"iss_4","timestamp":"2026-10-04T00:03:00Z","kind":"issue","class":"environment","severity":"minor","what_happened":"no tags object at all, must count as untagged"}
EOF
commit_files "$repo4" "task 45: write logs" specs/045_validation-task/issues.jsonl

record4="$repo4/specs/045_validation-task/book.observation.json"
(cd "$repo4" && bash "$OBS" 45 books books specs/045_validation-task sess_c completed) >/dev/null
assert_exit "(4) POLARITY/DIMENSION VALIDATION: exit code" 0 "$?"
assert_json "(4) valid tag counted: dimension_signals.by_dimension_polarity.readability.positive" "$record4" '.dimension_signals.by_dimension_polarity.readability.positive' "1"
if jq -e '.unrecognized_tags | map(select(.field == "dimension" and .value == "speed_of_light")) | length == 1' "$record4" >/dev/null 2>&1; then
  pass "(4) unrecognized dimension reported in unrecognized_tags, never coerced"
else
  fail "(4) unrecognized dimension 'speed_of_light' not reported correctly in unrecognized_tags"
fi
if jq -e '.unrecognized_tags | map(select(.field == "polarity" and .value == "sideways")) | length == 1' "$record4" >/dev/null 2>&1; then
  pass "(4) unrecognized polarity reported in unrecognized_tags, never coerced"
else
  fail "(4) unrecognized polarity 'sideways' not reported correctly in unrecognized_tags"
fi
assert_json "(4) untagged entry counted, never defaulted into a dimension" "$record4" '.dimension_signals.untagged_count' "1"

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 5: BACKFILL MARKING -- a --backfill record carries backfilled:true, figure_provenance,
# and per-group source; a live record does NOT carry backfilled:true.
# ════════════════════════════════════════════════════════════════════════════════════════════
rm -f "$record1"
(cd "$repo1" && bash "$OBS" --backfill 42) >/dev/null
backfill_rc=$?
assert_exit "(5) BACKFILL MARKING: --backfill exit code" 0 "$backfill_rc"
assert_json "(5) BACKFILL MARKING: backfilled == true" "$record1" '.backfilled' "true"
if jq -e 'has("figure_provenance") and (.figure_provenance | length) > 0' "$record1" >/dev/null 2>&1; then
  pass "(5) BACKFILL MARKING: figure_provenance present and non-empty"
else
  fail "(5) BACKFILL MARKING: figure_provenance missing or empty"
fi
assert_json "(5) BACKFILL MARKING: book_requires_churn.source == backfilled" "$record1" '.book_requires_churn.source' "backfilled"
assert_json "(5) BACKFILL MARKING: validated_by_promotions.source == backfilled" "$record1" '.validated_by_promotions.source' "backfilled"

(cd "$repo1" && bash "$OBS" 42 books books specs/042_fixture-task sess_x completed) >/dev/null
assert_json "(5) BACKFILL MARKING: a live record does NOT carry backfilled:true" "$record1" '.backfilled' "false"
if jq -e 'has("figure_provenance")' "$record1" >/dev/null 2>&1; then
  fail "(5) BACKFILL MARKING: a live record unexpectedly carries figure_provenance"
else
  pass "(5) BACKFILL MARKING: a live record carries no figure_provenance key"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 6: NON-BLOCKING FAILURE -- a malformed issues.jsonl, an unreadable task directory, and a
# crashing probe each leave the script exiting 0 with the affected group omitted.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo6="${WORKDIR}/failure-repo"
init_repo "$repo6"
mkdir -p "$repo6/specs/046_malformed-task"
(cd "$repo6" && touch specs/.gitkeep && git add specs/.gitkeep && git commit -q -m "task 46: init")
printf 'not valid json at all\n{"kind": "issue", unterminated\n' > "$repo6/specs/046_malformed-task/issues.jsonl"

record6a="$repo6/specs/046_malformed-task/book.observation.json"
(cd "$repo6" && bash "$OBS" 46 books books specs/046_malformed-task sess_d blocked) >/dev/null
assert_exit "(6) NON-BLOCKING: malformed issues.jsonl exit code" 0 "$?"
if [[ -f "$record6a" ]]; then
  pass "(6) NON-BLOCKING: malformed issues.jsonl still produced a record"
  assert_json_true "(6) NON-BLOCKING: generic.issues_present still true (file existed)" "$record6a" '.generic.issues_present'
  if jq -e 'has("generic") and (.generic | has("issue_counts") | not)' "$record6a" >/dev/null 2>&1; then
    pass "(6) NON-BLOCKING: issue_counts correctly OMITTED (not zeroed) on parse failure"
  else
    fail "(6) NON-BLOCKING: issue_counts should be omitted when the source file fails to parse"
  fi
else
  fail "(6) NON-BLOCKING: no record written for malformed issues.jsonl case"
fi

(cd "$repo6" && bash "$OBS" 999 books books specs/999_does-not-exist sess_e completed) >/dev/null
assert_exit "(6) NON-BLOCKING: unresolvable task_dir exit code" 0 "$?"

mkdir -p "$repo6/books/tool"
cat > "$repo6/books/tool/book-snapshot.sh" <<'EOF'
#!/usr/bin/env bash
echo "garbage, not json" >&2
exit 1
EOF
chmod +x "$repo6/books/tool/book-snapshot.sh"
echo "book_requires Baz" > "$repo6/A.lean"
commit_files "$repo6" "task 46: add lean file" A.lean
echo "book_requires Qux" >> "$repo6/A.lean"
commit_files "$repo6" "task 46 phase 1: extend" A.lean

record6c="$repo6/specs/046_malformed-task/book.observation.json"
(cd "$repo6" && bash "$OBS" 46 books books specs/046_malformed-task sess_f completed) >/dev/null
assert_exit "(6) NON-BLOCKING: crashing probe exit code" 0 "$?"
assert_json "(6) NON-BLOCKING: crashing probe leaves snapshot_delta absent, never half-written" "$record6c" '.snapshot_delta' "absent"

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 7: VACUOUS PASS -- first-class, populated from a supplied source, never inferred by
# negation of a pass.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo7="${WORKDIR}/vacuous-repo"
init_repo "$repo7"
mkdir -p "$repo7/specs/047_vacuous-task" "$repo7/specs/048_clean-task" "$repo7/specs/books-evidence"
(cd "$repo7" && touch specs/.gitkeep && git add specs/.gitkeep && git commit -q -m "task 47: init")

cat > "$repo7/specs/books-evidence/runs.jsonl" <<'EOF'
{"schema":"book-evidence-run-v1","timestamp":"2026-01-01T00:00:00Z","convention_version":"0.1.0","host_fingerprint":"deadbeef0000","tier":"layer-lint","target":"components/pt","wall_seconds":12,"peak_rss_bytes":null,"exit_status":0,"terminating_signal":null,"outcome_class":"vacuous-pass","export_count":null,"module_count":null,"refusal_count":null,"warning_count":null,"caller_context":{"task":"47","phase":"implement"}}
{"schema":"book-evidence-run-v1","timestamp":"2026-01-01T00:02:00Z","convention_version":"0.1.0","host_fingerprint":"deadbeef0000","tier":"certify","target":"book-foo","wall_seconds":20,"peak_rss_bytes":111111,"exit_status":0,"terminating_signal":null,"outcome_class":"pass","export_count":5,"module_count":3,"refusal_count":0,"warning_count":1,"caller_context":{"task":"47","phase":"implement"}}
{"schema":"book-evidence-run-v1","timestamp":"2026-01-01T00:05:00Z","convention_version":"0.1.0","host_fingerprint":"deadbeef0000","tier":"lake-build","target":"components/pt","wall_seconds":30,"peak_rss_bytes":222222,"exit_status":0,"terminating_signal":null,"outcome_class":"pass","export_count":null,"module_count":null,"refusal_count":null,"warning_count":null,"caller_context":{"task":"48","phase":"implement"}}
EOF
commit_files "$repo7" "task 47: write run log" specs/books-evidence/runs.jsonl

record7a="$repo7/specs/047_vacuous-task/book.observation.json"
(cd "$repo7" && bash "$OBS" 47 books books specs/047_vacuous-task sess_g completed) >/dev/null
assert_exit "(7) VACUOUS PASS: exit code" 0 "$?"
if jq -e '.vacuous_passes | type == "array" and length == 1 and .[0].tier == "layer-lint"' "$record7a" >/dev/null 2>&1; then
  pass "(7) VACUOUS PASS: populated from the supplied RUN log entry, never inferred"
else
  fail "(7) VACUOUS PASS: expected a populated vacuous_passes array sourced from runs.jsonl"
fi
if jq -e '.verification_tiers.tiers | type == "object" and (keys | length) >= 1 and has("layer-lint")' "$record7a" >/dev/null 2>&1; then
  pass "(7) VACUOUS PASS: verification_tiers populated, keyed by the hyphenated tier name"
else
  fail "(7) VACUOUS PASS: expected verification_tiers.tiers to carry the hyphenated layer-lint key"
fi
if jq -e '.certifier_outcomes.outcome_classes | type == "object" and (keys | length) >= 1' "$record7a" >/dev/null 2>&1; then
  pass "(7) VACUOUS PASS: certifier_outcomes populated from the certify-tier entry"
else
  fail "(7) VACUOUS PASS: expected certifier_outcomes.outcome_classes to be non-empty"
fi

record7b="$repo7/specs/048_clean-task/book.observation.json"
(cd "$repo7" && bash "$OBS" 48 books books specs/048_clean-task sess_h completed) >/dev/null
assert_exit "(7) VACUOUS PASS (clean task): exit code" 0 "$?"
assert_json "(7) VACUOUS PASS (clean task): vacuous_passes == [] (known-clean, not absent, not inferred)" "$record7b" '.vacuous_passes' "[]"

# task-ref-ok:begin inline, category 3: command-usage examples -- this block's fixtures build
# throwaway git repos whose commit subjects follow this codebase's own `task {N}:` / `task {N}
# phase {P}:` commit-subject convention literally, mirroring the identical fixture convention
# already established above and in scripts/tests/test-dispatch-metrics.sh.
# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 8: DIRECTORY SHAPE -- books/book-convention/NN-slug.md, an H1 `# Decision N: ...` heading,
# and a reduced one-line marker carrying the evidence-pointer arrow, promotes and resolves to the
# same durable heading text the flat shape would use.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo8="${WORKDIR}/dir-shape-repo"
init_repo "$repo8"
mkdir -p "$repo8/books/book-convention" "$repo8/specs/049_dir-shape-task"

cat > "$repo8/books/book-convention/13-exposure-policy.md" <<'EOF'
# Decision 13: Exposure policy

- **Validated by**: none yet
EOF
commit_files "$repo8" "task 49: add directory-shaped decision 13" books/book-convention/13-exposure-policy.md

python3 - "$repo8/books/book-convention/13-exposure-policy.md" <<'PYEOF'
import sys
path = sys.argv[1]
content = (
    "# Decision 13: Exposure policy\n\n"
    "- **Validated by**: partially, the exposure suite → full exercise history and "
    "citations: [books/book-convention-evidence/13-exposure-policy.md]"
    "(../book-convention-evidence/13-exposure-policy.md)\n"
)
open(path, "w").write(content)
PYEOF
commit_files "$repo8" "task 49 phase 1: promote directory decision 13" books/book-convention/13-exposure-policy.md

record8="$repo8/specs/049_dir-shape-task/book.observation.json"
(cd "$repo8" && bash "$OBS" 49 books books specs/049_dir-shape-task sess_dir completed) >/dev/null
assert_exit "(8) DIRECTORY SHAPE: exit code" 0 "$?"
assert_json "(8) DIRECTORY SHAPE: exactly one promotion" "$record8" '.validated_by_promotions.entries | length' "1"
assert_json "(8) DIRECTORY SHAPE: durable heading text" "$record8" '.validated_by_promotions.entries[0].decision' "Decision 13: Exposure policy"
assert_json "(8) DIRECTORY SHAPE: source_path names the directory file" "$record8" '.validated_by_promotions.entries[0].source_path' "books/book-convention/13-exposure-policy.md"

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 9: TRANSITIONAL SHAPE -- the SAME decision present in both the flat index and a directory
# file at once, with differing values in each. Per-path keying (Phase 1) means each shape is
# diffed within its own file only -- no cross-shape promotion -- and source_path distinguishes
# the two resulting entries.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo9="${WORKDIR}/transitional-repo"
init_repo "$repo9"
mkdir -p "$repo9/books/book-convention" "$repo9/specs/050_transitional-task"

cat > "$repo9/books/book-convention.md" <<'EOF'
## Decision 7: Book TOML v2 schema
- **Validated by**: none yet
EOF
cat > "$repo9/books/book-convention/07-book-toml-v2-schema.md" <<'EOF'
# Decision 7: Book TOML v2 schema

- **Validated by**: none yet
EOF
commit_files "$repo9" "task 50: transitional decision 7 in both shapes" books/book-convention.md books/book-convention/07-book-toml-v2-schema.md

sed -i 's/none yet/partially, the flat index value/' "$repo9/books/book-convention.md"
sed -i 's/none yet/binding, the directory value/' "$repo9/books/book-convention/07-book-toml-v2-schema.md"
commit_files "$repo9" "task 50 phase 1: promote decision 7 in both shapes" books/book-convention.md books/book-convention/07-book-toml-v2-schema.md

record9="$repo9/specs/050_transitional-task/book.observation.json"
(cd "$repo9" && bash "$OBS" 50 books books specs/050_transitional-task sess_trans completed) >/dev/null
assert_exit "(9) TRANSITIONAL: exit code" 0 "$?"
assert_json "(9) TRANSITIONAL: two promotions, one per shape (no cross-shape merge)" "$record9" '.validated_by_promotions.entries | length' "2"
if jq -e '[.validated_by_promotions.entries[].source_path] | sort == ["books/book-convention.md", "books/book-convention/07-book-toml-v2-schema.md"]' "$record9" >/dev/null 2>&1; then
  pass "(9) TRANSITIONAL: source_path distinguishes the flat entry from the directory entry"
else
  fail "(9) TRANSITIONAL: expected one entry per source_path, each shape diffed within its own file"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 10: FAULT-FRAME HEADING GRAMMAR -- components/fault_tolerance/fault-frame-design.md's `### Decision N — ...`
# headings (real U+2014 em dash), with multiple decisions in one file. Each marker must attribute
# to its OWN nearest preceding heading, not all collapse onto the first -- the pre-existing
# mis-read Phase 1 fixes, proven here rather than merely asserted.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo10="${WORKDIR}/fault-frame-repo"
init_repo "$repo10"
mkdir -p "$repo10/components/fault_tolerance" "$repo10/specs/051_fault-frame-task"

python3 - "$repo10/components/fault_tolerance/fault-frame-design.md" <<'PYEOF'
import sys
path = sys.argv[1]
content = (
    "# Fault frame design\n\n"
    "### Decision 1 — Signature: two-sorted `Kernel` / `FaultFormula`\n\n"
    "- **Validated by**: none yet\n\n"
    "### Decision 2 — Frame class: a lightweight Tier-A `FaultFrame`\n\n"
    "- **Validated by**: none yet\n"
)
open(path, "w").write(content)
PYEOF
commit_files "$repo10" "task 51: add fault-frame fixture with two decisions" components/fault_tolerance/fault-frame-design.md

python3 - "$repo10/components/fault_tolerance/fault-frame-design.md" <<'PYEOF'
import sys
path = sys.argv[1]
content = (
    "# Fault frame design\n\n"
    "### Decision 1 — Signature: two-sorted `Kernel` / `FaultFormula`\n\n"
    "- **Validated by**: binding, the kernel soundness suite\n\n"
    "### Decision 2 — Frame class: a lightweight Tier-A `FaultFrame`\n\n"
    "- **Validated by**: none yet\n"
)
open(path, "w").write(content)
PYEOF
commit_files "$repo10" "task 51 phase 1: promote fault-frame decision 1 only" components/fault_tolerance/fault-frame-design.md

record10="$repo10/specs/051_fault-frame-task/book.observation.json"
(cd "$repo10" && bash "$OBS" 51 books books specs/051_fault-frame-task sess_ff completed) >/dev/null
assert_exit "(10) FAULT-FRAME: exit code" 0 "$?"
assert_json "(10) FAULT-FRAME: exactly one promotion (decision 2 untouched)" "$record10" '.validated_by_promotions.entries | length' "1"
assert_json "(10) FAULT-FRAME: promotion attributed to its own heading, not the first" "$record10" '.validated_by_promotions.entries[0].decision' "Decision 1 — Signature: two-sorted \`Kernel\` / \`FaultFormula\`"

# ════════════════════════════════════════════════════════════════════════════════════════════
# Case 11: POINTER-ONLY EDIT -- only the "→ full exercise history and citations: ..." tail of a
# reduced marker changes (e.g. the evidence file was renamed). This MUST NOT count as a
# promotion: the value-prefix comparison (Phase 1) is new logic absent from both the pre-Phase-1
# observer and lint-validated-by.sh's own strip_marker_prefix(), which compares the whole value.
# ════════════════════════════════════════════════════════════════════════════════════════════
repo11="${WORKDIR}/pointer-only-repo"
init_repo "$repo11"
mkdir -p "$repo11/books/book-convention" "$repo11/specs/052_pointer-only-task"

python3 - "$repo11/books/book-convention/09-trust-unit-is-the-export.md" <<'PYEOF'
import sys
path = sys.argv[1]
content = (
    "# Decision 9: Trust unit is the export\n\n"
    "- **Validated by**: binding, the export suite → full exercise history and "
    "citations: [books/book-convention-evidence/09-trust-unit-is-the-export.md]"
    "(../book-convention-evidence/09-trust-unit-is-the-export.md)\n"
)
open(path, "w").write(content)
PYEOF
commit_files "$repo11" "task 52: add already-promoted decision 9" books/book-convention/09-trust-unit-is-the-export.md

python3 - "$repo11/books/book-convention/09-trust-unit-is-the-export.md" <<'PYEOF'
import sys
path = sys.argv[1]
content = (
    "# Decision 9: Trust unit is the export\n\n"
    "- **Validated by**: binding, the export suite → full exercise history and "
    "citations: [books/book-convention-evidence/09-trust-unit-renamed.md]"
    "(../book-convention-evidence/09-trust-unit-renamed.md)\n"
)
open(path, "w").write(content)
PYEOF
commit_files "$repo11" "task 52 phase 1: rename only the evidence pointer target" books/book-convention/09-trust-unit-is-the-export.md

record11="$repo11/specs/052_pointer-only-task/book.observation.json"
(cd "$repo11" && bash "$OBS" 52 books books specs/052_pointer-only-task sess_ptr completed) >/dev/null
assert_exit "(11) POINTER-ONLY EDIT: exit code" 0 "$?"
if jq -e '(.validated_by_promotions // {"entries": []}) | .entries | length == 0' "$record11" >/dev/null 2>&1; then
  pass "(11) POINTER-ONLY EDIT: a pointer-only edit produced zero promotion entries"
else
  fail "(11) POINTER-ONLY EDIT: expected zero promotions; an evidence-pointer-only edit must never count as one"
fi
# task-ref-ok:end

echo ""
echo "=== Results: $PASSED passed, $FAILED failed ==="
if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
# task-ref-ok:end
