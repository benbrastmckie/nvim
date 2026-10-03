---
name: skill-books-implementation-hard
description: Implement lean-book changes with hard-mode contracts (H2 anti-analysis, H7 territory, H9 wrap-up discipline). Invoke for --hard books implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# Books Implementation Hard Skill

Hard-mode wrapper that delegates `books` implementation to `books-implementation-hard-agent`
subagent. Extends `skill-books-implementation` with:

- Territory parameters (H7): includes territory contract when dispatched from orchestrate-hard
- Anti-analysis contract (H2): passed in delegation context for agent enforcement
- Wrap-up discipline (H9): `.orchestrator-handoff.json` always written by the agent

**Relationship to base skill**: Structurally follows `skill-books-implementation`'s postflight
pattern. Key difference: when `orchestrator_mode=true`, uses per-phase dispatch (H1) rather than
whole-plan dispatch, same as `books:certify`'s shared routing — no separate certify skill exists
here either.
**Maintenance note**: changes to `skill-books-implementation` postflight should be mirrored
here.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/contracts/anti-analysis.md` - H2 contract (loaded by agent)
- Path: `.claude/context/contracts/wrap-up.md` - H9 contract (loaded by agent)
- Path: `.claude/context/contracts/territory.md` - H7 contract (when territory params present)
- Path: `.claude/context/contracts/phase-closure.md` - depth-first phase closure (loaded by agent)
- Path: `.claude/context/contracts/pre-edit-gate.md` - per-item evidence before a mechanical-list edit (loaded by agent)
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/subagent-continuation-loop.md` - Continuation loop pattern

## Trigger Conditions

This skill activates when:
- `/implement N --hard` is invoked and task type is `books` (or `books:certify`)
- Note: `skill-orchestrate`'s own hard-mode dispatch (both effort modes, one engine) resolves
  and dispatches the AGENT (`books-implementation-hard-agent`) directly via
  `command-route-agent.sh`, not this SKILL file; this skill's own activation is via direct
  invocation

---

## Execution Flow

### Stage 1: Input Validation

```bash
# Lookup task (skill_validate_input exits 1 with its own not-found/terminal-state message;
# "terminal state" covers completed -- and also abandoned/expanded, a stricter but consistent
# superset of the prior completed-only check -- so the separate completed check below is
# removed as dead code, unreachable once skill_validate_input has already exited)
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
task_data="$TASK_DATA"

# Extract fields
task_type="$TASK_TYPE"
status="$TASK_STATUS"
project_name="$PROJECT_NAME"
description="$DESCRIPTION"
```

### Stage 1.5: Hard-Mode Cost Note

```bash
session_flag_file="/tmp/.hard-mode-notified-${SESSION_ID:-$$}"
if [ ! -f "$session_flag_file" ]; then
  echo "[hard-mode] Hard mode active (books implementation). Cost: ~3-5x standard." >&2
  touch "$session_flag_file"
fi
```

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-books-implementation-hard"
operation="implement"
```

### Stage 4a: Memory Retrieval and Literature Detection

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`.

### Stage 4: Prepare Delegation Context

Include task_context, plan_path, metadata_file_path, `effort_flag: "hard"`, `gate_flag`
(forwarded unchanged from the dispatch context, defaulting to `false` when absent — the advisory
gate tier is opt-in and this skill never decides it), and — when the
dispatch originates from `skill-orchestrate --hard` — the `territory`/`concurrent_siblings`
parameters it supplies. If `memory_context` and/or `lit_context` from Stage 4a are non-empty,
include them in the prompt. Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent
Use Agent tool with subagent_type: "books-implementation-hard-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`.

**Self-review before writing metadata**: identical to `skill-books-implementation`'s Stage 5b
self-review — re-read every file the inline path touched against `rules/books.md`'s six
non-negotiables before writing `status: "implemented"`.

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including
`memory_candidates`.

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

Identical to `skill-books-implementation`'s postflight boundary: no editing book/Lean/TOML
files, no running `lake build`/`books-tool`, no analysis, no artifact authoring. See that
skill's own section for the full list.

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

Brief text summary (NOT JSON).
