---
next_project_number: 210
---

# TODO

## Tasks

### 209. Create EXTENSION.md and index-entries.json for grant extension
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #207, Task #208
- **Created**: 2026-03-15

**Description**: Create the EXTENSION.md file with content to inject into CLAUDE.md when the grant extension is loaded, and index-entries.json with canonical paths for context discovery. This finalizes the extension for use with the `<leader>ac` loader.

---

### 208. Create grant context files for domain knowledge
- **Effort**: 2-3 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15

**Description**: Create context files in grant/context/ containing domain knowledge for grant writing. Include templates, funder research patterns, proposal structure guidelines, and budget justification formats. These files will be progressively loaded by the grant-agent based on task needs.

---

### 207. Create /grant command
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #206
- **Created**: 2026-03-15

**Description**: Create grant/commands/grant.md command following existing command patterns. The command should parse arguments (e.g., project name, funder, deadline), invoke skill-grant via the Skill tool, and handle postflight operations including git commits.

---

### 206. Create skill-grant thin wrapper
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: Task #205
- **Created**: 2026-03-15

**Description**: Create grant/skills/skill-grant/SKILL.md as a thin wrapper that validates inputs, prepares delegation context, invokes grant-agent via the Agent tool, validates the return, and propagates results. Follow the skill-meta pattern for internal postflight handling.

---

### 205. Create grant-agent with research and writing capabilities
- **Effort**: 2-3 hours
- **Status**: [RESEARCHED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15
- **Research**: [01_grant-agent-patterns.md](205_create_grant_agent/reports/01_grant-agent-patterns.md)

**Description**: Create grant/agents/grant-agent.md with capabilities for grant proposal research and writing. The agent should support: funder research (using WebSearch, WebFetch), proposal drafting, budget justification, and progress tracking. Include progressive context loading from grant/context/ files.

---

### 204. Create grant extension scaffold with manifest.json
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-15
- **Research**: [01_extension-scaffold-patterns.md](204_create_grant_extension_scaffold/reports/01_extension-scaffold-patterns.md), [02_grant-best-practices.md](204_create_grant_extension_scaffold/reports/02_grant-best-practices.md)
- **Plan**: [01_extension-scaffold-plan.md](204_create_grant_extension_scaffold/plans/01_extension-scaffold-plan.md)
- **Summary**: [01_extension-scaffold-summary.md](204_create_grant_extension_scaffold/summaries/01_extension-scaffold-summary.md)

**Description**: Create the foundational grant/ extension directory structure following existing extension patterns (nvim, lean). Create manifest.json with extension metadata including name, version, description, provides arrays (commands, skills, agents), and merge_targets for context index integration.

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
