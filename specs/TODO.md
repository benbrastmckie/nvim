---
next_project_number: 414
---

# TODO

## Task Order

*Updated 2026-04-13. 10 active tasks remaining.*

### Pending

- **413** [COMPLETED] -- Refine slides skill and command (design questions, routing, delegation)
- **412** [COMPLETED] -- Update documentation examples from Python to Rust
- **411** [COMPLETED] -- Update extension trigger wording to mechanism-agnostic
- **410** [COMPLETED] -- Remove meta Stage 5.5 auto-research artifact generation
- **409** [COMPLETED] -- Remove Phase Checkpoint Protocol from assembly/implement agents
- **398** [NOT STARTED] -- Extract artifact-linking logic to shared helper script
- **394** [NOT STARTED] -- Remove language-to-task_type backward compatibility shim
- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 413. Refine slides skill and command (design questions, routing, delegation)
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Task Type**: meta
- **Research**: [01_refine-slides-skill-command.md](specs/413_refine_slides_skill_command/reports/01_refine-slides-skill-command.md)
- **Plan**: [01_refine-slides-skill-command.md](specs/413_refine_slides_skill_command/plans/01_refine-slides-skill-command.md)
- **Summary**: Ported 8 SKILL.md edits and 3 slides.md edits from Zed working copy.

**Description**: Port slides skill and command refinements from Zed working copy. In `.claude/extensions/present/skills/skill-slides/SKILL.md`: expand Stage 3.5 (Design Questions) with step-by-step guidance replacing bash automation code, simplify agent resolution case statement syntax, streamline delegation context section, remove duplicate agent/workflow routing table from Stage 5, remove "Plan Success" return message format. In `.claude/extensions/present/commands/slides.md`: simplify output format question wording, renumber steps (remove Step 0.0 references), expand Step 2.5 "Enrich Description" with detailed path relativization logic, remove "Plan Success" return message format. Source: `/home/benjamin/.config/zed/CHANGE.md` Theme 6.

---

### 412. Update documentation examples from Python to Rust
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Task Type**: meta
- **Research**: [01_update-docs-python-rust.md](specs/412_update_docs_python_to_rust/reports/01_update-docs-python-rust.md)
- **Plan**: [01_update-docs-python-rust.md](specs/412_update_docs_python_to_rust/plans/01_update-docs-python-rust.md)
- **Summary**: Replaced ~45 Python teaching examples with Rust across 7 documentation files.

**Description**: Replace Python with Rust as the example language in documentation guides, since Python is a real bundled extension and creates confusion when used as a hypothetical teaching example. Files to update: `.claude/docs/guides/creating-skills.md` (agent/skill names python→rust, packages→crates, asyncio→tokio, pytest→cargo test), `.claude/docs/guides/creating-agents.md` (task_context example, context file reference python/→rust/), `.claude/docs/guides/component-selection.md` (skill routing example, "Adding Python Support"→"Adding Rust Support"), `.claude/docs/guides/adding-domains.md` (domain example "python"→"rust"), `.claude/docs/guides/creating-extensions.md` (remove "python" from simple extensions list), `.claude/docs/architecture/system-overview.md` (rename example section), `.claude/context/architecture/component-checklist.md` (language examples). Source: `/home/benjamin/.config/zed/CHANGE.md` Theme 5.

---

### 411. Update extension trigger wording to mechanism-agnostic
- **Effort**: 0.5 hours
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Task Type**: meta
- **Plan**: [01_update-trigger-wording.md](specs/411_update_extension_trigger_wording/plans/01_update-trigger-wording.md)
- **Summary**: Replaced `<leader>ac` trigger wording with mechanism-agnostic alternatives in 5 extension skill files (2 epidemiology, 3 present).

**Description**: Replace Neovim-specific `"Extension is loaded via \`<leader>ac\`"` trigger wording with mechanism-agnostic alternatives in 5 extension skill files. This makes skills portable across loading methods (keybinding, pre-merged, etc.). Files: `.claude/extensions/epidemiology/skills/skill-epi-implement/SKILL.md` (line 34, →"Epidemiology extension is available"), `.claude/extensions/epidemiology/skills/skill-epi-research/SKILL.md` (line 33, →"Epidemiology extension is available"), `.claude/extensions/present/skills/skill-funds/SKILL.md` (line 36, →"Present extension is available"), `.claude/extensions/present/skills/skill-grant/SKILL.md` (line 34, →"Present extension is available"), `.claude/extensions/present/skills/skill-timeline/SKILL.md` (line 35, →"Present extension is available"). Source: `/home/benjamin/.config/zed/CHANGE.md` Theme 3.

---

### 410. Remove meta Stage 5.5 auto-research artifact generation
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Task Type**: meta
- **Research**: [01_remove-meta-stage-5-5.md](specs/410_remove_meta_stage_5_5/reports/01_remove-meta-stage-5-5.md)
- **Plan**: [01_remove-meta-stage-5-5.md](specs/410_remove_meta_stage_5_5/plans/01_remove-meta-stage-5-5.md)
- **Summary**: Removed Stage 5.5 from meta-builder-agent. Tasks created via /meta now start as NOT STARTED.

**Description**: Remove the "Interview Stage 5.5: GenerateResearchArtifacts" from the meta-builder-agent, which auto-generated shallow research boilerplate and set tasks to RESEARCHED status. Tasks should instead start as NOT STARTED and follow the normal `/research → /plan → /implement` lifecycle. Important: task descriptions created by meta-builder-agent must still include full file paths to key sources so that `/research` has clear starting points. Files: `.claude/agents/meta-builder-agent.md` (remove Stage 5.5 section at lines 594-691, update Stage 5→6 transition, change state.json template status to "not_started", remove artifacts array, update TODO.md template to [NOT STARTED]), `.claude/skills/skill-meta/SKILL.md` (change summary to "NOT STARTED status", remove research report objects, update next_steps to "/research"), `.claude/docs/reference/standards/multi-task-creation-standard.md` (remove "Research Generation" row and Stage 5.5 references). Source: `/home/benjamin/.config/zed/CHANGE.md` Theme 2.

---

### 409. Remove Phase Checkpoint Protocol from assembly/implement agents
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Task Type**: meta
- **Plan**: [01_remove-checkpoint-protocol.md](specs/409_remove_phase_checkpoint_protocol/plans/01_remove-checkpoint-protocol.md)
- **Summary**: [01_remove-checkpoint-protocol-summary.md](specs/409_remove_phase_checkpoint_protocol/summaries/01_remove-checkpoint-protocol-summary.md)

**Description**: Remove the overly complex Phase Checkpoint Protocol from 3 extension agents. This removes per-phase git commits, phase-to-stage mapping tables, and "before/after each phase" checklists. Phase status markers (`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`) in plan files are preserved -- they are a core system feature defined in `.claude/rules/artifact-formats.md` and updated by implementation agents during execution.

---

### 398. Extract artifact-linking logic to shared helper script (consolidate six skill Stage 8 blocks)
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: 397

**Description**: Follow-up to task 397. After task 397 duplicated the four-case TODO.md artifact-linking logic into `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (mirroring the blocks already in `skill-researcher`, `skill-planner`, `skill-implementer`), six skills now carry near-identical Stage 8 logic. Extract this into a shared helper (e.g., `.claude/scripts/link-artifact-todo.sh` or a reusable skill) so the count-aware insertion (inline for 1 artifact, multi-line list for 2+) lives in one place and future skills cannot drift. See task 397's research report (`specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`, section "Existing helper candidates") for the trade-off analysis between sed-based scripts and Edit-tool in-place logic, and the skill-boundary halt constraint documented in `skill-status-sync`. Blocked on 397 being [COMPLETED].

---

### 394. Remove language-to-task_type backward compatibility shim
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Remove the backward compatibility shim that treats old `language` field values as `task_type` when no `task_type` field is present. This shim was added during task 393 to prevent breakage of existing tasks. Remove it once all existing tasks across current projects have been completed and no legacy-format tasks remain in active state.

---

### 384. Improve /convert command-skill-agent pipeline in filetypes extension
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**: [01_convert-pipeline-analysis.md](specs/384_improve_convert_command_skill_agent/reports/01_convert-pipeline-analysis.md)

**Description**: Improve the /convert command-skill-agent according to best practices while conforming to current .claude/ patterns. The markitdown pipeline is currently broken (bad Python interpreter); pymupdf text extraction works and is the recommended extraction tool. Refactor the filetypes/ extension's convert pipeline to use pymupdf as the primary extraction backend, fix or replace the broken markitdown integration, and ensure the command-skill-agent architecture follows established .claude/ conventions.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
 **Effort**: TBD
 **Status**: [RESEARCHED]
 **Research Started**: 2026-02-13
 **Research Completed**: 2026-02-13
 **Task Type**: neovim
 **Dependencies**: None
 **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

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
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

## Recommended Order

1. **409** [NOT STARTED] -> research/implement (independent, small)
2. **410** [NOT STARTED] -> research/implement (independent, medium)
3. **411** [NOT STARTED] -> implement directly (5 trivial text replacements)
4. **412** [RESEARCHED] -> plan/implement (independent, medium)
5. **413** [NOT STARTED] -> research (needs Zed working copy comparison)
6. **384** [RESEARCHED] -> plan (independent)
7. **78** [PLANNED] -> implement
8. **87** [RESEARCHED] -> plan
9. **398** [NOT STARTED] -> research (depends: 397)
10. **394** [NOT STARTED] -> research
