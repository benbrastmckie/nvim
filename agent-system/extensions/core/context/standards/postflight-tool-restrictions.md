# Postflight Tool Restrictions Standard

**Created**: 2026-03-17
**Purpose**: Define allowed vs prohibited operations during skill postflight phase
**Audience**: Skill authors, /meta agent, system maintainers

---

## Overview

Skills that delegate to subagents via the Agent tool must maintain a clean separation between agent work and postflight operations. The postflight phase exists solely for:
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
| `bash .claude/scripts/state-write.sh` | Update task status, link artifacts — the single mutex-guarded `specs/state.json` writer; owns its own private `mktemp` staging and acquire/stage/transform/validate/mv/release sequence internally, so callers never hand-roll `jq ... > tmp && mv` themselves |
| `git add`, `git commit` | Commit changes |
| `rm -f specs/{NNN}_*/.return-meta.json` | **`skill-spawn` only**: inline cleanup of the metadata file, since `/spawn` has no `command-gate-out.sh`/CHECKPOINT 3 consumer downstream to own this deletion instead. Every other skill's postflight (`skill_cleanup()`) does NOT remove this file — deletion is owned by the calling command's own last consumer; see `context/patterns/skill-postflight-flow.md`'s reader table |
| `rm -f specs/{NNN}_*/.postflight-pending` | Cleanup marker file |

### Edit Operations

| Target Pattern | Purpose |
|----------------|---------|
| `specs/TODO.md` | Update status markers |
| `specs/state.json` | Update task state (via `state-write.sh`, never a direct Edit/hand-rolled `mv`) |

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

## Exceptions

**`skill-orchestrate` only, D4 message-findings recovery**: when
`orchestrate-cycle-postflight.sh` reports `report_missing: true` for a research-phase dispatch
(its report file or `.return-meta.json` was missing or empty, and no outcome was recovered), the
orchestrate lead writes that dispatch's own Agent-tool return text **verbatim** to a local
capture file and calls `orchestrate-recover-message-findings.sh` — a mechanical, narrowly-scoped
script, not the lead's own judgment — to persist it into the task's `reports/` directory under a
clearly-tagged "recovered from agent message" banner. This is preservation of a dispatched
agent's own already-produced text, not authorship of new report content, and it is the ONLY
sanctioned exception to the "Write to summaries" / "Write reports/plans/summaries" prohibitions
above. It is scoped exclusively to `skill-orchestrate`'s own Move 3 and this one script-mediated
path; no other skill's postflight gains a corresponding exception by analogy. Full accounting:
`docs/architecture/handoff-schema.md`'s "Postflight Boundary" section (item 5) and
`skills/skill-orchestrate/SKILL.md`'s own "MUST NOT (Postflight Boundary)" section.

---

## Examples

### Correct Postflight (collapsed-shape domain skill pattern)

Reflects the actual `skill-nix-research/SKILL.md` shape — see
`@.claude/context/patterns/skill-lifecycle.md` for the full Stage-N skeleton and the "Two
Postflight Shapes" section explaining why this collapsed form has no inline git-commit stage
(a higher-level batch commit owns that instead, for this skill family):

```markdown
### Stage 6: Parse Subagent Return (Read Metadata File)
- Read specs/{NNN}_{SLUG}/.return-meta.json
- Extract status, artifacts, summary

### Stage 6a: Validate Artifact Content
- Non-blocking `validate-artifact.sh --fix` pass over the report artifact

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup
- `skill_postflight_update()` — call `update-task-status.sh postflight` (updates state.json and
  regenerates TODO.md), only on a success status
- `skill_propagate_memory_candidates()` — append any memory candidates the agent emitted
- `skill_link_artifacts()` — two-step `jq` add-artifact pattern, then `generate-todo.sh`
- `skill_lifecycle_notify()` — background TTS/tab-color notification
- `skill_cleanup()` — rm -f marker files only (`.postflight-pending`, `.postflight-loop-guard`).
  `.return-meta.json` is deliberately NOT removed here — its deletion is owned by the calling
  command's own last consumer; see `context/patterns/skill-postflight-flow.md`'s reader table

## Return Format
- Return a 3-6 bullet text summary (not JSON)
```

**Git commit**: this skill has no inline commit stage — `skill-orchestrate`'s own dispatch-loop
commit is the sole git-commit mechanism for this collapsed-shape family. `skill-reviser` and
`skill-spawn` instead interleave an explicit inline Stage 9: Git Commit before cleanup — see
`skill-lifecycle.md`'s "Two Postflight Shapes" for both variants.

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
- Updating state.json via `state-write.sh`
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

Run `lint-postflight-boundary.sh` directly, or as part of `verify-deploy.sh`'s gate suite.

---

## Related Documentation

- @.claude/context/patterns/thin-wrapper-skill.md - Thin wrapper pattern
- @.claude/context/patterns/skill-lifecycle.md - Complete skill lifecycle
- @.claude/context/formats/return-metadata-file.md - Metadata schema
