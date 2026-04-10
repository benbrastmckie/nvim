# Zed + Claude Code + Office Files: Setup and Usage Guide

**Last updated**: April 9, 2026
**Tools**: Zed 0.x, Claude Code, SuperDoc MCP, openpyxl MCP
**Platform**: macOS

---

## What You'll Get

After following this guide, you will have:

- **Zed** -- a fast, modern code editor (replaces apps like VS Code)
- **Claude Code** -- an AI assistant that lives inside Zed and can read, write, and edit files for you
- **SuperDoc + openpyxl** -- invisible helpers that let Claude edit Word and Excel files properly, preserving formatting and tracked changes

---

## Part 1: Installation (About 20 Minutes)

### Before You Start

- You need a Mac running macOS 11 (Big Sur) or newer
- You need an internet connection
- Set aside about 20-30 minutes

### Step 1: Open WezTerm

Open **WezTerm** from your Applications folder or Dock. A window with a text prompt will appear. You will paste commands into this window.

### Step 2: Install Homebrew

Homebrew is a tool that installs other tools. Paste this entire line and press Enter:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions (you may need to enter your Mac password). When it finishes, close WezTerm and reopen it.

To verify it worked, paste this and press Enter:

```
brew --version
```

You should see a version number like `Homebrew 4.x.x`. If you see "command not found", restart WezTerm and try again.

### Step 3: Install Zed

```
brew install --cask zed
```

Open Zed from your Applications folder or Spotlight (Cmd + Space, type "Zed") to confirm it launches. You can close it for now.

### Step 4: Connect the Word Document Helper (SuperDoc)

This lets Claude edit .docx files with tracked changes:

```
claude mcp add --scope user superdoc -- npx @superdoc-dev/mcp
```

### Step 5: Connect the Spreadsheet Helper (openpyxl)

This lets Claude edit .xlsx files:

```
claude mcp add --scope user openpyxl -- npx @jonemo/openpyxl-mcp
```

Verify both helpers are connected:

```
claude mcp list
```

You should see `superdoc` and `openpyxl` in the list.

### You're Done!

Open Zed, then press **Cmd + Shift + ?** to open the Agent Panel. Type a question to Claude to confirm everything works. Try: "Hello, what can you help me with?"

### Troubleshooting

**"command not found" after installing Homebrew**
Close WezTerm completely (Cmd + Q) and reopen it. Homebrew needs a fresh session.

**"superdoc" or "openpyxl" not showing in `claude mcp list`**
Re-run the `claude mcp add` command from Steps 4 or 5. Make sure you include `--scope user`.

**Zed's Agent Panel doesn't respond**
In Zed, go to **Settings > Extensions** and confirm "Claude Code" is listed. If not, search for it and install it.

---

## Part 2: What Each Tool Does

### What is Zed?

Zed is a text editor -- think of it as a lightweight alternative to apps like VS Code or Sublime Text. It opens fast, uses less memory, and has a built-in panel where you can chat with an AI assistant. You will use Zed as your home base for talking to Claude.

### What is Claude Code?

Claude Code is an AI assistant made by Anthropic. It lives inside Zed's Agent Panel (the sidebar you open with **Cmd + Shift + ?**). You type requests in plain English, and Claude reads your files, makes edits, and answers questions. It understands context -- you can say "edit the budget spreadsheet on my Desktop" and it knows what you mean.

### What is SuperDoc?

SuperDoc is an invisible helper that runs behind the scenes. When Claude needs to edit a Word document, it uses SuperDoc to make changes the right way -- preserving your formatting, styles, and tracked changes. You never interact with SuperDoc directly. It just makes Claude smarter about Office files.

The openpyxl helper does the same thing for Excel spreadsheets.

### How They Work Together

Here is what happens when you ask Claude to edit a Word document:

```
1. You type a request in Zed's Agent Panel
   (/edit ~/Documents/contract.docx "Replace 'ACME Corp' with 'NewCo Inc.'")

2. Claude saves any unsaved changes in Word for you

3. Claude makes the edits using SuperDoc (with tracked changes if you ask)

4. Claude reloads the document in Word automatically

5. You see the tracked changes appear in Word -- no need to reopen anything
```

You stay in Zed to give instructions. Word stays open the whole time -- Claude handles the save-edit-reload cycle for you.

### What It Cannot Do

Be aware of these limitations:

- **Cannot open Word/Excel files inside Zed** -- Zed is a text editor, not an Office suite. You still need Word or Excel to view the final result.
- **Each request uses API credits** -- Claude Code runs on a subscription or pay-per-use model. Frequent large edits will use more credits than simple questions.
- **Complex formatting has limits** -- SuperDoc handles most formatting well (bold, tables, headers, tracked changes), but very complex layouts (embedded charts, SmartArt) may need manual touch-up in Word.

### First-Time Setup Note

The first time Claude edits a document while Word is open, macOS will ask you to grant Zed (or WezTerm) permission to control Microsoft Word. Click **OK** when the dialog appears. This only happens once -- after that, Claude can save and reload Word documents automatically.

---

## Part 3: Common Workflows

These are step-by-step recipes for everyday tasks. Each one includes an example prompt you can paste directly into the Agent Panel.

### Workflow 1: Edit a Word Document with Tracked Changes

Use this when you want Claude to make changes to an existing .docx file, and you want to review each change in Word before accepting it. Word can stay open -- Claude handles saving and reloading for you.

**Steps:**

1. Open **Zed** and press **Cmd + Shift + ?** to open the Agent Panel
2. Type your request using `/edit` (see example below)
3. Wait for Claude to confirm the edits are done
4. Switch to **Word** -- the tracked changes will already be there

**Example prompt:**

> /edit ~/Documents/contract.docx "Replace every instance of 'ACME Corp' with 'NewCo Inc.' using tracked changes"

### Workflow 2: Update a Spreadsheet

Use this when you need to change values, add rows, or update formulas in an .xlsx file. **Note:** For spreadsheets, save and close the file in Excel first -- the automatic reload only works with Word for now.

**Steps:**

1. **Save and close** the spreadsheet in Excel
2. Open the Agent Panel in Zed
3. Describe what you want changed, being specific about sheet names, row labels, or column headers
4. Open the file in Excel to verify

**Example prompt:**

> In ~/Documents/budget.xlsx on the "Q2" sheet, change the Marketing row from 5000 to 7500, change Engineering from 12000 to 14000, and add a new row called "Cloud Services" with values 3000, 3200, 3500.

### Workflow 3: Edit Multiple Documents at Once

Use this when you need to make the same change across several Word files -- for example, updating a company name in all your contract templates.

**Steps:**

1. If your files are in OneDrive, **pause syncing** first (see Tips below)
2. Open the Agent Panel in Zed
3. Tell Claude which folder and what to change
4. Resume OneDrive syncing when done

**Example prompt:**

> /edit ~/Documents/Contracts/ "Replace 'Old Company LLC' with 'New Company LLC' using tracked changes. Give me a summary of how many changes were made in each file."

### Workflow 4: Create a New Document from Scratch

Use this when you want Claude to draft and format a new Word document for you.

**Steps:**

1. Open the Agent Panel in Zed
2. Describe what you need -- include the title, sections, and any specific content
3. Open the new file in Word to review and polish

**Example prompt:**

> /edit --new ~/Documents/memo.docx "Create a Q2 Budget Review memo, dated April 9, 2026, from Sarah Chen (Finance Director) to the Executive Team. Include a brief summary paragraph and a table with 4 columns: Department, Q1 Actual, Q2 Budget, and Variance."

### Workflow 5: Grant Writing and Research Presentations

Beyond editing documents, Claude has specialized commands for academic and research work. These walk you through the process with questions before producing output.

**`/grant` -- Write and manage grant proposals**

Start a new grant task, then draft sections or build a budget:

> /grant "NSF CAREER proposal on computational epidemiology"

Claude will ask clarifying questions (funding agency, aims, timeline). Once the task exists, use sub-commands:

> /grant 42 --draft "specific aims page"

> /grant 42 --budget "3-year R01, two postdocs, one graduate student"

**`/budget` -- Create grant budget spreadsheets**

Generates a formatted .xlsx budget with formulas for salaries, overhead, and multi-year totals:

> /budget "NIH R01 detailed budget, 5 years, $300K direct costs per year"

Claude will ask about personnel, equipment, and rates, then produce a ready-to-submit spreadsheet.

**`/funds` -- Research funding opportunities**

Surveys available funding programs and produces a report with eligibility, deadlines, and strategy:

> /funds "NIH and NSF funding landscape for machine learning in clinical trials"

**`/timeline` -- Build a project timeline**

Creates a structured timeline mapping specific aims to milestones and decision points:

> /timeline "R01 project timeline, 5 years, 3 specific aims"

**`/talk` -- Create research presentations**

Builds a slide deck from your research materials. Point it at a paper or manuscript:

> /talk "20-minute conference talk on our survival analysis paper"

> /talk /path/to/manuscript.pdf

Claude will ask about audience, format (conference, seminar, defense, poster, journal club), and key messages before assembling slides.

**How these commands work:** Each one creates a task that Claude works through step by step. You can close Zed and come back later -- type the same command with the task number to resume (e.g., `/grant 42`).

### Tips for OneDrive and SharePoint Files

If your documents sync with OneDrive or SharePoint:

**Pause OneDrive sync for batch edits.**
If you are editing many files at once (Workflow 3), pause syncing so OneDrive does not try to upload files mid-edit:

1. Click the **OneDrive icon** in your menu bar (top-right of screen)
2. Click the gear icon, then **Pause Syncing**
3. Choose a duration (2 hours is plenty)
4. Do your edits with Claude
5. Click the OneDrive icon again and choose **Resume Syncing**

---

## Part 4: Quick Reference

### Daily Workflow

Every time you want Claude to help with a file:

1. **Open Zed**
2. **Press Cmd + Shift + ?** to open the Agent Panel
3. **Type what you need** in plain English

That's it. Claude handles the rest.

### Cheat Sheet

| I want to... | Do this |
|---|---|
| Open the AI assistant | Press **Cmd + Shift + ?** in Zed |
| Edit a Word doc with tracked changes | `/edit path/to/file.docx "your instructions"` (see Workflow 1) |
| Update spreadsheet values | Close it in Excel first, then ask Claude (see Workflow 2) |
| Edit many files at once | `/edit path/to/folder/ "your instructions"` (see Workflow 3) |
| Create a new Word document | `/edit --new path/to/file.docx "describe what you need"` (see Workflow 4) |
| Write a grant proposal | `/grant "description"` then `/grant N --draft` (see Workflow 5) |
| Build a grant budget | `/budget "description"` (see Workflow 5) |
| Find funding opportunities | `/funds "your research area"` (see Workflow 5) |
| Create a project timeline | `/timeline "description"` (see Workflow 5) |
| Make a research talk | `/talk "description"` or `/talk /path/to/paper` (see Workflow 5) |
| See what Claude changed | Switch to Word -- tracked changes appear automatically |
| Check which helpers are installed | Run `claude mcp list` in WezTerm |
| Open a file in Zed | Press **Cmd + P** and type the filename |
| Search for text in Zed | Press **Cmd + Shift + F** |
| Save a file in Zed | Press **Cmd + S** |
| Open Zed settings | Press **Cmd + ,** |

### Useful Phrases for Claude

Start with `/edit` for any Word document task:

- `/edit file.docx "replace X with Y"` -- for find-and-replace edits
- `/edit file.docx "replace X with Y using tracked changes"` -- to get reviewable changes in Word
- `/edit --new file.docx "create a memo about..."` -- for new documents
- `/edit ~/Documents/Contracts/ "replace X with Y in all files"` -- for batch operations
- "Give me a summary of..." -- to get a report instead of making edits (no `/edit` needed)
