# Implementation Summary: Task #784

**Completed**: 2026-06-30
**Duration**: ~1 session

## Overview

Added a four-workflow selection front-end to the `/pr` PR-submission command in
`.claude/extensions/cslib/commands/pr.md`. A new STEP 1b resolves the workflow (NEW, STACKED,
UPDATE, AMEND) before any branch or CI work. Three mutually-exclusive flags (`--stacked [PR]`,
`--update [PR]`, `--amend [PR]`) plus auto-detect-always-confirm drive the choice, with
downstream branching in STEP 4 (sync), STEP 5 (branch/checkout), and STEP 10 (push/create).
The `--review` path (STEP 0–0.2) and PR-READY review-response path (STEP 0.5.x) are untouched.

## What Changed

- `.claude/extensions/cslib/commands/pr.md` — sole modified file (symlinked to
  `.claude/commands/pr.md`, so live immediately)

### Phase 1: Flag Parsing + Workflow Variables (STEP 1)
- Added five workflow state variables: `workflow`, `workflow_pr_ref`, `workflow_pr_number`,
  `workflow_head_branch`, `stacked_base_branch` to the STEP 1 defaults block.
- Extended the parse loop to recognize `--stacked`, `--update`, `--amend` with optional PR ref
  (bare integer or GitHub URL, reusing the STEP 0.1 URL-parser inline).
- Added mutual-exclusion check: if 2+ workflow flags present, error + STOP.
- STEP 1 now ends with "IMMEDIATELY CONTINUE to STEP 1b" instead of STEP 2.

### Phase 2: Insert STEP 1b (Workflow Determination)
- Inserted `### STEP 1b: Determine Workflow` between STEP 1 and STEP 2.
- **Case C** (no flag): skip detection, proceed to STEP 2.
- **Case A** (flag + PR ref): calls `gh pr view` to resolve `workflow_head_branch`, validates
  state and owner, confirms via AskUserQuestion.
- **Case B** (flag without PR ref): queries `gh pr list` (current branch first, then all open
  PRs), presents candidates in AskUserQuestion with "Supply manually" and "Switch to NEW"
  options; never silent auto-select.

### Phase 3: STEP 4/5/5b Conditional Branching
- **STEP 4**: branches on `$workflow` — `new` fetches upstream; `stacked` fetches upstream +
  `origin/$workflow_head_branch`; `update`/`amend` skips upstream fetch, runs `git fetch origin`.
- **STEP 5**: renamed to "Branch Creation / Checkout"; full per-workflow sub-sections:
  - `new`: original `git checkout upstream/main -b` with AskUserQuestion.
  - `stacked`: `git checkout origin/"$workflow_head_branch" -b "$branch_name"` with
    AskUserQuestion explaining "from PR #N head".
  - `update`/`amend`: `gh pr checkout "$workflow_pr_number"` with AskUserQuestion; sets
    `branch_name="$workflow_head_branch"`.
- **STEP 5b**: updated to note `lake exe cache get` runs for all four workflows.

### Phase 4: STEP 10 Push/Create Conditional Logic
- Restructured STEP 10 into four sub-sections (10a shared commit, 10b approval gates,
  10c dry-run previews, 10d execute push/create).
- `amend` pre-commit uses `git commit --amend --no-edit` instead of a new commit.
- Per-workflow AskUserQuestion approval gates (distinct question text per workflow).
- Per-workflow dry-run preview blocks (all four).
- `new` and `stacked`: call `gh pr create` (stacked targets `--base "$workflow_head_branch"`).
- `update`: plain `git push origin`; NO `gh pr create`.
- `amend`: `git push --force-with-lease origin`; NO `gh pr create`; force-push-rejected
  recovery message included.
- STEP 10b note added: non-fatal for update/amend if task already completed.

### Phase 5: Documentation
- Frontmatter `argument-hint` updated with the three new flags.
- Options table extended with `--stacked`, `--update`, `--amend` rows and mutual-exclusion note.
- New "Workflow Selection" subsection with four-workflow comparison table and auto-detect
  description added after the Options table.
- Output Examples section extended with Stacked PR, Update PR, and Amend PR examples.
- Notes section extended with workflow selection, `--amend` safety, and approval gate notes.
- **Manifest decision**: `keyword_overrides` not changed. The existing `pr`/`submit`/`upstream`/
  `branch`/`rebase`/`cherry-pick` keywords are sufficient; `/pr` is user-invoked directly with
  explicit workflow flags, not keyword-auto-routed.

## Decisions

- Inline URL parser for `workflow_pr_ref` replicates the STEP 0.1 parser to avoid
  cross-step coupling; the parser logic is identical and short.
- STEP 1b Case B (auto-detect) tries current branch first, then falls back to all open
  benbrastmckie PRs — this reduces noise when the user is on an unrelated branch.
- `git commit --amend --no-edit` is used for amend (not interactive rebase), per the plan's
  non-goal of keeping interactive rebase out of scope.
- `--force-with-lease` (not `--force`) is used for safety; recovery guidance is included.
- No change to `manifest.json` keyword_overrides (recorded rationale: low priority, user-invoked).

## Plan Deviations

- None (implementation followed plan exactly across all 6 phases).

## Verification

- Build: N/A (markdown command-spec file)
- Tests: Structural greps — all passed:
  - `--stacked`/`--update`/`--amend` present in STEP 1, Options table, argument-hint, Workflow Selection table, Output Examples
  - `STEP 1b` heading exists between STEP 1 and STEP 2 (grep -c returns 4)
  - `force-with-lease` present in STEP 10 amend path and Notes
  - `gh pr create --base "$workflow_head_branch"` present for stacked
  - Update and amend sections explicitly note NO `gh pr create`
  - 4 `[DRY RUN] Would execute:` blocks present (one per workflow)
  - 4 AskUserQuestion approval options for push (new/stacked/update/amend)
  - STEP 0, 0.1, 0.2, 0.5.1–0.5.7 headings all present and untouched
  - `.claude/commands/pr.md` is a symlink to `../extensions/cslib/commands/pr.md` (live immediately)

## Notes

The symlinked `.claude/commands/pr.md` reflects all changes immediately — no reinstall needed.
All new logic is confined to the PR-submission path (STEP 1 onwards); the `--review` early-exit
path and the PR-READY review-response path (STEP 0.5.x) remain byte-for-byte untouched.
