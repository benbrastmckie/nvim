# Reference Documentation

This directory contains schema definitions and reference documentation for the agent system's core data structures.

## Contents

| File | Description |
|------|-------------|
| state-management-schema.md | Complete state.json schema with field specifications and examples |
| skill-agent-mapping.md | Skill-to-agent routing and delegation reference |
| artifact-templates.md | Error report template (other artifact types use format files in `../formats/`) |
| workflow-diagrams.md | Visual diagrams for research, planning, implementation, and error recovery workflows |

## Purpose

Reference documentation differs from patterns and formats in that it provides:

- **Complete field specifications** - Every field documented with type, required status, and semantics
- **Schema validation rules** - Constraints and validation requirements
- **Examples for all variations** - Common and edge cases demonstrated
- **Cross-references to implementations** - Links to rules that enforce the schema

## Related Documentation

- `../patterns/` - Implementation patterns and best practices
- `../formats/` - Artifact templates and file formats
- `../../rules/` - Enforcement rules that validate against these schemas

## Navigation

- [Parent Directory](../README.md)
