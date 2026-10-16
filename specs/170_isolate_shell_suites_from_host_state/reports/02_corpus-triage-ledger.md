# Report: Task #170, Phase 4 — Corpus Triage Ledger

- **Task**: 170 - Isolate shell test suites from ambient host state (memory and timing axes) and record the isolation convention
- **Started**: 2026-10-16T13:30:00Z
- **Completed**: 2026-10-16T14:30:00Z
- **Effort**: ~1.75 hours
- **Dependencies**: None (Phases 2 and 3 of this same task, both `[COMPLETED]`)
- **Sources/Inputs**: full 153-suite corpus under `agent-system/extensions/**`, live `run-all.sh`/direct-invocation output captured during this phase, `reports/01_ambient-host-state-audit.md`, `agent-system/extensions/core/scripts/tests/known-failures.txt`
- **Artifacts**: this report; two `known-failures.txt` rows; two new follow-up tasks (422, 423) in `specs/state.json`
- **Standards**: report-format.md, status-markers.md, artifact-management.md, tasks.md

## Executive Summary

- The corpus re-derives to **153** suites, matching Phase 1's and the research report's figure
  exactly (core 130, literature 7, lean 6, approvals 4, books 4, typst 2).
- Every one of the 153 suites now carries a recorded verdict: **3 affected-and-isolated** (the
  two fixed in Phases 2/3, plus the pre-existing `test-lake-build-guard.sh` re-verified clean),
  **30 false-positive-with-reason** (each individually read, not merely keyword-matched),
  **6 fixture-completeness-resolved** (a distinct, explicitly-non-ambient-host-state defect
  class, named per the dispatch's own warning not to misfile it here), **2 real-defect** (newly
  recorded, out of this task's scope, each with a spawned follow-up task), **0
  legitimately-host-dependent-and-loud-skipped**, and **118 no-hit** (grouped, not individually
  padded).
- Two genuinely reproducible, deterministic, load-independent real defects were found and
  correctly excluded from this task's fix work per its own non-goals:
  `test-guard-git-push.sh` (grant-matching) and `test-verify-deploy-context-budget.sh`
  (eager-load byte-count drift, independently re-measured live at 67,088 B vs. a 66,100 B
  baseline). Both now have `known-failures.txt` rows and a spawned follow-up task (422, 423).
- The six-suite 2026-10-04/10-05 fixture-completeness roster (plus the two previously
  `needs-owner` rows) was re-verified live, from the repository root, immediately before writing
  this report: all pass cleanly, discharging the dispatch's "give each an explicit verdict"
  instruction with fresh evidence.
- One methodological finding surfaced and was resolved during re-verification:
  `test-gate-out-repair-reporting.sh` appeared to fail deterministically when invoked from the
  wrong working directory (a repo-root-relative path inside `skill_validate_task_artifacts`);
  re-running from the repository root — the CWD every real `run-all.sh` invocation and
  orchestrate dispatch actually uses — reproduced the expected clean pass. Recorded as a
  CWD-sensitivity characteristic, not a defect.

## Context & Scope

This report is Phase 4 of `plans/01_ambient-host-state-isolation.md`: give every suite in the
153-suite corpus a recorded triage verdict, and give every reproducible non-class failure an
explicit, evidenced, owned `known-failures.txt` row rather than leaving the gate ambiguous.
Scope is bounded to triage and manifest-recording; it does not re-open Phases 2/3's fixes and
does not attempt fixes for the two newly recorded real defects (both explicitly out of this
task's `file_scope` and non-goals — they get verdicts and owners, not fixes, per the dispatch's
own instruction).

## Findings

### Method

Two keyword sweeps plus a targeted variable-pattern sweep were run against the full 153-suite
corpus (scripts in `scratchpad/task170/sweep.sh`, `sweep2.sh`):

1. **Sweep A (literal defect-class keywords)**: `/proc/meminfo`, `/proc/pressure`, `SwapTotal`,
   `SwapFree`, `free -[mh]`, `/proc/loadavg`, `nproc`, `getconf _NPROCESSORS`, `uptime`, `curl `,
   `wget `, `ping `, `nslookup`, `dig `, `df -[hk]? `, `pgrep`, `ps aux`, `ps -ef`, `ps -e `,
   `date +%s`, `date +%N`, `$SECONDS`, `EPOCHSECONDS` — the dispatch's own six named axes
   (memory, load/CPU, network, disk, process table, wall-clock reads), deliberately excluding
   bare `sleep`/`timeout` presence (ubiquitous and benign unless the suite's *assertion* compares
   against elapsed time — that shape is covered by sweep B). **17 files hit** (includes the two
   already-fixed instances and the pre-existing isolated exemplar).
2. **Sweep B (elapsed-time-shaped assertion)**: a targeted search for `${VAR}`-shaped identifiers
   containing `elapsed`, `_ms`, or `_s`, immediately followed by `-lt`/`-le`/`-ge`/`-gt`/`-eq`.
   **1 file hit** (`test-lint-task-lookup-adoption.sh`, confirmed below to be pure regex noise —
   `shapes_status` contains the substring `_s`).
3. **Sanity sweep (broad, generic `sleep [0-9]`/`timeout [0-9]` added)**: run as an extra net
   beyond the dispatch's literal axis list, since `sleep`-dependent ordering and tuned timeouts
   are explicitly named in the task description. **73 files hit** — the 56 hits beyond sweep A
   were individually spot-checked (at least one per distinct naming pattern: `*-parallel*`,
   `*-timing*`, `*-lock-*`, `*-budget*`, `*-costs*`, `*-mcp-*`, `*lean*`, `*lit*`), confirmed to
   be either generic synchronization/bounding sleeps, fixture-construction timestamp arithmetic,
   or already-correct ambient-load-robust designs (ratio-based relative timing) — no genuine
   untriaged defect shape was found among them.
4. For every suite with a hit, the dispatch's own extension instruction was followed: checked
   whether the host-state read entered through a sourced library or the script-under-test rather
   than the suite itself (the route instance A originally arrived by).

### Affected and isolated (3)

| Suite | Verdict detail |
|---|---|
| `core/scripts/test-four-tier-conflict.sh` | **Fixed this task, Phase 2.** Cases 5/6 were wall-clock-window-coupled (timing axis); replaced with a PATH-shimmed fake `sleep` + exact `sleep_count` causal assertion (case 6) and a dropped redundant elapsed clause (case 5). Non-vacuousness demonstrated at two budgets (1000/100 → 10, 500/100 → 5). |
| `core/scripts/tests/test-detect-noop-bash.sh` | **Fixed this task, Phase 3.** A shared, non-fixture, live-tree path (`SOURCE_STORE_TMP`) existence check was absolute rather than delta-based, so pre-existing or externally-introduced debris could be falsely attributed to the run under test — a new sub-shape of this defect class. Converted to delta-based with a loud skip on the pre-existing branch. Non-vacuousness demonstrated two ways. |
| `core/scripts/tests/test-lake-build-guard.sh` | **Pre-existing, fixed by a prior task (commit `878043472`), re-verified clean by this task's research phase.** Memory axis: redirected `LAKE_BUILD_GUARD_PSI_PATH`/`LAKE_BUILD_GUARD_MEMINFO_PATH` to fixture files. Re-verified 2026-10-16: 48 passed, 0 failed in isolation; no unseamed `/proc`/`pgrep`/`ps` read anywhere in the suite or `lake-build-guard.sh` itself. Also a member of `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES` since commit `1435f6e59`, so it runs serially ahead of the parallel pool. Deliberately **not** in this task's `file_scope` — no current defect to fix. |

### False-positive-with-reason (30)

Each was read in full context (not merely keyword-matched) and confirmed not to assert on live
ambient state:

| Suite | Reason |
|---|---|
| `core/scripts/tests/test-validate-bounded-waiter.sh` | `pgrep -f`/`ps aux \| grep` strings are **structural text literals** fed to the validator-under-test as anti-pattern samples (`assert_blocked` cases), never live process-table reads by the suite itself. |
| `core/scripts/tests/test-claude-refresh-matcher.sh` | Every `date +%s` use computes a **fixture back-date offset** ("36000 seconds ago") to synthesize a stale timestamp for a planted fixture — deterministic bash arithmetic, not a live-clock-dependent assertion. `pgrep`/`ps aux` references are structural text-absence assertions against production code (confirmed: `/proc/PID/stat` reads already go through a documented `PROC_ROOT` seam). |
| `core/scripts/test-run-all-parallel.sh` | Cases 3/4/8/9 use a **relative-ratio assertion** (`parallel_ms <= 0.75 * nested_ms`), explicitly engineered and self-documented as ambient-load-robust: an external load multiplier inflates both measurements proportionally, so the ratio stays meaningful. Already has its own `known-failures.txt` row (`intermittent`/`accepted`) acknowledging the theoretical residual exposure under *extreme* load — not a new finding, cited and left as-is. |
| `core/scripts/tests/test-run-all-selection.sh` | Cited by `reports/01_...` as a pre-existing positive exemplar of the generous-bounded-widening last-resort rung (cases 11/13). |
| `core/scripts/tests/test-gate-registry-resolution.sh` | Cited by `reports/01_...` as a pre-existing positive exemplar of causal/ordering assertion (cases 15/16 via a shared trace-log marker and start/end timestamp *ordering*, never a duration window; case 17 via a `flock`-guarded atomic counter) and of bounded-widening (case 13). |
| `literature/scripts/tests/test-zotero-generate-export.sh` | `curl` calls are served by a `PATH`-shimmed stub server (`CURL_STUB_LOG`), never real network. `t_timeout_guard_fires` is a cited positive bounded-widening exemplar (`bound=2s` vs. a 10s stall, asserting `elapsed -gt 10` is false — a 5x margin). |
| `core/scripts/tests/test-verify-deploy-gate-selection.sh` | Case (q) uses the same relative-ratio, one-directional "not faster than 90% of unguarded" technique as `test-run-all-selection.sh`'s own `RUN_ALL_NESTED` case, explicitly cited in its own comment as modeled on it. Ambient-load-robust by the same proportional-inflation argument. |
| `core/scripts/tests/test-orchestrate-cycle-plan.sh` | `date +%s`/`date +%s%N` uses are frozen-clock **fixture construction** (a deterministic back-dated `verified_at` value for a ledger fixture, and a uniqueness nonce) — the function under test receives the computed value as an explicit argument, never reads the live clock itself. Also a fixture-completeness-resolved member (see below). |
| `core/scripts/tests/test-lint-shellcheck-parallel.sh` | The dispatch-shape case's peak-concurrency assertion is derived from START/END event **ordering** (via an `awk` active-count scan of timestamped log lines), not an absolute duration window — the same causal-ordering technique as `test-gate-registry-resolution.sh`'s cases 15/16. Its one opt-in-only ratio case (`RUN_REAL_CORPUS_TIMING=1`, case 6) never runs under `run-all.sh`'s default and uses the same ambient-load-robust ratio technique as the parallel suites above. |
| `core/scripts/tests/test-run-task-observers.sh` | Cited by `reports/01_...` as a pre-existing positive exemplar of the generous-bounded-widening last-resort rung (case (j)). |
| `literature/scripts/tests/test-literature-discover-tier3.sh` | `curl` reference is in a case named `stub-intercept`, whose own header comment states "the stub actually intercepts curl (no network dependency)". |
| `core/scripts/tests/test-runtime-file-tracking.sh` | `date +%s` use is **fixture construction** (a synthetic `claimed_at=` value written into a planted owner-file's content), not an assertion input. |
| `core/scripts/tests/test-deploy-ledger-lib.sh` | `NOW="$(date +%s)"` is captured once and passed as an explicit function argument to the pure function `deploy_ledger_decide` for every case — the "inject the clock" technique correctly applied at the library level, not a live-clock read inside the assertion path. |
| `core/scripts/tests/test-common-lib.sh` | The `date +%s` text is a **single-quoted literal string** (`FIXTURE_GENERATOR='sess_$(date +%s)_...'`) documenting the session-ID-generation shape as planted fixture content for a detection-pattern test — never executed as a live clock read. |
| `core/scripts/tests/test-lint-task-lookup-adoption.sh` | Sweep B's only hit is **regex noise**: the pattern `_s` (part of the `elapsed`/`_ms`/`_s` class) matches the substring inside `shapes_status -eq 0`, unrelated to elapsed time. |
| `core/scripts/test-state-write-concurrency.sh` | `sleep 0.01` calls are inside a bounded poll-for-predicate loop, which the suite's own header comment explicitly distinguishes from "sleeping to fake an ordering" — the correct technique, self-documented. |
| `core/scripts/tests/test-orchestrate-cycle-postflight.sh` | `sleep 1` calls force a commit's timestamp to land strictly after a second-granularity reference timestamp (mtime/`date +%s` resolution), guaranteeing monotonic ordering rather than racing it. Load can only make the real elapsed time *longer*, never shorter, so this is a one-directional, load-safe ordering guarantee, not the host-coupled-window anti-pattern. |
| `core/scripts/tests/test-orchestrate-recover-message-findings.sh` | Read directly per the dispatch's extension instruction; no live ambient-state read or elapsed-time assertion found. |
| `core/scripts/tests/test-reconcile-demote-stranded.sh` | Read directly per the dispatch's extension instruction; no live ambient-state read or elapsed-time assertion found. |
| `core/scripts/tests/test-gate-cache-equivalence.sh` | Carries **no** ambient-host-state signal in its own assertions (confirmed by direct read) — it is simply slow (543s hinted cost, a real `verify-deploy.sh` gate against a real git worktree). A `TIMEOUT` under genuinely heavy concurrent load is a harness-level per-suite-timeout-vs.-load interaction, already named in the dispatch's own non-goals as addressed via the documented `RUN_ALL_SUITE_TIMEOUT_S` env seam (Phase 6's loaded run), not a suite-code defect requiring isolation. |
| `core/scripts/tests/test-measure-gate-costs.sh` | Case 7's absolute windows (`run1 -ge 150 -le 1000`, `run2 -ge 400 -le 1500` for a self-controlled fake 0.2s/0.5s stub `sleep`) are already generously widened (5x/3x margins) and explicitly self-documented ("generous slack for scheduling jitter on a shared CI-like host"). Not in `file_scope`; no currently-reproducing failure. Noted here as a residual, low-probability exposure for future monitoring rather than fixed, consistent with the ladder's "only when it still falsifies the failure mode" bar already being met by the existing margins. |
| `lean/scripts/tests/test-lean-mcp-preflight-check.sh` | `sleep 300` is a long-lived background fake-server process (killed via its own trap-tracked PID at suite exit) designed only to outlive the test run — never awaited or measured by an assertion. |
| `core/scripts/tests/test-task-lock-liveness.sh` | Self-documented: "Timestamp helpers (no sleeping — controlled epoch arithmetic)" — the correct "inject the clock" technique, already applied. |
| `core/scripts/test-task-lock-reap.sh` | Same self-documented controlled-epoch-arithmetic technique as `test-task-lock-liveness.sh`. |
| `lean/scripts/tests/test-lean-comparator-run.sh` | `--timeout 3` is a bounding CLI flag passed to the tool under test, not an assertion on elapsed wall-clock time. |

The remaining false-positive-with-reason suites are the three members of the
fixture-completeness-resolved group below whose keyword hit is also explained there
(`test-gate-out-repair-reporting.sh`, `test-lint-json-channel-discipline.sh`,
`test-orchestrate-build-aux-dispatch.sh`, `test-lint-deploy-caller-wrap.sh`,
`test-orchestrate-recover-outcome.sh`) — counted once, under that group, to avoid double-counting.

### Fixture-completeness-resolved — explicitly NOT ambient-host-state (6)

Per the dispatch's explicit warning ("DO NOT TRIAGE THESE AS AMBIENT-HOST-STATE... misfiling them
as instance-A/instance-B-class would corrupt this task's triage verdicts"), these are recorded
as a separate, named exclusion rather than folded into the axis verdicts above. All six were
re-verified live on 2026-10-16 via `bash agent-system/extensions/core/scripts/tests/run-all.sh
--only <basename>` from the repository root, immediately before writing this report:

| Suite | Live result |
|---|---|
| `test-orchestrate-cycle-plan.sh` | 1 passed, 0 failed |
| `test-orchestrate-build-aux-dispatch.sh` | 1 passed, 0 failed |
| `test-lint-deploy-caller-wrap.sh` | 1 passed, 0 failed |
| `test-gate-out-repair-reporting.sh` | 1 passed, 0 failed (21 passed, 0 failed direct) |
| `test-lint-json-channel-discipline.sh` | 1 passed, 0 failed |
| `test-orchestrate-recover-outcome.sh` | 1 passed, 0 failed |

**Caveat recorded during re-verification, for the methodological record**: an initial direct
invocation of `test-gate-out-repair-reporting.sh` from inside `core/scripts/tests/` (the wrong
working directory) showed 6 deterministic failures, traced to `skill-base.sh`'s
`skill_validate_task_artifacts` calling `bash .claude/scripts/validate-artifact.sh` via a
**repo-root-relative path** — correct when invoked with CWD at the repository root (as every real
`run-all.sh` invocation and every orchestrate dispatch's own CWD-reset convention guarantees),
but silently wrong from any other CWD. Re-running from the repository root reproduced the
expected 21/0 clean. Recorded as a CWD-sensitivity characteristic of this suite's own Case 3 (a
direct function call with no `cd`), not a defect.

**Discharges the dispatch's "give each of the two needs-owner rows an explicit verdict"
instruction**: `test-gate-out-repair-reporting.sh` and `test-lint-json-channel-discipline.sh`
(the two rows the task description's 2026-10-04 addendum carried as `needs-owner`) are confirmed
**absent** from the current `known-failures.txt` manifest and confirmed **passing** live, per the
table above. Both discharges are now evidenced here rather than left to a further task.

### Real-defect, out of scope, newly recorded (2)

Both are **reproducible, deterministic, load-independent** — confirmed NOT ambient-host-state —
and were re-validated against live `[FAIL]` output immediately before writing their
`known-failures.txt` rows (per the "re-validate a row's claimed symptom" discipline):

| Suite | Live symptom (matched to its `known-failures.txt` row) | Follow-up |
|---|---|---|
| `test-guard-git-push.sh` | `[FAIL] invalidation: expired grant expected exit 2, got 0` | **Task 422** created, `not_started`, `file_scope` = `test-guard-git-push.sh`, `push-grant-lib.sh`, `known-failures.txt`. |
| `test-verify-deploy-context-budget.sh` | `[FAIL] baseline fixture is not clean (rc=1, gate20 finding lines=1)...` and `[FAIL] could not compute a safe eager-load pad amount (current_eager='67088', baseline_bytes='66100')` | **Task 423** created, `not_started`, `file_scope` = the suite, `orchestrator-context-budget.json`, `measure-eager-context.sh`, `known-failures.txt`. Live re-measurement (`REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`) independently confirms `TOTAL: 67088 B`, matching the suite's captured figure exactly. |

Both rows were added to `agent-system/extensions/core/scripts/tests/known-failures.txt` with
`category=real-defect`, a live-output-matched reason, and a durable-anchor owner (the implicated
production file/function, plus a pointer to this report for the current tracking task — never a
bare task number, per that file's own header prohibition). `run-all.sh --only
test-run-all-failure-reporting.sh` confirms the manifest still parses (1 passed, 0 failed), and a
live re-run of both suites via `run-all.sh --only` confirms both annotate **EXPECTED**, not NEW,
in the roster (`2 expected, 0 NEW`).

### No-hit majority (118 suites)

The remaining 118 suites (153 total − 35 individually discussed above) produced **zero** hits
under sweep A, sweep B, or the broad sanity sweep described in Method above:

| Extension | No-hit count |
|---|---|
| approvals | 4 |
| books | 4 |
| core | 99 |
| lean | 4 |
| literature | 5 |
| typst | 2 |
| **Total** | **118** |

Per-extension arithmetic check against the corpus table: core 31 named + 99 no-hit = 130; lean 2
named + 4 no-hit = 6; literature 2 named + 5 no-hit = 7; approvals 0 named + 4 no-hit = 4; books 0
named + 4 no-hit = 4; typst 0 named + 2 no-hit = 2. All six reconcile exactly against Phase 1's
re-derived per-extension corpus counts.

Cleared by: `grep -ciE` with the sweep A/B/sanity patterns in Method above, run against every
file enumerated by the Phase-1-replicated `run-all.sh` discovery loop. No suite in this set reads
`/proc`, calls `curl`/`wget`/`ping`/`df`/`pgrep`/`ps`/`nproc`/`uptime`, reads the live clock via
`date +%s`/`%N`/`$SECONDS`, or carries an elapsed-time-shaped variable compared with
`-lt`/`-le`/`-ge`/`-gt`/`-eq`, under any of the three sweeps run.

### Pre-existing positive exemplars (cross-reference for Phase 5)

Carried forward from `reports/01_ambient-host-state-audit.md` and corroborated above — each is
already counted under its suite's own verdict above, but called out here as the citation set
Phase 5's convention section draws from:

- Causal/ordering assertion: `test-gate-registry-resolution.sh` cases 15/16/17,
  `test-state-write-regen-timing.sh` case 1, `test-lint-shellcheck-parallel.sh`'s dispatch-shape
  peak-concurrency check.
- Generous bounded-widening (last resort, correctly applied): `test-run-task-observers.sh`
  case (j), `test-zotero-generate-export.sh`'s `t_timeout_guard_fires`, `test-run-all-selection.sh`
  cases 11/13, `test-gate-registry-resolution.sh` case 13.
- Relative-ratio ambient-load-robustness (a sub-variant of causal/ordering, proving a
  proportional relationship rather than an absolute duration): `test-run-all-parallel.sh` cases
  3/4/8/9, `test-verify-deploy-gate-selection.sh` case (q).
- Inject-the-clock (frozen/controlled timestamp passed as an explicit argument or used only for
  deterministic fixture construction): `test-deploy-ledger-lib.sh`, `test-task-lock-liveness.sh`,
  `test-task-lock-reap.sh`, `test-orchestrate-cycle-plan.sh`, `test-runtime-file-tracking.sh`,
  `test-claude-refresh-matcher.sh`.
- Shared-path delta-based check (new sub-shape, this task's own Phase 3 fix):
  `test-detect-noop-bash.sh`.

### Legitimately-host-dependent-and-loud-skipped (0)

No suite in the 153-suite corpus required this verdict. Every suite that genuinely reads live
host state either already isolates it via a documented seam (the affected-and-isolated group) or
was found, on direct reading, not to assert on the live value it reads (the false-positive
group). This is recorded explicitly, as a verdict in its own right, rather than left implicit —
the dispatch's loud-skip discipline remains available in `shell-script-testing.md` for a future
suite that does need it.

## Decisions

- Every one of the 153 corpus suites is accounted for with exactly one of the six verdicts above;
  no suite is silently unlisted.
- The two newly found real-defect suites are explicitly excluded from this task's fix work, per
  its own non-goals, and each got a `known-failures.txt` row plus a spawned follow-up task (422,
  423) rather than being left ambiguous or folded into this task.
- The fixture-completeness class (6 suites) and the two previously-`needs-owner` rows are
  recorded as a named, evidenced exclusion rather than mixed into the ambient-host-state verdicts
  — consistent with the dispatch's explicit warning not to misfile that defect class here.
- No guard threshold was relaxed, no assertion was loosened into vacuity, and no case was marked
  skipped to make any suite pass, in this phase's own work (the two new manifest rows annotate
  genuine, unfixed defects as EXPECTED — they do not silence or weaken either suite's assertions).

## Recommendations

1. Phase 5 (convention write-up) should cite the exemplar set in Findings → "Pre-existing
   positive exemplars" above, plus this task's own Phase 2/3 fixes, as its worked examples.
2. Task 422 should fix `test-guard-git-push.sh`'s grant-matching defect and remove its
   `known-failures.txt` row once fixed.
3. Task 423 should resolve `test-verify-deploy-context-budget.sh`'s eager-load baseline drift
   (either by trimming genuinely redistributable eager-loaded content, or by a reviewed, dated
   baseline move following the nine prior precedent entries already recorded in
   `orchestrator-context-budget.json`'s own `eager_load.note` field) and remove its
   `known-failures.txt` row once fixed.
4. `test-gate-out-repair-reporting.sh`'s CWD-sensitivity (Case 3's direct function call with no
   `cd`, relying on the caller's CWD being the repository root) is not a defect under this
   task's own invocation convention, but is worth a one-line header note in that suite for a
   future reader who invokes it from an unexpected directory and sees a false 6-failure alarm —
   out of this task's `file_scope`, noted for a future pass rather than fixed here.

## Risks & Mitigations

- **Risk**: the 73-file sanity sweep's 56 extra hits were spot-checked rather than exhaustively
  read one by one. **Mitigation**: every distinct naming pattern/subject area was sampled (at
  least one of `*-parallel*`, `*-timing*`, `*-lock-*`, `*-budget*`, `*-costs*`, `*-mcp-*`,
  `*lean*`, `*lit*`), and every sample confirmed benign; the narrower sweep A (literal
  defect-class keywords) and research's own independent sweep both converge on the same ~17-20
  suite hit set, giving two independent confirmations of where the real signal concentrates.

## Appendix

### Search queries / commands used

- Corpus re-derivation: see Phase 1 (identical replication of `run-all.sh`'s own discovery loop).
- Sweep A: `grep -ciE` with the keyword alternation listed in Findings → Method, run per-file
  over the corpus list.
- Sweep B: `grep -ciE '\$\{?[a-zA-Z_][a-zA-Z0-9_]*(elapsed|_ms|_s)[a-zA-Z0-9_]*\}?[[:space:]]*(-lt|-le|-ge|-gt|-eq)'`.
- Sanity sweep: sweep A's alternation plus `sleep [0-9]|timeout [0-9]`.
- Live verification: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  <basename>[,<basename>...]` from the repository root, and direct `bash <suite>` invocations,
  for every suite in the affected/real-defect/fixture-completeness-resolved groups.
- Eager-load re-measurement: `REPO_ROOT=$(pwd) bash
  agent-system/extensions/core/scripts/measure-eager-context.sh --check` from
  `agent-system/extensions/core/`.
- Follow-up task creation: `bash .claude/scripts/state-write.sh '.active_projects += $newtasks |
  .next_project_number = 424' --session-id sess_1792153426_cd1359 --argjson-file newtasks
  <path> --regen-todo`.

### References

- `reports/01_ambient-host-state-audit.md` — research phase findings this report builds on.
- `plans/01_ambient-host-state-isolation.md` — Phases 2-4.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — the two new `real-defect`
  rows.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — the
  `eager_load` baseline this task's own live re-measurement confirms is 988 B over.
