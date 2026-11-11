# Implementation Summary: Task #313

- **Task**: 313 - Advisory lint for hand-authored /orchestrate batch proposals in ROADMAP.md
- **Status**: [COMPLETED]
- **Started**: 2026-11-11T21:20:00Z
- **Completed**: 2026-11-11T23:35:00Z
- **Effort**: ~2 hours
- **Dependencies**: 306 (completed), 328 (completed), 344 (completed), 387 (completed), 401 (completed), 402 (completed)
- **Artifacts**: plans/01_roadmap-batch-proposal-lint.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built `scripts/lint/lint-roadmap-batch-proposals.sh` in the core extension's source store: a
purely advisory lint over the hand-authored `/orchestrate` batch proposals in a repository's
`specs/ROADMAP.md`, reporting four finding classes — (a) territory under-inclusion, (c) a batch
over `MAX_TASKS=8`, (d) a cited task that is terminal or nonexistent, (f) an unresolvable cited
repository path — plus one declarative statement (finding (e)) added to the format contract. The
lint never blocks (exit code unaffected by findings), never proposes or ranks a batch, and is
wired into the `/orchestrate` conclusion stage's Step 5, after the roadmap regenerate pass.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` — new file. Header
  states the advisory contract, the exit-0-on-findings divergence from sibling lints, the
  validator-never-proposer constraint, the absent-`file_scope` posture, and the 603 follow-up
  risk. Implements the layout sniff (classic/stage/unknown, transcribed from
  `roadmap-format.md`'s prose), the authored-Run-line parse (stopping at the generated coverage
  appendix), findings (c)/(d)/(f), and finding (a) — a single spliced `jq -n` program over
  `$FILE_SCOPE_OVERLAP_JQ_DEFS` from `scripts/lib/file-scope-overlap.sh` (no local copy of the
  overlap predicate anywhere in the file; `grep -c 'startswith'` returns 0).
- `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` — new fixture
  suite: one fixture per finding, the two required negative cases (rejected finding (b)'s
  absence; finding (f)'s two false-positive classes), unknown/stage layout cases, and the two
  mechanical assertions (exit-0-with-findings; real-corpus completion). 10/10 PASS.
- `agent-system/extensions/core/manifest.json` — registered both new files in `provides.scripts`
  at their sorted position.
- `agent-system/extensions/core/context/formats/roadmap-format.md` — finding (e)'s declarative
  paragraph added to `## Next Grammar`: an intra-batch `dependencies[]` edge sequences rather
  than disqualifies, citing (not restating) the guardrails document's Gate Catalogue.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 5 now invokes the
  lint after the roadmap regenerate commit, with the advisory/not-a-fourth-channel sentence; Step
  6 records that the findings appear with Step 5's output.
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — Consumers list
  gains this lint as a fourth active caller; the count sentences are corrected throughout.
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — the unnamed forward
  reference to "a separate, advisory lint... already planned as dependent work elsewhere" is
  replaced with a named pointer to the real script and its conclusion-stage call site.
- `specs/state.json` — (Phase 1, state-management only, no `file_scope` declaration per Decision
  D6) removed the stale `agent-system/extensions/core/commands/review.md` entry from this task's
  own `file_scope`; added serializing `dependencies[]` edges (603, 558, 562, 602 each now depend
  on 313) onto the records sharing this task's declared territory.

## Decisions

- Spliced `$FILE_SCOPE_OVERLAP_JQ_DEFS` into one `jq -n` program covering the whole Run-line
  cross-product (plan Decision D1), the same shape `orchestrate-batch-admit.sh` uses — never a
  per-pair shell-out.
- Finding (f)'s resolution went beyond the task record's two named guards after live-corpus
  testing surfaced 40 mostly-false findings (paths authored relative to `.claude/` or to a
  source-store extension directory with the `agent-system/extensions/` prefix dropped). Added
  multi-root resolution, a whitespace-is-not-a-path guard, and a literal-`...`-elision guard,
  reducing to 14 (now 8, after task 402 completed mid-session and cleared several finding (d)
  hits) — the residual class is documented in the script's own header rather than chased
  further, to avoid over-fitting the two named guards to one corpus document's current prose.
- Dropped the plan's "(Decision D4)" label from the Step 6 deliverable prose itself (kept the
  underlying fact); a task-plan decision label is not a durable anchor for a future reader of
  `conclusion-stage.md`.

## Plan Deviations

- None in substance. Finding (f)'s extra precision work (above) is an elaboration within the
  same task item, verification-driven, not a deviation from what was asked.

## Verification

- Build: N/A (bash scripts + markdown)
- Tests: `scripts/tests/test-lint-roadmap-batch-proposals.sh` 10/10 PASS. `test-roadmap-
  generation.sh` 105/105. `test-orchestrate-conclusion-aggregate.sh` 14/14. `test-manifest-
  scripts-sync.sh` and `test-script-inventory.sh` both green (re-verified from the deployed tree
  post-deploy, scoped via `run-all.sh --only`). `lint-shellcheck.sh` and `lint-test-harness-
  adoption.sh` both clean on the new files. `check-task-references.sh` reports 0 occurrences in
  every touched file.
- Files verified: Yes.
- **Gate deferral (per this dispatch's Batch Gate Deferral directive)**: this task's final phase
  declares `**Verification Tier**: full`, discharged against a SCOPED tier rather than
  independently running the complete gate set, because this dispatch is one of several
  concurrently co-dispatched `/orchestrate` tasks in one multi-task batch invocation.
  `deploy-headless.sh --skip-verify` landed the source-store change into the live `.claude/` tree
  (`RESULT=landed_verify_skipped`, exit 4 — the documented, expected outcome of a deliberate
  `--skip-verify` call, not a phase failure). The lint was then confirmed directly callable from
  the deployed path (exits 0 against the live `specs/ROADMAP.md`, 141 findings at this
  measurement — see below), and its test suite was confirmed discovered and green from the
  deployed tree via the scoped narrowing invocation `run-all.sh --only
  test-lint-roadmap-batch-proposals.sh` (1 passed, 0 failed). The complete gate set (including
  Gate 8's full `run-all.sh` battery) is deferred to the once-per-invocation batch-level stage at
  the end of this orchestrate cycle, per `context/contracts/phase-closure.md`'s no-promotion-
  without-evidence carve-out, and is NOT independently run or claimed green by this phase.
  `next_project_number` confirmed unchanged (607, before and after). No pre-existing gate
  failure was encountered in any scoped check run during this phase; every suite invoked
  (`test-lint-roadmap-batch-proposals.sh`, `test-manifest-scripts-sync.sh`,
  `test-script-inventory.sh`, `test-roadmap-generation.sh`,
  `test-orchestrate-conclusion-aggregate.sh`) passed cleanly, so there is nothing to record as a
  reasoned exclusion here.

## Finding Counts Against the Live Corpus (measured at deploy time, post-deploy)

Run against the deployed `specs/ROADMAP.md` with no explicit `--roadmap`/`--state` (default
resolution): `layout=classic`, `authored_run_lines=11`, `findings=141` — breakdown: a handful of
finding (d) hits (tasks cited in Run 1 that completed mid-session, during this same concurrent
batch cycle — a real, current transient-staleness signal, not a lint defect), a small number of
finding (f) hits (one genuine already-known-defect true positive —
`agent-system/extensions/core/scripts/lint-dead-command-recommendations.sh`, which the live
ROADMAP.md text itself independently documents as missing its `lint/` path segment — plus a
documented residual false-positive class, see the script's own "KNOWN RESIDUAL NOISE" header
paragraph), and the bulk (finding (a)) from coarse, widely-shared `file_scope` paths
(`__WHOLE_TREE__`, `plan-format.md`, `manifest.json`, etc.) across the backlog's 11 authored
batches — the volume the plan's own Scope Hypothesis explicitly anticipated and sanctioned as
correct output rather than a defect to suppress.

## Impacts

- An under-inclusive hand-authored batch (the real observed failure this task exists to close)
  is now caught once per `/orchestrate` invocation, at the conclusion stage, instead of only at
  dispatch time or never.
- `file-footprint-overlap.md`'s overlap predicate now has a fourth named consumer with a
  documented consumption shape, keeping the "one physical implementation, several splice sites"
  invariant intact.

## Follow-ups

- Record 603 (`roadmap-as-generated-artifact`) will move batch membership out of this file's
  hand-authored `## Next` prose into `state.json` entries; when that lands, this lint's entire
  parse layer needs rescoping against the new source of truth. Named in the script's own header
  as an accepted follow-up cost (per the user's recorded decision to proceed now against the
  live grammar), not solved here.
- Finding (f)'s documented residual false-positive class (citations that drop more than the
  `agent-system/extensions/<ext>/` prefix, placeholder words, transient runtime paths) is left
  as a stated limitation rather than chased to zero on this one corpus document.

## References

- Research: `specs/313_advisory_lint_for_roadmap_batch_proposals/reports/01_roadmap-batch-lint-seam-selection.md`
- Plan: `specs/313_advisory_lint_for_roadmap_batch_proposals/plans/01_roadmap-batch-proposal-lint.md`
- Script: `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh`
- Test suite: `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh`
