# Implementation Summary: Task #274

- **Task**: 274 - Next-admissible-batch suggestion and alternatives-on-conflict, both computed by
  invoking the real admission script
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T16:16:00Z
- **Completed**: 2026-11-04T18:15:00Z
- **Effort**: ~2 hours
- **Dependencies**: 165, 272, 273, 275, 344 (all completed)
- **Artifacts**: plans/01_next-admissible-batch-suggester.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, shell-strict-mode.md

## Overview

Built `orchestrate-suggest-next-batch.sh`, a new standalone script with two CLI modes
(`--next-batch` for end-of-orchestration suggestion, `--alternatives` for refusal-time
alternatives) that both establish admissibility exclusively by invoking the real
`orchestrate-batch-admit.sh` predicate and reading its v6 verdicts — no collision logic is
reimplemented anywhere. A caller-side edge-proposing step converts a `file_scope`-colliding
pair into a proposed, ordered `dependencies[]` sequence instead of silently dropping it. Both
trigger points are now wired (the conclusion stage's new Step 7, and `commands/orchestrate.md`'s
blocking `queue-check` failure branch), and the new consumer is documented across the
admission-schema consumer list and the orchestrator-critical-paths exclusion table.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — New file. Two-mode
  CLI (`--next-batch`/`--alternatives`, plus `--session-id`, `--max-tasks`, `--write-edges`,
  `--help`); the shared `probe_candidate_set()` admission-probe function (bounded by
  `MAX_PROBE_INVOCATIONS=20`); the readiness predicate (`build_ready_pool()`); phase-map
  derivation via `orchestrate-triage-classify.sh`; the selection doctrine (territory > topic >
  ascending-rest, per `batch-orchestration-guardrails.md`); the edge-proposing step
  (`resolve_noop_token()`, `propose_edge_for_pair()`); the shared selection+probe+render engine
  (`suggest_from_pool()`) used by both `mode_next_batch()` and `mode_alternatives()` (the latter
  reading `task-lock.sh queue-list` and excluding live-queue-covered tasks).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — New
  file. Scratch-tree regression suite with seven fixtures (a)-(g): happy-path wholesale
  admission; the edge-proposing acceptance case (pre-edge no joint pair, post-`--write-edges`
  both admit on a real re-probe); Mode B's live-queue exclusion; the absent-`file_scope`
  blocking-in-batch posture; `--max-tasks` truncation precedence for a territory-mandatory
  group; the no-forked-predicate regression (grep-provable, plus a check that the real schema
  doc's own Complete JSON Schema section is untouched); and the probe-invocation cap.
- `agent-system/extensions/core/manifest.json` — Registered the new script and test suite.
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — Added a measured
  (~2500 ms) cost-hint line.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Added Step 7 ("Suggest
  next batch") to the executable stage body, positioned between Step 5 and Step 6 since its
  output feeds Step 6's render; explicitly informational, not a fourth approval channel.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — Added
  the `**Suggested next batch**:` render line to the `### Conclusion` block.
- `agent-system/extensions/core/commands/orchestrate.md` — The blocking `queue-check` failure
  branch now invokes `orchestrate-suggest-next-batch.sh --alternatives` (failure-tolerant)
  before `exit 1`; the refusal's own exit code is never masked.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — One-line Move 5 pointer to
  Step 7 (no second copy of the step body).
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — One new "Read by"
  consumer-list entry naming the new script; schema/field-definition/version-history sections
  untouched.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — One new
  Exclusion Table row covering both Move 5 scripts (`orchestrate-conclusion-aggregate.sh` and
  `orchestrate-suggest-next-batch.sh`) together, closing a pre-existing documentation gap for
  the former alongside the latter.
- `agent-system/extensions/core/index-entries.json` — Line-count bookkeeping repair for the
  three markdown files Phase 5 edited (separate, non-task-274-scoped housekeeping commit, since
  this file is outside task 274's declared `file_scope`).

## Decisions

- Edge direction (Decision 1): the lower `project_number` is always rendered as the
  predecessor — a deterministic rendering choice, never an inferred truth about which task
  logically precedes the other.
- Propose-by-default, write only on `--write-edges` (Decision 2): the edge-proposing step never
  mutates `specs/state.json` unasked; `--write-edges` performs the write and re-probes the real
  admission script to show both members flip to `admit`.
- Discovered and handled a genuine tooling gap: `update-task-status.sh`'s `map_status()` has no
  `operation:target_status` combination resolving to state.json status `"not_started"`, so
  `--depends-on-add` cannot be issued as a no-op call against a task still in that status.
  `resolve_noop_token()` detects this and falls back to a loud propose-only rendering.
  Confirmed live against the real `specs/state.json`: tasks 385 and 464 genuinely collide on
  `file_scope`, and 464 is `not_started`, exercising this exact branch end to end.
- Mode B's "render each surviving alternative" requirement is satisfied by one shared
  selection+probe+edge-proposing engine (`suggest_from_pool()`) reused by both modes, rendering
  every sequence block and the final joint batch line it discovers in one bounded pass, rather
  than a repeated multi-batch search over a shrinking pool.
- Within a ready-only candidate pool, no two ready tasks can ever be connected by a
  `dependencies[]` edge to each other (a predecessor would have to be `status=completed`,
  which is terminal and therefore excluded from readiness) — this proves the selection
  doctrine's width-vs-chain-extension nuance is vacuous for a ready-pool-only selection.

## Plan Deviations

- Task 2.4 (selection doctrine): width-vs-chain-extension ordering proven vacuous within a
  ready-only pool; documented inline in `select_candidates()`'s header comment.
- Task 3.4 (Mode B "render each surviving alternative"): implemented as one shared shrink-engine
  pass (`suggest_from_pool()`), not a repeated multi-batch search.
- Phase 5's own verification used this dispatch's Batch Gate Deferral scoped tier
  (`verify-deploy.sh --only-gate 3,4,6,7,11,19,22`) rather than the plan's declared full,
  no-narrowing gate set — the full gate set is deferred to the batch-level stage, not skipped.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — `test-orchestrate-suggest-next-batch.sh` (11/11 assertions across fixtures
  a-g), `test-update-task-status.sh`, `test-manifest-scripts-sync.sh`, `test-script-inventory.sh`
- Files verified: Yes (both new files created, `chmod +x`, shellcheck clean)
- Gates run this dispatch (scoped per Batch Gate Deferral): 3 (doc-lint, after an
  `index-entries.json` repair), 4 (task-reference lint), 6 (agent-contracts lint), 7
  (routing-wiring lint), 11 (contract-compliance lint), 19 (branch-gated-sections lint), 22
  (shellcheck) — all PASS. One expected, pending-deploy-only gate-3 advisory remains
  (`suite-cost-hints.txt` not yet redeployed to `.claude/`) — not a defect; resolves at the
  batch-level redeploy checkpoint.
- Live-verified Mode A and Mode B against the real `specs/state.json` via a temporary,
  gitignored `.claude/scripts/` copy (removed after each test): both leave `specs/state.json`
  byte-identical before/after in their default form; a real, previously-unknown `file_scope`
  collision between tasks 385 and 464 was discovered and correctly rendered as an ordered
  sequence.

## Impacts

- `/orchestrate` now suggests a concretely admissible next batch at the end of every
  orchestration, and alternatives when a batch is refused for conflicting with an in-flight
  one — both grounded in the real admission predicate, never a re-derived approximation.
- A `file_scope`-colliding pair of otherwise-suggestible tasks is no longer silently withheld
  from every future suggestion; the suggester proposes the serializing edge that would make the
  pair admissible as an ordered sequence.

## Follow-ups

- None required for this task's acceptance criteria. Noted (not actioned) during
  implementation: `update-task-status.sh` cannot issue a no-op `--depends-on-add` call against
  a task currently in `not_started` status (no resolving `operation:target_status` token in
  `map_status()`); the edge-proposing step handles this gracefully today (loud propose-only
  fallback), but closing the underlying gap in `update-task-status.sh` itself is a candidate
  for a future, separate task.

## References

- Plan: `specs/274_next_admissible_batch_suggestion/plans/01_next-admissible-batch-suggester.md`
- Research: `specs/274_next_admissible_batch_suggestion/reports/01_next-admissible-batch-suggestion.md`
- Issue log: `specs/274_next_admissible_batch_suggestion/issues.jsonl`
