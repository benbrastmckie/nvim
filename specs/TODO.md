---
next_project_number: 419
---

# TODO

## Task Order

*Updated 2026-04-13. 5 active tasks remaining.*

### Pending

- **418** [COMPLETED] -- Add postflight self-execution fallback to skill wrapper pattern
- **398** [COMPLETED] -- Extract artifact-linking logic to shared helper script
- **394** [COMPLETED] -- Remove language-to-task_type backward compatibility shim
- **384** [COMPLETED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 418. Add postflight self-execution fallback to skill wrapper pattern
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_postflight-fallback.md](specs/418_add_postflight_fallback_to_skill_wrapper/reports/01_postflight-fallback.md)
- **Plan**: [01_postflight-fallback.md](specs/418_add_postflight_fallback_to_skill_wrapper/plans/01_postflight-fallback.md)

**Description**: Add postflight self-execution fallback to skill-implementer: when the skill executor does implementation work directly (without spawning a subagent via Task tool), it must still execute Stages 6-10 (read .return-meta.json, postflight status update, artifact linking, git commit, cleanup). The current pattern assumes Stage 5 always spawns a subagent, but agents frequently do the work inline, causing the entire postflight chain to break silently. Possible fixes: (1) add a Stage 5a check that detects inline execution and falls through to postflight, (2) restructure so postflight runs unconditionally after implementation regardless of delegation mode, or (3) add enforcement that prevents inline execution. This affects skill-researcher and skill-planner similarly if they have the same pattern.

---

### 398. Extract artifact-linking logic to shared helper script (consolidate six skill Stage 8 blocks)
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: 397
- **Research**: [01_artifact-linking-helper.md](specs/398_extract_artifact_linking_helper/reports/01_artifact-linking-helper.md)
- **Plan**: [01_artifact-linking-helper.md](specs/398_extract_artifact_linking_helper/plans/01_artifact-linking-helper.md)
- **Summary**: [01_artifact-linking-helper-summary.md](specs/398_extract_artifact_linking_helper/summaries/01_artifact-linking-helper-summary.md)

**Description**: Follow-up to task 397. After task 397 duplicated the four-case TODO.md artifact-linking logic into `skill-team-research`, `skill-team-plan`, and `skill-team-implement` (mirroring the blocks already in `skill-researcher`, `skill-planner`, `skill-implementer`), six skills now carry near-identical Stage 8 logic. Extract this into a shared helper (e.g., `.claude/scripts/link-artifact-todo.sh` or a reusable skill) so the count-aware insertion (inline for 1 artifact, multi-line list for 2+) lives in one place and future skills cannot drift. See task 397's research report (`specs/397_fix_team_skill_artifact_linking/reports/01_team-skill-artifact-linking.md`, section "Existing helper candidates") for the trade-off analysis between sed-based scripts and Edit-tool in-place logic, and the skill-boundary halt constraint documented in `skill-status-sync`. Blocked on 397 being [COMPLETED].

---

### 394. Remove language-to-task_type backward compatibility shim
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_remove-compat-shim.md](specs/394_remove_language_to_task_type_compat_shim/reports/01_remove-compat-shim.md)
- **Plan**: [01_remove-compat-shim.md](specs/394_remove_language_to_task_type_compat_shim/plans/01_remove-compat-shim.md)
- **Summary**: [01_remove-compat-shim-summary.md](specs/394_remove_language_to_task_type_compat_shim/summaries/01_remove-compat-shim-summary.md)

**Description**: Remove the backward compatibility shim that treats old `language` field values as `task_type` when no `task_type` field is present. This shim was added during task 393 to prevent breakage of existing tasks. Remove it once all existing tasks across current projects have been completed and no legacy-format tasks remain in active state.

---

### 384. Improve /convert command-skill-agent pipeline in filetypes extension
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**:
  - [01_convert-pipeline-analysis.md](specs/384_improve_convert_command_skill_agent/reports/01_convert-pipeline-analysis.md)
  - [02_convert-status-review.md](specs/384_improve_convert_command_skill_agent/reports/02_convert-status-review.md)
  - [03_pymupdf-vs-markitdown.md](specs/384_improve_convert_command_skill_agent/reports/03_pymupdf-vs-markitdown.md)
- **Plan**: [02_convert-pipeline-refactor.md](specs/384_improve_convert_command_skill_agent/plans/02_convert-pipeline-refactor.md)
- **Summary**: [02_convert-pipeline-summary.md](specs/384_improve_convert_command_skill_agent/summaries/02_convert-pipeline-summary.md)

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
2. **78** [PLANNED] -> implement
3. **87** [RESEARCHED] -> plan
4. **398** [NOT STARTED] -> research (depends: 397)
5. **394** [NOT STARTED] -> research
6. **418** [RESEARCHING] -> complete research
