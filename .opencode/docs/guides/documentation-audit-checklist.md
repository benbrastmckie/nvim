# Documentation Audit Checklist

**Version**: 1.0  
**Created**: Task 179 - Documentation Review  
**Purpose**: Comprehensive checklist for auditing .opencode/ documentation quality

---

## How to Use This Checklist

1. **Monthly audits**: Review all items, mark status
2. **After major changes**: Check affected sections
3. **Before releases**: Complete full checklist
4. **Track trends**: Watch for recurring issues

**Status Markers**:
- [ ] Not checked / Issue found
- [x] Verified / No issues
- [~] Partial / Needs attention

---

## Critical Issues (Breaks Functionality)

### 1. Path References

**Issue**: References to `.opencode_NEW` instead of `.opencode`

- [ ] Run: `grep -r "\.opencode_NEW" .opencode/ --include="*.md"`
- [ ] Expected: 0 matches
- [ ] If found: Replace all with `.opencode`

**Files to check**:
- All SKILL.md files
- All agent files
- All command files
- All context files
- All documentation files

---

### 2. Directory Names

**Issue**: References to `command/` instead of `commands/`

- [ ] Run: `grep -r "command/" .opencode/ --include="*.md" | grep -v "commands/"`
- [ ] Expected: 0 matches (except valid uses like "command/function")
- [ ] If found: Update to `commands/`

**Key files**:
- `.opencode/README.md`
- `.opencode/context/project/repo/project-overview.md`
- `.opencode/context/project/meta/meta-guide.md`
- `.opencode/agent/subagents/meta-builder-agent.md`

---

### 3. Non-existent Commands

**Issue**: Documentation references commands that don't exist

**Check QUICK-START.md**:
- [ ] Verify all listed commands exist in `.opencode/commands/`
- [ ] Valid commands: `/task`, `/research`, `/plan`, `/implement`, `/todo`, `/lake`, `/lean`, `/meta`, `/convert`, `/errors`, `/fix-it`, `/refresh`, `/review`, `/revise`
- [ ] If invalid commands found: Remove or add deprecation notice

**Check user guides**:
- [ ] All command examples use existing commands
- [ ] All `--help` references work

---

### 4. Blocked Tools Contradiction

**Issue**: Blocked tools listed as essential

**Check `.opencode/rules/lean4.md`**:
- [ ] `lean_diagnostic_messages` NOT in Essential Tools list
- [ ] `lean_diagnostic_messages` NOT in workflow examples
- [ ] Correct alternative (`lake build`) is documented

**Check other rules files**:
- [ ] No blocked tools in essential lists
- [ ] Blocked tools properly documented in blocked-mcp-tools.md

---

## Major Issues (Causes Confusion)

### 5. Project Name Consistency

**Issue**: Mixed "ProofChecker" and "Logos/Theory" naming

- [ ] Run: `grep -r "ProofChecker" .opencode/ --include="*.md" | grep -v "historical"`
- [ ] Expected: 0 matches (except intentional historical references)
- [ ] If found: Replace with "Logos/Theory"

**Key files**:
- `.opencode/README.md`
- `.opencode/commands/README.md`
- `.opencode/context/README.md`
- All project context files

**Exception**: Keep "ProofChecker" in historical context:
- `.opencode/context/project/repo/project-overview.md` line 9

---

### 6. Architecture Documentation

**Issue**: References to non-existent ARCHITECTURE.md

- [ ] Run: `grep -r "ARCHITECTURE\.md" .opencode/ --include="*.md"`
- [ ] Expected: 0 matches
- [ ] If found: Update to `.opencode/docs/architecture/system-overview.md`

**Files that may need fixing**:
- `.opencode/context/project/repo/project-overview.md`
- `.opencode/context/project/meta/meta-guide.md`
- `.opencode/QUICK-START.md`

---

### 7. Component Inventory

**Issue**: Wrong counts for commands, skills, agents

**Count actual files**:
- [ ] Commands: `ls .opencode/commands/*.md | wc -l` (should be 15)
- [ ] Skills: `find .opencode/skills -name "SKILL.md" | wc -l` (should be 20)
- [ ] Agents: `ls .opencode/agent/subagents/*.md | wc -l` (should be 14, or 15 including README)

**Update inventory in**:
- [ ] `.opencode/docs/guides/component-selection.md`
- [ ] `.opencode/README.md` Skill-to-Agent mapping

---

### 8. Orchestrator Frontmatter

**Issue**: Wrong name field in orchestrator.md

- [ ] Check `.opencode/agent/orchestrator.md` line 2
- [ ] Expected: `name: orchestrator`
- [ ] Not: `name: chat`

---

### 9. Architecture Diagram

**Issue**: Wrong delegation flow in subagents README

- [ ] Check `.opencode/agent/subagents/README.md`
- [ ] Verify three-layer architecture:
  ```
  Layer 1: Orchestrator
    |
    v
  Layer 2: Commands
    |
    v
  Layer 3: Subagents
  ```
- [ ] Ensure no mention of Skills layer in diagram (skills are routing, not execution)

---

## Minor Issues (Style & Polish)

### 10. Capitalization

**Issue**: Inconsistent "Lean 4" vs "LEAN 4"

- [ ] Run: `grep -r "LEAN 4" .opencode/ --include="*.md" | grep -v "code block"`
- [ ] Expected: 0 matches
- [ ] If found: Replace with "Lean 4" (except in code blocks where appropriate)

**Key files to check**:
- `.opencode/QUICK-START.md`
- `.opencode/rules/lean4.md`
- Any Lean 4 guides

---

### 11. Emojis

**Issue**: Emojis in formal documentation

- [ ] Run: `grep -E "[🚀⚡🎯✨🔧📊💡📝🔍⚠️✅❌]" .opencode/ --include="*.md" -r`
- [ ] Expected: 0 matches
- [ ] If found: Remove emojis, replace with text

**Key files**:
- `.opencode/QUICK-START.md` (most likely)
- Any user-facing guides

---

### 12. File Path Format

**Issue**: Inconsistent task number formatting

- [ ] Run: `grep -r "OC_[0-9][0-9]" .opencode/ --include="*.md" | grep -v "OC_NNN" | grep -v "OC_001"`
- [ ] Check for 1-2 digit references in directory paths
- [ ] Expected: Directories use `OC_NNN` (3-digit padded)
- [ ] Text can use `OC_N` (unpadded)

**Examples**:
- ✅ Directory: `specs/OC_017_slug/`
- ✅ Text: `task OC_17`
- ❌ Directory: `specs/OC_17_slug/`

---

## Maintenance Infrastructure

### 13. Documentation Maintenance Guide

- [ ] File exists: `.opencode/docs/guides/documentation-maintenance.md`
- [ ] Covers all critical and major issues
- [ ] Includes fix procedures
- [ ] Up to date with current standards

---

### 14. Audit Checklist

- [ ] File exists: `.opencode/docs/guides/documentation-audit-checklist.md` (this file)
- [ ] Covers all 18 issues from Task 179 research
- [ ] Status tracking is current
- [ ] Checklist is complete (all 18 items)

---

### 15. Validation Script

- [ ] Script exists: `.opencode/scripts/validate-docs.sh`
- [ ] Script runs without errors: `bash .opencode/scripts/validate-docs.sh`
- [ ] Checks for:
  - [ ] `.opencode_NEW` references
  - [ ] `command/` references
  - [ ] Non-existent commands
  - [ ] Blocked tools in essential lists
  - [ ] "ProofChecker" references (excluding historical)
  - [ ] ARCHITECTURE.md references
  - [ ] Component count mismatches
  - [ ] Orchestrator name field
  - [ ] "LEAN 4" capitalization
  - [ ] Emoji presence

---

## Summary

### Audit Results

**Date**: ___________  
**Auditor**: ___________

| Category | Items | Passed | Failed | Notes |
|----------|-------|--------|--------|-------|
| Critical | 4 | | | |
| Major | 5 | | | |
| Minor | 3 | | | |
| Infrastructure | 3 | | | |
| **Total** | **15** | | | |

### Action Items

| Priority | Issue | Action | Owner | Due |
|----------|-------|--------|-------|-----|
| | | | | |
| | | | | |
| | | | | |

---

## References

- **Task 179 Research**: `specs/OC_179_review_opencode_agent_system_documentation/reports/research-001.md`
- **Maintenance Guide**: `.opencode/docs/guides/documentation-maintenance.md`
- **Validation Script**: `.opencode/scripts/validate-docs.sh`

---

**Remember**: Documentation quality is everyone's responsibility. Run this checklist regularly to catch issues early.
