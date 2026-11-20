# Implementation Plan: Task #667

- **Task**: 667 - Amend branch-topology rulings R1-R3 and R5: per-batch worktree side branches with per-task squash landing onto the long-lived feature branch
- **Status**: [IMPLEMENTING]
- **Effort**: 8.5 hours
- **Dependencies**: None declared. Successor tasks created by Phase 3 depend on this task and on 513, 517, 553 as ruled in Phase 4.
- **Research Inputs**: specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_batch-worktree-squash-amendment.md
- **Artifacts**: plans/01_batch-worktree-squash-amendment.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task rules first and implements second, and it is sized honestly: the description says
"expect to expand", and the research report measures the two-root audit alone at 194 files plus
27 instruction documents. That does not fit one plan of two-hour phases. This plan therefore
delivers three things inside this task and hands the rest to successor tasks it creates:

1. **The ruling** (Element 1): the amending decision record and the dated amendment notes.
2. **The urgent repair** (defect D1): `milestone-ref-land.sh --verify` is fixed now, because it
   strands finished tasks at `[IMPLEMENTING]` today, independently of any topology change.
3. **The decomposition** (Elements 2 to 7): eight successor task records carrying the rulings,
   the revision of 655 and 666, and the dependency edges.

Elements 2 to 7 are NOT implemented by this task. The description's verification criteria that
describe running behaviour (admission refusal, one worktree per batch, one squash per task,
cleanup) are assigned, criterion by criterion, to the successor task that owns each; Phase 3
writes that assignment into each successor's description so none is dropped.

Every source-store edit targets `agent-system/extensions/core/**` in this repository, never a
deployed `.claude/**` path, and carries no task-number reference and no record-versioning
language. Decision records live under `specs/decisions/`, where both are permitted.

### Unconfirmed Assumption (not a user ruling)

The research report raised one non-blocking user decision that the user has not answered:
whether, in a repository where `specs/` is tracked, bookkeeping commits keep landing directly on
the integration branch between the per-task squash commits, or are held and folded into each
squash. **This plan proceeds on the research recommendation: bookkeeping commits land directly,
as today, and the squash carries code only.** That is an assumption, not a decision the user
made. Phase 1 records it in the amending record under an explicit "Unconfirmed assumption"
heading, and Phase 3 writes it into the description of the successor task that owns the commit
scripts, with the instruction to re-plan that task's two-root split if the user answers the
other way. Nothing built inside this task depends on it.

### Research Integration

Adopted from the report's Decisions section, with the planner's own calls marked:

- The amendment is sound. All five recorded defects are properties of the removed per-dispatch
  layer, not of `git worktree`. Three further recorded hazards (HEAD-stale `specs/`, deferral
  invisibility, agent-tool isolation forwarding and raw `git` in the worktree) must be engaged
  by name.
- Three modifications to the proposed rulings: the "`specs/` is gitignored" premise is false
  here; the symlink candidate is rejected; landing uses attribution (`git cherry-pick -n` of the
  task's own commits), not `git merge --squash` of an end commit.
- Lean repositories: Option L1 (per-repository opt-out). L2 is deferred with a stated spike
  protocol. **Planner's call:** the L2 spike is recorded in the amending record as deferred and
  is not created as a task; the user said either option is acceptable and L1 is ruled.
- `milestone-ref-land.sh` is retired as a landing mechanism by a successor; its `--verify` is
  repaired here first.
- **Planner's call:** the report lists four harness behaviours it could not measure from a
  dispatched agent (file-tool prompts for a worktree outside the project directory, path-scoped
  rule matching there, the working directory a hook process receives, subagent cwd). The
  worktree-siting ruling rests on them. Phase 1 records them as a named precondition, and
  Phase 3 creates a measurement task that every two-root successor depends on.

### Premise Re-Validation

Checked against live state before this plan was written:

1. **Source store: CONFIRMED.** `.extensions.core.source_dir` resolves to
   `agent-system/extensions/core` in this repository.
2. **"`specs/` and `.claude/` are gitignored": REFUTED for `specs/`, as the report found.**
   `git check-ignore -v specs .claude agent-system` matches only `.gitignore:6:/.claude/`.
3. **`integration_branch` undeclared (D3): CONFIRMED.** `jq 'del(.extensions)'
   .claude-extensions.json` returns only `version`.
4. **D1 script citations: CONFIRMED.** The ancestry assertion is at `milestone-ref-land.sh`
   line 97; `parent="$old_tip"` at lines 158 to 166. The postflight call site is
   `orchestrate-cycle-postflight.sh` lines 1378 to 1384, including the "Re-run to retry the
   landing" text, and `milestone_landing_refusal` gates the status write at three later sites.
5. **Context budget: CONFIRMED.** `skill-orchestrate/SKILL.md` is 27,494 bytes and
   `commands/orchestrate.md` 21,496 bytes. No phase of this plan edits either.
6. **Related records: CONFIRMED.** 655 is `not_started` with dependencies
   `[513, 517, 553, 654, 657]` and seven `file_scope` entries; 666 is `not_started` with none.
   Commit `7231ccbe2` changed `specs/state.json` and `specs/ROADMAP.md` only. Whether it fully
   applied 666's work is not re-derived here; Phase 4 checks it.
7. **Every correction target exists: CONFIRMED** for `milestone-ref-land.sh`,
   `tests/test-milestone-ref-land.sh`, `orchestrate-cycle-postflight.sh`,
   `tests/test-orchestrate-cycle-postflight.sh`, and the two decision records to be amended.
8. **No context file states the ancestry predicate.** A case-insensitive grep for `ancestor` in
   `ref-plumbing-landing.md`, `conclusion-stage.md` and `git-workflow-narrative.md` finds
   nothing; the narrative names `milestone-ref-land.sh --verify` only generically (line 258).
   The predicate is described in the script's own header, which Phase 2 edits.

Carried from the report and NOT re-derived (CARRIED-UNVERIFIED, source: the research report):
the fixture results for attribution landing, back-merge, compare-and-swap deletion and the six
`git-commit-scoped.sh` wrong-root cases; the 168-row and 194-file enumeration counts; the Lean
repository sizes; the claim that 536 and 567 precede 655 transitively through 553. The first
four are cited in the amending record as the report's measurements, attributed to it. The last
is re-checked in Phase 4 before any edge is written.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied in this dispatch, so roadmap context was not loaded. One fact was
observed while checking related records: 655 is the single member of a `--hard` batch under
milestone M1. This plan writes no roadmap entry. Siting the successor tasks into batches, and
re-siting or removing 655's batch after its scope shrinks, is recorded in the implementation
summary as a follow-up for `/roadmap`.

## Goals & Non-Goals

**Goals**:
- A decision record that amends R1, R2, R3 and R5, states the R6 consequence, and engages every
  recorded defect and hazard by mechanism.
- Dated `**Amended by**` notes on `branch-topology-and-landing-strategy.md` and
  `commit-layer-cluster-ordering.md`.
- A `--verify` that passes when the landed tree is correct, still fails when work did not land,
  and a postflight message that no longer sends an operator into an unbounded retry.
- Successor task records that together cover Elements 2 to 7 and every running-behaviour
  verification criterion in the description, with dependency edges written.
- 655 and 666 revised so neither carries a stale description.

**Non-Goals**:
- Building admission, the batch worktree, the two-root contract, attribution landing, cleanup,
  or the Element 7 documentation rewrite. Each belongs to a named successor.
- Retiring `milestone-ref-land.sh`. It is repaired here and retired by the landing successor.
- Declaring `integration_branch` in this repository's `.claude-extensions.json`. The key and
  its schema row belong to the admission successor.
- Re-opening R4, R7 or R8.
- Any edit to `skill-orchestrate/SKILL.md` or `commands/orchestrate.md`.
- Any roadmap entry.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The user expected Elements 2 to 7 built inside this task | M | M | The split is stated at the top of this plan and in the dispatch return; each criterion is assigned to a named successor so nothing is silently dropped |
| The unanswered bookkeeping-commit question is later answered the other way | M | L | Recorded as an unconfirmed assumption in the record and in the owning successor's description; nothing built here depends on it |
| The repaired `--verify` becomes a check that cannot fail | H | L | Phase 2 ships a deliberate negative fixture and requires it to be observed failing before the phase closes |
| A sibling commit lands on the work branch between landing and verify, so tree equality fails on correct work | M | L | The failure is now recoverable: a re-run lands the current tree and passes. The message says so and bounds the retry |
| Successor descriptions drift from the decision record | M | M | Each description cites the record by filename and section instead of restating rulings at length |
| The backlog audit flags a successor as a duplicate of 655 | L | H | Expected, since 655 is being superseded. Phase 4 revises 655 in the same dispatch; Phase 3 records each audit verdict and the reason for proceeding |
| Harness behaviour refutes external worktree siting | H | M | Recorded as a named precondition; the measurement task precedes every two-root successor and the record states the fallback procedure (amend the siting ruling, do not work around it) |
| Phase 2 shares `orchestrate-cycle-postflight.sh` with the not-started commit-layer chain | L | L | Territory overlap only matters for concurrent admission; no chain member is in flight |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 3 |
| 4 | 5 | 2, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Write the amending decision record and the amendment notes [COMPLETED]

**Goal**: The amendment exists as a durable decision record that a successor task can cite, and
both amended records point at it.

**Tasks**:
- [x] Read in full, before writing anything: `specs/decisions/branch-topology-and-landing-strategy.md`,
      `specs/decisions/worktree-isolation-removal-verdict.md`,
      `specs/decisions/worktree-isolation-removal-reaffirmation.md`,
      `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`,
      and the Judgment calls, Edges and Inputs sections of
      `specs/decisions/commit-layer-cluster-ordering.md`. The research report's summary of them
      does not substitute for this read. If the archive path is absent, locate the report with
      `find specs -name '02_worktree-isolation-reopened.md'` and record the path actually read. *(completed: archive path was present; all five sources read in this dispatch)*
- [x] Write `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` with these
      sections: *(completed)*
  - **Authority**: the user's 2026-11-20 decision, in the words the task description records,
    and the statement that R4, R7 and R8 are not re-opened.
  - **Defects engaged**: one entry per recorded defect (destructive release on
    `nothing_to_land`; worktree-blind root in `git-commit-scoped.sh`; `lake-build-guard.sh`
    false green; tasks marked completed with stranded commits; repo-scanning pollution) and per
    omitted hazard (HEAD-stale `specs/`; deferral invisibility; agent-tool isolation forwarding
    and raw `git` in the worktree). Each names the recorded mechanism and states why the amended
    design cannot reproduce it, or states plainly that it is closed only by named successor
    work. The wrong-root defect is stated as NOT closed by design.
  - **Rulings**: R1 (primary tree stays on the declared integration branch; admission refuses
    on another branch or on dirty tracked paths outside the state territory; a blanket clean
    test is refused and why). R2 (one branch and one worktree per invocation, cut from the
    integration tip, named from the session identity, reused on resume, sited outside the
    repository in a per-user state directory, recorded in a batch record under the primary
    tree's state directory, sparse without `specs/` where `specs/` is tracked). R3 (one squash
    commit per completed task, built by attribution, refusing on an unattributable commit or a
    pick conflict, verified by blob equality over the task's own path set strictly before the
    status write, idempotent). R5 (batch granularity only; nothing cloned, hardlinked or
    symlinked, build directories included; per-dispatch worktrees and the harness per-agent
    worktree option stay removed; isolation is a per-repository declaration). R6 consequence
    (the expected ref becomes per tree; Judgment 1's condition fires).
  - **Rejected alternatives**, each on its own merits: symlinking `specs/` and `.claude/`;
    `git merge --squash` of an end commit; full-tree equality as the landing predicate; a
    worktree inside or beside the repository; Option L2 as a design; a plumbing squash inside
    one shared tree for isolation-off repositories.
  - **Isolation-off repositories (Option L1)**: what such a repository gets (the admission
    branch check, phase commits landing directly as today) and what it loses (the per-task
    squash), stated plainly. The L2 spike protocol, recorded as deferred.
  - **Built-mechanism verdicts**: D1 to D4, the retirement of `milestone-ref-land.sh` as a
    landing mechanism, the repaired `--verify` predicate, and the verdict on the postflight
    refusal and its retry message.
  - **Cleanup and retention**: the removal precondition including ignored files, removal
    without force, compare-and-swap branch deletion against the proven tip, the mixed
    landed-and-retained batch, and report-only `/refresh`.
  - **Costs**: unserialized builds across trees, disk per batch, deploy ordering (land,
    redeploy, verify), `lean-lsp` and Sapience registrations.
  - **Unconfirmed assumption**: the bookkeeping-commit question, both options, the option this
    record proceeds on, and the statement that the user has not ruled.
  - **Measured precondition**: the four unmeasured harness behaviours, and the rule that a
    refuting measurement amends the siting ruling by a dated note instead of being worked
    around.
  - **Edges** and **Successor tasks**: left as headed placeholders stating that Phases 3 and 4
    fill them.
- [x] Attribute every measurement to its source: "measured in the research report" for the
      carried fixture results, with the report's path; "re-derived at plan time" for the eight
      items in this plan's Premise Re-Validation. *(completed)*
- [x] Append a dated note to `specs/decisions/branch-topology-and-landing-strategy.md` in the
      shape `**Amended by** batch-worktree-isolation-and-task-squash-landing.md, 2026-11-20:`
      naming R1, R2, R3 and R5 as amended and R6 as carrying a consequence. Do not rewrite the
      original rulings. *(completed)*
- [x] Append a dated note in the same shape to `specs/decisions/commit-layer-cluster-ordering.md`
      recording that Judgment 1's stated condition ("reinstates any form of tree isolation") has
      fired, and that source-store commit scoping and the third containment site become semantic
      predecessors of the two-root work. Place it beside the existing amendment note, not in
      place of it. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: Every touched path lies under `specs/**`, so sub-case (a) applies and the covering check is the `prose` row's diff read-through of the three decision-record files.

**Files to modify**:
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - new: the amending record
- `specs/decisions/branch-topology-and-landing-strategy.md` - one dated amendment note appended; exists (confirmed at authoring time); if absent, STOP and report, since there is then nothing to amend
- `specs/decisions/commit-layer-cluster-ordering.md` - one dated amendment note appended; exists (confirmed at authoring time); if absent, write the same content into the new record's Edges section and say so there

**Verification**:
- The new record contains one entry for each of the five defects and each of the three omitted
  hazards, checked by reading its "Defects engaged" section against the list above.
- `grep -c '^\*\*Amended by\*\* batch-worktree-isolation-and-task-squash-landing.md' ` returns 1
  for each of the two amended records.
- The record's "Unconfirmed assumption" section states that the user has not ruled.
- `git diff` on the two amended records shows additions only.

---

### Phase 2: Repair the landing verification and its retry message [COMPLETED]

**Goal**: `milestone-ref-land.sh --verify` reports a landing as landed when its tree is correct,
still fails when work did not land, and the postflight refusal no longer advises an unreachable
retry.

**Tasks**:
- [x] In `milestone-ref-land.sh`, replace the ancestry assertion in `--verify` mode with tree
      equality: pass exactly when the milestone ref exists and
      `git rev-parse "<ref>^{tree}"` equals `git rev-parse "HEAD^{tree}"`. Keep the existing
      exit codes (0 landed or no milestone membership, 1 not landed). *(completed)*
- [x] In landing mode, make a landing of an unchanged tree a no-op: when the ref exists and its
      tip tree already equals the tree being landed, create no commit and exit 0 with a NOTE
      line. This is what makes a re-run converge instead of extending the chain. *(completed)*
- [x] Record the source commit in each landed commit's message as a trailer line, so a verify
      failure can name which commit the ref last landed from. Use it only in the failure
      message; the pass or fail decision is the tree comparison above. *(completed: trailer is `Landed-From: <sha>`)*
- [x] Make the `--verify` failure message state the two trees compared and whether the work
      branch has advanced since the last landing. *(completed)*
- [x] Update the script's header comment (usage, `--verify` description, exit codes) to describe
      the predicate as it now is. State the current behaviour only. *(completed)*
- [x] In `orchestrate-cycle-postflight.sh`, replace the "Re-run to retry the landing" text at
      the `MILESTONE-LANDING` notice. The new text says that a re-run lands the current tree,
      and that a second identical refusal with an unchanged `HEAD` means stop and report, not
      retry again. Change no control flow: the refusal of the completion status write on a
      genuine verify failure stays. *(completed)*
- [x] In `tests/test-milestone-ref-land.sh`, add or rewrite cases: (a) three landings in
      sequence each pass `--verify`; (b) the negative fixture, a commit made after the last
      landing, makes `--verify` exit 1; (c) landing an unchanged tree creates no commit;
      (d) a ref whose chain already diverged from the work branch by the old parenting passes
      `--verify` when its tip tree matches, and otherwise is repaired by one landing;
      (e) a missing ref still exits 1. Remove or rewrite any case that asserts the ancestry
      behaviour. *(completed: 13 cases pass; existing Case 5 covers the missing ref)*
- [x] Observe case (b) fail the check before it is accepted: temporarily confirm the assertion
      fires (for example by running the case's verify call by hand in the fixture and reading
      exit 1), and record that observation in the phase's progress notes. Leave no deliberate
      break in the tree. *(completed: observed twice -- the case exits 1 under the repaired script, and a scratch copy with the comparison forced true fails the negative-fixture and diverged-chain cases; no break left in the tree)*
- [x] In `tests/test-orchestrate-cycle-postflight.sh`, update any case that matches the old
      notice text, and keep the cases asserting that a verify failure refuses the status write. *(deviation: altered — no case matched the old notice text, so none needed updating; one assertion was added that the notice names the re-run effect and bounds the retry)*
- [x] Re-run the Premise Re-Validation grep: confirm no file under
      `agent-system/extensions/core/context/` describes the verify predicate as ancestry. If one
      does, do not edit it in this phase; record it for the documentation-parity successor in
      the summary. *(completed: no context file states the predicate as ancestry)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: Exactly four source-store files change, and no `context/**` file needs
editing because none states the ancestry predicate (grep at authoring time found none). Confirm
at implementation time with `grep -rniE 'ancestor' agent-system/extensions/core/context/` and
`grep -rn 'Re-run to retry the landing' agent-system/extensions/core/`; a hit outside the four
declared files is recorded for the documentation-parity successor, not edited here.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's four `Files to modify` paths covers the edit; the selector, run once over that set at authoring time, returned `test-milestone-ref-land.sh` and `test-orchestrate-cycle-postflight.sh` together with `test-corroborate-phase-counts.sh`, `test-deploy-baseline-lib.sh`, `test-force-phases.sh`, `test-gate-out-derived-staleness.sh`, `test-git-commit-scoped.sh`, `test-handoff-dispatch-identity.sh`, `test-handoff-reader-parity.sh`, `test-lint-deliberate-break-residue.sh`, `test-lint-json-channel-discipline.sh`, `test-milestone-review-handoff.sh`, `test-orchestrate-context-growth.sh`, `test-orchestrate-cycle-plan.sh`, `test-orchestrate-recover-message-findings.sh`, `test-run-task-observers.sh`, `test-sapience-mcp-registration.sh`, `test-skill-base-lifecycle.sh` and `test-stall-reprompt-wiring.sh`.

**Files to modify**:
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` - tree-equality `--verify`, no-op re-landing, source-commit trailer, header comment
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` - sequence, negative, no-op, diverged-chain and missing-ref cases
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - the `MILESTONE-LANDING` notice text only
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - notice-text expectations

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` passes, and the
  negative case was observed to exit 1.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` passes.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over the four paths reports a
  green narrowed verdict.
- `grep -n 'is-ancestor' agent-system/extensions/core/scripts/milestone-ref-land.sh` returns
  nothing in `--verify` mode.
- `grep -rn 'Re-run to retry the landing' agent-system/extensions/core/` returns nothing.
- The task-reference and record-versioning lints report no new finding in the four files.

---

### Phase 3: Create the successor task records [NOT STARTED]

**Goal**: Elements 2 to 7, and every running-behaviour verification criterion in the task
description, are owned by a task record that cites the amending record.

**Tasks**:
- [ ] Create each task below through the sanctioned creation path in
      `agent-system/extensions/core/commands/task.md` (Create Task mode, Step 6):
      `audit-task-proposals.sh` for the backlog verdict, then `state-write.sh` with
      `--audit-verdict` and `--regen-todo`, then the topic registration that step requires. Use
      topic `orchestrator` and task type `meta`. Never hand-roll a `jq ... > tmp && mv` write.
      A duplicate-of-open verdict naming 655 is expected; record each verdict and the reason
      for proceeding (655 is revised in Phase 4) in the amending record's "Successor tasks"
      section.
- [ ] Every description opens with the two standing constraints (source store is the edit
      target with redeploy; no task-number references or record-versioning language under
      `agent-system/**`), cites
      `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` by section for its
      rulings instead of restating them, names the report and
      `reports/01_two-root-consumers.tsv` where relevant, states that the design must hold with
      isolation declared off, forbids new prose in `skill-orchestrate/SKILL.md` and
      `commands/orchestrate.md`, and lists the verification criteria it owns.
- [ ] The eight successors, in dependency order:
  1. **Harness measurement for an external worktree.** Measure, in a live session, whether file
     tools prompt or refuse for a path outside the project directory, whether path-scoped rules
     apply there, what working directory a hook process receives, and what cwd a subagent gets.
     Deliverable: a measurement record under `specs/decisions/`, and a dated amendment to the
     siting ruling if any result refutes it. Flag in the description that parts may need the
     user at the keyboard.
  2. **Declarations, admission and batch setup** (Element 2, D3). The `integration_branch` and
     isolation keys and their schema rows in `context/standards/repo-level-declarations.md`; the
     branch and dirtiness assertion in `orchestrate-cycle-plan.sh`'s preflight; the batch
     record; idempotent worktree creation, sparse where `specs/` is tracked; composition with
     task-lock, session-registry, orchestration-queue and `MAX_TASKS`. Owns: "an invocation
     started off the integration branch or on a dirty primary tree is refused at admission" and
     "a multi-task batch produces one worktree and one batch branch".
  3. **Two-root contract in the dispatch composer and the commit scripts** (Element 3, core).
     An explicit code-root parameter carried in the dispatch file by
     `orchestrate-build-dispatch.sh`; `git-commit-scoped.sh`, `git-commit-phase.sh`,
     `git-snapshot.sh`, `verify-touched.sh`, `orchestrator-postflight.sh`, `skill-base.sh` and
     the `lake-build-guard.sh` callers made two-root aware; a code pathspec with no code root
     is refused before staging while a batch record is live, so the silent exit-1 case cannot
     be reached. Carries the unconfirmed bookkeeping-commit assumption and the instruction to
     re-plan if the user answers otherwise. Owns: "no script commits from the wrong root, and a
     wrong-root invocation refuses loudly" for the commit path.
  4. **Two-root contract in the hooks.** `guard-destructive-git.sh` evaluates the tree the
     command targets; write-time hooks refuse an edit to a tracked non-state path under the
     primary root while a batch record is live; the payload-path hooks and libraries the
     report's cross-check found are classified. Owns the hook half of the wrong-root criterion.
  5. **Two-root classification of the remaining consumers.** Classify every row of
     `reports/01_two-root-consumers.tsv` plus the cross-check files and the instruction
     documents that invoke `.claude/scripts/` by relative path, as code-root, state-root or
     both; fix each that is wrong. The description states the report's counts as a hypothesis
     to re-derive, and carries its coverage caveat about consumers that reach a root only
     through a sourced library.
  6. **Per-task attribution landing and its verification** (Element 4). Landing in postflight
     under the commit mutex; blob-equality verification before the status write; the negative
     fixture; the two-concurrent-batches conflict fixture with refusal and resume; source-store
     commits in a second repository; retirement of `milestone-ref-land.sh` as a landing
     mechanism and retargeting of `milestone-review-handoff.sh`'s review range. Owns: "one
     squash commit per completed task on the integration branch with its phase list in the
     body, the primary tree never having changed branch" and "a task failing mid-batch leaves
     its commits, branch and worktree intact while its sibling lands".
  7. **Cleanup, retention and orphan reporting** (Element 5). The removal precondition
     including ignored files, unforced removal, compare-and-swap branch deletion, the mixed
     batch, and report-only `/refresh`. Owns: "after a fully landed batch the worktree and
     branch are gone; after a partial one they remain".
  8. **Documentation parity** (Element 7). `git-workflow-narrative.md`'s Branch Strategy
     section, `ref-plumbing-landing.md`, the branch-target rule in `rules/git-workflow.md`, the
     schema rows' prose, and `index-entries.json` line counts. Current design only. Owns: "the
     rules, the narrative and the scripts state the same contract".
- [ ] Give each successor a `file_scope` naming the source-store files its description lists,
      using on-disk paths under `agent-system/extensions/core/`. Do not declare a directory.
- [ ] Fill the amending record's "Successor tasks" section: one row per successor with its
      assigned number, its slug, the elements and criteria it owns, and its audit verdict.
- [ ] Check coverage in both directions: every sentence of the description's VERIFICATION
      block that describes running behaviour appears in exactly one successor's owned list, and
      "both worktree records are engaged defect by defect" is marked as discharged by Phase 1.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: Eight successor tasks are created. The count is a planning estimate: if
writing a description shows two units cannot be separated, or one must split, create the number
the work requires and record the reason in the amending record's "Successor tasks" section.
Confirm with `jq '.next_project_number' specs/state.json` before and after.

**Tier Justification**: `bash .claude/scripts/validate-state.sh` is the specific check covering a `specs/state.json` task-record write, run together with the diff read-through of the decision record.

**Files to modify**:
- `specs/state.json` - new successor task records; `next_project_number` advanced
- `specs/TODO.md` - regenerated view of the above
- `specs/ROADMAP.md` - generated from `specs/state.json`; regenerate with `bash .claude/scripts/roadmap-integration.sh --regenerate` in this phase if the new records change its rendering, and never hand-edit it
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - "Successor tasks" section filled

**Verification**:
- `bash .claude/scripts/validate-state.sh` passes.
- `jq` over `specs/state.json` shows each new record with status `not_started`, type `meta`, a
  non-empty `file_scope`, and a description citing the amending record's filename.
- The amending record's "Successor tasks" table has one row per record created, and the
  coverage check above is recorded there with no unowned criterion.
- `git diff --stat` shows no change outside `specs/`.

---

### Phase 4: Revise the superseded records and write the dependency edges [NOT STARTED]

**Goal**: 655 and 666 state their real remaining scope, and the dependency graph orders the
successors.

**Tasks**:
- [ ] Re-read 655's description from `specs/state.json` and identify its Element F
      (generated-file declaration). Rewrite the description with `state-write.sh` (jq filter,
      `--arg`, `--regen-todo`) so Element F is its whole remaining scope, with one paragraph
      stating that its topology elements are superseded by the amending record and naming the
      successor that owns each. Remove the stacked override blocks; do not append a fourth.
      If Element F cannot be identified in the description, do not guess: leave the description
      as it is, add the supersession paragraph only, and report this in the summary.
- [ ] Narrow 655's `file_scope` to the files Element F touches, only if the description makes
      them identifiable. Otherwise leave it and record why.
- [ ] Leave 655's existing dependency edges in place. Record in the amending record's Edges
      section that they are retained and which of them the narrowed scope no longer needs.
- [ ] Settle 666: compare the authored batch positions in `specs/state.json`'s
      `roadmap_milestones[].batches[]` against the outcome its description requires (the batch
      holding 655 sits after the last batch holding one of 655's prerequisites; no task in two
      batches; no batch lost a member). Write the finding into 666's description with
      `state-write.sh`: either "already applied by commit `7231ccbe2`, recommended for
      abandonment" with the evidence, or the precise remainder. Do not abandon it; abandonment
      is the user's `/task --abandon`, named in the summary as a follow-up.
- [ ] Before writing any edge, re-check the carried claim that 536 and 567 precede the commit
      scripts' work through 553: read the `dependencies` arrays of 553, 536 and 567. At plan
      time 553 lists `[536, 548]` and 567 lists none, so 567 is NOT shown to be transitive
      through 553. If that still holds, add 567 as a direct predecessor of successor 3.
- [ ] Write the edges with
      `bash .claude/scripts/update-task-status.sh preflight <N> edge_only "$session_id" --depends-on-add='[...]'`
      and let its cycle refusal run. Planned edges, by successor number from Phase 3's list:
      1 on 667; 2 on 667, 517 and 1; 3 on 2, 513 and 553 (and 567 per the check above); 4 on 2
      and 1; 5 on 3; 6 on 3 and 4; 7 on 6; 8 on 5, 6 and 7. If a write is refused, record the
      refusal and its reason in the Edges section instead of forcing it.
- [ ] Fill the amending record's Edges section with the `dependencies` arrays as written,
      quoted from `specs/state.json`, and the edges deliberately not written with reasons.
- [ ] Regenerate `specs/TODO.md` if any write omitted `--regen-todo`, and regenerate
      `specs/ROADMAP.md` if its rendering changed.

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: Two existing records are revised (655, 666) and the edge set above is
written across eight successors. The edge list is a hypothesis that depends on Phase 3's final
successor count and on the 553/567 check; confirm each edge against the live `dependencies`
arrays after writing, and treat the list quoted in the decision record as the result.

**Tier Justification**: `bash .claude/scripts/validate-state.sh` is the specific check covering dependency-edge and description writes to `specs/state.json`, and `update-task-status.sh`'s own write-time cycle refusal covers each edge.

**Files to modify**:
- `specs/state.json` - 655 and 666 descriptions; 655 `file_scope` where identifiable; successor `dependencies`
- `specs/TODO.md` - regenerated view of the above
- `specs/ROADMAP.md` - generated; regenerated here if its rendering changed, never hand-edited
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` - Edges section filled

**Verification**:
- `bash .claude/scripts/validate-state.sh` passes.
- `jq -r '.active_projects[]|select(.project_number==655)|.description' specs/state.json`
  contains no `BINDING CONSTRAINT` override block and names the amending record.
- 666's description states its disposition with evidence.
- Each successor's `dependencies` array in `specs/state.json` matches the Edges section.
- 666 is still present in `active_projects` (not abandoned by this phase).

---

### Phase 5: Redeploy and close [NOT STARTED]

**Goal**: The deployed tree carries the repaired scripts, and the task's own work is verified
together.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` from the repository
      root so the deployed `.claude/scripts/` copies of the two edited scripts match the source
      store. Do not hand-edit anything under `.claude/`.
- [ ] Confirm the deployed copies match: `diff` each of the two edited scripts against its
      deployed counterpart under `.claude/scripts/`.
- [ ] Confirm no manifest change is owed: this task adds no script, so
      `bash .claude/scripts/sync-manifest-scripts.sh --check` should report no gap. If it
      reports one, the gap predates this task; record it and do not widen scope.
- [ ] Run the scoped touched-path check over the task's source-store paths.
- [ ] Write the implementation summary. It must state, as follow-ups: the successor tasks by
      number; `/roadmap` siting for them and for 655's batch; `/task --abandon 666` if Phase 4
      found it applied; the unanswered bookkeeping-commit question; and, for any deploy
      consumer repository with tasks stranded at `[IMPLEMENTING]` by D1, that redeploying there
      and re-running the orchestration is the recovery route.

**Timing**: 1 hour

**Depends on**: 2, 4

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:
- Under `/orchestrate`, this phase's own obligation is the scoped touched-path check,
  `bash agent-system/extensions/core/scripts/verify-touched.sh` over the four Phase 2 paths,
  observed green. The complete gate set is deferred to the orchestration close and is not run
  independently here. In a standalone, non-orchestrated run, `bash .claude/scripts/verify-deploy.sh`
  is run directly instead.
- `diff` reports no difference between each edited source-store script and its deployed copy.
- `bash .claude/scripts/validate-state.sh` passes.
- The summary lists every follow-up named above.

## Testing & Validation

- [ ] Three sequential landings each pass `--verify`; a commit made after the last landing makes
      it exit 1; the failing case was observed to fail.
- [ ] A re-landing of an unchanged tree creates no commit.
- [ ] A verify failure still refuses the completion status write in postflight.
- [ ] The amending record engages five defects and three omitted hazards by mechanism.
- [ ] Both amended records carry exactly one new note naming the amending record.
- [ ] Every running-behaviour verification criterion in the task description is owned by
      exactly one successor task.
- [ ] `validate-state.sh` passes after Phases 3 and 4.
- [ ] No file under `agent-system/**` gains a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`: the amending record.
- Dated amendment notes on `specs/decisions/branch-topology-and-landing-strategy.md` and
  `specs/decisions/commit-layer-cluster-ordering.md`.
- Repaired `agent-system/extensions/core/scripts/milestone-ref-land.sh` and its suite; revised
  notice text in `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` and its
  suite.
- Eight successor task records (count subject to Phase 3's Scope Hypothesis), with edges.
- Revised descriptions for 655 and 666.
- `specs/667_amend_branch_topology_per_batch_worktree_squash/summaries/01_batch-worktree-squash-amendment-summary.md`.

## Rollback/Contingency

- **Phase 1** is additive under `specs/decisions/`. Revert by removing the new record and the
  two appended notes with a scoped commit revert.
- **Phase 2** is four files. If the repaired check misbehaves, revert those four files with
  `git revert` of the phase commit and redeploy; the previous behaviour (strands tasks, never
  destroys work) returns. Take a `git-snapshot.sh 667 --no-revert` checkpoint only if a risky
  intermediate state needs one; no rollback snapshot is planned.
- **Phases 3 and 4** write task records and edges. A wrongly created successor is abandoned by
  the user with `/task --abandon`; a wrong description is rewritten with `state-write.sh`. A
  dependency edge cannot be removed by the sanctioned edge writer, so a refused or doubtful edge
  is left unwritten and recorded, not forced.
- **If Phase 1's full read of the binding records contradicts the research report** on any
  defect's mechanism, the record follows the binding records, states the disagreement, and
  Phase 3 is re-scoped from the record as written. If the read shows the amendment unsound, the
  deliverable becomes a written refusal with evidence in the same file, Phases 3 and 4 are
  closed with reasoned exclusions, and Phase 2 still ships.
