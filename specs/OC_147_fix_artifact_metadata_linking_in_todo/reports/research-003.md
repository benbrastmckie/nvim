# Research Report: Task #OC_147

**Task**: OC_147 - fix_artifact_metadata_linking_in_todo  
**Started**: 2026-03-05T00:00:00Z  
**Completed**: 2026-03-05T03:00:00Z  
**Effort**: 3 hours  
**Dependencies**: None  
**Sources/Inputs**: 
- specs/TODO.md (OC_147 entry analysis)
- specs/state.json (OC_147 artifacts array)
- specs/OC_147_fix_artifact_metadata_linking_in_todo/.return-meta.json
- specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md
- specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md
- .opencode/skills/skill-researcher/SKILL.md
- .opencode/skills/skill-implementer/SKILL.md (comparison)
- .opencode/context/core/patterns/file-metadata-exchange.md
- .opencode/context/core/patterns/jq-escaping-workarounds.md
**Artifacts**: specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-003.md  
**Standards**: report-format.md  

---

## Executive Summary

**CRITICAL FINDING**: The artifact linking problem for OC_147 is a **systemic skill specification gap**, not a one-off error. The skill-researcher SKILL.md lacks detailed postflight instructions found in skill-implementer, causing inconsistent TODO.md artifact linking across all research tasks.

**Key Findings**:
- **Root Cause**: skill-researcher SKILL.md Stage 4 (Postflight) has only vague instructions: "Update state and link artifacts"
- **Missing Patterns**: skill-researcher does NOT reference `file-metadata-exchange.md` or `jq-escaping-workarounds.md` in context_injection
- **OC_147 Specific Issue**: research-002.md exists but is NOT linked in TODO.md; state.json only has research-001.md; .return-meta.json references research-002.md
- **Comparison**: skill-implementer has COMPLETE postflight patterns and properly links artifacts
- **Scope**: This affects ALL research tasks, not just OC_147

**Immediate Fix Required**: Update skill-researcher SKILL.md to include detailed postflight instructions matching skill-implementer pattern.

---

## Context & Scope

This research investigates the specific artifact linking problems reported for task OC_147:
1. research-001.md appears at bottom of task description instead of in a proper artifacts section
2. research-002.md was not linked in TODO.md at all
3. Artifact links appear inline rather than in a standardized format

The investigation expanded to understand the systemic root cause affecting all research tasks.

---

## Current State Analysis: OC_147

### 1. TODO.md Entry (Lines 9-31)

```markdown
### OC_147. Fix artifact metadata linking in TODO.md
- **Effort**: 4-6 hours
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None

**Description**: Research reports created by subagents are not being properly linked in the artifacts section of tasks...

**Key Findings**:
- **Root Cause**: Inconsistent skill postflight implementations - skill-researcher lacks detailed postflight patterns found in skill-implementer
- **Metadata Flow**: Core architecture working - agents create `.return-meta.json`, state.json IS populated
- **TODO.md Gap**: Artifact links appear inconsistently due to missing standardized postflight instructions
- **Solution**: Update skill-researcher and skill-planner with file-metadata-exchange.md and jq-escaping-workarounds.md patterns
- **Research**: [specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md](specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md)
```

**Issues Identified**:
- [✗] NO dedicated "## Artifacts" section exists in TODO.md for any task
- [✗] research-001.md is linked inline under "Key Findings" (line 30)
- [✗] research-002.md is NOT linked anywhere in TODO.md
- [✗] Link format is inconsistent with other tasks

### 2. state.json Artifacts Array (Lines 11-17)

```json
"artifacts": [
  {
    "type": "research",
    "path": "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md",
    "summary": "Comprehensive research report identifying root cause of artifact metadata linking issues..."
  }
]
```

**Issues Identified**:
- [✗] Only research-001.md is listed
- [✗] research-002.md is NOT in the artifacts array despite existing
- [✗] research-003.md (this report) will also need to be added

### 3. .return-meta.json Content

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md",
      "summary": "Comprehensive comparative analysis..."
    }
  ],
  "next_steps": "Run /plan OC_147 to create implementation plan...",
  "metadata": { ... }
}
```

**Issues Identified**:
- [✗] References research-002.md, but state.json has research-001.md
- [✗] This mismatch indicates postflight did not properly sync to state.json
- [✗] File was not cleaned up after postflight (still exists)

### 4. Report Files Status

| Report | File Exists | In TODO.md | In state.json | In .return-meta.json |
|--------|-------------|------------|---------------|----------------------|
| research-001.md | [✓] YES | [✓] YES (line 30) | [✓] YES | [✗] NO |
| research-002.md | [✓] YES | [✗] NO | [✗] NO | [✓] YES |
| research-003.md | [✓] YES | [✗] NO | [✗] NO | [✗] NO |

**Critical Inconsistency**: The three sources (TODO.md, state.json, .return-meta.json) are NOT synchronized, indicating the postflight stage is not properly updating all three locations.

---

## Root Cause Analysis

### 1. skill-researcher SKILL.md Postflight Gap

**Current Stage 4 (Lines 42-44)**:
```xml
<stage id="4" name="Postflight">
  <action>Update state and link artifacts</action>
</stage>
```

**Problem**: This is **TOO VAGUE**. It does not specify:
- HOW to read the .return-meta.json file
- HOW to update state.json artifacts array
- HOW to add artifact links to TODO.md
- WHAT format to use for TODO.md links
- HOW to handle jq escaping issues

### 2. Missing Context Files in skill-researcher

**skill-researcher context_injection (Lines 18-26)**:
```xml
<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>
```

**MISSING Files** (compared to skill-implementer):
- [✗] `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- [✗] `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol  
- [✗] `.opencode/context/core/patterns/file-metadata-exchange.md` - File I/O helpers
- [✗] `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns

### 3. Comparison: skill-implementer (Working Example)

**skill-implementer context_injection (Lines 18-28)**:
```xml
<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>
```

**skill-implementer Postflight (Lines 44-50)**:
```xml
<stage id="4" name="Postflight">
  <action>Update state and link artifacts using {file_metadata} and {jq_workarounds} patterns</action>
</stage>
<stage id="5" name="PostflightVerification">
  <action>Verify phase status consistency between plan file and metadata</action>
</stage>
```

**skill-implementer also has**:
- Detailed Execution Flow section (Lines 65-88)
- Validation Checklist (Lines 105-111)
- Phase Verification Details (Lines 89-103)

### 4. Root Cause Chain

```
┌─────────────────────────────────────────────────────────────────┐
│  ROOT CAUSE CHAIN FOR OC_147 ARTIFACT LINKING FAILURE          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. skill-researcher MISSING context files:                    │
│     - file-metadata-exchange.md (301 lines of patterns)        │
│     - jq-escaping-workarounds.md (229 lines of patterns)       │
│                                                                  │
│  2. Postflight stage has NO detailed implementation:             │
│     - "Update state and link artifacts" (4 words)                │
│     - No jq commands for state.json updates                      │
│     - No TODO.md linking format specified                        │
│     - No artifact array manipulation patterns                    │
│                                                                  │
│  3. When research-002.md was created:                          │
│     - Agent wrote .return-meta.json correctly                  │
│     - Skill postflight did NOT read metadata file properly     │
│     - Skill did NOT update state.json artifacts array          │
│     - Skill did NOT add link to TODO.md                        │
│                                                                  │
│  4. Result: Three-way mismatch                                  │
│     - .return-meta.json: references research-002.md            │
│     - state.json: only has research-001.md                     │
│     - TODO.md: only links research-001.md                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Comparison with Working Tasks

### Task OC_141 (Working Example)

**TODO.md Lines 172-193**:
```markdown
### OC_141. Fix agent delegation system failure
- **Summary**: [implementation-summary-20260306.md](OC_141_fix_agent_delegation_system_failure/summaries/implementation-summary-20260306.md)
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
...
- **Research**: [research-001.md](OC_141_fix_agent_delegation_system_failure/reports/research-001.md) - Critical system failure: Skills displayed instead of executed
- **Plan**: [implementation-001.md](OC_141_fix_agent_delegation_system_failure/plans/implementation-001.md) - 7-phase systematic audit and fix of skill-to-agent delegation
```

**Why OC_141 Works**:
- Uses skill-implementer (which has complete postflight patterns)
- Artifact links are inline under specific sections (Summary, Research, Plan)
- state.json has all artifacts properly listed (Lines 614-629)

### Task OC_146 (Partially Working)

**TODO.md Lines 46-53**:
```markdown
**Key Findings**:
- **System Architecture**: Three-layer delegation...
- **Report**: [specs/OC_146_.../reports/research-001.md](specs/OC_146_.../reports/research-001.md)
```

**Issue**: Only ONE research report linked, but multiple may exist.

---

## Specific Files and Lines Requiring Fixes

### 1. skill-researcher/SKILL.md (CRITICAL)

**File**: `.opencode/skills/skill-researcher/SKILL.md`

**Lines 18-26 - ADD Missing Context Files**:
```xml
<!-- CURRENT -->
<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
</context_injection>

<!-- REQUIRED -->
<context_injection>
  <file path=".opencode/context/core/formats/report-format.md" variable="report_format" />
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/standards/status-markers.md" variable="status_markers" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>
```

**Lines 42-44 - EXPAND Postflight Stage**:
```xml
<!-- CURRENT -->
<stage id="4" name="Postflight">
  <action>Update state and link artifacts</action>
</stage>

<!-- REQUIRED -->
<stage id="4" name="Postflight">
  <action>Read metadata file using {file_metadata} patterns, update state.json artifacts array using {jq_workarounds} patterns, add artifact link to TODO.md</action>
</stage>
<stage id="5" name="PostflightVerification">
  <action>Verify metadata file cleaned up, state.json updated, TODO.md has artifact link</action>
</stage>
```

**Lines 87-90 - ADD Detailed Postflight Instructions**:
```markdown
4. **Postflight**:
   - Read metadata file from `specs/{N}_{SLUG}/.return-meta.json` using {file_metadata} patterns
   - Extract artifact path, type, and summary from metadata
   - Update state.json:
     * Step 1: Update status to "researched" and set last_updated timestamp
     * Step 2: Add artifact to artifacts array using two-step jq pattern from {jq_workarounds}
   - Update TODO.md:
     * Add artifact link under "## Artifacts" section OR inline under "**Research**:"
     * Format: `- **Research**: [reports/research-NNN.md]({artifact_path}) - {summary}`
   - Git commit with message: "task {N}: research complete"
   - Cleanup: Remove `.return-meta.json` file

5. **PostflightVerification**:
   - Verify metadata file no longer exists
   - Verify state.json has artifact in artifacts array
   - Verify TODO.md has artifact link
```

### 2. TODO.md - Fix OC_147 Entry

**File**: `specs/TODO.md`

**Line 30 - UPDATE research-001.md link format**:
```markdown
<!-- CURRENT -->
- **Research**: [specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md](specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md)

<!-- REQUIRED - Add summary -->
- **Research**: [research-001.md](OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md) - Comprehensive research report identifying root cause of artifact metadata linking issues
```

**After Line 30 - ADD research-002.md link**:
```markdown
- **Research**: [research-002.md](OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md) - Comparative analysis of .claude/ vs .opencode/ metadata passing mechanisms
- **Research**: [research-003.md](OC_147_fix_artifact_metadata_linking_in_todo/reports/research-003.md) - Deep dive investigation of OC_147 specific linking problems and systemic fixes
```

### 3. state.json - Fix OC_147 Artifacts Array

**File**: `specs/state.json`

**Lines 11-17 - ADD Missing Artifacts**:
```json
"artifacts": [
  {
    "type": "research",
    "path": "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-001.md",
    "summary": "Comprehensive research report identifying root cause of artifact metadata linking issues..."
  },
  {
    "type": "research", 
    "path": "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-002.md",
    "summary": "Comparative analysis of .claude/ vs .opencode/ metadata passing mechanisms..."
  },
  {
    "type": "research",
    "path": "specs/OC_147_fix_artifact_metadata_linking_in_todo/reports/research-003.md", 
    "summary": "Deep dive investigation of OC_147 specific linking problems and systemic fixes"
  }
]
```

---

## Step-by-Step Fix Instructions

### Phase 1: Fix skill-researcher SKILL.md (Priority: CRITICAL)

1. **Read** `.opencode/skills/skill-researcher/SKILL.md`
2. **Edit** Lines 18-26: Add missing context files to context_injection
3. **Edit** Lines 42-44: Expand Postflight stage with detailed actions
4. **Add** new Stage 5 for PostflightVerification
5. **Add** detailed postflight instructions after Line 90 (after "Link research artifact and commit")
6. **Write** updated SKILL.md file
7. **Commit** with message: "fix(skill-researcher): add detailed postflight patterns for artifact linking"

### Phase 2: Fix OC_147 TODO.md Entry (Priority: HIGH)

1. **Read** `specs/TODO.md` lines 9-31
2. **Edit** Line 30: Update research-001.md link format to include summary
3. **Add** After Line 30: Add research-002.md and research-003.md links
4. **Write** updated TODO.md
5. **Commit** with message: "docs(todo): add missing research report links for OC_147"

### Phase 3: Fix OC_147 state.json Artifacts (Priority: HIGH)

1. **Read** `specs/state.json` lines 11-17
2. **Edit**: Add research-002.md and research-003.md to artifacts array
3. **Write** updated state.json
4. **Commit** with message: "fix(state): sync OC_147 artifacts array with actual reports"

### Phase 4: Cleanup .return-meta.json (Priority: MEDIUM)

1. **Verify** postflight completed successfully
2. **Remove** `specs/OC_147_fix_artifact_metadata_linking_in_todo/.return-meta.json`
3. **Commit** with message: "chore(cleanup): remove completed task metadata file"

### Phase 5: Audit Other Research Tasks (Priority: MEDIUM)

1. **Search** for all tasks with status "researched" in state.json
2. **Verify** each has artifact links in TODO.md
3. **Add** missing links where needed
4. **Update** skill-planner with same patterns if needed

---

## Decisions Made

1. **TODO.md Format**: Artifact links should be inline under "**Research**:" rather than in a separate "## Artifacts" section (no such sections currently exist in TODO.md)

2. **Link Format**: Use relative path format `[research-NNN.md]({task_path}/reports/research-NNN.md) - {summary}` for consistency with OC_141

3. **Priority**: Fix skill-researcher SKILL.md first (systemic fix), then fix OC_147 specifically

4. **Scope**: This affects ALL research tasks, so the skill fix will prevent future occurrences

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Editing SKILL.md breaks other functionality | Medium | High | Test with /research command on a test task after fix |
| jq patterns in postflight have escaping issues | Medium | Medium | Use tested patterns from jq-escaping-workarounds.md |
| TODO.md format inconsistent across tasks | High | Low | Standardize on OC_141 format as reference |
| Multiple .return-meta.json files orphaned | Medium | Low | Audit and cleanup all specs/*/.return-meta.json files |

---

## Appendix: Context Knowledge Candidates

### Candidate 1: File-Based Metadata Exchange Pattern
**Type**: Pattern  
**Domain**: agent-orchestration  
**Target Context**: `.opencode/context/core/patterns/file-metadata-exchange.md`  
**Content**: Skills must include `file-metadata-exchange.md` and `jq-escaping-workarounds.md` in context_injection to properly handle postflight metadata reading and state updates.  
**Source**: Comparison of skill-implementer (working) vs skill-researcher (broken)  
**Rationale**: This is a domain-general pattern applicable to all skills that delegate to subagents

### Candidate 2: TODO.md Artifact Linking Format
**Type**: Pattern  
**Domain**: documentation  
**Target Context**: `.opencode/context/core/formats/todo-format.md` (to be created)  
**Content**: Artifact links should use format: `- **Type**: [filename.md](path/to/filename.md) - Summary description`  
**Source**: OC_141 working example  
**Rationale**: Standardizes artifact linking across all tasks for consistency

---

## Related Tasks

- **OC_143**: Fix skill-researcher TODO.md linking regression (specific instance of this systemic issue)
- **OC_144**: Fix systemic metadata delegation across all skills (broader scope including planner and implementer)
- **OC_146**: Research subagent workflow best practices (identified this pattern gap)

---

*Report generated by general-research-agent following report-format.md standards*
