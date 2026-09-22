# Implementation Plan: Resolve source store target in deployed trees

- **Task**: 227 - Resolve source store target in deployed trees
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/227_resolve_source_store_target_in_deployed_trees/reports/02_resolve-target-via-extensions-json.md` (primary); `specs/227_resolve_source_store_target_in_deployed_trees/reports/01_source-store-rule-has-no-target.md` (prior round evidence)
- **Artifacts**: plans/02_resolve-target-via-extensions-json.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The source-store boundary rule hard-codes `agent-system/extensions/**` as its edit target, a
path that exists only in the repository that owns the source store. In every consumer tree the
rule deploys into, that target is unreachable, so the rule fails closed on its own purpose. This
plan replaces the hard-coded path with a resolution *procedure* against
`<project-root>/.claude-extensions.json`'s `extensions.<name>.source_dir` field — data the deploy
engine already stamps, per extension, with an absolute machine-local path, in a file that
deliberately lives outside `.claude/` so it survives a wipe. The boundary's substance is
unchanged: hand-authoring into a deployed `.claude/**` remains forbidden, and the rewrite adds an
explicit fallback for the degraded cases (`.claude-extensions.json` missing, unparseable, lacking
the extension's entry, or recording a `source_dir` absent from this machine) in which the source
store is genuinely unreachable and the agent must file rather than edit.

Done when: the rule's target-resolution text is repository-independent and its procedure, walked
by hand against a real consumer repository, yields an editable absolute path; and the two
deployed restatements of that target (the advisory hook's corrective message, and the rule's
one-line description in the generated `CLAUDE.md`) no longer contradict it.

### Research Integration

Findings carried into this plan from `reports/02_resolve-target-via-extensions-json.md`:

- `.claude-extensions.json` already records `extensions.<name>.source_dir` (absolute) and
  `source_git_head` for every loaded extension, written by `state.lua`'s `mark_loaded` on every
  deploy. Confirmed present and correct in a real consumer repository (`~/Projects/BimodalLogic`,
  `extensions.core.source_dir` = `/home/benjamin/.config/nvim/agent-system/extensions/core`),
  re-confirmed during this planning pass across all seven of that repo's loaded extensions.
- That file sits at the project root, outside `.claude/`, by explicit design (`config.lua`'s
  `root_state_file` comment) so a `.claude` wipe cannot remove it; it is regenerated on every
  deploy, so the recorded path cannot go stale the way baked-in rule prose does.
- Dispatch option (b) — deploy-time rewriting of the rule's prose — is rejected: `loader.lua`'s
  `copy_file` is a byte-for-byte copy with no substitution, and the only content-rewriting path
  (`merge.lua`) is specific to the `merge_targets` category. Option (b) would require new
  per-file substitution machinery for the `rules` category and a second thing to keep in sync,
  for precision the `source_dir` field already supplies.
- Dispatch option (c) — scoping the rule out of deployed trees — is rejected: it removes the
  explanatory "why" from every consumer tree for no gain once the target is resolvable.
- The adopted approach is a refinement of option (a): conditional/indirect resolution in the rule
  text itself, but resolving to a *real reachable path* before falling back to option (a)'s
  report-only behavior.
- `check-deploy-freshness.sh` already enumerates the exact degraded cases the fallback must name
  (missing/unparseable file, entry missing `source_dir`, `source_dir` absent from disk), so the
  rule reuses that vocabulary rather than inventing a parallel one.
- `.syncprotect` is irrelevant here: it protects only `context/repo/project-overview.md`-shaped
  entries, and protecting a rule file would preserve stale hand edits — the failure mode the
  boundary exists to prevent.

### Prior Plan Reference

No prior plan. This is the first plan artifact for this task; round 01 produced an evidence
report only.

### Roadmap Alignment

No `roadmap_path` supplied in this dispatch and no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Replace every hard-coded `agent-system/extensions/**` target assertion in
  `agent-system/extensions/core/rules/source-store-deploy-boundary.md` with a
  repository-independent resolution procedure against `.claude-extensions.json`'s
  `extensions.<name>.source_dir`.
- Name the degraded/unreachable cases explicitly, and give the consumer-side agent a sanctioned
  outcome for them (file a task via `/task`, which every tree carrying the `core` extension
  already has) rather than a silent report or a forbidden in-place edit.
- Preserve the boundary's substance verbatim: hand-authoring into a deployed `.claude/**` stays
  forbidden; the Exceptions and Enforcement sections keep their current meaning.
- Verify the rewritten procedure against at least one real consumer repository by walking its
  steps against that repo's actual on-disk state.
- Bring the two deployed restatements of the target — `hooks/validate-meta-write.sh`'s
  `additionalContext` message and `merge-sources/claudemd.md`'s rules-list line — into agreement
  with the rewritten rule, so a consumer agent is not handed a contradicting hard-coded path at
  the exact moment of violation.

**Non-Goals**:
- **No deploy-machinery change.** `loader.lua`, `merge.lua`, `config.lua`, `state.lua`,
  `deploy-headless.sh` are untouched. Dispatch option (b) is rejected on the evidence above.
- **No edit to any deployed `.claude/**` copy**, including this repository's own — that is the
  very act the rule forbids and is wiped by the next regeneration. The fix lands in the source
  store and reaches consumers through an ordinary deploy.
- **No deploy is performed by this task.** Propagating the corrected rule into already-deployed
  trees is the adjacent deploy-propagation task's surface, per the dispatch's
  "COORDINATE, DO NOT DUPLICATE" note. Verification here is a hand-walk of the procedure against
  a consumer repo's real state, not a redeploy of that repo.
- **No new filing mechanism for consumer-side findings.** `/task` already exists in every tree
  carrying the `core` extension; the dispatch's scope note excludes inventing one.
- **No new `context/patterns/source-store-resolution.md`.** The research offered this as an open
  question for the plan phase; it is declined. The resolution procedure belongs in the rule that
  needs it, and a second copy in a context file would be one more thing to keep in sync — the
  same drift class this task is fixing.
- **No edits to implementation-agent contract bullets** that restate the hard-coded target (e.g.
  `agents/general-implementation-agent.md`'s MUST NOT bullet, `agents/meta-builder-agent.md`'s
  Rule 2, and the per-extension implementation agents). This is a broad, per-extension surface
  outside this task's stated ownership, and `general-implementation-agent.md` is inside a
  concurrent sibling task's declared `file_scope` — see Risks below. Record the residue for a
  follow-up task at wrap-up; do not edit it here.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Territory collision: `agents/general-implementation-agent.md` carries the same hard-coded target and is in a concurrent sibling task's `file_scope` this same cycle | H | H | Declared a Non-Goal above. Do not open or edit that file. Record the residue in the wrap-up for a follow-up task instead |
| Rewrite drifts into weakening the boundary (e.g. admitting a `.claude/**` edit when the source store is unreachable) | H | M | Phase 1 verification explicitly diffs the Principle/Exceptions/Enforcement sections and asserts the prohibition text is unchanged in force; the fallback branch must end in "file, do not edit" |
| Rule text and the hook's advisory message drift apart, re-creating a contradiction | M | M | Phase 3 aligns the hook message only after the rule wording is final (depends on Phases 1 and 2), and asserts no remaining literal `agent-system/extensions` target instruction in either |
| A deployed tree predates `source_dir` stamping, so the field is absent | M | L | The fallback branch covers it by name, reusing `check-deploy-freshness.sh`'s existing vocabulary for the same condition |
| `source_dir` recorded by a deploy run on a different machine than the agent later runs on | M | L | Pre-existing, orthogonal limitation of the extension system as a whole (the source-store root is always machine-local). The same fallback handles it: path recorded but absent on disk -> unreachable -> file, do not edit |
| Implementer is tempted toward option (b) for "more precision" | M | L | Rejected in Non-Goals with the concrete evidence (no substitution mechanism exists for the `rules` category); hold the line at a text-only change absent new evidence |
| Editing this repo's own deployed `.claude/rules/` copy out of habit, since it is the copy loaded into context | H | M | Phase 4 asserts `git status` shows no modification under `.claude/` (it is gitignored here, so also assert the file's mtime/content is untouched) |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite the rule's target resolution [COMPLETED]

**Goal**: `agent-system/extensions/core/rules/source-store-deploy-boundary.md` states a
repository-independent procedure for locating the source store, with an explicit unreachable
branch, and carries no hard-coded `agent-system/extensions/**` target assertion.

**Tasks**:
- [x] Re-read the file immediately before editing (concurrent siblings share this working tree). *(completed)*
- [x] Rewrite **Path Pattern**: it currently scopes the rule to "a repository whose source store
      is `agent-system/extensions/**`", which makes the rule read as inapplicable in exactly the
      trees that need it. Restate as: any write whose target path is `.claude/**` in a repository
      whose `.claude/` tree was produced by a deploy — i.e. any tree carrying a
      `.claude-extensions.json`. *(completed)*
- [x] Rewrite **Principle**: keep the substance ("`.claude/` is a gitignored, disposable deploy
      artifact regenerated from the source store; hand-authored files there are silently wiped"),
      drop the `agent-system/extensions/**` literal from the sentence. *(completed)*
- [x] Rewrite **Correct Edit Target** as a numbered procedure: (1) read
      `<project-root>/.claude-extensions.json`; (2) select the entry under `extensions` for the
      owning extension — `core` for core system files (commands, skills, agents, rules, context,
      hooks, scripts, merge-sources), the extension's own name for extension-owned files; (3)
      read that entry's `source_dir`, an absolute path; (4) confirm it exists on disk; (5) edit
      under `<source_dir>/**`, at the path mirroring the deployed one (e.g. deployed
      `.claude/hooks/validate-meta-write.sh` -> `<source_dir>/hooks/validate-meta-write.sh`). *(completed)*
- [x] Add the **unreachable branch** immediately after the procedure, naming the conditions in
      `check-deploy-freshness.sh`'s existing vocabulary: `.claude-extensions.json` missing or
      unparseable; no entry for the relevant extension; entry missing `source_dir`; recorded
      `source_dir` absent from disk on this machine. In any of these, the source store is not
      reachable from this tree: the agent MUST NOT hand-author `.claude/**`, and MUST instead
      record the needed change as a task via `/task`, describing the deployed path, the intended
      change, and the reason it could not be made directly. *(completed)*
- [x] Replace the Before/After example pair so the "After" shows a resolved absolute path
      (illustrated as `<source_dir>/hooks/validate-meta-write.sh`), not a repo-specific literal.
      Where a concrete path is shown for readability, mark it explicitly as an illustration of
      one machine's resolved value, never as the target to type. *(completed)*
- [x] Leave the eager-loading HTML comment, **Exceptions**, and **Enforcement** sections
      untouched except where Enforcement's wording presupposes the removed literal. *(completed:
      Enforcement's wording did not presuppose the removed literal — no change needed there)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts the defect is confined to three sections of one file
(Path Pattern, Principle, Correct Edit Target). Confirm at implementation time by running
`grep -n "agent-system/extensions" agent-system/extensions/core/rules/source-store-deploy-boundary.md`
before and after: the before-set must be exactly the occurrences in those three sections, and the
after-set must contain no occurrence that instructs an agent where to write. If the before-set
includes an occurrence outside those three sections, widen this phase's task list and record it
rather than silently editing past the hypothesis.

**Files to modify**:
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - rewrite Path Pattern,
  Principle, and Correct Edit Target; add the unreachable branch

**Verification**:
- `grep -n "agent-system/extensions" agent-system/extensions/core/rules/source-store-deploy-boundary.md`
  returns no line that instructs an agent where to write (an illustrative, explicitly-labelled
  example value is acceptable; a bare target instruction is not).
- The file names `.claude-extensions.json`, `extensions`, and `source_dir` in the procedure.
- Diff read-through confirms the Principle, Exceptions, and Enforcement sections still forbid
  hand-authoring `.claude/**` with undiminished force, and that the unreachable branch ends in
  "file a task", never in a permitted `.claude/**` edit.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` passes for this file (no
  task-number references in a deliverable outside `specs/**`).

---

### Phase 2: Verify the procedure against a real consumer repository [NOT STARTED]

**Goal**: the rewritten procedure, executed step-by-step by a reader standing in a consumer tree,
yields an absolute path that exists and is editable — and the unreachable branch is confirmed to
behave as written when the field is absent.

**Tasks**:
- [ ] Walk the procedure literally against `~/Projects/BimodalLogic` (a real consumer repo, not
      this one): read its `.claude-extensions.json`, select the `core` entry, read `source_dir`,
      confirm the path exists on disk, and confirm the mirrored path for a concrete deployed file
      (e.g. its `.claude/rules/source-store-deploy-boundary.md` ->
      `<source_dir>/rules/source-store-deploy-boundary.md`) resolves to a real file.
- [ ] Repeat the selection step for one non-`core` extension entry in that same file, confirming
      the "extension's own name" branch of step (2) resolves too.
- [ ] Exercise the unreachable branch on a copy: against a scratch copy of that
      `.claude-extensions.json` with `source_dir` removed from the `core` entry (write the copy
      under the scratchpad directory, never into the consumer repo), confirm the procedure's
      step (3)/(4) text leads a reader unambiguously to the unreachable branch and not to a
      guess.
- [ ] Record the walkthrough result — the literal resolved paths and the branch outcomes — for
      the implementation summary.
- [ ] Apply any wording correction the walkthrough exposes (an ambiguous step, a missing
      pointer) directly to the rule file; this phase is expected to produce edits, not only a
      finding.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` - wording corrections
  exposed by the walkthrough (may be a no-op if none are found; record that outcome explicitly)

**Verification**:
- The walkthrough produced a real, existing absolute path for the `core` entry and for one
  non-`core` entry in `~/Projects/BimodalLogic/.claude-extensions.json`.
- The scratch-copy walkthrough reached the unreachable branch, and the branch's instruction
  ("file a task, do not edit `.claude/**`") was actionable without further inference.
- Read-only discipline held: `git status` in `~/Projects/BimodalLogic` is unchanged by this
  phase, and no file in that repository was written.

---

### Phase 3: Align the deployed restatements of the target [NOT STARTED]

**Goal**: the two other places a consumer tree is told where the source store is — the advisory
hook's corrective message and the generated `CLAUDE.md`'s rules-list line — agree with the
rewritten rule instead of contradicting it with a hard-coded path.

**Tasks**:
- [ ] Re-read both files immediately before editing (concurrent siblings share this tree).
- [ ] In `agent-system/extensions/core/hooks/validate-meta-write.sh`, rewrite the
      `additionalContext` JSON string so it (a) keeps the warning that the write will be wiped,
      (b) points at the resolution procedure — read `.claude-extensions.json`'s
      `extensions.<name>.source_dir` — instead of naming `agent-system/extensions/core/**`
      literally, and (c) keeps its existing pointer to
      `.claude/rules/source-store-deploy-boundary.md` and its "advisory only, does not block"
      closing clause.
- [ ] Preserve the surrounding shell mechanics exactly: the quoted `<< 'EOF'` heredoc (no
      variable expansion), single-line valid JSON, and `exit 0`. Do not alter the path-matching
      `case` block, the `specs/*` skip, or the `system-defect-record.sh` call.
- [ ] In `agent-system/extensions/core/merge-sources/claudemd.md`, rewrite the
      `source-store-deploy-boundary.md` line in the "Rules References" list so its one-line
      description does not restate the hard-coded target; point at the rule instead.
- [ ] Do not touch any other file that references the rule.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts exactly two files carry a deployed restatement of the
target within this task's ownership. Confirm at implementation time with
`grep -rn "agent-system/extensions" agent-system/extensions/core/hooks/ agent-system/extensions/core/merge-sources/`.
Occurrences found in agent contract files are out of scope by the Non-Goals above (one of them is
in a concurrent sibling's `file_scope`) — enumerate them for the wrap-up residue note rather than
editing them.

**Files to modify**:
- `agent-system/extensions/core/hooks/validate-meta-write.sh` - `additionalContext` message text
  only
- `agent-system/extensions/core/merge-sources/claudemd.md` - the one-line rules-list description
  for this rule

**Verification**:
- `bash -n agent-system/extensions/core/hooks/validate-meta-write.sh` parses clean.
- The hook's emitted JSON is still valid: pipe a synthetic PostToolUse payload naming a
  `.claude/rules/x.md` path into the script and confirm the output parses with
  `jq -e '.additionalContext'` and that the script exits 0.
- Neither changed string instructs an agent to write to a literal `agent-system/extensions`
  path; both name the `.claude-extensions.json` -> `source_dir` resolution or defer to the rule.
- The hook's non-blocking contract is intact: it still exits 0 on the matched path.

---

### Phase 4: Final consistency and boundary self-check [NOT STARTED]

**Goal**: the change is internally consistent, respects the boundary it documents, and leaves no
stray edit in a deployed or sibling-owned file.

**Tasks**:
- [ ] Confirm no file under `.claude/` was modified by this task: `git status --short` shows no
      `.claude/` entry, and the deployed
      `.claude/rules/source-store-deploy-boundary.md` still matches its pre-change content
      (it is gitignored here, so compare content, not git state).
- [ ] Confirm no file in any concurrent sibling's declared `file_scope` was modified — in
      particular `agent-system/extensions/core/agents/general-implementation-agent.md`.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` over the repo and
      confirm no new violation from the three changed files.
- [ ] Run `bash agent-system/extensions/core/scripts/check-extension-docs.sh` and confirm the
      changed files introduce no new finding (rules files carry no `index-entries.json` entry, so
      no `line_count` update is owed — confirm this rather than assume it).
- [ ] Read the rewritten rule end-to-end once more as a consumer-tree agent would, with no
      knowledge of this repository, and confirm every instruction in it is executable from that
      standing.
- [ ] Enumerate the residue for the wrap-up: the agent-contract files that still restate the
      hard-coded target, flagged as a recommended follow-up task (naming files, not task
      numbers).

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- None (verification phase; any defect found is fixed in the owning phase's file and re-verified
  here)

**Verification**:
- `git status --short` lists only the three intended source-store files plus this task's
  `specs/**` artifacts.
- `check-task-references.sh` and `check-extension-docs.sh` report no new findings.
- The consumer-standpoint read-through produces no instruction that cannot be executed from a
  tree that lacks `agent-system/`.

---

## Testing & Validation

- [ ] `grep -n "agent-system/extensions" agent-system/extensions/core/rules/source-store-deploy-boundary.md`
      yields no target instruction (illustrative, explicitly-labelled example values only).
- [ ] The rule names `.claude-extensions.json`, `extensions.<name>`, and `source_dir` in an
      ordered, executable procedure.
- [ ] The unreachable branch names all four degraded conditions and ends in "file a task", never
      in a permitted `.claude/**` edit.
- [ ] Procedure walkthrough against `~/Projects/BimodalLogic` resolves to an existing absolute
      path for both a `core` and a non-`core` extension entry, with that repository left
      unmodified.
- [ ] `bash -n` passes on the hook; a synthetic payload yields valid JSON with
      `.additionalContext` and exit 0.
- [ ] No `.claude/**` file modified; no sibling-owned file modified.
- [ ] `check-task-references.sh` and `check-extension-docs.sh` report no new findings.

## Artifacts & Outputs

- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` (rewritten target
  resolution)
- `agent-system/extensions/core/hooks/validate-meta-write.sh` (advisory message aligned)
- `agent-system/extensions/core/merge-sources/claudemd.md` (rules-list line aligned)
- `specs/227_resolve_source_store_target_in_deployed_trees/summaries/02_resolve-target-via-extensions-json-summary.md`
  (implementation summary, including the consumer-repo walkthrough record and the residue note
  for a follow-up task)

## Rollback/Contingency

All three changes are text-only and independently revertible. Because the phases commit
per-substep (`Commit Mode` defaults to `per-substep` throughout), reverting means `git revert` of
the specific commit, or `git checkout <sha> -- <path>` against a committed prior revision — not a
working-tree discard.

If an uncommitted working tree must be backed up before a genuine rollback, use the
snapshot-then-rollback recipe in `context/contracts/recovery.md`'s rollback rung, including its
out-of-scope override flag for the deliberate whole-tree case. Do not emit a bare default-mode
`git-snapshot.sh` as a routine precaution; a defensive, non-reverting checkpoint before risky
work uses `--no-revert` instead.

Contingency if the walkthrough in Phase 2 shows the procedure cannot resolve in the consumer tree
(e.g. `source_dir` is absent across the board on real deployed trees): do not fall back to the
hard-coded path, and do not weaken the boundary. Stop, record the finding, and return `partial`
with the evidence — the unreachable branch would then be the common case rather than the
exception, which is a different design question than this plan answers.
