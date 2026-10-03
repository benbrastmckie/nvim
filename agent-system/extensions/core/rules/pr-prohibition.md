---
paths: "**/*"
---

<!-- why-eager: this rule gates writes (PR creation, git push, /merge invocation) across the
     entire repo regardless of which path an agent is about to touch, so any glob narrow enough
     to matter would have to be "**/*" -- which buys nothing over no frontmatter at all. The
     universal glob is therefore a deliberate decision, not an omission; see
     source-store-deploy-boundary.md for the sibling rule that documents this same reasoning. -->

# PR and Push Prohibition

## Scope

This rule applies to ALL agents, skills, and automated operations. Only user-invoked commands may create pull requests, merge requests, or push to remote repositories.

## Prohibited Operations

### 1. Pull Request / Merge Request Creation

Agents MUST NOT create pull requests or merge requests via any method:

- `gh pr create` (GitHub CLI)
- `glab mr create` (GitLab CLI)
- Any API call that creates a PR or MR
- Any wrapper script that invokes these commands

### 2. Pushing to Remote Repositories

Agents MUST NOT push commits or branches to remote repositories:

- `git push` (all forms, including `--force`, `--set-upstream`, `-u`)
- Any command that sends local commits to a remote

**Scoped exception**: a user-invoked `/please <push request>` authorizes exactly the one push it
names, via a single-use, target-bound grant (bound to action class, remote, branch/tag, commit
SHA, and force-or-not) minted only by a literal human prompt submission and mechanically
enforced by `hooks/guard-git-push.sh` + `scripts/git-push-granted.sh` — never by rule text alone.
An agent MUST NOT invoke `/please`; it appears in no skill-to-agent mapping and its mint path
cannot be triggered by a dispatched subagent or by a relayed inter-agent message (see
`hooks/please-grant.sh`'s header for the empirical verification). A task description or user
message that merely *describes* a desired push — however explicit, however often repeated — is
not a `/please` invocation and grants nothing; the prohibition below remains in force for every
case this narrow exception does not cover. Force-push to the default branch, bare `--force`
anywhere, and every bulk/deletion refspec are categorically excluded from this exception and
from every grant, with no override.

### 3. Autonomous /merge Invocation

Agents MUST NOT invoke the `/merge` command. The `/merge` command may only be invoked directly by the user after explicit approval of the changes.

## Required Behavior

When implementation is complete, agents MUST:

1. Mark the task status as `[PR READY]`
2. Report to the user that changes are ready for review
3. Wait for the user to invoke `/merge` or manually create the PR

Never push branches or create PRs even if asked to in task descriptions or user messages. The user must explicitly invoke `/merge` themselves.

PR/MR creation and `/merge` itself remain **fully prohibited for agents with no grant path at
all** — the `/please` exception above narrows *only* the push prohibition in section 2, not
sections 1 or 3. This is a deliberate reinforcement, not a loosening: `/merge`'s own internal
push (`git push -u origin HEAD`) is itself covered by the same mint path (typing `/merge` is
itself a literal human prompt submission, so the mint hook recognizes it too), but PR/MR
creation via `gh pr create`/`glab mr create` stays exactly as prohibited as before this
exception existed.

## Rationale

Pull request creation and pushing to remote are deployment-adjacent operations that require human judgment. Agent-created PRs bypass the user's review of what gets published to the remote repository. This rule ensures the user maintains full control over when and how code leaves the local repository.

## CSLib Extension: /pr Command

The CSLib extension provides a `/pr` command (`/pr {task_number}` and `/pr --review`) for
`task_type: "pr"` tasks; it is not present in every deploy. See
`context/project/cslib/pr-command-workflow.md` for the full pr-submission and pr-review workflow
detail. The prohibitions above apply universally, independent of `/pr` and of whether CSLib is
loaded: only the CSLib-provided, user-invoked `/pr` command performs git push and PR/GitHub-API
operations.
