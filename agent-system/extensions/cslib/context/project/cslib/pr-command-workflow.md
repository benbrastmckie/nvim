# CSLib /pr Command Workflow

This file is the live, deployed home of the two CSLib-only `/pr` subsections that formerly lived
inline in `.claude/rules/pr-prohibition.md`. Relocated here because CSLib is the extension that
actually provides the `/pr` command; the universal PR/push prohibitions in `rules/pr-prohibition.md`
apply regardless of whether CSLib is loaded, and pointing to this file keeps that rule short while
this workflow detail stays available wherever CSLib is deployed.

## CSLib Extension: /pr Command

For tasks with `task_type: "pr"` (CSLib pull request tasks), the workflow differs from the
general `/merge` flow:

1. **skill-pr-implementation** (invoked via an implement-phase dispatch for N): Analyzes the git diff and
   composes `specs/{NNN}_{SLUG}/pr-description.md`. Transitions the task to `[PR READY]`.
   Does NOT create branches or run CI.

2. **`/pr {task_number}`** (user-invoked command): The single entry point for branch
   creation, Mathlib cache fetch, the 7-step CI pipeline, PR title confirmation, and
   `gh pr create` submission.

The prohibition on agent-created PRs and agent pushes still applies. Only step 2 (the
user-invoked `/pr` command) performs git push and PR creation.

## CSLib Extension: /pr --review Workflow

The `--review` flag to `/pr` creates tasks with `task_type: "pr"` and a `sources` array in
state.json. These tasks use the pr-review skills:

1. **`/pr --review <sources...>`** (user-invoked command): Creates a pr-type task with sources
   (GitHub PR URLs, Zulip thread URLs, or free-text descriptions). This is the ONLY way to
   create pr-review tasks.

2. **A research-phase dispatch for N** (pr-type task): Routes to `skill-pr-review-research`, which fetches
   GitHub PR data (reviews, comments, inline comments) and optionally Zulip thread data.
   Produces a research report.

3. **An implement-phase dispatch for N** (pr-type task with sources): Routes to `skill-pr-review-implementation`,
   which dispatches to `pr-review-implementation-agent`. The agent composes `pr-response.md`
   (GitHub PR comment) and optionally `zulip-response.md` (Zulip thread message). Transitions
   task to `[PR READY]`.

4. **`/pr N`** (when task is [PR READY] with sources): STEP 0.5 handles the posting workflow
   -- commits/pushes any local changes, posts `pr-response.md` as a GitHub PR comment,
   optionally sends `zulip-response.md` to Zulip. Transitions task to `[COMPLETED]`.

### Distinguishing pr-submission vs pr-review

| Condition | Workflow |
|-----------|----------|
| `task_type: "pr"`, `sources` absent or empty | pr-submission (legacy): the implement phase produces pr-description.md |
| `task_type: "pr"`, `sources` present | pr-review: the implement phase produces pr-response.md + zulip-response.md |

The dispatch within `skill-pr-review-implementation` checks for sources and forks to either
the review path or the legacy pr-description path.

The prohibition on agent-created PRs and agent pushes still applies to both workflows. Only
`/pr N` (user-invoked) performs git push and GitHub API operations.
