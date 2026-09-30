# Research Report: Task #269

**Task**: 269 - validate-state.sh --fix crashes on literal-null file_scope
**Started**: 2026-09-30T00:00:00Z
**Completed**: 2026-09-30T00:00:00Z
**Effort**: small (single-filter fix + comment update + regression fixture)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/validate-state.sh,
  agent-system/extensions/core/scripts/tests/test-validate-state.sh,
  .claude/scripts/state-write.sh), mechanical jq reproduction, live BimodalLogic
  specs/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Confirmed by direct reproduction: the `--fix` mutation filter at
  `agent-system/extensions/core/scripts/validate-state.sh:322` crashes with
  `jq: error (at <stdin>:1): Cannot iterate over null (null)` whenever any
  `active_projects[]` entry has a literal `file_scope: null`, because it gates on
  `has("file_scope")` (a key-presence test, true for null) instead of a type test.
- The adjacent **report** filter (lines 299-306) already guards correctly with
  `($t.file_scope // []) as $fs`, so the report step itself never crashes — only the
  mutation filter handed to `state-write.sh` is defective. `state-write.sh` then
  correctly refuses the write (its own documented exit code 3, "jq transform failed...
  target state file left untouched"), so no corruption occurs, but no repair happens
  either, silently, on every run against such a file.
- The correct fix is a one-line filter-predicate swap from `has("file_scope")` to
  `(.file_scope|type) == "array"`, verified by hand to preserve all three documented
  invariants (D3 order-preserving dedup, no-manufacture of `file_scope: []` on a
  never-had-one entry, idempotence) and to leave null-valued and absent-key entries
  byte-identical.
- The source-store/deploy-boundary is single-sited: only
  `agent-system/extensions/core/scripts/validate-state.sh` needs editing (confirmed
  byte-identical to the deployed `.claude/scripts/validate-state.sh` per the dispatch;
  not re-verified here since the dispatch already ran `diff -q`).
- The comment block directly above the filter (lines 299-302) currently documents and
  endorses the `has("file_scope")` form and must be rewritten alongside the code change.
- `scripts/tests/test-validate-state.sh` already has two live `--fix` fixtures that
  write through a real deployed `state-write.sh`
  (`FIX_FIXTURE_DIR` at line ~600, `NOMFG_FIXTURE_DIR` at line ~788); neither currently
  includes a null-valued `file_scope` entry, so neither currently reproduces this crash.
  One of them should be extended (see Recommendations) rather than adding a third
  fixture or a new file.

## Context & Scope

This is a confirmed, mechanically-reproduced defect in
`agent-system/extensions/core/scripts/validate-state.sh`'s `--fix` code path (the
source-store copy is the sole edit target per
`.claude/rules/source-store-deploy-boundary.md`; the deployed
`.claude/scripts/validate-state.sh` copy is a disposable, gitignored deploy artifact
regenerated from it). The scope is narrowly: (1) the one mutation filter, (2) its
documentation comment, (3) a regression test proving the fix actually repairs (not
merely "doesn't crash"). No other file in `validate-state.sh` or
`orchestrate-predispatch-review.sh` needs to change — the dispatch's "Check 8/9
lineage" note is background provenance, not additional scope.

## Findings

### Codebase Patterns

**The defective filter** (`agent-system/extensions/core/scripts/validate-state.sh:322`,
inside the `if [[ "$DO_FIX" == true ]]` block starting around line 255):

```
'.active_projects = [.active_projects[] | if has("file_scope") then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
```

Mechanically reproduced:

```
$ echo '{"active_projects":[{"project_number":1,"file_scope":null}]}' | jq -c \
  '.active_projects = [.active_projects[] | if has("file_scope") then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
jq: error (at <stdin>:1): Cannot iterate over null (null)
$ echo $?
5
```

`has("file_scope")` is a **key-presence** test and is `true` for a key whose value is
literal `null` — jq's `has` only asks "does this key exist in the object," not
"is the value of a usable type." The `reduce .[] as $x` inside the `if` branch then
tries to iterate the null value directly and jq aborts the whole filter (exit 5),
which is the underlying reason `state-write.sh` sees the transform fail.

**The correctly-guarded sibling** (report filter, lines 299-306):

```
_fix_report=$(jq -c '
    [ .active_projects[] | . as $t |
      select(has("file_scope")) |
      ($t.file_scope // []) as $fs |
      ...
```

This filter also starts from `has("file_scope")` (so it still *selects* null-valued
entries into consideration — that's fine, it's a reporting pass, not a mutation), but
immediately neutralizes the null with the `// []` default-coalescing idiom before doing
anything iteration-shaped with `$fs`. This is why the *report* step of `--fix` never
crashes even on a null-bearing fixture — only the subsequent mutation step does.

**`state-write.sh`'s refusal is correct, not the bug** — confirmed from
`.claude/scripts/state-write.sh`'s own header (documented exit codes): exit 3 means
"jq transform failed. The target state file is left untouched." `set -euo pipefail` is
active in that script, so a failing `jq` call propagates as exit 3 and the target file
is never touched. This is the safety mechanism working exactly as designed; the defect
is strictly upstream, in the filter text handed to `state-write.sh`, not in
`state-write.sh` itself. No change to `state-write.sh` is in scope.

**Verified fix** — swapping the predicate from a presence test to a type test:

```
'.active_projects = [.active_projects[] | if (.file_scope|type) == "array" then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
```

Hand-verified against a fixture covering all three relevant shapes in one input
(null-valued, duplicated array, and keyless):

```
$ echo '{"active_projects":[{"project_number":1,"file_scope":null},{"project_number":2,"file_scope":["a","a","b"]},{"project_number":3}]}' | jq -c \
  '.active_projects = [.active_projects[] | if (.file_scope|type) == "array" then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'
{"active_projects":[{"project_number":1,"file_scope":null},{"project_number":2,"file_scope":["a","b"]},{"project_number":3}]}
```
Exit 0. Project 1 (null) is left byte-identical (still `null`, key still present).
Project 2's duplicate is removed order-preservingly (`["a","a","b"]` →
`["a","b"]`, not `["a","b"]` via a sort — jq's `unique` was not used). Project 3
(no `file_scope` key at all) is left with no key manufactured. This single filter swap
satisfies all three documented invariants (D3 order-preserving dedup, no-manufacture,
idempotence) with no other code path changes needed.

**Comment block requiring an update** (lines 299-302, directly above the filter):

```
  # Order-preserving dedup filter (D3): `unique` sorts and must not be used. Only entries that
  # ALREADY have a file_scope field are touched (`if has("file_scope") then ... else . end`) --
  # never introduces a file_scope: [] field on an entry that never had one, and an entry whose
  # file_scope already has no duplicates is left byte-identical (the filter is idempotent there).
```

This comment currently *explains and endorses* the defective `has("file_scope")` form
as correct design. If only the filter text is changed and this comment is left as-is,
the comment becomes actively wrong documentation of the new code (re-describing the old,
buggy gate). It must be rewritten to describe the `(.file_scope|type) == "array"` gate
and why it is needed (a null-valued `file_scope` has the key present but is not an
array; the old `has()` gate wrongly treated "key present" as "safe to iterate").

**Existing regression-test infrastructure** (`agent-system/extensions/core/scripts/tests/test-validate-state.sh`):
Two live `--fix` fixtures already write through a real deployed `state-write.sh`
(both gracefully SKIP, not FAIL, when no deployed copy exists yet):

1. `FIX_FIXTURE_DIR` (~line 600): two `active_projects` entries, both *with* a
   `file_scope` array — one with exact duplicates (Class A, dedup expected) and one
   with a normalization-equivalent-but-not-exact pair (Class B, must stay untouched).
   Asserts exit 0, the deduped array, the untouched Class B array, and a diff over
   every non-`file_scope` field to prove nothing else was disturbed. **No null-valued
   or keyless entry present — does not currently exercise the crash.**
2. `NOMFG_FIXTURE_DIR` (~line 788, explicitly framed as the "non-manufacture (D4)"
   fixture): project 1 has an exact-duplicate array (repair expected); project 2 has
   **no `file_scope` key at all** and the assertion explicitly checks
   `has("file_scope") == false` survives `--fix` untouched. **This fixture already
   covers the keyless-entry half of invariant (c) in the dispatch, but has no
   null-valued entry, so it also does not currently exercise the crash.**

Neither fixture currently drives a null-valued `file_scope` through `--fix`, so neither
currently fails against the present defective filter (they would all pass today only
because none of them contains the null-triggering shape) — this is exactly why the bug
has shipped undetected: the crash-triggering shape (`file_scope: null`) was never in
the fixtures, only the crash-adjacent shape (`file_scope` key absent) was.

Both fixtures already share the same structural pattern (`REPO_ROOT/specs/_tmp_*_$$`,
guarded on `-f "$REPO_ROOT/.claude/scripts/state-write.sh"`, `rm -rf` cleanup,
`cp ... .orig` + field-diff-based "nothing else changed" assertion in the first one).

### External Resources

Not applicable — this is a self-contained jq filter defect with no external API or
library surface; jq's `has()` vs `type`/`//` semantics are standard and already
well-documented within this file's own surrounding comments (e.g. the Check 10 block's
`(has("file_scope") | not)` / `== null` / `== []` three-way discrimination at lines
~626-628 is the *correct* pattern this fix should mirror for the mutation filter).

## Decisions

- **Edit target is source-store only**: `agent-system/extensions/core/scripts/validate-state.sh`.
  Never hand-edit `.claude/scripts/validate-state.sh` (gitignored deploy artifact); a
  redeploy (`bash .claude/scripts/deploy-headless.sh`) propagates the fix, consistent
  with the dispatch's confirmed `diff -q` byte-identity and
  `.claude/rules/source-store-deploy-boundary.md`.
- **Fix is a single-predicate swap**, not a restructure: replace
  `if has("file_scope") then ... else . end` with
  `if (.file_scope|type) == "array" then ... else . end` in the mutation filter at
  (source-store) line 322. No changes to the report filter (lines ~299-306, already
  correct), to `state-write.sh`, or to any other check block.
- **The comment block at lines 299-302 must be updated in the same change** — it
  currently documents the `has("file_scope")` form as the correct design and must be
  rewritten to explain the type-test form and the null-vs-absent distinction it now
  correctly handles, per the dispatch's explicit requirement.
- **Regression test belongs in the existing `test-validate-state.sh` file**, not a new
  file, per the dispatch's explicit instruction and consistent with both existing
  `--fix` fixtures already living there.
- **`state-write.sh` is out of scope.** Its exit-3 refusal-on-jq-failure behavior is
  correct and documented; nothing about it should change.

## Recommendations

1. **Filter change** (`agent-system/extensions/core/scripts/validate-state.sh`, mutation
   filter, source-store line 322): swap the `if has("file_scope") then ... else . end`
   gate to `if (.file_scope|type) == "array" then ... else . end`. This is the exact
   verified fix from Findings above; no reduce-body change is needed.
2. **Comment update** (same file, lines 299-302): rewrite to describe the type-test
   gate, explicitly naming the null-vs-absent distinction it resolves (a null-valued
   `file_scope` has the key present but must not be treated as an array; the previous
   `has()` gate conflated "key present" with "safe to iterate"). Keep the existing D3
   (order-preserving, `unique` must not be used) and no-manufacture/idempotence
   documentation — only the has()-specific sentence needs replacing.
3. **Regression test** (`agent-system/extensions/core/scripts/tests/test-validate-state.sh`):
   add a null-valued `file_scope` entry to **one** of the two existing live `--fix`
   fixtures (do not add a third fixture or a new file) such that a single fixture run
   proves all three dispatch-required assertions in one pass:
   - exit status 0 (the crash is gone)
   - a genuine exact-duplicate entry elsewhere in the *same* fixture is actually
     deduped (proves the write landed, not merely that nothing crashed)
   - the null-valued entry is still literal `null` after `--fix`, and (if the fixture
     also carries a keyless entry) the keyless entry is still keyless.

   Two placement options, both structurally sound — planner/implementer should pick
   one rather than doing both, to avoid duplicated fixture machinery:
   - **Option A (extend `NOMFG_FIXTURE_DIR`, ~line 788)**: this fixture already has
     the "non-manufacture" framing and already contains project 1 (exact-duplicate,
     proves the write landed) and project 2 (keyless, proves no manufacture). Add a
     project 3 with `"file_scope": null` and assert
     `jq '.active_projects[] | select(.project_number==3) | .file_scope'` still prints
     `null`. This is the smallest diff: one new entry, one new assertion line, reusing
     every existing harness line (mkdir/cat/run/diff/rm) unchanged. This is the
     recommended option — it requires the fewest new assertions and keeps the
     "must not manufacture a field/value" theme in one place conceptually (null-safety
     is a no-manufacture invariant, same family as the keyless case already there).
   - **Option B (extend `FIX_FIXTURE_DIR`, ~line 600)**: add both a null-valued entry
     and a keyless entry as new projects 3 and 4, alongside the existing project 1
     (Class A dup) and project 2 (Class B untouched-dup). Slightly larger diff since
     this fixture doesn't yet have a keyless-entry precedent to extend, but it is the
     fixture the dispatch names by line number ("FIX_FIXTURE_DIR, circa line 600").
4. **Verification before considering the task done**: run
   `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` (and/or the
   deployed-tree copy if that's the suite's actual invocation convention in this repo)
   after a redeploy, confirming the new assertion passes and no existing assertion
   regresses. Also manually re-run the exact repro command from Findings against the
   patched source-store file to confirm exit 0 with `file_scope` still `null`.
5. **No action needed on the BimodalLogic consumer repo's `specs/state.json`.** That
   repo's null-valued entries are a downstream *symptom*, not part of this task's
   scope; the dispatch says that `/orchestrate` dispatch already worked around it
   locally with a project-scoped null-safe filter and deliberately did not hand-patch
   the deployed copy. (Note: a live count taken during this research shows 33
   null-valued `file_scope` entries in that repo's current `specs/state.json`, not the
   "five" cited in the dispatch's provenance note — state.json is a live, fast-moving
   file and the discrepancy is most likely simply drift since the dispatch was
   written. This has no bearing on the fix itself and is mentioned only so the
   implementer isn't confused if they check.)

## Risks & Mitigations

- **Risk**: editing the deployed `.claude/scripts/validate-state.sh` directly instead
  of the source store, causing the fix to be silently wiped on the next deploy.
  **Mitigation**: edit only `agent-system/extensions/core/scripts/validate-state.sh`;
  redeploy afterward so the deployed copy picks up the change.
- **Risk**: fixing only the crash (e.g. wrapping in `// []` at the mutation site
  instead of gating on type) without preserving the no-manufacture invariant — a `//
  []` default at the assignment site would *write* `file_scope: []` onto a
  previously-null entry, which the dispatch explicitly forbids (invariant 2). **Mitigation**:
  use the type-test gate (verified above) which leaves null and absent entries
  completely untouched, not defaulted.
- **Risk**: leaving the stale comment block in place, re-documenting the old
  (incorrect) design after the code changes. **Mitigation**: explicitly called out as
  in-scope by the dispatch and restated in Recommendations item 2.
- **Risk**: adding a new, isolated test file/fixture instead of extending the existing
  ones, fragmenting `--fix` test coverage and duplicating the
  `mkdir/cat/run/diff/rm` harness. **Mitigation**: Recommendation 3 above, extend an
  existing fixture.

## Context Extension Recommendations

None. This is a narrowly-scoped, single-filter bugfix with no new pattern or
convention that would benefit a dedicated context file; the existing
`source-store-deploy-boundary.md` rule and the file's own extensive inline comment
documentation already cover everything an implementer needs.

## Appendix

- Commands run: direct `jq` reproduction of both the defective and fixed filters
  (see Findings); `grep -n` over `validate-state.sh` and `test-validate-state.sh` for
  all `file_scope`/`has("file_scope")`/fixture-block occurrences; `jq` count of
  null-valued `file_scope` entries in `~/Projects/BimodalLogic/specs/state.json`.
- Files read: `agent-system/extensions/core/scripts/validate-state.sh` (lines
  ~255-340, ~440-690), `agent-system/extensions/core/scripts/tests/test-validate-state.sh`
  (lines ~500-645, ~775-825), `.claude/scripts/state-write.sh` (header/exit-code
  documentation), `.claude-extensions.json` (source_dir resolution).
- No web search was needed; this is a self-contained jq semantics defect internal to
  this repository's own tooling.
