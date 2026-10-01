# Research Report: Task #301

**Task**: 301 - Re-open the question closed by `specs/decisions/worktree-isolation-removal-verdict.md`
**Started**: 2026-10-01T00:00:00Z
**Completed**: 2026-10-01T00:00:00Z
**Effort**: ~1 research dispatch (no implementation; research-and-decide task)
**Dependencies**: None
**Sources/Inputs**: Codebase (scripts, agent/skill contracts, state.json, archived task artifacts), live observation of `/home/benjamin/Projects/Logos/Verification` (a sibling repository with a stale `.claude/` deploy still carrying the deleted `dispatch-worktree.sh`), WebSearch (git worktree orchestration for AI coding agents; CoW/reflink build-cache sharing; Lean/Lake, Cargo/sccache, and Claude-Squad-style harness isolation practice), direct filesystem inspection (`findmnt`, `df -T`), git history inspection, and this task's own round-1 artifact (`reports/01_worktree-run-live-evidence.md`, an operator-supplied primary-evidence record this report builds on and independently re-verifies rather than restates).
**Artifacts**:
- This report: `specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
- Decision record (new): `specs/decisions/worktree-isolation-removal-reaffirmation.md`
- Pointer added to: `specs/decisions/worktree-isolation-removal-verdict.md`
**Standards**: report-format.md, subagent-return.md, no-task-references-in-deliverables.md (this file is under `specs/`, exempt)

## Executive Summary

- **Disposition: CONFIRM.** Per-dispatch `git worktree` isolation stays removed. The full
  reasoning is in `specs/decisions/worktree-isolation-removal-reaffirmation.md`; this report is
  its evidentiary backing.
- **The gate question (item 3 of the original verdict — does any mechanism structurally dissolve
  the per-writer atomic-rename hazard) resolves to "yes in principle, no in practice today."**
  CoW/reflink (`git worktree add --reflink`, buck2-style CAS restores) would dissolve it
  structurally but is unavailable: this host's and the Verification repo's working trees both sit
  on `ext4`, which has no reflink support. Overlayfs would dissolve it structurally and *is*
  available on `ext4`, but requires a new privileged/user-namespace mount-management subsystem
  this system does not have, and does nothing for a second hazard class this task newly found
  (repo-scanning pollution from in-tree worktree provisioning). The single most useful finding
  this research produced — do not clone the build directory at all; give each worktree a fresh
  `.lake/` and rely on Lake's own content-addressed oelean cache the way the Mathlib ecosystem
  already does — is real and structurally sound, but unverified for this repository's non-Mathlib
  Lean targets, and is explicitly flagged as needing its own feasibility spike before it could
  ground a resurrection.
- **Independent of the gate question, every other new finding also points toward CONFIRM.** The
  budget headroom the removal bought is fully consumed by unrelated growth and the gate guarding
  it was promoted from `warn` to `hard` the same day this research ran (7 B of slack on
  `skill-orchestrate/SKILL.md`'s 20,000 B ceiling). Mode 2's supposedly worktree-exclusive
  capability was not actually delivered in the live run under study (a plan-sanctioned driver
  script bypassed `lake-build-guard.sh` entirely via a bare `lake` invocation). A second,
  previously unrecorded hazard class (repo-scanning pollution) generalizes the verdict's own
  decisive argument one level up, to tree-walking tools rather than build-directory writers.
- **The single most adverse-to-resurrection finding in this entire research pass is a fourth
  defect, independently corroborated here, that this task's own round-1 artifact
  (`reports/01_worktree-run-live-evidence.md`) recorded and the dispatch's inline evidence summary
  omitted.** In the same live run, `orchestrate-cycle-postflight.sh` failed to land either
  worktree automatically — it logged `no modified_files reported for task #119/#129; … NOT
  committed automatically` and then marked **both tasks `completed` anyway**, with 18 and 10
  commits respectively stranded on unmerged branches and `components/distsys/` entirely absent
  from `main` at the moment of that `completed` status. The work was recovered only because the
  orchestrating session noticed and landed both branches by hand (`524ff6b`, `e5ebba0` — both
  independently re-verified in this pass: the commits exist, and the files they bring in are
  confirmed present on `main`). This is a second, distinct route into the exact harm class
  abandoned task 276 was created for — not destructive release of uncommitted work, but **silent
  non-landing of committed work reported as `completed`** — and it means `/todo` would have
  archived both tasks while the mainline did not contain their output, had the lead not checked by
  hand. See "Findings > Live Evidence" for the full account and independent re-verification.
- **Narrower improvements the evidence does support, independent of the isolation question**:
  revise task 287 toward measured build weight instead of `task_type` inference; fix the
  `-- specs/` directory-pathspec convention in `meta-builder-agent.md` / `skill-meta/SKILL.md`
  (a newly-found, reproducible mode-1b commit-bleed instance, confirmed in this task's own
  creation commit); independently re-evaluate the PATH-shim wrapper for mode 2 on its own merits.
  None of these is created as a task here — task creation is out of this dispatch's scope.
- **No implementation was performed and no implementation task was created.** No script under
  `agent-system/extensions/core/scripts/` was modified.

## Context & Scope

**Two-round structure.** This task's artifact sequence already held a round-1 report
(`reports/01_worktree-run-live-evidence.md`) before this dispatch began, written by the
orchestrating lead session as an operator-supplied primary-evidence record of a live run observed
in flight, with an explicit instruction to a later research dispatch to verify its claims and
"advance the artifact sequence past this file rather than overwrite it." This report is that
advance: round 1's findings are independently re-verified where checkable (see "Findings > Live
Evidence") and folded into this round's audit, external research, and decision, rather than
restated as already-settled.

Task 301 was dispatched to re-open
`specs/decisions/worktree-isolation-removal-verdict.md` — a record explicitly marked "verdict,
not re-openable" — under genuinely new evidence rather than regret, and to terminate formally in
either a CONFIRM or a SUPERSEDE of that record. The dispatch file
(`specs/301_reopen_worktree_isolation_verdict/.dispatch/1.md`) is unusually detailed: it supplies
the mandatory first input (the removal verdict itself), a list of prior tasks to audit, a block of
time-limited live evidence observed in a sibling repository whose stale deploy still runs the
deleted worktree-isolation layer, an external-research mandate, design requirements that would
apply *only if* resurrection is proposed, a hard user-approval gate for that resurrection path, and
fifteen explicit research questions. This report follows that structure: it audits the prior
tasks, captures the live evidence (destroyed the moment the sibling repository redeploys — hence
captured first, before anything else), runs the external research, measures complexity against the
removal's own footprint table, and answers every one of the fifteen questions. Because the
evidence converges on CONFIRM, the resurrection-only design requirements and the hard approval
gate do not apply; the decision record states this explicitly rather than silently skipping them.

**Out of scope, honored**: no implementation task was created; no orchestration script was
modified; the cost objection was not re-litigated; the `MAX_TASKS` cap, the PATH-shim wrapper
ruling, and the state-schema field rulings were not decided — each remains its own task, named
but not created.

## Findings

### Codebase Patterns

- **The removal is thorough and verified absent from the source store.**
  `agent-system/extensions/core/scripts/dispatch-worktree.sh` does not exist; `git-grep`-style
  searches for "isolation" in `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
  return zero hits, confirming the Move 2 forwarding-prohibition paragraph was fully removed (it
  was described as moot, "no dispatch row carries those fields," in the budget-config file's own
  dated note) rather than merely trimmed.
- **The budget headroom the removal bought is now almost entirely spent.**
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json` (read directly)
  records, as of 2026-10-01: `skill-orchestrate/SKILL.md` at 19,993 B against a 20,000 B ceiling
  (7 B slack, after two dated duplication-trim passes); `commands/orchestrate.md` at 19,024 B
  against a 21,000 B ceiling; eager-load total at 65,402 B against a 65,950 B baseline (548 B
  slack). The same file's own `_comment` records that `ORCHESTRATOR_BUDGET_GATE_MODE` was
  promoted from `warn` to `hard` on this same date (visible independently in this repository's git
  log: `task 305 phase 2: promote ORCHESTRATOR_BUDGET_GATE_MODE from warn to hard`). This is a
  materially harder bar than the one the original removal verdict measured against: a resurrection
  that needs to restore even a short forwarding-prohibition paragraph to `SKILL.md` has 7 bytes of
  room before a now-hard, deploy-blocking gate fails it.
- **`task_type` as a build-weight proxy is confirmed static, not measured.**
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` line 1819:
  `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")`, consulted by `task_is_build_heavy_implement()` at
  line 1820, is a hand-maintained family list with no build-duration or job-count measurement
  anywhere in the admission path. Task 287 (completed; summary at
  `specs/287_no_coschedule_build_heavy_implement/summaries/01_build-heavy-coschedule-rule-summary.md`)
  implemented exactly this static-family admission rule as the removal verdict's Mode 2 ruling
  required — it is working as designed, but the design itself is the thing this task's live
  evidence calls into question (see Research Question 3 below).
- **The Move 2 Agent-tool `isolation`-forwarding hazard is currently moot by construction, not by
  a surviving prose guard.** No dispatch row in the current `orchestrate-cycle-plan.sh` output
  carries an `isolation` or `worktree_path` field at all (confirmed via the budget-config note and
  independently via the `SKILL.md` grep above), so there is nothing to forward. This is a
  structural non-issue only because the feature producing those fields is gone; a resurrection
  reintroduces the exact hazard the prose guard used to cover, and research question 6 (below)
  evaluates whether it can be closed structurally this time.
- **Mode-1b commit bleed via directory pathspec is live and reproducible, confirmed in this task's
  own creation commit.** `git show --stat 4dfe7af61` (this repository) shows the commit that
  created task 301 touching 8 files, 4 of which belong to two other tasks (293, 299) under a
  different, concurrently-live session (`sess_1790826658_06dbd3`, confirmed live in the session
  registry at the time via its `heartbeat_at` ~7 minutes before the commit). `git-commit-scoped.sh`
  was invoked with the directory pathspec `-- specs/` — the literal, prescribed pathspec in both
  `agent-system/extensions/core/agents/meta-builder-agent.md` (Stage 6 step 5) and
  `agent-system/extensions/core/skills/skill-meta/SKILL.md`'s Postflight Git Commit block. No data
  was lost (every swept file was semantically complete, and the task's actual state is intact and
  already further committed in `aed07df8e`), but provenance was damaged: four files now carry
  another session's commit message and attribution trailers. This happens below the layer
  `file_scope` or the contended-path lease can act at, because the collision is at commit-staging
  pathspec granularity, not dispatch admission. This task's own subsequent commits use an explicit
  file list and swept nothing — confirming the fix (narrow the two convention blocks' prescribed
  pathspec from `-- specs/` to an explicit per-file list) closes this completely, without
  resurrecting worktree isolation.
- **Task 287's defer mechanism is well-isolated and auditable.** `orchestrate-cycle-plan.sh`'s
  `task_is_build_heavy_implement()` (hoisted above the bucketing loop per the task's own
  implementation summary, to avoid a silent exit-127-under-`set -euo pipefail` bug) is a single,
  grep-able admission check with its own named defer reason, distinct from `file_scope_collision`.
  This is a clean substrate to extend with a measured signal (Research Question 3) without
  structural rework.

### Live Evidence (Captured Before Redeploy Could Destroy It)

Observed directly in `/home/benjamin/Projects/Logos/Verification`, whose `.claude/` deploy is
stale for the `core`/`lean` extensions and therefore still runs the deleted worktree-isolation
layer, during an `/orchestrate 119,122,129,151,154,159` batch run (2026-09-30/10-01). All items
below were independently re-verified during this research pass (not merely transcribed from the
dispatch):

- **Deployed artifact confirmed present and the source confirmed absent.**
  `/home/benjamin/Projects/Logos/Verification/.claude/scripts/dispatch-worktree.sh` exists,
  30,411 bytes, executable, dated Sep 30 16:29. The corresponding source-store path
  (`/home/benjamin/.config/nvim/agent-system/extensions/core/scripts/dispatch-worktree.sh`) does
  not exist. `git worktree list` in the Verification repo shows two live checkouts:
  `.orchestrate-worktrees/119-12` (branch `orchestrate/task-119-12`, HEAD `2ae828e`) and
  `.orchestrate-worktrees/129-14` (branch `orchestrate/task-129-14`, HEAD `f30d4b6`).
- **Clean isolation for the two lean4 tasks, footprint verified exactly as claimed.**
  `git diff --name-only e06ba69 f30d4b6` (task 129's merge-base to its branch tip) lists 26 files,
  every one under `components/distsys/`. `git log --oneline e06ba69..f30d4b6` shows exactly 10
  clean per-phase commits (`e3da7eb`..`f30d4b6`).
- **Task 119's in-worktree commits never invoked `git-commit-scoped.sh`.** This question is
  closed per the dispatch's own research-question 2 annotation and was not re-investigated; it is
  restated here only to preserve the chain of evidence: defect (b) (`git-commit-scoped.sh`'s
  worktree-blind `PROJECT_ROOT`) remains open and untested under an actual worktree invocation of
  the sanctioned commit path.
- **The build driver bypassed the build guard entirely, confirmed by direct inspection.**
  `books/scripts/certify.sh` inside the `119-12` worktree (406 lines) contains zero occurrences of
  `lake-build-guard` (`grep -c` returns `0`), and its actual invocation lines use bare `lake build
  --wfail`, `lake env`, and `lake shake`, gated only by `command -v lake` at line 109. The script's
  own header comments (not reproduced here) separately document that `lake-build-guard.sh --dir`
  scopes only the lock, not Lake's working directory — a related, independently-documented nuance.
  This is live, first-hand confirmation of the dispatch's claim, not a re-derivation of it.
- **The gitignore entries the removal deleted are confirmed gone and confirmed insufficient even if
  restored.** `git check-ignore -v .orchestrate-worktrees/ specs/.worktree-registry/` in the
  Verification repo returns no matching rule (both now surface as untracked content in `git
  status`). But `.gitignore` governs git's own tracking, not what an arbitrary `find`/`grep`-based
  generator walks — several of the generator classes the live incident named
  (`certificate-export.sh`'s fixture suite, `status-counts.sh`, `typst-component-index.sh`) do not
  consult `.gitignore` at all. Restoring the six deleted lines would not have prevented the
  pollution incident.
- **Postflight failed to land either worktree automatically, and both tasks were still marked
  `completed` — a fourth defect, independently corroborated here.** This task's own round-1
  artifact (`reports/01_worktree-run-live-evidence.md`), written by the orchestrating lead
  session as a primary observational record while the run was in flight, documents that
  `orchestrate-cycle-postflight.sh` emitted `[postflight] WARNING: no modified_files reported for
  task #119/#129; source-file changes NOT committed automatically. Review and commit manually.`
  and then set both tasks' status to `completed` regardless — with 18 commits (task 119) and 10
  commits (task 129) stranded on unmerged branches and `components/distsys/` (task 129's entire
  output) absent from `main` at that moment. This research pass independently re-verified the
  recovery side of this account directly against the Verification repository: `git log --oneline
  --all --grep="dispatch-worktree.sh land"` lists exactly the four commits the record names
  (`e5ebba0` task 129, `524ff6b` task 119, `baa3df1` task 153, `2c2e909` task 118), and
  `git cat-file -e main:components/distsys/lean/lakefile.toml` and
  `main:books/tests/certify/run.sh` both confirm present — i.e., the work was recovered, but only
  because the lead session noticed the discrepancy and landed both branches by hand after the
  fact; the automated land path inside postflight did not do it. (The exact postflight warning
  text was not independently found in this pass's own read of `specs/events.jsonl` in the
  Verification repo — that log may simply not carry stdout warnings — so the warning-text detail
  is reported here as round-1's primary account, corroborated on every independently-checkable
  fact: the commit hashes, their messages, and the files they bring to `main`.) This is the single
  most adverse-to-resurrection finding in the whole research pass: it is a second, distinct route
  into exactly the harm class task 276 was abandoned for (silent loss of the mainline's
  correctness guarantee about what `completed` means), reached not through destructive release
  but through silent non-landing, and it would have caused `/todo` to archive both tasks had the
  lead not checked `git merge-base --is-ancestor` by hand. The round-1 record's working hypothesis
  — that `modified_files` in `.return-meta.json` comes back empty for a worktree dispatch because
  files were modified inside the worktree rather than the main tree, and the postflight commit
  path does not account for that — is plausible given `modified_files`' documented contract
  (repo-relative paths, summed from `files_touched`, consumed by a commit pipeline invoked from
  the repo root) but was not independently re-derived or fixed in this pass; it is recorded as
  unverified root cause, consistent with round-1's own framing.
- **Filesystem confirmed `ext4` on both this repository and the Verification repository.**
  `findmnt -no FSTYPE /` → `ext4`; `df -T` on both repository paths resolves to the same `ext4`
  partition (`/dev/nvme0n1p2`, 93% full, ~33 GB free). This is the fact that resolves the gate
  question against reflink/CoW as a drop-in answer — see Research Question 1 below.

### External Resources

WebSearch queries run (current, dated 2026): git-worktree orchestration for concurrent AI coding
agents; CoW/reflink alternatives to hardlink-cloning (`cp --reflink`, btrfs/XFS/ZFS, overlayfs);
Cargo/sccache-style content-addressed build-cache sharing across worktrees; Lean/Lake build-cache
behavior across projects/worktrees; Claude-Squad-style harness isolation patterns. See Appendix for
the exact queries and sources.

- **Git-worktree-per-agent is now a well-established external pattern** (Claude Squad and similar
  tmux+worktree orchestrators), and the stated best practice is "every concurrent agent owns
  exactly one worktree and one branch, no two processes sharing a working tree path" — consistent
  with what this system built in task 199, and consistent with the clean isolation task 129
  achieved above. External practice does **not**, however, generally address the two load-bearing
  defects this system found in its own implementation (destructive release on `nothing_to_land`,
  and a build guard defeated by shared inodes under `cp -al`); those are specific to this system's
  own `dispatch-worktree.sh`/`lake-build-guard.sh`, not refuted or validated by the external
  survey either way.
- **Git-worktree isolation is explicitly described as *not* solving build-directory or cache
  contention on its own.** "Git worktree only provides low-level workspace isolation and does not
  solve task decomposition, dependency tracking, semantic conflicts, or merge selection,"
  and worktrees "do not isolate … persistent data" without additional measures — directly
  relevant to why this system's own build-contention mode (mode 2) needed a bespoke
  `lake-build-guard.sh`, which the live evidence shows can still be bypassed.
- **CoW/reflink worktree cloning is current, real practice — on filesystems this system does not
  use.** `git-cow` (a `git worktree add` variant that reflinks, including gitignored build
  outputs, costing "~0 disk, ready to build immediately") and buck2's `casd` component (which
  dropped its hardlink policy in favor of reflink-only, in its own words) are both concrete,
  shipped answers to the exact per-writer hazard this verdict's gate question asks about — on
  APFS, btrfs, XFS (`reflink=1`), bcachefs, or ZFS 2.2+. None of those is this system's `ext4`.
  The pattern is real; it is simply not available here without a filesystem migration.
- **The actually-recommended pattern for shared build caches is "share a read-only
  content-addressed store, never a writable working directory."** This is stated explicitly by
  more than one source: a Rust-ecosystem writeup that diagnoses a shared `CARGO_TARGET_DIR`
  growing unbounded (460 GB in one reported case) and corrupting test binaries across worktrees,
  with the fix being a per-worktree `target/` plus a shared `sccache` (keyed on inputs, not
  cargo's path hash — notably with `CARGO_TARGET_DIR`/`CARGO_BUILD_TARGET_DIR` stripped from the
  cache key first so hits land across different worktree paths); and a separate zero-copy,
  content-addressed Rust build-cache tool (`kache`) that restores hits into `target/` as a reflink
  where available, a hardlink or copy otherwise, from a blake3-keyed store, explicitly rejecting
  whole-directory sharing. This maps directly onto Lake: `lake exe cache get`'s own tar-keyed
  oelean store, and the unified cross-project cache folder Lake already maintains, are the same
  pattern this system would want for `.lake/`, rather than hardlink- or reflink-cloning the whole
  directory. This is the most decision-relevant finding this research produced (see Research
  Question 1).
- **An external report of the identical false-green shape this system found independently.**
  A capsem/Cargo-adjacent report titled "Shared cargo target dir can serve a workspace crate built
  from another worktree (false green)" describes the same mechanism as this system's
  `lake-build-guard.sh` defect — a shared, mutable build artifact directory serving a stale or
  cross-worktree result as if it were fresh and correct. This independently corroborates the
  removal verdict's structural argument: this is not a quirk unique to this system's scripts; it
  is a known failure shape of sharing mutable build state across worktrees in general.

## Decisions

1. **CONFIRM the removal verdict.** Full reasoning:
   `specs/decisions/worktree-isolation-removal-reaffirmation.md`. Per-dispatch `git worktree`
   isolation remains removed; no script under `agent-system/extensions/core/scripts/` was
   modified, and no implementation task was created.
2. **No design is proposed, and the hard user-approval gate does not activate.** The gate
   (requirement 4 of the dispatch) is conditioned on the research concluding in favor of
   resurrection. It does not.
3. **A non-blocking `user_decision` is set on `.return-meta.json`** (see that file) surfacing
   this CONFIRM verdict for the user's explicit review, per the user's own stated intent in this
   task's focus text ("I will review this to decide"). This is non-blocking: the decision record
   is written as final per the evidence, and the user can override it on review without the task
   needing to be re-opened to do so — exactly the same mechanism that re-opened the original
   verdict in the first place.
4. **No implementation task is created for any of the narrower follow-ups this research
   surfaced** (287's revision toward measured build weight; the `-- specs/` pathspec fix in
   `meta-builder-agent.md`/`skill-meta/SKILL.md`; the independent PATH-shim re-evaluation) — task
   creation is outside this dispatch's charter; they are named in the Recommendations section
   below for a human or a future `/meta` pass to act on.
5. **Tasks 276, 277, 165, 268 keep their existing dispositions** from the original removal
   verdict's Task Disposition table, unchanged by this reaffirmation (276 remains ABANDON, 277
   remains narrowed to part (b), 165 remains PROMOTE, 268 remains unchanged pending its phase 5).

## Risks & Mitigations

- **Risk: this reaffirmation could be read as foreclosing the Lake-cache-not-clone finding
  prematurely.** Mitigation: the decision record states explicitly that this is the most
  decision-relevant finding produced, names exactly what would need to be verified
  (whether this system's non-Mathlib Lean targets have anything resembling Mathlib's shared oelean
  cache), and recommends it as the one path worth a dedicated feasibility spike — rather than
  silently dropping it or treating "no reflink on ext4" as foreclosing every CoW-adjacent avenue.
- **Risk: narrower follow-ups named here (287 revision, pathspec fix, PATH-shim re-evaluation) are
  forgotten because no task tracks them.** Mitigation: both the decision record and this report
  name them explicitly and by exact mechanism (file, line, current behavior), so a future
  `/meta` or `/spawn` pass has enough detail to create tasks directly from this report without
  re-deriving the evidence.
- **Risk: a future reader re-litigates the cost objection, since isolation is "cheap" per the
  original measurements.** Mitigation: both this report and the reaffirmation record restate, in
  the same place as every other finding, that cost was never the reason and remains not the
  reason — the CONFIRM verdict is for reliability/structural/budget reasons, independently
  re-verified in this pass (the budget-headroom finding, the mode-2-not-actually-closed finding,
  and the repo-scanning-pollution finding), not a re-weighing of disk/latency cost.
- **Risk: the `-- specs/` directory-pathspec defect found here is mistaken for evidence that
  tips the scales toward resurrection**, since it is a real mode-1b gap the original verdict
  under-scored. Mitigation: stated explicitly, in both artifacts, that the fix available (an
  explicit file list, already proven by this task's own later commits) is strictly narrower than
  resurrecting worktree isolation and closes the hole completely on its own.

## Context Extension Recommendations

- **Topic**: `batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation Posture"
  section.
  **Gap**: the section explicitly retains the original three-failure-mode taxonomy "as history
  and reference," but does not yet carry the two new hazard classes this task found (repo-scanning
  pollution from in-tree worktree provisioning; mode 2's guard-bypass-via-bare-invocation
  recurrence) or the Lake-cache-not-clone structural finding.
  **Recommendation**: append a short subsection recording both new hazard classes and the
  CoW/reflink/overlayfs/clone-nothing evaluation, cross-referencing this report and the
  reaffirmation record, so a future re-opening of this question starts from a complete evidence
  base rather than re-deriving it. Not performed here — it would be an edit outside this task's
  charter (the dispatch forbids modifying orchestration scripts, and while this file is prose/docs
  rather than a script, extending it is a documentation change best scoped to its own small task
  or folded into whichever task implements the 287 revision).
- **Topic**: Lake/Mathlib shared-cache feasibility for this system's non-Mathlib Lean targets.
  **Gap**: no existing context file documents whether `components/distsys` (or any other
  non-Mathlib Lean component in this system) has, or could have, a content-addressed oelean cache
  analogous to Mathlib's `lake exe cache get`.
  **Recommendation**: a small, dedicated research spike (not this task) to answer that question
  directly, since it is the single fact that would most change the economics of a future
  resurrection attempt grounded in "clone nothing, reuse a cache" rather than hardlink- or
  reflink-cloning `.lake/` wholesale.

## Recommendations

1. **Confirm the removal verdict** (done — see the decision record).
2. **Revise task 287** to use a measured or probed build-weight signal (recorded prior job
   count/wall-clock duration per task, or a cheap dry-run probe) instead of the static
   `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` family list, so a Mathlib-free `lean4` package like
   task 129 (6 s wall, 17 jobs from an empty `.lake/`) is not categorically refused co-scheduling
   alongside another build-heavy candidate. Not created as a task here.
3. **Fix the `-- specs/` directory-pathspec convention** in `meta-builder-agent.md` (Stage 6 step
   5) and `skill-meta/SKILL.md`'s Postflight Git Commit block to an explicit per-file list,
   closing the mode-1b commit-bleed hole this task's own creation commit demonstrated live. Not
   created as a task here.
4. **Independently re-evaluate the PATH-shim wrapper for mode 2** on its own merits, regardless of
   the isolation posture — task 119's live evidence shows a plan-sanctioned driver script
   bypassing `lake-build-guard.sh` entirely via a bare `lake` invocation, a gap neither a shared
   tree nor a resurrected worktree closes by itself. Explicitly left to its own task, as both the
   original verdict and this task's own "out of scope" list require.
5. **If this question is ever re-opened a third time**, ground any resurrection proposal in the
   "clone nothing, reuse a content-addressed cache" pattern (Research Question 1) rather than in
   hardlink- or reflink-cloning `.lake/` wholesale, and run the feasibility spike named in Context
   Extension Recommendations first — the CoW/reflink filesystem-availability blocker found here
   will not have changed unless this system's host filesystem does.
6. **If this question is ever re-opened a third time, rescope task 276 before touching it.** Its
   subject is no longer just the `nothing_to_land`/release ancestry-test path — this research
   found a second, distinct route into the same harm class (postflight silently failing to land a
   worktree and marking the task `completed` anyway, apparently on empty `modified_files`). Both
   routes would need a fix before any resurrection could be considered safe, not just the
   originally-ticketed one. This is net-new evidence 276's own eventual un-abandonment would need
   to absorb; it is not acted on here because the layer stays removed and 276's current mechanism
   does not exist to be fixed.

## Research Questions Answered

1. **Is there a mechanism that structurally dissolves the per-writer atomic-rename hazard (the
   gate question)?** Qualified yes-in-principle (reflink/CoW; overlayfs), no-in-practice-today on
   this system (ext4, no mount-management subsystem). The clone-nothing/content-addressed-cache
   pattern is the most promising avenue but is unverified for this system's non-Mathlib Lean
   targets. See "Findings > External Resources" and the reaffirmation record's "The Gate Question,
   Answered" section.
2. **[Already closed per the dispatch — not re-derived.]** Task 119's clean in-worktree commits
   used raw `git`, never `git-commit-scoped.sh`; defect (b) remains open and untested under an
   actual worktree invocation of the sanctioned commit path.
3. **Can build weight be measured instead of inferred from `task_type`?** Yes — nothing in
   `orchestrate-cycle-plan.sh`'s admission path precludes consulting a recorded prior
   duration/job-count or running a cheap probe instead of the static family list; task 129's 6 s/
   17-job build is the concrete counter-example motivating this. Recommended as a 287 revision,
   independent of the isolation question.
4. **How does worktree isolation interact with deferral/wave scheduling when a deferred sibling is
   later dispatched against a tree lacking the unlanded branch work?** Confirmed as a genuine,
   previously unnamed hazard (task 159 vs. 129's unmerged work) — it argues against, not for,
   resurrecting worktrees under the existing wave-deferral design, since a shared tree would not
   have this blind spot.
5. **Must task 276's ABANDON be reversed if the layer returns, and what would the minimal fix
   be?** Not reached in the design sense (the layer does not return under this verdict, so 276
   remains ABANDON, unchanged, per the reaffirmation record's Task Disposition table) — but this
   research found that 276's hazard class is **broader than its original ticket**, independent of
   whether the layer ever returns: the live run's postflight failure (task completed with 28
   commits stranded, uncaught except by hand) is a second route into the same harm 276 was created
   for, reached through silent non-landing rather than destructive release. If this question is
   ever re-opened a third time in favor of resurrection, 276 must be revisited on this broadened
   basis, not just its original `nothing_to_land`-ancestry framing.
6. **Can the Move 2 isolation-forwarding hazard be made structurally impossible rather than
   prose-guarded?** Not designed — moot under CONFIRM, since no dispatch row carries an
   `isolation`/`worktree_path` field at all today. Would need to be answered fresh, structurally,
   if this question is ever re-opened a third time in favor of resurrection.
7. **What is the measured complexity of a minimal resurrection, scored against the removal
   footprint, and does it fit the budget ceilings?** Measured: the ceilings have *less* headroom
   now than at removal time (7 B slack on `SKILL.md`'s 20,000 B ceiling, 548 B on the eager-load
   baseline, both now gated hard), so any resurrection restoring even a short forwarding-prohibition
   paragraph fails the deploy gate outright without first finding equivalent bytes to cut
   elsewhere. No resurrection design was produced to measure further, since the verdict is CONFIRM.
8. **What does current external practice do for worktree orchestration and build-cache sharing?**
   Documented above (Findings > External Resources): worktree-per-agent is a standard
   orchestration pattern; cache sharing is done via a read-only content-addressed store populated
   per-worktree, never a cloned writable build directory — the opposite of this system's
   hardlink-clone-the-whole-`.lake/` approach.
9. **Where would the hard user-approval gate actually run, given `AskUserQuestion` is unreachable
   from a dispatched subagent?** Not designed — moot under CONFIRM; no design requiring approval
   was produced. For the record, the dispatch's own suggested answer (surface to the root session
   rather than prompting from inside a dispatch) is the right shape and is exactly what this
   report's non-blocking `user_decision` field does for the CONFIRM verdict itself.
10. **Does the shared-tree braided-commit cost (122/151) rise to a defect isolation would close,
    or is it covered by `file_scope` serialization plus the contended-path lease?** This report
    did not re-audit 122/151 directly (they live in a different repository and were not
    independently re-verified here beyond what the dispatch already recorded); treating it as a
    real, evidenced cost of the shared tree (agent discipline absorbing mode-1b pressure) is
    reasonable, but it is outweighed by the newly-found facts above (budget exhaustion, mode 2 not
    actually closed, repo-scanning pollution) and does not change the verdict.
11. **Does a resurrected design inherit the HEAD-stale `specs/` derived hazard class, or dispose of
    it?** Not designed — moot under CONFIRM. The hazard class the removal deleted (worktrees
    holding a stale tracked copy of `specs/`, forcing absolute-path artifact writes and a
    merge-back refusal for any branch touching `specs/**`) stays deleted along with the layer.
12. **Generalization check — does a design work unchanged across task types, or drift into a
    per-type carve-out matrix?** Not designed — moot under CONFIRM.
13. **Can worktrees be provisioned outside the repository root to avoid repo-scanning
    pollution?** Evaluated as a structural candidate for the repo-scanning hazard specifically;
    it would require every path-resolving tool in the system (component-count generators, the
    worktree registry itself, anything assuming repo-root-relative paths) to be re-audited for an
    absolute-path assumption, which is itself a fresh instance of the "unrelated script must stay
    disciplined" hazard this verdict exists to avoid. Not adopted, since no resurrection is
    proposed.
14. **Were the deleted `.gitignore` entries ever sufficient?** No — confirmed live (`git
    check-ignore -v` returns no matching rule even before accounting for the deletion's
    consequences), and several of the polluted generator classes do not consult `.gitignore` at
    all regardless of its content. Re-adding the six deleted lines is confirmed a non-answer.
15. **What is the full blast radius of in-repo worktree provisioning on measurement tooling?**
    Confirmed instances: `certificate-export.sh`'s fixture suite, `status-counts.sh`, and
    `typst-component-index.sh` (named directly in the live incident this task captured). A
    complete enumeration across every repo-scanning script in this system
    (`assess-repo-health.sh`, the typst generator suite, `script-reference.sh`, dual-grain
    discovery, the task-reference lint, byte-budget probes) was not performed — it would require
    auditing each script's path-walking logic individually, which is out of proportion to a
    question that is moot once the layer stays removed. Recorded as an open enumeration a future
    re-opening would need to complete, not answered exhaustively here.

## Appendix

### Search Queries Used

- "git worktree orchestration concurrent AI coding agents 2026 isolation best practices"
- "sharing build cache across git worktrees reflink copy-on-write cp --reflink btrfs overlayfs"
- "cargo target directory shared across git worktrees sccache content-addressed cache"
- "Mathlib Lake .lake build cache multiple worktrees parallel lean4 agents"
- "Claude Squad aider multi-agent git worktree tmux isolation build directory"

### Codebase Commands Used (Representative)

- `findmnt -no FSTYPE /`, `df -T <path>` — filesystem identification (ext4 confirmed on both
  repository paths)
- `git worktree list`, `git log --oneline <merge-base>..<tip>`, `git diff --name-only <a> <b>` —
  live worktree/footprint verification in the Verification repository
- `grep -c lake-build-guard <certify.sh>`, line-level grep for `lake build`/`lake env`/`lake
  shake`/`command -v lake` — bare-invocation confirmation
- `git check-ignore -v .orchestrate-worktrees/ specs/.worktree-registry/` — gitignore-sufficiency
  check
- `jq`/`grep` against `orchestrator-context-budget.json`, `orchestrate-cycle-plan.sh` — budget and
  build-weight-proxy verification
- `git show --stat 4dfe7af61` — mode-1b commit-bleed reproduction

### Prior Tasks Audited

`specs/archive/199_concurrent_dispatch_isolation_posture`,
`specs/archive/276_worktree_land_dirty_release_data_loss`, task 286 (completed; cited via the
removal verdict it produced), task 287 (`specs/287_no_coschedule_build_heavy_implement`,
completed), task 288 (`specs/288_remove_dispatch_worktree_isolation_layer`, completed — not yet
archived at time of this research), task 278 (Move 2 isolation-forwarding prohibition; superseded
in effect by the fields' removal), task 277 (`git-commit-scoped.sh` worktree targeting, narrowed),
task 268 (`lake-build-guard` false green, phase 5 remaining), task 165 (absent-`file_scope`
admission posture, promoted), `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`.
