# Implementation Plan: Task #591

- **Task**: 591 - Decide the fate of the errors.json triage surface
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: 572, 585
- **Research Inputs**: None (planned directly from the task description plus direct source-store reads; see Decision Record below for the evidence gathered)
- **Artifacts**: plans/01_retire-errors-triage-surface.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `specs/errors.json` / `scripts/errors-append.sh` / `/errors` triage surface is retired
outright. The write half of the surface has no production caller, the store is stale, and every
capability it still nominally offers is either already provided by `issues.jsonl` plus the
orchestration conclusion stage or is deliberately not provided anywhere by design. The work
removes the command, the writer script, its test suite, its schema and format contracts, its
manifest and context-index registrations, its `verify-deploy.sh` presence check and gate-registry
corpus row, its membership in the engine-written-state staging allowlist and the eager-context
volatile deny-list, and every prose reference across the source store — then redeploys so no
half-retired residue survives in the deployed tree.

### Decision Record

**(1) Does `/errors` retain a capability the live stores do not provide?** No.

Checked rather than assumed, against the actual implementations:

- **Capture**: `errors-append.sh append` has zero production call sites. Every remaining mention
  is a comment, a test fixture, a scratch-tree stub list, or `verify-deploy.sh`'s own
  manifest-presence check. The only non-`append` caller is `commands/errors.md` itself, calling
  `update`. A store whose sole writer is its own reader is not a live surface.
- **Cross-task grouping and recurrence tally**: provided. `scripts/orchestrate-conclusion-aggregate.sh --aggregate`
  reads every touched task's `issues.jsonl`, groups `open`/`worked_around` entries by `class`
  **across tasks**, separates `kind: "win"` entries, and tallies classes outside the seed enum.
  `/errors` Step 2 computes recurrence the same way (grouping on `type` at analysis time; the
  schema stores no recurrence field).
- **Severity and classification vocabulary**: provided, and richer. `issues.jsonl` carries a
  closed four-rung severity scale with explicit admission tests, an open 16-class taxonomy, a
  `resolution` field, a `suggested_channel` hint, and an `estimated_cost` `{value, unit}` pair.
  `errors.json` carries an open `type` string and a four-value severity with no admission tests.
- **Cross-repo durability**: provided, and `errors.json` never had it.
  `scripts/lib/central-log-lib.sh`'s `central_log_promote` appends to the owning repository's
  `specs/central-errors.jsonl` with bounded single-generation rotation.
- **Three-channel promotion**: provided. The conclusion stage's channels (a) fix-now,
  (b) agent-system change, (c) follow-up task, each behind its own fail-closed approval key.

Two things `/errors` has that nothing else does, both examined and both rejected as reasons to
keep it:

- **A mutable `fix_status` living record (`unfixed` -> `in_progress` -> `fixed`) with a
  `fix_task` cross-link.** `issues.jsonl` is append-only-by-line and fixes its `resolution` at
  write time. This is a genuine schema difference — but it has never been exercised: the
  `update` path is reachable only through `/errors --fix`, and the audit in Phase 1 tests
  whether it was ever used. A lifecycle field nothing advances is not a capability.
- **Automatic fix-task creation.** The conclusion stage records channel (b)/(c) proposals as
  evidence for a later deliberate consumer and explicitly never creates task directories. That is
  a stated design decision in `context/contracts/conclusion-stage.md`, not a gap `/errors` fills;
  re-introducing autonomous task creation through a side door would contradict it.

**(2) The 19 existing records.** Discarded, with a per-record disposition audit written to a
durable task artifact and the file's content preserved in git history (it is a tracked file).
The audit is Phase 1's deliverable rather than an assumption: the record titles correspond
closely to archived task directories under `specs/archive/` (for example a
`defect_vocabulary_gap` record against `011_expand_defect_class_vocabulary`, a
`test_suite_deployed_mode_failures` record against `012_fix_test_suite_deployed_mode_failures`,
an `acceptance_criterion_not_instrumented` record against
`013_instrument_gate_out_auto_repair_reporting`, a `deploy_orphan_files_undercounted` record
against `009_resolve_deploy_orphan_file_parity`), which is consistent with the substantive
findings having already been discharged into tasks while `fix_status` stayed stale because
nothing ever ran `/errors --fix`. Phase 1 confirms that correspondence record by record and
surfaces any genuinely undischarged finding in the audit artifact as a follow-up candidate — it
does not create tasks.

**(3) Retirement scope.** The command, the script, the manifest entry, the `verify-deploy.sh`
presence check, and the test fixtures are removed together, plus four surfaces the task
description does not enumerate but which would otherwise be exactly the misleading residue it
warns against: the context-index registrations, the gate-registry corpus row, the
engine-written-state staging allowlist membership, and the eager-context volatile deny-list entry.

### Research Integration

No research report was produced for this round. The description already carried the defect, the
mechanical verification, and the acceptance bar; the two open judgment calls — the capability
comparison and the records' fate — were settled by reading
`scripts/orchestrate-conclusion-aggregate.sh`, `context/formats/issue-log.md`,
`context/contracts/conclusion-stage.md`, `scripts/lib/central-log-lib.sh`, and the 19 records
themselves within this planning dispatch, as recorded above.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied with this dispatch; no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Settle the retention question on evidence and record the verdict durably.
- Give the 19 records a recorded disposition, not a silent deletion.
- Remove every live and documentary trace of the surface in one pass, leaving nothing a future
  reader can mistake for a live store.
- Leave the deployed tree free of orphaned copies of the removed files.

**Non-Goals**:
- Creating follow-up tasks for any undischarged finding the Phase 1 audit surfaces — the audit
  names them; task creation is a separate, deliberate act.
- Changing `issues.jsonl`, `events.jsonl`, `central-errors.jsonl`, or the conclusion stage in any
  way. This work removes a surface; it does not extend the ones that remain.
- Touching `agent-system/extensions/core/.claude-extensions.json`. That stray duplicate is an
  open record of its own; this work leaves it exactly as it is even though it names the removed
  paths.
- Moving `context/config/orchestrator-context-budget.json`'s `baseline_bytes` or editing its
  `note` field. This work only lowers the eager byte count, which the gate permits.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Territory collision on `scripts/verify-deploy.sh` with the open hook-registration-set lint record | M | M | Phase 3 isolates every `verify-deploy.sh` edit to gate 1's corpus loop and its header comment; check `git status` for a concurrent writer before starting the phase and serialize rather than racing |
| Territory collision on `manifest.json` with several open records | M | M | Phase 2's manifest edit is three row deletions in three distinct arrays; re-read the file immediately before editing rather than working from this plan's quoted line numbers |
| Deployed orphans after removal (gate 13 `find_orphans` fails on deployed-but-undeclared files) | H | H | Phase 8 redeploys with `--wipe`, which rebuilds `.claude/` from scratch rather than overlaying; a plain deploy would leave the removed files behind and fail gate 13 |
| An intermediate phase leaves a gate red (gate 1 after Phase 2 but before Phase 3; `lint-dead-command-recommendations.sh` after Phase 2 but before Phase 6) | M | H | Phase tiers are scoped so no intermediate phase runs a gate it cannot yet pass; the complete gate set runs once, in Phase 8, after every phase has landed |
| A record in `specs/errors.json` turns out to be genuinely undischarged | M | L | Phase 1's audit is per-record and its artifact names any such record explicitly; the content survives in git history regardless |
| The prose sweep misses a reference, leaving a dangling pointer to a deleted file | M | M | Phases 5-7 each re-run the same discovery grep as their own verification criterion; Phase 8 re-runs it repo-wide over the source store |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5, 6, 7 | 2 |
| 4 | 8 | 3, 4, 5, 6, 7 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Audit the 19 records and discard the store [COMPLETED]

**Goal**: Give every record in `specs/errors.json` a recorded disposition, then delete the file.

This phase runs before the allowlist change in Phase 4 deliberately: `specs/errors.json` is
currently a member of the engine-written-state staging allowlist, so the deletion commits
cleanly without a file-scope excursion. Reversing the order would force the deletion through a
scope exception for no benefit.

**Tasks**:
- [x] Dump all records with `jq -r '.errors[] | "\(.id)\t\(.timestamp)\t\(.type)\t\(.severity)\t\(.fix_status)\t\(.message)"' specs/errors.json`. *(completed: 19 records confirmed)*
- [x] For each record, search `specs/archive/` and `specs/state.json` for a task whose name or
      description covers the same finding. Record the match (archived directory name) or the
      absence of one. *(completed: 17 of 19 matched to a discharging task via fix_task field, title/scope match, or git log; 2 have no specific discharging task)*
- [x] Check whether any record's `fix_status` is `in_progress`, or whether any record carries a
      `fix_task` value — direct evidence of whether `/errors --fix` was ever run. Record the
      answer; it is the empirical half of the "mutable lifecycle field" argument in the Decision
      Record above. *(completed: zero records at in_progress across full git history; 9 records carry a fix_task value but none show evidence of errors-append.sh update/`/errors --fix` ever being run — all 9 were closed by direct edits to specs/errors.json from within the discharging task)*
- [x] Write `specs/591_retire_errors_json_triage_surface/reports/01_errors-record-disposition.md`:
      the retirement verdict, the capability comparison in condensed form, a table with one row
      per record (`id`, `type`, `fix_status`, discharging archived task or `none found`), and an
      explicit list of any record with no discharging task, labelled as follow-up candidates that
      this task deliberately does not turn into tasks. *(completed)*
- [x] `git rm specs/errors.json`. *(completed)*
- [x] Confirm the deleted blob is reachable in history: `git log --oneline -1 -- specs/errors.json`. *(completed: commit 464df494c)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: No deployed suite or gate reads `specs/errors.json`; the covering checks
are a `jq` pass over the disposition table confirming all 19 record ids appear, plus
`git log -- specs/errors.json` confirming the content survives deletion.

**Scope Hypothesis**: `specs/errors.json` holds exactly 19 records, 10 of them `fix_status:
unfixed`, with the newest timestamp in early September. Confirm by re-running the `jq` dump at
implementation time rather than trusting these counts; if the file has grown or changed, audit
what is actually there and say so in the artifact.

**Files to modify**:
- `specs/errors.json` - deleted
- `specs/591_retire_errors_json_triage_surface/reports/01_errors-record-disposition.md` - new disposition audit

**Verification**:
- The disposition artifact exists and contains one table row per record id present in the dump.
- `git log --oneline -1 -- specs/errors.json` names a commit, so the content is recoverable.
- `[ ! -e specs/errors.json ]`.

---

### Phase 2: Delete the surface files and deregister them [COMPLETED]

**Goal**: Remove the command, the writer, its test suite, and its two contract documents, and
drop every registration that still names them.

**Tasks**:
- [x] Delete `agent-system/extensions/core/commands/errors.md`,
      `agent-system/extensions/core/scripts/errors-append.sh`,
      `agent-system/extensions/core/scripts/tests/test-errors-append.sh`,
      `agent-system/extensions/core/context/formats/errors-format.md`,
      `agent-system/extensions/core/context/schemas/errors-schema.json`. *(completed)*
- [x] In `agent-system/extensions/core/manifest.json`, remove the `errors.md`,
      `errors-append.sh`, and `tests/test-errors-append.sh` rows, plus any row naming
      `formats/errors-format.md` or `schemas/errors-schema.json`. Re-read the file and locate
      each row by content; do not work from remembered line numbers. *(completed: three rows removed; no formats/errors-format.md or schemas/errors-schema.json rows existed in manifest.json)*
- [x] In `agent-system/extensions/core/index-entries.json`, delete the two entries whose `path`
      is `formats/errors-format.md` and `schemas/errors-schema.json`, and remove the `"/errors"`
      string from the `load_when.commands` array of every remaining entry that carries it. *(completed: 2 entries deleted, 8 remaining entries narrowed; plus one unlisted keyword/summary match on standards/error-recovery-strategies.md corrected — see deviation note)*
- [x] In `agent-system/extensions/core/scripts/tests/suite-classification.data`, remove the
      `test-errors-append.sh` row. *(completed)*
- [x] In `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`, remove the
      `test-errors-append.sh` row. *(completed)*
- [x] Validate both edited JSON files parse (`jq empty`). *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `jq empty` over the two edited JSON files plus
`bash .claude/scripts/validate-index.sh` (its missing-file check is exactly what a stale index
entry would trip) are the covering checks; gate 1 and `lint-dead-command-recommendations.sh`
cannot pass until Phases 3 and 6 land and are deferred to the final phase.

**Scope Hypothesis**: five files to delete; three manifest rows; two index entries to delete and
eight further index entries whose `commands[]` names `/errors`. Confirm the index figure at
implementation time with
`jq -r '.. | objects | select(has("path")) | select((..|strings)|test("^/errors$")) | .path' agent-system/extensions/core/index-entries.json`
and act on whatever that returns, not on the number stated here.

**Files to modify**:
- `agent-system/extensions/core/commands/errors.md` - deleted
- `agent-system/extensions/core/scripts/errors-append.sh` - deleted
- `agent-system/extensions/core/scripts/tests/test-errors-append.sh` - deleted
- `agent-system/extensions/core/context/formats/errors-format.md` - deleted
- `agent-system/extensions/core/context/schemas/errors-schema.json` - deleted
- `agent-system/extensions/core/manifest.json` - drop the three provides rows
- `agent-system/extensions/core/index-entries.json` - delete two entries, narrow eight `commands[]` arrays
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - drop the suite row
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - drop the cost-hint row

**Verification**:
- `jq empty agent-system/extensions/core/manifest.json` and `jq empty agent-system/extensions/core/index-entries.json` both exit 0.
- `grep -rn "errors-append\|errors-format\|errors-schema" agent-system/extensions/core/manifest.json agent-system/extensions/core/index-entries.json` returns nothing.
- None of the five deleted paths exists.

---

### Phase 3: Narrow the deploy gate and its registry corpus [COMPLETED]

**Goal**: Stop `verify-deploy.sh` gate 1 from asserting the presence of three files that no
longer exist, and bring the gate registry's declared input corpus and the baseline-cache test's
scratch corpus back in line with it.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/verify-deploy.sh`, remove
      `scripts/errors-append.sh`, `context/schemas/errors-schema.json`, and
      `context/formats/errors-format.md` from `gate1_run`'s `for rel in ...` list, leaving the six
      events-store paths. *(completed)*
- [x] Update gate 1's own `say "1. ..."` line and the block comment above `gate1_run` so they
      describe one store family (the events stack) rather than two. The comment currently
      narrates an "error-tracking stack"; that sentence goes. *(completed)*
- [x] In `agent-system/extensions/core/scripts/gate-registry.data`, edit gate 1's row: drop the
      three `.claude/...` entries from the `input_corpus` field and update the `name` field to
      match the new `say` line. Preserve the TAB separation and the nine-field shape exactly. *(completed)*
- [x] Run `bash .claude/scripts/lint/lint-gate-registry.sh` to confirm the row still parses and
      the id range stays contiguous. *(completed: 7 passed, 0 failed)*
- [x] In `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh`, drop the same
      three paths from the scratch `.claude/` corpus loop, remove the now-unneeded
      `context/schemas` / `context/formats` `mkdir -p` components if nothing else uses them, and
      correct the comment that calls gate 1's corpus "nine literal paths". *(completed: the context/schemas and context/formats mkdir -p components are still needed for events-schema.json/events-format.md, so left in place; corpus description corrected to "six literal paths")*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: interface

**Tier Justification**: `bash .claude/scripts/lint/lint-gate-registry.sh` plus the suite set the
repository's own selector resolves for these three touched paths — `suite_selection_select` from
`.claude/scripts/lib/suite-selection-lib.sh`, whose resolved basename list is then passed to
`run-all.sh --only` — cover every consumer of the gate-1 row and corpus.

**Scope Hypothesis**: exactly three paths leave gate 1's loop, one registry row changes, and one
test suite's scratch corpus shrinks from nine paths to six. Confirm with
`grep -n "errors" agent-system/extensions/core/scripts/gate-registry.data` returning nothing
after the edit.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - narrow gate 1's corpus loop, `say` line, and header comment
- `agent-system/extensions/core/scripts/gate-registry.data` - narrow gate 1's `input_corpus` and `name` fields
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - narrow the scratch corpus and correct its comment

**Verification**:
- `bash -n agent-system/extensions/core/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/lint/lint-gate-registry.sh` exits 0.
- The selector-resolved suite run exits 0:
  ```bash
  . .claude/scripts/lib/suite-selection-lib.sh
  mapfile -t s < <(suite_selection_select \
    agent-system/extensions/core/scripts/verify-deploy.sh \
    agent-system/extensions/core/scripts/gate-registry.data \
    agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh)
  bash .claude/scripts/tests/run-all.sh --only "$(IFS=,; echo "${s[*]}")"
  ```
- `grep -c "errors" agent-system/extensions/core/scripts/gate-registry.data` is 0.

---

### Phase 4: Retire `specs/errors.json` from the runtime allowlists [COMPLETED]

**Goal**: Remove the deleted store from the three live code paths that still name it — the
engine-written-state staging allowlist, the eager-context volatile deny-list, and the
artifact-logging hook — plus the postflight cross-link that reads it, and realign the three
suites that assert the allowlist's membership.

A staging allowlist that admits a file which no longer exists is exactly the half-retired residue
this task exists to prevent, so this is in scope rather than left as harmless.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh`, change the
      printed literal from the four-element array to
      `["specs/TODO.md","specs/state.json","specs/events.jsonl"]`, and update both header
      occurrences of the four-element list. Leave the fail-open two-literal fallback contract
      wording untouched — it is unchanged by this edit. *(completed)*
- [x] In `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh`,
      rewrite case (c) so it asserts `specs/events.jsonl` is present and `specs/errors.json` is
      absent from the member set. *(completed: also corrected case (b)'s length-4 assertion to 3 and case (d)'s "justified four" wording to "three", both necessary consequences of the same edit)*
- [x] In `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`, rewrite case Z16
      so it asserts the inverse: an undeclared `specs/errors.json` is now dropped as out-of-scope
      rather than admitted. Update the comment above it that names both files. *(completed)*
- [x] In `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`, rewrite case 13
      the same way, keeping the `specs/events.jsonl` half of the assertion intact. *(completed)*
- [x] In `agent-system/extensions/core/scripts/measure-eager-context.sh`, remove
      `"specs/errors.json"` from `VOLATILE_PATHS`. *(completed)*
- [x] In `agent-system/extensions/core/hooks/events-log-artifact.sh`, remove the
      `specs/errors.json|*/specs/errors.json)` case branch, its `--message "Error entry logged to
      specs/errors.json"` arm, and the header sentence that names the store. *(completed)*
- [x] In `agent-system/extensions/core/scripts/orchestrator-postflight.sh`, remove the
      `specs/errors.json` read that derives `error_ref` and the header paragraph describing it,
      keeping the surrounding `events-append.sh` call and its never-fatal posture intact. *(completed)*
- [x] In `agent-system/extensions/core/scripts/events-append.sh`, reword the `--error-ref` help
      line so it no longer names `errors.json`. Keep the flag itself — it is part of the events
      schema and is not being removed. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: the suite set the repository's own selector resolves for this phase's
touched paths — `suite_selection_select` from `.claude/scripts/lib/suite-selection-lib.sh`, whose
resolved basename list is passed to `run-all.sh --only` — covers every declared consumer of the
changed literal and of the edited hook and postflight paths.

**Scope Hypothesis**: the allowlist literal has exactly one other consumer surface — the three
scripts named in the library header (`git-commit-scoped.sh`, `orchestrate-cycle-postflight.sh`,
`git-commit-phase.sh`), none of which hand-copies the list and so none of which needs editing.
Confirm with `grep -rn 'specs/events.jsonl","specs/errors.json' agent-system/` returning only
the library before the edit and nothing after it. If a consumer turns out to hand-copy the
literal, fix it in this phase rather than deferring.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` - drop the fourth literal and its header mentions
- `agent-system/extensions/core/scripts/tests/test-engine-written-state-paths-lib.sh` - invert case (c)'s errors.json assertion
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` - invert case Z16
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` - invert case 13's errors.json half
- `agent-system/extensions/core/scripts/measure-eager-context.sh` - drop the volatile-path entry
- `agent-system/extensions/core/hooks/events-log-artifact.sh` - drop the errors.json case branch and header sentence
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - drop the error_ref derivation and its header paragraph
- `agent-system/extensions/core/scripts/events-append.sh` - reword the `--error-ref` help line

**Verification**:
- The selector-resolved suite run exits 0, using the same
  `suite_selection_select` -> `run-all.sh --only` composition shown in Phase 3's verification,
  with this phase's own eight touched paths as the arguments.
- `bash -n` exits 0 for each edited shell file.
- `grep -rn "specs/errors.json" agent-system/extensions/core/scripts/ agent-system/extensions/core/hooks/` returns nothing.

---

### Phase 5: Sweep the eager and contract-bearing prose [COMPLETED]

**Goal**: Correct every rule, standard, format, and claudemd-merged surface that still documents
the retired store as live, starting with the eager-loaded files where the correction also
recovers context budget.

**Tasks**:
- [x] `agent-system/extensions/core/rules/error-handling.md`: delete the paragraph describing
      `specs/errors.json`/`errors-append.sh`/`/errors` as a narrower decoupled triage surface and
      the sentence leaving its retirement open. The surrounding text already names
      `issue-record.sh` as the live write path and needs no addition. *(completed: also retargeted an unlisted '## Error Handling' bullet in merge-sources/claudemd.md — see deviation note)*
- [x] `agent-system/extensions/core/merge-sources/claudemd.md`: remove the `**Error Tracking**:
      specs/errors.json` quick-reference row and the `/errors` Command Reference row. *(completed)*
- [x] `agent-system/extensions/core/README.md`: remove the `/errors` command table row. *(completed)*
- [x] `agent-system/extensions/core/context/standards/error-recovery-strategies.md`: replace the
      `errors-append.sh append` invocation block and the full CLI/field spec with the
      `issue-record.sh` form already documented in `context/formats/issue-log.md`, and retarget
      the two numbered "Log to errors.json" steps. Point at `issue-log.md` rather than restating
      its schema. *(completed)*
- [x] `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`: delete the
      `specs/.errors.lock` row. In the `specs/.central-errors.lock` row, replace the
      "structurally identical to `specs/.errors.lock` above" comparison with one against
      `specs/.events.lock`, which remains. *(completed: also retargeted the .decisions.lock row's comparison, which pointed at the deleted .errors.lock row, and removed the `**/.errors.lock` gitignore-pattern line — both necessary consequences of the same row deletion)*
- [x] `agent-system/extensions/core/context/standards/git-staging-scope.md`: change the
      four-path engine-written-state list to three. *(completed)*
- [x] `agent-system/extensions/core/context/standards/shell-strict-mode.md`: drop
      `tests/test-errors-append.sh` from its file list. *(completed)*
- [x] `agent-system/extensions/core/context/standards/error-handling.md` and
      `context/standards/git-safety.md`: retarget or delete each `errors.json` mention. *(completed: 2 mentions in error-handling.md retargeted to issue-record.sh; left the unrelated, never-implemented `.agent-logs/errors.json` speculative permission-log mention untouched — different path/schema, out of this task's scope. 5 mentions in git-safety.md retargeted to issue-record.sh)*
- [x] `agent-system/extensions/core/context/formats/issue-log.md`: rewrite the "Three-Store
      Topology" section as a two-store topology (`issues.jsonl`, `events.jsonl`), delete the
      `errors.json` bullet and the closing reader-guidance sentence's third clause, and remove
      `errors.json`'s lazy-creation mention and the `err_{timestamp}` id-convention citation in
      the `entry_id` row. *(completed)*
- [x] `agent-system/extensions/core/context/formats/`: correct the remaining mentions in
      `events-format.md`, `command-output.md`, `command-structure.md`, and `subagent-return.md`. *(completed: command-output.md required removing a full "/errors command" output example block, not named explicitly but the same class of reference)*
- [x] Re-measure the eager context and record the new figure: run
      `REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check`, then update only
      `eager_load.measured_bytes` and `eager_load.measured_at` in
      `agent-system/extensions/core/context/config/orchestrator-context-budget.json`. Do not
      touch `baseline_bytes` and do not edit the `note` field. *(completed: 70389 -> 69930 B, still below the 70400 B baseline_bytes ceiling)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash .claude/scripts/check-task-references.sh`,
`bash .claude/scripts/check-record-versioning.sh`, and
`REPO_ROOT=$(pwd) bash .claude/scripts/measure-eager-context.sh --check` are the only mechanical
checks over these prose files, and the last is the one that covers the two eager files this phase
shrinks.

**Scope Hypothesis**: the eager byte count falls rather than rises, so the budget gate stays
green without any `baseline_bytes` move. Confirm by comparing the `--check` output against
`baseline_bytes` before committing; if the figure somehow rose above baseline, stop and record
the measurement rather than moving the baseline silently.

**Files to modify**:
- `agent-system/extensions/core/rules/error-handling.md` - drop the triage-surface paragraph
- `agent-system/extensions/core/merge-sources/claudemd.md` - drop the Error Tracking and `/errors` rows
- `agent-system/extensions/core/README.md` - drop the `/errors` command row
- `agent-system/extensions/core/context/standards/error-recovery-strategies.md` - retarget onto issue-record.sh
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - drop the `.errors.lock` row, repoint the central-lock comparison
- `agent-system/extensions/core/context/standards/git-staging-scope.md` - four-path list becomes three
- `agent-system/extensions/core/context/standards/shell-strict-mode.md` - drop the retired test from its list
- `agent-system/extensions/core/context/standards/error-handling.md` - retarget the errors.json mentions
- `agent-system/extensions/core/context/standards/git-safety.md` - retarget the errors.json mention
- `agent-system/extensions/core/context/formats/issue-log.md` - three-store topology becomes two
- `agent-system/extensions/core/context/formats/events-format.md` - correct the errors.json mentions
- `agent-system/extensions/core/context/formats/command-output.md` - drop the `/errors` rows
- `agent-system/extensions/core/context/formats/command-structure.md` - correct the errors.json mention
- `agent-system/extensions/core/context/formats/subagent-return.md` - correct the errors.json mention
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` - refresh `measured_bytes`/`measured_at` only

**Verification**:
- `grep -rn "errors-append\|specs/errors\.json\|errors-format\|errors-schema" agent-system/extensions/core/rules/ agent-system/extensions/core/context/standards/ agent-system/extensions/core/context/formats/ agent-system/extensions/core/merge-sources/ agent-system/extensions/core/README.md` returns nothing.
- `measure-eager-context.sh --check` reports a TOTAL at or below `baseline_bytes`.
- `check-task-references.sh` and `check-record-versioning.sh` report no new findings.

---

### Phase 6: Sweep the remaining context, command, skill, and docs prose [NOT STARTED]

**Goal**: Remove the surface from every remaining documentary surface in the source store.

**Tasks**:
- [ ] `agent-system/extensions/core/context/architecture/system-overview.md` and
      `context/architecture/context-layers.md`: remove the `/errors` and `errors.json` mentions.
- [ ] `agent-system/extensions/core/context/orchestration/architecture.md` and
      `context/reference/workflow-diagrams.md`: same.
- [ ] `agent-system/extensions/core/context/patterns/`: correct `backlog-reconciliation.md`
      (which cites `commands/errors.md` as a caller), `context-discovery.md` (which lists
      `/errors` among the command dimension's values), `system-defect-discrimination.md`,
      `early-metadata-pattern.md`, `checkpoint-execution.md`, and `mcp-tool-recovery.md`.
- [ ] `agent-system/extensions/core/context/processes/implementation-workflow.md`: same.
- [ ] `agent-system/extensions/core/commands/task.md`: remove `/errors` from the example caller
      list in the observations paragraph and from the programmatic-caller sentence that names
      `/errors` Step 3.6. `/meta` and `/fix-it` remain as the examples.
- [ ] `agent-system/extensions/core/commands/spawn.md`: remove the `errors.json` mention.
- [ ] `agent-system/extensions/core/skills/skill-reviser/SKILL.md` and
      `skills/skill-status-sync/SKILL.md`: same.
- [ ] `agent-system/extensions/core/docs/`: correct `guides/user-guide.md` (including its table
      of contents anchor), `guides/component-selection.md`, `guides/creating-commands.md`,
      `guides/permission-configuration.md`, `architecture/system-overview.md`,
      `reference/standards/multi-task-creation-standard.md` (its per-command compliance rows for
      `/errors`), and `reference/utility-scripts-inventory.md` (the `errors-append.sh` mirroring
      citation in the `orchestrate-record-decision.sh` entry — repoint it at a live script or
      drop the clause).
- [ ] Run `bash .claude/scripts/lint/lint-dead-command-recommendations.sh` and clear anything it
      flags.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `lint-dead-command-recommendations.sh` is the specific covering check for
a now-dead `/errors` recommendation line, and `validate-index.sh` covers a dangling index pointer
at a deleted file; no suite exercises this prose otherwise.

**Scope Hypothesis**: roughly twenty remaining files carry a reference, as enumerated above.
Confirm at implementation time with
`grep -rln "errors-append\|specs/errors\.json\|errors-format\.md\|errors-schema\.json\|\`/errors\`\|/errors command\|commands/errors\.md" agent-system/extensions/core/`
and work that list, not this one. Note that
`agent-system/extensions/core/context/formats/progress-file.md` matches only on an unrelated
`.../errors.lua` path and must not be edited.

**Files to modify**:
- `agent-system/extensions/core/context/architecture/system-overview.md` - drop the errors mentions
- `agent-system/extensions/core/context/architecture/context-layers.md` - drop the errors mentions
- `agent-system/extensions/core/context/orchestration/architecture.md` - drop the errors mentions
- `agent-system/extensions/core/context/reference/workflow-diagrams.md` - drop the errors mentions
- `agent-system/extensions/core/context/patterns/backlog-reconciliation.md` - drop the commands/errors.md caller citation
- `agent-system/extensions/core/context/patterns/context-discovery.md` - drop `/errors` from the command dimension list
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - drop the `/errors` mention
- `agent-system/extensions/core/context/patterns/early-metadata-pattern.md` - drop the errors.json mention
- `agent-system/extensions/core/context/patterns/checkpoint-execution.md` - drop the errors.json mention
- `agent-system/extensions/core/context/patterns/mcp-tool-recovery.md` - drop the errors.json mention
- `agent-system/extensions/core/context/processes/implementation-workflow.md` - drop the errors.json mention
- `agent-system/extensions/core/commands/task.md` - drop `/errors` from both caller lists
- `agent-system/extensions/core/commands/spawn.md` - drop the errors.json mention
- `agent-system/extensions/core/skills/skill-reviser/SKILL.md` - drop the errors.json mention
- `agent-system/extensions/core/skills/skill-status-sync/SKILL.md` - drop the errors.json mention
- `agent-system/extensions/core/docs/guides/user-guide.md` - drop the `/errors` section and its anchor
- `agent-system/extensions/core/docs/guides/component-selection.md` - drop the `/errors` mention
- `agent-system/extensions/core/docs/guides/creating-commands.md` - drop the errors.json mention
- `agent-system/extensions/core/docs/guides/permission-configuration.md` - drop the errors.json mention
- `agent-system/extensions/core/docs/architecture/system-overview.md` - drop the `/errors` mention
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` - drop the `/errors` compliance rows
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - repoint the errors-append.sh mirroring citation

**Verification**:
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh` passes.
- `bash .claude/scripts/validate-index.sh` reports no missing-file entries.
- The discovery grep above returns only `context/formats/progress-file.md` (the unrelated
  `errors.lua` match).

---

### Phase 7: Sweep the script comments and test-harness stub lists [NOT STARTED]

**Goal**: Clear the remaining references inside shell sources — header comments, structural-model
citations, and the scratch-tree stub lists that fabricate an `errors-append.sh` into fixture
deploy trees.

**Tasks**:
- [ ] `agent-system/extensions/core/scripts/lib/common.sh`: remove `scripts/errors-append.sh` and
      `scripts/tests/test-errors-append.sh` from the two header enumerations.
- [ ] `agent-system/extensions/core/scripts/orchestrate-record-decision.sh`: the header says its
      write mechanics follow `errors-append.sh`'s `append` subcommand. Repoint that citation at a
      surviving `flock`-guarded writer (`issue-record.sh` or `events-append.sh`) or restate the
      mechanics inline; do not leave a pointer at a deleted file.
- [ ] `agent-system/extensions/core/scripts/validate-state.sh`: its header cites
      `context/formats/errors-format.md` for the hand-rolled bash+jq idiom. Repoint at a
      surviving format document or restate the idiom.
- [ ] `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`: drop
      `specs/errors.json` from the engine-written-state comment list.
- [ ] `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` and
      `tests/test-orchestrate-record-decision.sh`: both cite `test-errors-append.sh` as their
      structural model. Repoint at a surviving suite with the same structure.
- [ ] Remove `errors-append.sh` from the scratch-tree stub lists in
      `tests/test-orchestrate-recover-message-findings.sh`,
      `tests/test-handoff-dispatch-identity.sh` (two occurrences),
      `tests/test-orchestrate-context-growth.sh`, and
      `tests/test-orchestrate-cycle-postflight.sh` (two occurrences).
- [ ] Run `bash .claude/scripts/lint/lint-shellcheck.sh` over the edited scripts.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: full

**Tier Justification**: this phase edits `scripts/lib/common.sh`, which every suite in the corpus
sources — a cross-cutting surface no narrowed selection covers; the repository's own
`suite_selection_select` confirms it by resolving this phase's touched paths to effectively the
whole suite set, so the full run is the honest check rather than a hand-picked subset.

**Scope Hypothesis**: eleven shell files carry only comment-level or stub-list references, none
of them executable logic. Confirm by re-running the discovery grep restricted to
`agent-system/extensions/core/scripts/` after Phase 4 has landed, and treat any match that turns
out to be executable logic rather than a comment as a finding to handle in this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/common.sh` - drop both header enumeration entries
- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` - repoint the write-mechanics citation
- `agent-system/extensions/core/scripts/validate-state.sh` - repoint the bash+jq idiom citation
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - drop errors.json from the comment list
- `agent-system/extensions/core/scripts/tests/test-generate-task-order.sh` - repoint the structural-model citation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` - repoint the structural-model citation
- `agent-system/extensions/core/scripts/tests/test-orchestrate-recover-message-findings.sh` - drop the stub entry
- `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - drop both stub entries
- `agent-system/extensions/core/scripts/tests/test-orchestrate-context-growth.sh` - drop the stub entry
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - drop both stub entries

**Verification**:
- `bash .claude/scripts/tests/run-all.sh` (unnarrowed) exits 0 with no new failures relative to
  the pre-task baseline.
- `bash .claude/scripts/lint/lint-shellcheck.sh` exits 0.
- `grep -rn "errors-append" agent-system/extensions/core/scripts/` returns nothing.

---

### Phase 8: Redeploy and run the complete gate set [NOT STARTED]

**Goal**: Regenerate the deployed tree so no orphaned copy of the removed files survives, then
prove the whole system is green.

A plain deploy overlays rather than prunes, so the removed files would remain in `.claude/` and
fail gate 13's `find_orphans` check. The wipe form snapshots, removes `.claude/` entirely, and
rebuilds it; `.syncprotect` is honored by the underlying engine.

**Tasks**:
- [ ] Re-run the repo-wide discovery grep over the source store and confirm nothing remains
      outside `agent-system/extensions/core/.claude-extensions.json` (deliberately out of scope,
      see Non-Goals) and `context/formats/progress-file.md` (unrelated `errors.lua` match).
- [ ] `bash .claude/scripts/deploy-headless.sh --wipe`.
- [ ] Confirm the deployed tree no longer carries `.claude/commands/errors.md`,
      `.claude/scripts/errors-append.sh`, `.claude/scripts/tests/test-errors-append.sh`,
      `.claude/context/formats/errors-format.md`, or `.claude/context/schemas/errors-schema.json`.
- [ ] `bash .claude/scripts/verify-deploy.sh` — the full gate set, including gate 1 (now
      events-only) and gate 13 (`find_orphans`, covering both orphan files and ghost index rows).
- [ ] `bash .claude/scripts/tests/run-all.sh` — the complete suite, not a narrowed selection.
- [ ] `bash .claude/scripts/validate-wiring.sh`, `bash .claude/scripts/validate-index.sh`,
      `bash .claude/scripts/check-task-references.sh`,
      `bash .claude/scripts/check-record-versioning.sh`, and the full
      `.claude/scripts/lint/` set.
- [ ] Confirm `.claude/CLAUDE.md` regenerated without the Error Tracking and `/errors` rows.

**Timing**: 1 hour

**Depends on**: 3, 4, 5, 6, 7

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - the deploy regenerates the entire deployed tree

**Verification**:
- `verify-deploy.sh` reports zero failures across every gate, gate 13 included.
- `tests/run-all.sh` passes with no new failures relative to the pre-task baseline.
- `validate-wiring.sh` and `validate-index.sh` pass.
- Every lint under `.claude/scripts/lint/` reports no new findings.
- None of the five removed paths exists under `.claude/`.
- `grep -rn "errors-append\|specs/errors\.json" .claude/` returns nothing.

---

## Testing & Validation

- [ ] The disposition artifact gives all 19 records a recorded outcome, with any undischarged
      finding named explicitly.
- [ ] `specs/errors.json` is gone and its content is reachable through git history.
- [ ] None of the five removed source-store files exists, and none is registered in
      `manifest.json` or `index-entries.json`.
- [ ] `verify-deploy.sh` gate 1 asserts six events-store paths and gate 13 finds no orphans.
- [ ] The engine-written-state literal is three elements and all three consuming suites assert
      the new membership.
- [ ] The eager context measurement is at or below `baseline_bytes` with `baseline_bytes`
      unmoved.
- [ ] `tests/run-all.sh` and the full lint set are green.
- [ ] A repo-wide grep of the source store finds no live reference to the retired surface.

## Artifacts & Outputs

- `specs/591_retire_errors_json_triage_surface/reports/01_errors-record-disposition.md` — the
  retirement verdict and the per-record disposition table.
- `specs/591_retire_errors_json_triage_surface/summaries/01_*-summary.md` — the completion
  summary, which should restate the verdict and name any follow-up candidate the audit surfaced.
- A regenerated `.claude/` deploy tree with the surface absent.

## Rollback/Contingency

Every change is a tracked git edit; the phases commit individually, so any single phase can be
reverted on its own with `git revert`. `specs/errors.json` is recoverable from history with
`git show <sha>:specs/errors.json > specs/errors.json`.

If the capability verdict proves wrong after the fact — if some consumer genuinely needed the
mutable `fix_status` lifecycle — the correct response is not to restore the retired surface but
to add a `resolution`-advancing mechanism to `issues.jsonl`, which is the store that actually
carries this repository's error traffic. Restoring a store with no writer would reinstate the
defect this task exists to close.

If Phase 8's wipe deploy fails its own pre-wipe snapshot, the script leaves `.claude/` untouched
and exits non-zero; resolve the snapshot failure and retry rather than falling back to a plain
deploy, which would leave the orphans gate 13 is there to catch.
