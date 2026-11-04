# Permission Configuration Guide

**Version**: 1.0.0  
**Last Updated**: 2026-01-05  
**Audience**: OpenCode system maintainers and developers  

---

## Table of Contents

1. [Overview](#overview)
2. [MCP Server Registration and Permissions](#mcp-server-registration-and-permissions)
3. [Permission System Architecture](#permission-system-architecture)
4. [Permission Evaluation Order](#permission-evaluation-order)
5. [Glob Pattern Syntax](#glob-pattern-syntax)
6. [Examples by Agent Type](#examples-by-agent-type)
7. [Safety Boundaries](#safety-boundaries)
8. [Debugging Permission Denials](#debugging-permission-denials)
9. [Common Permission Patterns](#common-permission-patterns)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The OpenCode agent system uses a declarative permission model defined in agent frontmatter. Permissions control what files agents can read/write and what bash commands they can execute. This guide explains how to configure permissions safely while maintaining system security.

### Key Principles

1. **Default Deny**: Everything is denied unless explicitly allowed
2. **Deny Overrides Allow**: Deny rules take precedence over allow rules
3. **Git Safety**: Expanded permissions are safe when combined with git rollback
4. **Least Privilege**: Grant only permissions needed for agent function
5. **Dangerous Operations**: Always deny destructive operations

### Settings File Location: a Host-App Constraint

`.claude/settings.json` and `.claude/settings.local.json` (and their OpenCode equivalents under
`.opencode/`) hold permission grants/denies plus hooks and MCP *permission* grants -- never MCP
server registration; see the [MCP Server Registration and Permissions](#mcp-server-registration-and-permissions)
section below. Unlike the
extension selection manifest (`.claude-extensions.json` / `.opencode-extensions.json`, now at the
project root) or the runtime logs directory (`.agent-logs/`, also at the project root), these two
settings files **cannot** be relocated out of `base_dir`: Claude Code (and OpenCode) hardcode
`.claude/settings.json` / `.claude/settings.local.json` as the paths they read permissions and
hooks from -- there is no configuration point to redirect that read.

Because a full `rm -rf .claude/` wipe still destroys these two files, they are protected by a
different mechanism than a path move:

- **Install-once** (`loader.lua`'s `copy_category("root_files", ...)`, gated by
  `CATEGORY_DESCRIPTORS.root_files.install_once`): once a project has its own
  `settings.json`/`settings.local.json`, reloading or re-loading the providing extension never
  overwrites it. `manager.unload` also excludes these two files from removal
  (`loader_mod.INSTALL_ONCE_ROOT_FILES`), so an unload-then-load reload cycle does not clobber
  in-place edits either. See "Install-Once vs Always-Overwrite" in
  `../architecture/extension-system.md` for the full asymmetry across `loader.lua` and `sync.lua`.
- **Backup/restore** (`settings_backup.lua`, driven by `manager.wipe`): for a *full* wipe (where
  the files themselves are deleted, not just reloaded), install-once alone cannot help -- there is
  nothing left to preserve in place. `manager.wipe`'s sequence is `backup -> rm -rf base_dir ->
  manager.regenerate`, snapshotting to a project-root staging directory
  (`.claude-settings-backup/` / `.opencode-settings-backup/`, gitignored) before the wipe.
  `manager.regenerate` itself restores that snapshot as the merge base BEFORE its per-extension
  load loop runs (not after) -- restoring first means the loop's own settings-fragment merges land
  on top of the restored base and survive, rather than being clobbered by a later restore. Staging
  is cleared once the restore succeeds.

---

## MCP Server Registration and Permissions

MCP tool availability rests on two independent axes, and this guide -- the one an author reaches
for when writing a `permissions.allow` entry -- covers only the permission half. **Registration**
(which file makes a server exist and connect) and **permission** (which file grants its tools
without a prompt) never substitute for one another.

**Settings files grant; they never register.** An `mcpServers` key inside
`settings.json`/`settings.local.json` -- and therefore inside an extension's
`settings-fragment.json`, which merges into one of those two files -- has no effect. Claude Code
never reads those files for server definitions. Registration happens on exactly two surfaces:
user-scope `~/.claude.json` (written by a host-level/home-manager activation block or a
`core/scripts/` setup script such as `setup-lean-mcp.sh`) and project-scoped `.mcp.json` at the
project root (for extension-owned, repo-local servers).

**Scoping an `mcp__{server}__*` grant** follows the same domain boundary as any other permission,
with one governing rule on top: **grant permissions at the same scope where the server is
registered.** User-scope registration -> grant in `~/.claude/settings.json`; project-scope
registration -> grant in the owning extension's own `settings-fragment.json`
`permissions.allow`. Getting this backwards is the recurring failure mode: a project-scope grant
only helps projects where that specific extension is loaded, so every other project's calls fall
back to a prompt -- and DENY outright in a headless run. See the "Grant permissions at the same
scope where the server is registered" subsection in
[MCP Server Ownership](../../context/patterns/mcp-server-ownership.md) for the full treatment,
including the `lean-lsp`/`playwright` worked example pair.

**Prefer a wildcard over an enumeration** (`"mcp__{server}__*"` rather than one entry per tool
name). An enumeration silently under-grants as the server's tool surface grows -- a missed update
reintroduces prompting for the new tool with no error to signal the gap -- while a wildcard cannot
drift. **Carve-out**: when a server intentionally splits its tools into a safe/always-allow tier
and an unsafe/always-prompt tier, a wildcard cannot express that split and enumeration is
required -- see the "Carve-out: safe/unsafe tool splits require enumeration" subsection in
[MCP Server Ownership](../../context/patterns/mcp-server-ownership.md) for the worked example.

See [MCP Server Ownership](../../context/patterns/mcp-server-ownership.md) for the full
registration procedure, the evidence behind "settings files never register," the workspace-trust
caveat, the session-start snapshot trap, and the one remaining extension (`memory`) still
carrying a dead `mcpServers` block.

---

## Permission System Architecture

### Permission Types

Permissions are defined in agent frontmatter YAML:

```yaml
permissions:
  allow:
    - read: ["{glob_patterns}"]
    - write: ["{glob_patterns}"]
    - edit: ["{glob_patterns}"]
    - bash: ["{command_names}"]
  deny:
    - read: ["{glob_patterns}"]
    - write: ["{glob_patterns}"]
    - edit: ["{glob_patterns}"]
    - bash: ["{command_patterns}"]
```

### Permission Scopes

- **read**: Read file contents
- **write**: Create or overwrite files
- **edit**: Modify existing files (safer than write)
- **bash**: Execute bash commands

### Tools vs Permissions

Tools must be enabled AND permissions granted:

```yaml
tools:
  - read    # Enable read tool
  - write   # Enable write tool
  - bash    # Enable bash tool
  - git     # Enable git tool (for safety commits)

permissions:
  allow:
    - read: ["**/*.md"]   # Grant read permission for markdown files
    - bash: ["git"]       # Grant permission to execute git commands
```

---

## Permission Evaluation Order

Permissions are evaluated in this order:

1. **Check deny list**: If operation matches deny rule → DENY
2. **Check allow list**: If operation matches allow rule → ALLOW
3. **Default deny**: If no match → DENY

### Example

```yaml
permissions:
  allow:
    - write: ["**/*.md"]
  deny:
    - write: [".git/**/*"]
```

**Evaluation**:
- Write to `README.md` → Check deny (no match) → Check allow (match) → **ALLOW**
- Write to `.git/config` → Check deny (match) → **DENY** (deny overrides allow)
- Write to `script.sh` → Check deny (no match) → Check allow (no match) → **DENY** (default)

---

## Glob Pattern Syntax

### Basic Patterns

| Pattern | Matches | Example |
|---------|---------|---------|
| `*` | Any characters except `/` | `*.md` matches `README.md` |
| `**` | Any characters including `/` | `**/*.md` matches `docs/guide.md` |
| `?` | Single character | `file?.md` matches `file1.md` |
| `[abc]` | Character class | `file[123].md` matches `file1.md` |
| `{a,b}` | Alternatives | `*.{md,txt}` matches `file.md` or `file.txt` |

### Path Patterns

```yaml
# Specific file
- read: ["specs/TODO.md"]

# All files in directory (non-recursive)
- read: ["specs/*"]

# All files in directory tree (recursive)
- read: ["specs/**/*"]

# All markdown files anywhere
- read: ["**/*.md"]

# Multiple patterns
- read: ["**/*.md", "**/*.lua", ".claude/**/*"]
```

### Bash Command Patterns

```yaml
# Exact command name
- bash: ["git"]

# Command with arguments (matches prefix)
- bash: ["git commit"]

# Multiple commands
- bash: ["git", "grep", "find", "jq"]

# Dangerous patterns to deny
- bash: ["rm -rf", "sudo", "chmod +x"]
```

---

## Examples by Agent Type

### Research Agent

**Purpose**: Read codebase, write research reports

```yaml
name: "researcher"
tools:
  - read
  - write
  - bash
  - git

permissions:
  allow:
    # Read access to documentation and code
    - read: ["**/*.md", ".claude/**/*", "docs/**/*", "**/*.lua"]
    
    # Write access to research outputs
    - write: ["specs/**/*", "docs/research/**/*"]
    
    # Safe bash commands for analysis
    - bash: ["git", "grep", "find", "wc", "jq", "sed", "awk"]
  
  deny:
    # Dangerous operations
    - bash: ["rm -rf", "sudo", "chmod +x", "dd", "wget", "curl"]
    
    # Protected files
    - write: [".git/**/*"]
    - read: [".env", "**/*.key", "**/*.pem"]
```

### Planning Agent

**Purpose**: Read research, write implementation plans

```yaml
name: "planner"
tools:
  - read
  - write
  - bash
  - git

permissions:
  allow:
    # Read access to specs and documentation
    - read: ["**/*.md", ".claude/**/*", "docs/**/*"]
    
    # Write access to plans
    - write: ["specs/**/*"]
    
    # Safe bash commands
    - bash: ["git", "grep", "find", "wc", "jq"]
  
  deny:
    # Dangerous operations
    - bash: ["rm -rf", "sudo", "chmod +x"]
    
    # Protected files
    - write: [".git/**/*"]
```

### Implementation Agent

**Purpose**: Read plans, write code and documentation

```yaml
name: "implementer"
tools:
  - read
  - write
  - edit
  - bash
  - git

permissions:
  allow:
    # Read access to everything
    - read: ["**/*"]
    
    # Write access to code and specs
    - write: ["**/*.lua", "**/*.md", "specs/**/*"]
    
    # Edit access (safer than write)
    - edit: ["**/*.lua", "**/*.md"]
    
    # Development commands
    - bash: ["git", "grep", "find", "wc", "jq"]

  deny:
    # Dangerous operations
    - bash: ["rm -rf", "sudo", "chmod +x", "dd"]

    # Protected files
    - write: [".git/**/*"]
```

### Domain Implementation Agent

**Purpose**: Implement domain-specific tasks with specialized tooling

```yaml
name: "domain-implementation-agent"
tools:
  - read
  - write
  - edit
  - bash
  - git

permissions:
  allow:
    # Read access to domain codebase
    - read: ["**/*.py", "**/*.md", ".claude/**/*"]

    # Write access to domain files
    - write: ["**/*.py", "specs/**/*"]

    # Edit access for domain files
    - edit: ["**/*.py"]

    # Domain development commands
    - bash: ["git", "python", "pytest"]

  deny:
    # Dangerous operations
    - bash: ["rm -rf", "sudo", "chmod +x"]

    # Protected files
    - write: [".git/**/*", "setup.cfg", "pyproject.toml"]
```

### Utility Agent (Status Sync Manager)

**Purpose**: Update TODO.md and state.json atomically

```yaml
name: "status-sync-manager"
tools:
  - read
  - write
  - bash
  - git

permissions:
  allow:
    # Read access to specs
    - read: ["specs/**/*"]
    
    # Write access to specific files only
    - write: ["specs/TODO.md", "specs/state.json", "specs/**/plans/*.md"]
    
    # Minimal bash commands
    - bash: ["date", "git"]
  
  deny:
    # Dangerous operations
    - bash: ["rm", "sudo", "su"]
    
    # Protected files
    - write: [".git/**/*"]
```

---

## Safety Boundaries

### Dangerous Operations That Must Be Denied

All agents should deny these operations in their frontmatter:

#### Destructive Filesystem Operations
```yaml
deny:
  - bash: ["rm -rf", "rm -fr", "rm -r", "rm -f"]
```
**Rationale**: Can delete entire directory trees, including git repository

#### Privilege Escalation
```yaml
deny:
  - bash: ["sudo", "su", "doas"]
```
**Rationale**: Can execute commands with elevated privileges

#### Permission Changes
```yaml
deny:
  - bash: ["chmod +x", "chmod 777", "chmod -R", "chown", "chgrp"]
```
**Rationale**: Can make files executable or change ownership

#### Disk Operations
```yaml
deny:
  - bash: ["dd", "mkfs", "fdisk", "parted"]
```
**Rationale**: Can destroy disk data

#### Network Operations
```yaml
deny:
  - bash: ["wget", "curl", "nc", "netcat", "ssh", "scp", "rsync"]
```
**Rationale**: Can exfiltrate data or download malicious code

#### Process Manipulation
```yaml
deny:
  - bash: ["kill -9", "killall", "pkill"]
```
**Rationale**: Can terminate critical processes

#### System Modification
```yaml
deny:
  - bash: ["systemctl", "service", "shutdown", "reboot", "init"]
```
**Rationale**: Can modify system state or reboot machine

#### Package Management
```yaml
deny:
  - bash: ["apt", "yum", "dnf", "pip", "npm", "cargo", "gem"]
```
**Rationale**: Can install malicious packages

#### Shell Execution
```yaml
deny:
  - bash: ["eval", "exec", "source", ".", "bash -c", "sh -c"]
```
**Rationale**: Can execute arbitrary code

#### Sensitive File Access
```yaml
deny:
  - read: [".env", "**/*.key", "**/*.pem", ".ssh/**/*", "**/*.secret"]
  - write: [".git/**/*", ".env", "**/*.key"]
```
**Rationale**: Can expose credentials or corrupt git repository

---

## Debugging Permission Denials

### Identifying Denials

Permission denials are logged to `.agent-logs/errors.json`:

```json
{
  "timestamp": "2026-01-05T10:30:00Z",
  "agent": "researcher",
  "error_type": "permission_denied",
  "operation": "write",
  "path": "init.lua",
  "reason": "Path matches deny pattern: init.lua"
}
```

### Common Denial Scenarios

#### Scenario 1: Writing to Protected File

**Error**: `Permission denied: write to .git/config`

**Cause**: `.git/**/*` in deny list

**Solution**: This is intentional. Git internals should never be modified by agents.

#### Scenario 2: Executing Denied Command

**Error**: `Permission denied: bash command 'rm -rf /tmp/old'`

**Cause**: `rm -rf` in deny list

**Solution**: This is intentional. Use git safety commits instead of manual cleanup.

#### Scenario 3: Reading Outside Allowed Paths

**Error**: `Permission denied: read /etc/passwd`

**Cause**: Path not in allow list, default deny applies

**Solution**: If legitimate, add path to allow list. Otherwise, this is intentional.

### Debugging Workflow

1. **Check error log**: Review `.agent-logs/errors.json` for denial details
2. **Review agent frontmatter**: Check allow and deny lists
3. **Verify pattern match**: Test glob pattern against denied path
4. **Assess legitimacy**: Is this operation needed for agent function?
5. **Update permissions**: If legitimate, add to allow list (with deny for dangerous operations)
6. **Test change**: Verify operation succeeds and dangerous operations still denied

---

## Common Permission Patterns

### Pattern 1: Read-Only Research

**Use Case**: Agent needs to analyze codebase without modifications

```yaml
permissions:
  allow:
    - read: ["**/*"]
    - bash: ["grep", "find", "wc", "jq"]
  deny:
    - read: [".env", "**/*.key", "**/*.pem"]
    - bash: ["rm", "sudo", "chmod"]
```

### Pattern 2: Spec-Only Writer

**Use Case**: Agent writes to specs only

```yaml
permissions:
  allow:
    - read: ["**/*.md", ".claude/**/*"]
    - write: ["specs/**/*"]
    - bash: ["git", "date"]
  deny:
    - write: [".git/**/*"]
    - bash: ["rm", "sudo"]
```

### Pattern 3: Code Implementation

**Use Case**: Agent implements code with full access

```yaml
permissions:
  allow:
    - read: ["**/*"]
    - write: ["**/*.lua", "**/*.md", "specs/**/*"]
    - edit: ["**/*.lua", "**/*.md"]
    - bash: ["git", "python", "pytest"]
  deny:
    - write: [".git/**/*"]
    - bash: ["rm -rf", "sudo", "chmod +x"]
```

### Pattern 4: Atomic State Update

**Use Case**: Agent updates specific files atomically

```yaml
permissions:
  allow:
    - read: ["specs/**/*"]
    - write: ["specs/TODO.md", "specs/state.json"]
    - bash: ["date", "git"]
  deny:
    - write: [".git/**/*"]
    - bash: ["rm", "sudo"]
```

---

## Troubleshooting

### Problem: Agent Can't Read Necessary Files

**Symptoms**:
- Agent fails with "Permission denied: read {path}"
- Operation requires file that's not in allow list

**Solution**:
1. Identify required file paths
2. Add glob patterns to allow list:
   ```yaml
   allow:
     - read: ["{required_paths}"]
   ```
3. Ensure no deny rule blocks the paths
4. Test agent operation

### Problem: Agent Can't Write Output Files

**Symptoms**:
- Agent fails with "Permission denied: write {path}"
- Output files not created

**Solution**:
1. Identify output file paths
2. Add glob patterns to allow list:
   ```yaml
   allow:
     - write: ["{output_paths}"]
   ```
3. Ensure output paths don't include protected files
4. Consider using edit instead of write for existing files
5. Test agent operation

### Problem: Agent Can't Execute Required Command

**Symptoms**:
- Agent fails with "Permission denied: bash command '{command}'"
- Operation requires bash command not in allow list

**Solution**:
1. Identify required command
2. Verify command is safe (not in dangerous operations list)
3. Add command to allow list:
   ```yaml
   allow:
     - bash: ["{command}"]
   ```
4. Test agent operation
5. Monitor for abuse

### Problem: Dangerous Operation Not Blocked

**Symptoms**:
- Agent can execute dangerous operation
- Security boundary violated

**Solution**:
1. Immediately add operation to deny list:
   ```yaml
   deny:
     - bash: ["{dangerous_operation}"]
   ```
2. Review all agent frontmatter files
3. Add deny rule to all agents
4. Test that operation is now blocked
5. Document in this guide

### Problem: Permission Changes Break Agent

**Symptoms**:
- Agent worked before, fails after permission change
- Legitimate operations denied

**Solution**:
1. Review recent permission changes in git history:
   ```bash
   git log -p -- .claude/agents/{agent}.md
   ```
2. Identify removed permission
3. Assess if removal was intentional
4. If unintentional, restore permission:
   ```bash
   git checkout HEAD~1 -- .claude/agents/{agent}.md
   ```
5. Test agent operation
6. Document decision

---

## Testing Permission Changes

### Test Checklist

Before committing permission changes:

- [ ] Agent can perform required operations
- [ ] Dangerous operations are still denied
- [ ] No unintended side effects
- [ ] Error handling works correctly
- [ ] Git safety commits created where needed
- [ ] Documentation updated

### Test Commands

```bash
# Test agent with new permissions
/orchestrate 123 --research  # or appropriate command

# Check for permission denials
grep "permission_denied" .agent-logs/errors.json

# Test dangerous operation is blocked
# (should fail with permission denied)
{agent_operation_that_should_fail}

# Verify git safety commits
git log --oneline -5

# Rollback if needed
git reset --hard HEAD~1
```

---

## Best Practices

### 1. Start Restrictive, Expand Gradually

Begin with minimal permissions and add as needed:

```yaml
# Start here
permissions:
  allow:
    - read: ["specs/**/*"]
    - write: ["specs/{agent_output}/**/*"]
    - bash: ["git"]

# Expand as needed
permissions:
  allow:
    - read: ["**/*.md", ".claude/**/*"]
    - write: ["specs/**/*"]
    - bash: ["git", "grep", "find"]
```

### 2. Always Include Deny Rules

Even with restrictive allow lists, include deny rules:

```yaml
permissions:
  allow:
    - bash: ["git"]
  deny:
    - bash: ["rm -rf", "sudo"]  # Explicit deny for clarity
```

### 3. Use Git Safety for Risky Operations

When expanding permissions, ensure git safety commits:

```yaml
# In agent workflow
<stage name="CreateSafetyCommit">
  <action>Create git safety commit before risky operation</action>
  <process>
    1. bash .claude/scripts/git-commit-scoped.sh --message "safety: pre-{operation} snapshot" --session "${session_id}" -- {files_to_modify}
    2. safety_commit=$(git rev-parse HEAD)
  </process>
</stage>
```

### 4. Document Permission Rationale

Add comments to agent frontmatter:

```yaml
permissions:
  allow:
    # Research agents need read access to analyze codebase
    - read: ["**/*.md", "**/*.lua"]
    
    # Write access limited to research outputs
    - write: ["specs/**/*"]
  
  deny:
    # Prevent modification of build configuration
    - write: ["config.yaml", "lock-file.json"]
```

### 5. Monitor Permission Denials

Regularly review denial logs:

```bash
# Check recent denials
jq '.[] | select(.error_type == "permission_denied")' .agent-logs/errors.json

# Group by agent
jq 'group_by(.agent) | map({agent: .[0].agent, count: length})' .agent-logs/errors.json
```

### 6. Test Rollback Scenarios

Verify git safety provides adequate protection:

```bash
# Create safety commit
bash .claude/scripts/git-commit-scoped.sh --message "safety: test" --session "${session_id}" -- {files}
safety_commit=$(git rev-parse HEAD)

# Make changes
{agent_operation}

# Rollback
git reset --hard $safety_commit
git clean -fd

# Verify rollback succeeded
git status
```

---

## Related Documentation

- [Frontmatter Standard](../../context/formats/frontmatter.md) - Agent frontmatter format
- [Delegation](../../context/orchestration/delegation.md) - Agent delegation patterns
- [State Management](../../context/orchestration/state-management.md) - State file management

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-05 | Initial permission configuration guide |

---

## Feedback

If you encounter permission issues not covered in this guide, please:

1. Document the issue in `.agent-logs/errors.json`
2. Create a task with `/task` command
3. Include permission denial details
4. Suggest solution if known

This guide will be updated based on production experience.
