# Decision Record: Per-Dispatch Working-Tree Isolation — Removal Reaffirmed

**Disposition: CONFIRMS** `specs/decisions/worktree-isolation-removal-verdict.md` (the "removal
verdict"). Per-dispatch `git worktree` isolation stays removed. This record does not replace the
removal verdict — it is cited, not restated, and remains the authoritative statement of the
three-defect table, the cost measurements, and the structural ("per-writer atomic rename") finding.
This record exists because task 301 was dispatched specifically to re-open that verdict under new
evidence (live production observation of the layer still running in a stale deploy, plus targeted
external research into CoW/reflink alternatives) and is required to terminate formally, one way or
the other. It terminates CONFIRMING.

Full evidentiary basis: `specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`
(task 301's research report). This record states the verdict and its load-bearing reasons only;
the report carries the full audit trail, external-research citations, and point-by-point answers
to all fifteen research questions task 301 carried.

## The Gate Question, Answered

The removal verdict's decisive structural argument was: hardlink-clone correctness depends on
"independently rebindable via atomic rename," which is a **per-writer** property, not a property
of the clone, so a layer built on it cannot be audited once and trusted — every script with
mutable per-invocation state inside the cloned tree is a fresh instance of the hazard, closed only
by a hand-maintained exclusion list. Task 301's mandate was to find out whether any mechanism
dissolves this structurally. Three were evaluated:

1. **CoW/reflink cloning** (`cp --reflink`, `git worktree add --reflink`, buck2-style CAS
   restores). This is real, current practice (`git-cow`, `casd`) and **would** dissolve the
   per-writer hazard structurally — a reflinked file is never shared storage; a write
   copy-on-writes a private block range regardless of whether the writer renames or truncates in
   place. **It does not apply here.** This host's and the Verification repo's root filesystem is
   `ext4` (`findmnt -no FSTYPE /` → `ext4`; `df -T` confirms both repos' working trees sit on the
   same `ext4` partition, 93% full). `ext4` has no `FICLONE`/reflink support. Reflink cloning is
   unavailable without a filesystem migration (btrfs, XFS with `reflink=1`, bcachefs, or ZFS
   2.2+), which is an infrastructure change several orders of magnitude outside this task's scope
   and outside any resurrection design's reasonable footprint.
2. **Overlayfs** (upper/lower copy-up, running atop the existing `ext4`). This is the one
   candidate that is structurally correct *and* available without a filesystem migration: the
   first write to any lower-layer file triggers a whole-file copy-up into the worktree's private
   upper directory before the write lands, so a truncate-in-place writer never touches the shared
   storage — correctness stops depending on the writer's discipline. It was evaluated and is
   **not adopted**, for reasons the report details: it requires privileged or user-namespace mount
   management per worktree (a new class of infrastructure this system has never needed), stale-
   mount cleanup on crash is itself a fresh instance of the "unrelated script doesn't know this
   exists" hazard this verdict exists to avoid, and it does nothing for the second, newly-found
   hazard class (repo-scanning pollution — see below), which concerns the worktree *appearing in
   the tree walk*, not what happens when a lower-layer file is written.
3. **Do not clone the build directory at all** (surfaced by this task's external research, and the
   single most useful finding it produced). The practice the Lean/Mathlib ecosystem and
   comparable toolchains (sccache for Rust, pnpm's content-addressed store) actually converge on
   is: never share or clone a *writable* build directory between concurrent builders; share only a
   read-only, content-addressed artifact store, and let each builder populate its own private
   build directory from it (`lake exe cache get`'s shared `.cache`/tar-keyed oelean store is this
   exact pattern already built into Lake). Applied to this system, a worktree would get a fresh,
   never-cloned `.lake/`, `lake-build-guard.sh`'s own state files would be genuinely per-tree by
   construction (no shared inode, no exclusion list needed), and the per-writer hazard does not
   arise because there is no clone to reason about. This is real and it is the most decision-
   relevant finding in the whole research pass — but it is not, by itself, a worked resurrection
   design: whether it is affordable depends on whether a non-Mathlib Lean target in this system
   (e.g. `components/distsys`) has anything resembling Mathlib's shared oelean cache to fall back
   on for the dependency tier, which this report did not verify and flags as the one open question
   that would need its own feasibility spike before this path could ground a resurrection.

**Verdict on the gate**: the answer to "is there a mechanism that structurally dissolves the
per-writer hazard" is a qualified **yes, in principle** (overlayfs, or clone-nothing-and-reuse-a-
content-store), but **no, as a drop-in fix available to this system today** — one candidate needs
infrastructure (a filesystem or a mount-management subsystem) this system does not have and would
have to build and operate, and the other needs a feasibility spike this task did not run. Per the
removal verdict's own framing ("if the only available answer is a promise of more discipline or a
longer hand-maintained exclusion list, that is strong evidence for leaving the layer removed"),
a *theoretically* dissolving mechanism that is not actually available to deploy is not a basis for
resurrection now. This alone would not be sufficient to re-confirm removal if every other
consideration favored resurrection; it is not alone — see the next section.

## Everything Else the New Evidence Found Also Points the Same Direction

- **A fourth defect, the single most adverse-to-resurrection fact this research produced: postflight
  did not land either worktree, and both tasks were marked `completed` anyway.** This task's own
  round-1 artifact (`reports/01_worktree-run-live-evidence.md`, an operator-supplied record of the
  same live run) documents `orchestrate-cycle-postflight.sh` warning that no `modified_files` were
  reported for tasks 119/129 and then setting both to `completed` regardless, with 18 and 10
  commits respectively stranded on unmerged branches and task 129's entire output
  (`components/distsys/`) absent from `main` at that moment. This report independently
  re-verified the recovery: the four `dispatch-worktree.sh land` commits the record names
  (`e5ebba0`, `524ff6b`, `baa3df1`, `2c2e909`) exist, and the files they bring in are confirmed
  present on `main` — but only because the orchestrating session noticed and landed both branches
  by hand after the fact; the automated path inside postflight did not. This is a second, distinct
  route into exactly the harm class task 276 was abandoned for — not destructive release of
  uncommitted work, but silent non-landing of committed work under a `completed` status — and it
  broadens 276's hazard class beyond its original `nothing_to_land`-ancestry framing. Had `/todo`
  run before the lead noticed, it would have archived both tasks while the mainline did not
  contain their work.
- **The budget headroom the removal bought is already gone, and the gate guarding it is now
  hard, not warn.** The removal's own footprint table recorded `skill-orchestrate/SKILL.md` at
  1,317 B over ceiling and eager context at 2,030 B over baseline as the headroom it relieved.
  As of this task's research (2026-10-01), `SKILL.md` measures 19,993 B against a 20,000 B
  ceiling (7 B of slack) and eager load measures 65,402 B against a 65,950 B baseline (548 B of
  slack) — both consumed by unrelated, legitimate growth since the removal, and
  `ORCHESTRATOR_BUDGET_GATE_MODE` was promoted from `warn` to `hard` the same day. Requirement 3's
  "fit inside the ceiling… or say what is given back" is no longer a comfortable margin question;
  it is now a hard-blocking gate with single-digit bytes of slack. Any resurrection that restores
  even the previously-removed Move 2 forwarding-prohibition paragraph (now fully absent — grep
  confirms zero occurrences of "isolation" in `skill-orchestrate/SKILL.md`) fails the deploy gate
  outright unless it finds equivalent bytes to cut elsewhere first.
- **Mode 2's worktree-exclusive capability is not actually exclusive.** The live evidence (task
  119, running inside a provisioned worktree under the still-deployed old code) shows the book
  driver script `certify.sh` invoking `lake build`/`lake env`/`lake shake` as bare commands,
  verified with zero references to `lake-build-guard` anywhere in the file. The guard was never
  consulted. Per-dispatch worktree isolation does not reliably close build contention either, when
  a plan-sanctioned driver script is unaware the guard exists — the identical "correctness depends
  on a caller that doesn't know the mechanism exists" shape the removal verdict already names as
  decisive, recurring a fifth time in the same observed run (alongside: absent `file_scope`, the
  unfired lock heartbeat, repo-scanning tools never consulting `.gitignore`, and task 119's own
  in-worktree commits reaching for raw `git` instead of `git-commit-scoped.sh`). This weakens the
  strongest remaining pro-resurrection argument (worktrees as the one capability a shared tree
  does not inherit for free): they do not fully deliver it either.
- **A second hazard class, not named in the original verdict, generalizes its own argument one
  level up.** In-repo worktree provisioning (`.orchestrate-worktrees/` living inside the repo
  root) causes repo-wide tree-walking tools — component-count generators, health probes, any
  `find`/`grep`/`git ls-files`-based inventory script — to double-count sibling checkouts as
  first-class repository content. This is independently confirmed: `git check-ignore -v
  .orchestrate-worktrees/` returns no matching rule in the live Verification repo (the removal
  deleted the relevant `.gitignore` lines), and several of the polluted generator classes named in
  the live incident do not consult `.gitignore` at all regardless. Re-adding the `.gitignore`
  lines is not a fix for this class of tool. A resurrected design would have to answer this for
  every repo-scanning tool in the system, not only for build-directory writers — the same
  "cannot audit once and trust" shape, recurring at the filesystem-tree-walk layer instead of the
  build-directory layer.
- **Mode 1b (commit bleed) is not as fully covered as the removal verdict re-scored it, but the
  fix available does not need worktrees.** This task's own creation commit
  (`4dfe7af61`) swept four files belonging to two other concurrently-live sessions into its commit
  because `git-commit-scoped.sh` was invoked with the directory pathspec `-- specs/` — the
  literal, prescribed convention in both `meta-builder-agent.md` (Stage 6 step 5) and
  `skill-meta/SKILL.md`'s Postflight Git Commit block. The bleed happens at the pathspec layer,
  below where `file_scope` declarations or the contended-path lease can act, so neither mechanism
  prevents it. The fix — an explicit file list instead of a directory pathspec, which this task's
  own later commits already used and which swept nothing — is strictly narrower than resurrecting
  worktree isolation and closes the same hole completely for this call path. This is recorded as a
  genuine, evidenced convention defect worth its own narrow follow-up task, not as an argument for
  resurrection.
- **`task_type` is confirmed a poor proxy for build weight, independent of the isolation
  question.** Task 129, in the `lean4` family that task 287's admission rule refuses to
  co-schedule, built from an empty `.lake/` with the network blocked in 6 seconds and 17 jobs
  (verified: `BUILD_HEAVY_TASK_TYPES=("lean4" "cslib")` in `orchestrate-cycle-plan.sh` is a static
  family list, not a measurement). This is a real refinement opportunity, but it is a 287 revision
  either way the isolation question is decided, not a reason to decide it one way.
- **Deferral-interacting invisibility is real but orthogonal.** A worktree holding unlanded branch
  work is invisible to a sibling dispatched in a later wave against the shared tree (task 159 vs.
  129's unmerged `components/distsys/README.md` work) — a genuine new hazard class the removal
  verdict did not name, recorded here for completeness, but it argues against resurrecting
  worktrees under wave deferral, not for it.

## What Remains True From the Removal Verdict, Unchanged

- Cost is still not the reason (confirmed again: `git worktree add` and hardlink-cloning remain
  cheap; the objection this record and the original both refuse is cost, not the structural and
  reliability ones).
- The original three defects (destructive release on `nothing_to_land`, `git-commit-scoped.sh`'s
  worktree-blind `PROJECT_ROOT`, `lake-build-guard.sh`'s shared-inode false green) remain exactly
  as recorded; none was re-tested as fixed (defect (b) in particular remains explicitly **open and
  untested** under a worktree — task 119's clean in-worktree commits used raw `git`, never
  `git-commit-scoped.sh`, so they are no evidence either way). A **fourth** defect was found by
  this research pass (postflight non-landing under a `completed` status — see above); the running
  count of layer-induced defects is now four, not three.
- Mode 1a (working-tree revert) remains dormant and closed by `git-snapshot.sh`'s existing
  fail-closed behavior, independent of isolation.
- The five contention inputs (auto-dependency edges, wave/cycle-split check, held-lock scan,
  state.json collision scan, session registry) remain the sole concurrency-safety mechanism, and
  nothing in this reaffirmation changes that.

## Task Disposition (Confirmatory, Narrower Than a Resurrection Would Require)

| Item | Disposition |
|---|---|
| Task 287 (`no_coschedule_build_heavy_implement`) | **REVISE** (own follow-up task, outside this task's scope to create per the dispatch's "out of scope" list, but recorded as the clearest concrete improvement this research supports): move from a static `task_type` family list to a measured-or-probed build-weight signal (recorded prior job count/duration per task, consulted at admission time), so a Mathlib-free `lean4` task like 129 is not categorically refused co-scheduling. |
| Task 165 (absent-`file_scope` admission posture) | **REMAINS PROMOTED**, unchanged. Isolation staying removed does not alter its scoring. |
| Task 276 (`nothing_to_land`/release data loss) | **REMAINS ABANDONED**, unchanged — its subject does not exist under a shared tree. Note for any future re-opening: its hazard class is now known to be broader than its original ticket (see the postflight-non-landing finding above), not narrower. |
| Task 277 (`git-commit-scoped.sh` worktree targeting) | **REMAINS NARROWED to part (b) only** (unresolvable pathspec → hard error instead of silent WARN-and-drop), unchanged. |
| Task 268 (`lake-build-guard` false green, phase 5 remaining) | **UNCHANGED** — finish phase 5; no re-scoping needed. |
| `meta-builder-agent.md` / `skill-meta/SKILL.md` postflight commit pathspec | **NEW finding, recommend a narrow follow-up task**: replace the prescribed `-- specs/` directory pathspec with an explicit per-file list, per the live mode-1b bleed evidence above. Not created here (task creation is outside this dispatch's charter). |
| PATH-shim wrapper for mode 2 | **Independent re-evaluation recommended**, on its own merits, regardless of this verdict — task 119's live evidence shows a plan-sanctioned driver script bypassing `lake-build-guard.sh` entirely via a bare `lake` invocation, reachable under either posture. Deciding this is explicitly left to its own task per the removal verdict's own scope boundary and this dispatch's "out of scope" list. |
| `batch-orchestration-guardrails.md`'s isolation section | Recommend appending the repo-scanning-pollution hazard class and the Lake-cache-not-clone finding as retained history/reference, alongside the existing three-failure-mode taxonomy — not required by this record, offered as a context-extension recommendation in the accompanying research report. |

## Scope Boundary Honored

This record decides only the re-opened isolation-posture question. It does not create any
implementation task, does not decide the `MAX_TASKS` cap, the PATH-shim wrapper, or any
state-schema field ruling, and does not modify any orchestration script. Those remain, as before,
each its own task.

## Provenance

- Task 301, research dispatch, session `sess_1790872161_63b5e7_301`, 2026-10-01.
- Full evidentiary report: `specs/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`.
- Original record (cited, not superseded): `specs/decisions/worktree-isolation-removal-verdict.md`.
