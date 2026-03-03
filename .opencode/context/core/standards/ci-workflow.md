# CI Workflow Standards

## Overview

CI is **skipped by default** on push events to reduce unnecessary builds. CI only runs when:
1. Manually triggered via `workflow_dispatch`
2. Pull request opened or updated
3. Commit message contains `[ci]` marker

This approach conserves CI resources while ensuring critical changes are validated.

## CI Trigger Markers

### Primary Marker

Add `[ci]` anywhere in the commit message to trigger CI:

```
task 423: complete implementation [ci]
```

### Marker Placement

The marker can appear anywhere in the commit message:
- End of first line (recommended): `fix: resolve bug [ci]`
- Separate line in body: `...\n\n[ci]`
- With description: `[ci] Run full build`

## Decision Criteria

### Trigger CI When

| Change Type | Trigger CI | Reason |
|-------------|------------|--------|
| Lean files (.lean) | Yes | Ensure code compiles and passes lint |
| Mathlib deps (lakefile.lean, lake-manifest.json) | Yes | Verify compatibility |
| CI configuration (.github/workflows/) | Yes | Validate workflow changes |
| Implementation completion | Yes | Final verification |
| Critical bug fixes | Yes | Confirm fix works |

### Skip CI When

| Change Type | Trigger CI | Reason |
|-------------|------------|--------|
| Research reports (.md) | No | No build impact |
| Implementation plans (.md) | No | No build impact |
| specs/TODO.md / specs/state.json | No | Task management only |
| CLAUDE.md updates | No | Configuration only |
| Context files (.opencode/context/) | No | Documentation only |
| Skills/agents (.opencode/skills/, .opencode/agents/) | No | Orchestration only |

## Task Lifecycle CI Triggers

### By Operation

| Operation | Default CI | Override |
|-----------|-----------|----------|
| `/research` complete | Skip | Add `[ci]` if needed |
| `/plan` complete | Skip | Add `[ci]` if needed |
| `/implement` phase complete | Skip | Add `[ci]` for Lean phases |
| `/implement` task complete | Skip (unless Lean) | Add `[ci]` for final verification |
| `/task` create/archive | Skip | Rarely needed |

### Language-Based Defaults

| Task Language | Default on Completion |
|---------------|----------------------|
| `lean` | Trigger CI (modifies source) |
| `meta` | Skip (modifies orchestration) |
| `markdown` | Skip (documentation only) |
| `general` | Case-by-case |

## Examples

### Commit Without CI (Default)

```
task 423: complete research

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

CI result: Skipped on push

### Commit With CI

```
task 334: complete implementation [ci]

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

CI result: Runs build, test, and lint

### Pull Request

```
Any commit message (no marker needed)
```

CI result: Always runs on PRs

### Manual Trigger

Use GitHub Actions UI or `gh workflow run ci.yml` to trigger manually.

## Implementation Details

### GitHub Actions Configuration

The CI workflow uses job-level `if` conditional:

```yaml
jobs:
  build:
    if: |
      github.event_name == 'workflow_dispatch' ||
      github.event_name == 'pull_request' ||
      contains(github.event.head_commit.message, '[ci]')
```

### skill-git-workflow Integration

The `trigger_ci` parameter controls marker addition:

```json
{
  "trigger_ci": true  // Appends [ci] to commit message
}
```

## Rollback

To restore default CI behavior (run on every push):
1. Remove the `if` conditional from `.github/workflows/ci.yml`
2. Remove `trigger_ci` documentation from skill-git-workflow

## References

- `.github/workflows/ci.yml` - CI workflow configuration
- `.opencode/skills/skill-git-workflow/SKILL.md` - Git commit skill with trigger_ci
- `.opencode/context/core/standards/git-integration.md` - Git integration patterns
