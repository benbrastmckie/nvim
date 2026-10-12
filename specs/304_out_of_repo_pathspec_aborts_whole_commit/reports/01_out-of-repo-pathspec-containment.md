# Research Report: Task #304

- **Task**: 304 - Stop one out-of-repository pathspec entry from aborting staging for every valid
  path, and stop the callers sinking the script's nonzero exits, while the task still reports
  success
- **Started**: 2026-10-12T11:30:00Z
- **Completed**: 2026-10-12T11:43:00Z
- **Effort**: 1-3 hours
- **Dependencies**: 184, 263, 273, 284, 285, 302 (declared, per-cycle-postflight overlap edges) —
  277, 335, 336 are now all COMPLETED/archived and are discussed below as closed precedent, not
  as pending dependencies
- **Sources/Inputs**: `scripts/git-commit-scoped.sh` (full read, 770 lines), `context/standards/
  git-staging-scope.md`, `context/formats/return-metadata-file.md`, `scripts/
  orchestrate-cycle-postflight.sh`, `scripts/orchestrate-unwind-dispatch.sh`, `scripts/
  orchestrator-postflight.sh` (orphan confirmation), `agents/general-implementation-agent.md`,
  three archived task summaries/plans (277, 335, 336), `specs/state.json`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real, precisely located, and unfixed: `scripts/git-commit-scoped.sh`'s V2
  classification loop still admits an absolute path into a *different* repository into Case 1
  (`[ -e "$p" ]` is a bare filesystem-existence test with no repository-containment check), so
  that one path reaches the single all-or-nothing `git add` and aborts staging for every valid
  sibling path in the same call.
- **The fix belongs at the chokepoint — `git-commit-scoped.sh`'s own drop pass (candidate 1) —
  and nowhere else.** Two sibling, already-completed tasks (335, 336) landed `file_scope`-based
  drop-and-warn filtering at the two wrapper layers (per-cycle postflight commit, phase commit),
  but both are conditional on a declared, non-empty `file_scope` (fail-open otherwise) and both
  test a *different* predicate (declared-scope membership, not repository boundary). Neither
  closes this task's defect universally; both explicitly name this task as the owner of the
  mechanical, caller-independent fix.
- **Premise correction**: the dispatch's framing of task 277 as `not_started` and a live
  ordering hazard is stale. Task 277 completed and archived on 2026-10-02; it adopted the
  narrower V6 gate (exit 4 on a no-commit partial drop), *not* a universal hard-error-on-drop, so
  Case 3 (genuinely unmatched) remains warn-and-drop exactly as this task's own design assumes.
  There is no live ordering hazard to resolve.
- **Ruling (silent vs. loud)**: drop-and-warn, folding the new out-of-repository case into the
  existing `dropped_pathspecs`/V6 machinery rather than inventing a new refusal gate. This beats
  the status quo on both axes — valid paths commit, and the violation is loud (a distinguishing
  `ERROR:`/`WARN:` naming the path and the reason) — without adding a new exit code.
- **Ruling (exit-code sink)**: branch explicitly at the two live script callers
  (`orchestrate-cycle-postflight.sh`, `orchestrate-unwind-dispatch.sh`), but `orchestrate-
  unwind-dispatch.sh` is in practice never exposed to this specific defect (it only ever passes
  two fixed literals, never `modified_files`); the real caller-side work is narrower than the
  dispatch assumed. Do not hand-edit ~50 documentation snippets; add a lint instead.
- **Ruling (cross-repo field)**: do not add a new field. State explicitly in the format spec that
  cross-repository edits are outside `modified_files`'s remit and must be reported in prose
  (`completion_summary`) or an `issues.jsonl` entry, pending operator action.

## Context & Scope

This is a research-only dispatch for task 304 (`task_type: meta`). The task asks research to
rule on WHERE the out-of-repository-pathspec fix belongs, on the silent-filtering-vs-loud-refusal
question, on the cross-repository-edit field question, on the global non-blocking-commit policy,
and on which callers must branch on `git-commit-scoped.sh`'s exit code — not to re-litigate
whether the underlying defect is real (it is, and is reproduced analytically below against the
live script) and not to implement the fix. The dispatch's own PREMISE CORRECTION (the
`modified_files` repo-relative contract is already documented, three times, and that is not the
gap) is accepted as given and is not re-verified here beyond confirming the source-store and
deployed copies of every file this task names are byte-identical (`diff -q` on all four,
`git-commit-scoped.sh`, `test-git-commit-scoped.sh`, `git-staging-scope.md`,
`return-metadata-file.md` — no output, confirmed identical).

Two findings materially extend the dispatch's own framing and are the core of this report:

1. **Task 277 is stale information in the dispatch, not current state.** It is COMPLETED and
   archived (`specs/archive/277_git_commit_scoped_worktree_targeting/`), not `not_started`. Its
   outcome is already live in the script read for this research — see Findings below.
2. **Two more sibling tasks (335, 336), invisible to the dispatch's own file_scope-overlap
   survey because neither is still active, already built adjacent, non-duplicating
   infrastructure, and both explicitly name task 304 as the designated owner of the fix this
   research is now ruling on.** This is the single most load-bearing discovery of this research
   pass and materially sharpens (without displacing) every ruling below.

## Findings

### Codebase Patterns

**The defect, confirmed live and unchanged.** `scripts/git-commit-scoped.sh`'s V2 loop (now
around line 408, shifted down from the dispatch's cited line 292 by the V5/V7/V8 machinery landed
since the dispatch was written) still reads:

```bash
if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
  # Case 1 — matched: present on disk, or already tracked.
  filtered_pathspecs+=("$p")
  add_pathspecs+=("$p")
```

`[ -e "$p" ]` is true for any path that exists on disk, in or out of the repository. An absolute
path into a sibling repository (the observed-damage shape: an agent-system source-store path
under `/home/benjamin/.config/nvim/...` edited while dispatched against
`~/Projects/Logos/Verification`) is admitted into `add_pathspecs`, reaches the single
all-or-nothing `git add "${add_pathspecs[@]}"` call (line ~581), and `git` fails that call fatally
(`fatal: ... is outside repository at '...'`) — aborting staging for every other entry in the same
call. This is exactly the dispatch's OBSERVED DAMAGE transcript, and nothing in the script's
growth since (V5 contention leases, V7 index verification, V8 post-commit integrity) touches this
classification gap; none of them runs before `git add`'s own Case-1 admission.

**Task 277 (completed 2026-10-02) — stale premise, but compatible outcome.** The dispatch
describes 277 as `not_started` and frames its interaction with this task as a load-bearing
ordering hazard ("if 277 lands first and makes every drop a hard error, this task must decide
whether an out-of-repo path is a hard error too"). In fact 277 completed over a week before this
research pass and is archived. Its actual ruling (`specs/archive/
277_git_commit_scoped_worktree_targeting/summaries/01_pathspec-drop-hard-error-summary.md`)
rejected the universal "hard error on drop" option explicitly ("Option (a) ... rejected") in
favor of the narrower V6 gate: refuse (exit 4) only when a drop occurred *and* the commit
attempt produced no commit at all. Case 3 (genuinely unmatched) remains warn-and-drop,
unconditionally, exactly as it was before 277 and exactly as this task's own design assumes. **The
ordering hazard the dispatch worried about does not exist**: there is no universal hard-error
posture to collide with. This is recorded as a premise correction, not a reason to skip the
277 edge in `file_scope` bookkeeping (state.json's own `dependencies` array already omits 277,
correctly, since it no longer needs sequencing).

**Tasks 335 and 336 (both completed, both archived) — adjacent infrastructure, explicitly not a
substitute for this task.** Neither appears in the dispatch's SIBLING-FIELD or
DECLARED-FILE_SCOPE-OVERLAPS sections because neither is active, but both directly bear on this
research's rulings and both name task 304 by number:

- **Task 335** (`specs/335_gate_modified_files_excursion_at_staging/`, completed 2026-10-08)
  promoted an existing detection-only advisory (`orchestrate-cycle-postflight.sh`'s WORK (h):
  compute `excursions_json`, every `modified_files` entry that is not a prefix-match of the
  dispatching task's declared `file_scope`) into an active staging-time filter (WORK (i)): an
  excursion is dropped from the per-cycle commit's `stage_paths` with a loud per-path `EXCURSION
  DROPPED` warning, drop-and-warn, never a whole-commit refusal. Because an absolute path into a
  different repository can never prefix-match a repo-relative `file_scope` entry, this filter
  *would* incidentally have caught the dispatch's own observed-damage shape — **but only if the
  dispatching task declares a non-empty `file_scope`** (the check's own length-guard means an
  absent/empty `file_scope` makes `excursions_json` stay `[]` and nothing is dropped — a
  documented, deliberate fail-open, not an oversight), and **only at this one call site**
  (`orchestrate-cycle-postflight.sh`'s per-cycle commit). Task 335's own summary is explicit and
  careful on this point: *"no artifact claims this gate would have caught the observed
  commit"* — the authors deliberately declined to claim this closes the dispatch's incident,
  because they could not confirm task 154 (the observed-damage task) had declared a `file_scope`.
  Task 335's own Follow-ups section states verbatim: *"If a future ruling needs a distinguishable
  `git-commit-scoped.sh` exit code for 'commit succeeded but dropped a `file_scope` excursion,'
  that is a FOLLOW-UP owned by the out-of-repository-pathspec task [304], which owns that
  exit-code contract."*
- **Task 336** (`specs/archive/336_phase_commit_staging_has_no_scope_check/`, completed
  2026-10-07) landed the parallel mechanism at the *other* commit site this per-cycle filter
  structurally cannot reach: the in-dispatch, mid-phase commit (`git-commit-phase.sh`, invoked
  from every one of 15 implementation-agent definitions). It authored the now-canonical
  "Phase-Commit Containment Self-Check" (quoted in full in `agents/
  general-implementation-agent.md`, confirmed present): drop-and-warn against the task's declared
  `file_scope`, same fail-open posture, same "never refuse the whole commit" ruling, independently
  reached. Task 336 explicitly recorded, as an *unfiled* follow-up specification (`specs/archive/
  336_.../evidence/03_followup-mechanical-check.md`), a proposal to mechanize this same
  `file_scope`-Containment predicate *inside* `git-commit-scoped.sh` itself (as new behavior on
  the existing `--task` flag, or a new opt-in flag) — explicitly because a prose recipe "depends
  on every future agent-definition author remembering to invoke it," unlike a script-level
  chokepoint. That follow-up's own text names its **Coordination Constraint** in full: *"This
  follow-up MUST be coordinated with the task that owns `git-commit-scoped.sh`'s exit-code
  contract — task 304 ... Whoever files this follow-up must read task 304's description before
  proposing any code change to `git-commit-scoped.sh`."*

**Why 335/336 do not obviate this task.** Both wrapper-layer mechanisms test *declared-scope
membership*, not *repository-boundary containment* — a different predicate that happens to
overlap for the specific absolute-path shape in the observed incident, but only conditionally
(file_scope must be declared) and only at the two call sites that currently derive their stage
list from `modified_files`/`files_touched`. Confirmed via `grep`: `scripts/
orchestrate-unwind-dispatch.sh` (the other live script caller of `git-commit-scoped.sh`) commits
only two fixed literals (`specs/state.json specs/TODO.md`), never `modified_files` — it has no
`file_scope`-excursion filter and could not be protected by one, but it is also never exposed to
this defect, because it never passes an agent-supplied path at all. Any *other* future caller of
`git-commit-scoped.sh` — a new command/skill snippet, a hand-typed pathspec, or a 16th
implementation-agent definition that forgets the phase-commit Containment Self-Check (336's own
named residual risk) — has zero protection today. Candidate 1 (the chokepoint fix inside
`git-commit-scoped.sh`'s own V2 classification) is the only mechanism robust to all of these,
independent of `file_scope` declaration, independent of which wrapper a caller goes through, and
is exactly the "durable fix" both 335 and 336 independently converge on and explicitly defer to
this task.

### External Resources

Not applicable — this is a pure codebase/process-history research task; no external
documentation was consulted.

## Decisions

**D1 — Fix site: candidate 1 only.** Land the repository-containment classification inside
`git-commit-scoped.sh`'s own V2 loop, ahead of (or as a refinement of) Case 1's existing
`[ -e "$p" ]` test. Candidate 2 (the postflight/phase-commit consumers) is **already landed**
(tasks 335, 336) for a related but distinct predicate (`file_scope` membership) and needs no
further code from this task beyond the exit-code coordination in D5 below. Candidate 3 (a
separate cross-repo field) is **declined** — see D4.

**D2 — Predicate: repository-containment via `realpath -m`, resolved consistently on both sides.**
Classify a positive, non-`:(exclude)` pathspec `$p` as **out-of-repository** (a new Case 1b,
distinct from Case 1's matched/Case 2's staged-deletion/Case 3's unmatched) when it exists on
disk or is tracked (so it would otherwise fall into Case 1) **and** its canonicalized path is not
contained in `$PROJECT_ROOT`. Concretely:

```bash
p_rel="$(realpath -m --relative-to="$PROJECT_ROOT" -- "$p" 2>/dev/null)" || p_rel=""
case "$p_rel" in
  ""|.."|../"*) out_of_repo=true ;;
  *) out_of_repo=false ;;
esac
```

`realpath -m` (already an accepted dependency in this codebase, precedent: `state-write.sh`'s
`DEFAULT_STATE_FILE_NORMALIZED`/`STATE_FILE_NORMALIZED`) canonicalizes `.`/`..` components and
symlinked ancestors without requiring the path to exist, and `--relative-to` directly answers
"is `$p` inside `$PROJECT_ROOT`" without a brittle string-prefix comparison (a naive
`case "$p_abs" in "$PROJECT_ROOT"/*)` would false-negative on a sibling directory sharing the
root as a literal substring, e.g. `$PROJECT_ROOT-backup`). This explicitly satisfies ACCEPTANCE
item 4: an **absolute path that resolves inside the repository** (e.g.
`$PROJECT_ROOT/specs/foo.md` given as an absolute literal) resolves to a `..`-free relative path
and is correctly treated as in-repo, continuing to work exactly as today; only a path whose
canonical form escapes `$PROJECT_ROOT` (whether given as an absolute path into another
filesystem tree, or as a relative path laundered through enough `../` to escape) is flagged.
Both symlinked and `..`-containing paths are therefore handled by construction, per the
dispatch's explicit ask — a symlink inside the repo whose target is itself inside the repo
resolves to an in-repo relative path; a symlink (or a `..`-chain) that genuinely escapes resolves
outside and is correctly flagged, matching what a subsequent `git add` would itself refuse.

**D3 — Classification and gate wiring: extend Case 3's existing machinery, not a new gate.** An
out-of-repository path is dropped from **both** `add_pathspecs` and `filtered_pathspecs` (never
admitted to either `git add` or `git commit --`, the same treatment Case 3 already gives a
genuinely-unmatched path) and appended to the existing `dropped_pathspecs` array (so it
participates in the existing V6 "partial drop + no commit" refusal built by task 277, without a
new exit code). The WARN message is distinct from Case 3's, naming the reason explicitly (e.g.
`WARN: git-commit-scoped.sh dropping out-of-repository pathspec '${p}' (resolves outside
${PROJECT_ROOT}); this path will NOT be part of the commit.`) so a reader of stderr — or of a
caller's structured issue log — can distinguish "never existed" from "exists, but in the wrong
repository," which is operationally a very different and more alarming signal.

**D4 — Cross-repository-edit field (candidate 3): do not add one.** The need is real (an agent
legitimately touching the agent-system source store while dispatched against a consumer repo has
nowhere durable to record it today), but a new schema field is disproportionate to this task's
narrow fix and duplicates ground `.return-meta.json`'s `memory_candidates`/`completion_summary`
and `issues.jsonl` (via `issue-record.sh --class "cross-repo edit"`, an open, extensible
class enum per `context/formats/issue-log.md`) already cover for free-text, operator-visible
reporting. Recommend adding one sentence to `return-metadata-file.md`'s `modified_files` section:
*"A file edited outside this repository (e.g. an agent-system source-store edit made while
dispatched against a consumer repo) is explicitly outside `modified_files`'s remit — do not list
it there. Report it in `completion_summary` or an `issues.jsonl` entry (`--class "cross-repo
edit"`) instead, so an operator can commit it by hand in its own repository."* This also closes
ACCEPTANCE item 5 without new machinery, and is consistent with this task's own OUT-OF-SCOPE
list (no new schema).

**D5 — Exit-code sink: extend, do not replace, the existing contract; branch only where the
defect is actually reachable.** The dispatch asks which callers must branch and on which codes.
Narrowed by the findings above:

- No new exit code is needed for the out-of-repository case itself (D3 folds it into the
  existing dropped-pathspecs/V6 machinery, reusing exit 4 for the "all dropped, nothing
  committed" shape and exit 0 for the "some dropped, N committed" shape — the latter is new
  *behavior*, not a new code: today that shape does not exist at all, since the single `git add`
  call fails fatally before any commit; after D2/D3 it exits 0, with the drop reported only on
  stderr).
- **`scripts/orchestrate-cycle-postflight.sh` must branch on `git-commit-scoped.sh`'s exit code**
  (it already receives `modified_files`-derived paths and is the one live site demonstrated to
  hit this defect). Recommended policy: treat exit `0` and `1` as today (success / benign no-op);
  treat `2`, `3`, `4`, `5` as "commit did not fully succeed" and record it via the existing
  `issue-record.sh` channel plus force the dispatch's resulting status to a non-terminal outcome
  (the script already has a `clamp_mode`/monotonic-max-clamp mechanism for exactly this kind of
  "do not let this transition claim more success than actually happened" need) rather than
  letting `implemented`/`completed` stand — this is the HARD CONSTRAINT's required shape: visible
  and attributable, never a silent swallow, and never a hard abort that strands the batch.
- **`scripts/orchestrate-unwind-dispatch.sh` does *not* need a branch for this specific defect.**
  Confirmed by reading its call site (`-- specs/state.json specs/TODO.md`, two fixed literals):
  it is structurally never exposed to an out-of-repository `modified_files` entry. It still has
  the pre-existing, unrelated residual (V6/V8 for its own two literals, extremely unlikely to
  ever trigger since both are always in-repo) — leave its current `|| echo WARN` as-is; branching
  it buys nothing for this task and is not required by the HARD CONSTRAINT, which is about
  *reachable* failure, not every call site unconditionally.
- **The ~50 documentation snippets: do not hand-edit.** Confirmed these are overwhelmingly prose
  (148 files mention `git-commit-scoped.sh`; 155 lines show an invocation shape across
  `.md`/`.sh`), most of which are *documentation illustrating the convention*, not independently
  executed code paths — and at least one load-bearing precedent (`general-implementation-agent
  .md`'s `git-commit-phase.sh` call site, landed by task 336) already demonstrates a full
  `case "$rc" in ...)` branch is a normal, low-cost pattern in this codebase, not a 50-site
  burden. Recommend a **lint**, not a bulk edit: extend (or sibling) `scripts/lint/
  lint-scoped-commit-boundary.sh` to flag a *literal script invocation* (`.sh`, never `.md`
  prose) that pipes `git-commit-scoped.sh` into a bare `|| echo` with no `$?`/`case` capture,
  wired as a `verify-deploy.sh` gate exactly as its sibling `lint-directory-pathspec-boundary.sh`
  is. This matches the dispatch's own stated preference ("Prefer the narrow mechanical fix plus
  an enforcement lint over editing 50 prose snippets by hand").
- **Reserve exit `6` for task 336's own named follow-up** (a future `file_scope`-Containment
  refusal code, "distinct from the existing ... refusal," per that follow-up's own text) —
  record this reservation in `git-staging-scope.md`'s exit-code table so this task's work and
  336's unfiled follow-up do not independently claim the same next-available code.

**D6 — Global non-blocking-commit policy: recommend, do not flip.** Per the dispatch's own
constraint and the HARD CONSTRAINT above, this task does not change the non-blocking posture
globally (a commit failure must never abort a batch). The correct-shaped fix is D5's targeted
branch at the one reachable live caller, which converts "silent success" into "visible,
attributable, non-terminal" without making anything fatal. Recommend this as the durable pattern
for any future caller that newly becomes exposed to a `git-commit-scoped.sh` nonzero exit, rather
than a blanket "all callers must be fatal" rule.

**D7 — Silent filtering vs. loud refusal: drop-and-warn, which beats the status quo on both
axes.** D2/D3 together commit the N valid paths (the "recover valid work" axis) while printing a
distinguishing stderr line naming the exact offending path and the exact reason (the "surface the
violation" axis) — and D5 makes that surfacing reach the task's own outcome via the
`orchestrate-cycle-postflight.sh` branch, rather than remaining a stderr-only artifact nobody
inspects. Neither axis is traded away; this report does not need the "if only one axis, say
which" escape hatch ACCEPTANCE item 7 anticipates.

## Recommendations

1. In `scripts/git-commit-scoped.sh`'s V2 loop, insert the D2 predicate as a new branch that runs
   *before* (or as a guard clause inside) the existing Case 1 test, so an out-of-repository path
   never reaches `[ -e "$p" ]`'s positive branch. Wire it into `dropped_pathspecs` per D3, with
   its own distinct WARN wording. Update the script's own header comment (Safety gates section)
   to document this as a new gate (suggest **V9**, since V8 is the most recent) distinct from V2's
   existing three cases, and update the Exit codes table's prose for exit `4` to mention the new
   drop reason.
2. Update `context/standards/git-staging-scope.md`'s Exit-Code Contract table and gate-label
   prose to add the V9 label, and reserve exit `6` per D5's last bullet.
3. Add the `modified_files`-remit sentence from D4 to `context/formats/return-metadata-file.md`,
   immediately after the existing "Absolute paths are not permitted" sentence. In the same edit,
   correct that section's stale reference to `orchestrator-postflight.sh` (confirmed orphaned, no
   live callers) so it also names `orchestrate-cycle-postflight.sh`, the actual live consumer —
   this is the one-line accuracy fix the dispatch already calls in-scope.
4. In `scripts/orchestrate-cycle-postflight.sh`, add the D5 exit-code branch immediately after the
   existing `git-commit-scoped.sh` call site (~line 1824), using the script's existing
   `clamp_mode`/issue-recording idioms rather than new mechanism.
5. Add new regression cases to `scripts/tests/test-git-commit-scoped.sh`, following the existing
   T-numbering (next available: **T14**, **T15**): T14 — one out-of-repository absolute path
   mixed with N valid repo-relative paths commits the N paths (content-asserted, per ACCEPTANCE
   item 2) and reports the offending path by name; T15 — an absolute path that resolves *inside*
   the repository continues to commit unchanged (ACCEPTANCE item 4's explicit regression case).
   Re-run T1-T13 unchanged as the regression set for ACCEPTANCE item 3 (Case 2 staged deletions
   especially, per the dispatch's own emphasis, since they share the all-or-nothing `git add`
   reasoning D2/D3 must not disturb).
6. File two follow-up tasks at `/todo` or via `/task`, rather than silently folding them into this
   task's own implementation phase: (a) propagate the `modified_files` repo-relative contract to
   the 9 silent implementation agents (already named by the dispatch as a follow-up); (b) task
   336's unfiled `file_scope`-Containment-chokepoint specification
   (`specs/archive/336_.../evidence/03_followup-mechanical-check.md`), explicitly coordinated
   with this task's own exit-code reservations (D5's last bullet) — the planner for this task
   should read that specification in full before finalizing the plan, since it constrains the
   exit-code space this task's own implementation claims.
7. Author the lint recommended in D5 (`lint-scoped-commit-boundary.sh` extension or a sibling
   script) as part of this task's own implementation if time permits; otherwise name it explicitly
   as an in-plan but deferrable phase, not a silent omission.

## Risks & Mitigations

- **Risk**: the new V9 predicate could false-positive on a legitimate in-repo path whose
  canonicalization touches an unusual symlink arrangement (e.g. a bind-mounted or NixOS-store
  symlinked subtree). **Mitigation**: resolve `$PROJECT_ROOT` itself through the *same*
  `realpath -m` call before comparing (never compare a raw, un-resolved `$PROJECT_ROOT` against a
  resolved `$p`), and add a regression case exercising a symlink-containing path if the test
  sandbox can construct one cheaply; if not practical within this task's effort budget, record the
  gap explicitly rather than silently skip it.
- **Risk**: folding the new drop into `dropped_pathspecs` means an out-of-repository path and a
   genuinely-unmatched path are now exit-code-indistinguishable (both route through V6's exit 4).
   **Mitigation**: the WARN/ERROR message text remains distinct per-path (D3), which is sufficient
   for a human or a grep-based lint; a caller that needs to discriminate programmatically does not
   exist today, and inventing a new exit code for a discrimination nobody currently consumes
   repeats the V6 gate's own reasoning for why it did not split "nothing to commit" from "commit
   genuinely failed."
- **Risk**: the `orchestrate-cycle-postflight.sh` branch in D5 could itself strand a batch if its
   non-terminal-status clamp is implemented incorrectly. **Mitigation**: reuse the script's
   existing, already-tested `clamp_mode`/`skill_postflight_update` monotonic-max machinery rather
   than writing new status-transition logic; add a dedicated regression case to
   `test-orchestrate-cycle-postflight.sh` exercising a nonzero `git-commit-scoped.sh` exit and
   asserting the task does *not* reach a terminal `completed` status.

## Context Extension Recommendations

- **Topic**: a single "Known Callers and Coverage" table for `git-commit-scoped.sh`'s
  containment/scope guards (V5 Overlap, the landed `file_scope` Containment at the two wrapper
  layers, and this task's new V9 repository Containment).
- **Gap**: `context/standards/git-staging-scope.md` currently documents each guard in its own
  prose subsection, written at different times by different tasks; a reader has to reconstruct
  which predicate (lease contention / declared-scope membership / repository boundary) protects
  which call site, and under what fail-open conditions, by reading three separate narratives.
- **Recommendation**: after this task's V9 lands, add one consolidated table (guard name,
  predicate, call sites covered, fail-open trigger) to `git-staging-scope.md`, superseding the
  need to re-derive this from three separate completed-task summaries the way this research pass
  had to. Not performed here — out of this task's declared `file_scope`.

## Appendix

### Search Queries / Commands Used

- Direct reads: `scripts/git-commit-scoped.sh` (full), `context/standards/git-staging-scope.md`
  (exit-code and related sections), `context/formats/return-metadata-file.md` (`modified_files`
  section), `agents/general-implementation-agent.md` (Phase-Commit Containment Self-Check),
  `scripts/orchestrate-cycle-postflight.sh` (WORK (h)/(i), lines ~1494-1830), `scripts/
  orchestrate-unwind-dispatch.sh` (commit call site).
- `diff -q` between source-store and deployed copies of all four `file_scope`-named files
  (confirmed byte-identical).
- `grep -rn "orchestrator-postflight.sh"` across `agent-system/extensions/core` (confirmed
  orphan status: zero live invocation sites, multiple independent in-repo notes agree).
- `grep -rln "excursion"` / `-S "excursions_json"` git-log search across `specs/` and
  `specs/archive/` (discovered tasks 335/336 and the git-log provenance of the excursion filter).
- `jq` queries against `specs/state.json` for tasks 277, 304, 335, 336's `active_projects`
  entries (confirmed 277/336 archived-completed, 335 completed, 304's own declared
  `file_scope`/`dependencies`).
- Read in full: `specs/archive/277_.../summaries/01_pathspec-drop-hard-error-summary.md`,
  `specs/335_.../summaries/01_excursion-filter-staging-gate-summary.md`, `specs/archive/
  336_.../summaries/01_phase-commit-containment-self-check-summary.md`, `specs/archive/
  336_.../evidence/03_followup-mechanical-check.md`, `specs/archive/336_.../plans/
  01_phase-commit-containment-self-check.md` (Phase 5 section).

### References

- `agent-system/extensions/core/scripts/git-commit-scoped.sh`
- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- `agent-system/extensions/core/context/formats/return-metadata-file.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/orchestrate-unwind-dispatch.sh`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `specs/archive/277_git_commit_scoped_worktree_targeting/`
- `specs/335_gate_modified_files_excursion_at_staging/`
- `specs/archive/336_phase_commit_staging_has_no_scope_check/`
