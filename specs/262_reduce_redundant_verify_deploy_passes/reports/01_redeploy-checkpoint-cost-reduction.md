# Research Report: Task #262

**Task**: 262 - Reduce redundant verify-deploy passes in the redeploy checkpoint
**Started**: 2026-09-26T00:26:00Z
**Completed**: 2026-09-26T01:10:00Z
**Effort**: Medium (source-level analysis + two live-timed baseline runs; no code changed)
**Dependencies**: 260 (self-clobbering redeploy fix) — confirmed COMPLETED in git log
  (`f90061046 task 260: complete implementation`); no rebase conflict found — the REDEPLOY
  CHECKPOINT block this task edits already reflects task 260's landed `orchestrate_cycle_plan_main`
  wrap.
**Sources/Inputs**: Direct reads of `scripts/orchestrate-cycle-plan.sh` (REDEPLOY CHECKPOINT
  block, ~lines 721-1026), `scripts/lib/deploy-ledger-lib.sh` (full file, 308 lines),
  `scripts/lib/deploy-baseline-lib.sh` (full file, 165 lines), `scripts/deploy-headless.sh`
  (header + inline-verify block), `scripts/verify-deploy.sh` (all 21 gate definitions, header),
  `context/patterns/batch-orchestration-guardrails.md` (Inter-Cycle Redeploy Checkpoint and
  Postflight Completion-Deploy Gate subsections), `scripts/tests/test-orchestrate-cycle-plan.sh`
  (ledger/checkpoint test scaffolding), `context/reference/orchestrator-critical-paths.json`;
  two live-timed empirical runs of `bash .claude/scripts/verify-deploy.sh` against this repo
  (`--skip-slow` and full-depth), both `--findings --quiet`.
**Artifacts**: - This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch's own correction is right, and this report does not revisit it: the pre/post
  findings pair around `deploy-headless.sh` must stay at identical, full depth — it is the only
  thing that isolates a deploy-*introduced* regression from a pre-existing one, and reusing one
  side for the other (the originally-reported "obvious fix") destroys that isolation outright.
- **The ledger-extension idea the dispatch asks to evaluate first (cache the whole
  `verify-deploy.sh --findings` snapshot across cycles, keyed on the durable ledger's hash state)
  does not safely reduce the dominant cost, and this report recommends against it as stated.**
  Reaching the ledger's `run` decision (the branch that actually pays for verify passes) requires
  the source-store content hash to have changed since the last write — precisely the condition
  under which a cached *prior* snapshot is stale for every source-only lint gate and would
  silently convert the checkpoint's documented "did this deploy introduce something new"
  contract into "did anything change since the last checkpoint" — a materially broader, blocking
  scope this checkpoint was never designed to have. The one sub-case where reuse would be
  provably safe (source hash provably unchanged) is *already* fully skipped today via
  `skip_hash`/`skip_attributed`, at zero verify-deploy.sh cost — so whole-snapshot caching buys
  nothing where it is safe, and is unsafe where it would matter.
- **The dominant, empirically measured cost is a single gate, not the pre/post pair as a whole.**
  Live-timed on this repo: `verify-deploy.sh --skip-slow --findings --quiet` took 1m35s;
  the same command *without* `--skip-slow` took 11m03s. Gate 8 (`tests/run-all.sh`, the shell
  test suite) accounts for roughly 9m28s of that — about 86% of a full run's wall time — and
  runs entirely against `agent-system/extensions/core/scripts/tests/**` (the source store), a
  tree `deploy-headless.sh` never writes to (it only *copies from* the source store into
  `.claude/`). That makes gate 8's outcome provably invariant across one checkpoint's own
  pre/post pair, independent of whether the *rest* of the tree changed.
- **A safe, in-scope, non-trivial win exists**: capture the gate-8 (`run-all.sh`) result exactly
  once per checkpoint firing — via a new function in `deploy-baseline-lib.sh` that duplicates
  gate 8's own invocation+parsing, so its `FINDING gate8 ...` lines are format-compatible with
  the existing set-diff machinery — and union that single snapshot into *both* the pre- and
  post-deploy `verify-deploy.sh --skip-slow` findings sets. This keeps the pre/post pair at
  literally identical depth for gate 8 (same lines on both sides, by construction, not by luck),
  changes nothing about the other 20 gates, and cuts the measured common-path verify cost from
  roughly two full runs (~22 min) to roughly one gate-8 run plus two fast (`--skip-slow`) runs
  (~14-15 min) — entirely within this task's declared `file_scope`
  (`orchestrate-cycle-plan.sh` + `deploy-baseline-lib.sh`; no change to `verify-deploy.sh` or
  `deploy-headless.sh`). It also removes gate 8 from the confirm/flaky-classification path
  entirely, since gate 8 can no longer appear as a "new" candidate finding.
- The "adjacent" question (suppress `deploy-headless.sh`'s own inline `--skip-slow` verify,
  since the checkpoint immediately runs its own full verify afterward) is real but requires a
  new opt-in flag on `deploy-headless.sh`, which is **not** in this task's `file_scope` and has
  many other callers depending on its exit-3 contract. **Decided OUT of this task explicitly**;
  recorded below as a scoped, low-risk follow-up for whoever owns `deploy-headless.sh`/
  `verify-deploy.sh` next.
- The flaky-vs-real confirmation pass and the attribution filter are both preserved unchanged in
  the recommended design — see Risks & Mitigations for the self-inflicted-load premise re-check
  the dispatch asked for.

## Context & Scope

Task 262 is a `meta` task whose edit target is the source store
(`agent-system/extensions/core/`), never `.claude/**`. Its declared `file_scope` is:

- `scripts/orchestrate-cycle-plan.sh`
- `scripts/lib/deploy-baseline-lib.sh`
- `scripts/lib/deploy-ledger-lib.sh`
- `context/patterns/batch-orchestration-guardrails.md`
- `scripts/tests/test-orchestrate-cycle-plan.sh`

It depends on task 260 (self-clobbering redeploy fix), confirmed complete
(`f90061046 task 260: complete implementation` in git log, most recent commit at research time).
Reading the current `orchestrate_cycle_plan_main` REDEPLOY CHECKPOINT block confirms it already
reflects the landed self-overwrite-hazard wrap (the `orchestrate_cycle_plan_main() { ... }`
function boundary described in the file's own header comment) — there is nothing left to rebase.

This report focuses exclusively on the redeploy checkpoint's *cost*, not its correctness
contract, which the dispatch has already re-derived carefully and which this report treats as
settled: the three-branch (a)/(b)/(c) failure contract, the confirmation filter, and the
attribution filter are all out of scope to change except where explicitly noted.

## Findings

### Codebase Patterns

**The checkpoint's actual common-path structure** (`scripts/orchestrate-cycle-plan.sh`,
approximately lines 828-1010), confirmed by direct read:

1. `deploy_ledger_decide` (from `deploy-ledger-lib.sh`) is consulted first. It returns
   `skip_hash`, `skip_attributed`, or `run`. Both skip decisions bypass the entire deploy+verify
   body — **zero** `verify-deploy.sh` invocations. Only `run` pays anything.
2. On `run`: `pre_findings = deploy_findings_snapshot(verify-deploy.sh)` — **full depth, no
   `--skip-slow`** (`scripts/lib/deploy-baseline-lib.sh`'s `deploy_findings_snapshot` passes no
   extra args by default at this call site).
3. `deploy-headless.sh` runs. Internally it always runs its own
   `verify-deploy.sh --skip-slow` (`scripts/deploy-headless.sh:402`, `VERIFY_ARGS=(--skip-slow)`)
   and folds the result into its own exit code (0 = clean, 3 = fast-verify found something),
   which the checkpoint only actually uses for branch (a) (`deploy_exit` 1 or 2) and for a
   cosmetic "DEPTH NOTE" diagnostic when `deploy_exit -eq 0` yet the checkpoint's own full-depth
   comparison still finds something.
4. `post_findings = deploy_findings_snapshot(verify-deploy.sh)` — full depth again, independent
   of step 3's inline pass.
5. `deploy_baseline_new_findings(pre, post)` computes the candidate-new set. If non-empty, a
   **third** full-depth `verify-deploy.sh` call (`confirm_findings`) re-runs to distinguish flaky
   from real, then the attribution filter narrows further. This third pass is correctly gated —
   it only fires on the rare would-be-defer path — and the dispatch's own instruction not to
   touch it is followed here.

**Why `deploy_ledger_decide` reaching `run` almost always means the source hash genuinely
changed** (read of `scripts/lib/deploy-ledger-lib.sh`'s `deploy_ledger_decide`): `skip_hash`
fires unconditionally whenever the aggregate hash is unchanged and the ledger isn't older than
`DEPLOY_LEDGER_MAX_AGE_SEC` (default 86400s) — it does not even check `task_numbers`. So any
`run` decision whose reason cites "no shared task" or "not all covered" is, by construction, a
case where the hash already differs (otherwise `skip_hash` would have already fired first). The
only `run` sub-case where the hash is provably *unchanged* is "hash changed (or ledger
unavailable) and deploy age exceeds max-age cap" read together with a same-hash comparison — i.e.
a stale-by-time-only ledger. `DEPLOY_LEDGER_MAX_AGE_SEC`'s entire purpose (per the library's own
header) is to force periodic re-verification for drift the source hash *cannot* see (e.g. manual
out-of-band edits to the deployed `.claude/` tree, which the ledger never hashes at all — it
hashes only `agent-system/extensions/core`). Reusing a cached snapshot specifically in this
sub-case would defeat that safety valve's own purpose. This confirms: **there is no sub-case of
`run` where reusing a prior whole-findings snapshot is both safe and actually needed** — either
the hash is unchanged (already free via `skip_hash`) or it changed (reuse is unsafe, see below).

**Why whole-snapshot reuse across cycles is unsafe when the hash actually changed** — this is
the central correctness finding of this report, and it generalizes the dispatch's own "the pair
must stay at identical depth" argument to the cross-cycle case:

Direct reading of `scripts/verify-deploy.sh`'s 21 gates shows most of them (gates 3, 4, 6, 7, 8,
11, 12, 15, 17, 18, 19, 20, confirmed by their own `[ ! -d "$TARGET/agent-system/extensions" ]`
SKIP-if-not-source-store guards and their invocation of source-store-resident lint scripts) audit
the **source store's own content**, not anything `deploy-headless.sh` writes. `deploy-headless.sh`
copies *from* the source store *into* `.claude/`; it never writes back into
`agent-system/extensions/core`. So within one checkpoint's own pre/post pair (source held fixed
across the single `deploy-headless.sh` call), these gates are provably identical pre and post —
this is exactly *why* today's design can never see a source-lint regression introduced by the
batch's own task edits: it only ever compares "before this one deploy op" against "after this one
deploy op," with source pinned, so a same-source lint issue cancels out of the diff by
construction and proceeds via branch (c) today, regardless of whether it is newly introduced or
ancient.

A **cross-cycle** cached snapshot breaks this pinning. If cycle N's `post_findings` (call it F0,
reflecting source state S0) is reused as cycle N+1's `pre_findings` while the checkpoint's own
fresh `post_findings` now reflects S1 (S1 != S0, since that is what forced `run`), then
`deploy_baseline_new_findings(F0, fresh_post)` will surface, as "new," any source-lint finding
that differs between S0 and S1 — including one introduced by in-progress task work that has not
yet reached its own completion (there is no other point in the `/orchestrate` lifecycle where
such a regression gets checked — `batch-orchestration-guardrails.md`'s own "Residual — the
`/orchestrate` path (D6) — CLOSED" section confirms `/orchestrate` has no serialized
per-task deploy+verify trigger of its own; it "relies entirely on the Inter-Cycle Redeploy
Checkpoint mechanism"). If that finding names a file in `cycle_modified_files` (likely, since it
came from this batch's own edit), the attribution filter will not save it — it becomes
confirmed + attributable + blocking, deferring the whole batch for something outside the
checkpoint's documented "did the deploy introduce this" contract. This is a genuine semantic
regression, not a caching nuance, and it is exactly the class of trap the dispatch's own
correction of the original candidate fix was modeling: attractive on paper, wrong once you read
the code that computes what "new" actually means.

**Empirical cost measurement** (live-timed on this repo, single sample, this environment —
re-measure at implementation time per the dispatch's own Verification item 1):

| Command | Wall time | Notes |
|---|---|---|
| `verify-deploy.sh --skip-slow --findings --quiet .` | 1m35.1s | All 21 gates except gate 8 |
| `verify-deploy.sh --findings --quiet .` (full) | 11m03.6s | All 21 gates including gate 8 |
| Implied gate-8-only cost | ~9m28s | Full minus skip-slow |

This is **far above** `verify-deploy.sh`'s own header comment ("gate 8 measured at 117.9s ... full
run ~2.8min"), which is now stale — the shell test suite has evidently grown substantially since
that comment was written. This makes the dispatch's 17-minute observed cost entirely plausible
(and likely to keep growing, since gate 8 scales with the number of shell test files, and every
un-skipped checkpoint pays it twice today, plus once more inside `deploy-headless.sh`'s own
inline pass at reduced depth).

Both runs surfaced pre-existing findings unrelated to this task (e.g. a `gate3` doc-lint hit
about a script not listed in `provides.scripts`, and several `gate8` shell-test failures
including a missing shared library reference and stale golden-output expectations) — these are
current, real, and orthogonal to task 262; they are not analyzed further here since they are
outside `file_scope`, but they are worth flagging to whoever tracks `errors.json` since they will
appear as "pre-existing" findings on every future checkpoint until fixed by their own owners.

**Gate-8 isolation is not merely inferred from its guard clause — it was checked directly.**
`scripts/verify-deploy.sh`'s gate 8 body invokes exactly
`bash "$TARGET/agent-system/extensions/core/scripts/tests/run-all.sh" --quiet` from `cd "$TARGET"`
— a single, source-store-scoped invocation. A repo-wide grep of `scripts/tests/*.sh` for any
direct reference to a deployed-tree path (`PROJECT_ROOT/.claude`, `$TARGET/.claude`,
`CLAUDE_DIR`) found zero hits. The handful of tests that DO reference `deploy-headless.sh` or
`verify-deploy.sh` by name (`test-deploy-propagation.sh`, `test-deploy-verify-wiring.sh`, and
others) each build their own isolated `mktemp`-scoped scratch `TARGET`/`WORKDIR`/`FIXTURE` tree
rather than touching the live deployed `.claude/` — confirmed by reading two of them directly.
This is strong, though not exhaustive, evidence that gate 8's outcome depends only on the source
store's `scripts/tests/**` content (and whatever those tests exercise via their own fixtures),
never on the live deployed tree's current state. Recommend a full audit of all
`scripts/tests/*.sh` files as an implementation-time verification step before relying on this as
an absolute invariant (the same "must establish rigorously, not assumed" discipline the dispatch
applied to the cross-cycle reuse proviso applies here too).

**The curated critical-paths list is far narrower than gate 8's true dependency surface.**
`context/reference/orchestrator-critical-paths.json`'s `critical_paths` array (the list
`deploy_ledger_hash_state` hashes) names roughly a dozen specific orchestrator-core files
(`skill-orchestrate/SKILL.md`, `commands/orchestrate.md`, `scripts/skill-base.sh`,
`scripts/task-lock.sh`, etc.) — it does not include `scripts/tests/**` at all. This confirms a
cross-cycle *gate-8-specific* cache (as opposed to the whole-snapshot cache this report rejects
above) would need its own, broader hash scope to be safe, and is not something the existing
ledger's hash can gate correctly as-is. See Recommendations.

### External Resources

Not applicable — this is a pure codebase-internal cost/correctness analysis; no external
documentation or library research was needed.

### Recommendations

**Primary recommendation (in scope, safe, concretely measured): within-checkpoint gate-8
de-duplication.**

1. Add a new function to `scripts/lib/deploy-baseline-lib.sh`, e.g.
   `deploy_gate8_snapshot <source_store_root>`, that duplicates gate 8's own invocation exactly
   (`cd <root> && bash <root>/scripts/tests/run-all.sh --quiet`), and on nonzero exit emits
   `FINDING gate8 <line>` for each parsed `[FAIL]` line from `run-all.sh`'s own output — matching
   `scripts/verify-deploy.sh`'s existing gate-8 finding format byte-for-byte, so the result is a
   drop-in, format-compatible input to the existing `deploy_baseline_new_findings` /
   `deploy_baseline_confirm_new_findings` / `deploy_baseline_unattributable_findings` functions
   (all three are purely textual/line-based and gate-agnostic — confirmed by reading
   `deploy-baseline-lib.sh` in full).
2. In `orchestrate-cycle-plan.sh`'s checkpoint, on the `run` branch: call
   `deploy_gate8_snapshot` exactly once, then build `pre_findings` and `post_findings` each from
   `deploy_findings_snapshot(verify-deploy.sh, --skip-slow)` **unioned** with that one shared
   gate-8 result (`sort -u` of both), for all three call sites that currently call
   `deploy_findings_snapshot` at full depth (`pre_findings`, `post_findings`, and the rare
   `confirm_findings` re-run).
3. This satisfies, not violates, the documented depth-symmetry constraint: gate 8 appears with
   **identical** content on both sides of every comparison, by construction — not by chance
   re-execution — so it can never spuriously show up as "new" or "dropped," and a genuinely
   pre-existing gate-8 failure still proceeds via branch (c) exactly as today.
4. Estimated effect on the measured common path: replaces two full runs (~22 min) with one
   gate-8 run (~9.5 min) plus two `--skip-slow` runs (~1.6 min each, ~3.2 min total) ≈ 12.7 min —
   roughly a 40% cut of the pre/post pair's own cost, and it also removes gate 8 entirely from
   the confirm pass's cost on the (rare) defer path, saving another ~9.5 min there whenever it
   fires.
5. Entirely within `file_scope`: only `orchestrate-cycle-plan.sh` and `deploy-baseline-lib.sh`
   change. `deploy-ledger-lib.sh` and `verify-deploy.sh`/`deploy-headless.sh` are untouched.
   `batch-orchestration-guardrails.md`'s "Inter-Cycle Redeploy Checkpoint" subsection needs a
   short addendum documenting the gate-8 sharing (its own DEFECT-A-style deliberate-choice
   framing), and `test-orchestrate-cycle-plan.sh` needs new coverage: a fixture where the fake
   `run-all.sh` is invoked-counted to assert it runs exactly once per checkpoint firing, not
   twice or three times.

**Rejected as stated (per the correctness analysis above): whole-findings-snapshot caching in
`deploy-ledger-lib.sh`, keyed on the existing source-hash state.** Do not implement this as the
dispatch's ledger-extension paragraph describes it. If a future task wants to revisit
cross-cycle reuse, it would need to be scoped much more narrowly than "cache
`post_findings`" — e.g. a dedicated, broader-than-`orchestrator-critical-paths.json` hash over
everything gate 8's test suite actually depends on, used *only* to gate reuse of the gate-8
line specifically (never the whole snapshot) — and even then, buys nothing beyond what the
primary recommendation above already achieves via a single-invocation-scoped share, without any
of the staleness risk of trusting a hash's completeness across time. Not designed further here;
flagged as a non-actionable, high-risk idea rather than a follow-up task.

**Adjacent item — deploy-headless.sh's own inline `--skip-slow` verify: decided OUT of this
task, explicitly.** `deploy-headless.sh` (which is not in `file_scope`) has many other callers
that depend on its exit-3 contract (`command-gate-out.sh`, `check-deploy-freshness.sh`,
`git-snapshot.sh`, `task-lock.sh`, `orchestrate-batch-admit.sh`, the postflight
completion-deploy gate's two serialized trigger sites, and others — confirmed via a repo-wide
grep). Suppressing its inline verify only when called from this one checkpoint would require a
new opt-in flag (e.g. `--skip-inline-verify`, default off everywhere else) and a redefinition of
what its exit code means when that flag is passed (it could then only ever return 0 or 1/2, never
3, since verification would not run inline). This is plausible and would save the measured
~1m35s inline pass on every triggered checkpoint, but it touches a file outside this task's
declared edit surface and changes a widely-depended-on contract, even if only for one opt-in call
site. Recommend a separate, narrowly-scoped follow-up task (with `file_scope` expanded to include
`scripts/deploy-headless.sh`) rather than folding it into 262.

## Decisions

- Preserve the pre/post pair at identical, full depth (per gate-8 sharing's design in the primary
  recommendation, "full depth" now means "`--skip-slow` plus the shared gate-8 union," which is
  informationally identical to today's unqualified full run, never a narrower comparison).
- Preserve the confirmation pass (flaky-vs-real) and the attribution filter, unchanged in logic;
  only their gate-8 cost is removed via the shared snapshot.
- Reject whole-findings cross-cycle caching in `deploy-ledger-lib.sh` as unsafe for the case that
  matters (source hash changed) and redundant with existing `skip_hash`/`skip_attributed` for the
  case that would be safe (source hash unchanged).
- Decide the `deploy-headless.sh` inline-verify suppression explicitly OUT of this task's scope;
  record it as a follow-up recommendation rather than silently dropping it or silently expanding
  `file_scope` to include it without a planning decision.

## Risks & Mitigations

- **Risk**: an undiscovered test under `scripts/tests/**` reads the live deployed `.claude/`
  tree rather than a scratch fixture, which would make gate 8 non-invariant across a
  `deploy-headless.sh` call and break the sharing design's correctness.
  **Mitigation**: full audit of all `scripts/tests/*.sh` (not just the sampled subset here) for
  any reference to a deployed-tree path outside a test's own `mktemp`/`WORKDIR`/`FIXTURE` scope,
  as an implementation-time precondition before landing the gate-8 sharing change; add an
  explicit assertion or comment recording that the audit was done.
- **Risk (self-inflicted-load premise re-check, per the dispatch's explicit instruction)**: the
  confirmation pass exists because "the checkpoint runs a full deploy plus the entire shell test
  suite immediately before taking its post snapshot," which is itself enough ambient load to
  flake a load-sensitive test in that same suite (`deploy-baseline-lib.sh`'s own documented
  motivation, observed case: `test-lake-build-guard.sh`). Under the primary recommendation, gate
  8 runs only **once** per checkpoint and is never part of the pre/post *comparison* at all (it
  is unioned identically into both sides), so it can no longer be the source of a spurious
  pre/post mismatch for itself — that specific load-sensitivity motivation is substantially
  weakened for gate 8. It is **not** eliminated for the other 20 gates, none of which this
  research established are immune to load-sensitivity; the confirmation/attribution mechanism is
  therefore preserved unchanged for all of them, per the dispatch's explicit instruction not to
  remove it. State this explicitly in the `batch-orchestration-guardrails.md` addendum so a
  future reader does not misread the gate-8 change as evidence the whole confirmation mechanism
  is now unnecessary.
- **Risk**: the new `deploy_gate8_snapshot` function silently drifts from gate 8's own format if
  `verify-deploy.sh`'s gate 8 body is edited later without a matching update here (a two-copy
  duplication hazard, the same class of drift `deploy-baseline-lib.sh`'s own header describes as
  the reason it was extracted as a shared library in the first place).
  **Mitigation**: a dedicated regression test asserting the two code paths' finding-line format
  stays byte-identical for a fixed synthetic `run-all.sh` failure fixture, run as part of
  `test-orchestrate-cycle-plan.sh`'s (or a new, small) test file; note the duplication explicitly
  in both functions' header comments, cross-referencing each other, so an editor of gate 8 is
  pointed at the sibling.
- **Risk**: gate-8 findings sharing changes the checkpoint's own stderr/notice detail slightly
  (the `verify_deploy_baseline_notices` entry's `pre_findings`/`post_findings` counts would now
  include a line count contributed by a call that ran outside `verify-deploy.sh` itself).
  **Mitigation**: no functional impact, but document the count semantics change in the
  `batch-orchestration-guardrails.md` addendum so an operator reading a notice's `pre_findings: N`
  count understands it now includes the shared gate-8 lines.

## Context Extension Recommendations

- **Topic**: `verify-deploy.sh`'s own header comment cites stale gate-8/full-run timings
  (117.9s / ~2.8min) that this report's live measurement (9m28s / 11m03s) shows are far out of
  date.
  **Gap**: no context file tracks verify-deploy.sh's actual current cost, so the staleness is
  invisible until someone times it by hand (as this report did).
  **Recommendation**: a follow-up task (outside 262's `file_scope`) should either update
  `verify-deploy.sh`'s own header comment with a re-measured figure, or note that such timings
  degrade naturally as the test suite grows and should not be treated as load-bearing
  documentation of current cost — a decision for whoever owns that file, not this task.

## Appendix

**Search/verification commands used**:
```
jq -r '.active_projects[] | select(...)' specs/state.json   # task 262 metadata + dependencies
grep -n "CURRENT_GATE=\"gate" scripts/verify-deploy.sh        # located all 21 gate boundaries
time bash .claude/scripts/verify-deploy.sh --skip-slow --findings --quiet .
time bash .claude/scripts/verify-deploy.sh --findings --quiet .
grep -rn "PROJECT_ROOT/.claude\|\$TARGET/.claude\|CLAUDE_DIR" scripts/tests/*.sh   # 0 hits
grep -rln "deploy-headless\|verify-deploy" scripts/tests/*.sh                     # fixture-scoped only
grep -rl "deploy-headless.sh" scripts/ context/ --include="*.sh" --include="*.md"  # caller census
```

**References**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (REDEPLOY CHECKPOINT block)
- `agent-system/extensions/core/scripts/lib/deploy-ledger-lib.sh`
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`
- `agent-system/extensions/core/scripts/verify-deploy.sh`
- `agent-system/extensions/core/scripts/deploy-headless.sh`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
