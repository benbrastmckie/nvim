# Implementation Plan: Task #448

- **Task**: 448 - Contain the regression-anchor source-store mutation so a concurrent session cannot observe or inherit it
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: 328 (SATISFIED -- landed and archived, see Premise Re-Validation)
- **Research Inputs**: specs/448_contain_deliberate_break_source_mutations/reports/01_contain-deliberate-break-mutations.md
- **Artifacts**: plans/01_contain-deliberate-break-mutations.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The regression-anchor check in `test-orchestrate-cycle-postflight.sh` mutates the real
source-store file `$CORE_DIR/orchestrate-cycle-postflight.sh` in place and relies on a
backup/restore pair plus an EXIT trap to put it back. The containment adopted here removes the
write to the shared tree entirely: call `setup_sandbox()` first so a clean copy lands at `$SUT`,
then apply the identical `sed` mutation to `$SUT`. The source store is never written, so there is
no exposure window for a concurrent reader and nothing for a trap to restore. Paired with that,
a new source-store-scoped lint detects both residue signals of the anti-pattern (an anchored-start
`while false &&` guard, and a leftover `*.anchor-bak` file), registered as gate 28 and covered by
its own suite, so a future reintroduction is caught mechanically rather than retrospectively.

### Premise Re-Validation

The dispatch's `## Premise Re-Validation` block flagged three carried claims plus the standing
edit-target line. Each checked against live state and against the research report:

1. **Edit target is the source store** (dispatch line 1) -- CONFIRMED unchanged.
   `.claude-extensions.json` records `"source_dir":
   "/home/benjamin/.config/nvim/agent-system/extensions/core"`. All edits land under
   `agent-system/extensions/core/**`, followed by a redeploy.
2. **The `setup_sandbox` re-copy constraint** (dispatch line 18) -- CONFIRMED, and its
   implication inverted. `setup_sandbox()` (lines 62-99) does `rm -rf "$WORKDIR"` then
   `cp "$CORE_DIR/$f" "$WORKDIR/.claude/scripts/$f"` for each collaborator. The constraint is
   real: a mutation on `$SUT` applied *before* `setup_sandbox()` is erased. The existing comment
   concludes from this that the mutation "must live" in `$CORE_DIR`; that conclusion does not
   follow -- it only requires the mutation to be applied *after* the last `setup_sandbox()` call,
   which the current block's ordering (mutate, then `setup_sandbox`) does not do. No
   `setup_sandbox()` call occurs between the block's own call and its `run_sut`, so a post-sandbox
   mutation on `$SUT` survives to `run_sut` and is honored.
3. **Harness override home does not exist** (dispatch line 25) -- CONFIRMED.
   `agent-system/extensions/core/scripts/lib/` contains no `test-harness-lib.sh` and no
   `*harness*`/`*test*` file at all. The dispatch's candidate option (1), framed as a generic
   harness override-source feature, has no home; the equivalent outcome is reached by the reorder
   above. Note that `agent-system/extensions/core/scripts/lib/test-harness-lib.sh` is nonetheless
   present in this task's declared `file_scope` in `specs/state.json` -- a declared path with no
   file behind it, which no phase here creates.
4. **The detector's self-exclusion regex** (dispatch line 27) -- CONFIRMED live, not merely
   carried. `grep -n "while false"` on the test file returns exactly one line (2666, the `sed`
   replacement string); the anchored form `grep -rnE '^[[:space:]]*while false[[:space:]]*&&'`
   over `agent-system/extensions/core --include="*.sh"` returns nothing. The anchored regex
   therefore separates the two cases today with zero false positives.
5. **Line numbers moved, as the dispatch warned.** The anchor block is at lines 2652-2695 (the
   dispatch cited "around 2170 and 2183" for the mutated loop; the research cited "2658-2695" for
   the block). The mutated target lines in `orchestrate-cycle-postflight.sh` are 2183 and 2196 --
   the `sed` pattern matches *two* `^    while IFS= read -r f; do$` lines, which is consistent
   with the dispatch's symptom describing two neutered accumulators
   (`cycle_modified_files` and `invocation_modified_files`). The anchor comment marker is at line
   2167.
6. **The already-fixed instance is still absent.** `grep -n "while false"
   agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` returns nothing, and
   `find agent-system/extensions/core -name "*.anchor-bak"` returns nothing. This record remains
   prevention-only; no phase re-does the already-reverted fix.
7. **Territory edge 328 is SATISFIED, a change from the dispatch's state.** The dispatch declares
   "328 ... Must land first." 328 is no longer in `specs/state.json`'s `active_projects`; it is
   archived at `specs/archive/328_systematic_script_and_test_corpus_efficiency` and its
   completion commit is `fd86bf491 task 328: complete implementation`. The blocker is cleared and
   no deferral is required. 415 has likewise landed (archived at
   `specs/archive/415_exact_pid_process_check_standard`); its standard lives in
   `context/standards/shell-script-testing.md` as `### Exact-pid process checks: the
   parallelism-safety rule for leftover/liveness assertions`, which settles the placement
   preference the dispatch's duplicate check recorded (see Decisions).
8. **Gate numbering** -- CONFIRMED. The highest `gateN_run()` in `verify-deploy.sh` is
   `gate27_run` (line 2050) and the highest `gate-registry.data` row id is 27. The next gate is
   28. No prose or script hardcodes a total gate count: `verify-deploy.sh`'s `--only-gate` range
   derives its maximum from `gate_registry_max_id`, and
   `test-verify-deploy-gate-selection.sh` reads `REGISTRY_MAX="$(gate_registry_max_id)"` rather
   than a literal.

### Research Integration

The research report's recommendations are adopted substantially as written, with two additions
and one adjustment derived during this planning pass:

- **Adopted**: the reorder as the primary containment (recommendation 1); the two in-suite
  invariant assertions (recommendation 2); the paired detector with an anchored-start regex and
  the `*.anchor-bak` check (recommendation 3); the detector's own suite (recommendation 4); and
  the "audited, no action" record for `test-validate-no-task-references.sh` (recommendation 5).
- **Addition (non-vacuousness)**: a post-`sed` assertion that the mutation actually applied to
  `$SUT`. The research's own risk register flags that a careless edit could turn the anchor into a
  vacuous pass; a silent `sed` no-op is the other route to the same outcome, and the reorder
  makes the target path a thing that can drift. Phase 1 adds that check.
- **Addition (fixture self-collision)**: the detector's scope includes `scripts/tests/`, so the
  detector's own new suite must plant its positive fixture without any line of its own source
  beginning with `while false &&`. This is the concrete form of the dispatch's "solve the
  self-exclusion explicitly" constraint, and it is a property of the new suite's authoring, not
  of the regex. Phase 5 carries it as a named task plus a negative-control case.
- **Adjustment (detector scope)**: widened from the research's
  `agent-system/extensions/core/**/*.sh` to all of `agent-system/extensions/`, matching
  `lint-scoped-commit-boundary.sh`'s own stated scope ("anywhere under
  `agent-system/extensions/`"). The research's audit already searched every extension and found
  the pattern only in core; a scope that stops at core would not see a future recurrence in
  another extension's suites, which are flattened into the same deployed
  `.claude/scripts/tests/` directory.

### Prior Plan Reference

No prior plan. This is the task's first plan round.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and `roadmap_flag` is not
set, so no roadmap consultation was performed and no roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Remove the write to `$CORE_DIR` from the regression-anchor check, closing the
  concurrent-observation window outright rather than shrinking it.
- Keep the anchor's guarantee byte-for-byte intact: artificially re-gating the accumulation
  block must still flip the cited fixture red.
- Make the two residue signals of the anti-pattern mechanically detectable, at gate level, in a
  way that does not block a suite legitimately holding a mutation mid-run.
- Pin the source-store byte-identity invariant inside the suite that previously violated it.
- Document the safe pattern in the testing standard so the convention is stated, not re-derived.

**Non-Goals**:
- Building a generic test-harness override-source feature. Its named home does not exist and one
  call site does not justify creating it.
- Holding a repository-level lock for the mutation window (dispatch option 2). See Decisions.
- Re-doing the already-reverted fix to `orchestrate-cycle-postflight.sh` itself. This record is
  prevention-only; that file is confirmed clean.
- A write-time PreToolUse block on the anti-pattern. The dispatch forbids it and it would make
  the technique unusable.
- Proving the absence of every conceivable source-store mutation. The detector is a line-oriented
  guardrail against a named shape, and says so in its own header.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The reorder accidentally drops the `grep -qF "$anchor_marker"` presence guard, turning the anchor into a vacuous pass | H | M | Phase 1 keeps the guard and its `else`/`common_test_fail` arm verbatim; only the write target and the block ordering change. Phase 1 additionally asserts the `sed` actually applied to `$SUT`. |
| The `sed` pattern silently stops matching after a future reindent of `orchestrate-cycle-postflight.sh`, so the anchor passes vacuously | H | M | Phase 1's post-`sed` assertion on `$SUT` fails loudly when the substitution is a no-op. |
| Mutating `$SUT` at the wrong point in the block leaves the sandbox git tree dirty in a way the SUT itself observes (it reads git status in `$WORKDIR`) | M | M | Phase 1 places the `sed` immediately after `setup_sandbox()` and before `commit_fixture`, which reproduces exactly the file state today's ordering produces at commit time. |
| The new suite's own planted fixture text trips the new detector, making the two mutually unsatisfiable | H | H (if unhandled) | Phase 5 constructs the planted line so no source line of the suite begins with `while false &&`, and carries a negative-control case asserting the detector reports nothing against the new suite itself. |
| Gate 28's registry row fails `lint-gate-registry.sh`'s Checks A-G (field count, contiguity, `cost_class` vocabulary, `input_corpus` grammar) | M | M | Phase 4 writes the row by copying gate 27's field-for-field shape and runs `lint-gate-registry.sh --verbose` as its own verification. |
| A record-versioning or task-number phrase leaks into a file under `agent-system/**` while rewriting a comment that describes a changed design | M | H (if unguarded) | Every phase that edits a comment or standard states the current design only. Phrases like "no longer mutates", "previously", "used to" are prohibited by `rules/no-record-versioning-in-deliverables.md`; the incident is described structurally ("a mutation applied to the shared source store is observable by a concurrent reader"), never as this record's own history. |
| Three paths this plan edits are outside the task's declared `file_scope` (`scripts/verify-deploy.sh`, `scripts/gate-registry.data`, `manifest.json`) | M | H | Declared explicitly in each phase's `Files to modify`, so the plan-to-`file_scope` harvest picks them up. The implementer should confirm the harvest ran before any commit that touches them. |
| Adding to `context/standards/shell-script-testing.md` (85 KB today) pushes a context-budget threshold | L | L | Phase 6's verification runs `test-verify-deploy-context-budget.sh`; the addition is a short subsection, not a new document. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4, 5 | 1 (for 2); 3 (for 4 and 5) |
| 3 | 6 | 1, 2, 3 |
| 4 | 7 | 1, 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel.

### Phase 1: Relocate the regression-anchor mutation onto the sandbox copy [COMPLETED]

**Goal**: The regression-anchor check never writes `$CORE_DIR`. The mutation is applied to the
sandbox copy at `$SUT` after `setup_sandbox()` has produced it, and the anchor's red-flip
guarantee is preserved and proven non-vacuous.

**Tasks**:
- [x] Re-derive the block's live line range before editing (`grep -n "ANCHOR_SRC\|anchor_restore" *(completed: anchor block at 2652-2695, marker at 2659, ANCHOR_SRC at 2660)*
      agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`); line
      numbers in this plan are a hypothesis, not a fact.
- [x] Reorder the block: move the existing `setup_sandbox` call to the top of the `if` body, then *(completed)*
      apply the identical `sed -i` substitution to `$SUT` instead of `$ANCHOR_SRC`. Place the
      `sed` after `setup_sandbox` and before `commit_fixture`.
- [x] Keep `anchor_marker` and the `grep -qF "$anchor_marker" "$ANCHOR_SRC"` guard exactly as *(completed)*
      they are (a read of the source store, not a write), including the `else` arm's
      `common_test_fail` message.
- [x] Remove the now-unneeded `cp "$ANCHOR_SRC" "${ANCHOR_SRC}.anchor-bak"`, the *(completed)*
      `anchor_restore()` definition, the `trap 'anchor_restore; cleanup' EXIT` installation, the
      `anchor_restore` call, and the `trap cleanup EXIT` reset. Leave the suite-level
      `common_test_workdir_init` EXIT trap untouched.
- [x] Add a non-vacuousness assertion immediately after the `sed`: confirm `$SUT` now contains a *(completed)*
      line matching `^[[:space:]]*while false[[:space:]]*&&`, and `common_test_fail` with a clear
      message if it does not (a `sed` that matched nothing would otherwise produce a
      silently-vacuous anchor).
- [x] Rewrite the block's header comment (lines 2652-2657 today) to state the current mechanism: *(completed)*
      the mutation is applied to the sandbox copy that `run_sut` executes, after
      `setup_sandbox()` has populated it, so the shared source store is never written and no
      restore step is required. State the `setup_sandbox` re-copy constraint as the reason the
      mutation must follow the sandbox build. Describe the hazard structurally (a mutation in the
      shared source store is observable by any concurrent reader and has no way to announce
      itself); do not narrate this file's own edit history, and do not reference a task number --
      see `rules/no-record-versioning-in-deliverables.md` and
      `rules/no-task-references-in-deliverables.md`.
- [x] Confirm no `setup_sandbox` call is introduced or left between the new `sed` and `run_sut` *(completed)*
      (such a call would erase the mutation and silently vacate the anchor).

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-corroborate-phase-counts.sh,test-handoff-dispatch-identity.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-stall-reprompt-wiring.sh`
is `suite_selection_select`'s full selection for this file, and the anchor case inside
`test-orchestrate-cycle-postflight.sh` directly re-asserts the red-flip guarantee this phase must
not break.

**Scope Hypothesis**: the anchor block sits at lines 2652-2695, the anchor comment marker at line
2167, and the `sed` pattern `^    while IFS= read -r f; do$` matches exactly two lines (2183 and
2196) of `orchestrate-cycle-postflight.sh`. Confirm all three by `grep -n` before editing; if the
match count is not two, stop and establish which accumulator is no longer covered before
proceeding.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - reorder the
  regression-anchor block, retarget the mutation to `$SUT`, drop the backup/trap/restore
  machinery, add the non-vacuousness assertion, rewrite the block header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-orchestrate-cycle-postflight.sh` exits 0, and the case
  "artificially re-gating the WORK (j) block flips this case red (anchor confirmed live)" is
  present and PASSing in the output -- the anchor's guarantee, pinned.
- The non-vacuousness assertion added above also reports PASS (a `sed` no-op would surface here).
- `git diff --stat` on `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is
  empty after the run, and `find agent-system/extensions/core -name "*.anchor-bak"` returns
  nothing -- the invariant the cited instance violated, checked manually here and automated in
  Phase 2.

---

### Phase 2: Pin the source-store byte-identity invariant inside the suite [NOT STARTED]

**Goal**: The suite itself fails loudly if any future edit reintroduces a write to the real
source-store file, rather than relying on an external observer noticing.

**Tasks**:
- [ ] Near the suite's top (after `CORE_DIR` is resolved and before the first `setup_sandbox`),
      capture a checksum of `$CORE_DIR/orchestrate-cycle-postflight.sh` into a variable.
- [ ] At the very end of the suite (before the pass/fail summary), recompute the checksum and
      emit a counted `common_test_pass`/`common_test_fail` case asserting byte-identity, with the
      failure message naming the file and both checksums.
- [ ] Add a second counted case at the same point asserting that no `*.anchor-bak` file exists
      anywhere under `$CORE_DIR` (`find "$CORE_DIR" -name "*.anchor-bak"` yields nothing),
      failing with the offending paths listed.
- [ ] Make both cases unconditional (never skipped), per the standard's loud-skip discipline --
      a check that can silently do nothing provides no guarantee.
- [ ] Confirm both new cases are counted into `$PASSED`/`$FAILED` so the suite's exit code
      reflects them.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-corroborate-phase-counts.sh,test-handoff-dispatch-identity.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-recover-message-findings.sh,test-stall-reprompt-wiring.sh`
is `suite_selection_select`'s full selection for this file, and the two assertions added here are
internal to `test-orchestrate-cycle-postflight.sh` with no consumer outside it.

**Scope Hypothesis**: the suite ends with the conventional
`echo "Passed: $PASSED" / echo "Failed: $FAILED"` block and the new cases can be inserted
immediately before it. Confirm by reading the file's last 20 lines; if the summary block has a
different shape, place the cases at the last point before whichever construct computes the exit
code.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add the
  checksum capture near the top and the two end-of-run invariant cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-orchestrate-cycle-postflight.sh` exits 0 with both new cases PASSing.
- Negative control, run manually and reverted immediately: temporarily append a byte to
  `$CORE_DIR/orchestrate-cycle-postflight.sh` from a separate shell mid-run (or apply the
  checksum comparison against a deliberately altered captured value) and confirm the
  byte-identity case goes RED. This proves the assertion is not vacuous.

---

### Phase 3: Add the deliberate-break residue detector [NOT STARTED]

**Goal**: A source-store-scoped lint reports both unambiguous residue signals of the
anti-pattern, following the established `scripts/lint/` family conventions, with its limitations
stated rather than implied.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh`,
      modelled structurally on `lint-scoped-commit-boundary.sh`: a header naming the anti-pattern
      and why it matters, an explicit `KNOWN LIMITATION` section, a `DETECTION MODEL` section,
      `--verbose` and `--help` flags, and exit codes 0 (clean) / 1 (findings) / 2
      (environment/usage error).
- [ ] Implement check A: any line under `agent-system/extensions/` matching
      `^[[:space:]]*while false[[:space:]]*&&` in a `*.sh` file is a finding. Use the anchored
      start deliberately -- it is what separates a real bash guard from a quoted `sed`
      replacement string containing the same phrase, with no path exclusion.
- [ ] Implement check B: any `*.anchor-bak` file under `agent-system/extensions/` is a finding
      (a surviving backup implies a crashed or incorrect restore step).
- [ ] Emit each finding as a `[VIOLATION]` line so
      `verify_deploy_extract_verdict_lines '[VIOLATION]' ...` can harvest it, matching gate 27's
      consumer shape.
- [ ] State in the `KNOWN LIMITATION` section that the check is regex-only and line-oriented: it
      cannot see an indirected mutation (a pattern held in a variable, or assembled across
      lines), and a clean run means "the known bad shapes are not present", never "no source
      mutation exists".
- [ ] State in the header that the detector is advisory/gate-level by construction -- it runs as
      part of an explicit gate pass, never as a write-time block, because a suite legitimately
      holds such a mutation for the duration of one fixture.
- [ ] Register the script in `agent-system/extensions/core/manifest.json`'s `provides.scripts`
      array as `lint/lint-deliberate-break-residue.sh`, subdirectory-qualified, matching the
      other `lint/lint-*.sh` entries.
- [ ] Describe the motivating hazard structurally in the header, with no task number and no
      record-versioning phrasing.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for both
touched paths, so no existing suite covers them; the covering checks are therefore the direct
`bash agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh --verbose` run
and `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose`, both checked
by exit status.

**Scope Hypothesis**: the anchored regex currently matches zero lines anywhere under
`agent-system/extensions/`, and zero `*.anchor-bak` files exist. Confirm by running the new lint
over the live tree and expecting exit 0; a nonzero result is a pre-existing occurrence to
adjudicate on its merits, not evidence of a lint defect.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh` - new detector
  (both checks, header, limitations, `--verbose`/`--help`, `[VIOLATION]` output)
- `agent-system/extensions/core/manifest.json` - add the script to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh --verbose`
  exits 0 against the live source store.
- The same run, invoked against a scratch copy with a planted `while false &&` guard, exits 1 and
  prints a `[VIOLATION]` line naming the file and line (the mechanical form of this is pinned by
  Phase 5's suite; this is the manual smoke check).
- `bash agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh --help` exits
  0 and prints usage.
- `jq -e '.provides.scripts | index("lint/lint-deliberate-break-residue.sh")'
  agent-system/extensions/core/manifest.json` succeeds.

---

### Phase 4: Register the detector as gate 28 [NOT STARTED]

**Goal**: The detector runs as part of the gate set, scoped to the source store, selectable via
`--only-gate 28`, and structurally valid against the registry lint.

**Tasks**:
- [ ] Add `gate28_run()` to `agent-system/extensions/core/scripts/verify-deploy.sh` immediately
      after `gate27_run()`, following that function's template exactly: `gate_selected 28`, a
      `say "28. ..."` line, `CURRENT_GATE="gate28"`, the
      `[ ! -d "$TARGET/agent-system/extensions" ]` SKIP branch (this is the required
      "scoped to the SOURCE STORE" mechanism), a `[ ! -f ... ]` `fail` branch for a missing lint
      script, the `--verbose` invocation with `REPO_ROOT="$TARGET"`, `pass`/`fail`, and the
      `FINDINGS_LIST` population via `verify_deploy_extract_verdict_lines '[VIOLATION]'`.
- [ ] Add a single TAB-separated row with id 28 to
      `agent-system/extensions/core/scripts/gate-registry.data`, 9 fields, copying gate 27's
      field shapes: name `Deliberate-break residue lint
      (lint-deliberate-break-residue.sh)`, invoke `gate28_run`, dependencies `-`,
      requires_source_store `true`, timeout_s `30`, cost_class `free`, serialized `false`,
      input_corpus `@extensions`.
- [ ] Verify the row uses real TAB characters (not spaces) and has exactly 8 tabs, per the
      registry lint's Check F.
- [ ] Confirm no total-gate-count literal needs updating: `--only-gate`'s maximum derives from
      `gate_registry_max_id`, and `test-verify-deploy-gate-selection.sh` reads
      `REGISTRY_MAX="$(gate_registry_max_id)"`. Re-grep to confirm no literal `27` bound was
      introduced elsewhere since.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: interface

**Tier Justification**: the registry row is read by consumers outside this phase's own files
(`lint-gate-registry.sh`'s Checks A-G and `gate_registry_max_id`'s derived `--only-gate` range),
so the covering check is `suite_selection_select`'s full selection for these two paths, `bash
agent-system/extensions/core/scripts/tests/run-all.sh --only
test-check-task-references.sh,test-claude-refresh-matcher.sh,test-deploy-baseline-lib.sh,test-deploy-orphans.sh,test-deploy-verify-overlap.sh,test-deploy-verify-wiring.sh,test-gate3-strict-equivalence.sh,test-gate8-expected-new-distinction.sh,test-gate-cache-equivalence.sh,test-gate-cache-lib.sh,test-gate-lock.sh,test-gate-out-self-attribution.sh,test-gate-registry-resolution.sh,test-lint-branch-gated-sections.sh,test-lint-hook-registration-paths.sh,test-lint-json-channel-discipline.sh,test-lint-shellcheck-parallel.sh,test-lint-task-lookup-adoption.sh,test-lint-unit-integration-boundary.sh,test-lint-verdict-extraction-anchoring.sh,test-measure-gate-costs.sh,test-orchestrate-batch-gate.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-parallel.sh,test-run-all-selection.sh,test-validate-artifact.sh,test-verify-deploy-context-budget.sh,test-verify-deploy-gate-selection-crash-net.sh,test-verify-deploy-gate-selection.sh`,
plus `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose`.

**Scope Hypothesis**: 28 is the next contiguous gate id and no other registry row or gate
function has been added concurrently. Confirm with `tail -3 gate-registry.data` and
`grep -nE '^gate[0-9]+_run\(\)' verify-deploy.sh | tail -3` immediately before editing; if 28 is
taken, use the next free contiguous id and adjust the function name to match.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - add the gate 28 run function
  immediately after the gate 27 one
- `agent-system/extensions/core/scripts/gate-registry.data` - add the id-28 row

**Verification**:
- `bash agent-system/extensions/core/scripts/lint/lint-gate-registry.sh --verbose` exits 0 (all
  of Checks A-G, including contiguity, field count, `cost_class` vocabulary and `input_corpus`
  grammar).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 28` exits 0 and the
  output shows the gate running (not skipping) against the source store.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-gate-registry-resolution.sh,test-verify-deploy-gate-selection.sh` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --verbose` exits 0 for the
  edited `verify-deploy.sh`.

---

### Phase 5: Give the detector its own suite [NOT STARTED]

**Goal**: Both detector directions are pinned mechanically, including the self-exclusion
property, and the new suite itself follows the safe-copy pattern it exists to protect.

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-lint-deliberate-break-residue.sh`
      following the standard's required structural model: `set -uo pipefail`, `SCRIPT_DIR`,
      `source "$SCRIPT_DIR/../lib/common.sh"`, `common_test_repo_root`,
      `common_test_workdir_init` called bare, `common_test_pass`/`_fail`/`_info`, and the
      conventional `Passed:`/`Failed:` summary with exit 0/1. Do not define local
      `pass()`/`fail()`/`info()`.
- [ ] Resolve the lint under test through `common_test_resolve_subject` with an explicit mode and
      pair it with `common_test_declare_subject`, per the mandatory subject-resolution
      declaration enforced by gate 27. Do not hand-roll a candidate lookup or an inline
      `*CANDIDATES*=()` array.
- [ ] Case 1 (positive, check A): build a scratch tree under `$WORKDIR` mirroring
      `agent-system/extensions/...`, plant a file containing a line that begins with the
      `while false &&` guard, run the lint against that scratch root, assert exit 1 and a
      `[VIOLATION]` line naming the planted file.
- [ ] Construct that planted line so no line of this suite's own source begins (after leading
      whitespace) with `while false &&` -- assemble it from two pieces at write time, so the
      detector reports nothing against this suite file itself. This is the explicit solution to
      the self-exclusion problem; a path exclusion is not acceptable, since it would also blind
      the detector to a real mutation planted in a test file.
- [ ] Case 2 (positive, check B): plant an empty `*.anchor-bak` file in the scratch tree, run the
      lint, assert exit 1 and a `[VIOLATION]` line naming it.
- [ ] Case 3 (negative control, self-exclusion): run the lint against the real source store and
      assert exit 0 -- in particular that it does NOT fire on
      `test-orchestrate-cycle-postflight.sh`'s own `sed` replacement string, nor on this new
      suite's own fixture-construction code.
- [ ] Case 4 (clean-tree control): run the lint against a scratch tree containing a `.sh` file
      whose text includes `while false &&` only inside a quoted string on a line that starts with
      something else, and assert exit 0.
- [ ] Never write to `$CORE_DIR` or any real source-store path from this suite: every fixture is
      a scratch copy under `$WORKDIR`, matching the precedent in `test-git-commit-scoped.sh` and
      `test-lint-deploy-caller-wrap.sh`.
- [ ] Register the suite in `agent-system/extensions/core/manifest.json`'s `provides.scripts` as
      `tests/test-lint-deliberate-break-residue.sh`.
- [ ] Add a row to `agent-system/extensions/core/scripts/tests/suite-classification.data`:
      `test-lint-deliberate-break-residue.sh`, class `unit`, reason `-`. Confirm the suite does
      not reference `deploy-headless.sh`, `verify-deploy.sh`, or `run-all.sh` by literal basename
      anywhere in its text (including comments and fixture strings) -- if it does, the correct
      remedy is to classify it `integration` with a stated `invokes:` reason, never to suppress
      the finding.
- [ ] Confirm no `suite-selection-lib.sh` or `suite-cost-hints.txt` edit is needed: stratum (a)
      basename pairing maps `lint-deliberate-break-residue.sh` to
      `test-lint-deliberate-break-residue.sh` automatically, and the cost-hints file is advisory
      and optional.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for these
three paths (the new suite does not exist at plan time, so nothing maps them), so no existing
suite covers them and the covering checks are the direct runs of `bash
agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh --verbose`, `bash
agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh --verbose` and
the harness-adoption lint in that same `scripts/lint/` directory (named in full under
Verification below), each checked by exit status.

**Scope Hypothesis**: four cases as enumerated, and the suite's own text produces zero detector
findings. Confirm the second half by running
`lint-deliberate-break-residue.sh --verbose` and checking the new suite file is absent from the
output; if it appears, the fixture construction is wrong and must be split further -- the fix is
never a path exclusion in the lint.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-deliberate-break-residue.sh` - new suite
  (four cases, scratch fixtures only, declared subject resolution)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - add the
  classification row
- `agent-system/extensions/core/manifest.json` - add the suite to `provides.scripts`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-lint-deliberate-break-residue.sh` exits 0 with all four cases PASSing.
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh --verbose`
  exits 0 (the new suite carries a classification row and satisfies its class's rule).
- `bash agent-system/extensions/core/scripts/lint/lint-subject-resolution-declaration.sh
  --verbose` exits 0 (the new suite declares its resolved subject).
- `bash agent-system/extensions/core/scripts/lint/lint-test-harness-adoption.sh --verbose` exits
  0 (the new suite uses the shared harness rather than local helper definitions).
- `bash agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh --verbose`
  still exits 0 against the live source store with the new suite file present -- the
  self-exclusion property, pinned.
- `git diff --stat agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is empty
  after the suite run.

---

### Phase 6: Record the audit and state the safe pattern in the testing standard [NOT STARTED]

**Goal**: The corpus-wide audit result is recorded rather than re-derived, and the safe pattern
is stated as a rule in the testing standard so the next author of a deliberate-break fixture
reads it instead of copying the nearest example.

**Tasks**:
- [ ] Re-run the corpus audit live, since the test corpus has changed since the research pass:
      (a) grep every `scripts/tests/*.sh` across all extensions for a `sed -i`, `cp`, or
      redirection whose target is a real-source-dir variable (`$CORE_DIR`, `$SRC_DIR`,
      `$SRC_SCRIPTS_DIR`, `$ANCHOR_SRC` or equivalent); (b) enumerate every suite defining a
      real-source-dir variable via `"$(cd "$SCRIPT_DIR/.." && pwd)"` and grep each for a write
      targeting its own variable. Record the resulting count.
- [ ] If the audit finds a site other than the one Phase 1 fixed, stop and record it explicitly
      rather than folding an unplanned fix into this phase -- the dispatch requires each such
      site to be brought under the rule or recorded as exempt, and an unexpected third site is a
      scope change, not a detail.
- [ ] Record `test-validate-no-task-references.sh` as audited-with-no-action: its own
      "regression anchor" operates on in-memory fixture strings passed to assertion helpers and
      mutates no file. Say this positively, as a property of that suite, not as a comparison
      against another record's claim.
- [ ] Add a new `###` subsection to
      `agent-system/extensions/core/context/standards/shell-script-testing.md`, placed under
      `## Fixture convention` directly after `### Never resolve a path against the live tree`
      (see Decisions for the placement rationale). State: a suite that deliberately breaks a
      production script to prove a case is not passing vacuously MUST apply that mutation to a
      sandbox or scratch copy, never to the real source-store file; the mutation must be applied
      after whatever sandbox-build step copies the file, since such a step re-copies from the
      source store and would erase an earlier mutation; and a backup/restore pair plus an EXIT
      trap is recovery, not containment -- a trap does not fire on `SIGKILL`, an OOM kill or a
      host crash, and even a perfect restore leaves the mutation observable by any concurrent
      reader for the whole fixture's duration.
- [ ] In that subsection, name the two established safe-copy precedents in this corpus
      (`test-git-commit-scoped.sh`'s inversion probes and `test-lint-deploy-caller-wrap.sh`'s
      self-test) and point at `lint/lint-deliberate-break-residue.sh` as the mechanical guard,
      noting it is gate-level and advisory because a suite legitimately holds such a mutation
      mid-run.
- [ ] Cross-reference the parallelism-safety sibling rule (`### Exact-pid process checks`) in one
      line, so the two concurrency-safety rules for suite authors are discoverable from each
      other.
- [ ] Write the whole subsection with no task-number reference and no record-versioning
      phrasing: state the rule and the structural hazard, never this standard's own drafting
      history.

**Timing**: 1 hour

**Depends on**: 1, 2, 3

**Verification Tier**: local

**Tier Justification**: this phase changes no executable surface, and the covering check is
`suite_selection_select`'s full selection for this path, `bash
agent-system/extensions/core/scripts/tests/run-all.sh --only
test-assess-repo-health.sh,test-census-count.sh,test-check-record-versioning.sh,test-check-task-references.sh,test-claude-refresh-matcher.sh,test-common-lib.sh,test-deploy-baseline-lib.sh,test-detect-noop-bash.sh,test-four-tier-conflict.sh,test-gate-cache-equivalence.sh,test-git-commit-phase.sh,test-git-commit-scoped.sh,test-git-corpus-enum-lib.sh,test-git-snapshot.sh,test-guard-destructive-git.sh,test-guard-git-push.sh,test-init-specs.sh,test-lake-build-guard.sh,test-lean-mcp-preflight-check.sh,test-lean-mcp-registration.sh,test-lean-sorry-census.sh,test-lean-src-roots.sh,test-lint-agent-contracts.sh,test-lint-shellcheck-parallel.sh,test-orchestrate-batch-gate.sh,test-orchestrate-triage-classify.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh,test-run-all-selection.sh,test-runtime-file-tracking.sh,test-task-reference-patterns-lib.sh,test-validate-bounded-waiter.sh,test-validate-handoff-location.sh,test-validate-no-record-versioning.sh,test-validate-no-task-references.sh,test-verify-deploy-context-budget.sh,test-verify-deploy-gate-selection-crash-net.sh`.

**Scope Hypothesis**: exactly one source-store-mutating suite exists corpus-wide (the one Phase 1
fixes), and `### Never resolve a path against the live tree` is still present under
`## Fixture convention` as the insertion anchor. Confirm the first by the two audit searches above
and the second by `grep -n "Never resolve a path against the live tree"` before editing; if the
anchor heading is absent, place the subsection under `## Fixture convention` at its end and say so.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - add the
  deliberate-break containment subsection under `## Fixture convention`

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-verify-deploy-context-budget.sh` exits 0.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence under
  `agent-system/**` (no task-number reference leaked into the standard).
- The two audit searches are re-run and their output recorded in the phase's own notes; the
  recorded count matches the single known site.
- `grep -n "Exact-pid process checks"
  agent-system/extensions/core/context/standards/shell-script-testing.md` still resolves, so the
  added cross-reference points at a live heading.

---

### Phase 7: Redeploy and run the full gate set [NOT STARTED]

**Goal**: The source-store changes are deployed, the whole gate set and test pool are green, and
the dispatch's pinned invariants are confirmed end to end against a full suite run.

**Tasks**:
- [ ] Redeploy the source store via `deploy-headless.sh` so the deployed `.claude/` tree carries
      the new lint, the new suite, the gate 28 wiring and the standard.
- [ ] Capture a checksum of `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
      before the full test-pool run and compare it after -- the invariant the cited instance
      violated, pinned across a complete run rather than a single-suite run.
- [ ] Confirm `find agent-system/extensions/core -name "*.anchor-bak"` returns nothing after the
      full run.
- [ ] Run the full gate set (`verify-deploy.sh`) and the full test pool (`tests/run-all.sh`),
      and reconcile any failure against the known-failures baseline rather than assuming it is
      new.
- [ ] Confirm the anchor case in `test-orchestrate-cycle-postflight.sh` is PASSing within the
      full-pool run (not just a selected run) -- the re-gate still flips the fixture red with the
      containment in place.
- [ ] Confirm gate 28 appears in the full `verify-deploy.sh` output, runs against the source store
      and passes.

**Timing**: 1 hour

**Depends on**: 1, 2, 3, 4, 5, 6

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase regenerates the entire deployed tree via `deploy-headless.sh`

**Verification**:
- `bash agent-system/extensions/core/scripts/deploy-headless.sh` completes successfully.
- `bash .claude/scripts/verify-deploy.sh` exits 0 with gate 28 present and passing; every other
  gate green or matched to the known-failures baseline.
- `bash .claude/scripts/tests/run-all.sh` exits 0, or every failure is matched to the
  known-failures baseline; the `test-orchestrate-cycle-postflight.sh` anchor case is PASSing in
  that run.
- The pre/post checksum of
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` is identical across the
  full run, and no `*.anchor-bak` file survives it.
- `bash agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh --verbose`
  exits 0 against the post-deploy source store.

---

## Testing & Validation

- [ ] The regression-anchor case still flips red when the accumulation block is re-gated -- the
      anchor's guarantee is intact (Phases 1 and 7).
- [ ] The `sed` substitution is proven to have applied, so the anchor cannot pass vacuously
      through a silent no-op (Phase 1).
- [ ] `$CORE_DIR/orchestrate-cycle-postflight.sh` is byte-identical before and after a full run
      of the suite, and across the full test pool (Phases 2 and 7).
- [ ] No `*.anchor-bak` file survives any run (Phases 2 and 7).
- [ ] The detector fires on a planted `while false &&` guard and on a planted leftover
      `*.anchor-bak`, and does not fire on the existing `sed` replacement string or on its own
      suite's fixture-construction code (Phase 5).
- [ ] Gate 28 is structurally valid against `lint-gate-registry.sh` and selectable via
      `--only-gate 28` (Phase 4).
- [ ] The new suite satisfies the harness-adoption, subject-resolution-declaration and
      unit/integration-boundary lints (Phase 5).
- [ ] No task-number reference and no record-versioning phrasing lands in any file under
      `agent-system/**` (all phases; checked in Phase 6 and by the full gate set in Phase 7).
- [ ] The corpus-wide audit is re-run live and its result recorded (Phase 6).

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - contained
  regression-anchor check plus the two source-store invariant cases
- `agent-system/extensions/core/scripts/lint/lint-deliberate-break-residue.sh` - new detector
- `agent-system/extensions/core/scripts/tests/test-lint-deliberate-break-residue.sh` - new suite
  for the detector
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `gate28_run()`
- `agent-system/extensions/core/scripts/gate-registry.data` - gate 28 row
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - classification row
- `agent-system/extensions/core/manifest.json` - two new `provides.scripts` entries
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - deliberate-break
  containment subsection
- Regenerated deployed `.claude/` tree (Phase 7)
- Implementation summary under `specs/448_contain_deliberate_break_source_mutations/summaries/`

## Rollback/Contingency

Each phase is a single scoped commit, so any phase can be reverted independently with
`git revert` of its commit followed by a redeploy. The highest-risk reversion is Phase 4's gate
registration: because `lint-gate-registry.sh`'s Check E requires contiguous ids, gate 28 must be
removed from both `verify-deploy.sh` and `gate-registry.data` together -- removing the registry
row alone leaves a defined-but-unregistered function, and removing the function alone leaves a
row whose `invoke` target does not exist (Check A). Phases 1 and 2 touch one file and revert
cleanly on their own; reverting Phase 1 restores the shared-tree mutation, so it should only be
reverted together with a replacement containment, never left reverted. If the full gate set in
Phase 7 surfaces a failure that cannot be matched to the known-failures baseline, take a
defensive checkpoint with `bash .claude/scripts/git-snapshot.sh 448 --no-revert` before
investigating, rather than reverting work in place.
