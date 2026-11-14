# Deploy Verification Evidence: `typescript` Extension

- **Task**: 621
- **Phase**: 2 (Execute the Deploy Verification and Record the Evidence)
- **Date**: 2026-11-14

## Procedure

A disposable scratch git repository was created under this session's own scratchpad directory
(outside this repository, the source store, and any `.claude-extensions.json`-registered target):

```
SCRATCH=/tmp/claude-1000/-home-benjamin--config-nvim/d3af9f9c-8356-4b06-8a1b-c27446e1f70e/scratchpad/ts-ext-verify-621
git init && git commit (one README.md file)
```

`core` then `typescript` were loaded into it via the same headless Lua call
`deploy-headless.sh` itself uses:

```
nvim --headless \
  -c "lua local ext_config = require('neotex.plugins.ai.shared.extensions.config'); \
      local ext_init = require('neotex.plugins.ai.shared.extensions.init'); \
      local manager = ext_init.create(ext_config.claude()); \
      manager.load('core', {confirm=false, force=true, project_dir=SCRATCH}); \
      manager.load('typescript', {confirm=false, force=true, project_dir=SCRATCH}); \
      print('DEPLOY_OK')" \
  -c "qa!"
```

run from this repository's own working directory (so the `neotex.plugins.ai.shared.extensions.*`
modules resolve from this config's `lua/` tree), with `project_dir` pointed at `SCRATCH`.

Run once with no `opencode.json.managed` marker present, then again after creating that marker
in `SCRATCH`, per the `opencode_json` gating behavior documented below.

## Results

### `manager.load` outcome

Both runs printed `DEPLOY_OK` (exit 0), confirming the loader completed without error for both
`core` and `typescript` against the scratch target.

### Merge target 1 — Expected `.claude/` files

Confirmed present, correctly scoped under `SCRATCH/.claude/` with no duplicate at the scratch
root:

- `.claude/agents/typescript-research-agent.md`
- `.claude/agents/typescript-implementation-agent.md`
- `.claude/skills/skill-typescript-research/` (directory)
- `.claude/skills/skill-typescript-implementation/` (directory)
- `.claude/rules/typescript-rules.md`
- `.claude/scripts/typescript-verify.sh`
- `.claude/context/contracts/typescript-adversarial-verification.md`
- `.claude/context/project/typescript/README.md`
- `.claude/context/project/typescript/standards/typescript-style-guide.md`
- `.claude/context/project/typescript/patterns/zod-validation-patterns.md`
- `.claude/context/project/typescript/patterns/path-alias-patterns.md`
- `.claude/context/project/typescript/domain/tsconfig-reference.md`
- `.claude/context/project/typescript/domain/module-systems.md`
- `.claude/context/project/typescript/tools/tsc-cli-guide.md`
- `.claude/context/project/typescript/tools/package-manager-detection.md`

16 installed files total (2 agents + 2 skill dirs + 1 rules file + 1 hook script + 1 contract
file + 8-file `context/project/typescript/` subtree). `find "$SCRATCH" -maxdepth 1
-iname "*typescript*"` returned nothing — no stray duplicate at the target root.

**Result: PASS.**

### Merge target 2 — Merged `CLAUDE.md` section (`claudemd`)

`SCRATCH/.claude/CLAUDE.md` contains a `## TypeScript Extension` section, sourced from
`EXTENSION.md`, carrying the Language Routing table, the Skill-Agent Mapping table, the
Commands note, and the Verification subsection (including the lifecycle-hook description) intact.

**Result: PASS.**

### Merge target 3 — Merged `index.json` entries (`index`)

`SCRATCH/.claude/context/index.json` carries all 9 `typescript`-subdomain entries (8
`project/typescript/**` context files + 1 `contracts/typescript-adversarial-verification.md`),
matching `index-entries.json`'s own 9 entries path-for-path and `line_count`-for-`line_count`
(53, 96, 98, 62, 81, 67, 66, 64, 57).

**Result: PASS.**

### Merge target 4 — Merged `opencode.json` (`opencode_json`)

**First run (no `opencode.json.managed` marker present in `SCRATCH`)**: `manager.load` reported
success (`DEPLOY_OK`) and `generate_opencode_json` returned `ok=true`, but **no `opencode.json`
file was written** — confirmed by `test -f "$SCRATCH/opencode.json"` returning false. This is
`merge.lua`'s own documented gating behavior (Step 1.2: Managed/unmanaged gating — `if
vim.fn.filereadable(target_path .. ".managed") ~= 1 then return true, nil, {} end`), not a
defect: a target repository that has not opted in via the marker file is correctly left
untouched.

**After creating `SCRATCH/opencode.json.managed` and re-running the identical `manager.load`
call**: `SCRATCH/opencode.json` now exists and its `agent` map carries both
`typescript-research` and `typescript-implementation` keys, alongside the other loaded
extensions' agent keys (`general-research`, `general-implementation`, `meta-builder`, `spawn`,
`reviser`, `plan`, `code-reviewer`, `task-planner`, `build`), sourced from
`opencode-agents.json`.

**Result: PASS (gating behavior confirmed correct, not a defect; marker required before this
target can be observed at all).**

## Cleanup

The scratch repository and every file it generated (including `opencode.json.managed` and the
regenerated `opencode.json`) were deleted after this evidence was recorded. `git status --short`
in this repository shows no stray artifact from the test — the scratch work happened entirely
under the session scratchpad, outside this repository's working tree.

## Summary

All four merge targets (`.claude/` installed files, `claudemd`, `index`, `opencode_json`)
confirmed working end-to-end against a disposable scratch target, reproducing and re-attributing
to this task's own artifacts the same test the research report performed. The
`opencode.json.managed` gating behavior is the one non-obvious mechanism surfaced; it is
durably recorded in the extension's own `README.md` as of Phase 3 of this task's plan.
