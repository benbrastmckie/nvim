# Implementation Summary: Task #587

- **Task**: 587 - Error logging contract and central log
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T00:00:00Z
- **Completed**: 2026-11-11T06:30:00Z
- **Effort**: ~11 hours (matching the plan's own estimate)
- **Dependencies**: None (coordinates with, but does not depend on, tasks 477, 484, 519, 543, 562)
- **Artifacts**: plans/01_error-logging-contract-central-log.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Error logging in this agent system was incoherent: the documented contract named an abandoned
store (`errors-append.sh`/`errors.json`, zero production writers, over two months stale) while
the two stores actually carrying failure traffic (`issues.jsonl`, `events.jsonl`) went unmentioned.
This task resolved that divergence for every error class at once: corrected the contract to name
the live store, added one seed class distinguishing infrastructure/transport unavailability from
work failure, documented a general occurrence-collapse convention plus a citation render cap,
and added a push-based promotion path from the two live writers to a single central cross-repo
log in this repository. Sapience backend failure is implemented strictly as a subclass of that
mechanism: a mechanical capture point in `sapience-retrieve.sh`'s exit-code split, and an honest,
explicitly best-effort note for the MCP-tool class that cannot be captured mechanically at all.
All seven planned phases executed; the final phase closed `[COMPLETED WITH EXCLUSIONS]` against
two confirmed pre-existing, unrelated findings (see "Plan Deviations" below) rather than a literal
all-green gate run.

## What Changed

- `agent-system/extensions/core/context/formats/issue-log.md` — 16-class seed enum (new
  `infrastructure/transport unavailable` class), corrected count references throughout, new
  `### Occurrence Collapse` subsection, new `## The Three-Store Topology` section, new
  `## Central Cross-Repo Log` section specifying the envelope and promotion filter
- `agent-system/extensions/core/scripts/issue-record.sh` — new seed class in
  `ISSUE_SEED_CLASSES`; non-fatal `central_log_promote` call wired in after the local append;
  the `lib/central-log-lib.sh` source call is guarded (file-existence check with a no-op
  fallback) so a fixture lacking the library degrades instead of crashing
- `agent-system/extensions/core/scripts/events-append.sh` — the symmetric `central_log_promote`
  wiring and the same defensive source guard
- `agent-system/extensions/core/scripts/lib/central-log-lib.sh` — new: `central_log_promote`,
  the single exported function implementing owning-repository resolution, the owning-repo skip,
  the promotion filter, a `jq -c -n` envelope, and a bounded `flock`-guarded append with
  single-generation rotation at 20000 lines
- `agent-system/extensions/core/scripts/tests/test-central-log-lib.sh` — new: 15-assertion
  fixture-driven unit suite for the library above
- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` — new
  `central-errors-lock` 25th file-class member (`**/.central-errors.lock`)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` — matching
  documentation row and fenced-block line for the new lock pattern (byte-identity with the
  lib's generated output re-confirmed)
- `specs/.gitignore` — managed block regenerated with the new lock pattern
- `agent-system/extensions/core/manifest.json` — `provides.scripts` rows for the new library and
  its test suite (via `sync-manifest-scripts.sh --write`)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — `unit` rows for
  `test-central-log-lib.sh` and `test-sapience-capture.sh`
- `agent-system/extensions/core/rules/error-handling.md` — `### 1. Log the Error` rewritten to
  name `issue-record.sh`; no-task-context route added; `#### Where Errors Are Stored` and
  `#### External Errors Mapped` subsections added; compressed during Phase 7 to recover
  eager-load budget
- `agent-system/extensions/core/context/formats/events-format.md` — note at the `category`
  closed-enum discussion recording non-task-scoped error capture as an intended use of the
  nullable `task` field
- `agent-system/extensions/core/scripts/tests/test-issue-record.sh` — three new cases: foreign-
  repo promotion with full envelope verification and unchanged stdout contract, the win filter,
  and the unwritable-target no-op
- `agent-system/extensions/sapience/scripts/sapience-retrieve.sh` — `curl --write-out` retains
  the HTTP status; exit codes split (1 benign no-match, 2 genuine transport/HTTP failure with a
  length-bounded stderr diagnostic); no added network call or latency on the success path
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — Stage 3.5's
  `memory_context` block captures the retrieval exit code and stderr, recording an
  `infrastructure/transport unavailable` entry non-fatally only on the genuine-failure code
- `agent-system/extensions/sapience/EXTENSION.md` — postflight wrapup records a failed
  `sapience-remember.sh` call; best-effort MCP self-report note with the mechanical gap stated
- `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md` — the
  same mechanical-gap statement at the two scripts' contract description, plus the updated
  exit-code-split description for `sapience-retrieve.sh`
- `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` — new: 11-assertion
  curl-stubbed suite covering the measured 503 body, a benign zero-hit 200, a successful
  200-with-hits, and a curl transport failure
- `agent-system/extensions/sapience/manifest.json` — `provides.scripts` row for the new suite
- `agent-system/extensions/memory/context/project/memory/distill-usage.md`,
  `agent-system/extensions/memory/context/project/memory/patterns/distill-revise-submode.md` —
  corrected two stale claims that `sapience-retrieve.sh`'s exit 1 made a zero-hit result and a
  transport failure indistinguishable, now false given this task's exit-code split
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — `--aggregate`
  caps each class's rendered `citations[]` at 10 and adds a `citations_remainder` field (the
  exact withheld count); `group_by(.class)` and the `(.resolution // "open")` predicate are
  byte-identical to before
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — documents the cap, the
  `citations_remainder` field, and the render-time obligation to surface a nonzero remainder
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` — two new
  cases: a 13-entry class renders 10 citations plus `citations_remainder == 3`; a 4-entry class
  renders all 4 with `citations_remainder == 0`
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — reviewed,
  dated `eager_load.baseline_bytes` move (68700 -> 70400) following this document's own
  established convention, after trimming both eager additions to compact pointer form
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` — Case 5's hardcoded
  expected class-member count corrected from 24 to 25
- `agent-system/extensions/core/index-entries.json`,
  `agent-system/extensions/memory/index-entries.json`,
  `agent-system/extensions/sapience/index-entries.json` — regenerated line counts
  (`generate-context-line-counts.sh`, run automatically by `deploy-headless.sh`)

## Decisions

- Reused `issues.jsonl` rather than create a new store (research decision 1); corrected the doc
  pointer rather than revive `errors-append.sh` (decision 2); one net-new seed class rather than
  a renormalization (decision 3); `tags.occurrence` write-side collapse plus a citation render
  cap, since `group_by(.class)` already performs read-time collapse (decision 5); mechanical
  capture only where a script already holds the diagnostic, with the MCP-tool class recorded as
  an accepted gap (decision 6); `events.jsonl` with `task: null` for the no-task-context case
  (decision 7); push, not pull, with an owning-repo skip and `flock` (decision 8).
- `central_log_promote`'s fixed two-argument signature resolves the writing repository's root by
  self-location (its own deployed path, via `common_repo_root`) rather than reading a
  caller-supplied `$PROJECT_ROOT` global, keeping the function independently testable and correct
  regardless of caller shell state.
- Guarded the `lib/central-log-lib.sh` source call in both writers with a file-existence check
  (falling back to a no-op `central_log_promote` stub) rather than requiring every existing test
  fixture that copies either writer to also be updated — this follows the library's own
  already-established silent-no-op design posture for every other unreachable-dependency case.

## Plan Deviations

- **Phase 3**: edited `context/standards/orchestrator-runtime-files.md` even though it was not
  named in Phase 3's Files-to-modify list — a direct, required consequence of adding a
  `runtime-file-patterns.sh` class member (that file's fenced block is mechanically pinned to the
  library's generated output by `test-runtime-file-tracking.sh` Case 3).
- **Phase 5**: corrected two stale cross-references in `memory/context/project/memory/{distill-
  usage.md,patterns/distill-revise-submode.md}` claiming `sapience-retrieve.sh`'s exit 1 made a
  zero-hit result and a transport failure indistinguishable — directly required by the Scope
  Hypothesis's own "adapt any site that reads the exit code" instruction once the stale claim was
  found during the call-site audit.
- **Phase 7**: the eager-load context budget (gate 20) regressed from this task's own necessary
  content growth (the corrected error-handling contract plus the Sapience capture documentation).
  Resolved via trim-then-reviewed-baseline-move, following the budget file's own established
  precedent and rounding convention, rather than leaving necessary contract-correction prose
  unwritten.
- **Phase 7**: a genuine regression was found and fixed mid-phase: `issue-record.sh`/
  `events-append.sh`'s unconditional `source lib/central-log-lib.sh` crashed any existing test
  fixture that copied either script without the new library. Fixed by guarding the source call;
  re-verified every affected suite green.
- **Phase 7 closed `[COMPLETED WITH EXCLUSIONS]`**: the complete gate set (`verify-deploy.sh`,
  no `--skip-slow`) and the full test corpus (`run-all.sh`) are not literally all-green. Two
  findings remain, both confirmed pre-existing and unrelated to this task via `git log` and
  direct reproduction (see the plan's own Phase 7 Reasoned Exclusions table for the full
  evidence): gate 24's `/ide` dead-command-recommendation finding in two untouched memory-extension
  docs, and 5 test suites (`test-deploy-baseline-lib.sh`, `test-gate-cache-lib.sh`,
  `test-gate-registry-resolution.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-build-aux-dispatch.sh`) that fail only when invoked from their deployed
  location, due to each suite's own hardcoded repo-root walk-up depth assuming source-store
  invocation — all five pass 100% when run from the source-store path instead.

## Verification

- Build: N/A (markdown/shell agent-system task)
- Tests: Phases 1-6's own tier-justified suite subsets all green (verified against the real
  edited logic via temporary deployed-copy overwrite-then-restore where the deploy was pending);
  Phase 7's full `verify-deploy.sh` and `run-all.sh` green except the two reasoned exclusions
  above
- Files verified: Yes — every new file registered in its owning extension's `manifest.json`
  (`sync-manifest-scripts.sh --write`); every new suite has a `suite-classification.data` row;
  `shellcheck -S warning` clean on every touched/created shell file

## Impacts

- A reader or agent following `rules/error-handling.md` now reaches the store that is actually
  written, not an abandoned one.
- Every repository sharing this agent system now has a cross-repo inbox
  (`specs/central-errors.jsonl` in the owning repository) showing error-bearing records promoted
  from any consumer repository's `issues.jsonl`/`events.jsonl`, with no repo enumeration and no
  dependency on the (currently unusable) extension repo registry.
- A Sapience backend outage (the motivating case) now produces a readable, classified record in
  both the originating task's log and the central log, with zero added network calls and
  measured per-call promotion overhead of **~17ms** (one `jq -c -n` envelope build, one `wc -l`
  line count, one `flock`-guarded local filesystem append) — matching the plan's (g) cost-ceiling
  requirement.
- A long outage or a high-volume same-class emitter now renders as a bounded, readable proposal
  at the conclusion stage (10 citations plus an explicit remainder count) instead of an unbounded
  list.

## Follow-ups

- Whether `errors.json`/`errors-append.sh`/`/errors` should be retired outright remains an open
  question, explicitly deferred (would delete a command and a schema).
- The 5 pre-existing repo-root-walk-up test-suite bugs identified during Phase 7 (see Plan
  Deviations) are a correctly-scoped, independent follow-up candidate — fixing 5 suites' own
  path-depth assumptions is unrelated to error-logging content.
- Task 484 (collapse per-path scope-excursion rows) may now adopt this task's general
  `tags.occurrence` collapse convention as an application of it, per the research report's own
  boundary statement; no phase here edited either of 484's named emitter sites.

## References

- Research report: `specs/587_error_logging_contract_and_central_log/reports/01_error-logging-contract.md`
- Plan: `specs/587_error_logging_contract_and_central_log/plans/01_error-logging-contract-central-log.md`
- Per-phase handoffs: `specs/587_error_logging_contract_and_central_log/handoffs/phase-{1,2,3,4,5,6}-handoff-*.md`
- Issue log: `specs/587_error_logging_contract_and_central_log/issues.jsonl`
