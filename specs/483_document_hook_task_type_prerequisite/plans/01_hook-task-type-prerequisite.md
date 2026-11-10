# Implementation Plan: Task #483

- **Task**: 483 - Document that an extension lifecycle hook can never fire without a declared `task_type`
- **Status**: [COMPLETED]
- **Effort**: 1.1 hours
- **Dependencies**: None
- **Research Inputs**: specs/483_document_hook_task_type_prerequisite/reports/01_hook-task-type-prerequisite.md
- **Artifacts**: plans/01_hook-task-type-prerequisite.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two coordinated, prose-only edits to the extension-authoring guidance in the source store
(`agent-system/extensions/core/`), followed by a redeploy and a source-vs-deployed confirmation.
The first edit inserts a new, prominent subsection at the top of `creating-extensions.md`'s
`## Lifecycle Hooks` section stating that a declared top-level `task_type` is a *prerequisite*
for any of the four lifecycle hooks to fire at all, quoting the exact resolver gate expression
as the mechanical source of truth. The second adds a short pointer warning to
`extension-development.md`'s `### Resource-Only Extensions` prose, which currently grants
authors permission to omit `task_type` with no statement of that consequence. No code changes:
`skill-base.sh` is read-only, the manifest schema, hook resolution order, and non-blocking
exit-code contract are all untouched, and no new cross-cutting hook seam is proposed or designed.

### Research Integration

The research report independently re-derived every mechanism claim from live source and matched
the dispatch's citations with zero drift. Findings carried into this plan:

- The gate is at `skill-base.sh:178` inside `skill_get_extension_dir()`, exactly
  `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]`; a manifest with no
  `task_type` yields `ext_task_type=""` from `jq -r '.task_type // empty'` and fails the `-n`
  test unconditionally — the equality check is never reached.
- All four `skill_run_extension_hook` call sites (`skill-base.sh` lines 478 preflight,
  541 context_injection, 761 verification, 1146 postflight) pass `"${TASK_TYPE:-}"`, the
  currently dispatched task's own type.
- The one real cross-cutting pre-dispatch injection is a hardcoded `memory-retrieve.sh` call at
  `orchestrate-build-dispatch.sh:342`, inside core's own dispatch builder — not an extension
  hook of any kind.
- Placement decision adopted from research: a NEW subsection inserted immediately after
  `## Lifecycle Hooks`' introductory sentence and *before* `### Hooks vs. provides.hooks`
  (between current lines 690 and 692), not an in-place edit of the existing
  `### Observers vs. Lifecycle Hooks` subsection at line 880 — a reader working through the
  Lifecycle Hooks section may never reach the observer comparison.
- Cross-reference, never duplicate, the existing `### Observers vs. Lifecycle Hooks` content;
  `suite_selection_select` was confirmed to return `__FULL_SWEEP__` for both target paths, so
  no shell suite covers either file.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided for this dispatch; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:

- State, prominently and as its own standalone claim inside `## Lifecycle Hooks`, that a hook
  fires only for a task whose `task_type` string-equals the declaring extension's own top-level
  `task_type`, and that an extension declaring no `task_type` has no firing path for any of its
  four hooks.
- Name `skill_get_extension_dir()` in `scripts/skill-base.sh` and quote the exact gate
  expression, so a future reader can verify the claim against source rather than trusting prose.
- Record that `nvim` and `nix` are PER-DOMAIN precedents, each firing only on its own domain's
  tasks, so citing them as precedent for a cross-cutting hook is visibly wrong.
- Record that the only real cross-cutting pre-dispatch injection is the hardcoded
  `memory-retrieve.sh` / `<memory-context>` call in `scripts/orchestrate-build-dispatch.sh`, that
  replicating that shape is a core change rather than an extension change, and that no
  extension-declarable cross-cutting seam exists.
- Note briefly, by cross-reference, that post-task observers do not solve pre-work orientation
  either, since they fire only after a task reaches a resting state.
- Carry a pointer warning in `extension-development.md`'s resource-only-extension prose that
  omitting `task_type` also forfeits all four lifecycle hooks.
- Redeploy so the statement reaches `.claude/`, and confirm the deployed copies match the source
  store.

**Non-Goals**:

- Any edit to `skill-base.sh`. It is READ for verification only.
- Adding, proposing, or designing a new cross-cutting hook seam.
- Changing the manifest schema, the hook resolution order, or the non-blocking exit-code
  contract.
- Forking a second account of the resolution rule that could drift from the existing
  `### Observers vs. Lifecycle Hooks` subsection.
- Any hand-authored edit under `.claude/**`, which is a disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New subsection drifts from the existing `### Observers vs. Lifecycle Hooks` account of the same resolution rule | M | M | Cross-reference that subsection by name for the full comparison and the WHY-TOPIC rationale; state only the standalone consequence locally. Phase 1 verification explicitly re-reads both for contradiction. |
| A reader skims past a mid-section insertion and still misses the constraint | M | L | Place it immediately after the section's own introductory sentence, ahead of every other subsection, per the research placement decision. |
| Redeploy regenerates the whole deployed tree, sweeping in unrelated pending source-store changes (the dispatch reports `core` and `lean` already stale) | M | H | Expected and acceptable: the redeploy is the sanctioned remedy for that staleness. Verify only this task's two files hunk-for-hunk; never hand-patch `.claude/**`. Commit only this task's own source-store hunks. |
| Deploy script exceeds the default Bash timeout and is read as a failure | L | M | Bounded-wait idiom: `timeout 540 bash .claude/scripts/deploy-headless.sh` with the Bash tool `timeout` parameter raised to 600000. |
| A concurrent sibling dispatch edits a shared file | L | L | Sibling 488's declared `file_scope` is disjoint from both target files. Still re-read each target immediately before editing, and stage explicit file lists only. |
| Task-number references leak into source-store prose | M | L | Cite durable anchors only (filenames, function names, section headings). Gate 4 in Phase 3 is the mechanical backstop. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: State the task_type prerequisite in creating-extensions.md [COMPLETED]

**Goal**: `creating-extensions.md`'s `## Lifecycle Hooks` section carries a new, prominent
subsection stating the `task_type` prerequisite, the exact gate expression, the
per-domain-versus-cross-cutting distinction, the core-only cross-cutting precedent, and a brief
observer cross-reference — satisfying acceptance criteria 1-5 and 7.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/docs/guides/creating-extensions.md` around the
      `## Lifecycle Hooks` heading and the `### Observers vs. Lifecycle Hooks` subsection
      immediately before editing (concurrency discipline; line numbers below are the
      research-verified positions, to be re-confirmed rather than trusted). *(completed)*
- [x] Insert a new `### Prerequisite: A Declared task_type` subsection immediately after the
      section's introductory sentence and before `### Hooks vs. provides.hooks` (between the
      current lines 690 and 692). *(completed)*
- [x] In that subsection, state the prerequisite as a standalone claim: a lifecycle hook fires
      only for a task whose `task_type` string-equals the declaring extension's own top-level
      `task_type`; an extension with no `task_type` has no firing path for any of its four
      hooks (preflight, context_injection, verification, postflight). *(completed)*
- [x] Name `skill_get_extension_dir()` in `scripts/skill-base.sh` as the mechanical source of
      truth and quote the gate verbatim: `[ -n "$ext_task_type" ] && [ "$ext_task_type" = "$task_type" ]`.
      Explain that `jq -r '.task_type // empty'` yields an empty string for a manifest with no
      `task_type`, which fails the `-n` test unconditionally, and that the resolver returns the
      FIRST matching extension. *(completed)*
- [x] State that the four `skill_run_extension_hook` call sites each pass the currently
      dispatched task's own `task_type`. *(completed)*
- [x] State that `nvim` and `nix` are PER-DOMAIN precedents — each fires only on its own
      domain's tasks because each declares its own matching `task_type` — and that citing them
      as precedent for a cross-cutting, task-type-independent hook inverts what the mechanism
      does. *(completed)*
- [x] State that the only real cross-cutting pre-dispatch injection in the system is the
      hardcoded `memory-retrieve.sh` / `<memory-context>` call in
      `scripts/orchestrate-build-dispatch.sh`, that replicating that shape is a core change
      rather than an extension change, and plainly that no extension-declarable cross-cutting
      seam exists. *(completed: cited current call site -- scripts/sapience-retrieve.sh, the script that replaced memory-retrieve.sh at this exact site in a same-day prior commit -- rather than the stale script name; recorded as a carried-figure correction in the issue log)*
- [x] Add one brief sentence noting that post-task observers do not solve pre-work orientation
      either (they fire only after a task reaches a resting state), cross-referencing
      `## Post-Task Observers` and `### Observers vs. Lifecycle Hooks` rather than restating
      their content. *(completed)*
- [x] Re-read the finished subsection against `### Observers vs. Lifecycle Hooks` and confirm no
      sentence duplicates or contradicts the existing resolution-rule account. *(completed)*
- [x] Commit this phase's single file with an explicit pathspec. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this source-store
markdown path (no shell suite covers it), so the covering check is sub-case (b)'s gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run alongside the `prose` row's diff read-through.

**Scope Hypothesis**: the insertion point is between current lines 690 and 692 of
`creating-extensions.md`, and `### Observers vs. Lifecycle Hooks` sits at line 880. Confirm both
by re-reading the file at implementation time before inserting; treat the line numbers as a
hypothesis and anchor the edit on the heading text, not on the numbers.

**Files to modify**:

- `agent-system/extensions/core/docs/guides/creating-extensions.md` - new
  `### Prerequisite: A Declared task_type` subsection inserted at the head of
  `## Lifecycle Hooks`; no other section altered.

**Verification**:

- Diff read-through confirms every changed hunk is prose inside the `## Lifecycle Hooks`
  section, with no change to any code block, table, or other section.
- `grep -n "skill_get_extension_dir" agent-system/extensions/core/docs/guides/creating-extensions.md`
  shows the function named inside the new subsection, and the quoted gate expression appears
  verbatim.
- The new subsection contains all five required statements (prerequisite, gate quote,
  per-domain precedent, core-only cross-cutting precedent, observer note) and the observer note
  is a cross-reference, not a restatement.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes (doc-lint and task-reference lint).

---

### Phase 2: Warn in extension-development.md that omitting task_type forfeits hooks [COMPLETED]

**Goal**: `extension-development.md`'s `### Resource-Only Extensions` prose, where authors are
told they may omit `task_type`, carries a pointer warning that doing so forfeits all four
lifecycle hooks, linking to the Phase 1 subsection — satisfying acceptance criterion 6.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/guides/extension-development.md` around the
      `### Resource-Only Extensions` heading and the manifest field table's `task_type` row
      immediately before editing. *(completed)*
- [x] Add a short paragraph directly after the existing "can omit `task_type` entirely"
      sentence, stating that omitting `task_type` also forfeits every lifecycle hook: a
      top-level `hooks` declaration in such a manifest has no firing path and is dead on
      arrival. *(completed)*
- [x] Link the warning to the Phase 1 subsection by file and section name, using the relative
      link style already present in this file (`../../docs/guides/creating-extensions.md`). *(completed)*
- [x] Keep the manifest field table's `task_type` row as a one-line schema reference; do not
      rewrite it (the "and/or" in the acceptance criterion is satisfied by the prose location,
      which is where an author is actively granted the permission). *(completed: table row left untouched)*
- [x] Confirm the linked section heading text matches what Phase 1 actually wrote, character for
      character. *(completed)*
- [x] Commit this phase's single file with an explicit pathspec. *(completed)*

**Timing**: 0.2 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for this source-store
markdown path, so the covering check is sub-case (b)'s gate subset
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
run alongside the `prose` row's diff read-through.

**Scope Hypothesis**: `### Resource-Only Extensions` is at current line 323 with its body at
325 onward, and the `task_type` field-table row at line 83. Confirm by re-reading at
implementation time and anchor on heading text rather than line numbers.

**Files to modify**:

- `agent-system/extensions/core/context/guides/extension-development.md` - one short warning
  paragraph added to the `### Resource-Only Extensions` prose, with a relative link to the
  Phase 1 subsection.

**Verification**:

- Diff read-through confirms a single added prose paragraph and no other change; the JSON
  example block below the prose is untouched.
- The relative link target resolves: the referenced file exists and
  `grep -n "Prerequisite: A Declared task_type" agent-system/extensions/core/docs/guides/creating-extensions.md`
  returns the heading the link names.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  passes.

---

### Phase 3: Redeploy and confirm deployed copies match the source store [COMPLETED]

**Goal**: The new guidance reaches `.claude/`, the deployed copies of both edited files match
the source store, and the full gate set is green — satisfying acceptance criterion 8.

**Tasks**:

- [x] Run the redeploy with the bounded-wait idiom:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash tool `timeout`
      parameter raised to 600000 (NOT its 120000ms default), per
      `context/patterns/external-process-wait.md` Rule 1. *(completed: deploy landed;
      RESULT=landed_verify_red on the deploy script's own un-narrowed fast-gate pass -- see
      deviation note below)*
- [x] Diff the deployed copy against the source store for each edited file and confirm identical
      content:
      `diff agent-system/extensions/core/docs/guides/creating-extensions.md .claude/docs/guides/creating-extensions.md`
      and
      `diff agent-system/extensions/core/context/guides/extension-development.md .claude/context/guides/extension-development.md`. *(completed: both report no differences)*
- [x] Confirm the new subsection heading and the warning paragraph are both present in the
      deployed copies by grep, not by inference from the deploy script's exit code alone. *(completed)*
- [x] Run the complete gate set and observe it green. *(deviation: scoped -- this dispatch's Batch
      Gate Deferral directive narrowed this phase's final-phase `full` tier to
      `verify-deploy.sh --skip-slow --only-gate 3,4`, which PASSed; the un-narrowed full gate
      reported 4/42 failures all attributable to other in-flight tasks in this same batch
      (gate10 timeout, eager-load baseline, shellcheck, dead-command-recommendation lint -- none
      touch this task's two files), deferred to the once-per-invocation batch-level gate stage)*
- [x] Review `git status --short` and stage only this task's own hunks with an explicit file
      list; never a directory or glob pathspec. Treat any foreign modification as a possible
      sibling edit and report rather than absorb it. *(completed: reviewed; all other dirty
      paths belong to sibling tasks already in flight in this batch, left untouched)*

**Timing**: 0.4 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - the redeploy regenerates the entire deployed `.claude/` tree, an implicit
  scope claim over that whole tree that no real declared path can express.
- `.claude/docs/guides/creating-extensions.md` - regenerated deploy artifact (never
  hand-authored).
- `.claude/context/guides/extension-development.md` - regenerated deploy artifact (never
  hand-authored).

**Verification**:

- The redeploy exits 0 within the bounded wait.
- Both `diff` invocations above report no differences.
- `grep -n "Prerequisite: A Declared task_type" .claude/docs/guides/creating-extensions.md`
  and a grep for the warning paragraph in `.claude/context/guides/extension-development.md`
  both match.
- The complete gate set for the repository is green:
  `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`). No `--skip-slow` and no
  `--only-gate` narrowing at this phase — neither is evidence for the final gate.

---

## Testing & Validation

- [x] Acceptance criterion 1: the prerequisite is stated explicitly and prominently inside
      `## Lifecycle Hooks`, not only in the observer comparison. *(completed)*
- [x] Acceptance criterion 2: `skill_get_extension_dir()` and `scripts/skill-base.sh` are named,
      and the gate expression is quoted verbatim. *(completed)*
- [x] Acceptance criterion 3: `nvim` and `nix` are described as per-domain, not cross-cutting,
      precedents. *(completed)*
- [x] Acceptance criterion 4: the hardcoded `<memory-context>` call in
      `scripts/orchestrate-build-dispatch.sh` is named as the only real cross-cutting
      pre-dispatch injection, with the core-change-not-extension-change consequence stated and
      the absence of any extension-declarable cross-cutting seam stated plainly. *(completed:
      named the current, verified script -- scripts/sapience-retrieve.sh -- rather than the
      stale memory-retrieve.sh citation in this item's own wording above; see Phase 1 deviation)*
- [x] Acceptance criterion 5: a brief observer note is present and cross-references the existing
      observer sections instead of duplicating them. *(completed)*
- [x] Acceptance criterion 6: `extension-development.md` carries the pointer warning, linked to
      the new subsection. *(completed)*
- [x] Acceptance criterion 7: no second account of the resolution rule was forked; the existing
      `### Observers vs. Lifecycle Hooks` subsection is cross-referenced, and nothing in the new
      subsection contradicts it. *(completed)*
- [x] Acceptance criterion 8: redeploy run and deployed copies confirmed to match the source
      store. *(completed)*
- [x] `skill-base.sh` is unmodified (`git status --short` shows no change to it from this task). *(completed: verified empty diff)*
- [x] No task-number references in either edited source-store file (gate 4 passes). *(completed: verify-deploy.sh --only-gate 4 PASS)*

## Artifacts & Outputs

- `agent-system/extensions/core/docs/guides/creating-extensions.md` - new
  `### Prerequisite: A Declared task_type` subsection in `## Lifecycle Hooks`.
- `agent-system/extensions/core/context/guides/extension-development.md` - warning paragraph in
  `### Resource-Only Extensions`.
- Regenerated deployed copies at `.claude/docs/guides/creating-extensions.md` and
  `.claude/context/guides/extension-development.md`.
- `specs/483_document_hook_task_type_prerequisite/summaries/01_hook-task-type-prerequisite-summary.md`
  at completion.

## Rollback/Contingency

Both source-store edits are additive prose in two files, each committed separately. To revert,
`git revert` the phase commit(s) for the affected file and redeploy; no schema, resolver, or
script behavior is touched, so there is no runtime state to unwind. If the redeploy in Phase 3
fails or produces a divergent deployed tree, do NOT hand-patch anything under `.claude/**` —
report the divergence and re-run the deploy; the source store remains the only authored copy, so
a failed deploy leaves the committed source edits intact and re-runnable.
