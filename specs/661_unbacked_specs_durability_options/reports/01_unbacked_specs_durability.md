# Research Report: Unbacked Specs Durability Options

**Task**: Unbacked specs durability options
**Started**: 2026-11-19T23:21:00Z
**Completed**: 2026-11-19T23:25:16Z
**Effort**: research-only, no implementation
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/**, specs/TODO.md), no web search needed
**Artifacts**: - specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Recommend **Option D: document the exposure and build nothing**. Every mechanism that
  recovers an ignored `specs/` tree does so by giving it a second place to live, and a second
  place to live is itself a branch, a remote, or a sync target that someone must create, grant
  access to, and keep alive — which is exactly the cross-branch/cross-repo churn the group
  ignored `specs/` to remove in the first place.
- The strongest *mechanism* candidate (periodic orphan-branch archive commit, in the same repo)
  still fails the disqualifying criterion: an orphan branch is a ref that participates in `git
  fetch --all`, `git branch -a`, CI branch-protection sweeps, and any tool that iterates
  branches, so every one of those surfaces now has to learn to skip it. That is the same shape
  of churn the sibling task group is actively removing from the *tracked* posture, reintroduced
  through a side door.
- A sibling-repository mirror and an external sync tool both recover the bytes but not the
  property that made `specs/` worth gitignoring (no cross-branch noise, no second thing to
  configure) — and both add a thing someone has to remember to keep running, with silent,
  undetectable failure modes (a stopped daemon, a stale clone) that are worse than the admitted
  exposure of doing nothing.
- A durability statement for the docs task is drafted below, under "Recommendation for
  Placement".

## Context & Scope

This task is part of a six-task group (658, 660, 661, 662, 663 visible in `specs/TODO.md`, plus
a sixth docs-reframe task) that makes an ignored `specs/` tree the supported default posture for
a freshly initialized repository, alongside the existing tracked posture (which stays fully
supported and is what this repository itself uses — 11,572 tracked files per task 660's own
measurement). The task that prompted the group found a consumer repository with 604 `specs/`
files on disk and zero git history behind them, because its root `.gitignore` now excludes
`specs/`.

This task's scope is narrow by its own description: recommend one durability option, state why
the others lose, and draft a short statement for a sibling documentation task to place. It
explicitly excludes designing an implementation, writing a script, or adding a hook. No file is
written outside this task's own `specs/` artifact directory.

I did not find any existing mechanism in this codebase that backs up an ignored `specs/` tree.
The closest analogues already in the codebase are: (1) `settings_backup.lua`, which snapshots
`settings.json`/`settings.local.json` to a gitignored sibling directory before a full `.claude/`
wipe — a *local, same-filesystem, short-lived* copy, not a durability mechanism against disk
loss; and (2) the Literature extension's `~/Projects/Literature/` global repository, which is a
genuine sibling-repository pattern, but for a fundamentally different kind of content (curated
reference material added deliberately and rarely) rather than one that fires on every task-state
mutation. Neither analogue transfers cleanly to `specs/`'s write pattern: multiple small
mutations per dispatch, across every phase of every task, for as long as the repository is
worked on.

## Findings

### Codebase Patterns

- `specs/` is tracked by default today (`.gitignore` in this repository does not exclude it);
  the sibling task group is adding the *option* to ignore it from `/init`'s scaffolding onward
  (task 660) and teaching the commit path to recognize an all-ignored pathspec as a non-failure
  outcome (task 658) — this task assumes that future state, not the status quo in this
  repository.
- `.claude/` itself is already a fully disposable, regenerate-from-source-store artifact (see
  `.gitignore`'s header comment and `rules/source-store-deploy-boundary.md`) — the project
  already has exactly one tree it treats as "fine to lose, regenerate on demand." `specs/` under
  the new ignored posture would be the *second* such tree, except it cannot be regenerated: it is
  the record of work done, not a build output.
- `context/standards/orchestrator-runtime-files.md` already draws the relevant distinction for a
  different file class: "ephemeral, no freshness check, a stale restore would corrupt state" vs.
  "durable provenance, tracked, a stale restore is caught by a freshness gate." `specs/`'s task
  artifacts (reports, plans, summaries, state.json, TODO.md) are durable provenance in that
  taxonomy's sense — they are exactly the class that standard says costs nothing to track "beyond
  history noise." Under the ignored posture, that durable-provenance class loses its git history
  entirely, which is the exposure this task is about.
- No existing script, hook, or cron job in `agent-system/extensions/core/scripts/` performs a
  periodic commit, snapshot, or external copy of `specs/` content. `git-snapshot.sh` exists but
  is a pre-rollback working-tree safety net (stash + branch/no-revert modes keyed to one git
  operation), not a durability mechanism against disk/filesystem loss.

### External Resources

Not consulted — the question is a design trade-off resolvable from the codebase's own stated
constraints (the disqualifying criterion in the task description, and the existing two-posture
contract from sibling tasks), not from external sync-tool documentation. No part of the
recommendation depends on a specific tool's feature set.

## Recommendations

Evaluated against the task description's four named options, scored on: setup cost, per-task
cost, what it recovers, what it silently fails to recover, and whether it reintroduces
cross-branch/cross-repo churn (the disqualifying criterion, applied first below).

### Option A — Sibling repository holding only specs trees

- **Setup cost**: create and host a second repository (or bare remote) per consumer repo; wire a
  push/pull path from the working repo to it; decide on a branching scheme inside it (one branch
  per consumer repo? one repo per consumer?).
- **Per-task cost**: either a commit+push on every lifecycle mutation (frequent — several times
  per dispatch) or a batched push on a cadence, trading freshness for frequency.
- **Recovers**: full git history of every tracked file in the sibling, if the push cadence kept
  up with disk loss.
- **Silently fails to recover**: anything written after the last successful push — and push
  failures (auth expiry, network outage, remote deleted) are exactly the kind of thing that goes
  unnoticed for weeks, the same failure mode task 663 documents for a mis-rooted ledger file.
- **Disqualifying criterion**: **fails.** This is cross-*repository* churn, a strictly heavier
  version of the cross-*branch* churn the group is removing. It requires a remote to exist, be
  reachable, and be kept in sync, and it reintroduces exactly the "second place that must be
  configured and kept alive" cost class that made `specs/` worth ignoring from `/init` onward in
  the first place (task 660's own rationale: "task state stays local to the working copy").

### Option B — Periodic archive commit onto an orphan branch, same repository

- **Setup cost**: a script to create the orphan branch, a commit routine that snapshots
  `specs/` onto it without touching the working branch, and a scheduling mechanism (cron, a
  skill hook, or a manual command).
- **Per-task cost**: one commit per snapshot cadence (not per task-mutation, if batched) — cheap
  per operation, but someone has to decide and maintain the cadence.
- **Recovers**: everything present in `specs/` at the time of the last snapshot commit.
- **Silently fails to recover**: anything written since the last snapshot, and — more subtly —
  anything the orphan branch's checkout step didn't capture correctly (a stale `.gitignore`
  interaction, a race with an in-flight dispatch writing mid-snapshot).
- **Disqualifying criterion**: **fails**, on the specific point the task description calls out
  as the deciding criterion. An orphan branch is still a *branch*: it shows up in `git branch
  -a`, participates in `git fetch`/`git push --all`, has to be excluded from every branch-sweep
  tool (CI matrix triggers, stale-branch cleanup scripts, `gh pr list --base`), and needs its own
  documentation so a future contributor doesn't try to merge it or delete it as stale. That is
  precisely the cross-branch churn category task 662's description names when it says the
  tracked posture caused `specs/` churn to "appear in a pull request" — an orphan branch doesn't
  appear in a PR, but it does appear in every other branch-enumerating surface, which is the same
  complaint in a different location.

### Option C — External file-sync or snapshot mechanism the host already runs

- **Setup cost**: nominally zero if the host (e.g., a home-directory backup tool, a filesystem
  snapshot schedule, a cloud-sync client) already covers the repository's working directory —
  but "already covers" has to be verified per host, and the task description itself frames this
  as conditional ("the host already runs"), not guaranteed.
- **Per-task cost**: zero — it is passive.
- **Recovers**: whatever the external tool's own retention window holds, at whatever granularity
  it snapshots (often whole-filesystem or whole-home-directory, not git-aware).
- **Silently fails to recover**: anything written between snapshot intervals; anything if the
  host-level tool was never actually configured, was silently disabled, or doesn't cover this
  particular path (a `.gitignore`-ignored directory is sometimes *also* excluded from naive
  backup tools that key off version-control ignore rules); and, critically, there is no
  git-native way for this project to verify the mechanism is actually running — it is wholly
  outside the repository's and the agent system's visibility.
- **Disqualifying criterion**: does not reintroduce cross-branch/cross-repo churn — it is the one
  option that doesn't touch git at all. But it fails on a different, equally fatal ground: it is
  not a decision this task or this codebase can make or verify. "The host already runs it" is
  either true (nothing to recommend — there's no action) or false (nothing this task can cause
  to become true, since it is explicitly out of scope to design or adopt a mechanism). It is not
  a candidate the agent system can "recommend" in the actionable sense the task asks for; at best
  it's a line in the durability statement telling a reader to check their own host.

### Option D — Document the exposure and build nothing

- **Setup cost**: a durability statement, no code.
- **Per-task cost**: zero.
- **Recovers**: nothing beyond what the reader's own backup discipline already recovers.
- **Silently fails to recover**: everything, if the reader has no such discipline — but this
  failure is now *visible*, stated in the rules a reader of the project consults, rather than
  silent.
- **Disqualifying criterion**: trivially passes — there is no new branch, no new repo, no new
  sync target, and no churn of any kind.

## Decisions

- **Recommendation: Option D.** Every mechanism that adds real recoverability (A, B) does so by
  creating a second place `specs/` content must also live, and a second place is, by
  construction, more branches, more repos, or more remotes to configure and keep alive — the
  exact cost the ignored posture exists to avoid. The one option that doesn't pay that cost
  (C) isn't something this project can build, verify, or recommend as an action; it collapses
  into "state the exposure and tell the reader to check their own host," which is Option D with
  extra words.
- This is not a claim that durability doesn't matter. It is a claim that every *mechanism*
  answer here is worse than the disease for this project's specific constraint set (a system
  that already explicitly disqualified cross-branch churn as a cost class), and that the honest,
  complete answer is to say so plainly rather than adopt a mechanism this task's own criteria
  rule out.
- A future repository with different constraints (e.g., one where a sibling specs-repository is
  already part of its normal operational posture, not something stood up solely for this
  purpose) could reasonably choose Option A. That is a per-repository decision this
  recommendation deliberately leaves open rather than forecloses — nothing here says Option A is
  never acceptable, only that it is not the one this project should adopt by default.

## Risks & Mitigations

- **Risk**: a reader skims past a documentation-only durability statement and assumes some
  mechanism already protects their ignored `specs/` tree. **Mitigation**: the statement below is
  written in the negative ("nothing here recovers X") rather than descriptively, so it cannot be
  misread as a feature.
- **Risk**: a future task reopens this question and builds Option A or B anyway, without
  re-deriving why they were rejected. **Mitigation**: this report and the durability statement
  both name the disqualifying criterion explicitly, not just the conclusion, so a future reader
  can check whether their situation actually differs before reversing the decision.

## Context Extension Recommendations

- **Topic**: specs/ durability under the ignored posture.
- **Gap**: no existing standard states what is and is not recoverable when `specs/` is
  gitignored; `orchestrator-runtime-files.md` covers a different, narrower file class
  (ephemeral orchestrator runtime scratch files, already gitignored under the *tracked* posture
  too) and does not speak to whole-tree loss.
- **Recommendation**: the sibling documentation task (reframing the surfaces that assert
  `specs/` is committed) is the correct place for this — see "Recommendation for Placement"
  below for the drafted text — rather than a new standalone standards file, since the statement
  is short and belongs beside the existing posture-description surfaces, not in a new location.

## Recommendation for Placement

Drafted durability statement, sized for insertion beside the other per-posture statements the
sibling documentation task places (plain prose, no heading level prescribed — the docs task
should fit it to the surface it lands in):

> **If the specs tree is gitignored**, task state, reports, plans, and summaries exist only on
> this working copy's disk. No commit, branch, or repository preserves them. Losing or
> discarding this working copy loses all of it, with no git history to recover from. This
> project does not provide, and does not recommend adopting, a mechanism to back up an ignored
> specs tree — a sibling repository, an archive branch, or a sync tool each either reintroduces
> the cross-branch or cross-repository overhead the ignored posture exists to avoid, or is a
> host-level concern this project cannot verify or configure. If specs/ durability matters for a
> given repository, track it instead; the tracked posture remains fully supported and carries its
> own git history for free.

## Appendix

- Search queries used: none (web search not invoked; see Context & Scope).
- Codebase surfaces consulted: `specs/TODO.md` (tasks 658, 660, 661, 662, 663), `.gitignore`,
  `.claude-extensions.json`, `agent-system/extensions/core/context/standards/
  orchestrator-runtime-files.md`, `agent-system/extensions/literature/context/project/
  literature/domain/literature-index.md`, grep over `agent-system/extensions/core/{context,docs}`
  for `orphan`, `sibling repo`, `archive branch`, `git bundle`, `rsync`, `syncthing`, `backup`.
