# Implementation Plan: Align Lifecycle Agent Handoff Contracts

- **Task**: 194 - Align lifecycle agent handoff contracts
- **Status**: [COMPLETED]
- **Effort**: 9 hours
- **Dependencies**: None
- **Research Inputs**: specs/194_align_lifecycle_agent_handoff_contracts/reports/01_handoff-obligation-audit.md
- **Artifacts**: plans/01_handoff-obligation-contract-rollout.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Every agent reachable via an `/orchestrate` `dispatch[]` row reaches `orchestrate-cycle-postflight.sh`,
where an absent `.orchestrator-handoff.json` is about to become a real `HANDOFF_STALE_OR_ABSENT`
defect signal (companion task, disjoint file scope). Today only 2 of the 64 reachable agents state
the handoff-writing obligation; 56 are silent on it and 6 state the explicit *opposite*. This plan
freezes one canonical obligation block in core, then rolls it out across the remaining 61 agent
contract files under `agent-system/extensions/*/agents/` — reversing the 6 prohibition statements
rather than appending contradictory text beside them. Done means: all 64 reachable agents carry a
consistently-worded obligation naming `.orchestrator-handoff.json` and its `handoff_path` source,
the aux-dispatch asymmetry still holds structurally, and the enumerated reachable set plus its
derivation method is recorded for re-verification.

### Research Integration

The research report supplies the load-bearing inputs this plan is built on:

- **The reachable set is 64 agents, not 6.** Derived mechanically from every
  `agent-system/extensions/*/manifest.json`'s `.routing_agents{,_hard}.{research,plan,implement}`
  values; `dispatch[]`'s phase vocabulary is fixed at exactly those three keys. Independently
  re-derived at plan time with the report's own command and reproduced **exactly** (64 names, same
  per-extension distribution, same mention counts).
- **The edit set splits three ways**, and this split drives the phase structure: 56 zero-count
  agents (pure additive edit), 6 prohibition agents (reversal — additive editing here would make
  the file self-contradictory), 2 already-correct agents (verify only, no edit).
- **Exclusions are settled and must not be re-litigated**: `literature`/`slidev` (`routing_exempt`,
  no `routing_agents` block), `present`'s `critique` phase and `slide-critic-agent` (not a
  `dispatch[]` phase), second-level router sub-agents `document-agent`/`spreadsheet-agent`/
  `pptx-assembly-agent` (never receive `orchestrator_mode`), and `reviser-agent`
  (`aux_dispatch[]`-only).
- **Nine implementation agents already say "handoff"** about the unrelated context-pressure
  mechanism (`specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`). Placement must keep
  the two file types visibly distinct — this is why Phase 6 is scoped as its own phase.

### Plan-Time Addition to the Research Findings

A fact not in the report, established at plan time by reading
`orchestrate-cycle-plan.sh`'s `aux_fixed_agent()`: the `divergence-audit` aux kind resolves its
agent to `research_agents[$t]` (default `general-research-agent`) — i.e. an agent that **is** in the
`dispatch[]`-reachable set can also be aux-dispatched. The aux row is emitted with
`orchestrator_mode: false` and no `handoff_path` key. This settles how the plan honors the
dispatch's two apparently-competing instructions ("do not restate the aux-dispatch exemption" vs.
"the exemption remains intact and is stated where relevant"): the canonical block's **trigger
condition is the exemption**. Conditioning the obligation on `orchestrator_mode: true` exempts every
aux dispatch structurally, so no file restates the aux contract, and the exemption is nonetheless
stated exactly where it can bite.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the dispatch context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- One canonical, three-variant (research / plan / implement) obligation block, authored once in
  core and copied verbatim-modulo-variant everywhere else.
- All 61 non-compliant reachable agents carry it: 55 by addition, 6 by reversal of existing
  prohibition text.
- The 2 already-correct agents are confirmed unchanged and remain the wording reference.
- The enumerated reachable set and its derivation command are recorded in the implementation
  summary so completeness is re-verifiable without re-deriving it.
- The aux-dispatch asymmetry survives, carried by the obligation's trigger condition.

**Non-Goals**:
- Any edit to `orchestrate-cycle-postflight.sh` or `is_contractual_handoff_writer()` — companion
  task's territory, deliberately disjoint.
- Updating `docs/architecture/handoff-schema.md`'s "Handoff Writers" table / D1 allowlist, which
  this task's landing makes stale. Outside this task's file scope
  (`agent-system/extensions/*/agents/**`); recorded as a follow-up in Phase 7.
- Any edit under `.claude/**` — disposable deploy tree, regenerated from the source store.
- Adding the obligation to excluded agents (`reviser-agent`, `slide-critic-agent`,
  `document-agent`, `spreadsheet-agent`, `pptx-assembly-agent`, literature/slidev agents).
- Changing the handoff JSON schema itself, or `orchestrate-cycle-plan.sh`'s aux emission.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A prohibition agent receives an additive edit, leaving the file self-contradictory ("MUST write" next to "MUST NOT write") | H | M | Phases 1-2 handle all 6 prohibition files exclusively and run before/parallel-to the additive phases; Phase 7 greps every reachable file for surviving `MUST NOT write`/`non-writer by design` text |
| New obligation conflated with the unrelated `handoffs/phase-{P}-handoff-{TIMESTAMP}.md` mechanism | M | H | Phase 6 isolates the 9 agents carrying that text; the canonical block's heading names `.orchestrator-handoff.json` literally and the block states the distinction in one clause |
| Wording drifts across 61 files, defeating "consistently worded" | M | H | Block frozen verbatim in the Appendix and in Phase 1's three core files; later phases copy, never re-author; Phase 7 diffs each inserted block against the frozen text |
| Aux-dispatched `general-research-agent` (divergence-audit) starts writing a handoff it was never asked for | M | M | Obligation conditioned on `orchestrator_mode: true` plus an explicit negative clause; verified in Phase 1 against `aux_fixed_agent()`'s emitted row shape |
| A task number leaks into an agent contract (rules violation) | M | L | Canonical block contains no task reference; Phase 7 runs `check-task-references.sh` |
| `.claude/**` edited instead of the source store, silently wiped on next deploy | H | L | Every phase's file list is rooted at `agent-system/extensions/`; Phase 7 asserts `git status` shows no `.claude/**` modifications |
| Counted 56/6/2 split proves wrong mid-implementation | M | L | Each phase carries a Scope Hypothesis with the re-derivation command; a mismatch is reported, not silently absorbed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6 | 1 |
| 3 | 7 | 2, 3, 4, 5, 6 |

Phases within the same wave can execute in parallel. Phases 2-6 own disjoint file sets (see each
phase's **Files to modify**) and may be dispatched in parallel under territory contracts.

---

### Phase 1: Freeze the Canonical Block and Land It in Core [COMPLETED]

**Goal**: Author the three canonical variants (research / plan / implement) once, and apply them to
the three core agents — two of which are prohibition reversals and one of which is a pure addition.
After this phase the exact text every later phase copies exists in-tree.

**Tasks**:
- [x] Re-read the wording reference: `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
      Stage 5 Step 1 (the `handoff_path` resolution paragraph, the "NEVER write a bare
      `.orchestrator-handoff.json` filename" rule, and the `dispatch_seq` echo paragraph) and the
      near-identical block in `cslib-implementation-hard-agent.md`.
- [x] Confirm the frozen text in this plan's `## Appendix: Canonical Obligation Block` still matches
      those references; if the references have drifted, update the Appendix first and note it.
- [x] `general-research-agent.md`: **reverse** the prohibition. *(completed)* Replace the "Do NOT use
      `wrap-up.md`'s H9 schema or `.orchestrator-handoff.json` for research — that schema and its
      consumer allowlist are implementation-agent-only" sentence with the research variant of the
      canonical block. Promote the existing "Defensive case, if this scoping decision is ever
      reversed" paragraph from hypothetical framing to normal-path text (its `dispatch_seq` and
      `artifacts[]` object-shape content is correct and is retained, not deleted). Leave the Option
      A / Option B context-exhaustion scoping discussion otherwise intact — it concerns the
      *other* handoff file.
- [x] `general-implementation-agent.md`: **reverse** the prohibition. *(completed)* Rewrite the
      "### `.orchestrator-handoff.json` (base-mode implement is a non-writer by design)" section
      into the implement variant of the canonical block, keeping its correct
      `phases_completed`/`phases_total` sourcing rule (the real integers from Stage 5a's
      marker-repair pass, never fabricated, never `null`, top level) as normal-path text. Remove the
      "Never writes a handoff, by design" claim and the "A `handoff_path` field ... is never an
      instruction for this agent to write one" sentence.
- [x] `planner-agent.md`: **add** the plan variant of the canonical block *(completed)* as a new subsection
      immediately after Stage 6's metadata-file contract and before Stage 7.
- [x] Verify none of the three files still asserts a non-writer status: *(confirmed: 0 matches)*
      `grep -n "non-writer\|MUST NOT write\|never write" ` on each.
- [x] Commit each file as its own green sub-step. *(3 commits: 5e80a468f, 343d26564, 1bd188129)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly 3 core files are in scope and exactly 2 of them carry prohibition
text. Confirm before editing with
`grep -c orchestrator-handoff.json agent-system/extensions/core/agents/{general-research-agent,general-implementation-agent,planner-agent}.md`
— expected `2`, `5`, `0` respectively. Report any deviation instead of absorbing it.

**Files to modify**:
- `agent-system/extensions/core/agents/general-research-agent.md` - prohibition reversed to research-variant obligation
- `agent-system/extensions/core/agents/general-implementation-agent.md` - prohibition section rewritten to implement-variant obligation
- `agent-system/extensions/core/agents/planner-agent.md` - plan-variant obligation added

**Verification**:
- Each of the 3 files contains the canonical block, byte-identical to the Appendix modulo the
  variant-specific status enum and phase-count sentence.
- `grep -i "non-writer by design\|MUST NOT write .orchestrator-handoff" ` returns nothing in all 3.
- Read each file end to end once: no surviving sentence contradicts the new obligation.
- Every cross-referenced path in the inserted block resolves:
  `context/contracts/wrap-up.md`, `context/patterns/dispatch-report-not-termination.md`,
  `context/schemas/orchestrator-handoff-schema.json`, `docs/architecture/handoff-schema.md`.

---

### Phase 2: Reverse the Four Remaining Prohibition Contracts [COMPLETED]

**Goal**: Apply the same reversal treatment to the 4 non-core agents whose contracts currently state
the opposite of the new obligation, and confirm the 2 already-correct agents need no edit.

**Tasks**:
- [x] `cslib-implementation-agent.md`: rewrite the "`.orchestrator-handoff.json` prohibition"
      paragraph into the implement variant; rewrite the numbered MUST-NOT checklist item ("Write
      .orchestrator-handoff.json -- base-mode implementation never writes a handoff") into a MUST-DO
      or delete it from the MUST NOT list and add the obligation to the MUST DO list.
- [x] `cslib-research-agent.md`: same treatment, research variant, including its MUST-NOT checklist
      item. *(completed)*
- [x] `lean-research-agent.md`: rewrite the "(research is a non-writer by design)" subsection into
      the research variant.
- [x] `lean-research-hard-agent.md`: same treatment, research variant. *(completed)*
- [x] Verify-only (no edit): confirm `cslib-implementation-hard-agent.md` and
      `lean-implementation-hard-agent.md` still carry their existing correct obligation and were not
      touched — `git diff --stat` must show them absent.
- [x] Commit each edited file as its own green sub-step. *(4 commits: cf8866461, 5eb3ff1af, ef647b097, cdbd1c453)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly 4 files need reversal here and exactly 2 need no edit. Confirm with
`grep -n "non-writer by design\|prohibition\|MUST NOT write" ` across the 6 nonzero-count non-core
agents before editing. If a fifth prohibition surfaces, report it rather than silently widening.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` - prohibition + checklist item reversed
- `agent-system/extensions/cslib/agents/cslib-research-agent.md` - prohibition + checklist item reversed
- `agent-system/extensions/lean/agents/lean-research-agent.md` - non-writer subsection reversed
- `agent-system/extensions/lean/agents/lean-research-hard-agent.md` - non-writer subsection reversed

**Verification**:
- All 4 files contain the canonical block; none contains surviving prohibition language, in prose
  *or* in a MUST-NOT checklist.
- `git diff --stat` for this phase lists exactly 4 files; the 2 hard-mode agents are absent.
- Read each of the 4 files end to end: no surviving contradiction.

---

### Phase 3: Founder Extension Rollout (15 agents) [COMPLETED]

**Goal**: Add the canonical block to every zero-count `founder` agent, using the variant matching the
`routing_agents` phase key that reaches it.

**Tasks**:
- [x] For each file below, determine its dispatch phase from
      `agent-system/extensions/founder/manifest.json`'s `routing_agents` block (research / plan /
      implement) and select the matching canonical variant.
- [x] Insert the block as a `###` subsection adjacent to the agent's existing return-metadata /
      wrap-up stage, following Phase 1's placement precedent. *(completed: all 15 founder agents)*
- [x] Commit per file (or in small same-variant groups where files are near-identical clones), each
      as a green sub-step. *(15 commits)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 15 founder agents are reachable and all 15 have mention count 0. Confirm with
the report's per-agent count command scoped to `agent-system/extensions/founder/agents/`.

**Files to modify** (all under `agent-system/extensions/founder/agents/`, canonical block added):
- `analyze-agent.md`, `deck-builder-agent.md`, `deck-planner-agent.md`, `deck-research-agent.md`,
  `finance-agent.md`, `financial-analysis-agent.md`, `founder-implement-agent.md`,
  `founder-plan-agent.md`, `founder-spreadsheet-agent.md`, `legal-analysis-agent.md`,
  `legal-council-agent.md`, `market-agent.md`, `meeting-agent.md`, `project-agent.md`,
  `strategy-agent.md`

**Verification**:
- `grep -c orchestrator-handoff.json` returns a nonzero count for all 15.
- Each inserted block's variant matches the agent's manifest phase key.
- Diff read-through: every changed hunk is a whole inserted subsection; no pre-existing line altered.

---

### Phase 4: Present and Filetypes Rollout (13 agents) [COMPLETED]

**Goal**: Add the canonical block to every zero-count `present` and `filetypes` agent, including the
two router agents that themselves sub-dispatch.

**Tasks**:
- [x] Resolve each agent's phase variant from the `present` / `filetypes` manifests' `routing_agents`
      blocks. `present`'s `critique` key is **not** a `dispatch[]` phase — `slide-critic-agent` stays
      out of scope and must not be edited. *(confirmed: slide-critic-agent untouched)*
- [x] Insert the matching canonical variant per file. *(completed)*
- [x] For `filetypes-router-agent.md` and `presentation-agent.md`, add one sentence clarifying that
      the obligation is the router's own, and that its second-level sub-dispatches
      (`document-agent`, `spreadsheet-agent`, `pptx-assembly-agent`) receive no `orchestrator_mode`
      and write no handoff.
- [x] Commit per file as a green sub-step. *(13 commits)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 7 `present` + 6 `filetypes` = 13 reachable zero-count agents, with
`slide-critic-agent` and the three second-level sub-agents excluded. Confirm against both manifests
before editing.

**Files to modify**:
- `agent-system/extensions/present/agents/`: `budget-agent.md`, `funds-agent.md`, `grant-agent.md`,
  `slide-planner-agent.md`, `slides-research-agent.md`, `slidev-assembly-agent.md`,
  `timeline-agent.md`
- `agent-system/extensions/filetypes/agents/`: `docx-edit-agent.md`, `filetypes-router-agent.md`,
  `filetypes-spreadsheet-agent.md`, `presentation-agent.md`, `scrape-agent.md`, `sheet-agent.md`

**Verification**:
- All 13 files carry a nonzero mention count; `slide-critic-agent.md`, `document-agent.md`,
  `spreadsheet-agent.md`, `pptx-assembly-agent.md` remain at 0 and are absent from `git diff --stat`.
- The two router files state the sub-dispatch clarification.

---

### Phase 5: Formal, CSLib, Epidemiology, Email, Lean Rollout (11 agents) [COMPLETED]

**Goal**: Add the canonical block to the remaining zero-count agents in the `formal`, `cslib`,
`epidemiology`, `email`, and `lean` extensions.

**Tasks**:
- [x] Resolve each agent's phase variant from its extension manifest, including `cslib`'s
      `routing_agents_hard` block for `cslib-research-hard-agent`.
- [x] Insert the matching canonical variant per file. *(completed)*
- [x] `lean-implementation-agent.md` carries the unrelated context-pressure handoff mechanism —
      place the new subsection so the two file types are visibly distinct (same treatment Phase 6
      applies at scale). *(disambiguation clause appended)*
- [x] `email-implementation-agent.md` is wrapper-only; the block adds no wrapper calls and must not
      disturb the safety-invariant sections. *(placed after Stage 5, before Critical Requirements)*
- [x] Commit per file as a green sub-step. *(11 commits)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 4 `formal` + 3 `cslib` + 2 `epidemiology` + 1 `email` + 1 `lean` = 11
zero-count agents. Confirm with the per-extension count command before editing.

**Files to modify**:
- `agent-system/extensions/formal/agents/`: `formal-research-agent.md`, `logic-research-agent.md`,
  `math-research-agent.md`, `physics-research-agent.md`
- `agent-system/extensions/cslib/agents/`: `cslib-research-hard-agent.md`,
  `pr-review-implementation-agent.md`, `pr-review-research-agent.md`
- `agent-system/extensions/epidemiology/agents/`: `epi-implement-agent.md`, `epi-research-agent.md`
- `agent-system/extensions/email/agents/email-implementation-agent.md`
- `agent-system/extensions/lean/agents/lean-implementation-agent.md`

**Verification**:
- All 11 files carry a nonzero mention count with the correct variant.
- `lean-implementation-agent.md`: both handoff mechanisms are present and unambiguous on a
  read-through of the surrounding section.

---

### Phase 6: Language-Toolchain Extensions Rollout (16 agents) [COMPLETED]

**Goal**: Add the canonical block to the `latex`, `nvim`, `nix`, `python`, `rust`, `typst`, `web`,
and `z3` agents — the cluster where the pre-existing context-pressure handoff text makes
disambiguation the main risk.

**Tasks**:
- [x] For each implementation agent, locate the existing context-pressure handoff section (typically
      "Stage 4E. Handoff on Context Pressure" or equivalent) referencing
      `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`. *(confirmed present in all 8)*
- [x] Place the new `.orchestrator-handoff.json` subsection so it does not read as an amendment to
      that section, and include the one-clause distinction: a different file, a different consumer,
      and both may be written in the same dispatch. *(disambiguation clause appended to all 8
      implementation agents)*
- [x] Insert the research variant into each research agent. *(completed)*
- [x] Commit per file as a green sub-step. *(16 commits)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 16 agents (2 per extension across 8 extensions), of which the implementation
agents carry pre-existing `handoff` text. Confirm the pre-existing-text subset with
`grep -il handoff` across the 16 before editing; the report predicts 8 of them here plus
`lean-implementation-agent` in Phase 5.

**Files to modify**:
- `agent-system/extensions/latex/agents/`: `latex-implementation-agent.md`, `latex-research-agent.md`
- `agent-system/extensions/nvim/agents/`: `neovim-implementation-agent.md`, `neovim-research-agent.md`
- `agent-system/extensions/nix/agents/`: `nix-implementation-agent.md`, `nix-research-agent.md`
- `agent-system/extensions/python/agents/`: `python-implementation-agent.md`, `python-research-agent.md`
- `agent-system/extensions/rust/agents/`: `rust-implementation-agent.md`, `rust-research-agent.md`
- `agent-system/extensions/typst/agents/`: `typst-implementation-agent.md`, `typst-research-agent.md`
- `agent-system/extensions/web/agents/`: `web-implementation-agent.md`, `web-research-agent.md`
- `agent-system/extensions/z3/agents/`: `z3-implementation-agent.md`, `z3-research-agent.md`

**Verification**:
- All 16 files carry a nonzero `.orchestrator-handoff.json` mention count.
- In every file that also mentions the phase-handoff mechanism, a reader can tell the two apart from
  the inserted text alone.

---

### Phase 7: Completeness Sweep and Record [COMPLETED]

**Goal**: Prove coverage across the full reachable set, prove the MUST NOTs held, and record the
enumerated set plus derivation method so a future reader can re-verify without re-deriving.

**Tasks**:
- [x] Re-run the reachable-set derivation from the manifests (command in the Appendix) and confirm
      it still yields 64 names; report any change. *(confirmed: 64, no change)*
- [x] Assert every one of the 64 has a nonzero `.orchestrator-handoff.json` mention count. *(confirmed: 0 zero-count)*
- [x] Assert no reachable agent retains prohibition language:
      `grep -rn "non-writer by design\|MUST NOT write .orchestrator-handoff\|never writes a handoff"`
      across `agent-system/extensions/*/agents/` returns nothing for reachable agents. *(confirmed clean)*
- [x] Assert wording consistency: for each of the 61 edited files, diff the inserted block against
      the Appendix text; only the variant-specific status enum and phase-count sentence may differ.
      *(confirmed: all 62 edited files — see deviation note on the 61 vs. 62 count below — contain
      the frozen core+mid sentences byte-identical modulo variant)*
- [x] Assert the aux-dispatch asymmetry: every inserted block is conditioned on
      `orchestrator_mode: true` and none restates the `aux_dispatch[]` contract. *(confirmed: all 62
      edited files condition on `orchestrator_mode: true`; the 2 untouched hard-mode agents predate
      this task and were out of scope; zero files restate the `aux_dispatch[]` contract)*
- [x] Assert MUST NOTs: `git diff --stat` for the whole task shows no change to
      `orchestrate-cycle-postflight.sh`, no change under `.claude/**`, and no change to the 2
      already-correct hard-mode agents. *(confirmed: all three assertions pass, zero-diff)*
- [x] Run `bash .claude/scripts/check-task-references.sh` (or the repo's current equivalent) and
      confirm no task-number reference was introduced into any agent contract. *(PASS: 0 unexempted
      occurrences across all 4 scanned trees)*
- [x] Write the implementation summary recording: the 64-name enumerated set, the exact derivation
      command, the 55/6/3 edit breakdown as actually applied, and the follow-up need to update
      `docs/architecture/handoff-schema.md`'s "Handoff Writers" table, D1 allowlist, and its
      "Open question, not decided here" paragraph — all now stale and outside this task's file scope.
      *(written; actual breakdown reconciled to 56/6/2 — see summary for the deviation explanation)*
- [x] Note in the summary that the obligation takes runtime effect only after the source store is
      redeployed to `.claude/` by the sanctioned deploy process, which is the user's step. *(noted)*

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4, 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 64 reachable agents, 61 edited (55 additive + 6 reversals) and 3 untouched
(2 already correct; `planner-agent` is counted as edited in Phase 1). The sweep itself is the
confirmation — a mismatch against these numbers is reported in the summary, never quietly adjusted.

**Files to modify**:
- `specs/194_align_lifecycle_agent_handoff_contracts/summaries/01_handoff-obligation-contract-rollout-summary.md` - created

**Verification**:
- All seven assertions above pass, each with its command output recorded in the summary.
- The summary's enumerated set matches the plan-time set exactly, or the delta is explained.

---

## Testing & Validation

- [ ] Reachable-set derivation reproduces 64 names from the manifests.
- [ ] All 64 reachable agents have a nonzero `.orchestrator-handoff.json` mention count.
- [ ] Zero surviving prohibition / non-writer statements among reachable agents.
- [ ] Inserted blocks are textually consistent with the frozen Appendix text modulo variant.
- [ ] Every cross-reference path inside the inserted block resolves in the source store.
- [ ] `orchestrate-cycle-postflight.sh` is unmodified.
- [ ] No file under `.claude/**` is modified.
- [ ] `cslib-implementation-hard-agent.md` and `lean-implementation-hard-agent.md` are unmodified.
- [ ] `slide-critic-agent`, `reviser-agent`, `document-agent`, `spreadsheet-agent`,
      `pptx-assembly-agent` and the literature/slidev agents are unmodified.
- [ ] Task-reference lint passes on all edited files.
- [ ] `bash .claude/scripts/validate-artifact.sh` passes on this plan and on the summary.

## Artifacts & Outputs

- 61 modified agent contract files under `agent-system/extensions/*/agents/`
- `specs/194_align_lifecycle_agent_handoff_contracts/summaries/01_handoff-obligation-contract-rollout-summary.md`
- The enumerated 64-agent reachable set and its derivation command, recorded in that summary
- A recorded follow-up need: `docs/architecture/handoff-schema.md` "Handoff Writers" / D1 update

## Rollback/Contingency

All changes are additive or localized markdown edits to agent contract files, committed one file
per green sub-step. Reverting is therefore per-commit: `git revert <sha>` for the offending file's
commit, or `git revert` across the phase's commit range to undo a whole phase. No schema, script, or
state file is touched, so a revert has no migration consequence.

If a defensive checkpoint is wanted before a phase that touches many files at once (Phases 3 and 6),
take a durable, non-reverting checkpoint with
`bash .claude/scripts/git-snapshot.sh 194 --no-revert`. A genuine whole-tree rollback of uncommitted
work is a different operation with its own invocation shape — see `context/contracts/recovery.md`'s
rollback rung, including its out-of-scope override flag; do not use the bare default form as a
routine start-of-phase precaution.

Partial completion is safe and leaves no broken state: an agent that has the obligation and one that
does not both behave exactly as they do today until the companion task widens postflight's
predicate. That is precisely the ordering this task exists to guarantee.

## Appendix: Canonical Obligation Block

Frozen at Phase 1 and copied verbatim thereafter. Three variants differ only in the status enum
sentence and the phase-count sentence; everything else is identical across all 61 files.

**Placement**: a `###` subsection adjacent to the agent's existing return-metadata / wrap-up stage,
never nested inside a context-pressure-handoff section.

**Heading**: ``### `.orchestrator-handoff.json` (orchestrator-mode dispatches)``

**Body** (shared across all three variants):

> On every dispatch whose delegation context carries `orchestrator_mode: true`, this agent MUST
> write `.orchestrator-handoff.json` before returning — on success and on a `partial` or `blocked`
> outcome alike.
>
> Write to the ABSOLUTE path given in your delegation context as `handoff_path`. If that field is
> absent, use `{task_dir}/.orchestrator-handoff.json` with the absolute `task_dir` from your
> delegation context. If neither is present, STOP and say so in your final message rather than
> guessing. NEVER write a bare `.orchestrator-handoff.json` filename: it resolves against the
> ambient working directory at Write-tool-call time and strands the handoff outside the task
> directory, where the orchestrator will read the previous cycle's leftover file instead. See
> `context/contracts/wrap-up.md`, "Write location", for the full rule.
>
> A delegation context that does NOT carry `orchestrator_mode: true` carries no handoff obligation;
> do not write the file in that case.
>
> **Echo `dispatch_seq` unchanged.** If your delegation context carries a `dispatch_seq` field, copy
> its value into the handoff's own `dispatch_seq` field verbatim — never invent, increment, or
> recompute one; if it is absent, omit it from the handoff too. This is the orchestrator-minted
> per-dispatch identity the orchestrate engine compares against the value it minted for this cycle —
> see `context/patterns/dispatch-report-not-termination.md`.
>
> Use the shape defined by `context/schemas/orchestrator-handoff-schema.json` (prose companion:
> `docs/architecture/handoff-schema.md`). `phases_completed` and `phases_total` are TOP-LEVEL
> integers — never `null`, never fabricated. `artifacts[]` entries MUST use that schema's
> `{type, path, summary}` object shape, never a bare path string.

**Variant-specific sentences**:

| Variant | Status enum sentence | Phase-count sentence |
|---------|----------------------|----------------------|
| research | `status` is one of `researched`, `partial`, `blocked`. | Set `phases_completed` and `phases_total` from the task's current plan when one exists, otherwise both to `0`. |
| plan | `status` is one of `planned`, `partial`, `blocked`. | Set `phases_total` to the phase count of the plan just written and `phases_completed` to `0`. |
| implement | `status` is one of `implemented`, `partial`, `blocked`. | Set `phases_completed` and `phases_total` to the real integers derived from the plan's phase headings — never fabricated, never left at a zero-valued default. |

**For the 9 agents that also carry the context-pressure handoff mechanism**, append:

> This is a different file from the context-pressure handoff at
> `specs/{NNN}_{SLUG}/handoffs/phase-{P}-handoff-{TIMESTAMP}.md`: a different path, a different
> consumer, and a different trigger. Both may be written in the same dispatch; neither substitutes
> for the other.

**Reachable-set derivation command** (re-run in Phase 7):

```bash
for f in agent-system/extensions/*/manifest.json; do
  jq -r '[(.routing_agents.research//{}),(.routing_agents.plan//{}),(.routing_agents.implement//{}),
          (.routing_agents_hard.research//{}),(.routing_agents_hard.plan//{}),(.routing_agents_hard.implement//{})][] | .[]?' "$f"
done | sort -u
```
