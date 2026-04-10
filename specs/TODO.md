---
next_project_number: 401
---

# TODO

## Task Order

*Updated 2026-04-10. 4 active tasks remaining.*

### Pending

- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 400. Overhaul epidemiology extension: /epi command, epi:study routing, and infrastructure completion
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**: [01_team-research.md](400_epi_extension_overhaul/reports/01_team-research.md)

**Description**: Research the `.claude/extensions/epidemiology/` extension and compare it to other extensions such as `founder/` and `present/` to identify improvements and missing infrastructure. Revise `task_type` routing to use the `{extension}:{type}` compound form with `epi` as the extension prefix (e.g., `epi:study`). Add a new `/epi` command that accepts a path, prompt, or task number and asks interactive questions to scope an epidemiology study in R, producing an `epi:study` task. The interactive questions should collect all paths to relevant directories, data files, descriptions, or other supporting content. After `/epi` creates the task, running `/research` and `/plan` on it should analyze all materials to produce a clear study design and development plan, and `/implement` should execute that plan, review results, and generate a final report of findings. Systematically review the current contents of `epidemiology/` (commands, skills, agents, context, manifest, rules, routing) against `founder/` and `present/` to enumerate what already exists, what is missing, and what should be improved to complete the command-skill-agent infrastructure.

---

### 399. Consolidate slides.md command into convert.md or talk.md and rename talk.md to slides.md
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_consolidate-slides-commands.md](399_consolidate_slides_commands/reports/01_consolidate-slides-commands.md)
- **Plan**: [01_consolidate-slides-commands.md](399_consolidate_slides_commands/plans/01_consolidate-slides-commands.md)
- **Summary**: [01_consolidate-slides-commands-summary.md](399_consolidate_slides_commands/summaries/01_consolidate-slides-commands-summary.md)

**Description**: Fold `.claude/extensions/filetypes/commands/slides.md` into either `.claude/extensions/filetypes/commands/convert.md` or `.claude/extensions/present/commands/talk.md`, whichever is most appropriate. Then rename `.claude/extensions/present/commands/talk.md` to `.claude/extensions/present/commands/slides.md`. The research/planning phase should evaluate which target command is the better semantic fit for the folded content, update any cross-references and registrations affected by the rename, and ensure no broken links remain in docs, manifests, or other commands.

---

### 398. Extract artifact-linking logic to shared helper script (consolidate six skill Stage 8 blocks)
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: 397

**Description**: Follow-up to task 397. After task 397 duplicated the four-case TODO.md artifact-linking logic into `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (mirroring the blocks already in `skill-researcher`, `skill-planner`, `skill-implementer`), six skills now carry near-identical Stage 8 logic. Extract this into a shared helper (e.g., `.claude/scripts/link-artifact-todo.sh` or a reusable skill) so the count-aware insertion (inline for 1 artifact, multi-line list for 2+) lives in one place and future skills cannot drift. See task 397's research report (`specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`, section "Existing helper candidates") for the trade-off analysis between sed-based scripts and Edit-tool in-place logic, and the skill-boundary halt constraint documented in `skill-status-sync`. Blocked on 397 being [COMPLETED].

---

### 397. Fix team-mode skills missing TODO.md artifact linking
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_team-skill-artifact-linking.md](397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md)
- **Plan**: [01_fix-team-skill-artifact-linking.md](397_fix_team_skill_artifact_linking/plans/01_fix-team-skill-artifact-linking.md)
- **Summary**: [01_fix-team-skill-artifact-linking-summary.md](397_fix_team_skill_artifact_linking/summaries/01_fix-team-skill-artifact-linking-summary.md)

**Description**: The three team-mode skills (`skill-team-research`, `skill-team-plan`, `skill-team-implement`) lack the TODO.md artifact-linking step that their single-agent counterparts (`skill-researcher`, `skill-planner`, `skill-implementer`) perform in their postflight. After a `--team` run, `state.json` correctly contains the artifact entry under `active_projects[].artifacts[]`, but TODO.md does not receive the inline `- **Research/Plan/Summary**: [file](path)` entry specified by `.claude/rules/artifact-formats.md` and `.claude/rules/state-management.md`. This causes silent TODO.md drift for every team-mode invocation. First observed on task 396 after `/research --team 396`. Fix by adding a TODO.md artifact-linking stage to all three team skills (mirroring `skill-researcher` line 292, `skill-planner`, `skill-implementer`), ensuring the count-aware format is used (inline for 1 artifact, multi-line list for 2+). Additionally, investigate whether this should be extracted into a shared postflight helper (e.g., `skill-status-sync` or a utility) so future skills cannot drift from the standard. Verify the fix by re-running `/research --team` on a test task and confirming both state.json and TODO.md are updated.

---

### 396. Review .claude/ architecture and update all relevant documentation
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Artifacts**:
  - **Research**: [01_team-research.md](396_review_claude_architecture_docs/reports/01_team-research.md)
  - **Plan**: [01_docs-audit-fixes.md](396_review_claude_architecture_docs/plans/01_docs-audit-fixes.md)
  - **Summary**: [01_docs-audit-summary.md](396_review_claude_architecture_docs/summaries/01_docs-audit-summary.md)

**Description**: Systematically review the current architecture for the .claude/ agent system, including the core agent system and the extensions loaded by the <leader>ac picker, in order to update all relevant documentation. Use /home/benjamin/.config/nvim/.claude/extensions/present/README.md as a reference model. Create /home/benjamin/.config/nvim/.claude/extensions/filetypes/README.md (which does not exist), and update any other places where documentation is missing or out of date.

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

1. **384** [RESEARCHED] -> plan (independent)
*No pending implementation tasks.*
