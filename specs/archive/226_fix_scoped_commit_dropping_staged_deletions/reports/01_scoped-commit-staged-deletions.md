# Research Report: Fix scoped commit dropping staged deletions

- **Task**: 226 - Fix scoped commit dropping staged deletions
- **Started**: 2026-09-17T00:00:00Z
- **Completed**: 2026-09-17T00:00:00Z
- **Effort**: ~1.5 hours (investigation + reproduction)
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/git-commit-scoped.sh` (edit target; V2 safety gate, lines 170-196; `git add`/`git commit` invocations, lines 227-298)
  - `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` (existing regression harness/template, T1-T7)
  - `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (live caller that passes individual file pathspecs, lines 505-548)
  - `agent-system/extensions/core/context/standards/git-staging-scope.md` (fail-safe direction: "under-stage, never over-stage")
  - `.claude/scripts/git-commit-scoped.sh` (deployed copy — currently byte-identical to source store copy, confirmed via diff)
  - `specs/TODO.md` (task 200 — the previously-filed deploy-propagation-gap task referenced by the dispatch's ACCEPTANCE)
  - Manual reproduction in scratch git repos (7 scenarios; see Findings)
- **Artifacts**: `specs/226_fix_scoped_commit_dropping_staged_deletions/reports/01_scoped-commit-staged-deletions.md` (this report)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md, `context/standards/shell-strict-mode.md` (shellcheck requirement for the implementation phase)

## Context & Scope

Confirm the root cause the dispatch's own survey already identified for
`git-commit-scoped.sh` silently dropping staged deletions from a path-scoped commit, verify it
by direct reproduction (not just code reading), determine the exact minimal fix (not just the
diagnosis), verify the fix's mechanics against git's actual behavior before recommending it, and
resolve the open "in scope" question about out-of-scope deletions. Editing the script itself is
plan/implement-phase work; this phase produces the confirmed diagnosis and a concrete,
git-verified fix design plus test-shape guidance for the planner.

## Findings

### Root cause confirmed by direct reproduction

The dispatch's survey note is correct. `git-commit-scoped.sh`'s V2 safety gate
(`git-commit-scoped.sh:181`) matches each positive pathspec with:

```bash
if [ -e "$p" ] || git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
```

Reproduced in a scratch repo: `git rm doomed.txt` (or `git mv old new`, whose delete-half behaves
identically) removes the path from **both** the working tree and the index in the same
operation. At that point neither disjunct holds — `-e` is false (gone from disk) and
`git ls-files --error-unmatch` is false (gone from the index) — so the gate drops the pathspec
with `WARN: ... dropping unmatched pathspec ...` and it never reaches `git add`/`git commit`.
Verified end-to-end: after running the unpatched script against a `git rm`'d file passed as an
explicit pathspec, `git status --short` still shows `D  doomed.txt` staged and untouched after
the "successful" (exit 0) commit — exactly the reported symptom (partial commit, exit 0,
deletion left staged for the user to commit by hand).

**By contrast, an *unstaged* deletion (plain `rm doomed.txt`, no `git rm`) already works
correctly today**, reproduced separately: the file is gone from disk but still tracked in the
index, so `git ls-files --error-unmatch` succeeds, the gate keeps it, and `git add` stages the
deletion normally. The defect is specific to a deletion **already staged before the script
runs** (`git rm`, `git mv`, or an equivalent prior `git add` after manual delete) — which is
precisely the `git rm lakefile.lean` and file-rename cases named in the dispatch.

**A directory-pathspec commit is unaffected.** Reproduced: passing the containing directory
(`specs/999_probe/`, which still exists on disk) instead of the file's own path passes the gate
trivially (`-e` true for the directory), and `git add <dir>/` picks up the staged deletion within
it correctly (Git has staged `git add <path>` as `-A`-equivalent — additions, modifications, and
deletions — since Git 2.0). The bug bites only when the deleted/renamed path itself is named as
an explicit positive pathspec entry.

**This is a live internal-pipeline risk, not only an external-repo one.** `orchestrator-postflight.sh:505-548`
builds `stage_paths` from the task directory (a directory pathspec, safe) *plus* individual
entries: the plan file, and every string in the implementation agent's self-reported
`modified_files` array (`stage_paths+=("$f")` per line). Any implementation agent that deletes or
renames a source file and reports it in `modified_files` hits this exact defect on its own
postflight commit — the deletion silently fails to land and is left staged, matching the observed
BimodalLogic symptom inside this system's own dispatch pipeline, not only in an external consumer
repo.

### The naive fix breaks `git add` for the whole batch — verified, do not do this

Simply widening the V2 gate's match condition to also accept an already-staged-deletion path
(e.g. `git cat-file -e HEAD:"$p"`) is **not sufficient by itself** and, tested directly, actively
breaks things if the newly-matched path is left in the array passed to `git add`:

```
$ git add specs/999_probe/keep.txt specs/999_probe/doomed.txt   # doomed.txt already git rm'd
fatal: pathspec 'specs/999_probe/doomed.txt' did not match any files
$ echo $?
128
```

`git add` errors on a pathspec that is *already* absent from both the working tree and the index
(there is nothing left for `git add` to stage — the deletion is already fully staged). Critically,
this is a **single all-or-nothing invocation**: `git-commit-scoped.sh` calls
`git add "${pathspecs[@]}"` once with the whole array (line 228), so one bad entry aborts the
*entire* add, including `keep.txt`'s legitimate unrelated staged modification — verified above:
after the failed `git add`, `keep.txt` was still shown as unstaged (` M`), not just `doomed.txt`.
Under the script's existing `if ! git add ...; then ...; exit 2; fi` handling (line 228-231), this
would turn the current *silent partial-drop* defect into a *loud whole-commit failure* for any
scoped commit that happens to include an already-staged deletion alongside other real work —
worse than today's bug for the common multi-file case.

### Verified minimal fix: decouple the `git add` set from the `git commit` set

The already-staged deletion does **not need `git add` at all** — it is already fully reflected in
the index. It only needs to be included in the final `git commit -- <pathspecs>` invocation so
the commit actually picks it up. Reproduced and confirmed working, including the rename case:

```bash
# doomed.txt already `git rm`'d (staged deletion); keep.txt has an unstaged modification
git add specs/999_probe/keep.txt                                    # doomed.txt deliberately omitted
git commit -m "..." -- specs/999_probe/doomed.txt specs/999_probe/keep.txt
# -> succeeds, commit contains both D doomed.txt and M keep.txt
```

```bash
# git mv old.txt new.txt (fully staged rename)
git add specs/999_probe/new.txt                                     # old.txt omitted (already staged)
git commit -m "..." -- specs/999_probe/old.txt specs/999_probe/new.txt
# -> succeeds; git show reports "R100  old.txt -> new.txt" (rename detected on display)
```

This confirms the exact shape the dispatch's survey suggested (HEAD/staged-diff match) and adds
the missing half: **classify, don't just match**. The V2 loop needs three outcomes per positive
pathspec, not two:

1. `-e "$p"` true, or `git ls-files --error-unmatch -- "$p"` true (existing two conditions) ->
   normal path: goes into **both** the `git add` set and the final `git commit --` set.
2. New: absent from disk *and* absent from the index, but present at `HEAD:"$p"`
   (`git cat-file -e "HEAD:$p"`, guarded by confirming `HEAD` itself resolves, for the
   first-commit edge case) -> **already-staged deletion**: goes into the `git commit --` set
   **only** — must be excluded from the `git add` set, or the whole `git add` call aborts as
   shown above.
3. Neither of the above -> unmatched, drop with the existing `WARN` (unchanged; this is what
   `T7` in the existing test file already locks down and must keep passing — a genuinely
   nonexistent, never-tracked path must still be dropped, not treated as case 2).

Practically this means the V2 loop needs to build two arrays (e.g. `filtered_pathspecs` for the
final commit pathspec list, as today, plus a new `add_pathspecs` subset that excludes case-2
entries), and the `git add` call at line 228 must be changed to use the new `add_pathspecs`
array while the `git commit ... -- "${pathspecs[@]}"` call at line 283 keeps using the full
matched set. `:(exclude)...` entries belong in both arrays unchanged (they are not subject to
this classification; that loop already `continue`s past them explicitly).

`git diff --cached --name-only -- "$p"` (the dispatch's alternative suggested signal) is not
needed in addition to the `HEAD:` check: given the loop has already established `p` is absent
from *both* disk and index, the only way `p` can still represent a real pending change is that it
existed in `HEAD` and was removed — `git cat-file -e "HEAD:$p"` alone is the precise,
sufficient test. (A path added-and-then-`git rm`'d within the same uncommitted session, never
part of any commit, correctly produces *no* diff at all for that path and correctly falls through
to case 3 — there is genuinely nothing to commit for it.)

### Out-of-scope deletions: recommend preserving current silent-ignore, no refuse behavior

The dispatch's "ALSO IN SCOPE" question — what the script should do about a deletion outside the
declared path scope — resolves cleanly from the codebase's own documented fail-safe direction and
does not require a blocking user decision:

- `git commit -- <pathspecs>` already restricts the commit to exactly the given pathspecs,
  regardless of what else is staged in the shared index. A staged deletion (or any other staged
  change) for a path *not* named in the caller's pathspec list is already left untouched today,
  silently, by the existing `git commit --` scoping — this is true uniformly for modifications,
  additions, and deletions alike, and nothing about the fix above changes that.
- `context/standards/git-staging-scope.md`'s "Fail-Safe Direction" section states the governing
  principle explicitly: **"Under-stage, never over-stage... It is always acceptable to leave
  source-file changes uncommitted for the user to review and stage manually."** A "refuse the
  whole commit if anything is staged outside scope" behavior would be a scope-*widening*
  hardening change unrelated to this defect, contradicts that documented fail-safe direction (it
  would turn an already-safe under-stage outcome into a hard failure), and is not requested by the
  ACCEPTANCE criteria.
- **Recommendation**: keep current behavior unchanged for out-of-scope paths (deletions included)
  — silently not part of the commit, exactly as for any other out-of-scope change type. No new
  refuse/detect logic is needed. This is a low-ambiguity call groundable directly in existing,
  already-approved project standards, not a `user_decision` item.

### Test-shape guidance for the three ACCEPTANCE cases

The existing `test-git-commit-scoped.sh` (T1-T7) is the harness to extend, not replace — it
already has the exact `build_repo`/`run_commit`/verify-via-`git show` pattern needed. Reusable
per-case shape confirmed by the manual reproductions above:

1. **Scoped commit containing only a deletion**: `git rm` a tracked file inside the probe dir,
   invoke with the file's own path as the sole positive pathspec, assert commit lands and
   `git show --name-status` reports `D` for that path (current script: drops it, no commit at all
   if it's the only positive pathspec — actually degenerates via the V3 post-filter refusal,
   exit 2, since filtering leaves zero positive entries; worth confirming this exact exit code in
   the "fails against current script" assertion).
2. **Deletion mixed with additions/modifications in the same path set**: the `doomed.txt` +
   `keep.txt` reproduction above — assert both land in one commit, `doomed.txt` no longer in
   `git status --short` afterward (currently: `keep.txt` lands, `doomed.txt` stays staged and
   dropped with `WARN`).
3. **Rename whose halves are both in scope**: `git mv old.txt new.txt`, both paths as positive
   pathspecs — assert the commit lands with `D old.txt` / `A new.txt` (or `R100` in `git show`),
   `git status --short` clean afterward (currently: only `new.txt` lands, `old.txt`'s delete-half
   is dropped and stays staged).

`T7` (genuinely nonexistent pathspec still dropped with `WARN`) must be preserved unchanged as a
regression guard against case-3-over-matching once the fix is in place.

### Deploy/propagation scope

`.claude/scripts/git-commit-scoped.sh` (deployed copy) is currently byte-identical to
`agent-system/extensions/core/scripts/git-commit-scoped.sh` (source store), confirmed by diff.
The ACCEPTANCE's "deployed trees are refreshed" clause is satisfied in *this* repo by whatever
regeneration step already keeps `.claude/` in sync with the source store (redeploy). The
consumer-repo propagation gap (a separate, already-filed defect: task 200 in this repo's own
`specs/TODO.md`, "Close the consumer-repo deploy propagation gap...") is correctly out of scope
here per the dispatch's own parenthetical — external repos such as BimodalLogic pick this fix up
only once they redeploy, which this task does not need to perform on their behalf.

## Decisions

- Fix targets the V2 gate classification (three-way, not two-way) plus decoupling the `git add`
  pathspec set from the `git commit` pathspec set — confirmed by direct reproduction, not
  inferred from reading alone.
- `git cat-file -e "HEAD:$p"` (guarded by HEAD existing) is the sufficient staged-deletion
  detection signal; `git diff --cached` is not independently needed.
- Out-of-scope deletions: preserve current silent-ignore behavior; no refuse logic added. Grounded
  in `git-staging-scope.md`'s existing "under-stage, never over-stage" fail-safe direction — not
  set as a `user_decision` item.

## Recommendations

1. In `agent-system/extensions/core/scripts/git-commit-scoped.sh`'s V2 gate loop
   (lines 174-188), add the third classification branch described above, producing a new
   `add_pathspecs` array (case 1 only, plus exclude entries) alongside the existing
   `filtered_pathspecs`/`pathspecs` array (cases 1+2, plus exclude entries) that continues to
   drive the final `git commit -- ...` call.
2. Change the `git add "${pathspecs[@]}"` call at line 228 to use the new `add_pathspecs` array
   instead of the full `pathspecs` array; leave the `git commit -m "$full_message" -- "${pathspecs[@]}"`
   calls at lines 283 and 293 unchanged (they must keep using the full matched set so the
   already-staged deletion is actually committed).
3. Extend `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` with three new
   cases (T8/T9/T10 or similar) covering the ACCEPTANCE's three shapes, following the existing
   `build_repo`/`run_commit`/`git show --name-status` verification pattern (never exit-code-only
   assertions, per that file's own stated convention). Confirm each new case fails against the
   current unpatched script before the fix and passes after, matching this repo's existing
   regression-test discipline.
4. Update the script's header safety-gate documentation (the V2 comment block, lines 45-48) to
   describe the corrected three-way classification, since it currently documents only the
   two-way match/drop behavior being changed.
5. Run `shellcheck` against the modified script per `context/standards/shell-strict-mode.md`
   before considering the phase complete.
6. After editing, redeploy so `.claude/scripts/git-commit-scoped.sh` picks up the fix in this
   repo (both copies are currently identical; do not hand-edit the `.claude/**` copy directly per
   `context/rules/source-store-deploy-boundary.md`). Consumer-repo propagation is out of scope
   (tracked separately as task 200).
7. No action needed on the out-of-scope-deletion question beyond documenting the decision (in the
   plan/summary) that current silent-ignore behavior is intentionally preserved.

## Risks & Mitigations

- **Risk**: forgetting to also exclude case-2 paths from `git add` reintroduces the verified
  "whole `git add` call aborts" failure mode, which is worse (loud, whole-commit) than today's
  silent partial-drop. **Mitigation**: the new regression tests (recommendation 3) must assert the
  mixed-deletion-plus-modification case (ACCEPTANCE shape 2) specifically, since that is the case
  that exposes an incorrectly-scoped `git add` array most directly.
- **Risk**: `git cat-file -e "HEAD:$p"` invoked before any commit exists (a fresh repo with no
  `HEAD`) errors noisily. **Mitigation**: guard with a `git rev-parse --verify -q HEAD` (or
  equivalent) check first, falling through to case 3 (drop with WARN) when there is no HEAD yet —
  consistent with the script's existing `--honest-index-rows` code path, which already handles a
  missing `HEAD` gracefully (lines 240-249) via the same failure-tolerant pattern.
- **Risk**: pathspec magic (globs, `:(exclude)`, etc.) passed as a positive entry won't resolve
  cleanly through `git cat-file -e HEAD:<p>` (it expects a literal tree path). **Mitigation**: none
  needed for this task — this is a pre-existing limitation shared by the current `-e "$p"` check
  too (shell/pathspec globs already interact awkwardly with a literal-path test), out of scope for
  this defect fix, and not exercised by any of the three ACCEPTANCE shapes.

## Appendix

- Reproductions performed in isolated scratch repos under the session scratchpad directory
  (`/tmp/claude-*/.../scratchpad/repro{1..7}`), never against the real repository tree.
- Key commands used to verify: `git rm`, `git mv`, `git add`, `git commit -- <pathspec>`,
  `git cat-file -e HEAD:<path>`, `git status --short`, `git show --name-status --format=""`.
- `git-commit-scoped.sh` git add/commit logic: lines 174-298.
- `orchestrator-postflight.sh` live caller: lines 505-548 (`modified_files` individual-path
  staging).
