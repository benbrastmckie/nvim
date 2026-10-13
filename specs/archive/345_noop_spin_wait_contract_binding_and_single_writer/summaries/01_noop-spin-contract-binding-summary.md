# Implementation Summary: Task #345

- **Task**: 345 - No-op spin wait-contract binding and single-writer discipline
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T13:33:00Z
- **Completed**: 2026-10-08T15:58:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: Task 343 (settled/archived; taken as given, not re-litigated)
- **Artifacts**: plans/01_noop-spin-contract-binding.md, reports/01_noop-spin-contract-binding.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, shell-script-testing.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md

## Overview

Research confirmed the measured incident (a 689-call, ~62-minute spin alternating `echo idle`
with a `grep`/`tail`/`wc` log read) is **Branch B**: `detect-noop-bash.sh`'s streak counter
deleted on every non-trivial command, so the alternating pattern never exceeded a streak of 1
against the fire threshold of 3 -- mechanically confirmed by replaying the real transcript through
the unmodified hook (0 firings). This implementation closes that streak-accounting gap in the
hook, extends the two existing pattern documents that already own the no-op-filler and
single-writer defect classes, and adds a committed regression fixture -- with **zero new
documents** and **no agent-prompt edit**, exactly as scoped.

## What Changed

- `agent-system/extensions/core/context/patterns/external-process-wait.md` -- Rule 2 ("No no-op
  filler") extended to name a repeated completion-polling log/status read as the same defect
  class as `:`/`true`/`date`/`echo waiting`, with the read-once alternative stated narrowly (log
  inspection itself is not forbidden, only repeated polling); one sentence confirming the rule
  applies identically to a local-build wait; and a compact "Contract home" paragraph recording
  this file as the single home for the filler prohibition, with `bounded-build-waiter.md` and
  `context/contracts/orchestrator-discipline.md` recorded as rejected candidates and why
  (the latter's own stated orchestrator-only audience).
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` -- new Required Rule 5
  ("One writer per shared tree"): at most one writer per shared fixture/build tree per dispatch,
  enforced by a `flock()`-held lock scoped to the tree root (`lake-build-guard.sh` cited by name
  as prior art, extended in "Conforming Examples" rather than reinvented), with the measured
  three-overlapping-invocations failure shape recorded as evidence. A new "Sizing a Wait Near the
  Per-Call Ceiling" subsection records the near-ceiling ruling (repeated bounded `kill -0`-gated
  iterations instead of one call sized to the full runtime). A "Rule 5 Non-Propagation Ruling"
  subsection records that Rule 5 is deliberately not added to the generated-copy agent-contract
  bullet pair, citing `propagate_bounded_wait_contract_and_lint_coverage` by project name as the
  standing ground for that separate concern. Rules 1-4 and the "Copy this exact text" fenced block
  are byte-identical to before.
- `agent-system/extensions/core/hooks/detect-noop-bash.sh` -- three-class streak accounting
  (Class T trivial / Class P repeated inspection probe / Class W genuine progress), a new
  `inspection_fingerprint` function (quote-blanked segment split, allowlist
  `cat`/`tail`/`head`/`wc`/`grep`/`ls`/`stat`/`test`/`[`, widened per the plan's own Scope
  Hypothesis to also accept a bare/literal `echo` via the existing `is_trivial_segment` and a
  `kill -0`-only liveness check), a FIFO-capped `noop-bash-shapes-<session>` sidecar surviving a
  Class-W counter reset, a widened advisory message naming both pattern files and the newly
  counted class, and a corrected header contract paragraph.
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` -- five new case groups:
  a measured-alternation regression (the real 29-command slice, indices 112-140 of the incident
  transcript, paths normalized), a pre-change-behavior-gone assertion, a productive-work control,
  a first-seen-versus-repeat case, and a sidecar-robustness case. Purely additive (199 insertions,
  0 deletions); all 40 pre-existing cases pass unmodified alongside the 10 new ones (50/50).

## Decisions

- **Branch A/B re-confirmed as Branch B** by direct mechanical replay of the real 689-command
  transcript through the unmodified production hook (0 firings, max streak 1) -- not re-derived
  from the research report's own figure, independently reproduced.
- **Contract home for the no-op-filler prohibition: `external-process-wait.md`**, amending its
  existing Rule 2. `bounded-build-waiter.md` and `orchestrator-discipline.md` evaluated and
  rejected in the file itself (see "What Changed" above).
- **Single-writer discipline lands in `bounded-build-waiter.md` as a new Rule 5**, not merged into
  the Rule-2 home -- a writer-concurrency concern distinct from Rule 4's waiter-attachment
  concern, modeled on `lake-build-guard.sh`'s existing `flock()` mechanism rather than inventing a
  new one.
- **Allowlist widened beyond the plan's literal three-utility list** to also cover a bare/literal
  `echo` and a `kill -0`-only liveness check, per the phase's own Scope Hypothesis instruction to
  widen deliberately rather than declare the replay unrepresentative. This raised coverage of the
  measured alternation's non-trivial neighbor commands from a literal-list-only reading to 258 of
  262 (98.5%); the remaining 4 (one `awk` `/proc/meminfo` read, one `for`/`case` `/proc` scan) are
  deliberately left classified Class W (genuine progress), not further widened.
- **Phase 5's `verify-deploy.sh` run accepted as `[COMPLETED WITH EXCLUSIONS]`**, not a bare pass
  -- see Plan Deviations below and the plan's own Reasoned Exclusions table.

## Plan Deviations

- **Phase 5, Task "`verify-deploy.sh` exits 0"** altered: the full gate set reports 3 of 35 checks
  FAIL. None traces to a defect in this task's own 4 files:
  - 2 findings (`hooks/detect-noop-bash.sh`, `scripts/tests/test-detect-noop-bash.sh` "content
    differs from source") are this task's own source-store edits not yet propagated to the
    gitignored `.claude/` deploy tree -- the expected, by-design state of any source-store-only
    edit per `context/patterns/regeneration-is-manual-only.md`. Redeployment runs only through one
    of exactly two sanctioned automated call sites (`command-gate-out.sh`'s `rc==6` branch,
    `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint); this dispatch is neither, so
    invoking `deploy-headless.sh` here would be an unsanctioned third call site, not a remedy.
  - 2 more gate-5 findings (`scripts/orchestrate-cycle-postflight.sh`,
    `scripts/tests/test-orchestrate-cycle-postflight.sh`) and all 3 of doc-lint's (gate 3) `core`
    FAIL lines trace to concurrent territory-sibling task 284's own in-progress edits -- a
    byte-for-byte match against that sibling's declared `file_scope` in this dispatch's own
    Territory payload, which explicitly warned not to treat this as a regression.
  - Gate 8's sole failing suite, `test-four-tier-conflict.sh` case 6 (a timing-budget assertion,
    `elapsed_ms=2745` vs. `budget_ms=1000`), is unrelated to any of this task's 4 files and was
    confirmed to pass 13/13 (including case 6, `elapsed 1656ms`) when re-run standalone
    immediately afterward -- consistent with load-induced timing flakiness during the concurrent
    multi-gate run, not a regression this task introduced.
  - See the plan's Phase 5 `#### Reasoned Exclusions` table for the full per-item record.

## Verification

- Build: N/A (no build step for this task type)
- Tests: `test-detect-noop-bash.sh` 50/50 passing (40 pre-existing unmodified + 10 new);
  `shellcheck` clean on both changed shell files; `lint-agent-contracts.sh --verbose` 0 failed
  (Check H 14/14); `check-task-references.sh` 0 occurrences on all 4 files.
- `verify-deploy.sh`: FAIL (3/35) -- see Plan Deviations above; not attributable to this task.
- Files verified: Yes (4 modifications, 0 additions under `agent-system/**`, confirmed via
  `git log --name-status` filtered to this task's own commits).

### BEFORE/AFTER measurement (method)

The real 689-command sequence was extracted directly from the incident's own sidechain transcript
(still on disk at the path recorded in the research report) and replayed, one command at a time,
through the hook binary as a fresh session with a scratch `NOOP_BASH_STATE_DIR`, counting
`additionalContext` occurrences and the counter file's observed maximum value between calls.

| | Full 689-command transcript | Committed 29-command fixture slice (indices 112-140) |
|---|---|---|
| BEFORE (unmodified hook) | 0 firings, max streak 1 | 0 firings, max streak 1 |
| AFTER (modified hook) | 77 firings, max streak 36, first fire at call 139 | 1 firing, max streak 3, first fire at call 28 |

The fixture slice additionally demonstrated the reverse direction: swapping in the pre-change hook
(`git show HEAD~1:...`) made exactly the 4 new fixture assertions fail (0 fires, max streak capped
at 1, repeat-shape counter missing), then the modified hook was restored and diff-confirmed
byte-identical to its pre-swap state.

## Impacts

- A dispatched agent alternating a trivial filler call with a repeated read-only completion probe
  (the exact measured incident shape) now reaches the advisory threshold instead of being
  structurally incapable of it -- within 28-139 calls depending on how quickly the probe's shape
  stabilizes, rather than never.
- The advisory message itself is now actionable for a local build/test spin: it names
  `bounded-build-waiter.md`'s captured-pid/`kill -0`/outer-timeout idiom alongside the pre-existing
  `external-process-wait.md` pointer, closing a content gap the research found in one of the two
  historical firings that did reach a subagent.
- Single-writer discipline for a shared fixture/build tree now has a stated, evidenced mechanism
  (not only an exhortation) in the same document that already owns "one waiter per log."

## Follow-ups

- **Consumer-repo recommendation (not implemented here)**: the measured incident's certify suite
  runs ~9.5 minutes (570s), 30s inside the Bash tool's 600s per-call ceiling -- `external-process-wait.md`'s
  own 540-versus-600 margin reasoning argues that margin is already too thin for a single bounded
  call. The consumer repo should shard or shorten that suite, or adopt the repeated-bounded-iteration
  sizing this task recorded in `bounded-build-waiter.md`.
- **Consumer-repo recommendation (not implemented here)**: the deployed `.claude/hooks/` copy in
  any consumer repo picks up this task's streak-accounting fix only on its next regeneration
  (interactive `[Reload All]`/`[Regenerate]`, or `deploy-headless.sh` through one of its two
  sanctioned automated call sites).
- **Declined for now**: context-sensitive advisory text that detects a nearby backgrounded local
  job and tailors the message accordingly. Declined because the widened message now names both
  idioms unconditionally, which already closes the research report's Finding 2 content gap
  without new detection logic.
- **Out of scope by design, filed separately**: propagating the bounded-wait MUST/MUST-NOT
  contract bullet pair (and Rule 5) to the fourteen implementation-agent files lacking it, and
  asserting that coverage in `lint-agent-contracts.sh`, is the standing ground of
  `propagate_bounded_wait_contract_and_lint_coverage` -- not absorbed here, per the dispatch's own
  explicit boundary.
- **Observed, not actioned**: a concurrent modification to `agent-system/extensions/core/index-entries.json`
  (a `line_count` auto-repair for this task's own two edited pattern files, consistent with a
  concurrent sanctioned redeploy-checkpoint run) was left untouched, outside this task's declared
  `file_scope`. Recorded via `issue-record.sh` (class "scope excursion", severity minor).

## References

- `specs/345_noop_spin_wait_contract_binding_and_single_writer/reports/01_noop-spin-contract-binding.md`
- `specs/345_noop_spin_wait_contract_binding_and_single_writer/plans/01_noop-spin-contract-binding.md`
- `agent-system/extensions/core/context/patterns/external-process-wait.md`
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md`
- `agent-system/extensions/core/hooks/detect-noop-bash.sh`
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (deploy-staleness
  contract backing the Phase 5 exclusions)
