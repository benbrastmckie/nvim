---
next_project_number: 427
---

# TODO

## Task Order

*Updated 2026-04-13. 8 active tasks remaining.*

### Pending

- **426** [NOT STARTED] -- Update slides command and manifest for --critic flag (depends: 425)
- **425** [NOT STARTED] -- Create skill-slide-critic interactive critique skill (depends: 424)
- **424** [NOT STARTED] -- Create slide-critic-agent (depends: 423)
- **423** [IMPLEMENTING] -- Create critique rubric context file
- **422** [RESEARCHED] -- Fix sync.lua overwriting all non-CLAUDE.md files
- **421** [COMPLETED] -- Fix status script grep pattern and TODO artifact linking
- **420** [COMPLETED] -- Prevent extension loader overwriting repo customizations
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 426. Update slides command and manifest for --critic flag
- **Effort**: medium
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: 425

**Description**: Add `--critic` flag parsing to the `/slides` command (`slides.md`). Accept `--critic /path/to/file`, `--critic N` (task number), or `--critic "prompt"` as input. Route to `skill-slide-critic`. Update `manifest.json` with critic routing entry. Update `index-entries.json` with context entries for the critic agent and rubric. Update EXTENSION.md documentation.

### 425. Create skill-slide-critic interactive critique skill
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: 424

**Description**: Create `skill-slide-critic` in the present extension. This skill runs an interactive critique loop: (1) delegates to `slide-critic-agent` for initial material review, (2) presents identified issues to user via AskUserQuestion grouped by category, (3) for each issue the user can accept, reject, modify, or provide an alternative response, (4) loops until all issues are addressed or dismissed, (5) produces a final critique report at `specs/{NNN}_{SLUG}/reports/{MM}_slide-critique.md` that can be consumed by `/plan` to guide slide design. Implements skill-internal postflight pattern.

### 424. Create slide-critic-agent
- **Effort**: large
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Dependencies**: 423

**Description**: Create `slide-critic-agent` in the present extension. This agent loads the critique rubric context and reviews all provided materials (source files, research reports, plans, existing slides). It evaluates against rubric criteria: narrative flow, audience alignment, timing balance, content depth, evidence quality, visual design considerations. Produces a structured issue list with severity (critical/high/medium/low), category, description, location in materials, and suggested improvement. Writes `.return-meta.json` with critique artifacts.

### 423. Create critique rubric context file
- **Effort**: medium
- **Status**: [IMPLEMENTING]
- **Task Type**: meta

- **Research**: [01_critique-rubric-research.md](423_create_critique_rubric_context/reports/01_critique-rubric-research.md)
- **Plan**: [01_critique-rubric-plan.md](423_create_critique_rubric_context/plans/01_critique-rubric-plan.md)
**Description**: Create a critique rubric context file at `.claude/extensions/present/context/project/present/talk/critique-rubric.md`. Define review criteria and scoring patterns for slide presentations across categories: narrative flow (logical progression, story arc, transitions), audience alignment (jargon level, assumed knowledge, engagement), timing balance (slides per section, pacing), content depth (too shallow vs too detailed), evidence quality (data presentation, citations, claims), and visual design considerations (text density, figure placement). Include talk-type-specific criteria for conference, seminar, defense, poster, and journal club presentations.

### 422. Fix sync.lua overwriting all non-CLAUDE.md files in target repos
- **Effort**: large
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Research**: [01_sync-overwrite-diagnosis.md](422_fix_sync_overwriting_all_non_claudemd_files/reports/01_sync-overwrite-diagnosis.md)

**Description**: Follow-up to task 420 (prevent extension loader overwriting repo customizations). Task 420 added section-aware sync for CLAUDE.md and post-sync re-injection of merge targets, but the fix is insufficient -- the zed config (`~/.config/zed/.claude/`) is still getting clobbered on every sync. This has now caused three wasted tasks in zed: task 60 (incorrectly "fixed" the diffs thinking they were stale references), task 61 (reverted task 60), and task 62 (initially misdiagnosed the same diffs again).

**Root cause analysis from the zed codebase:**

The `sync_files()` function in `sync.lua` (line ~246) only applies section preservation to files in `CONFIG_MARKDOWN_FILES` (CLAUDE.md and OPENCODE.md). The `execute_sync()` function (lines ~284-296) syncs ALL other .claude/ files with `action = "replace"`, which does a full overwrite. This means every file synced from nvim to zed gets its local content destroyed.

**Specific files being clobbered in the zed repo (evidence from `git diff .claude/`):**

1. `.claude/CLAUDE.md` -- Content NOT inside `<!-- SECTION -->` markers is lost: the Hooks section (validate-plan-write.sh), slide-planner-agent/skill-slide-planning table rows (3 tables), and `present:slides` compound task type routing. Task 420's section-marker fix does not protect content that the extension system didn't inject via markers.

2. `.claude/agents/README.md` -- Full overwrite removes slide-planner-agent row and the "Extension-specific agents" note. Not in `CONFIG_MARKDOWN_FILES`, so no protection at all.

3. `.claude/rules/git-workflow.md` -- Full overwrite removes the zed-specific "omit Co-Authored-By" user preference note and replaces it with nvim's Co-Authored-By trailer format. Not in `CONFIG_MARKDOWN_FILES`.

4. `.claude/agents/document-agent.md` -- Full overwrite replaces zed's pymupdf-as-primary version with nvim's markitdown-as-primary version. (The pymupdf improvement was done in zed but reverted as collateral damage when reverting task 60.)

5. `.claude/context/project/filetypes/` (3 files: conversion-tables.md, dependency-guide.md, tool-detection.md) -- Full overwrite replaces zed's pymupdf-aware versions with nvim's markitdown-only versions.

6. 7 skill files (skill-researcher, skill-planner, skill-implementer, skill-reviser, skill-team-research, skill-team-plan, skill-team-implement) -- Full overwrite replaces each skill's artifact-linking postflight. The nvim versions reference `link-artifact-todo.sh` script; the zed committed versions use inline Edit-based four-case logic.

7. `.claude/scripts/update-task-status.sh` -- Full overwrite replaces the committed version with nvim's version (which has a tolerant status regex).

8. `.claude/context/index.json` and `.claude/extensions.json` -- Re-injection is idempotent but the full overwrite first replaces the file, causing key reordering churn.

**Three categories of failure:**

| Category | Files affected | Why task 420 doesn't help |
|----------|---------------|---------------------------|
| Non-CLAUDE.md files | agents/README.md, rules/git-workflow.md, all skill files, context files, scripts | `CONFIG_MARKDOWN_FILES` only contains CLAUDE.md and OPENCODE.md; all other files get full overwrite |
| CLAUDE.md content outside section markers | Hooks section, slide-planner table rows, present:slides routing | Section preservation only protects `<!-- SECTION -->` blocks; manually-added content in CLAUDE.md is unprotected |
| Bidirectional improvements | document-agent.md (pymupdf), skill artifact-linking (script vs inline) | Sync is unidirectional (nvim -> target); improvements made in target repos are overwritten |

**Requirements for a proper fix:**

The sync system needs to handle the fact that target repos (zed, other projects) may have legitimate local customizations to ANY .claude/ file, not just CLAUDE.md sections. Possible approaches include: (a) expanding section-marker protection to all synced files, (b) adding a per-repo "protected files" list that sync skips, (c) making sync diff-aware rather than full-overwrite, or (d) only syncing files whose local content matches the previous sync snapshot (detecting local modifications and skipping those files).

### 421. Fix update-task-status.sh grep pattern and skill-planner TODO.md artifact linking
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [01_status-script-bugs.md](421_fix_status_script_grep_pattern_and_todo_linking/reports/01_status-script-bugs.md)
- **Plan**: [01_fix-status-linking.md](421_fix_status_script_grep_pattern_and_todo_linking/plans/01_fix-status-linking.md)
- **Summary**: [01_fix-status-linking-summary.md](421_fix_status_script_grep_pattern_and_todo_linking/summaries/01_fix-status-linking-summary.md)

**Description**: Fix update-task-status.sh grep pattern that fails to match TODO.md task entry status lines: script uses `^- \*\*Status\*\*:` but actual format is ` **Status**:` (space-indented, no dash). This causes all task entry status updates to silently fail, while Task Order and state.json updates succeed. Also fix skill-planner postflight to actually perform TODO.md artifact linking (Plan field) which was specified but never executed.

---

### 420. Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
- **Effort**: TBD
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [01_extension-loader-sync.md](420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md)
- **Plan**: [01_prevent-loader-overwrite.md](420_prevent_extension_loader_overwriting_repo_customizations/plans/01_prevent-loader-overwrite.md)
- **Summary**: [01_prevent-loader-overwrite-summary.md](420_prevent_extension_loader_overwriting_repo_customizations/summaries/01_prevent-loader-overwrite-summary.md)

**Description**: Investigation and fix for a systemic issue: when the `<leader>ac` extension loader syncs .claude/ files from the nvim config into other repos (like zed), it overwrites repo-specific additions to CLAUDE.md documentation tables. This caused slide-planner-agent and skill-slide-planning (added by task 56 in zed) to be silently removed from CLAUDE.md when the next sync occurred. Root cause analysis needed: (1) Identify how the extension loader syncs CLAUDE.md content between repos, (2) Determine why repo-specific additions are not preserved during sync, (3) Investigate whether extensions.json or manifest.json should declare documentation table entries that get merged rather than overwritten, (4) Check if other repos have similar repo-specific CLAUDE.md customizations at risk. Design and implement a fix: consider merge-based documentation table updates, repo-local sections in CLAUDE.md, extension manifest declarations for table entries, and validation that warns when a sync would remove entries added by tasks in the target repo.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Task Type**: neovim
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
- **Task Type**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---

## Recommended Order

1. **78** [PLANNED] -> implement
2. **87** [RESEARCHED] -> plan
3. **422** -> research (independent)
