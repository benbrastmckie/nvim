# Implementation Plan: Task #124

- **Task**: 124 - limit_docs_section_in_pickers
- **Status**: [NOT STARTED]
- **Effort**: 0.5-1 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false
- **Date**: 2026-03-03
- **Feature**: Limit [Docs] picker section to show only docs/README.md
- **Estimated Hours**: 0.5-1 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

Modify `create_docs_entries()` in `entries.lua` to show only the `docs/README.md` file instead of scanning for all `*.md` files. This affects both the Claude picker (`<leader>ac`) and OpenCode picker (`<leader>ao`) since they share the same entry-creation code, differentiated only by `config.base_dir`. The `scan_directory` function is not modified because its README exclusion behavior is correct for all other artifact types (commands, skills, agents, etc.).

### Research Integration

Research report (research-001.md) identified that `create_docs_entries()` currently uses `scan.scan_directory()` which explicitly excludes README.md files -- the exact opposite of the desired behavior. Option A (direct modification of `create_docs_entries`) was recommended as the cleanest approach, requiring changes to only one function in one file.

## Goals & Non-Goals

**Goals**:
- `<leader>ac` [Docs] section shows only `.claude/docs/README.md`
- `<leader>ao` [Docs] section shows only `.opencode/docs/README.md`
- Local README.md takes precedence over global (consistent with existing merge behavior)
- [Docs] section hidden entirely when no README.md exists

**Non-Goals**:
- Modifying `scan_directory` behavior (README exclusion is correct for other sections)
- Adding configuration options for docs filtering (unnecessary complexity)
- Changing the heading text or display format of the [Docs] section

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Projects without docs/README.md | L | M | [Docs] section simply will not appear -- acceptable behavior |
| Regression in other picker sections | M | L | Only `create_docs_entries` is modified; scan_directory untouched |
| Display formatting mismatch | L | L | Use existing `helpers.get_tree_char(true)` for consistent "last item" styling |

## Implementation Phases

### Phase 1: Modify create_docs_entries [COMPLETED]

**Goal**: Replace the directory-scanning logic in `create_docs_entries()` with direct README.md file detection, so only `{base_dir}/docs/README.md` appears in the [Docs] section.

**Tasks**:
- [ ] Replace `scan.scan_directory` + `scan.merge_artifacts` calls with direct `vim.fn.filereadable` checks for `docs/README.md`
- [ ] Check local project README first, fall back to global README
- [ ] Create a single entry for the found README.md file
- [ ] Keep the [Docs] heading entry with existing format
- [ ] Use `helpers.get_tree_char(true)` for the tree character (always last/only item)

**Timing**: 15-20 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Replace `create_docs_entries()` function body (lines 83-127)

**Implementation detail**:

Replace the current function body:
```lua
function M.create_docs_entries(config)
  local entries = {}
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"

  -- Only show docs/README.md (not all .md files in docs/)
  local readme_path = nil
  local is_local = false
  local local_readme = project_dir .. "/" .. base_dir .. "/docs/README.md"
  local global_readme = global_dir .. "/" .. base_dir .. "/docs/README.md"

  if vim.fn.filereadable(local_readme) == 1 then
    readme_path = local_readme
    is_local = true
  elseif vim.fn.filereadable(global_readme) == 1 then
    readme_path = global_readme
    is_local = false
  end

  if readme_path then
    local description = metadata.parse_doc_description(readme_path)

    table.insert(entries, {
      display = helpers.format_display(
        is_local and "*" or " ",
        " " .. helpers.get_tree_char(true),
        "README",
        description
      ),
      entry_type = "doc",
      name = "README",
      filepath = readme_path,
      is_local = is_local,
      ordinal = "zzzz_doc_README"
    })

    table.insert(entries, {
      is_heading = true,
      name = "~~~docs_heading",
      display = string.format("%-40s %s", "[Docs]", "Integration guides"),
      entry_type = "heading",
      ordinal = "docs",
      config = config,
    })
  end

  return entries
end
```

**Verification**:
- Open Neovim in a project with `.claude/docs/README.md` present
- Run `:ClaudeCommands` and verify [Docs] section shows only "README"
- Run `:OpencodeCommands` and verify [Docs] section shows only "README" (if `.opencode/docs/README.md` exists)
- Verify the local indicator (`*`) appears correctly when README is local
- Verify [Docs] section is hidden when no README.md exists

---

### Phase 2: Verification and Testing [COMPLETED]

**Goal**: Validate the change works correctly across both pickers and does not regress other sections.

**Tasks**:
- [ ] Test `:ClaudeCommands` picker -- verify [Docs] shows only README
- [ ] Test `:OpencodeCommands` picker -- verify [Docs] shows only README
- [ ] Verify other sections ([Commands], [Skills], [Agents], [Lib], etc.) are unaffected
- [ ] Verify preview works correctly when selecting the README entry
- [ ] Run existing tests: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.utils.scan_spec')" -c "q"` (if applicable)
- [ ] Test edge case: project without any docs/README.md (section should not appear)

**Timing**: 10-15 minutes

**Files to modify**: None (testing only)

**Verification**:
- All picker sections render correctly
- No Lua errors in `:messages`
- Preview pane shows README content when selected

## Testing & Validation

- [ ] `:ClaudeCommands` [Docs] section shows only README entry
- [ ] `:OpencodeCommands` [Docs] section shows only README entry (when applicable)
- [ ] Other picker sections ([Commands], [Skills], [Agents], [Lib], [Scripts], [Tests]) unaffected
- [ ] Preview works for the README entry
- [ ] No errors in `:messages` after opening pickers
- [ ] [Docs] section hidden when no docs/README.md exists

## Artifacts & Outputs

- Modified file: `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
- No new files created
- No configuration changes needed

## Rollback/Contingency

Revert the single function `create_docs_entries()` in `entries.lua` to its previous implementation (restore `scan.scan_directory` + `scan.merge_artifacts` calls). The change is isolated to one function in one file, making rollback trivial via `git checkout`.
