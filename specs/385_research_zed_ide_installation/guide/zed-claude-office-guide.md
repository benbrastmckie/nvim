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
   ("Replace 'ACME Corp' with 'NewCo Inc.' in contract.docx")

2. Claude reads your file using SuperDoc

3. Claude makes the edits (with tracked changes if you ask)

4. Claude saves the file

5. You open the file in Word and review the changes
```

You stay in Zed to give instructions. You open Word only to review the result.

### What It Cannot Do

Be aware of these limitations:

- **Cannot open Word/Excel files inside Zed** -- Zed is a text editor, not an Office suite. You still need Word or Excel to view the final result.
- **Cannot edit a file while Word has it open** -- Save and close the file in Word before asking Claude to edit it. Otherwise you may get a "file locked" error.
- **Each request uses API credits** -- Claude Code runs on a subscription or pay-per-use model. Frequent large edits will use more credits than simple questions.
- **Complex formatting has limits** -- SuperDoc handles most formatting well (bold, tables, headers, tracked changes), but very complex layouts (embedded charts, SmartArt) may need manual touch-up in Word.

---

## Part 3: Common Workflows

These are step-by-step recipes for everyday tasks. Each one includes an example prompt you can paste directly into the Agent Panel.

### Workflow 1: Edit a Word Document with Tracked Changes

Use this when you want Claude to make changes to an existing .docx file, and you want to review each change in Word before accepting it.

**Steps:**

1. **Save and close** the document in Word
2. Open **Zed** and press **Cmd + Shift + ?** to open the Agent Panel
3. Type your request (see example below)
4. Wait for Claude to confirm the edits are done
5. Open the file in **Word** -- you will see tracked changes you can Accept or Reject

**Example prompt:**

> In ~/Documents/contract.docx, replace every instance of "ACME Corp" with "NewCo Inc." using tracked changes.

### Workflow 2: Update a Spreadsheet

Use this when you need to change values, add rows, or update formulas in an .xlsx file.

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

1. **Save and close** all the documents in Word
2. If your files are in OneDrive, **pause syncing** first (see Tips below)
3. Open the Agent Panel in Zed
4. Tell Claude which folder and what to change
5. Resume OneDrive syncing when done

**Example prompt:**

> In all .docx files in ~/Documents/Contracts/, replace "Old Company LLC" with "New Company LLC" using tracked changes. Give me a summary of how many changes were made in each file.

### Workflow 4: Create a New Document from Scratch

Use this when you want Claude to draft and format a new Word document for you.

**Steps:**

1. Open the Agent Panel in Zed
2. Describe what you need -- include the title, sections, and any specific content
3. Open the new file in Word to review and polish

**Example prompt:**

> Create a new Word document at ~/Documents/memo.docx with the title "Q2 Budget Review", dated April 9, 2026, from Sarah Chen (Finance Director) to the Executive Team. Include a brief summary paragraph and a table with 4 columns: Department, Q1 Actual, Q2 Budget, and Variance.

### Tips for OneDrive and SharePoint Files

If your documents sync with OneDrive or SharePoint, follow these two rules to avoid conflicts:

**Rule 1: Always close the file in Word first.**
OneDrive locks files that Word has open. If Claude tries to edit a locked file, it will fail. Save the file, close Word, wait a few seconds, then ask Claude.

**Rule 2: Pause OneDrive sync for batch edits.**
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
| Edit a Word doc with tracked changes | Close it in Word first, then ask Claude (see Workflow 1) |
| Update spreadsheet values | Close it in Excel first, then ask Claude (see Workflow 2) |
| Edit many files at once | Pause OneDrive sync, then ask Claude (see Workflow 3) |
| Create a new Word document | Just describe it to Claude (see Workflow 4) |
| See what Claude changed | Open the file in Word -- look for tracked changes |
| Check which helpers are installed | Run `claude mcp list` in WezTerm |
| Open a file in Zed | Press **Cmd + P** and type the filename |
| Search for text in Zed | Press **Cmd + Shift + F** |
| Save a file in Zed | Press **Cmd + S** |
| Open Zed settings | Press **Cmd + ,** |

### Useful Phrases for Claude

These are good starting phrases for your prompts:

- "In [file path], replace..." -- for find-and-replace edits
- "In [file path], using tracked changes..." -- to get reviewable changes in Word
- "Create a new Word document at [path]..." -- for new documents
- "In all .docx files in [folder]..." -- for batch operations
- "Give me a summary of..." -- to get a report instead of making edits
