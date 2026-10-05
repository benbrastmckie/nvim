# Research Report: Task #325

**Task**: 325 - Stop git-commit-scoped.sh from aborting the whole commit on a `git add`
gitignore advisory for a tracked, ignore-matched path
**Started**: 2026-10-05
**Completed**: 2026-10-05
**Effort**: Small (single-file, localized fix at one exit-code check)
**Dependencies**: None (sibling tasks 304 and 322 share the same script but target different
code paths — see Findings)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (source-store copy; byte-identical
  to deployed copy, confirmed by dispatch)
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
- Live git behavior reproduction in an isolated `/tmp` scratch repo (git 2.54.0, same version the
  dispatch verified against)
- `specs/state.json` entries for tasks 304 and 322 (sibling scope check)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real, reproduced independently in an isolated scratch repo with git 2.54.0,
  exactly as the dispatch describes: `git add` on a **tracked** path whose path matches a
  `.gitignore` rule prints the "ignored by one of your .gitignore files" advisory, exits 1, **and
  still stages the file correctly**. `git-commit-scoped.sh:396` treats that exit 1 as a hard
  failure and aborts before `git commit` is ever reached.
- `git check-ignore -q` (used elsewhere in the same script for `:(exclude)` entries) cannot be
  reused here: it is index-aware and reports "not ignored" (exit 1) for a tracked file, directly
  contradicting what `git add` does. `git check-ignore --no-index` *would* agree with `git add`,
  but adding a second `check-ignore` call per path is unnecessary — the simpler, more general fix
  is a **post-add verification of actual index state**, not a smarter pre-check.
- The advisory is per-path-transparent within a single batched `git add` call: when a tracked
  ignore-matched path and an ordinary path are added together, **both** land in the index despite
  the nonzero exit. This is a different failure shape from task 304's out-of-repo pathspec, which
  I verified is a hard `fatal:` (exit 128) that aborts the **entire** batch before touching any
  path, including otherwise-valid siblings. Recommend keeping 325 and 304 as separate fixes (see
  Decisions).
- New finding beyond the dispatch: task 322's `$dst` move-destination paths are **not** protected
  by this fix. I verified that a freshly-moved file at a destination matching an ignore rule is
  genuinely untracked at that path and `git add` genuinely drops it (no advisory survives into the
  index) — `-f` is required to stage it. 322 needs its own targeted guard; it cannot piggyback on
  325's exit-code tolerance.
- Recommended fix: after the existing `git add "${add_pathspecs[@]}"` call (success or failure),
  verify per-path that each non-exclude `add_pathspecs` entry actually landed in the index as
  expected, and only treat the add as a failure for entries that demonstrably did not. This single
  verification block subsumes the current blind `if ! git add ...; then exit 2; fi`.

## Context & Scope

Scope is the single exit-code check at `git-commit-scoped.sh:395-400` (the "git add (guarded)"
step). Out of scope per the dispatch: `hooks/guard-destructive-git.sh`'s directory-pathspec
`--dry-run` restriction (noted, not pursued), and folding this fix into task 304's or task 322's
scope. Task 304 (predicate at line ~292) and task 322 (`/todo` directory-move staging) are
concurrent siblings on this same script this cycle; this report cross-checks both to avoid
conflicting guidance, per the dispatch's territory note.

## Findings

### Codebase Patterns

- The script already classifies positive pathspecs into three outcomes before `git add` (V2 gate,
  lines 292-340): matched (case 1), already-staged-deletion (case 2, deliberately excluded from
  `add_pathspecs`), and genuinely-unmatched (case 3, dropped with a WARN and recorded in
  `dropped_pathspecs` for the V6 gate). None of these three cases currently distinguishes "tracked
  path that merely drew an ignore advisory" from a genuine add failure — `add_pathspecs` for case 1
  contains both tracked and newly-added-on-disk paths, and `git add` is invoked once, in a batch,
  with success/failure trusted at the whole-call granularity (lines 395-400).
- The script's own header documents the general principle this defect extends: "V2 - an unmatched
  path in the commit pathspec aborts the WHOLE commit in bare git" — the same whole-call-trust
  problem recurs one step later, in the already-admitted `add_pathspecs` set, for a different
  trigger (ignore-matched-but-tracked rather than unmatched).
- `git-staging-scope.md` (lines 35-51) already documents the *symmetric* hazard for `:(exclude)`
  entries — naming an already-gitignored path in an explicit exclude pathspec triggers the same
  advisory and aborts the whole add — and the script's conditional-injection loop (lines 184-228)
  was built specifically to avoid ever emitting that exclude-side trigger. That existing fix
  protects only the exclude side; the positive-pathspec side (this task) was never covered, exactly
  as the dispatch states ("the hazard was understood for exclude entries and never applied to
  positive entries").

### Live Git Behavior (reproduced, git 2.54.0, isolated scratch repo)

| Scenario | `git add` exit | Actually staged? |
|---|---|---|
| Tracked file, path ignore-matched via parent-dir rule (this task's defect) | 1 (advisory) | **Yes** — confirmed via `git status --short` showing `M` |
| Same, batched with an ordinary valid path in one `git add` call | 1 (advisory) | **Yes, both paths** staged |
| Brand-new untracked file, path ignore-matched (true negative — the already-correct case) | 1 (advisory) | No — correctly not staged |
| `git check-ignore -q` on the tracked ignore-matched path | 1 ("not ignored") | n/a — index-aware, disagrees with `git add` |
| `git check-ignore --no-index` on the same path | 0 ("ignored") | n/a — agrees with `git add`'s advisory, disagrees with `check-ignore -q` |
| Out-of-repo absolute pathspec (`/etc/hostname`), batched with a valid path (task 304's trigger) | 128 (`fatal:`) | **No — neither path staged**, including the otherwise-valid sibling |
| Task 322's move destination: file physically moved into an ignore-matched, previously-untracked destination path | 1 (advisory) | No — genuinely dropped; `-f` required (confirmed: with `-f`, git even reports it as a detected rename `R src -> dst`) |

This table is the load-bearing evidence for the Decisions below: 325's trigger and 304's trigger
produce different failure shapes (soft/per-path-transparent vs. hard/whole-batch-opaque) even
though both currently surface as "the script treats a nonzero `git add` exit as fatal."

### External Resources

No external documentation needed beyond live git behavior reproduction (git 2.54.0 man pages
already match observed behavior: `git-add(1)`'s "Ignored files" section documents the advisory
and the `-f`/`--ignore-errors` escapes; neither escape is appropriate here since both would also
force-add or paper over genuinely-should-stay-dropped paths).

## Recommendations

1. **Fix site**: replace the blind `if ! git add "${add_pathspecs[@]}"; then exit 2; fi` at
   `git-commit-scoped.sh:395-400` with: run the add (capturing output and exit code, not
   short-circuiting on failure), then for every non-`:(exclude)` entry in `add_pathspecs`, verify
   it actually landed in the index as intended — e.g. `git ls-files --error-unmatch -- "$p"`
   (now tracked) **and** `git diff --quiet -- "$p"` (index content matches the working tree,
   i.e. no stale/partial stage). Collect any entry that fails this check into a
   `genuinely_failed_adds` array; only error (and skip the commit) if that array is non-empty,
   naming exactly which path(s) failed and why. This directly implements finding 1's prescription
   ("verifying the intended paths actually landed in the index after the add, rather than trusting
   the exit code in either direction") and is symmetric: it tolerates 325's false-negative exit 1
   and still correctly catches a genuine failure for any individual path.
2. **Do not use `-f`/`--ignore-errors` as the fix.** `-f` would also force-add any genuinely
   untracked, genuinely-should-stay-ignored path that happens to appear in `add_pathspecs` (e.g. a
   case-1 "present on disk" entry that was never meant to override `.gitignore`), silently
   widening what gets committed. The post-add verification approach has no such side effect.
3. **Do not reuse `git check-ignore -q` for this check.** It is index-aware and reports "not
   ignored" for exactly the tracked paths this defect is about — using it here would suppress the
   advisory-tolerance fix for the one case it needs to cover. (`--no-index` would technically agree
   with `git add`, but is an unnecessary extra process call once the post-add verification above is
   in place; it adds no information the post-add check doesn't already give more directly.)
4. **Keep this fix scoped to the `git add` step (line ~396) only** — do not touch the V2
   classification loop (line ~292, task 304's fix site) or the `/todo` directory-move staging
   call sites (task 322's fix site).

## Decisions

- **325 and 304 should remain separate fixes, not merged into one hardened add step**, despite
  both superficially being "don't trust `git add`'s exit code" issues. Verified reason: 304's
  out-of-repo pathspec produces a hard hard `fatal:` (exit 128) that aborts the **entire batched
  `git add` call before any path is processed** — a post-add verification step alone does not
  rescue 304's otherwise-valid sibling paths in that same batch; 304 genuinely needs its
  already-planned pre-filter at the Case 1 admission predicate (line ~292) to keep the bad pathspec
  out of the `git add` call in the first place. 325's trigger, by contrast, is per-path-transparent
  within the batch (confirmed: a valid sibling path still lands correctly even when another path in
  the same call draws the ignore advisory), so 325 only needs post-hoc tolerance, not a pre-filter.
  A single shared post-add verification helper is reasonable **as a building block both fixes could
  call**, but 304 still needs its own, distinct pre-filter on top of it.
- **322 cannot rely on 325's fix to unblock its destination-staging case.** Verified: a file
  physically moved (via plain `mv`, as `/todo`'s directory-move does) into a path matching an
  ignore rule is, from `git add`'s perspective, a **brand-new untracked path** at that destination
  — not a tracked path merely re-flagged by a parent-dir rule. `git add` genuinely drops it (no
  advisory-only false negative; the post-add verification in this report's Recommendation 1 would
  correctly flag this as a genuine failure, not silently accept it). 322's implementer needs a
  distinct, destination-specific guard (e.g. detecting that the move's destination is
  ignore-matched and explicitly force-adding only that known-safe, intentional move destination, or
  sequencing 322 to land only after a parent-directory `.gitignore` exemption is added for archived
  task directories). This sharpens the dispatch's existing warning to 322 with a verified mechanism,
  not just a flagged risk.
- No `user_decision` is required: the fix site, the fix shape, and the non-merge ruling for 304 are
  all settled by the verified evidence above, not by a preference only the user can supply.

## Risks & Mitigations

- **Risk**: a future git version changes the advisory's wording or exit code. Mitigation: the
  recommended fix does not pattern-match on the advisory text at all — it verifies actual index
  state after the call, so it is robust to git's own message/exit-code choices changing.
- **Risk**: `git diff --quiet -- "$p"` on a pathspec that is a case-2-style deletion could
  misbehave. Mitigation: not a concern here — `add_pathspecs` deliberately excludes case-2 entries
  already (per the existing comment at lines 320-330), so the new check only ever runs against
  paths that are expected to be present-on-disk adds.
- **Risk**: the new per-path verification loop adds `2 * N` extra git invocations (one
  `ls-files`, one `diff`, per positive `add_pathspecs` entry). Mitigation: this only runs once per
  commit invocation (not per dispatch cycle) and only over the caller's own narrow, task-scoped
  pathspec list — negligible cost relative to the mutex/contention-claim machinery already in the
  same script.

## Context Extension Recommendations

- **Topic**: git-add exit-code trust boundary (positive-pathspec side).
- **Gap**: `git-staging-scope.md` documents the exclude-side ignore-advisory hazard in detail but
  has no corresponding section for the positive-pathspec/tracked-file case this task fixes.
- **Recommendation**: once implemented, add a short subsection to `git-staging-scope.md` (sibling
  to the existing lines 35-51 passage) documenting that a tracked, ignore-matched positive pathspec
  draws the same advisory but, unlike the exclude case, **does not actually fail** — and that
  `git-commit-scoped.sh` now verifies index state post-add rather than trusting `git add`'s exit
  code, to prevent a future caller from "fixing" this by checking `git check-ignore -q` (which
  would silently regress, since it disagrees with `git add` for exactly this case).

## Appendix

- Live reproduction commands and exact outputs are captured in the Findings table above; run
  against an isolated `/tmp` scratch git repo (git 2.54.0), not the project repo, to avoid any
  interaction with `hooks/guard-destructive-git.sh`'s directory-pathspec and over-staging guards.
- Confirmed via `jq` against `specs/state.json`: task 304 is `not_started` with no reports yet;
  task 322 is `researching` (concurrent sibling this cycle). Neither has produced a report
  matching `ignored by one of your` or `addIgnoredFile`, consistent with the dispatch's
  "NO EXISTING COVERAGE" claim.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` confirmed as the correct edit target
  (source-store copy under `source_dir` for the `core` extension per `.claude-extensions.json`),
  not the deployed `.claude/` mirror.
