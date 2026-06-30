# Research Report: Task #784 — /pr Workflow Selection Front-End

**Task**: 784 - pr_command_workflow_selection
**Started**: 2026-06-30T00:00:00Z
**Completed**: 2026-06-30T00:30:00Z
**Effort**: ~2 hours (research phase)
**Dependencies**: None
**Sources/Inputs**: Codebase (pr.md, manifest.json, install-extension.sh, pr-prohibition.md), live `gh` CLI
**Artifacts**: `specs/784_pr_command_workflow_selection/reports/01_pr-workflow-selection-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- The `/pr` command source is at `.claude/extensions/cslib/commands/pr.md` (1806 lines), deployed via symlink to `.claude/commands/pr.md` — editing the source is sufficient, no re-deploy step needed.
- The existing STEP structure has a clear insertion point after STEP 1 (argument parsing, lines 735–758) and before STEP 2 (input resolution). The new workflow-selection step should become STEP 1.5 or be labeled "STEP 1b."
- All four workflows are feasible with the `gh` 2.93.0 CLI available: `gh pr list --repo leanprover/cslib --author benbrastmckie` returns structured JSON with `headRefName`, `baseRefName`, `number`, `title`, `url`. `gh pr checkout <N>` fetches and checks out a PR head. `gh pr create --base <branch>` covers stacked PRs.
- `--force-with-lease` is available in git 2.54.0. The pr-prohibition.md explicitly permits push/force-push within the user-invoked `/pr` command.
- The flag scheme (`--stacked`, `--update`, `--amend`, each with optional PR ref) interacts cleanly with existing `--draft`, `--dry-run`, `--branch` flags with no conflicts.

---

## Context & Scope

This research covers the structural analysis needed to plan the addition of a four-workflow selection front-end to the PR-submission path of the `/pr` command. The `--review` path (STEP 0, 0.1, 0.2) and the PR-READY review-response path (STEP 0.5.x) are explicitly out of scope and must not be modified.

---

## Findings

### 1. Current `/pr` Structure — Full Step Map

Source: `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md` (1806 lines)

**Frontmatter** (lines 1–6):
```yaml
description: Create and submit a CSLib PR, or create a PR review task (--review)
allowed-tools: Bash, Read, Edit, Write, AskUserQuestion
argument-hint: "<task_number | path | description> [--draft] [--dry-run] [--branch BRANCH] | --review <urls/descriptions...>"
model: opus
```

**Step map**:

| Step | Lines | Title | Purpose |
|------|-------|-------|---------|
| STEP 0 | 44–49 | Check for --review Flag | Early-exit for --review path |
| STEP 0.1 | 51–177 | Parse Source Arguments | Token classification for --review |
| STEP 0.2 | 180–337 | Create Review Task | Write state.json, commit |
| STEP 0.5 | 341–381 | Handle PR READY Review Response | Detect pr_ready + sources; early-exit |
| STEP 0.5.1 | 387–435 | Resolve Task Context | Read cslib state.json metadata |
| STEP 0.5.2 | 437–493 | Show Summary | Display task/PR info |
| STEP 0.5.3 | 495–529 | Approval Gate — Push and Comment | AskUserQuestion |
| STEP 0.5.4 | 531–581 | Execute Push and Post Comment | git commit/push, gh pr comment |
| STEP 0.5.5 | 583–659 | Approval Gate — Zulip Send | AskUserQuestion for Zulip |
| STEP 0.5.6 | 661–686 | Execute Zulip Send | zulip-send |
| STEP 0.5.7 | 688–731 | Transition to COMPLETED | update-task-status.sh |
| STEP 1 | 735–758 | Parse Arguments | Parse flags, set input_mode |
| STEP 2 | 760–852 | Resolve Input and Working Description | Read task metadata, pr-description.md |
| STEP 3 | 854–907 | Environment Check | gh auth, remotes, lakefile |
| STEP 4 | 909–937 | Sync with Upstream | `git fetch upstream` |
| STEP 5 | 939–1007 | Branch Creation | Propose slug, AskUserQuestion, create from upstream/main |
| STEP 5b | 1009–1036 | Fetch Mathlib Cache | `lake exe cache get` |
| STEP 6 | 1038–1089 | Stage Changes | Show/apply diff |
| STEP 7 | 1091–1248 | Run CI Pipeline | 7-step CI (lake build, checkInitImports, lint, lint-style, test, mk_all, shake) |
| STEP 8 | 1250–1366 | Select PR Title | 3-step interactive or pr-description.md fast path |
| STEP 9 | 1368–1471 | Compose PR Description | Template or pr-description.md approval |
| STEP 9b | 1473–1497 | Copy PR Description to Feature Branch | Task mode only |
| STEP 10 | 1499–1617 | Commit, Push, and Create PR | git add, commit, push, gh pr create |
| STEP 10b | 1619–1648 | Transition Task Status to Completed | update-task-status.sh |
| STEP 11 | 1650–1717 | Offer Merge-Back | Sync origin/main with upstream/main |

**Key insertion point**: The new workflow-determination step inserts immediately after STEP 1 (line 758) and before STEP 2 (line 760). It should be labeled **STEP 1b: Determine Workflow**.

**Downstream branching points**:
- **STEP 4** (lines 909–937): Currently always fetches `upstream` and creates branch from `upstream/main`. Must branch by workflow.
- **STEP 5** (lines 939–1007): Branch creation. Currently always `git checkout upstream/main -b "$branch_name"`. Must branch by workflow.
- **STEP 10** (lines 1499–1617): Currently always `git push -u origin "$branch_name"` then `gh pr create`. Must branch for update (no create) and amend (force-push, no create).

**Existing URL-parsing logic to reuse**: STEP 0.1 (lines 51–149) contains the GitHub PR URL parser:
```bash
owner=$(echo "$TOKEN" | sed 's|.*github\.com/||; s|/.*||')
repo=$(echo "$TOKEN" | sed 's|.*github\.com/[^/]*/||; s|/.*||')
pr_number=$(echo "$TOKEN" | sed 's|.*/pull/||; s|[/#].*||; s|[^0-9].*||')
```
This pattern must be extracted/replicated in the new STEP 1b for `--stacked URL`, `--update URL`, and `--amend URL` arguments.

**Existing `base_branch` hook** (STEP 2, lines 817–828): A `base_branch` variable is already read from `state.json` (default: `"main"`). The stacked workflow will override this from the PR's `baseRefName` / `headRefName`. The stacked advisory warning at lines 822–828 is relevant — it already detects `"stacked"` in pr_body. This advisory can be removed once the `--stacked` flag handles this explicitly.

---

### 2. Deployment Model

Source: `.claude/scripts/install-extension.sh` (lines 75–109) and `.claude/extensions/cslib/manifest.json`

The deployment model uses **symlinks**:
```
.claude/commands/pr.md -> ../extensions/cslib/commands/pr.md
```
Confirmed live:
```
lrwxrwxrwx .claude/commands/pr.md -> ../extensions/cslib/commands/pr.md
```

The `install_commands()` function in `install-extension.sh` (line 76) creates a relative symlink `../extensions/{EXT_NAME}/commands/{cmd_name}` in `.claude/commands/`. Because it is a symlink, **editing `.claude/extensions/cslib/commands/pr.md` immediately updates the deployed command — no reinstall needed**.

The `manifest.json` lists `"commands": ["pr.md", "vet.md"]` under `"provides"`. The `merge_targets.claudemd` section (source: `EXTENSION.md`, target: `.claude/CLAUDE.md`) merges the extension's CLAUDE.md content on install, but command changes do not require CLAUDE.md regeneration.

**Re-deploy procedure** (for completeness): If ever needed, run:
```bash
bash .claude/scripts/install-extension.sh .claude/extensions/cslib
```
But since the symlink exists, this is not needed for command file edits.

---

### 3. gh CLI Capabilities

**Version**: gh 2.93.0 (nixpkgs), available at `/usr/bin/gh` or via nix profile.

#### 3a. List open PRs from benbrastmckie on leanprover/cslib

```bash
gh pr list \
  --repo leanprover/cslib \
  --author benbrastmckie \
  --state open \
  --json number,title,headRefName,baseRefName,url
```

**Verified output** (live query on 2026-06-30):
```json
[
  {"baseRefName":"main","headRefName":"feat/modal-formula-primitives","number":662,"title":"feat(Logics/Modal): refactor formula primitives","url":"https://github.com/leanprover/cslib/pull/662"},
  {"baseRefName":"main","headRefName":"feat/temporal-formula-propositional","number":649,"title":"feat(Logics/LTL): LTL formula type and semantics","url":"https://github.com/leanprover/cslib/pull/649"},
  {"baseRefName":"main","headRefName":"feat/propositional-v2","number":648,"title":"feat(Logics/Propositional): five-primitive formula type","url":"https://github.com/leanprover/cslib/pull/648"}
]
```

**Matching by branch name**: `--head <branch-name>` filters by head branch name (note: `--head` does NOT support `owner:branch` syntax). To match by current git branch:
```bash
current_branch=$(git branch --show-current)
gh pr list --repo leanprover/cslib --author benbrastmckie --state open \
  --head "$current_branch" --json number,title,headRefName,baseRefName,url
```

**Matching by task slug**: When no branch match, fall back to listing all open PRs and filtering by task slug in the title or headRefName.

#### 3b. Get PR head ref details

```bash
gh pr view 662 --repo leanprover/cslib \
  --json headRefName,headRepositoryOwner,title,number,baseRefName,url
```

**Verified output**:
```json
{
  "baseRefName": "main",
  "headRefName": "feat/modal-formula-primitives",
  "headRepositoryOwner": {"login": "benbrastmckie", "name": "Benjamin Brast-McKie"},
  "number": 662,
  "title": "...",
  "url": "..."
}
```

The `headRefName` is the branch name in the fork. The `headRepositoryOwner.login` confirms it's from the user's fork (benbrastmckie).

#### 3c. Fetching a PR head ref

For PRs from the user's own fork, the head branch is already available via `origin`. Two approaches:

**Approach A — via `gh pr checkout`**:
```bash
gh pr checkout 662 --repo leanprover/cslib
```
This fetches the PR head ref from the PR author's fork and creates a local tracking branch. For the user's own fork, it is equivalent to `git fetch origin && git checkout feat/modal-formula-primitives`.

**Approach B — via git fetch refs/pull**:
```bash
git fetch upstream refs/pull/662/head:refs/remotes/upstream/pr/662
git checkout -b feat/modal-formula-primitives upstream/pr/662
```
Verified: `git ls-remote upstream 'refs/pull/662/head'` returns `f46056b9b6ebf44c322e88278b64ada959dbf146	refs/pull/662/head`.

**Recommended for this context (user's own fork)**: `gh pr checkout <N> --repo leanprover/cslib` is the cleanest approach. Since the branches already exist on `origin` (fork), it effectively does `git fetch origin && git checkout <headRefName>`.

#### 3d. Stacked PR: `gh pr create --base`

```bash
gh pr create \
  --base "feat/modal-formula-primitives" \
  --repo leanprover/cslib \
  --title "..." \
  --body "..."
```

The `--base` flag sets the target branch for the PR. For a stacked PR, `--base` should be set to the `headRefName` of the parent PR (e.g., `feat/modal-formula-primitives`). When the parent PR is merged to `main`, GitHub automatically retargets the child PR.

**Note**: `gh pr create` supports `--head <user>:<branch>` but this is only needed for cross-repo scenarios. For our fork model (pushing to `origin` and targeting `upstream`), just specifying `--base <branch>` is sufficient.

#### 3e. Auth and permissions

`gh auth status` must succeed before any `gh` commands. This is already checked in STEP 3 (lines 865–882). No additional scopes are needed for `gh pr list`, `gh pr view`, `gh pr checkout`, or `gh pr create` beyond the standard repo scope.

---

### 4. Git Mechanics Per Workflow

**Shared setup**: All workflows start with STEP 3 (environment check) already passing. `git fetch upstream` is called in STEP 4 but can be conditional.

#### Workflow 1: NEW (default)

Current behavior in STEP 4–5. No changes needed to logic, just guarded by `workflow="new"`:
```bash
git fetch upstream
git checkout upstream/main -b "$branch_name"
```
Then STEP 10: `git push -u origin "$branch_name"` + `gh pr create --base main`.

#### Workflow 2: STACKED

The feature branch is created from the HEAD of the target (parent) PR's head branch, not from `upstream/main`.

```bash
# Fetch the parent PR's head ref
parent_pr_head=$(gh pr view "$stacked_pr_number" --repo leanprover/cslib \
  --json headRefName --jq '.headRefName')

# Fetch origin to get the latest state of the parent PR's branch
git fetch origin "$parent_pr_head"

# Create the feature branch from the parent PR's head
git checkout origin/"$parent_pr_head" -b "$branch_name"
```

STEP 5b (Mathlib cache): Still applies — `lake exe cache get` after branch switch.

STEP 10 push and create:
```bash
git push -u origin "$branch_name"
gh pr create \
  --base "$parent_pr_head" \
  --repo leanprover/cslib \
  --title "$pr_title" \
  --body "$pr_body"
```

**Note**: The `--head` flag for `gh pr create` should point to the user's fork branch. Since we push to `origin` (benbrastmckie/cslib), gh automatically uses `benbrastmckie:$branch_name` as the head when creating a PR against `leanprover/cslib`.

#### Workflow 3: UPDATE

Update an existing PR: checkout the existing PR head branch, add changes, push normally (no `gh pr create`).

```bash
# Checkout the existing PR's head branch
gh pr checkout "$update_pr_number" --repo leanprover/cslib
# or equivalently:
git fetch origin
git checkout "$pr_head_branch"
```

The rest of the pipeline (CI, title/description review) runs on the checked-out branch. At STEP 10:
```bash
git push origin "$branch_name"
# NO gh pr create — PR already exists
```

Display instead: "Updated PR #${update_pr_number} — push complete."

#### Workflow 4: AMEND/SQUASH

Amend or squash onto the existing PR branch, then force-push.

```bash
# Checkout the existing PR's head branch
gh pr checkout "$amend_pr_number" --repo leanprover/cslib

# After CI passes and user reviews:
# Option A: amend
git add -A && git commit --amend --no-edit

# Option B: squash (user-driven — could also just amend)
# (Squash is more complex; recommend amend as the primary path with squash as advanced)

git push --force-with-lease origin "$branch_name"
# NO gh pr create
```

**Safety**: `--force-with-lease` is the safe force-push: it fails if the remote has commits the local branch doesn't know about (i.e., someone else pushed). This is the correct choice per the task description.

---

### 5. Flag-Parsing Design

**Current STEP 1** (lines 735–758) initializes:
```
input_mode=""
input_value=""
is_draft=false
is_dry_run=false
branch_override=""  # from --branch FLAG
```

**Extended STEP 1** should additionally initialize:
```
workflow="new"         # "new" | "stacked" | "update" | "amend"
workflow_pr_ref=""     # PR number or URL (optional positional after workflow flag)
workflow_pr_number=""  # resolved integer
```

**Parsing logic** (extending the existing loop):
```bash
# Process $ARGUMENTS token by token:
while [ $# -gt 0 ]; do
  case "$1" in
    --stacked)
      workflow="stacked"
      # Check if next token is a PR ref (number or URL)
      if [ $# -gt 1 ] && echo "$2" | grep -qE '^[0-9]+$|github\.com.*pull'; then
        workflow_pr_ref="$2"; shift
      fi ;;
    --update)
      workflow="update"
      if [ $# -gt 1 ] && echo "$2" | grep -qE '^[0-9]+$|github\.com.*pull'; then
        workflow_pr_ref="$2"; shift
      fi ;;
    --amend)
      workflow="amend"
      if [ $# -gt 1 ] && echo "$2" | grep -qE '^[0-9]+$|github\.com.*pull'; then
        workflow_pr_ref="$2"; shift
      fi ;;
    --draft) is_draft=true ;;
    --dry-run) is_dry_run=true ;;
    --branch) branch_override="$2"; shift ;;
    *) input_value="$1" ;;  # task number, path, or description
  esac
  shift
done
```

**Mutual exclusion**: Only one of `--stacked`, `--update`, `--amend` may be set. If two appear, display an error and STOP.

**Interaction with `--dry-run`**: Each workflow variant should emit its dry-run preview in STEP 10. Existing dry-run logic covers the `new` case; similar blocks needed for stacked/update/amend.

**URL parsing** (reuse from STEP 0.1): When `workflow_pr_ref` contains a GitHub URL, parse the PR number with:
```bash
workflow_pr_number=$(echo "$workflow_pr_ref" | sed 's|.*/pull/||; s|[/#].*||; s|[^0-9].*||')
```
When `workflow_pr_ref` is a bare integer: `workflow_pr_number="$workflow_pr_ref"`.

---

### 6. Interactive Auto-Detection Flow

The "auto-detect, confirm always" flow triggers in two cases:
1. A workflow flag was given (`--stacked`, `--update`, `--amend`) but no PR ref was supplied.
2. No workflow flag at all (default path) AND a heuristic suggests an existing PR may be relevant.

**Implementation: STEP 1b (new step)**

```bash
# Step 1b: Workflow determination + auto-detection
# After parsing flags in STEP 1:

# Case A: Explicit flag with PR ref supplied -> resolve and confirm
# Case B: Explicit flag without PR ref -> query and confirm
# Case C: No flag -> skip (default = new; optionally probe for open PRs)
```

**Case B (flag given, no PR ref)**: Auto-detect candidates:
```bash
current_branch=$(git -C /home/benjamin/Projects/cslib branch --show-current 2>/dev/null)
# Query 1: exact branch match
candidates=$(gh pr list --repo leanprover/cslib --author benbrastmckie --state open \
  --head "$current_branch" \
  --json number,title,headRefName,url 2>/dev/null)

# Query 2: if no exact match, list all open PRs
if [ "$(echo "$candidates" | jq 'length')" -eq 0 ]; then
  candidates=$(gh pr list --repo leanprover/cslib --author benbrastmckie --state open \
    --json number,title,headRefName,url 2>/dev/null)
fi
```

**AskUserQuestion design** (when candidates found):

```json
{
  "question": "Select the PR to target for --{workflow} workflow:",
  "header": "PR Selection for {workflow} workflow",
  "multiSelect": false,
  "options": [
    {
      "label": "PR #{N}: {title} (branch: {headRefName})",
      "description": "Use this PR as the {parent/target} for {stacked/update/amend}"
    },
    { for each additional candidate... },
    {
      "label": "Supply a PR URL or number manually",
      "description": "Enter the PR URL or number in the conversation"
    },
    {
      "label": "Switch to NEW workflow (no PR ref needed)",
      "description": "Create a fresh branch from upstream/main instead"
    },
    {
      "label": "Cancel",
      "description": "Abort the /pr workflow"
    }
  ]
}
```

If "Supply manually": display "Enter the GitHub PR URL or PR number:" and read next message.

**Case C (no flag, no PR ref)**: The default is `new`. The task description says to probe only when "no workflow flag was given at all." The recommended behavior: proceed with `workflow="new"` without probing, unless the user has a `base_branch` set in state.json that is not `main` (already handled by the existing advisory warning in STEP 2). This minimizes friction for the common case.

**Multiple candidate PRs**: When more than one candidate exists, the `options` array shows all of them (title, number, headRefName). The user selects one.

**No candidates found**: Display "No open PRs found from benbrastmckie on leanprover/cslib matching the current branch or task slug." Then:
```json
{
  "options": [
    {"label": "Supply a PR URL or number manually", ...},
    {"label": "Switch to NEW workflow", ...},
    {"label": "Cancel", ...}
  ]
}
```

---

### 7. Constraints & Risks

#### pr-prohibition.md Compliance

The rule at `.claude/rules/pr-prohibition.md` explicitly exempts the `/pr` command:
> "For tasks with `task_type: "pr"` (CSLib pull request tasks) [...] **`/pr {task_number}`** (user-invoked command): The single entry point for branch creation, Mathlib cache fetch, the 7-step CI pipeline, PR title confirmation, and `gh pr create` submission."
> "The prohibition on agent-created PRs and agent pushes still applies. Only step 2 (the user-invoked `/pr` command) performs git push and PR creation."

`git push --force-with-lease` is a form of `git push` and is therefore **permitted** within the `/pr` command. The task description explicitly requires it for the amend workflow, which is consistent with the prohibition (it's user-invoked and has an explicit approval gate).

**Explicit approval gates required**: The task description specifies "Keep all four workflows behind explicit AskUserQuestion approval gates before any push/force-push." This must be reflected in STEP 10's branching: each workflow variant must show a summary and ask for confirmation before executing the push.

#### Force-Push Safety

`git push --force-with-lease origin "$branch_name"` (not `--force`) is the correct command for amend/squash. It fails if upstream has diverged unexpectedly, preventing accidental data loss.

**When force-push fails**: Display:
```
Error: Force-push rejected — remote branch has new commits not in your local branch.
This usually means someone else pushed to the branch, or a CI bot committed.
Fetch first: git fetch origin {branch_name}
Then rebase or reset, then re-run /pr --amend.
```

#### Dry-Run Support

Each of the four workflows must honor `is_dry_run`. In STEP 10:
- **new**: existing dry-run output (lines 1561–1570) is sufficient.
- **stacked**: add `[DRY RUN] Would execute: git push -u origin {branch}; gh pr create --base {parent_head} ...`
- **update**: add `[DRY RUN] Would execute: git push origin {branch}` (no pr create)
- **amend**: add `[DRY RUN] Would execute: git push --force-with-lease origin {branch}` (no pr create)

#### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| No upstream remote | Already caught in STEP 3 (lines 880–886); STOP with fix instructions |
| PR not found by number | `gh pr view` returns non-zero; display error + offer to supply different ref or cancel |
| Multiple candidate PRs (auto-detect) | Show all in AskUserQuestion options; user selects |
| Current branch is already the PR head (update/amend) | `gh pr checkout` will detect "already on this branch"; graceful |
| Detached HEAD state | `git branch --show-current` returns empty string; detect and warn before auto-detect |
| `gh pr checkout` in fork context | Works when origin is the user's fork. The command fetches from the PR author's fork (same as origin for own PRs) |
| Stacked on a contributor's PR (not benbrastmckie) | `headRepositoryOwner.login` check should warn if not benbrastmckie; stacking onto someone else's PR is unusual but allowed — fetch via `refs/pull/N/head` |

---

### 8. Concrete Recommendations — Edit Points by Step

The implementation plan should have the following phases, keyed to specific line ranges:

**Phase 1: STEP 1 extension — flag parsing** (lines 735–758)
- Extend the existing argument parser to recognize `--stacked [PR]`, `--update [PR]`, `--amend [PR]` with optional PR ref.
- Initialize `workflow`, `workflow_pr_ref`, `workflow_pr_number` variables.
- Add mutual-exclusion check.
- Reuse existing GitHub URL regex from STEP 0.1.

**Phase 2: Insert STEP 1b — workflow determination** (after line 758, before line 760)
- When `workflow_pr_ref` is provided: resolve `workflow_pr_number` (URL or integer), call `gh pr view` to get `headRefName` and `baseRefName`, display confirmation via AskUserQuestion.
- When flag given but no ref: run auto-detect query, show AskUserQuestion with candidates.
- When no flag: `workflow="new"`, skip detection.
- Set resolved variables: `workflow_head_branch`, `stacked_base_branch`.

**Phase 3: STEP 4 and STEP 5 branching** (lines 909–1007)
- STEP 4: for `new`, fetch upstream as before. For `stacked`, additionally fetch `origin/$parent_head`. For `update`/`amend`, skip fetch-upstream (not needed).
- STEP 5: branch by workflow:
  - `new`: `git checkout upstream/main -b "$branch_name"` (existing)
  - `stacked`: `git checkout origin/"$parent_head" -b "$branch_name"`
  - `update`/`amend`: `gh pr checkout "$workflow_pr_number" --repo leanprover/cslib` (or `git checkout "$pr_head_branch"`)

**Phase 4: STEP 10 branching — push and PR create** (lines 1499–1617)
- After commit block, branch on workflow:
  - `new`: existing push + `gh pr create --base main` (or `$base_branch`)
  - `stacked`: `git push -u origin "$branch_name"` + `gh pr create --base "$parent_head"`
  - `update`: `git push origin "$branch_name"` (no pr create); display updated PR URL
  - `amend`: `git push --force-with-lease origin "$branch_name"` (no pr create); display amended PR URL
- All paths must have an explicit AskUserQuestion before the push action.

**Phase 5: Documentation updates** (lines 1–37, 1719–1806)
- Update `argument-hint` frontmatter to include `[--stacked [PR]] | [--update [PR]] | [--amend [PR]]`.
- Extend the Options table with the four new flags.
- Add "Workflow Selection" section to Notes (lines 1799–1806).
- Update Output Examples with examples for each workflow.
- Update `manifest.json` keyword_overrides if needed (current `"pr"` keywords already cover submit/branch/upstream; "stacked" and "update" are not listed but don't need to be since `/pr` is explicitly user-invoked).

---

## Decisions

- **Insertion point**: New step labeled "STEP 1b" (not STEP 2) to preserve the existing step numbering for the well-established CI steps (7 through 11). This minimizes confusion and avoids renumbering.
- **URL-parsing reuse**: The STEP 0.1 URL parser (lines 88–103) should be extracted as an inline code block in STEP 1 and reused verbatim for workflow PR refs. No refactoring to a shared function is needed since the command is prose-driven.
- **No auto-proceed for default case**: When no flag is given, default `workflow="new"` without probing open PRs. Probing adds latency and noise in the most common case (submitting a new PR).
- **`gh pr checkout` over manual fetch**: For update/amend, `gh pr checkout <N> --repo leanprover/cslib` is preferred over manual `git fetch + git checkout` because it handles fork remotes correctly and is self-documenting.
- **Amend scope**: Only `git commit --amend` is documented. Interactive squash (`git rebase -i`) is excluded from scope as it requires interactive input not supported in the agent environment.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `gh pr checkout` changes active branch before CI | Acceptable — CI runs on the checked-out branch for update/amend |
| Force-push on amend breaks CI artifacts | Already non-blocking — CI re-runs on GitHub Actions after push |
| Auto-detect returns 30+ PRs (gh default limit) | Add `--limit 10` to auto-detect query to keep list manageable |
| `workflow_pr_number` is from a different repo | Validation: check `headRepositoryOwner.login == "benbrastmckie"` after `gh pr view` |
| Stacked on a closed/merged PR | `gh pr view` returns `state: "closed"` — detect and warn before proceeding |
| No PR ref for stacked/update/amend and no open PRs found | Offer "Supply manually" or "Switch to NEW" options — never silent fallback |

---

## Appendix

### Search Queries Used
- Read: `.claude/extensions/cslib/commands/pr.md` (1806 lines, full read)
- Read: `.claude/scripts/install-extension.sh` (298 lines)
- Read: `.claude/rules/pr-prohibition.md` (via system-reminder)
- Bash: `ls -la .claude/commands/pr.md` (confirmed symlink)
- Bash: `cat .claude/extensions/cslib/manifest.json` (manifest structure)
- Bash: `gh pr list --repo leanprover/cslib --author benbrastmckie --state open --json ...` (live query)
- Bash: `gh pr view 662 --repo leanprover/cslib --json headRefName,headRepositoryOwner,...` (live query)
- Bash: `git ls-remote upstream 'refs/pull/662/head'` (confirmed PR head fetch)
- Bash: `gh --version`, `gh pr list --help`, `gh pr view --help`, `gh pr checkout --help`, `gh pr create --help`, `gh search prs --help`

### References
- Source file: `/home/benjamin/.config/nvim/.claude/extensions/cslib/commands/pr.md`
- Deployed symlink: `/home/benjamin/.config/nvim/.claude/commands/pr.md -> ../extensions/cslib/commands/pr.md`
- pr-prohibition rule: `/home/benjamin/.config/nvim/.claude/rules/pr-prohibition.md`
- Install script: `/home/benjamin/.config/nvim/.claude/scripts/install-extension.sh`
- CSLib manifest: `/home/benjamin/.config/nvim/.claude/extensions/cslib/manifest.json`
- gh CLI version 2.93.0, git version 2.54.0
