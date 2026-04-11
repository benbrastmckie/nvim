---
next_project_number: 403
---

# TODO

## Task Order

*Updated 2026-04-11. 5 active tasks remaining.*

### Pending

- **384** [RESEARCHED] -- Improve /convert command-skill-agent pipeline in filetypes extension
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 402. Add routing blocks to 11 extension manifests (doc-lint failures)
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Priority**: high
- **Review**: [review-2026-04-10.md](reviews/review-2026-04-10.md)
- **Research**: [01_extension-manifest-routing.md](402_add_routing_blocks_to_extension_manifests/reports/01_extension-manifest-routing.md)
- **Plan**: [01_add-routing-blocks.md](402_add_routing_blocks_to_extension_manifests/plans/01_add-routing-blocks.md)
- **Summary**: [01_add-routing-blocks-summary.md](402_add_routing_blocks_to_extension_manifests/summaries/01_add-routing-blocks-summary.md)

**Description**: `.claude/scripts/check-extension-docs.sh` reports 11 extensions whose `manifest.json` declares skills but has no `routing` block mapping task types to those skills: filetypes (5 skills), formal (4), latex (2), lean (4), memory (1), nix (2), nvim (2), python (2), typst (2), web (3), z3 (2). Without routing entries, when these extensions are loaded via `<leader>ac`, `/research`, `/plan`, and `/implement` fall back to default skills instead of dispatching to the extension's domain skills. Add `routing.research`, `routing.plan`, `routing.implement` blocks to each manifest following the pattern established by `present/manifest.json` and `founder/manifest.json`. Verify with `.claude/scripts/check-extension-docs.sh` exiting 0. This clears the way for the roadmap item "CI enforcement of doc-lint".

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

1. **384** [RESEARCHED] -> plan (independent)
*No pending implementation tasks.*
