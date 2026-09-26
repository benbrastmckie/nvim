# Implementation Plan: Reduce redundant verify-deploy passes in the redeploy checkpoint

- **Task**: 262 - Reduce redundant verify-deploy passes in the redeploy checkpoint
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: 260 (self-clobbering redeploy fix) — COMPLETED (`f90061046 task 260: complete implementation`); the REDEPLOY CHECKPOINT block already carries its `orchestrate_cycle_plan_main` wrap, nothing left to rebase
- **Research Inputs**: `specs/262_reduce_redundant_verify_deploy_passes/reports/01_redeploy-checkpoint-cost-reduction.md`
- **Artifacts**: plans/01_redeploy-checkpoint-cost-reduction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The inter-cycle redeploy checkpoint currently runs `verify-deploy.sh` at full depth twice on its
common path (`pre_findings` before `deploy-headless.sh`, `post_findings` after), plus a third
full-depth run on the rare would-be-defer confirmation path. Gate 8 (`tests/run-all.sh`, the shell
test suite) is ~86% of a full run's wall time (measured: 11m03s full vs. 1m35s `--skip-slow`,
implying ~9m28s for gate 8 alone), and its outcome is invariant across the single
`deploy-headless.sh` call the pair brackets. This plan captures gate 8 **exactly once per
checkpoint firing** and unions that one snapshot identically into every findings set the
checkpoint compares, leaving the other 20 gates on their existing per-side `--skip-slow` runs.
Done means: the checkpoint's measured common-path verify cost falls from ~2 full runs to
1 gate-8 run + 2 fast runs, the pre/post pair stays at *identical* depth by construction rather
than by luck, and every branch of the (a)/(b)/(c) contract — including the confirmation and
attribution filters — behaves exactly as today.

### Research Integration

The research report settles three things this plan treats as decided, not re-litigated:

1. **The originally-reported candidate fix ("cache and reuse the findings snapshot within a single
   checkpoint") is rejected outright.** `pre_findings` and `post_findings` deliberately observe
   different tree states; reusing one for the other destroys the baseline comparison. The code's
   own comment at `orchestrate-cycle-plan.sh:894-906` argues against it by name.
2. **The dispatch's preferred alternative — extending `deploy-ledger-lib.sh` to carry the findings
   snapshot across cycles, keyed on the existing hash state — is also rejected**, on the
   report's argument: reaching the ledger's `run` decision *requires* the source hash to have
   changed, which is precisely when a cached prior snapshot is stale for every source-only lint
   gate; and the one sub-case where reuse would be provably safe (hash unchanged) is already
   fully free via `skip_hash`/`skip_attributed`. The mechanism buys nothing where it is safe and
   is unsafe where it would matter. `deploy-ledger-lib.sh` is therefore **not modified by this
   plan**, despite being in `file_scope`.
3. **The adjacent question (suppressing `deploy-headless.sh`'s own inline `--skip-slow` verify)
   is decided OUT**, explicitly. `deploy-headless.sh` is outside `file_scope`, and its exit 3 is
   derived from precisely that inline run and consumed by many other callers
   (`command-gate-out.sh`, `check-deploy-freshness.sh`, `orchestrate-batch-admit.sh`, the
   postflight completion-deploy gate, others). Recorded as a follow-up, not folded in.

**One research premise is corrected by this plan, from a direct read of the source.** The report
states `deploy-headless.sh` "never writes back into `agent-system/extensions/core`". That is
false in one bounded way: `deploy-headless.sh`'s pre-deploy `line_count` auto-repair runs
`generate-context-line-counts.sh --write`, which mutates `agent-system/extensions/*/index-entries.json`
— source-store files (visible right now as `M agent-system/extensions/core/index-entries.json` in
`git status`). This does not invalidate the design, but it does change what Phase 1's audit must
check: gate 8's invariance across the deploy requires that no test read *either* the live
deployed `.claude/` tree *or* any source file the deploy itself mutates. Phase 1 makes that the
explicit, blocking precondition.

### Prior Plan Reference

No prior plan. This is round 1 for task 262.

### Roadmap Alignment

No `specs/ROADMAP.md` found; no `roadmap_flag` in the dispatch. No roadmap phases.

## Goals & Non-Goals

**Goals**:
- Capture gate 8 exactly once per checkpoint firing and union it identically into `pre_findings`,
  `post_findings`, and `confirm_findings`.
- Keep the pre/post pair informationally identical to today's unqualified full run (fast gates
  per-side + one shared gate-8 component), never narrower.
- Preserve every branch of the (a)/(b)/(c) contract, the confirmation (flaky-vs-real) filter, and
  the attribution filter — logic unchanged, only gate 8's cost removed from them.
- Preserve the fail-safe direction everywhere: an absent/unreadable/unrunnable gate-8 source still
  produces a *finding*, never a silent clean.
- Report measured before/after numbers, and never claim an improvement without them.

**Non-Goals**:
- Any change to `scripts/verify-deploy.sh` (outside `file_scope`).
- Any change to `scripts/deploy-headless.sh`, including its inline `--skip-slow` verify
  (explicitly decided out; see Research Integration item 3).
- Any change to `scripts/lib/deploy-ledger-lib.sh` (in `file_scope`, but the cross-cycle caching
  idea it would host is rejected; leaving it untouched is the decision, not an omission).
- Any change to `command-gate-out.sh`'s rc==6 handler, which also calls
  `deploy_findings_snapshot` at full depth. It gates a single task's completion with the operator
  present; its cost is not this task's problem and its depth stays full.
- Fixing the pre-existing, unrelated findings the research surfaced (a `gate3` doc-lint hit,
  several `gate8` shell-test failures). They are other owners' work and will keep showing up as
  pre-existing findings until fixed.
- Removing or weakening the confirmation pass or the attribution filter.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A test under `scripts/tests/**` reads the live deployed `.claude/` tree or a deploy-mutated source file, making gate 8 non-invariant across the deploy | H | L | Phase 1 is a **blocking precondition audit** of every `scripts/tests/*.sh`. A hit stops the sharing design and routes to the Rollback/Contingency fallback rather than being worked around |
| The new gate-8 parser drifts from `verify-deploy.sh`'s own gate-8 body, so shared lines stop matching what verify-deploy.sh would emit | M | M | Copy the `grep -F '[FAIL]'` + `${line#\[FAIL\] }` idiom **verbatim**, quirks included (indented sub-suite tail lines keep their leading spaces; `[run-all] [FAIL] zero suites` keeps its prefix). Cross-reference comments in both bodies, plus a format-parity regression test (Phase 4) |
| `post_findings` emptiness is load-bearing (it drives `post_exit`, the `clean` ledger write, and the `deployed_critical_paths` update); the union changes what "empty" means | M | L | The union is informationally identical to today's full run, so empty still means "fast gates clean AND gate 8 clean". Phase 3 records this equivalence in a comment; Phase 4 asserts a clean-path case still writes `clean` |
| Existing test cases (l)-(s), (t), (u) seed a fixture source store with no `scripts/tests/run-all.sh`, so the new function would emit a "not found" finding and flip their clean paths to `pre_existing` | M | H | Phase 4 seeds a passing `run-all.sh` stub in `g11_seed_source_store`, and adds a dedicated case for the missing-runner branch instead of letting it leak into unrelated cases |
| Sibling task 261 is dispatched this same cycle with `file_scope` covering the whole `agent-system/extensions/core/scripts/tests/` directory — a genuine overlap with Phase 4's edit target | M | M | Per `context/contracts/territory.md` (Cross-Task Territory): re-read `test-orchestrate-cycle-plan.sh` immediately before each edit; stage only this task's own hunks with an explicit file list (never a directory pathspec); treat an unexpected failure in a test file this plan does not touch as possibly a sibling's in-flight edit; STOP and report a foreign commit or modification after checking `git log` |
| Editing `.claude/**` instead of the source store | H | L | Every edit target in this plan is under `agent-system/extensions/core/`. Per `rules/source-store-deploy-boundary.md`, `.claude/**` is a disposable deploy artifact; a `.claude/` edit would be silently wiped |
| An end-to-end checkpoint wall-time measurement requires a real multi-task `/orchestrate` run whose checkpoint fires, which may not occur within this task | L | M | Phase 6 measures the three components directly (`time`-d) and states plainly when a total is derived from components rather than observed end to end. Never report a derived number as an observed one |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4, 5 | 3 |
| 5 | 6 | 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Precondition audit and pre-change baseline measurement [NOT STARTED]

**Goal**: Establish, before any edit, (i) that gate 8's outcome is genuinely invariant across one
`deploy-headless.sh` call, and (ii) the "before" wall-time numbers Verification item 1 requires.

**Tasks**:
- [ ] Enumerate every `agent-system/extensions/core/scripts/tests/*.sh` file and grep each for
      references to the live deployed tree outside its own `mktemp`/`WORKDIR`/`FIXTURE` scope:
      `PROJECT_ROOT/.claude`, `$TARGET/.claude`, `CLAUDE_DIR`, and a bare `.claude/` path.
- [ ] Additionally grep every test for reads of source files `deploy-headless.sh` itself mutates,
      i.e. `agent-system/extensions/*/index-entries.json` (the `generate-context-line-counts.sh
      --write` auto-repair at `deploy-headless.sh:312-315`). Confirm each hit is fixture-scoped
      (`test-index-entries-schema.sh` writes its own `$FIXTURE/index-entries.json`;
      `test-double-loading-check.sh` and `test-deploy-orphans.sh` reference it only in comments) —
      re-verify rather than trusting this plan's reading.
- [ ] Record the audit result explicitly, as a written statement of what was checked and what was
      found, in the phase's commit message and later in the execution summary.
- [ ] **Decision gate**: if any test reads the live deployed tree or a deploy-mutated source file,
      STOP. Do not proceed to Phase 2; take the Rollback/Contingency fallback and report.
- [ ] Measure and record, with `time`, from the repo root:
      `bash .claude/scripts/verify-deploy.sh --skip-slow --findings --quiet` and
      `bash .claude/scripts/verify-deploy.sh --findings --quiet`, and
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` on its own.
- [ ] Record whether `deploy-headless.sh`'s own wall time can be measured non-destructively in
      this environment; if not, say so rather than guessing a number.

**Timing**: 0.75 hours (plus ~25 minutes of unattended measurement wall time)

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts (a) that no test under `scripts/tests/**` reads the live
deployed tree or a deploy-mutated source file, and (b) that gate 8 accounts for roughly 9m28s of
an 11m03s full run. Both are hypotheses inherited from the research report, and this phase exists
precisely to confirm them at implementation time. Confirm (a) by the exhaustive greps above over
the full file list, not a sample; confirm (b) by the three fresh `time` measurements. A
materially different (b) does not block the design but MUST be reported as the actual baseline.

**Files to modify**:
- None. This phase reads and measures only.

**Verification**:
- The audit covers 100% of `scripts/tests/*.sh`, and the file count checked is stated.
- Three wall-time numbers are recorded with their commands.
- The decision gate is explicitly answered "proceed" or "stop", in writing.

---

### Phase 2: Add `deploy_gate8_snapshot` to `deploy-baseline-lib.sh` [NOT STARTED]

**Goal**: A single, format-compatible producer of gate-8 `FINDING` lines that can be captured once
and reused, living beside the three functions that already consume findings text.

**Tasks**:
- [ ] Add `deploy_gate8_snapshot <target_repo>` to
      `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`. The target argument is
      **required, with no default** — a default of `$(pwd)` would let a call site silently resolve
      the wrong tree, and a test fixture would then run the real 9-minute suite.
- [ ] Reproduce `verify-deploy.sh`'s gate-8 body (`scripts/verify-deploy.sh:481-503`) branch for
      branch, so the output is a drop-in substitute for what a full-depth run would have emitted:
  - `[ ! -d "$target/agent-system/extensions" ]` → emit **nothing** (gate 8's own
    "deploy consumer, not the source store" SKIP).
  - `[ ! -f "$target/agent-system/extensions/core/scripts/tests/run-all.sh" ]` → emit exactly
    `FINDING gate8 tests/run-all.sh not found in source store` (gate 8's `fail` with no
    third-arg override records the narrative message verbatim).
  - otherwise `cd "$target" && bash "$target/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet 2>&1`;
    on exit 0 emit nothing; on nonzero emit `FINDING gate8 ${line#\[FAIL\] }` for each line of
    that captured output matching `grep -F '[FAIL]'`.
- [ ] Copy the parse idiom **verbatim, quirks included**. `grep -F '[FAIL]'` is unanchored and
      `${line#\[FAIL\] }` only strips a *leading* `[FAIL] `, so: `[FAIL] <suite>` is stripped;
      the 4-space-indented sub-suite tail lines `run-all.sh` prints under a failing suite keep
      their indentation; and `[run-all] [FAIL] zero test suites discovered ...` keeps its
      `[run-all] ` prefix. Do not "improve" any of this — parity is the whole point.
- [ ] `sort -u` the output, matching `deploy_findings_snapshot`'s own normalization.
- [ ] Guarantee the function never aborts a caller running under `set -e -o pipefail` and never
      propagates `run-all.sh`'s exit code — the same contract, and the same `|| true` reasoning,
      `deploy_findings_snapshot` documents at `deploy-baseline-lib.sh:99-104`.
- [ ] Extend the library's header block to document the fifth exported function, including: why it
      exists (cost), why sharing is *sound* (gate 8 reads only the source store, which one
      `deploy-headless.sh` call leaves unchanged except for the bounded `index-entries.json`
      line_count repair Phase 1 audited), and an explicit two-copy drift warning naming
      `verify-deploy.sh`'s gate-8 body as the sibling that must be kept in step.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` - add
  `deploy_gate8_snapshot`; extend the header from four to five exported functions.

**Verification**:
- `bash -n` clean on the library.
- Sourced in isolation, `deploy_gate8_snapshot` returns 0 and emits nothing for a target with no
  `agent-system/extensions` directory.
- Sourced in isolation against a scratch target with `agent-system/extensions/` present but no
  `run-all.sh`, it emits exactly the one "not found in source store" finding line.
- Under `set -euo pipefail`, capturing its output with `x=$(deploy_gate8_snapshot "$t")` does not
  abort the calling shell for any of the three branches.

---

### Phase 3: Wire the shared gate-8 snapshot into the checkpoint [NOT STARTED]

**Goal**: The checkpoint pays for gate 8 once instead of two or three times, with the pre/post pair
at identical depth by construction.

**Tasks**:
- [ ] In `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`, inside the
      `if [ "$ledger_decision" = "run" ]` branch (currently opening at :866), capture the shared
      snapshot **first, before anything else in the branch**:
      `gate8_findings=$(deploy_gate8_snapshot "$PROJECT_ROOT")`. First position is deliberate —
      the least-loaded moment of the checkpoint, which minimizes the load-sensitive flaking the
      confirmation filter exists to absorb.
- [ ] Change all three `deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh"` call sites
      (`pre_findings` :867, `post_findings` :907, `confirm_findings` :944) to pass `--skip-slow`,
      and union each result with `$gate8_findings` via a single shared local helper or an inline
      `printf '%s\n%s\n' ... | grep '^FINDING ' | sort -u || true` — one idiom, used identically
      at all three sites, so no site can drift from the others.
- [ ] Note in a comment that `$PROJECT_ROOT` (`common_repo_root "$SCRIPT_DIR" 2`, :258) is the
      tree passed explicitly, whereas the `verify-deploy.sh` calls resolve `TARGET` from `$(pwd)`
      (`verify-deploy.sh:116`). These coincide in production; the explicit argument is what makes
      the gate-8 tree unambiguous and the fixture interposable.
- [ ] Rewrite the DEFECT A comment block (:894-906) so it documents the new arrangement without
      weakening its own constraint: the pre/post pair remains at identical depth — now
      *structurally* identical for gate 8 (the same lines on both sides by construction, not by
      two independent re-executions) and per-side identical for the other 20 gates. State
      explicitly that "full depth" now means "`--skip-slow` plus the shared gate-8 union", which
      is informationally identical to the previous unqualified full run and never narrower.
- [ ] Record in the same comment why `-z "$post_findings"` still means what it meant: the union is
      empty iff the fast gates are clean AND gate 8 is clean, so the `post_exit=0` derivation, the
      `clean` ledger write, and the `deployed_critical_paths` update at :909-916 are unchanged.
- [ ] Amend the confirmation-pass comment (:940-943) — the confirmation snapshot is still taken at
      the same depth as the pre/post pair, but gate 8 is no longer re-executed for it, and gate 8
      can no longer appear as a candidate-new finding at all.
- [ ] Amend the DEPTH NOTE wording (:983-991) for accuracy: with the checkpoint's own fast pass now
      covering the same gates as `deploy-headless.sh`'s inline `--skip-slow` verify, a
      `deploy_exit -eq 0` disagreement points at the shared gate-8 component. Keep
      `depth_disagreement` itself and its `defer_ledger` field unchanged.
- [ ] Do NOT touch the `else` (ledger-skip) arm at :1004-1026 — a skip still costs zero verify
      passes and zero gate-8 runs, which is already optimal.

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly three `deploy_findings_snapshot` call sites exist
in the checkpoint (`orchestrate-cycle-plan.sh` :867, :907, :944) and that `command-gate-out.sh`'s
two further call sites (:189, :202) are deliberately out of scope. Confirm at implementation time
with `grep -n deploy_findings_snapshot` across `scripts/` before editing — line numbers will have
drifted, and a fourth in-checkpoint site appearing would change the wiring.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - shared gate-8 capture; three
  call sites switched to `--skip-slow` + union; four comment blocks amended.

**Verification**:
- `bash -n` clean on the SUT.
- `grep -n deploy_findings_snapshot scripts/orchestrate-cycle-plan.sh` shows all three sites
  passing `--skip-slow`, and `grep -n deploy_gate8_snapshot` shows exactly one capture site.
- `command-gate-out.sh` is untouched (`git diff --stat` names no other script).
- The three amended comment blocks read as accurate descriptions of the new code, with the
  depth-symmetry constraint stated as preserved rather than relaxed.

---

### Phase 4: Test coverage and suite re-run [NOT STARTED]

**Goal**: Lock the new behavior in with tests that would fail if gate 8 were re-executed per side,
if the shared lines diverged in format, or if any branch of the contract changed.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
      immediately before editing — sibling task 261 declares this whole directory in its
      `file_scope` and is dispatched this same cycle.
- [ ] Add a `write_g11_run_all_stub <exit_code> [fail_line]` helper beside
      `write_g11_verify_stub` / `write_g11_deploy_headless_stub` (~:1164-1200), writing an
      invocation-counting stub to
      `$WORKDIR/agent-system/extensions/core/scripts/tests/run-all.sh`.
- [ ] Have `g11_seed_source_store` (~:1322) seed a **passing** `run-all.sh` stub by default, so
      every existing case that reaches the `run` branch with a seeded source store — (n), (o),
      (p), (q), (r), (s), (t), (u) — keeps its current clean/`pre_existing` expectations with
      assertions unchanged. Confirm by running the suite, not by inspection.
- [ ] Confirm cases (a)-(k) need no change: they deliberately never populate
      `$WORKDIR/agent-system/extensions/core`, so `deploy_gate8_snapshot` takes its
      "not a source store" SKIP branch and contributes no lines. Verify by observation.
- [ ] New case: **gate-8 invocation count**. On a checkpoint firing that reaches the confirmation
      path (a candidate new finding), the `run-all.sh` stub's counter reads exactly `1`, while the
      `verify-deploy.sh` counter reads `3`. This is the phase's primary regression guard.
- [ ] New case: **structural depth symmetry**. With the `run-all.sh` stub failing, its
      `FINDING gate8 ...` line appears in both `pre_findings` and `post_findings` counts and
      produces zero new findings — i.e. branch (c) proceeds loudly. Extend or sit alongside
      existing case (i) (":1514, depth-symmetry regression guard"), which today asserts the same
      outcome from a fixture that *arranges* for gate 8 to appear on both sides; the new case
      asserts it now holds by construction.
- [ ] New case: **missing runner is fail-safe**. Source store seeded but `run-all.sh` absent →
      the "not found in source store" finding appears on both sides → non-empty `post_findings` →
      branch (c) loud-proceed with a `pre_existing` ledger write, never a silent clean.
- [ ] New case: **format parity**. For a fixed synthetic `run-all.sh` failure output, assert the
      `FINDING gate8 ...` lines `deploy_gate8_snapshot` produces are byte-identical to what
      `verify-deploy.sh`'s gate-8 body would produce from the same output — including an indented
      sub-suite tail line and a `[run-all] [FAIL] zero test suites discovered` line.
- [ ] Re-run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` and
      the deploy/baseline-related suites under `scripts/tests/` in full. No test may be weakened,
      skipped, or deleted to make the change pass.
- [ ] Stage and commit only this task's own hunks, by explicit file list. Never a directory or
      glob `git add` pathspec (`rules/git-workflow.md`, Git Safety).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that cases (a)-(k) require no edits and that cases
(l)-(u) are made whole by seeding a passing `run-all.sh` stub in one helper. Confirm by running
the suite after the helper change and before writing any new case: any case failing at that point
identifies a further fixture dependency this plan did not anticipate, and is fixed in the fixture
rather than by relaxing the case's assertion.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - new
  `write_g11_run_all_stub` helper; `g11_seed_source_store` seeds a passing stub; four new
  Group 11 cases.

**Verification**:
- `test-orchestrate-cycle-plan.sh` passes in full, with the new cases reporting PASS by name.
- The gate-8 invocation-count case fails if either call site's `--skip-slow` is reverted (check by
  temporarily reverting one, observing the failure, then restoring).
- `git diff --stat` for this phase names exactly one file.
- No pre-existing case's assertion was edited to accommodate the change.

---

### Phase 5: Document the sharing in `batch-orchestration-guardrails.md` [NOT STARTED]

**Goal**: The authoritative checkpoint contract describes what the code now does, including the
two things a future reader would otherwise misread.

**Tasks**:
- [ ] Amend the **Baseline mechanism** paragraph (~:713-722 of
      `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`), which
      currently says the snapshot is "captured once immediately before `deploy-headless.sh` runs
      and once after it succeeds". Add that gate 8's component is captured once **in total**,
      before the deploy, and unioned identically into both sides — so the pair is at identical
      depth structurally, not by two independent executions.
- [ ] State the soundness argument in the same DEFECT-A-style "this is deliberate" register the
      code comment uses: gate 8 runs `run-all.sh` against the source store, which one
      `deploy-headless.sh` call does not change (except the bounded `index-entries.json`
      line_count auto-repair, which Phase 1 audited as read by no test), so its outcome cannot
      differ between the two sides of one checkpoint.
- [ ] Record the **self-inflicted-load premise re-check** the dispatch asked for, explicitly and
      in both directions: for gate 8, the premise is substantially weakened (it now runs once,
      before the deploy, and is never part of the pre/post *comparison*, so it cannot be the
      source of a spurious pre/post mismatch for itself). For the other 20 gates the premise is
      **not** weakened and the confirmation pass is preserved unchanged. Say plainly that the
      gate-8 change is not evidence the confirmation mechanism is unnecessary.
- [ ] Record the **notice-count semantics** change: a `verify_deploy_baseline_notices` entry's
      `pre_findings`/`post_findings` counts now include lines contributed by a call that ran
      outside `verify-deploy.sh` itself, so an operator reading a count is not misled.
- [ ] Record the two rejected/deferred designs so a later pass cannot rediscover them, in the same
      "Rejected alternatives, recorded so a later pass cannot rediscover them" register the
      document already uses: (i) cross-cycle whole-snapshot caching in the durable ledger, with
      the reason (safe only where already free, unsafe where it would matter); (ii)
      `deploy-headless.sh` inline-verify suppression, with the reason (exit-3 contract, many
      callers, outside `file_scope`) and its status as a scoped follow-up.
- [ ] Reference the code by script and function/section name, never by line number.
- [ ] No task-number references — `rules/no-task-references-in-deliverables.md` exempts
      `specs/**`, and this file is not under `specs/**`.

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - amend the
  Baseline mechanism paragraph; add the gate-8 sharing rationale, the load-premise re-check, the
  notice-count semantics note, and the two rejected-design records.

**Verification**:
- Diff read-through confirms every changed hunk is prose in this one file.
- The amended text names no line numbers and no task numbers.
- A reader of the amended section can answer, without reading the code: how many times gate 8
  runs per checkpoint, why that is sound, and why the confirmation pass still exists.

---

### Phase 6: Measure, verify end to end, and close [NOT STARTED]

**Goal**: Report real before/after numbers and confirm all eight of the dispatch's verification
items, without claiming anything unmeasured.

**Tasks**:
- [ ] Re-measure, with `time`, the post-change component costs: the shared gate-8 run
      (`run-all.sh --quiet`) and `verify-deploy.sh --skip-slow --findings --quiet`.
- [ ] Compute the before/after checkpoint verify cost from Phase 1's and this phase's components:
      before = 2 full runs (+1 on the defer path); after = 1 gate-8 run + 2 fast runs (+1 fast on
      the defer path). Report the raw component numbers alongside any derived total, and label a
      derived total as derived.
- [ ] If a real `/orchestrate` run whose checkpoint actually fires (`cycle_modified_files` touching
      `agent-system/**`) occurs while this task is in flight, record its observed checkpoint wall
      time. If none occurs, say so explicitly rather than presenting the derived number as
      observed. Do not stage an artificial multi-task run solely to produce a number.
- [ ] Walk the dispatch's eight verification items one by one and record, for each, the concrete
      evidence: item 1 the measurements above; items 2-4 restated in the terms this design
      actually implements (the within-checkpoint share, the ledger's unchanged `skip_hash` /
      `skip_attributed` / `run` behavior, and the missing/unreadable-runner fail-safe case from
      Phase 4) rather than the cross-cycle cache the plan rejects; items 5-7 the Phase 4 cases for
      defer, flaky classification, and branch (c); item 8 the full suite re-run.
- [ ] Run the full gate set once: `bash .claude/scripts/verify-deploy.sh` (no `--skip-slow`) and
      confirm no finding newly attributable to this task's own files. Pre-existing findings the
      research already catalogued stay pre-existing and are named as such, not silently absorbed.
- [ ] Write the execution summary, carrying forward: the Phase 1 audit statement, the corrected
      research premise about `deploy-headless.sh`'s source-store write, the measured numbers, and
      the two follow-up recommendations (inline-verify suppression; `verify-deploy.sh`'s stale
      header timings).

**Timing**: 1.25 hours (plus unattended measurement wall time)

**Depends on**: 4, 5

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the change cuts the checkpoint's common-path verify cost
by roughly 40% (~22 min to ~12.7 min of verify work). That is the research's projection from a
single-sample measurement, not a fact. Confirm with the fresh component measurements above, and
report whatever they actually show — including a smaller or absent saving.

**Files to modify**:
- `specs/262_reduce_redundant_verify_deploy_passes/summaries/01_*-summary.md` - execution summary
  (created by the implementation postflight, not a source-store edit).

**Verification**:
- Before and after numbers are both present, each with the command that produced it.
- All eight dispatch verification items have a recorded outcome; none is marked satisfied without
  evidence.
- The full (non-`--skip-slow`) gate set shows no finding attributable to this task's files.

---

## Testing & Validation

- [ ] `bash -n` clean on `deploy-baseline-lib.sh` and `orchestrate-cycle-plan.sh`.
- [ ] `test-orchestrate-cycle-plan.sh` passes in full, including all four new Group 11 cases.
- [ ] The gate-8 invocation-count case proves `run-all.sh` runs exactly once per checkpoint firing,
      even on the three-verify-call confirmation path.
- [ ] A failing gate-8 result present on both sides yields zero new findings (branch (c) loud
      proceed), by construction.
- [ ] An absent `run-all.sh` yields a finding on both sides, never a silent clean (fail-safe).
- [ ] A genuinely new, confirmed, attributable finding still defers the batch with the
      `defer_ledger` detail naming it.
- [ ] A flaky (non-reproducing) candidate finding is still classified flaky and does not defer.
- [ ] The ledger's `skip_hash` / `skip_attributed` / `run` decisions are unchanged
      (`deploy-ledger-lib.sh` untouched; cases (l)-(s) pass unmodified).
- [ ] The full `verify-deploy.sh` gate set reports no finding attributable to this task's files.
- [ ] No test weakened, skipped, or deleted.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — fifth exported function
  `deploy_gate8_snapshot` plus an extended header.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — one shared gate-8 capture,
  three call sites at `--skip-slow` + union, four amended comment blocks.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new stub helper,
  seeded passing `run-all.sh`, four new cases.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — amended
  Baseline mechanism paragraph and the sharing/load-premise/notice-count/rejected-design records.
- `specs/262_reduce_redundant_verify_deploy_passes/summaries/01_*-summary.md` — execution summary
  with measured before/after numbers and the two follow-up recommendations.
- Unchanged by design, and stated so: `scripts/verify-deploy.sh`, `scripts/deploy-headless.sh`,
  `scripts/lib/deploy-ledger-lib.sh`, `scripts/command-gate-out.sh`.

## Rollback/Contingency

The change is four files in the source store, none of which alters an interface another repository
consumes. Each phase commits independently, so reverting is per-phase.

- **Phase 1's decision gate fails** (a test reads the live deployed tree or a deploy-mutated source
  file): the sharing design is unsound as written. Do not proceed and do not weaken the audit.
  Report the specific test, and record the fallback: gate 8 would have to stay per-side, leaving
  only the (much smaller) option of sharing nothing and closing this task as "no safe saving
  found, here is why" — a legitimate outcome, not a failure to work around.
- **A later phase regresses the contract**: revert that phase's own commit with
  `git revert <sha>`. Earlier phases stand on their own — Phase 2 adds an unused function, which is
  inert; Phase 5 is prose only.
- **Working-tree rollback**: only if a genuine rollback is needed, and only then, snapshot first
  per `context/contracts/recovery.md`'s rollback rung (including its out-of-scope override flag
  for the deliberate whole-tree case) before any `git reset`/`checkout`/`clean`. A defensive
  checkpoint before risky work is `git-snapshot.sh <task> --no-revert`, which is durable without
  reverting the tree — never the bare default-mode form.
- **Sibling-task collision on the shared test file**: if a foreign commit or foreign uncommitted
  modification to `test-orchestrate-cycle-plan.sh` appears, STOP and report after checking
  `git log` to confirm the work is not this task's own. Do not revert or overwrite a sibling's
  work.
