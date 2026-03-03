# Research Workflow

**Version**: 1.0.0  
**Created**: 2025-12-29  
**Purpose**: Detailed research workflow for conducting research and creating reports

---

## Overview

This document describes the complete research workflow executed by the researcher subagent. It covers language-based routing, research execution, and report creation.

---

## Research Modes

### General Research

**When**: Task language is markdown, python, or general  
**Agent**: researcher  
**Tools**:
- Web search
- Documentation review
- File analysis
- API exploration

### Lean Research

**When**: Task language is lean  
**Agent**: lean-research-agent  
**Tools**:
- LeanExplore (explore Mathlib)
- Loogle (search by type signature)
- LeanSearch (semantic search)
- lean-lsp-mcp (LSP integration)
- Web search
- Documentation review

---

## Language-Based Routing

### Language Extraction

Language is extracted from task entry in specs/TODO.md:

```bash
grep -A 20 "^### ${task_number}." specs/TODO.md | grep "Language" | sed 's/\*\*Language\*\*: //'
```

**Fallback**: If extraction fails, defaults to "general" with warning logged.

### Routing Rules

| Language | Agent | Tools Available |
|----------|-------|----------------|
| `lean` | `lean-research-agent` | LeanExplore, Loogle, LeanSearch, lean-lsp-mcp, web search |
| `markdown` | `researcher` | Web search, documentation review |
| `python` | `researcher` | Web search, documentation review, API docs |
| `general` | `researcher` | Web search, documentation review |

**Critical**: Language extraction MUST occur before routing. Incorrect routing bypasses Lean-specific tooling.

---

## Detailed Workflow Steps

### Step 1: Load Task and Determine Scope

**Action**: Load task details and determine research scope

**Process**:
1. Read task from specs/TODO.md using grep (selective loading):
   ```bash
   grep -A 50 "^### ${task_number}." specs/TODO.md > /tmp/task-${task_number}.md
   ```
2. Extract task metadata:
   - Task number
   - Task title
   - Language
   - Description
   - Research focus (if specified in prompt)
3. Determine research scope:
   - Broad: General exploration of topic
   - Focused: Specific questions to answer
   - Deep: Comprehensive analysis
4. Identify research questions:
   - Extract from task description
   - Extract from acceptance criteria
   - Extract from user prompt (if provided)
5. Determine research approach:
   - Literature review
   - API exploration
   - Code analysis
   - Tool investigation

**Checkpoint**: Task loaded and research scope determined

### Step 2: Conduct Research

#### For General Research:

**Action**: Conduct research using general tools

**Process**:
1. Web search for relevant information:
   - Search for documentation
   - Search for tutorials
   - Search for examples
   - Search for best practices
2. Review documentation:
   - Official docs
   - API references
   - Guides and tutorials
3. Analyze code examples:
   - GitHub repositories
   - Stack Overflow
   - Blog posts
4. Synthesize findings:
   - Key concepts
   - Relevant APIs/libraries
   - Implementation approaches
   - Best practices
   - Potential pitfalls

#### For Lean Research:

**Action**: Conduct research using Lean-specific tools

**Process**:
1. Use LeanExplore to explore Mathlib:
   - Search for relevant modules
   - Explore type hierarchies
   - Find related theorems
2. Use Loogle for type-based search:
   - Search by type signature
   - Find functions with specific types
   - Discover relevant lemmas
3. Use LeanSearch for semantic search:
   - Search by natural language description
   - Find theorems by concept
   - Discover related proofs
4. Use lean-lsp-mcp for code analysis:
   - Analyze existing code
   - Check type information
   - Explore dependencies
5. Review Lean documentation:
   - Mathlib docs
   - Lean 4 manual
   - Theorem proving guides
6. Synthesize findings:
   - Relevant Mathlib modules
   - Applicable theorems
   - Proof strategies
   - Type definitions
   - Tactic recommendations

**Checkpoint**: Research conducted

### Step 3: Create Research Report

**Action**: Write research report documenting findings

**Process**:
1. Create research report file:
   - Path: `specs/{number}_{slug}/reports/research-001.md`
   - Directory created lazily when writing
2. Write report sections:
   - **Overview**: Research objective and scope
   - **Research Questions**: Questions addressed
   - **Findings**: Key discoveries organized by topic
   - **Relevant Documentation**: Links and references
   - **Recommendations**: Suggested approach for implementation
   - **Technical Details**: Specific APIs, functions, theorems, etc.
   - **Considerations**: Potential issues, trade-offs, alternatives
   - **Next Steps**: Recommended actions
3. For Lean research, include:
   - Mathlib modules to use
   - Relevant theorems and lemmas
   - Type definitions needed
   - Tactic strategies
   - Example code snippets
4. Validate report:
   - All research questions addressed
   - Findings are clear and actionable
   - Recommendations are specific
   - References are accurate
   - NO EMOJI (per documentation standards)

**Report Quality Standards**:
- Comprehensive coverage of topic
- Relevant documentation and references cited
- Clear recommendations for implementation
- Technical details and considerations documented
- NO EMOJI (per documentation.md standards)

**Checkpoint**: Research report created

### Step 4: Create Summary (Optional)

**Action**: Create summary artifact if needed

**Process**:
1. Determine if summary needed:
   - If report is long (>500 lines): Create summary
   - If report is concise (<500 lines): No summary needed
2. If summary needed:
   - Path: `specs/{number}_{slug}/summaries/research-summary.md`
   - Content: 3-5 sentence overview of findings
   - Token limit: <100 tokens (~400 characters)
   - Purpose: Protect orchestrator context window

**Summary vs Report**:
- Summary: Brief overview for orchestrator (<100 tokens)
- Report: Full findings for implementation (no token limit)

**Checkpoint**: Summary created if needed

### Step 5: Update Status

**Action**: Update task status to [RESEARCHED]

**Process**:
1. Delegate to status-sync-manager for atomic update:
   - Prepare update payload:
     ```json
     {
       "operation": "research_complete",
       "task_number": {number},
       "status": "researched",
       "research_path": "{report_path}",
       "research_metadata": {
         "findings_count": {count},
         "recommendations_count": {count}
       }
     }
     ```
   - Invoke status-sync-manager
   - Wait for return
2. status-sync-manager performs atomic update:
   - Update specs/TODO.md:
     - Status: [NOT STARTED] → [RESEARCHED]
     - Add **Research**: {report_path}
     - Add **Completed**: {date}
   - Update specs/state.json:
     - Update status and timestamps
     - Add research_path
     - Add research_metadata
   - Two-phase commit (all or nothing)
3. Verify atomic update succeeded

**Checkpoint**: Status updated atomically

### Step 6: Create Git Commit

**Action**: Create git commit for research

**Process**:
1. Delegate to git-workflow-manager:
   - Prepare commit payload:
     ```json
     {
       "operation": "research_commit",
       "scope": ["{report_path}", "specs/TODO.md", "specs/state.json"],
       "message": "task {number}: research completed"
     }
     ```
   - Invoke git-workflow-manager
   - Wait for return
2. git-workflow-manager creates commit:
   - Stage report file, specs/TODO.md, specs/state.json
   - Create commit
   - Verify commit created
3. If commit fails:
   - Log error (non-critical)
   - Continue (research already complete)
   - Return success with warning

**Commit Message Format**: `task {number}: research completed`

**Checkpoint**: Git commit created

### Step 7: Prepare Return

**Action**: Format return object per subagent-return-format.md

**Process**:
1. Build return object:
   ```json
   {
     "status": "completed",
     "summary": "Research completed: {brief_findings_overview} (<100 tokens)",
     "artifacts": [
       {
         "type": "research",
         "path": "{report_path}",
         "summary": "Research findings and recommendations"
       }
     ],
     "metadata": {
       "task_number": {number},
       "findings_count": {count},
       "recommendations_count": {count},
       "language": "{language}"
     },
     "session_id": "{session_id}"
   }
   ```
2. Validate return format:
   - Check all required fields present
   - Verify summary <100 tokens
   - Verify session_id matches input
   - Verify report file exists on disk
3. If validation fails:
   - Log error
   - Fix issues
   - Re-validate

**Token Limit**: Summary must be <100 tokens (~400 characters)

**Checkpoint**: Return object prepared

### Step 8: Return

**Action**: Return to command

**Process**:
1. Return formatted object to command
2. Command validates return
3. Command relays to user

**Checkpoint**: Return sent

---

## Topic Subdivision (--divide flag)

### When to Use

Use `--divide` flag when:
- Research topic is broad
- Multiple distinct sub-topics
- Parallel research would be beneficial

### Subdivision Process

1. **Analyze Topic**:
   - Identify natural sub-topics
   - Determine subdivision strategy
   - Estimate research effort per sub-topic

2. **Create Sub-Topics**:
   - Break main topic into 2-5 sub-topics
   - Each sub-topic should be independently researchable
   - Ensure sub-topics cover full scope

3. **Research Sub-Topics**:
   - Research each sub-topic separately
   - Create separate report sections
   - Synthesize findings across sub-topics

4. **Integrate Findings**:
   - Combine findings from all sub-topics
   - Identify cross-cutting themes
   - Create unified recommendations

**Example**:
```bash
/research 197 --divide
```

Topic: "LeanSearch API integration"

Sub-topics:
1. LeanSearch API documentation and capabilities
2. Authentication and rate limiting
3. Query syntax and best practices
4. Integration patterns and examples
5. Error handling and edge cases

---

## Status Transitions

| From | To | Condition |
|------|-----|-----------|
| [NOT STARTED] | [RESEARCHING] | Research started |
| [RESEARCHING] | [RESEARCHED] | Research completed successfully |
| [RESEARCHING] | [RESEARCHING] | Research failed or partial |
| [RESEARCHING] | [BLOCKED] | Research blocked by dependency |

**Status Update**: Delegated to `status-sync-manager` for atomic synchronization across specs/TODO.md and specs/state.json.

**Timestamps**:
- `**Started**: {date}` added when status → [RESEARCHING]
- `**Completed**: {date}` added when status → [RESEARCHED]

---

## Context Loading

### Routing Stage (Command)

Load minimal context for routing decisions:
- `.opencode/context/system/routing-guide.md` (routing logic)

### Execution Stage (Researcher)

Researcher loads context on-demand per `.opencode/context/index.md`:
- `core/standards/subagent-return-format.md` (return format)
- `core/standards/status-markers.md` (status transitions)
- `core/system/artifact-management.md` (lazy directory creation)
- Task entry via `grep -A 50 "^### ${task_number}." specs/TODO.md` (~2KB vs 109KB full file)
- `specs/state.json` (project state)

**Language-specific context**:
- If lean: `project/lean4/tools/leansearch-api.md`, `project/lean4/tools/loogle-api.md`
- If markdown: (no additional context)

**Optimization**: Task extraction reduces context from 109KB to ~2KB, 98% reduction.

---

## Error Handling

### Task Not Found

```
Error: Task {task_number} not found in specs/TODO.md

Recommendation: Verify task number exists in specs/TODO.md
```

### Invalid Task Number

```
Error: Task number must be an integer. Got: {input}

Usage: /research TASK_NUMBER [PROMPT]
```

### Language Extraction Failed

```
Warning: Language not found for task {task_number}, defaulting to 'general'

Proceeding with researcher agent (web search, documentation)
```

### Routing Validation Failed

```
Error: Routing validation failed: language={language}, agent={agent}

Expected: language=lean → agent=lean-research-agent
Got: language=lean → agent=researcher

Recommendation: Fix language extraction or routing logic
```

### Research Timeout

```
Warning: Research timed out after 3600s

Partial artifacts created: {list}

Resume with: /research {task_number}
```

### Status Update Failed

```
Error: Failed to update task status

Details: {error_message}

Artifacts created:
- Research Report: {report_path}

Manual recovery steps:
1. Verify research artifact exists: {report_path}
2. Manually update specs/TODO.md status to [RESEARCHED]
3. Manually update specs/state.json status to "researched"

Or retry: /research {task_number}
```

### Git Commit Failed (non-critical)

```
Warning: Git commit failed

Research completed successfully: {report_path}
Task status updated to [RESEARCHED]

Manual commit required:
  git add {files}
  git commit -m "task {number}: research completed"

Error: {git_error}
```

---

## Quality Standards

### Research Report Quality

- Comprehensive coverage of topic
- Relevant documentation and references cited
- Clear recommendations for implementation
- Technical details and considerations documented
- NO EMOJI (per documentation.md standards)

### Status Marker Compliance

- Use text-based status markers: [RESEARCHING], [RESEARCHED]
- Include timestamps: **Started**: {date}, **Completed**: {date}
- Follow status-markers.md conventions

### Atomic Updates

- Status updates delegated to status-sync-manager
- Two-phase commit ensures atomicity across specs/TODO.md and specs/state.json
- Rollback on failure to maintain consistency

---

## Implementation Notes

### Lazy Directory Creation

Directories created only when writing artifacts:
- `specs/{task_number}_{slug}/` created when writing first artifact
- `reports/` subdirectory created when writing research-001.md
- `summaries/` NOT created (summary is metadata, not artifact)

### Task Extraction Optimization

Extract only specific task entry from specs/TODO.md to reduce context load:

```bash
grep -A 50 "^### ${task_number}." specs/TODO.md > /tmp/task-${task_number}.md
```

**Impact**: Reduces context from 109KB (full specs/TODO.md) to ~2KB (task entry only), 98% reduction.

### Delegation Safety

- Max delegation depth: 3 (orchestrator → command → researcher → utility)
- Timeout: 3600s (1 hour) for research
- Session tracking: Unique session_id for all delegations
- Cycle detection: Prevent infinite delegation loops

---

## Lean-Specific Research Tools

### LeanExplore

**Purpose**: Explore Mathlib structure and contents  
**Usage**: Browse modules, types, theorems  
**Output**: Module structure, type hierarchies, theorem lists

### Loogle

**Purpose**: Search by type signature  
**Usage**: Find functions/theorems with specific types  
**Output**: Matching declarations with types and documentation

**Example**:
```
Query: Nat → Nat → Nat
Results: Nat.add, Nat.mul, Nat.sub, etc.
```

### LeanSearch

**Purpose**: Semantic search for theorems  
**Usage**: Search by natural language description  
**Output**: Relevant theorems ranked by relevance

**Example**:
```
Query: "commutativity of addition"
Results: Nat.add_comm, Int.add_comm, etc.
```

### lean-lsp-mcp

**Purpose**: LSP integration for code analysis  
**Usage**: Type checking, go-to-definition, find references  
**Output**: Type information, definitions, usage locations

---

## Performance Optimization

### Task Extraction

Extract only specific task entry from specs/TODO.md to reduce context load:

```bash
grep -A 50 "^### ${task_number}." specs/TODO.md > /tmp/task-${task_number}.md
```

**Impact**: Reduces context from 109KB (full specs/TODO.md) to ~2KB (task entry only), 98% reduction.

### Lazy Context Loading

Load context on-demand:
- Required context loaded upfront
- Optional context loaded when needed
- Language-specific context loaded only for that language

### Tool Selection

Use most appropriate tool for each research task:
- Type-based search → Loogle
- Semantic search → LeanSearch
- Module exploration → LeanExplore
- Code analysis → lean-lsp-mcp
- General search → Web search

---

## References

- **Command**: `.opencode/commands/research.md`
- **Subagent**: `.opencode/agent/subagents/researcher.md`
- **Lean Research Agent**: `.opencode/agent/subagents/lean-research-agent.md`
- **Return Format**: `.opencode/context/core/standards/subagent-return-format.md`
- **Status Markers**: `.opencode/context/core/standards/status-markers.md`
- **Artifact Management**: `.opencode/context/core/system/artifact-management.md`
- **Lean Tools**:
  - LeanSearch API: `.opencode/context/project/lean4/tools/leansearch-api.md`
  - Loogle API: `.opencode/context/project/lean4/tools/loogle-api.md`
  - LSP Integration: `.opencode/context/project/lean4/tools/lsp-integration.md`
