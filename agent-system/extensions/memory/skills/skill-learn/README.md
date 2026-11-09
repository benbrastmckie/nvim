# skill-learn

Memory creation skill for the `/learn` command.

## Purpose

Handles memory creation, similarity search, classification, and index maintenance for the
Obsidian-compatible memory vault. Vault analysis and maintenance (scoring, health reporting,
and the distill sub-modes) is a separate concern owned by the sibling `skill-distill` skill.

## Modes

### Standard Mode

Add text or file content as memory:
- Parse input (text vs file)
- Generate unique memory ID
- Search for similar existing memories
- Present preview with options
- Create memory file with YAML frontmatter
- Update index

### Task Mode

Review task artifacts and create classified memories:
- Locate task directory
- Scan artifact files
- Present interactive selection
- Classify each artifact (TECHNIQUE, PATTERN, CONFIG, WORKFLOW, INSIGHT, SKIP)
- Create categorized memories
- Update index with category grouping

## Auto-Retrieval

Memory retrieval is automatic: the research, plan, and implement preflight stages (dispatched via `/orchestrate`) call `memory-retrieve.sh` to inject relevant memories into agent context. The `--clean` flag suppresses auto-retrieval. No explicit opt-in flag is needed.

## Validate-on-Read

Before scoring or retrieval, `memory-index.json` is validated against the filesystem. Stale indexes (missing or orphaned entries) are automatically regenerated. There is no `--reindex` command; validate-on-read provides the equivalent functionality. This procedure (and the paired JSON Index Maintenance procedure) lives in this skill's `SKILL.md` and is shared with `skill-distill`, which cites it by name.

## Files

- `SKILL.md` - Skill definition and execution flow (learn modes: text, file, directory, task)

## Navigation

- [Parent Directory](../README.md)
