# Research Report: Task #336

**Task**: 336 - Rule on the in-dispatch phase-commit staging surface: fifteen implementation
agents commit with no file_scope check and no contended-path lease
**Started**: 2026-10-07T00:00:00Z
**Completed**: 2026-10-07T00:00:00Z
**Effort**: medium
**Dependencies**: None (declared explicitly; see Context & Scope)
**Sources/Inputs**: Codebase (agent-system/extensions/**, scripts/git-commit-scoped.sh,
scripts/lib/territory-contention-lib.sh, scripts/orchestrate-cycle-plan.sh), specs/state.json,
specs/TODO.md (sibling task 335, --task-wiring task 302, out-of-repo-pathspec task 304)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `--task {N}` alone does **not** address the observed defect. Traced to source
  (`build_contended_manifest` in `scripts/lib/territory-contention-lib.sh`): a path only enters
  the contention manifest when **two or more** tasks' declared `file_scope` name it. A path
  declared by **zero** tasks — the observed shape (nine undeclared Typst files) — is
  structurally invisible to the manifest and the V5 lease never fires for it, with or without
  `--task`. `--task` closes a different hazard (concurrent same-file dispatch between two tasks
  that both declared the path), not the undeclared-path hazard this task was filed over.
- Ruling: **both** mechanisms are needed, at two different layers, because they answer two
  different questions (Overlap vs. Containment, per `file-footprint-overlap.md`):
  1. **Now, within this task's file_scope** (the 15 agent `.md` files): add `--task {N}` to the
     recipe uniformly (closes the contended-path gap, cheap, matches task 302's per-site
     uniformity norm) **and** add a documented pre-commit self-check step that compares the
     phase's about-to-stage paths against the task's own declared `file_scope`
     (Containment predicate) before invoking `git-commit-scoped.sh`, dropping and loudly warning
     on any uncontained entry rather than silently committing it — mirroring the already-settled
     "under-stage, never over-stage" fail-safe direction from `git-staging-scope.md`.
  2. **Follow-up, out of this task's file_scope**: a mechanical containment check inside
     `git-commit-scoped.sh` itself, behind a new opt-in flag (or an extension of `--task`'s
     existing semantics), is the only mechanism that cannot be forgotten by a sixteenth agent
     definition. This requires a `git-commit-scoped.sh` change and a new/reused exit code,
     coordinated with task 304 (owner of that script's exit-code contract). Recorded here as a
     follow-up, not implemented.
- The mid-dispatch asymmetry (item 2 of the dispatch) is real and load-bearing: a phase commit
  has no postflight in scope and no cycle manifest guarantee, so the fix cannot be sited in
  `orchestrate-cycle-postflight.sh` (that is task 335's layer, and 335's own description
  concedes it cannot reach this surface either).
- Uniformity: the defect is byte-identical in shape across all fifteen definitions (verified: a
  zero-count `--task` grep against every file), so the ruling applies uniformly to all fifteen;
  no per-extension exception is justified.

## Context & Scope

**What was researched**: the commit recipe shared by fifteen implementation-agent definitions
(enumerated in the dispatch and re-verified below), the mechanics of `git-commit-scoped.sh`'s
`--task` flag and its V5 contended-path lease, the `build_contended_manifest` function that
feeds it, the existing `git-staging-scope.md` "under-stage, never over-stage" fail-safe
precedent used by the sibling task (335) at the postflight layer, and the empirical commit cited
in the task description.

**Constraints carried over from the dispatch** (restated for anyone reading this report without
the dispatch file):
- Source-store edit target only: `agent-system/extensions/**`, never `.claude/**`.
- `file_scope` is exactly the fifteen agent `.md` files (confirmed directly from
  `specs/state.json`'s `active_projects[] | select(.project_number==336)`); no test file, no
  `scripts/git-commit-scoped.sh`, no `context/standards/*.md` file is in scope.
- No dependencies declared; this task owns the surface, not a dependency chain.
- Out of scope: the postflight excursion gate (task 335), the nine recipe sites of the
  `--task`-wiring task (302), what `file_scope` means or how it is harvested, and any change to
  `git-commit-scoped.sh` itself (recorded as a follow-up per item 3 of the dispatch).

## Findings

### Codebase Patterns

**The surface, re-verified (not merely restated from the dispatch).** A direct grep against
every one of the fifteen files for `--task` occurrences:

```
books-implementation-agent.md             --task=0  commit-recipe-occurrences=1
books-implementation-hard-agent.md        --task=0  commit-recipe-occurrences=1
general-implementation-agent.md           --task=0  commit-recipe-occurrences=6
cslib-implementation-hard-agent.md        --task=0  commit-recipe-occurrences=1
founder-implement-agent.md                --task=0  commit-recipe-occurrences=5
latex-implementation-agent.md             --task=0  commit-recipe-occurrences=1
lean-implementation-agent.md              --task=0  commit-recipe-occurrences=1
lean-implementation-hard-agent.md         --task=0  commit-recipe-occurrences=2
nix-implementation-agent.md               --task=0  commit-recipe-occurrences=1
neovim-implementation-agent.md            --task=0  commit-recipe-occurrences=1
python-implementation-agent.md            --task=0  commit-recipe-occurrences=1
rust-implementation-agent.md              --task=0  commit-recipe-occurrences=1
typst-implementation-agent.md             --task=0  commit-recipe-occurrences=1
web-implementation-agent.md               --task=0  commit-recipe-occurrences=1
z3-implementation-agent.md                --task=0  commit-recipe-occurrences=1
```

All fifteen are confirmed at zero. `general-implementation-agent.md` and
`founder-implement-agent.md` carry the recipe at multiple sites (per-objective green-substep
commit plus per-phase commit) — both are equally unguarded, and both are covered by this ruling
since the fix is sited per-recipe-invocation, not per-file.

**Read `git-commit-scoped.sh` end to end to settle exactly what `--task` does.** `--task
<task_number>` is opt-in (empty value skips the flag, fails open on any error) and runs ONE
check, the "V5 contended-path refusal," **before** any `git add`:

```bash
# scripts/git-commit-scoped.sh, V5 block
if [ -n "$contention_task_number" ]; then
  contention_manifest_dir="$PROJECT_ROOT/specs/.contention-manifest"
  ...
  for manifest_file in "$contention_manifest_dir"/*.json; do
    jq -e --arg p "$p" '.contended // [] | any(.path == $p)' "$manifest_file" ...
  done
  ...  # claim via task-lock.sh, refuse (exit 3) only if ANOTHER live task holds the claim
```

The check is entirely against `specs/.contention-manifest/${session_id}.json`, a per-cycle file
built once per `/orchestrate` cycle by `build_contended_manifest()`
(`scripts/lib/territory-contention-lib.sh`). Reading that function directly:

```bash
# build_contended_manifest, territory-contention-lib.sh:231-309 (abridged)
if [ "${#tasks[@]}" -lt 2 ]; then rm -f "$manifest_path"; return 0; fi
for ct in "${tasks[@]}"; do
  ct_scope_json=$(... | jq -c '.file_scope // []')
  ...
  path_declarers["$path"]="${path_declarers[$path]:-} $ct"   # UNION of declaring tasks per path
done
...
for p in "${unique_paths[@]}"; do
  ...
  if [ "${#uniq_tasks[@]}" -ge 2 ]; then     # <-- the load-bearing predicate
    ...  # only THEN does $p enter the manifest as "contended"
```

**This is the single fact the whole ruling turns on**: a path enters the manifest, and therefore
becomes something `--task` can ever refuse on, **only if at least two tasks' own declared
`file_scope` name it this cycle**. `path_declarers` is built exclusively from
`.file_scope // []` arrays read out of `specs/state.json`. A path that **no task** declares —
the observed shape, where nine of ten staged Typst files were outside the one task's own
`file_scope` and (by the description's own account) presumably outside every other task's scope
too — has zero entries in `path_declarers`, is never a member of `unique_paths` with
`uniq_tasks >= 2`, and is **never written into any manifest file at all**, in any cycle, under
any `--task` value. `git-commit-scoped.sh`'s V5 block iterates the manifest and finds nothing;
`contended_here` stays `"false"` for that path; no claim is attempted; no refusal occurs. The
commit proceeds byte-identically to a call that omitted `--task` entirely.

This confirms, by direct code trace rather than inference, the dispatch's own claim: "the lease
only covers paths declared by some task, so it does nothing for a path declared by none." A
ruling of "pass `--task` and stop there" would leave the demonstrated-harm case completely
uncaught — it fixes a different, real hazard (two tasks that **both** declare the same path and
dispatch concurrently) but is structurally blind to an **undeclared** path, which is exactly what
`Overlap` (two declared scopes compared against each other) and `Containment` (one concrete path
tested against one scope) mean as *distinct* predicates in
`context/patterns/file-footprint-overlap.md`. `--task`'s V5 lease is an Overlap-family
mechanism; the observed defect needs a Containment-family one.

**The mid-dispatch asymmetry is confirmed, not assumed.** `build_contended_manifest` is called
exactly once, from `orchestrate-cycle-plan.sh`'s live-dispatch section, immediately before the
per-task dispatch-file-build loop, over the FULL set of tasks the orchestrator is about to
dispatch **this cycle**. A phase commit happens later, inside an already-running implementation
agent's own execution, with no cycle-plan step re-running and no guarantee the manifest file from
that agent's own dispatch cycle still exists or is current (a long-running implement dispatch can
outlive several `/orchestrate` cycles of OTHER tasks, each of which could overwrite or remove the
session's manifest file). This matches the dispatch's framing exactly: "no postflight in scope
and no orchestrator engine running the call." Any fix sited in `orchestrate-cycle-postflight.sh`
or `orchestrate-cycle-plan.sh` (task 335's layer) categorically cannot reach this surface, because
neither runs again until the agent returns — confirmed directly against task 335's own
description, which names this task by slug as the owner of the surface it cannot cover: "The
surface where that commit actually happened is a separate task, filed alongside this one
(`phase_commit_staging_has_no_scope_check`)."

**The existing "under-stage, never over-stage" precedent is the right model to reuse, not
reinvent.** `context/standards/git-staging-scope.md`'s "Fail-Safe Direction" section already
settles the house posture for an analogous gap (missing `modified_files` at the postflight
layer): drop the unverifiable entries, warn loudly, never silently include and never refuse the
whole commit. Task 335's own ruling direction for the postflight-layer excursion gate
independently reaches for the identical "drop-and-commit" shape for the same reason: it "matches
... the recorded 'Under-stage, never over-stage' fail-safe direction ... and needs no change to
`git-commit-scoped.sh`'s exit-code contract at all." The same shape transplants cleanly to the
phase-commit layer as the prose-level interim step (see Recommendations).

**Regression case, exercised by code trace rather than live execution.** Running
`git-commit-scoped.sh` for real against this repository's own working tree was deliberately
**not** attempted — it performs a genuine `git commit`, and exercising it live here would
entangle this research session with uncontrolled commits against the actual repo history, which
is unsafe and unnecessary. The pre-fix behavior is instead demonstrated by the code trace above,
which is exhaustive: every branch that could cause V5 to refuse requires the path to appear in
`path_declarers` with `uniq_tasks >= 2`, and an undeclared path can never reach that state by
construction (it is never written to `path_declarers` at all, by any task). This is a structural
proof, not a sampled test — there is no code path in `build_contended_manifest` or the V5 block
that can refuse an undeclared path under any `--task` value, current or future-added, as long as
the manifest's construction remains keyed to `file_scope` declarations.

One apparent discrepancy in the empirical commit was checked and resolved rather than left
unexplained: several of the fifteen recipes (e.g. `books-implementation-agent.md`,
`general-implementation-agent.md`) unconditionally include `specs/TODO.md` and `specs/state.json`
in their `stage_paths`, yet the cited commit's file list carries neither. This is not a
contradiction — `git add` on a byte-identical file stages nothing and contributes no entry to the
resulting commit's diff/file-list. A mid-phase commit where neither file changed since the
previous commit is fully consistent with both files being named in `stage_paths` and absent from
the commit's own file list. No inference about which specific one of the fifteen definitions
produced the cited commit is drawn from this (the dispatch itself only claims the commit's
*shape* matches this surface, not that a specific file is identified) — this report does not
overclaim that correspondence either.

### External Resources

None required. This is a pure mechanism/codebase-mechanics question internal to this
repository's own orchestration scripts; no external library, API, or tutorial is relevant.

## Recommendations

**Ruling on the mechanism (item 1 of the dispatch), with the explicit answer the Acceptance
criterion requires**: neither `--task` alone nor "neither" is correct. `--task` addresses only
the contended-path case (two tasks, both declaring the same path, dispatched concurrently) and
**concedes, by the code trace above, that it does nothing for the undeclared-path case** — the
exact shape of the observed harm. The ruling is **both**, applied at two different layers:

1. **Within this task's file_scope, uniformly across all fifteen definitions**:
   - Add `--task {N}` to every recipe's `git-commit-scoped.sh` invocation. This is cheap
     (fail-open, no behavior change for the common case), closes the real-but-different
     concurrent-dispatch hazard, and brings these fifteen sites into line with the uniformity
     norm task 302 is independently establishing at its own nine sites — two unrelated audits
     converging on the same "pass `--task` everywhere a phase/task owns the commit" norm.
   - Add a documented pre-commit self-check step, immediately before the
     `git-commit-scoped.sh` invocation in every one of the fifteen recipes: read the task's own
     `file_scope` (already available to the dispatched agent — it is read from
     `specs/state.json` at dispatch-build time and is the same array the dispatch file's
     Territory/Description sections are built from), apply the Containment predicate from
     `context/patterns/file-footprint-overlap.md` (exact match, or either side as a
     directory/glob ancestor) to each positive entry of the phase's about-to-stage path list,
     and for any entry **not** contained: drop it from `stage_paths` for this commit, emit a
     loud, named warning (mirroring `git-staging-scope.md`'s existing WARNING wording
     convention), and record it via the dispatch's own `issue-record.sh` call
     (`--kind issue --class scope-excursion` or equivalent) rather than silently committing it.
     This is the "under-stage, never over-stage" direction, transplanted verbatim from the
     postflight layer to the phase-commit layer — never refuse the whole phase commit over this,
     since an agent legitimately touching a file outside its declared scope (e.g. a necessary
     incidental fix) must still be able to land its in-scope work.
   - This closes the undeclared-path gap **today**, at the one layer this task's `file_scope`
     actually reaches, without waiting on the follow-up below.

2. **Recorded as a follow-up, NOT implemented in this task** (per item 3 of the dispatch,
   `scripts/git-commit-scoped.sh` is out of `file_scope`): the durable, uniform fix is a
   mechanical containment check inside `git-commit-scoped.sh` itself, consulted the same way
   `--task` consults the V5 lease today — either as new behavior added to the existing `--task
   <task_number>` flag (look up that task's own `file_scope` from `specs/state.json` directly,
   independent of the cycle contention manifest, and apply Containment to every positive
   pathspec) or as a distinct new opt-in flag. This is the mechanism the dispatch's item 2
   explicitly prefers ("a mechanism that cannot be forgotten by the sixteenth agent definition
   someone adds next") over the fifteen-file prose edit above — prose can be omitted by a new
   agent definition; a chokepoint inside the one script all sixteen-plus definitions call
   cannot. The prose-level self-check in (1) is the necessary interim measure precisely because
   this mechanical fix is out of reach from inside this task's own `file_scope`; it is not a
   substitute for it. This follow-up needs: (a) a new or reused exit code, distinct from V5's
   existing exit 3 (a different predicate — Containment, not Overlap/lease-contention — probably
   warrants its own code rather than overloading exit 3's wording), coordinated with task 304
   (`out_of_repo_pathspec_aborts_whole_commit`), the declared owner of this script's exit-code
   contract; and (b) the same fail-open posture `--task`'s existing V5 block already uses (a
   missing/malformed `file_scope`, or any error reading it, proceeds exactly as today — a
   concurrency/scope guard must never be the reason a commit cannot happen at all).

**Uniformity (item 4 of the dispatch)**: both halves of the ruling apply identically to all
fifteen definitions. The defect is byte-for-byte identical in shape at every site (confirmed by
the zero-count grep above and by reading three representative recipes — `books-`,
`general-`, and `lean-implementation-agent.md` — which share the same `git-commit-scoped.sh`
call shape modulo which variables feed `stage_paths`). No per-extension carve-out is justified; a
divergence here would itself be the kind of defect item 4 warns against.

## Decisions

- **`--task` alone is ruled insufficient** for this task's defect; it is retained as part of the
  answer (for the different, real hazard it does address) but is explicitly not claimed to cover
  the observed undeclared-path case.
- **The mechanism is two-layered**: a prose self-check (implementable now, inside this task's
  `file_scope`) plus a mechanical `git-commit-scoped.sh` extension (a recorded follow-up, out of
  this task's `file_scope`, coordinated with task 304).
- **The self-check's failure mode is drop-and-warn, never refuse-the-whole-commit** — reusing
  the already-settled "under-stage, never over-stage" direction rather than inventing a new
  posture.
- **No dependency edge is added** to task 335, task 302, or task 304. The file-footprint overlap
  with 302/304 is zero (different files); the subject overlap is real but does not imply a
  shared edit target. The follow-up to `git-commit-scoped.sh` is coordination language in this
  report, not a `dependencies[]` entry.
- **The regression case is exercised structurally** (a full code trace of
  `build_contended_manifest`'s `uniq_tasks >= 2` gate, proving no undeclared path can ever enter
  the manifest), not via a live execution against this repository's working tree, which would be
  unsafe and is unnecessary given the trace's exhaustiveness.
- **Uniform application across all fifteen definitions**, no subset ruling.

## Risks & Mitigations

- **Risk**: a prose-only self-check can be skipped or misapplied by a future dispatch of one of
  these fifteen agents, under time or context pressure — the same failure class that let the
  original defect exist unaddressed. **Mitigation**: this is named here as a known, accepted
  residual risk specifically because it is the reason the mechanical follow-up (layer 2) is the
  priority, durable fix; the prose step is explicitly interim, not a claimed permanent solution.
- **Risk**: adding `--task {N}` to all fifteen recipes pulls in `task-lock.sh`'s
  claim-acquire/claim-release machinery at every phase commit. **Mitigation**: negligible —
  `git-commit-scoped.sh`'s own header documents `--task` as fail-open unconditionally (absent
  flag, missing/unreadable manifest, or any internal error all proceed exactly as today), so the
  worst case for a site where nothing is ever contended is a few inexpensive `jq`/directory
  checks per commit, not a new failure mode.
- **Risk**: scope creep into `git-commit-scoped.sh` during implementation, driven by the
  temptation to "just fix it properly in one place" while already inside the fifteen files.
  **Mitigation**: explicitly named in this report and in the dispatch; the implementation phase
  must not widen `file_scope` to reach that script, and must record the mechanical fix as a
  follow-up task reference instead.
- **Risk**: the follow-up task, once filed, could collide with task 304's exit-code ownership if
  filed without reading that task's own description first. **Mitigation**: this report names
  task 304 explicitly as the coordination point; the follow-up filer should read task 304's
  description before proposing a new exit code.

## Context Extension Recommendations

- **Topic**: phase-commit (mid-dispatch) staging scope, as a documented layer alongside the
  existing `research`/`plan`/`implement` operation-type scopes.
- **Gap**: `context/standards/git-staging-scope.md`'s "Per-Operation Scope" section documents
  `research`, `plan`, and `implement` (the whole-task operation types `orchestrator-postflight.sh`
  and `orchestrate-cycle-postflight.sh` drive), but has no corresponding subsection for the
  mid-dispatch, per-phase commit an implementation agent issues on its own, with no postflight
  involved. This gap is exactly what let this task's defect go undocumented as a boundary rather
  than merely unimplemented as a check.
- **Recommendation**: once the follow-up mechanical check lands in `git-commit-scoped.sh` (layer
  2 above), add a "Phase Commit (mid-dispatch)" subsection to `git-staging-scope.md` naming this
  layer explicitly, its lack of a cycle-manifest guarantee, and the Containment-based check that
  guards it — mirroring how this document already explains the `research`/`plan`/`implement`
  layers. Not done as part of this task (the file is not in `file_scope`), named here so the
  follow-up filer inherits the pointer.

## Appendix

- Search/verification commands used (all read-only; no commit or mutation performed against
  this repository during research):
  - `grep -c -- '--task'` and `grep -c "git-commit-scoped.sh"` against each of the fifteen
    `file_scope` entries.
  - Full read of `agent-system/extensions/core/scripts/git-commit-scoped.sh` (header comments
    V1-V7 plus the executable body), to confirm `--task`'s exact behavior and fail-open posture.
  - Full read of `agent-system/extensions/core/scripts/lib/territory-contention-lib.sh`'s
    `_paths_contend` and `build_contended_manifest` functions, to confirm the `uniq_tasks >= 2`
    gate that makes an undeclared path structurally unreachable by the manifest.
  - Targeted reads of `books-implementation-agent.md`, `general-implementation-agent.md`, and
    `lean-implementation-agent.md`'s own commit-recipe sections, to confirm the recipe shape is
    uniform modulo variable names.
  - `jq` reads of `specs/state.json` for task 336's own `file_scope` (confirmed exactly the
    fifteen files, nothing else) and for the sibling/related tasks' titles (335, 302, 304).
  - `sed`/`grep` reads of `specs/TODO.md` for the full descriptions of task 335
    (`gate_modified_files_excursion_at_staging`), task 302 (the `--task`-wiring task), and the
    cross-reference to task 304 (`out_of_repo_pathspec_aborts_whole_commit`).
  - Read of `agent-system/extensions/core/context/standards/git-staging-scope.md`'s "Fail-Safe
    Direction" and "Reference Template" sections, to confirm the "under-stage, never over-stage"
    precedent this report's recommendation reuses.
  - Read of `agent-system/extensions/core/context/patterns/file-footprint-overlap.md`'s Overlap
    vs. Containment distinction, which supplies the precise vocabulary for why `--task`'s V5
    lease (Overlap) cannot substitute for the check this task needs (Containment).
