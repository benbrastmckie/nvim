## Grant Extension

This project includes grant writing support via the grant extension. Provides structured proposal development, budget planning, and funder-specific guidance for research and project funding applications.

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
- @.claude/context/project/grant/README.md
- @.claude/context/project/grant/domain/
- @.claude/context/project/grant/templates/
- @.claude/context/project/grant/patterns/
