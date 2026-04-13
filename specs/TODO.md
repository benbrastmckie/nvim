---
next_project_number: 417
---

# TODO

## Task Order

*Updated 2026-04-13. 8 active tasks remaining.*

### Pending

- **416** [NOT STARTED] -- Enforce skill delegation for plan artifacts
- **415** [COMPLETED] -- Improve /slides command task description format (Sources, forcing data, richer text)
- **414** [COMPLETED] -- Remove Phase Checkpoint Protocol from 10 extension agents
- **398** [NOT STARTED] -- Extract artifact-linking logic to shared helper script
- **394** [NOT STARTED] -- Remove language-to-task_type backward compatibility shim
- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 416. Enforce skill delegation for plan artifacts
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: The `/plan` command sometimes bypasses `skill-planner` delegation and writes plan files directly, producing artifacts that violate the plan format standard (`plan-format.md`, `plan-format-enforcement.md`). This happened on 2026-04-13 with task 414: the orchestrator read the /plan command spec, skipped the `Skill("skill-planner")` invocation, and wrote a plan missing required metadata (Status, Dependencies, Research Inputs, Artifacts, Standards, Type), required sections (Goals & Non-Goals, Testing & Validation, Artifacts & Outputs, Rollback/Contingency), the Dependency Analysis wave table, and proper phase format (Goal/Tasks/Timing/Depends on). The `plan-format-enforcement.md` rule exists but only influences agents that load it — it cannot prevent the orchestrator from writing non-conforming files directly. The same class of bypass could affect `/research` (skipping `skill-researcher`) or `/implement` (skipping `skill-implementer`). Investigate enforcement mechanisms: (1) settings.json hooks (PostToolUse on Write/Edit matching `specs/**/plans/*.md`) that validate format externally, (2) stronger anti-bypass wording in command specs, (3) feedback memory for future conversations. Determine which combination provides reliable enforcement without excessive overhead.

---

### 415. Improve /slides command task description format (Sources, forcing data, richer text)
- **Effort**: 30 min
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_slides-description-analysis.md](specs/415_improve_slides_command_task_description/reports/01_slides-description-analysis.md)
- **Plan**: [01_slides-description-plan.md](specs/415_improve_slides_command_task_description/plans/01_slides-description-plan.md)
- **Summary**: [01_slides-description-summary.md](specs/415_improve_slides_command_task_description/summaries/01_slides-description-summary.md)

**Description**: The `/slides` command in `present/` extension creates terse, poorly structured TODO.md task entries. Three specific improvements needed in `.claude/extensions/present/commands/slides.md`:

1. **Add Sources section**: Add a `**Sources**:` section to the TODO.md entry (Step 4) with full absolute paths to all source files. Currently source paths are relativized and buried in the single-line description.

2. **Add Forcing Data Gathered section**: Add a structured `**Forcing Data Gathered**:` section to the TODO.md entry showing all forcing question answers (output_format, talk_type, source_materials, audience_context). Model after `/deck` command (lines 239-254 of `founder/commands/deck.md`).

3. **Richer description**: Remove the ~20 word truncation on audience_context in Step 2.5. Use the full audience context. Improve the enriched description to be multi-line rather than a single compressed sentence.

**Reference**: `/deck` command at `.claude/extensions/founder/commands/deck.md` lines 239-254 for the TODO.md entry format to emulate.

### 414. Remove Phase Checkpoint Protocol from 10 extension agents
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Completed**: 2026-04-13
- **Summary**: Removed Phase Checkpoint Protocol from 10 extension agents (~280 lines). Restructured grant-agent Stage 6/7.
- **Task Type**: meta
- **Research**: [01_checkpoint-protocol-audit.md](specs/414_remove_phase_checkpoint_protocol/reports/01_checkpoint-protocol-audit.md)
- **Plan**: [01_checkpoint-removal-plan.md](specs/414_remove_phase_checkpoint_protocol/plans/01_checkpoint-removal-plan.md)

**Description**: Remove the "Phase Checkpoint Protocol" sections from 10 extension implementation agents that still contain them. This protocol documented per-phase `[IN PROGRESS]`/`[COMPLETED]` status tracking in plan headings, per-phase git commits, and phase-to-stage mapping tables. It was already removed from epi-implement-agent, pptx-assembly-agent, and slidev-assembly-agent as unnecessary overhead. The same removal should be applied to: latex-implementation-agent, typst-implementation-agent, python-implementation-agent, nix-implementation-agent, neovim-implementation-agent, web-implementation-agent, z3-implementation-agent, founder-implement-agent, deck-builder-agent, and grant-agent. Also remove inline references to the protocol (preamble notes, per-phase commit instructions, numbered rules at the end). Origin: PORT.md cross-reference audit.

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

1. **414** [NOT STARTED] -> research (independent, small)
2. **384** [RESEARCHED] -> plan (independent)
3. **78** [PLANNED] -> implement
4. **87** [RESEARCHED] -> plan
5. **398** [NOT STARTED] -> research (depends: 397)
6. **394** [NOT STARTED] -> research
