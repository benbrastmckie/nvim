# Implementation Plan: Task #283

- **Task**: 283 - Fix the agent-system test harness (run-all.sh): name failing suites, add a
  known-failing baseline, and reduce wall clock
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None
- **Research Inputs**: specs/283_test_harness_name_failures_baseline_wall_clock/reports/01_test-harness-defects-research.md
- **Artifacts**: plans/01_harness-roster-baseline-wall-clock.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The dispatch names three harness defects. Research established that Defect 1's per-suite
`[FAIL] <path>` naming already shipped upstream on 2026-09-25 and is already consumed by
`verify-deploy.sh` Gate 8 — so this plan does not re-implement it; it delivers the one piece
genuinely missing (a consolidated end-of-run failure roster) plus the regression test the
dispatch explicitly requires. Defect 2 (a machine-readable known-failing baseline) is real and
entirely unbuilt, and is the bulk of the work. Defect 3's harness-internal lever was already
shipped and measured by the archived task 261; the still-unexploited lever is orchestrator-side
amplification — five `deploy_findings_snapshot()` call sites re-run the full 105-suite Gate 8
battery 2-3 times per cycle on top of the dispatched agent's own gate runs. Alongside these,
one shared stale-fixture bug accounts for 3 of the 8 current failures and is cleared by a
one-line-per-file patch. Done means: a roster block exists and is regression-tested, a committed
manifest lets a run report `N failed, E expected, X NEW`, the 3 stale fixtures are green, and
the redeploy checkpoint no longer re-runs the shell-test battery.

### Research Integration

Every phase below is grounded in a finding from `reports/01_test-harness-defects-research.md`,
which included a live 105-suite run and standalone triage of all 8 failures:

- Per-suite `[FAIL]` naming already exists (run-all.sh lines 257 and 445, unconditional, not
  `--quiet`-suppressed). The plan scopes Defect 1 to the roster only (Phase 2).
- 3 of the 8 failures (`test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`,
  `test-orchestrate-recover-message-findings.sh`) share one root cause: a hardcoded sandbox
  `lib/*.sh` copy-list missing `return-meta-status-vocabulary.sh`, a dependency added to the real
  `orchestrate-cycle-postflight.sh` by task 258 phase 3. This directly answers the dispatch's
  explicit question about `test-handoff-dispatch-identity.sh`: it is **stale fixture
  maintenance, not evidence the handoff-identity contract is broken** (Phase 1).
- 3 further failures (`test-gate-out-repair-reporting.sh`,
  `test-lint-json-channel-discipline.sh`, `test-verify-deploy-context-budget.sh`) are real but
  unrelated defects in other components; 1 (`test-run-all-parallel.sh`) is the already-documented
  ambient-load flake; 1 (`test-typst-element-lint.sh`) is caused by uncommitted concurrent WIP.
  All are quarantined with reasons and owners rather than fixed here (Phase 4).
- Task 261's Phase 4 audit already closed the "can the 5 load-sensitive suites be isolated into
  the parallel pool" question with suite-by-suite evidence (zero fixed-resource collisions; all
  5 make genuine wall-clock or memory-pressure assertions that isolation cannot help). This plan
  does **not** re-open it (see Non-Goals).
- `verify-deploy.sh` already implements `--skip-slow`, which defers exactly Gate 8 (line 551-552)
  — so Phase 5's fix is a flag pass-through, not new machinery.
- `suite-cost-hints.txt` is the exact precedent for Phase 4's manifest: advisory, optional,
  checked-in, basename-keyed, drift-expected, read by `run-all.sh` at `$SCRIPT_DIR/<name>`, and
  listed in `manifest.json`'s `provides` array (line 254).

### Prior Plan Reference

No prior plan for this task. The archived `specs/archive/261_reduce_process_spawn_amplification_in_tests/`
plan is relevant prior art on the same file and is treated as a closed evidence base (its Phase 4
audit table settles the isolation question), not as a template.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- A consolidated, greppable end-of-run failure roster in `run-all.sh`, printed next to the final
  tally, that does not disturb the existing inline `[FAIL] <path>` contract Gate 8 depends on.
- A regression test proving a deliberately-failing fixture suite is named both inline and in the
  roster — the dispatch's explicit requirement, closing the "silently regress to zero [FAIL]
  lines" hole.
- A committed, machine-readable known-failing baseline manifest that `run-all.sh` optionally
  reads to report `N failed, E expected, X NEW`, with an opt-in mode that fails only on NEW.
- Every currently-red suite either fixed (the 3 sharing one stale-fixture bug) or quarantined
  with a category, a reason, and a named owner.
- A measurable wall-clock reduction by removing redundant full-suite Gate 8 runs from the
  orchestrator's own redeploy-checkpoint call sites.
- All edits in the source store under `agent-system/extensions/**`, never `.claude/**`.

**Non-Goals**:
- Re-implementing per-suite `[FAIL]` naming (already shipped 2026-09-25; re-adding it would
  duplicate a contract Gate 8 already consumes).
- Re-auditing whether the 5 load-sensitive suites can join the parallel pool (closed by task
  261's Phase 4 evidence).
- Flipping `--jobs` away from its default of 1 (task 261 deliberately declined this after a
  3-run flakiness gate).
- Fixing the underlying defects behind the quarantined suites: `validate-artifact.sh`'s repair
  aggregation, `chapter-quality-check.sh`'s channel discipline, `skill-orchestrate/SKILL.md`'s
  context-budget overage, or `typst-element-lint.sh`'s uncommitted WIP. Each gets a manifest row
  and an owner instead.
- Building the `--affected` changed-files-to-suites selector (research recommendation 6): a
  larger separate design effort, deferred to a follow-up task.
- Weakening any individual suite's assertions to make it pass.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The new roster block contains the literal token `[FAIL]`, causing `verify-deploy.sh` Gate 8's `grep -F '[FAIL]'` to double-count every failure into duplicate `FINDING gate8` rows | H | M | Phase 2 mandates the roster use a distinct `[run-all] Failing suites (N):` header with plain indented paths and **zero** `[FAIL]` tokens; Phase 3 adds an explicit assertion that the `[FAIL]` occurrence count equals the failing-suite count exactly |
| A quarantine manifest becomes a place for suites to rot unnoticed | H | M | Every row requires an owner field; an unowned row must carry the explicit `needs-owner` marker, and Phase 4 documents that as a lint-flaggable gap rather than an accepted steady state |
| `--skip-slow` on the redeploy checkpoint lets a genuine new shell-test regression slip past | M | M | The checkpoint's job is redundant double-checking — the dispatched agent's own phase gate already ran the full suite immediately prior (per the dispatch's own measured-cost account). Pre- and post-snapshots must change symmetrically so the `comm -13` diff stays meaningful; Phase 5 records the trade-off inline at each call site |
| The one-line-per-file fixture patch reintroduces the same drift the next time a core script gains a `lib/` dependency | M | H | Phase 1 evaluates the shared glob-copy pattern already used by `test-force-phases.sh:106` as the durable fix, and records the recurring-drift risk explicitly if the narrow patch is chosen instead |
| The manifest is seeded from transient state (`test-typst-element-lint.sh`'s uncommitted WIP) and immediately goes stale | M | M | Phase 4 re-derives the seed from a fresh live run at implementation time, not from the research report's list nor from `shell-script-testing.md`'s prose, and excludes any suite whose redness traces to uncommitted working-tree state |
| New files land in the source store but are not deployed because `manifest.json`'s `provides` array was not updated | M | M | Phases 3 and 4 each include the `manifest.json` `provides` addition in their own file list and verification |
| Editing `.claude/**` instead of the source store, silently wiped on next regeneration | H | L | Every phase's file list is source-store-rooted; `.claude/scripts/tests/run-all.sh` was confirmed gitignored and byte-identical to source |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 5 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 2, 3 |
| 4 | 6 | 2, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Clear the shared stale-fixture bug (3 red suites) [COMPLETED]

**Goal**: Turn `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`, and
`test-orchestrate-recover-message-findings.sh` green by supplying the `lib/` dependency their
synthetic sandboxes fail to copy, and decide whether to make that class of drift structurally
impossible.

**Tasks**:
- [x] Reproduce: run each of the three suites standalone from the source store and confirm the
      failure text is `shared library return-meta-status-vocabulary.sh not found` in each. *(completed)*
- [x] Confirm `agent-system/extensions/core/scripts/lib/return-meta-status-vocabulary.sh` exists
      and is the dependency `orchestrate-cycle-postflight.sh` actually sources. *(completed)*
- [x] Decide between (a) adding the filename to each suite's hardcoded `LIBS` list and
      `require_file` loop, and (b) replacing the three hardcoded lists with the glob-copy pattern
      already used at `tests/test-force-phases.sh:106`
      (`cp "$CORE_DIR"/lib/*.sh "$WORKDIR/.claude/scripts/lib/"`). Prefer (b) if it does not
      materially slow the sandbox setup or pull in a lib that changes suite behavior; record the
      rationale either way in the commit message. *(completed: chose (b) glob-copy; lib/ is only 16 files/188K, no material slowdown)*
- [x] Apply the chosen fix to all three suites. Note the copy-list in
      `test-handoff-dispatch-identity.sh` is at lines ~90-93, in
      `test-orchestrate-context-growth.sh` at the `LIBS=(...)` array feeding lines ~79 and ~93,
      and in `test-orchestrate-recover-message-findings.sh` at lines ~257-262. *(completed)*
- [x] If (a) is chosen, record the recurring-drift risk in a comment at each site naming the
      glob-copy alternative, so the next occurrence is not re-diagnosed from scratch. *(deviation: skipped — (b) glob-copy was chosen instead of (a), so this task does not apply)*
- [x] Re-run each of the three suites standalone and confirm all cases pass. *(completed: 8/8, 6/6, 23/23 passed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that exactly one missing library
(`return-meta-status-vocabulary.sh`) accounts for all failing cases in all three suites, and that
no second missing dependency is hiding behind the first. Confirm by running each suite standalone
to completion after the fix and checking the full case tally is green — not merely that the
original error string disappeared.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - add the missing lib to the sandbox copy-list and `require_file` loop, or switch to glob-copy
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` - same, in its `LIBS` array
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh` - same, in its e2e-case sandbox setup

**Verification**:
- Each of the three suites exits 0 when run standalone from the source store.
- `grep -c 'return-meta-status-vocabulary' ` on each file returns a non-zero count, or the file
  now uses the glob-copy form.
- No other suite's behavior changes (these three are self-contained sandbox builders).

---

### Phase 2: End-of-run failure roster in run-all.sh [NOT STARTED]

**Goal**: Collect failing suite names into a consolidated block printed immediately before the
final tally line, on both the sequential and parallel code paths, without perturbing the existing
inline `[FAIL] <path>` contract.

**Tasks**:
- [ ] Introduce a `FAILED_SUITE_NAMES=()` array alongside `FAIL_COUNT` (declared near line 220).
- [ ] Append the suite path at both existing failure sites: the sequential branch (line ~257,
      `echo "[FAIL] $suite_name"`) and the parallel branch (line ~445, `echo "[FAIL] $suite"`).
- [ ] Print the roster immediately before the final tally at line ~462, guarded by
      `[ "${#FAILED_SUITE_NAMES[@]}" -gt 0 ]`. Emit it unconditionally — **not** suppressed by
      `--quiet` — matching the inline `[FAIL]` line's existing posture.
- [ ] **Critical output-contract constraint**: the roster MUST NOT contain the literal token
      `[FAIL]` anywhere. `verify-deploy.sh` Gate 8 folds every `grep -F '[FAIL]'` hit into a
      `FINDING gate8` row, so a roster carrying that token would silently double every gate-8
      finding. Use a header of the form `[run-all] Failing suites (N):` followed by one
      `    <suite path>` line per entry.
- [ ] Update `run-all.sh`'s header comment block (the machine-greppable output contract around
      lines 82-84) to document the roster block alongside the existing `[FAIL] <suite path>` line,
      and state the no-`[FAIL]`-token constraint and why.
- [ ] Confirm the `--timings` aggregate row and the exit-code logic at lines ~465-470 are
      unchanged.
- [ ] Sanity-run: `bash run-all.sh --jobs 1` and `bash run-all.sh --jobs 4` against the existing
      tree and confirm the roster's entries match the inline `[FAIL]` lines exactly, on both paths.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that `run-all.sh` has exactly two failure-echo sites
(lines ~257 sequential, ~445 parallel) and exactly two downstream consumers of its stdout
contract (`verify-deploy.sh` Gate 8's `grep -F '[FAIL]'`, and `deploy_findings_snapshot` which
consumes Gate 8's output transitively). Confirm at implementation time by
`grep -n '\[FAIL\]' ` across the whole source store — not just `core/scripts/` — before editing,
and enumerate any additional consumer found.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - add `FAILED_SUITE_NAMES` array, append at both failure sites, print roster before the tally, update the header output-contract comment

**Verification**:
- A run with known failures prints one `[run-all] Failing suites (N):` header whose N matches the
  tally line's `failed` count, followed by exactly N indented paths.
- `bash run-all.sh --jobs 1` and `--jobs 4` produce identical roster content for the same tree.
- `grep -c -F '[FAIL]'` over a run's full output equals the failing-suite count (not 2x it).
- `bash verify-deploy.sh --findings --only-gate 8` produces the same number of `FINDING gate8`
  rows as before the change.

---

### Phase 3: Regression test for the naming + roster contract [NOT STARTED]

**Goal**: Add the dispatch's explicitly required regression test: a deliberately-failing fixture
suite must be named both inline and in the roster, so the "zero `[FAIL]` markers" symptom can
never silently return.

**Tasks**:
- [ ] Create `tests/test-run-all-failure-reporting.sh`, following the synthetic-fixture-directory
      pattern already established by `tests/test-run-all-parallel.sh` (build a temp tests dir
      containing a small set of trivially-passing suites plus one deliberately-failing suite, then
      invoke the real `run-all.sh` against it).
- [ ] Case: the deliberately-failing fixture's path appears in an inline `[FAIL] <path>` line.
- [ ] Case: the same path appears in the end-of-run roster block.
- [ ] Case: the roster header's count matches the tally line's `failed` count.
- [ ] Case (double-count guard): the total count of `[FAIL]` token occurrences in the output
      equals the number of failing fixtures — proving the roster did not reintroduce the token.
- [ ] Case: both assertions hold under `--quiet` (the naming contract is explicitly not
      `--quiet`-suppressed).
- [ ] Case: both assertions hold under `--jobs 3` (parallel path parity).
- [ ] Case: an all-passing fixture set prints no roster block at all and exits 0.
- [ ] Make the file executable (`chmod +x`) — `run-all.sh` skips non-executable suites with a
      `[SKIP]`, so a missing exec bit would make this test silently never run.
- [ ] Add `tests/test-run-all-failure-reporting.sh` to `manifest.json`'s `provides` array
      (alongside the other `tests/*.sh` entries around lines 177-250) so it deploys.
- [ ] Run the new suite standalone; confirm it passes and that it genuinely fails if the roster
      code from Phase 2 is temporarily reverted.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that `test-run-all-parallel.sh`'s fixture-construction
pattern is directly reusable here and that the new suite runs fast enough to stay out of the
load-sensitive class. Confirm by timing the new suite standalone; if it exceeds a couple of
seconds, add a `basename,wall_ms` row to `tests/suite-cost-hints.txt` rather than leaving it
unhinted.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` - new regression suite (create, chmod +x)
- `agent-system/extensions/core/manifest.json` - add the new suite to the `provides` array
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - conditional: add a cost row only if the new suite is slow enough to matter for scheduling

**Verification**:
- `bash tests/test-run-all-failure-reporting.sh` exits 0 and all cases report PASS.
- Temporarily reverting Phase 2's roster print makes the roster cases fail loudly (proving the
  test is not vacuously green).
- `jq -r '.provides[] | select(contains("failure-reporting"))' manifest.json` returns the entry.

---

### Phase 4: Committed known-failing baseline manifest [NOT STARTED]

**Goal**: Introduce a checked-in, machine-readable quarantine manifest and have `run-all.sh`
classify each failure as EXPECTED or NEW, so a run can report `8 failed, 8 expected, 0 NEW` and a
caller can gate on NEW only.

**Tasks**:
- [ ] Take a fresh full run (`bash run-all.sh --jobs auto`) **after** Phase 1 has landed, and
      derive the current failing set from the new roster block. Do not transcribe the research
      report's list or `shell-script-testing.md`'s prose list — research established both are
      stale relative to a live run.
- [ ] Create `tests/known-failures.txt`, mirroring `suite-cost-hints.txt`'s conventions exactly:
      basename-keyed (not full path, since discovery paths differ between source-store and
      deployed mode), `#` comments, blank lines ignored, and a header stating that the file is
      advisory, human-reviewed, optional, and that a missing or truncated file must never change
      which suites run.
- [ ] Row format: `basename|category|reason|owner`, where `category` is one of
      `real-defect` / `intermittent` / `load-sensitive` / `wip-transient`, and `owner` is a task
      reference or the literal `needs-owner`.
- [ ] Seed rows (subject to the fresh-run re-derivation above):
      `test-gate-out-repair-reporting.sh` (real-defect — `SKILL_VALIDATE_FIXES` /
      `SKILL_VALIDATE_FIXED_FILES` do not accumulate across multi-file aggregation and are not
      reset between calls in `validate-artifact.sh`);
      `test-lint-json-channel-discipline.sh` (real-defect — `typst/scripts/chapter-quality-check.sh`
      captures output with `2>&1` then consumes it as JSON/NDJSON);
      `test-verify-deploy-context-budget.sh` (real-defect — live Gate 20 findings:
      `skills/skill-orchestrate/SKILL.md` over its 20000 B ceiling and the eager-load total over
      its recorded baseline);
      `test-run-all-parallel.sh` (intermittent — case3's relative-timing assertion under heavy
      ambient host load; documented and accepted by task 261).
      Exclude `typst/scripts/tests/test-typst-element-lint.sh` if its redness still traces to
      uncommitted working-tree state; if it is committed-red by implementation time, add it as
      `real-defect`.
- [ ] Every row must carry an owner or the explicit `needs-owner` marker. For each `needs-owner`
      row, record in the plan's summary that a follow-up task should be spawned; do not silently
      leave a real defect unowned.
- [ ] Teach `run-all.sh` to read `$SCRIPT_DIR/known-failures.txt` optionally, following
      `COST_HINTS_FILE`'s existing shape (lines ~341-348): `[ -f "$FILE" ]` guard, read loop,
      skip comments and blanks. A missing file must degrade to today's behavior exactly.
- [ ] Classify each entry in `FAILED_SUITE_NAMES` (Phase 2's array) by basename against the
      manifest, and extend the final tally line to
      `[run-all] N passed, M failed (E expected, X NEW), S skipped, T total`. Keep the leading
      `N passed, M failed` prefix byte-identical so any existing consumer parsing the head of
      that line is unaffected.
- [ ] Annotate the roster block: mark each roster entry EXPECTED or NEW.
- [ ] Add an opt-in `--fail-on-new` flag (or equivalent) that exits non-zero only when `X > 0`.
      **Do not change the default exit-code semantics** — default stays "exit 1 if
      `FAIL_COUNT > 0`", so no existing caller's behavior shifts.
- [ ] Add `tests/known-failures.txt` to `manifest.json`'s `provides` array (next to
      `tests/suite-cost-hints.txt` at line ~254).
- [ ] Extend `tests/test-run-all-failure-reporting.sh` with manifest cases: a fixture-local
      manifest classifying one failing fixture as expected yields `(1 expected, 0 NEW)`; an
      unlisted failing fixture yields NEW; a missing manifest file leaves the tally and exit code
      exactly as before; `--fail-on-new` exits 0 when all failures are expected and non-zero when
      any is NEW.

**Timing**: 2 hours

**Depends on**: 1, 2, 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that the post-Phase-1 failing set is exactly 5 suites
(the 8 named in the dispatch, minus the 3 that Phase 1 clears) and that 4 of those 5 belong in
the manifest with the 5th excluded as WIP-transient. Confirm by the fresh full run required in
this phase's first task — the seed list above is a prediction from the research pass, not a fact,
and the run's roster block is the authority.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - new advisory manifest (create), seeded from a fresh live run
- `agent-system/extensions/core/scripts/tests/run-all.sh` - optional manifest read, EXPECTED/NEW classification, extended tally and roster annotation, opt-in `--fail-on-new`, header-comment documentation
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` - add manifest-classification cases
- `agent-system/extensions/core/manifest.json` - add `tests/known-failures.txt` to `provides`

**Verification**:
- A full run reports `(E expected, X NEW)` with `E` equal to the manifest row count that matched
  and `X` equal to 0 on an unmodified tree.
- Deleting or truncating `known-failures.txt` leaves the suite set, the pass/fail counts, and the
  exit code identical to pre-change behavior.
- `--fail-on-new` exits 0 on a tree whose only failures are manifest-listed.
- `bash tests/test-run-all-failure-reporting.sh` exits 0 with the new cases included.
- Every manifest row has a non-empty owner field or the literal `needs-owner`.

---

### Phase 5: Stop redeploy-checkpoint Gate 8 amplification [NOT STARTED]

**Goal**: Remove the redundant full-105-suite runs the orchestrator's own checkpoints trigger
2-3 times per cycle, by passing `--skip-slow` to the `deploy_findings_snapshot()` call sites —
the single highest-leverage wall-clock fix, requiring no change to `run-all.sh` itself.

**Tasks**:
- [ ] Confirm `verify-deploy.sh --skip-slow` defers exactly Gate 8 and no other gate (lines
      ~551-552 and the header note at ~789-790 state gate 8 only).
- [ ] Add `--skip-slow` to the three `deploy_findings_snapshot` calls in
      `orchestrate-cycle-plan.sh` (lines ~904 pre-redeploy, ~944 post-redeploy, ~985 confirm).
      `deploy_findings_snapshot` already forwards `[extra args...]` — no library change needed.
- [ ] Add `--skip-slow` to the two calls in `command-gate-out.sh` (lines ~189 pre, ~202 post).
- [ ] **Symmetry requirement**: within each file, the pre- and post-snapshot calls must carry
      identical flags, or the `deploy_baseline_new_findings` `comm -13` diff will report every
      gate-8 finding as spuriously new or spuriously resolved. Verify pairwise at each site.
- [ ] Record the trade-off in a comment at each call site: the checkpoint's job is NEW-finding
      detection relative to its own pre-redeploy baseline, and the dispatched agent's own phase
      gate already ran the full suite immediately prior; a redeploy cannot introduce a shell-test
      regression that the agent-side gate would not already have caught.
- [ ] Check `tests/test-orchestrate-cycle-plan.sh` (around line ~1131, which references the
      `deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh"` call shape) and any lint asserting
      that shape; update the expectation to the new flagged form if it pins the exact string.
- [ ] Measure: time one `deploy_findings_snapshot` invocation before and after, and record both
      numbers in the implementation summary so the wall-clock claim is evidenced rather than
      asserted.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The hypothesis is that there are exactly five `deploy_findings_snapshot`
call sites that actually execute (three in `orchestrate-cycle-plan.sh`, two in
`command-gate-out.sh`), the rest of the `grep` hits being comments, the library definition, and
test fixtures. Confirm by re-running
`grep -rn 'deploy_findings_snapshot' agent-system/extensions/core/scripts/` and classifying every
hit as call site / definition / comment / test before editing.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - add `--skip-slow` to the three redeploy-checkpoint snapshot calls, with rationale comments
- `agent-system/extensions/core/scripts/command-gate-out.sh` - add `--skip-slow` to the two postflight completion-deploy-gate snapshot calls, with rationale comments
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - conditional: update only if it asserts the exact unflagged call string

**Verification**:
- `grep -n 'deploy_findings_snapshot' ` on both scripts shows every executing call site carrying
  `--skip-slow`, and pre/post pairs matching within each file.
- `bash tests/test-orchestrate-cycle-plan.sh`, `bash tests/test-deploy-baseline-lib.sh`, and
  `bash tests/test-gate-out-repair-reporting.sh` behave no worse than their pre-change baseline
  (the last is a manifest-quarantined suite — compare its failing-case list before and after, not
  its exit code).
- A timed `deploy_findings_snapshot` call shows a materially reduced wall time versus the
  pre-change measurement, with both numbers recorded.

---

### Phase 6: Documentation reconciliation [NOT STARTED]

**Goal**: Make the new manifest the single source of truth for known-failing suites, retire the
duplicated prose list that research found stale, and document the roster contract and the
checkpoint trade-off where a future reader will look.

**Tasks**:
- [ ] In `context/standards/shell-script-testing.md`, replace the "Known pre-existing failures
      and flakes" prose list with a pointer to `scripts/tests/known-failures.txt` as the source of
      truth, keeping only the explanation of what the categories mean and how to add or retire a
      row. Research established that maintaining two copies of this fact is exactly the drift
      mechanism that produced the stale list.
- [ ] Document the end-of-run roster in the same file's output-contract discussion, including the
      no-`[FAIL]`-token constraint and why Gate 8 depends on it.
- [ ] Document the `--fail-on-new` opt-in and its non-default exit semantics.
- [ ] Document the redeploy-checkpoint `--skip-slow` decision and its trade-off, cross-referencing
      `context/patterns/batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint"
      subsection if that is where the checkpoint's contract lives.
- [ ] Verify the `index-entries.json` entry for `standards/shell-script-testing.md` (line ~1862)
      still describes the file accurately after the edit; update its summary/keywords if the
      pointer change makes them wrong.
- [ ] Confirm no task-number references leak into any file outside `specs/**` (the manifest's
      `owner` field uses durable references, and any task number there is inside
      `agent-system/extensions/**` — use a durable anchor such as the defect description and the
      owning script's path rather than a bare task number).

**Timing**: 0.75 hours

**Depends on**: 2, 4, 5

**Verification Tier**: prose

**Commit Mode**: per-substep

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - retire the duplicated prose failure list in favor of a manifest pointer; document the roster, `--fail-on-new`, and the checkpoint `--skip-slow` decision
- `agent-system/extensions/core/index-entries.json` - conditional: refresh the entry for `standards/shell-script-testing.md` only if the edit makes its summary or keywords inaccurate

**Verification**:
- `shell-script-testing.md` no longer enumerates individual failing suite names; it points at
  `scripts/tests/known-failures.txt`.
- `bash scripts/check-task-references.sh` (or the repo-wide task-reference lint) reports no new
  violations outside `specs/**`.
- `bash scripts/tests/test-index-entries-schema.json`-equivalent suite
  (`tests/test-index-entries-schema.sh`) still passes if `index-entries.json` was touched.

---

## Testing & Validation

- [ ] The three Phase-1 suites each exit 0 standalone.
- [ ] `tests/test-run-all-failure-reporting.sh` exits 0, covering: inline naming, roster presence,
      roster/tally count agreement, the `[FAIL]`-token double-count guard, `--quiet` parity,
      `--jobs N` parity, empty-roster-on-green, manifest EXPECTED/NEW classification, missing-manifest
      degradation, and `--fail-on-new` semantics.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs auto` reports
      `(E expected, 0 NEW)` on an unmodified post-implementation tree.
- [ ] `bash agent-system/extensions/core/scripts/verify-deploy.sh --findings --only-gate 8`
      produces the same `FINDING gate8` row count as before the change (no double-counting).
- [ ] Deleting `tests/known-failures.txt` and `tests/suite-cost-hints.txt` changes neither the
      suite set, the pass/fail counts, nor the default exit code.
- [ ] `bash tests/test-orchestrate-cycle-plan.sh` and `bash tests/test-deploy-baseline-lib.sh`
      pass after the Phase-5 flag change.
- [ ] No file under `.claude/**` was hand-edited (`git status` shows changes only under
      `agent-system/extensions/**` and `specs/**`).
- [ ] Before/after `deploy_findings_snapshot` timings recorded in the implementation summary.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/run-all.sh` (modified: roster, manifest
  classification, `--fail-on-new`, header contract docs)
- `agent-system/extensions/core/scripts/tests/known-failures.txt` (new)
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` (modified)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh` (modified)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (modified)
- `agent-system/extensions/core/scripts/command-gate-out.sh` (modified)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (modified)
- `agent-system/extensions/core/manifest.json` (modified: two `provides` additions)
- `specs/283_test_harness_name_failures_baseline_wall_clock/summaries/01_*-summary.md`
  (implementation summary, including before/after timings and any `needs-owner` manifest rows
  requiring a follow-up task)

## Rollback/Contingency

Every phase is independently revertible and each lands as its own scoped commit, so the normal
contingency is `git revert` of the offending commit — no working-tree discard is needed.

Phase-specific fallbacks:

- **Phase 2/4 (run-all.sh)**: the riskiest surface, because Gate 8 parses its stdout. If the
  roster or the extended tally line breaks Gate 8's finding count, revert that single commit;
  the inline `[FAIL]` contract that existed before this task is untouched by every other phase,
  so Gate 8 returns to working immediately.
- **Phase 4 (manifest)**: the manifest is advisory and optional by construction. Deleting
  `tests/known-failures.txt` restores pre-change reporting without any code change — this is the
  designed escape hatch, not a workaround.
- **Phase 5 (`--skip-slow`)**: dropping the flag from the five call sites restores the previous
  (slow, thorough) checkpoint behavior. If a new shell-test regression is ever traced to a
  checkpoint that skipped Gate 8, revert this phase and instead scope the flag to only those call
  sites that can prove an agent-side full-suite gate immediately preceded them.

If a genuine whole-tree rollback of uncommitted work becomes necessary mid-phase, follow
`context/contracts/recovery.md`'s rollback rung for the correct `git-snapshot.sh` invocation
shape, including its out-of-scope override flag — do not invoke a bare default-mode snapshot as a
routine precaution. For an ordinary defensive checkpoint before the Phase 2 or Phase 4
`run-all.sh` edits, use `git-snapshot.sh <task-number> --no-revert`, which is durable without
reverting the working tree.
