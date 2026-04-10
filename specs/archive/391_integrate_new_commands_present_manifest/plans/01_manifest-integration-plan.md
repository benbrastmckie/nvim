# Implementation Plan: Task #391

- **Task**: 391 - Integrate new commands into present extension manifest
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: 387, 388, 389, 390 (all completed)
- **Research Inputs**: specs/391_integrate_new_commands_present_manifest/reports/01_manifest-integration.md
- **Artifacts**: plans/01_manifest-integration-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task registers four new commands (/budget, /timeline, /funds, /talk) and their associated agents, skills, and context files into the present extension's manifest, index, and documentation files. Tasks 387-390 each created complete command stacks but did not update the extension registration files, leaving the new commands invisible to the routing system.

### Research Integration

The research report identified 5 files requiring updates: manifest.json (provides + routing), index-entries.json (9 new context files), EXTENSION.md (skill-agent table, commands table, language routing), README.md (overview and command docs), and opencode-agents.json (4 new agent entries). The report recommends using `present` as the base language with subtypes (`present:budget`, `present:timeline`, etc.) following the founder extension pattern.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Register all 4 new agents, skills, and commands in manifest.json provides
- Add routing entries for research/plan/implement phases using present:subtype pattern
- Add index entries for all 9 new context files with appropriate load_when selectors
- Update EXTENSION.md with complete skill-agent, commands, and language routing tables
- Update README.md with all 5 commands documented
- Add 4 new agent entries to opencode-agents.json

**Non-Goals**:
- Adding talk library files as individual index entries (the talk library has its own index.json)
- Modifying existing grant entries to use `present:grant` language (keep backward compatibility)
- Fixing budget-agent missing model field (separate concern)
- Changing any agent, skill, or command implementation files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| JSON syntax error in manifest or index | H | L | Validate JSON after each edit with jq |
| Routing key mismatch with existing grant flow | M | M | Keep existing `grant` routing key as-is, add `present:grant` alias |
| Inconsistent load_when selectors | M | L | Follow established pattern from existing grant entries |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Update manifest.json [COMPLETED]

**Goal**: Register all new agents, skills, commands in provides and add routing entries

**Tasks**:
- [ ] Add 4 agents to provides.agents: budget-agent.md, timeline-agent.md, funds-agent.md, talk-agent.md
- [ ] Add 4 skills to provides.skills: skill-budget, skill-timeline, skill-funds, skill-talk
- [ ] Add 4 commands to provides.commands: budget.md, timeline.md, funds.md, talk.md
- [ ] Add routing.research section with present base + 5 subtype entries
- [ ] Add routing.plan section with present base + 5 subtype entries
- [ ] Expand routing.implement with present base + 4 new subtype entries (keep existing grant entry)
- [ ] Validate resulting JSON with jq

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/manifest.json` - Add provides entries and routing sections

**Verification**:
- `jq . manifest.json` parses without error
- All 5 agents, 5 skills, 5 commands listed in provides
- routing has research, plan, implement sections with present:* keys

---

### Phase 2: Update index-entries.json [COMPLETED]

**Goal**: Add index entries for all 9 new context files with command-specific load_when

**Tasks**:
- [ ] Add entry for `project/present/domain/grant-budget-frameworks.md` (budget, 215 lines)
- [ ] Add entry for `project/present/patterns/budget-forcing-questions.md` (budget, 260 lines)
- [ ] Add entry for `project/present/domain/research-timelines.md` (timeline, 266 lines)
- [ ] Add entry for `project/present/patterns/timeline-patterns.md` (timeline, 151 lines)
- [ ] Add entry for `project/present/templates/timeline-template.md` (timeline, 197 lines)
- [ ] Add entry for `project/present/domain/funding-analysis.md` (funds, 275 lines)
- [ ] Add entry for `project/present/patterns/funding-forcing-questions.md` (funds, 337 lines)
- [ ] Add entry for `project/present/domain/presentation-types.md` (talk, 113 lines)
- [ ] Add entry for `project/present/patterns/talk-structure.md` (talk, 106 lines)
- [ ] Each entry uses load_when with appropriate languages, agents, and commands arrays
- [ ] Validate resulting JSON with jq

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add 9 new context file entries

**Verification**:
- `jq . index-entries.json` parses without error
- Total entries = 17 (existing) + 9 (new) = 26
- Each new entry has correct load_when with matching agent and command

---

### Phase 3: Update EXTENSION.md, README.md, and opencode-agents.json [COMPLETED]

**Goal**: Update all documentation and OpenCode agent registration

**Tasks**:
- [ ] EXTENSION.md: Add budget-agent, timeline-agent, funds-agent to skill-agent table (talk-agent already present)
- [ ] EXTENSION.md: Add /budget, /timeline, /funds command entries to commands table with usage and description
- [ ] EXTENSION.md: Add present:budget, present:timeline, present:funds rows to language routing table
- [ ] EXTENSION.md: Update extension description to mention budget, timeline, funds, talk capabilities
- [ ] README.md: Update overview table with /budget, /timeline, /funds, /talk rows
- [ ] README.md: Add command subsections for each new command with usage examples
- [ ] README.md: Update related files section with new context file references
- [ ] README.md: Update table of contents
- [ ] opencode-agents.json: Add budget, timeline, funds, talk agent entries following grant pattern
- [ ] Validate opencode-agents.json with jq

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md` - Expand tables and add command docs
- `.claude/extensions/present/README.md` - Add all new commands to docs
- `.claude/extensions/present/opencode-agents.json` - Add 4 new agent entries

**Verification**:
- EXTENSION.md skill-agent table has 5 rows (grant, budget, timeline, funds, talk)
- EXTENSION.md commands table has entries for all 5 commands
- README.md overview table has 5 rows
- opencode-agents.json has 5 agent entries and parses with jq

---

### Phase 4: Cross-File Validation [COMPLETED]

**Goal**: Verify consistency across all modified files

**Tasks**:
- [ ] Verify manifest.json provides arrays match actual files in agents/, skills/, commands/ directories
- [ ] Verify routing keys are consistent across research/plan/implement sections
- [ ] Verify index-entries.json agent names match agent filenames (minus .md)
- [ ] Verify index-entries.json command names match command filenames (minus .md, with / prefix)
- [ ] Verify EXTENSION.md language routing table matches manifest.json routing
- [ ] Verify opencode-agents.json agent names match agents/ directory contents

**Timing**: 0.25 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- None (read-only validation), minor fixes if inconsistencies found

**Verification**:
- All cross-references are consistent
- No orphaned or missing entries

## Testing & Validation

- [ ] All JSON files parse without error (jq validation)
- [ ] manifest.json provides lists all 5 agents, 5 skills, 5 commands
- [ ] manifest.json routing covers research/plan/implement for all present subtypes
- [ ] index-entries.json has 26 total entries with correct load_when selectors
- [ ] EXTENSION.md documents all 5 commands with skill-agent mappings
- [ ] README.md documents all 5 commands with usage examples
- [ ] opencode-agents.json has 5 agent entries

## Artifacts & Outputs

- `.claude/extensions/present/manifest.json` (modified)
- `.claude/extensions/present/index-entries.json` (modified)
- `.claude/extensions/present/EXTENSION.md` (modified)
- `.claude/extensions/present/README.md` (modified)
- `.claude/extensions/present/opencode-agents.json` (modified)

## Rollback/Contingency

All files are tracked in git. If implementation fails, revert with `git checkout -- .claude/extensions/present/`. The existing grant command will continue working regardless since its routing key is preserved.
