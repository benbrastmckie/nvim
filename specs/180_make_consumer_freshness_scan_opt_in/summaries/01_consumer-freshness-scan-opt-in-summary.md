# Implementation Summary: Task #180

- **Task**: 180 - Make the post-deploy consumer-freshness scan opt-in
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T00:00:00Z
- **Completed**: 2026-09-08T01:15:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_consumer-freshness-scan-opt-in.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`deploy-headless.sh`'s post-deploy block unconditionally walked every repo in the known-consumer
registry (~50 repos) via `check-consumer-freshness.sh --stale-only`, printing per-consumer
STALE/CANNOTVERIFY rows and a `CONSUMERS_STALE=<n>` marker on every deploy — including the
`/orchestrate` inter-cycle redeploy checkpoint, a blocking path no automated caller reads that
marker from. This implementation gated the entire walk behind a new, explicit, default-OFF
`--consumer-report` flag, following `verify-deploy.sh`'s existing "always explicit, never
derived. Default OFF" flag convention. All five plan phases completed; the flag-ON output is
confirmed byte-compatible in framing with the pre-change output, and the deploy's actual
verification path (the part that can change the exit-code verdict) was left completely
untouched.

## What Changed

- `agent-system/extensions/core/scripts/deploy-headless.sh` — added a `local CONSUMER_REPORT=false`
  flag, a `--consumer-report) CONSUMER_REPORT=true; shift ;;` case branch, updated the unknown-flag
  usage string, wrapped the post-deploy consumer-freshness block in
  `if [ "$CONSUMER_REPORT" = "true" ] && [ -f "$consumer_checker" ]; then` (internal statements —
  the `|| true`, the `grep -c .` count, the `CONSUMERS_STALE=` echo — left byte-identical),
  updated the header's "Two modes" flag documentation, `# Usage:` lines, "Machine-readable marker
  vocabulary" block, and "THREE CONFOUNDS" paragraph to describe the opt-in contract, and
  recalculated the `-h|--help` `sed` line range from `2,91p` to `2,101p` to match the header's
  growth.
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` — added four new
  regression cases (Cases 6-9): `--help` documents `--consumer-report`; an unknown-flag run's
  usage string lists `--consumer-report`; static source assertions pin the case branch, the
  default-`false` initialization, and the flag-guarded `CONSUMERS_STALE=` emission;
  `--consumer-report --dry-run` still short-circuits before the post-deploy block (no
  verification announcement, no `CONSUMERS_STALE=` line, exits 0). Updated the suite's header
  comment to note the new coverage.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — updated three
  paragraphs (the "Additive" post-deploy report description, the `RESULT=`/`CONSUMERS_STALE=`
  marker vocabulary section, and the Tier 3 "The post-deploy hook" paragraph) to state the walk
  is opt-in via `--consumer-report`, default OFF, and that it was moved off the blocking
  `/orchestrate` checkpoint path because it is report-only.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — updated the
  `check-consumer-freshness.sh` inventory entry to describe the new opt-in gating instead of
  "after every deploy".

## Decisions

- Flag named `--consumer-report` (names what the flag *produces*, keeping the default the quiet
  one) rather than an inverse-suppression name, and does not collide with
  `check-consumer-freshness.sh`'s own `--stale-only`/`--discover` vocabulary. Recorded as a
  planning-time judgment call since `verify-deploy.sh:32`'s convention it imitates is semantic
  (always explicit, default OFF), not a specific naming scheme.
- `ci-deploy-tree-bootstrap.md`'s `check-consumer-freshness.sh` bullet was read and consciously
  left unchanged: it describes only the script's own explicit-invocation contract and never
  claimed the deploy-headless.sh call was unconditional, so it did not understate the new gating.
- The consumer block's leading comment (immediately above the new `if` guard) was updated to
  describe the opt-in gating for accuracy; no statement *inside* the block was altered, per the
  plan's explicit constraint.

## Plan Deviations

- None (implementation followed plan). One necessary intermediate step not itemized in the plan:
  Phase 3's regression suite resolves scripts via the deployed `.claude/` tree first
  (`find_script()`), so a sanctioned default-mode `deploy-headless.sh` redeploy was run before
  the new test cases could pass — this doubled as Phase 4's first runtime-confirmation step
  rather than being wasted work.

## Verification

- Build: N/A (bash scripts and markdown only)
- Tests: `test-deploy-verify-wiring.sh` 20/20 PASS (9 pre-existing + 4 new cases, several of
  which assert multiple conditions); `test-consumer-freshness.sh` 14/14 PASS (unaffected,
  confirming no edits touched that script)
- Files verified: Yes — `bash -n` clean on both edited shell scripts; `--help` output inspected
  directly and confirmed complete/untruncated with `--consumer-report` documented
- Runtime confirmation (Phase 4): a default `deploy-headless.sh` run produced zero occurrences
  of `CONSUMERS_STALE`/`STALE`/`CANNOTVERIFY`/"Known consumer repos", `RESULT=landed_verify_clean`,
  exit 0. A `--consumer-report` run reproduced the consumer rows, printed
  `[deploy-headless] CONSUMERS_STALE=34` and the same framing lines (row count differs from
  Phase 1's reference capture — 35 vs 34 — as expected live-registry drift, never a framing
  change), and also exited 0 with `RESULT=landed_verify_clean` — identical verdict to the default
  run, confirming exit-code neutrality in both modes. The deployed `.claude/scripts/deploy-headless.sh`
  was confirmed to carry the `--consumer-report` branch after redeploy, confirming the
  source-store edit survives regeneration.
- Full gate set (`bash .claude/scripts/verify-deploy.sh`, no `--skip-slow`, run to completion
  after all five phases): two consecutive runs reported 3-of-34 then 1-of-34 failing checks,
  both times pointing at the same `test-verify-deploy-context-budget.sh` case 4
  ("byte-count drift introduced a NEW finding") concerning `commands/orchestrate.md`'s
  pre-existing, already-WARNed context-budget ceiling overage (gate 20). The differing failure
  count between the two runs confirms this is a flaky, byte-count-sensitive pre-existing test,
  not a regression introduced here — `--findings` output from both runs contains zero mentions
  of `consumer` or `deploy-headless`. The fast-gate tier this task's own inline
  `deploy-headless.sh` verification uses (`--skip-slow`) passed cleanly (33/33) in both Phase 4
  runs, which is the tier the `/orchestrate` redeploy checkpoint actually relies on.
- Caller audit (Phase 1): grepped `CONSUMERS_STALE`/`check-consumer-freshness` across the
  repository outside `.claude/**` and `specs/**`; the three known automated `deploy-headless.sh`
  callers (`orchestrate-cycle-plan.sh:588`, `command-gate-out.sh:176`,
  `.github/workflows/check-extension-docs.yml:69`) all read only the exit code and `RESULT=`
  vocabulary — zero genuine `CONSUMERS_STALE=` consumers found, so no call site needed the new
  flag passed.

## Impacts

- The `/orchestrate` inter-cycle redeploy checkpoint and `command-gate-out.sh`'s redeploy trigger
  no longer pay the ~50-repo consumer-freshness walk's wall-clock cost on every cycle (the scan
  itself measured ~2s for 35 rows in isolation at Phase 1; the walk simply does not run at all
  by default now).
- An operator who wants the consumer-staleness signal on demand runs
  `bash agent-system/extensions/core/scripts/deploy-headless.sh --consumer-report` (or the
  deployed `.claude/scripts/deploy-headless.sh` equivalent) and gets output byte-compatible with
  the pre-change unconditional behavior.
- No change to the deploy's verification path or exit-code contract: `verify_rc` is assigned
  strictly before the (now-gated) consumer block and is never reassigned by it in either mode.

## Follow-ups

- None. The task description names this as the lowest-risk of three redeploy-checkpoint tasks,
  landing first so `deploy-headless.sh` is settled before further gate-depth work modifies it;
  that ordering is now satisfied.

## References

- Plan: `specs/180_make_consumer_freshness_scan_opt_in/plans/01_consumer-freshness-scan-opt-in.md`
- Progress files: `specs/180_make_consumer_freshness_scan_opt_in/progress/phase-{1..5}-progress.json`
- Precedent: `specs/archive/152_decouple_stale_declarations_from_deploy_gating/plans/01_decouple-stale-declarations.md`
  (introduced the `RESULT=`/`CONSUMERS_STALE=` marker vocabulary preserved here)
