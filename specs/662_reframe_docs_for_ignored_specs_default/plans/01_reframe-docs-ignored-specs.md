# Implementation Plan: Task #662

- **Task**: 662 - Reframe docs for ignored-specs default
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None (consumes the landed outputs of tasks 658-661)
- **Research Inputs**: specs/662_reframe_docs_for_ignored_specs_default/reports/01_reframe-docs-ignored-specs.md
- **Artifacts**: plans/01_reframe-docs-ignored-specs.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Reframe every documentation surface in `agent-system/extensions/core/**` that states or implies,
as an invariant, that the `specs/` tree is committed to git, so that a gitignored `specs/` tree
reads as a first-class supported posture rather than a broken state. Each reframed surface states
what the two postures share (the lifecycle event and the commit *attempt*) and what differs (the
outcome: a commit, versus `git-commit-scoped.sh`'s non-failure V13 skip at exit `8`/`9`), pointing
at `context/standards/git-staging-scope.md`'s "Per-Operation Contract: Tracked vs. Gitignored
`specs`" section rather than re-deriving the explanation in each location. Task 661's drafted
durability statement is placed verbatim in `context/standards/orchestrator-runtime-files.md`'s
Fresh-Repo Default section. The two exemption standards and the two already-correct files the
research report cleared are explicitly out of the edit set.

### Research Integration

The research report changes the edit set materially and the plan is built on its findings, not on
the dispatch's grep-assembled list:

- **Dropped from the edit set** (named in the dispatch, cleared by direct reading):
  `rules/state-management.md` and `rules/artifact-formats.md` carry no commit-invariant assertion
  at all. No phase below touches either.
- **Highest-priority surface** is `docs/architecture/orchestrate-state-machine.md`, which the
  dispatch named but under-described: its `stall_suspected` detector is commit-gated by design,
  and under the ignored posture a fully successful `plan`-phase dispatch produces zero commits, so
  the detector's signal degrades for exactly the routine case. The fix is documentation-only —
  state the behaviour and name `stranded_suspected` (heartbeat-based, deliberately not
  commit-gated) as the detector that still covers it. No script logic changes.
- **Sweep-only surfaces the report found**: `docs/templates/README.md`'s 8-Stage Workflow Pattern
  and `commands/todo.md`'s Git Commit step.
- **Already correct, confirmed, no change**: both exemption standards (`git ls-files`-scoped, so
  gitignored paths self-exclude by construction), `context/standards/git-staging-scope.md`, and
  `context/standards/absent-specs-git-history.md`.
- **Durability statement placement**: end of `orchestrator-runtime-files.md`'s "Fresh-Repo
  Default: Whole `specs/` Tree Ignored" section, after the "Manual opt-in runbook" subsection and
  before `## Untracking Already-Committed Ephemeral Files`.

Two further surfaces were found by this planning pass's own confirmatory grep, beyond the
report's list, and are folded into Phase 5: `context/workflows/command-lifecycle.md` (lines 240,
411) and `context/orchestration/postflight-pattern.md` (line 327), each asserting "git commit
created" as a checkpoint/output with no posture qualifier.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch context; ROADMAP.md was not consulted and is not
modified.

## Premise Re-Validation (Carried-Figure Discipline)

Both lines the dispatch flagged were checked against live state during this planning pass:

1. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`"** — **Confirmed
   unchanged.** `.claude-extensions.json`'s `.extensions.core.source_dir` resolves to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, and all twelve surfaces the report
   names exist there at the stated paths. `deploy-headless.sh`, `verify-touched.sh`,
   `generate-context-line-counts.sh`, and `measure-eager-context.sh` all exist in that store.
2. **"The two exemption standards stay exactly as they are"** — **Confirmed correct and
   already satisfied.** `context/standards/task-reference-exemptions.md` (179 lines) and
   `context/standards/record-version-exemptions.md` (197 lines) both exist and both scope
   enforcement to `git ls-files` enumeration, which self-excludes gitignored paths by
   construction. No phase below edits either file; Phase 6 carries an explicit negative control
   asserting both are byte-unchanged.

## Goals & Non-Goals

**Goals**:
- No surface in the core source store asserts a committed `specs/` tree as an invariant.
- Each reframed surface states the behaviour under both postures, naming the V13 skip outcome.
- Task 661's durability statement is placed verbatim at the single best location.
- The two exemption standards are byte-unchanged.
- The deployed tree is regenerated and the gate set is green.

**Non-Goals**:
- No change to any script's logic — specifically not `orchestrate-cycle-postflight.sh`'s
  `stall_suspected` computation, which `stranded_suspected` already complements.
- No new standards file. `git-staging-scope.md`'s Per-Operation Contract stays the single source
  of truth every reframed surface points at.
- No edit to `rules/state-management.md`, `rules/artifact-formats.md`,
  `context/standards/git-staging-scope.md`, `context/standards/absent-specs-git-history.md`,
  `context/standards/task-reference-exemptions.md`, `context/standards/record-version-exemptions.md`.
- Not fixing `context/processes/implementation-workflow.md`'s pre-existing `**SUPERSEDED**`
  header, which the report flagged as an unrelated pre-existing record-versioning condition.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Gate 20 (eager context budget) fires: `rules/git-workflow.md` IS eager-loaded, measured at 70,472 B against a 71,600 B baseline — only 1,128 B of headroom | H | M | Phase 2 keeps its addition to a compact pointer paragraph (budget ≤ 400 B) with the full explanation living in the non-eager `git-staging-scope.md`, and runs `measure-eager-context.sh --check` as a phase verification criterion. Never move `baseline_bytes`; trim wording instead, per this field's own standing precedent |
| `index-entries.json` `line_count` drift blocks the deploy: four of the edit targets have indexed rows, and `check-extension-docs.sh` Rule R fails on a mismatch, which fails `verify-deploy.sh` Gate 3 | H | H | Every phase editing an indexed `context/**` file declares `index-entries.json` in its own `Files to modify` and runs `generate-context-line-counts.sh --write` in that same phase (see each phase's tasks) |
| Two phases racing on `index-entries.json` | M | M | Phases 1, 4, 5 are serialized by explicit `Depends on` edges rather than run in one wave |
| Divergent wording across 9+ surfaces, re-creating the pre-658 drift | M | M | Every surface points at `git-staging-scope.md`'s Per-Operation Contract (and `absent-specs-git-history.md`'s recording contract) by name instead of restating it; Phase 6 greps for the phrases to confirm consistency |
| Reframe accidentally reads as deprecating the tracked posture | M | L | Phase 6 greps for `deprecated|legacy|superseded|no longer` across the touched set as an explicit negative control |
| A record-versioning or task-number violation lands under `agent-system/**` | M | L | Phase 6's gate-3/4 checks plus an explicit grep; this plan file is under `specs/**` where both are exempt, the edits are not |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2, 4 | 1 |
| 3 | 5 | 4 |
| 4 | 6 | 2, 3, 5 |

Phases within the same wave can execute in parallel.

### Phase 1: Place the Durability Statement [COMPLETED]

**Goal**: Task 661's drafted durability statement is present verbatim at the end of
`orchestrator-runtime-files.md`'s Fresh-Repo Default section, so later phases can point at it.

**Tasks**:
- [x] Read `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`,
      section "### Durability statement (verbatim, for the documentation record to place)", and
      copy the blockquoted statement byte-for-byte. Strip the `> ` quote markers, keeping the
      text itself unmodified. *(completed)*
- [x] Insert it into `context/standards/orchestrator-runtime-files.md` as a new labelled
      paragraph immediately after the "Manual opt-in runbook" subsection's closing paragraph
      (currently ending `...see "Forward-Only Migration Note" below for the shared rationale.`,
      around line 592) and before `## Untracking Already-Committed Ephemeral Files` (currently
      line 593). Give it a short bold lead-in in the file's own existing style (e.g.
      `**Durability of an ignored specs tree**:`). *(completed)*
- [x] Confirm the inserted text is byte-identical to the source: extract both and `diff` them.
      *(completed: normalized-whitespace diff empty; nested bold markup preserved)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` and
      confirm it reports the `standards/orchestrator-runtime-files.md` row corrected (declared
      was 645, matching pre-edit actual). *(completed: ran the deployed `.claude/scripts/`
      copy per the script's own repo-root guard; 645 -> 655, re-run reports 0 changed)*
- [x] Commit both files together as one green sub-step. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/standards/orchestrator-runtime-files.md agent-system/extensions/core/index-entries.json` covers this phase's whole declared set, selecting test-audit-task-proposals.sh, test-context-reachability.sh, test-deploy-orphans.sh, test-deploy-propagation.sh, test-handoff-dispatch-identity.sh, test-index-entries-schema.sh, test-install-uninstall-extension.sh, test-manifest-scripts-sync.sh, test-roadmap-command-registration.sh, test-runtime-file-tracking.sh, and test-session-runtime-files.sh.

**Files to modify**:
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - durability
  statement inserted verbatim at the end of the Fresh-Repo Default section
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` for the
  orchestrator-runtime-files row (coupled generated surface; Rule R drift is commit-blocking via
  Gate 3)

**Verification**:
- `diff` of the extracted inserted text against the source blockquote is empty
- The statement sits between the runbook paragraph and `## Untracking Already-Committed
  Ephemeral Files` (confirm by `grep -n`)
- `generate-context-line-counts.sh --write` run; re-running it reports 0 changed
- The declared `line_count` for `standards/orchestrator-runtime-files.md` equals `wc -l` of the file
- The narrow check named in Tier Justification passes

---

### Phase 2: Reframe `rules/git-workflow.md` Commit Timing [NOT STARTED]

**Goal**: "Create Commits After" no longer reads as an unconditional post-condition, stated in a
compact pointer form that keeps the eager context budget green.

**Tasks**:
- [ ] Measure the pre-edit eager total: `cd /home/benjamin/.config/nvim && REPO_ROOT=$(pwd) bash
      agent-system/extensions/core/scripts/measure-eager-context.sh --check`, capturing the
      `TOTAL: <bytes> B` line to a file and grepping it. Record the figure and the margin against
      `baseline_bytes` (71,600 B) before writing anything.
- [ ] Add ONE compact paragraph under `## Commit Timing` (after the "Create Commits After" list,
      before "### Do Not Commit") stating: each listed lifecycle event still fires its commit
      attempt under either posture; under a wholly- or partly-gitignored `specs/` tree the attempt
      reports a non-failure skip (`git-commit-scoped.sh` exit `8`/`9`) for the ignored members
      instead of creating a commit; this is supported and expected, not a gap. Point at
      `context/standards/git-staging-scope.md`'s "Per-Operation Contract: Tracked vs. Gitignored
      `specs`" section and at `context/standards/orchestrator-runtime-files.md`'s Fresh-Repo
      Default section (where Phase 1 placed the durability statement) rather than re-deriving
      either. Do NOT call the tracked posture deprecated, legacy or superseded.
- [ ] Hard budget: keep the addition at or under 400 bytes. Count it (`git diff --stat` plus a
      byte count of the added hunk) before proceeding.
- [ ] Re-run `measure-eager-context.sh --check`. If it fires, trim this paragraph's wording — do
      NOT move `eager_load.baseline_bytes` in `context/config/orchestrator-context-budget.json`,
      and do not relocate detail out of an unrelated eager file to buy room.
- [ ] Commit.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/rules/git-workflow.md` covers this phase's single declared file, selecting test-guard-destructive-git.sh, test-plan-file-scope-harvest.sh, test-validate-no-task-references.sh, and test-validate-wiring.sh.

**Scope Hypothesis**: the posture note fits in ≤ 400 bytes and so stays inside the 1,128 B of
recorded eager headroom (70,472 B measured against a 71,600 B baseline) without any baseline
move. Confirm by running `measure-eager-context.sh --check` both before and after the edit and
comparing the two `TOTAL:` figures, rather than trusting the recorded `measured_bytes`.

**Files to modify**:
- `agent-system/extensions/core/rules/git-workflow.md` - one compact posture paragraph under
  the Commit Timing heading, pointer form only (no indexed line_count row, since rules files are
  not carried in index-entries.json)

**Verification**:
- `measure-eager-context.sh --check` exits 0 (post-edit `TOTAL:` at or under 71,600 B)
- `context/config/orchestrator-context-budget.json` is unmodified (`git diff --stat` over it is empty)
- The added paragraph names both pointer targets and contains none of
  `deprecated|legacy|superseded|no longer`
- The narrow check named in Tier Justification passes

---

### Phase 3: Reframe `orchestrate-state-machine.md` [NOT STARTED]

**Goal**: The document's two commit-assuming passages state the ignored-posture behaviour, and
the commit-gated `stall_suspected` detector's degradation under that posture is explicit, naming
`stranded_suspected` as the detector that still covers it.

**Tasks**:
- [ ] In `### Commit Granularity`'s "Exit-path coverage" table (around line 1077), qualify the
      `failed` row (line 1082) and the `blocked` row (line 1083), whose current text asserts the
      produced artifacts and status changes "are real and committed". Restate as: real, and
      committed unless the change set is specs-only under an ignored posture, in which case they
      are real and recorded through the V13 skip channel instead — pointing at
      `context/standards/absent-specs-git-history.md`'s "The V13 Recording Contract" section
      rather than restating it. Keep the table's existing cell style; a short parenthetical plus
      pointer is preferred over a new row.
- [ ] In `### The mechanical signal` (around line 1196), after the sentence describing the
      `git log --since=@<dispatch_start_ts>` commit count, add a short paragraph stating: under a
      gitignored `specs/` tree, zero commits for a task directory is the expected outcome of
      fully successful `plan`-phase work (which is specs-only by construction in the common
      case), not evidence of failure; `stall_suspected`'s commit-gated trigger therefore does not
      fire for that case; `stranded_suspected` (see "### The Strand Variant" below, heartbeat-based
      and deliberately not gated on any commit count) is the detector that still covers it.
- [ ] Do NOT change any script. State explicitly in the added prose that this is a documented
      coverage split between two existing detectors, not a request to widen `stall_suspected` —
      the document's own "non-widening ruling" (around line 1270) forbids that widening and must
      not be contradicted.
- [ ] Confirm no task-number reference and no record-versioning vocabulary entered the file.
- [ ] Commit.

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` covers this phase's single declared file, selecting test-handoff-reader-parity.sh, test-lint-postflight-boundary.sh, test-orchestrate-build-dispatch.sh, test-resume-scan-nonconformance.sh, test-routing-resolution.sh, test-session-runtime-files.sh, and test-stall-reprompt-wiring.sh.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - exit-path table rows
  for the failed and blocked outcomes qualified; the mechanical-signal section
  gains the posture paragraph (no indexed line_count row, since docs files are not carried in
  index-entries.json)

**Verification**:
- `grep -n "real and committed" docs/architecture/orchestrate-state-machine.md` no longer returns
  an unqualified assertion
- `### The mechanical signal` names both `stranded_suspected` and the zero-commit expectation
- `git diff` over `scripts/` within this phase is empty (documentation-only, no logic change)
- The document's non-widening ruling paragraph is unmodified
- The narrow check named in Tier Justification passes

---

### Phase 4: Reframe the Three Process-Workflow Commit Steps [NOT STARTED]

**Goal**: Each of the three `context/processes/*-workflow.md` commit steps covers the V13 skip as
a third, non-failure outcome, and no longer frames "Git commit created" as the only success.

**Tasks**:
- [ ] In `context/processes/research-workflow.md` "### Step 6: Create Git Commit" (line 221), add
      a third outcome branch alongside commit-succeeds and commit-fails: the commit reports a
      posture skip (`git-commit-scoped.sh` exit `8`/`9`), which is a non-failure and needs no
      remedy. Point at `context/standards/git-staging-scope.md`'s Per-Operation Contract.
- [ ] Soften that file's `**Checkpoint**: Git commit created` (line 248) to wording true under
      both postures — e.g. commit attempted, outcome recorded per posture. Mirror
      `absent-specs-git-history.md`'s existing "the repository's own configuration, not a defect"
      phrasing rather than inventing a new pattern.
- [ ] In the same file's "### Git Commit Failed (non-critical)" error template (line 453), state
      that a posture skip is NOT this error case and must not be reported through it.
- [ ] Apply the same two edits to `context/processes/planning-workflow.md` ("### Step 6: Create
      Git Commit", line 218; checkpoint at line 245). If that file has no "Git Commit Failed"
      template, skip the third edit there rather than adding one.
- [ ] Apply the same edits to `context/processes/implementation-workflow.md` ("### Step 5: Create
      Git Commit", line 261; checkpoint at line 295), for consistency across all three files the
      dispatch names. Make no other change to that file — in particular do NOT touch its
      pre-existing `**SUPERSEDED**` header, which is an unrelated pre-existing condition and
      explicitly out of scope.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` and
      confirm the three `processes/*-workflow.md` rows are corrected (declared were 563 / 538 /
      588, each matching pre-edit actual).
- [ ] Commit.

**Timing**: 1.25 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/context/processes/research-workflow.md agent-system/extensions/core/context/processes/planning-workflow.md agent-system/extensions/core/context/processes/implementation-workflow.md agent-system/extensions/core/index-entries.json` covers this phase's whole declared set, selecting test-context-reachability.sh, test-deploy-orphans.sh, test-index-entries-schema.sh, test-install-uninstall-extension.sh, test-manifest-scripts-sync.sh, and test-roadmap-command-registration.sh.

**Scope Hypothesis**: `planning-workflow.md` has no "Git Commit Failed" error template (only
`research-workflow.md` matched that heading in this planning pass's grep), so the third edit
applies to two files, not three. Confirm with `grep -n "Git Commit Failed"` across all three
files before editing, and skip rather than add where the heading is absent.

**Files to modify**:
- `agent-system/extensions/core/context/processes/research-workflow.md` - third outcome branch,
  softened checkpoint, error-template exclusion note
- `agent-system/extensions/core/context/processes/planning-workflow.md` - third outcome branch,
  softened checkpoint
- `agent-system/extensions/core/context/processes/implementation-workflow.md` - same two edits,
  nothing else
- `agent-system/extensions/core/index-entries.json` - regenerated line_count for the three
  process-workflow rows (coupled generated surface; Rule R drift is commit-blocking via Gate 3)

**Verification**:
- `grep -n "Git commit created" context/processes/` returns nothing
- Each of the three files names the exit `8`/`9` skip and points at `git-staging-scope.md`
- `implementation-workflow.md`'s `**SUPERSEDED**` header is unchanged (`git diff` shows no hunk
  touching it)
- Re-running `generate-context-line-counts.sh --write` reports 0 changed
- The narrow check named in Tier Justification passes

---

### Phase 5: Sweep the Remaining Surfaces [NOT STARTED]

**Goal**: Every remaining surface asserting a commit as an unconditional outcome is reframed, and
the sweep is re-run to confirm the set is closed.

**Tasks**:
- [ ] Re-run the confirmatory sweep over `agent-system/extensions/core/**/*.md` for
      `git commit created|commit is created|always commits|specs tree is committed|committed to git|specs/ is tracked`,
      with a bounded `timeout`, redirecting to a file and grepping it. Treat the result as the
      authoritative work list for this phase.
- [ ] `docs/templates/README.md`: soften the three unqualified "git commit created" / "create git
      commit" occurrences in the 8-Stage Workflow Pattern (lines 112, 315, 321; line 60's
      "git commits" parenthetical needs no change unless the sweep shows otherwise) to
      posture-neutral language — commit attempted, outcome recorded per the repository's
      tracked/ignored posture — so a future command or skill author does not read commit creation
      as a hard Stage 7 success criterion.
- [ ] `commands/todo.md`: add one sentence to "### 6. Git Commit" (line 744) noting that under a
      wholly-ignored `specs/` tree this step's commit reports a non-failure skip (exit `8`) for
      every archival run, since its entire `stage_paths` array is specs-scoped — benign and
      expected, same as any other specs-scoped commit.
- [ ] `context/workflows/command-lifecycle.md`: qualify the "git commit created" output
      (line 240) and the "Verify git commit created (or logged if failed)" criterion (line 411)
      the same way.
- [ ] `context/orchestration/postflight-pattern.md`: qualify the checkpoint at line 327 the same
      way.
- [ ] `context/standards/error-handling.md`: inspect the commit-failure example around line 91.
      Edit it ONLY if it frames a created commit as the sole success outcome; if it describes a
      genuine `git` failure (the posture skip being a distinct non-failure channel), leave it
      unchanged and record that decision in the phase notes.
- [ ] Every edit points at `git-staging-scope.md`'s Per-Operation Contract rather than restating
      the mechanism, and none describes the tracked posture as deprecated, legacy or superseded.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` for
      the indexed `context/**` files touched here (declared pre-edit: `workflows/command-lifecycle.md`
      443, `orchestration/postflight-pattern.md` 336, `standards/error-handling.md` 1054).
- [ ] Re-run the sweep grep and confirm every remaining hit is either reframed or a deliberate
      documented exclusion.
- [ ] Commit.

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/docs/templates/README.md agent-system/extensions/core/commands/todo.md agent-system/extensions/core/context/workflows/command-lifecycle.md agent-system/extensions/core/context/orchestration/postflight-pattern.md agent-system/extensions/core/context/standards/error-handling.md agent-system/extensions/core/index-entries.json` covers this phase's whole declared set, selecting test-assess-repo-health.sh, test-check-record-versioning.sh, test-check-task-references.sh, test-context-reachability.sh, test-deploy-orphans.sh, test-gate3-parallel-equivalence.sh, test-gate3-strict-equivalence.sh, test-gate-cache-equivalence.sh, test-index-entries-schema.sh, test-install-uninstall-extension.sh, test-lean-src-roots.sh, test-lint-agent-contracts.sh, test-lint-dead-command-recommendations.sh, test-lint-extension-readme-table.sh, test-manifest-scripts-sync.sh, test-orchestrate-batch-admit.sh, test-plan-file-scope-harvest.sh, test-record-version-patterns.sh, test-roadmap-command-registration.sh, test-script-inventory.sh, test-todo-archived-projects-scan.sh, test-todo-move-pair-staging.sh, test-validate-state.sh, and test-validate-wiring.sh.

**Scope Hypothesis**: the remaining surface set is these six files. This planning pass's own grep
found exactly `docs/templates/README.md` (2 unqualified lines plus line 112),
`context/workflows/command-lifecycle.md` (2), `context/orchestration/postflight-pattern.md` (1),
and `context/standards/error-handling.md` (1, likely needing no edit), with `commands/todo.md`
carried from the research report. Confirm by re-running the sweep grep as this phase's first task
and treating its output — not this list — as the work list; `error-handling.md` may legitimately
drop out.

**Files to modify**:
- `agent-system/extensions/core/docs/templates/README.md` - 8-Stage Stage 7 success criteria made
  posture-neutral
- `agent-system/extensions/core/commands/todo.md` - one sentence in the Git Commit step
- `agent-system/extensions/core/context/workflows/command-lifecycle.md` - output and verification
  criterion qualified
- `agent-system/extensions/core/context/orchestration/postflight-pattern.md` - checkpoint qualified
- `agent-system/extensions/core/context/standards/error-handling.md` - conditional; edit only if
  it frames a created commit as the sole success outcome
- `agent-system/extensions/core/index-entries.json` - `line_count` regenerated for whichever
  indexed `context/**` rows this phase actually touched (coupled generated surface; Rule R drift
  is commit-blocking via Gate 3)

**Verification**:
- The re-run sweep grep returns no unqualified commit-invariant assertion, or every residual hit
  is a documented deliberate exclusion recorded in the phase notes
- No touched file contains `deprecated|legacy|superseded` applied to the tracked posture
- Re-running `generate-context-line-counts.sh --write` reports 0 changed
- The narrow check named in Tier Justification passes

---

### Phase 6: Redeploy, Negative Control, and Close [NOT STARTED]

**Goal**: The deployed tree matches the source store, the protected files are provably unchanged,
and the gate set is green or explicitly deferred to the orchestration close.

**Tasks**:
- [ ] Negative control on the protected files: `git diff --stat -- agent-system/extensions/core/context/standards/task-reference-exemptions.md agent-system/extensions/core/context/standards/record-version-exemptions.md agent-system/extensions/core/rules/state-management.md agent-system/extensions/core/rules/artifact-formats.md agent-system/extensions/core/context/standards/git-staging-scope.md agent-system/extensions/core/context/standards/absent-specs-git-history.md`
      over this task's full commit range. It MUST be empty. If any of the six shows a hunk, revert
      that hunk before continuing.
- [ ] Negative control on framing: grep the touched set for `deprecated|legacy|superseded|no longer`
      and confirm no occurrence applies to the tracked posture.
- [ ] Negative control on deliverable rules: confirm no task-number reference and no
      record-versioning language landed under `agent-system/**` across this task's commits.
- [ ] Confirm `generate-context-line-counts.sh --write` reports 0 changed (all per-phase
      regenerations already landed) before deploying.
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh`, with a bounded
      `timeout`, output redirected to a file and grepped for the line_count auto-repair line and
      any WARNING. If the auto-repair corrects anything, that is a per-phase miss — commit the
      corrected `index-entries.json` as its own step and record it in the issue log.
- [ ] Re-run `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/measure-eager-context.sh --check`
      post-deploy and confirm it exits 0.
- [ ] In-dispatch scoped check: `bash agent-system/extensions/core/scripts/verify-touched.sh`
      (no arguments, so it derives this task's touched paths itself), bounded, redirected, grepped
      for its verdict line.
- [ ] Under `/orchestrate`, the complete gate set is DEFERRED to the orchestration close
      (`context/contracts/batch-gate-stage.md`), not run independently here. Record that deferral
      explicitly in this phase's verification notes. Under a standalone, non-orchestrated run with
      no Move 4 to defer to, run `bash .claude/scripts/verify-deploy.sh` directly instead.
- [ ] Write the completion summary and commit.

**Timing**: 0.25 hours

**Depends on**: 2, 3, 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - only if the pre-deploy auto-repair corrects
  a row a prior phase missed

**Verification**:
- The six-file protected-set `git diff --stat` is empty
- The framing, task-number, and record-versioning negative-control greps are all clean
- `deploy-headless.sh` completes with no WARNING and reports 0 line_count entries corrected
- `measure-eager-context.sh --check` exits 0
- `verify-touched.sh` (no arguments) reports a green verdict over this task's touched paths
- The deferral of the complete gate set to the orchestration close is recorded in this phase's
  notes (or, standalone, `verify-deploy.sh` ran green directly)

## Testing & Validation

- [ ] No surface in `agent-system/extensions/core/**` asserts a committed `specs/` tree as an
      invariant (confirmed by the Phase 5 re-run sweep)
- [ ] Each reframed surface states the behaviour under both postures and names the V13 skip
      outcome, pointing at `git-staging-scope.md`'s Per-Operation Contract
- [ ] Task 661's durability statement is present byte-for-byte at the end of
      `orchestrator-runtime-files.md`'s Fresh-Repo Default section
- [ ] `task-reference-exemptions.md` and `record-version-exemptions.md` are byte-unchanged
- [ ] No reframed surface describes the tracked posture as deprecated, legacy or superseded
- [ ] `index-entries.json` `line_count` has zero drift
- [ ] `measure-eager-context.sh --check` green with `baseline_bytes` unmoved
- [ ] Deploy succeeded and the complete gate set is green or explicitly deferred to the
      orchestration close

## Artifacts & Outputs

- Edited source-store surfaces: `rules/git-workflow.md`,
  `docs/architecture/orchestrate-state-machine.md`, the three `context/processes/*-workflow.md`
  files, `context/standards/orchestrator-runtime-files.md`, `docs/templates/README.md`,
  `commands/todo.md`, `context/workflows/command-lifecycle.md`,
  `context/orchestration/postflight-pattern.md`, and conditionally
  `context/standards/error-handling.md`
- `agent-system/extensions/core/index-entries.json` with regenerated `line_count` values
- A regenerated deployed `.claude/` tree
- `specs/662_reframe_docs_for_ignored_specs_default/summaries/01_reframe-docs-ignored-specs-summary.md`

## Rollback/Contingency

Every phase commits independently, so any single phase reverts with a scoped `git revert` of its
own commit without disturbing the others. Before any rollback that would discard uncommitted work,
take a snapshot first: `bash .claude/scripts/git-snapshot.sh 662`. The deploy is idempotent — a
re-run of `deploy-headless.sh` after a revert restores the deployed tree to match the reverted
source store. No script logic changes anywhere in this plan, so no runtime behaviour can regress;
the worst case is stale documentation prose, recoverable by reverting the relevant phase commit.
