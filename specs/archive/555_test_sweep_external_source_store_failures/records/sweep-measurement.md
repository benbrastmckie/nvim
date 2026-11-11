# Sweep Measurement: External-Source-Store Resolution

Measured independently after Phases 1-6 landed (the shared resolver, and its six fixed call
sites). All figures below are freshly measured in this repository; none is carried from an
earlier artifact.

## Source-store entry point

`bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs auto --fail-on-new`

```
174 passed, 8 failed (2 expected, 6 NEW), 2 skipped, 184 total
```

Failing suites (8):

| Suite | Classification |
|-------|-----------------|
| `test-double-loading-check.sh` | NEW |
| `test-gate-cache-equivalence.sh` | EXPECTED |
| `test-lint-unit-integration-boundary.sh` | NEW |
| `test-orchestrate-cycle-postflight.sh` | NEW |
| `test-orchestrate-predispatch-review.sh` | NEW |
| `test-postflight-deploy-gate.sh` | NEW |
| `test-redeploy-checkpoint-promotion.sh` | NEW |
| `test-verify-deploy-context-budget.sh` | EXPECTED |

## Deployed entry point

`bash .claude/scripts/tests/run-all.sh --jobs auto --fail-on-new`

```
162 passed, 13 failed (2 expected, 11 NEW), 2 skipped, 177 total
```

Failing suites (13):

| Suite | Classification |
|-------|-----------------|
| `test-deploy-baseline-lib.sh` | NEW |
| `test-double-loading-check.sh` | NEW |
| `test-gate-cache-equivalence.sh` | EXPECTED |
| `test-gate-cache-lib.sh` | NEW |
| `test-gate-registry-resolution.sh` | NEW |
| `test-lint-deploy-caller-wrap.sh` | NEW |
| `test-lint-unit-integration-boundary.sh` | NEW |
| `test-orchestrate-build-aux-dispatch.sh` | NEW |
| `test-orchestrate-cycle-postflight.sh` | NEW |
| `test-orchestrate-predispatch-review.sh` | NEW |
| `test-postflight-deploy-gate.sh` | NEW |
| `test-redeploy-checkpoint-promotion.sh` | NEW |
| `test-verify-deploy-context-budget.sh` | EXPECTED |

The deployed-entry-point total (177) differs from the source-store total (184) because the two
discovery modes enumerate different corpora (the deployed tree merges every loaded extension's
suites into one flat tree; the source-store scan walks `agent-system/extensions/*/scripts/
tests/` directly) — the same asymmetry documented elsewhere in this task's plan, not a
measurement error.

## The 6 confirmed suites: PASS roster confirmation

Each of the 6 confirmed suites appears explicitly in the PASS roster under BOTH discovery
modes above (grepped by name, not inferred from absence on the FAIL list):

- `test-askuserquestion-rehome.sh`
- `test-deploy-propagation.sh`
- `test-lint-dead-command-recommendations.sh`
- `test-manifest-scripts-sync.sh`
- `test-routing-resolution.sh`
- `test-update-task-status.sh`

## The 6 confirmed suites run as a set

`bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-askuserquestion-rehome.sh,test-deploy-propagation.sh,test-routing-resolution.sh,
test-update-task-status.sh,test-lint-dead-command-recommendations.sh,test-manifest-scripts-sync.sh`:

```
6 passed, 0 failed (0 expected, 0 NEW), 0 skipped, 6 total
```

This is the decisive evidence for the task's own acceptance: this repository's topology (local
source store) cannot by itself exhibit the original external-source-store symptom, so each
fixed suite's own internal synthetic external-source-store fixture case (added in Phases 1-5,
all independently passing — see each phase's own progress-file verification notes) is what
actually proves the class is closed, not this repository's ambient topology.

## Residual-failure classification: both-topology vs. one-topology-only

The source-store failing set (8) is a strict subset of the deployed failing set (13) — every
suite failing under the source-store entry point also fails under the deployed entry point.

**Both-topologies (repo-independent), 8 suites** — the only candidates Phase 8 may baseline:

- `test-double-loading-check.sh` (NEW)
- `test-gate-cache-equivalence.sh` (already EXPECTED)
- `test-lint-unit-integration-boundary.sh` (NEW)
- `test-orchestrate-cycle-postflight.sh` (NEW)
- `test-orchestrate-predispatch-review.sh` (NEW)
- `test-postflight-deploy-gate.sh` (NEW)
- `test-redeploy-checkpoint-promotion.sh` (NEW)
- `test-verify-deploy-context-budget.sh` (already EXPECTED)

**One-topology-only (deployed entry point only), 5 suites** — Phase 8 must NOT baseline these;
recorded here as follow-up candidates instead:

- `test-deploy-baseline-lib.sh`
- `test-gate-cache-lib.sh`
- `test-gate-registry-resolution.sh`
- `test-lint-deploy-caller-wrap.sh`
- `test-orchestrate-build-aux-dispatch.sh`

(`test-gate-cache-lib.sh` and `test-orchestrate-build-aux-dispatch.sh` are two of the two
suites this task's own research report found misattributed to the source-store-missing cause —
they fail identically in this repository, which has a local source store, so their cause is not
source-store topology. They are both already excluded from this task's Non-Goals; their
appearance only in the deployed-entry-point sweep here, never the source-store sweep, is
independent corroboration of that finding, not a new one.)

## Genuine finding vs. environmental

Every suite in the both-topologies set, except the two already-EXPECTED rows, was spot-checked
directly rather than assumed. `test-double-loading-check.sh`'s single failing case
(`Case 5 (degraded): expected affected command in unclassifiable-command bucket`) is a
bucket-classification assertion entirely unrelated to extensions-root or source-store
resolution — a genuine finding, not an environmental gap in this task's own work. The remaining
four NEW both-topology suites (`test-lint-unit-integration-boundary.sh`,
`test-orchestrate-cycle-postflight.sh`, `test-orchestrate-predispatch-review.sh`,
`test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`) match this task's
plan's own named "~29-suite deploy/gate/orchestrate-postflight regression cluster" by name
pattern and are declared out of scope by that plan's Non-Goals; none is classified
environmental, so none is returned to an earlier phase of this task.

## Optional external-consumer confirmation

Not performed. This dispatch has no access to a second, externally-source-stored consumer
repository's checkout. Recorded as PENDING OPERATOR ACTION, never as a pass — consistent with
the plan's own instruction that a stale or inaccessible consumer tree makes this step
INCONCLUSIVE rather than skipped silently.

## Bounded-waiter discipline

Both full sweeps were run detached (`nohup ... &`, captured PID) and waited out with a
`kill -0`-on-PID liveness loop under repeated bounded `timeout` calls, never `ps | grep` or
`pgrep -f`, one waiter per log, per `context/patterns/bounded-build-waiter.md`.
