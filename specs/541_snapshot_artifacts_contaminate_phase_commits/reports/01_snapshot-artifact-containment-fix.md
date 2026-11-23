# Research Report: Task #541

**Task**: 541 - Stop git-snapshot.sh's --no-revert artifacts from contaminating phase commits with OTHER tasks' files
**Started**: 2026-11-22T00:00:00Z
**Completed**: 2026-11-22T00:00:00Z
**Effort**: medium
**Dependencies**: specs/535_phase_commit_drops_own_plan_artifact (must run after; shares the same two files and `git-staging-scope.md`)
**Sources/Inputs**: - Codebase (`agent-system/extensions/core/scripts/git-snapshot.sh`, `scripts/git-commit-phase.sh`, `scripts/lib/file-scope-overlap.sh`, `context/standards/git-staging-scope.md`, `context/standards/orchestrator-runtime-files.md`), git history of two repositories (this repository and the BimodalLogic repository the record was migrated from), the source issue-log entry
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The incident is real, verified, and reproducible by inspection: commit `b7bba072e` in the
  BimodalLogic repository carries 13 foreign files from four unrelated tasks under
  `specs/744_wrap_inventory_tables_generated_markers/untracked-backup-1792263067/specs/`; the
  source issue-log entry (`iss_1792263251358_jTp86B`) matches the dispatch's summary verbatim.
- Two independent defects compose to cause it: `git-snapshot.sh`'s `--no-revert` mode enumerates
  untracked files repository-wide with no scope filter (Half 1), and `git-commit-phase.sh` stages
  the WHOLE task directory as a single directory pathspec that is never run through the
  Containment Self-Check (Half 2). Either fix alone closes the observed incident; both are
  recommended because they protect different artifacts (see below) and because the project's
  own fail-safe convention keeps a redundant site even once a stronger site subsumes it.
- The repo-wide untracked-file enumeration this task must narrow is used by `--no-revert` mode
  ONLY — confirmed by reading the full script. Default and `--branch` modes capture untracked
  files through `git stash push -u` (a different, inherently repository-wide git primitive that
  never writes a directory under the task directory), so narrowing the `--no-revert` enumeration
  to the dispatching task's declared `file_scope` costs those other two modes nothing.
- The two artifacts warrant different dispositions, exactly as the dispatch anticipated: the
  `untracked-backup-*/` copies are literal duplicates of files that are themselves already
  untracked (the originals are never touched by `--no-revert`), so moving that class into the
  existing ephemeral/gitignored runtime-file policy costs no real data. `working-progress-*.patch`
  is the only durable record of a REVERTING mode's lost tracked-file diff and is explicitly
  documented as deliberately not gitignored; it should stay tracked-eligible, which means Half
  2's directory-pathspec exclusion is this artifact's SOLE line of defense, not a second one.
- A third, in-scope-adjacent finding: `scripts/orchestrate-cycle-postflight.sh` builds the
  structurally identical `stage_paths=("${TASK_DIR}/" ...)` directory-pathspec seed at its own
  line 2080, for the whole-task completion commit. This task's declared `file_scope` does not
  name that file, so this report flags it rather than editing it — see Risks below.

## Context & Scope

Task 541 asks for a fix to a pair of cooperating defects in `scripts/git-snapshot.sh` and
`scripts/git-commit-phase.sh` that let `--no-revert` snapshot artifacts (an `untracked-backup-*/`
directory copy of untracked files, and a `working-progress-*.patch` diff) sitting inside a task's
own directory get swept into that task's phase commit by a directory-pathspec `git add`, with no
containment test ever examining them. The declared edit targets (per `specs/state.json`'s
`file_scope` for this task) are:

```
agent-system/extensions/core/scripts/git-snapshot.sh
agent-system/extensions/core/scripts/git-commit-phase.sh
agent-system/extensions/core/scripts/tests/test-git-snapshot.sh
agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh
agent-system/extensions/core/context/patterns/checkpoint-before-overflow.md
agent-system/extensions/core/context/standards/orchestrator-runtime-files.md
agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh
```

`context/standards/git-staging-scope.md` is named in the dispatch body as a plausible edit target
("any of ... the chosen fix touches") but is NOT present in the declared `file_scope` array above
— a minor inconsistency worth flagging to the plan phase (see Risks). This research treats the
seven declared paths as the authoritative edit surface and reports the staging-scope document as
read-only reference material, consistent with the dispatch's instruction to read task 777's
correction there before touching it.

The research verified the measured evidence, re-derived the mode-sharing question the dispatch
explicitly asked not to assume, and worked through the three ordered questions the dispatch poses.
It did not write code — that is the plan/implementation phases' job.

## Findings

### Codebase Patterns

**Half 1 — `git-snapshot.sh`'s `--no-revert` untracked-file enumeration (confirmed mode-specific).**
Reading the full script (`agent-system/extensions/core/scripts/git-snapshot.sh`) top to bottom
confirms the dispatch's description and settles the mode-sharing question it raised:

- Lines 369-448 run an out-of-scope **refusal guard** for default/`--branch` modes only (`if
  [ "$MODE" != "no-revert" ]`). It classifies dirty TRACKED paths against the task's declared
  `file_scope` via `path_covered_by_scope()` (from `lib/file-scope-overlap.sh`) and REFUSES the
  whole reverting operation if any tracked path falls outside scope; it also enumerates dirty
  UNTRACKED paths (`git ls-files --others --exclude-standard`, line 433) but only to print a
  WARNING about them — it never copies them anywhere. This block already fails closed (D4) when
  `file_scope` is absent, empty, missing `jq`, or missing `state.json`.
- Lines 506-563 are the `--no-revert` branch. Its own untracked-file enumeration at line 546
  (`UNTRACKED_LIST=$(git ls-files --others --exclude-standard 2>&1)`) is a SEPARATE, unguarded,
  repository-wide call with no scope filter at all, and its hits are copied one-by-one into
  `UNTRACKED_BACKUP="${TASK_DIR}/untracked-backup-${TS}"` (lines 552-563). This is the exact
  defect the dispatch names.
- Default mode (the `else` branch, lines 564-583) never populates `UNTRACKED_BACKUP` at all — it
  relies on `git stash push -u`, a git primitive that stashes untracked files into a stash
  COMMIT OBJECT (recoverable via `git stash pop`), not a directory copy under the task directory.
  `--branch` mode (lines 483-505) similarly never touches `UNTRACKED_BACKUP`; its WIP commit is on
  a scratch branch, not inside the task directory's own untracked-file tree.

**Conclusion on mode-sharing**: the line-546 enumeration this task must narrow is used by
`--no-revert` mode exclusively. Narrowing it to the dispatching task's declared `file_scope` has
zero effect on default/`--branch` mode behavior, because those modes never read `UNTRACKED_BACKUP`
or call this enumeration. The dispatch's own caution ("Check whether the enumeration is shared
across modes before narrowing it in a way that only suits one") is resolved: it is not shared.

The predicate to reuse for scoping is already in the same file's own dependency,
`path_covered_by_scope()` (`scripts/lib/file-scope-overlap.sh:202`), documented there as having
"exactly one string-comparison consumer (git-snapshot.sh's per-dirty-path classification loop)" —
i.e. only the D1-D5 guard currently calls it. Adding a second call site inside the `--no-revert`
branch is additive, not a new predicate.

**Half 2 — `git-commit-phase.sh`'s fixed `stage_paths` seed (confirmed never tested).** Reading
`scripts/git-commit-phase.sh` lines 449-455 and its own header comment confirms the directory
pathspec is staged unconditionally and is explicitly, deliberately exempt from the Containment
Self-Check:

```bash
# --- Fixed scope: always staged, never tested by the Containment Self-Check below. ...
stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")
[ -n "$plan_path" ] && stage_paths+=("$plan_path")
```

The Containment Self-Check that follows (lines 532-756) tests only entries derived from the
phase's own `files_touched` progress-file array — it never iterates the EXPANDED contents of the
`"${task_dir}/"` directory pathspec, because that pathspec is a single string handed straight to
`git add` later (line 764), not a list `git-commit-phase.sh` itself walks. `git-commit-scoped.sh`'s
own V10 gate (described in `git-staging-scope.md`) tests pathspec ENTRIES against `file_scope`,
and the dispatching task's own resolved directory is an explicit, always-admitted member of that
scope at all three Containment sites (`git-staging-scope.md`'s "second universal, per-site
widening" section) — so the `"${task_dir}/"` entry itself always passes V10 trivially, regardless
of what is sitting inside it on disk. Nothing in the current pipeline ever inspects the directory's
actual contents against scope. This is exactly how a foreign copy sitting physically inside the
directory reaches `git add` with zero containment test anywhere in the chain.

**Already-existing exclusion mechanism to reuse.** `git-staging-scope.md`'s "Canonical Runtime-File
Exclusion Set" section documents a `:(exclude)...` magic-pathspec array (`ephemeral_excludes`)
already used by this same staging contract to subtract specific ephemeral filenames from a
directory pathspec without an allowlist. The mechanism is directly applicable to both snapshot
artifact name patterns and requires no new primitive — only new entries in the array (or an
equivalent array local to `git-commit-phase.sh`, if the two scripts do not already share one; the
research did not find `git-commit-phase.sh` currently consuming `ephemeral_excludes` by name, so
the plan phase should confirm whether it needs to build its own small array of two
`:(exclude)...` entries or splice into a shared one via `runtime-file-patterns.sh`).

**Verified recurrence (routine, not exceptional).** The dispatch's "broader than the one cited
commit" claim is independently confirmed in THIS repository, not only in BimodalLogic:

```
$ git log --all --oneline -- 'specs/*/working-progress-*.patch' | head
d94736bbf todo: archive 25 completed tasks
6c0d20fcc task 603: complete implementation
...
$ git ls-files 'specs/*/working-progress-*.patch'
specs/archive/420_warn_plan_size_exceeds_cycle_budget/working-progress-1794101526.patch
specs/archive/482_create_sapience_extension/working-progress-1793893773.patch
specs/archive/532_roadmap_integration_regenerate_silent_abort/working-progress-1794424467.patch
specs/archive/603_roadmap_command_generated_from_state/working-progress-1794516883.patch
```

Four `working-progress-*.patch` files are currently tracked in this repository alone (all under
each task's OWN directory — these are not cross-task contamination, they are the routine-sweep
hygiene concern the dispatch separately names). The BimodalLogic repository's own commit history
(`b7bba072e`, `d12c308e7`, `fd04dd23e`, `062e46e2f`, `39cc0eb9b`) independently confirms the same
pattern across tasks 744, 807, 805, 794 there. This corroborates the dispatch's framing that the
patch sweep is routine infrastructure behavior, not a one-off.

**Measured evidence re-verification.** `git show --name-only b7bba072e` in the BimodalLogic
repository lists 13 files under `specs/744_wrap_inventory_tables_generated_markers/untracked-backup-1792263067/specs/{566,616,617,785}_*`,
matching the dispatch's claim exactly. The source issue-log entry
(`/home/benjamin/Projects/BimodalLogic/specs/archive/744_wrap_inventory_tables_generated_markers/issues.jsonl`,
`entry_id: iss_1792263251358_jTp86B`) reads verbatim:

> "git-snapshot.sh --no-revert wrote untracked-backup-\*/ (copies of four OTHER tasks' untracked
> specs files) and working-progress-\*.patch inside this task's directory; git-commit-phase.sh's
> task-directory pathspec then swept them into the phase 2 commit. Removed with git rm in the
> phase 3 commit; later phases skip the snapshot because no destructive git command follows the
> writer."

`class: tooling`, `severity: minor`, `resolution: null` — matching the dispatch's citation exactly.

**File-scope prevalence (measured, not assumed).** In this repository's current `state.json`, 115
of 121 non-terminal tasks (≈95%) carry a declared, non-empty `file_scope`; only 6 do not. The
dispatch's framing ("many non-terminal tasks declare none") is not the dominant case by this
measurement, but the instruction to define explicit, non-silent behavior for the absent case still
applies regardless of frequency — a 5% tail is not a case the fix can ignore.

### External Resources

Not applicable — this is a pure in-repo shell-tooling defect with no external library or API
surface; no web research was needed or performed.

## Recommendations

Answering the dispatch's three ordered questions:

**(1) Scope the `--no-revert` untracked-backup enumeration to the dispatching task's declared
`file_scope`.** Yes. Reuse `path_covered_by_scope()` (already sourced into `git-snapshot.sh` via
`lib/file-scope-overlap.sh`) inside the `--no-revert` branch (around line 546), filtering
`UNTRACKED_LIST` the same way the D1-D5 guard already filters `DIRTY_TRACKED`/`DIRTY_UNTRACKED`
for the reverting modes. Always admit the dispatching task's own resolved `TASK_DIR` as an
implicit in-scope member (mirroring the "own task directory" universal widening already
established for all three Containment sites in `git-staging-scope.md`), so a task's own untracked
work that happens to live inside its own directory is still captured.

For the absent/empty/unreadable `file_scope` case, do NOT silently fall back to the current
repo-wide behavior (the dispatch is explicit about this) and do NOT refuse the snapshot outright
either — `--no-revert` is non-destructive by design and must stay available as the sanctioned
checkpoint action `checkpoint-before-overflow.md` directs agents toward on every RED tree. The
recommended fallback is: when `file_scope` cannot be resolved, back up ONLY untracked files inside
the dispatching task's own `TASK_DIR` (not the whole repository), and print a loud, explicit,
named warning on stderr stating that the backup was narrowed to the task's own directory because
no declared `file_scope` was available — never silent, never a full-repo copy. This mirrors the
existing D4 fail-closed posture used by the reverting modes' guard, adapted so that a non-
destructive action degrades rather than refuses.

This narrowing has no cost to default/`--branch` modes: per the Findings above, those modes never
read or populate `UNTRACKED_BACKUP`; their untracked-file capture goes through `git stash push -u`
instead, an independent mechanism this change does not touch.

**(2) Relocate the artifacts so a directory pathspec cannot reach them — with two different
answers, as the dispatch anticipated.**

- `untracked-backup-{ts}/`: move into the ephemeral/gitignored runtime-file class documented in
  `context/standards/orchestrator-runtime-files.md` and mechanized in `scripts/lib/runtime-file-patterns.sh`
  (adding it as a new, directory-class member alongside `.lock/`, `.dispatch/`, etc., with its own
  gitignore pattern, e.g. `**/untracked-backup-*/`). This costs no real data: by construction the
  backed-up content is a literal duplicate of files that are THEMSELVES still untracked and
  present on disk at their original location — `--no-revert` mode never deletes the originals.
  Making the copy ephemeral also closes Half 1 structurally rather than only by scoping: per
  `git-staging-scope.md`'s own Canonical Runtime-File Exclusion Set note, "an ignored path swept
  up IMPLICITLY by a bare directory pathspec... is silently skipped by `git add` with no error" —
  so even an UN-scoped future enumeration bug would no longer reach a committed state. Recommend
  giving it a reap window via `scripts/reap-session-runtime-files.sh` consistent with the other
  scratch-state entries in that table, not an indefinite one, since its only purpose is bridging
  to a possible destructive command shortly after the snapshot.
- `working-progress-{ts}.patch`: KEEP it where it is, tracked-eligible, not gitignored. This
  preserves `git-snapshot.sh`'s own explicit, deliberate documented design ("the durable
  working-progress-\*.patch file is NOT gitignored and remains tracked under the task directory
  for manual recovery if needed") — this is the one artifact among the two that represents real,
  otherwise-unrecoverable information (the diff of tracked changes a REVERTING mode is about to
  discard from the working tree). Making it ephemeral would convert a deliberately-durable
  recovery artifact into one subject to timed deletion, which the dispatch correctly flags as a
  decision that must not be made by default inheritance from the `untracked-backup` answer.

**Consequence of (2) for priority.** Because the patch stays in place and stays reachable by the
directory pathspec, question (3)'s exclusion is this artifact's ONLY line of defense — not a
second, redundant one the way it is for `untracked-backup-*/` once that class is also made
ephemeral. The plan phase should treat the patch exclusion as load-bearing and the backup
exclusion as belt-and-suspenders, matching the project's own stated precedent for keeping a
redundant check in place even once a stronger site subsumes it (`git-staging-scope.md`'s "Site
2... kept in place rather than removed... even while it remains deliberately redundant" language
for the analogous engine-written-state-allowlist gap).

**(3) Add an explicit exclusion to `git-commit-phase.sh`'s fixed-scope pathspec.** Yes, as
belt-and-suspenders independent of where the artifacts land — recommended regardless of how (2) is
decided, and REQUIRED given (2)'s patch disposition. Add two `:(exclude)...` magic-pathspec
entries to the `stage_paths` construction at `git-commit-phase.sh:454`, following the exact
pattern `git-staging-scope.md`'s `ephemeral_excludes` array already establishes for other
ephemeral filenames:

```bash
stage_paths=(
  "${task_dir}/"
  ":(exclude)${task_dir}/working-progress-*.patch"
  ":(exclude)${task_dir}/untracked-backup-*"
  "specs/TODO.md"
  "specs/state.json"
)
```

Glob metacharacters are supported in git pathspecs by default (fnmatch-style, unless `:(literal)`
is specified), so the `*` wildcards above match the timestamp-suffixed names without needing the
exact timestamp. Per the same "CANDIDATE array" caveat `git-staging-scope.md` already documents
for `ephemeral_excludes` (naming an ALREADY-gitignored path as an explicit `:(exclude)` entry makes
`git add` abort the whole add with an "ignored by .gitignore" error when that path exists on
disk), this exclusion should be injected conditionally — guarded by `git check-ignore -q`, exactly
as `git-commit-scoped.sh` already guards its own four candidates — if and when `untracked-backup-*`
becomes gitignored per (2). The `working-progress-*.patch` exclusion has no such hazard, since (2)
recommends it stay un-ignored.

**Explicit non-recommendation on `git-commit-scoped.sh`.** The dispatch's NON-GOALS bars changes
there; this report does not propose any. The two new exclude entries belong solely in
`git-commit-phase.sh`'s own `stage_paths` construction, one layer above.

## Decisions

- The `--no-revert` untracked-backup enumeration is confirmed, by direct code reading, to be used
  by no mode other than `--no-revert` itself — narrowing it is safe with respect to default/
  `--branch` mode behavior.
- `untracked-backup-{ts}/` is recommended for the ephemeral/gitignored runtime-file class;
  `working-progress-{ts}.patch` is recommended to remain tracked-eligible and un-gitignored. These
  are deliberately DIFFERENT answers to the same relocation question, per the dispatch's own
  framing of the asymmetry between a duplicate-of-untracked-content artifact and a primary durable
  record.
- Both artifacts should additionally receive an explicit `:(exclude)` pathspec entry inside
  `git-commit-phase.sh`'s fixed `stage_paths` seed, independent of the relocation decision for
  either — for the patch this is the sole defense; for the backup directory it is intentional
  redundancy with the gitignore-based removal.
- No change is recommended to `git-commit-scoped.sh`, to the guard-hook marker protocol, to the
  stash-identity scheme, or to the containment predicate's treatment of genuinely out-of-scope
  paths — all consistent with the dispatch's stated NON-GOALS.

## Risks & Mitigations

- **`scripts/orchestrate-cycle-postflight.sh` carries the structurally identical hazard, out of
  this task's declared `file_scope`.** Line 2080 of that script builds
  `stage_paths=("${TASK_DIR}/" "$(dirname "$STATE_FILE")/TODO.md" "$STATE_FILE")` — the same
  unconditional directory-pathspec seed Half 2 names, for the per-cycle whole-task completion
  commit rather than the mid-dispatch phase commit. If a `--no-revert` snapshot is taken for a
  task and that task's cycle later reaches its own postflight completion commit before any phase
  commit runs, the identical sweep could occur there instead of in `git-commit-phase.sh`. This
  report does NOT recommend editing that file now — it is outside the declared `file_scope`, and
  editing it without that declaration would itself be a scope excursion of the kind this whole
  task record is about. Mitigation: flag this explicitly for the plan phase to decide whether to
  (a) widen `file_scope` for this task via the plan-authoring process, (b) spin off a narrow
  follow-up task once this one lands (the two `stage_paths` seeds are near-identical and a third
  reader could port the same two exclude entries quickly), or (c) accept the residual risk because
  (2)'s relocation of `untracked-backup-*/` into the gitignored class already closes most of the
  exposure structurally (a directory pathspec silently skips a gitignored path regardless of which
  script builds the pathspec) — leaving only the patch exposed at this second site, same as at the
  first.
- **`context/standards/git-staging-scope.md` is named by the dispatch body as a plausible edit
  target but is absent from the task's declared `file_scope`.** If the plan phase decides a prose
  correction there is warranted (e.g. documenting the two new exclude entries alongside the
  existing `ephemeral_excludes` description), it should first request a `file_scope` addition
  through the normal task-update path rather than editing silently outside scope; this is a
  process note, not a technical risk.
- **Reading task 777's correction before editing `git-staging-scope.md`.** Confirmed: the document
  as it currently reads does NOT contain the "structurally outside [the filter's] reach" false
  premise sentence the dispatch warns against reintroducing — the "Phase Commit (mid-dispatch)"
  and "Three Containment sites" sections already carry the corrected, more careful language (e.g.
  "Site 2's Phase-Commit Containment Self-Check is therefore load-bearing for the own-task-directory
  member specifically"). The plan/implementation phases should still read that section in full
  before any edit, but task 777's fix appears to already be live in this document as read today.
- **Test-suite false-negative risk.** The dispatch's acceptance criterion requires the new
  regression case to FAIL against the unmodified scripts before the fix lands. `scripts/tests/test-git-snapshot.sh`
  already has fixture helpers (`run_snapshot`, `common_test_pass`/`common_test_fail`,
  `FIXTURE_DIR_NAME`/`FIXTURE_NUM`) exercising `--no-revert` against an out-of-scope dirty tree
  (see its existing "Silent-exit reproduction" and "unlocked negative control" cases around lines
  170-245); the new case should follow the same fixture shape — a scratch repo with a second,
  foreign `specs/{NNN}_{slug}/` directory carrying untracked files, a `--no-revert` snapshot run
  for ONE task, then that task's phase commit via `git-commit-phase.sh`, asserting the foreign
  directory's files are absent from both the staged index and the resulting commit. Splitting the
  case across both suites (one half proving the backup lands outside scope, one half proving the
  commit never stages it) is consistent with the dispatch's "and/or" phrasing and gives narrower,
  more diagnostic failures than one combined end-to-end case.

## Context Extension Recommendations

- **Topic**: a shared, named helper for "the fixed task-directory `stage_paths` seed plus its
  exclude entries," consumable by both `git-commit-phase.sh` and `orchestrate-cycle-postflight.sh`.
- **Gap**: the two scripts currently duplicate the identical `stage_paths=("${task_dir}/" ...)`
  literal construction independently (confirmed by direct `grep` of both files), so a future fix
  to one (like this task) does not automatically propagate to the other, as the Risks section
  above demonstrates concretely.
- **Recommendation**: once this task's fix lands, a small follow-up (not part of this task's
  declared scope) could extract the fixed-seed-plus-excludes construction into a tiny shared
  shell function in `scripts/lib/`, sourced by both call sites, so the next ephemeral-artifact
  class added to the exclusion set needs one edit instead of two. This is a suggestion for a
  separate task, not a recommendation to widen this task's own `file_scope`.

## Appendix

- Search queries / commands used: `cat`/`sed -n`/`grep -n` over
  `agent-system/extensions/core/scripts/git-snapshot.sh`,
  `agent-system/extensions/core/scripts/git-commit-phase.sh`,
  `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`,
  `agent-system/extensions/core/context/standards/git-staging-scope.md`,
  `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-snapshot.sh`,
  `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh`.
- `git show --name-only b7bba072e`, `git log --all --oneline -- 'specs/*/working-progress-*.patch'`,
  `git ls-files 'specs/*/working-progress-*.patch'` — run in both this repository and
  `/home/benjamin/Projects/BimodalLogic`.
- `grep -rl jTp86B /home/benjamin/Projects/BimodalLogic/specs/` to locate and read the source
  issue-log entry verbatim (found archived under
  `specs/archive/744_wrap_inventory_tables_generated_markers/issues.jsonl`).
- `jq` queries against `specs/state.json` for this task's declared `file_scope` and for the
  repo-wide file_scope-prevalence measurement.
