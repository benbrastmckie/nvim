# Implementation Plan: Task #101

- **Task**: 101 - Add contents to language extensions
- **Status**: [COMPLETED]
- **Effort**: 4-6 hours
- **Dependencies**: Task #99 (extension system infrastructure - COMPLETED)
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-01
- **Feature**: Add language-specific content (agents, skills, rules, context) to lean, latex, z3, typst, and python extensions
- **Estimated Hours**: 4-6 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md

## Overview

Populate five language extensions with content sourced from three reference projects (ProofChecker, Logos/Theory, ModelChecker). Each extension needs agents, skills, rules (where applicable), and context files. Two extensions (lean, latex) already have skeleton directories that need content. Three extensions (z3, typst, python) need to be created from scratch including manifest files and all subdirectories.

### Research Integration

Research identified exact file counts and source locations for all five extensions. Key findings:
- Lean is the most comprehensive extension (~48 files including math/logic context)
- LaTeX, typst, z3, and python each have 9-14 files
- Agent files should be copied as-is (they serve as templates)
- Project-specific content (logos-macros, model-checker-api, dtt-foundation-standard) should be excluded
- Total estimated files: ~93

## Goals & Non-Goals

**Goals**:
- Populate lean extension with agents, skills, commands, rules, context, and scripts from ProofChecker
- Populate latex extension with agents, skills, rules, and context from ProofChecker
- Create typst extension with full content from Logos/Theory
- Create z3 extension with full content from ModelChecker
- Create python extension with full content from ModelChecker
- Follow the established extension file structure pattern (manifest.json, claudemd-section.md, index-entries.json)

**Non-Goals**:
- Modifying the extension picker or installation system (task 100)
- Creating hooks or scripts for z3, typst, or python (none identified in research)
- Including project-specific content (logos-macros, dtt-foundation, model-checker-api)
- Customizing agent files to remove project-specific references (they serve as templates)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent files contain project-specific paths | M | H | Document as templates; users customize after install |
| Context files too project-specific | M | M | Curate carefully; exclude logos-specific, modelchecker-specific content |
| Large file count (~93) makes review difficult | L | H | Phase by extension; verify each independently |
| Reference project files may have changed since research | L | L | Use latest versions; validate files exist before copy |
| Skill wrapper format may differ between projects | M | L | Normalize to consistent thin-wrapper pattern |

## Implementation Phases

### Phase 1: Create New Extension Scaffolds (z3, typst, python) [COMPLETED]

**Goal**: Create the three missing extension directories with manifest files and skeleton structure matching the established pattern from lean/latex/neovim.

**Tasks**:
- [ ] Create `extensions/z3/` directory with subdirectories (agents/, skills/, context/)
- [ ] Create `extensions/z3/manifest.json` based on research manifest template
- [ ] Create `extensions/z3/claudemd-section.md` following lean/latex pattern
- [ ] Create `extensions/z3/index-entries.json` with z3 context entries
- [ ] Create `extensions/typst/` directory with subdirectories (agents/, skills/, context/)
- [ ] Create `extensions/typst/manifest.json` based on research manifest template
- [ ] Create `extensions/typst/claudemd-section.md` following lean/latex pattern
- [ ] Create `extensions/typst/index-entries.json` with typst context entries
- [ ] Create `extensions/python/` directory with subdirectories (agents/, skills/, context/)
- [ ] Create `extensions/python/manifest.json` based on research manifest template
- [ ] Create `extensions/python/claudemd-section.md` following lean/latex pattern
- [ ] Create `extensions/python/index-entries.json` with python context entries

**Timing**: 0.5-1 hour

**Files to create**:
- `.claude/extensions/z3/manifest.json` - Extension metadata
- `.claude/extensions/z3/claudemd-section.md` - CLAUDE.md injection section
- `.claude/extensions/z3/index-entries.json` - Context index entries
- `.claude/extensions/typst/manifest.json` - Extension metadata
- `.claude/extensions/typst/claudemd-section.md` - CLAUDE.md injection section
- `.claude/extensions/typst/index-entries.json` - Context index entries
- `.claude/extensions/python/manifest.json` - Extension metadata
- `.claude/extensions/python/claudemd-section.md` - CLAUDE.md injection section
- `.claude/extensions/python/index-entries.json` - Context index entries

**Verification**:
- All three new extension directories exist with correct structure
- manifest.json files validate as proper JSON with all required fields
- claudemd-section.md files follow the established section pattern
- index-entries.json files have valid entry structure

---

### Phase 2: Populate Lean Extension Content [COMPLETED]

**Goal**: Fill the lean extension's empty subdirectories with content sourced from ProofChecker. This is the largest extension with agents, skills, commands, rules, context, and scripts.

**Tasks**:
- [ ] Copy `lean-research-agent.md` from ProofChecker agents/ to extensions/lean/agents/
- [ ] Copy `lean-implementation-agent.md` from ProofChecker agents/ to extensions/lean/agents/
- [ ] Copy `skill-lean-research/SKILL.md` from ProofChecker skills/ to extensions/lean/skills/
- [ ] Copy `skill-lean-implementation/SKILL.md` from ProofChecker skills/ to extensions/lean/skills/
- [ ] Copy `skill-lake-repair/SKILL.md` from ProofChecker skills/ to extensions/lean/skills/
- [ ] Copy `skill-lean-version/SKILL.md` from ProofChecker skills/ to extensions/lean/skills/
- [ ] Copy `lake.md` command from ProofChecker commands/ to extensions/lean/commands/
- [ ] Copy `lean.md` command from ProofChecker commands/ to extensions/lean/commands/
- [ ] Copy `lean4.md` rule from ProofChecker rules/ to extensions/lean/rules/
- [ ] Copy lean4 context directory from ProofChecker context/project/lean4/ to extensions/lean/context/project/lean4/
- [ ] Copy math context directory from ProofChecker context/project/math/ to extensions/lean/context/project/math/
- [ ] Copy logic context directory from ProofChecker context/project/logic/ to extensions/lean/context/project/logic/
- [ ] Copy `setup-lean-mcp.sh` from ProofChecker scripts/ to extensions/lean/scripts/
- [ ] Copy `verify-lean-mcp.sh` from ProofChecker scripts/ to extensions/lean/scripts/
- [ ] Update lean manifest.json provides section if needed to reflect actual content

**Timing**: 1-1.5 hours

**Source directory**: `/home/benjamin/Projects/ProofChecker/.claude/`

**Files to create/modify**:
- `.claude/extensions/lean/agents/lean-research-agent.md` - Research agent
- `.claude/extensions/lean/agents/lean-implementation-agent.md` - Implementation agent
- `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` - Research skill
- `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` - Implementation skill
- `.claude/extensions/lean/skills/skill-lake-repair/SKILL.md` - Lake repair skill
- `.claude/extensions/lean/skills/skill-lean-version/SKILL.md` - Version management skill
- `.claude/extensions/lean/commands/lake.md` - Lake command
- `.claude/extensions/lean/commands/lean.md` - Lean command
- `.claude/extensions/lean/rules/lean4.md` - Lean 4 rules
- `.claude/extensions/lean/context/project/lean4/**` - Lean 4 context (~17 files)
- `.claude/extensions/lean/context/project/math/**` - Math context (~7 files)
- `.claude/extensions/lean/context/project/logic/**` - Logic context (~13 files)
- `.claude/extensions/lean/scripts/setup-lean-mcp.sh` - MCP setup
- `.claude/extensions/lean/scripts/verify-lean-mcp.sh` - MCP verification

**Verification**:
- All agent files exist and are non-empty
- All skill directories contain SKILL.md files
- Command files exist in commands/ directory
- Rules file exists in rules/ directory
- Context directory tree has proper structure with README.md files
- Scripts are executable
- File count matches research estimate (~48)

---

### Phase 3: Populate LaTeX Extension Content [COMPLETED]

**Goal**: Fill the latex extension's empty subdirectories with agents, skills, rules, and context sourced from ProofChecker (and vetted against Logos/Theory).

**Tasks**:
- [ ] Copy `latex-implementation-agent.md` from ProofChecker agents/ to extensions/latex/agents/
- [ ] Check if `latex-research-agent.md` exists in ProofChecker and copy if found
- [ ] Copy `skill-latex-implementation/SKILL.md` from ProofChecker skills/ to extensions/latex/skills/
- [ ] Check if `skill-latex-research/` exists and copy if found
- [ ] Copy `latex.md` rule from ProofChecker rules/ to extensions/latex/rules/ (create rules/ dir)
- [ ] Copy latex context from ProofChecker context/project/latex/ to extensions/latex/context/project/latex/
- [ ] Exclude project-specific files (logos-macros.md) from context
- [ ] Update latex manifest.json provides section to reflect actual content (add rules, research agent if present)

**Timing**: 0.5-1 hour

**Source directory**: `/home/benjamin/Projects/ProofChecker/.claude/`

**Files to create/modify**:
- `.claude/extensions/latex/agents/latex-implementation-agent.md` - Implementation agent
- `.claude/extensions/latex/agents/latex-research-agent.md` - Research agent (if exists)
- `.claude/extensions/latex/skills/skill-latex-implementation/SKILL.md` - Implementation skill
- `.claude/extensions/latex/skills/skill-latex-research/SKILL.md` - Research skill (if exists)
- `.claude/extensions/latex/rules/latex.md` - LaTeX rules
- `.claude/extensions/latex/context/project/latex/**` - LaTeX context (~8 files)
- `.claude/extensions/latex/manifest.json` - Update provides section

**Verification**:
- Agent files exist and are non-empty
- Skill directories contain SKILL.md files
- Rules file exists
- Context files are present (excluding project-specific content)
- manifest.json provides section matches actual contents
- File count matches research estimate (~13)

---

### Phase 4: Populate Typst Extension Content [COMPLETED]

**Goal**: Fill the new typst extension with agents, skills, and context sourced from Logos/Theory. Create a typst development rules file since none exists in the source project.

**Tasks**:
- [ ] Copy `typst-implementation-agent.md` from Logos/Theory agents/ to extensions/typst/agents/
- [ ] Copy `typst-research-agent.md` from Logos/Theory agents/ to extensions/typst/agents/
- [ ] Copy `skill-typst-implementation/SKILL.md` from Logos/Theory skills/ to extensions/typst/skills/
- [ ] Copy `skill-typst-research/SKILL.md` from Logos/Theory skills/ to extensions/typst/skills/
- [ ] Copy typst context from Logos/Theory context/project/typst/ to extensions/typst/context/project/typst/
- [ ] Exclude project-specific context files (textbook-standards.md, dtt-foundation-standard.md)
- [ ] Verify manifest.json provides section matches actual content

**Timing**: 0.5-1 hour

**Source directory**: `/home/benjamin/Projects/Logos/Theory/.claude/`

**Files to create/modify**:
- `.claude/extensions/typst/agents/typst-implementation-agent.md` - Implementation agent
- `.claude/extensions/typst/agents/typst-research-agent.md` - Research agent
- `.claude/extensions/typst/skills/skill-typst-implementation/SKILL.md` - Implementation skill
- `.claude/extensions/typst/skills/skill-typst-research/SKILL.md` - Research skill
- `.claude/extensions/typst/context/project/typst/**` - Typst context (~10 files)

**Verification**:
- Agent files exist and are non-empty
- Skill directories contain SKILL.md files
- Context files are present (excluding project-specific content)
- manifest.json provides section matches actual contents
- File count matches research estimate (~14)

---

### Phase 5: Populate Z3 Extension Content [COMPLETED]

**Goal**: Fill the new z3 extension with agents, skills, and context sourced from ModelChecker.

**Tasks**:
- [ ] Copy `z3-research-agent.md` from ModelChecker agents/ to extensions/z3/agents/
- [ ] Copy `z3-implementation-agent.md` from ModelChecker agents/ to extensions/z3/agents/
- [ ] Copy `skill-z3-research/SKILL.md` from ModelChecker skills/ to extensions/z3/skills/
- [ ] Copy `skill-z3-implementation/SKILL.md` from ModelChecker skills/ to extensions/z3/skills/
- [ ] Copy z3 context from ModelChecker context/project/z3/ to extensions/z3/context/project/z3/
- [ ] Verify manifest.json provides section matches actual content

**Timing**: 0.5 hour

**Source directory**: `/home/benjamin/Projects/ModelChecker/.claude/`

**Files to create/modify**:
- `.claude/extensions/z3/agents/z3-research-agent.md` - Research agent
- `.claude/extensions/z3/agents/z3-implementation-agent.md` - Implementation agent
- `.claude/extensions/z3/skills/skill-z3-research/SKILL.md` - Research skill
- `.claude/extensions/z3/skills/skill-z3-implementation/SKILL.md` - Implementation skill
- `.claude/extensions/z3/context/project/z3/**` - Z3 context (~5 files)

**Verification**:
- Agent files exist and are non-empty
- Skill directories contain SKILL.md files
- Context files are present
- manifest.json provides section matches actual contents
- File count matches research estimate (~9)

---

### Phase 6: Populate Python Extension Content and Final Validation [COMPLETED]

**Goal**: Fill the new python extension with agents, skills, and context sourced from ModelChecker. Then perform cross-extension validation to ensure consistency.

**Tasks**:
- [ ] Copy `python-research-agent.md` from ModelChecker agents/ to extensions/python/agents/
- [ ] Copy `python-implementation-agent.md` from ModelChecker agents/ to extensions/python/agents/
- [ ] Copy `skill-python-research/SKILL.md` from ModelChecker skills/ to extensions/python/skills/
- [ ] Copy `skill-python-implementation/SKILL.md` from ModelChecker skills/ to extensions/python/skills/
- [ ] Copy python context from ModelChecker context/project/python/ to extensions/python/context/project/python/
- [ ] Exclude project-specific context (model-checker-api.md) from python context
- [ ] Verify manifest.json provides section matches actual content

**Cross-extension validation**:
- [ ] Verify all 8 extensions (neovim + 5 new/updated + lean + latex) have consistent manifest structure
- [ ] Verify all manifest.json `provides` sections match actual directory contents
- [ ] Verify all claudemd-section.md files follow the established pattern
- [ ] Verify all index-entries.json files have valid structure
- [ ] Count total files across all extensions and compare against research estimate (~93)
- [ ] Verify no project-specific content leaked into extensions

**Timing**: 0.5-1 hour

**Source directory**: `/home/benjamin/Projects/ModelChecker/.claude/`

**Files to create/modify**:
- `.claude/extensions/python/agents/python-research-agent.md` - Research agent
- `.claude/extensions/python/agents/python-implementation-agent.md` - Implementation agent
- `.claude/extensions/python/skills/skill-python-research/SKILL.md` - Research skill
- `.claude/extensions/python/skills/skill-python-implementation/SKILL.md` - Implementation skill
- `.claude/extensions/python/context/project/python/**` - Python context (~5 files)

**Verification**:
- Python extension: agent and skill files exist, context present, manifest accurate
- Cross-extension: all 8 extensions have consistent structure
- Total file count is within 10% of research estimate (~93)
- No project-specific content present in any extension

## Testing & Validation

- [ ] All manifest.json files parse as valid JSON
- [ ] All index-entries.json files parse as valid JSON
- [ ] Every `provides` field in manifests matches actual directory contents
- [ ] No empty subdirectories remain in populated extensions
- [ ] No project-specific files (logos-macros, dtt-foundation, model-checker-api) are included
- [ ] All agent .md files are non-empty and have proper frontmatter
- [ ] All SKILL.md files follow thin-wrapper pattern
- [ ] Context directory trees have README.md files at each level
- [ ] Total extension file count is approximately 93

## Artifacts & Outputs

- 5 populated language extensions (lean, latex, z3, typst, python)
- 3 new extension scaffolds with complete manifest files (z3, typst, python)
- ~93 content files across all extensions
- Updated manifests for lean and latex extensions

## Rollback/Contingency

All changes are within `.claude/extensions/` directory. Since extensions are isolated from the main .claude/ configuration:
- **Per-extension rollback**: Delete the extension directory and recreate from the skeleton
- **Full rollback**: `git checkout -- .claude/extensions/` restores to pre-implementation state
- **Partial completion**: Each phase produces a complete, independently functional extension
