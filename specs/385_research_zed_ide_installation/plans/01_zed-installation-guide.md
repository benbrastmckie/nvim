# Implementation Plan: Zed + Claude Code + Office Guide

- **Task**: 385 - Research Zed IDE installation
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md, reports/02_superdoc-workflows.md
- **Artifacts**: plans/01_zed-installation-guide.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: markdown
- **Lean Intent**: true

## Overview

Create a partner-facing guide for setting up Zed IDE with Claude Code and Microsoft Office file support on macOS. The guide prioritizes a minimal, non-overwhelming installation section (get things working in under 30 minutes) followed by deeper sections explaining what each tool can do and how to use them together. The deliverable is a single markdown document written for a non-technical audience who is comfortable with computers but not with terminals or developer tooling. Definition of done: a self-contained guide that the partner can follow from zero to a working Zed + Claude Code + SuperDoc setup, with reference sections for ongoing use.

### Research Integration

Two research reports inform this plan:

- **01_team-research.md**: Established the two-tier workflow (Claude Cowork for visual edits, Zed + Claude Code + SuperDoc MCP for programmatic edits), confirmed Zed cannot render Office files, identified installation commands for macOS, and mapped the MCP server landscape.
- **02_superdoc-workflows.md**: Provided concrete SuperDoc MCP installation steps, tool inventory, five detailed workflows (tracked changes, spreadsheet updates, batch SharePoint edits, new document creation, format conversion), and SharePoint/OneDrive mitigation strategies.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Produce a clear, step-by-step installation guide for macOS (Zed, Claude Code, Node.js, SuperDoc MCP, openpyxl MCP)
- Keep the installation section minimal and sequential -- no branching choices, no explanations of why
- Write post-installation sections covering: what each tool does, common workflows, tips for Office files
- Use plain language appropriate for a partner who uses Word/Excel daily but has never used a terminal IDE
- Include a quick-reference cheat sheet for daily use

**Non-Goals**:
- Writing installation instructions for Linux or Windows (partner is on macOS)
- Implementing any code, agents, skills, or extensions (this task produces a guide, not software)
- Covering Claude Cowork / Claude Desktop setup (separate tool, separate guide)
- Teaching programming or Zed extension development
- Covering every SuperDoc tool (focus on the 5 core workflows from research)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Guide is too long or overwhelming | H | M | Strict separation: installation is 1 page max, details come later in optional sections |
| SuperDoc MCP npx command fails on partner's machine | M | M | Include a verification step after each install command; add a troubleshooting subsection |
| Partner unfamiliar with Terminal.app | M | M | Include screenshot-style instructions (open Spotlight, type Terminal) and exact copy-paste commands |
| Node.js not installed on partner's Mac | M | L | Include Homebrew + Node.js install as prerequisite step |
| Guide becomes outdated as tools evolve | L | H | Date-stamp the guide; note version numbers for each tool |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Guide Structure and Installation Section [COMPLETED]

**Goal**: Create the guide document with front matter, table of contents, and the complete installation section -- the most critical part that must be minimal and clear.

**Tasks**:
- [ ] Create guide file at a suitable location (e.g., `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md`)
- [ ] Write guide title, date, and "What You'll Get" summary (3 bullet points: code editor, AI assistant, Office file editing)
- [ ] Write "Before You Start" checklist (macOS version, internet connection, ~30 minutes)
- [ ] Write "Step 1: Install Homebrew" (if not already installed) -- single terminal command with verification
- [ ] Write "Step 2: Install Node.js" -- `brew install node@20` with version check
- [ ] Write "Step 3: Install Zed" -- `brew install --cask zed` with "open Zed to verify"
- [ ] Write "Step 4: Install Claude Code" -- `brew install claude-code` or npm install, with login step
- [ ] Write "Step 5: Connect SuperDoc" -- `claude mcp add --scope user superdoc -- npx @superdoc-dev/mcp` with verification
- [ ] Write "Step 6: Connect Spreadsheet Tools" -- openpyxl MCP add command
- [ ] Write "Step 7: Open Zed and Verify" -- open a project, open Agent Panel (Cmd+?), ask Claude a test question
- [ ] Write "Troubleshooting" subsection (3-4 common issues: Node version too old, Homebrew not found, MCP not showing up)
- [ ] Review installation section for length -- target 1 printed page, no more

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md` - create new file

**Verification**:
- Installation section exists with exactly 7 numbered steps
- No step requires more than one terminal command
- Troubleshooting subsection covers at least 3 issues
- Section reads clearly without technical jargon

---

### Phase 2: Functionality Overview Sections [COMPLETED]

**Goal**: Write the "What Can It Do?" sections that explain each tool's capabilities in plain language, so the partner understands what's available before diving into workflows.

**Tasks**:
- [ ] Write "What is Zed?" section -- fast editor, replaces VSCode, keyboard shortcuts cheat sheet (open file, save, search, split panes)
- [ ] Write "What is Claude Code?" section -- AI assistant that lives inside Zed, can read/write files, understands context, accessed via Agent Panel
- [ ] Write "What is SuperDoc?" section -- invisible helper that lets Claude edit Word/Excel files properly (tracked changes, formatting preserved)
- [ ] Write "How They Work Together" section -- diagram or numbered flow showing: you ask Claude in Zed -> Claude uses SuperDoc -> file is edited -> you open in Word to review
- [ ] Write "What It Cannot Do" section -- honest limitations: cannot open Word files inside Zed, cannot edit files while Word has them open, changes consume API tokens

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md` - append sections

**Verification**:
- Each tool has its own subsection with a one-sentence summary
- "How They Work Together" includes a clear sequential flow
- Limitations section is honest and specific

---

### Phase 3: Workflow Patterns Section [COMPLETED]

**Goal**: Write practical, copy-paste-ready workflow examples the partner can follow for their most common Office tasks.

**Tasks**:
- [ ] Write "Workflow 1: Edit a Word Document with Tracked Changes" -- step-by-step from saving in Word through asking Claude to reviewing changes back in Word
- [ ] Write "Workflow 2: Update a Spreadsheet" -- finding and changing cell values, adding rows
- [ ] Write "Workflow 3: Batch-Edit Multiple Documents" -- replacing text across several files at once (the SharePoint contract example)
- [ ] Write "Workflow 4: Create a New Document from Scratch" -- describing what you want and getting a formatted .docx
- [ ] Write "Working with OneDrive/SharePoint Files" subsection -- the pause-sync pattern and close-Word-first pattern, written as simple rules ("always save and close the file in Word before asking Claude to edit it")
- [ ] Write example prompts for each workflow -- exact text the partner can type into the Agent Panel

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md` - append sections

**Verification**:
- At least 4 workflow examples with step-by-step instructions
- Each workflow includes an example prompt the partner can copy
- OneDrive/SharePoint section includes at least 2 mitigation patterns
- No workflow requires the partner to write code or edit config files

---

### Phase 4: Quick Reference, Polish, and Final Review [COMPLETED]

**Goal**: Add a quick-reference cheat sheet, review the entire guide for tone and length, and ensure it reads as a cohesive document.

**Tasks**:
- [ ] Write "Quick Reference" cheat sheet at the end -- table format with columns: "I want to...", "Do this"
- [ ] Write "Daily Workflow" summary -- the 3-step daily pattern (open Zed, open Agent Panel, ask Claude)
- [ ] Review entire guide for consistent tone (friendly, direct, no jargon)
- [ ] Review for length -- target 4-6 printed pages total (installation: 1 page, functionality: 1-2 pages, workflows: 1-2 pages, reference: 1 page)
- [ ] Remove any developer-facing language (MCP, ACP, npm, npx explanations) from non-installation sections
- [ ] Add date stamp and version note at the top of the guide
- [ ] Verify all terminal commands are correct and copy-pasteable

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md` - edit and append

**Verification**:
- Quick reference table exists with at least 8 entries
- Guide reads coherently from start to finish
- No section uses unexplained technical terms
- Total length is between 4 and 6 pages equivalent (~200-300 lines of markdown)

## Testing & Validation

- [ ] Installation section can be followed by someone who has never used Terminal before (mental walkthrough)
- [ ] Every terminal command in the guide is syntactically correct
- [ ] All tool names and versions match current availability (as of research date 2026-04-09)
- [ ] Workflow examples match the patterns validated in research report 02
- [ ] Guide renders correctly as markdown (headings, lists, code blocks, tables)
- [ ] No section exceeds reasonable length for a non-technical reader

## Artifacts & Outputs

- `specs/385_research_zed_ide_installation/guide/zed-claude-office-guide.md` -- the complete partner-facing guide
- `specs/385_research_zed_ide_installation/plans/01_zed-installation-guide.md` -- this plan

## Rollback/Contingency

The deliverable is a single new markdown file. If the guide proves inadequate after partner testing, individual sections can be revised independently without affecting the rest. The research reports remain as source material for any rewrite. No existing files are modified by this plan.
