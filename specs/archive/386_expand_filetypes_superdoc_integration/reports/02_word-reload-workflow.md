# Research Report: Task #386 (Round 2)

**Task**: 386 - Word Auto-Reload Workflow for docx-edit-agent
**Started**: 2026-04-09T18:15:00Z
**Completed**: 2026-04-09T18:25:00Z
**Effort**: Low
**Dependencies**: Round 1 research (01_team-research.md)
**Sources/Inputs**:
- Microsoft Learn: Document.Reload method (Word VBA)
- macOS advisory locking behavior (APFS/POSIX)
- Word for Mac AppleScript dictionary
**Artifacts**:
- specs/386_expand_filetypes_superdoc_integration/reports/02_word-reload-workflow.md

## Executive Summary

Word for Mac's `Document.Reload` VBA method can reload a document from disk without closing the window. Combined with macOS's advisory-only file locks (which SuperDoc can ignore), this enables a **zero-friction workflow**: the `docx-edit-agent` saves the partner's unsaved Word changes via AppleScript, performs SuperDoc edits, then triggers a Word reload -- all automatically, no hotkeys or manual steps required.

## Findings

### 1. macOS File Locks Are Advisory Only (High Confidence)

Word on macOS uses two locking layers:

| Layer | Mechanism | Blocks SuperDoc? |
|-------|-----------|-----------------|
| Owner file (`~$filename.docx`) | Word-internal cooperative lock | No -- only other Word instances check it |
| OS-level `flock()`/`fcntl()` | POSIX advisory lock | No -- advisory locks are ignorable by non-cooperative processes |

macOS/APFS does **not** support mandatory file locks. Any process (including SuperDoc) can freely read and write a .docx file that Word has open. The lock is a gentleman's agreement that SuperDoc does not participate in.

### 2. Word Does Not Detect External Changes (High Confidence)

Unlike VS Code or Sublime Text, Word for macOS:

- Does **not** watch the file for external modifications
- Does **not** prompt "this file was modified externally, reload?"
- Does **not** auto-refresh when the underlying file changes
- Works from an **in-memory copy** of the document
- Will **silently overwrite** external changes on its next save

This means SuperDoc can write to the file, but Word will not show the changes until explicitly told to reload.

### 3. Document.Reload Method Solves the Problem (High Confidence)

Word VBA provides `Document.Reload` which reloads the active document from disk without closing the window:

```vba
ActiveDocument.Reload
```

AppleScript equivalent:

```applescript
tell application "Microsoft Word"
    reload active document
end tell
```

Shell command:

```bash
osascript -e 'tell application "Microsoft Word" to reload active document'
```

**Behavior**:
- Discards the in-memory version, reloads from disk
- Keeps the Word window open (no close/reopen cycle)
- Asynchronous -- Word may take a moment to fully refresh
- Clears undo history (cannot undo back to pre-reload state)
- Only works on previously saved documents

### 4. Save-Before-Edit Protects Partner's Unsaved Work (High Confidence)

If the partner has unsaved edits when SuperDoc needs to write, those edits would be lost when SuperDoc overwrites the file. The solution: save the partner's work first via AppleScript before SuperDoc touches the file.

```bash
osascript -e 'tell application "Microsoft Word" to save active document'
```

This flushes the partner's in-memory edits to disk before SuperDoc opens the file. SuperDoc then reads the latest version (including the partner's just-saved changes), applies its edits on top, and saves.

### 5. The Zero-Friction docx-edit-agent Workflow (High Confidence)

The `docx-edit-agent` should execute this sequence automatically:

```
Step 1: Check if Word is running and has the target file open
        osascript -e 'tell application "System Events" to (name of processes) contains "Microsoft Word"'

Step 2: If Word has the file open, save partner's unsaved changes
        osascript -e 'tell application "Microsoft Word" to save active document'

Step 3: SuperDoc opens, edits, and saves the file
        superdoc_open(path) -> superdoc_search/replace -> superdoc_save() -> superdoc_close()

Step 4: If Word had the file open, trigger reload
        osascript -e 'tell application "Microsoft Word" to reload active document'
```

**Result**: The partner sees Word automatically update with the changes. No hotkeys, no closing, no reopening. The only requirement is that the partner does not type in Word during the few seconds that Steps 2-4 execute (a natural pause while waiting for Claude to finish).

### 6. Edge Cases and Mitigations

| Edge Case | Behavior | Mitigation |
|-----------|----------|------------|
| Word not running | `osascript` may launch Word or error | Check if Word is running first (Step 1); skip save/reload if not |
| File not open in Word | `save active document` has no target | Check if the specific file is the active document; skip if not |
| Partner typing during edit | Race condition: partner's keystrokes go to pre-reload buffer, lost on reload | SuperDoc edits take 2-5 seconds; acceptable risk. Agent could warn "editing document, please wait..." |
| Multiple Word documents open | `active document` may not be the target file | Match by file path: `document (full name of active document)` or iterate documents |
| Word in read-only mode | Save fails | Check if document is read-only; skip save, proceed with edit+reload |
| Large document reload | Reload takes several seconds | Async by design; no action needed |

### 7. Targeting a Specific Document (Medium Confidence)

If multiple documents are open in Word, the agent should target the correct one by path rather than relying on `active document`:

```applescript
tell application "Microsoft Word"
    set targetPath to "/Users/partner/Documents/contract.docx"
    repeat with d in documents
        if full name of d is targetPath then
            save d
            -- after SuperDoc edit:
            reload d
            exit repeat
        end if
    end repeat
end tell
```

This is more robust than `active document` but adds complexity. For v1, using `active document` with a warning if it doesn't match the target path is sufficient.

## Decisions

1. **The `docx-edit-agent` must include AppleScript save/reload as part of its workflow** -- this is not optional; it is the mechanism that makes the "no close Word" promise work
2. **Save before edit, reload after edit** -- this two-step AppleScript bracket around SuperDoc operations protects partner's work and shows results
3. **Check if Word is running before issuing AppleScript commands** -- avoid launching Word unexpectedly
4. **Use `active document` for v1** -- simpler; upgrade to path-based targeting if multi-document issues arise

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Document.Reload` not available on partner's Word version | Low | High | Test on partner's machine; fall back to close+reopen if unavailable |
| Partner types during SuperDoc edit window | Medium | Low | Edits lost on reload; 2-5 second window is acceptable |
| `osascript` blocked by macOS security (TCC) | Low | High | First run will prompt for accessibility permission; one-time approval |
| Race condition between save and SuperDoc open | Low | Medium | Sequential execution in agent ensures ordering |

## Impact on Task 386 Plan

The `docx-edit-agent` design must include:
- A "Word integration" stage that runs AppleScript save/reload
- Tool detection for `osascript` availability (always present on macOS)
- The `patterns/office-edit-patterns.md` context file should document this workflow
- The guide (`specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md`) should be updated to remove the "close Word first" requirement and replace it with the automatic workflow

## References

- [Document.Reload method (Word) - Microsoft Learn](https://learn.microsoft.com/en-us/office/vba/api/word.document.reload)
- [Automate Microsoft Word on macOS - Syed Umar Anis](https://umaranis.com/2024/02/29/automate-microsoft-word-on-macos/)
- [Office Automation with AppleScript - Brandwares](https://www.brandwares.com/bestpractices/2020/10/office-applescript-reference-cool-code/)
- [macOS File Locking - Apple Developer Forums](https://developer.apple.com/forums/thread/709905)
- [File Locking - Wikipedia](https://en.wikipedia.org/wiki/File_locking)
