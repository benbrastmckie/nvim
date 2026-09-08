# Implementation Plan: Task #180

- **Task**: 180 - Make the post-deploy consumer-freshness scan opt-in
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: None (no research report; see "Research Integration" below)
- **Artifacts**: plans/01_consumer-freshness-scan-opt-in.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`deploy-headless.sh`'s post-deploy block unconditionally walks every repo in the known-consumer
registry (~50 repos) via `check-consumer-freshness.sh --stale-only`, printing per-consumer
STALE/CANNOTVERIFY rows plus a `CONSUMERS_STALE=<n>` marker. The walk is report-only by explicit
design — it can never change the exit code — yet it sits on the critical path of the
`/orchestrate` inter-cycle redeploy checkpoint, which no caller reads it from. This plan gates
the walk behind a new, explicit, default-OFF `--consumer-report` flag on `deploy-headless.sh`,
leaving the emitted output byte-identical when the flag IS passed, and leaves the deploy's
verification path (the part that can change the verdict) completely untouched.

### Research Integration

No research report exists for this round, and none was requested: the task description is a
specification, not an open question — it names the defect, the exact file and code block, the
work list (A/B/C), and the acceptance bar. Direct codebase reads during planning confirmed every
factual claim it makes and resolved the three questions that would otherwise have needed
investigation:

1. **The scan site is exactly where the description says it is.**
   `agent-system/extensions/core/scripts/deploy-headless.sh` lines 395-425, the
   `--- Post-deploy stale-consumer report (TIER 3, additive output only)` block. It runs strictly
   after `verify_rc` is fixed, guarded on the deployed checker existing, with its own exit code
   absorbed by `|| true`.
2. **No caller reads `CONSUMERS_STALE=`.** A repo-wide grep for `CONSUMERS_STALE` outside
   `.claude/**` and `specs/**` returns only `deploy-headless.sh` itself plus prose in
   `context/patterns/regeneration-is-manual-only.md` and archived task artifacts. The three
   automated `deploy-headless.sh` callers —
   `scripts/orchestrate-cycle-plan.sh:588` (the redeploy checkpoint),
   `scripts/command-gate-out.sh:176` (the gate-out redeploy trigger), and
   `.github/workflows/check-extension-docs.yml:69` (CI) — all read only the exit code and the
   `RESULT=`/`FINDING` vocabulary. Work item C therefore resolves to "no caller needs the flag
   passed"; this is a hypothesis to re-confirm at implementation time (see Phase 1).
3. **`verify-deploy.sh` does not invoke the consumer scan at all.** The description's
   "some flag plumbing may also touch verify-deploy.sh" is a hedge that the code does not bear
   out — `check-consumer-freshness` appears nowhere in `verify-deploy.sh`. It is referenced there
   only in the sense that `verify-deploy.sh` supplies the *flag convention* to imitate.

One planning judgment call, recorded here rather than deferred: the flag is named
`--consumer-report`. `verify-deploy.sh`'s convention that the description points at is a
*semantic* convention ("always explicit, never derived. Default OFF" — verify-deploy.sh:32,
describing `--minimal-init`), not a naming scheme, so the name is a free choice. `--consumer-report`
names what the flag produces (a report) rather than what it suppresses, keeping the default the
quiet one, and it does not collide with `check-consumer-freshness.sh`'s own `--stale-only` /
`--discover` vocabulary.

### Prior Plan Reference

No prior plan for this task. The closest precedent is archived task 152's plan
(`specs/archive/152_decouple_stale_declarations_from_deploy_gating/plans/01_decouple-stale-declarations.md`),
which introduced the `RESULT=`/`CONSUMERS_STALE=` marker vocabulary this task must preserve. Its
lesson, adopted here: assertions about the consumer block's exit-code neutrality were confirmed
at *runtime* with `bash -x` against the real populated registry, not by static reading alone —
Phase 4 repeats that discipline for the new flag.

### Roadmap Alignment

No `specs/ROADMAP.md` exists in this repository; no roadmap flag was set on this dispatch. No
roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Add an explicit, default-OFF `--consumer-report` flag to `deploy-headless.sh` that gates the
  entire post-deploy consumer-freshness block.
- Keep the flag-ON output byte-identical to today's output, including the exact
  `[deploy-headless] CONSUMERS_STALE=<n>` line and the stream it is written to.
- Remove the ~50-repo walk from the default (and therefore from the `/orchestrate` inter-cycle
  redeploy checkpoint and `command-gate-out.sh`) critical path.
- Keep the scan's exit-code neutrality intact in both modes.
- Keep `deploy-headless.sh --help` accurate (its help text is a line-range `sed`, which the
  header edit will shift).

**Non-Goals**:
- Changing `check-consumer-freshness.sh` itself. It is already an explicitly-invoked,
  operator-facing audit script and needs no modification.
- Changing `verify-deploy.sh`. Confirmed it never invokes the consumer scan; it contributes only
  the flag convention being imitated.
- Removing, weakening, deferring, or reordering any gate that can change the deploy verdict.
  This task removes *reporting* from the blocking path, never *verification*.
- Flipping the flag ON at any existing call site. If Phase 1 finds a caller that genuinely
  depends on the scan, the remedy is to pass the flag there, not to change the default.
- Making the scan asynchronous, backgrounded, cached, or incremental. Opt-in is the whole change.
- Any edit under `.claude/**`, which is a regenerated deploy artifact
  (see `rules/source-store-deploy-boundary.md`).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| An unaudited caller silently loses the `CONSUMERS_STALE=` signal it depended on | M | L | Phase 1 is a dedicated caller audit across the source store, workflows, and docs before any code edit; its finding is recorded in the phase, and any real dependent gets the flag passed explicitly |
| The header edit shifts the `sed -n '2,91p'` help range, so `--help` truncates or over-prints | L | H | Phase 2 explicitly recalculates and updates the range as a numbered sub-step, and Phase 3 adds a `--help` assertion |
| Flag-ON output drifts from today's output (spacing, blank line, stream, marker text) | M | M | Phase 4 captures a pre-change reference capture of the block's output and diffs the flag-ON run against it byte-for-byte |
| Self-overwrite hazard: `deploy-headless.sh`'s single-`main()` structure is disturbed by editing inside it | H | L | The edit is confined to the existing `main()` body and its `while`-loop case block; the header's SELF-OVERWRITE HAZARD note is re-read before editing, and no logic moves to top level |
| Editing `.claude/scripts/deploy-headless.sh` instead of the source store, so the change is wiped by the next regeneration | M | M | Every phase names the `agent-system/extensions/core/**` path explicitly; Phase 4 confirms the change survives a redeploy |
| Doc prose asserting the scan runs "after every non-dry-run deploy" is left stale, misleading a future reader | L | H | Phase 5 updates all three identified prose sites |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Caller audit and cost baseline [COMPLETED]

**Goal**: Confirm, before any edit, that no caller depends on the scan running unconditionally,
and capture the two baselines (output bytes, wall-clock cost) that later phases verify against.

**Tasks**:
- [x] Re-run the caller audit: grep for `CONSUMERS_STALE` and `check-consumer-freshness` across
      the repository excluding `.claude/**` and `specs/**`. Record every hit and classify each as
      (a) the scan site itself, (b) prose/documentation, or (c) a genuine programmatic consumer.
      *(completed: only hits outside .claude/**+specs/** are deploy-headless.sh itself (a),
      check-consumer-freshness.sh + its test file (a, the scanner), and three prose docs
      (regeneration-is-manual-only.md, utility-scripts-inventory.md, ci-deploy-tree-bootstrap.md)
      (b). Zero (c) hits.)*
- [x] Inspect each of the three known automated `deploy-headless.sh` call sites and record what
      each actually parses from the output: `scripts/orchestrate-cycle-plan.sh` (~line 588),
      `scripts/command-gate-out.sh` (~line 176), and `.github/workflows/check-extension-docs.yml`
      (~line 69). *(completed: all three read only the exit code / RESULT-FINDING vocabulary;
      none greps for STALE or CONSUMERS_STALE)*
- [x] If any call site IS a genuine consumer, record it here and note that Phase 2 must pass
      `--consumer-report` at that site rather than change the default.
      *(completed: no genuine consumer found; Scope Hypothesis confirmed, default may change)*
- [x] Capture a byte-exact reference of today's consumer-block output by running
      `bash agent-system/extensions/core/scripts/check-consumer-freshness.sh --stale-only`
      and saving stdout+stderr to a scratch file outside the repo.
      *(completed: saved to scratchpad phase1_reference_capture.log)*
- [x] Time that same invocation (`time`, or wrap in `date +%s`) and record the wall-clock cost
      and the row count, so "the checkpoint's cost drops by the scan's share" has a number.
      *(completed: 35 rows, ~2s wall clock, exit 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Planning-time greps found exactly three automated `deploy-headless.sh`
callers and ZERO programmatic readers of `CONSUMERS_STALE=`. Both counts are hypotheses.
Confirm by re-running the greps above and reading each call site; if a fourth caller or a real
`CONSUMERS_STALE` consumer appears, record it and adjust Phase 2's task list before editing.

**Files to modify**:
- None (read-only audit; findings are recorded in this plan's phase checkboxes and carried into
  the implementation summary)

**Verification**:
- Every `CONSUMERS_STALE` / `check-consumer-freshness` hit outside `.claude/**` and `specs/**` is
  classified, with the classification written down.
- A reference capture file of today's `--stale-only` output exists, and its row count and
  wall-clock timing are recorded.

---

### Phase 2: Gate the scan behind `--consumer-report` in `deploy-headless.sh` [COMPLETED]

**Goal**: Add the explicit, default-OFF flag and wrap the post-deploy consumer block in it,
changing nothing about the block's internals, its stream, or its exit-code neutrality.

**Tasks**:
- [x] Re-read `deploy-headless.sh`'s SELF-OVERWRITE HAZARD header note before editing. All new
      logic goes inside the existing `main()` body; nothing moves to top level.
      *(completed: all edits confined inside main())*
- [x] Declare `local CONSUMER_REPORT=false` alongside the existing `DRY_RUN`/`WIPE`/`TARGET`/
      `MINIMAL_INIT_DIR` locals at the top of `main()`. *(completed)*
- [x] Add `--consumer-report) CONSUMER_REPORT=true; shift ;;` to the `while [ $# -gt 0 ]` case
      block, placed with the other boolean flags (`--dry-run`, `--wipe`) and BEFORE the `-*`
      unknown-flag catch-all. *(completed)*
- [x] Update the inline usage string in the `-*` unknown-flag branch to include
      `[--consumer-report]`. *(completed)*
- [x] Wrap the post-deploy consumer block's existing guard as
      `if [ "$CONSUMER_REPORT" = "true" ] && [ -f "$consumer_checker" ]; then` (or an equivalent
      outer `if`), so that with the flag OFF the block is skipped in its entirety — no walk, no
      per-consumer rows, and no `CONSUMERS_STALE=` line. Do NOT alter any statement inside the
      block: the `|| true`, the `grep -c .` count, the blank `echo ""`, the three human-readable
      lines, and the `[deploy-headless] CONSUMERS_STALE=${consumer_stale_count}` line stay
      byte-identical, on the same stream (stdout) they use today.
      *(completed: guard updated exactly as specified; internal statements untouched, only the
      leading block comment was updated for accuracy)*
- [x] Confirm `verify_rc` is still assigned strictly before this block and never reassigned
      inside or after it, and that the final `exit "$verify_rc"` path via
      `_dh_result_and_exit` is untouched. *(completed: confirmed via grep -n verify_rc; last
      assignment at line 412, block starts at 415, exit path unchanged)*
- [x] Update the header: add `--consumer-report` to the "Two modes"/flag documentation block and
      to the `# Usage:` lines, following `verify-deploy.sh:32`'s "always explicit, never derived.
      Default OFF: absent this flag, behavior is byte-for-byte unchanged" phrasing. *(completed)*
- [x] Update the header's `Machine-readable marker vocabulary` block: `CONSUMERS_STALE=<n>` is no
      longer "always printed by a non-dry-run, non-`--help` invocation" — it is now printed only
      under `--consumer-report` (and, as before, only when the deployed checker exists). Correct
      that sentence rather than leaving it stale. *(completed)*
- [x] Update the header's THREE CONFOUNDS paragraph so its description of the third confound
      states the scan is opt-in, while keeping its exit-code-neutrality claim intact. *(completed)*
- [x] Recalculate the `-h|--help` line range: the branch currently runs
      `sed -n '2,91p' "$0"`, and line 91 is the blank comment line closing the `# Exit codes:`
      block. After the header grows, find the new line number of that same boundary and update
      the `sed` range to match. Do not guess — read the file and count.
      *(completed: boundary moved from line 91 to line 101 after the 10 added header lines;
      range updated to `2,101p` and verified against actual `--help` output)*
- [x] `bash -n agent-system/extensions/core/scripts/deploy-headless.sh` (syntax clean).
      *(completed: SYNTAX OK)*
- [x] If Phase 1 identified a genuine dependent caller, add `--consumer-report` to that one call
      site explicitly, with a one-line comment saying why. *(completed: N/A — Phase 1 found no
      genuine dependent caller, so no call site was changed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the change is confined to ONE file
(`agent-system/extensions/core/scripts/deploy-headless.sh`) and touches no verification logic.
Confirm at implementation time with `git diff --stat` showing exactly one file changed, and by
reading the diff to check that no hunk falls inside the `verify-deploy.sh` invocation block or
the `verify_rc` assignment.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` - new `--consumer-report` flag
  (local, case branch, usage string), the post-deploy consumer block wrapped in the flag guard,
  header flag/marker/confound documentation updated, `--help` `sed` range recalculated

**Verification**:
- `bash -n` clean.
- `bash agent-system/extensions/core/scripts/deploy-headless.sh --help` prints the full header
  through the exit-code block with no truncation and no leakage of post-header lines, and names
  `--consumer-report`.
- An unknown-flag run still exits 1 with `RESULT=not_landed` and the updated usage string.
- Reading the diff: no hunk touches the `verify-deploy.sh` call, `VERIFY_ARGS`, `verify_rc`, or
  either `_dh_result_and_exit` terminal branch.

---

### Phase 3: Regression cases in `test-deploy-verify-wiring.sh` [COMPLETED]

**Goal**: Lock the new default-OFF/opt-in contract into the existing fixture-driven suite so a
future edit cannot silently restore the unconditional walk or break the marker.

**Tasks**:
- [x] Read `test-deploy-verify-wiring.sh`'s header, especially the ANTI-RECURSION INVARIANT: the
      fixture target is a throwaway consumer directory with no `agent-system/extensions` tree.
      Do not point any new case at this repo's root. *(completed: all new cases target the
      existing $FIXTURE, none point at the repo root)*
- [x] Add a case asserting `deploy-headless.sh --help` output contains `--consumer-report`.
      *(completed: Case 6)*
- [x] Add a case asserting an invocation with an unknown flag still reports the usage string and
      that the usage string now lists `--consumer-report`. *(completed: Case 7)*
- [x] Add static source assertions, in the style of the suite's existing Case 5: the source
      contains a `--consumer-report` case branch; the source initializes the flag to `false`
      (default OFF); the `CONSUMERS_STALE=` emission is inside a block guarded by the flag
      variable. *(completed: Case 8, four assertions)*
- [x] Add a case asserting `--consumer-report --dry-run` still prints `DRY RUN` and exits 0
      without printing the verification announcement or any `CONSUMERS_STALE=` line — the flag
      must not resurrect work on the dry-run path, which short-circuits before the block.
      *(completed: Case 9)*
- [x] Update the suite's header comment to say it also covers the `--consumer-report` opt-in
      contract. *(completed)*
- [x] Run the suite: `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh`
      and confirm all cases PASS. *(completed: 20 passed, 0 failed — required a redeploy first
      since find_script() prefers the deployed .claude/ copy, which had not yet picked up the
      source-store edit; ran the sanctioned default-mode deploy, not --wipe)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` to confirm
      `check-consumer-freshness.sh` itself is unaffected (it should be — no edits there).
      *(completed: 14 passed, 0 failed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes `test-deploy-verify-wiring.sh` is the correct and only
home for these cases, and that the new cases can be expressed without a real (nvim-dependent,
non-dry-run) deploy. Confirm by reading the suite's existing Case 4 and Case 5 patterns before
writing; if a real deploy turns out to be required for a case, drop that case to Phase 4's manual
runtime verification rather than weakening the suite's anti-recursion invariant.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` - new cases for the
  `--consumer-report` default-OFF/opt-in contract; header comment updated

**Verification**:
- `bash -n` clean on the suite.
- The suite exits 0 with the new cases reported as PASS.
- `test-consumer-freshness.sh` still exits 0.

---

### Phase 4: Runtime confirmation of both modes [COMPLETED]

**Goal**: Confirm at runtime — not by static reading — that a default run performs no consumer
walk, that a `--consumer-report` run reproduces today's output byte-for-byte, and that
exit-code neutrality holds in both modes.

**Tasks**:
- [x] Run the default mode against this repo:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh 2>&1 | tee <scratch>/default.log`.
      Confirm the log contains NO per-consumer STALE/CANNOTVERIFY rows, NO
      "Known consumer repos now stale" line, NO "Remedy:" line, and NO `CONSUMERS_STALE=` line.
      *(completed: RESULT=landed_verify_clean, exit 0; grep for CONSUMERS_STALE|STALE|
      CANNOTVERIFY|"Known consumer repos" returned 0 matches)*
- [x] Record the default run's wall-clock time and compare against Phase 1's recorded scan cost,
      so the saved share is a measured number rather than an assertion.
      *(completed: default run 111s total wall clock (includes the full nvim resync + 20-gate
      verify-deploy.sh, not just the removed scan); Phase 1's isolated scan cost was ~2s for 35
      rows. The redeploy checkpoint's savings equal that ~2s scan cost every cycle it now skips,
      confirming the scan was cheap in isolation but non-zero, and it no longer runs by default)*
- [x] Run the opt-in mode:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh --consumer-report 2>&1 | tee <scratch>/optin.log`.
      Confirm the consumer rows return and that the `[deploy-headless] CONSUMERS_STALE=<n>` line
      is present and byte-identical in form to Phase 1's reference capture (same prefix, same
      `=`, same count semantics). *(completed: RESULT=landed_verify_clean, exit 0,
      `[deploy-headless] CONSUMERS_STALE=34` present)*
- [x] Diff the consumer-block portion of `optin.log` against Phase 1's reference capture and
      confirm only the row set (which is live data) differs, never the framing lines.
      *(completed: framing lines — "Known consumer repos now stale relative to the source
      store:", "Remedy: run ... IN EACH stale repo ...", and the `CONSUMERS_STALE=<n>` line —
      are byte-identical in form; row count differs (35 -> 34, live registry drift between the
      Phase 1 and Phase 4 captures, not a framing change) and per-row content is live data by
      design)*
- [x] Confirm exit-code neutrality in both modes: record the exit code of each run and confirm
      the `RESULT=` marker on each run is consistent with that exit code, and that adding
      `--consumer-report` did not change the exit code relative to the default run of the same
      tree. (Both runs are expected to produce the same 0-or-3 verdict; a difference is a defect
      in this change, not an acceptable outcome.)
      *(completed: both runs exit 0 with RESULT=landed_verify_clean — identical verdict)*
- [x] Confirm the source-store change reached the deployed tree: after the deploy above, check
      that `.claude/scripts/deploy-headless.sh` contains the `--consumer-report` branch — i.e.
      the edit was made in the source store and survived regeneration.
      *(completed: `.claude/scripts/deploy-headless.sh` contains the
      `--consumer-report) CONSUMER_REPORT=true; shift ;;` case branch and all header updates)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes the two runs are safe to perform in this repo (each is
a real, non-destructive resync deploy, the sanctioned default mode — never `--wipe`). Confirm by
checking that neither command carries `--wipe` before running, and that the repo has no
uncommitted `.claude/` state worth preserving (it is gitignored and regenerable by design).

**Files to modify**:
- None (runtime verification; evidence is captured to scratch logs and summarized in the
  implementation summary)

**Verification**:
- `default.log`: zero occurrences of `CONSUMERS_STALE`, `STALE`, `CANNOTVERIFY`, and
  "Known consumer repos".
- `optin.log`: contains `[deploy-headless] CONSUMERS_STALE=` with an integer, plus the framing
  lines, matching the Phase 1 reference capture's structure.
- Both runs' exit codes recorded and equal to each other; each run's `RESULT=` marker consistent
  with its exit code.
- The deployed `.claude/scripts/deploy-headless.sh` carries the new flag.

---

### Phase 5: Documentation updates [NOT STARTED]

**Goal**: Update every prose site that currently asserts the scan runs unconditionally after
every deploy, so no future reader is misled about the new default.

**Tasks**:
- [ ] `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`, the
      "**Additive: a post-deploy consumer-freshness report.**" paragraph (~line 213): state that
      the call is now gated behind `deploy-headless.sh --consumer-report`, default OFF, and that
      it was moved off the blocking checkpoint path because it is report-only. Keep the
      exit-code-neutrality claim and the runtime-confirmation note intact.
- [ ] Same file, the "**The `RESULT=`/`CONSUMERS_STALE=` marker vocabulary**" section (~line 236):
      correct the `CONSUMERS_STALE=<n>` description to say it is emitted only under
      `--consumer-report`.
- [ ] Same file, the "**The post-deploy hook.**" paragraph (~line 373) under the Tier 3
      subsection: replace "after every non-dry-run deploy" with the opt-in condition.
- [ ] `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` (~line 23):
      update the `check-consumer-freshness.sh` entry, which currently says it is "guarded
      (`--stale-only || true`) from `deploy-headless.sh`'s trailing block after every deploy".
- [ ] `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` (~line 71):
      re-read the `check-consumer-freshness.sh` bullet; it already describes the script as "an
      opt-in whole-fleet audit", so update only if it now understates the deploy-side gating.
- [ ] Grep the source store once more for any remaining prose asserting the scan is
      unconditional, and fix or explicitly leave-as-correct each hit.
- [ ] Confirm no task-number references were introduced into any file outside `specs/**`
      (see `rules/no-task-references-in-deliverables.md`) — cite the flag name and file names,
      never a task number.

**Timing**: 0.5 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Planning-time greps identified exactly three prose files needing edits
(`regeneration-is-manual-only.md` at three sites, `utility-scripts-inventory.md`,
`ci-deploy-tree-bootstrap.md`). Confirm by re-running the grep for
`check-consumer-freshness\|CONSUMERS_STALE` across the source store and docs after the edits; any
remaining hit must be either corrected or consciously judged still-accurate.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - three
  paragraphs describing the post-deploy call as unconditional
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - the
  `check-consumer-freshness.sh` inventory entry
- `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md` - the
  `check-consumer-freshness.sh` bullet, if it now understates the gating

**Verification**:
- Every changed hunk lies inside markdown prose (diff read-through).
- No file outside `specs/**` contains a task-number reference introduced by this change.
- A final grep for `CONSUMERS_STALE` / `check-consumer-freshness` across the source store returns
  no prose that still claims the scan runs on every deploy.

---

## Testing & Validation

- [ ] `bash -n` clean on `deploy-headless.sh` and `test-deploy-verify-wiring.sh`.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` exits 0 with
      the new `--consumer-report` cases passing.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-consumer-freshness.sh` exits 0
      (unchanged script, unchanged behavior).
- [ ] A default `deploy-headless.sh` run emits no consumer walk output and no `CONSUMERS_STALE=`
      line.
- [ ] A `--consumer-report` run reproduces the consumer rows and a byte-compatible
      `[deploy-headless] CONSUMERS_STALE=<n>` line.
- [ ] Both runs produce the same exit code as each other, and the same code the pre-change script
      produced against the same tree — exit-code neutrality preserved.
- [ ] `deploy-headless.sh --help` renders the complete header block with the new flag documented.
- [ ] Full gate set before task completion: `bash .claude/scripts/verify-deploy.sh` findings are
      no worse than the pre-change baseline.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/deploy-headless.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh`
- Modified: `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
- Modified: `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
- Possibly modified: `agent-system/extensions/core/context/patterns/ci-deploy-tree-bootstrap.md`
- Implementation summary: `specs/180_make_consumer_freshness_scan_opt_in/summaries/01_consumer-freshness-scan-opt-in-summary.md`
- Recorded evidence: the measured scan cost from Phase 1 and the two runtime logs from Phase 4

## Rollback/Contingency

The change is confined to a small number of source-store files with no schema, state, or
registry component, so rollback is a plain revert:

1. `git revert` the phase commits (or `git checkout <pre-change-sha> -- <the listed files>` from
   a clean tree — never on a dirty tree; see `rules/git-workflow.md`).
2. Re-run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate `.claude/`
   from the reverted source store.
3. Confirm the restored unconditional behavior with one default run that again emits
   `CONSUMERS_STALE=`.

Partial-failure contingency: if Phase 4's runtime check shows the flag-ON output has drifted from
the Phase 1 reference capture, do NOT adjust the reference — fix the guard so the block's
internals are genuinely untouched, since byte-compatibility of the `CONSUMERS_STALE=` line is an
acceptance criterion, not a nice-to-have. If Phase 1 discovers a genuine caller dependency, the
task does not stall: pass `--consumer-report` at that call site and continue, per the description's
explicit instruction not to flip the default.
