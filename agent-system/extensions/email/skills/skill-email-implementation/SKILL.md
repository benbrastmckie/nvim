---
name: skill-email-implementation
description: Implement wrapper-only email triage/cleanup tasks from plans. Invoke for email implementation tasks.
allowed-tools: Agent, Bash, Read
---

# Email Implementation Skill

Thin wrapper that delegates email triage/cleanup implementation to the `email-implementation-agent`
subagent. This skill never calls the wrapper binaries itself — it only prepares delegation
context and dispatches.

## Trigger Conditions

This skill activates when:
- Task type is "email"
- An implement-phase dispatch targets an email task
- A census/classify/archive/delete/unsubscribe-extract plan needs wrapper-only execution

## Execution Flow

### Stage 1: Input Validation

Validate task_number exists, task_type is "email", and an implementation plan is present.

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-email-implementation"
operation="implement"
```

### Stage 3a: $PATH Precondition Check (contract §9)

Before dispatching, verify the five wrapper binaries are on `$PATH`:

```bash
command -v email-census email-classify email-archive-confirmed email-delete-confirmed \
  email-unsubscribe-extract
```

If any are missing, do NOT dispatch. Write `status: "failed"` metadata naming the missing
binary and instructing the user to run `home-manager switch --flake .#<user>` to activate the
generation containing `modules/home/email/agent-tools.nix`.

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

Domain-specific context for `email-implementation-agent`:
- Wrapper-only contract: only the five named binaries, never raw `himalaya`/`notmuch`/`msmtp`/
  `secret-tool`, never `rm` against Maildir.
- Propose-review-confirm-execute: STOP at every review gate for explicit human approval before
  any `--execute --confirm-manifest <sha256>` call.
- Constants: `MAX_BATCH_SIZE=50`, `PLAN_EXPIRY_DAYS=7`, delete auto-propose confidence `>= 0.90`.

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-email-implementation"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "email"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

If `memory_context` and/or `lit_context` from Stage 4a are non-empty, include them in the prompt
(memory context first, then literature briefing). Do NOT inject an empty block for either.

### Stage 5: Invoke Subagent

Use Agent tool with subagent_type: "email-implementation-agent".

### Stage 5b: Self-Execution Fallback

Follow `@.claude/context/patterns/skill-self-execution-fallback.md` in full. This skill's success
status value for that block's write obligation is `"implemented"`. This path is not expected for
email tasks — the wrapper-only contract is agent-owned — but if it is reached, it must still
respect Stage 3a's `$PATH` check and never invoke a wrapper binary directly from this skill.

## Postflight (ALWAYS EXECUTE)

### Stage 6: Parse Subagent Return

Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`, including `memory_candidates`.

### Stage 7, 7a, 8, 8a, 9: Postflight Status, Memory Candidates, Artifact Linking, Notify, Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md` in full: `field_name=**Summary**`,
`next_field=**Description**`.

### Stage 10: Return Brief Summary

Return 3-6 bullets. State clearly whether any mutation (`--execute`) occurred and, if so, which
manifest/sha256 authorized it.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Call any wrapper binary directly** - All classify/archive/delete/unsubscribe execution is
   done by the dispatched agent, wrapper-only, per the email extension's safety invariants
2. **Run build/test commands** - Verification is done by the dispatched agent
3. **Use MCP/WebSearch tools** - Domain tools are for the dispatched agent's use only
4. **Analyze or grep source** - Analysis is dispatched-agent work
5. **Write manifests or reports** - Artifact creation is dispatched-agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Calling `update-task-status.sh` for status updates (state.json + TODO.md)
- Linking artifacts in state.json
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md
