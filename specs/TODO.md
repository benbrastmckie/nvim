---
next_project_number: 421
---

# TODO

## Task Order

*Updated 2026-04-13. 3 active tasks remaining.*

### Pending

- **420** [PLANNED] -- Prevent extension loader overwriting repo customizations
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 420. Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
 **Effort**: TBD
 **Status**: [RESEARCHED]
 **Task Type**: meta
 **Dependencies**: None
 **Research**: [01_extension-loader-sync.md](420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md)

**Description**: Investigation and fix for a systemic issue: when the `<leader>ac` extension loader syncs .claude/ files from the nvim config into other repos (like zed), it overwrites repo-specific additions to CLAUDE.md documentation tables. This caused slide-planner-agent and skill-slide-planning (added by task 56 in zed) to be silently removed from CLAUDE.md when the next sync occurred. Root cause analysis needed: (1) Identify how the extension loader syncs CLAUDE.md content between repos, (2) Determine why repo-specific additions are not preserved during sync, (3) Investigate whether extensions.json or manifest.json should declare documentation table entries that get merged rather than overwritten, (4) Check if other repos have similar repo-specific CLAUDE.md customizations at risk. Design and implement a fix: consider merge-based documentation table updates, repo-local sections in CLAUDE.md, extension manifest declarations for table entries, and validation that warns when a sync would remove entries added by tasks in the target repo.

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

1. **78** [PLANNED] -> implement
3. **87** [RESEARCHED] -> plan
