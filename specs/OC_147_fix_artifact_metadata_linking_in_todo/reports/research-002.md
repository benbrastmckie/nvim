# Research Report: Task #OC_147

**Task**: OC_147 - fix_artifact_metadata_linking_in_todo
**Started**: 2026-03-05T00:00:00Z
**Completed**: 2026-03-05T02:00:00Z
**Effort**: 4 hours
**Dependencies**: None
**Sources/Inputs**: .claude/skills/, .opencode/skills/, .claude/agents/, .claude/context/core/patterns/, .opencode/context/core/patterns/, specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md
**Artifacts**: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md
**Standards**: report-format.md, status-markers.md

## Executive Summary

- **.claude/ System**: Fully mature file-metadata-exchange pattern with 11-stage skill postflight, detailed jq patterns, TODO.md artifact linking, and comprehensive error handling
- **.opencode/ System**: Simplified XML-based skill definitions with minimal postflight instructions, missing file-metadata-exchange patterns in skill-researcher and skill-planner
- **Key Gap**: .opencode/ skills lack the detailed postflight implementations that .claude/ skills have, particularly for TODO.md artifact linking
- **Root Cause**: .opencode/ skill-researcher and skill-planner do NOT include `file-metadata-exchange.md` and `jq-escaping-workarounds.md` in context_injection, while skill-implementer does
- **Recommendation**: Standardize .opencode/ skills to match .claude/ pattern by adding missing context files and detailed postflight steps

## Context & Scope

This research compares metadata passing mechanisms between the .claude/ and .opencode/ agent systems to understand:
1. How .claude/ passes metadata (file-metadata-exchange patterns)
2. How .opencode/ currently passes metadata
3. Key differences and improvement opportunities
4. Root cause of artifact metadata linking issues in TODO.md

## Findings

### 1. .claude/ System: Mature File-Metadata-Exchange Pattern

The .claude/ system has a comprehensive, battle-tested metadata passing architecture:

#### Skill Structure (skill-researcher example)
- **11 explicit stages** with detailed bash/jq implementations
- **Stage 0**: Early metadata creation (before any work)
- **Stage 6**: Parse subagent return (read metadata file)
- **Stage 8**: Link artifacts with TODO.md updates
- **Stage 10**: Cleanup marker and metadata files

#### Context References (All Skills)
All .claude/ skills reference these context files:
```markdown
- Path: `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/core/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
```

#### Metadata File Handling (Detailed)
```bash
# Stage 6: Parse Subagent Return (Read Metadata File)
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

#### Artifact Linking (TODO.md Updates)
```bash
# Stage 8: Link Artifacts - Add to state.json with two-step jq pattern
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern to avoid != escaping)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
fi

# Update TODO.md: Add research artifact link
# - **Research**: [research-{NNN}.md]({artifact_path})
```

#### Delegation Context (Includes metadata_file_path)
```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-researcher"],
  "timeout": 3600,
  "task_context": { ... },
  "focus_prompt": "{optional focus}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

### 2. .opencode/ System: Simplified XML-Based Skills

The .opencode/ system uses a more compact XML-style skill definition but lacks detailed postflight implementations:

#### Skill Structure (skill-researcher example)
- **4 high-level stages**: LoadContext, Preflight, Delegate, Postflight
- **Minimal postflight**: "Read metadata file and update state + TODO"
- **No detailed jq patterns**: References {file_metadata} and {jq_workarounds} variables but doesn't define them in context_injection

#### Context Injection (INCONSISTENT across skills)

**skill-researcher** (MISSING key files):
```xml
<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>
```

**skill-planner** (MISSING key files):
```xml
<context_injection>
  <file path=".opencode/context/core/formats/plan-format.md" variable="plan_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/workflows/task-breakdown.md" variable="task_breakdown" />
</context_injection>
```

**skill-implementer** (COMPLETE - has all files):
```xml
<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>
```

#### Postflight Stage (Minimal Instructions)
```xml
<stage id="4" name="Postflight">
  <action>Update state and link artifacts</action>
</stage>
```

Compare to skill-implementer:
```xml
<stage id="4" name="Postflight">
  <action>Update state and link artifacts using {file_metadata} and {jq_workarounds} patterns</action>
</stage>
```

#### Delegation Prompt (MISSING metadata_file_path)
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

### 3. Side-by-Side Comparison Table

| Aspect | .claude/ System | .opencode/ System | Gap |
|--------|-----------------|-------------------|-----|
| **Skill Format** | Markdown with bash examples | XML-style tags | Different paradigms |
| **Stages** | 11 detailed stages | 4 high-level stages | Less granularity |
| **Context Files** | 4 files referenced by all skills | Inconsistent (researcher/planner missing key files) | **CRITICAL GAP** |
| **file-metadata-exchange.md** | Referenced by all skills | Only in skill-implementer | Missing in researcher/planner |
| **jq-escaping-workarounds.md** | Referenced by all skills | Only in skill-implementer | Missing in researcher/planner |
| **Postflight Detail** | Detailed bash/jq code | High-level description | Implementation gap |
| **TODO.md Linking** | Explicit artifact linking steps | "Update state + TODO" (vague) | **ROOT CAUSE** |
| **metadata_file_path** | Included in delegation | Missing in delegation | Secondary issue |
| **Early Metadata** | Stage 0 pattern | Not specified | Resilience gap |
| **Cleanup** | Explicit file removal | Not specified | Orphaned files risk |
| **Error Handling** | Detailed per-stage | Minimal | Robustness gap |

### 4. Metadata File Schema Comparison

Both systems use nearly identical schemas (copied from .claude/):

**.claude/ return-metadata-file.md**:
- Path: `specs/{NNN}_{SLUG}/.return-meta.json` (zero-padded)
- Status values: researched, planned, implemented, partial, failed, blocked
- Artifacts array with type, path, summary
- Metadata object with session_id, agent_type, delegation info
- completion_data for implemented status

**.opencode/ return-metadata-file.md**:
- Path: `specs/{N}_{SLUG}/.return-meta.json` (unpadded)
- Same status values
- Same artifacts structure
- Same metadata object
- completion_data with readme_suggestions (instead of claudemd_suggestions)

**Key Difference**: .claude/ uses zero-padded task numbers in paths (`{NNN}`), .opencode/ uses unpadded (`{N}`). Both work but are inconsistent.

### 5. File-Metadata-Exchange Patterns Comparison

**.claude/ file-metadata-exchange.md** (301 lines):
- Writing patterns: Direct JSON, jq construction, Claude Write tool
- Reading patterns: Full object read, field extraction, validation
- Cleanup patterns: After success, with verification, emergency cleanup
- Error handling: Missing file, invalid JSON, missing required fields
- Complete skill postflight example (50+ lines of bash)

**.opencode/ file-metadata-exchange.md** (301 lines, nearly identical):
- Same patterns as .claude/
- Same error handling
- Same complete example
- Only difference: "OpenCode Write tool" instead of "Claude Write tool"

**The patterns exist in .opencode/ but are NOT referenced by skill-researcher or skill-planner!**

### 6. Root Cause Analysis: Why TODO.md Links Are Missing

Based on the comparison, the root cause is clear:

```
┌─────────────────────────────────────────────────────────────────┐
│  ROOT CAUSE CHAIN                                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. skill-researcher MISSING context files:                      │
│     - file-metadata-exchange.md                                  │
│     - jq-escaping-workarounds.md                                 │
│                                                                  │
│  2. Postflight stage has NO detailed instructions:             │
│     - "Update state and link artifacts" (too vague)              │
│     - No TODO.md linking format specified                        │
│     - No jq patterns for artifact array manipulation           │
│                                                                  │
│  3. Result: Skill postflight updates state.json correctly:     │
│     (artifacts array IS populated - verified in OC_146, OC_142)  │
│                                                                  │
│  4. But TODO.md artifact links are INCONSISTENT:               │
│     - OC_146: Has "**Key Findings**: [report](path)"           │
│     - OC_142: NO artifact link despite having report             │
│                                                                  │
│  5. Conclusion: Skills need explicit TODO.md linking steps     │
│     (as defined in .claude/ Stage 8)                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 7. Agent Definitions Comparison

**.claude/ general-research-agent.md** (450 lines):
- Comprehensive agent definition
- Stage 0: Early metadata creation
- Detailed execution flow
- Context discovery via index.json
- Error handling for network, timeout, interruption
- Return format: brief text summary (NOT JSON)
- Critical requirements list (10 MUST DO, 10 MUST NOT)

**.opencode/ general-research-agent.md**: **DOES NOT EXIST**

The .opencode/ system appears to use the .claude/ agent definitions directly, or agents are created dynamically. This is a significant architectural difference.

## Decisions

1. **Primary Issue**: .opencode/ skill-researcher and skill-planner lack the detailed postflight patterns that .claude/ skills have
2. **Secondary Issue**: Missing `metadata_file_path` in delegation prompts (less critical since agents construct path correctly)
3. **Standardization Decision**: .opencode/ skills should adopt the .claude/ pattern of including all 4 context files
4. **Path Inconsistency**: Decide on zero-padded vs unpaded task numbers (recommend zero-padded for sorting)
5. **Agent Definitions**: .opencode/ may need its own agent definitions or should explicitly reference .claude/ agents

## Recommendations

### Immediate Fix for .opencode/ Skills

Update skill-researcher/SKILL.md and skill-planner/SKILL.md to match skill-implementer pattern:

```xml
<context_injection>
  <!-- Existing files -->
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  
  <!-- ADD THESE (from skill-implementer): -->
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>
```

### Enhanced Postflight Stage

Update postflight to use the variables:

```xml
<stage id="4" name="Postflight">
  <action>Read metadata file using {file_metadata} patterns</action>
  <action>Update state.json using {jq_workarounds} for artifact array</action>
  <action>Update TODO.md with artifact links: - **Research**: [path](path)</action>
  <action>Commit changes and cleanup using {postflight_control}</action>
</stage>
```

### Add metadata_file_path to Delegation

Update delegation prompts to include:

```markdown
3. **Delegate**:
   - Call `Task` tool with `subagent_type="general-research-agent"`
   - Prompt: """
     Conduct research for task {N}.
     
     Metadata file path: specs/{N}_{SLUG}/.return-meta.json
     
     <system_context>
     Using the following format standards:
     {report_format}
     {status_markers}
     {return_metadata}
     </system_context>
     """
```

### Standardize Path Format

Recommend zero-padded task numbers for consistent sorting:
- Change: `specs/{N}_{SLUG}/.return-meta.json`
- To: `specs/{NNN}_{SLUG}/.return-meta.json`

Update all references in:
- .opencode/context/core/formats/return-metadata-file.md
- .opencode/context/core/patterns/file-metadata-exchange.md
- All skill files

### Create .opencode/ Agent Definitions

If .opencode/ is meant to be independent, create:
- .opencode/agents/general-research-agent.md
- .opencode/agents/planner-agent.md
- .opencode/agents/general-implementation-agent.md

Base these on .claude/ versions but adapted for OpenCode conventions.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Updating multiple skills | High effort | Start with skill-researcher (most visible impact) |
| jq command complexity | Errors in postflight | Use {jq_workarounds} patterns already defined |
| Path format change | Breaking existing tasks | Update path construction in one place, test thoroughly |
| TODO.md format inconsistencies | Broken links | Standardize on .claude/ format: `- **Type**: [path](path)` |
| Missing agent definitions | Undefined behavior | Either create .opencode/ agents or explicitly reference .claude/ agents |

## Appendix: Context Knowledge Candidates

### Candidate 1: Skill Postflight Standardization Pattern
**Type**: Pattern
**Domain**: meta-system
**Target Context**: .opencode/context/core/patterns/
**Content**: All skills should include file-metadata-exchange.md, jq-escaping-workarounds.md, return-metadata-file.md, and postflight-control.md in context_injection. Postflight stages should explicitly reference these patterns for metadata reading, state updates, TODO.md linking, and cleanup.
**Source**: Comparison of .claude/ vs .opencode/ skill implementations
**Rationale**: Standardized postflight ensures consistent artifact linking across all workflow commands

### Candidate 2: TODO.md Artifact Linking Format
**Type**: Pattern
**Domain**: documentation
**Target Context**: .opencode/context/core/formats/
**Content**: Artifact links in TODO.md should follow format: `- **Type**: [path](path) - description` where Type is Research/Plan/Summary/Implementation. This format is scannable and enables automated parsing.
**Source**: .claude/ skill-implementer Stage 8 and OC_146 TODO.md entry
**Rationale**: Consistent format makes TODO.md useful as a dashboard and enables automation

### Candidate 3: Metadata File Path Standardization
**Type**: Pattern
**Domain**: meta-system
**Target Context**: .opencode/context/core/patterns/
**Content**: Metadata file path should use zero-padded task numbers: `specs/{NNN}_{SLUG}/.return-meta.json` where NNN is 3-digit zero-padded. This ensures lexicographic sorting works correctly.
**Source**: .claude/ system uses {NNN}, .opencode/ uses {N}
**Rationale**: Zero-padding enables proper sorting in file listings and aligns with artifact naming conventions

### Candidate 4: Early Metadata Pattern
**Type**: Pattern
**Domain**: meta-system
**Target Context**: .opencode/context/core/patterns/
**Content**: Agents should write metadata with `status: "in_progress"` at Stage 0 (before substantive work). This ensures metadata exists even if agent is interrupted, enabling skill postflight to detect interruption and provide resume guidance.
**Source**: .claude/agents/general-research-agent.md Stage 0
**Rationale**: Resilience pattern for handling agent interruptions and timeouts

## References

- .claude/skills/skill-researcher/SKILL.md (311 lines, comprehensive)
- .claude/skills/skill-implementer/SKILL.md (402 lines, comprehensive)
- .claude/skills/skill-planner/SKILL.md (338 lines, comprehensive)
- .claude/agents/general-research-agent.md (450 lines, detailed)
- .claude/context/core/patterns/file-metadata-exchange.md (301 lines)
- .claude/context/core/formats/return-metadata-file.md (502 lines)
- .opencode/skills/skill-researcher/SKILL.md (90 lines, minimal)
- .opencode/skills/skill-implementer/SKILL.md (116 lines, moderate)
- .opencode/skills/skill-planner/SKILL.md (93 lines, minimal)
- .opencode/context/core/patterns/file-metadata-exchange.md (301 lines, unused)
- .opencode/context/core/formats/return-metadata-file.md (396 lines)
- specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md (previous research)
