---
name: skill-books-implementation
description: Implement lean-book authoring, certification and documentation changes. Invoke for books implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Implementation Skill

Thin wrapper that delegates `books` implementation to `books-implementation-agent` subagent.
This skill also serves the `books:certify` sub-route: no dedicated lifecycle skill exists for
it, since `books:certify` maps to the same base agents as `books` in the manifest's
`routing_agents` block (the `lean4:lake` precedent) — a certification-focused implementation
task routes here, not to a separate skill.

## Trigger Conditions

This skill activates when:
- Task type is "books" (or the `books:certify` sub-route)
- `/implement` command targets a `books` task
- Plan exists and task is ready for implementation

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists and task type is "books" (or "books:certify").

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-implementation"
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
Include task_context, plan_path, metadata_file_path, and `gate_flag` (forwarded unchanged from
the dispatch context, defaulting to `false` when absent — the advisory gate tier is opt-in and
this skill never decides it). If `memory_context` and/or `lit_context`
from Stage 4a are non-empty, include them in the prompt (memory context first, then literature
briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-implementation-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

**Self-review before writing metadata**: if this fallback path authors or modifies any book
module, `book.toml`, or Lean file directly (rather than wholesale re-delegating to another
skill/agent), it bypasses `books-implementation-agent`'s own Stage 4C entirely — so before
writing `.return-meta.json` with `status: "implemented"`, re-read every file this inline path
touched, by path, against `rules/books.md`'s six non-negotiables. A successful `lake build` does
NOT satisfy this check.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including `memory_candidates`.

---

### Stage 6d: Advisory Gate Tier Surface (Read from Metadata)

Read the agent-recorded `gate` block, if any, from metadata and surface it. The gate invocation
itself was performed by the agent in its Stage 5 Final Verification — this stage reads that
recorded result and MUST NOT re-run it, per
`@.claude/context/standards/postflight-tool-restrictions.md` and this skill's own
"MUST NOT (Postflight Boundary)" section below. This stage does not invoke `books-gate.sh`, does
not run a build, and does not grep source.

```bash
gate_ran=$(jq -r '.gate.ran // false' "$metadata_file" 2>/dev/null)
gate_lint_status=$(jq -r '.gate.layer_lint.status // ""' "$metadata_file" 2>/dev/null)
gate_rules_matched=$(jq -r '.gate.layer_lint.rules_matched // 0' "$metadata_file" 2>/dev/null)
gate_rules_total=$(jq -r '.gate.layer_lint.rules_total // 0' "$metadata_file" 2>/dev/null)
gate_violation_count=$(jq -r '.gate.layer_lint.violation_count // 0' "$metadata_file" 2>/dev/null)
gate_closure_status=$(jq -r '.gate.books_meta_closure.status // ""' "$metadata_file" 2>/dev/null)

if [ "$gate_ran" = "false" ] && [ -z "$gate_lint_status" ]; then
    echo "Stage 6d: INFO — no gate block recorded (--gate not requested, or the agent stopped before invocation); proceeding"
elif [ "$gate_lint_status" = "pass" ] && [ "$gate_closure_status" = "pass" ]; then
    echo "Stage 6d: Advisory gate tier PASS — layer_lint=pass (${gate_rules_matched}/${gate_rules_total} rules matched), books_meta_closure=pass"
else
    echo "Stage 6d: *** ADVISORY GATE FINDING ***"
    echo "  layer_lint.status: ${gate_lint_status} (rules matched: ${gate_rules_matched}/${gate_rules_total}, violations: ${gate_violation_count})"
    echo "  books_meta_closure.status: ${gate_closure_status}"
    if [ "$gate_lint_status" = "pass_vacuous" ]; then
        echo "  NOTE: pass_vacuous is NOT a pass — the lint reported no violations while matching 0 rules, so nothing was actually checked."
    fi
    echo "  This is ADVISORY ONLY — completion is proceeding regardless. See the implementation"
    echo "  summary's gate section for full detail."
fi
```

**Asymmetry note (deliberate, not an omission)**: unlike a `compliance_check == "failed"` branch,
which sets `status="partial"`, this stage MUST NOT assign `status` on any `gate` status, however
severe. The tier is advisory-only by binding design decision — see `### gate (optional)` in
`@.claude/context/formats/return-metadata-file.md`. It ADDS a cheap intermediate tier below the
existing fail-closed one; it relaxes nothing.

Gate-tier background — plain pointers, read on demand, never eager imports:
`context/project/books/domain/gate-tiers.md` and
`context/project/books/tools/certify-guide.md`.


### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full: `field_name=**Summary**`,
`next_field=**Description**`.

## Error Handling

### Input Validation Errors
Return immediately if task not found or wrong task type.

### Metadata File Missing
Keep status as "implementing", report error.

### Git Commit Failure
Non-blocking: Log failure but continue.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit book/Lean/TOML files** - All books work is done by agent
2. **Run `lake build` or `books-tool`** - Verification is done by agent
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
