# Implementation Summary: Task #262

- **Task**: 262 - Reduce redundant verify-deploy passes in the redeploy checkpoint
- **Status**: [COMPLETED]
- **Started**: 2026-09-26
- **Completed**: 2026-09-26
- **Effort**: ~3 hours (audit, measurement, documentation; no code-change phases executed)
- **Dependencies**: 260 (self-clobbering redeploy fix) — COMPLETED, nothing to rebase
- **Artifacts**: plans/01_redeploy-checkpoint-cost-reduction.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, plan-format.md (decision-gate/contingency shape)

## Overview

This task set out to reduce the inter-cycle redeploy checkpoint's verify cost by capturing Gate 8
(`tests/run-all.sh`, ~86% of a full `verify-deploy.sh` run's wall time) exactly once per checkpoint
firing and reusing it identically across the `pre_findings`/`post_findings`/`confirm_findings`
comparison. Phase 1's blocking precondition audit — required by the plan before any code change —
found the design's invariance premise **false**: 41 of the 73 files under
`agent-system/extensions/core/scripts/tests/` prefer the DEPLOYED copy of their own
subject-under-test over the source-store copy, by documented design. Gate 8's outcome is
therefore not invariant across a `deploy-headless.sh` call, and a single-capture share would make
the checkpoint categorically blind to any Gate-8-detectable regression the deploy itself
introduces. Per the plan's own Rollback/Contingency, no code was changed; Phases 2-6 close
`[COMPLETED WITH EXCLUSIONS]`, and the finding is recorded durably in
`batch-orchestration-guardrails.md` so a future pass does not rediscover the same unsound design.

## What Changed

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — added a new
  paragraph (after "Self-overwrite mitigation...") recording the REJECTED single-capture Gate-8
  sharing decision, its evidence (the 41-file deploy-tree-first finding), and the two further
  rejected/deferred alternatives (cross-cycle ledger caching; `deploy-headless.sh` inline-verify
  suppression).
- `agent-system/extensions/core/index-entries.json` — `line_count` corrected for 5 entries via
  `bash .claude/scripts/generate-context-line-counts.sh --write` (run from the deployed copy, per
  that script's source-store-only contract): the amended `batch-orchestration-guardrails.md`
  entry (this task's own edit) plus 4 pre-existing stale entries (`plan-format.md`,
  `anti-analysis.md`, `status-markers.md`, `regeneration-is-manual-only.md`) unrelated to this
  task, fixed as an unavoidable side effect of the tool's batch (non-single-file) write mode.
- `specs/262_reduce_redundant_verify_deploy_passes/plans/01_redeploy-checkpoint-cost-reduction.md`
  — Phase 1 checked off with full evidence and marked `[COMPLETED]`; Phases 2-6 marked
  `[COMPLETED WITH EXCLUSIONS]` with `#### Reasoned Exclusions` records; plan-level Status,
  Testing & Validation, and Artifacts & Outputs sections updated to reflect the actual (rejected)
  outcome rather than the original projection.
- No changes to `deploy-baseline-lib.sh`, `orchestrate-cycle-plan.sh`,
  `test-orchestrate-cycle-plan.sh`, `deploy-ledger-lib.sh`, `verify-deploy.sh`,
  `deploy-headless.sh`, or `command-gate-out.sh`.

## Decisions

- **Decision gate answered STOP** (Phase 1): of 73 files under `scripts/tests/`, 41 use a
  documented "deploy-tree-first / source-store-fallback candidate resolution" pattern — each
  resolves its own `REPO_ROOT` via `git rev-parse --show-toplevel` and prefers
  `$REPO_ROOT/.claude/scripts/...` (the deployed tree) over the source-store sibling as its
  subject-under-test, falling back to source only when the deployed copy is absent. Since
  `.claude/` is deployed on disk in this repo, the deployed candidate wins for all 41 files. A
  pre-redeploy Gate-8 run therefore exercises stale, pre-deploy copies of whatever those 41 suites
  target; a post-redeploy run exercises fresh, just-landed copies — exactly the divergence the
  pre/post comparison exists to observe. Capturing Gate 8 once and reusing it for both sides would
  silently mask that entire class of regression, which is worse than the cost being saved.
- **No artificial deploy was staged** to "prove" the divergence live. The finding rests on static,
  mechanically-reproducible code reading (`grep -l '\$REPO_ROOT/\.claude' *.sh | wc -l` → 41/73),
  which is conclusive on its own and does not require running `deploy-headless.sh` against a
  sibling task's in-flight, uncommitted work.
- **`deploy-headless.sh`'s own wall time was not measured**, and this is stated rather than
  guessed: doing so would have required a real deploy, which risked interfering with sibling task
  261's concurrent, uncommitted edits under the same `scripts/tests/` directory.
- **The two research-report-rejected alternatives** (cross-cycle whole-snapshot caching in the
  durable ledger; suppressing `deploy-headless.sh`'s own inline `--skip-slow` verify) remain
  rejected/deferred for their own, independent reasons, and are now recorded in
  `batch-orchestration-guardrails.md` alongside this task's own finding.

## Plan Deviations

- **Phases 2-4** (add `deploy_gate8_snapshot`; wire it into the checkpoint; add test coverage)
  skipped in full: Phase 1's decision gate answered STOP, and per the plan's own
  Rollback/Contingency, building on a decided-false premise was not attempted.
- **Phase 5** altered: the originally-planned "amend the Baseline mechanism paragraph to describe
  a working sharing mechanism" was not applicable (no mechanism exists). A related, smaller
  documentation edit was made instead, in the same file, recording the rejection and its evidence
  — serving the same underlying purpose (prevent future rediscovery) without describing code that
  was never built.
- **Phase 6** partially altered: the "post-change" measurement and before/after delta computation
  were skipped (no post-change state exists). The remaining tasks — walking the dispatch's 8
  verification items, running the full gate set, writing this summary — were completed as
  planned.

## Verification

- Build: N/A (no shell-syntax-affecting change; `deploy-baseline-lib.sh` and
  `orchestrate-cycle-plan.sh` are unmodified, confirmed via `git status`/`git diff`).
- Tests: `test-deploy-baseline-lib.sh` — 7 passed, 0 failed (re-run unmodified).
  `test-orchestrate-cycle-plan.sh` — 285 passed, 0 failed (re-run unmodified, ~45s).
- Files verified: Yes — `batch-orchestration-guardrails.md`'s new paragraph read back;
  `index-entries.json`'s corrected line counts confirmed via `--skip-slow` re-run (finding
  cleared); plan file phase headings confirmed via `grep -n "^### Phase"`.
- Full (non-`--skip-slow`) `verify-deploy.sh` gate set: run once in Phase 1 (10m53.502s, before
  any edit) and twice more at `--skip-slow` depth after this task's edits (1m34.880s pre-edit,
  1m33.875s with the stale line_count still present, 1m34.871s after the fix). No finding newly
  attributable to this task's own files beyond the expected, self-resolving "pending redeploy"
  signal (`gate5 core: Content differs from source: context/patterns/batch-orchestration-
  guardrails.md`) every legitimate source-store edit produces until the next redeploy — not a
  defect.
- Pre-existing, unrelated findings (confirmed via re-verification, not newly introduced): a
  `gate3` doc-lint hit; `scripts/tests/test-lint-deploy-caller-wrap.sh` "not in provides.scripts"
  and `run-all.sh` "content differs from source" (consistent with sibling task 261's declared,
  in-flight, uncommitted work under the same directory — confirmed via `git status`/`git diff`
  showing no diff of this task's own to either file); five pre-existing Gate-8 shell-test
  failures (`test-handoff-dispatch-identity.sh`, `test-lint-json-channel-discipline.sh`,
  `test-orchestrate-context-growth.sh`, `test-orchestrate-recover-message-findings.sh`,
  `test-verify-deploy-context-budget.sh`), confirmed identical between two runs taken ~90s apart
  with no deploy in between.

## Measured Numbers (Phase 1 baseline; no "after" state exists)

| Command | Wall time (real) | Research report's prior number |
|---|---|---|
| `verify-deploy.sh --skip-slow --findings --quiet` | 1m34.880s | 1m35.1s |
| `verify-deploy.sh --findings --quiet` (full, incl. Gate 8) | 10m53.502s | 11m03.6s |
| `agent-system/extensions/core/scripts/tests/run-all.sh --quiet` (Gate 8 alone) | 9m21.299s | ~9m28s (implied) |

Implied Gate-8-only cost from the first two rows: 9m18.622s — consistent with the standalone
9m21.299s measurement within normal noise, and consistent with the research report's own
single-sample numbers. No "after" numbers are reported because no code change was made; reporting
a before/after delta for an unimplemented design would misrepresent an unmeasured quantity as a
fact.

## Dispatch Verification Items (restated against the actual, rejected outcome)

1. **Measure wall time before/after**: before numbers above; no after exists (no change made).
2. **Clean checkpoint reuses cache**: N/A — no cache was built.
3. **Changed tree does not reuse, fresh pre-snapshot**: N/A — the checkpoint's existing per-side
   full-depth captures are unchanged from before this task.
4. **Unreadable/absent/stale cache degrades to fresh verify (fail-safe)**: N/A — no cache exists;
   the checkpoint's existing ledger fail-safe behavior (`skip_hash`/`skip_attributed`/`run`,
   degrading to `run` on `CANNOTVERIFY` or an unreadable ledger) is untouched
   (`deploy-ledger-lib.sh` has no diff).
5. **Genuinely new finding still defers with `defer_ledger` detail**: unchanged — this logic
   (`deploy_baseline_new_findings`, branch (b)) was not touched.
6. **Flaky finding correctly classified, does not defer**: unchanged — the confirmation filter
   (`deploy_baseline_confirm_new_findings`) was not touched.
7. **Pre-existing finding proceeds loudly via branch (c)**: unchanged — this logic was not
   touched.
8. **Re-run `scripts/tests/` for the checkpoint and deploy/baseline suites; no test weakened**:
   done — `test-orchestrate-cycle-plan.sh` (285/285) and `test-deploy-baseline-lib.sh` (7/7) both
   re-run unmodified and pass; no test file was touched by this task at all.

## Impacts

- The redeploy checkpoint's verify cost is **unchanged** by this task. The ~17-minute
  observed-cost defect this task was opened to address remains open; see Follow-ups.
- `batch-orchestration-guardrails.md` now carries a durable record preventing a future task or
  agent from re-proposing the same unsound single-capture Gate-8 sharing design without first
  re-deriving (or refuting) this finding.
- `index-entries.json`'s line-count drift (5 entries, 4 pre-existing) is corrected, a small,
  unplanned but harmless side effect.

## Follow-ups

- **The actual cost driver remains unaddressed.** A future task could revisit this from a
  different angle now that the naive within-checkpoint share is a documented dead end — e.g.
  auditing whether the 41 deploy-tree-first test files' preference for the deployed tree is
  itself intentional per-file (some may not need it) and could be narrowed, or investigating
  whether Gate 8's own suites could be split into a source-only subset (safe to share) and a
  deploy-dependent subset (must stay per-side) — neither evaluated here, both out of this task's
  scope as investigated.
- **`deploy-headless.sh`'s own internal `--skip-slow` verify suppression** — decided OUT
  explicitly (recorded in `batch-orchestration-guardrails.md`), a genuine, scoped follow-up: that
  script's exit 3 is derived from precisely that inline run and consumed by several other callers
  (`command-gate-out.sh`, `check-deploy-freshness.sh`, `orchestrate-batch-admit.sh`, the
  postflight completion-deploy gate, others) not audited here.
- **`verify-deploy.sh`'s own stale header/comment timings**, if any exist, were not audited by
  this task and are out of scope.

## References

- `specs/262_reduce_redundant_verify_deploy_passes/reports/01_redeploy-checkpoint-cost-reduction.md`
- `specs/262_reduce_redundant_verify_deploy_passes/plans/01_redeploy-checkpoint-cost-reduction.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (new
  "Resolved: ... single-capture Gate-8 sharing REJECTED" paragraph)
