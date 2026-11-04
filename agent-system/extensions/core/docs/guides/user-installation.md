# User Installation Guide

[Back to Docs](../docs-README.md) | [Detailed Installation](../../../../../docs/CLAUDE_CODE_INSTALL.md)

A quick-start guide for installing Claude Code and using it with your project.

---

## What This Guide Covers

This guide helps you:
1. Install Claude Code (Anthropic's AI CLI)
2. Set up your project
3. Set up Claude agent commands (optional)
4. Work with your project files
5. Set up GitHub CLI for issue reporting

**New to the terminal?** See your operating system's documentation for terminal basics.

---

## Installing Claude Code

Claude Code is Anthropic's command-line interface for AI-assisted development.

### Quick Installation

**macOS:**
```bash
brew install anthropics/claude/claude-code
```

**Windows (PowerShell as Administrator):**
```powershell
irm https://raw.githubusercontent.com/anthropics/claude-code/main/install.ps1 | iex
```

**Linux:**
```bash
curl -fsSL https://raw.githubusercontent.com/anthropics/claude-code/main/install.sh | sh
```

### Verify Installation

```bash
claude --version
```

You should see a version number.

---

## Authentication

Before using Claude Code, authenticate with your Anthropic account:

```bash
claude auth login
```

This opens a browser window. Log in with your Anthropic account and authorize Claude Code.

**Verify authentication:**
```bash
claude auth status
```

---

## Setting Up Your Project with Claude Code

### Step 1: Navigate to Your Project

```bash
cd /path/to/your/project
```

### Step 2: Initialize Git (if not already done)

Run manually by the user in their terminal, before the agent system (and therefore
`.claude/scripts/git-commit-scoped.sh`) exists in this project — outside the scope of the
scoped-commit contract in `.claude/context/standards/git-staging-scope.md`, which governs
agent-driven task commits after installation, not this one-time human bootstrap step:

```bash
git init
git add .
git commit -m "Initial commit"
```

### Step 3: Start Claude Code

```bash
claude
```

### Step 4: Verify Setup

Ask Claude:

```
Please verify my project setup by:
1. Checking the overall structure of the project
2. Identifying the build system or package manager in use
3. Confirming the source modules are properly organized
```

---

## Setting Up Claude Agent Commands (Optional)

The repository includes a `.claude/` agent system that provides enhanced task management and workflow commands for Claude Code.

### What the Agent System Provides

- **Task Management**: Create, track, and archive development tasks
- **Autonomous Workflow**: `/task "Description"` -> `/orchestrate N` -> `/todo` cycle, driven
  end to end by `/orchestrate` with no confirmation gates between phases
- **Specialized Skills**: Language-specific agents via extensions
- **Context Files**: Domain knowledge loaded per task type
- **State Persistence**: Track progress across Claude Code sessions

### After Installation

1. **Restart Claude Code** - Exit and restart for commands to be available
2. **Test the setup** - Try creating a test task:
   ```
   /task "Test task"
   ```
3. **Learn the commands** - See the Commands Reference

### Available Commands

| Command | Purpose |
|---------|---------|
| `/task` | Create and manage tasks |
| `/orchestrate` | Drive a task through its full lifecycle (research -> plan -> implement), or force a single phase with `--research`/`--plan`/`--implement` |
| `/revise` | Revise a plan or update a task description |
| `/todo` | Archive completed tasks |

For complete documentation, see the [Commands Reference](../../commands/README.md).

---

## Working with Your Project

Once your project is set up, use Claude Code to assist with development.

### Explore the Codebase

In Claude Code, ask:

```
Show me the structure of my project and explain
how the modules are organized.
```

Claude will:
1. Navigate the source directory structure
2. Explain the project organization
3. Show how configuration and modules are structured

### Working on Code

Ask Claude to help with specific tasks:

```
Help me understand how the authentication module is
configured in src/auth/config.py
```

Or:

```
I want to add a new module for data processing. Can you help me
find popular libraries and set one up?
```

---

## GitHub CLI Setup

The GitHub CLI (`gh`) allows Claude Code to create issues and pull requests. This is helpful for reporting bugs or contributing.

### Installing GitHub CLI

Ask Claude:

```
Please install the GitHub CLI (gh) for my system and help me
authenticate with GitHub.
```

**Or manually:**

**macOS:**
```bash
brew install gh
```

**Windows:**
```powershell
winget install GitHub.cli
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install gh
```

### Authenticate with GitHub

```bash
gh auth login
```

Follow the prompts to authenticate via browser.

**Verify:**
```bash
gh auth status
```

---

## Example Workflows

### Complete First-Time Setup

```bash
# Install Claude Code (see platform commands above)
claude --version

# Authenticate
claude auth login

# Navigate to your project
cd /path/to/your/project

# Start Claude
claude
```

In Claude Code:
```
Please help me:
1. Verify my project is properly structured
2. Explore the source directory and identify modules
3. Check for any common issues or improvements
```

### Adding a New Dependency

```bash
cd /path/to/your/project
claude
```

Ask Claude:
```
Help me add a logging library to my project with
proper configuration and usage examples.
```

### Debugging Issues

```bash
cd /path/to/your/project
claude
```

```
I'm getting an error when the project builds.
Please diagnose the issue and suggest fixes.
```

---

## Troubleshooting

### Claude Code Issues

**"Command not found":**
- Restart your terminal
- Check installation: `which claude`
- Reinstall using platform instructions

**Authentication failed:**
```bash
claude auth logout
claude auth login
```

### Project Issues

**Dependencies not loading:**
- Run your package manager's sync/install command
- Check for errors in the build output
- Verify dependency specifications are correct

**Build errors:**
- Check build configuration files for syntax errors
- Ensure all required tools are installed
- Review build logs for detailed error messages

---

## Next Steps

### Documentation

- **[Architecture](../../README.md)** - System architecture overview
- **[CLAUDE.md](../../CLAUDE.md)** - Quick reference for the agent system
- **[Commands Reference](../../commands/README.md)** - Full command documentation

### Project Documentation

- **Project source** - See your project's directory structure

### Contributing

- **[GitHub Setup](https://docs.github.com/en/get-started)** - Git and GitHub basics
- Open issues for bugs or feature requests

---

[Back to Docs](../docs-README.md) | [Copy .claude/ Directory](copy-claude-directory.md)
