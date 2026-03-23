# Research Report: Task #259

**Task**: 259 - skill_project
**Started**: 2026-03-23T12:00:00Z
**Completed**: 2026-03-23T12:15:00Z
**Effort**: 1-2 hours
**Dependencies**: project-agent.md (completed in task 256)
**Sources/Inputs**: Codebase exploration, existing founder extension skills
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- skill-project follows the thin wrapper pattern established by skill-market, skill-analyze, skill-strategy, and skill-legal
- Key stages: Input validation, preflight status update, postflight marker creation, delegation via Task tool, metadata parsing, artifact linking, git commit, cleanup
- Output goes to `strategy/timelines/` directory (does not exist yet, must be created by agent)
- Three operational modes: PLAN, TRACK, REPORT with different output paths and metadata status values

## Context and Scope

This research covers the patterns needed to implement skill-project as a thin wrapper that:
1. Validates task input and mode
2. Updates task status before and after agent work
3. Creates postflight marker for interruption safety
4. Delegates to project-agent via Task tool (NOT Skill)
5. Reads metadata file written by agent
6. Links artifacts to state.json and TODO.md
7. Commits changes with session ID
8. Cleans up temporary files

## Findings

### 1. Thin Wrapper Skill Pattern

All founder extension skills follow an identical 11-stage pattern:

| Stage | Description |
|-------|-------------|
| 1 | Input Validation - Check task exists, validate mode |
| 2 | Preflight Status Update - Set status to "researching" (for project: "planning" may be more appropriate) |
| 3 | Create Postflight Marker - `.postflight-pending` file |
| 4 | Prepare Delegation Context - Include task_context, forcing_data, mode, metadata_file_path |
| 5 | Invoke Agent - MUST use Task tool, NOT Skill |
| 6 | Parse Subagent Return - Read `.return-meta.json` |
| 7 | Update Task Status - Set final status (researched, planned, tracked, reported) |
| 8 | Link Artifacts - Add to state.json with summary, update TODO.md |
| 9 | Git Commit - Include session_id in commit body |
| 10 | Cleanup - Remove marker and metadata files |
| 11 | Return Brief Summary - Text format, NOT JSON |

**Reference**: `.claude/extensions/founder/skills/skill-market/SKILL.md` lines 1-337

### 2. Project-Agent Interface

The project-agent expects delegation context with:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "product_launch_timeline",
    "description": "Project timeline: Product launch Q2",
    "language": "founder"
  },
  "mode": "PLAN|TRACK|REPORT or null",
  "metadata_file_path": "specs/234_product_launch_timeline/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "project", "skill-project"]
  }
}
```

**Note**: delegation_depth is 2 because skill-project sits between orchestrator and project-agent.

### 3. Mode-Specific Behavior

| Mode | Status Value | Output Path | Description |
|------|--------------|-------------|-------------|
| PLAN | `planned` | `strategy/timelines/{slug}.typ` | Create new timeline |
| TRACK | `tracked` | Updates existing `.typ` file | Update progress |
| REPORT | `reported` | `strategy/timelines/{slug}-report.typ` | Generate status report |

The skill should NOT hardcode status to "researched" like other founder skills. Instead:
- PLAN mode: status = "planned"
- TRACK mode: status = "tracked"
- REPORT mode: status = "reported"

### 4. Output Directory Structure

Output goes to `strategy/timelines/`:

```
strategy/
└── timelines/
    ├── {project-slug}.typ        # PLAN mode output
    ├── {project-slug}.pdf        # PDF compilation (if typst available)
    └── {project-slug}-report.typ # REPORT mode output
```

**Note**: The `strategy/timelines/` directory does not exist yet. The project-agent is responsible for creating it during timeline generation.

### 5. Artifact Linking Differences

Unlike research skills that link to `specs/` reports, skill-project links to `strategy/timelines/`:

```bash
# Research skills
artifact_path="specs/${padded_num}_${project_name}/reports/01_${short_slug}.md"

# Skill-project
artifact_path="strategy/timelines/${project_slug}.typ"
artifact_type="timeline"  # Not "research"
```

For TODO.md linking, the path does NOT need `specs/` prefix stripping since artifacts are outside specs/:
```bash
# Direct path for strategy artifacts
todo_link_path="${artifact_path}"
```

### 6. Frontmatter and Allowed Tools

Based on existing founder skills:

```yaml
---
name: skill-project
description: Project timeline management with WBS, PERT estimation, and resource allocation
allowed-tools: Task, Bash, Edit, Read, Write
---
```

**Note**: No AskUserQuestion - all user interaction happens in project-agent via forcing questions.

### 7. Task Type Field

Following EXTENSION.md patterns, tasks created for project timelines should include:
- `task_type: "project"` for finer-grained routing
- This enables `/research {N}` to route to skill-project when task_type is "project"

### 8. jq Escaping Workaround

All jq commands use the "| not" pattern to avoid Issue #1132:

```bash
# SAFE
select(.type == "timeline" | not)

# UNSAFE (gets escaped as \!=)
select(.type != "timeline")
```

### 9. Postflight Marker Content

```json
{
  "session_id": "{session_id}",
  "skill": "skill-project",
  "task_number": {N},
  "operation": "project",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "{ISO timestamp}"
}
```

### 10. Status Update Patterns

**Preflight** (before agent invocation):
- state.json: `status: "planning"` (not "researching")
- TODO.md: `[PLANNING]`

**Postflight** (after successful agent return):
- PLAN: `status: "planned"`, TODO.md: `[PLANNED]`
- TRACK: `status: "tracked"`, TODO.md: `[TRACKED]` (custom status)
- REPORT: `status: "reported"`, TODO.md: `[REPORTED]` (custom status)

**Note**: TRACK and REPORT are custom status values not in core. May need to add to CLAUDE.md "Status Markers" section or use existing markers creatively.

## Recommendations

### Implementation Approach

1. **Follow skill-market as primary template** - It has the most complete Stage 0 forcing questions pattern and mode handling
2. **Add mode parameter handling** - Validate mode is PLAN, TRACK, or REPORT
3. **Adapt status values** - Use mode-specific final status (planned/tracked/reported)
4. **Adapt artifact linking** - Link to `strategy/timelines/` instead of `specs/` reports
5. **Handle multiple artifacts** - PLAN mode may produce both .typ and .pdf files

### Skill File Structure

```markdown
---
name: skill-project
description: Project timeline management with WBS, PERT estimation, and resource allocation
allowed-tools: Task, Bash, Edit, Read, Write
---

# Project Skill

Thin wrapper that routes project timeline requests to the `project-agent`.

[11 stages following skill-market pattern]
```

### Key Differences from Research Skills

| Aspect | Research Skills | skill-project |
|--------|-----------------|---------------|
| Preflight status | researching | planning |
| Postflight status | researched | planned/tracked/reported |
| Artifact location | specs/{NNN}_{SLUG}/reports/ | strategy/timelines/ |
| Artifact type | research | timeline |
| TODO.md prefix strip | Yes (remove specs/) | No (path already correct) |
| Modes | 4 modes per skill | 3 modes (PLAN/TRACK/REPORT) |

### Command Integration

A `/project` command (similar to `/market`, `/analyze`, `/strategy`) could be created to:
1. Ask pre-task forcing questions for project scope
2. Create task with `task_type: "project"` and `forcing_data`
3. Stop at `[NOT STARTED]` for manual `/research {N}` invocation

However, this is optional - skill-project can work without a dedicated command if tasks are created manually.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Custom status values (tracked/reported) not recognized | Document in CLAUDE.md or map to existing statuses |
| strategy/timelines/ directory may not exist | Agent creates it; skill should verify after agent returns |
| Typst compilation may fail | Non-blocking; preserve .typ file regardless |
| PDF artifact may not exist | Check for file before adding to artifacts array |

## Appendix

### Search Queries Used

1. Glob: `.claude/extensions/founder/skills/*.md` - Found skill patterns
2. Glob: `.claude/extensions/founder/agents/*.md` - Found agent definitions
3. Read: project-agent.md - Full agent specification
4. Read: skill-market, skill-analyze, skill-strategy, skill-legal - Pattern examples
5. Read: EXTENSION.md - Extension integration patterns

### Key Files Referenced

| File | Purpose |
|------|---------|
| `.claude/extensions/founder/agents/project-agent.md` | Agent specification (lines 1-912) |
| `.claude/extensions/founder/skills/skill-market/SKILL.md` | Primary skill pattern template |
| `.claude/extensions/founder/EXTENSION.md` | Extension integration patterns |
| `.claude/skills/skill-researcher/SKILL.md` | Core skill pattern reference |
| `.claude/context/core/formats/return-metadata-file.md` | Metadata file schema |
| `.claude/extensions/founder/context/project/founder/domain/timeline-frameworks.md` | Domain knowledge for project planning |
