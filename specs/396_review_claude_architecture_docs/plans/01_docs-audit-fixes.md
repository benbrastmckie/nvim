# Implementation Plan: .claude/ Architecture Documentation Audit and Fixes

- **Task**: 396 - review_claude_architecture_docs
- **Status**: [NOT STARTED]
- **Effort**: 11 hours
- **Dependencies**: None
- **Research Inputs**: specs/396_review_claude_architecture_docs/reports/01_team-research.md
- **Artifacts**: plans/01_docs-audit-fixes.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/docs/reference/standards/agent-frontmatter-standard.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `.claude/` agent system has a systemic documentation deficit across three domains: missing extension READMEs (11 of 14 extensions), core-doc drift (stale references and missing entries in `README.md`/`CLAUDE.md`/`skill-agent-mapping.md`), and template/frontmatter rot. This plan executes a three-tier remediation: Tier 1 tackles the explicitly requested `filetypes/README.md` plus surgical core-doc fixes, Tier 2 adds READMEs for five complex extensions (`lean`, `formal`, `nvim`, `nix`, `web`), and Tier 3 adds simple-extension READMEs plus template/guide cleanup. Definition of done: every extension has a README, all cross-reference drift identified in research is fixed, stale templates are rewritten or removed, and a doc-lint script prevents regression.

### Research Integration

The plan directly implements the three-tier scope resolution from the team research synthesis. The reference-model conflict (user's `present/README.md` vs. teammates' `founder/README.md`) is resolved by adopting `founder/README.md` as the canonical template with a section-applicability matrix: simple extensions omit sections and produce terse READMEs in the spirit of `present/README.md`, while complex extensions use the full structure. Blocker items from Finding 5 (lean manifest scripts), Finding 6 (formal research-only pattern), Finding 8 (Co-Authored-By convention conflict), and the duplicate doc-standards file are folded into explicit decision points in Phase 1.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` is empty. Phase 10 of this plan populates it with documentation-infrastructure items surfaced during research (doc-lint automation, manifest-driven generation, marketplace metadata).

## Goals & Non-Goals

**Goals**:
- Every `.claude/extensions/*/` directory has a README.md appropriate to its complexity
- All cross-reference drift identified in Finding 4 of the research is fixed
- Stale templates (agent/command/subagent) and the `creating-commands.md` guide are either rewritten to current format or removed
- `code-reviewer-agent.md` frontmatter migrated to current standard
- `.claude/CLAUDE.md` commit convention aligned with user's stored Co-Authored-By preference
- Duplicate documentation-standards files consolidated
- Doc-lint script prevents future regression of extension README gaps
- ROADMAP.md populated with remaining documentation-infrastructure items

**Non-Goals**:
- Manifest-driven README generation (deferred as roadmap item)
- Marketplace metadata for extensions (deferred as roadmap item)
- Rewriting extension functionality or restructuring routing
- Touching agent/skill/command logic -- this is documentation-only
- Creating README.md for `.claude/` subdirectories other than extensions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| User decisions on lean scripts, formal pattern, duplicate standards block progress | M | H | Consolidate decisions into a single Phase 1 decision checkpoint; proceed with Tier 1 surgical fixes regardless |
| Founder-template READMEs drift from evolving extensions | M | M | Phase 9 doc-lint script flags manifest/README drift; keep READMEs thin on implementation detail |
| Rewriting stale templates breaks implicit references from docs | M | L | Grep for template path references before deletion; update or preserve path names |
| Co-Authored-By convention change affects historical consistency | L | L | Change is forward-only; historical commits unaffected |
| Tier 3 bloat eats into Tier 1 quality | M | M | Strict phase ordering; Tier 1 fully validated before Tier 2 begins |
| Removing duplicate `documentation.md`/`documentation-standards.md` breaks @-references | M | M | Grep for both filenames across `.claude/` before consolidation; update all references in same commit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2 |
| 4 | 6, 7 | 5 |
| 5 | 8, 9, 10 | 6, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Decision Checkpoint and Baseline [NOT STARTED]

**Goal**: Resolve research-surfaced open questions before writing docs, and capture the baseline of current file state.

**Tasks**:
- [ ] Present user with 6 decisions: (a) lean extension scripts (remove from manifest vs. restore files), (b) formal research-only pattern (document as intentional vs. treat as bug), (c) duplicate documentation standards files (which is canonical), (d) stale templates (rewrite vs. delete), (e) Co-Authored-By convention update, (f) scope tier endorsement (Tier 1 only, 1+2, or full 1+2+3)
- [ ] Inventory current extension README status with a one-shot check
- [ ] Grep `.claude/` for references to `documentation.md`, `documentation-standards.md`, `agent-template.md`, `command-template.md`, `subagent-template.md`, `subagent-return-format.md`, `creating-commands.md` to map the blast radius of template/guide changes
- [ ] Record decisions and baseline inventory in `specs/396_review_claude_architecture_docs/reports/02_decisions.md`

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `specs/396_review_claude_architecture_docs/reports/02_decisions.md` - create decision record

**Verification**:
- Decision record exists with user responses to all 6 items
- Baseline inventory captures current state of each extension's README
- Blast-radius grep results logged for each stale filename

---

### Phase 2: Tier 1 -- Core-Doc Surgical Drift Fixes [NOT STARTED]

**Goal**: Apply all surgical fixes from Finding 4 of the research to core `.claude/` documentation.

**Tasks**:
- [ ] Add `reviser-agent` row to the agents table in `.claude/README.md`
- [ ] Add `plan-format-enforcement.md` entry to Rules References in `.claude/CLAUDE.md`
- [ ] Fix `.claude/context/reference/README.md`: rename `state-json-schema.md` reference to `state-management-schema.md`; add entries for `artifact-templates.md` and `workflow-diagrams.md`
- [ ] Add `skill-reviser`, `skill-spawn`, `skill-git-workflow`, `skill-orchestrator`, `skill-fix-it` to `.claude/context/reference/skill-agent-mapping.md`
- [ ] Fix `subagent-return-format.md` -> `subagent-return.md` references in `.claude/docs/templates/README.md`
- [ ] Add `guides/development/` subdirectory to the tree diagram in `.claude/docs/README.md`
- [ ] Remove `Co-Authored-By` trailer from the commit convention example block in `.claude/CLAUDE.md` (honors user memory)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/README.md` - add reviser-agent entry
- `.claude/CLAUDE.md` - add rule ref, remove Co-Authored-By from convention
- `.claude/context/reference/README.md` - fix filenames and add missing entries
- `.claude/context/reference/skill-agent-mapping.md` - add 5 missing skills
- `.claude/docs/templates/README.md` - fix filename reference
- `.claude/docs/README.md` - update tree diagram

**Verification**:
- Grep for `state-json-schema.md` returns no results
- Grep for `subagent-return-format.md` returns no results
- Grep for `reviser-agent` in `.claude/README.md` finds the new entry
- Grep for `plan-format-enforcement.md` in `.claude/CLAUDE.md` finds the new entry

---

### Phase 3: Tier 1 -- Code-Reviewer Frontmatter Migration [NOT STARTED]

**Goal**: Migrate `code-reviewer-agent.md` to the current minimal frontmatter standard and verify no other agents have the same rot.

**Tasks**:
- [ ] Read `.claude/docs/reference/standards/agent-frontmatter-standard.md` to confirm current required fields (`name`, `description`, `model`)
- [ ] Rewrite the frontmatter block in `.claude/agents/code-reviewer-agent.md` to match the standard; remove obsolete `mode`, `temperature`, `tools` block fields
- [ ] Grep all other agent files in `.claude/agents/` for obsolete fields (`mode: subagent`, `temperature:`, `max_tokens:`) to detect any additional drift
- [ ] Fix any additional agents surfaced by the grep

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/agents/code-reviewer-agent.md` - rewrite frontmatter
- Any other agent files flagged by grep

**Verification**:
- `code-reviewer-agent.md` frontmatter matches standard exactly
- Grep for `mode: subagent` across `.claude/agents/` returns no results
- Grep for `temperature:` in agent frontmatter returns no results

---

### Phase 4: Tier 1 -- filetypes/README.md [NOT STARTED]

**Goal**: Create `.claude/extensions/filetypes/README.md` using the full founder-style template.

**Tasks**:
- [ ] Read `.claude/extensions/founder/README.md` as canonical template reference
- [ ] Read `.claude/extensions/filetypes/manifest.json` and `EXTENSION.md` to enumerate commands, skills, agents, MCP servers
- [ ] Write `filetypes/README.md` with: Overview (5 commands capability table), Installation (`<leader>ac`), MCP Tool Setup (superdoc, openpyxl -- include exact npx commands), Commands section (one subsection per `/convert`, `/table`, `/slides`, `/scrape`, `/edit`), Architecture tree (6 agents, 5 skills, 5 commands, context structure), Skill-Agent Mapping table (explicitly note `skill-filetypes` dispatches to `filetypes-router-agent` and `document-agent`), Language Routing, Workflow diagram, Output Artifacts table, Key Patterns, Tool Dependencies (markitdown, pandoc, python-pptx), References
- [ ] Cross-verify README content against `manifest.json` to ensure no drift at birth

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/filetypes/README.md` - create new

**Verification**:
- README exists and renders cleanly in a markdown preview
- All 5 commands documented
- MCP servers have copy-pasteable install commands
- Skill-agent mapping explicitly notes the dual-agent dispatch
- All sections from the founder template are present

---

### Phase 5: Tier 1 -- Stale Template and Guide Resolution [NOT STARTED]

**Goal**: Apply the Phase 1 decision on stale templates and the `creating-commands.md` guide -- either rewrite to current format or remove.

**Tasks**:
- [ ] If decision = rewrite: update `.claude/docs/templates/agent-template.md` to match current minimal frontmatter (`name`, `description`, `model`); update `.claude/docs/templates/command-template.md` to document real frontmatter (`description:`, `allowed-tools:`, `argument-hint:`, `model:`); update `.claude/context/templates/agent-template.md` similarly; replace XML-block `.claude/context/templates/subagent-template.md` with current format
- [ ] If decision = delete: remove all four stale template files; update any references found in Phase 1 grep
- [ ] Rewrite `.claude/docs/guides/creating-commands.md` to remove all OpenAgents / v6.1 hybrid-architecture language; document the current checkpoint-based command pattern (GATE IN -> DELEGATE -> GATE OUT -> COMMIT)
- [ ] Consolidate `.claude/context/standards/documentation.md` and `documentation-standards.md` per Phase 1 decision: merge into the chosen canonical file, delete the other, update all @-references across `.claude/`

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/docs/templates/agent-template.md`
- `.claude/docs/templates/command-template.md`
- `.claude/context/templates/agent-template.md`
- `.claude/context/templates/subagent-template.md`
- `.claude/docs/guides/creating-commands.md`
- `.claude/context/standards/documentation.md` or `documentation-standards.md` (one deleted, one updated)
- Any files referencing the above (from Phase 1 blast-radius grep)

**Verification**:
- No template file documents `mode:`, `temperature:`, or `max_tokens:` fields
- Grep for "OpenAgents" and "v6.1 hybrid" returns no results
- Only one documentation-standards file remains
- All @-references resolve to existing files

---

### Phase 6: Tier 2 -- Complex Extension READMEs [NOT STARTED]

**Goal**: Create README.md for the five complex extensions using the founder-style full template.

**Tasks**:
- [ ] Create `.claude/extensions/lean/README.md`: MCP setup (lean-lsp), lake build workflow, rules references, 4 language routing if present, reference lean-lsp tool guidance
- [ ] Create `.claude/extensions/formal/README.md`: 4-language routing (formal, logic, math, physics); **explicitly document the research-only pattern** -- note that `/implement` falls through to `general-implementation-agent` and this is intentional
- [ ] Create `.claude/extensions/nvim/README.md`: self-referential importance, highest-traffic extension, Neovim-specific skills and agents, test protocols
- [ ] Create `.claude/extensions/nix/README.md`: mcp-nixos MCP setup, NixOS/nix-darwin patterns, nix flake workflow
- [ ] Create `.claude/extensions/web/README.md`: `/tag` command (user-only), rules, skills, web-specific patterns
- [ ] Each README cross-verified against its own `manifest.json` and `EXTENSION.md`

**Timing**: 3 hours

**Depends on**: 5

**Files to modify**:
- `.claude/extensions/lean/README.md` - create
- `.claude/extensions/formal/README.md` - create
- `.claude/extensions/nvim/README.md` - create
- `.claude/extensions/nix/README.md` - create
- `.claude/extensions/web/README.md` - create

**Verification**:
- All 5 files exist
- Each README's command/skill/agent lists match its manifest
- `formal/README.md` explicitly explains the research-only pattern
- MCP-using extensions have copy-pasteable install instructions

---

### Phase 7: Tier 3 -- Simple Extension READMEs [NOT STARTED]

**Goal**: Create terse present-style README.md for the five simple extensions.

**Tasks**:
- [ ] Create `.claude/extensions/latex/README.md` (present-style: Overview, Installation, Commands, Skill-Agent Mapping, Language Routing)
- [ ] Create `.claude/extensions/python/README.md` (present-style)
- [ ] Create `.claude/extensions/typst/README.md` (present-style)
- [ ] Create `.claude/extensions/z3/README.md` (present-style)
- [ ] Create `.claude/extensions/epidemiology/README.md` (present-style)
- [ ] Each README cross-verified against its own manifest

**Timing**: 1.5 hours

**Depends on**: 5

**Files to modify**:
- `.claude/extensions/latex/README.md` - create
- `.claude/extensions/python/README.md` - create
- `.claude/extensions/typst/README.md` - create
- `.claude/extensions/z3/README.md` - create
- `.claude/extensions/epidemiology/README.md` - create

**Verification**:
- All 5 files exist, each under ~120 lines
- Each README section applicability matches the matrix from research synthesis §1
- No drift from manifest content

---

### Phase 8: Tier 3 -- Extension README Template and Creating-Extensions Guide [NOT STARTED]

**Goal**: Codify the template pattern so future extensions produce README.md by default.

**Tasks**:
- [ ] Create `.claude/templates/extension-readme-template.md` derived from `founder/README.md` with the section-applicability matrix from research synthesis §1 embedded as a comment block at the top
- [ ] Update `.claude/docs/guides/creating-extensions.md` to require README.md as a standard deliverable, referencing the template
- [ ] If creating-extensions.md does not exist, note this in the Artifacts section and skip

**Timing**: 45 minutes

**Depends on**: 6, 7

**Files to modify**:
- `.claude/templates/extension-readme-template.md` - create
- `.claude/docs/guides/creating-extensions.md` - update (if exists)

**Verification**:
- Template file exists with both simple and complex section guidance
- creating-extensions.md references the template as a required deliverable
- Template matches the structure used in Phases 4, 6, and 7

---

### Phase 9: Doc-Lint Script [NOT STARTED]

**Goal**: Add a script that flags missing or stale extension documentation, preventing regression.

**Tasks**:
- [ ] Create `.claude/scripts/check-extension-docs.sh` that iterates `.claude/extensions/*/` and flags: missing README.md, missing EXTENSION.md, manifest entries referencing nonexistent files (e.g., the lean scripts case from Finding 5), README.md older than manifest.json, and commands listed in manifest but not in README
- [ ] Script exits non-zero on failures and prints a summary table
- [ ] Make the script executable
- [ ] Run the script against the post-Phase-7 state to confirm all extensions pass
- [ ] Document the script in `.claude/CLAUDE.md` Utility Scripts table

**Timing**: 1.25 hours

**Depends on**: 6, 7

**Files to modify**:
- `.claude/scripts/check-extension-docs.sh` - create
- `.claude/CLAUDE.md` - add to Utility Scripts table

**Verification**:
- Script runs cleanly with exit code 0 against current state
- Manually breaking one README (e.g., removing a command) causes exit code 1
- CLAUDE.md lists the script under Utility Scripts

---

### Phase 10: ROADMAP Population and Final Verification [NOT STARTED]

**Goal**: Populate the empty ROADMAP.md with deferred documentation-infrastructure items and perform final cross-reference verification.

**Tasks**:
- [ ] Populate `specs/ROADMAP.md` with documentation-infrastructure roadmap items surfaced in research: manifest-driven README generation, marketplace metadata for extensions, CI enforcement of doc-lint script, integration with `/review` command
- [ ] Run doc-lint script one final time
- [ ] Grep `.claude/` for any remaining references to deleted/renamed files (`state-json-schema.md`, `subagent-return-format.md`, OpenAgents, v6.1 hybrid, Co-Authored-By)
- [ ] Verify all Phase 1 decision items are resolved in the final state
- [ ] Write execution summary to `specs/396_review_claude_architecture_docs/summaries/01_execution-summary.md`

**Timing**: 45 minutes

**Depends on**: 8, 9

**Files to modify**:
- `specs/ROADMAP.md` - populate
- `specs/396_review_claude_architecture_docs/summaries/01_execution-summary.md` - create

**Verification**:
- ROADMAP.md contains at least 4 documentation-infrastructure items
- Final doc-lint run is clean
- No stale references to removed/renamed files remain in `.claude/`
- Execution summary documents all phases and any decisions deferred

---

## Testing & Validation

- [ ] `bash .claude/scripts/check-extension-docs.sh` exits 0 against the final state
- [ ] `grep -r "state-json-schema" .claude/` returns no results
- [ ] `grep -r "subagent-return-format" .claude/` returns no results
- [ ] `grep -r "OpenAgents\|v6.1 hybrid" .claude/` returns no results
- [ ] `grep -r "mode: subagent" .claude/agents/` returns no results
- [ ] All 14 extensions have a README.md file
- [ ] `filetypes/README.md` documents all 5 commands, both MCP servers, and the dual-agent dispatch for `skill-filetypes`
- [ ] `formal/README.md` explicitly documents the research-only pattern
- [ ] `.claude/CLAUDE.md` commit convention block no longer contains `Co-Authored-By`
- [ ] `reviser-agent` appears in `.claude/README.md` agents table
- [ ] `plan-format-enforcement.md` appears in `.claude/CLAUDE.md` rules references
- [ ] All cross-references in `.claude/context/reference/README.md` and `skill-agent-mapping.md` resolve to existing files

## Artifacts & Outputs

- `specs/396_review_claude_architecture_docs/reports/02_decisions.md` - decision record from Phase 1
- `.claude/extensions/filetypes/README.md` - Tier 1 primary deliverable
- `.claude/extensions/{lean,formal,nvim,nix,web}/README.md` - Tier 2 complex extensions
- `.claude/extensions/{latex,python,typst,z3,epidemiology}/README.md` - Tier 3 simple extensions
- `.claude/templates/extension-readme-template.md` - Tier 3 reusable template
- `.claude/scripts/check-extension-docs.sh` - Tier 3 lint script
- `.claude/README.md`, `.claude/CLAUDE.md`, `.claude/context/reference/README.md`, `.claude/context/reference/skill-agent-mapping.md`, `.claude/docs/templates/README.md`, `.claude/docs/README.md` - updated with drift fixes
- `.claude/agents/code-reviewer-agent.md` - frontmatter migration
- `.claude/docs/templates/{agent,command}-template.md`, `.claude/context/templates/{agent,subagent}-template.md` - rewritten or removed
- `.claude/docs/guides/creating-commands.md` - rewritten or removed per decision
- `.claude/docs/guides/creating-extensions.md` - updated (if exists)
- `.claude/context/standards/documentation.md` or `documentation-standards.md` - consolidated
- `specs/ROADMAP.md` - populated with doc-infrastructure items
- `specs/396_review_claude_architecture_docs/summaries/01_execution-summary.md` - final summary

## Rollback/Contingency

All changes are documentation-only -- no runtime behavior is affected. Rollback is `git revert` on the task's commits. Because phases are committed incrementally (one commit per phase per the `task {N}: phase {P}` convention), individual phases can be reverted without losing others. If Phase 2 (core-doc fixes) introduces broken @-references discovered later, those specific lines can be reverted while preserving the rest of the phase. The doc-lint script in Phase 9 is the long-term rollback safety net: any future change that breaks extension docs will fail the script, surfacing drift before it becomes entrenched.
