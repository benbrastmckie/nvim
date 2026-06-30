# Implementation Plan: Task #784 — /pr Workflow Selection Front-End

- **Task**: 784 - pr_command_workflow_selection
- **Status**: [COMPLETED]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_pr-workflow-selection-research.md
- **Artifacts**: plans/01_pr-workflow-selection-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-formats.md; state-management.md
- **Type**: meta

## Overview

Add a four-workflow selection front-end to the PR-submission path of the `/pr` command
(`.claude/extensions/cslib/commands/pr.md`). A new early step (STEP 1b) resolves which of four
workflows applies — NEW (default), STACKED on an upstream PR, UPDATE an existing PR, or
AMEND/SQUASH + force-push — before any branch/CI work. Three mutually-exclusive flags
(`--stacked [PR]`, `--update [PR]`, `--amend [PR]`) plus an auto-detect-and-confirm interactive
fallback drive the choice. Downstream steps (STEP 4 sync, STEP 5/5b branch, STEP 10 push/create)
branch conditionally on the resolved workflow. The `--review` path (STEP 0–0.2) and the PR-READY
review-response path (STEP 0.5.x) must remain completely UNTOUCHED. Definition of done: all four
workflows are documented, gated behind explicit AskUserQuestion approval before any push, honor
`--dry-run`, coexist with `--draft`/`--branch`, and the symlinked `.claude/commands/pr.md`
reflects the changes (no reinstall needed).

### Research Integration

The research report (`reports/01_pr-workflow-selection-research.md`) provides the authoritative
edit map. Key findings integrated:

- **Insertion point**: new STEP 1b after STEP 1 (line 758) and before STEP 2 (line 760); existing
  CI step numbering (7–11) is preserved.
- **Downstream branching points**: STEP 4 (lines 909–937), STEP 5 (939–1007), STEP 5b (1009–1036),
  STEP 10 (1499–1617).
- **URL-parsing reuse**: the STEP 0.1 GitHub PR URL parser (lines 88–93) is replicated inline for
  workflow PR refs.
- **gh CLI** (2.93.0): `gh pr list --repo leanprover/cslib --author benbrastmckie --state open
  --json number,title,headRefName,baseRefName,url`, `gh pr view <N> --json headRefName,...`,
  `gh pr checkout <N>`, `gh pr create --base <branch>` are all verified.
- **git** (2.54.0): `git push --force-with-lease` is available and permitted within `/pr`.
- **Deployment**: `.claude/commands/pr.md` is a symlink to the extension source, so editing the
  source is immediately live — no deploy phase.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this plan (no roadmap_path provided; roadmap_flag not set).

## Goals & Non-Goals

**Goals**:
- Add `--stacked [PR]`, `--update [PR]`, `--amend [PR]` flags with an optional positional PR ref
  (number or full GitHub PR URL), mutually exclusive, defaulting to NEW when none is given.
- Insert STEP 1b that resolves the workflow and PR-derived branch variables before STEP 2.
- Implement "auto-detect, confirm always": when a PR ref is needed but absent (or no flag is
  given and a probe is warranted), query gh and ALWAYS confirm via AskUserQuestion — never silent
  auto-proceed.
- Conditionally branch STEP 4 (sync), STEP 5/5b (branch creation/checkout), and STEP 10
  (push/create) on the resolved workflow.
- Keep an explicit approval gate before every push and force-push; support `--dry-run` for all
  four workflows.
- Update docs (frontmatter `argument-hint`, Options table, Input Modes/Notes, Output Examples, a
  workflow-selection overview) and verify/extend manifest `keyword_overrides`.

**Non-Goals**:
- Do NOT modify the `--review` path (STEP 0, 0.1, 0.2) or the PR-READY review-response path
  (STEP 0.5.1–0.5.7).
- Do NOT implement interactive `git rebase -i` squash (out of scope per research Decisions); amend
  uses `git commit --amend` only.
- Do NOT add a separate deploy/reinstall step (symlink makes edits live).
- Do NOT change the 7-step CI pipeline (STEP 7) logic.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Accidentally editing STEP 0/0.5 review paths | H | L | Phase verification greps confirm STEP 0/0.1/0.2/0.5.x bodies are byte-unchanged; each phase scopes edits to specific STEP headings |
| Force-push (`--force-with-lease`) data loss on amend | H | L | Mandatory AskUserQuestion approval gate before force-push; document force-push rejection recovery message |
| Mutual-exclusion not enforced -> ambiguous workflow | M | M | Phase 1 adds explicit check that errors+STOPs if 2+ workflow flags appear |
| Auto-detect returns too many PRs | L | M | Add `--limit 10` to gh queries; show candidates in AskUserQuestion, never silent pick |
| Stacked/update/amend PR ref points to closed/merged or non-benbrastmckie PR | M | L | STEP 1b validates `gh pr view` state and `headRepositoryOwner.login`; warn before proceeding |
| Symlink not reflecting edits | M | L | Final verification reads through `.claude/commands/pr.md` and greps for new flags/steps |
| Breaking existing `--draft`/`--dry-run`/`--branch` parsing | M | L | Phase 1 extends the existing parse loop additively; verification greps confirm old flags still handled |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 1 |
| 6 | 6 | 1, 2, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phase 5 (docs) depends only on the flag
scheme (Phase 1) and may run in parallel with Phases 2–4. Phase 6 is a final verification gate.

---

### Phase 1: Flag Parsing + Workflow Variable Initialization (STEP 1) [COMPLETED]

**Goal**: Extend STEP 1's argument parser to recognize the three new workflow flags with an
optional PR ref, initialize workflow state variables, and enforce mutual exclusion — without
disturbing existing `--draft`/`--dry-run`/`--branch`/input parsing.

**File**: `.claude/extensions/cslib/commands/pr.md` — STEP 1 (lines 735–758).

**Tasks**:
- [ ] In the STEP 1 defaults block (lines 740–745), add initialization for:
      `workflow="new"` (values: `new` | `stacked` | `update` | `amend`),
      `workflow_pr_ref=""` (raw number or URL), `workflow_pr_number=""` (resolved integer),
      `workflow_head_branch=""` (resolved PR head ref), `stacked_base_branch=""`.
- [ ] Extend the parse description (lines 747–751) to recognize `--stacked`, `--update`,
      `--amend`, each optionally followed by a PR ref token matching
      `^[0-9]+$|github\.com.*pull` (consume the token only when it matches; otherwise leave the
      workflow PR ref empty for STEP 1b auto-detection).
- [ ] Add an inline GitHub PR URL parser replicated from STEP 0.1 (lines 88–93) to resolve
      `workflow_pr_number` from `workflow_pr_ref` when it is a URL; bare integers map directly.
- [ ] Add a mutual-exclusion check: if more than one of `--stacked`/`--update`/`--amend` is
      present, display an error and **STOP**.
- [ ] Confirm the input-mode determination (lines 753–756) still classifies the first non-flag
      token; new flags must not be mistaken for `input_value`.

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — STEP 1 only.

**Verification**:
- `grep -n -- '--stacked' .claude/extensions/cslib/commands/pr.md` returns matches in STEP 1.
- `grep -n 'workflow="new"' ...` confirms default init present.
- `grep -n 'workflow=' ...` shows the four workflow values referenced.
- `grep -n 'mutual' ...` (or an explicit "more than one" error string) confirms exclusion check.
- Confirm `--draft`, `--dry-run`, `--branch` tokens are still handled (grep each).
- Confirm STEP 0/0.1/0.2 and STEP 0.5.x sections are byte-unchanged (grep their headings; no edits
  above line 735).

---

### Phase 2: Insert STEP 1b — Workflow Determination + Interactive Auto-Detection [COMPLETED]

**Goal**: Add a new STEP 1b between STEP 1 and STEP 2 that resolves the workflow's PR ref and
derived branch variables, running auto-detection + an always-on AskUserQuestion confirmation when
a ref is needed but absent, and skipping cleanly for the default NEW case.

**File**: `.claude/extensions/cslib/commands/pr.md` — insert after line 758 (end of STEP 1),
before line 760 (start of STEP 2).

**Tasks**:
- [ ] Add a `### STEP 1b: Determine Workflow` section with an EXECUTE NOW directive and the
      three resolution cases:
      - **Case A** (flag + PR ref supplied): resolve `workflow_pr_number`, call
        `gh pr view "$workflow_pr_number" --repo leanprover/cslib --json
        headRefName,baseRefName,state,headRepositoryOwner,title,url`; set `workflow_head_branch`
        (and `stacked_base_branch` for stacked); validate state is `open` and owner is
        `benbrastmckie` (warn otherwise); confirm via AskUserQuestion.
      - **Case B** (flag given, no PR ref): run auto-detect:
        `current_branch=$(git -C /home/benjamin/Projects/cslib branch --show-current)`, then
        `gh pr list --repo leanprover/cslib --author benbrastmckie --state open --head
        "$current_branch" --limit 10 --json number,title,headRefName,baseRefName,url`; if empty,
        re-query without `--head`. Present an AskUserQuestion listing each candidate (number,
        title, headRefName) plus "Supply a PR URL or number manually", "Switch to NEW workflow",
        and "Cancel". Never silently auto-proceed.
      - **Case C** (no flag): `workflow="new"`; skip detection (proceed to STEP 2).
- [ ] Add the "Supply manually" sub-flow: prompt "Enter the GitHub PR URL or PR number:" and read
      the next message; re-run the same resolution/validation as Case A.
- [ ] Add the "no candidates found" branch: display the no-PRs message and offer
      "Supply manually" / "Switch to NEW" / "Cancel".
- [ ] Set resolved variables consumed downstream: `workflow`, `workflow_pr_number`,
      `workflow_head_branch`, `stacked_base_branch`.
- [ ] End STEP 1b with **IMMEDIATELY CONTINUE to STEP 2**.

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — new STEP 1b section only (insertion between
  existing STEP 1 and STEP 2).

**Verification**:
- `grep -n 'STEP 1b' .claude/extensions/cslib/commands/pr.md` confirms the new heading exists
  between STEP 1 and STEP 2.
- `grep -n 'gh pr list' ...` and `grep -n 'gh pr view' ...` confirm auto-detect/resolve queries.
- `grep -n 'AskUserQuestion' ...` within STEP 1b confirms the confirmation gate.
- `grep -n 'Supply a PR URL' ...` confirms the manual-entry option.
- `grep -n 'Switch to NEW' ...` confirms the fall-back-to-new option.
- Confirm STEP 2 heading (`### STEP 2: Resolve Input`) still immediately follows STEP 1b.

---

### Phase 3: Conditional Branching in STEP 4 (Sync) and STEP 5/5b (Branch/Checkout) [COMPLETED]

**Goal**: Make upstream sync and branch creation branch by workflow: NEW from `upstream/main`
(existing), STACKED from the parent PR head, UPDATE/AMEND by checking out the existing PR head.
STEP 5b cache fetch still runs after any branch switch.

**File**: `.claude/extensions/cslib/commands/pr.md` — STEP 4 (909–937), STEP 5 (939–1007),
STEP 5b (1009–1036).

**Tasks**:
- [ ] STEP 4: wrap the `git fetch upstream` block so that — `new`: fetch upstream as today;
      `stacked`: also `git fetch origin "$workflow_head_branch"`; `update`/`amend`: skip
      fetch-upstream (not required) and instead `git fetch origin`.
- [ ] STEP 5: branch the creation logic on `$workflow`:
      - `new`: `git checkout upstream/main -b "$branch_name"` (existing behavior, unchanged).
      - `stacked`: `git checkout origin/"$workflow_head_branch" -b "$branch_name"`.
      - `update`/`amend`: `gh pr checkout "$workflow_pr_number" --repo leanprover/cslib` (or
        equivalently `git checkout "$workflow_head_branch"`); set `branch_name` to the checked-out
        head ref.
- [ ] STEP 5: update the AskUserQuestion prompt text so the "from upstream/main" phrasing is
      conditional (e.g., "from upstream/main" for new, "from PR #N head" for stacked, "checkout
      existing PR #N branch" for update/amend).
- [ ] STEP 5b: confirm the mathlib cache fetch (`lake exe cache get`) still runs after any branch
      switch (applies to all workflows); add a note that it runs for stacked/update/amend too.
- [ ] Preserve `--dry-run` short-circuits in STEP 5 for each workflow variant.

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — STEP 4, STEP 5, STEP 5b.

**Verification**:
- `grep -n 'origin/"\?\$workflow_head_branch' ...` (or `origin/$workflow_head_branch`) confirms
  stacked branch-from-PR-head logic.
- `grep -n 'gh pr checkout' ...` confirms update/amend checkout path.
- `grep -n 'upstream/main -b' ...` confirms NEW path is retained.
- `grep -n 'cache get' ...` confirms STEP 5b still present and applies on switch.
- Confirm each STEP 4/5 branch references `$workflow`.
- Confirm STEP 0.5.x and STEP 0 paths untouched.

---

### Phase 4: STEP 10 Push/Create Conditional Logic + Approval Gates + Dry-Run [COMPLETED]

**Goal**: Branch the commit/push/create logic on `$workflow`: plain push + NO `gh pr create` for
update; `git push --force-with-lease` + NO create for amend; `gh pr create --base
$workflow_head_branch` for stacked; current behavior for new. Each variant keeps an explicit
AskUserQuestion approval gate before push and a `--dry-run` preview.

**File**: `.claude/extensions/cslib/commands/pr.md` — STEP 10 (1499–1617).

**Tasks**:
- [ ] Add an amend pre-push step: for `amend`, after CI passes and before push, run
      `git add -A && git commit --amend --no-edit` (replacing the normal commit) — guarded by the
      approval gate.
- [ ] Branch the final-approval AskUserQuestion summary text per workflow (e.g., "Force-push amend
      to PR #N?", "Update PR #N (push, no new PR)?", "Submit stacked PR based on
      $workflow_head_branch?", existing "Submit this PR?" for new). Each must require explicit
      confirmation before any push/force-push.
- [ ] Branch the execution block on `$workflow`:
      - `new`: existing `git push -u origin "$branch_name"` + `gh pr create --base "$base_branch"`
        (unchanged).
      - `stacked`: `git push -u origin "$branch_name"` + `gh pr create --base
        "$workflow_head_branch" --repo leanprover/cslib ...`.
      - `update`: `git push origin "$branch_name"` and NO `gh pr create`; display "Updated PR
        #$workflow_pr_number — push complete" with the PR URL.
      - `amend`: `git push --force-with-lease origin "$branch_name"` and NO `gh pr create`;
        display "Amended PR #$workflow_pr_number — force-push complete".
- [ ] Extend the `--dry-run` block with per-workflow previews:
      stacked => `git push -u origin {branch}; gh pr create --base {head}`;
      update => `git push origin {branch}` (no create);
      amend => `git push --force-with-lease origin {branch}` (no create).
- [ ] Add the force-push-rejected recovery message (from research §7) for the amend path.
- [ ] Ensure STEP 10b (task status -> COMPLETED) still runs for new/stacked; for update/amend,
      confirm status transition behavior is sensible (task may already be COMPLETED; keep the
      existing non-fatal note).

**Timing**: 1.5 hours

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — STEP 10 (and adjacent STEP 10b note if needed).

**Verification**:
- `grep -n 'force-with-lease' ...` confirms the amend push.
- `grep -n 'gh pr create --base "\$workflow_head_branch"' ...` (or `--base "$workflow_head_branch"`)
  confirms stacked create.
- Confirm an update branch performs `git push origin` with NO adjacent `gh pr create` (read the
  update block).
- `grep -n 'DRY RUN' ...` shows per-workflow dry-run previews exist (count >= 1 per new variant).
- `grep -n 'AskUserQuestion' ...` within STEP 10 confirms approval gates per workflow.
- Confirm `commit --amend` present for amend path.

---

### Phase 5: Documentation Updates + Manifest keyword_overrides Verification [COMPLETED]

**Goal**: Update all user-facing documentation in pr.md for the new workflows and verify whether
the cslib manifest `keyword_overrides` need extension.

**File**: `.claude/extensions/cslib/commands/pr.md` — frontmatter (1–6), Options table (29–37),
Input Modes/overview (15–37), Output Examples (1721–1758), Notes (1799–1806). Also
`.claude/extensions/cslib/manifest.json`.

**Tasks**:
- [ ] Update frontmatter `argument-hint` (line 4) to include
      `[--stacked [PR]] [--update [PR]] [--amend [PR]]` alongside existing flags.
- [ ] Extend the Options table (lines 31–36) with four rows: `--stacked [PR]`, `--update [PR]`,
      `--amend [PR]` (note default = new), describing each and the optional PR ref.
- [ ] Add a short "Workflow Selection" overview subsection near the top (after the Options table,
      around line 37) summarizing the four workflows and the auto-detect-confirm behavior.
- [ ] Add Output Examples for stacked, update, and amend (mirroring the existing
      "Successful PR Submission" / "Dry-Run Output" blocks at 1723–1758).
- [ ] Add a Notes bullet (lines 1799–1806) describing workflow selection, the force-with-lease
      safety for amend, and that all workflows keep an approval gate.
- [ ] Verify manifest `keyword_overrides`: the existing `pr` keywords already include `submit`,
      `upstream`, `branch`, `rebase`, `cherry-pick`. Decide whether to add `stacked`/`amend`;
      since `/pr` is explicitly user-invoked (not keyword-auto-routed for these workflows), document
      the decision in the plan/summary. Extend only if the team wants `stacked`/`amend` task
      auto-detection (low priority; default = no change, record rationale).

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/commands/pr.md` — frontmatter, Options, overview, Output Examples,
  Notes.
- `.claude/extensions/cslib/manifest.json` — only if keyword_overrides extension is chosen.

**Verification**:
- `grep -n 'stacked' .claude/extensions/cslib/commands/pr.md` shows matches in argument-hint,
  Options table, overview, and Output Examples.
- `grep -n 'Workflow Selection' ...` confirms the overview subsection.
- `grep -n -- '--amend' ...` and `grep -n -- '--update' ...` appear in the Options table.
- `jq '.keyword_overrides.pr.keywords' .claude/extensions/cslib/manifest.json` reviewed; record
  whether changed.

---

### Phase 6: Final Structural Verification (No-Regression Gate) [COMPLETED]

**Goal**: Confirm the complete edit set is internally consistent, the review paths are untouched,
and the deployed symlink reflects all changes.

**File**: read-only verification across `.claude/extensions/cslib/commands/pr.md` and
`.claude/commands/pr.md`.

**Tasks**:
- [ ] Confirm `.claude/commands/pr.md` is still a symlink to `../extensions/cslib/commands/pr.md`
      (`ls -la`) and that reading through it shows the new STEP 1b and flags
      (`grep -n 'STEP 1b' .claude/commands/pr.md`).
- [ ] Confirm STEP 0, 0.1, 0.2 and STEP 0.5.1–0.5.7 bodies are unchanged (diff the byte ranges or
      grep each heading and spot-check that no workflow logic leaked in).
- [ ] Confirm all four workflows appear in STEP 1b, STEP 4/5, and STEP 10
      (grep `new`/`stacked`/`update`/`amend` co-occurrence in each region).
- [ ] Confirm every push/force-push in the new logic is preceded by an AskUserQuestion gate.
- [ ] Confirm a `--dry-run` path exists for each of the four workflows in STEP 10.
- [ ] Confirm no `gh pr create` is emitted for update or amend.

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3, 4, 5

**Files to modify**:
- None (verification only).

**Verification**:
- `ls -la .claude/commands/pr.md` shows the symlink target.
- `grep -c 'STEP 1b' .claude/commands/pr.md` >= 1.
- Heading inventory for STEP 0/0.5.x matches the pre-edit set (no additions/removals).
- Workflow tokens present in STEP 1b, STEP 4/5, STEP 10.

---

## Testing & Validation

- [ ] `grep -n -- '--stacked\|--update\|--amend' .claude/extensions/cslib/commands/pr.md` — all
      three flags present in parsing and docs.
- [ ] `grep -n 'STEP 1b' .claude/extensions/cslib/commands/pr.md` — new step present between
      STEP 1 and STEP 2.
- [ ] `grep -n 'force-with-lease' .claude/extensions/cslib/commands/pr.md` — amend push present.
- [ ] STEP 10 contains a `gh pr create --base "$workflow_head_branch"` for stacked and NO create
      for update/amend.
- [ ] Each new workflow has a `--dry-run` preview and an AskUserQuestion approval gate before push.
- [ ] STEP 0/0.1/0.2 and STEP 0.5.x sections are byte-identical to pre-edit (no review-path
      regressions).
- [ ] `.claude/commands/pr.md` (symlink) reflects all edits.
- [ ] manifest `keyword_overrides` decision recorded (changed or intentionally unchanged).

## Artifacts & Outputs

- `.claude/extensions/cslib/commands/pr.md` — modified command source (STEP 1, new STEP 1b,
  STEP 4, STEP 5, STEP 5b, STEP 10, frontmatter, Options, overview, Output Examples, Notes).
- `.claude/extensions/cslib/manifest.json` — optionally modified `keyword_overrides`.
- `.claude/commands/pr.md` — auto-updated via symlink (no separate write).
- `specs/784_pr_command_workflow_selection/plans/01_pr-workflow-selection-plan.md` — this plan.
- `specs/784_pr_command_workflow_selection/summaries/01_pr-workflow-selection-summary.md` —
  produced at implementation completion.

## Rollback/Contingency

All changes are confined to two files under version control. To revert:
`git checkout -- .claude/extensions/cslib/commands/pr.md .claude/extensions/cslib/manifest.json`.
Because deployment is via symlink, reverting the source immediately restores the deployed command;
no reinstall is needed. If a single phase introduces a regression, revert only the affected STEP
region (each phase is scoped to distinct, non-overlapping STEP sections), re-run the phase's
verification greps, and re-apply. The review paths (STEP 0/0.5.x) are never touched, so the
`--review` and PR-READY response workflows remain a safe fallback throughout.
