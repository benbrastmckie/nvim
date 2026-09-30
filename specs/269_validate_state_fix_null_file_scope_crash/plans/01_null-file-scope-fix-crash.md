# Implementation Plan: validate-state.sh --fix crashes on literal-null file_scope

- **Task**: 269 - validate-state.sh --fix crashes on literal-null file_scope
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/269_validate_state_fix_null_file_scope_crash/reports/01_null-file-scope-fix-crash.md
- **Artifacts**: plans/01_null-file-scope-fix-crash.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`validate-state.sh --fix`'s mutation filter gates duplicate-removal on `has("file_scope")`, a
key-presence test that is `true` for a literal-`null` value; the `reduce .[]` body then iterates
null and jq aborts, so `state-write.sh` correctly refuses the write and `--fix` repairs nothing
while still reporting its findings. The fix is a single predicate swap to the type test
`(.file_scope|type) == "array"`, a rewrite of the comment block that currently endorses the
defective form, and a regression fixture that proves repair actually lands on a null-bearing
state file. Done means: the extended `--fix` fixture is demonstrably red before the filter change
and green after, the full `test-validate-state.sh` suite passes, and null-valued and absent-key
entries survive `--fix` byte-identical.

### Research Integration

The research report confirms and sharpens the dispatch on four points this plan builds on:

- The **report** filter (`validate-state.sh` circa lines 303-310) is already null-safe via
  `($t.file_scope // []) as $fs`; only the **mutation** filter handed to `state-write.sh` (circa
  line 322) is defective. No change to the report filter, to `state-write.sh` (whose exit-3
  refusal is correct and documented), or to any check block.
- The verified fix was hand-run against a three-shape fixture (null / duplicated array / keyless)
  in one input and satisfies all three invariants with no reduce-body change.
- `FIX_FIXTURE_DIR` (circa line 600) has no keyless entry; `NOMFG_FIXTURE_DIR` (circa line 788)
  has a keyless entry but no null one. **Neither currently contains the crash-triggering shape** —
  which is precisely why the defect shipped undetected.
- The `// []` "fix at the assignment site" alternative is wrong: it would *write*
  `file_scope: []` onto a previously-null entry, violating invariant 2.

Two facts established by this plan's own reading of the code, beyond the report:

- **`--fix` only reaches the mutation filter when at least one genuine exact duplicate exists.**
  The report filter's `select(($fs|length) != ($dedup|length))` drops null entries (both lengths
  are 0), so a state file with nulls but no duplicates prints "nothing to repair" and never
  crashes. The regression fixture must therefore carry a null entry **and** a duplicated entry.
- **The crash is exit-code-invisible.** The `--fix` failure branch uses a raw
  `echo -e "${RED}[FAIL]${NC} ..."`, not `log_fail`, so it never increments `FAILED`; Checks 8-11
  are WARN-only in base mode, and base mode gates the exit code on `FAILED` alone. A null-bearing
  `--fix` run therefore exits **0** today while repairing nothing. This changes what the
  regression fixture must assert (see Phase 1) and is recorded as an out-of-scope observation
  under Non-Goals.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Swap the mutation filter's predicate from `has("file_scope")` to `(.file_scope|type) == "array"`
  in `agent-system/extensions/core/scripts/validate-state.sh` (source store only).
- Rewrite the comment block directly above that filter so it documents the type-test gate and the
  null-vs-absent distinction, instead of re-documenting the defect.
- Extend the existing `FIX_FIXTURE_DIR` block in
  `agent-system/extensions/core/scripts/tests/test-validate-state.sh` so one fixture run proves:
  the crash is gone, a genuine duplicate elsewhere in the same fixture was actually deduplicated
  (the write landed), the null-valued entry is still key-present-and-null, and the absent-key
  entry is still absent.
- Demonstrate the extended fixture is RED against the unfixed filter before applying the fix.
- Preserve all three documented invariants: D3 order-preserving dedup (never `unique`), no
  manufacture of `file_scope: []`, and idempotence.

**Non-Goals**:
- No edit to `.claude/scripts/validate-state.sh` or any other path under `.claude/**` (gitignored
  deploy artifact; see `.claude/rules/source-store-deploy-boundary.md`).
- No change to `state-write.sh`, to the report filter, or to any of Checks 8-11.
- No new test file and no third `--fix` fixture; `NOMFG_FIXTURE_DIR` is left untouched.
- **No redeploy in this task.** `deploy-headless.sh` regenerates the whole `.claude/` tree and
  would pick up three concurrent sibling tasks' in-flight source-store edits this same cycle. The
  deployed copy staying briefly stale is the normal lifecycle for a source-store edit; the next
  ordinary deploy propagates it. The regression suite does not need it (see Phase 1's validator
  resolution note).
- No change to any consumer repository's `specs/state.json`. The null-valued entries there are a
  downstream symptom, and the count cited in the dispatch (five) versus the research (33) is live-
  file drift with no bearing on the fix — do not reconcile the figures.
- **Not fixed here: the exit-code invisibility of a failed `--fix` write** (raw `echo` instead of
  `log_fail`, documented above). It is a real, separate defect in the same block and is recorded
  so it is not lost, but routing it through `log_fail` would change `--fix`'s exit contract for
  every existing caller and belongs in its own task.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Asserting "still null" with `jq '.file_scope'` cannot distinguish key-present-null from key-absent — both print `null`, so a filter that deleted the key would pass | H | H | Assert the pair `has("file_scope")` == `true` AND `.file_scope == null` together. This is the legitimate assertion-about-state use of `has()` the dispatch explicitly carves out (test-validate-state.sh circa line 807), not the defect this task removes |
| Fixture passes vacuously — rc is 0 even when the write fails (see Overview), so an rc-only assertion proves nothing | H | H | Make the dedup assertion on the duplicated entry the load-bearing proof, and additionally assert `$out` does NOT contain `--fix: state-write.sh failed` |
| `del(.active_projects[].file_scope)` in the existing "other fields unchanged" diff erases the null key on both sides, so that diff is blind to the null entry's fate | M | H | Keep the existing diff as-is for the non-`file_scope` fields it is designed for, and cover the null and keyless entries with the explicit per-project assertions above |
| Fixing the crash with `// []` at the assignment site instead of a type gate, manufacturing `file_scope: []` on a null entry (invariant 2 violation) | H | L | Use the type-test gate verified in research; Phase 3 asserts the null entry is still literally `null`, which a `// []` fix would fail |
| Substituting `unique` for the reduce while touching the filter (invariant 1 violation) | H | L | Change only the `if` predicate; leave the reduce body byte-identical. Phase 3 diffs the filter line to confirm only the predicate moved |
| Concurrent siblings 268/278/279 are dispatched this same cycle on this same tree, and 279's declared `file_scope` includes **both** files this task edits | H | M | Re-read each file immediately before editing; stage only this task's own hunks with an explicit file list (never a directory or glob pathspec); on encountering a foreign commit or foreign uncommitted modification to either file, STOP and report after checking `git log` |
| Editing the deployed copy by reflex, so the fix is wiped on the next deploy | H | L | Every phase's file list names `agent-system/extensions/core/...` explicitly; no phase touches `.claude/**` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is fully sequential by design: the
regression fixture must be proven RED before the fix lands, or it proves nothing about the fix.

### Phase 1: Extend the --fix fixture and prove it RED [NOT STARTED]

**Goal**: `FIX_FIXTURE_DIR` carries the crash-triggering shape and fails against the unfixed
filter, establishing that the new assertions have teeth.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-validate-state.sh` (territory:
      sibling 279 declares this file) and locate the `FIX_FIXTURE_DIR` heredoc.
- [ ] Add two entries to the fixture's `active_projects`, keeping projects 1 (Class A exact
      duplicate) and 2 (Class B normalization-equivalent) exactly as they are:
      project 3 with `"file_scope": null`, and project 4 with **no `file_scope` key at all**.
      Give both the same `project_name`/`status`/`task_type`/`created`/`last_updated`/`dependencies`
      shape the existing entries use, and bump `next_project_number` to 5.
- [ ] Extend the comment above the fixture to state what the four entries now cover (Class A
      repair, Class B untouched, null-valued untouched, absent-key untouched) and that the null
      entry is the crash-triggering shape.
- [ ] Add two capture lines beside the existing `fix_fs1`/`fix_fs2` captures:
      `fix_p3_null=$(jq -r '.active_projects[] | select(.project_number==3) | [has("file_scope"), (.file_scope == null)] | @tsv' ...)`
      and
      `fix_p4_has_key=$(jq -r '.active_projects[] | select(.project_number==4) | has("file_scope")' ...)`.
- [ ] Extend the `if` condition with three new conjuncts: `fix_p3_null` is `true\ttrue`,
      `fix_p4_has_key` is `false`, and `$out` does NOT contain
      `--fix: state-write.sh failed` (e.g. `! grep -q '\-\-fix: state-write.sh failed' <<< "$out"`).
- [ ] Extend the `fail` message and add `info` lines for the two new captures, matching the
      existing block's diagnostic style.
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` and confirm the
      `--fix fixture` assertion **FAILS**, with the `info` output showing project 1 still carrying
      its duplicates and `--fix: state-write.sh failed` present in `$out`. A green run here means
      the fixture does not exercise the crash — stop and diagnose rather than proceeding.
- [ ] Commit the red fixture on its own (the fixture edit is complete and verified-red; the RED
      state belongs to the code under test, not to a half-applied edit).

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the fixture lives in the `FIX_FIXTURE_DIR` block circa
line 600 and that projects 3 and 4 are new numbers not already used there. Confirm at
implementation time by grepping `FIX_FIXTURE_DIR` and reading the heredoc's existing
`project_number` values before inserting; line numbers in this plan are approximate anchors only
and will have drifted.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - extend the
  `FIX_FIXTURE_DIR` heredoc with a null-valued and an absent-key entry, add three assertions and
  their diagnostics, update the fixture's explanatory comment

**Verification**:
- The suite runs and the `--fix fixture` case reports FAIL (not SKIP). A SKIP means no deployed
  `state-write.sh` exists at `$REPO_ROOT/.claude/scripts/state-write.sh`; resolve that first,
  because a skipped fixture verifies nothing.
- The failure diagnostics name project 1's undeduplicated array, confirming the write was refused.
- `git diff` on the file touches only the `FIX_FIXTURE_DIR` block; `NOMFG_FIXTURE_DIR` is
  unchanged.

---

### Phase 2: Swap the mutation-filter predicate and rewrite its comment [NOT STARTED]

**Goal**: The mutation filter gates on array type rather than key presence, and the comment block
above it documents the type test instead of endorsing the defect.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/validate-state.sh` around the
      `if [[ "$DO_FIX" == true ]]` block (territory: sibling 279 declares this file too).
- [ ] In the filter string passed to `bash "$FIX_STATE_WRITE"`, replace `if has("file_scope") then`
      with `if (.file_scope|type) == "array" then`. Change nothing else in that string — the
      `reduce .[] as $x ([]; if index($x) then . else . + [$x] end)` body and the `else . end`
      stay byte-identical.
- [ ] Rewrite the comment block directly above the `_fix_report` assignment so it: keeps the D3
      statement that `unique` sorts and must not be used; replaces the
      `if has("file_scope") then ... else . end` sentence with the type-test form; states why the
      type test is required (a literal-null `file_scope` has the key present but is not iterable,
      and `has()` conflated "key present" with "safe to iterate", aborting jq and causing
      `state-write.sh` to refuse the write); and retains the no-manufacture and idempotence
      statements, noting that the type test satisfies no-manufacture for free because a
      null-valued entry keeps its null and an absent-key entry stays absent.
- [ ] Leave the `_fix_report` filter itself untouched — its `($t.file_scope // [])` guard is
      already correct.
- [ ] Commit the filter and comment change together (one semantic unit: the code and the comment
      that documents it must never be separately committed in a state where the comment is wrong).

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/validate-state.sh` - mutation-filter predicate swap
  (`has("file_scope")` -> `(.file_scope|type) == "array"`) and rewrite of the comment block above
  the `--fix` filters

**Verification**:
- `bash -n agent-system/extensions/core/scripts/validate-state.sh` exits 0.
- `git diff` shows exactly two hunks in this file: the comment block and the one filter line. No
  `unique` appears anywhere in the diff; the reduce body is unchanged.
- `grep -n 'has("file_scope")' agent-system/extensions/core/scripts/validate-state.sh` no longer
  matches the mutation filter line. Remaining matches in the report filter's `select(...)`, in
  Check 10's three-way discrimination, and in header comments are expected and correct — do not
  change them.
- Deferred to Phase 3: the fixture flipping green, and the full suite.

---

### Phase 3: Full verification of the green state and the invariants [NOT STARTED]

**Goal**: The extended fixture is green, the whole suite is green, and all three invariants are
confirmed by direct observation rather than by inference from the fixture alone.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` and confirm the
      `--fix fixture` case now PASSES and the total is `0 failed`, with no previously-passing case
      regressed (compare the passed count against the Phase 1 red run).
- [ ] Re-run the direct repro against the patched source-store filter text, confirming exit 0 and
      all three shapes handled in one input:
      `echo '{"active_projects":[{"project_number":1,"file_scope":null},{"project_number":2,"file_scope":["a","a","b"]},{"project_number":3}]}' | jq -c '.active_projects = [.active_projects[] | if (.file_scope|type) == "array" then .file_scope |= (reduce .[] as $x ([]; if index($x) then . else . + [$x] end)) else . end]'`
      Expect `{"active_projects":[{"project_number":1,"file_scope":null},{"project_number":2,"file_scope":["a","b"]},{"project_number":3}]}`:
      null preserved, dedup order-preserving (`["a","b"]`, not sorted), no key manufactured.
- [ ] Confirm idempotence on a real `--fix` path: build a throwaway null-bearing fixture under
      `specs/_tmp_*_$$` (the pattern the suite itself uses, so the deployed `state-write.sh`
      resolves), run `--fix` twice, and confirm the second run reports "nothing to repair" and
      leaves the file byte-identical to the first run's output. Remove the fixture directory
      afterward.
- [ ] Confirm no `.claude/**` path was modified: `git status --short` shows changes only under
      `agent-system/extensions/core/scripts/`, and no path under `.claude/` appears.
- [ ] Review `git status --short` and `git diff --staged` for foreign edits from siblings
      268/278/279 before the final commit; stage only this task's two files by explicit name.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:
- none planned - verification only; any edit needed here is a defect found by verification and
  belongs to the phase that introduced it

**Verification**:
- Suite exits 0 with the `--fix fixture` case passing and no regressions.
- Direct repro produces the exact expected output above with exit 0.
- Double-`--fix` run is byte-stable and reports "nothing to repair" on the second pass.
- Working tree contains no modification under `.claude/**`.

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-validate-state.sh` exits 0 with
      `0 failed`, and the `--fix fixture` case PASSES rather than SKIPS.
- [ ] The `--fix fixture` case FAILED before Phase 2 and PASSES after it (the red-then-green proof
      that the regression test has teeth).
- [ ] Project 1's Class A duplicates are removed order-preservingly; project 2's Class B pair is
      untouched; project 3 still satisfies `has("file_scope") == true and .file_scope == null`;
      project 4 still satisfies `has("file_scope") == false`.
- [ ] `$out` from the fixture run contains no `--fix: state-write.sh failed` line.
- [ ] `bash -n` passes on both modified files.
- [ ] `NOMFG_FIXTURE_DIR` and its assertions are unchanged and still pass.
- [ ] Running `--fix` twice over a null-bearing fixture is idempotent.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/validate-state.sh` - mutation filter gated on array type;
  comment block documenting the type test and the null-vs-absent distinction.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` - `FIX_FIXTURE_DIR` extended
  with null-valued (project 3) and absent-key (project 4) entries plus three new assertions.
- `specs/269_validate_state_fix_null_file_scope_crash/summaries/01_*-summary.md` - implementation
  summary at postflight.

## Rollback/Contingency

Both phases commit independently and each touches one file, so rollback is a targeted revert of
the relevant commit — no snapshot machinery is warranted for a two-file, two-commit change.

- Phase 2 regression (the new filter misbehaves on a shape the fixture does not cover): revert the
  Phase 2 commit only. The Phase 1 fixture commit then stands as a documented red test, which is a
  legitimate state to leave behind and hands the next attempt a working reproduction.
- Phase 1 regression (the fixture itself is malformed and breaks the suite): revert the Phase 1
  commit; the suite returns to its prior green-but-blind state.
- If a rollback that would discard uncommitted work becomes necessary, follow
  `context/contracts/recovery.md`'s rollback rung for the correct snapshot invocation, including
  its out-of-scope override flag. Do not emit a bare default-mode `git-snapshot.sh 269` as a
  precautionary checkpoint — three sibling tasks are live on this tree and a reverting snapshot
  would discard their in-flight work.
- Nothing in this task writes to any real `state.json`; all `--fix` runs target throwaway fixture
  directories under `specs/_tmp_*_$$`, so there is no state-corruption path to unwind.
