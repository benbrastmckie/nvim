# Research Report: Task #381

**Task**: 381 - Update manifest.json, index-entries.json, and routing for /meeting command
**Started**: 2026-04-08
**Completed**: 2026-04-08
**Effort**: small
**Dependencies**: Tasks 378, 379, 380
**Sources/Inputs**: Codebase (manifest.json, index-entries.json)
**Artifacts**: specs/381_meeting_manifest_registration/reports/01_manifest-registration-research.md
**Standards**: report-format.md

## Executive Summary

Three files need modification to register the /meeting command components in the founder extension:
1. `manifest.json` -- add meeting-agent, skill-meeting, meeting.md, and founder:meeting routing
2. `index-entries.json` -- add context entries for meeting-format.md and csv-tracker.md
3. No EXTENSION.md changes needed (the merge target handles CLAUDE.md injection)

## Findings

### manifest.json Changes

**provides.agents**: Add `"meeting-agent.md"`
**provides.skills**: Add `"skill-meeting"`
**provides.commands**: Add `"meeting.md"`
**routing.research**: Add `"founder:meeting": "skill-meeting"`
**routing.plan**: Add `"founder:meeting": "skill-founder-plan"` (shared planner)
**routing.implement**: Add `"founder:meeting": "skill-founder-implement"` (shared implementer)

### index-entries.json Changes

Add 2 new entries:

1. **meeting-format.md** (template):
   - path: `project/founder/templates/meeting-format.md`
   - agents: `["meeting-agent", "founder-plan-agent", "founder-implement-agent"]`
   - commands: `["/meeting"]`
   - line_count: ~200

2. **csv-tracker.md** (pattern):
   - path: `project/founder/patterns/csv-tracker.md`
   - agents: `["meeting-agent"]`
   - commands: `["/meeting"]`
   - line_count: ~130

### Line Counts

```bash
wc -l .claude/extensions/founder/context/project/founder/templates/meeting-format.md
# ~200 lines
wc -l .claude/extensions/founder/context/project/founder/patterns/csv-tracker.md
# ~130 lines
```

## Decisions

- Routing uses shared `skill-founder-plan` and `skill-founder-implement` for plan/implement phases (same as all other founder task types except deck)
- Context entries use `languages: ["founder"]` to match all founder task types
- meeting-format.md is loaded by meeting-agent, founder-plan-agent, and founder-implement-agent (the latter two may need it for planning/implementing meeting-related tasks)
- csv-tracker.md is loaded only by meeting-agent (CSV operations are meeting-specific)
