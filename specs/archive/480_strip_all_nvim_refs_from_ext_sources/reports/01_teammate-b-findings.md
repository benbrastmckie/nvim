# Teammate B Findings: Priority 2-3 Audit and Source-to-Deploy Mapping

**Task**: 480 - Strip all nvim/neovim/neotex/VimTeX references from extension sources
**Role**: Teammate B - Alternative Approaches
**Confidence**: HIGH

---

## Summary

- **Priority 2** (memory extension): 24 references across 7 files, all in examples/documentation content
- **Priority 3** (latex/typst/core): 5 references across 4 files, with nuanced treatment required
- **Source-to-Deploy mapping**: Extensions deploy with a consistent 1:1 mirror pattern; deployed copies need matching changes

---

## Priority 2: Memory Documentation Files

All references are in **examples** demonstrating how the memory system works. They use neovim/telescope topics to make the system feel concrete. These need generic replacements that still clearly illustrate the concepts.

### File 1: `.claude/extensions/memory/skills/skill-memory/SKILL.md`

**10 references:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 55 | `"topic": "neovim/plugins/telescope"` | `"topic": "project/utils/parsing"` |
| 221 | `2. MEM-neovim-plugin-patterns (45% overlap) -> Recommended: EXTEND` | `2. MEM-project-code-patterns (45% overlap) -> Recommended: EXTEND` |
| 226 | `[ ] EXTEND MEM-neovim-plugin-patterns (append section)` | `[ ] EXTEND MEM-project-code-patterns (append section)` |
| 393 | `/home/user/notes/neovim/ -> "neovim"` | `/home/user/notes/python/ -> "python"` |
| 396 | `Extract domain indicators: neovim, lua, telescope, lazy` | `Extract domain indicators: python, requests, api, database` |
| 397 | `Map to topic: "neovim/plugins" or "neovim/config"` | `Map to topic: "python/libs" or "python/patterns"` |
| 664 | `\| Neovim \| .fnl, .janet, .nix \|` | Remove category label "Neovim" (inaccurate: .fnl, .janet are Fennel/Janet, .nix is Nix). Replace with `\| Scripting \| .fnl, .janet, .nix \|` or move these to correct categories |
| 1046 | `# topic "neovim/plugins/telescope" -> cluster "neovim"` | `# topic "python/libs/requests" -> cluster "python"` |
| 2157 | `topic: "neovim/plugins/telescope"` (in purge frontmatter example) | `topic: "project/patterns/refactor"` |
| 2172 | `topic: "neovim/plugins/telescope"` (in post-tombstone frontmatter) | `topic: "project/patterns/refactor"` |

**Note on line 664**: The table category "Neovim" is inaccurate - `.fnl` (Fennel), `.janet` (Janet), and `.nix` (Nix) are not Neovim-specific. This is a logic bug masquerading as a naming issue. Recommend renaming to "Other" or splitting across appropriate categories.

### File 2: `.claude/extensions/memory/context/project/memory/learn-usage.md`

**12 references:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 24 | `/learn ~/docs/neovim-tips.txt` | `/learn ~/docs/project-notes.txt` |
| 33 | `/learn ~/notes/neovim/` | `/learn ~/notes/python/` |
| 92 | `2. MEM-neovim-plugin-patterns (45% overlap) -> EXTEND recommended` | `2. MEM-project-code-patterns (45% overlap) -> EXTEND recommended` |
| 120 | `Before: MEM-neovim-plugin-patterns "Neovim plugin patterns"` | `Before: MEM-project-code-patterns "Project code patterns"` |
| 121 | `After:  MEM-neovim-plugin-patterns with new:` | `After:  MEM-project-code-patterns with new:` |
| 143 | `topic: "neovim/plugins/telescope"` | `topic: "python/libs/requests"` |
| 156 | `### neovim/` | `### python/` |
| 157 | `  - neovim/plugins/telescope - 3 memories` | `  - python/libs/requests - 3 memories` |
| 158 | `  - neovim/config - 5 memories` | `  - python/config - 5 memories` |
| 172 | `Topic: neovim/lua` | `Topic: python/patterns` |
| 193 | `Topic: neovim/lua (confirm or modify)` | `Topic: python/patterns (confirm or modify)` |
| 292 | `4. **Be consistent** - neovim/plugins not plugins/neovim` | `4. **Be consistent** - python/libs not libs/python` |

### File 3: `.claude/extensions/memory/context/project/memory/memory-setup.md`

**1 reference:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 180 | `execute("write", {path: ".memory/10-Memories/MEM-neovim-lsp-best-practices.md", content: "..."})` | `execute("write", {path: ".memory/10-Memories/MEM-project-coding-practices.md", content: "..."})` |

### File 4: `.claude/extensions/memory/context/project/memory/knowledge-capture-usage.md`

**1 reference:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 294 | `Segment 3: "Key mappings" -> EXTEND MEM-neovim-plugin-patterns (42% overlap)` | `Segment 3: "API patterns" -> EXTEND MEM-project-code-patterns (42% overlap)` |

**Note**: This file's "Directory Scan Flow" example at lines ~283-296 scans `./lua/plugins/` which contains other neovim references (telescope.lua, lsp.lua). Line 294 is the only direct pattern match but the surrounding example context (telescope.lua, lsp.lua filenames on lines 285-286) would also need updating for consistency. However those lines do not match the grep pattern so I flag them as associated context.

### File 5: `.claude/extensions/memory/context/project/memory/domain/memory-reference.md`

**1 reference:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 54 | `topic: "neovim/plugins/telescope"` | `topic: "python/libs/requests"` |

### File 6: `.claude/extensions/memory/context/project/memory/distill-usage.md`

**0 references** - Clean, no changes needed.

### File 7: `.claude/extensions/memory/commands/learn.md`

**1 reference:**

| Line | Content | Suggested Replacement |
|------|---------|----------------------|
| 188 | `/learn ~/notes/neovim/           # Import notes directory to memory vault` | `/learn ~/notes/python/           # Import notes directory to memory vault` |

---

## Priority 3: Other Core Extension Files

### File 1: `.claude/extensions/latex/context/project/latex/tools/compilation-guide.md`

**1 reference:**

| Line | Content | Category | Suggested Replacement |
|------|---------|----------|-----------------------|
| 222 | `Most LaTeX editors (TeXstudio, VS Code with LaTeX Workshop, Neovim with VimTeX) provide:` | Documentation | Remove "Neovim with VimTeX" from the list OR change to a generic editor list: `Most LaTeX editors (e.g., TeXstudio, VS Code with LaTeX Workshop) provide:` |

**Assessment**: This is factual documentation about LaTeX editors. "Neovim with VimTeX" is a legitimate tool, but listing it here creates a neovim-specific reference in a supposedly generic extension. Since the latex extension should be editor-agnostic, removing the specific editor examples or keeping only non-nvim examples is appropriate.

### File 2: `.claude/extensions/typst/context/project/typst/tools/compilation-guide.md`

**1 reference (entire section):**

| Line | Content | Category | Suggested Replacement |
|------|---------|----------|-----------------------|
| 58-64 | `## Neovim Integration` section with `:TypstCompile`, `:TypstWatch` commands | Documentation | Remove entire section OR replace with generic "Editor Integration" section that doesn't list specific nvim commands |

**Full section to replace:**
```markdown
## Neovim Integration

With typst.vim or similar:
- `:TypstCompile` - Compile document
- `:TypstWatch` - Start watch mode
- Automatic compilation on save
```

**Suggested replacement:**
```markdown
## Editor Integration

Most editors with Typst support provide:
- Build on save
- Watch mode integration
- Error highlighting in source
```

### File 3: `.claude/extensions/core/context/standards/postflight-tool-restrictions.md`

**1 reference:**

| Line | Content | Category | Assessment |
|------|---------|----------|------------|
| 74 | `\| \`nvim --headless\` \| Verification is agent work \|` | Functional list | **KEEP - this is a concrete example of a prohibited build command** |

**Assessment**: This reference is in the "Prohibited Operations" table. `nvim --headless` is a real command used for Neovim verification (running headless tests). The table is meant to give concrete examples of prohibited patterns. Removing it reduces clarity. However, if the goal is complete editor-agnosticism in core docs, it could be replaced with a more generic example like `<editor> --headless`. Since it's in a "examples of prohibited patterns" table, it's arguably functional documentation. **Recommend keeping** as it's a concrete, recognizable example, but if changes are required, replace with `\| \`<tool> --headless\` \| Verification is agent work \|`.

### File 4: `.claude/extensions/core/scripts/lint/lint-postflight-boundary.sh`

**2 references:**

| Line | Content | Category | Assessment |
|------|---------|----------|------------|
| 6 | `# - Build/test commands (lake build, nvim --headless, pnpm build, etc.)` | Script comment | **KEEP or genericize** - this is a comment in a lint script describing what it detects |
| 100 | `local build_patterns="lake build\|nvim --headless\|pnpm build\|..."` | Functional code (regex) | **KEEP - this is functional regex** that detects `nvim --headless` in skill files |

**Assessment**: Both references are in the lint script that detects prohibited commands in postflight sections. The regex on line 100 is **functional code** - it must include `nvim --headless` to detect violations in skills that still use it. Removing it would cause false negatives. The comment on line 6 is documentation of what the script detects.

**Recommendation**: These should be **kept** as functional code. The `nvim --headless` pattern in the regex is a detection rule that exists precisely because neovim-using skills may try to call it in postflight. However, if desired for aesthetics, both lines can add other examples while keeping `nvim --headless` or just retain the pattern in the regex without the comment.

---

## Source-to-Deploy Mapping

### Pattern: Extensions deploy to `.claude/` with exact 1:1 mirroring

Extension source paths map to deployed paths as follows:

| Extension Source | Deployed Path |
|-----------------|---------------|
| `.claude/extensions/memory/skills/skill-memory/SKILL.md` | `.claude/skills/skill-memory/SKILL.md` |
| `.claude/extensions/memory/commands/learn.md` | `.claude/commands/learn.md` |
| `.claude/extensions/memory/commands/distill.md` | `.claude/commands/distill.md` |
| `.claude/extensions/memory/context/project/memory/*.md` | `.claude/context/project/memory/*.md` |
| `.claude/extensions/memory/context/project/memory/domain/*.md` | `.claude/context/project/memory/domain/*.md` |
| `.claude/extensions/core/context/standards/postflight-tool-restrictions.md` | `.claude/context/standards/postflight-tool-restrictions.md` |
| `.claude/extensions/core/scripts/lint/lint-postflight-boundary.sh` | `.claude/scripts/lint/lint-postflight-boundary.sh` |

**Verification**: Confirmed via `diff` that deployed copies are byte-identical to sources for all checked files.

**Latex/Typst compilation guides**: These deploy from their respective extension directories:
- `.claude/extensions/latex/context/project/latex/tools/compilation-guide.md`
- `.claude/extensions/typst/context/project/typst/tools/compilation-guide.md`

However, these files do **not** appear to have deployed copies in `.claude/context/` (grep found no deployed copies). They remain only in the extension source directories, loaded on demand when the latex/typst extensions are active. **All changes to source files must also be applied to their deployed counterparts** (if they exist; confirm before assuming).

### Key Rule: Always Change Both

For every source file changed, the deployed copy at the corresponding `.claude/` path must receive the identical change. The system uses exact copies with no transformation.

---

## Action Priority Matrix

| Priority | Files | Action | Deployed Copy Exists? |
|----------|-------|--------|-----------------------|
| HIGH | SKILL.md (lines 55, 221, 226, 393-397, 664, 1046, 2157, 2172) | Replace neovim/telescope examples with generic project examples | Yes: `.claude/skills/skill-memory/SKILL.md` |
| HIGH | learn-usage.md (12 refs) | Replace neovim/telescope with generic python examples | Yes: `.claude/context/project/memory/learn-usage.md` |
| HIGH | memory-setup.md (line 180) | Replace MEM-neovim-lsp slug with generic slug | Yes: `.claude/context/project/memory/memory-setup.md` |
| HIGH | knowledge-capture-usage.md (line 294) | Replace neovim example | Yes: `.claude/context/project/memory/knowledge-capture-usage.md` |
| HIGH | memory-reference.md (line 54) | Replace topic path | Yes: `.claude/context/project/memory/domain/memory-reference.md` |
| HIGH | learn.md command (line 188) | Replace ~/notes/neovim/ example | Yes: `.claude/commands/learn.md` |
| MEDIUM | latex compilation-guide.md (line 222) | Remove "Neovim with VimTeX" from editor list | No deployed copy found |
| MEDIUM | typst compilation-guide.md (lines 58-64) | Replace "Neovim Integration" section | No deployed copy found |
| LOW/KEEP | postflight-tool-restrictions.md (line 74) | Recommend keeping; functional example | Yes: `.claude/context/standards/postflight-tool-restrictions.md` |
| LOW/KEEP | lint-postflight-boundary.sh (lines 6, 100) | Recommend keeping; functional code | Yes: `.claude/scripts/lint/lint-postflight-boundary.sh` |

---

## Consistency Recommendation for Generic Topic Examples

All memory documentation examples currently use `neovim/plugins/telescope` as the canonical topic path. When replacing, use a **consistent** generic replacement throughout all files for coherence. Recommend:

- Topic: `"project/utils/parsing"` or `"python/libs/requests"` (pick one and use everywhere)
- Memory slug: `MEM-project-code-patterns` (replaces `MEM-neovim-plugin-patterns` everywhere)
- File example: `telescope-notes.md` -> `api-notes.md` or `research-notes.md`
- Directory: `~/notes/neovim/` -> `~/notes/python/` or `~/notes/research/`

Using `python` as the replacement domain (rather than a made-up project) keeps examples concrete and recognizable to a general audience, without implying any specific editor.

**Total actionable references: 27** (excluding the 3 "KEEP" recommendations in Priority 3)
