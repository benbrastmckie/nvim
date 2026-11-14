# Implementation Summary: Task #602

- **Task**: 602 - Improve the conclusion stage's next-batch proposal quality
- **Status**: [COMPLETED]
- **Started**: 2026-11-12
- **Completed**: 2026-11-12
- **Effort**: ~7 hours
- **Dependencies**: None
- **Artifacts**: plans/01_next-batch-proposal-quality.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The conclusion stage's next-batch suggester (`orchestrate-suggest-next-batch.sh`) previously
could end an orchestration on nothing but file_scope-colliding pair sequences, rendering at most
one option, and never wrote the edges it proposed. This implementation makes a colliding pair
ADDITIVE to a probe-verified joint batch rather than a replacement for one, renders up to three
distinct labelled batch options (one per selection-doctrine criterion), gates an actual
`--write-edges` call behind one explicit approval under a dedicated fail-closed ledger key, and
lands the roadmap-prune ruling with corrected grounds. Every admissibility fact continues to
arrive as a field on an `orchestrate-batch-admit.sh` verdict — no overlap or admission predicate
was copied, forked, or approximated anywhere in this work.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — added an
  invocation-scoped `REPORTED_PAIRS` set (D5) shared across every option in one script
  invocation; replaced the fall-through that dropped the joint batch with a conflict-free-subset
  second pass (`run_candidate_round()`, a shared probe+edge-pass+bucket helper factored out of
  the old inline loop body); refactored `select_candidates()`'s three passes into
  `select_candidates_for_criterion(territory|topic|width, exclude_csv, ready...)`, with
  `select_candidates()` now a thin composition that chains each pass's own exclude set forward
  (byte-identical net selection to before); added `MAX_BATCH_OPTIONS=3` and rewrote
  `mode_next_batch()` to render up to three labelled, probe-verified options, skipping an empty
  criterion's pool and any option whose task set duplicates an earlier one; wired
  `PROBE_CAP_HIT` so the shared `MAX_PROBE_INVOCATIONS` budget's exhaustion is rendered explicitly
  across the whole multi-option render, never silently. Fixed a latent, pre-existing parsing bug
  found while implementing the per-criterion selector (see Decisions below).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — added
  `add_task_topic()` helper and cases (h) (all-pairs pool renders sequences AND a joint batch,
  plus state.json byte-identity), (i) (three distinct labelled options, no duplicate sets), and
  (j) (the shared probe cap, exhausted mid-multi-option-render, is rendered explicitly).
- `agent-system/extensions/core/scripts/orchestrate-conclusion-aggregate.sh` — widened the closed
  `--channel` vocabulary from `a|b|c` to `a|b|c|edges` in both `--record-approval` and
  `--check-approval`; updated the usage header and ledger-shape comment to describe `edges` as an
  independent, non-channel approval key.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-aggregate.sh` — added
  case (g-edges): `edges` cross-key isolation in both directions (yes-for-edges leaves a/b/c
  not-approved; yes-for-a leaves edges not-approved), the same fail-closed posture
  (unrecorded/no/malformed) proven for `edges`, and an invalid `--channel` value still rejected
  with the documented exit status for both modes.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — rewrote Step 7 as a
  gated edge-write step (default invoke → `AskUserQuestion` on ≥1 proposed edge →
  `--record-approval --channel edges` → `--check-approval --channel edges` gate → gated
  `--write-edges` re-invoke, folded into Step 6); stated the zero-proposed-edge skip and the
  declined-approval byte-identity invariant; corrected Step 5's `--prune` exclusion rationale to
  the current fact (`--regenerate` already renders nothing a prune pass could remove; `--prune`
  is a deprecated alias), citing `roadmap-integration.sh`'s own header.
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md` — widened Move
  5's `AskUserQuestion` row to cover Step 7's `edges` gate; added
  `orchestrate-suggest-next-batch.sh` (both forms) and `lint/lint-roadmap-batch-proposals.sh` to
  the `Bash` row; added a Prohibited bullet mirroring channel (a)'s, for the `edges` key.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` —
  rewrote the `**Suggested next batch**:` block for the additive pair/joint-batch render, up to
  three labelled options with their own admission evidence, the cap-reached line, and the
  edge-write approval outcome (`approved — written` / `declined` / `not asked — no proposed
  edges`).
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — added one sentence citing
  `roadmap-integration.sh`'s own `mode_prune()` header as the source of truth for the
  `--prune`/`--regenerate` equivalence (the equivalence itself was already documented there in
  full by an earlier, separate change).
- The deployed `.claude/**` tree was regenerated from the source store via `deploy-headless.sh`
  (a disposable deploy artifact, never hand-authored).

## Decisions

- Factored the probe+edge-pass+bucket body shared by the main shrink-and-retry loop and the new
  second pass into one function (`run_candidate_round()`) rather than duplicating it, so D5's
  reported-pairs dedup logic exists in exactly one place.
- `REPORTED_PAIRS` is a script-level global (not a `suggest_from_candidates()`-local), because
  Phase 2's multi-option loop calls that function once per criterion within one script
  invocation — "a pair is never reported twice in one invocation" (D5) means the whole script
  run, not one option's own call. A separate, per-call `pairs_this_call` set still scopes each
  option's own conflict-free-subset second pass to pairs IT discovered, so one option's second
  pass never pulls in a lower member reported by an unrelated, earlier option.
- Fixed a latent, pre-existing bug discovered while implementing `select_candidates_for_criterion()`:
  `while IFS=$'\t' read -r t topic fs` silently collapsed an empty `topic` field, because bash
  treats tab (like space and newline) as an IFS-whitespace character that merges consecutive
  delimiters — confirmed directly (`IFS=$'\t' read -r a b c <<< $'x\t\tz'` yields `a=x b=z c=`).
  This corrupted `fs_of`/`topic_of` for any task with an empty `topic` (the common case), making
  the new territory criterion return empty and the topic criterion wrongly include unrelated
  tasks. Fixed by switching the jq/read field separator to ASCII 0x1F (never collapsed). This bug
  predates this task (the original, pre-refactor `select_candidates()` used the identical
  pattern) but was invisible there because that function's territory/topic grouping is only a
  truncation-ordering preference, never what detects a collision — the real admission predicate
  (`orchestrate-batch-admit.sh`) is unaffected by it.
- The edge-write approval uses its own `edges` ledger key rather than a fourth channel: Step 7
  derives from `specs/state.json`, not `issues.jsonl`, and the Exactly-One-Channel and
  Hint-Versus-Decision rules don't apply to it — matching how Step 5's roadmap lint and Step 7's
  suggester output were already treated as non-channel, informational content.
- Width criterion is the plain ready pool in ascending order, with no grouping — matching the
  original Pass 3's own comment on why no width-vs-chain nuance applies within a ready-only pool.

## Plan Deviations

- **Task 2.8** (case (j)): used case (g)'s own `MAX_PROBE_INVOCATIONS` sed-override technique
  directly (set to 1) rather than a low `--max-tasks`, to deterministically exhaust the cap
  mid-multi-option render with a 4-task fixture. The asserted acceptance behavior is identical.
- **Task 5.3** (roadmap-update.md sentence): the file already carried a comprehensive
  `--prune`/`--regenerate` equivalence description from an earlier, separate change; added only
  the specific header-citation sentence the task asked for, rather than rewriting already-correct
  surrounding prose.
- **Phase 6** (full-tier verification): discharged against a scoped tier
  (`verify-deploy.sh --skip-slow --only-gate 3,4`; `run-all.sh --only
  test-orchestrate-suggest-next-batch.sh,test-orchestrate-conclusion-aggregate.sh`) per this
  dispatch's own Batch Gate Deferral directive — the complete gate set runs once for the whole
  batch at the end of the invocation instead of independently here.
- **Phase 6** (end-to-end approval proof): exercised against a disposable scratch
  `specs/state.json` via the real deployed scripts, not the live production `specs/state.json`,
  to avoid a genuinely destructive real edge write against this repository's own task graph.

## Verification

- Build: N/A (shell scripts and markdown only)
- Tests: `test-orchestrate-suggest-next-batch.sh` 18/18 passed (including new cases h/i/j);
  `test-orchestrate-conclusion-aggregate.sh` 15/15 passed (including new case g-edges).
  `shellcheck` clean on all four touched shell files (only pre-existing SC1091/SC2329
  informational notices, unrelated to this task's edits).
- Scoped gate: `verify-deploy.sh --skip-slow --only-gate 3,4` — PASS, 3/3 checks, 0 failures.
- Full-tier deploy/gate/suite: discharged against the scoped tier above per the Batch Gate
  Deferral directive (see Plan Deviations). `deploy-headless.sh` was run 9 times across this
  dispatch as ordinary iterative verification; every run reported `RESULT=landed_verify_red` for
  the SAME 3 pre-existing, unrelated findings (gate10 timeout; eager-load total 71949B over its
  70400B baseline; `skills/skill-orchestrate/SKILL.md` 25510B over its 25000B ceiling) — none
  naming a file this task touched, all recorded via `issue-record.sh` and listed in the plan's
  Phase 6 `#### Reasoned Exclusions` table.
- Files verified: Yes — every modified file read back and checked for task-reference
  (`check-task-references.sh`, 0 occurrences on every touched source-store file) and
  record-versioning compliance.
- `specs/state.json`'s `next_project_number` confirmed unchanged (611) across every phase commit.
- Net line count: `git diff --numstat` across all 8 touched files: +788/-186, net **+602 lines**.

## Impacts

- An `/orchestrate` batch whose selected candidates are entirely file_scope-colliding pairs now
  ends with at least one real, probe-verified joint batch suggestion in addition to the ordered
  sequences — not just a list of two-task sequences with nothing else actionable.
- An operator choosing a next batch now sees up to three labelled, independently probe-verified
  options instead of one take-it-or-leave-it suggestion.
- The conclusion stage can now actually write the edges it proposes, behind one explicit
  approval, rather than only handing the operator a command to paste by hand.
- The roadmap-prune exclusion's recorded rationale now matches the tool's current behavior
  (`--prune` is a deprecated alias for `--regenerate`), rather than citing a decommissioned
  concern.

## Follow-ups

- None.

## References

- `specs/602_conclusion_stage_next_batch_proposal_quality/plans/01_next-batch-proposal-quality.md`
- `specs/602_conclusion_stage_next_batch_proposal_quality/reports/01_conclusion-stage-next-batch-proposal-quality.md`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
