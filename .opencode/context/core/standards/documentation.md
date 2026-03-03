# Documentation Standards

## Purpose

Documentation standards for the .opencode AI system and Logos/Theory repository.
These standards ensure documentation is clear, concise, accurate, and optimized for
AI agent consumption.

## Core Principles

1. **Clear**: Use precise technical language without ambiguity
2. **Concise**: Avoid bloat, historical mentions, and redundancy
3. **Accurate**: Document current state only, not past versions or future plans
4. **Consistent**: Follow established patterns and conventions
5. **AI-Optimized**: Structure for efficient AI agent parsing and understanding

## General Standards

### Content Guidelines

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
- Add "Version History" sections (this is useless cruft)
- Include version numbers in documentation (e.g., "v1.0.0", "v2.0.0")
- Document what changed between versions

### Formatting Standards

#### Line Length
- Maximum 100 characters per line
- Break long lines at natural boundaries (after punctuation, before conjunctions)

#### Headings
- Use ATX-style headings (`#`, `##`, `###`)
- Never use Setext-style underlines (`===`, `---`)
- Capitalize first word and proper nouns only

#### Code Blocks
- Always specify language for syntax highlighting
- Use `lean` for LEAN 4 code
- Use `bash` for shell commands
- Use `json` for JSON examples

#### File Trees
- Use Unicode box-drawing characters for directory trees
- Format: `├──`, `└──`, `│`
- Example:
  ```
  .opencode/
  ├── .opencode/context/
  │   ├── core/
  │   │   ├── repo/
  │   │   │   └── documentation.md
  │   │   └── lean4/
  └── specs/
  ```

#### Lists
- Use `-` for unordered lists
- Use `1.`, `2.`, `3.` for ordered lists
- Indent nested lists with 2 spaces

### NO EMOJI Policy

**Enforcement**: See `.opencode/AGENTS.md` for centralized rule (automatically loaded by OpenCode).

**Prohibition**: No emojis are permitted anywhere in .opencode system files.

**Rationale**:
- Emojis are ambiguous and culture-dependent
- Text-based alternatives are clearer and more accessible
- Emojis interfere with grep/search operations
- Professional documentation should use precise language

**Text Alternatives**:
| Emoji | Text Alternative | Usage |
|-------|-----------------|-------|
| [PASS] (was checkmark) | [PASS], [COMPLETE], [YES] | Success indicators |
| [FAIL] (was cross mark) | [FAIL], [NOT RECOMMENDED], [NO] | Failure indicators |
| [WARN] (was warning) | [WARN], [PARTIAL], [CAUTION] | Warning indicators |
| [TARGET] (was target) | [TARGET], [GOAL] | Objectives |
| [IDEA] (was lightbulb) | [IDEA], [TIP], [NOTE] | Suggestions |

**Validation**:
Before committing any artifact, verify no emojis present:
```bash
grep -E "[\x{1F300}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}]" file.md
```

If emojis found, replace with text alternatives from table above.

### NO VERSION HISTORY Policy

**Prohibition**: Version history sections are FORBIDDEN in all .opencode documentation.

**Rationale**:
- Version history is useless cruft that clutters documentation
- Git history already tracks all changes comprehensively
- Historical information becomes stale and misleading
- Documentation should describe current state only
- Version numbers (v1.0.0, v2.0.0, etc.) add no value
- "What changed" information is irrelevant to current usage

**Examples of Forbidden Content**:
```markdown
## Version History

- v5.0.0 (2026-01-05): Optimized with direct delegation
- v4.0.0 (2026-01-05): Full refactor with --expand flag
- v3.0.0 (2026-01-05): Simplified to direct implementation
```

**Correct Approach**:
- Document current behavior only
- Use git log to track changes
- Update documentation in-place when behavior changes
- Remove outdated information immediately

**Validation**:
Before committing any documentation, verify no version history:
```bash
grep -i "version history" file.md
grep -E "v[0-9]+\.[0-9]+\.[0-9]+" file.md
```

If version history found, remove it entirely.

### Cross-References

#### Internal Links
- Use relative paths from current file location
- Format: `[Link Text](relative/path/to/file.md)`
- Include section anchors when referencing specific sections:
  `[Section Name](file.md#section-anchor)`

#### External Links
- Use full URLs for external resources
- Include link text that describes the destination
- Verify links are accessible before committing

## LEAN 4 Specific Standards

### Formal Symbols
All Unicode formal symbols must be wrapped in backticks:
- `□` (box/necessity)
- `◇` (diamond/possibility)
- `△` (triangle)
- `▽` (nabla)
- `⊢` (turnstile/proves)
- `⊨` (double turnstile/models)

**Correct**: "The formula `□φ` represents necessity"
**Incorrect**: "The formula □φ represents necessity"

### Code Documentation
- All public definitions require docstrings
- Follow LEAN 4 docstring format with `/-!` and `-/`
- Include type signatures in examples
- Document preconditions and postconditions

### Module Documentation
- Each `.lean` file should have module-level documentation
- Explain purpose and key definitions
- Link to related modules
- Provide usage examples for complex functionality

## Directory README Standards

### When README Required
- Top-level source directories
- Test directories with 3+ subdirectories
- Example/archive directories
- Multi-subdirectory documentation roots

### When README Not Required
- Single-module directories with excellent `.lean` module documentation
- Subdirectories when parent README provides sufficient navigation
- Build/output directories
- Directories with <3 files that are self-explanatory

### README Structure
1. **Title**: Directory name as H1
2. **Purpose**: 1-2 sentence description
3. **Organization**: Subdirectory listing with brief descriptions
4. **Quick Reference**: Where to find specific functionality
5. **Usage**: How to build, test, or run (if applicable)
6. **Related Documentation**: Links to relevant docs

### README Anti-Patterns
- Duplicating `.lean` docstrings
- Describing files/structure that no longer exists
- Creating READMEs for simple directories
- Including implementation details better suited for code comments

## .opencode System Documentation

### Context Files
Context files in `.opencode/context/` provide knowledge for AI agents:

**Structure**:
- `core/`: Core system standards, workflows, repo, templates
- `lean4/`: LEAN 4 specific knowledge (domain, patterns, processes, tools)
- `logic/`: Logic domain knowledge (proof theory, semantics, metalogic)
- `math/`: Mathematical domain knowledge

**Guidelines**:
- Keep files focused on single topics
- Use hierarchical organization
- Provide concrete examples
- Include verification procedures where applicable
- Cross-reference related context files

### Artifact Documentation
Artifacts in `specs/` are organized by project:

**Structure**:
- `NNN_project_name/reports/`: Research and analysis reports
- `NNN_project_name/plans/`: Implementation plans (versioned)
- `NNN_project_name/summaries/`: Brief summaries

**Guidelines**:
- Use descriptive project names
- Increment plan versions when revising
- Keep summaries to 1-2 pages maximum
- Link artifacts to specs/TODO.md tasks
- Update specs/state.json after operations

## Validation

### Pre-Commit Checks
Before committing documentation:

1. **Syntax**: Validate markdown syntax
2. **Links**: Verify all internal links resolve
3. **Line Length**: Check 100-character limit compliance
4. **Formal Symbols**: Ensure backticks around Unicode symbols
5. **Code Blocks**: Verify language specification
6. **Consistency**: Check cross-file consistency

### Automated Validation
```bash
# Validate line length
awk 'length > 100 {print FILENAME" line "NR" exceeds 100 chars"; exit 1}' file.md

# Check for unbackticked formal symbols
grep -E "□|◇|△|▽|⊢|⊨" file.md | grep -v '`'

# Validate JSON syntax in code blocks
jq empty file.json

# Check for broken internal links
# (requires custom script)
```

## Quality Checklist

Use this checklist when creating or updating documentation:

- [ ] Content is clear and technically precise
- [ ] No historical information or version mentions
- [ ] No emojis used (verified with grep -E "[\x{1F300}-\x{1F9FF}\x{2600}-\x{26FF}\x{2700}-\x{27BF}]" file.md)
- [ ] Line length ≤ 100 characters
- [ ] ATX-style headings used
- [ ] Code blocks have language specification
- [ ] Unicode file trees used for directory structures
- [ ] Formal symbols wrapped in backticks
- [ ] Internal links use relative paths
- [ ] External links are accessible
- [ ] Cross-references are accurate
- [ ] No duplication of information
- [ ] Examples are concrete and verifiable

## Related Standards

### Logos/Theory Project
- [DIRECTORY_README_STANDARD.md](../../../docs/development/DIRECTORY_README_STANDARD.md)
  - Directory-level README conventions for LEAN 4 projects
- [DOC_QUALITY_CHECKLIST.md](../../../docs/development/DOC_QUALITY_CHECKLIST.md)
  - Systematic verification procedures for documentation quality
- [LEAN_STYLE_GUIDE.md](../../../docs/development/LEAN_STYLE_GUIDE.md)
  - Code-level documentation conventions

### .opencode System
- [Artifact Management](../system/artifact-management.md) - Artifact organization
- [State Schema](state-schema.md) - State file schemas
- [Core Standards](../standards/) - System-wide standards

## Maintenance

### Updating Standards
When updating these standards:
1. Ensure changes are backward compatible
2. Update related documentation
3. Notify affected agents/workflows
4. Test with existing documentation

---

## See Also

- [documentation-standards.md](documentation-standards.md) - File naming conventions, README
  requirements, prohibited content, and directory purpose standards
