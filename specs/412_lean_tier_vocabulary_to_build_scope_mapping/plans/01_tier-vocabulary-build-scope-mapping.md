# Implementation Plan: Task #412

- **Task**: 412 - Map core's Verification Tier vocabulary onto Lean build scopes
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: 396 (completed)
- **Research Inputs**: `specs/412_lean_tier_vocabulary_to_build_scope_mapping/reports/01_tier-vocabulary-build-scope-mapping.md`
- **Artifacts**: plans/01_tier-vocabulary-build-scope-mapping.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The lean extension defines no Lean meaning for core's four Verification Tier values, so a lean
plan's `**Tier Justification**:` line for a non-final phase is a reflex declaration of `full`
carrying no information. This plan adds one new section to
`lean-implementation-flow.md` stating what `prose`, `local`, `interface`, and `full` concretely
mean as Lean verification actions, and makes `lean-implementation-agent.md` point at it rather
than restate it. The mapping adopts, without relitigating, the settlement already landed by task
396: for Lean, `full` is the only tier that ever discharges a phase-end close or commit, because
Lean's declaration namespace is project-wide and a module-scoped build cannot see a cross-module
name clash. `prose`/`local`/`interface` are therefore defined as *in-phase, non-gating*
verification density — which is what core's tiering vocabulary is actually about — never as a
substitute for the phase-end full build.

### Premise Re-Validation (Carried-Figure Discipline)

Each flagged line in the dispatch `## Description` was checked against the prior research report
and against live repository state. Results, stated explicitly including where the description is
confirmed unchanged:

| Carried claim | Verdict | Evidence |
|---|---|---|
| `plan-format.md` defines `**Verification Tier:**` (one of prose/local/interface/full) at L97-98 | **Confirmed exactly** | `sed -n '95,108p'` on `agent-system/extensions/core/context/formats/plan-format.md` shows the field at L97-98 |
| `**Tier Justification:**` required on every non-final phase, omitted on the final phase, at L103-107 | **Confirmed exactly** | Same read; L103-107 carries the conditional-field text verbatim |
| …"L314" (third citation on the same line) | **Off by location, harmless** | L312-316 is the phase-heading regex table, not the Tier Justification field. The field's substantive spec is in `## Verification Tiers` (L351ff), which was read in full. Nothing in this plan depends on the L314 citation |
| "the lean extension never says what prose/local/interface/full MEAN" | **Confirmed** | A repo-wide search for `Verification Tier` under `agent-system/extensions/lean/` returns exactly one hit, a cross-reference to core's own section inside `plan-authoring-gate-collisions.md` Condition 2 (L55). No lean-local definition exists |
| "the shared flow document both lean implementation agents already reference" / "the two lean implementation agent files" | **FALSE as stated — one agent, not two** | `agent-system/extensions/lean/agents/` contains only `lean-implementation-agent.md` and `lean-research-agent.md`. `lean-implementation-hard-agent.md` was deleted 2026-11-09 (commit `749c660a4`) under the architecture `.claude/CLAUDE.md`'s `## Hard Mode (--hard)` records: `--hard` dispatches the same agent, with contracts injected at dispatch time. This plan edits the one surviving agent file |
| "every lake build stays DETACHED via `Bash(run_in_background: true)`" | **FALSE as stated — the live contract says the opposite** | `long-builds.md` Obligation 1 (L49-57): invoke as a *shell-level background job* (`cmd >log 2>&1 & pid=$!`), "never via the harness's own `Bash(run_in_background: true)` tool parameter." `lean-implementation-agent.md` MUST DO item 8 and MUST NOT item 13 restate the same prohibition. This plan preserves the **live** contract; the dispatch's PRESERVE clause names the right obligation (detachment) but the wrong mechanism |
| Bounded-wait obligation in `external-process-wait` / `long-builds.md` unchanged; scoped builds never exempt from detachment or guard | **Confirmed** | `long-builds.md` "Scoped builds are covered too" (L114-127) and "Completion discipline" (L198ff). No file in this plan's scope touches either |
| "check-module-invariants.sh in build-enabled mode" must be preserved | **Unverifiable from this repository** | `check-module-invariants.sh` is a consumer-repo script (a Lean project's own `scripts/`), absent from this source store; a repo-wide grep for `build-enabled` across the lean extension returns zero hits. The mapping will describe the mechanism functionally ("whichever of this script's checks require a completed build") rather than assert an unconfirmed flag name |
| "olean-freshness-for-every-touched-module tier" must be preserved | **Confirmed, under its existing name** | `long-builds.md` "Reading the build's verdict" item 3 (L190-193): "Strongest: an `.olean`-newer-than-source check per touched module." This is the strongest of three verdict-reading mechanisms for the `full` build, not a fifth tier; the mapping cites it by that existing name |
| Task 396 settled phase-commit gating; scoped `Periodic.lean` build passed while the full build failed on a `dualStructure` / `WeakCanonical.dualStructure` clash | **Confirmed as settled and already landed** | Task 396 (`lean_phase_commit_full_build_and_plan_anchor`) is `completed` in `specs/archive/state.json`. Its conclusion is live, unconditionally, in `lean-implementation-flow.md` Stage 4C (L121-133) and `lean-implementation-agent.md` Phase Checkpoint Protocol item 3 / MUST DO item 7 / MUST NOT item 3. This plan adopts it; it does not re-decide it |
| BimodalLogic cost figures (414 of 2848 jobs, 6354s elaboration; Metalogic 5649s / 306 modules; SubformulaProperty.lean 1103s, 2026-10-15) | **Not verifiable from this repository** | Measured in a different repository from a `.lake/build-guard.stdout` not present here. Carried as motivating background only — no phase, tier assignment, or acceptance criterion below depends on any of these numbers |

### Research Integration

Four research findings drive the phase structure directly:

1. Task 396's settlement is unconditional and already landed, so the mapping must present `full`
   as the sole phase-end-gating tier for Lean (Phase 1's central constraint, and Phase 2's
   contradiction check).
2. The standing cross-cutting surface that justifies `full` is nameable once: *the project-wide
   Lean declaration namespace — any new or renamed declaration can collide with an identically
   named one anywhere else in the library, invisible to any module-scoped build.* Stating it once
   and having lean plan authors point at it is the deliverable's whole point.
3. `plan-format.md`'s "Unmappable criterion" paragraph (Batch-aware deferral section) is the
   sanctioned authority for a domain defining its own concrete per-tier actions when core's
   shell-suite narrowing cannot express the covering check — and `suite_selection_select` has
   zero `.lean` mappings, so it would return `__FULL_SWEEP__` for any Lean-only phase. The
   mapping cites this hook rather than appearing to freelance a parallel vocabulary.
4. No fifth tier, no renamed tier value. The `.olean`-freshness check and the build-dependent
   `check-module-invariants.sh` checks are covering checks *within* `full`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; `specs/ROADMAP.md`
was not consulted.

## Goals & Non-Goals

**Goals**:
- State, once, in `lean-implementation-flow.md`, what each of core's four Verification Tier
  values means as a concrete Lean verification action.
- Name the standing cross-cutting surface (the project-wide Lean declaration namespace) once, so
  a non-final lean phase declaring `full` can point at it instead of re-deriving it.
- Make `lean-implementation-agent.md` point at the new section without restating or contradicting
  it.
- Leave the detachment, build-guard, and bounded-wait obligations verifiably byte-identical.

**Non-Goals**:
- Deciding or revisiting whether a phase commit is gated on a full build. Task 396 owns that; this
  plan adopts its conclusion.
- Modifying `lake-build-guard.sh`.
- Modifying `agent-system/extensions/core/context/formats/plan-format.md` — core already carries
  the required fields; this task consumes them.
- Introducing a fifth tier or renaming any of the four core tier values.
- Editing `agent-system/extensions/lean/index-entries.json`. A concurrent sibling (task 397) holds
  that file this cycle; see Risks for the accepted `line_count` drift and its remedy.
- Hand-editing `specs/state.json`'s `file_scope`. The stale `lean-implementation-hard-agent.md`
  entry is corrected mechanically: no phase below names that path, so
  `plan-file-scope-harvest.sh` rebuilds `file_scope` from this plan's `Files to modify` blocks at
  plan-postflight and the dead path simply does not survive.
- Writing to any deployed `.claude/**` path. The source store under `agent-system/extensions/` is
  the edit target; Phase 3 regenerates the deploy tree.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The mapping's wording lets `local`/`interface` read as able to gate a Lean phase close/commit, silently reopening the cross-module-clash hole task 396 closed | H | M | Phase 1 states `full` as the sole phase-end-gating tier in the section's own opening sentence, and labels every cheaper tier **non-gating** inline at each row. Phase 2's explicit contradiction check re-reads Stage 4C, Stage 4D, Phase Checkpoint item 3, MUST DO 7-8 and MUST NOT 3 against the new section |
| The new section duplicates rather than points at Stage 4C, so the two drift apart later | M | M | The mapping's `full` row cites Stage 4C by name for the gating rule rather than restating its rationale; Stage 4C gains a pointer to the mapping, not a copy of it |
| Citing an unverified `--build-enabled`-shaped flag for `check-module-invariants.sh` that does not exist, or exists under another name, in a given consumer repo | M | H | Describe functionally — "whichever of this script's checks require a completed build, as opposed to a pure source-text scan" — never a specific flag name. Verified above as unconfirmable from this source store |
| Restating the detachment mechanism in the new section, and restating it per the dispatch's wrong wording (`Bash(run_in_background: true)`) | H | M | The mapping never restates the invocation mechanism at all; it defers to `long-builds.md`'s preference order by reference, exactly as Stage 4C already does. Phase 3 verifies both obligation sections are byte-identical to their pre-change state |
| Record-versioning or task-number language leaking into a source-store file (task 396, "previously", "no longer") | M | M | The mapping names the *rationale* (project-wide declaration namespace) and `long-builds.md`/Stage 4C as durable anchors, never a task number or a draft lineage. Phase 3 runs the repo-wide lints that enforce both rules |
| `index-entries.json`'s `line_count: 224` for the flow doc drifts past the validator's 10% tolerance once the section lands | L | H | Accepted and declared, not worked around. `validate-context-index.sh` emits a **warning**, not an error, and is not wired into `verify-deploy.sh`; the remedy is the repo-wide `generate-context-line-counts.sh --write`, deliberately out of scope here because task 397 holds that file concurrently |
| A sibling task's in-flight edit to a lean extension file is mistaken for this task's own regression | M | L | Territory contract: re-read each file immediately before editing, stage only this task's own files by explicit path, never a directory or glob add, and never `git-snapshot.sh` in its reverting default mode |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel; this plan is strictly sequential.

---

### Phase 1: Author the Tier-to-Lean-Action Mapping [COMPLETED]

**Goal**: `lean-implementation-flow.md` contains one new section defining all four core
Verification Tier values as concrete Lean verification actions, with `full` identified as the
sole phase-end-gating tier and the standing cross-cutting surface named once.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
      immediately before editing (concurrent siblings are live on this tree this cycle). *(completed)*
- [x] Add a new section titled `## Verification Tiers in Lean Terms`, sited directly before
      `## Stage 4: Execute Proof Development Loop` so Stage 4B/4C can point back at it. Apply the
      section-anchoring rule already stated after Stage 4A's marker code fence: anchor both ends
      on heading-marker lines and search the end anchor forward from the start line. *(completed)*
- [x] Open the section by stating the gating rule the rest of it is conditioned on: for Lean,
      `full` is the only tier that ever discharges a phase's close or commit. The cheaper three
      describe how broadly verification runs *during* a phase — core's own "Non-negotiable
      invariant" framing — and never substitute for the phase-end full build. Cite Stage 4C as the
      authority for that gate rather than restating its rationale. *(completed)*
- [x] Name the standing cross-cutting surface once, in one sentence a lean plan's
      `**Tier Justification**:` line can point at verbatim: *the project-wide Lean declaration
      namespace — any new or renamed declaration can collide with an identically named one
      anywhere else in the library, invisible to any module-scoped build.* *(completed)*
- [x] Write the four-row mapping, each row labelled gating or non-gating inline:
      - `prose` (non-gating) — edits confined to comments, docstrings, or prose inside a `.lean`
        or lean-adjacent `.md` file with zero elaboration surface. In-phase check: diff
        read-through per core's own `prose` row.
      - `local` (non-gating) — a proof or definition confined to one module with no externally
        visible signature change. In-phase check: `lean_goal` + `lean_verify` per step, already
        mandated by Stage 4B item 5; optionally one scoped `lake build Module.Name` as the
        existing explicitly non-gating interim sanity check.
      - `interface` (non-gating) — a declaration's name, type, arity, or argument order changes
        with call sites spanning modules. In-phase check: scoped
        `lake build Module.A Module.B ...` over the changed module plus its enumerated direct
        dependents, still explicitly non-gating.
      - `full` (the sole gating tier) — the whole-project `lake build`, plus whichever
        `check-module-invariants.sh` checks require a completed build as opposed to a pure
        source-text scan, plus the `.olean`-newer-than-source check per touched module. Cite
        `long-builds.md`'s "Reading the build's verdict" item 3 by that existing name. *(completed)*
- [x] Add a closing note recording the authority for a domain defining its own per-tier actions:
      `suite_selection_select` carries no `.lean` mappings, so core's shell-suite narrowing
      returns `__FULL_SWEEP__` for any Lean-only phase; `plan-format.md`'s "Unmappable criterion"
      paragraph sanctions the implementer running the named check directly and recording that
      direct run as the scoped discharge. State that this mapping introduces no fifth tier and
      renames no core tier value. *(completed)*
- [x] Add a one-line pointer from Stage 4C back to the new section, without moving or rewording
      any of Stage 4C's existing gating text. *(completed)*
- [x] Confirm the section restates no invocation mechanism: no mention of `run_in_background`, no
      `lake-build-guard.sh` call shape, no bounded-wait idiom — defer to `long-builds.md`'s
      preference order by reference, as Stage 4C already does. *(completed)*

**Timing**: 50 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase touches exactly one file and adds one new section plus one
one-line pointer inside an existing stage, with no edit to any existing Stage 4C gating sentence.
The implementer confirms this by diffing the file after the edit and verifying the only changed
regions are the inserted section and the single added Stage 4C pointer line.

**Tier Justification**: `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint, run from the repository root, which holds both a deployed `.claude/` tree
and the `agent-system/extensions` source store) is the honest covering check for a single
source-store non-`specs/**` markdown edit, per `plan-format.md`'s `__FULL_SWEEP__` sub-case (b) —
`suite_selection_select` was run over this phase's path and returned `__FULL_SWEEP__`, so no test
suite covers it.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` - add the `## Verification Tiers in Lean Terms` section; add one pointer line in Stage 4C

**Verification**:
- `grep -c 'Verification Tiers in Lean Terms'` over the file returns 1.
- All four tier values `prose`, `local`, `interface`, `full` appear in the new section, each
  explicitly marked gating or non-gating.
- `grep -n 'run_in_background\|lake-build-guard.sh'` over the new section returns no hits.
- `git diff` on the file shows no change to any line inside Stage 4C's existing gating bullets
  other than the single added pointer line.
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` reports no finding naming this file
  (findings naming other, untouched files are the tree's standing baseline, per
  `plan-authoring-gate-collisions.md` Condition 2's corollary).

---

### Phase 2: Point the Implementation Agent at the Mapping [COMPLETED]

**Goal**: `lean-implementation-agent.md` references the new section as the authority for Lean
tier meanings, restates none of it, and contradicts none of it.

**Tasks**:
- [x] Re-read `agent-system/extensions/lean/agents/lean-implementation-agent.md` immediately
      before editing. *(completed)*
- [x] Add one `Context References` entry for the new section, written in the same shape as the
      existing `long-builds.md` entry (`@.claude/context/project/lean4/agents/lean-implementation-flow.md`
      is already the deploy-path form that file's siblings use), describing it as the authority
      for what each core Verification Tier value means in Lean terms. *(completed)*
- [x] Add a single pointer sentence in the Phase Checkpoint Protocol, attached to item 3, saying
      that the tier-to-action mapping lives in the flow document's
      `## Verification Tiers in Lean Terms` section — without restating any tier's actions and
      without altering item 3's existing full-build gating language. *(completed)*
- [x] Run the contradiction check: re-read the new Phase 1 section alongside this agent file's
      Phase Checkpoint Protocol item 3, MUST DO items 7 and 8, and MUST NOT items 3 and 13, and
      confirm each of the five says the same thing the mapping says. Any divergence is resolved in
      favour of the already-landed text (which carries task 396's settlement); the mapping is
      corrected, never the gating contract. *(completed)*
- [x] Confirm no restatement crept in: the agent file gains a reference and a pointer sentence,
      not a copy of the four-row table.
 *(completed)*
**Timing**: 35 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: exactly ONE agent file requires this edit, not two. The second file the
dispatch description implies, `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`,
was deleted 2026-11-09 and hard-mode contracts are now injected into the same agent at dispatch
time. The implementer confirms this before editing by listing
`agent-system/extensions/lean/agents/` and verifying only `lean-implementation-agent.md` and
`lean-research-agent.md` are present; if a hard-agent file has reappeared since this plan was
written, it gets the identical pointer edit and is added to this phase's staged file list.

**Tier Justification**: `bash .claude/scripts/tests/run-all.sh --only test-lean-plan-compliance-check.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-resume-scan-nonconformance.sh`
covers this phase's edit — `suite_selection_select` was run over this phase's path and returned
exactly those five suites (an agent-definition file, unlike Phase 1's context file, has real
agent-contract lint coverage and does **not** return the `__FULL_SWEEP__` sentinel).

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - add one Context References entry and one pointer sentence on Phase Checkpoint Protocol item 3

**Verification**:
- The file contains exactly one reference to `Verification Tiers in Lean Terms` in Context
  References and exactly one in the Phase Checkpoint Protocol; `grep -c` returns 2 overall.
- `git diff` shows no change to the substantive text of MUST DO items 7-8 or MUST NOT items 3
  and 13.
- The contradiction check is recorded in the phase's commit body or handoff: all five gating
  sites named above re-read and found consistent with the Phase 1 mapping.
- `bash .claude/scripts/tests/run-all.sh --only test-lean-plan-compliance-check.sh,test-lint-agent-contracts-await-notification.sh,test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-resume-scan-nonconformance.sh`
  exits 0 (the invoked command's exit status, not a stdout diff against a baseline).
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` reports no finding naming this file.

---

### Phase 3: Redeploy and Verify the Preserved Obligations [COMPLETED]

**Goal**: The deployed tree carries both edits, the full gate set is green for this task's own
files, and the detachment / guard / bounded-wait obligations are demonstrably unchanged.

**Tasks**:
- [x] Verify the three preserved obligations are byte-identical to their pre-change state by
      diffing against this task's base commit: `long-builds.md`'s Obligation 1 (detach), Obligation
      2 (guard), "Scoped builds are covered too", and "Completion discipline"; and
      `context/project/lean4/operations/external-process-wait` guidance. Any non-empty diff on
      those files is a defect in Phases 1-2, not an expected result — fix forward before
      proceeding. *(completed: `git diff` against the base commit on both `long-builds.md` and
      core's `external-process-wait.md` is empty)*
- [x] Confirm `lake-build-guard.sh` and `agent-system/extensions/core/context/formats/plan-format.md`
      are untouched (`git diff --name-only` against the base commit lists neither). *(completed)*
- [x] Run `timeout 540 bash .claude/scripts/deploy-headless.sh` to regenerate the deployed
      `.claude/` tree from the source store, and confirm it exits 0. *(deviation: altered — the
      deploy landed (RESULT=landed_verify_red) but the invocation itself exited 3, not 0: its
      internal fast-gate verification found two pre-existing, unrelated FAILs (specs/state.json
      `next_project_number` counter drift; the orchestrator eager-context-budget ceiling, driven
      by pre-existing uncommitted changes to `agent-system/extensions/lean/EXTENSION.md` and two
      other lean context files that were already dirty before this dispatch started and that this
      task never touches). Both findings are demonstrably pre-existing and name no file this task
      touched; the deploy itself (file placement) succeeded)*
- [x] Confirm both edits are present in the deployed tree
      (`.claude/context/project/lean4/agents/lean-implementation-flow.md` and
      `.claude/agents/lean-implementation-agent.md`), which proves the source-store edit target was
      correct and nothing was hand-authored under `.claude/**`. *(completed)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`. Distinguish findings
      naming this task's own two files from the tree's standing baseline, per
      `plan-authoring-gate-collisions.md` Condition 2's corollary — a bare "the gate passes" claim
      conflates the two and is not acceptable here. *(deviation: altered — this dispatch's own
      `.dispatch/11.md` carries a Batch Gate Deferral directive for this exact phase: the complete
      gate set is deferred to the once-per-batch stage rather than independently invoked here, in
      favour of the scoped discharge `bash .claude/scripts/verify-deploy.sh --only-gate 3,4`, which
      is green (PASS -- 3 check(s), 0 failure(s)) for both edited files. The complete gate DID
      still run once, as an internal side effect of `deploy-headless.sh`'s own fast-gate
      verification above, and its two FAILs are the same pre-existing, unrelated findings
      recorded on that task item — neither names either file this task edited)*
- [x] Run the two deliverable-content lints explicitly over the two edited files:
      `bash .claude/scripts/check-task-references.sh` (no task-number citations outside `specs/**`)
      and the record-version check from `scripts/lib/record-version-patterns.sh`'s consumers (no
      draft-lineage language). *(completed: `check-task-references.sh` reports no finding for
      either file; `check-record-versioning.sh agent-system/extensions/lean` reports 0 BLOCKING
      findings for either file — one pre-existing, unrelated ADVISORY hit on
      `lean-implementation-flow.md` line 40, inside the untouched Stage 1.5 section)*
- [x] Confirm `plan-file-scope-harvest.sh` rebuilt `file_scope` from this plan without the deleted
      `lean-implementation-hard-agent.md` path, and record the accepted `index-entries.json`
      `line_count` drift (remedy: repo-wide `generate-context-line-counts.sh --write`, deferred
      because task 397 holds that file concurrently). *(deviation: altered — `index-entries.json`
      line_count drift was auto-repaired by `deploy-headless.sh`'s own line_count auto-repair
      mechanism, not left accepted-and-deferred as the plan anticipated, so no further remedy is
      needed there. The `lean-implementation-hard-agent.md` path, however, was NOT dropped from
      `file_scope` — it is still present in `specs/state.json`'s entry for this task alongside
      `__WHOLE_TREE__` and both edited files. This was not hand-corrected here (hand-editing
      `file_scope` is prohibited); recorded as a non-blocking issue via `issue-record.sh` for a
      follow-up to the harvester)*

**Timing**: 35 minutes

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: this phase modifies no source file of its own; its only write is the
whole-deployed-tree regeneration, declared below with the reserved sentinel. The implementer
confirms this by checking that `git status --short` shows no modification under
`agent-system/` attributable to this phase beyond what Phases 1-2 already committed.

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes `deploy-headless.sh`, regenerating the entire deployed `.claude/` tree, which is an implicit scope claim over that whole tree

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` exits 0.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set, not a subset) is green, or every
  red finding is demonstrably pre-existing and names no file this task touched.
- `git diff --name-only` against the task's base commit lists exactly the two source-store files
  from Phases 1-2 and nothing else under `agent-system/`; in particular it lists neither
  `lake-build-guard.sh` nor `plan-format.md`.
- `git diff` over `long-builds.md` and the `external-process-wait` guidance is empty.
- `bash .claude/scripts/check-task-references.sh` reports no finding for either edited file.
- The record-version lint reports no finding for either edited file.
- The deployed copies of both edited files contain the new section and the new pointers.

---

## Testing & Validation

- [ ] The `## Verification Tiers in Lean Terms` section exists exactly once in
      `lean-implementation-flow.md` and defines all four core tier values.
- [ ] `full` is stated as the sole phase-end-gating tier for Lean; `prose`, `local`, and
      `interface` are each explicitly marked non-gating.
- [ ] The standing cross-cutting surface (the project-wide Lean declaration namespace) is stated
      once and is quotable by a lean plan's `**Tier Justification**:` line.
- [ ] `lean-implementation-agent.md` points at the section and restates none of it; its five
      existing gating sites are unchanged and consistent with it.
- [ ] No fifth tier was introduced and no core tier value was renamed.
- [ ] `check-module-invariants.sh`'s build-dependent checks are described functionally, with no
      asserted flag name.
- [ ] The `.olean`-newer-than-source check is cited by its existing `long-builds.md` name, as a
      covering check within `full`, not as a separate tier.
- [ ] Detachment, build-guard, and bounded-wait obligations are byte-identical to their
      pre-change state.
- [ ] `lake-build-guard.sh`, `plan-format.md`, and every `.claude/**` path are untouched by hand.
- [ ] No task-number references and no record-versioning language in any file landing under
      `agent-system/`.

## Artifacts & Outputs

- A new `## Verification Tiers in Lean Terms` section in
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`, plus
  one pointer line in its Stage 4C.
- One Context References entry and one Phase Checkpoint Protocol pointer sentence in
  `agent-system/extensions/lean/agents/lean-implementation-agent.md`.
- A regenerated deployed `.claude/` tree carrying both.
- An implementation summary at
  `specs/412_lean_tier_vocabulary_to_build_scope_mapping/summaries/01_tier-vocabulary-build-scope-mapping-summary.md`.
- A corrected `file_scope` in `specs/state.json`, produced mechanically by
  `plan-file-scope-harvest.sh` from this plan's `Files to modify` blocks.

## Rollback/Contingency

Each phase commits independently, so rollback is per-phase and granular. Before any intentional
rollback, take a checkpoint with `bash .claude/scripts/git-snapshot.sh 412 --no-revert` — never
the default reverting form, because concurrent siblings are live on this working tree this cycle
and a repo-global revert would discard their work.

- **Phase 1 or 2 rejected on review**: revert that phase's single-file commit. Both files return
  to a self-consistent prior state; no other file depends on the new section's existence.
- **Phase 3's full gate goes red on a file this task touched**: do not revert the source-store
  edits; fix forward per `.claude/context/contracts/recovery.md` and re-run the gate, since a
  partial deploy tree is a worse state than either endpoint.
- **A contradiction surfaces in Phase 2 between the mapping and an already-landed gating site**:
  the gating site wins — it carries task 396's settlement, which this task is forbidden to
  relitigate. Correct the Phase 1 mapping and re-run Phase 1's verification before proceeding.
