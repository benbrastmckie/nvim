---
next_project_number: 345
---

# TODO

## Task Order

*Updated 2026-03-31. 11 active tasks remaining.*

### Pending

- **340** [RESEARCHED] -- Create reusable typst slide deck templates
- **341** [NOT STARTED] -- /deck command and deck-research-agent integration
- **342** [NOT STARTED] -- Deck planner with interactive style/content questions (depends: 340, 341)
- **343** [NOT STARTED] -- Deck builder typst agent (depends: 340, 342)
- **344** [NOT STARTED] -- Migrate deck from present/ to founder/ extension (depends: 341, 342, 343)
- **336** [COMPLETED] -- Fix TODO.md status update bug in skill-implementer
- **338** [COMPLETED] -- Consolidate duplicated references across .claude/ files
- **337** [COMPLETED] -- Condense skill-implementer verbosity (depends: 336)
- **339** [COMPLETED] -- Reduce agent boilerplate (depends: 338)
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 340. Create reusable typst slide deck templates
- **Effort**: Medium
- **Status**: [RESEARCHED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_typst-deck-templates.md](340_create_typst_deck_templates/reports/01_typst-deck-templates.md)

**Description**: Create 3-4 reusable typst slide deck templates in `founder/context/project/founder/templates/typst/` for the deck workflow. Templates should use touying 0.6.3 with different visual styles (minimal, professional, dark, startup). Each template defines: slide structure (10 main slides + appendix), color palettes, typography (24pt+ body, 40pt+ titles per YC compliance), and 16:9 aspect ratio. Reference `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/deck-source.typ` as the basic/minimal template. Templates must be self-contained and parameterizable for the deck-planner to reference during planning.

---

### 341. /deck command and deck-research-agent integration
- **Effort**: Medium
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: None

**Description**: Create the `/deck` command in `founder/commands/deck.md` that accepts a path, prompt, or task number. When given a description or path, it creates a task with `language: founder, task_type: deck` and generates a research report from the provided materials. Create `deck-research-agent` in `founder/agents/` and `skill-deck-research` in `founder/skills/` for researching deck content. Add `founder:deck` research routing to `founder/manifest.json`. Add deck-specific index entries to `founder/index-entries.json`. The research agent should synthesize input materials (files, prompts, task references) into a structured research report suitable for the deck-planner to consume.

---

### 342. Deck planner with interactive style/content questions
- **Effort**: Large
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 340, 341

**Description**: Create `deck-planner-agent` in `founder/agents/` and `skill-deck-plan` in `founder/skills/`. The planner begins with interactive AskUserQuestion flow: (1) select a visual style from available templates, (2) choose which slide contents to include in the main 10 slides vs appendix slides from research findings, (3) select slide ordering from a few different arrangement options. After questions, generate a plan conforming to `plan-format.md` that specifies the typst template to use, slide-by-slide content assignments, and appendix contents. Add `founder:deck` plan routing to `founder/manifest.json` (overriding the shared `skill-founder-plan` for deck type).

---

### 343. Deck builder typst agent
- **Effort**: Medium
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 340, 342

**Description**: Create `deck-builder-agent` in `founder/agents/` and `skill-deck-implement` in `founder/skills/`. The builder reads the plan, selects the specified typst template, and generates a complete `.typ` file with 10 main slides and optional appendix slides. Compiles to PDF via `typst compile`. Add `founder:deck` implement routing to `founder/manifest.json` (overriding the shared `skill-founder-implement` for deck type). Output goes to `strategy/{slug}-deck.typ` and `strategy/{slug}-deck.pdf`.

---

### 344. Migrate deck from present/ to founder/ extension
- **Effort**: Small
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 341, 342, 343

**Description**: Remove deck functionality from `present/` extension and finalize founder integration. Remove `skill-deck`, `deck-agent`, and `deck.md` command from `present/`. Move relevant context files (pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md) to `founder/context/`. Update `present/EXTENSION.md` to remove deck routing and skill-agent mapping. Update `present/manifest.json` to remove deck references. Update `present/index-entries.json` to remove deck entries. Update `founder/EXTENSION.md` to add deck command documentation and routing table entries.

---

### 336. Fix TODO.md status update bug in skill-implementer
- **Effort**: Small
- **Status**: [COMPLETED]
- **Completed**: 2026-03-31
- **Language**: meta
- **Dependencies**: None
- **Summary**: Converted buried prose instructions to prominent structured Edit patterns in skill-implementer; added defensive TODO.md status check in implement.md GATE OUT

**Description**: The skill-implementer postflight (Stage 7, line 295) has a single prose instruction to update TODO.md status from [IMPLEMENTING] to [COMPLETED] that gets skipped because it's sandwiched between code blocks. Fix: (1) Convert the TODO.md status update to a scripted pattern or prominent instruction block, (2) Add defensive TODO.md status check in implement.md GATE OUT (currently only checks state.json), (3) Consider a shared update-task-status.sh script for atomic TODO.md+state.json updates.

---

### 337. Condense skill-implementer verbosity
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 336

**Description**: Restructure skill-implementer/SKILL.md so critical instructions are prominent rather than buried prose between code blocks. Apply same pattern to other verbose skills (skill-fix-it at 1005 lines, skill-todo at 926 lines). Key changes: elevate all TODO.md/state.json update instructions to consistent format (code blocks or explicit step markers), remove redundant explanations that duplicate rules/ files, reduce total line count while preserving all functional instructions.

---

### 338. Consolidate duplicated references across .claude/ files
- **Effort**: Medium
- **Status**: [COMPLETED]
- **Completed**: 2026-03-31
- **Language**: meta
- **Dependencies**: None
- **Summary**: Removed 481 lines (27%) across 4 agent files by consolidating Stage 0, context discovery, error handling, and return format examples into cross-references

**Description**: Unify information that's duplicated across multiple files into single canonical sources: (1) Status markers defined in 4+ files -> single reference, (2) Artifact path explanations in 5+ places -> single reference, (3) Error handling re-explained in 12+ files -> cross-reference to error-handling.md, (4) Context discovery jq pattern duplicated in every agent -> shared template or include reference. Replace duplicates with cross-references to canonical sources. Target: eliminate ~800-1200 lines of redundancy.

---

### 339. Reduce agent boilerplate across all agents
- **Effort**: Medium-Large
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 338

**Description**: Extract repeated boilerplate from 6 agent files (~100-150 lines each = 600-900 total). Repeated sections: Stage 0 (early metadata), Stage 1 (parse delegation), context discovery jq queries, error handling sections, artifact path explanations. Create a base-agent template or shared-sections pattern that agents can reference. Preserve agent-specific execution stages while eliminating structural repetition.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Started**: 2026-02-13
- **Research Completed**: 2026-02-13
- **Planning Started**: 2026-02-13
- **Planning Completed**: 2026-02-13
- **Language**: neovim
- **Dependencies**: None
- **Research**: [research-001.md](078_fix_himalaya_smtp_authentication_failure/reports/research-001.md)
- **Plan**: [implementation-001.md](078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md)

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: "Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted". The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.

---
