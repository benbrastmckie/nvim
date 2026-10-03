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
/tag [--patch|--minor|--major] [--force] [--dry-run] [--skip-version-check] [--skip-changelog-check]
```

| Flag | Description |
|------|-------------|
| `--patch` | Increment patch version (default): `v0.2.3` -> `v0.2.4` |
| `--minor` | Increment minor version, reset patch: `v0.2.3` -> `v0.3.0` |
| `--major` | Increment major version, reset minor and patch: `v0.2.3` -> `v1.0.0` |
| `--force` | Skip confirmation prompt |
| `--dry-run` | Show what would be done without executing |
| `--skip-version-check` | Bypass a declared-version mismatch (still prints a loud warning naming both versions) |
| `--skip-changelog-check` | Bypass a missing or empty CHANGELOG entry (still prints the full failure detail first) |

## Execution

### Step 1: Parse Arguments

Extract flags from command input:

```bash
# Parse from command input
increment="patch"  # default
force=false
dry_run=false
skip_version_check=false
skip_changelog_check=false

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
if [[ "$*" == *"--skip-version-check"* ]]; then
  skip_version_check=true
fi
if [[ "$*" == *"--skip-changelog-check"* ]]; then
  skip_changelog_check=true
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

  # Check if we're ahead (not fully pushed). ahead == 0 here is mathematically identical to
  # `git merge-base --is-ancestor HEAD origin/$current_branch` -- not a proxy for it -- because
  # Step 6 always tags HEAD with no commit-ish argument. If /tag ever gains non-HEAD tagging,
  # this equivalence must be re-derived.
  ahead=$(git rev-list --count "origin/$current_branch..HEAD" 2>/dev/null || echo "0")
  if [ "$ahead" -gt 0 ]; then
    echo "Error: Local branch is $ahead commit(s) ahead of remote (not fully pushed)."
    echo ""
    echo "A tag created now would point at a commit absent from origin/$current_branch. A"
    echo "consuming repo's release preflight (git merge-base --is-ancestor) rejects such a tag"
    echo "*after* it has already been pushed, requiring a delete-and-re-push to recover."
    echo ""
    echo "Resolution: Push the branch with 'git push origin $current_branch' before tagging."
    exit 1
  fi
fi

echo "Git state: OK (clean working tree, fully pushed, up-to-date with remote)"
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

### Step 3.5: Validate Version Consistency

Ensure any declared package version agrees with the computed tag before proceeding. This step
runs for every invocation path — default, `--force`, and `--dry-run` alike — because it sits
strictly before Step 5's `--dry-run` `exit 0`:

```bash
echo ""
echo "=== Validating Version Consistency ==="
echo ""

new_version_bare="${new_version#v}"
repo_root=$(git rev-parse --show-toplevel)

# Bounded-depth discovery, excluding vendor/build directories (node_modules above all --
# unbounded recursion in a Node repo finds thousands of package.json files).
manifest_files=$(find "$repo_root" -maxdepth 3 \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/venv/*' \
  \( -name pyproject.toml -o -name setup.cfg -o -name setup.py -o -name package.json -o -name Cargo.toml \) \
  2>/dev/null | sort)

extract_declared_version() {
  local file="$1"
  local base
  base=$(basename "$file")
  case "$base" in
    pyproject.toml)
      # [project]-scoped so a later [tool.poetry] table never false-matches.
      sed -n '/^\[project\]/,/^\[/p' "$file" \
        | grep -m1 '^version[[:space:]]*=' \
        | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/'
      ;;
    setup.cfg)
      sed -n '/^\[metadata\]/,/^\[/p' "$file" \
        | grep -m1 '^version[[:space:]]*=' \
        | sed -E 's/^version[[:space:]]*=[[:space:]]*([^ ]*).*/\1/'
      ;;
    setup.py)
      # Best-effort literal-kwarg heuristic. A non-match falls through to "no version
      # declared", per DR-6 -- setup.py's version can be an arbitrary Python expression.
      grep -m1 -E "version[[:space:]]*=[[:space:]]*['\"]" "$file" \
        | sed -E "s/.*version[[:space:]]*=[[:space:]]*['\"]([^'\"]*)['\"].*/\1/"
      ;;
    package.json)
      jq -r '.version // empty' "$file"
      ;;
    Cargo.toml)
      sed -n '/^\[package\]/,/^\[/p' "$file" \
        | grep -m1 '^version[[:space:]]*=' \
        | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]*)".*/\1/'
      ;;
  esac
}

# Collect path:version pairs for every manifest yielding a non-empty declared version.
# PEP 621 `dynamic = ["version"]` and Cargo `version.workspace = true` correctly yield
# empty here -- honest "not declared here" answers, not bugs.
declared_pairs=""
while IFS= read -r manifest; do
  [ -z "$manifest" ] && continue
  declared_version=$(extract_declared_version "$manifest")
  if [ -n "$declared_version" ]; then
    declared_pairs="${declared_pairs}${manifest}:${declared_version}"$'\n'
  fi
done <<< "$manifest_files"
declared_pairs="${declared_pairs%$'\n'}"

if [ -z "$declared_pairs" ]; then
  echo "No declared package version found (checked pyproject.toml, setup.cfg, setup.py,"
  echo "package.json, Cargo.toml near repo root). Skipping version-consistency check."
else
  # DR-3: check every discovered manifest; any single mismatch fails the gate.
  mismatch_found=false
  while IFS=: read -r manifest declared_version; do
    [ -z "$manifest" ] && continue
    declared_bare="${declared_version#v}"
    if [ "$declared_bare" != "$new_version_bare" ]; then
      mismatch_found=true
    fi
  done <<< "$declared_pairs"

  if [ "$mismatch_found" = true ]; then
    echo "Error: Declared package version does not match computed tag ($new_version)."
    echo ""
    echo "Declared in:"
    while IFS=: read -r manifest declared_version; do
      [ -z "$manifest" ] && continue
      echo "  $manifest (version = \"$declared_version\")"
    done <<< "$declared_pairs"
    echo ""
    if [ "$skip_version_check" = true ]; then
      echo "WARNING: --skip-version-check is set. Proceeding despite the mismatch above."
      echo "Computed tag: $new_version. The declared version(s) listed above diverge from it."
    else
      echo "Resolution: Update the mismatched manifest(s) to $new_version_bare, commit, then re-run /tag."
      echo "Or pass --skip-version-check to proceed anyway (not recommended)."
      exit 1
    fi
  else
    echo "Version consistency: OK -- declared version(s) match computed tag ($new_version)."
    while IFS=: read -r manifest declared_version; do
      [ -z "$manifest" ] && continue
      echo "  $manifest (version = \"$declared_version\")"
    done <<< "$declared_pairs"
  fi
fi
```

### Step 3.6: Validate Changelog Entry

Ensure a discovered CHANGELOG declares a non-empty entry for the computed version before
proceeding. This step runs for every invocation path — default, `--force`, and `--dry-run`
alike — because it sits strictly before Step 5's `--dry-run` `exit 0`:

```bash
echo ""
echo "=== Validating Changelog Entry ==="
echo ""

# Bounded-depth discovery, excluding the same vendor/build directories Step 3.5 excludes.
# $repo_root and $new_version_bare are already in scope from Step 3.5.
changelog_candidates=$(find "$repo_root" -maxdepth 3 -type f \
  -not -path '*/node_modules/*' \
  -not -path '*/.git/*' \
  -not -path '*/dist/*' \
  -not -path '*/build/*' \
  -not -path '*/target/*' \
  -not -path '*/__pycache__/*' \
  -not -path '*/.venv/*' \
  -not -path '*/venv/*' \
  -iname 'CHANGELOG.md' \
  2>/dev/null | sort)
changelog_file=$(printf '%s\n' "$changelog_candidates" | head -1)

# A repo has at most one canonical changelog by convention; disclose any additional
# candidates as explicitly ignored rather than silently picking the sorted-first match.
extra_candidates=$(printf '%s\n' "$changelog_candidates" | tail -n +2)
if [ -n "$extra_candidates" ]; then
  echo "Multiple CHANGELOG.md files found; using: $changelog_file"
  echo "Ignored additional candidates:"
  printf '%s\n' "$extra_candidates" | sed 's/^/  /'
fi

if [ -z "$changelog_file" ]; then
  echo "No CHANGELOG.md found near repo root (bounded-depth search, vendor/build dirs excluded)."
  echo "Skipping changelog check."
  tag_message="$new_version"
  tag_message_source="bare version string (no CHANGELOG found)"
else
  changelog_ok=true
  heading_found=false
  if grep -q "^## \[${new_version_bare}\]" "$changelog_file"; then
    heading_found=true
    changelog_section=$(awk -v ver="$new_version_bare" '
      $0 ~ "^## \\[" ver "\\]" { found=1; next }
      found && /^## / { exit }
      found { print }
    ' "$changelog_file")
    if [ -z "$(printf '%s' "$changelog_section" | tr -d '[:space:]')" ]; then
      changelog_ok=false
    fi
  else
    changelog_ok=false
  fi

  if [ "$changelog_ok" = false ]; then
    echo "Error: Changelog entry missing or empty for $new_version_bare."
    echo ""
    echo "Changelog file: $changelog_file"
    if [ "$heading_found" = true ]; then
      echo "The '## [$new_version_bare]' heading exists but its section is empty."
    else
      echo "No '## [$new_version_bare]' heading found."
    fi
    echo ""
    if [ "$skip_changelog_check" = true ]; then
      echo "WARNING: --skip-changelog-check is set. Proceeding despite the above."
      tag_message="$new_version"
      tag_message_source="bare version string (changelog check skipped)"
    else
      echo "Resolution: Add a non-empty '## [$new_version_bare]' section to $changelog_file, commit, then re-run /tag."
      echo "Or pass --skip-changelog-check to proceed anyway (not recommended)."
      exit 1
    fi
  else
    echo "Changelog entry: OK -- $changelog_file has a non-empty '## [$new_version_bare]' section."
    # Decision: the annotated tag's subject line is $new_version and its body is the extracted
    # CHANGELOG section, because that section is already validated non-empty by this step and is
    # the same content the release preflight reads. The bare $new_version message is a deliberate
    # fallback used only when no section is available (no changelog, or check skipped) -- not a
    # default reached by omission. -a (not -s) is used because signing requires a configured GPG
    # key that is not universal across consuming repos.
    tag_message=$(printf '%s\n\n%s\n' "$new_version" "$changelog_section")
    tag_message_source="CHANGELOG section for $new_version_bare ($changelog_file)"
  fi
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
  echo "  git tag -a $new_version -m <$tag_message_source>"
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
bash .claude/scripts/git-push-granted.sh --revoke 2>/dev/null || true
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

# Create annotated tag (not lightweight) -- required by the release preflight's
# `[ "$(git cat-file -t "$TAG")" = "tag" ]` assertion. -a rather than -s: signing requires a
# configured GPG key that is not universal across consuming repos.
if ! git tag -a "$new_version" -m "$tag_message"; then
  echo "Error: Failed to create tag $new_version"
  exit 1
fi

echo "Created annotated tag: $new_version"
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

### Ahead of Remote (Not Fully Pushed)

```
=== Validating Git State ===

Error: Local branch is 36 commit(s) ahead of remote (not fully pushed).

A tag created now would point at a commit absent from origin/main. A
consuming repo's release preflight (git merge-base --is-ancestor) rejects such a tag
*after* it has already been pushed, requiring a delete-and-re-push to recover.

Resolution: Push the branch with 'git push origin main' before tagging.
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

### Version Mismatch

```
=== Validating Version Consistency ===

Error: Declared package version does not match computed tag (v1.3.1).

Declared in:
  code/pyproject.toml (version = "1.3.0")

Resolution: Update the mismatched manifest(s) to 1.3.1, commit, then re-run /tag.
Or pass --skip-version-check to proceed anyway (not recommended).
```

### No Declared Version Found

This is an **informational** outcome, not a failure. `/tag` proceeds normally after printing it,
in every invocation mode including `--dry-run`:

```
=== Validating Version Consistency ===

No declared package version found (checked pyproject.toml, setup.cfg, setup.py,
package.json, Cargo.toml near repo root). Skipping version-consistency check.
```

### Version Check Skipped by Flag

`--skip-version-check` suppresses the *block*, not the *disclosure*: the mismatch is still
printed in full before the override warning, so the transcript records exactly what was
overridden.

```
=== Validating Version Consistency ===

Error: Declared package version does not match computed tag (v1.3.1).

Declared in:
  code/pyproject.toml (version = "1.3.0")

WARNING: --skip-version-check is set. Proceeding despite the mismatch above.
Computed tag: v1.3.1. The declared version(s) listed above diverge from it.
```

### Changelog Entry Missing or Empty

This is the fatal-by-default outcome. There are two variants: the version heading is absent from
the discovered CHANGELOG, or the heading is present but its section is empty.

Heading absent:

```
=== Validating Changelog Entry ===

Error: Changelog entry missing or empty for 1.3.1.

Changelog file: code/CHANGELOG.md
No '## [1.3.1]' heading found.

Resolution: Add a non-empty '## [1.3.1]' section to code/CHANGELOG.md, commit, then re-run /tag.
Or pass --skip-changelog-check to proceed anyway (not recommended).
```

Heading present, section empty:

```
=== Validating Changelog Entry ===

Error: Changelog entry missing or empty for 1.3.1.

Changelog file: code/CHANGELOG.md
The '## [1.3.1]' heading exists but its section is empty.

Resolution: Add a non-empty '## [1.3.1]' section to code/CHANGELOG.md, commit, then re-run /tag.
Or pass --skip-changelog-check to proceed anyway (not recommended).
```

### No Changelog Found

This is an **informational** outcome, not a failure. `/tag` proceeds normally after printing it,
in every invocation mode including `--dry-run`:

```
=== Validating Changelog Entry ===

No CHANGELOG.md found near repo root (bounded-depth search, vendor/build dirs excluded).
Skipping changelog check.
```

### Changelog Check Skipped by Flag

`--skip-changelog-check` suppresses the *block*, not the *disclosure*: the failure detail is
still printed in full before the override warning, so the transcript records exactly what was
overridden.

```
=== Validating Changelog Entry ===

Error: Changelog entry missing or empty for 1.3.1.

Changelog file: code/CHANGELOG.md
No '## [1.3.1]' heading found.

WARNING: --skip-changelog-check is set. Proceeding despite the above.
```

---

## Agent Restrictions

**CRITICAL**: This command is user-only. Agents MUST NOT invoke /tag.

**Enforcement layers**:

1. **Frontmatter flag**: `user-only: true` in skill YAML
2. **Documentation**: Clear CRITICAL warnings in this file
3. **No agent mapping**: Not listed in Skill-to-Agent Mapping table in CLAUDE.md

**Rationale**: Deployment timing is a business decision that requires human judgment. Agents prepare code changes but never control when those changes go to production.
