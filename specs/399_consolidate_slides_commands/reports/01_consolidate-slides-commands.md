# Research Report: Task #399 - Consolidate slides.md command

**Task**: 399 - Consolidate slides commands
**Started**: 2026-04-10T00:00:00Z
**Completed**: 2026-04-10T00:00:00Z
**Effort**: S (research), M (implementation)
**Dependencies**: None
**Sources/Inputs**:
- .claude/extensions/filetypes/commands/slides.md
- .claude/extensions/filetypes/commands/convert.md
- .claude/extensions/present/commands/talk.md
- .claude/extensions/filetypes/manifest.json
- .claude/extensions/present/manifest.json
- .claude/extensions/filetypes/EXTENSION.md, README.md, index-entries.json
- .claude/extensions/present/EXTENSION.md, README.md, index-entries.json
- .claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md
- .claude/extensions/filetypes/context/project/filetypes/README.md
- .claude/extensions/filetypes/context/project/filetypes/patterns/presentation-slides.md
- .claude/extensions/filetypes/agents/presentation-agent.md
- .claude/extensions/filetypes/skills/skill-presentation/SKILL.md
- .claude/extensions/present/agents/talk-agent.md
- .claude/extensions/present/skills/skill-talk/SKILL.md
- .claude/scripts/install-extension.sh
- .claude/scripts/check-extension-docs.sh
- .claude/docs/guides/user-guide.md
- .claude/docs/reference/standards/extension-slim-standard.md
- .claude/context/patterns/context-discovery.md
- .claude/context/architecture/system-overview.md
**Artifacts**:
- specs/399_consolidate_slides_commands/reports/01_consolidate-slides-commands.md
**Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- The three files serve disjoint purposes: `filetypes/commands/slides.md` is a PPTX->Beamer/Polylux/Touying conversion utility; `filetypes/commands/convert.md` is a general document format converter; `present/commands/talk.md` is a research talk task-creation command with forcing questions.
- **Recommendation: fold `filetypes/commands/slides.md` into `filetypes/commands/convert.md`.** The semantic and architectural fit is overwhelming: both live in the filetypes extension, share the same router pattern, converter tool ecosystem (pandoc, markitdown, python-pptx), skill-presentation infrastructure, and argument shape (SOURCE [OUTPUT]). Folding into `talk.md` is infeasible: `talk.md` is a task-lifecycle command (creates specs/state.json entries, runs forcing questions, delegates to skill-talk for Slidev synthesis), not a converter.
- The rename `present/commands/talk.md -> present/commands/slides.md` does not influence the fold decision. The target command is conceptually the research-talk creation command, not a pptx converter; keeping the fold in filetypes keeps converter logic with other converters.
- After the fold, `/convert` gains knowledge of presentation formats (beamer, polylux, touying) and should route pptx inputs with a `--format` flag to `skill-presentation`. The `/slides` command name is deleted from the filetypes extension and becomes available for the present extension's renamed command.
- No residual naming collision: after the rename, the only `slides.md` command file will be `present/commands/slides.md`. The install-extension.sh symlink layer in `.claude/commands/` currently has no symlinks for any of these (extensions loaded on demand); at install time each extension symlinks its own command files to `.claude/commands/`, so the rename must be accompanied by removal of the old filetypes `slides.md` symlink target to avoid symlink conflict when both extensions are loaded simultaneously.
- Roughly 25-30 reference sites need updates across 12 files (manifests, index-entries.json, EXTENSION.md, README.md, conversion-tables.md, filetypes/README.md sub-doc, skill-presentation trigger doc, user-guide.md, extension-slim-standard.md, system-overview.md, context-discovery.md, and the commands themselves).

## Context & Scope

Task 399 requests two structural edits:
1. Fold `.claude/extensions/filetypes/commands/slides.md` into either `convert.md` (filetypes) or `talk.md` (present).
2. Rename `.claude/extensions/present/commands/talk.md` -> `.claude/extensions/present/commands/slides.md`.

The research phase must pick the best target for the fold, catalog every cross-reference to update, verify no collisions, and understand the command-discovery mechanism.

## Findings

### File Inventory

#### .claude/extensions/filetypes/commands/slides.md (308 lines)
- **Frontmatter**: `description: Convert presentations to Beamer, Polylux, or Touying slides`
- **Argument hint**: `SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying]`
- **Purpose**: Convert PPTX/PPT/MD to Beamer/Polylux/Touying/Markdown/PPTX.
- **Shape**: GATE IN (parse args, validate source, infer output, validate format) -> DELEGATE to `skill-presentation` -> GATE OUT (verify output) -> optional COMMIT.
- **Args parsed**: `$1` source, `$2` output, `--format`, `--theme`.
- **Tools**: python-pptx, pandoc.
- **Skill invoked**: `skill-presentation` -> `presentation-agent`.
- **Metadata returned**: includes `slide_count`.

#### .claude/extensions/filetypes/commands/convert.md (259 lines)
- **Frontmatter**: `description: Convert documents between formats (PDF/DOCX to Markdown, Markdown to PDF)`
- **Argument hint**: `SOURCE_PATH [OUTPUT_PATH]`
- **Purpose**: General document conversion (PDF, DOCX, XLSX, PPTX, HTML, images <-> Markdown; Markdown -> PDF).
- **Shape**: identical structure to slides.md (GATE IN / DELEGATE / GATE OUT / COMMIT).
- **Skill invoked**: `skill-filetypes` -> `filetypes-router-agent`.
- **Already references /slides**: line 47 says `For presentation conversions, use /slides.` (will be removed on fold).
- **PPTX already listed in supported conversions** as PPTX->Markdown via markitdown (convert.md:42).

#### .claude/extensions/present/commands/talk.md (478 lines)
- **Frontmatter**: `description: Create research talk tasks with pre-task forcing questions for academic presentations`, `model: opus`
- **Argument hint**: `"description" | TASK_NUMBER | /path/to/file.md`
- **Purpose**: Task-lifecycle command. Creates specs/{NNN}_{SLUG}/ tasks, runs pre-task forcing questions (talk type, source materials, audience context), delegates to skill-talk for research/assembly of Slidev presentations. Supports `--design` flag for post-research design confirmation.
- **Shape**: Stage 0 (forcing questions) -> Gate IN -> Stage 1 (task creation, state.json/TODO.md updates) -> Stage 2 (research delegation to skill-talk) -> Stage 3 (design confirmation).
- **Scope**: specs/state.json mutation, TODO.md manipulation, task lifecycle management. Output is Slidev (`.md`) presentation under `talks/{N}_{slug}/`, not Beamer/Typst.

### Overlap Analysis

| Dimension | slides.md (source) | convert.md | talk.md |
|-----------|--------------------|------------|---------|
| Extension | filetypes | **filetypes (same)** | present (different) |
| Command category | file converter | **file converter** | task-lifecycle creator |
| Argument shape | `SRC [OUT] [--format]` | **`SRC [OUT]`** | `"desc" \| N \| file.md` |
| Skill delegated | skill-presentation | skill-filetypes | skill-talk |
| State mutation | none | **none** | specs/state.json + TODO.md |
| Output format | .tex / .typ (Beamer/Polylux/Touying) | .md / .pdf / others | .md (Slidev) |
| Tools | pandoc, python-pptx | **markitdown, pandoc** | WebSearch, jq, git, Edit |
| Task system integration | none | **none** | full (task creation, forcing data, design decisions) |
| Model hint | none | none | opus |

convert.md already handles PPTX->Markdown via markitdown (row in the conversion table at convert.md:42). Folding means: `/convert` gains `--format` support for beamer/polylux/touying routes, and when the source is .pptx and a slide-output format is requested, delegate to `skill-presentation` instead of `skill-filetypes`. This is a modest extension of an existing converter.

By contrast, folding slides.md into talk.md would require smashing two incompatible shapes: a stateless file converter and a stateful task lifecycle manager. `talk.md` does not accept a raw pptx as converter input; its file-path mode uses the file as *source material* for a newly created task, then runs research -> plan -> implement to *build* a Slidev deck from scratch. These are opposite directions of data flow (extracting *from* a pptx vs. authoring *to* a Slidev deck).

### Rename Impact on Fold Decision

After the fold, the present extension will rename `talk.md` -> `slides.md`. Key questions:
1. Does this cannibalize the `/slides` command name the filetypes extension was using? Yes, but intentionally: filetypes' `/slides` is being retired in favor of flags on `/convert`, which is exactly what makes the namespace available for the present extension.
2. Could the rename have argued for folding *into* talk.md (so the new `/slides` absorbs the old pptx conversion)? No. The renamed command is still the research-talk task-lifecycle command - only its surface name changes. Its internal logic (forcing questions, state mutation, Slidev assembly) is unrelated to pptx conversion. Mixing them would produce an ill-typed command (is `/slides pres.pptx` a conversion request or "create a talk task using pres.pptx as source material"?).
3. Is there a risk that after the rename, users typing `/slides foo.pptx` expect the old behavior? Yes - this is the main user-facing risk. Mitigation: add a clear "Moved to /convert --format=beamer" note in the present extension's README and CHANGELOG (discussed under Risks).

### Cross-Reference Catalog

References to the old `/slides` command (filetypes) that need removal or rewrite:

| File | Lines | Type | Action |
|------|-------|------|--------|
| .claude/extensions/filetypes/manifest.json | 26 (`"slides.md"` in provides.commands) | registration | **Remove** entry |
| .claude/extensions/filetypes/commands/slides.md | whole file | source | **Delete** file |
| .claude/extensions/filetypes/commands/convert.md | 47 (`For presentation conversions, use /slides`) | cross-ref | **Remove** note; merge slides support into convert.md |
| .claude/extensions/filetypes/commands/convert.md | 42 (PPTX->Markdown row) | support table | **Extend** with PPTX->Beamer/Polylux/Touying rows |
| .claude/extensions/filetypes/commands/convert.md | STAGE 2 DELEGATE | skill invocation | Add `--format` dispatch to skill-presentation for pptx+(beamer\|polylux\|touying) |
| .claude/extensions/filetypes/EXTENSION.md | 22 (`/slides` row) | CLAUDE.md merge | **Remove** row; annotate `/convert` row for pptx-to-slides |
| .claude/extensions/filetypes/README.md | 13 (command table row) | extension doc | **Remove** row |
| .claude/extensions/filetypes/README.md | 79-90 (/slides section) | extension doc | **Remove** section; expand /convert section |
| .claude/extensions/filetypes/README.md | 128 (dir tree listing) | extension doc | **Remove** entry |
| .claude/extensions/filetypes/README.md | 208 (outputs table) | extension doc | **Remove** row; merge into /convert row |
| .claude/extensions/filetypes/index-entries.json | 20, 45, 98, 120, 143, 167 (`/slides` in load_when.commands) | context routing | **Replace** `/slides` with `/convert` (or delete if redundant with existing `/convert` entries) |
| .claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md | 23, 68-70, 125, 129 | domain doc | Change heading `## Presentation Conversions (via /slides)` to `(via /convert)`; update example commands |
| .claude/extensions/filetypes/context/project/filetypes/README.md | 45 (/slides), 61 (path), 86 (command example) | domain doc | Update section heading and examples |
| .claude/extensions/filetypes/skills/skill-presentation/SKILL.md | 25 (`User explicitly runs /slides command`) | skill trigger doc | Change to `/convert` with pptx+slide-format |
| .claude/extensions/filetypes/agents/presentation-agent.md | (no /slides mentions found; paths like `slides.tex` are artifact paths, unaffected) | - | No change |
| .claude/docs/reference/standards/extension-slim-standard.md | 116 (sample command table row) | standard example | Update example to show /convert folding |
| .claude/docs/guides/user-guide.md | 462-484 (/convert Command section) | user doc | Extend with beamer/polylux/touying examples (user-guide.md doesn't currently mention /slides so no removal, but additions help) |
| .claude/context/architecture/system-overview.md | 408 (`Additional commands (/convert) available via extensions`) | arch doc | No change (only mentions /convert generically) |
| .claude/context/patterns/context-discovery.md | 250-251 (domain-specific command list) | pattern doc | Keep `/slides` in list (now belongs to present extension); OR add a note clarifying which extension owns it. Re-evaluate: since the rename moves `/slides` to present, this entry stays valid but its domain shifts. |

References to `/talk` (present) that need updating for the rename:

| File | Lines | Type | Action |
|------|-------|------|--------|
| .claude/extensions/present/commands/talk.md | whole file | source | **Rename** to slides.md; update "# /talk Command" heading and all self-referential `/talk` text on lines 18-21, 286, 311, 440 to `/slides`; also update `description:` frontmatter if desired (task says command name changes, not necessarily description text) |
| .claude/extensions/present/manifest.json | 10 (`"talk.md"` in provides.commands) | registration | **Replace** with `"slides.md"` |
| .claude/extensions/present/EXTENSION.md | 29-31 (`/talk` rows in Commands table) | CLAUDE.md merge | **Rename** `/talk` -> `/slides` in all three rows |
| .claude/extensions/present/README.md | 21 (commands table row), 69 (section header), 74-76 (usage examples) | extension doc | **Rename** `/talk` -> `/slides` |
| .claude/extensions/present/index-entries.json | 350, 364 (`"commands": ["/talk"]`) | context routing | **Replace** `/talk` with `/slides` |
| .claude/extensions/present/skills/skill-talk/SKILL.md | 34 (`/talk command with task number`), 303 (`Use /talk for talk-type tasks`) | skill doc | **Update** to `/slides` |
| .claude/extensions/present/skills/skill-talk/SKILL.md | 50 (`--design workflow handled at command level (talk.md)`) | skill doc | **Update** to `slides.md` |
| .claude/extensions/present/agents/talk-agent.md | (references `/talk` only indirectly via library paths; talk/contents/... are artifact paths) | - | Search and update any `/talk` slash-command references |
| .claude/extensions/present/context/project/present/domain/presentation-types.md | 3 (`Domain reference for research presentation types supported by the /talk command`) | domain doc | **Update** to `/slides` |

**Historical / task-artifact references** (specs/*, archive): present in historical task files but do not need updating per task instructions.

**Command-name-only references** like `.claude/context/patterns/context-discovery.md:250-251` list `/slides` among domain-specific commands. After the consolidation, `/slides` is still valid (now owned by present extension), so this line remains accurate.

### Collision Check

After the fold+rename:
- `.claude/extensions/filetypes/commands/slides.md` -> **deleted**
- `.claude/extensions/present/commands/slides.md` -> **new** (renamed from talk.md)
- Result: exactly one `slides.md` in extension commands. No collision.

`.claude/commands/` symlink layer (created by install-extension.sh): currently empty of all three commands in this workspace. At extension load time, install-extension.sh creates symlinks based on each manifest's `provides.commands`. After the manifests are updated:
- filetypes no longer provides `slides.md` (so no symlink creation, no conflict).
- present provides `slides.md` (pointing to `../extensions/present/commands/slides.md`).

**Caveat**: If a user has both extensions installed and then updates filetypes without uninstalling first, the stale `slides.md` symlink from the old filetypes install could collide with the new present symlink. Mitigation: ensure implementation plan includes an uninstall/reinstall step or explicit symlink cleanup. The uninstall-extension.sh script presumably removes only files listed in the *current* manifest, so updating the filetypes manifest to drop `slides.md` from `provides.commands` and then running uninstall would leave an orphan. This is an implementation detail to confirm during the plan phase.

### Command Discovery Mechanism

- **Installation-time discovery**: `.claude/scripts/install-extension.sh` reads the extension directory and for every `commands/*.md` file creates a symlink at `.claude/commands/{name}.md` pointing at `../extensions/{ext}/commands/{name}.md` (lines 80-108). The symlink approach means Claude Code's command resolver sees these as normal commands in `.claude/commands/`.
- **Manifest-driven validation**: `.claude/scripts/check-extension-docs.sh` validates every entry in `manifest.json`'s `provides.commands` array against the on-disk files and cross-checks that README.md mentions each command (lines 83-86, 127). This doc-lint will fail if:
  - filetypes' manifest still lists `slides.md` but the file is deleted.
  - present's manifest still lists `talk.md` but the file is renamed.
  - filetypes README still documents `/slides` but manifest has dropped it.
  - present README still documents `/talk` but manifest lists `slides.md`.
- **No separate command index**: There is no top-level registry JSON that enumerates extension commands independently of the manifests. The manifests are the sole source of truth, and symlinks are regenerated on install. No additional regeneration step is required beyond re-running install-extension.sh (or equivalent) after the changes.

### Index Entries and Load-When Commands

`filetypes/index-entries.json` has six entries with `/slides` in `load_when.commands`. After the fold, these context files are still relevant (presentation-slides patterns, tool detection, etc.), but the command key should shift from `/slides` to `/convert`. Options:
1. Replace `/slides` with `/convert` in every entry -> loads presentation context when `/convert` is invoked. Slight over-load but low cost.
2. Keep `/slides` AND add `/convert` (redundant; only needed if both commands exist).
3. Omit `/slides`, rely on agent name (`presentation-agent`) to trigger loading.

**Recommendation**: Option 1 - replace `/slides` with `/convert`. This is simplest and keeps context discovery aligned with the new command surface. Patterns loaded under `/convert` include general conversion tools (tool-detection, dependency-guide, conversion-tables), which are already loaded for `/convert` in other entries - there's no duplication, just broader coverage.

## Decisions

- **Fold target**: `.claude/extensions/filetypes/commands/convert.md`.
- **Rename handling**: Perform the two operations as sequential phases: (1) fold+delete slides.md in filetypes, (2) rename talk.md->slides.md in present. Order matters because phase 1 frees the `/slides` namespace, preventing any transient collision if both extensions are loaded mid-operation.
- **Dispatch logic in convert.md**: After the fold, convert.md should detect when source is `.pptx`/`.ppt` AND a slide-output `--format` is specified, and delegate to `skill-presentation` instead of `skill-filetypes`. Fallback (pptx with no format, or `--to=md`) continues to use `skill-filetypes` for markitdown extraction.
- **Frontmatter for the folded convert.md**: extend `allowed-tools` with anything slides.md required (it only adds Read, which convert.md already has); extend argument-hint to `SOURCE_PATH [OUTPUT_PATH] [--format beamer|polylux|touying] [--theme NAME]`.
- **Preserve `--theme` argument**: slides.md has a `--theme` flag. Carry it over.
- **Index-entries replacement**: Replace `/slides` with `/convert` in filetypes/index-entries.json.
- **Context-discovery.md line 250-251**: Leave `/slides` in the list (now owned by present extension).

## Recommendations

1. **(Highest priority)** Fold slides.md into convert.md with a pptx+slide-format dispatch branch. Update convert.md's description, argument-hint, supported conversions table, GATE IN parsing (add `--format`, `--theme`), and STAGE 2 DELEGATE (conditional skill selection).
2. Delete `.claude/extensions/filetypes/commands/slides.md`.
3. Update `.claude/extensions/filetypes/manifest.json` to remove `slides.md` from `provides.commands`.
4. Update filetypes docs: EXTENSION.md, README.md (3 locations), conversion-tables.md, filetypes/README.md sub-doc, skill-presentation/SKILL.md trigger section.
5. Replace `/slides` with `/convert` in filetypes/index-entries.json (6 occurrences).
6. Rename `.claude/extensions/present/commands/talk.md` to `slides.md`.
7. Rewrite internal `/talk` references inside the new slides.md: heading (line 8), usage examples (18-21), task resume pointer (286), error message (311, 440). The frontmatter `description:` and `allowed-tools:` can stay semantically the same but the `# /talk Command` header should become `# /slides Command`.
8. Update `.claude/extensions/present/manifest.json`: change `talk.md` to `slides.md` in `provides.commands`.
9. Update present docs: EXTENSION.md (3 rows), README.md (command table, section header, examples), skill-talk/SKILL.md (3 locations), index-entries.json (2 locations).
10. Update `.claude/extensions/present/context/project/present/domain/presentation-types.md:3`.
11. Search talk-agent.md for any `/talk` slash-command references (not library paths) and update.
12. Run `.claude/scripts/check-extension-docs.sh` as the validation gate before committing. This script will flag missing files and README/manifest mismatches.
13. Run `.claude/scripts/validate-extension-index.sh` if it exists to validate index-entries.
14. Do NOT update specs/, archive/, or historical task summaries - task instructions say these are reference-only.
15. Add a note in present extension's README under `/slides` that `/convert --format=beamer` handles pptx extraction, and a note in filetypes conversion-tables.md that research-talk task creation uses `/slides` in the present extension.
16. Consider a one-line backward-compatibility note in the root CLAUDE.md or user-guide.md ("renamed from /talk in v{X}") to ease user migration.

## Risks & Mitigations

- **Risk**: User muscle memory - `/slides foo.pptx` previously meant conversion; post-change it means "create a research talk task with foo.pptx as source material." **Mitigation**: Clear mention in extension READMEs and present CHANGELOG; make `/convert --format=beamer` prominent in filetypes docs.
- **Risk**: Symlink collision during partial update (both old filetypes `slides.md` symlink and new present `slides.md` symlink targeting the same location). **Mitigation**: Implementation plan must sequence: (a) uninstall filetypes commands cleanly or explicitly `rm .claude/commands/slides.md` before reinstalling extensions; (b) perform fold and rename as independent commits so that in any intermediate state, at most one extension claims `slides.md`.
- **Risk**: doc-lint (`check-extension-docs.sh`) failures during a staged update. **Mitigation**: Apply all manifest + README + command-file changes in a single commit per extension (two commits total: one for filetypes fold, one for present rename).
- **Risk**: index-entries.json wrong after replacement (over- or under-loading context for `/convert`). **Mitigation**: Verify by reading each entry and checking the paths remain relevant; presentation-slides.md and pitch-deck patterns are legitimate `/convert` context only when the target is a slide format.
- **Risk**: `skill-presentation` trigger conditions still say `User explicitly runs /slides command`. If not updated, the skill-routing engine may still try to dispatch on the absent command. **Mitigation**: Update skill-presentation/SKILL.md line 25 to reference `/convert` with pptx+slide-format.
- **Risk**: Missing internal cross-references if grep missed escaped or linked variants. **Mitigation**: Implementation phase re-runs the same greps post-edit to confirm zero stale references outside specs/.
- **Risk**: `talk-agent.md` name - the agent is still named `talk-agent` even though the command is now `/slides`. The task description does not request an agent rename and doing so would ripple across many more files. **Mitigation**: Leave agent name as `talk-agent`; document the mismatch in present/README.md ("The /slides command delegates to talk-agent via skill-talk - the underlying skill and agent names are preserved to minimize churn").

## Appendix

### Search Queries Used
- `rg 'slides\.md|/slides\b|filetypes/commands/slides' .claude/` -> 45 files
- `rg 'talk\.md|/talk\b|present/commands/talk' .claude/` -> 9 files
- `rg 'convert\.md|/convert\b|filetypes/commands/convert' .claude/` -> 15 files
- `find .claude -name 'slides.md' -not -path '*/founder/*'` -> 1 file
- `find .claude -name 'talk.md'` -> 1 file
- `ls -la .claude/commands/` -> confirmed no extension symlinks currently resident

### Notes on Founder Extension References
Many hits for `slides.md` in `.claude/extensions/founder/` refer to the Slidev source file artifact (`strategy/{slug}-deck/slides.md`), not the `/slides` slash command. These are unaffected by this task - they are content filenames within a built deck directory.

### Files To Modify (Summary)
1. `.claude/extensions/filetypes/commands/convert.md` - extend with slides support
2. `.claude/extensions/filetypes/commands/slides.md` - **delete**
3. `.claude/extensions/filetypes/manifest.json` - drop slides.md
4. `.claude/extensions/filetypes/EXTENSION.md` - drop /slides row
5. `.claude/extensions/filetypes/README.md` - remove /slides section + rows
6. `.claude/extensions/filetypes/index-entries.json` - /slides -> /convert x6
7. `.claude/extensions/filetypes/context/project/filetypes/domain/conversion-tables.md` - heading/command examples
8. `.claude/extensions/filetypes/context/project/filetypes/README.md` - section update
9. `.claude/extensions/filetypes/skills/skill-presentation/SKILL.md` - trigger doc
10. `.claude/extensions/present/commands/talk.md` - **rename** to slides.md + internal `/talk` -> `/slides`
11. `.claude/extensions/present/manifest.json` - talk.md -> slides.md
12. `.claude/extensions/present/EXTENSION.md` - /talk -> /slides
13. `.claude/extensions/present/README.md` - /talk -> /slides
14. `.claude/extensions/present/index-entries.json` - /talk -> /slides x2
15. `.claude/extensions/present/skills/skill-talk/SKILL.md` - /talk -> /slides, talk.md -> slides.md
16. `.claude/extensions/present/context/project/present/domain/presentation-types.md` - /talk -> /slides
17. `.claude/extensions/present/agents/talk-agent.md` - any slash-command `/talk` references
18. `.claude/docs/reference/standards/extension-slim-standard.md` - example table row (optional, cosmetic)
19. `.claude/docs/guides/user-guide.md` - optional expansion of /convert section

### Standards Consulted
- @.claude/rules/workflows.md (command lifecycle pattern)
- @.claude/rules/error-handling.md
- @.claude/context/patterns/context-discovery.md (domain-specific command rules)
- @.claude/docs/reference/standards/extension-slim-standard.md (extension doc format)
