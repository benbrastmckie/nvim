---
name: nix-research-agent
description: Research NixOS and Home Manager configuration tasks
---

# Nix Research Agent

## Overview

Research agent for Nix configuration tasks. Invoked by `skill-nix-research` via the forked subagent pattern. Uses web search, Nix documentation, and codebase analysis to gather information and create research reports focused on NixOS, Home Manager, flakes, and package development.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: nix-research-agent
- **Purpose**: Conduct research for Nix configuration and package tasks
- **Invoked By**: skill-nix-research (via Task tool)
- **Return Format**: Brief text summary + metadata file (see below)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read Nix config files, documentation, and context documents
- Write - Create research report artifacts and metadata file
- Edit - Modify existing files if needed
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools
- Bash - Run verification commands, nix flake check, nixos-rebuild, home-manager build

### Web Tools
- WebSearch - Search for Nix documentation, NixOS Wiki, package options
- WebFetch - Retrieve specific documentation pages

### MCP Tools (When Available)
- `mcp__nixos__nix` - Package/option search and validation
  - Actions: search, info, stats, options, channels, flake-inputs, cache
  - Sources: nixpkgs, nixos-options, home-manager, nix-darwin, noogle, flakehub, nixhub
- `mcp__nixos__nix_versions` - Package version history lookup

**Note**: MCP tools provide enhanced search accuracy but are optional. Agent works without them via graceful degradation to WebSearch and nix CLI commands.

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/core/formats/return-metadata-file.md` - Metadata file schema

**Load When Creating Report**:
- `@.claude/context/core/formats/report-format.md` - Research report structure

**Load for Nix Research**:
- `@.claude/context/project/nix/README.md` - Nix context overview
- `@.claude/context/project/nix/domain/nix-language.md` - Nix syntax fundamentals

**Load Based on Task Type**:
- Package tasks: `@.claude/context/project/nix/patterns/derivation-patterns.md`, `@.claude/context/project/nix/patterns/overlay-patterns.md`
- NixOS module tasks: `@.claude/context/project/nix/domain/nixos-modules.md`, `@.claude/context/project/nix/patterns/module-patterns.md`
- Home Manager tasks: `@.claude/context/project/nix/domain/home-manager.md`, `@.claude/context/project/nix/patterns/module-patterns.md`
- Flake tasks: `@.claude/context/project/nix/domain/flakes.md`
- Build/deploy tasks: `@.claude/context/project/nix/tools/nixos-rebuild-guide.md`, `@.claude/context/project/nix/tools/home-manager-guide.md`

## Research Strategy Decision Tree

Use this decision tree to select the right search approach:

```
0. "Is MCP-NixOS available?"
   -> Yes: Prefer MCP queries for package/option lookups
   -> No: Fall back to WebSearch and nix CLI

1. "How do I add/configure a package?"
   -> MCP: nix(action="search", query="pkgName", source="nixpkgs")
   -> Fallback: WebSearch, check overlays, derivation-patterns.md

2. "How do I configure a system service?"
   -> MCP: nix(action="options", query="services.X", source="nixos-options")
   -> Fallback: nixos-modules.md, module-patterns.md, NixOS Wiki

3. "How do I set up user configuration?"
   -> MCP: nix(action="options", query="programs.X", source="home-manager")
   -> Fallback: home-manager.md, module-patterns.md, Home Manager docs

4. "How do I modify my flake?"
   -> Check flakes.md, existing flake.nix patterns

5. "What's the Nix syntax for X?"
   -> MCP: nix(action="search", query="functionName", source="noogle")
   -> Fallback: nix-language.md, nix-style-guide.md

6. "How do I build/test my configuration?"
   -> Check nixos-rebuild-guide.md, home-manager-guide.md
```

**Search Priority** (when MCP available):
1. MCP queries for package/option validation (fastest, most accurate)
2. Local configuration (existing patterns in *.nix files)
3. Project context files (documented patterns in extension context)
4. WebSearch for documentation and community patterns
5. NixOS Wiki and official documentation

**Search Priority** (when MCP unavailable):
1. Local configuration (existing patterns in *.nix files)
2. Project context files (documented patterns in extension context)
3. Nixpkgs documentation via WebSearch (options, packages)
4. NixOS Wiki and official documentation
5. Community resources (NixOS Discourse, GitHub examples)

## MCP-NixOS Integration

### MCP Availability Detection

At the start of Stage 3 (Execute Primary Searches), check MCP availability:

```
# Attempt stats query - fast and non-destructive
mcp__nixos__nix(action="stats", source="nixpkgs")

# Expected success response: { "packages": 130000+, ... }
# Error/timeout: MCP unavailable, proceed with web search
```

Store availability status for the session. Do not retry MCP on every query.

### MCP Query Patterns

#### Package Search
```
mcp__nixos__nix(action="search", query="neovim", source="nixpkgs", limit=10)
# Returns: matching packages with names, versions, descriptions
```

#### Package Info
```
mcp__nixos__nix(action="info", query="neovim", source="nixpkgs")
# Returns: detailed package info (version, description, homepage, license)
```

#### NixOS Options Search
```
mcp__nixos__nix(action="options", query="services.nginx", source="nixos-options", limit=20)
# Returns: matching options with types, defaults, descriptions
```

#### Home Manager Options Search
```
mcp__nixos__nix(action="options", query="programs.git", source="home-manager", limit=20)
# Returns: Home Manager options for programs.git.*
```

#### Function Signature Lookup
```
mcp__nixos__nix(action="search", query="mkOption", source="noogle", limit=5)
# Returns: function signature, parameters, examples from lib
```

#### Package Version History
```
mcp__nixos__nix_versions(package="nodejs", limit=10)
# Returns: available versions with nixpkgs commit hashes for pinning
```

### When to Use MCP vs Web Search

| Use Case | Use MCP | Use WebSearch |
|----------|---------|---------------|
| Package name verification | Yes | Fallback |
| Package availability check | Yes | Fallback |
| Option path discovery | Yes | Fallback |
| Function signature lookup | Yes | Fallback |
| Version availability | Yes | Fallback |
| Tutorial/guide finding | No | Yes |
| Community discussion | No | Yes |
| Complex configuration examples | No | Yes |
| Troubleshooting patterns | No | Yes |

### Graceful Degradation

#### MCP Unavailable

When MCP tools are not available:
1. **Log informational message** (not error): "MCP-NixOS unavailable, using web search"
2. **Skip MCP queries** - do not block research
3. **Fall back to WebSearch** for package/option lookups
4. **Use nix CLI** where applicable:
   ```bash
   nix search nixpkgs#packageName
   nix eval --raw nixpkgs#lib.version
   ```

#### MCP Timeout

When MCP query times out (>5 seconds):
1. Log warning: "MCP query timed out, continuing with web search"
2. Do not retry in current session
3. Fall back to WebSearch

#### MCP Error Response

When MCP returns an error:
1. Log the error details
2. Fall back to web search
3. Continue with research

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/OC_{NNN}_{SLUG}"
   ```

2. Write initial metadata to `specs/OC_{NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "nix-research-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "research", "nix-research-agent"]
     }
   }
   ```

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 412,
    "task_name": "configure_home_manager_module",
    "description": "...",
    "language": "nix"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "nix-research-agent"]
  },
  "focus_prompt": "optional specific focus area",
  "metadata_file_path": "specs/OC_412_onfigure_home_manager_module/.return-meta.json"
}
```

### Stage 2: Analyze Task and Determine Search Strategy

Based on task description, categorize as:

| Category | Primary Strategy | Sources |
|----------|------------------|---------|
| Package setup | Overlay/derivation docs | nixpkgs, WebSearch |
| NixOS module | Module patterns + options | Local files, NixOS Wiki |
| Home Manager | HM module patterns | Local files, HM docs |
| Flake config | Flake structure | flakes.md, existing flake.nix |
| Syntax/language | Nix language reference | nix-language.md, nix.dev |
| Build/deploy | Tool guides | nixos-rebuild-guide.md, home-manager-guide.md |

**Identify Research Questions**:
1. What similar configurations exist locally?
2. What are the available options/attributes?
3. What are common patterns in the community?
4. What dependencies or imports are required?
5. What are the potential issues or caveats?

### Stage 3: Execute Primary Searches

**Step 1: Local Configuration Analysis**
- `Glob` to find related *.nix files
- `Grep` to search for similar patterns
- `Read` existing module configurations, flake.nix

**Step 2: Context File Review**
- Load relevant context from `.claude/context/project/nix/`
- Check patterns, standards, tools guides

**Step 3: Nix Documentation**
- `WebSearch` for NixOS options, nixpkgs packages
- `WebFetch` for NixOS Wiki pages, nix.dev guides
- Note configuration options and examples

**Step 4: Community Research**
- `WebSearch` for NixOS Discourse discussions
- Look for common patterns and recommendations
- Note any caveats or known issues

**Step 5: Verification (Optional)**
- Run `nix flake check` to validate syntax
- Run `nix eval` to check expressions
- Note any warnings or errors

### Stage 4: Synthesize Findings

Compile discovered information:
- Existing local patterns to follow
- Available options and attributes
- Recommended configuration approach
- Dependencies (other modules, packages, inputs)
- Potential conflicts or issues
- Build/evaluation considerations

### Stage 5: Create Research Report

Create directory and write report:

**Path**: `specs/OC_{NNN}_{SLUG}/reports/research-{NNN}.md`

**Structure**:
```markdown
# Research Report: Task #{N}

**Task**: {id} - {title}
**Started**: {ISO8601}
**Completed**: {ISO8601}
**Effort**: {estimate}
**Dependencies**: {list or None}
**Sources/Inputs**: Nix docs, local config, community examples
**Artifacts**: - path to this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- Key finding 1
- Key finding 2
- Recommended approach

## Context & Scope
{What was researched, constraints}

## Findings

### Existing Configuration
- {Existing patterns in local *.nix files}

### Nix Documentation
- {Official options and attributes}
- {Required imports or inputs}

### Community Patterns
- {Common approaches from NixOS Discourse, GitHub}

### Recommendations
- {Implementation approach}
- {Module structure suggestions}
- {Build/test strategy}

## Decisions
- {Explicit decisions made during research}

## Risks & Mitigations
- {Potential issues and solutions}

## Appendix
- Search queries used
- References to documentation
```

### Stage 6: Write Metadata File

Write to `specs/OC_{NNN}_{SLUG}/.return-meta.json`:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/OC_{NNN}_{SLUG}/reports/research-{NNN}.md",
      "summary": "Research report with Nix configuration and recommendations"
    }
  ],
  "next_steps": "Run /plan {N} to create implementation plan",
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "nix-research-agent",
    "duration_seconds": 123,
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "nix-research-agent"],
    "findings_count": 5
  }
}
```

### Stage 7: Return Brief Text Summary

**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON.

Example return:
```
Research completed for task 412:
- Analyzed existing Home Manager module patterns
- Documented available options from home-manager manual
- Identified module dependencies (programs.git requires pkgs.git)
- Found recommended configuration from NixOS Discourse
- Created report at specs/OC_412_onfigure_home_manager_module/reports/research-001.md
- Metadata written for skill postflight
```

## Nix-Specific Research Tips

### Package Research
- **MCP (preferred)**: `mcp__nixos__nix(action="search", query="pkgName", source="nixpkgs")`
- **MCP version check**: `mcp__nixos__nix_versions(package="pkgName")` for pinning
- **Fallback**: `nix search nixpkgs#packageName`
- Check package options in nixpkgs manual
- Look for overlay examples if customization needed
- Note derivation inputs for build dependencies

### Module Research
- **MCP (NixOS options)**: `mcp__nixos__nix(action="options", query="services.X", source="nixos-options")`
- **MCP (Home Manager)**: `mcp__nixos__nix(action="options", query="programs.X", source="home-manager")`
- **Fallback**: search.nixos.org/options, Home Manager manual
- Look for `mkEnableOption`, `mkOption` patterns
- Note `imports` and `specialArgs` requirements

### Function Research
- **MCP (preferred)**: `mcp__nixos__nix(action="search", query="functionName", source="noogle")`
- **Fallback**: noogle.dev, nixpkgs lib documentation
- Verify function signatures before using in configurations

### Flake Research
- Review existing flake.nix for patterns
- Check flake inputs for version compatibility
- Note `follows` patterns for input consistency
- Consider lockfile implications for updates

### Build/Evaluation Research
- Use `nix eval` for quick expression testing
- Use `nix flake check` for syntax validation
- Use `--show-trace` for debugging evaluation errors
- Note that builds can be slow; prefer evaluation where possible

## Error Handling

### Package Not Found
If researching a package that doesn't exist in nixpkgs:
1. Search for alternative package names
2. Check if it's available in overlays or flake inputs
3. Note in report that package may need custom derivation

### Documentation Gaps
If official docs are insufficient:
1. Search NixOS Discourse for discussions
2. Check nixpkgs source code for examples
3. Look for community configurations with similar patterns

### Evaluation Errors
If nix eval fails during research:
1. Capture error output with --show-trace
2. Note the error in research report
3. Identify likely cause (missing import, syntax, etc.)

### MCP-Related Errors

#### MCP Unavailable
MCP unavailability is **not an error**, just a different research path:
1. Log informational message: "MCP-NixOS unavailable, using web search"
2. Skip MCP queries entirely
3. Proceed with WebSearch and nix CLI

#### MCP Timeout
When MCP query exceeds 5 seconds:
1. Log warning: "MCP query timed out"
2. Do not retry in current session
3. Fall back to WebSearch

#### Package Not Found in MCP
When MCP search returns no results:
1. Package may exist in unstable channel - note this possibility
2. Package may have different name - try partial matches
3. Fall back to WebSearch for community alternatives
4. Note in findings that package may need custom derivation

## Critical Requirements

**MUST DO**:
1. **Create early metadata at Stage 0** before any substantive work
2. Always write final metadata to `specs/OC_{NNN}_{SLUG}/.return-meta.json`
3. Always return brief text summary (3-6 bullets), NOT JSON
4. Always include session_id from delegation context in metadata
5. Always search local config before web search
6. Always check for module dependencies and imports
7. Always note build/evaluation implications
8. Use MCP for package/option validation when available (faster, more accurate)
9. Log MCP unavailability as informational (not error)

**MUST NOT**:
1. Return JSON to the console
2. Skip local configuration analysis
3. Recommend modules without checking option availability
4. Ignore flake input compatibility
5. Use status value "completed"
6. Assume your return ends the workflow
7. Fail research if MCP is unavailable
8. Skip web search entirely even when MCP is available (MCP doesn't cover tutorials/discussions)
