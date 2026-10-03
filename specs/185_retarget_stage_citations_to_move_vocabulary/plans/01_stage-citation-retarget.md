# Implementation Plan: Task #185

- **Task**: 185 - Retarget the remaining historical "Stage N" and "Stage MT-N" citations to the four-move loop vocabulary
- **Status**: [IMPLEMENTING]
- **Effort**: 7.5 hours
- **Dependencies**: Task 88 (the four-move rewrite) is complete. Ordered behind the concurrent
  engine-editing siblings that touch `batch-orchestration-guardrails.md` and `handoff-schema.md`.
- **Research Inputs**: `specs/185_retarget_stage_citations_to_move_vocabulary/reports/01_stage-citation-survey.md`
- **Artifacts**: plans/01_stage-citation-retarget.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  rules/source-store-deploy-boundary.md, rules/no-task-references-in-deliverables.md
- **Type**: markdown
- **Lean Intent**: false

## Overview

`skill-orchestrate/SKILL.md` was rewritten from a two-engine, Stage-numbered state machine
(single-task Stages 0-8; multi-task Stages MT-1..MT-5) into a single four-move loop whose
sections are `Move 1` through `Move 4`. Eighteen files under `agent-system/extensions/core/`
still cite the deleted section names as the authority for where a live mechanism lives. This
plan retargets each live citation to the correct Move while leaving untouched (a) citations that
deliberately narrate the deleted engine's history and (b) the four other, independently numbered
"Stage N" vocabularies in this codebase that merely collide lexically with the old names. Done
means: every live citation names the correct Move, every historical one is explicitly framed as
historical, the scoped acceptance grep returns only intentional historical references, and
deploy plus the full gate run are green.

### Research Integration

The survey (`reports/01_stage-citation-survey.md`) supplies three findings this plan is built on:

1. **Five independent "Stage N" vocabularies exist.** The dispatch's naive grep
   (`Stage MT-|Stage [0-8]\b`) matches 77 files under
   `core/{context,docs,skills,commands,agents}`, but only 18 carry genuine citations of
   `skill-orchestrate`'s deleted structure. The other four vocabularies — the generic
   agent-execution-flow convention (`Stage 0: Initialize Early Metadata` ... in every
   `agents/*.md` and the templates they derive from), the generic skill-body
   preflight/postflight flow, `/meta`'s own interview stages, and other scripts' retained
   internal labels — are live and correct. A blind sweep would corrupt all four.
2. **The Stage -> Move mapping is confirmed** against the current `SKILL.md` and
   `docs/architecture/orchestrate-state-machine.md`. It is reproduced below as this plan's single
   authority; every editing phase consumes it rather than re-deriving a mapping.
3. **Sub-step granularity no longer exists as prose anchors.** Move 1, 2, and 3 are each a single
   flattened script call; the old `step 3`/`step 7`/`step 4.5`/`step 5.5` subdivisions live
   inside `orchestrate-cycle-plan.sh`, `orchestrate-build-dispatch.sh`, and
   `orchestrate-cycle-postflight.sh`. A citation must therefore rename the anchor and keep the
   descriptive parenthetical — never fabricate a "Move 1 step 7".

A fresh re-grep at plan time confirmed every per-file hit count in the survey is unchanged (33,
28, 11, 12, 5, 17, 25, 12, 7, 7, 5, 1, 1, 1, 1, 3, 1, 1), so no drift has occurred since the
survey; Phase 1 re-confirms this immediately before editing begins.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no ROADMAP.md consultation performed.

## Goals & Non-Goals

**Goals**:
- Retarget every citation of `skill-orchestrate/SKILL.md`'s deleted Stage 0-8 / Stage MT-1..5
  sections that points at a LIVE mechanism, so it names the correct `Move 1`-`Move 4` anchor.
- Explicitly mark as historical every citation that narrates what the deleted engine did, using
  the framing already modelled in `docs/architecture/orchestrate-state-machine.md` (lines 48,
  704) and `context/patterns/file-footprint-overlap.md`.
- Rewrite `docs/examples/research-flow-example.md`'s worked trace against the current Move loop,
  so the file keeps the purpose its own opening paragraph claims ("traces a complete
  `/orchestrate --research` invocation through the **current** architecture").
- Leave a durable record of which grep-matching files were reviewed and found clean, so a future
  sweep does not re-flag them blind.
- Keep deploy and the full gate run green.

**Non-Goals**:
- Renaming scripts or script-internal labels that contain the word "stage"
  (`orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`, and
  `orchestrate-build-dispatch.sh`'s own live `Stage 3.5 (Dispatch Prep)` label). These are script
  identity, not `SKILL.md` section citations; the six files that cite `Stage 3.5` by name are
  correct and must not change.
- Touching the six `agents/*.md` files or any other file whose "Stage N" belongs to one of the
  four unrelated vocabularies.
- Fixing `context/patterns/task-lock.md`'s separate, pre-existing staleness problem (it cites the
  orphaned `orchestrator-postflight.sh` as a live reference implementation). Unrelated to this
  sweep; recorded by the survey as a follow-up.
- Rewriting surrounding prose beyond what a correct anchor rename requires.
- Editing the deployed `.claude/` tree.

## The Stage -> Move Mapping (single authority for every editing phase)

Single-task (deleted):

| Old anchor | Retarget to |
|---|---|
| Stage 0: Multi-Task Mode Detection | Deleted outright — no `multi_task_mode` branch exists; there is one loop. Rewrite as historical or drop the citation. |
| Stage 1 / 1b (input validation, routing) | Move 1 (classification/admission inside `orchestrate-cycle-plan.sh`) and `command-route-agent.sh` |
| Stage 2 (loop-guard init; paired bash-comment convention) | Move 1 (`orchestrate-cycle-plan.sh`'s loop-guard initialization) |
| Stage 3 / 3.5 (state machine loop, Dispatch Prep) | Move 1's dispatch-file composition call into `orchestrate-build-dispatch.sh`. The script's own `Stage 3.5` label is still live — cite it as `orchestrate-build-dispatch.sh`'s `Stage 3.5`, never as a `SKILL.md` section. |
| Stage 4: State Handlers | Deleted; consolidated into Move 2's per-task dispatch preflight |
| Stage 5: Handoff Reading / `dispatch_seq` staleness gate | Move 3 (logic lives in `orchestrate-cycle-postflight.sh`, called from Move 3) |
| Stage 5a: Drift Inspection | Move 2's `aux_dispatch[]` path (`drift-inspection` kind) |
| Stage 5b: H5 divergence audit | Move 2's `aux_dispatch[]` path (`divergence-audit` kind) |
| Stage 6: Blocker Escalation | Move 2's `aux_dispatch[]` path (`blocker-research`/`plan-revision` kinds); the cross-cutting 5-step sequence is documented in `orchestrate-state-machine.md`'s "Blocker Escalation: 5-Step Sequence" |
| Stage 7: Loop Guard Update | Move 3 (the update) / Move 4 (the loop-condition check that reads it) |
| Stage 8: Postflight / full-loop termination | Move 3 (the shared per-row postflight call) / Move 4 (terminal branch) |

Multi-task (deleted):

| Old anchor | Retarget to |
|---|---|
| Stage MT-1 / MT-2 (initialization) | Move 1 ("Setup (once per invocation)" plus the single `orchestrate-cycle-plan.sh` call) |
| Stage MT-3 (steps 1-7: eligibility, classification, admission, redeploy checkpoint at step 7) | Move 1 — all folded into the one `orchestrate-cycle-plan.sh` call; no `SKILL.md`-addressable sub-step remains |
| Stage MT-4 (dispatch; step 4.5 admission predicate; step 5.5 per-task commit) | Move 2 |
| Stage MT-5 (consolidated output rendering / detection) | Move 3, and Move 4's batched `AskUserQuestion` relay for the `pending_ask_user` accumulation specifically |

**Phrasing rule**: `Stage MT-3 step 7` becomes
``Move 1 (`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint)`` — rename the anchor,
keep the descriptive parenthetical, never invent a "Move N step M".

**Classification rule** (applied to every hit, in order):
1. Does the line cite `SKILL.md`'s deleted structure as the authority for a LIVE mechanism?
   -> retarget per the tables above.
2. Does it deliberately narrate the deleted engine's history? -> leave it, but ensure the
   historical framing is explicit ("the former single-task engine's Stage 6, deleted along with
   that engine").
3. Is it one of the four unrelated vocabularies (agent execution flow, generic skill flow,
   `/meta` interview, another script's own internal label)? -> leave untouched.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A blind `sed` sweep corrupts the four unrelated "Stage N" vocabularies | H | M | No phase runs a whole-file replace. Every hit is classified line-by-line against the Classification rule above; Phase 1 produces the per-hit ledger that the editing phases execute from. |
| Sub-step citations get renamed to a nonexistent "Move N step M" | M | M | The Phrasing rule above is restated in every editing phase's tasks; Phase 9's acceptance grep includes a `Move [0-9]+ step` check that must return zero hits. |
| `orchestrate-build-dispatch.sh`'s own live `Stage 3.5` label gets "fixed" | M | M | Called out as a Non-Goal and in the mapping table; the six citing files are deliberately absent from `file_scope`. |
| Line numbers drift because concurrent sibling tasks edit `batch-orchestration-guardrails.md` / `handoff-schema.md` | M | M | Phase 1 re-greps fresh and records hit counts; no phase trusts the survey's line numbers. Phase 1 aborts to the user if a count has moved by more than a couple of lines in a way that suggests a sibling edit landed mid-sweep. |
| The acceptance grep is run unscoped and "fails" on the legitimate unrelated hits | L | H | Phase 9's grep is explicitly scoped to the 18-file `file_scope` plus a named exclusion list; the plan states that a repo-wide grep will always show dozens of correct unrelated hits and that this is expected. |
| Edits land in the deployed `.claude/` tree and are wiped by the next deploy | H | L | Every `Files to modify` path is rooted at `agent-system/extensions/core/`; Phase 9 verifies `git status` shows no `.claude/**` modifications attributable to this task before deploying. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6, 7, 8 | 1 |
| 3 | 9 | 2, 3, 4, 5, 6, 7, 8 |

Phases within the same wave can execute in parallel. Wave 2's phases have disjoint file
territory by construction — no file appears in two phases' `Files to modify` lists.

---

### Phase 1: Build the per-hit classification ledger [COMPLETED]

**Goal**: Produce a durable, per-hit classification of every grep match in the 18 in-scope files,
so the editing phases execute a decided ledger rather than re-deciding mid-edit.

**Tasks**:
- [x] For each of the 18 files listed in Artifacts & Outputs, run
      `grep -n -C2 -E "Stage MT-|Stage [0-8]\b" <file>` fresh from
      `agent-system/extensions/core/`. *(completed)*
- [x] Confirm the per-file hit count against the counts recorded in Research Integration above.
      If a count has changed, read the surrounding diff context and note whether a concurrent
      sibling edit landed; record the new count rather than proceeding on the stale one.
      *(completed: all counts unchanged, no drift)*
- [x] Classify every hit as `LIVE` (retarget), `HISTORICAL` (leave; verify framing is explicit),
      or `UNRELATED` (leave; name which of the four vocabularies it belongs to). *(completed)*
- [x] For each `LIVE` hit, record the replacement anchor from the mapping table, including the
      descriptive parenthetical to preserve. *(completed)*
- [x] Write the ledger to
      `specs/185_retarget_stage_citations_to_move_vocabulary/notes/01_citation-ledger.md`
      (a working note, not a deliverable artifact — it is not linked into `state.json`).
      *(completed)*
- [x] Resolve the one open question the survey left: `context/patterns/mode-gated-section-loading.md`
      claims `SKILL.md` "already uses an informal paired bash-comment convention"
      (`# --- name:begin ---` / `# --- name:end ---`). A plan-time grep for `begin ---` found
      **no such convention anywhere in the current `SKILL.md`**. Confirm that grep, then record
      in the ledger that this citation must be reframed as historical precedent (or retargeted to
      a currently-live example elsewhere if one is found) — not merely renumbered to a Move.
      *(completed: confirmed no convention exists; reframed as historical in Phase 8)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: The hypothesis is that exactly 18 files carry genuine citations and that
their hit counts are the 18 numbers recorded in Research Integration. Confirm by running the
fresh per-file grep above and comparing counts; additionally re-run
`grep -rlE "Stage MT-" --include="*.md" agent-system/extensions/core/{context,docs,skills,commands}`
(the unambiguous `MT-` subset, 11 files at survey time) to confirm no new `MT-` citation site
appeared outside the 18.

**Files to modify**:
- `specs/185_retarget_stage_citations_to_move_vocabulary/notes/01_citation-ledger.md` - new working note holding the per-hit ledger

**Verification**:
- The ledger exists and contains one row per grep hit across all 18 files.
- Every row carries a classification and, for `LIVE` rows, a concrete replacement string.
- No `LIVE` row's replacement string matches `Move [0-9]+ step`.

---

### Phase 2: Retarget `batch-orchestration-guardrails.md` [COMPLETED]

**Goal**: Retarget the largest single concentration of citations — all MT-3/MT-4/MT-5 references
to still-live admission, dispatch, commit, and redeploy mechanics.

**Tasks**:
- [x] Re-grep the file and reconcile against the Phase 1 ledger before editing. *(completed)*
- [x] Apply each `LIVE` replacement individually (Edit, not `sed`), preserving every descriptive
      parenthetical naming the mechanism or script. *(completed)*
- [x] Where a citation named a sub-step (`MT-3 step 7`, `MT-4 step 4.5`, `MT-4 step 5.5`),
      collapse it to ``Move K (`<script>`'s `<mechanism>`)`` per the Phrasing rule. *(completed)*
- [x] Re-read the diff to confirm no hunk changed prose meaning beyond the anchor rename.
      *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 33 grep hits, expected to be entirely `LIVE` MT-series citations with no
unrelated-vocabulary hits in this file. Confirm against the Phase 1 ledger; if the ledger marks
any hit `UNRELATED` or `HISTORICAL`, honour the ledger over this count.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - MT-3/MT-4/MT-5 anchors retargeted to Move 1/Move 2/Move 3

**Verification**:
- `grep -nE "Stage MT-|Stage [0-8]\b" <file>` returns only hits the ledger marked `HISTORICAL` or
  `UNRELATED`.
- `grep -nE "Move [0-9]+ step" <file>` returns nothing.
- Diff read-through confirms every changed hunk is an anchor rename, not a prose rewrite.

---

### Phase 3: Retarget `docs/architecture/handoff-schema.md` [COMPLETED]

**Goal**: Retarget this file's citations, which the survey classified from the dispatch's own list
rather than line-by-line — so this phase carries the heaviest classification burden of the
editing phases.

**Tasks**:
- [x] Re-grep and classify every hit against the Classification rule; do not assume all 28 are
      `LIVE`. *(completed: 23 LIVE, 5 UNRELATED)*
- [x] Pay particular attention to citations describing *who writes* and *who reads* the handoff:
      the write side is the dispatched agent's own obligation, the read side is Move 3
      (`orchestrate-cycle-postflight.sh`). Retarget the read side to Move 3 and leave the write
      side's agent-internal stage references alone if they belong to the agent-execution-flow
      vocabulary. *(completed)*
- [x] Apply each `LIVE` replacement individually, preserving descriptive parentheticals.
      *(completed)*
- [x] Re-read the diff. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 28 grep hits of mixed classification — this file was NOT line-verified by
the survey. Confirm the per-hit split from the Phase 1 ledger before editing, and record in the
implementation summary how many turned out `LIVE` vs. `UNRELATED`, since the survey could not.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` - Stage 5/7/8 and MT-4 anchors retargeted to Move 2/Move 3

**Verification**:
- Residual grep hits match the ledger's `HISTORICAL`/`UNRELATED` rows exactly.
- `grep -nE "Move [0-9]+ step" <file>` returns nothing.
- Every retargeted read-side citation names `orchestrate-cycle-postflight.sh` or Move 3, not a
  deleted Stage.

---

### Phase 4: Retarget the three batch/cycle schema and template docs [COMPLETED]

**Goal**: Retarget the remaining dispatch-named documentation sites that describe batch admission,
cycle postflight, and consolidated results rendering.

**Tasks**:
- [x] `docs/architecture/batch-admit-schema.md`: retarget MT-3 admission-predicate citations to
      Move 1 (`orchestrate-cycle-plan.sh`'s admission pass) and MT-4 step 4.5 citations to
      Move 2. *(completed: all 12 hits were MT-3 step 4.5/step 3, all retargeted to Move 1)*
- [x] `docs/architecture/orchestrate-cycle-postflight.md`: retarget Stage 5/7/8 and MT-5
      citations to Move 3 / Move 4 per the mapping table; this file documents the script Move 3
      calls, so prefer naming the script plus the Move. *(completed: 5 LIVE retargeted to Move 3,
      6 HISTORICAL left untouched — this doc narrates the pre-merger single-task/multi-task split
      explicitly in past tense)*
- [x] `context/patterns/orchestrate-batch-results-template.md`: retarget MT-5 rendering citations
      to Move 3, and the `pending_ask_user` relay specifically to Move 4. *(completed: all 5 hits
      were general rendering citations, retargeted to Move 3 per the mapping table; no
      `pending_ask_user`-specific citation appeared in this file's hit set)*
- [x] Re-read each diff. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 12 + 11 + 5 = 28 grep hits across three files, expected predominantly
`LIVE`. Confirm per-file against the Phase 1 ledger.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - MT-3/MT-4 anchors retargeted to Move 1/Move 2
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` - Stage 5/7/8 and MT-5 anchors retargeted to Move 3/Move 4
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - MT-5 anchors retargeted to Move 3, `pending_ask_user` relay to Move 4

**Verification**:
- Residual grep hits in each of the three files match the ledger's non-`LIVE` rows.
- `grep -nE "Move [0-9]+ step"` returns nothing in any of the three.

---

### Phase 5: Retarget `context/standards/orchestrator-runtime-files.md` [COMPLETED]

**Goal**: Retarget the runtime-file map so each of `.orchestrator-loop-guard`,
`.orchestrator-churn-state.json`, `.drift-inspection.json`, and `.orchestrator-handoff.json`
names the correct Move for its write, read, and cleanup points.

**Tasks**:
- [x] Re-grep and reconcile against the ledger. *(completed)*
- [x] Retarget per the mapping: Stage 2 -> Move 1 (loop-guard creation); Stage 5/5a -> Move 3
      (handoff read) and Move 2's `aux_dispatch[]` drift-inspection path; Stage 7 -> Move 3
      (loop-guard update); Stage 8 -> Move 3/Move 4 (postflight and terminal cleanup); MT-4 ->
      Move 2. *(completed; two bare "Stage 5a" instances not matched by the scoped grep pattern
      were fixed anyway, see ledger; "Stage 3b"/"Stage 9" left as a recorded residual gap, also
      unmatched by the scoped pattern and absent from the mapping table)*
- [x] Where the file asserts a write/read ordering between two old stages, confirm the ordering
      still holds between the Moves it maps onto before asserting it in Move terms. *(completed)*
- [x] Re-read the diff. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 17 grep hits, expected all `LIVE`. Confirm against the ledger.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - Stage 2/5/5a/7/8 and MT-4 anchors retargeted to Move 1/Move 2/Move 3/Move 4

**Verification**:
- Residual grep hits match the ledger's non-`LIVE` rows.
- Each runtime file's write point, read point, and cleanup point names a Move that exists in the
  current `SKILL.md`.
- `grep -nE "Move [0-9]+ step" <file>` returns nothing.

---

### Phase 6: Rewrite the worked trace in `docs/examples/research-flow-example.md` [COMPLETED]

**Goal**: Rewrite the end-to-end worked trace against the current Move 1-4 loop, keeping the
file's stated purpose intact.

**Decision (made at plan time, not deferred)**: the survey flagged a choice between rewriting the
trace and reframing the whole file as a historical example. **Rewrite it.** The file's own opening
sentence promises a trace "through the current architecture", and the survey found no other
context file that walks a Move-based dispatch cycle end-to-end — reframing it as history would
leave that gap unfilled and contradict the file's first paragraph. The rewrite is scoped to the
trace's anchors and flow structure, not to its narrative content or its worked example data.

**Tasks**:
- [x] Re-grep and reconcile against the ledger. Note that this file mixes two vocabularies on
      adjacent lines: `skill-orchestrate` stage citations (`LIVE`, retarget) and the research
      agent's own `Agent Stage 1`..`Agent Stage 6` headings (`UNRELATED`, leave exactly as they
      are). *(completed: 15 LIVE retargeted, 7 UNRELATED Agent-Stage headings + the live
      Stage 3.5 script label left untouched)*
- [x] Rewrite the flow diagram's `[Layer 2: Skill]` block: replace the
      `Stage 1 / 1b / 2 / 3 / 3.5` sequence with the Move 1 sequence, naming
      `orchestrate-cycle-plan.sh` and `orchestrate-build-dispatch.sh` (including the latter's own
      still-live `Stage 3.5 (Dispatch Prep)` label, cited as the script's label). *(completed)*
- [x] Rewrite the return-flow lines (`Stage 5 -> Stage 7 -> Stage 8`) as Move 3 and Move 4.
      *(completed)*
- [x] Rewrite the prose section headings that name `skill-orchestrate` stages
      (`**Stage 1: Input Validation**`, `**Stage 2: Loop Guard Initialization**`,
      `**Stage 3: State Machine Loop**`, `**Stage 3.5: Dispatch Prep**`,
      `**Agent -> Stage 5: Handoff Reading**`, `**Stage 7: Loop Guard Update**`,
      `**Stage 8: Postflight**`) to their Move equivalents, merging sections where the mapping
      collapses several old stages into one Move rather than inventing sub-anchors.
      *(completed: Steps 2 ["Stage 1/1b/2/3"] merged into one "Move 1" section; Step 5
      ["Stage 5/7/8"] merged into one "Move 3" section)*
- [x] Remove or rewrite the `(single-task mode)` qualifier on the `[Layer 2: Skill]` label —
      there is only one loop now. *(completed)*
- [x] Update the closing summary list (the "Return Flow" bullet) to Move vocabulary.
      *(completed)*
- [x] Leave the `task-ref-ok` marker block and the concrete example task number untouched.
      *(completed)*
- [x] Re-read the whole file top-to-bottom (not just the diff) to confirm the trace still reads
      as one coherent sequence after the section merges. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 25 grep hits, of which roughly 13 are `skill-orchestrate` citations to
retarget and roughly 12 are the research agent's own `Agent Stage N` headings to leave untouched.
Confirm the exact split from the Phase 1 ledger before editing — the ratio matters here more than
in any other phase, because the two vocabularies alternate within a single document.

**Files to modify**:
- `agent-system/extensions/core/docs/examples/research-flow-example.md` - worked trace, flow diagram, and section headings rewritten against Move 1-4; `Agent Stage N` headings preserved verbatim

**Verification**:
- Residual grep hits are exactly the `Agent Stage N` lines the ledger marked `UNRELATED`, plus any
  citation of `orchestrate-build-dispatch.sh`'s own `Stage 3.5` label.
- `grep -nE "Move [0-9]+ step" <file>` returns nothing.
- Every Move named in the file exists as a `### Move N:` heading in the current
  `skills/skill-orchestrate/SKILL.md`.
- The file reads as a coherent single trace: no dangling reference to a section the rewrite
  merged away.

---

### Phase 7: Line-level edits in the four mixed-vocabulary files [COMPLETED]

**Goal**: Apply single-line or few-line retargets in the four files that carry both a genuine
citation and an unrelated vocabulary, without touching the unrelated hits.

**Tasks**:
- [x] `context/patterns/skill-postflight-flow.md`: retarget only the one line that contrasts the
      generic flow with `skill-orchestrate`'s "Stage MT-4 per-task loop" -> Move 2. The file's
      other ~11 hits are the generic skill-body Stage 1-9 convention and MUST NOT change.
      *(completed: exactly 1 of 12 hits was LIVE)*
- [x] `context/patterns/infra-failure-discrimination.md`: retarget the handoff-inspection-timing
      citations ("Stage 5", "Stage MT-4 step 1") -> Move 3. The file's `Stage 0`, `Stage 2`, and
      `Stage 7` hits are the agent-execution-flow convention and MUST NOT change.
      *(completed: 3 of 7 hits were LIVE)*
- [x] `context/patterns/regeneration-is-manual-only.md`: retarget the "Stage MT-3 step 7"
      inter-cycle redeploy-checkpoint citations to
      ``Move 1 (`orchestrate-cycle-plan.sh`'s inter-cycle redeploy checkpoint)`` and the
      "Stage MT-4" per-task commit citations to Move 2. Leave the one reference to
      `orchestrate-build-dispatch.sh`'s own `Stage 3.5` untouched. *(completed: 6 of 7 hits were
      LIVE, 1 was the live script label)*
- [x] `context/patterns/dispatch-report-not-termination.md`: retarget only the one line citing
      "`skill-orchestrate/SKILL.md`'s Stage 5 staleness-gate comment block" -> Move 3. The other
      two hits belong to the lean extension's own agent-stage convention and MUST NOT change.
      *(completed: exactly 1 of 3 hits was LIVE)*
- [x] After each file, re-grep and confirm the untouched hits are byte-identical to before.
      *(completed: diff review confirms no collateral edits in any of the four files)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: 12 + 7 + 7 + 3 = 29 grep hits across four files, of which only about 1 + 3
+ 6 + 1 = 11 are `LIVE`. The precise per-file `LIVE` set comes from the Phase 1 ledger, and the
count of untouched hits must be verified unchanged after editing — that invariant is the real
check here, not the count of edits.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/skill-postflight-flow.md` - one `Stage MT-4` citation -> Move 2
- `agent-system/extensions/core/context/patterns/infra-failure-discrimination.md` - handoff-inspection-timing citations -> Move 3
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - MT-3 step 7 and MT-4 citations -> Move 1 / Move 2
- `agent-system/extensions/core/context/patterns/dispatch-report-not-termination.md` - one `Stage 5` staleness-gate citation -> Move 3

**Verification**:
- For each file, the set of residual grep hits equals the ledger's `UNRELATED` + `HISTORICAL` rows
  exactly — same line text, no collateral edits.
- `grep -nE "Move [0-9]+ step"` returns nothing in any of the four.
- `git diff --stat` for this phase shows only the four intended files.

---

### Phase 8: Retarget the five single-citation files [COMPLETED]

**Goal**: Retarget the five files carrying exactly one citation each, including the one that needs
a historical reframe rather than a rename.

**Tasks**:
- [x] `skills/skill-git-workflow/SKILL.md`: the line "single-task CHECKPOINT 3 and multi-task
      Stage MT-4 step 5.5" describes the current commit execution site -> retarget to Move 2,
      collapsing both halves (there is one engine now, so the single-task/multi-task contrast is
      itself stale). *(completed)*
- [x] `docs/fork-patterns.md`: "Stage 5a drift inspection, Stage 6 blocker research" -> Move 2's
      `aux_dispatch[]` path, naming the `drift-inspection` and `blocker-research` kinds.
      *(completed)*
- [x] `context/contracts/territory.md`: "The orchestrator's own Stage 5 `dispatch_seq` gate" ->
      Move 3 (the gate now lives in `orchestrate-cycle-postflight.sh`). *(completed)*
- [x] `context/contracts/wrap-up.md`: "...Stage 5 of both orchestrate engines compares against..."
      -> Move 3, and drop "both orchestrate engines" (there is one engine). *(completed)*
- [x] `context/patterns/mode-gated-section-loading.md`: per the Phase 1 ledger, the claim that
      `SKILL.md` "already uses an informal paired bash-comment convention" is no longer true of
      the current file. Reframe the sentence as historical precedent (naming the pre-rewrite
      engine) or, if Phase 1 found a currently-live example of the convention elsewhere, point at
      that instead. Do NOT simply renumber `Stage 2` to `Move 1` — that would assert a convention
      the current `SKILL.md` does not contain. *(completed: no live example found anywhere in
      the core extension tree; reframed as pure historical precedent)*
- [x] Re-read each diff. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: five files with one grep hit each. Confirm each file still has exactly one
hit before editing; a second hit means the file drifted and the ledger must be re-derived for it.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-git-workflow/SKILL.md` - MT-4 step 5.5 commit-site citation -> Move 2
- `agent-system/extensions/core/docs/fork-patterns.md` - Stage 5a/6 citations -> Move 2 `aux_dispatch[]` kinds
- `agent-system/extensions/core/context/contracts/territory.md` - Stage 5 `dispatch_seq` gate -> Move 3
- `agent-system/extensions/core/context/contracts/wrap-up.md` - Stage 5 `dispatch_seq` comparison -> Move 3, "both engines" dropped
- `agent-system/extensions/core/context/patterns/mode-gated-section-loading.md` - Stage 2 bash-comment-convention claim reframed as historical precedent

**Verification**:
- Each of the five files returns zero `LIVE` residual grep hits.
- `mode-gated-section-loading.md`'s sentence no longer asserts that the current `SKILL.md`
  contains the paired-comment convention.
- `grep -nE "Move [0-9]+ step"` returns nothing in any of the five.

---

### Phase 9: Acceptance grep, confirmed-clean record, deploy, and full gate run [COMPLETED]

**Goal**: Establish that the acceptance criteria hold, leave a durable record of the
reviewed-and-clean files, and confirm deploy plus the full gate run are green.

**Tasks**:
- [ ] Run the scoped acceptance grep over the editing phases' 16 edited files:
      `grep -nE "Stage MT-|Stage [0-8]\b"` on each. Every residual hit must be justified by the
      Phase 1 ledger as `HISTORICAL` or `UNRELATED`; enumerate them in the summary with their
      justification.
- [ ] Run `grep -rnE "Move [0-9]+ step" agent-system/extensions/core/` and confirm zero hits (no
      fabricated sub-step anchors anywhere).
- [ ] Confirm every Move named across the edited files exists as a `### Move N:` heading in
      `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`.
- [ ] Record the two confirmed-clean files — `docs/architecture/orchestrate-state-machine.md`
      (its historical framings at "former" / "deleted along with that engine" are the model, its
      remaining hits are false positives or valid script-name citations) and
      `context/patterns/file-footprint-overlap.md` (already correctly historical about a
      different deleted engine) — as reviewed-with-no-action, so a future sweep has the record.
      Where a one-line clarifying parenthetical would prevent a future re-flag, add it; otherwise
      record the finding in the implementation summary only.
- [ ] Confirm `git status --short` shows no modification under `.claude/**` attributable to this
      task (source-store boundary).
- [x] Run `bash .claude/scripts/deploy-headless.sh` and confirm it succeeds. *(completed:
      RESULT=landed_verify_clean, 33/33 checks)*
- [x] Run `bash .claude/scripts/verify-deploy.sh` (the full gate run, Gate 8 included) and confirm
      green. *(completed with findings — see below: 2 of 34 checks failed, both confirmed
      unrelated to this task's edits)*
- [x] If the gate run reports a pre-existing failure unrelated to these edits, record it
      explicitly rather than attributing it to this task. *(completed — two findings recorded)*

**Full gate run finding 1 — whole-tree orphan detection (check 13)**: flagged
`tmp/noop-bash-count-50a41710-9ffb-4d2a-8522-9a84ee1fd97e`. Confirmed an environmental false
positive attributable to this orchestrator session's own tooling, not this task: the file lives
at `.claude/tmp/noop-bash-count-<uuid>` (inside the disposable deployed tree, hence the
`.claude`-relative report path), the UUID matches this orchestrator session's own scratchpad
directory, it is untracked in every branch (`git log --all -- 'tmp/noop-bash-count-*'` returns
nothing, `git ls-files | grep -c noop-bash-count` returns 0), and no repo-root `tmp/` directory
exists at all. Not created by any edit this task made.

**Full gate run finding 2 — shell test suite (check 8, `run-all.sh`)**: 105 passed, 3 failed (2
expected, 1 new), 1 skipped, 109 total, run directly and to completion in the foreground
(`timeout 600 bash agent-system/extensions/core/scripts/tests/run-all.sh --jobs 4`, exit 0). The
2 "(EXPECTED)" failures (`test-gate-out-repair-reporting.sh`,
`test-lint-json-channel-discipline.sh`) are pre-marked expected/flaky by the runner itself, not a
regression. The 1 "(NEW)" failure (`test-typst-element-lint.sh`, case-h2) is caused by an
uncommitted, in-progress modification to `agent-system/extensions/typst/scripts/typst-element-lint.sh`
sitting in the shared working tree (`git status --short` shows it `M`, unstaged, 43
insertions/7 deletions) — confirmed via `git log` to belong to task 179's lineage, not to task
185's 17 markdown-only edits, and already present as a dirty file in `git status` before this
task's first commit. Not caused by, or attributable to, this task.

**Timing**: 0.75 hours

**Depends on**: 2, 3, 4, 5, 6, 7, 8

**Verification Tier**: full

**Scope Hypothesis**: 16 files edited across Phases 2-8, with two further files
(`orchestrate-state-machine.md`, `file-footprint-overlap.md`) reviewed and expected to need no
change — 18 files in `file_scope` total. Confirm by `git diff --name-only` against the
pre-Phase-2 commit: the edited set must be a subset of the 18, and any file outside the 18 is a
scope violation to investigate before closing.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - clarifying parenthetical only if needed to prevent a future re-flag; no retarget expected
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - clarifying parenthetical only if needed; no retarget expected

**Verification**:
- Scoped acceptance grep: every residual hit across the 18 files is accounted for by the ledger.
- `grep -rnE "Move [0-9]+ step" agent-system/extensions/core/` returns zero hits.
- No `.claude/**` file is modified by this task's commits.
- `deploy-headless.sh` exits 0.
- `verify-deploy.sh` reports no new failures relative to the pre-task baseline.

---

## Testing & Validation

- [x] Per-file scoped grep (`grep -nE "Stage MT-|Stage [0-8]\b"`) over all 18 `file_scope` files:
      every residual hit justified as `HISTORICAL` or `UNRELATED` by the Phase 1 ledger.
      *(completed)*
- [x] `grep -rnE "Move [0-9]+ step" agent-system/extensions/core/` returns zero hits. *(completed:
      zero hits in any file this task touched; one pre-existing, unrelated hit noted in the
      ledger — ordinary English "Move 3 step" in a test script, not a fabricated sub-anchor, and
      not authored by this task)*
- [x] Every Move anchor cited in an edited file resolves to a real `### Move N:` heading in the
      current `skills/skill-orchestrate/SKILL.md`. *(completed)*
- [x] The six files that cite `orchestrate-build-dispatch.sh`'s own live `Stage 3.5` label
      (`commands/orchestrate.md`, `context/contracts/anti-analysis.md`,
      `context/guides/hard-mode-routing.md`, `context/guides/manifest-routing-schema.md`, and the
      `/meta`-variant site in `docs/reference/standards/multi-task-creation-standard.md`) are
      unmodified — confirm via `git diff --name-only`. *(completed)*
- [x] No `agents/*.md` file is modified. *(completed)*
- [x] `git status --short` shows no `.claude/**` modification attributable to this task.
      *(completed)*
- [x] `bash .claude/scripts/deploy-headless.sh` exits 0. *(completed: RESULT=landed_verify_clean,
      33 checks, 0 failures)*
- [ ] `bash .claude/scripts/verify-deploy.sh` reports no new failures versus the pre-task
      baseline.

**Note on grep scoping**: the acceptance grep is scoped to the 18 `file_scope` files (and, for the
`Move N step` check, to `agent-system/extensions/core/`). An unscoped repo-wide
`Stage MT-|Stage [0-8]` grep will always return dozens of correct, unrelated hits from the four
other vocabularies and from script filenames and internal labels. That is expected, not a defect,
and must not be treated as a failed acceptance check.

## Artifacts & Outputs

Edited (Phases 2-8, 16 files, all under `agent-system/extensions/core/`):
- `context/patterns/batch-orchestration-guardrails.md`
- `docs/architecture/handoff-schema.md`
- `docs/architecture/batch-admit-schema.md`
- `docs/architecture/orchestrate-cycle-postflight.md`
- `context/patterns/orchestrate-batch-results-template.md`
- `context/standards/orchestrator-runtime-files.md`
- `docs/examples/research-flow-example.md`
- `context/patterns/skill-postflight-flow.md`
- `context/patterns/infra-failure-discrimination.md`
- `context/patterns/regeneration-is-manual-only.md`
- `context/patterns/dispatch-report-not-termination.md`
- `skills/skill-git-workflow/SKILL.md`
- `docs/fork-patterns.md`
- `context/contracts/territory.md`
- `context/contracts/wrap-up.md`
- `context/patterns/mode-gated-section-loading.md`

Reviewed, no retarget expected (Phase 9, 2 files, same root):
- `docs/architecture/orchestrate-state-machine.md`
- `context/patterns/file-footprint-overlap.md`

Working note (not a linked artifact):
- `specs/185_retarget_stage_citations_to_move_vocabulary/notes/01_citation-ledger.md`

Deliverable artifact:
- `specs/185_retarget_stage_citations_to_move_vocabulary/summaries/01_stage-citation-retarget-summary.md`
  (written at implementation completion; must enumerate every residual grep hit with its
  justification, and report the `LIVE`/`UNRELATED` split Phase 3 discovered for
  `handoff-schema.md`, which the survey could not determine)

## Rollback/Contingency

Every phase's edits are markdown prose confined to one disjoint file set, committed per phase, so
rollback is per-phase and independent: `git revert` the phase's commit. No schema, script, or
runtime behaviour changes, so a revert cannot leave a half-migrated state.

If a defensive checkpoint is wanted before the largest phases (2, 3, 6), take a durable,
non-reverting one with `bash .claude/scripts/git-snapshot.sh 185 --no-revert`. A genuine rollback
that must discard uncommitted work follows `context/contracts/recovery.md`'s rollback rung for
the correct `git-snapshot.sh` invocation shape — including its out-of-scope override flag — before
running the destructive command.

If `verify-deploy.sh` goes red in Phase 9 and bisecting by phase commit does not isolate the
cause, revert the whole wave-2 set and re-run the gate to confirm the failure is pre-existing
rather than introduced here; record the finding instead of leaving the task green on an
unexplained red gate.
