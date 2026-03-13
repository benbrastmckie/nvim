# Research Report: Task #192

**Task**: 192 - bypass_opencode_permission_requests
**Started**: 2026-03-13T00:00:00Z
**Completed**: 2026-03-13T00:30:00Z
**Effort**: 2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .opencode/settings.json, extension settings fragments, context/schemas, hooks directory
**Artifacts**: - specs/192_bypass_opencode_permission_requests/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The opencode permission system uses a `settings.json` file with `allow` and `deny` arrays to control tool access
- Permission prompts can be bypassed using the `PreToolUse` hook mechanism which returns `{"permissionDecision": "allow"}`
- The `CLAUDE_TOOL_INPUT` environment variable provides tool arguments in JSON format for dynamic permission decisions
- Four approaches identified: PreToolUse hooks, pattern-based permissions, environment variables (not currently supported), and global allow patterns
- **Recommended approach**: Extend PreToolUse hooks to check for `/tmp/*` paths and auto-allow access

## Context & Scope

This research investigates how to bypass opencode's permission requests for external directories like `/tmp/*`. Currently, opencode asks for permission with dialog options (Once, Always, Reject) when accessing files outside the workspace. The goal is to configure the system to automatically allow such permissions without prompts.

### Research Questions

1. How does the opencode permission system work?
2. What configuration options are available for permissions?
3. Can PreToolUse hooks be used to auto-allow permissions?
4. Are there environment variables that control permission behavior?
5. What is the best approach for the user's needs?

## Findings

### How the Permission System Works

The opencode permission system is configured in `.opencode/settings.json` with the following structure:

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(nvim *)",
      "Read",
      "Write",
      "Edit",
      ...
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(sudo *)",
      ...
    ]
  },
  "hooks": {
    "PreToolUse": [...],
    "PostToolUse": [...]
  }
}
```

**Permission Pattern Matching:**
- `Bash(command pattern)` - Allows specific bash commands with glob patterns
- `Read`, `Write`, `Edit`, `Glob`, `Grep`, `WebSearch`, `WebFetch`, `Task`, `TodoWrite` - Allows entire tool categories
- `mcp__server-name__tool-name` - Allows specific MCP tool invocations
- `deny` patterns take precedence over `allow` patterns

**Permission Decision Flow:**
1. Tool invocation is checked against `deny` patterns first
2. If not denied, checked against `allow` patterns
3. If not explicitly allowed, opencode shows a permission dialog
4. User can select Once, Always, or Reject

### PreToolUse Hook Mechanism

The `PreToolUse` hook system provides dynamic permission control. Hooks are executed before a tool runs and can return a permission decision.

**Current Implementation in settings.json:**

```json
"PreToolUse": [
  {
    "matcher": "Write",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
      }
    ]
  }
]
```

**Key Components:**

1. **`matcher`**: Specifies which tool(s) the hook applies to (e.g., "Write", "Read", "Bash")
2. **`CLAUDE_TOOL_INPUT`**: Environment variable containing tool arguments as JSON
3. **`permissionDecision`**: Return field with values: `"allow"`, `"deny"`, or `"ask"`
4. **`permissionDecisionReason`**: Optional explanation for the decision

**Hook Return Format:**
```json
{
  "permissionDecision": "allow",
  "permissionDecisionReason": "Auto-allowed for /tmp/* access"
}
```

### Available Hook Types

The settings.json supports these hook types:

| Hook Type | When Triggered | Use Case |
|-----------|----------------|----------|
| `PreToolUse` | Before any tool execution | Permission decisions, input validation |
| `PostToolUse` | After tool execution | Logging, validation, side effects |
| `SessionStart` | When session begins | Initialization, setup |
| `UserPromptSubmit` | When user submits prompt | Pre-processing |
| `Stop` | When command/agent stops | Cleanup, notifications |
| `SubagentStop` | When subagent completes | Post-processing results |

### Extension Permission Patterns

Extensions can provide `settings-fragment.json` files that add permissions:

**Example from extensions/nix/settings-fragment.json:**
```json
{
  "permissions": {
    "allow": [
      "mcp__nixos__nix",
      "mcp__nixos__nix_versions"
    ]
  }
}
```

These fragments are merged with the main settings.json.

## Approaches to Bypass Permission Prompts

### Approach 1: PreToolUse Hooks (RECOMMENDED)

Create hooks that check for `/tmp/*` paths and auto-allow them.

**Implementation:**

```json
"PreToolUse": [
  {
    "matcher": "Read",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"ask\\\"}\"; fi'"
      }
    ]
  },
  {
    "matcher": "Write",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
      }
    ]
  },
  {
    "matcher": "Edit",
    "hooks": [
      {
        "type": "command",
        "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"ask\\\"}\"; fi'"
      }
    ]
  }
]
```

**Pros:**
- Granular control over which files/paths are auto-allowed
- Can add logging/tracking of auto-allowed operations
- Works immediately without restart
- Can be extended to other paths beyond /tmp

**Cons:**
- Requires complex JSON escaping
- Each tool (Read, Write, Edit) needs separate hook
- Must be careful not to accidentally deny legitimate operations

### Approach 2: Pattern-Based Permissions

Add pattern-based permissions to the `allow` array.

**Note:** The current settings.json uses simple tool names like `"Read"`, `"Write"` without path patterns. It is unclear if patterns like `Read(/tmp/*)` are supported based on the current codebase.

**Hypothetical Implementation:**
```json
"permissions": {
  "allow": [
    "Read",
    "Write",
    "Edit",
    "Read(/tmp/*)",
    "Write(/tmp/*)",
    "Edit(/tmp/*)"
  ]
}
```

**Pros:**
- Simple configuration change
- No hooks needed

**Cons:**
- Path-specific permissions not confirmed to work in current opencode version
- May require opencode version update

### Approach 3: Environment Variables

Search was conducted for environment variables controlling permissions. **No environment variables were found** that control the permission dialog behavior in the current opencode system.

Variables found in use:
- `CLAUDE_TOOL_INPUT` - Tool arguments (JSON)
- `OBSIDIAN_API_KEY`, `OBSIDIAN_PORT` - For MCP servers
- `OPENCODE_TTS_ENABLED` - For TTS notifications

**Conclusion:** Environment variable approach is not currently supported.

### Approach 4: Global Allow with Selective Deny

Modify the existing Write hook to allow everything except sensitive paths.

**Current Write hook allows all writes:**
```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "bash -c '... echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\";'"
    }
  ]
}
```

This already auto-allows all Write operations! The current implementation returns `{"permissionDecision": "allow"}` for ALL write operations, not just state.json.

**Wait - let me re-read the current implementation:**

The current hook:
```bash
if [[ "$FILE" == *"specs/state.json"* ]]; then 
  echo "{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"State file write\"}"; 
else 
  echo "{\"permissionDecision\": \"allow\"}"; 
fi
```

This shows that the ELSE branch also returns `allow`, meaning ALL writes are currently auto-allowed. This suggests the current setup already bypasses Write permission prompts.

However, Read and Edit operations may still prompt for external directories.

## Recommended Implementation

Based on the findings, here is the recommended approach to bypass all permission prompts for `/tmp/*`:

### Solution: Extend PreToolUse Hooks for Read, Write, Edit

Add PreToolUse hooks for Read and Edit tools to auto-allow `/tmp/*` access, similar to the existing Write hook.

**Complete settings.json modification:**

```json
{
  "permissions": {
    "allow": [
      "Bash(git:*)",
      "Bash(nvim *)",
      "Bash(luac *)",
      "Bash(lake *)",
      "Bash(pdflatex *)",
      "Bash(latexmk *)",
      "Bash(bibtex *)",
      "Bash(biber *)",
      "Bash(pnpm *)",
      "Bash(npx *)",
      "Bash(cd *)",
      "Bash(ls *)",
      "Bash(mkdir *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(chmod +x *)",
      "Read",
      "Write",
      "Edit",
      "Glob",
      "Grep",
      "WebSearch",
      "WebFetch",
      "Task",
      "TodoWrite",
      "mcp__lean-lsp__*",
      "mcp__astro-docs__*",
      "mcp__context7__*",
      "mcp__playwright__*"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo *)",
      "Bash(chmod 777 *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"ask\\\"}\"; fi'"
          }
        ]
      },
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"State file write\\\"}\"; elif [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"allow\\\"}\"; fi'"
          }
        ]
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == /tmp/* ]]; then echo \"{\\\"permissionDecision\\\": \\\"allow\\\", \\\"permissionDecisionReason\\\": \\\"Auto-allowed /tmp access\\\"}\"; else echo \"{\\\"permissionDecision\\\": \\\"ask\\\"}\"; fi'"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write",
        "hooks": [
          {
            "type": "command",
            "command": "bash -c 'FILE=$(echo \"$CLAUDE_TOOL_INPUT\" | jq -r \".file_path // empty\" 2>/dev/null); if [[ \"$FILE\" == *\"specs/state.json\"* ]]; then bash .opencode/hooks/validate-state-sync.sh 2>/dev/null || echo \"{}\"; else echo \"{}\"; fi'"
          }
        ]
      }
    ],
    "SessionStart": [...],
    "UserPromptSubmit": [...],
    "Stop": [...],
    "SubagentStop": [...]
  }
}
```

### Alternative: Universal Auto-Allow Hook

If the goal is to bypass ALL permission prompts (not just /tmp), use this simplified approach:

```json
"PreToolUse": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "echo '{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"Auto-allowed by system configuration\"}'"
      }
    ]
  }
]
```

**WARNING**: This disables ALL permission checks. Only use in trusted environments.

## Decisions

1. **PreToolUse hooks are the correct mechanism** for auto-allowing permissions
2. **Write operations are already auto-allowed** in the current configuration
3. **Read and Edit need additional hooks** to auto-allow /tmp/* access
4. **No environment variables** currently control permission behavior
5. **The `*` matcher** can be used to apply hooks to all tools (use with caution)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Overly permissive configuration | Security - could allow malicious file access | Only auto-allow specific paths like `/tmp/*`, use deny patterns for dangerous commands |
| JSON escaping errors | Configuration won't load | Test configuration with `cat settings.json | jq .` to validate JSON |
| Hook execution failures | Permission prompts may still appear | Add `|| echo '{"permissionDecision":"ask"}'` fallback to hooks |
| Unintended path matches | Could allow access to wrong files | Use strict pattern matching `[[ "$FILE" == /tmp/* ]]` instead of wildcards in middle |
| Lost audit trail | Can't track what was auto-allowed | Add `permissionDecisionReason` field with descriptive messages |

## Context Extension Recommendations

- **Topic**: Permission system documentation
- **Gap**: No comprehensive documentation exists for the PreToolUse hook mechanism and permissionDecision format
- **Recommendation**: Create `.opencode/context/core/permissions.md` documenting:
  - Permission pattern syntax
  - Hook configuration format
  - CLAUDE_TOOL_INPUT structure
  - Common permission bypass patterns
  - Security best practices

## Appendix

### Search Queries Used

1. Codebase search: `grep -r "permission\|allow\|deny\|PreToolUse" .opencode/`
2. File pattern search: `glob "**/*permission*"` in .opencode/
3. Settings analysis: Read `.opencode/settings.json`
4. Extension settings: Read `extensions/*/settings-fragment.json`
5. Schema analysis: Read `context/core/schemas/frontmatter-schema.json`
6. Hook analysis: Read `hooks/validate-state-sync.sh`

### CLAUDE_TOOL_INPUT Structure

Based on the hook implementations, `CLAUDE_TOOL_INPUT` contains:

**For Read tool:**
```json
{
  "file_path": "/path/to/file"
}
```

**For Write tool:**
```json
{
  "file_path": "/path/to/file",
  "content": "file content"
}
```

**For Edit tool:**
```json
{
  "file_path": "/path/to/file",
  "old_string": "text to replace",
  "new_string": "replacement text"
}
```

**For Bash tool:**
```json
{
  "command": "command to execute",
  "workdir": "/optional/workdir"
}
```

### permissionDecision Values

- `"allow"` - Grant permission without prompting
- `"deny"` - Deny permission without prompting
- `"ask"` - Show permission dialog to user (default behavior)

### References

- `.opencode/settings.json` - Main configuration file
- `.opencode/context/core/schemas/frontmatter-schema.json` - Permission schema
- `.opencode/extensions/nix/settings-fragment.json` - Extension permission example
- `.opencode/hooks/validate-state-sync.sh` - Hook script example
