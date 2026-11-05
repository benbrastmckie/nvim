# Implementation Summary: Task #405

- **Task**: 405 - Detect a stranded dispatch from its own stale heartbeat instead of only after a recorded failure
- **Status**: [COMPLETED]
- **Started**: 2026-10-15T00:00:00Z
- **Completed**: 2026-10-15T06:15:00Z
- **Effort**: ~6 hours (plan estimate: 11.5 hours)
- **Dependencies**: None
- **Artifacts**: plans/01_stranded-dispatch-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Built the missing monitoring-context consumer of `task-lock.sh check`'s `held-live` state: a new
read-only probe (`dispatch-strand-probe.sh`) that combines the heartbeat signal the system
already writes with artifact- and commit-quiescence terms, wired into the three readers that can
act on it (postflight's new `stranded_suspected` field, the lead's existing one-re-prompt relay,
and `reconcile-task-status.sh`'s demotion gate). The prevention half extends
`lint-agent-contracts.sh` with Check K, which mechanically rejects the detach-then-await-a-
notification antipattern in agent contracts. All 8 plan phases closed (7 `[COMPLETED]`, Phase 8
`[COMPLETED WITH EXCLUSIONS]` for one reasoned, evidenced deferral).

## What Changed

- `agent-system/extensions/core/scripts/dispatch-strand-probe.sh` — new. Classifies a task's
  dispatch as `live`/`stranded`/`unknown` from `task-lock.sh check`'s output text prefix plus
  artifact- and commit-quiescence probes over the task directory. Fails closed; never mutates.
- `agent-system/extensions/core/scripts/tests/test-dispatch-strand-probe.sh` — new, 5 cases
  (stranded, healthy-but-slow false-positive regression, held-fresh, unknown/fail-closed,
  no-side-effects).
- `agent-system/extensions/core/context/patterns/task-lock.md` — new "`held-live` Interpretation
  Is Context-Dependent, Not Universal" subsection: both readings side by side, the weak-evidence
  caveat, the measured conjunction, the two rejected signals, the named
  `orchestrate-cycle-plan.sh` gap, and the honest coverage boundary.
- `specs/ROADMAP.md` — corrected one unfiled observation's prescribed remedy (a direct re-prompt
  message is unreachable; the sequence that actually works is stop/postflight/fresh-dispatch).
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — early probe capture
  before WORK (j)'s lock release; new advisory `stranded_suspected` field (phase-agnostic, not
  commit-gated, deliberately separate from `stall_suspected`), emitted in both output arms.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — 4 new
  producer cases (T0–T3: field present/false, stranded fixture, healthy-but-slow fixture, both
  emission arms).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 3 extracts
  `stranded_suspected`, ORs it with `stall_suspected` into the re-prompt predicate, and records
  which detector fired via a `signal` field on the ledger entry; the existing relay is reused
  unchanged.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — "The Strand
  Variant: `stranded_suspected`" subsection under Abandoned Wrap-Up; the liveness-probe section
  now names `dispatch-strand-probe.sh` as the mechanical form of its own guidance; `mt_state_file`
  field reference updated for the dual-origin ledger entries and the new `signal` field.
- `agent-system/extensions/core/scripts/tests/test-stall-reprompt-wiring.sh` — producer/consumer/
  predicate/documentation assertions for the new field, plus a mechanical end-to-end routing
  proof that re-extracts the lead's own jq program at run time and proves the no-failure-charge
  property across both a first-occurrence and a second-occurrence pass.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — `demote_stranded_status()`
  now splits its exit-1 arm on the output line's text prefix: `held-fresh` keeps its refusal
  message byte-for-byte; `held-live` consults the probe and demotes only on a `stranded` verdict.
- `agent-system/extensions/core/scripts/tests/test-reconcile-demote-stranded.sh` — new, 7 cases.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — new "Forbidden-Shape
  Lint Anchor" subsection carrying Check K's four anchor values.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new Check K
  (detach-then-await-a-notification antipattern absence), with the two Lean contracts as curated
  exclusions.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-await-notification.sh` —
  new, 4 cases (clean/violating/excluded/prohibitively-quoting).
- `agent-system/extensions/core/manifest.json`, `index-entries.json` — new scripts declared;
  line-count drift for the two edited patterns files regenerated.
- A redeployed `.claude/` tree carrying all of the above.

## Decisions

- Followed the plan's own settled Decisions verbatim (new standalone script rather than a
  `task-lock.sh` subcommand; `strand`/`stranded_suspected` lexically distinct from
  `stall`/`stall_suspected`; three-term conjunction excluding a process-descendant walk and
  system load; fail-closed on ambiguity; early probe capture before lock release).
- Ledger entries carry a new `signal` field (`"stall"`, `"strand"`, or `"stall+strand"`) so a
  reader can always tell which detector populated a given `pending_stall_reprompt[]`/
  `stall_ledger[]` entry — not specified verbatim in the plan's task list but required by its
  own "keep the two signals distinguishable" instruction.

## Plan Deviations

- **Phase 3's verification command** named `TARGET_REPO` as
  `agent-system/extensions/core` for its `verify-deploy.sh --skip-slow --only-gate 3,4` call;
  that argument expects a repo root carrying a deployed `.claude/` tree, which the extension
  subdirectory does not have. Ran the same command against the real repo root instead and
  confirmed the resulting findings were the expected pre-redeploy drift and a known pre-existing
  self-match, not caused by this phase's edits.
- **Phase 8** closed `[COMPLETED WITH EXCLUSIONS]`: the once-per-invocation complete
  `verify-deploy.sh` gate set (no `--skip-slow`, no `--only-gate`) was deferred to the shared
  batch stage per this dispatch's own Batch Gate Deferral directive, rather than independently
  run here. See that phase's own `#### Reasoned Exclusions` record for the full evidence.
- **Phase 8** found and fixed two regressions this task's own edits introduced, neither named in
  the plan's own task list: (1) adding Check K after Check J in `lint-agent-contracts.sh` broke
  `test-lint-agent-contracts-handoff-section.sh`'s own Check-J section-scoping sed boundary
  (fixed by widening the boundary to stop at the next `--- Check ` header, not only the final
  summary divider); (2) the Move 3 additions pushed `skills/skill-orchestrate/SKILL.md` over its
  configured 24000 B per-file eager-load ceiling (25119 B measured) — fixed by trimming the added
  prose to 23997 B, pointing to `orchestrate-state-machine.md` for the full rationale instead of
  repeating it inline.

## Verification

- Build: N/A (no compiled artifact)
- Tests: Passed — every new/extended suite green individually
  (`test-dispatch-strand-probe.sh`, `test-lint-agent-contracts-await-notification.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-stall-reprompt-wiring.sh`,
  `test-reconcile-demote-stranded.sh`, `test-reconcile-handoff-status.sh`,
  `test-lint-agent-contracts.sh`, `test-lint-agent-contracts-handoff-section.sh`,
  `test-lint-shellcheck.sh`); the full internal `run-all.sh` (147 suites) run twice shows only
  the pre-existing baseline failures (`test-detect-noop-bash.sh`, `test-guard-git-push.sh`,
  `test-four-tier-conflict.sh`, `test-verify-deploy-context-budget.sh`'s Gate 20 baseline drift)
  after the two regressions above were fixed.
- Files verified: Yes — manifest declaration confirmed via `sync-manifest-scripts.sh`/
  `check-extension-docs.sh` (no undeclared-script finding); plan artifact validates
  (`validate-artifact.sh`); task-reference and record-versioning sweeps report 0 BLOCKING across
  all 14 touched `agent-system/**` files; redeploy landed and gates 3/4/20/22 checked directly
  against the deployed tree (clean except the two pre-existing gate-3/4 findings).

## Impacts

- A stranded dispatch (live holder pid, stale heartbeat, no artifact or commit movement) is now
  detected and routed to a foreground re-prompt BEFORE any failure is charged, for every phase —
  including a research dispatch with zero commits, the shape the prior commit-gated
  `stall_suspected` signal could never see.
- `reconcile-task-status.sh`'s demotion gate no longer treats a stranded `held-live` lock as
  healthy; it now demotes exactly the cases the probe confirms stranded, while still refusing on
  a genuinely fresh lock or an unresolvable probe.
- A new lint check mechanically rejects any future agent contract that pairs a backgrounding
  instruction with an explicit wait-for-a-completion-notification instruction, with the two
  already-owned Lean exceptions carried as curated, reproducible exclusions.

## Follow-ups

- `orchestrate-cycle-plan.sh`'s lock PROBE still groups a same-session `held-live` result with
  `held-fresh`, sharing this defect's blind spot in the admission-time context. Left untouched
  per the plan's own Non-Goals (it was another concurrently-dispatched task's declared territory
  at authoring time); named as an open follow-up in `task-lock.md`'s new subsection.
- The honest coverage boundary recorded in `task-lock.md`: a dispatch that strands and returns
  promptly with a still-fresh heartbeat is not covered by this detector; that shape remains
  `report_missing`'s and the D4 message-findings recovery's ground.
- Two confirmed pre-existing issues surfaced during verification and are unrelated to this task:
  `check-extension-docs.sh` Rule S flags `context/project/lean4/patterns/measurement-harness-strictness.md`
  (no `index.json` entry); `test-verify-deploy-context-budget.sh`'s Gate 20 eager-load total sits
  988 B over its recorded baseline.

## References

- `specs/405_detect_stranded_dispatch_from_stale_heartbeat/plans/01_stranded-dispatch-detection.md`
- `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_detect-stranded-dispatch.md`
- `specs/405_detect_stranded_dispatch_from_stale_heartbeat/reports/01_discriminator-and-failed-remedy.md`
