# Research Report: Reframe Docs for Ignored-Specs Default

**Task**: Reframe every surface that asserts the specs tree is committed, so an ignored one
reads as the supported default rather than a broken state, and place the durability statement
beside it.
**Started**: 2026-11-19T00:00:00Z
**Completed**: 2026-11-19T00:00:00Z
**Effort**: research-only, no implementation
**Dependencies**: None (consumes the completed outputs of four sibling tasks — see Sources below)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/**`), the four predecessor tasks'
reports/summaries, no web search needed
**Artifacts**: `specs/662_reframe_docs_for_ignored_specs_default/reports/01_reframe-docs-ignored-specs.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The grep-assembled surface list in the dispatch is a useful starting point but is imprecise on
  direct reading: `rules/artifact-formats.md` contains **no** specs-is-committed assertion at
  all and needs no edit; `rules/state-management.md` likewise contains no explicit git-commit
  invariant (the real invariant lives in `rules/git-workflow.md`'s "Commit Timing" table and the
  three `context/processes/*-workflow.md` files' "Create Git Commit" steps).
- The sharpest, most load-bearing violation is NOT in the named list: `docs/architecture/orchestrate-state-machine.md`'s
  `stall_suspected` detector is explicitly **commit-gated** ("`git log --since=@<dispatch_start_ts>`
  over the task directory counts at least one commit") and its "Exit-path coverage" table asserts
  every MT terminal outcome's "artifacts and status changes it produced are real and committed."
  Under the ignored posture, a `plan`-phase dispatch that touches only `specs/**` paths produces
  **zero** commits even on full, successful completion — the signal this mechanism relies on to
  distinguish "real work, abandoned wrap-up" from "genuine failure" degrades silently for exactly
  the class of dispatch the ignored posture makes routine. This needs an explicit caveat, not
  just a word change, because it is a behavioral gap in a detection mechanism, not merely stale
  prose.
- A second sweep-only discovery: `docs/templates/README.md`'s "8-Stage Workflow Pattern" states
  three times, unconditionally, that Stage 7 validation requires "git commit created" — generic
  guidance for any future command/skill author, with no posture qualifier at all.
- The two exemption standards the dispatch protects (`task-reference-exemptions.md`,
  `record-version-exemptions.md`) already state their enforcement scans "every **git-tracked**
  file... via `git ls-files`" and already parenthesize "(so gitignored/vendored/generated paths
  are excluded by construction)" — this is **already correct** for both postures and needs no
  framing change. This confirms the "stays exactly as it is" instruction is already satisfied.
- The durability statement task 661 drafted has one clearly best placement: the end of
  `context/standards/orchestrator-runtime-files.md`'s "Fresh-Repo Default: Whole `specs/` Tree
  Ignored" section, immediately after its "Manual opt-in runbook" subsection — the one place in
  the corpus that already walks a reader through choosing between the two postures.

## Context & Scope

This is the sixth and last task in a group that makes an ignored `specs/` tree a first-class,
supported default posture alongside the existing tracked posture. The four predecessor tasks
that landed the mechanism are the ground truth for what this task now documents:

- **Task 658** added `scripts/lib/specs-ignore-lib.sh` (the `specs_tree_is_gitignored`/
  `path_is_gitignored` predicates) and `git-commit-scoped.sh`'s `V13` gate, which turns an
  all-ignored or partially-ignored pathspec into non-failure exit codes `8` (wholly ignored) and
  `9` (partial, with trackable siblings still committed) instead of the previous
  staging-failure-shaped exit `2`.
- **Task 659** made this skip durable without demoting the task: `orchestrate-cycle-postflight.sh`
  fires a deduped `issue-record.sh` entry (task context) or `git-commit-scoped.sh` fires an
  `events-append.sh` deviation line (no task context), and `context/standards/absent-specs-git-history.md`
  now gives a per-reader stated answer for every git-history reader named by that dispatch.
- **Task 660** made the ignored posture the actual default: `init-specs.sh` writes a repo-root
  managed `/specs/` ignore block on a fresh repository (nothing yet tracked under `specs/`), never
  touches an already-tracked repository, and `check-runtime-file-tracking.sh`'s Check C is now
  posture-aware. `context/standards/orchestrator-runtime-files.md` documents this split and a
  manual opt-in runbook for switching postures.
- **Task 661** evaluated durability options for an ignored, unbacked `specs/` tree and recommends
  Option D (document the exposure, build no mechanism), with a drafted statement for this task to
  place verbatim.

This task's own scope, per its dispatch: sweep the documentation corpus for every surface that
states or implies, as an invariant, that the `specs/` tree is committed to git, and reframe each
so it states the behavior under BOTH postures — never describing the tracked posture as
deprecated or superseded, since it remains fully supported and is this repository's own posture
(11,643 tracked files as of this research pass). The two task-reference/record-version exemption
standards are explicitly out of scope for reframing (confirmed below to already be correct). This
report is research only; it does not edit any file under `agent-system/**`.

## Findings

### Codebase Patterns

**Verified against the dispatch's five named surfaces by direct reading** (not by grep alone):

| Surface | Current state | Needs reframing? |
|---|---|---|
| `rules/state-management.md` | File-sync and canonical-source sections describe TODO.md/state.json update mechanics only; contains no explicit "specs is committed" assertion. | **No** — nothing to change here. The dispatch's description text names this file but the actual invariant lives elsewhere (see git-workflow.md and the process-workflow files below). |
| `rules/artifact-formats.md` | Placeholder conventions, artifact naming, phase markers, versioning, TODO.md linking format. Contains no commit-related assertion at all. | **No** — confirmed by full read; no edit needed. |
| `rules/git-workflow.md` | "Commit Timing" -> "Create Commits After" lists five lifecycle events (task creation, research completion, plan creation, each implementation phase, final implementation, archival) as an unconditional post-condition list, with no posture qualifier. | **Yes** — this is the clearest invariant-as-written in the named list: it reads as "a commit always lands after X," which is true only under the tracked posture. Needs a sentence stating that under the ignored posture these same lifecycle events still fire a commit *attempt* (via `git-commit-scoped.sh`), which correctly reports a non-failure skip (exit 8/9) rather than creating a commit, and that this is expected, not a gap. |
| `context/processes/research-workflow.md`, `planning-workflow.md`, `implementation-workflow.md` | Each has a near-identical "Step N: Create Git Commit" stage ending in `**Checkpoint**: Git commit created`, and a "Git Commit Failed (non-critical)" error template whose remedy is "Manual commit required: `bash .claude/scripts/git-commit-scoped.sh ...`". These frame "commit created" as the only successful outcome and "commit failed" as the only unsuccessful one — the V13 non-failure skip is a third, uncovered outcome shape. | **Yes**, for research-workflow.md and planning-workflow.md as live-reading documents. **Caveat for implementation-workflow.md**: see below — this file carries its own pre-existing `**SUPERSEDED**` header stating it is "referenced by nothing in the live context-loading chain" and describes a `resume_phase` pattern the current implementation agent does not use. Confirmed by grep: none of the three files are referenced anywhere outside `index-entries.json` (a searchable index, not a loading chain) and one unrelated `root-files/settings.local.json` hit. |
| `docs/architecture/orchestrate-state-machine.md` | See "A Load-Bearing Gap, Not Just Stale Prose" below — this is the most consequential surface found, named in the dispatch's list but under-described by it. | **Yes**, with the highest priority of the group. |

**Sweep findings beyond the named list** (the dispatch explicitly asked for this, warning its
own list "was assembled by grep, not by reading"):

- **`docs/templates/README.md`**'s "8-Stage Workflow Pattern" (the generic template new
  commands/skills are built from) states three times, with no posture qualifier: Stage 7 is
  "Validate artifacts, update TODO.md, state.json, **create git commit**"; "Critical: Stage 7
  must be fully implemented. Stage 7 failures cause system-wide reliability issues"; "Validate
  Stage 7: Ensure artifacts validated, TODO.md updated, **git commit created**"; "Test Stage 7:
  Verify TODO.md, state.json, **git commit created**." A future skill/agent author reading this
  template in isolation would reasonably treat "git commit created" as a hard success criterion,
  which is false under the ignored posture for a specs-only Stage 7.
- **`commands/todo.md`**'s "### 6. Git Commit" step runs `git-commit-scoped.sh` against an
  explicit `stage_paths` array built entirely from `specs/**` paths (`specs/TODO.md`,
  `specs/state.json`, `specs/archive/state.json`). Under the wholly-ignored posture this call
  would hit `V13` and return exit `8` (no commit, non-failure) for every `/todo` archival
  operation — a correct, benign outcome, but the document never mentions this possibility or
  states that `/todo`'s archival step is expected to be a no-op commit under that posture. Lower
  priority than the three above since the mechanism already handles it safely; the gap is purely
  documentary.
- **`context/standards/git-staging-scope.md`** and **`context/standards/absent-specs-git-history.md`**
  (both edited by tasks 658/659) already carry the correct, dual-posture framing and need no
  further change. `git-staging-scope.md`'s "## Per-Operation Contract: Tracked vs. Gitignored
  `specs`" section is the best existing model for how the reframed surfaces above should read —
  see Recommendations.
- **`context/standards/orchestrator-runtime-files.md`** (edited by task 660) already has the
  "Fresh-Repo Default: Whole `specs/` Tree Ignored" section with a "Manual opt-in runbook"
  subsection walking a reader through switching an already-tracked consumer to the ignored
  posture. This is the natural home for the durability statement — see Recommendations.

### A Load-Bearing Gap, Not Just Stale Prose (`orchestrate-state-machine.md`)

Two passages in this document assert, as a matter of course, that lifecycle work is committed:

1. **"### Commit Granularity"**'s "Exit-path coverage" table states, for the `failed` and
   `blocked` outcome rows: "Move 3's postflight body still runs for a failed dispatch; artifacts
   and status changes it produced are real and committed." Under the ignored posture this is
   false for a specs-only change set: the artifacts are real, but nothing is committed — `V13`
   reports exit `8`/`9` instead.
2. **"### The mechanical signal"** (the `stall_suspected` detector): "`orchestrate-cycle-postflight.sh`
   emits `stall_suspected` for exactly the second row: phase is `plan` or `implement`, no outcome
   was recovered, and `git log --since=@<dispatch_start_ts>` over the task directory counts at
   least one commit." The whole point of this detector is to distinguish "real work got committed,
   then wrap-up was abandoned" (treat as recoverable) from "genuine failure, nothing happened"
   (treat as `failed`). Its only signal is a commit count. A `plan`-phase dispatch under the
   ignored posture that writes a complete, correct plan file and then abandons its closing
   artifacts will show **zero** commits for that task directory — not because nothing happened,
   but because nothing specs-only ever commits under that posture. The detector's binary
   (`stall_suspected=true` iff commit count >= 1) therefore silently biases toward `failed` for
   exactly the dispatches the ignored posture makes routine (plan-phase work is specs-only by
   construction in the common case).

   The document itself already names a structurally similar blind spot for a different reason
   (`stranded_suspected`'s own text: "that conjunction has a blind spot: the measured total-loss
   instance... wrote no report, made no commit, and `stall_suspected`'s own commit-gated trigger
   could not see it by construction"), and already resolves it with a heartbeat-based detector
   that is explicitly "NOT [gated] on any commit count." That existing resolution is evidence this
   gap is already anticipated in spirit, just not yet connected to the ignored-specs posture in
   writing — `stranded_suspected`'s heartbeat/quiescence signal is the one of the pair that still
   functions correctly for a specs-only plan-phase dispatch under the ignored posture;
   `stall_suspected`'s commit count does not.

This is why the dispatch's instruction to "revise" rather than just "note" matters here: the
fix most consistent with the rest of the document's own stated design is a sentence in "### The
mechanical signal" stating that under the ignored posture, zero commits for a `plan`-phase task
directory is the EXPECTED outcome of fully successful work (not just of total failure), that
`stall_suspected`'s commit-gated signal therefore does not fire for that case, and that
`stranded_suspected`'s heartbeat-based signal is the one that still covers it. This is a
documentation-only fix (stating the known behavior and which existing detector covers the gap) —
it does not require changing `orchestrate-cycle-postflight.sh`'s code, since `stranded_suspected`
already exists and already has no commit-count precondition.

### External Resources

Not consulted — this is a closed, internal-corpus documentation sweep; no external best-practice
research applies.

## Recommendations

1. **Use `git-staging-scope.md`'s "Per-Operation Contract: Tracked vs. Gitignored `specs`" as the
   template pattern** for every reframed surface: state what the two postures share unconditionally
   (the computed staging list, the lifecycle event itself happening), then state what differs (the
   outcome/exit code/commit presence), explicitly declining to call either posture deprecated.
2. **`rules/git-workflow.md`**: add a short paragraph (or a table footnote) under "Commit Timing"
   stating that each listed lifecycle event still attempts its commit under either posture; under
   a wholly-or-partly ignored `specs/` tree the attempt reports a non-failure skip (`git-commit-scoped.sh`
   exit `8`/`9`) rather than creating a commit for the ignored members, and this is the supported,
   expected behavior for that posture — point to `git-staging-scope.md`'s contract section rather
   than re-deriving it.
3. **`context/processes/research-workflow.md`** and **`planning-workflow.md`**: in each "Step N:
   Create Git Commit" stage, add a third branch alongside "commit succeeds" / "commit fails
   (non-critical)" — "commit reports a posture skip (non-failure)" — and soften
   `**Checkpoint**: Git commit created` to something that is true under both postures (e.g.
   "commit attempted; outcome recorded per posture"). Do not invent new prose patterns; mirror the
   phrasing `absent-specs-git-history.md` already uses for "the repository's own configuration,
   not a defect."
4. **`context/processes/implementation-workflow.md`**: apply the same edit for consistency with
   the other two process-workflow files (the dispatch names all three), but flag to whoever plans
   this that the file is already marked dead (`**SUPERSEDED**`, not referenced by the live
   context-loading chain). The minimal-correct action is the same posture-split sentence added
   for consistency and so a future reader opening the file in isolation is not misled twice over
   (once by the stale `resume_phase` pattern, once by the stale commit-is-the-only-outcome
   framing) — but this is lower operational priority than items 2, 3, and 5, since nothing live
   consults this file's commit-step prose today.
5. **`docs/architecture/orchestrate-state-machine.md`** (highest priority):
   - In "### Commit Granularity"'s exit-path table, qualify the `failed`/`blocked` rows' "real and
     committed" language to "real, and committed unless the change set is specs-only under an
     ignored posture, in which case it is real and recorded via the V13 skip channel instead" (or
     point to `absent-specs-git-history.md`'s recording contract rather than restating it).
   - In "### The mechanical signal", add the sentence described above: zero commits for a
     `plan`-phase task directory under the ignored posture is an expected outcome of successful
     work, not evidence of failure; `stranded_suspected` (not `stall_suspected`) is the detector
     that still covers this case, by design, since it is not commit-gated.
6. **`docs/templates/README.md`**: soften all three "git commit created" lines in the 8-Stage
   Workflow Pattern to posture-neutral language (e.g. "commit attempted, outcome recorded per the
   repository's tracked/ignored posture") so a future command/skill author does not treat commit
   creation as a hard, unconditional Stage 7 success criterion.
7. **`commands/todo.md`**: optional, lower priority — add one sentence to "### 6. Git Commit"
   noting that under the wholly-ignored posture this step's commit reports a non-failure skip
   (exit 8) for every archival run, same as any other `specs`-scoped commit.
8. **Durability statement placement**: insert task 661's drafted statement verbatim at the end of
   `context/standards/orchestrator-runtime-files.md`'s "Fresh-Repo Default: Whole `specs/` Tree
   Ignored" section, immediately after the "Manual opt-in runbook" paragraph and before
   "## Untracking Already-Committed Ephemeral Files" — this is the one place in the corpus that
   already walks a reader through choosing between the two postures, so the durability tradeoff
   belongs exactly there rather than in a new, disconnected location. Optionally cross-reference
   it (a one-line pointer, not a duplicate) from `rules/git-workflow.md`'s reframed "Commit Timing"
   section, since that is where a reader first learns commits are posture-dependent.
9. **No change needed**: `rules/state-management.md`, `rules/artifact-formats.md`,
   `context/standards/git-staging-scope.md`, `context/standards/absent-specs-git-history.md`,
   `context/standards/task-reference-exemptions.md`, `context/standards/record-version-exemptions.md`.
   The last two are explicitly protected by the dispatch and were independently confirmed correct
   below (Decisions).

## Decisions

- **The two exemption standards require no framing change.** `task-reference-exemptions.md`'s
  "## Enforcement" section states its repo-wide lint "enumerates every git-tracked file in the
  repository via `git ls-files` (so gitignored/vendored/generated paths are excluded by
  construction)," and `record-version-exemptions.md`'s own lint is "modeled on
  `check-task-references.sh`" with the identical `git ls-files`-based enumeration. Both already
  self-exclude gitignored paths by construction, independent of whether `specs/` happens to be
  one of them. Their framing never assumed `specs/` is tracked — it is scoped to "every git-tracked
  file," which already degrades correctly when `specs/` is gitignored. This confirms the dispatch's
  "stays exactly as it is" instruction is already true today and needs no edit.
- **`rules/state-management.md` and `rules/artifact-formats.md` are dropped from the edit set.**
  Both were named in the dispatch's grep-assembled list, but a full read of each (not just a grep
  match) found no commit-invariant assertion in either file. Recording this explicitly so the
  planning phase does not spend a phase "fixing" files that need no fix.
- **`docs/architecture/orchestrate-state-machine.md` is treated as the highest-priority surface**,
  ahead of the three process-workflow files, because its gap is behavioral (a detector's signal
  silently degrades for a routine case under the new default) rather than purely descriptive. The
  fix recommended above is still documentation-only (stating the known behavior and naming the
  detector that already covers it), not a request to change any script's logic.

## Risks & Mitigations

- **Risk**: reframing `orchestrate-state-machine.md`'s commit-gated language could be read as an
  invitation to also change `orchestrate-cycle-postflight.sh`'s actual `stall_suspected`
  computation. **Mitigation**: the recommendation above is explicit that `stranded_suspected`
  already exists and already has no commit-count precondition — the fix is to document which
  existing detector covers the ignored-posture case, not to alter either detector's code.
- **Risk**: a reframe that adds "under the ignored posture, zero commits is expected" language to
  multiple surfaces, worded slightly differently each time, could drift out of sync the same way
  the pre-task-658 exit-code handling once did across call sites. **Mitigation**: point every
  reframed surface at `git-staging-scope.md`'s "Per-Operation Contract" section and
  `absent-specs-git-history.md`'s recording contract rather than re-deriving the explanation in
  each location — both are already the single source of truth for this behavior.
- **Risk**: `implementation-workflow.md`'s pre-existing `**SUPERSEDED**` header itself appears to
  violate `rules/no-record-versioning-in-deliverables.md`'s prohibition on "supersedes"/"no longer
  current" framing outside `specs/**`. **Mitigation/scope note**: this is a pre-existing condition
  unrelated to the specs-committed reframe and is out of this task's declared scope; not fixing
  it here, but flagging it so it is not mistaken for something this task introduced or is
  expected to resolve.

## Context Extension Recommendations

- **Topic**: a single canonical "posture-neutral commit outcome" phrasing for documentation.
- **Gap**: five-plus surfaces each independently describe "what happens when a commit is
  attempted," with growing risk of divergent wording as more surfaces adopt the posture split
  (this task adds at least four more: git-workflow.md, the two live process-workflow files,
  orchestrate-state-machine.md, docs/templates/README.md).
- **Recommendation**: no new standards file — `git-staging-scope.md`'s "Per-Operation Contract:
  Tracked vs. Gitignored `specs`" section already serves this role; every reframed surface should
  link to it by name rather than restate it, consistent with how `absent-specs-git-history.md`
  already does this for git-history readers.

## Appendix

- Search queries used: none (web search not invoked; closed internal-corpus sweep).
- Codebase surfaces read in full: `rules/state-management.md`, `rules/git-workflow.md`,
  `rules/artifact-formats.md`, `context/processes/research-workflow.md`,
  `context/processes/planning-workflow.md`, `context/processes/implementation-workflow.md`
  (headers, modes, commit steps, error templates), `docs/architecture/orchestrate-state-machine.md`
  (Commit Granularity through the Strand Variant sections), `context/standards/task-reference-exemptions.md`,
  `context/standards/record-version-exemptions.md` (Enforcement sections),
  `context/standards/git-staging-scope.md` (Per-Operation Contract section),
  `context/standards/orchestrator-runtime-files.md` (Fresh-Repo Default section),
  `context/standards/absent-specs-git-history.md` (in full), `docs/templates/README.md`,
  `commands/todo.md` (Steps 5-6).
- Grep sweeps run (repo-relative to `agent-system/extensions/core/`):
  `specs.*committed|committed.*specs|specs tree|specs.*git history|git history.*specs|TODO.md.*commit|state.json.*commit`
  across all `*.md`; targeted follow-up greps on each hit; a reference-check grep for
  `research-workflow.md|planning-workflow.md|implementation-workflow.md` across the whole
  extension to establish live-vs-dead loading status; a grep for
  `track|commit|git history` inside both exemption standards.
- Predecessor artifacts consulted in full: `specs/658_ignored_specs_predicate_and_commit_path/summaries/01_ignored-specs-predicate-commit-path-summary.md`,
  `specs/659_never_demote_on_ignored_specs_skip/summaries/01_never-demote-ignored-specs-skip-summary.md`,
  `specs/660_init_specs_ignores_specs_by_default/summaries/01_init-specs-ignores-by-default-summary.md`,
  `specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md`,
  `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`.
