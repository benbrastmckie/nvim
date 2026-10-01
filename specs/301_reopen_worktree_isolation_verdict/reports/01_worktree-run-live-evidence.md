# Research Report: Task #301 — Live Evidence from a Successful Worktree-Isolation Run

**Provenance banner — read first.** This is an **operator-supplied evidence record**, not the
output of this task's own research dispatch. It was written by the `/orchestrate` lead session
that *observed* the run it describes, in a different repository, while the run was still in
flight. A later research dispatch should treat every claim here as **primary observational data
to be verified**, not as a finished verdict, and should advance the artifact sequence past this
file rather than overwrite it. Where this record states a measurement, the command that produced
it is in Appendix A.1 so it can be re-run.

**Sources/Inputs**: a live `/orchestrate 119,122,129,151,154,159` run in
`/home/benjamin/Projects/Logos/Verification`, session `sess_1790826682_ca5834`, spanning
2026-09-30 into 2026-10-01 UTC; that repository's git history; the dispatched agents' own
handoffs and `.return-meta.json` files; `specs/.worktree-registry/`; `specs/events.jsonl`.

---

## Executive Summary

**The worktree isolation layer ran, and its core mechanics worked.** Two of four cycle-1
dispatches provisioned worktrees. Both completed their full plans, both produced footprints
exactly matching their declared scope with zero stray paths, and both branches landed into `main`
via `dispatch-worktree.sh land` with verdict `landed`, zero conflicts and zero refusals. Counting
earlier dispatches in the same repository, the land path has now succeeded **4 times out of 4**
with no recorded refusal or conflict verdict.

**One failure must not be lost in that result.** Postflight did **not** land either worktree. Both
tasks reached status `completed` with **28 commits stranded on unmerged branches**, and
`components/distsys/` — the entire output of one task — was absent from `main`. The lead landed
both by hand only after noticing. Had `/todo` run first, it would have archived tasks whose work
the mainline did not contain.

**The decision this evidence actually frames.** Provisioning, branch isolation and landing are one
thing; lifecycle integration is another, and they failed differently. The mechanics are
restoration-grade. The integration is not, and its failure falls squarely in the hazard class of
**abandoned task 276**. Anyone reading this record as simple support for restoration should read
§F5 and §"What This Evidence Does Not Support" before concluding.

This record does **not** re-open cost. Cost was measured and ruled out by the existing verdict and
is not revisited here.

---

## Why This Evidence Exists At All

The observation was an accident of staleness and is **perishable**.

`/home/benjamin/Projects/Logos/Verification` carries a `.claude/` deploy that is stale for the
`core` and `lean` extensions. It therefore still contains `dispatch-worktree.sh` — present,
executable, 30,411 bytes — even though that file is deleted from the source store at
`agent-system/extensions/core/scripts/dispatch-worktree.sh`. The run below is thus **live
observation of the removed layer in production, recorded after its removal**.

A redeploy of that repository destroys the observation site. Any further measurement anyone wants
from this configuration must be taken before then, or arranged deliberately.

---

## What Ran

Cycle 1 dispatched four implement phases. Cycle 2 dispatched two research phases after the
cycle-1 work landed.

| Task | Isolation | Branch | Agent | Phases | Commits | Footprint |
|---|---|---|---|---|---|---|
| 119 | worktree `119-12` | `orchestrate/task-119-12` | `lean-implementation-agent` | 23/23 | 18 | 34 files, all under `books/**` + `docs/book-convention.md` |
| 129 | worktree `129-14` | `orchestrate/task-129-14` | `lean-implementation-agent` | 10/10 | 10 | 26 files, all under `components/distsys/` |
| 122 | none (shared tree) | — | `typst-implementation-agent` | 16/16 | — | `typst/**`, `docs/`, `.github/workflows/`, plus 2 out-of-scope |
| 151 | none (shared tree) | — | `typst-implementation-agent` | 7/7 | — | `typst/manual/chapters/**`, `typst/chapter-sources.json` |

All four reached postflight verdict `ok`, status `completed`, with no halts and no transport
errors.

---

## Findings

### F1 — Provisioning and branch isolation worked, measured rather than asserted

Both worktrees provisioned without incident and both were **clean** at completion (`git status
--porcelain` empty inside each). Footprints were verified against the common merge base
(`e06ba69`) rather than taken from the agents' own reports:

- Task 129: **26 files, every one under `components/distsys/`**. Zero paths outside its declared
  scope.
- Task 119: **34 files**, all under `books/**` or `docs/book-convention.md`.

Neither branch touched `specs/**`, which matters because `land` refuses any branch that does.

### F2 — The land path worked: 4 of 4, zero conflicts, zero refusals

Both branches landed with verdict `landed`:

- `524ff6b dispatch-worktree.sh land: task 119 (orchestrate/task-119-12)`
- `e5ebba0 dispatch-worktree.sh land: task 129 (orchestrate/task-129-14)`

Two earlier lands in the same repository, same day, also succeeded:

- `2c2e909 dispatch-worktree.sh land: task 118 (orchestrate/task-118-9)`
- `baa3df1 dispatch-worktree.sh land: task 153 (orchestrate/task-153-11)`

`specs/events.jsonl` records **no** `refused_specs_paths`, `refused_dirty_overlap`, `conflict` or
`unavailable` verdict. The refusal gates were pre-checked before landing and were genuinely
satisfied rather than bypassed: neither branch touched `specs/**`, and the main tree's only
dirtiness was `specs/events.jsonl` (append-only telemetry) plus the untracked
`.orchestrate-worktrees/` and `specs/.worktree-registry/` directories — none overlapping either
branch's footprint.

Post-land verification confirmed `components/distsys/lean/lakefile.toml`,
`books/tests/certify/run.sh` and `books/schema/book-cert-v2.md` all present on `main`.

**Note on scope**: `land` merges but does **not** release. Both worktrees remained on disk
afterwards, by documented design (`release` is a separate subcommand).

### F3 — Concurrency was genuinely gained, and the replacement rule now forbids it

This is the strongest pro-restoration observation in the run.

Tasks 119 and 129 are **both `lean4`**, both members of the family the build-heavy predicate
names, and they ran **concurrently**, each in its own worktree, to clean completion.

Task 287's admission rule — the mechanism adopted to close mode 2 when the layer was removed —
**forbids exactly this co-scheduling**. So the replacement buys safety by surrendering throughput
that this run demonstrably achieved without incident. That trade is the crux of the "is it worth
it" question, and it was not framed this way at removal time.

### F4 — The shared-tree counterfactual is visible in the same run

Tasks 122 and 151 ran in the shared tree and **braided 21 commits onto `main`** interleaved with
one another (`task 122 phase 7`, `task 151 phase 6`, `task 122 phase 12`, …). Task 151 reported
having to hand-stage carefully to exclude its siblings' in-flight files.

The existing verdict re-scores mode 1b as "covered by `file_scope` serialization plus the
contended-path lease." In this run that pressure was absorbed by **agent discipline**, not closed
structurally. Task 122 additionally reported two modified files outside its declared `file_scope`
(`typst/manual/name-resolution-whitelist.txt`,
`components/framed_channel/docs/units/stuffed_channel.typ`), the second of which had already drawn
an idle cross-batch overlap advisory against out-of-batch task 144 at pre-dispatch — so that
advisory was well-founded.

### F5 — THE FAILURE: postflight did not land, and tasks reached `completed` with stranded work

**This is the most important finding in this record and the one most adverse to restoration.**

`orchestrate-cycle-postflight.sh` emitted, for both worktree tasks:

```
[postflight] WARNING: no modified_files reported for task #119; source-file changes NOT committed automatically. Review and commit manually.
[postflight] WARNING: no modified_files reported for task #129; source-file changes NOT committed automatically. Review and commit manually.
```

It then marked both tasks `completed` anyway. At that moment:

- `orchestrate/task-119-12` — **18 commits unlanded**
- `orchestrate/task-129-14` — **10 commits unlanded**
- `components/distsys/` — **absent from `main` entirely**

So `specs/state.json` asserted completion of work the mainline did not contain. `/todo` would have
archived both. The work was recovered only because the lead checked `git merge-base --is-ancestor`
for each branch rather than trusting the `completed` status.

The immediate mechanical cause to investigate is **empty `modified_files` in `.return-meta.json`
for a worktree dispatch** — plausibly because the files were modified in the worktree, not the
main tree, and the reporting path did not account for that. That hypothesis is **not verified
here** and is left as work.

**Relationship to abandoned task 276.** 276 (`worktree_land_dirty_release_data_loss`) was
ABANDONED on the rationale that its subject — the `nothing_to_land` → `release` path — ceases to
exist under removal. This run shows a **second, distinct route to the same harm class**: not
destructive release of uncommitted work, but *silent non-landing of committed work under a
`completed` status*. If the layer returns, 276 is live again, and it is live for a broader reason
than its original ticket described.

### F6 — Worktrees polluted unrelated repository-scanning tooling

Task 122 closed **2 of its 16 phases** as `[COMPLETED WITH EXCLUSIONS]` — phase 8 (wiring
`typst-manual-sync-check.sh` as a blocking CI gate) and phase 16 (acceptance). One of the two
cited causes was, in its own words, *"this `/orchestrate` cycle's concurrent sibling worktrees
(tasks 119, 129) inflating some generators' component counts."*

Mechanism, as recorded: `dual-grain discovery` reported `.orchestrate-worktrees/119-12/` and
`129-14/` as **duplicate component roots**, and a tree-wide scan produced `[FAIL]`s sourced
**entirely** from those two directories, with zero outside them. Affected generators:
`certificate-export.sh`'s fixture suite, `status-counts.sh`, `typst-component-index.sh`.

Because `.orchestrate-worktrees/` is provisioned **inside** the repository, repo-scanning tooling
walks the checkouts as first-class content and double-counts. The failure is not a build or commit
error — it **silently corrupts the output of unrelated measurement scripts**, and here it was
severe enough to force two phases of an unrelated sibling task to close with exclusions rather
than clean. Task 122 diagnosed it as transient, expected to resolve once the worktrees are reaped,
which is precisely why it would otherwise leave no durable trace.

**Re-adding the deleted `.gitignore` entries is a non-answer.** Commit `95689dd43` (task 288 phase
8) deleted 6 lines including `/.orchestrate-worktrees/` and `**/.worktree-registry/`. But
`.gitignore` governs git's tracking, not what a `find`/`grep`-based generator walks, and several
of the polluted generators never consult it.

**Structural candidate worth evaluating: provision worktrees outside the repository root.** Costs
to weigh: relative-path assumptions, tooling that resolves from the repo root, and the registry's
own location.

**This hazard is the existing verdict's decisive argument reappearing one level up.** The verdict
made the per-writer argument about mutable state inside a hardlink-cloned `.lake/`; this is the
same "correctness depends on the discipline of unrelated scripts that do not know the layer
exists" shape, at the level of repository tree-walking, which the verdict did not anticipate. It
**strengthens** that argument rather than rebutting it.

### F7 — The build guard was escaped from *inside* a dispatch

Task 119 rebuilt `books/lean` while its own acceptance suite was running; the two collided and
produced a spurious suite failure. Cause, as reported and then verified: `books/scripts/certify.sh`
contains **zero** `lake-build-guard` references and invokes `lake build --wfail`, `lake env` and
`lake shake` straight off `PATH`, guarding only on `command -v lake`.

An adjacent nuance from task 119's own phase-21 handoff: `lake-build-guard.sh`'s `--dir` *"scopes
the LOCK only, not lake's working directory"* — a second way to be inside the guard and still
unprotected.

**This corrects the existing verdict's reasoning.** Its Mode 2 Ruling declined the PATH-shim
wrapper and justified the decline by scoping the residual to *"a bare invocation of the build tool
from outside an orchestration — an operator's own shell, or a script this system does not own,"*
calling that *"a different threat model from in-orchestration contention."* Here a
**plan-sanctioned driver script, inside an orchestrator-scheduled dispatch**, defeated the guard.
The exposure the verdict set aside as out-of-scope reappeared inside the threat model it claimed
was covered.

**It also weakens the strongest pro-restoration argument.** Mode 2 is the one capability the
verdict concedes a shared tree does not inherit for free, which makes it the best remaining case
for bringing worktrees back. If build invocations can escape the guard from inside a dispatch,
per-dispatch build isolation does not reliably contain build contention either — the escaping
invocation is unaware of which tree it should be confined to. The decision should not let the
resurrection case rest on mode 2 without answering this.

### F8 — Defect (b) remains open and untested

The existing verdict's defect (b) holds that `git-commit-scoped.sh` cannot stage inside a worktree
because `PROJECT_ROOT` derives from `BASH_SOURCE[0]` with no `--repo-root`/`--worktree` flag, so
every pathspec falls through WARN-and-drop while the script returns success.

Task 119 committed 18 times from inside its worktree, which initially looked like evidence the
defect is fixed. Asked directly, it reported using **raw `git add -- <explicit file list>` followed
by `git commit`, and never invoking `git-commit-scoped.sh` at all**.

So this run is **no evidence either way**. Defect (b) stays fully priced into any restoration
estimate, and verifying it — actually exercising `git-commit-scoped.sh` from inside a worktree — is
live work. Whether the fix is a `--repo-root`/`--worktree` flag or something structural is also
open.

Separately: routing around the sanctioned path forfeits that path's own guarantees — pathspec
scoping, the contended-path lease, and the `Co-Authored-By`/`Claude-Session` trailers.

### F9 — `task_type` is a poor proxy for build weight

Directly relevant to this task's requirement that any design generalize beyond `lean4` to all task
types, with lean as the hard case.

Task 129 is a **Mathlib-free** Lake package. Its clean build from an empty `.lake/` with the
network blocked measured **6 s wall, 17 jobs**, zero warnings. Yet `lean4` is exactly the family
task 287's admission rule treats as build-heavy and refuses to co-schedule.

"Lean builds are large" is true in general and **false for this instance by three orders of
magnitude of job count**. A design keyed on `task_type` will both over-restrict cheap lean work and
miss expensive non-lean work. Measuring build weight, rather than inferring it from task type, is
the direction this suggests — and it is a candidate revision to task 287 independent of the
isolation posture.

---

## The Recurring Shape: Six Instances in One Run

In every case below the guard did not fail. **It was never consulted.**

| # | Instance | Mechanism that existed but did not run |
|---|---|---|
| 1 | Absent `file_scope` (historical, the verdict's own finding) | cross-task overlap check |
| 2 | Commit site passed `-- specs/` and omitted `--task` | `git-commit-scoped.sh`'s contended-path lease |
| 3 | Repo-scanning generators walk worktree checkouts | `.gitignore` (never consulted by those generators) |
| 4 | `certify.sh` calls bare `lake` off `PATH` | `lake-build-guard.sh` |
| 5 | Task 119 used raw `git`, bypassing the sanctioned path | `git-commit-scoped.sh` entirely |
| 6 | Empty `modified_files` → postflight never landed | the land/commit path in postflight |

**The verdict's decisive argument therefore generalizes further than the verdict stated it.** The
pattern is not specific to mutable state inside a hardlink-cloned build directory; it is a
property of any mechanism that depends on callers opting in.

Two consequences point in opposite directions, and both belong in the decision:

- **For the PATH shim** (currently declined): it is the only mechanism in play that closes a
  "never consulted" hazard **by construction** rather than by discipline, precisely because a shim
  on `PATH` intercepts the bare call *on account of* the caller's unawareness. It deserves
  re-evaluation on its own merits, **independent of whether isolation returns** — which makes it a
  possible *alternative* to resurrection, not only a complement.
- **Against reading instances 2 and 5 as pro-isolation**: isolation would have prevented the
  commit bleed structurally, but so does an explicit file list, at a fraction of the complexity and
  without resurrecting anything. Note that instances 2 and 5 are the same problem from opposite
  sides — one dispatch was harmed by *using* the sanctioned commit path, another by *avoiding* it.

---

## What This Evidence Supports

1. **The provisioning, branch-isolation and landing mechanics are restoration-grade.** 4/4 lands,
   zero conflicts, zero refusals, clean worktrees, footprints exactly as declared.
2. **The concurrency gain is real and is currently forbidden.** Two build-heavy `lean4` tasks ran
   simultaneously to clean completion; task 287's rule now rules that out.
3. **The shared tree's costs are observed rather than theoretical** — 21 braided commits, hand-staging
   to avoid siblings, two out-of-scope modified files.

## What This Evidence Does Not Support

1. **Unconditional restoration.** Lifecycle integration failed in the hazard class of abandoned
   task 276 (§F5), by a route that ticket did not describe.
2. **A reduced cost estimate.** Defect (b) is untested (§F8), and §F6 is a hazard class the removal
   verdict never considered.
3. **Resting the case on mode 2.** §F7 shows worktrees do not fully close build contention either,
   and mode 2 is the strongest remaining pro-restoration argument — so this undercuts the case at
   its strongest point, not a peripheral one.
4. **Anything about cost.** Not re-opened; the existing measurements stand.

---

## Recommendations for the Research and Decision Phase

1. **Decide provisioning/landing and lifecycle integration separately.** This run passed the first
   and failed the second. Treating them as one verdict discards the actual signal.
2. **Make §F5 a blocking prerequisite of any restoration.** A dispatch that reaches `completed`
   with unlanded commits is a correctness failure, not an inconvenience. Reproduce it, find why
   `modified_files` is empty for a worktree dispatch, and fix it before anything else.
3. **Evaluate provisioning outside the repository root** as the structural answer to §F6, costing
   the relative-path, root-resolution and registry-location consequences.
4. **Re-evaluate the PATH shim independently of the posture** (§F7), as the only candidate that
   closes a "never consulted" hazard by construction.
5. **Replace `task_type` build-weight inference with measurement** (§F9), as a candidate revision to
   task 287 regardless of the isolation decision.
6. **Price defect (b) as untested** (§F8) and verify it by actually exercising
   `git-commit-scoped.sh` from inside a worktree.
7. **Revisit task 276's ABANDON** — it is the safety-critical one, and §F5 broadens rather than
   narrows its subject.
8. **Take any further measurement from the stale deploy before it is redeployed**, or the
   observation site is gone.

---

## Appendix

### A.1 Verification commands used

```bash
# Stale-deploy framing fact (observation site still carries the removed layer)
ls -la .claude/scripts/dispatch-worktree.sh                  # present, 30,411 bytes
ls -la <source_store>/scripts/dispatch-worktree.sh           # absent

# Worktrees and branches
git worktree list
git merge-base --is-ancestor orchestrate/task-119-12 main    # before land: false
git rev-list --count main..orchestrate/task-119-12           # 18
git rev-list --count main..orchestrate/task-129-14           # 10

# True footprints, from the merge base (NOT a two-dot diff, which mixes in main's own movement)
git diff --name-only e06ba69 orchestrate/task-129-14 | wc -l # 26
git diff --name-only e06ba69 orchestrate/task-129-14 | awk -F/ '{print $1"/"$2}' | sort -u
git diff --name-only e06ba69 orchestrate/task-119-12 | wc -l # 34

# Land refusal gates, pre-checked
git diff --name-only $(git merge-base main <branch>) <branch> -- 'specs/*'   # empty, both
git status --porcelain                                       # only events.jsonl + untracked worktrees

# Landing
bash .claude/scripts/dispatch-worktree.sh land 119 --session sess_1790826682_ca5834
bash .claude/scripts/dispatch-worktree.sh land 129 --session sess_1790826682_ca5834

# Historical land record
git log --oneline --all --grep="dispatch-worktree.sh land"   # 4 commits, all 2026-09-30

# Post-land presence on main
git cat-file -e main:components/distsys/lean/lakefile.toml
git cat-file -e main:books/tests/certify/run.sh
git cat-file -e main:books/schema/book-cert-v2.md

# Build weight (reported by the dispatch, from an empty .lake/ with network blocked)
# task 129: 6 s wall, 17 jobs, zero warnings
```

### A.2 References

- `specs/decisions/worktree-isolation-removal-verdict.md` — the verdict this task re-opens.
  §F6 and §F7 are corrections to its reasoning; §F3 and §F4 are new trade data; §F5 is adverse to
  restoration.
- `specs/archive/199_concurrent_dispatch_isolation_posture` — built the layer.
- `specs/archive/276_worktree_land_dirty_release_data_loss` — ABANDONED; §F5 reopens its subject
  by a different route.
- Task 277 — `git-commit-scoped.sh` unresolvable-pathspec hard error (narrowed; part (a), worktree
  targeting, becomes live again if the layer returns).
- Task 278 — forbids forwarding the Agent tool `isolation` parameter. Honored in this run only by
  Move 2's prose; see the note below.
- Task 287 — the build-heavy co-scheduling admission rule that replaced mode 2. §F3 and §F9 bear
  directly on it.
- Task 288 — the removal; its phase 8 deleted the `.gitignore` entries discussed in §F6.
- Commits in the observed repository: `524ff6b`, `e5ebba0` (lands); `2c2e909`, `baa3df1` (earlier
  lands); `95689dd43` in the source store (the `.gitignore` deletion).

### A.3 One hazard avoided only by prose, worth hardening

The dispatch rows carried `isolation: "worktree"` and `worktree_path`, which merely **record** an
already-provisioned checkout. Forwarding them to the Agent tool's own `isolation` parameter would
be syntactically valid — its enum includes `"worktree"` — and would raise no error, while stacking
a **second** harness checkout. The harness then refuses all cross-checkout git by design while
still permitting file writes and build runs, so a dispatched agent authors and verifies its work
green and then cannot commit it. Recorded cost in an earlier production run: 20 of a dispatch's 21
phases.

In this run the hazard was avoided **only because `skill-orchestrate`'s Move 2 prose forbids the
forwarding**. A restored design should make it structurally impossible rather than
prose-guarded — this is the same "never consulted" shape as the six instances above, one step
before it fires.
