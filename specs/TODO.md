---
next_project_number: 313
---

# TODO

## Task Order

*Updated 2026-03-27. 7 active tasks remaining.*

### Pending

- **309** [COMPLETED] -- Research unified artifact numbering system
- **310** [NOT STARTED] -- Update state.json schema (blocked by 309)
- **311** [NOT STARTED] -- Update artifact-formats.md rule (blocked by 309)
- **312** [NOT STARTED] -- Update skills/agents unified numbering (blocked by 310, 311)
- **308** [COMPLETED] -- Implement adaptive context loading by extension and language
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 309. Research unified artifact numbering system
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-27
- **Research Completed**: 2026-03-27
- **Planning Started**: 2026-03-27
- **Planning Completed**: 2026-03-27
- **Implementation Started**: 2026-03-27
- **Implementation Completed**: 2026-03-27
- **Language**: meta
- **Research**: [01_unified-numbering-research.md](309_unified_artifact_numbering_research/reports/01_unified-numbering-research.md)
- **Plan**: [02_unified-numbering-with-teams.md](309_unified_artifact_numbering_research/plans/02_unified-numbering-with-teams.md)
- **Summary**: [01_implementation-summary.md](309_unified_artifact_numbering_research/summaries/01_implementation-summary.md)
- **Dependencies**: None

**Description**: Analyze current artifact numbering patterns across all skills/agents, document how next_artifact_number should be tracked in state.json, and design the unified sequencing logic where research drives numbering and plan/summary inherit the current number. Review ProofChecker task 058 as an example of desired behavior.

---

### 310. Update state.json schema with next_artifact_number field
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #309

**Description**: Add next_artifact_number field to task entries in state.json schema. Update state-management-schema.md documentation. Handle backward compatibility for existing tasks without the field.

---

### 311. Update artifact-formats.md rule for unified numbering
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #309

**Description**: Change "Per-Type Sequential Numbering" to "Unified Sequential Numbering" with new semantics: research increments, plan/summary inherit current max. Document the research-driven pattern.

---

### 312. Update all skills and agents for unified numbering
- **Effort**: 3-4 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #310, Task #311

**Description**: Modify all artifact-producing components to use unified numbering. Research skill/agent increments next_artifact_number. Planning and implementation skills/agents inherit the current max number from existing artifacts. Also update extension agents that produce artifacts.

---

### 308. Implement adaptive context loading by extension and language
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-26
- **Research Completed**: 2026-03-26
- **Planning Started**: 2026-03-26
- **Planning Completed**: 2026-03-26
- **Implementation Started**: 2026-03-26
- **Implementation Completed**: 2026-03-26
- **Language**: meta
- **Summary**: [01_implementation-summary.md](308_adaptive_context_loading_by_extension_and_language/summaries/01_implementation-summary.md)
- **Research**: [01_context-loading-research.md](308_adaptive_context_loading_by_extension_and_language/reports/01_context-loading-research.md)
- **Plan**: [01_adaptive-context-loading.md](308_adaptive_context_loading_by_extension_and_language/plans/01_adaptive-context-loading.md)

**Description**: Implement adaptive context loading that filters by loaded extensions and task language. Currently, empty load_when conditions (empty arrays for agents/languages/commands) cause ALL context files to load unconditionally, regardless of task language. In the Vision project, a typst task loads ~24,444 lines of unrelated context (business-frameworks.md, legal-frameworks.md, pitch-deck-templates, etc.) because 74 core files have empty load_when. Fix this by: (1) Changing empty-array semantics so empty = never-load instead of always-load, requiring explicit 'always: true' for universal files; (2) Adding language-gate validation to the extension loader that warns when entries lack language filtering; (3) Adding a context budget system that caps total loaded lines and prioritizes by relevance (always > agent-match > language-match > command-match); (4) Making the skill/agent context loading queries filter OUT entries that don't match any active dimension rather than loading everything unfiltered. This is a meta task affecting .claude/context/, .claude/extensions/, .claude/agents/, and .claude/skills/.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---
