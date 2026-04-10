# Research Report: Task #385 - Teammate C (Critic) Findings

**Task**: 385 - Research Zed IDE installation plan for partner's laptop
**Role**: Critic - Gap analysis, assumptions, and feasibility concerns
**Started**: 2026-04-09T00:00:00Z
**Completed**: 2026-04-09T01:00:00Z
**Effort**: ~1 hour
**Sources/Inputs**: WebSearch (7 queries), WebFetch (4 pages), GitHub issues
**Artifacts**: This report

---

## Executive Summary

- The "precise location editing" concept for Word documents faces a fundamental feasibility problem: paragraph indices are positional, not stable identifiers, and shift whenever content is added or removed
- Claude Code CLI cannot natively read .docx files (confirmed as an open feature request, not yet resolved); all Office editing requires third-party skill wrappers with their own limitations
- Zed's Windows support is explicitly described by the Zed team as "not yet ready for general release" with five known problem areas remaining, making it a risky choice for a non-developer partner's daily driver
- python-docx has critical gaps around tracked changes, macros, and complex formatting that are unresolved as of the knowledge cutoff
- The task description assumes several things that need explicit validation before proceeding

---

## Section 1: Assumptions That Need Validation

### 1.1 OS Is Unknown - Installation Steps Cannot Be Written Yet

The task asks for "OS-specific installation steps" but the partner's OS is not stated. This is not a minor gap: Zed's Windows support is materially less mature than macOS or Linux. The installation approach, known issues, and suitability differ significantly:

- **macOS**: Stable, production-ready, the primary development target
- **Linux**: Stable, well-supported
- **Windows**: Explicitly documented by Zed as having five unresolved problem areas (key bindings, SSH remoting, WSL, extension compatibility, performance parity with macOS). The Zed team's own blog post states the Windows port is "not yet ready for general release."

**Validation needed**: What OS does the partner use?

### 1.2 The Partner's Use Case Is Unspecified

"Office workflow options" is too broad. The research and plan will look completely different depending on:

- Does the partner write long-form documents (essays, reports)? -> Paragraph-level editing might work
- Do they collaborate with others who track changes? -> python-docx cannot write tracked changes; edits will appear as direct edits and break review workflows
- Are any documents macro-enabled (.docm)? -> python-docx explicitly does not support .docm files
- Do they use embedded Excel tables, charts, or OLE objects in Word? -> python-docx has limited support for these
- Are documents stored on OneDrive or SharePoint? -> File locking conflicts become a serious operational concern

**Validation needed**: What does the partner actually do with Office files? Casual writing? Collaborative tracked-changes review? Templates with macros?

### 1.3 Is Zed Actually Appropriate for a Non-Developer?

Zed's entire design and marketing targets developers. Its documentation, extension ecosystem, and community assume programming workflows. For a non-developer using it to edit Word documents via AI tools, there are significant usability concerns:

- Configuration is done via JSON settings files (not a GUI wizard)
- No built-in document viewer for .docx, .xlsx, or .pdf
- No grammar/spell checking comparable to Microsoft Word or even LibreOffice
- The minimalist UI offers no "open recent documents," "file explorer" oriented toward document folders, or Office-style formatting toolbars
- If the partner needs to view the formatted document while editing, they must open a separate application

**Validation needed**: Is the partner technically comfortable with developer tools? What is their current workflow?

---

## Section 2: The Precise Location Editing Feasibility Problem

This is the most technically fraught aspect of the entire task and deserves close scrutiny.

### 2.1 Paragraph Indices Are Not Stable Identifiers

The concept of "line numbers in text files" works because line numbers are stable until the file is edited and re-counted. In .docx XML, paragraphs are elements in a sequential list within `word/document.xml`. A "paragraph index" (e.g., "paragraph 7") is purely positional.

**The fundamental problem**: Insert one paragraph before paragraph 7, and what was paragraph 7 is now paragraph 8. There is no persistent paragraph identifier by default.

The DOCX format does have a mechanism for stable references: **bookmarks** (`<w:bookmarkStart>` / `<w:bookmarkEnd>`). These survive edits and can serve as stable anchors. However:
- Bookmarks must be inserted at document creation or setup time
- python-docx has limited bookmark support (creation is possible via XML manipulation; there is no high-level API)
- Regular Word documents written by typical users will not have bookmarks in place
- The AI workflow would need to insert bookmarks as a first step before any location-based editing could be reliable

The `rsidR` attribute (revision session ID) exists in DOCX XML but is for tracking editing sessions across Word saves, not for stable paragraph addressing.

**Conclusion**: The "line number analogy" is misleading. For a virgin document without pre-placed bookmarks, paragraph indices will drift after any edit. Any implementation must either:
a) Use bookmarks (requiring upfront document instrumentation), or
b) Accept that location references become stale after each edit and require re-indexing

### 2.2 Tables, Headers, Footnotes, and Textboxes Are Not Paragraphs

A .docx document is not a flat list of paragraphs. Content appears in:
- Body paragraphs (`w:p` in `w:body`)
- Table cells (each cell has its own `w:p` elements)
- Headers and footers (separate XML parts)
- Footnotes and endnotes (separate XML parts)
- Text boxes and drawing objects (anchored inline or floating)
- Comments (separate XML part)

A "paragraph index" that counts only body paragraphs will silently ignore table cell content. A paragraph inside a table cell and a paragraph in the body can have the same positional index depending on how counting is implemented. This is a significant source of bugs and confusion.

### 2.3 python-docx Cannot Write Tracked Changes

If the partner shares documents with colleagues who use Microsoft Word's "Track Changes" feature:
- python-docx does not generate `<w:ins>` (insertion) or `<w:del>` (deletion) markup
- Edits made via python-docx will appear in Word as direct accepted edits, not as tracked suggestions
- A PR (#1534) was submitted to python-docx in January 2026 to address this, but as of research date its merge status is unknown
- The `docx-revisions` third-party library exists as a workaround but adds another dependency

**Impact**: Any workflow involving collaborative editing with track changes is not compatible with the python-docx approach without significant additional complexity.

### 2.4 Round-Trip Fidelity Issues

python-docx's documentation explicitly states that it preserves complex elements it does not understand when saving. In practice this means:
- Custom styles, themes, and style inheritance may not be preserved correctly after a round-trip
- Table formatting (cell shading, border styles) has known loss cases
- Text within table cells loses inline formatting in some versions
- Performance degrades on large documents (add_paragraph() slows as document grows)
- .docm (macro-enabled) files are explicitly unsupported and will fail to open

---

## Section 3: Claude Code and .docx - Confirmed Native Limitation

Claude Code CLI's `Read` tool rejects `.docx` files with:

```
This tool cannot read binary files. The file appears to be a binary .docx file.
```

This is a confirmed, known limitation tracked in GitHub issues (#2213, #9631, #35911). The most recent issue (#35911) was filed March 2026 and closed as a duplicate. There is no indication this will be resolved soon.

**Implication**: Any Office file editing workflow through Claude Code requires a wrapper layer (third-party skills, MCP tools, or custom scripts that:
1. Extract text from .docx via Pandoc or python-docx
2. Perform edits
3. Write back to .docx

Each of these steps introduces failure modes: extraction loss, write-back formatting corruption, and the file-locking issues described below.

---

## Section 4: File Locking and Cloud Storage Conflicts

### 4.1 File Locking When Word/Office Is Open

If the partner has a .docx file open in Microsoft Word and a script (via Claude Code) simultaneously writes to it:
- On Windows, Word holds an exclusive write lock via the OS
- The script will either fail with a permission error or write to a temp file
- This is a common complaint in the LibreOffice/OpenOffice community for exactly this scenario
- Microsoft Word also creates a lock file (`.~lock.filename.docx`) that signals to other applications that the document is open

**Impact**: The partner must close the document in Word before any AI-assisted editing can succeed. This breaks a natural workflow where someone reads the document in Word and asks Claude to edit it.

### 4.2 OneDrive / SharePoint Sync Conflicts

If documents are stored in OneDrive (very common for Office 365 users):
- OneDrive's sync client can conflict with external writes to a synced file
- Simultaneously editing via Word (which triggers OneDrive upload) and via a script can create sync conflicts
- SharePoint checked-out files are exclusively locked and cannot be written to by scripts
- OneDrive's conflict resolution creates duplicate files (`filename (1).docx`, `filename (AutoRecovery).docx`) rather than merging changes

---

## Section 5: Zed Windows Maturity - Specific Risk Items

### 5.1 Current Known Issues (from Zed's Own Blog)

As of the Zed Windows progress report (blog post still live as of April 2026 search):

| Problem Area | Status | Impact |
|---|---|---|
| Key bindings | Not resolved | Non-developer may be confused by non-standard shortcuts |
| SSH remoting | Buggy (path convention mismatches) | Remote editing scenarios broken |
| WSL support | In progress | Developer workflow, lower impact for non-dev |
| Extension compatibility | Path mismatches | Some extensions may fail silently |
| Performance vs macOS | Monitoring phase | Potential lag on lower-spec Windows hardware |

DirectX 11 is a hard requirement. On older Windows machines or VMs (e.g., Hyper-V), Zed may fail to start entirely.

### 5.2 Extension Ecosystem Gap

VS Code has 60,000+ extensions. Zed has ~500. Specific gaps relevant to a non-developer partner:

- No equivalent to VS Code's Microsoft Word Preview or Office Viewer extensions
- Git integration is more basic (GitLens-equivalent missing)
- No built-in grammar checking
- Debugger is in beta and limited to select languages (irrelevant for document editing, but signals overall maturity)
- 33% of users who migrate from VS Code to Zed return, 100% citing the extension ecosystem

### 5.3 ACP Protocol - Better News Here

ACP (Agent Client Protocol) for integrating Claude Code, OpenCode, and Codex appears to be genuinely production-ready as of late 2025, with JetBrains and Zed both shipping registry-based agent installation. This is one area where the risks are lower than initially feared.

---

## Section 6: Missing Research Areas (For Other Teammates)

The following topics are not yet addressed and should be covered:

1. **Exact partner OS** - Without this, Windows vs macOS installation steps are speculative
2. **Microsoft Office license situation** - Is the partner using Microsoft 365, a one-time purchase, or LibreOffice? This affects which file formats are in play
3. **Claude API cost modeling** - Every AI-assisted Office edit consumes API tokens. If the partner edits documents frequently, this could become expensive. No cost estimate is in the research brief
4. **Accessibility** - Zed's accessibility support (screen reader, high contrast, font scaling) has not been researched. VSCode's accessibility is substantially more mature
5. **Pandoc as an alternative foundation** - The actual conversion layer for Office files is likely Pandoc (widely used, reliable). Its limitations for round-trip fidelity should be independently researched
6. **LibreOffice as a companion app** - LibreOffice can open and save .docx files and is free. It may be a better companion for document viewing than trying to force Zed to handle it. This should be evaluated
7. **The "official Anthropic skills repo"** - The claude-office-skills README mentions being superseded by an official Anthropic skills repository (as of 2026-04-01). This official repo should be located and evaluated

---

## Section 7: Recommended Approach Before Proceeding

### Must Validate First
1. **Confirm the partner's OS** - If Windows, assess whether Zed's current stability is acceptable or whether VSCode remains the better choice for now
2. **Clarify the partner's actual document workflow** - Collaborative tracked changes vs. solo editing vs. template usage radically changes the tooling recommendation
3. **Find the official Anthropic skills repo** for Office files - It was referenced as superseding the third-party repo and may have resolved some of the limitations described here

### Design Constraints for the Implementation Plan

If proceeding, the implementation plan should acknowledge these constraints:

- **Paragraph location system must use bookmarks, not indices** - Any "precise location" feature needs to instrument documents with bookmarks on first use, then use those bookmarks as stable references
- **File must be closed in native Office app before AI editing** - This is an OS-level constraint that cannot be engineered around
- **Track changes compatibility requires explicit decision** - Either accept that edits bypass track changes (and document this for the partner), or invest in the docx-revisions library
- **python-docx should not be used on .docm files** - Macro-enabled documents must be excluded from the AI editing workflow
- **Round-trip fidelity should be tested with the partner's actual documents** - Do not assume fidelity; test with real documents before deploying

---

## Evidence and Sources

- Zed Windows known issues: [Zed for Windows: What's Taking So Long?](https://zed.dev/blog/windows-progress-report)
- Zed Windows documentation: [Zed Windows Docs](https://zed.dev/docs/windows)
- Claude Code .docx limitation (confirmed open): [Issue #35911](https://github.com/anthropics/claude-code/issues/35911)
- python-docx tracked changes gap: [Issue #340](https://github.com/python-openxml/python-docx/issues/340)
- python-docx .docm unsupported: [Issue #284](https://github.com/python-openxml/python-docx/issues/284)
- ACP production readiness: [JetBrains ACP blog](https://blog.jetbrains.com/ai/2025/12/agents-protocols-and-why-we-re-not-playing-favorites/)
- Extension ecosystem gap (33% return rate): [Zed vs VS Code 2026](https://thesoftwarescout.com/zed-vs-vs-code-2026-which-code-editor-should-you-choose/)
- DOCX XML structure and bookmarks: [officeopenxml.com bookmarks](http://officeopenxml.com/WPbookmark.php)
- rsidR / revision identifiers: [IJDC rsidR paper](https://ijdc.net/index.php/ijdc/article/download/870/685/3282)
- OneDrive/SharePoint file locking: [CIAOPS troubleshooting guide](https://blog.ciaops.com/2025/06/16/troubleshooting-guide-onedrive-sharepoint-sync-and-office-save-issues-in-m365/)
- claude-office-skills repo: [tfriedel/claude-office-skills](https://github.com/tfriedel/claude-office-skills)

---

## Confidence Levels

| Finding | Confidence | Basis |
|---|---|---|
| Paragraph indices are unstable | High | DOCX XML specification and general document model |
| Claude Code cannot natively read .docx | High | Confirmed via multiple open GitHub issues, March 2026 |
| Zed Windows not production-ready | High | Zed's own blog post explicitly states this |
| python-docx cannot write tracked changes | High | Open GitHub issues, no merged fix confirmed |
| python-docx cannot open .docm files | High | Explicitly documented in issue #284 |
| ACP is production-ready | Medium-High | JetBrains + Zed documentation, December 2025 |
| File locking conflict with Office apps | High | Standard OS file locking behavior, documented |
| OneDrive sync conflicts | Medium | Common issue, severity depends on partner's setup |
| Zed is poor fit for non-developers | Medium | Inferred from design philosophy and community reports |
| Round-trip formatting fidelity issues | Medium | Pattern of bug reports; severity varies by document |
