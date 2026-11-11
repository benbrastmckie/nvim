# Git Staging Scope Contract

## Overview

This standard defines the operation-type commit-scope contract for the single-agent commit
pipeline (the research, plan, and implement dispatches). It replaces repo-wide `git add -A` staging with
targeted, work-scoped staging so every commit contains only the files the operation actually
produced — never a concurrent session's stray edits.

This is the canonical authority referenced by `orchestrator-postflight.sh`, `skill-orchestrate`,
`general-implementation-agent`, `git-workflow.md`, and `skill-git-workflow`.

## Canonical Runtime-File Exclusion Set

Every task-directory `git add` in this contract considers the same fixed set of ephemeral runtime
files for exclusion, via git exclusion pathspecs (`:(exclude)...`) rather than an allowlist — an
allowlist would also silently drop legitimate durable content that live task directories carry
(`progress/`, `handoffs/`, `fixtures/`, `tests/`, `HANDOFF.md`), trading one silent-drop bug for
another. Exclusion pathspecs instead subtract exactly the ephemeral classes and nothing else. See
`context/standards/orchestrator-runtime-files.md` for the full two-class policy and the rationale
(freshness-gate asymmetry) behind which files these are:

```bash
task_dir="specs/${padded_num}_${project_name}"
ephemeral_excludes=(
  ":(exclude)${task_dir}/.orchestrator-loop-guard"
  ":(exclude)${task_dir}/.orchestrator-churn-state.json"
  ":(exclude)${task_dir}/.drift-inspection.json"
  ":(exclude)${task_dir}/.lock/"
  ":(exclude)${task_dir}/.dispatch/"
)
```

**This is a CANDIDATE array, not an unconditionally-injected one.** Naming a path already covered
by `.gitignore` in an explicit `:(exclude)...` pathspec entry makes `git add` treat it as an
EXPLICITLY-NAMED ignored path and refuse the WHOLE add ("The following paths are ignored by one
of your .gitignore files") whenever that path currently exists on disk — a held task lock's
`.lock/` directory is the case that surfaces this in practice, but all four candidates reproduce
the identical abort if present and gitignored. An ignored path swept up IMPLICITLY by a bare
directory pathspec (no exclude entry naming it) is, by contrast, silently skipped by `git add`
with no error — gitignore coverage alone is already sufficient to keep it out. `git-commit-scoped.sh`,
the sanctioned implementation of this contract (see "Commit-Level Path Scoping and Cross-Process
Serialization" below), therefore injects each candidate as an explicit `:(exclude)...` entry only
when `git check-ignore -q` reports it is NOT already covered by `.gitignore`. In a repo that has
applied the full ephemeral `.gitignore` block (including this one), the post-injection pathspec
list carries **zero** of these four entries — exclusion is delivered by `.gitignore` alone. In an
under-configured consumer repo lacking that block, all four candidates are injected verbatim,
identical to this contract's pre-conditional behavior. See
`context/standards/orchestrator-runtime-files.md`'s "This gitignore coverage is the primary,
sufficient control" statement — this conditional-injection behavior is the mechanical expression
of that already-settled position: gitignore coverage is primary, this exclusion set is
defense-in-depth for a repo that has not yet applied it, not the primary control itself.

**`.orchestrator-handoff.json` and `.return-meta.json` are deliberately NOT in this set.** They
are durable provenance under the settled policy in `orchestrator-runtime-files.md` — staging them
is intended, not an oversight to fix later.

Every scope below extends this same array rather than re-deriving its own exclusion list —
extend it here once if a future audit adopts another ephemeral class.

## Positive-Pathspec Ignore-Advisory Hazard (the `:(exclude)`-side passage's sibling)

The hazard above is about an EXCLUDE entry naming an already-gitignored path. There is a
distinct, sibling hazard on the POSITIVE-pathspec side: a path that is **tracked**, but whose
path matches a `.gitignore` rule via a parent-directory pattern (e.g. a tracked
`specs/archive/state.json` under a `specs/archive/` ignore rule). Naming such a path as an
ordinary positive pathspec draws the same "ignored by one of your .gitignore files" advisory and
the same nonzero `git add` exit — but unlike the exclude-entry case, the add does **not**
genuinely fail: the file is staged correctly. Trusting `git add`'s exit code here is a false
negative, not a hard failure, and the two cases must not be treated as the same defect.

**`git check-ignore -q` MUST NOT be used to detect this case.** It is index-aware and reports
"not ignored" (exit 1) for exactly these already-tracked paths — directly contradicting `git
add`'s own advisory on the same path. Only `git check-ignore -v --no-index` agrees with `git
add`'s view, and even that is unnecessary: the sanctioned implementation (`git-commit-scoped.sh`'s
V7 gate, documented in that script's own header) does not pre-check at all. It captures `git add`'s
output and exit code without branching on them, then verifies ACTUAL POST-ADD INDEX STATE per
positive pathspec (`git ls-files --error-unmatch` plus a `git diff --quiet` residual check) —
tolerating the advisory false negative while still refusing a genuine failure (e.g. the
out-of-repo-pathspec hard failure, which stages nothing and must keep refusing).

**Index presence is NOT the universal success signal, and the gate does not treat it as one.**
A positive pathspec whose every tracked file `git add` just staged as DELETED is correctly ABSENT
from `git ls-files` afterwards, so an index-presence requirement alone would refuse a commit whose
index is already exactly right. The vacated source half of a directory move has precisely this
shape — which is why requiring presence unconditionally made the gate refuse the very
both-endpoints pattern "Rename and Directory-Move Staging" below mandates, and refuse a pure
directory deletion identically. The gate therefore also accepts a pathspec that is absent from the
working tree, resolvable against HEAD, and reported by `git diff --cached HEAD -- <path>` as
exiting EXACTLY 1 (a staged change exists). Reading that exit code exactly is load-bearing: exit 0
means nothing was staged there (a genuine drop) and anything above 1 is a git error — notably the
128 of an out-of-repo pathspec — so both keep refusing, and a boolean `! git diff ...` test would
wrongly accept the error case. Callers need do nothing to opt in; the correct staging pattern is
simply no longer refused.

**Tracked-vs-moved distinction, by mechanism**: this hazard applies only to a path that is
ALREADY TRACKED when the ignore rule first matches it. A file relocated by a plain `mv` into an
ignore-matched destination is, at that destination, a BRAND-NEW UNTRACKED path — `git add`
genuinely drops it, with nothing staged, because there is no existing index entry for `git
ls-files --error-unmatch` to find. The V7 post-add verification above correctly refuses this
case rather than tolerating it. "Rename and Directory-Move Staging" below describes the
pairing obligation for a move's two endpoints; a caller moving a file INTO an ignore-matched
directory needs its own destination-ignored guard on top of that pairing — this contract's V7
tolerance does not and cannot substitute for one.

**`git add -f` / `--ignore-errors` is not the sanctioned remedy.** Either would also force-stage
a genuinely untracked, genuinely-should-stay-ignored path — the exact over-staging this contract
exists to prevent, trading a false-negative bug for a silent-ignore-bypass one.

## Per-Operation Scope

### `research`

No commit is created. `do_git_commit=false` for the `research` operation type in
`orchestrator-postflight.sh`. This is unchanged by this contract — research was already safe.

### `plan`

Stage:

```
specs/{padded}_{slug}/ "${ephemeral_excludes[@]}"
specs/TODO.md
specs/state.json
```

No dependency on agent self-report — the plan operation only ever touches files under the task
directory plus the two shared index files. The exclusion pathspecs above still apply: a plan
dispatch can run inside an in-flight `/orchestrate` loop and must not sweep in the loop guard,
churn state, drift-inspection scratch file, or a `.lock/` directory.

### `implement`

Stage the `plan` scope above (task directory with the same exclusions), PLUS:

```
{plan_path}                      # the plan file itself (may have phase status edits)
{each entry of modified_files}   # agent self-reported source files touched (see below)
```

`modified_files` is an optional `string[]` field in the agent's `.return-meta.json` (see
`.claude/context/formats/return-metadata-file.md`). It is populated by
`general-implementation-agent` (and other implementation agents) as they `Write`/`Edit` files
during execution — see `.claude/context/formats/progress-file.md`'s `files_touched` field for the
per-objective accumulation mechanism that feeds it.

**Sanctioned per-phase implementation: `git-commit-phase.sh`.** For a mid-dispatch PHASE commit
specifically (as opposed to the final whole-task completion commit this section otherwise
describes), `agent-system/extensions/core/scripts/git-commit-phase.sh` is the canonical
implementation of the pattern above — it derives the `files_touched`-based stage list from the
phase's own progress file instead of a hand-typed `stage_paths` array, performs the Phase-Commit
Containment Self-Check mechanically, and invokes `git-commit-scoped.sh` (below) unpiped
internally. See its own header for the full argument interface and exit-code mapping, and
`agents/general-implementation-agent.md`'s Stage 4B-iii and Phase Checkpoint Protocol for both
call sites. This mirrors how `git-commit-scoped.sh` is already the canonical implementation for
the base commit pattern this section documents — the wrapper sits one layer above it for the
phase-commit case specifically, never replacing it.

**A plan phase closes with exactly one commit.** That phase's wrap-up provenance — the
phase-heading marker promotion, the progress file, the post-phase self-review annotations, and
the phase-end handoff under `handoffs/` — is written *before* that commit fires and rides inside
it. A trailing, provenance-only commit issued after the phase's closing commit has already fired
is not sanctioned; there is no second commit per phase.

This is safe because the phase-end handoff is ordinary durable task content with no freshness
consumer: no script anywhere in this source store reads a `handoffs/phase-{P}-handoff-*.md` file
to gate staleness or identity. Contrast `.orchestrator-handoff.json` (singular, one per task
directory), whose mtime-and-`dispatch_seq` freshness gate in `orchestrate-cycle-postflight.sh` is
a function of filesystem mtime and an embedded content field — neither of which depends on which
commit a file landed in. The phase-end handoff's own filename additionally embeds a UTC
timestamp (`phase-{P}-handoff-{YYYYMMDD}T{HHMM}Z.md`), so any filename-derived freshness signal
survives being staged into the work commit unchanged.

The crash-between-commits argument — that folding turns a two-commit loss window into a
one-commit one — is acknowledged and does not outweigh the fold. A crash before the single
folded commit loses only that phase's wrap-up bookkeeping (marker promotion, progress file,
self-review annotations, handoff); the phase's substantive work is already protected by the
mandatory per-objective green-substep commits (`task {N} phase {P}.{O}: {objective_description}`)
that land throughout the phase, well before the closing commit. A crash loses re-doable
bookkeeping, not work, and the smaller steady-state commit count is preferred over that bounded
loss window.

This does not widen staging scope: `handoffs/` already lies inside `specs/{padded}_{slug}/`, the
same task-directory pathspec the `implement` scope above already stages, and this document's own
"Canonical Runtime-File Exclusion Set" already treats `handoffs/` as durable content the
exclusion design deliberately does not drop. See `context/contracts/phase-closure.md`'s "Marker/
commit synchrony is bidirectional" section for the companion half of this same principle (the
heading marker's own promotion-on-commit requirement).

### Phase Commit (mid-dispatch)

This subsection records an asymmetry that a prior implementation effort's own research surfaced
and left as an explicitly named, open specification until the V10 gate (see "Exit-Code Contract
and Safety Gates" below) landed to close it: a phase commit fires **mid-dispatch**,
inside an already-running implementation agent, not at a command's postflight boundary. Two
structural facts distinguish this surface from the whole-task completion commit the rest of this
document otherwise describes:

- **No postflight is in scope.** The per-cycle postflight-sited Containment filter
  (`orchestrate-cycle-postflight.sh`'s WORK (h)/(i), described in "Staging-Layer Containment
  Filter" above) runs only at a command's own postflight boundary, once per task per cycle. A
  mid-dispatch phase commit never reaches that boundary at all — the dispatch is still running
  when the commit fires — so a guard sited there structurally cannot protect this surface, no
  matter how it is tuned.
- **No guaranteed-current contention manifest.** The cycle-scoped contended-path manifest V5
  consults (`specs/.contention-manifest/*.json`) is built once per `/orchestrate` cycle at that
  cycle's own planning stage. A long-running phase commit has no guarantee the manifest still
  exists, or still reflects the current cycle, by the time it fires — unlike a postflight commit,
  which runs at a point in the cycle where the manifest is known to be fresh.

Because of both facts, any guard for this surface must be sited either in the recipe itself (the
Phase-Commit Containment Self-Check inside `git-commit-phase.sh`, landed as an earlier,
interim measure — see "Staging-Layer Containment Filter"'s "Three Containment sites" paragraph
above) or inside `git-commit-scoped.sh` itself, which every phase commit already reaches
regardless of manifest freshness or postflight timing. V10 is that second, durable answer: it
runs inside the ONE script every phase commit (and every other `--task`-supplying caller)
already invokes, so it needs no fresh manifest and no postflight boundary to reach the surface
the recipe-level self-check alone could not structurally guarantee coverage for. See the "Three
Containment sites" paragraph above for how the two mechanisms now relate (site 3 subsumes site
2's reach going forward; site 2 is kept as a redundant, non-load-bearing belt-and-suspenders
check, not removed).

### Concurrency Qualifier: Targeted Staging Is Necessary But Not Sufficient

Everything above (explicit whole-path staging, never a directory or glob pathspec) remains the
sanctioned staging form and remains **fully sufficient against over-broad staging** — nothing
here widens or narrows that predicate. It addresses accidentally picking up more files than an
operation intended. It does **not**, by itself, address a narrower and different hazard:
**two concurrently dispatched tasks both holding uncommitted edits to the same shared file.**
Path granularity is the file — an explicit-path `git add` cannot subdivide a file by author — so
a dispatch that stages a shared file by its correct, explicit whole path can still carry a
sibling's still-uncommitted lines into its own commit, silently and without any staging mistake
on either side. This has been observed in production: a single shared markdown file carrying a
sibling task's rows inside an otherwise-correctly-scoped commit, and separately, a multi-task
batch where several dispatches' correctly-scoped commits each swept up a different task's
in-flight edits to shared files, attributing that content to the wrong task's commit history.

The remedy for this hazard lives at a different layer than staging-path discipline: a
first-claim contended-path lease enforced inside `git-commit-scoped.sh` itself (refusing to stage
a path a live sibling dispatch is concurrently contending for, rather than trying to stage it more
carefully), or, for a task type whose builds are expensive enough to warrant it, per-dispatch
working-tree isolation. See the working-tree and build isolation posture decision record
(`context/patterns/batch-orchestration-guardrails.md`'s "Working-Tree and Build Isolation
Posture" section) for the full scoring of both remedies against this and the other concurrent-
dispatch failure modes. That document and this one are cross-referenced deliberately: this
document defines what a single dispatch stages; that one decides what protects a shared file
across dispatches.

These remedies — the contended-path lease and per-dispatch working-tree isolation — address the
*cross-task* shared-file hazard: two different tasks' dispatches both holding uncommitted edits
to the same file. They do not address a different question: the *same-task* concurrent-write
hazard, where two dispatches against the identical task number could race on that task's own
artifacts. That hazard is settled by the per-task-number lock in `context/patterns/task-lock.md`,
acquired at the shared command preflight gate, which prevents two dispatches against the same
task number from running concurrently in the first place. A reader evaluating whether a
same-task staging scope needs its own concurrency remedy should start there rather than
re-deriving it by search.

## Multi-Task Application

In multi-task `/orchestrate`, the `research`/`plan`/`implement` scopes above apply **once per
task**, keyed to that task's own directory and its own `.return-meta.json` — never unioned across
tasks into a single combined commit. A union commit cannot be reverted per task. Concretely: MT
mode's per-task postflight loop (`orchestrate-cycle-postflight.sh`, called from `skill-orchestrate`'s Move 3) issues one scoped
commit per task per phase transition, reusing this same contract with `task_dir` and
`modified_files` resolved from that task's own state — never a sibling task's.

`--honest-index-rows` is required at every site staging `specs/state.json` or `specs/TODO.md`,
because those shared, wholesale-regenerated index files legitimately carry other tasks' current
rows in the same commit — including at the MT per-task commit site, which stages both files on
every task's commit.

## Fail-Safe Direction

**Under-stage, never over-stage.**

If `modified_files` is absent, empty, or the agent did not report it, the postflight pipeline
MUST fall back to staging only the fixed task-directory paths (`specs/{padded}_{slug}/`,
`specs/TODO.md`, `specs/state.json`, and the plan path for `implement`) and print a **loud,
non-silent warning**:

```
[postflight] WARNING: no modified_files reported; source-file changes NOT committed automatically. Review and commit manually.
```

In multi-task application (see "Multi-Task Application" above), the same warning is emitted per
task with the task number appended (`no modified_files reported for task #{task_num}; ...`) — this
is the only sanctioned wording; a second, differently-worded convention MUST NOT be introduced.

It is always acceptable to leave source-file changes uncommitted for the user to review and
stage manually. It is never acceptable to reach for `git add -A` to "catch everything" — that
silently pulls in unrelated concurrent-session changes.

### Staging-Layer Containment Filter (a Refinement of the Fail-Safe Direction Above)

This subsection records a refinement of the "under-stage, never over-stage" direction above, not
a new gate: the V2/V3/V5/V6/V7 gates in "Exit-Code Contract and Safety Gates" below all live
*inside* `git-commit-scoped.sh` itself; the filter described here is sited one layer above, in the
per-cycle postflight *caller* (`orchestrate-cycle-postflight.sh`), before `git-commit-scoped.sh`
is ever invoked. Placement follows directly from that distinction: a check on what gets PASSED to
the commit script is not a check on what the commit script DOES with what it is passed.

**The behaviour.** At per-cycle postflight, a self-reported `modified_files` entry that falls
outside the dispatching task's declared `file_scope` (the Containment predicate: one concrete
path tested against one task's own declared scope, as distinct from the Overlap-family
`--task`/V5 contended-path check, which tests a path against OTHER tasks' declared scopes) is
DROPPED from the staged set, with a loud per-path warning, and left uncommitted on disk for
manual review; the rest of the cycle's commit proceeds unaffected (drop-and-warn, never refuse
the whole commit). An absent or empty declared `file_scope` fails OPEN: the comparison never
runs, and nothing is dropped — a task with no declared `file_scope` commits exactly as it did
before this filter existed. The dispatching task's own resolved task directory is always an
implicit, unconditional in-scope member for this comparison (see
`orchestrate-cycle-postflight.sh`'s item (h) header note for the whole-directory ruling). The
four `specs/` carve-out paths (`TASK_DIR/`, `TODO.md`, `state.json`, and the plan path for
`implement`) are never tested against this filter at all — they are appended to the staged set
before the filtered loop runs, structurally outside its reach.

**Empirical basis, and precisely what it does and does not show.** A dated observation
(2026-10-04, in the Verification repository, `~/Projects/Logos/Verification`): a commit carried
nine generated Typst files
(`typst/manual/generated/components/{channel,crc8,receiver,ring_buffer,seq_num,stuff,
stuffed_channel,varint,vec_queue}.typ`), of which the originating task's declared
`file_scope` named exactly one (`crc8.typ`). Eight were outside the declared scope; five sibling
`book.cert.json` paths in the same commit were all correctly in scope. Scoping therefore held for
every declared path and failed only for the undeclared ones — the signature of an unvalidated
staging list, not a mis-declared scope. **This observation's provenance must be stated accurately,
not glossed over**: that commit was a mid-dispatch PHASE commit (subject: a book-recertification
phase commit), made by the implementation agent itself, NOT a per-cycle postflight commit
produced by `orchestrate-cycle-postflight.sh` — its own file list carries no `state.json`, no
`TODO.md`, and no task-directory entry other than the plan file, whereas a genuine postflight
commit unconditionally stages all three. **No claim is made anywhere that this staging-layer
filter would have prevented that observed commit — it would not have, because it does not run at
that site.** The observation is the evidence that the underlying Containment predicate is worth
enforcing somewhere, not a case this filter itself catches.

**What this filter does not cover.** An in-dispatch, mid-phase commit (the surface the 2026-10-04
observation actually came from) has no per-cycle postflight in scope at all, so no
postflight-sited filter can structurally reach it. That surface's own Containment check is a
separate mechanism, at a separate layer: `agents/general-implementation-agent.md`'s "Phase-Commit
Containment Self-Check" heading.

**Three Containment sites, not one.** With `git-commit-scoped.sh`'s own V10 gate landed (see
"Exit-Code Contract and Safety Gates" below), the same Containment predicate — one concrete path
tested against one task's own declared `file_scope` — is now checked at three independent
sites, each reaching a different commit surface:

1. **This postflight-sited filter** (`orchestrate-cycle-postflight.sh`'s WORK (h)/(i), described
   above) — reaches only the per-cycle whole-task completion commit, never a mid-dispatch phase
   commit.
2. **`git-commit-phase.sh`'s own Phase-Commit Containment Self-Check** (its header's section of
   that name) — reaches a mid-dispatch phase commit issued through that wrapper specifically.
   Site 2 is also the feedback source that keeps a task's declared `file_scope` from staying
   stale: every path this site drops is additionally deposited into `proposed_file_scope` (see
   "Why a task reported as carrying no `file_scope` can still see a drop at a later phase
   commit" below for the full producer/consumer narrative). This changes nothing about the
   predicate or the drop-and-warn posture at this or either of the other two sites — the
   deposit is additive to, and never a substitute for, the warning and the issue row every site
   already fires on a drop.
3. **V10, inside `git-commit-scoped.sh` itself** (gated on `--task`) — reaches EVERY caller that
   already supplies `--task` for the V5 contended-path lease, which includes both sites above
   (both already pass `--task`) plus every other caller of `git-commit-scoped.sh` that does the
   same, with zero call-site edits required.

All three sites now test a candidate path against the SAME shared definition of the
engine-written-state path set, `scripts/lib/engine-written-state-paths-lib.sh` (see "The
engine-written-state allowlist is one shared, canonical definition" below for the library's own
contract). Site 2 previously tested `files_touched` against the raw declared `file_scope`
alone, with no allowlist at all; it now carries the same splice sites 1 and 3 already carried,
closing that gap rather than leaving it the one site without one.

**A second universal, per-site widening: the committing task's own resolved artifact
directory.** Independently of the shared engine-written-state allowlist above, all three
Containment sites also admit the dispatching task's own resolved artifact directory as an
implicit, unconditional in-scope member. This member is deliberately NOT part of the shared
`scripts/lib/engine-written-state-paths-lib.sh` definition: that library's own header rejects
any task-owned `specs/{NNN}_*/` path, because a per-task directory is authored by one task's own
dispatch rather than engine-written on behalf of every/many tasks, failing the library's
admission bar. Each site obtains the directory through its own existing mechanism rather than a
shared helper: site 1 strips `PROJECT_ROOT` off its own absolute `TASK_DIR`
(`orchestrate-cycle-postflight.sh`'s `task_dir_rel="${TASK_DIR#"$PROJECT_ROOT"/}"`); site 2
reuses the `task_dir` local variable it already builds from `--task`/`--project`
(`git-commit-phase.sh`'s `task_dir="specs/${padded_num}_${project_name}"`, spliced into
`file_scope_arr` as `file_scope_arr+=("${task_dir}/")` inside the Self-Check's existing non-empty
`file_scope_arr` guard); site 3 calls `lib/task-lookup-lib.sh`'s `task_lookup_dir()`
(`git-commit-scoped.sh`'s V10 resolution). Sites 1 and 3 carried this member from their own
original landing; site 2's Phase-Commit Containment Self-Check did not, until the splice named
above.

Site 3 structurally subsumes site 2's own reach for the engine-written-state allowlist gap
specifically: `git-commit-phase.sh` always forwards `--task` to `git-commit-scoped.sh` (see that
wrapper's own invocation), so V10 now runs on every commit site 2's self-check already covered
for that allowlist. **This subsumption does NOT extend to the own-task-directory member
described above.** Site 2 removes an uncontained path from its own `files_touched` array — and
therefore from its own `stage_paths` pathspec — before `git-commit-scoped.sh` is ever invoked;
V10 tests only the pathspec entries it is actually handed, so it can neither see nor restore a
path site 2 has already dropped upstream of that call. Site 2's Phase-Commit Containment
Self-Check is therefore load-bearing for the own-task-directory member specifically, even while
it remains deliberately redundant (not load-bearing) for the engine-written-state allowlist gap,
where V10's identical coverage makes it so. It is left in place rather than removed for either
reason (it is idempotent, fail-open, and cheap, and additionally records its own `scope
excursion` issue-log entry independently of V10's) — but a future reader must not read
"redundant for the allowlist gap" as license to delete the self-check outright: doing so would
reopen the own-task-directory gap this section records. Site 1 is NOT subsumed by site 3: a
postflight `modified_files` entry can be dropped by the postflight-sited filter BEFORE it is
ever handed to `git-commit-scoped.sh` at all, so V10 never sees a path site 1 already removed —
the two sites are complementary layers on the SAME surface (the whole-task completion commit),
not a redundant pair the way sites 2 and 3 are for the phase-commit surface's engine-written-state
allowlist gap. See "Phase Commit (mid-dispatch)" below for the full asymmetry this landing
closes.

**A third asymmetry, deliberately left open: the deployed-tree strip and the within-dispatch
`proposed_file_scope` lookup are site-2-only.** Site 2's `file_scope_arr` has every entry equal
to `.claude`/`.claude/` or prefixed `.claude/` stripped before the own-task-directory and
engine-written-state splices run (a deployed-tree path is never a legitimate `file_scope`
member — `rules/source-store-deploy-boundary.md`), with a post-strip non-emptiness re-test
falling through to the existing fail-open path when nothing survives. Site 2 additionally
carries a read-only, exact-string `proposed_file_scope_lookup`, consulted ONLY to annotate a
repeat drop's warning text ("already recorded ... land it with a scoped follow-up commit") for
a path already deposited earlier in the same dispatch — it is NEVER unioned into
`file_scope_arr`, and never changes the admit/reject decision itself. (An admitting union was
built and rejected: it regressed `test-git-commit-phase.sh`'s own idempotence fixture, because
V10 at site 3 independently vetoes a path site 2 admits only on the STRENGTH of a not-yet-merged
deposit, making site 2 either falsely report success or hard-fail on a path that genuinely never
lands — see `git-commit-phase.sh`'s own "WITHIN-DISPATCH proposed_file_scope LOOKUP (PART B)"
header subsection for the full reasoning.)

Neither of these two site-2 mechanisms is mirrored at site 3. A `file_scope` carrying a bare
`.claude/` entry is therefore stripped (and the whole check falls open if nothing else survives)
at site 2, but V10's own `containment_scope_arr` resolution at site 3 still reads that same bare
`.claude/` entry unstripped — today's un-normalized `is_contained_v10()` composition can still
read it as covering every deployed-tree path, the EXACT loophole site 2's strip was built to
close, just one layer downstream. This is a recorded, out-of-scope residual (site 3 and its own
test suite are outside the file_scope of the task that landed the site-2 strip and lookup) for a
future task to close by porting the SAME strip into site 3's V10 resolution block — not a defect
in site 2's own, narrower closure.

**The staging-seed/containment asymmetry the own-task-directory member closes.**
`git-commit-phase.sh`'s unconditional `stage_paths` seed (`stage_paths=("${task_dir}/"
"specs/TODO.md" "specs/state.json")`, described in "Phase Commit (mid-dispatch)" below) already
stages the whole task directory regardless of any task's declared `file_scope` — the parity
assumption recorded in "Scope of the `git-commit-phase.sh` migration" below, that the commit
pipeline already covers the whole task directory regardless of declared scope, is TRUE of this
seed. It was FALSE of the Containment Self-Check's own `file_scope_arr`, which tested every
`files_touched` entry — including one sitting inside the very directory the seed already
stages — against a scope that never named that directory. In the fixture harness used to pin
this (`test-git-commit-phase.sh`'s Cases 15 and 16), the practical consequence was not an actual
omission from the commit — the directory-level seed already lands the file regardless — but a
spurious `WARNING: ... dropping out-of-scope path` plus a spurious `scope excursion` row written
to the task's own `issues.jsonl` for a path that was never actually out of scope. The
own-task-directory member recorded above closes that specific asymmetry between the two
constructs.

**Why a task reported as carrying no `file_scope` can still see a drop at a later phase
commit.** `orchestrator-postflight.sh`'s additive `--file-scope-add` write-back — fed by a
research report's `proposed_file_scope`, by `plan-file-scope-harvest.sh`'s harvested "Files to
modify" union, or (the third source) by `git-commit-phase.sh`'s own drop-time deposit into the
SAME `proposed_file_scope` field, consumed at implement postflight — can populate a
previously-absent `file_scope` between an earlier review of a task's state and a later phase
commit. The third source differs from the other two in producer, not in consumer path or merge
semantics: the field is still additive-only, still union-merged, and still forwarded via the
same `--file-scope-add` flag, but on this path it is deposited by the commit wrapper itself,
mid-dispatch, at the moment its own Containment Self-Check drops a path — not authored by any
agent. A review observing "no declared `file_scope`" and a later phase commit observing a real,
non-empty, source-only `file_scope` are therefore both correct readings of the same task at two
different points in its lifecycle, not evidence that the fail-open guard failed to apply. The
fail-open posture itself — an absent, empty, or malformed `file_scope` skips the Containment
Self-Check entirely — is unchanged and remains deliberate.

**The engine-written-state allowlist is one shared, canonical definition.** All three
Containment sites widen their own effective scope with the same fixed path set before testing a
candidate path, sourced from `scripts/lib/engine-written-state-paths-lib.sh` rather than each
site hand-copying the list separately. That library exports one function,
`engine_written_state_paths`, printing the four admitted members:
`specs/TODO.md`, `specs/state.json`, `specs/events.jsonl`, `specs/errors.json`. Its own header
states the admission bar a future fifth member must clear: engine-written on behalf of
every/many tasks, AND never legitimately declarable in any one task's own `file_scope` — a
candidate failing either half does not belong in the set, since widening it weakens every site's
excursion guard at once. A source or resolution failure at any site falls back to the hardcoded
two-literal pair (`specs/TODO.md`, `specs/state.json`) rather than an empty scope, so a library
failure reproduces each site's pre-shared-library behavior exactly rather than narrowing it.
WORK (i)'s unconditional `stage_paths` seed (the carve-out described above) remains an
independent second layer at site 1 — this allowlist does not replace it, and removing the seed
would reintroduce genuine commit-time loss of `specs/TODO.md` and `specs/state.json`. The
"Site 1 is NOT subsumed by site 3" asymmetry above is unchanged by the shared definition: the
allowlist closes one specific false-positive blind spot in each site's own diagnostic, not the
asymmetry itself. The allowlist only ever admits a path when some caller already names it in a
pathspec or in a reported `modified_files`/`files_touched` entry — it is never itself added to
any `stage_paths` seed, because unconditionally seeding a shared, append-only store like
`specs/events.jsonl` into every commit would sweep a concurrently-dispatched sibling task's own
event rows into this task's commit, the opposite of the excursion guard's purpose.

**Scope of the `git-commit-phase.sh` migration.** A source-store-wide sweep for the same
hand-typed `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json" ...)` shape found it
repeated across most per-extension implementation agents (lean, nix, rust, typst, books, latex,
web, python, z3, cslib, epidemiology, founder, nvim and others), each with its own Phase
Checkpoint Protocol copied from the same original template `general-implementation-agent.md`'s
two sites were migrated from. Migrating every one of those is a real, separately-scoped
follow-up, not folded in here: this cross-reference records the finding so a future task can
pick it up, rather than silently leaving it undiscoverable. The command-level commits
`check-task-references.sh` also turned up (`review.md`, `todo.md`, `errors.md`) and the
whole-task completion commits in `orchestrator-postflight.sh` and
`orchestrate-cycle-postflight.sh` are a different category entirely — a final, whole-task
commit, not a per-phase one — and are unaffected by this wrapper by design.

**A different-repository containment nuance: a `file_scope` entry whose correct home is not THIS
repository at all.** A `files_touched` path can fail containment for a reason none of the three
sites above distinguishes from an ordinary undeclared-scope miss: the path may belong to a
DIFFERENT repository entirely, either a genuinely unrelated location, or an extension's own
SOURCE STORE (`.claude-extensions.json`'s per-extension `source_dir`), whose enclosing git
toplevel differs from this repository's own root. Before this nuance was recognized, both shapes
reached site 2's ordinary Containment Self-Check and were reported with the identical "not
contained in this task's declared file_scope" wording a genuinely in-repository undeclared path
gets — "commit this in the source store" was indistinguishable from "you did not declare this".

`scripts/lib/source-store-path-lib.sh` resolves this ambiguity with one shared classification,
`source_store_classify <repo_root> <path>`, consumed at site 2 (`git-commit-phase.sh`) BEFORE its
own containment test runs — the same placement rule `git-commit-scoped.sh`'s V9 out-of-repository
guard already follows for itself: an out-of-repository path must never be able to reach a scope
test, because a scope test can only ever answer "declared or not", never "which repository". Per
extension, it resolves `source_dir`, that directory's own enclosing git toplevel, and whether the
tested path is attributable to that extension (by the source-store-relative spelling convention
already in universal use, or by absolute resolution under `source_dir`); when the resolved
toplevel equals the committing repository's own canonicalized root, the extension contributes
nothing and the path's bare in-repository verdict stands unchanged — the INERTNESS property that
keeps this mechanism a no-op in a repository that owns its own source store. Three verdicts:
`IN_REPO` (proceeds into the ordinary Containment Self-Check exactly as before this classification
existed — acceptance-criterion-3 territory: nothing here changes that path's existing treatment);
`SOURCE_STORE` (classified to a named extension and repository toplevel); `OUT_OF_REPO` (no
extension claims it).

A `SOURCE_STORE` or `OUT_OF_REPO` verdict is dropped from the committing repository's own commit
exactly as an ordinary excursion is — never admitted, never staged — but reported under a class
TEXTUALLY DISTINCT from the ordinary `scope excursion`: `source store excursion`, naming the
resolved repository root (and, for `SOURCE_STORE`, the extension and the path's location inside
that repository) rather than reusing the undeclared-scope wording. Neither verdict's path is ever
deposited into `proposed_file_scope`: a path this repository can never hold would guarantee an
identical drop on every future phase if re-seeded into `specs/state.json`'s declared scope, so
`propose_file_scope_addition()` carries its own defensive refusal for both verdicts, mirroring its
existing deployed-tree refusal.

A `SOURCE_STORE` verdict additionally gets a sanctioned, single-pathspec commit attempt in its own
repository — `scripts/commit-source-store-path.sh <target_root> <relative_path> <message>
<session_id>` — invoked immediately after the committing repository's own commit returns, never
before. This is the SAME single-explicit-pathspec staging discipline this document already
requires throughout — never a directory, never a glob, never `-A`/`.`/`-am` — applied unchanged to
the second repository. The script refuses up front, before touching that repository's index, on:
the target equalling the committing repository's own root (not an out-of-repository case at all);
a target that is not a git working tree; a detached HEAD; an in-progress merge, rebase,
cherry-pick, or bisect; an existing `index.lock`; a missing target file; or an empty diff for that
one path (a benign no-op, not a failure). Every refusal and every genuine commit failure names the
exact manual recovery command. **This mechanism is FAIL-OPEN UNCONDITIONALLY**: its own exit code
is captured and reported, never propagated into the committing repository's own commit or exit
code, and no caller is permitted to treat a non-zero result from it as fatal — the three outcomes
(committed, benign no-op, not committed) are each recorded via a non-fatal issue-log call, a win
on equal footing with a failure, and the drop-time notice above is made unconditional and
outcome-aware by this follow-on attempt rather than replaced by it.

**Named residuals, recorded explicitly rather than chased to parity in one pass.** The whole-task
completion commit site and `git-commit-scoped.sh`'s own containment gate keep their existing
behaviour unchanged: the latter's own out-of-repository guard already classifies the absolute
out-of-repository shape correctly on its own terms, and the former is not on the path any
observed drop of this kind took. The direct `file_scope`-write route into `specs/state.json` does
not gain the matching unexpanded-shell-variable-shape refusal this nuance's authoring-boundary
companion added at the harvest and plan-validation surfaces — every confirmed instance of that
shape originated at the harvester, not at that write path, and that write path's own test suite
sits in a separately declared scope. A future task extending the refusal there should re-derive
the origin rather than assume it still holds.

## Reference Template (canonical scoped-staging pattern)

This is the canonical, proven scoped-staging pattern — reuse it verbatim rather than
reinventing scoped staging:

```bash
padded_num=$(printf "%03d" "$task_number")
git add \
  "specs/${padded_num}_${project_name}/reports/" \
  "specs/${padded_num}_${project_name}/.return-meta.json" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete research

Session: ${session_id}
"
```

For `implement`, extend the same pattern with the plan path, `modified_files`, and the canonical
exclusion set (this template stages the whole task directory, unlike the research example
above, so the exclusions are required here). **This inline template is illustrative of the
overall staging shape only — it is NOT the sanctioned implementation.**
`agent-system/extensions/core/scripts/git-commit-scoped.sh` is the sanctioned implementation
(see "Commit-Level Path Scoping and Cross-Process Serialization" below) and applies the
`git check-ignore`-gated conditional injection documented in "Canonical Runtime-File Exclusion
Set" above — a caller reading only this template and reproducing the unconditional `git add
"${ephemeral_excludes[@]}"` shape shown here verbatim would reintroduce the `.lock/`-present
abort hazard that conditional injection exists to close. Prefer invoking
`git-commit-scoped.sh` directly over hand-rolling this template's `git add`/`git commit` pair —
running the template's `git add "${stage_paths[@]}"` line as a raw top-level Bash command is now
correctly BLOCKED by `guard-destructive-git.sh` on a dirty tree, since `${task_dir}/` is a
directory pathspec (see "Forbidden Operations" above); `git-commit-scoped.sh` is the sanctioned
path precisely because its own internal `git add` runs as a subprocess, never as the literal
top-level `tool_input.command` the hook observes (the same structural-invisibility precedent
`guard-destructive-git.sh`'s header documents for `git-snapshot.sh`):

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
ephemeral_excludes=(
  ":(exclude)${task_dir}/.orchestrator-loop-guard"
  ":(exclude)${task_dir}/.orchestrator-churn-state.json"
  ":(exclude)${task_dir}/.drift-inspection.json"
  ":(exclude)${task_dir}/.lock/"
  ":(exclude)${task_dir}/.dispatch/"
)
stage_paths=(
  "${task_dir}/"
  "${ephemeral_excludes[@]}"
  "specs/TODO.md"
  "specs/state.json"
  "$plan_path"
)
# Append each self-reported modified file
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file")

git add "${stage_paths[@]}"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}
"
```

## Forbidden Operations

The following are forbidden in the commit pipeline and any agent/skill that stages files for a
task-scoped commit:

- `git add -A`
- `git add .`
- A **directory or glob `git add` pathspec** (e.g. `git add -- some/dir/`, `git add some/dir`,
  `git add src/*.lean`) — stages every modified file the pathspec expands to, the identical
  over-staging harm as `git add -A`/`git add .` in a narrower disguise. The sanctioned explicit
  multi-file list (e.g. `git add -- a.lean b.lean`) is unaffected and remains the correct form.
  When that explicit list is covering a directory *rename* rather than an ordinary edit, see
  "Rename and Directory-Move Staging" below for the additional pairing requirement an explicit
  list must satisfy.
- `git commit -am` (implicitly stages all tracked-file modifications)
- A **bare, unscoped `git commit`** (no trailing `-- <pathspec>...`) — see "Commit-Level Path
  Scoping and Cross-Process Serialization" below. Even when staging was correctly narrowed by
  this contract, a bare commit still commits the ENTIRE shared index, not just what was just
  staged, so a concurrently-dispatched agent's staged-but-uncommitted work gets swept into
  whichever agent commits next.

These commands stage (or commit) more than the operation actually produced, which can silently
include a concurrent session's stray edits, unrelated in-progress work, or accidental file
changes that have nothing to do with the current operation.

**Enforced by `guard-destructive-git.sh`**: the first four bullets above (`git add -A`/`--all`,
`git add .`, a directory-or-glob `git add` pathspec, and `git commit -a`/`-am`/`--all`) are
enforced mechanically, not just by convention — `.claude/hooks/guard-destructive-git.sh`'s
over-staging predicate blocks all four on a dirty working tree via exit 2, with NO
snapshot-marker exemption (see that hook's header for the data-loss vs. scope-pollution
rationale). The bare-unscoped-commit bullet is not part of that predicate; it is enforced by
`git-commit-scoped.sh` always naming its pathspec, per "Commit-Level Path Scoping and
Cross-Process Serialization" below.

## Rename and Directory-Move Staging

**Rule**: any `mv` whose two endpoints are both inside the staged tree MUST contribute BOTH
endpoints — the old path and the new path — to the commit's pathspec list, together, in the
same commit. An explicit file list only covers what it names; a shared-directory token that
used to sweep up both sides of a rename incidentally is not a substitute for naming both
endpoints, and is itself forbidden by "Forbidden Operations" above.

**Failure mode this rule prevents**: if an accumulator or hand-written `git add` line is taught
to collect only a move's destination, the vacated source is never staged. `git add` is never
asked to record the source's removal, the destination lands in the commit as a fresh
`create mode` with no matching `delete mode`, and the old tree stays in the index pointing at
files that no longer exist on disk — while the commit still exits 0 reporting success.

**Why no existing gate catches an omission**: a directory-pathspec lint classifies only tokens
that are *present* in a call site's pathspec; a missing token is an omission, not a textual
pattern, so such a lint structurally cannot see it. Likewise, `git-commit-scoped.sh`'s own
pathspec-classification gates (matched / already-staged-deletion / genuinely-unmatched, and the
per-passed-path contention check) only ever inspect pathspecs they are *given* — an endpoint
that was never passed is never evaluated by any of them. The rename-pairing discipline below is
therefore a call-site obligation; no downstream gate can substitute for it.

**Canonical illustration** (the pattern every call site below should match), from the vault
rename site in `commands/todo.md`:

```bash
# Stage the rename's exact old and new paths together so `git add` records it as a rename
# rather than leaving the old tree's removal unstaged. This is NOT a bare shared-directory
# pathspec: both tokens name the two exact paths this one `mv` just touched, not an open-ended
# directory sweep.
stage_paths+=(specs/archive "${vault_path}/")
```

**Two mechanisms this rule must be honored under** (the two live call sites that pair
endpoints, named by file plus step/stage, never by line number — both drift):

- An **accumulator array**, in `commands/todo.md`: each move site appends `stage_paths+=("$old"
  "$new")` to a shared array threaded through the whole archival recipe and consumed once at
  its final commit step.
- A **hand-written `git add` line**, in `skill-todo/SKILL.md`'s GitCommit stage: each of that
  recipe's Stage 10 move sites appends to a `moved_paths[]` array, which the GitCommit stage's
  `git add` invocation expands with `"${moved_paths[@]}"` rather than naming a fixed destination
  directory.

Both mechanisms satisfy the same rule; which one a given recipe uses is a function of whether it
already carries a pathspec accumulator or builds its `git add` invocation inline — not a reason
to relax the pairing requirement itself.

## Cached-Untracking Staging (`git rm --cached` with content left on disk)

**Rule**: to commit a `git rm -r --cached <dir>` untracking — index deletions whose content
remains present on disk — invoke `git-commit-scoped.sh` with an ordinary positive pathspec naming
`<dir>`, exactly as for any other scoped commit. No relocation of any file out of the working
tree is required or sanctioned; relocating content out of the repository to work around a
refusal is not a recipe and MUST NOT be used.

**Failure mode this rule prevents**: `git commit -- <pathspec>` (and every other pathspec-scoped
commit form, including an explicit file list or an `--only` invocation) has `--only` semantics
and re-reads the working tree fresh for each named path at commit time. A path staged as deleted
but still present on disk therefore always resolves to "nothing to commit" under that form, with
HEAD unmoved — pathspec granularity does not matter here, because the hazard is in `--only`
commit semantics, not in how narrowly the pathspec names its targets. An explicit file list is
not a workaround for this shape for the same reason a directory pathspec is not: neither can
express a committed deletion whose content remains on disk. `git-commit-scoped.sh` instead
commits this shape via a bare `git commit` (the whole staged index) ONLY after proving the staged
index is exactly the declared pathspec scope — the whole-index diff compared against the same
diff restricted to the declared pathspecs — so the commit can never land wider than what the
caller actually asked for, even though the underlying mechanism is a bare commit.

**Why no existing gate catches it**: this shape's premise is the OPPOSITE of "Rename and
Directory-Move Staging" above. That section, and the fully-staged-deletion carve-out it
documents, both require content GONE from the working tree — the vacated source half of a
directory move. A cached-untracking requires content PRESENT on disk, with every tracked file
already removed from the index. A single predicate cannot honor both premises without blurring
them, so `git-commit-scoped.sh` classifies the two shapes separately (Verified Findings V11 and
V12 in the script's own header) and emits two textually distinct stderr NOTEs so a reader can map
a given invocation's note to the correct shape: the fully-staged-deletion NOTE names "the source
half of a directory move"; the cached-untracking NOTE names "a cached-untracking shape" and
states explicitly that it is NOT the source half of a directory move. The two NOTEs are never
both emitted for the same invocation.

**Identifying this shape in a log**: this shape surfaces as one of two gitignore-dependent
symptom texts, which both identify the same cached-untracking shape. For a gitignored directory,
the symptom is a refusal whose message includes "not present in the index at all" — the
directory's content is present on disk, which is the opposite of the fully-staged-deletion
conjunct that symptom's classification path checks for. For a non-gitignored directory, the
symptom is no error at all: the untracked files simply reappear in `git ls-files` after the
commit, because `git add` restages whatever is still present on disk. A reader who maps either
symptom text to this section has correctly identified the shape; `git-commit-scoped.sh` resolves
both via the same Verified Finding V11/V12 classification above, with no relocation and no
special-cased recipe beyond the ordinary invocation below.

**Canonical illustration**:

```bash
# Untrack a stale deploy tree whose content remains on disk -- no relocation needed.
git rm -r --cached .opencode
bash agent-system/extensions/core/scripts/git-commit-scoped.sh \
  --message "untrack stale .opencode deploy tree" --session "$session_id" \
  -- .opencode
```

## Commit-Level Path Scoping and Cross-Process Serialization

Staging narrowly is necessary but not sufficient: a narrowed `git add` followed by a **bare**
`git commit` still commits the entire shared index, because `git commit` with no pathspec commits
everything currently staged — including anything a concurrently-dispatched agent staged into the
same shared index but has not yet committed. This was a real, observed defect (two implementation
agents each reported their own phase commits swept into a concurrent session's commit message).

The fix has two parts, both mandatory for every commit site in the dispatch pipeline:

1. **Every `git commit` MUST name its pathspec**: `git commit -m "..." -- <pathspec>...`, using
   the same paths (plus the canonical exclusion set) that were just staged. A bare `git commit`
   is now a Forbidden Operation (see above), on the same footing as `git add -A`.
2. **The `git add` + `git commit` pair MUST be serialized** through the `specs/.commit-lock/`
   mutex (`task-lock.sh`'s `commit-acquire`/`commit-release` verbs — see
   `context/patterns/task-lock.md`'s Scope-Mutex CLI section for the full contract). Path-scoping
   alone converts misattribution into a DIFFERENT failure: two simultaneous scoped commits race on
   git's own `index.lock`, and one fails outright. Serializing the add+commit pair removes that
   race without reintroducing misattribution.

`agent-system/extensions/core/scripts/git-commit-scoped.sh` is the single sanctioned
implementation of both parts. Every commit site in the dispatch pipeline invokes it rather than
re-deriving this pattern inline — the pattern drifted once already when it was left to eleven
near-duplicate call sites (nine of eleven never received the canonical exclusion set after it was
added to this document), and a single shipped helper is what stops that recurring.

Two non-obvious safety rules, discovered empirically and enforced inside the helper rather than
left for each caller to rediscover:

- **An exclude-only pathspec list commits WIDER than a bare commit, not narrower.** `git commit --
  ":(exclude)some/path"` with no positive pathspec entry commits everything except the excluded
  path — the opposite of the intended narrowing. A degenerate `stage_paths` (e.g. an empty task
  directory variable) would silently turn the fix into a worse bug. `git-commit-scoped.sh` refuses
  to run (no `git add`, no commit) if the pathspec list contains zero positive entries, both
  before and after path validation.
- **An unmatched path in the commit pathspec aborts the WHOLE commit.** `git commit -- <paths
  including one git cannot match>` fails with `error: pathspec '...' did not match any file(s)
  known to git` and commits nothing at all — worse than `git add`'s equivalent failure, which
  today is already guarded by the postflight pipeline. `git-commit-scoped.sh` validates each
  positive pathspec and drops unmatched entries with a loud warning rather than aborting the
  entire commit.

### Exit-Code Contract and Safety Gates

`git-commit-scoped.sh`'s own header documents its full exit-code table and safety-gate labels
(V2, V3, V5, V6, V8, V9); this subsection mirrors that table here so a reader of this document is
not left to open the script for it.

| Exit code | Meaning |
|-----------|---------|
| `0` | Commit created. |
| `1` | "Nothing to commit" (identical to a bare `git commit`'s own exit code), or the `git commit` itself failed after the bounded `index.lock` retry. Non-blocking — matches every call site's existing `|| echo "NOTE: Nothing to commit..."` fallback. |
| `2` | Usage error, or the V3 degenerate-pathspec refusal (an exclude-only list, or every positive pathspec dropped by V2/V9/V10 — refused before any `git add`/`git commit`), or `git add` itself failed for one or more staged paths. |
| `3` | Contended-path refusal (V5, `--task` only): a positive pathspec entry is listed as contended in the cycle manifest AND currently claimed by ANOTHER live task. Refused before any `git add`; nothing staged. Never emitted when `--task` is omitted. |
| `4` | The V6 refusal below: one or more positive pathspecs were dropped — as genuinely unmatched (V2), as out-of-repository (V9), or as outside the dispatching task's declared `file_scope` (V10) — AND the commit attempt produced no commit. `dropped_pathspecs` carries all three drop reasons undifferentiated for this gate's purposes. |
| `5` | The V8 refusal below: a commit WAS created (`commit_exit` was `0`) but one or more named positive pathspecs did not land in `HEAD` as intended. Dedicated and never folded into `commit_exit`, since the defining feature of this defect is that `commit_exit` is already `0`. |
| `6` | The V9 decision below: a commit WAS created (`commit_exit` was `0`) and one or more positive pathspecs were dropped as out-of-repository. Observability, not a refusal — the valid paths already committed successfully. |
| `7` | The V10 decision below: a commit WAS created (`commit_exit` was `0`) and one or more positive pathspecs were dropped as outside the dispatching task's own declared `file_scope`. Observability, not a refusal — the valid paths already committed successfully. Never emitted when `--task` is omitted, nor when V9 also fired for the same invocation (V9's own exit `6` keeps precedence by placement). The all-dropped shape stays exit `2` (V3, above) and the survivors-but-no-commit shape stays exit `4` (V6, above) — reaching `7` requires `commit_exit` to already be `0`. |

Gate labels, in the same voice as the script header:

- **V2** — an unmatched path in the commit pathspec aborts the whole commit in bare git; this
  script classifies each positive pathspec into matched / already-staged-deletion / genuinely
  unmatched, dropping only the third case with a loud warning.
- **V3** — an exclude-only pathspec list (or a positive list that fully degenerates to one after
  V2 filtering) commits WIDER than a bare commit, not narrower; refused outright before any
  `git add`/`git commit`.
- **V5** — explicit-path staging alone does not protect against CONCURRENT same-file dispatch;
  `--task` opts a caller into a per-path first-claim lease against the cycle-scoped contention
  manifest.
- **V6** — a PARTIAL pathspec drop (some, not all, positive entries hit V2's genuinely-unmatched
  case) is indistinguishable from the ordinary, benign "nothing changed" no-op once the survivors
  themselves carry no diff: both land on exit `1`, differing only in a stderr `WARN:` line that no
  current caller inspects. (V3 above already refuses the OTHER half of this gap — every positive
  pathspec dropped; V6 covers what V3 does not.) When at least one pathspec was dropped AND the
  commit attempt produced no commit, this script now exits `4` with a loud `ERROR:` naming every
  dropped path instead of falling through to the generic `NOTE:`. The predicate deliberately does
  NOT try to distinguish "nothing to commit" from "git commit genuinely failed" by parsing commit
  output — both sub-cases are already nonzero and already swallowed identically by every current
  caller, so splitting them buys nothing and adds a dependency on git's own wording.
- **V8** — a named, matched, non-ignored positive pathspec (V2 case 1, correctly staged by V7's
  own standards) can still be absent, or present with the wrong content, in the commit that
  `git commit -- <pathspec>` actually produces, while the script exits `0` and prints nothing —
  structurally indistinguishable from an ordinary successful commit at every earlier gate, since
  the drop happens strictly between a correct `git add` and the commit's own tree build (see
  `git-commit-scoped.sh`'s header for the "`git commit -- <pathspec>` re-reads the working tree
  fresh at commit time" fact this gap depends on). This script now takes a pre-commit intent
  snapshot of every surviving positive pathspec (a content hash, or an explicit "absent" sentinel
  for a staged deletion) before `git add` runs, and a post-commit integrity gate that resolves
  each snapshotted path from the resulting `HEAD` and compares, printing a marked `ERROR:` naming
  every mismatch and exiting `5` whenever `commit_exit` was `0`. A correct absence (a V2 case-2
  staged deletion, or the vacated source half of a V7 fully-staged-deletion rename) compares as a
  MATCH, never a mismatch — see the script's own test suite's false-positive dimension cases for
  what this was checked against. Scope correction: the incident that originally motivated this
  gate (commit `fc9f786e` in a consumer repository) turned out, on re-checking the actual
  tool-call transcript, to be a CALLER-SIDE pathspec-list omission (the dropped path was never
  named in that commit's own argument list at all) — outside what this script can see, and a
  class V8 cannot catch by construction. V8 is confirmed, by direct deterministic reproduction,
  to catch a different mechanism: a named, correctly-staged path whose committed content still
  diverges from what was staged, independent of whichever concrete mechanism (a hook, a
  concurrent writer, or something else) causes that divergence. See the script's own header for
  the full correction.
- **V9** — an absolute pathspec pointing into a DIFFERENT repository exists on disk, so V2's
  matched-case test (`[ -e "$p" ]`, with no containment check) admits it to the single
  all-or-nothing `git add` call, which then fails FATALLY for every path in that call, not just
  the offending one (verified empirically: a mixed call with one out-of-repository path stages
  NEITHER the out-of-repository path NOR any of the valid ones). This script now classifies a
  positive pathspec as out-of-repository BEFORE V2's matched case can claim it, by resolving ONLY
  the pathspec's PARENT directory (`realpath -m --relative-to=<resolved PROJECT_ROOT>` against
  `dirname` of the pathspec) — deliberately never the pathspec's own final component. That
  distinction is load-bearing: an in-repo leaf symlink whose target lies outside the repository is
  a LEGAL `git add` argument (staged as a symlink blob) and must not be dropped, while a path
  THROUGH an in-repo symlinked directory whose target lies outside the repository IS fatal to
  `git add` itself and correctly resolves out-of-repository under the parent-only rule, since the
  symlinked directory is itself part of the parent path. A V9-classified path is dropped with a
  WARN distinct from V2's own unmatched-path WARN and recorded in both the shared drop ledger (so
  V6 above still refuses the all-dropped-and-nothing-committed shape as exit `4`) and a separate
  out-of-repository ledger (so exit `6` can be decided independently of V2's genuinely-unmatched
  drops). See the script's own header for the full predicate and the empirical verification it
  cites.
- **V10** — `--task <N>` only (layered onto the SAME flag V5 and V9's own ledger already
  consume, rather than a separate opt-in flag, so every caller that already supplies `--task`
  for V5 gains this check with ZERO call-site edits). V9 above catches a pathspec resolving
  OUTSIDE THE REPOSITORY; V10 catches a narrower case V9 says nothing about: a pathspec INSIDE
  the repository but outside the DISPATCHING TASK's own declared `file_scope`
  (`specs/state.json`'s `.active_projects[].file_scope`) — the Containment predicate (one
  concrete path tested against one task's own declared scope), as distinct from the Overlap
  family V5 already implements (a path tested against OTHER tasks' declared scopes). The
  effective scope compared against is wider than the bare declared array: it also admits the
  task's own resolved directory (via `lib/task-lookup-lib.sh`'s `task_lookup_dir`), the two
  fixed literals `specs/TODO.md` and `specs/state.json`, and every declared derived-output
  prefix (`lib/derived-artifact-probe-lib.sh`'s `derived_probe_output_prefixes`) — the SAME
  widening `orchestrate-cycle-postflight.sh`'s own WORK (h) Containment filter already applies
  one layer above this script, so a declared derived-output path that survives THAT filter is
  never silently re-dropped here. Evaluated BEFORE V2's matched case, same placement rule as V9
  immediately above, reusing V9's already-computed parent-directory resolution (never a fresh
  whole-path `realpath`, for the identical leaf-symlink-safety reason V9's own entry states). An
  uncontained path is dropped with a WARN textually distinct from both V2's own unmatched-path
  WARN and V9's out-of-repository WARN, added to neither the add set nor the commit set, and
  recorded in a dedicated Containment-drop ledger (mirroring V9's own out-of-repository ledger
  pattern) plus one non-fatal `issue-record.sh --class "scope excursion"` call. Posture is
  drop-and-warn, never refuse, and FAILS OPEN unconditionally on: `--task` omitted; no
  `specs/state.json` entry for that task number; a missing, empty, `null`, or malformed
  (non-array or non-string-member) `file_scope`; or any internal error resolving the task
  directory or the derived-output prefixes — in every such case the effective scope is left
  EMPTY, which disables this entire check by construction, the same single-disable-switch shape
  V5's own fail-open posture already uses. See exit code `7` above for the resulting observable
  outcome on a commit that nonetheless succeeds.

**Recorded caller-escalation residual**: every call site other than
`orchestrate-cycle-postflight.sh` still wraps the invocation as `cmd || echo "WARN: ...
(non-blocking)"`. Because bash's `A || B` yields `B`'s exit status regardless of `A`'s own code,
ANY nonzero exit from the script — `1`, `2`, `3`, `4`, `5`, `6`, or `7` — still collapses to
success for those callers' own control flow. `orchestrate-cycle-postflight.sh`, the one live
caller actually exposed to a `modified_files`-sourced out-of-repository pathspec, now captures `$?`
explicitly and branches: exit `1` keeps the existing non-blocking wording verbatim (the benign
"nothing to commit" no-op); exits `2`, `3`, `4`, `5`, and `6` print a named, attributable `ERROR:`
(task number, exit code, and that code's meaning from this table), fire one durable
`issue-record.sh` entry (`--class "orchestration defect"`, aggregated by
`orchestrate-conclusion-aggregate.sh`) and populate the emitted verdict JSON's `note` field.
Exit `7` is not a member of that explicit list (this script's own `file_scope` excludes
`orchestrate-cycle-postflight.sh`, so this change does not touch its case statement) but is
still loud and attributable: it falls through that `case` statement's own `*)` catch-all branch
for "an unrecognized future exit code," which prints the same shape of named `ERROR:` (task
number, exit code, non-blocking) without the durable `issue-record.sh` entry the explicit list
gets — a real, if slightly reduced, observability gap rather than a silent swallow, and a
natural candidate for that explicit list to adopt `7` by name in a future pass over this script.
Neither path changes `halt` or `infra_exempt_cycle`. `verdict` and the task's own STATUS (not
merely its issue log) ARE narrowly reassignable, but only inside one additional, separately-gated
block sited immediately after this exit-code `case` statement: when the exit code is `2`, `3`,
`4`, or `5` for an `implemented` dispatch whose completion-claim gate just passed (the exact
conjunction under which this same call site's `case "$dispatch_status"` chose the "complete
implementation" commit message), the task is demoted from `completed` to `partial` in
`state.json`, its handoff gains a named blocker with no continuation pointer (so the next cycle's
triage routes it to `needs_human` instead of re-dispatching `implement`), and the cycle's verdict
flips from `ok` to `defer`. Exit `6` and exit `7` deliberately do NOT demote — both mean a commit
landed (exit `6`: V9's out-of-repository drop alongside a commit that still landed; exit `7`: V10
containment drop, same shape) — so a task whose deliverable changes are genuinely on disk,
committed, is never second-guessed. See `context/standards/status-markers.md`'s `[COMPLETED]`
subsection for the sanctioned terminal-state exception this implements. Exit `7` still has not
been adopted into the explicit `2|3|4|5|6)` list above (the observability gap noted two
paragraphs up), and is correspondingly excluded from the demotion gate as well — both by the same
"a `*)` catch-all code might not mean a commit failed to land" fail-open reasoning.
`orchestrate-unwind-dispatch.sh` and `lib/redeploy-checkpoint-lib.sh` are deliberately left on the
`|| echo` idiom: both pass only fixed, caller-constructed literals to this script, never a
`modified_files` entry, so neither is structurally exposed to this defect.
`orchestrator-postflight.sh` is confirmed orphaned (zero live invocation sites) and was not
touched. `scripts/lint/lint-scoped-commit-boundary.sh`'s RULE 3 keeps a future `.sh` caller from
re-introducing the exit-code sink, with reasoned allowlist entries for the three callers named
above. The roughly 50 remaining references across documentation and prose skill/agent bodies are
copied illustration, not executed code, and are intentionally not hand-edited; RULE 3 is scoped
to `.sh` files only for exactly this reason.

**Flagged follow-up, not adopted here, and NOT settled**: an earlier research pass's own
forced-fail-open two-writer harness reported a shared-overlapping-path drop in a minority of
trials (3/20, 1/10) under the `specs/.commit-lock` mutex's fail-open branch. That result was NOT
independently reproduced by V8's own implementation work (which instead confirmed a different,
unrelated mechanism — see V8 above) and should not be cited as a settled falsification of the
mutex's prior safety comment; the comment was left as an open "UNDETERMINED" question rather than
overwritten with an unsupported concurrency claim (see the script's own header for the exact
wording). A stronger fix would make that mutex fail CLOSED on an acquire timeout instead of
proceeding unserialized (mirroring `specs/.scope-lock`'s existing fail-closed posture); this
remains a behavior change beyond "make the failure loud," is deliberately held out of this gate's
scope, and is flagged here as an open question rather than either a silently dropped or a
falsely-settled one.

## Required Review Flow

Before any commit in the pipeline, prefer to surface what is about to be committed:

```bash
git status --short
git diff --staged
```

After a targeted commit, the postflight pipeline runs `git status --porcelain` and logs a
warning if the working tree is still non-empty — this surfaces (rather than hides) any gap
between what was staged and what actually changed.

## State-Write Serialization and Honest Commit Messages

This scoped-staging rule governs WHAT gets staged for a commit; it does not, by itself, say
anything about ordering the underlying writes to the shared files it stages. `specs/state.json`
in particular is mutated by several independent read-modify-write round trips per postflight run
(status update, artifact-number increment, completion-data writes, memory-candidate propagation,
artifact linking), each of which reads the file, transforms it, and writes it back —  a shape
that is only ever safe against a SINGLE writer at a time. `orchestrator-postflight.sh` now
brackets that entire read-modify-write-plus-`TODO.md`-regen window (its Stages 7 through 8a) in
the `specs/.scope-lock/` mutex documented in `task-lock.md`'s "Scope-Mutex CLI" section, so two
concurrent postflight runs on DIFFERENT tasks can no longer interleave their state.json writes
and silently lose one session's update.

**Correction to an earlier version of this section**: this serialization was previously described
as stopping at the state-write window, with `git add`/`git commit` (Stage 9 and later) deliberately
left "explicitly outside the mutex... a slower git/TTS/cleanup tail carries no data-integrity risk
worth serializing." That reasoning was sound when the only committer was a single sequential
postflight process, but concurrent multi-task dispatch invalidated it: two simultaneously
dispatched agents' `git add` + bare `git commit` pairs on the shared index is exactly the
misattribution defect "Commit-Level Path Scoping and Cross-Process Serialization" above describes.
Stage 9 still stays outside the **state-write** mutex (`specs/.scope-lock/`, released before
Stage 8b) — that boundary is unchanged and still correct, since state.json's read-modify-write
concern is unrelated to committing. But Stage 9 now runs INSIDE a second, distinct **commit**
mutex (`specs/.commit-lock/`, via `git-commit-scoped.sh`) for the whole duration of its `git add` +
`git commit` pair. Both statements are true simultaneously: "outside the state-write mutex" and
"inside the commit mutex" describe two different, non-overlapping critical sections guarded by two
different mutexes — see `task-lock.md`'s two-mutex documentation for why one mutex could not serve
both.

Because the staging rule above still allows `specs/state.json` and `specs/TODO.md` to legitimately
carry OTHER tasks' current rows in a given commit (they are shared, wholesale-regenerated index
files — see Per-Operation Scope above), `orchestrator-postflight.sh`'s Stage 9 now also runs a
staged-diff scan immediately after `git add` and before `git commit`: it compares the just-staged
`specs/state.json` against `HEAD`'s, entry-by-entry on parsed `active_projects` records (never a
raw `+`/`-` line diff, which would miss a changed field sitting inside an unchanged
`project_number` context line), and appends a body line naming every OTHER task whose index rows
the commit carries — e.g. `Also carries current index rows for tasks: 42, 57`. This does not
change staging scope or serialization; it makes an already-legitimate outcome (a commit
mentioning one task while its diff includes other tasks' current index rows) honestly labeled
rather than silently attributed to the named task alone. The scan is entirely failure-tolerant:
any error (missing `HEAD` file on a first commit, unparseable JSON, no staged `state.json`) omits
the addendum and falls through to the plain commit message — it must never break a commit.

## Related Documentation

- `.claude/context/formats/return-metadata-file.md` — `modified_files` field schema, and its
  "Multiple Sequential Writers" subsection for the read-modify-write invariant a later writer to
  `.return-meta.json` (e.g. the orchestrator postflight stage) MUST follow
- `.claude/context/formats/progress-file.md` — `files_touched` per-objective field
- `.claude/scripts/orchestrator-postflight.sh` — Stage 9 execution site
- `.claude/scripts/git-commit-scoped.sh` — the single sanctioned implementation of commit-level
  path scoping plus commit-mutex serialization (see "Commit-Level Path Scoping and Cross-Process
  Serialization" above)
- `.claude/rules/git-workflow.md` — Never Run list and Commit Scope section
- `.claude/skills/skill-git-workflow/SKILL.md` — canonical documentation front
- `.claude/context/patterns/task-lock.md` — the `specs/.scope-lock/` scope-mutex CLI
  (`scope-acquire`/`scope-release`) that brackets the state.json read-modify-write window
  referenced above, AND the sibling `specs/.commit-lock/` commit-mutex CLI
  (`commit-acquire`/`commit-release`) that `git-commit-scoped.sh` uses to serialize commits
- `.claude/context/standards/orchestrator-runtime-files.md` — the two-class ephemeral/durable
  policy the canonical exclusion set above implements, with the full freshness-gate rationale
- `.claude/scripts/orchestrate-cycle-postflight.sh` — the per-task commit site
  that applies the "Multi-Task Application" scope above once per task
- `.claude/docs/architecture/orchestrate-state-machine.md` — MT Mode's Commit Granularity
  subsection, and `.claude/context/patterns/batch-orchestration-guardrails.md` — hazard 2's
  retirement record
- `.claude/scripts/lint/lint-scoped-commit-boundary.sh` — the mechanical guardrail against
  regrowth of the raw `git add` + bare `git commit -m` anti-pattern this doc describes; wired as
  `verify-deploy.sh` gate 17
- `.claude/scripts/lint/lint-directory-pathspec-boundary.sh` — the complementary mechanical
  guardrail against the OPPOSITE failure mode: a `git-commit-scoped.sh` call that correctly ends
  in a trailing pathspec, but that pathspec is itself a bare SHARED directory (e.g. `-- specs/`
  or `-- .memory/`) rather than the explicit file list this doc's per-operation scopes require.
  It deliberately does not flag the sanctioned task-scoped directory form (`-- "${task_dir}/"`,
  `-- "specs/${padded_num}_${slug}/reports/"`) described above. Wired as `verify-deploy.sh`
  **gate 23**, a blocking gate — deliberately placed as a trailing gate rather than inserted
  beside gate 17: insertion there would renumber gates 18-22, silently invalidating the heavy
  by-number citations those gates carry elsewhere in the system (gate 20 alone is cited in over a
  hundred files). A green gate 23 certifies "no bare shared-directory pathspec token, as written"
  — it does not certify that pathspecs are correct.

  **Ruling: the exempted task-scoped directory form stays as-is.** It is deliberately not
  narrowed to explicit file lists, for four reasons. (a) The over-stage it permits is confined to
  one task's own territory — its own directory — so the cross-session bleed across unrelated
  tasks' files that motivated the explicit-file-list rule above does not apply here. (b)
  `git-commit-scoped.sh` already injects `:(exclude)` entries for the canonical
  ephemeral-runtime-file candidate set (see "Canonical Runtime-File Exclusion Set" above) at
  exactly these directories, so the known-risky content inside a task's own directory is already
  carved out mechanically, not left to the pathspec shape. (c) The per-task dispatch lock in
  `context/patterns/task-lock.md`, acquired at the shared command preflight gate, prevents two
  dispatches against the same task number from running concurrently — the scenario a concurrent
  in-place artifact write within that one directory would require. (d) Converting the roughly
  three dozen sanctioned sites to explicit file lists would require, at every one of them, the
  both-endpoints rename audit the "Rename and Directory-Move Staging" section above mandates for
  any directory-token-to-explicit-list conversion — a real and recurring correctness cost, not a
  one-time mechanical substitution.

  This ruling is not immune to a real counter-argument, which is answered here rather than left
  unaddressed: the contended-path lease (`git-commit-scoped.sh`'s V5 block) compares pathspec
  tokens against contention-manifest entries by exact string equality, so a directory token can
  never match a file-path manifest entry and bypasses the lease by construction at these sites.
  The answer: the manifest is populated only from cycle-dispatched tasks' own declared
  `file_scope` entries, which are source-tree paths rather than another task's own artifact
  directory, so the bypassed check has nothing to match at these sites in practice — and where a
  shared `specs/` index file (`TODO.md`, `state.json`) *is* genuinely contended, it is staged by
  its own explicit path at the sites covered above, never swept in by a directory token.
