---
description: Create and push semantic version tags for CI/CD deployment (user-only)
argument-hint: [--patch|--minor|--major] [--force] [--dry-run]
model: opus
---

# Command: /tag

**Purpose**: Creates and pushes semantic version tags to trigger CI/CD deployment to production.  
**User Only**: YES - Agents MUST NOT invoke this command  
**Layer**: 1 (Direct execution)  
**Delegates To**: skill-tag (Direct execution skill)

---

## Warning

**CRITICAL**: This command immediately triggers CI/CD deployment to production. Deployment timing is a user-controlled business decision. Agents are prohibited from invoking this command.

---

## Usage

```bash
/tag [--patch|--minor|--major] [--force] [--dry-run]
```

| Flag | Description |
|------|-------------|
| `--patch` | Increment patch version (default): `v0.2.3` -> `v0.2.4` |
| `--minor` | Increment minor version, reset patch: `v0.2.3` -> `v0.3.0` |
| `--major` | Increment major version, reset minor and patch: `v0.2.3` -> `v1.0.0` |
| `--force` | Skip confirmation prompt |
| `--dry-run` | Show what would be done without executing |

---

## Examples

```bash
/tag                    # Interactive patch release
/tag --minor            # Interactive minor release
/tag --major --force    # Force major release (no prompt)
/tag --dry-run          # Preview what would happen
```

---

## Workflow

1. **Validate Git State**: Check for clean working tree and up-to-date branch
2. **Compute Version**: Calculate new version based on increment type
3. **Display Summary**: Show commits since last tag
4. **Confirm**: Interactive confirmation (unless --force)
5. **Create Tag**: `git tag vX.Y.Z`
6. **Push Tag**: `git push origin vX.Y.Z`
7. **Update State**: Record deployment in state.json

---

## Requirements

- Clean working tree (no uncommitted changes)
- On a branch (not detached HEAD)
- Up-to-date with remote
- No existing tag with computed version

---

## Agent Restrictions

**Agents MUST NOT invoke /tag**. This is enforced by:
- `user-only: true` in skill frontmatter
- Explicit prohibition in agent rules
- No agent mapping in CLAUDE.md
