---
next_project_number: 382
---

# TODO

## Task Order

*Updated 2026-04-08. 7 active tasks remaining.*

### Pending

- **381** [NOT STARTED] -- Update manifest.json, index-entries.json, routing (depends: 378-380)
- **380** [COMPLETED] -- Create skill-meeting + meeting.md command (depends: 379)
- **379** [COMPLETED] -- Create meeting-agent (depends: 378)
- **378** [COMPLETED] -- Create meeting format context files
- **368** [COMPLETED] -- Create context documentation for Slidev custom formalism rendering
- **87** [RESEARCHED] -- Investigate terminal directory change in wezterm
- **78** [PLANNED] -- Fix Himalaya SMTP authentication failure

## Tasks

### 381. Update manifest.json, index-entries.json, and routing for /meeting command
- **Effort**: 30 minutes
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 378, 379, 380

**Description**: Register all /meeting components in the founder extension. Add meeting-agent.md to provides.agents, skill-meeting to provides.skills, meeting.md to provides.commands. Add founder:meeting routing entries for research/plan/implement phases. Add context entries to index-entries.json for meeting-format.md and csv-tracker.md with appropriate load_when conditions.

### 380. Create skill-meeting and meeting.md command
- **Effort**: 1 hour
- **Status**: [NOT STARTED]
- **Language**: meta
- **Dependencies**: 379

**Description**: Create skill-meeting/SKILL.md as thin wrapper routing to meeting-agent (following skill-legal pattern). Create commands/meeting.md with two modes: (1) `/meeting /path/to/notes.md` -- process raw meeting notes into structured investor meeting file + CSV update, (2) `/meeting --update /path/to/file.md` -- re-read existing meeting file and update CSV entry. Support task number input for resume. Follow the /legal command's Stage 0-2 pattern adapted for meeting processing (no forcing questions needed -- the notes file IS the input).

### 379. Create meeting-agent for investor meeting note processing
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: 378
- **Research**: [01_meeting-agent-research.md](379_meeting_agent/reports/01_meeting-agent-research.md)
- **Plan**: [01_meeting-agent-plan.md](379_meeting_agent/plans/01_meeting-agent-plan.md)

**Description**: Create .claude/extensions/founder/agents/meeting-agent.md following legal-council-agent pattern. The agent: (1) reads raw meeting notes markdown, (2) web-searches investor/company for profile data (fund size, team, thesis, portfolio), (3) generates structured meeting file with full YAML frontmatter (investor_name, website, fund_size, stage, geography, focus, check_size_min/max, team, pipeline_stage, meetings array, fit_score, strengths, gaps, action items) + markdown body (Investor Profile, Relationship Status, Fit Assessment, Meeting Log with feedback themes, Action Items, Strategic Notes, Raw Notes preservation), (4) locates CSV file in same directory, (5) adds/updates CSV entry from frontmatter metadata. Support --update mode for CSV-only updates from existing meeting files. Reference context: meeting-format.md template, csv-tracker.md format.

### 378. Create meeting format context files
- **Effort**: 1 hour
- **Status**: [COMPLETED]
- **Language**: meta
- **Dependencies**: None
- **Research**: [01_meeting-format-research.md](378_meeting_format_context_files/reports/01_meeting-format-research.md)
- **Plan**: [01_meeting-format-plan.md](378_meeting_format_context_files/plans/01_meeting-format-plan.md)

**Description**: Create two context files in .claude/extensions/founder/context/project/founder/: (1) templates/meeting-format.md -- meeting file template documenting the YAML frontmatter schema (all metadata fields from Halcyon/Celero examples) and markdown body structure (Investor Profile table, Relationship Status, Fit Assessment, Meeting Log with feedback themes, Action Items table, Strategic Notes, Raw Notes preservation section), (2) patterns/csv-tracker.md -- CSV format reference documenting column order, value formats, and update logic for the investor tracking spreadsheet. Based on exemplar files: /home/benjamin/Projects/Logos/Vision/investors/VC/2026-04-07_halcyon.md, 2026-04-08_celero.md, and VC-spreadsheet.csv.

### 377. Add ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Language**: neovim
- **Research**:
  - [01_team-research.md](specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/01_team-research.md)
  - [02_unified-keymap-research.md](specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/02_unified-keymap-research.md)
- **Plan**: [02_unified-keymap-plan.md](specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/plans/02_unified-keymap-plan.md)

**Description**: Add a ctrl-based keymapping (non-conflicting with existing bindings) for triggering dictation in Neovim. When inside the Claude Code sidebar, the keymap should directly load voice recording using current best practices (April 2026). Research existing ctrl keymaps to avoid conflicts and determine the optimal dictation/voice integration approach.

### 376. TTS notification: primary agent only with Notification hook support
- **Effort**: 30 minutes
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**: [01_tts-primary-agent-research.md](specs/376_tts_primary_agent_only_notification_hook/reports/01_tts-primary-agent-research.md)
- **Plan**: [01_tts-primary-agent.md](specs/376_tts_primary_agent_only_notification_hook/plans/01_tts-primary-agent.md)
- **Summary**: [01_tts-primary-agent-summary.md](specs/376_tts_primary_agent_only_notification_hook/summaries/01_tts-primary-agent-summary.md)

**Description**: Configure TTS announcements to fire only for the primary agent, not subagents. Add `agent_id` guard to `tts-notify.sh` (present only in subagent context) and add a `Notification` hook entry in `settings.json` for interactive feedback events (permission prompts, idle prompts, elicitation dialogs).

### 368. Create context documentation for Slidev custom formalism rendering
- **Effort**: 1-2 hours
- **Status**: [COMPLETED]
- **Language**: meta
- **Research**:
  - [01_slidev-custom-formalism.md](specs/368_context_docs_slidev_custom_formalism/reports/01_slidev-custom-formalism.md)
  - [02_team-research.md](specs/368_context_docs_slidev_custom_formalism/reports/02_team-research.md)
- **Plan**:
  - [01_slidev-custom-formalism.md](specs/368_context_docs_slidev_custom_formalism/plans/01_slidev-custom-formalism.md)
  - [02_slidev-custom-formalism.md](specs/368_context_docs_slidev_custom_formalism/plans/02_slidev-custom-formalism.md)
- **Summary**: [02_slidev-custom-formalism-summary.md](specs/368_context_docs_slidev_custom_formalism/summaries/02_slidev-custom-formalism-summary.md)

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

1. **377** [PLANNED] -> implement
