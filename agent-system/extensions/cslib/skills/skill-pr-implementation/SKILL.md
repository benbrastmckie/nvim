---
name: skill-pr-implementation
description: PR description preparation for CSLib tasks. Analyzes task description and git diff to produce pr-description.md. Delegates to cslib-implementation-agent and transitions task to [PR READY]. Branch creation and CI are handled by the /pr command. Invoke for pr implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write
---

# PR Implementation Skill

Thin wrapper that delegates PR preparation work to `cslib-implementation-agent` subagent with
PR-specific delegation context. The critical difference from `skill-cslib-implementation` is
the postflight status transition: this skill calls `pr_ready` (not `implement`), setting the
task to `[PR READY]` to direct the user to run `/pr {task_number}`.

## Trigger Conditions

This skill activates when:
- Task type is "pr"
- /implement command targets a PR preparation task
- A pr-description.md needs to be composed based on the task description and git diff

## Execution Flow

### Stage 1: Input Validation
Validate task_number exists, task_type is "pr", and an implementation plan is present.

### Stage 2: Preflight Status Update
Update status to "implementing" BEFORE invoking subagent.

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

### Stage 3: Prepare Delegation Context

PR-specific context for the cslib-implementation-agent:

- Target output: `specs/{NNN}_{SLUG}/pr-description.md` (canonical PR description file)
- Diff analysis: Run `git diff` to analyze what changes are present on the current branch
- Standards: `pr-description-format.md` and `pr-conventions.md` (loaded via index-entries.json `languages: ["pr"]`)
- Note: Branch creation and CI verification are handled by the `/pr` command

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-pr-implementation"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "pr"
  },
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "orchestrator_mode": true,
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "pr_description_path": "specs/{NNN}_{SLUG}/pr-description.md"
}
```

**Important**: The subagent's task is PR description composition only --
NOT branch creation, CI verification, or Lean proof implementation. The agent should:
1. Read the task description and plan to understand what was implemented
2. Run `git diff` (or `git diff upstream/main...HEAD`) to analyze changes on the current branch
3. Compose `pr-description.md` following the canonical format from `pr-description-format.md`
4. Determine `base_branch` (typically `"main"`) and include it in the return metadata
5. Write `.return-meta.json` with status `implemented` when done

### Stage 4: Invoke Subagent
Use Agent tool with subagent_type: "cslib-implementation-agent".

### Stage 4b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 4b). Do NOT skip these stages for any reason.

### Stage 5: Parse Subagent Return
Read the metadata file from `specs/{N}_{SLUG}/.return-meta.json`.

### Stage 6: Update Task Status (Postflight — PR READY)

**CRITICAL DIFFERENCE**: This skill calls `pr_ready` as the status target, NOT `implement`.
This sets the task to `[PR READY]` instead of `[COMPLETED]`, directing the user to run `/merge`.

```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" pr_ready "$session_id"
```

Do NOT call `postflight implement` -- that would incorrectly mark the task as `[COMPLETED]`
before the PR has been submitted.

### Stage 7: Link Artifacts
Add pr-description.md artifact to state.json with summary. Update TODO.md per
`@.claude/context/patterns/artifact-linking-todo.md` with `field_name=**Summary**`,
`next_field=**Description**`.

Artifact type: `pr_description`, path: `specs/{NNN}_{SLUG}/pr-description.md`.

**base_branch**: Also record the base branch in the state.json task entry. This field is read
by the `/pr` command to set `--base` when creating the PR. Use the branch name the PR will
target (e.g., `"main"` for direct upstream PRs, or `"feat/parent-branch"` for stacked PRs).

The subagent should determine and report the base branch used (typically `"main"` unless
this task is stacked on top of another unmerged PR).

```bash
# Write base_branch to state.json task metadata
base_branch_used="main"  # or the parent branch for stacked PRs

bash .claude/scripts/state-write.sh \
  '.active_projects |= map(if .project_number == $num then . + {"base_branch": $branch} else . end)' \
  --session-id "$session_id" \
  --argjson num "$task_number" \
  --arg branch "$base_branch_used"
```

### Stage 8: Git Commit
Commit changes with session ID.

### Stage 9: Return Brief Summary

Include a message directing the user to run `/pr {task_number}` now that the task is `[PR READY]`:

> PR description complete. Task is now [PR READY].
> Run `/pr {task_number}` to create the branch, run CI, and submit the pull request.

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit .lean files** - All CSLib proof work is done by agent
2. **Run lake build/test/lint** - Verification is done by agent
3. **Use lean-lsp MCP tools** - Domain tools are for agent use only
4. **Grep for sorries** - Debt analysis is agent work
5. **Write pr-description.md** - Artifact creation is agent work
6. **Create feature branches** - Branch creation is handled by the `/pr` command, not this skill
7. **Run CI pipeline** - CI verification (lake test, lint, shake) is handled by the `/pr` command, not this skill
8. **Call `postflight implement`** - This skill MUST use `postflight pr_ready` to set [PR READY]

See `context/standards/postflight-tool-restrictions.md` § "MUST NOT Section Template"
for the full PROHIBITION clause (the lead skill must not continue, complete, or "fill in" a
partial/failed subagent's work; report the status and let the user re-run `/implement`) and the
postflight-phase allowed-operations list (read metadata, TODO.md update, artifact linking, git
commit, cleanup); this skill's own state.json update uses jq with the `pr_ready` status target,
not `postflight implement`.

## Return Format

Brief text summary (NOT JSON).
