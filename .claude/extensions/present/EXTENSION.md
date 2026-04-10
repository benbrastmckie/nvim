## Present Extension

Structured proposal development (grants) and research presentation creation (talks) in Typst and Slidev formats.

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-grant | grant-agent | opus | Grant proposal research and drafting |
| skill-budget | budget-agent | opus | Grant budget spreadsheet generation (XLSX) |
| skill-timeline | timeline-agent | opus | Research project timeline planning |
| skill-funds | funds-agent | opus | Research funding landscape analysis |
| skill-talk | talk-agent | opus | Research talk material synthesis and presentation assembly |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/grant` | `/grant "Description"` | Create grant task (stops at [NOT STARTED]) |
| `/grant` | `/grant N --draft ["focus"]` | Draft narrative sections (exploratory) |
| `/grant` | `/grant N --budget ["guidance"]` | Develop budget with justification |
| `/grant` | `/grant --revise N "description"` | Create revision task for existing grant |
| `/budget` | `/budget "Description"` | Create grant budget task with forcing questions |
| `/budget` | `/budget N` | Resume budget generation for existing task |
| `/timeline` | `/timeline "Description"` | Create research timeline task |
| `/timeline` | `/timeline N` | Resume timeline planning for existing task |
| `/funds` | `/funds "Description"` | Create funding analysis task with forcing questions |
| `/funds` | `/funds N` | Resume funding analysis for existing task |
| `/slides` | `/slides "Description"` | Create research talk task with forcing questions |
| `/slides` | `/slides N` | Resume research on existing talk task |
| `/slides` | `/slides /path/to/file` | Use file as primary source material for talk |

### Language Routing

| Language | Task Type | Research Skill | Implementation Skill | Tools |
|----------|-----------|----------------|---------------------|-------|
| `present` | `grant` | `skill-grant` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |
| `present` | `budget` | `skill-budget` | `skill-budget` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present` | `timeline` | `skill-timeline` | `skill-timeline` | WebSearch, WebFetch, Read, Write, Edit |
| `present` | `funds` | `skill-funds` | `skill-funds` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present` | `talk` | `skill-talk` | `skill-talk` | WebSearch, WebFetch, Read, Write, Edit |

### Talk Modes

| Mode | Duration | Slides | Use Case |
|------|----------|--------|----------|
| CONFERENCE | 15-20 min | 12-18 | Conference platform presentations |
| SEMINAR | 45-60 min | 30-45 | Departmental seminars, job talks |
| DEFENSE | 30-60 min | 25-40 | Grant defense, thesis defense |
| POSTER | N/A | 1 | Poster session presentations |
| JOURNAL_CLUB | 15-30 min | 10-15 | Paper review for journal club |

### Talk Library

The talk library at `context/project/present/talk/` contains:
- **Patterns**: Slide structure definitions for each talk mode
- **Content Templates**: Slidev-compatible markdown templates for slide types
- **Components**: Vue components (FigurePanel, DataTable, CitationBlock, StatResult, FlowDiagram)
- **Themes**: Academic-clean and clinical-teal visual themes
