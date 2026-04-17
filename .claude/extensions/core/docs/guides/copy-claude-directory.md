# Copy .claude/ Directory Guide

[Back to Docs](../README.md) | [User Installation](user-installation.md) | [Commands Reference](../commands/README.md)

Instructions for copying the `.claude/` agent system directory to a new project.

---

## What is the .claude/ System?

The `.claude/` directory provides an agent system for Claude Code that enhances your development workflow with:

- **Task Management Commands**: `/task`, `/research`, `/plan`, `/implement` - structured workflow for development tasks
- **Specialized Skills**: Language-specific agents available via extensions (LaTeX, Typst, and more)
- **Context Files**: Domain knowledge loaded per task type via the extension system
- **State Tracking**: TODO.md and state.json for persistent task tracking across sessions
- **Extensible Architecture**: Easy to add new domain contexts for additional specializations

Once installed, you can create numbered tasks, conduct research, create implementation plans, and execute them with automatic progress tracking.

---

## Prerequisites

Before proceeding, ensure you have:

1. **Git installed**
   ```bash
   git --version
   ```
   If not installed, see [Git Installation Guide](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

2. **Claude Code installed and authenticated**
   ```bash
   claude --version
   claude auth status
   ```

3. **A target project directory**
   - This should be the root directory where you run Claude Code
   - The `.claude/` directory will be placed here

---

## What to Copy

### Core Files (Always Copy)

These are the essential files for the system to function:

```
.claude/
├── CLAUDE.md                    # Main configuration
├── commands/                    # Slash commands
├── skills/                      # Skill definitions
├── agents/                      # Agent definitions
├── rules/                       # Auto-applied rules
├── context/
│   ├── core/                   # Core patterns and standards
│   └── project/               # Project domain context
├── docs/                        # Documentation
└── settings.json               # Claude settings
```

### Task State Files (Fresh Start)

For a fresh installation, initialize these files:

**specs/state.json**:
```json
{
  "next_project_number": 1,
  "active_projects": [],
  "repository_health": {
    "last_assessed": null,
    "status": "healthy"
  }
}
```

**specs/TODO.md**:
```markdown
# TODO

## Tasks

(No tasks yet)
```

---

## What to Customize

After copying, customize these files for your project:

### 1. CLAUDE.md

Update the project structure section to match your project:

```markdown
## Project Structure

src/
├── core/                 # Core functionality
├── modules/              # Feature modules
├── utils/                # Utility functions
└── main.py               # Entry point
```

### 2. Context Files

The `context/project/` directory contains domain knowledge files. Add context specific to your project:
- Language patterns and conventions
- Framework or library guides
- Tool-specific configuration patterns

Customize or extend based on your specific project stack.

### 3. Rules

Extension rules apply to specific file patterns (e.g., `src/**/*.py`). Adjust patterns to match your project paths.

---

## Extension Points

### Adding New Domain Contexts

To add a new domain (e.g., for a specific framework):

1. Create directory: `.claude/context/project/your-domain/`
2. Add context files following the existing patterns
3. Create domain-specific agents if needed
4. Update routing in `skill-orchestrator/SKILL.md`

See [Adding Domains Guide](adding-domains.md) for detailed instructions.

### Adding New Languages

To support a new language type:

1. Add entry to routing table in `skill-orchestrator/SKILL.md`
2. Create `skill-{language}-research/SKILL.md`
3. Create `skill-{language}-implementation/SKILL.md`
4. Create corresponding agent files
5. Update `CLAUDE.md` documentation

---

## Installation Instructions

### macOS / Linux

```bash
# Navigate to a temporary location
cd /tmp

# Clone the repository (replace with your source)
git clone https://github.com/your-repo.git source-repo

# Copy .claude/ to your project directory
cp -r source-repo/.claude /path/to/your/project/

# Initialize specs directory
mkdir -p /path/to/your/project/specs
echo '{"next_project_number":1,"active_projects":[]}' > /path/to/your/project/specs/state.json
echo '# TODO\n\n## Tasks\n' > /path/to/your/project/specs/TODO.md

# Clean up
rm -rf source-repo
```

### Windows (PowerShell)

```powershell
cd $env:TEMP

git clone https://github.com/your-repo.git source-repo

Copy-Item -Recurse source-repo\.claude C:\path\to\your\project\

# Initialize specs
New-Item -ItemType Directory -Force -Path C:\path\to\your\project\specs
'{"next_project_number":1,"active_projects":[]}' | Out-File C:\path\to\your\project\specs\state.json
'# TODO`n`n## Tasks`n' | Out-File C:\path\to\your\project\specs\TODO.md

Remove-Item -Recurse -Force source-repo
```

---

## Verification

After copying, verify the installation:

### 1. Check Directory Structure

```bash
ls -la .claude/
```

You should see:
- `commands/` - Slash command definitions
- `skills/` - Specialized agent skills
- `agents/` - Agent definitions
- `rules/` - Automatic behavior rules
- `context/` - Domain knowledge

### 2. Restart Claude Code

```
/exit
```

Then start again:
```bash
claude
```

### 3. Test Commands

```
/task "Test task creation"
```

---

## Quick Start

After installation:

```
/task "Add search functionality"      # Create a task
/research 1                           # Research implementation options
/plan 1                               # Create implementation plan
/implement 1                          # Execute the plan
/todo                                 # Archive completed tasks
```

---

## Troubleshooting

### Commands not available

1. Ensure you restarted Claude Code
2. Verify you're in the correct directory
3. Check that `.claude/commands/` contains `.md` files

### Language routing issues

Verify `skill-orchestrator/SKILL.md` has correct routing for your language.

### Missing context

Ensure `context/project/` was copied correctly.

---

## Next Steps

- **[Adding Domains Guide](adding-domains.md)** - Extend for new domains
- **[Commands Reference](../commands/README.md)** - Full command documentation
- **[User Installation Guide](user-installation.md)** - Complete setup guide

---

[Back to Docs](../README.md) | [User Installation](user-installation.md) | [Commands Reference](../commands/README.md)
