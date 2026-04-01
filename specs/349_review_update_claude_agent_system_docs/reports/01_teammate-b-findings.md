# Teammate B Findings: Extension System Documentation Audit

**Task**: 349 - Review and update .claude/ agent system documentation for correctness and consistency
**Focus**: Extension system documentation and cross-referencing with actual implementations
**Date**: 2026-04-01

---

## Methodology

- Read `extensions/README.md` thoroughly
- Listed all 14 extension directories
- Read all 14 `manifest.json` files
- Read `founder/README.md` and `present/README.md` in detail
- Cross-referenced every manifest `provides.agents`, `provides.skills`, and `provides.rules` against actual filesystem contents
- Verified all `index-entries.json` context file paths exist on disk
- Checked `context/index.json` (main merged index) for correctness
- Checked `CLAUDE.md` extension language list for completeness

---

## Key Findings

**1. extensions/README.md incorrectly attributes `deck` to `present` extension**

The Available Extensions table (line 35) reads:
```
| present | deck, grant | Presentations and grant proposals |
```

This is wrong on two counts:
- The `present` extension has `language: "present"` and only provides `grant-agent.md`, `skill-grant`, and the `/grant` command
- Pitch deck generation is in the `founder` extension, not `present`. The `present/README.md` (line 19) explicitly states: "Pitch deck generation has moved to the `founder` extension."
- The description "Presentations and grant proposals" is inaccurate; it should be "Grant writing and proposal development"

**Confidence**: High (verified against both manifests and present/README.md)

---

**2. `founder/README.md` is outdated — documents v3.0 as having only 5 commands, but the extension actually has 8**

The founder README (lines 7-9, 17-21, 147-205) consistently describes "five commands" (market, analyze, strategy, legal, project) and an architecture tree that omits `/sheet`, `/finance`, and `/deck`.

The actual extension (as of manifest v3.0 and EXTENSION.md) has 8 commands, 12 agents, and 12 skills:
- Missing from README commands table: `/sheet`, `/finance`, `/deck`
- Missing from README architecture tree: `skill-spreadsheet/`, `skill-finance/`, `skill-deck-research/`, `skill-deck-plan/`, `skill-deck-implement/`, and corresponding agents (`spreadsheet-agent.md`, `finance-agent.md`, `deck-research-agent.md`, `deck-planner-agent.md`, `deck-builder-agent.md`)
- Missing from README "What's New in v3.0" section: no mention of deck workflow, spreadsheet workflow, or finance workflow

The EXTENSION.md (injected into CLAUDE.md when loaded) is accurate and lists all 8 commands and 12 skill-agent mappings. The README.md has fallen behind.

**Confidence**: High (manifest.json, EXTENSION.md, skills/ and agents/ directories all consistent; README contradicts them)

---

**3. `CLAUDE.md` extension language list omits `founder` and `present` languages**

The Language-Based Routing section (CLAUDE.md line 75-78) lists:
```
Extensions provide additional language support (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, etc.)
```

Two extensions with actual `language` values are missing from this example list:
- `founder` (language: "founder") — 8 commands, complex sub-type routing with `founder:deck`, `founder:sheet`, etc.
- `present` (language: "present") — grant writing workflow

The `etc.` implies completeness but omits active languages that users might try to configure tasks with.

**Confidence**: High

---

**4. `extensions/README.md` loading procedure references `core-index-entries.json` without a path**

The loading steps (line 46) state:
> "Core index entries are loaded from `core-index-entries.json` (always included)"

The actual file is located at `.claude/context/core-index-entries.json`, not at the `.claude/` root. This is a minor but potentially confusing omission for extension authors trying to understand the loading sequence.

**Confidence**: High (file confirmed at `/home/benjamin/.config/nvim/.claude/context/core-index-entries.json`)

---

**5. `web` extension provides `skill-tag` which silently overrides the core `skill-tag`**

The web extension's `manifest.json` (line 9) includes `skill-tag` in its `provides.skills`. When the web extension is loaded, its `skill-tag/SKILL.md` (which is an extended version with example execution flows) would be copied to `.claude/skills/skill-tag/`, overwriting the core version.

The core `skill-tag` is marked as "user-only" in CLAUDE.md and is documented as a system-wide capability. The web extension's version adds 133 lines of example flows but is otherwise identical in frontmatter and behavior.

This is not technically wrong (the web version is a strict superset), but:
- It is undocumented in extensions/README.md
- Extension loading docs say "Agent, skill, rule files are copied to .claude/" without warning about core overrides
- Users unloading the web extension would need to restore the core skill-tag

**Confidence**: Medium (functionally equivalent but undocumented override behavior)

---

**6. `filetypes` extension provides `document-agent.md` but no corresponding `skill-document`**

The filetypes manifest lists `document-agent.md` in `provides.agents` but only 4 skills: `skill-filetypes`, `skill-spreadsheet`, `skill-presentation`, `skill-scrape` — no `skill-document`.

Investigation shows this is intentional: `document-agent.md` is invoked as a sub-agent by the `filetypes-router-agent`, not directly by a skill. However, the asymmetry (agent listed in `provides` but not matched with a skill) could confuse extension authors using filetypes as a reference pattern.

This is an underdocumented architectural choice, not a bug.

**Confidence**: Medium (intentional architecture but not documented anywhere in the extension)

---

**7. All 14 extension `index-entries.json` context file references verified as accurate**

Every path in every extension's `index-entries.json` was verified to exist on disk. No dead links found across all 14 extensions (epidemiology: 4 entries, filetypes: 9, formal: 45, founder: 32, latex: 10, lean: 26, memory: 5, nix: 11, nvim: 21, present: 17, python: 6, typst: 26, web: 23, z3: 5).

**Confidence**: High

---

**8. All 14 extension `provides.agents` and `provides.skills` files verified to exist on disk**

Every agent `.md` file and every skill directory referenced in all 14 manifest `provides` sections exists on disk. No broken references found.

**Confidence**: High

---

**9. All 14 extension `provides.rules` files verified to exist on disk**

Every rule file referenced in the 4 extensions that provide rules (web: `web-astro.md`, latex: `latex.md`, lean: `lean4.md`, nvim: `neovim-lua.md`, nix: `nix.md`) exists on disk.

**Confidence**: High

---

**10. Main `context/index.json` is a core-only snapshot — extension entries are ephemeral**

The current `context/index.json` contains exactly 95 entries, all with `domain: "core"`. No extension entries are permanently stored here. This is architecturally correct per the README (extensions are merged at load time and removed at unload), but:
- The CLAUDE.md documentation (line 218-219) says "Extension index entries are merged into `.claude/context/index.json` by the loader -- no separate extension query needed" without clarifying this is ephemeral
- New contributors might expect to find extension entries in the committed index.json

**Confidence**: High (architecture correct; documentation clarity issue)

---

**11. `founder` extension's routing table in manifest is accurate and well-structured**

The founder manifest `routing` section correctly maps all 3 phases (research, plan, implement) x 9 sub-types (founder, founder:market, founder:analyze, founder:strategy, founder:legal, founder:project, founder:sheet, founder:finance, founder:deck). All referenced skill names exist in the extension's `skills/` directory.

**Confidence**: High

---

**12. `present` extension routing is minimal but accurate**

The present manifest contains a routing entry for `implement.grant -> skill-grant:assemble`. The `:assemble` suffix is a sub-command notation. The `skill-grant` skill exists. This routing entry works as documented.

**Confidence**: High

---

**13. Extensions README description column for `founder` is too narrow**

The current entry reads:
```
| founder | founder | Business strategy and startup operations |
```

The actual founder extension covers: market sizing, competitive analysis, GTM strategy, contract review, project timelines, cost breakdown spreadsheets, financial analysis, and pitch deck creation — a much broader surface area than "startup operations" implies. More accurate: "Business strategy, financial analysis, pitch decks, and startup operations" or similar.

**Confidence**: Medium (subjective but the current description is arguably misleading given 8 commands)

---

## Recommended Changes

### Priority 1: Correctness Fixes

**1.1 Fix `extensions/README.md` table entry for `present`** (line 35):

Current:
```markdown
| present | deck, grant | Presentations and grant proposals |
```
Change to:
```markdown
| present | present | Grant writing and proposal development |
```

**1.2 Update `founder/README.md` to document all 8 commands**

The README needs:
- Update "five commands" references (lines 7-9 and 17) to "eight commands"
- Add `/sheet`, `/finance`, `/deck` to the commands overview table (after line 21)
- Add spreadsheet, finance, and deck agents/skills to the Architecture section (after line 185)
- Add deck workflow section describing 3-phase deck process (deck-research-agent → deck-planner-agent → deck-builder-agent)
- Add `/sheet` and `/finance` command documentation sections (after `/project` section)

**1.3 Add `founder` and `present` to `CLAUDE.md` extension language list** (line 76):

Current:
```
Extensions provide additional language support (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, etc.)
```
Change to:
```
Extensions provide additional language support (neovim, lean4, latex, typst, python, nix, web, z3, epidemiology, formal, founder, present, etc.)
```

### Priority 2: Clarity Improvements

**2.1 Add path to `core-index-entries.json` in `extensions/README.md`** (line 46):

Current:
> "Core index entries are loaded from `core-index-entries.json` (always included)"

Change to:
> "Core index entries are loaded from `.claude/context/core-index-entries.json` (always included)"

**2.2 Document the core skill override behavior for `web` extension in `extensions/README.md`**

Add a note in the Extension Structure or Loading Extensions section explaining that extensions can provide updated versions of core skills (e.g., `skill-tag`). Add a note that the web extension's `skill-tag` is an extended version of the core `skill-tag`.

**2.3 Document the router-agent pattern in `filetypes` extension**

The `filetypes` extension uses a router-agent pattern where `document-agent.md` is a sub-agent invoked by `filetypes-router-agent`, not directly by a skill. This is architecturally distinct from other extensions and should be noted in the filetypes extension README or in the general extensions README under Extension Patterns.

**2.4 Clarify ephemeral nature of extension entries in `context/index.json`**

In `CLAUDE.md` context discovery section, add a note that extension entries exist in `index.json` only while the extension is loaded (they are removed on unload), and that the committed `index.json` contains only core entries.

**2.5 Update `extensions/README.md` description for `founder`** (line 34):

Current:
```
| founder | founder | Business strategy and startup operations |
```
Consider changing to:
```
| founder | founder | Business strategy: market sizing, competitive analysis, GTM, legal, project, spreadsheet, finance, pitch decks |
```

---

## Summary Table

| # | Finding | File(s) | Severity | Confidence |
|---|---------|---------|----------|------------|
| 1 | `present` entry says "deck, grant" but deck is in founder | extensions/README.md | High | High |
| 2 | founder/README.md documents 5 commands but extension has 8 | founder/README.md | High | High |
| 3 | CLAUDE.md extension language list omits `founder` and `present` | CLAUDE.md | Medium | High |
| 4 | core-index-entries.json path not specified in loading docs | extensions/README.md | Low | High |
| 5 | web extension skill-tag overrides core skill-tag (undocumented) | extensions/README.md, web/ | Low | Medium |
| 6 | document-agent has no matching skill (intentional but undocumented) | filetypes/manifest.json | Low | Medium |
| 7 | All index-entries.json context file paths verified correct | All extensions | N/A (no change) | High |
| 8 | All provides.agents and provides.skills files verified present | All extensions | N/A (no change) | High |
| 9 | All provides.rules files verified present | nvim, latex, lean, nix, web | N/A (no change) | High |
| 10 | context/index.json ephemeral nature underdocumented | CLAUDE.md | Low | High |
| 11 | founder routing table is accurate and complete | founder/manifest.json | N/A (no change) | High |
| 12 | present routing is minimal but accurate | present/manifest.json | N/A (no change) | High |
| 13 | founder README description in extensions/README.md is too narrow | extensions/README.md | Low | Medium |
