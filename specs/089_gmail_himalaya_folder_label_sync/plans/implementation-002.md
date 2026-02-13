# Implementation Plan: Task #89 (Revised v002)

- **Task**: 89 - gmail_himalaya_folder_label_sync
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-002.md (this file)
- **Previous Version**: plans/implementation-001.md (superseded)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Revision Notes

Changes from v001:
- **Removed**: Phase 1 backup file creation - using git version control instead
- **Changed**: Edit `~/.dotfiles/home.nix` instead of `~/.mbsyncrc` directly
- **Added**: Home-manager rebuild step to apply changes
- **Simplified**: 4 phases instead of 5 (backup eliminated)

## Overview

This plan implements bidirectional folder/label synchronization between Gmail and Himalaya by modifying the home-manager configuration in `~/.dotfiles/home.nix`. The mbsyncrc is defined inline in home.nix and managed via Nix, creating symlinks to the generated config. Git version control in the dotfiles repo provides rollback capability.

### Research Integration

Key findings from research-001.md:
- Current architecture: Gmail IMAP <-> mbsync <-> Local Maildir <-> Himalaya CLI
- Himalaya operates on local Maildir only; mbsync handles Gmail synchronization
- Current mbsyncrc uses explicit `Patterns "EuroTrip" "CrazyTown" "Letters"` - new labels do not auto-sync
- Solution: Change to `Patterns * ![Gmail]* !INBOX` with `Create Both`, `Expunge Both`, and `Remove Both`

### Configuration Location

The mbsyncrc is managed by home-manager in:
- **Source**: `~/.dotfiles/home.nix` (lines 888-894, gmail-folders channel)
- **Generated**: `/nix/store/.../home-manager-files/.mbsyncrc`
- **Symlink**: `~/.mbsyncrc` -> Nix store path

## Goals & Non-Goals

**Goals**:
- Enable automatic discovery and sync of new Gmail labels created in browser
- Enable Himalaya-created folders to sync to Gmail without manual pattern list edits
- Enable bidirectional folder deletion propagation
- Preserve existing folder sync behavior for current labels
- Use git for version control (no backup file copies)

**Non-Goals**:
- Modifying Himalaya's Lua integration in Neovim (out of scope)
- Changing the Maildir backend architecture (keeping current two-tier design)
- Moving mbsyncrc to a separate file (keeping inline in home.nix)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wildcard patterns sync unwanted system folders | Low | Low | Use exclusion patterns `![Gmail]*` and `!INBOX` |
| Accidental folder deletion propagates to Gmail | Medium | Medium | Test with non-critical folder first; git revert available |
| Breaking existing sync behavior | High | Low | Git commit before changes; test incrementally; easy rollback |
| Home-manager rebuild failure | Low | Low | Nix syntax checked before apply; git revert if needed |

## Implementation Phases

### Phase 1: Modify home.nix for Wildcard Patterns [COMPLETED]

**Goal**: Update the gmail-folders channel in home.nix to use wildcard patterns with proper exclusions.

**Tasks**:
- [ ] Commit current state of home.nix to git (ensure clean starting point)
- [ ] Edit `~/.dotfiles/home.nix` gmail-folders channel (lines 888-894)
- [ ] Change `Patterns` from explicit list to wildcard with exclusions
- [ ] Add `Remove Both` directive for folder deletion propagation
- [ ] Commit changes with descriptive message

**Timing**: 15 minutes

**Files to modify**:
- `~/.dotfiles/home.nix` - Modify gmail-folders channel configuration

**Changes** (around line 888-894):
```diff
      Channel gmail-folders
      Far :gmail-remote:
      Near :gmail-local:
-     Patterns "EuroTrip" "CrazyTown" "Letters"
+     Patterns * ![Gmail]* !INBOX
      Create Both
      Expunge Both
+     Remove Both
      SyncState *
```

**Verification**:
- Git commit created with changes
- No Nix syntax errors in home.nix

---

### Phase 2: Rebuild Home-Manager and Test Sync [IN PROGRESS]

**Goal**: Apply the new configuration and verify basic sync still works.

**Tasks**:
- [ ] Run `home-manager switch` to rebuild and apply configuration
- [ ] Verify symlink updated: `ls -la ~/.mbsyncrc`
- [ ] Verify new patterns in config: `grep "Patterns" ~/.mbsyncrc`
- [ ] Run `mbsync gmail-folders` to test sync with existing folders
- [ ] Verify existing labels (EuroTrip, CrazyTown, Letters) still sync correctly

**Timing**: 15 minutes

**Files to modify**:
- None (applying generated config)

**Commands**:
```bash
# Apply new configuration
home-manager switch

# Verify symlink points to new config
ls -la ~/.mbsyncrc

# Verify patterns
grep -A 5 "Channel gmail-folders" ~/.mbsyncrc

# Test sync
mbsync gmail-folders

# Check existing folders still present
himalaya folder list --account gmail | grep -E "EuroTrip|CrazyTown|Letters"
```

**Verification**:
- Home-manager switch completes without errors
- ~/.mbsyncrc contains new wildcard patterns
- Existing folders still sync correctly

---

### Phase 3: Test Bidirectional Folder Sync [NOT STARTED]

**Goal**: Verify new labels/folders sync bidirectionally between Gmail and Himalaya.

**Tasks**:
- [ ] **Gmail -> Himalaya**: Create test label "TestFromGmail" in Gmail web interface
- [ ] Run `mbsync gmail-folders` and verify folder appears locally
- [ ] Verify folder visible in `himalaya folder list --account gmail`
- [ ] **Himalaya -> Gmail**: Create test folder via `himalaya folder add TestFromHimalaya --account gmail`
- [ ] Run `mbsync gmail-folders` and verify label appears in Gmail web interface
- [ ] **Deletion test**: Delete TestFromGmail in Gmail, sync, verify removed locally
- [ ] **Deletion test**: Delete TestFromHimalaya in Himalaya, sync, verify removed from Gmail
- [ ] Clean up any remaining test folders

**Timing**: 20 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- New Gmail labels auto-sync to Himalaya after mbsync
- New Himalaya folders sync to Gmail as labels
- Folder deletions propagate in both directions

---

### Phase 4: Update Documentation [NOT STARTED]

**Goal**: Document the new workflow and configuration for future reference.

**Tasks**:
- [ ] Update `~/.dotfiles/docs/himalaya.md` with new folder sync behavior
- [ ] Document the workflow:
  - Creating folders in Gmail (auto-syncs to Himalaya)
  - Creating folders in Himalaya (syncs to Gmail via mbsync)
  - Deleting folders (propagates bidirectionally)
- [ ] Note that explicit Patterns list is no longer needed
- [ ] Commit documentation changes

**Timing**: 10 minutes

**Files to modify**:
- `~/.dotfiles/docs/himalaya.md` - Add folder sync documentation

**Verification**:
- Documentation accurately describes new behavior
- Workflow steps are clear and actionable
- Changes committed to git

## Testing & Validation

- [ ] Git commit created before any changes
- [ ] home.nix modification applied without Nix syntax errors
- [ ] Home-manager switch completes successfully
- [ ] Existing folders (EuroTrip, CrazyTown, Letters) remain synced
- [ ] New Gmail labels auto-sync to Himalaya after `mbsync gmail-folders`
- [ ] Himalaya-created folders sync to Gmail as labels
- [ ] Folder deletions propagate bidirectionally
- [ ] No unwanted [Gmail]/* system folders appear in local Maildir

## Artifacts & Outputs

- `~/.dotfiles/home.nix` - Modified configuration (git tracked)
- `~/.dotfiles/docs/himalaya.md` - Updated documentation (git tracked)
- `specs/089_gmail_himalaya_folder_label_sync/summaries/implementation-summary-YYYYMMDD.md` - Completion summary

## Rollback/Contingency

Git provides full rollback capability:

1. **Immediate Rollback**: Revert to previous commit
   ```bash
   cd ~/.dotfiles
   git revert HEAD
   home-manager switch
   ```

2. **Partial Rollback**: If only `Remove Both` causes issues
   - Edit home.nix to remove `Remove Both` line
   - Run `home-manager switch` to apply

3. **Investigation**: If unexpected folders sync
   - Check Patterns exclusion syntax in home.nix
   - Add additional exclusion patterns as needed
   - Example: Add `!Drafts !Archive` if those cause issues
