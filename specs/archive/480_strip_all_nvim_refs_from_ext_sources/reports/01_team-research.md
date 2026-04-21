# Research Report: Task #480

**Task**: Comprehensively strip ALL remaining nvim/neovim/neotex/VimTeX references from extension sources
**Date**: 2026-04-18
**Mode**: Team Research (4 teammates)
**Session**: sess_1776559563_3d29db

## Summary

Comprehensive audit identifies **~75 actionable nvim/neovim/neotex/VimTeX references** across 3 extension directories (core, latex, memory) and their deployed copies. The task description correctly identifies Priority 1 items but has two scope gaps: (1) memory files are in `extensions/memory/`, not `extensions/core/`, and (2) `settings.local.json` and `core/README.md` contain undocumented references. The unconditional overwrite behavior of the extension loader means every source reference re-contaminates deployed copies on reload, making source-level fixes essential.

## Key Findings

### Priority 1: Core + Latex Extension Sources (17 lines, 6 files) -- MUST FIX

All confirmed present and untouched by tasks 478/479:

| File | Lines | Action | Deployed Copy |
|------|-------|--------|---------------|
| `extensions/latex/EXTENSION.md` | 17-22 | Remove entire VimTeX Integration subsection (root cause of CLAUDE.md contamination) | Part of CLAUDE.md generation |
| `extensions/core/agents/code-reviewer-agent.md` | 36-38 | Remove "Load For Neovim Code" block | `.claude/agents/code-reviewer-agent.md` |
| `extensions/core/docs/README.md` | 120, 191 | Remove nvim table row + "moved to nvim" tombstone | `.claude/docs/README.md` |
| `extensions/core/docs/docs-README.md` | 18, 19, 56, 57 | Remove 4 "moved to nvim extension" tombstone entries | `.claude/docs/docs-README.md` |
| `extensions/core/scripts/validate-wiring.sh` | 240-245 | Remove nvim) case block | `.claude/scripts/validate-wiring.sh` |
| `extensions/core/templates/extension-readme-template.md` | 26 | Remove "nvim, " from example list | `.claude/templates/extension-readme-template.md` |

### Priority 2: Memory Extension Examples (~26 refs, 7 files) -- SHOULD FIX

Files are in `extensions/memory/` (NOT `extensions/core/` as task description states):

| File | Refs | Action | Deployed Copy |
|------|------|--------|---------------|
| `extensions/memory/skills/skill-memory/SKILL.md` | 10 | Replace neovim/telescope topic examples with python/libs/requests | `.claude/skills/skill-memory/SKILL.md` |
| `extensions/memory/context/project/memory/learn-usage.md` | 12 | Replace neovim topic paths with python examples | `.claude/context/project/memory/learn-usage.md` |
| `extensions/memory/context/project/memory/memory-setup.md` | 1 | Replace MEM-neovim-lsp slug | `.claude/context/project/memory/memory-setup.md` |
| `extensions/memory/context/project/memory/knowledge-capture-usage.md` | 1 | Replace neovim example + associated context | `.claude/context/project/memory/knowledge-capture-usage.md` |
| `extensions/memory/context/project/memory/domain/memory-reference.md` | 1 | Replace topic path | `.claude/context/project/memory/domain/memory-reference.md` |
| `extensions/memory/commands/learn.md` | 1 | Replace ~/notes/neovim/ path | `.claude/commands/learn.md` |
| `extensions/memory/data/.memory/README.md` | 3 | Replace MEM-neovim examples | No deployed copy |

**Replacement strategy**: Use `python/libs/requests` as canonical topic path, `MEM-project-code-patterns` as canonical slug, `~/notes/python/` as canonical directory. Consistency across all files is critical.

### Priority 3: Build Tool References (5 refs, 4 files) -- NUANCED

| File | Lines | Action | Rationale |
|------|-------|--------|-----------|
| `extensions/latex/context/.../compilation-guide.md` | 222 | Remove "Neovim with VimTeX" from editor list | No deployed copy outside extension |
| `extensions/typst/context/.../compilation-guide.md` | 58-64 | Replace "Neovim Integration" section with generic "Editor Integration" | No deployed copy outside extension |
| `extensions/core/context/standards/postflight-tool-restrictions.md` | 74 | **KEEP** -- functional example of prohibited command | `.claude/context/standards/postflight-tool-restrictions.md` |
| `extensions/core/scripts/lint/lint-postflight-boundary.sh` | 6, 100 | **KEEP** -- functional regex pattern for lint detection | `.claude/scripts/lint/lint-postflight-boundary.sh` |

### Gaps Discovered by Critic (not in task description)

| File | Lines | Type | Recommendation |
|------|-------|------|----------------|
| `extensions/core/README.md` | 3, 158 | "neovim" in example domain extension lists | Low priority -- informational, does not deploy |
| `extensions/core/docs/architecture/extension-system.md` | 163, 513 | "VimTeX integration" in latex manifest description | Low priority -- factually accurate description |
| `extensions/core/systemd/claude-refresh.service` | 9 | Hardcoded `%h/.config/nvim/` path | Medium priority -- broken for non-nvim deployments |
| `extensions/core/root-files/settings.local.json` | 16-52 | 14 historical nvim migration `mv` commands | Medium priority -- stale migration commands that contaminate other projects |
| `extensions/memory/README.md` | multiple | ~8 neovim topic examples | Low priority -- extension README, does not deploy |
| `extensions/memory/data/.memory/index.md` | multiple | 2 neovim refs in index | Low priority -- data template |

### Latex Extension Additional References (not in priorities)

| File | Lines | Type | Recommendation |
|------|-------|------|----------------|
| `extensions/latex/manifest.json` | 4 | "VimTeX integration" in description | Replace with "latexmk/pdflatex toolchain" |
| `extensions/latex/README.md` | 3, 33, 37-40, 56 | VimTeX keymaps section, VimTeX link | Keep -- this IS the latex extension's own README |
| `extensions/latex/context/.../README.md` | 9 | "VimTeX integration" in tools list | Replace with generic |

## Synthesis

### Conflicts Resolved

1. **postflight-tool-restrictions.md and lint-postflight-boundary.sh**: Teammates A and B agree these are functional code that should be kept. Teammate D suggests replacing `nvim --headless` with `helix --headless`. **Resolution**: Keep as-is. The `nvim --headless` pattern in lint regex is a detection rule; removing it creates false negatives. The postflight restrictions table uses it as a concrete example. These are legitimate functional references, not contamination.

2. **Memory extension location**: Task description says files are in `extensions/core/`. Teammates B, C, and D all confirm they are in `extensions/memory/`. **Resolution**: Implementation must target `extensions/memory/`, not `extensions/core/`.

3. **settings.local.json**: Teammate D identifies 14 stale migration commands as a contamination vector. Not in task description. **Resolution**: Include as a new Priority 1 item -- these actively contaminate other projects on extension load.

4. **core/README.md neovim refs**: Teammate C identifies lines 3 and 158. Not in any priority. **Resolution**: Low priority -- file is the extension's own README and does not deploy to other projects.

5. **latex/manifest.json VimTeX description**: **Resolution**: Include in Priority 1 -- the manifest description feeds into extension-system.md examples and CLAUDE.md generation.

### Gaps Identified

1. **No prevention mechanism exists**: After 3 tasks (478, 479, 480), there is still no automated check to prevent re-contamination. Teammate D recommends extending `check-extension-docs.sh` with a `check_core_purity()` function.

2. **Typst extension not in task scope**: The typst compilation guide has a full "Neovim Integration" section (lines 58-64) that wasn't explicitly listed in task priorities but should be fixed.

3. **settings.local.json migration commands**: Completely missed by all previous tasks. These are stale `mv` commands that have already executed but still expose nvim-specific paths.

### Recommendations

**Implementation approach**: Fix sources first, then mirror to deployed copies. Use `grep -riE` verification after each priority level to confirm zero remaining references.

**Suggested phase structure**:
- Phase 1: Priority 1 source fixes (6 files + settings.local.json + latex/manifest.json)
- Phase 2: Priority 2 memory extension fixes (7 files with consistent replacements)
- Phase 3: Priority 3 compilation guide fixes (2 files)
- Phase 4: Mirror ALL source changes to deployed copies
- Phase 5: Add `check_core_purity()` prevention to check-extension-docs.sh
- Phase 6: Verification grep

**Files to KEEP unchanged** (functional references):
- `extensions/core/context/standards/postflight-tool-restrictions.md` (line 74)
- `extensions/core/scripts/lint/lint-postflight-boundary.sh` (lines 6, 100)
- `extensions/core/README.md` (lines 3, 158 -- does not deploy)
- `extensions/latex/README.md` (entire file -- extension's own docs)

**Verification command** (expanded from task description):
```bash
grep -riE 'nvim|neovim|neotex|vimtex' \
  .claude/extensions/core/ \
  .claude/extensions/latex/ \
  .claude/extensions/memory/ \
  --include='*.md' --include='*.sh' --include='*.json' \
  | grep -v 'extensions/core/README.md' \
  | grep -v 'extensions/core/EXTENSION.md' \
  | grep -v 'extensions/latex/README.md' \
  | grep -v 'lint-postflight-boundary.sh' \
  | grep -v 'postflight-tool-restrictions.md'
```
Expected: zero results.

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary (P1 audit) | completed | high | Detailed per-file line-by-line catalog of all 17 Priority 1 references |
| B | Alternatives (P2-3 audit) | completed | high | 24 memory refs cataloged with consistent replacement strategy; deploy mapping |
| C | Critic | completed | high | Found memory files in wrong extension; discovered core/README.md and systemd gaps |
| D | Horizons | completed | high | Identified settings.local.json contamination vector; prevention strategy |

## References

- Zed post-reload audit: `/home/benjamin/.config/zed/specs/065_strip_nvim_references_post_sync/reports/04_post-reload-diff-review.md`
- Task 478 summary: `specs/478_editor_agnostic_extension_docs/summaries/01_editor-agnostic-docs-summary.md`
- Task 479 report: `specs/479_fix_remaining_nvim_refs_in_core_ext/reports/01_nvim-refs-audit.md`
- Teammate A findings: `specs/480_strip_all_nvim_refs_from_ext_sources/reports/01_teammate-a-findings.md`
- Teammate B findings: `specs/480_strip_all_nvim_refs_from_ext_sources/reports/01_teammate-b-findings.md`
- Teammate C findings: `specs/480_strip_all_nvim_refs_from_ext_sources/reports/01_teammate-c-findings.md`
- Teammate D findings: `specs/480_strip_all_nvim_refs_from_ext_sources/reports/01_teammate-d-findings.md`
