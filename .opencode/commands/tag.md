# /tag Command

Create and push semantic version tags for CI/CD deployment. This command is **user-only** - agents cannot invoke it.

**CRITICAL**: Deployment timing is user-controlled. This command creates and pushes git tags which immediately trigger CI/CD deployment to production.

## Syntax

```
/tag [--patch|--minor|--major] [--force] [--dry-run]
```

## Options

| Flag | Description |
|------|-------------|
| `--patch` | Increment patch version (default): `v0.2.3` -> `v0.2.4` |
| `--minor` | Increment minor version, reset patch: `v0.2.3` -> `v0.3.0` |
| `--major` | Increment major version, reset minor and patch: `v0.2.3` -> `v1.0.0` |
| `--force` | Skip confirmation prompt |
| `--dry-run` | Show what would be done without executing |

## What It Does

1. **Validates git state** - Ensures clean working tree, up-to-date with remote
2. **Computes new version** - Based on increment type and latest tag
3. **Shows summary** - Displays commits since last tag, version change
4. **Confirms deployment** - Interactive prompt (unless `--force`)
5. **Creates tag** - Creates git tag locally
6. **Pushes tag** - Pushes to origin (triggers CI/CD)
7. **Updates state** - Records deployment in `specs/state.json`

## Default Increment

If no increment flag is provided, `--patch` is used by default.

## Execution

Invoke skill-tag with the provided arguments:

```
skill: skill-tag
args: {flags from command}
```

The skill performs all validation, version computation, confirmation, and git operations.

## Examples

### Interactive Deployment (Recommended)

```bash
# Patch release (default) with confirmation
/tag

# Minor release with confirmation
/tag --minor

# Major release with confirmation
/tag --major
```

### Preview Mode

```bash
# Show what would be deployed without executing
/tag --dry-run

# Preview minor release
/tag --minor --dry-run
```

### Force Mode

```bash
# Skip confirmation, immediate deployment
/tag --force

# Force minor release
/tag --minor --force
```

## Output

### Interactive Flow

```
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

[Confirmation prompt appears]

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

Verify deployment:
  - CI/CD pipeline: Check pipeline status in your CI provider
  - Hosting platform: Check deployment status (e.g., Cloudflare, Vercel, Netlify)
  - Live site: Verify changes are live
```

### Dry Run Output

```
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

## Error Handling

### Dirty Working Tree

```
Error: Working tree has uncommitted changes.

Uncommitted files:
 M src/pages/index.astro
?? src/components/New.astro

Resolution: Commit or stash changes before tagging.
```

### Behind Remote

```
Error: Local branch is 3 commit(s) behind remote.

Resolution: Pull latest changes with 'git pull' before tagging.
```

### Tag Already Exists

```
Error: Tag v0.2.4 already exists.

Existing tags:
v0.2.4
v0.2.3
v0.2.2

Resolution: Use a different increment type or check tag history.
```

### Push Failed

```
Error: Failed to push tag to remote.

The tag was created locally but not pushed.
To recover:
  1. Fix network/auth issues
  2. Run: git push origin v0.2.4

Or to undo the local tag:
  git tag -d v0.2.4
```

## Version Tracking

The `/tag` command updates the `deployment_versions` section in `specs/state.json`:

```json
{
  "deployment_versions": {
    "last_deployed": "v0.2.4",
    "last_deployed_at": "2026-02-10T18:00:00Z",
    "deployment_history": [
      {
        "version": "v0.2.4",
        "deployed_at": "2026-02-10T18:00:00Z",
        "commit_sha": "abc1234def5678"
      }
    ]
  }
}
```

History is limited to the last 10 deployments.

## Semantic Versioning Guidelines

| Version Type | When to Use | Examples |
|--------------|-------------|----------|
| **Patch** | Bug fixes, config changes, minor content | Typo fixes, _redirects, metadata |
| **Minor** | New features, significant content | New pages, routes, features |
| **Major** | Breaking changes, redesigns | URL changes, major redesign |

## Safety

- **User-only command**: Agents cannot invoke `/tag` (enforced via `user-only: true`)
- **Git validation**: Blocks deployment if working tree is dirty or behind remote
- **Confirmation required**: Interactive prompt unless `--force` is used
- **Dry-run available**: Preview deployment with `--dry-run`
- **Recovery instructions**: Clear guidance if push fails

## Related Documentation

- `.claude/rules/git-workflow.md` - Git conventions and agent restrictions
- `.claude/extensions/web/context/project/web/tools/` - CI/CD and deployment guides (project-specific)
