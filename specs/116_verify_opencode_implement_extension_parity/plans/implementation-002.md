# Implementation Plan: Task #116 (Revised)

- **Task**: 116 - Verify OpenCode & Implement Extension Parity
- **Status**: [NOT STARTED]
- **Version**: 002
- **Revised**: 2026-03-03
- **Effort**: 5-7 hours (reduced due to category-based approach)
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md), [research-002.md](../reports/research-002.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This revised plan incorporates findings from supplementary research (research-002.md) that analyzed three other .opencode/ systems (Logos/Theory, ProofChecker, dotfiles). Key insight: **the extension pattern is unique to nvim** - other systems embed components directly in core. This means all 7 missing extensions must be created by adapting .claude/ counterparts using mechanical translation.

The plan now uses a **category-based approach** for efficiency:
- **Category A** (latex, typst): Components already in core, just need extension packaging
- **Category B** (web): Partial in core, needs completion + packaging
- **Category C** (document-converter, nix, python, z3): Missing entirely, full creation from .claude/

### Research Integration

**From research-001.md**:
- Formal extension missing 3 agents, 3 skills, 41 context files
- Lean extension missing 2 skills, 27 context files, scripts, settings-fragment
- 7 .claude extensions with no .opencode equivalent

**From research-002.md**:
- No other .opencode/ systems use extensions/ pattern - must adapt from .claude/
- Mechanical translation pattern: path prefixes, manifest rekey, frontmatter additions
- Category-based approach reduces effort: start with already-in-core components
- Agent frontmatter needs: mode, temperature, tools, permissions blocks

## Goals & Non-Goals

**Goals**:
- Complete formal and lean extensions to match .claude/ counterparts
- Create 7 new .opencode extensions using mechanical translation from .claude/
- Follow category-based order: A (packaging) -> C (full creation) -> B (completion)
- Validate extension structure pattern before tackling harder categories

**Non-Goals**:
- Removing baked-in content from .opencode base (separate cleanup task)
- Creating new content not in .claude extensions
- Modifying .claude extensions themselves

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path mismatch after translation | M | M | Validate all @-references resolve after each extension |
| Agent frontmatter missing fields | M | L | Use lean extension agents as template for frontmatter structure |
| Context duplication (core vs extension) | L | M | Reference core context via relative paths, do not duplicate |
| Empty index-entries.json | L | M | Populate with actual context file entries |

## Implementation Phases

### Phase 1: Complete Formal Extension [NOT STARTED]

**Goal**: Bring .opencode/extensions/formal/ to full parity with .claude/extensions/formal/ (48 files total).

**Tasks**:
- [ ] Add 3 missing agents: logic-research-agent.md, math-research-agent.md, physics-research-agent.md
- [ ] Add 3 missing skills: skill-logic-research/, skill-math-research/, skill-physics-research/
- [ ] Create context directories: logic/ (18 files), math/ (14 files), physics/ (2 files)
- [ ] Populate index-entries.json with all entries (adjust paths to .opencode/)
- [ ] Update manifest.json and EXTENSION.md

**Mechanical Translation**:
```bash
# For each agent, apply:
sed -i 's|\.claude/|.opencode/|g' agent.md
sed -i 's|@\.claude/|@.opencode/|g' agent.md
# Add frontmatter if missing: mode: subagent, temperature: 0.2
```

**Timing**: 1.5 hours

**Verification**:
- File count matches .claude/extensions/formal/ (48 files)
- All @-references resolve to existing .opencode/ paths
- index-entries.json uses .opencode/ paths

---

### Phase 2: Complete Lean Extension [NOT STARTED]

**Goal**: Bring .opencode/extensions/lean/ to full parity with .claude/extensions/lean/ (38 files total).

**Tasks**:
- [ ] Add 2 missing skills: skill-lake-repair/SKILL.md, skill-lean-version/SKILL.md
- [ ] Create context/project/lean4/ with all 27 files
- [ ] Add scripts: setup-lean-mcp.sh, verify-lean-mcp.sh
- [ ] Add settings-fragment.json for lean-lsp MCP server
- [ ] Populate index-entries.json
- [ ] Update manifest.json and EXTENSION.md

**Timing**: 1 hour

**Verification**:
- File count matches .claude/extensions/lean/ (38 files)
- Scripts reference .opencode/ paths
- settings-fragment.json has valid MCP server config

---

### Phase 3: Category A - Package Existing Core Components (latex, typst) [NOT STARTED]

**Goal**: Create extension packages for components already in .opencode/agent/subagents/ and .opencode/skills/.

**Rationale**: These components exist in core, so we only need manifest.json, EXTENSION.md, and index-entries.json. This validates the extension structure pattern before tackling harder categories.

**Tasks**:

**latex extension** (reference existing core components):
- [ ] Create .opencode/extensions/latex/ directory structure
- [ ] Create manifest.json with opencode_md merge target
- [ ] Create EXTENSION.md with section_id: extension_oc_latex
- [ ] Create index-entries.json referencing .opencode/context/project/latex/ files
- [ ] Reference agents from .opencode/agent/subagents/latex-*.md
- [ ] Reference skills from .opencode/skills/skill-latex-*/

**typst extension** (reference existing core components):
- [ ] Create .opencode/extensions/typst/ directory structure
- [ ] Create manifest.json with opencode_md merge target
- [ ] Create EXTENSION.md with section_id: extension_oc_typst
- [ ] Create index-entries.json referencing .opencode/context/project/typst/ files
- [ ] Reference agents from .opencode/agent/subagents/typst-*.md
- [ ] Reference skills from .opencode/skills/skill-typst-*/

**Timing**: 30 minutes (15 min each)

**Verification**:
- Each extension has valid manifest.json with opencode_md merge target
- EXTENSION.md has correct section_id format
- References point to existing core components

---

### Phase 4: Category C - Full Creation (document-converter, nix, python, z3) [NOT STARTED]

**Goal**: Create 4 new .opencode extensions by adapting .claude/ counterparts using mechanical translation.

**Mechanical Translation Pattern**:
```bash
# 1. Copy extension directory
cp -r .claude/extensions/{name}/ .opencode/extensions/{name}/

# 2. Global path substitution
find .opencode/extensions/{name}/ -type f -exec sed -i 's|\.claude/|.opencode/|g' {} \;
find .opencode/extensions/{name}/ -type f -exec sed -i 's|@\.claude/|@.opencode/|g' {} \;

# 3. Rekey manifest.json merge_targets
jq '.merge_targets = {opencode_md: .merge_targets.claudemd | .target = ".opencode/OPENCODE.md" | .section_id = "extension_oc_{name}"}' manifest.json

# 4. Add agent frontmatter (mode, temperature, tools, permissions)
```

**Tasks**:

**document-converter** (6 files):
- [ ] Copy and translate from .claude/extensions/document-converter/
- [ ] Verify agent has proper frontmatter

**nix** (20 files):
- [ ] Copy and translate from .claude/extensions/nix/
- [ ] Include settings-fragment.json with mcp-nixos config
- [ ] Verify all 11 context files transferred

**python** (13 files):
- [ ] Copy and translate from .claude/extensions/python/
- [ ] Verify 2 agents, 2 skills, 6 context files

**z3** (12 files):
- [ ] Copy and translate from .claude/extensions/z3/
- [ ] Verify 2 agents, 2 skills, 4 context files

**Timing**: 2 hours (30 min each)

**Verification**:
- Zero .claude/ path references in translated files
- All manifest.json files use opencode_md merge target
- All agents have mode/temperature/tools/permissions frontmatter

---

### Phase 5: Category B - Complete Web Extension [NOT STARTED]

**Goal**: Create web extension by completing missing components and packaging.

**Current State**: Context exists at .opencode/context/project/web/, but missing agents and skills.

**Tasks**:
- [ ] Copy and translate web-research-agent.md from .claude/
- [ ] Copy and translate web-implementation-agent.md from .claude/
- [ ] Copy and translate skill-web-research/ from .claude/
- [ ] Copy and translate skill-web-implementation/ from .claude/
- [ ] Copy and translate rule web.md from .claude/
- [ ] Create manifest.json with opencode_md merge target
- [ ] Create EXTENSION.md with section_id: extension_oc_web
- [ ] Create index-entries.json referencing existing core context

**Timing**: 45 minutes

**Verification**:
- web extension has 2 agents, 2 skills, 1 rule
- Context references point to .opencode/context/project/web/
- All translated files have no .claude/ references

---

### Phase 6: Verification and Validation [NOT STARTED]

**Goal**: Validate all 9 extensions are correct and ready for use.

**Tasks**:
- [ ] Run file count comparison for all 9 extensions
- [ ] Validate all manifest.json files parse correctly
- [ ] Validate all index-entries.json files use .opencode/ paths
- [ ] Grep for any remaining .claude/ references: `grep -r "\.claude/" .opencode/extensions/`
- [ ] Verify all @-references resolve: check each SKILL.md and agent file
- [ ] Create overlap summary (extensions vs baked-in core) for future cleanup

**Timing**: 30 minutes

**Verification**:
- All 9 extensions have matching file counts vs .claude counterparts
- Zero .claude/ references in .opencode/extensions/
- All JSON files parse without errors

## Testing & Validation

- [ ] Each extension has correct file count
- [ ] All manifest.json files have opencode_md merge target
- [ ] All index-entries.json files use .opencode/ paths
- [ ] All EXTENSION.md files use section_id format extension_oc_{name}
- [ ] No .opencode extension file contains .claude/ path reference
- [ ] All agents have mode/temperature/tools/permissions frontmatter

## Artifacts & Outputs

- `.opencode/extensions/formal/` - completed (48 files)
- `.opencode/extensions/lean/` - completed (38 files)
- `.opencode/extensions/latex/` - new (packaging only)
- `.opencode/extensions/typst/` - new (packaging only)
- `.opencode/extensions/document-converter/` - new (6 files)
- `.opencode/extensions/nix/` - new (20 files)
- `.opencode/extensions/python/` - new (13 files)
- `.opencode/extensions/z3/` - new (12 files)
- `.opencode/extensions/web/` - new (28 files)
- Total: ~202 files across 9 extensions

## Rollback/Contingency

- All changes are additive (new files) with minimal modifications to existing files
- Each extension is self-contained and can be removed independently if needed
- Git history preserves all states for rollback if required

## Key Changes from v001

1. **Category-based ordering**: A -> C -> B instead of completion-first approach
2. **Mechanical translation pattern**: Documented sed/jq commands for batch processing
3. **Agent frontmatter requirements**: Explicit mode/temperature/tools/permissions blocks
4. **Reduced time estimate**: 5-7 hours (down from 6-8) due to efficient batching
5. **Validation focus**: Grep for .claude/ references as primary correctness check
