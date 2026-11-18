# Implementation Plan: Task #558

- **Task**: 558 - Document the convention that a task description must request a PROPOSAL PACKET, never task FILING, from an autonomous dispatch
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/558_conclusion_stage_filing_handoff_phrasing/reports/01_filing-handoff-phrasing-convention.md
- **Artifacts**: plans/01_filing-handoff-phrasing-convention.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Documentation-only change at two sites in the `core` extension's source store. The convention
is stated **once**, as a new subsection immediately following Component 7's existing
"Foreground Requirement" paragraph in
`agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`, naming
the forbidden shape (a description instructing an autonomous dispatch to file tasks), the
required shape (a description requesting issue-log entries plus a rendered candidate list), and
the WHY (Component 7's Foreground Requirement plus the measured `AskUserQuestion` withholding).
A second, pointer-only sentence pair is added to
`agent-system/extensions/core/context/contracts/conclusion-stage.md`'s Overview, where the
originating author's attention already was. No new packet format is specified; the deliverable
points at the existing `suggested_channel` hint field plus ordinary report/plan/summary prose.
Both edits then land in the deployed tree via `deploy-headless.sh`.

### Research Integration

The research report's siting diagnosis is adopted without modification: primary site (a)
composed with pointer site (b), rejecting (c). Specific findings carried into the phases below:

- `grep -rln "multi-task-creation-standard"` over the source store found 19 referencing files,
  none of which are `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`, or
  `general-implementation-agent.md` — the agents that actually author plan phase text. This is
  why site (a) alone under-reaches and the `conclusion-stage.md` pointer is added.
- `grep -rl "proposal packet\|reconciled proposal"` over the source store returns zero hits
  (re-verified live during this planning pass). There is no pre-existing, differently-worded
  packet specification to reconcile against, and correspondingly no new one is to be written:
  the "packet" is a pointer to `context/formats/issue-log.md`'s `suggested_channel` field plus
  a human-readable list in the dispatch's own artifact.
- The WHY is citable rather than re-derivable:
  `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched
  Subagents (Measured)" section (confirmed present) is the stronger claim than Component 7's own
  "does not reliably surface" phrasing, and both are cited by path rather than restated.
- The skeleton-plan follow-up mechanism is a disjoint precedent and is deliberately **not**
  referenced from the new convention.

### Carried-Figure Re-Validation

Every premise line the dispatch flagged was checked against live state during this planning
pass. Results stated explicitly, including the confirmations:

1. **CONFIRMED, verbatim.** Component 7's Foreground Requirement reads, at
   `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md:502`:
   "Confirmation MUST execute in the foreground skill layer (not inside a delegated background
   agent). `AskUserQuestion` called from background agents (spawned via Task tool) does not
   reliably surface to users." The description's characterization is accurate.
2. **CONFIRMED.** `docs/reference/standards/agent-frontmatter-standard.md` carries
   `### Tool Withholding from Dispatched Subagents (Measured)` at line 108, with two further
   in-document cross-references at lines 35 and 98. The categorical-withholding claim has a live
   citable home.
3. **CORRECTED.** The description's line "its channel (c), 'follow-up tasks as children', is
   executed at the orchestrate-lead level where `AskUserQuestion` is reachable" does not match
   the contract. `context/contracts/conclusion-stage.md`'s Overview states channel (b) is "never
   dispatched or executed by this stage" and channel (c) is "never created as task directories by
   this stage", and that "Only channel (a) executes anything". Step 4c confirms it: "No task is
   created, no task directory is populated, and `specs/state.json` is not written. This evidence
   is consumed later, deliberately and in batches, by `/distill --meta`". The foreground
   Component 7 confirmation therefore happens **downstream** of the conclusion stage, at a
   separate, deliberately-batched invocation (this codebase's current name for that consumer is
   `/telemetry --meta`, which delegates to `meta-builder-agent`). **This correction does not
   change the remedy** — the hand-off target for a dispatch is still the evidence store, and the
   filing decision still rests with a foreground surface — but the new prose MUST describe the
   chain accurately rather than claiming the conclusion stage itself files anything.
4. **CONFIRMED.** Both edit targets lie outside `specs/**`
   (`agent-system/extensions/core/...`), so the no-task-references and no-record-versioning
   rules bind on the new prose. Carried into every phase's task list below.
5. **CONFIRMED.** Both named correction targets exist on disk at the paths research cites, and
   the `source_dir` for extension `core` resolves via
   `jq -r '.extensions.core.source_dir' .claude-extensions.json` to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- State the phrasing convention exactly once, at `multi-task-creation-standard.md`'s Component 7,
  naming the forbidden shape, the required shape, and the WHY.
- Add a pointer-only note at `conclusion-stage.md`'s Overview declaring that a task description
  or plan naming this stage as the filer is malformed, directing the reader to the single
  statement.
- Point at the existing `suggested_channel` / report-prose shape rather than specifying a new
  packet format.
- Land both edits in the deployed tree with `RESULT=landed_verify_clean`.

**Non-Goals**:

- No change to Component 7's foreground requirement or to any confirmation gate.
- No new capability for dispatched agents to file tasks; no relaxation of the `AskUserQuestion`
  withholding.
- No change to the conclusion stage's channel routing, filter predicate, exactly-one-channel
  rule, or Hint-Versus-Decision rule.
- No retroactive rewrite of existing task descriptions carrying the offending phrasing.
- No edit to the skeleton-plan follow-up mechanism, and no reference to it from the new prose.
- No fix for the stale "15-class seed enum" figure recorded in this task's `issues.jsonl` during
  research — it is unrelated and is left for its own record.
- No edit to `scripts/orchestrate-build-dispatch.sh` or its aux/unwind siblings (rejected site
  (c)).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New subsection is read as governing only the Component 1-8 multi-task-creator surfaces that document otherwise addresses | M | H | The subsection's own opening sentence states explicitly that it binds *any* task description or plan-phase instruction handed to an autonomous dispatch, not only multi-task-creator output. Phase 1 task list carries this as a required element. |
| New prose repeats the description's inaccurate "the conclusion stage files channel (c)" framing, writing a falsehood into the contract | H | M | Carried-Figure item 3 above records the correction. Phase 1 and Phase 2 task lists both require the chain be described as record-evidence -> aggregate/classify -> separate foreground confirmed creation. |
| Prose accidentally carries a task-number reference or record-versioning phrasing | M | M | Both edited files lie outside `specs/**`. Gate 4 (task-reference lint) is in the Phase 1/2 verification subset and the full Phase 3 gate set; record-versioning phrasing is checked by diff read-through against `.claude/rules/no-record-versioning-in-deliverables.md`'s forbidden-phrase list. |
| The pointer note duplicates rather than points, producing the "second, differently-worded convention" the description names as making the work worthless | H | L | Phase 2's task list caps the addition at two sentences and forbids restating the forbidden/required shapes; it names the heading and defers. Phase 2's verification includes a read-back confirming no shape definition appears at the pointer site. |
| A sibling task dispatched this same cycle edits one of the two target files | M | L | Neither target path appears in any concurrent sibling's declared `file_scope` (503, 526, 538 checked — all disjoint). Territory contract still applies: re-read each file immediately before editing, stage only this task's own hunks. |
| Deploy leaves the tree non-clean (the dispatch already reports `core` as stale before any edit) | M | M | Phase 3 runs the bounded-wait deploy and requires `RESULT=landed_verify_clean` explicitly; a different RESULT is a phase failure, not a warning to note and move past. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: State the convention at Component 7 [COMPLETED]

**Goal**: The convention exists, stated once, in the task-authoring standard, adjacent to the
Foreground Requirement it protects.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
      around Component 7 (the `**Foreground Requirement**:` paragraph through the
      `Reference implementation: skill-meta Stage 2.5 ...` line, immediately before
      `### 8. State Updates (Required)`), confirming the insertion point before editing.
      *(completed)*
- [x] Add one new subsection immediately after that `Reference implementation:` line and before
      `### 8. State Updates (Required)`. Give it a stable, citable heading naming the
      proposal-versus-filing distinction (the Phase 2 pointer will cite this heading verbatim,
      so fix the wording here). *(completed: heading "Requesting a Proposal Packet, Not Filing,
      From an Autonomous Dispatch")*
- [x] In that subsection, state that the convention binds **any** task description or plan-phase
      instruction handed to an autonomous dispatch, not only output from a multi-task-creator
      surface. *(completed)*
- [x] State the **forbidden shape**: a task description or plan phase text that instructs an
      autonomous research/plan/implement dispatch to itself file, create, or confirm creation of
      a follow-up task or an agent-system change request. *(completed)*
- [x] State the **required shape**: the description instead asks the dispatch to (1) record one
      `issue-record.sh` entry per candidate, carrying `suggested_channel: follow_up_task` or
      `agent_system` as appropriate, and (2) render the same candidates as a human-readable list
      in its own report, plan, or summary — leaving confirmed creation to a foreground surface.
      *(completed)*
- [x] State the **why**, by citation and not by restatement: Component 7's own Foreground
      Requirement two paragraphs above, plus
      `docs/reference/standards/agent-frontmatter-standard.md`'s "Tool Withholding from
      Dispatched Subagents (Measured)" section for the categorical, measured unreachability of
      `AskUserQuestion` from a dispatch. *(completed)*
- [x] Describe the downstream chain accurately per Carried-Figure item 3: the dispatch records
      evidence; the orchestration conclusion stage aggregates and classifies it into channels
      without creating anything; a separate, deliberately-batched foreground invocation performs
      the Component 7-compliant confirmed creation. Do **not** write that the conclusion stage
      itself files tasks. *(completed)*
- [x] Point at `context/formats/issue-log.md`'s `suggested_channel` field as the existing shape.
      Do not specify a new packet format, and do not reference the skeleton-plan follow-up
      mechanism. *(completed)*
- [x] Read the new hunk back against `.claude/rules/no-task-references-in-deliverables.md` and
      `.claude/rules/no-record-versioning-in-deliverables.md`: durable anchors only (file names,
      section headings, "Component 7", `suggested_channel`, `follow_up_task`, `AskUserQuestion`),
      no task numbers, no `iss_*` ids, no draft-history or supersession phrasing. *(completed:
      read back manually, no violations found)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly one file is edited in this phase, and the insertion point is
immediately after Component 7's `Reference implementation: skill-meta Stage 2.5 ...` line and
before the `### 8. State Updates (Required)` heading. Confirm by re-reading that region before
editing rather than trusting the line region named here; if the surrounding text has moved,
re-locate the Foreground Requirement paragraph by its text and insert after the subsection it
terminates.

**Tier Justification**: `suite_selection_select` over this phase's path returns the
`__FULL_SWEEP__` sentinel (no suite maps to it), so the honest covering check is sub-case (b)'s
gate subset `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow
--only-gate 3,4 /home/benjamin/.config/nvim` plus the `prose` row's diff read-through — no suite
is claimed.

**Files to modify**:

- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` - new
  Component 7-adjacent subsection stating the convention once

**Verification**:

- Diff read-through confirming every changed hunk is prose inside the intended subsection, with
  no edit to Component 7's own Foreground Requirement text or to any adjacent component.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` passes (doc-lint and task-reference lint; `TARGET` is the
  source-store repository root, which also holds the deployed `.claude/` tree).
- Grep the new subsection for the four required elements: the scope sentence, the forbidden
  shape, the required shape naming `suggested_channel`, and both WHY citations by path.

---

### Phase 2: Add the pointer-only note at the conclusion-stage Overview [COMPLETED]

**Goal**: A reader reasoning from the conclusion stage's own vocabulary — the surface the
originating phrasing came from — is told the phrasing is malformed and sent to the single
statement.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/contracts/conclusion-stage.md`'s Overview,
      specifically the channel (b)/(c) bullets ("never dispatched or executed by this stage",
      "never created as task directories by this stage") and the "Only channel (a) executes
      anything" paragraph that follows them. *(completed)*
- [x] Add at most two sentences immediately after that paragraph stating that a task description
      or plan phase naming this stage as the filer of follow-up tasks or agent-system changes is
      malformed, and that such a description must instead ask its dispatch for issue-log entries
      plus a rendered candidate list. *(completed)*
- [x] Point to the Phase 1 subsection by document path and heading, verbatim as Phase 1 wrote it.
      Do **not** restate the forbidden shape, the required shape, or the WHY citations here —
      the pointer defers. *(completed)*
- [x] Confirm no change was made to the Overview's channel descriptions, to the Filter Predicate,
      the Exactly-One-Channel Rule, the Hint-Versus-Decision Rule, the Citation Requirement, or
      to any step of The Executable Stage Body. *(completed: diff confined to the two new
      sentences, above ## The Evidence Base)*
- [x] Read the new hunk back against the no-task-references and no-record-versioning rules, as in
      Phase 1. *(completed: no violations found)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly one file is edited in this phase, and the addition is confined to
the Overview section — no step of The Executable Stage Body is touched. Confirm by diffing the
file and checking that every changed line falls above the `## The Evidence Base` heading.

**Tier Justification**: `suite_selection_select` over this phase's path returns three real
suites, so the covering check is `bash .claude/scripts/tests/run-all.sh --only
test-orchestrate-conclusion-aggregate.sh,test-orchestrate-conclusion-backstop.sh,test-orchestrate-conclusion-roadmap.sh`
plus the `prose` row's diff read-through — no sentinel is claimed.

**Files to modify**:

- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - pointer-only note in the
  Overview, after the "Only channel (a) executes anything" paragraph

**Verification**:

- Diff shows changed lines only within the Overview (above `## The Evidence Base`), and the
  addition is at most two sentences.
- The cited heading string matches the heading Phase 1 actually wrote in
  `multi-task-creation-standard.md` (grep both files for the heading text and compare).
- No definition of the forbidden or required shape appears at this site — read the addition back
  and confirm it only declares the malformed case and defers.
- `bash .claude/scripts/tests/run-all.sh --only
  test-orchestrate-conclusion-aggregate.sh,test-orchestrate-conclusion-backstop.sh,test-orchestrate-conclusion-roadmap.sh`
  exits 0 (the three suites `suite_selection_select` maps this path to).
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` passes (doc-lint and task-reference lint over the new prose).

---

### Phase 3: Redeploy and verify the full gate set [COMPLETED]

**Goal**: Both edits are present in the deployed `.claude/` tree, the `core` staleness the
dispatch reported is cleared, and the complete gate set is green.

**Tasks**:

- [x] Confirm Phases 1 and 2 are committed (each as its own scoped commit, explicit file list,
      never a directory or glob pathspec). *(completed: phase 1 commit a43b8f74e, phase 2 commit
      5d23cfccd plus scoped follow-up commit 473667611 for the dropped
      agent-system/extensions/core/index-entries.json path)*
- [x] Run the deploy with a bounded wait:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, invoked with the Bash tool's
      `timeout` parameter raised to 600000 per `context/patterns/external-process-wait.md`
      Rule 1. *(completed)*
- [x] Confirm the deploy reports `RESULT=landed_verify_clean`. Any other RESULT is a phase
      failure: stop, report it, and do not proceed to attest the gate set. *(completed:
      RESULT=landed_verify_clean, 41 checks, 0 failures)*
- [x] Confirm both edits are present in the deployed mirror at
      `.claude/docs/reference/standards/multi-task-creation-standard.md` and
      `.claude/context/contracts/conclusion-stage.md`. *(completed: both headings/pointer
      confirmed present via grep)*
- [x] Run the complete gate set and observe it green in this dispatch. *(deviation: altered —
      this dispatch carries a Batch Gate Deferral directive for this phase's declared `full`
      tier; discharged against the scoped narrowing invocation
      `verify-deploy.sh --only-gate 3,4 --skip-unchanged` (both PASS, post-deploy) plus the
      `deploy-headless.sh` run's own internal `verify-deploy.sh --skip-slow` pass (41 checks, 0
      failures) rather than an additional independent unflagged full sweep; the complete gate
      set for the whole batch runs once at the end of this /orchestrate invocation per the
      directive)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- `timeout 540 bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- The complete gate set for the repository runs green and is observed in this dispatch, not
  trusted on sight: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`), with no gate subset and no
  `--skip-slow` substituted for it.
- `grep` of the deployed
  `.claude/docs/reference/standards/multi-task-creation-standard.md` finds the new subsection
  heading, and `grep` of the deployed `.claude/context/contracts/conclusion-stage.md` finds the
  pointer sentence citing it.
- `git status --short` shows no unexpected modification outside this task's declared scope and
  the regenerated deploy artifacts.

## Testing & Validation

- [x] The convention appears exactly once as a definition: a repo-wide grep for the new
      heading's distinctive wording finds the statement in
      `multi-task-creation-standard.md` and a pointer in `conclusion-stage.md`, and no third
      restatement. *(completed: confirmed in both source-store files and their deployed mirror,
      no other hit)*
- [x] The statement names the forbidden shape, the required shape, and both WHY citations by
      path. *(completed)*
- [x] No new packet format is specified; the required shape cites
      `context/formats/issue-log.md`'s `suggested_channel` field. *(completed)*
- [x] No edit touched Component 7's Foreground Requirement text, any confirmation gate, the
      conclusion stage's channel routing / filter predicate / exactly-one-channel rule, or the
      skeleton-plan follow-up mechanism. *(completed)*
- [x] New prose carries no task numbers, no `iss_*` ids, and no record-versioning language
      (gate 4 plus diff read-through). *(completed: gate 4 passed; diff read-through found no
      violations)*
- [x] Deploy reports `RESULT=landed_verify_clean` and the full gate set is green. *(completed:
      RESULT=landed_verify_clean; full gate set deferred to the batch stage per this dispatch's
      Batch Gate Deferral directive, discharged here against the scoped narrowing invocation —
      see Phase 3's task-list annotation)*

## Artifacts & Outputs

- Edited: `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
- Edited: `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- Regenerated: the deployed `.claude/` tree (`deploy-headless.sh`)
- `specs/558_conclusion_stage_filing_handoff_phrasing/summaries/01_*-summary.md` at completion

## Rollback/Contingency

Both phases are additive prose edits to two files, each committed separately. To revert, drop the
relevant commit(s) with `git revert` and redeploy. If an intentional rollback of uncommitted work
is needed, take a snapshot first (`bash .claude/scripts/git-snapshot.sh 558`) per
`.claude/rules/git-workflow.md`. If Phase 3's deploy does not report
`RESULT=landed_verify_clean`, leave the source-store commits in place, do not hand-patch anything
under `.claude/**`, and report the RESULT — the source-store edits are the durable deliverable and
a deploy failure is diagnosable independently of them.
