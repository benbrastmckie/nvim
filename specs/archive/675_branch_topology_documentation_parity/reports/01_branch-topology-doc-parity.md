# Research Report: Task #675

**Task**: 675 - Rewrite the branch-strategy documentation to state the implemented integration-branch contract
**Started**: 2026-11-23T16:40:00Z
**Completed**: 2026-11-23T17:10:00Z
**Effort**: one research dispatch; implementation estimated at 2-3 phases (rewrite + sweep-fix + redeploy)
**Dependencies**: `two_root_classification_of_remaining_consumers`, `per_task_attribution_squash_landing`, `batch_worktree_cleanup_retention_orphan_report` (per the amending record's Edges table). The first and third are held (worktree/two-root work deferred); the second (`per_task_attribution_squash_landing`) is completed and is the load-bearing one — its own ruling record settles what this task documents, per the task description's "RULING THIS DOCUMENTS" paragraph.
**Sources/Inputs**:
  - `specs/decisions/branch-topology-and-landing-strategy.md` (R1-R8, read in full)
  - `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (the amending record, key sections read: Rulings R1/R2/R3/R5/R6-amended, Isolation-off repositories, Built-mechanism verdicts, Successor tasks, Edges)
  - `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (the third, load-bearing ruling; read in full)
  - `specs/669_integration_branch_admission_and_batch_worktree/summaries/01_integration-branch-admission-summary.md` and `specs/673_per_task_attribution_squash_landing/summaries/01_landing-verification-gate-summary.md` (what was actually built)
  - `specs/673_.../reports/01_isolation-off-landing-ruling.md` (its own Recommendations item 4 names the two context documents this task owns)
  - Live scripts read directly: `scripts/milestone-ref-land.sh` (header), `scripts/update-task-status.sh` (PHASE 0.6 gate), `scripts/orchestrate-cycle-plan.sh` (admission call site), `scripts/lib/batch-admission-lib.sh`, existence checks on `scripts/task-landing-verify.sh` and `scripts/milestone-review-handoff.sh`
  - Live documents read in full: `context/standards/git-workflow-narrative.md`, `context/patterns/ref-plumbing-landing.md`, `rules/git-workflow.md`, `context/standards/repo-level-declarations.md`, `context/standards/git-staging-scope.md` (targeted sections), `context/standards/shared-worktree-discipline.md` (in full), `context/contracts/conclusion-stage.md` (targeted section)
  - `specs/state.json` for live task status/dependencies/hold reasons of tasks 668-675 and 686
  - `index-entries.json` line counts vs. live `wc -l` for all five target files plus the two sweep files
**Artifacts**: - `specs/675_branch_topology_documentation_parity/reports/01_branch-topology-doc-parity.md` (this report)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Two of the five named edit targets are already current and need no rewrite; two are
  substantially stale; one is a mechanical no-op.** `context/patterns/ref-plumbing-landing.md`
  and `context/standards/repo-level-declarations.md` were already kept in sync by the tasks that
  built the mechanism (`per_task_attribution_squash_landing` and
  `integration_branch_admission_and_batch_worktree` respectively) and correctly state the
  implemented, isolation-off contract today. `context/standards/git-workflow-narrative.md`'s
  Branch Strategy section and `rules/git-workflow.md` are genuinely stale/absent and need the
  rewrite the task description asks for. `index-entries.json` line counts for the two already-
  current files are already correct; only the files this task actually edits will need their
  counts updated.
- **The sweep found one confirmed stale page outside the task's `file_scope`:**
  `context/contracts/conclusion-stage.md` (line ~414) still says the milestone review ref is
  "landed by `scripts/milestone-ref-land.sh` at each task's own completion" and describes
  `milestone-review-handoff.sh` as reading a `refs/heads/milestone/<id>` ref — both retired.
  `per_task_attribution_squash_landing`'s own research report explicitly named this page as
  belonging to this task. It is not in the task's declared `file_scope` today.
- **The sweep's two explicitly-named files diverge in outcome.**
  `context/standards/shared-worktree-discipline.md`'s opening sentence ("per-agent worktree
  isolation is a settled non-goal, not an open question") is stale in the sense the task
  description flags: PER-DISPATCH isolation is still correctly a settled non-goal, but
  BATCH-granularity isolation is now a declared-but-unimplemented mode with five held
  successor tasks waiting behind it — neither "settled" nor "implemented," and the page
  currently reads as if the whole topic is closed. `context/standards/git-staging-scope.md`,
  by contrast, makes no branch/worktree-topology claim that the ruling record changed: its one
  mention of "per-dispatch working-tree isolation" (as a scored-but-unadopted remedy, cross-
  referenced to `batch-orchestration-guardrails.md`) remains accurate, because per-dispatch
  isolation specifically stays removed under every amendment. No edit to this file is
  recommended.
- **The implemented contract, verified against the scripts rather than the records**: the
  primary tree stays on the declared `integration_branch` (admission refuses off-branch or a
  dirty state-territory invocation, confirmed live in `orchestrate-cycle-plan.sh` and
  `batch-admission-lib.sh`); `worktree_isolation` is `off` unless declared `batch`, and `batch`
  is refused loudly (`isolation_unimplemented`) rather than silently honored, because nothing
  builds it yet; phase commits stay on the integration branch as made — nothing is picked,
  squashed, or rewritten there; landing is a verification (`task-landing-verify.sh`, V1/V2/V4/V5)
  that runs inside `update-task-status.sh postflight` strictly before the completion status
  write and refuses (exit 7) rather than skips; `milestone-ref-land.sh` is retired as a landing
  mechanism (confirmed by its own live header comment) and stays on disk as an unused snapshot
  utility; `milestone-review-handoff.sh` now reads the integration branch and the landing
  proofs, not a milestone ref.
- **The held worktree/two-root successor tasks, by slug** (cite these, never by number, per
  `no-task-references-in-deliverables.md`): `batch_worktree_creation_when_isolation_on`,
  `two_root_contract_dispatch_and_commit_scripts`, `two_root_contract_in_hooks`,
  `two_root_classification_of_remaining_consumers`, `batch_worktree_cleanup_retention_orphan_report`
  — all five are live `hold` status in `specs/state.json`, each with a hold reason naming the
  operator's isolation-deferral direction.

## Context & Scope

The task asks for documentation parity with the ACTUALLY IMPLEMENTED contract, not with the
full ruling: the primary tree stays on a declared integration branch; a task's phase commits
land there directly and are verified (not squashed) before completion; worktree isolation and
the per-task squash are declared-but-unimplemented, deferred behind five held tasks. The research
scope was to (1) read all three ruling records in full or in the relevant sections, (2) read
the live scripts the records describe to confirm what is actually built (the task's own
verification criterion: "checked by reading the scripts rather than the records"), (3) read
the five named target documents' current content to classify each as current, stale, or absent,
and (4) sweep the two named standards documents plus anything else the ruling records'
"follow-ups" sections flagged as belonging to this task.

Out of scope for this research pass: actually editing any file (this is the research phase;
editing is the plan/implementation phase's job), and re-deriving the ruling itself — the three
decision records are binding and are cited, not re-argued.

## Findings

### Codebase Patterns

**What the live scripts actually do** (read directly, not inferred from the records):

- `scripts/orchestrate-cycle-plan.sh` line ~852 onward calls
  `batch_admission_evaluate "$PROJECT_ROOT" ...` from `scripts/lib/batch-admission-lib.sh`,
  sourced hard, before any dispatch is composed. This is the `integration_branch` /
  `worktree_isolation` admission gate (`off_integration_branch`, `dirty_primary_tree`,
  `isolation_unimplemented` stop reasons), live in this repository's deployed copy.
- `scripts/update-task-status.sh` carries a header-documented exit code 7 ("Postflight landing
  gate refused the transition") and a "PHASE 0.6: Postflight landing gate (unconditional, exit
  7)" block (around line 1044) that calls `scripts/task-landing-verify.sh` beside the script and
  exits 7, writing no state, on a refusal. This is the single choke-point the research report
  for `per_task_attribution_squash_landing` flagged as the open question ("the plan either
  places the predicate there... or wires every caller") — confirmed resolved in favor of the
  choke-point option.
- `scripts/task-landing-verify.sh` exists (20,648 bytes, executable) and
  `scripts/lib/batch-admission-lib.sh` exists (17,130 bytes) — both load-bearing scripts this
  task's documentation must describe are present and wired, not aspirational.
- `scripts/milestone-ref-land.sh`'s own header (lines 1-11) already states its retired status in
  its own words: "no lifecycle script calls this script, and it is not a landing mechanism...
  This script stays as the worked implementation of the plumbing idiom... run by hand when a
  snapshot ref of the current tree is wanted. The ref it writes is a parallel history." This is
  independent, in-script confirmation of the ruling record's "Verdict on the script" paragraph —
  the live artifact and the record agree.
- `grep -rn "git checkout -b\|git switch -c" scripts/ hooks/` returns exactly one hit today:
  `git-snapshot.sh`'s `--branch` rollback path — the same single exception the original topology
  record's R1 measured, unchanged by either amendment. "No script creates or switches branches
  during dispatch work" (the exact claim `rules/git-workflow.md` needs to state per the task
  description) is confirmed true today, not merely asserted by a record.
- `.claude-extensions.json` declares neither `integration_branch` nor `worktree_isolation` in
  this repository today (both read as `null`/undeclared via `jq`) — this repository is currently
  running in the fail-open, undeclared, advisory-only posture for both keys.

**Per-document classification against the five named edit targets:**

| Document | Status found | What is stale (if any) |
|---|---|---|
| `context/standards/git-workflow-narrative.md`, "Branch Strategy" section (lines 235-283) | **Stale** | Describes only the original, un-amended R1-R8 contract: "the admission-time check ... is a separate, consumer-owned concern" (not built out, when it now is); "One squash commit is appended to `refs/heads/milestone/<id>` per completed task" as the live landing mechanism (retired); no mention of `integration_branch` admission refusal, the state territory, `worktree_isolation`, the landing-verification gate, or the held successor tasks. This is the section the task description's item 1 targets, and it needs a substantial rewrite, not a patch. |
| `context/patterns/ref-plumbing-landing.md` | **Already current** | Already carries a "The Landing Mechanism" section (added by `per_task_attribution_squash_landing`, confirmed in its own summary's "What Changed") stating plainly that nothing is picked or squashed on the integration branch, that landing is `task-landing-verify.sh` run inside `update-task-status.sh`, and that the idiom itself is now used for the review ref built at review time, naming `milestone-ref-land.sh` as a snapshot utility no lifecycle script calls. The concurrency-safety argument (the durable content the task description asks to preserve) is intact and unchanged. No edit is needed beyond what the plan may want for cross-reference tidiness. |
| `rules/git-workflow.md` | **Absent, not stale** | Carries no branch rule of any kind today — no mention of which branch a commit lands on, no mention that no script creates or switches branches. The task description's item 3 ("state the branch rule at the point of use") is additive: a new short subsection (near "Commit Message Format" or "Commit Timing," both of which already point at `git-workflow-narrative.md` for elaboration) stating the rule in one or two sentences and pointing at the narrative's Branch Strategy section for detail, matching this rule file's existing pattern of short point-of-use statements plus a pointer. |
| `context/standards/repo-level-declarations.md`, the `integration_branch` and `worktree_isolation` sections (lines 235-328) | **Already current** | Written by `integration_branch_admission_and_batch_worktree` and matches the live schema exactly: both stop reasons, the exact state-territory list, the fail-open-on-absence table, and a clearly labeled Live-vs-Declared-not-implemented table for `worktree_isolation` naming the held successor by slug (`batch_worktree_creation_when_isolation_on`, confirmed a real, currently-held task, not a dangling reference). No edit is needed; the task description's item 4 is already satisfied by the implementing task's own documentation work. |
| `index-entries.json` line counts | **Mechanical, deferred to edit time** | `index-entries.json` only carries entries for paths under `context/**` (confirmed: `rules/**` files carry no `line_count` entry at all, by design of the index — not a gap this task needs to fix). Current recorded counts for all `context/**` targets (`git-workflow-narrative.md` 297, `ref-plumbing-landing.md` 98, `repo-level-declarations.md` 418) exactly match live `wc -l` today. Only `git-workflow-narrative.md`'s count will need updating once its rewrite changes its length; `ref-plumbing-landing.md` and `repo-level-declarations.md` need no count change unless the plan also edits them. |

### Sweep findings (task description item 6)

| Document | Sweep result |
|---|---|
| `context/standards/shared-worktree-discipline.md` | **Confirmed stale**, exactly as the task description predicted. Its opening sentence states "per-agent worktree isolation is a settled non-goal, not an open question" citing only the removal reaffirmation record. Read literally this is still half-true (per-DISPATCH isolation genuinely stays removed under every amendment — `batch-worktree-isolation-and-task-squash-landing.md`'s R2-amended: "Per-dispatch worktrees stay removed"), but the amending record reopened isolation at BATCH granularity as a declared-but-unimplemented mode with five held tasks waiting to build it. The page's framing invites a reader to conclude the whole topic is closed, when a part of it is open-but-not-yet-built. The fix is narrow: state that per-dispatch/per-agent isolation specifically stays a settled non-goal, and that batch-granularity isolation is a separate, currently off-unless-declared, declared-but-unimplemented mode, naming the held successor slugs, matching exactly the distinction `repo-level-declarations.md` already draws correctly for `worktree_isolation`. |
| `context/standards/git-staging-scope.md` | **No stale claim found.** Grepped for every branch/worktree/landing-mechanism term the ruling records touch (`cherry-pick`, `squash`, `milestone`, `landing`, `integration branch`, `checked-out branch`, `single working tree`, `one HEAD`, `per-repository`): the only hits are either generic (conditional-branching "branch" in prose, not a git branch; "cherry-pick" in a generic in-progress-merge-state detection list) or the one substantive mention, at lines ~255-269, of "per-dispatch working-tree isolation" offered as one of two scored-but-not-adopted remedies for the cross-task shared-file hazard, cross-referenced to `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture" section. That referenced section itself already states its blanket verdict is retained as history, not a live selection rationale, and remains accurate: per-dispatch isolation is still not adopted. No edit to this file is recommended by this sweep. |
| `context/contracts/conclusion-stage.md` (found via `per_task_attribution_squash_landing`'s own follow-ups, not the task description's literal list) | **Confirmed stale, not currently in `file_scope`.** Around line 414: "`refs/heads/milestone/<id>`, landed by `scripts/milestone-ref-land.sh` at each task's own completion" — both the landing mechanism named and the ref `milestone-review-handoff.sh` is said to confirm are retired/changed. Per `per_task_attribution_squash_landing`'s own summary, `milestone-review-handoff.sh` was rewritten to resolve the integration branch and read landing proofs, and `review.ref` is now `refs/heads/<integration branch>`, not a milestone ref. `per_task_attribution_squash_landing`'s own research report explicitly recommended this page be left to this task ("The last two documents belong to `branch_topology_documentation_parity` (675) by its description"). It should be added to this task's `file_scope` at plan time. |

### External Resources

None consulted; this is an entirely in-repository documentation-parity task and every claim
needed either a decision record, a task artifact, or a live script/document read.

## Recommendations

1. **Rewrite `git-workflow-narrative.md`'s Branch Strategy section.** Replace the five existing
   subsections with content stating: the primary tree stays on the declared `integration_branch`
   and is never switched during orchestration, verified rather than assumed, with the two live
   admission refusals (`off_integration_branch`, `dirty_primary_tree`) and their exact arming
   condition (both arm only when `integration_branch` is declared; undeclared gives one advisory
   per session, no refusal); phase commits land on the integration branch as made and stay
   there — nothing is picked, squashed, or rewritten there; landing is
   `task-landing-verify.sh`'s verification, run inside `update-task-status.sh postflight`
   strictly before the completion status write, refusing (exit 7) rather than skipping;
   `worktree_isolation` is `off` unless declared, `batch` is declared-but-unimplemented and
   refused loudly rather than silently honored, naming the held successors by slug; point to
   `ref-plumbing-landing.md`'s "The Landing Mechanism" section for where the idiom is actually
   used today (the review ref, built at review time from landing proofs — not the integration
   branch itself). Do not describe a batch branch or a worktree as live anywhere in the rewrite.
2. **Leave `ref-plumbing-landing.md` and `repo-level-declarations.md` untouched** unless the plan
   finds a cross-reference worth tightening; both already state the implemented contract
   accurately and were verified against the live scripts, not just the records, in this report.
3. **Add a short, new branch-rule subsection to `rules/git-workflow.md`.** State, at the point of
   use (near "Commit Message Format" / "Commit Timing"), which branch a commit lands on (the
   checked-out primary-tree branch, verified against the declared `integration_branch` where one
   is declared) and that no script creates or switches branches during dispatch work (excepting
   `git-snapshot.sh`'s `--branch` recovery path), pointing to `git-workflow-narrative.md`'s
   Branch Strategy section for the full detail — matching this file's existing short-rule-plus-
   pointer convention rather than duplicating the narrative's length.
4. **Fix `context/contracts/conclusion-stage.md`'s stale milestone-ref-land/milestone-ref
   paragraph** (around line 414) to describe `milestone-review-handoff.sh` resolving the
   integration branch and reading landing proofs, not a `refs/heads/milestone/<id>` ref landed by
   `milestone-ref-land.sh`. Add this file to the task's `file_scope` at plan time; it is not
   there today and `per_task_attribution_squash_landing`'s own report named it as this task's.
5. **Fix `shared-worktree-discipline.md`'s opening sentence** to separate the two granularities
   explicitly: per-dispatch/per-agent worktree isolation is a settled non-goal (true, unchanged
   by either amendment); batch-granularity worktree isolation is a separate, currently
   off-unless-declared, declared-but-unimplemented mode with named held successors, not a
   settled question either way. Add this file to the task's `file_scope` at plan time if the
   plan accepts this fix (the task description's sweep instruction asks that the sweep's findings
   be reported, which this report does; whether to fix it is the plan's call, but the finding is
   unambiguous).
6. **Do not edit `git-staging-scope.md`.** This report's sweep found no stale branch/worktree
   topology claim in it; its one relevant mention (per-dispatch isolation as a scored-but-
   unadopted remedy) remains accurate under the current ruling.
7. **Update `index-entries.json`'s `line_count` for every `context/**` file actually edited**
   (certainly `git-workflow-narrative.md`; `conclusion-stage.md` and
   `shared-worktree-discipline.md` if the plan accepts recommendations 4 and 5) once the new
   line counts are known post-edit — this is mechanical and cannot be precomputed before the
   edits exist. `rules/git-workflow.md` needs no `index-entries.json` row; the index does not
   cover `rules/**`.
8. **Cite every held successor task by slug, never by number**, per
   `no-task-references-in-deliverables.md` (this applies to every edit this task makes, since
   all target files are deliverables under `agent-system/extensions/core/**`, never under
   `specs/**`). The five live slugs, confirmed held in `specs/state.json` at research time:
   `batch_worktree_creation_when_isolation_on`, `two_root_contract_dispatch_and_commit_scripts`,
   `two_root_contract_in_hooks`, `two_root_classification_of_remaining_consumers`,
   `batch_worktree_cleanup_retention_orphan_report`.

## Decisions

- **Scope narrowed to what is actually stale**, not the full named-file list treated uniformly:
  two of the five named targets (`ref-plumbing-landing.md`, `repo-level-declarations.md`) are
  verified current and this report recommends leaving them untouched rather than re-touching
  files that already state the implemented contract correctly.
- **`conclusion-stage.md` is recommended for inclusion in `file_scope`** at plan time, even
  though it is outside the task's literally-declared scope today, because it carries the same
  staleness class the task exists to fix and was explicitly named by the implementing task's own
  artifacts as belonging here.
- **`git-staging-scope.md` is recommended against editing.** The task description's sweep
  instruction named it as a candidate; this report's sweep did not confirm a stale claim in it,
  and the recommendation is to leave it alone rather than manufacture an edit to satisfy the
  instruction's letter.
- **No blocking user decision is raised.** Every finding above is settled by direct evidence
  (a live script, a live document, or `specs/state.json`), not by a judgment call needing the
  user.

## Risks & Mitigations

- **A rewritten Branch Strategy section could drift from the live scripts again** the next time
  any of the five held successor tasks is un-held and built. Mitigation: the rewrite should cite
  the mechanism by behavior and by script name, not by a static snapshot of exit codes or stop
  reasons that could be renamed; where a number (an exit code, a refusal reason string) is
  stated, it should be the kind of fact a reader can `grep` to re-verify, matching the task
  description's own verification criterion.
- **`conclusion-stage.md` and `shared-worktree-discipline.md` are outside the declared
  `file_scope`.** If the plan does not explicitly widen `file_scope` to include them, an
  implementation agent may skip editing them even though this report recommends it, or may edit
  them and trip a scope-excursion check. Mitigation: the plan should explicitly re-declare
  `file_scope` to include both, stating the reason (matching the pattern
  `integration_branch_admission_and_batch_worktree`'s own summary used for its own scope
  deviations).
- **Index line-count updates cannot be computed now.** They depend on the exact rewritten
  content, which does not exist yet. Mitigation: the plan's last phase should run the mechanical
  `wc -l` check against the four `context/**` targets right before the redeploy, matching the
  pattern `integration_branch_admission_and_batch_worktree`'s and
  `per_task_attribution_squash_landing`'s own summaries describe (both tasks' redeploys included
  an "index-entries.json corrected by the redeploy's auto-repair" step) — if the deploy pipeline
  auto-repairs `line_count` on redeploy, the plan should confirm that before hand-computing it.

## Context Extension Recommendations

none (meta task)

## Appendix

- Decision records read: `specs/decisions/branch-topology-and-landing-strategy.md` (full, 97
  lines), `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (651 lines;
  sections 205-430 and 512-651 read in full, remainder scanned by heading), `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
  (full, ~271 lines).
- Task artifacts read: `specs/669_.../summaries/01_integration-branch-admission-summary.md`,
  `specs/673_.../summaries/01_landing-verification-gate-summary.md`,
  `specs/673_.../reports/01_isolation-off-landing-ruling.md` (full).
- Live scripts inspected: `scripts/milestone-ref-land.sh` (header), `scripts/update-task-status.sh`
  (grep for `task-landing-verify|exit 7|PHASE 0.6`), `scripts/orchestrate-cycle-plan.sh` (grep
  for `integration_branch|batch_admission`), existence/size checks on
  `scripts/task-landing-verify.sh`, `scripts/lib/batch-admission-lib.sh`,
  `scripts/milestone-review-handoff.sh`.
- Live documents read: `context/standards/git-workflow-narrative.md` (full),
  `context/patterns/ref-plumbing-landing.md` (full), `rules/git-workflow.md` (full),
  `context/standards/repo-level-declarations.md` (targeted sections, lines 1-33 and 235-350),
  `context/standards/git-staging-scope.md` (grep passes for branch/worktree/landing terms, plus
  lines 245-280), `context/standards/shared-worktree-discipline.md` (full, 61 lines),
  `context/contracts/conclusion-stage.md` (lines 395-425).
- `specs/state.json` queries: task status/hold-reason for 668-675 and 686;
  `.active_projects[].file_scope` for 675 and 670 (to confirm the dispatch-composer/commit-script
  split); `.integration_branch`/`.worktree_isolation` top-level keys in `.claude-extensions.json`
  (both null, undeclared, in this repository today).
- Searches: `grep -rn "git checkout -b\|git switch -c" scripts/ hooks/` (one hit,
  `git-snapshot.sh`); `grep -rln "milestone-ref-land" --include="*.md" .` (three hits: this
  task's three target/sweep documents, confirming no fourth stale reference exists);
  `grep -rln "batch branch\|cherry-pick" context/standards context/patterns` (three hits, each
  individually checked and found non-stale); line-count comparison (`wc -l` vs.
  `jq '.entries[]|select(.path==...)|.line_count'`) for all five named targets plus the two
  swept files.
