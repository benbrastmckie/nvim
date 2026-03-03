# Documentation Maintenance Guide

**Version**: 1.0  
**Created**: Task 179 - Documentation Review  
**Purpose**: Ensure .opencode/ documentation remains accurate, consistent, and maintainable

---

## Overview

This guide establishes the process for maintaining documentation quality in the .opencode/ agent system. Following these practices prevents documentation drift and ensures all team members can rely on accurate documentation.

---

## Maintenance Tasks

### Daily (During Development)

**When modifying .opencode/ files:**

1. **Update references immediately** - If you move or rename a file, update all references
2. **Sync component counts** - If you add/remove commands, skills, or agents, update:
   - `.opencode/docs/guides/component-selection.md` inventory section
   - `.opencode/OPENCODE.md` Skill-to-Agent mapping table
3. **Verify examples still work** - Test any command examples in documentation
4. **Check cross-references** - Ensure @-references point to existing files

### Weekly (Documentation Hygiene)

**Run validation script:**
```bash
bash .opencode/scripts/validate-docs.sh
```

**Review output for:**
- Broken path references
- Non-existent commands mentioned in docs
- Missing or outdated component counts
- Incorrect project naming

### Monthly (Comprehensive Audit)

**Full documentation review:**

1. Run the complete audit checklist:
   ```bash
   # Review each item in documentation-audit-checklist.md
   # Check off completed items
   ```

2. Focus areas:
   - **Path accuracy**: All `.opencode/` paths are valid
   - **Command existence**: All documented commands exist
   - **Project naming**: Consistent "Logos/Theory" usage
   - **Component counts**: Accurate inventory numbers
   - **Cross-references**: Functional internal links

3. Update after significant changes:
   - New commands/skills/agents added
   - Directory restructuring
   - Major feature additions

---

## Common Issues & Fixes

### Issue: Path References Broken

**Symptoms**: Documentation mentions files that don't exist

**Fix**:
1. Find broken references: `grep -r "\.opencode/" .opencode/ --include="*.md"`
2. Verify each path exists: `ls <path>`
3. Update or remove broken references

### Issue: Wrong Project Name

**Symptoms**: "ProofChecker" appears in current documentation

**Fix**:
```bash
# Replace (preserving historical references)
find .opencode -name "*.md" ! -path "*/project-overview.md" \
  -exec sed -i 's/ProofChecker/Logos\/Theory/g' {} \;
```

### Issue: Outdated Component Counts

**Symptoms**: Inventory numbers don't match actual files

**Fix**:
1. Count actual files:
   ```bash
   ls .opencode/commands/*.md | wc -l
   find .opencode/skills -name "SKILL.md" | wc -l
   ls .opencode/agent/subagents/*.md | wc -l
   ```
2. Update `.opencode/docs/guides/component-selection.md`
3. Update `.opencode/OPENCODE.md` mapping tables

### Issue: Non-existent Commands

**Symptoms**: QUICK-START.md or guides mention commands that don't work

**Fix**:
1. Verify command exists: `ls .opencode/commands/<command>.md`
2. Test command: Try running `/command --help`
3. Remove or deprecate non-existent commands

---

## Documentation Standards

### Required for All Documentation Files

1. **Frontmatter** (YAML between `---` lines):
   ```yaml
   ---
   name: filename
   description: "Clear, concise description"
   ---
   ```

2. **Accurate cross-references**:
   - Use `@.opencode/path/to/file.md` format
   - Verify target file exists
   - Update when moving files

3. **Consistent terminology**:
   - "Lean 4" (not "LEAN 4")
   - "Logos/Theory" (not "ProofChecker")
   - "commands/" (not "command/")
   - `OC_NNN` for directories (3-digit padded)

4. **No emojis** in formal documentation

### Prohibited Patterns

**Never include:**
- References to `.opencode_NEW` (use `.opencode`)
- Non-existent files in examples
- Deprecated commands without migration notes
- Blocked tools in "Essential Tools" lists

---

## Tools & Scripts

### validate-docs.sh

Runs automated checks for common issues:
- Path reference validation
- Command existence checks
- Project naming verification
- Component count verification

Run weekly or before releases.

### documentation-audit-checklist.md

Comprehensive checklist covering all documentation aspects. Use monthly or after major changes.

---

## When to Update Documentation

### Immediate (Same PR)

- Adding/removing commands, skills, or agents
- Changing file paths or directory structure
- Modifying command signatures or behavior
- Updating blocked/essential tools lists

### Before Release

- Run full validation script
- Complete audit checklist
- Verify all examples work
- Review for consistency

### Periodic (Quarterly)

- Comprehensive documentation review
- Update outdated examples
- Refresh stale content
- Archive obsolete documentation

---

## Emergency Fixes

**If documentation is severely broken:**

1. Create high-priority task: `/task "Fix critical documentation issues"`
2. Run validation script to identify all issues
3. Fix in order of severity:
   - Broken paths (users can't find files)
   - Wrong commands (users get errors)
   - Incorrect project name (brand confusion)
4. Verify fixes: Re-run validation script
5. Update audit checklist status

---

## Success Metrics

**Healthy documentation indicators:**
- `validate-docs.sh` returns 0 issues
- All internal links resolve
- Component counts match reality
- No deprecated references
- Consistent terminology throughout

**Warning signs:**
- Validation script finds issues
- User questions about "missing" files
- Commands that don't work as documented
- Inconsistent naming in different files

---

## Related Resources

- **Audit Checklist**: `.opencode/docs/guides/documentation-audit-checklist.md`
- **Validation Script**: `.opencode/scripts/validate-docs.sh`
- **Component Guide**: `.opencode/docs/guides/component-selection.md`
- **Standards**: `.opencode/context/core/standards/documentation.md`

---

**Remember**: Documentation is a first-class citizen. Keep it accurate, keep it current, keep it useful.
