# Research Report: Task Order Schema and Format

- **Task**: 272 - Define Task Order schema and format specification
- **Started**: 2026-03-24T00:00:00Z
- **Completed**: 2026-03-24T00:00:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - ProofChecker/specs/TODO.md Task Order section (reference implementation)
  - .claude/context/core/formats/roadmap-format.md (existing format standard)
  - specs/TODO.md (current Task Order section in this project)
- **Artifacts**: .claude/context/core/formats/task-order-format.md
- **Standards**: report-format.md, artifact-formats.md

## Executive Summary

- The Task Order section provides structured task prioritization between `# TODO` and `## Tasks`
- Format includes: timestamp, goal statement, numbered categories, dependency chains, and task entries
- Dependency chains use Unicode arrow notation (`→`) in fenced code blocks
- Task entries support both ordered (numbered) and unordered (bulleted) formats
- All elements are parseable via regex patterns documented in the format specification
- The format is already in active use in both ProofChecker and this project's TODO.md

## Context and Scope

Task 272 is the foundation for the Task Order management feature chain (272 -> 273 -> 274/275 -> 276). This research identifies the structural elements needed for a formal specification that downstream tasks (parsing, pruning, insertion) can reference.

## Findings

1. **Section placement**: Task Order sits between the YAML frontmatter/header and the `## Tasks` section, serving as a curated view of active task priorities.

2. **Update tracking**: An italicized timestamp line records when the section was last modified and what changed, enabling change detection.

3. **Goal statement**: A bold-prefixed single line captures the current project focus, giving context for category ordering decisions.

4. **Category system**: Numbered `###` headers organize tasks by priority tier (Critical Path, Code Cleanup, Experimental, Deferred, Backlog). Categories are project-customizable.

5. **Dependency notation**: Fenced code blocks contain arrow-delimited chains (`A → B → C`). Box-drawing characters support branching dependencies.

6. **Entry formats**: Numbered lists for ordered tasks within dependency chains; bullet lists for unordered tasks. Both formats include bold task number, status marker, and brief description.

## Decisions

- Use `--` (em-dash style) as the separator between status marker and description, matching the ProofChecker reference
- Support both `--` and ` -- ` with optional subtitle in category headers
- Document regex patterns for all parseable elements to support task 273
- Keep the format specification in `.claude/context/core/formats/` alongside roadmap-format.md

## Recommendations

1. Create the format specification at `.claude/context/core/formats/task-order-format.md`
2. Include a complete example section modeled on the ProofChecker reference
3. Document all regex parsing patterns in a summary table for task 273
4. Add cross-references to roadmap-format.md and state-management.md
