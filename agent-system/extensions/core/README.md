# Core Extension

Foundational system payload providing the base agent infrastructure for Claude Code. Unlike domain extensions (nix, neovim, formal), core is always active and requires no installation or loading. It supplies all commands, agents, rules, skills, scripts, hooks, context, and templates that power the task management and agent orchestration workflow.

## Overview

| Category | Count | Description |
|----------|-------|-------------|
| Commands | 15 | Full task lifecycle from creation through archival |
| Agents | 8 | Research, implementation, planning, review, meta, revision, spawn |
| Skills | 16 | Orchestration, team mode, utilities, and domain routing |
| Rules | 6 | Auto-applied rules for state, git, artifacts, workflows, errors |
| Scripts | 200 | Validation, memory, extension management, hooks, linting |
| Hooks | 11 | Session logging, notifications, validation, memory nudging |
| Context | 15+ dirs | Architecture, patterns, guides, schemas, workflows, reference |
| Docs | 23+ files | Standards documentation, architecture guides, templates |
| Templates | 3 | CLAUDE.md header, extension README template, settings.json |

## Always Active

Core is not a domain extension and is never loaded via the extension picker. It is the foundational layer that the extension loader itself depends on. All other extensions build upon core's commands, agents, and orchestration infrastructure. There is no `enable`/`disable` toggle -- core is always present.

## Commands

All 16 commands use checkpoint-based execution: GATE IN (preflight) -> DELEGATE (skill/agent) -> GATE OUT (postflight) -> COMMIT.

| Command | Usage | Description |
|---------|-------|-------------|
| `/task` | `/task "Description"` | Create, recover, expand, sync, or abandon tasks |
| `/research` | `/research N [focus]` | Research task(s), route by task type |
| `/plan` | `/plan N` | Create phased implementation plan(s) |
| `/implement` | `/implement N` | Execute plan(s) with phase resume support |
| `/todo` | `/todo` | Archive completed/abandoned tasks, sync metrics |
| `/meta` | `/meta` | Interactive system builder for .claude/ changes |
| `/review` | `/review` | Analyze codebase and create analysis reports |
| `/revise` | `/revise N` | Create new plan version or update description |
| `/errors` | `/errors` | Analyze error patterns, create fix plans |
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/refresh` | `/refresh` | Clean orphaned processes and old files |
| `/spawn` | `/spawn N` | Spawn new tasks to unblock a blocked task |
| `/merge` | `/merge` | Create pull/merge request for current branch |
| `/project-overview` | `/project-overview` | Interactive repo scan and project-overview.md generation |
| `/tag` | `/tag` | Create semantic version tag (user-only) |
| `/zulip` | `/zulip` | Fetch a Zulip thread via API and write formatted JSON to a file |

Multi-task syntax: `/research`, `/plan`, and `/implement` accept comma-separated and range task numbers (e.g., `/research 7, 22-24`). Flags like `--force`, `--fast`, `--hard` modify behavior.

## Agents

| Agent | Purpose |
|-------|---------|
| general-research-agent | General web/codebase research |
| general-implementation-agent | General file implementation |
| planner-agent | Implementation plan creation |
| meta-builder-agent | System building and meta tasks |
| code-reviewer-agent | Code quality assessment and review |
| reviser-agent | Plan revision with research synthesis |
| spawn-agent | Blocker analysis and task decomposition |

Agent definitions include an `agents/README.md` documenting the shared agent frontmatter standard.

## Architecture

```
core/
├── manifest.json              # Extension configuration
├── merge-sources/claudemd.md  # CLAUDE.md merge content (core has no EXTENSION.md -- see
│                               #   merge_targets.claudemd.source in manifest.json)
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── agents/                    # 8 agent definitions
│   ├── general-research-agent.md
│   ├── general-implementation-agent.md
│   ├── planner-agent.md
│   ├── meta-builder-agent.md
│   ├── code-reviewer-agent.md
│   ├── reviser-agent.md
│   ├── spawn-agent.md
│   └── README.md
│
├── commands/                  # 15 slash command definitions
│   ├── task.md, research.md, plan.md, implement.md
│   ├── todo.md, meta.md, review.md, revise.md
│   ├── errors.md, fix-it.md, refresh.md
│   ├── spawn.md, merge.md, project-overview.md, tag.md
│   └── (each defines preflight, delegation, postflight)
│
├── skills/                    # 10 skill wrappers
│   ├── skill-orchestrate/     # Autonomous lifecycle state machine (/orchestrate command)
│   ├── skill-meta/            # System building
│   ├── skill-status-sync/     # Atomic status updates
│   ├── skill-todo/            # Task archival
│   ├── skill-tag/             # Version tagging (user-only)
│   ├── skill-refresh/         # Process cleanup
│   ├── skill-reviser/         # Plan revision
│   ├── skill-spawn/           # Blocker decomposition
│   ├── skill-git-workflow/    # Scoped git commits
│   └── skill-fix-it/          # Tag scanning
│
├── rules/                     # 6 auto-applied rules
│   ├── artifact-formats.md
│   ├── error-handling.md
│   ├── git-workflow.md
│   ├── plan-format-enforcement.md
│   ├── state-management.md
│   └── workflows.md
│
├── scripts/                   # 200 utility scripts
│   ├── check-extension-docs.sh, export-to-markdown.sh
│   ├── install-extension.sh, uninstall-extension.sh
│   ├── memory-retrieve.sh, validate-*.sh
│   └── lint/
│
├── hooks/                     # 11 lifecycle hooks
│   ├── log-session.sh, post-command.sh
│   ├── memory-nudge.sh, subagent-postflight.sh
│   ├── validate-plan-write.sh, validate-state-sync.sh
│   ├── tts-notify.sh
│   └── wezterm-*.sh
│
├── context/                   # 15+ context directories
│   ├── architecture/, patterns/, guides/
│   ├── formats/, schemas/, standards/
│   ├── workflows/, processes/, templates/
│   ├── meta/, orchestration/, reference/
│   ├── repo/, troubleshooting/, checkpoints/
│   └── routing.md, validation.md, index.schema.json
│
├── docs/                      # Standards documentation
│   ├── README.md, architecture/, examples/
│   ├── guides/, reference/, templates/
│   └── docs-README.md
│
├── templates/                 # Scaffolding templates
│   ├── claudemd-header.md
│   ├── extension-readme-template.md
│   └── settings.json
│
├── systemd/                   # Systemd units
│   ├── claude-refresh.service
│   └── claude-refresh.timer
│
├── merge-sources/             # CLAUDE.md merge content
│   └── claudemd.md
│
└── root-files/                # Root-level config files
    ├── settings.json
    ├── settings.local.json
    └── .gitignore
```

## No Task-Type Routing

Core provides no task-type routing block in its manifest. This is intentional: core is not a domain extension and does not handle specific task types. The three core task types (`general`, `meta`, `markdown`) are hardcoded in the orchestrator's routing logic rather than declared via manifest routing entries. Domain extensions (nix, neovim, formal, etc.) declare their own routing blocks to register additional task types.

## Intentionally Omitted Sections

The following sections common to domain extension READMEs are omitted because they do not apply to core:

- **Installation**: Core is always active; no installation step exists.
- **MCP Tool Setup**: Core uses no MCP tools directly.
- **Language Routing**: Core has no domain-specific language routing.
- **Workflow**: Core defines the workflow infrastructure itself; individual command workflows are documented in each command definition.
- **Skill-Agent Mapping**: The full mapping table is in `.claude/CLAUDE.md` and would be redundant here.
- **Output Artifacts**: Artifacts are task-specific, not core-specific.
- **Key Patterns**: Patterns are documented in `context/patterns/` and `docs/`.

## Related Documentation

- `.claude/CLAUDE.md` - Agent system configuration and command reference (core's claudemd merge
  source is `agent-system/extensions/core/merge-sources/claudemd.md`, not an `EXTENSION.md` --
  core has none; see `docs/reference/standards/extension-slim-standard.md`'s "Resource-Only /
  Non-EXTENSION.md-Source Extensions" note)
- `.claude/docs/docs-README.md` - Standards documentation index
- `.claude/context/index.json` - Context discovery index
- `.claude-extensions.json` (project root) - Extension registry
