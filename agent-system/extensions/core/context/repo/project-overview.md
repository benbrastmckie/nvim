# Project Overview

## Purpose

This repository is a personal Neovim configuration (`init.lua`, `lua/neotex/core/`,
`lua/neotex/plugins/`, `after/ftplugin/`, lazy.nvim plugin specs). It also hosts an
agent-orchestration system (Claude Code and OpenCode) used to drive the configuration's own
development through a research -> plan -> implement -> complete task lifecycle.

## Two-Layer Extension Architecture

The agent-orchestration side of this repository uses a two-layer extension system:

- **Layer 1 -- Editor loader**: Manages which agent files, skills, rules, and context exist in
  the agent runtime directory. The extension picker triggers the loader, which copies files from
  extension sources under `agent-system/extensions/*/` into the runtime and regenerates the main
  configuration file.
- **Layer 2 -- Agent system** (`.claude/`): The runtime read by the AI coding assistant. It is a
  gitignored, disposable deploy artifact regenerated from the extension sources -- contains only
  the files that have been loaded by the editor loader. The assistant does not know about the
  extension system; it sees a standard directory structure. Hand-authoring under `.claude/**`
  directly is incorrect; edit the source store instead (see
  `.claude/rules/source-store-deploy-boundary.md`).

`.claude-extensions.json` resolves each extension's `source_dir`, the authoritative location to
edit for any change under a deployed `.claude/` path.

See `.claude/docs/architecture/extension-system.md` for the full two-layer architecture
documentation.

## Extensions Present

The extensions currently registered in `.claude-extensions.json` are:

- `core` -- task lifecycle, orchestration, meta-system tooling
- `nix` -- NixOS / Home Manager configuration support
- `nvim` -- Neovim configuration development support
- `lean` -- Lean 4 theorem proving (Mathlib, Lake builds)
- `memory` -- knowledge capture and retrieval (memory vault)
- `literature` -- paper/spec ingestion and search (`specs/literature/`)
- `email` -- AI-assisted email triage over Himalaya/notmuch

## Repository Structure

```
init.lua                      # Neovim entry point
lua/neotex/
├── core/                    # Core Neovim functionality
└── plugins/                 # Plugin configurations (lazy.nvim specs)
after/ftplugin/               # Filetype-specific settings

specs/                       # Task management
├── TODO.md                 # Task list (generated from state.json)
├── state.json              # Task state (machine source of truth)
└── {NNN}_{SLUG}/           # Task artifacts
    ├── reports/
    ├── plans/
    └── summaries/

.claude/                     # Claude Code configuration (deploy artifact, gitignored)
├── CLAUDE.md               # Generated agent-system reference
├── commands/                # Slash commands
├── skills/                  # Skill definitions
├── agents/                  # Agent definitions
├── rules/                   # Auto-applied rules
└── context/                 # Domain knowledge

agent-system/extensions/      # Extension SOURCE STORE (edit here, not .claude/)
└── {extension}/
    ├── manifest.json        # Extension metadata
    ├── agents/, skills/, rules/, context/, commands/, scripts/
    └── ...
```

## Task Lifecycle

Tasks move through `specs/TODO.md` and `specs/state.json` via status markers
(`[NOT STARTED]` -> `[RESEARCHING]`/`[RESEARCHED]` -> `[PLANNING]`/`[PLANNED]` ->
`[IMPLEMENTING]` -> `[COMPLETED]`, plus exception states `[BLOCKED]`, `[PARTIAL]`, `[HOLD]`, and
terminal states `[ABANDONED]`, `[EXPANDED]`). `/orchestrate` drives a task autonomously through
this lifecycle without confirmation gates; `/task`, `/revise`, `/review`, and `/todo` manage
tasks individually. See `.claude/CLAUDE.md`'s Command Reference for the full table.

## Related Documentation

- `CLAUDE.md` (project root) -- Neovim-specific coding standards (Lua style, project
  organization, documentation policy)
- `.claude/CLAUDE.md` -- generated agent-system reference (task management, command reference,
  extension routing)
- `.claude/docs/docs-README.md` -- architecture entry point for the agent system
- `agent-system/extensions/*/manifest.json` -- available extensions, their capabilities, and
  dependency declarations
