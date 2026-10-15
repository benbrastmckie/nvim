# Research Report: Task #411

**Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
**Started**: 2026-10-14
**Completed**: 2026-10-14
**Effort**: large (multi-phase implementation, per the dispatch's own "costly" severity)
**Dependencies**: None declared
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/verify-deploy.sh`, `scripts/tests/run-all.sh`,
  `scripts/lint/lint-shellcheck.sh`, `scripts/lib/deploy-baseline-lib.sh`,
  `scripts/orchestrate-batch-gate.sh`, `scripts/check-extension-docs.sh`,
  `scripts/tests/suite-cost-hints.txt`, `scripts/tests/known-failures.txt`,
  `scripts/tests/test-verify-deploy-context-budget.sh`, `scripts/lib/manifest-routing-lib.sh`,
  `context/patterns/batch-orchestration-guardrails.md`
- Live empirical measurement: `shellcheck --version`/`--help`, direct and `--only-gate`-scoped
  `verify-deploy.sh` runs, direct lint-script timing, and three `xargs -P` parallelization
  experiments, all taken on this host at `uptime` load 0.60-2.16 (idle) with `nproc`=24
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dispatch's headline cost figure for Gate 22 (lint-shellcheck.sh) does not reproduce on
  an idle machine, and a live parallelization experiment contradicts its proposed fix's expected
  magnitude.** Dispatch claims 542s (contended); a same-host idle re-run measured **75.9s**
  (~7x faster) with 0 findings (not 2). Three `xargs -P` parallelization shapes (`-P24 -n20`,
  `-P4 -n96`, `-P8 -n48`) were all **slower** than the sequential 75.9s baseline (80-91s); only
  true one-process-per-file dispatch (`-P24 -n1`) beat it, at 50.5s — a real but modest **~1.5x**
  win, not the dispatch's implied ~7-15x. See Findings §1 for the full measurement table and the
  likely mechanism (per-process overhead/memory-bandwidth contention, not CPU starvation).
- **A large, cost-relevant gate is entirely absent from the dispatch's own "six gates account
  for virtually all the cost" model.** Gate 3 (`check-extension-docs.sh`, 1,707 lines, content-
  drift hashing across the whole deployed tree, 23 extensions) measured, idle, direct
  invocation: **2m04.171s (124.2s) wall**, with `user 1m01.200s` / `sys 1m04.806s` — a roughly
  even user/sys split indicating heavy syscall volume (consistent with its documented per-file
  diff/hash/line-count comparisons across every extension) rather than either pure CPU work or
  pure I/O wait. At 124s, this is **the single largest individual gate cost measured in this
  research** — larger than lint-shellcheck's 75.9s — and it is not named anywhere in the
  dispatch's Measured Evidence section or its "six gates" cost table.
- **Gate 8's unanchored `grep -F '[FAIL]'` finding-extraction defect is confirmed exactly as
  described**, at `verify-deploy.sh` line ~635, and the SAME unanchored pattern exists at four
  more call sites (lines 564, 592, 710, 743, feeding gates 6/7/10/11 from four different producer
  scripts) plus the sibling `grep -F '[VIOLATION]'` pattern at gates 22/23. None of those four
  sibling producers currently emits a PASS/log message that quotes the literal substring they
  scrape for, so they are not actively broken today — but they share the identical anchoring
  defect and are one future PASS-message wording change away from the same corruption class Gate
  8 just suffered. The registry design should fix this class once, not gate-by-gate.
- **The "12 nested verify-deploy.sh invocations" framing for the Gate 8 straggler
  (`test-verify-deploy-context-budget.sh`) does not match the file on disk.** It contains 4
  invocations today, and its own header comment documents that it was ALREADY reduced from "4
  full-battery invocations (~391s measured)" to "1 full-battery baseline + 3 `--only-gate
  20`-scoped calls (~100s expected)" by a prior change — which matches the 103s cost-hint figure
  the dispatch itself cites. The remaining lever is not "reduce invocation count" (already done)
  but "make the one remaining full-battery baseline call fast," which is just the main registry
  work applied recursively, not a separate special case.
- **`run-all.sh` already contains a mature, well-documented parallel scheduler** (opt-in
  `--jobs N|auto`, `JOBS_CAP=4`, longest-first via advisory `suite-cost-hints.txt`, a
  `LOAD_SENSITIVE_BASENAMES` serialized set, a `wait -n` worker-slot pool, deterministic
  discovery-order output regardless of job count, and a `RUN_ALL_NESTED` guard) that the dispatch
  correctly identifies as the shape to generalize to gate-level scheduling in `verify-deploy.sh`.
  This is real, substantial prior art, not something to design from scratch.
- **Recommended approach**: build the declarative gate registry on the `manifest-routing-lib.sh`
  precedent (data-declared-in-a-file, one shared sourced interpreter) rather than a new paradigm;
  reuse `run-all.sh`'s scheduler shape verbatim for gate-level concurrency; land the Gate 8
  anchoring fix (and its four siblings) as a small, independent, low-risk first phase; and insist
  on a from-scratch idle-machine cost re-measurement (single-gate, `--only-gate`-scoped, averaged
  over at least 2 runs) before finalizing which gates are "slow" and which are "free" — the
  existing evidence table in the dispatch is demonstrably unreliable in both directions.

## Context & Scope

This is a research pass for a `meta`-type task whose edit target is the source store
(`agent-system/extensions/core/**`), covering two tightly coupled subsystems:

1. `verify-deploy.sh` (1,289 lines) — 23 sequential, copy-pasted `if gate_selected N; then ... fi`
   blocks sharing `say()`/`pass()`/`fail()`/`warn()` helpers, a `FINDINGS_LIST` accumulator, and
   `--quiet`/`--findings`/`--skip-slow`/`--only-gate`/`--minimal-init` flags.
2. `tests/run-all.sh` (640 lines) — the suite discovery-and-execution engine behind Gate 8,
   already carrying a proven opt-in parallel scheduler.

Scope also covers the specific, independently-landable Gate 8 finding-extraction defect (an
unanchored substring match corrupting the findings set five downstream consumers read), and the
broader framework redesign goal (parallel, declarative, uniform cost/timeout model). Both are
addressed below. The research did not attempt the implementation itself (no code was changed in
`agent-system/extensions/**`); all commands run were read-only measurement or lint/test
invocations against the existing repository state.

## Findings

### 1. Codebase Patterns — `verify-deploy.sh` structure

- 23 gates, each guarded by `if gate_selected N; then ... fi` (confirmed at lines 308, 335, 386,
  452, 484, 546, 574, 602, 654, 690, 725, 757, 794, 858, 891, 928, 956, 988, 1020, 1071, 1164,
  1194, 1230). `gate_selected()` (line ~287) is the single predicate every gate consults;
  `--only-gate` populates `GATES_FILTER`.
- Most source-store-only gates (3, 5, 6, 7, 9, 10, 11, 12, 17, 18, 19, 21, 22, 23) repeat an
  identical `[ ! -d "$TARGET/agent-system/extensions" ] && say "[SKIP] ..."` guard — a second,
  smaller instance of the copy-paste the dispatch names, and a natural first field in the
  declarative registry (`requires_source_store: true`).
- `FAILURES`/`CHECKS` counters and `FINDINGS_LIST+=("FINDING $CURRENT_GATE ...")` are the only
  cross-gate shared state; `CURRENT_GATE` is a single global reassigned at the top of each block.
  A registry-based runner needs an equivalent per-gate-invocation scope (e.g. a subshell or an
  associative array keyed by gate id) if gates run concurrently, since the current design
  assumes strict sequential reassignment of one shared variable.
- `--findings` output contract: every line is `FINDING gate<N> <text>`, consumed by
  `grep '^FINDING '` downstream (anchored correctly) — the pollution problem is entirely
  upstream, in how `FINDINGS_LIST` is populated from each gate's SUBPROCESS output, not in how
  it's read back out.

### 2. Gate 8's finding-extraction defect — confirmed, and not unique to Gate 8

Confirmed exact code (verify-deploy.sh, in the Gate 8 block):
```bash
while IFS= read -r run_all_line; do
  FINDINGS_LIST+=("FINDING gate8 ${run_all_line#\[FAIL\] }")
done < <(printf '%s\n' "$run_all_output" | grep -F '[FAIL]')
```
`grep -F '[FAIL]'` is unanchored, matching the literal substring anywhere in a line. The
dispatch's prescribed fix — anchor to `run-all.sh`'s own documented contract,
`grep -E '^\[FAIL\] '` — is correct and matches `run-all.sh`'s own header, which states its
verdict rows are exactly `[FAIL] <suite path>` (line-initial) and its narration uses a distinct
`[run-all] [PASS] $suite_name` prefix specifically so Gate 8's scrape never collides with a pass
line.

**The identical unanchored pattern exists at four more call sites**, each scraping a different
producer:
| Line | Gate | Producer scraped | Match pattern |
|---|---|---|---|
| 564 | gate6 | `lint-agent-contracts.sh` | `grep -F '[FAIL]'` |
| 592 | gate7 | `lint-routing-wiring.sh` | `grep -F '[FAIL]'` |
| 635 | gate8 | `tests/run-all.sh` | `grep -F '[FAIL]'` (the named defect) |
| 710 | gate10 | `validate-state.sh --deep` | `grep -F '[FAIL]'` |
| 743 | gate11 | `lint-contract-compliance.sh` | `grep -F '[FAIL]'` |
| (gate22/23 use the sibling `grep -F '[VIOLATION]'` pattern against `lint-shellcheck.sh` /
  `lint-directory-pathspec-boundary.sh`'s own `[VIOLATION]`-prefixed lines — same shape, same
  risk class.) |

All four sibling producers (`lint-agent-contracts.sh`, `lint-routing-wiring.sh`,
`validate-state.sh`, `lint-contract-compliance.sh`) define `log_pass()`/`log_fail()` as
`echo "[PASS] $1"` / `echo "[FAIL] $1"` over an arbitrary free-text `$1`. A `grep -n
'log_pass "[^"]*\[FAIL\]'` across all four found **zero** current PASS messages that quote the
token — so none of the four is actively broken today — but nothing structurally prevents a
future PASS message (e.g. "no `[FAIL]`-style lines found") from reproducing exactly Gate 8's
incident. **Recommendation for the plan**: fix this once, as a shared helper (e.g. a
`verify_deploy_extract_verdict_lines()` function taking the anchor pattern as a parameter) that
every FINDINGS_LIST-populating gate calls, rather than patching five call sites independently and
leaving the same latent defect at gates 22/23's `[VIOLATION]` variant.

`deploy-baseline-lib.sh`'s own consumption (`deploy_findings_snapshot` -> `grep '^FINDING '`) is
already correctly anchored — confirmed via its header and the five real (non-test) callers
(`verify-deploy.sh` itself, `orchestrate-batch-gate.sh`, `orchestrate-cycle-plan.sh`,
`command-gate-out.sh`, plus `deploy-ledger-lib.sh` sourcing it) — so the pollution is fully
contained to the per-gate scrape step inside `verify-deploy.sh`, exactly as the dispatch states.

### 3. The Gate 8 straggler — "12 nested invocations" does not match the code

`test-verify-deploy-context-budget.sh` (335 lines) contains exactly **4** `verify-deploy.sh`
invocations today (`grep -n '"\$VERIFY_DEPLOY"'` at lines 78 (file-existence check, not an
invocation), 175, 189, 309), not 12. Its own header comment (lines 32-39) documents the relevant
history directly:

> "INVOCATION COUNT (historical note, superseded by gate selection): this suite used to keep its
> wall-clock bounded purely by minimizing the number of full-battery verify-deploy.sh calls ...
> That rationale is now superseded: verify-deploy.sh's `--only-gate` flag ... lets run B, case 3,
> and case 4 each pay only for Gate 20, cutting this suite from **4 full-battery invocations
> (~391s measured)** to **1 full-battery baseline + 3 gate-20-only calls (~100s expected)**."

This matches `suite-cost-hints.txt`'s own entry for this suite (`test-verify-deploy-context-
budget.sh,103000`) almost exactly — the straggler has already had its invocation count attacked,
successfully, by a prior change. **The dispatch's framing ("Splitting it, or reducing its 12
nested verify-deploy.sh invocations, is what moves that floor") describes a lever that was
already pulled.** The real remaining cost driver is the ONE full-battery baseline call (needed
to keep "all twenty gates run together, clean" covered somewhere in the suite), which pays for
every other gate's corpus walk once. Moving this floor further means making full-battery
`verify-deploy.sh` itself faster — i.e., the main registry/concurrency work this task already
targets — not a separate suite-level fix.

### 4. Live idle-machine cost measurement — the dispatch's cost table does not reproduce

All measurements below were taken on this host, `uptime` load 0.60-0.92-2.16 (idle), `nproc`=24,
immediately before writing this report, as direct re-runs of the same lint scripts the dispatch
cites. Values are wall-clock `real` from `time`.

| Script / Gate | Dispatch's figure (contended) | This research's idle re-measurement | Direction |
|---|---|---|---|
| `lint-shellcheck.sh` (Gate 22) | 542s (9m02s), rc=1, "2 finding(s)" | **75.9s**, rc=0, "0 finding(s)" | ~7.1x faster; findings also differ |
| `lint-scoped-commit-boundary.sh` (part of Gate 17) | 40,563ms | **67.0s** | ~1.65x **slower** |
| `lint-state-writer-boundary.sh` (Gate 12) | 32,033ms | **17.6s** | ~1.8x faster |
| `lint-hook-registration-paths.sh` (Gate 21) | 15,354ms | **15.7s** | matches |
| `lint-directory-pathspec-boundary.sh` (Gate 23) | 12,935ms | **22.8s** | ~1.76x **slower** |
| `lint-task-lookup-adoption.sh` (Gate 18) | 12,634ms | **21.4s** | ~1.69x **slower** |
| `check-extension-docs.sh` (Gate 3) | not in the dispatch's cost table at all | **124.2s** (2m04.171s; user 61.2s, sys 64.8s) | entirely unaccounted-for; largest single gate measured |
| Gates 6+7+9+10+11+21+23 combined (`--only-gate`) | not itemized individually beyond the 6 named gates | **51.6s** for 7 gates | materially non-"free" |
| Gates 5+13 combined (nvim headless) | not discussed | **2.6s** | negligible, as expected |

Two things follow from this table. First, **direction of drift is inconsistent** — some gates
got much faster idle (shellcheck, state-writer-boundary), others got slower (scoped-commit-
boundary, directory-pathspec-boundary, task-lookup-adoption) — which rules out "contention
inflated everything uniformly" as an explanation; something else (disk-cache state, corpus growth
since the dispatch's own measurement session, or run-to-run variance in `find`-heavy scripts with
high `sys` time) is also in play. Second, **Gate 3 is a large, completely undocumented cost, confirmed at 124.2s idle** (user
61.2s, sys 64.8s) — a roughly even split pointing at heavy syscall/subprocess-fork volume
(consistent with its header's description of per-file diff/hash/line-count content-drift checks
across 23 extensions) rather than pure CPU-bound work, which is exactly the shape that benefits
from reducing subprocess/fork count, not from `xargs`-style parallelization alone. Confirmed
during this same run: a genuine pre-existing `project-wide FAIL: 1 issue(s) found` (all 23
per-extension rows PASS; the one failure is the project-wide check), consistent with the
dispatch's claim of a known pre-existing Gate 3 failure, though this research did not drill into
whether it is specifically the "lean4 doc-lint missing index.json entry" the dispatch names —
worth confirming the exact identity in the plan/implement phase.

**Implication for the plan**: do not carry the dispatch's "six gates account for virtually all
the cost, seventeen are free" model forward as given. Re-derive the true cost table with
`--only-gate`-scoped, idle, averaged-over-N-runs measurements (the dispatch's own Verification
section already mandates an idle re-take for the before/after comparison; this finding shows the
SAME discipline is needed for the baseline evidence that motivates prioritization, not only for
proving the fix worked).

### 5. Parallelizing `lint-shellcheck.sh` — real, but far smaller than claimed, and shape-sensitive

`shellcheck --help` confirms (checked directly, v0.11.0) there is no internal `--jobs`/parallel
flag — any parallelism must be external process-level fan-out. Four `xargs -P` shapes were timed
against the same 381-file corpus, idle, immediately following the 75.9s sequential baseline:

| Invocation shape | Real wall time | vs. sequential (75.9s) |
|---|---|---|
| Sequential (today's code, single invocation, all files) | 75.9s | baseline |
| `xargs -0 -P 24 -n 20` (20 batched invocations) | 84.4s | **+11% slower** |
| `xargs -0 -P 4 -n 96` (4 batched invocations) | 90.9s | **+20% slower** |
| `xargs -0 -P 8 -n 48` (8 batched invocations) | 80.0s | **+5% slower** |
| `xargs -0 -P 24 -n 1` (true one-process-per-file) | 50.5s | **-33% (only shape that wins)** |

All four produced 0 findings, matching sequential — correctness is preserved across every shape
tested, which de-risks parallelization from a correctness standpoint. But performance is
shape-sensitive in a way the dispatch did not anticipate: **batching multiple files per
shellcheck invocation and running several such batches concurrently is counterproductive on this
host** (every batched shape was slower than doing nothing at all), while true one-file-per-
process dispatch gives a real but modest ~1.5x win — nowhere near the dispatch's implied
"~542s to an expected ~25-40s" (which would require roughly a 15-20x speedup matching this
24-core box's core count). The likely mechanism is per-process memory-bandwidth or scheduling
contention when many shellcheck processes run concurrently (user CPU time summed to 8-9 minutes
across all shapes while wall time barely moved or got worse) — shellcheck is a Haskell binary
with its own GC, and GC behavior under concurrent memory pressure is a plausible culprit, though
this research did not isolate the exact cause.

**Recommendation for the plan**: build the parallel shellcheck path as one-process-per-file
(matching run-all.sh's own `run_one()` shape: one unit of work, one background job, output
captured to its own file, `wait -n`-scheduled against a worker cap), target the cap at a modest
number informed by a repeat of this experiment (not a bare `nproc`), and budget for roughly a
1.3-1.8x realistic win on this corpus size, not an order-of-magnitude one. Re-run this exact
experiment as the plan's acceptance test before committing to a specific worker count.

### 6. `run-all.sh` — mature, reusable parallel-scheduler prior art

Confirmed structure (640 lines):
- `--jobs N|auto` (default `JOBS=1`, confirmed at the top-level variable declaration); `auto`
  resolves to `nproc` capped at `JOBS_CAP=4` (line ~189), with the cap's own rejected-alternatives
  note in the header (a bare `nproc` was rejected because several suites rsync a ~16MB fixture or
  launch headless nvim, and N concurrent copies multiplies peak disk/memory past what those
  suites were individually sized for).
- `LOAD_SENSITIVE_BASENAMES` (5 suites: `test-lake-build-guard.sh`,
  `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`,
  `test-four-tier-conflict.sh`, `test-run-all-parallel.sh`) always run alone, serially, before the
  parallel pool starts — an ambient-load precaution, not a resource-collision one (the Phase 4
  audit the comment cites found zero suites with a fixed port/socket/lock path collision).
- Longest-first scheduling via the advisory `suite-cost-hints.txt` (118 lines, ~102 real hint
  rows after its ~16-line header/comment block — close to the dispatch's cited "98 of 147"), with
  a `TOTAL_ACCOUNTED` assertion guaranteeing an unhinted suite is appended, never dropped,
  duplicated, or silently reordered away.
- A `wait -n`-based worker-slot pool (`active` counter against `$JOBS`), per-suite output capture
  to `$OUT_DIR/{out,rc,ms}.$i`, and a final emission loop that walks `"${!SUITES[@]}"` **in
  discovery order** regardless of which order jobs actually finished in — this is exactly the
  determinism property the dispatch's GOAL section demands be preserved, already solved once.
- `RUN_ALL_NESTED=1` nested-invocation guard, forcing `JOBS=1` when run-all.sh is invoked from
  inside one of its own suites (e.g. via a suite that shells out to `verify-deploy.sh`, whose
  Gate 8 is run-all.sh itself).
- No per-suite timeout anywhere — confirmed by inspection (`bash "$suite"` with no `timeout`
  wrapper in either the sequential or `run_one()` parallel path) — matching the dispatch's claim
  #8 exactly.

This is the single most direct piece of prior art for the gate-level scheduler the dispatch asks
for in `verify-deploy.sh`. The plan should port this shape (worker-slot pool, per-unit output
capture, discovery-order final emission, an explicit load-sensitive/serialized carve-out,
dependency declaration as the gate-level analogue of the suite-level "run load-sensitive ones
first, alone") rather than inventing a second concurrency primitive.

### 7. Declarative-registry prior art: `manifest-routing-lib.sh`

`scripts/lib/manifest-routing-lib.sh` (364 lines) is an existing, proven precedent for exactly
the shape the dispatch's MAINTAINABILITY section asks for: data (there, `routing_agents` entries)
declared in a structured file (there, each extension's `manifest.json`), consumed by one shared,
sourced, side-effect-free library implementing a precedence ladder, validated by its own lint
(`lint-routing-wiring.sh`) and test suite (`test-routing-resolution.sh`). Its own header states
the contract discipline a gate registry would need too: never calls `exit`, sets no shell
options a caller inherits, every internal variable explicitly unset before returning. This is a
stronger structural model to build the gate registry on than a bespoke new JSON schema, since its
validation/test pattern (a lint plus a dedicated resolution test) already exists and is familiar
to this codebase's own conventions.

### 8. `orchestrate-batch-gate.sh` — confirmed complementary, not overlapping

Confirmed: `orchestrate-batch-gate.sh` sources `deploy-baseline-lib.sh` and calls
`deploy_baseline_self_attributable_findings` to attribute each batch-level finding back to the
task(s) whose `modified_files` plausibly caused it. Its own header explicitly distinguishes
itself from the Inter-Cycle Redeploy Checkpoint (a different, deploy-boundary-straddling
mechanism) and states it runs the complete gate set exactly once per batch. This confirms the
dispatch's framing precisely: this script changes HOW OFTEN the gate set runs; this task changes
WHAT ONE RUN COSTS. It is also a live, real consumer that benefits directly from the Gate 8
anchoring fix, since a polluted `FINDINGS_LIST` corrupts its attribution input.

### 9. Known pre-existing failures — independently verified

- **Gate 20** (`measure-eager-context.sh --check`): re-ran `verify-deploy.sh --only-gate 20`
  directly against this repo and confirmed the exact failure: `eager-load total (67088 B)
  exceeds recorded baseline (66100 B)` — a 988 B overage, matching the dispatch's "~988B over
  baseline" claim exactly.
- **Gate 8 suites** `test-detect-noop-bash.sh` and `test-guard-git-push.sh` exist under
  `scripts/tests/`; `test-four-tier-conflict.sh` exists as a flat suite directly under `scripts/`
  (not under `scripts/tests/`) — confirmed present, just in the OTHER of the two documented suite
  locations (`scripts/test-*.sh` vs. `scripts/tests/test-*.sh`), which is why an initial
  `scripts/tests/`-only `ls` missed it. No discrepancy once both discovery locations are checked.
- Gate 3 itself was confirmed to have exactly one pre-existing failure (`project-wide FAIL:
  1 issue(s) found`, all 23 per-extension rows PASS) at 124.2s idle wall time (see Findings §4).
  This research did not drill into the failure's exact text to confirm it is specifically the
  "lean4 doc-lint missing index.json entry" the dispatch names — recommend confirming that exact
  identity (re-run `check-extension-docs.sh` without `--quiet`) in the plan/implement phase.

## Decisions

- **Treat the dispatch's Measured Evidence section as a *motivating* data point, not a
  load-bearing cost model.** The registry's actual gate-ordering/concurrency design must be
  derived from a fresh, idle, `--only-gate`-scoped, averaged measurement taken during planning or
  implementation, not from the contended numbers cited in the dispatch (several of which do not
  reproduce, in both directions, per Findings §4).
- **Land the Gate 8 finding-extraction fix as its own small, independent phase**, generalized
  into one shared anchored-extraction helper covering all five unanchored call sites (gates
  6/7/8/10/11) plus the sibling `[VIOLATION]` pattern (gates 22/23), rather than patching Gate 8
  alone and leaving four structurally-identical latent defects. This matches the dispatch's own
  instruction that this piece is "landable on its own, ahead of the larger refactor" — the
  generalization is a natural, low-risk widening of that same phase, not scope creep, since it is
  the same anchoring technique applied to the same `FINDINGS_LIST`-population mechanism.
- **Do not pursue "reduce Gate 8 straggler invocation count" as a distinct work item** — it was
  already done (4 full-battery -> 1 full-battery + 3 scoped). The straggler's remaining cost is
  inherent to the one necessary full-battery call and will shrink automatically as the main
  registry/concurrency work makes full-battery `verify-deploy.sh` faster.
- **Build gate-level concurrency as a direct port of `run-all.sh`'s existing scheduler shape**
  (worker-slot pool via `wait -n`, per-gate output capture, discovery-order final emission, an
  explicit load-sensitive/serialized gate class) rather than a new concurrency primitive — the
  dispatch's own constraint ("the gate-level scheduler should follow that proven shape") is both
  correct and already fully worked out in code to copy from.
- **Build the declarative registry data shape on the `manifest-routing-lib.sh` precedent**
  (structured data file + one shared sourced interpreter + a dedicated lint + a dedicated
  resolution test), not a bespoke new pattern.
- **Re-scope the shellcheck parallelization target** from the dispatch's implied ~15-20x
  ("~542s to ~25-40s") to an evidence-based ~1.3-1.8x, using one-process-per-file dispatch only
  (batched-file dispatch was empirically worse than sequential at every batch size tested).
- **Add Gate 3 (`check-extension-docs.sh`) to the registry's priority list for cost
  investigation** — it is unaccounted-for in the dispatch's own evidence and its wall-time/CPU-
  time profile suggests a different optimization lever (reducing subprocess fork/exec count,
  likely by batching its many per-file `diff`/hash/line-count comparisons) than the gates the
  dispatch focused on.

## Recommendations

1. **Phase 0 (small, independent, land first)**: fix the Gate 8 `grep -F '[FAIL]'` unanchored
   extraction (and generalize to the four sibling call sites plus the `[VIOLATION]` variant at
   gates 22/23) behind one shared helper function. Add the three regression cases the dispatch
   names (line-initial `[FAIL] <path>` selected; a `[PASS]` line quoting `[FAIL]` not selected; an
   indented fixture-internal `[FAIL]` not selected) to `test-orchestrate-batch-gate.sh` /
   `test-deploy-baseline-lib.sh`, plus a producer-side pinning case in
   `test-run-all-selection.sh`. No file_scope change needed beyond what the dispatch already
   states (`verify-deploy.sh` and `tests/run-all.sh` are already declared; `deploy-baseline-
   lib.sh` needs no change).
2. **Phase 1 (cost-model re-baseline)**: before designing the registry's scheduling/dependency
   graph, re-measure every gate idle, `--only-gate`-scoped, at least twice each, including Gate 3
   (not in the dispatch's table at all) and the gates 6/7/9/10/11/21/23 cluster this research
   measured at 51.6s combined (also not individually itemized in the dispatch). Do not reuse the
   dispatch's contended numbers for prioritization.
3. **Phase 2 (declarative registry)**: model the gate registry on `manifest-routing-lib.sh`'s
   shape — a structured data declaration (name, command, dependencies, timeout, cost class,
   remedy text per the dispatch's own field list) plus one shared sourced runner library, with
   its own lint and resolution test, replacing the 23 copy-pasted `if gate_selected N; then` blocks.
4. **Phase 3 (gate-level concurrency)**: port `run-all.sh`'s scheduler verbatim in shape (worker-
   slot pool via `wait -n`, per-gate captured output, discovery-order final emission, declared
   dependencies as the gate-level generalization of the suite-level load-sensitive/serialized
   carve-out).
5. **Phase 4 (shellcheck parallelization)**: implement as one-process-per-file dispatch only
   (not batched `xargs -n N>1`), sized to a worker cap chosen from a repeat of this research's
   experiment, not a bare `nproc`; budget for a ~1.3-1.8x win.
6. **Phase 5 (shared corpus enumeration)**: replace each lint's own `find`/`git ls-files` walk
   with one shared enumeration (a single `git ls-files` call over `agent-system/extensions/`,
   produced once per `verify-deploy.sh` invocation) that every gate filters in-memory by its own
   extension/path pattern, rather than re-walking the filesystem per gate. Note this is NOT
   literally "six lints share one `git ls-files -- '*.sh'` call" as the dispatch's evidence item
   #7 states — only `lint-shellcheck.sh` currently uses `git ls-files`; the rest use `find` with
   differing per-lint extension filters (`*.sh`, `*.md`, `*.sh`+`*.md` combined, `*.json`,
   `SKILL.md`, `manifest.json`). The shared mechanism therefore needs to produce one master
   tracked-path list and let each gate derive its own filtered view from it, not assume a single
   list satisfies every gate unmodified.
7. **Phase 6 (`run-all.sh` default)**: flip the bare-invocation default from `JOBS=1` to `auto`,
   preserving the explicit `--jobs 1` opt-out and the byte-identical sequential code path
   (already structurally separate in the code, per Findings §6 — this is a low-risk, almost
   data-only change).
8. **Phase 7 (timeout discipline)**: add a uniform per-gate and per-suite timeout, with a
   deliberately-stalled fixture test proving it fires (dispatch's own Verification requirement).

## Risks & Mitigations

- **Risk**: re-deriving the cost model mid-implementation discovers the true dominant cost is
  Gate 3 or the gates-6/7/9/10/11/21/23 cluster, not Gate 22 — which would invalidate a plan that
  over-invests in shellcheck parallelization relative to its real share of total wall time.
  **Mitigation**: Phase 1 above is placed before the registry design specifically to catch this;
  do not let shellcheck parallelization (Phase 4) consume disproportionate planning effort before
  Phase 1's numbers are in.
- **Risk**: a worker-count choice for shellcheck parallelization, chosen without repeating this
  research's experiment, could regress wall time (as three of four tested shapes did here).
  **Mitigation**: treat Phase 4's experiment as a required, repeatable acceptance gate, not a
  one-off; the shape (true one-process-per-file, not batched) is the load-bearing choice, more
  than the exact worker count.
- **Risk**: concurrent gate execution surfaces a real resource collision `run-all.sh`'s own
  parallelism-safety audit never had to consider (verify-deploy.sh gates write/read different
  files than suites do — e.g. gate 20's fixture files, gate 13's `find_orphans` nvim invocation).
  **Mitigation**: the dispatch already requires "Parallelism-safety must be established per gate
  and per suite, not assumed" and explicitly asks to extend `run-all.sh`'s existing audit
  discipline rather than inventing a new one — treat this as a mandatory per-gate audit step in
  the implementation plan, not an afterthought.
- **Risk**: generalizing the Gate 8 fix to a shared helper (Phase 0) could itself introduce a
  regression if the four sibling gates' producer output shapes differ subtly (e.g. `grep -F
  '[VIOLATION]'` vs. `grep -F '[FAIL]'` is a different token entirely). **Mitigation**: the shared
  helper should take the anchor pattern as an explicit parameter per call site (never infer it),
  and each of the five+two call sites needs its own pinning regression case, not one shared test
  assumed to cover all.

## Context Extension Recommendations

- **Topic**: idle-vs-contended measurement discipline for this repository's own gate/lint cost
  claims.
- **Gap**: nothing in `.claude/context/` currently warns that a cost figure measured "same
  session" alongside other heavy concurrent activity can be wrong in EITHER direction (not just
  inflated) relative to a clean re-measurement — this research found both directions in the same
  small sample.
- **Recommendation**: a short addition to `context/standards/shell-script-testing.md` (or a new
  pointer from it) stating that any cost claim cited in a task description or report as
  justification should be accompanied by the `uptime` load average at measurement time, and that
  a load average above ~2 on this host invalidates the figure for prioritization purposes until
  re-taken idle.

## Appendix

### Search queries / commands used

- `grep -n '^# Gate [0-9]' / 'if gate_selected' verify-deploy.sh`
- `grep -n "grep -F '\[FAIL\]'" verify-deploy.sh`
- `shellcheck --version`, `shellcheck --help | grep -i -E 'job|parallel|thread'`
- `time bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh --quiet` (idle re-run)
- `xargs -0 -P{24,4,8} -n{20,96,48,1} shellcheck -x -S warning -f gcc` (four parallelization
  shapes, same corpus, same host, same idle window)
- `time bash .../lint-scoped-commit-boundary.sh --verbose`, same for
  `lint-state-writer-boundary.sh`, `lint-hook-registration-paths.sh`,
  `lint-directory-pathspec-boundary.sh`, `lint-task-lookup-adoption.sh`
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate
  {3,5,13,20,6,7,9,10,11,21,23} --findings --quiet .` (scoped re-measurements; gate 3 did not
  complete within budget)
- `grep -rl "deploy_findings_snapshot|deploy-baseline-lib" scripts/ --include='*.sh'`
- `grep -rln "git ls-files" lint/*.sh` and a per-file `find`/`git ls-files` survey across the 13
  named lint scripts

### References

- `agent-system/extensions/core/scripts/verify-deploy.sh`
- `agent-system/extensions/core/scripts/tests/run-all.sh`
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh`
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh`
- `agent-system/extensions/core/scripts/check-extension-docs.sh`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`
- `agent-system/extensions/core/scripts/tests/known-failures.txt`
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
- `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
