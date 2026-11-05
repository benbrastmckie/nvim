# Research Report: Shared-Worktree History-Read Discipline

**Task**: 362 - Teach the non-destructive history-read techniques at the point of use, so an
implementation agent inspecting past file state never reverts a shared working tree
**Started**: 2026-10-17
**Completed**: 2026-10-17
**Effort**: small (one new one-page standards file + one short pointer bullet in each of 14
implementation agent definitions + the agent template)
**Dependencies**: bounded-wait propagation task (dependencies: [356]) -- confirmed complete (see
Findings); close-lint-curated-array-coverage-gaps task (359) -- confirmed complete
**Sources/Inputs**: codebase (`agent-system/extensions/core/context/standards/*.md`,
`agent-system/extensions/*/agents/*.md`, `agent-system/extensions/core/context/templates/agent-template.md`,
`.claude/context/index.json`), `specs/state.json`, `specs/archive/` precedent tasks, git log
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dependency this task declared (bounded-wait propagation to the 14 implementation agent
  definitions) is confirmed **complete** (`git log` shows `task 356: complete implementation`),
  so editing the 14 agent definitions is unblocked, consistent with the Acceptance bullet that
  forbids editing them before that task finishes.
- Of the three carried figures in the dispatch description, one is independently re-confirmed in
  full local detail; the other two cannot be re-derived from this repository at all, because the
  originating incident happened in a separate consumer repository. See Findings for the exact
  split and why that is the honest answer, not a gap in this research pass.
- A near-identical placement question was already asked and answered by an archived precedent
  task (`post-incident-verification-checklist`): it surveyed the same three candidate documents
  for closely analogous short, point-of-use, discoverability-critical content and rejected all
  three in favor of a new one-page file. That reasoning transfers directly here.
- Recommendation: a **new one-page file**, `context/standards/shared-worktree-discipline.md`
  (source store `agent-system/extensions/core/`), rather than amending `git-safety.md` or
  `git-workflow-narrative.md`. Net document count increase: one, as the acceptance criteria
  allow.
- Reachability mechanism: a short MUST-NOT-style bullet plus a path citation, added to each of
  the 14 implementation agent definitions (the ones named in this task's `file_scope`) and to
  `context/templates/agent-template.md`, mirroring the existing "No History Rewrites" MUST NOT
  bullet already present in `general-implementation-agent.md` -- not a literal duplication of
  the full section, and not reliance on an `@`-style Context Reference entry auto-resolving
  inside a dispatched subagent (it does not; see Findings).

## Context & Scope

Researched: (a) re-derivation of the three carried figures in the dispatch description against
local artifacts; (b) survey of `git-safety.md` and `git-workflow-narrative.md` as placement
candidates, per the dispatch's explicit instruction to survey both before deciding; (c) whether
the declared dependency (task 356, bounded-wait propagation) has actually completed, since the
acceptance criteria forbid editing the 14 agent definitions before it does; (d) the actual
structure of the 14 named implementation agent definitions and the agent template, to determine
a concrete, consistent reachability mechanism; (e) the existing decision record on per-dispatch
worktree isolation, to confirm the detached-worktree mention in scope cannot be read as reopening
it. Out of scope per the dispatch: proposing or reopening worktree isolation; touching the guard
hook, `rules/git-workflow.md`, the no-op-spin task's files, or the bounded-wait contract text
itself; authoring the post-incident verification checklist (already a separate, completed task).

## Findings

### Dependency Status: Confirmed Complete

`git log --all --oneline | grep "task 356"` shows a full phase sequence culminating in
`209c49d44 task 356: complete implementation`. Task 356's own file_scope included the 14
implementation agent definitions this task also names in its `file_scope`. Task 356's directory
no longer appears in `specs/state.json`'s `active_projects` (it has been archived/vaulted), which
is expected for a completed task, not evidence of anything unresolved. The dependency edge this
task declared is therefore satisfied: editing the 14 definitions is safe per the Acceptance
bullet "no edit to the fourteen agent definitions occurs before the bounded-wait propagation task
completes."

### Re-Derivation of the Three Carried Figures

**Figure 1 -- "TWO implementation agents independently reached for bare `git stash`" -- fully
corroborated locally.** `agent-system/extensions/core/context/standards/git-workflow-narrative.md`'s
"No Destructive Git on Uncommitted Work -- Bare `git stash` Incident and Full Detail" section
(written by an earlier, already-archived task) documents this incident in complete detail with
matching figures: observed 2026-10-07, a multi-task `/orchestrate` batch of four tasks sharing one
working tree in a separate consumer repository, two independent implementation agents each
running a bare whole-tree `git stash` for the same legitimate purpose (isolating a pre-existing
test failure from their own edit), one stash spanning a ~375-second build whose later `git stash
pop` aborted and applied nothing, and roughly thirty files of pre-session uncommitted work
surviving only inside a 53-file stash entry. No divergence from the dispatch description's count.
A directly descended, now-archived task (`post-incident-verification-checklist`) independently
re-derived the identical figures against the identical source section and also found no
divergence -- two independent re-derivations now agree.

**Figures 2 and 3 -- the detached-worktree planner instance and the `git show
<stash-ref>:path` self-recovery instance -- NOT locally re-derivable.** Exhaustive search of this
repository's `specs/` tree, `.memory/`, and the standards documents that already narrate the
2026-10-07 incident turned up no record of either instance. This is expected, not a gap in this
research pass: `git-workflow-narrative.md`'s own incident section states the batch ran "in a
separate consumer repository" (the dispatch description names it: Logos/Verification) -- that
repository's `specs/` artifacts, where a planner's or implementation agent's own dispatch handoffs
would have recorded these two specific actions, are not present in this filesystem at all. Local
hits for "detached worktree" in this repo's own `specs/` are all a different, generic use (an
agent confirming a pre-existing test failure reproduces at a prior commit, e.g.
`specs/382_guard_foreign_stash_pop/summaries/01_foreign-stash-pop-guard-summary.md:110` and
`specs/archive/199_concurrent_dispatch_isolation_posture/plans/01_isolation-posture-implementation.md:1020`)
-- a real and useful illustration of the same read-only technique, but not evidence of the
specific carried instance. **Disposition**: treat figures 2 and 3 as carried-but-unverifiable-here
rather than confirmed; the SCOPE section's required content (the read-only techniques and the
three forbidden commands) does not depend on confirming them, since it is prescriptive guidance,
not an incident narrative.

### Placement Survey: `git-safety.md` and `git-workflow-narrative.md`, Both Rejected

**`git-safety.md` (700 lines)**. Read in full. It is entirely a *before/during risky-operation*
playbook: safety-commit-then-rollback XML stage templates, commit message standards, a
`.bak`-file migration checklist, and (separately) the consent-gated push/destructive-action grant
design. Its one paragraph closest to this task's topic, "Recovering an Unconsumed Dispatch," is
about undoing a *never-issued* `/orchestrate` dispatch -- a different scenario entirely (no tree
has been touched yet). There is no natural section for "what read-only technique to reach for
when you need to inspect historical file state on a tree other agents are concurrently writing
to." Critically, **none of the 14 implementation agent definitions currently reference
`git-safety.md` at all** (`grep -rl "git-safety" agent-system/extensions/*/agents/*.md` returns
nothing) -- so amending it would not, by itself, improve reachability any more than a new file
would; a pointer bullet into the 14 definitions is required either way.

**`git-workflow-narrative.md` (259 lines)**. Read in full. It already carries the full incident
narrative for the bare-`git-stash` hazard (the source for Figure 1 above) and is explicitly
self-described, at its own top, as a lazily-loaded *reactive elaboration* companion to the eager
`rules/git-workflow.md` core -- read "once an agent is already following the core's rules," never
positioned as something to find fast at the point of deciding which git command to run. Appending
a point-of-use quick-reference section here would bury it inside 250+ lines of unrelated incident
write-ups (the history-rewrite incident, the wrong-identity stash hazard, session-ID lifecycle,
branch strategy) -- the opposite of discoverable.

**Precedent, already decided once.** An archived task, `post-incident-verification-checklist`,
was dispatched to answer an almost identical placement question for almost identical content
(short, must-be-found-fast, point-of-use git-safety guidance for a shared tree) and surveyed the
same three candidates (`git-safety.md`, `git-staging-scope.md`, `git-workflow-narrative.md`),
rejecting all three with reasoning that transfers verbatim to this task, and creating instead a
new one-page file (`context/standards/post-incident-verification-checklist.md`, now deployed and
registered in `.claude/context/index.json`). That file's own convention -- state the four checks
concretely, then end with "a one-line pointer back to `git-workflow-narrative.md`'s incident
section for full mechanism detail" -- is a ready-made template for this task's own new file.

**Decision**: create `context/standards/shared-worktree-discipline.md` (source store
`agent-system/extensions/core/`), not an amendment to either surveyed file. This satisfies the
acceptance bullet "net document count increase is zero or one, with the placement decision
recorded" via the "one" branch, and the placement rejection reasoning above satisfies "the
placement decision recorded."

### Reachability Mechanism: How a Pointer Actually Reaches a Dispatched Subagent

An `@`-style entry inside an implementation agent's own "Context References" list (the
pattern used by every one of the 14 definitions, e.g. `@.claude/context/formats/return-metadata-file.md
- Metadata file schema (always load)`) does **not** auto-resolve its target content into a
dispatched subagent's context the way it would for the harness's own native `@`-mention handling
in an interactively-typed prompt or a project `CLAUDE.md`. This is already an established,
previously-verified fact in this codebase (carried in a sibling task's own description, concerning
the bounded-wait bullet pair this task's dependency propagated): each in-scope agent body must
carry a literal copy of load-bearing rule text for it to be reliably present, because Context
Reference entries are read by the agent *actively choosing to open the path*, not injected
automatically.

For a SHORT (3-4 bullet) piece of prescriptive guidance like this task's SCOPE, the right-sized
mechanism is **not** full literal duplication into all 14 files (that would make "a section, not a
framework" false in spirit, duplicating the same four bullets 14 times) and **not** a bare
Context-Reference list entry either (same non-resolution problem, and nothing in the agent's own
flow tells it *when* to go read that path). The precedent already living in
`general-implementation-agent.md` itself answers this: its Critical Requirements **MUST NOT**
list carries item 10, a short, literal, "at the point of use" bullet about a structurally
analogous git hazard (history rewrites under concurrent writers) ending in a path citation to
`.claude/rules/git-workflow.md`'s full section:

> 10. Run a bare `git commit --amend` or a HEAD-moving `git reset` while any other dispatched
>     writer is live in this repo -- see `.claude/rules/git-workflow.md`'s "No History Rewrites
>     While Another Writer Is Live" section. ...

This is exactly the shape this task's content needs: a short literal MUST-NOT bullet, naming the
three forbidden commands and the read-only alternative in one or two sentences, ending in a path
citation to the new standards file for full detail (the read-only command forms, the scratchpad
guidance, and the explicitly-labelled read-only detached-worktree note). Verified that none of
the 13 extension implementation agents currently carry an equivalent bullet (a `grep` for "No
History Rewrites" across them returns nothing outside `general-implementation-agent.md`), so this
is a genuinely new addition to all 14, not a duplicate of something already there under a
different name.

**Concrete demonstration of the pointer chain** (satisfies the acceptance bullet "that
reachability is demonstrated... not merely asserted"): with the new bullet added,
`agent-system/extensions/core/agents/general-implementation-agent.md`'s own Critical
Requirements MUST NOT list would cite `context/standards/shared-worktree-discipline.md` by path,
exactly as item 10 already cites `.claude/rules/git-workflow.md` by path today -- a direct,
file-to-file citation from an agent definition to the new section, reproducible with `grep -n
"shared-worktree-discipline" agent-system/extensions/core/agents/general-implementation-agent.md`
once applied.

### `agent-template.md` Confirms the Convention

`agent-system/extensions/core/context/templates/agent-template.md` (the canonical structure
`meta-builder-agent` uses when generating new agents) shows every agent body following a fixed
shape: Overview, `## Context References` (an `@`-reference list), `## Execution Flow`, then
(by the pattern observed across all 14 real agent files) a `## Critical Requirements` section
ending in numbered **MUST DO**/**MUST NOT** lists. Adding the new MUST NOT bullet to this
template too (per `file_scope`) ensures every *future* generated implementation agent inherits
the pointer by construction, closing the "discoverability, not capability" gap this task exists
to fix for agents that do not exist yet, not only the current 14.

### Detached Worktree: Confirmed Distinct from the Settled Isolation Question

Read `specs/decisions/worktree-isolation-removal-reaffirmation.md` and the "Non-goals, honored"
line in the archived `measured-co-scheduling-signal and isolation posture` task's own report
(`specs/archive/311_measured_co_scheduling_signal_and_isolation_posture/reports/01_co-scheduling-signal-isolation-posture.md:92`:
"no per-dispatch `git worktree` isolation design is proposed or restored"). Both confirm the
decided question is architectural: whether every *concurrent dispatch* gets its own persistent,
cloned, writable worktree for the whole duration of its work (ruled out on ext4, for structural
per-writer-atomic-rename reasons, with CoW/reflink and overlayfs alternatives also evaluated and
rejected). A single agent creating a **disposable, detached, read-only worktree at a specific
commit**, inspecting a file, and discarding it is a different operation entirely in both
duration (seconds, within one dispatch) and effect (zero writes to the shared tree, since the
inspection happens in the detached worktree's own private checkout) -- it is not an instance of
the architecture that was ruled out. The new file's mention of this technique will carry an
explicit "READ-ONLY INSPECTION TECHNIQUE, not an isolation strategy" label, per the dispatch's
own requirement, so no future reader can mistake it for reopening the settled question.

### Index Registration Convention (for the implementation phase, not decided here)

`.claude/context/index.json` already carries an entry for the sibling precedent file
(`standards/post-incident-verification-checklist.md`, line 6610) with `domain: "core"`,
`subdomain: "standards"`, a `topics` array, and a `load_when.agents` array currently listing only
`general-implementation-agent` (not all 14) -- noted here as the existing convention to follow,
not a defect to fix in this task. The new file should get an analogous entry; whether
`load_when.agents` should list `general-implementation-agent` alone (matching the one existing
precedent) or all 14 implementation agents (matching this task's own broader `file_scope`) is a
genuine open choice the planner should make explicitly, since the precedent and this task's own
scope point in different directions.

## Recommendations

1. Create `agent-system/extensions/core/context/standards/shared-worktree-discipline.md`
   (source store; redeploy afterward) as a short, single-topic, well-under-100-line file
   containing, at minimum:
   - A one-line "when/why": shared trees mean a tree-wide git operation reverts work a sibling
     dispatch or the user has not committed yet, with no reliable per-session recovery.
   - Read history with `git show HEAD:path` or `git show <ref>:path`; read differences with
     `git diff HEAD -- path`.
   - Copy to a scratchpad (per this codebase's scratchpad convention) for any experiment that
     needs a mutable copy of a historical file.
   - NEVER `git stash` (bare or whole-tree), `git checkout -- <path>`, or `git restore <path>`
     on a shared tree -- each reverts the tree out from under concurrent writers.
   - A detached worktree at a specific commit, explicitly labelled a READ-ONLY INSPECTION
     TECHNIQUE (never an isolation strategy), for cases needing to run a command against
     historical state rather than merely read a file's text.
   - One pointer line back to `context/standards/git-workflow-narrative.md`'s incident section
     for the full mechanism/incident detail, mirroring the precedent file's own convention.
2. Add one short literal MUST-NOT-style bullet, citing the new file by path, to each of the 14
   implementation agent definitions named in this task's `file_scope`
   (`general-implementation-agent.md` plus the 13 extension implementation/implementation-hard
   agents) and to `context/templates/agent-template.md`, in each file's existing Critical
   Requirements MUST NOT list (or the nearest analogous section where one exists), mirroring
   `general-implementation-agent.md`'s existing item 10 ("No History Rewrites") in shape and
   length.
3. Do not amend `git-safety.md` or `git-workflow-narrative.md` for this content; record the
   rejection reasoning above in the plan.
4. Register the new file in `.claude/context/index.json` (deployed) following the sibling
   `post-incident-verification-checklist.md` entry's shape; let the planner decide the
   `load_when.agents` scope (one agent vs. all 14) explicitly rather than defaulting silently.
5. Redeploy after editing the source store, per `rules/source-store-deploy-boundary.md`, and
   verify the deployed `.claude/context/standards/` copy and all 14 deployed agent files reflect
   the change.
6. Treat the two unverifiable carried figures (detached-worktree planner instance, `git show
   <stash-ref>:path` self-recovery instance) as illustrative, not as facts requiring citation in
   the new file -- the SCOPE's required content stands on its own prescriptive merits and does
   not need the specific incident narrative to justify it (that narrative already lives in
   `git-workflow-narrative.md` for the one figure that is confirmed).

## Decisions

- **New file, not a section append**: `context/standards/shared-worktree-discipline.md`,
  rejecting both surveyed candidates (`git-safety.md`: wrong shape, a risky-operation
  safety-commit/rollback playbook with no natural home for this content, and currently
  unreferenced by any of the 14 agent definitions anyway; `git-workflow-narrative.md`: right
  topic but wrong audience-timing, a lazily-loaded reactive elaboration never meant to be found
  fast at the point of deciding which git command to run) -- both for the same underlying reason
  an already-archived precedent task reached when it faced the identical placement question for
  closely analogous content.
- **Reachability mechanism**: a short literal MUST-NOT bullet with a path citation in each of the
  14 implementation agent definitions plus the agent template, mirroring
  `general-implementation-agent.md`'s existing "No History Rewrites" bullet -- not an `@`-style
  Context Reference list entry (does not reliably resolve inside a dispatched subagent) and not
  full literal duplication of the whole section into all 14 files (wrong-sized for "a section,
  not a framework").
- **Detached worktree labelling**: explicitly a read-only inspection technique, never an
  isolation strategy -- confirmed distinct in both duration and effect from the architecturally
  settled, reaffirmed-closed per-dispatch worktree isolation question.
- **Carried-figure disposition**: Figure 1 (two-agent bare-stash count) re-confirmed with no
  divergence; Figures 2-3 (detached-worktree planner instance, stash-ref self-recovery instance)
  are carried-but-unverifiable from this repository and should not be cited as confirmed facts in
  the new file's text.

## Risks & Mitigations

- **Risk**: 14 separate file edits for one short bullet is more surface area than the "KEEP IT
  SHORT" instruction might suggest for a single deliverable. **Mitigation**: the bullet is
  identical (or near-identical, modulo each file's own existing MUST NOT numbering) across all
  14 files and the template -- this is propagation of one short pointer, not 14 independently
  authored pieces of guidance, and it is exactly the shape the dispatch's own OVERLAP GUARD
  section anticipated when it chose to depend on task 356 rather than skip the agent-file edits.
- **Risk**: registering the new file's `load_when.agents` scope inconsistently with the sibling
  precedent (`post-incident-verification-checklist.md` lists only one agent) could itself become
  a future discoverability gap of the same shape this task fixes. **Mitigation**: flagged
  explicitly above as a planner-level choice, not defaulted silently.
- **Risk**: a future reader skimming only the new file's detached-worktree bullet, out of
  context, mistakes it for an isolation proposal. **Mitigation**: the dispatch's own requirement
  to label it explicitly "READ-ONLY INSPECTION TECHNIQUE, not an isolation strategy" is carried
  into Recommendation 1 verbatim.

## Context Extension Recommendations

- **Topic**: index.json registration convention for a standards file intended to be reachable
  from *multiple* named agents (as opposed to one).
- **Gap**: the one existing precedent (`post-incident-verification-checklist.md`) registers
  `load_when.agents` with a single agent name even though its own content is implementation-agent-
  general; there is no documented guidance on whether `load_when.agents` should enumerate every
  consuming agent or rely on a narrower "load when this specific agent's own body cites it"
  convention.
- **Recommendation**: not a blocking gap for this task (the planner can make an explicit, stated
  choice either way per Recommendation 4 above), but worth a short note in
  `context/architecture/context-layers.md` or the index.json schema doc the next time that
  schema is touched, so future standards-file registrations do not have to re-derive the
  ambiguity from scratch.

## Appendix

- Searches used: `grep -rln "detached worktree"`, `grep -rln "git show.*stash"` across `specs/`
  and `agent-system/`; `grep -rn "git-safety.md\|context/standards/git-safety"` across all 14
  agent definitions and the template (zero hits); `jq`/`python3 -c` queries against
  `specs/state.json` for tasks 362, 356, 359, and 439; `git log --all --oneline | grep "task
  356"`; direct reads of `git-safety.md` (700 lines), `git-workflow-narrative.md` (259 lines),
  `specs/archive/363_post_incident_uncommitted_state_checklist/reports/01_post-incident-checklist.md`,
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`, and
  `specs/archive/311_measured_co_scheduling_signal_and_isolation_posture/reports/01_co-scheduling-signal-isolation-posture.md`.
- Files inspected for the Context References / Critical Requirements convention:
  `agent-system/extensions/core/agents/general-implementation-agent.md`,
  `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`,
  `agent-system/extensions/cslib/agents/cslib-implementation-agent.md`,
  `agent-system/extensions/web/agents/web-implementation-agent.md`,
  `agent-system/extensions/python/agents/python-implementation-agent.md`,
  `agent-system/extensions/books/agents/books-implementation-agent.md`,
  `agent-system/extensions/core/context/templates/agent-template.md`.
- References: `.claude-extensions.json` (`extensions.core.source_dir`), `.claude/context/index.json`
  (line 6610 entry for `post-incident-verification-checklist.md`).
