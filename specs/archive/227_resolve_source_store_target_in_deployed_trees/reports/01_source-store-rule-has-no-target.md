# Sweep Evidence Report: source-store rule has no reachable target in deployed trees

**Task**: Resolve the source-store target in deployed trees
**Produced**: 2026-09-16 (repository hygiene sweep in ~/Projects/BimodalLogic); carried into the source-store repository 2026-09-17
**Status**: Pre-research evidence.
**Effort**: Small, but the fix probably lands in a *different repository*.
**Dependencies**: None.
**Sources/Inputs**:
- `.claude/rules/source-store-deploy-boundary.md`
- `.gitignore:85` (`/.claude`), repository root listing
- `.claude/CLAUDE.md` § "Rules References"
- `specs/reviews/review-2026-09-16.md`, Finding L3

## Executive Summary

- `.claude/rules/source-store-deploy-boundary.md` instructs that every write targeting
  `.claude/**` is wrong and must go to `agent-system/extensions/**` instead: *"Edit the source
  store instead: `agent-system/extensions/core/**` for core system files … `agent-system/extensions/<ext>/**`
  for extension-owned files."*
- **No `agent-system/` directory exists in this repository.** `ls agent-system` →
  `No such file or directory`.
- The rule is therefore unfollowable as written *here*. An agent obeying it has nowhere to write;
  an agent ignoring it writes into `.claude/`, which is gitignored (`/.claude` at `.gitignore:85`)
  and which the next deploy overwrites — the exact outcome the rule exists to prevent.
- The rule itself is correct in substance. The problem is that it was deployed into a repository
  whose source store lives elsewhere, and it names the path as if it were local.

## Why this is worth a task rather than an edit

Two things make the obvious fix wrong:

1. **Editing `.claude/rules/source-store-deploy-boundary.md` in place is the very thing the rule
   forbids**, and the edit would be wiped by the next `deploy-headless.sh` / `[Reload All]`. The
   file's own Enforcement section documents an advisory `PostToolUse` hook
   (`validate-meta-write.sh`) that fires on precisely this write.
2. **`.claude/` is gitignored here**, so any in-place fix is invisible to version control and
   unreviewable.

The durable fix belongs in whatever repository *does* hold `agent-system/extensions/core/rules/`.
This task's deliverable in *this* repository is therefore the diagnosis and the decision, plus
whichever of the local options below is chosen.

## What the rule should probably say

The rule's own "Known limitation" paragraph already gets close to the right analysis:

> a PostToolUse hook sees only a `file_path` argument. It cannot know task type, lifecycle stage,
> command context, **or which repository the path belongs to** — its `specs/*|*/specs/*` skip
> matches unconditionally regardless of repo.

The same blind spot applies to the rule text: it hard-codes a source-store path that is correct in
the agent-system repository and absent in every repository the system is deployed *into*. Options:

- **Make the path conditional**: "if this repository contains `agent-system/`, edit there;
  otherwise the source store is external — do not edit `.claude/**` at all, and report the needed
  change instead." This preserves the rule's intent in both contexts.
- **Make the rule detect its own deployment**: have the deploy step rewrite the "Correct Edit
  Target" section with the actual source-store location, which it knows.
- **Scope the rule out of deployed trees entirely**, leaving only the agent-contract half (the
  implementer-agent MUST NOT bullets), which is repository-independent and already exists.

## Scope of this task in this repository

1. Confirm the diagnosis against the current deployed tree (the sweep confirmed it on 2026-09-16;
   re-confirm, since `.claude/` is regenerated and may have changed).
2. Check `.syncprotect` — if the file is listed there, a local correction would actually survive
   sync, which changes the calculus.
3. Decide which of the three options above is right, and record the decision here.
4. Carry the fix to the agent-system repository, or produce a precise patch for it that the user
   can apply there.
5. If a local stopgap is wanted in the meantime, prefer adding a clarifying note to the
   *repository-level* `CLAUDE.md` (which is tracked and is not a deploy artifact) over editing
   anything under `.claude/`.

## Verification

- `.claude/rules/source-store-deploy-boundary.md` (after the next deploy) names a target that
  exists, or explicitly handles the "source store is external" case.
- A test write to a `.claude/**` path produces advice an agent can actually act on.
- Nothing in this task's change set lives under `.claude/` in this repository.
