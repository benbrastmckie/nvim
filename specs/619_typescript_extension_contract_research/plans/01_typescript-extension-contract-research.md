# Implementation Plan: Task #619

- **Task**: 619 - Survey the real extension file contract and establish the 2026 TypeScript toolchain detection matrix
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None (head of the `typescript-extension` chain: 619 -> 620 -> 621 -> 622 -> 623)
- **Research Inputs**: specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md
- **Artifacts**: plans/01_typescript-extension-contract-research.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task's sole deliverable is a research report, and that report already exists and already
answers all six required outcomes in substance. The remaining work is therefore not new
investigation but **closeout**: re-verify the report's load-bearing mechanical claims against live
source before four downstream tasks build on them, and close two specific coverage gaps found at
plan-authoring time that the downstream chain will press directly. Definition of done: every one of
the six required outcomes is answered in the report, each load-bearing mechanical claim has been
re-derived against the source store in this task, and the report passes `validate-artifact.sh` plus
the full gate set. All writes land under `specs/**`; no file under `agent-system/extensions/` is
created or modified by this task.

### Research Integration

The report (`reports/01_typescript-extension-contract-research.md`, 39 KB) supplies the entire
substance this plan operates on: the required-vs-convention file inventory ground-truthed against
`manifest.lua`, the manifest/`index-entries.json` field-to-consumer table, the four-stage lifecycle
hook contract (five positional args, unconditionally non-blocking exit codes, basename resolution
against the flat deployed `.claude/scripts/`), the `keyword_overrides` / `hard_contracts` resolution
mechanics, the `index.json` upsert-by-`path` merge model, and the 2026 toolchain detection matrix.
Its Recommendations section already carries the four inputs task 620 consumes (scaffold on the `nix`
precedent rather than the `python`/`rust` floor; model `keyword_overrides.typescript` on `rust`'s
multi-word-biased entry; declare `routing_agents` before `keyword_overrides`; decline
`hard_contracts` for a first cut per `books`'s precedent). This plan does not re-derive any of that
— it verifies it and fills what it is missing.

Two gaps were identified mechanically while authoring this plan, and both are closed by phases
below rather than deferred to a downstream task:

- **Outcome 2 gap**: `merge_targets` is covered at the key level only. Its per-entry sub-fields
  `source`, `target` and `section_id` have no row in the field-to-consumer table, and `section_id`
  does not appear in the report at all — yet task 621's own description mandates
  `section_id: extension_typescript`.
- **Outcome 6 gap**: the detection matrix has no signal for Node's native TypeScript type-stripping
  (running `.ts` files directly under `node --test` with no build step), none for a TypeScript
  project carrying **no** `tsconfig.json`, and none for the syntax constraint type-stripping imposes.
  Task 622's falsifiability profile is precisely that shape — ESM, `node --test test/*.test.ts`, no
  `tsconfig.json` anywhere, no bundler — so the matrix currently has a hole exactly where the chain's
  own validation task will press.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch's delegation context, so no roadmap file was loaded
as an input. For continuity, `specs/ROADMAP.md`'s head batch is this same chain
(`/orchestrate 619, 620, 621, 622, 623`), seated at position 0 as the stated priority on the grounds
that it contends for no open territory; the chain is linear and five deep with one member per wave,
and `619` is its only dispatchable member today. The roadmap's own note that `619` and `620` declare
an empty `file_scope` array is consistent with this plan: both are `specs/**`-only records, and that
is why the empty array is harmless for these two specifically. This plan makes no roadmap edit.

## Goals & Non-Goals

**Goals**:
- Re-derive each load-bearing mechanical claim in the report against live source, so four downstream
  tasks inherit verified facts rather than a single-pass reading.
- Close the Outcome 2 field-to-consumer gap at `merge_targets` sub-field granularity, including
  `section_id`.
- Close the Outcome 6 detection-matrix gap for native type-stripping, the no-`tsconfig.json` project
  shape, and the syntax constraint type-stripping imposes — verified against current sources, not
  pretraining.
- Leave the report passing `validate-artifact.sh ... report` and the full gate set.

**Non-Goals**:
- Creating or modifying anything under `agent-system/extensions/` — that is tasks 621 and 623.
- Designing the new extension's file manifest, agents, tree layout, or content split — that is
  task 620.
- Loading the extension into any consumer repository or validating detection end to end — that is
  task 622.
- Re-opening the three prior-art closures the report already corroborated against live source
  (the hard-contracts injection lineage and the keyword-override false-positive fix).
- Executing the `typescript-web.md` split, or re-measuring its line boundaries.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A re-derivation contradicts a report claim that tasks 620/621 would have built on | H | M | Phase 1 corrects the report in place at the point of discovery and records the contradiction in the issue log, rather than noting it only in prose |
| Native type-stripping facts are asserted from pretraining and are wrong for late-2026 Node | H | M | Phase 3 requires a live source check for each version threshold before any row is written; an unverifiable threshold is written as a signal without a version claim, never as a guessed number |
| Gap-closure edits bloat the report into a general TypeScript tutorial | M | M | Each new row names a detection SIGNAL only, matching the existing matrix's column shape; no new prose section is added beyond the rows and their notes |
| The report's own completeness-discharge sweeps have gone stale since the research dispatch | M | L | Phase 1 re-runs both sweeps verbatim and treats a changed result as a correction, not a footnote |
| Four serial single-file phases tempt a batched end-of-task commit | M | M | Commit mode is the default `per-substep` on every phase; each phase closes with its own commit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is deliberately fully serial: every
phase edits the same single file (`reports/01_typescript-extension-contract-research.md`), so no two
phases may run concurrently.

### Phase 1: Re-verify load-bearing claims and enumerate residual gaps [COMPLETED]

**Goal**: Establish that each mechanical claim the downstream chain will build on still holds against
live source, and produce a confirmed, closed list of residual coverage gaps.

**Tasks**:
- [x] Re-run both completeness-discharge sweeps the report cites verbatim and compare against its
      stated results: `grep -l "hard_contracts" agent-system/extensions/*/manifest.json` (report
      claims exactly `lean` and `cslib`) and a sweep of `specs/archive/` for any directory name
      containing `deliver_hard_mode` or `hard_mode_contracts` (report claims none). *(completed: both sweeps re-run verbatim, both matched the report exactly)*
- [x] Re-derive the loader's hard requirement: confirm `REQUIRED_FIELDS` in
      `lua/neotex/plugins/ai/shared/extensions/manifest.lua` is exactly `name`/`version`/`description`
      and that `validate_provides` / `validate_merge_targets` each return early when their key is
      absent. *(completed: confirmed at manifest.lua lines 7, 43-53, 59-85, 91-113)*
- [x] Re-derive the lifecycle-hook contract against `agent-system/extensions/core/scripts/lib/skill-base.sh`:
      the `task_type` string-equality gate in `skill_get_extension_dir()`, the five positional args
      passed to a hook script, and that `skill_run_extension_hook`'s terminal statement is
      unconditionally `return 0`. *(completed: confirmed at agent-system/extensions/core/scripts/skill-base.sh -- actual path has no /lib/ segment; the task text above names a non-existent `scripts/lib/skill-base.sh`, the real file is `scripts/skill-base.sh`)*
- [x] Re-derive `routing_lookup_flat()`'s four-step ladder in
      `agent-system/extensions/core/scripts/lib/manifest-routing-lib.sh` and confirm it is a sibling
      of `routing_lookup()` rather than a wrapper over it. *(completed: confirmed sibling, not wrapper, per the function's own source comment)*
- [x] Re-derive `append_index_entries()`'s upsert-by-exact-`path` behavior in
      `lua/neotex/plugins/ai/shared/extensions/merge.lua`. *(completed: confirmed at merge.lua lines 687-738)*
- [x] Sweep the five surveyed manifests for any top-level or `merge_targets` sub-field key that has
      no row in the report's Outcome 2 table, and record the resulting unlisted-key list for Phase 2
      to consume: `for e in python rust web nix lean; do jq -r 'keys[]' agent-system/extensions/$e/manifest.json; done | sort -u`. *(completed: unlisted-key list is empty -- every top-level and merge_targets-entry key already has a report row; the only gap is the merge_targets.{entry}.{source,target,section_id} sub-field rows Phase 2 is already tasked with adding)*
- [x] Apply an in-place correction to the report for any claim found not to hold, and record each
      such correction via `issue-record.sh` as it is found. *(completed: no claim failed re-derivation, so no correction was applied; recorded as a win via issue-record.sh)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Two figures are carried into this phase from the report and must be re-derived
rather than trusted — "exactly `lean` and `cslib` declare `hard_contracts`" and "no archived
directory names `deliver_hard_mode`/`hard_mode_contracts`" (source:
`reports/01_typescript-extension-contract-research.md`, Risks & Mitigations, carried-figure
discharge bullet). Both are confirmed by the two sweep commands named in the task list above; a
differing result is a correction to the report, not a footnote.

**Tier Justification**: Every path this phase touches lies under `specs/**` and
`suite_selection_select` returns `__FULL_SWEEP__` for it, so no suite covers the file; the covering
check is `bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` alongside a diff read-through, and every edit here is markdown prose with no executable surface.

**Files to modify**:
- `specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md` - in-place corrections to any claim that fails re-derivation; no edit if every claim holds

**Verification**:
- Both discharge sweeps re-run, with their actual output recorded in the phase's progress notes
- Each of the five re-derivations cites the file and the function or constant it was confirmed
  against
- The unlisted-key list for Phase 2 is explicit and closed (possibly empty)
- `bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` exits 0

---

### Phase 2: Close the Outcome 2 field-to-consumer gap [COMPLETED]

**Goal**: Make the Outcome 2 field-to-consumer table complete at `merge_targets` sub-field
granularity, so task 621 can author its manifest from the report alone.

**Tasks**:
- [x] Add rows to the Outcome 2 `manifest.json` table for `merge_targets.{entry}.source`,
      `merge_targets.{entry}.target` and `merge_targets.{entry}.section_id`, each paired with its
      actual consumer, read out of `merge.lua` / `loader.lua` rather than inferred: `source`/`target`
      are what `validate_merge_targets()` requires on every entry and what the deploy engine reads to
      locate and place content; `section_id` must be traced to the consumer that actually reads it
      (expected: the CLAUDE.md section-delimiting path in `generate_claudemd()` and its reverse on
      unload) and named, not described generically. *(deviation: altered — traced to "no live consumer", not the expected generate_claudemd()/section-delimiting path; see progress file task 2.1. Also corrected the pre-existing merge_targets row's consumer attribution from loader.lua to init.lua.)*
- [x] Add a row for every key on Phase 1's unlisted-key list, or state explicitly in the phase notes
      that the list came back empty. *(completed: the list came back empty beyond the sub-field rows objective 1 already adds)*
- [x] Add one sentence to the table's surrounding prose recording that `section_id` is mandatory in
      practice for any extension merging into CLAUDE.md — the convention every surveyed manifest
      follows — and name the form task 621 is specified to use (`extension_typescript`). *(completed: worded to agree with the "presently inert, convention-only" finding)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The gap this phase closes rests on two claims measured at plan-authoring time:
`section_id` appears in the `merge_targets` entries of all five surveyed manifests, and appears zero
times in the report. Confirm both before editing, with
`for e in python rust web nix lean; do jq -r '[.merge_targets//{}|to_entries[]|.value|keys[]]|unique|join(",")' agent-system/extensions/$e/manifest.json; done`
and `grep -c section_id specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md`.
If the report already covers it, this phase narrows to the unlisted-key rows only.

**Tier Justification**: The only touched path is the `specs/**` report, for which
`suite_selection_select` returns `__FULL_SWEEP__` (no suite covers it); the covering check is
`bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` plus a diff read-through, and the edit adds table rows to markdown with no executable surface.

**Files to modify**:
- `specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md` - new rows in the Outcome 2 `manifest.json` field-to-consumer table, plus one clarifying sentence

**Verification**:
- Every `merge_targets` sub-field key present in any of the five surveyed manifests has a row naming
  a specific consumer function, not a generic description
- `section_id`'s named consumer was read out of source in this phase, not assumed
- Phase 1's unlisted-key list is fully discharged (every entry either has a row or a stated reason it
  needs none)
- `bash .claude/scripts/validate-artifact.sh ... report` exits 0

---

### Phase 3: Close the Outcome 6 detection-matrix gap [COMPLETED]

**Goal**: Give the detection matrix the signals it currently lacks for the exact project shape task
622 will validate against: `.ts` run directly under Node with no build step and no `tsconfig.json`.

**Tasks**:
- [x] Verify against current sources (web search, not pretraining) the state of Node's native
      TypeScript type-stripping as of late 2026: which Node versions strip types unflagged, which
      require a flag, and what the flag names are. Write the version thresholds only as far as they
      are actually verified; an unverified threshold is recorded as a signal with no version claim. *(completed: verified against official Node.js docs + nightly v26 history table; all thresholds cited inline)*
- [x] Add a "Native type-stripping / no-build TypeScript execution" block of rows to the matrix,
      each naming a detection SIGNAL in the same column shape the existing rows use — candidate
      signals to confirm: a `package.json` script invoking `node --test` or `node` directly on a
      `.ts` path; `engines.node` pinning a version at or above the unflagged threshold; a
      `--experimental-strip-types` / `--experimental-transform-types` flag appearing in any script;
      the absence of any build or bundler devDependency alongside `.ts` entry points. *(completed: new ### subsection added after Typecheck/Build, 6-row table including --no-strip-types as an additional confirmed signal)*
- [x] Add a row for the **no-`tsconfig.json`** project shape, stating explicitly what each dependent
      signal degrades to when it is absent: the existing `tsc` typecheck row's primary signal does
      not fire, and the entire "Module Resolution Modes" subsection is unanswerable from config and
      must be inferred from source import style instead. *(completed: new row added to Module Resolution Modes table)*
- [x] Add the syntax-constraint note that type-stripping implies — the constructs it cannot erase
      (confirm the current set; expected: enums, namespaces, parameter properties, legacy
      decorators) and the `erasableSyntaxOnly` compiler option that enforces the constraint when a
      `tsconfig.json` does exist. *(completed: confirmed set is enum/namespace-with-runtime-code/parameter-properties/decorators/tsconfig-paths; erasableSyntaxOnly confirmed as a real TS 5.8 option)*
- [x] Add one sentence to the matrix preamble recording that a TypeScript project may legitimately
      have no `tsconfig.json` at all, so a detection script must not treat its absence as "not a
      TypeScript project". *(completed)*

**Timing**: 0.6 hours

**Depends on**: 2

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The gap rests on a measurement taken at plan-authoring time — a case-insensitive
grep of the report for `strip-types|type-strip|stripping|erasableSyntax|no tsconfig|allowImportingTsExtensions|--experimental`
returned zero matches. Re-run that grep before editing; if any term now appears, narrow this phase to
the genuinely missing rows rather than duplicating existing coverage. Every version threshold written
in this phase is a carried figure from a live source and must name that source inline or be written
without the number.

**Tier Justification**: The only touched path is the `specs/**` report, for which
`suite_selection_select` returns `__FULL_SWEEP__` (no suite covers it); the covering check is
`bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` plus a diff read-through, and the edit adds matrix rows to markdown with no executable surface.

**Files to modify**:
- `specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md` - new rows and notes in the TypeScript Toolchain Detection Matrix section

**Verification**:
- Task 622's stated profile (ESM, `node --test test/*.test.ts`, no `tsconfig.json`, no bundler) can be
  classified end to end by reading the matrix alone, with every classification step resting on a named
  signal
- Every version threshold asserted names the source it was verified against in this phase
- No new row assumes a stack; each names a file presence, lockfile name, `package.json` script, or
  dependency key
- `bash .claude/scripts/validate-artifact.sh ... report` exits 0

---

### Phase 4: Outcome-coverage attestation and final gate [COMPLETED]

**Goal**: Attest that all six required outcomes are answered, and close the task against the full
gate set.

**Tasks**:
- [x] Walk the dispatch's six REQUIRED OUTCOMES one at a time and record, for each, the report
      section and heading that answers it — a one-line mapping, six entries, no gaps and no
      "partially". *(completed: see handoff's Outcome-Coverage Mapping; all six report H2/H3 headings already carry explicit "(Outcome N)" tags)*
- [x] Confirm the report's Recommendations section still carries all four inputs task 620 consumes,
      and that nothing added in Phases 2-3 contradicts them. *(completed: re-read lines 258-284; all four bullets intact and unaffected by Phases 2-3)*
- [x] Re-read the report end to end once for internal consistency between the sections the three
      prior phases edited. *(completed: full end-to-end read surfaced and corrected a third instance of the loader.lua/init.lua conflation -- the dependencies row's manager.load() attribution)*
- [x] Run `bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` and resolve any finding. *(completed: exits 0, 0 warnings, after the Phase 4 correction)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` ... *(deviation: altered — discharged per the dispatch's Batch Gate Deferral directive instead of run independently; see handoff's Batch Gate Deferral Discharge note)*
- [x] Attest in the handoff whether anything was recorded in the issue log during this task, rather
      than silently recording nothing. *(completed: see handoff's Issue Log Attestation)*

**Timing**: 0.4 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md` - consistency corrections only, if the end-to-end read surfaces any

**Verification**:
- A six-entry outcome-to-section mapping exists, with every entry naming a real heading in the report
- `bash .claude/scripts/validate-artifact.sh ... report` exits 0
- `bash .claude/scripts/verify-deploy.sh` runs to completion with no failing gate attributable to
  this task's edits; the full gate set is run, not a hand-picked subset of validators
- The issue-log attestation is present in the handoff prose

---

## Testing & Validation

- [ ] Both of the report's completeness-discharge sweeps re-run, with actual output recorded
- [ ] All five load-bearing mechanical claims re-derived against named source files and functions
- [ ] `merge_targets` sub-field coverage complete, `section_id`'s consumer traced to source
- [ ] Task 622's profile classifiable end to end from the matrix alone
- [ ] Six-entry outcome-to-section mapping complete with no gaps
- [ ] `bash .claude/scripts/validate-artifact.sh specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md report` exits 0
- [ ] `bash .claude/scripts/verify-deploy.sh` passes

## Artifacts & Outputs

- `specs/619_typescript_extension_contract_research/reports/01_typescript-extension-contract-research.md`
  (updated: Outcome 2 table completed, detection matrix extended, any failed claim corrected)
- `specs/619_typescript_extension_contract_research/summaries/01_typescript-extension-contract-research-summary.md`
  (written at completion)
- `specs/619_typescript_extension_contract_research/plans/01_typescript-extension-contract-research.md`
  (this file, phase markers advanced in place)
- Issue-log entries in `specs/619_typescript_extension_contract_research/issues.jsonl`, recorded as
  they arise

## Rollback/Contingency

Every write in this task lands on one markdown file under `specs/**`; nothing under
`agent-system/extensions/` is touched, so no deploy, no extension load state, and no consumer
repository can be left inconsistent by a failure here. Each phase commits its own green state, so
reverting a bad phase is a revert of that phase's single commit.

If a phase's work must be discarded before it is committed, take a durable checkpoint that does not
revert the working tree first — `bash .claude/scripts/git-snapshot.sh 619 --no-revert` — and then
discard. A genuine reverting rollback (the default, tree-reverting form of `git-snapshot.sh`) is
warranted here only if a correction applied in Phase 1 is later found to have been wrong and the
report must be returned to its researched state; in that case follow
`context/contracts/recovery.md`'s rollback rung for the exact invocation shape, including its
out-of-scope override flag, rather than improvising a destructive git command.

Contingency on an irreducible blocker: if a Phase 3 version threshold cannot be verified against any
live source, write the signal without the version claim and record the unresolved threshold in the
issue log — the matrix row is still useful as a signal, and a guessed version number is exactly the
failure mode the report's own Decisions section was written to avoid. This does not block the task.
