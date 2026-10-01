# Research Report: Task #283

**Task**: 283 - Fix the agent-system test harness (run-all.sh): name failing suites, add a
known-failing baseline, and reduce wall clock
**Started**: 2026-09-30T19:05:00Z
**Completed**: 2026-09-30T19:20:00Z
**Effort**: ~1 session (research only)
**Dependencies**: None
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/scripts/tests/run-all.sh`,
  `verify-deploy.sh`, `orchestrate-cycle-plan.sh`, `lib/deploy-baseline-lib.sh`), a live full
  105-suite `run-all.sh --jobs auto` execution performed during this research pass, the 8
  individually-failing suites re-run standalone, `git log`/`git diff` on the harness and on
  `agent-system/extensions/typst/scripts/typst-element-lint.sh`, the archived task 261 plan/
  summary/phase-4-audit-table, `context/standards/shell-script-testing.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect 1 (naming) is already substantially fixed upstream.** `run-all.sh` has emitted an
  unconditional, machine-greppable `[FAIL] <suite path>` line per failing suite since commit
  `d77e0ed3d` (task 261 phase 6.1, 2026-09-25) — five days before this task was filed. A fresh
  live run performed during this research pass (105 suites, `--jobs auto`) produced exactly 8
  `[FAIL] <path>` lines, matching the dispatch's own 8-suite list 1:1, and `verify-deploy.sh`
  Gate 8 already consumes these lines into `FINDING gate8 ...` rows when `--findings` is passed.
  The dispatch's premise ("110 RUN, 97 PASS, ZERO FAIL markers") is contradicted by the current
  source and by this run; the most likely explanation is a stale observation window (before
  2026-09-25) or a grep for the `[run-all] [FAIL]` prefix pattern that the FAIL line deliberately
  does not carry (RUN/PASS/SKIP are prefixed `[run-all] `; FAIL is bare `[FAIL] <path>` by
  design, per the header comment). **What is still genuinely missing** is the dispatch's second
  ask: a consolidated end-of-run failure roster (today a reader must notice scattered inline
  `[FAIL]` lines during a 105-suite scroll; there is no single "Failing suites (8): ..." block
  next to the final tally line).
- **Defect 2 (no baseline manifest) is real and unaddressed at the tooling level**, though a
  prose list already exists at `context/standards/shell-script-testing.md`'s "Known pre-existing
  failures and flakes" section (4 consistently-failing + 1 known-intermittent + 5 load-sensitive
  suites). `run-all.sh` does not read this list, so it cannot report "N expected-failing, 0 NEW".
  Cross-checking that prose list against today's live 8 failures found it **incomplete**: 2 of
  today's 8 failures (`test-verify-deploy-context-budget.sh`,
  `typst/scripts/tests/test-typst-element-lint.sh`) are not in the documented list at all, and
  one documented list entry (the file that's currently `git diff`-modified,
  `typst-element-lint.sh`) is failing for reasons unrelated to the harness (see Findings).
- **Root-caused 3 of the 8 failures to one single shared bug**, not three separate defects:
  `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`, and
  `test-orchestrate-recover-message-findings.sh`'s e2e case all build a synthetic sandbox that
  copies a **hardcoded list** of `lib/*.sh` files into `$WORKDIR/.claude/scripts/lib/`, and that
  list predates task 258 phase 3 (2026-09-25), which added a *new* hard dependency
  (`lib/return-meta-status-vocabulary.sh`) to the real `orchestrate-cycle-postflight.sh` these
  suites copy in unmodified. All three fail identically: `ERROR: ... shared library
  return-meta-status-vocabulary.sh not found`. **This directly answers the dispatch's explicit
  question** ("check whether the red test describes a real live defect rather than being merely
  stale") for `test-handoff-dispatch-identity.sh`: it is stale — a fixture-maintenance gap, not
  evidence the dispatch_seq/handoff-identity gate itself is broken.
- **2 of the 8 failures are genuine, narrow, real repo-state defects unrelated to run-all.sh's
  own logic**: `test-verify-deploy-context-budget.sh` fails because Gate 20 (context budget)
  currently finds 2 real findings against the live repo (`skills/skill-orchestrate/SKILL.md` at
  21317 B exceeds its 20000 B ceiling; eager-load total 67980 B exceeds the 65950 B baseline),
  which exceeds the test's own `-le 1` cleanliness tolerance for its baseline precondition.
  `typst/scripts/tests/test-typst-element-lint.sh` fails because
  `agent-system/extensions/typst/scripts/typst-element-lint.sh` currently carries an
  **uncommitted, in-progress working-tree edit** (a new "Check 4: element presence" warning,
  visible in `git diff`) that the test's own fixtures were never updated to expect — this is
  unrelated, concurrent WIP in the same repo, not a run-all.sh or task-283 defect to fix.
- **1 of the 8 (`test-gate-out-repair-reporting.sh`) is a real, distinct logic bug**: 5 of 19
  cases fail deterministically (not intermittently, in this run) around
  `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES` not accumulating correctly across
  multi-file aggregation and not resetting between calls (Case 3, 4, 6). This needs its own,
  separate investigation into `validate-artifact.sh`'s auto-repair aggregation function; it is
  out of scope for a harness-reporting fix and should be quarantined with an owning task, not
  fixed inline here.
- **1 of the 8 (`test-run-all-parallel.sh`) reproduced the exact, already-documented
  ambient-load flake** from task 261's own record (case3: "parallel (1904ms) is not meaningfully
  faster than forced-sequential (1904ms)"), under the same kind of heavy concurrent-agent load
  task 261 diagnosed (this research session itself ran alongside 7 other named addressable
  agents per its own dispatch context). Not a new regression.
- **Defect 3 (wall clock) was already substantially attacked by task 261** (archived,
  2026-09-26): `--jobs N|auto` (opt-in, default stays 1), `verify-deploy.sh --only-gate`, and a
  4x-to-1x collapse of `test-verify-deploy-context-budget.sh`'s own invocations (391s -> 103s).
  Task 261 measured `--jobs 4` at ~212s vs. sequential ~508-646s under *quiet* conditions, but
  explicitly **declined to flip the default** because a 3-run flakiness gate found load-sensitive
  suites did not reliably benefit under heavy ambient host contention — the same condition this
  research session just reproduced live (`--jobs auto` here took ~278s, barely better than the
  ~272-275s sequential baseline the dispatch itself measured, because the host was busy).
  Task 261's Phase 4 audit (full 97/105-suite table) already investigated whether the 5
  load-sensitive suites could join the parallel pool via isolation (per-suite temp roots/lock
  paths) and found **zero suites with a fixed port/socket/lock-path collision** — every one of
  the 5 is load-sensitive because it makes a real wall-clock-budget or `/proc/meminfo`-pressure
  assertion, not because of a resource collision. **Isolation would not help**; this question is
  already closed by evidence, not open for re-investigation.
- **The highest-leverage, still-unexploited wall-clock fix candidate found this session**:
  `orchestrate-cycle-plan.sh`'s redeploy checkpoint calls `deploy_findings_snapshot()`
  (`lib/deploy-baseline-lib.sh`) 2-3 times per cycle (pre / post / confirm), and each call runs
  `bash verify-deploy.sh --findings --quiet` with **no `--skip-slow` and no `--only-gate`** —
  meaning it re-runs the *entire* 105-suite Gate 8 battery 2-3 times per orchestration cycle, on
  top of whatever full-suite runs the dispatched agent already performed as its own phase gate.
  This is the concrete mechanism behind the dispatch's "measured cost" story (agent runs it
  twice, orchestrator's own checkpoint runs it a third time, one call exceeded 8m27s). Passing
  `--skip-slow` (or a narrower `--only-gate` list excluding gate 8) to these specific
  drift-detection calls is a small, surgical, high-value fix that does not require touching
  `run-all.sh` internals at all.

## Context & Scope

Researched `agent-system/extensions/core/scripts/tests/run-all.sh` (the shell-suite runner) and
its three named defects: (1) failing suites are unnamed, (2) no committed known-failing
baseline, (3) high wall clock with 5 suites permanently excluded from the parallel pool. Per the
dispatch's scope note, all edit targets live under `agent-system/extensions/**` (source store),
never hand-authored under `.claude/**`; `.claude/scripts/tests/run-all.sh` was confirmed
byte-identical to the source-store copy and gitignored (disposable deploy artifact), so no
`.claude/**` edits are ever the right target. Research also covered `verify-deploy.sh` Gate 8
(the harness's primary consumer), `orchestrate-cycle-plan.sh`'s redeploy checkpoint (the second
consumer, and the one implicated in the dispatch's "8m27s" observation), and the archived task
261 (which already did substantial, directly-relevant prior work on this same file).

A live full-suite run was executed during this research pass (`bash run-all.sh --jobs auto`,
105 suites, ~278s wall time) specifically to verify the dispatch's factual claims against
current reality rather than taking the described 855-line log at face value, since the described
symptom (zero `[FAIL]` markers) directly contradicted what a fresh reading of the current source
predicted. All 8 named failing suites were additionally re-run standalone to triage root cause.

## Findings

### Codebase Patterns

- `run-all.sh` (472 lines) has two code paths sharing one contract: sequential (`--jobs 1`,
  default, byte-identical to pre-`--jobs` behavior) and parallel (`--jobs N>1`), both of which
  print `echo "[FAIL] $suite_name"` (unprefixed, unconditional — not gated by `--quiet`) at the
  point of failure, and both accumulate into one final line:
  `"[run-all] $PASS_COUNT passed, $FAIL_COUNT failed, $SKIP_COUNT skipped, $TOTAL_DISCOVERED total"`.
  The `[RUN]`/`[PASS]`/`[SKIP]` lines are prefixed `[run-all] ` and suppressed by `--quiet`; the
  `[FAIL]` line is deliberately bare and never suppressed (header comment, lines 82-84: "every
  failing suite prints a line of the exact form `[FAIL] <suite path>`... regardless of `--quiet`
  or `--jobs`"). There is no code path today that collects failing suite names into an array for
  an end-of-run roster — only the integer `FAIL_COUNT` survives to the final line.
- `verify-deploy.sh` Gate 8 (`say "8. Shell test suite runner..."`, ~line 549) already invokes
  `run-all.sh --quiet` and, under `--findings`, greps its output for `grep -F '[FAIL]'` and
  folds each into `FINDING gate8 <suite path>` — i.e., one consumer of the naming contract
  already exists and works correctly today.
- `deploy_findings_snapshot()` (`lib/deploy-baseline-lib.sh:90`) is the second, more expensive
  consumer: `bash "$verify_deploy_path" --findings --quiet "$@"` with no slow-gate exclusion.
  `orchestrate-cycle-plan.sh`'s redeploy checkpoint (~lines 904, 944, 985) calls this function
  2-3 times per cycle (pre-redeploy baseline, post-redeploy snapshot, and a confirm-pass only
  when new findings appear) — each one a full 20-gate `verify-deploy.sh` run including the full
  105-suite Gate 8.
- `context/standards/shell-script-testing.md`'s "Suite runtime" section documents `--timings`,
  `--jobs`, and `--only-gate` (all from task 261) and a "Known pre-existing failures and flakes"
  prose list (4 consistently-failing + 1 intermittent + 5 load-sensitive = 10 named suites). This
  list is **not read by any script** — it exists purely as human-facing documentation, and this
  session found it does not currently cover 2 of the 8 live failures.
- Task 261's archived `progress/phase-4-audit-table.txt` (full 97-suite parallelism-safety
  verdict table) already classified every suite as `PARALLEL-SAFE` or `LOAD-SENSITIVE` with a
  one-line reason; every `LOAD-SENSITIVE` reason cites a real wall-clock-budget or
  `/proc/meminfo`-pressure assertion, and the table's own header states the audit found **zero**
  suites with a fixed port/socket/lock-path collision outside their own fixture.

### External Resources

Not applicable — this is a closed, self-contained shell-test-harness question with no external
library or API surface; all research was codebase- and live-run-based per the task's own scope.

### Live Triage of the 8 Named Failing Suites

| Suite | Root cause found this session | Disposition |
|---|---|---|
| `core/.../test-handoff-dispatch-identity.sh` | Stale fixture: sandbox's hardcoded `lib/*.sh` copy-list predates task 258 phase 3's new `return-meta-status-vocabulary.sh` dependency in the real `orchestrate-cycle-postflight.sh` it copies in. All 8 cases fail identically with "shared library ... not found". | **Fix**: add the missing filename to the copy-list (and to the `require_file` loop). Mechanical, low-risk. Confirms the dispatch_seq/handoff-identity gate logic itself is NOT broken — answers the dispatch's explicit stale-vs-real question. |
| `core/.../test-orchestrate-context-growth.sh` | Same root cause (same missing lib in its own sandbox copy-list). 3 of 6 candidate checks fail with the identical "shared library ... not found" error; the actual growth-budget assertion it exists to protect (`PER_TASK_PER_CYCLE_BYTES` under 2048 B) still passes. | **Fix**: same one-line list fix. |
| `core/.../test-orchestrate-recover-message-findings.sh` | Same root cause, in this suite's e2e acceptance case only (its earlier dry-run cases don't invoke the real postflight SUT, so they pass). | **Fix**: same one-line list fix. |
| `core/.../test-verify-deploy-context-budget.sh` | Genuine, real, currently-live Gate 20 findings against the actual repo tree: `skills/skill-orchestrate/SKILL.md` (21317 B) over its 20000 B ceiling, and eager-load total (67980 B) over the recorded 65950 B baseline — exceeds the test's own `-le 1` baseline-cleanliness tolerance. | **Quarantine with owning task**: trim `skill-orchestrate/SKILL.md` (or re-baseline deliberately) is separate work, not a run-all.sh or task-283 fix. |
| `core/.../test-lint-json-channel-discipline.sh` | Genuine, real current lint violation: `agent-system/extensions/typst/scripts/chapter-quality-check.sh` captures `$out` with `2>&1` then consumes it as JSON/NDJSON — a real channel-discipline defect in that script, not a harness or test bug. | **Quarantine with owning task**: fix `chapter-quality-check.sh`'s stderr/stdout channel handling, separate from task 283. |
| `core/.../test-gate-out-repair-reporting.sh` | Distinct real logic bug: `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES` globals do not accumulate correctly across multi-file aggregation (Case 3/4) and are not reset between calls (Case 6) — 5 of 19 cases failed deterministically in this run (not flaky as documented). | **Quarantine with owning task**: needs its own investigation of `validate-artifact.sh`'s auto-repair aggregation, out of harness scope. |
| `core/.../test-run-all-parallel.sh` | Reproduced the exact, already-diagnosed-and-accepted ambient-load flake from task 261 (case3's relative-timing assertion: "parallel is not meaningfully faster than forced-sequential"), under genuinely heavy concurrent-agent host load during this research session. | **No action / already known**: this is the documented load-sensitive behavior task 261 explicitly declined to "fix" further (weakening it more would violate the no-test-weakening constraint). |
| `typst/.../test-typst-element-lint.sh` | Currently-uncommitted, in-progress working-tree edit to `typst-element-lint.sh` (confirmed via `git diff`: a new "Check 4: element presence" advisory warning) that this test's own `case-h2` fixture was never updated to expect. Unrelated, concurrent WIP elsewhere in the repo. | **Not this task's concern**: will resolve itself when that other work either commits its own fixture update or is reverted; do not "fix" task 283's baseline manifest around transient uncommitted state — if it's still present when task 283 implements, exclude it from the manifest with a note that it's WIP-caused, not baseline. |

## Decisions

- Treat Defect 1's per-suite naming as **already delivered** upstream (2026-09-25); scope task
  283's Defect-1 work to the genuinely missing piece — a consolidated end-of-run failure roster
  (e.g., a `Failing suites (N):` block, built from an array populated at each existing `[FAIL]`
  echo site, printed immediately before the final tally line) — plus the dispatch's explicitly
  required regression test asserting a deliberately-failing fixture suite is named in the output.
  Do not re-implement per-suite `[FAIL]` naming; it would be redundant with a contract Gate 8
  already depends on today.
- Treat the `shell-script-testing.md` prose list as the starting draft for Defect 2's manifest,
  not as ground truth: it is demonstrably stale (2 of today's 8 live failures are absent from
  it). Any manifest format adopted must be re-derived from a fresh live run, not transcribed from
  that prose section.
- Recommend the manifest be a small structured file (JSON or a simple `name,reason,owning_task`
  text format, mirroring `suite-cost-hints.txt`'s "advisory, human-reviewed, checked-in,
  drift-is-expected" precedent) that `run-all.sh` optionally reads to classify each failure as
  `EXPECTED` vs `NEW` in its summary line and exit-code decision, without changing the underlying
  pass/fail semantics of any individual suite.
- Recommend the wall-clock fix prioritize the `deploy_findings_snapshot()` call sites in
  `orchestrate-cycle-plan.sh`'s redeploy checkpoint (pass `--skip-slow` or an `--only-gate` list
  excluding gate 8) over further `run-all.sh`-internal parallelism work, since task 261 already
  measured and shipped the internal-parallelism lever and found its marginal value degraded
  under the exact load conditions this orchestration system runs under in practice.
- Do not re-open the "should the 5 load-sensitive suites be isolated into the parallel pool"
  question as new research — task 261's Phase 4 audit already closed it with suite-by-suite
  evidence (no fixed-resource collisions found; all 5 are genuine wall-clock/memory-pressure
  assertions that degrade under real ambient load, which isolation cannot fix).
- Do not fix `test-verify-deploy-context-budget.sh`'s Gate 20 findings, `chapter-quality-check.sh`'s
  channel-discipline violation, `validate-artifact.sh`'s repair-aggregation bug, or
  `typst-element-lint.sh`'s uncommitted WIP as part of task 283 — these are real but unrelated
  defects the triage surfaced; quarantine each into the Defect-2 manifest with its own reason and
  spin off (or point to) an owning task rather than expanding task 283's scope.

## Recommendations

1. **Defect 1 — failure roster, not re-naming.** Add a `FAILED_SUITE_NAMES` array populated at
   each existing `[FAIL] $suite_name` / `[FAIL] $suite` echo site (both sequential and parallel
   branches), and print a consolidated block (`[run-all] Failing suites (N):` followed by one
   indented line per name) immediately before the final tally line. Add a new narrow regression
   suite (or extend `test-run-all-parallel.sh`'s existing synthetic-fixture pattern) asserting
   that a deliberately-failing fixture suite's path appears both in an inline `[FAIL]` line and
   in the new roster block, per the dispatch's explicit requirement.
2. **Defect 2 — committed baseline/quarantine manifest.** Introduce a small, human-reviewed,
   checked-in manifest (e.g. `agent-system/extensions/core/scripts/tests/known-failures.txt` or
   `.json`, following `suite-cost-hints.txt`'s advisory-file precedent) with one row per
   known-failing suite: basename, category (consistently-failing / intermittent / real-defect /
   wip-transient), a one-line reason, and an owning task reference where one exists. Have
   `run-all.sh` read it (optionally, never required) to report `"$FAIL_COUNT failed,
   $EXPECTED_COUNT expected, $NEW_COUNT NEW"` and to let a caller (e.g. a future stricter Gate 8
   mode) fail only on `NEW_COUNT > 0`. Seed the manifest from this session's live-verified list
   (5 already-documented + `test-verify-deploy-context-budget.sh` +
   `test-lint-json-channel-discipline.sh`; exclude `test-typst-element-lint.sh` unless it is
   still failing at implementation time), not from the stale `shell-script-testing.md` prose,
   and update that doc to point at the manifest as the source of truth instead of duplicating it.
3. **Defect 2 (mechanical fix folded in) — the shared stale-fixture bug.** Fix
   `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`, and
   `test-orchestrate-recover-message-findings.sh` by adding `return-meta-status-vocabulary.sh` to
   each suite's sandbox `lib/*.sh` copy-list (and `require_file` loop). This alone should clear 3
   of the 8 current failures without touching `run-all.sh` itself, and should ship as its own
   small, easily-reviewed piece of task 283's plan (or, if preferred, spin out as a trivial prep
   task table so this task's own harness-focused artifacts aren't diluted). Consider whether a
   shared helper (e.g. `cp "$CORE_DIR"/lib/*.sh "$WORKDIR/.claude/scripts/lib/"`, mirroring
   `test-force-phases.sh`'s existing glob-copy pattern at its line 106) would prevent this class
   of drift recurring the next time a new core script gains a new `lib/` dependency, versus
   continuing to hand-maintain three parallel hardcoded lists.
4. **Defect 3 — attack orchestrator-side amplification before further harness-internal work.**
   Pass `--skip-slow` (or a curated `--only-gate` list omitting gate 8) to the
   `deploy_findings_snapshot()` calls inside `orchestrate-cycle-plan.sh`'s redeploy checkpoint,
   since that checkpoint's job (detect NEW findings from a redeploy) does not need the full
   105-suite shell-test battery re-run 2-3 times in the same short window when the dispatched
   agent has typically already run it as its own phase gate. This is the single highest-leverage,
   lowest-risk wall-clock fix identified, and requires no change to `run-all.sh` itself.
5. **Defect 3 — do not re-litigate isolation for the 5 load-sensitive suites.** Treat task 261's
   Phase 4 audit as closing this question; if a future task wants to revisit it, it should be
   triggered by a *new* measurement (e.g. this shared dev machine's ambient-load profile
   genuinely changing, per that task's own recorded follow-up), not by re-auditing the same 97
   suites from scratch.
6. **Defect 3 — optional secondary lever**: a changed-files-to-affected-suites selector (e.g. a
   `--affected` flag mapping a git diff's touched paths to the suites most likely to exercise
   them) would let an implementation dispatch's own *interim* phase gates run a small relevant
   subset instead of the full 105, reserving full-suite runs for the final phase gate and the
   redeploy checkpoint. This is a larger, separate design effort and should be scoped as its own
   plan phase (or deferred to a follow-up task) rather than blocking the roster/manifest/
   checkpoint fixes above.

## Risks & Mitigations

- **Risk**: adding a baseline manifest could be used to silently hide a suite from view once
  quarantined, letting it rot indefinitely. **Mitigation**: require an `owning_task` field (or an
  explicit "no owner yet, needs `/spawn`" marker) per manifest row, and treat an unowned
  quarantine entry as a lint-flaggable gap, not a permanently accepted state.
- **Risk**: the `deploy_findings_snapshot()` `--skip-slow` change could let a redeploy checkpoint
  miss a genuine new shell-test regression introduced by the batch just landed. **Mitigation**:
  the dispatched agent's own phase gate already runs the full suite before the checkpoint fires
  (per the dispatch's own "measured cost" account), so the checkpoint's job is redundant
  double-checking, not the only line of defense; if this assumption doesn't hold for every
  caller, scope the flag to only the checkpoint call sites that can prove an already-passing
  agent-side gate immediately preceded them.
- **Risk**: fixing the 3 stale-fixture sandbox suites by hand-adding one filename per list
  reintroduces the same drift the next time a core script gains a new `lib/` dependency.
  **Mitigation**: recommendation 3 above proposes a shared glob-copy helper as the durable fix;
  if the plan phase decides the one-line patch is sufficient for now, record the recurring-drift
  risk explicitly so a future occurrence isn't re-diagnosed from scratch.
- **Risk**: `test-verify-deploy-context-budget.sh`'s underlying Gate 20 violation
  (`skill-orchestrate/SKILL.md` over its context-budget ceiling) is itself real, live repo drift
  that will keep this suite red until someone trims that file. **Mitigation**: quarantine it with
  an explicit owning-task pointer (spin one off via `/spawn` or a follow-up `/task` if none
  exists) rather than let the manifest mask a real, actionable budget regression indefinitely.

## Context Extension Recommendations

- **Topic**: `shell-script-testing.md`'s "Known pre-existing failures and flakes" section.
- **Gap**: This prose list is the only committed record of known-failing suites today, and this
  session found it is stale/incomplete relative to a live run (missing 2 of 8 current failures).
  It also has no machine-readable form, so nothing can compute "expected vs. new" automatically.
- **Recommendation**: once Defect 2's manifest exists (recommendation 2 above), update this
  section to point at the manifest as the single source of truth (`See
  scripts/tests/known-failures.{txt,json} for the current list` or similar) rather than
  maintaining the prose list in parallel — two sources of the same fact is exactly the drift
  mechanism this session observed.

## Appendix

- Live commands run: `bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs auto`
  (105 suites, ~278s, 97 passed / 8 failed / 0 skipped — matches dispatch's tally exactly);
  standalone re-runs of each of the 8 failing suites; `bash
  agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20 --findings` to confirm the
  live Gate 20 findings; `git diff agent-system/extensions/typst/scripts/typst-element-lint.sh`
  to confirm the uncommitted WIP edit; `git log --oneline -- .../run-all.sh` and `git log -L` on
  `orchestrate-cycle-postflight.sh`'s new-lib-dependency block to date the stale-fixture root
  cause against task 258 phase 3 (2026-09-25).
- References: archived `specs/archive/261_reduce_process_spawn_amplification_in_tests/` (plan,
  summary, phase-4-audit-table.txt), `context/standards/shell-script-testing.md`,
  `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`,
  `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`.
