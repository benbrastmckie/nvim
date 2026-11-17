# Implementation Summary: Task #624

- **Task**: 624 - Make system-defect-record.sh able to attribute a dispatched-agent defect from a deploy-consumer repository
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T22:46:00Z
- **Completed**: 2026-11-18T01:05:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None (both declared dependencies were already closed and settled adjacent questions, per the research report)
- **Artifacts**: plans/01_signal-b-deploy-consumer-resolution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`system-defect-record.sh`'s Signal B `--dispatched-agent` attribution resolved an agent name to
its definition file by globbing `agent-system/extensions/*/agents/NAME.md`, a path that exists
only in the repository physically holding the source store. In any deploy consumer (a repo
carrying only the regenerated `.claude/**` mirror) the glob could never match, so the recorder
refused with exit 3 and the defect was lost to a non-fatal log line. This implementation added a
second resolution route, reached only when the glob finds nothing, that looks up each
extension's `source_dir` in `.claude-extensions.json` and checks for the agent file there,
emitting the identical `agent-system/extensions/<ext>/agents/<NAME>.md` string the glob route
produces. A four-case fixture suite pins both routes, their path-shape parity, and the preserved
exit-3 refusal; the governing discrimination document's resolver prose was updated to match; and
the fix was deployed and attested end-to-end against both a scratch consumer-shaped tree and the
real consumer repository that originally reproduced the defect.

## What Changed

- `agent-system/extensions/core/scripts/system-defect-record.sh` — added
  `resolve_agent_via_extensions_manifest()`, called as a fallback inside the `--dispatched-agent`
  branch only when the existing `agent-system/extensions/*/agents/NAME.md` glob finds nothing;
  updated the header's resolver description to name both routes.
- `agent-system/extensions/core/scripts/tests/test-system-defect-record-signal-b.sh` — new
  four-case fixture suite (11 assertions): (a) consumer route resolves via `.claude-extensions.json`
  with no local `agent-system/` subtree, (b) a non-core extension key is named correctly in the
  resolved path, (c) the glob route is unchanged and emits the identical resolved-path string as
  (a), (d) the exit-3 refusal and its message are unchanged when nothing resolves. Resolution is
  proven via the recursion-guard echo (a fixture `orchestrator-critical-paths.json` marking the
  expected resolved path `recursion_guard: true`), never an event write.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — one `unit` row for
  the new suite.
- `agent-system/extensions/core/manifest.json` — `provides.scripts` entry for the new suite,
  inserted mechanically via `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — the resolver
  paragraph now names both resolution routes (glob, then the `.claude-extensions.json`
  `source_dir` fallback), keeping the exit-3-on-unresolvable and `--attributed-path`-precedence
  statements intact.
- `agent-system/extensions/core/index-entries.json` — hand-corrected `line_count` for
  `system-defect-discrimination.md` (578 -> 583), required because
  `generate-context-line-counts.sh` cannot run from the source store.
- Regenerated deployed `.claude/**` tree (deploy artifact, via `deploy-headless.sh`; not
  hand-authored, not tracked by git).

## Decisions

- Glob-first, manifest-fallback ordering: the new helper is reached only when the existing glob
  resolves nothing, leaving the source-store-holding repository's hot path and every existing
  `agent-system/`-shaped fixture bit-for-bit unchanged.
- The helper reconstructs the resolved-path string from the extension key
  (`agent-system/extensions/<key>/agents/<NAME>.md`) rather than deriving it from the absolute
  `source_dir` path, so the output shape is byte-identical to the glob route's regardless of
  where `source_dir` physically points.
- Every failure mode inside the new helper (missing manifest, unreadable jq, missing/unreachable
  `source_dir`, no matching agent file) falls through to an empty result rather than aborting the
  recorder under `set -euo pipefail`.
- Resolution is proven in the fixture suite via the recursion-guard echo rather than an event
  write, avoiding copying `events-append.sh`/`events-query.sh` and their dependency chain into
  any fixture.
- No live recording call was made into the external `cslib` repository that originally
  reproduced the defect; its attestation is a read-only replay of the `source_dir` lookup instead.

## Plan Deviations

- Phase 4's "run the complete gate set" task was altered to the scoped tier this dispatch's own
  Batch Gate Deferral directive requires (`verify-deploy.sh --only-gate 3,4,5,8 --skip-unchanged
  --gate8-touched <task's touched files>`) rather than an independent unflagged
  `verify-deploy.sh` run. The complete gate set runs once for the whole batch at the end of the
  invocation per that directive.
- Phase 2's task list stated "four sibling dependencies" for the fixture suite but named only
  three (`deploy-root-guard.sh`, `lib/common.sh`, `lib/file-scope-overlap.sh`); confirmed by
  reading the subject's own `source`/`.` lines that three is the complete and correct set — a
  count slip in the plan text, not a missed dependency.

## Verification

- Build: N/A (shell scripts; `bash -n` syntax check passed).
- Tests: `test-system-defect-record-signal-b.sh` — 11/11 assertions passed (all four cases).
  Covering suite list for Phase 1 (6 suites) passed. `sync-manifest-scripts.sh --check` passed.
  Scoped `verify-deploy.sh` gates 3, 4, 5 passed clean; gate 8 (narrowed via `--gate8-touched`)
  reported 3 failing suites, all confirmed unrelated to this task's `file_scope` (one pre-existing
  documented EXPECTED/load-sensitive failure, two NEW failures traced to other tasks'/extensions'
  files — see Follow-ups).
- Files verified: Yes — diffed the deployed copy of `system-defect-record.sh` against the source
  store (byte-identical) and confirmed the deployed suite exists.
- End-to-end attestation: a scratch consumer-shaped tree (deployed `.claude/` copy, a
  `.claude-extensions.json` pointing at this repository's real `agent-system/extensions/core`, no
  `agent-system/` subtree of its own) invoked the deployed recorder with
  `--dispatched-agent general-research-agent`; it exited 0 and recorded
  `detail.attributed_source_path = "agent-system/extensions/core/agents/general-research-agent.md"`
  — the inverse of the original reproduction. A read-only replay against the real consumer
  repository that originally reproduced the defect (`/home/benjamin/Projects/cslib`) confirmed its
  `.claude-extensions.json` `source_dir` lookup resolves to an existing agent file there.

## Impacts

- A dispatched-agent-attributed defect (e.g. a `RECOVERY_DECLINED` detection) raised from a
  deploy-consumer repository is now recorded durably instead of being silently lost to a
  non-fatal log line.
- No change to the recursion guard, dedup rule, detail payload, defect-class enum, or any call
  site's invocation convention — the fix is purely additive on the path that previously refused.

## Follow-ups

- `test-lint-unit-integration-boundary.sh` currently fails against the live corpus because two
  OTHER suites lack `suite-classification.data` rows: `test-lint-fixture-dependency-declaration.sh`
  (introduced by a different, already-closed task) and the sapience extension's
  `test-sapience-context-scoping.sh`. Neither file is in this task's scope; recorded via
  `issue-record.sh` for whichever task/extension owns them.
- `test-mcp-merge-target.sh` fails on two `.mcp.json` merge assertions unrelated to this task,
  plausibly concurrent-session MCP state contamination under a multi-task batch. Recorded via
  `issue-record.sh`; not investigated further here as out of scope.
- The research report's separately-flagged latent misattribution risk in
  `transform_deploy_to_source()` (the `--attributed-path` branch mapping every bare `.claude/X`
  to `extensions/core/X`, which would be wrong for the flat-merged `.claude/agents/` directory)
  remains unaddressed — explicitly out of scope for this task, worth a separate record.

## References

- Research report: `specs/624_defect_record_unresolvable_in_deploy_consumer/reports/01_signal-b-deploy-consumer-resolution.md`
- Plan: `specs/624_defect_record_unresolvable_in_deploy_consumer/plans/01_signal-b-deploy-consumer-resolution.md`
- Governing pattern document: `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
