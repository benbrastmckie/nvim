# Research Report: Task #265

- **Task**: 265 - Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs
- **Started**: 2026-09-29T22:43:00Z
- **Completed**: 2026-09-29T23:20:00Z
- **Effort**: ~1 hour (research)
- **Dependencies**: Task 266 (deploy-pending/identical-dispatch guard) — COMPLETED, archived at
  `specs/archive/266_deploy_pending_vs_identical_dispatch_guard/`. Unblocked.
- **Sources/Inputs**: Codebase (verify-deploy.sh, run-all.sh, deploy-headless.sh,
  orchestrate-cycle-plan.sh, command-gate-out.sh, test-lint-deploy-caller-wrap.sh,
  test-run-all-parallel.sh), `context/patterns/batch-orchestration-guardrails.md`,
  `context/standards/shell-script-testing.md`, task 261's archived plan/summary, live experiment
  (reproducing a test-suite defect)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- Task 261 (archived, COMPLETED WITH EXCLUSIONS) already added opt-in `--jobs N|auto` to
  `run-all.sh` and explicitly recommends it as "a correct, verified opt-in" for "any caller on a
  quieter host willing to request it explicitly." Gate 8's two real automated invocation contexts
  (see below) are exactly that kind of caller — the parallel-safety dependency this task's
  description worried about is **already discharged**, no re-validation gate needed.
- The dependency question in the dispatch ("(a) carry the 3-run validation ourselves, or (b)
  depend on task 261's Phase 6") is **moot as stated**: task 261's Phase 6 already ran and
  concluded (COMPLETED WITH EXCLUSIONS, not PARTIAL — the PARTIAL characterization in the
  dispatch's oldest paragraphs is superseded by its own later "PATH REVIEW" paragraph, which is
  correct). Nothing needs to be re-run.
- **New finding, not previously recorded anywhere in this repo**: `test-run-all-parallel.sh`'s
  case3 timing assertion fails **deterministically**, independent of ambient host load, whenever
  the suite runs nested inside any `run-all.sh` invocation (which is always, when it's discovered
  as one of the ~97 suites — including today's Gate 8, at `--jobs 1`). This is a real bug in the
  test's own "unguarded" baseline measurement (it inherits `RUN_ALL_NESTED=1` from its parent
  without clearing it), not the ambient-load flakiness task 261 attributed it to. Reproduced
  live (see Findings). This task's file_scope already includes `test-run-all-parallel.sh`, so
  fixing it is in scope and would let Gate 8 go fully green instead of perpetually reporting a
  "known-intermittent" failure.
- For the absorbed former-task-267 half (deploy-headless.sh's inline verify redundancy): only
  **two** files in the whole repository actually *execute* `deploy-headless.sh`
  (`command-gate-out.sh` and `orchestrate-cycle-plan.sh`) — every other file in the dispatch's
  "known callers" list only prints a remedy string mentioning it. Both real callers already
  discard `deploy-headless.sh`'s own exit-0-vs-3 distinction (`if exit -eq 1 || -eq 2 ... else
  ...`) and independently take their own full-depth pre/post `verify-deploy.sh --findings`
  snapshot around the call — so an opt-in `--skip-verify` flag returning a **new**, distinct exit
  code requires zero control-flow change in either caller, and no other caller's behavior can
  regress by construction.

## Context & Scope

Task 265 (`task_type: meta`) absorbed former task 267 and now covers two independent phases
sharing file footprint on `orchestrate-cycle-plan.sh`:
- **(A)** Give `verify-deploy.sh`'s Gate 8 (`scripts/verify-deploy.sh:558`) opt-in parallelism via
  `run-all.sh --jobs`.
- **(B)** Resolve the `deploy-headless.sh` inline-verify redundancy against the Inter-Cycle
  Redeploy Checkpoint's own pre/post/confirm full-depth snapshots.

Both are scoped to `agent-system/extensions/core/` (source store); `.claude/**` is never the edit
target.

## Findings

### Part A — Gate 8 parallelism

**Current state** (`scripts/verify-deploy.sh:558`):
```bash
run_all_output=$(cd "$TARGET" && bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet 2>&1)
```
No `--jobs` passed, so it inherits `run-all.sh`'s own `JOBS=1` default (fully sequential).

**Task 261's disposition** (`specs/archive/261_reduce_process_spawn_amplification_in_tests/`,
COMPLETED WITH EXCLUSIONS, 2026-09-26): added `--jobs N|auto` (cap 4 via `JOBS_CAP`), longest-first
scheduling from an advisory `suite-cost-hints.txt`, a `LOAD_SENSITIVE_BASENAMES` array (5 suites:
`test-lake-build-guard.sh`, `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`,
`test-four-tier-conflict.sh`, `test-run-all-parallel.sh`) that always runs serially before the
parallel pool, and the `RUN_ALL_NESTED=1` guard. Phase 6's 3-run flakiness gate did **not** meet
its own criterion (3/3 clean AND no load-sensitive-suite failure) under sustained heavy ambient
host contention (5 concurrent `claude` sessions + a browser), so the task **declined to flip
`run-all.sh`'s own default** — but closed `--jobs N` as "a correct, verified opt-in," with
identical pass/fail sets to `--jobs 1` on every one of 97 suites except the already-classified
load-sensitive set. Measured full-battery wall time: 507.9s at `--jobs 1` vs. 211.9s/219.3s/211.9s
at `--jobs 4` (three runs). This is already documented in
`context/standards/shell-script-testing.md`'s "Suite runtime" section, which explicitly
anticipates a caller opting in.

**Where the dispatch's premise needed correction**: its opening paragraphs describe task 261 as
"remains PARTIAL with Phases 6 and 7 outstanding," but its own later "PATH REVIEW 2026-09-28"
paragraph correctly supersedes this: task 261 is COMPLETED (verified above from the archived
summary). Dependency option (b) is satisfied; there is no outstanding validation gate to carry.

**Where Gate 8 sits relative to the load-sensitive-suite risk**: the risk task 261 found was
ambient *host* contention (many concurrent agent sessions), not correctness. Gate 8's two real
automated call sites (Part B below establishes there are exactly two) both fire at points
`context/patterns/batch-orchestration-guardrails.md` documents as having **no dispatch
concurrency** — `command-gate-out.sh`'s single-task completion path, and
`orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint, which "runs at the START of ...
strictly BEFORE Move 2 issues that cycle's own dispatch batch — the one point in the loop with no
dispatch in flight." That is precisely the condition under which task 261's `--jobs 4` reproduced
the sequential pass/fail set exactly. A manual, interactive `verify-deploy.sh` invocation (a
developer running it directly on a busy dev box, e.g. concurrently with several other agent
sessions — the exact scenario this very `/orchestrate` cycle is running seven sibling dispatches
under) is **not** one of those two sanctioned sites and has no such guarantee, which is the
argument for an environment override rather than an unconditional hardcode.

**New finding — a genuine, reproducible bug in `test-run-all-parallel.sh`, not ambient-load
flakiness**: `run-all.sh` unconditionally runs
```bash
if [ "${RUN_ALL_NESTED:-}" = "1" ]; then JOBS=1; fi
export RUN_ALL_NESTED=1
```
near the top, **regardless of whether `--jobs` was passed or whether this run-all.sh instance is
itself nested**. Every suite it invokes (`bash "$suite"`, a plain subprocess) therefore inherits
`RUN_ALL_NESTED=1` in its own environment. `test-run-all-parallel.sh`'s case3/case4 measure:
```bash
bash "$FIXTURE_RUNNER" --quiet --jobs 3            # meant to be the "unguarded", genuinely-parallel baseline
RUN_ALL_NESTED=1 bash "$FIXTURE_RUNNER" --quiet --jobs 3   # the explicitly-forced-sequential comparison
```
The first line does **not** clear `RUN_ALL_NESTED` before invoking the fixture. When
`test-run-all-parallel.sh` itself is discovered and run as one of `run-all.sh`'s own suites — which
is exactly what happens every time the full battery runs, including today's Gate 8 at `--jobs 1`
— it inherits `RUN_ALL_NESTED=1` from its own parent, so the "unguarded" measurement is *also*
forced sequential. `parallel_ms` ends up ≈ `nested_ms`, and case3's ratio assertion
(`parallel_ms <= 75% of nested_ms`) fails deterministically. I reproduced this directly:

```
$ env -u RUN_ALL_NESTED bash scripts/tests/test-run-all-parallel.sh   # standalone
[PASS] case3: --jobs 3 (718ms) is genuinely concurrent -- <= 75% of the forced-sequential time (1908ms)
Results: 9 passed, 0 failed

$ RUN_ALL_NESTED=1 bash scripts/tests/test-run-all-parallel.sh        # simulates being nested (i.e. discovered by an outer run-all.sh)
[FAIL] case3: --jobs 3 (1902ms) is not meaningfully faster than forced-sequential (1906ms) -- parallelism may be a no-op
Results: 8 passed, 1 failed
```
This is **deterministic**, not probabilistic — it explains task 261's Phase 6 observation ("failed
its own internal relative-timing assertion in all 3 runs") far better than genuine ambient-load
flakiness would (which should not fail 3/3 identically by mechanism). It also means this suite is
*already* part of Gate 8's "known-intermittent" failure today, at `--jobs 1`, with or without this
task's change — so task 265's own Verification #1 (identical pass/fail set before/after) is
achievable: this suite was already failing in the sequential baseline for this structural reason,
and will keep failing identically after Gate 8 gains `--jobs N`, which is not a new regression.

This is a good, low-risk candidate for the plan to fix (the file is already in this task's
`file_scope`): change case3's first measurement to explicitly clear the inherited variable, e.g.
`env -u RUN_ALL_NESTED bash "$FIXTURE_RUNNER" --quiet --jobs 3`. Doing so would let Gate 8 (and any
top-level `bash run-all.sh` run) go fully green rather than perpetually reporting a documented but
mischaracterized failure. This is a genuine bug fix, not the forbidden "weaken/regress the
ratio-based assertion" the dispatch warns against — the ratio design itself stays; only the
baseline measurement's environment isolation is corrected.

**Recommendation for job count / env override** (settling the dispatch's "ALSO SETTLE" bullets):
- Default: `auto` (resolves to `nproc`, capped at `JOBS_CAP=4` in `run-all.sh`). On this dev host
  `nproc=24`, so `auto` == `4` here, matching task 261's own Phase 6 measurement configuration
  exactly — but `auto` degrades gracefully on a smaller CI/container host (e.g. 2 vCPUs) instead of
  unconditionally oversubscribing with a hardcoded `4`.
- Env override: a new variable, e.g. `VERIFY_DEPLOY_GATE8_JOBS` (unset → `auto`; set to a positive
  integer or `1` → passed through verbatim as Gate 8's own `--jobs` value, subject to
  `run-all.sh`'s existing validation). This gives a CI/low-memory-host escape hatch to force `1`
  without touching source. No such override exists yet anywhere in `verify-deploy.sh`; naming
  follows the existing `DEPLOY_LOCK_STALE_SEC`-style `${VAR:-default}` convention used elsewhere
  in this codebase (no central env-var registry to update).
- The nested-invocation guard is unaffected by this call site: Gate 8 passing `--jobs auto` (or
  any N) to `run-all.sh` still hits the *same* `RUN_ALL_NESTED` check `run-all.sh` already has;
  when Gate 8's own `run-all.sh` is itself reached from inside a suite that shells out to
  `verify-deploy.sh` (the genuine nesting case the guard exists for), `RUN_ALL_NESTED=1` is already
  set by the outer invocation and Gate 8's `--jobs` request is force-reduced to `1` exactly as
  today. Confirmed by reading `run-all.sh`'s guard code directly; no change needed there.
- `--skip-slow` and the deploy-consumer/missing-run-all.sh branches
  (`verify-deploy.sh:551,553-556`) are untouched by this change — the new `--jobs` argument is
  appended only inside the existing "else" branch that already runs `run-all.sh --quiet`.
  `test-deploy-verify-wiring.sh`'s fixture never has an `agent-system/extensions` directory, so
  gate 8 always SKIPs in that suite regardless — zero risk to that test from adding `--jobs`.

### Part B — `deploy-headless.sh` inline-verify redundancy (absorbed former task 267)

**The actual redundancy, confirmed**: `deploy-headless.sh`'s own inline
`verify-deploy.sh --skip-slow` pass (~1.5 min, fast gates only, never gate 8) is followed
immediately, in **both** of its real callers, by that caller's own independent **full-depth**
(`verify-deploy.sh --findings`, all 20 gates including gate 8) pre-redeploy and post-redeploy
snapshot pair, via the shared `deploy_findings_snapshot` helper in
`scripts/lib/deploy-baseline-lib.sh`. The inline fast-gate pass is therefore fully re-checked (and
then some) by the caller's own post-redeploy snapshot every single time — the ~1.5 min is not
partially but **entirely** wasted work on both of the paths that matter.

**Caller enumeration — corrected and narrower than the dispatch's inherited list**: the dispatch's
list of 16 "referencing" files is a *mentions* list, not an *invokers* list, and says so itself
("some references are mentions, not invocations, and the distinction matters"). I verified this
directly (`grep` for genuine execution syntax, `bash .../deploy-headless.sh` in command position,
vs. string-literal/comment/remedy-message contexts). Result: **exactly two files execute
`deploy-headless.sh`** anywhere in the source store:

| File | Call site | Concurrency posture (per batch-orchestration-guardrails.md) |
|---|---|---|
| `scripts/command-gate-out.sh:192` | Postflight completion-deploy gate, single-task `/implement` path | "has no concurrency — it is the true single-task `/implement` completion path" |
| `scripts/orchestrate-cycle-plan.sh:892` | Inter-Cycle Redeploy Checkpoint | "runs at the START of `orchestrate-cycle-plan.sh`, strictly BEFORE Move 2 issues that cycle's own dispatch batch — the one point in the loop with no dispatch in flight" |

Every other file in the dispatch's list (`verify-deploy.sh`, `orchestrate-build-dispatch.sh`,
`orchestrate-batch-admit.sh`, `skill-base.sh`, `deploy-root-guard.sh`, `check-deploy-freshness.sh`,
`check-consumer-freshness.sh`, `check-extension-docs.sh`, `validate-state.sh`, `git-snapshot.sh`,
`task-lock.sh`, `measure-eager-context.sh`, `system-defect-record.sh`,
`lib/deploy-baseline-lib.sh`, plus `dispatch-worktree.sh` and
`orchestrate-predispatch-review.sh` which the dispatch's list omitted but which also only print a
remedy string) only tells a human or agent to run `bash .claude/scripts/deploy-headless.sh`
themselves — none of them execute it programmatically. `test-lint-deploy-caller-wrap.sh`
independently corroborates this exact two-caller set: its own header states it classifies every
reference into GENUINE-invocation vs. MENTION and enforces the self-overwrite-hazard wrap only on
genuine callers, and its self-test fixture list matches these two plus `deploy-headless.sh` itself.

**This narrows and de-risks the "enumerate every caller" verification requirement significantly**:
an opt-in suppression flag only needs to be threaded through by these two call sites; every other
file in the 16-item list needs **no code change at all** (their exit-3 contract is preserved
trivially, since they never read `deploy-headless.sh`'s exit code — they only print its name in a
message).

**Both real callers already ignore the exit-0-vs-3 distinction**, which resolves the "no caller
can silently misread it as verified-green" concern more thoroughly than the dispatch anticipated:

```bash
# command-gate-out.sh
if [ "$gate_out_deploy_rc" -eq 1 ] || [ "$gate_out_deploy_rc" -eq 2 ]; then ...   # not landed
else
  gate_out_post_findings="$(deploy_findings_snapshot ...)"                        # landed (0 OR 3) -- own signal used
  ...
fi

# orchestrate-cycle-plan.sh
if [ "$deploy_exit" -eq 1 ] || [ "$deploy_exit" -eq 2 ]; then ...                 # not landed
else
  post_findings=$(deploy_findings_snapshot "$SCRIPT_DIR/verify-deploy.sh")        # landed (0 OR 3) -- own signal used
  ...
fi
```
Both already collapse `deploy-headless.sh`'s exit 0 and exit 3 into the same "landed" branch and
derive the real clean/red signal from their own independent full-depth snapshot comparison, never
from `deploy-headless.sh`'s exit code itself. This means:
- Recommendation: an opt-in `--skip-verify` flag, passed only by these two call sites, that skips
  the inline `verify-deploy.sh --skip-slow` call entirely and returns a **new, distinct** exit code
  (e.g. `4`, since 0/1/2/3 are taken) with a new `RESULT=landed_verify_skipped` marker — not 0
  (which would misrepresent "verified clean" to a *future* caller or a human reading a log without
  knowing the flag was passed) and not 3 (which documented callers read as "verify ran and found
  something," which is false when it was skipped).
- Because both real callers' branch conditions are `-eq 1 || -eq 2` (not-landed) vs. an unconditional
  `else`, exit `4` falls into their existing "landed" `else` branch **automatically, with zero
  control-flow edits** to either file — only the invocation line itself needs the new flag
  appended. This is the "structural guarantee, not a claim" the dispatch asked for: I did not
  merely assert no other caller changes; I showed the only two real callers' existing branch
  predicates are already exit-code-partition-compatible with a new code.
- Every one of the 14+ mention-only files needs no change, confirmed above.
- `test-lint-deploy-caller-wrap.sh` polices *structural wrapping* (a top-level function, closing
  brace, single trailing invocation), not the argument list on the invocation line — adding
  `--skip-verify` to an already-wrapped genuine call does not change its classification and should
  not trip this lint. (Not independently executed in this research pass; the plan/implementation
  phase should run it after the edit to confirm, per the task's own Verification #5.)
- The narrower alternative the dispatch asked to weigh — a cheaper `--only-gate`-targeted inline
  verify instead of outright suppression — is strictly dominated here: `--only-gate` would still
  pay *some* inline cost that the caller's own full-depth snapshot re-checks anyway (every gate,
  not a subset, is redundant on this specific path), and it does not remove the ambiguity that a
  distinct exit code is needed regardless. Suppression is simpler, cheaper, and the two-caller
  enumeration above shows it is safe by construction. Record this comparison, as the dispatch
  requested, in favor of suppression.
- `docs/architecture/orchestrate-state-machine.md` (in this task's `file_scope`) does not currently
  document `deploy-headless.sh`'s exit codes at all (grepped for `exit 3`/`RESULT=`: no hits) — it
  only documents the checkpoint's own JSON fields. A one- or two-line addition noting the new
  `--skip-verify`/exit-4 path may be worth adding for completeness but is not load-bearing; the
  authoritative documentation is `deploy-headless.sh`'s own header and
  `context/patterns/regeneration-is-manual-only.md`'s "Inline Verification and Exit Code 3"
  subsection (both already in scope for the plan to update).

## Decisions

- Do not re-run or re-derive task 261's Phase 6 flakiness gate; cite its recorded pass/fail sets
  and its 5-suite `LOAD_SENSITIVE_BASENAMES` list directly (reproduced above).
- Recommend Gate 8 request `--jobs auto` by default with a new `VERIFY_DEPLOY_GATE8_JOBS` env
  override (unset → auto; set → passed through verbatim), rather than a bare hardcoded `4` or an
  unconditional `auto` with no override — final naming/precedence is a planning-phase decision but
  the direction (opt-in parallel request + escape hatch) is settled here.
- Recommend fixing `test-run-all-parallel.sh`'s case3 nested-inheritance bug
  (`env -u RUN_ALL_NESTED` on its "unguarded" measurement) as part of this task, since the file is
  already in `file_scope` and the fix directly serves this task's own goal of a clean Gate 8 run.
- Recommend the opt-in `--skip-verify` flag + new distinct exit code (not narrowed `--only-gate`)
  for deploy-headless.sh's Part B, passed only by `command-gate-out.sh` and
  `orchestrate-cycle-plan.sh` — the only two genuine callers in the entire source store.

## Risks & Mitigations

- **Risk**: a future third automated caller of `deploy-headless.sh` is added later and forgets to
  handle a new exit code. Mitigation: `test-lint-deploy-caller-wrap.sh` already re-derives the
  genuine-caller set from file contents every run (never a hardcoded list), so a new caller is
  caught by that lint's structural-wrap requirement; the plan should also add or extend a test
  asserting the exit-4/`RESULT=landed_verify_skipped` contract explicitly (Verification #4 in the
  dispatch).
- **Risk**: `--jobs auto` resolving differently on a future host with `nproc` between 1 and 4
  changes Gate 8's timing characteristics per-host. Mitigation: this is inherent to `auto` and is
  the same behavior `run-all.sh` itself already documents and accepts; the env override provides
  the escape hatch for a host where even `auto`'s result is unsafe (e.g. `nproc=1` low-memory CI
  container also under memory pressure — force `VERIFY_DEPLOY_GATE8_JOBS=1`).
- **Risk**: fixing `test-run-all-parallel.sh`'s nested-inheritance bug in the same task as the
  `--jobs` wiring could make a before/after pass/fail comparison harder to read (a suite flips from
  FAIL to PASS for a reason unrelated to `--jobs` itself). Mitigation: the plan should sequence the
  test fix as an early, separately-verified phase (fix it and confirm it now passes standalone AND
  nested, before touching `verify-deploy.sh:558`), so Verification #1's baseline-vs-new-invocation
  pass/fail comparison is taken with the fix already landed on both sides and is not confused by a
  suite whose failure status changes for a reason unrelated to `--jobs`.

## Context Extension Recommendations

- **Topic**: `test-run-all-parallel.sh`'s nested-inheritance defect.
- **Gap**: `context/standards/shell-script-testing.md`'s "Known pre-existing failures and flakes"
  section currently attributes this suite's failure purely to "load-sensitive... heavy ambient host
  load," which this research shows is not the true (or at least not the sole) mechanism.
- **Recommendation**: once fixed, remove `test-run-all-parallel.sh` from that document's
  load-sensitive list (it can stay in `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES` array as an
  ambient-load precaution for its OWN measurement stability, which is a separate, legitimate
  concern from the deterministic bug fixed here) and add a short note distinguishing "genuinely
  load-sensitive" from "was actually a nested-environment-inheritance bug, now fixed" so a future
  reader does not re-attribute a similar future failure to load without checking first.

## Appendix

- Commands run: `git log --oneline --all --grep=jobs -i`; direct greps across
  `agent-system/extensions/core/scripts/**`; a live reproduction of
  `test-run-all-parallel.sh` under `RUN_ALL_NESTED=1` vs. unset (see Findings, Part A).
- Key files read in full or substantial part: `scripts/verify-deploy.sh` (gates 7-9, `--only-gate`
  parsing), `scripts/tests/run-all.sh` (header, `--jobs`/`auto`/guard logic,
  `LOAD_SENSITIVE_BASENAMES`), `scripts/tests/test-run-all-parallel.sh` (full),
  `scripts/deploy-headless.sh` (exit-code header, inline verify block),
  `scripts/orchestrate-cycle-plan.sh` (checkpoint branches ~849-1030),
  `scripts/command-gate-out.sh` (postflight deploy-gate branch),
  `scripts/tests/test-lint-deploy-caller-wrap.sh` (header),
  `scripts/tests/test-deploy-verify-wiring.sh` (gate8 fixture behavior),
  `context/patterns/batch-orchestration-guardrails.md` (Inter-Cycle Redeploy Checkpoint,
  Postflight Completion-Deploy Gate, rejected redundant-verify-passes design),
  `context/standards/shell-script-testing.md` (Suite runtime section),
  `specs/archive/261_.../summaries/01_test-suite-runtime-reduction-summary.md` (full).
