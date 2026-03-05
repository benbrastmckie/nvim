# Research Report: Task #OC_147

**Task**: OC_147 - fix_artifact_metadata_linking_in_todo
**Started**: 2026-03-05T00:00:00Z
**Completed**: 2026-03-05T01:30:00Z
**Effort**: 4 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of .opencode/skills/, .opencode/agent/subagents/, specs/TODO.md, specs/state.json, .return-meta.json files
**Artifacts**: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- **Root Cause Identified**: The artifact metadata linking system has a **design gap** rather than a single bug - the system relies on skill postflight stages to read `.return-meta.json` files and update TODO.md, but the current skill specifications lack the detailed postflight implementation patterns
- **Key Finding**: state.json artifacts array IS being populated correctly (verified with OC_142 and OC_146), but TODO.md artifact links are inconsistently added
- **Critical Gap**: skill-researcher/SKILL.md does NOT include the detailed postflight patterns found in skill-implementer/SKILL.md (file-metadata-exchange.md, jq-escaping-workarounds.md)
- **Metadata Flow Status**: Subagents ARE creating `.return-meta.json` files correctly, and state.json IS being updated, but TODO.md updates are inconsistent
- **OC_143/OC_144 Connection**: The missing `metadata_file_path` parameter in skill delegation (identified in OC_143/OC_144) is related but separate - agents know where to write metadata, but skills need better postflight patterns to read it and update TODO.md

## Context & Scope

This research investigates why research reports created by subagents are not being properly linked in the artifacts section of TODO.md entries. Instead, report metadata sometimes appears at the bottom of task entries in TODO.md or is missing entirely.

The investigation covers:
1. How artifacts are supposed to be linked in TODO.md
2. The metadata flow: subagent → metadata file → state.json → TODO.md
3. Skill postflight stage implementations
4. Comparison of working vs non-working artifact linking examples

## Findings

### 1. The Metadata Flow Architecture (Working Correctly)

The metadata flow architecture is well-designed and mostly functional:

```
Subagent (general-research-agent)
    ↓ (writes)
.return-meta.json file
    ↓ (skill postflight reads)
Skill Postflight Stage
    ↓ (updates)
state.json artifacts array
    ↓ (should update)
TODO.md artifact links
```

**Verified Working Components**:

1. **Agent Metadata Creation**: Agents correctly write `.return-meta.json` files
   - Location: `specs/{N}_{SLUG}/.return-meta.json`
   - Schema: Follows `return-metadata-file.md` specification
   - Example from OC_146:
     ```json
     {
       "status": "researched",
       "artifacts": [{
         "type": "report",
         "path": "specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md",
         "summary": "Comprehensive research report..."
       }],
       "metadata": {...}
     }
     ```

2. **state.json Artifacts Array**: IS being populated correctly
   - OC_146 has artifacts array with research report
   - OC_142 has artifacts array with research report
   - Both have correct type, path, and summary fields

### 2. The TODO.md Linking Gap (Inconsistent)

**Working Example - OC_146**:
```markdown
### OC_146. Research and implement subagent workflow best practices
- **Effort**: 6-8 hours
- **Status**: [RESEARCHED]
...
**Key Findings**:
- **System Architecture**: Three-layer delegation...
- **Report**: [specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md](specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md)
```

**Non-Working Example - OC_142**:
```markdown
### OC_142. Implement knowledge capture system
- **Effort**: large
- **Status**: [RESEARCHED]
...
**Files to Create/Modify**:
- .opencode/commands/fix.md...
```

**Key Difference**: OC_146 has the artifact link under "Key Findings", but OC_142 has NO artifact link at all, even though both have:
- Research report files that exist
- state.json artifacts array populated
- Status set to [RESEARCHED]

### 3. Skill Postflight Implementation Gap

**Critical Finding**: Skills have inconsistent postflight implementations:

**skill-implementer/SKILL.md** (More Complete):
- Loads `file-metadata-exchange.md` variable
- Loads `jq-escaping-workarounds.md` variable
- Has detailed postflight instructions with jq patterns
- Stage 4: "Update state and link artifacts using {file_metadata} and {jq_workarounds}"

**skill-researcher/SKILL.md** (Less Complete):
- Does NOT load `file-metadata-exchange.md`
- Does NOT load `jq-escaping-workarounds.md`
- Has minimal postflight instructions: "Read metadata file and update state + TODO"
- No detailed jq patterns or artifact linking instructions

**skill-planner/SKILL.md** (Minimal):
- No context_injection for file-metadata-exchange.md
- Minimal postflight: "Update state and link artifacts"

### 4. The Missing metadata_file_path Parameter (Related Issue)

While researching, discovered that OC_143 and OC_144 identify a related but separate issue:

**Issue**: Skills don't pass `metadata_file_path` to agents during delegation

**Current skill-researcher delegation** (lines 74-86):
```markdown
3. **Delegate**:
   - Call `Task` tool with `subagent_type="general-research-agent"`
   - Prompt: """
     Conduct research for task {N}.
     <system_context>
     Using the following format standards:
     {report_format}
     {status_markers}
     </system_context>
     """
```

**Missing**: The prompt does NOT include `metadata_file_path` parameter!

**Agent Expectation** (from general-research-agent.md line 139):
```json
{
  "metadata_file_path": "specs/412_create_general_research_agent/.return-meta.json"
}
```

**Impact**: Agents are expected to know the metadata file path from delegation context, but skills aren't providing it. However, agents appear to be constructing the path correctly anyway (based on task number), so this is a secondary issue.

### 5. TODO.md Artifact Linking Format

From analyzing TODO.md, the artifact linking format appears to be:

```markdown
- **Research**: [path/to/report.md](path/to/report.md) - Brief description
```

Or for plans:
```markdown
- **Plan**: [path/to/plan.md](path/to/plan.md) - Brief description
```

Or for summaries:
```markdown
- **Summary**: [path/to/summary.md](path/to/summary.md) - Brief description
```

The format is a bullet point with bold label, markdown link, and optional description.

### 6. State.json Artifacts Array Structure

From OC_146 state.json entry:
```json
{
  "artifacts": [
    {
      "type": "research",
      "path": "specs/OC_146_research_implement_subagent_workflow_best_practices/reports/research-001.md",
      "summary": "Comprehensive research report on subagent workflow best practices..."
    }
  ]
}
```

The artifacts array IS being populated correctly by skill postflight stages.

## Decisions

1. **Primary Issue**: The main problem is inconsistent skill postflight implementations, not a broken metadata flow
2. **Secondary Issue**: Missing `metadata_file_path` in delegation prompts (addressed in OC_143/OC_144)
3. **Root Cause**: skill-researcher and skill-planner lack detailed postflight patterns compared to skill-implementer
4. **Solution Approach**: Standardize postflight implementations across all skills using the skill-implementer pattern

## Recommendations

### Immediate Fix (OC_147 Implementation)

1. **Update skill-researcher/SKILL.md**:
   - Add `file-metadata-exchange.md` to context_injection
   - Add `jq-escaping-workarounds.md` to context_injection
   - Add detailed postflight instructions using {file_metadata} patterns
   - Include explicit TODO.md artifact linking steps

2. **Update skill-planner/SKILL.md**:
   - Add `file-metadata-exchange.md` to context_injection
   - Add `jq-escaping-workarounds.md` to context_injection
   - Add detailed postflight instructions

3. **Add metadata_file_path to delegation prompts** (as identified in OC_143/OC_144):
   - Update all skill delegation prompts to include:
     ```json
     {
       "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json"
     }
     ```

### Standardization Pattern

All skills should follow the skill-implementer pattern:

```markdown
<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>

<execution>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds}</action>
  </stage>
</execution>
```

### Postflight Implementation Template

Skills should include explicit postflight steps:

```markdown
4. **Postflight**:
   - Read `.return-meta.json` using {file_metadata} patterns
   - Extract artifact information (path, type, summary)
   - Update specs/state.json status and artifacts array
   - Update TODO.md with artifact links:
     - Research reports: `- **Research**: [path](path) - summary`
     - Plans: `- **Plan**: [path](path) - summary`
     - Summaries: `- **Summary**: [path](path) - summary`
   - Git commit changes
   - Clean up marker and metadata files
```

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Multiple skills need updates | High effort | Prioritize skill-researcher first (most visible issue) |
| jq command complexity | Errors in postflight | Use {jq_workarounds} patterns from skill-implementer |
| TODO.md format inconsistencies | Broken links | Standardize on existing format from OC_146 |
| Backward compatibility | Breaking existing workflows | Test with new task before applying to all skills |

## Appendix: Context Knowledge Candidates

### Candidate 1: Skill Postflight Standardization Pattern
**Type**: Pattern
**Domain**: meta-system
**Target Context**: .opencode/context/core/patterns/
**Content**: All skills should include file-metadata-exchange.md and jq-escaping-workarounds.md in context_injection, and use explicit postflight steps for updating TODO.md artifact links.
**Source**: Comparison of skill-implementer vs skill-researcher implementations
**Rationale**: Standardized postflight ensures consistent artifact linking across all workflow commands

### Candidate 2: TODO.md Artifact Linking Format
**Type**: Pattern
**Domain**: documentation
**Target Context**: .opencode/context/core/formats/
**Content**: Artifact links in TODO.md should follow format: `- **Type**: [path](path) - description` where Type is Research/Plan/Summary/Implementation.
**Source**: Analysis of OC_146 TODO.md entry
**Rationale**: Consistent format makes TODO.md scannable and enables automated parsing

### Candidate 3: Metadata File Path Construction
**Type**: Pattern
**Domain**: meta-system
**Target Context**: .opencode/context/core/patterns/
**Content**: Metadata file path follows pattern: `specs/{N}_{SLUG}/.return-meta.json` where N is task number and SLUG is project_name from state.json.
**Source**: return-metadata-file.md specification
**Rationale**: Standardized path enables both skills and agents to know where to read/write metadata
