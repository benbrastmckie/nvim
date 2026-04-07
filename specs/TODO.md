---
next_project_number: 370
---

# TODO

## Task Order

*Updated 2026-04-07. 3 active tasks remaining.*

### Pending

- **369** [PLANNED] -- Integrate ROAD_MAP.md consultation into research/planning agents
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 369. Integrate ROAD_MAP.md consultation into research and planning agents
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Research Completed**: 2026-04-07
- **Language**: meta
- **Dependencies**: None
- **Research**:
  - [01_roadmap-integration-gaps.md](369_roadmap_integration_research_planning/reports/01_roadmap-integration-gaps.md)
  - [02_team-research-roles.md](369_roadmap_integration_research_planning/reports/02_team-research-roles.md)
- **Plan**: [02_roadmap-integration.md](369_roadmap_integration_research_planning/plans/02_roadmap-integration.md)

**Description**: Research and planning agents (`general-research-agent`, `planner-agent`) are completely blind to `specs/ROAD_MAP.md`, causing repeated misalignment with project priorities. Fix by: (1) adding a roadmap consultation stage to `general-research-agent.md` (read-only, for strategic context); (2) adding a roadmap alignment stage to `planner-agent.md` (read roadmap, align plan phases, pre-populate `roadmap_items`); (3) updating `context/index.json` `load_when` entries for `formats/roadmap-format.md` and `patterns/roadmap-update.md` to include research/planning agents and commands; (4) adding `roadmap_path` to delegation contexts in `skill-researcher/SKILL.md` and `skill-planner/SKILL.md`. Files: 5 files across agents/, skills/, and context/.

---

### 368. Create context documentation for Slidev custom formalism rendering
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Language**: meta

**Description**: Create context documentation for custom formalism rendering in Slidev presentations. The founder extension's slidev-deck-template.md currently has no documentation about rendering custom mathematical notation. Based on research of the Logos Vision deck (strategy/02-deck/slidev/), the following patterns need to be documented in the founder extension context: (1) LogosOp.vue component -- SVG-based inline operators (boxright, diamondright, circleright, dotcircleright) using currentColor inheritance, 28x16 viewBox, baseline alignment at -0.1em; (2) KaTex.vue component -- KaTeX wrapper with custom macro preprocessing, placeholder substitution to inject SVGs into KaTeX-rendered HTML, props: expr (string), display (boolean); (3) KaTeX macro configuration (setup/katex.ts) -- defines \boxright, \diamondright, \circleright, \dotcircleright macros using \mathrel with \htmlStyle overlap technique as fallback; (4) Unicode HTML entity patterns -- standard operators rendered via HTML entities wrapped in font-serif spans; (5) Dual rendering decision tree -- when to use LogosOp (plain text/HTML context) vs KaTex.vue (mathematical expressions) vs HTML entities (standard Unicode symbols). Files to modify: slidev-deck-template.md (add custom formalism section), deck/README.md (add component docs for LogosOp and KaTex), index-entries.json (add index entries if separate file created), possibly create custom-formalism-patterns.md if content is too large for the template. Source material: /home/benjamin/Projects/Logos/Vision/strategy/02-deck/slidev/components/LogosOp.vue, KaTex.vue, and setup/katex.ts.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
 **Effort**: TBD
 **Status**: [RESEARCHED]
 **Research Started**: 2026-02-13
 **Research Completed**: 2026-02-13
 **Language**: neovim
 **Dependencies**: None
 **Research**: [research-001.md](087_investigate_wezterm_terminal_directory_change/reports/research-001.md)

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

## Recommended Order

