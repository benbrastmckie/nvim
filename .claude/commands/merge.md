---
description: Create a pull/merge request for the current branch (GitHub PR or GitLab MR)
allowed-tools: Bash(git:*), Bash(gh:*), Bash(glab:*)
argument-hint: [--draft] [--assignee USER] [--label LABEL] [--reviewer USER]
---

# /merge Command

Create a pull request (GitHub) or merge request (GitLab) for the current branch. Automatically detects the platform from the git remote URL, validates that you are not on `main`, pushes the branch to origin with upstream tracking, and creates the PR/MR via the appropriate CLI.

## Syntax

```
/merge [options]
```

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--draft` | Create PR/MR as a draft | false |
| `--assignee USER` | Assign to a user by username | (none) |
| `--label LABEL` | Add a label | (none) |
| `--reviewer USER` | Request review from user | (none) |
| `--title TITLE` | Custom title (default: use --fill) | (none) |
| `--body BODY` | Custom description (default: use --fill) | (none) |
| `--target BRANCH` | Target branch (default: main) | main |

## Platform Flag Mapping

| Unified Flag | gh pr create | glab mr create |
|--------------|--------------|----------------|
| `--draft` | `--draft` | `--draft` |
| `--assignee USER` | `--assignee USER` | `--assignee USER` |
| `--label LABEL` | `--label LABEL` | `--label LABEL` |
| `--reviewer USER` | `--reviewer USER` | `--reviewer USER` |
| `--fill` | `--fill` | `--fill --yes` |
| `--target BRANCH` | `--base BRANCH` | `--target-branch BRANCH` |
| `--title TITLE` | `--title TITLE` | `--title TITLE` |
| `--body BODY` | `--body BODY` | `--description BODY` |

## Prerequisites

- Must be on a branch other than `main`/`master`
- Must have the appropriate CLI installed:
  - GitHub: `gh` CLI installed and authenticated (`gh auth status`)
  - GitLab: `glab` CLI installed and authenticated (`glab auth status`)
- Must have a remote configured as `origin`

## Execution

**EXECUTE NOW**: Follow these steps in sequence. Do not just describe what should happen - actually perform each step.

### STEP 1: Parse Arguments

**EXECUTE NOW**: Parse the command arguments to extract flags.

```
# Default values
draft=false
assignee=""
label=""
reviewer=""
title=""
body=""
target="main"

# Parse flags from $ARGUMENTS
```

Track:
- `--draft` -> set draft=true
- `--assignee USER` -> set assignee=USER
- `--label LABEL` -> set label=LABEL
- `--reviewer USER` -> set reviewer=USER
- `--title TITLE` -> set title=TITLE
- `--body BODY` -> set body=BODY
- `--target BRANCH` -> set target=BRANCH

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Detect Platform

**EXECUTE NOW**: Detect whether this is a GitHub or GitLab repository.

```bash
origin_url=$(git remote get-url origin 2>/dev/null)
```

**Detection Logic**:

1. **URL Pattern Matching** (primary):
   - If URL contains `github.com` or matches `github:` -> platform=github
   - If URL contains `gitlab.com` or matches `gitlab:` -> platform=gitlab

2. **CLI Availability Fallback** (if URL ambiguous):
   - Check if `gh auth status` succeeds -> platform=github
   - Check if `glab auth status` succeeds -> platform=gitlab

**If platform cannot be determined**:
```
Error: Cannot determine platform (GitHub or GitLab)
=================================================

Origin URL: {origin_url}

Recovery:
- Ensure your remote URL contains github.com or gitlab.com
- Ensure gh or glab CLI is installed and authenticated:
  - GitHub: gh auth login
  - GitLab: glab auth login
```
**STOP** - cannot proceed without platform detection.

**If platform detected**: **IMMEDIATELY CONTINUE** to STEP 3.

---

### STEP 3: Validate Branch

**EXECUTE NOW**: Check that the current branch is not `main` or `master`.

```bash
current_branch=$(git branch --show-current)
```

**If branch is `main` or `master`**:
```
Error: Cannot create PR/MR from '{branch}' branch
=================================================

You are currently on the '{branch}' branch.
Pull/merge requests must be created from a feature branch.

Recovery:
1. Create a new branch: git checkout -b feature-branch
2. Make your changes and commit them
3. Run /merge again
```
**STOP** - execution cannot proceed from main/master branch.

**If branch is valid**: **IMMEDIATELY CONTINUE** to STEP 4.

---

### STEP 4: Push to Origin

**EXECUTE NOW**: Push the current branch to origin with upstream tracking.

```bash
git push -u origin HEAD
```

Capture the output and exit code.

**If push fails**:
```
Error: Failed to push branch to origin
======================================

{git error output}

Recovery:
- Check your git remote configuration: git remote -v
- Ensure you have write access to the repository
- Resolve any conflicts or upstream issues
- Try pushing manually: git push -u origin HEAD
```
**STOP** - execution cannot proceed without successful push.

**If push succeeds**: **IMMEDIATELY CONTINUE** to STEP 5.

---

### STEP 5: Create PR/MR

**EXECUTE NOW**: Create the pull/merge request via the appropriate CLI.

#### For GitHub (platform=github):

Build the gh command:
```bash
gh_cmd="gh pr create --fill"

# Add target branch
gh_cmd="$gh_cmd --base $target"

# Add optional flags
if [ "$draft" = true ]; then
  gh_cmd="$gh_cmd --draft"
fi
if [ -n "$assignee" ]; then
  gh_cmd="$gh_cmd --assignee $assignee"
fi
if [ -n "$label" ]; then
  gh_cmd="$gh_cmd --label $label"
fi
if [ -n "$reviewer" ]; then
  gh_cmd="$gh_cmd --reviewer $reviewer"
fi
if [ -n "$title" ]; then
  gh_cmd="$gh_cmd --title \"$title\""
fi
if [ -n "$body" ]; then
  gh_cmd="$gh_cmd --body \"$body\""
fi

# Execute
$gh_cmd
```

#### For GitLab (platform=gitlab):

Build the glab command:
```bash
glab_cmd="glab mr create --fill --yes"

# Add target branch
glab_cmd="$glab_cmd --target-branch $target"

# Add optional flags
if [ "$draft" = true ]; then
  glab_cmd="$glab_cmd --draft"
fi
if [ -n "$assignee" ]; then
  glab_cmd="$glab_cmd --assignee $assignee"
fi
if [ -n "$label" ]; then
  glab_cmd="$glab_cmd --label $label"
fi
if [ -n "$reviewer" ]; then
  glab_cmd="$glab_cmd --reviewer $reviewer"
fi
if [ -n "$title" ]; then
  glab_cmd="$glab_cmd --title \"$title\""
fi
if [ -n "$body" ]; then
  glab_cmd="$glab_cmd --description \"$body\""
fi

# Execute
$glab_cmd
```

Capture the output to extract the PR/MR URL.

**If PR/MR creation fails**:
```
Error: Failed to create {PR_type}
=================================

{cli error output}

Recovery:
- Check authentication: {cli} auth status
- Check repository access: {cli} repo view
- If PR/MR already exists, the CLI will show the existing URL
- Try creating manually: {cli} {command} create --fill
```
**STOP** - PR/MR creation failed.

**If PR/MR creation succeeds**: Extract the URL from the output and **IMMEDIATELY CONTINUE** to STEP 6.

---

### STEP 6: Report Results

**EXECUTE NOW**: Display the pull/merge request information.

```
{PR_type} Created
=================

Platform: {GitHub|GitLab}
Branch: {current_branch}
Target: {target}

URL: {pr_mr_url}
```

**STOP** - execution complete.

---

## Examples

### Basic PR/MR

```bash
# Create PR/MR from current branch (auto-detect platform)
/merge
```

### Draft PR/MR

```bash
# Create as draft (work in progress)
/merge --draft
```

### Assigned with Reviewer

```bash
# Create and assign, request review
/merge --assignee johndoe --reviewer janesmith
```

### Custom Target Branch

```bash
# Create PR/MR targeting develop branch
/merge --target develop
```

### Combined Options

```bash
# Create draft PR/MR with assignee and label
/merge --draft --assignee johndoe --label "wip"
```

## Output

### Success (GitHub)

```
Pull Request Created
===================

Platform: GitHub
Branch: feature/add-new-modal
Target: main

URL: https://github.com/user/project/pull/42
```

### Success (GitLab)

```
Merge Request Created
====================

Platform: GitLab
Branch: feature/add-new-modal
Target: main

URL: https://gitlab.com/user/project/-/merge_requests/42
```

### Error: On Main Branch

```
Error: Cannot create PR/MR from 'main' branch
=============================================

You are currently on the 'main' branch.
Pull/merge requests must be created from a feature branch.

Recovery:
1. Create a new branch: git checkout -b feature-branch
2. Make your changes and commit them
3. Run /merge again
```

### Error: Platform Detection Failed

```
Error: Cannot determine platform (GitHub or GitLab)
=================================================

Origin URL: git@custom-server.com:user/project.git

Recovery:
- Ensure your remote URL contains github.com or gitlab.com
- Ensure gh or glab CLI is installed and authenticated:
  - GitHub: gh auth login
  - GitLab: glab auth login
```

## Troubleshooting

### CLI Not Installed

Install the appropriate CLI:
- GitHub: `brew install gh` or see https://cli.github.com/
- GitLab: `brew install glab` or see https://gitlab.com/gitlab-org/cli

### Not Authenticated

Run the authentication command:
- GitHub: `gh auth login`
- GitLab: `glab auth login`

### Remote 'origin' Not Found

Configure the remote:
```bash
# GitHub
git remote add origin git@github.com:user/project.git

# GitLab
git remote add origin git@gitlab.com:user/project.git
```

### PR/MR Already Exists

If a PR/MR already exists for the current branch, the CLI will display the existing URL. This is not an error.

### Push Rejected Due to Conflicts

Resolve conflicts locally first:
```bash
git fetch origin main
git rebase origin/main
# or
git merge origin/main
```
Then run `/merge` again.

### Enterprise GitHub/GitLab

For self-hosted instances, ensure:
1. The CLI is configured with your instance URL
2. Your remote URL uses the instance domain
3. Authentication is configured for the instance

## Related Commands

- `/task` - Create a task for the work
- `/implement` - Implement the task
- `/review` - Review code before merging
