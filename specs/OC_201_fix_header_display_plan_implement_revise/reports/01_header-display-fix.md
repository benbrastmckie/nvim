# Research Report: Task #201

**Task**: 201 - fix_header_display_plan_implement_revise
**Started**: 2026-03-13T12:00:00Z
**Completed**: 2026-03-13T12:15:00Z
**Effort**: 0.5-1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .opencode/commands/*.md
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `/research` command has a working header display pattern at lines 5-9 that the other commands lack
- The fix requires adding a similar header instruction block at the top of each command file
- Three commands need the fix: `/plan`, `/implement`, and `/revise`
- The pattern uses explicit instructions to avoid markdown headings and output plain text first

## Context & Scope

This research examines why `/research` correctly displays task numbers in response headers (e.g., "[Researching] Task OC_72: project_name") while `/plan`, `/implement`, and `/revise` do not. The goal is to identify the specific code pattern that enables this behavior and document how to apply it to the other commands.

## Findings

### Working Pattern in /research (Lines 5-9)

The `/research` command contains a critical instruction block immediately after the frontmatter:

```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Researching] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS — never output "OC_N" or "OC_NN" literally.
```

This pattern:
1. **Explicitly prohibits markdown headings** as first output
2. **Specifies the exact format** with bracketed status and task identifier
3. **Emphasizes substitution of real values** over template placeholders
4. **Positions the instruction at the very top** before any other content

### Missing Pattern in /plan

The `/plan` command (lines 1-211) does NOT have this header instruction:
- Line 1-3: Frontmatter only
- Line 5: Immediately jumps to "Create an implementation plan for the given task."
- No explicit instruction about first output format

The preflight section (Step 3, lines 42-65) does mention "Display header" but:
- It's buried deep in the document (line 55-57)
- The instruction style is different (not a prohibition-first directive)
- Claude may not process it with the same priority as a top-of-file instruction

### Missing Pattern in /implement

The `/implement` command (lines 1-251) also lacks the header instruction:
- Line 1-3: Frontmatter only
- Line 5: Immediately jumps to "Execute the implementation plan for the given task."
- No top-level instruction about output format

The preflight section (Step 4, lines 51-74) has no "Display header" instruction at all.

### Missing Pattern in /revise

The `/revise` command (lines 1-368) uses a completely different structure:
- Lines 1-3: Frontmatter
- Lines 5-10: Task input and context blocks
- No header display instruction anywhere
- Uses XML-style workflow execution tags instead of numbered steps

### Root Cause Analysis

The issue is **instruction positioning and emphasis**:

| Command | Header Instruction Position | Emphasis Level | Works? |
|---------|----------------------------|----------------|--------|
| /research | Lines 5-9 (top of file) | Strong prohibition + explicit format | Yes |
| /plan | Lines 55-57 (buried in Step 3) | Weak (just "Display header") | No |
| /implement | None | None | No |
| /revise | None | None | No |

Claude Code prioritizes instructions at the top of command files. Instructions buried deep in procedural steps are processed with lower priority and may be skipped when the model generates its response.

### The Fix Pattern

Add the following block immediately after the frontmatter (lines 5-9) in each command:

**For /plan:**
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Planning] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS — never output "OC_N" or "OC_NN" literally.

---
```

**For /implement:**
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Implementing] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS — never output "OC_N" or "OC_NN" literally.

---
```

**For /revise:**
```markdown
**DO NOT start with a markdown heading.** Your first output must be a plain line using the actual argument value. If $ARGUMENTS is `72` or `OC_72`, output:

[Revising] Task OC_72: (project_name once known from state.json)

Substitute the real integer from $ARGUMENTS — never output "OC_N" or "OC_NN" literally.

---
```

## Recommendations

1. **Add header instruction block** to all three commands immediately after frontmatter
2. **Use consistent format**: `[Action] Task OC_N: project_name`
3. **Keep the prohibition-first style**: "DO NOT start with a markdown heading"
4. **Include the substitution warning**: "never output OC_N literally"
5. **Position before any other content** for maximum priority

## Decisions

- Use bracketed action verbs matching the command phase: [Planning], [Implementing], [Revising]
- Keep identical instruction structure across all commands for maintainability
- Place instruction block between frontmatter and existing content, with horizontal rule separator

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Instruction may be ignored by some models | Use strong prohibition language ("DO NOT") |
| Format inconsistency across commands | Use copy-paste template with only action verb changed |
| Future commands may miss this pattern | Document pattern in command authoring standards |

## Implementation Checklist

1. [ ] Edit `.opencode/commands/plan.md` - add header block after line 3
2. [ ] Edit `.opencode/commands/implement.md` - add header block after line 3
3. [ ] Edit `.opencode/commands/revise.md` - add header block after line 3
4. [ ] Verify each command displays correct header format
5. [ ] Consider documenting this pattern in command authoring standards

## Appendix

### File Locations
- `/home/benjamin/.config/nvim/.opencode/commands/research.md` - Working reference
- `/home/benjamin/.config/nvim/.opencode/commands/plan.md` - Needs fix
- `/home/benjamin/.config/nvim/.opencode/commands/implement.md` - Needs fix
- `/home/benjamin/.config/nvim/.opencode/commands/revise.md` - Needs fix

### Key Lines in /research
- Lines 5-9: Header instruction block (the pattern to copy)
- Lines 55-59: Preflight "Display header" step (redundant but reinforcing)
