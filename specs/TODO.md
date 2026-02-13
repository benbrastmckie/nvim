---
next_project_number: 91
---

# TODO

## Tasks

### 90. Ensure bidirectional syncing for labels and folders for himalaya and Protonmail
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: general
- **Dependencies**: Task #89

**Description**: Ensure bidirectional syncing for labels and folders for himalaya and the logos (protonmail) email account in an analogous manner to the himalaya and gmail account detailed in task 89.

### 89. Research Gmail label and folder synchronization with Himalaya
- **Effort**: 1 hour
- **Status**: [IMPLEMENTING]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Implementation Started**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](089_gmail_himalaya_folder_label_sync/reports/research-001.md)
- **Plan**: [implementation-002.md](089_gmail_himalaya_folder_label_sync/plans/implementation-002.md)

**Description**: Research how Gmail labels and folders sync with Himalaya email client. Investigate: (1) whether creating/deleting labels in Gmail browser automatically syncs to Himalaya locally, (2) whether Himalaya can create/delete folders and labels that sync back to Gmail, and (3) best practices for bidirectional folder/label management between Gmail web interface and Himalaya in Neovim.

### 88. Simplify himalaya threading keybindings
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Implementation Started**: 2026-02-13
- **Implementation Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](088_simplify_himalaya_threading_keybindings/reports/research-001.md)
- **Plan**: [implementation-001.md](088_simplify_himalaya_threading_keybindings/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260213.md](088_simplify_himalaya_threading_keybindings/summaries/implementation-summary-20260213.md)

**Description**: Change himalaya sidebar threading keybindings to use `<S-Tab>` (Shift-Tab) for toggling expand/collapse all threads. Remove individual thread fold keybindings (zo, zc, zR, zM, gT) from both the sidebar keymaps and the help menu, keeping only `<Tab>` for single thread toggle and `<S-Tab>` for all threads.

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

### 86. Fix himalaya sent folder display and add missing sidebar keybindings
- **Effort**: 2-3 hours
- **Status**: [COMPLETED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Implementation Started**: 2026-02-13
- **Implementation Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](086_fix_himalaya_sent_and_sidebar_keybindings/reports/research-001.md)
- **Plan**: [implementation-001.md](086_fix_himalaya_sent_and_sidebar_keybindings/plans/implementation-001.md)
- **Summary**: [implementation-summary-20260213.md](086_fix_himalaya_sent_and_sidebar_keybindings/summaries/implementation-summary-20260213.md)

**Description**: Fix sent emails (replies) not showing up in sent folder when using himalaya in neovim. Add useful commands (sync, etc.) that are not currently included as single-letter mappings in the himalaya sidebar to be accessible there in addition to under `<leader>m` in which-key. Update the help menu triggered with '?' in the sidebar to reflect all available keybindings.

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

### 72. Fix himalaya sidebar help showing leader keybindings that conflict with toggle selection
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Language**: neovim
- **Dependencies**: None

**Description**: Fix himalaya sidebar help display (shown via '?') incorrectly showing leader keybindings (`<leader>mA` - Switch account, `<leader>mf` - Change folder, `<leader>ms` - Sync folder) in the Folder Management section. These leader commands should not be accessible or defined in the sidebar since `<leader>` is `<Space>` which is used for toggle selections in that buffer.
