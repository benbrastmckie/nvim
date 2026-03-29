# Documentation Standards

Standards for documentation files in the `.claude/` directory and `docs/` directory.

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

**Rationale**: README.md is a universal convention recognized by GitHub, GitLab, and other
platforms. It appears prominently in directory listings and repository views.

**All other files** follow kebab-case, including:
- `CONTRIBUTING.md` becomes `contributing.md`
- `CHANGELOG.md` becomes `changelog.md`
- `LICENSE.md` remains an exception only if required by tooling

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
- Follow patterns from DIRECTORY_README_STANDARD.md
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
- Use `**Warning**:` instead of warning emoji
- Use `- [ ]` and `- [x]` for checkboxes instead of checkmark emojis
- Use `[PASS]`, `[FAIL]`, `[PARTIAL]` for status indicators
- Use `**DO**` and `**DON'T**` for emphasis
- Use `->` or unicode `→` for flow indicators

### "Quick Start" Sections

Do not include "Quick Start" sections in documentation.

**Problem**: Quick Start sections encourage users to skip context and understanding.
Users jump to the quick start, copy commands without understanding them, then encounter
problems they cannot debug because they lack foundational knowledge.

**Alternative approaches**:
- Structured introduction that builds understanding progressively
- Clear prerequisites section followed by step-by-step instructions
- Example-first documentation where examples are explained in detail
- Reference tables that users can scan quickly while still providing context

### "Quick Reference" Documents

Do not create standalone quick reference documents or reference card sections.

**Problem**: Quick reference documents become maintenance burdens. They duplicate
information from authoritative sources, drift out of sync, and provide incomplete
information that leads to incorrect usage.

**Alternative approaches**:
- Summary tables within authoritative documents
- Decision trees that guide users to the right information
- Well-organized indexes with links to full documentation
- Command help text (`--help` flags) for CLI tools

**Exception**: Tables that summarize information defined in the same document are
acceptable. The prohibition applies to separate "cheat sheet" or "quick ref" files.

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

**Rationale**: Documentation describes the current state of the system. Historical
information belongs in git history, release notes, or dedicated migration guides
that are separate from the main documentation.

**Correct approach**:
- Document current behavior only
- Use git log to track changes
- Update documentation in-place when behavior changes
- Remove outdated information immediately
- Create separate migration guides when needed (in `docs/` not `context/`)

## Directory Purpose

### docs/ Directory

User-facing guides and documentation.

**Audience**: Human users, developers, contributors

**Content types**:
- Installation and setup guides
- How-to guides with step-by-step instructions
- Tutorials and walkthroughs
- Troubleshooting guides
- Architecture overviews (user-facing)
- Contributing guidelines

**Style characteristics**:
- User-friendly language
- Step-by-step instructions
- Explanatory prose
- Screenshots or diagrams where helpful

**README.md**: Required in all subdirectories

### context/ Directory

AI agent knowledge and operational standards.

**Audience**: AI agents (Claude Code), developers maintaining the system

**Content types**:
- Standards and conventions
- Schema definitions
- Pattern libraries
- Domain knowledge (logic, mathematics)
- Tool usage guides
- Workflow specifications

**Style characteristics**:
- Technical precision
- Machine-parseable structure
- Concrete examples with verification
- Cross-references to related context

**README.md**: Optional (include when helpful for navigation)

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

### Related Standards

- [documentation.md](documentation.md) - General documentation formatting standards
- [DIRECTORY_README_STANDARD.md](../../../docs/development/DIRECTORY_README_STANDARD.md) -
  Directory README conventions for the project
