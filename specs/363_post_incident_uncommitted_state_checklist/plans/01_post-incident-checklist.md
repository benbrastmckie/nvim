# Implementation Plan: Task #363

- **Task**: 363 - A one-page post-incident verification checklist naming uncommitted pre-session tree state as the first mandatory check
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: stash-reclassification task (archived at `specs/archive/361_reclassify_bare_git_stash_as_destructive/`) — complete, so this task is unblocked
- **Research Inputs**: specs/363_post_incident_uncommitted_state_checklist/reports/01_post-incident-checklist.md
- **Artifacts**: plans/01_post-incident-checklist.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create one new standalone standards page under the `agent-system/extensions/core/` source store
holding a four-item post-incident verification checklist, ordered by recoverability with
pre-session uncommitted tracked modifications first, and naming concrete stash-entry/reflog
comparison commands for that first check. Register it in the core extension's context index so it
is lazily discoverable, add a single cross-reference block to the destructive-git guard's
existing `stash_revert`-only refusal message so the pointer fires at incident time, then redeploy
and run the full gate set against both the source store and the deployed copy.

### Research Integration

The research report settled four things this plan builds directly on:

1. **Placement ruled**: a new standalone file, not a section append. All three surveyed
   candidates (`git-safety.md`, `git-staging-scope.md`, `git-workflow-narrative.md`) plus one
   found independently (`context/contracts/recovery.md`) were rejected with per-candidate
   reasoning; the findability-under-incident-conditions argument held. Proposed path:
   `context/standards/post-incident-verification-checklist.md`.
2. **Carried figures re-derived with no divergence** against
   `context/standards/git-workflow-narrative.md`'s existing incident section: two implementation
   agents, each a bare whole-tree stash; one stash spanning a ~375-second build whose later pop
   aborted and applied nothing; roughly thirty files of pre-session uncommitted work surviving
   only inside a 53-file stash entry; sibling commits unharmed.
3. **Git mechanics verified by hand** in a disposable scratch repository, not asserted:
   `git diff HEAD` and `git status --short` both come back *completely empty* after a bare stash
   revert; `git diff --stat HEAD stash@{N}` gives the per-path signal; `git stash show -p -u`
   (the `-u` is required) surfaces untracked content a bare `show -p` omits; and
   `git fsck --unreachable --no-reflog | grep commit` recovers an already-dropped entry's
   dangling commits.
4. **Guard insertion point located**: `hooks/guard-destructive-git.sh`'s `stash_revert`-specific
   block ends with the pathspec-scoped-stash guidance line immediately before its closing `fi`;
   the cross-reference goes *inside* that conditional, never in the generic trailer that fires
   for every destructive class.

This plan additionally closes the one question the report left open under Context Extension
Recommendations: the index registration mechanism. The core manifest declares
`"index": { "source": "index-entries.json", "target": ".claude/context/index.json" }`, so the
source-store file to edit is `agent-system/extensions/core/index-entries.json` (an object with a
single `entries` array; `standards/git-workflow-narrative.md` is the shape exemplar). No manual
edit of the deployed `.claude/context/index.json` is required or permitted.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- One page (target well under 100 lines) at
  `agent-system/extensions/core/context/standards/post-incident-verification-checklist.md`
  carrying exactly four mandatory checks in the mandated order.
- Check (1) names concrete stash-entry and reflog comparison commands, not a bare "check
  uncommitted state" instruction.
- The deliverable states, as a fact in its own text, that a reverted file matches HEAD and
  therefore reads as clean to `git status`/`git diff` — so a clean result is not evidence of no
  loss.
- The ordering rationale (uncommitted state first because it is the only category with no other
  recovery path) is stated in the deliverable itself.
- The guard's `stash_revert` refusal message points at the checklist, with its patterns,
  `DESTRUCTIVE_ACTION_CLASS` values, escape hatch, and rule text otherwise untouched.
- The new file is registered in `index-entries.json` and reachable after a redeploy.
- Placement decision and rejected alternatives recorded in the deliverable.

**Non-Goals**:
- No incident-management framework, severity taxonomy, or reporting template.
- No disclosure or candour requirements — disclosure quality was already high; verification scope
  was the defect.
- No change to the guard's patterns, destructive-action-class values, escape hatch, or
  `rules/git-workflow.md` rule text (owned by the archived stash-reclassification task).
- No retroactive audit of past incidents in any repository.
- No worktree-isolation proposal (ruled out at
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`).
- No hand-edit of any deployed `.claude/**` copy.
- No task-number references in any file landing under `agent-system/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Cross-reference lands in the guard's generic destructive trailer instead of inside the `stash_revert` conditional, firing for every class | M | M | Phase 3 re-derives the conditional's opening and closing line numbers at edit time and verifies placement with a post-edit `sed -n` read of the block plus a `test-guard-destructive-git.sh` run |
| Scope creep into an incident-response framework, given how much adjacent material exists (`git-safety.md` rollback patterns, `recovery.md` fix-forward ladder) | M | M | Hard line budget enforced in Phase 1 verification (`wc -l` under 100); only one permitted outbound "see also" pointer to `git-workflow-narrative.md` for mechanism detail |
| Checklist written but never consulted mid-incident | H | L | Guard cross-reference (Phase 3) fires exactly when a `stash_revert`-class command is refused; index registration (Phase 2) makes it lazily discoverable by keyword |
| Stale `line_count` in the index entry after late wording edits to the checklist | L | M | Phase 2 depends on Phase 1 being complete; its verification recomputes `wc -l` and compares against the recorded value |
| Concurrent sibling redeploy races Phase 4's `deploy-headless.sh` | L | M | `.claude/` is gitignored, so a redeploy produces no commit conflict and redeploy is idempotent; re-run verification against the deployed copy afterwards, and per the dispatch concurrency note STOP and report any foreign commit, foreign uncommitted modification, or build not started by this dispatch |
| Sibling tasks hold `agent-system/extensions/core/` paths this same cycle (`orchestrate-cycle-postflight.sh`; `external-process-wait.md`, `bounded-build-waiter.md`, `detect-noop-bash.sh`, `test-detect-noop-bash.sh`) | M | M | No overlap with this task's four files; re-read each file immediately before editing, stage only this task's own explicit file list (never a directory or glob `git add`), and never run `git-snapshot.sh` in its reverting default mode |
| A task-number reference slips into a deliverable under `agent-system/**` | M | L | Phase 1 and Phase 3 verification both run `check-task-references.sh`; the write-time hook also gates it |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the One-Page Checklist [NOT STARTED]

**Goal**: The standalone one-page standards file exists in the source store with all four checks
in the mandated order, the deceptive-clean-status fact stated outright, the recoverability
ordering rationale stated in the file, and the placement decision plus rejected alternatives
recorded.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/context/standards/git-workflow-narrative.md`'s
      "No Destructive Git on Uncommitted Work — Bare `git stash` Incident and Full Detail"
      section and re-confirm the carried figures (two agents; one stash spanning a long build
      whose pop aborted applying nothing; ~30 files of pre-session uncommitted work inside a
      53-file stash entry; sibling commits unharmed). Report any divergence from the research
      report's re-derivation in the implementation summary.
- [ ] Write `context/standards/post-incident-verification-checklist.md` in the source store with
      this structure:
      - A two-line opening: *when* (immediately after any destructive or tree-wide git action on
        a shared working tree) and *why* (verification that stops at sibling commits and the
        agent's own edits misses the one category with no other recovery path).
      - A standalone statement of the deceptive mechanism: a reverted file matches HEAD, so it
        reads as clean to `git status`, to `git diff`, and to every naive check; absence of a
        modification is indistinguishable from absence of a problem unless compared against the
        stash entry or the reflog. Therefore a clean `git status` is **not** evidence of no loss.
      - The four mandatory checks, numbered, in this order, each with concrete commands:
        1. **Pre-session uncommitted tracked modifications** — `git stash list`;
           `git diff --stat HEAD stash@{N}` for each outstanding entry;
           `git stash show -p -u stash@{N}` (the `-u` is required — a bare `show -p` omits
           untracked content); and, when the entry is no longer in `git stash list`,
           `git fsck --unreachable --no-reflog | grep commit` followed by
           `git show --stat <sha>` on each candidate.
        2. **Untracked files** — `git status --porcelain --ignored=no`, cross-checked against the
           stash's untracked parent (`stash@{N}^3`) when the entry was created with `-u`.
        3. **Sibling commits** — `git log --oneline <pre-incident-sha>..HEAD` against each
           sibling's reported work.
        4. **The agent's own edits** — confirm the declared `file_scope` is fully present.
      - The ordering rationale, stated explicitly: ordered by *recoverability*, not convenience.
        A sibling commit survives in history regardless; an agent's own edit can be redone;
        pre-session uncommitted work exists in exactly one place and, once reverted, reads as
        clean — so it goes first, while there is still time to extract it before the stash entry
        is dropped or garbage-collected. Note that the same four checks in a different order
        would reproduce the original failure.
      - A short placement note recording that this is a standalone page rather than a section of
        `git-safety.md` (a before/during risky-operation playbook), `git-staging-scope.md` (a
        pre-commit staging contract), `git-workflow-narrative.md` (a lazily-loaded reactive
        elaboration companion, read only once an agent is already following the core rules), or
        `context/contracts/recovery.md` (a build-error fix-forward ladder) — because a checklist
        that must be findable under incident conditions needs its own named page.
      - Exactly one outbound pointer, to `context/standards/git-workflow-narrative.md`'s incident
        section, for full mechanism detail.
- [ ] Confirm no task-number references and no emoji in the new file.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: the deliverable fits in one page — hypothesized at well under 100 lines of
markdown including all commands and the rationale, in exactly one new file with no edits to any
existing standards document. Confirm at implementation time with
`wc -l agent-system/extensions/core/context/standards/post-incident-verification-checklist.md`
and `git status --short -- agent-system/extensions/core/context/standards/`; if the content cannot
fit the budget, cut worked examples and prose introduction first (per the research report's
Recommendation 5) rather than letting the page grow.

**Files to modify**:
- `agent-system/extensions/core/context/standards/post-incident-verification-checklist.md` - new file; the one-page four-check checklist

**Verification**:
- File exists and `wc -l` is under 100.
- `grep -n` confirms the four check headings appear in the mandated order (uncommitted tracked
  modifications, untracked files, sibling commits, own edits) and that check (1) contains literal
  `git stash list`, `git diff --stat HEAD stash@{N}`, `git stash show -p -u`, and
  `git fsck --unreachable --no-reflog` strings.
- `grep -n` confirms the deliverable contains both the reverted-file-matches-HEAD statement and
  the recoverability ordering rationale.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrences.
- Diff read-through confirms every changed hunk is markdown prose in the single new file.

---

### Phase 2: Register the New File in the Context Index [NOT STARTED]

**Goal**: The checklist is lazily discoverable through the core extension's context index, added
at the source store (`index-entries.json`), never by hand-editing the deployed
`.claude/context/index.json`.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/index-entries.json`'s
      `standards/git-workflow-narrative.md` entry as the shape exemplar (`path`, `domain`,
      `subdomain`, `summary`, `line_count`, `keywords`, `topics`, `load_when`).
- [ ] Append one entry for `standards/post-incident-verification-checklist.md` with
      `domain: "core"`, `subdomain: "standards"`, a one-line summary, the actual `line_count`
      from Phase 1, keywords covering the incident-recovery vocabulary (for example
      `post-incident`, `uncommitted-state`, `git-stash`, `reflog`, `verification-checklist`), and
      `topics: ["git-workflow"]`.
- [ ] Set `load_when` to mirror the sibling git-workflow standards entry's reach
      (implementation-agent plus `/orchestrate`) so the page is reachable at the moment a
      destructive action is being attempted.
- [ ] Re-read the file immediately before editing in case a sibling has touched it this cycle,
      and stage only this file.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: exactly one new JSON object appended to `index-entries.json`'s `entries`
array, with no existing entry modified. Confirm with
`git diff -- agent-system/extensions/core/index-entries.json` showing a single added object and
no other hunks, and with `jq '.entries | length'` before and after differing by exactly one.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - append one entry for the new standards file

**Verification**:
- `jq -e '.entries[] | select(.path == "standards/post-incident-verification-checklist.md")'`
  returns the new entry.
- `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- Recorded `line_count` equals the live `wc -l` of the Phase 1 file.
- `git diff` on this file shows only the one appended object.

---

### Phase 3: Point the Guard's Refusal Message at the Checklist [NOT STARTED]

**Goal**: The destructive-git guard's `stash_revert`-specific refusal message names the checklist,
inside that conditional only, with the guard's patterns, class values, escape hatch, and rule
text unchanged.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/hooks/guard-destructive-git.sh` immediately before
      editing and re-derive the `stash_revert` conditional's opening
      (`if [ "${DESTRUCTIVE_ACTION_CLASS:-}" = "stash_revert" ]; then`) and its closing `fi`
      line numbers — do not trust the line numbers carried in the research report.
- [ ] Insert the cross-reference as `echo ... >&2` lines immediately after the
      pathspec-scoped-stash guidance line and strictly *before* that conditional's closing `fi`,
      so it never lands in the generic trailer that fires for every destructive class. Shape:
      a pointer to `context/standards/post-incident-verification-checklist.md` stating that it
      checks uncommitted pre-session tree state first, because a reverted file reads clean and
      has no other recovery path once the stash entry is gone.
- [ ] Change nothing else in the file: no pattern, no `DESTRUCTIVE_ACTION_CLASS` value, no escape
      hatch, no `rules/git-workflow.md` text.
- [ ] Confirm no task-number references were introduced.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the edit is confined to a handful of added `echo` lines in exactly one file,
with zero deletions and zero modifications to existing lines. Confirm with
`git diff --numstat -- agent-system/extensions/core/hooks/guard-destructive-git.sh` showing
deletions of 0, and with a `sed -n` read of the conditional confirming the added lines sit above
its closing `fi`.

**Files to modify**:
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` - add the checklist cross-reference inside the existing `stash_revert` refusal block only

**Verification**:
- `bash -n agent-system/extensions/core/hooks/guard-destructive-git.sh` passes.
- `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` passes.
- `sed -n` read of the `stash_revert` block shows the new lines between the pathspec-scoped
  guidance line and the closing `fi`.
- `git diff --numstat` shows 0 deletions on this file.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrences.

---

### Phase 4: Redeploy and Run the Full Gate Set [NOT STARTED]

**Goal**: The source-store changes are reflected in the deployed `.claude/` tree and the
repository's complete gate set is green.

**Tasks**:
- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh`.
- [ ] Confirm the deployed copies landed:
      `.claude/context/standards/post-incident-verification-checklist.md` exists and matches the
      source store; `.claude/hooks/guard-destructive-git.sh` carries the cross-reference; and
      `jq` finds the new entry in `.claude/context/index.json`.
- [ ] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` (source-store path:
      `agent-system/extensions/core/scripts/verify-deploy.sh`), plus
      `bash .claude/scripts/validate-context-index.sh`.
- [ ] Per the dispatch concurrency note: if a foreign commit, a foreign uncommitted
      modification, or a build this dispatch did not start is observed, check `git log` to
      confirm the work is not this task's own, then STOP and report rather than proceeding.
- [ ] Commit with an explicit per-file staging list (never a directory or glob `git add`).

**Timing**: 40 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Files to modify**:
- none planned — this phase deploys and verifies the three preceding phases' files; it writes no source-store content of its own

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0.
- `bash .claude/scripts/validate-context-index.sh` exits 0.
- `diff` between the source-store checklist and `.claude/context/standards/post-incident-verification-checklist.md` is empty.
- `grep -c "post-incident-verification-checklist" .claude/hooks/guard-destructive-git.sh` is at
  least 1.
- `jq -e '.entries[] | select(.path == "standards/post-incident-verification-checklist.md")' .claude/context/index.json` succeeds.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/context/standards/post-incident-verification-checklist.md`
      exists, is under 100 lines, and carries the four checks in the mandated order.
- [ ] Check (1) names concrete stash-entry and reflog comparison commands.
- [ ] The deliverable states that a reverted file matches HEAD and therefore reads as clean, so a
      clean `git status` is not evidence of no loss.
- [ ] The recoverability ordering rationale is in the deliverable, not only in the task
      description.
- [ ] Placement decision and rejected alternatives recorded in the deliverable.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` passes.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-index-entries-schema.sh` passes.
- [ ] `bash .claude/scripts/verify-deploy.sh` exits 0.
- [ ] `bash .claude/scripts/validate-context-index.sh` exits 0.
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new occurrences under
      `agent-system/**`.
- [ ] Guard patterns, `DESTRUCTIVE_ACTION_CLASS` values, and escape hatch are byte-identical
      apart from the added `echo` lines (`git diff --numstat` shows 0 deletions on the hook).

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/post-incident-verification-checklist.md` (new)
- `agent-system/extensions/core/index-entries.json` (one appended entry)
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` (cross-reference lines added
  inside the existing `stash_revert` refusal block)
- Regenerated deployed copies under `.claude/` (gitignored deploy artifact, not committed)
- `specs/363_post_incident_uncommitted_state_checklist/summaries/01_post-incident-checklist-summary.md`

## Rollback/Contingency

All three source-store changes are additive and independently revertible:

- The checklist page is a new file — `git rm` (or delete, if uncommitted) removes it with no
  other effect.
- The index entry is one appended JSON object — remove it and re-run
  `test-index-entries-schema.sh`.
- The guard cross-reference is pure added `echo` lines with zero deletions — remove them and
  re-run `test-guard-destructive-git.sh`.

After any revert, re-run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to bring
the deployed `.claude/` tree back into agreement with the source store. Do not use
`git-snapshot.sh` in its reverting default mode at any point in this task: siblings share this
working tree this cycle. If a defensive checkpoint is wanted before Phase 3's hook edit, use
`bash .claude/scripts/git-snapshot.sh 363 --no-revert`.
