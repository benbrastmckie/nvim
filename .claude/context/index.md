# Context Index - Lazy-Loading Quick Map

**Created**: 2025-12-23
**Updated**: 2026-01-28 (Task 702 - Added Typst context section)
**Purpose**: Quick reference map for on-demand context loading following checkpoint-based execution

> **DEPRECATION NOTICE** (2026-02-24): This file is being superseded by `index.json` for machine-readable context discovery. While this markdown file remains useful for human reference, agents should use `index.json` with jq queries for automated context discovery. See `.claude/context/core/patterns/context-discovery.md` for query patterns.

---

## Usage Pattern

**Routing Stage** (Orchestrator Stages 1-3):
- Load NO context files during routing
- Make routing decisions with command frontmatter only
- Target: <10% context window usage

**Execution Stage** (Agent Stage 4+):
- Load only files needed for specific workflow
- Use index.md to identify required files
- Load context on-demand via @.claude/context/{category}/{file}

---

## Core Checkpoints (core/checkpoints/) **NEW**

**Checkpoint-based execution model** - Reference during command execution

- **checkpoint-gate-in.md** (~200 tokens) - GATE IN preflight validation
  - Session ID generation
  - Task existence validation
  - Status transition validation
  - Preflight status update via skill-status-sync (direct execution)

- **checkpoint-gate-out.md** (~250 tokens) - GATE OUT postflight validation
  - Return structure validation
  - Artifact existence verification
  - Postflight status update with artifact linking
  - Idempotency checks for artifact links

- **checkpoint-commit.md** (~150 tokens) - COMMIT finalization
  - Git commit with session ID
  - Non-blocking error handling
  - Final return composition

- **README.md** - Checkpoint model overview

---

## Core Routing/Validation (core/) **NEW**

**Minimal context files for tiered loading**

- **routing.md** (~200 tokens) - Command-level routing
  - Language → Skill mapping table
  - Status transitions by command
  - Session ID format

- **validation.md** (~300 tokens) - Skill-level validation
  - Return schema (required fields)
  - Input requirements
  - Artifact validation patterns
  - Idempotency checks

---

## Core Standards (core/standards/)

**Consolidated files** - Load for delegation, return format, validation

- **delegation.md** (510 lines) - Unified delegation standard
  - Return format schema (all agents MUST follow)
  - Delegation patterns and safety mechanisms
  - Session tracking, cycle detection, timeouts
  - Validation framework
  - Replaces: subagent-return-format.md, subagent-delegation-guide.md, delegation-patterns.md

---

## Core Orchestration (core/orchestration/)

**Consolidated files** (2026-01-19) - Load for orchestration, delegation, validation

- **orchestration-core.md** (~250 lines) - Essential orchestration patterns
  - Session ID format and tracking
  - Delegation safety (depth limits, cycle detection, timeouts)
  - Return format schema
  - Command->Agent routing and language extraction
  - **LOAD for any delegation operation**

- **orchestration-validation.md** (~200 lines) - Validation patterns
  - Return validation steps (JSON, fields, status, artifacts)
  - Error codes and handling
  - /task flag validation
  - **LOAD when validating agent returns**

- **orchestration-reference.md** (~200 lines) - Examples and troubleshooting
  - Command execution flow examples
  - Bulk operation patterns
  - Troubleshooting guide
  - **LOAD when debugging orchestration issues**

- **state-management.md** (~300 lines) - Unified state management
  - Status markers and transition rules
  - State schemas
  - Fast jq lookup patterns
  - **LOAD for state queries and updates**

- **architecture.md** (~750 lines) - Three-layer architecture overview
  - Command->Skill->Agent delegation pattern
  - Layer responsibilities
  - **LOAD for understanding system design**

- **preflight-pattern.md** (~220 lines) - Pre-delegation process
  - **LOAD when implementing preflight**

- **postflight-pattern.md** (~340 lines) - Post-completion process
  - **LOAD when implementing postflight**

**Deprecated files** (still available for reference):
- orchestrator.md -> orchestration-core.md, orchestration-reference.md
- delegation.md -> orchestration-core.md, orchestration-validation.md
- routing.md -> orchestration-core.md
- validation.md -> orchestration-validation.md
- subagent-validation.md -> orchestration-validation.md
- sessions.md -> orchestration-core.md

---

## Core Architecture (core/architecture/) **NEW**

Load for: Architecture understanding, component generation, /meta agent use

- **system-overview.md** (~300 lines) - Three-layer architecture overview
  - Command -> Skill -> Agent delegation pattern
  - Component responsibilities matrix
  - Delegation flow diagrams
  - Checkpoint model reference
  - **MUST load when understanding system architecture or generating components**

- **component-checklist.md** (~250 lines) - Component creation decision tree
  - When to create command vs skill vs agent
  - Checklists for each component type
  - Common component combinations
  - Naming conventions
  - **MUST load when creating new components via /meta**

- **generation-guidelines.md** (~350 lines) - Templates for /meta agent
  - Command generation template
  - Skill generation template (thin wrapper pattern)
  - Agent generation template
  - Anti-stop patterns reference
  - Post-generation verification
  - **MUST load when /meta generates new components**

---

## Core Patterns (core/patterns/)

Load for: Behavior patterns that apply across all agents/skills

- **anti-stop-patterns.md** (~150 lines) - Critical patterns to prevent workflow early stop
  - Forbidden status values ("completed", "done", "finished")
  - Safe contextual alternatives ("researched", "planned", "implemented")
  - Forbidden phrases in summaries/next_steps
  - Enforcement points and validation commands
  - **MUST load when creating new agents or skills via /meta**

- **skill-lifecycle.md** (~100 lines) - Self-contained skill pattern
  - Skills own preflight → delegate → postflight lifecycle
  - Eliminates multiple skill invocations per workflow
  - Reduces halt risk from 3 skill calls to 1
  - **MUST load when refactoring workflow skills**

- **inline-status-update.md** (~200 lines) - Reusable status update snippets
  - Preflight patterns for research/planning/implementation
  - Postflight patterns with artifact linking
  - TODO.md edit patterns
  - Error handling patterns
  - **MUST load when adding status management to skills**

- **jq-escaping-workarounds.md** (~150 lines) - jq command escaping bug workarounds
  - Documents Claude Code Issue #1132 (Bash tool jq escaping)
  - Two-step approach for artifact updates
  - Pattern templates for research/planning/implementation postflight
  - Testing checklist for new jq patterns
  - **MUST load when adding jq commands that use map(select(!=)) patterns**

- **thin-wrapper-skill.md** (~120 lines) - Quick reference for thin wrapper skill pattern
  - Frontmatter requirements
  - Execution pattern (5 steps)
  - Task tool invocation (NOT Skill tool)
  - When to use vs direct execution

- **metadata-file-return.md** (~100 lines) - Quick reference for agent return via metadata file
  - File location pattern
  - Schema quick reference
  - Status values (contextual, never "completed")
  - Agent writing and skill reading patterns

- **checkpoint-execution.md** (~180 lines) - Quick reference for command checkpoint pattern
  - Three-checkpoint model (GATE IN, DELEGATE, GATE OUT, COMMIT)
  - Status transitions by command
  - Session ID tracking
  - Error handling at each checkpoint

---

## Core Formats (core/formats/)

Load for: Artifact creation

- **subagent-return.md** - Return format schema for all agents (includes anti-stop warning)
- **plan-format.md** - Implementation plan structure
- **report-format.md** - Research report structure
- **summary-format.md** - Implementation summary structure

---

## Core Standards (core/standards/)

Load for: Task validation, artifact creation, documentation standards

- **status-markers.md** (350 lines) - **Complete** status marker reference
  - Standard status markers (NOT STARTED, RESEARCHING, PLANNED, etc.)
  - TODO.md vs state.json mapping
  - Command → Status mapping
  - Valid transition rules and diagrams
  - Atomic synchronization protocol
  - **Note**: For most use cases, `orchestration/state-management.md` is sufficient.
    Load status-markers.md only when you need detailed transition validation rules.
- **ci-workflow.md** (140 lines) - CI workflow standards and trigger criteria
  - Skip-by-default behavior with `[ci]` marker
  - Decision criteria for triggering CI
  - Language-based defaults (neovim triggers, meta/markdown skip)
  - Task lifecycle CI triggers
- **tasks.md** (227 lines) - Task entry format, required fields, validation rules
- **documentation.md** (178 lines) - Documentation standards, NO EMOJI policy
- **plan.md** (104 lines) - Implementation plan structure and requirements
- **code.md** (155 lines) - Code quality standards
- **tests.md** (127 lines) - Test requirements and standards
- **patterns.md** (213 lines) - Common design patterns
- **summary.md** (60 lines) - Summary artifact standards
- **report.md** (66 lines) - Report artifact standards
- **analysis.md** (103 lines) - Analysis artifact standards
- **frontmatter-standard.md** (92 lines) - YAML frontmatter requirements
- **commands.md** (73 lines) - Command structure standards

---

## Core System (core/system/)

Load for: Artifact management, git commits, context loading

- **artifact-management.md** (274 lines) - Lazy directory creation, artifact naming (required for all workflows)
- **git-commits.md** (34 lines) - Targeted commit patterns
- **context-guide.md** (89 lines) - Context loading patterns
- **self-healing-guide.md** (153 lines) - Self-healing mechanisms

---

## Core Workflows (core/workflows/)

Load for: Review, task breakdown, sessions

- **review.md** (164 lines) - Review workflow and criteria
- **task-breakdown.md** (270 lines) - Task decomposition patterns
- **sessions.md** (157 lines) - Session management
- **delegation.md** (82 lines) - Delegation context template (temporary context files)

---

## Core Templates (core/templates/)

Load for: Creating new agents, commands, orchestrators

- **thin-wrapper-skill.md** - Template for creating new skills (thin wrapper pattern)
- **subagent-template.md** - Template for creating new agents
- **command-template.md** - Template for creating new commands
- **orchestrator-template.md** - Template for orchestrator patterns
- **meta-guide.md** - Meta-documentation guide
- **state-template.json** - State file template
- **subagent-frontmatter-template.yaml** - Frontmatter template

---

## Documentation Guides (docs/guides/)

Load for: Component development and architecture understanding

**Component Development**:
- **component-selection.md** - Decision tree for command vs skill vs agent
- **creating-commands.md** - Step-by-step command creation
- **creating-skills.md** - Step-by-step skill creation (thin wrapper pattern)
- **creating-agents.md** - Step-by-step agent creation (8-stage workflow)

**Context Loading**:
- **context-loading-best-practices.md** - Lazy loading patterns

**Examples**:
- **examples/research-flow-example.md** - End-to-end /research command flow

**When to Load**:
- Load component-selection.md when deciding what to create
- Load creating-*.md when implementing new component
- Load research-flow-example.md for understanding flow patterns

---

## Project Context (project/)

Load only when needed for language-specific workflows:

### Neovim Context (project/neovim/)

Load for: Neovim implementation tasks (Language: neovim)

**Overview**:
- **README.md** (~80 lines) - Directory overview and loading strategy

**Domain**:
- **lua-patterns.md** - Lua idioms for Neovim
- **plugin-ecosystem.md** - lazy.nvim, common plugins
- **lsp-overview.md** - LSP concepts, mason, nvim-lspconfig
- **neovim-api.md** - vim.api, vim.fn, vim.opt patterns

**Patterns**:
- **plugin-spec.md** - lazy.nvim plugin specification
- **keymap-patterns.md** - vim.keymap.set, which-key
- **autocommand-patterns.md** - vim.api.nvim_create_autocmd
- **ftplugin-patterns.md** - after/ftplugin structure

**Standards**:
- **lua-style-guide.md** - Lua conventions
- **testing-patterns.md** - plenary.nvim testing

**Tools**:
- **lazy-nvim-guide.md** - lazy.nvim usage
- **treesitter-guide.md** - Tree-sitter configuration
- **telescope-guide.md** - Telescope patterns

**Templates**:
- **plugin-template.md** - New plugin spec template
- **ftplugin-template.md** - New ftplugin template

**When to Load**:
- Load README.md for overview on any Neovim task
- Load lua-style-guide.md when setting up Lua modules
- Load plugin-spec.md when working with plugin configuration
- Load keymap-patterns.md when defining keybindings
- Load autocommand-patterns.md when working with autocmds

### Typst Context (project/typst/)

Load for: Typst implementation tasks (Language: typst)

**Overview**:
- **README.md** (~80 lines) - Directory overview and loading strategy

**Standards**:
- **typst-style-guide.md** (~230 lines) - Document setup, typography, show rules
  - Page layout and margins (1.5in x 1.25in, matching LaTeX)
  - URLblue hyperlink styling (rgb(0, 0, 150))
  - URL text formatting with raw() (texttt equivalent)
  - Heading spacing (above: 1.4em, below: 1em)
- **notation-conventions.md** - shared-notation.typ and theory-specific modules
- **document-structure.md** - Main document and chapter organization

**Patterns**:
- **theorem-environments.md** - thmbox setup and usage
- **cross-references.md** - Labels, refs, code cross-references

**Templates**:
- **chapter-template.md** - Boilerplate for new chapters

**Tools**:
- **compilation-guide.md** - `typst compile` and `typst watch` usage

**When to Load**:
- Load README.md for overview on any Typst task
- Load typst-style-guide.md when setting up document formatting
- Load theorem-environments.md when working with definitions/theorems
- Load chapter-template.md when creating new chapters

---

### Repo Context (project/repo/)

Load for: General markdown/documentation tasks (Language: markdown)

- **project-overview.md** - Repository structure and organization
- **self-healing-implementation-details.md** - Self-healing system details

---

## System Context (system/)

Load for: Orchestrator and routing patterns

- **orchestrator-guide.md** - Orchestrator implementation patterns
- **routing-guide.md** - Routing decision logic

---

## Meta Context (Integrated into core/)

Load for: /meta command and meta-builder-agent workflows

**When to Load**: Only when executing /meta command via meta-builder-agent

**Note**: /meta now uses the skill-meta -> meta-builder-agent delegation pattern (Task 429, 2026-01-12)

**Component Development Guides** (docs/guides/):
- **component-selection.md** - Decision tree for what to create (command vs skill vs agent)
- **creating-commands.md** - Step-by-step command creation guide
- **creating-skills.md** - Step-by-step skill creation guide (thin wrapper pattern)
- **creating-agents.md** - Step-by-step agent creation guide (8-stage workflow)

**Interview Patterns** (core/workflows/):
- **interview-patterns.md** (226 lines) - Progressive disclosure, adaptive questioning, validation checkpoints

**Architecture Design** (core/standards/):
- **architecture-principles.md** (272 lines) - Modular design, hierarchical organization, context efficiency
- **domain-patterns.md** (260 lines) - Development, business, hybrid, and Neovim-specific domain patterns

**Agent Templates** (core/templates/):
- **agent-templates.md** (336 lines) - Orchestrator, research, validation, processing, and generation templates

**Loading Strategy for meta-builder-agent**:
- **Interactive mode**: Load component-selection.md during interview Stage 2
- **Prompt mode**: Load component-selection.md for analysis
- **Analyze mode**: Load CLAUDE.md and index.md for system inventory
- Load creating-*.md guides when specific component types are being discussed
- Never load during routing (Stages 1-3)

---

## Core Specs (specs/)

Load selectively: Use grep extraction for specific tasks, avoid loading full file

- **TODO.md** - Active task list (large file - load via: `grep -A 50 "^### {task_number}\." TODO.md`)
- **state.json** - Project state tracking (load full file, ~8KB)

---

## Context Loading Examples

**Research Workflow (researcher.md)**:
```
Stage 4 loads:
- @.claude/context/core/orchestration/orchestration-core.md
- @.claude/context/core/orchestration/state-management.md
- grep -A 50 "^### {task_number}\." specs/TODO.md
- @specs/state.json

Language-specific:
- If neovim: @.claude/context/project/neovim/domain/neovim-api.md
- If markdown: (no additional context)
```

**Planning Workflow (planner.md)**:
```
Stage 4 loads:
- @.claude/context/core/orchestration/orchestration-core.md
- @.claude/context/core/formats/plan-format.md
- @.claude/context/core/orchestration/state-management.md
- grep -A 50 "^### {task_number}\." specs/TODO.md
- @specs/state.json
- Research artifacts from task (if exist)
```

**Implementation Workflow (implementer.md, task-executor.md)**:
```
Stage 4 loads:
- @.claude/context/core/orchestration/orchestration-core.md
- @.claude/context/core/orchestration/state-management.md
- @.claude/context/core/system/git-commits.md
- grep -A 50 "^### {task_number}\." specs/TODO.md
- @specs/state.json
- Plan file (if exists)

Language-specific:
- If neovim: @.claude/context/project/neovim/standards/lua-style-guide.md
- If neovim: @.claude/context/project/neovim/tools/lazy-nvim-guide.md
```

**Meta Workflow (meta-builder-agent)**:

See `.claude/agents/meta-builder-agent.md` for complete stage-by-stage context loading guidance.

Quick reference:
- Interactive/Prompt modes: component-selection.md + on-demand component guides
- Analyze mode: CLAUDE.md + index.md (read-only analysis)
- All modes: subagent-return.md (always)

---

## Context Budget Targets (Task 246 Goals)

- **Routing**: <10% context window (Stages 1-3, no context loading)
- **Execution**: 90% context window available (Stage 4+, selective loading)
- **Total context system**: 2,000-2,500 lines (Phase 3 consolidation target)

---

## Consolidation Summary (Task 246 Phase 3)

**Completed**:
- ✓ Delegation files merged: 1,003 → 510 lines (50% reduction)
- ✓ State management files merged: 1,574 → 535 lines (66% reduction)
- ✓ command-lifecycle.md deprecated: 1,138 lines pending removal
- ✓ Total reduction: 3,715 → 1,045 lines (72% reduction, 2,670 lines saved)

**Deprecated Files** (deprecation period ended 2025-01-29, now removed):
- subagent-return-format.md → core/standards/delegation.md#return-format (removed)
- subagent-delegation-guide.md → core/standards/delegation.md#delegation-patterns (removed)
- state-schema.md → core/system/state-management.md#state-schemas (removed)
- command-lifecycle.md → see agent files for execution patterns (pending removal)

**Note**: status-markers.md has been moved from core/system/ to core/standards/ (2026-01-08) as it defines standards/conventions rather than system implementation.

---

## Migration Notes (Task 240 + Task 246)

**Phase 1 (Complete)**: Index pattern established, /research migrated to frontmatter
**Phase 2 (Complete)**: All commands migrate to frontmatter, orchestrator simplified
**Phase 3 (Complete)**: Context consolidation, 72% size reduction achieved
**Phase 4 (Planned)**: Testing and documentation

---

## Quick Navigation

**For Component Development**:
- **Component Selection**: → `docs/guides/component-selection.md`
- **Creating Commands**: → `docs/guides/creating-commands.md`
- **Creating Skills**: → `docs/guides/creating-skills.md`
- **Creating Agents**: → `docs/guides/creating-agents.md`
- **Skill Template**: → `core/templates/thin-wrapper-skill.md`

**For Standards**:
- **For Delegation**: → `core/standards/delegation.md`
- **For State Management**: → `core/system/state-management.md`
- **For Artifacts**: → `core/system/artifact-management.md`
- **For Git Commits**: → `core/system/git-commits.md`
- **For Task Format**: → `core/standards/tasks.md`
- **For Plan Format**: → `core/standards/plan.md`
- **For Neovim Lua Style**: → `project/neovim/standards/lua-style-guide.md`
- **For Plugin Patterns**: → `project/neovim/patterns/plugin-spec.md`
