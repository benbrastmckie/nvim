# Implementation Summary: Task #169

**Completed**: 2026-03-10
**Duration**: ~3 hours

## Changes Made

Established clean core/extension separation for both .claude/ and .opencode/ agent systems. Core systems now contain only language-agnostic elements, with domain-specific content provided by extensions that are loaded on-demand.

### Key Changes

1. **Core System Cleanup**
   - Removed 27 extension-provided agents from core
   - Removed 28 extension-provided skills from core
   - Removed 5 extension-provided rules from core
   - Removed 13 extension-provided context directories from core

2. **index.json as Adaptive Registry**
   - Rebuilt index.json to contain only 10 core entries
   - Extensions merge their entries at load time
   - All extension index-entries.json files use canonical `project/*` paths

3. **Post-Load Verification**
   - Created verify.lua module for integrity checking
   - Verification runs automatically after extension load
   - Checks agents, skills, rules, context files, section injection, index merge

4. **State Tracking Fix**
   - extensions.json now stores relative paths (not absolute)
   - Enables project portability

5. **Validation Script**
   - Created validate-wiring.sh for CI/manual verification
   - Validates core system integrity
   - Validates extension wiring when loaded

## Files Modified

### Created
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - Post-load verification module
- `.claude/scripts/validate-wiring.sh` - Wiring validation script
- `.claude/extensions/README.md` - Extension documentation with path format requirements

### Modified
- `.claude/CLAUDE.md` - Updated to core-only routing, notes about extensions
- `.claude/context/index.json` - Rebuilt with 10 core entries (was 97)
- `.opencode/README.md` - Updated skill-to-agent mapping, language routing
- `.opencode/context/index.json` - Rebuilt with 10 core entries (was 32)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Added verification, relative path storage
- `specs/169_verify_agent_systems_wired_after_reload/plans/implementation-001.md` - Phase markers

### Deleted (moved to extensions)
- 27 agent files from .claude/agents/ and .opencode/agent/subagents/
- 28 skill directories from .claude/skills/ and .opencode/skills/
- 5 rule files from .claude/rules/ and .opencode/rules/
- 13 context directories from .claude/context/project/ and .opencode/context/project/

## Verification

- Core validation: 36 checks passed, 0 warnings, 0 failed
- Both .claude/ and .opencode/ systems validated
- validate-wiring.sh script runs successfully
- Extension load/unload works with new verification

## Notes

- Extensions must be loaded via `<leader>ac` (Claude) or `<leader>ao` (OpenCode) after checkout
- The extension loader will copy files, merge index entries, and inject CLAUDE.md sections
- Post-load verification catches missing files and failed merges
- Path normalization happens at extension source (index-entries.json), not at merge time
