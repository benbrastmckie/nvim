---
description: Authorize one otherwise-blocked git action for this single invocation (user-only)
allowed-tools: Bash(git:*), Bash(.claude/scripts/git-push-granted.sh:*), AskUserQuestion
argument-hint: "<push request, e.g. 'push origin feature-x' or 'push tag v1.0.0 to origin'>"
---

# Command: /please

**Purpose**: Authorizes exactly ONE otherwise-blocked action per invocation — the human-facing
confirmation surface for the consent-gated push/destructive-action mechanism.
**User Only**: YES — Agents MUST NOT invoke this command. It is never available to an agent: it
appears in no skill-to-agent mapping, and its mint path (`hooks/please-grant.sh`) fires only on
this Claude Code session's own literal, human-typed prompt submission — never on an expanded
command body, and never on a prompt relayed from another agent (an inter-agent message arrives
wrapped in `<agent-message from="...">` tags, which never matches the mint hook's prefix check).
**Layer**: 1 (Direct execution)
**Delegates To**: none — this command IS the confirmation step; the actual grant was already
minted by `hooks/please-grant.sh` before this command body ever runs (see "How Minting Actually
Happens" below).

---

## Warning

**CRITICAL CAVEAT**: Typing `/please ...` proves to the system that a human submitted THIS
prompt — it does **not** prove that the command this command then runs is the one the human
meant. The grant is provenance, not intent-verification. For anything irreversible (a push, a
`git reset --hard`, a `git clean -fd`, a stash drop), **confirmation via `AskUserQuestion` before
the action runs is mandatory**, not optional, precisely because the grant alone cannot close
that gap.

---

## How Minting Actually Happens

A `UserPromptSubmit` hook (`hooks/please-grant.sh`) runs BEFORE this command body ever executes,
on the raw, literal text of the prompt you just typed. It parses the request, checks categorical
exclusions, and — if accepted — mints a single-use, HMAC-signed grant bound to the exact action,
remote/branch (or tag), commit SHA, and force-or-not. This command's own job is narrower: confirm
with the user, then run the ONE sanctioned command that consumes that grant. This command never
mints anything itself; if the mint hook refused (ambiguous request, categorical exclusion), there
is no grant to consume and the action below will fail closed with a clear error.

---

## Usage

```
/please push <remote> <branch>
/please push <branch> to <remote>
/please push tag <name> to <remote>
/please <push form> --force-with-lease
```

(The mint hook's grammar also accepts the five destructive-action forms documented in
`hooks/please-grant.sh` — `git reset --hard`, `git clean -fd`, `git checkout -- <path>`,
`git restore <path>`, `git stash drop`/`clear` — for the companion `guard-destructive-git.sh`
grant check. This command's own body below covers the push forms; a destructive-action request
is confirmed and executed the same way, substituting the literal git command for the wrapper
invocation in STEP 4.)

---

## Never-List (refused regardless of wording, enforced in THIS command's own logic — never by a
hook, since hooks exist to stop agents and this command is user-invoked)

Refuse immediately, before STEP 1, if the request asks for any of:
- Credential or secret access (reading, printing, or exfiltrating any key, token, password, or
  `.env`-shaped file)
- Deletion outside this repository
- `.git` internals (rewriting refs by hand, editing `.git/config`, `.git/hooks/`, packed-refs,
  or anything under `.git/` directly rather than through an ordinary git command)
- Disabling, editing, or removing hooks or hook settings (any write to `.claude/hooks/`,
  `.claude/settings.json`'s `hooks` key, or the push-grant store/key path — the latter is also
  mechanically blocked by `guard-git-push.sh`'s tamper guard, but this command refuses it by its
  own logic too, before that hook is ever reached)

If the request matches any of these, respond:
```
Refused: this request falls under /please's never-list ({matched category}). /please
authorizes one otherwise-blocked git action for THIS invocation only — it is not a general
escape hatch, and no wording changes that.
```
**STOP.**

---

## Execution

**EXECUTE NOW**: Follow these steps in sequence. Do not just describe what should happen —
actually perform each step.

### STEP 1: Parse the Request

**EXECUTE NOW**: Read `$ARGUMENTS` (the text after `/please`). This is informational for THIS
command body — the mint hook already parsed the literal prompt and either minted a grant or
didn't. Extract, from the same text, what you will show the user in STEP 2: remote, branch/tag,
and whether `--force-with-lease` was requested.

If `$ARGUMENTS` doesn't look like a push request matching the usage forms above (and isn't one
of the five destructive forms), say so and ask the user to retype it in an accepted form. Do not
guess at what they meant.

### STEP 2: Show the Exact Command and Its Effect

**EXECUTE NOW**: Compute and display local vs. remote state before asking for confirmation.

```bash
remote="{parsed remote}"
ref="{parsed branch or tag}"
git fetch "$remote" "$ref" --quiet 2>/dev/null || true
local_sha="$(git rev-parse "$ref" 2>/dev/null || echo unknown)"
remote_sha="$(git rev-parse "${remote}/${ref}" 2>/dev/null || echo "(does not exist on remote)")"
commit_count="$(git rev-list --count "${remote}/${ref}..${ref}" 2>/dev/null || echo unknown)"
```

Display:
```
Please Summary
==============

Action:       push {ref} to {remote}{ (--force-with-lease) if requested}
Local SHA:    {local_sha}
Remote SHA:   {remote_sha}
Commits:      {commit_count} ahead of {remote}/{ref}
```

### STEP 3: Confirm Before Any Irreversible Step

**EXECUTE NOW**: Ask via `AskUserQuestion` — mandatory, never skipped, per the caveat above.

```json
{
  "question": "Proceed with this push?",
  "header": "Confirm /please",
  "multiSelect": false,
  "options": [
    {"label": "Yes, push {ref} to {remote}", "description": "Runs the sanctioned wrapper, consuming the grant just minted for this exact action"},
    {"label": "Cancel", "description": "Abort without pushing. Revokes the grant so it cannot be used by a later, different command."}
  ]
}
```

**Response handling**:
- **"Yes, push ..."**: **IMMEDIATELY CONTINUE** to STEP 4.
- **"Cancel"**: run `bash .claude/scripts/git-push-granted.sh --revoke`, display "Cancelled. No
  push was performed; the grant was revoked." and **STOP**.

### STEP 4: Execute — Through the Sanctioned Wrapper, Never a Bare `git push`

**EXECUTE NOW**:

```bash
bash .claude/scripts/git-push-granted.sh --remote "$remote" --ref "$ref" \
  $( [ "$force_with_lease_requested" = "1" ] && echo --force-with-lease )
```

Prefer `--force-with-lease` (which the wrapper resolves against the currently observed remote
SHA via `git`'s own lease mechanism) over a bare `--force` whenever the request asked for any
force form — bare `--force` is categorically excluded from every grant and the wrapper will
refuse it regardless.

**If the wrapper fails** (no matching grant, expired, wrong target, or the push itself failed):
display its stderr verbatim and **STOP** — do not retry with a bare `git push`, which the push
guard hook will block unconditionally, and do not widen the request to work around the failure.

**If it succeeds**: display the wrapper's own success line and **STOP**. Do not log the action
a second time — `scripts/git-push-granted.sh` already appended the `push_grant_consumed` audit
event via `scripts/events-append.sh`.

---

## Agent Restrictions

This command MUST NOT be invoked by any agent, skill, or automated process. It appears in no
skill-to-agent mapping. Its mint path is a `UserPromptSubmit` hook that fires only on a literal
human prompt submission — a dispatched subagent has no prompt-submission pipeline to trigger it,
and an inter-agent relayed message arrives wrapped in a way that never matches the hook's
prefix check (verified empirically; see `hooks/please-grant.sh`'s header comment).
