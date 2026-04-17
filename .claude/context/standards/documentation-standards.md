# Documentation Standards

Standards for documentation files in the `.claude/` directory and `docs/` directory. These standards ensure documentation is clear, concise, accurate, and optimized for AI agent consumption.

## Core Principles

1. **Clear**: Use precise technical language without ambiguity
2. **Concise**: Avoid bloat, historical mentions, and redundancy
3. **Accurate**: Document current state only, not past versions or future plans
4. **Consistent**: Follow established patterns and conventions
5. **AI-Optimized**: Structure for efficient AI agent parsing and understanding

## File Naming Conventions

### General Rule

All documentation files in `.claude/` use **lowercase kebab-case** with `.md` extension.

**Correct**:
- `documentation-standards.md`
- `error-handling.md`
- `task-management.md`
- `mcp-tools-guide.md`

**Incorrect**:
- `DOCUMENTATION_STANDARDS.md` (all caps)
- `documentation_standards.md` (underscores)
- `DocumentationStandards.md` (PascalCase)
- `documentationStandards.md` (camelCase)

### README.md Exception

`README.md` files use ALL_CAPS naming. This is the **only** exception to kebab-case.

**Rationale**: README.md is a universal convention recognized by GitHub, GitLab, and other platforms. It appears prominently in directory listings and repository views.

**All other files** follow kebab-case, including:
- `CONTRIBUTING.md` becomes `contributing.md`
- `CHANGELOG.md` becomes `changelog.md`
- `LICENSE.md` remains an exception only if required by tooling

## Content Guidelines

**Do**:
- Document what exists now
- Use present tense
- Provide concrete examples
- Include verification commands where applicable
- Link to related documentation
- Use technical precision

**Don't**:
- Include historical information about past versions
- Mention "we changed X to Y" or "previously this was Z"
- Use emojis anywhere in documentation
- Include speculative future plans
- Duplicate information across files
- Use vague or ambiguous language
- Add "Version History" sections
- Include version numbers in documentation (e.g., "v1.0.0", "v2.0.0")
- Document what changed between versions

## Formatting Standards

### Line Length
- Maximum 100 characters per line
- Break long lines at natural boundaries (after punctuation, before conjunctions)

### Headings
- Use ATX-style headings (`#`, `##`, `###`)
- Never use Setext-style underlines (`===`, `---`)
- Capitalize first word and proper nouns only

### Code Blocks
- Always specify language for syntax highlighting
- Use `bash` for shell commands
- Use `json` for JSON examples
- Use the appropriate language identifier for project source files
- Use `lean` for Lean code (when extension loaded)

### File Trees
- Use Unicode box-drawing characters: `├──`, `└──`, `│`
- Example:
  ```
  .claude/
  ├── commands/
  │   ├── task.md
  │   └── research.md
  └── context/
      └── standards/
  ```

### Lists
- Use `-` for unordered lists
- Use `1.`, `2.`, `3.` for ordered lists
- Indent nested lists with 2 spaces

## README.md Requirements

### docs/ Subdirectories

Every subdirectory of `.claude/docs/` **must** contain a `README.md` file.

**Purpose**: Navigation guide and organizational documentation

**Content requirements**:
- Directory title as H1
- 1-2 sentence purpose description
- File listing with brief descriptions (if directory contains files)
- Subdirectory listing with brief descriptions (if directory contains subdirectories)
- Related documentation links (if applicable)

**Style guidance**:
- Lightweight and navigation-focused
- Do not duplicate content from files in the directory
- Keep under 100 lines where possible

### context/ Subdirectories

README.md files are **optional** in `.claude/context/` subdirectories.

**When to include**:
- Directories with 3+ files
- Complex organizational structures
- Directories where file purposes are not self-evident from names

**When to omit**:
- Single-purpose directories with clear naming
- Directories where file names are self-explanatory
- Deeply nested directories where parent README provides sufficient context

### README Structure Template

1. **Title**: Directory name as H1
2. **Purpose**: 1-2 sentence description
3. **Organization**: Subdirectory listing with brief descriptions
4. **Contents**: File listing (if leaf directory)
5. **Related Documentation**: Links to relevant docs

### README Anti-Patterns

- Duplicating module/file docstrings
- Describing files/structure that no longer exists
- Creating READMEs for simple directories
- Including implementation details better suited for code comments
- Including "Quick Start" sections (see Prohibited Content)

## Prohibited Content

### Emojis

Do not use emojis in documentation.

**Prohibited**: Any emoji characters including:
- Status indicators (checkmarks, cross marks, warning signs)
- Decorative icons (sparkles, stars, arrows)
- Face/emotion emojis
- Object emojis

**Permitted**: Unicode characters for technical purposes:
- Mathematical symbols: `→`, `∧`, `∨`, `¬`, `□`, `◇`, `∀`, `∃`
- Arrows for diagrams: `↑`, `↓`, `←`, `→`, `↔`
- Box-drawing characters: `├`, `└`, `│`, `─`
- Special characters: `×`, `÷`, `±`, `≤`, `≥`, `≠`

**Rationale**:
- Maintains professional, consistent tone across documentation
- Ensures cross-platform rendering consistency
- Improves accessibility for screen readers
- Reduces visual clutter and distraction
- Facilitates grep/search operations

**Alternatives**:
| Use case | Alternative |
|----------|-------------|
| Success indicator | `[PASS]`, `[COMPLETE]`, `[YES]` |
| Failure indicator | `[FAIL]`, `[NO]` |
| Warning indicator | `[WARN]`, `[PARTIAL]`, `[CAUTION]` |
| Objective | `**Goal**:` |
| Suggestion | `**Note**:`, `**Tip**:` |
| Flow arrow | `->` or unicode `→` |
| Checkbox | `- [ ]` and `- [x]` |

### "Quick Start" Sections

Do not include "Quick Start" sections in documentation.

**Problem**: Quick Start sections encourage users to skip context and understanding. Users jump to the quick start, copy commands without understanding them, then encounter problems they cannot debug because they lack foundational knowledge.

**Alternative approaches**:
- Structured introduction that builds understanding progressively
- Clear prerequisites section followed by step-by-step instructions
- Example-first documentation where examples are explained in detail
- Reference tables that users can scan quickly while still providing context

### "Quick Reference" Documents

Do not create standalone quick reference documents or reference card sections.

**Problem**: Quick reference documents become maintenance burdens. They duplicate information from authoritative sources, drift out of sync, and provide incomplete information that leads to incorrect usage.

**Alternative approaches**:
- Summary tables within authoritative documents
- Decision trees that guide users to the right information
- Well-organized indexes with links to full documentation
- Command help text (`--help` flags) for CLI tools

**Exception**: Tables that summarize information defined in the same document are acceptable. The prohibition applies to separate "cheat sheet" or "quick ref" files.

### Version History Sections

Version history sections are **forbidden** in all `.claude/` documentation.

**Rationale**:
- Version history is useless cruft that clutters documentation
- Git history already tracks all changes comprehensively
- Historical information becomes stale and misleading
- Documentation should describe current state only

**Forbidden example**:
```markdown
## Version History

- v5.0.0 (2026-01-05): Optimized with direct delegation
- v4.0.0 (2026-01-05): Full refactor with --expand flag
```

**Correct approach**:
- Document current behavior only
- Use git log to track changes
- Update documentation in-place when behavior changes
- Remove outdated information immediately

## Temporal Language Requirements

### Present Tense Only

Write all documentation in present tense.

**Correct**:
- "The system validates input before processing."
- "This function returns a boolean."
- "Users configure the path in settings.json."

**Incorrect**:
- "The system was changed to validate input."
- "Previously, this function returned an integer."
- "Users used to configure this differently."

### No Historical References

Do not include version history, migration notes, or "what changed" content.

**Prohibited content**:
- Version History sections
- Changelog entries within documentation
- "Changed in v2.0" annotations
- Migration guides within standards documents
- References to "the old system" or "legacy behavior"
- "Previously known as" notes
- "Deprecated in favor of" notes (except in dedicated deprecation notices)

**Rationale**: Documentation describes the current state of the system. Historical information belongs in git history, release notes, or dedicated migration guides that are separate from the main documentation.

## Directory Purpose

### docs/ Directory

User-facing guides and documentation.

- **Audience**: Human users, developers, contributors
- **Content types**: installation/setup, how-to guides, tutorials, troubleshooting, architecture overviews, contributing guidelines
- **Style**: User-friendly language, step-by-step instructions, explanatory prose
- **README.md**: Required in all subdirectories

### context/ Directory

AI agent knowledge and operational standards.

- **Audience**: AI agents (Claude Code), developers maintaining the system
- **Content types**: standards, schemas, pattern libraries, domain knowledge, tool usage guides, workflow specifications
- **Style**: Technical precision, machine-parseable structure, concrete examples with verification, cross-references
- **README.md**: Optional (include when helpful for navigation)

### Key Differences

| Aspect | docs/ | context/ |
|--------|-------|----------|
| Primary audience | Humans | AI agents |
| Writing style | Explanatory | Prescriptive |
| Examples | Tutorials | Specifications |
| Navigation | README required | README optional |
| Updates | User-driven | System-driven |

## Cross-References

### Internal Links

Use relative paths from the current file location:
- Format: `[Link Text](relative/path/to/file.md)`
- With section: `[Section Name](file.md#section-anchor)`

### External Links

- Use full URLs for external resources
- Include link text that describes the destination
- Verify links are accessible before committing

## Validation

### Pre-Commit Checks

Before committing documentation:

1. **Syntax**: Validate markdown syntax
2. **Links**: Verify all internal links resolve
3. **Line Length**: Check 100-character limit compliance
4. **Code Blocks**: Verify language specification
5. **No Emoji**: Confirm no emoji characters present
6. **Consistency**: Check cross-file consistency

### Automated Validation

```bash
# Validate line length (warn on >100 chars)
awk 'length > 100 {print FILENAME" line "NR" exceeds 100 chars"}' file.md

# Check for emoji characters
grep -P "[\x{1F300}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}]" file.md

# Check for version history sections
grep -i "version history" file.md

# Validate JSON syntax in code blocks (extract and pipe to jq)
jq empty file.json
```

## Quality Checklist

Use this checklist when creating or updating documentation:

- [ ] Content is clear and technically precise
- [ ] No historical information or version mentions
- [ ] No emojis used
- [ ] Line length <= 100 characters
- [ ] ATX-style headings used
- [ ] Code blocks have language specification
- [ ] Unicode file trees used for directory structures
- [ ] Internal links use relative paths
- [ ] External links are accessible
- [ ] Cross-references are accurate
- [ ] No duplication of information
- [ ] Examples are concrete and verifiable
- [ ] Present tense throughout
- [ ] No "Quick Start" or standalone "Quick Reference" sections

## Related Standards

- [artifact-formats.md](../../rules/artifact-formats.md) - Report/plan file formats
- [state-management.md](../../rules/state-management.md) - State file schemas
