# Grant Writing Workflow Reference

## Command Reference

The `/grant` command supports both task creation and grant-specific workflows.

### Task Creation Mode
```bash
/grant "Description"
```
Creates a task with `language="grant"`. The description is recorded, not executed.

**Example**:
```bash
/grant "Research NIH R01 funding for AI safety project"
```

Output:
```
Grant task #{N} created: Research NIH R01 funding for AI safety project
Status: [NOT STARTED]
Language: grant

Recommended workflow:
1. /orchestrate 500 --research - Research funders and requirements
2. /grant 500 --draft - Draft narrative sections (exploratory)
3. /grant 500 --budget - Develop budget (exploratory)
4. /orchestrate 500 --plan - Create plan informed by drafts
5. /orchestrate 500 --implement - Assemble grant materials to grants/500_{slug}/
```

### Draft Mode (--draft)
```bash
/grant N --draft                     # Default drafting
/grant N --draft "Optional prompt"   # Guided drafting
```

Drafts narrative sections of the proposal. Optional prompt provides focus guidance.

**Examples**:
```bash
/grant 500 --draft
/grant 500 --draft "Focus on innovation and methodology sections"
/grant 500 --draft "Expand the specific aims with more detail on experimental design"
```

### Budget Mode (--budget)
```bash
/grant N --budget                    # Default budget template
/grant N --budget "Optional prompt"  # Guided budget
```

Develops line-item budget with justification. Optional prompt provides budget guidance.

**Examples**:
```bash
/grant 500 --budget
/grant 500 --budget "Include travel for 3 conferences per year"
/grant 500 --budget "Focus on personnel costs, minimize equipment requests"
```

### Revise Mode (--revise)
```bash
/grant --revise N "description"
```

Creates a new task to revise an existing grant (where N is the original grant task number).

**Example**:
```bash
/grant --revise 500 "Update methodology for new reviewer feedback"
```

Output:
```
Grant revision task #{N} created for Grant #{M}
Status: [NOT STARTED]
Parent Grant: Task #{M}
Revises: grants/500_nsf_career_ai/

Recommended workflow:
1. /grant 505 --draft "Focus on sections needing revision"
2. /grant 505 --budget "Update budget items as needed"
3. /orchestrate 505 --implement - Update existing grant directory
```

### Legacy Mode (Deprecated)
```bash
/grant N workflow_type [focus]
```

Legacy workflow_type syntax is deprecated but still supported:
- `funder_research` - Use `/orchestrate N --research` instead
- `proposal_draft` - Use `/grant N --draft` instead
- `budget_develop` - Use `/grant N --budget` instead
- `progress_track` - Still supported

## Core Command Integration

Tasks with `language="grant"` route through core commands:

| Phase | Routes To | Purpose |
|---------|-----------|---------|
| research | skill-grant (funder_research) | Research funders |
| plan | planner-agent (direct) | Create implementation plan (informed by drafts/budgets) |
| implement | skill-grant (assemble) | Assemble grant materials |

## Recommended Workflow

1. **Create task**: `/grant "Research NSF CAREER funding for AI interpretability"`
2. **Research funders**: `/orchestrate 500 --research` (routes to skill-grant)
3. **Draft narrative**: `/grant 500 --draft ["focus prompt"]` (exploratory)
4. **Develop budget**: `/grant 500 --budget ["budget guidance"]` (exploratory)
5. **Create plan**: `/orchestrate 500 --plan` (informed by drafts and budget)
6. **Assemble materials**: `/orchestrate 500 --implement` (creates grants/500_{slug}/)

## Grant Output Directory

Final grant materials are assembled to `grants/{N}_{slug}/`:
```
grants/500_nsf_career_ai/
  - narrative.md     # Complete proposal narrative
  - budget.md        # Finalized budget with justifications
  - checklist.md     # Submission requirements checklist
  - README.md        # Grant package overview
```

## Revision Workflow

To revise an existing grant:

1. **Create revision task**: `/grant --revise 500 "Update methodology section"`
   - Creates a new task linked to the original grant
   - Task state includes `parent_grant` and `revises_directory` fields

2. **Make changes**: Use `--draft` and `--budget` to create updated sections

3. **Assemble revision**: `/orchestrate 505 --implement`
   - Merges new changes with existing grant
   - Preserves unchanged sections
   - Creates backup of original files

**State Fields for Revision Tasks**:
| Field | Type | Description |
|-------|------|-------------|
| `parent_grant` | number | Original grant task number |
| `revises_directory` | string | Path to existing grant directory |

## Grant Writing Components

- **Narrative Sections**: Problem statement, methodology, impact, sustainability
- **Budget Development**: Personnel, equipment, travel, indirect costs
- **Compliance**: Funder-specific requirements, format guidelines, submission procedures
