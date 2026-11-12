# Implementation Summary: Task #600

- **Task**: 600 - Sapience retrieve cold-start retry
- **Status**: [COMPLETED]
- **Started**: 2026-11-12T18:21:00Z
- **Completed**: 2026-11-12T19:50:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_sapience-retrieve-cold-start-retry.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`sapience-retrieve.sh` previously collapsed every non-2xx HTTP status into one catch-all `exit 2`
arm before the response body was ever parsed, so a cold-start 503 carrying `starting: true` and
`retry_after` was indistinguishable from a genuine failure. This implementation adds exactly one
bounded retry gated on that narrow discriminator, honors the server's own `retry_after` hint
through a clamp, extends the test harness to drive the path with no live vault, documents the
contract, and redeploys. All five plan phases completed; the terminal fail-open degrade is
byte-identical to before.

## What Changed

- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — added
  `RETRY_DELAY_DEFAULT=15`/`RETRY_DELAY_MIN=1`/`RETRY_DELAY_MAX=20` constants; extracted the
  request issuance into an `issue_request` function; added a cold-start predicate (HTTP 503 +
  parseable JSON + strict-boolean `.starting == true`) that, on match, sleeps a clamped
  `retry_after` and retries exactly once; left the catch-all `exit 2` diagnostic and the
  transport-failure branch byte-identical; updated the header comment block.
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` — extended the
  `curl` stub to support a sequenced two-response dispatch (`_1`/`_2`-suffixed env vars with
  fallback to the existing unsuffixed vars), added a companion recording `sleep` stub, added
  `curl_call_count`/`sleep_durations` readback helpers, and added five new cases (cold start then
  success; a second 503 after retry; a 4xx never retried; a non-JSON 503 body never retried; a
  `retry_after` of 9999 clamped to 20).
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` —
  replaced the stale "never blocks or retries the dispatch on any exit code" clause with an
  accurate description of the bounded retry contract (predicate, clamp, one-attempt budget,
  ~36s capped worst case, unchanged terminal degrade).
- Deployed mirrors (`.claude/scripts/sapience-retrieve.sh`,
  `.claude/scripts/tests/test-sapience-capture.sh`,
  `.claude/context/project/sapience/domain/per-repo-scoping.md`) regenerated via
  `deploy-headless.sh`; `index-entries.json`'s `line_count` for `per-repo-scoping.md` auto-updated
  to 153 by the deploy's own `generate-context-line-counts.sh` pass.

## Decisions

- Clamp rule: parse `retry_after` with `jq -r '.retry_after // empty'`; fall back to the default
  `15` on anything not matching `^[0-9]+$`; clamp into `[1, 20]`.
- Fixed constants (not env-overridable), for consistency with the file's two existing constants.
- `STUB_DIR` is exported by the test harness's `run_sr` and read by both the `curl` and `sleep`
  stubs, rather than having each self-locate via `$0`/`dirname`, since `$0` resolves to the bare
  command name (not a full path) when found via `PATH` search.
- Mid-task verification of the source-store script, before the Phase 5 redeploy, used
  `CORE_TEST_SUBJECT_MODE=source-store` to override `test-sapience-capture.sh`'s default
  `deploy-tree-first` subject resolution, which would otherwise have silently exercised the
  stale deployed copy.

## Plan Deviations

- **Phase 5, task "Run the complete gate set and confirm green"** altered: per this dispatch's
  Batch Gate Deferral directive, discharged via the scoped narrowing (`run-all.sh --only
  test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-sapience-capture.sh`
  and `verify-deploy.sh --skip-slow --only-gate 3,4`), both green against the redeployed tree. The
  complete gate set was additionally run once for direct observation (not as the official
  discharge) and showed 4 failures, all pre-existing and unrelated to this task: Gate 8's 5
  already-baselined `run-all.sh` suite failures (`test-sapience-capture.sh` itself passed), a
  Gate 10 60s timeout, an orchestrator eager-load-budget overage, and a `skill-orchestrate.md`
  size-ceiling overage — none touching sapience files or this task's `file_scope`.
- **Phase 4's own scoped check** (`verify-deploy.sh --skip-slow --only-gate 3,4`) initially failed
  Gate 3 with three sapience findings, all structurally expected pre-redeploy (deployed-content
  drift on two already-edited files, and a self-healing `index-entries.json` line-count
  mismatch). Confirmed resolved by the same check re-run after Phase 5's redeploy: Gate 3 now
  passes clean.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck` both clean on the changed script).
- Tests: `test-sapience-capture.sh` — 29 of 29 assertions pass (11 pre-existing + 18 new),
  completing in well under a second against both the source-store and the redeployed copy. The
  four-suite scoped `run-all.sh --only` set passes against the redeployed tree. The unfiltered
  `run-all.sh` run shows 176 passed, 5 failed (all 5 pre-existing `EXPECTED`, 0 NEW) — not
  including `test-sapience-capture.sh`.
- Files verified: Yes — `diff` between each of the three source-store files and its deployed
  mirror shows zero drift.

## Impacts

- A dispatch built while the Sapience vault is cold-starting now has roughly a 1-in-N chance (one
  per occurrence) of a successful retry landing a populated `<memory-context>` instead of
  unconditionally degrading to empty, at a bounded added cost of at most ~36s on that one call.
- Every other retrieval path (success, benign no-match, 4xx, non-JSON body, transport error) is
  unchanged in behavior and timing.

## Follow-ups

- None required by this task. Noted but explicitly out of scope: whether the same cold-start
  hint reaches `sapience-remember.sh` was flagged in the originating description as a candidate
  for a separate record, not addressed here.

## References

- Plan: `specs/600_sapience_retrieve_cold_start_retry/plans/01_sapience-retrieve-cold-start-retry.md`
- Report: `specs/600_sapience_retrieve_cold_start_retry/reports/01_sapience-retrieve-cold-start-retry.md`
