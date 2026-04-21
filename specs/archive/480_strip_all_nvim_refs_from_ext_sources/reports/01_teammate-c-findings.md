# Teammate C: Critic Findings - Task 480

**Role**: Critic - Verify completeness against Zed audit
**Completed**: 2026-04-18
**Method**: Comprehensive grep across `.claude/extensions/core/` and `.claude/extensions/latex/`, cross-check vs Zed audit report 04 and task 479 summary.

---

## Key Findings

### Critical Gap: Memory Extension is NOT in `core`, it's in `memory`

The task 480 description refers to memory documentation examples in `extensions/core/`. This is **incorrect** -- those files live in `.claude/extensions/memory/`, not `.claude/extensions/core/`. They are:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` (10 neovim refs)
- `.claude/extensions/memory/context/project/memory/learn-usage.md` (12 refs)
- `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md` (1 ref)
- `.claude/extensions/memory/context/project/memory/memory-setup.md` (1 ref)
- `.claude/extensions/memory/context/project/memory/domain/memory-reference.md` (1 ref)
- `.claude/extensions/memory/commands/learn.md` (1 ref)
- `.claude/extensions/memory/README.md` (8 refs)
- `.claude/extensions/memory/data/.memory/README.md` (3 refs)
- `.claude/extensions/memory/data/.memory/20-Indices/index.md` (2 refs)

None of these appear in the task 480 description. They ARE documented in the Zed audit as Category B (illustrative examples).

### Critical Gap: Deployed agents in `.claude/agents/` NOT in any priority

The Zed audit Category A mentions `agents/code-reviewer-agent.md` (3 lines). But the deployed nvim extension agents are completely missing from the priority list:
- `.claude/agents/neovim-implementation-agent.md` -- entire file is nvim-specific (~40+ nvim refs)
- `.claude/agents/neovim-research-agent.md` -- entire file is nvim-specific (~25+ nvim refs)

These are **deployed copies of the nvim extension's agents** and are legitimate content for THIS neovim repo. However, the task 480 description only mentions `extensions/core/` and `extensions/latex/`. These agents are in `.claude/agents/`, not in extensions/core or extensions/latex, so they are out of scope for this task. But they should be noted for clarity.

### VimTeX in `docs/architecture/extension-system.md` Not Listed

Both the source (`extensions/core/docs/architecture/extension-system.md:163,513`) and deployed copy (`.claude/docs/architecture/extension-system.md:163,513`) contain `"LaTeX document development with VimTeX integration"`. This is the **latex manifest description** embedded in the extension-system.md document as an example. It is NOT listed in the task 480 priorities -- a minor gap, but likely intentional (the description is factually correct for the latex extension).

### systemd Path: Both Source and Deployed Are Identical

Both `.claude/extensions/core/systemd/claude-refresh.service:9` and `.claude/systemd/claude-refresh.service:9` contain:
```
ExecStart=%h/.config/nvim/.claude/scripts/claude-refresh.sh --force
```
This is listed in the Zed audit as Priority 1 item 6 ("Fix path to zed-local script"), but the task 480 description does NOT mention it. The path is hardcoded to `.config/nvim/` which is nvim-repo-specific. However, this path is meaningless/broken for non-nvim deployments regardless.

### What Tasks 478/479 Did vs. What Remains

| File | 478 Fixed | 479 Fixed | Still Exists |
|------|-----------|-----------|--------------|
| templates/claudemd-header.md | No | Yes (neotex -> extension loader) | Clean |
| context/guides/extension-development.md | Yes (leader->picker) + No | Yes (Neovim Lua loader) | Clean |
| docs/architecture/extension-system.md | No | Yes (Neovim Lua Loader) | VimTeX in example JSON |
| context/architecture/system-overview.md | No | Yes (neovim -> nix in example) | Clean |
| docs/architecture/system-overview.md | No | Yes (neovim -> nix in example) | Clean |
| merge-sources/claudemd.md | No | Yes (neovim removed from list) | Clean |
| context/meta/meta-guide.md | No | Yes (dup path fix) | Clean |
| extensions/latex/EXTENSION.md | No | No | **VimTeX section + leader bindings** |
| extensions/core/agents/code-reviewer-agent.md | No | No | **"Load For Neovim Code" block** |
| extensions/core/docs/README.md | No | No | **nvim row + "moved to nvim" note** |
| extensions/core/docs/docs-README.md | No | No | **"moved to nvim extension" x4** |
| extensions/core/scripts/validate-wiring.sh | No | No | **nvim) case block** |
| extensions/core/templates/extension-readme-template.md | No | No | **"nvim" in example list** |

Tasks 478 and 479 together fixed approximately 10 references, primarily in guides and architecture docs. They did NOT touch any of the Priority 1 items listed in task 480.

---

## Complete Grep Results Summary

### `.claude/extensions/core/` -- All Matches

| File | Line | Content |
|------|------|---------|
| `templates/extension-readme-template.md` | 26 | `Complex extensions (e.g., filetypes, lean, formal, nvim, nix, web...)` |
| `docs/docs-README.md` | 18 | `(moved to nvim extension: project/neovim/guides/neovim-integration.md)` |
| `docs/docs-README.md` | 19 | `(moved to nvim extension: project/neovim/guides/tts-stt-integration.md)` |
| `docs/docs-README.md` | 56 | `Neovim Integration - Moved to nvim extension: .claude/extensions/nvim/...` |
| `docs/docs-README.md` | 57 | `TTS/STT Integration - Moved to nvim extension: .claude/extensions/nvim/...` |
| `docs/architecture/extension-system.md` | 163 | `"description": "LaTeX document development with VimTeX integration"` |
| `docs/architecture/extension-system.md` | 513 | `[x] latex - LaTeX document development with VimTeX integration` |
| `docs/README.md` | 120 | `nvim \| Neovim/Lua \| neovim-research-agent, neovim-implementation-agent` |
| `docs/README.md` | 191 | `Neovim Integration - Moved to nvim extension: extensions/nvim/...` |
| `systemd/claude-refresh.service` | 9 | `ExecStart=%h/.config/nvim/.claude/scripts/claude-refresh.sh --force` |
| `scripts/validate-wiring.sh` | 240 | `nvim)` |
| `scripts/validate-wiring.sh` | 241 | `validate_agent_exists "$system_dir/$agents_subdir" "neovim-research-agent"` |
| `scripts/validate-wiring.sh` | 242 | `validate_agent_exists "$system_dir/$agents_subdir" "neovim-implementation-agent"` |
| `scripts/validate-wiring.sh` | 243 | `validate_index_entries "$system_dir" "neovim-research-agent"` |
| `scripts/validate-wiring.sh` | 244 | `validate_language_entries "$system_dir" "neovim"` |
| `README.md` | 3 | `Unlike domain extensions (nix, neovim, formal), core is always active` |
| `README.md` | 158 | `Domain extensions (nix, neovim, formal, etc.) declare their own routing blocks` |
| `scripts/lint/lint-postflight-boundary.sh` | 6 | `# - Build/test commands (lake build, nvim --headless, pnpm build, etc.)` |
| `scripts/lint/lint-postflight-boundary.sh` | 100 | `local build_patterns="lake build\|nvim --headless\|..."` |
| `agents/code-reviewer-agent.md` | 36 | `**Load For Neovim Code**:` |
| `agents/code-reviewer-agent.md` | 37 | `@.claude/extensions/nvim/context/project/neovim/standards/lua-style-guide.md` |
| `agents/code-reviewer-agent.md` | 38 | `@.claude/extensions/nvim/context/project/neovim/domain/lua-patterns.md` |
| `context/standards/postflight-tool-restrictions.md` | 74 | `\| \`nvim --headless\` \| Verification is agent work \|` |
| `root-files/settings.local.json` | 16-52 | Multiple `/home/benjamin/.config/nvim/` absolute paths (functional, not a content issue) |

### `.claude/extensions/latex/` -- All Matches

| File | Line | Content |
|------|------|---------|
| `EXTENSION.md` | 17 | `### VimTeX Integration` |
| `EXTENSION.md` | 19 | `- Compile: \`:VimtexCompile\` (\`<leader>lc\`)` |
| `EXTENSION.md` | 20 | `- View PDF: \`:VimtexView\` (\`<leader>lv\`)` |
| `EXTENSION.md` | 21 | `- Clean: \`:VimtexClean\` (\`<leader>lk\`)` |
| `EXTENSION.md` | 22 | `- TOC: \`:VimtexTocOpen\` (\`<leader>li\`)` |
| `manifest.json` | 4 | `"description": "LaTeX document development with VimTeX integration"` |
| `README.md` | 3 | `LaTeX document development support with VimTeX integration` |
| `README.md` | 33 | `## VimTeX Keymaps` |
| `README.md` | 37-40 | 4 `<leader>` keybinding rows |
| `README.md` | 56 | `- [VimTeX](https://github.com/lervag/vimtex)` |
| `context/project/latex/tools/compilation-guide.md` | 222 | `Most LaTeX editors (..., Neovim with VimTeX) provide:` |
| `context/project/latex/README.md` | 9 | `- \`tools/\` - Compilation guide, VimTeX integration` |

---

## Comparison with Zed Audit

The Zed audit (report 04) was done on the **zed project's** `.claude/` directory, which is a deployed copy of the extension system. This grep was done on the **nvim project's** extension sources. Key differences:

1. **Zed audit Category A items all map to extension SOURCE files in nvim** -- The fixes the Zed audit wants are upstream source fixes in this nvim repo.

2. **Zed audit misses `extensions/core/README.md`**: Lines 3 and 158 both contain `neovim` as example domain extension. Not in any priority list.

3. **Zed audit Category D (validate-wiring.sh, lint-postflight-boundary.sh)** correctly maps to `extensions/core/scripts/`. Task 480 mentions these as Priority 3.

4. **Zed audit Category B (memory examples)**: These live in `extensions/memory/` (not `extensions/core/`). Task 480 description incorrectly says they're in core's skills/commands. The Zed audit is correct that these are illustrative examples, not actionable cleanup targets. However, fixing them would prevent recontamination across all downstream deployments.

5. **Zed audit correctly identifies the upstream fix needed**: latex/EXTENSION.md VimTeX section is the root cause of CLAUDE.md recontamination.

---

## What 478/479 Missed and Why

**Task 478** focused narrowly on `<leader>ac` references (extension picker keybinding) and the `project-overview.md` scope issue. It did not search for all nvim-related content -- only for the editor-specific keybinding language.

**Task 479** focused on the 6 specific nvim/neotex references identified in the Zed audit of that time (neotex in claudemd-header.md, "Neovim Lua loader" in docs, "neovim" in example lists). Neither task did a comprehensive audit of latex extension or of code-reviewer-agent.md, docs/README.md, docs/docs-README.md, validate-wiring.sh, or extension-readme-template.md.

Both tasks operated in "fix what we see" mode rather than "find everything" mode. The Zed post-reload audit (done after 479) finally identified the full scope.

---

## Additional References NOT in Any Priority List

These exist in extension sources and are NOT mentioned in the task 480 description:

| File | Lines | Type | Actionable? |
|------|-------|------|-------------|
| `core/README.md:3` | `(nix, neovim, formal)` | Illustrative example | Low priority (README is factually accurate for this repo) |
| `core/README.md:158` | `(nix, neovim, formal, etc.)` | Illustrative example | Low priority |
| `core/docs/architecture/extension-system.md:163,513` | VimTeX in example JSON | Accurate description | Low priority (factually correct) |
| `core/root-files/settings.local.json:16-52` | Absolute paths to nvim config | Functional data | Not a content issue |
| `memory/` (all files) | ~40 neovim example refs | Illustrative examples | Low priority, cosmetic |

---

## Confidence Level

**High confidence** that the grep results are complete for `.claude/extensions/core/` and `.claude/extensions/latex/`. The search used case-insensitive regex `nvim|neovim|neotex|VimTeX|vimtex` with unlimited results.

**Key insight**: The task 480 description's Priority 2 (memory docs) incorrectly locates those files in `extensions/core/`. They are in `extensions/memory/`. The scope of the task should expand to include `extensions/memory/` for completeness, OR explicitly exclude it as "out of scope because illustrative examples are acceptable."

**Verification**: After all fixes, the recommended verification command should be:
```bash
grep -riE 'nvim|neovim|neotex|VimTeX|vimtex|<leader>' \
  .claude/extensions/core/ \
  .claude/extensions/latex/ \
  .claude/extensions/memory/skills/ \
  .claude/extensions/memory/context/ \
  .claude/extensions/memory/commands/
```
not just core and latex as the task description states.
