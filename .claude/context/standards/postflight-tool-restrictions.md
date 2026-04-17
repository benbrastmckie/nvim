# Postflight Tool Restrictions Standard

**Created**: 2026-03-17
**Purpose**: Define allowed vs prohibited operations during skill postflight phase
**Audience**: Skill authors, /meta agent, system maintainers

---

## Overview

Skills that delegate to subagents via the Task tool must maintain a clean separation between agent work and postflight operations. The postflight phase exists solely for:
- State management (updating state.json and TODO.md)
- Artifact linking (recording paths in state.json)
- Git commits
- Cleanup (removing temp files)

The postflight phase **MUST NOT** perform any work that belongs in the agent, including:
- Verification operations
- Build or test commands
- Source file modifications
- Additional tool calls beyond state management

---

## Allowed Operations

### Read Operations

| Tool | Allowed Pattern | Purpose |
|------|-----------------|---------|
| Read | `specs/{NNN}_*/.*` | Read agent metadata files (.return-meta.json) |
| Read | `specs/{NNN}_*/summaries/*` | Verify summary artifact exists |
| Read | `specs/{NNN}_*/reports/*` | Verify report artifact exists |
| Read | `specs/{NNN}_*/plans/*` | Verify plan artifact exists |

### Bash Operations

| Command Pattern | Purpose |
|-----------------|---------|
| `jq` on state.json | Update task status, link artifacts |
| `git add`, `git commit` | Commit changes |
| `rm -f specs/{NNN}_*/.return-meta.json` | Cleanup metadata file |
| `rm -f specs/{NNN}_*/.postflight-pending` | Cleanup marker file |
| `mkdir -p specs/tmp` | Create temp directory for atomic writes |
| `mv specs/tmp/state.json specs/state.json` | Atomic state update |

### Edit Operations

| Target Pattern | Purpose |
|----------------|---------|
| `specs/TODO.md` | Update status markers |
| `specs/state.json` | Update task state (via mv pattern) |

---

## Prohibited Operations

### Edit Tool Restrictions

| Prohibited Pattern | Reason |
|--------------------|--------|
| Edit on `*.lua` | Source modification is agent work |
| Edit on `*.lean` | Source modification is agent work |
| Edit on `*.py` | Source modification is agent work |
| Edit on `*.ts`, `*.tsx`, `*.js` | Source modification is agent work |
| Edit on `*.md` outside `specs/` | Documentation is agent work |
| Edit on `.claude/**/*` (non-specs) | System modification is agent work |

### Bash Command Restrictions

| Prohibited Pattern | Reason |
|--------------------|--------|
| `lake build` | Verification is agent work |
| `nvim --headless` | Verification is agent work |
| `npm run build`, `pnpm build` | Verification is agent work |
| `cargo build`, `cargo test` | Verification is agent work |
| `pytest`, `python -m unittest` | Verification is agent work |
| `grep` on source files | Analysis is agent work |
| `nix build` | Verification is agent work |
| Any MCP tool | Domain tools are agent work |

### Write Tool Restrictions

| Prohibited Pattern | Reason |
|--------------------|--------|
| Write to source files | Implementation is agent work |
| Write to `.claude/` (except specs/) | System modification is agent work |
| Write to summaries | Agent creates summary |

---

## Examples

### Correct Postflight (skill-researcher pattern)

```markdown
### Stage 6: Parse Subagent Return (Read Metadata File)
- Read specs/{NNN}_{SLUG}/.return-meta.json
- Extract status, artifacts, summary

### Stage 7: Update Task Status (Postflight)
- jq update state.json to "researched"
- Edit TODO.md status marker

### Stage 8: Link Artifacts
- jq add artifact to state.json

### Stage 9: Git Commit
- git add/commit

### Stage 10: Cleanup
- rm -f metadata and marker files
```

### Incorrect Postflight (VIOLATION)

```markdown
### Stage 6: Zero-Debt Verification Gate  <-- WRONG: This is agent work
- grep for sorries                        <-- WRONG: Analysis is agent work
- lake build                              <-- WRONG: Verification is agent work

### Stage 7: Update Task Status
- Update based on verification            <-- WRONG: Status based on postflight check
```

The verification gate must move to the agent, which returns verification results in metadata.

---

## Agent Responsibilities

When verification is needed before completion, the **agent** must:

1. Perform verification (build, test, debt check)
2. Record results in metadata:
   ```json
   {
     "status": "implemented",
     "verification": {
       "build_passed": true,
       "debt_free": true,
       "tests_passed": true
     }
   }
   ```
3. If verification fails, return `status: "partial"` with reason

The **skill** postflight then:
1. Reads metadata
2. Propagates status to state.json based on agent's reported status
3. Does NOT re-verify

---

## MUST NOT Section Template

All agent-delegating skills should include this section:

```markdown
## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status implemented, partial, or failed --
this skill MUST proceed immediately to postflight. The skill MUST NOT:

1. **Edit source files** - All implementation work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP tools** - Domain tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill
> MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report
> the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
```

---

## Enforcement

### Lint Script

The `lint-postflight-boundary.sh` script detects violations:
- Edit tool calls on source files after Stage 5+
- Build commands after "postflight" or Stage 5+
- MCP tool references after delegation

### Pre-Commit Hook

Run as part of `validate-all-standards.sh --postflight` category.

---

## Related Documentation

- @.claude/context/patterns/thin-wrapper-skill.md - Thin wrapper pattern
- @.claude/context/patterns/skill-lifecycle.md - Complete skill lifecycle
- @.claude/context/formats/return-metadata-file.md - Metadata schema
