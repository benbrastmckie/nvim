# Implementation Plan: Migrate nvim/.opencode/ to Theory/.opencode/ Base

- **Task**: 111 - compare_opencode_agent_systems
- **Status**: [NOT STARTED]
- **Effort**: 5-7 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the current nvim/.opencode/ agent system with Theory/.opencode/ as the new base, then port back neovim-specific elements (agents, skills, domain context) that Theory lacks. This achieves the best of both systems: Theory's mature architecture, deep domain knowledge (lean4, logic, math, typst, latex), comprehensive test infrastructure, and confirmed feature parity with .claude/, combined with nvim's neovim-specific agents and domain context. The resulting system will have feature parity with nvim/.claude/ without relying on an extension system (since .opencode/ does not support extensions).

### Research Integration

Two research reports inform this plan:

- **research-001.md**: Compared nvim/.opencode/ (291 files) vs ProofChecker/.opencode/ (950 files). Concluded nvim has superior architecture (simplified routing, extension system) while ProofChecker has superior domain knowledge and documentation.
- **research-002.md**: Compared Theory/.opencode/ (1016 files) against both systems. Concluded Theory is the most mature system with confirmed .claude/ feature parity. Recommended using Theory as the new base and porting nvim-specific elements back. Identified exactly what would be lost (neovim agents, web agents, extension system, neovim/web domain context, MCP permissions) and gained (logic/math/typst/latex research agents, 7 additional skills, 60+ domain context files, Lean commands).

## Goals & Non-Goals

**Goals**:
- Replace nvim/.opencode/ with Theory/.opencode/ as the base system
- Port neovim-research-agent and neovim-implementation-agent as subagents
- Port neovim domain context (13+ files)
- Add neovim-specific skills (skill-neovim-research, skill-neovim-implementation)
- Update OPENCODE.md to reference nvim project structure instead of Theory/Lean
- Update settings.json with nvim-specific MCP permissions and bash permissions
- Update project-overview.md for the nvim repository
- Optionally port web domain context and web agents
- Validate the resulting system loads and routes correctly

**Non-Goals**:
- Adding an extension system to .opencode/ (that is a .claude/ innovation)
- Porting Python validation scripts (bash validators are sufficient)
- Modifying Theory's core orchestration patterns or skill lifecycle
- Achieving exact parity with nvim/.claude/ (some .claude/-only features like index.json context discovery and model: frontmatter field are not applicable)
- Migrating existing nvim/.opencode/specs/ task history (start fresh with OC_ prefix)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Theory/.opencode/ has changed since research was conducted | M | L | Verify directory structure before copy; research was conducted same day |
| Neovim agents reference nvim-specific paths that differ in Theory structure | M | M | Adapt agent paths during porting (Phase 3); use agent/subagents/ structure |
| OPENCODE.md has many Theory-specific references | H | H | Systematic find-and-replace in Phase 5; verify all sections reference nvim |
| settings.json merge conflicts between Theory and nvim permissions | M | M | Start from Theory settings.json, add nvim-specific permissions incrementally |
| Losing existing nvim/.opencode/specs/ task data | L | H | Back up existing specs/ before overwrite; or exclude specs/ from copy |
| Web domain context is large and may not be needed | L | L | Make web porting optional (Phase 4); skip if not actively needed |
| OC_ task prefix conflicts with existing nvim task numbering | M | M | Reset OC_ numbering in new system; existing .claude/ tasks unaffected |

## Implementation Phases

### Phase 1: Backup and Prepare [COMPLETED]

**Goal**: Preserve current nvim/.opencode/ state and extract files needed for porting before the replacement.

**Tasks**:
- [ ] Create backup of current nvim/.opencode/ directory (excluding node_modules)
- [ ] Extract and save neovim-research.md agent to a staging area
- [ ] Extract and save neovim-implementation.md agent to a staging area
- [ ] Extract and save neovim domain context (context/project/neovim/) to a staging area
- [ ] Extract and save web domain context (context/project/web/) to a staging area
- [ ] Extract and save web agents (web-research.md, web-implementation.md) to a staging area
- [ ] Extract and save code-reviewer.md agent to a staging area
- [ ] Record current settings.json nvim-specific permissions for later merge
- [ ] Back up existing specs/ directory task data (OC_ prefix tasks)

**Timing**: 30 minutes

**Files to modify**:
- No files modified; read-only extraction and backup operations

**Verification**:
- Staging area contains all neovim-specific files
- Backup of nvim/.opencode/ exists and is non-empty
- List of nvim-specific MCP permissions is recorded

---

### Phase 2: Copy Theory/.opencode/ as Base [COMPLETED]

**Goal**: Replace nvim/.opencode/ with the entire Theory/.opencode/ directory, establishing the new base system.

**Tasks**:
- [ ] Remove current nvim/.opencode/ directory (preserving backup from Phase 1)
- [ ] Copy Theory/.opencode/ to nvim/.opencode/ (excluding specs/ directory to avoid overwriting nvim task data)
- [ ] Copy Theory/.opencode/specs/state.json and specs/TODO.md as fresh starting points (reset task numbering)
- [ ] Verify directory structure: agent/, agent/subagents/, commands/, skills/, context/, hooks/, scripts/, docs/, rules/, templates/
- [ ] Verify settings.json exists and is valid JSON
- [ ] Verify orchestrator.md exists in agent/
- [ ] Run `find nvim/.opencode/ -type f | wc -l` to confirm expected file count (~200+ files)

**Timing**: 30 minutes

**Files to modify**:
- Entire `.opencode/` directory (replaced)

**Verification**:
- File count is within expected range (150-250 files, excluding node_modules and specs)
- Core directories all exist: agent/, commands/, skills/, context/, hooks/, rules/
- settings.json parses as valid JSON
- orchestrator.md exists and references Theory architecture

---

### Phase 3: Port Neovim-Specific Agents and Skills [COMPLETED]

**Goal**: Add neovim-research-agent and neovim-implementation-agent as subagents, and create corresponding skills.

**Tasks**:
- [ ] Create `agent/subagents/neovim-research-agent.md` by adapting the extracted neovim-research.md to the Theory subagent format (YAML frontmatter with mode: subagent, proper tools/permissions declarations)
- [ ] Create `agent/subagents/neovim-implementation-agent.md` by adapting the extracted neovim-implementation.md to the Theory subagent format
- [ ] Create `skills/skill-neovim-research/SKILL.md` following Theory's skill template pattern (referencing neovim-research-agent)
- [ ] Create `skills/skill-neovim-implementation/SKILL.md` following Theory's skill template pattern (referencing neovim-implementation-agent)
- [ ] Optionally port `code-reviewer.md` as `agent/subagents/code-reviewer-agent.md`
- [ ] Update the routing configuration (context/core/orchestration/routing.md) to include neovim language routing
- [ ] Verify agent files have valid frontmatter and reference correct subagent paths

**Timing**: 1.5 hours

**Files to modify**:
- `agent/subagents/neovim-research-agent.md` - New file
- `agent/subagents/neovim-implementation-agent.md` - New file
- `skills/skill-neovim-research/SKILL.md` - New file
- `skills/skill-neovim-implementation/SKILL.md` - New file
- `agent/subagents/code-reviewer-agent.md` - New file (optional)
- `context/core/orchestration/routing.md` - Add neovim language routing

**Verification**:
- All new agent files exist and have valid YAML frontmatter
- All new skill files exist and reference correct agent names
- Routing configuration includes `neovim` language with correct agent mappings

---

### Phase 4: Port Domain Context [COMPLETED]

**Goal**: Add neovim domain context files and optionally web domain context to the new system.

**Tasks**:
- [ ] Copy neovim domain context from staging area to `context/project/neovim/` (13+ files preserving subdirectory structure: domain/, patterns/, standards/, templates/, tools/)
- [ ] Create `context/project/neovim/README.md` if not already present
- [ ] Update `context/index.md` to include neovim context entries with appropriate load_when conditions (language: neovim, agents: neovim-research-agent, neovim-implementation-agent)
- [ ] Optionally copy web domain context to `context/project/web/` (14+ files)
- [ ] Optionally create web agents and skills if web context is ported
- [ ] Optionally update `context/index.md` with web context entries
- [ ] Verify all context file paths referenced in agents exist on disk
- [ ] Add neovim rules file: `rules/neovim-lua.md` (port from current nvim/.opencode/rules/)

**Timing**: 1 hour

**Files to modify**:
- `context/project/neovim/` - New directory (13+ files)
- `context/project/web/` - New directory (14+ files, optional)
- `context/index.md` - Updated with new entries
- `rules/neovim-lua.md` - New file

**Verification**:
- `context/project/neovim/` exists with all expected files
- `context/index.md` includes neovim entries
- All file paths referenced in neovim agents are valid
- `rules/neovim-lua.md` exists with Lua coding standards

---

### Phase 5: Update Configuration Files [COMPLETED]

**Goal**: Adapt OPENCODE.md, settings.json, and project-overview.md from Theory's Lean/math focus to nvim's Neovim configuration management focus.

**Tasks**:
- [ ] Update OPENCODE.md:
  - Replace Theory project description with nvim project description
  - Update Project Structure section to reflect nvim directory layout (nvim/, lua/, after/, etc.)
  - Update Language-Based Routing table to include `neovim` and optionally `web`
  - Update Skill-to-Agent Mapping table with neovim agents and skills
  - Update Context Imports section with neovim domain context paths
  - Update Rules References to include neovim-lua.md
  - Remove or generalize Theory-specific references (Lean commands, Theories/ directory, sorry/axiom counts)
  - Update repository_health section to remove Lean-specific metrics
- [ ] Update settings.json:
  - Add nvim-specific MCP permissions: mcp__astro-docs__, mcp__context7__, mcp__playwright__
  - Add nvim-specific bash permissions: Bash(pnpm *), Bash(npx *)
  - Keep Theory's LaTeX permissions (pdflatex, latexmk, bibtex, biber) as they may be useful
  - Verify hook paths are correct for the nvim repository
- [ ] Update `context/project/repo/project-overview.md`:
  - Replace Theory repository overview with nvim configuration repository overview
  - Document nvim directory structure (lua/neotex/, after/ftplugin/, plugin/, etc.)
  - Reference relevant coding standards from nvim/CLAUDE.md
- [ ] Review and update any remaining Theory-specific references in commands/ that mention Lean project paths

**Timing**: 1.5 hours

**Files to modify**:
- `OPENCODE.md` - Comprehensive updates
- `settings.json` - Permission additions
- `context/project/repo/project-overview.md` - Full rewrite
- Various `commands/*.md` files - Minor path updates if needed

**Verification**:
- OPENCODE.md contains no references to Theory, Theories/, Lean-specific metrics
- OPENCODE.md Skill-to-Agent Mapping includes neovim entries
- OPENCODE.md Language-Based Routing includes neovim
- settings.json includes nvim-specific MCP and bash permissions
- settings.json parses as valid JSON
- project-overview.md describes the nvim repository accurately

---

### Phase 6: Validation and Cleanup [COMPLETED]

**Goal**: Verify the migrated system is consistent, remove temporary staging files, and confirm readiness for use.

**Tasks**:
- [ ] Run structure validation: verify all directories exist (agent/, agent/subagents/, commands/, skills/, context/, hooks/, rules/, scripts/, docs/)
- [ ] Verify all agents referenced in skills actually exist as files
- [ ] Verify all skills referenced in OPENCODE.md actually exist as files
- [ ] Verify all context files referenced in index.md exist on disk
- [ ] Verify settings.json is valid JSON with all required hook paths pointing to existing scripts
- [ ] Verify OPENCODE.md contains no stale Theory-specific references
- [ ] Run `scripts/validate-docs.sh` if present to check documentation
- [ ] Remove staging area / backup files (or move to a known archive location)
- [ ] Remove Theory-specific domain context that is not relevant:
  - Keep: lean4/, logic/, math/, latex/, typst/ (useful for formal methods work from nvim)
  - Remove or archive: physics/ (unless actively needed)
- [ ] Verify OC_ task prefix is configured in state.json
- [ ] Create a brief migration summary noting what was ported, what was kept from Theory, and what was omitted

**Timing**: 1 hour

**Files to modify**:
- `context/project/physics/` - Removed or archived (optional)
- Staging area files - Removed
- No other modifications expected; this phase is primarily validation

**Verification**:
- Zero broken file references across agents, skills, and context index
- settings.json validates as correct JSON
- OPENCODE.md has no Theory-specific references
- All hook scripts referenced in settings.json exist on disk
- All agent files have valid frontmatter
- System is ready for first `/task` invocation

## Testing & Validation

- [ ] Structural validation: all expected directories exist
- [ ] File reference validation: all @-references in agents and skills point to existing files
- [ ] JSON validation: settings.json and state.json parse correctly
- [ ] OPENCODE.md validation: no stale Theory references, all tables accurate
- [ ] Context index validation: all entries in index.md point to existing files
- [ ] Hook validation: all hook scripts referenced in settings.json exist and are executable
- [ ] Agent count validation: expected number of agents present (Theory's 14 + 2 neovim + optionally 2 web + 1 code-reviewer = 17-19 agents)
- [ ] Skill count validation: expected number of skills present (Theory's 20 + 2 neovim + optionally 2 web = 22-24 skills)

## Artifacts & Outputs

- `plans/implementation-001.md` - This plan file
- `summaries/implementation-summary-YYYYMMDD.md` - Post-implementation summary
- Updated `nvim/.opencode/` directory (the primary deliverable)

## Rollback/Contingency

The backup created in Phase 1 provides a complete rollback path:

1. If migration fails at any point after Phase 2, restore from the Phase 1 backup
2. The backup preserves the original nvim/.opencode/ in its entirety
3. Since this is a meta task modifying configuration files only (not production code), rollback is straightforward: delete the new .opencode/ and restore the backup
4. Git history also preserves the pre-migration state as an additional safety net
