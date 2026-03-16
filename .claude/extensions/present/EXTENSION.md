## Present Extension

This project includes presentation support via the present extension. Provides structured proposal development (grants) and investor pitch deck generation (decks) in Typst format.

---

## Grant Writing

Structured proposal development, budget planning, and funder-specific guidance for research and project funding applications.

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `grant` | `skill-grant` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-grant | grant-agent | opus | Grant proposal research and drafting |

### Grant Writing Workflow

1. **Research Phase**: Analyze funder requirements, review past awarded grants, identify alignment
2. **Drafting Phase**: Develop narrative sections following funder-specific templates
3. **Review Phase**: Verify compliance, check budget alignment, validate impact statements

### Key Components

- **Narrative Sections**: Problem statement, methodology, impact, sustainability
- **Budget Development**: Personnel, equipment, travel, indirect costs
- **Compliance**: Funder-specific requirements, format guidelines, submission procedures

### Context Imports

Domain knowledge (load as needed):
- @.claude/context/project/present/README.md
- @.claude/context/project/present/domain/
- @.claude/context/project/present/templates/
- @.claude/context/project/present/patterns/

---

## Pitch Deck Generation

YC-style investor pitch deck generation in Typst format using the touying package.

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `deck` | `skill-deck` | `skill-deck` | Read, Write, Glob, Bash |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-deck | deck-agent | - | Pitch deck generation in Typst |

### Deck Generation Workflow

1. **Input Phase**: Accept prompt describing startup or file with startup information
2. **Content Mapping**: Map content to YC's 10-slide structure
3. **Generation Phase**: Generate complete Typst file with touying syntax
4. **Output Phase**: Write .typ file ready for compilation

### Key Components

- **YC Slide Structure**: Title, Problem, Solution, Traction, Why Us/Now, Business Model, Market, Team, The Ask, Closing
- **Touying Integration**: Modern Typst presentation package with theme support
- **Design Principles**: Legibility, Simplicity, Obviousness (YC guidelines)

### Context Imports

Domain knowledge (load as needed):
- @.claude/context/project/present/patterns/pitch-deck-structure.md
- @.claude/context/project/present/patterns/touying-pitch-deck-template.md
