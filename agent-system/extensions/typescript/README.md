# TypeScript Extension

Generic, framework-agnostic TypeScript language, tooling, and configuration support: `tsconfig.json`
strictness and project references, module systems (ESM/CJS), runtime validation (Zod), and
`tsc`-based verification. Nothing in this extension's context tree references Astro, Vite,
React, Next.js, or Cloudflare — that content belongs to a framework-specific extension instead.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `typescript` | typescript-research-agent | TypeScript/tooling research |
| `typescript` | typescript-implementation-agent | TypeScript implementation |

## Installation

Loaded via the extension picker. Once loaded, `typescript` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via
`/orchestrate`) with `task_type: "typescript"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typescript-research | typescript-research-agent | TypeScript/tooling research |
| skill-typescript-implementation | typescript-implementation-agent | TypeScript implementation |

## File Inventory

```
typescript/
  manifest.json                                          # Name, version, provides, routing, merge_targets, hard_contracts
  EXTENSION.md                                           # CLAUDE.md source content
  README.md                                              # This file
  index-entries.json                                     # Context index entries
  opencode-agents.json                                   # OpenCode agent definitions
  agents/typescript-research-agent.md                    # Research agent
  agents/typescript-implementation-agent.md              # Implementation agent (tsc verification loop)
  skills/skill-typescript-research/SKILL.md              # Thin wrapper skill
  skills/skill-typescript-implementation/SKILL.md        # Thin wrapper skill
  rules/typescript-rules.md                              # Auto-applied rule (*.ts, *.tsx, package.json, tsconfig*.json)
  scripts/typescript-verify.sh                           # verification-stage lifecycle hook
  context/contracts/typescript-adversarial-verification.md  # hard_contracts override (compiler-as-oracle)
  context/project/typescript/README.md                   # Generic context tree index
  context/project/typescript/standards/typescript-style-guide.md
  context/project/typescript/patterns/zod-validation-patterns.md
  context/project/typescript/patterns/path-alias-patterns.md
  context/project/typescript/domain/tsconfig-reference.md
  context/project/typescript/domain/module-systems.md
  context/project/typescript/tools/tsc-cli-guide.md
  context/project/typescript/tools/package-manager-detection.md
```

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `typescript` | WebSearch, WebFetch, Read, Bash (read-shaped probes) | Read, Write, Edit, Bash (`tsc --noEmit`, package-manager scripts) |

## Verification

```bash
tsc --noEmit    # Full typecheck gate, run after each sub-step
```

The implementation agent runs `tsc --noEmit` (or the project's own declared typecheck command)
after each sub-step and blocks on failures. The `verification`-stage lifecycle hook
(`scripts/typescript-verify.sh`) additionally runs automatically after every dispatch's
artifacts are validated, reporting `ran_pass`/`ran_fail`/`skipped_no_command` per sub-check with
an honest-degrade guarantee: it never reports a pass when no typecheck or test command exists to
run.

### Verifying This Extension's Own Deploy (Scratch-Target Procedure)

To confirm this extension's four `merge_targets` end-to-end without touching any real
repository, deploy it into a disposable scratch git repository (created and destroyed entirely
under a session scratchpad — never this repository, the source store, or any
`.claude-extensions.json`-registered target) using the same headless Lua call
`deploy-headless.sh` itself uses:

```bash
nvim --headless \
  -c "lua local ext_config = require('neotex.plugins.ai.shared.extensions.config'); \
      local ext_init = require('neotex.plugins.ai.shared.extensions.init'); \
      local manager = ext_init.create(ext_config.claude()); \
      manager.load('core', {confirm=false, force=true, project_dir=SCRATCH}); \
      manager.load('typescript', {confirm=false, force=true, project_dir=SCRATCH}); \
      print('DEPLOY_OK')" \
  -c "qa!"
```

run from this config repository's own working directory (so the
`neotex.plugins.ai.shared.extensions.*` modules resolve), with `project_dir` pointed at
`SCRATCH`. Confirm the four merge targets directly against the scratch tree:

1. **Installed files** — `SCRATCH/.claude/` contains both agents, both skill directories,
   `rules/typescript-rules.md`, `scripts/typescript-verify.sh`, the contract file, and the full
   8-file `context/project/typescript/` subtree, all correctly scoped under `.claude/` with no
   duplicate at the scratch root.
2. **`claudemd`** — a `## TypeScript Extension` section appears in `SCRATCH/.claude/CLAUDE.md`.
3. **`index`** — `SCRATCH/.claude/context/index.json` carries all 9 `typescript`-tagged entries,
   matching `index-entries.json`.
4. **`opencode_json` — gated by a `.managed` marker**: without a `SCRATCH/opencode.json.managed`
   file present, `merge.lua`'s `generate_opencode_json` (Step 1.2, managed/unmanaged gating)
   returns `ok=true` and **writes no file** — this is the function's own documented no-op path,
   not a defect. Create `SCRATCH/opencode.json.managed` (an empty file is sufficient) and
   re-run the load above to observe this target: the regenerated `opencode.json` then carries
   both `typescript-research` and `typescript-implementation` agent keys. A tester who skips
   creating the marker will see no `opencode.json` at all and may wrongly conclude this merge
   target is broken.

Delete the scratch repository and every file it generated once done.

## Deliberately Omitted

- **No `settings-fragment.json`**: nothing MCP- or permission-specific to configure for generic
  TypeScript work.
- **No `templates/`**: a generic TypeScript project has no fixed shape to scaffold, unlike a
  framework extension's page/component templates.
- **No `mcp-fragment.json`**: no TypeScript MCP server in wide use comparable to `mcp-nixos`.

## References

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [TypeScript release notes](https://www.typescriptlang.org/docs/handbook/release-notes/overview.html)
- [`@typescript-eslint` rules](https://typescript-eslint.io/rules/)
- [Zod documentation](https://zod.dev/)
