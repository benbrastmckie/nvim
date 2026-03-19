---
next_project_number: 247
---

# TODO

## Tasks

### 246. Upgrade founder extension typst templates to professional styling
- **Effort**: 4-6 hours
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: None

**Description**: Extract the professional typst template design from /home/benjamin/Projects/Logos/Vision/strategy/market-sizing-condensed.typ and use it as the basis for the typst templates in the founder extension, enabling /plan + /implement on founder tasks (market, analyze, strategy) to produce professional PDF reports.

The existing strategy-template.typ uses generic styling (New Computer Modern font, gray color scheme). The reference template has: Libertinus Serif font, navy/blue color palette (#0a2540, #1a4a7a, #2a5a9a), professional heading styles with colored underlines, metric() pills (dark navy with white text), callout() boxes (left-bordered), professional page header/footer with company name, and alternating row tables.

**Files to update**:
1. `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` - Complete rewrite with professional styling
2. `.claude/extensions/founder/context/project/founder/templates/typst/market-sizing.typ` - Section structure matching condensed document
3. `.claude/extensions/founder/context/project/founder/templates/typst/competitive-analysis.typ` - Professional color scheme
4. `.claude/extensions/founder/context/project/founder/templates/typst/gtm-strategy.typ` - Professional color scheme
5. `.claude/extensions/founder/agents/founder-implement-agent.md` - Update Phase 5 inline generation example

**Reference**: /home/benjamin/Projects/Logos/Vision/strategy/market-sizing-condensed.typ (564 lines)

---

### 245. Fix plan status update script arguments in skill-implementer
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](245_fix_plan_status_update_script_arguments/reports/01_meta-research.md)
- **Plan**: [01_fix-script-args.md](245_fix_plan_status_update_script_arguments/plans/01_fix-script-args.md)
- **Summary**: [01_fix-script-args-summary.md](245_fix_plan_status_update_script_arguments/summaries/01_fix-script-args-summary.md)

**Description**: Fix the argument mismatch between `update-plan-status.sh` (expects 3 args: `TASK_NUMBER PROJECT_NAME STATUS`) and skill-implementer calls (passes 4 args including extraneous `$padded_num`). Remove `$padded_num` from script invocations at lines 93, 264, and 283 in skill-implementer/SKILL.md. Check and fix similar issues in extension skills (nvim, present) if present.

---

### 244. Integrate Recommended Order utility into workflow commands
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Language**: meta
- **Dependencies**: Task #243
- **Research**: [01_recommended-order-research.md](243_recommended_order_integration/reports/01_recommended-order-research.md)
- **Plan**: [01_workflow-integration.md](244_integrate_recommended_order_utility/plans/01_workflow-integration.md)
- **Summary**: [02_workflow-integration-summary.md](244_integrate_recommended_order_utility/summaries/02_workflow-integration-summary.md)

**Description**: Integrate the Recommended Order utility into 4 workflow components: (1) /task command - call add_to_recommended_order after creating task entry (Step 7), (2) skill-implementer - call remove_from_recommended_order in Stage 7 postflight after completion, (3) skill-spawn - call refresh_recommended_order in Stage 12 after creating spawned tasks, (4) skill-todo - call remove_from_recommended_order in Stage 10 for each archived task. Ensure graceful handling when Recommended Order section does not exist (skip, do not fail).

---

### 243. Create Recommended Order helper utility script
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_recommended-order-research.md](243_recommended_order_integration/reports/01_recommended-order-research.md)
- **Plan**: [01_recommended-order-utility.md](243_recommended_order_integration/plans/01_recommended-order-utility.md)
- **Summary**: [01_recommended-order-utility-summary.md](243_recommended_order_integration/summaries/01_recommended-order-utility-summary.md)

**Description**: Create .claude/scripts/update-recommended-order.sh with three functions: (1) add_to_recommended_order TASK_NUM - insert task into Recommended Order section based on dependency position, (2) remove_from_recommended_order TASK_NUM - remove task entry from section, (3) refresh_recommended_order - regenerate entire section from state.json dependency graph using topological sort. The section format is: numbered list with bold task numbers, arrow separator, action hints, and parenthetical dependency notes. Also update .claude/rules/state-management.md to document the Recommended Order section format and conventions.

---

### 242. Add <leader>am model picker for Claude Code with Opus as default
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Language**: neovim
- **Dependencies**: None
- **Research**: [01_model-picker-research.md](242_add_leader_am_model_picker_for_claude_code/reports/01_model-picker-research.md)
- **Plan**: [01_model-picker-plan.md](242_add_leader_am_model_picker_for_claude_code/plans/01_model-picker-plan.md)
- **Summary**: [01_model-picker-summary.md](242_add_leader_am_model_picker_for_claude_code/summaries/01_model-picker-summary.md)

**Description**: Add a `<leader>am` keymap that opens a Telescope picker listing the three Anthropic Claude models (Opus 4.6 first, then Sonnet 4.6, then Haiku 4.5). Selecting a model updates `~/.config/.claude/settings.local.json` with the chosen model value and notifies the user that a restart is required. Follow the same file-modification pattern used by `<leader>ay` (yolo mode toggle): read the JSON file, update the `"model"` field, write back. Also update the global default from `"sonnet"` to `"opus"` in `settings.local.json` as part of this task. The picker should use `vim.ui.select` or a lightweight Telescope dropdown (not the full session picker complexity), display the three options with model IDs and human-readable labels, and show the currently active model visually. Add the keymap entry in `which-key.lua` under the `<leader>a` (AI) group with icon and desc `"model (claude)"`.

---

### 241. Add /spawn command, skill-spawn wrapper, and spawn-agent for blocked task recovery
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-19
- **Completed**: 2026-03-19
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-research.md](241_add_spawn_command_skill_agent/reports/01_meta-research.md)
- **Plan**: [01_spawn-workflow.md](241_add_spawn_command_skill_agent/plans/01_spawn-workflow.md)
- **Summary**: [01_spawn-workflow-summary.md](241_add_spawn_command_skill_agent/summaries/01_spawn-workflow-summary.md)

**Description**: Create the complete `/spawn N [prompt]` workflow for recovering from blocked implementations. When `/implement` on a task gets stuck, the user runs `/spawn N` (with an optional description of what's blocking), and the command researches the blocker, decomposes it into a minimal set of new tasks, and wires up all dependency relationships automatically. Three components must be created together:

**1. `/spawn` command** (`.claude/commands/spawn.md`): Accepts task number and optional blocker prompt. Validates that the target task exists and is in a blockable state (implementing, partial, blocked, planned, or researched). Generates a session ID, loads the task's latest plan for context, and delegates to `skill-spawn`. Allowed tools: `Skill, Bash(jq:*), Bash(git:*), Read, Glob`. Model: `claude-opus-4-5-20251101`.

**2. `skill-spawn` wrapper** (`.claude/skills/skill-spawn/SKILL.md`): Thin wrapper following the standard skill pattern. Preflight sets the parent task status to `blocked` in state.json and `[BLOCKED]` in TODO.md. Delegates to `spawn-agent` via Task tool. Postflight reads the agent's `.spawn-return.json` file and performs all state writes: (a) creates new task directories and research stubs, (b) inserts new tasks into state.json and TODO.md in topological order (foundational tasks get lower numbers, using Kahn's algorithm on the agent-provided `dependency_order`), (c) updates the parent task's `dependencies` array in state.json to include all new task numbers, (d) edits the parent task's `- **Dependencies**:` line in TODO.md accordingly, (e) commits with message `task N: spawn {M} tasks to resolve blocker`. The skill MUST NOT perform analysis or task decomposition - that is the agent's responsibility. New tasks should have `parent_task: N` in their state.json entries and `- **Parent Task**: #N` in their TODO.md entries, and start with `status: "researched"`.

**3. `spawn-agent`** (`.claude/agents/spawn-agent.md`): The analysis brain of the system. Given the blocked task's data, its plan (with phase status markers showing where it stalled), and the optional user prompt, the agent: reads all available context (research reports, plan phases, partial summaries), identifies the root cause of the block (missing prerequisite, external dependency, design ambiguity, scope creep, or technical unknowns), decomposes into the minimal number of new tasks needed, and reasons explicitly about sequentiality. The sequentiality rule is: keep tasks separate only when the specific implementation details of one task (not just its completion) affect how a later task should be implemented. Tasks that are merely ordered but don't affect each other's implementation choices should be combined or marked independent. The agent writes a blocker analysis report to `specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md` and a machine-readable return file to `specs/{NNN}_{SLUG}/.spawn-return.json` with schema: `{ new_tasks: [{index, title, description, effort, language, dependencies: [indices]}], dependency_order: [sorted indices], parent_task_number, analysis_summary, report_path }`. The agent MUST NOT create tasks in state.json or TODO.md - that is the skill's responsibility.

**CLAUDE.md update**: Add `skill-spawn -> spawn-agent` row to the Skill-to-Agent Mapping table.

---

### 240. Fix /market command to use forcing questions workflow with market type tasks
- **Effort**: 5-6 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_market-workflow-research.md](240_fix_market_command_forcing_questions_workflow/reports/01_market-workflow-research.md)
- **Plan**: [01_founder-workflow-plan.md](240_fix_market_command_forcing_questions_workflow/plans/01_founder-workflow-plan.md)
- **Summary**: [01_founder-workflow-summary.md](240_fix_market_command_forcing_questions_workflow/summaries/01_founder-workflow-summary.md)

**Description**: Fix /market command in the founder/ extension to ask forcing questions before creating tasks (following the pattern from tasks 233 and 234). Currently /market starts research immediately, but should instead: (1) ask forcing questions, (2) create a task with 'market' type (distinct from 'founder' to differentiate from 'analyze' and 'strategy' types), (3) include task description and research report based on question answers. Running /research on market tasks should route to market-research agent for careful research. Running /plan on market tasks should route to a planner that prepares a typst file plan. Running /implement on market tasks should construct the typst file. Rework all founder/ extension commands uniformly to follow this pattern.

---

### 238. Fix founder extension /implement to generate typst files using templates
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Research**: [01_founder-typst-fix.md](238_fix_founder_implement_typst_output/reports/01_founder-typst-fix.md)
- **Plan**: [01_founder-typst-fix-plan.md](238_fix_founder_implement_typst_output/plans/01_founder-typst-fix-plan.md)
- **Summary**: [01_founder-typst-fix-summary.md](238_fix_founder_implement_typst_output/summaries/01_founder-typst-fix-summary.md)
- **Language**: meta
- **Dependencies**: Task #237

**Description**: Fix /implement for founder tasks to generate typst files instead of markdown files. Currently /implement creates .md files (e.g., market-sizing-v3-20260318.md) but should use the typst templates from the founder extension (.claude/extensions/founder/) to produce properly formatted .typ files.

---

### 237. Add typst output generation to founder task implementation
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Research**: [01_typst-output-research.md](237_add_typst_output_founder_implementation/reports/01_typst-output-research.md)
- **Plan**: [01_typst-output-implementation.md](237_add_typst_output_founder_implementation/plans/01_typst-output-implementation.md)
- **Summary**: [01_typst-output-summary.md](237_add_typst_output_founder_implementation/summaries/01_typst-output-summary.md)
- **Language**: meta
- **Dependencies**: Task #236

**Description**: Enhance `/implement` for founder tasks to generate typst output in `founder/` directory at the repository root. The implementation should use templates and formatting assets from the founder extension (`.claude/extensions/founder/`) to produce professionally formatted strategy documents from the markdown reports created by `/market`, `/analyze`, and `/strategy` commands.

---

### 236. Refactor founder extension commands to research-stop workflow
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Research**: [01_workflow-analysis.md](236_refactor_founder_commands/reports/01_workflow-analysis.md)
- **Plan**: [01_workflow-refactor.md](236_refactor_founder_commands/plans/01_workflow-refactor.md)
- **Summary**: [01_workflow-refactor-summary.md](236_refactor_founder_commands/summaries/01_workflow-refactor-summary.md)

**Description**: Refactor `/market`, `/analyze`, and `/strategy` commands so each stops after producing a research report (status [RESEARCHED]) rather than auto-proceeding through plan+implement. Forcing questions happen at research time; plan reads the report; implement generates the final `strategy/` output. Applies uniformly across all three commands, their skills, and their agents. Also updates `founder-plan-agent` to read the research report instead of asking redundant questions, and `founder-implement-agent` to support an optional output path argument.

---

### 235. Research and integrate MCP tools for founder extension
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Research**:
  - [01_meta-research.md](235_research_integrate_mcp_founder/reports/01_meta-research.md)
  - [02_mcp-tools-research.md](235_research_integrate_mcp_founder/reports/02_mcp-tools-research.md)
- **Plan**:
  - [01_mcp-tools-integration.md](235_research_integrate_mcp_founder/plans/01_mcp-tools-integration.md)
  - [02_mcp-tools-integration-revised.md](235_research_integrate_mcp_founder/plans/02_mcp-tools-integration-revised.md)
  - [03_mcp-tools-final.md](235_research_integrate_mcp_founder/plans/03_mcp-tools-final.md)
- **Summary**: [01_mcp-integration-summary.md](235_research_integrate_mcp_founder/summaries/01_mcp-integration-summary.md)

**Description**: Research and integrate MCP (Model Context Protocol) tools to enhance founder extension agent capabilities for market research and business strategy. Includes: (1) Research MCP tools for market research - market data APIs, industry reports, company information; (2) Research MCP tools for business strategy - competitive intelligence, trend analysis, financial data; (3) Evaluate and integrate best tools into founder extension manifest.json and agent definitions.

---

### 234. Upgrade founder/ extension to task-based workflow with forcing questions
- **Effort**: 8-12 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #233
- **Started**: 2026-03-18
- **Completed**: 2026-03-18
- **Research**:
  - [01_task-integration-research.md](234_upgrade_founder_extension_workflow/reports/01_task-integration-research.md)
  - [02_plan-implement-workflow.md](234_upgrade_founder_extension_workflow/reports/02_plan-implement-workflow.md)
- **Plan**: [01_founder-workflow-upgrade.md](234_upgrade_founder_extension_workflow/plans/01_founder-workflow-upgrade.md)
- **Summary**: [01_founder-workflow-summary.md](234_upgrade_founder_extension_workflow/summaries/01_founder-workflow-summary.md)

**Description**: Overhaul the founder/ extension so that /market, /analyze, and /strategy commands: (1) create tasks in the task system and produce detailed report artifacts rather than console-only output; (2) accept a file path, task number, or no argument; (3) implement a three-phase forcing questions workflow — initial research phase (reads context/input), interactive forcing questions round (questions informed by initial research), and a final research/synthesis phase that produces the detailed report artifact. Update commands, skills, agents, and context files accordingly.

---

### 233. Research gstack for founder extension integration
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Research**:
  - [01_gstack-founder-integration.md](233_research_gstack_founder_extension/reports/01_gstack-founder-integration.md)
  - [02_founder-skills-deep-dive.md](233_research_gstack_founder_extension/reports/02_founder-skills-deep-dive.md)
- **Plan**: [01_founder-extension-plan.md](233_research_gstack_founder_extension/plans/01_founder-extension-plan.md)
- **Summary**: [01_founder-extension-summary.md](233_research_gstack_founder_extension/summaries/01_founder-extension-summary.md)

**Description**: Research https://github.com/garrytan/gstack to see what elements would make sense to integrate into my agent system as a new founder/ extension.

---

### 232. Update example templates to be YC compliant
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: Task #229, Task #230, Task #231
- **Research**:
  - [01_meta-research.md](232_example_templates_yc_compliance/reports/01_meta-research.md)
  - [02_example-analysis.md](232_example_templates_yc_compliance/reports/02_example-analysis.md)
- **Plan**: [01_yc-compliance-plan.md](232_example_templates_yc_compliance/plans/01_yc-compliance-plan.md)
- **Summary**: [02_yc-compliance-summary.md](232_example_templates_yc_compliance/summaries/02_yc-compliance-summary.md)

**Description**: Simplify all 4 example pitch deck files in `.claude/extensions/present/examples/` to demonstrate YC-compliant design. Remove complex panel layouts, use larger fonts (28pt+ body, 44pt+ titles), and ensure each slide shows one-idea-per-slide principle. Files: professional-blue-pitch.typ, premium-dark-pitch.typ, minimal-light-pitch.typ, growth-green-pitch.typ.

---

### 231. Update pitch-deck-structure with stricter guidelines
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: Task #228
- **Research**: [01_meta-research.md](231_pitch_deck_structure_update/reports/01_meta-research.md)
- **Plan**: [01_pitch-deck-enforcement.md](231_pitch_deck_structure_update/plans/01_pitch-deck-enforcement.md)
- **Summary**: [02_pitch-deck-enforcement-summary.md](231_pitch_deck_structure_update/summaries/02_pitch-deck-enforcement-summary.md)

**Description**: Update `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` with mandatory enforcement language. Add "Content Density Rules" section (max 1 idea per slide, max 5 bullets), "Typography Enforcement" section (min 24pt body, min 40pt titles), strengthen anti-patterns from advisory to PROHIBITED, and add validation checklist with pass/fail criteria.

---

### 230. Update touying-pitch-deck-template with simpler layouts
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: Task #228
- **Research**: [01_meta-research.md](230_touying_template_simplification/reports/01_meta-research.md)
- **Plan**: [01_template-simplification.md](230_touying_template_simplification/plans/01_template-simplification.md)
- **Summary**: [02_implementation-summary.md](230_touying_template_simplification/summaries/02_implementation-summary.md)

**Description**: Update `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` to remove complex layout patterns. Replace multi-column grid examples with single-column layouts, increase default font sizes (32pt body, 48pt titles), remove panel/card helper patterns, and add explicit "DO NOT USE" section documenting prohibited layout patterns.

---

### 229. Update deck-agent with strict YC enforcement
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: Task #228
- **Research**:
  - [01_meta-research.md](229_deck_agent_enforcement/reports/01_meta-research.md)
  - [02_deck-agent-research.md](229_deck_agent_enforcement/reports/02_deck-agent-research.md)
- **Plan**: [01_deck-agent-enforcement.md](229_deck_agent_enforcement/plans/01_deck-agent-enforcement.md)
- **Summary**: [01_implementation-summary.md](229_deck_agent_enforcement/summaries/01_implementation-summary.md)

**Description**: Update `.claude/extensions/present/agents/deck-agent.md` to enforce YC compliance. Add hard limit of 10 slides max, enforce minimum font sizes (24pt body, 40pt titles) in generated Typst, add content density validation (one idea per slide), simplify default layouts by removing multi-column grids, and add YC compliance validation before returning with compliance_passed boolean in metadata.

---

### 228. Add YC Compliance Checklist context file
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: None
- **Research**:
  - [01_meta-research.md](228_yc_compliance_checklist/reports/01_meta-research.md)
  - [02_yc-compliance-research.md](228_yc_compliance_checklist/reports/02_yc-compliance-research.md)
- **Plan**: [01_yc-compliance-plan.md](228_yc_compliance_checklist/plans/01_yc-compliance-plan.md)
- **Summary**: [01_implementation-summary.md](228_yc_compliance_checklist/summaries/01_implementation-summary.md)

**Description**: Create `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` with hard enforcement rules for YC-style pitch decks. Include: max 10 slides, min 24pt body font, min 40pt titles, one idea per slide, max 5 bullets per slide. Document prohibited patterns (screenshots, complex grids, nested panels, small fonts). Provide pass/fail validation criteria and pre-flight checklist.

---

### 227. Enhance /meta with topic consolidation and embedded research
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meta-enhancement-patterns.md](227_enhance_meta_topic_consolidation/reports/01_meta-enhancement-patterns.md)
- **Plan**: [02_meta-enhancement-plan.md](227_enhance_meta_topic_consolidation/plans/02_meta-enhancement-plan.md)
- **Summary**: [03_meta-enhancement-summary.md](227_enhance_meta_topic_consolidation/summaries/03_meta-enhancement-summary.md)

**Description**: Modify /meta command behavior to (1) actively consolidate related items into minimal topic-based tasks using aggressive grouping, and (2) generate research report artifacts during task creation so tasks start in RESEARCHED status. Changes affect meta-builder-agent.md interview stages, skill-meta postflight, and state.json artifact linking.

**Scope**:
- meta-builder-agent.md: Add consolidation logic in Stage 3 (IdentifyUseCases), add research artifact generation in Stage 6 (CreateTasks)
- skill-meta.md: Update to handle RESEARCHED status and artifact linking in postflight
- multi-task-creation-standard.md: Document the "minimize tasks" principle

---

### 226. Implement multi-line artifact linking in TODO.md for 2+ artifacts
- **Effort**: 4-6 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-18
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_artifact-linking-audit.md](226_multiline_artifact_linking/reports/01_artifact-linking-audit.md)
- **Plan**: [02_multiline-linking-plan.md](226_multiline_artifact_linking/plans/02_multiline-linking-plan.md)
- **Summary**: [03_multiline-linking-summary.md](226_multiline_artifact_linking/summaries/03_multiline-linking-summary.md)

**Description**: The current artifact linking format puts all artifacts of the same type on one line, comma-separated. For tasks with multiple research iterations (e.g., 10 research reports for ProofChecker task 981, 6 for task 988), this produces unreadable single lines. Implement a new standard: when a task has a single artifact of a given type, keep the current inline format; when 2+ artifacts exist, switch to an indented multi-line list. Update all components that write artifact links: 3 core skills (skill-researcher, skill-planner, skill-implementer), 4 extension skills (skill-web-research, skill-web-implementation, skill-nix-implementation, skill-grant), the standalone skill-status-sync, the canonical standard files (state-management.md, artifact-formats.md), the inline-status-update.md pattern file, and 2 process workflow docs (research-workflow.md, planning-workflow.md).

---

### 225. Enforce postflight boundary after agent delegation in skills
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-17
- **Research Completed**: 2026-03-17
- **Planning Started**: 2026-03-17
- **Planning Completed**: 2026-03-17
- **Implementation Started**: 2026-03-17
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_postflight-boundary.md](225_enforce_postflight_boundary_after_agent_delegation/reports/01_postflight-boundary.md)
- **Plan**: [02_implementation-plan.md](225_enforce_postflight_boundary_after_agent_delegation/plans/02_implementation-plan.md)
- **Summary**: [03_postflight-boundary-summary.md](225_enforce_postflight_boundary_after_agent_delegation/summaries/03_postflight-boundary-summary.md)

**Description**: Skills that delegate to subagents via the Task tool are violating the "thin wrapper" pattern by continuing to make implementation changes after the agent returns. Evidence from `/implement 982` output shows skill-lean-implementation: (1) Agent completed at line 68 ("Done - 87 tool uses"), (2) Skill then ran git status, lake build, lean_goal MCP tool, and made Edit calls to DovetailedBuild.lean (lines 74-133). This violates the architectural boundary where skills should only do postflight operations (read metadata, update status, link artifacts, git commit) after agent return - NOT continue implementation.

**Root Cause**: No explicit prohibition or tool restriction preventing skills from using implementation tools (Edit, Write to source files, MCP tools) during postflight stages.

**Fix Components**:
1. Add "BLOCKED TOOLS IN POSTFLIGHT" section to skill template documentation listing tools that MUST NOT be used after agent returns (Edit on source files, Write to source files, all MCP tools except diagnostic)
2. Update skill-lean-implementation SKILL.md Stage 5-10 to add explicit "DO NOT" constraints
3. Update skill-implementer SKILL.md with same constraints (reference implementation)
4. Add to code-standards.md or create new postflight-boundary-standard.md documenting this architectural rule
5. Consider adding a lint rule to detect this anti-pattern in skill definitions

---

### 224. Add interactive theme and palette picker to /deck command
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-17
- **Research Completed**: 2026-03-17
- **Planning Started**: 2026-03-17
- **Planning Completed**: 2026-03-17
- **Implementation Started**: 2026-03-17
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_interactive-picker-patterns.md](224_add_interactive_theme_palette_picker_to_deck/reports/01_interactive-picker-patterns.md)
- **Plan**: [02_implementation-plan.md](224_add_interactive_theme_palette_picker_to_deck/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](224_add_interactive_theme_palette_picker_to_deck/summaries/03_implementation-summary.md)

**Description**: Replace --theme and add --palette flags with an AskUserQuestion-based picker that lets users select both the Touying theme (simple, metropolis, dewdrop, university, stargazer) and color palette (professional-blue, premium-dark, minimal-light, growth-green) interactively. The picker should show visual descriptions for each option. Update deck.md command, skill-deck/SKILL.md, and deck-agent.md to support the new interactive selection flow and palette application.

---

### 223. Improve /deck slide themes with polished examples and documentation
- **Effort**: 6-9 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-17
- **Research Completed**: 2026-03-17
- **Planning Started**: 2026-03-17
- **Planning Completed**: 2026-03-17
- **Implementation Started**: 2026-03-17
- **Completed**: 2026-03-17
- **Language**: general
- **Dependencies**: None
- **Research**: [01_investor-pitch-themes.md](223_improve_deck_themes_examples_documentation/reports/01_investor-pitch-themes.md)
- **Plan**: [02_implementation-plan.md](223_improve_deck_themes_examples_documentation/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](223_improve_deck_themes_examples_documentation/summaries/03_implementation-summary.md)

**Description**: The slide decks created by /deck in the present/ extension need improvement. This task covers: (1) Research online to find the best, most polished slide themes suitable for investor pitch decks - focus on professional VC presentation aesthetics, modern typography, color schemes, and Typst/Touying-compatible patterns; (2) Create .claude/extensions/present/examples/ directory with sample pitch decks demonstrating each recommended theme style - each example should be a complete, compilable Typst file showing the theme applied to a mock startup pitch; (3) Create .claude/extensions/present/README.md documentation explaining extension purpose and capabilities, /deck and /grant commands, available themes with visual descriptions, how to compile and customize decks, and links to the examples/ directory.

---

### 222. Document memory extension usage patterns and expectations
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Started**: 2026-03-17
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_memory-extension-analysis.md](222_document_memory_extension_usage/reports/01_memory-extension-analysis.md)
- **Plan**: [02_implementation-plan.md](222_document_memory_extension_usage/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](222_document_memory_extension_usage/summaries/03_implementation-summary.md)

**Description**: Understand how the memory extension works and create detailed documentation in .claude/extensions/memory/README.md to inform expectations and usage patterns.

---

### 221. Fix phase status marker updates in grant-agent, skill-grant, and latex/typst implementation agents
- **Effort**: 2.25 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-17
- **Research**: [01_phase-status-markers.md](221_fix_phase_status_markers_implementation_agents/reports/01_phase-status-markers.md)
- **Plan**: [02_implementation-plan.md](221_fix_phase_status_markers_implementation_agents/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](221_fix_phase_status_markers_implementation_agents/summaries/03_implementation-summary.md)
- **Language**: meta
- **Dependencies**: None

**Description**: Fix phase status marker updates across implementation agents in the Vision repository. Three issues to address: (1) grant-agent lacks Phase Checkpoint Protocol - does not update plan-level or phase-level status markers ([NOT STARTED] -> [IN PROGRESS] -> [COMPLETED]) during the assemble workflow, unlike general-implementation-agent which has Stage 4A (mark phase in progress) and Stage 4D (mark phase complete) with per-phase git commits; (2) skill-grant lacks calls to update-plan-status.sh at preflight and postflight, unlike skill-implementer which calls this script; (3) latex-implementation-agent and typst-implementation-agent have incomplete phase marker instructions - they mention updates but lack detailed Edit tool patterns and a Phase Checkpoint Protocol section. Fix all three by: adding a Phase Checkpoint Protocol section to grant-agent mirroring general-implementation-agent, adding update-plan-status.sh calls to skill-grant, and expanding phase marker instructions in latex/typst implementation agents. All agents should update TODO.md, state.json, plan file phase headers, and plan metadata consistently.

---

### 220. Add `--fix-it` flag to `/grant` command with grant directory scanning
- **Effort**: 3-5 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-03-17
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_fix-it-flag-research.md](220_add_fix_it_flag_to_grant_command/reports/01_fix-it-flag-research.md)
- **Plan**: [02_implementation-plan.md](220_add_fix_it_flag_to_grant_command/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](220_add_fix_it_flag_to_grant_command/summaries/03_implementation-summary.md)

**Description**: Add a `--fix-it N` mode to the `/grant` command (`.claude/extensions/present/commands/grant.md`) that scans the grant project directory for embedded `FIX:` and `TODO:` tags and creates structured tasks to implement those changes, following the same interactive pattern as the `/fix-it` command.

**Component 1 — Modify `/grant` command** (`grant.md`): Add `--fix-it` to the Modes table and Mode Detection section. Syntax: `/grant N --fix-it`. Parse the grant number N, validate the task exists in state.json (or archive), extract the slug to locate `grants/{N}_{slug}/`, and abort with a clear message if the directory does not exist. Then delegate to `skill-grant-fix-it` with args `task_number={N} grant_dir=grants/{N}_{slug}/ session_id={session_id}`. Implement GATE IN / GATE OUT checkpoints matching the pattern used by `--draft` and `--budget` modes. Output on success: list of task numbers created and suggested next steps.

**Component 2 — Create `skill-grant-fix-it`** (new file `.claude/extensions/present/skills/skill-grant-fix-it/SKILL.md`): Direct-execution skill that mirrors the logic of `skill-fix-it` but scoped to a grant directory. Steps: (1) Accept `task_number` and `grant_dir` from args. (2) Scan `{grant_dir}` recursively for `FIX:` and `TODO:` tags across all relevant file types (`.tex`, `.md`, `.bib`, `.txt`). Use comment-style patterns appropriate to each type: `% FIX:` / `% TODO:` for `.tex`, `<!-- FIX:` / `<!-- TODO:` for `.md`, `# FIX:` / `# TODO:` for `.bib`/`.txt`. (3) Display tag scan results to the user before any selection. If no tags found, report and exit. (4) Prompt for task type selection via `AskUserQuestion` with `multiSelect: true` — offer "fix-it task" (combine all FIX: tags into one task) and/or "TODO tasks" (one task per selected TODO: item, or grouped by topic). (5) For TODO tasks with 2+ items, offer topic grouping using the same clustering algorithm as `skill-fix-it` (shared key terms, directory proximity, action type). (6) Confirm before creating. (7) Create selected tasks in `specs/state.json` and `specs/TODO.md` with `language="grant"` so they route through the grant workflow. Task descriptions include file paths and line numbers from the scan. (8) Git commit with message `fix-it: create {N} tasks from grant {M} tags`.

**Component 3 — Register in manifest.json**: Add `skill-grant-fix-it` to the `skills` array in `.claude/extensions/present/manifest.json`.

---

### 219. Incorporate ProofChecker documentation, patterns, and /merge command into nvim .claude/ system
- **Effort**: 6-8 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-16
- **Completed**: 2026-03-16
- **Language**: meta
- **Research**: [01_proofchecker-integration.md](219_incorporate_proofchecker_docs_and_patterns/reports/01_proofchecker-integration.md)
- **Plan**: [02_implementation-plan.md](219_incorporate_proofchecker_docs_and_patterns/plans/02_implementation-plan.md)
- **Summary**: [03_implementation-summary.md](219_incorporate_proofchecker_docs_and_patterns/summaries/03_implementation-summary.md)

**Description**: Incorporate missing documentation, patterns, format schemas, and commands from ProofChecker's `.claude/` system to make the nvim agent system more complete and portable across both GitHub and GitLab repositories. Specifically: (1) Add `blocked-mcp-tools.md` to the lean extension's context as a standalone doc with the unblocking procedure (currently only embedded in mcp-tools-guide.md without formal recovery steps); (2) Create `context/core/reference/state-json-schema.md` — a complete schema reference for state.json; (3) Create `context/core/reference/skill-agent-mapping.md` — maps skills to agents and routing rules (currently only in CLAUDE.md); (4) Create `context/core/patterns/early-metadata-pattern.md` — pattern for writing metadata early to enable recovery from interrupted delegation; (5) Create `context/core/patterns/mcp-tool-recovery.md` — structured retry/fallback patterns for MCP tool failures; (6) Create `context/core/formats/handoff-artifact.md` — schema for teammate handoff documents enabling context-efficient continuation (needed for --team successor pattern); (7) Create `context/core/formats/progress-file.md` — schema for progress-tracking JSON files supporting resumable work; (8) Update `context/index.json` with entries for all new files so agents can discover them; (9) Create `/merge` command in core `.claude/commands/merge.md` — adapt ProofChecker's GitLab-only `/merge` command to auto-detect whether the current repo is GitHub or GitLab (check for `.git/config` remote URL patterns or `gh`/`glab` auth status) and use the appropriate CLI (`gh pr create` for GitHub, `glab mr create` for GitLab), supporting --draft, --title, --body flags and providing unified MR/PR workflow regardless of platform. The reference source is `/home/benjamin/Projects/ProofChecker/.claude/` — read each ProofChecker file, adapt it to the nvim extension-based architecture (removing ProofChecker-specific content, generalizing for a multi-extension/multi-platform system), and place in the correct location.

---

### 218. Implement `--team` flag for `/research` command
- **Effort**: 12-16 hours
- **Status**: [COMPLETED]
- **Started**: 2026-03-16
- **Completed**: 2026-03-16
- **Language**: meta
- **Research**: [01_team-flag-research.md](218_implement_team_flag_for_research_command/reports/01_team-flag-research.md)
- **Plan**: [02_team-flag-implementation.md](218_implement_team_flag_for_research_command/plans/02_team-flag-implementation.md)
- **Summary**: [03_team-flag-summary.md](218_implement_team_flag_for_research_command/summaries/03_team-flag-summary.md)

**Description**: Implement `--team` flag for `/research` command to enable parallel multi-agent research using the research-coordinator pattern. Root cause: `--team` is silently ignored — passed as part of the focus prompt text with no flag parsing in research.md. Fix requires: (1) add `--team` flag parsing to research.md, (2) add team routing for the grant language (and other languages), (3) implement or wire up research-coordinator pattern for parallel multi-agent research. Investigation found `--team` was planned in archived task 093 but never implemented.

---

### 217. Revise /grant workflow order: --draft and --budget before /plan
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-improvements.md](217_revise_grant_workflow_order_draft_budget_before_plan/reports/01_grant-improvements.md)
- **Plan**: [02_workflow-improvements.md](217_revise_grant_workflow_order_draft_budget_before_plan/plans/02_workflow-improvements.md)
- **Summary**: [03_workflow-improvements-summary.md](217_revise_grant_workflow_order_draft_budget_before_plan/summaries/03_workflow-improvements-summary.md)

**Description**: Revise the /grant command and related utilities in the present/ extension so that the recommended workflow places --draft and --budget before /plan N. The correct order is: (1) /grant "Description", (2) /research N, (3) /grant N --draft, (4) /grant N --budget, (5) /plan N, (6) /implement N. This means drafting and budgeting happen as part of exploratory work that informs the formal plan, and /plan N creates the implementation plan based on the draft/budget artifacts before /implement N assembles everything into grants/{N}_{slug}/. Update all references to the recommended workflow in grant.md, skill-grant/SKILL.md, grant-agent.md, and EXTENSION.md.

---

### 216. Refactor /grant command to output final materials via /implement to grants/ directory
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-implement-routing.md](216_refactor_grant_implement_output_to_grants_dir/reports/01_grant-implement-routing.md)
- **Plan**: [04_grant-refactor-revised.md](216_refactor_grant_implement_output_to_grants_dir/plans/04_grant-refactor-revised.md)
- **Summary**: [05_grant-refactor-summary.md](216_refactor_grant_implement_output_to_grants_dir/summaries/05_grant-refactor-summary.md)

**Description**: Remove the `--finish` flag from the /grant command and update the grant workflow so that running `/implement N` on a grant task assembles all intermediate artifacts (drafts, budgets from `specs/{NNN}_{SLUG}/`) and writes the final grant output to a new `grants/{NN}_{grant-slug}/` directory in the project root. Files to modify: (1) `grant.md` command — remove Finish Mode section and update recommended workflow output; (2) `skill-grant/SKILL.md` — remove finish workflow type from routing table, validation, and all case statements; (3) `grant-agent.md` — remove finish workflow execution and update routing table; (4) `EXTENSION.md` — update documentation to reflect new workflow ending with `/implement N`; and the grant-specific implementation handling needs to be added so that `/implement N` on a grant task generates the final assembled output in `grants/{NN}_{grant-slug}/`.

---

### 215. Revise /grant command design for elegant integration with core agent system
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_grant-command-design.md](215_revise_grant_command_design/reports/01_grant-command-design.md)
- **Plan**: [03_grant-command-plan.md](215_revise_grant_command_design/plans/03_grant-command-plan.md)
- **Summary**: [04_grant-command-summary.md](215_revise_grant_command_design/summaries/04_grant-command-summary.md)

**Description**: Revise the /grant command to work like the /task command except that it should create a task with the type set to 'grant'. Review the best options for an elegant design that avoids redundancy with /research, /plan, and /implement commands while maintaining modularity. Consider whether /grant should support --draft and --budget flags for grant-specific stages, or whether these should be separate commands. The design should integrate naturally with the existing core agent system while fitting in among the other extensions.

---

### 210. Rename grant/ extension directory to present/
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_rename-extension-dir.md](210_rename_grant_extension_to_present/plans/01_rename-extension-dir.md)
- **Summary**: [01_rename-extension-summary.md](210_rename_grant_extension_to_present/summaries/01_rename-extension-summary.md)

**Description**: Rename the extension directory from `.claude/extensions/grant/` to `.claude/extensions/present/`. Update manifest.json: change `name` field from "grant" to "present", `language` field from "grant" to "present", and `merge_targets.claudemd.section_id` from "extension_grant" to "extension_present". This is the foundational rename that all subsequent tasks depend on.

---

### 211. Move deck elements from filetypes/ to present/
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #210
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_move-deck-files.md](211_move_deck_elements_to_present/plans/01_move-deck-files.md)
- **Summary**: [01_move-deck-summary.md](211_move_deck_elements_to_present/summaries/01_move-deck-summary.md)

**Description**: Move deck-related files from the filetypes/ extension into the renamed present/ extension. Files to move: `agents/deck-agent.md`, `commands/deck.md`, `skills/skill-deck/SKILL.md`, and context patterns `context/project/filetypes/patterns/pitch-deck-structure.md` and `context/project/filetypes/patterns/touying-pitch-deck-template.md`. Move context patterns to `context/project/present/patterns/` in the present/ extension.

---

### 212. Update present/ extension metadata for deck integration
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #211
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Plan**: [01_update-metadata.md](212_update_present_extension_metadata_for_deck/plans/01_update-metadata.md)
- **Summary**: [01_update-metadata-summary.md](212_update_present_extension_metadata_for_deck/summaries/01_update-metadata-summary.md)

**Description**: Update present/ extension configuration to register the newly moved deck components. Update `manifest.json` provides arrays: add "deck-agent.md" to agents, "skill-deck" to skills, "deck.md" to commands. Update `EXTENSION.md`: add a deck documentation section and revise the title to reflect both grant writing and presentation capabilities. Update `index-entries.json`: add the two deck context entries (pitch-deck-structure.md, touying-pitch-deck-template.md) with correct present/ paths and load_when referencing deck-agent and /deck command. Update `deck-agent.md` to change all `@context/project/filetypes/patterns/` references to `@context/project/present/patterns/`.

---

### 213. Clean up filetypes/ extension after deck migration
- **Effort**: 30 min
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #211
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_filetypes-cleanup-research.md](213_cleanup_filetypes_extension_after_deck_migration/reports/01_filetypes-cleanup-research.md)
- **Plan**: [02_cleanup-filetypes-plan.md](213_cleanup_filetypes_extension_after_deck_migration/plans/02_cleanup-filetypes-plan.md)
- **Summary**: [03_cleanup-filetypes-summary.md](213_cleanup_filetypes_extension_after_deck_migration/summaries/03_cleanup-filetypes-summary.md)

**Description**: Remove all deck-related references from the filetypes/ extension after deck components have been moved to present/. Remove "deck-agent.md" from `manifest.json` agents array, "skill-deck" from skills array, and "deck.md" from commands array. Remove the deck documentation section from `EXTENSION.md`. Remove the two deck context entries (pitch-deck-structure.md, touying-pitch-deck-template.md) from `index-entries.json`.

---

### 214. Restructure context/project/grant/ to context/project/present/
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #212
- **Created**: 2026-03-16
- **Completed**: 2026-03-16
- **Research**: [01_context-restructure-research.md](214_restructure_context_grant_to_present/reports/01_context-restructure-research.md)
- **Plan**: [01_context-restructure-plan.md](214_restructure_context_grant_to_present/plans/01_context-restructure-plan.md)
- **Summary**: [01_context-restructure-summary.md](214_restructure_context_grant_to_present/summaries/01_context-restructure-summary.md)

**Description**: Rename the context subdirectory from `context/project/grant/` to `context/project/present/` within the present/ extension. Update all 16 path entries in `index-entries.json` from `project/grant/` to `project/present/` (including README and all domain/patterns/standards/templates/tools files). Update `grant-agent.md` all `@context/project/grant/` @-references to `@context/project/present/`. Update any `@.claude/context/project/grant/` references in `EXTENSION.md` to `@.claude/context/project/present/`. Update the `provides.context` field in `manifest.json` from "project/grant" to "project/present".

---

### 209. Create EXTENSION.md and index-entries.json for grant extension
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #207, Task #208
- **Created**: 2026-03-15
- **Completed**: 2026-03-16
- **Research**: [01_extension-metadata-research.md](209_create_extension_metadata/reports/01_extension-metadata-research.md)
- **Plan**: [02_extension-metadata-plan.md](209_create_extension_metadata/plans/02_extension-metadata-plan.md)
- **Summary**: [03_extension-metadata-summary.md](209_create_extension_metadata/summaries/03_extension-metadata-summary.md)

**Description**: Create the EXTENSION.md file with content to inject into CLAUDE.md when the grant extension is loaded, and index-entries.json with canonical paths for context discovery. This finalizes the extension for use with the `<leader>ac` loader.

---

### 208. Create grant context files for domain knowledge
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15
- **Research**: [01_grant-context-patterns.md](208_create_grant_context_files/reports/01_grant-context-patterns.md)
- **Plan**: [01_grant-context-plan.md](208_create_grant_context_files/plans/01_grant-context-plan.md)
- **Summary**: [01_grant-context-summary.md](208_create_grant_context_files/summaries/01_grant-context-summary.md)

**Description**: Create context files in grant/context/ containing domain knowledge for grant writing. Include templates, funder research patterns, proposal structure guidelines, and budget justification formats. These files will be progressively loaded by the grant-agent based on task needs.

---

### 207. Create /grant command
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: Task #206
- **Created**: 2026-03-15
- **Completed**: 2026-03-16
- **Research**: [01_grant-command-research.md](207_create_grant_command/reports/01_grant-command-research.md)
- **Plan**: [02_grant-command-plan.md](207_create_grant_command/plans/02_grant-command-plan.md)
- **Summary**: [03_grant-command-summary.md](207_create_grant_command/summaries/03_grant-command-summary.md)

**Description**: Create grant/commands/grant.md command following existing command patterns. The command should parse arguments (e.g., project name, funder, deadline), invoke skill-grant via the Skill tool, and handle postflight operations including git commits.

---

### 206. Create skill-grant thin wrapper
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #205
- **Created**: 2026-03-15
- **Research**: [01_skill-wrapper-patterns.md](206_create_skill_grant_wrapper/reports/01_skill-wrapper-patterns.md)
- **Plan**: [01_skill-grant-plan.md](206_create_skill_grant_wrapper/plans/01_skill-grant-plan.md)
- **Summary**: [01_skill-grant-summary.md](206_create_skill_grant_wrapper/summaries/01_skill-grant-summary.md)

**Description**: Create grant/skills/skill-grant/SKILL.md as a thin wrapper that validates inputs, prepares delegation context, invokes grant-agent via the Agent tool, validates the return, and propagates results. Follow the skill-meta pattern for internal postflight handling.

---

### 205. Create grant-agent with research and writing capabilities
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-03-15
- **Research Completed**: 2026-03-15
- **Planning Started**: 2026-03-15
- **Planning Completed**: 2026-03-15
- **Implementation Started**: 2026-03-15
- **Implementation Completed**: 2026-03-15
- **Language**: meta
- **Dependencies**: Task #204
- **Created**: 2026-03-15
- **Research**: [01_grant-agent-patterns.md](205_create_grant_agent/reports/01_grant-agent-patterns.md)
- **Plan**: [01_grant-agent-plan.md](205_create_grant_agent/plans/01_grant-agent-plan.md)
- **Summary**: [01_grant-agent-summary.md](205_create_grant_agent/summaries/01_grant-agent-summary.md)

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

## Recommended Order

1. **87** -> plan (independent)
2. **78** -> implement (independent)
