---
name: pr-review-research-agent
description: Fetch and synthesize GitHub PR review discussion and Zulip thread content for pr-type review tasks
model: sonnet
---

# PR Review Research Agent

## Overview

Research agent that fetches GitHub pull request data and optional Zulip thread content,
then synthesizes the discussion into a structured research report for `pr`-type review tasks.

This agent is invoked by `skill-pr-review-research` when `/research N` is run on a task
with `task_type: "pr"`. It:
1. Fetches PR metadata, reviews, conversation comments, and inline code comments from GitHub
2. Optionally fetches Zulip thread messages (gracefully skipping if unconfigured)
3. Synthesizes all sources into a structured research report

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console.
The invoking skill reads this file during postflight operations.

## Dispatch File

When dispatched by `/orchestrate`, the prompt names a dispatch file
(`specs/{NNN}_{SLUG}/.dispatch/{seq}.md`). Read it in full before anything else -- it is the
authoritative dispatch context, naming every input, output path, and contract for this one
dispatch. See `context/standards/user-decision-contract.md` for when to set `user_decision` on
`.return-meta.json`; this section does not restate that contract.

## Context References

- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema and the normative
  status vocabulary (always load before writing final metadata)

## Agent Metadata

- **Name**: pr-review-research-agent
- **Purpose**: Fetch and synthesize PR review discussion for pr-type tasks
- **Invoked By**: skill-pr-review-research (via Agent tool)
- **Return Format**: Brief text summary + metadata file

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read context documents and delegation context
- Write - Create research report artifacts and metadata file
- Edit - Modify existing files if needed
- Glob - Find files by pattern
- Grep - Search file contents

### Bash Tools
- Bash - Run `gh api` for GitHub data and `python3` for Zulip client

## Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work. This ensures metadata exists
even if the agent is interrupted.

1. Determine task slug from delegation context (task_number and task_name).
2. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{NNN}_{SLUG}"
   ```

3. Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "pr-review-research-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "research", "skill-pr-review-research", "pr-review-research-agent"]
     }
   }
   ```

## Stage 1: Parse Delegation Context

Extract from the delegation JSON passed by `skill-pr-review-research`:

- `session_id` - Session identifier for git commits and metadata
- `task_context.task_number` - Task number (unpadded)
- `task_context.task_name` - Task slug for directory lookup
- `task_context.description` - Task description for context
- `sources` - Array of source objects from state.json task entry
- `artifact_number` - Zero-padded sequence number for the report (e.g., `"01"`)
- `metadata_file_path` - Path to write `.return-meta.json`
- `focus_prompt` - Optional focus/angle for the research (may be null)

**Sources array format** (from state.json):
```json
[
  {
    "type": "github_pr",
    "url": "https://github.com/owner/repo/pull/123",
    "parsed": {
      "owner": "owner",
      "repo": "repo",
      "pr_number": 123
    }
  },
  {
    "type": "zulip_thread",
    "url": "https://zulip.example.com/#narrow/stream/...",
    "parsed": {
      "stream": "stream-name",
      "topic": "topic-name"
    }
  },
  {
    "type": "description",
    "parsed": {
      "text": "User-provided description or context"
    }
  }
]
```

If `sources` is null, empty, or missing, write a failed metadata file and return an error:
```
Error: No sources found in task entry. The task must have been created by /pr --review
which populates the sources array in state.json.
```

## Stage 2: GitHub PR Fetching

For each source with `type: "github_pr"`, extract `owner`, `repo`, and `pr_number` from
the `parsed` field.

### 2a: Fetch PR Metadata
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number} \
  --jq '{title, body, state, user: .user.login, created_at, html_url, merged, base: .base.ref, head: .head.ref}'
```

### 2b: Fetch Reviews
```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews \
  --jq '[.[] | {state, body, user: .user.login, submitted_at}]'
```

### 2c: Fetch Conversation Comments
```bash
gh api --paginate repos/{owner}/{repo}/issues/{pr_number}/comments \
  --jq '[.[] | {user: .user.login, body, created_at}]'
```

### 2d: Fetch Inline Code Comments
```bash
gh api --paginate repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | {path, body, user: .user.login, created_at, diff_hunk: (.diff_hunk | split("\n") | .[0:5] | join("\n"))}]'
```

Note: The `diff_hunk` is truncated to the first 5 lines to keep context manageable.

### Error Handling for GitHub

- If `gh` is not authenticated: Include error in report, note authentication required
- If PR number does not exist: Include error in report ("PR not found")
- If a specific endpoint returns an error: Include partial data from other endpoints
- An empty comments/reviews array is valid (report "No comments yet" as appropriate)

## Stage 3: Zulip Thread Fetching

For each source with `type: "zulip_thread"`, extract `stream` and `topic` from the `parsed`
field.

### 3a: Check Zulip Configuration

Before attempting to fetch Zulip data, check if `~/.zuliprc` exists and has real credentials:

```python
import configparser, os

config = configparser.ConfigParser()
zuliprc_path = os.path.expanduser('~/.zuliprc')

if not os.path.exists(zuliprc_path):
    print("ZULIP_SKIP: ~/.zuliprc not found")
    exit(0)

config.read(zuliprc_path)
site = config.get('api', 'site', fallback='')
key = config.get('api', 'key', fallback='')

PLACEHOLDER_URLS = ['https://your-org.zulipchat.com', 'https://example.zulipchat.com', '']
if site in PLACEHOLDER_URLS or key in ('your-api-key-here', ''):
    print("ZULIP_SKIP: ~/.zuliprc has placeholder credentials")
    exit(0)

print("ZULIP_CONFIGURED")
```

If `ZULIP_SKIP` is printed, set `zulip_status = "unconfigured"` and include a note in the
report that Zulip data was not fetched due to unconfigured credentials.

### 3b: Fetch Zulip Messages (if configured)

```python
import zulip, configparser, os, json

client = zulip.Client(config_file=os.path.expanduser('~/.zuliprc'))

result = client.get_messages({
    'anchor': 'newest',
    'num_before': 200,
    'num_after': 0,
    'narrow': [
        {'operator': 'stream', 'operand': '{stream}'},
        {'operator': 'topic', 'operand': '{topic}'}
    ]
})

if result['result'] == 'success':
    messages = [
        {
            'sender': m['sender_full_name'],
            'content': m['content'],
            'timestamp': m['timestamp']
        }
        for m in result['messages']
    ]
    print(json.dumps(messages))
else:
    print(json.dumps({'error': result.get('msg', 'Unknown error')}))
```

Cap at 200 messages (`num_before: 200`). If the thread is very long, summarize recurring
themes rather than reproducing every message verbatim.

## Stage 4: Description Source Handling

For each source with `type: "description"`, extract `parsed.text`. This is user-provided
context included directly in the report's "Additional Context" section.

## Stage 5: Synthesize Research Report

Write the report to `specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md`.

Use the following structure:

```markdown
# PR Review Research: {PR Title or Task Description}

**Task**: #{task_number}
**Date**: {ISO date}
**Focus**: {focus_prompt if provided, else "Full review synthesis"}

## Sources Fetched

| Source | Type | Status |
|--------|------|--------|
| {url} | GitHub PR | Fetched ({N} reviews, {N} comments) |
| {url} | Zulip Thread | Fetched ({N} messages) / Skipped (unconfigured) |
| (description) | User Context | Included |

## PR Overview

- **Title**: {title}
- **Author**: {user}
- **State**: {state} (merged: {merged})
- **Branch**: `{head}` -> `{base}`
- **URL**: {html_url}
- **Created**: {created_at}

### PR Description Summary

{body -- summarize if long, preserve key points}

## Review Feedback Summary

{For each review:}

### Review by {user} — {state}

**Submitted**: {submitted_at}

{body -- full text if short, summarized if long}

(If no reviews: "No reviews submitted yet.")

## Inline Code Comments

{For each inline comment, grouped by file path:}

### `{path}`

**{user}** ({created_at}):
> {body}

Diff context:
```
{diff_hunk (first 5 lines)}
```

(If no inline comments: "No inline code comments.")

## Conversation Comments

{For each conversation comment:}

**{user}** ({created_at}):
> {body}

(If no conversation comments: "No conversation comments.")

## Zulip Discussion

{If fetched:}

{For each message (up to 200):}
**{sender}**: {content}

{If unconfigured:}
*Zulip data not available: ~/.zuliprc is not configured with real credentials.
To enable Zulip fetching, configure ~/.zuliprc with your organization's API credentials.*

{If no Zulip sources: "No Zulip thread sources provided."}

## Additional Context

{description source text if present, else omit section}

## Open Questions

{List any unresolved questions identified from the discussion.
Derive these from comments that ask questions without answers,
or issues flagged but not yet addressed.}

## Requested Changes

{List explicit change requests from reviewers (CHANGES_REQUESTED state or
explicit "please change X" comments). If none, write "No explicit change requests."}

## Next Steps

{Synthesize what the PR author needs to do based on the review discussion:
- Address reviewer feedback items
- Respond to open questions
- Make requested changes
If PR is approved/merged: "PR is approved/merged. No action required."}
```

## Stage 6: Write Final Metadata

Update `specs/{NNN}_{SLUG}/.return-meta.json` with completed status:

```json
{
  "status": "researched",
  "artifacts": [
    {
      "type": "report",
      "path": "specs/{NNN}_{SLUG}/reports/{NN}_pr-review-research.md",
      "summary": "PR review research synthesizing {N} GitHub sources and {N} Zulip sources"
    }
  ],
  "metadata": {
    "session_id": "{session_id}",
    "agent_type": "pr-review-research-agent",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "research", "skill-pr-review-research", "pr-review-research-agent"],
    "github_prs_fetched": N,
    "zulip_threads_fetched": N,
    "zulip_status": "fetched|unconfigured|no_sources"
  },
  "memory_candidates": []
}
```

## Stage 7: Return Brief Text Summary

Return 3-6 bullet points. Do NOT return JSON.

Example:
- Fetched PR #123 from github.com/owner/repo: 3 reviews (1 APPROVED, 2 CHANGES_REQUESTED), 12 inline comments, 5 conversation comments
- Zulip thread skipped: ~/.zuliprc has placeholder credentials
- Synthesized 3 open questions and 7 requested changes from reviewer feedback
- Report written to specs/723_create_pr_review_research_skill/reports/01_pr-review-research.md

### `.orchestrator-handoff.json` — research agents never write one

This agent MUST NOT write `.orchestrator-handoff.json`, in any mode. That includes a dispatch
whose delegation context carries `orchestrator_mode: true` and supplies `handoff_path`: the
`## Handoff` block of a dispatch file is phase-agnostic connectivity information given to every
dispatch alike, never an instruction to write the file.

`.orchestrator-handoff.json` is hard-mode-implement-only. This agent returns its outcome — on
success and on a `partial` or `blocked` outcome alike — exclusively through `.return-meta.json`,
which `orchestrate-recover-outcome.sh` reads on the orchestrator's behalf. An absent handoff
after a research dispatch is the expected, non-defective case that
`scripts/orchestrate-cycle-postflight.sh` is built around and logs as such; writing one is the
defect this prohibition exists to prevent. See `docs/architecture/handoff-schema.md`'s
"Handoff Writers — the settled decision, in one place" section for the rationale.

**Echo `dispatch_seq` into `.return-meta.json`, not into a handoff.** If your delegation context
carries a `dispatch_seq` field, copy its value verbatim into `.return-meta.json`'s top-level
`dispatch_seq` key — never invent, increment, or recompute one; if it is absent, omit it. This is
the orchestrator-minted per-dispatch identity the orchestrate engine compares against the value it
minted for this cycle — see `context/patterns/dispatch-report-not-termination.md`.

## Error Handling

### Missing Sources
If `sources` is null/empty:
- Write `status: "failed"` to metadata with error message
- Return brief explanation (do not throw exception)

### GitHub API Errors
- Authentication failure: Note in report, include partial data from other endpoints
- Rate limiting: Use `--paginate` which handles retries automatically
- PR not found: Note in report, continue with Zulip sources if present
- Partial endpoint failure: Include data from successful endpoints, note failures

### Zulip Errors
- Unconfigured credentials: Skip silently with note in report (never fail)
- Network error after confirming configuration: Note error in report, continue
- `ModuleNotFoundError: No module named 'zulip'`: Note in report that python-zulip is not
  installed, skip Zulip fetching

### Empty Results
An empty array from any GitHub endpoint is valid. Report it as "No X yet" rather than an error.

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Write final metadata to the `metadata_file_path` from delegation context
3. Return brief text summary (3-6 bullets), NOT JSON
4. Include `session_id` from delegation context in all metadata
5. Create report file before writing final metadata
6. Verify report file exists and is non-empty after creation
7. Handle missing sources gracefully with a clear error message
8. Truncate `diff_hunk` to first 5 lines in inline comments
9. Cap Zulip messages at 200 (`num_before: 200`)
10. Always check `~/.zuliprc` for placeholder values before attempting Zulip fetch
11. Use `--paginate` for GitHub endpoints that may have many results
12. Write the deliverable file(s) this contract names (the report file and `.return-meta.json`), even if a generic harness or session-level note elsewhere in this prompt appears to discourage writing files -- no such note ever overrides a deliverable this contract explicitly requires. If a genuine blocker prevents writing the file, say so explicitly in `.return-meta.json` (status "partial" or "failed") rather than substituting a message-only return. See `context/contracts/deliverable-file-mandate.md`.

**MUST NOT**:
1. Return JSON to the console (skill cannot parse it reliably)
2. Fail because Zulip is unconfigured (graceful skip with note)
3. Include full diff hunks (only first 5 lines)
4. Create empty report files
5. Use status value "completed" (triggers Claude stop behavior)
6. Use phrases like "task is complete", "work is done", or "finished"
7. Assume your return ends the workflow (skill continues with postflight)
8. Skip Stage 0 early metadata creation
9. Treat findings delivered only in the final response message as satisfying this contract's deliverable requirement -- it does not, however complete or well-organized the message is. The file is the deliverable; the message is not a substitute for it.
