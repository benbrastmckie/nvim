# Implementation Plan: Task #106

- **Task**: 106 - Review dotfiles .claude/ agent system for NixOS to add nix/ extension
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: Task #102, Task #105
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, artifact-formats.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-02
- **Feature**: Create nix/ extension from dotfiles Nix agent system with MCP-NixOS support
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

This plan creates a `nix/` extension under `.claude/extensions/` by extracting and adapting Nix-specific components from the dotfiles `.claude/` system at `/home/benjamin/.dotfiles/.claude/`. The extension includes 2 agents, 2 skills, 1 rule, 11 context files, and 4 metadata files (manifest.json, EXTENSION.md, index-entries.json, settings-fragment.json). The pattern follows the web/ extension (task 105) as the primary template, with the lean/ extension (task 102) as the precedent for MCP server integration.

### Research Integration

The research report (research-001.md) identified:
- 2 agents (510 and 857 lines) with MCP-NixOS graceful degradation built in
- 2 skills with standard thin-wrapper pattern and postflight markers
- 1 rule file covering Nix formatting, module patterns, and anti-patterns
- 11 context files organized in domain/, patterns/, standards/, tools/ subdirectories
- MCP-NixOS server integration recommended (Option A) since agents already support it
- All dotfiles-specific content (host names, user paths, flake references) must be generalized

## Goals & Non-Goals

**Goals**:
- Create complete `.claude/extensions/nix/` directory following established extension architecture
- Adapt all Nix agents, skills, rules, and context from dotfiles to extension format
- Include MCP-NixOS server support with settings-fragment.json (following lean/ precedent)
- Register extension via manifest.json, EXTENSION.md, and index-entries.json
- Generalize all dotfiles-specific content to be project-agnostic

**Non-Goals**:
- Creating custom slash commands for Nix (standard /research, /plan, /implement workflow suffices)
- Creating setup/verification scripts (MCP-NixOS is simpler than lean-lsp)
- Modifying the core orchestrator routing (EXTENSION.md handles this via merge)
- Updating .opencode/extensions/ (separate task if desired)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Context paths not updated after extraction | High | Medium | Systematic grep verification in Phase 6 |
| Dotfiles agents too large/project-specific | Medium | Low | Extract cleanly, trim project-specific sections |
| MCP-NixOS server not available everywhere | Low | Medium | Agents have built-in graceful degradation |
| Orchestrator routing not updated | High | Low | EXTENSION.md merge target handles this |
| Missing dotfiles source files | Medium | Low | Research verified all 16 source files exist |

## Implementation Phases

### Phase 1: Extension Metadata Files [NOT STARTED]

**Goal**: Create the extension directory structure and the 3 core metadata files that define the extension.

**Tasks**:
- [ ] Create `.claude/extensions/nix/` directory structure
- [ ] Create `manifest.json` with extension metadata, provides list, merge_targets, and mcp_servers
- [ ] Create `EXTENSION.md` with language routing table, skill-agent mapping, key technologies, and build verification commands
- [ ] Create `index-entries.json` with entries for all 11 context files plus the README

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/nix/manifest.json` - Extension manifest (follow web/ pattern, add mcp_servers like lean/)
- `.claude/extensions/nix/EXTENSION.md` - CLAUDE.md section content for nix routing
- `.claude/extensions/nix/index-entries.json` - Context discovery entries for 11 context files

**Verification**:
- manifest.json is valid JSON with all required fields (name, version, description, language, provides, merge_targets)
- EXTENSION.md has Language Routing and Skill-Agent Mapping sections
- index-entries.json is valid JSON array with entries matching context file count

---

### Phase 2: MCP Settings Fragment [NOT STARTED]

**Goal**: Create the MCP-NixOS server configuration fragment following the lean/ extension pattern.

**Tasks**:
- [ ] Create `settings-fragment.json` with MCP-NixOS server configuration
- [ ] Include permission allowlist for MCP-NixOS tools (`mcp__nixos__nix`, `mcp__nixos__nix_versions`, etc.)
- [ ] Update manifest.json to reference settings merge target

**Timing**: 15 minutes

**Files to create**:
- `.claude/extensions/nix/settings-fragment.json` - MCP server config and permissions

**Source reference**:
- Lean settings-fragment.json pattern: `/home/benjamin/.config/nvim/.claude/extensions/lean/settings-fragment.json`
- Dotfiles agent MCP references: search for `mcp__nixos` in agent files

**Verification**:
- settings-fragment.json is valid JSON
- All MCP tool names referenced in agents are included in permissions
- manifest.json merge_targets includes settings entry

---

### Phase 3: Agents [NOT STARTED]

**Goal**: Adapt the 2 Nix agents from dotfiles to extension format with updated context paths.

**Tasks**:
- [ ] Copy and adapt `nix-research-agent.md` from `/home/benjamin/.dotfiles/.claude/agents/nix-research-agent.md`
- [ ] Copy and adapt `nix-implementation-agent.md` from `/home/benjamin/.dotfiles/.claude/agents/nix-implementation-agent.md`
- [ ] Update all context reference paths from `.claude/context/project/nix/` to `.claude/extensions/nix/context/project/nix/`
- [ ] Update rules reference from `.claude/rules/nix.md` to `.claude/extensions/nix/rules/nix.md`
- [ ] Remove dotfiles-specific references (host names: garuda, nandi, hamsa; user-specific paths; dotfiles flake references)
- [ ] Preserve MCP-NixOS tool references and graceful degradation patterns

**Timing**: 45 minutes

**Files to create**:
- `.claude/extensions/nix/agents/nix-research-agent.md` - Adapted from dotfiles (510 lines source)
- `.claude/extensions/nix/agents/nix-implementation-agent.md` - Adapted from dotfiles (857 lines source)

**Source files**:
- `/home/benjamin/.dotfiles/.claude/agents/nix-research-agent.md`
- `/home/benjamin/.dotfiles/.claude/agents/nix-implementation-agent.md`

**Verification**:
- No references to `.dotfiles` or dotfiles-specific paths remain
- No host-specific names (garuda, nandi, hamsa) remain
- Context paths point to extension directory (`.claude/extensions/nix/...`)
- MCP tool references preserved (`mcp__nixos__nix`, `mcp__nixos__nix_versions`)
- Both agents have proper frontmatter (name, description fields)

---

### Phase 4: Skills [NOT STARTED]

**Goal**: Adapt the 2 Nix skills from dotfiles to extension format.

**Tasks**:
- [ ] Create `skills/skill-nix-research/SKILL.md` adapted from `/home/benjamin/.dotfiles/.claude/skills/skill-nix-research/SKILL.md`
- [ ] Create `skills/skill-nix-implementation/SKILL.md` adapted from `/home/benjamin/.dotfiles/.claude/skills/skill-nix-implementation/SKILL.md`
- [ ] Update agent references to point to extension agent paths
- [ ] Update context references to extension paths
- [ ] Preserve preflight/postflight patterns and completion_data propagation

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/nix/skills/skill-nix-research/SKILL.md` - Research skill wrapper
- `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` - Implementation skill wrapper

**Source files**:
- `/home/benjamin/.dotfiles/.claude/skills/skill-nix-research/SKILL.md`
- `/home/benjamin/.dotfiles/.claude/skills/skill-nix-implementation/SKILL.md`

**Verification**:
- Skills reference correct agent file names
- No dotfiles-specific paths remain
- Preflight status update pattern present
- Postflight marker file creation present
- Implementation skill handles completion_data propagation

---

### Phase 5: Rules and Context Files [NOT STARTED]

**Goal**: Adapt the 1 rule file and 11 context files from dotfiles, removing project-specific content.

**Tasks**:
- [ ] Create `rules/nix.md` adapted from `/home/benjamin/.dotfiles/.claude/rules/nix.md`
- [ ] Create `context/project/nix/README.md` adapted from dotfiles
- [ ] Create `context/project/nix/domain/nix-language.md` - Nix expression syntax
- [ ] Create `context/project/nix/domain/flakes.md` - Flake structure and inputs
- [ ] Create `context/project/nix/domain/nixos-modules.md` - Module system and options
- [ ] Create `context/project/nix/domain/home-manager.md` - User-level configuration
- [ ] Create `context/project/nix/patterns/module-patterns.md` - Module definition patterns
- [ ] Create `context/project/nix/patterns/overlay-patterns.md` - Overlay customization
- [ ] Create `context/project/nix/patterns/derivation-patterns.md` - Package building
- [ ] Create `context/project/nix/standards/nix-style-guide.md` - Formatting and naming
- [ ] Create `context/project/nix/tools/nixos-rebuild-guide.md` - System rebuild workflows
- [ ] Create `context/project/nix/tools/home-manager-guide.md` - Home Manager workflows
- [ ] Remove dotfiles-specific host names, user paths, and flake references from all files
- [ ] Generalize examples to be project-agnostic

**Timing**: 45 minutes

**Files to create**:
- `.claude/extensions/nix/rules/nix.md` - Nix development rules (path: `**/*.nix`)
- `.claude/extensions/nix/context/project/nix/README.md` - Context overview
- `.claude/extensions/nix/context/project/nix/domain/nix-language.md`
- `.claude/extensions/nix/context/project/nix/domain/flakes.md`
- `.claude/extensions/nix/context/project/nix/domain/nixos-modules.md`
- `.claude/extensions/nix/context/project/nix/domain/home-manager.md`
- `.claude/extensions/nix/context/project/nix/patterns/module-patterns.md`
- `.claude/extensions/nix/context/project/nix/patterns/overlay-patterns.md`
- `.claude/extensions/nix/context/project/nix/patterns/derivation-patterns.md`
- `.claude/extensions/nix/context/project/nix/standards/nix-style-guide.md`
- `.claude/extensions/nix/context/project/nix/tools/nixos-rebuild-guide.md`
- `.claude/extensions/nix/context/project/nix/tools/home-manager-guide.md`

**Source directory**: `/home/benjamin/.dotfiles/.claude/context/project/nix/`
**Source rule**: `/home/benjamin/.dotfiles/.claude/rules/nix.md`

**Verification**:
- All 12 files created (1 rule + 11 context)
- No dotfiles-specific host names or paths remain
- Rule file has proper frontmatter with paths field
- Context README describes the directory structure accurately
- All context files have substantive content (not just stubs)

---

### Phase 6: Verification and Consistency Check [NOT STARTED]

**Goal**: Verify the complete extension is internally consistent and follows established patterns.

**Tasks**:
- [ ] Verify all files listed in manifest.json `provides` actually exist
- [ ] Verify all paths in index-entries.json point to existing files
- [ ] Verify no dotfiles-specific references remain (grep for `.dotfiles`, `garuda`, `nandi`, `hamsa`, `/home/benjamin`)
- [ ] Verify context paths in agents and skills point to extension directory
- [ ] Verify manifest.json merge_targets reference existing source files
- [ ] Verify settings-fragment.json MCP permissions match agent MCP tool references
- [ ] Count total files and compare to research estimate (expected: ~20 files)
- [ ] Spot-check 2-3 files for content quality and formatting

**Timing**: 15 minutes

**Files to verify** (no new files):
- All files created in Phases 1-5

**Verification**:
- Zero grep hits for dotfiles-specific terms
- File count matches expectation (~20 files total)
- manifest.json provides arrays match actual directory contents
- index-entries.json entry count matches context file count (11 + README = 12 entries)
- All JSON files parse without errors

## Testing & Validation

- [ ] All JSON files (manifest.json, index-entries.json, settings-fragment.json) are valid JSON
- [ ] No dotfiles-specific references remain in any extension file
- [ ] Context paths in agents/skills point to `.claude/extensions/nix/` prefix
- [ ] Rule file frontmatter has valid paths field
- [ ] manifest.json provides counts match: 2 agents, 2 skills, 0 commands, 1 rule, 1 context dir
- [ ] Total file count: ~20 files (4 metadata + 2 agents + 2 skills + 1 rule + 11 context)
- [ ] Extension structure mirrors web/ extension organization (no extra directories)

## Artifacts & Outputs

- `.claude/extensions/nix/` - Complete Nix extension directory (~20 files)
- `manifest.json` - Extension manifest with MCP-NixOS integration
- `EXTENSION.md` - CLAUDE.md section for nix language routing
- `index-entries.json` - Context discovery entries (12 entries)
- `settings-fragment.json` - MCP-NixOS server and permissions config
- 2 agent files, 2 skill files, 1 rule file, 11 context files

## Rollback/Contingency

To revert if implementation fails:
```bash
# Remove the entire nix extension directory
rm -rf .claude/extensions/nix/
# No core files are modified - the extension is self-contained
```

The nix extension is completely self-contained in `.claude/extensions/nix/`. No core system files (CLAUDE.md, index.json, settings.json) are directly modified during implementation. Integration happens via merge_targets at activation time, so removal is trivial.
