# TODO.md Artifact Linking Pattern

Canonical four-case logic for linking artifacts in TODO.md task entries. Skills reference this pattern instead of carrying inline instructions.

**Automation**: This logic is implemented by `.claude/scripts/link-artifact-todo.sh`. Core skills call the script in their Stage 8 postflight. The four-case logic below remains as reference documentation.

## Parameterization Map

| Artifact Type | `field_name` | `next_field` |
|---------------|-------------|-------------|
| research | `**Research**` | `**Plan**` |
| plan | `**Plan**` | `**Description**` |
| summary | `**Summary**` | `**Description**` |

## Prerequisites

Before linking, strip the `specs/` prefix (TODO.md is inside `specs/`):

```bash
todo_link_path="${artifact_path#specs/}"
```

Extract the filename from the path for the link text:

```bash
artifact_filename=$(basename "$artifact_path")
```

## Four-Case Edit Logic

Read the task's entry in `specs/TODO.md` and determine which case applies.

### Case 1: No Existing Line

The task entry has no `- {field_name}:` line.

**Action**: Insert a new inline link. Find the `- {next_field}:` line in the task entry and insert before it:

```
old_string: - {next_field}:
new_string: - {field_name}: [{artifact_filename}]({todo_link_path})
- {next_field}:
```

**Example** (research artifact, file `01_initial-research.md`):
```
old_string: - **Plan**:
new_string: - **Research**: [01_initial-research.md](398_extract_artifact/reports/01_initial-research.md)
- **Plan**:
```

### Case 2: Existing Inline (Single Link)

The task entry has `- {field_name}: [something](path)` -- a link on the same line.

**Action**: Convert to multi-line format with both the existing and new links:

```
old_string: - {field_name}: [existing_file](existing_path)
new_string: - {field_name}:
  - [existing_file](existing_path)
  - [{artifact_filename}]({todo_link_path})
```

**Example** (plan artifact, existing inline link):
```
old_string: - **Plan**: [01_impl-plan.md](398_extract_artifact/plans/01_impl-plan.md)
new_string: - **Plan**:
  - [01_impl-plan.md](398_extract_artifact/plans/01_impl-plan.md)
  - [02_revised-plan.md](398_extract_artifact/plans/02_revised-plan.md)
```

### Case 3: Existing Multi-Line

The task entry has `- {field_name}:` followed by indented bullet items (2+ links already).

**Action**: Append the new link as a bullet before the `- {next_field}:` line:

```
old_string:   - [last_item](last_path)
- {next_field}:
new_string:   - [last_item](last_path)
  - [{artifact_filename}]({todo_link_path})
- {next_field}:
```

**Example** (summary artifact, existing multi-line):
```
old_string:   - [01_exec-summary.md](398_extract_artifact/summaries/01_exec-summary.md)
- **Description**:
new_string:   - [01_exec-summary.md](398_extract_artifact/summaries/01_exec-summary.md)
  - [02_revised-summary.md](398_extract_artifact/summaries/02_revised-summary.md)
- **Description**:
```

### Case 4: Link Already Present

The artifact path already appears in the task entry.

**Action**: Skip -- no edit needed.

## Compact Reference for Skills

Skills should replace their inline four-case instructions with:

```markdown
**Update TODO.md**: Link artifact using count-aware format.

Apply the four-case Edit logic from `@.claude/context/patterns/artifact-linking-todo.md`
with `field_name={field_name}`, `next_field={next_field}`.
```

## Cross-References

- `.claude/rules/state-management.md` -- Artifact Linking Format rules
- `.claude/context/reference/state-management-schema.md` -- Count-Aware Linking detection patterns
