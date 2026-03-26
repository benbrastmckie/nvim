## Present Extension

Structured proposal development (grants) and investor pitch deck generation (decks) in Typst format.

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-grant | grant-agent | opus | Grant proposal research and drafting |
| skill-deck | deck-agent | - | Pitch deck generation in Typst |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/grant` | `/grant "Description"` | Create grant task (stops at [NOT STARTED]) |
| `/grant` | `/grant N --draft ["focus"]` | Draft narrative sections (exploratory) |
| `/grant` | `/grant N --budget ["guidance"]` | Develop budget with justification |
| `/grant` | `/grant --revise N "description"` | Create revision task for existing grant |
| `/deck` | `/deck "startup description"` | Generate YC-style pitch deck in Typst |

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `grant` | `skill-grant` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |
| `deck` | `skill-deck` | `skill-deck` | Read, Write, Glob, Bash |

### Context

- @context/project/present/domain/grant-workflow.md - Command usage, revision workflow, output directory
- @context/project/present/domain/deck-workflow.md - Deck generation workflow, YC slide structure
- @context/project/present/domain/proposal-components.md - Standard grant proposal sections
- @context/project/present/patterns/pitch-deck-structure.md - YC 10-slide structure
- @context/project/present/patterns/touying-pitch-deck-template.md - Touying Typst patterns
