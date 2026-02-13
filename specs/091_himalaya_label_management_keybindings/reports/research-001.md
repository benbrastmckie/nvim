# Research Report: Himalaya Label Management Keybindings

- **Task**: 91 - himalaya_label_management_keybindings
- **Started**: 2026-02-13T00:00:00Z
- **Completed**: 2026-02-13T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: Task 86 (sync/account keybindings), Task 88 (threading keybindings)
- **Sources/Inputs**:
  - Himalaya CLI help output (`himalaya --help`, `himalaya flag --help`, `himalaya folder --help`)
  - Local configuration: `lua/neotex/plugins/tools/himalaya/`
  - Existing keybindings: `config/ui.lua`
  - State management: `core/state.lua`
  - Email operations: `utils.lua`, `ui/main.lua`
- **Artifacts**: This report
- **Standards**: report-format.md, artifact-formats.md

## Project Context

- **Upstream Dependencies**: `himalaya/config/ui.lua` (keybindings), `himalaya/core/state.lua` (selection), `himalaya/utils/cli.lua` (CLI execution)
- **Downstream Dependents**: None (new feature)
- **Alternative Paths**: Could use which-key `<leader>m` menu instead of direct keybindings
- **Potential Extensions**: Bulk label operations via visual selection

## Executive Summary

- Himalaya CLI supports folder management (`folder add/delete/list/purge`) but **not direct "label" management** - Gmail-style labels are implemented as folders
- Himalaya supports **flag management** (`flag add/set/remove`) for standard flags (seen, answered, flagged, deleted, draft) plus custom flags
- The existing Neovim integration has comprehensive selection patterns (`state.get_selected_emails()`, `toggle_selection()`) that can be reused
- For "apply label to email", use `flag add <email_id> <flag_name>` - supports multiple email IDs in one command
- Folder/label CRUD requires `himalaya folder add/delete` - **no rename command exists**
- Recommended keybindings: `l` for label/flag operations (selection-aware), `gl` prefix for folder/label management

## Context & Scope

The task requests three features:
1. Create/edit/delete labels (where editing changes all emails with that label)
2. Apply label to email under cursor (single email)
3. Apply label to selected emails (visual/selection mode)

**Key Insight**: Himalaya treats "labels" as either:
- **Folders** (Gmail labels map to folders in IMAP)
- **Flags** (standard: seen, answered, flagged, deleted, draft; custom flags also supported)

## Findings

### 1. Himalaya CLI Commands

#### Flag Commands (for labeling emails)
```bash
# Add flag(s) to envelope(s)
himalaya flag add <ID-OR-FLAG>... [-f FOLDER] [-a ACCOUNT]
# Every arg parsable as integer = ID, otherwise = flag name

# Replace all flags on envelope
himalaya flag set <ID-OR-FLAG>... [-f FOLDER] [-a ACCOUNT]

# Remove flag(s) from envelope(s)
himalaya flag remove <ID-OR-FLAG>... [-f FOLDER] [-a ACCOUNT]
```

**Examples**:
```bash
# Add "important" flag to email 123
himalaya flag add 123 important -a gmail -f INBOX

# Add "review" flag to multiple emails
himalaya flag add 123 456 789 review -a gmail -f INBOX

# Remove "flagged" from email 123
himalaya flag remove 123 flagged -a gmail -f INBOX
```

#### Folder Commands (for label management)
```bash
# Create folder/label
himalaya folder add <FOLDER> [-a ACCOUNT]

# List folders
himalaya folder list [-a ACCOUNT]

# Delete folder
himalaya folder delete <FOLDER> [-a ACCOUNT]

# Purge folder (delete all messages)
himalaya folder purge <FOLDER> [-a ACCOUNT]

# Expunge folder (remove deleted messages)
himalaya folder expunge <FOLDER> [-a ACCOUNT]
```

**Note**: No `folder rename` command exists. To "edit" a label name, must create new, move messages, delete old.

### 2. Existing Neovim Integration Patterns

#### Selection System (`core/state.lua`)
```lua
-- Already implemented:
state.toggle_email_selection(email_id, email_data)
state.get_selected_emails()  -- Returns array of selected emails
state.is_email_selected(email_id)
state.clear_selection()
state.get_selection_count()
```

#### Selection-Aware Operations (`ui/main.lua`)
The codebase uses a consistent pattern for selection-aware operations:
```lua
-- Example from move operation:
if #state.get_selected_emails() > 0 then
  main.move_selected_emails()
else
  main.move_current_email()
end
```

#### CLI Execution (`utils/cli.lua`)
```lua
-- Execute himalaya command
cli_utils.execute_himalaya(args, opts)
-- Args: table of command arguments
-- Opts: { account = 'gmail', folder = 'INBOX', show_loading = true }
```

#### Existing manage_tag function (`utils.lua:751-772`)
```lua
function M.manage_tag(email_id, tag, action)
  local args = { 'flag', action, tag, email_id }
  local result = cli_utils.execute_himalaya(args, {
    account = account,
    folder = folder
  })
  if result then
    M.clear_email_cache(account, folder)
  end
  return result ~= nil
end
```

### 3. Keybinding Slot Analysis (`config/ui.lua`)

Current bindings in email list (himalaya-list filetype):
- **Used**: q, Space, n, p, j, k, C-d, C-u, F, d, a, r, R, f, m, c, e, /, Tab, S-Tab, s, S, A, i, ?, gH, CR, Esc
- **Available for labels**: `l`, `L`, `g` prefix combinations, `t` (tag), `b` (bound/label)

**Recommended**: Use `l` for label/flag operations (mnemonic: Label)
- `l` - Apply label/flag to current or selected emails (picker)
- `gl` - Label management submenu (create/delete)

### 4. Implementation Architecture

#### A. Apply Label to Email(s)

```lua
-- In ui/main.lua or new labels.lua module
function M.label_current_email()
  local email_id = M.get_current_email_id()
  if not email_id then
    notify.himalaya('No email selected', notify.categories.STATUS)
    return
  end
  M.show_label_picker({ email_id })
end

function M.label_selected_emails()
  local selected = state.get_selected_emails()
  if #selected == 0 then
    notify.himalaya('No emails selected', notify.categories.STATUS)
    return
  end
  local ids = vim.tbl_map(function(e) return e.id end, selected)
  M.show_label_picker(ids)
end

function M.show_label_picker(email_ids)
  -- Get available flags/labels
  -- Show vim.ui.select picker
  -- Call himalaya flag add <ids...> <flag>
end
```

#### B. Folder/Label Management

```lua
function M.create_label()
  vim.ui.input({ prompt = 'New label name: ' }, function(name)
    if name and name ~= '' then
      local args = { 'folder', 'add', name }
      cli_utils.execute_himalaya(args, { account = account })
      notify.himalaya('Label created: ' .. name, notify.categories.SUCCESS)
    end
  end)
end

function M.delete_label()
  local folders = utils.get_folders(account)
  vim.ui.select(folders, {
    prompt = 'Delete label:',
    format_item = function(f) return f.name end
  }, function(choice)
    if choice then
      -- Confirm deletion
      vim.ui.select({'Yes', 'No'}, {
        prompt = 'Delete label "' .. choice.name .. '"? All emails will be moved.'
      }, function(confirm)
        if confirm == 'Yes' then
          local args = { 'folder', 'delete', choice.name }
          cli_utils.execute_himalaya(args, { account = account })
        end
      end)
    end
  end)
end
```

### 5. Standard Flags vs Custom Flags

Himalaya recognizes these standard flags:
- `seen` - Email has been read
- `answered` - Email has been replied to
- `flagged` - Email is starred/flagged
- `deleted` - Email is marked for deletion
- `draft` - Email is a draft

Custom flags (may not be supported by all backends):
- Any other string passed to `flag add`
- Gmail supports labels which can be treated as custom flags
- IMAP support varies by server

## Decisions

1. **Use `l` keybinding** for label/flag operations (matches Gmail's 'l' for labels)
2. **Selection-aware by default** - `l` operates on selection if any, otherwise current email
3. **Separate management commands** - Use `gl` prefix for create/delete operations
4. **No "edit" operation** - Himalaya lacks folder rename; document as limitation
5. **Focus on flags first** - Standard flags are universally supported; custom flags may vary

## Recommendations

### Priority 1: Implement Label Application (Core Feature)

1. Add `l` keybinding in `config/ui.lua` for email list
2. Create `show_flag_picker()` function in new `features/labels.lua` module
3. Use selection-aware pattern (selected emails if any, else current)
4. Show picker with common flags + option to enter custom

### Priority 2: Implement Visual Mode Support

1. Add visual mode `l` mapping in `config/ui.lua`
2. Get selected line range, extract email IDs from line_map
3. Call same `show_flag_picker()` with collected IDs

### Priority 3: Add Folder/Label Management

1. Add `glc` (create), `gld` (delete) keybindings
2. Implement `create_label()` and `delete_label()` functions
3. Add `:HimalayaLabelCreate` and `:HimalayaLabelDelete` commands

### Priority 4: Flag Display Enhancement

1. Show current flags in email list display
2. Highlight flagged/starred emails
3. Add flag column or indicator

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Custom flags not supported by backend | Medium | Medium | Document limitation, focus on standard flags first |
| Folder delete loses emails | Low | High | Require confirmation, warn about data loss |
| Flag operations slow for many emails | Low | Low | Show progress notification for bulk operations |
| Visual mode selection conflict | Low | Medium | Use custom selection (Space/n/p) as primary, visual as secondary |

## Appendix

### References
- [Himalaya CLI](https://github.com/pimalaya/himalaya) - Official repository
- Himalaya v1.1.0 command structure (verified via `himalaya --help`)

### Existing Similar Patterns in Codebase
- `move_selected_emails()` - Selection-aware move to folder
- `delete_selected_emails()` - Selection-aware deletion
- `archive_selected_emails()` - Selection-aware archive
- `spam_selected_emails()` - Selection-aware spam marking

### Suggested File Structure
```
lua/neotex/plugins/tools/himalaya/
  features/
    labels.lua          # New: Label/flag management functions
  config/
    ui.lua              # Update: Add l, gl keybindings
  commands/
    email.lua           # Update: Add HimalayaLabel* commands
```

### Sample Keybinding Configuration

```lua
-- In config/ui.lua setup_email_list_keymaps()

-- Label/flag operations (selection-aware)
keymap('n', 'l', function()
  local ok, main = pcall(require, 'neotex.plugins.tools.himalaya.ui.main')
  if ok then
    local state = require('neotex.plugins.tools.himalaya.core.state')
    if #state.get_selected_emails() > 0 then
      main.label_selected_emails()
    else
      main.label_current_email()
    end
  end
end, vim.tbl_extend('force', opts, { desc = 'Apply label/flag' }))

-- Label management
keymap('n', 'glc', function()
  local ok, labels = pcall(require, 'neotex.plugins.tools.himalaya.features.labels')
  if ok and labels.create_label then
    labels.create_label()
  end
end, vim.tbl_extend('force', opts, { desc = 'Create label' }))

keymap('n', 'gld', function()
  local ok, labels = pcall(require, 'neotex.plugins.tools.himalaya.features.labels')
  if ok and labels.delete_label then
    labels.delete_label()
  end
end, vim.tbl_extend('force', opts, { desc = 'Delete label' }))
```
