# Research Report: Post-Incident Uncommitted-State Verification Checklist

**Task**: 363 - A one-page post-incident verification checklist naming uncommitted pre-session
tree state as the first mandatory check
**Started**: 2026-10-08
**Completed**: 2026-10-08
**Effort**: small (single-file standards doc + one guard cross-reference line)
**Dependencies**: stash-reclassification task (archived; see `specs/archive/361_reclassify_bare_git_stash_as_destructive/`) -- complete, so this task is unblocked
**Sources/Inputs**: codebase (`agent-system/extensions/core/context/standards/*.md`,
`hooks/guard-destructive-git.sh`), `.claude-extensions.json`, local git-plumbing experiments
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The incident this task responds to is already fully documented, with re-confirmed figures, in
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`'s "No Destructive
  Git on Uncommitted Work -- Bare `git stash` Incident and Full Detail" section -- no new
  investigation of root cause is needed, only a forward-looking checklist.
- Re-derivation of the carried figures confirms the description's numbers against the source
  narrative verbatim: two independent implementation agents, each running a bare whole-tree
  `git stash`; one stash spanning a ~375-second build whose later `git stash pop` aborted and
  applied nothing; "roughly thirty files" of pre-session uncommitted work (a freshly-deployed
  configuration tree plus its extension-state file) surviving only inside a 53-file stash entry;
  sibling commits unharmed throughout. No divergence found.
- Recommend a **new, standalone one-page file** at
  `context/standards/post-incident-verification-checklist.md` (source store:
  `agent-system/extensions/core/`) rather than appending to any of the three surveyed existing
  documents -- see Decisions for the per-candidate rejection reasoning.
- The four checks, their order, and the concrete stash/reflog commands for check (1) were
  verified by hand against a disposable scratch git repository (see Findings); the key fact --
  `git diff HEAD` reads completely empty after a bare stash revert, even though pre-session work
  is sitting in the stash entry -- was reproduced directly.
- The guard's refusal message (`hooks/guard-destructive-git.sh`) already has a
  `stash_revert`-specific block (lines 605-615) ending in the pathspec-scoped-stash guidance line
  (614); the cross-reference line belongs immediately after it, before the closing `fi` on line
  615. No other line in the file needs to change.

## Context & Scope

Researched: (a) the incident record and its exact figures, to re-derive rather than blindly
restate the carried numbers in the task description; (b) the three standards documents named as
survey candidates (`git-safety.md`, `git-staging-scope.md`, `git-workflow-narrative.md`) plus one
I located independently (`context/contracts/recovery.md`) for fit as a placement target; (c) the
concrete git commands needed for check (1)'s stash-entry/reflog comparison, verified by hand; (d)
the exact insertion point in the guard hook's refusal text for the cross-reference. Out of scope
per the dispatch: no change to the guard's patterns, `DESTRUCTIVE_ACTION_CLASS` values, escape
hatch, or rule text (owned by the now-archived stash-reclassification task); no incident-
management framework, severity taxonomy, or candour/disclosure requirements; no retroactive
audit of other repos; no worktree-isolation proposal (already ruled out, confirmed the decision
record exists at `specs/decisions/worktree-isolation-removal-reaffirmation.md`).

## Findings

### Codebase Patterns

**The incident is already the subject of a detailed standards section.**
`context/standards/git-workflow-narrative.md:80-142` ("No Destructive Git on Uncommitted Work --
Bare `git stash` Incident and Full Detail") documents the mechanism, the measured incident, and
the verdict reasoning for what stays permitted (pathspec-scoped push, pop/apply). It explicitly
separates the loss itself from "the verification-scope half of that finding," which it says "is
filed and tracked separately and is not covered here" -- i.e. this task. That narrative is the
authoritative source for the carried figures and matches the dispatch description with no
divergence.

**Three survey candidates, all rejected as the placement target:**

- `context/standards/git-safety.md` (700 lines) -- entirely a *before/during* risky-operation
  playbook (safety-commit-then-rollback patterns, XML stage templates, a migration checklist for
  removing `.bak` files). Its one relevant paragraph (`Recovering an Unconsumed Dispatch`, lines
  34-45) is about undoing a *never-issued* dispatch, a different scenario. No natural section
  for "what to check after a destructive action already ran against a shared tree."
- `context/standards/git-staging-scope.md` (564 lines) -- a commit-scope contract (what to
  stage, exclusion pathspecs, the scoped-commit script). Concerned with *staging discipline*
  before a commit, not post-incident recovery verification. No `stash`/`uncommitted`/`reflog`
  hits relevant to recovery checking.
- `context/standards/git-workflow-narrative.md` (214 lines) -- already carries the incident
  narrative itself (see above) but is explicitly a lazily-loaded *reactive elaboration*
  companion to the eager `rules/git-workflow.md` core, read "once an agent is already following
  the core's rules" -- never positioned as something to find fast mid-incident. Appending the
  checklist here would bury a findability-critical artifact inside a 200+-line narrative file
  alongside four unrelated incident write-ups.
- `context/contracts/recovery.md` (113 lines, found independently) -- the fix-forward recovery
  ladder for *build errors* (fix forward / strategic-sorry / snapshot-rollback). Different failure
  class entirely (a build fails vs. a destructive git action already ran); not a fit.

**Ruling**: a new, named one-page file. The task description's own reasoning -- "a checklist
that must be findable under incident conditions argues for its own named page" -- holds up
against all three candidates: none has a section an agent reaching for "what do I check after a
stash/reset/checkout incident" would land on without reading past unrelated content first.
Proposed path: `context/standards/post-incident-verification-checklist.md`. This also follows
the existing one-topic-per-file convention in `context/standards/` (e.g.
`push-consent-relay.md`, `user-decision-contract.md`, both single-topic, both under 200 lines).

### Verified Git Mechanics for Check (1)

Reproduced by hand in a disposable scratch repository (`/tmp`, outside this repo, discarded
after use -- no effect on this repo's tree):

1. After `git stash push -u -- <paths>` (or a bare whole-tree stash), the working tree reverts to
   HEAD. **`git status --short` and `git diff HEAD` both come back completely empty** -- this is
   the exact deceptive mechanism the task description names: a reverted file matches HEAD, so it
   reads as clean to every naive check, confirmed directly rather than asserted.
2. `git stash list` enumerates outstanding entries (including, on a shared tree, entries left by
   a sibling agent).
3. `git diff --stat HEAD stash@{N}` lists exactly the tracked paths the stash entry captured that
   differ from the current (reverted) tree -- the per-path signal of what was pulled out.
4. `git stash show -p -u stash@{N}` is required (not the bare `git stash show -p`) to see
   **untracked** file content too -- confirmed that a bare `git stash show -p` on a stash created
   with `-u` omits the untracked file entirely, while adding `-u` to the `show` surfaces it. This
   matters because the incident's lost content included untracked state.
5. Once a stash entry has been popped-and-failed-then-dropped, or dropped outright,
   `git fsck --unreachable --no-reflog | grep commit` surfaces its still-unreachable commit
   objects (confirmed: 3 dangling commits recovered after a deliberate `stash drop` in the test
   repo -- the stash merge commit, its untracked-tree parent, and the index-tree parent).
   `git show --stat <sha>` on each candidate reveals which one is the relevant stash. This is the
   reflog-adjacent recovery path the task description requires ("compared against THE STASH
   ENTRY and THE REFLOG, NOT merely against HEAD") for the case where the entry is no longer in
   `git stash list` at all.

### Guard Hook Cross-Reference Point

`hooks/guard-destructive-git.sh` (source store path; deployed at
`.claude/hooks/guard-destructive-git.sh`) already carries a `stash_revert`-specific refusal block
at lines 605-615, added by the now-archived stash-reclassification task. Its last content line
(614, "A pathspec-scoped 'git stash push -- <path>' remains permitted...") is immediately
followed by the closing `fi` on line 615. The cross-reference belongs as one or two new `echo ...
>&2` lines inserted between 614 and 615, inside the `stash_revert`-only conditional (not in the
generic trailer at 616-621, which fires for every destructive class, not just stash). Example
shape (for the implementation phase, not applied here):

```bash
echo "If this stash already ran: run the post-incident verification checklist at" >&2
echo "context/standards/post-incident-verification-checklist.md -- it checks uncommitted" >&2
echo "pre-session tree state FIRST, since a reverted file reads clean and has no other" >&2
echo "recovery path once the stash entry is gone." >&2
```

No other line in the hook needs to change; the task's non-goals (no change to patterns, classes,
escape hatch, or rule text) are satisfied by touching only this message body.

## Decisions

- **New file, not a section append.** Ruled against all three named candidates plus one found
  independently (`context/contracts/recovery.md`); reasoning above under Findings.
- **Proposed path**: `context/standards/post-incident-verification-checklist.md` under the
  `agent-system/extensions/core/` source store (never the deployed `.claude/` copy directly, per
  `rules/source-store-deploy-boundary.md`); redeploy required afterward.
- **Cross-reference insertion point**: `hooks/guard-destructive-git.sh` lines 614/615 (inside the
  `stash_revert` conditional), source-store path, not the deployed copy.
- **Scope held to the four named checks** in the mandated order; no severity taxonomy, no
  disclosure/candour language added (per explicit non-goals).
- **No index.json entry drafted here** -- registering a new standards file's lazy-load metadata
  (`domain`, `subdomain`, `keywords`, `topics`, `load_when`) is a mechanical step the
  implementation phase should carry out against whatever generator or manual-edit convention
  currently populates `.claude/context/index.json`'s `standards/*.md` entries (confirmed by
  example at `context/standards/git-workflow-narrative.md`'s own index entry: `domain: "core"`,
  `subdomain: "standards"`, `topics: ["git-workflow"]`); flagged under Context Extension
  Recommendations below rather than decided here, since the generation mechanism itself was not
  fully traced.

## Recommendations

1. Create `context/standards/post-incident-verification-checklist.md` (source store) with:
   - A one-line "when to use" trigger (after any destructive/tree-wide git action on a shared
     tree) and a one-line "why" (verification that stops at sibling commits and own edits misses
     the one category with no other recovery path).
   - The explicit statement that a reverted file matches HEAD and therefore reads clean to
     `git status`/`git diff`, so a clean result is not evidence of no loss -- stated as fact, not
     merely implied by the check list.
   - The four checks in the mandated order, each with concrete commands:
     1. Pre-session uncommitted tracked modifications -- `git stash list`,
        `git diff --stat HEAD stash@{N}`, `git stash show -p -u stash@{N}`, and the
        `git fsck --unreachable --no-reflog | grep commit` fallback for an already-dropped entry.
     2. Untracked files -- `git status --porcelain --ignored=no`, cross-checked against the
        stash's untracked parent (`stash@{N}^3`) when `-u` was used.
     3. Sibling commits -- `git log --oneline <pre-incident-sha>..HEAD` against each sibling's
        reported work.
     4. The agent's own edits -- confirm its declared `file_scope` is fully present.
   - The ordering rationale stated explicitly in the file itself (recoverability, not
     convenience): a sibling commit survives in history regardless; an agent's own edit can be
     redone; pre-session uncommitted work exists in exactly one place and, once reverted, reads
     as clean -- hence first, while there is still time to extract it before the stash entry is
     dropped or garbage-collected.
   - A one-line pointer back to `context/standards/git-workflow-narrative.md`'s incident section
     for full mechanism detail, so the checklist itself stays one page.
2. Insert the guard cross-reference (see Findings) at
   `hooks/guard-destructive-git.sh` lines 614/615, inside the `stash_revert` conditional only.
3. Redeploy after editing the source store (`rules/source-store-deploy-boundary.md`); verify the
   deployed `.claude/hooks/guard-destructive-git.sh` and `.claude/context/standards/` copy both
   reflect the change.
4. Register the new file in whatever currently populates `.claude/context/index.json` (see
   Context Extension Recommendations) so it is lazily discoverable, not just reachable by direct
   path.
5. Keep the new file strictly to one page -- target well under 100 lines; the draft above comes
   in near that bound including commands and rationale, so avoid adding worked examples or a
   prose introduction beyond the "when/why" opening.

## Risks & Mitigations

- **Risk**: the checklist is written but never actually consulted mid-incident because nothing
  outside the guard's own refusal text points at it. **Mitigation**: the guard cross-reference
  (Recommendation 2) is the one channel the task description itself specifies, and it fires at
  exactly the moment a `stash_revert`-class command is blocked or about to run -- the highest-
  leverage single insertion point available.
- **Risk**: a future edit to the guard hook's stash_revert block could drift the cross-reference
  out of the conditional (e.g., accidentally landing in the generic trailer that fires for every
  destructive class). **Mitigation**: name the exact line numbers and the conditional boundary
  explicitly in the plan so the implementing agent inserts inside, not after, the `fi` on line
  615.
- **Risk**: scope creep into a broader incident-response document given how much adjacent
  material exists (git-safety.md's rollback patterns, recovery.md's fix-forward ladder).
  **Mitigation**: the task's own non-goals list is explicit and this report's recommendations
  stay inside it; the one permitted cross-link is a single "see also" pointer to
  git-workflow-narrative.md for mechanism detail, not a merge of content.

## Context Extension Recommendations

- **Topic**: how new `context/standards/*.md` files get registered in `.claude/context/index.json`
  (domain/subdomain/keywords/topics/load_when fields).
- **Gap**: no source-store `index.json` or generator script was found alongside
  `agent-system/extensions/core/context/`; the deployed index appears to be either hand-maintained
  per-deploy or produced by a mechanism not located during this research pass (`deploy-headless.sh`
  and `install-extension.sh` reference `index.json` but were not traced to completion given this
  task's one-page scope).
- **Recommendation**: the implementation phase should locate the actual registration mechanism
  (likely inside `scripts/deploy-headless.sh`) before or while adding the new file, rather than
  assume a manual index.json edit is required; a future context-maintenance task could document
  this mechanism explicitly if it turns out to be non-obvious to the next agent that adds a
  standards file.

## Appendix

- Search queries / commands used: `grep -rn -i "stash\|uncommitted\|reflog"` across the three
  survey candidates; `grep -n "stash_revert\|Refusal\|refusal"` against
  `hooks/guard-destructive-git.sh`; manual git-plumbing reproduction in a disposable `/tmp` scratch
  repository (`git stash push -u -- <paths>`, `git diff --stat HEAD stash@{0}`,
  `git stash show -p -u stash@{0}`, `git stash drop`, `git fsck --unreachable --no-reflog`),
  discarded after use with no effect on this repository.
- References: `agent-system/extensions/core/context/standards/git-workflow-narrative.md:80-142`,
  `agent-system/extensions/core/hooks/guard-destructive-git.sh:436-622`,
  `specs/archive/361_reclassify_bare_git_stash_as_destructive/` (dependency task, archived/
  complete), `specs/decisions/worktree-isolation-removal-reaffirmation.md` (confirmed to exist,
  per the non-goals list).
