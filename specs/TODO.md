---
next_project_number: 490
---

# TODO

## Task Order

*Updated 2026-04-19. 4 active tasks remaining.*

### Pending

- **489** [COMPLETED] -- Fix /meta prompt mode regression: model bypasses Skill delegation and implements directly instead of creating tasks
- **488** [COMPLETED] -- Widen load_when for state-management-schema.md in index.json so task-creating commands see TODO.md entry format spec
- **487** [COMPLETED] -- Update stale meta sister files (architecture-principles, standards-checklist, interview-patterns)
- **485** [COMPLETED] -- Rewrite meta-guide.md to match current system
- **486** [COMPLETED] -- Align skill-meta and agent frontmatter/references
- **482** [IMPLEMENTING] -- Create project-overview detection rule
- **483** [NOT STARTED] -- Create skill-project-overview for interactive repo generation (depends: 482)
- **484** [NOT STARTED] -- Wire project-overview components into extension system (depends: 482, 483)
- **476** [COMPLETED] -- Consolidate extension system documentation into single source of truth
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 489. Fix /meta prompt mode regression: model bypasses Skill delegation and implements directly instead of creating tasks
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [489_fix_meta_command_bypass/reports/01_meta-bypass-analysis.md]
- **Plan**: [489_fix_meta_command_bypass/plans/01_meta-bypass-fix.md]
- **Summary**: [489_fix_meta_command_bypass/summaries/01_meta-bypass-summary.md]

**Description**: When `/meta PROMPT` is invoked with a clear, actionable request (e.g., "add a --roadmap flag to /plan"), the model bypasses the entire Skill delegation chain and implements the changes directly using Read/Edit/Write tools, instead of creating tasks via the interactive picker flow.

**Root Cause Analysis**:

The command, skill, and agent files are structurally intact -- the regression is behavioral:

1. **Command expansion injects actionable context**: When `/meta PROMPT` runs, the full meta.md content is expanded inline. The user's prompt ("add --roadmap flag") is so clear that the model treats it as implementation instructions rather than as input to the task-creation workflow.

2. **`allowed-tools: Skill` is advisory, not enforced**: The command frontmatter says only `Skill` is allowed, but the model has global permission for Read/Write/Edit from settings.json. There's no hook or enforcement mechanism to prevent the model from using those tools when the /meta command context is active.

3. **No anti-bypass constraint**: Unlike `/plan` which has an explicit "Anti-Bypass Constraint" section with a PostToolUse hook (`validate-plan-write.sh`) that catches direct artifact writes, `/meta` has no equivalent enforcement. The "FORBIDDEN" and "REQUIRED" sections in meta.md are purely instructional.

4. **Prompt mode's abbreviated flow is too terse**: The prompt mode flow (5 steps) gives high-level guidance ("Parse prompt -> Check related -> Propose breakdown -> Confirm -> Create") but doesn't emphasize the mandatory Skill tool invocation step prominently enough. The model sees a shortcut and takes it.

**Proposed Fix Areas**:

- **meta.md**: Add an Anti-Bypass Constraint section (matching /plan pattern) that explicitly prohibits direct file edits outside specs/ and mandates Skill tool invocation
- **meta.md**: Strengthen prompt mode flow with explicit "EXECUTE NOW: Invoke Skill tool" directive (matching /plan's STAGE 2 pattern)
- **Hook enforcement**: Consider adding a PostToolUse hook that detects when /meta context is active and Write/Edit is used on non-specs/ files, injecting corrective guidance
- **skill-meta**: The loaded version at .claude/skills/ has `agent: meta-builder-agent` frontmatter (good), but the extension source at extensions/core/ is missing this field -- sync them
- **meta-builder-agent**: The prompt mode (Stage 3B) flow should more explicitly require AskUserQuestion confirmation before any task creation, with a stronger gate

---

### 488. Widen load_when for state-management-schema.md in index.json so task-creating commands see TODO.md entry format spec
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [488_widen_todo_entry_format_context/reports/01_widen-load-when.md]
- **Plan**: [488_widen_todo_entry_format_context/plans/01_widen-load-when.md]
- **Summary**: [488_widen_todo_entry_format_context/summaries/01_widen-load-when-summary.md]

**Description**: Widen load_when for state-management-schema.md in index.json so /review and all task-creating commands see the TODO.md entry format spec. Add explicit format reference to review.md task creation section.

### 487. Update stale meta sister files (architecture-principles, standards-checklist, interview-patterns)
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [487_update_stale_meta_sister_files/reports/01_meta-sister-files.md]
- **Plan**: [487_update_stale_meta_sister_files/plans/01_update-meta-sister-files.md]
- **Summary**: [487_update_stale_meta_sister_files/summaries/01_update-meta-sister-files-summary.md]
- **Description**: Update or consolidate 3 stale sister files in `.claude/context/meta/`: architecture-principles.md (references .opencode, phantom 3-level context, non-existent tools), standards-checklist.md (references subagent-return.md, non-existent frontmatter fields), interview-patterns.md (old interview stages). Rewrite to match current system or remove if redundant with new meta-guide.md. Sync both deployed and extension source copies. Follow-on from tasks 485/486.

### 485. Rewrite meta-guide.md to match current system
- **Effort**: Large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [485_rewrite_meta_guide/reports/01_team-research.md]
- **Plan**: [485_rewrite_meta_guide/plans/01_rewrite-meta-guide.md]
- **Summary**: [485_rewrite_meta_guide/summaries/01_rewrite-meta-guide-summary.md]

**Description**: Complete rewrite of `.claude/extensions/core/context/meta/meta-guide.md` (462 lines). The current file documents a phantom system: a 12-question interview across 5 phases, `.opencode/agent/subagents/` paths, marketing-style claims ("+20% routing accuracy"), and a 3-level context allocation model that doesn't exist. Rewrite to document the actual /meta workflow: 3 modes (interactive/prompt/analyze), the 7-stage interview, multi-task creation standard compliance, and current system paths. Fix broken reference to `.claude/context/standards/commands.md`. Update both extension source and deployed copy.

### 486. Align skill-meta and agent frontmatter/references
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [486_align_skill_meta_frontmatter/reports/01_team-research.md]
- **Plan**: [486_align_skill_meta_frontmatter/plans/01_align-skill-meta.md]
- **Summary**: [486_align_skill_meta_frontmatter/summaries/01_align-skill-meta-summary.md]

**Description**: Bundle of small fixes across the /meta pipeline: (1) Add `context: fork` and `agent: meta-builder-agent` to skill-meta frontmatter per thin-wrapper pattern, (2) Fix stale `subagent-return.md` references to `return-metadata-file.md` in both skill and agent, (3) Remove hardcoded `latex` domain type from DetectDomainType in meta-builder-agent.md (replace with extension-aware pattern or `general` fallback), (4) All changes in extension source copies under `.claude/extensions/core/`. Mirror to deployed copies.

### 482. Create project-overview detection rule
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Plan**: [specs/482_project_overview_detection_rule/plans/01_overview-detection-rule.md]
- **Summary**: [specs/482_project_overview_detection_rule/summaries/01_overview-detection-rule-summary.md]

**Description**: Create a detection rule that fires when `project-overview.md` contains the `<!-- GENERIC TEMPLATE` marker. The rule should instruct the agent to notify the user and suggest invoking the project-overview generation workflow (task 483's skill).

### 483. Create skill-project-overview for interactive repo generation
- **Effort**: Medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #482

**Description**: Create `skill-project-overview` implementing a 3-step workflow: (1) automatically research the repo (directory structure, languages, frameworks, key files), (2) ask the user interactive questions to verify findings and make clarifications, (3) create a task with a research artifact summarizing findings, then close with guidance to continue with `/research` or proceed to `/plan` then `/implement`.

### 484. Wire project-overview components into extension system
- **Effort**: Small
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: Task #482, #483

**Description**: Wire the detection rule and skill into the extension system: update CLAUDE.md skill/agent tables, add context index entries, update extension manifest `provides` and `index-entries.json`, and update `update-project.md` to reference the new automated workflow.

### 481. Remove check_core_purity() function from check-extension-docs.sh
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Plan**: [481_remove_check_core_purity_from_check_extension_docs/plans/01_remove-core-purity.md]
- **Summary**: [481_remove_check_core_purity_from_check_extension_docs/summaries/01_remove-core-purity-summary.md]

**Description**: Remove check_core_purity() function from check-extension-docs.sh (both source and deployed copy) added by task 480 - this prevention infrastructure is scope creep beyond the reference removal task.

### 480. Comprehensively strip ALL remaining nvim/neovim/neotex/VimTeX references from extension sources
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [480_strip_all_nvim_refs_from_ext_sources/reports/01_team-research.md]
- **Plan**: [480_strip_all_nvim_refs_from_ext_sources/plans/01_strip-nvim-refs.md]
- **Summary**: [480_strip_all_nvim_refs_from_ext_sources/summaries/01_strip-nvim-refs-summary.md]

**Description**: Comprehensively strip ALL remaining nvim/neovim/neotex/VimTeX references from core and latex extension sources. Third attempt -- tasks 478 and 479 each fixed only a subset. Zed post-reload audit (see /home/benjamin/.config/zed/specs/065_strip_nvim_references_post_sync/reports/04_post-reload-diff-review.md) still finds 60 references across 18 files after reloading. Priority 1 (must fix): (1) Remove VimTeX Integration subsection from extensions/latex/EXTENSION.md upstream (propagates `<leader>` bindings into CLAUDE.md on reload), (2) Remove "Load For Neovim Code" block from extensions/core/agents/code-reviewer-agent.md, (3) Remove nvim routing row and "moved to nvim extension" notes from extensions/core/docs/README.md, (4) Remove "moved to nvim extension" entries from extensions/core/docs/docs-README.md, (5) Remove nvim case block from extensions/core/scripts/validate-wiring.sh, (6) Replace "nvim" example in extensions/core/templates/extension-readme-template.md. Priority 2 (should fix): Replace "neovim" example topics in memory documentation (6 files, ~33 refs in extensions/core/skills/skill-memory/SKILL.md, extensions/core/context/project/memory/*.md, extensions/core/commands/learn.md). Priority 3: Genericize nvim references in extensions/core/context/project/latex/tools/compilation-guide.md, extensions/core/context/project/typst/tools/compilation-guide.md, extensions/core/context/standards/postflight-tool-restrictions.md, and extensions/core/scripts/lint/lint-postflight-boundary.sh. Mirror ALL source changes to deployed copies. Verify with `grep -riE 'nvim|neovim|neotex' .claude/extensions/core/ .claude/extensions/latex/` returning zero actionable results.

### 479. Fix remaining nvim-specific references in core extension sources
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [specs/479_fix_remaining_nvim_refs_in_core_ext/reports/01_nvim-refs-audit.md]
- **Plan**: [479_fix_remaining_nvim_refs_in_core_ext/plans/01_fix-nvim-refs.md]
- **Summary**: [specs/479_fix_remaining_nvim_refs_in_core_ext/summaries/01_fix-nvim-refs-summary.md]

**Description**: Fix remaining nvim/neotex references in core extension source files that were missed by task 478 and cause re-contamination on reload: (1) Replace "neotex extension loader" with "extension loader" in templates/claudemd-header.md, (2) Replace "Neovim Lua loader" with "extension loader" in context/guides/extension-development.md, (3) Replace "neovim" in extension example lists in context/architecture/system-overview.md, docs/architecture/system-overview.md, and merge-sources/claudemd.md with generic alternatives, (4) Fix meta-guide.md bug where ".claude/docs/README.md" was changed to duplicate ".claude/README.md, .claude/README.md", (5) Mirror all source changes to deployed copies. Root cause identified in zed post-reload audit report.

### 478. Make extension core docs editor-agnostic and handle project-overview.md per-project generation
- **Effort**: Small
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [specs/478_editor_agnostic_extension_docs/reports/01_team-research.md]
- **Plan**: [478_editor_agnostic_extension_docs/plans/01_editor-agnostic-docs.md]
- **Summary**: [478_editor_agnostic_extension_docs/summaries/01_editor-agnostic-docs-summary.md]

**Description**: Two related changes to prevent nvim-specific contamination when extension core files are synced to other projects: (1) Replace hardcoded `<leader>ac` references with generic "extension picker" language in `extensions/core/` docs (extension-development.md, loader-reference.md, extension-readme-template.md), following the multi-editor pattern already used in extensions/README.md. (2) Exclude project-overview.md from the core extension loader sync -- it describes this repo's specific structure and should not propagate to downstream projects. Instead, provide a stub/template (e.g., update-project.md) that detects when project-overview.md is missing and instructs Claude to suggest generating one based on analysis of the actual project structure. (3) Update deployed copies in `.claude/context/` to match. Existing project-overview.md in this nvim repo remains unchanged.

### 477. Fix generated CLAUDE.md duplicate header, restore README.md, and improve generation
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [477_fix_generated_claudemd_and_restore_readme/reports/01_fix-claudemd-generation.md]
- **Plan**: [477_fix_generated_claudemd_and_restore_readme/plans/01_fix-claudemd-generation.md]
- **Summary**: [477_fix_generated_claudemd_and_restore_readme/summaries/01_fix-claudemd-generation-summary.md]

**Description**: Fix the generated `.claude/CLAUDE.md` file which has a duplicate header (lines 1-10). Restore the missing `.claude/README.md` from git history and update it for accuracy. Add a reference to the root `README.md` in the generated CLAUDE.md. Review the generated CLAUDE.md for additional improvements to how the file is produced.

### 476. Consolidate extension system documentation into single source of truth
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [476_consolidate_extension_system_docs/reports/01_consolidate-ext-docs.md]
- **Plan**: [476_consolidate_extension_system_docs/plans/01_consolidate-ext-docs.md]
- **Summary**: [476_consolidate_extension_system_docs/summaries/01_consolidate-ext-docs-summary.md]

**Description**: Consolidate extension system documentation into a single source of truth to eliminate contradictions between `docs/architecture/extension-system.md`, `context/guides/extension-development.md`, and `docs/guides/creating-extensions.md`. The files have drifted out of sync -- some describe CLAUDE.md as a computed artifact via `generate_claudemd()` while others regress to the old section-injection approach. Additional inconsistencies exist in conflict handling behavior, `provides` field coverage, loader function documentation, and validator expectations vs actual index.json schema.

Scope: (1) Audit the Lua loader implementation for ground truth, (2) designate `docs/architecture/extension-system.md` as the comprehensive reference with other files cross-referencing rather than restating, (3) eliminate content duplication so each concept is documented in exactly one place, (4) fix all contradictions to reflect actual implementation, (5) align `validate-context-index.sh` with actual index.json schema, (6) integrate untracked `loader-reference.md` and `index.schema.json`, (7) clean up stale references.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

## Recommended Order

1. **479** -> research (independent)
2. **480** -> research (independent)
3. **481** -> research (independent)
