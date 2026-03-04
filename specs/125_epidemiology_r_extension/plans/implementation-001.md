# Implementation Plan: Task #125

**Task**: OC_125 - Add epidemiology research extension for R and related tooling
**Version**: 001
**Created**: 2026-03-04
**Language**: meta

## Overview

Implement a comprehensive epidemiology research extension in both `.opencode/extensions/epidemiology/` and `.claude/extensions/epidemiology/`. This extension will support R-based workflows using the `rmcp` and `mcptools` MCP servers, along with specialized agents for research design and implementation. The extension will incorporate domain knowledge for key packages like EpiModel, epidemia (Stan), EpiNow2, and EpiEstim.

## Phases

### Phase 1: Extension Structure Scaffold

**Status**: [COMPLETED]
**Estimated effort**: 1 hour

**Objectives**:
1. Create extension directory structure in `.opencode/` and `.claude/`
2. Create `manifest.json` with merge targets
3. Create `EXTENSION.md` with language routing configuration
4. Create initial `index-entries.json`

**Files to modify**:
- `.opencode/extensions/epidemiology/manifest.json` - Define extension metadata
- `.opencode/extensions/epidemiology/EXTENSION.md` - Define language routing
- `.opencode/extensions/epidemiology/index-entries.json` - Define context
- `.claude/extensions/epidemiology/` - Mirror structure

**Steps**:
1. Create directories: `agents`, `skills`, `context`, `rules`
2. Write `manifest.json` linking to OPENCODE.md and index.json
3. Write `EXTENSION.md` defining `r` and `epidemiology` language routes
4. Write `index-entries.json` with placeholders for context files
5. Copy structure to `.claude/extensions/epidemiology/`

**Verification**:
- Verify directories exist in both locations
- Check `manifest.json` syntax
- Ensure `EXTENSION.md` contains routing tables

---

### Phase 2: Agents and Skills Implementation

**Status**: [COMPLETED]
**Estimated effort**: 2 hours

**Objectives**:
1. Implement `epidemiology-research-agent`
2. Implement `epidemiology-implementation-agent`
3. Implement `skill-epidemiology-research`
4. Implement `skill-epidemiology-implementation`

**Files to modify**:
- `.opencode/extensions/epidemiology/agents/epidemiology-research-agent.md`
- `.opencode/extensions/epidemiology/agents/epidemiology-implementation-agent.md`
- `.opencode/extensions/epidemiology/skills/skill-epidemiology-research/SKILL.md`
- `.opencode/extensions/epidemiology/skills/skill-epidemiology-implementation/SKILL.md`

**Steps**:
1. Write research agent definition (model: opus, tools: WebSearch, rmcp, etc.)
2. Write implementation agent definition (tools: Rscript, Write, Edit, rmcp)
3. Write research skill definition with allowed tools and context
4. Write implementation skill definition
5. Mirror files to `.claude/extensions/`

**Verification**:
- Verify agent files exist and follow schema
- Verify skill files exist and follow schema

---

### Phase 3: Domain Context Documentation

**Status**: [COMPLETED]
**Estimated effort**: 3 hours

**Objectives**:
1. Document R epidemiology packages (EpiModel, epidemia, EpiNow2)
2. Document statistical analysis patterns (Stan, Bayesian inference)
3. Create guides for MCP tools usage

**Files to modify**:
- `.opencode/extensions/epidemiology/context/project/epidemiology/README.md`
- `.opencode/extensions/epidemiology/context/project/epidemiology/tools/r-packages.md`
- `.opencode/extensions/epidemiology/context/project/epidemiology/tools/mcp-guide.md`
- `.opencode/extensions/epidemiology/context/project/epidemiology/patterns/statistical-modeling.md`

**Steps**:
1. Write domain README with overview of epidemiology workflows
2. Write `r-packages.md` detailing EpiModel, epidemia, EpiNow2, EpiEstim
3. Write `mcp-guide.md` documenting usage of `rmcp` and `mcptools`
4. Write `statistical-modeling.md` covering Bayesian workflows with Stan
5. Mirror to `.claude/extensions/`

**Verification**:
- Context files contain accurate package information
- MCP guide matches server capabilities

---

### Phase 4: Integration and Configuration

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1. Add MCP server configuration snippet
2. Integrate with OPENCODE.md
3. Update context index

**Files to modify**:
- `.opencode/extensions/epidemiology/settings-fragment.json` - MCP config
- `.opencode/OPENCODE.md` - (via merge target)
- `.opencode/context/index.json` - (via merge target)

**Steps**:
1. Create `settings-fragment.json` with `rmcp` configuration
2. Run `/meta` (or manual merge) to update system configuration (optional, as extensions usually self-install via leader picker, but we define the files here)
   - *Note*: We will just define the source files. The system handles merging when the extension is loaded.
3. Validate JSON syntax for all configuration files

**Verification**:
- `settings-fragment.json` is valid JSON
- MCP configuration is correct for `rmcp`

---

## Dependencies

- R installation (system level)
- Python/pip (for rmcp)
- R packages: `EpiModel`, `epidemia`, `EpiNow2`, `mcptools`

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| MCP server `rmcp` not installed | Agent instructions include fallback to standard Rscript execution |
| Stan toolchain missing | Documentation includes setup guide for RTools/Stan |
| Dual extension maintenance | Script or manual process to ensure parity between .opencode and .claude |

## Success Criteria

- [ ] Directory structure created in both .opencode and .claude
- [ ] Agents and Skills defined and valid
- [ ] Context documentation covers identified R packages
- [ ] MCP configuration available in settings-fragment
```
