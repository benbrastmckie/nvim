# Research Report: Task #344

**Task**: 344 - migrate_deck_present_to_founder
**Started**: 2026-03-31T00:00:00Z
**Completed**: 2026-03-31T00:15:00Z
**Effort**: Small-Medium (config file edits, file moves, no code logic)
**Dependencies**: 341, 342, 343 (founder extension and deck skills -- already completed)
**Sources/Inputs**: Codebase exploration of present/ and founder/ extensions
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder extension (tasks 341-343) already has complete deck infrastructure: 3 skills, 3 agents, 1 command, 5 typst templates, and full routing
- The present extension still contains the OLD deck infrastructure: 1 skill, 1 agent, 1 command, 4 context files, plus EXTENSION.md/manifest.json/index-entries.json references
- Three context files (pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md) live in present/ but are referenced by BOTH extensions -- these need to move to founder/
- The founder's deck agents currently have `@-references` pointing to `present/context/` paths that will need updating after the move
- The filetypes extension also references `deck-agent` in its index-entries.json -- this needs updating to reference the founder agents instead
- The present/examples/ directory contains 4 pitch deck .typ files and shared-config.typ that should move to founder/ since they are deck-specific

## Context & Scope

This migration removes all deck functionality from the `present/` extension and ensures the `founder/` extension is self-contained for deck operations. After migration, `present/` will be a grant-writing-only extension.

## Findings

### 1. Present Extension -- Deck Artifacts to Remove/Move

#### Files to DELETE (replaced by founder equivalents)

| File | Replacement in founder/ |
|------|------------------------|
| `present/agents/deck-agent.md` | `founder/agents/deck-research-agent.md`, `deck-planner-agent.md`, `deck-builder-agent.md` |
| `present/skills/skill-deck/SKILL.md` | `founder/skills/skill-deck-research/`, `skill-deck-plan/`, `skill-deck-implement/` |
| `present/commands/deck.md` | `founder/commands/deck.md` |
| `present/context/project/present/domain/deck-workflow.md` | Subsumed by founder's workflow-reference.md |

#### Files to MOVE to founder/context/

| Source (present/) | Destination (founder/) |
|-------------------|----------------------|
| `context/project/present/patterns/pitch-deck-structure.md` | `context/project/founder/patterns/pitch-deck-structure.md` |
| `context/project/present/patterns/touying-pitch-deck-template.md` | `context/project/founder/patterns/touying-pitch-deck-template.md` |
| `context/project/present/patterns/yc-compliance-checklist.md` | `context/project/founder/patterns/yc-compliance-checklist.md` |

#### Files to MOVE (examples)

| Source (present/) | Destination (founder/) |
|-------------------|----------------------|
| `examples/professional-blue-pitch.typ` | Already exists as `founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ` |
| `examples/premium-dark-pitch.typ` | Already exists as `founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ` |
| `examples/minimal-light-pitch.typ` | Already exists as `founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ` |
| `examples/growth-green-pitch.typ` | Already exists as `founder/context/project/founder/templates/typst/deck/deck-growth-green.typ` |
| `examples/shared-config.typ` | Review if needed in founder/ |
| `examples/README.md` | Review if needed in founder/ |

Since founder already has its own deck templates, the present/examples/ can simply be deleted. The README.md in present/ will need updating to remove deck references but can keep the examples directory if it is still useful for grant examples (it currently has no grant examples).

#### Config entries to EDIT in present/

**manifest.json** -- Remove deck references:
- Line 8: `"agents"` array: remove `"deck-agent.md"`
- Line 9: `"skills"` array: remove `"skill-deck"`
- Line 10: `"commands"` array: remove `"deck.md"`

**EXTENSION.md** -- Remove deck references:
- Line 3: Description -- remove "and investor pitch deck generation (decks)"
- Line 10: skill-deck row from Skill-Agent Mapping table
- Line 20: /deck row from Commands table
- Line 27: `deck` row from Language Routing table

**index-entries.json** -- Remove 4 deck entries:
- Entry at line 3-15: `pitch-deck-structure.md` (languages: deck, agents: deck-agent)
- Entry at line 17-29: `touying-pitch-deck-template.md` (languages: deck, agents: deck-agent)
- Entry at line 31-43: `yc-compliance-checklist.md` (languages: deck, agents: deck-agent)
- Entry at line 269-281: `deck-workflow.md` (languages: deck, agents: deck-agent)

**README.md** -- Major rewrite needed to remove all deck sections:
- Remove Pitch Deck Generation section and subsections (lines 9, 23-24, 33-46, 66-312)
- Update overview table
- Remove deck troubleshooting
- Remove deck references in Related Files section

**opencode-agents.json** -- No changes needed (already grant-only)

### 2. Founder Extension -- Current Deck Infrastructure (Already Complete)

Tasks 341-343 created:

**Agents** (3):
- `founder/agents/deck-research-agent.md`
- `founder/agents/deck-planner-agent.md`
- `founder/agents/deck-builder-agent.md`

**Skills** (3):
- `founder/skills/skill-deck-research/SKILL.md`
- `founder/skills/skill-deck-plan/SKILL.md`
- `founder/skills/skill-deck-implement/SKILL.md`

**Command** (1):
- `founder/commands/deck.md`

**Templates** (5):
- `founder/context/project/founder/templates/typst/deck/deck-dark-blue.typ`
- `founder/context/project/founder/templates/typst/deck/deck-growth-green.typ`
- `founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ`
- `founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ`
- `founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ`

**Manifest routing** -- Already complete with `founder:deck` routes for research/plan/implement

**EXTENSION.md** -- Already documents all deck skills, agents, commands, and routing

**index-entries.json** -- Already has entries for:
- All 5 deck typst templates (lines 654-748)
- 3 cross-references to present/ context files (lines 576-653) -- these point to `project/present/patterns/` paths

### 3. Cross-References Requiring Updates

#### Founder index-entries.json -- Path updates needed

Three entries in `founder/index-entries.json` reference present/ paths and need updating after context files move:

| Current path | New path |
|-------------|----------|
| `project/present/patterns/pitch-deck-structure.md` | `project/founder/patterns/pitch-deck-structure.md` |
| `project/present/patterns/touying-pitch-deck-template.md` | `project/founder/patterns/touying-pitch-deck-template.md` |
| `project/present/patterns/yc-compliance-checklist.md` | `project/founder/patterns/yc-compliance-checklist.md` |

Also remove `"deck-agent"` from the agents arrays in these entries (the present/ deck-agent no longer exists; the founder agents are `deck-research-agent`, `deck-planner-agent`, `deck-builder-agent`).

#### Founder deck agent files -- @-reference updates

All three founder deck agents reference present/ context paths via `@-references`:

- `founder/agents/deck-research-agent.md` (lines 39-41)
- `founder/agents/deck-builder-agent.md` (lines 37-39)
- `founder/agents/deck-planner-agent.md` (lines 40-42)

Each references:
```
@.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md
@.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md
@.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md
```

These need to become:
```
@.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md
@.claude/extensions/founder/context/project/founder/patterns/touying-pitch-deck-template.md
@.claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md
```

#### Filetypes extension -- deck-agent references

`filetypes/index-entries.json` (lines 101-139) has two entries that reference `"deck-agent"` in their agents arrays:
- `project/filetypes/patterns/pitch-deck-structure.md` -- agents: `["presentation-agent", "deck-agent"]`
- `project/filetypes/patterns/touying-pitch-deck-template.md` -- agents: `["presentation-agent", "deck-agent"]`

These should be updated to reference the new founder agents (`deck-research-agent`, `deck-planner-agent`, `deck-builder-agent`) or simply removed if filetypes should not route to founder agents.

#### Founder skill-deck-research -- present reference

`founder/skills/skill-deck-research/SKILL.md` line 53 mentions: "Standalone deck generation without task workflow (use present's skill-deck)". This reference to present's skill-deck needs removal since that skill will no longer exist.

### 4. Present Extension Post-Migration State

After migration, present/ should contain ONLY grant-writing artifacts:

```
present/
  agents/grant-agent.md
  commands/grant.md
  context/project/present/
    domain/funder-types.md
    domain/grant-terminology.md
    domain/grant-workflow.md
    domain/proposal-components.md
    patterns/budget-patterns.md
    patterns/evaluation-patterns.md
    patterns/narrative-patterns.md
    patterns/proposal-structure.md
    README.md
    standards/character-limits.md
    standards/writing-standards.md
    templates/budget-justification.md
    templates/evaluation-plan.md
    templates/executive-summary.md
    templates/submission-checklist.md
    tools/funder-research.md
    tools/web-resources.md
  examples/            # DELETE entire directory (all deck examples, no grant examples)
  skills/skill-grant/SKILL.md
  EXTENSION.md         # Edit: grant-only
  index-entries.json   # Edit: remove 4 deck entries
  manifest.json        # Edit: remove deck refs
  opencode-agents.json # No change needed
  README.md            # Major edit: remove all deck sections
```

## Decisions

- **Context files move rather than copy**: pitch-deck-structure.md, touying-pitch-deck-template.md, and yc-compliance-checklist.md should be moved (not duplicated) since founder is now the sole owner
- **Delete present/examples/**: All examples are deck-specific and founder already has its own templates. No grant examples exist to preserve
- **Delete deck-workflow.md**: Its content (18 lines) is already covered by founder's workflow-reference.md
- **Update filetypes references**: Change `deck-agent` to founder's deck agents in filetypes index-entries.json

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Broken @-references in founder agents after move | High | Update all 3 agent files in same commit as file move |
| Merged index.json stale after extension change | Medium | Reload extensions after migration to regenerate merged index |
| filetypes extension breaks if deck-agent removed | Low | Update filetypes index-entries.json to reference new agents |
| README.md edit misses a deck reference | Low | grep for "deck" in present/ after edits to verify |

## Migration Checklist

### Phase 1: Move context files to founder/

1. `git mv .claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md .claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`
2. `git mv .claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md .claude/extensions/founder/context/project/founder/patterns/touying-pitch-deck-template.md`
3. `git mv .claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md .claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md`

### Phase 2: Delete present/ deck files

4. `git rm .claude/extensions/present/agents/deck-agent.md`
5. `git rm .claude/extensions/present/skills/skill-deck/SKILL.md` (and rmdir skill-deck/)
6. `git rm .claude/extensions/present/commands/deck.md`
7. `git rm .claude/extensions/present/context/project/present/domain/deck-workflow.md`
8. `git rm -r .claude/extensions/present/examples/` (all 5 files + README)

### Phase 3: Edit present/ config files

9. Edit `present/manifest.json`: Remove deck-agent.md, skill-deck, deck.md
10. Edit `present/EXTENSION.md`: Remove deck skill-agent row, deck command row, deck language routing row, update description
11. Edit `present/index-entries.json`: Remove 4 deck entries
12. Edit `present/README.md`: Remove all deck sections, update to be grant-only

### Phase 4: Update founder/ cross-references

13. Edit `founder/agents/deck-research-agent.md`: Update 3 @-references from present/ to founder/ paths
14. Edit `founder/agents/deck-builder-agent.md`: Update 3 @-references from present/ to founder/ paths
15. Edit `founder/agents/deck-planner-agent.md`: Update 3 @-references from present/ to founder/ paths
16. Edit `founder/index-entries.json`: Update 3 path entries from `project/present/patterns/` to `project/founder/patterns/`, remove `deck-agent` from agents arrays
17. Edit `founder/skills/skill-deck-research/SKILL.md`: Remove line 53 reference to "present's skill-deck"

### Phase 5: Update filetypes/ cross-references

18. Edit `filetypes/index-entries.json`: Update `deck-agent` references in pitch-deck-structure.md and touying-pitch-deck-template.md entries

### Phase 6: Verification

19. `grep -r "deck" .claude/extensions/present/` -- should return zero matches
20. `grep -r "present.*deck\|deck.*present" .claude/extensions/founder/` -- should return zero matches
21. `grep -r "deck-agent" .claude/extensions/` -- should only match founder/ agents (not present/ or as a load_when reference)

## Appendix

### Search queries used
- `find .claude/extensions/present/ -type f` -- full file inventory
- `find .claude/extensions/founder/ -type f` -- full file inventory
- `grep -r "deck" .claude/extensions/present/` -- all deck references in present/
- `grep -r "deck" .claude/extensions/founder/` -- all deck references in founder/
- `grep -r "deck-agent|skill-deck" .claude/ --include="*.json"` -- cross-extension references
- `grep -r "present" .claude/extensions/founder/agents/deck-*` -- @-reference paths in founder agents
- `grep -r "present" .claude/extensions/founder/skills/` -- present references in founder skills

### File counts
- Files to delete from present/: 10 (1 agent, 1 skill dir, 1 command, 1 context, 6 examples)
- Files to move to founder/: 3 (context pattern files)
- Files to edit in present/: 4 (manifest.json, EXTENSION.md, index-entries.json, README.md)
- Files to edit in founder/: 5 (3 agents, 1 index-entries.json, 1 skill)
- Files to edit in filetypes/: 1 (index-entries.json)
- Total operations: 23
