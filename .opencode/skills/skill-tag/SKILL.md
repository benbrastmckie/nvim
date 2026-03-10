---
name: skill-tag
description: Create and push semantic version tags for CI/CD deployment. User-only command - agents cannot invoke.
allowed-tools: Bash, AskUserQuestion, Read
user-only: true
---

# Tag Skill (Direct Execution)

Direct execution skill for creating and pushing semantic version tags to trigger CI/CD deployment. This command is **user-only** - agents MUST NOT invoke it.

**CRITICAL**: Deployment timing is user-controlled. This command creates and pushes git tags which immediately trigger CI/CD deployment to production.

## Command Syntax

```
/tag [--patch|--minor|--major] [--force] [--dry-run]
```

| Flag | Description |
|------|-------------|
| `--patch` | Increment patch version (default): `v0.2.3` -> `v0.2.4` |
| `--minor` | Increment minor version, reset patch: `v0.2.3` -> `v0.3.0` |
| `--major` | Increment major version, reset minor and patch: `v0.2.3` -> `v1.0.0` |
| `--force` | Skip confirmation prompt |
| `--dry-run` | Show what would be done without executing |

## Execution

### Step 1: Parse Arguments

Extract flags from command input:

```bash
# Parse from command input
increment="patch"  # default
force=false
dry_run=false

if [[ "$*" == *"--minor"* ]]; then
  increment="minor"
fi
if [[ "$*" == *"--major"* ]]; then
  increment="major"
fi
if [[ "$*" == *"--force"* ]]; then
  force=true
fi
if [[ "$*" == *"--dry-run"* ]]; then
  dry_run=true
fi
```

### Step 2: Validate Git State

Check that the repository is in a valid state for tagging:

```bash
echo "=== Validating Git State ==="
echo ""

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
  echo "Error: Working tree has uncommitted changes."
  echo ""
  echo "Uncommitted files:"
  git status --short
  echo ""
  echo "Resolution: Commit or stash changes before tagging."
  exit 1
fi

# Check if we're on a branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" = "HEAD" ]; then
  echo "Error: Detached HEAD state. Checkout a branch before tagging."
  exit 1
fi

# Check if local is behind remote
git fetch origin "$current_branch" --quiet 2>/dev/null || true
local_sha=$(git rev-parse HEAD)
remote_sha=$(git rev-parse "origin/$current_branch" 2>/dev/null || echo "")

if [ -n "$remote_sha" ] && [ "$local_sha" != "$remote_sha" ]; then
  # Check if we're behind
  behind=$(git rev-list --count "HEAD..origin/$current_branch" 2>/dev/null || echo "0")
  if [ "$behind" -gt 0 ]; then
    echo "Error: Local branch is $behind commit(s) behind remote."
    echo ""
    echo "Resolution: Pull latest changes with 'git pull' before tagging."
    exit 1
  fi
fi

echo "Git state: OK (clean working tree, up-to-date with remote)"
```

### Step 3: Compute New Version

Get current version and compute new version based on increment type:

```bash
echo ""
echo "=== Computing Version ==="
echo ""

# Get current version (latest tag)
current_version=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Current version: $current_version"

# Parse version components
major=$(echo "$current_version" | sed 's/v\([0-9]*\).*/\1/')
minor=$(echo "$current_version" | sed 's/v[0-9]*\.\([0-9]*\).*/\1/')
patch=$(echo "$current_version" | sed 's/v[0-9]*\.[0-9]*\.\([0-9]*\)/\1/')

# Increment based on type
case "$increment" in
  patch)
    patch=$((patch + 1))
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
esac

new_version="v${major}.${minor}.${patch}"
echo "New version: $new_version ($increment release)"

# Check if tag already exists
if git rev-parse "$new_version" >/dev/null 2>&1; then
  echo ""
  echo "Error: Tag $new_version already exists."
  echo ""
  echo "Existing tags:"
  git tag -l 'v*' --sort=-v:refname | head -5
  echo ""
  echo "Resolution: Use a different increment type or check tag history."
  exit 1
fi
```

### Step 4: Display Summary

Show what will be deployed:

```bash
echo ""
echo "=== Deployment Summary ==="
echo ""
echo "Version:  $current_version -> $new_version"
echo "Branch:   $current_branch"
echo "Commit:   $(git rev-parse --short HEAD)"
echo ""

# Show commits since last tag
commits_since=$(git log "$current_version"..HEAD --oneline 2>/dev/null | wc -l)
if [ "$commits_since" -gt 0 ]; then
  echo "Commits since $current_version ($commits_since total):"
  git log "$current_version"..HEAD --oneline | head -10
  if [ "$commits_since" -gt 10 ]; then
    echo "  ... and $((commits_since - 10)) more"
  fi
else
  echo "No commits since $current_version"
fi

echo ""
echo "This will trigger CI/CD deployment to production."
```

### Step 5: Execute Based on Mode

#### Dry-Run Mode

If `--dry-run` is set:

```bash
if [ "$dry_run" = true ]; then
  echo ""
  echo "=== DRY RUN MODE ==="
  echo ""
  echo "Would execute:"
  echo "  git tag $new_version"
  echo "  git push origin $new_version"
  echo ""
  echo "No changes made."
  exit 0
fi
```

#### Force Mode

If `--force` is set, skip confirmation and proceed to Step 6.

#### Interactive Mode (Default)

If neither flag is set, prompt for confirmation using AskUserQuestion:

```json
{
  "question": "Create and push version tag?",
  "header": "Version Tag Confirmation",
  "multiSelect": false,
  "options": [
    {
      "label": "Yes, create and push {new_version}",
      "description": "Triggers CI/CD deployment to production"
    },
    {
      "label": "No, cancel",
      "description": "Do not create tag"
    }
  ]
}
```

If user selects "No, cancel":
```bash
echo ""
echo "Tag creation cancelled."
exit 0
```

### Step 6: Create and Push Tag

Create the tag locally:

```bash
echo ""
echo "=== Creating Tag ==="
echo ""

# Create tag
if ! git tag "$new_version"; then
  echo "Error: Failed to create tag $new_version"
  exit 1
fi

echo "Created tag: $new_version"
```

Push the tag to remote:

```bash
echo ""
echo "=== Pushing Tag ==="
echo ""

# Push tag to origin
if ! git push origin "$new_version"; then
  echo ""
  echo "Error: Failed to push tag to remote."
  echo ""
  echo "The tag was created locally but not pushed."
  echo "To recover:"
  echo "  1. Fix network/auth issues"
  echo "  2. Run: git push origin $new_version"
  echo ""
  echo "Or to undo the local tag:"
  echo "  git tag -d $new_version"
  exit 1
fi

echo "Pushed tag: $new_version to origin"
```

### Step 7: Update state.json

Update the deployment_versions section in state.json:

```bash
echo ""
echo "=== Updating State ==="
echo ""

state_file="specs/state.json"
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
commit_sha=$(git rev-parse HEAD)

# Check if deployment_versions section exists
if jq -e '.deployment_versions' "$state_file" >/dev/null 2>&1; then
  # Update existing section
  jq --arg version "$new_version" \
     --arg timestamp "$timestamp" \
     --arg sha "$commit_sha" \
     '.deployment_versions.last_deployed = $version |
      .deployment_versions.last_deployed_at = $timestamp |
      .deployment_versions.deployment_history = ([{
        "version": $version,
        "deployed_at": $timestamp,
        "commit_sha": $sha
      }] + .deployment_versions.deployment_history[0:9])' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
else
  # Create new section
  jq --arg version "$new_version" \
     --arg timestamp "$timestamp" \
     --arg sha "$commit_sha" \
     '.deployment_versions = {
        "last_deployed": $version,
        "last_deployed_at": $timestamp,
        "deployment_history": [{
          "version": $version,
          "deployed_at": $timestamp,
          "commit_sha": $sha
        }]
      }' \
     "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
fi

echo "Updated state.json with deployment version $new_version"
```

### Step 8: Display Success

Show completion message with next steps:

```bash
echo ""
echo "========================================"
echo "  Tag Created and Pushed Successfully"
echo "========================================"
echo ""
echo "Version:    $new_version"
echo "Commit:     $(git rev-parse --short HEAD)"
echo "Pushed to:  origin"
echo ""
echo "CI/CD deployment has been triggered."
echo ""
echo "Verify deployment:"
echo "  - CI/CD pipeline: Check pipeline status in your CI provider"
echo "  - Hosting platform: Check deployment status"
echo "  - Live site: Verify changes are live"
echo ""
```

---

## Example Execution Flows

### Interactive Flow (Default)

```bash
# User runs: /tag

=== Validating Git State ===

Git state: OK (clean working tree, up-to-date with remote)

=== Computing Version ===

Current version: v0.2.3
New version: v0.2.4 (patch release)

=== Deployment Summary ===

Version:  v0.2.3 -> v0.2.4
Branch:   main
Commit:   abc1234

Commits since v0.2.3 (5 total):
abc1234 task 44: complete implementation
def5678 task 43: complete research
...

This will trigger CI/CD deployment to production.

# Prompt appears:
[Version Tag Confirmation]
Create and push version tag?
  1. Yes, create and push v0.2.4 - Triggers CI/CD deployment to production
  2. No, cancel - Do not create tag

# User selects option 1

=== Creating Tag ===

Created tag: v0.2.4

=== Pushing Tag ===

Pushed tag: v0.2.4 to origin

=== Updating State ===

Updated state.json with deployment version v0.2.4

========================================
  Tag Created and Pushed Successfully
========================================

Version:    v0.2.4
Commit:     abc1234
Pushed to:  origin

CI/CD deployment has been triggered.
```

### Dry-Run Flow

```bash
# User runs: /tag --minor --dry-run

=== Validating Git State ===

Git state: OK (clean working tree, up-to-date with remote)

=== Computing Version ===

Current version: v0.2.3
New version: v0.3.0 (minor release)

=== Deployment Summary ===

Version:  v0.2.3 -> v0.3.0
Branch:   main
Commit:   abc1234

Commits since v0.2.3 (5 total):
...

This will trigger CI/CD deployment to production.

=== DRY RUN MODE ===

Would execute:
  git tag v0.3.0
  git push origin v0.3.0

No changes made.
```

### Force Flow

```bash
# User runs: /tag --force

# Skips confirmation, proceeds directly:

=== Validating Git State ===

Git state: OK (clean working tree, up-to-date with remote)

=== Computing Version ===

Current version: v0.2.3
New version: v0.2.4 (patch release)

=== Deployment Summary ===
...

=== Creating Tag ===

Created tag: v0.2.4

=== Pushing Tag ===

Pushed tag: v0.2.4 to origin

=== Updating State ===

Updated state.json with deployment version v0.2.4

========================================
  Tag Created and Pushed Successfully
========================================
...
```

---

## Error Handling

### Dirty Working Tree

```
=== Validating Git State ===

Error: Working tree has uncommitted changes.

Uncommitted files:
 M src/pages/index.astro
?? src/components/New.astro

Resolution: Commit or stash changes before tagging.
```

### Behind Remote

```
=== Validating Git State ===

Error: Local branch is 3 commit(s) behind remote.

Resolution: Pull latest changes with 'git pull' before tagging.
```

### Tag Already Exists

```
=== Computing Version ===

Current version: v0.2.3
New version: v0.2.4 (patch release)

Error: Tag v0.2.4 already exists.

Existing tags:
v0.2.4
v0.2.3
v0.2.2
v0.2.1
v0.2.0

Resolution: Use a different increment type or check tag history.
```

### Push Failed

```
=== Pushing Tag ===

Error: Failed to push tag to remote.

The tag was created locally but not pushed.
To recover:
  1. Fix network/auth issues
  2. Run: git push origin v0.2.4

Or to undo the local tag:
  git tag -d v0.2.4
```

### Detached HEAD

```
=== Validating Git State ===

Error: Detached HEAD state. Checkout a branch before tagging.
```

---

## Agent Restrictions

**CRITICAL**: This command is user-only. Agents MUST NOT invoke /tag.

**Enforcement layers**:

1. **Frontmatter flag**: `user-only: true` in skill YAML
2. **Documentation**: Clear CRITICAL warnings in this file
3. **No agent mapping**: Not listed in Skill-to-Agent Mapping table in CLAUDE.md
4. **Git workflow rules**: Existing restrictions in git-workflow.md

**Rationale**: Deployment timing is a business decision that requires human judgment. Agents prepare code changes but never control when those changes go to production.

---

## Related Documentation

- `.opencode/rules/git-workflow.md` - Git conventions and agent restrictions
- `.opencode/context/project/web/tools/` - CI/CD and deployment guides (project-specific)
