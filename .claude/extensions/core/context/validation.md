# Skill Validation Context

Token budget: ~300 tokens

## Return Schema (Required Fields)

```json
{
  "status": "completed|partial|failed",
  "summary": "Brief description of work done",
  "artifacts": [
    {
      "type": "research|plan|summary",
      "path": "relative/path/to/artifact.md",
      "summary": "Brief artifact description"
    }
  ]
}
```

## Input Requirements

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| task_number | int | Yes | Task ID from state.json |
| focus_prompt | string | No | Optional focus for research |
| session_id | string | Yes | From GATE IN checkpoint |
| resume_phase | int | No | For implementation resume |

## Artifact Validation

1. Path must be relative to repo root
2. File must exist on disk
3. Type must match artifact category:
   - research: `specs/{NNN}_*/reports/*.md`
   - plan: `specs/{NNN}_*/plans/*.md`
   - summary: `specs/{NNN}_*/summaries/*-summary.md`

## Idempotency Check

Before linking artifact to TODO.md:
```bash
grep -q "$artifact_path" specs/TODO.md
```

If found, skip linking (already exists).
