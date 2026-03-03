# User Installation Guide

[Back to Docs](../README.md)

A quick-start guide for installing opencode and using it to work with Logos/Theory.

---

## What This Guide Covers

This guide helps you:
1. Set up the Logos/Theory project
2. Install Lean 4 and Mathlib
3. Work with Lean 4 proofs
4. Understand the opencode agent system

**New to the terminal?** See your operating system's documentation for terminal basics.

---

## Installing Lean 4

Logos/Theory requires Lean 4 and Mathlib. Install elan (Lean version manager):

```bash
# macOS/Linux
curl https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh -sSf | sh

# Windows - download from https://github.com/leanprover/elan/releases
```

After installation, restart your terminal and verify:

```bash
elan --version
lake --version
```

---

## Setting Up Logos/Theory

### Step 1: Clone the Repository

```bash
mkdir -p ~/Documents/Projects
cd ~/Documents/Projects
git clone https://github.com/benbrastmckie/Logos.git
cd Logos/Theory
```

### Step 2: Build the Project

```bash
cd ~/Documents/Projects/Logos/Theory
lake build
```

This may take several minutes on first build as it downloads Mathlib cache.

### Step 3: Verify Setup

Test the Lean setup:

```bash
lake build
```

Should complete without errors.

---

## Using the OpenCode Agent System

The Logos/Theory repository includes a `.opencode/` agent system that provides enhanced task management and workflow commands.

### What the Agent System Provides

- **Task Management**: Create, track, and archive development tasks
- **Structured Workflow**: `/research` -> `/plan` -> `/implement` cycle
- **Specialized Skills**: Language-specific agents for Lean 4 development
- **Context Files**: Domain knowledge for logic, semantics, and theorem proving
- **State Persistence**: Track progress across sessions
- **Lean MCP Tools**: Integration with lean-lsp for proof assistance

### Available Commands

| Command | Purpose |
|---------|---------|
| `/task` | Create and manage tasks |
| `/research` | Conduct research on a task |
| `/plan` | Create implementation plan |
| `/implement` | Execute implementation |
| `/todo` | Archive completed tasks |

For complete documentation, see the [User Guide](user-guide.md).

---

## Working with Lean 4 Proofs

Once Logos/Theory is set up, use the agent system to assist with theorem proving.

### Explore the Codebase

Ask about the project structure:

```
Show me the structure of the Theories/ directory and explain
the organization of the modal logic system.
```

### Working on Proofs

Ask for help with specific proofs:

```
Help me understand the proof of Deduction Theorem in
Theories/Modal/Logic.lean
```

Or:

```
I'm trying to prove a modal logic theorem. Can you help me
find relevant lemmas in Mathlib using leansearch?
```

### Using Lean MCP Tools

The agent system has access to specialized Lean tools:

| Tool | Purpose |
|------|---------|
| `lean_goal` | See proof state at a position |
| `lean_hover_info` | Get type signatures |
| `lean_leansearch` | Search Mathlib by natural language |
| `lean_loogle` | Search by type signature |
| `lake build` | Check for compiler errors (via Bash) |

**Note**: Some MCP tools are blocked due to known bugs. See `.opencode/context/core/patterns/blocked-mcp-tools.md` for details.

---

## GitHub CLI Setup

The GitHub CLI (`gh`) allows creating issues and pull requests. This is helpful for reporting bugs or contributing.

### Installing GitHub CLI

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

## Opening Issues on Logos/Theory

When you encounter bugs or have suggestions, you can create issues.

### Using the Agent System

```
I'm getting an error when building the project.
Help me create an issue on the Logos/Theory repository
with the error details.
```

### Manual Issue Creation

```bash
gh issue create --repo benbrastmckie/Logos \
  --title "Brief description" \
  --body "Detailed description of the issue"
```

### What to Include in Issues

- Lean version (`lean --version`)
- Lake version (`lake --version`)
- Operating system
- Steps to reproduce
- Expected vs actual behavior
- Error messages (if any)

---

## Example Workflows

### Complete First-Time Setup

```bash
# Install Lean 4 (see commands above)
elan --version

# Clone and set up project
mkdir -p ~/Documents/Projects && cd ~/Documents/Projects
git clone https://github.com/benbrastmckie/Logos.git
cd Logos/Theory

# Build (first time takes a while)
lake build
```

Then use the agent system:
```
Please help me:
1. Verify the Lean 4 setup is working
2. Explore the Theories/ directory structure
3. Run diagnostics on a sample proof file
```

### Working with Existing Proofs

```bash
cd ~/Documents/Projects/Logos/Theory
# Launch your AI assistant with the project
```

Ask about the project:
```
Review Theories/Modal/Logic.lean and explain the key theorems
and how they relate to Kripke semantics.
```

### Debugging Build Issues

```bash
cd ~/Documents/Projects/Logos/Theory
# Launch your AI assistant
```

```
I ran lake build and got an error.
Please diagnose the issue and suggest fixes.
```

---

## Troubleshooting

### Lean/Lake Issues

**"lake: command not found":**
- Ensure elan is installed
- Restart terminal after elan installation
- Check: `elan show` to see installed toolchains

**Build errors:**
- Run `lake clean` then `lake build`
- Ensure you're using the correct Lean version (check `lean-toolchain`)
- Download Mathlib cache: `lake exe cache get`

**Slow builds:**
- First builds are slow due to Mathlib compilation
- Use `lake exe cache get` to download prebuilt cache

### Lean LSP Issues

**MCP tools not working:**
- Ensure the lean-lsp MCP server is configured
- Check your AI assistant settings for MCP configuration
- Verify Lean project builds successfully first

---

## Next Steps

### Documentation

- **[Architecture](../architecture/system-overview.md)** - System architecture overview
- **[User Guide](user-guide.md)** - Comprehensive command reference
- **[OPENCODE.md](../../OPENCODE.md)** - Quick reference

### Project Documentation

- **[docs/](../../../docs/)** - Project documentation
- **[Theories/](../../../Theories/)** - Lean 4 source code

### Contributing

- **[GitHub Setup](https://docs.github.com/en/get-started)** - Git and GitHub basics
- Open issues for bugs or feature requests

---

[Back to Docs](../README.md)
