---
name: skill-typst-implementation
description: Implement Typst documents. Invoke for Typst-language implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Typst Implementation Skill

Thin wrapper that delegates Typst implementation to `typst-implementation-agent` subagent.

## Trigger Conditions

This skill activates when:
- Task type is "typst"
- /implement command targets a Typst task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and language is "typst".

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-typst-implementation"
operation="implement"
```

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

### Stage 4: Prepare Delegation Context
Include task_context, plan_path, metadata_file_path. If `memory_context` and/or `lit_context`
from Stage 4a are non-empty, include them in the prompt (memory context first, then literature
briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "typst-implementation-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

**Self-review before writing metadata**: if this fallback path authors or modifies any `.typ`
content directly (rather than wholesale re-delegating to another skill/agent), it bypasses
`typst-implementation-agent`'s own Stage 4C entirely -- so before writing `.return-meta.json`
with `status: "implemented"`, re-read every `.typ` section this inline path touched, by path,
against `context/project/typst/standards/semantic-element-usage.md` and answer that standard's
Self-Review Questions verbatim (see the **MUST NOT (Document Structure)** section below for the
enforceable items this check protects). `typst compile` succeeding does NOT satisfy this check.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including `memory_candidates`.

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full: `field_name=**Summary**`,
`next_field=**Description**`.

## Error Handling

### Input Validation Errors
Return immediately if task not found or wrong language.

### Metadata File Missing
Keep status as "implementing", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

## MUST NOT (Document Structure)

This list is distinct from the postflight-boundary list below -- it is a content gate, not a
division-of-labor rule, and it applies specifically to the Stage 5b self-execution fallback path
(the one path in this skill that can author `.typ` content without ever passing through
`typst-implementation-agent`'s own Stage 4C verification). See
`agents/typst-implementation-agent.md`'s Critical Requirements MUST NOT items 7-8 for the
identical prohibitions enforced on the agent's own authoring path; the two lists are kept in
correspondence deliberately so neither path is left ungated.

Whenever Stage 5b authors or modifies `.typ` content directly, this skill MUST NOT:

1. Leave a semantic element (`#definition`, `#theorem`, `#lemma`, `#corollary`, `#example`,
   `#proof`, `#remark`, `#rule-block`, `#rule-list`) standing as the first body content after a
   chapter or section heading with no intervening prose -- see
   `context/project/typst/standards/semantic-element-usage.md`'s Universal Placement Rule.
2. Place a long enumerated status/tracking checklist inside a `#remark` (or any other semantic
   element) -- that content belongs in a `specs/**` task artifact, an appendix, or a dedicated
   status section, per `standards/semantic-element-usage.md`'s "Where Tracking Content Belongs".

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .typ files** - All Typst work is done by agent
2. **Run typst compile** - Compilation is done by agent
3. **Analyze or grep source** - Analysis is agent work
4. **Write summary/reports** - Artifact creation is agent work

> **PROHIBITION**: If the subagent returned partial or failed status, the lead skill MUST NOT attempt to continue, complete, or "fill in" the subagent's work. Report the partial/failed status and let the user re-run `/implement` to resume.

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).
