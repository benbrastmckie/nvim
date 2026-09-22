# Implementation Summary: Task #227

- **Task**: 227 - Resolve source store target in deployed trees
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T15:58:23Z
- **Completed**: 2026-09-22T16:30:00Z
- **Effort**: ~0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/02_resolve-target-via-extensions-json.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

The source-store boundary rule hard-coded `agent-system/extensions/**` as its edit target — a
path that exists only in the repository that owns the source store, making the rule unfollowable
in every deployed consumer tree. This implementation replaced the hard-coded target with a
repository-independent resolution *procedure* against `<project-root>/.claude-extensions.json`'s
`extensions.<name>.source_dir` field, added an explicit unreachable-source-store fallback, and
brought the two other deployed restatements of the target (an advisory hook message and a
generated-`CLAUDE.md` rules-list line) into agreement with the rewritten rule. The procedure was
verified by hand-walking it against a real consumer repository, `~/Projects/BimodalLogic`.

## What Changed

- `agent-system/extensions/core/rules/source-store-deploy-boundary.md` — rewrote **Path
  Pattern** to be repository-independent (any tree carrying `.claude-extensions.json`, not "a
  repository whose source store is `agent-system/extensions/**`"); rewrote **Principle** to drop
  the literal; replaced **Correct Edit Target** with a 5-step numbered procedure (read
  `.claude-extensions.json` -> select the `extensions` entry for the owning extension -> read its
  `source_dir` -> confirm it exists on disk -> edit under `<source_dir>/**` at the mirrored path);
  added an **If the source store is unreachable** subsection naming the four degraded conditions
  (missing/unparseable `.claude-extensions.json`; no entry for the extension; entry missing
  `source_dir`; recorded `source_dir` absent from disk) and directing the agent to file a task via
  `/task` rather than hand-author `.claude/**`; replaced the Before/After example so "After" shows
  an explicitly-labelled illustrative resolved path instead of a repo-specific literal.
- `agent-system/extensions/core/hooks/validate-meta-write.sh` — rewrote the `additionalContext`
  JSON message so it points at the `.claude-extensions.json` -> `source_dir` resolution procedure
  instead of naming `agent-system/extensions/core/**` literally, while keeping the wipe warning,
  the pointer to `.claude/rules/source-store-deploy-boundary.md`, and the "advisory only, does not
  block" closing clause. Shell mechanics (quoted heredoc, single-line valid JSON, `exit 0`,
  path-matching `case` block, `specs/*` skip, `system-defect-record.sh` call) are unchanged.
- `agent-system/extensions/core/merge-sources/claudemd.md` — reworded the
  `source-store-deploy-boundary.md` line in the "Core rules" list so its one-line description
  points at the `.claude-extensions.json` `source_dir` resolution instead of restating the
  hard-coded `agent-system/extensions/**` target.

## Decisions

- Adopted the refinement of dispatch option (a) recommended by research round 2: a
  resolution *procedure* against `.claude-extensions.json`'s `source_dir` field, with an explicit
  unreachable branch, rather than option (b) (deploy-time prose rewriting — rejected because
  `loader.lua`'s `copy_file` has no substitution mechanism for the `rules` category) or option (c)
  (scoping the rule out of deployed trees — rejected because it removes the explanatory "why" for
  no gain once the target is resolvable).
- Left the Enforcement section's wording unchanged: on review it did not presuppose the removed
  literal (it describes the hook injecting "a corrective ... message naming the correct
  source-store target," which remains accurate after the rewrite).
- Did not run `deploy-headless.sh` or otherwise propagate the corrected rule into any deployed
  `.claude/` tree, per the plan's explicit Non-Goal — that is the adjacent deploy-propagation
  task's surface, not this task's.

## Plan Deviations

- **Phase 4 verification** ("check-extension-docs.sh report no new findings") altered in effect:
  `check-extension-docs.sh` reports one new finding directly attributable to this task —
  "deployed rule content drift" for `rules/source-store-deploy-boundary.md" — which is the
  expected, inherent consequence of a source-store-only edit with no deploy performed (an explicit
  Non-Goal of this plan). It is not a content defect in the rewrite. Recorded in
  `progress/phase-4-progress.json`'s `deviations` array.

## Verification

- Build: N/A (text/prose and one shell script)
- Tests: `bash -n` on the hook parses clean; a synthetic PostToolUse payload piped through the
  hook produces valid JSON (`jq -e '.additionalContext'` succeeds) and the script exits 0
- `grep -n "agent-system/extensions" .../source-store-deploy-boundary.md` returns only one
  explicitly-labelled illustrative example line (`# e.g. /home/example/repo/agent-system/...`),
  no target instruction
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-task-references.sh --quiet`:
  PASS, 0 unexempted occurrences across all 4 scanned trees
- `git status --short`: zero entries under `.claude/`; the deployed
  `.claude/rules/source-store-deploy-boundary.md` copy's mtime (2026-09-21 23:39) predates every
  commit this task made, confirming it was never touched
- Consumer-repository walkthrough against `~/Projects/BimodalLogic`:
  - `core` entry: `extensions.core.source_dir` =
    `/home/benjamin/.config/nvim/agent-system/extensions/core` (exists on disk); mirrored
    `.claude/rules/source-store-deploy-boundary.md` resolves to
    `agent-system/extensions/core/rules/source-store-deploy-boundary.md`, a real file
  - Non-`core` entry (`lean`): `extensions.lean.source_dir` =
    `/home/benjamin/.config/nvim/agent-system/extensions/lean` (exists on disk); mirrored
    `.claude/agents/lean-research-agent.md` resolves to
    `agent-system/extensions/lean/agents/lean-research-agent.md`, byte-identical size (19530
    bytes)
  - Unreachable branch: a scratch copy of `~/Projects/BimodalLogic/.claude-extensions.json` with
    `.extensions.core.source_dir` deleted (written to the session scratchpad, never into the
    consumer repo) unambiguously reaches "the entry has no `source_dir` field" — step (3) of the
    procedure has no field to read
  - Read-only discipline held: `git status --short` in `~/Projects/BimodalLogic` was unaffected by
    the walkthrough (the one pre-existing modification, `specs/events.jsonl`, predates and is
    unrelated to this task)
- Files verified: Yes (all three changed files read back after edit; sizes/content confirmed)

## Impacts

- An agent in any deployed consumer tree that encounters a PostToolUse hand-authoring warning, or
  reads the source-store boundary rule directly, now has an executable procedure for locating and
  editing the real source store on that machine, instead of a hard-coded path that only exists in
  this repository.
- Consumer-tree agents that genuinely cannot resolve the source store (a pre-`source_dir`-stamping
  deploy, a moved/missing source checkout) now have a sanctioned outcome — file a task via
  `/task` — instead of either silently reporting or violating the boundary by hand-authoring
  `.claude/**`.
- This repository's own deployed `.claude/rules/source-store-deploy-boundary.md` copy is now
  intentionally stale relative to the source-store copy, until the next deploy. This is expected
  and matches this task's declared Non-Goal (no deploy performed here); `check-extension-docs.sh`
  will continue to flag this drift until a deploy runs.

## Follow-ups

- **Residue for a follow-up task** (explicitly out of this task's scope per its Non-Goals): 16
  agent-contract files still restate the hard-coded `agent-system/extensions/<ext>/**` target in
  their own MUST-NOT bullets or rule text, independent of the rule file this task rewrote:
  - `agent-system/extensions/core/agents/general-implementation-agent.md` (MUST NOT bullet)
  - `agent-system/extensions/core/agents/meta-builder-agent.md` (Rule 2 phrasing, plus several
    internal Component 4a / Stage 3.5 default-path descriptions not covered by Rule 2 alone)
  - `agent-system/extensions/email/agents/email-implementation-agent.md`
  - `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md`
  - `agent-system/extensions/nix/agents/nix-implementation-agent.md`
  - `agent-system/extensions/z3/agents/z3-implementation-agent.md`
  - `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
  - `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
  - `agent-system/extensions/rust/agents/rust-implementation-agent.md`
  - `agent-system/extensions/python/agents/python-implementation-agent.md`
  - `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`
  - `agent-system/extensions/latex/agents/latex-implementation-agent.md`
  - `agent-system/extensions/lean/agents/lean-implementation-agent.md`
  - `agent-system/extensions/lean/agents/lean-implementation-hard-agent.md`
  - `agent-system/extensions/web/agents/web-implementation-agent.md`
  - `agent-system/extensions/typst/agents/typst-implementation-agent.md`

  15 of these share one identical boilerplate bullet ("Hand-author files under `.claude/**` --
  see `.claude/rules/source-store-deploy-boundary.md`; edit the source store at
  `agent-system/extensions/<ext>/**` instead"); a follow-up task could reword that shared bullet
  once and propagate it, plus separately address `meta-builder-agent.md`'s Rule 2 and its
  Component 4a defaulting logic.
- This repository's own deployed `.claude/` tree (and any other already-deployed consumer tree,
  e.g. `~/Projects/BimodalLogic`) still carries the pre-fix rule text until the next deploy runs.
  Propagating the fix is the adjacent deploy-propagation task's surface, not repeated here.

## References

- `specs/227_resolve_source_store_target_in_deployed_trees/plans/02_resolve-target-via-extensions-json.md`
- `specs/227_resolve_source_store_target_in_deployed_trees/reports/02_resolve-target-via-extensions-json.md`
- `specs/227_resolve_source_store_target_in_deployed_trees/reports/01_source-store-rule-has-no-target.md`
- `specs/227_resolve_source_store_target_in_deployed_trees/progress/phase-{1,2,3,4}-progress.json`
