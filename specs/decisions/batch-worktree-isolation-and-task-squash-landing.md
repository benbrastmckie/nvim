# Decision Record: Batch Worktree Isolation and Per-Task Squash Landing

This record amends rulings R1, R2, R3 and R5 of
`specs/decisions/branch-topology-and-landing-strategy.md` (the "topology record") and states the
consequence for its R6. It reinstates working-tree isolation at one granularity only, the
orchestrate invocation (a "batch"), and rules how a task's work lands on the long-lived
integration branch as one squash commit.

Decided 2026-11-20 by `amend_branch_topology_per_batch_worktree_squash` (667). Tasks are named
by slug with the number alongside, because numbers are reassigned at a vault renumber and slugs
are not.

This record rules. It builds two things only: the repaired landing verification (see
"Built-mechanism verdicts") and the task records that carry the rest (see "Successor tasks").
Nothing else described below exists yet. Until the successors land, every dispatch still runs in
the single shared working tree exactly as the topology record describes.

## Authority

The user decided the target workflow on 2026-11-20, in their own words as the task description
records them: long-lived feature branches, with short-lived batch side branches that merge one
squashed commit per task, where the side branches are cleaned up after. The user asked directly
why worktrees are not used and, shown the analysis, directed that R5 and R1 to R3 be amended.

R5 read "not reinstated, in any form, at any granularity". It is re-opened by the same authority
that issued it. R4 (the `integration_branch` key), R7 (the roadmap regenerate and the batch gate
already satisfy the milestone bullets) and R8 (prepare, never push) are NOT re-opened and stand
as written. R8's handoff now points at the integration branch.

The user also gave guidance for Lean repositories on the same date: avoiding worktrees there is
acceptable if reasonable, and using them is acceptable only by a route that does not duplicate
the lake builds. That guidance governs "Isolation-off repositories" below.

## Evidence read

Read in full for this record, in this dispatch, not taken from a summary:

- `specs/decisions/branch-topology-and-landing-strategy.md`
- `specs/decisions/worktree-isolation-removal-verdict.md` (the "removal verdict")
- `specs/decisions/worktree-isolation-removal-reaffirmation.md` (the "reaffirmation")
- `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
  (the "reopening report"; the path the reaffirmation cites, under `specs/301_.../`, has since
  moved to the archive)
- `specs/decisions/commit-layer-cluster-ordering.md`: Edges, Judgment calls, Inputs to the
  branch feature

Measurements below carry one of two attributions:

- **Measured in the research report** means
  `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_batch-worktree-squash-amendment.md`
  ran the experiment in scratch fixtures. This record cites those results and did not re-run
  them: the attribution-landing, back-merge, compare-and-swap deletion and sparse-worktree
  fixtures, the six `git-commit-scoped.sh` wrong-root cases, the consumer enumeration counts, and
  the Lean repository sizes.
- **Re-derived at plan time** means the implementing plan's Premise Re-Validation checked it
  against live state: the source store location, `specs/` being tracked, `integration_branch`
  being undeclared, the D1 line citations, the two context-budget byte counts, the state of
  records 655 and 666, the existence of every file to be edited, and the absence of the ancestry
  predicate from any context file.

## The starting claim, verified

The claim to verify was: what was removed was a worktree PER DISPATCH with gitignored mutable
state hardlink-cloned into it, and the recorded defects are properties of that layer, not of
`git worktree`.

It holds, with one qualification that this record does not soften. The removal verdict's
structural reason has two parts. The first is specific to cloning: hardlink correctness rests on
atomic-rename rebindability, a per-writer property. A design that clones nothing has no instance
of it. The second is general: "a layer whose correctness depends on the continuing discipline of
unrelated scripts that do not know it exists cannot be audited once and then trusted." The
reopening report applies that second part to exactly the siting this record adopts (its question
13): a worktree outside the repository root requires every path-resolving tool to be re-audited
for an absolute-path assumption, "itself a fresh instance" of the hazard.

That objection is correct and it applies here. This design does not dissolve it. It answers it
differently from the removed layer: a consumer that resolves the wrong root must refuse loudly
instead of degrading silently, and the refusal is keyed on a batch record the consumer can read,
so correctness stops depending on a caller knowing the mechanism exists. That is an obligation on
successor work, not a property this record can assert. See defect 2.

## Defects engaged

Each entry names the recorded mechanism, then states either why the amended design cannot
reproduce it or that it is closed only by named successor work.

### 1. Destructive release on a `nothing_to_land` verdict

**Recorded mechanism** (removal verdict, defect table). `dispatch-worktree.sh land` derived
`nothing_to_land` from a pure ancestry test and never inspected the working tree; postflight
folded that verdict into the success branch and released the worktree at once. It nearly
destroyed 456 verified Lean lines.

**Under this design.** Not closed by construction. Closed only if cleanup is built as ruled in
"Cleanup and retention": removal is conditional on a recorded landing proof for every task of
the batch, is never forced, and is never triggered by an inferred or empty verdict. Measured in
the research report: `git worktree remove` without `--force` exits 128 on a modified file and on
an untracked file. Residual, also measured there: it does not refuse on ignored files, so a
build product or report written to an ignored path would be deleted silently. Removal therefore
carries its own precondition. A second route to the same harm was observed directly during the
research: `guard-destructive-git.sh` judges safety from the tree of its own process directory,
so a destructive command aimed at a dirty batch worktree is allowed whenever the primary tree is
clean. Owner: the cleanup successor and the hooks successor.

### 2. `git-commit-scoped.sh` worktree-blind project root

**Recorded mechanism** (removal verdict). `PROJECT_ROOT` derived from the script's own location,
no flag to name another tree; every pathspec fell through WARN-and-drop, nothing staged, and the
script returned success. The reaffirmation records it as open and untested under a worktree.

**Under this design. NOT closed by design.** This is the primary risk of the amendment.
Measured in the research report with the live deployed script, invoked by its primary-tree path
against a worktree edit: a new file, an absolute path, and a mixed pathspec are now loud (exit 2,
2 and 4). A relative pathspec naming a file that exists in both trees and is modified only in
the worktree prints "nothing to commit ... (non-blocking)" and exits 1. Every caller treats exit
1 as a benign no-op. That is the recorded defect surviving in its most common shape, an edit to
an existing file. It is closed only by the two-root work: an explicit code root carried in the
dispatch file, and a refusal before staging when a batch record is live for the session and a
code pathspec arrives with no code root, so the silent exit cannot be reached. Owner: the commit
scripts successor.

### 3. `lake-build-guard.sh` false green

**Recorded mechanism** (removal verdict). `cp -al` of `.lake/` shared the inodes of the guard's
five `build-guard.*` state files; `finalize_record()` truncates in place, so a worktree build
overwrote the main tree's record and reported a build that wrote no `.olean`.

**Under this design.** Closed by construction, on one condition that R5 makes a ruling: nothing
is cloned, hardlinked or symlinked into the worktree, build directories included. A second tree
then has its own `.lake/` and its own five state files; there is no shared inode to truncate.
The one candidate that would have introduced a new shared path, symlinking, is rejected below.
No other clone or shared-inode route is introduced. A cost replaces the defect: see "Costs".

### 4. Tasks marked `completed` with commits stranded

**Recorded mechanism** (reaffirmation). Postflight warned that no `modified_files` were reported
and wrote `completed` regardless, with 18 and 10 commits stranded on unmerged branches. The
root-cause hypothesis (edits outside the main tree left `modified_files` empty) is recorded
there as unverified, and stays unverified here.

**Under this design.** Not closed by construction. Closed only if landing and its verification
run strictly before the completion status write and a failure refuses the write. Postflight
already has that ordering for the milestone ref; what was broken there is the verification
predicate, repaired by this task. Owner for the integration-branch landing: the landing
successor. Because the root cause is unverified, the landing successor must not rely on
`modified_files`: attribution reads the batch branch's commits directly.

### 5. Repo-scanning pollution

**Recorded mechanism** (reaffirmation). Worktrees provisioned under the repository root were
walked by generators and inventory scripts, several of which never consult `.gitignore`.

**Under this design.** Closed by siting, ruled in R2: the worktree lives outside the repository
and outside its parent directory, in a per-user state directory. No scan rooted at the
repository or one level above it can reach it. Inside the root is the recorded case. A sibling
directory is seen by any scan rooted one level up. A directory under the git metadata directory
relies on every walker skipping it, the same unaudited assumption. The system temp directory is
refused for a different reason: a reboot would discard uncommitted worktree edits.

### 6. HEAD-stale `specs/` (omitted from the task's defect table)

**Recorded mechanism** (removal verdict, "derived hazard class"). A provisioned worktree held a
HEAD-stale tracked copy of `specs/`, forcing absolute-path artifact writes and a merge-back
refusal for any branch touching `specs/**`.

**Under this design.** It returns in full wherever `specs/` is tracked, and `specs/` is tracked
in this repository and in the Lean consumer surveyed (re-derived at plan time: `git check-ignore`
matches only `/.claude/`). The task description's premise that `specs/` is gitignored is false
here. Ruled in R2: in that posture the worktree is sparse and excludes `specs/`, so a stale read
becomes a missing-file failure instead of a silent one. State is reached only by absolute path
into the primary tree. Measured in the research report: `git worktree add --no-checkout` then
`git sparse-checkout set --no-cone '/*' '!/specs/'` yields a clean worktree with no `specs/`,
and a commit and a back-merge carrying `specs/` changes both succeed.

### 7. Deferral invisibility (omitted from the task's defect table)

**Recorded mechanism** (reaffirmation; reopening report question 4). Unlanded branch work in one
worktree was invisible to a sibling dispatched later against the shared tree.

**Under this design.** Cannot occur inside a batch: every task of the batch shares the one
worktree. It persists between two concurrent batches until the first lands, which is ordinary
branch semantics. Cross-session `file_scope` admission is what keeps it from mattering, and this
record changes nothing about that mechanism.

### 8. Agent-tool isolation forwarding, and raw `git` in the worktree (omitted from the task's defect table)

**Recorded mechanism** (reopening report question 6; reaffirmation). A dispatch row carrying an
isolation field could be forwarded to the harness's own per-agent worktree option. Separately,
an agent in a worktree committed with raw `git` and never called the sanctioned script.

**Under this design.** Both recur. R5 keeps the harness's per-agent worktree option prohibited,
and the dispatch file carries a code-root path only, so there is no isolation field to forward.
Raw `git` is not prevented by this record. Attribution landing (R3) refuses on any commit in the
range it cannot attribute to a task, so a raw commit with a nonconforming subject blocks landing
loudly instead of being skipped. A raw commit with a conforming subject lands, without the
sanctioned script's trailers.

### Budget

The reaffirmation's context-budget finding recurs, tighter. Re-derived at plan time:
`skill-orchestrate/SKILL.md` is 27,494 bytes and `commands/orchestrate.md` 21,496 bytes, against
ceilings the research report records as 27,500 and 22,000. No successor may add prose to either
file. Everything goes in scripts and the dispatch composer.

## Rulings

### R1, amended

The primary working tree stays on the declared integration branch and is never switched during
orchestration. Admission refuses an invocation when the primary tree is on another branch, or
when tracked paths outside the state territory are dirty. Where isolation is on, work happens on
a side branch in a separate worktree.

A blanket "clean tree" test is refused. In a tracked-`specs/` repository the primary tree is
dirty under `specs/` during ordinary operation (this dispatch began with nine modified tracked
paths there and a modified top-level declarations file), so a blanket test would refuse every invocation. "State territory" means `specs/`
and the top-level declarations file. The admission successor fixes the exact path set.

The branch check applies in every repository, isolation on or off.

### R2, amended

One side branch and one worktree per orchestrate invocation. Not per dispatch, not per task.

- Cut from the integration branch tip at admission.
- Named from the session identity.
- Reused on resume: creation is idempotent, keyed on the batch record.
- Sited outside the repository and its parent, in a per-user state directory, keyed by a hash of
  the primary root and the session identity. Never the system temp directory.
- Recorded in a batch record under the primary tree's state directory. No script derives the
  worktree path; every consumer reads it from the record.
- Sparse, excluding `specs/`, wherever `specs/` is tracked.

The siting's precondition was measured live against a scratch repository and a real `git`
worktree sited outside the repository and its parent, and none of the four results refutes the
siting. See `specs/decisions/external-worktree-harness-behaviour.md` and "Measured precondition".

### R3, amended

One squash commit per completed task lands directly on the integration branch, subject
`task {N}: {title}`, body carrying the session identity and the task's phase list.

- **Built by attribution.** The landing selects the task's own commits on the batch branch
  between the merge base and the batch tip, by the `task {N}` commit-subject convention, merge
  commits excluded, applies them with `git cherry-pick -n` in the primary tree, and makes one
  commit. Measured in the research report: with two tasks committing in interleaved order this
  landed exactly the first task's files.
- **Refusing, not skipping.** Landing refuses if the unlanded range holds a commit attributable
  to no task, or if a pick conflicts. A refusal leaves the task un-completed and the branch
  intact.
- **Verified before the status write.** The predicate is blob equality over the task's own path
  set, between the new integration tip and the task's end commit. It runs strictly before the
  completion status is written. It must be shown to fail on a deliberate negative fixture.
- **Idempotent.** A re-run after a recorded landing proof is a no-op.
- **Back-merge.** After a landing, the integration branch is merged into the batch branch so the
  next task's range has the correct merge base. Measured in the research report: clean, since
  both sides carry identical changes.
- **Serialized** under the existing `specs/.commit-lock` mutex. No new lock.

Two concurrent batches landing on one integration branch make the second landing a real
three-way pick that can conflict. The response is refusal with the branch intact; resume is a
back-merge of the integration branch into the batch branch followed by a re-run. `file_scope`
admission across sessions remains the mechanism that makes this rare.

Source-store commits made by `commit-source-store-path.sh` in a second repository are outside
the batch branch and outside the squash. They land on whatever branch that repository has
checked out, as `commit-layer-cluster-ordering.md`'s Input 1 already records. The landing
successor states this in the squash body or rules otherwise; this record does not extend the
squash across repositories.

`git rebase -i` is unavailable in this environment and is not used. Every step above is
non-interactive.

### R5, amended

Worktree isolation is reinstated at batch granularity ONLY.

- Nothing is cloned, hardlinked or symlinked into the worktree. There is no exception for build
  directories.
- Per-dispatch worktrees stay removed.
- Hardlink cloning stays removed.
- The harness's own per-agent worktree option stays prohibited.
- Isolation is a per-repository declaration: `worktree_isolation`, a top-level string key in
  `.claude-extensions.json` beside `integration_branch`, with the values `batch` and `off`.
  Undeclared means `off`. A repository that declares nothing behaves as it does today, apart
  from the R1 branch check once `integration_branch` is declared.

The removal verdict and the reaffirmation are not withdrawn. Their defect tables, measurements
and structural finding stand, and remain the reason per-dispatch worktrees and cloning stay
removed.

### R6, consequence

The topology record's R6 held that one `HEAD` per repository meant
`phase_commit_boundary_mechanical_check` (513)'s expected-ref parameter stays per repository.
Where isolation is on, that premise no longer holds: the expected ref is the batch branch,
queried in the batch worktree. The parameter becomes per tree.

`commit-layer-cluster-ordering.md`'s Judgment 1 ruled that source-store commit scoping (536) and
the third containment site (567) are ordering predecessors of the branch work by file territory
only, and named what would change that: a ruling "that reinstates any form of tree isolation,
since the evidence rests on one `HEAD` per repository." **That condition now fires.** Its
evidence was that `git-commit-scoped.sh` "changes to its project root and commits"; with two
roots that step chooses a `HEAD`, and its containment block decides which paths reach which
tree. Both tasks become semantic predecessors of the two-root work on the commit scripts. The
resulting edges are ruled in "Edges".

Input 3 of that record (the two generated state files ride in every task's commits, so per-task
ranges are not separable by path) dissolves where `specs/` is excluded from the batch worktree,
because those files never appear on the batch branch.

## Rejected alternatives

Each is stated on its own merits.

- **Symlinking `specs/` and `.claude/` into the worktree.** Measured in the research report. A
  directory-only ignore pattern does not match a symlink, so the link shows as untracked and
  blocks `git worktree remove`. Root resolution through the link depends on logical-path `pwd`
  and flips to the primary tree for the six scripts that resolve physically, including
  `git-commit-scoped.sh` and `state-write.sh`. Hooks resolve through `$CLAUDE_PROJECT_DIR`
  regardless. Over a tracked `specs/` it makes every tracked file show as deleted. It makes the
  root depend on how a script happened to be addressed, which is the recorded defect's own
  shape.
- **`git merge --squash` of a task's end commit.** Measured in the research report: with two
  interleaved tasks it co-lands the second task's unfinished phase commit. It is exact only when
  completions are strictly sequential, which a batch does not guarantee.
- **Snapshot semantics with co-landed tasks named in the body.** It lands unverified, unfinished
  work under another task's completion. Refused for the same reason defect 4 is a defect.
- **Full-tree equality as the landing predicate on the integration branch.** Wrong as soon as
  the integration branch carries anything else: a bookkeeping commit, another batch's landing.
  It remains the right predicate for the milestone ref, which lands a snapshot of the whole
  tree; see "Built-mechanism verdicts".
- **A worktree inside or beside the repository, or under the git metadata directory.** See
  defect 5.
- **Option L2 as a design.** See below; it is a feasibility spike, not a design.
- **A plumbing squash inside one shared tree, for isolation-off repositories.** It needs the
  single tree's `HEAD` to sit on a side branch, which every concurrent session in that tree
  would then share.
- **A blanket clean-tree admission test.** See R1.

## Isolation-off repositories (Option L1)

Ruled: Option L1. Isolation is off unless declared, and Lean repositories do not declare it.

**What such a repository gets.** The R1 admission branch check. Phase commits landing directly
on the integration branch, as today. Every existing concurrency mechanism unchanged.

**What it loses.** The per-task squash. Nothing else. The review unit there is the range of a
task's commits, or a squash the user chooses at merge time. This is stated plainly because it
means the user's target workflow is not delivered in Lean repositories by this record.

**Why not L2.** Measured in the research report, read-only, in one Lean consumer repository on
Lean 4.33.0-rc1 and Lake 5.0.0: `.lake/` is 16 GiB, of which 6.4 GiB is project-local output
for 1,468 source files and about 9.6 GiB is dependencies. A fresh worktree would re-fetch the
dependency tier and rebuild the project tier from nothing. No build was timed; the sizes settle
it. The pinned Lake has a `lake cache` subcommand, but its configured cache directory does not
exist on that host, the trace files embed absolute paths under the tree's own build directory,
and no hit rate across differing tree paths has been measured. The reaffirmation's binding rule,
never share or clone a writable build directory between concurrent builders, rules out every
shortcut that is not that cache.

**L2 spike protocol, recorded as deferred.** Populate the local Lake cache from one tree. Build
a second tree at a different path with the network blocked. Count rebuilt modules. Check
`lake-build-guard.sh`'s five state files are distinct inodes in the two trees. No task is
created for it: the user said either option is acceptable and L1 is ruled. A result showing
near-zero rebuilds would be grounds for a dated amendment to this section.

Every ruling in this record must hold with isolation off. Each successor's description carries
that requirement.

## Built-mechanism verdicts

`milestone-ref-land.sh` as it stood, per defect:

- **D1, confirmed.** `--verify` asserted that `HEAD` is an ancestor of the milestone ref, while
  landing parents each new commit on the previous milestone tip. Only the first landing has the
  work branch's `HEAD` as its parent, so the assertion is false permanently from the second
  landing on, while the landed tree is correct. Confirmed by live reproduction in a consumer
  repository (the chain the task description records), by a three-landing replay in the research
  report, and against this repository's own `refs/heads/milestone/M1`.
- **D2, confirmed.** Under the undeclared-branch fallback the first landing parents on `HEAD`
  itself, so the ref is the work branch's whole per-phase history plus one empty-diff commit.
  Nothing is squashed.
- **D3, confirmed.** `integration_branch` is undeclared here and nothing at admission reads it.
- **D4, confirmed.** The ref is a parallel history; merging it back adds commits and no content.

**Verdict on the script.** Retired as a landing mechanism, by the landing successor, once R3's
landing exists: with one squash commit per task on the integration branch itself, a parallel ref
adds only D4's duplicate history. `milestone-review-handoff.sh` then points its review range at
the integration branch. It is NOT retired by this task, and it stays the only landing mechanism
in isolation-off repositories until the landing successor rules on what replaces it there.

**Verdict on `--verify`, built by this task.** The predicate is tree equality: the check passes
exactly when the milestone ref exists and its tip tree equals the tree of `HEAD`. Landing an
unchanged tree creates no commit, so a re-run converges instead of extending the chain. Each
landed commit records its source commit in a trailer, used only to explain a failure. The check
still fails when work did not land: a commit made after the last landing changes `HEAD`'s tree
and the check exits 1. The suite carries that negative fixture, and it was observed to fail
before the repair was accepted.

**Verdict on the postflight response.** The refusal of the completion status write on a verify
failure is KEPT. It is the closure of defect 4 and must not be weakened into a warning. The
message "Re-run to retry the landing" is REPLACED: under the ancestry predicate it sent an
operator into an unbounded loop, each retry diverging the chain further. Under tree equality a
re-run does converge, because it lands the current tree. The new message says so, and bounds it:
a second identical refusal with `HEAD` unchanged means stop and report, not retry again.

One residual is accepted. A sibling's commit landing on the work branch between a task's landing
and its verify changes `HEAD`'s tree and fails the check on correct work. That failure is
recoverable by one re-run, and the message says so.

## Cleanup and retention

- **When.** Only when every task of the batch has a recorded landing proof.
- **Removal precondition.** In the worktree, `git status --porcelain --ignored` shows nothing
  outside a declared allowlist. This covers modified, untracked and ignored content; the last is
  what `git worktree remove` does not check.
- **Removal.** `git worktree remove` without `--force`. A refusal is reported and the worktree
  stays.
- **Branch deletion.** `git branch -d` refuses a squash-landed branch as unmerged (measured in
  the research report). Deletion is therefore `git update-ref -d <ref> <proven tip>`, a
  compare-and-swap against the tip recorded with the landing proof. A branch that advanced after
  its proof was recorded cannot be deleted by it. Never delete on an inferred verdict. The
  whole-batch predicate `git merge-tree --write-tree` equal to the integration tree is a
  necessary check and never by itself a proof: it is also true of a branch that never changed
  anything.
- **Retention.** A task left `[PARTIAL]`, `[BLOCKED]`, failed or abandoned keeps the worktree
  and the branch for resume.
- **Mixed batch.** A batch holding both landed and retained tasks keeps both worktree and
  branch. The landed tasks' commits stay on the branch as history already present on the
  integration branch through the back-merge.
- **Orphans.** `/refresh` lists batch records whose session is not live and whose worktree still
  exists. It removes nothing.
- **`guard-destructive-git.sh`** is respected throughout, and must itself evaluate the tree a
  command targets (defect 1).

## Costs

- **Builds are no longer serialized across trees.** `build-guard.lock` is per tree. Two batches
  building in two trees do not exclude each other, where two sessions in one tree do today. The
  build-heavy co-scheduling rule covers one orchestration only. A host-wide lock is a separate
  decision, not made here.
- **Disk.** Each batch worktree is a full checkout, less `specs/` where sparse. Negligible in
  this repository; decisive for Lean, hence L1.
- **Deploy ordering.** `.extensions.<name>.source_dir` is an absolute path into the primary
  tree. In a repository that owns its source store, a batch's source-store edits sit in the
  worktree and are not what a redeploy reads until they land. The order is land, redeploy,
  verify. Postflight already refuses completion on a pending deploy.
- **Registrations.** `lean-lsp` and Sapience registrations are keyed on the session's project
  path, which stays the primary tree. Sapience is unaffected. `lean-lsp` would serve the primary
  tree's files, not the worktree's; moot under L1.
- **One phase can produce two commits in two trees** where `specs/` is tracked: a code commit on
  the batch branch and a bookkeeping commit on the integration branch. See the next section.

## Unconfirmed assumption

**The user has not ruled on this.** The research report raised it as a non-blocking question and
it is unanswered.

In a repository where `specs/` is tracked, task bookkeeping (state, plan markers, reports,
summaries) is committed in the primary tree. Two options:

- **A. Bookkeeping commits land directly on the integration branch, as today**, between the
  per-task squash commits. The squash carries code only. Simple and durable; the integration
  branch's history is squash commits interleaved with bookkeeping commits.
- **B. Each task's state and artifact changes are held uncommitted and folded into its squash.**
  One commit per task with nothing between, at the cost of state sitting uncommitted for the
  life of a task, against the commit-per-green-substep mandate.

This record proceeds on **A**, the research recommendation. That is an assumption made to keep
the work moving, not a decision. Nothing built by this task depends on it. The commit scripts
successor carries it in its description, with the instruction to re-plan its two-root split if
the user answers B.

## Measured precondition

R2's siting rests on four harness behaviours that could not be measured from a dispatched agent:

1. Whether file tools prompt or refuse for a path outside the project directory.
2. Whether path-scoped rules apply to files there.
3. What working directory a hook process receives.
4. What working directory a subagent starts in.

These are a precondition, not an assumption to build on. The measurement successor runs first,
and every two-root successor depends on it. **If a measurement refutes the siting, the siting
ruling is amended by a dated note on this record. It is not worked around** in a script, by a
symlink, or by moving the worktree inside the repository.

**Discharged by** external-worktree-harness-behaviour.md, 2026-11-22: all four were measured live
against a scratch repository and a real `git` worktree sited outside the repository and its
parent. None refutes the siting. Two residuals were named and judged not to bear on the siting:
file-tool behaviour for an external path under a non-`bypassPermissions` mode (not observable
from a dispatched agent; needs the user), and the hook subprocess's own raw OS-level `pwd`
(deliberately not isolated, since doing so needed temporary diagnostic instrumentation in live
personal settings).

## Successor tasks

Eight task records carry what this record rules and does not build. Each was created through the
`/task` creation path (`audit-task-proposals.sh`, then `state-write.sh --allocate-into
--audit-verdict`), with topic `orchestrator` and type `meta`. Each description cites this record
by section instead of restating it.

| Number | Slug | Elements and criteria owned | Backlog audit verdict against 655 |
|---|---|---|---|
| 668 | `measure_harness_behaviour_for_external_worktree` | The four measurements of "Measured precondition". Owns no running-behaviour criterion; its own criterion is a measurement record under `specs/decisions/` | duplicate-of-open, semantic only (0.53) |
| 669 | `integration_branch_admission_and_batch_worktree` | Element 2 and D3: both declaration schema rows, admission, the batch record, idempotent sparse worktree creation. Owns: "an invocation started off the integration branch or on a dirty primary tree is refused at admission"; "a multi-task batch produces one worktree and one batch branch" | duplicate-of-open, path overlap (0.63) |
| 670 | `two_root_contract_dispatch_and_commit_scripts` | Element 3, core: the code root in the dispatch file, the commit, snapshot, verification and build-guard callers, the pre-staging refusal, 513's per-tree expected ref. Carries the unconfirmed bookkeeping assumption. Owns: the commit-path half of "no script commits from the wrong root, and a wrong-root invocation refuses loudly" | duplicate-of-open, path overlap (0.53) |
| 671 | `two_root_contract_in_hooks` | Element 3, hooks: `guard-destructive-git.sh` judging the targeted tree, the write-time refusal under the primary root, the payload-path hooks. Owns: the hook half of the same criterion | duplicate-of-open, semantic only (0.52) |
| 672 | `two_root_classification_of_remaining_consumers` | Element 3, remainder: every row of `reports/01_two-root-consumers.tsv`, the cross-check set, the instruction documents. Owns no criterion of its own; it is the completeness half of the audit | duplicate-of-open, semantic only (0.48) |
| 673 | `per_task_attribution_squash_landing` | Element 4: attribution landing, blob-equality verification with a negative fixture, back-merge, the two-batch conflict fixture, second-repository commits, retirement of `milestone-ref-land.sh`. Owns: "one squash commit per completed task on the integration branch with its phase list in the body, the primary tree never having changed branch"; "a task failing mid-batch leaves its commits, branch and worktree intact while its sibling lands" | duplicate-of-open, path overlap (0.59) |
| 674 | `batch_worktree_cleanup_retention_orphan_report` | Element 5: the removal precondition, unforced removal, compare-and-swap deletion, retention, the mixed batch, report-only `/refresh`. Owns: "after a fully landed batch the worktree and branch are gone; after a partial one they remain" | duplicate-of-open, semantic only (0.54) |
| 675 | `branch_topology_documentation_parity` | Element 7: the narrative's Branch Strategy section, `ref-plumbing-landing.md`, the rule in `rules/git-workflow.md`, the schema rows' prose, index line counts. Owns: "the rules, the narrative and the scripts state the same contract" | duplicate-of-open, path overlap (0.64) |

**Count.** Eight, as planned. No unit had to be merged or split while writing the descriptions.
672 is the one most likely to divide later, and its description says so.

**Audit verdicts, and why creation proceeded.** Every proposal drew a `duplicate-of-open`
verdict naming `branch_aware_orchestration_and_squash_landing` (655), as expected: these tasks
take over 655's topology elements, and 655 is revised in the same dispatch to its one unrelated
element (see "Edges"). The `/task` path asks the user to confirm creation on such a verdict.
**That confirmation was not put to the user**: the prompt is unreachable from a dispatched
agent, and the implementing plan directed proceeding with the verdict recorded. Each record
carries its full verdict in its own `audit_verdict` field. A reader who disagrees abandons the
record with `/task --abandon`.

The audits also returned mechanical path overlaps with other open tasks. These are territory
facts for admission to order, not duplication: 670 overlaps the commit-layer chain on the commit
scripts (it is ordered behind that chain's tail by edge), 673 overlaps the open tasks that edit
`orchestrate-cycle-postflight.sh`, and 674 shares the `/refresh` files with
`refresh_tmp_sweep_pass` (664).

**Element 6** (costs to measure and state) has no task of its own. Its content is this record's
"Costs" and "Isolation-off repositories" sections; the one measurement it leaves open, the L2
spike, is recorded as deferred and deliberately not created.

**Coverage, checked in both directions.** The task description's VERIFICATION block has eight
sentences.

| VERIFICATION sentence | Owner |
|---|---|
| Both worktree records are engaged defect by defect in the amending record | Discharged by this record, "Defects engaged" |
| An invocation started off the integration branch or on a dirty primary tree is refused at admission | 669 |
| A multi-task batch produces one worktree and one batch branch | 669 |
| ...and one squash commit per completed task on the integration branch with its phase list in the body, the primary tree never having changed branch | 673 |
| A task failing mid-batch leaves its commits, branch and worktree intact while its sibling lands | 673 |
| No script commits from the wrong root, and a wrong-root invocation refuses loudly | 670 (commit path) and 671 (hooks) |
| After a fully landed batch the worktree and branch are gone; after a partial one they remain | 674 |
| The rules, the narrative and the scripts state the same contract | 675 |

No sentence is unowned. One is split across two owners by design, along the commit-path and
hook halves, and each half is stated in its owner's description. Every owned criterion in a
successor's description traces back to a row above.

## Edges

Written with `update-task-status.sh preflight <N> edge_only <session> --depends-on-add='[...]'`,
which ran the write-time cycle refusal. None was refused. The arrays below are quoted from
`specs/state.json` after the writes.

| Task | `dependencies` as written | Why |
|---|---|---|
| 668 `measure_harness_behaviour_for_external_worktree` | `[667]` | Measures the siting this record rules |
| 669 `integration_branch_admission_and_batch_worktree` | `[517, 667, 668]` | 517 (`stage_regenerated_derived_files_in_phase_commits`) shares `repo-level-declarations.md`, the edge the topology record's R4 put on 655 for the same schema row; 668 because the worktree is not created until its siting is measured |
| 670 `two_root_contract_dispatch_and_commit_scripts` | `[513, 553, 669]` | 513 semantic: it supplies the expected-ref parameter this task makes per tree. 553 is the tail of the commit-layer chain on `git-commit-scoped.sh`. 669 supplies the batch record the refusal is keyed on |
| 671 `two_root_contract_in_hooks` | `[668, 669]` | Needs the measured hook working directory and payload path, and the batch record |
| 672 `two_root_classification_of_remaining_consumers` | `[670]` | Classifies against the contract 670 fixes |
| 673 `per_task_attribution_squash_landing` | `[670, 671]` | Lands only once no script and no hook can commit or destroy from the wrong root |
| 674 `batch_worktree_cleanup_retention_orphan_report` | `[673]` | Cleanup is conditional on the landing proofs 673 records |
| 675 `branch_topology_documentation_parity` | `[672, 673, 674]` | Documents what was built, after it is built |

To check an edge: `jq '.active_projects[]|select(.project_number==N)|.dependencies' specs/state.json`.

**536 and 567: semantic predecessors, reached through 553, with no direct edge.** The R6
consequence makes source-store commit scoping (536) and the third containment site (567)
semantic predecessors of 670. Both are already in 553's transitive closure, re-computed from
the live `dependencies` arrays before any edge was written: 553 lists `[536, 548]`, and 567 is
reached through `536 -> 524 -> 501 -> 486 -> 541 -> 535 -> 567`. So 670's edge on 553 orders it
behind both. The implementing plan read 567's own empty `dependencies` array as showing 567 was
not transitive through 553; that was the wrong array to read (it lists what 567 waits on, not
what waits on 567), and the research report's claim that both precede the commit-script work
through 553 is confirmed. No direct edge was written, because the sanctioned writer cannot
remove one. **This ordering now carries a semantic dependency through a chain written for file
territory.** Anyone who reverses a link in that chain, by the `state-write.sh` recipe
`commit-layer-cluster-ordering.md` documents, must first add 536 and 567 to 670 directly.

**Deliberately not written.**

- 674 against `refresh_tmp_sweep_pass` (664). They share the three `/refresh` files and neither
  needs the other's result. That is territory for admission to order, stated in 674's
  description.
- 670 directly on 668. Reached through 669.
- Any edge onto 655. Its remaining scope is unrelated to topology.

**655, `branch_aware_orchestration_and_squash_landing`, revised.** Its description is rewritten
to its generated-file declaration, its one element unrelated to topology, with a paragraph
naming the task that now owns each superseded element. The three stacked override blocks are
removed. Its title is changed to match; its slug cannot change. Its `dependencies` stay
`[513, 517, 553, 654, 657]`, left in place because the sanctioned writer cannot remove an edge.
Of these, 654 and 657 are completed; 513 and 553 served the commit-script and expected-ref work
that has moved to 670, and the narrowed scope no longer needs them; 517 may still matter if the
declaration is documented in `repo-level-declarations.md`. Its `file_scope` still lists the
seven files of the superseded scope, because the generated-file element does not fix which
files it touches; the description says so and directs that it be re-declared at plan time.
Until then 655 over-claims territory on the commit scripts.

**666, `re_site_branch_aware_batch_after_prerequisites`, settled by evidence and not
abandoned.** Commit `7231ccbe2` moved 655's batch from position 3 to position 19, after its
three non-terminal prerequisites at 9, 15 and 18; no task sits in two batches; the full member
list is identical before and after (127 entries). The named instance is applied. Its sweep
requirement is not: one inversion remains, `manifest_registration_dropped_from_phase_commit`
(486) in the batch at position 8 depending on `snapshot_artifacts_contaminate_phase_commits`
(541) in the batch at position 9. The finding is written at the top of 666's description with a
recommended disposition. Abandonment is the user's.

**Roadmap.** None of 668 to 675 is sited in a batch, and 655's batch keeps a `--hard` flag and a
rationale authored for its superseded scope. Both are for a `/roadmap` pass; this record writes
no roadmap entry.

## Verification criteria of the task description

"Both worktree records are engaged defect by defect in the amending record" is discharged by
"Defects engaged" above. Every other criterion describes running behaviour and is owned by a
successor; the assignment is in "Successor tasks".

## Provenance

- Task `amend_branch_topology_per_batch_worktree_squash` (667), implement dispatch, session
  `sess_1795203458_188c22`, 2026-11-20.
- Amends: `specs/decisions/branch-topology-and-landing-strategy.md` (R1, R2, R3, R5; R6
  consequence) and `specs/decisions/commit-layer-cluster-ordering.md` (Judgment 1).
- Research input:
  `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_batch-worktree-squash-amendment.md`
  and `reports/01_two-root-consumers.tsv` beside it.
- Implementing plan:
  `specs/667_amend_branch_topology_per_batch_worktree_squash/plans/01_batch-worktree-squash-amendment.md`.
