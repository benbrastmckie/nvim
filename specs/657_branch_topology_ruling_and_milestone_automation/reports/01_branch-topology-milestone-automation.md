# Research Report: Task #657

**Task**: 657 - Branch-topology ruling, then milestone automation and review gates
**Started**: 2026-11-20T00:00:00Z
**Completed**: 2026-11-20T00:00:00Z
**Effort**: Large (two-element meta task; Element 1 is a fully re-opened design question, Element 2 builds automation on top of it)
**Dependencies**: 654 (completed), 656 (completed); this report recommends adding 553 (`git_commit_scoped_gate_refusal_diagnostic`) as a direct predecessor — see Recommendations
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`, `specs/state.json`, `specs/ROADMAP.md`), decision records (`specs/decisions/*.md`), task descriptions (553, 654, 655, 656), existing scripts read in full
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Element 2 is substantially already built.** Two of its four stated automation points are
  already live, mechanical, and unconditional, delivered by task 656: ROADMAP.md (including every
  milestone's progress and batch-done counts) is wholly re-derived from `specs/state.json` on
  every `/orchestrate` conclusion, and the existing complete-gate batch run
  (`orchestrate-batch-gate.sh`) already fires once per invocation whenever any implement dispatch
  occurred. The only genuinely new piece is the milestone-completion push/review handoff — nothing
  in the system prepares or surfaces that today.
- **Element 1's reopened question has a concrete, evidence-grounded answer that needs neither
  worktree isolation nor per-invocation branch creation.** The central hazard a branch feature at
  ANY granularity (per-task, per-invocation, or per-milestone) runs into under this system's
  concurrency model is not squash-content interleaving (already named in the commit-layer-cluster
  record) but checkout itself: `git checkout`/`git switch` repoints the ONE shared working tree's
  `HEAD` instantly for every concurrent session, corrupting a sibling's in-flight uncommitted work.
  This recurs at every branch granularity that requires checking out a new branch to land work on
  it, and it is a different hazard from, but structurally cousin to, the "per-writer cannot audit
  once and trust" defect that killed worktree isolation.
- **The recommended design avoids the hazard structurally rather than guarding it**: keep ALL
  phase commits on whichever single branch is already checked out (no new branch creation during
  the hot path at all, so GAP 1's "every phase commit lands on whatever branch the operator left
  checked out" becomes a feature, not a bug, once that branch is admission-verified); build each
  milestone's review-ready history as a `refs/heads/milestone/<id>` ref using pure ref plumbing
  (`git commit-tree` + `git update-ref`), which never checks that ref out and therefore never
  touches the shared working tree, index, or any concurrent sibling's state. One squash commit per
  completed task is appended to the milestone ref as that task lands; at milestone completion the
  ref is handed to the user, prepared but unpushed, through the existing `/please` + `/merge`
  consent-gated path.
- This design reproduces none of the three/four measured worktree-isolation defects (no clone, no
  shared inode, no per-writer discipline to audit) and closes the specific "postflight marks a
  task `completed` without having landed its work" hole by making the ref-plumbing step itself the
  thing postflight verifies before transitioning status — the same failure class that stranded 18
  and 10 commits on unmerged worktree branches in the reaffirmation record's live incident.
- The file-scope overlap the dispatch names (`git-commit-scoped.sh`, `orchestrate-cycle-postflight.sh`,
  `git-push-granted.sh`) against `git_commit_scoped_gate_refusal_diagnostic` (553) is real and
  current — confirmed directly in `specs/state.json`, not just asserted by the dispatch — which
  supports adding that dependency edge now, ahead of the implement phase.

## Context & Scope

This is a research dispatch for a two-element meta task. Element 1 re-opens, by explicit user
decision, the branch-topology and landing-strategy question that a prior decision record
(`specs/decisions/commit-layer-cluster-ordering.md`) and task 655's description had treated as
settled (branch-per-invocation, worktree isolation forbidden). The binding evidence requirement —
read `worktree-isolation-removal-verdict.md` and `worktree-isolation-removal-reaffirmation.md`,
identify the specific measured mechanism, and show why any new proposal cannot reproduce it —
applies to any proposal that reinstates worktree-style isolation; this report does not propose
reinstating it, and engages the mechanism explicitly in Recommendations and Risks below so the
record that is ultimately written does not have to re-derive the engagement from scratch.

Element 2 asks for milestone-progress automation, batch-triggered systematic testing, and a
milestone-completion push/review handoff that must route exclusively through the existing
consent-gated push mechanism (`/please`, `please-grant.sh`, `guard-git-push.sh`,
`git-push-granted.sh`) — never minting its own grant, never pushing or opening a PR autonomously.

This is a **research-phase** dispatch. Per the pattern already established by task 654 (the
commit-layer-cluster reconciliation, whose own decision record, dependency edges, and task
revisions were produced across its PLAN and IMPLEMENT phases, not its research phase), this report
does not itself write `specs/decisions/*.md`, does not run
`update-task-status.sh --depends-on-add`, and does not revise task 655's or 553's description. It
hands the plan phase a grounded recommendation to turn into the actual ruling.

## Findings

### Codebase Patterns

**Branch awareness, measured.** Confirmed directly (not merely cited from the dispatch):
`grep -rn "git checkout -b\|git switch -c" agent-system/extensions/core/scripts
agent-system/extensions/core/hooks` returns exactly one hit, `git-snapshot.sh:493`, inside its
`--branch` rollback path. No orchestration script reads, asserts, or creates a branch.
`context/standards/git-workflow-narrative.md`'s `## Branch Strategy` section is eleven lines of
unenforced prose (`main` or feature branches; an optional `task-{N}-{slug}` convention).

**The commit-layer-cluster-ordering record already names the decisive concurrency hazard, as an
input, not yet as a ruling.** Its "Inputs to the branch feature" section states: "(b) Landing a
squash by switching the single shared working tree carries concurrent siblings' uncommitted edits
across the switch. Concurrent writers are the normal condition." This report's own
analysis (below, Recommendations) generalizes that single bullet into the controlling design
constraint for Element 1: it is not specific to the *landing* step, it applies to *any* checkout
of a non-currently-checked-out branch while a sibling session is live in the same tree, which is
why branch-per-invocation (655's prior "settled" design, requiring a fresh checkout at admission
time) carries the same class of risk as branch-per-task would, just less frequently triggered.

**Milestone schema and ROADMAP regeneration (task 656), read directly from the live store and the
generator, not just the summary:**
- `specs/state.json` top-level `roadmap_milestones[]`: each entry has `id`, `title`, `aim`,
  `status` (here `null` at the array-wrapper level — the live per-milestone object actually
  carries `progress: {status: "active"}` and `review: {state: "none"}`, both hand/judgment fields,
  never auto-computed), and `batches[]`. Each batch has `task_ids`, `description`, `rationale`,
  `flags` — no stored "done" flag.
- `roadmap-integration.sh` (confirmed by reading its render logic, lines ~222-333) computes
  **everything quantitative from scratch on every render**: a batch is done when every one of its
  `task_ids` is terminal in `active_projects` (`TERMINAL_JQ=["completed","abandoned","expanded"]`)
  or absent from `active_projects` (i.e. archived); a milestone's `b_done`/`b` and `t_done`/`t`
  counts are derived the same way. The rendered `specs/ROADMAP.md` confirms this live: `M1`'s
  dashboard reads "1/30 batches, 7/127 tasks done" and "Batch 1 (done)" with no corresponding
  stored field anywhere in `state.json` — it is all re-derived at render time.
- `orchestrate-conclusion-roadmap.sh` is called **unconditionally** from Move 4 of every
  `/orchestrate` invocation, regardless of outcome (`all_terminal`, `no_eligible_stuck`,
  `max_cycles`, every `partial`) — confirmed by reading the script's header and body. On a
  `generated`-classified roadmap it runs `roadmap-integration.sh --regenerate` and commits the
  result through `git-commit-scoped.sh`. **This already is** "an orchestration completing ...
  regenerates ROADMAP.md," for every `/orchestrate` invocation, single-task or multi-task alike.
  The only field Element 2's first bullet could still mean beyond this is the *judgment* `progress`
  field (`active`/paused/etc.) — which 656's own agent file (`roadmap-agent.md`) deliberately
  reserves for explicit `/roadmap` judgment, not mechanical update, mirroring how `review` is
  handled (see next point).
- `orchestrate-batch-gate.sh` already runs the **complete verify-deploy.sh gate set exactly once
  per invocation**, triggered whenever `.implement_agents` is non-empty for that invocation (read
  from the multi-task state file) — confirmed from its header comment. A roadmap "Batch" entry's
  own rendered form in `specs/ROADMAP.md` *is* the literal suggested `/orchestrate <task_ids>`
  invocation (e.g. "Batch 4 ... `/orchestrate 645, 560, 629, 630, 631, 632`"), so when that
  suggested command is actually run, `orchestrate-batch-gate.sh` already fires the systematic test
  pass for it. The one gap against the literal Element 2 wording ("all completing") is that the
  trigger is "any implement dispatch happened," not "every member of this batch reached a terminal
  status" — a strictly broader, already-safer trigger, not a missing one.
- 656's own Follow-ups record two relevant, currently-undecided gaps: (1) "Nothing writes `review`
  except a `/roadmap` judgment pass on explicit instruction... Whether a workflow step should
  record it is undecided" — directly Element 2's review-gate question; (2) "a task joins a
  milestone only through a batch... held or externally owned work cannot be shown under its
  milestone" — a pre-existing design gap this task inherits but does not need to solve to satisfy
  its own DONE WHEN criteria.

**The consent-gated push mechanism (`consent_gated_git_push`, archived), read in full:**
- `hooks/please-grant.sh` is a `UserPromptSubmit` hook that mints a grant **only** from the raw
  text of a literal human-typed prompt beginning `/please`, `/merge`, `/tag`, or `/pr`. It is
  verified (per its own header, Phase 1 evidence) that a dispatched subagent's prompt never
  triggers this hook, and an inter-agent `SendMessage` relay arrives wrapped in
  `<agent-message from="...">` tags that never match the anchored prefix check. No agent, by any
  wording or wrapper, can cause a grant to be minted.
- The grant is single-use, HMAC-signed, bound to `(action_class, remote, ref, force, head_sha)`,
  and expires after `PG_EXPIRY_WINDOW` seconds. `guard-git-push.sh` (PreToolUse on `Bash`) blocks
  every un-granted `git push` and unconditionally blocks any `Write`/`Edit`/`Bash` that targets the
  grant store or key path — there is no write channel into the grant store at all, for any agent.
  `git-push-granted.sh --remote <r> --ref <ref> [--force-with-lease]` is the only sanctioned
  consumer; it fails closed on any mismatch and is itself gated the same way `/please` is.
- `/please` (commands/please.md) and `/merge` (commands/merge.md) are both explicitly
  **user-only**; they appear in no skill-to-agent mapping and cannot be invoked by any agent.
  `/merge`'s own push step (`git push -u origin HEAD`) is gated by the identical
  `guard-git-push.sh` hook — its grant was minted at the moment the user typed `/merge`, by the
  same `please-grant.sh` hook, confirming `/please` and `/merge` already share one mint/consume
  pipeline rather than two parallel ones.
- **No existing script "prepares" a push or drafts a PR body without pushing.** This is the one
  piece of Element 2 that is genuinely unbuilt; everything downstream of "prepare" already exists.
- `pg_is_default_branch`/`pg_default_branch` in `push-grant-lib.sh` confirm only a **force** push
  to the default branch is categorically excluded from every grant — an ordinary, non-force push
  (e.g. of a prepared milestone side-branch, or even directly fast-forwarding `main` if a repo ever
  wanted that) is grantable through the normal `/please` flow.
- Resolved source-store paths (via `.claude-extensions.json`'s `.extensions.core.source_dir`):
  `agent-system/extensions/core/hooks/{please-grant.sh,guard-git-push.sh}` and
  `agent-system/extensions/core/scripts/git-push-granted.sh`. All edits for any new milestone
  push/review wiring belong there, never under the deployed `.claude/**` tree, per
  `rules/source-store-deploy-boundary.md`.

**No existing per-repo declaration site for an "integration branch."**
`context/standards/repo-level-declarations.md` documents `trigger_glob`/`generated_paths` and
`closing_gate` declarations, but no `integration_branch` (or equivalent) key exists today. The
commit-layer-cluster-ordering record's own "Inputs to the branch feature" item 5 already points at
`.claude-extensions.json` top-level keys as "the existing home" for such a declaration — this
report confirms that no such key is populated yet, so Element 1's design (whatever topology it
settles on) still needs to add one if it wants to resolve the work branch from configuration
rather than literally trusting whatever is checked out.

**Task 655's current description** (read in full) still carries the "BINDING CONSTRAINT, NOT
RE-OPENABLE" block and the branch-per-invocation "settled design" — both of which its own trailing
paragraph already defers to this task's ruling ("THE BINDING CONSTRAINT BLOCK ABOVE IS SUBJECT TO
A LATER RULING -- READ THAT RULING FIRST... wherever it differs... the ruling wins and this
description is stale at that point"). 655 already depends on 657 in `state.json`
(`dependencies: [513, 553, 654, 657]`), so the revision channel from this task's ruling into 655's
description is already wired; only the ruling's content, and the write of the revision itself, is
outstanding.

**A rendering/data discrepancy, flagged but not resolved.** `specs/ROADMAP.md`'s live Batch 2
preview (under M1) currently prints `657 blocked:553`, naming a dependency 657 does not yet have:
`jq '.active_projects[]|select(.project_number==657)|.dependencies'` against `specs/state.json`
returns `[654, 656]` only, both in the live working tree and at `HEAD` — no entry for 553.
`roadmap-integration.sh`'s own `status_token()` function (read directly) derives a `blocked:N`
token purely from the live `.dependencies[]` array intersected with the active-task set, so this
printed text cannot be a current render of that function against today's data; it is either a
stale snapshot from an earlier render this research did not trace to its commit, or produced by a
different code path. Recorded here rather than chased further — it does not change the
recommendation below (add the edge) and its cause is orthogonal to this task's own ruling — but
the plan/implement phase should re-check `specs/ROADMAP.md` after writing the 553 edge to confirm
it then renders consistently with `state.json`.

**File-scope overlap with 553, confirmed, not merely asserted.** `specs/state.json`'s
`active_projects[657].file_scope` already lists `git-commit-scoped.sh`,
`orchestrate-cycle-postflight.sh`, and `git-push-granted.sh`; `active_projects[553].file_scope` is
`[git-commit-scoped.sh, tests/test-git-commit-scoped.sh]`. The overlap on `git-commit-scoped.sh` is
real under the commit-layer-cluster record's own overlap predicate ("a declared `file_scope` entry
of one equals... an entry of the other"). That record's stated reason for keeping 657 off the
chain — "657's declared scope on the two shared scripts is read-and-rule" — no longer matches
657's actual declared scope, which now includes `git-push-granted.sh` and both scripts for Element
2's automation, not only a read for Element 1's ruling.

### External Resources

This is primarily an internal-system design task, but the dispatch poses the squash-granularity
question directly ("the best git workflow ... using side branches and squash merging as
appropriate, to produce the highest-quality history"), which was checked against current external
guidance rather than decided from internal reasoning alone. Industry convention converges on:
squash merges suit short-lived branches, collapsing one topic's work into a single trunk commit;
a long-lived branch should instead keep its merge commits, or be hand-tidied before merging,
because squashing it away loses exactly the commit-level granularity later debugging and
reverting need (GitLab's own squash-and-merge docs advise against squashing a long-lived branch
for this reason; a GitHub engineering post on commit squashing makes the same short-lived-branch
qualification). This corroborates, rather than drives, the recommendation below: the per-task
squash onto the milestone ref (Recommendation item 2) is the short-lived-unit squash this
convention endorses, while whether the milestone ref itself is squashed again when it finally
merges to the integration branch is left as the human reviewer's call at PR time (Recommendation
item 6) — consistent with `pr-prohibition.md`'s human-controlled-merge principle, and now also
with this external convention rather than against it.

The one piece of general git knowledge load-bearing for the recommendation below — that a commit
can be created on, and a ref updated to point at, a branch that is **not currently checked out**,
via `git commit-tree <tree> -p <parent> -m <msg>` followed by
`git update-ref refs/heads/<name> <new-sha>`, entirely without touching the working tree or the
index — is standard git plumbing (the same technique used by, e.g., headless `gh-pages` deploy
scripts) rather than anything specific to a library or tutorial, so no citation beyond "git
plumbing commands" applies.

## Recommendations

**Element 1 — branch topology and landing strategy.**

1. **Keep the work branch exactly as it is today: whatever single branch is already checked out.**
   Do not create a new branch per invocation, per task, or per milestone for the *hot path* (the
   phase commits a dispatch makes while actively doing work). This eliminates GAP 1's "every phase
   commit lands on whatever branch the operator left checked out" as a defect — it becomes the
   explicit design, verified (not merely assumed) by an admission-time check that the checked-out
   branch matches a configured integration-branch declaration (a new key under
   `.claude-extensions.json`, falling back to the current branch with a loud advisory when
   undeclared — reusing 655's own Element A design, which survives this ruling unchanged). This
   also sidesteps the deeper hazard named below entirely: if no new branch is ever checked out
   during normal dispatch work, the shared-tree-checkout race against concurrent siblings never
   arises for the common case.
2. **Build each milestone's review-ready history as a dedicated ref, using ref plumbing, never a
   checkout.** For a milestone with `state.json` id `M1`, maintain `refs/heads/milestone/M1`
   (or an equivalent, data-driven, non-literal name resolved from `roadmap_milestones[].id`, per
   655's repo-agnostic constraint). At that task's `[IMPLEMENTING] -> [COMPLETED]` transition in
   `orchestrate-cycle-postflight.sh`:
   - `tree=$(git rev-parse HEAD^{tree})` (the task's cumulative state is already correct in the
     tree, because phase commits already happened on the live branch);
   - `parent=$(git rev-parse refs/heads/milestone/<id> 2>/dev/null || git rev-parse
     <integration-branch>)` (first task in the milestone forks from the integration branch's tip;
     every later task's squash commit chains onto the previous one);
   - `new=$(git commit-tree "$tree" -p "$parent" -m "task {N}: {title}" <<<"{phase list body}")`;
   - `git update-ref refs/heads/milestone/<id> "$new"`.
   None of these four commands touches the working tree, the index, or `HEAD`. A concurrent
   sibling session doing unrelated work in the same tree is completely unaffected — there is no
   window in which its uncommitted edits could be attributed to the wrong branch, because `HEAD`
   never moves. Serialize the `update-ref` itself under the existing task-lock to avoid a lost
   update if two tasks in the same milestone land in the same instant (a narrow race, not a
   structural one).
3. **Milestone completion triggers a prepare-and-handoff step, never a push.** When a conclusion-
   stage pass (sibling to `orchestrate-conclusion-roadmap.sh`, same Move 4 call site, same
   file-scope) observes that a milestone's `roadmap-integration.sh`-computed `b_done == b` just
   became true this invocation (i.e. it was not true before this invocation's postflight actions
   and is true after), it:
   - confirms `refs/heads/milestone/<id>` exists and its commit count matches the milestone's
     `t_done` task count (a sanity check, not a new source of truth);
   - computes the diff/range against the integration branch's current tip for display;
   - drafts a PR-shaped summary (one bullet per task's squash-commit subject/body) as plain output
     (and/or an artifact under the milestone's own `specs/` tree — not a task directory, since a
     milestone outlives any one task) — never writes it to the grant store, never touches
     `hooks/please-grant.sh` or its key path (`guard-git-push.sh`'s tamper guard blocks that
     unconditionally regardless of intent);
   - surfaces, in the conclusion output, the **exact literal commands** for the user to type:
     `/please push refs/heads/milestone/<id> to origin` (or the equivalent remote-branch form),
     then `/merge --target <integration-branch>` — never invoking either itself, consistent with
     `/please`'s and `/merge`'s own "Agents MUST NOT invoke this command" restriction and with
     `pr-prohibition.md`.
   This is "preparation plus a handoff," exactly as the dispatch requires, built entirely from
   primitives that already exist (`/please`, `/merge`, `git-push-granted.sh`) plus one new,
   narrowly-scoped read-and-report script.
4. **Merge strategy: squash per task, via plumbing, not `git merge --squash`.** 655's Element D
   already settled on squash-per-task; this recommendation keeps that decision but changes the
   *mechanism* from a working-tree `git merge --squash` (which requires checking out the target
   branch) to the ref-plumbing form above (which does not). `git rebase -i` remains unavailable in
   this environment and is not needed either way.
5. **Worktree isolation: not reinstated — and the binding-evidence engagement, explicit.** The
   verdict and reaffirmation records name four measured defects, all rooted in one structural
   cause: a *clone* (hardlink or otherwise) of mutable state, whose correctness depends on every
   writer that touches it discovering and respecting an unaudited exclusion list ("per-writer
   atomic-rename," the repo-scan tree-walk pollution class, and the postflight-non-landing
   incident where two worktree branches were never merged yet their tasks were marked
   `completed`). This design creates **no clone of anything** — the milestone ref is built from
   the already-correct tree of the existing, single working copy's `HEAD`, via a new commit object,
   never a filesystem copy — so there is no shared inode, no exclusion list, and nothing for an
   unrelated script to forget about. The fourth defect (postflight marking a task `completed`
   without having actually landed its committed work) is the one this design must guard against
   explicitly, not by assumption: `orchestrate-cycle-postflight.sh`'s `[COMPLETED]` transition must
   verify `git merge-base --is-ancestor <task's last phase commit> refs/heads/milestone/<id>`
   (or equivalently, that the new `update-ref` call actually succeeded) **before**, not after,
   writing `completed` to `state.json` — closing exactly the hole that let two worktree branches'
   work go unlanded under a `completed` status in the reaffirmation record's live incident. This
   re-reaches the removal verdict's own conclusion (no isolation layer) while directly answering
   "why can't this design reproduce the measured mechanism" with a structural reason (no clone, no
   checkout) rather than an assertion of better design.
6. **What remains genuinely open for the plan/implement phase to decide**, rather than this
   report prejudging: the exact `.claude-extensions.json` key name and shape for the integration-
   branch declaration; whether the milestone ref additionally needs periodic rebasing onto a moved
   integration-branch tip while the milestone is still open (recommend: no automatic rebase — treat
   a moved base the same way an ordinary long-lived feature branch treats it, as the human
   reviewer's call at PR time, consistent with `pr-prohibition.md`'s human-controlled-merge
   principle); and the precise commit-message/body convention for the milestone-ref's squash
   commits (recommend reusing the `task {N}: {title}` subject convention already in
   `rules/git-workflow.md`, with the phase list in the body, exactly as 655's Element D already
   specifies).

**Element 2 — automation and review gates.**

1. **Milestone progress + ROADMAP regeneration: no new mechanism needed.** Confirm
   `orchestrate-conclusion-roadmap.sh`'s existing unconditional call already satisfies this bullet
   for every `/orchestrate` invocation; the plan phase should state this explicitly rather than
   building a parallel path. The only decision left is whether the milestone's judgment `progress`
   field (`active`/held/etc., distinct from the auto-derived counts) should ever be mechanically
   advanced (e.g. to a `done` status the moment `b_done == b`) — recommend yes, narrowly: have the
   new milestone-completion step from Element 1's recommendation 3 above also flip
   `roadmap_milestones[].progress.status` to a value meaning "awaiting review/push" once the
   handoff is prepared, so the dashboard reflects the new state without waiting for a `/roadmap`
   pass — while leaving `review.state` exactly as 656 left it (written only by `/roadmap` judgment),
   per that task's own Follow-ups note that this is still undecided and not blocking.
2. **Batch-completion-triggered systematic testing: reuse `orchestrate-batch-gate.sh` as-is, or
   narrow its trigger — plan-phase decision, not a research-phase ruling.** The existing
   "any implement dispatch happened" trigger is a safe superset of "every batch member completed";
   recommend keeping it rather than adding a narrower, batch-membership-aware trigger, since the
   narrower form would require a new read of `roadmap_milestones[].batches[]` at a call site that
   does not use the milestone schema at all today, for a strictly weaker (less frequently testing)
   outcome.
3. **Milestone-completion push/review handoff: build as scoped above (Element 1, recommendation
   3).** This is the one piece of Element 2 with no existing mechanism to reuse beyond the
   `/please`/`/merge` consent primitives themselves.
4. **`git-workflow-narrative.md`'s Branch Strategy section**: replace its eleven aspirational lines
   with the mechanically-backed contract above once ruled — the single long-lived checked-out
   branch for phase commits, the per-milestone ref for review, and the `/please`+`/merge` handoff —
   so the written standard and the enforced behavior agree, per this task's own DONE WHEN
   criterion.
5. **Dependency edge**: add `657 depends on 553` (`git_commit_scoped_gate_refusal_diagnostic`) via
   `update-task-status.sh --depends-on-add` at plan/implement time. The file-scope overlap on
   `git-commit-scoped.sh` is confirmed above, and 553's diagnostic-message fix is cheapest on
   settled structure (per its own stated principle, echoed in the commit-layer-cluster-ordering
   record) — landing 657's automation on top of 553's corrected verdict message, rather than the
   reverse, avoids 657 having to re-derive or duplicate 553's fix.

## Decisions

- This report does not write `specs/decisions/*.md`, does not run
  `update-task-status.sh --depends-on-add`, and does not revise task 655's or 553's description —
  those are plan/implement-phase deliverables for this task, consistent with how task 654 (the
  precedent this task's own dispatch cites) sequenced its research, plan, and multi-phase
  implementation.
- The binding evidence requirement is treated as satisfied for the purpose of this report's own
  recommendation (no worktree reinstatement proposed), and the specific engagement required by
  that constraint — reading both records, naming the measured mechanism, showing why the proposed
  design cannot reproduce it — is written out in Recommendations, item 5, for the eventual
  decision record to cite or extend rather than re-derive.

## Risks & Mitigations

- **Risk**: the per-milestone ref-plumbing approach is unfamiliar relative to ordinary
  checkout-and-merge workflows, raising implementation risk (a wrong `commit-tree` invocation
  could silently create a commit with the wrong parent or tree). **Mitigation**: the plan phase
  should require a test that asserts the milestone ref's commit count, parent chain, and tree
  equality against the live branch's state after each simulated task landing, mirroring the
  rigor `test-git-commit-scoped.sh`-class suites already apply to this codebase's other commit
  primitives.
- **Risk**: concurrent tasks within the *same* milestone landing at nearly the same instant could
  race on `git update-ref refs/heads/milestone/<id>` (a classic compare-and-swap hazard: both read
  the same old tip, both compute a new commit from it, the second `update-ref` either fails or
  silently drops the first's work depending on flags used). **Mitigation**: use
  `git update-ref refs/heads/milestone/<id> <new> <old>` (the three-argument form, which fails if
  the ref has moved since `<old>` was read) and serialize retry through the existing task-lock
  mechanism rather than inventing a new lock.
- **Risk**: a milestone ref could grow stale relative to a fast-moving integration branch across a
  long milestone, producing a noisy PR diff at review time. **Mitigation**: explicitly left as the
  human reviewer's call (see Recommendations item 6) rather than automated, consistent with
  `pr-prohibition.md`.
- **Risk**: re-reading this report's recommendation as "ruled" rather than "recommended" could
  cause the plan phase to skip engaging the binding-evidence requirement on its own terms.
  **Mitigation**: this report explicitly flags (Decisions, above) that the actual ruling and its
  binding-evidence engagement still belong to the decision record the plan/implement phases write.

## Context Extension Recommendations

- **Topic**: ref-plumbing-based branch landing (no checkout). **Gap**: no existing context file
  documents this technique; `git-workflow-narrative.md` and `git-staging-scope.md` both assume
  commits land via ordinary checkout-and-commit. **Recommendation**: once Element 1's ruling is
  written, add a short pattern document (e.g.
  `context/patterns/ref-plumbing-landing.md`) describing the `commit-tree`/`update-ref` idiom and
  its concurrency-safety property, so a future script touching branch landing does not reach for
  `git checkout` by default.
- **Topic**: integration-branch declaration. **Gap**: `repo-level-declarations.md` documents
  `trigger_glob`/`generated_paths`/`closing_gate` but no `integration_branch` key.
  **Recommendation**: once Element 1's plan phase fixes the key's name and shape, add it to that
  same standard rather than inventing a parallel declaration surface.

## Appendix

- Search queries used: `grep -rn "git checkout -b\|git switch -c" scripts/ hooks/`,
  `jq -r '.active_projects[]|select(.project_number==N)|...'` against `specs/state.json` for
  tasks 553/654/655/656/657, `jq` queries against `roadmap_milestones` for schema and live values.
- Files read in full: `specs/decisions/worktree-isolation-removal-verdict.md`,
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`,
  `specs/decisions/commit-layer-cluster-ordering.md`,
  `agent-system/extensions/core/hooks/please-grant.sh`,
  `agent-system/extensions/core/hooks/guard-git-push.sh`,
  `agent-system/extensions/core/scripts/git-push-granted.sh`,
  `agent-system/extensions/core/commands/please.md`,
  `agent-system/extensions/core/commands/merge.md`,
  `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh`,
  `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` (header),
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` (partial),
  `agent-system/extensions/core/context/standards/git-integration.md`,
  `specs/656_milestone_schema_and_generated_roadmap/summaries/01_milestone-schema-generated-roadmap-summary.md`,
  task 655's and 553's full `state.json` descriptions.
- References: `specs/decisions/worktree-isolation-removal-verdict.md`,
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`,
  `specs/decisions/commit-layer-cluster-ordering.md`,
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`,
  `agent-system/extensions/core/context/standards/repo-level-declarations.md`.
- External search queries and sources (squash-granularity corroboration, External Resources
  above): "trunk-based development feature branch squash merge milestone review gate CI best
  practices", "long-lived feature branch side branches squash merge strategy clean history" —
  [GitLab: Squash and merge](https://archives.docs.gitlab.com/17.2/ee/user/project/merge_requests/squash_and_merge.html),
  [GitHub: Squash your commits](https://github.blog/open-source/git/squash-your-commits/),
  [Graphite: What is Git Merge Squash?](https://graphite.dev/guides/git-merge-squash).
