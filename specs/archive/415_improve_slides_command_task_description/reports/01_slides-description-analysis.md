# Research Report: Improve /slides Command Task Description Format

## Summary

The `/slides` command in the `present/` extension creates poorly structured TODO.md task entries compared to the `/deck` command in the `founder/` extension. Three specific sections of `slides.md` need modification: Step 2.5 (description enrichment), Step 4 (TODO.md entry), and Step 6 (output display).

## Analysis

### Current /slides Behavior (Problem)

**Step 2.5** (lines 187-229) constructs a single-line enriched description:
```
{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.
```

Issues:
1. **Path relativization**: Source paths are stripped to repo-relative paths (line 218-219), losing the full path when sharing context across repos
2. **Audience truncation**: `head -c 120` truncates audience context to ~20 words (line 227)
3. **Single compressed line**: All metadata crammed into one sentence

**Step 4** (lines 253-269) creates a minimal TODO.md entry:
```markdown
### {N}. {Title}
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: present

**Description**: {enriched_description}
```

Issues:
1. No **Sources** section with full paths
2. No **Forcing Data Gathered** section
3. Description is the single compressed line from Step 2.5

**Step 6** (lines 282-296) shows a console output that mentions talk_type and output_format but not sources or audience context in a structured way.

### /deck Reference Implementation (Target)

**Step 5** (lines 235-254) creates a rich TODO.md entry:
```markdown
### {task_number}. Pitch deck: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: founder
- **Type**: deck
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Purpose: {forcing_data.purpose}
- Source materials: {forcing_data.source_materials}
- Context: {forcing_data.context}
```

**Step 7** (lines 270-288) also displays forcing data in the console output.

### Gap Summary

| Aspect | /slides (current) | /deck (reference) | Fix |
|--------|-------------------|-------------------|-----|
| Sources | Relative paths buried in description | Listed in Forcing Data | Add **Sources** section with full absolute paths |
| Forcing answers | Not shown in TODO.md | Shown in **Forcing Data Gathered** | Add structured section |
| Audience context | Truncated to ~120 chars | Full context preserved | Remove truncation |
| Description format | Single compressed line | Clean base description | Separate metadata from description |
| Console output | No forcing data recap | Forcing data recap shown | Add recap to Step 6 |

## Recommended Changes

### Change 1: Step 2.5 - Simplify enriched description

The enriched description should be a clean narrative summary, not a metadata dump. Move structured metadata to the TODO.md entry instead.

**Before** (lines 187-229):
- Packs talk_type, output_format, source paths, audience into one line
- Relativizes paths
- Truncates audience to ~120 chars

**After**:
- Keep only the base description + talk type + duration as the enriched description
- Remove path relativization (paths go to Sources section)
- Remove audience truncation (audience goes to Forcing Data section)
- Target format: `{base_description} ({talk_type} talk, {duration}, {output_format})`

### Change 2: Step 4 - Expand TODO.md entry

**Before** (lines 261-269):
```markdown
### {N}. {Title}
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: present

**Description**: {enriched_description}
```

**After**:
```markdown
### {N}. {Title}
- **Effort**: TBD
- **Status**: [NOT STARTED]
- **Task Type**: present

**Description**: {enriched_description}

**Sources**:
- {full_absolute_path_1}
- {full_absolute_path_2}
- task:{N} (if task reference)

**Forcing Data Gathered**:
- Output format: {forcing_data.output_format}
- Talk type: {forcing_data.talk_type}
- Source materials: {forcing_data.source_materials}
- Audience context: {forcing_data.audience_context}
```

Key design decisions:
- **Sources** is a separate section with full absolute paths (not relativized)
- **Forcing Data Gathered** mirrors the `/deck` pattern with all four forcing fields
- Audience context is shown in FULL (no truncation)

### Change 3: Step 6 - Enrich console output

**Before** (lines 284-296):
```
Talk task #{N} created: {TITLE}
Status: [NOT STARTED]
Language: present
Talk Type: {talk_type}
Output Format: {output_format}
```

**After**:
```
Talk task #{N} created: {TITLE}
Status: [NOT STARTED]
Task Type: present
Talk Type: {talk_type}
Output Format: {output_format}

Forcing Data Gathered:
- Output format: {output_format}
- Talk type: {talk_type}
- Sources: {source_materials}
- Audience: {audience_context}

Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)
```

Also update "Language" to "Task Type" for consistency with current conventions.

## Files to Modify

| File | Lines | Change |
|------|-------|--------|
| `.claude/extensions/present/commands/slides.md` | 187-229 | Simplify Step 2.5 enrichment |
| `.claude/extensions/present/commands/slides.md` | 253-269 | Expand Step 4 TODO.md entry |
| `.claude/extensions/present/commands/slides.md` | 282-296 | Enrich Step 6 console output |

## Complexity

Low. Single file, three localized edits. No structural changes to the command flow, no new steps, no changes to state.json schema or skill routing.
